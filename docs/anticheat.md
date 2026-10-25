# Anti-Cheat Audit and Host Security Model

This document specifies the security and authority architecture of the OpenCE dedicated server (network version 38). It documents every protection mechanism, whether authority resides on the host or client, the exact implementation locations in source code, verified operational limits, and instructions for server operators.

---

## Executive Summary

Halo CE's distributed network model in OpenCE is hybrid: **server-authoritative simulation with client-side prediction and lag-compensated hit registration**.

1. **Damage Authority**: Damage is dealt exclusively by the host (`network_damage.c:7-8`). Clients report candidate hits (`_distributed_message_hit_reports`). The host strictly audits each report against weapon ownership, firing rate limits, line-of-sight geometry, historical trajectory, bounding spheres, and time bounds (`network_damage.c:2061-2295`). Clients cannot inflict arbitrary damage or fabricate weapon damage types they do not possess.
2. **Weapons and Inventory Authority**: All inventories, carried weapons, total ammunition, and loaded rounds are completely authoritative on the host (`network_objects.c:1602-1634`). The host sends inventory states down to clients (`_distributed_message_inventories`); clients never dictate their ammunition or grenade counts to the host.
3. **Score Authority**: Kills, deaths, team scores, and game objectives are computed solely by the host (`network_distributed.c:29, 4735-4746`).
4. **Movement and Speed Validation**: Client movement is predicted locally, but the host validates unit speed, jump velocities, and flight ceilings each tick (`network_distributed.c:2181-2299, 2429-2524`). Clock manipulation (speed hacking) is monitored over sliding 2-second windows with automatic prediction refusal and stream-verified bans (`network_distributed.c:4357-4456`).

---

## Protection Matrix

| System / Vector | Authority Model | Host Enforcement Evidence | Vulnerability / Spoof Status |
| :--- | :--- | :--- | :--- |
| **Damage Execution** | Host Authoritative | `network_damage.c:7-8, 2333-2337` | **Enforced**. Clients cannot apply direct damage; only host calls `object_cause_damage`. |
| **Hit Report Validation** | Host Audited | `network_damage.c:2061-2295` | **Enforced**. Validates weapon held, rate of fire, distance reach, LoS raycast, target history, and time bounds. |
| **Damage Reach & Range** | Host Audited | `network_damage.c:1745-1776, 2154-2160, 2204-2209` | **Enforced**. Projectile flight envelope and bounding radius checked against weapon tag limits. |
| **Line-of-Sight Check** | Host Audited | `network_damage.c:1988-2046, 2233-2248` | **Enforced**. World structure raycast (`collision_test_line`) prevents shooting through solid geometry. |
| **Weapon Firing Rates** | Host Audited | `network_damage.c:110-120, 2173-2175` | **Enforced**. Rate bucket (`HIT_REPORT_BURST_SECONDS`) caps hit frequency to tag trigger rates. |
| **Inventory & Ammo** | Host Authoritative | `network_objects.c:1602-1634, 3008-3058` | **Enforced**. Host simulates magazines and grenades; client takes host inventory. |
| **Scores & Statistics** | Host Authoritative | `network_distributed.c:29, 4735-4746` | **Enforced**. Score delta messages from clients do not exist. |
| **Speed Hack (Clock)** | Host Monitored | `network_distributed.c:4357-4456` | **Enforced**. Refuses predictions at >1.1x speed; bans at 10 s sustained stream-verified skew. |
| **Movement & Flying** | Host Clamped | `network_distributed.c:2181-2299, 2469-2504` | **Enforced**. Client positions clamped to tag biped speed, jump velocity, and fall rates. |
| **Teleportation** | Host Clamped | `network_distributed.c:2469` | **Enforced**. Delta positions > `HOST_ACCEPT_TOLERANCE` (3.0 world units) rejected. |
| **Bans & Identity** | Host Enforced | `network_distributed.c:4247-4290` | **Enforced**. IP and hardware ID checked against `bans.txt` on connection. |
| **Vote-Kick Integrity** | Host Stream-Gated | `network_distributed.c:4619-4629`, `network_votekick.c` | **Enforced**. Only accepted from reliable stream; counted by unique IP and HWID. |
| **Aimbot / Memory Injection** | Client Memory | N/A (Client Execution) | **Not Protected by Host**. Host cannot detect external memory manipulation or aim snapping. |

---

## Detailed Audit Findings

### 1. Damage Reach and Hit Report Validation

#### Test Harness vs Production Path
The distance checks in `port/linux/game/network_test.c:568-580` (`network_test_shoot`) are exclusive to the debug harness (`debug.network_test_shoot` / `HALO_NETWORK_TEST_SHOOT`) used by `tools/net_compare.py`. They never execute during normal server hosting.

However, the production damage pipeline in `port/linux/game/network_damage.c` implements comprehensive, server-side validation:
1. **Report Origin and Ownership** (`network_damage.c:2085-2090`): Host verifies that the reporting machine owns the player claimed as the damage dealer.
2. **Weapon Ownership Verification** (`network_damage.c:2118-2121`, `1262-1329`): Host inspects the player's recent weapon history (`damage_players[player].definition_indices`) within `RECENT_WEAPON_TICKS` (10 seconds / 300 ticks). If the damage effect tag does not match a weapon or projectile currently or recently held by the player, the report is rejected (`rate <= 0.0f`).
3. **Grenade Consumption** (`network_damage.c:2161-2171`, `2179-2180`): Grenade damage is accepted only if the host witnessed the player throw a grenade (`distributed_grenade_throw`) of that type within the valid time window. Once detonated, the recorded throw is consumed (`damage_players[player].throw_times[throw_index] = NONE`).
4. **Burst Rate Limiting** (`network_damage.c:2173-2175`): Weapon hit reports are metered by `distributed_report_paid` against the weapon trigger's rate of fire with a 3-second burst tolerance (`HIT_REPORT_BURST_SECONDS = 3`, `HIT_REPORT_RATE_MARGIN = 2`). Flooding hit reports beyond tag firing parameters fails validation.
5. **Melee Distance and Origin** (`network_damage.c:2184-2188`, `1675-1697`): Melee damage requires the host's historical trail of the player's unit position (`distributed_player_was_near`) within the target history buffer to be in proximity to both the impact origin and the epicenter.
6. **Vehicle Collision Verification** (`network_damage.c:2197-2201`, `1704-1737`): Damage from vehicle impact requires the host to confirm that the reporting player was driving the vehicle and that the vehicle trajectory intercepted the target within bounding sphere radii.
7. **Projectile Flight Reach** (`network_damage.c:2204-2209`, `1745-1776`): Point damage (bullets, projectiles) must lie within the reach distance (`damage_reach.distance`) calculated from tag velocity and maximum lifetime (`distributed_projectile_flight`), measured from anywhere the player has been along the historical movement trail (`damage_trails`).
8. **Target Historical Window (Lag Compensation)** (`network_damage.c:2213-2230`): Target position reported by the client is verified against the host's object history buffer (`damage_history`, 64 ticks / ~2.13 s). If the target was not near that position within `REPORT_MAXIMUM_AGE_TICKS` (30 ticks / 1.0 s), the report is rejected.
9. **Line-of-Sight Raycasting** (`network_damage.c:2233-2248`, `1988-2046`): Before applying point damage, the host traces collision rays (`collision_test_line` with `_collision_test_structure_bit`) between the shooter's historical eye positions and the target bounding sphere. If solid world geometry occludes all line-of-sight paths, the damage is discarded.

### 2. Ammunition and Grenade Authority

- **Inventory Transmission**: The host packages unit inventory state in `distributed_inventory_from_unit` (`network_objects.c:1602-1634`) and transmits it via `_distributed_message_inventories` (`network_objects.c:1783-1790`).
- **Client Handling**: Clients receive inventory packets in `network_objects_handle_inventories` (`network_objects.c:3166-3175`) and overwrite local magazine and grenade state via `distributed_client_apply_inventory` (`network_objects.c:3008-3058`).
- **No Client-to-Host Inventory Packet**: In `network_distributed.c:4617-4638`, `_distributed_message_inventories` is processed exclusively by clients (`game_connection() == _game_connection_network_client`). If a rogue client sends an inventory message to the host, it is ignored and dropped.
- **Weapon Firing**: Weapon firing is simulated on the host by feeding player input actions (`update_server_handle_distributed_input`, `network_distributed.c:2850`). Ammo is deducted server-side by weapon simulation routines.

### 3. Score and Objective Authority

- **Host Simulation**: Kill attribution and deaths are registered by the host in `network_damage.c` and recorded in `distributed_deaths` (`network_distributed.c:3340-3423`).
- **Statistics Broadcast**: Every tick or whenever statistics change, the host broadcasts `_distributed_message_player_statistics` (`network_distributed.c:3596-3671`).
- **Client Reception**: Clients update scoreboard numbers in `network_distributed.c:4735-4746`. Clients have no message type to report scores, kills, or objective captures to the host.

### 4. Movement and Speed Hack Detection

#### Speed Hack Detection Engine
Implemented in `network_distributed.c:4357-4456` (`distributed_note_client_clock`):
- **Measurement Window**: Measured over 2000 ms sliding windows (`CLIENT_CLOCK_WINDOW_MILLISECONDS = 2000`).
- **Rate Threshold**: Clock rate exceeding 1.10x real time (`CLIENT_CLOCK_FAST_RATE = 1.1f`).
- **Ahead Threshold**: Client clock more than 15 ticks (0.50 s) ahead of host time (`CLIENT_CLOCK_AHEAD_TICKS = 15`).
- **Immediate Penalty**: When both conditions are met, the machine is flagged `clock->fast = TRUE`. During this time, `distributed_machine_clock_fast(machine_index)` causes `network_distributed.c:4664` to immediately drop all incoming `_distributed_message_player_prediction` and `_distributed_message_vehicle_prediction` packets. The host simulates the player using server-side ticks only.
- **Auto-Kick / Ban Duration**: 5 consecutive fast windows (`CLIENT_CLOCK_FAST_WINDOWS = 5`, 10 seconds total).
- **Stream Confirmation**: To prevent UDP source IP spoofing from maliciously disconnecting other players, the host requires confirmation on the reliable TCP/TLS stream (`clock->ahead_on_stream = TRUE`, `network_distributed.c:4368-4369, 4399`). If fast clock ticks are observed only in UDP datagrams, the player is not dropped; an unverified warning is logged to `cheaters.txt` (`network_distributed.c:4434-4450`).

#### Movement Validation Bounds
Implemented in `network_distributed.c:2181-2299` (`distributed_on_foot_bound`) and `2429-2524` (`distributed_take_prediction`):
- **Maximum Step Distance**: Target position delta between ticks must not exceed `HOST_ACCEPT_TOLERANCE` (3.0 world units, `network_distributed.c:2469`).
- **Horizontal & Vertical Velocity**: Velocity is bounded by `run_speed`, `jump_speed`, and double-speed traits (`network_distributed.c:2251-2272`).
- **Ceiling Clamping**: Z-height is restricted by `distributed_on_foot_ceiling` (`network_distributed.c:2496-2500`). Floating or flying above legitimate jump and explosive knockback arcs is rejected.

---

## Operator Guide: Bans, Cheater Logs, and Recovery

### File Locations on Linux

The server engine references files using Xbox drive paths:
- `d:\bans.txt`
- `d:\cheaters.txt`

Under the Linux platform abstraction layer (`port/linux/src/xbox_files.c:6-17` and `port/linux/src/msvc_crt.c:578-583`), `d:\` translates to the **data root**:
1. Directory path configured by `paths.data` in `config.toml`.
2. Or current working directory if it contains a `maps/` folder.
3. In the official Docker container and server deployment layout, these files are written to the server runtime directory:
   - `/root/halo-server-pkg/server/bans.txt` (or `/app/server/bans.txt` in container volume).
   - `/root/halo-server-pkg/server/cheaters.txt`.

### File Format

Entries are written as single-line ASCII records (`network_distributed.c:4184-4228`):
```text
YYYY-MM-DD HH:MM:SS ip=<ip_address> hwid=<32_hex_chars> discord="<username>" (<discord_id>) name="<player_name>" reason="<reason>"
```

Example:
```text
2026-10-24 21:05:12 ip=198.51.100.42 hwid=a1b2c3d4e5f60718293a4b5c6d7e8f90 discord="spartan" (123456789012345678) name="MasterChief" reason="speed hack (game ran 1.45 times as fast)"
```

### Unbanning a Player

The ban list is checked upon connection in `network_distributed_banned` (`network_distributed.c:4249-4290`):
1. Open `bans.txt` in any text editor.
2. Locate the line containing the target IP or HWID.
3. Delete the line and save the file.
4. Changes take effect on subsequent connection attempts (the file is re-read on every incoming connection handshake).

### Diagnosing Network Lag and Clock False Positives

Players on unstable links, cellular connections, or behind Carrier-Grade NAT (CGNAT) may experience sudden burst packet delivery.
- **Why False Positives are Rare**: A delayed burst may cause ticks to arrive quickly, but `clock->latest_tick - game_time_get()` will not remain sustained ahead of the host clock for 10 continuous seconds. Furthermore, unverified UDP packet bursts alone never trigger an auto-kick (`network_distributed.c:4429-4435`).
- **Symptom of Real Speed Hack**: Consistent logging in `debug.txt` showing `machine #N's game runs X.XX times as fast as this host's` across 5 consecutive windows (10 s), accompanied by stream verification.
- **Symptom of Network Jitter / Packet Delivery Burst**: An isolated log entry `datagrams said its game ran X times as fast... its stream not: not dropped (unverified)`. If an operator sees unverified warnings without actual speed hack kicks, the player is experiencing bufferbloat or connection reordering, not running a cheat.

---

## Known Gaps and Unprotected Vectors

The following vectors are not protected by the dedicated server engine:

| Vector | Severity | Explanation | Mitigation |
| :--- | :--- | :--- | :--- |
| **Client-Side Aimbot / Auto-Aim** | **High** | Clients compute their own input pitch and yaw angles locally. Memory injection or aim assistance tools that lock onto player bounding boxes cannot be detected server-side. | Operator observation, player vote-kick (`votekick <player>`), and community reports. |
| **Wallhack / ESP (Entity Display)** | **High** | OpenCE sends player positions within network visibility zones to all clients for smooth local interpolation. Client memory scanners can read unit coordinates and render ESP overlays. | Fast kick/ban via operator console; player vote-kicking. |
| **HWID Spoofing** | **Medium** | The client generates its hardware ID locally (`p2p_hardware_id`). A malicious actor running with administrative privileges can modify `/etc/machine-id` or spoof SMBIOS data to generate a new HWID. | Combined IP banning + server password gating (`network.server_password`). |
| **Public Chat Forced Off Bug** | **Low** | In public listed games, text chat was historically forced off in `chat_host_config_flags`. | Resolved in Milestone 2 (`network.public_chat = true`). |

---

## Conclusion

The OpenCE dedicated server engine exhibits rigorous server authority across all gameplay-critical states: hits are raycast-verified and history-bounded, inventories and ammunition are completely host-simulated, scores cannot be modified by clients, and clock manipulations trigger automated prediction revocation and kicking.

No engine code changes are required for anti-cheat verification in Milestone 4.
