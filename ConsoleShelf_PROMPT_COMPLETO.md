# Prompt mestre: ConsoleShelf para macOS (Claude Code, Plan Mode)

> **Uso:** salve estes arquivos na raiz de um repositório novo, abra o Claude Code em **Plan Mode**, e envie este prompt referenciando os documentos. **Não implemente código antes da aprovação explícita do plano.**

## Papel

Atue como **Staff macOS Engineer + Software Architect + Product Designer** especializado em Swift 6, SwiftUI, AppKit, APIs do macOS, UX de interfaces de consoles, acessibilidade, performance e testes. Seu objetivo é planejar e, **somente depois de aprovado o plano**, construir um aplicativo nativo para macOS, provisoriamente chamado **ConsoleShelf** (nome alterável). Responda e documente em **português do Brasil**; use nomes de tipos, símbolos e código em inglês.

## Produto em uma frase

Uma biblioteca visual unificada de jogos de múltiplos consoles, inspirada na filosofia de experiência do **iiSU** e dos home menus de consoles, capaz de localizar ROMs distribuídas em várias pastas e iniciar cada jogo diretamente no **emulador externo configurado pelo usuário**, sem incluir emuladores nem jogos.

## Fontes de referência

- Produto de inspiração, não código/ativos para reutilizar: https://github.com/iisu-network/iiSU e https://iisu.network/gallery
- CLI PCSX2: https://github.com/PCSX2/pcsx2-net-www/blob/main/docs/advanced/cli.md
- CLI Dolphin: https://github.com/dolphin-emu/dolphin/blob/master/Readme.md
- Limitação de `NSWorkspace.OpenConfiguration.arguments` sob sandbox: https://developer.apple.com/documentation/appkit/nsworkspace/openconfiguration/arguments
- Persistência SwiftData: https://developer.apple.com/documentation/swiftdata
- Controles: https://developer.apple.com/documentation/GameController
- Permissões de arquivos: https://developer.apple.com/documentation/security/accessing-files-from-the-macos-app-sandbox

**Não reproduza logos, ilustrações, músicas, assets ou telas do iiSU/Nintendo/Sony.** Desenvolva identidade própria. Não baixe, forneça ou distribua ROMs, BIOS, firmware, keys ou emuladores. Considere apenas arquivos legalmente obtidos pelo usuário.

## Contexto, decisões iniciais e limites

1. Aplicação **nativa em Swift / SwiftUI**, com AppKit pontual. Nada de Electron, React, Tauri, WebView como base de interface, ou emulação própria.
2. Alvo inicial: **macOS 14 ou superior**, desde que o Xcode presente suporte esse deployment target. Preferir compatibilidade Apple Silicon e Intel; registrar restrições dos emuladores por arquitetura.
3. **Offline-first**: navegação, coleção, configurações e abertura de jogos funcionam sem rede.
4. Distribuição inicial: **app macOS fora da Mac App Store**, com planejamento para assinatura/notarização. O sandbox exige pesquisa separada por causa do launch de emuladores com argumentos. **Não prometa compatibilidade com Mac App Store para o MVP.**
5. Os emuladores são **instalados e configurados pelo usuário**. Começar com **PCSX2 (PS2)** e **Dolphin (GameCube/Wii)**. Outros emuladores, incluindo soluções para Switch, são **extensões futuras condicionadas à disponibilidade, legalidade e compatibilidade real em macOS**. Não assumir que Yuzu ou Ryujinx são soluções atuais e suportadas.
6. Pastas de ROMs ficam **onde já estão**, sem cópias ou alterações destrutivas. A biblioteca indexa referências, não importa fisicamente arquivos por padrão.
7. Perfis configuráveis por sistema e, depois, override por jogo. Validar executável, existência da ROM, argumentos e erros de inicialização antes de lançar.
8. Não incluir APIs externas para capas na primeira prova técnica. A biblioteca deve aceitar **placeholders e metadados manuais**. Scraping online será opcional e posterior.
9. Priorizar **responsividade, navegação por teclado/controle, acessibilidade e estabilidade** acima de efeitos visuais.
10. Priorizar padrões simples e testáveis. Não criar arquitetura excessivamente fragmentada apenas para parecer enterprise.

## MODO DE TRABALHO: PRIMEIRO PLANEJAMENTO, DEPOIS IMPLEMENTAÇÃO

Você está em **Plan Mode**. Nesta primeira interação:

### A. Investigue antes de decidir

- Inspecione repositório, arquivos, configuração do git, ambiente, `xcodebuild`, `swift`, versão do Xcode, SDK, deployment targets e arquiteturas disponíveis.
- Identifique se existe projeto Xcode ou se deve ser criado do zero.
- Confirme fatos técnicos importantes na documentação oficial e, quando possível, localmente: ciclo de vida dos processos, modos de abertura com `NSWorkspace` versus `Process`, argumentos CLI para versão do PCSX2/Dolphin **em macOS**, nomes e caminhos executáveis dentro de `.app`, comportamento com app já aberto, sandbox, leitura de caminhos com espaços e Unicode, uso de controles e persistência.
- **Não assuma** que argumentos de documentação Windows são idênticos ao binário macOS sem teste. Não invente suporte ou requisitos.
- Identifique dúvidas bloqueantes. Para preferências não bloqueantes, adote defaults descritos aqui e registre as suposições.

### B. Entregue um plano técnico explícito, sem alterar código

Produza, na resposta do Plan Mode:

1. **Resumo de viabilidade, riscos e lacunas**.
2. **PRD revisado**: verificar se os requisitos em `docs/PRD.md` são coerentes, classificar Must/Should/Could/Won't e apontar ambiguidades.
3. **ADR review**: analisar os ADRs existentes e recomendar manutenção, alteração ou ADRs novos, sem mudar silenciosamente decisões importantes.
4. **Arquitetura proposta**, diagrama textual e responsabilidade de cada módulo.
5. **Design system e mapa de telas**, incluindo comportamento em janela/fullscreen, estados vazios, erros, loading, foco do teclado/controle e Reduce Motion.
6. **Modelo de dados** com entidades, IDs, relacionamentos, política de deduplicação, detecção de arquivos movidos e estratégia de migração.
7. **Contrato dos adapters de emuladores**: `EmulatorAdapter`, `LaunchRequest`, `LaunchResult`, `LaunchError`; templates de argumentos por emulador, validação e isolamento para testes. Justifique `NSWorkspace`, `Process` ou combinação. Nunca executar comandos concatenados via shell.
8. **Plano de execução por fases**, com dependências, pequenas tarefas, estimativas relativas de complexidade e critérios de passagem (gates). A primeira entrega de código deverá ser uma *vertical slice* que abre **uma ROM real de PS2** a partir de uma UI mínima, usando emulador instalado, e que possibilita teste simulado sem o emulador.
9. **Plano de testes** (unitário, integração, acessibilidade, performance e manual) e estratégia de mocks/test fixtures.
10. **Lista de comandos para compilar/testar** que serão usados quando autorizado, com tratamento para ausência de Xcode.
11. **Riscos e trade-offs** ordenados: launch sem sandbox, compatibilidade por emulador, permissões, performance em grandes bibliotecas, metadata matching, copyright de assets e suporte a controle.
12. **Proposta de primeira sprint** limitada à prova técnica e à menor infraestrutura necessária.

**Não criar, editar ou apagar arquivos de código na fase de planejamento. Não entrar em implementação até eu aprovar o plano.** Se não puder executar Xcode, produza o plano e código somente quando autorizado, marcando validações pendentes, sem declarar builds ou testes como executados.

### C. Após eu aprovar

- Implemente **uma fase por vez**, respeitando ADRs e critérios de aceite. Use commits pequenos se eu autorizar git.
- Ao final de cada fase, detalhe arquivos alterados, comandos executados, testes aprovados/falhos e decisões novas. **Nunca afirme que compilou/testou se não executou.**
- Prefira código idiomático Swift, `async/await` e isolamento de estado adequado. Evite lógica de negócio em `View` e evite longas operações de indexação/decodificação de imagens na main thread.
- Não remova dados do usuário, não mova ROMs, não execute instaladores, não modifique sistema ou configurações dos emuladores sem consentimento explícito.
- Use fixtures de teste e caminhos fictícios no repositório; não comite caminhos pessoais nem coleções reais.

## Entradas obrigatórias

Considere **`docs/PRD.md`** e **`docs/adr/*.md`** como especificações iniciais de referência. Se este arquivo estiver sendo utilizado sem os demais, consulte as seções PRD e ADRs na versão consolidada `ConsoleShelf_PROMPT_COMPLETO.md`. Em divergências, descreva o conflito e proponha resolução no plano.

## Resultado esperado da primeira resposta do Claude

Um **plano executável e revisável**; não um dump de código. Com checklist por etapa, gates de aceitação, riscos e decisões registradas. Termine indicando qual será a primeira tarefa após aprovação, mas **não a execute ainda**.


---

# ANEXO I — PRD

# PRD — ConsoleShelf (Product Requirements Document)

**Versão:** 0.1 | **Status:** proposta para validação | **Plataforma:** macOS 14+ | **Idioma da interface inicial:** português do Brasil (arquitetura pronta para localização)

## 1. Visão e problema

Pessoas que usam múltiplos emuladores no macOS guardam ROMs em diferentes pastas e precisam abrir manualmente cada emulador e escolher o jogo. A experiência é fragmentada e a organização depende de ferramentas diversas. **ConsoleShelf** resolve isso com uma biblioteca e um launcher unificados, de estética inspirada em interfaces de consoles portáteis, sem implementar emulação.

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


---

# ANEXO II — Architecture Decision Records (ADRs)

# ADR-0001 — SwiftUI como UI principal e AppKit seletivo

**Status:** Proposto | **Data:** 2026-10-27

## Contexto
Precisamos de uma aplicação nativa macOS com experiência visual de console, navegação por mouse/teclado/controle e integração com janelas e processos.

## Decisão
Adotar **SwiftUI** como camada de UI, **AppKit** para APIs especializadas do macOS e **GameController** para controles. Criar design tokens para tipografia, cores, raios, espaçamento, estados de foco e motion. Evitar WebView/Electron. Não introduzir Metal/SceneKit até profiling demonstrar necessidade.

## Consequências
Integração macOS e rápida iteração visual, porém foco avançado, entrada de controle e certos comportamentos de janela podem exigir bridges. Separar views de regras de scan/launch para testes.

## Alternativas
AppKit-only (mais boilerplate); renderizador custom com Metal (complexidade injustificada no MVP); frontend web (não atende objetivo nativo).


---

# ADR-0002 — Distribuição direta inicialmente, sem App Sandbox

**Status:** Proposto | **Data:** 2026-10-27

## Contexto
Precisamos abrir aplicativos externos com caminho da ROM/argumentos e acessar diretórios escolhidos pelo usuário. Apple documenta que `NSWorkspace.OpenConfiguration.arguments` é ignorado quando o processo chamador está sandboxed; acesso/execução de programas externos também enfrenta restrições de sandbox.

## Decisão
**MVP não sandboxed**, distribuído diretamente, com futura **assinatura Developer ID, hardened runtime e notarização** sujeitas à verificação técnica. Não planejar Mac App Store no MVP. Mesmo fora do sandbox, usar seletores nativos, menor privilégio operacional possível, validações de arquivos e auditabilidade dos lançamentos. Revisitar restrições e alternativas seguras antes de uma distribuição pública.

## Consequências
Facilita PoC, mas exige cuidado de segurança, política de distribuição/atualização e validação de Gatekeeper. O app não deve pedir privilégios administrativos. Não executar shell arbitrário.

## Alternativas
Mac App Store sandboxed (não validada para o launcher); helper privilegiado (complexidade e superfície de risco não justificadas); protocol handlers específicos (apenas onde emulador os suportar).

## Referências
- https://developer.apple.com/documentation/appkit/nsworkspace/openconfiguration/arguments
- https://developer.apple.com/documentation/security/accessing-files-from-the-macos-app-sandbox


---

# ADR-0003 — Adapters de emulador com validação e launch tipados

**Status:** Proposto | **Data:** 2026-10-27

## Contexto
Emuladores possuem executáveis, formatos e argumentos diferentes. Um launcher genérico baseado em string de shell é frágil e inseguro.

## Decisão
Definir protocolos testáveis (`EmulatorAdapter`, `EmulatorRegistry`, `GameLaunching`) e modelos tipados (`LaunchRequest`, `LaunchResult`, `LaunchError`). Cada adapter decide compatibilidade de formato, resolve app/executable configurado, constrói **array de argumentos** e valida entradas. Começar com PCSX2 e Dolphin, idealmente com adapters pequenos e testes com caminhos Unicode/espaços. Determinar em PoC se a execução usa `NSWorkspace.openApplication` ou `Process` para cada binário, considerando app já aberto e ativação de janela. Não interpolar comando em shell.

## Consequências
Extensível, isolável em testes, porém requer manter testes de compatibilidade por versão e plataforma.

## Alternativas
Um switch gigante por console (evolui mal); comando livre sem validação (arriscado); reimplementar emulação (fora do escopo).

## Referências
- https://github.com/PCSX2/pcsx2-net-www/blob/main/docs/advanced/cli.md
- https://github.com/dolphin-emu/dolphin/blob/master/Readme.md


---

# ADR-0004 — Biblioteca indexada não destrutiva

**Status:** Proposto | **Data:** 2026-10-27

## Contexto
ROMs podem estar em múltiplos discos, diretórios e mídias removíveis. Copiar tudo gera uso de espaço e risco de perda de dados.

## Decisão
Manter ROMs no local original; persistir `LibrarySource` e caminhos relativos/identificadores. Scanner não altera arquivos. Entradas com caminho indisponível permanecem no catálogo com status de reparo. Considerar bookmarks persistentes quando for necessário; na versão não sandboxed, não supor que bookmarks com security scope sejam obrigatórios para todo arquivo. Nunca apagar ROM ao excluir entrada da biblioteca.

## Consequências
Importação rápida e menor custo de armazenamento, mas requer controle de arquivos movidos e discos desconectados.

## Alternativas
Copiar toda a biblioteca (uso de disco elevado); symlinks gerenciados (fragilidade); reescrever a estrutura de origem (risco desnecessário).


---

# ADR-0005 — SwiftData para persistência local do MVP

**Status:** Proposto | **Data:** 2026-10-27

## Contexto
Precisamos persistir jogos, consoles, fontes, perfis de emuladores, favoritos e metadados sem servidor.

## Decisão
Adotar **SwiftData** (macOS 14+) com modelos persistentes mantidos atrás de protocolos de repositório/serviço quando necessário à testabilidade. Não armazenar imagens grandes ou ROMs como blobs no banco. Guardar referências de arte/caminhos de cache. Definir IDs estáveis, migração e backup/export como problemas explícitos do desenho. Evitar acesso descoordenado ao `ModelContext` entre atores/threads.

## Consequências
Baixa dependência externa e integração com SwiftUI; exigirá testes de migração e cuidado com importações em lote.

## Alternativas
SQLite direto/GRDB (mais controle, dependência e código); JSON único (escalabilidade/consistência fracas); Core Data (mais boilerplate).


---

# ADR-0006 — Offline-first; metadata e capas opcionais

**Status:** Proposto | **Data:** 2026-10-27

## Contexto
O launcher deve ser útil sem contas/API/network, e provedores de capa podem fornecer correspondências incorretas ou ter limites de uso.

## Decisão
Aceitar título derivado do arquivo, edição manual, placeholder e artwork local no MVP. Manter contratos de `MetadataProvider` e `ArtworkProvider` como extensões posteriores, com cache, confirmação de termos/licença, fallback e seleção manual de resultados. Não incluir conteúdo visual protegido no pacote sem autorização.

## Consequências
Primeira versão menos rica visualmente, mas robusta, privada e testável sem rede.

## Alternativas
Scraping obrigatório no onboarding (frágil); download automático irrestrito (limites, licenças e erro de matching).


---

# ADR-0007 — Navegação por controle e acessibilidade no sistema de foco

**Status:** Proposto | **Data:** 2026-10-27

## Contexto
A experiência de console depende de navegação previsível por controle, mas precisa continuar totalmente funcional em teclado e mouse.

## Decisão
Criar `InputCoordinator` que transforma entradas GameController/teclado em ações semânticas (up/down/left/right/confirm/back/context), com foco explícito por tela e testes de transição. Não capturar entradas globais do sistema. Garantir teclado como fallback, VoiceOver, foco visível, contraste e Reduce Motion. Gamepad inicialmente como meta Should para não bloquear o primeiro launch real.

## Consequências
Melhor consistência, ao custo de lidar com reconexão, múltiplos gamepads e repetição de comandos.

## Alternativas
Depender só de focus engine automática (pode não bastar); handlers soltos em cada View (comportamento divergente).


---

# ADR-0008 — Scan incremental e imagens sob demanda

**Status:** Proposto | **Data:** 2026-10-27

## Contexto
Bibliotecas podem ter milhares de entradas. O app não deve congelar por enumeração de diretórios, hash de ROMs grandes ou decodificação de thumbnails.

## Decisão
Scanner assíncrono e cancelável, sem bloqueio da main thread, com resultados enviados em lotes; re-scan incremental quando viável. Imagens carregadas sob demanda, cache de thumbnails redimensionados com invalidação. Nenhum hash integral obrigatório no MVP. Medir desempenho em 100, 1.000 e 5.000 registros em hardware real, depois otimizar com instrumentos.

## Consequências
UI responsiva, mas mais estado de progresso e complexidade de atualização/coerência.

## Alternativas
Scans completos síncronos, full-size artwork no grid ou pre-hash de todas as ROMs (lentos).


---

# ADR-0009 — Segurança, logs e observabilidade locais

**Status:** Proposto | **Data:** 2026-10-27

## Contexto
O app pode iniciar programas externos escolhidos pelo usuário e ler estruturas de pastas pessoais.

## Decisão
Sem shell concatenado; argumentos como array; validação de URL/arquivos; não executar scripts fornecidos via metadata; evitar abrir caminhos arbitrários recebidos da rede. Usar `os.Logger` com dados pessoais privados/redigidos, diagnóstico local opt-in para exportar logs, sem analytics remoto por padrão. Nunca solicitar senha administrativa nem executar alterações destrutivas.

## Consequências
Menos risco e maior previsibilidade; troubleshooting requer logs locais bem delimitados.

## Alternativas
Logging irrestrito de paths, execução de comandos livres e telemetria automática (rejeitados).


---

# Checklist operacional para o Claude Code

- [ ] Plan Mode: somente inspecionar e planejar.
- [ ] Provar execução PCSX2 com parâmetros e caminhos reais antes de criar UI complexa.
- [ ] Testar scanner e launch com fixtures e mocks.
- [ ] Implementar onboarding mínimo, biblioteca offline e configs.
- [ ] Adicionar Dolphin após validar contratos dos adapters.
- [ ] Implementar grid/console mode, controles e motion responsivo.
- [ ] Registrar comandos/erros/testes reais; não prometer validações inexistentes.
