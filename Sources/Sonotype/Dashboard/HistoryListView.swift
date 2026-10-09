import AppKit
import SwiftUI

/// Vista de histórico de transcrições com pesquisa em tempo real, visualização detalhada em painel duplo
/// (Master-Detail), exportação em múltiplos formatos (.txt, .md, .csv) e ações rápidas.
/// Cumpre estritamente Apple HIG, tipografia SF Pro calibrada e materiais semânticos do macOS.
public struct HistoryListView: View {
    @Bindable public var viewModel: DashboardViewModel

    @State private var showClearConfirmation: Bool = false
    @State private var copyFeedbackTrigger: Int = 0
    @State private var deleteFeedbackTrigger: Int = 0
    @State private var exportFeedbackTrigger: Int = 0
    @State private var recentlyCopiedId: UUID? = nil

    public init(viewModel: DashboardViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        Group {
            if viewModel.historyRecords.isEmpty {
                emptyStateView
            } else {
                HSplitView {
                    recordsListPane
                        .frame(minWidth: 320, idealWidth: 360, maxWidth: 440)

                    recordDetailPane
                        .frame(minWidth: 340, maxWidth: .infinity)
                }
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                exportMenu
                clearAllButton
            }
        }
        .confirmationDialog(
            "Limpar Todo o Histórico",
            isPresented: $showClearConfirmation,
            titleVisibility: .visible
        ) {
            Button("Apagar Todas as Transcrições", role: .destructive) {
                deleteFeedbackTrigger += 1
                viewModel.clearAllHistory()
            }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("Esta ação eliminará permanentemente todas as \(viewModel.historyRecords.count) transcrições guardadas no dispositivo.")
        }
        .sensoryFeedback(.success, trigger: copyFeedbackTrigger)
        .sensoryFeedback(.impact(weight: .light), trigger: deleteFeedbackTrigger)
        .sensoryFeedback(.success, trigger: exportFeedbackTrigger)
    }

    // MARK: - Painel Esquerdo: Lista de Registos

    @ViewBuilder
    private var recordsListPane: some View {
        VStack(spacing: 0) {
            List(selection: $viewModel.selectedRecord) {
                ForEach(viewModel.historyRecords) { record in
                    historyRow(for: record)
                        .tag(record)
                        .listRowInsets(EdgeInsets(top: 6, leading: 10, bottom: 6, trailing: 10))
                        .listRowSeparator(.hidden)
                }
            }
            .listStyle(.sidebar)
            .searchable(
                text: $viewModel.searchQuery,
                placement: .sidebar,
                prompt: "Pesquisar transcrições..."
            )

            // Rodapé com contador de registos
            HStack {
                Text("\(viewModel.historyRecords.count) \(viewModel.historyRecords.count == 1 ? "transcrição" : "transcrições")")
                    .font(.system(size: 11, weight: .medium, design: .default)) // SF Pro Text <= 19pt
                    .tracking(0.06)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(.regularMaterial)
            .overlay(Divider(), alignment: .top)
        }
    }

    // MARK: - Linha do Histórico

    @ViewBuilder
    private func historyRow(for record: TranscriptionRecord) -> some View {
        let isSelected = viewModel.selectedRecord?.id == record.id
        let isRecentlyCopied = recentlyCopiedId == record.id

        VStack(alignment: .leading, spacing: 8) {
            // Metadados Superiores: Idioma e Data
            HStack(spacing: 6) {
                Text(record.detectedLanguage.uppercased())
                    .font(.system(size: 10, weight: .bold, design: .default)) // SF Pro Text <= 19pt
                    .tracking(0.06)
                    .foregroundStyle(isSelected ? Color.white : Color.primary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        isSelected ? Color.white.opacity(0.25) : Color.primary.opacity(0.08),
                        in: Capsule()
                    )

                Text(formattedDate(record.createdAt))
                    .font(.system(size: 11, weight: .regular, design: .default)) // SF Pro Text <= 19pt
                    .tracking(0.06)
                    .foregroundStyle(isSelected ? Color.white.opacity(0.85) : Color.secondary)

                Spacer()

                // Botão de Cópia Rápida (1-clique)
                Button {
                    copyFeedbackTrigger += 1
                    recentlyCopiedId = record.id
                    viewModel.copyToClipboard(record.text)
                    Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 1_500_000_000)
                        if recentlyCopiedId == record.id {
                            recentlyCopiedId = nil
                        }
                    }
                } label: {
                    Image(systemName: isRecentlyCopied ? "checkmark" : "doc.on.doc")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(isSelected ? Color.white : (isRecentlyCopied ? Color.green : Color.secondary))
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Copiar texto para a área de transferência")
                .accessibilityLabel("Copiar transcrição")

                // Botão de Eliminar Individual
                Button(role: .destructive) {
                    deleteFeedbackTrigger += 1
                    viewModel.deleteTranscription(record)
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(isSelected ? Color.white.opacity(0.8) : Color.secondary)
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Eliminar este registo")
                .accessibilityLabel("Eliminar transcrição")
            }

            // Excerto do Texto
            Text(record.text)
                .font(.system(size: 13, weight: .regular, design: .default)) // SF Pro Text <= 19pt
                .tracking(-0.08)
                .foregroundStyle(isSelected ? Color.white : Color.primary)
                .lineLimit(3)
                .multilineTextAlignment(.leading)

            // Metadados Inferiores: Duração e Palavras
            HStack(spacing: 8) {
                Label(String(format: "%.1fs", record.duration), systemImage: "clock")
                    .font(.system(size: 11, weight: .medium, design: .default)) // SF Pro Text <= 19pt
                    .tracking(0.06)
                    .foregroundStyle(isSelected ? Color.white.opacity(0.8) : Color.secondary)

                Text("•")
                    .foregroundStyle(isSelected ? Color.white.opacity(0.5) : Color.secondary.opacity(0.5))

                Text("\(record.wordCount) \(record.wordCount == 1 ? "palavra" : "palavras")")
                    .font(.system(size: 11, weight: .medium, design: .default)) // SF Pro Text <= 19pt
                    .tracking(0.06)
                    .foregroundStyle(isSelected ? Color.white.opacity(0.8) : Color.secondary)

                Spacer()
            }
        }
        .padding(12)
        .frame(minHeight: 44) // Alvo interativo mínimo Apple HIG
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(isSelected ? Color.accentColor : Color.primary.opacity(0.03))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(isSelected ? Color.clear : Color.primary.opacity(0.06), lineWidth: 0.5)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            viewModel.selectedRecord = record
        }
    }

    // MARK: - Painel Direito: Detalhe do Registo

    @ViewBuilder
    private var recordDetailPane: some View {
        if let record = viewModel.selectedRecord {
            VStack(alignment: .leading, spacing: 16) {
                // Barra de Ações Superior do Detalhe
                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Detalhe da Transcrição")
                            .font(.system(size: 16, weight: .bold, design: .default)) // SF Pro Text <= 19pt
                            .tracking(-0.31)
                            .foregroundStyle(.primary)

                        Text(record.createdAt.formatted(date: .long, time: .standard))
                            .font(.system(size: 12, weight: .regular, design: .default)) // SF Pro Text <= 19pt
                            .tracking(0.0)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    // Botão Destacado de Cópia (Apple HIG: minHeight 44pt)
                    Button {
                        copyFeedbackTrigger += 1
                        recentlyCopiedId = record.id
                        viewModel.copyToClipboard(record.text)
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: recentlyCopiedId == record.id ? "checkmark" : "doc.on.doc.fill")
                                .font(.system(size: 13, weight: .semibold))
                            Text(recentlyCopiedId == record.id ? "Copiado!" : "Copiar Texto")
                                .font(.system(size: 13, weight: .semibold, design: .default)) // SF Pro Text <= 19pt
                                .tracking(-0.08)
                        }
                        .padding(.horizontal, 14)
                        .frame(minHeight: 44) // 44pt touch footprint
                        .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .foregroundStyle(.white)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help("Copiar texto completo para a área de transferência")
                    .accessibilityLabel("Copiar texto completo")
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)

                // Pílulas de Metadados
                HStack(spacing: 10) {
                    metadataChip(title: "Idioma", value: record.detectedLanguage.uppercased(), icon: "globe")
                    metadataChip(title: "Duração", value: String(format: "%.1f s", record.duration), icon: "timer")
                    metadataChip(title: "Palavras", value: "\(record.wordCount)", icon: "text.word.spacing")
                }
                .padding(.horizontal, 20)

                Divider()

                // Visualizador de Texto Completo
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(record.text)
                            .font(.system(size: 15, weight: .regular, design: .default)) // SF Pro Text <= 19pt
                            .tracking(-0.23)
                            .lineSpacing(6)
                            .foregroundStyle(.primary)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(20)
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .strokeBorder(.separator, lineWidth: 0.5)
                            )
                    }
                    .frame(maxWidth: 920)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            .background(.thinMaterial)
        } else {
            ContentUnavailableView {
                Label("Nenhuma Transcrição Selecionada", systemImage: "doc.text.magnifyingglass")
            } description: {
                Text("Selecione uma gravação na lista à esquerda para consultar a transcrição completa e os respetivos metadados.")
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.thinMaterial)
        }
    }

    // MARK: - Componente Chip de Metadados

    @ViewBuilder
    private func metadataChip(title: String, value: String, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 10, weight: .regular, design: .default)) // SF Pro Text <= 19pt
                    .tracking(0.06)
                    .foregroundStyle(.secondary)

                Text(value)
                    .font(.system(size: 12, weight: .semibold, design: .default)) // SF Pro Text <= 19pt
                    .tracking(0.0)
                    .foregroundStyle(.primary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(.separator, lineWidth: 0.5)
        )
    }

    // MARK: - Estado Vazio

    @ViewBuilder
    private var emptyStateView: some View {
        if viewModel.searchQuery.isEmpty {
            ContentUnavailableView {
                Label("Sem Transcrições", systemImage: "waveform.badge.mic")
            } description: {
                Text("As suas notas de voz e transcrições ditadas aparecerão aqui automaticamente após cada gravação.")
            } actions: {
                Text("Prima Option + Espaço para ditar")
                    .font(.system(size: 12, weight: .medium, design: .monospaced)) // SF Pro Text <= 19pt
                    .tracking(0.0)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(.quaternary, in: Capsule())
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ContentUnavailableView.search(text: viewModel.searchQuery)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - Toolbar Controls

    @ViewBuilder
    private var exportMenu: some View {
        Menu {
            Button {
                exportFeedbackTrigger += 1
                viewModel.exportWithSavePanel(format: .plainText)
            } label: {
                Label("Texto Simples (.txt)", systemImage: "doc.text")
            }

            Button {
                exportFeedbackTrigger += 1
                viewModel.exportWithSavePanel(format: .markdown)
            } label: {
                Label("Documento Markdown (.md)", systemImage: "text.badge.checkmark")
            }

            Button {
                exportFeedbackTrigger += 1
                viewModel.exportWithSavePanel(format: .csv)
            } label: {
                Label("Folha de Cálculo CSV (.csv)", systemImage: "tablecells")
            }
        } label: {
            Label("Exportar", systemImage: "square.and.arrow.up")
        }
        .disabled(viewModel.historyRecords.isEmpty)
        .help("Exportar o histórico de transcrições nos formatos .txt, .md ou .csv")
    }

    @ViewBuilder
    private var clearAllButton: some View {
        Button(role: .destructive) {
            showClearConfirmation = true
        } label: {
            Label("Limpar Tudo", systemImage: "trash")
        }
        .disabled(viewModel.historyRecords.isEmpty)
        .help("Limpar todo o histórico de transcrições")
    }

    // MARK: - Formatador de Data Amigável

    private func formattedDate(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            let timeStr = date.formatted(date: .omitted, time: .shortened)
            return "Hoje, \(timeStr)"
        } else if calendar.isDateInYesterday(date) {
            let timeStr = date.formatted(date: .omitted, time: .shortened)
            return "Ontem, \(timeStr)"
        } else {
            return date.formatted(date: .abbreviated, time: .shortened)
        }
    }
}
