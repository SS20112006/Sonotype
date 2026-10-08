# Tarefa 09: Arquitetura da Janela de Dashboard com Barra Lateral

* Status: accepted
* Deciders: Principal Architect / Orchestrator, User
* Date: 2026-10-08

## Context and Problem Statement
O Sonotype necessita de uma janela principal no macOS para consultar o histórico de transcrições, pesquisar registos em tempo real, gerir termos de vocabulário e regras de substituição rápida de voz, inspecionar estatísticas de produtividade e exportar dados para ficheiros locais (.txt, .md, .csv).
A janela deve seguir estritamente o Apple HIG para macOS Sequoia, utilizando `NavigationSplitView` com materiais nativos, sem bibliotecas de terceiros (Ponytail Code Economy), e sem guardar ficheiros de áudio em disco.

## Decision Drivers
* Conformidade rigorosa com Apple Human Interface Guidelines (`NavigationSplitView`, `.regularMaterial`, SF Pro Text <=19pt, SF Pro Display >=20pt, contraste WCAG 2.1 AA >= 4.5:1, touch/click targets >= 44x44pt).
* Ponytail Code Economy (aproveitar componentes padrão do SwiftUI e o `PersistenceRepository` SwiftData existente).
* Reatividade fluida com `@Observable` e isolamento `@MainActor`.
* Exportação real em disco com `NSSavePanel` nativo do macOS para formatos `.txt`, `.md` e `.csv`.

## Considered Options
* Opção 1: Janela monolítica com abas simples `TabView`.
* Opção 2: Janela dividida nativa com `NavigationSplitView` no estilo Apple Notes / System Settings, separando visualmente Sidebar (Histórico, Dicionário, Estatísticas) e Painel de Detalhe.

## Decision Outcome
Opção escolhida: "Opção 2", porque segue as diretrizes padrão do macOS para aplicações de produtividade orientadas a documentos e histórico, proporcionando navegação intuitiva com pesquisa integrada e suporte a atalhos.

### Positive Consequences
* Interface moderna, familiar e consistente com as aplicações nativas do macOS.
* Pesquisa `.searchable` integrada diretamente na barra lateral e painel de lista.
* Arquitetura desacoplada: `DashboardViewModel` faz a ponte reativa com `PersistenceRepository`, permitindo testes unitários limpos.

### Negative Consequences
* Necessita de gerir dimensões mínimas de janela (`minWidth: 700`, `minHeight: 450`) para evitar aperto de layout.

## Sub-Agent Delegation Plan (🚀 Trio Full-Stack Feature)
1. `frontend-design-specialist`: Desenho e estruturação dos componentes SwiftUI seguindo Apple HIG (`DashboardWindowView`, `HistoryListView`, `VocabularyManagerView`, `StatsOverviewView`).
2. `fullstack-engineer`: Implementação do `DashboardViewModel` `@Observable`, integração de dados com `PersistenceRepository`, ações de exportação com `NSSavePanel`, e testes unitários.
3. `qa-security-auditor`: Verificação estrita de ausência de mocks em código de produção, garantia de zero áudio em disco, verificação de tipografia e acessibilidade, e execução de testes.
4. `devops-release`: Commit semântico atómico (`feat(dashboard): implement sidebar navigation, history, vocabulary and export`) cumprindo Conventional Commits 1.0.0.
