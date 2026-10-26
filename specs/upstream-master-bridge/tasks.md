# Tareas de Implementación: Master Server Bridge

- [ ] T-001 [FR-1] Portar `server_mode.c` y los comandos CLI `--keygen` y `--sign` a la base de código.
      toca: `port/linux/src/server_mode.c`, `port/linux/src/server_mode.h`, `source/main/main.c`
      done: `./halo --keygen` genera `publisher.key` y `./halo --sign "test"` produce una firma Ed25519 en hex.
      verify: `build/linux/halo --keygen && build/linux/halo --sign "test"`

- [ ] T-002 [FR-2] Portar `server_master.c` y `master_list.c` para el ciclo de publicación periódica HTTPS hacia `master.opencommunityedition.com`.
      toca: `port/linux/src/server_master.c`, `port/linux/src/server_master.h`, `port/linux/src/posix_server.c`
      done: El servidor despacha periódicamente el JSON de estado firmado al master server oficial.
      verify: Verificación en log con mensaje `server_master: published to master.opencommunityedition.com (200 OK)`.

- [ ] T-003 [FR-3] Preservar e integrar `/metrics` Prometheus y webhooks dentro del despachador HTTP unificado.
      toca: `port/linux/game/server_web.c`, `port/linux/src/server_http.c`
      done: `curl -s http://localhost:8080/metrics` responde con datos válidos de jugadores y tickrate.
      verify: `curl -s http://localhost:8080/metrics | grep halo_players_active`

- [x] T-004 [FR-4] Probar empaquetado multi-arquitectura y documentar el proceso de registro ante el bot oficial de Discord (`/apply`).
      toca: `README.md`, `README.es.md`, `docs/master-registration.md`
      done: Documentación 1:1 explicando cómo generar la clave, pedir la autorización y activar la región.
      verify: `test -f docs/master-registration.md && grep -q "keygen" docs/master-registration.md`
