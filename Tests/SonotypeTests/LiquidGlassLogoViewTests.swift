import SwiftUI
import XCTest
@testable import Sonotype

@MainActor
final class LiquidGlassLogoViewTests: XCTestCase {

    // MARK: - Inicialização e Callback

    func testLiquidGlassLogoViewInitialization() {
        var didTriggerAction = false
        let view = LiquidGlassLogoView(state: .idle, size: 36) {
            didTriggerAction = true
        }

        XCTAssertEqual(view.state, .idle)
        XCTAssertEqual(view.size, 36)
        XCTAssertNotNil(view.action)

        view.action?()
        XCTAssertTrue(didTriggerAction)
    }

    func testLiquidGlassLogoViewDefaultParameters() {
        let view = LiquidGlassLogoView()
        XCTAssertEqual(view.state, .idle)
        XCTAssertEqual(view.size, 34)
        XCTAssertNil(view.action)
    }

    // MARK: - Cálculos de Escala da Lente

    func testCalculateLensScale() {
        // Estado em repouso
        let normalScale = LiquidGlassLogoView.calculateLensScale(isHovered: false, isPressed: false)
        XCTAssertEqual(normalScale, 1.0, accuracy: 0.001)

        // Estado com hover ativo
        let hoveredScale = LiquidGlassLogoView.calculateLensScale(isHovered: true, isPressed: false)
        XCTAssertEqual(hoveredScale, 1.05, accuracy: 0.001)

        // Estado de clique/pressão (tem precedência)
        let pressedScale = LiquidGlassLogoView.calculateLensScale(isHovered: true, isPressed: true)
        XCTAssertEqual(pressedScale, 0.92, accuracy: 0.001)

        let pressedNotHoveredScale = LiquidGlassLogoView.calculateLensScale(isHovered: false, isPressed: true)
        XCTAssertEqual(pressedNotHoveredScale, 0.92, accuracy: 0.001)
    }

    // MARK: - Cálculos da Aura Cáustica (Escala e Opacidade)

    func testCalculateAuraScaleAcrossStates() {
        // Idle
        XCTAssertEqual(LiquidGlassLogoView.calculateAuraScale(state: .idle, isHovered: false, isPulsing: false), 1.0, accuracy: 0.001)
        XCTAssertEqual(LiquidGlassLogoView.calculateAuraScale(state: .idle, isHovered: true, isPulsing: false), 1.15, accuracy: 0.001)

        // Recording
        XCTAssertEqual(LiquidGlassLogoView.calculateAuraScale(state: .recording, isHovered: false, isPulsing: false), 1.0, accuracy: 0.001)
        XCTAssertEqual(LiquidGlassLogoView.calculateAuraScale(state: .recording, isHovered: false, isPulsing: true), 1.25, accuracy: 0.001)

        // Processing
        XCTAssertEqual(LiquidGlassLogoView.calculateAuraScale(state: .processing, isHovered: false, isPulsing: false), 1.0, accuracy: 0.001)
        XCTAssertEqual(LiquidGlassLogoView.calculateAuraScale(state: .processing, isHovered: false, isPulsing: true), 1.12, accuracy: 0.001)
    }

    func testCalculateAuraOpacityAcrossStates() {
        // Idle
        XCTAssertEqual(LiquidGlassLogoView.calculateAuraOpacity(state: .idle, isHovered: false, isPulsing: false), 0.18, accuracy: 0.001)
        XCTAssertEqual(LiquidGlassLogoView.calculateAuraOpacity(state: .idle, isHovered: true, isPulsing: false), 0.40, accuracy: 0.001)

        // Recording
        XCTAssertEqual(LiquidGlassLogoView.calculateAuraOpacity(state: .recording, isHovered: false, isPulsing: false), 0.40, accuracy: 0.001)
        XCTAssertEqual(LiquidGlassLogoView.calculateAuraOpacity(state: .recording, isHovered: false, isPulsing: true), 0.65, accuracy: 0.001)

        // Processing
        XCTAssertEqual(LiquidGlassLogoView.calculateAuraOpacity(state: .processing, isHovered: false, isPulsing: false), 0.30, accuracy: 0.001)
        XCTAssertEqual(LiquidGlassLogoView.calculateAuraOpacity(state: .processing, isHovered: false, isPulsing: true), 0.50, accuracy: 0.001)
    }

    // MARK: - Cores Cáusticas e Conformidade WCAG 2.1 AA

    func testCausticColorsPerState() {
        XCTAssertEqual(LiquidGlassLogoView.causticColor(for: .idle), Color.accentColor)
        XCTAssertEqual(LiquidGlassLogoView.causticColor(for: .recording), Color.red)
        XCTAssertEqual(LiquidGlassLogoView.causticColor(for: .processing), Color.orange)
    }

    func testGlyphColorsCalibratedForDarkAndLightModes() {
        for state in [QuickPopoverState.idle, .recording, .processing] {
            let darkColor = LiquidGlassLogoView.glyphColor(for: state, colorScheme: .dark)
            let lightColor = LiquidGlassLogoView.glyphColor(for: state, colorScheme: .light)

            // Garante calibração distinta entre modos claro e escuro para alto contraste
            XCTAssertNotEqual(darkColor, lightColor, "As cores para o estado \(state) devem ser calibradas especificamente para cada esquema.")
        }
    }

    // MARK: - Acessibilidade e Especificações de Vidro

    func testAccessibilityStatusDescriptions() {
        XCTAssertEqual(LiquidGlassLogoView.accessibilityStatusDescription(state: .idle), "Pronto para ditar")
        XCTAssertEqual(LiquidGlassLogoView.accessibilityStatusDescription(state: .recording), "A gravar áudio")
        XCTAssertEqual(LiquidGlassLogoView.accessibilityStatusDescription(state: .processing), "A processar texto")
    }

    func testSpecularBorderThickness() {
        XCTAssertEqual(LiquidGlassLogoView.specularBorderLineWidth(), 1.0, accuracy: 0.001)
    }

    // MARK: - Avaliação do Body em SwiftUI

    func testBodyEvaluationInAllStates() {
        for state in [QuickPopoverState.idle, .recording, .processing] {
            let view = LiquidGlassLogoView(state: state, size: 34)
            _ = view.body
            XCTAssertEqual(view.state, state)
        }
    }
}
