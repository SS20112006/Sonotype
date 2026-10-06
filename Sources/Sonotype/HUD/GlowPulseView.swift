import SwiftUI

/// Componente visual do ponto luminoso pulsante (Estética C1).
/// Apresenta um ponto minimalista central e uma aura difusa externa que pulsa
/// suavemente em tempo real de acordo com a amplitude vocal recebida.
public struct GlowPulseView: View {
    public let amplitude: Float
    public let isProcessing: Bool
    public let tintColor: Color

    @State private var isSpinning: Bool = false

    public init(
        amplitude: Float,
        isProcessing: Bool = false,
        tintColor: Color = .red
    ) {
        self.amplitude = min(max(amplitude, 0.0), 1.0)
        self.isProcessing = isProcessing
        self.tintColor = tintColor
    }

    public var body: some View {
        ZStack {
            if isProcessing {
                // Indicador de processamento discreto e elegante
                Circle()
                    .strokeBorder(Color.accentColor.opacity(0.25), lineWidth: 2)
                    .frame(width: 16, height: 16)

                Circle()
                    .trim(from: 0.0, to: 0.7)
                    .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    .frame(width: 16, height: 16)
                    .rotationEffect(.degrees(isSpinning ? 360 : 0))
                    .onAppear {
                        withAnimation(.linear(duration: 0.9).repeatForever(autoreverses: false)) {
                            isSpinning = true
                        }
                    }
            } else {
                // Aura externa difusa reativa à amplitude (Glow Pulse C1)
                Circle()
                    .fill(tintColor.opacity(Self.calculateGlowOpacity(amplitude: amplitude)))
                    .frame(width: 14, height: 14)
                    .scaleEffect(Self.calculateGlowScale(amplitude: amplitude))
                    .blur(radius: 3.5)

                // Ponto central vibrante com leve realce
                Circle()
                    .fill(tintColor)
                    .frame(width: 8, height: 8)
                    .shadow(color: tintColor.opacity(0.55), radius: 2, x: 0, y: 0)
            }
        }
        .frame(width: 24, height: 24)
        .animation(.spring(response: 0.25, dampingFraction: 0.65), value: amplitude)
    }

    /// Calcula a escala da aura externa em função da amplitude vocal (1.0 a 2.4).
    public static func calculateGlowScale(amplitude: Float) -> CGFloat {
        let clamped = min(max(CGFloat(amplitude), 0.0), 1.0)
        return 1.0 + clamped * 1.4
    }

    /// Calcula a opacidade da aura externa em função da amplitude vocal (0.25 a 0.85).
    public static func calculateGlowOpacity(amplitude: Float) -> Double {
        let clamped = min(max(Double(amplitude), 0.0), 1.0)
        return 0.25 + clamped * 0.60
    }
}
