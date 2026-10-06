import SwiftUI

/// Estados visuais de exibição da pílula HUD.
public enum HUDDisplayState: String, Sendable, Equatable, CaseIterable {
    case idle
    case recording
    case processing
    case cancelled
}

/// Configuração textual e visual da pílula HUD.
public struct HUDConfiguration: Sendable, Equatable {
    public var languageBadge: String
    public var recordingTitle: String
    public var processingTitle: String
    public var cancelledTitle: String

    public init(
        languageBadge: String = "PT / EN",
        recordingTitle: String = "A escutar...",
        processingTitle: String = "A processar...",
        cancelledTitle: String = "Cancelado"
    ) {
        self.languageBadge = languageBadge
        self.recordingTitle = recordingTitle
        self.processingTitle = processingTitle
        self.cancelledTitle = cancelledTitle
    }
}

/// Vista SwiftUI da pílula flutuante minimalista (HUD).
/// Envolvida em material translúcido adaptativo nativo Apple (`.regularMaterial`),
/// exibe o ponto luminoso C1, o estado da sessão e o distintivo de idioma.
public struct FloatingPillHUDView: View {
    public let state: HUDDisplayState
    public let amplitude: Float
    public let config: HUDConfiguration

    public init(
        state: HUDDisplayState,
        amplitude: Float,
        config: HUDConfiguration = HUDConfiguration()
    ) {
        self.state = state
        self.amplitude = amplitude
        self.config = config
    }

    public var body: some View {
        HStack(spacing: 12) {
            // Ponto luminoso pulsante C1 reativo à voz
            GlowPulseView(
                amplitude: amplitude,
                isProcessing: state == .processing,
                tintColor: dotColor
            )

            // Texto de estado em SF Pro Text (<= 19pt) com ajuste óptico de tracking
            Text(statusMessage)
                .font(.system(size: 13, weight: .medium, design: .default))
                .tracking(-0.08)
                .foregroundStyle(.primary)
                .lineLimit(1)

            // Distintivo de idioma configurado (PT / EN)
            Text(config.languageBadge)
                .font(.system(size: 10, weight: .semibold, design: .default))
                .tracking(0.2)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(.quaternary, in: Capsule())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(minHeight: 44) // Ergonomia & conformidade Apple HIG (44x44pt)
        .background(
            Capsule(style: .continuous)
                .fill(.regularMaterial)
        )
        .overlay(
            Capsule(style: .continuous)
                .strokeBorder(.separator.opacity(0.35), lineWidth: 0.5)
        )
        .shadow(color: Color.black.opacity(0.18), radius: 14, x: 0, y: 6)
    }

    private var dotColor: Color {
        switch state {
        case .recording:
            return .red
        case .processing:
            return .accentColor
        case .cancelled:
            return .orange
        case .idle:
            return .secondary
        }
    }

    private var statusMessage: String {
        switch state {
        case .recording:
            return config.recordingTitle
        case .processing:
            return config.processingTitle
        case .cancelled:
            return config.cancelledTitle
        case .idle:
            return "Pronto"
        }
    }
}
