import AppKit
import SwiftUI
import XCTest
@testable import Sonotype

@MainActor
final class SettingsViewsTests: XCTestCase {
    private var isolatedDefaults: UserDefaults!
    private var suiteName: String!
    private var preferencesManager: PreferencesManager!

    override func setUp() async throws {
        try await super.setUp()
        suiteName = "SettingsViewsTests-\(UUID().uuidString)"
        isolatedDefaults = UserDefaults(suiteName: suiteName)
        isolatedDefaults.removePersistentDomain(forName: suiteName)
        preferencesManager = PreferencesManager(userDefaults: isolatedDefaults)
    }

    override func tearDown() async throws {
        isolatedDefaults.removePersistentDomain(forName: suiteName)
        isolatedDefaults = nil
        preferencesManager = nil
        suiteName = nil
        try await super.tearDown()
    }

    // MARK: - 1. Inicialização e Renderização Básica de SettingsView e Abas

    func testSettingsViewInitialization() {
        let settingsView = SettingsView(preferencesManager: preferencesManager)
        XCTAssertNotNil(settingsView.body)
        XCTAssertEqual(settingsView.selectedTab, .general)
    }

    func testGeneralSettingsTabViewInitialization() {
        let tab = GeneralSettingsTabView(preferencesManager: preferencesManager)
        XCTAssertNotNil(tab.body)
    }

    func testPermissionsSettingsTabViewInitialization() {
        let mockService = MockPermissionsService()
        let tab = PermissionsSettingsTabView(permissionsService: mockService)
        XCTAssertNotNil(tab.body)
        XCTAssertEqual(tab.permissionsService.isAccessibilityAuthorized, false)
    }

    func testRecordingSettingsTabViewInitialization() {
        let tab = RecordingSettingsTabView(preferencesManager: preferencesManager)
        XCTAssertNotNil(tab.body)
    }

    func testTextLanguageSettingsTabViewInitialization() {
        let tab = TextLanguageSettingsTabView(preferencesManager: preferencesManager)
        XCTAssertNotNil(tab.body)
    }

    func testClipboardSettingsTabViewInitialization() {
        let tab = ClipboardSettingsTabView(preferencesManager: preferencesManager)
        XCTAssertNotNil(tab.body)
    }

    func testStatsSettingsTabViewInitialization() {
        let tab = StatsSettingsTabView(preferencesManager: preferencesManager)
        XCTAssertNotNil(tab.body)
    }

    // MARK: - 2. Testes de Mutação Reativa e Sincronização de Preferências

    func testGeneralTabMutationsReflectInPreferences() {
        preferencesManager.launchAtLogin = false
        preferencesManager.dockVisibilityMode = .dynamic

        // Alterna launchAtLogin
        preferencesManager.launchAtLogin = true
        XCTAssertTrue(preferencesManager.preferences.launchAtLogin)

        // Alterna dockVisibilityMode
        preferencesManager.dockVisibilityMode = .alwaysDock
        XCTAssertEqual(preferencesManager.preferences.dockVisibilityMode, .alwaysDock)

        preferencesManager.dockVisibilityMode = .menuBarOnly
        XCTAssertEqual(preferencesManager.preferences.dockVisibilityMode, .menuBarOnly)
    }

    func testRecordingTabMutationsReflectInPreferences() {
        preferencesManager.triggerMode = .toggle
        preferencesManager.silenceTimeoutSeconds = 45.0
        preferencesManager.soundFeedbackEnabled = true

        // Alterna modo de ativação
        preferencesManager.triggerMode = .pushToTalk
        XCTAssertEqual(preferencesManager.preferences.triggerMode, .pushToTalk)

        // Alterna timeout de silêncio
        preferencesManager.silenceTimeoutSeconds = 15.0
        XCTAssertEqual(preferencesManager.preferences.silenceTimeoutSeconds, 15.0)

        preferencesManager.silenceTimeoutSeconds = nil
        XCTAssertNil(preferencesManager.preferences.silenceTimeoutSeconds)

        // Alterna feedback sonoro
        preferencesManager.soundFeedbackEnabled = false
        XCTAssertFalse(preferencesManager.preferences.soundFeedbackEnabled)
    }

    func testTextLanguageTabMutationsReflectInPreferences() {
        preferencesManager.languageSelectionMode = .autoDetect
        preferencesManager.hudFeedbackMode = .waveformOnly
        preferencesManager.oralCommandsEnabled = true
        preferencesManager.fillerFilterEnabled = true
        preferencesManager.autoCapitalizationEnabled = true
        preferencesManager.autoFinalPeriodEnabled = false

        // Alterna modo de idioma
        preferencesManager.languageSelectionMode = .fixedEN
        XCTAssertEqual(preferencesManager.preferences.languageSelectionMode, .fixedEN)

        // Alterna feedback visual do HUD
        preferencesManager.hudFeedbackMode = .liveTranscription
        XCTAssertEqual(preferencesManager.preferences.hudFeedbackMode, .liveTranscription)

        preferencesManager.hudFeedbackMode = .directCursor
        XCTAssertEqual(preferencesManager.preferences.hudFeedbackMode, .directCursor)

        // Alterna toggles de pós-processamento
        preferencesManager.oralCommandsEnabled = false
        XCTAssertFalse(preferencesManager.preferences.oralCommandsEnabled)

        preferencesManager.fillerFilterEnabled = false
        XCTAssertFalse(preferencesManager.preferences.fillerFilterEnabled)

        preferencesManager.autoCapitalizationEnabled = false
        XCTAssertFalse(preferencesManager.preferences.autoCapitalizationEnabled)

        preferencesManager.autoFinalPeriodEnabled = true
        XCTAssertTrue(preferencesManager.preferences.autoFinalPeriodEnabled)
    }

    func testClipboardTabMutationsReflectInPreferences() {
        preferencesManager.clipboardSafetyMode = .pasteAndKeep
        preferencesManager.textInjectionStrategy = .accessibilityWithFallback

        // Alterna modo de clipboard
        preferencesManager.clipboardSafetyMode = .preservePrevious
        XCTAssertEqual(preferencesManager.preferences.clipboardSafetyMode, .preservePrevious)

        // Alterna estratégia de injeção
        preferencesManager.textInjectionStrategy = .keystrokeOnly
        XCTAssertEqual(preferencesManager.preferences.textInjectionStrategy, .keystrokeOnly)

        preferencesManager.textInjectionStrategy = .accessibilityOnly
        XCTAssertEqual(preferencesManager.preferences.textInjectionStrategy, .accessibilityOnly)
    }

    func testStatsTabMutationsReflectInPreferences() {
        var metrics = preferencesManager.metricsVisibility
        XCTAssertTrue(metrics.timeSaved)
        XCTAssertTrue(metrics.totalWords)
        XCTAssertTrue(metrics.sessionsCount)
        XCTAssertTrue(metrics.speakingSpeed)
        XCTAssertTrue(metrics.languageBreakdown)

        metrics.timeSaved = false
        metrics.speakingSpeed = false
        preferencesManager.metricsVisibility = metrics

        XCTAssertFalse(preferencesManager.preferences.metricsVisibility.timeSaved)
        XCTAssertFalse(preferencesManager.preferences.metricsVisibility.speakingSpeed)
        XCTAssertTrue(preferencesManager.preferences.metricsVisibility.totalWords)
        XCTAssertTrue(preferencesManager.preferences.metricsVisibility.sessionsCount)
        XCTAssertTrue(preferencesManager.preferences.metricsVisibility.languageBreakdown)
    }

    // MARK: - 3. Testes do HotkeyRecorderView

    func testHotkeyRecorderViewInitialStateAndRendering() {
        let recorder = HotkeyRecorderView(preferencesManager: preferencesManager)
        XCTAssertNotNil(recorder.body)
        XCTAssertFalse(recorder.isRecording)
        XCTAssertEqual(recorder.currentHotkey, .defaultToggle)
        XCTAssertNil(recorder.errorMessage)
    }

    func testHotkeyRecorderEscCancelsRecording() {
        let recorder = HotkeyRecorderView(preferencesManager: preferencesManager)
        recorder.startRecording()
        XCTAssertTrue(recorder.isRecording)

        // Pressionar Escape (keyCode 53) deve cancelar gravação sem alterar atalho
        let handled = recorder.handleCapturedKeyEvent(
            keyCode: 53,
            modifierFlags: [],
            manager: preferencesManager
        )

        XCTAssertTrue(handled)
        XCTAssertFalse(recorder.isRecording)
        XCTAssertEqual(preferencesManager.globalHotkey, .defaultToggle)
        XCTAssertNil(recorder.errorMessage)
    }

    func testHotkeyRecorderRejectsKeysWithoutModifiers() {
        let recorder = HotkeyRecorderView(preferencesManager: preferencesManager)
        recorder.startRecording()
        XCTAssertTrue(recorder.isRecording)

        // Pressionar tecla solta (ex: Espaço sem modificadores) deve ser rejeitado
        let handled = recorder.handleCapturedKeyEvent(
            keyCode: 49,
            modifierFlags: [],
            manager: preferencesManager
        )

        XCTAssertFalse(handled)
        XCTAssertTrue(recorder.isRecording)
        XCTAssertEqual(preferencesManager.globalHotkey, .defaultToggle)
        XCTAssertNotNil(recorder.errorMessage)
    }

    func testHotkeyRecorderAppliesValidShortcut() {
        let recorder = HotkeyRecorderView(preferencesManager: preferencesManager)
        recorder.startRecording()
        XCTAssertTrue(recorder.isRecording)

        // Pressionar combinação válida (Cmd + Shift + K -> keyCode 40)
        let handled = recorder.handleCapturedKeyEvent(
            keyCode: 40,
            modifierFlags: [.command, .shift],
            manager: preferencesManager
        )

        XCTAssertTrue(handled)
        XCTAssertFalse(recorder.isRecording)
        XCTAssertEqual(preferencesManager.globalHotkey.keyCode, 40)
        XCTAssertTrue(preferencesManager.globalHotkey.modifierFlags.contains(.command))
        XCTAssertTrue(preferencesManager.globalHotkey.modifierFlags.contains(.shift))
        XCTAssertFalse(preferencesManager.globalHotkey.modifierFlags.contains(.option))
        XCTAssertNil(recorder.errorMessage)
    }

    func testHotkeyRecorderResetToDefault() {
        let recorder = HotkeyRecorderView(preferencesManager: preferencesManager)
        let custom = GlobalHotkey(keyCode: 36, modifiers: [.command])
        preferencesManager.globalHotkey = custom
        XCTAssertEqual(recorder.currentHotkey, custom)

        recorder.resetToDefault()
        XCTAssertEqual(preferencesManager.globalHotkey, .defaultToggle)
    }

    // MARK: - 4. Testes de Integração com AppDelegate e Janelas

    func testAppDelegateOpenSettingsWindow() {
        let appDelegate = AppDelegate()
        let mockPermissions = MockPermissionsService()
        appDelegate.setupCoreServices(
            preferencesManager: preferencesManager,
            permissionsService: mockPermissions
        )

        // Acionar abertura da janela de definições
        appDelegate.openSettingsWindow()

        XCTAssertNotNil(appDelegate.settingsWindow)
        if let window = appDelegate.settingsWindow {
            XCTAssertEqual(window.title, "Definições")
            XCTAssertTrue(window.contentViewController is NSHostingController<SettingsView>)
        }

        // Acionar novamente para garantir foco e reutilização sem criar janela duplicada
        let firstWindow = appDelegate.settingsWindow
        appDelegate.openSettingsWindow()
        XCTAssertTrue(appDelegate.settingsWindow === firstWindow)
    }

    func testSettingsTabEnumProperties() {
        for tab in SettingsTab.allCases {
            XCTAssertFalse(tab.title.isEmpty)
            XCTAssertFalse(tab.systemImage.isEmpty)
            XCTAssertEqual(tab.id, tab.rawValue)
        }
        XCTAssertEqual(SettingsTab.permissions.title, "Permissões")
        XCTAssertEqual(SettingsTab.permissions.systemImage, "lock.shield")
        XCTAssertEqual(SettingsTab.permissions.id, "permissions")
    }

    func testPermissionsSettingsCoordinatorLifecycleAndActions() async {
        let mock = MockPermissionsService()
        var relaunchCalled = false
        let coordinator = PermissionsSettingsCoordinator(
            permissionsService: mock,
            onRelaunchOnboarding: {
                relaunchCalled = true
            }
        )

        XCTAssertFalse(coordinator.allPermissionsAuthorized)
        XCTAssertEqual(coordinator.pendingCount, 2) // mock has mic: notDetermined, speech: authorized, ax: false

        // Testar refreshStatuses
        mock.microphoneStatus = .authorized
        mock.speechStatus = .authorized
        mock.isAccessibilityAuthorized = true
        coordinator.refreshStatuses()

        XCTAssertTrue(coordinator.isMicrophoneAuthorized)
        XCTAssertTrue(coordinator.isSpeechAuthorized)
        XCTAssertTrue(coordinator.isAccessibilityAuthorized)
        XCTAssertTrue(coordinator.allPermissionsAuthorized)
        XCTAssertEqual(coordinator.pendingCount, 0)
        XCTAssertNotNil(coordinator.lastRefreshedAt)

        // Testar pedidos de acesso
        mock.microphoneStatus = .notDetermined
        await coordinator.requestMicrophoneAccess()
        XCTAssertEqual(mock.requestMicrophoneAccessCallCount, 1)

        await coordinator.requestSpeechAccess()
        XCTAssertEqual(mock.requestSpeechAccessCallCount, 1)

        coordinator.requestAccessibilityAccess()
        XCTAssertEqual(mock.checkAccessibilityCallCount, 1)

        // Testar abertura de definições
        coordinator.openSystemSettings(for: .microphone)
        XCTAssertEqual(mock.openSystemSettingsCallCount, 1)
        XCTAssertEqual(mock.lastOpenedSettingsPane, .microphone)

        // Testar polling
        coordinator.startPolling()
        XCTAssertEqual(mock.startPollingCallCount, 1)
        coordinator.stopPolling()
        XCTAssertEqual(mock.stopPollingCallCount, 1)

        // Testar relançamento de onboarding
        coordinator.relaunchOnboarding()
        XCTAssertTrue(relaunchCalled)
    }

    func testSettingsViewWithInitialTabPermissions() {
        let mock = MockPermissionsService()
        var didRelaunch = false
        let settingsView = SettingsView(
            preferencesManager: preferencesManager,
            permissionsService: mock,
            initialTab: .permissions,
            onRelaunchOnboarding: { didRelaunch = true }
        )

        XCTAssertNotNil(settingsView.body)
        XCTAssertEqual(settingsView.selectedTab, .permissions)
        settingsView.onRelaunchOnboarding?()
        XCTAssertTrue(didRelaunch)
    }

    func testAppDelegateOpenSettingsWindowWithSelectedTab() {
        let appDelegate = AppDelegate()
        let mockPermissions = MockPermissionsService()
        appDelegate.setupCoreServices(
            preferencesManager: preferencesManager,
            permissionsService: mockPermissions
        )

        appDelegate.openSettingsWindow(selectedTab: .permissions)
        XCTAssertNotNil(appDelegate.settingsWindow)
        XCTAssertEqual(appDelegate.settingsWindow?.title, "Definições")
    }

    func testKeyCapViewRendering() {
        let keyCap = KeyCapView("⌥", isHighlighted: true)
        XCTAssertNotNil(keyCap.body)
        XCTAssertEqual(keyCap.text, "⌥")
        XCTAssertTrue(keyCap.isHighlighted)
    }

    func testHotkeyRecorderCoordinatorLifecycle() {
        let coordinator = HotkeyRecorderCoordinator(preferencesManager: preferencesManager)
        XCTAssertFalse(coordinator.isRecording)
        XCTAssertEqual(coordinator.currentHotkey, .defaultToggle)

        coordinator.startRecording()
        XCTAssertTrue(coordinator.isRecording)
        XCTAssertTrue(coordinator.isPulsing)

        coordinator.stopRecordingMonitor()
        XCTAssertFalse(coordinator.isPulsing)

        coordinator.cancelRecording()
        XCTAssertFalse(coordinator.isRecording)
        XCTAssertNil(coordinator.errorMessage)
    }

    func testMenuBarManagerOpenSettingsIntegration() {
        let appDelegate = AppDelegate()
        let menuBarManager = MenuBarExtraManager()
        let mockPermissions = MockPermissionsService()
        appDelegate.setupCoreServices(
            preferencesManager: preferencesManager,
            menuBarManager: menuBarManager,
            permissionsService: mockPermissions
        )

        // Acionar onOpenSettings do menuBarManager deve abrir a janela de definições
        menuBarManager.onOpenSettings?()

        if let window = appDelegate.settingsWindow {
            XCTAssertEqual(window.title, "Definições")
        }
    }

    func testDashboardWindowViewSettingsButtonIntegration() {
        var didOpenSettings = false
        let repo = try! PersistenceRepository(inMemory: true)
        let viewModel = DashboardViewModel(repository: repo, autoLoad: false)

        let dashboardView = DashboardWindowView(viewModel: viewModel) {
            didOpenSettings = true
        }
        XCTAssertNotNil(dashboardView.body)

        dashboardView.onOpenSettings?()
        XCTAssertTrue(didOpenSettings)
    }
}
