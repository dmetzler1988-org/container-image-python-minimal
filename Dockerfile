FROM ghcr.io/dmetzler1988-org/alpine-minimal:0.0.3

LABEL maintainer="dmetzler1988"
LABEL version="1.0"
LABEL description="Minimal Python container image based on dmetzler1988-org/alpine-minimal image"

# Install Python3 and pip3 - check versions on https://pkgs.alpinelinux.org/packages
RUN apk --no-cache add python3 py3-pip

# Create links for better usage
RUN ln /usr/bin/python3 /usr/bin/py

WORKDIR /app
