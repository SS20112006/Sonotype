import AppKit
import SwiftUI
import os

/// Delegado principal do ciclo de vida da aplicação Sonotype no macOS.
/// Inicializa o motor de sessão, HUD flutuante, barra de menus e controlo híbrido da Dock.
@MainActor
public final class AppDelegate: NSObject, NSApplicationDelegate, Sendable {
    private static let logger = Logger(subsystem: "com.sonotype.app", category: "AppDelegate")

    public private(set) var preferencesManager: PreferencesManager?
    public private(set) var coordinator: RecordingSessionCoordinator?
    public private(set) var hudController: HUDController?
    public private(set) var menuBarManager: MenuBarExtraManager?
    public private(set) var dockCoordinator: DockVisibilityCoordinator?
    public private(set) var repository: PersistenceRepository?
    public private(set) var audioCaptureService: AudioCaptureService?
    public private(set) var speechService: SpeechRecognitionService?
    public private(set) var languageDetector: LanguageDetectorService?
    public private(set) var postProcessor: TextPostProcessor?
    public private(set) var injectionService: TextInjectionService?
    public private(set) var settingsWindow: NSWindow?

    public var activeLanguage: SpeechLanguage = .portuguesePT
    public var currentTranscription: String = ""
    public private(set) var sessionStartTime: Date?

    public func applicationDidFinishLaunching(_ notification: Notification) {
        setupCoreServices()
    }

    public func setupCoreServices(
        preferencesManager: PreferencesManager = PreferencesManager(),
        coordinator: RecordingSessionCoordinator? = nil,
        hudController: HUDController = HUDController(),
        dockCoordinator: DockVisibilityCoordinator? = nil,
        menuBarManager: MenuBarExtraManager = MenuBarExtraManager(),
        repository: PersistenceRepository = .shared,
        audioCaptureService: AudioCaptureService = AudioCaptureService(),
        speechService: SpeechRecognitionService = SpeechRecognitionService(),
        languageDetector: LanguageDetectorService = LanguageDetectorService(),
        postProcessor: TextPostProcessor = TextPostProcessor(),
        injectionService: TextInjectionService = TextInjectionService()
    ) {
        self.preferencesManager = preferencesManager

        // Inicializar ou sincronizar dockCoordinator com o modo das preferências
        let finalDockCoordinator: DockVisibilityCoordinator
        if let dockCoordinator = dockCoordinator {
            finalDockCoordinator = dockCoordinator
            finalDockCoordinator.setMode(preferencesManager.preferences.dockVisibilityMode)
        } else {
            finalDockCoordinator = DockVisibilityCoordinator(initialMode: preferencesManager.preferences.dockVisibilityMode)
        }
        self.dockCoordinator = finalDockCoordinator

        // Inicializar ou configurar coordinator com as preferências
        let finalCoordinator: RecordingSessionCoordinator
        if let coordinator = coordinator {
            finalCoordinator = coordinator
            finalCoordinator.silenceManager.timeoutDuration = preferencesManager.preferences.silenceTimeoutSeconds
            finalCoordinator.setSoundEnabled(preferencesManager.preferences.soundFeedbackEnabled)
            finalCoordinator.setHotkey(preferencesManager.preferences.globalHotkey)
            finalCoordinator.stateMachine.hotkeyMode = (preferencesManager.preferences.triggerMode == .pushToTalk ? .pushToTalk : .toggle)
        } else {
            let silenceManager = SilenceTimeoutManager(timeoutDuration: preferencesManager.preferences.silenceTimeoutSeconds)
            let soundPlayer = SystemFeedbackSoundPlayer(isEnabled: preferencesManager.preferences.soundFeedbackEnabled)
            let hotkeyManager = SystemGlobalHotkeyManager(hotkey: preferencesManager.preferences.globalHotkey)
            let stateMachine = RecordingStateMachine(hotkeyMode: preferencesManager.preferences.triggerMode == .pushToTalk ? .pushToTalk : .toggle)
            finalCoordinator = RecordingSessionCoordinator(
                stateMachine: stateMachine,
                hotkeyManager: hotkeyManager,
                silenceManager: silenceManager,
                soundPlayer: soundPlayer
            )
        }
        self.coordinator = finalCoordinator

        self.hudController = hudController
        self.menuBarManager = menuBarManager
        self.repository = repository
        self.audioCaptureService = audioCaptureService
        self.speechService = speechService
        self.languageDetector = languageDetector
        self.postProcessor = postProcessor
        self.injectionService = injectionService

        // Resolução inicial do idioma com base em LanguageSelectionMode
        switch preferencesManager.preferences.languageSelectionMode {
        case .autoDetect:
            self.activeLanguage = languageDetector.defaultLanguage
        case .fixedPT:
            self.activeLanguage = .portuguesePT
        case .fixedEN:
            self.activeLanguage = .englishUS
        }

        // Conectar callbacks do PreferencesManager aos serviços ativos
        let existingDockHandler = preferencesManager.onDockModeChanged
        preferencesManager.onDockModeChanged = { [weak finalDockCoordinator] newMode in
            finalDockCoordinator?.setMode(newMode)
            existingDockHandler?(newMode)
        }

        let existingSilenceHandler = preferencesManager.onSilenceTimeoutChanged
        preferencesManager.onSilenceTimeoutChanged = { [weak finalCoordinator] newTimeout in
            finalCoordinator?.silenceManager.timeoutDuration = newTimeout
            existingSilenceHandler?(newTimeout)
        }

        let existingSoundHandler = preferencesManager.onSoundFeedbackChanged
        preferencesManager.onSoundFeedbackChanged = { [weak finalCoordinator] isEnabled in
            finalCoordinator?.setSoundEnabled(isEnabled)
            existingSoundHandler?(isEnabled)
        }

        let existingHotkeyHandler = preferencesManager.onHotkeyChanged
        preferencesManager.onHotkeyChanged = { [weak self, weak finalCoordinator, weak menuBarManager] newHotkey in
            finalCoordinator?.setHotkey(newHotkey)
            if let self = self {
                let badge = self.preferencesManager?.preferences.languageSelectionMode.badgeTitle ?? "PT / EN"
                menuBarManager?.updateDetails(language: badge, hotkey: newHotkey.displayString)
            }
            existingHotkeyHandler?(newHotkey)
        }

        let existingLanguageHandler = preferencesManager.onLanguageModeChanged
        preferencesManager.onLanguageModeChanged = { [weak self, weak menuBarManager] newMode in
            guard let self = self else { return }
            switch newMode {
            case .autoDetect:
                self.activeLanguage = self.languageDetector?.defaultLanguage ?? .portuguesePT
            case .fixedPT:
                self.activeLanguage = .portuguesePT
            case .fixedEN:
                self.activeLanguage = .englishUS
            }
            let hotkeyStr = self.preferencesManager?.preferences.globalHotkey.displayString ?? "⌥ Espaço"
            menuBarManager?.updateDetails(language: newMode.badgeTitle, hotkey: hotkeyStr)
            existingLanguageHandler?(newMode)
        }

        let existingTriggerHandler = preferencesManager.onTriggerModeChanged
        preferencesManager.onTriggerModeChanged = { [weak finalCoordinator] newMode in
            finalCoordinator?.stateMachine.hotkeyMode = (newMode == .pushToTalk ? .pushToTalk : .toggle)
            existingTriggerHandler?(newMode)
        }

        // Atualizar estado inicial da barra de menus
        menuBarManager.updateDetails(
            language: preferencesManager.preferences.languageSelectionMode.badgeTitle,
            hotkey: preferencesManager.preferences.globalHotkey.displayString
        )

        // 1. Pipeline de gravação e transcrição no Coordenador
        let originalStart = finalCoordinator.onStartRecording
        finalCoordinator.onStartRecording = { [weak self, weak finalCoordinator, weak audioCaptureService, weak speechService] in
            guard let self = self,
                  let coordinator = finalCoordinator,
                  let audioCaptureService = audioCaptureService,
                  let speechService = speechService else { return }

            self.currentTranscription = ""
            self.sessionStartTime = Date()

            // Respeitar LanguageSelectionMode ao iniciar a gravação
            let langMode = self.preferencesManager?.preferences.languageSelectionMode ?? .autoDetect
            switch langMode {
            case .autoDetect:
                self.activeLanguage = self.languageDetector?.defaultLanguage ?? .portuguesePT
            case .fixedPT:
                self.activeLanguage = .portuguesePT
            case .fixedEN:
                self.activeLanguage = .englishUS
            }

            // Iniciar reconhecimento de voz para o idioma ativo
            do {
                try speechService.startRecognition(
                    language: self.activeLanguage,
                    onTranscriptionUpdate: { [weak self] text, _ in
                        if Thread.isMainThread {
                            MainActor.assumeIsolated {
                                self?.currentTranscription = text
                            }
                        } else {
                            Task { @MainActor in
                                self?.currentTranscription = text
                            }
                        }
                    },
                    onError: { [weak coordinator] error in
                        if Thread.isMainThread {
                            MainActor.assumeIsolated {
                                coordinator?.handleError(error)
                            }
                        } else {
                            Task { @MainActor in
                                coordinator?.handleError(error)
                            }
                        }
                    }
                )
            } catch {
                Self.logger.error("Falha ao iniciar reconhecimento de voz: \(error.localizedDescription, privacy: .public)")
                coordinator.handleError(error)
                return
            }

            // Conectar buffers capturados em RAM diretamente ao reconhecimento de fala
            audioCaptureService.onBufferCaptured = { [weak speechService] buffer in
                speechService?.appendBuffer(buffer)
            }

            // Conectar amplitude de áudio ao coordenador e monitor de silêncio
            audioCaptureService.onAmplitudeChanged = { [weak coordinator] amplitude in
                if Thread.isMainThread {
                    MainActor.assumeIsolated {
                        coordinator?.feedAudioAmplitude(amplitude)
                    }
                } else {
                    Task { @MainActor in
                        coordinator?.feedAudioAmplitude(amplitude)
                    }
                }
            }

            audioCaptureService.onError = { [weak coordinator] error in
                if Thread.isMainThread {
                    MainActor.assumeIsolated {
                        coordinator?.handleError(error)
                    }
                } else {
                    Task { @MainActor in
                        coordinator?.handleError(error)
                    }
                }
            }

            // Iniciar captação de áudio do microfone
            do {
                try audioCaptureService.startCapture()
            } catch {
                Self.logger.error("Falha ao iniciar captura de áudio: \(error.localizedDescription, privacy: .public)")
                speechService.cancel()
                coordinator.handleError(error)
                return
            }

            originalStart?()
        }

        let originalFinish = finalCoordinator.onFinishRecording
        finalCoordinator.onFinishRecording = { [weak self, weak audioCaptureService, weak speechService, weak repository, weak postProcessor, weak injectionService, weak languageDetector] reason in
            audioCaptureService?.stopCapture()
            speechService?.finishAudio()

            guard let self = self else { return }

            let rawText = self.currentTranscription
            let trimmedText = rawText.trimmingCharacters(in: .whitespacesAndNewlines)

            defer {
                self.currentTranscription = ""
                self.sessionStartTime = nil
            }

            if !trimmedText.isEmpty {
                // 1. Aplicar regras de substituição personalizadas
                var processedText = trimmedText
                if let repo = repository {
                    do {
                        processedText = try repo.applyReplacements(to: processedText)
                    } catch {
                        Self.logger.warning("Falha ao aplicar regras de substituição: \(error.localizedDescription, privacy: .public)")
                    }
                }

                // 2. Deteção de idioma e pós-processamento (hesitações, pontuação, capitalização)
                let langMode = self.preferencesManager?.preferences.languageSelectionMode ?? .autoDetect
                let detectedLanguage: SpeechLanguage
                switch langMode {
                case .autoDetect:
                    detectedLanguage = languageDetector?.detectLanguage(from: processedText) ?? self.activeLanguage
                case .fixedPT:
                    detectedLanguage = .portuguesePT
                case .fixedEN:
                    detectedLanguage = .englishUS
                }

                let postProcessingOptions = PostProcessingOptions(
                    fillerFilterEnabled: self.preferencesManager?.preferences.fillerFilterEnabled ?? true,
                    oralCommandsEnabled: self.preferencesManager?.preferences.oralCommandsEnabled ?? true,
                    capitalizationEnabled: self.preferencesManager?.preferences.autoCapitalizationEnabled ?? true,
                    autoFinalPeriodEnabled: self.preferencesManager?.preferences.autoFinalPeriodEnabled ?? false
                )

                let formattedText = postProcessor?.process(
                    text: processedText,
                    language: detectedLanguage,
                    options: postProcessingOptions
                ) ?? processedText

                // 3. Injeção de texto no cursor da aplicação ativa
                if let injection = injectionService {
                    let strategy = self.preferencesManager?.preferences.textInjectionStrategy ?? .accessibilityWithFallback
                    let clipboardMode = self.preferencesManager?.preferences.clipboardSafetyMode ?? .pasteAndKeep
                    _ = await injection.inject(
                        text: formattedText,
                        strategy: strategy,
                        clipboardMode: clipboardMode
                    )
                }

                // 4. Registo persistente no repositório local
                let duration: TimeInterval
                if let startTime = self.sessionStartTime {
                    duration = Date().timeIntervalSince(startTime)
                } else {
                    duration = 0.0
                }

                if let repo = repository {
                    do {
                        try repo.recordTranscription(
                            text: formattedText,
                            duration: duration,
                            language: detectedLanguage.rawValue
                        )
                    } catch {
                        Self.logger.error("Falha ao registar transcrição no repositório: \(error.localizedDescription, privacy: .public)")
                    }
                }
            }

            if let originalFinish = originalFinish {
                await originalFinish(reason)
            }
        }

        let originalCancel = finalCoordinator.onCancelRecording
        finalCoordinator.onCancelRecording = { [weak self, weak audioCaptureService, weak speechService] in
            audioCaptureService?.stopCapture()
            speechService?.cancel()
            self?.currentTranscription = ""
            self?.sessionStartTime = nil
            originalCancel?()
        }

        // 2. Vincula HUD ao ciclo de vida da gravação
        hudController.attach(to: finalCoordinator)

        // 3. Vincula MenuBarExtra ao ciclo de vida da gravação
        menuBarManager.attach(to: finalCoordinator)

        // 4. Vincula tratamento centralizado de erros da sessão
        finalCoordinator.onError = { [weak self] error in
            Self.logger.error("Erro reportado no coordenador de gravação: \(error.localizedDescription, privacy: .public)")
            self?.audioCaptureService?.stopCapture()
            self?.speechService?.cancel()
            self?.currentTranscription = ""
            self?.sessionStartTime = nil
            self?.hudController?.setCancelled()
            self?.menuBarManager?.setPlaybackState(.idle)
        }

        // 5. Liga ações da MenuBar para abrir o Dashboard e gerir janelas
        menuBarManager.onOpenDashboard = { [weak self] in
            self?.openDashboardWindow()
        }
        menuBarManager.onOpenSettings = { [weak self] in
            self?.openSettingsWindow()
        }

        // 6. Inicia observação de janelas para o modo dinâmico da Dock
        finalDockCoordinator.startObservingWindowNotifications()

        // 7. Inicia escuta global de atalhos
        finalCoordinator.start()
    }

    /// Traz as janelas principais para a frente e sincroniza o estado da Dock.
    public func openDashboardWindow() {
        guard let app = NSApp else { return }
        app.activate(ignoringOtherApps: true)
        if let window = app.windows.first(where: { DockVisibilityCoordinator.isRegularWindow($0) }) {
            if window.isMiniaturized {
                window.deminiaturize(nil)
            }
            window.makeKeyAndOrderFront(nil)
            window.orderFrontRegardless()
        }
        dockCoordinator?.syncWithOpenWindows()
    }

    /// Abre a janela de definições do Sonotype.
    /// Tenta acionar a scene Settings do SwiftUI; se não estiver disponível, cria ou foca a janela dedicada.
    public func openSettingsWindow() {
        guard let app = NSApp else { return }
        app.activate(ignoringOtherApps: true)

        // 1. Tenta acionar o seletor padrão do SwiftUI para a scene Settings
        let handled = app.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        if handled {
            dockCoordinator?.syncWithOpenWindows()
            return
        }

        // 2. Se a janela dedicada já existir, foca-a
        if let window = settingsWindow, window.isVisible {
            if window.isMiniaturized {
                window.deminiaturize(nil)
            }
            window.makeKeyAndOrderFront(nil)
            window.orderFrontRegardless()
            dockCoordinator?.syncWithOpenWindows()
            return
        }

        // 3. Fallback: cria e apresenta a janela de definições com SettingsView
        let manager = self.preferencesManager ?? .shared
        let settingsView = SettingsView(preferencesManager: manager)
        let hostingController = NSHostingController(rootView: settingsView)

        let window = NSWindow(contentViewController: hostingController)
        window.title = "Definições"
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.setContentSize(NSSize(width: 540, height: 480))
        window.center()
        window.isReleasedWhenClosed = false
        self.settingsWindow = window

        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
        dockCoordinator?.syncWithOpenWindows()
    }

    public func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            openDashboardWindow()
        }
        return true
    }
}

@main
struct SonotypeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup("Sonotype") {
            DashboardWindowView(
                viewModel: DashboardViewModel(
                    repository: appDelegate.repository ?? .shared,
                    autoLoad: true
                ),
                onOpenSettings: {
                    appDelegate.openSettingsWindow()
                }
            )
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 850, height: 580)

        Settings {
            SettingsView(preferencesManager: appDelegate.preferencesManager ?? .shared)
        }
    }
}
