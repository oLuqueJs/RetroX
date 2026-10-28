# ADR-0004 — Biblioteca indexada não destrutiva

**Status:** Proposto | **Data:** 2026-10-27

## Contexto
ROMs podem estar em múltiplos discos, diretórios e mídias removíveis. Copiar tudo gera uso de espaço e risco de perda de dados.

## Decisão
Manter ROMs no local original; persistir `LibrarySource` e caminhos relativos/identificadores. Scanner não altera arquivos. Entradas com caminho indisponível permanecem no catálogo com status de reparo. Considerar bookmarks persistentes quando for necessário; na versão não sandboxed, não supor que bookmarks com security scope sejam obrigatórios para todo arquivo. Nunca apagar ROM ao excluir entrada da biblioteca.

## Consequências
Importação rápida e menor custo de armazenamento, mas requer controle de arquivos movidos e discos desconectados.

## Alternativas
Copiar toda a biblioteca (uso de disco elevado); symlinks gerenciados (fragilidade); reescrever a estrutura de origem (risco desnecessário).
