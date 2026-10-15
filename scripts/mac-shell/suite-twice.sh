#!/bin/bash
# The flakiness test: the real-window suite twice in one run, and what differed between the two rounds.
#
#   scripts/mac-shell/run.sh scripts/mac-shell/suite-twice.sh
#
# Evidence carries no window ids or times apart from its first line, so two rounds that went the same way differ in
# nothing else. A step that passes in one round and fails in the other is worse than no step: fix it or drop it.
# The first round's evidence is kept in mac-shell/evidence-round-1/; the second round's is what counts.
#
# Exit code: the second round's, or 3 when both passed but differed.
source "$(dirname "$0")/lib.sh"
needs_throwaway_mac "keep the pointer and the keyboard for longer than a curtain hangs and a run's record is believed"

"$BASH" scripts/mac-shell/suite.sh "$@"
first=$?
[ "$first" -lt 2 ] || exit "$first"
mkdir -p "$ARBOR_OUT/evidence-round-1"
cp "$ARBOR_OUT"/evidence/*.txt "$ARBOR_OUT/evidence-round-1/"

echo
echo "=== the second round"
"$BASH" scripts/mac-shell/suite.sh "$@"
second=$?

echo
echo "=== what differed between the rounds (< the first, > the second)"
# Without the first line (the time) and the reasons of failed checks (coordinates, window ids).
bare() { tail -n +2 "$1" 2>/dev/null | sed 's/ — .*//'; }
differences=0
for file in "$ARBOR_OUT"/evidence/*.txt; do
  name=$(basename "$file")
  if ! diff <(bare "$ARBOR_OUT/evidence-round-1/$name") <(bare "$file") > "$ARBOR_OUT/difference.txt"; then
    differences=$((differences + 1))
    echo "--- $name"
    cat "$ARBOR_OUT/difference.txt"
  fi
done
rm -f "$ARBOR_OUT/difference.txt"
echo "rounds: exit codes $first and $second, $differences section(s) differed"
[ "$second" -ne 0 ] && exit "$second"
[ "$differences" -eq 0 ] || exit 3
