import XCTest
@testable import Sonotype

final class LanguageDetectorServiceTests: XCTestCase {
    private var service: LanguageDetectorService!

    override func setUp() {
        super.setUp()
        service = LanguageDetectorService(defaultLanguage: .portuguesePT)
    }

    func testDetectPortugueseSentences() {
        let sentencePT1 = "Olá a todos, este é um teste de transcrição em língua portuguesa para o Sonotype."
        let sentencePT2 = "Preciso de enviar um relatório detalhado sobre o projeto ainda hoje."

        let result1 = service.detectLanguage(from: sentencePT1)
        let result2 = service.detectLanguage(from: sentencePT2)

        XCTAssertTrue(result1.isPortuguese, "Deveria detetar Português para a frase 1 (resultado: \(result1.rawValue))")
        XCTAssertTrue(result2.isPortuguese, "Deveria detetar Português para a frase 2 (resultado: \(result2.rawValue))")
    }

    func testDetectEnglishSentences() {
        let sentenceEN1 = "Hello everyone, this is an offline voice dictation test in English."
        let sentenceEN2 = "Please make sure to submit the pull request before the team standup meeting."

        let result1 = service.detectLanguage(from: sentenceEN1)
        let result2 = service.detectLanguage(from: sentenceEN2)

        XCTAssertTrue(result1.isEnglish, "Deveria detetar Inglês para a frase 1 (resultado: \(result1.rawValue))")
        XCTAssertTrue(result2.isEnglish, "Deveria detetar Inglês para a frase 2 (resultado: \(result2.rawValue))")
    }

    func testEmptyAndWhitespaceFallbackToDefaultLanguage() {
        XCTAssertEqual(service.detectLanguage(from: ""), .portuguesePT)
        XCTAssertEqual(service.detectLanguage(from: "   \n\t  "), .portuguesePT)

        let englishDefaultService = LanguageDetectorService(defaultLanguage: .englishUS)
        XCTAssertEqual(englishDefaultService.detectLanguage(from: ""), .englishUS)
    }

    func testConfidenceScores() {
        let ptScores = service.confidenceScores(for: "Isto é um teste exclusivo em língua portuguesa.")
        XCTAssertGreaterThan(ptScores.portuguese, ptScores.english, "Pontuação de português deve ser superior para texto em português.")

        let enScores = service.confidenceScores(for: "This is a purely English sentence tested with the model.")
        XCTAssertGreaterThan(enScores.english, enScores.portuguese, "Pontuação de inglês deve ser superior para texto em inglês.")
    }

    func testSpeechLanguageLocalesAndFlags() {
        XCTAssertTrue(SpeechLanguage.portuguesePT.isPortuguese)
        XCTAssertTrue(SpeechLanguage.portugueseBR.isPortuguese)
        XCTAssertFalse(SpeechLanguage.portuguesePT.isEnglish)

        XCTAssertTrue(SpeechLanguage.englishUS.isEnglish)
        XCTAssertTrue(SpeechLanguage.englishGB.isEnglish)
        XCTAssertFalse(SpeechLanguage.englishUS.isPortuguese)

        XCTAssertEqual(SpeechLanguage.portuguesePT.locale.identifier, "pt-PT")
        XCTAssertEqual(SpeechLanguage.englishUS.locale.identifier, "en-US")
    }
}
