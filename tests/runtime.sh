#!/bin/sh
# Tests for the runtime variant: Python only, no tools to install or build anything.
set -eu

: "${IMAGE:?IMAGE must be set}"

fail() {
  echo "FAIL (runtime): $*" >&2
  exit 1
}

pass() {
  echo "ok (runtime): $*"
}

if docker run --rm "$IMAGE" python3 -m pip --version > /dev/null 2>&1; then
  fail "pip is present"
fi
if docker run --rm "$IMAGE" python3 -m ensurepip --version > /dev/null 2>&1; then
  fail "ensurepip is present"
fi
pass "no pip, no ensurepip"

if docker run --rm "$IMAGE" sh -c 'command -v gcc || command -v cc || ls /usr/local/include/python3*/Python.h' > /dev/null 2>&1; then
  fail "compiler or Python headers are present"
fi
pass "no compiler, no headers"
