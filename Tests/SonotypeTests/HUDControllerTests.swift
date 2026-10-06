import XCTest
@testable import Sonotype

// MARK: - Mock para Suporte aos Testes de Integração do HUD

@MainActor
private final class MockHotkeyForHUD: GlobalHotkeyMonitoring, Sendable {
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

    func triggerHotkey() {
        hotkeyAction?()
    }

    func triggerEscape() {
        escapeAction?()
    }
}

// MARK: - Testes do HUDController

@MainActor
final class HUDControllerTests: XCTestCase {
    private var controller: HUDController!

    override func setUp() async throws {
        try await super.setUp()
        controller = HUDController()
    }

    override func tearDown() async throws {
        controller.reset()
        controller = nil
        try await super.tearDown()
    }

    // MARK: - Ciclo de Exibição e Ocultação

    func testInitialState() {
        XCTAssertFalse(controller.viewModel.isVisible)
        XCTAssertEqual(controller.viewModel.displayState, .idle)
        XCTAssertEqual(controller.viewModel.amplitude, 0.0)
    }

    func testShowRecordingState() {
        controller.show(state: .recording)

        XCTAssertTrue(controller.viewModel.isVisible)
        XCTAssertEqual(controller.viewModel.displayState, .recording)
    }

    func testHideImmediate() {
        controller.show(state: .recording)
        XCTAssertTrue(controller.viewModel.isVisible)

        controller.hide(animated: false)

        XCTAssertFalse(controller.viewModel.isVisible)
        XCTAssertEqual(controller.viewModel.displayState, .idle)
        XCTAssertEqual(controller.viewModel.amplitude, 0.0)
    }

    // MARK: - Atualização de Amplitude Vocal

    func testUpdateAmplitudeWhenRecording() {
        controller.show(state: .recording)

        controller.updateAmplitude(0.45)
        XCTAssertEqual(controller.viewModel.amplitude, 0.45, accuracy: 0.001)

        // Limites
        controller.updateAmplitude(1.8)
        XCTAssertEqual(controller.viewModel.amplitude, 1.0, accuracy: 0.001)

        controller.updateAmplitude(-0.5)
        XCTAssertEqual(controller.viewModel.amplitude, 0.0, accuracy: 0.001)
    }

    func testUpdateAmplitudeIgnoredWhenHiddenOrIdle() {
        controller.hide(animated: false)

        controller.updateAmplitude(0.8)
        XCTAssertEqual(controller.viewModel.amplitude, 0.0, "Não deve atualizar amplitude com HUD oculto.")
    }

    // MARK: - Estados de Processamento e Cancelamento

    func testSetProcessing() {
        controller.show(state: .recording)
        controller.updateAmplitude(0.7)

        controller.setProcessing()

        XCTAssertEqual(controller.viewModel.displayState, .processing)
        XCTAssertEqual(controller.viewModel.amplitude, 0.0, "Amplitude deve ser zerada em processamento.")
    }

    func testSetCancelled() {
        controller.show(state: .recording)
        controller.updateAmplitude(0.5)

        controller.setCancelled()

        XCTAssertEqual(controller.viewModel.displayState, .cancelled)
        XCTAssertEqual(controller.viewModel.amplitude, 0.0)
    }

    // MARK: - Integração com RecordingSessionCoordinator

    func testCoordinatorAttachmentLifecycle() async {
        let mockHotkey = MockHotkeyForHUD()
        let stateMachine = RecordingStateMachine(hotkeyMode: .toggle)
        let silenceManager = SilenceTimeoutManager(timeoutDuration: 45.0)
        let soundPlayer = MockFeedbackSoundPlayer()

        let coordinator = RecordingSessionCoordinator(
            stateMachine: stateMachine,
            hotkeyManager: mockHotkey,
            silenceManager: silenceManager,
            soundPlayer: soundPlayer
        )

        // Vincula HUD ao Coordenador
        controller.attach(to: coordinator)

        // 1. Inicia sessão via hotkey
        mockHotkey.triggerHotkey()

        XCTAssertEqual(stateMachine.currentState, .recording)
        XCTAssertTrue(controller.viewModel.isVisible)
        XCTAssertEqual(controller.viewModel.displayState, .recording)

        // 2. Alimenta amplitude vocal
        coordinator.feedAudioAmplitude(0.62)
        XCTAssertEqual(controller.viewModel.amplitude, 0.62, accuracy: 0.001)

        // 3. Cancela via Escape
        mockHotkey.triggerEscape()

        XCTAssertEqual(stateMachine.currentState, .idle)
        XCTAssertEqual(controller.viewModel.displayState, .cancelled)

        coordinator.stop()
    }
}
