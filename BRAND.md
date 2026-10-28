# Marca do RetroX

O **código** do RetroX é software livre, licenciado sob a [GPL-3.0](LICENSE).
A **marca** não é: ela fica fora dessa licença.

## O que é reservado

Copyright © 2026 Otávio Luque. Todos os direitos reservados sobre:

- **A Rayo**, a personagem da identidade visual, em qualquer versão, recorte ou derivação.
- **O logo e o kit da marca** do RetroX (tile, ícone, assinaturas e wordmark).
- **Os nomes "RetroX" e "Rayo"**, como marca.

Arquivos cobertos:

| Caminho | O que é |
|---|---|
| `docs/design/rayo/` | Arte original da Rayo |
| `docs/design/logo/` | Kit da marca gerado a partir da Rayo |
| `Support/RetroX.icns` | Ícone do app |
| `Sources/RetroXApp/Resources/RayoMark.png` | Tile da Rayo usado na interface |
| `docs/images/` | Capturas de tela que mostram a Rayo |

Esses arquivos estão no repositório para que o projeto compile e funcione, mas **não** são
licenciados sob a GPL-3.0. Nada na GPL-3.0 dá direito de usá-los.

O tema de cores "Rayo Paradise" é só uma paleta de cores e faz parte do código (GPL-3.0). O nome
dele, porém, remete à marca.

## O que você pode fazer

- Ler, estudar, compilar e rodar o RetroX para uso próprio, com a Rayo incluída.
- Usar o código livremente, nos termos da GPL-3.0.
- Citar o RetroX e mostrar capturas de tela para falar do projeto (uma resenha, um artigo, uma issue).
- Fazer fork e abrir pull requests de código para este repositório.

## O que você não pode fazer sem autorização

- Distribuir um fork, build ou app que use a Rayo, o logo ou o nome RetroX.
- Usar a Rayo em outro produto, material de divulgação, loja, merchandising ou obra derivada.
- Sugerir que seu fork é o RetroX oficial ou que tem apoio do projeto.

Para pedir autorização, escreva para [yukaritake@proton.me](mailto:yukaritake@proton.me).

## Como publicar um fork

1. **Troque o nome** do app e do pacote (`Package.swift`, `Support/`, `scripts/`).
2. **Troque a arte**: substitua `docs/design/rayo/rayo.png` pela sua ilustração e rode
   `swift scripts/brand-kit.swift`. Isso regenera o kit, o tile e o ícone. Substitua também
   `Support/RetroX.icns` e remova as capturas de tela de `docs/images/`.
3. **Remova ou renomeie** o tema "Rayo Paradise" se quiser evitar qualquer associação.
4. Mantenha os avisos de copyright do código e a licença GPL-3.0, como ela exige.

Sem o tile, a interface cai num "R" provisório (`Sources/RetroXApp/DesignSystem/Brand.swift`).
