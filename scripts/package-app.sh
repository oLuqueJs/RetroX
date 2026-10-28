#!/bin/bash
# Cria um ZIP do app, assinado ad hoc, para a arquitetura do host.
set -euo pipefail
cd "$(dirname "$0")/.."

version="${1:?uso: scripts/package-app.sh VERSION}"
if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+([+-][0-9A-Za-z.-]+)?$ ]]; then
  echo "versão inválida: $version" >&2
  exit 64
fi

scripts/bundle-app.sh release
app=".build/RetroX.app"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString ${version%%[-+]*}" "$app/Contents/Info.plist"
codesign --force --sign - "$app"
codesign --verify --deep --strict "$app"

mkdir -p dist
archive="RetroX-${version}-macos-$(uname -m).zip"
rm -f "dist/$archive"
ditto -c -k --sequesterRsrc --keepParent "$app" "dist/$archive"
(cd dist && shasum -a 256 "$archive" > SHA256SUMS.txt)
printf 'Pacote: dist/%s\n' "$archive"
