import AppKit
import AVFoundation
import Combine
import Speech
import SwiftUI

/// Coordenador observável responsável pelo estado reativo das permissões do sistema
/// para o separador de Definições de Permissões (`PermissionsSettingsTabView`).
@MainActor
public final class PermissionsSettingsCoordinator: ObservableObject, Sendable {
    public let permissionsService: PermissionsServiceProtocol
    public var onRelaunchOnboarding: (@MainActor @Sendable () -> Void)?

    @Published public private(set) var isMicrophoneAuthorized: Bool = false
    @Published public private(set) var isSpeechAuthorized: Bool = false
    @Published public private(set) var isAccessibilityAuthorized: Bool = false
    @Published public private(set) var isRefreshing: Bool = false
    @Published public private(set) var lastRefreshedAt: Date?
    @Published public var feedbackTrigger: Int = 0

    private var cancellables = Set<AnyCancellable>()

    public init(
        permissionsService: PermissionsServiceProtocol = PermissionsService(),
        onRelaunchOnboarding: (@MainActor @Sendable () -> Void)? = nil
    ) {
        self.permissionsService = permissionsService
        self.onRelaunchOnboarding = onRelaunchOnboarding
        refreshStatuses()
        setupObservers()
    }

    public var allPermissionsAuthorized: Bool {
        isMicrophoneAuthorized && isSpeechAuthorized && isAccessibilityAuthorized
    }

    public var pendingCount: Int {
        var count = 0
        if !isMicrophoneAuthorized { count += 1 }
        if !isSpeechAuthorized { count += 1 }
        if !isAccessibilityAuthorized { count += 1 }
        return count
    }

    private func setupObservers() {
        // Escutar retorno da aplicação ao primeiro plano para revalidar autorizações imediatamente
        NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.refreshStatuses()
            }
            .store(in: &cancellables)

        // Se o serviço for um ObservableObject concreto, sincroniza o estado através dos publishers das propriedades publicadas
        if let observableService = permissionsService as? PermissionsService {
            observableService.$isAccessibilityAuthorized
                .receive(on: RunLoop.main)
                .sink { [weak self] isAuth in
                    guard let self = self else { return }
                    if self.isAccessibilityAuthorized != isAuth {
                        self.isAccessibilityAuthorized = isAuth
                        self.lastRefreshedAt = Date()
                        self.feedbackTrigger += 1
                    }
                }
                .store(in: &cancellables)

            observableService.$microphoneStatus
                .receive(on: RunLoop.main)
                .sink { [weak self] status in
                    guard let self = self else { return }
                    let isAuth = (status == .authorized)
                    if self.isMicrophoneAuthorized != isAuth {
                        self.isMicrophoneAuthorized = isAuth
                        self.lastRefreshedAt = Date()
                    }
                }
                .store(in: &cancellables)

            observableService.$speechStatus
                .receive(on: RunLoop.main)
                .sink { [weak self] status in
                    guard let self = self else { return }
                    let isAuth = (status == .authorized)
                    if self.isSpeechAuthorized != isAuth {
                        self.isSpeechAuthorized = isAuth
                        self.lastRefreshedAt = Date()
                    }
                }
                .store(in: &cancellables)
        }
    }

    /// Sincroniza as variáveis publicadas com o estado do serviço apenas quando há alterações reais.
    @discardableResult
    private func syncFromService(triggerFeedback: Bool) -> Bool {
        let newMic = permissionsService.isMicrophoneAuthorized
        let newSpeech = permissionsService.isSpeechAuthorized
        let newAx = permissionsService.isAccessibilityAuthorized

        var hasChanged = false
        if self.isMicrophoneAuthorized != newMic {
            self.isMicrophoneAuthorized = newMic
            hasChanged = true
        }
        if self.isSpeechAuthorized != newSpeech {
            self.isSpeechAuthorized = newSpeech
            hasChanged = true
        }
        if self.isAccessibilityAuthorized != newAx {
            self.isAccessibilityAuthorized = newAx
            hasChanged = true
        }

        if hasChanged || self.lastRefreshedAt == nil {
            self.lastRefreshedAt = Date()
            if triggerFeedback && hasChanged {
                self.feedbackTrigger += 1
            }
        }
        return hasChanged
    }

    /// Inicia monitorização periódica das permissões enquanto a aba estiver visível.
    public func startPolling(interval: TimeInterval = 0.5) {
        permissionsService.startPolling(interval: interval)
    }

    /// Interrompe monitorização periódica das permissões.
    public func stopPolling() {
        permissionsService.stopPolling()
    }

    /// Atualiza imediatamente os estados de microfone, fala e acessibilidade.
    public func refreshStatuses() {
        permissionsService.refreshStatuses()
        _ = syncFromService(triggerFeedback: true)
    }

    /// Requisita permissão de acesso ao microfone ao macOS.
    public func requestMicrophoneAccess() async {
        isRefreshing = true
        _ = await permissionsService.requestMicrophoneAccess()
        refreshStatuses()
        isRefreshing = false
    }

    /// Requisita permissão de reconhecimento de fala ao macOS.
    public func requestSpeechAccess() async {
        isRefreshing = true
        _ = await permissionsService.requestSpeechAccess()
        refreshStatuses()
        isRefreshing = false
    }

    /// Requisita prompt de autorização de acessibilidade ao macOS.
    public func requestAccessibilityAccess() {
        _ = permissionsService.checkAccessibilityPermission(prompt: true)
        refreshStatuses()
    }

    /// Abre o painel de privacidade correspondente nas Definições do Sistema do macOS.
    public func openSystemSettings(for pane: SystemPrivacyPane) {
        permissionsService.openSystemSettings(for: pane)
    }

    /// Invoca o relançamento do assistente de onboarding guiado.
    public func relaunchOnboarding() {
        onRelaunchOnboarding?()
    }
}

/// Aba dedicada à Gestão e Auditoria de Permissões do Sistema no painel de Definições (`SettingsTab.permissions`).
/// Concebida de acordo com Apple HIG, tipografia SF Pro calibrada e contraste estrito WCAG 2.1 AA.
@MainActor
public struct PermissionsSettingsTabView: View {
    @ObservedObject public var coordinator: PermissionsSettingsCoordinator

    public init(coordinator: PermissionsSettingsCoordinator) {
        self.coordinator = coordinator
    }

    public init(
        permissionsService: PermissionsServiceProtocol = PermissionsService(),
        onRelaunchOnboarding: (@MainActor @Sendable () -> Void)? = nil
    ) {
        self.coordinator = PermissionsSettingsCoordinator(
            permissionsService: permissionsService,
            onRelaunchOnboarding: onRelaunchOnboarding
        )
    }

    public init(
        permissionsService: PermissionsService,
        onRelaunchOnboarding: (@MainActor @Sendable () -> Void)? = nil
    ) {
        self.coordinator = PermissionsSettingsCoordinator(
            permissionsService: permissionsService,
            onRelaunchOnboarding: onRelaunchOnboarding
        )
    }

    public var permissionsService: PermissionsServiceProtocol {
        coordinator.permissionsService
    }

    public var onRelaunchOnboarding: (@MainActor @Sendable () -> Void)? {
        get { coordinator.onRelaunchOnboarding }
        set { coordinator.onRelaunchOnboarding = newValue }
    }

    public var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                headerBanner

                // Secção 1: Microfone
                microphoneSection

                // Secção 2: Reconhecimento de Fala
                speechRecognitionSection

                // Secção 3: Acessibilidade
                accessibilitySection

                // Secção 4: Ações Globais e Diagnóstico
                globalActionsSection

                // Secção 5: Nota Informativa de Acessibilidade
                accessibilityNoticeCard
            }
            .padding(18)
        }
        .sensoryFeedback(.selection, trigger: coordinator.feedbackTrigger)
        .onAppear {
            coordinator.startPolling()
            coordinator.refreshStatuses()
        }
        .onDisappear {
            coordinator.stopPolling()
        }
    }

    // MARK: - Banner de Introdução

    private var headerBanner: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: coordinator.allPermissionsAuthorized ? "checkmark.shield.fill" : "lock.shield")
                .font(.system(size: 32, weight: .semibold))
                .foregroundStyle(coordinator.allPermissionsAuthorized ? Color.green : Color.accentColor)
                .frame(width: 44, height: 44)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text("Permissões do Sistema")
                        .font(.system(size: 20, weight: .bold, design: .default)) // SF Pro Display >= 20pt
                        .tracking(0.35)
                        .foregroundStyle(Color.primary)

                    Spacer()

                    // Badge de resumo do estado geral
                    HStack(spacing: 5) {
                        Image(systemName: coordinator.allPermissionsAuthorized ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                            .font(.system(size: 11, weight: .semibold))
                        Text(coordinator.allPermissionsAuthorized ? "Totalmente Configurado" : "\(coordinator.pendingCount) Pendente(s)")
                            .font(.system(size: 11, weight: .semibold, design: .default)) // SF Pro Text <= 19pt
                            .tracking(0.0)
                    }
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .foregroundStyle(coordinator.allPermissionsAuthorized ? Color.green : Color.orange)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill((coordinator.allPermissionsAuthorized ? Color.green : Color.orange).opacity(0.12))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder((coordinator.allPermissionsAuthorized ? Color.green : Color.orange).opacity(0.3), lineWidth: 0.5)
                    )
                }

                Text("O Sonotype processa o áudio e a transcrição inteiramente em memória RAM local. São necessárias as três autorizações do macOS para capturar a sua voz, transcrever offline e colar diretamente no cursor.")
                    .font(.system(size: 12, weight: .regular, design: .default)) // SF Pro Text <= 19pt
                    .tracking(-0.05)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color(nsColor: .separatorColor).opacity(0.5), lineWidth: 0.5)
        )
    }

    // MARK: - Secção: Microfone

    private var microphoneSection: some View {
        SettingsCard(
            title: "Microfone",
            icon: "mic.fill",
            footer: "Necessário para capturar o áudio da voz em memória RAM."
        ) {
            HStack(alignment: .center, spacing: 14) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Captação de Áudio")
                        .font(.system(size: 13, weight: .medium, design: .default))
                        .tracking(-0.08)
                        .foregroundStyle(.primary)

                    Text(coordinator.isMicrophoneAuthorized ? "Acesso concedido para entrada de microfone" : "Acesso ao microfone ainda não autorizado")
                        .font(.system(size: 11, weight: .regular, design: .default))
                        .tracking(0.06)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 12)

                HStack(spacing: 8) {
                    statusBadge(isAuthorized: coordinator.isMicrophoneAuthorized)

                    if !coordinator.isMicrophoneAuthorized {
                        Button {
                            Task {
                                await coordinator.requestMicrophoneAccess()
                            }
                        } label: {
                            Text("Autorizar")
                                .font(.system(size: 12, weight: .medium))
                                .tracking(-0.08)
                                .frame(minWidth: 70, minHeight: 28)
                        }
                        .buttonStyle(.borderedProminent)
                        .frame(minHeight: 44) // Alvo ergonómico >= 44pt
                        .help("Solicitar permissão de acesso ao microfone")
                    }

                    Button {
                        coordinator.openSystemSettings(for: .microphone)
                    } label: {
                        Text("Abrir Definições")
                            .font(.system(size: 12, weight: .regular))
                            .tracking(-0.08)
                            .frame(minWidth: 100, minHeight: 28)
                    }
                    .buttonStyle(.bordered)
                    .frame(minHeight: 44) // Alvo ergonómico >= 44pt
                    .help("Abrir painel de Microfone nas Definições do Sistema")
                }
            }
            .frame(minHeight: 44)
        }
    }

    // MARK: - Secção: Reconhecimento de Fala

    private var speechRecognitionSection: some View {
        SettingsCard(
            title: "Reconhecimento de Fala",
            icon: "waveform",
            footer: "Necessário para a Apple Speech transcrever a fala no dispositivo."
        ) {
            HStack(alignment: .center, spacing: 14) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Motor de Transcrição Apple Speech")
                        .font(.system(size: 13, weight: .medium, design: .default))
                        .tracking(-0.08)
                        .foregroundStyle(.primary)

                    Text(coordinator.isSpeechAuthorized ? "Autorizado para transcrição de fala no dispositivo" : "Acesso ao motor de fala pendente")
                        .font(.system(size: 11, weight: .regular, design: .default))
                        .tracking(0.06)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 12)

                HStack(spacing: 8) {
                    statusBadge(isAuthorized: coordinator.isSpeechAuthorized)

                    if !coordinator.isSpeechAuthorized {
                        Button {
                            Task {
                                await coordinator.requestSpeechAccess()
                            }
                        } label: {
                            Text("Autorizar")
                                .font(.system(size: 12, weight: .medium))
                                .tracking(-0.08)
                                .frame(minWidth: 70, minHeight: 28)
                        }
                        .buttonStyle(.borderedProminent)
                        .frame(minHeight: 44) // Alvo ergonómico >= 44pt
                        .help("Solicitar permissão de reconhecimento de fala")
                    }

                    Button {
                        coordinator.openSystemSettings(for: .speechRecognition)
                    } label: {
                        Text("Abrir Definições")
                            .font(.system(size: 12, weight: .regular))
                            .tracking(-0.08)
                            .frame(minWidth: 100, minHeight: 28)
                    }
                    .buttonStyle(.bordered)
                    .frame(minHeight: 44) // Alvo ergonómico >= 44pt
                    .help("Abrir painel de Reconhecimento de Fala nas Definições do Sistema")
                }
            }
            .frame(minHeight: 44)
        }
    }

    // MARK: - Secção: Acessibilidade

    private var accessibilitySection: some View {
        SettingsCard(
            title: "Acessibilidade",
            icon: "accessibility",
            footer: "Necessário para injetar o texto transcrito diretamente no cursor de qualquer aplicação."
        ) {
            HStack(alignment: .center, spacing: 14) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Injeção Direta no Cursor")
                        .font(.system(size: 13, weight: .medium, design: .default))
                        .tracking(-0.08)
                        .foregroundStyle(.primary)

                    Text(coordinator.isAccessibilityAuthorized ? "Autorizado para emular digitação via System Events" : "Autorização necessária para colar texto automaticamente")
                        .font(.system(size: 11, weight: .regular, design: .default))
                        .tracking(0.06)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 12)

                HStack(spacing: 8) {
                    statusBadge(isAuthorized: coordinator.isAccessibilityAuthorized)

                    if !coordinator.isAccessibilityAuthorized {
                        Button {
                            coordinator.requestAccessibilityAccess()
                        } label: {
                            Text("Solicitar Acesso")
                                .font(.system(size: 12, weight: .medium))
                                .tracking(-0.08)
                                .frame(minWidth: 95, minHeight: 28)
                        }
                        .buttonStyle(.borderedProminent)
                        .frame(minHeight: 44) // Alvo ergonómico >= 44pt
                        .help("Exibir diálogo do macOS a solicitar Acessibilidade")
                    }

                    Button {
                        coordinator.openSystemSettings(for: .accessibility)
                    } label: {
                        Text("Abrir Definições")
                            .font(.system(size: 12, weight: .regular))
                            .tracking(-0.08)
                            .frame(minWidth: 100, minHeight: 28)
                    }
                    .buttonStyle(.bordered)
                    .frame(minHeight: 44) // Alvo ergonómico >= 44pt
                    .help("Abrir painel de Acessibilidade nas Definições do Sistema")
                }
            }
            .frame(minHeight: 44)
        }
    }

    // MARK: - Secção: Ações Globais e Diagnóstico

    private var globalActionsSection: some View {
        SettingsCard(
            title: "Ações de Diagnóstico e Auditoria",
            icon: "wrench.and.screwdriver"
        ) {
            HStack(spacing: 12) {
                Button {
                    coordinator.refreshStatuses()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 12, weight: .medium))
                        Text("Verificar Novamente")
                            .font(.system(size: 12, weight: .medium, design: .default))
                            .tracking(-0.08)
                    }
                    .frame(minWidth: 150, minHeight: 28)
                }
                .buttonStyle(.bordered)
                .frame(minHeight: 44) // Alvo ergonómico Apple HIG >= 44x44pt
                .help("Reconsultar o estado atual de todas as permissões no macOS")

                Spacer()

                Button {
                    coordinator.relaunchOnboarding()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 12, weight: .medium))
                        Text("Reabrir Assistente de Onboarding")
                            .font(.system(size: 12, weight: .medium, design: .default))
                            .tracking(-0.08)
                    }
                    .frame(minWidth: 200, minHeight: 28)
                }
                .buttonStyle(.bordered)
                .frame(minHeight: 44) // Alvo ergonómico Apple HIG >= 44x44pt
                .disabled(coordinator.onRelaunchOnboarding == nil)
                .help("Abrir o assistente guiado de 3 passos e campo de testes")
            }
            .frame(minHeight: 44)
        }
    }

    // MARK: - Secção: Nota de Acessibilidade macOS

    private var accessibilityNoticeCard: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "info.circle")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.accentColor)
                .padding(.top, 1)
                .accessibilityHidden(true)

            Text("Nota de Acessibilidade macOS: Se o Sonotype já aparecer ativado nas Definições do Sistema mas o estado não atualizar, desative e reative o comutador nas Definições do Sistema uma vez para atualizar o registo do macOS.")
                .font(.system(size: 11, weight: .regular, design: .default)) // SF Pro Text <= 19pt
                .tracking(0.06)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Color(nsColor: .separatorColor).opacity(0.4), lineWidth: 0.5)
        )
    }

    // MARK: - Componente Auxiliar: Badge de Estado

    private func statusBadge(isAuthorized: Bool) -> some View {
        HStack(spacing: 4) {
            Image(systemName: isAuthorized ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .font(.system(size: 10, weight: .semibold))
            Text(isAuthorized ? "Autorizado" : "Pendente")
                .font(.system(size: 11, weight: .semibold, design: .default)) // SF Pro Text <= 19pt
                .tracking(0.0)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .foregroundStyle(isAuthorized ? Color.green : Color.orange)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill((isAuthorized ? Color.green : Color.orange).opacity(0.12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .strokeBorder((isAuthorized ? Color.green : Color.orange).opacity(0.3), lineWidth: 0.5)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(isAuthorized ? "Estado: Autorizado" : "Estado: Pendente")
    }
}
