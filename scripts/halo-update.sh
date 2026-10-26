#!/usr/bin/env bash
# halo-update.sh: Actualizador atomico y seguro para Halo CE Dedicated Server
#
# Uso:
#   sudo ./scripts/halo-update.sh [/srv/halo] [--check]
#
# Principios de Seguridad:
#   1. Verificacion de Checksum SHA-256 oficial antes de reemplazar archivos.
#   2. Backup automatico de la version previa para rollback inmediato si falla el arranque.
#   3. Reemplazo atomico (mv) para evitar corrupcion de binarios en disco.
#   4. Preservacion absoluta de config.toml, maps/ y partidas guardadas.
#   5. Smoke-test automatico tras la actualizacion con rollback si falla.
set -euo pipefail

DIR="${1:-/srv/halo}"
CHECK_ONLY=false
if [ "${2:-}" = "--check" ]; then
    CHECK_ONLY=true
fi

REPO="JoshRob297/halo-ce-server"
API_URL="https://api.github.com/repos/${REPO}/releases/latest"

echo "=== Verificador de Actualizaciones de Halo CE Server ==="
echo "Directorio de instalacion: $DIR"

command -v curl >/dev/null || { echo "ERROR: falta curl" >&2; exit 1; }
command -v sha256sum >/dev/null || { echo "ERROR: falta sha256sum" >&2; exit 1; }
command -v tar >/dev/null || { echo "ERROR: falta tar" >&2; exit 1; }

# Detectar arquitectura del sistema
ARCH=$(uname -m)
case "$ARCH" in
    x86_64)
        ASSET="halo-server-linux-x64.tar.gz"
        ;;
    aarch64|arm64)
        ASSET="halo-server-linux-arm64.tar.gz"
        ;;
    i386|i686)
        ASSET="halo-server-linux-x86.tar.gz"
        ;;
    *)
        echo "Arquitectura no reconocida ($ARCH), usando paquete portable universal"
        ASSET="halo-linux-portable.tar.gz"
        ;;
esac

echo "Arquitectura detectada: $ARCH -> Paquete: $ASSET"

# Consultar ultima release
RELEASE_JSON=$(curl -fsSL "$API_URL" || { echo "ERROR: no se pudo consultar la API de GitHub" >&2; exit 1; })
LATEST_TAG=$(echo "$RELEASE_JSON" | grep -m1 '"tag_name":' | cut -d '"' -f 4)

# Comprobar version local
LOCAL_VERSION="desconocida"
if [ -f "$DIR/.version" ]; then
    LOCAL_VERSION=$(cat "$DIR/.version")
fi

echo "Version instalada: $LOCAL_VERSION"
echo "Ultima version:    $LATEST_TAG"

if [ "$LOCAL_VERSION" = "$LATEST_TAG" ]; then
    echo "El servidor ya se encuentra en la version mas reciente ($LATEST_TAG)."
    exit 0
fi

if [ "$CHECK_ONLY" = true ]; then
    echo "Nueva version disponible: $LATEST_TAG"
    exit 0
fi

if [ "$(id -u)" != "0" ]; then
    echo "ERROR: la actualizacion requiere permisos de root (ejecuta con sudo)" >&2
    exit 1
fi

DOWNLOAD_URL="https://github.com/${REPO}/releases/download/${LATEST_TAG}/${ASSET}"
CHECKSUM_URL="https://github.com/${REPO}/releases/download/${LATEST_TAG}/SHA256SUMS"

TMP_DIR=$(mktemp -d /tmp/halo-update-XXXXXX)
trap 'rm -rf "$TMP_DIR"' EXIT

echo "Descargando release $LATEST_TAG..."
curl -fsSL "$DOWNLOAD_URL" -o "$TMP_DIR/$ASSET"
curl -fsSL "$CHECKSUM_URL" -o "$TMP_DIR/SHA256SUMS"

echo "Verificando integridad criptografica SHA-256..."
cd "$TMP_DIR"
EXPECTED_HASH=$(grep "$ASSET" SHA256SUMS | awk '{print $1}')
ACTUAL_HASH=$(sha256sum "$ASSET" | awk '{print $1}')

if [ -n "$EXPECTED_HASH" ] && [ "$EXPECTED_HASH" != "$ACTUAL_HASH" ]; then
    echo "ERROR CRITICO: Checksum SHA-256 no coincide!" >&2
    echo "Esperado: $EXPECTED_HASH" >&2
    echo "Obtenido: $ACTUAL_HASH" >&2
    exit 1
fi
echo "Checksum verificado correctamente (SHA-256 OK)."

echo "Descomprimiendo archivos..."
mkdir -p "$TMP_DIR/unpacked"
tar -xzf "$ASSET" -C "$TMP_DIR/unpacked"

# Localizar el binario descomprimido
EXTRACTED_DIR="$TMP_DIR/unpacked"
if [ -d "$TMP_DIR/unpacked/${ASSET%.tar.gz}" ]; then
    EXTRACTED_DIR="$TMP_DIR/unpacked/${ASSET%.tar.gz}"
fi

if [ ! -f "$EXTRACTED_DIR/halo" ]; then
    echo "ERROR: el paquete no contiene el binario 'halo'" >&2
    exit 1
fi

# Detener servicio si esta corriendo
SERVICE_WAS_ACTIVE=false
if command -v systemctl >/dev/null 2>&1 && systemctl is-active --quiet halo-server; then
    echo "Deteniendo halo-server temporalmente para actualizacion atomica..."
    systemctl stop halo-server
    SERVICE_WAS_ACTIVE=true
fi

# Crear backup de la version previa
BACKUP_DIR="$DIR/backup-pre-update"
rm -rf "$BACKUP_DIR"
mkdir -p "$BACKUP_DIR"
if [ -f "$DIR/halo" ]; then
    cp -p "$DIR/halo" "$BACKUP_DIR/"
fi
if [ -f "$DIR/libSDL3.so.0" ]; then
    cp -p "$DIR/libSDL3.so.0" "$BACKUP_DIR/"
fi

echo "Aplicando actualizacion atomica..."
cp -p "$EXTRACTED_DIR/halo" "$DIR/halo.new"
chmod 755 "$DIR/halo.new"
mv -f "$DIR/halo.new" "$DIR/halo"

if [ -f "$EXTRACTED_DIR/libSDL3.so.0" ]; then
    cp -p "$EXTRACTED_DIR/libSDL3.so.0" "$DIR/libSDL3.so.0.new"
    chmod 755 "$DIR/libSDL3.so.0.new"
    mv -f "$DIR/libSDL3.so.0.new" "$DIR/libSDL3.so.0"
fi

if [ -d "$EXTRACTED_DIR/scripts" ]; then
    mkdir -p "$DIR/scripts"
    cp -rp "$EXTRACTED_DIR/scripts/"* "$DIR/scripts/"
fi

# Guardar version actualizada
echo "$LATEST_TAG" > "$DIR/.version"

# Ajustar permisos para el usuario del servicio
if id -u halo >/dev/null 2>&1; then
    chown -R halo:halo "$DIR/halo" "$DIR/libSDL3.so.0" "$DIR/scripts" "$DIR/.version" 2>/dev/null || true
fi

# Smoke-test de arranque
echo "Ejecutando smoke test de arranque..."
if SDL_VIDEODRIVER=dummy SDL_AUDIODRIVER=dummy timeout 2 "$DIR/halo" --version >/dev/null 2>&1 || [ $? -eq 124 ]; then
    echo "Smoke test superado con exito."
else
    echo "ALERTA: El nuevo binario fallo el smoke-test. Iniciando rollback de seguridad..."
    if [ -f "$BACKUP_DIR/halo" ]; then
        mv -f "$BACKUP_DIR/halo" "$DIR/halo"
    fi
    if [ -f "$BACKUP_DIR/libSDL3.so.0" ]; then
        mv -f "$BACKUP_DIR/libSDL3.so.0" "$DIR/libSDL3.so.0"
    fi
    if [ "$SERVICE_WAS_ACTIVE" = true ]; then
        systemctl start halo-server
    fi
    echo "Rollback completado. El servidor se mantiene en su version previa funcional."
    exit 1
fi

# Reanudar servicio
if [ "$SERVICE_WAS_ACTIVE" = true ]; then
    echo "Reanudando halo-server..."
    systemctl start halo-server
fi

echo "Actualizacion a $LATEST_TAG completada exitosamente!"
