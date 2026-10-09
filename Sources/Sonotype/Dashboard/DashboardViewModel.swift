import AppKit
import Foundation
import Observation
import SwiftData
import UniformTypeIdentifiers
import os

/// Secções funcionais navegáveis na barra lateral do Dashboard.
public enum DashboardSection: String, CaseIterable, Identifiable, Sendable {
    case home = "Início"
    case history = "Histórico"
    case vocabulary = "Dicionário"
    case stats = "Estatísticas"

    public var id: String { rawValue }
}

/// Extensão de conveniência para metadados de ficheiro do formato de exportação.
extension ExportFormat {
    public var fileExtension: String {
        rawValue
    }

    public var contentType: UTType? {
        switch self {
        case .plainText:
            return .plainText
        case .markdown:
            return UTType(filenameExtension: "md") ?? .plainText
        case .csv:
            return .commaSeparatedText
        }
    }
}

/// ViewModel reativo do Dashboard do Sonotype com suporte a observação granular (@Observable),
/// isolamento na MainThread (@MainActor) e total conformidade com Swift 6 Concurrency (Sendable).
///
/// PONYTAIL & CODE ECONOMY:
/// Reutiliza os motores já consolidados de SwiftData em PersistenceRepository, sem camadas
/// redundantes ou abstrações especulativas. Zero retenção de áudio.
@Observable
@MainActor
public final class DashboardViewModel: Sendable {
    private static let logger = Logger(subsystem: "com.sonotype.app", category: "DashboardViewModel")

    public let repository: PersistenceRepository
    public let pasteboard: NSPasteboard

    // MARK: - Estado Observado

    public var selectedSection: DashboardSection
    public var searchQuery: String {
        didSet {
            if searchQuery != oldValue {
                loadHistory()
            }
        }
    }
    public var historyRecords: [TranscriptionRecord]
    public var vocabularyEntries: [VocabularyEntry]
    public var replacementRules: [WordReplacementRule]
    public var stats: TotalUsageStats
    public var dailyStats: [SessionStat]
    public var preferencesManager: PreferencesManager?
    public var permissionsService: PermissionsServiceProtocol?
    public var selectedRecord: TranscriptionRecord?
    public var errorMessage: String?

    /// Handler opcional para simular ou interceptar a escolha de URL no NSSavePanel em testes
    public var savePanelHandler: (@MainActor (NSSavePanel) -> URL?)?

    // MARK: - Inicializador

    public init(
        repository: PersistenceRepository = .shared,
        pasteboard: NSPasteboard = .general,
        preferencesManager: PreferencesManager? = nil,
        permissionsService: PermissionsServiceProtocol? = nil,
        autoLoad: Bool = false
    ) {
        self.repository = repository
        self.pasteboard = pasteboard
        self.preferencesManager = preferencesManager
        self.permissionsService = permissionsService
        self.selectedSection = .home
        self.searchQuery = ""
        self.historyRecords = []
        self.vocabularyEntries = []
        self.replacementRules = []
        self.stats = TotalUsageStats()
        self.dailyStats = []
        self.selectedRecord = nil
        self.errorMessage = nil

        if autoLoad {
            loadAll()
        }
    }

    // MARK: - Carregamento de Dados

    /// Carrega todos os dados do repositório: histórico, vocabulário, regras e estatísticas agregadas.
    public func loadAll() {
        errorMessage = nil
        loadHistory()
        loadVocabulary()
        loadReplacementRules()
        loadStats()
        loadDailyStats()
    }

    /// Carrega as transcrições do histórico com filtragem de pesquisa por substring se aplicável.
    public func loadHistory() {
        do {
            let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
            historyRecords = try repository.fetchTranscriptions(searchQuery: query.isEmpty ? nil : query)
            if let selected = selectedRecord, !historyRecords.contains(where: { $0.id == selected.id }) {
                selectedRecord = nil
            }
        } catch {
            errorMessage = "Falha ao carregar histórico: \(error.localizedDescription)"
            Self.logger.error("Erro ao carregar histórico: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Carrega todos os termos de vocabulário personalizado.
    public func loadVocabulary() {
        do {
            vocabularyEntries = try repository.fetchVocabulary()
        } catch {
            errorMessage = "Falha ao carregar vocabulário: \(error.localizedDescription)"
            Self.logger.error("Erro ao carregar vocabulário: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Carrega todas as regras de substituição de texto.
    public func loadReplacementRules() {
        do {
            replacementRules = try repository.fetchReplacementRules()
        } catch {
            errorMessage = "Falha ao carregar regras de substituição: \(error.localizedDescription)"
            Self.logger.error("Erro ao carregar regras de substituição: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Recalcula e carrega as estatísticas de utilização global.
    public func loadStats() {
        do {
            stats = try repository.fetchTotalStats()
        } catch {
            errorMessage = "Falha ao carregar estatísticas: \(error.localizedDescription)"
            Self.logger.error("Erro ao carregar estatísticas: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Carrega as estatísticas diárias para o heatmap de atividade e cálculo de streaks.
    public func loadDailyStats() {
        do {
            dailyStats = try repository.fetchDailyStats(limit: 35)
        } catch {
            Self.logger.error("Falha ao carregar estatísticas diárias: \(error.localizedDescription, privacy: .public)")
            dailyStats = []
        }
    }

    /// Retorna os dias consecutivos ativos de utilização (streak atual).
    public var currentStreakDays: Int {
        let calendar = Calendar.current
        let todayKey = SessionStat.makeDayKey(from: Date(), calendar: calendar)
        let statsByDay = Dictionary(uniqueKeysWithValues: dailyStats.map { ($0.dayKey, $0) })

        var streak = 0
        var checkDate = Date()

        // Se hoje ainda não houver ditados, verifica se ontem houve para manter streak ativo
        if let todayStat = statsByDay[todayKey], todayStat.totalWords > 0 {
            streak += 1
            checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate) ?? checkDate
        } else {
            let yesterday = calendar.date(byAdding: .day, value: -1, to: checkDate) ?? checkDate
            let yesterdayKey = SessionStat.makeDayKey(from: yesterday, calendar: calendar)
            if let yStat = statsByDay[yesterdayKey], yStat.totalWords > 0 {
                streak += 1
                checkDate = calendar.date(byAdding: .day, value: -2, to: checkDate) ?? checkDate
            } else {
                return 0
            }
        }

        while true {
            let dayKey = SessionStat.makeDayKey(from: checkDate, calendar: calendar)
            if let stat = statsByDay[dayKey], stat.totalWords > 0 {
                streak += 1
                guard let prev = calendar.date(byAdding: .day, value: -1, to: checkDate) else { break }
                checkDate = prev
            } else {
                break
            }
        }

        return streak
    }

    /// Retorna o total de dias com utilização registada.
    public var activeDaysCount: Int {
        dailyStats.filter { $0.totalWords > 0 }.count
    }

    // MARK: - Ações de Histórico

    /// Elimina um registo individual de transcrição e atualiza a lista e estatísticas.
    public func deleteTranscription(_ record: TranscriptionRecord) {
        do {
            try repository.deleteTranscription(record)
            if selectedRecord?.id == record.id {
                selectedRecord = nil
            }
            loadHistory()
            loadStats()
        } catch {
            errorMessage = "Falha ao eliminar transcrição: \(error.localizedDescription)"
            Self.logger.error("Erro ao eliminar transcrição: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Apaga todo o histórico de transcrições e atualiza o estado e estatísticas.
    public func clearAllHistory() {
        do {
            try repository.deleteAllTranscriptions()
            selectedRecord = nil
            loadHistory()
            loadStats()
        } catch {
            errorMessage = "Falha ao apagar histórico: \(error.localizedDescription)"
            Self.logger.error("Erro ao apagar histórico: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Ações de Vocabulário

    /// Adiciona ou atualiza um termo no dicionário personalizado.
    public func addVocabulary(word: String, priority: Int = 1) {
        let trimmed = word.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        do {
            _ = try repository.addVocabulary(word: trimmed, priority: priority)
            loadVocabulary()
        } catch {
            errorMessage = "Falha ao adicionar vocabulário: \(error.localizedDescription)"
            Self.logger.error("Erro ao adicionar vocabulário: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Elimina um termo do dicionário personalizado.
    public func deleteVocabulary(_ entry: VocabularyEntry) {
        do {
            try repository.deleteVocabulary(entry)
            loadVocabulary()
        } catch {
            errorMessage = "Falha ao eliminar vocabulário: \(error.localizedDescription)"
            Self.logger.error("Erro ao eliminar vocabulário: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Ações de Regras de Substituição

    /// Adiciona uma nova regra de expansão de atalhos falados.
    public func addReplacementRule(trigger: String, replacement: String, isCaseSensitive: Bool = false) {
        let trimmedTrigger = trigger.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTrigger.isEmpty else { return }
        do {
            _ = try repository.addReplacementRule(
                trigger: trimmedTrigger,
                replacement: replacement,
                isCaseSensitive: isCaseSensitive
            )
            loadReplacementRules()
        } catch {
            errorMessage = "Falha ao adicionar regra de substituição: \(error.localizedDescription)"
            Self.logger.error("Erro ao adicionar regra de substituição: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Remove uma regra de expansão de atalhos falados.
    public func deleteReplacementRule(_ rule: WordReplacementRule) {
        do {
            try repository.deleteReplacementRule(rule)
            loadReplacementRules()
        } catch {
            errorMessage = "Falha ao eliminar regra de substituição: \(error.localizedDescription)"
            Self.logger.error("Erro ao eliminar regra de substituição: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Clipboard & Utilidades

    /// Copia o texto para a área de transferência do sistema.
    @discardableResult
    public func copyToClipboard(_ text: String) -> Bool {
        pasteboard.clearContents()
        return pasteboard.setString(text, forType: .string)
    }

    /// Limpa qualquer mensagem de erro ativa.
    public func clearError() {
        errorMessage = nil
    }

    // MARK: - Motor de Exportação

    /// Gera a representação textual formatada dos registos para o formato solicitado (.txt, .md, .csv).
    public func exportData(format: ExportFormat) -> String {
        let recordsToExport = historyRecords.isEmpty && searchQuery.isEmpty
            ? (try? repository.fetchTranscriptions()) ?? []
            : historyRecords
        return repository.exportTranscriptions(recordsToExport, format: format)
    }

    /// Grava os dados exportados diretamente no URL de ficheiro especificado.
    public func saveExport(format: ExportFormat, to url: URL) throws {
        let content = exportData(format: format)
        do {
            try content.write(to: url, atomically: true, encoding: .utf8)
        } catch {
            errorMessage = "Falha ao gravar ficheiro: \(error.localizedDescription)"
            throw error
        }
    }

    /// Gera um nome de ficheiro padrão amigável para exportação incluindo data e hora.
    public func defaultExportFileName(for format: ExportFormat, date: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HHmm"
        let dateStr = formatter.string(from: date)
        return "sonotype_transcricoes_\(dateStr).\(format.fileExtension)"
    }

    /// Abre o diálogo nativo do NSSavePanel no macOS e grava o ficheiro exportado no local selecionado.
    @discardableResult
    public func exportWithSavePanel(format: ExportFormat) -> Bool {
        let panel = NSSavePanel()
        panel.title = "Exportar Transcrições"
        panel.prompt = "Exportar"
        panel.nameFieldStringValue = defaultExportFileName(for: format)
        if let contentType = format.contentType {
            panel.allowedContentTypes = [contentType]
        }
        panel.canCreateDirectories = true

        let selectedURL: URL?
        if let customHandler = savePanelHandler {
            selectedURL = customHandler(panel)
        } else {
            let response = panel.runModal()
            selectedURL = (response == .OK) ? panel.url : nil
        }

        guard let destinationURL = selectedURL else {
            return false
        }

        do {
            try saveExport(format: format, to: destinationURL)
            return true
        } catch {
            errorMessage = "Falha ao gravar exportação: \(error.localizedDescription)"
            return false
        }
    }
}
