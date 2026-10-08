import SwiftUI

/// Painel principal de Definições (Preferences / Settings) da aplicação Sonotype no macOS Sequoia.
/// Estruturado nativamente com `TabView` e 5 abas semânticas: Geral, Gravação, Texto & Idioma,
/// Clipboard e Estatísticas. Cumpre rigorosamente Apple Human Interface Guidelines e WCAG 2.1 AA.
@MainActor
public struct SettingsView: View {
    @ObservedObject public var preferencesManager: PreferencesManager
    @State public var selectedTab: SettingsTab = .general

    public init(preferencesManager: PreferencesManager = .shared) {
        self.preferencesManager = preferencesManager
    }

    public var body: some View {
        TabView(selection: $selectedTab) {
            GeneralSettingsTabView(preferencesManager: preferencesManager)
                .tabItem {
                    Label(SettingsTab.general.title, systemImage: SettingsTab.general.systemImage)
                }
                .tag(SettingsTab.general)

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
        .frame(minWidth: 520, idealWidth: 540, maxWidth: 580, minHeight: 460, idealHeight: 520)
        .sensoryFeedback(.selection, trigger: selectedTab)
    }
}
