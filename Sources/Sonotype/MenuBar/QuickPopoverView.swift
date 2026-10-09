import SwiftUI

/// Estado simplificado do motor de voz para apresentação no popover.
public enum QuickPopoverState: Sendable, Equatable {
    case idle
    case recording
    case processing
}

/// Vista compacta exibida no popover da barra de menus ao clicar no ícone do Sonotype.
/// Inspirada no Centro de Controlo e menus nativos do macOS da Apple (estilo janelas/tiles).
/// Contém módulo de ditado tátil, cartões lado a lado para Dashboard e Definições,
/// e encerramento discreto, cumprindo rigorosamente Apple HIG e WCAG 2.1 AA.
public struct QuickPopoverView: View {
    public let state: QuickPopoverState
    public let currentLanguage: String
    public let hotkeyDisplay: String

    public var onOpenDashboard: (() -> Void)?
    public var onOpenSettings: (() -> Void)?
    public var onToggleRecording: (() -> Void)?
    public var onQuit: (() -> Void)?

    @State private var recordingTrigger: Int = 0
    @State private var navigationTrigger: Int = 0
    @State private var quitTrigger: Int = 0
    @State private var hoveredControlId: String? = nil

    public init(
        state: QuickPopoverState = .idle,
        currentLanguage: String = "PT / EN",
        hotkeyDisplay: String = "⌥ Espaço",
        onOpenDashboard: (() -> Void)? = nil,
        onOpenSettings: (() -> Void)? = nil,
        onToggleRecording: (() -> Void)? = nil,
        onQuit: (() -> Void)? = nil
    ) {
        self.state = state
        self.currentLanguage = currentLanguage
        self.hotkeyDisplay = hotkeyDisplay
        self.onOpenDashboard = onOpenDashboard
        self.onOpenSettings = onOpenSettings
        self.onToggleRecording = onToggleRecording
        self.onQuit = onQuit
    }

    public var body: some View {
        VStack(spacing: 8) {
            // Módulo Principal de Ditado (estilo Apple Control Center)
            dictationModuleCard

            // Janelas Rápidas lado a lado (Estilo Apple Control Center: Dashboard + Definições)
            HStack(spacing: 8) {
                actionTile(
                    id: "dashboard",
                    title: "Dashboard",
                    icon: "macwindow",
                    tooltip: "Abrir o Dashboard do Sonotype"
                ) {
                    navigationTrigger += 1
                    onOpenDashboard?()
                }

                actionTile(
                    id: "settings",
                    title: "Definições",
                    icon: "gearshape.fill",
                    tooltip: "Abrir Definições no Dashboard"
                ) {
                    navigationTrigger += 1
                    onOpenSettings?()
                }
            }

            Divider()
                .padding(.vertical, 2)

            // Rodapé discreto: Encerrar
            quitButton
        }
        .padding(10)
        .frame(width: 260)
        .background(.regularMaterial)
        .sensoryFeedback(.impact(weight: .medium, intensity: 1.0), trigger: recordingTrigger)
        .sensoryFeedback(.selection, trigger: navigationTrigger)
        .sensoryFeedback(.impact(weight: .light, intensity: 1.0), trigger: quitTrigger)
    }

    // MARK: - Módulo de Ditado (Card Principal)

    @ViewBuilder
    private var dictationModuleCard: some View {
        let isHovered = hoveredControlId == "record"
        let isRecording = state == .recording

        Button {
            recordingTrigger += 1
            onToggleRecording?()
        } label: {
            HStack(spacing: 10) {
                // Ícone circular com estado
                ZStack {
                    Circle()
                        .fill(iconCircleFill)
                        .frame(width: 34, height: 34)

                    Image(systemName: iconName)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(iconForeground)
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text(titleText)
                        .font(.system(size: 13, weight: .semibold, design: .default)) // SF Pro Text <= 19pt
                        .tracking(-0.08)
                        .foregroundStyle(.primary)

                    // Atalho discreto sem ênfase excessiva
                    Text(hotkeyDisplay)
                        .font(.system(size: 11, weight: .regular, design: .monospaced)) // SF Pro Text <= 19pt
                        .tracking(0.0)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Indicador subtil de estado
                Circle()
                    .fill(statusDotColor)
                    .frame(width: 8, height: 8)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(minHeight: 50)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(cardBackgroundColor(isHovered: isHovered, isRecording: isRecording))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(isRecording ? Color.red.opacity(0.4) : Color.primary.opacity(0.06), lineWidth: 0.5)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(state == .recording ? "Parar gravação de voz" : "Iniciar ditado por voz (\(hotkeyDisplay))")
        .onHover { hovering in
            hoveredControlId = hovering ? "record" : nil
        }
        .accessibilityLabel(titleText)
        .accessibilityHint("Alternar gravação de voz")
    }

    private var iconName: String {
        switch state {
        case .idle: return "mic.fill"
        case .recording: return "stop.fill"
        case .processing: return "arrow.triangle.2.circlepath"
        }
    }

    private var iconForeground: Color {
        .white
    }

    private var iconCircleFill: Color {
        switch state {
        case .idle: return Color.accentColor
        case .recording: return Color.red
        case .processing: return Color.orange
        }
    }

    private var statusDotColor: Color {
        switch state {
        case .idle: return Color.green
        case .recording: return Color.red
        case .processing: return Color.orange
        }
    }

    private var titleText: String {
        switch state {
        case .idle: return "Ditado"
        case .recording: return "A gravar..."
        case .processing: return "A processar..."
        }
    }

    private func cardBackgroundColor(isHovered: Bool, isRecording: Bool) -> Color {
        if isRecording {
            return isHovered ? Color.red.opacity(0.18) : Color.red.opacity(0.10)
        } else {
            return isHovered ? Color.primary.opacity(0.09) : Color.primary.opacity(0.05)
        }
    }

    // MARK: - Janelas / Cartões Rápidos de Ação (Dashboard & Definições)

    @ViewBuilder
    private func actionTile(
        id: String,
        title: String,
        icon: String,
        tooltip: String,
        action: @escaping () -> Void
    ) -> some View {
        let isHovered = hoveredControlId == id

        Button(action: action) {
            VStack(spacing: 5) {
                ZStack {
                    Circle()
                        .fill(isHovered ? Color.primary.opacity(0.12) : Color.primary.opacity(0.06))
                        .frame(width: 28, height: 28)

                    Image(systemName: icon)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.primary)
                }

                Text(title)
                    .font(.system(size: 11, weight: .medium, design: .default)) // SF Pro Text <= 19pt
                    .tracking(-0.04)
                    .foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .frame(minHeight: 54) // HIG alvo de toque confortável (> 44pt)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isHovered ? Color.primary.opacity(0.09) : Color.primary.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.5)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(tooltip)
        .onHover { hovering in
            hoveredControlId = hovering ? id : nil
        }
        .accessibilityLabel(title)
        .accessibilityHint(tooltip)
    }

    // MARK: - Botão de Encerrar

    @ViewBuilder
    private var quitButton: some View {
        let isHovered = hoveredControlId == "quit"

        Button(role: .destructive) {
            quitTrigger += 1
            onQuit?()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "power")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(isHovered ? .red : .secondary)

                Text("Encerrar")
                    .font(.system(size: 12, weight: .regular, design: .default)) // SF Pro Text <= 19pt
                    .tracking(-0.04)
                    .foregroundStyle(isHovered ? .red : .secondary)

                Spacer()

                Text("⌘Q")
                    .font(.system(size: 11, weight: .regular, design: .default))
                    .tracking(0.04)
                    .foregroundStyle(isHovered ? Color.red.opacity(0.8) : Color.secondary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .frame(minHeight: 28)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(isHovered ? Color.red.opacity(0.08) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("Encerrar o Sonotype (⌘Q)")
        .onHover { hovering in
            hoveredControlId = hovering ? "quit" : nil
        }
        .accessibilityLabel("Encerrar o Sonotype")
    }
}
