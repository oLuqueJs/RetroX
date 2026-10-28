# Brand spec — RetroX ("Portátil quente")

Direção escolhida em 2026-10-28 entre três propostas (Portátil quente, Editorial de caixa, Console funcional). A usabilidade se inspira na filosofia de launchers de portáteis como o iiSU: palco do jogo em foco, prateleira de capas, controle primeiro. A identidade é própria: nenhum logo, tela, som ou asset do iiSU, da Sony ou da Nintendo é usado. As capas exibidas são as que o usuário tem no próprio disco.

Os valores abaixo são a fonte da verdade em `Sources/RetroXCore/Design/Palette.swift`, e o contraste é verificado por teste (`PaletteTests`).

## Temas
O RetroX tem 11 temas, escolhidos por perfil, cada um com variante clara e escura: **RetroX** (a paleta abaixo, com 4 acentos), Gruvbox, Catppuccin (Latte/Mocha), Tokyo Night (Day/Night), Nord, Solarized, Dracula (Alucard/Dracula), Rosé Pine (Dawn/Main), Everforest, Kanagawa (Lotus/Wave) e One. Os esquemas conhecidos usam as cores oficiais de cada projeto, com ajustes mínimos onde a cor original não atingia AA. Quase sempre o ajuste foi no texto secundário; em Catppuccin Latte, Tokyo Night Day, Solarized e Everforest claros, o texto principal ficou um pouco mais escuro para manter a hierarquia. Os valores estão em `Sources/RetroXCore/Design/Themes.swift`, e `ThemeTests` confere contraste e hierarquia de todos.

Cada tema define oito tokens: fundo, superfície, elevado, texto, texto secundário, divisória, acento e texto sobre o acento.

## Cores (tema RetroX)

### Neutros (quentes, nunca preto ou branco puros)
| Token | Claro | Escuro | Uso |
|---|---|---|---|
| background | #F4F0EA | #1B1916 | Fundo das telas |
| surface | #FFFDF9 | #262320 | Cartões, barra de comandos, folhas |
| raised | #EAE4DB | #312D29 | Botões secundários, teclas, chão da prateleira |
| textPrimary | #1E1B18 | #F3EEE7 | Texto principal |
| textSecondary | #6A625A | #ADA59B | Legendas, metadados |
| divider | #DDD5CA | #3B3632 | Separadores |

### Cor de tema (uma por vez, escolhida nos Ajustes)
| Tema | Preenchimento claro | Preenchimento escuro |
|---|---|---|
| Coral (padrão) | #C7472A | #F07A57 |
| Âmbar | #A85E12 | #E9A23B |
| Sálvia | #4F7A52 | #8DBB8F |
| Ardósia | #44657F | #8DB3CF |

Texto sobre o preenchimento: #FFFDF9 no claro, #1B1916 no escuro. A cor de tema aparece só em preenchimentos (Jogar, chave ligada), anéis de foco, halo da capa em foco e marcadores. **Nunca em texto pequeno.**

### Capas geradas (quando não há imagem)
Tom por sistema (PS2: #2E3742), texto #F3EEE7. Sem cores de marca de console.

### Contraste mínimo (testado)
Texto ≥ 4,5:1 sobre background, surface e raised, nos dois modos. Texto sobre a cor de tema ≥ 4,5:1. Anel de foco ≥ 3:1 sobre o fundo.

## Tipografia
SF Pro Rounded para títulos (tom de console), SF Pro para o resto. No máximo quatro tamanhos por tela.

| Nível | Tamanho | Peso |
|---|---|---|
| Display | 34 pt | Bold, rounded |
| Heading | 20 pt | Semibold, rounded |
| Body | 15 pt | Regular (Semibold para ênfase) |
| Caption | 12 pt | Medium; em caixa alta com tracking 1,4 nas linhas de sistema |

## Espaçamento e forma
- Grade de 8 pt: 4, 8, 16, 24, 32, 48. Margem lateral das telas: 48 pt.
- Raios: 8, 12 (capas e cartões pequenos), 16 (cartões grandes). Botões são cápsulas com altura mínima de 44 pt.
- Capas sempre na proporção 5:7.

## Detalhe de assinatura
Na prateleira, a capa em foco sobe 10%, ganha um halo na cor de tema e se reflete no "chão" da prateleira. Com Reduzir Movimento, fica só o anel de foco: nada cresce nem se desloca.

## Movimento
- Foco: `snappy` (0,28 s, pouco quique).
- Hover: `smooth` (0,22 s), com elevação leve (escala 1,03–1,04).
- Trocas de tela: esmaecimento de 0,18 s.
- Abas e seletor de layout deslizam a pílula selecionada (`matchedGeometryEffect`).
- Com Reduzir Movimento, só esmaece: nada cresce nem se desloca.

## Telas
Perfis ("Quem vai jogar?", avatares de 128 pt com anel de foco), Início (palco + prateleira), Biblioteca (grade com quatro layouts: Capas 128 pt, Capas grandes 184 pt, Capas e nomes 148 pt, Lista), Emuladores, Detalhes (folha de 880 × 620) e Ajustes (Aparência e Controle).

## Voz
Português do Brasil, direto e calmo. Mensagens de erro dizem o que aconteceu e oferecem a ação que resolve.
