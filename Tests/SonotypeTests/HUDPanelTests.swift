import XCTest
import AppKit
@testable import Sonotype

@MainActor
final class HUDPanelTests: XCTestCase {
    private var panel: HUDPanel!

    override func setUp() async throws {
        try await super.setUp()
        panel = HUDPanel()
    }

    override func tearDown() async throws {
        panel.close()
        panel = nil
        try await super.tearDown()
    }

    // MARK: - Propriedades e Estilo do NSPanel

    func testPanelStyleMaskAndFloatingLevel() {
        XCTAssertTrue(panel.styleMask.contains(.borderless), "HUDPanel deve ser sem moldura (.borderless).")
        XCTAssertTrue(panel.styleMask.contains(.nonactivatingPanel), "HUDPanel deve ser .nonactivatingPanel para não roubar foco.")
        XCTAssertEqual(panel.level, .floating, "HUDPanel deve ter nível flutuante (.floating).")
        XCTAssertTrue(panel.isFloatingPanel, "isFloatingPanel deve ser true.")
    }

    func testPanelTransparencyAndShadow() {
        XCTAssertFalse(panel.isOpaque, "HUDPanel não deve ser opaco.")
        XCTAssertEqual(panel.backgroundColor, .clear, "Fundo da janela do painel deve ser transparente.")
        XCTAssertFalse(panel.hasShadow, "Sombra da janela deve ser false para permitir sombra nativa da pílula SwiftUI.")
    }

    func testPanelFocusInvariants() {
        // Invariante de foco: O HUD flutuante nunca deve roubar o foco do cursor ou da app ativa
        XCTAssertFalse(panel.canBecomeKey, "HUDPanel nunca pode tornar-se key window.")
        XCTAssertFalse(panel.canBecomeMain, "HUDPanel nunca pode tornar-se main window.")
        XCTAssertFalse(panel.hidesOnDeactivate, "HUDPanel não deve esconder-se ao perder ativação de processo.")
    }

    func testPanelCollectionBehavior() {
        let behavior = panel.collectionBehavior
        XCTAssertTrue(behavior.contains(.canJoinAllSpaces), "HUDPanel deve estar presente em todos os Spaces.")
        XCTAssertTrue(behavior.contains(.fullScreenAuxiliary), "HUDPanel deve funcionar como auxiliar em ecrã inteiro.")
        XCTAssertTrue(behavior.contains(.transient), "HUDPanel deve ter comportamento transitório.")
        XCTAssertTrue(behavior.contains(.ignoresCycle), "HUDPanel deve ser ignorado no ciclo de janelas.")
    }

    // MARK: - Posicionamento na Área Visível

    func testRepositionToBottomCenter() {
        guard let screen = NSScreen.main else { return }
        let visibleFrame = screen.visibleFrame
        let bottomMargin: CGFloat = 80.0

        panel.repositionToBottomCenter(on: screen, bottomMargin: bottomMargin)

        let expectedX = round(visibleFrame.origin.x + (visibleFrame.size.width - panel.frame.size.width) / 2.0)
        let expectedY = round(visibleFrame.origin.y + bottomMargin)

        XCTAssertEqual(panel.frame.origin.x, expectedX, accuracy: 1.0)
        XCTAssertEqual(panel.frame.origin.y, expectedY, accuracy: 1.0)
    }
}
