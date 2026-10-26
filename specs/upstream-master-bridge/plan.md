# Plan de Arquitectura: Integración con Master Server Oficial (v1.4.0)

## Aclaración sobre C vs Go
- **El Servidor de Juego Dedicado (OpenCE)**: Tanto en nuestra versión como en la oficial upstream, el servidor de juego **está 100% escrito en C** (`halo`). Maneja la física del motor de Halo CE original, mapas, colisiones, render nulo, red UDP y el servidor web HTTP embebido.
- **El Master Server Remoto (`opence-master-server`)**: Es un servicio de backend independiente que corre en la nube de OpenCE (`master.opencommunityedition.com`) escrito en **Go**. Actúa como directorio central/catálogo global. Los servidores dedicados en C se comunican con él vía peticiones HTTPS POST firmadas con Ed25519.

## Decisiones de Arquitectura

1. **Contexto**: Upstream introdujo `port/linux/src/server_master.c`, `server_mode.c` y `server_http.c`. Nuestra versión contiene un despachador HTTP optimizado (`server_web.c`) que añade `/metrics`, webhooks y persistencia `PUT /api/settings`.
2. **Decisión**: Integrar el despachador de publicación de `server_master.c` y la lógica de argumentos CLI (`--server`, `--keygen`, `--sign`) dentro de nuestra base de código, inyectando los endpoints comunitarios (`/metrics`, webhooks) en el servidor HTTP sin reemplazar los endpoints REST requeridos por `app.js`.
3. **Alternativas descartadas**:
   - Reemplazar completamente nuestro `server_web.c` por `server_http.c` de upstream: Descartado porque perderíamos el exportador `/metrics` de Prometheus, los webhooks y la adaptación para Raspberry Pi 3B.
   - Forzar a los clientes a usar listas no oficiales: Descartado porque aísla a la comunidad de los jugadores que usan clientes vanilla de OpenCE Build 289+.
4. **Consecuencias**:
   - Se mantiene la compatibilidad con ARM64 / x86_64.
   - El operador obtiene su clave de publisher ejecutando `./halo --keygen` y puede registrarla ante el bot oficial de OpenCE con `./halo --sign <nonce>`.

## Riesgos y Mitigación
- **Riesgo**: Que el Master Server oficial tarde en autorizar la clave vía Discord.
  - *Mitigación*: Mantener el modo híbrido (`_listing_dedicated` en brokers P2P) para que el servidor siga siendo descubrible de inmediato en el Server Browser mientras se completa la verificación manual.
