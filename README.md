# RetroX

Launcher nativo para macOS que reúne numa biblioteca visual os jogos de vários consoles e abre cada um no emulador externo que o usuário já tem instalado. O RetroX não inclui emuladores, jogos, BIOS nem chaves, e não copia, move ou altera os arquivos de jogo.

**Status:** Sprint 1 (launch com PCSX2, home e emuladores como plugins). Nome anterior provisório: ConsoleShelf.

## Como usar

1. Escolha (ou crie) um perfil em **Quem vai jogar?**. Cada perfil tem foto, tema, favoritos e recentes próprios.
2. Vá em **Emuladores**, ative o **PCSX2** e escolha a pasta dele: a que tem o `PCSX2.app` e as pastas de jogos (por exemplo `~/Emulators/ps2`, com `roms/` e `covers/`). O RetroX também usa as pastas de jogos, as capas (inclusive as que o PCSX2 baixa) e a BIOS que o próprio PCSX2 já conhece.
3. Em **Início**, navegue pela prateleira; em **Biblioteca**, veja todos os jogos em grade ou lista, com busca e filtro por console. Pressione **Return** (ou o botão de confirmar) para jogar. Quando o PCSX2 fecha, o RetroX volta para a frente.
4. Em **Detalhes**, troque a capa de um jogo ou busque informações na Wikipedia.
5. Em **Ajustes**, escolha tema, fonte, visualização da tela inicial (Prateleira, Carrossel ou Grade), animações e o tipo de controle. Cada perfil guarda os seus.

Teclado: setas navegam, `[` `]` (ou ⌘1–⌘4) trocam de aba, Q/E troca de prateleira ou de console, Espaço abre os detalhes, F favorita, / busca na Biblioteca, M (ou ⌘,) abre os Ajustes, Esc volta.

Controle: o app inteiro funciona pelo controle. O botão de baixo confirma (o da direita no layout Nintendo), o da direita volta, os gatilhos trocam de aba, Start abre os Ajustes. Em Ajustes > Controle dá para escolher os glifos de Xbox, PlayStation (DualSense) ou Switch.

Nada nas pastas dos jogos é copiado, movido ou alterado.

## Requisitos

- macOS 14 ou superior.
- Para compilar: Swift 6 (Command Line Tools ou Xcode). A persistência (Fase 2 em diante) exige o Xcode.
- Emuladores instalados pelo usuário. Hoje: PCSX2 (PS2). Dolphin (GameCube/Wii) está planejado.

## Compilar, testar e rodar

```sh
scripts/check-toolchain.sh        # o que o toolchain atual consegue (Xcode, SwiftData, Rosetta)
swift build                       # app, ferramentas e núcleo
scripts/test.sh                   # testes unitários (Swift Testing)
scripts/integration-launch.sh     # abre um emulador falso de verdade e confere o argv
RX_NETWORK=1 scripts/test.sh --filter MetadataNetworkTests   # busca real na Wikipedia (opt-in)
scripts/bundle-app.sh debug       # monta .build/RetroX.app (assinatura ad hoc)
open .build/RetroX.app
```

Diagnóstico de launch sem a interface (o mesmo código do app):

```sh
swift run rx-launch-probe --app /Applications/PCSX2.app --rom "/caminho/do/jogo.iso" --dry-run
```

Sem `--dry-run`, o emulador é aberto de verdade.

## Documentação

- [`docs/PRD.md`](docs/PRD.md): produto, escopo, requisitos e critérios de aceite.
- [`docs/adr/`](docs/adr/): decisões de arquitetura.
- [`docs/DECISOES.md`](docs/DECISOES.md): decisões do usuário, suposições e pendências.
- [`docs/spikes/`](docs/spikes/): evidências de testes técnicos com emuladores reais.
- [`docs/origem/`](docs/origem/): especificação original usada para planejar o projeto.

Ilustrações, logos e telas de terceiros citados como inspiração não são usados no projeto.

## Releases

O workflow de testes do GitHub Actions testa e valida o pacote em pull requests, pushes
para branches fora de `main` e execuções manuais. O workflow de release reutiliza esses
mesmos testes no commit enviado a `main`. Após os testes de um push em `main`, o semantic-release analisa os commits convencionais,
cria a tag e publica uma GitHub Release quando há alterações que justificam uma nova versão.
O ZIP do `RetroX.app` para Apple Silicon e seu SHA-256 ficam anexados à release.
A primeira versão automática será `1.0.0` se ainda não houver uma tag de release.

Para gerar o pacote localmente em um Mac, execute `scripts/package-app.sh 1.2.3`.
O arquivo é criado em `dist/` para a arquitetura do computador, com assinatura ad hoc;
o Gatekeeper pode bloquear sua abertura em outro Mac.

O pacote de teste e seu checksum também ficam disponíveis na seção **Artifacts** da
execução do workflow no GitHub Actions. Esse pacote usa a versão `0.0.0` e serve para
validar o commit executado. As releases versionadas continuam disponíveis em **Releases**.
Não é necessária uma conta Apple para gerar esses arquivos. A assinatura é ad hoc e
não há notarização; o macOS pode exigir que o usuário autorize a abertura do app.
