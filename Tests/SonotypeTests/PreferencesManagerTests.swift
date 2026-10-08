import AppKit
import XCTest
@preconcurrency import AVFoundation
@preconcurrency import Speech
@testable import Sonotype

// MARK: - Mocks Auxiliares para Testes de Integração de Preferências

@MainActor
private final class MockHotkeyForPreferences: GlobalHotkeyMonitoring, Sendable {
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
private final class MockActivationPolicyForPreferences: ActivationPolicyControlling, Sendable {
    var activationPolicy: NSApplication.ActivationPolicy = .accessory

    func setActivationPolicy(_ policy: NSApplication.ActivationPolicy) -> Bool {
        activationPolicy = policy
        return true
    }
}

// MARK: - Suite de Testes do PreferencesManager

@MainActor
final class PreferencesManagerTests: XCTestCase {
    private var isolatedDefaults: UserDefaults!
    private var suiteName: String!

    override func setUp() async throws {
        try await super.setUp()
        suiteName = "PreferencesManagerTests-\(UUID().uuidString)"
        isolatedDefaults = UserDefaults(suiteName: suiteName)
        isolatedDefaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() async throws {
        isolatedDefaults.removePersistentDomain(forName: suiteName)
        isolatedDefaults = nil
        suiteName = nil
        try await super.tearDown()
    }

    // MARK: - 1. Carregamento dos Valores Padrão

    func testDefaultValuesLoadedOnInitialization() {
        let manager = PreferencesManager(userDefaults: isolatedDefaults)
        let prefs = manager.preferences

        XCTAssertFalse(prefs.launchAtLogin)
        XCTAssertEqual(prefs.dockVisibilityMode, .dynamic)
        XCTAssertEqual(prefs.triggerMode, .toggle)
        XCTAssertEqual(prefs.globalHotkey, .defaultToggle)
        XCTAssertEqual(prefs.silenceTimeoutSeconds, 45.0)
        XCTAssertTrue(prefs.soundFeedbackEnabled)
        XCTAssertEqual(prefs.languageSelectionMode, .autoDetect)
        XCTAssertEqual(prefs.hudFeedbackMode, .waveformOnly)
        XCTAssertTrue(prefs.oralCommandsEnabled)
        XCTAssertTrue(prefs.fillerFilterEnabled)
        XCTAssertTrue(prefs.autoCapitalizationEnabled)
        XCTAssertFalse(prefs.autoFinalPeriodEnabled)
        XCTAssertEqual(prefs.clipboardSafetyMode, .pasteAndKeep)
        XCTAssertEqual(prefs.textInjectionStrategy, .accessibilityWithFallback)
        XCTAssertEqual(prefs.metricsVisibility, DashboardMetricsVisibility())

        // Testar propriedades de conveniência no manager
        XCTAssertFalse(manager.launchAtLogin)
        XCTAssertEqual(manager.dockVisibilityMode, .dynamic)
        XCTAssertEqual(manager.triggerMode, .toggle)
        XCTAssertEqual(manager.globalHotkey, .defaultToggle)
        XCTAssertEqual(manager.silenceTimeoutSeconds, 45.0)
        XCTAssertTrue(manager.soundFeedbackEnabled)
        XCTAssertEqual(manager.languageSelectionMode, .autoDetect)
        XCTAssertEqual(manager.hudFeedbackMode, .waveformOnly)
        XCTAssertTrue(manager.oralCommandsEnabled)
        XCTAssertTrue(manager.fillerFilterEnabled)
        XCTAssertTrue(manager.autoCapitalizationEnabled)
        XCTAssertFalse(manager.autoFinalPeriodEnabled)
        XCTAssertEqual(manager.clipboardSafetyMode, .pasteAndKeep)
        XCTAssertEqual(manager.textInjectionStrategy, .accessibilityWithFallback)
        XCTAssertEqual(manager.metricsVisibility, DashboardMetricsVisibility.default)
    }

    // MARK: - 2. Persistência e Recuperação em UserDefaults Isolado

    func testPersistenceAndRecoveryInIsolatedUserDefaults() {
        let manager1 = PreferencesManager(userDefaults: isolatedDefaults)

        let customHotkey = GlobalHotkey(keyCode: 36, modifiers: [.command, .shift])
        let customMetrics = DashboardMetricsVisibility(
            timeSaved: false,
            totalWords: true,
            sessionsCount: false,
            speakingSpeed: true,
            languageBreakdown: false
        )

        manager1.launchAtLogin = true
        manager1.dockVisibilityMode = .alwaysDock
        manager1.triggerMode = .pushToTalk
        manager1.globalHotkey = customHotkey
        manager1.silenceTimeoutSeconds = 25.0
        manager1.soundFeedbackEnabled = false
        manager1.languageSelectionMode = .fixedEN
        manager1.hudFeedbackMode = .directCursor
        manager1.oralCommandsEnabled = false
        manager1.fillerFilterEnabled = false
        manager1.autoCapitalizationEnabled = false
        manager1.autoFinalPeriodEnabled = true
        manager1.clipboardSafetyMode = .preservePrevious
        manager1.textInjectionStrategy = .keystrokeOnly
        manager1.metricsVisibility = customMetrics

        // Criar segunda instância apontando para o mesmo UserDefaults
        let manager2 = PreferencesManager(userDefaults: isolatedDefaults)
        let loaded = manager2.preferences

        XCTAssertTrue(loaded.launchAtLogin)
        XCTAssertEqual(loaded.dockVisibilityMode, .alwaysDock)
        XCTAssertEqual(loaded.triggerMode, .pushToTalk)
        XCTAssertEqual(loaded.globalHotkey, customHotkey)
        XCTAssertEqual(loaded.silenceTimeoutSeconds, 25.0)
        XCTAssertFalse(loaded.soundFeedbackEnabled)
        XCTAssertEqual(loaded.languageSelectionMode, .fixedEN)
        XCTAssertEqual(loaded.hudFeedbackMode, .directCursor)
        XCTAssertFalse(loaded.oralCommandsEnabled)
        XCTAssertFalse(loaded.fillerFilterEnabled)
        XCTAssertFalse(loaded.autoCapitalizationEnabled)
        XCTAssertTrue(loaded.autoFinalPeriodEnabled)
        XCTAssertEqual(loaded.clipboardSafetyMode, .preservePrevious)
        XCTAssertEqual(loaded.textInjectionStrategy, .keystrokeOnly)
        XCTAssertEqual(loaded.metricsVisibility, customMetrics)

        // Testar persistência de silenceTimeoutSeconds como nil (desativado)
        manager1.silenceTimeoutSeconds = nil
        let manager3 = PreferencesManager(userDefaults: isolatedDefaults)
        XCTAssertNil(manager3.silenceTimeoutSeconds)

        // Testar recuperação graciosa e segura de dados corrompidos
        isolatedDefaults.set("corrupted-bytes-payload".data(using: .utf8)!, forKey: PreferencesManager.storageKey)
        let managerCorrupted = PreferencesManager(userDefaults: isolatedDefaults)
        XCTAssertEqual(managerCorrupted.preferences, AppPreferences.default)
    }

    // MARK: - 3. Reset para Valores Padrão

    func testResetToDefaults() {
        let manager = PreferencesManager(userDefaults: isolatedDefaults)

        manager.dockVisibilityMode = .menuBarOnly
        manager.soundFeedbackEnabled = false
        manager.silenceTimeoutSeconds = 10.0
        manager.languageSelectionMode = .fixedPT
        manager.autoFinalPeriodEnabled = true

        XCTAssertNotEqual(manager.preferences, AppPreferences.default)

        manager.resetToDefaults()

        XCTAssertEqual(manager.preferences, AppPreferences.default)

        // Verificar recuperação persistente pós-reset
        let reloaded = PreferencesManager(userDefaults: isolatedDefaults)
        XCTAssertEqual(reloaded.preferences, AppPreferences.default)
    }

    // MARK: - 4. Disparo de Callbacks em Tempo Real

    func testRealtimeCallbacksTriggerOnPropertyChanges() {
        let manager = PreferencesManager(userDefaults: isolatedDefaults)

        var dockChangedCallCount = 0
        var lastDockMode: DockVisibilityMode?
        manager.onDockModeChanged = { mode in
            dockChangedCallCount += 1
            lastDockMode = mode
        }

        var silenceTimeoutCallCount = 0
        var lastSilenceTimeout: TimeInterval??
        manager.onSilenceTimeoutChanged = { timeout in
            silenceTimeoutCallCount += 1
            lastSilenceTimeout = timeout
        }

        var soundFeedbackCallCount = 0
        var lastSoundFeedback: Bool?
        manager.onSoundFeedbackChanged = { enabled in
            soundFeedbackCallCount += 1
            lastSoundFeedback = enabled
        }

        var hotkeyCallCount = 0
        var lastHotkey: GlobalHotkey?
        manager.onHotkeyChanged = { hotkey in
            hotkeyCallCount += 1
            lastHotkey = hotkey
        }

        var languageModeCallCount = 0
        var lastLanguageMode: LanguageSelectionMode?
        manager.onLanguageModeChanged = { mode in
            languageModeCallCount += 1
            lastLanguageMode = mode
        }

        var triggerModeCallCount = 0
        var lastTriggerMode: RecordingTriggerMode?
        manager.onTriggerModeChanged = { mode in
            triggerModeCallCount += 1
            lastTriggerMode = mode
        }

        var hudFeedbackCallCount = 0
        var lastHudFeedback: HUDFeedbackMode?
        manager.onHUDFeedbackModeChanged = { mode in
            hudFeedbackCallCount += 1
            lastHudFeedback = mode
        }

        // 1. Alterar dockVisibilityMode
        manager.dockVisibilityMode = .menuBarOnly
        XCTAssertEqual(dockChangedCallCount, 1)
        XCTAssertEqual(lastDockMode, .menuBarOnly)

        // Alterar para o mesmo valor não deve disparar novamente
        manager.dockVisibilityMode = .menuBarOnly
        XCTAssertEqual(dockChangedCallCount, 1)

        // 2. Alterar silenceTimeoutSeconds
        manager.silenceTimeoutSeconds = 30.0
        XCTAssertEqual(silenceTimeoutCallCount, 1)
        XCTAssertEqual(lastSilenceTimeout, 30.0)

        manager.silenceTimeoutSeconds = nil
        XCTAssertEqual(silenceTimeoutCallCount, 2)
        XCTAssertNil(lastSilenceTimeout ?? 45.0)

        // 3. Alterar soundFeedbackEnabled
        manager.soundFeedbackEnabled = false
        XCTAssertEqual(soundFeedbackCallCount, 1)
        XCTAssertEqual(lastSoundFeedback, false)

        // 4. Alterar globalHotkey
        let newKey = GlobalHotkey(keyCode: 48, modifiers: [.control])
        manager.globalHotkey = newKey
        XCTAssertEqual(hotkeyCallCount, 1)
        XCTAssertEqual(lastHotkey, newKey)

        // 5. Alterar languageSelectionMode
        manager.languageSelectionMode = .fixedPT
        XCTAssertEqual(languageModeCallCount, 1)
        XCTAssertEqual(lastLanguageMode, .fixedPT)

        // 6. Alterar triggerMode
        manager.triggerMode = .pushToTalk
        XCTAssertEqual(triggerModeCallCount, 1)
        XCTAssertEqual(lastTriggerMode, .pushToTalk)

        // 7. Alterar hudFeedbackMode
        manager.hudFeedbackMode = .liveTranscription
        XCTAssertEqual(hudFeedbackCallCount, 1)
        XCTAssertEqual(lastHudFeedback, .liveTranscription)
    }

    // MARK: - 5. Integração com AppDelegate e Atualização Imediata dos Serviços

    func testAppDelegateIntegrationInitializesServicesFromPreferences() {
        let manager = PreferencesManager(userDefaults: isolatedDefaults)
        let customHotkey = GlobalHotkey(keyCode: 48, modifiers: [.option])
        manager.preferences = AppPreferences(
            dockVisibilityMode: .menuBarOnly,
            triggerMode: .pushToTalk,
            globalHotkey: customHotkey,
            silenceTimeoutSeconds: 20.0,
            soundFeedbackEnabled: false,
            languageSelectionMode: .fixedPT
        )

        let appDelegate = AppDelegate()
        let mockHotkey = MockHotkeyForPreferences()
        let silenceManager = SilenceTimeoutManager(timeoutDuration: 45.0)
        let soundPlayer = MockFeedbackSoundPlayer()
        let coordinator = RecordingSessionCoordinator(
            stateMachine: RecordingStateMachine(hotkeyMode: .toggle),
            hotkeyManager: mockHotkey,
            silenceManager: silenceManager,
            soundPlayer: soundPlayer
        )
        let dockCoordinator = DockVisibilityCoordinator(
            initialMode: .dynamic,
            policyController: MockActivationPolicyForPreferences()
        )

        appDelegate.setupCoreServices(
            preferencesManager: manager,
            coordinator: coordinator,
            hudController: HUDController(),
            dockCoordinator: dockCoordinator,
            menuBarManager: MenuBarExtraManager(),
            repository: try! PersistenceRepository(inMemory: true),
            audioCaptureService: MockAudioCaptureService(),
            speechService: MockSpeechRecognitionService(),
            languageDetector: LanguageDetectorService(),
            postProcessor: TextPostProcessor(),
            injectionService: TextInjectionService()
        )

        // Serviços devem ser configurados com os valores das preferências
        XCTAssertEqual(appDelegate.dockCoordinator?.currentMode, .menuBarOnly)
        XCTAssertEqual(appDelegate.coordinator?.silenceManager.timeoutDuration, 20.0)
        XCTAssertFalse(appDelegate.coordinator?.soundPlayer.isEnabled ?? true)
        XCTAssertEqual(appDelegate.coordinator?.hotkeyManager.currentHotkey, customHotkey)
        XCTAssertEqual(appDelegate.coordinator?.stateMachine.hotkeyMode, .pushToTalk)
        XCTAssertEqual(appDelegate.activeLanguage, .portuguesePT)
    }

    func testAppDelegateIntegrationUpdatesActiveServicesImmediately() {
        let manager = PreferencesManager(userDefaults: isolatedDefaults)
        let appDelegate = AppDelegate()

        let mockHotkey = MockHotkeyForPreferences()
        let silenceManager = SilenceTimeoutManager(timeoutDuration: 45.0)
        let soundPlayer = MockFeedbackSoundPlayer()
        let coordinator = RecordingSessionCoordinator(
            stateMachine: RecordingStateMachine(hotkeyMode: .toggle),
            hotkeyManager: mockHotkey,
            silenceManager: silenceManager,
            soundPlayer: soundPlayer
        )
        let dockCoordinator = DockVisibilityCoordinator(
            initialMode: .dynamic,
            policyController: MockActivationPolicyForPreferences()
        )

        appDelegate.setupCoreServices(
            preferencesManager: manager,
            coordinator: coordinator,
            hudController: HUDController(),
            dockCoordinator: dockCoordinator,
            menuBarManager: MenuBarExtraManager(),
            repository: try! PersistenceRepository(inMemory: true),
            audioCaptureService: MockAudioCaptureService(),
            speechService: MockSpeechRecognitionService(),
            languageDetector: LanguageDetectorService(),
            postProcessor: TextPostProcessor(),
            injectionService: TextInjectionService()
        )

        // 1. Modificar dockVisibilityMode -> reflete imediatamente no dockCoordinator
        manager.dockVisibilityMode = .alwaysDock
        XCTAssertEqual(appDelegate.dockCoordinator?.currentMode, .alwaysDock)

        // 2. Modificar silenceTimeoutSeconds -> reflete imediatamente no silenceManager
        manager.silenceTimeoutSeconds = 12.0
        XCTAssertEqual(appDelegate.coordinator?.silenceManager.timeoutDuration, 12.0)

        manager.silenceTimeoutSeconds = nil
        XCTAssertNil(appDelegate.coordinator?.silenceManager.timeoutDuration)

        // 3. Modificar soundFeedbackEnabled -> reflete imediatamente no soundPlayer
        manager.soundFeedbackEnabled = false
        XCTAssertFalse(appDelegate.coordinator?.soundPlayer.isEnabled ?? true)

        manager.soundFeedbackEnabled = true
        XCTAssertTrue(appDelegate.coordinator?.soundPlayer.isEnabled ?? false)

        // 4. Modificar globalHotkey -> reflete imediatamente no hotkeyManager
        let updatedHotkey = GlobalHotkey(keyCode: 36, modifiers: [.command])
        manager.globalHotkey = updatedHotkey
        XCTAssertEqual(appDelegate.coordinator?.hotkeyManager.currentHotkey, updatedHotkey)

        // 5. Modificar languageSelectionMode -> reflete imediatamente em activeLanguage
        manager.languageSelectionMode = .fixedEN
        XCTAssertEqual(appDelegate.activeLanguage, .englishUS)

        manager.languageSelectionMode = .fixedPT
        XCTAssertEqual(appDelegate.activeLanguage, .portuguesePT)

        manager.languageSelectionMode = .autoDetect
        XCTAssertEqual(appDelegate.activeLanguage, .portuguesePT)

        // 6. Modificar triggerMode -> reflete imediatamente na máquina de estados
        manager.triggerMode = .pushToTalk
        XCTAssertEqual(appDelegate.coordinator?.stateMachine.hotkeyMode, .pushToTalk)

        manager.triggerMode = .toggle
        XCTAssertEqual(appDelegate.coordinator?.stateMachine.hotkeyMode, .toggle)
    }

    // MARK: - 6. Respeito às Opções de Gravação e Pós-Processamento no Ciclo de Vida

    func testRecordingPipelineRespectsLanguageSelectionModeOnStart() {
        let manager = PreferencesManager(userDefaults: isolatedDefaults)
        manager.languageSelectionMode = .fixedEN

        let appDelegate = AppDelegate()
        let mockSpeech = MockSpeechRecognitionService()
        let mockAudio = MockAudioCaptureService()
        let mockHotkey = MockHotkeyForPreferences()
        let coordinator = RecordingSessionCoordinator(
            stateMachine: RecordingStateMachine(hotkeyMode: .toggle),
            hotkeyManager: mockHotkey,
            silenceManager: SilenceTimeoutManager(timeoutDuration: 45.0),
            soundPlayer: MockFeedbackSoundPlayer()
        )

        appDelegate.setupCoreServices(
            preferencesManager: manager,
            coordinator: coordinator,
            hudController: HUDController(),
            dockCoordinator: DockVisibilityCoordinator(initialMode: .menuBarOnly, policyController: MockActivationPolicyForPreferences()),
            menuBarManager: MenuBarExtraManager(),
            repository: try! PersistenceRepository(inMemory: true),
            audioCaptureService: mockAudio,
            speechService: mockSpeech,
            languageDetector: LanguageDetectorService(),
            postProcessor: TextPostProcessor(),
            injectionService: TextInjectionService()
        )

        // Inicia gravação com modo fixo EN
        mockHotkey.simulateHotkeyPressed()

        XCTAssertTrue(mockSpeech.startRecognitionCalled)
        XCTAssertEqual(mockSpeech.capturedLanguage, .englishUS)
        XCTAssertEqual(appDelegate.activeLanguage, .englishUS)
    }

    func testFinishRecordingAppliesConfiguredPreferences() async throws {
        let manager = PreferencesManager(userDefaults: isolatedDefaults)
        manager.fillerFilterEnabled = true
        manager.autoCapitalizationEnabled = true
        manager.autoFinalPeriodEnabled = true
        manager.languageSelectionMode = .fixedPT
        manager.clipboardSafetyMode = .pasteAndKeep
        manager.textInjectionStrategy = .accessibilityWithFallback

        let appDelegate = AppDelegate()
        let mockSpeech = MockSpeechRecognitionService()
        let mockAudio = MockAudioCaptureService()
        let mockHotkey = MockHotkeyForPreferences()
        let mockAX = MockAccessibilityInjector()
        let mockKeystroke = MockKeystrokeSimulator()
        let testPasteboard = NSPasteboard(name: .init("PreferencesManagerTestsPB-\(UUID().uuidString)"))
        let clipboard = ClipboardSafetyManager(pasteboard: testPasteboard)
        let injectionService = TextInjectionService(
            accessibilityInjector: mockAX,
            keystrokeSimulator: mockKeystroke,
            clipboardManager: clipboard
        )
        let repository = try PersistenceRepository(inMemory: true)

        let coordinator = RecordingSessionCoordinator(
            stateMachine: RecordingStateMachine(hotkeyMode: .toggle),
            hotkeyManager: mockHotkey,
            silenceManager: SilenceTimeoutManager(timeoutDuration: 45.0),
            soundPlayer: MockFeedbackSoundPlayer()
        )

        appDelegate.setupCoreServices(
            preferencesManager: manager,
            coordinator: coordinator,
            hudController: HUDController(),
            dockCoordinator: DockVisibilityCoordinator(initialMode: .menuBarOnly, policyController: MockActivationPolicyForPreferences()),
            menuBarManager: MenuBarExtraManager(),
            repository: repository,
            audioCaptureService: mockAudio,
            speechService: mockSpeech,
            languageDetector: LanguageDetectorService(),
            postProcessor: TextPostProcessor(),
            injectionService: injectionService
        )

        // Inicia gravação
        mockHotkey.simulateHotkeyPressed()
        // Define texto com hesitações e sem ponto final
        appDelegate.currentTranscription = "hum o teste do sistema funciona"

        // Para gravação
        mockHotkey.simulateHotkeyPressed()

        for _ in 0..<50 {
            if coordinator.stateMachine.currentState == .idle { break }
            try? await Task.sleep(nanoseconds: 10_000_000)
        }

        XCTAssertEqual(mockAX.injectCallCount, 1)
        let injected = mockAX.injectedText ?? ""
        // Hesitação "hum" deve ser filtrada
        XCTAssertFalse(injected.lowercased().contains("hum"))
        // Ponto final deve ser adicionado porque autoFinalPeriodEnabled está ativo
        XCTAssertTrue(injected.hasSuffix("."))
        // Início deve ser capitalizado
        XCTAssertTrue(injected.hasPrefix("O teste"))

        testPasteboard.releaseGlobally()
    }
}
