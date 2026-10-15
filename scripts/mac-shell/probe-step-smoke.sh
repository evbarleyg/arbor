#!/bin/bash
# Three steps of CI's Mac job, by themselves: the simulator's smoke test, the scenarios, the release tools' test. Then what they leave behind.
# For GitHub's Macs only, which are thrown away: it lists processes and windows, and runs tests and real windows without lib.sh's care.
[ "${GITHUB_ACTIONS:-}" = true ] && [ "$(id -un)" = runner ] || { echo "skipped: for one of GitHub's Macs only"; exit 77; }
cd "$(dirname "$0")/../.." || exit 2
mkdir -p mac-shell
source scripts/mac-shell/probe-state.sh
for step in sim-smoke scenarios release-tools-test; do
  began=$SECONDS
  "./scripts/$step.sh" > "mac-shell/$step.log" 2>&1
  echo "$step.sh: exit $?, $((SECONDS - began)) s"
done
probe_state
