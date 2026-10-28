# ADR-0009 — Segurança, logs e observabilidade locais

**Status:** Proposto | **Data:** 2026-10-27

## Contexto
O app pode iniciar programas externos escolhidos pelo usuário e ler estruturas de pastas pessoais.

## Decisão
Sem shell concatenado; argumentos como array; validação de URL/arquivos; não executar scripts fornecidos via metadata; evitar abrir caminhos arbitrários recebidos da rede. Usar `os.Logger` com dados pessoais privados/redigidos, diagnóstico local opt-in para exportar logs, sem analytics remoto por padrão. Nunca solicitar senha administrativa nem executar alterações destrutivas.

## Consequências
Menos risco e maior previsibilidade; troubleshooting requer logs locais bem delimitados.

## Alternativas
Logging irrestrito de paths, execução de comandos livres e telemetria automática (rejeitados).
