# ADR-0004 — Biblioteca indexada não destrutiva

**Status:** Aceito | **Data:** 2026-10-27

## Contexto
ROMs podem estar em múltiplos discos, diretórios e mídias removíveis. Copiar tudo gera uso de espaço e risco de perda de dados.

## Decisão
Manter ROMs no local original; persistir `LibrarySource` e caminhos relativos/identificadores. Scanner não altera arquivos. Entradas com caminho indisponível permanecem no catálogo com status de reparo. Considerar bookmarks persistentes quando for necessário; na versão não sandboxed, não supor que bookmarks com security scope sejam obrigatórios para todo arquivo. Nunca apagar ROM ao excluir entrada da biblioteca.

## Consequências
Importação rápida e menor custo de armazenamento, mas requer controle de arquivos movidos e discos desconectados.

## Alternativas
Copiar toda a biblioteca (uso de disco elevado); symlinks gerenciados (fragilidade); reescrever a estrutura de origem (risco desnecessário).

## Emenda (2026-10-27)
- A fonte guarda um bookmark comum (sem security scope) da pasta raiz, além do último caminho conhecido. Cada jogo guarda só o caminho relativo à fonte.
- `sourceOffline` (volume desmontado, bookmark irresolúvel) é diferente de `missing` (arquivo sumiu de uma fonte acessível). Fonte offline nunca marca jogos como ausentes.
- Fontes sobrepostas (uma dentro da outra) são bloqueadas ao adicionar.
