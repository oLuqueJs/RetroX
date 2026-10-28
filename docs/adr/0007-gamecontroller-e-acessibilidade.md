# ADR-0007 — Navegação por controle e acessibilidade no sistema de foco

**Status:** Aceito | **Data:** 2026-10-27

## Contexto
A experiência de console depende de navegação previsível por controle, mas precisa continuar totalmente funcional em teclado e mouse.

## Decisão
Criar `InputCoordinator` que transforma entradas GameController/teclado em ações semânticas (up/down/left/right/confirm/back/context), com foco explícito por tela e testes de transição. Não capturar entradas globais do sistema. Garantir teclado como fallback, VoiceOver, foco visível, contraste e Reduce Motion. Gamepad inicialmente como meta Should para não bloquear o primeiro launch real.

## Consequências
Melhor consistência, ao custo de lidar com reconexão, múltiplos gamepads e repetição de comandos.

## Alternativas
Depender só de focus engine automática (pode não bastar); handlers soltos em cada View (comportamento divergente).

## Emenda (2026-10-27)
- `GCController.shouldMonitorBackgroundEvents` fica `false` (default desde o macOS 11.3), de forma explícita: com o emulador em primeiro plano, o RetroX não recebe input do controle.
- O `InputCoordinator` só atua no Console Mode. No Library Mode vale o foco nativo do macOS.

## Emenda (2026-10-28, tarde)
- O controle navega o app inteiro: perfis, Início (as três visualizações), Biblioteca, Emuladores, Ajustes, detalhes e a partida. Só a edição de texto (nome de perfil, busca) continua exigindo teclado.
- Mapa fixo por posição: baixo confirma (direita no layout Nintendo ou com "inverter"), direita volta, esquerda abre detalhes, cima favorita, LB/RB trocam prateleira ou console, gatilhos trocam de aba, Start abre Ajustes, View/Create/− abre Emuladores.
- Presets de glifos: Automático (o próprio controle), Xbox, PlayStation (DualSense) e Nintendo Switch (`ControllerPreset`, testado).
- Os Ajustes saíram da janela separada do macOS e viraram uma tela do app, para serem alcançáveis pelo controle. ⌘, continua abrindo os Ajustes.
- Níveis de animação por perfil (completas, reduzidas, desligadas) somam-se ao Reduzir Movimento do macOS: com qualquer um dos dois, nada cresce, desliza ou inclina.

