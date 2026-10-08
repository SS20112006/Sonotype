import AppKit
import AVFoundation
import ApplicationServices
import Combine
import Foundation
@preconcurrency import Speech
import os

/// Protocolo de abstração do serviço de verificação e requisição de permissões do sistema.
@MainActor
public protocol PermissionsServiceProtocol: AnyObject, Sendable {
    /// Estado atual da autorização de microfone.
    var microphoneStatus: AVAuthorizationStatus { get }

    /// Indica se o microfone está concedido.
    var isMicrophoneAuthorized: Bool { get }

    /// Estado atual da autorização de reconhecimento de fala.
    var speechStatus: SFSpeechRecognizerAuthorizationStatus { get }

    /// Indica se o reconhecimento de fala está concedido.
    var isSpeechAuthorized: Bool { get }

    /// Indica se a permissão de acessibilidade está concedida (Trusted).
    var isAccessibilityAuthorized: Bool { get }

    /// Requisita permissão de acesso ao microfone ao sistema operativo.
    func requestMicrophoneAccess() async -> Bool

    /// Requisita permissão de acesso ao reconhecimento de fala ao sistema operativo.
    func requestSpeechAccess() async -> Bool

    /// Verifica e opcionalmente solicita acesso de acessibilidade (abrindo prompt do sistema se necessário).
    func checkAccessibilityPermission(prompt: Bool) -> Bool

    /// Abre o painel correspondente das Definições do Sistema no macOS.
    func openSystemSettings(for permission: SystemPrivacyPane)
}

extension PermissionsServiceProtocol {
    public var speechStatus: SFSpeechRecognizerAuthorizationStatus {
        SFSpeechRecognizer.authorizationStatus()
    }

    public var isSpeechAuthorized: Bool {
        speechStatus == .authorized
    }

    public func requestSpeechAccess() async -> Bool {
        let current = SFSpeechRecognizer.authorizationStatus()
        if current == .authorized {
            return true
        }

        return await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }
}

/// Identificadores de painéis de privacidade das Definições do Sistema no macOS.
public enum SystemPrivacyPane: Sendable {
    case microphone
    case speechRecognition
    case accessibility

    public var url: URL? {
        switch self {
        case .microphone:
            return URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone")
        case .speechRecognition:
            return URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_SpeechRecognition")
        case .accessibility:
            return URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
        }
    }
}

/// Serviço central de permissões do Sonotype no macOS.
/// Responsável pela verificação reativa do Microfone, Reconhecimento de Fala e da API de Acessibilidade.
@MainActor
public final class PermissionsService: ObservableObject, PermissionsServiceProtocol, Sendable {
    private static let logger = Logger(subsystem: "com.sonotype.app", category: "PermissionsService")

    @Published public private(set) var microphoneStatus: AVAuthorizationStatus = .notDetermined
    @Published public private(set) var speechStatus: SFSpeechRecognizerAuthorizationStatus = .notDetermined
    @Published public private(set) var isAccessibilityAuthorized: Bool = false

    public var isMicrophoneAuthorized: Bool {
        microphoneStatus == .authorized
    }

    public var isSpeechAuthorized: Bool {
        speechStatus == .authorized
    }

    private let workspace: NSWorkspace
    private var pollTimer: Timer?

    public init(workspace: NSWorkspace = .shared) {
        self.workspace = workspace
        refreshStatuses()
    }

    deinit {
        // Timer with weak target will get deallocated; or if stopped before deinit.
    }

    /// Atualiza imediatamente os estados observáveis de microfone, fala e acessibilidade.
    public func refreshStatuses() {
        self.microphoneStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        self.speechStatus = SFSpeechRecognizer.authorizationStatus()
        self.isAccessibilityAuthorized = AXIsProcessTrusted()
    }

    /// Inicia temporizador de monitorização periódica durante os passos de Onboarding ou ecrã de Definições.
    public func startPolling(interval: TimeInterval = 1.0) {
        stopPolling()
        refreshStatuses()
        pollTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refreshStatuses()
            }
        }
    }

    /// Para o temporizador de monitorização periódica.
    public func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
    }

    /// Requisita permissão de acesso ao microfone ao sistema operativo de forma assíncrona.
    public func requestMicrophoneAccess() async -> Bool {
        let current = AVCaptureDevice.authorizationStatus(for: .audio)
        if current == .authorized {
            self.microphoneStatus = .authorized
            return true
        }

        let granted = await AVCaptureDevice.requestAccess(for: .audio)
        self.microphoneStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        Self.logger.info("Resultado do pedido de microfone: \(granted, privacy: .public)")
        return granted
    }

    /// Requisita permissão de reconhecimento de fala ao sistema operativo de forma assíncrona.
    public func requestSpeechAccess() async -> Bool {
        let current = SFSpeechRecognizer.authorizationStatus()
        if current == .authorized {
            self.speechStatus = .authorized
            return true
        }

        return await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { [weak self] status in
                Task { @MainActor [weak self] in
                    self?.speechStatus = status
                    Self.logger.info("Resultado do pedido de fala: \(status.rawValue, privacy: .public)")
                    continuation.resume(returning: status == .authorized)
                }
            }
        }
    }

    /// Verifica se a aplicação é confiável na API de Acessibilidade do macOS.
    /// Se `prompt` for `true`, o macOS exibe o diálogo nativo do sistema a solicitar autorização.
    public func checkAccessibilityPermission(prompt: Bool = false) -> Bool {
        let trusted: Bool
        if prompt {
            let key = "AXTrustedCheckOptionPrompt" as CFString
            let options = [key: kCFBooleanTrue as Any] as CFDictionary
            trusted = AXIsProcessTrustedWithOptions(options)
        } else {
            trusted = AXIsProcessTrusted()
        }
        self.isAccessibilityAuthorized = trusted
        return trusted
    }

    /// Abre as Definições do Sistema no painel de privacidade adequado.
    public func openSystemSettings(for permission: SystemPrivacyPane) {
        if let url = permission.url {
            let opened = workspace.open(url)
            if !opened {
                Self.logger.warning("Falha ao abrir URL de definições: \(url.absoluteString, privacy: .public)")
            }
        }
    }
}
