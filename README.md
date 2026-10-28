
<div align="center">
  <img src="./docs/design/logo/retrox-lockup-on-light.png#gh-light-mode-only" alt="RetroX" width="360" />
  <img src="./docs/design/logo/retrox-lockup-on-dark.png#gh-dark-mode-only" alt="RetroX" width="360" />
  <p>Seus jogos, seus emuladores, uma só biblioteca.</p>
</div>

<div align="center">
  <a href="https://www.swift.org/"><img alt="Swift" src="https://img.shields.io/badge/Swift-D63A62?style=for-the-badge&amp;logo=swift&amp;logoColor=white" /></a>
  <a href="https://www.apple.com/macos/"><img alt="macOS" src="https://img.shields.io/badge/macOS-D63A62?style=for-the-badge&amp;logo=apple&amp;logoColor=white" /></a>
</div>

<div align="center">
  <a href="https://github.com/oLuqueJs/RetroX/actions/workflows/tests.yml"><img alt="Status do workflow de testes" src="https://img.shields.io/github/actions/workflow/status/oLuqueJs/RetroX/tests.yml?style=for-the-badge&amp;label=testes&amp;labelColor=D63A62&amp;color=D63A62&amp;logo=github&amp;logoColor=white" /></a>
  <a href="https://github.com/oLuqueJs/RetroX/releases"><img alt="Versão da release" src="https://img.shields.io/github/v/release/oLuqueJs/RetroX?style=for-the-badge&amp;label=vers%C3%A3o&amp;labelColor=D63A62&amp;color=D63A62&amp;logo=github&amp;logoColor=white" /></a>
  <a href="./LICENSE"><img alt="Licença GPL-3.0" src="https://img.shields.io/badge/licen%C3%A7a-GPL--3.0-D63A62?style=for-the-badge&amp;labelColor=D63A62&amp;logo=gnu&amp;logoColor=white" /></a>
</div>

<div align="center">
  <a href="https://github.com/oLuqueJs/RetroX/commits/main/"><img alt="Atividade semanal de commits" src="https://img.shields.io/github/commit-activity/w/oLuqueJs/RetroX?style=for-the-badge&amp;label=commits&amp;labelColor=D63A62&amp;color=D63A62&amp;logo=git&amp;logoColor=white" /></a>
  <a href="https://github.com/oLuqueJs/RetroX/stargazers"><img alt="Estrelas no GitHub" src="https://img.shields.io/github/stars/oLuqueJs/RetroX?style=for-the-badge&amp;label=estrelas&amp;labelColor=D63A62&amp;color=D63A62&amp;logo=github&amp;logoColor=white" /></a>
</div>

<p align="center">
  <a href="#instalação">Instalação</a> ·
  <a href="#como-usar">Como usar</a> ·
  <a href="#desenvolvimento">Desenvolvimento</a> ·
  <a href="#documentação">Documentação</a>
</p>

---

RetroX é um launcher nativo para macOS que reúne seus jogos em uma biblioteca visual e os abre nos emuladores que você já tem instalados. Navegue pelo teclado ou controle, personalize perfis e temas, e volte à biblioteca quando terminar de jogar.

O RetroX não inclui emuladores, jogos, BIOS ou chaves. Ele lê suas pastas de jogos sem copiar, mover ou alterar os arquivos.

<p align="center">
  <img src="docs/images/retrox-inicio.png" alt="Tela inicial do RetroX com uma prateleira de jogos fictícios no tema Rayo Paradise escuro" width="100%" />
  <br />
  <sub>Tela inicial com uma biblioteca de demonstração.</sub>
</p>

## Destaques

- **Biblioteca visual:** navegue por prateleira, carrossel, grade ou lista e encontre seus jogos por busca e console.
- **Perfis pessoais:** cada pessoa mantém seus próprios favoritos, recentes e preferências.
- **Feito para controle:** percorra o aplicativo pelo controle ou teclado, com glifos para Xbox, PlayStation e Switch.
- **Temas para escolher:** personalize cores, fonte e animações com variantes claras e escuras.
- **Seus emuladores:** configure o PCSX2, abra o jogo e volte ao RetroX ao terminar.

### Temas para o seu jeito de jogar

| Rayo Paradise · claro | Gruvbox · escuro |
| :---: | :---: |
| <img src="docs/images/retrox-rayo-claro.png" alt="RetroX com o tema Rayo Paradise claro" /> | <img src="docs/images/retrox-gruvbox.png" alt="RetroX com o tema Gruvbox escuro" /> |

## Instalação

### macOS (Apple Silicon)

**[Baixar a última versão](https://github.com/oLuqueJs/RetroX/releases/latest)**

Você precisa do macOS 14 ou superior e dos emuladores instalados por você. Hoje o RetroX suporta o **PCSX2** (PS2); o Dolphin (GameCube/Wii) está planejado.

1. Baixe `RetroX-<versão>.zip` na [página de Releases](https://github.com/oLuqueJs/RetroX/releases) e confira o `SHA256SUMS.txt`.
2. Descompacte e mova o `RetroX.app` para `/Applications`.
3. Na primeira vez, abra com o botão direito > **Abrir**. O app tem assinatura ad hoc e não é notarizado, então o Gatekeeper pede autorização.

## Como usar

1. Escolha (ou crie) um perfil em **Quem vai jogar?**. Cada perfil tem foto, tema, favoritos e recentes próprios.
2. Vá em **Emuladores**, ative o **PCSX2** e escolha a pasta dele: a que tem o `PCSX2.app` e as pastas de jogos (por exemplo `~/Emulators/ps2`, com `roms/` e `covers/`). O RetroX também usa as pastas de jogos, as capas (inclusive as que o PCSX2 baixa) e a BIOS que o próprio PCSX2 já conhece.
3. Em **Início**, navegue pela prateleira; em **Biblioteca**, veja todos os jogos em grade ou lista, com busca e filtro por console. Pressione **Return** (ou o botão de confirmar) para jogar. Quando o PCSX2 fecha, o RetroX volta para a frente.
4. Em **Detalhes**, troque a capa de um jogo ou busque informações na Wikipedia.
5. Em **Ajustes**, escolha tema, fonte, visualização da tela inicial (Prateleira, Carrossel ou Grade), animações e o tipo de controle. Cada perfil guarda os seus.

### Controles

| Ação | Teclado | Controle |
| --- | --- | --- |
| Navegar | Setas | Direcional ou analógico |
| Confirmar ou jogar | Enter | Botão de confirmar¹ |
| Voltar | Esc | Botão de voltar |
| Trocar de aba | `[` / `]` ou ⌘1–⌘4 | Gatilhos |
| Trocar prateleira ou console | Q / E | Botões superiores |
| Abrir detalhes | Espaço | Botão de detalhes |
| Favoritar | F | Botão de favorito |
| Buscar na biblioteca | `/` | — |
| Abrir ajustes | M ou ⌘, | Start |

¹ Por padrão, o botão inferior confirma; no layout Nintendo, é o botão da direita. Em **Ajustes > Controle**, escolha os glifos de Xbox, PlayStation (DualSense) ou Switch.

## Desenvolvimento

Para compilar: Swift 6, com as Command Line Tools ou o Xcode.

```sh
swift build                       # app, ferramentas e núcleo
swift test                        # testes unitários
scripts/bundle-app.sh debug       # monta .build/RetroX.app
open .build/RetroX.app
```

Estrutura: `Sources/RetroXCore` (domínio, emuladores, biblioteca), `Sources/RetroXApp` (SwiftUI),
`Tests/` e `docs/`. Veja o [guia de contribuição](CONTRIBUTING.md), a [estratégia de testes](docs/TESTING.md)
e as [decisões de arquitetura](docs/adr/).

## Documentação

- [PRD](docs/PRD.md): produto, escopo e critérios de aceite
- [Decisões de arquitetura](docs/adr/): interface, plugins, lançamento e metadados
- [Decisões e pendências](docs/DECISOES.md)
- [Estratégia de testes](docs/TESTING.md)
- [Design](docs/design/brand-spec.md) e [marca](BRAND.md)

<p align="center">
  <img src="docs/design/logo/retrox-tile-512.png" alt="Rayo, personagem da identidade visual do RetroX" width="96" />
  <br />
  <sub>Conheça a Rayo no <a href="docs/design/logo/README.md">kit da marca</a>.</sub>
</p>

---

## Licença

Copyright © 2026 Otávio Luque ([yukaritake@proton.me](mailto:yukaritake@proton.me)).

Este projeto é licenciado sob a GNU General Public License v3.0. Veja [LICENSE](LICENSE) para os detalhes.

A licença vale para o **código**. A Rayo, o logo, o ícone e os nomes RetroX e Rayo são marca e ficam fora dela, com todos os direitos reservados. Veja [BRAND.md](BRAND.md) para o que é permitido e como publicar um fork.

Contribuições são bem-vindas por fork e pull request. Veja o [guia de contribuição](CONTRIBUTING.md).

Mesmo com a licença GPL, fique à vontade para entrar em contato se quiser usar o RetroX num projeto proprietário. Estou aberto a combinar licenças alternativas caso a caso.

PCSX2, Dolphin e os nomes de consoles citados pertencem aos seus respectivos donos. O RetroX não é afiliado a eles, e ilustrações, logos e telas de terceiros citados como inspiração não são usados no projeto.