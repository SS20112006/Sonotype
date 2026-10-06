import AppKit

/// Painel flutuante de sistema sem moldura para exibição do HUD do Sonotype.
/// Configurado como `.nonactivatingPanel` e `.floating` para sobrepor qualquer aplicação
/// sem roubar o foco da janela ativa ou do cursor de inserção.
@MainActor
public final class HUDPanel: NSPanel {
    public init(contentRect: NSRect = NSRect(x: 0, y: 0, width: 280, height: 72)) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        setupPanelProperties()
    }

    private func setupPanelProperties() {
        // Nível flutuante acima de janelas comuns do sistema
        level = .floating
        isFloatingPanel = true

        // Transparência para renderização precisa do material SwiftUI
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false

        // Não esconde quando a aplicação perde o foco
        hidesOnDeactivate = false

        // Presença contínua em todos os espaços de trabalho e apps em ecrã inteiro
        collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
            .transient,
            .ignoresCycle
        ]

        // Impede movimentação acidental e ciclo de tabulação
        isMovableByWindowBackground = false
        isReleasedWhenClosed = false
    }

    // Invariante de foco: O painel HUD nunca deve roubar o foco da janela ativa
    override public var canBecomeKey: Bool {
        false
    }

    override public var canBecomeMain: Bool {
        false
    }

    /// Reposiciona a pílula no centro horizontal inferior do ecrã alvo (ou ecrã principal).
    /// Margem padrão: 72pt acima do fundo da área visível (respeitando a Dock).
    public func repositionToBottomCenter(on screen: NSScreen? = NSScreen.main, bottomMargin: CGFloat = 72.0) {
        guard let targetScreen = screen ?? NSScreen.main else { return }
        let visibleFrame = targetScreen.visibleFrame

        let panelSize = frame.size
        let x = visibleFrame.origin.x + (visibleFrame.size.width - panelSize.width) / 2.0
        let y = visibleFrame.origin.y + bottomMargin

        setFrameOrigin(NSPoint(x: round(x), y: round(y)))
    }
}
