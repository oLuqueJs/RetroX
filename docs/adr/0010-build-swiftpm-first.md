# ADR-0010 — Build SwiftPM-first

**Status:** Aceito | **Data:** 2026-10-27

## Contexto
A máquina de desenvolvimento tem só as Command Line Tools (Swift 6.4, SDK macOS 27), sem Xcode. Nas CLT, SwiftUI, `@Observable` e Swift Testing compilam, mas a macro `@Model` do SwiftData não (o plugin `SwiftDataMacros` não existe nas CLT). Também não há `xcodebuild`, XCUITest nem Instruments. O usuário vai instalar o Xcode antes da Fase 2.

## Decisão
O código vive num pacote SwiftPM (`Package.swift`), que compila com `swift build` e testa com `swift test` tanto nas CLT quanto no Xcode (que abre o pacote diretamente).

- `RetroXCore`: regras de negócio, sem SwiftUI e sem SwiftData. Compila e testa só com as CLT.
- `RetroXApp`: executável SwiftUI. Para rodar como app de verdade (Dock, ativação, Info.plist), o script `scripts/bundle-app.sh` monta `RetroX.app` a partir do binário e assina ad hoc.
- `RetroXPersistence` (SwiftData) só entra no pacote quando o Xcode estiver instalado (Fase 2).
- Ferramentas de desenvolvimento (`rx-launch-probe`, `rx-fake-emulator`) são targets executáveis do mesmo pacote e não fazem parte do app distribuído.

Um projeto `.xcodeproj` (gerado por XcodeGen, com consentimento) só será criado se XCUITest, asset catalogs ou o fluxo de distribuição exigirem.

## Consequências
O núcleo é testável sem Xcode e o repositório não carrega um `.xcodeproj` difícil de revisar. Em troca, o bundle do app é montado por script, e recursos como asset catalog e String Catalog podem exigir passos extras até existir um projeto Xcode.

Peculiaridades das CLT encontradas na Sprint 1 (Swift 6.4, backend `swiftbuild`):
- A descoberta do plugin de macros do Swift Testing é intermitente (2 falhas em 3 builds limpos). Os testes rodam por `scripts/test.sh`, que passa `-plugin-path` explicitamente quando o toolchain ativo é o das CLT.
- O backend antigo (`--build-system native`) não encontra o módulo `Testing` nas CLT.
- No SDK do macOS 27, o `@State` do SwiftUI é uma macro (`SwiftUIMacros.StateMacro`), e as CLT não trazem o plugin `SwiftUIMacros` (no SDK 26.5 ainda era property wrapper). `@Observable` e `@Bindable` funcionam. Até o Xcode ser instalado, a UI evita `@State`: o estado de tela fica no view model `@Observable`. Isso reforça que as Fases 2 e 3 dependem do Xcode.

## Alternativas
`.xcodeproj` escrito à mão sem Xcode (frágil); Tuist ou XcodeGen desde já (ferramenta externa sem necessidade imediata); esperar o Xcode para começar (atrasa a prova técnica do launch, que não depende dele).
