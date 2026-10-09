import SwiftUI

/// Aba de Definições de Clipboard e Injeção do Sonotype.
/// Configura o modo de salvaguarda da área de transferência e o método de injeção de texto no cursor.
@MainActor
public struct ClipboardSettingsTabView: View {
    @ObservedObject public var preferencesManager: PreferencesManager

    public init(preferencesManager: PreferencesManager) {
        self.preferencesManager = preferencesManager
    }

    public var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                // Secção 1: Salvaguarda da Área de Transferência
                SettingsCard(
                    title: "Salvaguarda do Clipboard",
                    icon: "doc.on.clipboard",
                    footer: clipboardModeExplanation(for: preferencesManager.clipboardSafetyMode)
                ) {
                    SettingsRow(
                        title: "Modo de Salvaguarda",
                        subtitle: "Gestão do conteúdo da área de transferência ao ditar"
                    ) {
                        Picker("", selection: Binding(
                            get: { preferencesManager.clipboardSafetyMode },
                            set: { preferencesManager.clipboardSafetyMode = $0 }
                        )) {
                            Text("Modo A: Colar e manter cópia no Clipboard (Cmd+V)").tag(ClipboardSafetyMode.pasteAndKeep)
                            Text("Modo B: Preservar e restaurar clipboard anterior").tag(ClipboardSafetyMode.preservePrevious)
                        }
                        .pickerStyle(.menu)
                        .frame(minWidth: 260)
                        .accessibilityLabel("Modo de Salvaguarda do Clipboard")
                    }
                }

                // Secção 2: Estratégia de Injeção de Texto
                SettingsCard(
                    title: "Estratégia de Injeção",
                    icon: "cursorarrow.rays",
                    footer: injectionStrategyExplanation(for: preferencesManager.textInjectionStrategy)
                ) {
                    SettingsRow(
                        title: "Método de Inserção",
                        subtitle: "Mecanismo utilizado para inserir o texto na aplicação ativa"
                    ) {
                        Picker("", selection: Binding(
                            get: { preferencesManager.textInjectionStrategy },
                            set: { preferencesManager.textInjectionStrategy = $0 }
                        )) {
                            Text("Acessibilidade com fallback").tag(TextInjectionStrategy.accessibilityWithFallback)
                            Text("Apenas Acessibilidade").tag(TextInjectionStrategy.accessibilityOnly)
                            Text("Apenas Eventos de Teclado").tag(TextInjectionStrategy.keystrokeOnly)
                        }
                        .pickerStyle(.menu)
                        .frame(minWidth: 220)
                        .accessibilityLabel("Estratégia de Injeção de Texto")
                    }
                }
            }
            .padding(18)
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity, alignment: .top)
        }
    }

    private func clipboardModeExplanation(for mode: ClipboardSafetyMode) -> String {
        switch mode {
        case .pasteAndKeep:
            return "Modo A (Padrão): O texto transcrito é colado no cursor e permanece disponível na área de transferência para reutilização rápida caso a janela de destino mude."
        case .preservePrevious:
            return "Modo B: O Sonotype guarda um instantâneo do que tinha copiado anteriormente e restaura fielmente o histórico após a colagem do ditado."
        }
    }

    private func injectionStrategyExplanation(for strategy: TextInjectionStrategy) -> String {
        switch strategy {
        case .accessibilityWithFallback:
            return "Recomendado: Tenta inserir diretamente via API de Acessibilidade macOS (AXUIElement); se o campo ativo não suportar, recorre automaticamente à simulação de teclado Cmd+V."
        case .accessibilityOnly:
            return "Apenas Acessibilidade: Insere estritamente via AXUIElement sem nunca recorrer a simulação de teclas nem alterar o clipboard."
        case .keystrokeOnly:
            return "Apenas Eventos de Teclado: Simula diretamente o atalho Cmd+V via eventos do sistema (CGEvent)."
        }
    }
}
