import AppKit
import Foundation
import os

/// Modos suportados de visibilidade do ícone do Sonotype na Dock do macOS.
public enum DockVisibilityMode: String, Sendable, CaseIterable, Codable {
    /// Modo Padrão: invisível na Dock em repouso (.accessory); visível quando janelas abertas (.regular).
    case dynamic
    /// Sempre invisível na Dock, existindo exclusivamente na Barra de Menus (.accessory).
    case menuBarOnly
    /// Sempre visível na Dock (.regular), como uma aplicação desktop tradicional.
    case alwaysDock
}

/// Abstração para injeção e teste de controlo da política de ativação do NSApplication.
@MainActor
public protocol ActivationPolicyControlling: Sendable {
    var activationPolicy: NSApplication.ActivationPolicy { get }
    @discardableResult
    func setActivationPolicy(_ policy: NSApplication.ActivationPolicy) -> Bool
}

/// Implementação padrão que delega diretamente no NSApplication.shared.
@MainActor
public final class SystemActivationPolicyController: ActivationPolicyControlling {
    public init() {}

    public var activationPolicy: NSApplication.ActivationPolicy {
        NSApp?.activationPolicy() ?? .accessory
    }

    @discardableResult
    public func setActivationPolicy(_ policy: NSApplication.ActivationPolicy) -> Bool {
        guard let app = NSApp else { return false }
        return app.setActivationPolicy(policy)
    }
}

/// Coordenador do modo híbrido de visibilidade da aplicação na Dock do macOS.
/// Gere as transições entre .accessory (sem ícone na Dock) e .regular (com ícone na Dock).
@MainActor
public final class DockVisibilityCoordinator: ObservableObject, Sendable {
    private static let logger = Logger(subsystem: "com.sonotype.app", category: "DockVisibilityCoordinator")

    @Published public private(set) var currentMode: DockVisibilityMode
    @Published public private(set) var activeWindowCount: Int = 0
    @Published public private(set) var currentPolicy: NSApplication.ActivationPolicy

    public let policyController: any ActivationPolicyControlling

    private var observationTasks: [Task<Void, Never>] = []

    public init(
        initialMode: DockVisibilityMode = .dynamic,
        policyController: any ActivationPolicyControlling = SystemActivationPolicyController()
    ) {
        self.currentMode = initialMode
        self.policyController = policyController
        self.currentPolicy = policyController.activationPolicy

        // Aplica a política inicial com base no modo
        recomputePolicy()
    }

    /// Altera o modo de visibilidade e recalcula a política de ativação.
    public func setMode(_ newMode: DockVisibilityMode) {
        guard currentMode != newMode else { return }
        currentMode = newMode
        recomputePolicy()
    }

    /// Incrementa a contagem de janelas regulares abertas e atualiza a política.
    public func windowDidOpen() {
        activeWindowCount += 1
        recomputePolicy()
    }

    /// Decrementa a contagem de janelas regulares abertas e atualiza a política.
    public func windowDidClose() {
        activeWindowCount = max(0, activeWindowCount - 1)
        recomputePolicy()
    }

    /// Atualiza diretamente a contagem de janelas abertas.
    public func updateWindowCount(_ count: Int) {
        activeWindowCount = max(0, count)
        recomputePolicy()
    }

    /// Recalcula e aplica a política de ativação adequada.
    @discardableResult
    public func recomputePolicy() -> NSApplication.ActivationPolicy {
        let targetPolicy: NSApplication.ActivationPolicy
        switch currentMode {
        case .alwaysDock:
            targetPolicy = .regular
        case .menuBarOnly:
            targetPolicy = .accessory
        case .dynamic:
            targetPolicy = (activeWindowCount > 0) ? .regular : .accessory
        }

        if policyController.activationPolicy != targetPolicy {
            let success = policyController.setActivationPolicy(targetPolicy)
            if !success {
                Self.logger.error("Falha ao definir activationPolicy para \(targetPolicy == .regular ? "regular" : "accessory", privacy: .public)")
            }
        }
        currentPolicy = targetPolicy
        return targetPolicy
    }

    /// Determina se uma janela é uma janela de documento/dashboard regular (e não HUD/Panel/Popover).
    public static func isRegularWindow(_ window: NSWindow) -> Bool {
        if window is NSPanel { return false }
        let className = String(describing: type(of: window))
        if className.contains("Popover") || className.contains("Status") { return false }
        return window.styleMask.contains(.titled)
    }

    /// Inicia a monitorização automática de notificações de janelas do macOS via AsyncSequence.
    public func startObservingWindowNotifications() {
        stopObservingWindowNotifications()

        let openTask = Task { @MainActor [weak self] in
            for await notification in NotificationCenter.default.notifications(named: NSWindow.didBecomeMainNotification) {
                guard let self = self else { break }
                if let window = notification.object as? NSWindow, Self.isRegularWindow(window) {
                    self.syncWithOpenWindows()
                }
            }
        }

        let closeTask = Task { @MainActor [weak self] in
            for await notification in NotificationCenter.default.notifications(named: NSWindow.willCloseNotification) {
                guard let self = self else { break }
                if let window = notification.object as? NSWindow, Self.isRegularWindow(window) {
                    // Pequeno intervalo para permitir a atualização da lista de janelas do NSApp
                    do {
                        try await Task.sleep(nanoseconds: 50_000_000)
                    } catch {
                        break
                    }
                    guard !Task.isCancelled else { break }
                    self.syncWithOpenWindows()
                }
            }
        }

        observationTasks = [openTask, closeTask]
    }

    /// Para a monitorização automática de janelas.
    public func stopObservingWindowNotifications() {
        observationTasks.forEach { $0.cancel() }
        observationTasks.removeAll()
    }

    /// Sincroniza a contagem com as janelas regulares visíveis no NSApp.
    public func syncWithOpenWindows() {
        guard let windows = NSApp?.windows else { return }
        let count = windows.filter { $0.isVisible && Self.isRegularWindow($0) }.count
        updateWindowCount(count)
    }
}
