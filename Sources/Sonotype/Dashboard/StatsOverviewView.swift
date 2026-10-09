import AppKit
import SwiftUI

/// Vista de resumo analítico e estatísticas de utilização do Sonotype.
/// Apresenta tempo poupado, total de palavras, sessões e repartição linguística (PT vs EN).
/// Cumpre estritamente Apple HIG, materiais semânticos nativos e tipografia SF Pro calibrada.
public struct StatsOverviewView: View {
    public let viewModel: DashboardViewModel

    public init(viewModel: DashboardViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                // Título da Página com SF Pro Display (>= 20pt)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Estatísticas & Produtividade")
                        .font(.system(size: 20, weight: .bold, design: .default)) // SF Pro Display >= 20pt
                        .tracking(0.35)
                        .foregroundStyle(.primary)

                    Text("Métricas acumuladas de utilização e tempo poupado com o ditado por voz offline.")
                        .font(.system(size: 12, weight: .regular, design: .default)) // SF Pro Text <= 19pt
                        .tracking(0.0)
                        .foregroundStyle(.secondary)
                }

                // Grelha Principal de Métricas Adaptativa
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 220, maximum: 340), spacing: 16)], spacing: 16) {
                    // 1. Tempo Poupado
                    statMetricCard(
                        title: "Tempo Poupado Estimado",
                        value: formattedTimeSaved,
                        subtitle: "Face à velocidade média de dactilografia manual (40 PPM).",
                        icon: "bolt.fill",
                        tint: .orange
                    )

                    // 2. Total de Palavras
                    statMetricCard(
                        title: "Palavras Transcritas",
                        value: viewModel.stats.totalWords.formatted(),
                        subtitle: "Volume global de texto gerado através do ditado.",
                        icon: "text.word.spacing",
                        tint: .blue
                    )

                    // 3. Transcrições e Tempo em Fala
                    statMetricCard(
                        title: "Sessões de Ditado",
                        value: "\(viewModel.stats.totalTranscriptions)",
                        subtitle: formattedSpeechDuration,
                        icon: "waveform.and.mic",
                        tint: .purple
                    )

                    // 4. Velocidade de Fala Efetiva
                    statMetricCard(
                        title: "Velocidade Média em Voz",
                        value: formattedSpeakingWPM,
                        subtitle: "Palavras por minuto ditadas durante as sessões ativas.",
                        icon: "speedometer",
                        tint: .green
                    )
                }

                // Cartão de Repartição Linguística
                languageBreakdownCard

                // Cartão de Garantia de Privacidade Local
                privacyGuaranteeCard
            }
            .padding(20)
            .frame(maxWidth: 1040)
            .frame(maxWidth: .infinity, alignment: .top)
        }
        .background(.thinMaterial)
    }

    // MARK: - Cartão Genérico de Métrica

    @ViewBuilder
    private func statMetricCard(
        title: String,
        value: String,
        subtitle: String,
        icon: String,
        tint: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: 28, height: 28)
                    .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 6, style: .continuous))

                Text(title)
                    .font(.system(size: 13, weight: .medium, design: .default)) // SF Pro Text <= 19pt
                    .tracking(-0.08)
                    .foregroundStyle(.secondary)

                Spacer()
            }

            // Valor Principal com SF Pro Display (>= 20pt)
            Text(value)
                .font(.system(size: 26, weight: .bold, design: .default)) // SF Pro Display >= 20pt
                .tracking(0.38)
                .foregroundStyle(.primary)

            Text(subtitle)
                .font(.system(size: 11, weight: .regular, design: .default)) // SF Pro Text <= 19pt
                .tracking(0.06)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .padding(18)
        .frame(maxWidth: .infinity, minHeight: 120, alignment: .topLeading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(.separator, lineWidth: 0.5)
        )
    }

    // MARK: - Repartição Linguística (Português vs Inglês)

    @ViewBuilder
    private var languageBreakdownCard: some View {
        let totalLangWords = viewModel.stats.portugueseWords + viewModel.stats.englishWords
        let ptFraction = totalLangWords > 0 ? Double(viewModel.stats.portugueseWords) / Double(totalLangWords) : 0.5
        let enFraction = totalLangWords > 0 ? Double(viewModel.stats.englishWords) / Double(totalLangWords) : 0.5

        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: "globe.europe.africa.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 28, height: 28)
                    .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 6, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Repartição Linguística")
                        .font(.system(size: 14, weight: .semibold, design: .default)) // SF Pro Text <= 19pt
                        .tracking(-0.15)
                        .foregroundStyle(.primary)

                    Text("Distribuição de palavras transcritas por deteção de idioma.")
                        .font(.system(size: 12, weight: .regular, design: .default)) // SF Pro Text <= 19pt
                        .tracking(0.0)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }

            // Barra de Proporção Visual Elegante
            GeometryReader { geometry in
                let availableWidth = max(0, geometry.size.width - 3)
                let ptWidth = max(4, availableWidth * ptFraction)
                let enWidth = max(4, availableWidth * enFraction)

                HStack(spacing: 3) {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(Color.accentColor)
                        .frame(width: ptWidth)
                        .help("Português: \(Int(ptFraction * 100))%")

                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(Color.teal)
                        .frame(width: enWidth)
                        .help("Inglês: \(Int(enFraction * 100))%")
                }
            }
            .frame(height: 12)

            // Legenda Detalhada
            HStack(spacing: 24) {
                // Português
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color.accentColor)
                        .frame(width: 10, height: 10)

                    VStack(alignment: .leading, spacing: 1) {
                        Text("Português (PT)")
                            .font(.system(size: 12, weight: .medium, design: .default)) // SF Pro Text <= 19pt
                            .tracking(0.0)
                            .foregroundStyle(.primary)

                        Text("\(viewModel.stats.portugueseWords.formatted()) palavras (\(Int(ptFraction * 100))%)")
                            .font(.system(size: 11, weight: .regular, design: .default)) // SF Pro Text <= 19pt
                            .tracking(0.06)
                            .foregroundStyle(.secondary)
                    }
                }

                // Inglês
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color.teal)
                        .frame(width: 10, height: 10)

                    VStack(alignment: .leading, spacing: 1) {
                        Text("Inglês (EN)")
                            .font(.system(size: 12, weight: .medium, design: .default)) // SF Pro Text <= 19pt
                            .tracking(0.0)
                            .foregroundStyle(.primary)

                        Text("\(viewModel.stats.englishWords.formatted()) palavras (\(Int(enFraction * 100))%)")
                            .font(.system(size: 11, weight: .regular, design: .default)) // SF Pro Text <= 19pt
                            .tracking(0.06)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()
            }
        }
        .padding(18)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(.separator, lineWidth: 0.5)
        )
    }

    // MARK: - Cartão de Garantia de Privacidade

    @ViewBuilder
    private var privacyGuaranteeCard: some View {
        HStack(spacing: 14) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 24))
                .foregroundStyle(.green)
                .frame(width: 44, height: 44) // 44pt target footprint
                .background(Color.green.opacity(0.12), in: Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text("Processamento 100% Local e Privado")
                    .font(.system(size: 13, weight: .semibold, design: .default)) // SF Pro Text <= 19pt
                    .tracking(-0.08)
                    .foregroundStyle(.primary)

                Text("Todo o áudio é processado estritamente na memória RAM com zero retenção de ficheiros de áudio em disco e zero transmissão pela rede.")
                    .font(.system(size: 11, weight: .regular, design: .default)) // SF Pro Text <= 19pt
                    .tracking(0.06)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(.separator, lineWidth: 0.5)
        )
    }

    // MARK: - Formatadores Auxiliares

    private var formattedTimeSaved: String {
        let minutes = viewModel.stats.estimatedTimeSavedMinutes
        if minutes < 1.0 {
            return "< 1 min"
        } else if minutes < 60.0 {
            return "\(Int(minutes)) min"
        } else {
            let hours = minutes / 60.0
            return String(format: "%.1f h", hours)
        }
    }

    private var formattedSpeechDuration: String {
        let seconds = viewModel.stats.totalDurationSeconds
        if seconds < 60.0 {
            return String(format: "%.1fs em fala ativa acumulada.", seconds)
        } else {
            let mins = Int(seconds) / 60
            let remainingSecs = Int(seconds) % 60
            return "\(mins)m \(remainingSecs)s em fala ativa acumulada."
        }
    }

    private var formattedSpeakingWPM: String {
        let seconds = viewModel.stats.totalDurationSeconds
        let words = viewModel.stats.totalWords
        guard seconds > 2.0 && words > 0 else {
            return "-- PPM"
        }
        let wpm = Double(words) / (seconds / 60.0)
        return "\(Int(wpm)) PPM"
    }
}
