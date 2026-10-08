import AppKit
import SwiftUI
import os

/// Contentor auxiliar thread-safe para remoção limpa de token de monitor NSEvent no deinit.
private final class RecorderMonitorTokenBox: @unchecked Sendable {
    private let lock = NSLock()
    private var token: Any?

    func remove() {
        lock.lock()
        defer { lock.unlock() }
        if let t = token {
            NSEvent.removeMonitor(t)
            token = nil
        }
    }

    func set(_ newToken: Any?) {
        lock.lock()
        defer { lock.unlock() }
        if let old = token {
            NSEvent.removeMonitor(old)
        }
        token = newToken
    }
}

/// Coordenador observável responsável pelo ciclo de vida, interceção de eventos e validação
/// de atalhos globais de teclado para o `HotkeyRecorderView`.
@MainActor
public final class HotkeyRecorderCoordinator: ObservableObject, Sendable {
    private static let logger = Logger(subsystem: "com.sonotype.app", category: "HotkeyRecorderCoordinator")

    public let preferencesManager: PreferencesManager

    @Published public var isRecording: Bool = false
    @Published public var isPulsing: Bool = false
    @Published public var errorMessage: String? = nil
    @Published public var feedbackTrigger: Int = 0

    private let tokenBox = RecorderMonitorTokenBox()

    public init(preferencesManager: PreferencesManager) {
        self.preferencesManager = preferencesManager
    }

    deinit {
        tokenBox.remove()
    }

    public var currentHotkey: GlobalHotkey {
        preferencesManager.preferences.globalHotkey
    }

    /// Inicia o modo interativo de escuta de atalho de teclado através de monitor local NSEvent.
    public func startRecording() {
        stopRecordingMonitor()
        errorMessage = nil
        isRecording = true
        isPulsing = true

        let token = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            guard let self = self, self.isRecording else { return event }

            let handled = self.handleCapturedKeyEvent(
                keyCode: event.keyCode,
                modifierFlags: event.modifierFlags
            )

            if handled {
                return nil // Interceta e consome o evento de teclado
            }
            return event
        }
        tokenBox.set(token)
    }

    /// Cancela o modo de gravação sem alterar o atalho configurado.
    public func cancelRecording() {
        stopRecordingMonitor()
        isRecording = false
        isPulsing = false
        errorMessage = nil
    }

    /// Restaura o atalho padrão de fábrica (Option + Espaço).
    public func resetToDefault() {
        cancelRecording()
        preferencesManager.globalHotkey = .defaultToggle
        feedbackTrigger += 1
    }

    /// Para e desaloca o monitor local de eventos.
    public func stopRecordingMonitor() {
        tokenBox.remove()
        isPulsing = false
    }

    /// Processa uma combinação de teclas capturada, validando regras de segurança.
    /// Retorna `true` se o evento foi tratado e deve ser consumido.
    @discardableResult
    public func handleCapturedKeyEvent(
        keyCode: UInt16,
        modifierFlags: NSEvent.ModifierFlags
    ) -> Bool {
        // Regra 1: Tecla Escape (keyCode 53) cancela a gravação
        if keyCode == 53 {
            cancelRecording()
            return true
        }

        // Regra 2: Rejeitar atalhos sem teclas modificadoras (Option, Command, Control, Shift)
        let relevantModifiers = modifierFlags.intersection([.option, .command, .control, .shift])
        guard relevantModifiers.rawValue != 0 else {
            errorMessage = "Inclua pelo menos uma tecla modificadora (⌥, ⌘, ⌃, ⇧)."
            return false
        }

        // Regra 3: Validação de combinação válida
        let newHotkey = GlobalHotkey(keyCode: keyCode, modifiers: relevantModifiers)
        preferencesManager.globalHotkey = newHotkey
        stopRecordingMonitor()
        isRecording = false
        errorMessage = nil
        feedbackTrigger += 1
        return true
    }
}

/// Componente SwiftUI nativo macOS para visualização e gravação de atalhos globais de teclado.
/// Cumpre estritamente Apple Human Interface Guidelines, WCAG 2.1 AA e alvos ergonómicos >= 44x44pt.
@MainActor
public struct HotkeyRecorderView: View {
    @ObservedObject public var coordinator: HotkeyRecorderCoordinator

    public init(preferencesManager: PreferencesManager) {
        self.coordinator = HotkeyRecorderCoordinator(preferencesManager: preferencesManager)
    }

    public init(coordinator: HotkeyRecorderCoordinator) {
        self.coordinator = coordinator
    }

    // MARK: - Propriedades de Conveniência

    public var preferencesManager: PreferencesManager {
        coordinator.preferencesManager
    }

    public var isRecording: Bool {
        coordinator.isRecording
    }

    public var currentHotkey: GlobalHotkey {
        coordinator.currentHotkey
    }

    public var errorMessage: String? {
        coordinator.errorMessage
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                // Área de visualização do atalho ou indicador de gravação
                if coordinator.isRecording {
                    recordingBadge
                } else {
                    hotkeyCapsDisplay
                }

                Spacer()

                // Botões de ação
                if coordinator.isRecording {
                    cancelButton
                } else {
                    recordButton
                    resetButton
                }
            }

            // Mensagem de aviso / erro de validação
            if let error = coordinator.errorMessage {
                HStack(spacing: 5) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(.yellow)
                    Text(error)
                        .font(.system(size: 11, weight: .medium, design: .default)) // SF Pro Text <= 19pt
                        .tracking(0.06)
                        .foregroundStyle(.secondary)
                }
                .transition(.opacity)
            }
        }
        .sensoryFeedback(.impact(weight: .medium, intensity: 1.0), trigger: coordinator.feedbackTrigger)
        .onDisappear {
            coordinator.stopRecordingMonitor()
        }
    }

    // MARK: - Subvisões Visuais

    @ViewBuilder
    private var hotkeyCapsDisplay: some View {
        HStack(spacing: 5) {
            let hotkey = coordinator.currentHotkey
            let flags = hotkey.modifierFlags

            if flags.contains(.control) {
                KeyCapView("⌃")
            }
            if flags.contains(.option) {
                KeyCapView("⌥")
            }
            if flags.contains(.shift) {
                KeyCapView("⇧")
            }
            if flags.contains(.command) {
                KeyCapView("⌘")
            }

            KeyCapView(GlobalHotkey.keyName(for: hotkey.keyCode))
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Atalho atual: \(coordinator.currentHotkey.displayString)")
    }

    @ViewBuilder
    private var recordingBadge: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Color.red)
                .frame(width: 8, height: 8)
                .opacity(coordinator.isPulsing ? 1.0 : 0.3)
                .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: coordinator.isPulsing)

            Text("Pressione a nova combinação de teclas...")
                .font(.system(size: 12, weight: .medium, design: .default)) // SF Pro Text <= 19pt
                .tracking(0.0)
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .strokeBorder(Color.accentColor.opacity(0.35), lineWidth: 1)
        )
    }

    @ViewBuilder
    private var recordButton: some View {
        Button {
            coordinator.startRecording()
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "record.circle")
                    .font(.system(size: 12, weight: .medium))
                Text("Gravar Atalho")
                    .font(.system(size: 12, weight: .medium, design: .default)) // SF Pro Text <= 19pt
                    .tracking(-0.08)
            }
            .frame(minHeight: 28)
            .padding(.horizontal, 10)
        }
        .buttonStyle(.borderedProminent)
        .frame(minWidth: 44, minHeight: 44) // Alvo ergonómico Apple HIG >= 44x44pt
        .help("Gravar uma nova combinação de teclas para ativação do Sonotype")
        .accessibilityLabel("Gravar Atalho")
    }

    @ViewBuilder
    private var resetButton: some View {
        Button {
            coordinator.resetToDefault()
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 11, weight: .medium))
                Text("Repor Padrão")
                    .font(.system(size: 12, weight: .regular, design: .default)) // SF Pro Text <= 19pt
                    .tracking(-0.08)
            }
            .frame(minHeight: 28)
            .padding(.horizontal, 8)
        }
        .buttonStyle(.bordered)
        .disabled(coordinator.currentHotkey == .defaultToggle)
        .frame(minWidth: 44, minHeight: 44) // Alvo ergonómico Apple HIG >= 44x44pt
        .help("Restaurar o atalho de ativação padrão (⌥ Espaço)")
        .accessibilityLabel("Repor Padrão")
    }

    @ViewBuilder
    private var cancelButton: some View {
        Button(role: .cancel) {
            coordinator.cancelRecording()
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "xmark.circle")
                    .font(.system(size: 12, weight: .medium))
                Text("Cancelar (Esc)")
                    .font(.system(size: 12, weight: .medium, design: .default)) // SF Pro Text <= 19pt
                    .tracking(-0.08)
            }
            .frame(minHeight: 28)
            .padding(.horizontal, 10)
        }
        .buttonStyle(.bordered)
        .frame(minWidth: 44, minHeight: 44) // Alvo ergonómico Apple HIG >= 44x44pt
        .help("Cancelar modo de gravação sem alterar o atalho atual")
        .accessibilityLabel("Cancelar gravação")
    }

    // MARK: - Métodos de Teste e Controlo Direto

    public func startRecording() {
        coordinator.startRecording()
    }

    public func cancelRecording() {
        coordinator.cancelRecording()
    }

    public func resetToDefault() {
        coordinator.resetToDefault()
    }

    @discardableResult
    public func handleCapturedKeyEvent(
        keyCode: UInt16,
        modifierFlags: NSEvent.ModifierFlags,
        manager: PreferencesManager? = nil
    ) -> Bool {
        if let manager = manager, manager !== coordinator.preferencesManager {
            let tempCoordinator = HotkeyRecorderCoordinator(preferencesManager: manager)
            tempCoordinator.isRecording = true
            return tempCoordinator.handleCapturedKeyEvent(keyCode: keyCode, modifierFlags: modifierFlags)
        }
        return coordinator.handleCapturedKeyEvent(keyCode: keyCode, modifierFlags: modifierFlags)
    }
}
