# Guía Definitiva de Instalación: Raspberry Pi 3B / 4 / 5 & ARM64 (Bare-Metal sin Docker)

Esta guía explica paso a paso cómo instalar, configurar y ejecutar de forma nativa el servidor dedicado 24/7 de **Halo: Combat Evolved (OpenCE Netcode v39)** en placas **Raspberry Pi** de 64 bits (**Raspberry Pi 3 Model B, 3B+, 4, 400 y 5**) y servidores basados en arquitectura **ARM64 (AArch64)** como **Oracle Cloud Ampere A1** (Free Tier), AWS Graviton o VPS Debian/Ubuntu ARM64, **directamente en el sistema operativo sin sobrecarga de Docker**.

---

## 1. Requisitos de Hardware y Sistema Operativo

| Componente | Requisito Mínimo (RPi 3B) | Recomendado (RPi 4 / 5) |
| :--- | :--- | :--- |
| **Procesador** | Broadcom BCM2837 (Quad-Core Cortex-A53 @ 1.2 GHz) | Broadcom BCM2711 / BCM2712 |
| **Memoria RAM** | 1 GB LPDDR2 | 2 GB a 8 GB LPDDR4/5 |
| **Almacenamiento** | MicroSD Clase 10 / A1 (8 GB mínimo libre) | SSD USB 3.0 / NVMe Hat |
| **Sistema Operativo** | **Raspberry Pi OS (64-bit / Bookworm)** o Ubuntu Server 24.04 ARM64 | **Raspberry Pi OS (64-bit / Bookworm)** |
| **Arquitectura** | `aarch64` (`uname -m` debe devolver `aarch64`) | `aarch64` |

> **IMPORTANTE:** El sistema operativo debe ser de **64 bits**. Para comprobar que tu Raspberry Pi corre en 64 bits, ejecuta:
> ```bash
> uname -m
> # Debe devolver: aarch64
> ```

---

## 2. Optimización del Sistema para Raspberry Pi (1 GB / 2 GB RAM)

En servidores headless dedicados que no tienen monitor conectado, es indispensable liberar la memoria RAM asignada al procesador gráfico:

### A. Reducir memoria de la GPU a 16 MB
1. Abre el archivo de configuración de arranque:
   ```bash
   sudo nano /boot/firmware/config.txt
   # En versiones antiguas de Raspberry Pi OS: sudo nano /boot/config.txt
   ```
2. Añade o modifica al final:
   ```ini
   gpu_mem=16
   ```
3. Guarda con `Ctrl+O`, `Enter` y sal con `Ctrl+X`. Esto deja más de 950 MB de RAM libres para el sistema y el servidor de Halo.

### B. Habilitar Swap ZRAM Comprimido (Previene cuelgues por Out-Of-Memory)
```bash
sudo apt update && sudo apt install -y zram-tools
echo -e "ALGO=lz4\nPERCENT=50" | sudo tee /etc/default/zramswap
sudo systemctl restart zramswap
```

---

## 3. Instalación de Dependencias del Sistema

El servidor de Halo corre con controladores dummy de SDL (sin monitor, sin tarjeta de sonido y sin GPU). Para ejecutar el paquete y permitir la compatibilidad binaria multiarquitectura:

```bash
# Actualizar repositorios e instalar paquetes base
sudo apt update && sudo apt install -y \
  curl wget tar gzip 7zip coreutils procps net-tools ca-certificates

# Habilitar soporte multiarquitectura si corres Debian/Raspberry Pi OS
sudo dpkg --add-architecture armhf 2>/dev/null || true
sudo apt update && sudo apt install -y libc6 libstdc++6 2>/dev/null || true
```

---

## 4. Instalación Paso a Paso del Servidor (Desde Cero)

### Paso 1: Crear usuario y directorios del sistema
Por seguridad y aislamiento, el servidor se ejecuta bajo un usuario sin privilegios de root (`halo`):

```bash
# Crear usuario de sistema dedicado
sudo id -u halo >/dev/null 2>&1 || sudo useradd --system --shell /usr/sbin/nologin --home-dir /opt/halo-server halo

# Crear árbol de carpetas estándar
sudo mkdir -p /opt/halo-server/maps \
              /opt/halo-server/custom_maps \
              /opt/halo-server/scripts \
              /opt/halo-server/web
```

### Paso 2: Descargar el paquete oficial compilado (Release v1.5.1+)
Descargamos el paquete oficial de producción que incluye el motor compilado Netcode v39, librerías SDL3, plantillas TOML y el Tactical Web Dashboard v2:

```bash
cd /tmp
curl -fsSL https://github.com/JoshRob297/halo-ce-server/releases/latest/download/halo-server-linux-arm64.tar.gz -o halo-server.tar.gz

# Extraer el contenido en /opt/halo-server
sudo tar -xzf halo-server.tar.gz --strip-components=1 -C /opt/halo-server/
rm -f halo-server.tar.gz

# Dar permisos de ejecución al binario y scripts
sudo chmod +x /opt/halo-server/halo
sudo chmod +x /opt/halo-server/scripts/*.sh 2>/dev/null || true
```

### Paso 3: Importar los mapas legales del juego
El servidor necesita los archivos de mapas (`.map`) para poder iniciar partidas. Tienes dos formas de añadirlos:

#### Opción A: Extracción automática desde ISO legal de Xbox (Recomendada)
Si tienes el archivo ISO del disco original (`halo.iso`):
```bash
cd /opt/halo-server
sudo ./scripts/import-maps.sh /ruta/a/tu/halo.iso
```
*El script extraerá automáticamente `ui.map`, `beavercreek.map`, `wizard.map`, etc., y verificará sus hashes SHA-256.*

#### Opción B: Copia manual de mapas
Si ya tienes los archivos `.map` en tu PC, cópialos por SSH / SCP directamente a la carpeta maps:
```bash
# Desde tu PC:
scp *.map pi@IP_DE_TU_RASPBERRY:/tmp/
# En la Raspberry Pi:
sudo mv /tmp/*.map /opt/halo-server/maps/
```
*Asegúrate de que al menos existan `ui.map` y los mapas que tengas configurados en tu rotación.*

### Paso 4: Ajustar permisos
```bash
sudo chown -R halo:halo /opt/halo-server
```

---

## 5. Configurar el Archivo `config.toml`

Edita la configuración con tus preferencias de servidor:

```bash
sudo nano /opt/halo-server/config.toml
```

Asegúrate de revisar los siguientes valores clave:

```toml
[debug]
null_renderer = true

# Rotación de mapas chicos y modos alternados
network_test = "host:beavercreek:swat;wizard:infection;chillout:gun_game;prisoner:swat;putput:infection;damnation:gun_game;longest:swat;carousel:infection"
network_test_time = 15
network_test_player = false
network_test_start = 1.0

[server]
name = "JOCESLAB MX | RASPBERRY PI 24/7"
password = ""
web_enabled = true
web_port = 8080
web_password = ""

[network]
online = true
host_public = true
tunnel_port = 2302

[match]
respawn_time = -1     # -1 = Reaparición inmediata (0s)
score_to_win = 20     # Límite a 20 bajas
```

Guarda los cambios con `Ctrl+O`, `Enter` y sal con `Ctrl+X`.

---

## 6. Configurar como Servicio 24/7 (systemd)

Para que el servidor arranque solo cuando enciendes la Raspberry Pi, se reinicie automáticamente ante cortes de luz o caídas y corra en segundo plano:

1. Crea el archivo de servicio:
   ```bash
   sudo nano /etc/systemd/system/halo-server.service
   ```

2. Pega la siguiente configuración optimizada:
   ```ini
   [Unit]
   Description=Halo Combat Evolved Dedicated Server 24/7 (OpenCE Netcode v39)
   After=network-online.target
   Wants=network-online.target

   [Service]
   Type=simple
   User=halo
   Group=halo
   WorkingDirectory=/opt/halo-server
   Environment="SDL_VIDEODRIVER=dummy"
   Environment="SDL_AUDIODRIVER=dummy"
   Environment="LD_LIBRARY_PATH=/opt/halo-server"
   ExecStart=/opt/halo-server/halo --server --config /opt/halo-server/config.toml
   Restart=always
   RestartSec=5
   LimitNOFILE=65535
   StandardOutput=journal
   StandardError=journal

   [Install]
   WantedBy=multi-user.target
   ```

3. Recarga systemd y activa el servicio:
   ```bash
   sudo systemctl daemon-reload
   sudo systemctl enable halo-server
   sudo systemctl start halo-server
   ```

---

## 7. Verificación y Operación

### Comprobar estado en vivo:
```bash
sudo systemctl status halo-server
```

### Ver el registro en vivo (Log con colores):
```bash
sudo journalctl -u halo-server -f -o cat
```

### Comprobar puertos abiertos:
```bash
ss -tuln | grep -E '2302|8080'
# Debe mostrar:
# udp  UNCONN  0  0  0.0.0.0:2302  0.0.0.0:*
# tcp  LISTEN  0  8  0.0.0.0:8080  0.0.0.0:*
```

### Acceso al Tactical Web Dashboard:
Abre tu navegador web en tu PC o teléfono e ingresa a:
```text
http://IP_DE_TU_RASPBERRY_PI:8080
```
Verás el **Tactical Web Dashboard v2** con telemetría en tiempo real, cambio de temas (UNSC Titanium, Covenant Sacristan, ONI Black Ops), control de rotación reactivo (`▲`/`▼`) y visor de Anti-Cheat.

---

## 8. Apertura de Puertos en el Router (Port Forwarding)

Para que jugadores de todo el mundo puedan entrar a tu servidor desde el buscador público de Halo CE:

1. Entra a la interfaz de administración de tu router (generalmente `192.168.1.1`).
2. Ve a la sección **Port Forwarding / Reenvío de Puertos**.
3. Añade la regla:
   - **Puerto Externo:** `2302`
   - **Puerto Interno:** `2302`
   - **Protocolo:** **UDP**
   - **IP de Destino:** La IP local de tu Raspberry Pi (ej. `192.168.1.150`).
4. *(Opcional)* Si quieres acceder al Web Dashboard fuera de tu casa, añade el puerto `8080` en protocolo **TCP** (recomendado proteger con contraseña en `config.toml` o mediante VPN WireGuard / Tailscale).

---

## 9. Rendimiento Medido en Raspberry Pi

| Métrica | Raspberry Pi 3B (1 GB) | Raspberry Pi 4 (2/4 GB) | Raspberry Pi 5 (4/8 GB) |
| :--- | :--- | :--- | :--- |
| **Uso de Memoria RAM** | ~85 MB | ~92 MB | ~95 MB |
| **Uso de CPU (Juego 16 jugadores)** | 3.5% - 5.8% | 1.8% - 3.2% | < 1.5% |
| **Tickrate del Motor** | 30.0 Hz clavados | 30.0 Hz clavados | 30.0 Hz clavados |
| **Consumo Eléctrico Promedio** | ~2.5 Watts | ~3.8 Watts | ~4.5 Watts |
| **Costo Eléctrico Estimado** | < $0.50 USD / mes | < $0.80 USD / mes | < $1.00 USD / mes |

La Raspberry Pi es la plataforma física ideal para operar este servidor de forma ininterrumpida y autosuficiente.

---

## 10. ¿Qué pasa si tienes Raspberry Pi OS de 32 bits (`armhf`)?

Si ejecutas `uname -m` y tu sistema reporta **`armv7l`** o tienes instalada la versión tradicional de 32 bits de Raspberry Pi OS, el binario nativo AArch64 (64-bit) no podrá ejecutarse directamente y verás el error:
```text
bash: ./halo: cannot execute binary file: Exec format error
```

Tienes dos soluciones directas para resolverlo:

### Opción A: Activar el Kernel de 64 bits (Recomendada si tu placa es RPi 3, 4 o 5)
Las placas Raspberry Pi 3, 4 y 5 tienen procesadores ARMv8 de 64 bits físicos. Si instalaste el sistema operativo de 32 bits, el hardware soporta correr el kernel de 64 bits manteniendo tus programas de 32 bits:

1. Abre el archivo de configuración del firmware:
   ```bash
   sudo nano /boot/firmware/config.txt
   # En versiones antiguas: sudo nano /boot/config.txt
   ```
2. Añade esta línea al final:
   ```ini
   arm_64bit=1
   ```
3. Guarda (`Ctrl+O`, `Enter`) y reinicia la placa:
   ```bash
   sudo reboot
   ```
4. Al reiniciar, verifica con:
   ```bash
   uname -m
   # Ahora devolverá: aarch64
   ```
   *Con esto ya puedes instalar y ejecutar el servidor ARM64 directamente siguiendo la sección 4 de esta guía.*

---

### Opción B: Ejecutar mediante emulación Box86 (En sistemas 32 bits puros / RPi 2)
Si mantienes un espacio de usuario puramente de 32 bits (`armhf`), puedes correr el binario portable x86 usando **Box86**, un emulador ultraligero que traduce llamadas x86 a ARMv7 sin requerir una máquina virtual pesada:

1. Instalar Box86 desde el repositorio de Pi-Apps o compilado:
   ```bash
   # Instalar dependencias
   sudo apt update && sudo apt install -y git cmake build-essential
   
   # O descargar binario precompilado de Box86 para Raspberry Pi OS
   sudo wget https://ryanfortner.github.io/box86-debs/box86.list -O /etc/apt/sources.list.d/box86.list
   wget -qO- https://ryanfortner.github.io/box86-debs/KEY.gpg | sudo gpg --dearmor -o /etc/apt/trusted.gpg.d/box86.gpg
   sudo apt update && sudo apt install -y box86-rpi3armhf # o box86-rpi4armhf segun tu modelo
   ```

2. Descargar el paquete portable `x86` (i686) de Halo:
   ```bash
   cd /tmp
   curl -fsSL https://github.com/JoshRob297/halo-ce-server/releases/latest/download/halo-server-linux-x86.tar.gz -o halo-x86.tar.gz
   sudo tar -xzf halo-x86.tar.gz --strip-components=1 -C /opt/halo-server/
   rm -f halo-x86.tar.gz
   ```

3. Ejecutar el servidor a través de Box86:
   ```bash
   cd /opt/halo-server
   BOX86_NOBANNER=1 SDL_VIDEODRIVER=dummy SDL_AUDIODRIVER=dummy box86 ./halo --server --config /opt/halo-server/config.toml
   ```
   *Box86 consume solo ~15 MB adicionales de RAM y corre el motor de Halo CE a 30 Hz constantes sin sobrecargar la CPU.*
