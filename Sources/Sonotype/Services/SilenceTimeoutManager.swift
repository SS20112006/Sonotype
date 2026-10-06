import Foundation

/// Protocolo de abstração temporal para testes determinísticos de timeout sem esperas reais no clock.
public protocol TimeProviding: Sendable {
    func now() -> Date
}

/// Implementação padrão que utiliza o relógio real do sistema macOS.
public struct SystemTimeProvider: TimeProviding, Sendable {
    public init() {}

    public func now() -> Date {
        Date()
    }
}

/// Gestor de proteção de silêncio contínuo.
/// Monitoriza a amplitude sonora e encerra a gravação automaticamente se o utilizador parar de falar
/// durante o período configurado (padrão: 45 segundos), evitando gravações infinitas e poupando bateria.
@MainActor
public final class SilenceTimeoutManager: Sendable {
    public private(set) var isRunning: Bool = false

    /// Duração do timeout contínuo em segundos. Se for `nil`, o timeout está desativado.
    public var timeoutDuration: TimeInterval?

    /// Limiar mínimo de amplitude RMS (0.0 a 1.0) para considerar presença de fala humana.
    public var silenceThreshold: Float

    /// Registo do instante da última fala detetada acima do limiar.
    public private(set) var lastVoiceActivityTime: Date

    /// Provedor de relógio injetável.
    private let timeProvider: any TimeProviding

    /// Callback disparado quando o timeout de silêncio contínuo expira.
    public var onSilenceTimeout: (@MainActor @Sendable () -> Void)?

    private var checkTask: Task<Void, Never>?

    public init(
        timeoutDuration: TimeInterval? = 45.0,
        silenceThreshold: Float = 0.04,
        timeProvider: any TimeProviding = SystemTimeProvider()
    ) {
        self.timeoutDuration = timeoutDuration
        self.silenceThreshold = silenceThreshold
        self.timeProvider = timeProvider
        self.lastVoiceActivityTime = timeProvider.now()
    }

    deinit {
        checkTask?.cancel()
    }

    /// Inicia a vigilância de silêncio para a sessão atual.
    public func start() {
        guard !isRunning else { return }
        isRunning = true
        lastVoiceActivityTime = timeProvider.now()

        checkTask?.cancel()
        // Tarefa periódica assíncrona de segurança para avaliar o timeout em background
        checkTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 500_000_000)
                guard !Task.isCancelled, let self = self, self.isRunning else { break }
                self.evaluateTimeout()
            }
        }
    }

    /// Pára a monitorização de silêncio e cancela a verificação periódica.
    public func stop() {
        isRunning = false
        checkTask?.cancel()
        checkTask = nil
    }

    /// Reinicia o marco temporal da última fala.
    public func reset() {
        lastVoiceActivityTime = timeProvider.now()
    }

    /// Alimenta o gestor com a amplitude RMS calculada pelo AVAudioEngine em tempo real.
    public func feedAmplitude(_ amplitude: Float) {
        guard isRunning else { return }

        let now = timeProvider.now()
        if amplitude >= silenceThreshold {
            // Fala detetada: reinicia a contagem de silêncio contínuo
            lastVoiceActivityTime = now
        } else {
            // Silêncio: avalia se o limite estipulado foi atingido
            evaluateTimeout()
        }
    }

    /// Avalia se o tempo de silêncio decorrido ultrapassou o limite estipulado.
    @discardableResult
    public func evaluateTimeout() -> Bool {
        guard isRunning, let timeout = timeoutDuration else { return false }

        let elapsed = timeProvider.now().timeIntervalSince(lastVoiceActivityTime)
        if elapsed >= timeout {
            stop()
            onSilenceTimeout?()
            return true
        }
        return false
    }

    /// Retorna o tempo decorrido de silêncio desde a última atividade de fala.
    public func currentSilenceDuration() -> TimeInterval {
        timeProvider.now().timeIntervalSince(lastVoiceActivityTime)
    }
}
