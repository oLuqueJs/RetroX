# ADR-0001 — SwiftUI como UI principal e AppKit seletivo

**Status:** Proposto | **Data:** 2026-10-27

## Contexto
Precisamos de uma aplicação nativa macOS com experiência visual de console, navegação por mouse/teclado/controle e integração com janelas e processos.

## Decisão
Adotar **SwiftUI** como camada de UI, **AppKit** para APIs especializadas do macOS e **GameController** para controles. Criar design tokens para tipografia, cores, raios, espaçamento, estados de foco e motion. Evitar WebView/Electron. Não introduzir Metal/SceneKit até profiling demonstrar necessidade.

## Consequências
Integração macOS e rápida iteração visual, porém foco avançado, entrada de controle e certos comportamentos de janela podem exigir bridges. Separar views de regras de scan/launch para testes.

## Alternativas
AppKit-only (mais boilerplate); renderizador custom com Metal (complexidade injustificada no MVP); frontend web (não atende objetivo nativo).
