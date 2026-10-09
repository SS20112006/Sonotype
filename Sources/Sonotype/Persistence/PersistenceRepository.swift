import Foundation
import SwiftData
import os

/// Formatos suportados para exportação do histórico de transcrições.
public enum ExportFormat: String, CaseIterable, Sendable {
    case plainText = "txt"
    case markdown = "md"
    case csv = "csv"
}

/// Estrutura agregada de estatísticas de utilização do Sonotype.
public struct TotalUsageStats: Equatable, Sendable {
    public let totalTranscriptions: Int
    public let totalWords: Int
    public let totalDurationSeconds: TimeInterval
    public let portugueseWords: Int
    public let englishWords: Int
    public let estimatedTimeSavedMinutes: Double

    public init(
        totalTranscriptions: Int = 0,
        totalWords: Int = 0,
        totalDurationSeconds: TimeInterval = 0.0,
        portugueseWords: Int = 0,
        englishWords: Int = 0,
        estimatedTimeSavedMinutes: Double = 0.0
    ) {
        self.totalTranscriptions = totalTranscriptions
        self.totalWords = totalWords
        self.totalDurationSeconds = totalDurationSeconds
        self.portugueseWords = portugueseWords
        self.englishWords = englishWords
        self.estimatedTimeSavedMinutes = estimatedTimeSavedMinutes
    }
}

// MARK: - Persistence Repository

/// Implementação da camada de persistência local sobre SwiftData e SQLite.
///
/// PONYTAIL & ZERO PERSISTÊNCIA DE ÁUDIO:
/// Todos os modelos guardam exclusivamente texto, durações e contagens numéricas.
/// Nenhum ficheiro de áudio ou buffer é gravado no disco.
@MainActor
public final class PersistenceRepository {
    private static let logger = Logger(subsystem: "com.sonotype.app", category: "PersistenceRepository")

    /// Instância partilhada global padrão da aplicação.
    public static let shared: PersistenceRepository = {
        do {
            let container = try PersistenceContainerFactory.makeContainer(inMemory: false)
            return PersistenceRepository(container: container)
        } catch {
            logger.fault("PersistenceRepository.shared falhou ao inicializar armazenamento persistente em disco: \(error.localizedDescription, privacy: .public). Inicializando contentor defensivo em memória.")
            let fallback = try! PersistenceContainerFactory.makeContainer(inMemory: true)
            return PersistenceRepository(container: fallback)
        }
    }()

    public let container: ModelContainer
    public let context: ModelContext

    public init(container: ModelContainer) {
        self.container = container
        self.context = container.mainContext
    }

    public init(container: ModelContainer, context: ModelContext) {
        self.container = container
        self.context = context
    }

    public init(inMemory: Bool = false) throws {
        let container = try PersistenceContainerFactory.makeContainer(inMemory: inMemory)
        self.container = container
        self.context = container.mainContext
    }

    private func saveContextIfNeeded() throws {
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                Self.logger.error("Falha ao gravar alterações no ModelContext: \(error.localizedDescription, privacy: .public)")
                throw error
            }
        }
    }

    // MARK: - Transcrições

    @discardableResult
    public func recordTranscription(
        text: String,
        duration: TimeInterval = 0.0,
        language: String = "pt-PT",
        date: Date = Date()
    ) throws -> TranscriptionRecord {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let record = TranscriptionRecord(
            text: trimmed,
            createdAt: date,
            duration: duration,
            detectedLanguage: language
        )
        context.insert(record)

        // Sincroniza estatísticas diárias automaticamente e persiste
        _ = try recordSessionStat(
            wordCount: record.wordCount,
            duration: duration,
            language: language,
            date: date
        )

        return record
    }

    public func fetchTranscriptions(
        searchQuery: String? = nil,
        limit: Int? = nil
    ) throws -> [TranscriptionRecord] {
        var descriptor = FetchDescriptor<TranscriptionRecord>(
            sortBy: [SortDescriptor(\TranscriptionRecord.createdAt, order: .reverse)]
        )
        if let limit = limit, searchQuery == nil {
            descriptor.fetchLimit = limit
        }

        var results = try context.fetch(descriptor)

        if let query = searchQuery?.trimmingCharacters(in: .whitespacesAndNewlines), !query.isEmpty {
            results = results.filter { $0.text.localizedCaseInsensitiveContains(query) }
            if let limit = limit {
                results = Array(results.prefix(limit))
            }
        }

        return results
    }

    public func deleteTranscription(_ record: TranscriptionRecord) throws {
        context.delete(record)
        try saveContextIfNeeded()
    }

    public func deleteAllTranscriptions() throws {
        let descriptor = FetchDescriptor<TranscriptionRecord>()
        let records = try context.fetch(descriptor)
        for record in records {
            context.delete(record)
        }
        try saveContextIfNeeded()
    }

    public func exportTranscriptions(
        _ records: [TranscriptionRecord],
        format: ExportFormat
    ) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"

        switch format {
        case .plainText:
            return records.map { record in
                let dateStr = dateFormatter.string(from: record.createdAt)
                return "[\(dateStr)] (\(record.detectedLanguage)):\n\(record.text)\n"
            }.joined(separator: "\n")

        case .markdown:
            var md = "# Histórico de Transcrições — Sonotype\n\n"
            for record in records {
                let dateStr = dateFormatter.string(from: record.createdAt)
                let durationStr = String(format: "%.1fs", record.duration)
                md += "### \(dateStr) (\(record.detectedLanguage) • \(record.wordCount) palavras • \(durationStr))\n\n"
                md += "\(record.text)\n\n---\n\n"
            }
            return md.trimmingCharacters(in: .whitespacesAndNewlines)

        case .csv:
            let dateFormatter = ISO8601DateFormatter()
            var csv = "id,created_at,language,duration_seconds,word_count,text\r\n"
            for record in records {
                let escapedText = record.text.replacingOccurrences(of: "\"", with: "\"\"")
                let dateStr = dateFormatter.string(from: record.createdAt)
                csv += "\"\(record.id.uuidString)\",\"\(dateStr)\",\"\(record.detectedLanguage)\",\(record.duration),\(record.wordCount),\"\(escapedText)\"\r\n"
            }
            return csv
        }
    }

    public func exportAllTranscriptions(format: ExportFormat) throws -> String {
        let records = try fetchTranscriptions()
        return exportTranscriptions(records, format: format)
    }

    // MARK: - Vocabulário Personalizado

    @discardableResult
    public func addVocabulary(word: String, priority: Int = 1) throws -> VocabularyEntry {
        let trimmed = word.trimmingCharacters(in: .whitespacesAndNewlines)
        let descriptor = FetchDescriptor<VocabularyEntry>()
        let existingEntries = try context.fetch(descriptor)

        if let existing = existingEntries.first(where: { $0.word.caseInsensitiveCompare(trimmed) == .orderedSame }) {
            existing.priority = priority
            try saveContextIfNeeded()
            return existing
        }

        let entry = VocabularyEntry(word: trimmed, priority: priority)
        context.insert(entry)
        try saveContextIfNeeded()
        return entry
    }

    public func fetchVocabulary() throws -> [VocabularyEntry] {
        let descriptor = FetchDescriptor<VocabularyEntry>(
            sortBy: [
                SortDescriptor(\VocabularyEntry.priority, order: .reverse),
                SortDescriptor(\VocabularyEntry.word, order: .forward)
            ]
        )
        return try context.fetch(descriptor)
    }

    public func deleteVocabulary(_ entry: VocabularyEntry) throws {
        context.delete(entry)
        try saveContextIfNeeded()
    }

    // MARK: - Regras de Substituição Rápida

    @discardableResult
    public func addReplacementRule(
        trigger: String,
        replacement: String,
        isCaseSensitive: Bool = false
    ) throws -> WordReplacementRule {
        let trimmedTrigger = trigger.trimmingCharacters(in: .whitespacesAndNewlines)
        let rule = WordReplacementRule(
            trigger: trimmedTrigger,
            replacement: replacement,
            isCaseSensitive: isCaseSensitive
        )
        context.insert(rule)
        try saveContextIfNeeded()
        return rule
    }

    public func fetchReplacementRules() throws -> [WordReplacementRule] {
        let descriptor = FetchDescriptor<WordReplacementRule>(
            sortBy: [SortDescriptor(\WordReplacementRule.createdAt, order: .forward)]
        )
        return try context.fetch(descriptor)
    }

    public func deleteReplacementRule(_ rule: WordReplacementRule) throws {
        context.delete(rule)
        try saveContextIfNeeded()
    }

    public func applyReplacements(to text: String) throws -> String {
        let rules = try fetchReplacementRules()
        var result = text
        for rule in rules {
            result = rule.apply(to: result)
        }
        return result
    }

    // MARK: - Estatísticas de Sessão

    @discardableResult
    public func recordSessionStat(
        wordCount: Int,
        duration: TimeInterval = 0.0,
        language: String = "pt-PT",
        date: Date = Date()
    ) throws -> SessionStat {
        let dayKey = SessionStat.makeDayKey(from: date)
        let stat: SessionStat

        if let existing = try fetchStat(for: date) {
            stat = existing
            stat.totalTranscriptions += 1
            stat.totalWords += wordCount
            stat.totalDurationSeconds += duration
            let langLower = language.lowercased()
            if langLower.hasPrefix("pt") {
                stat.portugueseWords += wordCount
            } else if langLower.hasPrefix("en") {
                stat.englishWords += wordCount
            }
        } else {
            let langLower = language.lowercased()
            let isPt = langLower.hasPrefix("pt")
            let isEn = langLower.hasPrefix("en")
            stat = SessionStat(
                date: date,
                dayKey: dayKey,
                totalTranscriptions: 1,
                totalWords: wordCount,
                totalDurationSeconds: duration,
                portugueseWords: isPt ? wordCount : 0,
                englishWords: isEn ? wordCount : 0
            )
            context.insert(stat)
        }

        try saveContextIfNeeded()
        return stat
    }

    public func fetchStat(for date: Date) throws -> SessionStat? {
        let dayKey = SessionStat.makeDayKey(from: date)
        let descriptor = FetchDescriptor<SessionStat>(
            predicate: #Predicate<SessionStat> { stat in
                stat.dayKey == dayKey
            }
        )
        let results = try context.fetch(descriptor)
        return results.first
    }

    public func fetchTodayStat() throws -> SessionStat? {
        try fetchStat(for: Date())
    }

    public func fetchTotalStats() throws -> TotalUsageStats {
        let descriptor = FetchDescriptor<SessionStat>()
        let stats = try context.fetch(descriptor)

        var totalTranscriptions = 0
        var totalWords = 0
        var totalDuration: TimeInterval = 0
        var ptWords = 0
        var enWords = 0

        for stat in stats {
            totalTranscriptions += stat.totalTranscriptions
            totalWords += stat.totalWords
            totalDuration += stat.totalDurationSeconds
            ptWords += stat.portugueseWords
            enWords += stat.englishWords
        }

        let typingMinutes = Double(totalWords) / 40.0
        let speakingMinutes = totalDuration / 60.0
        let timeSaved = max(0.0, typingMinutes - speakingMinutes)

        return TotalUsageStats(
            totalTranscriptions: totalTranscriptions,
            totalWords: totalWords,
            totalDurationSeconds: totalDuration,
            portugueseWords: ptWords,
            englishWords: enWords,
            estimatedTimeSavedMinutes: timeSaved
        )
    }

    // MARK: - Limpeza Geral de Dados

    public func clearAllData() throws {
        try deleteAllTranscriptions()

        let vocabDescriptor = FetchDescriptor<VocabularyEntry>()
        for entry in try context.fetch(vocabDescriptor) {
            context.delete(entry)
        }

        let rulesDescriptor = FetchDescriptor<WordReplacementRule>()
        for rule in try context.fetch(rulesDescriptor) {
            context.delete(rule)
        }

        let statsDescriptor = FetchDescriptor<SessionStat>()
        for stat in try context.fetch(statsDescriptor) {
            context.delete(stat)
        }

        try saveContextIfNeeded()
    }
}
