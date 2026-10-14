#!/bin/bash
# PROBE, not to be merged: arbor-e2e as CI runs it (through ci-step.py) and then plainly, to see which of the two the switch of apps fails in.
set -uo pipefail
cd "$(dirname "$0")/../.." || exit 2
mkdir -p mac-shell
swift build > mac-shell/build.log 2>&1 || { grep "error:" mac-shell/build.log | sort -u | head -n 40; exit 2; }
for way in plain plain plain; do
  echo "=== $way"
  if [ "$way" = ci ]; then ./scripts/ci-step.py e2e ./scripts/e2e.sh --full-screen > "mac-shell/run-$way-$RANDOM.txt" 2>&1
  else ./scripts/e2e.sh --full-screen > "mac-shell/run-$way-$RANDOM.txt" 2>&1; fi
  echo "exit $?"
done
grep -h "✘\|↳" mac-shell/run-*.txt | sort | uniq -c | head -n 120
grep -c "✘" mac-shell/run-*.txt
exit 0
