import XCTest
@testable import Sonotype

private final class TestBox<T>: @unchecked Sendable {
    private let lock = NSLock()
    private var _value: T?

    init(_ value: T? = nil) {
        self._value = value
    }

    var value: T? {
        lock.lock()
        defer { lock.unlock() }
        return _value
    }

    func set(_ newValue: T) {
        lock.lock()
        defer { lock.unlock() }
        _value = newValue
    }
}

private final class TestArrayBox<T>: @unchecked Sendable {
    private let lock = NSLock()
    private var _values: [T] = []

    var values: [T] {
        lock.lock()
        defer { lock.unlock() }
        return _values
    }

    func append(_ item: T) {
        lock.lock()
        defer { lock.unlock() }
        _values.append(item)
    }
}

@MainActor
final class RecordingStateMachineTests: XCTestCase {
    private var stateMachine: RecordingStateMachine!

    override func setUp() async throws {
        try await super.setUp()
        stateMachine = RecordingStateMachine(hotkeyMode: .toggle)
    }

    override func tearDown() async throws {
        stateMachine = nil
        try await super.tearDown()
    }

    // MARK: - Estado Inicial

    func testInitialStateIsIdle() {
        XCTAssertEqual(stateMachine.currentState, .idle)
        XCTAssertEqual(stateMachine.hotkeyMode, .toggle)
        XCTAssertNil(stateMachine.lastStopReason)
    }

    // MARK: - Ciclo Normal (Start -> Stop -> Finish)

    func testNormalRecordingLifecycle() {
        let recordedTransitions = TestArrayBox<(RecordingState, RecordingState)>()
        stateMachine.onStateChange = { from, to in
            recordedTransitions.append((from, to))
        }

        // 1. Iniciar
        let startSuccess = stateMachine.startRecording()
        XCTAssertTrue(startSuccess)
        XCTAssertEqual(stateMachine.currentState, .recording)

        // 2. Parar (Toggle)
        let stopReasonBox = TestBox<RecordingStopReason>()
        stateMachine.onStop = { reason in
            stopReasonBox.set(reason)
        }

        let stopSuccess = stateMachine.stopRecording(reason: .userToggle)
        XCTAssertTrue(stopSuccess)
        XCTAssertEqual(stateMachine.currentState, .processing)
        XCTAssertEqual(stateMachine.lastStopReason, .userToggle)
        XCTAssertEqual(stopReasonBox.value, .userToggle)

        // 3. Concluir Processamento
        let finishSuccess = stateMachine.finishProcessing()
        XCTAssertTrue(finishSuccess)
        XCTAssertEqual(stateMachine.currentState, .idle)

        // Verificar histórico de transições
        let transitions = recordedTransitions.values
        XCTAssertEqual(transitions.count, 3)
        XCTAssertEqual(transitions[0].0, .idle)
        XCTAssertEqual(transitions[0].1, .recording)
        XCTAssertEqual(transitions[1].0, .recording)
        XCTAssertEqual(transitions[1].1, .processing)
        XCTAssertEqual(transitions[2].0, .processing)
        XCTAssertEqual(transitions[2].1, .idle)
    }

    // MARK: - Cancelamento por Escape

    func testCancellationViaEscapeFromRecording() {
        stateMachine.startRecording()
        XCTAssertEqual(stateMachine.currentState, .recording)

        let stopReasonBox = TestBox<RecordingStopReason>()
        stateMachine.onStop = { reason in
            stopReasonBox.set(reason)
        }

        let cancelSuccess = stateMachine.cancelRecording()
        XCTAssertTrue(cancelSuccess)
        XCTAssertEqual(stateMachine.currentState, .cancelled)
        XCTAssertEqual(stateMachine.lastStopReason, .userCancelled)
        XCTAssertEqual(stopReasonBox.value, .userCancelled)

        // Pode iniciar nova gravação a partir de cancelado
        let restartSuccess = stateMachine.startRecording()
        XCTAssertTrue(restartSuccess)
        XCTAssertEqual(stateMachine.currentState, .recording)
    }

    func testCancellationFromProcessing() {
        stateMachine.startRecording()
        stateMachine.stopRecording()
        XCTAssertEqual(stateMachine.currentState, .processing)

        let cancelSuccess = stateMachine.cancelRecording()
        XCTAssertTrue(cancelSuccess)
        XCTAssertEqual(stateMachine.currentState, .cancelled)
    }

    // MARK: - Timeout de Silêncio

    func testSilenceTimeoutStopReason() {
        stateMachine.startRecording()

        let stopReasonBox = TestBox<RecordingStopReason>()
        stateMachine.onStop = { reason in
            stopReasonBox.set(reason)
        }

        let timeoutSuccess = stateMachine.handleSilenceTimeout()
        XCTAssertTrue(timeoutSuccess)
        XCTAssertEqual(stateMachine.currentState, .processing)
        XCTAssertEqual(stateMachine.lastStopReason, .silenceTimeout)
        XCTAssertEqual(stopReasonBox.value, .silenceTimeout)
    }

    // MARK: - Transições Inválidas

    func testInvalidTransitionsAreRejected() {
        // Não pode parar quando já está em idle
        XCTAssertFalse(stateMachine.stopRecording())
        XCTAssertEqual(stateMachine.currentState, .idle)

        // Não pode processar diretamente a partir de idle
        XCTAssertFalse(stateMachine.finishProcessing())
        XCTAssertEqual(stateMachine.currentState, .idle)

        // Não pode cancelar quando está em idle
        XCTAssertFalse(stateMachine.cancelRecording())
        XCTAssertEqual(stateMachine.currentState, .idle)
    }

    // MARK: - Reset

    func testResetReturnsToIdle() {
        stateMachine.startRecording()
        stateMachine.reset()
        XCTAssertEqual(stateMachine.currentState, .idle)
        XCTAssertNil(stateMachine.lastStopReason)
    }
}
