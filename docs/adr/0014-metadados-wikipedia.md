# ADR-0014 — Informações de jogos: banco do emulador offline e Wikipedia sob demanda

**Status:** Aceito | **Data:** 2026-10-28

## Contexto
O usuário pediu para puxar informações dos jogos de uma fonte pública, como o Playnite faz. O ADR-0006 exige offline-first, fonte opcional, cache, escolha manual do resultado e atenção a termos e licenças.

Opções avaliadas:
- **IGDB** (o padrão do Playnite): bom para jogos, mas exige credenciais de desenvolvedor da Twitch (client ID e secret) de cada usuário.
- **TheGamesDB, ScreenScraper, RAWG**: exigem chave ou conta.
- **Wikipedia e Wikidata**: públicos, sem chave. Texto da Wikipedia em CC BY-SA (exige atribuição); dados do Wikidata em CC0.
- **Banco do próprio emulador**: o PCSX2 traz `GameIndex.yaml` no app (serial → nome oficial, região, compatibilidade). Offline e local.

## Decisão
1. **Offline e automático:** o plugin do PCSX2 lê o `GameIndex.yaml` do app para os seriais da biblioteca. O nome oficial aparece como subtítulo, e região e compatibilidade nos detalhes. O título exibido continua sendo o do arquivo, porque mods e traduções não batem com o nome oficial (ex.: "GT 4 Spec II" tem o serial de "Gran Turismo 4 [Online Public Beta]").
2. **Online, só por ação do usuário:** em Detalhes, "Buscar na Wikipedia" pesquisa (português, depois inglês) e lista resultados. O usuário escolhe o certo, e só então o resumo é baixado e guardado em `games.json`. O Wikidata completa ano, desenvolvedora, editora e gênero quando responde; se estiver fora do ar, fica só o resumo.
3. A fonte e a licença ficam visíveis ("Fonte: Wikipedia (pt) · CC BY-SA", com link). As requisições usam um User-Agent identificado, como pede a política da Wikimedia.
4. **Capas não são baixadas da internet.** Capas de jogos em geral não são livres. O RetroX usa as capas que o usuário tem (pastas do emulador, capas que o PCSX2 baixa, ou uma imagem escolhida em "Trocar capa").
5. O contrato fica aberto para outros provedores. O IGDB pode entrar depois, como opção para quem fornecer as próprias credenciais.

## Consequências
- Funciona sem conta e sem chave. Sem rede, tudo continua funcionando, menos a busca, que avisa.
- Jogos obscuros podem não ter página na Wikipedia; a busca aceita editar o termo.
- Em 2026-10-28 o Wikidata estava fora do ar (503) durante o desenvolvimento. O desenho já trata isso, e o teste `wikidataDown` cobre o caso.

## Alternativas
IGDB por padrão (exige credenciais por usuário); scraping de sites de capas (licenças e termos); buscar automaticamente para a biblioteca inteira (viola a escolha manual do ADR-0006 e gera associações erradas).
