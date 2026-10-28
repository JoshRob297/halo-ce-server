# Halo CE dedicated server, built from the OpenCE port with the dedicated
# host suite (feat/server-full-suite) on top.
#
# Two stages: an Arch builder with the 32-bit toolchain compiles the release
# build (the committed PGO profile, tools/ci_build.py linux release); a slim
# Debian runtime holds only the binary, the bundled SDL3 and the config.

ARG OPENCE_REPO=https://github.com/JoshRob297/halo-ce-touch.git
ARG OPENCE_REF=feat/server-full-suite

FROM --platform=$BUILDPLATFORM archlinux:base AS build

ARG OPENCE_REPO
ARG OPENCE_REF

RUN printf '[multilib]\nInclude = /etc/pacman.d/mirrorlist\n' >> /etc/pacman.conf \
 && pacman -Syu --noconfirm --needed \
    git zstd python python-pytest ninja ccache \
    clang lld gcc lib32-glibc lib32-gcc-libs cmake pkgconf wayland

WORKDIR /src
RUN git clone --depth 1 --branch "$OPENCE_REF" "$OPENCE_REPO" . \
 && python3 tools/ci_build.py linux release

FROM debian:bookworm-slim

ARG TARGETARCH

# Configurar soporte segun arquitectura:
# En amd64: arquitectura i386 nativa
# En arm64: compatibilidad armhf / box86
RUN if [ "$TARGETARCH" = "amd64" ]; then \
        dpkg --add-architecture i386 \
        && apt-get update \
        && apt-get install -y --no-install-recommends libc6:i386 libgcc-s1:i386 ca-certificates netcat-openbsd \
        && rm -rf /var/lib/apt/lists/*; \
    else \
        dpkg --add-architecture armhf \
        && apt-get update \
        && apt-get install -y --no-install-recommends libc6:armhf libgcc-s1:armhf ca-certificates netcat-openbsd \
        && rm -rf /var/lib/apt/lists/*; \
    fi

WORKDIR /halo
COPY --from=build /src/dist/halo-linux-release/halo /halo/halo
COPY --from=build /src/dist/halo-linux-release/libSDL3.so.0 /halo/libSDL3.so.0
COPY --from=build /src/dist/halo-linux-release/SDL3-LICENSE.txt /halo/SDL3-LICENSE.txt
COPY server/config.toml /halo/config.toml
COPY scripts /halo/scripts

# the data root: maps/ beside the executable; saved games under the home
VOLUME ["/halo/maps", "/halo/custom_maps", "/root/.local/share/halo-linux"]
EXPOSE 2302/udp 8080/tcp

# no display and no sound card: SDL's dummy drivers (the game still opens
# SDL's video and audio, as any host would)
ENV SDL_VIDEODRIVER=dummy \
    SDL_AUDIODRIVER=dummy

ENTRYPOINT ["/halo/halo"]
