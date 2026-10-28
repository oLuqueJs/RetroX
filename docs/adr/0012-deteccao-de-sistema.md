# ADR-0012 — Detecção de sistema por fonte, cabeçalho e extensão

**Status:** Aceito (assinaturas a validar com fixtures na Fase 2) | **Data:** 2026-10-27

## Contexto
A mesma extensão serve a vários consoles: `.iso` pode ser PS2, GameCube ou Wii; `.rvz` pode ser GameCube ou Wii. O RF-02 proíbe presumir o console só pela extensão. Hash integral é caro e não é exigido (ADR-0008).

## Decisão
O `SystemDetector` decide o sistema de cada arquivo nesta ordem:

1. **Dica da fonte:** o usuário pode declarar o sistema de uma pasta-fonte. Se a extensão é suportada por esse sistema, ela vale.
2. **Cabeçalho:** leitura de no máximo 64 KB do início do arquivo, sem hash. Assinaturas candidatas, a confirmar com fixtures sintéticas na Fase 2:
   - ISO 9660 com `CD001` em `0x8001` e identificador de sistema `PLAYSTATION` → PS2 (o RetroX não suporta PS1 no MVP);
   - magic GameCube `0xC2339F3D` em `0x1C`;
   - magic Wii `0x5D1C9EA3` em `0x18`.
3. **Extensão inequívoca:** quando só um sistema do catálogo aceita a extensão.

Se nenhuma regra decide, o arquivo entra como `needsReview` e o usuário escolhe. O método usado fica registrado no jogo (`detectionMethod`), e a escolha manual sempre prevalece.

## Consequências
Menos falsos positivos e nenhum custo de hash. Formatos comprimidos (`chd`, `rvz`) dependem da dica da fonte ou de escolha manual até haver leitura específica do formato.

## Alternativas
Só extensão (atribui errado `.iso` de outros consoles); hash completo contra banco de dados (lento e exige base externa); perguntar sempre (onboarding cansativo).
