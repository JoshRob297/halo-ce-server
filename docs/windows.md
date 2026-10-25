# Windows Headless Dedicated Server Guide

This guide covers running the Halo CE (OpenCE) dedicated server headless on Windows without a display, GPU, or sound hardware.

---

## 1. What Is Verified vs Not Verified

- **Verified in CI (`windows-2025`):** The Windows binary (`halo.exe`) successfully initialises SDL headless using dummy drivers (`SDL_VIDEODRIVER=dummy SDL_AUDIODRIVER=dummy`), parses headless launch arguments, and proceeds through engine startup to the game data verification phase.
- **Not Verified in CI:** A full multi-player hosted network game is not simulated in CI because retail game maps cannot be redistributed or embedded into CI pipelines. Running full game sessions requires valid retail Xbox map files provided by the operator.

---

## 2. Obtaining Game Maps on Windows

The dedicated server requires the Xbox map files (`*.map`) extracted from a legally owned retail disc of *Halo: Combat Evolved* (Xbox).

1. **Extracting from Disc Image (ISO):**
   - Use `extract-xiso` or 7-Zip to extract the contents of your Xbox ISO.
   - Locate the `maps/` directory inside the disc image.
2. **Directory Structure:**
   Place the maps in a `maps/` folder beside `halo.exe`:
   ```text
   C:\halo\
   ├── halo.exe
   ├── SDL3.dll
   ├── config.toml
   └── maps\
       ├── ui.map
       ├── bloodgulch.map
       ├── bitmaps.map
       ├── sounds.map
       └── ...
   ```
   If Custom Edition maps are used, place them inside a `custom_maps\` folder beside `maps\`:
   ```text
   C:\halo\
   └── custom_maps\
       ├── cbeaver.map
       └── ...
   ```
   If maps reside in another location, set `paths.data` in `config.toml` to the directory containing `maps\`.

---

## 3. Running Headless by Hand

### Command Prompt (`cmd.exe`)

Open Command Prompt, set the environment variables, and start `halo.exe`:

```cmd
cd /d C:\halo
set SDL_VIDEODRIVER=dummy
set SDL_AUDIODRIVER=dummy
set HALO_NETWORK_TEST=host:bloodgulch:slayer
set HALO_EXIT_AFTER=0
halo.exe
```

### PowerShell

Open PowerShell, set the process-level environment variables, and start `halo.exe`:

```powershell
Set-Location "C:\halo"
$env:SDL_VIDEODRIVER = "dummy"
$env:SDL_AUDIODRIVER = "dummy"
$env:HALO_NETWORK_TEST = "host:bloodgulch:slayer"
$env:HALO_EXIT_AFTER = "0"
.\halo.exe
```

---

## 4. Configuration (`config.toml`)

When `halo.exe` runs for the first time, it writes default settings to `config.toml` in its working directory. Key settings for headless operation:

```toml
[paths]
# If your maps are not in C:\halo\maps, point to the folder containing maps/
data = "C:\\halo"

[network]
online = true
host_public = true
# Optional password gate
server_password = ""
# Optional health monitor port (0 = disabled)
health_port = 8099

[debug]
# Telnet operator console (local loopback)
telnet_console = true
telnet_console_port = 2323
```

---

## 5. Windows Firewall Rule

Allow inbound UDP traffic on port 2302 so clients can discover and join the server. Run in an elevated PowerShell prompt:

```powershell
New-NetFirewallRule -DisplayName "Halo CE Server" -Direction Inbound -Protocol UDP -LocalPort 2302 -Action Allow
```

If the health check endpoint is enabled and needs external access, create an inbound rule for TCP 8099:

```powershell
New-NetFirewallRule -DisplayName "Halo CE Health" -Direction Inbound -Protocol TCP -LocalPort 8099 -Action Allow
```

---

## 6. Running as a Windows Service with NSSM

To ensure the server runs continuously in the background and restarts automatically on failure or reboot, use the Non-Sucking Service Manager ([NSSM](https://nssm.cc/)).

> **Note:** The NSSM configuration below is documented according to standard Windows service specifications; it has not been directly exercised on bare-metal Windows test rigs by our automated CI.

Run the following commands from an elevated Command Prompt:

```cmd
nssm install HaloServer "C:\halo\halo.exe"
nssm set HaloServer AppDirectory "C:\halo"
nssm set HaloServer AppEnvironmentExtra SDL_VIDEODRIVER=dummy SDL_AUDIODRIVER=dummy
nssm set HaloServer AppStdout "C:\halo\server.log"
nssm set HaloServer AppStderr "C:\halo\server.err.log"
nssm set HaloServer AppStopMethodSkip 6
nssm set HaloServer AppExit Default Restart
nssm start HaloServer
```

### Understanding `AppStopMethodSkip 6`

The Halo engine loop does not process standard window closure messages (`WM_CLOSE`) or console control events (`SIGTERM` equivalents) during headless operation. Setting `AppStopMethodSkip 6` instructs NSSM to skip `WM_CLOSE` and console events, ensuring NSSM can cleanly terminate and restart the process via hard process termination when stopping or cycling the service.

Service management commands:
```cmd
nssm status HaloServer
nssm stop HaloServer
nssm restart HaloServer
nssm remove HaloServer confirm
```

---

## 7. Operator Console on Windows

The dedicated server includes an unauthenticated telnet administration console bound to `127.0.0.1:2323` when `debug.telnet_console = true`.

To connect from Windows:

### Using PowerShell or Netcat (`nc`)
PowerShell test connection:
```powershell
Test-NetConnection -ComputerName 127.0.0.1 -Port 2323
```

If `nc` (netcat) or PuTTY is installed:
```cmd
nc 127.0.0.1 2323
```

Commands supported over the telnet console:
- `kick <name>`: Disconnect a player.
- `ban <name>`: Disconnect a player and write IP/HWID to `bans.txt` and `cheaters.txt`.
- `votekick <name>`: Initiate a vote kick.
- Halo Script engine commands (`game_won`, etc.).

For complete operator documentation, see [docs/operator.md](operator.md).

---

## 8. Health Endpoint on Windows

If `network.health_port` is configured (e.g. `8099`), the server serves HTTP status snapshots. Windows 10+ includes `curl.exe` out of the box:

```cmd
curl.exe -s http://127.0.0.1:8099/health
```

Expected output:
```json
{"status":"ok","state":"pregame","map":"bloodgulch","variant":"slayer","players":1,"max_players":128,"minutes_left":0,"listed":true,"uptime_seconds":42}
```

Probe with `HEAD` for lightweight uptime monitors:
```cmd
curl.exe -I http://127.0.0.1:8099/health
```
