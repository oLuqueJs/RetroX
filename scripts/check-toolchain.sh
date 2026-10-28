#!/bin/bash
# Mostra o que o toolchain atual consegue fazer pelo RetroX. Só lê; não altera nada.
set -uo pipefail

ok()   { printf '  [ok]    %s\n' "$1"; }
warn() { printf '  [falta] %s\n' "$1"; }

echo "Sistema: macOS $(sw_vers -productVersion) ($(uname -m))"
echo "Toolchain: $(xcode-select -p 2>/dev/null || echo 'nenhum')"
echo "Swift: $(swift --version 2>/dev/null | head -1)"
echo

if xcodebuild -version >/dev/null 2>&1; then
  ok "Xcode: $(xcodebuild -version | head -1)"
else
  warn "Xcode: só Command Line Tools. Sem xcodebuild, XCUITest e Instruments."
fi

if printf 'import SwiftData\n@Model final class Probe { var x = 0; init() {} }\n' \
    | swiftc -typecheck -target "$(uname -m)-apple-macos14" - >/dev/null 2>&1; then
  ok "SwiftData (@Model): compila. A Fase 2 pode começar."
else
  warn "SwiftData (@Model): não compila neste toolchain (instale o Xcode)."
fi

if [ -e /Library/Apple/usr/libexec/oah/libRosettaRuntime ]; then
  ok "Rosetta: instalado (necessário para emuladores só x86_64, como o PCSX2 2.9)."
else
  warn "Rosetta: não instalado. Emuladores só x86_64 não abrem em Apple Silicon."
fi
