# Tarefa 10: Arquitetura do Painel de Definições e Gestão de Preferências

* Status: accepted
* Deciders: Principal Architect / Orchestrator, User
* Date: 2026-10-08

## Context and Problem Statement
O Sonotype é uma aplicação de ditado offline nativa para macOS focada em máxima velocidade, ergonomia e personalização.
Até ao momento (Tarefas 01 a 09), os vários subsistemas (modo de gravação, timeout de silêncio, feedback auditivo, visibilidade da Dock, processamento de texto e salvaguarda de clipboard) utilizavam valores padrão configurados de fábrica.
A Tarefa 10 tem como objetivo centralizar toda a personalização da aplicação num motor reativo de preferências (`PreferencesManager`) e fornecer uma interface nativa macOS Sequoia com abas (`SettingsView`), permitindo ao utilizador configurar o comportamento do sistema sem necessidade de reiniciar a aplicação.

## Decision Drivers
* **Conformidade Apple HIG (macOS Sequoia)**: Interface nativa com `TabView`, grelhas alinhadas, controlos `Picker`, `Toggle`, `Slider` e gravador de atalhos ergonómico, alvos interativos >= 44x44pt, contraste WCAG 2.1 AA e materiais semânticos.
* **Propagação em Tempo Real (Zero Restart)**: Qualquer alteração efetuada nas definições deve ter efeito imediato nos serviços ativos (`RecordingSessionCoordinator`, `DockVisibilityCoordinator`, `SilenceTimeoutManager`, `FeedbackSoundPlayer`, `TextPostProcessor`, etc.).
* **Ponytail Code Economy**: Persistência baseada na biblioteca padrão do macOS (`UserDefaults` com codificação `Codable`), sem dependências externas nem estruturas desnecessárias.
* **Resiliência e Ausência de Falhas Silenciosas**: Validação robusta de atalhos e valores limites, prevenindo combinações inválidas ou perdas silenciosas de configuração.

## Considered Options
* Opção 1: Janela personalizada com controlos avulsos e persistência manual em ficheiro JSON no disco.
* Opção 2: Sistema centralizado com `PreferencesManager` `@Observable` no `@MainActor`, persistência via `UserDefaults`, e janela nativa de preferências macOS (`Settings` scene e `SettingsView` com abas organizadas: *Geral*, *Gravação*, *Texto & Idioma*, *Clipboard*, *Estatísticas*).

## Decision Outcome
Opção escolhida: "Opção 2", pois tira partido das capacidades nativas do macOS e SwiftUI (`Settings` scene, `@Observable`, `UserDefaults`), garantindo integração perfeita no sistema operativo e reatividade instantânea.

### Estrutura das Abas de Definições
1. **Geral**:
   - Iniciar no Login (toggle demonstrativo/persistido).
   - Presença no Sistema / Modo Dock (`dynamic`, `menuBarOnly`, `alwaysDock`).
2. **Gravação**:
   - Modo de Ativação (`toggle` vs `pushToTalk`).
   - Gravador Interativo de Atalho Global (padrão: `Option + Espaço`, botão para gravar/repor).
   - Timeout de Silêncio Contínuo (15s, 30s, 45s, 60s, Desativado).
   - Sons de Feedback Sensorial (Ligado / Desligado).
3. **Texto & Idioma**:
   - Idioma Primário (Deteção Automática `pt/en`, Fixo `pt-PT`, Fixo `en-US`).
   - Feedback Visual durante a fala (Onda Sonora, Transcrição em Tempo Real, Direto no Cursor).
   - Comandos Orais de Pontuação (Ligado / Desligado).
   - Filtro de Palavras de Hesitação (Ligado / Desligado).
   - Capitalização Automática e Ponto Final Automático.
4. **Clipboard**:
   - Salvaguarda do Clipboard (Modo A: Manter Cópia vs Modo B: Preservar Anterior).
   - Estratégia de Injeção de Texto (Acessibilidade com Fallback, Apenas Acessibilidade, Apenas Eventos de Teclado).
5. **Estatísticas**:
   - Seleção de cartões e métricas visíveis no Dashboard (Tempo poupado, total de palavras, palavras hoje, divisão PT/EN).

## Sub-Agent Delegation Plan (🎨 Trio UI/UX & Native Desktop)
1. **`fullstack-engineer`**: Implementação do modelo de dados de preferências, `PreferencesManager` com persistência em `UserDefaults`, propagação em tempo real para os serviços ativos do `AppDelegate`, e suite completa de testes unitários.
2. **`frontend-design-specialist`**: Implementação da interface visual `SettingsView` com abas nativas, alinhamento Apple HIG, componente gravador de atalho `HotkeyRecorderView`, e integração de abertura da janela no `AppDelegate` e `MenuBarExtraManager`.
3. **`qa-security-auditor`**: Auditoria contra falhas silenciosas, verificação estrita de ausência de stubs em produção, verificação de tipografia óptica SF Pro, alvos interativos >= 44x44pt e execução de 100% dos testes unitários.
4. **`devops-release`**: Validação da suite de testes completa e fecho da versão com commit semântico atómico `feat(settings): implement preferences manager and native settings panel (#10)`.
