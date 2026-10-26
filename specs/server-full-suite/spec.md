# Spec: Halo Dedicated Server Complete Suite (v1.3.0)

## Problema
El servidor dedicado de Halo CE se encuentra al 82% de completitud frente a servidores dedicados de nivel de producción modernos. Faltan cuatro módulos críticos requeridos por administradores, operadores de Unraid/Docker y comunidades:
1. Imposibilidad de redirigir los logs (`debug.txt`, `debug.old.txt`) a un directorio personalizado (`HALO_LOG_DIR`), obligando a usuarios de Unraid a exponer la raíz binaria.
2. Carencia de autenticación y control de acceso basado en roles (RBAC) con login web protegido por Argon2id y sesiones seguras en el Web Dashboard.
3. Carencia de integración nativa con Discord y Telegram mediante webhooks para notificar inicios de partida, resultados (carnage reports) y sanciones.
4. Ausencia de exportador de telemetría y métricas para observabilidad con Prometheus y Grafana (`/metrics`).

## Alcance
- Dentro:
  - **Módulo 1: Log Redirection (HALO_LOG_DIR / paths.logs):** Soporte en motor C para escribir y rotar logs en cualquier ruta configurada sin tocar la raíz de datos.
  - **Módulo 2: RBAC & Web Authentication:** Pasarela de login en el Web Dashboard (`/api/login`, `/api/logout`, `/api/session`), soporte de contraseña Argon2id, tokens CSRF, cookies de sesión y permisos jerárquicos (Owner, Admin, Moderator, Viewer).
  - **Módulo 3: Event Webhooks (Discord / Telegram):** Notificaciones HTTP asíncronas para eventos de servidor: arranque de mapa, ganador/marcador final y sanciones disciplinarias.
  - **Módulo 4: Observabilidad Prometheus (/metrics):** Endpoint `/metrics` con formato OpenMetrics estándar para monitoreo en tiempo real de jugadores, tickrate, ping y estado del servidor.
- Fuera:
  - Grabación de replays de cliente (requiere modificaciones en el renderizador de cliente fuera del alcance del servidor headless).
  - Modificación del protocolo de red de juego (Netcode v38 se mantiene 100% inalterado).

## Requisitos funcionales
- FR-1 [Logs]: Si `HALO_LOG_DIR` o `paths.logs` está definido, el motor crea el directorio y escribe `debug.txt` y `debug.old.txt` allí | criterio: El archivo se crea y escribe en la ruta especificada.
- FR-2 [RBAC]: Si `server.web_password` está configurado, la Web GUI oculta controles de administración hasta iniciar sesión | criterio: Peticiones no autorizadas a `/api/command`, `/api/settings` (PUT) y `/api/rotation` (PUT/POST) retornan HTTP 401.
- FR-3 [Webhooks]: Cuando una partida finaliza o un jugador es sancionado, el despachador de webhooks envía un payload JSON al webhook de Discord o Telegram configurado | criterio: Petición HTTP POST enviada con código de respuesta 200/204.
- FR-4 [Métricas]: `GET /metrics` expone métricas en formato texto Prometheus (players, tickrate, uptime, map_info) | criterio: `curl http://...:8080/metrics` devuelve cabeceras `# HELP` y `# TYPE` conformes a la especificación OpenMetrics.

## Requisitos no funcionales
- NFR-1: Cero secretos o webhooks en logs o repositorios | verificacion: Sanitización estricta en código y commits.
- NFR-2: La autenticación no debe añadir latencia al tick de juego de 30 Hz | medicion: Verificación de hash Argon2id ejecutada en el hilo web HTTP sin bloquear el bucle principal.
- NFR-3: Memoria en reposo del servidor debe mantenerse < 120 MB en ARM64 y x86 | medicion: RSS reportado por `ps`.

## Supuestos
- Los clientes se comunican exclusivamente por Netcode v38.
- La librería mbedtls ya enlazada en el proyecto provee primitivas criptográficas para hashing y tokens.
