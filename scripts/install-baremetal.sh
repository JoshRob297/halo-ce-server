#!/usr/bin/env bash
# install-baremetal.sh: baja el server de la release y deja el servicio listo.
#
#   sudo ./scripts/install-baremetal.sh [/srv/halo] [URL del binario]
#
# El primer argumento es el directorio de instalacion (default /srv/halo).
# El segundo es la URL del binario de la release; por default la ultima
# release de este repositorio (server-linux-x86-portable.tar.gz -> halo).
#
# No trae mapas: copialos despues a <dir>/maps/ desde tu disco.
set -euo pipefail

DIR="${1:-/srv/halo}"
BIN_URL="${2:-https://github.com/JoshRob297/halo-ce-server/releases/latest/download/halo-linux-portable.tar.gz}"

if [ "$(id -u)" != "0" ]; then
    echo "correlo como root (usa sudo)" >&2
    exit 1
fi

command -v curl >/dev/null || { echo "falta curl" >&2; exit 1; }

echo "instalando en $DIR"

# el usuario del servicio, con home dentro del dir (partidas guardadas)
id -u halo >/dev/null 2>&1 || useradd --system --home-dir "$DIR/home" --create-home --shell /usr/sbin/nologin halo

mkdir -p "$DIR/maps" "$DIR/custom_maps"
cd "$DIR"

echo "bajando $BIN_URL"
curl -fsSL "$BIN_URL" -o halo.tar.gz
tar -xzf halo.tar.gz
rm halo.tar.gz
[ -x "$DIR/halo" ] || { echo "el tarball no trajo $DIR/halo" >&2; exit 1; }

# la config de ejemplo, si no hay una
if [ ! -f "$DIR/config.toml" ]; then
    cp /usr/share/halo-ce-server/config.toml "$DIR/config.toml" 2>/dev/null || true
fi

chown -R halo:halo "$DIR"

# la unidad de systemd (la copia embebida, o la del repo)
UNIT_SRC="$(dirname "$0")/../systemd/halo-server.service"
if [ -f "$UNIT_SRC" ]; then
    sed "s|/srv/halo|$DIR|g" "$UNIT_SRC" > /etc/systemd/system/halo-server.service
else
    sed "s|/srv/halo|$DIR|g" "$DIR/halo-server.service" > /etc/systemd/system/halo-server.service
fi

systemctl daemon-reload
systemctl enable --now halo-server

echo
echo "listo. Arrancalo con: systemctl restart halo-server"
echo "log:               journalctl -u halo-server -f"
echo "mapas:             $DIR/maps/"
echo "config:            $DIR/config.toml"
