# Spike 0002 — RetroAchievements e controle integrados ao PCSX2

**Data:** 2026-10-28 · **Status:** validado. A parte de RetroAchievements foi removida do app a pedido do usuário (D12); a de controle segue em leitura.

## Perguntas
1. Dá para validar a configuração do RetroAchievements do emulador junto com o RetroX, inclusive por perfil?
2. Dá para ter um mini configurador de controle no RetroX que reflita no emulador?

Tudo abaixo foi verificado só lendo arquivos (PCSX2 2.9.147, `PCSX2.ini` do usuário e texto do binário), sem alterar nada.

## RetroAchievements
**O que o PCSX2 guarda:** a seção `[Achievements]` do `PCSX2.ini`, com `Enabled`, `ChallengeMode` (hardcore), `EncoreMode`, opções de notificação e, quando há login, `Username` e `Token`. Na máquina do usuário: `Enabled = false` e sem `Username` nem `Token`, ou seja, desligado e sem conta.

**Implementado e depois removido (D12):**
- A descoberta do plugin lê `Enabled`, `ChallengeMode` e `Username`. **O token nunca é consultado nem exibido**; o teste `achievementsAndController` garante que ele não aparece na descoberta.
- Emuladores mostra "desligado", "ligado sem conta" ou "conectado como X (hardcore)".
- Cada perfil pode guardar o usuário do RetroAchievements. O editor de perfil compara com a conta conectada no PCSX2 e avisa se for outra.

**Por perfil, de verdade, não foi feito:** trocar a conta do emulador ao trocar de perfil exigiria gravar `Username` e `Token` no `PCSX2.ini`. Isso significa guardar o token de cada jogador e alterar a configuração do emulador, o que a suposição S3 proíbe sem consentimento explícito. O PCSX2 tem um login global.

**Possível depois (RF-18):** mostrar progresso e conquistas no RetroX pela Web API do RetroAchievements, com a chave de API que cada usuário gera no site. Não exige mexer no emulador.

## Controle
**O que o PCSX2 guarda:** `[Pad1]` no `PCSX2.ini`, com `Type = DualShock2` e cada botão ligado a uma entrada SDL (`Cross = SDL-0/FaceSouth`, `L2 = SDL-0/+LeftTrigger`…). Ele também aceita perfis de entrada (`inputprofiles/*.ini`, referenciados por `InputProfileName`) e configurações por jogo passadas na linha de comando (`-gamecfg <arquivo>`, presente no texto de ajuda do binário).

**Implementado:**
- Emuladores mostra o tipo de controle e o mapeamento da porta 1 com nomes amigáveis (por exemplo, "× → botão de baixo (A / ×)").
- Ajustes > Controle: escolher o botão de confirmar do RetroX (baixo, ou direita no estilo Nintendo) e um teste ao vivo que mostra a ação de cada botão. Vale só para navegar no RetroX.

**Caminho validado para "refletir no emulador", ainda não implementado:**
1. O RetroX grava um perfil de entrada próprio, `inputprofiles/RetroX.ini`, na pasta de dados do PCSX2. É um arquivo novo; nenhum arquivo existente é alterado.
2. Ao abrir um jogo, passa `-gamecfg <arquivo do RetroX>` com `InputProfileName = RetroX`, sem tocar no `PCSX2.ini`.

Pendências antes de implementar:
- **Consentimento** para criar arquivos na pasta do PCSX2.
- Confirmar no código-fonte do PCSX2 em que seção do arquivo de jogo o `InputProfileName` é lido.
- Testar com um controle físico conectado. O teste do spike 0001 não teve controle.

## Conclusão
- Validação do RetroAchievements: **possível e feita** (leitura).
- Conta por perfil: **não**, sem alterar a configuração do emulador.
- Configurador que reflete no emulador: **possível** pelo caminho `-gamecfg` + perfil de entrada próprio, aguardando consentimento e teste com controle.
