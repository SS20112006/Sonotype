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
}
