#!/bin/bash
# A step of CI's Mac job, by itself: arbor-e2e, full screen included. Then what it leaves behind.
# For GitHub's Macs only, which are thrown away: it lists processes and windows, and runs tests and real windows without lib.sh's care.
[ "${GITHUB_ACTIONS:-}" = true ] && [ "$(id -un)" = runner ] || { echo "skipped: for one of GitHub's Macs only"; exit 77; }
cd "$(dirname "$0")/../.." || exit 2
mkdir -p mac-shell
source scripts/mac-shell/probe-state.sh
began=$SECONDS
./scripts/e2e.sh --full-screen > mac-shell/e2e.log 2>&1
echo "arbor-e2e --full-screen: exit $?, $((SECONDS - began)) s"
grep -E "✘|passed|failed" mac-shell/e2e.log | head -n 12 | cut -c 1-150
probe_state
