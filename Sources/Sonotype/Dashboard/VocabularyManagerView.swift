import AppKit
import SwiftUI

/// Vista de gestão de vocabulário técnico e regras de substituição rápida de voz.
/// Permite afinar o motor de reconhecimento e configurar expansões automáticas de texto.
/// Cumpre estritamente Apple HIG, tipografia óptica SF Pro e acessibilidade WCAG 2.1 AA.
public struct VocabularyManagerView: View {
    @Bindable public var viewModel: DashboardViewModel

    // MARK: - Estado Local do Vocabulário
    @State private var selectedTab: Int = 0
    @State private var newWord: String = ""
    @State private var newPriority: Int = 3

    // MARK: - Estado Local das Regras de Substituição
    @State private var newTrigger: String = ""
    @State private var newReplacement: String = ""
    @State private var newIsCaseSensitive: Bool = false

    // MARK: - Triggers de Sensory Feedback
    @State private var addWordFeedbackTrigger: Int = 0
    @State private var addRuleFeedbackTrigger: Int = 0
    @State private var deleteFeedbackTrigger: Int = 0

    public init(viewModel: DashboardViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Seletor de Abas no Topo
            Picker("Secção de Configuração", selection: $selectedTab) {
                Text("Dicionário Personalizado (\(viewModel.vocabularyEntries.count))").tag(0)
                Text("Substituições de Voz (\(viewModel.replacementRules.count))").tag(1)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .background(.regularMaterial)
            .overlay(Divider(), alignment: .bottom)

            // Conteúdo da Aba Selecionada
            ScrollView {
                VStack(spacing: 24) {
                    if selectedTab == 0 {
                        vocabularySection
                    } else {
                        replacementRulesSection
                    }
                }
                .padding(24)
            }
            .background(.thinMaterial)
        }
        .sensoryFeedback(.selection, trigger: selectedTab)
        .sensoryFeedback(.success, trigger: addWordFeedbackTrigger)
        .sensoryFeedback(.success, trigger: addRuleFeedbackTrigger)
        .sensoryFeedback(.impact(weight: .light), trigger: deleteFeedbackTrigger)
    }

    // MARK: - 1. Secção de Vocabulário Personalizado

    @ViewBuilder
    private var vocabularySection: some View {
        VStack(alignment: .leading, spacing: 18) {
            // Cabeçalho da Secção com SF Pro Display (>= 20pt)
            VStack(alignment: .leading, spacing: 4) {
                Text("Vocabulário & Termos Técnicos")
                    .font(.system(size: 20, weight: .bold, design: .default)) // SF Pro Display >= 20pt
                    .tracking(0.38)
                    .foregroundStyle(.primary)

                Text("Adicione siglas, nomes próprios ou jargão técnico para aumentar a prioridade de correspondência durante a transcrição offline.")
                    .font(.system(size: 13, weight: .regular, design: .default)) // SF Pro Text <= 19pt
                    .tracking(-0.08)
                    .foregroundStyle(.secondary)
            }

            // Formulário de Adição
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    TextField("Nova palavra técnica ou nome próprio...", text: $newWord)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 13, weight: .regular, design: .default)) // SF Pro Text <= 19pt
                        .tracking(-0.08)
                        .frame(minHeight: 34)

                    // Seletor de Prioridade
                    Picker("Prioridade", selection: $newPriority) {
                        Text("P1 - Baixa").tag(1)
                        Text("P2 - Normal").tag(2)
                        Text("P3 - Média").tag(3)
                        Text("P4 - Alta").tag(4)
                        Text("P5 - Máxima").tag(5)
                    }
                    .frame(width: 140)

                    // Botão de Submissão (Apple HIG: 44pt touch footprint)
                    Button {
                        submitNewWord()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "plus.circle.fill")
                            Text("Adicionar")
                                .font(.system(size: 13, weight: .semibold, design: .default)) // SF Pro Text <= 19pt
                                .tracking(-0.08)
                        }
                        .padding(.horizontal, 14)
                        .frame(minHeight: 44) // 44pt touch target
                        .background(canAddWord ? Color.accentColor : Color.secondary.opacity(0.2), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .foregroundStyle(canAddWord ? Color.white : Color.secondary)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(!canAddWord)
                    .help("Adicionar novo termo ao dicionário personalizado")
                    .accessibilityLabel("Adicionar palavra ao vocabulário")
                }
            }
            .padding(16)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(.separator, lineWidth: 0.5)
            )

            // Lista de Termos Ativos
            if viewModel.vocabularyEntries.isEmpty {
                emptyVocabularyCard
            } else {
                VStack(spacing: 8) {
                    ForEach(viewModel.vocabularyEntries) { entry in
                        vocabularyEntryRow(entry)
                    }
                }
            }
        }
    }

    private var canAddWord: Bool {
        !newWord.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func submitNewWord() {
        guard canAddWord else { return }
        addWordFeedbackTrigger += 1
        viewModel.addVocabulary(word: newWord, priority: newPriority)
        newWord = ""
    }

    @ViewBuilder
    private func vocabularyEntryRow(_ entry: VocabularyEntry) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "character.book.closed.fill")
                .font(.system(size: 14))
                .foregroundStyle(Color.accentColor)

            Text(entry.word)
                .font(.system(size: 14, weight: .medium, design: .default)) // SF Pro Text <= 19pt
                .tracking(-0.15)
                .foregroundStyle(.primary)

            Spacer()

            // Badge de Prioridade
            Text("Prioridade \(entry.priority)")
                .font(.system(size: 11, weight: .semibold, design: .default)) // SF Pro Text <= 19pt
                .tracking(0.06)
                .foregroundStyle(priorityColor(entry.priority))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(priorityColor(entry.priority).opacity(0.12), in: Capsule())

            // Botão de Eliminar
            Button(role: .destructive) {
                deleteFeedbackTrigger += 1
                viewModel.deleteVocabulary(entry)
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 32, height: 32)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Remover palavra do dicionário")
            .accessibilityLabel("Remover \(entry.word)")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .frame(minHeight: 44) // Alvo interativo mínimo Apple HIG
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(.separator, lineWidth: 0.5)
        )
    }

    private func priorityColor(_ priority: Int) -> Color {
        switch priority {
        case 5: return .red
        case 4: return .orange
        case 3: return .accentColor
        default: return .secondary
        }
    }

    @ViewBuilder
    private var emptyVocabularyCard: some View {
        VStack(spacing: 8) {
            Image(systemName: "character.book.closed")
                .font(.system(size: 28))
                .foregroundStyle(.secondary)
            Text("Sem Termos Personalizados")
                .font(.system(size: 14, weight: .semibold, design: .default)) // SF Pro Text <= 19pt
                .tracking(-0.15)
                .foregroundStyle(.primary)
            Text("Adicione siglas, termos de programação ou nomes para melhorar a taxa de acerto do reconhecimento.")
                .font(.system(size: 12, weight: .regular, design: .default)) // SF Pro Text <= 19pt
                .tracking(0.0)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(32)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(.separator, lineWidth: 0.5)
        )
    }

    // MARK: - 2. Secção de Regras de Substituição Rápida de Voz

    @ViewBuilder
    private var replacementRulesSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            // Cabeçalho da Secção com SF Pro Display (>= 20pt)
            VStack(alignment: .leading, spacing: 4) {
                Text("Regras de Substituição de Voz")
                    .font(.system(size: 20, weight: .bold, design: .default)) // SF Pro Display >= 20pt
                    .tracking(0.38)
                    .foregroundStyle(.primary)

                Text("Defina atalhos falados que são automaticamente expandidos em texto completo (ex: \"meu email\" → \"contacto@sonotype.app\").")
                    .font(.system(size: 13, weight: .regular, design: .default)) // SF Pro Text <= 19pt
                    .tracking(-0.08)
                    .foregroundStyle(.secondary)
            }

            // Formulário de Adição de Regra
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Quando falar...")
                            .font(.system(size: 11, weight: .semibold, design: .default)) // SF Pro Text <= 19pt
                            .tracking(0.06)
                            .foregroundStyle(.secondary)
                        TextField("Gatilho falado (ex: meu email)", text: $newTrigger)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 13, weight: .regular, design: .default)) // SF Pro Text <= 19pt
                            .tracking(-0.08)
                    }

                    Image(systemName: "arrow.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .padding(.top, 16)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Substituir por...")
                            .font(.system(size: 11, weight: .semibold, design: .default)) // SF Pro Text <= 19pt
                            .tracking(0.06)
                            .foregroundStyle(.secondary)
                        TextField("Texto substituído (ex: contacto@exemplo.com)", text: $newReplacement)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 13, weight: .regular, design: .default)) // SF Pro Text <= 19pt
                            .tracking(-0.08)
                    }
                }

                HStack {
                    Toggle("Sensível a maiúsculas/minúsculas", isOn: $newIsCaseSensitive)
                        .font(.system(size: 12, weight: .medium, design: .default)) // SF Pro Text <= 19pt
                        .tracking(0.0)

                    Spacer()

                    Button {
                        submitNewRule()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "plus.circle.fill")
                            Text("Criar Regra")
                                .font(.system(size: 13, weight: .semibold, design: .default)) // SF Pro Text <= 19pt
                                .tracking(-0.08)
                        }
                        .padding(.horizontal, 14)
                        .frame(minHeight: 44) // 44pt touch footprint
                        .background(canAddRule ? Color.accentColor : Color.secondary.opacity(0.2), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .foregroundStyle(canAddRule ? Color.white : Color.secondary)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(!canAddRule)
                    .help("Criar nova regra de substituição de texto por voz")
                    .accessibilityLabel("Criar regra de substituição")
                }
            }
            .padding(16)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(.separator, lineWidth: 0.5)
            )

            // Lista de Regras Ativas
            if viewModel.replacementRules.isEmpty {
                emptyRulesCard
            } else {
                VStack(spacing: 8) {
                    ForEach(viewModel.replacementRules) { rule in
                        ruleEntryRow(rule)
                    }
                }
            }
        }
    }

    private var canAddRule: Bool {
        !newTrigger.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !newReplacement.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func submitNewRule() {
        guard canAddRule else { return }
        addRuleFeedbackTrigger += 1
        viewModel.addReplacementRule(
            trigger: newTrigger,
            replacement: newReplacement,
            isCaseSensitive: newIsCaseSensitive
        )
        newTrigger = ""
        newReplacement = ""
        newIsCaseSensitive = false
    }

    @ViewBuilder
    private func ruleEntryRow(_ rule: WordReplacementRule) -> some View {
        HStack(spacing: 12) {
            // Gatilho
            HStack(spacing: 4) {
                Image(systemName: "quote.opening")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                Text(rule.trigger)
                    .font(.system(size: 13, weight: .semibold, design: .monospaced)) // SF Pro Text <= 19pt
                    .tracking(0.0)
                    .foregroundStyle(.primary)
                Image(systemName: "quote.closing")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 6, style: .continuous))

            Image(systemName: "arrow.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)

            // Substituição
            Text(rule.replacement)
                .font(.system(size: 13, weight: .regular, design: .default)) // SF Pro Text <= 19pt
                .tracking(-0.08)
                .foregroundStyle(.primary)
                .lineLimit(1)

            Spacer()

            if rule.isCaseSensitive {
                Text("Aa")
                    .font(.system(size: 10, weight: .bold, design: .monospaced)) // SF Pro Text <= 19pt
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 4, style: .continuous))
                    .help("Sensível a maiúsculas/minúsculas")
            }

            // Botão de Eliminar
            Button(role: .destructive) {
                deleteFeedbackTrigger += 1
                viewModel.deleteReplacementRule(rule)
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 32, height: 32)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Remover esta regra de substituição")
            .accessibilityLabel("Remover regra para \(rule.trigger)")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .frame(minHeight: 44) // Alvo interativo mínimo Apple HIG
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(.separator, lineWidth: 0.5)
        )
    }

    @ViewBuilder
    private var emptyRulesCard: some View {
        VStack(spacing: 8) {
            Image(systemName: "arrow.triangle.swap")
                .font(.system(size: 28))
                .foregroundStyle(.secondary)
            Text("Sem Regras de Substituição")
                .font(.system(size: 14, weight: .semibold, design: .default)) // SF Pro Text <= 19pt
                .tracking(-0.15)
                .foregroundStyle(.primary)
            Text("Crie regras de substituição automática para expandir atalhos verbais em assinaturas, links ou blocos de texto.")
                .font(.system(size: 12, weight: .regular, design: .default)) // SF Pro Text <= 19pt
                .tracking(0.0)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(32)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(.separator, lineWidth: 0.5)
        )
    }
}
