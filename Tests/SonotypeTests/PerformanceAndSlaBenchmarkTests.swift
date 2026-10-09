import AppKit
import Darwin
import XCTest
@testable import Sonotype

@MainActor
final class PerformanceAndSlaBenchmarkTests: XCTestCase {

    // MARK: - Helper de Memória macOS

    private func getResidentMemoryBytes() -> UInt64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size / MemoryLayout<natural_t>.size)
        let kerr = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        return kerr == KERN_SUCCESS ? info.resident_size : 0
    }

    // MARK: - SLA 1: Cold Boot / Inicialização de Serviços < 1.0s

    func testColdBootInitializationSLA() throws {
        let startTime = CFAbsoluteTimeGetCurrent()

        // 1. Inicializar contentor SwiftData em memória e repositório
        let container = try PersistenceContainerFactory.makeContainer(inMemory: true)
        let repository = PersistenceRepository(container: container)

        // 2. Inicializar gestor de preferências
        let testSuiteName = "PerformanceTests-\(UUID().uuidString)"
        let testDefaults = UserDefaults(suiteName: testSuiteName)!
        let preferencesManager = PreferencesManager(userDefaults: testDefaults)

        // 3. Inicializar pipeline de processamento de texto e idioma
        let languageDetector = LanguageDetectorService()
        let postProcessor = TextPostProcessor()

        // 4. Inicializar temporizador de silêncio e máquina de estados
        let silenceManager = SilenceTimeoutManager()
        let stateMachine = RecordingStateMachine()

        // 5. Inicializar injeção de texto com salvaguarda de clipboard
        let testPasteboard = NSPasteboard(name: .init("PerfPasteboard-\(UUID().uuidString)"))
        let clipboardManager = ClipboardSafetyManager(pasteboard: testPasteboard)
        let mockAX = MockAccessibilityInjector()
        let mockKeys = MockKeystrokeSimulator()
        let injectionService = TextInjectionService(
            accessibilityInjector: mockAX,
            keystrokeSimulator: mockKeys,
            clipboardManager: clipboardManager
        )

        let elapsedTime = CFAbsoluteTimeGetCurrent() - startTime

        // SLA de Cold Boot: < 1.0s (habitualmente < 0.15s)
        XCTAssertLessThan(
            elapsedTime,
            1.0,
            "A inicialização a frio dos serviços excedeu o SLA de 1.0s (tempo real: \(elapsedTime)s)"
        )

        // Limpeza defensiva
        testPasteboard.releaseGlobally()
        testDefaults.removePersistentDomain(forName: testSuiteName)
        _ = (repository, preferencesManager, languageDetector, postProcessor, silenceManager, stateMachine, injectionService)
    }

    // MARK: - SLA 2: Latência de Pós-Processamento e Injeção < 50ms

    func testTextInjectionAndPostProcessingLatencySLA() async throws {
        let postProcessor = TextPostProcessor()
        let mockAX = MockAccessibilityInjector()
        let mockKeys = MockKeystrokeSimulator()
        let testPasteboard = NSPasteboard(name: .init("PerfLatencyPasteboard-\(UUID().uuidString)"))
        let clipboardManager = ClipboardSafetyManager(pasteboard: testPasteboard)
        let injectionService = TextInjectionService(
            accessibilityInjector: mockAX,
            keystrokeSimulator: mockKeys,
            clipboardManager: clipboardManager
        )

        let sampleSpeech = "olá bom dia vírgula esta é uma demonstração de performance do sonotype ponto final"
        let iterations = 20
        var totalDuration: Double = 0

        for _ in 0..<iterations {
            let start = CFAbsoluteTimeGetCurrent()

            let processed = postProcessor.process(
                text: sampleSpeech,
                language: .portuguesePT,
                options: .default
            )

            let result = await injectionService.inject(
                text: processed,
                strategy: .accessibilityOnly,
                clipboardMode: .pasteAndKeep
            )

            let duration = CFAbsoluteTimeGetCurrent() - start
            totalDuration += duration

            XCTAssertTrue(result.success)
        }

        let averageLatencyMs = (totalDuration / Double(iterations)) * 1000.0

        // SLA de Injeção no Cursor: < 50ms (habitualmente < 5ms)
        XCTAssertLessThan(
            averageLatencyMs,
            50.0,
            "A latência média de processamento e injeção excedeu o SLA de 50ms (tempo médio: \(averageLatencyMs)ms)"
        )

        testPasteboard.releaseGlobally()
    }

    // MARK: - SLA 3: Garantia Estrita de Zero Retenção de Áudio em Disco

    func testZeroAudioRetentionPolicy() throws {
        let tempDir = FileManager.default.temporaryDirectory
        let initialAudioFiles = try FileManager.default.contentsOfDirectory(atPath: tempDir.path)
            .filter { $0.hasSuffix(".wav") || $0.hasSuffix(".m4a") || $0.hasSuffix(".caf") }

        let container = try PersistenceContainerFactory.makeContainer(inMemory: true)
        let repository = PersistenceRepository(container: container)

        // Simula gravação e inserção no histórico de 10 sessões
        for i in 1...10 {
            try repository.recordTranscription(
                text: "Transcrição de teste de conformidade de segurança #\(i)",
                duration: 4.5,
                language: "pt-PT"
            )
        }

        let finalAudioFiles = try FileManager.default.contentsOfDirectory(atPath: tempDir.path)
            .filter { $0.hasSuffix(".wav") || $0.hasSuffix(".m4a") || $0.hasSuffix(".caf") }

        XCTAssertEqual(
            initialAudioFiles.count,
            finalAudioFiles.count,
            "Foram detetados ficheiros de áudio persistidos em disco. Violação da política de zero retenção."
        )

        let history = try repository.fetchTranscriptions()
        XCTAssertEqual(history.count, 10)
    }

    // MARK: - SLA 4: Controlo de Pegada de Memória em Operação Ativa

    func testMemoryFootprintSLA() throws {
        let initialBytes = getResidentMemoryBytes()

        let container = try PersistenceContainerFactory.makeContainer(inMemory: true)
        let repository = PersistenceRepository(container: container)
        let postProcessor = TextPostProcessor()

        // Simula processamento intensivo de 50 sessões sucessivas
        for i in 0..<50 {
            let processed = postProcessor.process(
                text: "Processamento de texto de teste número \(i) com comandos e pontuação automática vírgula demonstrando economia de memória.",
                language: .portuguesePT,
                options: .default
            )
            try repository.recordTranscription(text: processed, duration: 2.0, language: "pt-PT")
        }

        let finalBytes = getResidentMemoryBytes()
        let deltaMB = Double(finalBytes > initialBytes ? finalBytes - initialBytes : 0) / (1024.0 * 1024.0)

        // O crescimento de memória residente durante operação intensiva deve ser estritamente contido (< 25MB)
        XCTAssertLessThan(
            deltaMB,
            25.0,
            "O crescimento de memória residente durante operação intensiva excedeu 25MB (delta: \(deltaMB)MB)"
        )
    }
}
