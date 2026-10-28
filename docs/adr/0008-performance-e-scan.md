# ADR-0008 — Scan incremental e imagens sob demanda

**Status:** Proposto | **Data:** 2026-10-27

## Contexto
Bibliotecas podem ter milhares de entradas. O app não deve congelar por enumeração de diretórios, hash de ROMs grandes ou decodificação de thumbnails.

## Decisão
Scanner assíncrono e cancelável, sem bloqueio da main thread, com resultados enviados em lotes; re-scan incremental quando viável. Imagens carregadas sob demanda, cache de thumbnails redimensionados com invalidação. Nenhum hash integral obrigatório no MVP. Medir desempenho em 100, 1.000 e 5.000 registros em hardware real, depois otimizar com instrumentos.

## Consequências
UI responsiva, mas mais estado de progresso e complexidade de atualização/coerência.

## Alternativas
Scans completos síncronos, full-size artwork no grid ou pre-hash de todas as ROMs (lentos).
