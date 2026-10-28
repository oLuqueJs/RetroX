#!/bin/bash
# Monta .build/RetroX.app a partir do executável do SwiftPM e assina ad hoc (ADR-0010).
# Uso: scripts/bundle-app.sh [debug|release]
set -euo pipefail
cd "$(dirname "$0")/.."

configuration="${1:-debug}"
case "$configuration" in
  debug|release) ;;
  *) echo "uso: $0 [debug|release]" >&2; exit 64 ;;
esac

swift build -c "$configuration" --product RetroX
bin_dir="$(swift build -c "$configuration" --show-bin-path)"

app=".build/RetroX.app"
rm -rf "$app"
mkdir -p "$app/Contents/MacOS"
cp "$bin_dir/RetroX" "$app/Contents/MacOS/RetroX"
cp Support/Info.plist "$app/Contents/Info.plist"
codesign --force --sign - "$app"

echo "$app"
