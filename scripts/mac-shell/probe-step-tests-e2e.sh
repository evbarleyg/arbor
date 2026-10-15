#!/bin/bash
# Two steps of CI's Mac job, one after the other: the tests, then arbor-e2e.
# For GitHub's Macs only, which are thrown away: it lists processes and windows, and runs tests and real windows without lib.sh's care.
[ "${GITHUB_ACTIONS:-}" = true ] && [ "$(id -un)" = runner ] || { echo "skipped: for one of GitHub's Macs only"; exit 77; }
cd "$(dirname "$0")/../.." || exit 2
bash scripts/mac-shell/probe-step-tests.sh
mkdir -p mac-shell/tests && mv mac-shell/*.log mac-shell/*.tsv mac-shell/tests/ 2>/dev/null
bash scripts/mac-shell/probe-step-e2e.sh
