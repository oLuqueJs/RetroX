#!/bin/bash
# Testes de integração do launch com um emulador falso (rx-fake-emulator), aberto de verdade
# pelo LaunchServices e por exec direto. Não toca em emuladores nem em ROMs reais.
set -euo pipefail
cd "$(dirname "$0")/.."

swift build --product rx-fake-emulator
bin_dir="$(swift build --show-bin-path)"
RX_FAKE_EMULATOR_BIN="$bin_dir/rx-fake-emulator" exec scripts/test.sh --filter LaunchIntegrationTests "$@"
