import SwiftUI

/// Painel principal de Definições (Preferences / Settings) da aplicação Sonotype no macOS Sequoia.
/// Estruturado nativamente com `TabView` e 6 abas semânticas: Geral, Permissões, Gravação, Texto & Idioma,
/// Clipboard e Estatísticas. Cumpre rigorosamente Apple Human Interface Guidelines e WCAG 2.1 AA.
@MainActor
public struct SettingsView: View {
    @ObservedObject public var preferencesManager: PreferencesManager
    public let permissionsService: PermissionsServiceProtocol
    public var onRelaunchOnboarding: (@MainActor @Sendable () -> Void)?
    @State public var selectedTab: SettingsTab

    public init(
        preferencesManager: PreferencesManager = .shared,
        permissionsService: PermissionsServiceProtocol = PermissionsService(),
        initialTab: SettingsTab = .general,
        onRelaunchOnboarding: (@MainActor @Sendable () -> Void)? = nil
    ) {
        self.preferencesManager = preferencesManager
        self.permissionsService = permissionsService
        self._selectedTab = State(initialValue: initialTab)
        self.onRelaunchOnboarding = onRelaunchOnboarding
    }

    public var body: some View {
        TabView(selection: $selectedTab) {
            GeneralSettingsTabView(preferencesManager: preferencesManager)
                .tabItem {
                    Label(SettingsTab.general.title, systemImage: SettingsTab.general.systemImage)
                }
                .tag(SettingsTab.general)

            PermissionsSettingsTabView(
                permissionsService: permissionsService,
                onRelaunchOnboarding: onRelaunchOnboarding
            )
            .tabItem {
                Label(SettingsTab.permissions.title, systemImage: SettingsTab.permissions.systemImage)
            }
            .tag(SettingsTab.permissions)

            RecordingSettingsTabView(preferencesManager: preferencesManager)
                .tabItem {
                    Label(SettingsTab.recording.title, systemImage: SettingsTab.recording.systemImage)
                }
                .tag(SettingsTab.recording)

            TextLanguageSettingsTabView(preferencesManager: preferencesManager)
                .tabItem {
                    Label(SettingsTab.textLanguage.title, systemImage: SettingsTab.textLanguage.systemImage)
                }
                .tag(SettingsTab.textLanguage)

            ClipboardSettingsTabView(preferencesManager: preferencesManager)
                .tabItem {
                    Label(SettingsTab.clipboard.title, systemImage: SettingsTab.clipboard.systemImage)
                }
                .tag(SettingsTab.clipboard)

            StatsSettingsTabView(preferencesManager: preferencesManager)
                .tabItem {
                    Label(SettingsTab.stats.title, systemImage: SettingsTab.stats.systemImage)
                }
                .tag(SettingsTab.stats)
        }
        .frame(minWidth: 540, idealWidth: 560, maxWidth: 620, minHeight: 480, idealHeight: 540)
        .sensoryFeedback(.selection, trigger: selectedTab)
    }
}
