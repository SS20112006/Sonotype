import Foundation
@preconcurrency import Speech
@preconcurrency import AVFoundation
import os

/// Erros tipados do motor de reconhecimento de voz.
public enum SpeechRecognitionError: LocalizedError, Sendable {
    case recognizerUnavailable(SpeechLanguage)
    case onDeviceRecognitionUnsupported(SpeechLanguage)
    case alreadyRecognizing
    case noActiveSession

    public var errorDescription: String? {
        switch self {
        case .recognizerUnavailable(let lang):
            return "Reconhecedor de fala indisponível para o idioma \(lang.rawValue)."
        case .onDeviceRecognitionUnsupported(let lang):
            return "Reconhecimento offline (no dispositivo) não suportado para \(lang.rawValue)."
        case .alreadyRecognizing:
            return "Já existe uma sessão de reconhecimento em curso."
        case .noActiveSession:
            return "Nenhuma sessão de reconhecimento ativa."
        }
    }
}

/// Serviço de reconhecimento de voz offline utilizando SFSpeechRecognizer nativo da Apple.
/// Garante processamento exclusivamente em memória RAM e enforce de requiresOnDeviceRecognition = true.
public class SpeechRecognitionService: @unchecked Sendable {
    private static let logger = Logger(subsystem: "com.sonotype.app", category: "SpeechRecognitionService")

    private let lock = NSLock()
    private var recognizers: [SpeechLanguage: SFSpeechRecognizer] = [:]
    private var currentRequest: SFSpeechAudioBufferRecognitionRequest?
    private var currentTask: SFSpeechRecognitionTask?
    private var _isRecognizing: Bool = false

    /// Define se o reconhecimento deve forçar estritamente o modo offline (invariante do projeto).
    public let requiresOnDeviceRecognition: Bool

    public var isRecognizing: Bool {
        lock.lock()
        defer { lock.unlock() }
        return _isRecognizing
    }

    public init(requiresOnDeviceRecognition: Bool = true) {
        self.requiresOnDeviceRecognition = requiresOnDeviceRecognition
        self.prewarmRecognizers()
    }

    deinit {
        cancel()
    }

    /// Pré-aquece os reconhecedores para os idiomas suportados em memória RAM.
    private func prewarmRecognizers() {
        for lang in SpeechLanguage.allCases {
            if let recognizer = SFSpeechRecognizer(locale: lang.locale) {
                recognizers[lang] = recognizer
            } else {
                Self.logger.warning("Reconhecedor SFSpeechRecognizer indisponível para o locale \(lang.rawValue, privacy: .public)")
            }
        }
    }

    /// Retorna a instância de SFSpeechRecognizer para um idioma específico.
    public func recognizer(for language: SpeechLanguage) -> SFSpeechRecognizer? {
        lock.lock()
        defer { lock.unlock() }
        return recognizers[language]
    }

    /// Verifica se o idioma suporta reconhecimento de fala offline no dispositivo.
    public func isOfflineSupported(for language: SpeechLanguage) -> Bool {
        guard let rec = recognizer(for: language) else { return false }
        return rec.supportsOnDeviceRecognition
    }

    /// Inicia uma sessão de reconhecimento de fala para um idioma alvo.
    /// O áudio é alimentado em streaming através de `appendBuffer(_:)` sem gravar nada em disco.
    public func startRecognition(
        language: SpeechLanguage = .portuguesePT,
        onTranscriptionUpdate: @escaping @Sendable (String, Bool) -> Void, // (texto, isFinal)
        onError: (@Sendable (Error) -> Void)? = nil
    ) throws {
        lock.lock()
        defer { lock.unlock() }

        guard !_isRecognizing else {
            Self.logger.warning("Tentativa de iniciar reconhecimento com uma sessão já ativa")
            throw SpeechRecognitionError.alreadyRecognizing
        }

        guard let rec = recognizers[language] ?? SFSpeechRecognizer(locale: language.locale) else {
            Self.logger.error("Reconhecedor de fala indisponível para o idioma \(language.rawValue, privacy: .public)")
            throw SpeechRecognitionError.recognizerUnavailable(language)
        }

        recognizers[language] = rec

        if requiresOnDeviceRecognition && !rec.supportsOnDeviceRecognition {
            // Nota: Em simuladores ou máquinas sem modelos descarregados, avisa com erro tipado
            Self.logger.error("Reconhecimento offline no dispositivo não suportado para \(language.rawValue, privacy: .public)")
            throw SpeechRecognitionError.onDeviceRecognitionUnsupported(language)
        }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = requiresOnDeviceRecognition

        self.currentRequest = request
        self._isRecognizing = true
        Self.logger.info("Iniciando reconhecimento de fala para o idioma \(language.rawValue, privacy: .public)")

        self.currentTask = rec.recognitionTask(with: request) { [weak self] result, error in
            guard let self = self else { return }

            if let result = result {
                let transcription = result.bestTranscription.formattedString
                let isFinal = result.isFinal
                onTranscriptionUpdate(transcription, isFinal)

                if isFinal {
                    Self.logger.info("Reconhecimento de fala finalizado com sucesso")
                    self.resetSession()
                }
            }

            if let error = error {
                Self.logger.error("Erro na tarefa de reconhecimento de fala: \(error.localizedDescription, privacy: .public)")
                onError?(error)
                self.resetSession()
            }
        }
    }

    /// Alimenta um buffer de áudio em memória diretamente no pedido ativo.
    public func appendBuffer(_ buffer: AVAudioPCMBuffer) {
        lock.lock()
        defer { lock.unlock() }

        guard _isRecognizing, let request = currentRequest else {
            Self.logger.debug("Buffer ignorado: nenhuma sessão de reconhecimento ativa")
            return
        }
        request.append(buffer)
    }

    /// Notifica o fim do fluxo de áudio para produzir o resultado final.
    public func finishAudio() {
        lock.lock()
        defer { lock.unlock() }

        guard _isRecognizing, let request = currentRequest else {
            Self.logger.debug("finishAudio ignorado: nenhuma sessão de reconhecimento ativa")
            return
        }
        Self.logger.info("Finalizando fluxo de áudio da sessão de reconhecimento")
        request.endAudio()
    }

    /// Cancela imediatamente a sessão em curso e liberta recursos.
    public func cancel() {
        lock.lock()
        defer { lock.unlock() }

        if _isRecognizing {
            Self.logger.info("Cancelando sessão de reconhecimento de fala ativa")
        }
        currentRequest?.endAudio()
        currentTask?.cancel()
        currentTask = nil
        currentRequest = nil
        _isRecognizing = false
    }

    private func resetSession() {
        lock.lock()
        defer { lock.unlock() }

        currentRequest = nil
        currentTask = nil
        _isRecognizing = false
    }
}
