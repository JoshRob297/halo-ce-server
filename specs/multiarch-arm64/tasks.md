# Tasks: Multi-Architecture Linux Builds (ARM64 & x86_64)

- [x] T-001 [FR-1] Portar módulos base de 64 bits (`xbox_address.h`, `xbox_memory.c` 64-bit y `lp64_rewrite.py`) en `halo-opence-dhost`
      toca: source/cseries/xbox_address.h, port/linux/src/xbox_memory.c, tools/lp64_rewrite.py, tools/lp64_build.py
      done: Los archivos existen y compilan sin errores de sintaxis con clang
      verify: clang -fsyntax-only -Isource/cseries -DHALO_64BIT source/cseries/xbox_address.h

- [x] T-002 [FR-1] Configurar script de compilación y toolchain Ninja para ARM64 (`tools/server_build.py` o target `ninja server-arm64`)
      toca: configure.py, tools/server_build.py, tools/linux64_build.py
      done: El generador Ninja genera las reglas para target `aarch64-linux-gnu`
      verify: python3 configure.py && grep "aarch64" build.ninja

- [x] T-003 [FR-1] Probar compilación cruzada del binario `halo-server-arm64` con Clang y sysroot aarch64
      toca: build/server-arm64/halo
      done: Binario ELF 64-bit LSB ejecutable ARM aarch64 generado exitosamente
      verify: file /tmp/test_arm64_server_boot | grep "ARM aarch64"

- [x] T-004 [FR-2] Validar ejecución headless en ARM64 con QEMU (test de arranque, socket UDP 2302 y API HTTP 8080)
      toca: qemu-aarch64-static
      done: El binario arranca, inicializa el servidor en modo headless y expone /api/settings
      verify: qemu-aarch64-static /tmp/test_arm64_server_boot | grep "hosting UDP"

- [x] T-005 [FR-4] Actualizar workflow de CI (`.github/workflows/ci.yml`) y `Dockerfile` multi-arch en `halo-server-pkg`
      toca: .github/workflows/ci.yml, Dockerfile, docker-compose.yml
      done: GitHub Actions compila x86, x64 y arm64 y publica los tarballs correspondientes
      verify: git diff .github/workflows/docker.yml | grep "platforms"

- [x] T-006 [FR-3] Actualizar documentación bilingüe (`README.md`, `README.es.md`, `docs/raspberry-pi.md`) con instrucciones de instalación en Raspberry Pi 3B
      toca: README.md, README.es.md, docs/raspberry-pi.md
      done: Guía paso a paso para Raspberry Pi 3B/4/5 con Docker y bare-metal en español e inglés
      verify: test -f docs/raspberry-pi.md && grep "Raspberry Pi 3B" docs/raspberry-pi.md
