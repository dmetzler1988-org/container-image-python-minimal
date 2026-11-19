# python-minimal

Minimal CPython images, built from python.org source on
[alpine-minimal](https://github.com/dmetzler1988-org/container-image-alpine-minimal). New Python patch releases are
checked hourly and built the same hour, without waiting for Alpine's packages.

- Python 3.14 and 3.13, each as a lean **runtime** image and a **dev** image for building app dependencies
- The python.org tarball is verified with Sigstore against the release manager's identity before it is built
- Runs as the non-root user `app`, UID/GID `10001`
- Built for `linux/amd64` and `linux/arm64`, signed with cosign, with an SBOM and a vulnerability report attached
- Rebuilt daily on the newest alpine-minimal, so base and library fixes arrive without anyone touching the repo

| Variant | Contains | Missing on purpose |
|---|---|---|
| runtime | Python, standard library, `python` → `python3` | pip, ensurepip, compiler, headers, test suite, tkinter, IDLE |
| dev | runtime plus pip, headers, `python3-config`, compiler and `-dev` libraries | test suite, tkinter, IDLE |

## Tags

For release 1.4.2 with Python 3.14.10 and 3.13.18:

| Tags | Image |
|---|---|
| `3.14.10`, `3.14`, `3`, `latest` | 3.14 runtime |
| `3.14.10-dev`, `3.14-dev`, `3-dev` | 3.14 dev |
| `3.13.18`, `3.13` | 3.13 runtime |
| `3.13.18-dev`, `3.13-dev` | 3.13 dev |
| `3.14.10-1.4.2`, `3.14.10-dev-1.4.2`, … | one specific release per image; never moves. Use it to roll back |

The moving tags work like `latest`: a new build re-points them. Pin them by digest and let your update bot
(Dependabot or Renovate) bump the digest.

The old package `ghcr.io/dmetzler1988-org/python3-minimal` (0.0.1, Alpine's `python3` package) is not
updated anymore.

## Usage

Install your app's dependencies in the dev image, copy only the result into the runtime image:

```Dockerfile
FROM ghcr.io/dmetzler1988-org/python-minimal:3.14-dev@sha256:<digest> AS build
COPY requirements.txt .
RUN python -m venv /opt/venv && /opt/venv/bin/pip install -r requirements.txt

FROM ghcr.io/dmetzler1988-org/python-minimal:3.14@sha256:<digest>
COPY --from=build /opt/venv /opt/venv
COPY --chown=10001:10001 app/ /app/
CMD ["/opt/venv/bin/python", "/app/main.py"]
```

Packages with C extensions compile against this exact Python in the dev stage. Alpine uses musl, so pip picks
`musllinux` wheels where they exist and compiles from source otherwise.

If a package needs a system library at runtime (e.g. `libpq`), install it in the runtime stage and remove the
package manager afterwards with alpine-minimal's `finalize`:

```Dockerfile
USER root
RUN apk add --no-cache libpq && /usr/local/sbin/finalize
USER 10001
```

## Releases

Every release has a SemVer version and a [GitHub Release](../../releases) listing each image's Python version,
tags and digest. `versions.lock` records the last release; the pipeline writes it, never edit it by hand.

| Change since the last release | Level |
|---|---|
| An image removed (e.g. a Python line at end of life) | major |
| An image added (e.g. Python 3.15), or a new Alpine minor version | minor |
| A Python patch release, a new alpine-minimal build, updated packages, or changes to `Dockerfile` / `images.json` | patch |
| Nothing | no release |

The build, test, release and signing steps live in
[dmetzler1988-org/container-workflows](https://github.com/dmetzler1988-org/container-workflows).

## Adding a Python line

1. Add the line's runtime and dev entries to `images.json`; move `majorTag` and `latest` to the newest line.
2. Add the release manager's Sigstore identity to the signer table in the `Dockerfile`
   (from <https://www.python.org/downloads/metadata/sigstore/>).

## Local build and tests

```shell
docker build --target runtime --build-arg PYTHON_VERSION=3.14.10 --build-arg OPTIMIZE=false -t python-minimal:local .
IMAGE=python-minimal:local IMAGE_KEY=3.14 tests/run.sh
```

`OPTIMIZE=false` skips profile-guided optimization and LTO, which make the build much slower. CI always builds with them.

## License

This application is free software: you can redistribute it and/or modify it under the terms of
the [GNU Affero General Public License v3](https://www.gnu.org/licenses/agpl-3.0.txt).

## Copyright

Copyright (c) 2024 [dmetzler1988](https://github.com/dmetzler1988)
