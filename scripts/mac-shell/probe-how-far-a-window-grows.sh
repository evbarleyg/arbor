#!/bin/bash
# How far does macOS let a window grow or go when its size and position are set through Accessibility? ARBOR IS NOT RUNNING.
#
#   scripts/mac-shell/run.sh scripts/mac-shell/probe-how-far-a-window-grows.sh          about six minutes
#
# Read off traces of Arbor on one hosted Mac (one display, the Dock at the bottom, test windows only): a size call that makes a window GROW stops where the bottom edge comes to the
# visible frame's bottom less 1 and the right edge to the display's right edge, judged where the window stands when the call arrives; an edge that is past its line
# already is free; position calls are not held back. So the order of the calls decides what a window ends up with. This asks what nobody had seen, with grow.swift, which
# makes the calls one by one and writes down what came of each:
#
#   A  the control: three lines that are known
#   B  the same journeys in four orders: size, position, size (FramePlan.full); position, size; size, position; the smaller size, position, size
#   C  a window that hangs over an edge: the right one, the line at the bottom, the left one, two at once; and one that ends exactly at a line
#   D  a slot that ends exactly at the visible bottom or at the display's right edge, in whole and in half points; and how far a position goes
#   E  A, B, D again with the Dock at the left, and A and D with the Dock hidden
#   G  real apps: TextEdit, Finder, Terminal, Safari; Chrome and a Java app, which draw their own windows' content with toolkits of their own
#   F  a second, smaller display to the right, to the left and below: growing across the shared edge, a large window on its way to the smaller display and back
#
# What comes back: grow.jsonl, every call and every result as grow.swift printed them (its header says what is in a line); output.txt, a line for each result.
# It judges nothing: every line is an answer. Exit code 0 unless a tool did not compile.
source "$(dirname "${BASH_SOURCE[0]}")/lib-apps.sh"
needs_throwaway_mac "move the Dock to the left and hide it, plug in a virtual display, and open and quit real apps"

GROW="$ARBOR_ROOT/.build/mac-shell/grow"
RESULTS="$ARBOR_OUT/grow.jsonl"
scratch_dir grow STEPS
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

# MARK: The steps. Every number is relative to the displays as they are, and comes to the known one on a display of 1024×768 with the Dock's top at 705.

cat > "$STEPS/control" << 'STEPS'
round A the control
one A1-grows-where-it-stands 170 vb1-485 480 348 size 494 650
one A2-parked-it-grows r1-1 vb1-28 325 524 size 1000 650
one A3-sent-to-the-corner 170 vb1-485 480 348 pos r1-1 b1-1
STEPS

cat > "$STEPS/orders" << 'STEPS'
round B four orders
orders SPS,PS,SP,sPS
journey B1-grows vl1+170 220 480 348 vl1+12 vt1+12 494 vb1-vt1-24
journey B2-shrinks vl1+12 vt1+12 vr1-vl1-24 vb1-vt1-24 600 300 300 200
journey B3-wider-and-lower vr1-506 vt1+12 494 vb1-vt1-24 vl1+12 vb1-325 vr1-vl1-24 313
journey B4-narrower-and-taller vl1+12 vb1-325 vr1-vl1-24 313 vr1-506 vt1+12 494 vb1-vt1-24
journey B5-back-from-the-corner r1-1 vb1-28 325 524 vl1+12 vt1+12 494 vb1-vt1-24
STEPS

cat > "$STEPS/hanging" << 'STEPS'
round C hanging over an edge
one C1-right-over-taller r1-224 100 400 300 size 400 500
one C2-right-over-wider r1-224 100 400 300 size 500 300
one C3-right-over-taller-than-the-line r1-224 100 400 300 size 400 vb1
one C4-right-over-both r1-224 100 400 300 size 500 500
one C5-right-over-narrower-and-taller r1-224 100 400 300 size 300 500
one C6-bottom-over-wider 100 vb1-205 300 400 size 500 400
one C7-bottom-over-wider-than-the-display 100 vb1-205 300 400 size r1+100 400
one C8-bottom-over-taller 100 vb1-205 300 400 size 300 500
one C9-bottom-over-both 100 vb1-205 300 400 size 500 500
one C10-left-over-wider -200 100 400 300 size 600 300
one C11-left-over-taller -200 100 400 300 size 400 500
one C12-left-over-past-both -200 100 400 300 size r1+400 vb1
one C13-right-and-bottom-over r1-224 vb1-205 400 400 size 600 600
one C14-right-edge-at-the-edge r1-400 100 400 300 size 500 300
one C15-bottom-one-above-the-visible-bottom 100 vb1-301 300 300 size 300 400
one C16-bottom-at-the-visible-bottom 100 vb1-300 300 300 size 300 400
one C17-bottom-one-past-the-visible-bottom 100 vb1-299 300 300 size 300 400
one C18-right-edge-one-past r1-399 100 400 300 size 500 300
STEPS

cat > "$STEPS/exact" << 'STEPS'
round D exactly at a line
orders SPS,PS
journey D1-ends-at-the-visible-bottom vl1+170 220 480 348 vl1+12 vt1+12 494 vb1-vt1-12
journey D2-ends-one-above vl1+170 220 480 348 vl1+12 vt1+12 494 vb1-vt1-13
journey D3-half-y-ends-at-the-visible-bottom vl1+170 220 480 348 vl1+12 vt1+12.5 494 vb1-vt1-12.5
journey D4-half-y-ends-one-above vl1+170 220 480 348 vl1+12 vt1+12.5 494 vb1-vt1-13.5
journey D5-ends-at-the-right-edge vl1+170 220 480 348 r1-494 vt1+12 494 400
journey D6-ends-one-past-the-right-edge vl1+170 220 480 348 r1-494 vt1+12 495 400
journey D7-half-x-ends-at-the-right-edge vl1+170 220 480 348 r1-494.5 vt1+12 494.5 400
journey D8-the-whole-visible-frame vl1+170 220 480 348 vl1 vt1 vr1-vl1 vb1-vt1
one D9-taller-than-the-display vl1+170 220 480 348 size 480 b1
one D10-wider-than-the-display vl1+170 220 480 348 size r1 348
one D11-sent-to-the-bottom vl1+170 220 480 348 pos vl1+170 b1-1
one D12-sent-under-the-menu-bar vl1+170 220 480 348 pos vl1+170 0
one D13-sent-above-the-display vl1+170 220 480 348 pos vl1+170 -50
one D14-sent-far-left vl1+170 220 480 348 pos -600 220
one D15-sent-far-right vl1+170 220 480 348 pos r1+500 220
STEPS

cat > "$STEPS/dock" << 'STEPS'
round E at the edge of the Dock
one E1-sent-under-the-Dock vl1+170 220 480 348 pos 0 220
one E2-sent-half-under-the-Dock vl1+170 220 480 348 pos vl1-30 220
one E3-sent-past-the-left-edge vl1+170 220 480 348 pos -100 220
one E4-under-the-Dock-wider 0 220 300 200 size 600 200
one E5-under-the-Dock-taller 0 220 300 200 size 300 400
STEPS

cat > "$STEPS/app" << 'STEPS'
round G a real app
one A1-grows-where-it-stands 170 vb1-485 480 348 size 494 650
one A2-parked-it-grows r1-1 vb1-28 325 524 size 1000 650
one A3-sent-to-the-corner 170 vb1-485 480 348 pos r1-1 b1-1
orders SPS,PS,SP,sPS
journey B1-grows vl1+170 220 480 348 vl1+12 vt1+12 494 vb1-vt1-24
journey B4-narrower-and-taller vl1+12 vb1-325 vr1-vl1-24 313 vr1-506 vt1+12 494 vb1-vt1-24
one C1-right-over-taller r1-224 100 400 300 size 400 500
one C2-right-over-wider r1-224 100 400 300 size 500 300
one C3-right-over-taller-than-the-line r1-224 100 400 300 size 400 vb1
one D9-taller-than-the-display vl1+170 220 480 348 size 480 b1
one D10-wider-than-the-display vl1+170 220 480 348 size r1 348
STEPS

cat > "$STEPS/two" << 'STEPS'
round F two displays
one F1-on-the-main-one-wider-than-it r1-500 vt1+50 400 300 size 900 300
one F2-on-the-main-one-taller-than-it l1+100 vb1-400 400 300 size 400 900
one F3-on-the-second-wider-than-it r2-300 vt2+50 250 200 size 700 200
one F4-on-the-second-taller-than-it l2+100 vb2-300 250 200 size 250 700
one F5-across-the-right-edge-wider r1-100 vt1+50 400 300 size 1200 300
one F6-large-sent-to-the-smaller vl1+12 vt1+12 1000 650 pos vl2+12 vt2+12
one F7-large-sent-to-the-smaller-ones-corner vl1+12 vt1+12 1000 650 pos vl2 vt2
orders SPS,PS,SP,sPS
journey F8-large-to-a-slot-on-the-smaller vl1+12 vt1+12 1000 650 vl2+12 vt2+12 vr2-vl2-24 vb2-vt2-24
journey F9-back-to-the-larger vl2+12 vt2+12 vr2-vl2-24 vb2-vt2-24 vl1+12 vt1+12 1000 650
journey F10-small-to-the-whole-of-the-second vl1+100 vt1+100 300 200 vl2 vt2 vr2-vl2 vb2-vt2
STEPS

# MARK: Asking

# A line for each result, for whoever reads output.txt; all of it is in grow.jsonl.
brief_lines() {
  python3 -c '
import json, sys
def f(r): return "-" if r is None else " ".join(format(v, "g") for v in r)
for line in sys.stdin:
    try: o = json.loads(line)
    except ValueError:
        print("  " + line.rstrip()); continue
    k = o.get("kind")
    if k == "displays":
        print("  displays (%s): " % o["why"] + "; ".join("%d: %s visible %s" % (d["n"], f(d["frame"]), f(d["visible"])) for d in o["displays"]))
    elif k == "window":
        print("  window %s of %s (%s, %s) at %s" % (o["window"], o["bundle"], o["role"], o["subrole"], f(o["frame"])))
    elif k == "result":
        print("  %-44s %-4s %-5s %s -> %s: %s %s | short %s | half way %s | moved %d resized %d | %.1f ms%s" % (
            o["name"], o.get("order", ""), {True: "reads", False: "blind"}.get(o.get("reads"), ""), f(o["placed"]), f(o.get("target")), f(o["rest"]),
            "RIGHT" if o.get("right") else "OTHER", f(o.get("short")), "; ".join(f(h) for h in o["halfway"]) or "-", o["moved"], o["resized"], o["ms"],
            "" if o["end"] == o["rest"] else " | at once it was " + f(o["end"])) + ("" if o["rest"] == o["restServer"] else " | the window server says " + f(o["restServer"])))
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

dock_says() {
  echo "the Dock: orientation $(defaults read com.apple.dock orientation 2>/dev/null || echo "not set"), autohide $(defaults read com.apple.dock autohide 2>/dev/null || echo "not set"), tilesize $(defaults read com.apple.dock tilesize 2>/dev/null || echo "not set")"
}
# dock <orientation> <autohide>
dock() {
  defaults write com.apple.dock orientation "$1"
  defaults write com.apple.dock autohide -bool "$2"
  killall Dock
  # launchd starts it again; the apps hear of the new visible frame a moment after it has drawn itself.
  sleep 5
  dock_says
}

step "the Mac"
sw_vers
dock_says
macos_tiling
"$ARBOR_VDISPLAY" list

reopen_test_windows 1
sleep 2
TEST=$ARBOR_WINDOWS_PID

printf 'reads both\n' > "$STEPS/both"
printf 'reads on\n' > "$STEPS/on"
ask base "$TEST" "$W1" control both orders on hanging exact
shot base

# MARK: E, the Dock
DOCK_IS_OURS=yes
at_exit '[ -z "$DOCK_IS_OURS" ] || dock bottom false > /dev/null 2>&1'
dock left false
ask dock-left "$TEST" "$W1" control orders exact dock
shot dock-left
dock bottom true
ask dock-hidden "$TEST" "$W1" control exact
dock bottom false
DOCK_IS_OURS=""
ask base-again "$TEST" "$W1" control

# MARK: G, real apps
apps_scratch

# real <label> <bundle id> [file…]
real() {
  local label=$1
  shift
  if ! app_open "$@"; then
    echo "$label: no window to ask"
    [ -z "$APP_PID" ] || app_quit "$APP_PID"
    return
  fi
  app_dismiss "$APP_PID"
  sleep 1
  ask "$label" "$APP_PID" "$APP_WINDOW" app
}

real textedit com.apple.TextEdit "$APPS_SCRATCH/oak.txt"
app_quit "$APP_PID"
# The Finder is not quit: it is the Mac's own, and comes back by itself.
real finder com.apple.finder "$APPS_SCRATCH/grove"
real terminal com.apple.Terminal
app_quit "$APP_PID"
real safari com.apple.Safari "$APPS_SCRATCH/page.html"
app_quit "$APP_PID"

step "Chrome"
began=$SECONDS
if bounded 60 open -g -b com.google.Chrome --args --no-first-run --no-default-browser-check "file://$APPS_SCRATCH/page.html"; then
  tries=0
  until CHROME=$(apptool pid com.google.Chrome 2>/dev/null); do
    [ "$tries" -ge 100 ] && break
    sleep 0.1
    tries=$((tries + 1))
  done
  if [ -n "${CHROME:-}" ]; then
    apps_remember "$CHROME"
    apptool wait-window "$CHROME" 20 | sed 's/^/  /'
    echo "open after $((SECONDS - began)) s"
    sleep 2
    ask chrome "$CHROME" first app
    app_quit "$CHROME"
  else
    echo "Chrome did not start"
  fi
else
  echo "there is no Chrome, or it does not open"
fi

step "a Java app"
if java=$(/usr/libexec/java_home 2>/dev/null) && [ -x "$java/bin/jconsole" ]; then
  "$java/bin/jconsole" > /dev/null 2>&1 5<&- 6>&- 8>&- 9>&- &
  JAVA_PID=$!
  started "$JAVA_PID"
  sleep 8
  apptool windows "$JAVA_PID" | sed 's/^/  /'
  ask java "$JAVA_PID" first app
  kill_started "$JAVA_PID"
else
  echo "no jconsole"
fi
echo "what else is installed, for whoever looks for an app that is not AppKit's:"
ls /Applications | tr '\n' ';'
echo

# MARK: F, a second display, smaller than the main one whichever size that has
ask base-after-the-apps "$TEST" "$W1" control
display_add 800 600 right
"$ARBOR_VDISPLAY" list
ask two-right "$TEST" "$W1" control two exact
panorama two-right
display_move left
"$ARBOR_VDISPLAY" list
ask two-left "$TEST" "$W1" two
display_move below
"$ARBOR_VDISPLAY" list
ask two-below "$TEST" "$W1" control two
display_remove
sleep 3
ask base-at-the-end "$TEST" "$W1" control

step "done"
echo "$(grep -c '"kind":"call"' "$RESULTS") calls, $(grep -c '"kind":"result"' "$RESULTS") results in grow.jsonl"
exit 0
