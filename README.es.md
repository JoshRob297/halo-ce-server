<div align="center">

# Servidor Dedicado de Halo CE

**Servidor dedicado 24/7 headless para Halo: Combat Evolved (OpenCE)**

<p align="center">
  <a href="README.md">English</a> • <b>Español</b>
</p>

[![Release](https://img.shields.io/github/v/release/JoshRob297/halo-ce-server?style=for-the-badge&color=blue)](https://github.com/JoshRob297/halo-ce-server/releases/latest)
[![Docker](https://img.shields.io/badge/docker-ready-2496ED?style=for-the-badge&logo=docker&logoColor=white)](#inicio-rápido-docker)
[![Netcode](https://img.shields.io/badge/netcode-v38-green?style=for-the-badge)](#quién-puede-unirse)
[![Web Dashboard](https://img.shields.io/badge/web-dashboard-002244?style=for-the-badge&logo=html5&logoColor=2299ff)](#dashboard-web)
[![Anti-Cheat](https://img.shields.io/badge/anticheat-enforced-success?style=for-the-badge)](docs/anticheat.md)
[![License](https://img.shields.io/badge/license-MIT-purple?style=for-the-badge)](LICENSE)

Ejecuta un servidor multijugador o cooperativo continuo **sin monitor, sin GPU y sin tarjeta de sonido**.<br/>
Construido sobre el puerto nativo de [OpenCE](https://github.com/OpenCommunityEdition/OpenCE) (`dhost-v38`).

[Inicio Rápido](#inicio-rápido-docker) • [Guía Completa](#guía-completa-paso-a-paso) • [Dashboard Web](#dashboard-web) • [CLI de Operador](#cli-de-operador-operatorsh) • [Raspberry Pi ARM64](docs/raspberry-pi.md) • [Ajustes](#tabla-de-configuración) • [English Version](README.md)

</div>

---

### Características Principales

- **Netcode Nativo OpenCE (v38):** Compatible directamente con todos los clientes oficiales de OpenCE (Windows, Linux, Android y Web) sin requerir modificaciones.
- **Dashboard Web Embebido (Opcional en `:8080`):** Interfaz gráfica de administración web integrada en el binario sin dependencias externas (HTML, CSS y JS puro).
- **Rotación y Votación en Lobby:** Soporta rotación secuencial o aleatoria (`shuffle`), y permite a los jugadores del lobby votar por la siguiente partida escribiendo `1` a `N` en el chat.
- **Anti-Inactividad (AFK Auto-Kick):** Detecta inactividad de sticks, botones y mira, enviando advertencia privada a $T-30$s y desconectando automáticamente al jugador inactivo.
- **Baneos Progresivos Escalables:** Sistema automático de strikes (1h -> 24h -> 7d -> permanente) con expiración automática transparente.
- **Server Browser Público:** Se anuncia automáticamente en el buscador público oficial del juego o permite acceso mediante enlace directo (`halo://join/...`).
- **Consumo Mínimo de Recursos:** Funciona con renderizador nulo y drivers dummy de SDL. Ideal para cualquier VPS básico, mini-PC, NUC o servidor homelab.

---

## Arquitectura General

```
+-------------------------------------------------------------------------+
|                           MÁQUINA SERVIDOR                              |
|                                                                         |
|  +--------------------------- Docker / Bare Metal --------------------+ |
|  |                                                                    | |
|  |  Motor de Halo (OpenCE Core) <---> config.toml (Rotación y Límites)| |
|  |       |                                                            | |
|  |  Drivers Virtuales A/V (SDL dummy, renderizador nulo)              | |
|  |       |                                                            | |
|  |  Dashboard Web Embebido (HTTP/REST :8080 opcional)                 | |
|  |       |                                                            | |
|  |  Listener de Red de Juego (UDP 2302)                               | |
|  +-------|------------------------------------------------------------+ |
+----------|--------------------------------------------------------------+
           |
           +---> STUN / Master Browser (Descubrimiento Público)
           |
           +---> Clientes Entrantes (PC, Android APK, Linux, Web)
```

---

## Dashboard Web

El servidor incluye un Dashboard Web nativo embebido en C que escucha en el puerto `:8080`, replicando fielmente la interfaz de administración oficial de OpenCE y manteniendo 100% de compatibilidad con los clientes oficiales actuales (Netcode v38).

El panel web es **completamente opcional**: si se configura `health_port = 0`, el servidor no abre ningún socket HTTP y corre en modo headless puro.

<p align="center">
  <img src="docs/screenshots/dashboard_status.png" alt="Dashboard Web de Halo CE - Pestaña Status" width="850">
</p>

### Módulos del Dashboard
- **Status y Telemetría en Vivo:** Mapa actual, variante activa, tiempo de partida, marcador en vivo, uptime y gráfica histórica de jugadores de los últimos 10 minutos.
- **Gestor de Rotación:** Reordenamiento interactivo de mapas (`Up`, `Down`, `Remove`, `Play Now`) y formulario para agregar nuevas combinaciones de mapas y modos en caliente.
- **Administración de Jugadores:** Monitoreo con ping, IP, equipo y botones de moderación instantánea (`Kick`, `Ban`, `Mute`).
- **Ajustes y Consola Web:** Editor visual de parámetros de `config.toml` y terminal interactiva RCON en el navegador.

<p align="center">
  <img src="docs/screenshots/dashboard_rotation.png" alt="Gestor de Rotación de Mapas" width="420">&nbsp;
  <img src="docs/screenshots/dashboard_settings.png" alt="Editor de Ajustes" width="420">
</p>

---

## Contenido

- [Qué Necesitas](#qué-necesitas)
- [Inicio Rápido (Docker)](#inicio-rápido-docker)
- [Guía Completa Paso a Paso](#guía-completa-paso-a-paso)
- [CLI de Operador (operator.sh)](#cli-de-operador-operatorsh)
- [Multiplataforma y Hardware Compatible](#multiplataforma-y-hardware-compatible)
- [Servidor en Windows](#servidor-en-windows)
- [Tabla de Configuración](#tabla-de-configuración)
- [Mapas y Modos de Juego](#mapas-y-modos-de-juego)
- [Campañas Cooperativas (16 Jugadores)](#campañas-cooperativas-hasta-16-jugadores)
- [Bots, Mapas Custom y Mods](#bots-mapas-custom-y-mods)
- [Quién Puede Unirse](#quién-puede-unirse)
- [Solución de Problemas](#solución-de-problemas)
- [Seguridad y Anti-Cheat](#seguridad-y-anti-cheat)
- [Hoja de Ruta y Estado](#hoja-de-ruta-y-estado-del-proyecto)
- [Comparativa: Nuestra Versión vs Upstream](#comparativa-nuestra-versión-vs-upstream)
- [Créditos y Atribución](#créditos-y-atribución)

---

## Qué Necesitas

1. **Archivos de mapas del juego:** Debes proveer la carpeta `maps/` extraída de **tu propio disco original legal**. El servidor nunca incluye ni distribuye datos protegidos por derechos de autor.
2. **Entorno de ejecución:**
   - **Docker** (Recomendado en cualquier sistema operativo), o
   - **Linux x86_64** (servicio systemd / binario portable), o
   - **Windows** (consola o servicio NSSM).
3. **Acceso de red:** Un puerto UDP entrante (por defecto: `2302`). UPnP se intenta automáticamente; para servidores dedicados se recomienda abrir el puerto manualmente en el router.

### Extracción de Mapas del Disco

Para multijugador necesitas `ui.map` y los mapas que quieras en la rotación (`bloodgulch.map`, `chillout.map`, etc.). Para cooperativo requieres además los mapas de campaña (`a10.map`, `c10.map`, etc.). Los mapas de Custom Edition van en una carpeta `custom_maps/`.

Extracción desde la imagen ISO original (se hace una sola vez en tu PC):

```sh
# Usando extract-xiso (Linux / macOS / WSL)
extract-xiso -x "Halo - Combat Evolved (USA).xiso.iso"

# O usando 7-Zip
7z x "Halo - Combat Evolved (USA).xiso.iso" maps/
```

---

## Inicio Rápido (Docker)

Con Docker y Docker Compose instalados:

```sh
# 1. Crear estructura de carpetas
mkdir -p halo-server/maps

# 2. Copiar los mapas extraídos
cp /ruta/a/tus/mapas/* halo-server/maps/

# 3. Descargar docker-compose.yml
cd halo-server
curl -fsSL -O https://raw.githubusercontent.com/JoshRob297/halo-ce-server/main/docker-compose.yml

# 4. Iniciar el servidor
docker compose up -d

# 5. Ver los registros en vivo
docker compose logs -f
```

En menos de un minuto verás:
```text
halo-linux: Internet play: hosting. Invite players with this link: halo://join/...
halo-linux: Internet play: the game is listed in everyone's server browser (public)
halo-linux: network test: game 1, gun_game on beavercreek
```

---

## Guía Completa Paso a Paso

### Paso 1: Organizar los Archivos

```sh
mkdir -p ~/halo-server/maps
cd ~/halo-server

# Copiar el mapa base obligatorio
cp /ruta/a/tus/mapas/ui.map ./maps/

# Copiar los mapas multijugador deseados
cp /ruta/a/tus/mapas/beavercreek.map ./maps/
cp /ruta/a/tus/mapas/bloodgulch.map ./maps/
cp /ruta/a/tus/mapas/chillout.map ./maps/
cp /ruta/a/tus/mapas/damnation.map ./maps/
cp /ruta/a/tus/mapas/wizard.map ./maps/
```

### Paso 2: Descargar Configuraciones

```sh
curl -fsSL -O https://raw.githubusercontent.com/JoshRob297/halo-ce-server/main/docker-compose.yml
curl -fsSL -O https://raw.githubusercontent.com/JoshRob297/halo-ce-server/main/server/config.toml
```

### Paso 3: Personalizar `config.toml`

Abre `config.toml` y edita los valores principales:

```toml
[network]
server_name = "Mi Servidor Halo 24/7"    # Nombre en el Server Browser
tunnel_port = 2302                       # Puerto UDP de juego
public_chat = true                       # Permitir chat de texto en partidas públicas
map_rotation = "shuffle"                 # "sequence" o "shuffle" (aleatorio)
map_voting = true                        # Votación de mapas en lobby por chat
map_vote_options = 3                     # Candidatos a votar (2 a 5)
afk_timeout = 180                        # Auto-kick por inactividad (segundos, 0 = desactiva)
health_port = 8080                       # Puerto del Dashboard Web y API (0 = desactiva)

[debug]
null_renderer = true
network_test = "host:beavercreek:gun_game,swat;wizard:gun_game,infection;chillout:swat,infection"
network_test_time = 15                   # Límite de partida en minutos
network_test_countdown = 15              # Segundos de cuenta regresiva en el lobby
network_test_player = true               # Inicia la partida automáticamente y permite unirse en caliente
telnet_console = true
telnet_console_port = 2323
```

En `docker-compose.yml`, descomenta la línea del volumen de configuración:
```yaml
    volumes:
      - ./maps:/halo/maps:ro
      - ./saved:/root/.local/share/halo-linux
      - ./config.toml:/halo/config.toml:ro
```

### Paso 4: Firewall y Reenvío de Puertos (Port Forwarding)

Abre el puerto UDP `2302` (juego) y opcionalmente TCP `8080` (dashboard web):

```sh
# UFW (Ubuntu / Debian)
sudo ufw allow 2302/udp
sudo ufw allow 8080/tcp

# FirewallD (Fedora / RHEL)
sudo firewall-cmd --add-port=2302/udp --permanent
sudo firewall-cmd --add-port=8080/tcp --permanent
sudo firewall-cmd --reload
```

En routers residenciales: Reenvía el puerto UDP `2302` hacia la IP local de tu servidor.

### Paso 5: Despliegue en Bare Metal (systemd)

Si prefieres ejecutar directamente en el sistema operativo sin contenedores:

```sh
# 1. Ejecutar el instalador automatizado
sudo curl -fsSL https://raw.githubusercontent.com/JoshRob297/halo-ce-server/main/scripts/install-baremetal.sh | sudo bash -s -- /srv/halo

# 2. Copiar mapas
sudo cp /ruta/a/tus/mapas/* /srv/halo/maps/

# 3. Editar configuración
sudo nano /srv/halo/config.toml

# 4. Iniciar y habilitar el servicio
sudo systemctl enable --now halo-server
sudo journalctl -u halo-server -f
```

---

## CLI de Operador (operator.sh)

El servidor incluye la utilidad `scripts/operator.sh` que se comunica con la consola interna mediante telnet loopback local (`127.0.0.1:2323`).

### Uso con Docker
```bash
# Consultar estado en vivo de la partida
docker exec halo-server /halo/operator.sh status

# Expulsar a un jugador
docker exec halo-server /halo/operator.sh kick "NombreJugador"

# Banear con sistema progresivo automático
docker exec halo-server /halo/operator.sh ban "Griefer"

# Iniciar votación de expulsión desde el servidor
docker exec halo-server /halo/operator.sh votekick "AfkPlayer"

# Ejecutar comandos de depuración o Halo Script directamente
docker exec halo-server /halo/operator.sh raw "help kick"
```

### Uso en Bare Metal / Systemd
```bash
/opt/halo-server/operator.sh status
/opt/halo-server/operator.sh kick "NombreJugador"
```

Consulta [docs/operator.md](docs/operator.md) para más detalles sobre comandos de moderación y formatos de archivo.

---

## Multiplataforma y Hardware Compatible

El servidor está optimizado para ejecutarse en diversas arquitecturas y factores de forma:

| Plataforma / Arquitectura | Dispositivos y Hardware | Método de Despliegue | Notas |
| :--- | :--- | :--- | :--- |
| **Linux ARM64 (`aarch64`)** | **Raspberry Pi 3B / 3B+ / 4 / 5**, Orange Pi 5, **Oracle Cloud Ampere A1**, AWS Graviton | **Docker (`linux/arm64`)** o Bare-Metal systemd | Consumo ultra-bajo (2.5W a 4W). Usa ~85 MB de RAM. Guía completa: [docs/raspberry-pi.md](docs/raspberry-pi.md). |
| **Linux x86_64 (`amd64`)** | Servidores VPS (Hetzner, Linode, DigitalOcean, OVH), Proxmox VE / LXC, PC Bare Metal | **Docker (`linux/amd64`)** o Bare-Metal systemd | Despliegue estándar recomendado para homelabs y la nube. |
| **Linux x86 (`i686`)** | Hardware antiguo de 32 bits, VPS legacy | Binario ELF nativo | Máxima compatibilidad retrospectiva. |
| **Windows x86_64 / x86** | Windows 10/11, Windows Server 2016-2025 | Ejecutable `.exe` nativo o servicio NSSM | Sin interfaz gráfica ni sonido (drivers dummy SDL). Guía completa: [docs/windows.md](docs/windows.md). |

---

## Servidor en Windows

El servidor corre de forma nativa en Windows usando los drivers dummy de SDL sin entorno gráfico ni sonido.

- **Guía Completa de Windows:** Consulta [docs/windows.md](docs/windows.md) para la configuración paso a paso, arranque manual en PowerShell/CMD, reglas de Windows Defender Firewall y ejecución persistente como servicio de Windows mediante NSSM (`nssm install HaloServer`).
- **Verificación en CI:** El trabajo `windows` en GitHub Actions (`windows-2025`) compila y verifica continuamente el arranque headless con `SDL_VIDEODRIVER=dummy SDL_AUDIODRIVER=dummy`.

---

## Tabla de Configuración

Todos los parámetros se gestionan en `config.toml` o mediante variables de entorno equivalentes:

| Parámetro | Tipo | Default | Variable de Entorno | Descripción |
| :--- | :--- | :--- | :--- | :--- |
| `network.server_name` | String | `""` | `HALO_NET_SERVER_NAME` | Nombre visible en el Server Browser público (máx. 32 caracteres). |
| `network.tunnel_port` | Integer | `2302` | `HALO_NET_TUNNEL_PORT` | Puerto de red UDP para el tráfico de juego. |
| `network.online` | Boolean | `true` | `HALO_NET_ONLINE` | Habilita conectividad a internet (`false` = solo LAN). |
| `network.host_public` | Boolean | `true` | `HALO_NET_HOST_PUBLIC` | Publica la partida en el Server Browser oficial. |
| `network.public_chat` | Boolean | `true` | `HALO_NET_PUBLIC_CHAT` | Habilita chat de texto en partidas públicas moderadas. |
| `network.server_password`| String | `""` | `HALO_NET_SERVER_PASSWORD` | Contraseña de acceso con hash Argon2id (vacío = servidor abierto). |
| `network.map_rotation` | String | `"sequence"`| `HALO_NET_MAP_ROTATION` | `"sequence"` (en orden) o `"shuffle"` (aleatorio sin repetir). |
| `network.map_voting` | Boolean | `false` | `HALO_NET_MAP_VOTING` | Votación en lobby para que los jugadores elijan el siguiente mapa por chat. |
| `network.map_vote_options`| Integer | `3` | `HALO_NET_MAP_VOTE_OPTIONS` | Número de opciones candidatas en la votación (2 a 5). |
| `network.afk_timeout` | Integer | `180` | `HALO_NET_AFK_TIMEOUT` | Segundos de inactividad antes de auto-kick (aviso a $T-30$s, 0 = desactiva). |
| `network.escalating_bans`| Boolean | `true` | `HALO_NET_ESCALATING_BANS` | Baneos progresivos por strikes: 1h -> 24h -> 7d -> permanente. |
| `network.health_port` | Integer | `0` | `HALO_NET_HEALTH_PORT` | Puerto TCP para Dashboard Web y API REST (0 = desactiva). |
| `debug.null_renderer` | Boolean | `true` | `HALO_NULL_RENDERER` | Suprime renderizado de ventanas y gráficos (modo headless). |
| `debug.network_test` | String | `""` | `HALO_NETWORK_TEST` | Lista de mapas y modos: `"host:mapa:modo;mapa:modo"`. |
| `debug.network_test_time` | Integer | `0` | `HALO_NETWORK_TEST_TIME` | Límite máximo de partida en minutos. |
| `debug.network_test_countdown`| Integer| `0` | `HALO_NETWORK_TEST_COUNTDOWN`| Segundos de cuenta regresiva en el lobby (0 = 31s). |
| `debug.network_test_player` | Boolean | `true` | `HALO_NETWORK_TEST_PLAYER` | `true`: añade jugador host inactivo para iniciar solo y permitir unirse en caliente. |

---

## Mapas y Modos de Juego

### Mapas Soportados
Cualquier archivo `.map` presente en la carpeta `maps/` puede especificarse por su nombre base:
`beavercreek`, `bloodgulch`, `boardingaction`, `carousel`, `chillout`, `damnation`, `hangemhigh`, `longest`, `prisoner`, `putput`, `ratrace`, `sidewinder`, `wizard`.

Para mapas de Custom Edition en `custom_maps/`, usa el prefijo correspondiente: `custom_maps\hugeass`.

### Modos de Juego Soportados
Puedes encadenar múltiples modos por mapa separados por comas:

| Identificador | Categoría | Reglas y Mecánicas |
| :--- | :--- | :--- |
| **`slayer`** / **`team_slayer`** | Clásico Halo | Combate a muerte todos contra todos o por equipos. |
| **`ctf`** / **`ironctf`** | Clásico Halo | Captura la bandera. `ironctf` desactiva devolución por toque. |
| **`oddball`** / **`team_oddball`** | Clásico Halo | Mantener la calavera para acumular puntos. Ataque cuerpo a cuerpo con calavera. |
| **`king`** / **`team_king`** | Clásico Halo | Rey de la Colina. Acumular tiempo dentro de la colina móvil. |
| **`race`** / **`team_race`** / **`rally`** | Clásico Halo | Conducir vehículos por una secuencia de puntos de control. |
| **`swat`** | **Custom OpenCE** | Sin escudos, muerte instantánea por disparo a la cabeza con cualquier arma, inicio con pistola + rifle, sin radar, sin granadas en mapa. |
| **`infection`** | **Custom OpenCE** | Humanos (Rojo) vs Zombies (Verde/Azul). Zombies con mayor velocidad y ataque de calavera. Los humanos eliminados se convierten en zombies. |
| **`gun_game`** | **Custom OpenCE** | Juego de Armas. Cada baja otorga el siguiente arma de la lista. La baja con el último arma gana la partida. |
| **`hardcore`** / **`hardcore_slayer`**| **Custom OpenCE** | Sin sensor de movimiento, sin asistencia de apuntado. Cada baja restaura instantáneamente vida y escudos completos al asesino. |
| **`hardcore_ctf`** | **Custom OpenCE** | Captura la bandera con reglas hardcore (sin radar, sin aim assist, regeneración por kill). |
| **`hardcore_oddball`** | **Custom OpenCE** | Oddball con reglas hardcore (sin radar, sin aim assist, regeneración por kill). |
| **`hardcore_king`** | **Custom OpenCE** | Rey de la colina con reglas hardcore (sin radar, sin aim assist, regeneración por kill). |
| **`coop`** | Campaña | Misiones cooperativas de la campaña original (`a10`, `b30`, etc.). |

---

## Campañas Cooperativas (Hasta 16 Jugadores)

El servidor soporta de forma nativa la campaña completa en cooperativo online para **hasta 16 jugadores simultáneos** (el juego original de Xbox solo permitía 2 en pantalla dividida).

### Cómo Hostear Campaña Co-op
En `config.toml`, define el nivel y la variante `coop` en `network_test`:
```toml
[debug]
# Hostear una misión específica o rotación de campaña:
network_test = "host:a10:coop"
# O una rotación completa de misiones:
# network_test = "host:a10:coop;a30:coop;b30:coop;c10:coop"
```

### Identificadores de Misiones de Campaña
| ID Nivel | Nombre del Mapa | Nombre de la Misión |
| :--- | :--- | :--- |
| **`a10`** | `a10.map` | The Pillar of Autumn |
| **`a30`** | `a30.map` | Halo |
| **`a50`** | `a50.map` | The Truth and Reconciliation |
| **`b30`** | `b30.map` | The Silent Cartographer |
| **`b40`** | `b40.map` | Assault on the Control Room |
| **`c10`** | `c10.map` | 343 Guilty Spark |
| **`c20`** | `c20.map` | The Library |
| **`c40`** | `c40.map` | Two Betrayals |
| **`d20`** | `d20.map` | Keyes |
| **`d40`** | `d40.map` | The Maw |

### Ajustes Especiales de Co-op en `config.toml`
- `network.coop_enemies_mode = "per_player"`: Escala el tamaño de los escuadrones enemigos automáticamente con cada jugador adicional (hasta 8x enemigos para balancear 16 jugadores).
- `network.coop_pickups = "per_player"`: Multiplica la munición y botiquines en el mapa según el conteo de jugadores.
- `network.coop_friendly_fire = "on"`: Fuego amigo (`"off"`, `"on"`, `"shields_only"`, `"explosives_only"`).
- `coop_vehicles`: Los Pelicans en cinemáticas descargan automáticamente Warthogs adicionales si hay más jugadores en la escuadra.
- `coop_spectate`: Si un jugador muere mientras sus compañeros continúan vivos, entra en modo espectador en tercera persona sobre sus aliados hasta que reaparece.

---

## Bots, Mapas Custom y Mods

### Bots Multijugador Inteligentes
El servidor incluye IA de bots multijugador nativa (`bots.c`) capaz de navegar, combatir con armas y disputar objetivos (Slayer, CTF, King of the Hill):
- En `config.toml`: `bots.count = 4` (añade de 1 a 16 bots para rellenar partidas vacías).
- Vía Consola RCON / Web Console: `bots.count = 8` o `bots.skill = "expert"`.

### Descarga Automática P2P de Mapas Custom (`map_share`)
OpenCE incorpora un protocolo P2P tipo BitTorrent (`map_share.c`):
- Los mapas de Custom Edition se colocan en la carpeta `custom_maps/` (por ejemplo `custom_maps/hugeass.map`).
- Cuando un jugador entra sin el mapa, el servidor calcula el hash SHA-256 y envía piezas (`chunks`).
- Los demás jugadores en la partida que ya tienen el mapa actúan como semillas (`seeders`), transmitiendo piezas en paralelo.
- El juego descarga el mapa en segundo plano mientras el servidor continúa la partida; el jugador se une en caliente al completarse la descarga.
- Control de ancho de banda: `network.map_share_upload = 1024` (KB/s máximos dedicados a compartir mapas para proteger el tráfico de juego).

### Mods de Tags (HEK e Invader)
El motor soporta mods basados en tags en la carpeta `mods/`:
- Estructura: `mods/<nombre_mod>/mod.toml` y subcarpeta `tags/`.
- Permite sustituir texturas, sonidos, textos y geometrías de armas/vehículos con tags de Halo PC sin romper la compatibilidad de red con clientes vainilla.
- Gestión de orden de carga automática con `load_order.toml`.

---

## Quién Puede Unirse

| Tipo de Cliente | Versión de Red | Estado |
| :--- | :--- | :--- |
| **OpenCE Oficial (Desktop / PC)** | v38 | Compatible directamente |
| **OpenCE Android APK** | v38 | Compatible directamente |
| **OpenCE WebAssembly (Navegador)** | v38 | Compatible directamente |
| **Clientes Anteriores (v37 o menor)** | ≤ v37 | Requiere actualizar cliente |

---

## Solución de Problemas

### `SDL_Init failed: No available video device`
Ocurre si ejecutas el binario directamente en Linux sin definir los controladores dummy de SDL. Exporta las variables:
```sh
export SDL_VIDEODRIVER=dummy
export SDL_AUDIODRIVER=dummy
```

### El Servidor no Aparece en el Server Browser
1. Verifica que `network.online = true` y `network.host_public = true` estén activos en `config.toml`.
2. Asegúrate de que el puerto UDP 2302 sea accesible externamente. Conexiones detrás de CGNAT estricto requieren utilizar un VPS con IP pública directa.

### `No es posible unirse a la partida` desde el Teléfono
1. **En Wi-Fi Local (NAT Loopback):** Si intentas unirte desde el Server Browser estando conectado al Wi-Fi de tu casa, routers residenciales que no soportan NAT Hairpinning descartan los paquetes dirigidos a su propia IP pública. Conéctate vía **System Link (LAN)** o usa datos móviles (4G/5G).
2. **Partida en Pregame sin Jugadores:** Asegúrate de tener `network_test_player = true` en `config.toml` para que la partida inicie automáticamente y acepte uniones en caliente.

---

## Seguridad y Anti-Cheat

El servidor ejerce autoridad estricta como anfitrión de la partida (Host Authority):
- Autoridad exclusiva del servidor sobre inventario, munición de armas, granadas y marcadores.
- Validación exhaustiva de reportes de daño: posesión previa del arma disparada, cadencia máxima por ráfaga, esferas de colisión históricas de la víctima y trazado de rayos para verificar línea de visión directa (Line-of-Sight).
- Detección automática de aceleración de reloj (Speed Hacks) con rechazo inmediato de predicción y baneo automático verificado.

Consulta [docs/anticheat.md](docs/anticheat.md) para el informe completo de auditoría, la matriz de protecciones del host y la guía de administración de sanciones.

---

## Hoja de Ruta y Estado del Proyecto

- [x] Despliegue completo headless en contenedores Docker y systemd.
- [x] Rotación automatizada de secuencias de mapas y modos de juego.
- [x] Publicación automática en el Server Browser público y generación de tokens de invitación.
- [x] Consola interactiva de operador (`operator.sh` / Telnet loopback).
- [x] Conmutador de chat público (`network.public_chat`).
- [x] Filtro de acceso / contraseña de servidor con hash Argon2id (`network.server_password`).
- [x] Auditoría completa de seguridad y anti-cheat documentada ([docs/anticheat.md](docs/anticheat.md)).
- [x] Web Dashboard nativo de telemetría y API REST en tiempo real (`:8080`).
- [x] Soporte nativo para Windows headless ([docs/windows.md](docs/windows.md)).
- [x] Soporte multiplataforma ARM64 para Raspberry Pi 3B/4/5 y Oracle Cloud ([docs/raspberry-pi.md](docs/raspberry-pi.md)).

Consulta [docs/roadmap.md](docs/roadmap.md) para los hitos y próximas características planeadas.

---

## Comparativa: Nuestra Versión vs Upstream

| Característica | Nuestra Versión (`halo-ce-server`) | Rama Experimental Upstream (`dedicated-server`) |
| :--- | :--- | :--- |
| **Compatibilidad con Clientes** | **100% Compatible (Netcode v38)**<br>Todos los jugadores actuales de Android APK, PC y Linux pueden entrar ya. | **Incompatible hoy (Netcode v39)**<br>Requiere actualizaciones de cliente no lanzadas al público. |
| **Dashboard Web** | **Embebido Nativo sin Dependencias (`:8080`)**<br>Admin web interactivo, telemetría en vivo, gráfica histórica y editor de rotación. | Embebido en rama experimental apuntando a v39. |
| **Votación de Mapas en Lobby** | **Votación Interactiva por Chat (`map_voting = true`)**<br>Los jugadores eligen la siguiente partida escribiendo `1` a `N` en el chat. | Solo rotación fija o cambio manual por comando. |
| **Auto-Kick por Inactividad (AFK)** | **Protección Automatizada (`afk_timeout = 180`)**<br>Monitorea sticks analógicos, botones y mira con aviso privado a $T-30$s. | No implementado. |
| **Baneos Progresivos Escalables** | **Sistema de Strikes (`escalating_bans = true`)**<br>1h -> 24h -> 7d -> permanente con expiraciones automáticas. | Flag manual de duración por comando (`sv_ban <player> 2h`). |
| **Rotación de Mapas** | **Secuencial y Aleatoria (`shuffle`)**<br>Evita repetir el mapa anterior de forma consecutiva. | Parser de lista secuencial. |
| **CLI de Operador** | **Script `operator.sh` + Terminal Web + Telnet Loopback** | Stdin de consola, WebSocket RCON, Terminal Web. |
| **Distribución Pública** | **Imagen Docker en GHCR (`139 MB`) + Releases Binarios** | Código fuente en rama no mergeada. |

---

## Créditos y Atribución

- **[Proyecto OpenCE](https://github.com/OpenCommunityEdition/OpenCE):** La descompilación base, la arquitectura del motor y el netcode multijugador son obra y mantenimiento de los contribuidores de la comunidad OpenCE.
- **Arquitectura de Interfaz Web:** El diseño visual del dashboard, los estilos (`app.css`) y la lógica cliente del frontend (`app.js`) fueron creados por **MrBruh / cybersecurity** en el proyecto OpenCE. Nosotros adaptamos el dashboard para interactuar directamente con el núcleo del motor en Netcode v38, brindando disponibilidad inmediata a la comunidad sin forzar la transición a v39.

---

## Licencia

Este repositorio de empaquetado, scripts y documentación se proporcionan bajo la [Licencia MIT](LICENSE).
Halo: Combat Evolved es una marca registrada de Microsoft Corporation. Este proyecto es una herramienta independiente de código abierto basada en la descompilación de OpenCE.
