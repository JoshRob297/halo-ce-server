# Halo CE Dedicated Server (OpenCE)

Servidor dedicado de Halo: Combat Evolved listo para hostear 24/7, basado en
el puerto nativo de [OpenCE](https://github.com/OpenCommunityEdition/OpenCE)
con el host dedicado encima (`dhost-v38`).

- **Sin pantalla, sin GPU y sin tarjeta de sonido**: renderer nulo, audio
  apagado. Corre en un VPS, un NUC o una Raspberry Pi x86.
- **Netcode 38**: la version actual de OpenCE; los clientes oficiales de hoy
  se conectan tal cual (LAN, enlace de invitacion o Server Browser).
- **Rotacion de mapas**: `bloodgulch:slayer,ctf;chillout:oddball;...` en el
  `config.toml`; el server vuelve al lobby solo y arranca el siguiente.
- **Listado publico**: aparece en el Server Browser de todos, o privado con
  enlace de invitacion (`halo://join/...`).

Dedicated server for Halo: Combat Evolved, ready to host 24/7, built on the
[OpenCE](https://github.com/OpenCommunityEdition/OpenCE) native port with the
dedicated host carried on top (`dhost-v38`). Headless (null renderer, no
audio), network version 38 (current OpenCE clients join as-is), map rotation
and public/private listing.

## Los mapas

El server no trae datos del juego. Copia `maps/` desde tu propio disco
(la carpeta que extrae el instalador del puerto, o la de tu instalacion de
Halo PC/Custom Edition para mapas CE en `custom_maps/`).

The server ships no game data. Bring your own `maps/` folder from your disc
(the folder the port's installer extracts; Halo PC/Custom Edition maps go in
`custom_maps/`).

## Docker (lo mas rapido)

```sh
mkdir -p halo-server/maps
cp -r /ruta/a/tus/maps/* halo-server/maps/
docker compose up -d
docker compose logs -f
```

La config por defecto esta en `server/config.toml` (nombre, rotacion, puerto).
Sobreescribela con `./config.toml` si la montas en `docker-compose.yml`.

The default config is `server/config.toml` (name, rotation, port). Override
it with your own `./config.toml` if you mount it in `docker-compose.yml`.

## Linux pelado (systemd)

```sh
sudo ./scripts/install-baremetal.sh /srv/halo
sudo cp -r /ruta/a/tus/maps/* /srv/halo/maps/
sudo systemctl enable --now halo-server
journalctl -u halo-server -f
```

El script descarga el binario de la release, instala la unidad y deja el
`config.toml` listo.

## Puertos

| Protocolo | Puerto | Para que |
| --- | --- | --- |
| UDP | 2302 | Juego e invitaciones (cambialo en `network.tunnel_port`) |

El juego pide el forwarding al router por UPnP solo; con firewall manual abre
ese puerto UDP. Es **un puerto por maquina**: dos servers en la misma maquina
necesitan `network.tunnel_port` distintos (y data roots distintos).

UDP 2302 for gameplay and invites (`network.tunnel_port`). One port per
machine: two servers on one machine need different ports and data roots.

## Config principal

`config.toml` (al lado del ejecutable, o `/halo/config.toml` en Docker):

```toml
[debug]
null_renderer = true
# rotacion de mapas: "mapa:variante,variante;mapa:variante"
network_test = "host:bloodgulch:slayer,ctf;chillout:slayer,oddball;sidewinder:ctf"
network_test_time = 15        # minutos por partida
network_test_countdown = 15   # segundos de lobby
network_test_start = 1.0
network_test_player = false   # sin jugador propio del host

[audio]
enabled = false

[network]
server_name = "My 24/7 Halo"
tunnel_port = 2302

[display]
time_notices = true
```

Todos los ajustes estan en `docs/dedicated_server.md` (el original del
proyecto). El server imprime el enlace de invitacion al arrancar.

All settings are documented in `docs/dedicated_server.md` (the project's
own). The server prints its invite link at start-up.

## Compatibilidad

| Cliente | Conecta |
| --- | --- |
| OpenCE build oficial actual (netcode 38) | Si |
| Android / Windows / Linux / Web | Si (misma netcode) |
| Versiones mas viejas (37 y anteriores) | No: actualiza el cliente |

El host nunca revisa la version del cliente: es el cliente el que decide, y
los oficiales de hoy son 38.

Current official OpenCE clients (38) join as-is. Older clients must update:
the host never checks a client's version, the client does.

## Que no es

- No es el "dedicated server" nativo del roadmap de OpenCE: es el host
  automatico del puerto (`debug.network_test`) con la lista de mapas, el
  countdown y el nombre encima, sin tocar el wire protocol.
- No trae datos del juego. No hay un solo archivo de Microsoft aqui.

## Licencia

El empaquetado (Dockerfile, scripts, configs de ejemplo) es MIT. El juego es
de OpenCE (CC0/decompilacion); los mapas son del usuario.

The packaging (Dockerfile, scripts, sample configs) is MIT. The game is
OpenCE's; maps are the user's own.
