import XCTest
@testable import Sonotype

final class TextPostProcessorTests: XCTestCase {
    private var processor: TextPostProcessor!

    override func setUp() {
        super.setUp()
        processor = TextPostProcessor()
    }

    // MARK: - Testes de Regressão em Português

    func testPortugueseFullPipelineWithFillersAndCommands() {
        let rawTranscription = "hum olá vírgula como estás ponto de interrogação ãh tudo ótimo ponto final"
        let processed = processor.process(text: rawTranscription, language: .portuguesePT)
        XCTAssertEqual(processed, "Olá, como estás? Tudo ótimo.")
    }

    func testPortugueseMultiLineDictation() {
        let rawTranscription = "caro colega vírgula nova linha hum segue o resumo semanal ponto final novo parágrafo com os melhores cumprimentos vírgula nova linha simão sousa"
        let processed = processor.process(text: rawTranscription, language: .portuguesePT)
        let expected = """
        Caro colega,
        Segue o resumo semanal.

        Com os melhores cumprimentos,
        Simão sousa
        """
        XCTAssertEqual(processed, expected)
    }

    func testPortugueseCleanPhraseWithoutFillers() {
        let rawTranscription = "bom dia a todos vírgula a reunião começa dentro de dez minutos ponto final"
        let processed = processor.process(text: rawTranscription, language: .portuguesePT)
        XCTAssertEqual(processed, "Bom dia a todos, a reunião começa dentro de dez minutos.")
    }

    func testPortugueseAutoFinalPeriod() {
        let rawTranscription = "este é um teste rápido sem comando de encerramento"
        var options = PostProcessingOptions.default
        options.autoFinalPeriodEnabled = true

        let processed = processor.process(text: rawTranscription, language: .portuguesePT, options: options)
        XCTAssertEqual(processed, "Este é um teste rápido sem comando de encerramento.")
    }

    // MARK: - Testes de Regressão em Inglês

    func testEnglishFullPipelineWithFillersAndCommands() {
        let rawTranscription = "well um hello comma how is the deployment going question mark uh all tests passed period"
        let processed = processor.process(text: rawTranscription, language: .englishUS)
        XCTAssertEqual(processed, "Well hello, how is the deployment going? All tests passed.")
    }

    func testEnglishMultiLineDictation() {
        let rawTranscription = "hi team comma new line um please review the attached pr period new paragraph thanks comma new line alex"
        let processed = processor.process(text: rawTranscription, language: .englishUS)
        let expected = """
        Hi team,
        Please review the attached pr.

        Thanks,
        Alex
        """
        XCTAssertEqual(processed, expected)
    }

    func testEnglishCleanPhraseWithoutFillers() {
        let rawTranscription = "offline speech recognition with Apple Speech framework works as expected period"
        let processed = processor.process(text: rawTranscription, language: .englishUS)
        XCTAssertEqual(processed, "Offline speech recognition with Apple Speech framework works as expected.")
    }

    // MARK: - Testes de Opções e Toggles

    func testDisabledFillerFilterKeepsHesitations() {
        let rawTranscription = "olá hum este é um teste ponto final"
        var options = PostProcessingOptions.default
        options.fillerFilterEnabled = false

        let processed = processor.process(text: rawTranscription, language: .portuguesePT, options: options)
        XCTAssertEqual(processed, "Olá hum este é um teste.")
    }

    func testDisabledOralCommandsKeepsSpokenWords() {
        let rawTranscription = "olá vírgula este é um teste ponto final"
        var options = PostProcessingOptions.default
        options.oralCommandsEnabled = false

        let processed = processor.process(text: rawTranscription, language: .portuguesePT, options: options)
        XCTAssertEqual(processed, "Olá vírgula este é um teste ponto final")
    }

    func testDisabledCapitalizationLeavesCasingUnchanged() {
        let rawTranscription = "olá vírgula tudo bem ponto final nova linha segunda linha ponto final"
        var options = PostProcessingOptions.default
        options.capitalizationEnabled = false

        let processed = processor.process(text: rawTranscription, language: .portuguesePT, options: options)
        XCTAssertEqual(processed, "olá, tudo bem.\nsegunda linha.")
    }

    // MARK: - Casos de Fronteira

    func testEmptyAndWhitespaceInput() {
        XCTAssertEqual(processor.process(text: "", language: .portuguesePT), "")
        XCTAssertEqual(processor.process(text: "   \n\t  ", language: .englishUS), "")
    }
}
