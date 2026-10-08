import AppKit
import SwiftUI
import os

/// Gestor do item da barra de menus do macOS (NSStatusItem) e do menu Popover rápido associado.
/// Apresenta o ícone de prontidão/escuta, atalhos, e responde aos cliques do utilizador.
@MainActor
public final class MenuBarExtraManager: NSObject, NSPopoverDelegate, Sendable {
    private static let logger = Logger(subsystem: "com.sonotype.app", category: "MenuBarExtraManager")

    public let statusItem: NSStatusItem
    public let popover: NSPopover

    @Published public private(set) var currentState: QuickPopoverState = .idle
    @Published public private(set) var isPopoverShown: Bool = false

    public var onOpenDashboard: (@MainActor @Sendable () -> Void)?
    public var onOpenSettings: (@MainActor @Sendable () -> Void)?
    public var onToggleRecording: (@MainActor @Sendable () -> Void)?
    public var onQuit: (@MainActor @Sendable () -> Void)?

    private var currentLanguage: String = "PT / EN"
    private var hotkeyDisplay: String = "⌥ Espaço"

    public init(
        statusItem: NSStatusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength),
        popover: NSPopover = NSPopover()
    ) {
        self.statusItem = statusItem
        self.popover = popover
        super.init()

        setupStatusItem()
        setupPopover()
    }

    private func setupStatusItem() {
        if let button = statusItem.button {
            button.target = self
            button.action = #selector(handleStatusItemClicked)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            updateStatusItemVisual(state: .idle)
        }
    }

    private func setupPopover() {
        popover.behavior = .transient
        popover.animates = true
        popover.delegate = self
        updatePopoverContent()
    }

    /// Destrói o item da barra de menus, libertando recursos do sistema.
    public func destroy() {
        hidePopover()
        NSStatusBar.system.removeStatusItem(statusItem)
        Self.logger.info("Item da barra de menus destruído")
    }

    /// Atualiza o conteúdo SwiftUI inserido no popover.
    public func updatePopoverContent() {
        let view = QuickPopoverView(
            state: currentState,
            currentLanguage: currentLanguage,
            hotkeyDisplay: hotkeyDisplay,
            onOpenDashboard: { [weak self] in
                self?.hidePopover()
                self?.onOpenDashboard?()
            },
            onOpenSettings: { [weak self] in
                self?.hidePopover()
                self?.onOpenSettings?()
            },
            onToggleRecording: { [weak self] in
                self?.onToggleRecording?()
            },
            onQuit: { [weak self] in
                self?.hidePopover()
                if let onQuit = self?.onQuit {
                    onQuit()
                } else {
                    NSApp?.terminate(nil)
                }
            }
        )

        let hostingController = NSHostingController(rootView: view)
        popover.contentViewController = hostingController
    }

    /// Trata o clique no ícone da barra de menus (toggle popover).
    @objc public func handleStatusItemClicked() {
        if popover.isShown {
            hidePopover()
        } else {
            showPopover()
        }
    }

    /// Exibe o popover ancorado no botão da barra de menus.
    public func showPopover() {
        guard let button = statusItem.button else { return }
        updatePopoverContent()
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        isPopoverShown = true
    }

    /// Oculta o popover da barra de menus.
    public func hidePopover() {
        guard popover.isShown else { return }
        popover.performClose(nil)
        isPopoverShown = false
    }

    /// Atualiza o estado visual e o ícone na barra de menus.
    public func setPlaybackState(_ state: QuickPopoverState) {
        currentState = state
        updateStatusItemVisual(state: state)
        if popover.isShown {
            updatePopoverContent()
        }
    }

    /// Atualiza o idioma e atalho exibidos no popover.
    public func updateDetails(language: String, hotkey: String) {
        currentLanguage = language
        hotkeyDisplay = hotkey
        if popover.isShown {
            updatePopoverContent()
        }
    }

    /// Atualiza o ícone SF Symbol e descrição de acessibilidade do botão.
    private func updateStatusItemVisual(state: QuickPopoverState) {
        guard let button = statusItem.button else { return }

        let symbolName: String
        let accessibilityLabel: String

        switch state {
        case .idle:
            symbolName = "waveform.circle"
            accessibilityLabel = "Sonotype: Pronto para ditar"
        case .recording:
            symbolName = "waveform.circle.fill"
            accessibilityLabel = "Sonotype: A gravar voz"
        case .processing:
            symbolName = "arrow.triangle.2.circlepath"
            accessibilityLabel = "Sonotype: A processar texto"
        }

        let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: accessibilityLabel)
        image?.isTemplate = true
        button.image = image
        button.toolTip = accessibilityLabel
    }

    // MARK: - NSPopoverDelegate

    public func popoverDidShow(_ notification: Notification) {
        isPopoverShown = true
    }

    public func popoverDidClose(_ notification: Notification) {
        isPopoverShown = false
    }

    /// Vincula o gestor da barra de menus aos eventos do RecordingSessionCoordinator.
    public func attach(to coordinator: RecordingSessionCoordinator) {
        self.onToggleRecording = { [weak coordinator] in
            coordinator?.handleHotkeyTrigger()
        }

        let originalStart = coordinator.onStartRecording
        coordinator.onStartRecording = { [weak self] in
            self?.setPlaybackState(.recording)
            originalStart?()
        }

        let originalFinish = coordinator.onFinishRecording
        coordinator.onFinishRecording = { [weak self] reason in
            self?.setPlaybackState(.processing)
            defer {
                self?.setPlaybackState(.idle)
            }
            if let originalFinish = originalFinish {
                await originalFinish(reason)
            }
        }

        let originalCancel = coordinator.onCancelRecording
        coordinator.onCancelRecording = { [weak self] in
            self?.setPlaybackState(.idle)
            originalCancel?()
        }
    }
}
