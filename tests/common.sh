#!/bin/sh
# Tests every python-minimal variant must pass. Expects $IMAGE and $IMAGE_KEY.
set -eu

: "${IMAGE:?IMAGE must be set}"
: "${IMAGE_KEY:?IMAGE_KEY must be set}"

readonly EXPECTED_UID=10001
readonly VERSION_LABEL=org.opencontainers.image.version

fail() {
  echo "FAIL (common): $*" >&2
  exit 1
}

pass() {
  echo "ok (common): $*"
}

# No -i: a container that reads stdin would swallow the caller's input. Only py_stdin passes it on.
py() {
  docker run --rm "$IMAGE" python3 "$@"
}

py_stdin() {
  docker run --rm -i "$IMAGE" python3 -
}

uid=$(docker run --rm "$IMAGE" id -u)
[ "$uid" = "$EXPECTED_UID" ] || fail "runs as uid $uid, expected $EXPECTED_UID"
pass "runs as uid $EXPECTED_UID"

label=$(docker inspect --format "{{ index .Config.Labels \"$VERSION_LABEL\" }}" "$IMAGE")
actual=$(py -c 'import platform; print(platform.python_version())')
[ "$label" = "$actual" ] || fail "label $VERSION_LABEL=$label but python3 reports $actual"
line=${IMAGE_KEY%-dev}
case "$actual" in
  "$line".*) ;;
  *) fail "image key $IMAGE_KEY expects Python $line.x, got $actual" ;;
esac
pass "Python $actual matches label and line $line"

docker run --rm "$IMAGE" python --version > /dev/null || fail "python symlink missing"
pass "python points to python3"

py_stdin <<'PY' || fail "a standard library module is missing or broken"
import bz2, ctypes, decimal, hashlib, lzma, readline, sqlite3, ssl, uuid, zlib

context = ssl.create_default_context()
assert context.cert_store_stats()["x509_ca"] > 0, "no CA certificates loaded"
assert sqlite3.connect(":memory:").execute("select 1").fetchone() == (1,)
assert hashlib.sha256(b"x").hexdigest().startswith("2d711642")
assert lzma.decompress(lzma.compress(b"data")) == b"data"
assert bz2.decompress(bz2.compress(b"data")) == b"data"
assert zlib.decompress(zlib.compress(b"data")) == b"data"
assert decimal.Decimal("0.1") + decimal.Decimal("0.2") == decimal.Decimal("0.3")
assert ctypes.sizeof(ctypes.c_int) == 4
PY
pass "ssl with CA certificates, sqlite3, ctypes, decimal, compression, readline, uuid"

if py -c 'import test.support' > /dev/null 2>&1; then
  fail "test suite was not removed"
fi
pass "no test suite"
