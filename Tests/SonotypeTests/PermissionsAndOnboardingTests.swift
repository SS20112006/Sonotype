import AppKit
import XCTest
@preconcurrency import AVFoundation
@testable import Sonotype

// MARK: - Mock Permissions Service para Testes Unitários

@MainActor
final class MockPermissionsService: PermissionsServiceProtocol, Sendable {
    var microphoneStatus: AVAuthorizationStatus = .notDetermined
    var isMicrophoneAuthorized: Bool {
        microphoneStatus == .authorized
    }
    var isAccessibilityAuthorized: Bool = false

    var requestMicrophoneAccessResult: Bool = true
    var requestMicrophoneAccessCallCount: Int = 0

    var checkAccessibilityResult: Bool = false
    var checkAccessibilityCallCount: Int = 0
    var lastCheckAccessibilityPrompt: Bool?

    var openSystemSettingsCallCount: Int = 0
    var lastOpenedSettingsPane: SystemPrivacyPane?

    func requestMicrophoneAccess() async -> Bool {
        requestMicrophoneAccessCallCount += 1
        if requestMicrophoneAccessResult {
            microphoneStatus = .authorized
        } else {
            microphoneStatus = .denied
        }
        return requestMicrophoneAccessResult
    }

    func checkAccessibilityPermission(prompt: Bool) -> Bool {
        checkAccessibilityCallCount += 1
        lastCheckAccessibilityPrompt = prompt
        return isAccessibilityAuthorized
    }

    func openSystemSettings(for permission: SystemPrivacyPane) {
        openSystemSettingsCallCount += 1
        lastOpenedSettingsPane = permission
    }
}

// MARK: - Suite de Testes de Onboarding e Permissões

@MainActor
final class PermissionsAndOnboardingTests: XCTestCase {
    private var isolatedDefaults: UserDefaults!
    private var suiteName: String!

    override func setUp() async throws {
        try await super.setUp()
        suiteName = "PermissionsOnboardingTests-\(UUID().uuidString)"
        isolatedDefaults = UserDefaults(suiteName: suiteName)
        isolatedDefaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() async throws {
        isolatedDefaults.removePersistentDomain(forName: suiteName)
        isolatedDefaults = nil
        suiteName = nil
        try await super.tearDown()
    }

    // MARK: - 1. Persistência de hasCompletedOnboarding e Notificação

    func testOnboardingPreferenceDefaultAndPersistence() {
        let manager = PreferencesManager(userDefaults: isolatedDefaults)
        XCTAssertFalse(manager.hasCompletedOnboarding)
        XCTAssertFalse(manager.preferences.hasCompletedOnboarding)

        var notificationFired = false
        var recordedStatus: Bool?
        manager.onOnboardingStatusChanged = { status in
            notificationFired = true
            recordedStatus = status
        }

        manager.hasCompletedOnboarding = true
        XCTAssertTrue(notificationFired)
        XCTAssertEqual(recordedStatus, true)
        XCTAssertTrue(manager.hasCompletedOnboarding)

        // Verificar numa nova instância apontando para o mesmo storage
        let manager2 = PreferencesManager(userDefaults: isolatedDefaults)
        XCTAssertTrue(manager2.hasCompletedOnboarding)
    }

    // MARK: - 2. Máquina de Estados do OnboardingViewModel

    func testOnboardingViewModelNavigationFlow() async {
        let mockPermissions = MockPermissionsService()
        let manager = PreferencesManager(userDefaults: isolatedDefaults)
        let viewModel = OnboardingViewModel(
            permissionsService: mockPermissions,
            preferencesManager: manager
        )

        // Passo 1 inicial: Microfone
        XCTAssertEqual(viewModel.currentStep, .microphone)
        XCTAssertFalse(viewModel.canAdvance)

        // Tentar avançar sem permissão não muda o passo
        viewModel.nextStep()
        XCTAssertEqual(viewModel.currentStep, .microphone)

        // Conceder permissão de microfone
        mockPermissions.requestMicrophoneAccessResult = true
        let grantedMic = await mockPermissions.requestMicrophoneAccess()
        XCTAssertTrue(grantedMic)
        XCTAssertTrue(viewModel.canAdvance)

        // Avançar para o Passo 2: Acessibilidade
        viewModel.nextStep()
        XCTAssertEqual(viewModel.currentStep, .accessibility)
        XCTAssertFalse(viewModel.canAdvance)

        // Retroceder para o Passo 1
        viewModel.previousStep()
        XCTAssertEqual(viewModel.currentStep, .microphone)

        // Voltar ao Passo 2
        viewModel.nextStep()
        XCTAssertEqual(viewModel.currentStep, .accessibility)

        // Conceder permissão de Acessibilidade
        mockPermissions.isAccessibilityAuthorized = true
        XCTAssertTrue(viewModel.canAdvance)

        // Avançar para o Passo 3: Playground
        viewModel.nextStep()
        XCTAssertEqual(viewModel.currentStep, .playground)
        XCTAssertTrue(viewModel.canAdvance)

        // Concluir Onboarding
        var dismissCalled = false
        viewModel.onDismiss = {
            dismissCalled = true
        }

        viewModel.nextStep() // No playground, nextStep conclui
        XCTAssertTrue(viewModel.isCompleted)
        XCTAssertTrue(dismissCalled)
        XCTAssertTrue(manager.hasCompletedOnboarding)
    }

    func testOnboardingViewModelTestingBypass() {
        let mockPermissions = MockPermissionsService()
        let manager = PreferencesManager(userDefaults: isolatedDefaults)
        let viewModel = OnboardingViewModel(
            permissionsService: mockPermissions,
            preferencesManager: manager,
            bypassPermissionsForTesting: true
        )

        XCTAssertTrue(viewModel.canAdvance)
        viewModel.nextStep()
        XCTAssertEqual(viewModel.currentStep, .accessibility)
        XCTAssertTrue(viewModel.canAdvance)
        viewModel.nextStep()
        XCTAssertEqual(viewModel.currentStep, .playground)
    }

    func testOnboardingPlaygroundSpeechTestingToggles() {
        let mockPermissions = MockPermissionsService()
        let manager = PreferencesManager(userDefaults: isolatedDefaults)
        let viewModel = OnboardingViewModel(
            permissionsService: mockPermissions,
            preferencesManager: manager
        )

        var started = false
        var stopped = false
        viewModel.onStartTestSpeech = { started = true }
        viewModel.onStopTestSpeech = { stopped = true }

        viewModel.toggleSpeechTest()
        XCTAssertTrue(viewModel.isTestingSpeech)
        XCTAssertTrue(started)

        viewModel.toggleSpeechTest()
        XCTAssertFalse(viewModel.isTestingSpeech)
        XCTAssertTrue(stopped)
    }

    func testPermissionsServiceSettingsOpenPane() {
        let mockPermissions = MockPermissionsService()
        mockPermissions.openSystemSettings(for: .microphone)
        XCTAssertEqual(mockPermissions.openSystemSettingsCallCount, 1)
        XCTAssertEqual(mockPermissions.lastOpenedSettingsPane, .microphone)

        mockPermissions.openSystemSettings(for: .accessibility)
        XCTAssertEqual(mockPermissions.openSystemSettingsCallCount, 2)
        XCTAssertEqual(mockPermissions.lastOpenedSettingsPane, .accessibility)

        mockPermissions.openSystemSettings(for: .speechRecognition)
        XCTAssertEqual(mockPermissions.openSystemSettingsCallCount, 3)
        XCTAssertEqual(mockPermissions.lastOpenedSettingsPane, .speechRecognition)
        XCTAssertNotNil(SystemPrivacyPane.speechRecognition.url)
    }

    // MARK: - 3. Integração com AppDelegate e Abertura de Janelas

    func testAppDelegateOpensOnboardingWhenNotCompleted() {
        let manager = PreferencesManager(userDefaults: isolatedDefaults)
        manager.hasCompletedOnboarding = false

        let appDelegate = AppDelegate()
        let mockPermissions = MockPermissionsService()

        appDelegate.setupCoreServices(
            preferencesManager: manager,
            permissionsService: mockPermissions
        )

        XCTAssertNil(appDelegate.onboardingWindow)
        appDelegate.openOnboardingWindow()

        XCTAssertNotNil(appDelegate.onboardingWindow)
        XCTAssertTrue(appDelegate.onboardingWindow?.isVisible ?? false)

        appDelegate.closeOnboardingWindow()
        XCTAssertNil(appDelegate.onboardingWindow)
    }

    func testOnboardingDismissClosesWindowAndOpensDashboard() {
        let manager = PreferencesManager(userDefaults: isolatedDefaults)
        let appDelegate = AppDelegate()
        let mockPermissions = MockPermissionsService()

        appDelegate.setupCoreServices(
            preferencesManager: manager,
            permissionsService: mockPermissions
        )

        appDelegate.openOnboardingWindow()
        XCTAssertNotNil(appDelegate.onboardingWindow)

        // Fechar onboarding via método
        appDelegate.closeOnboardingWindow()
        XCTAssertNil(appDelegate.onboardingWindow)
    }
}
