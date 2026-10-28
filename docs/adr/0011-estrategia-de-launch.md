# ADR-0011 — Estratégia de launch: NSWorkspace por padrão, Process como alternativa

**Status:** Aceito | **Data:** 2026-10-27

## Contexto
O ADR-0003 deixou para um spike a escolha entre `NSWorkspace.openApplication` e `Process` para abrir cada emulador. O spike `docs/spikes/0001-launch-pcsx2-macos.md` abriu o PCSX2 2.9.144 real com caminhos difíceis pelas duas estratégias e checou o resultado no log do próprio emulador.

## Decisão
- **Padrão para emuladores com app (`.app`): `NSWorkspace`** (`WorkspaceLauncher`), com `arguments` = argv do adapter, `activates = true`, `createsNewApplicationInstance = false`, `addsToRecentItems = false`.
- **`Process`** (`FoundationProcessLauncher`) continua disponível por perfil (`EmulatorProfile.strategy`) para diagnóstico e para emuladores sem `.app`. stdout e stderr vão para `/dev/null` ou para um arquivo escolhido, nunca para um pipe sem leitor.
- O término é observado por kqueue (`DispatchSource` de processo), que funciona para as duas estratégias e não depende de run loop. Exit status só existe com `Process`.
- Emulador já aberto: a validação recusa o launch (`emulatorAlreadyRunning`) e oferece trazê-lo para frente. O RetroX não encerra o emulador nem abre outra instância por padrão.
- PCSX2: argv `["-batch", "--", <rom>]`. A tela cheia segue a configuração do próprio emulador, a menos que o perfil force `-fullscreen` ou `-nofullscreen`.

## Por quê
- As duas estratégias entregaram o argv byte a byte e abriram o jogo. O desempate vem do resto:
  - Com `NSWorkspace`, o emulador é lançado pelo LaunchServices: ganha ativação e Dock normais, e responde pelos próprios prompts de privacidade (TCC). Com `Process`, ele vira filho do RetroX e esses prompts são atribuídos ao RetroX.
  - A vantagem do `Process` (exit status e stdout) pesou pouco: o stdout do PCSX2 é quase vazio e o log útil fica no `emulog.txt` dele.
- A documentação da Apple e o teste com emulador falso mostram que, com o app já aberto, o LaunchServices descarta os novos argumentos. Daí a recusa explícita em vez de um launch que "não faz nada".

## Consequências
- Sem exit status na estratégia padrão: a detecção de falha usa a janela de saída precoce (5 s) do `SessionOutcome`.
- Cada novo adapter deve repetir um spike curto (argv + log do emulador) antes de virar padrão.
- Se o RetroX um dia for para sandbox, `arguments` passa a ser ignorado (ADR-0002) e esta decisão precisa ser revista.

## Alternativas
`open -a … --args` via `Process` (mesmo efeito do `NSWorkspace`, com um processo intermediário); nova instância sempre (`createsNewApplicationInstance = true`), que arrisca conflito de memory cards e de configuração; Apple Events de abrir documento (não passam flags como `-batch`).
