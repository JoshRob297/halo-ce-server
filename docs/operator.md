# Operator Console Guide

The dedicated server includes a local telnet administration console and the `scripts/operator.sh` management CLI for operator administration without requiring an in-game client or display.

---

## 1. Enabling the Telnet Console

The console listens on `127.0.0.1:2323` by default (local loopback only, unauthenticated).

### Configuration (`config.toml`)
In `config.toml` under `[debug]`:
```toml
[debug]
telnet_console = true
telnet_console_port = 2323
```

### Environment Variable
Alternatively, pass `HALO_TELNET_CONSOLE=1` (or `true`) at startup:
```bash
HALO_TELNET_CONSOLE=1 ./halo
```

---

## 2. Operator CLI (`scripts/operator.sh`)

`scripts/operator.sh` provides a unified CLI for controlling the dedicated server.

### Commands

| Command | Description |
| :--- | :--- |
| `operator.sh kick <name>` | Immediately disconnects a player. The player can rejoin. |
| `operator.sh ban <name>` | Drops the player, writes their IP and HWID to `bans.txt` and `cheaters.txt`, and blocks reconnection. |
| `operator.sh votekick <name>` | Triggers a host vote-kick against a player. |
| `operator.sh say <text>` | Broadcast message notice (logs warning: pending native engine chat injection hook). |
| `operator.sh status` | Reads the latest 5-second server state line from `debug.txt` and formats game status. |
| `operator.sh raw <command>` | Sends an arbitrary command or Halo Script expression directly to the console. |

## Text Chat in Public Servers

By default, text chat is disabled in games listed in the public server browser.
A dedicated server with operator moderation can enable it:

In `config.toml`:
```toml
[network]
text_chat = "on"      # on | links | off
public_chat = true    # lift the public-listing restriction
```

With `/mute <name>` (operator chat command) and `operator.sh ban <name>`,
the operator can manage disruptive players. Links are blocked unless
`text_chat = "links"`.

## Server Password (Join Gating)

The dedicated server supports password protection while remaining listed in the public server browser:

In `config.toml`:
```toml
[network]
server_password = "your_secret_password"
```

Or via environment variable:
```bash
export HALO_NET_SERVER_PASSWORD="your_secret_password"
```

### Behavior & Details
- **Empty string (`""`)**: Default. The server is public and open to anyone joining from the browser.
- **Non-empty string**: The server listing is marked as locked (`_listing_password` flag). Its lobby token is sealed with the password key using Argon2id salted with the host signing key (`p2p_seal_token`).
- **Joining**: Clients selecting the locked server in the server browser are prompted for the password (`p2p_listing_unlock`). Only clients entering the correct password can derive the key, unlock the token, and join. Direct invite links continue to work if shared.

### Environment Overrides

- `HALO_CONSOLE_HOST`: Console IP (default: `127.0.0.1`)
- `HALO_CONSOLE_PORT`: Console port (default: `2323`)
- `HALO_LOG_FILE`: Engine log file path for `status` (default: `/root/.local/share/halo-linux/debug.txt`)

### Usage Examples

```bash
# Kick a player
scripts/operator.sh kick "RedSpartan"

# Ban a player
scripts/operator.sh ban "Griefer99"

# Trigger a vote kick
scripts/operator.sh votekick "AfkPlayer"

# Check server state
scripts/operator.sh status
# Output: map: bloodgulch | variant: slayer | players: 4 | state: in_game

# Send raw Halo Script or debug commands
scripts/operator.sh raw "help kick"
```

---

## 3. Docker Usage

When running with Docker or Docker Compose, execute commands inside the container via `docker exec`:

### Enable in `docker-compose.yml`
```yaml
services:
  halo-server:
    image: ghcr.io/joshrob297/halo-ce-server:latest
    environment:
      - HALO_TELNET_CONSOLE=true
```

### Running Commands
```bash
# Check current game status
docker exec halo-server /halo/scripts/operator.sh status

# Kick a player
docker exec halo-server /halo/scripts/operator.sh kick "PlayerName"

# Ban a player
docker exec halo-server /halo/scripts/operator.sh ban "Cheater"

# Send a raw console command
docker exec halo-server /halo/scripts/operator.sh raw "game_won"
```

---

## 4. Bare-Metal Usage

When running bare-metal via systemd or background process:

```bash
# Local execution
/path/to/halo-server-pkg/scripts/operator.sh status

# Remote execution via SSH
ssh user@server '/path/to/halo-server-pkg/scripts/operator.sh kick "PlayerName"'
```

You can also connect directly using `nc` or `socat`:
```bash
printf "kick PlayerName\n" | socat -t 2 - TCP:127.0.0.1:2323
```

---

## 5. Bans and Cheaters Files

Both files are maintained alongside `debug.txt` (typically `/root/.local/share/halo-linux/` or the server execution directory).

### `bans.txt` Format
Each line records a banned entity in tab-delimited format:
```tsv
YYYY-MM-DD HH:MM:SS	ip=192.168.1.50	hwid=a1b2c3d4e5f60718	discord_username=none	discord_id=none	players=BadActor	reason=banned by the host
```

- `ip=`: Remote IPv4 address.
- `hwid=`: Sanitized 16-byte hex HMAC-SHA-256 hardware identifier (from Linux machine-id, Windows GUID, or Android ID).
- `discord_username=` / `discord_id=`: Discord identity if self-reported by client.
- `players=`: Player name reported at the time of the ban.
- `reason=`: Reason for the ban (e.g. `banned by the host` or cheater detection details).

### How to Unban
The host checks `bans.txt` on new client connections. To unban a player:
1. Open `bans.txt` in a text editor or remove the corresponding line:
   ```bash
   sed -i '/ip=192.168.1.50/d' /path/to/bans.txt
   ```
2. The change takes effect immediately for subsequent connection attempts.

### `cheaters.txt` Format and Triggers
`cheaters.txt` logs automated anti-cheat detections:
```tsv
YYYY-MM-DD HH:MM:SS	ip=192.168.1.75	hwid=f0e1d2c3b4a59687	discord_username=none	discord_id=none	players=SpeedRunner	reason=speed hack detected
```

#### What Triggers an Entry:
1. **Speed Hacks:** The server compares client tick timing against its host clock every 2 seconds. If a client runs >10% faster and >0.5 seconds ahead continuously for 10 seconds, the host automatically drops the connection, bans the IP/HWID in `bans.txt`, and logs the infraction to `cheaters.txt`.
2. **Unverified Timing Discrepancies:** If incoming datagrams are ahead of real time but cannot be confirmed via the client's TCP stream, an `unverified` entry is written to `cheaters.txt` without issuing an immediate ban to protect against packet spoofing.
3. **Manual Host Bans:** When `ban <name>` is executed by the operator, an entry is written to both `bans.txt` and `cheaters.txt`.

---

## 6. Health Check Endpoint

The server includes an HTTP health check endpoint on a dedicated TCP port (`network.health_port` in `config.toml` or `HALO_NET_HEALTH_PORT` environment variable).

### Configuration

In `config.toml`:
```toml
[network]
health_port = 8080
```

Or via environment variable:
```bash
export HALO_NET_HEALTH_PORT=8080
```

When using Docker Compose, publish the TCP port in `docker-compose.yml`:
```yaml
services:
  halo-server:
    ports:
      - "2302:2302/udp"
      - "8080:8080/tcp"
    environment:
      - HALO_NET_HEALTH_PORT=8080
```

### Endpoints

- `GET /health`: Returns HTTP 200 with JSON status payload:
  ```json
  {"status":"ok","state":"in_game","map":"bloodgulch","variant":"slayer","players":3,"max_players":16,"minutes_left":8,"listed":true,"uptime_seconds":1234}
  ```
State values: `pregame`, `in_game`, `postgame`, `no_server`.

- `HEAD /health`: the same headers with no body, for monitors that probe
  with HEAD.

- Any other path or method: HTTP 404 with `{"error":"not found"}`.

### Example Usage

```bash
curl -s http://127.0.0.1:8080/health
```

The endpoint binds `0.0.0.0` (so a container can publish it), serves no
path but `/health`, and does no authentication: publish it only where you
want it reachable, or keep the Docker port mapping off and probe from
inside the container.
