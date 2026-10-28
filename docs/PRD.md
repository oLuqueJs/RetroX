# PRD — RetroX (Product Requirements Document)

**Versão:** 0.2 | **Status:** revisado após o plano técnico (ver §12) | **Plataforma:** macOS 14+ | **Idioma da interface inicial:** português do Brasil (arquitetura pronta para localização)

> Nome anterior (provisório): ConsoleShelf. A especificação original está em `docs/origem/`.

## 1. Visão e problema

Pessoas que usam múltiplos emuladores no macOS guardam ROMs em diferentes pastas e precisam abrir manualmente cada emulador e escolher o jogo. A experiência é fragmentada e a organização depende de ferramentas diversas. **RetroX** resolve isso com uma biblioteca e um launcher unificados, de estética inspirada em interfaces de consoles portáteis, sem implementar emulação.

### Proposta de valor

> Abrir um único aplicativo, escolher um sistema ou jogo e iniciar a ROM correta no emulador externo escolhido, com uma navegação bonita, rápida, previsível e confortável no teclado, mouse e controle.

### Público inicial

- Usuário de macOS com ROMs obtidas legitimamente e um ou mais emuladores já instalados.
- Entusiastas de retro gaming que valorizam uma experiência de console nativa, sem menus excessivamente técnicos.
- Usuários que alternam entre uso desktop e fullscreen/controle.

### Diferencial

**Native macOS-first + aesthetics-first + external emulator orchestration.** Diferenciação em UX e integração com macOS; não quantidade de consoles suportados na versão 1.

## 2. Objetivos e não objetivos

**Objetivos do MVP:** indexar pastas sem copiar arquivos; detectar sistemas de forma assistida; manter biblioteca local; configurar PCSX2 e Dolphin; iniciar jogos diretamente; navegar por grid/console e buscar por título; oferecer fluxo útil de onboarding e erros compreensíveis.

**Fora do MVP:** emular internamente, fornecer ROMs/BIOS/keys, baixar firmware, organizar ou mover fisicamente ROMs, instalar emuladores, scraping obrigatório, integração RetroAchievements, sync em nuvem, temas extensíveis, gerenciamento automático de saves, tempo de jogo preciso, dual-screen e distribuição Mac App Store.

## 3. Jornadas principais

1. **Primeiro uso:** abrir app -> explicação curta -> selecionar 1+ diretórios -> configurar sistemas detectados -> escolher executável do PCSX2/Dolphin -> visualizar jogos indexados -> executar jogo de teste.
2. **Uso recorrente:** abrir app -> Home com recentes/favoritos e sistemas -> selecionar console -> escolher jogo -> Play -> emulador abre ROM -> retornar à biblioteca.
3. **Arquivo faltando:** biblioteca preserva entrada e preferências -> sinaliza indisponibilidade -> permite localizar novamente ou remover apenas referência do catálogo.
4. **Emulador faltando:** impedir launch, explicar configuração necessária e abrir configurações. Não instalar nada automaticamente.
5. **Mudança de layout:** alternar Console Mode (imersivo) / Library Mode (desktop), preservando seleção e preferência.

## 4. Requisitos funcionais (RF)

| ID | Prioridade | Requisito e aceite esperado |
|---|---|---|
| RF-01 | Must | Selecionar múltiplas pastas de ROMs pelo seletor nativo, preservando os arquivos originais. |
| RF-02 | Must | Scanner recursivo assíncrono identifica arquivos suportados com base em extensão e configuração de sistema; não presumir console apenas por extensão ambígua. |
| RF-03 | Must | Indexar games com ID persistente, título editável, console, caminho/referência, disponibilidade e data de atualização. |
| RF-04 | Must | Persistir e reabrir biblioteca sem revarrer todos os arquivos obrigatoriamente a cada lançamento. |
| RF-05 | Must | Configurar caminho do emulador por console; validar instalação, arquivo, permissões e compatibilidade antes do launch. |
| RF-06 | Must | Iniciar ROM no PCSX2 e Dolphin com argumentos documentados e testados no macOS; exibir erro com ação de correção. |
| RF-07 | Must | Grid de capas com placeholders, título e console; biblioteca deve funcionar mesmo sem internet/capa. |
| RF-08 | Must | Busca local por nome e filtro por console, com resultado rápido para bibliotecas comuns. |
| RF-09 | Must | Onboarding que permita configurar biblioteca e ao menos um emulador, com estados vazios. |
| RF-10 | Must | Modo em janela com mouse/teclado, escopo de foco consistente e estados de hover/seleção. |
| RF-11 | Should | Console Mode em fullscreen, com navegação de controle usando GameController. |
| RF-12 | Should | Favoritos e seção recentes, persistidos localmente. |
| RF-13 | Should | Trocar emulador padrão do console e definir override por jogo sem duplicar ROM. |
| RF-14 | Should | Rescan manual com progresso, cancelamento e atualização incremental; tratamento de arquivos duplicados ou movidos. |
| RF-15 | Should | Metadados manuais e capas locais personalizadas; scraping de fontes externas é etapa posterior. |
| RF-16 | Should | Layout com transições discretas, configurações de movimento e alternativa com Reduce Motion. |
| RF-17 | Could | Serviços externos para metadata/artwork, com cache, rate limiting e confirmação de termos. |
| RF-18 | Could | Integração com RetroAchievements e exibição de conquistas. |
| RF-19 | Could | Mais adapters: RetroArch, PPSSPP e outros com suporte macOS comprovado. |
| RF-20 | Won't/MVP | Importação destrutiva, downloader de jogos, instalador de BIOS ou integração com arquivos protegidos. |

**Observação:** `.iso`, `.chd`, `.rvz`, `.gcm`, `.wbfs`, `.cue`/`.bin`, `.m3u` e outros formatos requerem mapeamento explícito por sistema/adaptador e testes. Não prometer que todos são suportados. Não tratar ZIP/7z como ROM iniciável sem validação do emulador. Evitar cadastrar pistas de `.bin` de um mesmo `.cue` como jogos diferentes.

## 5. Requisitos não funcionais (RNF)

| ID | Critério |
|---|---|
| RNF-01 | Swift/SwiftUI nativos, AppKit onde necessário; app responsivo sem decodificação de capas e varredura bloqueando a main thread. |
| RNF-02 | Offline-first, sem login e sem servidor obrigatório. |
| RNF-03 | Abertura subsequente rápida de biblioteca já indexada; objetivos de desempenho devem ser medidos em máquina real. |
| RNF-04 | Interface preparada para animações fluidas em 60 Hz, com degradação aceitável e respeito a Reduce Motion. |
| RNF-05 | Nenhuma alteração, cópia ou exclusão de ROMs por padrão. |
| RNF-06 | Erros compreensíveis com ações: localizar ROM, escolher emulador, reindexar e tentar novamente. |
| RNF-07 | Log estruturado com `os.Logger` e privacidade dos caminhos pessoais por padrão. |
| RNF-08 | Testes unitários para scanner, mapeamento de extensões, modelos, resolução de caminhos e construção de argumentos. |
| RNF-09 | Build e testes reproduzíveis via Xcode/xcodebuild em macOS suportado; sem alegar CI macOS se não existir. |
| RNF-10 | Acessível com VoiceOver, foco visível, contraste adequado, navegação por teclado e configurações de movimento. |

## 6. Telas e navegação

**Onboarding:** boas-vindas -> adicionar pastas -> selecionar/confirmar console -> configurar emulador -> escanear -> biblioteca.

**Home (Console Mode):** favoritos/recentes, escolha de sistema, destaque do jogo focado, ações Play/Detalhes; transições simples e sons opcionais desligados por padrão.

**Library Mode:** grid redimensionável de capas, busca, filtros, ordenação por título/sistema/recente, ações de contexto.

**Game Details:** arte, título, console, origem, status, emulador utilizado, Play, favorito e edição manual.

**Settings:** diretórios, emuladores, preferências de UI, controles, diagnósticos e About.

**Estados transversais:** empty library, missing emulator, missing file, unsupported format, scan progress, stale bookmark, no cover, loading, launching, failed launch, no controller.

## 7. Dados sugeridos (conceitual)

- `Game`: UUID, displayTitle, systemID, sourceID, relativePath, originalFilename, optional metadata, artworkKey, favorite, lastLaunchedAt, availabilityStatus.
- `GameSystem`: stable slug (ex.: `ps2`, `gamecube`, `wii`), displayName, supportedFormats, defaultEmulatorProfileID.
- `LibrarySource`: UUID, rootURL reference/bookmark as appropriate, displayName, accessState, lastScannedAt.
- `EmulatorProfile`: UUID, name, systemIDs, appURL/executable reference, adapterID, additionalUserOptions, isEnabled.
- `GameEmulatorOverride`: gameID, emulatorProfileID.
- `ScanRecord` or equivalent: sourceID, scanStatus, warnings, counters, timestamp.

**Estratégia recomendada:** referenciar ROM por `LibrarySource` + caminho relativo, com identificador estável de entrada; manter mapeamento de URLs atuais e resolver bookmarks/URLs quando necessário. Normalizar strings e lidar com colisões de nomes iguais em pastas diferentes. Não usar apenas o título como chave. Hash integral da ROM **não** será obrigatório no MVP, pois jogos podem ser enormes.

## 8. Métricas de validação

- **North Star de UX:** tempo do primeiro clique na biblioteca até o jogo ser entregue ao emulador (medido do app, separado do tempo de boot do jogo).
- Primeiro onboarding sem assistência: proporção de usuários que conseguem configurar uma pasta e emulador.
- Porcentagem de lançamentos válidos concluídos sem erro de launcher.
- Porcentagem de ROMs suportadas corretamente indexadas; falsos positivos/duplicatas.
- Fluidez de navegação com 100, 1.000 e 5.000 entradas; consumo de memória e responsividade medidos, sem promessas prematuras.

## 9. Critérios de aceite do MVP

- [ ] Adicionar pelo menos duas pastas distintas, indexá-las e reiniciar app sem perder a biblioteca.
- [ ] Não copiar, mover ou excluir arquivos de origem.
- [ ] Configurar PCSX2 e Dolphin instalados; associar consoles e validar os caminhos.
- [ ] Clicar em Play num arquivo PS2 suportado e abrir diretamente esse arquivo no PCSX2 no macOS; demonstrar fluxo equivalente com Dolphin.
- [ ] Caminhos com espaços e Unicode não quebram montagem de argumentos.
- [ ] ROM faltante ou emulador ausente geram mensagens úteis, não crash.
- [ ] Busca local, filtro por console e grid de placeholders funcionam offline.
- [ ] UI não trava durante importação, varredura e carregamento de capas.
- [ ] Build/debug local e testes unitários executados, com resultados relatados.

## 10. Riscos e hipóteses

- **R1:** particularidades de launch/CLI dos emuladores em macOS (alto) -> PoC primeiro.
- **R2:** sandbox impede passagem de argumentos/execução externa -> distribuição direta no MVP; ADR específico.
- **R3:** formatos, arquivos multi-disc e detecção de sistema ambígua -> registro explícito por plataforma + correção manual.
- **R4:** capas e scraping podem falhar ou ter direitos restritos -> placeholders e capas fornecidas pelo usuário.
- **R5:** processamento de bibliotecas grandes -> scanner incremental, cache e cancelamento.
- **R6:** dispositivos e configurações de controle variam -> teclado como fallback, foco determinístico e testes manuais.

## 11. Futuro, após MVP

Extensões para outros adapters e formatos, RetroAchievements, provedores opcionais de metadados com limites de API, layouts alternativos (incluindo inspiração dual-screen), temas próprios, assets animados, importação gerenciada explicitamente opt-in e telemetria apenas se houver consentimento. Validar demanda antes de implementar cada item.

## 12. Revisão 0.2 (2026-10-27)

Resultado da revisão feita no plano técnico aprovado. Prevalece sobre as seções anteriores em caso de conflito.

| Ref. | Ajuste |
|---|---|
| RF-03 | A detecção **exata** de arquivo movido (mesmo volume + mesmo `fileIdentifier`) passa a ser Must, porque sem ela o "ID persistente" se perde num simples mover de pasta. A UI de revisão de movidos/duplicatas continua em RF-14 (Should). |
| RF-02 | "Detecção assistida" significa, em ordem: (1) dica de sistema da pasta-fonte; (2) leitura de cabeçalho de até 64 KB, sem hash; (3) extensão inequívoca. Arquivo ambíguo fica em `needsReview` e nunca é atribuído em silêncio. Ver ADR-0012. |
| RF-05 | "Compatibilidade" = bundle válido, executável presente e executável, bundle ID esperado (aviso se diferente), arquitetura executável no host (x86_64 em Apple Silicon exige Rosetta) e versão registrada. Sem bloqueio por versão no MVP. |
| RF-06 | A evidência de "testado no macOS" fica em `docs/spikes/`. O critério do Dolphin fica pendente até haver Dolphin instalado na máquina de teste. |
| Jornadas 2 e 5 | Dependem de requisitos Should (RF-11, RF-12). No MVP Must, a home é o Library Mode; recentes e favoritos aparecem quando existirem. |
| RF-08 | Hipótese a medir, não promessa: filtro em menos de 100 ms com 5.000 itens. |
| §7 Dados | `GameSystem` vira catálogo estático em código; preferências do usuário por sistema ficam em `SystemPreference`. `GameEmulatorOverride` vira relacionamento opcional no jogo (1:1). |
| Formatos | PS2: `iso`, `chd`, `cso`, `zso` (declarados pelo bundle do PCSX2 2.9.144). `mdf`, `bin/cue` e `elf` depois, com teste. GameCube/Wii: `iso`, `gcm`, `rvz`, `wbfs`, `ciso`, `gcz`, `wia`, pendente de verificação com o Dolphin. ZIP/7z: nunca. |
| Jornada 2 | "Retornar à biblioteca" = o emulador é aberto em modo batch (fecha ao parar o jogo) e o RetroX volta à frente quando o processo termina. |
| RNF-09 | Além de Xcode/`xcodebuild`, o caminho reproduzível sem Xcode é `swift build` / `swift test` (SwiftPM). |
| Plataforma | O deployment target macOS 14 compila, mas não é testável na máquina de desenvolvimento atual (macOS 27). A escolha entre 14 e 15 será feita no gate da Fase 1 (ver ADR-0005). |
