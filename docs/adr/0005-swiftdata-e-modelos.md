# ADR-0005 — SwiftData para persistência local do MVP

**Status:** Proposto | **Data:** 2026-10-27

## Contexto
Precisamos persistir jogos, consoles, fontes, perfis de emuladores, favoritos e metadados sem servidor.

## Decisão
Adotar **SwiftData** (macOS 14+) com modelos persistentes mantidos atrás de protocolos de repositório/serviço quando necessário à testabilidade. Não armazenar imagens grandes ou ROMs como blobs no banco. Guardar referências de arte/caminhos de cache. Definir IDs estáveis, migração e backup/export como problemas explícitos do desenho. Evitar acesso descoordenado ao `ModelContext` entre atores/threads.

## Consequências
Baixa dependência externa e integração com SwiftUI; exigirá testes de migração e cuidado com importações em lote.

## Alternativas
SQLite direto/GRDB (mais controle, dependência e código); JSON único (escalabilidade/consistência fracas); Core Data (mais boilerplate).
