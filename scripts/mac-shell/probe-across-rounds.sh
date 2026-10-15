#!/bin/bash
# Five rounds each, from a small display to a large one, on real macOS: by the command, by a hand's drop of a floating window just over the border, and by a
# hand's drop of a docked one. A probe: played at the head and at its base, which is the control.
#
#   MAC_SHELL_TIMEOUT=5400 scripts/mac-shell/run.sh --priority 1 scripts/mac-shell/probe-across-rounds.sh
#
# For every round: each frame the window server had for the window, with its milliseconds; every call Arbor made to it, what it asked, what the window took and
# when (out of the round's trace); whether it had its place's height within a second and a half and ten seconds later; what Arbor had written down.
# At the control the checks are expected to fail: that they do, in the same rounds, is what it is for.
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

# calls <name> <window>: Arbor's calls to the window in that round's trace, and the timers that ask again.
calls() {
  python3 - "$TRACES/$1.jsonl" "$2" << 'PY'
import json, sys
lines = [json.loads(line) for line in open(sys.argv[1])]
window, first, whole = int(sys.argv[2]), None, None
for e in lines[1:]:
    if e.get("call") == "setFrame" and e.get("id") == window:
        asked, took = e["frame"], e.get("result")
        short = bool(took) and (took[3] < asked[3] - 2 or took[2] < asked[2] - 2)
        first = e["t"] if first is None else first
        if took and not short and whole is None and asked[3] > 900:
            whole = e["t"]
        print("  call t %.4f asked %s took %s%s" % (e["t"], asked, took, "  SHORT" if short else ""))
    elif "timer" in e and str(e["timer"]).startswith("across-"):
        print("  call t %.4f the timer that asks again" % e["t"])
print("  calls: whole %s" % ("%d ms after the first call" % round((whole - first) * 1000) if whole is not None and first is not None else "never"))
PY
}

arbor_build
macos_tiling off
display_add 1280 720 right
echo "displays (id uuid x y w h scale main vendor model serial):"
"$ARBOR_VDISPLAY" list
arbor_start 3
summary

step "the large display: W3 at its right end, along the border"
ctl dock "$W3" right
sleep 1
read -r x3 y3 w3 h3 <<< "$(slot_of "$W3" | awk '{ for (i = 1; i <= NF; i++) printf "%d ", $i + 0.5 }')"
border=$((x3 + w3 + 12))
to=$((border - 50))
echo "W3's slot ends at $((x3 + w3)); the border is at about $border; the hand lets go at $to $((y3 + h3 / 2))"

# over_the_border <window>: taken 90 points from its left edge, right of the three buttons, and let go 50 points over the border.
over_the_border() {
  local x y w
  read -r x y w _ <<< "$(real_frame_of "$1" | awk '{ for (i = 1; i <= NF; i++) printf "%d ", $i + 0.5 }')"
  echo "taken at $((x + 90)) $((y + 12)); it is $w wide, so it should reach from $((to - 90)) to $((to - 90 + w)) when it is let go"
  drag $((x + 90)) $((y + 12)) "$to" $((y3 + h3 / 2)) --hold 1
}

for round in 1 2 3 4 5; do
  step "a floating window, dropped over the border: round $round"
  ctl float "$W2"
  sleep 1
  is display2 "$W2" || ctl move-to-display next "$W2"
  sleep 3
  check "it floats on the small display" is display2 "$W2"
  WATCH=10 across "float-drop-$round" "$W2" over_the_border "$W2"
  calls "float-drop-$round" "$W2"
  check "it is docked on the large display" is display1 "$W2"
done
ctl float "$W2"
sleep 1
summary

for round in 1 2 3 4 5; do
  step "a docked window, dropped over the border: round $round"
  is docked "$W2" || ctl dock "$W2" left
  sleep 1
  is display2 "$W2" || ctl move-to-display next "$W2"
  sleep 3
  check "it is docked on the small display" is display2 "$W2"
  WATCH=10 across "dock-drop-$round" "$W2" over_the_border "$W2"
  calls "dock-drop-$round" "$W2"
  check "it is docked on the large display" is display1 "$W2"
done
ctl float "$W2"
sleep 1
summary

ctl dock "$W1" left
sleep 1
for round in 1 2 3 4 5; do
  step "by the command: round $round"
  is display2 "$W1" || ctl move-to-display next "$W1"
  sleep 3
  check "it is docked on the small display" is display2 "$W1"
  across "command-$round" "$W1" ctl move-to-display next "$W1"
  calls "command-$round" "$W1"
  check "it is docked on the large display" is display1 "$W1"
done
summary

arbor_stop
display_remove
macos_tiling on > /dev/null
