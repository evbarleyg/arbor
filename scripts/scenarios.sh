#!/bin/bash
# Runs every user-journey scenario in collab/scenarios through arbor-sim.
# A scenario fails when arbor-sim exits non-zero, which it does when an
# `expect` line does not hold (each one prints EXPECTATION FAILED) or a command
# fails that no `expect fail` answers for, a window is moved twice where once would have done (MOVED TWICE) and no
# `expect jolt` answers for it, or a display is not laid out again, and when it expects nothing at all.
#
# Each scenario is then run once more while a trace is recorded, and the trace is replayed in strict mode
# (docs/TRACES.md): the replayed controller must do exactly what the recorded one did. That fails when
# something new crosses the seams between Arbor and macOS without being recorded or replayed.
#
#   ./scripts/scenarios.sh            # summary
#   VERBOSE=1 ./scripts/scenarios.sh  # full arbor-sim output
#   ARBOR_SCENARIOS=<folder> ./scripts/scenarios.sh   # another folder's *.sim (scripts/test-tooling.py)
set -uo pipefail
cd "$(dirname "$0")/.."

sim=.build/debug/arbor-sim
[ -x "$sim" ] || { echo "run swift build first"; exit 2; }

# Checked: with an empty name arbor-sim would take ARBOR_HOME for unset and write where this script does not look.
traces=$(mktemp -d) && [ -d "$traces" ] || { echo "cannot make a temporary folder for the traces"; exit 2; }
trap 'rm -rf "$traces"' EXIT

failed=0
for file in "${ARBOR_SCENARIOS:-collab/scenarios}"/*.sim; do
  output=$("$sim" < "$file" 2>&1)
  code=$?
  name=$(basename "$file")
  expectations=$(grep -c '^> expect' <<<"$output")
  if [ "${VERBOSE:-}" = 1 ]; then
    echo "=== $name"
    echo "$output"
  fi
  if [ $code -ne 0 ] || grep -q "EXPECTATION FAILED" <<<"$output"; then
    failed=1
    echo "✘ $name (exit $code)"
    grep -B1 "EXPECTATION FAILED" <<<"$output" | grep -v '^--$' | sed 's/^/    /'
    grep -E "COMMAND FAILED|MOVED TWICE|LAYOUT OUT OF DATE" <<<"$output" | sed 's/^/    /'
    continue
  elif [ "$expectations" -eq 0 ]; then
    failed=1
    echo "✘ $name (it expects nothing, so it can never fail)"
    continue
  fi
  rm -rf "$traces/traces"
  { echo "quiet"; echo "trace on scenario"; cat "$file"; echo; echo "flush"; echo "trace off"; } \
    | ARBOR_HOME="$traces" "$sim" > /dev/null 2>&1
  if replay=$("$sim" replay "$traces"/traces/*.jsonl --strict 2>&1); then
    echo "✔ $name ($expectations expectations; replayed from a trace)"
  else
    failed=1
    echo "✘ $name: its trace does not replay as recorded (docs/TRACES.md, \"When a replay of a scenario fails\")"
    sed -n '/problem(s):/,$p' <<<"$replay" | sed 's/^/    /'
  fi
done
exit $failed
