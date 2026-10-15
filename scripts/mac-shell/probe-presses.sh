#!/bin/bash
# Who holds a press back? In an ordinary day with Arbor, presses on windows' title bars reached the apps 35 to 69 ms late; in runs without Arbor hardly any did. It looked like a
# fault of Arbor's. **It is macOS's own doing**: a press on a window of an app that is not in front is passed on only when macOS has brought the app forward, and the day was full of
# such presses while the runs without Arbor had two. This is the probe that said so, kept for the next time somebody suspects a tap.
#
#   scripts/mac-shell/run.sh scripts/mac-shell/probe-presses.sh          six minutes
#
# Real apps, Finder and Safari docked side by side. Then the same sixteen clicks on their two title bars in turn, each of which brings the other app forward, round after
# round: with Arbor as it ships; without a trace being recorded; without the line round the focused window; with no event tap at all; paused; and after Quit, which is the
# same Mac without Arbor. **A pause and a Quit give every window its own frame back, and then one window covers the others and every click falls on the app that is in
# front already, which is quick anyway** (the first run of this probe had such a baseline, worth nothing). So after both, every window is put back where it was
# while Arbor arranged them, and a round says of how many of its presses another app came forward.
# A listen-only tap at the far end of the session's taps writes down how late each press and release arrived (witness.swift log).
#
# What it answered on hosted Macs on 2026-10-15, half of the presses within so many ms. First run: 38, 35, 35, 35 as shipped, without the rectangle's taps, with no tap of Arbor's in the window
# server's list, as shipped again: it is no event tap. Second run, on a slower Mac: 51 as shipped, 41 without a trace, 42 without the line, 57 without taps, 60 paused, 61 as shipped again, and
# 77 without Arbor.
#
# What comes back: presses.txt, the table; witness.log; taps-<round>.txt, the taps as the window server lists them.
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
# Where every window of the cast is now, to be put back there when nobody arranges them any more.
ARRANGED=""
for name in $WALK_CAST; do ARRANGED="$ARRANGED $(window_of "$name"):$(real_of "$(window_of "$name")" | tr ' ' ':')"; done
arrange() {
  local each
  for each in $ARRANGED; do
    # shellcheck disable=SC2046
    apptool set-frame $(echo "$each" | tr ':' ' ') > /dev/null
  done
  sleep 1
}
# round <name> <what it is>: sixteen clicks, and which lines of the witness's log are theirs.
round() {
  local name=$1 from turn app
  echo "Arbor's taps:"
  "$DAY_WITNESS" taps | grep "pid=${ARBOR_PID:-none} " | sed 's/^/  /'
  from=$(($(wc -l < "$ARBOR_OUT/witness.log") + 1))
  for turn in 1 2 3 4 5 6 7 8; do
    for app in finder safari; do switch_click "$app"; done
  done
  ROUNDS="$ROUNDS $name:$from:$(wc -l < "$ARBOR_OUT/witness.log" | tr -d ' ')"
  "$DAY_WITNESS" taps > "$ARBOR_OUT/taps-$name.txt"
}
with() {
  printf '%s\n' "$1" > "$ARBOR_HOME/settings.json"
  ctl reload-settings
  sleep 1
}

chapter "Arbor as it ships"
round shipped
chapter "Without a trace being recorded"
ctl trace off
round no-trace
chapter "Without the line round the focused window"
with '{"focusRing": false}'
round no-line
chapter "With no event tap at all"
with '{"frameRectangleModifier": "none", "frameRectangleOnDesktop": false, "scrollZoom": false, "gesturesEnabled": false}'
round no-taps
with '{}'
chapter "Paused, the windows put back where they were"
pause
arrange
round paused
resume
chapter "As it ships, once more: is it the settings, or the time of day?"
view all
round shipped-again
walk_quit
chapter "After Quit, the windows put back where they were: the same Mac without Arbor"
arrange
round without-arbor

step "the table"
python3 - "$ARBOR_OUT/witness.log" "$ARBOR_OUT/samples.log" $ROUNDS << 'PYTHON' | tee "$ARBOR_OUT/presses.txt"
import sys
lines = open(sys.argv[1], encoding="utf-8", errors="replace").read().splitlines()
# When another app came to the front, by the samples.
front = [int(parts[0]) for parts in (line.split() for line in open(sys.argv[2], encoding="utf-8", errors="replace")) if len(parts) > 2 and parts[1] == "A"]
print(f"{'round':<16}{'what':<9}{'n':>4}{'half within':>13}{'9 in 10':>10}{'the latest':>12}{'over 20 ms':>12}   (ms; presses that brought another app forward, other presses, releases)")
for word in sys.argv[3:]:
    name, first, last = word.split(":")
    events = [(int(parts[0]), parts[2], int(parts[3]) / 1000) for parts in (line.split() for line in lines[int(first) - 1:int(last)]) if len(parts) > 3 and parts[1] == "E"]
    forward = lambda time: any(time - 100 <= other <= time + 400 for other in front)  # noqa: E731
    for what, late in (("forward", sorted(late for time, kind, late in events if kind == "down" and forward(time))),
                       ("same app", sorted(late for time, kind, late in events if kind == "down" and not forward(time))),
                       ("release", sorted(late for time, kind, late in events if kind == "up"))):
        if late:
            print(f"{name:<16}{what:<9}{len(late):>4}{late[len(late) // 2]:>13.1f}{late[len(late) * 9 // 10]:>10.1f}{late[-1]:>12.1f}{sum(each > 20 for each in late):>12}")
PYTHON
walk_end
