#!/usr/bin/env bash
# ==============================================================================
# update-extractor.sh: Actualiza el extractor de mapas a la ultima version
# desde GitHub sin reinstalar el servidor completo.
# ==============================================================================
set -euo pipefail

SCRIPT_URL="https://raw.githubusercontent.com/JoshRob297/halo-ce-server/main/scripts/import-maps.sh"
TARGET="/opt/halo-server/scripts/import-maps.sh"

echo "=========================================================="
echo " ACTUALIZADOR DE EXTRACTOR DE MAPAS - HALO CE SERVER"
echo "=========================================================="

if [ "$(id -u)" != "0" ]; then
    echo "ERROR: Ejecuta con sudo:" >&2
    echo "  curl -fsSL https://raw.githubusercontent.com/JoshRob297/halo-ce-server/main/scripts/update-extractor.sh | sudo bash" >&2
    exit 1
fi

mkdir -p /opt/halo-server/scripts

echo "[*] Descargando ultima version del extractor..."
curl -fsSL "$SCRIPT_URL" -o "$TARGET"
chmod +x "$TARGET"
chown halo:halo "$TARGET"

echo "[+] Extractor actualizado en: $TARGET"
echo "[+] Version: $(head -n 2 $TARGET | tail -n 1)"

echo ""
echo "Uso:"
echo "  sudo $TARGET \"Halo (Xbox).iso\""
echo "  sudo $TARGET /ruta/a/mapas/"
echo "=========================================================="
