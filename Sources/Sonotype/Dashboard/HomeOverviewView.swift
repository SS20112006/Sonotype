import AppKit
import SwiftUI

/// Vista de página inicial (Homepage / Visão Geral) interativa do Sonotype.
/// Apresenta métricas de produtividade com comparação explícita de tempo poupado (voz vs teclado),
/// novo calendário de atividade mensal intuitivo com navegação temporal e inspetor diário,
/// atalhos e definições rápidas de sistema e acesso direto às últimas transcrições.
/// Cumpre estritamente Apple HIG, materiais semânticos nativos (.regularMaterial) e WCAG 2.1 AA.
public struct HomeOverviewView: View {
    @Bindable public var viewModel: DashboardViewModel
    public var onOpenSettings: (() -> Void)?

    @State private var displayedMonth: Date = Date()
    @State private var selectedDate: Date = Date()
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

                // 2. Painéis Principais: Resumo de Produtividade + Calendário de Atividade
                HStack(alignment: .top, spacing: 16) {
                    productivitySummaryCard
                        .frame(minWidth: 320, idealWidth: 350, maxWidth: 390)

                    calendarActivityCard
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

                Text("Acompanhe o seu ritmo de ditado por voz, tempo poupado e atalhos rápidos.")
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

    // MARK: - 2. Cartão de Resumo de Produtividade (Comparação Voz vs Teclado)

    private var productivitySummaryCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center) {
                Label("Produtividade", systemImage: "bolt.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.primary)

                Spacer()

                // Badge de Eficiência Multiplicadora
                HStack(spacing: 4) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 10, weight: .bold))
                    Text(String(format: "%.1fx mais rápido", viewModel.speedupMultiplier))
                        .font(.system(size: 11, weight: .bold))
                }
                .foregroundStyle(Color.green)
                .padding(.horizontal, 8)
                .padding(.vertical, 3.5)
                .background(Color.green.opacity(0.12), in: Capsule())
            }

            Divider()

            // Destaque Principal: Tempo Poupado Face ao Teclado
            VStack(alignment: .leading, spacing: 2) {
                Text(formattedTimeSavedHero)
                    .font(.system(size: 26, weight: .bold, design: .default)) // SF Pro Display
                    .tracking(0.35)
                    .foregroundStyle(Color.green)

                Text("tempo estimado poupado face ao teclado")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            // Bloco Comparativo Detalhado (Voz vs Digitação Manual)
            VStack(spacing: 8) {
                HStack {
                    Label("A Ditar (Voz)", systemImage: "waveform")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(formattedDuration(viewModel.totalSpeakingSeconds))
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundStyle(.primary)
                }

                HStack {
                    Label("A Escrever (~45 PPM)", systemImage: "keyboard")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(formattedDuration(viewModel.estimatedTypingSeconds))
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundStyle(.primary)
                }

                // Barra Proporcional de Comparação
                comparisonBarView
                    .padding(.vertical, 2)

                Divider()

                HStack {
                    Text("Diferença Poupada")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.green)
                    Spacer()
                    Text("+" + formattedDuration(viewModel.timeSavedSeconds))
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color.green)
                }
            }
            .padding(10)
            .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            Divider()

            // Sub-métricas: Palavras, Sessões e Ritmo de Fala
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(viewModel.stats.totalWords.formatted())
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.primary)
                    Text("Palavras")
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(.secondary)
                }

                Spacer()

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

            // Nota de Rodapé / Roadmap V2
            HStack(alignment: .top, spacing: 6) {
                Image(systemName: "info.circle")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .padding(.top, 1)

                Text("Baseado na média humana de 45 PPM. No Sonotype v2 poderá realizar um teste de digitação para calibrar a sua velocidade.")
                    .font(.system(size: 10, weight: .regular))
                    .foregroundStyle(.secondary.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, 2)
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(.separator.opacity(0.5), lineWidth: 0.5)
        )
    }

    private var comparisonBarView: some View {
        let speaking = viewModel.totalSpeakingSeconds
        let saved = viewModel.timeSavedSeconds
        let total = max(1.0, speaking + saved)
        let voiceRatio = max(0.05, min(0.95, speaking / total))
        let savedRatio = max(0.05, min(0.95, saved / total))

        return VStack(spacing: 4) {
            GeometryReader { geo in
                HStack(spacing: 2) {
                    RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                        .fill(Color.accentColor)
                        .frame(width: max(4, geo.size.width * voiceRatio))

                    RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                        .fill(Color.green)
                        .frame(width: max(4, geo.size.width * savedRatio))
                }
            }
            .frame(height: 6)

            HStack {
                HStack(spacing: 4) {
                    Circle().fill(Color.accentColor).frame(width: 5, height: 5)
                    Text("Voz (\(formattedDuration(speaking)))")
                        .font(.system(size: 9.5, weight: .medium))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                HStack(spacing: 4) {
                    Circle().fill(Color.green).frame(width: 5, height: 5)
                    Text("Poupado (\(formattedDuration(saved)))")
                        .font(.system(size: 9.5, weight: .semibold))
                        .foregroundStyle(Color.green)
                }
            }
        }
    }

    // MARK: - 3. Cartão de Atividade (Novo Calendário Mensal Intuitivo)

    private var calendarActivityCard: some View {
        let days = generateCalendarDays(for: displayedMonth)
        let statsDict = Dictionary(uniqueKeysWithValues: viewModel.dailyStats.map { ($0.dayKey, $0) })
        let currentStreak = viewModel.currentStreakDays
        let activeDays = viewModel.activeDaysCount

        return VStack(alignment: .leading, spacing: 14) {
            // Cabeçalho: Título "Atividade" + Navegação de Mês + Badges
            HStack(alignment: .center, spacing: 10) {
                Label("Atividade", systemImage: "calendar")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.primary)

                Spacer()

                // Controlo de Navegação Mensal
                HStack(spacing: 6) {
                    Button {
                        previousMonth()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.primary)
                            .frame(width: 22, height: 22)
                            .background(.quaternary, in: RoundedRectangle(cornerRadius: 5, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .help("Mês anterior")

                    Text(formattedMonthTitle)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.primary)
                        .frame(minWidth: 100)

                    Button {
                        nextMonth()
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.primary)
                            .frame(width: 22, height: 22)
                            .background(.quaternary, in: RoundedRectangle(cornerRadius: 5, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .help("Mês seguinte")

                    if !isDisplayingCurrentMonth {
                        Button {
                            goToToday()
                        } label: {
                            Text("Hoje")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(Color.accentColor)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(Color.accentColor.opacity(0.12), in: Capsule())
                        }
                        .buttonStyle(.plain)
                        .help("Voltar ao mês atual")
                    }
                }

                Spacer()

                // Badge de Streak
                HStack(spacing: 5) {
                    Image(systemName: "flame.fill")
                        .foregroundStyle(currentStreak > 0 ? Color.orange : Color.secondary)
                        .font(.system(size: 11, weight: .bold))

                    Text("\(currentStreak) \(currentStreak == 1 ? "dia" : "dias")")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.primary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.quaternary, in: Capsule())

                // Badge de Dias Ativos
                Text("\(activeDays) ativos")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.quaternary, in: Capsule())
            }

            Divider()

            // Corpo do Calendário: Grelha Mensal à Esquerda + Resumo e Inspetor à Direita
            HStack(alignment: .top, spacing: 18) {
                // Coluna Esquerda: Grelha Semanal e Dias do Calendário
                VStack(alignment: .leading, spacing: 8) {
                    // Cabeçalho dos Dias da Semana (Seg a Dom)
                    HStack(spacing: 4) {
                        ForEach(weekdaySymbols, id: \.self) { symbol in
                            Text(symbol)
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(.secondary)
                                .frame(width: 30, alignment: .center)
                        }
                    }

                    // Grelha de Células do Calendário (7 colunas)
                    LazyVGrid(columns: Array(repeating: GridItem(.fixed(30), spacing: 4), count: 7), spacing: 4) {
                        ForEach(days) { day in
                            let stat = statsDict[day.dayKey]
                            let wordCount = stat?.totalWords ?? 0
                            calendarDayCell(day: day, wordCount: wordCount, stat: stat)
                        }
                    }

                    // Legenda de Intensidade no Rodapé
                    HStack(spacing: 5) {
                        Text("Menos")
                            .font(.system(size: 9.5, weight: .regular))
                            .foregroundStyle(.secondary)

                        heatLegendSquare(color: Color.secondary.opacity(0.10))
                        heatLegendSquare(color: Color.accentColor.opacity(0.25))
                        heatLegendSquare(color: Color.accentColor.opacity(0.60))
                        heatLegendSquare(color: Color.accentColor)

                        Text("Mais")
                            .font(.system(size: 9.5, weight: .regular))
                            .foregroundStyle(.secondary)

                        Spacer()

                        Text("Clique para inspecionar")
                            .font(.system(size: 9.5, weight: .regular))
                            .foregroundStyle(.secondary.opacity(0.7))
                    }
                    .padding(.top, 4)
                }

                Divider()
                    .frame(maxHeight: 220)

                // Coluna Direita: Inspetor do Dia Selecionado + Resumo do Mês
                VStack(alignment: .leading, spacing: 12) {
                    // 1. Inspetor do Dia Selecionado
                    selectedDayInspectorCard(statsDict: statsDict)

                    Divider()

                    // 2. Resumo Analítico do Mês em Exibição
                    let mStats = monthStats(days: days, statsDict: statsDict)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Resumo de \(formattedShortMonthTitle)")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.secondary)

                        activityInsightRow(
                            title: "Total no Mês",
                            value: "\(mStats.totalWords) palavras",
                            icon: "character.textbox"
                        )

                        activityInsightRow(
                            title: "Dias com Ditados",
                            value: "\(mStats.activeDays) dias",
                            icon: "calendar.badge.clock"
                        )

                        activityInsightRow(
                            title: "Média / Dia Ativo",
                            value: "\(mStats.avgWords) / dia",
                            icon: "chart.line.uptrend.xyaxis"
                        )

                        if let peakDay = mStats.peakDayNumber, mStats.peakWords > 0 {
                            activityInsightRow(
                                title: "Pico no Mês",
                                value: "\(mStats.peakWords) pal (dia \(peakDay))",
                                icon: "trophy.fill"
                            )
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(.separator.opacity(0.5), lineWidth: 0.5)
        )
    }

    // MARK: - Célula de Dia do Calendário

    private func calendarDayCell(day: CalendarDayItem, wordCount: Int, stat: SessionStat?) -> some View {
        let isSelected = calendar.isDate(day.date, inSameDayAs: selectedDate)
        let isHovered = hoveredDayKey == day.dayKey

        let cellBackground: Color = {
            guard day.isCurrentMonth else {
                return Color.clear
            }
            if wordCount == 0 {
                return Color.secondary.opacity(0.08)
            } else if wordCount < 50 {
                return Color.accentColor.opacity(0.22)
            } else if wordCount < 200 {
                return Color.accentColor.opacity(0.58)
            } else {
                return Color.accentColor
            }
        }()

        let textColor: Color = {
            guard day.isCurrentMonth else {
                return Color.secondary.opacity(0.30)
            }
            if wordCount >= 200 {
                return Color.white
            }
            if day.isToday {
                return Color.accentColor
            }
            return Color.primary
        }()

        let tooltipText: String = {
            let df = DateFormatter()
            df.locale = Locale(identifier: "pt_PT")
            df.dateFormat = "d 'de' MMMM"
            let dateStr = df.string(from: day.date)
            if wordCount > 0 {
                let trans = stat?.totalTranscriptions ?? 1
                return "\(dateStr): \(wordCount) palavras (\(trans) sessões)"
            } else {
                return "\(dateStr): Sem atividade"
            }
        }()

        return Button {
            selectedDate = day.date
        } label: {
            VStack(spacing: 1.5) {
                Text("\(day.dayNumber)")
                    .font(.system(size: 11, weight: day.isToday ? .bold : .medium))
                    .foregroundStyle(textColor)

                if wordCount > 0 && day.isCurrentMonth {
                    Circle()
                        .fill(wordCount >= 200 ? Color.white : Color.accentColor)
                        .frame(width: 3.5, height: 3.5)
                } else if day.isToday && day.isCurrentMonth {
                    Circle()
                        .fill(Color.accentColor)
                        .frame(width: 3, height: 3)
                } else {
                    Spacer().frame(height: 3.5)
                }
            }
            .frame(width: 30, height: 30)
            .background(cellBackground, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(
                        isSelected ? Color.primary : (isHovered ? Color.secondary.opacity(0.4) : (day.isToday && day.isCurrentMonth ? Color.accentColor.opacity(0.6) : Color.clear)),
                        lineWidth: isSelected ? 1.8 : 1.0
                    )
            )
        }
        .buttonStyle(.plain)
        .help(tooltipText)
        .onHover { hovering in
            if hovering {
                hoveredDayKey = day.dayKey
            } else if hoveredDayKey == day.dayKey {
                hoveredDayKey = nil
            }
        }
    }

    private func heatLegendSquare(color: Color) -> some View {
        RoundedRectangle(cornerRadius: 2.5, style: .continuous)
            .fill(color)
            .frame(width: 10, height: 10)
    }

    // MARK: - Painel do Dia Selecionado

    private func selectedDayInspectorCard(statsDict: [String: SessionStat]) -> some View {
        let key = SessionStat.makeDayKey(from: selectedDate, calendar: calendar)
        let stat = statsDict[key]
        let isToday = calendar.isDateInToday(selectedDate)

        let df = DateFormatter()
        df.locale = Locale(identifier: "pt_PT")
        df.dateFormat = "d 'de' MMMM"
        let dateStr = df.string(from: selectedDate)

        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 5) {
                Text(isToday ? "Hoje (\(dateStr))" : dateStr)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.primary)

                if isToday {
                    Text("ATUAL")
                        .font(.system(size: 8.5, weight: .bold))
                        .foregroundStyle(Color.accentColor)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Color.accentColor.opacity(0.12), in: Capsule())
                }
            }

            if let s = stat, s.totalWords > 0 {
                HStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("\(s.totalWords)")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Color.accentColor)
                        Text("palavras")
                            .font(.system(size: 9.5, weight: .regular))
                            .foregroundStyle(.secondary)
                    }

                    Text("•")
                        .foregroundStyle(.secondary.opacity(0.4))

                    VStack(alignment: .leading, spacing: 1) {
                        Text("\(s.totalTranscriptions)")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.primary)
                        Text("ditados")
                            .font(.system(size: 9.5, weight: .regular))
                            .foregroundStyle(.secondary)
                    }

                    Text("•")
                        .foregroundStyle(.secondary.opacity(0.4))

                    VStack(alignment: .leading, spacing: 1) {
                        Text(formattedDuration(s.totalDurationSeconds))
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .foregroundStyle(.primary)
                        Text("tempo voz")
                            .font(.system(size: 9.5, weight: .regular))
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                Text("Sem atividade de voz gravada neste dia.")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.04), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
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

    // MARK: - Formatadores e Helpers de Calendário

    private struct CalendarDayItem: Identifiable, Equatable {
        let id: String
        let date: Date
        let dayNumber: Int
        let isCurrentMonth: Bool
        let isToday: Bool
        let dayKey: String
    }

    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.locale = Locale(identifier: "pt_PT")
        cal.firstWeekday = 2 // Segunda-feira como início de semana europeu
        return cal
    }

    private let weekdaySymbols: [String] = ["Seg", "Ter", "Qua", "Qui", "Sex", "Sáb", "Dom"]

    private var isDisplayingCurrentMonth: Bool {
        calendar.isDate(displayedMonth, equalTo: Date(), toGranularity: .month)
    }

    private var formattedMonthTitle: String {
        let df = DateFormatter()
        df.locale = Locale(identifier: "pt_PT")
        df.dateFormat = "MMMM yyyy"
        let str = df.string(from: displayedMonth)
        return str.prefix(1).uppercased() + str.dropFirst()
    }

    private var formattedShortMonthTitle: String {
        let df = DateFormatter()
        df.locale = Locale(identifier: "pt_PT")
        df.dateFormat = "MMMM"
        let str = df.string(from: displayedMonth)
        return str.prefix(1).uppercased() + str.dropFirst()
    }

    private func previousMonth() {
        if let prev = calendar.date(byAdding: .month, value: -1, to: displayedMonth) {
            displayedMonth = prev
        }
    }

    private func nextMonth() {
        if let next = calendar.date(byAdding: .month, value: 1, to: displayedMonth) {
            displayedMonth = next
        }
    }

    private func goToToday() {
        displayedMonth = Date()
        selectedDate = Date()
    }

    private func generateCalendarDays(for monthDate: Date) -> [CalendarDayItem] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: monthDate) else {
            return []
        }

        let firstDayOfMonth = monthInterval.start
        let weekday = calendar.component(.weekday, from: firstDayOfMonth)
        // Offset a partir de Segunda-feira (weekday = 2)
        let leadingDaysCount = (weekday - 2 + 7) % 7

        var items: [CalendarDayItem] = []
        let todayKey = SessionStat.makeDayKey(from: Date(), calendar: calendar)

        // 1. Dias anteriores do mês findo
        if leadingDaysCount > 0 {
            for i in (1...leadingDaysCount).reversed() {
                if let date = calendar.date(byAdding: .day, value: -i, to: firstDayOfMonth) {
                    let key = SessionStat.makeDayKey(from: date, calendar: calendar)
                    let dayNum = calendar.component(.day, from: date)
                    items.append(CalendarDayItem(
                        id: key,
                        date: date,
                        dayNumber: dayNum,
                        isCurrentMonth: false,
                        isToday: key == todayKey,
                        dayKey: key
                    ))
                }
            }
        }

        // 2. Dias do mês corrente
        let numberOfDays = calendar.range(of: .day, in: .month, for: monthDate)?.count ?? 30
        for day in 1...numberOfDays {
            if let date = calendar.date(bySetting: .day, value: day, of: firstDayOfMonth) {
                let key = SessionStat.makeDayKey(from: date, calendar: calendar)
                items.append(CalendarDayItem(
                    id: key,
                    date: date,
                    dayNumber: day,
                    isCurrentMonth: true,
                    isToday: key == todayKey,
                    dayKey: key
                ))
            }
        }

        // 3. Dias posteriores para completar as colunas semanais (múltiplo de 7)
        let remaining = (7 - (items.count % 7)) % 7
        if remaining > 0, let lastDay = items.last?.date {
            for i in 1...remaining {
                if let date = calendar.date(byAdding: .day, value: i, to: lastDay) {
                    let key = SessionStat.makeDayKey(from: date, calendar: calendar)
                    let dayNum = calendar.component(.day, from: date)
                    items.append(CalendarDayItem(
                        id: key,
                        date: date,
                        dayNumber: dayNum,
                        isCurrentMonth: false,
                        isToday: key == todayKey,
                        dayKey: key
                    ))
                }
            }
        }

        return items
    }

    private func monthStats(
        days: [CalendarDayItem],
        statsDict: [String: SessionStat]
    ) -> (totalWords: Int, activeDays: Int, avgWords: Int, peakWords: Int, peakDayNumber: Int?) {
        let currentMonthDays = days.filter { $0.isCurrentMonth }
        var totalWords = 0
        var activeDays = 0
        var peakWords = 0
        var peakDay: Int? = nil

        for day in currentMonthDays {
            if let stat = statsDict[day.dayKey], stat.totalWords > 0 {
                totalWords += stat.totalWords
                activeDays += 1
                if stat.totalWords > peakWords {
                    peakWords = stat.totalWords
                    peakDay = day.dayNumber
                }
            }
        }

        let avg = activeDays > 0 ? totalWords / activeDays : 0
        return (totalWords, activeDays, avg, peakWords, peakDay)
    }

    private func activityInsightRow(title: String, value: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 9.5, weight: .regular))
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(.primary)
            }
        }
    }

    // MARK: - Formatadores de Tempo e Duração

    private var formattedTimeSavedHero: String {
        let minutes = viewModel.timeSavedSeconds / 60.0
        if minutes < 1.0 {
            if viewModel.stats.totalWords == 0 {
                return "0 min"
            }
            return "< 1 min"
        } else if minutes < 60.0 {
            return "+\(Int(minutes)) min"
        } else {
            let hours = minutes / 60.0
            return String(format: "+%.1fh", hours)
        }
    }

    private func formattedDuration(_ seconds: Double) -> String {
        if seconds < 1.0 {
            return "0s"
        } else if seconds < 60.0 {
            return "\(Int(seconds))s"
        } else if seconds < 3600.0 {
            let mins = Int(seconds) / 60
            let secs = Int(seconds) % 60
            return secs > 0 ? "\(mins)m \(secs)s" : "\(mins)m"
        } else {
            let hours = Int(seconds) / 3600
            let mins = (Int(seconds) % 3600) / 60
            return mins > 0 ? "\(hours)h \(mins)m" : "\(hours)h"
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
