#!/bin/bash
# Verifica o artefato distribuído, após extrair o ZIP tal como quem o baixa.
set -euo pipefail
cd "$(dirname "$0")/.."

version="${1:?uso: scripts/verify-package.sh VERSION}"
require_file() {
  if [[ ! -s "$1" ]]; then echo "Arquivo ausente ou vazio no pacote: $1" >&2; exit 1; fi
}
arch="$(uname -m)"
archive="dist/RetroX-${version}-macos-${arch}.zip"
require_file "$archive"
(cd dist && shasum -a 256 -c SHA256SUMS.txt)

temp_dir="$(mktemp -d "${TMPDIR:-/tmp}/retrox-package-test.XXXXXX")"
trap 'rm -rf "$temp_dir"' EXIT
ditto -x -k "$archive" "$temp_dir"
app="$temp_dir/RetroX.app"
require_file "$app/Contents/MacOS/RetroX"
if [[ ! -x "$app/Contents/MacOS/RetroX" ]]; then echo "RetroX sem permissão de execução" >&2; exit 1; fi
require_file "$app/Contents/Resources/RetroX.icns"
resources="$app/Contents/Resources/RetroX_RetroXApp.bundle"
# SwiftPM usa bundle plano com o backend clássico e Contents/Resources com swiftbuild.
if [[ -d "$resources/Contents/Resources" ]]; then resources="$resources/Contents/Resources"; fi
require_file "$resources/Resources/RayoMark.png"
test "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$app/Contents/Info.plist")" = "${version%%[-+]*}"
test "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$app/Contents/Info.plist")" = RetroX
lipo "$app/Contents/MacOS/RetroX" -verify_arch "$arch"
codesign --verify --deep --strict "$app"
printf 'Pacote validado: %s\n' "$archive"
