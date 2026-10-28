# Spike 0001 — Abrir uma ROM de PS2 no PCSX2 para macOS

**Data:** 2026-10-27 · **Status:** concluído · **Decisão resultante:** ADR-0011

## Pergunta
O PCSX2 para macOS abre diretamente uma ROM recebida por argumento, com caminhos difíceis, quando lançado pelo RetroX? Qual forma de criar o processo usar: `NSWorkspace` ou `Process`?

## Ambiente
- Mac Apple M4, macOS 27.2, Rosetta instalado. Só Command Line Tools (Swift 6.4, SDK 27.0).
- PCSX2 v2.9.144 (`net.pcsx2.pcsx2`), executável `Contents/MacOS/PCSX2`, **x86_64 apenas** (roda via Rosetta), hardened runtime.
- Configuração do PCSX2 do usuário, não alterada: `StartFullscreen=true`, `ConfirmShutdown=true`, BIOS configurada.
- ROM: uma ISO de PS2 do próprio usuário, com espaços e parênteses no nome.
- Ferramenta: `rx-launch-probe`, que usa o mesmo `GameLauncher` do app.

## Evidência estática (sem executar o PCSX2)
O texto de ajuda dentro do binário macOS 2.9.144 (extraído com `strings`) traz `Usage: {} [parameters] [--] [boot filename]` e as flags `-batch`, `-nogui`, `-fullscreen`, `-nofullscreen`, `-bigpicture`, `-fastboot`, `-slowboot`, `-portable`, `-datapath`, `-gamecfg`, `-elf`, `-disc`, `-bios`, `-state`, `-statefile`, `-logfile`, `-testconfig`, `-setupwizard`, `-turbo`, `-unlimited` e `--` ("use quando o nome tem espaços ou começa com hífen"). Bate com a documentação oficial da CLI, que só mostra exemplos de Windows.

## Execuções reais
Cada execução abriu o PCSX2 com `["-batch", "--", <rom>]`. O critério de sucesso foi a linha `isoFile open ok: <caminho>` no log do próprio PCSX2 (`emulog.txt`), comparada byte a byte com o argv, mais o serial do disco e o início da execução do jogo. As sessões foram encerradas com SIGTERM só no pid aberto pelo teste, com autorização do usuário.

| # | Estratégia | Caminho da ROM | Log == argv (bytes) | Jogo iniciou | Término detectado |
|---|---|---|---|---|---|
| A | `workspace` | original: espaços e parênteses | sim | sim (serial SLUS-21490, ELF executando em 6,3 s) | sim, sem exit status |
| B | `process` | symlink em pasta **NFD** com `ç`, `ã`, `ñ`, CJK e emoji; nome **começando com `-`** | sim | sim (4 s) | sim, status 0 |
| C | `workspace` | symlink em pasta e nome **NFC** com acentos | sim | sim (4 s) | sim, sem exit status |
| D | — | com o PCSX2 aberto (durante A), nova validação com outra ROM | — | — | recusada: `emulatorAlreadyRunning`, ação "Trazer emulador para frente" |

Observações:
- O PCSX2 registra exatamente o caminho recebido (o do symlink, não o alvo), sem normalizar Unicode. NFD e NFC funcionaram.
- O `--` é o que permite o nome iniciado por hífen; sem ele, o PCSX2 trataria o nome como opção.
- O PCSX2 trata SIGTERM como Ctrl+C: "Received CTRL+C, attempting graceful shutdown". Saiu em cerca de 1 s, com status 0.
- Com a estratégia `process`, o stdout do PCSX2 é quase vazio (76 bytes). O log útil continua em `emulog.txt`, então capturar stdout ajuda pouco.
- As execuções B e C aparecem como "fechou cedo" porque o SIGTERM do teste veio antes de 5 s. Isso é artefato do teste, não falha.
- `stat` da pasta de ROMs (mtime, tamanho, inode) idêntico antes e depois. Os symlinks ficaram num diretório temporário e foram apagados no fim. O próprio PCSX2 atualiza os arquivos dele a cada jogo (log, `playtime.dat`), como em qualquer uso normal.

## Evidência complementar (emulador falso, `scripts/integration-launch.sh`)
- O argv chega byte a byte pelas duas estratégias, inclusive com `$()`, aspas, NFD, CJK e emoji. O LaunchServices não injeta argumentos extras.
- Com o app já aberto e `createsNewApplicationInstance = false`, o LaunchServices devolve a instância existente (mesmo pid) e **não entrega os novos argumentos**. Isso confirma a documentação da Apple e justifica a recusa feita pela validação.

## Não coberto aqui
- ROM em pasta protegida pelo TCC (Documentos, Mesa, Downloads, volume removível): o prompt de privacidade e a quem ele é atribuído ficam para a Fase 2.
- PCSX2 nativo arm64 (não há build oficial no momento) e macOS 14 em runtime.
- Interação com `ConfirmShutdown=true` quando o usuário fecha o jogo pela interface do PCSX2 (validação manual no Gate G0).
