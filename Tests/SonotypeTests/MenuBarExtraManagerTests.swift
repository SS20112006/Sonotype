import AppKit
import XCTest
@testable import Sonotype

@MainActor
private final class MockHotkeyForMenuBar: GlobalHotkeyMonitoring, Sendable {
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
        hotkeyAction?()
    }

    func simulateEscapePressed() {
        escapeAction?()
    }
}

@MainActor
final class MenuBarExtraManagerTests: XCTestCase {
    private var manager: MenuBarExtraManager!

    override func setUp() async throws {
        try await super.setUp()
        manager = MenuBarExtraManager()
    }

    override func tearDown() async throws {
        manager.destroy()
        manager = nil
        try await super.tearDown()
    }

    // MARK: - Estado Inicial

    func testInitialState() {
        XCTAssertEqual(manager.currentState, .idle)
        XCTAssertFalse(manager.isPopoverShown)
        XCTAssertNotNil(manager.statusItem.button)
    }

    // MARK: - Transições de Estado

    func testPlaybackStateTransitions() {
        manager.setPlaybackState(.recording)
        XCTAssertEqual(manager.currentState, .recording)

        manager.setPlaybackState(.processing)
        XCTAssertEqual(manager.currentState, .processing)

        manager.setPlaybackState(.idle)
        XCTAssertEqual(manager.currentState, .idle)
    }

    // MARK: - Atualização de Detalhes

    func testUpdateDetails() {
        manager.updateDetails(language: "EN-US", hotkey: "⌥ Espaço")
        // Não deve causar falhas e mantém o estado estável
        XCTAssertEqual(manager.currentState, .idle)
    }

    // MARK: - Integração com RecordingSessionCoordinator

    func testAttachmentToCoordinator() async {
        let mockHotkey = MockHotkeyForMenuBar()
        let stateMachine = RecordingStateMachine(hotkeyMode: .toggle)
        let silenceManager = SilenceTimeoutManager(timeoutDuration: 45.0)
        let soundPlayer = MockFeedbackSoundPlayer()

        let coordinator = RecordingSessionCoordinator(
            stateMachine: stateMachine,
            hotkeyManager: mockHotkey,
            silenceManager: silenceManager,
            soundPlayer: soundPlayer
        )

        manager.attach(to: coordinator)

        // 1. Inicia gravação via hotkey
        mockHotkey.simulateHotkeyPressed()
        XCTAssertEqual(coordinator.stateMachine.currentState, .recording)
        XCTAssertEqual(manager.currentState, .recording)

        // 2. Cancela gravação via Escape
        mockHotkey.simulateEscapePressed()
        XCTAssertEqual(coordinator.stateMachine.currentState, .idle)
        XCTAssertEqual(manager.currentState, .idle)

        coordinator.stop()
    }

    func testToggleRecordingFromMenuBarAction() {
        let mockHotkey = MockHotkeyForMenuBar()
        let stateMachine = RecordingStateMachine(hotkeyMode: .toggle)
        let silenceManager = SilenceTimeoutManager(timeoutDuration: 45.0)
        let soundPlayer = MockFeedbackSoundPlayer()

        let coordinator = RecordingSessionCoordinator(
            stateMachine: stateMachine,
            hotkeyManager: mockHotkey,
            silenceManager: silenceManager,
            soundPlayer: soundPlayer
        )

        manager.attach(to: coordinator)

        // Simula clique no botão de alternar ditado no popover
        manager.onToggleRecording?()
        XCTAssertEqual(coordinator.stateMachine.currentState, .recording)
        XCTAssertEqual(manager.currentState, .recording)

        coordinator.stop()
    }

    func testAttachmentPreservesExistingHandlers() async {
        let mockHotkey = MockHotkeyForMenuBar()
        let stateMachine = RecordingStateMachine(hotkeyMode: .toggle)
        let silenceManager = SilenceTimeoutManager(timeoutDuration: 45.0)
        let soundPlayer = MockFeedbackSoundPlayer()

        let coordinator = RecordingSessionCoordinator(
            stateMachine: stateMachine,
            hotkeyManager: mockHotkey,
            silenceManager: silenceManager,
            soundPlayer: soundPlayer
        )

        var originalStartInvoked = false
        var originalFinishInvoked = false
        var originalCancelInvoked = false

        coordinator.onStartRecording = {
            originalStartInvoked = true
        }
        coordinator.onFinishRecording = { _ in
            originalFinishInvoked = true
        }
        coordinator.onCancelRecording = {
            originalCancelInvoked = true
        }

        manager.attach(to: coordinator)

        // 1. Inicia gravação: manager deve ir para .recording e originalStart deve disparar
        mockHotkey.simulateHotkeyPressed()
        XCTAssertEqual(manager.currentState, .recording)
        XCTAssertTrue(originalStartInvoked)

        // 2. Finaliza gravação: manager transita por .processing/.idle e originalFinish deve disparar
        mockHotkey.simulateHotkeyPressed()
        for _ in 0..<50 {
            if originalFinishInvoked { break }
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
        XCTAssertTrue(originalFinishInvoked)
        XCTAssertEqual(manager.currentState, .idle)

        // 3. Inicia novamente e cancela via escape: originalCancel deve disparar
        mockHotkey.simulateHotkeyPressed()
        mockHotkey.simulateEscapePressed()
        XCTAssertTrue(originalCancelInvoked)
        XCTAssertEqual(manager.currentState, .idle)

        coordinator.stop()
    }
}
