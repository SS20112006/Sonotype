import AppKit
import XCTest
@preconcurrency import AVFoundation
@preconcurrency import Speech
@testable import Sonotype

// MARK: - Mocks para Testes de Integração do Pipeline

final class MockAudioCaptureService: AudioCaptureService, @unchecked Sendable {
    private let lock = NSLock()
    var startCaptureCalled = false
    var stopCaptureCalled = false
    var shouldThrowOnStart = false

    override func startCapture() throws {
        lock.lock()
        defer { lock.unlock() }
        if shouldThrowOnStart {
            throw AudioCaptureError.converterInitializationFailed
        }
        startCaptureCalled = true
    }

    override func stopCapture() {
        lock.lock()
        defer { lock.unlock() }
        stopCaptureCalled = true
    }
}

final class MockSpeechRecognitionService: SpeechRecognitionService, @unchecked Sendable {
    private let lock = NSLock()
    var startRecognitionCalled = false
    var finishAudioCalled = false
    var cancelCalled = false
    var shouldThrowOnStart = false
    var capturedLanguage: SpeechLanguage?
    var capturedContextualStrings: [String] = []
    var appendedBuffersCount = 0
    var savedTranscriptionUpdate: (@Sendable (String, Bool) -> Void)?
    var savedErrorCallback: (@Sendable (Error) -> Void)?

    override func startRecognition(
        language: SpeechLanguage = .portuguesePT,
        contextualStrings: [String] = [],
        onTranscriptionUpdate: @escaping @Sendable (String, Bool) -> Void,
        onError: (@Sendable (Error) -> Void)? = nil
    ) throws {
        lock.lock()
        defer { lock.unlock() }
        if shouldThrowOnStart {
            throw SpeechRecognitionError.recognizerUnavailable(language)
        }
        startRecognitionCalled = true
        capturedLanguage = language
        capturedContextualStrings = contextualStrings
        savedTranscriptionUpdate = onTranscriptionUpdate
        savedErrorCallback = onError
    }

    override func appendBuffer(_ buffer: AVAudioPCMBuffer) {
        lock.lock()
        defer { lock.unlock() }
        appendedBuffersCount += 1
    }

    @discardableResult
    override func finishAudio() -> String {
        lock.lock()
        defer { lock.unlock() }
        finishAudioCalled = true
        return ""
    }

    override func cancel() {
        lock.lock()
        defer { lock.unlock() }
        cancelCalled = true
    }
}

@MainActor
private final class MockHotkeyForPipeline: GlobalHotkeyMonitoring, Sendable {
    var isEnabled: Bool = true
    var currentHotkey: GlobalHotkey = .defaultToggle

    var hotkeyAction: (@MainActor @Sendable () -> Void)?
    var escapeAction: (@MainActor @Sendable () -> Void)?

    func startMonitoring() {}
    func stopMonitoring() {}

    func onHotkeyPressed(_ action: @escaping @MainActor @Sendable () -> Void) {
        self.hotkeyAction = action
    }

    func onEscapePressed(_ action: @escaping @MainActor @Sendable () -> Void) {
        self.escapeAction = action
    }

    func simulateHotkeyPressed() {
        hotkeyAction?()
    }

    func simulateEscapePressed() {
        escapeAction?()
    }
}

@MainActor
private final class MockActivationPolicyForPipeline: ActivationPolicyControlling, Sendable {
    var activationPolicy: NSApplication.ActivationPolicy = .accessory

    func setActivationPolicy(_ policy: NSApplication.ActivationPolicy) -> Bool {
        activationPolicy = policy
        return true
    }
}

// MARK: - Testes de Integração do Pipeline em AppDelegate

@MainActor
final class AppDelegatePipelineTests: XCTestCase {
    private var appDelegate: AppDelegate!
    private var coordinator: RecordingSessionCoordinator!
    private var mockHotkey: MockHotkeyForPipeline!
    private var hudController: HUDController!
    private var dockCoordinator: DockVisibilityCoordinator!
    private var menuBarManager: MenuBarExtraManager!
    private var repository: PersistenceRepository!
    private var mockAudioService: MockAudioCaptureService!
    private var mockSpeechService: MockSpeechRecognitionService!
    private var languageDetector: LanguageDetectorService!
    private var postProcessor: TextPostProcessor!
    private var mockAX: MockAccessibilityInjector!
    private var mockKeystroke: MockKeystrokeSimulator!
    private var testPasteboard: NSPasteboard!
    private var injectionService: TextInjectionService!
    private var mockPermissions: MockPermissionsService!

    override func setUp() async throws {
        try await super.setUp()

        mockHotkey = MockHotkeyForPipeline()
        let stateMachine = RecordingStateMachine(hotkeyMode: .toggle)
        let silenceManager = SilenceTimeoutManager(timeoutDuration: 45.0)
        let soundPlayer = MockFeedbackSoundPlayer()

        coordinator = RecordingSessionCoordinator(
            stateMachine: stateMachine,
            hotkeyManager: mockHotkey,
            silenceManager: silenceManager,
            soundPlayer: soundPlayer
        )

        hudController = HUDController()
        dockCoordinator = DockVisibilityCoordinator(
            initialMode: .menuBarOnly,
            policyController: MockActivationPolicyForPipeline()
        )
        menuBarManager = MenuBarExtraManager()
        repository = try PersistenceRepository(inMemory: true)

        mockAudioService = MockAudioCaptureService()
        mockSpeechService = MockSpeechRecognitionService()
        languageDetector = LanguageDetectorService(defaultLanguage: .portuguesePT)
        postProcessor = TextPostProcessor()

        mockAX = MockAccessibilityInjector()
        mockKeystroke = MockKeystrokeSimulator()
        testPasteboard = NSPasteboard(name: .init("AppDelegatePipelineTests-\(UUID().uuidString)"))
        let clipboard = ClipboardSafetyManager(pasteboard: testPasteboard)
        injectionService = TextInjectionService(
            accessibilityInjector: mockAX,
            keystrokeSimulator: mockKeystroke,
            clipboardManager: clipboard
        )

        mockPermissions = MockPermissionsService()
        mockPermissions.microphoneStatus = .authorized
        mockPermissions.speechStatus = .authorized

        appDelegate = AppDelegate()
        appDelegate.setupCoreServices(
            coordinator: coordinator,
            hudController: hudController,
            dockCoordinator: dockCoordinator,
            menuBarManager: menuBarManager,
            repository: repository,
            audioCaptureService: mockAudioService,
            speechService: mockSpeechService,
            languageDetector: languageDetector,
            postProcessor: postProcessor,
            injectionService: injectionService,
            permissionsService: mockPermissions
        )
    }

    override func tearDown() async throws {
        coordinator.stop()
        menuBarManager.destroy()
        hudController.reset()
        dockCoordinator.stopObservingWindowNotifications()
        testPasteboard.releaseGlobally()

        appDelegate = nil
        coordinator = nil
        mockHotkey = nil
        hudController = nil
        dockCoordinator = nil
        menuBarManager = nil
        repository = nil
        mockAudioService = nil
        mockSpeechService = nil
        languageDetector = nil
        postProcessor = nil
        mockAX = nil
        mockKeystroke = nil
        testPasteboard = nil
        injectionService = nil
        mockPermissions = nil

        try await super.tearDown()
    }

    // MARK: - Verificação da Inicialização e Injeção de Dependências

    func testSetupCoreServicesInitializesAllServices() {
        XCTAssertNotNil(appDelegate.coordinator)
        XCTAssertNotNil(appDelegate.hudController)
        XCTAssertNotNil(appDelegate.dockCoordinator)
        XCTAssertNotNil(appDelegate.menuBarManager)
        XCTAssertNotNil(appDelegate.repository)
        XCTAssertNotNil(appDelegate.audioCaptureService)
        XCTAssertNotNil(appDelegate.speechService)
        XCTAssertNotNil(appDelegate.languageDetector)
        XCTAssertNotNil(appDelegate.postProcessor)
        XCTAssertNotNil(appDelegate.injectionService)
        XCTAssertEqual(appDelegate.activeLanguage, .portuguesePT)
        XCTAssertEqual(appDelegate.currentTranscription, "")
    }

    // MARK: - Pipeline de Início de Gravação (onStartRecording)

    func testStartRecordingWiredSuccessfully() {
        // Dispara início da sessão através do atalho global
        mockHotkey.simulateHotkeyPressed()

        XCTAssertEqual(coordinator.stateMachine.currentState, .recording)
        XCTAssertTrue(mockSpeechService.startRecognitionCalled, "O serviço de fala deve ser iniciado.")
        XCTAssertEqual(mockSpeechService.capturedLanguage, .portuguesePT)
        XCTAssertTrue(mockAudioService.startCaptureCalled, "A captação de áudio deve ser iniciada.")
        XCTAssertTrue(hudController.viewModel.isVisible, "O HUD deve ficar visível.")
        XCTAssertEqual(hudController.viewModel.displayState, .recording)
        XCTAssertEqual(menuBarManager.currentState, .recording)

        // Testa passagem de buffer capturado para o speechService
        let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 16000, channels: 1, interleaved: false)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 1024)!
        mockAudioService.onBufferCaptured?(buffer)
        XCTAssertEqual(mockSpeechService.appendedBuffersCount, 1, "Buffers de áudio devem fluir diretamente para o speechService.")

        // Testa atualização de amplitude para o coordinator e HUD
        mockAudioService.onAmplitudeChanged?(0.82)
        XCTAssertEqual(hudController.viewModel.amplitude, 0.82, accuracy: 0.001)
    }

    func testStartRecordingSpeechServiceErrorHandled() {
        mockSpeechService.shouldThrowOnStart = true

        mockHotkey.simulateHotkeyPressed()

        // Como o reconhecimento falhou, o coordenador deve tratar o erro e regressar a idle
        XCTAssertEqual(coordinator.stateMachine.currentState, .idle)
        XCTAssertFalse(mockAudioService.startCaptureCalled, "A captação não deve iniciar se o reconhecimento falhar.")
        XCTAssertEqual(hudController.viewModel.displayState, .cancelled)
        XCTAssertEqual(hudController.viewModel.configuration.cancelledTitle, "Idioma indisponível")
        XCTAssertEqual(menuBarManager.currentState, .idle)
    }

    func testCoordinatorOnErrorDisplaysUserFriendlyHUDReasonForSpeechErrors() {
        coordinator.handleError(SpeechRecognitionError.notAuthorized)
        XCTAssertEqual(hudController.viewModel.displayState, .cancelled)
        XCTAssertEqual(hudController.viewModel.configuration.cancelledTitle, "Sem permissão de fala")

        coordinator.handleError(SpeechRecognitionError.microphoneNotAuthorized)
        XCTAssertEqual(hudController.viewModel.displayState, .cancelled)
        XCTAssertEqual(hudController.viewModel.configuration.cancelledTitle, "Sem microfone")

        coordinator.handleError(SpeechRecognitionError.onDeviceRecognitionUnsupported(.portuguesePT))
        XCTAssertEqual(hudController.viewModel.displayState, .cancelled)
        XCTAssertEqual(hudController.viewModel.configuration.cancelledTitle, "Voz offline indisponível")
    }

    func testStartRecordingWithUnauthorizedMicrophoneCancelsSession() {
        mockPermissions.microphoneStatus = .denied

        mockHotkey.simulateHotkeyPressed()

        XCTAssertEqual(coordinator.stateMachine.currentState, .idle)
        XCTAssertFalse(mockAudioService.startCaptureCalled)
        XCTAssertEqual(hudController.viewModel.displayState, .cancelled)
        XCTAssertEqual(hudController.viewModel.configuration.cancelledTitle, "Sem microfone")
        XCTAssertEqual(mockPermissions.openSystemSettingsCallCount, 1)
        XCTAssertEqual(mockPermissions.lastOpenedSettingsPane, .microphone)
    }

    func testStartRecordingWithNotDeterminedSpeechCancelsSession() {
        mockPermissions.speechStatus = .notDetermined

        mockHotkey.simulateHotkeyPressed()

        XCTAssertEqual(coordinator.stateMachine.currentState, .idle)
        XCTAssertFalse(mockSpeechService.startRecognitionCalled)
        XCTAssertEqual(hudController.viewModel.displayState, .cancelled)
        XCTAssertEqual(hudController.viewModel.configuration.cancelledTitle, "Sem permissão de fala")
        XCTAssertEqual(mockPermissions.openSystemSettingsCallCount, 1)
        XCTAssertEqual(mockPermissions.lastOpenedSettingsPane, .speechRecognition)
    }

    func testStartRecordingAudioCaptureServiceErrorHandled() {
        mockAudioService.shouldThrowOnStart = true

        mockHotkey.simulateHotkeyPressed()

        // Como a captura de áudio falhou, a fala deve ser cancelada e o coordenador tratado
        XCTAssertEqual(coordinator.stateMachine.currentState, .idle)
        XCTAssertTrue(mockSpeechService.cancelCalled, "A sessão de fala deve ser cancelada se a captura falhar.")
        XCTAssertEqual(hudController.viewModel.displayState, .cancelled)
        XCTAssertEqual(hudController.viewModel.configuration.cancelledTitle, "Erro no conversor de áudio")
        XCTAssertEqual(menuBarManager.currentState, .idle)
    }

    // MARK: - Pipeline de Finalização da Gravação (onFinishRecording)

    func testFinishRecordingPipelineWithTranscribedText() async throws {
        // Regista regra de substituição de teste
        try repository.addReplacementRule(trigger: "computador", replacement: "dispositivo macOS")

        // 1. Inicia gravação
        mockHotkey.simulateHotkeyPressed()
        XCTAssertEqual(coordinator.stateMachine.currentState, .recording)

        // 2. Simula transcrição acumulada
        appDelegate.currentTranscription = "o meu computador vírgula funciona muito bem"

        // 3. Finaliza gravação via toggle de atalho
        mockHotkey.simulateHotkeyPressed()

        // Aguarda execução assíncrona do processamento e injeção com polling determinístico
        for _ in 0..<50 {
            if coordinator.stateMachine.currentState == .idle { break }
            try? await Task.sleep(nanoseconds: 10_000_000)
        }

        // Verificações do ciclo de paragem
        XCTAssertTrue(mockAudioService.stopCaptureCalled, "A captura de áudio deve ser interrompida.")
        XCTAssertTrue(mockSpeechService.finishAudioCalled, "O serviço de fala deve finalizar o fluxo de áudio.")
        XCTAssertEqual(coordinator.stateMachine.currentState, .idle)
        XCTAssertEqual(appDelegate.currentTranscription, "", "A transcrição em AppDelegate deve ser limpa após processamento.")

        // Verificações de processamento e injeção
        XCTAssertEqual(mockAX.injectCallCount, 1, "O texto final processado deve ser injetado.")
        let injected = mockAX.injectedText ?? ""
        XCTAssertTrue(injected.contains("dispositivo macOS"), "A regra de substituição deve ser aplicada.")
        XCTAssertTrue(injected.contains(", funciona"), "O comando oral 'vírgula' deve ser convertido em pontuação.")
        XCTAssertTrue(injected.hasPrefix("O meu"), "A capitalização de início de frase deve ser aplicada.")

        // Verificações de persistência
        let records = try repository.fetchTranscriptions()
        XCTAssertEqual(records.count, 1, "A transcrição deve ser gravada no repositório SwiftData.")
        XCTAssertEqual(records.first?.text, injected)
        XCTAssertEqual(records.first?.detectedLanguage, "pt-PT")
    }

    func testFinishRecordingPipelineWithEmptyTextReturnsEarly() async throws {
        // 1. Inicia gravação
        mockHotkey.simulateHotkeyPressed()

        // 2. Transcrição vazia / apenas espaços
        appDelegate.currentTranscription = "   \n\t  "

        // 3. Finaliza gravação
        mockHotkey.simulateHotkeyPressed()
        for _ in 0..<50 {
            if coordinator.stateMachine.currentState == .idle { break }
            try? await Task.sleep(nanoseconds: 10_000_000)
        }

        XCTAssertTrue(mockAudioService.stopCaptureCalled)
        XCTAssertTrue(mockSpeechService.finishAudioCalled)
        XCTAssertEqual(coordinator.stateMachine.currentState, .idle)
        XCTAssertEqual(mockAX.injectCallCount, 0, "Nenhum texto deve ser injetado se o resultado for vazio.")

        let records = try repository.fetchTranscriptions()
        XCTAssertEqual(records.count, 0, "Nenhuma transcrição vazia deve ser gravada no repositório.")
    }

    // MARK: - Pipeline de Cancelamento da Gravação (onCancelRecording)

    func testCancelRecordingWiredSuccessfully() {
        mockHotkey.simulateHotkeyPressed()
        XCTAssertEqual(coordinator.stateMachine.currentState, .recording)

        appDelegate.currentTranscription = "texto a ser descartado"

        // Cancela através da tecla Escape
        mockHotkey.simulateEscapePressed()

        XCTAssertEqual(coordinator.stateMachine.currentState, .idle)
        XCTAssertTrue(mockAudioService.stopCaptureCalled, "A captura de áudio deve ser interrompida no cancelamento.")
        XCTAssertTrue(mockSpeechService.cancelCalled, "O reconhecimento de fala deve ser cancelado.")
        XCTAssertEqual(appDelegate.currentTranscription, "", "O rascunho de transcrição deve ser descartado.")
        XCTAssertEqual(mockAX.injectCallCount, 0, "Nenhum texto deve ser injetado no cancelamento.")
        XCTAssertEqual(hudController.viewModel.displayState, .cancelled)
        XCTAssertEqual(hudController.viewModel.configuration.cancelledTitle, "Cancelado")
        XCTAssertEqual(menuBarManager.currentState, .idle)
    }

    // MARK: - Tratamento de Erros da Sessão (onError)

    func testCoordinatorOnErrorResetsAudioAndSpeech() {
        mockHotkey.simulateHotkeyPressed()
        XCTAssertEqual(coordinator.stateMachine.currentState, .recording)

        appDelegate.currentTranscription = "conteúdo pendente"

        // Simula erro direto emitido no coordenador
        coordinator.handleError(AudioCaptureError.bufferAllocationFailed)

        XCTAssertEqual(coordinator.stateMachine.currentState, .idle)
        XCTAssertTrue(mockAudioService.stopCaptureCalled)
        XCTAssertTrue(mockSpeechService.cancelCalled)
        XCTAssertEqual(appDelegate.currentTranscription, "")
        XCTAssertEqual(hudController.viewModel.displayState, .cancelled)
        XCTAssertEqual(hudController.viewModel.configuration.cancelledTitle, "Erro de memória")
        XCTAssertEqual(menuBarManager.currentState, .idle)
    }

    // MARK: - Encadeamento de Callbacks Pré-existentes

    func testSetupCoreServicesPreservesPreExistingHandlers() async {
        var preStartRan = false
        var preFinishRan = false
        var preCancelRan = false

        let customCoordinator = RecordingSessionCoordinator(
            stateMachine: RecordingStateMachine(hotkeyMode: .toggle),
            hotkeyManager: MockHotkeyForPipeline(),
            silenceManager: SilenceTimeoutManager(timeoutDuration: 45.0),
            soundPlayer: MockFeedbackSoundPlayer()
        )

        customCoordinator.onStartRecording = {
            preStartRan = true
        }
        customCoordinator.onFinishRecording = { _ in
            preFinishRan = true
        }
        customCoordinator.onCancelRecording = {
            preCancelRan = true
        }

        let customMenuBar = MenuBarExtraManager()
        let customDelegate = AppDelegate()
        let authorizedPermissions = MockPermissionsService()
        authorizedPermissions.microphoneStatus = .authorized
        authorizedPermissions.speechStatus = .authorized

        customDelegate.setupCoreServices(
            coordinator: customCoordinator,
            hudController: HUDController(),
            dockCoordinator: DockVisibilityCoordinator(initialMode: .menuBarOnly, policyController: MockActivationPolicyForPipeline()),
            menuBarManager: customMenuBar,
            repository: try! PersistenceRepository(inMemory: true),
            audioCaptureService: MockAudioCaptureService(),
            speechService: MockSpeechRecognitionService(),
            languageDetector: LanguageDetectorService(),
            postProcessor: TextPostProcessor(),
            injectionService: injectionService,
            permissionsService: authorizedPermissions
        )

        // 1. Inicia gravação
        customCoordinator.handleHotkeyTrigger()
        XCTAssertTrue(preStartRan, "O handler original pre-existente onStartRecording deve ter sido chamado.")

        // 2. Finaliza gravação
        customCoordinator.handleHotkeyTrigger()
        for _ in 0..<50 {
            if customCoordinator.stateMachine.currentState == .idle { break }
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
        XCTAssertTrue(preFinishRan, "O handler original pre-existente onFinishRecording deve ter sido chamado.")

        // 3. Inicia e cancela
        customCoordinator.handleHotkeyTrigger()
        customCoordinator.handleEscapeTrigger()
        XCTAssertTrue(preCancelRan, "O handler original pre-existente onCancelRecording deve ter sido chamado.")

        customCoordinator.stop()
        customMenuBar.destroy()
    }
}
