# Roadmap

What the release ships, and what comes next in order.

## Shipped (v1.0.0)

- The OpenCE port with the dedicated host (`dhost-v38`, network version 38).
- Map rotation, lobby countdown, time limit, server name, public/private
  listing, time notices.
- Docker image, `docker-compose.yml`, systemd unit, bare-metal install
  script, portable Linux binary.

## Next, in order

### 1. Operator controls (`sv_*` console)

Today the operator watches the log; they cannot act. The goal is a console
that reads commands from stdin (and, later, a small HTTP endpoint):

- `sv_map <map>[:variant]` / `sv_map_next` - switch the map now or after the
  game.
- `sv_kick <player>`, `sv_ban <player>` - the game already has kick/ban
  (`network_game_server_kick_machine`, `bans.txt`); wire them to commands.
- `sv_say <text>` - a message to every player.
- `sv_status` - who is in, what map, how much is left.

The engine has a telnet console for scripts (`debug.telnet_console`,
127.0.0.1); the dedicated host can reuse it or read stdin, both without
touching the wire protocol.

### 2. Text chat and voice

The game has both already (`network.text_chat`, `network.voice_*`). Two
gaps to close:

- Upstream disables text chat in games listed in the server browser; a
  public server's operator should be able to allow it and to post their own
  lines (`sv_say` above).
- Voice works as the host's settings say; document what each mode does for
  a public server and pick sane defaults.

### 3. Anti-cheat review

The base already carries several protections; the milestone is to audit
them, close the gaps and document them:

- The old fork carried "kick speed hacks and add bans" (movement beyond the
  game's limits, on the host's authority).
- `network_block_mouse_aim_assist` lets the host block aim assist.
- Vote-kick and bans exist in the game (`network.votekick_*`, `bans.txt`).
- The netcode already survives corrupted datagrams by design
  (`debug.network_corrupt` tests); review what a malicious client can still
  send that the host should refuse.

### 4. Health check

A tiny HTTP endpoint (`GET /health` -> `{state, map, players}`) so a
monitoring system knows the server is alive and listed, without reading
logs.

### 5. Windows headless verification

The code and CI build Windows; the headless run without a display has not
been tested by us. Verify NSSM + dummy drivers, then document it.

## Not planned

- An in-game admin GUI: the goal is a console, not a panel.
- Changing the wire protocol: clients must keep joining as-is.
- Shipping game data: never.
