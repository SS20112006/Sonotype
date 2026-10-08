import AppKit
import XCTest
@testable import Sonotype

@MainActor
private final class MockActivationPolicyController: ActivationPolicyControlling, Sendable {
    var policy: NSApplication.ActivationPolicy = .accessory
    var recordedChanges: [NSApplication.ActivationPolicy] = []

    var activationPolicy: NSApplication.ActivationPolicy {
        policy
    }

    @discardableResult
    func setActivationPolicy(_ newPolicy: NSApplication.ActivationPolicy) -> Bool {
        policy = newPolicy
        recordedChanges.append(newPolicy)
        return true
    }
}

@MainActor
final class DockVisibilityCoordinatorTests: XCTestCase {
    private var mockController: MockActivationPolicyController!
    private var coordinator: DockVisibilityCoordinator!

    override func setUp() async throws {
        try await super.setUp()
        mockController = MockActivationPolicyController()
        coordinator = DockVisibilityCoordinator(initialMode: .dynamic, policyController: mockController)
    }

    override func tearDown() async throws {
        coordinator.stopObservingWindowNotifications()
        coordinator = nil
        mockController = nil
        try await super.tearDown()
    }

    // MARK: - Modo Híbrido Dinâmico

    func testInitialDynamicStateIsAccessoryWithZeroWindows() {
        XCTAssertEqual(coordinator.currentMode, .dynamic)
        XCTAssertEqual(coordinator.activeWindowCount, 0)
        XCTAssertEqual(mockController.policy, .accessory, "Em repouso sem janelas, o Sonotype deve ser .accessory.")
    }

    func testOpeningWindowTransitionsToRegularInDynamicMode() {
        coordinator.windowDidOpen()

        XCTAssertEqual(coordinator.activeWindowCount, 1)
        XCTAssertEqual(mockController.policy, .regular, "Com janela aberta, deve transitar para .regular na Dock.")
        XCTAssertEqual(coordinator.currentPolicy, .regular)
    }

    func testClosingLastWindowReturnsToAccessoryInDynamicMode() {
        coordinator.windowDidOpen()
        coordinator.windowDidOpen()
        XCTAssertEqual(coordinator.activeWindowCount, 2)
        XCTAssertEqual(mockController.policy, .regular)

        coordinator.windowDidClose()
        XCTAssertEqual(coordinator.activeWindowCount, 1)
        XCTAssertEqual(mockController.policy, .regular, "Ainda resta 1 janela, deve continuar .regular.")

        coordinator.windowDidClose()
        XCTAssertEqual(coordinator.activeWindowCount, 0)
        XCTAssertEqual(mockController.policy, .accessory, "Última janela fechada, deve recolher para .accessory.")
    }

    func testWindowCloseUnderflowClampedToZero() {
        coordinator.windowDidClose()
        coordinator.windowDidClose()

        XCTAssertEqual(coordinator.activeWindowCount, 0)
        XCTAssertEqual(mockController.policy, .accessory)
    }

    func testUpdateWindowCountExplicitly() {
        coordinator.updateWindowCount(3)
        XCTAssertEqual(coordinator.activeWindowCount, 3)
        XCTAssertEqual(mockController.policy, .regular)

        coordinator.updateWindowCount(0)
        XCTAssertEqual(coordinator.activeWindowCount, 0)
        XCTAssertEqual(mockController.policy, .accessory)
    }

    // MARK: - Modos Alternativos (MenuBarOnly & AlwaysDock)

    func testMenuBarOnlyModeAlwaysAccessoryEvenWithWindows() {
        coordinator.setMode(.menuBarOnly)
        XCTAssertEqual(mockController.policy, .accessory)

        coordinator.windowDidOpen()
        XCTAssertEqual(coordinator.activeWindowCount, 1)
        XCTAssertEqual(mockController.policy, .accessory, "No modo menuBarOnly, mesmo com janelas abertas deve manter-se .accessory.")
    }

    func testAlwaysDockModeAlwaysRegularEvenWithoutWindows() {
        coordinator.setMode(.alwaysDock)
        XCTAssertEqual(mockController.policy, .regular, "No modo alwaysDock, deve ser .regular mesmo sem janelas abertas.")

        coordinator.windowDidOpen()
        XCTAssertEqual(mockController.policy, .regular)

        coordinator.windowDidClose()
        XCTAssertEqual(mockController.policy, .regular)
    }

    func testSwitchingBackToDynamicReevaluatesActiveWindows() {
        coordinator.setMode(.alwaysDock)
        XCTAssertEqual(mockController.policy, .regular)

        // Com 0 janelas abertas, voltar a Dynamic deve regressar a .accessory
        coordinator.setMode(.dynamic)
        XCTAssertEqual(mockController.policy, .accessory)

        // Abre 1 janela e muda para MenuBarOnly, depois regressa a Dynamic
        coordinator.windowDidOpen()
        coordinator.setMode(.menuBarOnly)
        XCTAssertEqual(mockController.policy, .accessory)

        coordinator.setMode(.dynamic)
        XCTAssertEqual(mockController.policy, .regular)
    }

    // MARK: - Filtro de Janelas Regulares

    func testIsRegularWindowFilter() {
        let regularWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        let hudPanel = HUDPanel()
        let plainPanel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 200, height: 100),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        XCTAssertTrue(DockVisibilityCoordinator.isRegularWindow(regularWindow), "Janelas com título normais são regulares.")
        XCTAssertFalse(DockVisibilityCoordinator.isRegularWindow(hudPanel), "HUDPanel flutuante nunca deve ser considerado janela regular.")
        XCTAssertFalse(DockVisibilityCoordinator.isRegularWindow(plainPanel), "NSPanel sem moldura não é janela regular.")
    }

    // MARK: - Ciclo de Notificações

    func testStartAndStopObservingNotifications() {
        coordinator.startObservingWindowNotifications()
        // Executa sem crash e limpa de seguida
        coordinator.stopObservingWindowNotifications()
    }
}
