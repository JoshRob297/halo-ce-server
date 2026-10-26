# Architecture Plan: Halo Dedicated Server Complete Suite

## Arquitectura Modular

```
                           [ Motor Dedicated Server ]
                                      |
         +----------------------------+----------------------------+
         |                            |                            |
  [ xbox_files.c ]             [ server_web.c ]             [ server_webhooks.c ]
  - HALO_LOG_DIR               - /metrics (Prometheus)      - Discord Webhook
  - paths.logs                 - /api/login (Argon2id)      - Telegram Bot API
  - Rotacion a 64 MB           - RBAC (Owner/Admin/Mod)     - Eventos: Match, Carnage,
                               - Cookies HttpOnly / CSRF      Bans
```

## Decisiones de Arquitectura

### Decisión 1: Redirección de logs (`HALO_LOG_DIR`)
- **Contexto:** El motor original abre `d:\debug.txt` con la letra de unidad virtual `d:`.
- **Decisión:** Interceptar la resolución de la ruta `d:\debug.txt` en `xbox_files.c`. Si `config_string("paths.logs")` o la variable `HALO_LOG_DIR` existen, redirigir la apertura a ese directorio físico.
- **Alternativas descartadas:** Mapear enlaces simbólicos dentro del contenedor (frágil ante reinicios).

### Decisión 2: Autenticación Web y Sesiones
- **Contexto:** `app.js` ya soporta formulario de login y cookies de sesión si el backend devuelve roles y tokens CSRF.
- **Decisión:** Implementar autenticación basada en cookie `session_id` con SHA-256 HMAC / Argon2id en `server_web.c`. Si no hay contraseña configurada (`server.web_password = ""`), se mantiene el modo libre (`owner` automático) para conveniencia en redes locales.
- **Alternativas descartadas:** JWT sin estado (añade complejidad innecesaria en un servidor monoproceso en C).

### Decisión 3: Despachador de Webhooks asíncrono
- **Contexto:** Las llamadas HTTP externas a Discord o Telegram tardan entre 100 y 500 ms.
- **Decisión:** Despachar las peticiones en un hilo de trabajo en segundo plano mediante sockets TCP o libcurl/posix sockets, asegurando que el tickrate de 30 Hz del juego nunca sufra micro-tirones.

### Decisión 4: Formato del Exportador Prometheus (`/metrics`)
- **Contexto:** Administradores de infraestructura necesitan monitorizar servidores de juego mediante Grafana.
- **Decisión:** Generar las métricas directamente en memoria dentro del despachador HTTP (`server_web.c`) bajo la ruta `/metrics` con las métricas clave:
  `halo_server_uptime_seconds`, `halo_players_active`, `halo_players_max`, `halo_tickrate_hz`, `halo_match_seconds_remaining`.
