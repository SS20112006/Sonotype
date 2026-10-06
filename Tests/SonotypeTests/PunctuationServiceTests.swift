import XCTest
@testable import Sonotype

final class PunctuationServiceTests: XCTestCase {
    private var service: PunctuationService!

    override func setUp() {
        super.setUp()
        service = PunctuationService()
    }

    func testPortugueseOralCommandsPunctuation() {
        let input = "olá vírgula como estás ponto de interrogação tudo bem ponto final"
        let output = service.process(text: input, language: .portuguesePT)
        XCTAssertEqual(output, "olá, como estás? tudo bem.")
    }

    func testPortuguesePontoAtEndConverted() {
        let input = "olá vírgula amanhã vamos ao cinema ponto"
        let output = service.process(text: input, language: .portuguesePT)
        XCTAssertEqual(output, "olá, amanhã vamos ao cinema.")
    }

    func testPortuguesePontoDeVistaPreserved() {
        let input = "o meu ponto de vista é diferente"
        let output = service.process(text: input, language: .portuguesePT)
        XCTAssertEqual(output, "o meu ponto de vista é diferente")
    }

    func testPortugueseNewLineAndParagraphCommands() {
        let input = "primeira frase nova linha segunda frase novo parágrafo terceira frase"
        let output = service.process(text: input, language: .portuguesePT)
        XCTAssertEqual(output, "primeira frase\nsegunda frase\n\nterceira frase")
    }

    func testPortugueseQuotesAndParentheses() {
        let input = "ele disse abrir aspas bom dia fechar aspas com entusiasmo"
        let output = service.process(text: input, language: .portuguesePT)
        XCTAssertEqual(output, "ele disse \"bom dia\" com entusiasmo")
    }

    func testPortugueseSemicolonAndColon() {
        let input = "temos dois itens dois pontos o primeiro ponto e vírgula e o segundo"
        let output = service.process(text: input, language: .portuguesePT)
        XCTAssertEqual(output, "temos dois itens: o primeiro; e o segundo")
    }

    func testEnglishOralCommandsPunctuation() {
        let input = "hello comma how are you question mark everything is fine period"
        let output = service.process(text: input, language: .englishUS)
        XCTAssertEqual(output, "hello, how are you? everything is fine.")
    }

    func testEnglishPeriodOfTimePreserved() {
        let input = "it will last for a short period of time"
        let output = service.process(text: input, language: .englishUS)
        XCTAssertEqual(output, "it will last for a short period of time")
    }

    func testEnglishNewLineAndParagraphCommands() {
        let input = "first line new line second line new paragraph third line"
        let output = service.process(text: input, language: .englishUS)
        XCTAssertEqual(output, "first line\nsecond line\n\nthird line")
    }

    func testEnglishQuotesAndParentheses() {
        let input = "she said open quote welcome close quote with a smile"
        let output = service.process(text: input, language: .englishUS)
        XCTAssertEqual(output, "she said \"welcome\" with a smile")
    }

    func testPunctuationSpacingNormalization() {
        let input = "olá  ,tudo bem  ?sim  .  obrigado"
        let output = service.normalizePunctuationSpacing(input)
        XCTAssertEqual(output, "olá, tudo bem? sim. obrigado")
    }

    func testOralCommandsDisabledLeavesTextAsIs() {
        let input = "olá vírgula como estás ponto final"
        let output = service.process(text: input, language: .portuguesePT, oralCommandsEnabled: false)
        XCTAssertEqual(output, "olá vírgula como estás ponto final")
    }

    func testAutoFinalPeriodAddsPeriodWhenMissing() {
        let input = "este é um texto sem ponto"
        let output = service.process(text: input, language: .portuguesePT, oralCommandsEnabled: false, autoFinalPeriod: true)
        XCTAssertEqual(output, "este é um texto sem ponto.")
    }

    func testAutoFinalPeriodDoesNotDuplicateExistingTerminal() {
        let input = "este texto já tem ponto."
        let output = service.process(text: input, language: .portuguesePT, oralCommandsEnabled: false, autoFinalPeriod: true)
        XCTAssertEqual(output, "este texto já tem ponto.")
    }
}
