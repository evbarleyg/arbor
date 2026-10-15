#!/bin/bash
# Runs arbor-e2e (with the arguments given, e.g. --full-screen) and keeps its output as evidence in
# collab/evidence/e2e-latest.txt.
# The evidence is replaced only when the run actually drove windows (exit 0 or
# 1); a run without Accessibility permission (exit 2) leaves it untouched.
#
# At a terminal the run is printed as it goes. Anywhere else somebody reads a report afterwards, and whoever quotes it quotes its
# beginning: there what kept the run from giving a verdict comes first, then the checks that failed, each under its step, and the whole
# run after them.
set -uo pipefail
cd "$(dirname "$0")/.."

# On GitHub's Macs, which are thrown away after the run, arbor-e2e looks out for nobody. A runner that a person set up on their own Mac says
# GITHUB_ACTIONS=true as well. GitHub's run their jobs as `runner`, and no variable changes what the account is called (as in
# mac-shell/lib.sh). Taken out of the environment, so that arbor-e2e and whatever else this script starts find it gone.
if [ "${GITHUB_ACTIONS:-}" = true ] && [ "$(id -un)" != runner ]; then unset GITHUB_ACTIONS; fi
# There, too, the run is recorded (docs/TRACES.md), and Arbor's log and the traces are left in mac-shell/e2e/, which comes back to whoever asked for the
# run: what a hosted Mac showed should never need a Mac again (scripts/trace-to-test.py). Not on a person's Mac: a trace names the apps that are open.
unset ARBOR_E2E_KEEP
if [ "${GITHUB_ACTIONS:-}" = true ] && [ "$(id -un)" = runner ]; then export ARBOR_E2E_KEEP="$PWD/mac-shell/e2e"; fi

mkdir -p collab/evidence
tmp=$(mktemp) || exit 2
run() {
  echo "# arbor-e2e $(date -u +%Y-%m-%dT%H:%MZ) on macOS $(sw_vers -productVersion), commit $(git rev-parse --short HEAD)"
  .build/debug/arbor-e2e "$@"
}
if [ -t 1 ]; then
  run "$@" | tee "$tmp"
  code=${PIPESTATUS[0]}
else
  run "$@" > "$tmp"
  code=$?
  # The runner's own line, and under it what the Mac said of itself, up to the blank line.
  awk '/^arbor-e2e: no verdict/ { on = 1 } on && /^$/ { on = 0; print "" } on' "$tmp"
  if grep -q "^  ✘ " "$tmp"; then
    echo "# the checks that failed, each under its step; the whole run follows"
    # With the notes under it (↳: what Arbor logged during the step), word for word, so that ci-step.py takes both for one failure.
    awk '/^▸ / { step = $0 } /^  ✘ / { if (step != "") print step; step = ""; print; noted = 1; next } noted && /^ *↳/ { print; next } { noted = 0 }' "$tmp"
    echo
  fi
  cat "$tmp"
fi

if [ "$code" -eq 0 ] || [ "$code" -eq 1 ]; then
  mv "$tmp" collab/evidence/e2e-latest.txt
  echo "evidence saved to collab/evidence/e2e-latest.txt (it names this Mac's display: commit it only from a throwaway Mac, such as CI's)"
else
  rm -f "$tmp"
fi
exit "$code"
