#!/bin/bash
# For how long after a window has changed display is its size still judged by the display it came from? ARBOR IS NOT RUNNING.
#
#   scripts/mac-shell/run.sh scripts/mac-shell/probe-when-the-display-turns.sh          about eight minutes
#
# probe-how-far-a-window-grows.sh found it: macOS lets a window grow as far as the edges of its display, and a size call made 0.5 to 5.6 ms after the position call that took the
# window to another display was held to the edges of the OLD display, 10 times of 10; 200 ms after, to those of the new one, 4 of 4. So a window that goes from a small display to a slot on a
# large one ends short whatever the order of the calls, and has to be asked again. This asks when: a window goes to and fro between a slot on an 800×600 display and
# 1000×650 on the main one, with the small display to the right, to the left and below, in two ways:
#
#   PS    position, WAIT, size
#   SPSS  size, position, size back to back, as Arbor does today; WAIT; size once more, as a cure would
#
# with waits of 0 to 300 ms, which are spun and not slept, because a timer on a hosted Mac comes 12 to 160 ms late; what they really were stands in every line. Nothing is read between the calls.
# After every journey the window has 300 ms, is read again, and is then put to the point where the next journey starts (`placedRight` says whether it was).
# The test window three times with ten waits, TextEdit twice with six.
# L: the corner where Arbor parks a window (the main display's right edge less 1, as low as macOS lets it), with the small display to the right, below, and right beside and under that corner: on which display does macOS
# count a window there? Does it grow whole there, as on one display? From there to a slot on the main display: position, then size at once and after 250 ms; and sized where it is parked, then moved.
#
# Before that, on one display, what the first probe left open. I: a bottom edge in the Dock's strip and just past the display's bottom: from where on is it free to grow?
# K: a window cannot grow into a frame that hangs over an edge once it has been moved there (position, size ended 1 short of a frame 1 point over the right edge, 4 times of 4, where size,
# position, size got it whole, having sized the window where there was room). Does size, position, size always get such a frame where there was room at the old place, and what where there was none?
# And at the end Chrome, which `open -b` did not open then: is a Chromium window clipped like the others, and does it move late?
#
# What comes back: turn.jsonl, as grow.swift printed it; output.txt, a line for each journey and the tables. It judges nothing. Exit code 0 unless a tool did not compile.
source "$(dirname "${BASH_SOURCE[0]}")/lib-apps.sh"
needs_throwaway_mac "plug in a virtual display, at which macOS moves every window, and open and quit real apps"

GROW="$ARBOR_ROOT/.build/mac-shell/grow"
RESULTS="$ARBOR_OUT/turn.jsonl"
scratch_dir turn STEPS
: > "$RESULTS"

mkdir -p "$ARBOR_ROOT/.build/mac-shell"
swiftc -O -swift-version 5 "$ARBOR_ROOT/scripts/mac-shell/grow.swift" -o "$GROW" > "$ARBOR_OUT/build-grow.log" 2>&1 &
GROW_COMPILER=$!
apps_build
if ! wait "$GROW_COMPILER"; then
  grep -A 6 "error:" "$ARBOR_OUT/build-grow.log" | head -n 60
  die "scripts/mac-shell/grow.swift did not compile"
fi
apps_watchdog 900

cat > "$STEPS/strip" << 'STEPS'
round I in the strip of the Dock and past the bottom of the display
one I1-bottom-10-past-the-visible-bottom 100 vb1-290 300 300 size 300 400
one I2-bottom-30-past 100 vb1-270 300 300 size 300 400
one I3-bottom-2-above-the-bottom-of-the-display 100 b1-302 300 300 size 300 400
one I4-bottom-1-above 100 b1-301 300 300 size 300 400
one I5-bottom-at-the-bottom-of-the-display 100 b1-300 300 300 size 300 400
one I6-bottom-1-past 100 b1-299 300 300 size 300 400
one I7-bottom-2-past 100 b1-298 300 300 size 300 400
one I8-bottom-30-past 100 b1-270 300 300 size 300 400
STEPS

# Into a frame that hangs over: by 1, 20, 100, 160 points at the right, by 1, 20, 100, 300 below the visible bottom, and both. From a place with room for the new size, and from one without.
{
  echo "round K into a frame that hangs over an edge"
  echo "orders SPS,PS,sPS"
  for start in "room 170 100 480 348" "no-room r1-485 vb1-353 480 348"; do
    for over in 1 20 100 160; do echo "journey K-${start%% *}-right-$over ${start#* } r1-494+$over vt1+12 494 400"; done
    for over in 1 20 100 300; do echo "journey K-${start%% *}-bottom-$over ${start#* } vl1+12 vb1-500+$over 494 500"; done
    echo "journey K-${start%% *}-both-100-100 ${start#* } r1-494+100 vb1-500+100 494 500"
    echo "journey K-${start%% *}-both-160-300 ${start#* } r1-494+160 vb1-500+300 494 500"
  done
} > "$STEPS/over"

cat > "$STEPS/all-waits" << 'STEPS'
round J when the display turns
turn J vl1+12 vt1+12 1000 650 vl2+12 vt2+12 vr2-vl2-24 vb2-vt2-24 0,10,25,50,75,100,150,200,250,300 3 PS,SPSS
STEPS

cat > "$STEPS/six-waits" << 'STEPS'
round J when the display turns
turn J vl1+12 vt1+12 1000 650 vl2+12 vt2+12 vr2-vl2-24 vb2-vt2-24 0,25,50,100,150,250 2 PS,SPSS
STEPS

cat > "$STEPS/corner" << 'STEPS'
round L the corner where Arbor parks, beside a second display
one L1-sent-to-the-corner vl1+12 vt1+12 480 348 pos r1-1 b1-1
one L2-parked-it-grows.1 r1-1 vb1-28 325 524 size 1000 650
one L2-parked-it-grows.2 r1-1 vb1-28 325 524 size 1000 650
one L2-parked-it-grows.3 r1-1 vb1-28 325 524 size 1000 650
turn L r1-1 vb1-28 325 524 vl1+12 vt1+12 1000 650 0,250 3 PS,SP
STEPS

cat > "$STEPS/app" << 'STEPS'
round G a real app
one A1-grows-where-it-stands 170 vb1-485 480 348 size 494 650
one A2-parked-it-grows r1-1 vb1-28 325 524 size 1000 650
one A3-sent-to-the-corner 170 vb1-485 480 348 pos r1-1 b1-1
orders SPS,PS,SP,sPS
journey B1-grows vl1+170 220 480 348 vl1+12 vt1+12 494 vb1-vt1-24
one C2-right-over-wider r1-224 100 400 300 size 500 300
one C3-right-over-taller-than-the-line r1-224 100 400 300 size 400 vb1
one D10-wider-than-the-display vl1+170 220 480 348 size r1 348
round H who moves late
later on
one H1-taller-and-wider 100 100 600 400 size 700 500
one H2-smaller 100 100 700 500 size 600 400
one H3-moved 100 100 600 400 pos 300 150
one H4-sent-to-the-corner 100 100 600 400 pos r1-1 b1-1
one H5-back-from-the-corner r1-1 vb1-28 600 400 pos 100 100
orders SPS,PS
reads off
journey H7-into-a-slot 170 220 600 348 vl1+12 vt1+12 700 vb1-vt1-24
STEPS

brief_lines() {
  python3 -c '
import json, sys
def f(r): return "-" if r is None else " ".join(format(v, "g") for v in r)
for line in sys.stdin:
    try: o = json.loads(line)
    except ValueError:
        print("  " + line.rstrip()); continue
    k = o.get("kind")
    if k == "displays" and o["why"] != "end":
        print("  displays (%s): " % o["why"] + "; ".join("%d: %s visible %s" % (d["n"], f(d["frame"]), f(d["visible"])) for d in o["displays"]))
    elif k == "window":
        print("  window %s of %s (%s, %s) at %s" % (o["window"], o["bundle"], o["role"], o["subrole"], f(o["frame"])))
    elif k == "turn":
        print("  %-8s %-4s wait %3g: waited %7.2f ms, %s since the position call | %s%s -> %s: %s %s | short %s | moved %d resized %d%s" % (
            o["name"], o["order"], o["wait"], o["waited"], "-" if o["sincePosition"] is None else "%7.2f" % o["sincePosition"], f(o["placed"]), "" if o["placedRight"] else " (NOT WHERE IT SHOULD START)", f(o["target"]), f(o["rest"]),
            "WHOLE" if o["right"] else "OTHER", f(o.get("short")), o["moved"], o["resized"], "" if o["end"] == o["rest"] else " | at once it was " + f(o["end"])))
    elif k == "result":
        looks = o.get("later", [])
        late = any(l["ax"] != o["end"] or l["ws"] != o["endServer"] for l in looks)
        print("  %-44s %-4s %s -> %s: %s %s | short %s | half way %s | moved %d resized %d | %.1f ms" % (
            o["name"], o.get("order", ""), f(o["placed"]), f(o.get("target")), f(o["rest"]), "RIGHT" if o.get("right") else "OTHER", f(o.get("short")),
            "; ".join(f(h) for h in o["halfway"]) or "-", o["moved"], o["resized"], o["ms"])
            + ("" if not looks else " | LATE: at once %s (server %s); " % (f(o["end"]), f(o["endServer"])) + "; ".join("%d ms %s (server %s)" % (l["after"], f(l["ax"]), f(l["ws"])) for l in looks) if late else " | the same at the three later looks"))
    elif k in ("skipped", "note"):
        print("  %s: %s" % (k, o.get("text")))
'
}

# ask <label> <pid> <window id|first> <steps…>
ask() {
  local label=$1 pid=$2 window=$3 name
  shift 3
  for name in "$@"; do cat "$STEPS/$name"; done > "$STEPS/now"
  step "$label: $*"
  limit 150 "$GROW" "$pid" "$window" "$label" "$STEPS/now" 2>&1 | tee -a "$RESULTS" | brief_lines
}

step "the Mac"
sw_vers
macos_reduce_motion
"$ARBOR_VDISPLAY" list
apps_scratch

reopen_test_windows 1
sleep 2
TEST=$ARBOR_WINDOWS_PID
ask one-display "$TEST" "$W1" strip over

TEXTEDIT=""
if app_open com.apple.TextEdit "$APPS_SCRATCH/oak.txt"; then TEXTEDIT=$APP_PID TEXTEDIT_WINDOW=$APP_WINDOW; else echo "TextEdit: no window to ask"; fi
[ -z "$TEXTEDIT" ] || ask one-display-textedit "$TEXTEDIT" "$TEXTEDIT_WINDOW" over

display_add 800 600 right
for side in right left below; do
  [ "$side" = right ] || display_move "$side"
  "$ARBOR_VDISPLAY" list
  ask "test-window-$side" "$TEST" "$W1" all-waits
  [ -z "$TEXTEDIT" ] || ask "textedit-$side" "$TEXTEDIT" "$TEXTEDIT_WINDOW" six-waits
  [ "$side" = left ] || ask "corner-$side" "$TEST" "$W1" corner
done
# And with the small display where it lies beside, or under, that very corner.
read -r MAIN_WIDTH MAIN_HEIGHT <<< "$("$ARBOR_VDISPLAY" list | awk '$8 == "main" { print $5, $6 }')"
display_move below $((MAIN_WIDTH - 800))
"$ARBOR_VDISPLAY" list
ask corner-below-at-the-right "$TEST" "$W1" corner
display_move right $((MAIN_HEIGHT - 600))
"$ARBOR_VDISPLAY" list
ask corner-right-and-low "$TEST" "$W1" corner
display_remove
sleep 3
[ -z "$TEXTEDIT" ] || app_quit "$TEXTEDIT"

step "the tables: of the journeys with that wait, how many ended whole (and the waits as they really were, ms since the position call)"
python3 - "$RESULTS" << 'PYTHON'
import collections, json, sys
rows = []
for line in open(sys.argv[1], encoding="utf-8"):
    try: o = json.loads(line)
    except ValueError: continue
    if o.get("kind") == "turn": rows.append(o)
table = collections.OrderedDict()
for o in rows: table.setdefault((o["label"], o["name"], o["order"]), collections.OrderedDict()).setdefault(o["wait"], []).append(o)
for (label, name, order), waits in table.items():
    print("%-20s %-8s %-5s" % (label, name, order) + "  ".join("%g: %d/%d (%.1f-%.1f)" % (
        wait, sum(o["right"] for o in group), len(group), min(o["sincePosition"] or 0 for o in group), max(o["sincePosition"] or 0 for o in group)) for wait, group in waits.items()))
print("started where it should: %d of %d" % (sum(o["placedRight"] for o in rows), len(rows)))
PYTHON

step "Chrome"
began=$SECONDS
CHROME=""
if bounded 60 open -g -a "/Applications/Google Chrome.app" --args --no-first-run --no-default-browser-check "file://$APPS_SCRATCH/page.html"; then
  tries=0
  until CHROME=$(apptool pid com.google.Chrome 2>/dev/null); do
    [ "$tries" -ge 100 ] && break
    sleep 0.1
    tries=$((tries + 1))
  done
fi
if [ -n "$CHROME" ]; then
  apps_remember "$CHROME"
  apptool wait-window "$CHROME" 20 | sed 's/^/  /'
  echo "open after $((SECONDS - began)) s"
  sleep 2
  ask chrome "$CHROME" first app
  app_quit "$CHROME"
else
  echo "Chrome did not open"
fi

step "done"
echo "$(grep -c '"kind":"turn"' "$RESULTS") journeys between displays, $(grep -c '"kind":"result"' "$RESULTS") other results in turn.jsonl"
exit 0
