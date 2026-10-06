import XCTest
@testable import Sonotype

// MARK: - Mocks para Testes de Integração do Coordenador

private final class MockTimeProvider: TimeProviding, @unchecked Sendable {
    private let lock = NSLock()
    private var currentTime: Date

    init(initialTime: Date = Date(timeIntervalSince1970: 1000.0)) {
        self.currentTime = initialTime
    }

    func now() -> Date {
        lock.lock()
        defer { lock.unlock() }
        return currentTime
    }

    func advance(by seconds: TimeInterval) {
        lock.lock()
        defer { lock.unlock() }
        currentTime = currentTime.addingTimeInterval(seconds)
    }
}

@MainActor
private final class MockHotkeyManager: GlobalHotkeyMonitoring, Sendable {
    var isEnabled: Bool = true
    var currentHotkey: GlobalHotkey = .defaultToggle

    var hotkeyAction: (@MainActor @Sendable () -> Void)?
    var escapeAction: (@MainActor @Sendable () -> Void)?

    func startMonitoring() {}
    func stopMonitoring() {}

    func onHotkeyPressed(_ action: @escaping @MainActor @Sendable () -> Void) {
        self.hotkeyAction = action
    }

    func onEscapePressed(_ action: @escaping @MainActor @Sendable () -> Void) {
        self.escapeAction = action
    }

    func simulateHotkeyPressed() {
        guard isEnabled else { return }
        hotkeyAction?()
    }

    func simulateEscapePressed() {
        guard isEnabled else { return }
        escapeAction?()
    }
}

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

// MARK: - Testes do RecordingSessionCoordinator

@MainActor
final class RecordingSessionCoordinatorTests: XCTestCase {
    private var stateMachine: RecordingStateMachine!
    private var mockHotkey: MockHotkeyManager!
    private var mockClock: MockTimeProvider!
    private var silenceManager: SilenceTimeoutManager!
    private var mockSound: MockFeedbackSoundPlayer!
    private var coordinator: RecordingSessionCoordinator!

    override func setUp() async throws {
        try await super.setUp()
        stateMachine = RecordingStateMachine(hotkeyMode: .toggle)
        mockHotkey = MockHotkeyManager()
        mockClock = MockTimeProvider()
        silenceManager = SilenceTimeoutManager(
            timeoutDuration: 45.0,
            silenceThreshold: 0.04,
            timeProvider: mockClock
        )
        mockSound = MockFeedbackSoundPlayer()

        coordinator = RecordingSessionCoordinator(
            stateMachine: stateMachine,
            hotkeyManager: mockHotkey,
            silenceManager: silenceManager,
            soundPlayer: mockSound
        )
    }

    override func tearDown() async throws {
        coordinator.stop()
        coordinator = nil
        silenceManager = nil
        mockSound = nil
        mockHotkey = nil
        mockClock = nil
        stateMachine = nil
        try await super.tearDown()
    }

    // MARK: - Ciclo Toggle Normal (Option + Espaço)

    func testHotkeyToggleLifecycle() async {
        let startCalled = TestBox<Bool>(false)
        let finishReasonBox = TestBox<RecordingStopReason>()

        coordinator.onStartRecording = {
            startCalled.set(true)
        }
        coordinator.onFinishRecording = { reason in
            finishReasonBox.set(reason)
        }

        // 1. Primeiro toque de atalho: Iniciar
        mockHotkey.simulateHotkeyPressed()

        XCTAssertEqual(stateMachine.currentState, .recording)
        XCTAssertTrue(startCalled.value ?? false)
        XCTAssertEqual(mockSound.startSoundCount, 1)
        XCTAssertTrue(silenceManager.isRunning)

        // 2. Segundo toque de atalho: Finalizar
        mockHotkey.simulateHotkeyPressed()

        // Aguarda a conclusão assíncrona do processamento
        try? await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(stateMachine.currentState, .idle)
        XCTAssertEqual(finishReasonBox.value, .userToggle)
        XCTAssertEqual(mockSound.stopSoundCount, 1)
        XCTAssertFalse(silenceManager.isRunning)
    }

    // MARK: - Ciclo de Cancelamento por Escape

    func testEscapeCancellationLifecycle() {
        let cancelCalled = TestBox<Bool>(false)
        coordinator.onCancelRecording = {
            cancelCalled.set(true)
        }

        // Inicia gravação
        mockHotkey.simulateHotkeyPressed()
        XCTAssertEqual(stateMachine.currentState, .recording)
        XCTAssertTrue(silenceManager.isRunning)

        // Pressiona Escape para cancelar
        mockHotkey.simulateEscapePressed()

        XCTAssertEqual(stateMachine.currentState, .idle)
        XCTAssertTrue(cancelCalled.value ?? false)
        XCTAssertEqual(mockSound.cancelSoundCount, 1)
        XCTAssertFalse(silenceManager.isRunning)
    }

    func testEscapeWhileIdleDoesNothing() {
        let cancelCalled = TestBox<Bool>(false)
        coordinator.onCancelRecording = {
            cancelCalled.set(true)
        }

        mockHotkey.simulateEscapePressed()

        XCTAssertEqual(stateMachine.currentState, .idle)
        XCTAssertFalse(cancelCalled.value ?? false)
        XCTAssertEqual(mockSound.cancelSoundCount, 0)
    }

    // MARK: - Ciclo de Timeout de Silêncio Contínuo (45s)

    func testSilenceTimeoutAutomaticTrigger() async {
        let finishReasonBox = TestBox<RecordingStopReason>()
        coordinator.onFinishRecording = { reason in
            finishReasonBox.set(reason)
        }

        // Inicia gravação
        mockHotkey.simulateHotkeyPressed()
        XCTAssertEqual(stateMachine.currentState, .recording)

        // 45 segundos de silêncio contínuo
        mockClock.advance(by: 45.0)
        coordinator.feedAudioAmplitude(0.01)

        // Aguarda a finalização assíncrona
        try? await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(stateMachine.currentState, .idle)
        XCTAssertEqual(finishReasonBox.value, .silenceTimeout)
        XCTAssertEqual(mockSound.stopSoundCount, 1)
        XCTAssertFalse(silenceManager.isRunning)
    }
}
