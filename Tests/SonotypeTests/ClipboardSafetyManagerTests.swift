import AppKit
import XCTest
@testable import Sonotype

@MainActor
final class ClipboardSafetyManagerTests: XCTestCase {
    private var pasteboard: NSPasteboard!
    private var manager: ClipboardSafetyManager!

    override func setUp() async throws {
        try await super.setUp()
        // Cria um pasteboard com nome único por teste para garantir isolamento absoluto
        pasteboard = NSPasteboard(name: .init("SonotypeTestPasteboard-\(UUID().uuidString)"))
        manager = ClipboardSafetyManager(pasteboard: pasteboard)
    }

    override func tearDown() async throws {
        pasteboard.releaseGlobally()
        pasteboard = nil
        manager = nil
        try await super.tearDown()
    }

    // MARK: - Modo A (pasteAndKeep)

    func testModeAPasteAndKeepSetsAndKeepsTextInPasteboard() async {
        manager.setText("Conteúdo Antigo")
        XCTAssertEqual(manager.currentString(), "Conteúdo Antigo")

        let newTranscription = "Texto transcrito pelo Sonotype"
        await manager.withPreservedClipboard(
            text: newTranscription,
            mode: .pasteAndKeep,
            restoreDelayNanoseconds: 0
        ) {
            // Durante a ação de colagem, o pasteboard contém o novo texto
            XCTAssertEqual(self.manager.currentString(), newTranscription)
        }

        // No Modo A, o texto transcrito DEVE permanecer no pasteboard como salvaguarda
        XCTAssertEqual(manager.currentString(), newTranscription)
    }

    // MARK: - Modo B (preservePrevious)

    func testModeBPreservePreviousRestoresOriginalText() async {
        let originalText = "Texto importantíssimo antes do ditado"
        manager.setText(originalText)
        XCTAssertEqual(manager.currentString(), originalText)

        let transcribedText = "Texto temporário a ser colado"
        var wasInvoked = false

        await manager.withPreservedClipboard(
            text: transcribedText,
            mode: .preservePrevious,
            restoreDelayNanoseconds: 0
        ) {
            wasInvoked = true
            // Durante a ação, o pasteboard deve conter o texto temporário
            XCTAssertEqual(self.manager.currentString(), transcribedText)
        }

        XCTAssertTrue(wasInvoked)
        // No Modo B, após a operação o clipboard deve restaurar o conteúdo anterior
        XCTAssertEqual(manager.currentString(), originalText)
    }

    func testModeBPreserveEmptyPasteboard() async {
        pasteboard.clearContents()
        XCTAssertNil(manager.currentString())

        let transcribedText = "Primeiro ditado num clipboard vazio"

        await manager.withPreservedClipboard(
            text: transcribedText,
            mode: .preservePrevious,
            restoreDelayNanoseconds: 0
        ) {
            XCTAssertEqual(self.manager.currentString(), transcribedText)
        }

        // Deve retornar ao estado vazio original
        XCTAssertNil(manager.currentString())
    }

    func testModeBPreserveMultipleDataTypes() {
        // Popula com texto e dados binários customizados
        pasteboard.clearContents()
        let customType = NSPasteboard.PasteboardType("com.sonotype.custom-data")
        let customData = "dados-binarios-de-teste".data(using: .utf8)!

        let item = NSPasteboardItem()
        item.setString("Texto com metadados", forType: .string)
        item.setData(customData, forType: customType)
        pasteboard.writeObjects([item])

        // Captura snapshot
        let snapshot = manager.captureSnapshot()
        XCTAssertFalse(snapshot.items.isEmpty)
        XCTAssertEqual(snapshot.items.first?.dataByType[customType.rawValue], customData)

        // Altera o pasteboard
        manager.setText("Sobrescrevendo temporariamente")
        XCTAssertEqual(manager.currentString(), "Sobrescrevendo temporariamente")
        XCTAssertNil(pasteboard.data(forType: customType))

        // Restaura snapshot
        manager.restore(snapshot: snapshot)

        // Valida integridade completa
        XCTAssertEqual(manager.currentString(), "Texto com metadados")
        XCTAssertEqual(pasteboard.data(forType: customType), customData)
    }

    // MARK: - Snapshot & Restore Isolados

    func testSnapshotOnEmptyPasteboardReturnsEmptySnapshot() {
        pasteboard.clearContents()
        let snapshot = manager.captureSnapshot()
        XCTAssertTrue(snapshot.items.isEmpty)

        // Restaurar snapshot vazio limpa o pasteboard
        manager.setText("Qualquer coisa")
        manager.restore(snapshot: snapshot)
        XCTAssertNil(manager.currentString())
    }

    func testCurrentStringHandlesEmptyAndNonEmpty() {
        pasteboard.clearContents()
        XCTAssertNil(manager.currentString())

        manager.setText("Sonotype Ditado")
        XCTAssertEqual(manager.currentString(), "Sonotype Ditado")
    }
}
