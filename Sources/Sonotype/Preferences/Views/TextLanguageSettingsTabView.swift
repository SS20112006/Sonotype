import SwiftUI

/// Aba de Definições de Texto e Idioma do Sonotype.
/// Configura o modelo de idioma, estilo de feedback visual do HUD e filtros de pós-processamento de texto.
@MainActor
public struct TextLanguageSettingsTabView: View {
    @ObservedObject public var preferencesManager: PreferencesManager

    public init(preferencesManager: PreferencesManager) {
        self.preferencesManager = preferencesManager
    }

    public var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                // Secção 1: Reconhecimento e Idioma
                SettingsCard(
                    title: "Reconhecimento & Interface",
                    icon: "globe",
                    footer: "O Sonotype opera 100% offline no dispositivo sem recorrer a serviços na nuvem."
                ) {
                    SettingsRow(
                        title: "Idioma Primário",
                        subtitle: "Resolução do idioma para transcrição da fala"
                    ) {
                        Picker("", selection: Binding(
                            get: { preferencesManager.languageSelectionMode },
                            set: { preferencesManager.languageSelectionMode = $0 }
                        )) {
                            Text("Deteção Automática (PT / EN)").tag(LanguageSelectionMode.autoDetect)
                            Text("Português Fixo (pt-PT)").tag(LanguageSelectionMode.fixedPT)
                            Text("Inglês Fixo (en-US)").tag(LanguageSelectionMode.fixedEN)
                        }
                        .pickerStyle(.menu)
                        .frame(minWidth: 205)
                        .accessibilityLabel("Idioma Primário")
                    }

                    Divider()
                        .padding(.vertical, 4)

                    SettingsRow(
                        title: "Feedback Visual do HUD",
                        subtitle: "Estilo da pílula flutuante durante a ditado"
                    ) {
                        Picker("", selection: Binding(
                            get: { preferencesManager.hudFeedbackMode },
                            set: { preferencesManager.hudFeedbackMode = $0 }
                        )) {
                            Text("Apenas onda sonora pulsante").tag(HUDFeedbackMode.waveformOnly)
                            Text("Texto em tempo real na pílula").tag(HUDFeedbackMode.liveTranscription)
                            Text("Digitação direta no cursor").tag(HUDFeedbackMode.directCursor)
                        }
                        .pickerStyle(.menu)
                        .frame(minWidth: 215)
                        .accessibilityLabel("Feedback Visual do HUD")
                    }
                }

                // Secção 2: Pós-processamento de Texto
                SettingsCard(
                    title: "Polimento e Formatação Automática",
                    icon: "text.badge.checkmark",
                    footer: "As regras de formatação são aplicadas instantaneamente antes da inserção do texto no cursor."
                ) {
                    SettingsRow(
                        title: "Pontuação Oral",
                        subtitle: "Converter comandos orais (vírgula, ponto, nova linha)"
                    ) {
                        Toggle("", isOn: Binding(
                            get: { preferencesManager.oralCommandsEnabled },
                            set: { preferencesManager.oralCommandsEnabled = $0 }
                        ))
                        .toggleStyle(.switch)
                        .accessibilityLabel("Pontuação Oral")
                    }

                    Divider()
                        .padding(.vertical, 4)

                    SettingsRow(
                        title: "Filtro de Hesitações",
                        subtitle: "Eliminar hesitações (hum, ãh, tipo)"
                    ) {
                        Toggle("", isOn: Binding(
                            get: { preferencesManager.fillerFilterEnabled },
                            set: { preferencesManager.fillerFilterEnabled = $0 }
                        ))
                        .toggleStyle(.switch)
                        .accessibilityLabel("Filtro de Hesitações")
                    }

                    Divider()
                        .padding(.vertical, 4)

                    SettingsRow(
                        title: "Capitalização Automática",
                        subtitle: "Capitalizar primeira letra de frases e pontuação"
                    ) {
                        Toggle("", isOn: Binding(
                            get: { preferencesManager.autoCapitalizationEnabled },
                            set: { preferencesManager.autoCapitalizationEnabled = $0 }
                        ))
                        .toggleStyle(.switch)
                        .accessibilityLabel("Capitalização Automática")
                    }

                    Divider()
                        .padding(.vertical, 4)

                    SettingsRow(
                        title: "Ponto Final Automático",
                        subtitle: "Inserir ponto final no fecho do ditado se ausente"
                    ) {
                        Toggle("", isOn: Binding(
                            get: { preferencesManager.autoFinalPeriodEnabled },
                            set: { preferencesManager.autoFinalPeriodEnabled = $0 }
                        ))
                        .toggleStyle(.switch)
                        .accessibilityLabel("Ponto Final Automático")
                    }
                }
            }
            .padding(18)
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity, alignment: .top)
        }
    }
}
