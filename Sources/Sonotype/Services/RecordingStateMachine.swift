import Foundation

/// Estados formais do ciclo de vida da gravação no Sonotype.
public enum RecordingState: String, Sendable, Equatable, CaseIterable {
    /// Aplicação em repouso, pronta para escutar o próximo acionamento do atalho.
    case idle
    /// A capturar fluxo de áudio ativamente.
    case recording
    /// Transcrição a finalizar, pós-processamento de texto e injeção no cursor.
    case processing
    /// Sessão cancelada expressamente (ex: tecla Escape). Áudio e texto são descartados.
    case cancelled
}

/// Modo de operação do atalho global configurado nas preferências.
public enum HotkeyMode: String, Sendable, CaseIterable, Codable {
    /// Modo Toggle (Mãos Livres): 1 toque para iniciar, 1 toque para finalizar e inserir.
    case toggle
    /// Modo Push-to-Talk: manter pressionado para gravar, soltar para finalizar e inserir.
    case pushToTalk
}

/// Motivo pelo qual a gravação foi finalizada ou interrompida.
public enum RecordingStopReason: String, Sendable, Equatable {
    /// O utilizador acionou novamente o atalho em modo Toggle.
    case userToggle
    /// O utilizador soltou a tecla em modo Push-to-Talk.
    case userRelease
    /// O utilizador cancelou expressamente com a tecla Escape.
    case userCancelled
    /// O sistema detetou ausência de voz durante o limite configurado (45s de silêncio contínuo).
    case silenceTimeout
}

/// Máquina de estados determinística para o ciclo de gravação do Sonotype.
@MainActor
public final class RecordingStateMachine: Sendable {
    public private(set) var currentState: RecordingState = .idle
    public var hotkeyMode: HotkeyMode
    public private(set) var lastStopReason: RecordingStopReason?

    /// Callbacks observadores de transição de estado
    public var onStateChange: (@MainActor @Sendable (RecordingState, RecordingState) -> Void)?
    public var onStop: (@MainActor @Sendable (RecordingStopReason) -> Void)?

    public init(hotkeyMode: HotkeyMode = .toggle) {
        self.hotkeyMode = hotkeyMode
        self.currentState = .idle
        self.lastStopReason = nil
    }

    /// Valida se uma transição de estado é permitida pelas regras de negócio.
    public func canTransition(to newState: RecordingState) -> Bool {
        switch (currentState, newState) {
        case (.idle, .recording):
            return true
        case (.recording, .processing):
            return true
        case (.recording, .cancelled):
            return true
        case (.processing, .idle):
            return true
        case (.processing, .cancelled):
            return true
        case (.cancelled, .idle):
            return true
        case (.cancelled, .recording):
            return true
        default:
            return false
        }
    }

    /// Inicia a gravação a partir de .idle ou .cancelled.
    @discardableResult
    public func startRecording() -> Bool {
        guard canTransition(to: .recording) else { return false }
        transition(to: .recording)
        lastStopReason = nil
        return true
    }

    /// Pára a gravação normal e transita para o processamento de texto.
    @discardableResult
    public func stopRecording(reason: RecordingStopReason = .userToggle) -> Bool {
        guard canTransition(to: .processing) else { return false }
        lastStopReason = reason
        transition(to: .processing)
        onStop?(reason)
        return true
    }

    /// Cancela a gravação imediatamente (via Escape ou aborto).
    @discardableResult
    public func cancelRecording() -> Bool {
        guard canTransition(to: .cancelled) else { return false }
        lastStopReason = .userCancelled
        transition(to: .cancelled)
        onStop?(.userCancelled)
        return true
    }

    /// Conclui o processamento e regressa ao repouso (.idle).
    @discardableResult
    public func finishProcessing() -> Bool {
        guard canTransition(to: .idle) else { return false }
        transition(to: .idle)
        return true
    }

    /// Redefine a máquina para repouso incondicionalmente.
    public func reset() {
        let previous = currentState
        currentState = .idle
        lastStopReason = nil
        if previous != .idle {
            onStateChange?(previous, .idle)
        }
    }

    /// Aciona a paragem decorrente do timeout de silêncio contínuo.
    @discardableResult
    public func handleSilenceTimeout() -> Bool {
        return stopRecording(reason: .silenceTimeout)
    }

    private func transition(to newState: RecordingState) {
        let previous = currentState
        currentState = newState
        onStateChange?(previous, newState)
    }
}
