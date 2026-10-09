import AppKit
import SwiftUI
import XCTest
@testable import Sonotype

@MainActor
final class DashboardViewsTests: XCTestCase {
    private var repository: PersistenceRepository!
    private var testPasteboard: NSPasteboard!
    private var viewModel: DashboardViewModel!

    override func setUp() async throws {
        try await super.setUp()
        repository = try PersistenceRepository(inMemory: true)
        testPasteboard = NSPasteboard(name: .init("DashboardViewsTestsPasteboard-\(UUID().uuidString)"))
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

    // MARK: - 1. Inicialização e Renderização Básica de DashboardWindowView

    func testDashboardWindowViewCreation() {
        let view = DashboardWindowView(viewModel: viewModel)
        XCTAssertNotNil(view.body)
        XCTAssertEqual(viewModel.selectedSection, .home)
    }

    func testHomeOverviewViewCreation() {
        let homeView = HomeOverviewView(viewModel: viewModel)
        XCTAssertNotNil(homeView.body)
    }

    // MARK: - 2. Inicialização e Subviews de HistoryListView

    func testHistoryListViewCreation() throws {
        try repository.recordTranscription(text: "Teste de transcrição em voz", duration: 3.2, language: "pt-PT")
        viewModel.loadAll()
        XCTAssertEqual(viewModel.historyRecords.count, 1)

        let historyView = HistoryListView(viewModel: viewModel)
        XCTAssertNotNil(historyView.body)

        // Selecionar primeiro registo
        viewModel.selectedRecord = viewModel.historyRecords.first
        XCTAssertNotNil(viewModel.selectedRecord)
        XCTAssertEqual(viewModel.selectedRecord?.text, "Teste de transcrição em voz")
    }

    // MARK: - 3. Inicialização e Subviews de VocabularyManagerView

    func testVocabularyManagerViewCreation() throws {
        try repository.addVocabulary(word: "SwiftUI", priority: 4)
        try repository.addReplacementRule(trigger: "meu site", replacement: "https://sonotype.app", isCaseSensitive: false)
        viewModel.loadAll()

        let vocabView = VocabularyManagerView(viewModel: viewModel)
        XCTAssertNotNil(vocabView.body)
        XCTAssertEqual(viewModel.vocabularyEntries.count, 1)
        XCTAssertEqual(viewModel.replacementRules.count, 1)
    }

    // MARK: - 4. Inicialização e Métricas de StatsOverviewView

    func testStatsOverviewViewCreation() throws {
        try repository.recordTranscription(text: "Uma duas três quatro cinco palavras", duration: 2.0, language: "pt-PT")
        try repository.recordTranscription(text: "One two three four five english words", duration: 2.0, language: "en-US")
        viewModel.loadAll()

        let statsView = StatsOverviewView(viewModel: viewModel)
        XCTAssertNotNil(statsView.body)
        XCTAssertEqual(viewModel.stats.totalTranscriptions, 2)
        XCTAssertEqual(viewModel.stats.portugueseWords, 6)
        XCTAssertEqual(viewModel.stats.englishWords, 7)
        XCTAssertGreaterThan(viewModel.stats.estimatedTimeSavedMinutes, 0)
    }

    // MARK: - 5. Comportamento do AppDelegate ao Reabrir Janela

    func testAppDelegateDashboardWindowActivation() {
        let appDelegate = AppDelegate()
        // Deve executar sem lançar exceções
        appDelegate.openDashboardWindow()

        let handled = appDelegate.applicationShouldHandleReopen(NSApplication.shared, hasVisibleWindows: false)
        XCTAssertTrue(handled, "applicationShouldHandleReopen deve retornar true e tentar abrir a janela se não houver janelas visíveis.")
    }
}
