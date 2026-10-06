# Roteiro de Tarefas: Sonotype (Conversa a Conversa)

> **Instruções de Execução**: Cada tarefa abaixo foi desenhada para ser executada em **uma conversa isolada**. Ao abrir uma nova conversa, basta dizer:
> *"Consulta o `docs/roadmap/tasks.md` e vamos implementar a próxima tarefa pendente."*

---

## Tabela de Progresso Geral

| Tarefa | Nome da Tarefa | Foco Principal | Estado |
| :---: | :--- | :--- | :---: |
| **01** | [Fundação do Projeto & Build System](#tarefa-01-fundação-do-projeto--build-system) | Estrutura Swift 6, Entitlements, Makefile e App Bundle | ✅ CONCLUÍDO |
| **02** | [Pipeline de Áudio & Motor Apple Speech](#tarefa-02-pipeline-de-áudio--motor-apple-speech) | AVAudioEngine em RAM, SFSpeechRecognizer offline PT/EN | ✅ CONCLUÍDO |
| **03** | [Pós-Processamento, Pontuação & Filtros](#tarefa-03-pós-processamento-pontuação--filtros) | Comandos orais, pontuação inteligente, limpeza de hesitações | ✅ CONCLUÍDO |
| **04** | [Injeção no Cursor & Salvaguarda de Clipboard](#tarefa-04-injeção-no-cursor--salvaguarda-de-clipboard) | Acessibilidade macOS, simulação de digitação, Cmd+V seguro | ✅ CONCLUÍDO |
| **05** | [Gestor de Atalho Global & Timeout de Silêncio](#tarefa-05-gestor-de-atalho-global--timeout-de-silêncio) | Hotkey Option+Espaço, máquina de estados, proteção 45s | ✅ CONCLUÍDO |
| **06** | [Pílula Flutuante HUD (Glow Pulse C1)](#tarefa-06-pílula-flutuante-hud-glow-pulse-c1) | Interface flutuante translúcida, ponto pulsante reativo à voz | ✅ CONCLUÍDO |
| **07** | [Menu Bar Extra & Modo Híbrido da Dock](#tarefa-07-menu-bar-extra--modo-híbrido-da-dock) | Ícone na barra de menus, popover rápido, dock dinâmica | ⏳ PENDENTE |
| **08** | [Camada de Persistência Local (SwiftData)](#tarefa-08-camada-de-persistência-local-swiftdata) | Base de dados local para Histórico, Dicionário e Estatísticas | ⏳ PENDENTE |
| **09** | [Dashboard com Barra Lateral (Histórico & Dicionário)](#tarefa-09-dashboard-com-barra-lateral-histórico--dicionário) | NavigationSplitView: Histórico pesquisável, Dicionário e Snippets | ⏳ PENDENTE |
| **10** | [Painel de Definições & Armazenamento de Preferências](#tarefa-10-painel-de-definições--armazenamento-de-preferências) | Configuração de todos os seletores (atalhos, sons, dock, filtros) | ⏳ PENDENTE |
| **11** | [Experiência de Onboarding & Permissões](#tarefa-11-experiência-de-onboarding--permissões) | Boas-vindas em 3 passos com teste interativo imediato | ⏳ PENDENTE |
| **12** | [Hardening de Produção, Assinatura & Packaging](#tarefa-12-hardening-de-produção-assinatura--packaging) | Código assinado, build para ~/Downloads/Sonotype.app e release | ⏳ PENDENTE |

---

## Detalhe das Tarefas

### Tarefa 01: Fundação do Projeto & Build System
- **Objetivo**: Inicializar a estrutura raiz do projeto nativo para macOS (macOS 14+ / 15+ Sequoia), configurando compilação reproduzível sem ferramentas de terceiros pesadas.
- **Entregáveis**:
  - Estrutura de diretórios (`Sources/Sonotype`, `Resources`, `Tests`).
  - `Package.swift` ou `Sonotype.xcodeproj` configurado com Swift 6 e SwiftUI nativo.
  - Entitlements de segurança (`Sonotype.entitlements`) com permissão de áudio (`com.apple.security.device.audio-input`).
  - `Makefile` com targets fundamentais: `make check`, `make build`, `make local`, `make run`.
  - Ponto de entrada básico do app (`SonotypeApp.swift`).
- **Critério de Aceitação / Verificação**:
  - `make build` compila sem erros nem avisos.
  - `make run` inicia a aplicação com janela ou ícone no menu bar.

---

### Tarefa 02: Pipeline de Áudio & Motor Apple Speech
- **Objetivo**: Implementar a captação de áudio em memória volátil e a transcrição offline usando o framework nativo da Apple (`SFSpeechRecognizer`).
- **Entregáveis**:
  - `AudioCaptureService`: Gestão de `AVAudioEngine` capturando áudio a 16kHz mono em buffer de memória (zero ficheiros no disco).
  - `SpeechRecognitionService`: Reconhecimento de fala offline (`requiresOnDeviceRecognition = true`) nos idiomas `pt-PT`, `pt-BR`, `en-US`, `en-GB`.
  - `LanguageDetectorService`: Lógica de deteção automática entre Português e Inglês com fallback inteligente.
  - Notificações ou callbacks de amplitude sonora em tempo real para alimentar a animação da pílula.
- **Critério de Aceitação / Verificação**:
  - Testes unitários com ficheiro de áudio de teste simulado verificando transcrição em PT e EN.
  - Confirmação de que nenhum ficheiro temporário ou áudio é escrito no disco.

---

### Tarefa 03: Pós-Processamento, Pontuação & Filtros
- **Objetivo**: Transformar a transcrição crua num texto polido, inteligente e natural nos dois idiomas.
- **Entregáveis**:
  - `PunctuationService`:
    - Pontuação automática baseada em pausas naturais.
    - Suporte a comandos orais nos dois idiomas: *"vírgula"*, *"ponto final"*, *"ponto de interrogação"*, *"nova linha"*, *"novo parágrafo"*, *"dois pontos"* e equivalentes em inglês (*"comma"*, *"period"*, etc.).
  - `FillerWordFilterService`:
    - Deteção e remoção automática de hesitações em Português (*"hum"*, *"ãh"*, *"hã"*, *"éé"*, *"tipo"*, *"ou seja"*) e Inglês (*"um"*, *"uh"*, *"like"*).
  - `CapitalizationService`: Correção automática de maiúsculas no início de frases.
- **Critério de Aceitação / Verificação**:
  - Testes de regressão cobrindo frases faladas em PT e EN com e sem hesitações, validando o output final limpo.

---

### Tarefa 04: Injeção no Cursor & Salvaguarda de Clipboard
- **Objetivo**: Inserir o texto final transcrito na aplicação em foco e gerir o Clipboard com segurança.
- **Entregáveis**:
  - `TextInjectionService`: Injeção de texto no cursor através da API de Acessibilidade (`AXUIElement`) e fallback via simulação de eventos de teclado (`CGEvent`).
  - `ClipboardSafetyManager`:
    - Modo A (Padrão): Colar e guardar cópia no Clipboard (`Cmd + V`) para garantir que o utilizador nunca perde texto se a janela ativa mudar.
    - Modo B: Preservar o clipboard anterior sem alteração.
- **Critério de Aceitação / Verificação**:
  - Teste de injeção num campo de texto e verificação de integridade do conteúdo do clipboard.

---

### Tarefa 05: Gestor de Atalho Global & Timeout de Silêncio
- **Objetivo**: Orquestrar o ciclo de vida da gravação com atalhos de teclado globais e proteção de inatividade.
- **Entregáveis**:
  - `GlobalHotkeyManager`: Captura global de `Option + Espaço` (e suporte a atalhos customizados) em segundo plano, mesmo com outras apps em foco.
  - `RecordingStateMachine`: Estados formais (`idle`, `recording`, `processing`, `cancelled`).
  - Suporte a cancelamento imediato via tecla `Escape`.
  - `SilenceTimeoutManager`: Monitorização da amplitude de voz; se detetar 45 segundos de silêncio contínuo em modo Toggle, finaliza a sessão e cola o texto automaticamente.
  - `FeedbackSoundPlayer`: Efeitos sonoros nativos sutis do macOS ao iniciar e ao parar a gravação.
- **Critério de Aceitação / Verificação**:
  - Testes da máquina de estados (início, paragem, cancelamento por Escape, disparo do timeout de silêncio).

---

### Tarefa 06: Pílula Flutuante HUD (Glow Pulse C1)
- **Objetivo**: Construir a interface visual minimalista flutuante no centro inferior do ecrã.
- **Entregáveis**:
  - `HUDPanel`: `NSPanel` sem moldura, flutuante (`.floating`), não ativador de foco (`nonactivatingPanel`), com material adaptativo Apple (`.regularMaterial` em Claro/Escuro).
  - `GlowPulseView` (Estética C1): Ponto luminoso minimalista que pulsa suavemente de acordo com o volume da voz em tempo real.
  - Animações fluidas de entrada e saída com curvas `.spring()`.
- **Critério de Aceitação / Verificação**:
  - Pílula surge no centro inferior ao premir o atalho e desaparece suavemente ao parar.
  - Conformidade estrita com Apple HIG (contraste, materiais semânticos e fluidez).

---

### Tarefa 07: Menu Bar Extra & Modo Híbrido da Dock
- **Objetivo**: Criar o ícone de presença no topo do macOS e controlar a visibilidade dinâmica da Dock.
- **Entregáveis**:
  - `MenuBarExtraManager`: Ícone na barra de menus com estado de prontidão e animação de escuta.
  - `QuickPopoverView`: Menu popover compacto contendo:
    - Estado atual e idioma.
    - Atalho visível (`Option + Espaço`).
    - Botão "Abrir Dashboard", "Definições", "Encerrar".
  - `DockVisibilityCoordinator`:
    - Modo Híbrido Dinâmico: `.accessory` em repouso (invisível na Dock); `.regular` quando a janela de Dashboard/Definições estiver aberta.
- **Critério de Aceitação / Verificação**:
  - Clicar no ícone da barra de menus abre o popover.
  - Fechar janelas remove a app da Dock; abrir o Dashboard faz a app reaparecer na Dock.

---

### Tarefa 08: Camada de Persistência Local (SwiftData)
- **Objetivo**: Modelar e persistir os dados do utilizador de forma segura, privada e de alta velocidade.
- **Entregáveis**:
  - Modelos SwiftData / SQLite local:
    - `TranscriptionRecord`: ID, texto transcrito, data/hora, duração, palavras, idioma detetado.
    - `VocabularyEntry`: Palavra/termo técnico personalizado e prioridade.
    - `WordReplacementRule`: Gatilho falado e texto de substituição.
    - `SessionStat`: Estatísticas diárias de uso.
  - Camada de repositório e migração segura.
  - Garantia estrita de zero persistência de áudio.
- **Critério de Aceitação / Verificação**:
  - Testes unitários de inserção, leitura, filtragem e remoção com tempo de execução inferior a 50ms.

---

### Tarefa 09: Dashboard com Barra Lateral (Histórico & Dicionário)
- **Objetivo**: Desenvolver a janela principal com navegação por barra lateral clássica da Apple.
- **Entregáveis**:
  - `DashboardWindow`: Janela `NavigationSplitView` com estilo nativo Apple.
  - **Secção Histórico**:
    - Lista de transcrições com barra de pesquisa integrada (`.searchable`).
    - Ações rápidas: Copiar com 1 clique, eliminar item individual.
    - Botões de exportação para `.txt`, `.md` e `.csv`.
    - Botão "Limpar Histórico" com diálogo de confirmação nativo do macOS.
  - **Secção Dicionário**:
    - Gestor de Vocabulário Personalizado (adicionar termos técnicos).
    - Tabela de Substituições rápidas (ex: *"meu email"* ➔ *"utilizador@email.com"*).
  - **Secção Estatísticas**:
    - Cartões de tempo poupado estimado, palavras totais e divisão PT/EN.
- **Critério de Aceitação / Verificação**:
  - Navegação fluida entre secções da barra lateral, pesquisa funcional e exportações a gerar ficheiros válidos.

---

### Tarefa 10: Painel de Definições & Armazenamento de Preferências
- **Objetivo**: Centralizar todas as preferências e opções de personalização da aplicação.
- **Entregáveis**:
  - `SettingsView` (Janela de Definições nativa com abas):
    - **Geral**: Iniciar no Login, Presença na Dock (Dinâmico vs Apenas Menu Bar vs Sempre Dock).
    - **Gravação**: Modo Toggle vs Push-to-Talk, Gravador interativo de atalhos de teclado, Timeout de silêncio (15s, 30s, 45s, 60s, Desativado), Sons (Ligado/Desligado).
    - **Texto & Idioma**: Idioma (Auto-Detect vs Fixo PT vs Fixo EN), Modo de feedback (Apenas onda vs Streaming na pílula vs Digitação direta), Comandos de pontuação (Ligado/Desligado), Filtro de hesitações (Ligado/Desligado).
    - **Clipboard**: Copiar para clipboard ao colar (Ligado/Desligado).
    - **Personalizar Dashboard**: Toggles para escolher que cartões de estatísticas aparecem no Dashboard.
- **Critério de Aceitação / Verificação**:
  - Mudanças nas definições têm efeito imediato nas instâncias em execução e persistem após reinício da app.

---

### Tarefa 11: Experiência de Onboarding & Permissões
- **Objetivo**: Criar a receção inicial para o utilizador conceder permissões e testar a app no primeiro minuto.
- **Entregáveis**:
  - `OnboardingWindowView`:
    - Passo 1: Permissão de Microfone com feedback visual de sucesso.
    - Passo 2: Permissão de Acessibilidade com botão para abrir diretamente as Definições do Sistema do macOS.
    - Passo 3: Playground de Teste Interativo — campo onde o utilizador prime `Option + Espaço`, fala e vê o texto a ser ditado e inserido.
  - Guarda de estado (`hasCompletedOnboarding`) em `UserDefaults`.
- **Critério de Aceitação / Verificação**:
  - Em máquina limpa, o onboarding surge no arranque e só avança com permissões satisfeitas; fecha e nunca mais incomoda após conclusão.

---

### Tarefa 12: Hardening de Produção, Assinatura & Packaging
- **Objetivo**: Polir o produto final, garantir conformidade de segurança e produzir o instalador pronto a usar.
- **Entregáveis**:
  - Auditoria de segurança e acessibilidade (WCAG AA, SF Pro optical sizing, zero fugas de memória).
  - Configuração de assinatura estável local (Apple Development / Ad-hoc) no `Makefile`.
  - Target `make local`: Compila e copia a aplicação limpa diretamente para `~/Downloads/Sonotype.app`.
  - Target `make dmg`: Gera uma imagem DMG distribuível do Sonotype com ícone de arrastar para a pasta Aplicações.
- **Critério de Aceitação / Verificação**:
  - Execução de `make local` e abertura com `open ~/Downloads/Sonotype.app` funciona sem erros nem alertas de integridade.
