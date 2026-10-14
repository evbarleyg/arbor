#!/bin/bash
# A probe, not to be merged: build and test with the Swift of the newest Xcode on the runner.
cd "$(dirname "$0")/../.." || exit 2
mkdir -p mac-shell
PATH=$(printf '%s' "$PATH" | tr ':' '\n' | grep -v swiftly | paste -sd: -)
export PATH
unset TOOLCHAINS
swift --version 2>&1
date -u +%T
swift build --build-tests > mac-shell/build.log 2>&1
code=$?
grep -E "^/.*: (error|warning):|^error:|While emitting IR|While evaluating request IRGen" mac-shell/build.log | sed "s|$PWD/||g" | sort -u | head -n 60
tail -n 2 mac-shell/build.log
date -u +%T
[ "$code" = 0 ] || exit "$code"
swift test --skip-build > mac-shell/test.log 2>&1
code=$?
grep -E "✘|error:|Test run with|Executed .* tests" mac-shell/test.log | cut -c 1-300 | head -n 60
date -u +%T
exit "$code"
