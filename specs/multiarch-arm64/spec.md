# Multi-Architecture Support: Linux ARM64 (Raspberry Pi 3B / Oracle Cloud) & x86_64

## Problema
El servidor dedicado de Halo CE actual (`halo-ce-server`) se compila exclusivamente como binario de 32 bits i686 (`--target=i686-linux-gnu`). Esto presenta dos limitaciones críticas:
1. En placas de desarrollo como **Raspberry Pi 3B / 4 / 5** y servidores cloud ARMv8 (Oracle Cloud Ampere A1, AWS Graviton), no se puede ejecutar de forma nativa sin recurrir a emuladores (como Box86).
2. En distribuciones Linux de 64 bits modernas (Debian 12, Ubuntu 24.04, Alpine), requiere instalar paquetes multilib/i386 de 32 bits (`libc6:i386`), aumentando el tamaño y complejidad del despliegue Docker y bare-metal.

## Alcance
- Dentro:
  - Generación de binario nativo Linux ARM64 (`aarch64-linux-gnu`) probado para Raspberry Pi 3B/4/5 y Oracle Cloud ARM.
  - Generación de binario nativo Linux x86_64 (`x86_64-linux-gnu`) sin dependencias de librerías multilib i386.
  - Mantenimiento del binario actual i686 (`linux-x86`) para máxima compatibilidad con equipos antiguos.
  - Compatibilidad estricta con Netcode v38 (mismo hash, tickrate de 30Hz, desalineación cero en structs de red).
  - Publicación multi-arquitectura en GitHub Actions CI (`docker buildx` para `linux/amd64` y `linux/arm64`).
- Fuera:
  - Puertos gráficos OpenGL de 64 bits para clientes de escritorio (este spec cubre exclusivamente el servidor dedicado headless).
  - Sistemas de 16 bits o arquitecturas no-ARM/x86 (MIPS, RISC-V).

## Requisitos funcionales
- FR-1: El servidor debe compilar y enlazar como ejecutable nativo ELF AArch64 (`aarch64-linux-gnu`) sin warnings fatales | criterio: `file build/linux-arm64/halo` reporta `ELF 64-bit LSB executable, ARM aarch64`.
- FR-2: El servidor debe arrancar en modo headless (`null_renderer = true`) en un host ARM64 (o QEMU aarch64) y escuchar correctamente en el puerto UDP 2302 y HTTP 8080 | criterio: Respuesta HTTP 200 en `/api/settings` y socket UDP 2302 en estado listening.
- FR-3: El layout de memoria de las estructuras del juego y de los paquetes de red Netcode v38 en ARM64 y x86_64 debe ser idéntico al de i686 | criterio: Ninguna discrepancia de alineación en structs de red y tags (`assert(sizeof(...) == ...)`); los clientes oficiales v38 se conectan sin errores de protocolo.
- FR-4: El pipeline de CI en GitHub Actions debe compilar y empaquetar los 3 binarios (`halo-server-linux-x86`, `halo-server-linux-x64`, `halo-server-linux-arm64`) en cada release | criterio: Los artefactos existen en el workflow de GitHub Actions.

## Requisitos no funcionales
- NFR-1: Consumo de memoria en reposo en ARM64 < 120 MB de RAM | medicion: RSS reportado por `ps` en host o contenedor.
- NFR-2: Cero secretos o tokens en scripts de build o configuración del repositorio | verificacion: `git log` y `grep` sin strings sensibles.
- NFR-3: Binario headless sin dependencias externas pesadas | verificacion: `ldd` no requiere X11, Wayland, PulseAudio o PipeWire.

## Supuestos
- La Raspberry Pi 3B corre un sistema operativo de 64 bits (Raspberry Pi OS 64-bit basado en Debian Bookworm/Bullseye o Ubuntu Server 64-bit).
- Clang y LLD soportan cross-compilation a `--target=aarch64-linux-gnu` en el entorno de compilación.

## Preguntas abiertas
- Ninguna bloqueante en este momento.
