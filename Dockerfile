# syntax=docker/dockerfile:1

# CPython built from python.org source on alpine-minimal, verified with Sigstore.
#
# Targets:
#   runtime  Python only: no pip, no compiler, no headers, no test suite.
#   dev      Python with pip, headers and a compiler, as a build stage for apps.
#
# CI passes the version, the release manager's Sigstore identity and the base digest (see images.json and
# .github/workflows/ci.yaml). The base tag has no digest here on purpose: CI pins it with --build-context.

ARG COSIGN_IMAGE=ghcr.io/sigstore/cosign/cosign:v3.1.4@sha256:0f06154836d2de34f887a5c273506d52ca43edaa1d9e53e6510fa78a48f69c2d

FROM ${COSIGN_IMAGE} AS cosign

FROM ghcr.io/dmetzler1988-org/alpine-minimal:3.24 AS base

# ---------------------------------------------------------------------------------------------------------
FROM base AS source

ARG PYTHON_VERSION

USER root
COPY --from=cosign /ko-app/cosign /usr/local/bin/cosign
RUN apk add --no-cache curl xz
WORKDIR /src
# Release manager Sigstore identity per version line, from https://www.python.org/downloads/metadata/sigstore/
# A new line, or a new release manager, fails the build here until this table is updated.
RUN : "${PYTHON_VERSION:?build arg PYTHON_VERSION is required}" \
 && case "${PYTHON_VERSION%.*}" in \
      3.14) PYTHON_SIGNER=hugo@python.org; PYTHON_SIGNER_ISSUER=https://github.com/login/oauth ;; \
      3.13) PYTHON_SIGNER=thomas@python.org; PYTHON_SIGNER_ISSUER=https://accounts.google.com ;; \
      *) echo "No Sigstore signer known for Python ${PYTHON_VERSION%.*}; add it to the Dockerfile" >&2; exit 1 ;; \
    esac \
 && tarball="Python-${PYTHON_VERSION}.tar.xz" \
 && url="https://www.python.org/ftp/python/${PYTHON_VERSION}/${tarball}" \
 && curl -fsS --retry 3 --connect-timeout 10 --max-time 300 -o "$tarball" "$url" \
 && curl -fsS --retry 3 --connect-timeout 10 --max-time 60 -o "$tarball.sigstore" "$url.sigstore" \
 && cosign verify-blob \
      --bundle "$tarball.sigstore" \
      --certificate-identity "$PYTHON_SIGNER" \
      --certificate-oidc-issuer "$PYTHON_SIGNER_ISSUER" \
      "$tarball" \
 && mkdir /src/python \
 && tar -xJf "$tarball" -C /src/python --strip-components=1

# ---------------------------------------------------------------------------------------------------------
FROM base AS build

ARG PYTHON_VERSION
# false skips profile-guided optimization and LTO: much faster, for local test builds only.
ARG OPTIMIZE=true

USER root
RUN apk add --no-cache \
      build-base linux-headers pax-utils \
      bzip2-dev expat-dev gdbm-dev libffi-dev mpdecimal-dev ncurses-dev openssl-dev \
      readline-dev sqlite-dev util-linux-dev xz-dev zlib-dev
COPY --from=source /src/python /src/python
WORKDIR /src/python
RUN set -eu \
 && optimize="" \
 && if [ "$OPTIMIZE" = "true" ]; then optimize="--enable-optimizations --with-lto"; fi \
 # shellcheck disable=SC2086 # optimize holds zero or two flags
 && ./configure \
      --prefix=/usr/local \
      --build="$(gcc -dumpmachine)" \
      --with-ensurepip=install \
      --with-system-expat \
      --with-system-libmpdec \
      --without-static-libpython \
      $optimize \
 && make -j"$(nproc)" \
 && make install \
 && minor="${PYTHON_VERSION%.*}" \
 && test "$(/usr/local/bin/python3 -c 'import platform; print(platform.python_version())')" = "$PYTHON_VERSION" \
 && find /usr/local -depth \
      \( -type d \( -name test -o -name tests -o -name idle_test \) \) -exec rm -rf '{}' + \
 && rm -rf \
      "/usr/local/lib/python$minor/idlelib" \
      "/usr/local/lib/python$minor/tkinter" \
      "/usr/local/lib/python$minor/turtledemo" \
      /usr/local/bin/idle3* \
 # Bytecode for python -O/-OO only (about 23 MB); the normal .pyc stay, so startup needs no recompiling.
 && find /usr/local -type f -name '*.opt-[12].pyc' -delete \
 # Strip ELF files only (scanelf lists them), so scripts never reach strip and nothing needs "|| true".
 && scanelf --recursive --nobanner --format '%F' /usr/local | xargs -r strip --strip-unneeded \
 && ln -s python3 /usr/local/bin/python \
 && ln -s pip3 /usr/local/bin/pip \
 # Shared libraries the installed Python needs from Alpine, as "so:" package names apk resolves on both
 # architectures. Libraries that /usr/local ships itself are left out.
 && scanelf --needed --nobanner --format '%n#p' --recursive /usr/local \
      | tr ',' '\n' | sort -u \
      | awk 'system("[ -e /usr/local/lib/" $1 " ]") == 0 { next } { print "so:" $1 }' \
      > /usr/local/.rundeps

# ---------------------------------------------------------------------------------------------------------
FROM base AS runtime

ARG PYTHON_VERSION
ARG ALPINE_MINIMAL_IMAGE=unknown
ARG ALPINE_MINIMAL_DIGEST=unknown

LABEL org.opencontainers.image.title="python-minimal" \
      org.opencontainers.image.description="Minimal CPython built from source on alpine-minimal, runs as non-root user 10001." \
      org.opencontainers.image.source="https://github.com/dmetzler1988-org/container-image-python-minimal" \
      org.opencontainers.image.version="${PYTHON_VERSION}" \
      org.opencontainers.image.base.name="${ALPINE_MINIMAL_IMAGE}" \
      org.opencontainers.image.base.digest="${ALPINE_MINIMAL_DIGEST}"

USER root
COPY --from=build /usr/local /usr/local
RUN set -eu \
 && apk add --no-cache $(cat /usr/local/.rundeps) \
 && rm /usr/local/.rundeps \
 && minor="${PYTHON_VERSION%.*}" \
 # Runtime only: no pip, no ensurepip, no headers or build configuration.
 && rm -rf \
      /usr/local/bin/pip* \
      /usr/local/bin/python*-config \
      /usr/local/include \
      /usr/local/lib/pkgconfig \
      "/usr/local/lib/python$minor/ensurepip" \
      "/usr/local/lib/python$minor/site-packages/pip" \
      "/usr/local/lib/python$minor/site-packages/pip-"* \
      "/usr/local/lib/python$minor/config-$minor"*
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1
USER 10001
CMD ["python3"]

# ---------------------------------------------------------------------------------------------------------
FROM base AS dev

ARG PYTHON_VERSION
ARG ALPINE_MINIMAL_IMAGE=unknown
ARG ALPINE_MINIMAL_DIGEST=unknown

LABEL org.opencontainers.image.title="python-minimal-dev" \
      org.opencontainers.image.description="CPython built from source on alpine-minimal, with pip, headers and a compiler for building app dependencies." \
      org.opencontainers.image.source="https://github.com/dmetzler1988-org/container-image-python-minimal" \
      org.opencontainers.image.version="${PYTHON_VERSION}" \
      org.opencontainers.image.base.name="${ALPINE_MINIMAL_IMAGE}" \
      org.opencontainers.image.base.digest="${ALPINE_MINIMAL_DIGEST}"

USER root
COPY --from=build /usr/local /usr/local
RUN set -eu \
 && apk add --no-cache $(cat /usr/local/.rundeps) \
      build-base linux-headers \
      bzip2-dev expat-dev gdbm-dev libffi-dev mpdecimal-dev ncurses-dev openssl-dev \
      readline-dev sqlite-dev util-linux-dev xz-dev zlib-dev \
 && rm /usr/local/.rundeps
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PIP_NO_CACHE_DIR=1
USER 10001
CMD ["python3"]
