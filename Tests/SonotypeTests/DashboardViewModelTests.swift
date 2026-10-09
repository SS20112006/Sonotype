import AppKit
import Foundation
import SwiftData
import XCTest
@testable import Sonotype

@MainActor
final class DashboardViewModelTests: XCTestCase {
    private var repository: PersistenceRepository!
    private var testPasteboard: NSPasteboard!
    private var viewModel: DashboardViewModel!

    override func setUp() async throws {
        try await super.setUp()
        // Repositório SwiftData em RAM para testes completamente isolados
        repository = try PersistenceRepository(inMemory: true)
        testPasteboard = NSPasteboard(name: .init("DashboardTestPasteboard-\(UUID().uuidString)"))
        viewModel = DashboardViewModel(
            repository: repository,
            pasteboard: testPasteboard,
            autoLoad: false
        )
    }

    override func tearDown() async throws {
        testPasteboard.releaseGlobally()
        testPasteboard = nil
        viewModel = nil
        repository = nil
        try await super.tearDown()
    }

    // MARK: - 1. Estado Inicial e Carregamento Completo (loadAll)

    func testInitialStateAndLoadAll() throws {
        // Estado inicial antes de loadAll
        XCTAssertEqual(viewModel.selectedSection, .home)
        XCTAssertEqual(viewModel.searchQuery, "")
        XCTAssertTrue(viewModel.historyRecords.isEmpty)
        XCTAssertTrue(viewModel.vocabularyEntries.isEmpty)
        XCTAssertTrue(viewModel.replacementRules.isEmpty)
        XCTAssertNil(viewModel.selectedRecord)
        XCTAssertNil(viewModel.errorMessage)

        // Povoar repositório
        try repository.recordTranscription(text: "Primeira transcrição de teste", duration: 2.0, language: "pt-PT")
        try repository.recordTranscription(text: "Second voice note in english", duration: 3.5, language: "en-US")
        try repository.addVocabulary(word: "Sonotype", priority: 5)
        try repository.addReplacementRule(trigger: "email pessoal", replacement: "user@example.com", isCaseSensitive: false)

        viewModel.loadAll()

        XCTAssertEqual(viewModel.historyRecords.count, 2)
        XCTAssertEqual(viewModel.vocabularyEntries.count, 1)
        XCTAssertEqual(viewModel.replacementRules.count, 1)
        XCTAssertEqual(viewModel.vocabularyEntries.first?.word, "Sonotype")
        XCTAssertEqual(viewModel.replacementRules.first?.trigger, "email pessoal")
        XCTAssertEqual(viewModel.stats.totalTranscriptions, 2)
        XCTAssertGreaterThan(viewModel.stats.totalWords, 0)
    }

    // MARK: - 2. Seletor de Secções do Dashboard

    func testDashboardSectionSelection() {
        XCTAssertEqual(DashboardSection.home.rawValue, "Início")
        XCTAssertEqual(DashboardSection.history.rawValue, "Histórico")
        XCTAssertEqual(DashboardSection.vocabulary.rawValue, "Dicionário")
        XCTAssertEqual(DashboardSection.stats.rawValue, "Estatísticas")
        XCTAssertEqual(DashboardSection.settings.rawValue, "Definições")

        XCTAssertEqual(DashboardSection.home.id, "Início")
        XCTAssertEqual(DashboardSection.history.id, "Histórico")
        XCTAssertEqual(DashboardSection.vocabulary.id, "Dicionário")
        XCTAssertEqual(DashboardSection.stats.id, "Estatísticas")
        XCTAssertEqual(DashboardSection.settings.id, "Definições")

        XCTAssertEqual(DashboardSection.allCases.count, 5)

        viewModel.selectedSection = .vocabulary
        XCTAssertEqual(viewModel.selectedSection, .vocabulary)

        viewModel.selectedSection = .stats
        XCTAssertEqual(viewModel.selectedSection, .stats)

        viewModel.selectedSection = .settings
        XCTAssertEqual(viewModel.selectedSection, .settings)
    }

    // MARK: - 3. Filtragem de Pesquisa por Substring

    func testSearchQueryFiltering() throws {
        try repository.recordTranscription(text: "Reunião de equipa com sprint planning", duration: 5.0, language: "pt-PT")
        try repository.recordTranscription(text: "Almoço de trabalho no restaurante", duration: 3.0, language: "pt-PT")
        try repository.recordTranscription(text: "Reunião de alinhamento com cliente", duration: 4.0, language: "pt-PT")

        viewModel.loadAll()
        XCTAssertEqual(viewModel.historyRecords.count, 3)

        // Pesquisa com correspondência parcial case-insensitive
        viewModel.searchQuery = "reunião"
        XCTAssertEqual(viewModel.historyRecords.count, 2)
        XCTAssertTrue(viewModel.historyRecords.allSatisfy { $0.text.localizedCaseInsensitiveContains("reunião") })

        // Pesquisa em maiúsculas
        viewModel.searchQuery = "RESTAURANTE"
        XCTAssertEqual(viewModel.historyRecords.count, 1)
        XCTAssertEqual(viewModel.historyRecords.first?.text, "Almoço de trabalho no restaurante")

        // Pesquisa sem resultados
        viewModel.searchQuery = "inexistentexyz"
        XCTAssertEqual(viewModel.historyRecords.count, 0)

        // Limpeza da pesquisa restaura a lista completa
        viewModel.searchQuery = ""
        XCTAssertEqual(viewModel.historyRecords.count, 3)

        // Pesquisa só com espaços em branco deve retornar todos
        viewModel.searchQuery = "   "
        XCTAssertEqual(viewModel.historyRecords.count, 3)
    }

    func testSearchQueryDeselectsFilteredOutRecord() throws {
        let rec1 = try repository.recordTranscription(text: "Relatório de finanças", duration: 2.0, language: "pt-PT")
        _ = try repository.recordTranscription(text: "Código Swift no Xcode", duration: 3.0, language: "pt-PT")

        viewModel.loadAll()
        viewModel.selectedRecord = rec1
        XCTAssertEqual(viewModel.selectedRecord?.id, rec1.id)

        // Filtrar excluindo o item selecionado
        viewModel.searchQuery = "Xcode"
        XCTAssertNil(viewModel.selectedRecord, "O registo selecionado deve ser desmarcado se não estiver nos resultados da pesquisa.")
    }

    // MARK: - 4. Eliminação Individual de Transcrição

    func testDeleteSingleTranscription() throws {
        let rec1 = try repository.recordTranscription(text: "Primeiro registo", duration: 1.0, language: "pt-PT")
        let rec2 = try repository.recordTranscription(text: "Segundo registo", duration: 2.0, language: "pt-PT")

        viewModel.loadAll()
        XCTAssertEqual(viewModel.historyRecords.count, 2)

        viewModel.selectedRecord = rec1
        viewModel.deleteTranscription(rec1)

        XCTAssertEqual(viewModel.historyRecords.count, 1)
        XCTAssertEqual(viewModel.historyRecords.first?.id, rec2.id)
        XCTAssertNil(viewModel.selectedRecord, "Registo eliminado que estava selecionado deve ser desmarcado.")

        let remainingInRepo = try repository.fetchTranscriptions()
        XCTAssertEqual(remainingInRepo.count, 1)
        XCTAssertEqual(remainingInRepo.first?.id, rec2.id)
    }

    // MARK: - 5. Eliminação em Massa de Transcrições (clearAllHistory)

    func testClearAllHistory() throws {
        let rec1 = try repository.recordTranscription(text: "Registo A", duration: 1.0, language: "pt-PT")
        _ = try repository.recordTranscription(text: "Registo B", duration: 2.0, language: "pt-PT")
        _ = try repository.recordTranscription(text: "Registo C", duration: 3.0, language: "pt-PT")

        viewModel.loadAll()
        viewModel.selectedRecord = rec1
        XCTAssertEqual(viewModel.historyRecords.count, 3)

        viewModel.clearAllHistory()

        XCTAssertTrue(viewModel.historyRecords.isEmpty)
        XCTAssertNil(viewModel.selectedRecord)

        let remainingInRepo = try repository.fetchTranscriptions()
        XCTAssertTrue(remainingInRepo.isEmpty)
    }

    // MARK: - 6. Gestão de Vocabulário Personalizado

    func testVocabularyAddAndDelete() throws {
        viewModel.loadAll()
        XCTAssertTrue(viewModel.vocabularyEntries.isEmpty)

        viewModel.addVocabulary(word: "Sonotype", priority: 10)
        viewModel.addVocabulary(word: "Whisper", priority: 5)

        XCTAssertEqual(viewModel.vocabularyEntries.count, 2)
        XCTAssertEqual(viewModel.vocabularyEntries[0].word, "Sonotype")
        XCTAssertEqual(viewModel.vocabularyEntries[0].priority, 10)
        XCTAssertEqual(viewModel.vocabularyEntries[1].word, "Whisper")

        // Tentar adicionar palavra em branco deve ser ignorado
        viewModel.addVocabulary(word: "   ", priority: 1)
        XCTAssertEqual(viewModel.vocabularyEntries.count, 2)

        // Eliminação
        let entryToDelete = viewModel.vocabularyEntries[0]
        viewModel.deleteVocabulary(entryToDelete)

        XCTAssertEqual(viewModel.vocabularyEntries.count, 1)
        XCTAssertEqual(viewModel.vocabularyEntries[0].word, "Whisper")

        let repoEntries = try repository.fetchVocabulary()
        XCTAssertEqual(repoEntries.count, 1)
        XCTAssertEqual(repoEntries[0].word, "Whisper")
    }

    // MARK: - 7. Gestão de Regras de Substituição

    func testReplacementRulesAddAndDelete() throws {
        viewModel.loadAll()
        XCTAssertTrue(viewModel.replacementRules.isEmpty)

        viewModel.addReplacementRule(
            trigger: "meu site",
            replacement: "https://sonotype.app",
            isCaseSensitive: false
        )

        XCTAssertEqual(viewModel.replacementRules.count, 1)
        XCTAssertEqual(viewModel.replacementRules[0].trigger, "meu site")
        XCTAssertEqual(viewModel.replacementRules[0].replacement, "https://sonotype.app")
        XCTAssertFalse(viewModel.replacementRules[0].isCaseSensitive)

        // Adicionar gatilho vazio deve ser ignorado
        viewModel.addReplacementRule(trigger: "", replacement: "nada", isCaseSensitive: false)
        XCTAssertEqual(viewModel.replacementRules.count, 1)

        // Eliminação
        let ruleToDelete = viewModel.replacementRules[0]
        viewModel.deleteReplacementRule(ruleToDelete)

        XCTAssertTrue(viewModel.replacementRules.isEmpty)
        let repoRules = try repository.fetchReplacementRules()
        XCTAssertTrue(repoRules.isEmpty)
    }

    // MARK: - 8. Motor de Exportação (.txt, .md, .csv)

    func testExportDataFormats() throws {
        let fixedDate = Date(timeIntervalSince1970: 1775484000)
        try repository.recordTranscription(
            text: "Texto simples de teste",
            duration: 2.5,
            language: "pt-PT",
            date: fixedDate
        )
        try repository.recordTranscription(
            text: "Voice note with \"quotes\"",
            duration: 1.8,
            language: "en-US",
            date: fixedDate.addingTimeInterval(60)
        )

        viewModel.loadAll()

        // 1. Plain Text (.txt)
        let txtExport = viewModel.exportData(format: .plainText)
        XCTAssertTrue(txtExport.contains("Texto simples de teste"))
        XCTAssertTrue(txtExport.contains("Voice note with \"quotes\""))
        XCTAssertTrue(txtExport.contains("(pt-PT):"))
        XCTAssertTrue(txtExport.contains("(en-US):"))

        // 2. Markdown (.md)
        let mdExport = viewModel.exportData(format: .markdown)
        XCTAssertTrue(mdExport.contains("# Histórico de Transcrições — Sonotype"))
        XCTAssertTrue(mdExport.contains("Texto simples de teste"))
        XCTAssertTrue(mdExport.contains("pt-PT • 4 palavras • 2.5s"))

        // 3. CSV (.csv)
        let csvExport = viewModel.exportData(format: .csv)
        XCTAssertTrue(csvExport.hasPrefix("id,created_at,language,duration_seconds,word_count,text"))
        XCTAssertTrue(csvExport.contains("\"\"quotes\"\""))
    }

    // MARK: - 9. Gravação de Exportação em Ficheiro Local (saveExport)

    func testSaveExportToFile() throws {
        try repository.recordTranscription(text: "Registo para gravação em ficheiro", duration: 1.5, language: "pt-PT")
        viewModel.loadAll()

        let tempDirectory = FileManager.default.temporaryDirectory
        let fileURL = tempDirectory.appendingPathComponent("export_test_\(UUID().uuidString).md")

        defer {
            try? FileManager.default.removeItem(at: fileURL)
        }

        try viewModel.saveExport(format: .markdown, to: fileURL)

        XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path))
        let writtenContent = try String(contentsOf: fileURL, encoding: .utf8)
        XCTAssertEqual(writtenContent, viewModel.exportData(format: .markdown))
    }

    // MARK: - 10. Suporte a NSSavePanel com Handler Customizado

    func testExportWithSavePanel() throws {
        try repository.recordTranscription(text: "Gravação via SavePanel", duration: 2.0, language: "pt-PT")
        viewModel.loadAll()

        let tempDir = FileManager.default.temporaryDirectory
        let destinationURL = tempDir.appendingPathComponent("savepanel_test_\(UUID().uuidString).csv")

        defer {
            try? FileManager.default.removeItem(at: destinationURL)
        }

        // Simula aprovação no modal do NSSavePanel via savePanelHandler
        viewModel.savePanelHandler = { panel in
            return destinationURL
        }

        let success = viewModel.exportWithSavePanel(format: .csv)
        XCTAssertTrue(success)
        XCTAssertTrue(FileManager.default.fileExists(atPath: destinationURL.path))

        let csvContent = try String(contentsOf: destinationURL, encoding: .utf8)
        XCTAssertTrue(csvContent.contains("Gravação via SavePanel"))

        // Simula cancelamento do modal
        viewModel.savePanelHandler = { _ in
            return nil
        }

        let cancelled = viewModel.exportWithSavePanel(format: .csv)
        XCTAssertFalse(cancelled)
    }

    // MARK: - 11. Cópia para Clipboard (NSPasteboard)

    func testCopyToClipboard() {
        let textToCopy = "Texto copiado para a área de transferência do Sonotype"
        let success = viewModel.copyToClipboard(textToCopy)

        XCTAssertTrue(success)
        let copiedText = testPasteboard.string(forType: .string)
        XCTAssertEqual(copiedText, textToCopy)
    }

    // MARK: - 12. Gestão de Erros

    func testErrorMessageHandling() {
        viewModel.clearError()
        XCTAssertNil(viewModel.errorMessage)

        // Tentativa de gravar num URL inválido deve lançar erro e propagar para errorMessage
        let invalidURL = URL(fileURLWithPath: "/caminho/completamente/invalido/e/inacessivel/sonotype.txt")
        XCTAssertThrowsError(try viewModel.saveExport(format: .plainText, to: invalidURL))
        XCTAssertNotNil(viewModel.errorMessage)

        viewModel.clearError()
        XCTAssertNil(viewModel.errorMessage)
    }
}
