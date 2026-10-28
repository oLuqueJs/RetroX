# Kit da marca RetroX

A marca é a **Rayo** (o tile) e o nome **RetroX**, com o "X" na cor de destaque. Tudo aqui é gerado a partir de
`docs/design/rayo/rayo.png` por `swift scripts/brand-kit.swift`; para mudar o kit, mude o original ou o script,
nunca os PNGs à mão.

![Prancha do kit](retrox-kit.png)

## Arquivos

| Arquivo | Uso |
|---|---|
| `retrox-icon-1024.png` | Ícone na grade do macOS (corpo 824/1024, cantos transparentes). O `.icns` fica em `Support/RetroX.icns` |
| `retrox-tile-512.png` | Só o tile, sem margem: avatares, favicons, redes |
| `retrox-lockup-on-dark.png` / `-on-light.png` | Assinatura horizontal (padrão; barra superior e abertura do app) |
| `retrox-stacked-on-dark.png` / `-on-light.png` | Assinatura empilhada: espaços estreitos e verticais (README, redes) |
| `retrox-wordmark-on-dark.png` / `-on-light.png` | Só o nome, quando a Rayo já está por perto |

## Alinhamento

Toda medida vem da **altura das maiúsculas (C)** do nome, em SF Pro Rounded Heavy com tracking −1,5%.

- **Horizontal:** tile = 2C. A faixa das maiúsculas (da linha de base ao topo do "R") fica centrada no tile. O vão
  entre o tile e a tinta do "R" é 0,75C.
- **Empilhada:** tile = 3C, centrado sobre o nome. Do pé do tile ao topo das maiúsculas: 1C.
- **"o→X":** o X tem recuo lateral largo, então o par leva um aperto extra de −4,5% do corpo. Assim todos os vãos
  entre as letras ficam iguais.
- **Respiro:** no mínimo 1C livre em volta da assinatura.
- **Tamanho mínimo:** horizontal com nome a partir de 16 pt; abaixo disso, só o tile.

No app, `BrandLockup`, `BrandWordmark` e `BrandMark` (`Sources/RetroXApp/DesignSystem/Brand.swift`) aplicam as
mesmas regras, e lá o "X" segue a cor de destaque do tema escolhido.

## Cores

| Nome | Hex | Uso |
|---|---|---|
| Rosa Rayo | `#FEB5B8` | "X" sobre fundo escuro (10,4:1 sobre `#1B1916`) |
| Rosa fundo | `#B83A55` | "X" sobre fundo claro (4,9:1 sobre `#F4F0EA`) |
| Céu Rayo | `#7BADFD` | Fundo do tile; cor de apoio |
| Tinta / Papel | `#1E1B18` / `#F3EEE7` | "Retro" sobre o claro / sobre o escuro |

## Não fazer

- Não recortar, girar nem trocar a ilustração do tile; não pôr a Rayo em círculo (vira foto de perfil).
- Não colorir o "Retro" nem pintar o "X" com outra cor que não a de destaque.
- Não aproximar o tile do nome além de 0,75C, nem centralizar o nome pela caixa do texto (fica baixo).

## Cabeçalho para o README do projeto

```html
<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="docs/design/logo/retrox-lockup-on-dark.png">
    <img src="docs/design/logo/retrox-lockup-on-light.png" alt="RetroX" width="360">
  </picture>
</p>
<p align="center">Seus jogos, num lugar só. Um launcher nativo para macOS.</p>
```
