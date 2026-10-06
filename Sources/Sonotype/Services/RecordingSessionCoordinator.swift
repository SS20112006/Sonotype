import Foundation

/// Coordenador do ciclo de vida das sessões de gravação do Sonotype.
/// Integra a máquina de estados, captura de atalhos globais, proteção de silêncio contínuo
/// e emissão de feedback auditivo nativo.
@MainActor
public final class RecordingSessionCoordinator: Sendable {
    public let stateMachine: RecordingStateMachine
    public let hotkeyManager: any GlobalHotkeyMonitoring
    public let silenceManager: SilenceTimeoutManager
    public let soundPlayer: any FeedbackSoundPlaying

    /// Callback disparado quando uma nova gravação é iniciada.
    public var onStartRecording: (@MainActor @Sendable () -> Void)?

    /// Callback assíncrono disparado quando a gravação deve ser finalizada, processada e inserida.
    /// Parâmetro: `RecordingStopReason` indicando se a paragem foi voluntária (.userToggle) ou por inatividade (.silenceTimeout).
    public var onFinishRecording: (@MainActor @Sendable (RecordingStopReason) async -> Void)?

    /// Callback disparado quando a gravação é cancelada expressamente (via tecla Escape).
    public var onCancelRecording: (@MainActor @Sendable () -> Void)?

    /// Callback disparado a cada atualização de amplitude de áudio para alimentar a UI/HUD.
    public var onAmplitudeChanged: (@MainActor @Sendable (Float) -> Void)?

    public init(
        stateMachine: RecordingStateMachine = RecordingStateMachine(),
        hotkeyManager: any GlobalHotkeyMonitoring = SystemGlobalHotkeyManager(),
        silenceManager: SilenceTimeoutManager = SilenceTimeoutManager(),
        soundPlayer: any FeedbackSoundPlaying = SystemFeedbackSoundPlayer()
    ) {
        self.stateMachine = stateMachine
        self.hotkeyManager = hotkeyManager
        self.silenceManager = silenceManager
        self.soundPlayer = soundPlayer

        setupEventBindings()
    }

    private func setupEventBindings() {
        // Vincula acionamento do atalho global (Option + Espaço)
        hotkeyManager.onHotkeyPressed { [weak self] in
            self?.handleHotkeyTrigger()
        }

        // Vincula tecla de cancelamento (Escape)
        hotkeyManager.onEscapePressed { [weak self] in
            self?.handleEscapeTrigger()
        }

        // Vincula timeout de silêncio contínuo de 45 segundos
        silenceManager.onSilenceTimeout = { [weak self] in
            self?.handleSilenceTimeoutTrigger()
        }
    }

    /// Inicia o monitoramento de atalhos globais no sistema.
    public func start() {
        hotkeyManager.startMonitoring()
    }

    /// Interrompe o monitoramento de atalhos e cancela qualquer sessão ativa.
    public func stop() {
        hotkeyManager.stopMonitoring()
        silenceManager.stop()
        stateMachine.reset()
    }

    /// Trata a alternância (Toggle) do atalho global.
    public func handleHotkeyTrigger() {
        switch stateMachine.currentState {
        case .idle, .cancelled:
            guard stateMachine.startRecording() else { return }
            soundPlayer.playStartSound()
            silenceManager.start()
            onStartRecording?()

        case .recording:
            silenceManager.stop()
            soundPlayer.playStopSound()
            guard stateMachine.stopRecording(reason: .userToggle) else { return }

            Task { [weak self] in
                guard let self = self else { return }
                await self.onFinishRecording?(.userToggle)
                self.stateMachine.finishProcessing()
            }

        case .processing:
            // Enquanto o texto está a ser processado e injetado, ignora novos toques de toggle
            break
        }
    }

    /// Trata o cancelamento imediato ao premir a tecla Escape.
    public func handleEscapeTrigger() {
        guard stateMachine.currentState == .recording || stateMachine.currentState == .processing else {
            return
        }

        silenceManager.stop()
        soundPlayer.playCancelSound()
        stateMachine.cancelRecording()
        onCancelRecording?()
        stateMachine.reset()
    }

    /// Trata o disparo automático de paragem por inatividade/silêncio prolongado.
    public func handleSilenceTimeoutTrigger() {
        guard stateMachine.currentState == .recording else { return }

        soundPlayer.playStopSound()
        guard stateMachine.handleSilenceTimeout() else { return }

        Task { [weak self] in
            guard let self = self else { return }
            await self.onFinishRecording?(.silenceTimeout)
            self.stateMachine.finishProcessing()
        }
    }

    /// Encaminha o nível de amplitude de áudio para a monitorização de silêncio contínuo e UI.
    public func feedAudioAmplitude(_ amplitude: Float) {
        silenceManager.feedAmplitude(amplitude)
        onAmplitudeChanged?(amplitude)
    }
}
