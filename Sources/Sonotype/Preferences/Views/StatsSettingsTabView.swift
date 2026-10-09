import SwiftUI

/// Aba de Definições de Estatísticas do Sonotype.
/// Permite personalizar a visibilidade de widgets e blocos analíticos apresentados no Dashboard.
@MainActor
public struct StatsSettingsTabView: View {
    @ObservedObject public var preferencesManager: PreferencesManager

    public init(preferencesManager: PreferencesManager) {
        self.preferencesManager = preferencesManager
    }

    public var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                SettingsCard(
                    title: "Personalização do Dashboard",
                    icon: "chart.bar.xaxis",
                    footer: "Ative ou desative os cartões analíticos exibidos na secção de Estatísticas do Dashboard."
                ) {
                    SettingsRow(
                        title: "Tempo Estimado Poupado",
                        subtitle: "Exibe horas e minutos poupados face à velocidade média de digitação"
                    ) {
                        Toggle("", isOn: Binding(
                            get: { preferencesManager.metricsVisibility.timeSaved },
                            set: {
                                var updated = preferencesManager.metricsVisibility
                                updated.timeSaved = $0
                                preferencesManager.metricsVisibility = updated
                            }
                        ))
                        .toggleStyle(.switch)
                        .accessibilityLabel("Tempo Estimado Poupado")
                    }

                    Divider()
                        .padding(.vertical, 4)

                    SettingsRow(
                        title: "Total de Palavras Transcritas",
                        subtitle: "Contador acumulado de palavras ditadas com sucesso"
                    ) {
                        Toggle("", isOn: Binding(
                            get: { preferencesManager.metricsVisibility.totalWords },
                            set: {
                                var updated = preferencesManager.metricsVisibility
                                updated.totalWords = $0
                                preferencesManager.metricsVisibility = updated
                            }
                        ))
                        .toggleStyle(.switch)
                        .accessibilityLabel("Total de Palavras Transcritas")
                    }

                    Divider()
                        .padding(.vertical, 4)

                    SettingsRow(
                        title: "Sessões Realizadas",
                        subtitle: "Número total de sessões de voz iniciadas e processadas"
                    ) {
                        Toggle("", isOn: Binding(
                            get: { preferencesManager.metricsVisibility.sessionsCount },
                            set: {
                                var updated = preferencesManager.metricsVisibility
                                updated.sessionsCount = $0
                                preferencesManager.metricsVisibility = updated
                            }
                        ))
                        .toggleStyle(.switch)
                        .accessibilityLabel("Sessões Realizadas")
                    }

                    Divider()
                        .padding(.vertical, 4)

                    SettingsRow(
                        title: "Velocidade de Fala",
                        subtitle: "Ritmo médio de elocução medido em palavras por minuto (PPM)"
                    ) {
                        Toggle("", isOn: Binding(
                            get: { preferencesManager.metricsVisibility.speakingSpeed },
                            set: {
                                var updated = preferencesManager.metricsVisibility
                                updated.speakingSpeed = $0
                                preferencesManager.metricsVisibility = updated
                            }
                        ))
                        .toggleStyle(.switch)
                        .accessibilityLabel("Velocidade de Fala")
                    }

                    Divider()
                        .padding(.vertical, 4)

                    SettingsRow(
                        title: "Divisão entre Idiomas",
                        subtitle: "Gráfico de distribuição percentual entre Português e Inglês"
                    ) {
                        Toggle("", isOn: Binding(
                            get: { preferencesManager.metricsVisibility.languageBreakdown },
                            set: {
                                var updated = preferencesManager.metricsVisibility
                                updated.languageBreakdown = $0
                                preferencesManager.metricsVisibility = updated
                            }
                        ))
                        .toggleStyle(.switch)
                        .accessibilityLabel("Divisão entre Idiomas")
                    }
                }
            }
            .padding(18)
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity, alignment: .top)
        }
    }
}
