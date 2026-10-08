import AppKit
import Foundation
import SwiftUI
import Combine

/// Passos do fluxo de Onboarding guiado no primeiro arranque.
public enum OnboardingStep: Int, CaseIterable, Sendable, Comparable {
    case microphone = 1
    case accessibility = 2
    case playground = 3

    public static func < (lhs: OnboardingStep, rhs: OnboardingStep) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    public var title: String {
        switch self {
        case .microphone:
            return "Microfone"
        case .accessibility:
            return "Acessibilidade"
        case .playground:
            return "Experimentar"
        }
    }

    public var stepDescription: String {
        switch self {
        case .microphone:
            return "O Sonotype precisa de acesso ao microfone para capturar e transcrever a sua fala diretamente em memória RAM."
        case .accessibility:
            return "A permissão de acessibilidade permite injetar texto transcrito instantaneamente no cursor de qualquer aplicação."
        case .playground:
            return "Tudo pronto! Experimente falar ou transcrever no campo de testes antes de começar a ditar no seu dia a dia."
        }
    }
}

/// ViewModel responsável pela máquina de estados do assistente de Onboarding.
@MainActor
public final class OnboardingViewModel: ObservableObject, Sendable {
    @Published public var currentStep: OnboardingStep = .microphone
    @Published public var isCompleted: Bool = false
    @Published public var playgroundText: String = ""
    @Published public var isTestingSpeech: Bool = false
    @Published public var errorMessage: String? = nil

    @Published public var isAccessibilityAuthorized: Bool = false
    @Published public var isMicrophoneAuthorized: Bool = false
    @Published public var isSpeechAuthorized: Bool = false

    /// Flag para ambientes de teste unitário onde permissões do SO não podem ser concedidas fisicamente.
    public var bypassPermissionsForTesting: Bool = false

    public let permissionsService: PermissionsServiceProtocol
    public let preferencesManager: PreferencesManager
    public var onDismiss: (@MainActor @Sendable () -> Void)?

    // Callbacks ou closures para interação com speech service no Playground
    public var onStartTestSpeech: (@MainActor @Sendable () -> Void)?
    public var onStopTestSpeech: (@MainActor @Sendable () -> Void)?

    private var cancellables = Set<AnyCancellable>()

    public init(
        permissionsService: PermissionsServiceProtocol = PermissionsService(),
        preferencesManager: PreferencesManager = .shared,
        bypassPermissionsForTesting: Bool = false
    ) {
        self.permissionsService = permissionsService
        self.preferencesManager = preferencesManager
        self.bypassPermissionsForTesting = bypassPermissionsForTesting
        self.isAccessibilityAuthorized = permissionsService.isAccessibilityAuthorized
        self.isMicrophoneAuthorized = permissionsService.isMicrophoneAuthorized
        self.isSpeechAuthorized = permissionsService.isSpeechAuthorized

        setupObservers()
    }

    private func setupObservers() {
        // Escuta quando a aplicação regressa ao primeiro plano para atualizar imediatamente as permissões
        NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self = self else { return }
                self.refreshStatuses()
            }
            .store(in: &cancellables)

        // Se o serviço de permissões for um ObservableObject, propaga mudanças para a view atualizar a UI sem ciclo recursivo
        if let permissionsObservable = permissionsService as? PermissionsService {
            permissionsObservable.objectWillChange
                .receive(on: RunLoop.main)
                .sink { [weak self] _ in
                    guard let self = self else { return }
                    self.syncFromService()
                }
                .store(in: &cancellables)
        }
    }

    /// Sincroniza as variáveis publicadas locais com o estado do serviço apenas quando há alterações.
    @discardableResult
    private func syncFromService() -> Bool {
        let newAx = permissionsService.isAccessibilityAuthorized
        let newMic = permissionsService.isMicrophoneAuthorized
        let newSpeech = permissionsService.isSpeechAuthorized

        var changed = false
        if self.isAccessibilityAuthorized != newAx {
            self.isAccessibilityAuthorized = newAx
            changed = true
        }
        if self.isMicrophoneAuthorized != newMic {
            self.isMicrophoneAuthorized = newMic
            changed = true
        }
        if self.isSpeechAuthorized != newSpeech {
            self.isSpeechAuthorized = newSpeech
            changed = true
        }

        if changed {
            objectWillChange.send()
        }
        return changed
    }

    /// Inicia a monitorização periódica das permissões (ex: ao exibir o ecrã de Onboarding).
    public func startPolling(interval: TimeInterval = 0.5) {
        permissionsService.startPolling(interval: interval)
    }

    /// Interrompe a monitorização periódica das permissões (ex: ao ocultar o ecrã de Onboarding).
    public func stopPolling() {
        permissionsService.stopPolling()
    }

    /// Atualiza imediatamente os estados das permissões de sistema consultando o serviço.
    public func refreshStatuses() {
        permissionsService.refreshStatuses()
        _ = syncFromService()
    }

    /// Força o avanço direto para o playground sem exigir confirmação do TCC/SO.
    public func forceAdvanceToPlayground() {
        currentStep = .playground
    }

    /// Permite a transição direta para qualquer passo específico.
    public func goToStep(_ step: OnboardingStep) {
        currentStep = step
    }

    // MARK: - Validação de Navegação por Passo

    /// Indica se o utilizador pode avançar a partir do passo atual.
    public var canAdvance: Bool {
        if bypassPermissionsForTesting {
            return true
        }

        switch currentStep {
        case .microphone:
            return (isMicrophoneAuthorized || permissionsService.isMicrophoneAuthorized) &&
                   (isSpeechAuthorized || permissionsService.isSpeechAuthorized)
        case .accessibility:
            return isAccessibilityAuthorized || permissionsService.isAccessibilityAuthorized
        case .playground:
            return true
        }
    }

    /// Tenta avançar para o passo seguinte se as validações forem satisfeitas.
    public func nextStep() {
        guard canAdvance else {
            Self.triggerInvalidAttemptFeedback()
            return
        }

        switch currentStep {
        case .microphone:
            currentStep = .accessibility
        case .accessibility:
            currentStep = .playground
        case .playground:
            completeOnboarding()
        }
    }

    /// Retrocede para o passo anterior.
    public func previousStep() {
        switch currentStep {
        case .microphone:
            break
        case .accessibility:
            currentStep = .microphone
        case .playground:
            currentStep = .accessibility
        }
    }

    // MARK: - Ações de Permissão

    /// Solicita acesso ao microfone e ao reconhecimento de fala.
    public func requestMicrophoneAccess() async {
        errorMessage = nil
        let micGranted = await permissionsService.requestMicrophoneAccess()
        let speechGranted = await permissionsService.requestSpeechAccess()
        refreshStatuses()

        if !micGranted && !bypassPermissionsForTesting {
            errorMessage = "Acesso ao microfone recusado. Por favor, ative nas Definições do Sistema."
        } else if !speechGranted && !bypassPermissionsForTesting {
            errorMessage = "Acesso ao reconhecimento de fala pendente ou recusado. Por favor, ative nas Definições do Sistema."
        }
    }

    /// Solicita acesso à API de Acessibilidade.
    public func requestAccessibilityAccess() {
        errorMessage = nil
        let granted = permissionsService.checkAccessibilityPermission(prompt: true)
        refreshStatuses()
        if !granted && !bypassPermissionsForTesting {
            errorMessage = "Acesso à Acessibilidade pendente. Ative o Sonotype nas Definições do Sistema."
        }
    }

    /// Abre o painel correspondente das Definições do Sistema.
    public func openSystemSettings(for pane: SystemPrivacyPane) {
        permissionsService.openSystemSettings(for: pane)
    }

    // MARK: - Passo 3: Playground de Teste

    /// Alterna teste de fala no playground.
    public func toggleSpeechTest() {
        if isTestingSpeech {
            isTestingSpeech = false
            onStopTestSpeech?()
        } else {
            isTestingSpeech = true
            onStartTestSpeech?()
        }
    }

    // MARK: - Finalização do Onboarding

    /// Conclui o onboarding, persiste a preferência e invoca o callback de fecho.
    public func completeOnboarding() {
        preferencesManager.hasCompletedOnboarding = true
        isCompleted = true
        onDismiss?()
    }

    private static func triggerInvalidAttemptFeedback() {
        NSSound.beep()
    }
}
