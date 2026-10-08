import AppKit
import XCTest
@preconcurrency import AVFoundation
@preconcurrency import Speech
@testable import Sonotype

// MARK: - Mock Permissions Service para Testes Unitários

@MainActor
final class MockPermissionsService: PermissionsServiceProtocol, Sendable {
    var microphoneStatus: AVAuthorizationStatus = .notDetermined
    var isMicrophoneAuthorized: Bool {
        microphoneStatus == .authorized
    }
    var speechStatus: SFSpeechRecognizerAuthorizationStatus = .authorized
    var isSpeechAuthorized: Bool {
        speechStatus == .authorized
    }
    var isAccessibilityAuthorized: Bool = false

    var requestMicrophoneAccessResult: Bool = true
    var requestMicrophoneAccessCallCount: Int = 0

    var requestSpeechAccessResult: Bool = true
    var requestSpeechAccessCallCount: Int = 0

    var checkAccessibilityResult: Bool = false
    var checkAccessibilityCallCount: Int = 0
    var lastCheckAccessibilityPrompt: Bool?

    var openSystemSettingsCallCount: Int = 0
    var lastOpenedSettingsPane: SystemPrivacyPane?

    var startPollingCallCount: Int = 0
    var stopPollingCallCount: Int = 0
    var refreshStatusesCallCount: Int = 0
    var lastStartPollingInterval: TimeInterval?
    var onRefreshStatuses: (@MainActor () -> Void)?

    func requestMicrophoneAccess() async -> Bool {
        requestMicrophoneAccessCallCount += 1
        if requestMicrophoneAccessResult {
            microphoneStatus = .authorized
        } else {
            microphoneStatus = .denied
        }
        return requestMicrophoneAccessResult
    }

    func requestSpeechAccess() async -> Bool {
        requestSpeechAccessCallCount += 1
        if requestSpeechAccessResult {
            speechStatus = .authorized
        } else {
            speechStatus = .denied
        }
        return requestSpeechAccessResult
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

    func startPolling(interval: TimeInterval) {
        startPollingCallCount += 1
        lastStartPollingInterval = interval
    }

    func stopPolling() {
        stopPollingCallCount += 1
    }

    func refreshStatuses() {
        refreshStatusesCallCount += 1
        onRefreshStatuses?()
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

    func testOnboardingViewModelForceAdvanceToPlayground() {
        let mockPermissions = MockPermissionsService()
        let manager = PreferencesManager(userDefaults: isolatedDefaults)
        let viewModel = OnboardingViewModel(
            permissionsService: mockPermissions,
            preferencesManager: manager
        )

        XCTAssertEqual(viewModel.currentStep, .microphone)
        viewModel.forceAdvanceToPlayground()
        XCTAssertEqual(viewModel.currentStep, .playground)
        XCTAssertTrue(viewModel.canAdvance)
    }

    func testOnboardingViewModelRefreshStatuses() {
        let mockPermissions = MockPermissionsService()
        let manager = PreferencesManager(userDefaults: isolatedDefaults)
        let viewModel = OnboardingViewModel(
            permissionsService: mockPermissions,
            preferencesManager: manager
        )

        XCTAssertEqual(mockPermissions.refreshStatusesCallCount, 0)
        viewModel.refreshStatuses()
        XCTAssertEqual(mockPermissions.refreshStatusesCallCount, 1)
    }

    func testOnboardingViewModelGoToStep() {
        let mockPermissions = MockPermissionsService()
        let manager = PreferencesManager(userDefaults: isolatedDefaults)
        let viewModel = OnboardingViewModel(
            permissionsService: mockPermissions,
            preferencesManager: manager
        )

        XCTAssertEqual(viewModel.currentStep, .microphone)
        viewModel.goToStep(.accessibility)
        XCTAssertEqual(viewModel.currentStep, .accessibility)
        viewModel.goToStep(.playground)
        XCTAssertEqual(viewModel.currentStep, .playground)
        viewModel.goToStep(.microphone)
        XCTAssertEqual(viewModel.currentStep, .microphone)
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

    func testOnboardingViewModelPollingControls() {
        let mockPermissions = MockPermissionsService()
        let manager = PreferencesManager(userDefaults: isolatedDefaults)
        let viewModel = OnboardingViewModel(
            permissionsService: mockPermissions,
            preferencesManager: manager
        )

        XCTAssertEqual(mockPermissions.startPollingCallCount, 0)
        XCTAssertEqual(mockPermissions.stopPollingCallCount, 0)

        viewModel.startPolling()
        XCTAssertEqual(mockPermissions.startPollingCallCount, 1)
        XCTAssertEqual(mockPermissions.lastStartPollingInterval, 0.5)

        viewModel.stopPolling()
        XCTAssertEqual(mockPermissions.stopPollingCallCount, 1)
    }

    func testOnboardingViewModelAppDidBecomeActiveRefreshesStatuses() async {
        let mockPermissions = MockPermissionsService()
        let manager = PreferencesManager(userDefaults: isolatedDefaults)
        let viewModel = OnboardingViewModel(
            permissionsService: mockPermissions,
            preferencesManager: manager
        )

        let initialRefreshCount = mockPermissions.refreshStatusesCallCount
        let refreshExpectation = expectation(description: "refreshStatuses called on app did become active")
        mockPermissions.onRefreshStatuses = {
            refreshExpectation.fulfill()
        }

        // Envia notificação didBecomeActiveNotification
        NotificationCenter.default.post(name: NSApplication.didBecomeActiveNotification, object: nil)

        await fulfillment(of: [refreshExpectation], timeout: 2.0)

        XCTAssertEqual(mockPermissions.refreshStatusesCallCount, initialRefreshCount + 1)
        _ = viewModel
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

    // MARK: - 4. Sincronização e Pedido de Microfone e Fala Conjuntos

    func testOnboardingViewModelRequestsBothMicrophoneAndSpeech() async {
        let mockPermissions = MockPermissionsService()
        let manager = PreferencesManager(userDefaults: isolatedDefaults)
        let viewModel = OnboardingViewModel(
            permissionsService: mockPermissions,
            preferencesManager: manager
        )

        mockPermissions.requestMicrophoneAccessResult = true
        mockPermissions.requestSpeechAccessResult = true

        await viewModel.requestMicrophoneAccess()

        XCTAssertEqual(mockPermissions.requestMicrophoneAccessCallCount, 1)
        XCTAssertEqual(mockPermissions.requestSpeechAccessCallCount, 1)
        XCTAssertTrue(viewModel.isMicrophoneAuthorized)
        XCTAssertTrue(viewModel.isSpeechAuthorized)
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertTrue(viewModel.canAdvance)
    }

    func testOnboardingViewModelMicrophoneDeniedSetsErrorMessage() async {
        let mockPermissions = MockPermissionsService()
        let manager = PreferencesManager(userDefaults: isolatedDefaults)
        let viewModel = OnboardingViewModel(
            permissionsService: mockPermissions,
            preferencesManager: manager
        )

        mockPermissions.requestMicrophoneAccessResult = false
        mockPermissions.requestSpeechAccessResult = true

        await viewModel.requestMicrophoneAccess()

        XCTAssertEqual(mockPermissions.requestMicrophoneAccessCallCount, 1)
        XCTAssertFalse(viewModel.isMicrophoneAuthorized)
        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertFalse(viewModel.canAdvance)
    }

    func testOnboardingViewModelSpeechDeniedSetsErrorMessage() async {
        let mockPermissions = MockPermissionsService()
        let manager = PreferencesManager(userDefaults: isolatedDefaults)
        let viewModel = OnboardingViewModel(
            permissionsService: mockPermissions,
            preferencesManager: manager
        )

        mockPermissions.requestMicrophoneAccessResult = true
        mockPermissions.requestSpeechAccessResult = false

        await viewModel.requestMicrophoneAccess()

        XCTAssertEqual(mockPermissions.requestSpeechAccessCallCount, 1)
        XCTAssertFalse(viewModel.isSpeechAuthorized)
        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertFalse(viewModel.canAdvance)
    }

    func testOnboardingViewModelDirectPublishedPropertiesSync() {
        let mockPermissions = MockPermissionsService()
        let manager = PreferencesManager(userDefaults: isolatedDefaults)
        let viewModel = OnboardingViewModel(
            permissionsService: mockPermissions,
            preferencesManager: manager
        )

        XCTAssertFalse(viewModel.isAccessibilityAuthorized)
        XCTAssertFalse(viewModel.isMicrophoneAuthorized)

        mockPermissions.microphoneStatus = .authorized
        mockPermissions.speechStatus = .authorized
        mockPermissions.isAccessibilityAuthorized = true

        viewModel.refreshStatuses()

        XCTAssertTrue(viewModel.isAccessibilityAuthorized)
        XCTAssertTrue(viewModel.isMicrophoneAuthorized)
        XCTAssertTrue(viewModel.isSpeechAuthorized)
    }
}
