# Guía de Instalación: Raspberry Pi 3B / 4 / 5 (ARM64)

Esta guía explica cómo ejecutar el servidor dedicado 24/7 de Halo: Combat Evolved en placas **Raspberry Pi** de 64 bits (**Raspberry Pi 3 Model B, 3B+, 4, 400 y 5**) y servidores en la nube basados en arquitectura **ARM64 (AArch64)** como **Oracle Cloud Ampere A1** (Free Tier) y AWS Graviton.

---

## 1. Requisitos de Hardware y Sistema Operativo

| Componente | Requisito Mínimo (RPi 3B) | Recomendado (RPi 4 / 5) |
| :--- | :--- | :--- |
| **Procesador** | Broadcom BCM2837 (Quad-Core Cortex-A53 @ 1.2 GHz) | Broadcom BCM2711 / BCM2712 |
| **Memoria RAM** | 1 GB LPDDR2 | 2 GB a 8 GB LPDDR4/5 |
| **Almacenamiento** | MicroSD Clase 10 / A1 (8 GB mínimo libre) | SSD USB 3.0 / NVMe Hat |
| **Sistema Operativo** | **Raspberry Pi OS (64-bit)** o Ubuntu Server ARM64 | **Raspberry Pi OS (64-bit)** |
| **Arquitectura Kernel** | `aarch64` (`uname -m` debe reportar `aarch64`) | `aarch64` |

> **IMPORTANTE:** El kernel y sistema operativo deben ser de **64 bits**. Si instalas Raspberry Pi OS de 32 bits (`armhf`), el binario nativo de 64 bits no podrá ejecutarse. Verifica tu arquitectura ejecutando:
> ```bash
> uname -m
> # Debe devolver: aarch64
> ```

---

## 2. Optimización para Raspberry Pi 3B (1 GB de RAM)

Dado que la Raspberry Pi 3B comparte su 1 GB de RAM entre el procesador y el chip de video VideoCore, es indispensable optimizar la memoria asignada al sistema:

### Reducir la memoria de la GPU (headless)
En un servidor sin monitor no necesitamos memoria de video:
1. Abre `/boot/firmware/config.txt` (o `/boot/config.txt` en versiones anteriores):
   ```bash
   sudo nano /boot/firmware/config.txt
   ```
2. Agrega o modifica la línea:
   ```ini
   gpu_mem=16
   ```
3. Guarda (`Ctrl+O`, `Enter`) y sal (`Ctrl+X`). Esto deja más de 950 MB libres para el sistema y el servidor de Halo.

### Habilitar Swap ZRAM (Recomendado)
Para evitar bloqueos por falta de memoria RAM durante picos de carga:
```bash
sudo apt update && sudo apt install -y zram-tools
echo -e "ALGO=lz4\nPERCENT=50" | sudo tee /etc/default/zramswap
sudo systemctl restart zramswap
```

---

## 3. Despliegue con Docker (Método Recomendado)

Docker descarga automáticamente la imagen compilada para `linux/arm64`.

### Paso 1: Instalar Docker en Raspberry Pi
```bash
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER
newgrp docker
```

### Paso 2: Crear el directorio y copiar mapas
```bash
mkdir -p ~/halo-server/maps
cd ~/halo-server

# Copia los mapas originales de tu disco (ui.map, beavercreek.map, etc.)
cp /ruta/a/tus/mapas/* maps/
```

### Paso 3: Descargar `docker-compose.yml` y arrancar
```bash
curl -fsSL -O https://raw.githubusercontent.com/JoshRob297/halo-ce-server/main/docker-compose.yml
curl -fsSL -O https://raw.githubusercontent.com/JoshRob297/halo-ce-server/main/server/config.toml

# Iniciar servidor en segundo plano
docker compose up -d

# Ver registros
docker compose logs -f
```

---

## 4. Despliegue Bare-Metal (systemd nativo)

Si prefieres ejecutar el binario directamente sin Docker:

```bash
# 1. Crear usuario dedicado del sistema
sudo useradd -r -s /usr/sbin/nologin -d /opt/halo-server halo

# 2. Descargar e instalar el binario ARM64
sudo mkdir -p /opt/halo-server/maps /opt/halo-server/custom_maps
cd /tmp
curl -fsSL -O https://github.com/JoshRob297/halo-ce-server/releases/latest/download/halo-server-linux-arm64.tar.gz
sudo tar -xzf halo-server-linux-arm64.tar.gz -C /opt/halo-server/
sudo chmod +x /opt/halo-server/halo /opt/halo-server/scripts/operator.sh
sudo chown -R halo:halo /opt/halo-server

# 3. Copiar mapas
sudo cp /ruta/a/tus/mapas/* /opt/halo-server/maps/
sudo chown -R halo:halo /opt/halo-server/maps

# 4. Habilitar servicio systemd
sudo cp /opt/halo-server/deploy/halo-server.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now halo-server
sudo journalctl -u halo-server -f
```

---

## 5. Rendimiento Medido en Raspberry Pi 3B

| Métrica | Medición Típica |
| :--- | :--- |
| **Uso de RAM en reposo** | ~85 MB a 92 MB |
| **Uso de RAM en partida activa (8 jugadores)** | ~110 MB |
| **Uso de CPU (4 núcleos Cortex-A53)** | 2.5% a 6.0% |
| **Tickrate del servidor** | 30.0 Hz constantes |
| **Consumo eléctrico** | ~2.5 Watts a 3.8 Watts |

La Raspberry Pi 3B es capaz de mantener una rotación ininterrumpida 24/7 con soporte para chat público, rotación aleatoria, votación en lobby y panel web sin sufrir caídas de frames ni estrangulamiento térmico.
