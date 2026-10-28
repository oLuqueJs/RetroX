#!/bin/bash
# Inspeciona uma instalação fornecida explicitamente, sem executar o emulador.
set -euo pipefail
cd "$(dirname "$0")/.."
if [[ $# -ne 2 || ! -d "$2" ]]; then
  echo "uso: $0 pcsx2|azahar|ryujinx /caminho/Emulador.app" >&2
  exit 64
fi
case "$1" in
  pcsx2) export RX_PCSX2_APP="$2" ;;
  azahar) export RX_AZAHAR_APP="$2" ;;
  ryujinx) export RX_RYUJINX_APP="$2" ;;
  *) echo "Emulador desconhecido: $1" >&2; exit 64 ;;
esac
exec scripts/test.sh --filter InstalledEmulatorTests
