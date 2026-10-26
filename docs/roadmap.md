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

**Status: Done.** Comprehensive code audit completed and documented in [`docs/anticheat.md`](anticheat.md).

Audit findings across all evaluated vectors:
1. **Weapon reach & production damage**: Verified. The checks in `network_test.c` are test-harness only (`debug.network_test_shoot`), but production damage handling in `network_damage.c:2061-2295` performs strict server-side validation on every hit report (verifying recent weapon ownership `distributed_player_deals`, firing burst rate `distributed_report_paid`, reach distance `distributed_player_could_fire`, melee distance `distributed_player_was_near`, historical target window `distributed_target_seen`, and line-of-sight raycasts `distributed_report_line_of_sight`).
2. **Aimbot / no-recoil**: Recoil and spread are simulated server-side via weapon action inputs (`update_server_handle_distributed_input`). External aim assistance or memory modification in client process memory remains undetectable server-side.
3. **Grenade count & ammunition**: Verified. Inventories, carried weapons, total ammo, and grenades are 100% authoritative on the host (`network_objects.c:1602-1634`). Clients never send inventory or ammo counts to the host; they only receive host states (`network_objects.c:3008-3058`).
4. **Scoreboard manipulation**: Verified. Kills, deaths, and team scores are calculated strictly from host simulation (`network_damage.c`, `network_distributed.c:3340-3423`). Clients cannot alter scores.
5. **HWID spoofing limit**: Verified. HWID and IP are matched against `bans.txt` on connection. Spoofed HWIDs cannot grant elevated privileges or duplicate votes (`network_votekick.c`).
6. Comprehensive operator guide and protection matrix written to `docs/anticheat.md`.

No engine vulnerabilities warranting micro-patches were identified; server authority is already strictly enforced by the netcode architecture.

---

## Known Gaps

The following engine-level limitations and threat vectors are unmitigated or require external controls:

| Vector | Severity | Status / Description |
| :--- | :--- | :--- |
| **Client Memory ESP / Aimbot** | **High** | Client execution space is unverified. Players modifying client memory to snap aim or draw player bounding boxes through walls cannot be prevented server-side. Mitigated by player vote-kicks and operator bans. |
| **HWID Spoofing** | **Medium** | Client hardware IDs (`p2p_hardware_id`) derive from local OS identifiers (`/etc/machine-id`, SMBIOS). Root/admin users can spoof them. Mitigated by IP banning and server join passwords (`network.server_password`). |
| **Unverified Speed Hack on UDP** | **Low** | If clock skew is detected solely on UDP datagrams without stream confirmation, the host logs to `cheaters.txt` as unverified but does not kick to protect against source IP spoofing. |

---

## Milestone 5: Health check endpoint

**Status: Done.** Completed in engine commits `2280e45b` (the endpoint) and
`e6d69b01` (the stop race and HEAD).

Implemented:
1. Native `server_health.{c,h}` module built into the engine running an independent `SDL_Thread` listening on 0.0.0.0 on TCP port `network.health_port` (`HALO_NET_HEALTH_PORT`).
2. Publishes snapshot every frame without locking the game loop, protected by `SDL_Mutex`.
3. Handles `GET /health` with HTTP 200 JSON payload:
   ```json
   {"status":"ok","state":"pregame","map":"bloodgulch","variant":"slayer","players":1,"max_players":128,"minutes_left":0,"listed":true,"uptime_seconds":17}
   ```
4. Returns HTTP 404 for any other request path.
5. Config setting added in `port_config.c` (default `0`: disabled) and documented in `port/linux/README.md`, `server/config.toml`, `docs/operator.md`, and `docker-compose.yml`.
6. Smoke tested on headless host cachy:
   - `curl -s http://127.0.0.1:8099/health` -> `{"status":"ok","state":"pregame","map":"bloodgulch","variant":"slayer","players":1,"max_players":128,"minutes_left":0,"listed":true,"uptime_seconds":17}`
   - `curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:8099/nope` -> `404`

---

## Milestone 6: Windows headless verification

**Status: Done.** Windows headless execution verified via GitHub Actions CI and documented in [`docs/windows.md`](windows.md).

Verification details:
1. Added CI step `Headless smoke test` to the `windows` job in `.github/workflows/build.yml` running on `windows-2025`.
2. The smoke test runs `halo.exe` with `SDL_VIDEODRIVER=dummy SDL_AUDIODRIVER=dummy HALO_NETWORK_TEST="host:bloodgulch:slayer" HALO_EXIT_AFTER=10`.
3. Assertions verified in CI:
   - Dummy SDL drivers are accepted (`SDL_Init` succeeds without failure).
   - Log contains `maps folder:` check proving the binary reaches data validation without crashing.
   - Honest limit: The smoke test verifies headless engine startup and SDL initialization; it does NOT test a full game session because retail map files are not shipped in CI.
4. Windows execution, NSSM service management, firewall rules, and operator console documented in [`docs/windows.md`](windows.md).

---

## Milestone 7: Log directory redirection (QoL for Unraid / Docker)

**Status: Planned.** Allow custom redirection of `debug.txt` and `debug.old.txt` via environment variable or config setting (e.g. `HALO_LOG_DIR` or `paths.logs`), as requested by users in Issue #1.

Goals:
1. Provide a dedicated setting in `port_config.c` (`paths.logs` / `HALO_LOG_DIR`) to point the engine's log file output to a custom directory instead of strictly `d:\` (the game data root).
2. Allow Unraid and Docker users to map a dedicated `/logs` volume share without having to mount the entire `/halo` binary root directory.
3. Automatically roll `debug.txt` to `debug.old.txt` in the specified folder when reaching 64 MB.

---

## Milestone 8: Role-based access control (RBAC), user authentication & Web Login

**Status: Planned.** Native authentication system and tiered role permissions for server operations, in-game moderation, and Web Dashboard access.

Goals:
1. **Multi-Tiered Roles:**
   - **Owner:** Full system authority, configuration updates, role delegation, server shutdown/restart.
   - **Admin:** Playlist and map management (`Play Now`, rotation reordering), permanent bans, unbans, RCON access.
   - **Moderator:** Player kicks, temporary strikes/bans (up to 7 days), text chat muting, in-game warning broadcasts.
   - **Viewer:** Read-only access to live telemetry, player graphs, and scoreboard facts without administrative capabilities.
2. **Web Portal Authentication & Login:**
   - Session-based authentication via Argon2id hashed passwords (`server.web_password` and `server.web_moderator_password`).
   - Secure HttpOnly session cookies with automatic 12-hour expiration (or 30 minutes idle timeout) and CSRF protection.
   - Login interface displayed directly in the embedded Web Dashboard before granting access to sensitive controls (`/api/command`, `/api/rotation/next`, moderation actions).
3. **Audit Trail:**
   - Append-only logging of moderation actions to `control_audit.log` (timestamp, actor, target player, action taken, and reason).

---

## Not planned
- Changing the wire protocol (clients must keep joining as-is).
- Shipping retail game data.
