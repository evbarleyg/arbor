#!/bin/bash
# Who holds a press back? With Arbor running, presses on windows' title bars were seen to reach the apps 35 to 68 ms late (13 of 192 presses and releases in an ordinary
# day; without Arbor one stray in 84). This asks which of Arbor's event taps it is, or whether it is none.
#
#   scripts/mac-shell/run.sh scripts/mac-shell/probe-presses.sh          six minutes
#
# Real apps and an arrangement as in the day. Then the same two dozen clicks on three title bars, four times over: with Arbor's settings as they ship; without the
# rectangle's taps (`frameRectangleModifier` none, `frameRectangleOnDesktop` false); with no event tap at all (`scrollZoom` and `gesturesEnabled` false as well); and after
# Quit, which is the same Mac without Arbor. A listen-only tap at the far end of the session's taps writes down how late each press and release arrived
# (witness.swift log). After each round: Arbor's taps as the window server lists them, with what each has cost by the window server's own count.
#
# What comes back: presses.txt, the table; witness.log; taps-<round>.txt.
#
# Only on GitHub's Macs, as every journey (lib-walk.sh asks).
WALK_KIND=hunt
source "$(dirname "${BASH_SOURCE[0]}")/lib-walk.sh"

walk_begin stock laptop defaults
day_manifest settings '"changed in the course of the run"'
switch_to finder;  dock_key left
switch_to safari;  dock_key right
view all

ROUNDS=""
# round <name> <what it is>: two dozen clicks, and which lines of the witness's log are theirs.
round() {
  local name=$1 from turn app
  chapter "$2"
  echo "Arbor's taps before:"
  "$DAY_WITNESS" taps | grep "pid=${ARBOR_PID:-none} " | sed 's/^/  /'
  from=$(($(wc -l < "$ARBOR_OUT/witness.log") + 1))
  for turn in 1 2 3 4 5 6 7 8; do
    for app in finder safari calendar; do switch_click "$app"; done
  done
  ROUNDS="$ROUNDS $name:$from:$(wc -l < "$ARBOR_OUT/witness.log" | tr -d ' ')"
  "$DAY_WITNESS" taps > "$ARBOR_OUT/taps-$name.txt"
  echo "Arbor's taps after:"
  grep "pid=${ARBOR_PID:-none} " "$ARBOR_OUT/taps-$name.txt" | sed 's/^/  /'
}
with() {
  printf '%s\n' "$1" > "$ARBOR_HOME/settings.json"
  ctl reload-settings
  sleep 1
}

round shipped "Arbor's settings as they ship"
with '{"frameRectangleModifier": "none", "frameRectangleOnDesktop": false}'
round no-rectangle "Without the rectangle's taps"
with '{"frameRectangleModifier": "none", "frameRectangleOnDesktop": false, "scrollZoom": false, "gesturesEnabled": false}'
round no-taps "With no event tap at all"
with '{}'
round shipped-again "As they ship, once more: is it the settings, or the time of day?"
walk_quit
round without-arbor "After Quit: the same Mac without Arbor"

step "the table"
python3 - "$ARBOR_OUT/witness.log" $ROUNDS << 'PYTHON' | tee "$ARBOR_OUT/presses.txt"
import sys
lines = open(sys.argv[1], encoding="utf-8", errors="replace").read().splitlines()
print(f"{'round':<16}{'what':<6}{'n':>4}{'half within':>13}{'9 in 10':>10}{'the latest':>12}{'over 20 ms':>12}   (ms)")
for word in sys.argv[2:]:
    name, first, last = word.split(":")
    for what in ("down", "up"):
        late = sorted(int(parts[3]) / 1000 for parts in (line.split() for line in lines[int(first) - 1:int(last)]) if len(parts) > 3 and parts[1] == "E" and parts[2] == what)
        if late:
            print(f"{name:<16}{what:<6}{len(late):>4}{late[len(late) // 2]:>13.1f}{late[len(late) * 9 // 10]:>10.1f}{late[-1]:>12.1f}{sum(each > 20 for each in late):>12}")
PYTHON
walk_end
