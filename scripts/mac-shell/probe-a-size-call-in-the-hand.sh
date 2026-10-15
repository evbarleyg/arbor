#!/bin/bash
# What does macOS do with ONE size call through Accessibility while a hand is dragging the window by its title bar? ARBOR IS NOT RUNNING.
#
#   scripts/mac-shell/run.sh scripts/mac-shell/probe-a-size-call-in-the-hand.sh          under eight minutes
#
# A SYNTHETIC POINTER STANDS FOR A HAND: pointer.swift posts the press, the movements and the release where a mouse does (the HID event tap), so the window server drags the window as it does for
# a person; but its movements come in even steps, it rests between them for as long as the script needs, and it never trembles.
#
# Every trial: the window is put at a frame; pressed on its title bar and dragged a little way, THE BUTTON STAYS DOWN; one size call (never a position) by grow.swift, which reads the frame back at once and 50, 200
# and 500 ms after the call returned, by Accessibility and by the window server, with the pointer and the button each time, and takes AXResized and AXMoved with their times; the pointer moves on 60 points in
# 10 steps; the button comes up; where the window is 0.1 s and 0.7 s later.
#
#   T1  smaller: 600×400, held in the middle, asked 480×300
#   T4  narrower than the point it is held at: 936 wide, held at x+800, asked 304 wide
#   T5  wider and higher: 325×319 asked 480×600, held at the left, in the middle and at the right of the title bar
#   T6  the cut in the hand: held with its top at y 404 (the Dock's line at 704), asked 600 high, from 200 high (a) and from 319 high, which reaches into the Dock's strip already (b); then the hand carries it up to y 80,
#       where it fits, and it is asked again, still in the hand
#   T7  a size call 5, 20 and 50 ms after the release (grow.swift watches the button and spins)
#   T9  at rest, no hand: at 624,404 400×319: position 624,80; size 400×600; position 624,404, back to back: sized where it fits, then moved
#
# The test window five times each; TextEdit, Safari and, while the clock allows, Terminal three times T1, T4, T5 in the middle, T6a, T7 at 20 ms and T9. The pointer keeps away from the edges, where macOS tiles.
#
# What comes back:
#   inhand.jsonl    one JSON object per line, as grow.swift printed them (its header says what is in `put`, `look` and `hand`), and the script's own {"kind":"trial"…} and {"kind":"pointer"…} with the very words
#                   the pointer tool got. "label" is <app>.<trial>.<which time>. "epoch" is milliseconds since 1970 everywhere, as in samples.log
#   samples.log     the window server's list and the pointer sixty times a second (sampler.swift), `M <label>` before each trial
#   ax-events.txt   what Accessibility reported all the while (axwatch.swift: seconds since it began, `[button down]`), `--- <label> <seconds since 1970>` before each trial
#   output.txt      a line for each of them
# It judges nothing. Exit code 0 unless a tool did not compile.
source "$(dirname "${BASH_SOURCE[0]}")/lib-apps.sh"
needs_throwaway_mac "drag windows about with the real pointer, and open and quit real apps"

TOOLS="$ARBOR_ROOT/.build/mac-shell"
GROW="$TOOLS/grow"
RESULTS="$ARBOR_OUT/inhand.jsonl"
EVENTS="$ARBOR_OUT/ax-events.txt"
BUDGET=${PROBE_BUDGET:-440}
scratch_dir inhand STEPS
: > "$RESULTS"
: > "$EVENTS"
: > "$STEPS/trial"

mkdir -p "$TOOLS"
COMPILING=""
for tool in grow axwatch sampler; do
  swiftc -O -swift-version 5 "$ARBOR_ROOT/scripts/mac-shell/$tool.swift" -o "$TOOLS/$tool" > "$ARBOR_OUT/build-$tool.log" 2>&1 &
  COMPILING="$COMPILING $tool:$!"
done
apps_build
for job in $COMPILING; do
  wait "${job#*:}" && continue
  grep -A 6 "error:" "$ARBOR_OUT/build-${job%:*}.log" | head -n 40
  die "scripts/mac-shell/${job%:*}.swift did not compile"
done
apps_watchdog 560
echo "clock: built after ${SECONDS}s"

# MARK: The tools

brief_lines() {
  python3 -c '
import json, sys
def f(r): return "-" if r is None else " ".join(format(v, "g") for v in r)
def g(o): return "%s (server %s) pointer %s %s" % (f(o["ax"]), f(o["ws"]), f(o["pointer"]), "down" if o["button"] else "up")
for line in sys.stdin:
    try: o = json.loads(line)
    except ValueError:
        print("  " + line.rstrip()); continue
    k = o.get("kind")
    if k == "displays":
        print("  displays (%s): " % o["why"] + "; ".join("%d: %s visible %s" % (d["n"], f(d["frame"]), f(d["visible"])) for d in o["displays"]))
    elif k == "window":
        print("  window %s of %s (%s, %s) at %s" % (o["window"], o["bundle"], o["role"], o["subrole"], f(o["frame"])))
    elif k == "put":
        print("  put: %s%s" % (f(o["ax"]), "" if o["right"] else " (WANTED %s)" % f(o["wanted"])))
    elif k == "look":
        print("  %-10s %s" % (o["name"] + ":", g(o)))
    elif k == "hand":
        print("  %s: %s%s" % (o["name"], "; ".join("%s %s (%.1f ms)" % (c["call"], f(c["asked"]), c["ms"]) for c in o["calls"]),
                              "" if "sinceRelease" not in o else ", %.2f ms after the release" % o["sinceRelease"]))
        if "before" in o: print("    before:  " + g(o["before"]))
        print("    at once: " + g(o["once"]))
        for l in o["later"]: print("    %3d ms:  %s" % (l["after"], g(l)))
        print("    reports: " + ("; ".join("%s %.1f" % (n[1], n[0]) for n in o["notes"]) or "none"))
'
}

# ask <steps, one to an argument>: grow.swift on the window in hand. What it said is told at the end of the trial: a hand should not have to wait for the telling.
ask() {
  printf '%s\n' "$@" > "$STEPS/now"
  limit 30 "$GROW" "$PID" "$WINDOW" "$LABEL" "$STEPS/now" 2>&1 | tee -a "$RESULTS" >> "$STEPS/trial"
}
tell() {
  brief_lines < "$STEPS/trial"
  : > "$STEPS/trial"
}
# hand <words for the pointer tool>: and what they were, with the time
hand() {
  printf '{"kind":"pointer","label":"%s","epoch":%s,"words":"%s"}\n' "$LABEL" "$(perl -MTime::HiRes=time -e 'printf "%.3f", time * 1000')" "$*" >> "$RESULTS"
  # shellcheck disable=SC2068
  arbor_input $@
}
in_time() {
  [ "$SECONDS" -lt "$BUDGET" ] && return 0
  echo "SKIPPED: $1 (${SECONDS}s have gone, the budget is ${BUDGET}s)"
  printf '{"kind":"skipped","label":"%s"}\n' "$1" >> "$RESULTS"
  return 1
}
# begin <trial> <which time> <x y w h>: sets LABEL, marks every log, puts the window there
begin() {
  LABEL="$APP.$1.$2"
  in_time "$LABEL" || return 1
  step "$LABEL"
  printf '{"kind":"trial","label":"%s","epoch":%s,"start":[%s,%s,%s,%s]}\n' "$LABEL" "$(perl -MTime::HiRes=time -e 'printf "%.3f", time * 1000')" "$3" "$4" "$5" "$6" >> "$RESULTS"
  echo "--- $LABEL $(arbor_now)" >> "$EVENTS"
  echo "mark $LABEL" >&6
  ask "put start $3 $4 $5 $6"
}
# ends the trial: the button comes up
let_go() {
  hand release
  sleep 0.1
  ask "look let-go"
  sleep 0.5
  ask "look rest"
  tell
}

# in_hand <trial> <time> <x y w h> <held at: points from the window's left edge> <dragged by dx dy> <asked w h> <carried on by dx dy>
in_hand() {
  local x=$3 y=$4 at=$7 dx=$8 dy=$9 w=${10} h=${11} ox=${12} oy=${13} px py
  begin "$1" "$2" "$3" "$4" "$5" "$6" || return 0
  px=$((x + at)) py=$((y + GRIP))
  hand drag "$px" "$py" $((px + dx)) $((py + dy)) --no-release --steps 15 --duration 0.3 --hold 0.1
  ask "chain asked size $w $h"
  hand drag-on $((px + dx + ox)) $((py + dy + oy)) --steps 10 --duration 0.4 --hold 0.1
  ask "look carried"
  let_go
}

# the_cut <trial> <time> <height to start with>
the_cut() {
  local px py
  begin "$1" "$2" 300 364 325 "$3" || return 0
  px=$((300 + 162)) py=$((364 + GRIP))
  hand drag "$px" "$py" $((px + 40)) $((py + 40)) --no-release --steps 15 --duration 0.3 --hold 0.1
  ask "chain asked-low size 325 600"
  hand drag-on $((px + 40)) $((py + 40 - 324)) --steps 20 --duration 0.5 --hold 0.1
  ask "look carried-up" "chain asked-high size 325 600"
  hand drag-on $((px + 100)) $((py + 40 - 324)) --steps 10 --duration 0.4 --hold 0.1
  ask "look carried"
  let_go
}

# after_the_release <trial> <time> <ms>
after_the_release() {
  local px py waiter
  begin "$1" "$2" 200 150 600 400 || return 0
  px=$((200 + 300)) py=$((150 + GRIP))
  hand drag "$px" "$py" $((px + 60)) $((py + 40)) --no-release --steps 15 --duration 0.3 --hold 0.1
  ask "look held"
  # It has to be watching the button before the button comes up.
  echo "chain asked after-release $3 size 480 300" > "$STEPS/later"
  limit 30 "$GROW" "$PID" "$WINDOW" "$LABEL" "$STEPS/later" > "$STEPS/said" 2>&1 5<&- 6>&- 8>&- 9>&- &
  waiter=$!
  sleep 0.4
  hand release
  wait "$waiter"
  tee -a "$RESULTS" < "$STEPS/said" >> "$STEPS/trial"
  sleep 0.3
  ask "look rest"
  tell
}

at_rest() {
  begin "$1" "$2" 624 404 400 319 || return 0
  ask "chain there-and-back pos 624 80 size 400 600 pos 624 404"
  sleep 0.2
  ask "look rest"
  tell
}

# every <times> <all|some>
every() {
  local time
  for time in $(seq 1 "$1"); do
    in_hand T1-smaller "$time" 200 150 600 400 300 60 40 480 300 60 0
    in_hand T4-narrower-than-where-it-is-held "$time" 40 120 936 400 800 40 40 304 400 -60 0
    [ "$2" = some ] || in_hand T5-wider-and-higher-held-left "$time" 300 60 325 319 90 40 30 480 600 60 0
    in_hand T5-wider-and-higher-held-in-the-middle "$time" 300 60 325 319 162 40 30 480 600 60 0
    [ "$2" = some ] || in_hand T5-wider-and-higher-held-right "$time" 300 60 325 319 300 40 30 480 600 60 0
    the_cut T6a-the-cut-from-200-high "$time" 200
    [ "$2" = some ] || the_cut T6b-the-cut-from-319-high "$time" 319
    [ "$2" = some ] || after_the_release T7-5-ms-after-the-release "$time" 5
    after_the_release T7-20-ms-after-the-release "$time" 20
    [ "$2" = some ] || after_the_release T7-50-ms-after-the-release "$time" 50
    at_rest T9-sized-where-it-fits-then-moved "$time"
  done
}

WATCHER=""
# watched <pid>: axwatch on that process, until the next
watched() {
  [ -z "$WATCHER" ] || kill_started "$WATCHER"
  echo "# axwatch on $APP begins at $(arbor_now) seconds since 1970; its own seconds count from there" >> "$EVENTS"
  "$TOOLS/axwatch" "$1" >> "$EVENTS" 2>&1 5<&- 6>&- 7>&- 8>&- 9>&- &
  WATCHER=$!
  started "$WATCHER"
  sleep 0.5
}

# MARK: The run

step "the Mac"
sw_vers
echo "defaults read com.apple.WindowManager:"
defaults read com.apple.WindowManager 2>&1 | sed 's/^/  /'
macos_tiling
macos_reduce_motion
echo "the Dock: orientation $(defaults read com.apple.dock orientation 2>/dev/null || echo "not set"), autohide $(defaults read com.apple.dock autohide 2>/dev/null || echo "not set")"
pointer displays
apps_scratch

mkfifo "$STEPS/sampler-in" "$STEPS/sampler-out"
"$TOOLS/sampler" "$ARBOR_OUT/samples.log" "$STEPS/sampler-in" "$STEPS/sampler-out" --hz 60 2>> "$ARBOR_OUT/sampler-stderr.log" 7>&- 8>&- 9>&- &
SAMPLER_PID=$!
started "$SAMPLER_PID"
exec 6> "$STEPS/sampler-in" 5< "$STEPS/sampler-out"

reopen_test_windows 1
sleep 2
APP=test-window PID=$ARBOR_WINDOWS_PID WINDOW=$W1 GRIP=12 LABEL=test-window
ask "look first"
tell
export GROW_BRIEF=1
watched "$PID"
every 5 all
echo "clock: the test window done after ${SECONDS}s"

# real <name> <bundle id> [file…]
real() {
  APP=$1 LABEL=$1
  shift
  in_time "$APP" || return 0
  step "$APP opens"
  if ! app_open "$@"; then
    echo "$APP: no window to ask"
    [ -z "$APP_PID" ] || app_quit "$APP_PID"
    return
  fi
  app_dismiss "$APP_PID"
  PID=$APP_PID WINDOW=$APP_WINDOW
  # In front, as the window a person drags is from the press on.
  apptool activate "$PID"
  sleep 1
  GROW_BRIEF="" ask "put first 200 150 600 400"
  tell
  # How far below the window's top a press moves it and meets no control, by Accessibility's account of what lies there.
  read -r _ grab_y role <<< "$(apptool grab "$WINDOW" 2>/dev/null)"
  GRIP=12
  [ -z "${grab_y:-}" ] || GRIP=$((${grab_y%.*} - 150))
  echo "held $GRIP points below its top (${role:-nothing said})"
  watched "$PID"
  every 3 some
  app_quit "$PID"
  echo "clock: $APP done after ${SECONDS}s"
}
real textedit com.apple.TextEdit "$APPS_SCRATCH/oak.txt"
real safari com.apple.Safari "$APPS_SCRATCH/page.html"
real terminal com.apple.Terminal

[ -z "$WATCHER" ] || kill_started "$WATCHER"
if kill -0 "$SAMPLER_PID" 2>/dev/null; then
  echo stop >&6
  exec 6>&- 5<&-
  ended "$SAMPLER_PID" 30 || kill_started "$SAMPLER_PID"
fi

step "done"
echo "$(grep -c '"kind":"trial"' "$RESULTS") trials, $(grep -c '"kind":"hand"' "$RESULTS") rounds of calls, $(grep -c '"kind":"skipped"' "$RESULTS") skipped; samples.log $(grep -c "" "$ARBOR_OUT/samples.log") lines; ax-events.txt $(grep -c "" "$EVENTS") lines"
echo "NOT VARIED: one Mac, one macOS; one display, at scale 1; the Dock at the bottom, shown; macOS's tiling switches as the image has them (printed at the top); Reduce Motion as the image has it (printed at the top);"
echo "NOT VARIED: one Space, no Stage Manager, no full screen; a synthetic pointer, which rests while the call is made and moves in even steps; the pointer never near an edge or a corner of the display, nor in the menu bar;"
echo "NOT VARIED: no modifier key down; one size call at a time, never a position call in the hand; the window in front from the press on; Arbor not running, so no event tap of its own in the way."
exit 0
