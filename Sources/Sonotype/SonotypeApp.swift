import AppKit
import SwiftUI
import os

/// Delegado principal do ciclo de vida da aplicação Sonotype no macOS.
/// Inicializa o motor de sessão, HUD flutuante, barra de menus e controlo híbrido da Dock.
@MainActor
public final class AppDelegate: NSObject, NSApplicationDelegate, Sendable {
    private static let logger = Logger(subsystem: "com.sonotype.app", category: "AppDelegate")

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

    public var activeLanguage: SpeechLanguage = .portuguesePT
    public var currentTranscription: String = ""
    public private(set) var sessionStartTime: Date?

    public func applicationDidFinishLaunching(_ notification: Notification) {
        setupCoreServices()
    }

    public func setupCoreServices(
        coordinator: RecordingSessionCoordinator = RecordingSessionCoordinator(),
        hudController: HUDController = HUDController(),
        dockCoordinator: DockVisibilityCoordinator = DockVisibilityCoordinator(initialMode: .dynamic),
        menuBarManager: MenuBarExtraManager = MenuBarExtraManager(),
        repository: PersistenceRepository = .shared,
        audioCaptureService: AudioCaptureService = AudioCaptureService(),
        speechService: SpeechRecognitionService = SpeechRecognitionService(),
        languageDetector: LanguageDetectorService = LanguageDetectorService(),
        postProcessor: TextPostProcessor = TextPostProcessor(),
        injectionService: TextInjectionService = TextInjectionService()
    ) {
        self.coordinator = coordinator
        self.hudController = hudController
        self.dockCoordinator = dockCoordinator
        self.menuBarManager = menuBarManager
        self.repository = repository
        self.audioCaptureService = audioCaptureService
        self.speechService = speechService
        self.languageDetector = languageDetector
        self.postProcessor = postProcessor
        self.injectionService = injectionService

        self.activeLanguage = languageDetector.defaultLanguage

        // 1. Pipeline de gravação e transcrição no Coordenador
        let originalStart = coordinator.onStartRecording
        coordinator.onStartRecording = { [weak self, weak coordinator, weak audioCaptureService, weak speechService] in
            guard let self = self,
                  let coordinator = coordinator,
                  let audioCaptureService = audioCaptureService,
                  let speechService = speechService else { return }

            self.currentTranscription = ""
            self.sessionStartTime = Date()

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

        let originalFinish = coordinator.onFinishRecording
        coordinator.onFinishRecording = { [weak self, weak audioCaptureService, weak speechService, weak repository, weak postProcessor, weak injectionService, weak languageDetector] reason in
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
                let detectedLanguage = languageDetector?.detectLanguage(from: processedText) ?? self.activeLanguage
                let formattedText = postProcessor?.process(
                    text: processedText,
                    language: detectedLanguage
                ) ?? processedText

                // 3. Injeção de texto no cursor da aplicação ativa
                if let injection = injectionService {
                    _ = await injection.inject(text: formattedText)
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

        let originalCancel = coordinator.onCancelRecording
        coordinator.onCancelRecording = { [weak self, weak audioCaptureService, weak speechService] in
            audioCaptureService?.stopCapture()
            speechService?.cancel()
            self?.currentTranscription = ""
            self?.sessionStartTime = nil
            originalCancel?()
        }

        // 2. Vincula HUD ao ciclo de vida da gravação
        hudController.attach(to: coordinator)

        // 3. Vincula MenuBarExtra ao ciclo de vida da gravação
        menuBarManager.attach(to: coordinator)

        // 4. Vincula tratamento centralizado de erros da sessão
        coordinator.onError = { [weak self] error in
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

        // 6. Inicia observação de janelas para o modo dinâmico da Dock
        dockCoordinator.startObservingWindowNotifications()

        // 7. Inicia escuta global de atalhos
        coordinator.start()
    }

    /// Traz as janelas principais para a frente e sincroniza o estado da Dock.
    public func openDashboardWindow() {
        guard let app = NSApp else { return }
        app.activate(ignoringOtherApps: true)
        if let window = app.windows.first(where: { DockVisibilityCoordinator.isRegularWindow($0) }) {
            window.makeKeyAndOrderFront(nil)
        }
        dockCoordinator?.syncWithOpenWindows()
    }
}

@main
struct SonotypeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup("Sonotype") {
            ContentView()
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
    }
}

struct ContentView: View {
    @State private var isReady: Bool = true
    @State private var hapticTrigger: Int = 0
    @State private var hudController: HUDController?

    var body: some View {
        VStack(spacing: 20) {
            // Header with SF Pro Display (>= 20pt)
            HStack(spacing: 12) {
                Image(systemName: "waveform.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 32, height: 32)
                    .foregroundStyle(.tint)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Sonotype")
                        .font(.system(size: 22, weight: .bold, design: .default)) // SF Pro Display >= 20pt
                        .tracking(0.35)
                        .foregroundStyle(.primary)

                    Text("Ditado por voz offline nativo")
                        .font(.system(size: 13, weight: .medium, design: .default)) // SF Pro Text <= 19pt
                        .tracking(-0.08)
                        .foregroundStyle(.secondary)
                }
            }
            .accessibilityElement(children: .combine)

            // Status Card with Native macOS Semantic Material
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Circle()
                        .fill(isReady ? Color.green : Color.orange)
                        .frame(width: 10, height: 10)
                    Text(isReady ? "Motor de Áudio Pronto" : "A Inicializar...")
                        .font(.system(size: 13, weight: .semibold, design: .default)) // SF Pro Text <= 19pt
                        .tracking(-0.08)
                        .foregroundStyle(.primary)
                    Spacer()
                    Text("PT / EN")
                        .font(.system(size: 11, weight: .medium, design: .default)) // SF Pro Text <= 19pt
                        .tracking(0.06)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.quaternary, in: Capsule())
                }

                Text("Prima Option + Espaço para alternar o ditado ou consulte a barra de menus.")
                    .font(.system(size: 12, weight: .regular, design: .default)) // SF Pro Text <= 19pt
                    .tracking(0.0)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            .padding(14)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(.separator, lineWidth: 0.5)
            )
            .accessibilityElement(children: .combine)

            // Primary Action Button meeting 44x44pt touch target and Apple HIG
            Button {
                hapticTrigger += 1
                if hudController == nil {
                    hudController = HUDController()
                }
                guard let hud = hudController else { return }
                if hud.viewModel.isVisible {
                    hud.hide()
                } else {
                    hud.show(state: .recording)
                    hud.updateAmplitude(0.65)
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "mic.fill")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Testar Ditado")
                        .font(.system(size: 14, weight: .semibold, design: .default)) // SF Pro Text <= 19pt
                        .tracking(-0.15)
                }
                .frame(maxWidth: .infinity)
                .frame(minHeight: 44) // 44x44pt touch target requirement
                .background(.tint, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .foregroundStyle(.white)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Testar exibição da pílula HUD de ditado")
            .accessibilityLabel("Testar Ditado")
            .accessibilityHint("Ativa a simulação da gravação e exibe o HUD")
            .sensoryFeedback(.impact(weight: .medium, intensity: 1.0), trigger: hapticTrigger)
        }
        .padding(24)
        .frame(width: 380)
        .background(.regularMaterial)
    }
}
