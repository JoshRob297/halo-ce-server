#!/usr/bin/env bash
# ==============================================================================
# HALO COMBAT EVOLVED - AUTO MAP EXTRACTOR & IMPORTER (v2.3)
# Compatible con: x86_64, ARM64 (Raspberry Pi 3/4/5), ARMv7 (32-bit).
# Extrae mapas (.map) desde ISO (Xbox/XISO) o copia desde directorio existente.
# Auto-instala dependencias (7z, extract-xiso) segun arquitectura.
# Muestra errores detallados y ofrece alternativas si falla.
# ==============================================================================

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

# ==============================================================================
# Funcion: Auto-instalar dependencias de extraccion segun arquitectura
# ==============================================================================
install_extraction_deps() {
    echo "[*] Verificando dependencias de extraccion..."

    # Instalar 7z (p7zip-full) si no esta disponible
    if ! command -v 7z >/dev/null 2>&1; then
        echo "[*] 7z no encontrado. Intentando instalar p7zip-full..."
        if command -v apt-get >/dev/null 2>&1; then
            apt-get update -qq 2>/dev/null
            apt-get install -y -qq p7zip-full 2>/dev/null || true
        elif command -v dnf >/dev/null 2>&1; then
            dnf install -y -q p7zip p7zip-plugins 2>/dev/null || true
        elif command -v pacman >/dev/null 2>&1; then
            pacman -Sy --noconfirm --needed p7zip 2>/dev/null || true
        fi
    fi

    # Verificar si extract-xiso esta disponible; si no, compilar desde fuente
    if ! command -v extract-xiso >/dev/null 2>&1; then
        # Intentar compilar extract-xiso desde fuente (funciona en ARM64 y x86)
        if command -v gcc >/dev/null 2>&1 || command -v cc >/dev/null 2>&1; then
            echo "[*] extract-xiso no encontrado. Intentando compilar desde fuente..."
            TMP_BUILD=$(mktemp -d /tmp/extract_xiso_build_XXXXXX)
            if curl -fsSL "https://raw.githubusercontent.com/XboxDev/extract-xiso/master/extract-xiso.c" \
                -o "$TMP_BUILD/extract-xiso.c" 2>/dev/null; then
                if (cd "$TMP_BUILD" && (gcc -O2 -o extract-xiso extract-xiso.c 2>/dev/null || cc -O2 -o extract-xiso extract-xiso.c 2>/dev/null)); then
                    cp "$TMP_BUILD/extract-xiso" /usr/local/bin/extract-xiso
                    chmod +x /usr/local/bin/extract-xiso
                    echo "[+] extract-xiso compilado e instalado en /usr/local/bin/"
                else
                    echo "[-] No se pudo compilar extract-xiso (faltan librerias)."
                fi
            else
                echo "[-] No se pudo descargar el codigo fuente de extract-xiso."
            fi
            rm -rf "$TMP_BUILD"
        else
            echo "[!] No hay compilador (gcc/cc). extract-xiso no se puede compilar."
            echo "    Instala con: sudo apt install -y build-essential"
        fi
    fi

    # Verificar que al menos una herramienta este disponible
    if ! command -v 7z >/dev/null 2>&1 && ! command -v extract-xiso >/dev/null 2>&1; then
        echo ""
        echo "[-] ERROR CRITICO: No se encontro 7z ni extract-xiso."
        echo "    Instala manualmente con:"
        echo "      sudo apt update && sudo apt install -y p7zip-full"
        echo ""
        echo "    Si usas Raspberry Pi con Raspbian de 32 bits:"
        echo "      sudo apt install -y p7zip-full build-essential"
        echo "      sudo /opt/halo-server/scripts/import-maps.sh \"tu_iso.iso\""
        exit 1
    fi

    echo "    [+] Herramientas de extraccion verificadas:"
    command -v 7z >/dev/null 2>&1 && echo "        - 7z: $(which 7z)"
    command -v extract-xiso >/dev/null 2>&1 && echo "        - extract-xiso: $(which extract-xiso)"
}

# ==============================================================================
# Caso 1: Es un archivo ISO
# ==============================================================================
if [ -f "$SOURCE" ]; then
    echo "[*] Detectada imagen ISO: $SOURCE"

    # Verificar que el archivo sea un ISO valido
    FILE_TYPE=$(file -b "$SOURCE" 2>/dev/null || echo "unknown")
    echo "    Tipo de archivo: $FILE_TYPE"

    # Verificar tamano minimo (un ISO de Halo CE debe tener al menos 50 MB)
    FILE_SIZE=$(stat -c%s "$SOURCE" 2>/dev/null || stat -f%z "$SOURCE" 2>/dev/null || echo "0")
    if [ "$FILE_SIZE" -lt 1000000 ]; then
        echo "[-] ERROR: El archivo es demasiado pequeno ($FILE_SIZE bytes)."
        echo "    Asegurate de que sea un ISO completo de Halo CE."
        exit 1
    fi
    TMP_DIR=$(mktemp -d /tmp/halo_iso_ext_XXXXXX)
    trap 'rm -rf "$TMP_DIR"' EXIT

    install_extraction_deps

    # Copiar el ISO a un nombre temporal sin caracteres especiales
    SAFE_ISO="$TMP_DIR/halo_input.iso"
    cp "$SOURCE" "$SAFE_ISO"
    SOURCE="$SAFE_ISO"

    EXTRACTED=0
    # Intentar con extract-xiso primero (mejor para XISO)
    if command -v extract-xiso >/dev/null 2>&1; then
        echo "[*] Extrayendo con extract-xiso..."
        if extract-xiso -x "$SOURCE" -d "$TMP_DIR" 2>&1 | tail -5; then
            EXTRACTED=1
        fi
    fi

    # Fallback con 7z
    if [ "$EXTRACTED" -eq 0 ] && command -v 7z >/dev/null 2>&1; then
        echo "[*] Extrayendo con 7z (metodo alternativo)..."
        if 7z x "$SOURCE" -o"$TMP_DIR" maps/ -y 2>&1 | tail -5; then
            EXTRACTED=1
        elif 7z x "$SOURCE" -o"$TMP_DIR" -y 2>&1 | tail -5; then
            EXTRACTED=1
        fi
    fi

    # Verificar que se extrajeron mapas
    MAP_COUNT=$(find "$TMP_DIR" -type f -iname "*.map" | wc -l)
    if [ "$MAP_COUNT" -gt 0 ]; then
        echo ""
        echo "[+] Se encontraron $MAP_COUNT mapas en la imagen ISO."
        find "$TMP_DIR" -type f -iname "*.map" -exec cp -v {} "$TARGET_DIR/" \;
        chmod 644 "$TARGET_DIR"/*.map 2>/dev/null || true
        echo "[+] Mapas importados exitosamente en: $TARGET_DIR"
    else
        echo ""
        echo "[-] ERROR: No se pudieron extraer archivos .map de la ISO."
        echo ""
        echo "    DIAGNOSTICO:"
        echo "    - Tipo de archivo: $(file -b "$SOURCE" 2>/dev/null || echo "desconocido")"
        echo "    - Tamano: $(stat -c%s "$SOURCE" 2>/dev/null || stat -f%z "$SOURCE" 2>/dev/null || echo "0") bytes"
        echo "    - Herramientas: 7z=$(command -v 7z 2>/dev/null || echo "NO"), extract-xiso=$(command -v extract-xiso 2>/dev/null || echo "NO")"
        echo ""
        echo "    SOLUCIONES:"
        echo "    1. Verifica que la ISO sea un disco original de Halo CE (Xbox)."
        echo "    2. Si es de Internet Archive, descarga la version 'Rev 2' (NTSC)."
        echo "    3. Extrae los mapas manualmente en tu PC y copialos:"
        echo "       sudo cp /ruta/a/mapas/*.map $TARGET_DIR/"
        echo ""
        echo "    Posibles causas:"
        echo "    1. La ISO no es un disco original de Halo CE (Xbox)."
        echo "    2. La ISO es de Custom Edition (PC) y no tiene la carpeta maps/."
        echo "    3. El formato XISO requiere extract-xiso (no 7z)."
        echo ""
        echo "    Soluciones alternativas:"
        echo "    A) Descarga el ISO correcto de Internet Archive (Xbox Rev 2)."
        echo "    B) Extrae los mapas manualmente en tu PC y copialos:"
        echo "       sudo cp /ruta/a/mapas/*.map $TARGET_DIR/"
        echo "    C) Si tienes Custom Edition, copia los .map de su carpeta maps/"
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
        echo "    Asegurate de que la carpeta contenga archivos .map (no .bsp ni otros formatos)."
        exit 1
    fi
else
    echo "[-] ERROR: El origen '$SOURCE' no es un archivo ISO valido ni una carpeta."
    echo "    Asegurate de poner comillas alrededor del nombre si tiene espacios o parentasis:"
    echo "    sudo $0 \"Halo (Xbox).iso\""
    exit 1
fi

echo "=========================================================="
echo " LISTADO DE MAPAS INSTALADOS EN EL SERVIDOR:"
ls -lh "$TARGET_DIR"/*.map 2>/dev/null || echo "Carpeta vacia."
echo "=========================================================="
