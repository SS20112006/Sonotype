import AppKit
import XCTest
@testable import Sonotype

// MARK: - Mocks de Teste

final class MockAccessibilityInjector: AccessibilityTextInjecting, @unchecked Sendable {
    var isTrusted: Bool = true
    var shouldSucceed: Bool = true
    var injectedText: String?
    var injectCallCount: Int = 0

    func isProcessTrusted(prompt: Bool) -> Bool {
        isTrusted
    }

    func injectTextAtCursor(_ text: String) -> Bool {
        injectCallCount += 1
        injectedText = text
        return shouldSucceed
    }
}

final class MockKeystrokeSimulator: KeystrokeSimulating, @unchecked Sendable {
    var shouldSucceed: Bool = true
    var simulateCallCount: Int = 0

    func simulatePasteKeystroke() -> Bool {
        simulateCallCount += 1
        return shouldSucceed
    }
}

// MARK: - Testes do TextInjectionService

@MainActor
final class TextInjectionServiceTests: XCTestCase {
    private var mockAX: MockAccessibilityInjector!
    private var mockKeystroke: MockKeystrokeSimulator!
    private var testPasteboard: NSPasteboard!
    private var clipboardManager: ClipboardSafetyManager!
    private var service: TextInjectionService!

    override func setUp() {
        super.setUp()
        mockAX = MockAccessibilityInjector()
        mockKeystroke = MockKeystrokeSimulator()
        testPasteboard = NSPasteboard(name: .init("TextInjectionServiceTests-\(UUID().uuidString)"))
        clipboardManager = ClipboardSafetyManager(pasteboard: testPasteboard)
        service = TextInjectionService(
            accessibilityInjector: mockAX,
            keystrokeSimulator: mockKeystroke,
            clipboardManager: clipboardManager
        )
    }

    override func tearDown() {
        testPasteboard.releaseGlobally()
        testPasteboard = nil
        mockAX = nil
        mockKeystroke = nil
        clipboardManager = nil
        service = nil
        super.tearDown()
    }

    // MARK: - Injeção via Acessibilidade (AXUIElement)

    func testInjectAccessibilitySuccessPath() async {
        mockAX.shouldSucceed = true
        mockKeystroke.shouldSucceed = false // Se chamado, falharia

        let text = "Texto direto no cursor via AXUIElement"
        let result = await service.inject(
            text: text,
            strategy: .accessibilityWithFallback,
            clipboardMode: .pasteAndKeep
        )

        XCTAssertTrue(result.success)
        XCTAssertEqual(result.methodUsed, .accessibility)
        XCTAssertEqual(mockAX.injectCallCount, 1)
        XCTAssertEqual(mockAX.injectedText, text)
        XCTAssertEqual(mockKeystroke.simulateCallCount, 0)
        // No Modo A, também deve guardar cópia no clipboard para salvaguarda
        XCTAssertEqual(clipboardManager.currentString(), text)
    }

    func testInjectAccessibilityModeBPreservePreviousLeavesClipboardUntouched() async {
        let originalClipboard = "Clipboard intocado do utilizador"
        clipboardManager.setText(originalClipboard)

        mockAX.shouldSucceed = true

        let text = "Inserção sem alterar clipboard"
        let result = await service.inject(
            text: text,
            strategy: .accessibilityWithFallback,
            clipboardMode: .preservePrevious
        )

        XCTAssertTrue(result.success)
        XCTAssertEqual(result.methodUsed, .accessibility)
        XCTAssertEqual(clipboardManager.currentString(), originalClipboard)
    }

    // MARK: - Fallback Transparente para Simulação (CGEvent)

    func testInjectFallbackToKeystrokeWhenAccessibilityFails() async {
        mockAX.shouldSucceed = false
        mockKeystroke.shouldSucceed = true

        let text = "Texto injetado através de fallback Cmd+V"
        let result = await service.inject(
            text: text,
            strategy: .accessibilityWithFallback,
            clipboardMode: .pasteAndKeep
        )

        XCTAssertTrue(result.success)
        XCTAssertEqual(result.methodUsed, .keystrokeSimulation)
        XCTAssertEqual(mockAX.injectCallCount, 1)
        XCTAssertEqual(mockKeystroke.simulateCallCount, 1)
        XCTAssertEqual(clipboardManager.currentString(), text)
    }

    func testInjectKeystrokeModeBRestoresPreviousClipboard() async {
        let originalContent = "Texto confidencial anterior"
        clipboardManager.setText(originalContent)

        mockAX.shouldSucceed = false
        mockKeystroke.shouldSucceed = true

        let text = "Ditado temporário colado"
        let result = await service.inject(
            text: text,
            strategy: .accessibilityWithFallback,
            clipboardMode: .preservePrevious,
            keystrokeRestoreDelay: 0
        )

        XCTAssertTrue(result.success)
        XCTAssertEqual(result.methodUsed, .keystrokeSimulation)
        XCTAssertEqual(mockKeystroke.simulateCallCount, 1)
        // Após a injeção em Modo B, o clipboard original deve estar 100% restaurado
        XCTAssertEqual(clipboardManager.currentString(), originalContent)
    }

    // MARK: - Restrições de Estratégia

    func testInjectAccessibilityOnlyDoesNotFallback() async {
        mockAX.shouldSucceed = false
        mockKeystroke.shouldSucceed = true

        let text = "Não deve tentar simulação"
        let result = await service.inject(
            text: text,
            strategy: .accessibilityOnly
        )

        XCTAssertFalse(result.success)
        XCTAssertNil(result.methodUsed)
        XCTAssertEqual(mockAX.injectCallCount, 1)
        XCTAssertEqual(mockKeystroke.simulateCallCount, 0)
    }

    func testInjectKeystrokeOnlyBypassesAccessibility() async {
        mockAX.shouldSucceed = true // Mesmo que AX tivesse sucesso, não deve ser chamado
        mockKeystroke.shouldSucceed = true

        let text = "Direto para teclado"
        let result = await service.inject(
            text: text,
            strategy: .keystrokeOnly
        )

        XCTAssertTrue(result.success)
        XCTAssertEqual(result.methodUsed, .keystrokeSimulation)
        XCTAssertEqual(mockAX.injectCallCount, 0)
        XCTAssertEqual(mockKeystroke.simulateCallCount, 1)
    }

    // MARK: - Validações e Casos de Erro

    func testInjectEmptyTextFailsImmediately() async {
        let result = await service.inject(text: "")
        XCTAssertFalse(result.success)
        XCTAssertNil(result.methodUsed)
        XCTAssertEqual(mockAX.injectCallCount, 0)
        XCTAssertEqual(mockKeystroke.simulateCallCount, 0)
    }

    func testKeystrokeSimulationFailureReturnsError() async {
        mockAX.shouldSucceed = false
        mockKeystroke.shouldSucceed = false

        let result = await service.inject(
            text: "Falha intencional de CGEvent",
            strategy: .keystrokeOnly
        )

        XCTAssertFalse(result.success)
        XCTAssertNil(result.methodUsed)
        XCTAssertNotNil(result.errorDescription)
    }

    // MARK: - Instanciação dos Injetores de Sistema

    func testSystemInjectorsInitialization() {
        let sysAX = SystemAccessibilityInjector()
        // Executar sem erro
        _ = sysAX.isProcessTrusted(prompt: false)

        let sysKeystroke = SystemKeystrokeSimulator()
        XCTAssertNotNil(sysKeystroke)
    }
}
