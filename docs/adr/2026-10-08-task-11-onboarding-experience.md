# ADR: Tarefa 11 - Experiência de Onboarding & Permissões

- **Status**: Aceite
- **Data**: 2026-10-08
- **Issue**: [#11](https://github.com/SS20112006/Sonotype/issues/11)
- **Trio de Ataque**: 🎨 Trio UI/UX & Native Desktop (`apple-hig-specialist`, `fullstack-engineer`, `qa-security-auditor`, `devops-release`)

## Contexto
O Sonotype necessita de duas permissões essenciais para operar no macOS:
1. Microfone (`AVCaptureDevice` / `AVAudioApplication`) para captação de voz offline.
2. Acessibilidade (`AXIsProcessTrustedWithOptions`) para injeção direta de texto no cursor através de eventos de acessibilidade (`AXUIElement`) e atalhos de teclado globais.

No primeiro arranque, a aplicação deve apresentar uma janela de onboarding elegante e acolhedora em 3 passos para instruir o utilizador, verificar/solicitar permissões contextualmente e permitir um teste imediato do fluxo de ditado (Playground interativo) antes de entrar em modo de repouso na barra de menus.

## Decisões Arquiteturais

1. **Gestor de Permissões (`PermissionsService`)**:
   - Serviço isolado `@MainActor` responsável por consultar e solicitar o estado do Microfone e da Acessibilidade.
   - Fornece método direto para abrir as Definições de Sistema na secção exata de Acessibilidade (`x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility`).
   - Suporta polling reactivo ou notificações para detetar quando o utilizador concede a permissão nas Definições do Sistema.

2. **Janela e Vista de Onboarding (`OnboardingWindowView`)**:
   - Layout visual elegante no padrão Apple HIG com `.regularMaterial`, cantos arredondados contínuos e SF Pro Typography.
   - **Passo 1 (Microfone)**: Apresenta o benefício da privacidade offline e botão de concessão com indicador de estado.
   - **Passo 2 (Acessibilidade)**: Explica a injeção no cursor com botão para abrir as Definições do Sistema e verificação dinâmica em tempo real.
   - **Passo 3 (Playground Interativo)**: Permite ao utilizador ditar (utilizando `Option + Espaço` ou gravação de teste) e ver a transcrição em tempo real, validando o funcionamento antes de concluir.
   - Botão de conclusão que grava `hasCompletedOnboarding = true` em `UserDefaults` (através de `PreferencesManager`).

3. **Integração no Ciclo de Vida (`AppDelegate` / `SonotypeApp`)**:
   - No arranque (`applicationDidFinishLaunching`), se `hasCompletedOnboarding == false`, apresenta a janela de onboarding automaticamente.
   - Permite também reabrir o onboarding manualmente a partir da barra de menus ou definições para diagnóstico.
   - Garante que a Dock e o foco de janelas funcionam harmonicamente via `DockVisibilityCoordinator`.

4. **Conformidade Apple HIG & Acessibilidade**:
   - Contrastes mínimos WCAG 2.1 AA (4.5:1).
   - Touch/click targets de no mínimo 44x44pt.
   - SF Pro Text para rótulos <=19pt e SF Pro Display para títulos >=20pt.
