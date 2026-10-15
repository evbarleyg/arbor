#!/bin/bash
# Runs a command in the Linux image CI uses, for machines that have Docker but no Swift for Linux
# (a Mac included). Only the headless stack builds there; see Package.swift.
#
#   ./scripts/linux.sh                      # make check scenarios parity
#   ./scripts/linux.sh swift test --filter GeometryTests
#
# The build goes to a Docker volume, so the checkout's own .build is left alone. The image has
# neither python3 nor make; they are added for every command except plain `swift …`.
# ARBOR_DOCKER_ARGS adds arguments to `docker run`, e.g. --network host.
set -euo pipefail
cd "$(dirname "$0")/.."

image=$(sed -n 's/^ *container: *\(swift:[^ ]*\) *$/\1/p' .github/workflows/linux.yml | head -1)
[ -n "$image" ] || { echo "no Swift image named in .github/workflows/linux.yml"; exit 2; }
[ $# -gt 0 ] || set -- make check scenarios parity

# shellcheck disable=SC2086
exec docker run --rm ${ARBOR_DOCKER_ARGS:-} -v "$PWD":/src -v arbor-linux-build:/src/.build -w /src "$image" \
  bash -c 'if [ "$1" != swift ]; then
             { apt-get update -qq && apt-get install -y -qq python3 make; } >/dev/null 2>&1 \
               || { echo "could not add python3 and make to the container" >&2; exit 2; }
           fi
           exec "$@"' bash "$@"
