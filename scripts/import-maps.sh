#!/usr/bin/env bash
# HALO COMBAT EVOLVED - AUTO MAP EXTRACTOR & IMPORTER (v2.1)
# Soporta nombres con espacios, parentesis y caracteres especiales.
set -euo pipefail

TARGET_DIR="${2:-/opt/halo-server/maps}"
SOURCE="${1:-}"

echo "=========================================================="
echo " HALO DEDICATED SERVER // AUTO MAP IMPORTER & EXTRACTOR"
echo "=========================================================="

if [ -z "$SOURCE" ]; then
    echo "Uso:"
    echo "  $0 \"nombre_del_archivo.iso\" [directorio_destino]"
    echo ""
    echo "Ejemplos:"
    echo "  $0 \"Halo (Xbox).iso\""
    echo "  $0 \"/home/pi/Descargas/Halo - Combat Evolved (USA).iso\""
    echo "  $0 /ruta/a/mapas/ /opt/halo-server/maps"
    exit 1
fi

mkdir -p "$TARGET_DIR"

# Caso 1: Es un archivo ISO
if [ -f "$SOURCE" ]; then
    echo "[*] Detectada imagen ISO: $SOURCE"
    TMP_DIR=$(mktemp -d /tmp/halo_iso_ext_XXXXXX)
    trap 'rm -rf "$TMP_DIR"' EXIT

    # Copiar el ISO a un nombre temporal sin caracteres especiales
    # para evitar que extract-xiso o 7z fallen con parentesis
    SAFE_ISO="$TMP_DIR/halo_input.iso"
    cp "$SOURCE" "$SAFE_ISO"
    SOURCE="$SAFE_ISO"

    EXTRACTED=0
    # Intentar con extract-xiso
    if command -v extract-xiso >/dev/null 2>&1; then
        echo "[*] Extrayendo con extract-xiso..."
        extract-xiso -x "$SOURCE" -d "$TMP_DIR" >/dev/null 2>&1 || true
        EXTRACTED=1
    fi

    # Fallback con 7z
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
        chmod 644 "$TARGET_DIR"/*.map 2>/dev/null || true
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
        chmod 644 "$TARGET_DIR"/*.map 2>/dev/null || true
        echo "[+] $MAP_COUNT mapas copiados exitosamente a: $TARGET_DIR"
    else
        echo "[-] ERROR: No se encontraron archivos .map en $SOURCE"
        exit 1
    fi
else
    echo "[-] ERROR: El origen '$SOURCE' no es un archivo ISO valido ni una carpeta."
    echo "    Asegurate de poner comillas alrededor del nombre si tiene espacios o parentesis:"
    echo "    sudo $0 \"Halo (Xbox).iso\""
    exit 1
fi

echo "=========================================================="
echo " LISTADO DE MAPAS INSTALADOS EN EL SERVIDOR:"
ls -lh "$TARGET_DIR"/*.map 2>/dev/null || echo "Carpeta vacia."
echo "=========================================================="
