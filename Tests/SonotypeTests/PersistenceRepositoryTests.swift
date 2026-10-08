import Foundation
import SwiftData
import XCTest
@testable import Sonotype

@MainActor
final class PersistenceRepositoryTests: XCTestCase {
    private var repository: PersistenceRepository!

    override func setUp() async throws {
        try await super.setUp()
        // Cria repositório estritamente em memória RAM para isolamento e velocidade máxima
        repository = try PersistenceRepository(inMemory: true)
    }

    override func tearDown() async throws {
        repository = nil
        try await super.tearDown()
    }

    // MARK: - 1. Inserção e Leitura de Transcrições

    func testRecordTranscriptionAndFetch() throws {
        let text = "Esta é uma mensagem de teste em português com várias palavras."
        let date = Date()
        let duration: TimeInterval = 4.5
        let language = "pt-PT"

        let record = try repository.recordTranscription(
            text: text,
            duration: duration,
            language: language,
            date: date
        )

        XCTAssertEqual(record.text, text)
        XCTAssertEqual(record.duration, duration)
        XCTAssertEqual(record.detectedLanguage, language)
        XCTAssertEqual(record.wordCount, 11, "Deve calcular exatamente 11 palavras.")

        let allRecords = try repository.fetchTranscriptions()
        XCTAssertEqual(allRecords.count, 1)
        XCTAssertEqual(allRecords.first?.id, record.id)
    }

    // MARK: - 2. Ordenação Cronológica e Limite

    func testChronologicalOrderingAndLimit() throws {
        let baseDate = Date()
        try repository.recordTranscription(text: "Primeira", duration: 1.0, language: "pt-PT", date: baseDate.addingTimeInterval(-100))
        try repository.recordTranscription(text: "Segunda", duration: 2.0, language: "pt-PT", date: baseDate.addingTimeInterval(-50))
        try repository.recordTranscription(text: "Terceira", duration: 3.0, language: "pt-PT", date: baseDate)

        let all = try repository.fetchTranscriptions()
        XCTAssertEqual(all.count, 3)
        XCTAssertEqual(all[0].text, "Terceira", "A mais recente deve estar no topo (ordenação decrescente).")
        XCTAssertEqual(all[1].text, "Segunda")
        XCTAssertEqual(all[2].text, "Primeira")

        let limited = try repository.fetchTranscriptions(limit: 2)
        XCTAssertEqual(limited.count, 2)
        XCTAssertEqual(limited[0].text, "Terceira")
        XCTAssertEqual(limited[1].text, "Segunda")
    }

    // MARK: - 3. Pesquisa e Filtragem com Insensibilidade a Maiúsculas e Acentos

    func testSearchQueryFiltering() throws {
        try repository.recordTranscription(text: "Relatório de projeto urgente", language: "pt-PT")
        try repository.recordTranscription(text: "Reunião de alinhamento com a equipa", language: "pt-PT")
        try repository.recordTranscription(text: "Meeting notes about architecture overview", language: "en-US")

        let ptResults = try repository.fetchTranscriptions(searchQuery: "relatório")
        XCTAssertEqual(ptResults.count, 1)
        XCTAssertEqual(ptResults.first?.text, "Relatório de projeto urgente")

        // Teste de busca case-insensitive
        let enResults = try repository.fetchTranscriptions(searchQuery: "MEETING")
        XCTAssertEqual(enResults.count, 1)
        XCTAssertEqual(enResults.first?.text, "Meeting notes about architecture overview")

        // Busca com substring parcial comum aos registos em português ("de" em "de projeto" e "de alinhamento")
        let partialResults = try repository.fetchTranscriptions(searchQuery: "de")
        XCTAssertEqual(partialResults.count, 2)

        // Busca com substring parcial no meio de uma palavra (ex: "arch" em "architecture")
        let subResults = try repository.fetchTranscriptions(searchQuery: "arch")
        XCTAssertEqual(subResults.count, 1)
        XCTAssertEqual(subResults.first?.text, "Meeting notes about architecture overview")

        // Busca sem correspondência
        let emptyResults = try repository.fetchTranscriptions(searchQuery: "inexistente")
        XCTAssertTrue(emptyResults.isEmpty)
    }

    // MARK: - 4. Remoção Individual e Limpeza Total

    func testDeletionAndClearAll() throws {
        let rec1 = try repository.recordTranscription(text: "Item 1")
        let rec2 = try repository.recordTranscription(text: "Item 2")

        XCTAssertEqual(try repository.fetchTranscriptions().count, 2)

        try repository.deleteTranscription(rec1)
        let remaining = try repository.fetchTranscriptions()
        XCTAssertEqual(remaining.count, 1)
        XCTAssertEqual(remaining.first?.id, rec2.id)

        try repository.deleteAllTranscriptions()
        XCTAssertEqual(try repository.fetchTranscriptions().count, 0)
    }

    // MARK: - 5. Vocabulário Personalizado

    func testVocabularyOperations() throws {
        let entry1 = try repository.addVocabulary(word: "Sonotype", priority: 5)
        let entry2 = try repository.addVocabulary(word: "SwiftData", priority: 10)
        let entry3 = try repository.addVocabulary(word: "macOS", priority: 1)

        XCTAssertEqual(entry1.word, "Sonotype")
        XCTAssertEqual(entry2.priority, 10)

        // Atualização de prioridade ao reinserir mesma palavra (case-insensitive)
        let updated = try repository.addVocabulary(word: "sonotype", priority: 20)
        XCTAssertEqual(updated.id, entry1.id, "Deve atualizar a mesma entrada de vocabulário.")
        XCTAssertEqual(updated.priority, 20)

        let vocab = try repository.fetchVocabulary()
        XCTAssertEqual(vocab.count, 3)
        XCTAssertEqual(vocab[0].word, "Sonotype", "Maior prioridade (20) deve estar no topo.")
        XCTAssertEqual(vocab[1].word, "SwiftData", "Prioridade 10 deve estar em segundo.")
        XCTAssertEqual(vocab[2].word, "macOS", "Menor prioridade deve estar em último.")

        try repository.deleteVocabulary(entry3)
        XCTAssertEqual(try repository.fetchVocabulary().count, 2)
    }

    // MARK: - 6. Regras de Substituição Rápida de Texto

    func testWordReplacementRules() throws {
        try repository.addReplacementRule(trigger: "meu email", replacement: "suporte@sonotype.app", isCaseSensitive: false)
        try repository.addReplacementRule(trigger: "AI", replacement: "Inteligência Artificial", isCaseSensitive: true)

        let rules = try repository.fetchReplacementRules()
        XCTAssertEqual(rules.count, 2)

        let replaced1 = try repository.applyReplacements(to: "Por favor envia para MEU EMAIL agora.")
        XCTAssertEqual(replaced1, "Por favor envia para suporte@sonotype.app agora.")

        let replaced2 = try repository.applyReplacements(to: "O projeto usa AI e ai.")
        XCTAssertEqual(replaced2, "O projeto usa Inteligência Artificial e ai.", "Regra sensível a maiúsculas não deve afetar 'ai'.")

        try repository.deleteReplacementRule(rules[0])
        XCTAssertEqual(try repository.fetchReplacementRules().count, 1)
    }

    // MARK: - 7. Estatísticas de Sessão & Tempo Poupado

    func testSessionStatsAggregation() throws {
        let now = Date()
        try repository.recordTranscription(text: "Olá mundo em português", duration: 2.0, language: "pt-PT", date: now)
        try repository.recordTranscription(text: "Mais quatro palavras aqui", duration: 3.0, language: "pt-BR", date: now)
        try repository.recordTranscription(text: "Hello world in English", duration: 2.0, language: "en-US", date: now)

        let todayStat = try repository.fetchTodayStat()
        XCTAssertNotNil(todayStat)
        guard let stat = todayStat else { return }

        XCTAssertEqual(stat.totalTranscriptions, 3)
        XCTAssertEqual(stat.totalWords, 12) // 4 + 4 + 4
        XCTAssertEqual(stat.totalDurationSeconds, 7.0) // 2 + 3 + 2
        XCTAssertEqual(stat.portugueseWords, 8)
        XCTAssertEqual(stat.englishWords, 4)

        // Verificação do cálculo de tempo poupado estimado
        // 12 palavras a 40 ppm = 0.3 min (18 segundos).
        // Tempo a falar = 7 segundos = ~0.1167 min.
        // Tempo poupado = 0.3 - 0.1167 = ~0.1833 min > 0
        XCTAssertGreaterThan(stat.estimatedTimeSavedMinutes, 0.0)

        // Estatísticas Globais
        let totalStats = try repository.fetchTotalStats()
        XCTAssertEqual(totalStats.totalTranscriptions, 3)
        XCTAssertEqual(totalStats.totalWords, 12)
        XCTAssertEqual(totalStats.portugueseWords, 8)
        XCTAssertEqual(totalStats.englishWords, 4)
        XCTAssertGreaterThan(totalStats.estimatedTimeSavedMinutes, 0.0)
    }

    // MARK: - 8. Exportação nos Formatos PlainText, Markdown e CSV

    func testExportFormats() throws {
        let date = Date(timeIntervalSince1970: 1775484000) // Data fixa para teste determinístico
        let rec1 = TranscriptionRecord(
            text: "Primeira transcrição com \"aspas\"",
            createdAt: date,
            duration: 2.5,
            wordCount: 4,
            detectedLanguage: "pt-PT"
        )
        let rec2 = TranscriptionRecord(
            text: "Second transcription",
            createdAt: date.addingTimeInterval(60),
            duration: 1.5,
            wordCount: 2,
            detectedLanguage: "en-US"
        )

        let records = [rec1, rec2]

        // 1. Plain Text
        let txt = repository.exportTranscriptions(records, format: .plainText)
        XCTAssertTrue(txt.contains("(pt-PT):"))
        XCTAssertTrue(txt.contains("Primeira transcrição com \"aspas\""))
        XCTAssertTrue(txt.contains("(en-US):"))

        // 2. Markdown
        let md = repository.exportTranscriptions(records, format: .markdown)
        XCTAssertTrue(md.contains("# Histórico de Transcrições — Sonotype"))
        XCTAssertTrue(md.contains("###"))
        XCTAssertTrue(md.contains("pt-PT • 4 palavras • 2.5s"))

        // 3. CSV (com escape de aspas RFC 4180)
        let csv = repository.exportTranscriptions(records, format: .csv)
        XCTAssertTrue(csv.hasPrefix("id,created_at,language,duration_seconds,word_count,text"))
        XCTAssertTrue(csv.contains("\"\"aspas\"\""), "As aspas dentro do texto devem ser escapadas com aspas duplas no CSV.")
        XCTAssertTrue(csv.contains("\"pt-PT\",2.5,4"))
    }

    // MARK: - 9. Garantia Estrita de Zero Persistência de Áudio

    func testZeroAudioPersistenceGuarantee() throws {
        let record = try repository.recordTranscription(
            text: "Texto estritamente confidencial",
            duration: 3.0,
            language: "pt-PT"
        )

        // Inspeciona as propriedades do modelo para garantir que nenhuma transporta áudio
        let mirror = Mirror(reflecting: record)
        let propertyNames = mirror.children.compactMap { $0.label }

        let forbiddenKeywords = ["audio", "sound", "buffer", "pcm", "wav", "mp3", "voicefile", "filepath"]
        for prop in propertyNames {
            let lower = prop.lowercased()
            for forbidden in forbiddenKeywords {
                XCTAssertFalse(
                    lower.contains(forbidden),
                    "Propriedade '\(prop)' em TranscriptionRecord viola a política de Zero Retenção de Áudio."
                )
            }
        }
    }

    // MARK: - 10. Desempenho e Latência (< 50ms)

    func testPerformanceBenchmarkUnder50ms() throws {
        let startTime = CFAbsoluteTimeGetCurrent()

        // Ciclo completo de inserção, pesquisa, leitura e eliminação
        for i in 1...20 {
            try repository.recordTranscription(
                text: "Registo de benchmark número \(i) com métricas de desempenho",
                duration: 1.2,
                language: i % 2 == 0 ? "pt-PT" : "en-US"
            )
        }

        let fetched = try repository.fetchTranscriptions(searchQuery: "benchmark", limit: 10)
        XCTAssertEqual(fetched.count, 10)

        let stats = try repository.fetchTotalStats()
        XCTAssertEqual(stats.totalTranscriptions, 20)

        try repository.clearAllData()
        XCTAssertEqual(try repository.fetchTranscriptions().count, 0)

        let elapsedTime = CFAbsoluteTimeGetCurrent() - startTime

        // Requisito estrito do roadmap: tempo de execução inferior a 50ms (0.05s)
        XCTAssertLessThan(
            elapsedTime,
            0.05,
            "O tempo de execução total das operações locais deve ser estritamente inferior a 50ms. Tempo real: \(String(format: "%.4f", elapsedTime))s"
        )
    }
}
