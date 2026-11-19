#!/bin/sh
# Tests for the dev variant: pip works and a C extension builds against this exact Python.
set -eu

: "${IMAGE:?IMAGE must be set}"

fail() {
  echo "FAIL (dev): $*" >&2
  exit 1
}

pass() {
  echo "ok (dev): $*"
}

docker run --rm "$IMAGE" python3 -m pip --version > /dev/null || fail "pip is missing"
docker run --rm "$IMAGE" pip --version > /dev/null || fail "pip symlink missing"
pass "pip works"

docker run --rm "$IMAGE" python3-config --includes > /dev/null || fail "python3-config is missing"
pass "python3-config present"

# Build a tiny extension module with the image's compiler and headers, as a non-root user, then import it.
docker run --rm -i -w /tmp "$IMAGE" sh -eu <<'SH' || fail "a C extension does not build or import"
cat > hello.c <<'C'
#include <Python.h>
static PyObject *greet(PyObject *self, PyObject *args) { return PyUnicode_FromString("hello"); }
static PyMethodDef methods[] = {{"greet", greet, METH_NOARGS, NULL}, {NULL, NULL, 0, NULL}};
static struct PyModuleDef module = {PyModuleDef_HEAD_INIT, "hello", NULL, -1, methods};
PyMODINIT_FUNC PyInit_hello(void) { return PyModule_Create(&module); }
C
suffix=$(python3 -c 'import sysconfig; print(sysconfig.get_config_var("EXT_SUFFIX"))')
cc -shared -fPIC $(python3-config --includes) hello.c -o "hello$suffix"
test "$(python3 -c 'import hello; print(hello.greet())')" = hello
SH
pass "C extension builds and imports"

docker run --rm -i -w /tmp "$IMAGE" sh -eu <<'SH' || fail "creating a venv with pip failed"
python3 -m venv /tmp/venv
/tmp/venv/bin/pip --version > /dev/null
SH
pass "venv with pip works"
