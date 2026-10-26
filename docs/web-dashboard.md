# Web Dashboard & REST API Guide

The Halo CE Dedicated Server embeds a zero-dependency, low-latency web management portal directly compiled into the C binary. It operates over standard HTTP without requiring Node.js, Python, PHP, or external web servers (Nginx/Apache).

---

## 1. Overview & Architecture

- **Port:** Configured via `network.health_port` (default: `8080`).
- **Fully Optional:** Setting `network.health_port = 0` in `config.toml` disables the HTTP listener completely with zero performance impact.
- **Frontend Stack:** Vanilla HTML5, modern CSS3 (responsive grid and dark theme), and pure ECMAScript (no npm or external CDN dependencies).
- **Embedded Assets:** All frontend files (`index.html`, `app.css`, `app.js`, `icon.svg`) are baked into the binary as read-only memory arrays.
- **Concurrency & Safety:** The HTTP dispatcher runs on an independent POSIX background thread (`server_health.c`). Telemetry reads acquire an internal mutex snapshot to avoid stalling the 30 Hz game tick loop.

---

## 2. Dashboard Modules & Tabs

### 1. Status Tab (`/`)
<p align="center">
  <img src="screenshots/dashboard_status.png" alt="Status Dashboard" width="800">
</p>

Provides real-time telemetry updated every 2 seconds via live polling:
- **Server Health Facts:** Server uptime, active player count, maximum capacity, tickrate, memory consumption, and host link status.
- **Current Game State:** Active map name, mission title, gametype ruleset, and match elapsed time.
- **Live Scoreboard:** Real-time kill count, deaths, scores, ping, and team assignments for all connected players.
- **Player History Graph:** Interactive SVG timeline tracking connected player density over the trailing 10 minutes.

### 2. Rotation Tab (`#rotation`)
<p align="center">
  <img src="screenshots/dashboard_rotation.png" alt="Rotation Manager" width="450">
</p>

Allows full control over the map and gametype playlist cycle:
- **Active Playlist:** Displays the planned match sequence with reordering controls (`Up`, `Down`, `Remove`).
- **Instant Skip / Switch (`Play Now`):** Immediately advances the server to the selected map/mode combination without restarting the daemon.
- **Add Combination:** Interactive dropdown selector listing:
  - All 13 multiplayer maps (`beavercreek`, `bloodgulch`, `wizard`, etc.).
  - All 10 campaign co-op missions (`a10` Pillar of Autumn through `d40` The Maw).
  - All standard and custom gametypes (`slayer`, `ctf`, `oddball`, `king`, `race`, `swat`, `infection`, `gun_game`, `hardcore_*`, and `coop`).

### 3. Settings Tab (`#settings`)
<p align="center">
  <img src="screenshots/dashboard_settings.png" alt="Settings Editor" width="450">
</p>

Visual configuration editor mapping directly to parameters:
- `network.server_name`: Server title displayed in the Master Browser.
- `network.tunnel_port`: Primary UDP game listening port (default: 2302).
- `network.map_rotation`: Mode sequence order (`sequence` or `shuffle`).
- `network.map_voting`: In-lobby chat voting toggle.
- `network.afk_timeout`: Automatic idle kick timer in seconds.
- `network.map_share` & `network.map_share_upload`: BitTorrent P2P map distribution toggles and bandwidth rate limiter.
- `network.coop_enemies_mode` & `network.coop_pickups`: Campaign co-op scaling algorithms (`per_player`, `none`, `multiplier`).
- `bots.count`: Number of active AI multiplayer bots (0 to 16).

### 4. Interactive Web Console / RCON (`#console`)
A browser-based terminal connected directly to the engine's Halo Script compiler and command parser. Supports executing any command supported by `operator.sh` or the internal telnet interface (`help`, `status`, `sv_map`, `kick <player>`, `ban <player>`, etc.).

---

## 3. REST API Specification

All endpoints return JSON responses with an `"ok": true|false` status field.

### `GET /api/status`
Returns comprehensive live server state and scoreboard facts.

**Sample Response:**
```json
{
  "ok": true,
  "name": "JOCES 24/7 CUSTOM",
  "state": "ingame",
  "map": "beavercreek",
  "title": "Battle Creek",
  "gametype": "gun_game",
  "time": "04:32",
  "time_limit": 15,
  "players": 4,
  "max_players": 16,
  "history": [0, 0, 1, 2, 2, 3, 4, 4, 4, 4],
  "scoreboard": [
    {"index": 0, "name": "MasterChief", "team": 0, "score": 12, "kills": 12, "deaths": 4, "ping": 18},
    {"index": 1, "name": "Arbiter", "team": 1, "score": 9, "kills": 9, "deaths": 6, "ping": 25}
  ]
}
```

### `GET /api/maps`
Lists all available multiplayer and campaign levels supported by the server engine.

### `GET /api/gametypes`
Lists all built-in multiplayer variants (`slayer`, `swat`, `infection`, `gun_game`, etc.) and campaign `coop`.

### `GET /api/settings`
Returns an array of typed configuration parameters with metadata, current values, types, and allowed options.

### `POST /api/rotation/next`
Advances the server to the next scheduled match in the playlist.

### `POST /api/command`
Executes a console command or Halo Script expression.

**Request Payload:**
```json
{
  "line": "kick \"Griefer\""
}
```

**Response:**
```json
{
  "ok": true,
  "lines": ["player Griefer kicked"]
}
```

---

## 4. Security & Network Configuration

1. **Local Access vs LAN Access:**
   - In standard bare-metal deployments, ensure port `8080` (TCP) is allowed through `nftables`, `ufw`, or `firewalld`:
     ```bash
     sudo ufw allow 8080/tcp
     ```
2. **Reverse Proxy & HTTPS (Recommended for Public Internet Access):**
   - For secure remote access across public networks, place the dashboard behind an Nginx or Caddy reverse proxy with SSL termination and basic authentication:
   ```nginx
   server {
       listen 443 ssl http2;
       server_name halo-admin.example.com;

       ssl_certificate /etc/letsencrypt/live/example.com/fullchain.pem;
       ssl_certificate_key /etc/letsencrypt/live/example.com/privkey.pem;

       auth_basic "Restricted Access";
       auth_basic_user_file /etc/nginx/.htpasswd;

       location / {
           proxy_pass http://127.0.0.1:8080;
           proxy_set_header Host $host;
           proxy_set_header X-Real-IP $remote_addr;
       }
   }
   ```
