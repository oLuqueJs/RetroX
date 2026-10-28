# RetroX

Launcher nativo para macOS que reúne numa biblioteca visual os jogos de vários consoles e abre cada um no emulador externo que o usuário já tem instalado. O RetroX não inclui emuladores, jogos, BIOS nem chaves, e não copia, move ou altera os arquivos de jogo.

**Status:** Sprint 1 (prova técnica do launch com PCSX2). Nome anterior provisório: ConsoleShelf.

## Requisitos

- macOS 14 ou superior.
- Para compilar: Swift 6 (Command Line Tools ou Xcode). A persistência (Fase 2 em diante) exige o Xcode.
- Emuladores instalados pelo usuário. Hoje: PCSX2 (PS2). Dolphin (GameCube/Wii) está planejado.

## Documentação

- [`docs/PRD.md`](docs/PRD.md): produto, escopo, requisitos e critérios de aceite.
- [`docs/adr/`](docs/adr/): decisões de arquitetura.
- [`docs/DECISOES.md`](docs/DECISOES.md): decisões do usuário, suposições e pendências.
- [`docs/spikes/`](docs/spikes/): evidências de testes técnicos com emuladores reais.
- [`docs/origem/`](docs/origem/): especificação original usada para planejar o projeto.

Ilustrações, logos e telas de terceiros citados como inspiração não são usados no projeto.
