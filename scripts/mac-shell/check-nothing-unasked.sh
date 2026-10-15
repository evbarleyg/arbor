#!/bin/bash
# Nothing is drawn that was not asked for (collab/QUESTIONS.md, Q29, 6; board 0.7), looked at on a real Mac with real apps, Arbor as it ships.
#
#   scripts/mac-shell/run.sh scripts/mac-shell/check-nothing-unasked.sh          on one of GitHub's Macs, from anywhere: ten minutes
#
# The question only a Mac can answer: what does the SCREEN show? Linux knows what the controller asks the presenter for; it cannot
# know how wide macOS makes the menu bar item for each of its signs, nor whether a panel of Arbor's comes up all the same.
#
# 1. ONE ICON, ONE WIDTH. After each thing that used to change the item (a dock, a second one, a window framed, a view saved, the view held, Arbor
#    holding still, a pause, everything floating) the item's frame is read from the window server and a picture of the menu bar
#    is taken (item-<nn>-<state>.png). Every frame has to have the size of the first. (Its place is macOS's: the clock beside it changes its width.)
# 2. NO RING, NO CARD, NO BACKDROP. The sampler writes down every window on the screen sixty times a second, Arbor's own panels among them. In all of
#    the run none of them may be a stage (a panel over the whole display), a ring (an ordinary-level panel that reaches a little beyond
#    another app's window on all four sides) or a backdrop (a panel far below the ordinary level).
#    Reduce Motion is OFF, as a person's Mac comes, so that it is Arbor's own default that keeps the stage away.
# 3. EACH WINDOW MOVES ONCE. Every act is a step of lib-walk.sh's, so jolts.py judges it as it judges the day: `jolt`, `moved-unasked`, `lost`.
#    With no stage nothing is covered: every move of every real window shows, and is judged.
# 4. NO EMPTY DESK. With no stage nothing covers the time between the moment the windows are out of the way and the moment their tiles are drawn.
#    On a hosted Mac that was 400 ms for four first tiles, all of it spent on the apps' icons, which are now got ready ahead of time. Every
#    chapter is a trace, so for every command it is known how long Arbor was busy after its last move (busy-after-the-last-move.txt).
#    That is Arbor's own view. The screen's is in the samples: for every step in which tiles came, how long after the last window had
#    moved the first and the last of them were there (tiles-after-the-windows.txt). Measured, not yet held to a number: on the first run
#    5 ms for the first tile of the day, and 899 ms at Arrange Windows, where the main thread drew tiles of new sizes for the first time.
# 5. THE OPTIONS STILL WORK. At the end each is switched on by command, and is then seen: a ring, a backdrop, a wider item, a stage.
#
# What comes back: the pictures, items.txt (one line per state: its name and the item's frame), arbors-panels.txt (every panel of Arbor's that
# was ever on screen: layer and size, and how often it came or changed), day-report.md and samples.log as after any walk.
#
# Only on GitHub's Macs, like every walk.
WALK_REDUCE_MOTION=off
WALK_KIND=hunt
source "$(dirname "${BASH_SOURCE[0]}")/lib-walk.sh"
[ -z "${ARBOR_REHEARSAL:-}" ] || { echo "a walk is among real apps, and the fake Mac has none: this cannot be rehearsed"; exit 77; }

ITEM_COUNT=0
ITEM_FIRST=""
# bar <name>: a picture of the right end of the menu bar, at full resolution.
bar() {
  if on_throwaway_mac; then screencapture -x -R "$((WALK_X + WALK_W - 560)),$WALK_Y,560,40" "$ARBOR_OUT/$1.png" && echo "shot: mac-shell/$1.png"; fi
}
# item <state>: where the menu bar item is now, written down, pictured, and held to the size it had at first. Not to the place: macOS lays the
# items out from the right, and the clock beside them is wider at 10:00 than at 9:59.
item() {
  local frame size
  ITEM_COUNT=$((ITEM_COUNT + 1))
  sleep "${ARBOR_SETTLE:-0.7}"
  frame=$(status_item_frame) || frame=""
  echo "$1 ${frame:-none}" >> "$ARBOR_OUT/items.txt"
  echo "the item, $1: ${frame:-none}"
  bar "item-$(printf '%02d' "$ITEM_COUNT")-$1"
  check "$1: Arbor says it shows a single icon" single_icon
  size=$(echo "$frame" | awk '{ print $3, $4 }')
  [ -n "$ITEM_FIRST" ] || ITEM_FIRST=$size
  check "$1: the item is as wide and as high as it was at first ($ITEM_FIRST)" test -n "$size" -a "$size" = "$ITEM_FIRST"
}
single_icon() { "$ARBOR_BIN/arborctl" menu-bar | grep -q "single icon"; }

# Arbor's panels, as jolts.py and shots-F15.sh know them: a stage is at level 4 and covers the display, a backdrop lies just above the Desktop's icons.
# panels_in_the_samples <from line>: `<layer> <w>x<h> <times>` for every size of panel of Arbor's that was on the screen from that line of the samples on.
panels_in_the_samples() {
  tail -n "+$1" "$DAY_SAMPLES" | awk -v pid="$ARBOR_PID" '$2 == "W" && $4 == pid { seen[$5 " " $8 "x" $9]++ } END { for (panel in seen) print panel, seen[panel] }' | sort -n
}
# Of those: the stages and the backdrops.
stages_in() { awk -v w="$WALK_W" -v h="$WALK_H" '{ split($2, size, "x") } $1 == 4 && size[1] >= 0.95 * w && size[2] >= 0.95 * h'; }
backdrops_in() { awk '$1 < -1000'; }
# rings_in_the_samples <from line>: each panel of Arbor's that was a ring at some moment from that line on, with the window it was round. Tiles and the
# welcome window are at the level of ordinary windows too, and as large. What makes a ring is what it is round: another app's window, which it
# reaches beyond by 1 to 20 points on all four sides. (A tile that fades out over the window it stood in for is as large as that window, to the point.)
rings_in_the_samples() {
  python3 - "$DAY_SAMPLES" "$ARBOR_PID" "$1" << 'END'
import sys
path, arbor, start = sys.argv[1], sys.argv[2], int(sys.argv[3])
frames, found = {}, {}
for number, line in enumerate(open(path), 1):
    field = line.split()
    if len(field) >= 9 and field[1] == "W":
        frames[field[2]] = (field[3], int(field[4])) + tuple(float(value) for value in field[5:9])
    elif len(field) >= 3 and field[1] == "G":
        frames.pop(field[2], None)
    else:
        continue
    if number < start:
        continue
    for panel, (pid, layer, x, y, w, h) in frames.items():
        if pid != arbor or layer != 0 or panel in found:
            continue
        for window, (other, level, a, b, c, d) in frames.items():
            if other != arbor and level == 0 and all(1 <= beyond <= 20 for beyond in (a - x, b - y, x + w - a - c, y + h - b - d)):
                found[panel] = f"line {number}: panel {panel} at {x:g},{y:g} {w:g}x{h:g} is round window {window} at {a:g},{b:g} {c:g}x{d:g}"
print("\n".join(found.values()))
END
}
# busy <trace…>: for every command that moved a window, how long Arbor went on being busy after its last move, and how long it took to get there.
busy() {
  python3 - "$@" << 'END'
import json, sys
for path in sys.argv[1:]:
    command = None
    for line in open(path):
        try:
            entry = json.loads(line)
        except ValueError:
            continue
        if "command" in entry:
            command, began, last = entry["command"], entry["t"], None
        elif command and entry.get("call") == "setFrame":
            last = entry["t"]
        elif command and "done" in entry:
            if last is not None:
                print(f"{round((entry['t'] - last) * 1000)} ms after its last move, which came {round((last - began) * 1000)} ms after it was asked: {command}")
            command = None
END
}
# tiles_after_the_windows: for every step in which a tile came up (a panel of Arbor's at the level of ordinary windows, and no handle in a gap, which is 12
# points across): how long the desk was empty, from the step's last move of another app's window to the first tile and to the last.
# (A panel that is wholly transparent is not on the screen yet, by the sampler.)
tiles_after_the_windows() {
  python3 - "$DAY_SAMPLES" "$ARBOR_PID" << 'END'
import sys
path, arbor = sys.argv[1], sys.argv[2]
step, moved, seen, known = None, None, [], set()
def say():
    if step and moved is not None and seen:
        print(f"{max(0, seen[0] - moved)} ms until the first of {len(seen)}, {max(0, seen[-1] - moved)} ms until the last: {step}")
for line in open(path):
    field = line.split()
    if len(field) >= 5 and field[1] == "M" and field[2] == "begin":
        say()
        step, moved, seen = " ".join(field[3:]), None, []
    elif len(field) >= 9 and field[1] == "W" and field[4] == "0":
        if field[3] != arbor:
            moved = int(field[0]) if field[2] in known else moved
        elif field[2] not in known and min(float(field[7]), float(field[8])) > 12:
            seen.append(int(field[0]))
        known.add(field[2])
    elif len(field) >= 3 and field[1] == "G":
        known.discard(field[2])
say()
END
}
none_of() { local found; found=$("$@"); [ -z "$found" ] || { echo "$found" | head -n 3; return 1; }; }
some_of() { [ -n "$("$@")" ]; }

walk_begin stock laptop defaults
: > "$ARBOR_OUT/items.txt"
item nothing-docked

chapter "Docks and moves of the view, as Arbor ships"
switch_to finder;  dock_key left;   item one-docked
switch_to safari;  dock_key right;  item two-docked
switch_to textedit;  dock_key right;  item three-docked
switch_to safari
view frame;  item framed
save_view 1;  item a-view-saved
view all;  item everything
view_n 1;  item at-the-saved-view
view back
view desktop;  item the-desktop
view all

chapter "Every window at once: most of them become tiles"
walk_act dock-key arrange "chooses Arrange Windows";  must ctl arrange;  changed;  acted moves=any tiles=ok
item everything-arranged
"$ARBOR_BIN/arborctl" status

chapter "What the one icon says"
walk_act way-out hold "holds the view";  must ctl hold;  acted;  item held
walk_act way-out release "lets it go";  must ctl release;  acted moves=any
walk_act way-out hold-still "asks Arbor to hold still";  must ctl hold still;  acted;  item holding-still
walk_act way-out release-again "lets it go";  must ctl release;  acted moves=any
pause;  item paused
resume;  item resumed
float_all;  item everything-floats

step "what was on the screen meanwhile"
panels_in_the_samples 1 > "$ARBOR_OUT/arbors-panels.txt"
echo "every panel of Arbor's that was on the screen (layer, size, samples):"
cat "$ARBOR_OUT/arbors-panels.txt"
check "the sampler saw panels of Arbor's at all, or it proves nothing" test -s "$ARBOR_OUT/arbors-panels.txt"
check "none of them was a stage" none_of stages_in < "$ARBOR_OUT/arbors-panels.txt"
check "none of them was ever round a window: no ring" none_of rings_in_the_samples 1
check "none of them was a backdrop" none_of backdrops_in < "$ARBOR_OUT/arbors-panels.txt"
check "the item had one size in all $ITEM_COUNT states" test "$(awk '{ print $(NF - 1), $NF }' "$ARBOR_OUT/items.txt" | sort -u | wc -l | tr -d ' ')" = 1

step "how long the desk was empty"
# The chapter's trace is closed, so that all of it can be read.
"$ARBOR_BIN/arborctl" trace off > /dev/null 2>&1
busy "$ARBOR_HOME"/traces/*.jsonl | sort -rn > "$ARBOR_OUT/busy-after-the-last-move.txt"
head -n 12 "$ARBOR_OUT/busy-after-the-last-move.txt"
echo "got ready ahead of time, by Arbor's log: $(grep -c "got ready the costume of" "$ARBOR_HOME/arbor.log") apps, $(grep -c "got ready the stage of" "$ARBOR_HOME/arbor.log") stages"
tiles_after_the_windows > "$ARBOR_OUT/tiles-after-the-windows.txt"
echo "by the screen: how long the desk was empty, from the last window's move to the tiles:"
cat "$ARBOR_OUT/tiles-after-the-windows.txt"
check "commands that moved windows were traced, or this proves nothing" test -s "$ARBOR_OUT/busy-after-the-last-move.txt"
check "the apps' colours and icons were got ready ahead of time" grep -q "got ready the costume of" "$ARBOR_HOME/arbor.log"
check "and no stage" fails grep -q "got ready the stage of" "$ARBOR_HOME/arbor.log"
check "no command kept the desk waiting 200 ms after its last move" test "$(head -n 1 "$ARBOR_OUT/busy-after-the-last-move.txt" | cut -d ' ' -f 1)" -lt 200

chapter "Each is an option still"
OPTIONS_FROM=$(($(wc -l < "$DAY_SAMPLES") + 1))
switch_to finder;  dock_key left
walk_act way-out ring-on "switches the focus ring on";  must ctl set focusRing true;  acted
sleep 1
check "there is a ring now, by the very look that found none before" some_of rings_in_the_samples "$OPTIONS_FROM"
shot option-ring
walk_act way-out backdrop-on "darkens the wallpaper behind docked windows";  must ctl set dimBehindArranged 0.25;  acted
shot option-backdrop
walk_act way-out buttons-on "switches the buttons on";  must ctl set menuBarControls true;  acted
check "Arbor says it shows buttons" eventually fails single_icon
sleep "${ARBOR_SETTLE:-0.7}"
echo "the item, with buttons: $(status_item_frame)"
check "and the item is wider than the icon" test "$(status_item_frame | awk '{ print int($3) }')" -gt "$(echo "$ITEM_FIRST" | awk '{ print int($1) }')"
bar item-option-buttons
walk_act way-out motion-on "switches the motion on";  must ctl set animationDuration 0.46;  acted
switch_to safari;  dock_key right
view frame
view all
panels_in_the_samples "$OPTIONS_FROM" > "$ARBOR_OUT/arbors-panels-with-the-options.txt"
check "with the motion on a stage was seen" some_of stages_in < "$ARBOR_OUT/arbors-panels-with-the-options.txt"
check "and with the darkening a backdrop" some_of backdrops_in < "$ARBOR_OUT/arbors-panels-with-the-options.txt"
for key in focusRing dimBehindArranged menuBarControls animationDuration; do
  walk_act way-out "reset-$key" "puts $key back";  must ctl reset "$key";  acted
done
item back-as-it-ships

walk_end
