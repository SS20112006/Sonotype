# Roteiro de Tarefas: Sonotype (Conversa a Conversa)

> **Instruções de Execução**: Cada tarefa abaixo foi desenhada para ser executada em **uma conversa isolada**. Ao abrir uma nova conversa, basta dizer:
> *"Consulta o `docs/roadmap/tasks.md` e vamos implementar a próxima tarefa pendente."*

---

## Tabela de Progresso Geral & Backlog no Git

| Tarefa | Issue Git | Nome da Tarefa | Trio de Ataque Oficial | Subagentes Atribuídos | Skills Principais | Estado |
| :---: | :---: | :--- | :--- | :--- | :--- | :---: |
| **01** | [#1](https://github.com/SS20112006/Sonotype/issues/1) | [Fundação do Projeto & Build System](#tarefa-01-fundação-do-projeto--build-system) | 🚀 Trio Full-Stack Feature | `fullstack-engineer`, `devops-release`, `qa-security-auditor` | `ponytail`, `semantic-git-workflow`, `swift-concurrency-6-2`, `verification-before-completion` | ✅ CONCLUÍDO |
| **02** | [#2](https://github.com/SS20112006/Sonotype/issues/2) | [Pipeline de Áudio & Motor Apple Speech](#tarefa-02-pipeline-de-áudio--motor-apple-speech) | 🚀 Trio Full-Stack Feature | `fullstack-engineer`, `qa-security-auditor`, `devops-release` | `swift-concurrency-6-2`, `verification-before-completion`, `ponytail`, `test-driven-development` | ✅ CONCLUÍDO |
| **03** | [#3](https://github.com/SS20112006/Sonotype/issues/3) | [Pós-Processamento, Pontuação & Filtros](#tarefa-03-pós-processamento-pontuação--filtros) | 🚀 Trio Full-Stack Feature | `fullstack-engineer`, `qa-security-auditor`, `devops-release` | `test-driven-development`, `ponytail`, `error-handling`, `verification-before-completion` | ✅ CONCLUÍDO |
| **04** | [#4](https://github.com/SS20112006/Sonotype/issues/4) | [Injeção no Cursor & Salvaguarda de Clipboard](#tarefa-04-injeção-no-cursor--salvaguarda-de-clipboard) | 🚀 Trio Full-Stack Feature | `fullstack-engineer`, `qa-security-auditor`, `devops-release` | `systematic-debugging`, `verification-before-completion`, `ponytail`, `safety-guard` | ✅ CONCLUÍDO |
| **05** | [#5](https://github.com/SS20112006/Sonotype/issues/5) | [Gestor de Atalho Global & Timeout de Silêncio](#tarefa-05-gestor-de-atalho-global--timeout-de-silêncio) | 🚀 Trio Full-Stack Feature | `fullstack-engineer`, `qa-security-auditor`, `devops-release` | `swift-concurrency-6-2`, `test-driven-development`, `verification-before-completion`, `error-handling` | ✅ CONCLUÍDO |
| **06** | [#6](https://github.com/SS20112006/Sonotype/issues/6) | [Pílula Flutuante HUD (Glow Pulse C1)](#tarefa-06-pílula-flutuante-hud-glow-pulse-c1) | 🎨 Trio UI/UX & Native Desktop | `apple-hig-specialist`, `fullstack-engineer`, `qa-security-auditor`, `devops-release` | `apple-hig-auditor`, `swiftui-patterns`, `design-taste-frontend`, `verification-before-completion` | ✅ CONCLUÍDO |
| **07** | [#7](https://github.com/SS20112006/Sonotype/issues/7) | [Menu Bar Extra & Modo Híbrido da Dock](#tarefa-07-menu-bar-extra--modo-híbrido-da-dock) | 🎨 Trio UI/UX & Native Desktop | `apple-hig-specialist`, `fullstack-engineer`, `qa-security-auditor`, `devops-release` | `swiftui-patterns`, `apple-hig-auditor`, `semantic-git-workflow`, `verification-before-completion` | ✅ CONCLUÍDO |
| **08** | [#8](https://github.com/SS20112006/Sonotype/issues/8) | [Camada de Persistência Local (SwiftData)](#tarefa-08-camada-de-persistência-local-swiftdata) | 🚀 Trio Full-Stack Feature / ⚡ Trio Hotfix | `fullstack-engineer`, `build-error-resolver`, `qa-security-auditor`, `devops-release` | `systematic-debugging`, `verification-before-completion`, `ponytail`, `semantic-git-workflow` | ✅ CONCLUÍDO |
| **09** | [#9](https://github.com/SS20112006/Sonotype/issues/9) | [Dashboard com Barra Lateral (Histórico & Dicionário)](#tarefa-09-dashboard-com-barra-lateral-histórico--dicionário) | 🚀 Trio Full-Stack Feature | `apple-hig-specialist`, `fullstack-engineer`, `qa-security-auditor`, `devops-release` | `swiftui-patterns`, `apple-hig-auditor`, `ponytail`, `verification-before-completion`, `semantic-git-workflow` | ✅ CONCLUÍDO |
| **10** | [#10](https://github.com/SS20112006/Sonotype/issues/10) | [Painel de Definições & Armazenamento de Preferências](#tarefa-10-painel-de-definições--armazenamento-de-preferências) | 🎨 Trio UI/UX & Native Desktop | `apple-hig-specialist`, `fullstack-engineer`, `silent-failure-hunter`, `devops-release` | `swiftui-patterns`, `apple-hig-auditor`, `error-handling`, `verification-before-completion`, `semantic-git-workflow` | ✅ CONCLUÍDO |
| **11** | [#11](https://github.com/SS20112006/Sonotype/issues/11) | [Experiência de Onboarding & Permissões](#tarefa-11-experiência-de-onboarding--permissões) | 🎨 Trio UI/UX & Native Desktop | `apple-hig-specialist`, `fullstack-engineer`, `qa-security-auditor`, `devops-release` | `apple-hig-auditor`, `swiftui-patterns`, `systematic-debugging`, `verification-before-completion`, `semantic-git-workflow` | ✅ CONCLUÍDO |
| **12** | [#12](https://github.com/SS20112006/Sonotype/issues/12) | [Hardening de Produção, Assinatura & Packaging](#tarefa-12-hardening-de-produção-assinatura--packaging) | 🏛️ Trio Arquitetura, Performance & Dívida | `qa-security-auditor`, `complexity-auditor`, `performance-engineer`, `silent-failure-hunter`, `devops-release` | `production-readiness-verifier`, `ponytail-audit`, `performance-profiling-benchmark`, `finishing-a-development-branch`, `semantic-git-workflow` | ⏳ PENDENTE |

---

## Detalhe das Tarefas

### Tarefa 01: Fundação do Projeto & Build System
- **Objetivo**: Inicializar a estrutura raiz do projeto nativo para macOS (macOS 14+ / 15+ Sequoia), configurando compilação reproduzível sem ferramentas de terceiros pesadas.
- **Subagentes**: `fullstack-engineer`, `devops-release`.
- **Skills**: `ponytail`, `semantic-git-workflow`.
- **Entregáveis**:
  - Estrutura de diretórios (`Sources/Sonotype`, `Resources`, `Tests`).
  - `Package.swift` configurado com Swift 6 e SwiftUI nativo.
  - Entitlements de segurança (`Sonotype.entitlements`) com permissão de áudio (`com.apple.security.device.audio-input`).
  - `Makefile` com targets fundamentais: `make check`, `make build`, `make local`, `make run`.
  - Ponto de entrada básico do app (`SonotypeApp.swift`).
- **Critério de Aceitação**: `make build` compila sem erros; `make run` inicia com sucesso.

---

### Tarefa 02: Pipeline de Áudio & Motor Apple Speech
- **Objetivo**: Implementar a captação de áudio em memória volátil e a transcrição offline usando o framework nativo da Apple (`SFSpeechRecognizer`).
- **Subagentes**: `fullstack-engineer`, `qa-security-auditor`.
- **Skills**: `swift-concurrency-6-2`, `verification-before-completion`.
- **Entregáveis**:
  - `AudioCaptureService`: Gestão de `AVAudioEngine` capturando áudio a 16kHz mono em buffer de memória (zero ficheiros no disco).
  - `SpeechRecognitionService`: Reconhecimento de fala offline (`requiresOnDeviceRecognition = true`) nos idiomas `pt-PT`, `pt-BR`, `en-US`, `en-GB`.
  - `LanguageDetectorService`: Lógica de deteção automática entre Português e Inglês com fallback inteligente.
  - Callbacks de amplitude sonora em tempo real para alimentar a animação da pílula.
- **Critério de Aceitação**: Testes unitários com buffer em memória; confirmação de zero ficheiros escritos em disco.

---

### Tarefa 03: Pós-Processamento, Pontuação & Filtros
- **Objetivo**: Transformar a transcrição crua num texto polido, inteligente e natural nos dois idiomas.
- **Subagentes**: `fullstack-engineer`.
- **Skills**: `test-driven-development`, `ponytail`.
- **Entregáveis**:
  - `PunctuationService`: Pontuação automática por pausas e comandos orais ("vírgula", "ponto final", "nova linha", "comma", etc.).
  - `FillerWordFilterService`: Remoção de hesitações ("hum", "ãh", "tipo", "um", "uh", "like").
  - `CapitalizationService`: Correção automática de maiúsculas no início de frases.
- **Critério de Aceitação**: Testes de regressão cobrindo frases faladas em PT e EN.

---

### Tarefa 04: Injeção no Cursor & Salvaguarda de Clipboard
- **Objetivo**: Inserir o texto final transcrito na aplicação em foco e gerir o Clipboard com segurança.
- **Subagentes**: `fullstack-engineer`, `qa-security-auditor`.
- **Skills**: `systematic-debugging`, `verification-before-completion`.
- **Entregáveis**:
  - `TextInjectionService`: Injeção de texto via `AXUIElement` e fallback via `CGEvent`.
  - `ClipboardSafetyManager`: Modo A (Colar e preservar no Clipboard) e Modo B (Restaurar clipboard anterior).
- **Critério de Aceitação**: Testes unitários de injeção e integridade do pasteboard.

---

### Tarefa 05: Gestor de Atalho Global & Timeout de Silêncio
- **Objetivo**: Orquestrar o ciclo de vida da gravação com atalhos de teclado globais e proteção de inatividade.
- **Subagentes**: `fullstack-engineer`.
- **Skills**: `swift-concurrency-6-2`, `test-driven-development`.
- **Entregáveis**:
  - `GlobalHotkeyManager`: Captura global de `Option + Espaço` em segundo plano.
  - `RecordingStateMachine`: Estados formais (`idle`, `recording`, `processing`, `cancelled`) e suporte a tecla `Escape`.
  - `SilenceTimeoutManager`: Auto-finalização após 45s de silêncio contínuo.
  - `FeedbackSoundPlayer`: Sons nativos sutis ao iniciar e parar.
- **Critério de Aceitação**: Testes da máquina de estados e disparo de timeout.

---

### Tarefa 06: Pílula Flutuante HUD (Glow Pulse C1)
- **Objetivo**: Construir a interface visual minimalista flutuante no centro inferior do ecrã.
- **Subagentes**: `apple-hig-specialist`, `fullstack-engineer`.
- **Skills**: `apple-hig-auditor`, `swiftui-patterns`.
- **Entregáveis**:
  - `HUDPanel`: `NSPanel` flutuante sem moldura sobre material adaptativo Apple (`.regularMaterial`).
  - `GlowPulseView` (Estética C1): Ponto luminoso minimalista com aura reativa ao volume da voz.
  - Animações fluidas `.spring()`.
- **Critério de Aceitação**: Pílula surge e desaparece suavemente; conformidade estrita com Apple HIG.

---

### Tarefa 07: Menu Bar Extra & Modo Híbrido da Dock
- **Objetivo**: Criar o ícone de presença no topo do macOS e controlar a visibilidade dinâmica da Dock.
- **Subagentes**: `apple-hig-specialist`, `fullstack-engineer`, `devops-release`.
- **Skills**: `swiftui-patterns`, `apple-hig-auditor`, `semantic-git-workflow`.
- **Entregáveis**:
  - `MenuBarExtraManager`: Ícone na barra de menus com estado de prontidão e animação de escuta.
  - `QuickPopoverView`: Menu popover compacto com atalhos, estado e botões de ação rápida.
  - `DockVisibilityCoordinator`: Modo Híbrido Dinâmico (`.accessory` em repouso, `.regular` quando há janelas abertas).
- **Critério de Aceitação**: Testes unitários do gestor de menu bar e do coordenador da dock aprovados; commit semântico isolado.

---

### Tarefa 08: Camada de Persistência Local (SwiftData)
- **Objetivo**: Modelar e persistir os dados do utilizador de forma segura, privada e de alta velocidade, estabilizando as asserções de teste pendentes.
- **Subagentes Atribuídos**:
  - `build-error-resolver`: Correção cirúrgica e minimalista das 2 asserções falhadas em `PersistenceRepositoryTests.swift` (contagem de 11 palavras vs 10; query parcial de `"de"` vs palavra inglesa `"design"`).
  - `qa-security-auditor`: Execução da suite `swift test` (146/146 a passar), verificação da garantia de zero retenção de áudio em disco e benchmarking de execução (<50ms).
  - `devops-release`: Staging atómico e commits das Tarefas 07 e 08 (`feat(menubar): ...` e `feat(persistence): ...`).
- **Skills Obrigatórias**:
  - `systematic-debugging`: Análise de causa raiz das asserções de teste sem alterar contratos do repositório.
  - `verification-before-completion`: Execução de `swift test` garantindo evidência fresca antes de qualquer asserção de conclusão.
  - `semantic-git-workflow`: Formatação estrita Conventional Commits 1.0.0 e isolamento de escopo monorepo.
- **Entregáveis**:
  - Modelos SwiftData (`TranscriptionRecord`, `VocabularyEntry`, `WordReplacementRule`, `SessionStat`).
  - `PersistenceContainerFactory` com fallback defensivo em memória.
  - `PersistenceRepository` thread-safe isolado em `@MainActor`.
  - Testes unitários com 100% de sucesso.
- **Critério de Aceitação**: `swift test` passa 100% sem falhas nem avisos; commits das Tarefas 07 e 08 criados no Git.

---

### Tarefa 09: Dashboard com Barra Lateral (Histórico & Dicionário)
- **Objetivo**: Desenvolver a janela principal com navegação por barra lateral clássica da Apple (`NavigationSplitView`).
- **Subagentes Atribuídos**:
  - `apple-hig-specialist`: Autor do layout visual nativo do macOS:
    - Construção de `DashboardWindowView` com `NavigationSplitView` no estilo Apple Notes / System Settings.
    - Materiais semânticos (`.regularMaterial`), tipografia óptica SF Pro Text (≤19pt) e SF Pro Display (≥20pt), contraste WCAG 2.1 AA e touch/click targets de no mínimo 44x44pt.
  - `fullstack-engineer`: Implementação da lógica de dados e reatividade:
    - `DashboardViewModel` isolado com `@Observable` ligado ao `PersistenceRepository`.
    - Barra de pesquisa integrada (`.searchable`) com filtragem reativa e paginação suave.
    - Ações rápidas: Copiar com 1 clique, eliminação individual e diálogo de confirmação nativo para limpeza total.
    - Exportação real para ficheiros `.txt`, `.md` e `.csv` via `NSSavePanel`.
    - Gestor de Vocabulário Personalizado e editor de regras de substituição de texto por voz.
  - `qa-security-auditor`: Verificação estrita de ausência de dados mock em produção, validação de acessibilidade e execução de testes automatizados de exportação e filtragem.
  - `devops-release`: Commit semântico atómico da funcionalidade do Dashboard.
- **Skills Obrigatórias**:
  - `swiftui-patterns`: Padrões modernos de UI, reatividade `@Observable`, `.searchable` e ciclo de vida de janelas macOS.
  - `apple-hig-auditor`: Conformidade com o guia de design da Apple para janelas divididas, ícones SF Symbols com cores semânticas e materiais de profundidade.
  - `ponytail`: YAGNI e Code Economy — utilizar os componentes padrão (`Table`, `List`, `Form`) sem bibliotecas pesadas de terceiros.
  - `verification-before-completion`: Prova de execução de testes antes de dar a tarefa como concluída.
  - `semantic-git-workflow`: Formato Conventional Commits (`feat(dashboard): ...`).
- **Entregáveis**:
  - `DashboardWindowView` e componentes de detalhe (`HistoryListView`, `VocabularyManagerView`, `StatsOverviewView`).
  - Exportadores de ficheiros `.txt`, `.md` e `.csv`.
  - Testes unitários cobrindo o ViewModel, pesquisa e exportação.
- **Critério de Aceitação**: Navegação fluida entre as 3 secções, pesquisa em tempo real sem latência perceptível e exportações a produzir ficheiros válidos.

---

### Tarefa 10: Painel de Definições & Armazenamento de Preferências
- **Objetivo**: Centralizar todas as preferências e opções de personalização da aplicação numa janela de Definições nativa com abas.
- **Subagentes Atribuídos**:
  - `apple-hig-specialist`: Design das abas de definições nativas (`Settings` / `TabView`) seguindo os padrões do macOS Sequoia (alinhamento de rótulos à direita, controlos `Picker`, `Toggle`, `Slider` e espaçamentos simétricos).
  - `fullstack-engineer`: Engenharia do sistema de preferências reativas:
    - `PreferencesManager` centralizado com persistência em `UserDefaults` / `@AppStorage`.
    - Propagação em tempo real para os serviços ativos (`RecordingSessionCoordinator`, `DockVisibilityCoordinator`, `SilenceTimeoutManager`, `FeedbackSoundPlayer`, `TextPostProcessor`).
    - Componente interativo gravador de atalho de teclado global (captura de modificadores e códigos de tecla).
  - `silent-failure-hunter`: Auditoria do fluxo de persistência de definições para garantir que alterações não são ignoradas silenciosamente nem perdem sincronia entre processos.
  - `devops-release`: Commit semântico atómico (`feat(settings): ...`).
- **Skills Obrigatórias**:
  - `swiftui-patterns`: Composição de janelas de preferências do macOS e sincronização reativa bidirecional.
  - `apple-hig-auditor`: Layout padrão de Settings no macOS com navegação por ícones e grelha alinhada.
  - `error-handling`: Validação de atalhos em conflito com atalhos de sistema e timeouts de silêncio inválidos.
  - `verification-before-completion`: Testes unitários verificando a propagação de cada configuração.
  - `semantic-git-workflow`: Formato Conventional Commits.
- **Entregáveis**:
  - `SettingsView` com abas: *Geral*, *Gravação*, *Texto & Idioma*, *Clipboard*, *Estatísticas*.
  - `PreferencesManager` e gravador de atalhos de teclado.
  - Testes unitários para persistência e reatividade de cada preferência.
- **Critério de Aceitação**: Modificar qualquer preferência nas Definições reflete imediatamente no comportamento da aplicação em tempo de execução sem reiniciar.

---

### Tarefa 11: Experiência de Onboarding & Permissões
- **Objetivo**: Criar o assistente de primeiro arranque para solicitar permissões essenciais de forma elegante e permitir o teste interativo da app no primeiro minuto.
- **Subagentes Atribuídos**:
  - `apple-hig-specialist`: Autor da experiência visual de boas-vindas:
    - Janela de onboarding elegante com materiais translúcidos, tipografia cuidada, ilustrações/ícones SF Symbols com cores semânticas e transições suaves entre passos.
  - `fullstack-engineer`: Implementação dos verificadores de permissão e playground:
    - Passo 1: Verificação e pedido de microfone (`AVCaptureDevice.requestAccess` / `AVAudioApplication`).
    - Passo 2: Verificação de acessibilidade (`AXIsProcessTrustedWithOptions`) com observador de regresso do utilizador e botão direto para as Definições de Sistema (`x-apple.systempreferences:`).
    - Passo 3: Playground interativo onde o utilizador dita usando `Option + Espaço` e valida o funcionamento em tempo real.
    - Guarda booleana persistente `hasCompletedOnboarding`.
  - `qa-security-auditor`: Auditoria de permissões e segurança de sandbox para garantir que os pedidos de autorização não bloqueiam o `MainActor` e cumprem as exigências do Gatekeeper e macOS Security.
  - `devops-release`: Commit semântico atómico (`feat(onboarding): ...`).
- **Skills Obrigatórias**:
  - `apple-hig-auditor`: Boas práticas de autorização contextual e explicada da Apple.
  - `swiftui-patterns`: Máquina de estados de assistente de múltiplos passos com animações `.spring()`.
  - `systematic-debugging`: Diagnóstico de estados de autorização (não determinado, concedido, negado, restrito).
  - `verification-before-completion`: Testes unitários do fluxo de transição de passos.
  - `semantic-git-workflow`: Formato Conventional Commits.
- **Entregáveis**:
  - `OnboardingWindowView` com fluxo de 3 passos e playground.
  - Coordenador de ciclo de vida de arranque condicional no `AppDelegate` / `SonotypeApp`.
  - Testes unitários cobrindo o fluxo de onboarding.
- **Critério de Aceitação**: Em arranque limpo, o onboarding surge automaticamente e só permite concluir com permissões concedidas; não volta a surgir em execuções posteriores.

---

### Tarefa 12: Hardening de Produção, Assinatura & Packaging
- **Objetivo**: Conduzir auditorias rigorosas de segurança, código e performance, configurar assinatura de código e produzir os artefactos finais distribuíveis (`Sonotype.app` e `.dmg`).
- **Subagentes Atribuídos**:
  - `qa-security-auditor`: Auditoria de integridade e segurança pré-deploy:
    - Varredura de eliminação de stubs/mocks em código de produção.
    - Verificação de conformidade com os Entitlements de áudio e acessibilidade.
    - Auditoria estrita da garantia de Zero Retenção de Áudio em disco.
    - Verificação final de acessibilidade (WCAG 2.1 AA) e tipografia SF Pro.
  - `complexity-auditor`: Auditoria Ponytail em todo o repositório:
    - Remoção de código morto, ficheiros órfãos, imports redundantes e complexidade desnecessária.
  - `performance-engineer`: Benchmarks de execução:
    - Medição de tempo de arranque a frio (<1.0s).
    - Latência de injeção no cursor (<50ms).
    - Consumo de memória RAM em repouso e durante o ditado (<80MB).
  - `silent-failure-hunter`: Auditoria forense para erradicar blocos `catch` vazios, `try?` não verificados ou falhas silenciosas no áudio.
  - `devops-release`: Engenharia de build, assinatura e distribuição:
    - Targets do `Makefile`: `make check`, `make build`, `make local` (instalando em `~/Downloads/Sonotype.app`) e `make dmg` (gerando imagem DMG pronta a instalar).
    - Assinatura de código ad-hoc / Apple Development estável.
    - Geração do changelog e finalização de branch (`finishing-a-development-branch`).
- **Skills Obrigatórias**:
  - `production-readiness-verifier`: Checklist automatizado pré-distribuição.
  - `ponytail-audit`: Varredura completa de sobre-engenharia no repositório.
  - `performance-profiling-benchmark`: Medição de tempos de resposta e uso de memória.
  - `finishing-a-development-branch`: Procedimento formal de fecho de desenvolvimento e integração.
  - `semantic-git-workflow`: Release tag e changelog semântico 1.0.0.
- **Entregáveis**:
  - Relatório final de auditoria de segurança, acessibilidade e performance.
  - Target `make dmg` no `Makefile` a produzir `build/Sonotype.dmg`.
  - Executável assinado funcional em `~/Downloads/Sonotype.app`.
- **Critério de Aceitação**: `open ~/Downloads/Sonotype.app` e montagem do DMG funcionam sem erros nem alertas de integridade no macOS Sequoia.
