# Registro de decisões e suposições

Decisões do usuário e suposições de trabalho que não cabem num ADR. Decisões de arquitetura ficam em `docs/adr/`.

## Decisões do usuário (2026-10-27)

| ID | Decisão |
|---|---|
| D1 | O usuário instala o Xcode antes da Fase 2. O SwiftData (ADR-0005) fica mantido. |
| D2 | Git autorizado: repositório local, commits pequenos por tarefa, sem remote e sem push. |
| D3 | O produto passa a se chamar **RetroX** (módulos `RetroXCore`, `RetroXApp`…). "ConsoleShelf" fica só como histórico em `docs/origem/`. |

## Suposições de trabalho

| ID | Suposição | Revisar em |
|---|---|---|
| S1 | Bundle ID provisório `local.retrox.RetroX`, trocado antes de qualquer assinatura Developer ID. | Fase 7 |
| S2 | A versão de PCSX2 validada é a 2.9.144 (macOS, x86_64 via Rosetta). Outras versões podem mudar a CLI. | A cada nova versão do PCSX2 |
| S3 | Por padrão o RetroX respeita a configuração do emulador (tela cheia, confirmação ao sair) e não grava nos arquivos de configuração dele. | — |
| S4 | Dolphin não está instalado na máquina de desenvolvimento; o adapter é testado com fakes até que esteja. | Fase 4 |
| S5 | Deployment target macOS 14 (do PRD), com a troca para macOS 15 em aberto. | Gate da Fase 1 |

## Pendências que dependem do usuário

- Instalar o Xcode e rodar `sudo xcode-select -s /Applications/Xcode.app/Contents/Developer` (Fase 1).
- Instalar o Dolphin para validar a Fase 4.
- Escolher o bundle ID definitivo e ter conta Apple Developer para assinatura e notarização (Fase 7).
