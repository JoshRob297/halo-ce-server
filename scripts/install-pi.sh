#!/usr/bin/env bash
# install-pi.sh: nombre historico del instalador de Raspberry Pi.
#
# Hay un solo instalador: install-server.sh detecta la placa (x86_64, i386,
# aarch64, ARMv7), elige el paquete correcto y configura el servicio. Este
# archivo existe para que los enlaces y comandos antiguos sigan funcionando.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd || true)"

if [ -n "$HERE" ] && [ -f "$HERE/install-server.sh" ]; then
    exec bash "$HERE/install-server.sh" "$@"
fi

TMP="$(mktemp /tmp/halo-install-server.XXXXXX.sh)"
trap 'rm -f "$TMP"' EXIT
curl -fsSL --retry 3 --connect-timeout 15 \
    "https://raw.githubusercontent.com/JoshRob297/halo-ce-server/main/scripts/install-server.sh" \
    -o "$TMP"
exec bash "$TMP" "$@"
