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

            // Lista de Secções com Seleção Vinculada + Definições na Barra Lateral
            List {
                Section {
                    ForEach(DashboardSection.allCases, id: \.self) { section in
                        sidebarRow(for: section)
                            .tag(section)
                    }
                }

                Section {
                    Button {
                        onOpenSettings?()
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "gearshape")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(Color.secondary)
                                .frame(width: 20)

                            Text("Definições")
                                .font(.system(size: 13, weight: .medium, design: .default))
                                .tracking(-0.08)
                                .foregroundStyle(.primary)

                            Spacer()

                            Image(systemName: "arrow.up.forward.app")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.vertical, 4)
                        .frame(minHeight: 32)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help("Abrir Definições do Sonotype (⌘,)")
                    .accessibilityLabel("Definições")
                }
            }
            .listStyle(.sidebar)
        }
        .background(.regularMaterial)
    }

    // MARK: - Linha da Barra Lateral

    @ViewBuilder
    private func sidebarRow(for section: DashboardSection) -> some View {
        HStack(spacing: 10) {
            Image(systemName: sectionIcon(for: section))
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(viewModel.selectedSection == section ? Color.accentColor : Color.secondary)
                .frame(width: 20)

            Text(section.rawValue)
                .font(.system(size: 13, weight: .medium, design: .default)) // SF Pro Text <= 19pt
                .tracking(-0.08)
                .foregroundStyle(.primary)

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
        .padding(.vertical, 4)
        .frame(minHeight: 32)
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
        }
    }

    private func sectionBadge(for section: DashboardSection) -> String? {
        switch section {
        case .home:
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
            HomeOverviewView(viewModel: viewModel, onOpenSettings: onOpenSettings)
        case .history:
            HistoryListView(viewModel: viewModel)
        case .vocabulary:
            VocabularyManagerView(viewModel: viewModel)
        case .stats:
            StatsOverviewView(viewModel: viewModel)
        }
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
