# Upstream Master Server Bridge & Official Dedicated Architecture

## Problema
En OpenCE Build 289, el cliente del juego dejó de mostrar servidores dedicados en la pestaña oficial DEDICATED basándose en la bandera del host, exigiendo que provengan autenticados por un Master Server oficial (`master.opencommunityedition.com`) firmado mediante claves Ed25519 (`publisher.key`). Nuestro servidor opera actualmente en modo autónomo/P2P; aunque expone métricas Prometheus, Web Dashboard y webhooks, carece del subsistema que publica hacia el master server central de OpenCE con pruebas criptográficas (`--keygen`, `--sign`).

## Alcance
- Dentro:
  - Portar e integrar `server_master.c`, `server_mode.c` y soporte `--keygen`/`--sign`.
  - Habilitar autenticación con el master server oficial (`master.opencommunityedition.com`).
  - Preservar al 100% las funciones comunitarias exclusivas: Web Dashboard embebido, Prometheus `/metrics`, webhooks Discord/Telegram, selector Campaign/Multiplayer y soporte ARM64 (Raspberry Pi 3B).
  - Unificar el hilo HTTP entre las funciones nativas y nuestros endpoints enriquecidos.
- Fuera:
  - No se reemplaza el servidor dedicado del juego en Go: el binario del juego sigue siendo C nativo (`halo`). La implementación del master server upstream en Go (`opence-master-server`) se consume como servicio de catálogo remoto vía HTTPS.

## Requisitos funcionales
- FR-1: Generación y firma de clave de publisher mediante comandos CLI `./halo --keygen` y `./halo --sign <nonce>` | criterio: genera `publisher.key` (Ed25519) de 64 bytes y calcula firmas hex verificables.
- FR-2: Publicación periódica automática al Master Server oficial vía HTTPS cada 30 segundos | criterio: `server_master.c` despacha payloads JSON firmados a `https://master.opencommunityedition.com/publish` y procesa respuestas 200 OK.
- FR-3: Preservar endpoints comunitarios `/metrics`, `/api/rotation/play` y webhooks | criterio: un cliente curl a `/metrics` retorna telemetría Prometheus con el servidor en modo master server activo.
- FR-4: Registro de región (`server.region`) en el payload del master server | criterio: el master server recibe y publica la etiqueta `"region"` para que los clientes vean `EU`, `NA`, etc.

## Requisitos no funcionales
- NFR-1: Consumo de CPU < 2% en reposo durante el ciclo de publicación HTTPS | medición: top / pidstat en Linux x86_64 y ARM64.
- NFR-2: Cero fugas de claves privadas: `publisher.key` debe guardarse con permisos `0600` y nunca exponerse en logs ni respuestas web.

## Supuestos
- El Master Server oficial de OpenCE acepta solicitudes de operadores vía su bot de Discord con el comando `/apply`.
- El puerto UDP 2302 del servidor debe ser accesible desde internet para que la sonda de reachability del master server responda con éxito.

## Preguntas abiertas
- Ninguna. Protocolo y vectores criptográficos documentados en `docs/master_protocol.md`.
