import XCTest
import SwiftUI
@testable import Sonotype

@MainActor
final class GlowPulseViewTests: XCTestCase {
    // MARK: - Cálculos de Escala da Aura (Estética C1)

    func testGlowScaleCalculationZeroAmplitude() {
        let scale = GlowPulseView.calculateGlowScale(amplitude: 0.0)
        XCTAssertEqual(scale, 1.0, accuracy: 0.001, "Com amplitude zero, a escala da aura deve ser 1.0.")
    }

    func testGlowScaleCalculationMidAmplitude() {
        let scale = GlowPulseView.calculateGlowScale(amplitude: 0.5)
        XCTAssertEqual(scale, 1.7, accuracy: 0.001, "Com amplitude 0.5, a escala da aura deve ser 1.7.")
    }

    func testGlowScaleCalculationMaxAmplitude() {
        let scale = GlowPulseView.calculateGlowScale(amplitude: 1.0)
        XCTAssertEqual(scale, 2.4, accuracy: 0.001, "Com amplitude máxima, a escala da aura deve ser 2.4.")
    }

    func testGlowScaleClampingForUnderflowAndOverflow() {
        let scaleUnder = GlowPulseView.calculateGlowScale(amplitude: -0.8)
        XCTAssertEqual(scaleUnder, 1.0, accuracy: 0.001)

        let scaleOver = GlowPulseView.calculateGlowScale(amplitude: 2.5)
        XCTAssertEqual(scaleOver, 2.4, accuracy: 0.001)
    }

    // MARK: - Cálculos de Opacidade da Aura

    func testGlowOpacityCalculationZeroAmplitude() {
        let opacity = GlowPulseView.calculateGlowOpacity(amplitude: 0.0)
        XCTAssertEqual(opacity, 0.25, accuracy: 0.001, "Com amplitude zero, a opacidade base deve ser 0.25.")
    }

    func testGlowOpacityCalculationMaxAmplitude() {
        let opacity = GlowPulseView.calculateGlowOpacity(amplitude: 1.0)
        XCTAssertEqual(opacity, 0.85, accuracy: 0.001, "Com amplitude máxima, a opacidade deve ser 0.85.")
    }

    func testGlowOpacityClamping() {
        let opacityUnder = GlowPulseView.calculateGlowOpacity(amplitude: -1.0)
        XCTAssertEqual(opacityUnder, 0.25, accuracy: 0.001)

        let opacityOver = GlowPulseView.calculateGlowOpacity(amplitude: 3.0)
        XCTAssertEqual(opacityOver, 0.85, accuracy: 0.001)
    }

    // MARK: - Instanciação da View

    @MainActor
    func testViewInstantiationAndProperties() {
        let view = GlowPulseView(amplitude: 0.4, isProcessing: false, tintColor: .red)
        XCTAssertEqual(view.amplitude, 0.4, accuracy: 0.001)
        XCTAssertFalse(view.isProcessing)
        XCTAssertEqual(view.tintColor, .red)
        _ = view.body

        let processingView = GlowPulseView(amplitude: 0.0, isProcessing: true)
        XCTAssertTrue(processingView.isProcessing)
        _ = processingView.body
    }

    @MainActor
    func testFloatingPillViewInstantiation() {
        let config = HUDConfiguration(
            languageBadge: "PT",
            recordingTitle: "A gravar voz...",
            processingTitle: "A formatar...",
            cancelledTitle: "Interrompido"
        )

        let pillView = FloatingPillHUDView(state: .recording, amplitude: 0.6, config: config)
        XCTAssertEqual(pillView.state, .recording)
        XCTAssertEqual(pillView.amplitude, 0.6, accuracy: 0.001)
        XCTAssertEqual(pillView.config.languageBadge, "PT")
        _ = pillView.body
    }
}
