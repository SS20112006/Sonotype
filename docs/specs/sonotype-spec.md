# Especificação de Produto: Sonotype

## 1. Conceito Nuclear
O **Sonotype** é uma ferramenta de produtividade minimalista para macOS que transforma voz falada em texto escrito no cursor do utilizador, funcionando de forma local e privada.

---

## 2. Decisões de Design & Experiência do Utilizador (UX)
*(Documento vivo a ser refinado pergunta a pergunta)*

### 2.1 Presença Visual e HUD Flutuante
- **Decisão**: Pílula Flutuante Central (Floating Pill / Cápsula).
- **Posicionamento**: Centro inferior do ecrã principal, ligeiramente elevado da margem inferior (evitando sobrepor a Dock se visível).
- **Material & Estética (1)**: Vidro translúcido nativo adaptativo macOS (`.regularMaterial`), que responde harmoniosamente ao Modo Claro e Modo Escuro do sistema, com cantos arredondados contínuos e sombra sutil.
- **Animação Visual (C)**: Ponto pulsante minimalista (*Glow Pulse*) com iluminação e pulsação suave sincronizada com o nível de entrada da voz (visual ultra-limpo, sem barras ruidosas). Entrada e saída da pílula com transição fluida (`.spring()`).

### 2.2 Gatilhos e Comportamento de Atalhos
- **Atalho Padrão de Fábrica**: `Option + Espaço`.
- **Decisão de Modo**: Modo Toggle (Premir para Iniciar / Premir para Concluir).
- **Motivação de Uso**: O utilizador frequentemente navega entre diferentes separadores e janelas para consultar dados enquanto fala; as mãos precisam de ficar 100% livres durante o ditado.
- **Fluxo de Ações**:
  1. Primeiro toque no atalho global (`Option + Espaço`): Inicia a escuta e exibe a pílula visual.
  2. Utilizador navega, lê ou escreve livremente.
  3. Segundo toque no atalho: Encerra o áudio, processa a transcrição e cola o texto no campo atualmente focado.
- **Mecanismo de Cancelamento**: Premir `Escape` ou clicar no botão de descartar na pílula cancela a gravação sem colar nada.
- **Personalização de Atalhos**: As Definições contam com um gravador interativo de atalhos onde o utilizador pode premir qualquer combinação de teclas para substituir o atalho padrão.

### 2.3 Resposta Auditiva e Háptica
- **Decisão**: Sons sutis nativos do macOS por padrão (áudio de feedback para início e fim de gravação).
- **Personalização**: Opção explícita nas Definições para ativar/desativar sons de gravação de acordo com o gosto do utilizador.

### 2.4 Comportamento de Transcrição e Inserção
- **Decisão Padrão**: Onda sonora na pílula enquanto fala (foco total, zero poluição visual enquanto navega ou consulta informação).
- **Ação ao Concluir**: No momento em que o utilizador carrega no atalho para parar, o processador finaliza a transcrição e insere o texto diretamente no campo ativo.
- **Integração com Clipboard**:
  - *Padrão*: Insere no cursor e copia automaticamente para o Clipboard (`Cmd + V`), garantindo segurança contra perdas de foco.
  - *Opção nas Definições*: Permite ativar o modo que preserva o Clipboard anterior sem o sobrescrever.
- **Opções de Visualização nas Definições**: O utilizador pode escolher entre:
  1. *Apenas Onda Sonora* (Padrão: foco limpo).
  2. *Pré-visualização em Tempo Real na Pílula* (Streaming de palavras na cápsula).
  3. *Digitação Contínua em Tempo Real* (Escreve diretamente no campo enquanto fala).

### 2.5 Gestão de Idiomas (Português & Inglês)
- **Decisão Padrão**: Deteção Automática Inteligente (Auto-Detect entre PT e EN).
- **Personalização nas Definições**:
  - Opção de fixar o idioma padrão (Auto / Português / Inglês).
  - Opção de configurar atalhos de teclado dedicados para cada idioma (ex: um para ditar forçadamente em Português e outro para Inglês).

### 2.6 Interface de Definições e Menu Bar
- **Decisão Inicial**: Painel de Definições leve e intuitivo contendo:
  - Alternância do modo de atalho: Toggle vs Push-to-Talk.
  - Alternância de sons de feedback: Ligado vs Desligado.
  - Modo de visualização de texto: Apenas Onda vs Streaming na Pílula vs Digitação Direta.
  - Gestão de Idioma: Auto-Detect vs Fixo vs Atalhos por Idioma.
  - Comportamento de Clipboard: Atualizar Clipboard com transcrição (Padrão) vs Preservar conteúdo anterior.
  - Visibilidade na Dock: Dinâmico (Padrão) vs Apenas Barra de Menus vs Sempre na Dock.
  - Comandos Orais de Pontuação: Ativado (Padrão) vs Desativado.
  - Remoção Automática de Hesitações: Ativado (Padrão) vs Ditado Literal.
  - Inicialização com o sistema: Iniciar automaticamente no Login (Ligado/Desligado).

### 2.7 Dashboard da Aplicação & Histórico
- **Layout de Janela**: Estilo clássico nativo Apple com Barra Lateral (`NavigationSplitView`).
  - **Barra Lateral (Sidebar)** à esquerda:
    - 🕒 **Histórico**: Lista de transcrições com filtros de data e pesquisa rápida.
    - 📖 **Dicionário**: Gestão de vocabulário personalizado e substituição de frases/palavras.
    - 📊 **Estatísticas**: Métricas leves de produtividade (palavras ditadas, tempo poupado estimado, contagem por idioma).
    - ⚙️ **Definições**: Painel completo de configurações da aplicação.
  - **Painel de Conteúdo** à direita:
    - No *Histórico*: Tabela/lista elegante com cada ditado (texto completo, data/hora, idioma e duração), com botão de cópia com 1 clique e botão de apagar.
    - No topo: Barra de pesquisa integrada estilo macOS (`.searchable`).
    - Dimensões recomendadas: Janela de tamanho equilibrado (ex: 800x520 pt) com suporte a modo claro e escuro.

### 2.8 Presença no Sistema, Menu Bar e Comportamento na Dock
- **Menu Bar (Barra de Menus)**:
  - Ícone monocromático nativo no topo do ecrã (com ponto de pulsação suave durante a escuta).
  - **Menu Popover Rápido (ao clicar)**:
    - Estado atual do motor (ex: "Pronto para ditar" / Microfone ativo).
    - Atalho visível (`Option + Espaço`).
    - Botão "Abrir Dashboard" (abre a janela completa com Sidebar).
    - Botão "Definições".
    - Separador e botão "Encerrar o Sonotype" (`Cmd + Q`).
- **Decisão de Presença na Dock**: Modo Híbrido Dinâmico (`NSApplication.ActivationPolicy` dinâmico).
  - Em repouso/escrita: A app corre em modo acessório (`.accessory`), visível exclusivamente na Barra de Menus (zero pegada na Dock ou `Cmd + Tab`).
  - Ao abrir Dashboard/Definições: Transita fluidamente para modo regular (`.regular`), exibindo o ícone do Sonotype na Dock para fácil alternância e gestão de janelas.
  - Ao fechar as janelas: Recolhe novamente para `.accessory`.
- **Configurabilidade**: Nas Definições, o utilizador pode optar por fixar "Sempre na Dock" ou "Nunca na Dock (Apenas Barra de Menus)".

### 2.9 Processamento de Texto, Pontuação & Limpeza
- **Pontuação Inteligente Híbrida**:
  - Pontuação automática por pausas de respiração e ritmo da fala.
  - Mapeamento de comandos orais nos dois idiomas:
    - Português: *"vírgula"* (` , `), *"ponto"* / *"ponto final"* (` . `), *"ponto de interrogação"* (` ? `), *"ponto de exclamação"* (` ! `), *"nova linha"* (`\n`), *"novo parágrafo"* (`\n\n`), *"dois pontos"* (` : `).
    - Inglês: *"comma"*, *"period"*, *"question mark"*, *"exclamation point"*, *"new line"*, *"new paragraph"*, *"colon"*.
- **Filtro de Hesitações (Filler Words)**:
  - Elimina hesitações involuntárias comuns em Português (*"hum"*, *"ãh"*, *"hã"*, *"éé"*, *"tipo"*, *"ou seja"*) e Inglês (*"um"*, *"uh"*, *"er"*, *"like"*).
  - O texto final inserido é limpo, mantendo a gramática correta sem poluição acústica.

### 2.10 Vocabulário Personalizado e Substituição de Texto
- **Palavras Específicas / Jargão**:
  - Lista de termos técnicos, acrónimos e nomes próprios configuráveis pelo utilizador.
  - Injetados no contexto do reconhecedor de fala para garantir prioridade de correspondência fonética.
- **Tabela de Substituições (Snippets por Voz)**:
  - Mapeamento: *Quando eu disser [Gatilho]* ➔ *Escrever [Texto Final]*.
  - Exemplos:
    - "meu email" ➔ "utilizador@email.com"
    - "pr" ➔ "Pull Request"
    - "site" ➔ "https://..."
  - Executado imediatamente antes da inserção no cursor, permitindo alta produtividade no dia a dia.

### 2.11 Experiência de Primeiro Arranque (Onboarding & Boas-Vindas)
- **Apresentação Inicial**: Apresentada apenas na primeira abertura da aplicação (ou reaberta via menu de Ajuda).
- **Estrutura em 3 Etapas**:
  1. 🎙️ **Microfone**: Botão de permissão com estado visual claro (Verificado / Pendente).
  2. 🛡️ **Acessibilidade**: Instrução clara com botão que abre diretamente as Definições de Acessibilidade do macOS (`x-apple.systempreferences:...`).
  3. 🚀 **Área de Treino Interativa**: Caixa de texto integrada onde o utilizador experimenta premir `Option + Espaço`, ditar uma frase de exemplo, ver a pílula animada e ver o texto a ser escrito automaticamente.
- **Conclusão**: Botão "Começar a Usar o Sonotype", que fecha o onboarding e deixa a app pronta a correr na barra de menus.

### 2.12 Modularidade e Personalização da Dashboard
- **Painel de Estatísticas Configurável**:
  - Cartões disponíveis:
    - ⏱️ *Tempo Poupado Estimado*: Comparação fala vs digitação.
    - 📝 *Palavras Ditadas*: Contador geral e diário.
    - 🌐 *Distribuição de Idiomas*: Percentagem Português vs Inglês.
    - ⚡ *Média de Palavras por Minuto (WPM)*.
  - **Controlo Total nas Definições**: Secção "Personalizar Dashboard" onde o utilizador ativa ou desativa com interruptores simples cada cartão individual, mantendo a vista exatamente tão limpa ou tão detalhada quanto desejar.

### 2.13 Proteção de Silêncio e Timeout de Inatividade
- **Decisão Padrão**: 45 segundos de silêncio contínuo em modo Toggle encerra a sessão automaticamente.
- **Comportamento ao Disparar**: Transcreve o áudio recolhido até ao início do silêncio, cola o texto no cursor, reproduz o som suave de fecho e recolhe a pílula flutuante.
- **Configurabilidade nas Definições**:
  - Seletor de tempo de silêncio com opções: 15s, 30s, 45s (Padrão), 60s, ou Desativado (gravação ilimitada até clique manual).

### 2.14 Privacidade e Armazenamento (Zero Retenção de Áudio)
- **Decisão Estrita**: Zero ficheiros de áudio em disco.
- **Ciclo de Vida do Buffer de Áudio**:
  - O áudio capturado pelo microfone via `AVAudioEngine` é mantido estritamente em memória volátil (RAM).
  - É processado pelo motor Apple Speech (`SFSpeechRecognizer`).
  - Assim que a transcrição é gerada e inserida, o buffer de áudio é libertado e destruído de imediato.
- **Persistência de Dados**:
  - A base de dados local (SwiftData ou SQLite leve nativo) armazena exclusivamente: texto da transcrição, data/hora, contagem de palavras e idioma detetado.
  - Zero risco de fuga de áudio pessoal e zero consumo acumulado de armazenamento do Mac.

### 2.15 Exportação e Gestão de Dados do Histórico
- **Formatos de Exportação Suportados**:
  - **Texto Simples (`.txt`)**: Exporta notas consolidadas linha a linha.
  - **Markdown (`.md`)**: Exporta notas formatadas com cabeçalhos de data/hora.
  - **Folha de Cálculo (`.csv`)**: Exporta com colunas organizadas (`Data`, `Hora`, `Idioma`, `Palavras`, `Texto`).
- **Limpeza de Dados**:
  - Opção "Limpar Histórico" com diálogo de confirmação nativo do macOS para prevenir apagamentos acidentais.
  - Opção de eliminação individual de cada entrada com um clique.
