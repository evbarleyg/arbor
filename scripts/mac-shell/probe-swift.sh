#!/bin/bash
# A probe, not to be merged: what does the Swift that comes with the runner's Xcode make of Arbor?
cd "$(dirname "$0")/../.." || exit 2
mkdir -p mac-shell
PATH=$(printf '%s' "$PATH" | tr ':' '\n' | grep -v swiftly | paste -sd: -)
export PATH
unset TOOLCHAINS

echo "== Xcodes on this Mac"
for xcode in /Applications/Xcode*.app; do
  [ -L "$xcode" ] && { echo "$xcode -> $(readlink "$xcode")"; continue; }
  echo "$xcode: $(DEVELOPER_DIR=$xcode/Contents/Developer swift --version 2>&1 | head -1)"
done
echo "selected: $(xcode-select -p)"
swift --version 2>&1

echo "== variants"
for file in scripts/mac-shell/probe-swift/*.swift; do
  for mode in -Onone -O; do
    log=mac-shell/$(basename "$file" .swift)$mode.log
    if swiftc -swift-version 6 -target arm64-apple-macosx14.0 -parse-as-library -emit-ir $mode -o /dev/null "$file" > "$log" 2>&1; then
      echo "ok      $mode $(basename "$file")"
    else
      echo "FAILED  $mode $(basename "$file"): $(grep -E 'error:|While emitting IR' "$log" | head -3 | tr '\n' ' ' | cut -c 1-400)"
    fi
  done
done

echo "== the real thing"
swift build --build-tests > mac-shell/build.log 2>&1
code=$?
grep -E "^/.*: error:|^error:|While emitting IR|While evaluating request IRGen" mac-shell/build.log | sed "s|$PWD/||g" | sort -u | head -n 60
tail -n 2 mac-shell/build.log
exit "$code"
