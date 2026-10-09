import Foundation
@preconcurrency import Speech
@preconcurrency import AVFoundation
import os

/// Erros tipados do motor de reconhecimento de voz.
public enum SpeechRecognitionError: LocalizedError, Sendable {
    case recognizerUnavailable(SpeechLanguage)
    case onDeviceRecognitionUnsupported(SpeechLanguage)
    case notAuthorized
    case microphoneNotAuthorized
    case dictationDisabled
    case alreadyRecognizing
    case noActiveSession

    public var errorDescription: String? {
        switch self {
        case .recognizerUnavailable(let lang):
            return "Reconhecedor de fala indisponível para o idioma \(lang.rawValue)."
        case .onDeviceRecognitionUnsupported(let lang):
            return "Reconhecimento offline (no dispositivo) não suportado para \(lang.rawValue)."
        case .notAuthorized:
            return "Permissão de reconhecimento de fala não concedida. Ative nas Definições do Sistema."
        case .microphoneNotAuthorized:
            return "Permissão de microfone não concedida. Ative nas Definições do Sistema."
        case .dictationDisabled:
            return "O Ditado do macOS está desativado. Ative o Ditado em Definições do Sistema > Teclado."
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
    private var currentRequestId = UUID()
    private var _isRecognizing: Bool = false

    // Estado acumulado para permitir transcrições longas contínuas sem perdas
    private var accumulatedTranscription: String = ""
    private var currentSegmentTranscription: String = ""
    private var lastRawSegmentString: String = ""
    private var effectiveLanguage: SpeechLanguage = .portuguesePT
    private var onTranscriptionCallback: (@Sendable (String, Bool) -> Void)?
    private var onErrorCallback: (@Sendable (Error) -> Void)?
    private var rotationTimerTask: Task<Void, Never>?

    /// Intervalo de rotação proativa de tarefa (em segundos) para contornar o limite nativo de 60s da Apple.
    public let rotationIntervalSeconds: TimeInterval = 45.0

    /// Define se o reconhecimento deve forçar estritamente o modo offline (invariante do projeto).
    public let requiresOnDeviceRecognition: Bool

    public var isRecognizing: Bool {
        lock.lock()
        defer { lock.unlock() }
        return _isRecognizing
    }

    /// Retorna a transcrição completa acumulada até ao momento.
    public var currentFullTranscription: String {
        lock.lock()
        defer { lock.unlock() }
        return Self.combineTranscriptions(accumulatedTranscription, currentSegmentTranscription)
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

    /// Verifica se o Ditado ou a Siri estão habilitados no sistema macOS.
    public static var isDictationOrSiriEnabled: Bool {
        let keyDictation = "DictationIMMasterDictationEnabled" as CFString
        let domainDictation = "com.apple.speech.recognition.AppleSpeechRecognition.prefs" as CFString
        var keyExists: DarwinBoolean = false
        let dictationVal = CFPreferencesGetAppBooleanValue(keyDictation, domainDictation, &keyExists)
        if keyExists.boolValue && dictationVal {
            return true
        }

        let keySiri = "Assistant Enabled" as CFString
        let domainSiri = "com.apple.assistant.support" as CFString
        var siriExists: DarwinBoolean = false
        let siriVal = CFPreferencesGetAppBooleanValue(keySiri, domainSiri, &siriExists)
        if siriExists.boolValue && siriVal {
            return true
        }

        // Se nenhuma das chaves existe explicitamente, assume true para evitar bloqueio indevido
        if !keyExists.boolValue && !siriExists.boolValue {
            return true
        }

        return false
    }

    /// Inicia uma sessão de reconhecimento de fala contínua de longa duração.
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

        if !Self.isDictationOrSiriEnabled {
            Self.logger.error("Ditado do macOS desativado no sistema")
            throw SpeechRecognitionError.dictationDisabled
        }

        var activeRec = recognizers[language] ?? SFSpeechRecognizer(locale: language.locale)
        var effectiveLanguage = language

        // Fallback inteligente para variantes da mesma língua com suporte on-device pré-instalado
        if requiresOnDeviceRecognition, let r = activeRec, !r.supportsOnDeviceRecognition {
            if language == .portuguesePT, let brRec = recognizers[.portugueseBR], brRec.supportsOnDeviceRecognition {
                Self.logger.info("Locale pt-PT sem modelo offline descarregado; utilizando recognizer pt-BR on-device.")
                activeRec = brRec
                effectiveLanguage = .portugueseBR
            } else if language == .englishGB, let usRec = recognizers[.englishUS], usRec.supportsOnDeviceRecognition {
                Self.logger.info("Locale en-GB sem modelo offline descarregado; utilizando recognizer en-US on-device.")
                activeRec = usRec
                effectiveLanguage = .englishUS
            }
        }

        guard let rec = activeRec else {
            Self.logger.error("Reconhecedor de fala indisponível para o idioma \(language.rawValue, privacy: .public)")
            throw SpeechRecognitionError.recognizerUnavailable(language)
        }

        recognizers[effectiveLanguage] = rec

        // Verificação estrita de permissões do sistema
        let speechAuth = SFSpeechRecognizer.authorizationStatus()
        let micAuth = AVCaptureDevice.authorizationStatus(for: .audio)

        if speechAuth == .denied || speechAuth == .restricted {
            Self.logger.error("Permissão de reconhecimento de fala não concedida (\(speechAuth.rawValue)) para \(language.rawValue, privacy: .public)")
            throw SpeechRecognitionError.notAuthorized
        } else if micAuth == .denied || micAuth == .restricted {
            Self.logger.error("Permissão de microfone não concedida (\(micAuth.rawValue)) para \(language.rawValue, privacy: .public)")
            throw SpeechRecognitionError.microphoneNotAuthorized
        }

        self.accumulatedTranscription = ""
        self.currentSegmentTranscription = ""
        self.lastRawSegmentString = ""
        self.effectiveLanguage = effectiveLanguage
        self.onTranscriptionCallback = onTranscriptionUpdate
        self.onErrorCallback = onError
        self.currentRequestId = UUID()
        self._isRecognizing = true

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = requiresOnDeviceRecognition && rec.supportsOnDeviceRecognition

        self.currentRequest = request
        let requestId = self.currentRequestId
        Self.logger.info("Iniciando reconhecimento de fala de longa duração para o idioma \(effectiveLanguage.rawValue, privacy: .public) (onDevice: \(request.requiresOnDeviceRecognition))")

        self.currentTask = rec.recognitionTask(with: request) { [weak self] result, error in
            self?.handleRecognitionResult(result: result, error: error, requestId: requestId)
        }

        scheduleRotationTimer()
    }

    /// Trata resultados parciais/finais e transições de elocuções para preservar toda a fala da gravação.
    private func handleRecognitionResult(result: SFSpeechRecognitionResult?, error: Error?, requestId: UUID) {
        lock.lock()
        defer { lock.unlock() }

        // Se o resultado pertence a um request antigo após rotação
        guard _isRecognizing, requestId == currentRequestId else {
            if let result = result {
                let text = result.bestTranscription.formattedString.trimmingCharacters(in: .whitespacesAndNewlines)
                if !text.isEmpty && !accumulatedTranscription.localizedCaseInsensitiveContains(text) {
                    accumulatedTranscription = Self.combineTranscriptions(accumulatedTranscription, text)
                    let full = accumulatedTranscription
                    onTranscriptionCallback?(full, false)
                }
            }
            return
        }

        if let result = result {
            let rawFormatted = result.bestTranscription.formattedString
            let isFinal = result.isFinal

            // Deteta se a Apple finalizou uma elocução anterior e começou uma nova após pausa
            if Self.shouldCommitPreviousUtterance(previous: lastRawSegmentString, new: rawFormatted) {
                accumulatedTranscription = Self.combineTranscriptions(accumulatedTranscription, lastRawSegmentString)
                currentSegmentTranscription = rawFormatted
            } else {
                currentSegmentTranscription = rawFormatted
            }
            lastRawSegmentString = rawFormatted

            if isFinal {
                // Segmento finalizado pela Apple
                accumulatedTranscription = Self.combineTranscriptions(accumulatedTranscription, currentSegmentTranscription)
                currentSegmentTranscription = ""
                lastRawSegmentString = ""

                let fullText = accumulatedTranscription
                onTranscriptionCallback?(fullText, false)

                // Se o utilizador ainda estiver a gravar, inicia imediatamente nova tarefa para não perder fala subsequente
                if _isRecognizing {
                    restartTaskUnderActiveSessionLocked()
                }
            } else {
                let fullText = Self.combineTranscriptions(accumulatedTranscription, currentSegmentTranscription)
                onTranscriptionCallback?(fullText, false)
            }
        }

        if let error = error {
            let nsError = error as NSError
            Self.logger.debug("Mensagem da tarefa de reconhecimento (code \(nsError.code)): \(error.localizedDescription, privacy: .public)")

            let isDictationDisabled = nsError.localizedDescription.localizedCaseInsensitiveContains("dictation")
                || nsError.localizedDescription.localizedCaseInsensitiveContains("siri")
                || (nsError.domain == "kAFAssistantErrorDomain" && nsError.code == 1700)
                || nsError.code == 201

            if isDictationDisabled {
                onErrorCallback?(SpeechRecognitionError.dictationDisabled)
                resetSessionLocked()
                return
            } else if nsError.code == 1110 {
                onErrorCallback?(SpeechRecognitionError.notAuthorized)
                resetSessionLocked()
                return
            }

            // Erros não-fatais de timeout ou fim de tarefa da Apple (ex: 203, 216, cancelled):
            // Comita o que já foi captado e reabre uma nova tarefa sob a mesma sessão ativa!
            if _isRecognizing {
                if !currentSegmentTranscription.isEmpty {
                    accumulatedTranscription = Self.combineTranscriptions(accumulatedTranscription, currentSegmentTranscription)
                    currentSegmentTranscription = ""
                    lastRawSegmentString = ""
                }
                restartTaskUnderActiveSessionLocked()
            }
        }
    }

    /// Reinicia uma nova tarefa SFSpeechRecognitionTask sob uma sessão ativa em curso.
    private func restartTaskUnderActiveSessionLocked() {
        guard _isRecognizing, let rec = recognizers[effectiveLanguage] else { return }

        let newRequest = SFSpeechAudioBufferRecognitionRequest()
        newRequest.shouldReportPartialResults = true
        newRequest.requiresOnDeviceRecognition = requiresOnDeviceRecognition && rec.supportsOnDeviceRecognition
        let newRequestId = UUID()

        self.currentRequest = newRequest
        self.currentRequestId = newRequestId

        self.currentTask = rec.recognitionTask(with: newRequest) { [weak self] result, error in
            self?.handleRecognitionResult(result: result, error: error, requestId: newRequestId)
        }

        scheduleRotationTimer()
    }

    /// Rotação proativa periódica aos 45 segundos para contornar o limite de 60s da Apple sem paragens.
    private func scheduleRotationTimer() {
        rotationTimerTask?.cancel()
        rotationTimerTask = Task { [weak self] in
            do {
                try await Task.sleep(nanoseconds: UInt64(45 * 1_000_000_000))
            } catch {
                return
            }
            guard !Task.isCancelled, let self = self else { return }
            self.rotateTaskProactively()
        }
    }

    private func rotateTaskProactively() {
        lock.lock()
        defer { lock.unlock() }

        guard _isRecognizing, let rec = recognizers[effectiveLanguage] else { return }
        Self.logger.info("Executando rotação proativa de tarefa de fala (45s) para suportar transcrição contínua")

        if !currentSegmentTranscription.isEmpty {
            accumulatedTranscription = Self.combineTranscriptions(accumulatedTranscription, currentSegmentTranscription)
            currentSegmentTranscription = ""
            lastRawSegmentString = ""
        }

        let oldRequest = currentRequest
        let newRequest = SFSpeechAudioBufferRecognitionRequest()
        newRequest.shouldReportPartialResults = true
        newRequest.requiresOnDeviceRecognition = requiresOnDeviceRecognition && rec.supportsOnDeviceRecognition
        let newRequestId = UUID()

        self.currentRequest = newRequest
        self.currentRequestId = newRequestId

        self.currentTask = rec.recognitionTask(with: newRequest) { [weak self] result, error in
            self?.handleRecognitionResult(result: result, error: error, requestId: newRequestId)
        }

        oldRequest?.endAudio()
        scheduleRotationTimer()
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

    /// Notifica o fim do fluxo de áudio da sessão e comita o texto final de forma síncrona.
    @discardableResult
    public func finishAudio() -> String {
        lock.lock()
        rotationTimerTask?.cancel()
        rotationTimerTask = nil

        currentRequest?.endAudio()

        if !currentSegmentTranscription.isEmpty {
            accumulatedTranscription = Self.combineTranscriptions(accumulatedTranscription, currentSegmentTranscription)
            currentSegmentTranscription = ""
            lastRawSegmentString = ""
        }

        let result = accumulatedTranscription
        resetSessionLocked()
        lock.unlock()
        return result
    }

    /// Notifica o fim do fluxo de áudio e aguarda até 500ms pelo esvaziamento final do pipeline de buffers em RAM.
    public func finishAudioAndGetFinalTranscription(timeoutSeconds: TimeInterval = 0.5) async -> String {
        let isRec: Bool = lock.withLock {
            rotationTimerTask?.cancel()
            rotationTimerTask = nil
            guard _isRecognizing else { return false }
            currentRequest?.endAudio()
            return true
        }

        if !isRec {
            return finishAudio()
        }

        let deadline = Date().addingTimeInterval(timeoutSeconds)
        while Date() < deadline {
            try? await Task.sleep(nanoseconds: 50_000_000)
            let stillPending = lock.withLock { !currentSegmentTranscription.isEmpty }
            if !stillPending {
                break
            }
        }

        return finishAudio()
    }

    /// Cancela imediatamente a sessão em curso e liberta todos os recursos.
    public func cancel() {
        lock.lock()
        defer { lock.unlock() }

        if _isRecognizing {
            Self.logger.info("Cancelando sessão de reconhecimento de fala ativa")
        }
        rotationTimerTask?.cancel()
        rotationTimerTask = nil

        currentRequest?.endAudio()
        currentTask?.cancel()
        resetSessionLocked()
    }

    private func resetSessionLocked() {
        currentRequest = nil
        currentTask = nil
        _isRecognizing = false
        accumulatedTranscription = ""
        currentSegmentTranscription = ""
        lastRawSegmentString = ""
        rotationTimerTask?.cancel()
        rotationTimerTask = nil
    }

    // MARK: - Algoritmos de Agregação e Deteção de Fronteiras de Fala

    /// Avalia se a nova cadeia de caracteres indica o início de uma nova elocução após uma pausa/frase anterior.
    public static func shouldCommitPreviousUtterance(previous: String, new: String) -> Bool {
        let prevTrimmed = previous.trimmingCharacters(in: .whitespacesAndNewlines)
        let newTrimmed = new.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !prevTrimmed.isEmpty, !newTrimmed.isEmpty else { return false }

        // Se a nova elocução contém a anterior ou começa por ela, é uma expansão contínua
        if newTrimmed.hasPrefix(prevTrimmed) || newTrimmed.localizedCaseInsensitiveContains(prevTrimmed) {
            return false
        }

        let prevWords = prevTrimmed.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        let newWords = newTrimmed.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }

        guard !prevWords.isEmpty, !newWords.isEmpty else { return false }

        // Conta palavras coincidentes no prefixo
        var matchingPrefixWords = 0
        let minCount = min(prevWords.count, newWords.count)
        for i in 0..<minCount {
            if prevWords[i].caseInsensitiveCompare(newWords[i]) == .orderedSame {
                matchingPrefixWords += 1
            } else {
                break
            }
        }

        // Se pelo menos metade das palavras do início coincide, é refinamento da mesma frase
        if prevWords.count > 0 && Double(matchingPrefixWords) / Double(prevWords.count) >= 0.5 {
            return false
        }

        // Caso contrário, a Apple iniciou uma nova frase/elocução independente após uma pausa
        return true
    }

    /// Combina dois blocos textuais mantendo pontuação e espaçamento higiénico.
    public static func combineTranscriptions(_ a: String, _ b: String) -> String {
        let aTrimmed = a.trimmingCharacters(in: .whitespacesAndNewlines)
        let bTrimmed = b.trimmingCharacters(in: .whitespacesAndNewlines)
        if aTrimmed.isEmpty { return bTrimmed }
        if bTrimmed.isEmpty { return aTrimmed }
        return "\(aTrimmed) \(bTrimmed)"
    }
}
