#!/usr/bin/env bash
# ==============================================================================
# HALO COMBAT EVOLVED - AUTO MAP EXTRACTOR & IMPORTER
# Extrae y organiza legalmente los mapas (.map) desde un archivo ISO (Xbox / XISO)
# o desde una carpeta existente hacia la instalacion del servidor dedicado.
# ==============================================================================

set -euo pipefail

TARGET_DIR="${2:-/opt/halo-server/maps}"
SOURCE="${1:-}"

echo "=========================================================="
echo " HALO DEDICATED SERVER // AUTO MAP IMPORTER & EXTRACTOR"
echo "=========================================================="

if [ -z "$SOURCE" ]; then
    echo "Uso:"
    echo "  $0 <archivo.iso | carpeta_origen> [directorio_destino_maps]"
    echo ""
    echo "Ejemplos:"
    echo "  $0 'Halo - Combat Evolved.iso'"
    echo "  $0 /ruta/a/Halo_Custom_Edition/maps /opt/halo-server/maps"
    exit 1
fi

mkdir -p "$TARGET_DIR"

# Caso 1: Es un archivo ISO
if [ -f "$SOURCE" ] && [[ "$SOURCE" =~ \.(iso|xiso)$ ]]; then
    echo "[*] Detectada imagen ISO: $SOURCE"
    TMP_DIR=$(mktemp -d /tmp/halo_iso_ext_XXXXXX)
    trap 'rm -rf "$TMP_DIR"' EXIT

    EXTRACTED=0
    # Intentar con extract-xiso si esta disponible
    if command -v extract-xiso >/dev/null 2>&1; then
        echo "[*] Extrayendo con extract-xiso..."
        extract-xiso -x "$SOURCE" -d "$TMP_DIR" >/dev/null 2>&1 || true
        EXTRACTED=1
    fi

    # Fallback con 7z si no extrajo
    if [ "$EXTRACTED" -eq 0 ] && command -v 7z >/dev/null 2>&1; then
        echo "[*] Extrayendo con 7z..."
        7z x "$SOURCE" -o"$TMP_DIR" maps/ -y >/dev/null 2>&1 || 7z x "$SOURCE" -o"$TMP_DIR" -y >/dev/null 2>&1 || true
        EXTRACTED=1
    fi

    # Buscar todos los .map extraidos y moverlos
    MAP_COUNT=$(find "$TMP_DIR" -type f -iname "*.map" | wc -l)
    if [ "$MAP_COUNT" -gt 0 ]; then
        echo "[+] Se encontraron $MAP_COUNT mapas en la imagen ISO."
        find "$TMP_DIR" -type f -iname "*.map" -exec cp -v {} "$TARGET_DIR/" \;
        chmod 644 "$TARGET_DIR"/*.map
        echo "[+] Mapas importados exitosamente en: $TARGET_DIR"
    else
        echo "[-] ERROR: No se pudieron extraer archivos .map de la ISO."
        echo "    Asegurate de instalar '7z' (p7zip-full) o 'extract-xiso'."
        exit 1
    fi

# Caso 2: Es un directorio con mapas ya extraidos
elif [ -d "$SOURCE" ]; then
    echo "[*] Importando mapas desde directorio: $SOURCE"
    MAP_COUNT=$(find "$SOURCE" -type f -iname "*.map" | wc -l)
    if [ "$MAP_COUNT" -gt 0 ]; then
        find "$SOURCE" -type f -iname "*.map" -exec cp -v {} "$TARGET_DIR/" \;
        chmod 644 "$TARGET_DIR"/*.map
        echo "[+] $MAP_COUNT mapas copiados exitosamente a: $TARGET_DIR"
    else
        echo "[-] ERROR: No se encontraron archivos .map en $SOURCE"
        exit 1
    fi
else
    echo "[-] ERROR: El origen '$SOURCE' no es un archivo .iso ni una carpeta valida."
    exit 1
fi

echo "=========================================================="
echo " LISTADO DE MAPAS INSTALADOS EN EL SERVIDOR:"
ls -lh "$TARGET_DIR"/*.map 2>/dev/null || echo "Carpeta vacia."
echo "=========================================================="
