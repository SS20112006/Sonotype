import SwiftUI

@main
struct SonotypeApp: App {
    var body: some Scene {
        WindowGroup {
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

            // Status Card with Native macOS Semantic Material
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Circle()
                        .fill(isReady ? Color.green : Color.orange)
                        .frame(width: 10, height: 10)
                    Text(isReady ? "Motor de Áudio Pronto" : "A Inicializar...")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.primary)
                    Spacer()
                    Text("PT / EN")
                        .font(.system(size: 11, weight: .medium))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.quaternary, in: Capsule())
                }

                Text("Prima Option + Espaço para alternar o ditado ou consulte as definições.")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            .padding(14)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(.separator, lineWidth: 0.5)
            )

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
                        .font(.system(size: 14, weight: .semibold)) // SF Pro Text <= 19pt
                }
                .frame(maxWidth: .infinity)
                .frame(minHeight: 44) // 44x44pt touch target requirement
                .background(.tint, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
            .sensoryFeedback(.impact(weight: .light, intensity: 1.0), trigger: hapticTrigger)
        }
        .padding(24)
        .frame(width: 380)
        .background(.regularMaterial)
    }
}
