FROM ghcr.io/dmetzler1988-org/alpine-minimal:0.0.1

LABEL maintainer="dmetzler1988"
LABEL version="1.0"
LABEL description="Minimal Python container image based on dmetzler1988-org/alpine-minimal image"

# Install Python3 and pip3 - check versions on https://pkgs.alpinelinux.org/packages
RUN apk --no-cache add python3 py3-pip

# Create links for better usage
RUN ln /usr/bin/python3 /usr/bin/py

# error: externally-managed-environment
  #× This environment is externally managed
# The system-wide python installation should be maintained using the system
  #    package manager (apk) only.
  #
  #    If the package in question is not packaged already (and hence installable via
  #    "apk add py3-somepackage"), please consider installing it inside a virtual
  #    environment, e.g.:

# Enable virtual environment
#RUN python3 -m venv /path/to/venv && . /path/to/venv/bin/activate
#RUN pip install mypackage
# To exit the virtual environment, run:
#RUN deactivate
