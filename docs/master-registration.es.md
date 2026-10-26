# Guía de Registro en el Master Server

Esta guía detalla el procedimiento para registrar un servidor dedicado ante el Master Server oficial de OpenCE (`master.opencommunityedition.com`).

A partir de OpenCE Build 289, los servidores dedicados que se muestran en la pestaña oficial **DEDICATED** del explorador del juego requieren autenticación criptográfica mediante un par de claves Ed25519 registradas ante el bot oficial de verificación. Los servidores no autenticados permanecen descubribles mediante brokers de señalización P2P en el explorador general, pero no aparecerán en la categoría verificada DEDICATED sin completar este flujo de validación.

---

## 1. Generación de Claves Criptográficas (`--keygen`)

El motor OpenCE utiliza firmas asimétricas Ed25519 para verificar la identidad del servidor. Antes de solicitar el registro, genere un par de claves de publisher en la máquina anfitriona.

### Ejecución

Ejecute el binario `halo` desde el directorio de instalación del servidor utilizando el argumento `--keygen`:

```bash
./halo --keygen
```

### Gestión de Claves y Políticas de Seguridad

1. **Generación de Archivos**: El motor genera un archivo de clave de 64 bytes denominado `publisher.key` en el directorio de trabajo actual, junto con la correspondiente clave pública en formato hexadecimal.
2. **Permisos**: Configure permisos estrictos en el sistema de archivos inmediatamente para prevenir compromisos de la clave privada:
   ```bash
   chmod 600 publisher.key
   ```
3. **Directivas de OPSEC**:
   - Nunca envíe `publisher.key` a repositorios de control de versiones.
   - Nunca exponga `publisher.key` a través de directorios públicos, dashboards web o registros de contenedores.
   - Restrinja el acceso de lectura estrictamente al usuario del sistema que ejecuta el proceso del servidor.

---

## 2. Solicitud de Registro en Discord (`/apply`)

El registro del servidor se coordina a través del bot de operaciones del Master Server de OpenCE alojado en el servidor oficial de Discord.

### Procedimiento Paso a Paso

1. Únase al servidor oficial de Discord de la comunidad OpenCE.
2. Diríjase al canal `#master-server-registration` o al canal designado para interacciones con el bot.
3. Ejecute el comando de barra diagonal `/apply`:
   ```text
   /apply public_key:<CLAVE_PUBLICA_HEX> server_name:<NOMBRE_DEL_SERVIDOR>
   ```
4. El bot del Master Server valida el formato de la clave pública y emite una cadena de desafío criptográfico denominada **nonce** (una cadena hexadecimal aleatoria de alta entropía y de un solo uso).
5. Copie la cadena exacta del nonce proporcionada en la respuesta del bot. El desafío expira tras una ventana de tiempo fija (habitualmente 15 minutos).

---

## 3. Prueba Criptográfica de Posesión (`--sign`)

Para demostrar la posesión de la clave privada correspondiente a la clave pública enviada, firme el nonce de desafío mediante la CLI del motor `halo`.

### Firma del Desafío

Ejecute el binario `halo` utilizando el parámetro `--sign` seguido del nonce exacto recibido del bot:

```bash
./halo --sign "<nonce>"
```

### Salida del Comando

El binario lee `publisher.key` del directorio de trabajo, calcula la firma Ed25519 sobre el desafío y muestra la firma resultante en la salida estándar:

```text
nonce:     a8f9c1d2e3b4...
signature: 5f8a9b2c...3d1e
```

### Conclusión del Protocolo de Verificación

1. Regrese al canal de registro en Discord.
2. Envíe la prueba de firma mediante el comando de verificación indicado por el bot:
   ```text
   /verify nonce:<nonce> signature:<FIRMA_HEX>
   ```
3. Una vez validada la firma contra la clave pública registrada, el bot confirma la autorización:
   ```text
   Server identity verified. Publisher authorized for official DEDICATED listings.
   ```

---

## 4. Configuración del Servidor y Verificación en la Lista Master

Tras obtener la aprobación del registro, configure el archivo del servidor dedicado para declarar la ubicación geográfica y establecer la comunicación con el master server.

### Configuración (`server/config.toml`)

Abra `server/config.toml` (o suministre las variables de entorno equivalentes) y configure los parámetros de identidad:

```toml
[network]
online = true
host_public = true
tunnel_port = 2302

# Identificador de Región del Servidor
# Se muestra en la columna de ping/región del Server Browser.
# Opciones válidas: "eu", "na-e", "na-w", "sa", "ap-e", "ap-s", "af"
region = "eu"
```

Alternativa con variables de entorno:
```bash
export HALO_SERVER_REGION="eu"
export HALO_NET_ONLINE="true"
export HALO_NET_HOST_PUBLIC="true"
```

### Requisitos de Red

El Master Server ejecuta una prueba de conectividad activa contra el anfitrión para verificar la accesibilidad de los clientes antes de incorporar el nodo al directorio público:

- Verifique que el puerto UDP `2302` (o el configurado en `network.tunnel_port`) se encuentre abierto y redireccionado en su cortafuegos/enrutador.
- Confirme conectividad de salida hacia el puerto HTTPS `443` de `master.opencommunityedition.com`.

### Verificación de la Publicación

1. Inicie el servicio del servidor dedicado:
   ```bash
   ./halo
   ```
2. Inspeccione la salida de registro de inicio para comprobar el enlace con el master server:
   ```text
   server_master: publishing identity to master.opencommunityedition.com...
   server_master: published to master.opencommunityedition.com (200 OK)
   ```
3. Inicie el cliente de juego OpenCE (Build 289 o superior).
4. Diríjase a **Multiplayer** > **Internet**.
5. Cambie a la pestaña **DEDICATED**.
6. Confirme que su servidor aparece en el listado con el nombre configurado, capacidad de jugadores, indicadores de latencia y la etiqueta de región asignada (por ejemplo, `EU`).
