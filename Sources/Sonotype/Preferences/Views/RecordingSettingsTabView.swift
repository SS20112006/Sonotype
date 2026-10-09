import SwiftUI

/// Aba de Definições de Gravação do Sonotype.
/// Configura o modo de ativação, atalho global do teclado, timeout de silêncio e feedback sonoro.
@MainActor
public struct RecordingSettingsTabView: View {
    @ObservedObject public var preferencesManager: PreferencesManager

    public init(preferencesManager: PreferencesManager) {
        self.preferencesManager = preferencesManager
    }

    public var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                // Secção 1: Modo de Acionamento
                SettingsCard(
                    title: "Modo de Acionamento",
                    icon: "hand.tap",
                    footer: triggerModeExplanation(for: preferencesManager.triggerMode)
                ) {
                    SettingsRow(
                        title: "Modo de Gravação",
                        subtitle: "Comportamento do atalho de teclado durante a fala"
                    ) {
                        Picker("", selection: Binding(
                            get: { preferencesManager.triggerMode },
                            set: { preferencesManager.triggerMode = $0 }
                        )) {
                            Text("Alternar (1 toque inicia, 1 toque para)").tag(RecordingTriggerMode.toggle)
                            Text("Pressionar para Falar").tag(RecordingTriggerMode.pushToTalk)
                        }
                        .pickerStyle(.menu)
                        .frame(minWidth: 220)
                        .accessibilityLabel("Modo de Gravação")
                    }
                }

                // Secção 2: Atalho Global de Teclado
                SettingsCard(
                    title: "Atalho de Teclado Global",
                    icon: "keyboard",
                    footer: "Atalho global do macOS para iniciar ou parar o ditado em qualquer aplicação."
                ) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Combinação de Ativação")
                                .font(.system(size: 13, weight: .medium, design: .default)) // SF Pro Text <= 19pt
                                .tracking(-0.08)
                                .foregroundStyle(.primary)
                            Spacer()
                        }
                        HotkeyRecorderView(preferencesManager: preferencesManager)
                    }
                    .padding(.vertical, 4)
                }

                // Secção 3: Silêncio e Feedback de Áudio
                SettingsCard(
                    title: "Proteção & Sons",
                    icon: "speaker.wave.2",
                    footer: "A proteção de silêncio finaliza e insere a transcrição automaticamente se deixar de falar."
                ) {
                    SettingsRow(
                        title: "Proteção de Silêncio Contínuo",
                        subtitle: "Tempo de silêncio antes de terminar a gravação"
                    ) {
                        Picker("", selection: Binding<Double?>(
                            get: { preferencesManager.silenceTimeoutSeconds },
                            set: { preferencesManager.silenceTimeoutSeconds = $0 }
                        )) {
                            Text("15 segundos").tag(Optional(15.0))
                            Text("30 segundos").tag(Optional(30.0))
                            Text("45 segundos (Padrão)").tag(Optional(45.0))
                            Text("60 segundos").tag(Optional(60.0))
                            Text("Desativado").tag(Double?.none)
                        }
                        .pickerStyle(.menu)
                        .frame(minWidth: 175)
                        .accessibilityLabel("Proteção de Silêncio Contínuo")
                    }

                    Divider()
                        .padding(.vertical, 4)

                    SettingsRow(
                        title: "Feedback Sonoro",
                        subtitle: "Reproduzir sons nativos ao iniciar e parar"
                    ) {
                        Toggle("", isOn: Binding(
                            get: { preferencesManager.soundFeedbackEnabled },
                            set: { preferencesManager.soundFeedbackEnabled = $0 }
                        ))
                        .toggleStyle(.switch)
                        .accessibilityLabel("Feedback Sonoro")
                    }
                }
            }
            .padding(18)
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity, alignment: .top)
        }
    }

    private func triggerModeExplanation(for mode: RecordingTriggerMode) -> String {
        switch mode {
        case .toggle:
            return "Modo Alternar: Toque uma vez no atalho para iniciar o ditado e toque novamente quando terminar de falar."
        case .pushToTalk:
            return "Modo Pressionar para Falar: Mantenha as teclas premidas enquanto fala e solte para inserir o texto no cursor."
        }
    }
}
