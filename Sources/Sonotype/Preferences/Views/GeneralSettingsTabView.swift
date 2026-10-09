import SwiftUI

/// Aba de Definições Gerais do Sonotype.
/// Configura o comportamento de arranque com o macOS e o modo de presença na Dock / Barra de Menus.
@MainActor
public struct GeneralSettingsTabView: View {
    @ObservedObject public var preferencesManager: PreferencesManager

    public init(preferencesManager: PreferencesManager) {
        self.preferencesManager = preferencesManager
    }

    public var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                // Secção 0: Identidade Visual da Aplicação
                HStack(spacing: 16) {
                    SonotypeBrandLogoView(size: 56)
                        .shadow(color: Color.black.opacity(0.15), radius: 4, x: 0, y: 2)

                    VStack(alignment: .leading, spacing: 3) {
                        Text("Sonotype")
                            .font(.system(size: 18, weight: .bold)) // SF Pro Text <= 19pt
                            .tracking(-0.3)
                            .foregroundStyle(.primary)

                        Text("Ditado por Voz Offline no Dispositivo")
                            .font(.system(size: 13, weight: .regular))
                            .foregroundStyle(.secondary)

                        Text("Versão 1.0.0 • macOS")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.tertiary)
                    }

                    Spacer()
                }
                .padding(.horizontal, 4)
                .padding(.bottom, 2)

                // Secção 1: Arranque com o Sistema
                SettingsCard(
                    title: "Arranque do Sistema",
                    icon: "power",
                    footer: "O Sonotype pode ser iniciado automaticamente em segundo plano para estar pronto a ditar imediatamente."
                ) {
                    SettingsRow(
                        title: "Iniciar no Login",
                        subtitle: "Executar o Sonotype ao iniciar sessão no macOS"
                    ) {
                        Toggle("", isOn: Binding(
                            get: { preferencesManager.launchAtLogin },
                            set: { preferencesManager.launchAtLogin = $0 }
                        ))
                        .toggleStyle(.switch)
                        .accessibilityLabel("Iniciar no Login")
                    }
                }

                // Secção 2: Presença na Dock e Barra de Menus
                SettingsCard(
                    title: "Presença no Sistema",
                    icon: "macwindow.on.rectangle",
                    footer: dockModeExplanation(for: preferencesManager.dockVisibilityMode)
                ) {
                    SettingsRow(
                        title: "Visibilidade na Dock",
                        subtitle: "Determina como o ícone do Sonotype interage com a Dock"
                    ) {
                        Picker("", selection: Binding(
                            get: { preferencesManager.dockVisibilityMode },
                            set: { preferencesManager.dockVisibilityMode = $0 }
                        )) {
                            Text("Dinâmico (Padrão)").tag(DockVisibilityMode.dynamic)
                            Text("Apenas Barra de Menus").tag(DockVisibilityMode.menuBarOnly)
                            Text("Sempre na Dock").tag(DockVisibilityMode.alwaysDock)
                        }
                        .pickerStyle(.menu)
                        .frame(minWidth: 175)
                        .accessibilityLabel("Modo de Visibilidade na Dock")
                    }
                }
            }
            .padding(18)
        }
    }

    private func dockModeExplanation(for mode: DockVisibilityMode) -> String {
        switch mode {
        case .dynamic:
            return "Modo Dinâmico: O ícone oculta-se da Dock quando em repouso e surge apenas enquanto janelas de Definições ou Dashboard estiverem ativas."
        case .menuBarOnly:
            return "Apenas Barra de Menus: O Sonotype reside discretamente na barra de menus superior, nunca ocupando espaço na Dock."
        case .alwaysDock:
            return "Sempre na Dock: Comporta-se como uma aplicação desktop tradicional, mantendo sempre o ícone fixo na Dock."
        }
    }
}
