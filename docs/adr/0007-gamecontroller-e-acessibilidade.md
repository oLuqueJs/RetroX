# ADR-0007 — Navegação por controle e acessibilidade no sistema de foco

**Status:** Proposto | **Data:** 2026-10-27

## Contexto
A experiência de console depende de navegação previsível por controle, mas precisa continuar totalmente funcional em teclado e mouse.

## Decisão
Criar `InputCoordinator` que transforma entradas GameController/teclado em ações semânticas (up/down/left/right/confirm/back/context), com foco explícito por tela e testes de transição. Não capturar entradas globais do sistema. Garantir teclado como fallback, VoiceOver, foco visível, contraste e Reduce Motion. Gamepad inicialmente como meta Should para não bloquear o primeiro launch real.

## Consequências
Melhor consistência, ao custo de lidar com reconexão, múltiplos gamepads e repetição de comandos.

## Alternativas
Depender só de focus engine automática (pode não bastar); handlers soltos em cada View (comportamento divergente).
