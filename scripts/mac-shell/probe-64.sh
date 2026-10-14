#!/bin/bash
# A probe, not to be merged: the control. Swift 6.4 still builds it, warnings and all.
cd "$(dirname "$0")/../.." || exit 2
mkdir -p mac-shell
swift --version 2>&1
swift build --build-tests > mac-shell/build.log 2>&1
code=$?
grep -E "^/.*: (error|warning):|^error:" mac-shell/build.log | sed "s|$PWD/||g" | sort -u | head -n 60
tail -n 2 mac-shell/build.log
exit "$code"
