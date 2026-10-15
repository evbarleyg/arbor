#!/bin/bash
# One part of a gate: the journey that gate.py's plan has in this place, for the commit that is checked out (docs/VIABLE.md).
#
#   scripts/mac-shell/run.sh scripts/mac-shell/gate.sh scripts/mac-shell/gate.sh        as often as `gate.py plan first` has rows: two user-hours
#   python3 scripts/mac-shell/gate.py plan                                              every row of a whole gate
#
# run.sh hands a script no arguments. It does say which part of how many this playing is ($MAC_SHELL_PART, $MAC_SHELL_PARTS), and that is all this needs:
# how many there are says which dispatch it is (first, rest or whole), the part says which row. A row is a walk, the control of one, a written day, the
# sabotage run or a sit, at one setting of macOS's tiling, on one arrangement of displays, with one cast, with or without Reduce Motion.
#
# A walk is seeded from the commit, so it cannot be a file in it. It is written here, into what the run brings back (walk.txt: one word of lib-walk.sh's a
# line), and the same commit and row give the same walk anywhere: `gate.py row <commit> <part> <parts>`, then `gate.py acts <seed> <display> <acts>`.
#
# It relies on nothing that the script before it on the same Mac left behind: walk_begin sets the display, macOS's tiling, the wallpaper click and Reduce Motion.
#
# Only on GitHub's Macs, as every journey (lib-walk.sh asks).
GATE_HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd) || exit 2
GATE_COMMIT=$(git -C "$GATE_HERE" rev-parse HEAD) || exit 2
GATE_ROW=$(python3 "$GATE_HERE/gate.py" row "$GATE_COMMIT" "${MAC_SHELL_PART:-0}" "${MAC_SHELL_PARTS:-0}") || exit 64
row() { echo "$GATE_ROW" | sed -n "s/^$1=//p"; }
echo "part ${MAC_SHELL_PART:-?} of ${MAC_SHELL_PARTS:-?} of a gate on ${GATE_COMMIT:0:12}: $(row name) ($(row kind), $(row cast), $(row display), macOS's tiling $(row tiling), $(row motion))"

[ "$(row motion)" = moving ] || export WALK_REDUCE_MOTION=on DAY_REDUCE_MOTION=on
if [ "$(row script)" != gate.sh ]; then
  # Written journeys, which take their cell from the environment.
  DAY_DISPLAY=$(row display) DAY_TILING=$(row tiling)
  export DAY_DISPLAY DAY_TILING
  exec "$BASH" "$GATE_HERE/$(row script)"
fi
[ "$(row kind)" != control ] || WALK_WITHOUT_ARBOR=1
source "$GATE_HERE/lib-walk.sh"

python3 "$GATE_HERE/gate.py" acts "$(row seed)" "$(row display)" "$(row acts)" > "$ARBOR_OUT/walk.txt" || die "gate.py did not write the walk"
walk_begin "$(row cast)" "$(row display)" "$(row tiling)" "$(row seed)" "$GATE_COMMIT"
source "$ARBOR_OUT/walk.txt"
walk_end
