# ADR-0009 — Segurança, logs e observabilidade locais

**Status:** Aceito | **Data:** 2026-10-27

## Contexto
O app pode iniciar programas externos escolhidos pelo usuário e ler estruturas de pastas pessoais.

## Decisão
Sem shell concatenado; argumentos como array; validação de URL/arquivos; não executar scripts fornecidos via metadata; evitar abrir caminhos arbitrários recebidos da rede. Usar `os.Logger` com dados pessoais privados/redigidos, diagnóstico local opt-in para exportar logs, sem analytics remoto por padrão. Nunca solicitar senha administrativa nem executar alterações destrutivas.

## Consequências
Menos risco e maior previsibilidade; troubleshooting requer logs locais bem delimitados.

## Alternativas
Logging irrestrito de paths, execução de comandos livres e telemetria automática (rejeitados).

## Emenda (2026-10-27)
- Os argumentos de um launch são logados com caminhos marcados como `.private`.
- Argumentos extras do usuário são tokenizados ao salvar, guardados como array e validados contra uma lista de flags que o adapter gerencia (por exemplo `--`, `-batch`, `--exec`).
