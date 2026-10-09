# Project Brain: Sonotype

> **Single Source of Local Truth**: Mantido e atualizado continuamente ao longo das sessões de planeamento e desenvolvimento.

---

## 1. Visão Geral & Ideia da Aplicação
- **Nome**: Sonotype
- **Conceito**: Aplicação nativa para macOS focada em ditado por voz offline de altíssima velocidade e privacidade. O utilizador aciona um atalho, fala naturalmente em **Português** ou **Inglês**, e o texto é transcrito e inserido diretamente no cursor de qualquer aplicação ativa.
- **Princípio Fundamental**: *Ponytail Code Economy* — Sem bibliotecas de terceiros pesadas, sem sistemas de licença pagos, sem ficheiros legados de dezenas de línguas. 100% focado na experiência de utilização, estética nativa Apple (Apple HIG) e ergonomia do utilizador.

---

## 2. Invariantes Técnicos Ratificados
- **Plataforma**: macOS 14.0+ / 15.0+ (Sequoia)
- **Linguagem & Framework**: Swift 6, SwiftUI nativo, AppKit quando estritamente necessário.
- **Motor de Transcrição**: Apple Speech nativo (`SFSpeechRecognizer` com `requiresOnDeviceRecognition = true`).
- **Idiomas Suportados**: Exclusivamente Português (`pt-PT`, `pt-BR`) e Inglês (`en-US`, `en-GB`), com deteção e alternância rápida.

---

## 3. Caderno de Preferências & Gosto do Utilizador (Living Log)
*(Esta secção é preenchida iterativamente com base nas respostas dadas pelo utilizador)*
- **Indicador Visual de Gravação (HUD)**: Pílula Flutuante Central (Floating Pill) no centro inferior do ecrã.
- **Estética & Animação (C1)**: Ponto pulsante minimalista (*Glow Pulse*) que pulsa suavemente com a amplitude da voz; cápsula em vidro translúcido adaptativo nativo Apple (`.regularMaterial` em Claro/Escuro).
- **Comportamento do Atalho**: Modo Toggle / Mãos Livres (1 toque para iniciar, mãos livres para alternar janelas/separadores e consultar informação enquanto fala, 1 toque para finalizar e inserir). Tecla Escape para cancelar.
  - Atalho padrão de fábrica: `Option + Espaço` (com componente de gravação de atalho customizado nas Definições).
- **Feedback Sensorial & Áudio**: Sons sutis nativos do macOS por padrão ao iniciar e parar a gravação (configurável nas Definições para ligar/desligar).
- **Flexibilidade nas Definições**: As Definições devem permitir alternar o Modo do Atalho (Toggle vs Push-to-Talk) e alternar Sons (Ligado/Desligado).
- **Idiomas & Deteção**:
  - Padrão: Deteção automática inteligente entre Português e Inglês (Auto-Detect).
  - Definições: Permite fixar o idioma primário (PT ou EN fixo) ou configurar atalhos dedicados opcionais para cada língua.
- **Inserção de Texto & Feedback Visual**:
  - Padrão: Forma de onda suave durante a fala na pílula (sem distrair a visão), texto inserido diretamente no cursor ao finalizar.
  - Definições: Opção de escolher entre "Apenas onda sonora ao falar", "Texto em tempo real na pílula", ou "Digitação direta no documento".
- **Clipboard & Salvaguarda**:
  - Padrão: Colar no cursor + guardar cópia no Clipboard (Cmd+V) para garantir que nada é perdido.
  - Definições: Opção para preservar o clipboard anterior sem sobrescrever.
- **Dashboard & Histórico**:
  - Janela nativa clássica macOS com Barra Lateral (`NavigationSplitView` com Sidebar estilo Apple Notes/Settings).
  - Secções na barra lateral: *Histórico*, *Estatísticas / Resumo*, *Dicionário* e *Definições*. Painel de detalhe amplo à direita com pesquisa e ações rápidas.
  - Exportação prática de histórico para `.txt`, `.md` e `.csv`, com opção de limpeza segura de dados.
- **Vocabulário & Substituições**:
  - Dicionário integrado para adicionar palavras customizadas (jargão técnico, siglas, nomes próprios) com prioridade de reconhecimento.
  - Tabela de substituição rápida de texto por voz (expansão de atalhos falados, ex: "meu email" -> endereço real).
- **Presença no Sistema (Dock & Menu Bar)**:
  - Padrão: Híbrido Dinâmico (O ícone na Dock só aparece enquanto o Dashboard ou as Definições estiverem abertos; em segundo plano fica apenas na Barra de Menus).
  - Menu Bar: Clique abre Popover Rápido nativo (estado, atalho Option+Espaço, atalho para abrir Dashboard, Definições e Encerrar).
  - Definições: Permite alternar entre "Dinâmico (Padrão)", "Apenas Barra de Menus", e "Sempre na Dock".
- **Pontuação & Limpeza de Texto**:
  - Padrão: Pontuação inteligente automática por pausas + suporte a comandos orais ("vírgula", "ponto", "nova linha" em PT e EN) + Limpeza automática de palavras de hesitação ("hum", "ãh", "tipo").
  - Definições: Toggles para ativar/desativar comandos orais e filtro de hesitações.
- **Experiência de Primeiro Arranque (Onboarding)**:
  - Guia visual elegante de 3 passos: 1. Permissão de Microfone, 2. Permissão de Acessibilidade com atalho para Definições do Sistema, 3. Área de teste interativo para experimentar o primeiro ditado (Option+Espaço).
- **Proteção de Silêncio / Timeout de Segurança**:
  - Padrão: Encerramento e inserção automática após 45 segundos de silêncio contínuo em modo Toggle (evita gravações involuntárias e poupa bateria).
  - Definições: Seletor de tempo de silêncio (15s, 30s, 45s, 60s, Desativado).
- **Privacidade & Retenção de Áudio**:
  - Zero ficheiros de áudio no disco. Todo o fluxo é processado estritamente em memória RAM e descartado de imediato. O Histórico armazena unicamente o texto transcrito e metadados.
- **Estatísticas & Modularidade da Dashboard**:
  - Padrão: Métricas motivadoras de produtividade (tempo estimado poupado, total de palavras, palavras hoje, divisão PT/EN).
  - Customização: O utilizador pode escolher nas Definições quais os cartões e widgets visíveis no Dashboard.

---

## 4. Roteiro de Implementação (Conversa a Conversa)
O plano completo de desenvolvimento de ponta a ponta encontra-se formalizado em [`docs/roadmap/tasks.md`](roadmap/tasks.md), composto por 12 tarefas autocontidas projetadas para serem executadas sequencialmente (uma conversa por tarefa):
1. **Tarefa 01**: Fundação do Projeto & Build System (`make build`, `make local`).
2. **Tarefa 02**: Pipeline de Áudio & Motor Apple Speech (`AVAudioEngine`, `SFSpeechRecognizer`).
3. **Tarefa 03**: Pós-Processamento, Pontuação & Filtros (Hesitações e comandos falados).
4. **Tarefa 04**: Injeção no Cursor & Salvaguarda de Clipboard (`AXUIElement`, `CGEvent`).
5. **Tarefa 05**: Gestor de Atalho Global & Timeout de Silêncio (`Option + Espaço`, 45s timeout).
6. **Tarefa 06**: Pílula Flutuante HUD (Glow Pulse C1 adaptativo claro/escuro).
7. **Tarefa 07**: Menu Bar Extra & Modo Híbrido da Dock (Popover rápido e dock dinâmica).
8. **Tarefa 08**: Camada de Persistência Local (SwiftData para histórico e dicionário).
9. **Tarefa 09**: Dashboard com Barra Lateral (Histórico, Dicionário, Estatísticas, Exportação).
10. **Tarefa 10**: Painel de Definições & Armazenamento de Preferências.
11. **Tarefa 11**: Experiência de Onboarding & Permissões (3 passos com teste interativo).
12. **Tarefa 11B**: Gestão & Auditoria de Permissões nas Definições (Aba Permissões com auditoria em tempo real, refresh e relançamento do Onboarding).
13. **Tarefa 12**: Hardening de Produção, Assinatura & Packaging (`~/Downloads/Sonotype.app`).

---

## 5. Estado Atual & Backlog no Git
- **Fase**: 100% das Tarefas do Roteiro Concluídas com Sucesso (Tarefas 01 a 12 concluídas, 249 testes unitários e de integração a passar, 0 falhas).
- **Backlog Sincronizado no Git**:
  - Todas as 12 tarefas fundamentais concluídas e verificadas com rigor.
  - Artefactos finais gerados e assinados: `build/Sonotype.dmg` e `~/Downloads/Sonotype.app`.
- **Próximo Passo**: Release v1.0.0 pronta para distribuição. Backlog futuro para v2.0 documentado abaixo.

---

## 6. Backlog Futuro (Roadmap v2.0)
- **Voice Snippets & Prompt Macros**: Expansão de texto e templates longos por comando vocal (ex: *"prompt próxima tarefa"* -> texto pré-configurado). Especificação formal detalhada em [`docs/roadmap/v2-voice-snippets-macros.md`](roadmap/v2-voice-snippets-macros.md).

