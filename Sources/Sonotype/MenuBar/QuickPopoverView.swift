import SwiftUI

/// Estado simplificado do motor de voz para apresentação no popover.
public enum QuickPopoverState: Sendable, Equatable {
    case idle
    case recording
    case processing
}

/// Vista compacta exibida no popover da barra de menus ao clicar no ícone do Sonotype.
/// Cumpre estritamente Apple HIG, WCAG 2.1 AA e princípios de ergonomia e tipografia SF Pro Text.
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
    @State private var hoveredButtonId: String? = nil

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
        VStack(alignment: .leading, spacing: 14) {
            // Header: Marca + Estado + Idioma
            HStack(spacing: 10) {
                Image(systemName: "waveform.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 24, height: 24)
                    .foregroundStyle(.tint)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 1) {
                    Text("Sonotype")
                        .font(.system(size: 15, weight: .bold, design: .default)) // SF Pro Text <= 19pt
                        .tracking(-0.23)
                        .foregroundStyle(.primary)

                    statusLabel
                }

                Spacer()

                // Badge de Idioma (WCAG AA contraste)
                Text(currentLanguage)
                    .font(.system(size: 11, weight: .semibold, design: .default)) // SF Pro Text <= 19pt
                    .tracking(0.06)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(.quaternary, in: Capsule())
                    .accessibilityLabel("Idioma atual: \(currentLanguage)")
            }
            .accessibilityElement(children: .combine)

            // Cartão de Atalho com tecla estilizada
            HStack {
                Text("Atalho de Ditado")
                    .font(.system(size: 12, weight: .medium, design: .default)) // SF Pro Text <= 19pt
                    .tracking(0.0)
                    .foregroundStyle(.secondary)

                Spacer()

                Text(hotkeyDisplay)
                    .font(.system(size: 12, weight: .semibold, design: .monospaced)) // SF Pro Text <= 19pt
                    .tracking(0.0)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .strokeBorder(.separator, lineWidth: 0.5)
                    )
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Atalho de ditado: \(hotkeyDisplay)")

            Divider()

            // Ações Principais
            VStack(spacing: 6) {
                // Ação rápida: Testar / Alternar Ditado (44pt target footprint)
                popoverButton(
                    id: "record",
                    title: state == .recording ? "Parar Ditado" : "Iniciar Ditado",
                    icon: state == .recording ? "stop.fill" : "mic.fill",
                    isPrimary: true,
                    tooltip: state == .recording ? "Interromper gravação atual" : "Começar ditado por voz"
                ) {
                    recordingTrigger += 1
                    onToggleRecording?()
                }

                // Abrir Dashboard
                popoverButton(
                    id: "dashboard",
                    title: "Abrir Dashboard",
                    icon: "sidebar.left",
                    tooltip: "Abrir a janela principal do Sonotype"
                ) {
                    navigationTrigger += 1
                    onOpenDashboard?()
                }

                // Definições
                popoverButton(
                    id: "settings",
                    title: "Definições...",
                    icon: "gearshape",
                    tooltip: "Configurar idioma, modelo e atalhos"
                ) {
                    navigationTrigger += 1
                    onOpenSettings?()
                }
            }

            Divider()

            // Ação de Encerrar
            quitButton
        }
        .padding(14)
        .frame(width: 270)
        .background(.regularMaterial)
        .sensoryFeedback(.impact(weight: .medium, intensity: 1.0), trigger: recordingTrigger)
        .sensoryFeedback(.selection, trigger: navigationTrigger)
        .sensoryFeedback(.impact(weight: .light, intensity: 1.0), trigger: quitTrigger)
    }

    @ViewBuilder
    private var statusLabel: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(statusColor)
                .frame(width: 7, height: 7)

            Text(statusText)
                .font(.system(size: 12, weight: .medium, design: .default)) // SF Pro Text <= 19pt
                .tracking(0.0)
                .foregroundStyle(.secondary)
        }
    }

    private var statusColor: Color {
        switch state {
        case .idle: return .green
        case .recording: return .red
        case .processing: return .orange
        }
    }

    private var statusText: String {
        switch state {
        case .idle: return "Pronto para ditar"
        case .recording: return "A gravar voz..."
        case .processing: return "A processar texto..."
        }
    }

    @ViewBuilder
    private func popoverButton(
        id: String,
        title: String,
        icon: String,
        isPrimary: Bool = false,
        tooltip: String,
        action: @escaping () -> Void
    ) -> some View {
        let isHovered = hoveredButtonId == id

        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: isPrimary ? .semibold : .regular))
                    .foregroundStyle(isPrimary ? Color.accentColor : Color.primary)
                    .frame(width: 18)

                Text(title)
                    .font(.system(size: 13, weight: isPrimary ? .semibold : .medium, design: .default)) // SF Pro Text <= 19pt
                    .tracking(-0.08)
                    .foregroundStyle(.primary)

                Spacer()
            }
            .padding(.horizontal, 10)
            .frame(minHeight: isPrimary ? 44 : 38) // Ergonomia Apple HIG (44pt para ação primária, 38pt com área completa para secundárias)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(buttonBackgroundColor(isPrimary: isPrimary, isHovered: isHovered))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(tooltip)
        .onHover { hovering in
            hoveredButtonId = hovering ? id : nil
        }
        .accessibilityLabel(title)
        .accessibilityHint(tooltip)
    }

    private func buttonBackgroundColor(isPrimary: Bool, isHovered: Bool) -> Color {
        if isPrimary {
            return isHovered ? Color.accentColor.opacity(0.20) : Color.accentColor.opacity(0.12)
        } else {
            return isHovered ? Color.primary.opacity(0.08) : Color.clear
        }
    }

    @ViewBuilder
    private var quitButton: some View {
        let isHovered = hoveredButtonId == "quit"

        Button(role: .destructive) {
            quitTrigger += 1
            onQuit?()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "power")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(isHovered ? .red : .secondary)

                Text("Encerrar o Sonotype")
                    .font(.system(size: 13, weight: .regular, design: .default)) // SF Pro Text <= 19pt
                    .tracking(-0.08)
                    .foregroundStyle(isHovered ? .red : .primary)

                Spacer()

                // Contraste WCAG 2.1 AA: .secondary assegura >= 4.5:1
                Text("⌘Q")
                    .font(.system(size: 11, weight: .medium, design: .default)) // SF Pro Text <= 19pt
                    .tracking(0.06)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 10)
            .frame(minHeight: 38) // Ergonomia Apple HIG com contentShape completo
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(isHovered ? Color.red.opacity(0.12) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("Encerrar o Sonotype (⌘Q)")
        .onHover { hovering in
            hoveredButtonId = hovering ? "quit" : nil
        }
        .accessibilityLabel("Encerrar o Sonotype")
        .accessibilityHint("Fecha a aplicação Sonotype")
    }
}
