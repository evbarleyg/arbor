#!/bin/bash
# A step of CI's Mac job, by itself: the tests a Mac can say something about, all of them. Then what it leaves behind.
# For GitHub's Macs only, which are thrown away: it lists processes and windows, and runs tests and real windows without lib.sh's care.
[ "${GITHUB_ACTIONS:-}" = true ] && [ "$(id -un)" = runner ] || { echo "skipped: for one of GitHub's Macs only"; exit 77; }
cd "$(dirname "$0")/../.." || exit 2
mkdir -p mac-shell
source scripts/mac-shell/probe-state.sh
began=$SECONDS
swift build --build-tests > mac-shell/build-tests.log 2>&1
echo "swift build --build-tests: exit $?, $((SECONDS - began)) s"
began=$SECONDS
./scripts/ci-tests.py run --mode mac-only --record mac-shell/mac.tsv > mac-shell/test.log 2>&1
echo "the selection: exit $?, $((SECONDS - began)) s"
grep -E "^Recorded|^Running the tests" mac-shell/test.log
rm -f mac-shell/mac.tsv.events
probe_state
