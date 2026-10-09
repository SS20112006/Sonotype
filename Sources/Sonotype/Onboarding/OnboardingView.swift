import AppKit
import SwiftUI

/// Ecrã visual de boas-vindas e configuração passo a passo (Onboarding) do Sonotype.
/// Desenhado rigorosamente de acordo com a Apple HIG:
/// - SF Pro Text (<= 19pt) e SF Pro Display (>= 20pt)
/// - Materiais translúcidos (.regularMaterial) e paleta semântica
/// - Alvos mínimos de toque/clique de 44x44pt
/// - Feedback tátil / sensorial nos botões de navegação
public struct OnboardingView: View {
    @ObservedObject public var viewModel: OnboardingViewModel

    public init(viewModel: OnboardingViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Cabeçalho / Indicador de Passos
            stepIndicatorHeader
                .padding(.top, 28)
                .padding(.horizontal, 32)

            Spacer(minLength: 16)

            // Conteúdo Específico do Passo Atual
            VStack(spacing: 20) {
                switch viewModel.currentStep {
                case .microphone:
                    microphoneStepView
                case .accessibility:
                    accessibilityStepView
                case .playground:
                    playgroundStepView
                }
            }
            .padding(.horizontal, 40)
            .animation(.easeInOut(duration: 0.25), value: viewModel.currentStep)

            // Mensagem de Erro / Aviso
            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.system(size: 13, weight: .medium, design: .default))
                    .foregroundStyle(Color.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .padding(.top, 12)
            }

            Spacer(minLength: 16)

            // Barra Inferior de Navegação
            bottomNavigationFooter
                .padding(.horizontal, 32)
                .padding(.bottom, 24)
        }
        .frame(width: 580, height: 520)
        .background(.regularMaterial)
        .onAppear {
            viewModel.startPolling()
        }
        .onDisappear {
            viewModel.stopPolling()
        }
    }

    // MARK: - Cabeçalho do Indicador de Passos

    private var stepIndicatorHeader: some View {
        HStack(spacing: 16) {
            ForEach(OnboardingStep.allCases, id: \.self) { step in
                Button {
                    viewModel.goToStep(step)
                } label: {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(stepIndicatorColor(for: step))
                            .frame(width: 24, height: 24)
                            .overlay(
                                Group {
                                    if step < viewModel.currentStep {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundStyle(Color.white)
                                    } else {
                                        Text("\(step.rawValue)")
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundStyle(step == viewModel.currentStep ? Color.white : Color.primary.opacity(0.75))
                                    }
                                }
                            )
                            .accessibilityHidden(true)

                        Text(step.title)
                            .font(.system(size: 14, weight: step == viewModel.currentStep ? .semibold : .regular))
                            .tracking(-0.15) // SF Pro Text tracking
                            .foregroundStyle(step == viewModel.currentStep ? Color.primary : Color.secondary)
                    }
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Passo \(step.rawValue): \(step.title)")
                .accessibilityValue(stepStatusDescription(for: step))
                .accessibilityHint("Clique para navegar para o passo \(step.title)")
                .sensoryFeedback(.selection, trigger: viewModel.currentStep)

                if step != .playground {
                    Rectangle()
                        .fill(Color.primary.opacity(0.12))
                        .frame(height: 1)
                        .frame(maxWidth: .infinity)
                        .accessibilityHidden(true)
                }
            }
        }
    }

    private func stepIndicatorColor(for step: OnboardingStep) -> Color {
        if step == viewModel.currentStep {
            return Color.accentColor
        } else if step < viewModel.currentStep {
            return Color.green
        } else {
            return Color.secondary.opacity(0.25)
        }
    }

    private func stepStatusDescription(for step: OnboardingStep) -> String {
        if step == viewModel.currentStep {
            return "Passo atual"
        } else if step < viewModel.currentStep {
            return "Concluído"
        } else {
            return "Pendente"
        }
    }

    // MARK: - Passo 1: Microfone

    private var microphoneStepView: some View {
        VStack(spacing: 16) {
            Image(systemName: "mic.circle.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 72, height: 72)
                .foregroundStyle((viewModel.isMicrophoneAuthorized && viewModel.isSpeechAuthorized) ? Color.green : Color.accentColor)
                .accessibilityHidden(true)

            Text("Acesso ao Microfone")
                .font(.system(size: 22, weight: .bold)) // SF Pro Display >= 20pt
                .tracking(0.35) // Display tracking
                .foregroundStyle(Color.primary)

            Text(OnboardingStep.microphone.stepDescription)
                .font(.system(size: 14, weight: .regular)) // SF Pro Text <= 19pt
                .tracking(-0.15) // Text tracking
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 16) {
                Button {
                    Task {
                        await viewModel.requestMicrophoneAccess()
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: (viewModel.isMicrophoneAuthorized && viewModel.isSpeechAuthorized) ? "checkmark.circle.fill" : "mic.fill")
                        Text((viewModel.isMicrophoneAuthorized && viewModel.isSpeechAuthorized) ? "Autorizado" : "Permitir Microfone")
                            .font(.system(size: 13, weight: .medium))
                            .tracking(-0.08)
                    }
                    .frame(minWidth: 160, minHeight: 44) // Target >= 44pt
                }
                .buttonStyle(.borderedProminent)
                .tint((viewModel.isMicrophoneAuthorized && viewModel.isSpeechAuthorized) ? .green : .accentColor)
                .disabled(viewModel.isMicrophoneAuthorized && viewModel.isSpeechAuthorized)
                .sensoryFeedback(.success, trigger: viewModel.isMicrophoneAuthorized && viewModel.isSpeechAuthorized)

                if !viewModel.isMicrophoneAuthorized {
                    Button {
                        viewModel.openSystemSettings(for: .microphone)
                    } label: {
                        Text("Abrir Definições")
                            .font(.system(size: 13, weight: .medium))
                            .tracking(-0.08)
                            .frame(minWidth: 140, minHeight: 44) // Target >= 44pt
                    }
                    .buttonStyle(.bordered)
                } else if !viewModel.isSpeechAuthorized {
                    Button {
                        viewModel.openSystemSettings(for: .speechRecognition)
                    } label: {
                        Text("Definições de Fala")
                            .font(.system(size: 13, weight: .medium))
                            .tracking(-0.08)
                            .frame(minWidth: 140, minHeight: 44) // Target >= 44pt
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding(.top, 8)
        }
    }

    // MARK: - Passo 2: Acessibilidade

    private var accessibilityStepView: some View {
        VStack(spacing: 14) {
            Image(systemName: "accessibility.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 56, height: 56)
                .foregroundStyle(viewModel.isAccessibilityAuthorized ? Color.green : Color.accentColor)
                .accessibilityHidden(true)

            Text("Controlo de Acessibilidade")
                .font(.system(size: 22, weight: .bold)) // SF Pro Display >= 20pt
                .tracking(0.35) // Display tracking
                .foregroundStyle(Color.primary)

            Text(OnboardingStep.accessibility.stepDescription)
                .font(.system(size: 14, weight: .regular)) // SF Pro Text <= 19pt
                .tracking(-0.15) // Text tracking
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            if viewModel.isAccessibilityAuthorized {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.green)
                    Text("Acessibilidade Autorizada")
                        .font(.system(size: 13, weight: .medium))
                        .tracking(-0.08)
                }
                .frame(minWidth: 160, minHeight: 44)
                .padding(.top, 4)
            } else {
                HStack(spacing: 12) {
                    Button {
                        viewModel.requestAccessibilityAccess()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "lock.open.fill")
                            Text("Solicitar Acesso")
                                .font(.system(size: 13, weight: .medium))
                                .tracking(-0.08)
                        }
                        .frame(minWidth: 130, minHeight: 44) // Target >= 44pt
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.accentColor)

                    Button {
                        viewModel.openSystemSettings(for: .accessibility)
                    } label: {
                        Text("Abrir Definições")
                            .font(.system(size: 13, weight: .medium))
                            .tracking(-0.08)
                            .frame(minWidth: 120, minHeight: 44) // Target >= 44pt
                    }
                    .buttonStyle(.bordered)

                    Button {
                        viewModel.refreshStatuses()
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "arrow.clockwise")
                            Text("Verificar Novamente")
                                .font(.system(size: 13, weight: .medium))
                                .tracking(-0.08)
                        }
                        .frame(minWidth: 140, minHeight: 44) // Target >= 44pt
                    }
                    .buttonStyle(.bordered)
                }
                .sensoryFeedback(.selection, trigger: viewModel.isAccessibilityAuthorized)

                VStack(spacing: 8) {
                    Text("Nota: Se o Sonotype já constar na lista de Acessibilidade das Definições do Sistema de uma versão anterior, o macOS requer desativar e voltar a ativar o botão uma vez para atualizar a cache do sistema. Em alternativa, pode clicar em 'Continuar mesmo assim'.")
                        .font(.system(size: 11, weight: .regular))
                        .tracking(-0.1)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 16)

                    Button {
                        viewModel.forceAdvanceToPlayground()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.forward.circle")
                            Text("Continuar mesmo assim")
                                .font(.system(size: 13, weight: .medium))
                                .tracking(-0.08)
                        }
                        .frame(minWidth: 180, minHeight: 44) // Target >= 44pt
                    }
                    .buttonStyle(.bordered)
                    .sensoryFeedback(.impact, trigger: viewModel.currentStep)
                }
                .padding(.top, 4)
            }
        }
    }

    // MARK: - Passo 3: Playground de Testes

    private var playgroundStepView: some View {
        VStack(spacing: 16) {
            SonotypeBrandLogoView(size: 64)
                .shadow(color: Color.black.opacity(0.18), radius: 6, x: 0, y: 3)

            Text("Campo de Teste")
                .font(.system(size: 22, weight: .bold)) // SF Pro Display >= 20pt
                .tracking(0.35) // Display tracking
                .foregroundStyle(Color.primary)

            Text(OnboardingStep.playground.stepDescription)
                .font(.system(size: 14, weight: .regular)) // SF Pro Text <= 19pt
                .tracking(-0.15) // Text tracking
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            // Campo de texto interativo com contraste e acessibilidade aprimorados
            TextEditor(text: $viewModel.playgroundText)
                .font(.system(size: 14, design: .monospaced))
                .scrollContentBackground(.hidden)
                .frame(height: 100)
                .padding(8)
                .background(Color(nsColor: .textBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color.primary.opacity(0.15), lineWidth: 1)
                )
                .accessibilityLabel("Campo de texto para teste de ditado")

            HStack(spacing: 12) {
                Button {
                    viewModel.toggleSpeechTest()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: viewModel.isTestingSpeech ? "stop.fill" : "mic.fill")
                        Text(viewModel.isTestingSpeech ? "Parar Teste" : "Testar Ditado")
                            .font(.system(size: 13, weight: .medium))
                            .tracking(-0.08)
                    }
                    .frame(minWidth: 150, minHeight: 44) // Target >= 44pt
                }
                .buttonStyle(.borderedProminent)
                .tint(viewModel.isTestingSpeech ? .red : .accentColor)
                .sensoryFeedback(.impact, trigger: viewModel.isTestingSpeech)

                if !viewModel.playgroundText.isEmpty {
                    Button("Limpar") {
                        viewModel.playgroundText = ""
                    }
                    .font(.system(size: 13, weight: .regular))
                    .tracking(-0.08)
                    .frame(minWidth: 80, minHeight: 44) // Target >= 44pt
                    .buttonStyle(.bordered)
                }
            }
        }
    }

    // MARK: - Rodapé de Navegação

    private var bottomNavigationFooter: some View {
        HStack {
            if viewModel.currentStep != .microphone {
                Button {
                    viewModel.previousStep()
                } label: {
                    Text("Voltar")
                        .font(.system(size: 13, weight: .regular))
                        .tracking(-0.08)
                        .frame(minWidth: 80, minHeight: 44)
                }
                .buttonStyle(.bordered)
            } else {
                Spacer()
                    .frame(width: 80)
            }

            Spacer()

            if viewModel.currentStep == .accessibility && !viewModel.canAdvance {
                Button {
                    viewModel.forceAdvanceToPlayground()
                } label: {
                    HStack(spacing: 4) {
                        Text("Avançar mesmo assim")
                            .font(.system(size: 13, weight: .regular))
                            .tracking(-0.08)
                        Image(systemName: "chevron.forward")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .frame(minWidth: 140, minHeight: 44)
                }
                .buttonStyle(.bordered)
                .sensoryFeedback(.impact, trigger: viewModel.currentStep)
            }

            Button {
                viewModel.nextStep()
            } label: {
                Text(viewModel.currentStep == .playground ? "Concluir" : "Continuar")
                    .font(.system(size: 13, weight: .semibold))
                    .tracking(-0.08)
                    .frame(minWidth: 100, minHeight: 44)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!viewModel.canAdvance)
            .sensoryFeedback(.selection, trigger: viewModel.currentStep)
        }
    }
}
