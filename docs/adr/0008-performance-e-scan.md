# ADR-0008 — Scan incremental e imagens sob demanda

**Status:** Aceito | **Data:** 2026-10-27

## Contexto
Bibliotecas podem ter milhares de entradas. O app não deve congelar por enumeração de diretórios, hash de ROMs grandes ou decodificação de thumbnails.

## Decisão
Scanner assíncrono e cancelável, sem bloqueio da main thread, com resultados enviados em lotes; re-scan incremental quando viável. Imagens carregadas sob demanda, cache de thumbnails redimensionados com invalidação. Nenhum hash integral obrigatório no MVP. Medir desempenho em 100, 1.000 e 5.000 registros em hardware real, depois otimizar com instrumentos.

## Consequências
UI responsiva, mas mais estado de progresso e complexidade de atualização/coerência.

## Alternativas
Scans completos síncronos, full-size artwork no grid ou pre-hash de todas as ROMs (lentos).

## Emenda (2026-10-27)
- O scanner usa `FileManager.enumerator` com pré-carga de resource keys, pula arquivos ocultos e packages, e publica em lotes de cerca de 200 itens.
- Thumbnails são geradas com ImageIO (`CGImageSourceCreateThumbnailAtIndex`), com `NSCache` em memória e cache em disco em `Caches/RetroX/Thumbnails`.
