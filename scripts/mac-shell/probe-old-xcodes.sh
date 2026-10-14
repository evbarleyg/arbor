#!/bin/bash
# A probe, not to be merged: which of the runner's older Xcodes build Arbor?
cd "$(dirname "$0")/../.." || exit 2
mkdir -p mac-shell
PATH=$(printf '%s' "$PATH" | tr ':' '\n' | grep -v swiftly | paste -sd: -)
export PATH
unset TOOLCHAINS
worst=0
for version in 26.0.1 26.3 26.4.1; do
  export DEVELOPER_DIR=/Applications/Xcode_$version.app/Contents/Developer
  echo "== Xcode $version: $(swift --version 2>&1 | head -1)"
  date -u +%T
  swift build --build-tests --scratch-path ".build-$version" > "mac-shell/build-$version.log" 2>&1
  code=$?
  grep -E "^/.*: error:|^error:|While emitting IR|While evaluating request IRGen" "mac-shell/build-$version.log" | sed "s|$PWD/||g" | sort -u | cut -c 1-260 | head -n 40
  tail -n 1 "mac-shell/build-$version.log"
  echo "Xcode $version: exit code $code"
  [ "$code" = 0 ] || worst=$code
done
date -u +%T
exit "$worst"
