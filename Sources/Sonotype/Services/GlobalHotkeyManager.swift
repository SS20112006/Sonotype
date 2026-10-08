import AppKit
import Combine
import Foundation
import os

/// Representação tipada de uma combinação de teclas de atalho global.
public struct GlobalHotkey: Sendable, Equatable, Hashable, Codable {
    public let keyCode: UInt16
    public let modifiers: UInt

    /// Modificadores relevantes suportados para atalhos do Sonotype.
    public static let relevantModifiersMask: NSEvent.ModifierFlags = [.option, .command, .control, .shift]

    public init(keyCode: UInt16, modifiers: NSEvent.ModifierFlags) {
        self.keyCode = keyCode
        // Preserva unicamente as teclas modificadoras relevantes (Option, Command, Control, Shift)
        // e mascara bits dependentes do dispositivo físico no macOS 14/15
        let relevant = modifiers
            .intersection(.deviceIndependentFlagsMask)
            .intersection(Self.relevantModifiersMask)
            .rawValue
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
        // Teclas de Controlo e Edição
        case 49: return "Espaço"
        case 53: return "Esc"
        case 36: return "Return"
        case 48: return "Tab"
        case 51: return "Delete"
        case 117: return "Fwd Del"

        // Letras
        case 0: return "A"
        case 1: return "S"
        case 2: return "D"
        case 3: return "F"
        case 4: return "H"
        case 5: return "G"
        case 6: return "Z"
        case 7: return "X"
        case 8: return "C"
        case 9: return "V"
        case 11: return "B"
        case 12: return "Q"
        case 13: return "W"
        case 14: return "E"
        case 15: return "R"
        case 16: return "Y"
        case 17: return "T"
        case 31: return "O"
        case 32: return "U"
        case 34: return "I"
        case 35: return "P"
        case 37: return "L"
        case 38: return "J"
        case 40: return "K"

        // Números
        case 18: return "1"
        case 19: return "2"
        case 20: return "3"
        case 21: return "4"
        case 22: return "6"
        case 23: return "5"
        case 25: return "9"
        case 26: return "7"
        case 28: return "8"
        case 29: return "0"

        // Setas de Navegação
        case 123: return "←"
        case 124: return "→"
        case 125: return "↓"
        case 126: return "↑"

        // Teclas de Função
        case 122: return "F1"
        case 120: return "F2"
        case 99: return "F3"
        case 118: return "F4"
        case 96: return "F5"
        case 97: return "F6"
        case 98: return "F7"
        case 100: return "F8"
        case 101: return "F9"
        case 109: return "F10"
        case 103: return "F11"
        case 111: return "F12"

        default: return "Tecla(\(keyCode))"
        }
    }

    /// Compara se um evento do macOS coincide com esta combinação de teclas.
    public func matches(eventKeyCode: UInt16, eventModifiers: NSEvent.ModifierFlags) -> Bool {
        guard eventKeyCode == keyCode else { return false }
        // No macOS 14/15, event.modifierFlags contém bits independentes de dispositivo mais flags internas/físicas.
        // Sanitiza bits dependentes usando .deviceIndependentFlagsMask e isola as teclas relevantes.
        let sanitized = eventModifiers
            .intersection(.deviceIndependentFlagsMask)
            .intersection(Self.relevantModifiersMask)
        let relevant = UInt(sanitized.rawValue)
        return relevant == modifiers
    }
}

/// Protocolo de abstração para captura e monitorização de atalhos globais de teclado.
@MainActor
public protocol GlobalHotkeyMonitoring: AnyObject, Sendable {
    var isEnabled: Bool { get set }
    var currentHotkey: GlobalHotkey { get set }

    func startMonitoring()
    func stopMonitoring()
    func restartMonitoring()

    func onHotkeyPressed(_ action: @escaping @MainActor @Sendable () -> Void)
    func onEscapePressed(_ action: @escaping @MainActor @Sendable () -> Void)

    func simulateHotkeyPressed()
    func simulateEscapePressed()
}

extension GlobalHotkeyMonitoring {
    public func restartMonitoring() {
        startMonitoring()
    }
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
    private static let logger = Logger(subsystem: "com.sonotype.app", category: "GlobalHotkeyManager")

    public var isEnabled: Bool = true
    public var currentHotkey: GlobalHotkey

    private let monitorTokens = MonitorTokenBox()
    private var cancellables = Set<AnyCancellable>()
    private var lastAccessibilityState: Bool = AXIsProcessTrusted()

    private var hotkeyAction: (@MainActor @Sendable () -> Void)?
    private var escapeAction: (@MainActor @Sendable () -> Void)?

    public init(hotkey: GlobalHotkey = .defaultToggle) {
        self.currentHotkey = hotkey
        setupAccessibilityObserver()
    }

    deinit {
        monitorTokens.removeAll()
    }

    private func setupAccessibilityObserver() {
        NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self = self else { return }
                let currentTrusted = AXIsProcessTrusted()
                if currentTrusted != self.lastAccessibilityState {
                    self.lastAccessibilityState = currentTrusted
                    Self.logger.info("Estado de Acessibilidade alterado para \(currentTrusted, privacy: .public). Reiniciando monitores de atalhos.")
                    self.restartMonitoring()
                }
            }
            .store(in: &cancellables)
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
        Self.logger.info("Iniciando monitorização de atalhos globais")

        // No macOS, capturar eventos globais de outras aplicações requer permissão de Acessibilidade
        if !AXIsProcessTrusted() {
            Self.logger.warning("Monitor global de teclas inativo: permissão de acessibilidade necessária")
        }

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

    /// Reinicia a monitorização de atalhos globais (ex: quando o estado de Acessibilidade muda).
    public func restartMonitoring() {
        Self.logger.info("Reiniciando monitorização de atalhos globais")
        startMonitoring()
    }

    /// Interrompe a escuta ativa e desaloca os monitores.
    public func stopMonitoring() {
        Self.logger.info("Interrompendo monitorização de atalhos globais")
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
