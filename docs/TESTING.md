# Estratégia de testes

O RetroX usa **Swift Testing** (`import Testing`), fornecido pelo toolchain Swift 6.
A suíte usa `@Test`, testes parametrizados, `#expect`, `#require`, traits e funções async.
Não é necessário acrescentar outro framework para testar os protocolos atuais.

## Camadas implementadas

| Camada | Comando | O que comprova |
|---|---|---|
| Unitários e mocks | `scripts/test.sh` | Regras, argumentos, persistência em diretórios temporários, parsing, falhas e interações com dependências simuladas |
| Processo real controlado | `scripts/integration-launch.sh --process-only` | argv byte a byte, término imediato, exit codes 0/17, stream de saída encerrado e executável removido; não abre janela |
| Integração desktop | `scripts/integration-launch.sh` | Inclui LaunchServices, reutilização de instância e o processo falso; requer sessão gráfica |
| Pacote | `scripts/package-app.sh 0.0.0` seguido de `scripts/verify-package.sh 0.0.0` | ZIP extraído, checksum, executável, arquitetura, versão, ícone, recurso da marca e assinatura |
| Instalação real | `RX_PCSX2_APP=/caminho/PCSX2.app scripts/test.sh --filter InstalledEmulatorTests` | Inspeção do bundle e arquitetura, mais preparação do plano do PCSX2 sem executá-lo |
| Rede real | `RX_NETWORK=1 scripts/test.sh --filter MetadataNetworkTests` | Integração opt-in com Wikipedia/Wikidata |

O CI executa os unitários/mocks, o processo falso sem janela e a validação do pacote.
Registra o commit/toolchain e guarda os logs mesmo se os testes falharem. Não depende
de jogos, BIOS, firmware, contas externas nem instalações de emuladores.
As suítes opt-in aparecem como ignoradas no comando padrão.

## Diagnóstico de launch

Para investigar um launch sem a interface, com o mesmo código do app:

```sh
swift run rx-launch-probe --app /Applications/PCSX2.app --rom "/caminho/do/jogo.iso" --dry-run
```

Sem `--dry-run`, o emulador é aberto de verdade.

## Mocks e bibliotecas

`FakeFileSystem` e `FakeRunningApplications` isolam disco e processos abertos.
`RecordingLauncher`/`FailingLauncher` verificam chamadas, roteamento, erros e ausência
de retries/fallbacks não solicitados. `ScriptedHTTP` é um actor por teste com respostas
ordenadas e URLs registradas: testa recuperação entre idiomas e codificação da busca
sem acessar a rede nem depender de estado global. Nenhum desses mocks chega ao app distribuído.

[Swift Testing](https://github.com/swiftlang/swift-testing) já cobre as necessidades atuais.
[Mockable](https://github.com/Kolos65/Mockable) foi avaliado como alternativa para gerar
mocks via macros. Pode valer a pena quando o número de protocolos crescer; agora os
poucos mocks são pequenos e explícitos, sem acrescentar geração de código ou dependências
à compilação. Snapshots visuais e XCUITest seriam uma camada futura para a interface,
separada dos testes de domínio e do contrato de lançamento.

## Emuladores reais: alcance e próximos passos

Os comandos abaixo são somente leitura e exigem o caminho explicitamente:

```sh
RX_PCSX2_APP=/Applications/PCSX2.app scripts/test.sh --filter InstalledEmulatorTests
RX_AZAHAR_APP=/Applications/Azahar.app scripts/test.sh --filter InstalledEmulatorTests
RX_RYUJINX_APP=/Applications/Ryujinx.app scripts/test.sh --filter InstalledEmulatorTests
```

Azahar e Ryujinx validam apenas o contrato genérico do bundle macOS: plist, executável,
permissão e arquitetura compatível. **Não validam argumentos, boot nem integração do
RetroX com esses emuladores**, pois não há adapters implementados para eles.
O teste de PCSX2 cria um arquivo temporário vazio para preparar o plano; não tenta emulá-lo.
Um caminho configurado inválido falha; ausência de configuração deixa o teste ignorado.

| Emulador | Situação no RetroX | Etapa necessária antes de testar boot |
|---|---|---|
| PCSX2 | Adapter e plugin implementados; mocks, processo falso e preflight de instalação | Instalação/versionamento fixos, perfil de teste isolado, BIOS e fixture de teste fornecidas, critério observável de boot e timeout com limpeza do processo |
| Azahar | Sem adapter/plugin | Implementar o contrato a partir da CLI da versão escolhida, depois fixtures homebrew e dados de sistema conforme os requisitos dessa versão |
| Ryujinx | Reconhecido no catálogo, sem adapter/plugin | Escolher explicitamente distribuição/fork e versão, verificar CLI/proveniência e requisitos de firmware/chaves, depois criar adapter e fixture |

Testes de emulação devem rodar opt-in em Mac dedicado com sessão gráfica, GPU e versões
fixadas. Não conectar um runner pessoal com credenciais a pull requests não confiáveis.
Não baixar automaticamente ROMs, BIOS, firmware ou chaves. Um processo vivo ou uma
janela aberta não prova que o jogo iniciou: o cenário precisa observar um marcador
específico (log, frame ou sinal da fixture), encerrar apenas o processo criado e guardar
versão/arquitetura/resultado. Saves e configurações devem ficar em perfil temporário.

Referências primárias para implementar os contratos:

- [CLI do PCSX2](https://github.com/PCSX2/pcsx2/blob/master/pcsx2-qt/QtHost.cpp).
- [Projeto Azahar](https://github.com/azahar-emu/azahar).
- [Testes assíncronos no Swift Testing](https://docs.swift.org/latest/documentation/testing/testing-asynchronous-code/).
