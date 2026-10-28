# ADR-0006 — Offline-first; metadata e capas opcionais

**Status:** Aceito | **Data:** 2026-10-27

## Contexto
O launcher deve ser útil sem contas/API/network, e provedores de capa podem fornecer correspondências incorretas ou ter limites de uso.

## Decisão
Aceitar título derivado do arquivo, edição manual, placeholder e artwork local no MVP. Manter contratos de `MetadataProvider` e `ArtworkProvider` como extensões posteriores, com cache, confirmação de termos/licença, fallback e seleção manual de resultados. Não incluir conteúdo visual protegido no pacote sem autorização.

## Consequências
Primeira versão menos rica visualmente, mas robusta, privada e testável sem rede.

## Alternativas
Scraping obrigatório no onboarding (frágil); download automático irrestrito (limites, licenças e erro de matching).
