#!/bin/bash
# `make reality`: how far are the stand-ins from a real Mac? One number, to bring down to zero (docs/TESTING.md, "Reality").
#
#   make reality                              rehearse scripts/mac-shell/reality.sh here, run it on a hosted Mac, compare
#   make reality MAC=collab/evidence/reality-mac   compare with the run that was committed: a minute and a half instead of a quarter of an hour
#   make reality MAC=.mac-shell/reality-123   or with any earlier run
#   make reality MAC="<run> <another run>"    with several: what differs between the Macs' own runs is counted apart, as unstable
#   make reality MAC=… CHECK=1                exit code 1 for a divergence that collab/evidence/reality-known.txt does not have, or has and is gone
#   make reality MAC=… KNOWN=1                write that list anew, keeping the words of the keys it has
#   make reality-trunk                        after a batch has landed: REF=swarm/trunk PRIORITY=1 CHECK=1. The Mac plays that branch's head, whatever branch is
#                                             checked out here, as long as the code, the scripts and the list here are what that head has. The last line is the verdict
#                                             PLAY THE HEAD OF A BATCH, NOT A COMMIT IN THE MIDDLE OF ONE: a batch arrives commit by commit, over minutes. So no Mac is
#                                             started before the branch has stood still for three minutes (STILL=0: whoever landed the batch has named this very commit)
#
# On Linux only, as rehearsals are. A run on a Mac needs the branch pushed, and `gh` (scripts/mac-shell/run.sh). A folder may be the run's own or the
# `reality` folder inside it. The report is also left in .build/reality/report.md, the rehearsal's observations in .build/reality/linux.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 2

known=collab/evidence/reality-known.txt
work=.build/reality
mkdir -p "$work"

# First what costs nothing: a slip in MAC should not take a rehearsal to come out.
# shellcheck disable=SC2206
macs=(${MAC:-})
observations=()
for folder in ${macs[@]+"${macs[@]}"}; do
  [ -d "$folder/reality" ] && folder="$folder/reality"
  if [ -z "$(ls "$folder"/*.jsonl 2>/dev/null)" ]; then
    echo "reality.sh: no observations (<journey>.jsonl) in $folder" >&2
    exit 2
  fi
  observations+=("$folder")
done

# The rehearsal plays what lies here and the Mac what GitHub has at REF: compared they say something only if that is the same.
if [ -n "${REF:-}" ]; then
  git fetch -q origin "$REF" 2>/dev/null || echo "reality.sh: note: could not ask origin for $REF, going by what was fetched last" >&2
  if ! git diff --quiet "origin/$REF" -- Package.swift Sources scripts "$known" 2>/dev/null; then
    echo "reality.sh: what lies here is not origin/$REF (Package.swift, Sources, scripts, $known): git switch --detach origin/$REF" >&2
    exit 2
  fi
  if [ ${#observations[@]} -eq 0 ] && [ "${STILL:-180}" -gt 0 ]; then
    echo "waiting ${STILL:-180} s to see that $REF stands still: a run in the middle of a batch says nothing about the batch, and takes a Mac for twenty minutes"
    head=$(git rev-parse "origin/$REF")
    sleep "${STILL:-180}"
    git fetch -q origin "$REF" 2>/dev/null
    if [ "$(git rev-parse "origin/$REF")" != "$head" ]; then
      echo "reality.sh: $REF has moved on meanwhile: git switch --detach origin/$REF, and again" >&2
      exit 2
    fi
  fi
fi

# The Mac first: most of its time is waiting for one, and the rehearsal fits into that.
if [ ${#observations[@]} -eq 0 ]; then
  echo "running it on a hosted Mac: five to twenty-five minutes, most of them waiting for one"
  # shellcheck disable=SC2086
  scripts/mac-shell/run.sh ${PRIORITY:+--priority "$PRIORITY"} scripts/mac-shell/reality.sh ${REF:-} > "$work/mac.txt" 2>&1 &
  mac=$!
fi

echo "rehearsing scripts/mac-shell/reality.sh"
scripts/mac-shell/rehearse.sh scripts/mac-shell/reality.sh > "$work/rehearsal.txt" 2>&1
code=$?
# 1: one of lib.sh's own checks at the end of a session came out ✘. What was written down is whole all the same.
if [ "$code" -gt 1 ]; then
  # The Mac's run goes on, and run.sh's output says where it is: nothing that was waited for is thrown away.
  tail -n 30 "$work/rehearsal.txt"
  echo "reality.sh: the rehearsal failed; all of what it said is in $work/rehearsal.txt" >&2
  exit 2
fi
[ "$code" -eq 0 ] || grep "✘" "$work/rehearsal.txt"
rm -rf "$work/linux"
cp -R .build/rehearsal/out/reality "$work/linux"

if [ ${#observations[@]} -eq 0 ]; then
  wait "$mac"
  folder=$(sed -n 's/^output: //p' "$work/mac.txt" | tail -n 1)
  if [ -z "$folder" ] || [ -z "$(ls "$folder"/reality/*.jsonl 2>/dev/null)" ]; then
    tail -n 30 "$work/mac.txt"
    echo "reality.sh: the Mac brought no observations back; all of what run.sh said is in $work/mac.txt" >&2
    exit 2
  fi
  echo "the Mac's run: $folder (make reality MAC=$folder compares with it again)"
  observations=("$folder/reality")
fi

arguments=("${observations[0]}" "$work/linux")
for folder in "${observations[@]:1}"; do arguments+=(--also "$folder"); done
[ -f "$known" ] && arguments+=(--known "$known")
[ -n "${CHECK:-}" ] && arguments+=(--check)
# Straight over the list: the tool reads it first and puts the new one in its place only when it is whole.
[ -n "${KNOWN:-}" ] && arguments+=(--write-known "$known")
python3 scripts/reality-diff.py "${arguments[@]}" --markdown "$work/report.md" | tee "$work/report.txt"
code=${PIPESTATUS[0]}
# One line to pass on: which commit the Mac played, the verdict, the number. What is new stands above it, a line each (✘ new).
if [ -n "${REF:-}" ]; then
  verdict=green
  [ "$code" -eq 0 ] || verdict=RED
  echo "$REF at $(cut -c 1-7 "${observations[0]}/commit.txt" 2>/dev/null): $verdict: $(tail -n 1 "$work/report.txt" | sed 's/^reality: //')"
fi
[ -n "${KNOWN:-}" ] && [ "$code" -le 1 ] && echo "wrote $known: give every line that ends in ? a word on what it is"
exit "$code"
