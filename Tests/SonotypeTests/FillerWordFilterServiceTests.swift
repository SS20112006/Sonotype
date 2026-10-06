import XCTest
@testable import Sonotype

final class FillerWordFilterServiceTests: XCTestCase {
    private var service: FillerWordFilterService!

    override func setUp() {
        super.setUp()
        service = FillerWordFilterService()
    }

    func testRemovePortugueseBasicFillers() {
        let input = "Olá hum eu estava a pensar ãh se podemos reunir hoje"
        let output = service.filter(text: input, language: .portuguesePT)
        XCTAssertEqual(output, "Olá eu estava a pensar se podemos reunir hoje")
    }

    func testRemovePortugueseFillersWithPunctuation() {
        let input = "Bom dia, hum, como correu a reunião, ãh, de ontem?"
        let output = service.filter(text: input, language: .portuguesePT)
        XCTAssertEqual(output, "Bom dia, como correu a reunião, de ontem?")
    }

    func testRemovePortugueseTipoAssimAndHesitations() {
        let input = "O projeto está tipo assim quase terminado éé amanhã entregamos"
        let output = service.filter(text: input, language: .portuguesePT)
        XCTAssertEqual(output, "O projeto está quase terminado amanhã entregamos")
    }

    func testPreserveLegitimateWordsContainingFillerLettersPT() {
        let input = "A humildade é um tipo de virtude humana"
        let output = service.filter(text: input, language: .portuguesePT)
        XCTAssertEqual(output, "A humildade é um tipo de virtude humana")
    }

    func testRemoveEnglishBasicFillers() {
        let input = "Well um I think uh we should deploy the release today"
        let output = service.filter(text: input, language: .englishUS)
        XCTAssertEqual(output, "Well I think we should deploy the release today")
    }

    func testRemoveEnglishFillersWithPunctuation() {
        let input = "We need, um, three more days, uh, to finalize tests."
        let output = service.filter(text: input, language: .englishUS)
        XCTAssertEqual(output, "We need, three more days, to finalize tests.")
    }

    func testPreserveLegitimateWordsContainingFillerLettersEN() {
        let input = "I really like this summary and the umbrella project"
        let output = service.filter(text: input, language: .englishUS)
        XCTAssertEqual(output, "I really like this summary and the umbrella project")
    }

    func testEmptyStringReturnsEmpty() {
        XCTAssertEqual(service.filter(text: "", language: .portuguesePT), "")
        XCTAssertEqual(service.filter(text: "   ", language: .englishUS), "")
    }
}
