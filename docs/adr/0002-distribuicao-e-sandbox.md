# ADR-0002 — Distribuição direta inicialmente, sem App Sandbox

**Status:** Aceito | **Data:** 2026-10-27

## Contexto
Precisamos abrir aplicativos externos com caminho da ROM/argumentos e acessar diretórios escolhidos pelo usuário. Apple documenta que `NSWorkspace.OpenConfiguration.arguments` é ignorado quando o processo chamador está sandboxed; acesso/execução de programas externos também enfrenta restrições de sandbox.

## Decisão
**MVP não sandboxed**, distribuído diretamente, com futura **assinatura Developer ID, hardened runtime e notarização** sujeitas à verificação técnica. Não planejar Mac App Store no MVP. Mesmo fora do sandbox, usar seletores nativos, menor privilégio operacional possível, validações de arquivos e auditabilidade dos lançamentos. Revisitar restrições e alternativas seguras antes de uma distribuição pública.

## Consequências
Facilita PoC, mas exige cuidado de segurança, política de distribuição/atualização e validação de Gatekeeper. O app não deve pedir privilégios administrativos. Não executar shell arbitrário.

## Alternativas
Mac App Store sandboxed (não validada para o launcher); helper privilegiado (complexidade e superfície de risco não justificadas); protocol handlers específicos (apenas onde emulador os suportar).

## Referências
- https://developer.apple.com/documentation/appkit/nsworkspace/openconfiguration/arguments
- https://developer.apple.com/documentation/security/accessing-files-from-the-macos-app-sandbox

## Emenda (2026-10-27)
- Sem sandbox, ler pastas em Documentos, Mesa, Downloads ou volumes removíveis ainda gera prompt de privacidade (TCC) atribuído ao RetroX. O onboarding explica isso, e o estado `denied` de uma fonte orienta o usuário até os Ajustes do Sistema. O app nunca pede Acesso Total ao Disco.
- Nenhum entitlement de Apple Events: o RetroX não automatiza outros apps.
- Assinatura Developer ID e notarização dependem de uma conta Apple Developer do usuário e ficam fora do MVP técnico. Até lá, os builds locais usam assinatura ad hoc.
