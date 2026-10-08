import AppKit
import SwiftUI

/// Identificador tipado e enumerado das abas de definições do Sonotype.
public enum SettingsTab: String, CaseIterable, Identifiable, Sendable {
    case general
    case recording
    case textLanguage
    case clipboard
    case stats

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .general:
            return "Geral"
        case .recording:
            return "Gravação"
        case .textLanguage:
            return "Texto & Idioma"
        case .clipboard:
            return "Clipboard"
        case .stats:
            return "Estatísticas"
        }
    }

    public var systemImage: String {
        switch self {
        case .general:
            return "gearshape"
        case .recording:
            return "waveform.badge.mic"
        case .textLanguage:
            return "character.bubble"
        case .clipboard:
            return "doc.on.clipboard"
        case .stats:
            return "chart.bar"
        }
    }
}

/// Componente visual estilizado representando uma tecla física nativa do macOS.
/// Utiliza SF Pro Text monospaced, fundo translúcido sutil e borda hairline (Apple HIG).
public struct KeyCapView: View {
    public let text: String
    public var isHighlighted: Bool = false

    public init(_ text: String, isHighlighted: Bool = false) {
        self.text = text
        self.isHighlighted = isHighlighted
    }

    public var body: some View {
        Text(text)
            .font(.system(size: 13, weight: .semibold, design: .monospaced)) // SF Pro Text <= 19pt
            .tracking(0.0)
            .foregroundStyle(isHighlighted ? Color.accentColor : Color.primary)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .frame(minWidth: 28, minHeight: 28)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(isHighlighted ? Color.accentColor.opacity(0.18) : Color.primary.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(isHighlighted ? Color.accentColor.opacity(0.4) : Color(nsColor: .separatorColor).opacity(0.6), lineWidth: 0.5)
            )
            .shadow(color: Color.black.opacity(0.04), radius: 1, x: 0, y: 1)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(text)
    }
}

/// Cartão estruturado de agrupamento para painéis de definições macOS.
/// Aplica materiais nativos (.regularMaterial), borda hairline e espaçamento equilibrado.
public struct SettingsCard<Content: View>: View {
    public let title: String?
    public let icon: String?
    public let footer: String?
    public let content: Content

    public init(
        title: String? = nil,
        icon: String? = nil,
        footer: String? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.icon = icon
        self.footer = footer
        self.content = content()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let title = title {
                HStack(spacing: 6) {
                    if let icon = icon {
                        Image(systemName: icon)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color.accentColor)
                    }
                    Text(title)
                        .font(.system(size: 12, weight: .semibold, design: .default)) // SF Pro Text <= 19pt
                        .tracking(-0.1)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 4)
            }

            VStack(alignment: .leading, spacing: 0) {
                content
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Color(nsColor: .separatorColor).opacity(0.5), lineWidth: 0.5)
            )

            if let footer = footer {
                Text(footer)
                    .font(.system(size: 11, weight: .regular, design: .default)) // SF Pro Text <= 19pt
                    .tracking(0.06)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

/// Linha de controlo acessível para formulários de preferências macOS.
/// Garante pegada ergonómica mínima de 44pt de altura e contraste WCAG 2.1 AA.
public struct SettingsRow<Content: View>: View {
    public let title: String
    public let subtitle: String?
    public let content: Content

    public init(
        title: String,
        subtitle: String? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    public var body: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .medium, design: .default)) // SF Pro Text <= 19pt
                    .tracking(-0.08)
                    .foregroundStyle(.primary)

                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.system(size: 11, weight: .regular, design: .default)) // SF Pro Text <= 19pt
                        .tracking(0.06)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: 12)

            content
        }
        .frame(minHeight: 44) // Alvo ergonómico Apple HIG >= 44pt
        .contentShape(Rectangle())
    }
}
