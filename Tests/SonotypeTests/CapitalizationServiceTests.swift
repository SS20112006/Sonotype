import XCTest
@testable import Sonotype

final class CapitalizationServiceTests: XCTestCase {
    private var service: CapitalizationService!

    override func setUp() {
        super.setUp()
        service = CapitalizationService()
    }

    func testCapitalizeFirstWordOfSentence() {
        let input = "olá a todos, bem-vindos ao Sonotype."
        let output = service.capitalize(text: input)
        XCTAssertEqual(output, "Olá a todos, bem-vindos ao Sonotype.")
    }

    func testCapitalizeAfterTerminalPunctuation() {
        let input = "primeira frase. segunda frase? terceira frase! quarta frase."
        let output = service.capitalize(text: input)
        XCTAssertEqual(output, "Primeira frase. Segunda frase? Terceira frase! Quarta frase.")
    }

    func testCapitalizeAfterNewLines() {
        let input = "título principal\nprimeiro parágrafo\n\nsegundo parágrafo"
        let output = service.capitalize(text: input)
        XCTAssertEqual(output, "Título principal\nPrimeiro parágrafo\n\nSegundo parágrafo")
    }

    func testCapitalizeWithQuotesAndParentheses() {
        let input = "\"este é um teste entre aspas\" e (este entre parênteses)."
        let output = service.capitalize(text: input)
        XCTAssertEqual(output, "\"Este é um teste entre aspas\" e (Este entre parênteses).")
    }

    func testCapitalizeAfterEllipsis() {
        let input = "estava a pensar... talvez amanhã seja melhor."
        let output = service.capitalize(text: input)
        XCTAssertEqual(output, "Estava a pensar... Talvez amanhã seja melhor.")
    }

    func testPreservesExistingAcronymsAndInternalCapitals() {
        let input = "a API do macOS e do iOS foi atualizada pela equipa da NASA."
        let output = service.capitalize(text: input)
        XCTAssertEqual(output, "A API do macOS e do iOS foi atualizada pela equipa da NASA.")
    }

    func testAccentedLettersCapitalization() {
        let input = "é fundamental testar a área de trabalho."
        let output = service.capitalize(text: input)
        XCTAssertEqual(output, "É fundamental testar a área de trabalho.")
    }

    func testEmptyStringReturnsEmpty() {
        XCTAssertEqual(service.capitalize(text: ""), "")
    }
}
