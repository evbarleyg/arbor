#!/bin/bash
# From a small display to a large one, on real macOS: the small one is virtual (lib.sh's display_add, vdisplay.m).
#
#   MAC_SHELL_TIMEOUT=5400 scripts/mac-shell/run.sh --priority 1 scripts/mac-shell/check-across-displays.sh
#
# Right after a position call has taken a window to another display, macOS judges a size call by the display the window came from. Seen on hosted
# Macs: sent from 1280×720 to 1920×1080 a docked window asked to be 947 high took 677, twice within 2 ms; Arbor then centred it in its slot and
# wrote the short size down, and so it lay. Arbor makes nothing of such an answer now and asks again when macOS has caught up
# (Controller+AcrossDisplays.swift). The stand-ins play the rule as it was measured. The questions only a Mac can answer:
#   1. Sent across by the command: is the window whole within about a second, in ONE further change, never anywhere but at its slot's corner?
#   2. Let go by hand on the large display, near the border, with its larger part still over the small one: the same?
#   3. Is anything written down of where it stopped? (The header of a trace begun afterwards holds what Arbor has learnt of each window's sizes.)
#   4. Sent back to the large display and let go of at once (two commands as fast as they can be sent), and sent across floating: has it its own
#      size, to the point, and still when it is docked and floated again long after?
#   5. The other way, from the large display to the small one: straight into its slot?
#
# What comes back: output.txt with every frame each window had on its way, arbor.log, traces/<step>.jsonl (no titles: docs/TRACES.md).
#
# On GitHub's Macs plugging the display in also switches the main one from 1024×768 to 1920×1080.
source "$(dirname "$0")/lib.sh"
needs_throwaway_mac "plug a virtual display in and rearrange the displays, at which macOS moves every window"

TRACES="$ARBOR_OUT/traces"
mkdir -p "$TRACES"

# way <window> <seconds>: prints each frame the window server has for the window from now on, once, with the milliseconds since the call.
way() {
  local id=$1 until last="" now began
  began=$(perl -MTime::HiRes=time -e 'printf "%d", time * 1000')
  until=$((began + $2 * 1000))
  while :; do
    now=$(perl -MTime::HiRes=time -e 'printf "%d", time * 1000')
    [ "$now" -lt "$until" ] || break
    frame=$(real_frame_of "$id" | awk '{ for (i = 1; i <= NF; i++) printf "%d ", $i + 0.5 }')
    if [ "$frame" != "$last" ]; then
      echo "$((now - began)) $frame"
      last=$frame
    fi
  done
}

# judged <file of `way`> <x y w h of the slot>: the measure. Prints why not.
judged() {
  python3 - "$@" << 'PY'
import sys
rows = [[int(n) for n in line.split()] for line in open(sys.argv[1]) if line.strip()]
slot = [int(float(n) + 0.5) for n in sys.argv[2:6]]
near = lambda a, b, by=3: abs(a - b) <= by
there = [row for row in rows if near(row[1], slot[0]) and near(row[2], slot[1])]
why = []
if not rows or not all(near(a, b) for a, b in zip(rows[-1][1:], slot)):
    why.append("it does not end in its slot %s: %s" % (slot, rows[-1][1:] if rows else "nothing seen"))
whole = [row for row in rows if all(near(a, b) for a, b in zip(row[1:], slot))]
# Counted from when it first is at its slot's corner: a drag takes its own time to get there.
if whole and there and whole[0][0] - there[0][0] > 1500:
    why.append("it was whole only %d ms after it came to its slot's corner" % (whole[0][0] - there[0][0]))
# From the first time it is at its slot's corner it is nowhere else.
if there:
    after = rows[rows.index(there[0]):]
    astray = [row for row in after if not (near(row[1], slot[0]) and near(row[2], slot[1]))]
    if astray:
        why.append("it left its slot's corner: %s" % astray)
    if len(after) > 2:
        why.append("more than one further change: %s" % after)
print("; ".join(why) if why else "whole %d ms after it came to its slot's corner, %d frames there" % (whole[0][0] - there[0][0], len(rows) - rows.index(there[0])))
sys.exit(1 if why else 0)
PY
}

# learnt <name>: what Arbor has written down of where each window stopped growing, out of the header of a trace begun now.
learnt() {
  "$ARBOR_BIN/arborctl" trace on "$1" > /dev/null
  "$ARBOR_BIN/arborctl" trace off > /dev/null
  cp "$ARBOR_HOME"/traces/*-"$1".jsonl "$TRACES/$1.jsonl" || { echo "no trace $1"; return 1; }
  python3 - "$TRACES/$1.jsonl" << 'PY'
import json, sys
header = json.loads(open(sys.argv[1]).readline())
def find(value):
    if isinstance(value, dict):
        if "seenSizes" in value:
            return value["seenSizes"]
        for inner in value.values():
            found = find(inner)
            if found is not None:
                return found
    return None
seen = find(header) or {}
# least, most, stoppedAt, closeOffer, closeTook
stopped = {window: sizes[2] for window, sizes in seen.items() if any(sizes[2])} if isinstance(seen, dict) else seen
print("stopped at: %s" % (stopped or "nothing"))
sys.exit(1 if stopped else 0)
PY
}

# across <name> <window> <command…>: records, watches the window from before the command on, for four seconds or $WATCH, and judges its way.
across() {
  local name=$1 id=$2 watcher
  shift 2
  "$ARBOR_BIN/arborctl" trace on "$name" > /dev/null
  way "$id" "${WATCH:-4}" > "$ARBOR_OUT/way-$name.txt" &
  watcher=$!
  "$@"
  wait "$watcher"
  "$ARBOR_BIN/arborctl" trace off > /dev/null
  cp "$ARBOR_HOME"/traces/*-"$name".jsonl "$TRACES/$name.jsonl" || echo "no trace $name"
  echo "its way (ms x y w h):"
  sed 's/^/  /' "$ARBOR_OUT/way-$name.txt"
  echo "its slot: $(slot_of "$id")"
  # shellcheck disable=SC2046
  check "$name: whole within a second and a half, one further change, never off its slot's corner" judged "$ARBOR_OUT/way-$name.txt" $(slot_of "$id")
  sleep 10
  # shellcheck disable=SC2046
  check "$name: and ten seconds later" arbor_close "$(real_frame_of "$id")" "$(slot_of "$id")"
  check "$name: nothing is written down of where it stopped" learnt "$name-learnt"
  check "$name: it did not take the third asking" fails logged "as short as another display would have it"
}

arbor_build
# The drop docks beside a window that lies along the border between the displays, which may be an edge to macOS's own tiling.
macos_tiling off
display_add 1280 720 right
echo "displays (id uuid x y w h scale main vendor model serial):"
"$ARBOR_VDISPLAY" list
arbor_start 3
summary

step "the large display: W3 at its right end, along the border; W1 and W2 go to the small one"
ctl dock "$W3" right
ctl dock "$W1" left
ctl dock "$W2" left
sleep 1
step "5. from the large display to the small one"
across to-the-small-one "$W1" ctl move-to-display next "$W1"
check "it is docked there" is display2 "$W1"
ctl move-to-display next "$W2"
check "so is the second, in its slot" eventually is in_slot "$W2"
sleep 2
summary

# Before the command's journey, which docks W1 along the border and takes W3 away from it.
step "2. let go by hand near the border, held at the left of its title bar: its larger part is still over the small display"
read -r x2 y2 w2 _ <<< "$(real_frame_of "$W2" | awk '{ for (i = 1; i <= NF; i++) printf "%d ", $i + 0.5 }')"
read -r x3 y3 w3 h3 <<< "$(slot_of "$W3" | awk '{ for (i = 1; i <= NF; i++) printf "%d ", $i + 0.5 }')"
border=$((x3 + w3 + 12))
# Held right of the three buttons; let go on the right part of W3, 40 points from its right edge, which lies along the border.
to=$((x3 + w3 - 40))
echo "W2 is $w2 wide, held 90 points from its left edge; W3's slot ends at $((x3 + w3)), the border is at about $border; let go at $to"
check "most of it will hang over the small display" test $((to - 90 + w2 / 2)) -gt "$border"
by_hand() { drag $((x2 + 90)) $((y2 + 12)) "$to" $((y3 + h3 / 2)) --hold 1; }
WATCH=10 across drop "$W2" by_hand
check "it is docked on the large display" is display1 "$W2"
summary

step "1. sent to the large display by the command"
across command "$W1" ctl move-to-display next "$W1"
check "it is docked on the large display" is display1 "$W1"
summary

step "4. its own size, after a journey"
ctl float-all
sleep 2
# Larger than the small display has room for.
tw move "$W1" 300 80 700 850
sleep 1
echo "its own frame: $(real_frame_of "$W1")"
ctl dock "$W1" left
sleep 1
ctl move-to-display next "$W1"
sleep 3
check "it is docked on the small display" is display2 "$W1"
"$ARBOR_BIN/arborctl" trace on own-size > /dev/null
way "$W1" 4 > "$ARBOR_OUT/way-own-size.txt" &
watcher=$!
# As fast as two commands can be sent: within the moment, if a Mac allows.
"$ARBOR_BIN/arborctl" move-to-display next "$W1" > /dev/null
"$ARBOR_BIN/arborctl" float "$W1" > /dev/null
wait "$watcher"
"$ARBOR_BIN/arborctl" trace off > /dev/null
cp "$ARBOR_HOME"/traces/*-own-size.jsonl "$TRACES/own-size.jsonl" || echo "no trace own-size"
echo "its way (ms x y w h):"
sed 's/^/  /' "$ARBOR_OUT/way-own-size.txt"
check "let go of right after the journey: as wide as it was" width_is "$W1" 700
check "and as high" height_is "$W1" 850
ctl dock "$W1" left
sleep 2
ctl float "$W1"
sleep 2
check "docked and floated again: as wide as it was" width_is "$W1" 700
check "and as high: nothing short was written down as its own" height_is "$W1" 850

step "4b. sent across floating, there and back"
ctl move-to-display next "$W1"
sleep 3
echo "floating on the small display it has: $(real_frame_of "$W1")"
way "$W1" 4 > "$ARBOR_OUT/way-floating-back.txt" &
watcher=$!
ctl move-to-display next "$W1"
wait "$watcher"
sed 's/^/  /' "$ARBOR_OUT/way-floating-back.txt"
check "back on the large display it is as wide as it was" width_is "$W1" 700
check "and as high" height_is "$W1" 850
summary

arbor_stop
display_remove
macos_tiling on > /dev/null
