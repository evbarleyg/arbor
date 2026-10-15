#!/bin/bash
# What does macOS do with a POSITION call through Accessibility while a hand is dragging the window by its title bar? ARBOR IS NOT RUNNING.
#
#   scripts/mac-shell/run.sh scripts/mac-shell/probe-a-position-call-in-the-hand.sh          about nine minutes
#
# probe-a-size-call-in-the-hand.sh found: a size call in the hand is taken as at rest, the origin stays, and the drag goes on at the old distance between pointer and origin. So a window that is made narrower than the
# point it is held at is left behind by the pointer, and still follows it from afar. Can it be put under the pointer again, in the hand? Does the drag go on from the NEW hold, or does the window jump back by the old one
# at the pointer's next step?
#
# A SYNTHETIC POINTER STANDS FOR A HAND: pointer.swift posts the press, the movements and the release where a mouse does (the HID event tap); its movements come in even steps and it never trembles.
#
# In the order of their worth, which is the order in which the clock cuts from the end:
#   P1  936 wide, held at x+800, the pointer at rest: size 304×400 and at once a position that puts the middle of the title bar under the pointer; then carried on 60 points in 10 steps, let go
#   P2  600×400 held in the middle, at rest: a position alone, which changes the hold from x+300 to x+100
#   M1  the size call alone while the pointer MOVES (fired by grow.swift when the pointer has gone 20 of 120 points)
#   M2  P1's two calls while the pointer moves
#   K1  P1 with ⌘ down from before the press      K2  P1 with ⌘ pressed in the middle of the drag
#   K3  P1 with ⌘ down, on a window that is NOT in front (TextEdit is, and its window lies over part of it): does it come forward?
#   W   the wall at the Dock's line: 325×319 with its foot 21 points above the line, pulled down until the pointer is 19, 40, 80 and 150 points past where the foot meets the line: does the foot stay at the line?
#   X   carried by the hand to a LARGER display at the right and dropped the moment it has crossed; then one size call that asks for more height than the display it came from could hold, 1, 50, 200 and 1000 ms after the
#       button came up; and the same call still in the hand over the larger display. Who judges the size: the display it came from, or the one it is on? (By calls alone, a size call within 6 ms of the position call that
#       changed the display was judged by the old one: probe-how-far-a-window-grows.sh.) Dropped with its origin 10 points past the edge; and, three times at 1 and 200 ms, with only its middle across
#       And what a window manager would do after such a drop: held near the RIGHT end of its title bar and dropped with the pointer 50 points over the border, so that three quarters of it are still on the display it comes from,
#       after the hand has RESTED there for 200 ms or for 1 s with the button down; as soon as the button is up, a position call to a place wholly on the larger display and the size call right behind it; and 500 ms after that the size
#       call once more: does asking again heal it? The control: dropped without a rest, and the pair 1 s after the drop
#   S   Safari and Terminal, held where a short pull has shown that the window comes along: the first probe's T1 (smaller), T4 (narrower than where it is held) and T6a (the cut, and whole higher up)
# All of P to W three times, then P and M twice more, then X five times, then S.
#
# What comes back: inhand.jsonl, samples.log, ax-events.txt, output.txt, as from probe-a-size-call-in-the-hand.sh, whose header says what is in them; also {"kind":"order"…}: the frontmost app's process and the ordinary
# windows from front to back. It judges nothing. Exit code 0 unless a tool did not compile.
source "$(dirname "${BASH_SOURCE[0]}")/lib-apps.sh"
needs_throwaway_mac "drag windows about with the real pointer, hold ⌘ down meanwhile, plug in a virtual display, and open and quit real apps"

TOOLS="$ARBOR_ROOT/.build/mac-shell"
GROW="$TOOLS/grow"
RESULTS="$ARBOR_OUT/inhand.jsonl"
EVENTS="$ARBOR_OUT/ax-events.txt"
BUDGET=${PROBE_BUDGET:-250}
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
apps_watchdog 700
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
    elif k == "order":
        print("  %-10s in front: process %s; windows from the front: %s" % (o["name"] + ":", o["front"], " ".join(str(i) for i in o["windows"])))
    elif k == "hand":
        print("  %s: %s%s" % (o["name"], "; ".join("%s %s%s (%.1f ms)" % (c["call"], f(c["asked"]), " = to " + f(c["sentTo"]) if c["call"] == "under" else "", c["ms"]) for c in o["calls"]),
                              "" if "gone" not in o else ", the pointer %.0f points on its way" % o["gone"]))
        if "before" in o: print("    before:  " + g(o["before"]))
        print("    at once: " + g(o["once"]))
        for l in o["later"]: print("    %3d ms:  %s" % (l["after"], g(l)))
        print("    reports: " + ("; ".join("%s %.1f" % (n[1], n[0]) for n in o["notes"]) or "none"))
'
}

stamp() { perl -MTime::HiRes=time -e 'printf "%.3f", time * 1000'; }
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
  printf '{"kind":"pointer","label":"%s","epoch":%s,"words":"%s"}\n' "$LABEL" "$(stamp)" "$*" >> "$RESULTS"
  # lib.sh's `key` keeps the record of keys that are down, so that they come up whatever ends the script.
  # shellcheck disable=SC2068
  if [ "$1" = key ]; then $@; else arbor_input $@; fi
}
# order <name>: who is in front
order() {
  printf '{"kind":"order","label":"%s","name":"%s","epoch":%s,"front":%s,"windows":[%s]}\n' "$LABEL" "$1" "$(stamp)" "$(apptool front | cut -d ' ' -f 1)" \
    "$(pointer windows --on-screen | awk '$3 == 0 { printf "%s%s", comma, $1; comma = "," }')" | tee -a "$RESULTS" >> "$STEPS/trial"
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
  printf '{"kind":"trial","label":"%s","epoch":%s,"start":[%s,%s,%s,%s]}\n' "$LABEL" "$(stamp)" "$3" "$4" "$5" "$6" >> "$RESULTS"
  echo "--- $LABEL $(arbor_now)" >> "$EVENTS"
  echo "mark $LABEL" >&6
  ask "put start $3 $4 $5 $6"
}
# let_go [options of release]: ends the trial
let_go() {
  hand release "$@"
  ask "pause 100" "look let-go" "pause 400" "look rest"
  tell
}

PULL="--no-release --steps 6 --duration 0.2 --hold 0.1"
CARRY="--steps 10 --duration 0.4 --hold 0.1"
# What P1 asks: narrower than where it is held, and under the pointer again by the middle of its title bar.
BOTH="size 304 400 under 152 12"

# at_rest_in_hand <trial> <time> <x y w h> <held at> <calls> [modifiers]
at_rest_in_hand() {
  local x=$3 y=$4 at=$7 calls=$8 mods=${9:+--mods $9} px py
  begin "$1" "$2" "$3" "$4" "$5" "$6" || return 0
  px=$((x + at)) py=$((y + GRIP))
  # shellcheck disable=SC2086
  hand drag "$px" "$py" $((px + 40)) $((py + 40)) $PULL $mods
  ask "chain asked $calls"
  # shellcheck disable=SC2086
  hand drag-on $((px - 20)) $((py + 40)) $CARRY $mods
  ask "look carried"
  # shellcheck disable=SC2086
  let_go $mods
}

# on_the_move <trial> <time> <x y w h> <held at> <calls>: the calls are made when the pointer has gone 20 of 120 points
on_the_move() {
  local x=$3 y=$4 at=$7 calls=$8 px py waiter
  begin "$1" "$2" "$3" "$4" "$5" "$6" || return 0
  px=$((x + at)) py=$((y + GRIP))
  # shellcheck disable=SC2086
  hand drag "$px" "$py" $((px + 40)) $((py + 40)) $PULL
  echo "chain asked after-move 20 $calls" > "$STEPS/later"
  limit 30 "$GROW" "$PID" "$WINDOW" "$LABEL" "$STEPS/later" > "$STEPS/said" 2>&1 5<&- 6>&- 8>&- 9>&- &
  waiter=$!
  # It has to be watching the pointer before the pointer sets out.
  sleep 0.4
  hand drag-on $((px + 40 - 120)) $((py + 40)) --steps 20 --duration 0.8 --hold 0.1
  wait "$waiter"
  tee -a "$RESULTS" < "$STEPS/said" >> "$STEPS/trial"
  ask "look carried"
  let_go
}

# ⌘ goes down in the middle of the drag.
late_command() {
  local px py
  begin "$1" "$2" 40 120 936 400 || return 0
  px=$((40 + 800)) py=$((120 + GRIP))
  # shellcheck disable=SC2086
  hand drag "$px" "$py" $((px + 20)) $((py + 20)) $PULL
  hand key cmd --down
  hand drag-on $((px + 40)) $((py + 40)) --steps 4 --duration 0.15 --hold 0.1 --mods cmd
  ask "chain asked $BOTH"
  # shellcheck disable=SC2086
  hand drag-on $((px - 20)) $((py + 40)) $CARRY --mods cmd
  ask "look carried"
  let_go --mods cmd
  hand key cmd --up
}

# ⌘ down from before the press, on a window that is not in front.
from_behind() {
  local px py
  [ -n "$TEXTEDIT" ] || return 0
  begin "$1" "$2" 40 120 936 400 || return 0
  apptool unhide "$TEXTEDIT"
  apptool activate "$TEXTEDIT"
  sleep 0.5
  order before
  px=$((40 + 800)) py=$((120 + GRIP))
  # shellcheck disable=SC2086
  hand drag "$px" "$py" $((px + 40)) $((py + 40)) $PULL --mods cmd
  order held
  ask "chain asked $BOTH"
  # shellcheck disable=SC2086
  hand drag-on $((px - 20)) $((py + 40)) $CARRY --mods cmd
  ask "look carried"
  order carried
  let_go --mods cmd
  order rest
  tell
  apptool hide "$TEXTEDIT"
  sleep 0.3
}

# the_wall <trial> <time> <how far past the line the pointer goes>
the_wall() {
  local px py foot=$((LINE - 21))
  begin "$1" "$2" 300 $((foot - 319)) 325 319 || return 0
  px=$((300 + 162)) py=$((foot - 319 + GRIP))
  hand drag "$px" "$py" "$px" $((py + 21 + $3)) --no-release --steps $(((21 + $3) / 8 + 3)) --duration 0.4 --hold 0.3
  ask "look held"
  let_go
}

# across <trial> <time> <how far past the edge its origin is let go> <ms after the release | hand>
across() {
  local x=$((EDGE - 450)) px py to waiter
  begin "$1" "$2" "$x" 200 400 300 || return 0
  px=$((x + 200)) py=$((200 + GRIP)) to=$((EDGE + $3 + 200))
  if [ "$4" = hand ]; then
    hand drag "$px" "$py" "$to" "$py" --no-release --steps 16 --duration 0.5 --hold 0 --no-settle
    ask "chain asked size 400 $TALL"
    # shellcheck disable=SC2086
    hand drag-on $((to + 60)) "$py" $CARRY
    ask "look carried"
    let_go
    return
  fi
  # It watches the button from before the press, so that the drag can end in its release at once.
  echo "chain asked after-release $4 size 400 $TALL" > "$STEPS/later"
  limit 30 "$GROW" "$PID" "$WINDOW" "$LABEL" "$STEPS/later" > "$STEPS/said" 2>&1 5<&- 6>&- 8>&- 9>&- &
  waiter=$!
  sleep 0.4
  hand drag "$px" "$py" "$to" "$py" --steps 16 --duration 0.5 --hold 0 --no-settle
  wait "$waiter"
  tee -a "$RESULTS" < "$STEPS/said" >> "$STEPS/trial"
  ask "pause 300" "look rest"
  tell
}

# own_pair <trial> <time> <seconds the hand rests before it lets go> <ms between the drop and the pair>
own_pair() {
  local x=$((EDGE - 450)) px py waiter
  begin "$1" "$2" "$x" 200 400 300 || return 0
  px=$((x + 350)) py=$((200 + GRIP))
  printf '%s\n' "chain pair after-release $4 pos r1+100 200 size 400 $TALL" "chain asked-again size 400 $TALL" > "$STEPS/later"
  limit 30 "$GROW" "$PID" "$WINDOW" "$LABEL" "$STEPS/later" > "$STEPS/said" 2>&1 5<&- 6>&- 8>&- 9>&- &
  waiter=$!
  sleep 0.4
  hand drag "$px" "$py" $((EDGE + 50)) "$py" --steps 8 --duration 0.3 --hold "$3" --no-settle
  wait "$waiter"
  tee -a "$RESULTS" < "$STEPS/said" >> "$STEPS/trial"
  ask "look rest"
  tell
}

# the first probe's T1, T4 and T6a, for an app whose hold had to be found
in_hand() {
  local x=$3 y=$4 at=$7 w=$8 h=$9 px py
  begin "$1" "$2" "$3" "$4" "$5" "$6" || return 0
  px=$((x + at)) py=$((y + GRIP))
  # shellcheck disable=SC2086
  hand drag "$px" "$py" $((px + 40)) $((py + 40)) $PULL
  ask "chain asked size $w $h"
  # shellcheck disable=SC2086
  hand drag-on $((px - 20)) $((py + 40)) $CARRY
  ask "look carried"
  let_go
}
the_cut() {
  local px py
  begin "$1" "$2" 200 364 600 240 || return 0
  px=$((200 + $3)) py=$((364 + GRIP))
  # shellcheck disable=SC2086
  hand drag "$px" "$py" $((px + 40)) $((py + 40)) $PULL
  ask "chain asked-low size 600 600"
  hand drag-on $((px + 40)) $((py + 40 - 324)) --steps 12 --duration 0.4 --hold 0.1
  ask "look carried-up" "chain asked-high size 600 600"
  # shellcheck disable=SC2086
  hand drag-on $((px + 100)) $((py + 40 - 324)) $CARRY
  ask "look carried"
  let_go
}

WATCHER=""
watched() {
  [ -z "$WATCHER" ] || kill_started "$WATCHER"
  echo "# axwatch on $APP begins at $(arbor_now) seconds since 1970; its own seconds count from there" >> "$EVENTS"
  "$TOOLS/axwatch" "$@" >> "$EVENTS" 2>&1 5<&- 6>&- 7>&- 8>&- 9>&- &
  WATCHER=$!
  started "$WATCHER"
  sleep 0.5
}

# MARK: The run

step "the Mac"
sw_vers
echo "defaults read com.apple.WindowManager:"
defaults read com.apple.WindowManager 2>&1 | sed 's/^/  /'
macos_reduce_motion
echo "the Dock: orientation $(defaults read com.apple.dock orientation 2>/dev/null || echo "not set"), autohide $(defaults read com.apple.dock autohide 2>/dev/null || echo "not set")"
pointer displays
apps_scratch

mkfifo "$STEPS/sampler-in" "$STEPS/sampler-out"
"$TOOLS/sampler" "$ARBOR_OUT/samples.log" "$STEPS/sampler-in" "$STEPS/sampler-out" --hz 60 2>> "$ARBOR_OUT/sampler-stderr.log" 7>&- 8>&- 9>&- &
SAMPLER_PID=$!
started "$SAMPLER_PID"
exec 6> "$STEPS/sampler-in" 5< "$STEPS/sampler-out"

# TextEdit is K3's window in front; hidden the rest of the time, so that no edge of it is near a window that is dragged.
TEXTEDIT=""
if app_open com.apple.TextEdit "$APPS_SCRATCH/oak.txt"; then
  TEXTEDIT=$APP_PID
  APP=textedit PID=$APP_PID WINDOW=$APP_WINDOW LABEL=textedit
  ask "put aside 450 300 400 300"
  tell
  apptool hide "$TEXTEDIT"
else
  echo "TextEdit: no window, so no K3"
fi
sleep 2 # the Dock has grown by an icon, and the visible frame with it

reopen_test_windows 1
sleep 2
APP=test-window PID=$ARBOR_WINDOWS_PID WINDOW=$W1 GRIP=12 LABEL=test-window
ask "look first"
# The line: the visible frame's bottom less 1, as the first lines of grow.swift have just said.
LINE=$(python3 -c '
import json, sys
for line in open(sys.argv[1]):
    o = json.loads(line)
    if o.get("kind") == "displays":
        v = o["displays"][0]["visible"]
print(int(v[1] + v[3] - 1))' "$STEPS/trial") || LINE=704
tell
echo "the line: $LINE"
export GROW_BRIEF=1
# shellcheck disable=SC2086
watched "$PID" $TEXTEDIT

worth_most() {
  at_rest_in_hand P1-size-and-position "$1" 40 120 936 400 800 "$BOTH"
  at_rest_in_hand P2-position-alone "$1" 200 150 600 400 300 "under 100 12"
  on_the_move M1-size-on-the-move "$1" 300 150 600 400 300 "size 480 300"
  on_the_move M2-size-and-position-on-the-move "$1" 60 120 936 400 800 "$BOTH"
}
for time in 1 2 3; do
  worth_most "$time"
  at_rest_in_hand K1-command-from-the-press "$time" 40 120 936 400 800 "$BOTH" cmd
  late_command K2-command-in-the-middle "$time"
  from_behind K3-command-on-a-window-behind "$time"
  for past in 19 40 80 150; do the_wall "W-$past-past-the-line" "$time" "$past"; done
done
for time in 4 5; do worth_most "$time"; done
echo "clock: one display done after ${SECONDS}s"
[ -z "$TEXTEDIT" ] || app_quit "$TEXTEDIT"

BUDGET=$((BUDGET + 245))
if in_time "the larger display"; then
  step "a larger display at the right"
  display_add 2560 1440 right
  "$ARBOR_VDISPLAY" list
  EDGE=$("$ARBOR_VDISPLAY" list | awk '$8 == "main" { print $3 + $5 }')
  [ -n "$EDGE" ] || die "vdisplay names no main display"
  # More than the display it comes from can hold between its menu bar and its Dock; grow.swift works it out from the displays as they are.
  TALL="vb1-vt1+150"
  LABEL=test-window.two-displays
  GROW_BRIEF="" ask "look first"
  tell
  for time in 1 2 3 4 5; do
    for after in 1 50 200 1000; do across "X-dropped-across-$after-ms" "$time" 10 "$after"; done
    across X-across-in-the-hand "$time" 10 hand
  done
  for time in 1 2 3; do
    for after in 1 200; do across "X-dropped-with-its-middle-across-$after-ms" "$time" -190 "$after"; done
  done
  echo "the forecast for what follows, from a model: the pair's size is cut to what the display it came from holds, and the second asking heals it"
  for time in 1 2 3 4 5; do
    own_pair X-rested-200-ms-dropped-mostly-behind-then-position-and-size "$time" 0.2 0
    own_pair X-rested-1000-ms-dropped-mostly-behind-then-position-and-size "$time" 1 0
    own_pair X-dropped-mostly-behind-then-position-and-size-1000-ms-later "$time" 0 1000
  done
  display_remove
  sleep 3
  echo "clock: two displays done after ${SECONDS}s"
fi
BUDGET=$((BUDGET + 30))

# comes_along <held at> <grip>: a short pull there, and whether the window came
comes_along() {
  local before after
  before=$(pointer frame "$WINDOW")
  arbor_input drag $((200 + $1)) $((150 + $2)) $((200 + $1 + 12)) $((150 + $2 + 12)) --steps 3 --duration 0.1 --hold 0.1 > /dev/null
  sleep 0.2
  after=$(pointer frame "$WINDOW")
  # Whatever the press opened instead.
  [ "$before" != "$after" ] || arbor_input key escape > /dev/null
  echo "  held $1 from the left, $2 from the top: $before -> $after"
  [ "$before" != "$after" ]
}
# real <name> <bundle id> [file…]
real() {
  local at grip found=""
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
  apptool activate "$PID"
  sleep 1
  for grip in 4 12 26; do
    for at in 150 110 480 540; do
      ask "put trying 200 150 600 400"
      if comes_along "$at" "$grip"; then found=yes; break 2; fi
    done
  done
  : > "$STEPS/trial"
  [ -n "$found" ] || { echo "$APP: no hold found"; app_quit "$PID"; return; }
  GRIP=$grip
  echo "$APP is held $at from the left, $GRIP from the top"
  watched "$PID"
  for time in 1 2; do
    in_hand T1-smaller "$time" 200 150 700 400 "$at" 600 300
    in_hand T4-narrower-than-where-it-is-held "$time" 40 120 936 400 800 304 400
    the_cut T6a-the-cut "$time" "$at"
  done
  app_quit "$PID"
  echo "clock: $APP done after ${SECONDS}s"
}
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
echo "NOT VARIED: one Mac, one macOS; one display, at scale 1; the Dock at the bottom, shown; macOS's tiling switches and Reduce Motion as the image has them (printed at the top); one Space, no Stage Manager, no full screen;"
echo "NOT VARIED in X: one app (the test window), one pair of displays, one direction (to the larger one, at the right), one size asked, the Dock at the bottom of the display it comes from."
echo "NOT VARIED: a synthetic pointer, in even steps; never near an edge or a corner of the display, nor in the menu bar; no modifier but ⌘; the speed of the pull at the wall; Arbor not running, so no event tap of its own in the way."
exit 0
