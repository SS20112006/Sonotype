import XCTest
@testable import Sonotype

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

@MainActor
final class SilenceTimeoutManagerTests: XCTestCase {
    private var mockClock: MockTimeProvider!
    private var manager: SilenceTimeoutManager!

    override func setUp() async throws {
        try await super.setUp()
        mockClock = MockTimeProvider()
        manager = SilenceTimeoutManager(
            timeoutDuration: 45.0,
            silenceThreshold: 0.04,
            timeProvider: mockClock
        )
    }

    override func tearDown() async throws {
        manager.stop()
        manager = nil
        mockClock = nil
        try await super.tearDown()
    }

    // MARK: - Estado Inicial & Padrões

    func testDefaultInitialization() {
        let defaultMgr = SilenceTimeoutManager()
        XCTAssertEqual(defaultMgr.timeoutDuration, 45.0)
        XCTAssertEqual(defaultMgr.silenceThreshold, 0.04)
        XCTAssertFalse(defaultMgr.isRunning)
    }

    // MARK: - Disparo do Timeout de 45 Segundos

    func testContinuousSilenceTriggersTimeoutAfter45Seconds() {
        let timeoutTriggered = TestBox<Bool>(false)
        manager.onSilenceTimeout = {
            timeoutTriggered.set(true)
        }

        manager.start()
        XCTAssertTrue(manager.isRunning)

        // 30 segundos de silêncio (amplitude abaixo do limiar)
        mockClock.advance(by: 30.0)
        manager.feedAmplitude(0.01)
        XCTAssertFalse(timeoutTriggered.value ?? false, "Não deve disparar aos 30 segundos.")
        XCTAssertTrue(manager.isRunning)

        // Mais 15 segundos -> total de 45 segundos de silêncio contínuo
        mockClock.advance(by: 15.0)
        manager.feedAmplitude(0.01)

        XCTAssertTrue(timeoutTriggered.value ?? false, "Deve disparar aos 45 segundos de silêncio contínuo.")
        XCTAssertFalse(manager.isRunning, "O gestor deve parar automaticamente após disparar.")
    }

    // MARK: - Reinício do Contador com Fala Ativa

    func testVoiceActivityResetsSilenceTimer() {
        let timeoutTriggered = TestBox<Bool>(false)
        manager.onSilenceTimeout = {
            timeoutTriggered.set(true)
        }

        manager.start()

        // 40 segundos de silêncio
        mockClock.advance(by: 40.0)
        manager.feedAmplitude(0.02)
        XCTAssertFalse(timeoutTriggered.value ?? false)

        // Voz detetada (amplitude 0.35 >= limiar 0.04)
        manager.feedAmplitude(0.35)
        XCTAssertEqual(manager.currentSilenceDuration(), 0.0, accuracy: 0.001)

        // Passam mais 20 segundos de silêncio
        mockClock.advance(by: 20.0)
        manager.feedAmplitude(0.01)
        XCTAssertFalse(timeoutTriggered.value ?? false, "Tempo decorrido total é 60s, mas contínuo é apenas 20s.")

        // Passam mais 25 segundos (atingindo 45s de silêncio contínuo desde a última fala)
        mockClock.advance(by: 25.0)
        manager.feedAmplitude(0.01)
        XCTAssertTrue(timeoutTriggered.value ?? false, "Deve disparar ao atingir 45s desde a última voz.")
    }

    // MARK: - Timeout Desativado

    func testDisabledTimeoutNeverTriggers() {
        manager.timeoutDuration = nil
        let timeoutTriggered = TestBox<Bool>(false)
        manager.onSilenceTimeout = {
            timeoutTriggered.set(true)
        }

        manager.start()
        mockClock.advance(by: 300.0) // 5 minutos de silêncio
        manager.feedAmplitude(0.0)

        XCTAssertFalse(timeoutTriggered.value ?? false, "Com timeoutDuration = nil, nunca deve disparar.")
        XCTAssertTrue(manager.isRunning)
    }

    // MARK: - Durações Personalizadas

    func testCustomTimeoutDuration15Seconds() {
        manager.timeoutDuration = 15.0
        let timeoutTriggered = TestBox<Bool>(false)
        manager.onSilenceTimeout = {
            timeoutTriggered.set(true)
        }

        manager.start()
        mockClock.advance(by: 14.9)
        manager.feedAmplitude(0.0)
        XCTAssertFalse(timeoutTriggered.value ?? false)

        mockClock.advance(by: 0.2)
        manager.feedAmplitude(0.0)
        XCTAssertTrue(timeoutTriggered.value ?? false)
    }

    // MARK: - Paragem e Reset

    func testStopCancelsMonitoring() {
        manager.start()
        XCTAssertTrue(manager.isRunning)
        manager.stop()
        XCTAssertFalse(manager.isRunning)

        let timeoutTriggered = TestBox<Bool>(false)
        manager.onSilenceTimeout = {
            timeoutTriggered.set(true)
        }

        mockClock.advance(by: 100.0)
        manager.feedAmplitude(0.0)
        XCTAssertFalse(timeoutTriggered.value ?? false, "Não deve disparar se estiver parado.")
    }
}
