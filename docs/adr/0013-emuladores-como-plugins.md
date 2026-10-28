# ADR-0013 — Emuladores como plugins com pasta raiz

**Status:** Aceito | **Data:** 2026-10-28

## Contexto
A primeira interface pedia o caminho do `.app` do emulador e o de cada ROM. Na prática, quem usa emuladores já organiza tudo numa pasta por emulador (o app, `roms/`, `covers/`, a BIOS), e o próprio emulador já conhece as pastas de jogos dele. Pedir arquivo por arquivo era a usabilidade errada, e o seletor ainda perdia a escolha (ver o commit da nova interface).

## Decisão
- Cada emulador é um **plugin** (`EmulatorPlugin`) que o usuário **ativa** na tela Emuladores e para o qual escolhe uma **pasta raiz**: a pasta que guarda o app do emulador e as pastas de jogos.
- O plugin descobre, só lendo:
  - o app (direto na raiz ou uma subpasta abaixo; com várias versões, a mais nova);
  - as pastas de jogos (`roms`, `games`, `jogos`, `isos`…) e as ROMs soltas na raiz;
  - as capas (`covers`…).
- O plugin nativo do PCSX2 também lê, **sem alterar**, a configuração do próprio PCSX2 (`inis/PCSX2.ini`, inclusive no modo portátil): as pastas da lista de jogos (`Paths`, `RecursivePaths`), a pasta de capas e a BIOS escolhida.
- O serial do disco (`SYSTEM.CNF` da ISO) é lido para casar as capas que o PCSX2 baixa, que ele nomeia pelo serial.
- O plugin entrega o `EmulatorAdapter` (ADR-0003) que abre cada jogo. O perfil por sistema do PRD vira "o plugin ativo para aquele sistema"; o override por jogo continua previsto (RF-13).
- Configuração dos plugins e histórico de jogos (favoritos, últimas partidas) ficam em JSON em `~/Library/Application Support/RetroX/` até a Fase 2. Nessa fase a biblioteca vai para o SwiftData (ADR-0005), com ID persistente e detecção de arquivo movido.

## Consequências
- O onboarding encolhe para "ativar o emulador e escolher a pasta dele".
- Até a Fase 2, o ID de um jogo é o caminho do arquivo: mover uma ROM de lugar perde favorito e histórico dela.
- Cada plugin novo (Dolphin, por exemplo) precisa do seu próprio conhecimento de pastas e configuração, e de um spike de launch (ADR-0011).
- Plugins de vários sistemas (GameCube e Wii no Dolphin) dependem da detecção do ADR-0012.

## Alternativas
Perfis por sistema com caminhos manuais, como no PRD original (mais passos, sem aproveitar o que o emulador já sabe); importar a lista de jogos de dentro do cache binário do PCSX2 (formato interno, sem garantia entre versões); copiar as ROMs para uma biblioteca própria (proibido pelo ADR-0004).
