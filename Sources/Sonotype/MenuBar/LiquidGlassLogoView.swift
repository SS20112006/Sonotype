import SwiftUI

/// Componente de logótipo "Liquid Glass" com estética premium Apple HIG e lente fosca translúcida.
/// Implementa profundidade vítrea multicamadas:
/// - Fundo cáustico difuso com pulso líquido dinâmico (idle, recording, processing)
/// - Corpo em material semântico (.ultraThinMaterial) com curvatura refrativa
/// - Borda especular interna chanfrada (strokeBorder com gradiente linear)
/// - Glint especular superior (fresnel)
/// - Glifo central de onda sonora com contraste WCAG 2.1 AA (mínimo 4.5:1)
/// - Ergonomia tátil com alvo de clique mínimo de 44x44pt e feedback sensorial (.sensoryFeedback).
public struct LiquidGlassLogoView: View {
    @Environment(\.colorScheme) private var colorScheme

    public let state: QuickPopoverState
    public let size: CGFloat
    public var action: (() -> Void)?

    @State private var isHovered: Bool = false
    @State private var isPulsing: Bool = false
    @State private var tapFeedbackTrigger: Int = 0

    public init(
        state: QuickPopoverState = .idle,
        size: CGFloat = 34,
        action: (() -> Void)? = nil
    ) {
        self.state = state
        self.size = size
        self.action = action
    }

    public var body: some View {
        Button(action: {
            tapFeedbackTrigger += 1
            action?()
        }) {
            ZStack {
                // Camada 0: Aura cáustica externa e pulso líquido ambiente
                causticAuraLayer

                // Camada 1: Onda de propagação líquida (ativa em gravação)
                if state == .recording {
                    liquidRippleRing
                }

                // Camada 2: Corpo da lente de vidro fosco (Liquid Glass Lens)
                glassLensBody

                // Camada 3: Glifo central em vibração acústica (Waveform)
                centerGlyphLayer

                // Camada 4: Glint especular superior de reflexão curvada
                specularGlintLayer

                // Camada 5: Borda chanfrada especular de alta precisão
                specularBorderLayer
            }
            .frame(width: size, height: size)
            .scaleEffect(Self.calculateLensScale(isHovered: isHovered, isPressed: false))
            .animation(.spring(response: 0.28, dampingFraction: 0.72), value: isHovered)
        }
        .buttonStyle(LiquidGlassButtonStyle(isHovered: isHovered))
        // Ergonomia Apple HIG: Alvo de toque/clique mínimo de 44x44pt
        .frame(minWidth: 44, minHeight: 44)
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovered = hovering
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
                isPulsing = true
            }
        }
        .sensoryFeedback(.impact(weight: .medium, intensity: 0.8), trigger: tapFeedbackTrigger)
        .help(tooltipText)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Logótipo Sonotype")
        .accessibilityValue(Self.accessibilityStatusDescription(state: state))
        .accessibilityHint(action != nil ? "Clique para alternar o ditado de voz" : "")
        .accessibilityAddTraits(.isButton)
    }

    // MARK: - Subcamadas Visuais

    /// Aura cáustica com difusão líquida reativa ao estado de voz e hover.
    @ViewBuilder
    private var causticAuraLayer: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [
                        Self.causticColor(for: state).opacity(
                            Self.calculateAuraOpacity(state: state, isHovered: isHovered, isPulsing: isPulsing)
                        ),
                        Self.causticColor(for: state).opacity(0.0)
                    ],
                    center: .center,
                    startRadius: size * 0.1,
                    endRadius: size * 0.75
                )
            )
            .frame(width: size * 1.5, height: size * 1.5)
            .scaleEffect(Self.calculateAuraScale(state: state, isHovered: isHovered, isPulsing: isPulsing))
            .blur(radius: isHovered ? 8 : (state == .recording ? 6 : 4))
            .animation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true), value: isPulsing)
    }

    /// Anel de ondulação líquida com efeito de expansão radial durante gravação.
    @ViewBuilder
    private var liquidRippleRing: some View {
        Circle()
            .stroke(
                Self.causticColor(for: state).opacity(isPulsing ? 0.0 : 0.55),
                lineWidth: 1.2
            )
            .frame(width: size, height: size)
            .scaleEffect(isPulsing ? 1.38 : 1.02)
            .animation(.easeOut(duration: 1.4).repeatForever(autoreverses: false), value: isPulsing)
    }

    /// Lente física de vidro líquido: material semântico + curvatura e sombreamento óptico.
    @ViewBuilder
    private var glassLensBody: some View {
        Circle()
            .fill(.ultraThinMaterial)
            // Gradiente refrativo de espessura de vidro
            .overlay(
                Circle()
                    .fill(
                        LinearGradient(
                            stops: [
                                .init(color: .white.opacity(0.22), location: 0.0),
                                .init(color: .white.opacity(0.04), location: 0.45),
                                .init(color: .black.opacity(0.12), location: 1.0)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            // Núcleo cáustico interno
            .overlay(
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Self.causticColor(for: state).opacity(isHovered ? 0.24 : 0.14),
                                .clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: size * 0.48
                        )
                    )
            )
            // Sombra ambiente de profundidade
            .shadow(
                color: Color.black.opacity(colorScheme == .dark ? 0.45 : 0.15),
                radius: isHovered ? 5 : 3,
                x: 0,
                y: isHovered ? 2.5 : 1.5
            )
    }

    /// Glifo central em vibração acústica (Waveform).
    @ViewBuilder
    private var centerGlyphLayer: some View {
        let glyphColor = Self.glyphColor(for: state, colorScheme: colorScheme)

        if let logo = SonotypeBrandAsset.logoImage {
            Image(nsImage: logo)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: size * 0.72, height: size * 0.72)
                .clipShape(RoundedRectangle(cornerRadius: size * 0.16, style: .continuous))
                .scaleEffect(state == .recording ? (isPulsing ? 1.06 : 0.96) : 1.0)
                .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: isPulsing)
        } else {
            Image(systemName: "waveform")
                .font(.system(size: size * 0.44, weight: .semibold, design: .default)) // SF Pro Text <= 19pt
                .foregroundStyle(glyphColor)
                .shadow(color: Self.causticColor(for: state).opacity(0.45), radius: isHovered ? 2.5 : 1.5, x: 0, y: 0.5)
                .scaleEffect(state == .recording ? (isPulsing ? 1.06 : 0.96) : 1.0)
                .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: isPulsing)
        }
    }

    /// Glint especular superior (reflexão curvada de luz ambiente).
    @ViewBuilder
    private var specularGlintLayer: some View {
        Ellipse()
            .fill(
                LinearGradient(
                    stops: [
                        .init(color: .white.opacity(colorScheme == .dark ? 0.55 : 0.70), location: 0.0),
                        .init(color: .white.opacity(0.15), location: 0.4),
                        .init(color: .clear, location: 1.0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(width: size * 0.65, height: size * 0.32)
            .offset(y: -size * 0.22)
            .blur(radius: 0.4)
            .clipShape(Circle().inset(by: 1.0))
    }

    /// Borda chanfrada de alta precisão especular com espessura de 1pt.
    @ViewBuilder
    private var specularBorderLayer: some View {
        Circle()
            .strokeBorder(
                LinearGradient(
                    stops: [
                        .init(color: .white.opacity(0.85), location: 0.0),
                        .init(color: .white.opacity(0.35), location: 0.3),
                        .init(color: .white.opacity(0.08), location: 0.65),
                        .init(color: .white.opacity(0.40), location: 1.0)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: Self.specularBorderLineWidth()
            )
    }

    // MARK: - Acessibilidade & Textos

    private var tooltipText: String {
        switch state {
        case .idle:
            return "Sonotype — Pronto para ditar"
        case .recording:
            return "Sonotype — A gravar voz (clique para parar)"
        case .processing:
            return "Sonotype — A processar áudio..."
        }
    }

    // MARK: - Cálculos e Métodos Puros Testáveis

    /// Escala do corpo da lente em repouso, hover ou clique.
    public static func calculateLensScale(isHovered: Bool, isPressed: Bool) -> CGFloat {
        if isPressed {
            return 0.92
        } else if isHovered {
            return 1.05
        } else {
            return 1.0
        }
    }

    /// Escala da aura cáustica externa de acordo com estado, hover e pulso.
    public static func calculateAuraScale(state: QuickPopoverState, isHovered: Bool, isPulsing: Bool) -> CGFloat {
        switch state {
        case .idle:
            return isHovered ? 1.15 : 1.0
        case .recording:
            return isPulsing ? 1.25 : 1.0
        case .processing:
            return isPulsing ? 1.12 : 1.0
        }
    }

    /// Opacidade da aura cáustica de acordo com o estado e interação.
    public static func calculateAuraOpacity(state: QuickPopoverState, isHovered: Bool, isPulsing: Bool) -> Double {
        switch state {
        case .idle:
            return isHovered ? 0.40 : 0.18
        case .recording:
            return isPulsing ? 0.65 : 0.40
        case .processing:
            return isPulsing ? 0.50 : 0.30
        }
    }

    /// Cor base do brilho cáustico de acordo com o estado do motor.
    public static func causticColor(for state: QuickPopoverState) -> Color {
        switch state {
        case .idle:
            return Color.accentColor
        case .recording:
            return Color.red
        case .processing:
            return Color.orange
        }
    }

    /// Cor do glifo central calibrada para garantir contraste WCAG 2.1 AA (mínimo 4.5:1)
    /// contra o fundo de material nos modos Claro e Escuro.
    public static func glyphColor(for state: QuickPopoverState, colorScheme: ColorScheme) -> Color {
        switch state {
        case .idle:
            return colorScheme == .dark
                ? Color(red: 0.35, green: 0.75, blue: 1.0)
                : Color(red: 0.0, green: 0.45, blue: 0.88)
        case .recording:
            return colorScheme == .dark
                ? Color(red: 1.0, green: 0.35, blue: 0.38)
                : Color(red: 0.82, green: 0.12, blue: 0.14)
        case .processing:
            return colorScheme == .dark
                ? Color(red: 1.0, green: 0.68, blue: 0.22)
                : Color(red: 0.78, green: 0.38, blue: 0.02)
        }
    }

    /// Descrição acessível do estado para VoiceOver.
    public static func accessibilityStatusDescription(state: QuickPopoverState) -> String {
        switch state {
        case .idle:
            return "Pronto para ditar"
        case .recording:
            return "A gravar áudio"
        case .processing:
            return "A processar texto"
        }
    }

    /// Espessura da borda chanfrada especular de vidro.
    public static func specularBorderLineWidth() -> CGFloat {
        1.0
    }
}

/// Estilo de botão tátil para o logótipo Liquid Glass que oferece animação de pressão com mola suave.
private struct LiquidGlassButtonStyle: ButtonStyle {
    let isHovered: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .opacity(configuration.isPressed ? 0.92 : 1.0)
            .animation(.spring(response: 0.22, dampingFraction: 0.7), value: configuration.isPressed)
    }
}
