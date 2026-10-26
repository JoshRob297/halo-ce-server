# Architecture Plan: Multi-Architecture Linux Builds (ARM64 / x86_64 / i686)

## Arquitectura Propuesta

```
                  [ Código Fuente C89 / OpenCE v38 ]
                                  |
              +-------------------+-------------------+
              |                                       |
     [ tools/linux_build.py ]                [ tools/lp64_build.py ]
              |                                       |
    [ Target: i686-linux-gnu ]              [ tools/lp64_rewrite.py ]
              |                        (Reescritura de tipos: long -> int)
              |                                       |
              |                        +--------------+--------------+
              |                        |                             |
              v                        v                             v
      [ halo-linux-x86 ]      [ halo-linux-x64 ]            [ halo-linux-arm64 ]
        (i686 32-bit)          (x86_64 64-bit)                (aarch64 64-bit)
              |                        |                             |
              +------------------------+-----------------------------+
                                       |
                        [ GitHub Actions CI Workflow ]
                                       |
                   +-------------------+-------------------+
                   |                                       |
      [ GitHub Releases Tarballs ]             [ Docker Buildx Hub / GHCR ]
    - halo-server-linux-x86.tar.gz            - linux/amd64 (x64)
    - halo-server-linux-x64.tar.gz            - linux/arm64 (Raspberry Pi 3B/4/5)
    - halo-server-linux-arm64.tar.gz
```

## Decisiones de Arquitectura

### Decisión 1: Estrategia de tipos en arquitecturas de 64 bits (LP64)
- **Contexto:** El código original de Xbox 2001 compila bajo MSVC donde `long` es de 32 bits. En Linux 64-bit (`LP64`), `long` es de 64 bits, lo que provocaría desalineación en structs de red y tags del mapa.
- **Decisión:** Adoptar la técnica de compilación de Chupathingy/OpenCE mediante `tools/lp64_rewrite.py` y `source/cseries/xbox_address.h` con el flag `-DHALO_64BIT=1`.
- **Alternativas descartadas:**
  - *Usar ILP32 en ARM (arm64_32 de Apple):* Requiere toolchains no estándar en Linux comunes y carece de soporte directo en distribuciones Debian/Ubuntu para Raspberry Pi.
  - *Box86 emulado:* Agrega sobrecarga y complejidad operativa al usuario; se descartó a favor del binario ELF nativo puro.
- **Consecuencias:** Se obtiene un binario ELF aarch64 nativo sin dependencias de emulación, con ejecución directa en cualquier distribución Linux ARM64 estándar.

### Decisión 2: Espacio de memoria y direcciones Xbox (`xbox_address.h` / `xbox_memory.c`)
- **Contexto:** Las etiquetas de mapas y el estado físico del juego esperan direcciones de 32 bits.
- **Decisión:** Para ARM64, ubicar la base de memoria Xbox en `XBOX_ADDRESS_SPACE_BASE = 0x4000000000ULL` (256 GB), dentro de los límites de los kernels ARM64 con espacio de direcciones de 39 bits (Raspberry Pi OS).
- **Consecuencias:** Cero colisiones de memoria en hosts con poca RAM (como el 1 GB de la RPi 3B).

### Decisión 3: Generación de binarios en CI
- **Contexto:** Raspberry Pi 3B tiene recursos limitados para compilar el proyecto directamente en la placa.
- **Decisión:** Utilizar Clang cross-compilation en GitHub Actions (`ubuntu-latest` x86_64) con sysroots ARM64 ligeros (`aarch64-linux-gnu`) y compilar los artefactos en la nube.
- **Consecuencias:** Compilaciones ultrarrápidas (< 5 minutos) y entrega directa de binarios precompilados en los releases.

## Riesgos y Mitigación
1. **Riesgo:** Desalineación de estructuras de red entre clientes v38 (32-bit) y el servidor (64-bit).
   - *Mitigación:* Tests de aserciones estáticas de tamaño de structs (`_Static_assert(sizeof(...) == ..., ...)`) antes de emitir paquetes.
2. **Riesgo:** Agotamiento de memoria RAM en RPi 3B (1 GB).
   - *Mitigación:* El servidor headless se compila sin SDL3 gráfico ni dependencias X11/Wayland, manteniendo el RSS por debajo de 100 MB.

## Niveles de Testing
1. **Unitario:** Test de compilación y enlace cruzado con `aarch64-linux-gnu`.
2. **Integración:** Ejecución en contenedor Docker ARM64 emulado por QEMU en el CI para validar que arranca, carga mapas y responde en el puerto 8080.
3. **Red:** Verificación de conexión de clientes v38 y respuesta del Web Dashboard.
