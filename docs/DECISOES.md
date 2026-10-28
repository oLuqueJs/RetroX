# Registro de decisões e suposições

Decisões do usuário e suposições de trabalho que não cabem num ADR. Decisões de arquitetura ficam em `docs/adr/`.

## Decisões do usuário (2026-10-27)

| ID | Decisão |
|---|---|
| D1 | O usuário instala o Xcode antes da Fase 2. O SwiftData (ADR-0005) fica mantido. |
| D2 | Git autorizado: repositório local, commits pequenos por tarefa, sem remote e sem push. |
| D3 | O produto passa a se chamar **RetroX** (módulos `RetroXCore`, `RetroXApp`…). "ConsoleShelf" fica só como histórico em `docs/origem/`. |

## Decisões do usuário (2026-10-28)

| ID | Decisão |
|---|---|
| D4 | Emuladores são **plugins** que o usuário ativa; o primeiro é o plugin nativo do PCSX2 (ADR-0013). |
| D5 | A "pasta raiz" de um emulador é a pasta que guarda o app dele junto com ROMs, capas e BIOS (ex.: `~/Emulators/ps2`). |
| D6 | Direção visual **"Portátil quente"** (docs/design/brand-spec.md), com a usabilidade de launcher de portátil inspirada no iiSU e identidade própria. |
| D7 | A skill `swiftui-design-skill` faz parte do projeto (`.claude/skills/`); os passos dela de baixar assets de marca não se aplicam. |
| D8 | Perfis de jogador com tela de seleção ao abrir (estilo console). Favoritos, recentes e tema são por perfil; capa própria e informações dos jogos são compartilhadas. |
| D9 | 11 temas de cor (RetroX + 10 esquemas conhecidos), cada um claro e escuro, escolhidos por perfil. |
| D10 | Informações de jogos: banco do PCSX2 offline e Wikipedia/Wikidata sob demanda, com escolha do resultado (ADR-0014). Capas não são baixadas da internet. |
| D11 | ~~RetroAchievements e controle do PCSX2 em leitura.~~ Revisto em D12. |
| D12 | RetroAchievements fica fora do RetroX (pedido do usuário em 2026-10-28): nada é lido nem mostrado. O controle do PCSX2 continua só em leitura; gravar perfil de entrada depende de consentimento e teste com controle (spike 0002). |

## Suposições de trabalho

| ID | Suposição | Revisar em |
|---|---|---|
| S1 | Bundle ID provisório `local.retrox.RetroX`, trocado antes de qualquer assinatura Developer ID. | Fase 7 |
| S2 | A versão de PCSX2 validada é a 2.9.144 (macOS, x86_64 via Rosetta). Outras versões podem mudar a CLI. | A cada nova versão do PCSX2 |
| S3 | Por padrão o RetroX respeita a configuração do emulador (tela cheia, confirmação ao sair) e não grava nos arquivos de configuração dele. | — |
| S4 | Dolphin não está instalado na máquina de desenvolvimento; o adapter é testado com fakes até que esteja. | Fase 4 |
| S5 | Deployment target macOS 14 (do PRD), com a troca para macOS 15 em aberto. | Gate da Fase 1 |
| S6 | Até a Fase 2, o ID de um jogo é o caminho do arquivo; favoritos e histórico ficam em JSON. | Fase 2 |
| S7 | A CLI do PCSX2 2.9.147 é igual à da 2.9.144 validada no spike (conferido no texto de ajuda do binário). | A cada versão |

## Pendências que dependem do usuário

- Instalar o Xcode e rodar `sudo xcode-select -s /Applications/Xcode.app/Contents/Developer` (Fase 1).
- Instalar o Dolphin para validar a Fase 4.
- Autorizar (ou não) o RetroX a criar um perfil de entrada próprio na pasta do PCSX2 e testar com um controle físico (spike 0002).
- Escolher o bundle ID definitivo e ter conta Apple Developer para assinatura e notarização (Fase 7).
