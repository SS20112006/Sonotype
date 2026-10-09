import AppKit
import SwiftUI

/// Vista de página inicial (Homepage / Visão Geral) interativa do Sonotype.
/// Apresenta métricas agregadas de impacto, matriz de atividade diária estilo GitHub (heat grid),
/// atalhos e definições rápidas de sistema e acesso direto às últimas transcrições.
/// Cumpre estritamente Apple HIG, materiais semânticos nativos (.regularMaterial) e WCAG 2.1 AA.
public struct HomeOverviewView: View {
    @Bindable public var viewModel: DashboardViewModel
    public var onOpenSettings: (() -> Void)?

    @State private var hoveredDayKey: String? = nil
    @State private var copiedRecordId: UUID? = nil

    public init(viewModel: DashboardViewModel, onOpenSettings: (() -> Void)? = nil) {
        self.viewModel = viewModel
        self.onOpenSettings = onOpenSettings
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                // 1. Cabeçalho de Boas-Vindas
                welcomeHeader

                // 2. Painéis Principais: Resumo de Produtividade + Matriz de Atividade Estilo GitHub
                HStack(alignment: .top, spacing: 16) {
                    productivitySummaryCard
                        .frame(minWidth: 260, idealWidth: 290, maxWidth: 330)

                    githubStyleActivityCard
                        .frame(maxWidth: .infinity)
                }

                // 3. Painel de Definições Rápidas & Estado do Sistema
                quickSettingsAndStatusCard

                // 4. Painel de Transcrições Recentes
                recentTranscriptionsCard
            }
            .padding(20)
            .frame(maxWidth: 1060)
            .frame(maxWidth: .infinity, alignment: .top)
        }
        .background(.thinMaterial)
        .onAppear {
            viewModel.loadDailyStats()
            viewModel.loadStats()
            viewModel.loadHistory()
        }
    }

    // MARK: - 1. Cabeçalho de Boas-Vindas

    private var welcomeHeader: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text("Visão Geral")
                        .font(.system(size: 20, weight: .bold, design: .default)) // SF Pro Display >= 20pt
                        .tracking(0.35)
                        .foregroundStyle(.primary)

                    // Badge de Estado Ativo
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 7, height: 7)
                        Text("Pronto")
                            .font(.system(size: 11, weight: .semibold, design: .default))
                            .foregroundStyle(Color.green)
                    }
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2.5)
                    .background(Color.green.opacity(0.12), in: Capsule())
                }

                Text("Acompanhe o seu ritmo de ditado por voz, produtividade e atalhos rápidos.")
                    .font(.system(size: 12, weight: .regular, design: .default)) // SF Pro Text <= 19pt
                    .tracking(0.0)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Botão de Ditar / Instrução de Atalho em Destaque
            HStack(spacing: 6) {
                Image(systemName: "waveform")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color.accentColor)

                Text("Prima")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)

                HStack(spacing: 3) {
                    Text("⌥")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                    Text("Espaço")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                }
                .padding(.horizontal, 5)
                .padding(.vertical, 2.5)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 5, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .strokeBorder(.separator, lineWidth: 0.5)
                )

                Text("em qualquer app")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(.separator.opacity(0.5), lineWidth: 0.5)
            )
        }
    }

    // MARK: - 2. Cartão de Resumo de Produtividade

    private var productivitySummaryCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("Produtividade", systemImage: "bolt.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.primary)

                Spacer()
            }

            Divider()

            // Métrica 1: Palavras Totais
            VStack(alignment: .leading, spacing: 2) {
                Text(viewModel.stats.totalWords.formatted())
                    .font(.system(size: 26, weight: .bold, design: .default)) // SF Pro Display
                    .tracking(0.35)
                    .foregroundStyle(Color.accentColor)

                Text("palavras ditadas")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            // Métrica 2: Tempo Poupado
            VStack(alignment: .leading, spacing: 2) {
                Text(formattedTimeSavedString(minutes: viewModel.stats.estimatedTimeSavedMinutes))
                    .font(.system(size: 22, weight: .bold, design: .default))
                    .tracking(0.35)
                    .foregroundStyle(Color.orange)

                Text("tempo estimado poupado")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            Divider()

            // Sub-métricas em 2 colunas
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(viewModel.stats.totalTranscriptions)")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.primary)
                    Text("Sessões")
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(alignment: .leading, spacing: 2) {
                    Text(formattedWPMString)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.primary)
                    Text("Média Voz")
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(.separator.opacity(0.5), lineWidth: 0.5)
        )
    }

    // MARK: - 3. Matriz de Atividade Estilo GitHub (Heat Grid)

    private var githubStyleActivityCard: some View {
        let days = recent77Days()
        let statsDict = Dictionary(uniqueKeysWithValues: viewModel.dailyStats.map { ($0.dayKey, $0) })
        let currentStreak = viewModel.currentStreakDays
        let activeDays = viewModel.activeDaysCount

        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center) {
                Label("Atividade de Voz", systemImage: "chart.dots.scatter")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.primary)

                Spacer()

                // Badge de Streak
                HStack(spacing: 6) {
                    Image(systemName: "flame.fill")
                        .foregroundStyle(currentStreak > 0 ? Color.orange : Color.secondary)
                        .font(.system(size: 12, weight: .bold))

                    Text("\(currentStreak) \(currentStreak == 1 ? "dia" : "dias") de streak")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.primary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.quaternary, in: Capsule())

                // Badge de Dias Ativos
                Text("\(activeDays) dias ativos")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.quaternary, in: Capsule())
            }

            Divider()

            // Grelha e Métricas de Atividade Recente
            HStack(alignment: .top, spacing: 18) {
                // Matriz de Quadrados dos Últimos 77 Dias (11 Semanas x 7 Dias)
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .top, spacing: 5) {
                        ForEach(0..<11, id: \.self) { weekIndex in
                            VStack(spacing: 5) {
                                ForEach(0..<7, id: \.self) { dayOfWeekIndex in
                                    let index = (weekIndex * 7) + dayOfWeekIndex
                                    if index < days.count {
                                        let date = days[index]
                                        let dayKey = SessionStat.makeDayKey(from: date)
                                        let wordCount = statsDict[dayKey]?.totalWords ?? 0

                                        activityCell(
                                            date: date,
                                            dayKey: dayKey,
                                            wordCount: wordCount
                                        )
                                    }
                                }
                            }
                        }
                    }

                    // Legenda de Intensidade no Rodapé
                    HStack(spacing: 6) {
                        Text("Menos")
                            .font(.system(size: 10, weight: .regular))
                            .foregroundStyle(.secondary)

                        heatLegendSquare(color: Color.secondary.opacity(0.12))
                        heatLegendSquare(color: Color.accentColor.opacity(0.35))
                        heatLegendSquare(color: Color.accentColor.opacity(0.65))
                        heatLegendSquare(color: Color.accentColor)

                        Text("Mais")
                            .font(.system(size: 10, weight: .regular))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 2)
                }

                Divider()
                    .frame(maxHeight: 125)

                // Destaques de Ritmo Recente
                VStack(alignment: .leading, spacing: 10) {
                    activityInsightRow(
                        title: "Total no Período",
                        value: "\(recentWordsCount(statsDict: statsDict, days: days)) palavras",
                        icon: "character.textbox"
                    )

                    activityInsightRow(
                        title: "Média / Dia Ativo",
                        value: formattedAverageActiveWords(statsDict: statsDict, days: days),
                        icon: "chart.line.uptrend.xyaxis"
                    )

                    activityInsightRow(
                        title: "Pico Diário",
                        value: formattedPeakDayWords(statsDict: statsDict, days: days),
                        icon: "trophy.fill"
                    )
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            if let hovered = hoveredDayKey, let stat = statsDict[hovered] {
                Text("\(hovered): \(stat.totalWords) palavras (\(stat.totalTranscriptions) ditados)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.accentColor)
                    .padding(.top, 2)
            } else if let hovered = hoveredDayKey {
                Text("\(hovered): Sem atividade")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(.secondary)
                    .padding(.top, 2)
            }
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(.separator.opacity(0.5), lineWidth: 0.5)
        )
    }

    private func activityCell(date: Date, dayKey: String, wordCount: Int) -> some View {
        let isHovered = hoveredDayKey == dayKey
        let cellColor: Color = {
            if wordCount == 0 {
                return Color.secondary.opacity(0.12)
            } else if wordCount < 50 {
                return Color.accentColor.opacity(0.35)
            } else if wordCount < 200 {
                return Color.accentColor.opacity(0.65)
            } else {
                return Color.accentColor
            }
        }()

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "d 'de' MMMM"
        let dateString = dateFormatter.string(from: date)

        return RoundedRectangle(cornerRadius: 3.5, style: .continuous)
            .fill(cellColor)
            .frame(width: 18, height: 18)
            .overlay(
                RoundedRectangle(cornerRadius: 3.5, style: .continuous)
                    .strokeBorder(isHovered ? Color.primary : Color.clear, lineWidth: 1.5)
            )
            .help("\(dateString): \(wordCount) palavras ditadas")
            .onHover { isHovering in
                if isHovering {
                    hoveredDayKey = dayKey
                } else if hoveredDayKey == dayKey {
                    hoveredDayKey = nil
                }
            }
    }

    private func heatLegendSquare(color: Color) -> some View {
        RoundedRectangle(cornerRadius: 2.5, style: .continuous)
            .fill(color)
            .frame(width: 10, height: 10)
    }

    // MARK: - 4. Cartão de Definições Rápidas & Estado

    private var quickSettingsAndStatusCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("Controlo Rápido & Permissões", systemImage: "slider.horizontal.3")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.primary)

                Spacer()

                Button {
                    onOpenSettings?()
                } label: {
                    HStack(spacing: 4) {
                        Text("Todas as Definições")
                            .font(.system(size: 12, weight: .medium))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundStyle(Color.accentColor)
                }
                .buttonStyle(.plain)
            }

            Divider()

            HStack(spacing: 24) {
                // Item 1: Estado do Microfone
                statusItem(
                    title: "Microfone",
                    icon: "mic.fill",
                    isAuthorized: viewModel.isMicrophoneAuthorized,
                    authorizedText: "Concedido",
                    unauthorizedText: "Ativar",
                    action: {
                        viewModel.permissionsService?.openSystemSettings(for: .microphone)
                    }
                )

                Divider()
                    .frame(height: 36)

                // Item 2: Estado de Acessibilidade
                statusItem(
                    title: "Acessibilidade",
                    icon: "accessibility.fill",
                    isAuthorized: viewModel.isAccessibilityAuthorized,
                    authorizedText: "Concedido",
                    unauthorizedText: "Abrir Definições",
                    action: {
                        viewModel.permissionsService?.openSystemSettings(for: .accessibility)
                    }
                )

                Divider()
                    .frame(height: 36)

                // Item 3: Idioma Ativo Rápido
                VStack(alignment: .leading, spacing: 4) {
                    Text("Modo de Idioma")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)

                    if let prefs = viewModel.preferencesManager {
                        Picker("Idioma", selection: Binding(
                            get: { prefs.preferences.languageSelectionMode },
                            set: { prefs.preferences.languageSelectionMode = $0 }
                        )) {
                            Text("Auto-Deteção").tag(LanguageSelectionMode.autoDetect)
                            Text("Português").tag(LanguageSelectionMode.fixedPT)
                            Text("Inglês").tag(LanguageSelectionMode.fixedEN)
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                        .frame(minWidth: 220)
                    } else {
                        Text("Auto-Deteção (PT/EN)")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.primary)
                    }
                }
            }
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(.separator.opacity(0.5), lineWidth: 0.5)
        )
    }

    private func statusItem(
        title: String,
        icon: String,
        isAuthorized: Bool,
        authorizedText: String,
        unauthorizedText: String,
        action: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(isAuthorized ? Color.green : Color.orange)
                .frame(width: 32, height: 32)
                .background(
                    (isAuthorized ? Color.green : Color.orange).opacity(0.12),
                    in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.primary)

                if isAuthorized {
                    Text(authorizedText)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.green)
                } else {
                    Button(unauthorizedText) {
                        action()
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.orange)
                }
            }
        }
    }

    // MARK: - 5. Cartão de Transcrições Recentes

    private var recentTranscriptionsCard: some View {
        let recent = Array(viewModel.historyRecords.prefix(3))

        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("Transcrições Recentes", systemImage: "clock.arrow.circlepath")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.primary)

                Spacer()

                Button {
                    viewModel.selectedSection = .history
                } label: {
                    HStack(spacing: 4) {
                        Text("Ver Todas (\(viewModel.historyRecords.count))")
                            .font(.system(size: 12, weight: .medium))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundStyle(Color.accentColor)
                }
                .buttonStyle(.plain)
            }

            Divider()

            if recent.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "mic.badge.plus")
                        .font(.system(size: 32))
                        .foregroundStyle(.secondary.opacity(0.7))

                    Text("Ainda não tem transcrições gravadas")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.primary)

                    Text("Prima Option + Espaço em qualquer aplicação para ditar o seu primeiro texto.")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            } else {
                VStack(spacing: 10) {
                    ForEach(recent) { record in
                        recentRecordRow(record: record)
                    }
                }
            }
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(.separator.opacity(0.5), lineWidth: 0.5)
        )
    }

    private func recentRecordRow(record: TranscriptionRecord) -> some View {
        let isCopied = copiedRecordId == record.id

        return HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(record.text)
                    .font(.system(size: 13, weight: .regular, design: .default))
                    .tracking(-0.08)
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                HStack(spacing: 8) {
                    Text(formattedDate(record.createdAt))
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(.secondary)

                    Text("•")
                        .foregroundStyle(.secondary.opacity(0.5))

                    Text("\(record.wordCount) palavras")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)

                    Text("•")
                        .foregroundStyle(.secondary.opacity(0.5))

                    Text(record.detectedLanguage.uppercased())
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color.accentColor)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 3))
                }
            }

            Spacer()

            // Botão de Cópia com 1 toque
            Button {
                viewModel.copyToClipboard(record.text)
                copiedRecordId = record.id
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    if copiedRecordId == record.id {
                        copiedRecordId = nil
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                        .font(.system(size: 11, weight: .semibold))
                    Text(isCopied ? "Copiado" : "Copiar")
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundStyle(isCopied ? Color.green : Color.primary)
                .padding(.horizontal, 10)
                .frame(minHeight: 32)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            }
            .buttonStyle(.plain)
            .sensoryFeedback(.success, trigger: isCopied)
            .help("Copiar texto para a área de transferência")
        }
        .padding(10)
        .background(Color.secondary.opacity(0.04), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    // MARK: - Formatadores e Helpers

    private func activityInsightRow(title: String, value: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 10, weight: .regular))
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.primary)
            }
        }
    }

    private func recentWordsCount(statsDict: [String: SessionStat], days: [Date]) -> Int {
        days.reduce(0) { total, date in
            let key = SessionStat.makeDayKey(from: date)
            return total + (statsDict[key]?.totalWords ?? 0)
        }
    }

    private func formattedAverageActiveWords(statsDict: [String: SessionStat], days: [Date]) -> String {
        let activeCounts = days.compactMap { date -> Int? in
            let key = SessionStat.makeDayKey(from: date)
            guard let words = statsDict[key]?.totalWords, words > 0 else { return nil }
            return words
        }
        guard !activeCounts.isEmpty else { return "0 / dia" }
        let avg = activeCounts.reduce(0, +) / activeCounts.count
        return "\(avg) / dia"
    }

    private func formattedPeakDayWords(statsDict: [String: SessionStat], days: [Date]) -> String {
        let peak = days.map { date in
            let key = SessionStat.makeDayKey(from: date)
            return statsDict[key]?.totalWords ?? 0
        }.max() ?? 0
        return peak > 0 ? "\(peak) palavras" : "0 palavras"
    }

    private func recent77Days() -> [Date] {
        let calendar = Calendar.current
        let today = Date()
        var dates: [Date] = []
        for offset in (0..<77).reversed() {
            if let date = calendar.date(byAdding: .day, value: -offset, to: today) {
                dates.append(date)
            }
        }
        return dates
    }

    private func recent35Days() -> [Date] {
        Array(recent77Days().suffix(35))
    }

    private func formattedTimeSavedString(minutes: Double) -> String {
        if minutes < 1.0 {
            return "< 1 min"
        } else if minutes < 60.0 {
            return "\(Int(minutes)) min"
        } else {
            let hours = minutes / 60.0
            return String(format: "%.1fh", hours)
        }
    }

    private var formattedWPMString: String {
        let words = Double(viewModel.stats.totalWords)
        let seconds = viewModel.stats.totalDurationSeconds
        guard seconds > 0 else { return "150 PPM" }
        let wpm = Int((words / seconds) * 60.0)
        return "\(wpm) PPM"
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
