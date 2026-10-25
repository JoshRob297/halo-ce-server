# Operator Roadmap

What the engine already provides, what the first release ships, and what
comes next in order of impact.

---

## What the engine already has (no code needed)

These work today on a running server. They are gaps in documentation, not
in the code.

### Console commands (host only, in-game)

The in-game developer console routes everything through
`hs_compile_and_evaluate` (the original Xbox scripting engine). The port
adds three host-only commands with Tab name completion:

| Command | Effect |
| :--- | :--- |
| `kick <name>` | Drops the player's machine; all players notified; player may rejoin immediately. |
| `ban <name>` | Drops + writes `ip=` and `hwid=` to `bans.txt` and `cheaters.txt` beside `debug.txt`. Host refuses that IP/HWID on future joins while running. Remove the line to unban. |
| `votekick <name>` | Host initiates a vote (same as a player doing it from the scoreboard). |

Any Halo Script function the original Xbox build had is also available
(`game_won`, `player_enable_input`, etc.).

### Telnet console (scripted access, 127.0.0.1)

`debug.telnet_console = true` (default: `false`) opens a listener on
`127.0.0.1:2323` (port: `debug.telnet_console_port`). Everything sent to
it passes through the same `console_process_command` as the in-game
console: `kick`, `ban`, and all Halo Script. No password; local only.

This is the operator's interface today. A thin wrapper on stdin can forward
lines to it.

### Mute (host, in-game chat)

Type `/mute <name> [minutes]` or `/unmute <name>` as a chat line (host
only). Mutes text lines and voice for all machines. The scoreboard's
right-click also does this. Internally: `network_chat_host_mute()`.

### Text chat settings

`network.text_chat`:

| Value | Effect |
| :--- | :--- |
| `on` | Chat allowed, links refused. |
| `links` | Chat allowed with links. |
| `off` | Chat fully disabled. |

**Known gap**: chat is automatically off in publicly listed games
(`p2p_hosting_listed()` forces it off regardless of the setting). A
dedicated public server therefore has no text chat today. Fixing this
requires a one-line change in `chat_host_config_flags()`.

### Vote-kick (players)

Built into `network_votekick.c`. Players start a vote from the scoreboard
or with `votekick <name>` in their console. The host counts by real address
+ HWID; needs more than half the electorate and at least 2 votes.
`network.votekick_minutes` sets the play time required to start a vote
(default: 5). `network.votekick_ban_minutes` sets the in-memory ban after a
passed vote (default: 30; not written to `bans.txt`).

### Anti-cheat that runs today

| Protection | How it works |
| :--- | :--- |
| **Speed hack detection** | Host measures client tick rate vs its own clock every 2 s. >10% faster and >0.5 s ahead: predictions refused immediately. After 10 s sustained + stream confirmation: auto-kick, `cheaters.txt`, `bans.txt`. |
| **Position validation** | Impossible positions (outside map) and unauthorized teleports are corrected or rejected. Legitimate teleporters are validated against map flags. |
| **Damage range check** | Melee capped at 1.5 m; projectile damage beyond the tag's `maximum_range` is refused. |
| **Aim assist block** | `network.block_mouse_aim_assist = true` sends a policy to all clients. |
| **Corrupt datagrams** | Discarded by design; the engine never trusts malformed packets. |
| **Connection rate limit** | 6 new connections per minute per address at the server layer. |
| **Stream-only trust** | Votes and sensitive messages accepted only from the client's TCP stream, never from bare UDP datagrams. |
| **HWID sanitization** | Hardware IDs are stripped to hex before storage or comparison. |

### Voice chat

Works. `network.voice_*` settings control it. The host can mute a player's
voice for everyone (same call as text mute). Players can mute individual
machines locally from the scoreboard.

---

## Shipped: v1.0.0

- Headless Docker image (SDL dummy drivers, null renderer).
- Map and gametype rotation from `config.toml` (`debug.network_test`).
- Public server browser listing and invite link.
- Network version 38: current OpenCE clients join as-is.
- Automated lobby countdown and map progression.
- Vote-kick, bans, speed-hack detection — all inherited from the engine.

---

## Milestone 1: Operator console (stdin pipe to telnet)

**Status: Done (v1.1.0).** Telnet console verified on headless linux build and wrapper tooling shipped.

Implementation summary:
1. `scripts/operator.sh` created to interface with telnet on 127.0.0.1:2323 (`kick`, `ban`, `votekick`, `say`, `status`, `raw`). [Done]
2. Documented operator commands, Docker usage, bare-metal workflow, and ban/cheater formats in `docs/operator.md`. [Done]
3. Telnet console verified on headless linux host (`debug.telnet_console = true` / `HALO_TELNET_CONSOLE=1`). Commands like `kick <name>` execute cleanly via telnet socket. [Done]
4. Log parsing implemented for `operator.sh status` extracting map, players, and game state (`pregame`, `in_game`, `postgame`) from 5-second engine logs. [Done]
5. `say` wrapper stubbed with warning in `operator.sh`; native script hook planned for upstream chat integration. [In Progress / Upstream]

Verified: `printf "kick test\n" | socat -t 2 - TCP:127.0.0.1:2323` and `scripts/operator.sh status` tested against running server on cachy.

---

## Milestone 2: Text chat in public servers

**Status: Done (v1.2.0).** Completed in engine commit `4697c3fd14417af7bc9ebd44a67d63b2652425da`.

Implemented:
1. `chat_host_config_flags()` updated in `network_chat.c` to allow chat when `network.public_chat` is enabled (`(!p2p_hosting_listed() || config_boolean("network.public_chat"))`).
2. `network.public_chat` setting added in `port_config.c` (default: `false`, environment: `HALO_NET_PUBLIC_CHAT`).
3. Documented in `port/linux/README.md`, `server/config.toml`, and `docs/operator.md`.
4. Verified compilation with `ci_build.py linux debug` on cachy.

---

## Milestone 3: Server password (join gate)

**Status: Done (v1.3.0).** Completed in engine commit `e7172ac7edbb69dcae984f4757c2514930bebf9a`.

Implemented:
1. `network.server_password` setting added in `port_config.c` (default: `""`, environment: `HALO_NET_SERVER_PASSWORD`).
2. `network_test.c` updated during host setup to call `p2p_set_hosting_password(server_password && server_password[0] ? server_password : NULL)`.
3. When set, `p2p_lobby.c` seals the lobby invite token with Argon2id salted with the host's key, advertising `_listing_password` (`locked = 1`) in the public browser. Clients must unlock with the matching password to join.
4. Documented in `server/config.toml` and `docs/operator.md`.
5. Verified compilation with `ci_build.py linux debug` on cachy.

---

## Milestone 4: Anti-cheat audit and hardening

**Priority: high (security).** The engine already catches speed hacks,
position cheats and corrupt datagrams. The audit closes remaining gaps:

1. **Weapon reach**: the damage range check in `network_test.c` is a test
   harness function. Confirm that the same check runs in production host
   mode, or port it to `network_distributed.c`.
2. **Aimbot / no-recoil**: the host controls recoil and spread server-side
   by design (the Xbox build's authority model). Verify that a client
   cannot submit a shot that bypasses the host's spread application.
3. **Grenade count manipulation**: clients report grenade counts; the host
   should cap them at the map's spawn values.
4. **Scoreboard manipulation**: verify the host rejects score deltas it did
   not cause.
5. **HWID spoofing limit**: documented in `NETCODE.md` — a copied HWID can
   only reduce votes, never add them. Confirm no other path where a spoofed
   HWID gives an advantage.
6. Write `docs/anticheat.md` with what is enforced, what is not, and how to
   read `cheaters.txt`.

Done when: `docs/anticheat.md` exists and items 1-5 each have a finding
(confirmed OK, or a fix committed).

---

## Milestone 5: Health check endpoint

**Priority: medium (ops).** A `GET /health` HTTP endpoint that returns:

```json
{"state": "in_game", "map": "bloodgulch", "variant": "slayer", "players": 4, "listed": true}
```

Implementation: a 30-line thread in `sdl_platform.c` or a sidecar script
that parses the 5-second state log line piped to a file, served by a
one-liner Python HTTP server in the Docker image.

Done when: `curl http://localhost:8080/health` returns JSON from a running
container.

---

## Milestone 6: Windows headless verification

**Priority: low.** The CI already builds Windows. The gap is a smoke test:

1. Run the bare binary with `SDL_VIDEODRIVER=dummy SDL_AUDIODRIVER=dummy`
   on a headless Windows Server VM (or GitHub Actions `windows-latest`).
2. Confirm invite link + STUN + server browser listing appear in the log.
3. Document NSSM setup for auto-restart.

Done when: the README's Windows section has verified commands and a CI job
that builds and smoke-tests headless.

---

## Not planned

- An in-game admin GUI or web panel.
- Changing the wire protocol (clients must keep joining as-is).
- Shipping game data.
- Map voting by players (the rotation is the operator's; players
  vote-kick, not vote-map).
