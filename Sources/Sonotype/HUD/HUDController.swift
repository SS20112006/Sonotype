import AppKit
import SwiftUI
import os

/// Modelo observável de estado visual da pílula HUD.
@MainActor
public final class HUDViewModel: ObservableObject, Sendable {
    @Published public var isVisible: Bool = false
    @Published public var displayState: HUDDisplayState = .idle
    @Published public var amplitude: Float = 0.0
    @Published public var configuration: HUDConfiguration = HUDConfiguration()

    public init() {}
}

/// Content wrapper com animações fluidas de entrada e saída com curvas .spring().
public struct HUDContainerView: View {
    @ObservedObject public var viewModel: HUDViewModel

    public init(viewModel: HUDViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        Group {
            if viewModel.isVisible {
                FloatingPillHUDView(
                    state: viewModel.displayState,
                    amplitude: viewModel.amplitude,
                    config: viewModel.configuration
                )
                .transition(
                    .asymmetric(
                        insertion: .scale(scale: 0.88).combined(with: .opacity).combined(with: .offset(y: 10)),
                        removal: .scale(scale: 0.92).combined(with: .opacity).combined(with: .offset(y: 6))
                    )
                )
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: viewModel.isVisible)
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: viewModel.displayState)
        .frame(minWidth: 260, minHeight: 64)
        .padding(10)
    }
}

/// Controlador do ciclo de vida da Pílula Flutuante HUD.
/// Faz a ponte entre os eventos da sessão de gravação, a janela `HUDPanel`
/// e a interface SwiftUI com animações spring.
@MainActor
public final class HUDController: Sendable {
    private static let logger = Logger(subsystem: "com.sonotype.app", category: "HUDController")

    public let panel: HUDPanel
    public let viewModel: HUDViewModel

    private var hideTask: Task<Void, Never>?

    public init(
        panel: HUDPanel = HUDPanel(),
        viewModel: HUDViewModel = HUDViewModel()
    ) {
        self.panel = panel
        self.viewModel = viewModel

        setupHostingView()
    }

    private func setupHostingView() {
        let container = HUDContainerView(viewModel: viewModel)
        let hostingView = NSHostingView(rootView: container)
        hostingView.frame = panel.contentView?.bounds ?? NSRect(x: 0, y: 0, width: 280, height: 72)
        hostingView.autoresizingMask = [.width, .height]

        panel.contentView = hostingView
    }

    /// Exibe a pílula HUD animada no centro inferior do ecrã.
    public func show(state: HUDDisplayState = .recording) {
        hideTask?.cancel()
        hideTask = nil

        viewModel.displayState = state
        panel.repositionToBottomCenter()
        panel.orderFrontRegardless()

        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            viewModel.isVisible = true
        }
        Self.logger.debug("HUD exibido com estado: \(state.rawValue, privacy: .public)")
    }

    /// Oculta a pílula HUD com transição fluida de saída.
    public func hide(animated: Bool = true) {
        hideTask?.cancel()

        if animated {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                viewModel.isVisible = false
            }

            // Aguarda o término da animação spring para recolher a janela do compositor
            hideTask = Task { @MainActor [weak self] in
                do {
                    try await Task.sleep(nanoseconds: 350_000_000)
                } catch {
                    return
                }
                guard !Task.isCancelled, let self = self, !self.viewModel.isVisible else { return }
                self.panel.orderOut(nil)
                self.viewModel.displayState = .idle
                self.viewModel.amplitude = 0.0
            }
        } else {
            viewModel.isVisible = false
            panel.orderOut(nil)
            viewModel.displayState = .idle
            viewModel.amplitude = 0.0
        }
        Self.logger.debug("HUD ocultado")
    }

    /// Atualiza a amplitude vocal em tempo real (0.0 a 1.0) para alimentar a animação C1.
    public func updateAmplitude(_ amplitude: Float) {
        guard viewModel.isVisible, viewModel.displayState == .recording else { return }
        viewModel.amplitude = min(max(amplitude, 0.0), 1.0)
    }

    /// Transita para o estado de processamento de texto.
    public func setProcessing() {
        hideTask?.cancel()
        withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
            viewModel.displayState = .processing
            viewModel.amplitude = 0.0
        }
    }

    /// Exibe brevemente o estado cancelado e recolhe a pílula automaticamente.
    public func setCancelled() {
        hideTask?.cancel()
        withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
            viewModel.displayState = .cancelled
            viewModel.amplitude = 0.0
        }

        hideTask = Task { @MainActor [weak self] in
            do {
                try await Task.sleep(nanoseconds: 500_000_000)
            } catch {
                return
            }
            guard !Task.isCancelled, let self = self else { return }
            self.hide()
        }
    }

    /// Reinicia todos os estados visuais.
    public func reset() {
        hide(animated: false)
    }

    /// Vincula o controlador do HUD aos eventos do RecordingSessionCoordinator.
    public func attach(to coordinator: RecordingSessionCoordinator) {
        let originalStart = coordinator.onStartRecording
        coordinator.onStartRecording = { [weak self] in
            self?.show(state: .recording)
            originalStart?()
        }

        let originalFinish = coordinator.onFinishRecording
        coordinator.onFinishRecording = { [weak self] reason in
            self?.setProcessing()
            defer {
                self?.hide()
            }
            if let originalFinish = originalFinish {
                await originalFinish(reason)
            }
        }

        let originalCancel = coordinator.onCancelRecording
        coordinator.onCancelRecording = { [weak self] in
            self?.setCancelled()
            originalCancel?()
        }

        let originalAmplitude = coordinator.onAmplitudeChanged
        coordinator.onAmplitudeChanged = { [weak self] amplitude in
            self?.updateAmplitude(amplitude)
            originalAmplitude?(amplitude)
        }
    }
}
