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
