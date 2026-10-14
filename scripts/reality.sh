#!/bin/bash
# `make reality`: how far are the stand-ins from a real Mac? One number, to bring down to zero (docs/TESTING.md, "Reality").
#
#   make reality                              rehearse scripts/mac-shell/reality.sh here, run it on a hosted Mac, compare
#   make reality MAC=.mac-shell/reality-123   compare with an earlier run on a Mac: seconds instead of a quarter of an hour
#   make reality MAC="<run> <another run>"    with several: what differs between the Macs' own runs is counted apart, as unstable
#   make reality MAC=… CHECK=1                exit code 1 for a divergence that collab/evidence/reality-known.txt does not have, or has and is gone
#   make reality MAC=… KNOWN=1                write that list anew, keeping the words of the keys it has
#
# On Linux only, as rehearsals are. A run on a Mac needs the branch pushed, and `gh` (scripts/mac-shell/run.sh). A folder may be the run's own or the
# `reality` folder inside it. The report is also left in .build/reality/report.md, the rehearsal's observations in .build/reality/linux.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 2

known=collab/evidence/reality-known.txt
work=.build/reality
mkdir -p "$work"

echo "rehearsing scripts/mac-shell/reality.sh"
if ! scripts/mac-shell/rehearse.sh scripts/mac-shell/reality.sh > "$work/rehearsal.txt" 2>&1; then
  tail -n 30 "$work/rehearsal.txt"
  echo "reality.sh: the rehearsal failed; all of what it said is in $work/rehearsal.txt" >&2
  exit 2
fi
rm -rf "$work/linux"
cp -R .build/rehearsal/out/reality "$work/linux"

# shellcheck disable=SC2206
macs=(${MAC:-})
if [ ${#macs[@]} -eq 0 ]; then
  echo "running it on a hosted Mac: five to twenty-five minutes, most of them waiting for one"
  scripts/mac-shell/run.sh scripts/mac-shell/reality.sh > "$work/mac.txt" 2>&1
  folder=$(sed -n 's/^output: //p' "$work/mac.txt" | tail -n 1)
  if [ -z "$folder" ] || [ ! -d "$folder/reality" ]; then
    tail -n 30 "$work/mac.txt"
    echo "reality.sh: the Mac brought no observations back; all of what run.sh said is in $work/mac.txt" >&2
    exit 2
  fi
  echo "the Mac's run: $folder (make reality MAC=$folder compares with it again)"
  macs=("$folder")
fi

arguments=()
for folder in "${macs[@]}"; do
  [ -d "$folder/reality" ] && folder="$folder/reality"
  if [ -z "$(ls "$folder"/*.jsonl 2>/dev/null)" ]; then
    echo "reality.sh: no observations (<journey>.jsonl) in $folder" >&2
    exit 2
  fi
  if [ ${#arguments[@]} -eq 0 ]; then arguments=("$folder" "$work/linux"); else arguments+=(--also "$folder"); fi
done
[ -f "$known" ] && arguments+=(--known "$known")
[ -n "${CHECK:-}" ] && arguments+=(--check)
[ -n "${KNOWN:-}" ] && arguments+=(--write-known "$work/known.txt")
python3 scripts/reality-diff.py "${arguments[@]}" --markdown "$work/report.md"
code=$?
if [ -n "${KNOWN:-}" ] && [ -s "$work/known.txt" ]; then
  cp "$work/known.txt" "$known"
  echo "wrote $known: give every line that ends in ? a word on what it is"
fi
exit "$code"
