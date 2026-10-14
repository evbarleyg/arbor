#!/bin/bash
# Records a trace from the running Arbor (docs/TRACES.md): turns recording on, waits while you do the
# thing, turns it off, checks that nothing private is in the file, and copies it to
# collab/evidence/traces/<name>.jsonl, where the tests replay it.
#
#   make trace NAME=safari-drag            # until you press return
#   make trace NAME=safari-drag FOR=15     # for 15 seconds, for whoever cannot press return
#   ./scripts/trace.sh safari-drag [seconds]
#
# Needs Arbor running (make run, or the installed app) with Accessibility.
set -uo pipefail
cd "$(dirname "$0")/.."

name=${1:-}
seconds=${2:-}
case "$name" in
  "" | *[!A-Za-z0-9._-]*) echo "usage: make trace NAME=<name>, e.g. safari-drag (letters, digits, dots, dashes)"; exit 2 ;;
esac
ctl=.build/debug/arborctl
[ -x "$ctl" ] || { echo "run swift build first"; exit 2; }

started=$("$ctl" trace on "$name") || { echo "$started"; exit 1; }
echo "$started"
path=$(sed -n 's/^recording \(.*\.jsonl\): .*$/\1/p' <<<"$started")
[ -n "$path" ] || { echo "could not read the trace's path from Arbor's reply"; "$ctl" trace off; exit 1; }

if [ -n "$seconds" ]; then
  echo "Do the thing (drag, resize, switch Spaces…) now: recording for $seconds seconds."
  sleep "$seconds"
else
  echo "Do the thing (drag, resize, switch Spaces…), then press return."
  read -r
fi
"$ctl" trace off || exit 1

echo
python3 scripts/trace-check.py "$path" || { echo "not copied: $path"; exit 1; }
mkdir -p collab/evidence/traces
target="collab/evidence/traces/$name.jsonl"
cp "$path" "$target"
echo
echo "saved $target ($(wc -l < "$target" | tr -d ' ') lines). See what it holds with"
echo "  make replay FILE=$target"
echo "then say what it shows in collab/evidence/traces/README.md and commit both."
