# dmetzler1988 Python base image

The dmetzler1988 Python base image is an image based on our
[dmetzler1988-org/alpine-minimal](https://github.com/dmetzler1988-org/container-image-alpine-minimal/pkgs/container/alpine-minimal) 
from [Github Package Manager](https://ghcr.io/).

## Features

- based on [dmetzler1988-org/alpine-minimal](https://github.com/dmetzler1988-org/container-image-alpine-minimal/pkgs/container/alpine-minimal)
- contains python3

## Usage

This image can be used as a downstream image in your repository. Replace the `:latest` tag with a specific version.

```Dockerfile
FROM ghcr.io/dmetzler1988-org/python3-minimal:latest AS build

WORKDIR /app

COPY . .
RUN apk --no-cache add py3-flask

USER nobody

CMD ["python3", "main.py"]
```

## Local Build

To build this image on local system, use the following command in your CLI

```shell
docker build -t dmetzler1988-org/python3-minimal .
```

## Build Process

The CI/CD setup uses the [Docker build-push Action](https://github.com/docker/build-push-action) to publish container images.  
This is managed in [.github/workflows/release.yaml](./.github/workflows/release.yaml).

## License

This application is free software: you can redistribute it and/or modify it under the terms of 
the [GNU Affero General Public License v3](https://www.gnu.org/licenses/agpl-3.0.txt).

## Copyright

Copyright (c) 2024 [dmetzler1988](https://github.com/dmetzler1988)
