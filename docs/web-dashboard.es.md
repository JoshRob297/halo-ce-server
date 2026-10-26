# Guía del Dashboard Web y API REST

El Servidor Dedicado de Halo CE incluye un portal web de administración embebido en C sin dependencias externas. Se ejecuta directamente desde el binario del juego mediante HTTP estándar, sin requerir Node.js, Python, PHP ni servidores web externos (Nginx/Apache).

---

## 1. Arquitectura y Características

- **Puerto:** Configurado con `network.health_port` (por defecto: `8080`).
- **100% Opcional:** Fijar `network.health_port = 0` en `config.toml` desactiva por completo el socket HTTP con impacto cero en el rendimiento.
- **Frontend Ligero:** HTML5 semántico, CSS3 moderno (tema oscuro y diseño adaptativo) y JavaScript nativo puro sin librerías ni CDNs externos.
- **Assets Embebidos:** Todos los archivos de interfaz (`index.html`, `app.css`, `app.js`, `icon.svg`) están compilados en la memoria del ejecutable como matrices constantes.
- **Seguridad en Concurrencia:** El despachador HTTP corre en un hilo independiente POSIX (`server_health.c`). Las lecturas de telemetría obtienen un snapshot protegido por mutex para no retrasar el ciclo de juego de 30 Hz.

---

## 2. Módulos y Pestañas del Dashboard

### 1. Pestaña Status (`/`)
<p align="center">
  <img src="screenshots/dashboard_status.png" alt="Dashboard Status" width="800">
</p>

Telemetría en tiempo real actualizada cada 2 segundos por sondeo activo:
- **Telemetría del Servidor:** Tiempo de actividad (uptime), jugadores conectados, capacidad máxima, tickrate y consumo de memoria.
- **Estado de Partida:** Mapa en curso, título de misión, modo de juego activo y tiempo transcurrido.
- **Marcador en Vivo:** Bajas (kills), muertes, puntuación individual, ping y equipo de cada jugador.
- **Gráfica Histórica de Jugadores:** Gráfica interactiva SVG con la fluctuación de jugadores durante los últimos 10 minutos.

### 2. Pestaña Rotation (`#rotation`)
<p align="center">
  <img src="screenshots/dashboard_rotation.png" alt="Gestor de Rotación" width="450">
</p>

Administración completa de la lista de reproducción:
- **Lista Activa:** Visualiza la secuencia programada con botones de reordenamiento (`Up`, `Down`, `Remove`).
- **Salto Inmediato (`Play Now`):** Cambia inmediatamente la partida en curso al mapa y modo seleccionado sin reiniciar el servidor.
- **Agregar Combinación:** Selector interactivo que incluye:
  - Los 13 mapas multijugador clásicos (`beavercreek`, `bloodgulch`, `wizard`, etc.).
  - Las 10 misiones de campaña cooperativa (`a10` Pillar of Autumn hasta `d40` The Maw).
  - Todos los modos de juego estándar y custom (`slayer`, `ctf`, `oddball`, `king`, `race`, `swat`, `infection`, `gun_game`, `hardcore_*` y `coop`).

### 3. Pestaña Settings (`#settings`)
<p align="center">
  <img src="screenshots/dashboard_settings.png" alt="Editor de Ajustes" width="450">
</p>

Editor visual de variables de configuración con guardado en caliente:
- `network.server_name`: Nombre visible en el buscador público oficial.
- `network.tunnel_port`: Puerto UDP de juego (por defecto: 2302).
- `network.map_rotation`: Orden de reproducción (`sequence` o `shuffle`).
- `network.map_voting`: Votación por chat en el lobby.
- `network.afk_timeout`: Tiempo de inactividad antes de auto-kick en segundos.
- `network.map_share` y `network.map_share_upload`: Distribución P2P BitTorrent de mapas custom y límite de subida en KB/s.
- `network.coop_enemies_mode` y `network.coop_pickups`: Algoritmos de escalado en campaña (`per_player`, `none`, `multiplier`).
- `bots.count`: Cantidad de bots IA multijugador activos (0 a 16).

### 4. Consola Web / RCON Interactiva (`#console`)
Terminal interactiva conectada al compilador Halo Script y despachador de comandos del motor. Permite ejecutar cualquier instrucción soportada por `operator.sh` (`status`, `kick <jugador>`, `ban <jugador>`, `sv_map`, etc.).

---

## 3. Especificación de la API REST

Todos los endpoints devuelven respuestas en formato JSON con el campo `"ok": true|false`.

### `GET /api/status`
Devuelve el estado completo del servidor, telemetría y marcador en vivo.

### `GET /api/maps`
Lista todos los mapas multijugador y niveles de campaña soportados.

### `GET /api/gametypes`
Lista las variantes de juego integradas y el modo `coop`.

### `GET /api/settings`
Devuelve el arreglo de parámetros tipados con valores actuales, tipos de dato y opciones válidas.

### `POST /api/rotation/next`
Avanza de inmediato a la siguiente partida programada en la rotación.

### `POST /api/command`
Ejecuta un comando de consola o expresión de Halo Script.

**Cuerpo de la Petición:**
```json
{
  "line": "kick \"Griefer\""
}
```

---

## 4. Configuración de Red y Seguridad

1. **Acceso Local y en LAN:**
   - En despliegues bare-metal, abre el puerto TCP `8080` en tu firewall:
     ```bash
     # UFW (Ubuntu / Debian)
     sudo ufw allow 8080/tcp
     ```
2. **Proxy Inverso con HTTPS (Recomendado para Internet Público):**
   - Para exponer el dashboard fuera de la red local, se recomienda utilizar Nginx o Caddy como proxy inverso con certificado SSL y autenticación HTTP básica (Basic Auth):
   ```nginx
   server {
       listen 443 ssl http2;
       server_name halo-admin.tudominio.com;

       ssl_certificate /etc/letsencrypt/live/tudominio.com/fullchain.pem;
       ssl_certificate_key /etc/letsencrypt/live/tudominio.com/privkey.pem;

       auth_basic "Acceso Restringido";
       auth_basic_user_file /etc/nginx/.htpasswd;

       location / {
           proxy_pass http://127.0.0.1:8080;
           proxy_set_header Host $host;
           proxy_set_header X-Real-IP $remote_addr;
       }
   }
   ```
