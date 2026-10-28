#!/bin/bash
# Roda `swift test` repassando os argumentos recebidos.
#
# Nas Command Line Tools (Swift 6.4, backend swiftbuild), a descoberta do plugin de macros do
# Swift Testing é intermitente: às vezes o compilador não recebe o TestingMacros e o build falha
# com "plugin for module 'TestingMacros' not found". Passar o caminho do plugin explicitamente
# resolve. Com o Xcode ativo, nada é acrescentado.
set -euo pipefail
cd "$(dirname "$0")/.."

extra=()
developer_dir="$(xcode-select -p 2>/dev/null || true)"
plugin_dir="$developer_dir/usr/lib/swift/host/plugins/testing"
if [[ "$developer_dir" == *CommandLineTools* && -d "$plugin_dir" ]]; then
  extra=(-Xswiftc -plugin-path -Xswiftc "$plugin_dir")
fi

exec swift test "${extra[@]}" "$@"
