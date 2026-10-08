import AppKit
@preconcurrency import ApplicationServices
import CoreGraphics
import Foundation
import os

/// Método utilizado para realizar a injeção do texto.
public enum TextInjectionMethod: String, Sendable, Equatable {
    /// Inserção direta via API de Acessibilidade macOS (AXUIElement) sem alterar o clipboard.
    case accessibility

    /// Inserção simulada via eventos de teclado (CGEvent - Cmd+V).
    case keystrokeSimulation
}

/// Estratégia de injeção preferida.
public enum TextInjectionStrategy: String, Sendable, CaseIterable {
    /// Tenta AXUIElement primeiro; se o elemento não suportar ou falhar, recorre a CGEvent.
    case accessibilityWithFallback
    /// Força unicamente injeção por Acessibilidade (AXUIElement).
    case accessibilityOnly
    /// Força unicamente injeção por eventos de teclado (CGEvent).
    case keystrokeOnly
}

/// Resultado detalhado da operação de injeção.
public struct TextInjectionResult: Sendable, Equatable {
    public let success: Bool
    public let methodUsed: TextInjectionMethod?
    public let errorDescription: String?

    public init(success: Bool, methodUsed: TextInjectionMethod?, errorDescription: String? = nil) {
        self.success = success
        self.methodUsed = methodUsed
        self.errorDescription = errorDescription
    }

    public static func success(with method: TextInjectionMethod) -> TextInjectionResult {
        TextInjectionResult(success: true, methodUsed: method, errorDescription: nil)
    }

    public static func failure(_ reason: String) -> TextInjectionResult {
        TextInjectionResult(success: false, methodUsed: nil, errorDescription: reason)
    }
}

/// Contrato para injeção via Accessibility API (permite testes determinísticos).
public protocol AccessibilityTextInjecting: Sendable {
    func isProcessTrusted(prompt: Bool) -> Bool
    func injectTextAtCursor(_ text: String) -> Bool
}

/// Implementação padrão de Acessibilidade utilizando AXUIElement nativo do macOS.
public final class SystemAccessibilityInjector: AccessibilityTextInjecting, Sendable {
    public init() {}

    public func isProcessTrusted(prompt: Bool = false) -> Bool {
        if prompt {
            let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue()
            let options = [key: kCFBooleanTrue as Any] as CFDictionary
            return AXIsProcessTrustedWithOptions(options)
        }
        return AXIsProcessTrusted()
    }

    public func injectTextAtCursor(_ text: String) -> Bool {
        let systemWide = AXUIElementCreateSystemWide()
        var focusedElementRef: CFTypeRef?
        let copyError = AXUIElementCopyAttributeValue(
            systemWide,
            kAXFocusedUIElementAttribute as CFString,
            &focusedElementRef
        )

        guard copyError == .success,
              let focusedElementRef,
              CFGetTypeID(focusedElementRef) == AXUIElementGetTypeID() else {
            return false
        }

        let focusedElement = focusedElementRef as! AXUIElement

        var isSettable: DarwinBoolean = false
        let settableCheck = AXUIElementIsAttributeSettable(
            focusedElement,
            kAXSelectedTextAttribute as CFString,
            &isSettable
        )

        guard settableCheck == .success, isSettable.boolValue else {
            return false
        }

        let setError = AXUIElementSetAttributeValue(
            focusedElement,
            kAXSelectedTextAttribute as CFString,
            text as CFTypeRef
        )

        return setError == .success
    }
}

/// Contrato para simulação de eventos de teclado (permite testes determinísticos).
public protocol KeystrokeSimulating: Sendable {
    func simulatePasteKeystroke() -> Bool
}

/// Implementação padrão utilizando CGEvent nativo do macOS (Cmd+V).
public final class SystemKeystrokeSimulator: KeystrokeSimulating, Sendable {
    public init() {}

    public func simulatePasteKeystroke() -> Bool {
        guard let source = CGEventSource(stateID: .combinedSessionState) else {
            return false
        }

        // Virtual Key Code 0x09 = ANSI 'V'
        let virtualKeyV: CGKeyCode = 0x09

        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: virtualKeyV, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: virtualKeyV, keyDown: false) else {
            return false
        }

        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand

        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)

        return true
    }
}

/// Serviço de injeção de texto no cursor da aplicação ativa com fallback para simulação e salvaguarda do clipboard.
@MainActor
public final class TextInjectionService: Sendable {
    private static let logger = Logger(subsystem: "com.sonotype.app", category: "TextInjectionService")

    public let accessibilityInjector: any AccessibilityTextInjecting
    public let keystrokeSimulator: any KeystrokeSimulating
    public let clipboardManager: ClipboardSafetyManager

    public init(
        accessibilityInjector: any AccessibilityTextInjecting = SystemAccessibilityInjector(),
        keystrokeSimulator: any KeystrokeSimulating = SystemKeystrokeSimulator(),
        clipboardManager: ClipboardSafetyManager = ClipboardSafetyManager()
    ) {
        self.accessibilityInjector = accessibilityInjector
        self.keystrokeSimulator = keystrokeSimulator
        self.clipboardManager = clipboardManager
    }

    /// Executa a injeção do texto com a estratégia e modo de clipboard selecionados.
    ///
    /// - Parameters:
    ///   - text: Texto transcrito polido a inserir no cursor.
    ///   - strategy: Estratégia de injeção (Acessibilidade com fallback, apenas AX, ou apenas CGEvent).
    ///   - clipboardMode: Modo de gestão do clipboard (Modo A: manter cópia; Modo B: preservar anterior).
    ///   - keystrokeRestoreDelay: Atraso em nanossegundos antes de restaurar o clipboard no Modo B.
    /// - Returns: `TextInjectionResult` contendo o sucesso, o método utilizado e eventuais diagnósticos.
    public func inject(
        text: String,
        strategy: TextInjectionStrategy = .accessibilityWithFallback,
        clipboardMode: ClipboardSafetyMode = .pasteAndKeep,
        keystrokeRestoreDelay: UInt64 = 75_000_000
    ) async -> TextInjectionResult {
        guard !text.isEmpty else {
            Self.logger.warning("Pedido de injeção de texto com conteúdo vazio")
            return .failure("Texto vazio para injeção.")
        }

        switch strategy {
        case .accessibilityOnly:
            if accessibilityInjector.injectTextAtCursor(text) {
                if clipboardMode == .pasteAndKeep {
                    clipboardManager.setText(text)
                }
                Self.logger.info("Injeção realizada com sucesso via Acessibilidade (AXUIElement)")
                return .success(with: .accessibility)
            } else {
                let reason = "Falha na injeção via AXUIElement (elemento não acessível ou sem suporte a seleção)."
                Self.logger.error("Injeção via Acessibilidade falhou: \(reason, privacy: .public)")
                return .failure(reason)
            }

        case .keystrokeOnly:
            return await injectViaKeystroke(
                text: text,
                mode: clipboardMode,
                restoreDelay: keystrokeRestoreDelay
            )

        case .accessibilityWithFallback:
            if accessibilityInjector.injectTextAtCursor(text) {
                if clipboardMode == .pasteAndKeep {
                    clipboardManager.setText(text)
                }
                Self.logger.info("Injeção realizada com sucesso via Acessibilidade (AXUIElement)")
                return .success(with: .accessibility)
            }
            Self.logger.info("Acessibilidade indisponível para o elemento ativo. Recorrendo a fallback via CGEvent (Cmd+V)")
            // Fallback transparente para simulação via CGEvent + Cmd+V
            return await injectViaKeystroke(
                text: text,
                mode: clipboardMode,
                restoreDelay: keystrokeRestoreDelay
            )
        }
    }

    private func injectViaKeystroke(
        text: String,
        mode: ClipboardSafetyMode,
        restoreDelay: UInt64
    ) async -> TextInjectionResult {
        var didSimulate = false
        await clipboardManager.withPreservedClipboard(
            text: text,
            mode: mode,
            restoreDelayNanoseconds: restoreDelay
        ) {
            didSimulate = keystrokeSimulator.simulatePasteKeystroke()
        }

        guard didSimulate else {
            let reason = "Falha ao emitir eventos CGEvent para atalho Cmd+V."
            Self.logger.error("Simulação de teclado falhou: \(reason, privacy: .public)")
            return .failure(reason)
        }

        Self.logger.info("Injeção realizada com sucesso via simulação CGEvent (Cmd+V)")
        return .success(with: .keystrokeSimulation)
    }
}
