# Guía de Webhooks para Discord y Telegram

El servidor puede enviar alertas automáticas y eventos de partida en tiempo real a canales de **Discord** o grupos de **Telegram** de forma asíncrona y sin bloquear el ciclo de juego.

---

## 1. Configuración en `config.toml`

En la sección `[webhooks]` de `config.toml` (o mediante variables de entorno equivalentes):

```toml
[webhooks]
# URL de webhook de Discord (dejar vacío para desactivar)
discord = "https://discord.com/api/webhooks/XXXXXX/YYYYYY"

# URL de webhook de bot de Telegram o microservicio
telegram = "https://api.telegram.org/bot<TOKEN>/sendMessage?chat_id=<CHAT_ID>"
```

### Variables de Entorno equivalentes:
- `HALO_WEBHOOK_DISCORD="https://discord.com/api/webhooks/..."`
- `HALO_WEBHOOK_TELEGRAM="https://api.telegram.org/bot..."`

---

## 2. Eventos Notificados

1. **Inicio de Partida (`Match Start`):**
   - Notifica el mapa cargado, la variante o modo de juego y la cantidad de jugadores presentes.
2. **Fin de Partida y Carnage Report (`Match Finished`):**
   - Publica el ganador de la partida, el mapa completado y la puntuación final obtenida.
3. **Alertas de Moderación Disciplinaria (`Player Ban`):**
   - Informa al canal de moderación cuando un jugador es expulsado o sancionado por trampas o conducta inapropiada, indicando motivo y duración del strike.
