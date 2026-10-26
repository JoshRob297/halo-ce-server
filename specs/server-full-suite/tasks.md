# Tasks: Halo Dedicated Server Complete Suite

- [ ] T-001 [FR-1] Implementar redirección de logs (`HALO_LOG_DIR` / `paths.logs`) en `xbox_files.c` y `port_config.c`
      toca: port/linux/src/xbox_files.c, port/linux/src/port_config.c, source/cseries/errors.c
      done: debug.txt se escribe en el directorio indicado por HALO_LOG_DIR
      verify: HALO_LOG_DIR=/tmp/test_logs ./build/linux/halo --version && test -f /tmp/test_logs/debug.txt

- [ ] T-002 [FR-4] Implementar exportador de métricas Prometheus en `server_web.c` (`/metrics`)
      toca: port/linux/game/server_web.c
      done: GET /metrics devuelve formato OpenMetrics válido con cabeceras y tipos
      verify: curl -s http://127.0.0.1:8080/metrics | grep "halo_players_active"

- [ ] T-003 [FR-2] Implementar pasarela de autenticación RBAC y sesiones seguras en `server_web.c`
      toca: port/linux/game/server_web.c, port/assets/server_ui/app.js
      done: Login con POST /api/login valida contraseña y emite cookie de sesión; endpoints sensibles protegidos
      verify: curl -s -X POST http://127.0.0.1:8080/api/login -d '{"password":"test"}'

- [ ] T-004 [FR-3] Implementar despachador asíncrono de webhooks para Discord y Telegram
      toca: port/linux/game/server_webhooks.c, port/linux/game/server_webhooks.h, port/linux/src/port_config.c
      done: Enviar notificación al inicio y fin de partida cuando webhook esté configurado
      verify: gcc -fsyntax-only port/linux/game/server_webhooks.c

- [ ] T-005 Compilar binario en nodo cachy, desplegar en LXC 106 y verificar estabilidad
      toca: build/linux/halo, LXC 106
      done: Servidor 24/7 en LXC 106 actualizado y corriendo con las nuevas capacidades
      verify: curl -s http://192.168.1.17:8080/metrics

- [ ] T-006 Actualizar documentación completa (`README.md`, `README.es.md`, `docs/webhooks.md`, `docs/metrics.md`)
      toca: README.md, README.es.md, docs/webhooks.md, docs/metrics.md
      done: Toda la suite documentada con ejemplos claros en inglés y español
      verify: git status -s
