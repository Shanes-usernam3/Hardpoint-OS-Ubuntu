#!/usr/bin/env bash
# Build the Himmelblau (Microsoft Entra ID sign-in) packages for Ubuntu 24.04
# from a pinned upstream release, using upstream's own Docker build.
#   HIMMELBLAU_TAG=4.0.5 tools/build-himmelblau.sh <output-dir>
set -euo pipefail
TAG="${HIMMELBLAU_TAG:?set HIMMELBLAU_TAG}"
OUT="$(realpath -m "${1:-extra-pkgs}")"
SRC="$(mktemp -d)/himmelblau"
git clone --depth 1 --branch "$TAG" https://github.com/himmelblau-idm/himmelblau "$SRC"
cd "$SRC"
# CI has no terminal: upstream's Makefile runs docker with -it
sed -i 's/ -it / -i /g' Makefile
export DOCKER_BUILDKIT=1
make ubuntu24.04
mkdir -p "$OUT"
cp -v packaging/*.deb "$OUT/"
ls -la "$OUT"
