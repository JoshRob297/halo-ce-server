#!/usr/bin/env bash
# ==============================================================================
# install-server.sh: Instalador universal 1-Click para Halo CE Dedicated Server
# Compatible con: x86_64 (PC/VPS), ARM64 (Raspberry Pi 3/4/5, Oracle Ampere,
#   AWS Graviton), ARMv7 (32-bit Raspbian con kernel 64-bit transparente).
# Caracteristicas:
#   - Auto-detecta e instala dependencias del sistema (apt/dnf/pacman).
#   - Detecta instalacion previa y la repara o actualiza.
#   - Descarga la ultima release de produccion (v1.5.1+).
#   - Configura servicio systemd 24/7 con auto-reinicio.
#   - Optimiza memoria GPU en Raspberry Pi (gpu_mem=16).
#   - Habilita kernel 64-bit transparente en SO de 32 bits si el CPU lo soporta.
#   - Preserva config.toml y mapas existentes al actualizar.
# ==============================================================================

set -euo pipefail

INSTALL_DIR="/opt/halo-server"
ARCH="$(uname -m)"
BITS="$(getconf LONG_BIT 2>/dev/null || echo 64)"
RELEASE_URL="https://github.com/JoshRob297/halo-ce-server/releases/latest/download"
SERVICE_NAME="halo-server"
CONFIG_FILE=""
NEED_REBOOT_FOR_64BIT=0
IS_UPDATE=0

# ==============================================================================
# 1. Verificar permisos de root
# ==============================================================================
if [ "$(id -u)" != "0" ]; then
    echo "ERROR: Ejecuta este instalador con sudo:" >&2
    echo "  curl -fsSL https://raw.githubusercontent.com/JoshRob297/halo-ce-server/main/scripts/install-server.sh | sudo bash" >&2
    exit 1
fi

echo "=========================================================="
echo " Instalador Universal: Halo CE Dedicated Server 24/7     "
echo " (OpenCE Netcode v39 + Tactical Web Dashboard v2)        "
echo "=========================================================="
echo ""

# ==============================================================================
# 2. Identificar archivo de configuracion de arranque (Raspberry Pi)
# ==============================================================================
if [ -f /boot/firmware/config.txt ]; then
    CONFIG_FILE="/boot/firmware/config.txt"
elif [ -f /boot/config.txt ]; then
    CONFIG_FILE="/boot/config.txt"
fi

# ==============================================================================
# 3. Detectar instalacion previa
# ==============================================================================
if [ -f "$INSTALL_DIR/halo" ]; then
    IS_UPDATE=1
    echo "[*] Instalacion existente detectada en $INSTALL_DIR"
    echo "    Se actualizara la version sin tocar config.toml ni mapas."
    echo ""
fi

# ==============================================================================
# 4. Instalar dependencias del sistema segun gestor de paquetes
# ==============================================================================
echo "[*] Verificando e instalando dependencias del sistema..."

install_deps_apt() {
    apt-get update -qq
    apt-get install -y -qq curl wget tar gzip p7zip-full coreutils procps \
        net-tools ca-certificates 2>/dev/null || true
}

install_deps_dnf() {
    dnf install -y -q curl wget tar gzip p7zip p7zip-plugins coreutils \
        procps-ng net-tools ca-certificates 2>/dev/null || true
}

install_deps_pacman() {
    pacman -Sy --noconfirm --needed curl wget tar gzip p7zip coreutils \
        procps-ng net-tools ca-certificates >/dev/null 2>&1 || true
}

if command -v apt-get >/dev/null 2>&1; then
    install_deps_apt
elif command -v dnf >/dev/null 2>&1; then
    install_deps_dnf
elif command -v pacman >/dev/null 2>&1; then
    install_deps_pacman
else
    echo "[!] Gestor de paquetes no reconocido. Asegurate de tener curl, tar, gzip, 7z instalados."
fi

# Verificar que las herramientas criticas esten disponibles
for tool in curl tar gzip; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        echo "[-] ERROR: Falta la herramienta '$tool'. Instalala manualmente."
        exit 1
    fi
done

if ! command -v 7z >/dev/null 2>&1 && ! command -v extract-xiso >/dev/null 2>&1; then
    echo "[!] Advertencia: No se encontro 7z ni extract-xiso. El extractor de mapas ISO no funcionara."
    echo "    Instala con: sudo apt install -y p7zip-full"
fi

echo "[+] Dependencias verificadas."

# ==============================================================================
# 5. Seleccion automatica del paquete segun arquitectura
# ==============================================================================
echo "[*] Detectando arquitectura del sistema: $ARCH ($BITS-bit)..."

PKG_NAME="halo-server-linux-x64.tar.gz"

case "$ARCH" in
    x86_64|amd64)
        PKG_NAME="halo-server-linux-x64.tar.gz"
        echo "    -> PC / Servidor Linux x86_64 (64-bit nativo)"
        ;;
    aarch64|arm64)
        PKG_NAME="halo-server-linux-arm64.tar.gz"
        echo "    -> Hardware ARM64 nativo (Raspberry Pi 64-bit / Cloud ARM64)"
        ;;
    armv7l|armhf)
        echo "    -> Sistema ARM de 32 bits detectado."
        # Comprobar si el procesador fisico es ARMv8 (64-bit)
        if grep -qE "ARMv8|CPU architecture: 8|cortex-a53|cortex-a72|cortex-a76" /proc/cpuinfo 2>/dev/null || [ -d /sys/module/bcm2835 ]; then
            echo "    -> Procesador de 64 bits detectado bajo SO de 32 bits."
            if [ -n "$CONFIG_FILE" ]; then
                if ! grep -q "^arm_64bit=1" "$CONFIG_FILE"; then
                    echo "" >> "$CONFIG_FILE"
                    echo "# Habilitar kernel AArch64 para Halo Server" >> "$CONFIG_FILE"
                    echo "arm_64bit=1" >> "$CONFIG_FILE"
                    echo "    [+] Habilitado 'arm_64bit=1' en $CONFIG_FILE."
                    NEED_REBOOT_FOR_64BIT=1
                else
                    echo "    [+] 'arm_64bit=1' ya estaba configurado."
                fi
            fi
            PKG_NAME="halo-server-linux-arm64.tar.gz"
        else
            echo "    -> Hardware ARMv7 puro: configurando emulador ligero Box86..."
            if command -v apt-get >/dev/null 2>&1; then
                apt-get install -y -qq box86 2>/dev/null || true
            fi
            PKG_NAME="halo-server-linux-x86.tar.gz"
        fi
        ;;
    i386|i686)
        PKG_NAME="halo-server-linux-x86.tar.gz"
        echo "    -> Sistema x86 de 32 bits."
        ;;
    *)
        echo "    [!] Arquitectura no reconocida ($ARCH). Intentando x86_64 por defecto."
        PKG_NAME="halo-server-linux-x64.tar.gz"
        ;;
esac

# ==============================================================================
# 6. Crear usuario del sistema y carpetas (si no existen)
# ==============================================================================
echo "[*] Configurando usuario 'halo' y directorios en $INSTALL_DIR..."

if ! id -u halo >/dev/null 2>&1; then
    useradd --system --shell /usr/sbin/nologin --home-dir "$INSTALL_DIR" halo
    echo "    [+] Usuario 'halo' creado."
else
    echo "    [+] Usuario 'halo' ya existe."
fi

mkdir -p "$INSTALL_DIR/maps" \
         "$INSTALL_DIR/custom_maps" \
         "$INSTALL_DIR/scripts" \
         "$INSTALL_DIR/web"

# ==============================================================================
# 7. Backup de config.toml si existe (antes de actualizar)
# ==============================================================================
if [ "$IS_UPDATE" = "1" ] && [ -f "$INSTALL_DIR/config.toml" ]; then
    cp "$INSTALL_DIR/config.toml" "$INSTALL_DIR/config.toml.bak"
    echo "[*] Backup de config.toml creado: config.toml.bak"
fi

# ==============================================================================
# 8. Descargar e instalar la ultima release de produccion
# ==============================================================================
echo "[*] Descargando ultima release de produccion ($PKG_NAME)..."
TAR_URL="$RELEASE_URL/$PKG_NAME"
curl -fsSL "$TAR_URL" -o /tmp/halo-pkg.tar.gz
echo "    [+] Descargado: $PKG_NAME"

# Extraer sin sobrescribir config.toml ni mapas
tar -xzf /tmp/halo-pkg.tar.gz --strip-components=1 -C "$INSTALL_DIR" \
    --exclude='config.toml' \
    --exclude='maps' \
    --exclude='custom_maps' \
    --exclude='maps_ce' 2>/dev/null || \
tar -xzf /tmp/halo-pkg.tar.gz --strip-components=1 -C "$INSTALL_DIR"
rm -f /tmp/halo-pkg.tar.gz

chmod +x "$INSTALL_DIR/halo" 2>/dev/null || true
chmod +x "$INSTALL_DIR/scripts/"*.sh 2>/dev/null || true

# ==============================================================================
# 9. Crear config.toml si no existe (instalacion nueva)
# ==============================================================================
if [ ! -f "$INSTALL_DIR/config.toml" ]; then
    if [ -f "$INSTALL_DIR/config.toml.example" ]; then
        cp "$INSTALL_DIR/config.toml.example" "$INSTALL_DIR/config.toml"
    elif [ -f "$INSTALL_DIR/deploy/config.toml" ]; then
        cp "$INSTALL_DIR/deploy/config.toml" "$INSTALL_DIR/config.toml"
    else
        # Configuracion minima por defecto
        cat << 'TOML_EOF' > "$INSTALL_DIR/config.toml"
[debug]
null_renderer = true
network_test = "host:beavercreek:swat;wizard:infection;chillout:gun_game;prisoner:swat;putput:infection;damnation:gun_game;longest:swat;carousel:infection"
network_test_time = 15
network_test_player = false
network_test_start = 1.0

[server]
name = "Halo CE Dedicated Server"
password = ""
web_enabled = true
web_port = 8080
web_password = ""

[network]
online = true
host_public = true
tunnel_port = 2302

[match]
respawn_time = -1
score_to_win = 20
TOML_EOF
    fi
    echo "    [+] config.toml creado con valores por defecto."
fi

# ==============================================================================
# 10. Optimizacion de memoria GPU (Raspberry Pi)
# ==============================================================================
if [ -n "$CONFIG_FILE" ]; then
    if ! grep -q "^gpu_mem=" "$CONFIG_FILE"; then
        echo "gpu_mem=16" >> "$CONFIG_FILE"
        echo "[*] Asignado gpu_mem=16 en $CONFIG_FILE para maximizar RAM libre."
    else
        echo "[*] gpu_mem ya configurado en $CONFIG_FILE."
    fi
fi

# ==============================================================================
# 11. Servicio systemd 24/7 con auto-reinicio
# ==============================================================================
echo "[*] Registrando servicio systemd '$SERVICE_NAME'..."

EXEC_CMD="$INSTALL_DIR/halo --server --config $INSTALL_DIR/config.toml"
# Si es ARMv7 puro con Box86
if [ "$ARCH" = "armv7l" ] || [ "$ARCH" = "armhf" ]; then
    if ! grep -qE "ARMv8|CPU architecture: 8|cortex-a53|cortex-a72|cortex-a76" /proc/cpuinfo 2>/dev/null && [ ! -d /sys/module/bcm2835 ]; then
        EXEC_CMD="/usr/bin/box86 $INSTALL_DIR/halo --server --config $INSTALL_DIR/config.toml"
    fi
fi

cat << SYSTEMD_EOF > /etc/systemd/system/$SERVICE_NAME.service
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
ExecStart=$EXEC_CMD
Restart=always
RestartSec=5
LimitNOFILE=65535
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
SYSTEMD_EOF

chown -R halo:halo "$INSTALL_DIR"
systemctl daemon-reload
systemctl enable "$SERVICE_NAME" >/dev/null 2>&1 || true

# ==============================================================================
# 12. Arrancar o reiniciar el servicio
# ==============================================================================
IP_ADDR="$(hostname -I 2>/dev/null | awk '{print $1}' || echo 'IP_DE_TU_SERVIDOR')"

if [ "$NEED_REBOOT_FOR_64BIT" = "1" ]; then
    echo ""
    echo "=========================================================="
    echo "  INSTALACION COMPLETADA (requiere reinicio)             "
    echo "=========================================================="
    echo ""
    echo "  [!] Tu Raspberry Pi tenia activo el kernel de 32 bits."
    echo "      Ya activamos 'arm_64bit=1' en config.txt automaticamente."
    echo ""
    echo "  👉 SOLO REINICIA TU RASPBERRY PI CON:"
    echo "     sudo reboot"
    echo ""
    echo "  Al reiniciar, el servidor arrancara SOLO en 64 bits al 100%."
    echo ""
else
    systemctl restart "$SERVICE_NAME" 2>/dev/null || true
    echo ""
    echo "=========================================================="
    if [ "$IS_UPDATE" = "1" ]; then
        echo "  ACTUALIZACION COMPLETADA EXITOSAMENTE                  "
    else
        echo "  INSTALACION COMPLETADA EXITOSAMENTE                    "
    fi
    echo "=========================================================="
    echo ""
    echo "  Servidor ejecutandose 24/7 en segundo plano."
    echo "  - Tactical Web Dashboard: http://${IP_ADDR}:8080"
    echo "  - Ver registros en vivo:  sudo journalctl -u $SERVICE_NAME -f"
    echo ""
    echo "MAPAS DEL JUEGO:"
    echo "  Copia tus archivos .map a:"
    echo "  $INSTALL_DIR/maps/ (mapas normales)"
    echo "  $INSTALL_DIR/custom_maps/ (mapas custom)"
    echo ""
    echo "  (Si tienes tu archivo halo.iso de Xbox, corre:)"
    echo "  sudo $INSTALL_DIR/scripts/import-maps.sh \"halo.iso\""
    echo "=========================================================="
fi
