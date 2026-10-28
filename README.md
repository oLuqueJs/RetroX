# ConsoleShelf — pacote de especificação para Claude Code

Contém:

- `PROMPT_CLAUDE_CODE.md`: instruções de primeira sessão em Plan Mode.
- `docs/PRD.md`: produto, escopo, requisitos e critérios de aceite.
- `docs/adr/`: decisões de arquitetura propostas (não finalizadas).
- `ConsoleShelf_PROMPT_COMPLETO.md` (também disponível separadamente): tudo em um único texto para copiar e colar.

## Como usar

1. Extraia este pacote no repositório vazio do projeto.
2. No terminal do macOS, execute `claude --permission-mode plan` (ou abra `claude` e use `/plan`).
3. Envie ao Claude Code: `Leia @PROMPT_CLAUDE_CODE.md, @docs/PRD.md e todos os @docs/adr/*.md. Produza o plano solicitado, sem implementar antes de minha aprovação.`
4. Revise o plano e **só depois** autorize a implementação, começando pela prova de conceito PCSX2.

**Nota:** A documentação citada é referência técnica, não licença para copiar ativos ou código de terceiros.
