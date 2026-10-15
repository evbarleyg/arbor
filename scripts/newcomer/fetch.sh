#!/bin/bash
# Brings back what a run of the newcomer's eval left: .newcomer/<run>/, with journal.jsonl, which score.py reads.
#
#   scripts/newcomer/fetch.sh <run>…          while a run is under way: the journal so far
#
# Git alone. The branches go by themselves after a day (scripts/housekeeping.py).
set -euo pipefail
cd "$(dirname "$0")/../.."
[ $# -gt 0 ] || { echo "usage: scripts/newcomer/fetch.sh <run>…" >&2; exit 64; }
for run in "$@"; do
  [[ "$run" =~ ^[A-Za-z0-9-]{1,20}$ ]] || { echo "fetch.sh: '$run' is no run's name" >&2; exit 64; }
  git fetch --quiet --no-tags --depth 1 origin "+refs/heads/mac-shell-out/newcomer.$run.record:refs/newcomer/$run" \
    || { echo "fetch.sh: $run has left no record (yet)" >&2; exit 1; }
  rm -rf ".newcomer/${run:?}"
  mkdir -p ".newcomer/$run"
  git archive "refs/newcomer/$run" | tar -x -C ".newcomer/$run"
  git update-ref -d "refs/newcomer/$run"
  echo ".newcomer/$run: $(git -C . log -1 --format=%s FETCH_HEAD)"
done
