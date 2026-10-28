#!/usr/bin/env bash
# install-server.sh: Instalador universal 1-Click para cualquier sistema Linux
# Soporta: x86_64 (PC/VPS), ARM64 (Raspberry Pi 3/4/5, Oracle Ampere, Graviton)
# y sistemas 32-bit (Raspbian armv7l o i686).
set -euo pipefail

echo "=========================================================="
echo " Instalador 1-Click: Halo CE Dedicated Server 24/7        "
echo " (OpenCE Netcode v39 + Tactical Web Dashboard v2)         "
echo "=========================================================="

if [ "$(id -u)" != "0" ]; then
    echo "ERROR: Por favor ejecuta este instalador con sudo:" >&2
    echo "  curl -fsSL https://raw.githubusercontent.com/JoshRob297/halo-ce-server/main/scripts/install-server.sh | sudo bash" >&2
    exit 1
fi

INSTALL_DIR="/opt/halo-server"
ARCH="$(uname -m)"
BITS="$(getconf LONG_BIT 2>/dev/null || echo 64)"

echo "[*] Arquitectura del sistema: $ARCH ($BITS-bit)"

# 1. Instalar dependencias del sistema segun gestor de paquetes
echo "[*] Instalando herramientas base (curl, tar, 7z, utilerias de red)..."
if command -v apt-get >/dev/null 2>&1; then
    apt-get update -qq
    apt-get install -y -qq curl wget tar gzip 7zip coreutils procps net-tools ca-certificates >/dev/null
elif command -v dnf >/dev/null 2>&1; then
    dnf install -y -q curl wget tar gzip p7zip p7zip-plugins coreutils procps-ng net-tools ca-certificates >/dev/null
elif command -v pacman >/dev/null 2>&1; then
    pacman -Sy --noconfirm --needed curl wget tar gzip p7zip coreutils procps-ng net-tools ca-certificates >/dev/null
fi

# 2. Seleccion automatica del paquete de release segun arquitectura
PKG_NAME="halo-server-linux-x64.tar.gz"
NEED_REBOOT_FOR_64BIT=0

# Identificar archivo de configuracion de Raspberry Pi si aplica
CONFIG_FILE=""
if [ -f /boot/firmware/config.txt ]; then
    CONFIG_FILE="/boot/firmware/config.txt"
elif [ -f /boot/config.txt ]; then
    CONFIG_FILE="/boot/config.txt"
fi

case "$ARCH" in
    x86_64|amd64)
        PKG_NAME="halo-server-linux-x64.tar.gz"
        echo "[+] Detectado PC / Servidor Linux x86_64."
        ;;
    aarch64|arm64)
        PKG_NAME="halo-server-linux-arm64.tar.gz"
        echo "[+] Detectado hardware ARM64 nativo (Raspberry Pi 64-bit / Servidor Cloud)."
        ;;
    armv7l|armhf)
        echo "[!] Detectado sistema ARM de 32 bits."
        # Si el procesador fisico es ARMv8 (Pi 3B, 3B+, 4, 400, 5, Zero 2W)
        if grep -qE "ARMv8|CPU architecture: 8|cortex-a53|cortex-a72|cortex-a76" /proc/cpuinfo 2>/dev/null || [ -d /sys/module/bcm2835 ]; then
            echo "[+] Procesador de 64 bits detectado bajo SO de 32 bits."
            if [ -n "$CONFIG_FILE" ]; then
                if ! grep -q "^arm_64bit=1" "$CONFIG_FILE"; then
                    echo "" >> "$CONFIG_FILE"
                    echo "# Habilitar kernel 64-bit para Halo Server" >> "$CONFIG_FILE"
                    echo "arm_64bit=1" >> "$CONFIG_FILE"
                    echo "[+] 'arm_64bit=1' anadido a $CONFIG_FILE."
                    NEED_REBOOT_FOR_64BIT=1
                fi
            fi
            PKG_NAME="halo-server-linux-arm64.tar.gz"
        else
            echo "[!] Hardware ARMv7 puro: configurando emulador ligero Box86..."
            if command -v apt-get >/dev/null 2>&1; then
                apt-get install -y -qq box86 2>/dev/null || true
            fi
            PKG_NAME="halo-server-linux-x86.tar.gz"
        fi
        ;;
    i386|i686)
        PKG_NAME="halo-server-linux-x86.tar.gz"
        echo "[+] Detectado sistema x86 de 32 bits."
        ;;
    *)
        PKG_NAME="halo-server-linux-x64.tar.gz"
        ;;
esac

# 3. Usuario aislado y carpetas
echo "[*] Creando usuario 'halo' y estructura de archivos en $INSTALL_DIR..."
id -u halo >/dev/null 2>&1 || useradd --system --shell /usr/sbin/nologin --home-dir "$INSTALL_DIR" halo
mkdir -p "$INSTALL_DIR/maps" "$INSTALL_DIR/custom_maps" "$INSTALL_DIR/scripts" "$INSTALL_DIR/web"

# 4. Descarga del paquete oficial precompilado
echo "[*] Descargando release oficial de produccion ($PKG_NAME)..."
TAR_URL="https://github.com/JoshRob297/halo-ce-server/releases/latest/download/$PKG_NAME"
curl -fsSL "$TAR_URL" -o /tmp/halo-pkg.tar.gz
tar -xzf /tmp/halo-pkg.tar.gz --strip-components=1 -C "$INSTALL_DIR"
rm -f /tmp/halo-pkg.tar.gz

chmod +x "$INSTALL_DIR/halo" 2>/dev/null || true
chmod +x "$INSTALL_DIR/scripts/"*.sh 2>/dev/null || true

# 5. Servicio systemd 24/7
echo "[*] Registrando servicio systemd 'halo-server'..."
cat << SYSTEMD_EOF > /etc/systemd/system/halo-server.service
[Unit]
Description=Halo Combat Evolved Dedicated Server 24/7 (OpenCE Netcode v39)
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=halo
Group=halo
WorkingDirectory=$INSTALL_DIR
Environment="SDL_VIDEODRIVER=dummy"
Environment="SDL_AUDIODRIVER=dummy"
Environment="LD_LIBRARY_PATH=$INSTALL_DIR"
ExecStart=$INSTALL_DIR/halo --server --config $INSTALL_DIR/config.toml
Restart=always
RestartSec=5
LimitNOFILE=65535
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
SYSTEMD_EOF

# Optimizacion de memoria GPU si es Raspberry Pi
if [ -n "$CONFIG_FILE" ]; then
    if ! grep -q "^gpu_mem=" "$CONFIG_FILE"; then
        echo "gpu_mem=16" >> "$CONFIG_FILE"
        echo "[+] Asignado gpu_mem=16 en $CONFIG_FILE para maximizar memoria RAM libre."
    fi
fi

chown -R halo:halo "$INSTALL_DIR"
systemctl daemon-reload
systemctl enable halo-server

if [ "$NEED_REBOOT_FOR_64BIT" = "0" ]; then
    systemctl restart halo-server 2>/dev/null || true
fi

IP_ADDR="$(hostname -I 2>/dev/null | awk '{print $1}' || echo 'IP_DE_TU_SERVIDOR')"

echo ""
echo "=========================================================="
echo "       INSTALACION COMPLETADA AUTOMATICAMENTE             "
echo "=========================================================="

if [ "$NEED_REBOOT_FOR_64BIT" = "1" ]; then
    echo ""
    echo "[!] ATENCION (Raspberry Pi 32-bit):"
    echo "    Activamos 'arm_64bit=1' en config.txt automaticamente."
    echo ""
    echo "    👉 REINICIA TU RASPBERRY PI CON:"
    echo "       sudo reboot"
    echo ""
    echo "    Al reiniciar, el servidor arrancara SOLO en 64 bits al 100%."
else
    echo ""
    echo "  Servidor ejecutandose 24/7 en segundo plano."
    echo "  - Tactical Web Dashboard: http://${IP_ADDR}:8080"
    echo "  - Ver registros en vivo:  sudo journalctl -u halo-server -f"
fi

echo ""
echo "MAPAS DEL JUEGO:"
echo "  Copia tus archivos .map a:"
echo "  $INSTALL_DIR/maps/"
echo ""
echo "  (Si tienes tu archivo halo.iso de Xbox, corre:)"
echo "  sudo $INSTALL_DIR/scripts/import-maps.sh /ruta/a/halo.iso"
echo "=========================================================="
