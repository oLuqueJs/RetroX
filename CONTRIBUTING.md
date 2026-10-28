# Contribuindo com o RetroX

Obrigado pelo interesse! Contribuições são bem-vindas: código, testes, documentação, relatos de bugs
e ideias. Este guia explica como participar.

## Licença das contribuições

- O código do RetroX é licenciado sob a [GPL-3.0](LICENSE). Ao enviar uma contribuição de código ou
  documentação, você concorda que ela seja licenciada sob a mesma GPL-3.0.
- Só envie o que você escreveu ou tem direito de enviar. Não copie código de projetos com licença
  incompatível com a GPL-3.0.
- A **Rayo, o logo e os nomes "RetroX" e "Rayo" não fazem parte da licença do código** (veja
  [BRAND.md](BRAND.md)). Não envie alterações nesses arquivos de arte, nem arte nova para a marca,
  sem combinar antes numa issue.

## Código de conduta

Seja respeitoso. Críticas são sobre o código e as ideias, nunca sobre as pessoas. Assédio,
discriminação e ataques pessoais não são tolerados, e quem os praticar pode ser removido do projeto.
Para denunciar, escreva para [yukaritake@proton.me](mailto:yukaritake@proton.me).

## Como contribuir

### Relatando bugs e sugerindo melhorias

Abra uma [issue](https://github.com/oLuqueJs/RetroX/issues) depois de procurar se já existe uma
igual. Num bug, inclua:

- versão do RetroX, versão do macOS e arquitetura (Apple Silicon ou Intel);
- emulador e versão envolvidos, se houver;
- passos para reproduzir, o resultado esperado e o que aconteceu;
- logs ou capturas de tela, sem dados pessoais.

Para mudanças grandes (novo emulador, nova tela, mudança de arquitetura), abra uma issue antes de
escrever o código. Assim você evita retrabalho. Decisões já tomadas estão em [docs/adr/](docs/adr/) e
[docs/DECISOES.md](docs/DECISOES.md); o escopo do produto está em [docs/PRD.md](docs/PRD.md).

### Vulnerabilidades de segurança

Não abra issue pública. Escreva para [yukaritake@proton.me](mailto:yukaritake@proton.me) com os
detalhes, e a resposta vem o quanto antes.

### Fluxo de branches

O projeto tem duas branches protegidas:

- **`beta`**: onde toda mudança entra primeiro. Cada merge publica uma pré-release
  (`1.2.0-beta.1`, `1.2.0-beta.2`…), marcada como *pre-release* no GitHub e fora do link "última versão".
- **`main`**: a versão estável. Só recebe a promoção da `beta` e correções urgentes.

**Todo pull request, inclusive de forks, vai para a `beta`.** Se você abrir contra a `main` por engano,
o mantenedor muda o alvo.

- Nome da branch: `<tipo>/<descrição-curta>`, com os mesmos tipos dos commits.
- O PR exige o CI verde e é integrado com **squash merge**. O título do PR vira o commit na `beta`,
  então ele precisa seguir o padrão de commits abaixo.
- Depois do merge, a branch é apagada.
- A versão estável sai quando o mantenedor integra a `beta` na `main`, também por **squash merge**. O
  título desse PR é o commit que define a versão, então usa o tipo da mudança mais relevante
  (`feat: novo tema e capas do Azahar`), e um `BREAKING CHANGE:` vai na descrição. Em seguida, a `main` é
  integrada de volta na `beta`; o mesmo vale depois de qualquer mudança direto na `main`.

### Enviando código por fork e pull request

1. Faça um **fork** do repositório e clone o seu fork.
2. Crie uma branch a partir da `beta`, com um nome que descreva a mudança:
   `feat/dolphin-adapter`, `fix/scan-capas`, `docs/readme`.
3. Faça a mudança (veja as regras abaixo) e rode as verificações.
4. Envie a branch para o seu fork e abra um **pull request** para a `beta` deste repositório.
5. Descreva o que mudou e por quê, e ligue a issue relacionada (`Closes #123`).
6. Responda aos comentários da revisão. Se pedirem ajustes, adicione commits à mesma branch.

Pull requests de primeira vez passam pelo CI (workflow **Testes**). Ele precisa estar verde para o
merge. Ninguém faz push direto na `main` nem na `beta`; todo merge passa por revisão.

## Ambiente de desenvolvimento

Requisitos: macOS 14 ou superior e Swift 6 (Command Line Tools ou Xcode). Mais detalhes no
[README](README.md#desenvolvimento).

```sh
swift build                       # compila app, ferramentas e núcleo
swift test                        # testes unitários
git diff --check                  # espaços em branco sobrando
scripts/bundle-app.sh debug       # monta .build/RetroX.app para testar na mão
```

A estratégia de testes está em [docs/TESTING.md](docs/TESTING.md).

## Regras de código

- Faça a menor mudança correta. Não mexa em arquivos sem relação com a tarefa.
- Respeite a separação de módulos: interface e estado de tela em `Sources/RetroXApp`; lógica de
  domínio, biblioteca, emuladores e infraestrutura em `Sources/RetroXCore`. Não coloque regra de
  negócio em views SwiftUI.
- Siga os protocolos e o estilo do código ao redor (nomes, comentários, concorrência estrita do Swift 6).
- Não adicione dependências sem necessidade. Se for indispensável, justifique no PR.
- Toda mudança de comportamento vem com testes. Não remova nem enfraqueça testes para passar o build.
- A biblioteca é **não destrutiva**: o RetroX nunca escreve nas pastas de jogos do usuário.
- Não inclua credenciais, tokens, dados pessoais, ROMs, BIOS, jogos ou qualquer material protegido por
  direitos autorais de terceiros.
- Não suba arquivos gerados (`.build/`, `dist/`, `node_modules/`).
- Texto de interface e documentação em português do Brasil; identificadores de código em inglês.

## Mensagens de commit

Usamos [Conventional Commits](https://www.conventionalcommits.org/pt-br/), em português, porque o
semantic-release gera as versões a partir deles.

```
feat(biblioteca): detecta capas do Azahar
fix(launch): escapa caminhos com espaços
docs(readme): atualiza a lista de emuladores
```

Tipos usados: `feat`, `fix`, `docs`, `refactor`, `test`, `chore`, `ci`. Eles definem a versão:
`feat` gera minor, `fix` e `chore` geram patch, e `docs`, `ci`, `refactor` e `test` não geram release.
Para mudança incompatível, escreva `BREAKING CHANGE: <descrição>` no corpo do commit (gera major).
O `!` depois do tipo não é reconhecido.

## Releases

O workflow **Testes** roda em pull requests, em pushes para branches fora de `main` e `beta` e sob demanda.
O workflow de release reutiliza esses testes no commit enviado a `main` ou `beta`; depois deles, o
semantic-release lê os commits, cria a tag e publica uma GitHub Release com o ZIP do `RetroX.app`
(Apple Silicon) e o SHA-256. As regras de versão estão em `.releaserc.json`:

| Commit | Versão | Exemplo (a partir de 0.0.0) |
| --- | --- | --- |
| `BREAKING CHANGE` no corpo (qualquer tipo) | major | 1.0.0 |
| `feat` | minor | 0.1.0 |
| `fix`, `chore` | patch | 0.0.1 |
| `docs`, `ci`, `refactor`, `test`, `perf`, `style`, `build` | sem release | — |

Sem nenhuma tag no repositório, o semantic-release começa em `1.0.0`. Para começar em `0.x`, crie antes a
tag `v0.0.0` no commit de partida.

Para gerar o pacote localmente: `scripts/package-app.sh 1.2.3` (o ZIP vai para `dist/`, com assinatura
ad hoc, sem notarização). Cada execução do workflow também deixa um pacote de teste (`0.0.0`) em **Artifacts**.

## Checklist do pull request

- [ ] `swift build` e `swift test` passam localmente
- [ ] `git diff --check` não acusa nada
- [ ] Testes novos ou atualizados cobrem a mudança
- [ ] Documentação atualizada, se a mudança é visível para o usuário
- [ ] Commits no padrão Conventional Commits
- [ ] Não mexi na arte da marca (Rayo, logo, ícone)

Dúvidas? Abra uma issue ou uma discussão. Toda ajuda conta.
