#!/bin/sh
# Test entry point for the shared build and release workflows.
# Expects the image reference in $IMAGE and its key from images.json in $IMAGE_KEY (e.g. 3.14 or 3.14-dev).
set -eu

: "${IMAGE:?IMAGE must be set to the image under test}"
: "${IMAGE_KEY:?IMAGE_KEY must be set, e.g. 3.14 or 3.14-dev}"

tests_dir=$(dirname "$0")
sh "$tests_dir/common.sh"
case "$IMAGE_KEY" in
  *-dev) sh "$tests_dir/dev.sh" ;;
  *) sh "$tests_dir/runtime.sh" ;;
esac
echo "all tests passed for $IMAGE ($IMAGE_KEY)"
