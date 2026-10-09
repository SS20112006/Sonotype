import XCTest
@preconcurrency import Speech
@preconcurrency import AVFoundation
@testable import Sonotype

final class SpeechRecognitionServiceTests: XCTestCase {
    private var service: SpeechRecognitionService!

    override func setUp() {
        super.setUp()
        service = SpeechRecognitionService(requiresOnDeviceRecognition: true)
    }

    override func tearDown() {
        service.cancel()
        service = nil
        super.tearDown()
    }

    func testRequiresOnDeviceRecognitionInvariantEnforced() {
        XCTAssertTrue(
            service.requiresOnDeviceRecognition,
            "O serviço deve exigir estritamente reconhecimento on-device (offline) conforme invariante."
        )
    }

    func testSupportedLocalesRecognizersInitialized() {
        for lang in SpeechLanguage.allCases {
            let rec = service.recognizer(for: lang)
            XCTAssertNotNil(rec, "Reconhecedor para \(lang.rawValue) deve ser inicializado com sucesso.")
            XCTAssertEqual(rec?.locale.identifier, lang.rawValue)
        }
    }

    func testInitialStateIsNotRecognizing() {
        XCTAssertFalse(service.isRecognizing)
    }

    func testSafeLifecycleWithoutActiveSession() {
        // Operações de paragem/cancelamento em idle não devem lançar exceções nem causar crashes
        service.cancel()
        service.finishAudio()
        XCTAssertFalse(service.isRecognizing)
    }

    func testAppendBufferInMemoryDoesNotWriteToDisk() {
        let fileManager = FileManager.default
        let tempDir = fileManager.temporaryDirectory
        let initialCount = (try? fileManager.contentsOfDirectory(atPath: tempDir.path))?.count ?? 0

        let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 16000, channels: 1, interleaved: false)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 1024)!
        buffer.frameLength = 1024

        // Envia múltiplos buffers simulados em RAM
        for _ in 0..<10 {
            service.appendBuffer(buffer)
        }

        let finalCount = (try? fileManager.contentsOfDirectory(atPath: tempDir.path))?.count ?? 0
        XCTAssertEqual(initialCount, finalCount, "Zero ficheiros de áudio podem ser gravados no disco.")
    }

    func testSpeechRecognitionErrorDescriptions() {
        let err1 = SpeechRecognitionError.recognizerUnavailable(.portuguesePT)
        XCTAssertNotNil(err1.errorDescription)
        let err2 = SpeechRecognitionError.onDeviceRecognitionUnsupported(.englishUS)
        XCTAssertNotNil(err2.errorDescription)
        let err3 = SpeechRecognitionError.alreadyRecognizing
        XCTAssertNotNil(err3.errorDescription)
        let err4 = SpeechRecognitionError.noActiveSession
        XCTAssertNotNil(err4.errorDescription)
        let err5 = SpeechRecognitionError.notAuthorized
        XCTAssertNotNil(err5.errorDescription)
        let err6 = SpeechRecognitionError.microphoneNotAuthorized
        XCTAssertNotNil(err6.errorDescription)
        let err7 = SpeechRecognitionError.dictationDisabled
        XCTAssertNotNil(err7.errorDescription)
        XCTAssertTrue(err7.errorDescription?.contains("Ditado") == true)
    }

    func testUtteranceBoundaryCommitDetection() {
        // Continuação simples: nova frase começa com a anterior -> não comita
        XCTAssertFalse(
            SpeechRecognitionService.shouldCommitPreviousUtterance(previous: "Olá", new: "Olá mundo"),
            "Expansão direta de frase não deve ser considerada nova elocução"
        )

        // Correção pontual com prefixo comum >= 50% -> não comita
        XCTAssertFalse(
            SpeechRecognitionService.shouldCommitPreviousUtterance(previous: "Eu vou falar com o João", new: "Eu vou falar com a Maria"),
            "Correção de final de frase deve substituir e não duplicar"
        )

        // Nova elocução após pausa (o bug relatado pelo utilizador): frase anterior longa, nova frase curta e sem prefixo comum -> DEVE comitar!
        XCTAssertTrue(
            SpeechRecognitionService.shouldCommitPreviousUtterance(
                previous: "Estive a falar cerca de quarenta segundos a um minuto e expliquei tudo",
                new: "duas palavras"
            ),
            "Nova elocução sem prefixo comum após pausa deve ser comitada para não perder o texto anterior"
        )

        // Expansão que contém a frase anterior -> não comita
        XCTAssertFalse(
            SpeechRecognitionService.shouldCommitPreviousUtterance(previous: "projeto", new: "o projeto todo"),
            "Frase nova que engloba a anterior não deve comitar previamente"
        )

        // Strings vazias -> não comita
        XCTAssertFalse(SpeechRecognitionService.shouldCommitPreviousUtterance(previous: "", new: "teste"))
        XCTAssertFalse(SpeechRecognitionService.shouldCommitPreviousUtterance(previous: "teste", new: ""))
    }

    func testCombineTranscriptions() {
        XCTAssertEqual(
            SpeechRecognitionService.combineTranscriptions("Primeira parte", "segunda parte"),
            "Primeira parte segunda parte"
        )
        XCTAssertEqual(
            SpeechRecognitionService.combineTranscriptions("", "apenas nova"),
            "apenas nova"
        )
        XCTAssertEqual(
            SpeechRecognitionService.combineTranscriptions("apenas anterior", ""),
            "apenas anterior"
        )
        XCTAssertEqual(
            SpeechRecognitionService.combineTranscriptions("   ", "   "),
            ""
        )
    }

    func testFinishAudioAsyncLifecycle() async {
        let text = await service.finishAudioAndGetFinalTranscription(timeoutSeconds: 0.1)
        XCTAssertEqual(text, "")
        XCTAssertFalse(service.isRecognizing)
    }
}
