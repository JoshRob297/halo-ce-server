# Un servidor dedicado

Una copia del juego puede quedarse corriendo como host: hostea una lista de mapas por su
cuenta, arranca sus partidas, vuelve a su lobby despues de cada una, y las maquinas que se
conectan saben cuanto queda de la partida. Los jugadores entran con un enlace de
invitacion o lo encuentran en el Server Browser.

No hay un servidor central. Esto es una copia del juego manteniendo una partida abierta
para los demas: el host automatico de system link que el puerto ya trae
(`debug.network_test`, `port/linux/NETCODE.md`), con una lista de mapas.

## Plataformas

El mismo host, el mismo `config.toml` y la misma netcode, en las dos plataformas en que el
juego se compila como ejecutable de escritorio:

| Plataforma | Compilarlo | Correrlo |
| --- | --- | --- |
| Linux, x86 32-bit | `python configure.py` y `ninja linux`, o el `dist/halo-linux-release/` del CI | `./halo` |
| Windows, x86 32-bit | `ninja windows` (nativo, o `--windows-cross` desde Linux), o el `dist/halo-windows-release/` del CI | `halo.exe` |

Ambos son el mismo juego: un server arrancado en Windows y uno arrancado en Linux
sostienen las mismas partidas, aceptan los mismos clientes y leen los mismos ajustes, y un
cliente de una plataforma se conecta al server de la otra. Los nombres de los ajustes, la
sintaxis de la lista de mapas, el log y el enlace de invitacion son identicos; solo cambia
la forma en que cada sistema mantiene vivo el proceso ("Mantenerlo corriendo", abajo).

No necesita pantalla, GPU ni dispositivo de audio: el renderer es nulo y el audio esta
apagado, asi que una maquina sin display ni tarjeta de sonido lo corre tal cual. La app de
Android y el build web son clientes: la app puede hostear una partida mientras corre, pero
no tiene modo headless, y una pestana del navegador se cierra con la pagina.

## Que necesita

- Un build del juego, de la plataforma de la maquina (arriba).
- Los datos del juego: una carpeta que contenga `maps/`, como para jugar.
- Un `config.toml` al lado del ejecutable con los ajustes de abajo. El juego escribe el
  archivo con sus defaults en el primer arranque, y una clave mal escrita se escribe al log
  y se queda en su default.
- Una maquina que quede encendida, y un puerto UDP para el juego por internet: fija
  `network.tunnel_port` (2302 abajo), para que la regla del firewall y el forward del
  router lo nombren; 0 (el default) deja que el juego elija un puerto distinto en cada
  arranque. El juego pide al router que lo reenvie solo (UPnP), asi que una conexion normal
  funciona; **es un puerto por maquina**, asi que dos copias del juego no pueden hostear
  ambas juego por internet en una maquina.

## Los ajustes

El mismo archivo en ambas plataformas, en las secciones a las que pertenecen:

```toml
[debug]
# un server no tiene pantalla: nada se dibuja, no se hace ventana
null_renderer = true

# la lista de mapas que hostea, en el orden en que la juega: entradas de "mapa" o
# "mapa:variante,variante,...", ";" entre ellas, y vuelta a la primera despues de la
# ultima. Los nombres son los que muestran las listas del juego
# ("levels\test\wizard", y un mapa de Custom Edition como "custom_maps\<nombre>",
# mira docs/custom_edition_caches.md)
network_test = "host:wizard:slayer,ctf;chillout:slayer,ctf,oddball;sidewinder:ctf,slayer"

# los minutos que dura cada partida de la lista, para que una partida que nadie gana
# termine igual y la lista avance
network_test_time = 15

# los segundos que el lobby cuenta hacia el arranque de una partida. 0: el del juego,
# 31 segundos
network_test_countdown = 15

# cuanto espera el host a un countdown antes de arrancar la partida a la fuerza, cuando
# nada mas la arranca
network_test_start = 1.0

# false: el host no toma jugador propio. Sus partidas son solo de los jugadores y espera
# en su lobby al primero. true (el default) es el host del test automatico, que juega con
# jugador propio: toda maquina ve a ese jugador, y las partidas lo cuentan
network_test_player = false

[audio]
# no se abre dispositivo de audio
enabled = false

[paths]
# la raiz de datos, cuando los mapas no estan al lado del ejecutable
# data = "/srv/halo"

[network]
# el nombre que su listado muestra en el Server Browser de todos (32 bytes como mucho en
# el browser; el lobby del juego muestra 15 caracteres)
server_name = "Mi Server 24/7"

# el puerto UDP del juego por internet: uno fijo, para que la regla del firewall y el
# forward del router lo nombren (0 deja que el juego elija uno en cada arranque)
tunnel_port = 2302

[display]
# avisa a los jugadores, en la zona de chat, cuanto queda de partida y el countdown del
# lobby. Cada maquina lo calcula de las opciones de la partida y de su reloj, asi que nada
# nuevo viaja entre ellas
time_notices = true
```

Cada ajuste tiene una variable de entorno que lo sobreescribe para un arranque; estan en la
tabla de ajustes de `port/linux/README.md` (los mismos nombres en Windows) y explicados en
`port/linux/NETCODE.md`. En Windows se fijan en la shell que arranca el server, o en un
`.cmd`:

```bat
set HALO_DATA_ROOT=C:\halo
set HALO_NULL_RENDERER=1
set HALO_NO_AUDIO=1
halo.exe
```

## Como se eligen los mapas y los modos

No hay un menu en el server (no tiene pantalla): el admin los escribe en `config.toml`,
en `debug.network_test`, y la lista rota sola.

- **Mapas**: los nombres que el juego conoce (`bloodgulch`, `chillout`, `sidewinder`,
  `wizard`, y un mapa de Custom Edition como `custom_maps\<nombre>`). Los mapas tienen que
  estar en `maps/` (o `custom_maps/`).
- **Modos**: las variantes del motor por su nombre (`slayer`, `ctf`, `oddball`, `king`,
  `race`), los gametypes de OpenCE (`swat`, `infection`, `gun_game`, `hardcore_slayer`,
  `hardcore_ctf`, `hardcore_oddball`) y los niveles de campana en cooperativo (`coop`).
  Cada entrada puede llevar varias variantes separadas por comas, y el juego las juega por
  turno.
- **Los jugadores no votan ni eligen el siguiente mapa**: eso no existe en este enfoque
  (es el host automatico del puerto, no un panel de admin). Cambiar el orden o los modos
  es editar `config.toml` y reiniciar el server; un server con `network_test_player =
  false` que se queda solo vuelve al lobby y pasa al siguiente de la lista.
- Si una variante de la lista pide equipos y hay menos de dos jugadores, el server juega
  en su lugar la primera variante del mapa que no pide equipos, para que la lista no se
  quede parada.

## Correrlo

Entra al ejecutable, desde la carpeta de los datos:

```
cd /srv/halo
./halo
```

```
cd C:\halo
halo.exe
```

El juego escribe su enlace de invitacion (una linea `halo://join/<64 digitos
hexadecimales>`) al standard error al inicio de cada hosting, y loguea el resto al
standard output y a su propio log.

## Mantenerlo corriendo

**Linux**, una unidad que lo mantiene vivo y lo reinicia:

```ini
[Unit]
Description=Halo: Combat Evolved dedicated server
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=halo
WorkingDirectory=/srv/halo
Environment=HALO_DATA_ROOT=/srv/halo
Environment=HOME=/srv/halo/home
Environment=SDL_VIDEODRIVER=dummy
Environment=SDL_AUDIODRIVER=dummy
ExecStart=/srv/halo/halo
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
```

**Windows**, en una consola que quede abierta (minimizada alcanza), o como servicio con un
wrapper como NSSM, o una tarea del Task Scheduler iniciada al logon con "Do not stop the
task if it runs longer than" desmarcado. El ejecutable tiene los mismos ajustes y el mismo
renderer nulo, asi que no muestra nada.

En ambos, evita que la maquina se duerma (Linux: `systemd-inhibit` o enmascara
`sleep.target`; Windows: suspension "nunca" del plan de energia, solo para la cuenta del
server).

## Abrir el puerto

```
# Linux (ufw)
ufw allow 2302/udp

# Windows (prompt elevado)
netsh advfirewall firewall add rule name="Halo CE server" dir=in action=allow protocol=UDP localport=2302
```

## Que hace, y que esperar

- **Se lista** en el Server Browser de todos bajo `network.server_name`, e imprime su
  enlace de invitacion, que cambia en cada arranque.
- **Espera en su lobby** al primer jugador, con la siguiente entrada de su lista elegida y
  pre-cargada. El countdown arranca cuando hay un jugador (uno solo alcanza), y la partida
  comienza exactamente cuando el countdown llega a cero.
- **Cada partida termina y la lista avanza**, la termine el marcador, el limite de tiempo
  o la salida del ultimo jugador. Una partida cuyos jugadores se fueron se cierra quince
  segundos despues del ultimo (una gracia: una conexion que vuelve dentro de ellos
  conserva la partida), y una variante de la lista que pide equipos, con menos de dos
  jugadores, se juega como la primera variante del mapa que no pide equipos.
- **Conserva su listado** mientras opera, y vuelve a su lobby despues de cada partida en
  lugar de soltar la que sostiene.
- **Un operador puede vigilarlo** sin pantalla: su estado, y cuanto queda de la partida
  que corre, van al log cada cinco segundos, junto con las razones por las que un
  countdown no corre, las maquinas que entran y salen, y los mensajes entre ellas
  (`debug.txt`, el log del motor, y el standard output).

```
server: state 1 (pregame 0, ingame 1, postgame 2), map levels\test\wizard\wizard,
14 of 15 minutes left after 61 s, countdown active, 0 ms left;
machines 1, a player on each 1, teams 1, players 2 of 1, all pre-cached 1
```

## Quien puede entrar

Un cliente se conecta a un host cuya version de red esta en su rango
(`HALO_PORT_NETWORK_VERSION_MINIMUM` a `HALO_PORT_NETWORK_VERSION_MAXIMUM`): la suya, y
las que difieren de ella solo en lo que la otra maquina descarta. En este build el rango
es 38 a secas, asi que un cliente de 38 entra y uno de otra version no
(`port/linux/NETCODE.md`, "Versions"). El rango es del cliente: un host nunca revisa la
version de un cliente, y un cliente viejo que solo conoce su propia version rechaza un
host mas nuevo hasta actualizarse. Una maquina que entra a mitad de partida la juega desde
donde esta, y una que entra al lobby cuenta para la siguiente.

## Notas

- Los ajustes de arriba pertenecen al host automatico de system link. Con sus defaults
  (sin lista de mapas, sin avisos, el jugador propio del test) nada de esto opera y un
  host que arman los menus es el que el juego siempre tuvo.
- Un host por maquina: el puerto del juego por internet es uno, y tambien la copia del
  juego que abren los enlaces `halo://`.
- Las partidas son las del juego: un host dedicado no cambia lo que un mapa o un gametype
  hace, solo cual viene despues.
