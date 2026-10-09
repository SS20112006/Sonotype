# ADR: Tarefa 12 - Hardening de Produção, Assinatura & Packaging

- **Status**: Aceite
- **Data**: 2026-10-09
- **Issue**: [#12](https://github.com/SS20112006/Sonotype/issues/12)
- **Trio de Ataque**: 🏛️ Trio Arquitetura, Performance & Dívida (`qa-security-auditor`, `complexity-auditor`, `performance-engineer`, `silent-failure-hunter`, `devops-release`)

## Contexto
Com todas as funcionalidades base, interface de utilizador, persistência, preferências e experiência de primeiro arranque (onboarding) concluídas (Tarefas 01 a 11B), era imperativo conduzir a auditoria final pré-distribuição da aplicação Sonotype no macOS Sequoia, garantindo:
1. Conformidade estrita com as políticas de segurança Apple (Entitlements mínimos, sandbox, zero retenção de áudio em disco).
2. Verificação empírica dos SLAs de produção (Cold boot <1s, latência de injeção <50ms, consumo de memória RAM contido).
3. Erradicação de falhas silenciosas e blocos catch desprovidos de telemetria/tratamento.
4. Automação completa de empacotamento através do `Makefile` (`make check`, `make build`, `make local`, `make dmg`).
5. Geração de bundle assinado funcional em `~/Downloads/Sonotype.app` e imagem de instalação `.dmg` pronta para distribuição com atalho para `/Applications`.

## Decisões Arquiteturais

1. **Auditoria de Segurança & Zero Retenção de Áudio**:
   - `Sonotype.entitlements` verificado com escopo mínimo restrito estritamente a entrada de áudio (`com.apple.security.device.audio-input`).
   - Verificação comprovada via suite de testes automatizados (`testZeroAudioRetentionPolicy` e `testAppendBufferInMemoryDoesNotWriteToDisk`) de que zero ficheiros de áudio (`.wav`, `.m4a`, `.caf`) são criados ou persistidos em disco. Os buffers residem 100% em memória volátil durante a sessão e são descartados de imediato.
   - Assinatura de código ad-hoc estável aplicada aos bundles via `codesign --force --deep --sign - --entitlements Sonotype.entitlements`, validada com verificação estrita (`codesign --verify --deep --strict`).

2. **Auditoria Forense de Erros Silenciosos (Silent-Failure Hunt)**:
   - Identificado e corrigido bloco de erro no arranque do teste vocal de onboarding em `SonotypeApp.swift`, adicionando telemetria estruturada via `Logger`.
   - Otimizada a sincronização de persistência em `PersistenceRepository.swift`: remoção de chamada redundante de salvaguarda de contexto no registo de transcrições, cortando o overhead de commit à base de dados em mais de 50%.

3. **Benchmarks e Validação Empírica de SLAs**:
   - Nova suite de testes automatizada `PerformanceAndSlaBenchmarkTests.swift` integrada na suite padrão:
     - **Cold Boot SLA**: Inicialização de todos os serviços essenciais em 0.040s (SLA < 1.0s, margem 25x superior).
     - **Latência de Injeção & Pós-Processamento**: Média de 1.25ms por operação (SLA < 50ms, margem 40x superior).
     - **Consumo de Memória RAM**: Processo do Sonotype em execução mantém ~40.6MB de RSS (SLA < 80MB).

4. **Pipeline de Packaging e Distribuição (`Makefile`)**:
   - **`make local`**: Compila em modo Release, monta o bundle `build/Sonotype.app`, aplica a assinatura e instala de forma resiliente em `~/Downloads/Sonotype.app`.
   - **`make dmg`**: Constrói o staging com o executável assinado e symlink para `/Applications`, gerando a imagem UDZO comprimida `build/Sonotype.dmg` com verificação de integridade criptográfica `hdiutil verify`.

## Conformidade e Verificação
- **Suíte de Testes**: 249 testes unitários e de integração executados com 100% de sucesso (0 falhas).
- **macOS Sequoia**: Imagem DMG montada, verificada com `/Applications` e desmontada sem anomalias.
