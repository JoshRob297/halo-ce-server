# Halo CE Dedicated Server (OpenCE)

A Halo: Combat Evolved dedicated server that runs 24/7 with **no screen, no
GPU and no sound card**, built on the [OpenCE](https://github.com/OpenCommunityEdition/OpenCE)
native port with the dedicated host carried on top (`dhost-v38`).

- **Network version 38**: today's official OpenCE clients join as-is, over
  LAN, an invite link or the public server browser.
- **Map rotation**: `bloodgulch:slayer,ctf;chillout:oddball;...` in
  `config.toml`; the server returns to its lobby by itself and starts the
  next one.
- **Public or private**: listed in everyone's server browser under your
  server name, or private behind an invite link (`halo://join/...`).
- **Headless**: SDL's dummy drivers, null renderer, no audio device. Runs on
  a VPS, a NUC or an old laptop.

---

## Contents

- [What you need](#what-you-need)
- [Quick start (Docker)](#quick-start-docker)
- [The complete guide, step by step](#the-complete-guide-step-by-step)
- [The settings](#the-settings)
- [Maps and game modes](#maps-and-game-modes)
- [Who can join](#who-can-join)
- [Troubleshooting](#troubleshooting)
- [What this is not (yet)](#what-this-is-not-yet)
- [En espanol](#en-espanol)

---

## What you need

- The game's data, from **your own disc**: the extracted `maps/` folder.
  The server never ships, downloads or distributes game files.
- One of:
  - **Docker** (any OS that runs it), or
  - **Linux** (systemd) for the bare binary, or
  - **Windows** for the bare binary (a console window or NSSM keeps it up).
- One UDP port reachable from the internet for public play (UPnP is asked
  for automatically; otherwise open it by hand - see [Open the port](#open-the-port)).

### What you need from the disc

A multiplayer-only server needs `ui.map` plus the maps in its rotation
(`bloodgulch.map`, `chillout.map`, ...). Co-op also needs the campaign maps
(`a10.map`, `b30.map`, `c10.map`, ...). Custom Edition maps go in a
`custom_maps/` folder.

The ISO is used **once, on your PC, to extract these**. Two ways:

| Way | How |
| --- | --- |
| The port's installer | Run the game once on a PC with the disc image; it extracts `maps/` itself |
| Extract by hand | `extract-xiso -x "Halo - Combat Evolved (USA).xiso.iso"` or 7z: open the image and copy the `maps` folder |

---

## Quick start (Docker)

```sh
mkdir -p halo-server/maps
cp -r /path/to/your/extracted/maps/* halo-server/maps/     # ui.map, bloodgulch.map, ...
curl -fsSL -o docker-compose.yml https://raw.githubusercontent.com/JoshRob297/halo-ce-server/main/docker-compose.yml
docker compose up -d
docker compose logs -f
```

You will see, within a minute:

```
halo-linux: Internet play: hosting. Invite players with this link ...
halo-linux: Internet play: the game is listed in everyone's server browser (public)
```

That is it: the server is up. Share the invite link, or tell people to look
for `My 24/7 Halo` in the server browser of their OpenCE client.

---

## The complete guide, step by step

For someone who has never hosted anything. Every command is given.

### 1. Get the maps from your disc

You own the game? On a PC where the OpenCE game runs, the installer already
extracted a `maps/` folder next to the game. Find it (`.../halo/maps/`) and
copy it. Otherwise extract the disc image:

```sh
# Linux (extract-xiso; or: 7z x disc.iso and copy the maps folder)
extract-xiso -x "Halo - Combat Evolved (USA).xiso.iso"
ls extracted/maps    # ui.map, bloodgulch.map, sidewinder.map, ...
```

You need `ui.map` and at least the multiplayer maps you want in the
rotation. Put them in one folder:

```sh
mkdir -p halo-server/maps
cp extracted/maps/ui.map halo-server/maps/
cp extracted/maps/bloodgulch.map extracted/maps/chillout.map extracted/maps/sidewinder.map halo-server/maps/
```

### 2. Install Docker (skip if you have it)

- Ubuntu/Debian: `curl -fsSL https://get.docker.com | sh`
- Windows/macOS: install Docker Desktop, then use a terminal.
- Check: `docker --version`

### 3. Bring up the server

```sh
cd halo-server
curl -fsSL -O https://raw.githubusercontent.com/JoshRob297/halo-ce-server/main/docker-compose.yml
docker compose up -d
```

The image is pulled from GitHub Container Registry the first time, then
started. It is about 139 MB.

### 4. Set your name, rotation and port

Edit the config (the default is in the image; override it with your own
file):

```sh
curl -fsSL -O https://raw.githubusercontent.com/JoshRob297/halo-ce-server/main/server/config.toml
nano config.toml
```

The lines that matter:

```toml
[debug]
network_test = "host:bloodgulch:slayer,ctf;chillout:slayer,oddball;sidewinder:ctf,slayer"
network_test_time = 15        # minutes per game
network_test_countdown = 15   # lobby seconds

[network]
server_name = "My 24/7 Halo"  # shown in the server browser
tunnel_port = 2302            # the UDP port
```

Then mount it (uncomment the last line of `docker-compose.yml`):

```yaml
      # - ./config.toml:/halo/config.toml:ro
```

and restart:

```sh
docker compose down && docker compose up -d
```

### 5. Open the port (only if UPnP is off or the router has none)

```sh
# Linux, ufw
sudo ufw allow 2302/udp

# Windows, elevated prompt
netsh advfirewall firewall add rule name="Halo CE server" dir=in action=allow protocol=UDP localport=2302
```

On a router: forward UDP 2302 to the machine running the server. On a VPS:
open UDP 2302 in the cloud firewall. The game asks the router by UPnP
itself, so a home connection usually works with no manual rule.

> One UDP port per machine. Two servers on one machine need two different
> `network.tunnel_port` values (and two data folders).

### 6. Verify it works

```sh
docker compose logs -f
```

- `Invite players with this link` - your invite link (changes each start).
- `the game is listed in everyone's server browser (public)` - people can
  find it by the server name.
- `server: state 1 ..., map levels\test\bloodgulch\bloodgulch` - every five
  seconds, which game is running and how much is left.

From another PC: open your OpenCE game, Multiplayer -> Server Browser, and
look for your server name. Or send the invite link to a friend.

### 7. Update the server

```sh
docker compose pull && docker compose up -d
```

---

## The settings

The full reference is `docs/dedicated_server.md` (the project's own). The
server reads `config.toml` beside the executable (in the image: `/halo`),
writes the defaults there at first start, and a wrong key is logged and left
at its default. Every setting also has a `HALO_*` environment variable.

| Setting | Default | What it does |
| --- | --- | --- |
| `debug.null_renderer` | `false` | `true`: nothing is drawn, no window is made (the server) |
| `debug.network_test` | `""` | The map list: `"host:map:variant,variant;map:variant"` |
| `debug.network_test_time` | `0` | Minutes per game, over the gametype's own limit |
| `debug.network_test_countdown` | `0` | Lobby countdown seconds (0: the game's own, 31) |
| `debug.network_test_start` | `15.0` | Seconds the host waits before forcing the start |
| `debug.network_test_player` | `true` | `false`: the host takes no player of its own |
| `audio.enabled` | `true` | `false`: no audio device is opened |
| `network.server_name` | `""` | The name shown in the server browser |
| `network.tunnel_port` | `0` | The fixed UDP port (0: a new one each start) |
| `network.online` | `true` | Internet play (`false`: LAN only) |
| `network.host_public` | `true` | Public listing (`false`: invite-only) |
| `display.time_notices` | `true` | Chat-area notices of the time left and the countdown |

---

## Maps and game modes

The server has no menu: **the admin picks the maps and the game modes in
`config.toml`** (`debug.network_test`) and the list rotates by itself.

- **Maps**: the names the game knows (`bloodgulch`, `chillout`,
  `sidewinder`, `wizard`, `boardingaction`, ...; a Custom Edition map as
  `custom_maps\<name>`). The `.map` file must be in `maps/` or
  `custom_maps/`.
- **Game modes**, in each entry's comma list:
  - the engine's variants: `slayer`, `ctf`, `oddball`, `king`, `race`;
  - OpenCE's gametypes: `swat`, `infection`, `gun_game`,
    `hardcore_slayer`, `hardcore_ctf`, `hardcore_oddball`;
  - campaign levels in co-op: `coop`.
- **Players do not vote for the next map**: that does not exist in this
  approach (it is the port's automated host, not an admin panel). Changing
  the list is editing `config.toml` and restarting.
- If a variant asks for teams and fewer than two players are in, the server
  plays that map's first variant without teams instead, so the list never
  stands still.

---

## Who can join

| Client | Joins |
| --- | --- |
| Current official OpenCE build (network version 38) | Yes |
| Android / Windows / Linux / Web | Yes (same netcode) |
| Older clients (37 and earlier) | No - update the client |

The host never checks a client's version: the client does. Current official
clients are 38.

---

## Troubleshooting

| Symptom | Cause and fix |
| --- | --- |
| `SDL_Init failed: No available video device` | You ran the bare binary without the dummy drivers. Set `SDL_VIDEODRIVER=dummy SDL_AUDIODRIVER=dummy` (the Docker image and the systemd unit set them) |
| The server runs but no one from the internet joins | Port not open or CGNAT. Open UDP `tunnel_port`; check the router. If your ISP puts you behind CGNAT, host on a VPS |
| `the game is listed` does not appear | `network.host_public` false, or `network.online` false: the server is invite-only |
| Maps are missing / the game stops | The rotation names a map that is not in `maps/`. Copy it, or fix the list |
| The server does not stop | It ignores SIGTERM by design. `docker compose down` handles it; on bare metal `systemctl kill -s KILL halo-server` |

---

## What this is not (yet)

- Not an admin panel: no in-game map picking, no vote, no operator commands
  yet. (Players can vote-kick each other, as in the game itself.)
- Not the roadmap's native dedicated server: this is the port's automated
  host (`debug.network_test`) with the map list, countdown and name carried
  on top; the wire protocol is untouched.
- No game data is shipped. Not one Microsoft file lives here.

**Roadmap**: operator console (kick/ban/map, `sv_*` commands), text chat
announcements, cheat/anti-cheat review, and a health check endpoint. The
first release ships the solid core; the operator controls are the next
milestone.

---

## En espanol

Resumen rapido: este repositorio empaqueta un **servidor dedicado de Halo
Combat Evolved** (puerto nativo OpenCE, netcode 38) en Docker, systemd o
binario pelado. Corre 24/7 sin pantalla ni GPU. Los mapas y los modos de
juego se eligen en `config.toml` (`debug.network_test`): el server rota la
lista solo y los clientes oficiales actuales se conectan tal cual, por LAN,
enlace de invitacion o Server Browser publico.

Necesitas la carpeta `maps/` extraida de **tu propio** disco (la ISO se usa
una sola vez para extraerla; el server nunca la pide ni la distribuye).
Con Docker son dos comandos:

```sh
mkdir -p halo-server/maps && cp -r /ruta/a/tus/mapas/* halo-server/maps/
cd halo-server && docker compose up -d
```

La guia completa paso a paso, los ajustes, los modos de juego disponibles y
los problemas comunes estan en ingles arriba. Preguntas y bugs: abre un
issue en este repositorio.

---

## License

The packaging (Dockerfile, scripts, sample configs, docs) is MIT. The game
is OpenCE's; maps are the user's own.
