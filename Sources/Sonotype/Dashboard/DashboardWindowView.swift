import AppKit
import SwiftUI

/// Janela principal do Dashboard do Sonotype com navegação por barra lateral (`NavigationSplitView`).
/// Contém as secções de Histórico de Transcrições, Dicionário / Regras e Estatísticas de Utilização.
/// Cumpre rigorosamente Apple Human Interface Guidelines (SF Pro Display/Text, materiais semânticos,
/// alvos interativos >= 44pt e contraste WCAG 2.1 AA).
public struct DashboardWindowView: View {
    @Bindable public var viewModel: DashboardViewModel
    public var onOpenSettings: (() -> Void)?

    public init(viewModel: DashboardViewModel, onOpenSettings: (() -> Void)? = nil) {
        self.viewModel = viewModel
        self.onOpenSettings = onOpenSettings
    }

    public var body: some View {
        NavigationSplitView {
            sidebarContent
                .navigationSplitViewColumnWidth(min: 220, ideal: 240, max: 290)
        } detail: {
            VStack(spacing: 0) {
                // Banner de Erro Reativo
                if let error = viewModel.errorMessage {
                    errorBanner(message: error)
                }

                // Conteúdo Principal da Secção
                detailContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(minWidth: 720, minHeight: 480)
        .sensoryFeedback(.selection, trigger: viewModel.selectedSection)
        .task {
            viewModel.loadAll()
        }
    }

    // MARK: - Barra Lateral (Sidebar)

    @ViewBuilder
    private var sidebarContent: some View {
        VStack(spacing: 0) {
            // Cabeçalho da Aplicação na Barra Lateral com Atalho Compacto
            HStack(spacing: 10) {
                SonotypeBrandLogoView(size: 26)

                VStack(alignment: .leading, spacing: 1) {
                    Text("Sonotype")
                        .font(.system(size: 14, weight: .bold, design: .default)) // SF Pro Text <= 19pt
                        .tracking(-0.2)
                        .foregroundStyle(.primary)

                    Text("Ditado por Voz")
                        .font(.system(size: 11, weight: .regular, design: .default))
                        .tracking(0.06)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Atalho compacto no topo
                HStack(spacing: 3) {
                    Text("⌥")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    Text("Espaço")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                }
                .foregroundStyle(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 5, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .strokeBorder(.separator, lineWidth: 0.5)
                )
                .help("Atalho global para iniciar ou parar o ditado")
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)
            .padding(.bottom, 8)

            Divider()

            // Lista de Secções com Seleção Vinculada + Definições integradas
            List(selection: $viewModel.selectedSection) {
                Section {
                    ForEach([DashboardSection.home, .history, .vocabulary, .stats], id: \.self) { section in
                        Button {
                            viewModel.selectedSection = section
                        } label: {
                            sidebarRow(for: section)
                        }
                        .buttonStyle(.plain)
                        .tag(section)
                    }
                }

                Section {
                    Button {
                        viewModel.selectedSection = .settings
                    } label: {
                        sidebarRow(for: .settings)
                    }
                    .buttonStyle(.plain)
                    .tag(DashboardSection.settings)
                }
            }
            .listStyle(.sidebar)
        }
        .background(.regularMaterial)
    }

    // MARK: - Linha da Barra Lateral

    @ViewBuilder
    private func sidebarRow(for section: DashboardSection) -> some View {
        let isSelected = viewModel.selectedSection == section
        HStack(spacing: 10) {
            Image(systemName: sectionIcon(for: section))
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                .frame(width: 20)

            Text(section.rawValue)
                .font(.system(size: 13, weight: isSelected ? .semibold : .medium, design: .default)) // SF Pro Text <= 19pt
                .tracking(-0.08)
                .foregroundStyle(isSelected ? .primary : .secondary)

            Spacer()

            if let badge = sectionBadge(for: section) {
                Text(badge)
                    .font(.system(size: 11, weight: .semibold, design: .default)) // SF Pro Text <= 19pt
                    .tracking(0.06)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.quaternary, in: Capsule())
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .frame(minHeight: 34)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(isSelected ? Color.accentColor.opacity(0.12) : Color.clear)
        )
        .contentShape(Rectangle())
        .accessibilityLabel(section.rawValue)
    }

    private func sectionIcon(for section: DashboardSection) -> String {
        switch section {
        case .home:
            return "house.fill"
        case .history:
            return "clock.arrow.circlepath"
        case .vocabulary:
            return "character.book.closed"
        case .stats:
            return "chart.bar.xaxis"
        case .settings:
            return "gearshape"
        }
    }

    private func sectionBadge(for section: DashboardSection) -> String? {
        switch section {
        case .home, .settings:
            return nil
        case .history:
            return viewModel.historyRecords.isEmpty ? nil : "\(viewModel.historyRecords.count)"
        case .vocabulary:
            let count = viewModel.vocabularyEntries.count + viewModel.replacementRules.count
            return count == 0 ? nil : "\(count)"
        case .stats:
            return nil
        }
    }

    // MARK: - Painel de Detalhe por Secção

    @ViewBuilder
    private var detailContent: some View {
        switch viewModel.selectedSection {
        case .home:
            HomeOverviewView(viewModel: viewModel, onOpenSettings: {
                viewModel.selectedSection = .settings
            })
        case .history:
            HistoryListView(viewModel: viewModel)
        case .vocabulary:
            VocabularyManagerView(viewModel: viewModel)
        case .stats:
            StatsOverviewView(viewModel: viewModel)
        case .settings:
            settingsDetailPane
        }
    }

    @ViewBuilder
    private var settingsDetailPane: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Definições")
                        .font(.system(size: 18, weight: .bold, design: .default)) // SF Pro Text <= 19pt
                        .tracking(-0.2)
                        .foregroundStyle(.primary)

                    Text("Personalize atalhos, reconhecimento de fala, permissões e formatação.")
                        .font(.system(size: 12, weight: .regular, design: .default)) // SF Pro Text <= 19pt
                        .tracking(0.0)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 2)

            SettingsView(
                preferencesManager: viewModel.preferencesManager ?? .shared,
                permissionsService: viewModel.permissionsService ?? PermissionsService(),
                initialTab: .general,
                isEmbedded: true
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(.thinMaterial)
    }

    // MARK: - Banner de Erro

    @ViewBuilder
    private func errorBanner(message: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.yellow)

            Text(message)
                .font(.system(size: 12, weight: .medium, design: .default)) // SF Pro Text <= 19pt
                .tracking(0.0)
                .foregroundStyle(.primary)

            Spacer()

            Button("Dispensar") {
                viewModel.clearError()
            }
            .buttonStyle(.plain)
            .font(.system(size: 11, weight: .semibold, design: .default)) // SF Pro Text <= 19pt
            .tracking(0.06)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 4, style: .continuous))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.yellow.opacity(0.12))
        .overlay(Divider(), alignment: .bottom)
    }
}
