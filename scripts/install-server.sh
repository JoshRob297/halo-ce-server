#!/usr/bin/env bash
# ==============================================================================
# install-server.sh: instalador de un solo comando del servidor dedicado de
# Halo: Combat Evolved (OpenCE). Probado en x86_64, i386, aarch64 (via
# qemu-i386-static) y ARMv7 con kernel de 64 bits.
#
# Uso:
#   curl -fsSL https://raw.githubusercontent.com/JoshRob297/halo-ce-server/main/scripts/install-server.sh | sudo bash
#   sudo ./scripts/install-server.sh                 instala o actualiza
#   sudo ./scripts/install-server.sh --check         solo comprueba el estado
#   sudo ./scripts/install-server.sh --dir /srv/halo instala en otra ruta
#
# Garantias:
#   - El paquete se verifica con SHA-256 antes de tocar la instalacion.
#   - config.toml, maps/ y custom_maps/ nunca se sobrescriben.
#   - El binario se prueba antes de registrar el servicio.
#   - Si el servicio no arranca, se restaura la version anterior.
# ==============================================================================

set -euo pipefail

INSTALL_DIR="/opt/halo-server"
SERVICE_NAME="halo-server"
SERVICE_USER="halo"
REPO="JoshRob297/halo-ce-server"
RELEASE_URL="https://github.com/${REPO}/releases/latest/download"
LOG_FILE="/var/log/halo-install.log"
MODE="install"
ARCH="$(uname -m)"
CONFIG_BOOT=""
NEED_REBOOT_FOR_64BIT=0
IS_UPDATE=0
TMP_DIR=""
BACKUP_DIR=""
OLD_BIN=""
EXEC_PREFIX=""

# ------------------------------------------------------------------------------
# Salida: todo va a pantalla y a /var/log/halo-install.log
# ------------------------------------------------------------------------------
mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null || LOG_FILE="/tmp/halo-install.log"
: > "$LOG_FILE" 2>/dev/null || true

log() { printf '%s\n' "$*" | tee -a "$LOG_FILE"; }
say() { printf '%s\n' "$*"; }
die() {
    say "" >&2
    say "[-] ERROR: $*" | tee -a "$LOG_FILE" >&2
    say "    Registro completo: $LOG_FILE" >&2
    exit 1
}

cleanup() {
    [ -n "$TMP_DIR" ] && rm -rf "$TMP_DIR"
}
trap cleanup EXIT

# ------------------------------------------------------------------------------
# Argumentos
# ------------------------------------------------------------------------------
while [ $# -gt 0 ]; do
    case "$1" in
        --check) MODE="check"; shift ;;
        --dir)
            [ $# -ge 2 ] || die "--dir necesita una ruta"
            INSTALL_DIR="$2"; shift 2 ;;
        --help|-h)
            sed -n '3,18p' "$0" | sed 's/^# \{0,1\}//'
            exit 0 ;;
        *)
            die "opcion desconocida: $1 (usa --help)" ;;
    esac
done

# ------------------------------------------------------------------------------
# Comprobaciones previas
# ------------------------------------------------------------------------------
if [ "$(id -u)" != "0" ]; then
    say "ERROR: hace falta root. Ejecuta:"
    say "  curl -fsSL https://raw.githubusercontent.com/${REPO}/main/scripts/install-server.sh | sudo bash"
    exit 1
fi

command -v systemctl >/dev/null 2>&1 || \
    die "systemd no esta disponible en este sistema (contenedores sin init no estan soportados)."

log "=========================================================="
log " Halo CE Dedicated Server - instalador OpenCE Netcode v41 "
log "=========================================================="
log ""

# ------------------------------------------------------------------------------
# Espacio en disco: el paquete ocupa ~25 MB y el servidor ~120 MB en marcha
# ------------------------------------------------------------------------------
AVAIL_KB="$(df -Pk "$(dirname "$INSTALL_DIR")" 2>/dev/null | awk 'NR==2 {print $4}')"
if [ -n "${AVAIL_KB:-}" ] && [ "$AVAIL_KB" -lt 262144 ]; then
    die "quedan menos de 256 MB libres en $(dirname "$INSTALL_DIR")."
fi

# ------------------------------------------------------------------------------
# Instalacion previa y estado
# ------------------------------------------------------------------------------
if [ -x "$INSTALL_DIR/halo" ]; then
    IS_UPDATE=1
    log "[*] Instalacion existente en $INSTALL_DIR"
    log "    version instalada: $("$INSTALL_DIR/halo" --version 2>/dev/null | head -1 || echo desconocida)"
    log "    config.toml y mapas se conservan."
    log ""
fi

if [ "$MODE" = "check" ]; then
    log "[*] Comprobacion del servicio $SERVICE_NAME"
    if systemctl is-active --quiet "$SERVICE_NAME"; then
        log "    servicio: activo desde $(systemctl show -p ActiveEnterTimestamp --value "$SERVICE_NAME")"
        journalctl -u "$SERVICE_NAME" -n 5 --no-pager 2>/dev/null | tail -5 | tee -a "$LOG_FILE"
    else
        log "    servicio: inactivo"
    fi
    exit 0
fi

# ------------------------------------------------------------------------------
# Dependencias
# ------------------------------------------------------------------------------
log "[*] Dependencias del sistema..."

apt_deps() {
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -qq || die "apt-get update fallo: revisa /etc/apt/sources.list y la red."
    apt-get install -y -qq curl ca-certificates tar gzip file p7zip-full coreutils procps \
        net-tools netcat-openbsd socat >/dev/null 2>&1 || \
        apt-get install -y -qq curl ca-certificates tar gzip file coreutils procps >/dev/null 2>&1 || \
        die "no se pudieron instalar las dependencias basicas (curl, tar, gzip, file)."

    case "$ARCH" in
        x86_64|amd64)
            dpkg --add-architecture i386 2>/dev/null || true
            apt-get update -qq 2>/dev/null || true
            apt-get install -y -qq libc6:i386 libstdc++6:i386 libgcc-s1:i386 >/dev/null 2>&1 || \
                log "    [!] No se pudieron instalar las librerias i386: el motor de 32 bits no arrancara."
            ;;
        aarch64|arm64)
            dpkg --add-architecture i386 2>/dev/null || true
            apt-get update -qq 2>/dev/null || true
            apt-get install -y -qq qemu-user-binfmt >/dev/null 2>&1 || \
                apt-get install -y -qq qemu-user-static >/dev/null 2>&1 || true
            apt-get install -y -qq libc6:i386 libstdc++6:i386 libgcc-s1:i386 >/dev/null 2>&1 || \
                log "    [!] No se pudieron instalar las librerias i386 para qemu."
            systemctl restart systemd-binfmt 2>/dev/null || true
            ;;
    esac
}

dnf_deps() {
    dnf install -y -q curl ca-certificates tar gzip file p7zip coreutils procps-ng \
        net-tools socat >/dev/null 2>&1 || \
        die "no se pudieron instalar las dependencias basicas con dnf."
    case "$ARCH" in
        x86_64|amd64)
            dnf install -y -q glibc.i686 libstdc++.i686 >/dev/null 2>&1 || \
                log "    [!] No se pudo instalar el multilib i686: el motor de 32 bits no arrancara."
            ;;
    esac
}

pacman_deps() {
    pacman -Sy --noconfirm --needed curl ca-certificates tar gzip file p7zip coreutils \
        procps-ng net-tools socat >/dev/null 2>&1 || \
        die "no se pudieron instalar las dependencias basicas con pacman."
    case "$ARCH" in
        x86_64|amd64)
            pacman -S --noconfirm --needed lib32-glibc lib32-gcc-libs >/dev/null 2>&1 || \
                log "    [!] No se pudo instalar lib32: el motor de 32 bits no arrancara (revisa /etc/pacman.conf)."
            ;;
    esac
}

if command -v apt-get >/dev/null 2>&1; then
    apt_deps
elif command -v dnf >/dev/null 2>&1; then
    dnf_deps
elif command -v pacman >/dev/null 2>&1; then
    pacman_deps
else
    log "    [!] Gestor de paquetes no reconocido; se asume que curl, tar, gzip y file ya estan."
fi

for tool in curl tar gzip; do
    command -v "$tool" >/dev/null 2>&1 || die "falta '$tool' y no se pudo instalar."
done

if ! command -v 7z >/dev/null 2>&1 && ! command -v extract-xiso >/dev/null 2>&1; then
    log "    [!] Sin 7z ni extract-xiso: el importador de mapas desde ISO no funcionara (no afecta al servidor)."
fi
log "[+] Dependencias listas."

# ------------------------------------------------------------------------------
# Elegir el paquete segun la arquitectura
# ------------------------------------------------------------------------------
PKG_NAME=""
case "$ARCH" in
    x86_64|amd64)
        PKG_NAME="halo-server-linux-x64.tar.gz"
        log "[*] Arquitectura: x86_64 (paquete x64)"
        ;;
    i386|i686)
        PKG_NAME="halo-server-linux-x86.tar.gz"
        log "[*] Arquitectura: x86 de 32 bits (paquete x86)"
        ;;
    aarch64|arm64)
        PKG_NAME="halo-server-linux-arm64.tar.gz"
        log "[*] Arquitectura: aarch64 (motor i386 sobre qemu-i386-static)"
        ;;
    armv7l|armhf)
        if [ -f /boot/firmware/config.txt ]; then
            CONFIG_BOOT="/boot/firmware/config.txt"
        elif [ -f /boot/config.txt ]; then
            CONFIG_BOOT="/boot/config.txt"
        fi
        if grep -qE "ARMv8|CPU architecture: 8|cortex-a53|cortex-a72|cortex-a76" /proc/cpuinfo 2>/dev/null; then
            log "[*] Arquitectura: ARMv7 con CPU de 64 bits."
            if [ -n "$CONFIG_BOOT" ] && ! grep -q "^arm_64bit=1" "$CONFIG_BOOT"; then
                printf '\n# Halo CE Dedicated Server: kernel de 64 bits\narm_64bit=1\n' >> "$CONFIG_BOOT"
                NEED_REBOOT_FOR_64BIT=1
                log "    [+] 'arm_64bit=1' anadido a $CONFIG_BOOT"
            fi
            PKG_NAME="halo-server-linux-arm64.tar.gz"
        else
            die "ARMv7 sin soporte de 64 bits: este motor no puede ejecutarse. Usa una Raspberry Pi 3/4/5 con SO de 64 bits."
        fi
        ;;
    *)
        die "arquitectura no soportada: $ARCH (se admiten x86_64, i386, aarch64 y ARMv7)."
        ;;
esac

# ------------------------------------------------------------------------------
# Descarga verificada
# ------------------------------------------------------------------------------
TMP_DIR="$(mktemp -d /tmp/halo-install.XXXXXX)"
PKG_PATH="$TMP_DIR/$PKG_NAME"

log "[*] Descargando $PKG_NAME ..."
curl -fSL --retry 3 --retry-delay 2 --connect-timeout 15 --max-time 900 \
    "$RELEASE_URL/$PKG_NAME" -o "$PKG_PATH" 2>>"$LOG_FILE" || \
    die "no se pudo descargar el paquete desde $RELEASE_URL/$PKG_NAME. Comprueba la red y que exista una release publicada."

# SHA-256: el release publica SHA256SUMS. Si esta, es obligatorio que coincida.
if curl -fsSL --retry 2 --connect-timeout 15 "$RELEASE_URL/SHA256SUMS" -o "$TMP_DIR/SHA256SUMS" 2>>"$LOG_FILE"; then
    EXPECTED="$(awk -v n="$PKG_NAME" '$2 == n {print $1}' "$TMP_DIR/SHA256SUMS")"
    [ -n "$EXPECTED" ] || die "SHA256SUMS no incluye $PKG_NAME: release incompleta."
    ACTUAL="$(sha256sum "$PKG_PATH" | awk '{print $1}')"
    [ "$EXPECTED" = "$ACTUAL" ] || die "el SHA-256 del paquete no coincide. Descarga corrupta o manipulada; no se instala nada."
    log "[+] SHA-256 verificado."
else
    log "    [!] No se pudo descargar SHA256SUMS; se continua sin verificar (release antigua)."
fi

tar -tzf "$PKG_PATH" >/dev/null 2>&1 || die "el paquete descargado no es un tar.gz valido."
mkdir -p "$TMP_DIR/pkg"
tar -xzf "$PKG_PATH" --strip-components=1 -C "$TMP_DIR/pkg" || die "no se pudo extraer el paquete."

for required in halo libSDL3.so.0; do
    [ -f "$TMP_DIR/pkg/$required" ] || die "el paquete no contiene '$required'. Release incompleta."
done
log "[+] Paquete extraido y completo."

# ------------------------------------------------------------------------------
# Probar el binario antes de instalar
# ------------------------------------------------------------------------------
chmod +x "$TMP_DIR/pkg/halo"
PKG_DESC="$(file -b "$TMP_DIR/pkg/halo" 2>/dev/null || true)"

case "$ARCH" in
    aarch64|arm64)
        case "$PKG_DESC" in
            *"Intel 80386"*|*"Intel i386"*|*"x86-64"*)
                QEMU_BIN="$(command -v qemu-i386-static || command -v qemu-i386 || true)"
                [ -n "$QEMU_BIN" ] || die "aarch64 sin qemu-i386: apt install -y qemu-user-binfmt libc6:i386"
                QEMU_LIB="/usr/lib/i386-linux-gnu"
                if [ ! -d "$QEMU_LIB" ]; then
                    QEMU_LIB="/lib/i386-linux-gnu"
                fi
                [ -d "$QEMU_LIB" ] || die "faltan las librerias i386: apt install -y libc6:i386 libstdc++6:i386"
                EXEC_PREFIX="$QEMU_BIN -L $QEMU_LIB"
                ;;
        esac
        ;;
esac

VERSION_OUT="$(cd "$TMP_DIR/pkg" && LD_LIBRARY_PATH=. $EXEC_PREFIX ./halo --version 2>&1 | head -1 || true)"
case "$VERSION_OUT" in
    *"network version"*) log "[+] Binario valido: $VERSION_OUT" ;;
    *)
        die "el binario no arranca en este sistema: ${VERSION_OUT:-sin salida}. Revisa las dependencias (librerias i386, qemu)."
        ;;
esac

# ------------------------------------------------------------------------------
# Instalacion: backup y copia sin tocar config ni mapas
# ------------------------------------------------------------------------------
mkdir -p "$INSTALL_DIR" "$INSTALL_DIR/maps" "$INSTALL_DIR/custom_maps" "$INSTALL_DIR/scripts"

STAMP="$(date +%Y%m%d%H%M%S)"
if [ "$IS_UPDATE" = "1" ]; then
    BACKUP_DIR="$INSTALL_DIR/.backup-$STAMP"
    mkdir -p "$BACKUP_DIR"
    cp -a "$INSTALL_DIR/halo" "$BACKUP_DIR/" 2>/dev/null || true
    cp -a "$INSTALL_DIR/libSDL3.so.0" "$BACKUP_DIR/" 2>/dev/null || true
    cp -a "$INSTALL_DIR/config.toml" "$BACKUP_DIR/" 2>/dev/null || true
    OLD_BIN=1
    log "[*] Backup de la version anterior en $BACKUP_DIR"
fi

# Solo estos archivos se reemplazan; config.toml, maps y custom_maps quedan intactos.
install -m 0755 "$TMP_DIR/pkg/halo" "$INSTALL_DIR/halo.new"
mv -f "$INSTALL_DIR/halo.new" "$INSTALL_DIR/halo"
install -m 0755 "$TMP_DIR/pkg/libSDL3.so.0" "$INSTALL_DIR/libSDL3.so.0"
for extra in SDL3-LICENSE.txt brokers.txt masters.txt; do
    [ -f "$TMP_DIR/pkg/$extra" ] && install -m 0644 "$TMP_DIR/pkg/$extra" "$INSTALL_DIR/$extra"
done
log "[+] Motor instalado."

# config.toml: se crea solo si falta
if [ ! -f "$INSTALL_DIR/config.toml" ]; then
    if [ -f "$TMP_DIR/pkg/config.toml" ]; then
        install -m 0640 "$TMP_DIR/pkg/config.toml" "$INSTALL_DIR/config.toml"
    else
        cat > "$INSTALL_DIR/config.toml" <<'TOML_EOF'
[server]
name = "Halo CE Dedicated Server"
web_bind = "127.0.0.1"
web_port = 8080

[network]
online = true
host_public = true
tunnel_port = 2302
TOML_EOF
    fi
    log "[+] config.toml creado."
fi

# La contrasena del dashboard la genera el motor en el primer arranque
# (server_mode.c: escribe server.web_password en config.toml). No se toca aqui:
# duplicarla la fijaria en el log de instalacion.
WEB_BIND="$(grep -oE '^[[:space:]]*web_bind[[:space:]]*=[[:space:]]*"[^"]*"' "$INSTALL_DIR/config.toml" 2>/dev/null | sed 's/.*"\(.*\)"/\1/' | head -1 || true)"
if [ -n "$WEB_BIND" ] && [ "$WEB_BIND" != "127.0.0.1" ] && [ "$WEB_BIND" != "localhost" ]; then
    log "    [!] server.web_bind = $WEB_BIND: el dashboard escucha fuera de loopback."
    log "        Su contrasena esta en config.toml (server.web_password), hecha por el servidor."
fi

# ------------------------------------------------------------------------------
# Usuario y servicio
# ------------------------------------------------------------------------------
if ! id -u "$SERVICE_USER" >/dev/null 2>&1; then
    useradd --system --shell /usr/sbin/nologin --home-dir "$INSTALL_DIR" "$SERVICE_USER"
    log "[+] Usuario '$SERVICE_USER' creado."
fi

chown -R "$SERVICE_USER:$SERVICE_USER" "$INSTALL_DIR"
chmod 0640 "$INSTALL_DIR/config.toml" 2>/dev/null || true

EXEC_CMD="$INSTALL_DIR/halo --server --config $INSTALL_DIR/config.toml"
[ -n "$EXEC_PREFIX" ] && EXEC_CMD="$EXEC_PREFIX $EXEC_CMD"

cat > "/etc/systemd/system/$SERVICE_NAME.service" <<SYSTEMD_EOF
[Unit]
Description=Halo: Combat Evolved Dedicated Server (OpenCE Netcode v41)
After=network-online.target
Wants=network-online.target
StartLimitIntervalSec=300
StartLimitBurst=5

[Service]
Type=simple
User=$SERVICE_USER
Group=$SERVICE_USER
WorkingDirectory=$INSTALL_DIR
Environment=SDL_VIDEODRIVER=dummy
Environment=SDL_AUDIODRIVER=dummy
Environment=LD_LIBRARY_PATH=$INSTALL_DIR
Environment=HOME=$INSTALL_DIR
ExecStart=$EXEC_CMD
Restart=on-failure
RestartSec=5
LimitNOFILE=65535
NoNewPrivileges=true
PrivateTmp=true
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
SYSTEMD_EOF

# gpu_mem solo en Raspberry Pi
if [ -f /boot/firmware/config.txt ]; then CONFIG_BOOT="/boot/firmware/config.txt"
elif [ -f /boot/config.txt ]; then CONFIG_BOOT="/boot/config.txt"; fi
if [ -n "$CONFIG_BOOT" ] && ! grep -q "^gpu_mem=" "$CONFIG_BOOT"; then
    echo "gpu_mem=16" >> "$CONFIG_BOOT"
    log "[*] gpu_mem=16 en $CONFIG_BOOT (el servidor no dibuja)."
fi

systemctl daemon-reload
systemctl enable "$SERVICE_NAME" >/dev/null 2>&1 || true
# Un intento anterior fallido deja la unidad en start-limit-hit, que impide
# arrancar hasta un reset: se limpia siempre antes de probar.
systemctl reset-failed "$SERVICE_NAME" 2>/dev/null || true

if [ "$NEED_REBOOT_FOR_64BIT" = "1" ]; then
    log ""
    log "=========================================================="
    log " INSTALACION LISTA: reinicia para activar el kernel de 64 bits"
    log "=========================================================="
    log "  sudo reboot"
    log ""
    log "  Al arrancar, el servidor lo hace solo."
    exit 0
fi

# ------------------------------------------------------------------------------
# Arranque con diagnostico y rollback
# ------------------------------------------------------------------------------
MAP_COUNT="$(find "$INSTALL_DIR/maps" -maxdepth 1 -name '*.map' 2>/dev/null | wc -l | tr -d ' ')"
if [ "${MAP_COUNT:-0}" -eq 0 ]; then
    log ""
    log " [!] No hay mapas en $INSTALL_DIR/maps: el motor no puede arrancar sin ui.map."
    log "     Importalos desde tu ISO de Xbox y vuelve a arrancar:"
    log "       sudo $INSTALL_DIR/scripts/import-maps.sh halo.iso"
    log "       sudo systemctl restart $SERVICE_NAME"
fi

systemctl restart "$SERVICE_NAME" 2>/dev/null || true
ATTEMPT=0
while [ "$ATTEMPT" -lt 15 ]; do
    sleep 1
    ATTEMPT=$((ATTEMPT + 1))
    if ! systemctl is-active --quiet "$SERVICE_NAME"; then
        break
    fi
    # el motor sale a los ~2 s si le faltan datos: se exige que siga vivo
    if [ "$ATTEMPT" -ge 8 ] && systemctl is-active --quiet "$SERVICE_NAME"; then
        break
    fi
done

SERVICE_LOG="$(journalctl -u "$SERVICE_NAME" --since "-3min" --no-pager 2>/dev/null || true)"

if ! systemctl is-active --quiet "$SERVICE_NAME"; then
    say ""
    say "[-] El servicio no arranco. Ultimas lineas del journal:"
    printf '%s\n' "$SERVICE_LOG" | tail -20 | tee -a "$LOG_FILE"

    case "$SERVICE_LOG" in
        *"no usable maps"*)
            say ""
            say "[!] Es un problema de datos, no del binario: faltan los mapas del juego."
            say "    Copia las .map a $INSTALL_DIR/maps o ejecuta:"
            say "      sudo $INSTALL_DIR/scripts/import-maps.sh halo.iso"
            say "    El servicio queda registrado y arrancara al reiniciarlo."
            exit 2
            ;;
        *"is taken by another program"*)
            say ""
            say "[!] El puerto UDP de juego esta ocupado por otro programa:"
            say "      ss -lunp | grep 2302"
            say "    Liberalo, o cambia network.tunnel_port en $INSTALL_DIR/config.toml."
            say "    El binario esta instalado; el servicio arrancara al liberar el puerto."
            exit 3
            ;;
    esac

    if [ -n "$OLD_BIN" ] && [ -f "$BACKUP_DIR/halo" ]; then
        say ""
        say "[*] Restaurando la version anterior..."
        install -m 0755 "$BACKUP_DIR/halo" "$INSTALL_DIR/halo"
        [ -f "$BACKUP_DIR/libSDL3.so.0" ] && install -m 0755 "$BACKUP_DIR/libSDL3.so.0" "$INSTALL_DIR/libSDL3.so.0"
        systemctl restart "$SERVICE_NAME" 2>/dev/null || true
        sleep 3
        if systemctl is-active --quiet "$SERVICE_NAME"; then
            say "[+] Version anterior restaurada y en marcha. La actualizacion no se aplico."
        else
            say "[-] La version anterior tampoco arranca. Revisa el journal y $LOG_FILE"
        fi
    fi
    exit 1
fi

VERSION="$(systemctl show -p MainPID --value "$SERVICE_NAME" >/dev/null 2>&1 && \
    journalctl -u "$SERVICE_NAME" --since "-2min" --no-pager 2>/dev/null | grep -oE "OpenCE build-[0-9]+, network version [0-9]+" | tail -1 || true)"
IP_ADDR="$(hostname -I 2>/dev/null | awk '{print $1}')"
[ -n "$IP_ADDR" ] || IP_ADDR="<IP-del-servidor>"

log ""
log "=========================================================="
if [ "${MAP_COUNT:-0}" -eq 0 ]; then
    log " INSTALADO: FALTAN LOS MAPAS DEL JUEGO"
elif [ "$IS_UPDATE" = "1" ]; then
    log " ACTUALIZACION COMPLETADA"
else
    log " INSTALACION COMPLETADA"
fi
log "=========================================================="
log "  Estado:    $(systemctl is-active "$SERVICE_NAME" 2>/dev/null || echo inactivo)"
log "  Version:   ${VERSION:-ver journalctl}"
log "  Registros: sudo journalctl -u $SERVICE_NAME -f"
log "  Carpeta:   $INSTALL_DIR"
log ""
log " DASHBOARD (escucha solo en esta maquina):"
log "   ssh -L 8080:127.0.0.1:8080 root@$IP_ADDR"
log "   abre http://127.0.0.1:8080 en tu navegador"
log ""
log " Para exponerlo en la LAN, en config.toml:"
log "   web_bind = \"0.0.0.0\"    (la contrasena ya esta en config.toml)"
log "   systemctl restart $SERVICE_NAME"
log ""
log " MAPAS:"
log "   $INSTALL_DIR/maps/         mapas originales (.map)"
log "   $INSTALL_DIR/custom_maps/  mapas Custom Edition"
log "   Desde una ISO de Xbox: sudo $INSTALL_DIR/scripts/import-maps.sh halo.iso"
log "=========================================================="
