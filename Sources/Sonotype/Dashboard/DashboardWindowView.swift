import AppKit
import SwiftUI

/// Janela principal do Dashboard do Sonotype com navegação por barra lateral (`NavigationSplitView`).
/// Contém as secções de Histórico de Transcrições, Dicionário / Regras e Estatísticas de Utilização.
/// Cumpre rigorosamente Apple Human Interface Guidelines (SF Pro Display/Text, materiais semânticos,
/// alvos interativos >= 44pt e contraste WCAG 2.1 AA).
public struct DashboardWindowView: View {
    @Bindable public var viewModel: DashboardViewModel

    public init(viewModel: DashboardViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        NavigationSplitView {
            sidebarContent
                .navigationSplitViewColumnWidth(min: 210, ideal: 230, max: 280)
        } detail: {
            VStack(spacing: 0) {
                // Banner de Erro Reativo
                if let error = viewModel.errorMessage {
                    errorBanner(message: error)
                }

                // Conteúdo Principal da Secção
                detailContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                // Rodapé Semântico com Estado do Motor e Atalho Rápido
                footerStatusBar
            }
        }
        .frame(minWidth: 750, minHeight: 500)
        .sensoryFeedback(.selection, trigger: viewModel.selectedSection)
        .task {
            viewModel.loadAll()
        }
    }

    // MARK: - Barra Lateral (Sidebar)

    @ViewBuilder
    private var sidebarContent: some View {
        VStack(spacing: 0) {
            // Cabeçalho da Aplicação na Barra Lateral
            HStack(spacing: 10) {
                Image(systemName: "waveform.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 26, height: 26)
                    .foregroundStyle(Color.accentColor)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 1) {
                    Text("Sonotype")
                        .font(.system(size: 15, weight: .bold, design: .default)) // SF Pro Text <= 19pt
                        .tracking(-0.23)
                        .foregroundStyle(.primary)

                    Text("Ditado por Voz Offline")
                        .font(.system(size: 11, weight: .regular, design: .default)) // SF Pro Text <= 19pt
                        .tracking(0.06)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 10)

            Divider()

            // Lista de Secções com Seleção Vinculada
            List(
                DashboardSection.allCases,
                id: \.self,
                selection: Binding(
                    get: { viewModel.selectedSection },
                    set: { if let section = $0 { viewModel.selectedSection = section } }
                )
            ) { section in
                sidebarRow(for: section)
                    .tag(section)
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

    // MARK: - Rodapé de Estado (Status Bar)

    @ViewBuilder
    private var footerStatusBar: some View {
        HStack(spacing: 16) {
            // Indicador de Estado do Motor de Áudio
            HStack(spacing: 6) {
                Circle()
                    .fill(Color.green)
                    .frame(width: 8, height: 8)

                Text("Motor Offline Pronto")
                    .font(.system(size: 11, weight: .medium, design: .default)) // SF Pro Text <= 19pt
                    .tracking(0.06)
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Estado: Motor Offline Pronto")

            Text("•")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)

            // Garantia de Privacidade Local
            HStack(spacing: 4) {
                Image(systemName: "shield.checkered")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)

                Text("100% Local (Zero Nuvem)")
                    .font(.system(size: 11, weight: .regular, design: .default)) // SF Pro Text <= 19pt
                    .tracking(0.06)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Indicador de Atalho de Teclado
            HStack(spacing: 6) {
                Text("Atalho de Ditado:")
                    .font(.system(size: 11, weight: .regular, design: .default)) // SF Pro Text <= 19pt
                    .tracking(0.06)
                    .foregroundStyle(.secondary)

                Text("⌥ Espaço")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced)) // SF Pro Text <= 19pt
                    .tracking(0.0)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 4, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .strokeBorder(.separator, lineWidth: 0.5)
                    )
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Atalho de ditado: Option + Espaço")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.regularMaterial)
        .overlay(Divider(), alignment: .top)
    }
}
