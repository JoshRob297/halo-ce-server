# Guía de Observabilidad y Métricas Prometheus (`/metrics`)

El Servidor Dedicado de Halo CE incluye un exportador nativo de métricas compatible con el formato estándar de **Prometheus** y **OpenMetrics**. No requiere agentes intermediarios ni Node Exporters adicionales.

---

## 1. Endpoint y Formato

- **Ruta:** `GET http://<ip-servidor>:8080/metrics`
- **Content-Type:** `text/plain; version=0.0.4; charset=utf-8`

### Ejemplo de Salida:
```text
# HELP halo_server_info Information about the dedicated server
# TYPE halo_server_info gauge
halo_server_info{version="1.2.2",netcode="38",map="beavercreek",gametype="gun_game"} 1
# HELP halo_players_active Number of active connected players
# TYPE halo_players_active gauge
halo_players_active 4
# HELP halo_players_max Maximum player capacity of the server
# TYPE halo_players_max gauge
halo_players_max 16
# HELP halo_match_minutes_remaining Remaining match duration in minutes
# TYPE halo_match_minutes_remaining gauge
halo_match_minutes_remaining 12
# HELP halo_server_tickrate_hz Target server simulation tickrate
# TYPE halo_server_tickrate_hz gauge
halo_server_tickrate_hz 30.0
```

---

## 2. Configuración en `prometheus.yml`

Para recopilar automáticamente los datos del servidor cada 15 segundos en tu instancia de Prometheus:

```yaml
scrape_configs:
  - job_name: 'halo_dedicated_server'
    scrape_interval: 15s
    static_configs:
      - targets: ['192.168.1.17:8080']
        labels:
          environment: 'production'
          server_name: 'JOCES 24/7 CUSTOM'
```

---

## 3. Consultas Útiles para Tableros de Grafana

- **Jugadores conectados en tiempo real:**
  ```promql
  halo_players_active
  ```
- **Porcentaje de ocupación del servidor:**
  ```promql
  (halo_players_active / halo_players_max) * 100
  ```
- **Estabilidad del tickrate del juego:**
  ```promql
  halo_server_tickrate_hz
  ```
