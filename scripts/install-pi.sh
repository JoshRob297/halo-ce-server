#!/usr/bin/env bash
# install-pi.sh: Instalador automatico universal para Raspberry Pi (32-bit y 64-bit)
# Detecta Raspbian Bookworm armv7l, habilita kernel 64-bit transparente o Box86.
set -euo pipefail

echo "=========================================================="
echo " Instalador 1-Click: Halo CE Dedicated Server 24/7 (Pi)   "
echo "=========================================================="

if [ "$(id -u)" != "0" ]; then
    echo "ERROR: Ejecutalo con permisos de administrador (sudo):" >&2
    echo "  curl -fsSL https://raw.githubusercontent.com/JoshRob297/halo-ce-server/main/scripts/install-pi.sh | sudo bash" >&2
    exit 1
fi

INSTALL_DIR="/opt/halo-server"
ARCH="$(uname -m)"
BITS="$(getconf LONG_BIT 2>/dev/null || echo 32)"

echo "[*] Arquitectura del Kernel: $ARCH"
echo "[*] Espacio de usuario:      ${BITS}-bit"

# 1. Dependencias esenciales
echo "[*] Instalando dependencias base..."
apt-get update -qq
apt-get install -y -qq curl wget tar gzip 7zip coreutils procps net-tools ca-certificates >/dev/null

# 2. Deteccion y adaptacion inteligente para 32-bit (armv7l / Raspbian Bookworm)
PKG_NAME="halo-server-linux-arm64.tar.gz"
NEED_REBOOT_FOR_64BIT=0

# Identificar archivo de configuracion de arranque de la Pi
CONFIG_FILE=""
if [ -f /boot/firmware/config.txt ]; then
    CONFIG_FILE="/boot/firmware/config.txt"
elif [ -f /boot/config.txt ]; then
    CONFIG_FILE="/boot/config.txt"
fi

if [ "$ARCH" = "armv7l" ] || [ "$BITS" = "32" ]; then
    echo "[!] Detectado sistema operativo de 32 bits (Raspbian armv7l)."
    
    # Comprobar si el procesador es fisicamente ARMv8 (64-bit: Pi 3B, 3B+, 4, 400, 5, Zero 2W)
    if grep -qE "ARMv8|CPU architecture: 8|cortex-a53|cortex-a72|cortex-a76" /proc/cpuinfo 2>/dev/null || [ -d /sys/module/bcm2835 ]; then
        echo "[+] Tu procesador fisico soporta 64-bit de forma nativa."
        if [ -n "$CONFIG_FILE" ]; then
            if ! grep -q "^arm_64bit=1" "$CONFIG_FILE"; then
                echo "" >> "$CONFIG_FILE"
                echo "# Habilitar kernel AArch64 para Halo Server" >> "$CONFIG_FILE"
                echo "arm_64bit=1" >> "$CONFIG_FILE"
                echo "[+] Habilitado 'arm_64bit=1' en $CONFIG_FILE."
                if [ "$ARCH" != "aarch64" ]; then
                    NEED_REBOOT_FOR_64BIT=1
                fi
            fi
        fi
        PKG_NAME="halo-server-linux-arm64.tar.gz"
    else
        echo "[!] Hardware antiguo (ARMv6/ARMv7 puro como Pi 1 o Pi 2)."
        echo "[*] Instalando Box86 para soporte x86..."
        apt-get install -y -qq box86 2>/dev/null || true
        PKG_NAME="halo-server-linux-x86.tar.gz"
    fi
fi

# 3. Preparar usuario del sistema y carpetas
echo "[*] Configurando usuario de sistema 'halo' y rutas en $INSTALL_DIR..."
id -u halo >/dev/null 2>&1 || useradd --system --shell /usr/sbin/nologin --home-dir "$INSTALL_DIR" halo
mkdir -p "$INSTALL_DIR/maps" "$INSTALL_DIR/custom_maps" "$INSTALL_DIR/scripts" "$INSTALL_DIR/web"

# 4. Descargar paquete oficial precompilado
echo "[*] Descargando release oficial de produccion ($PKG_NAME)..."
TAR_URL="https://github.com/JoshRob297/halo-ce-server/releases/latest/download/$PKG_NAME"
curl -fsSL "$TAR_URL" -o /tmp/halo-pkg.tar.gz
tar -xzf /tmp/halo-pkg.tar.gz --strip-components=1 -C "$INSTALL_DIR"
rm -f /tmp/halo-pkg.tar.gz

chmod +x "$INSTALL_DIR/halo" 2>/dev/null || true
chmod +x "$INSTALL_DIR/scripts/"*.sh 2>/dev/null || true

# 5. Servicio systemd 24/7 con auto-arranque y auto-reinicio
echo "[*] Creando y registrando servicio systemd 'halo-server'..."
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

# 6. Optimizacion de memoria GPU (16 MB para dejar toda la RAM libre al server)
if [ -n "$CONFIG_FILE" ]; then
    if ! grep -q "^gpu_mem=" "$CONFIG_FILE"; then
        echo "gpu_mem=16" >> "$CONFIG_FILE"
        echo "[+] Asignado gpu_mem=16 en $CONFIG_FILE para maximizar RAM libre."
    fi
fi

chown -R halo:halo "$INSTALL_DIR"
systemctl daemon-reload
systemctl enable halo-server

# Arrancar si no requiere reinicio previo
if [ "$NEED_REBOOT_FOR_64BIT" = "0" ]; then
    systemctl restart halo-server 2>/dev/null || true
fi

IP_ADDR="$(hostname -I 2>/dev/null | awk '{print $1}' || echo 'IP_DE_TU_PI')"

echo ""
echo "=========================================================="
echo "       INSTALACION COMPLETADA AUTOMATICAMENTE             "
echo "=========================================================="

if [ "$NEED_REBOOT_FOR_64BIT" = "1" ]; then
    echo ""
    echo "[!] ATENCION: Tu Raspberry Pi tenia activo el kernel de 32 bits."
    echo "    Ya activamos 'arm_64bit=1' en config.txt automaticamente."
    echo ""
    echo "    👉 SOLO REINICIA TU RASPBERRY PI CON:"
    echo "       sudo reboot"
    echo ""
    echo "    Al encender, el servidor arrancara SOLO en 64 bits al 100%."
else
    echo ""
    echo "  Servidor ejecutandose 24/7 en segundo plano."
    echo "  - Tactical Web Dashboard: http://${IP_ADDR}:8080"
    echo "  - Ver registros en vivo:  sudo journalctl -u halo-server -f"
fi

echo ""
echo "MAPAS DEL JUEGO:"
echo "  Copia tus archivos .map (ui.map, beavercreek.map...) a:"
echo "  $INSTALL_DIR/maps/"
echo ""
echo "  (Si tienes tu archivo halo.iso de Xbox, corre:)"
echo "  sudo $INSTALL_DIR/scripts/import-maps.sh /ruta/a/halo.iso"
echo "=========================================================="
