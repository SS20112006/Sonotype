import AppKit
import Foundation

/// Representação tipada de uma combinação de teclas de atalho global.
public struct GlobalHotkey: Sendable, Equatable, Hashable, Codable {
    public let keyCode: UInt16
    public let modifiers: UInt

    public init(keyCode: UInt16, modifiers: NSEvent.ModifierFlags) {
        self.keyCode = keyCode
        // Preserva unicamente as teclas modificadoras relevantes (Option, Command, Control, Shift)
        let relevant = modifiers.intersection([.option, .command, .control, .shift]).rawValue
        self.modifiers = UInt(relevant)
    }

    public var modifierFlags: NSEvent.ModifierFlags {
        NSEvent.ModifierFlags(rawValue: UInt(modifiers))
    }

    /// Atalho padrão de fábrica do Sonotype: Option + Espaço
    public static let defaultToggle = GlobalHotkey(keyCode: 49, modifiers: [.option])

    /// Tecla de cancelamento imediato: Escape
    public static let escapeKey = GlobalHotkey(keyCode: 53, modifiers: [])

    /// Descrição legível para visualização na interface do utilizador (ex: "⌥ Espaço").
    public var displayString: String {
        var parts: [String] = []
        let flags = modifierFlags
        if flags.contains(.control) { parts.append("⌃") }
        if flags.contains(.option) { parts.append("⌥") }
        if flags.contains(.shift) { parts.append("⇧") }
        if flags.contains(.command) { parts.append("⌘") }

        parts.append(Self.keyName(for: keyCode))
        return parts.joined(separator: " ")
    }

    /// Nome amigável dos principais key codes do macOS.
    public static func keyName(for keyCode: UInt16) -> String {
        switch keyCode {
        case 49: return "Espaço"
        case 53: return "Esc"
        case 36: return "Return"
        case 48: return "Tab"
        default: return "Tecla(\(keyCode))"
        }
    }

    /// Compara se um evento do macOS coincide com esta combinação de teclas.
    public func matches(eventKeyCode: UInt16, eventModifiers: NSEvent.ModifierFlags) -> Bool {
        guard eventKeyCode == keyCode else { return false }
        let currentRelevant = eventModifiers.intersection([.option, .command, .control, .shift]).rawValue
        return currentRelevant == modifiers
    }
}

/// Protocolo de abstração para captura e monitorização de atalhos globais de teclado.
@MainActor
public protocol GlobalHotkeyMonitoring: Sendable {
    var isEnabled: Bool { get set }
    var currentHotkey: GlobalHotkey { get set }

    func startMonitoring()
    func stopMonitoring()

    func onHotkeyPressed(_ action: @escaping @MainActor @Sendable () -> Void)
    func onEscapePressed(_ action: @escaping @MainActor @Sendable () -> Void)

    func simulateHotkeyPressed()
    func simulateEscapePressed()
}

/// Contentor auxiliar thread-safe para remoção limpa de tokens de monitores NSEvent no deinit.
private final class MonitorTokenBox: @unchecked Sendable {
    private let lock = NSLock()
    var globalMonitor: Any?
    var localMonitor: Any?

    func removeAll() {
        lock.lock()
        defer { lock.unlock() }
        if let monitor = globalMonitor {
            NSEvent.removeMonitor(monitor)
            globalMonitor = nil
        }
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
            localMonitor = nil
        }
    }

    func setGlobal(_ monitor: Any?) {
        lock.lock()
        defer { lock.unlock() }
        if let old = globalMonitor {
            NSEvent.removeMonitor(old)
        }
        globalMonitor = monitor
    }

    func setLocal(_ monitor: Any?) {
        lock.lock()
        defer { lock.unlock() }
        if let old = localMonitor {
            NSEvent.removeMonitor(old)
        }
        localMonitor = monitor
    }
}

/// Implementação nativa macOS do gestor de atalhos globais.
/// Monitoriza eventos de teclado no sistema através de NSEvent global e local.
@MainActor
public final class SystemGlobalHotkeyManager: GlobalHotkeyMonitoring, Sendable {
    public var isEnabled: Bool = true
    public var currentHotkey: GlobalHotkey

    private let monitorTokens = MonitorTokenBox()

    private var hotkeyAction: (@MainActor @Sendable () -> Void)?
    private var escapeAction: (@MainActor @Sendable () -> Void)?

    public init(hotkey: GlobalHotkey = .defaultToggle) {
        self.currentHotkey = hotkey
    }

    deinit {
        monitorTokens.removeAll()
    }

    public func onHotkeyPressed(_ action: @escaping @MainActor @Sendable () -> Void) {
        self.hotkeyAction = action
    }

    public func onEscapePressed(_ action: @escaping @MainActor @Sendable () -> Void) {
        self.escapeAction = action
    }

    /// Inicia a escuta ativa de eventos de teclado.
    public func startMonitoring() {
        stopMonitoring()

        // Monitor global para quando outras aplicações do macOS estiverem em primeiro plano
        let global = NSEvent.addGlobalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            Task { @MainActor [weak self] in
                self?.handleKeyEvent(event)
            }
        }
        monitorTokens.setGlobal(global)

        // Monitor local para quando a aplicação Sonotype estiver em foco
        let local = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            if let self = self, self.handleKeyEvent(event) {
                // Interceta e consome o evento se for atalho do Sonotype para evitar conflitos locais
                return nil
            }
            return event
        }
        monitorTokens.setLocal(local)
    }

    /// Interrompe a escuta ativa e desaloca os monitores.
    public func stopMonitoring() {
        monitorTokens.removeAll()
    }

    /// Avalia um evento de teclado e aciona as ações correspondentes.
    @discardableResult
    public func handleKeyEvent(_ event: NSEvent) -> Bool {
        guard isEnabled else { return false }

        // Verifica o atalho configurado de gravação (ex: Option + Espaço)
        if currentHotkey.matches(eventKeyCode: event.keyCode, eventModifiers: event.modifierFlags) {
            hotkeyAction?()
            return true
        }

        // Verifica a tecla Escape para cancelamento imediato
        if GlobalHotkey.escapeKey.matches(eventKeyCode: event.keyCode, eventModifiers: event.modifierFlags) {
            escapeAction?()
            return true
        }

        return false
    }

    /// Simula o acionamento do atalho global (para testes e botões de interface).
    public func simulateHotkeyPressed() {
        guard isEnabled else { return }
        hotkeyAction?()
    }

    /// Simula o acionamento da tecla Escape (para testes e botões de interface).
    public func simulateEscapePressed() {
        guard isEnabled else { return }
        escapeAction?()
    }
}
