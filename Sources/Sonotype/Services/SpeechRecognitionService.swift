import Foundation
@preconcurrency import Speech
@preconcurrency import AVFoundation

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
public final class SpeechRecognitionService: @unchecked Sendable {
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
            throw SpeechRecognitionError.alreadyRecognizing
        }

        guard let rec = recognizers[language] ?? SFSpeechRecognizer(locale: language.locale) else {
            throw SpeechRecognitionError.recognizerUnavailable(language)
        }

        recognizers[language] = rec

        if requiresOnDeviceRecognition && !rec.supportsOnDeviceRecognition {
            // Nota: Em simuladores ou máquinas sem modelos descarregados, avisa com erro tipado
            throw SpeechRecognitionError.onDeviceRecognitionUnsupported(language)
        }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = requiresOnDeviceRecognition

        self.currentRequest = request
        self._isRecognizing = true

        self.currentTask = rec.recognitionTask(with: request) { [weak self] result, error in
            guard let self = self else { return }

            if let result = result {
                let transcription = result.bestTranscription.formattedString
                let isFinal = result.isFinal
                onTranscriptionUpdate(transcription, isFinal)

                if isFinal {
                    self.resetSession()
                }
            }

            if let error = error {
                onError?(error)
                self.resetSession()
            }
        }
    }

    /// Alimenta um buffer de áudio em memória diretamente no pedido ativo.
    public func appendBuffer(_ buffer: AVAudioPCMBuffer) {
        lock.lock()
        defer { lock.unlock() }

        guard _isRecognizing, let request = currentRequest else { return }
        request.append(buffer)
    }

    /// Notifica o fim do fluxo de áudio para produzir o resultado final.
    public func finishAudio() {
        lock.lock()
        defer { lock.unlock() }

        guard _isRecognizing, let request = currentRequest else { return }
        request.endAudio()
    }

    /// Cancela imediatamente a sessão em curso e liberta recursos.
    public func cancel() {
        lock.lock()
        defer { lock.unlock() }

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
