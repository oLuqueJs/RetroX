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
