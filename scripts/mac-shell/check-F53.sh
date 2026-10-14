#!/bin/bash
# F53, summoning, on real windows of two apps, with a real pointer and real keys:
#
#   scripts/mac-shell/run.sh scripts/mac-shell/check-F53.sh
#
# What only a Mac can say, and this asks:
# - pressed as a real shortcut, does `summon` bring the other app's window over a framed window with the keyboard in it,
#   in front, without the view or any other window moving? Does it stay (no stale focus report sends it away at once)?
# - pressed again, is it out of view and the keyboard back in the window that had it?
# - does a real click on another app's window send it away?
# - dragged by its title bar, does it come back to that place, also after Arbor is launched again?
# - with summonStays, does it survive a click, in front?
# - with summonStays, is it covered after a click in the window that has the keyboard already?
# - pause, resume, quit: in view when Arbor lets go.
# - does opening an app by name work (Calculator; on GitHub's throwaway Macs only)?
#
# Safe on a person's Mac: it changes no setting, touches only windows it opened, and moves the pointer and
# presses keys. The part that launches Calculator is left out there.
source "$(dirname "$0")/lib.sh"

# What `summon` is asked for. A name no app on anybody's Mac has: when Arbor knows no window of an app of that name,
# `summon` looks for the app in the Applications folders and opens it.
APP=ArborTestWindows2

# None of this script's windows that lie in front of window $1, as the window server has them, overlaps it.
uncovered() {
  local x y w h
  read -r x y w h <<< "$(real_frame_of "$1")"
  [ -n "$h" ] || return 1
  "$ARBOR_POINTER" windows --on-screen | awk -v id="$1" -v x="$x" -v y="$y" -v w="$w" -v h="$h" -v mine=" $W1 $W2 $SCRATCH " '
    $1 == id { exit }
    index(mine, " " $1 " ") && $4 < x + w && $4 + $6 > x && $5 < y + h && $5 + $7 > y { covered = 1 }
    END { exit covered }'
}
# Windows $1 and $2 overlap, so that one can cover the other.
overlap() {
  echo "$(real_frame_of "$1") $(real_frame_of "$2")" \
    | awk '{ exit !($1 < $5 + $7 && $5 < $1 + $3 && $2 < $6 + $8 && $6 < $2 + $4) }'
}
# Where the scratch window's title bar has to go for the window to be near the top left corner of the display:
# over the editor's left edge, away from the middle, and wholly in view, or it would be summoned somewhere else.
a_place_of_its_own() {
  local sx sy sw sh x y w h
  read -r sx sy sw sh <<< "$(screen_of 1)"
  read -r x y w h <<< "$(frame_of "$SCRATCH")"
  [ -n "$h" ] || die "the scratch window has no frame"
  echo "$((sx + 40 + w / 2)) $((sy + 72))"
}
# A point in the editor's top right corner, clear of the scratch window.
in_the_editor() {
  local x y w h
  read -r x y w h <<< "$(frame_of "$W1")"
  [ -n "$h" ] || die "the editor has no frame"
  echo "$((x + w - 60)) $((y + 60))"
}
is_not() { ! is "$@"; }
is_not_shown() { ! has_overlay "$1"; }
at() { [ "$(real_frame_of "$1")" = "$2" ]; }
camera() { arbor_ask json | python3 -c 'import json, sys; print(json.load(sys.stdin)["displays"][0]["camera"])'; }
camera_is() { [ "$(camera)" = "$1" ]; }
trait() { arbor_ask json | python3 -c 'import json, sys; w = [w for w in json.load(sys.stdin)["windows"] if w["id"] == int(sys.argv[1])][0]; sys.exit(0 if w[sys.argv[2]] else 1)' "$1" "$2"; }
is_not_trait() { ! trait "$@"; }
running() { "$ARBOR_BIN/arborctl" status | grep -q "^running"; }
# For a second: for things that must not happen a moment later.
stays() {
  local tries=0
  while [ "$tries" -lt 10 ]; do
    "$@" || return 1
    sleep 0.1
    tries=$((tries + 1))
  done
}
here() {
  check "$1: in view" eventually is on_screen "$SCRATCH"
  check "$1: Arbor says summoned" eventually trait "$SCRATCH" summoned
  check "$1: it has the keyboard" eventually is focused "$SCRATCH"
  check "$1: nothing covers it" eventually uncovered "$SCRATCH"
  check "$1: and it stays" stays trait "$SCRATCH" summoned
  check "$1: the view did not move" camera_is "$view"
}
gone() {
  check "$1: out of view" eventually is_not on_screen "$SCRATCH"
  check "$1: Arbor says stashed" eventually trait "$SCRATCH" stashed
  check "$1: the keyboard is in $2" eventually is focused "$2"
  check "$1: the view did not move" camera_is "$view"
}

# A second app under a name of its own: `summon` finds apps by name, and both would be ArborTestWindows. A name nobody's app
# has: should the window be gone, `summon` would launch the app of that name, and there is one called Scratch.
open_scratch() {
  local hello="" tries=0 app=${ARBOR_TEST_WINDOWS_2:-}
  if [ -z "$app" ]; then
    app="$ARBOR_SESSION_DIR/$APP"
    cp "$ARBOR_BIN/ArborTestWindows" "$app"
  fi
  mkfifo "$ARBOR_SESSION_DIR/scratch-stdin"
  "$app" --count 1 < "$ARBOR_SESSION_DIR/scratch-stdin" > "$ARBOR_SESSION_DIR/scratch-hello" \
    2>> "$ARBOR_OUT/test-windows.log" &
  SCRATCH_PID=$!
  started "$SCRATCH_PID"
  exec 8> "$ARBOR_SESSION_DIR/scratch-stdin"
  while [ -z "$hello" ] && [ "$tries" -lt 100 ]; do
    sleep 0.1
    hello=$(head -n 1 "$ARBOR_SESSION_DIR/scratch-hello" 2>/dev/null)
    tries=$((tries + 1))
  done
  SCRATCH=$(python3 -c 'import json, sys; print(json.loads(sys.argv[1])["windows"][0])' "$hello") \
    || die "the second app did not report its window (got: $hello)"
  ARBOR_EXTRA_PIDS=$SCRATCH_PID
}
close_scratch() {
  exec 8>&-
  arbor_await_exit "$SCRATCH_PID" 30 || kill -TERM "$SCRATCH_PID" 2>/dev/null
}

arbor_build

step "an editor and a browser from one app, a scratch window from another; ⌃⌥\` summons it"
arbor_settings '{"bindings": {"ctrl+opt+`": "summon '$APP'"}}'
open_scratch
arbor_start 2 ARBOR_NO_HOTKEYS=0
check "Arbor arranges the other app's window too" eventually is managed "$SCRATCH"
arbor_ask json | python3 -c 'import json, sys; [print("w%d is of app %s (%s)" % (w["id"], w["app"], w["bundleID"])) for w in json.load(sys.stdin)["windows"]]'
ctl dock "$W1" left
ctl dock "$W2" right
# shellcheck disable=SC2046
click $(center_of "$W1")
ctl zoom "$W1"
check "framed on the editor: the scratch window is out of view with the Desktop" eventually is parked "$SCRATCH"
check "the editor has the keyboard" eventually is focused "$W1"
view=$(camera)
editor=$(real_frame_of "$W1")
shot 01-framed

step "1: the shortcut"
key 'ctrl+opt+`'
here "summoned"
check "the editor has not moved" at "$W1" "$editor"
summary
shot 02-summoned

step "2: the shortcut again"
key 'ctrl+opt+`'
gone "sent away" "$W1"
check "the editor has not moved" at "$W1" "$editor"
shot 03-sent-away

step "4: it remembers where it was put"
key 'ctrl+opt+`'
here "summoned again"
# shellcheck disable=SC2046
drag $(titlebar_of "$SCRATCH") $(a_place_of_its_own) --no-release
check "dragged over the editor's edge: no preview" is_not_shown 3
release
check "dropped, it is still summoned" eventually trait "$SCRATCH" summoned
sleep 1
chosen=$(real_frame_of "$SCRATCH")
echo "put at $chosen"

step "3: a real click on another app's window sends it away"
# shellcheck disable=SC2046
click $(in_the_editor)
gone "after a click on the editor" "$W1"
key 'ctrl+opt+`'
here "summoned a third time"
check "where it was put" eventually at "$SCRATCH" "$chosen"
shot 04-where-it-was-put
key 'ctrl+opt+`'
gone "sent away" "$W1"

step "where the Desktop is in view it goes out of view all the same"
ctl show-all
view=$(camera)
check "showing everything, it is still out of view" stays is_not on_screen "$SCRATCH"
shot 05-everything-without-it
key 'ctrl+opt+`'
here "summoned over everything"
key 'ctrl+opt+`'
gone "sent away" "$W1"

step "framing a window that was sent away summons it; float makes it an ordinary window again"
ctl zoom "$SCRATCH"
here "framed"
check "where it was put" eventually at "$SCRATCH" "$chosen"
key 'ctrl+opt+`'
gone "sent away" "$W1"
ctl float "$SCRATCH"
check "floated: in view, on the Desktop" eventually is on_screen "$SCRATCH"
check "floated: no longer stashed" is_not_trait "$SCRATCH" stashed
check "floated: nor summoned" is_not_trait "$SCRATCH" summoned
check "floated: the keyboard is still in the editor" is focused "$W1"
key 'ctrl+opt+`'
here "summoned from the Desktop"
key 'ctrl+opt+`'
gone "sent away" "$W1"

step "⌃⌥0 brings it back to the Desktop as an ordinary window"
key ctrl+opt+0
check "in view" eventually is on_screen "$SCRATCH"
check "no longer stashed" is_not_trait "$SCRATCH" stashed
shot 05b-home

step "a docked window has a place"
ctl zoom "$W1"
check "framed" eventually is parked "$W2"
ctl summon ArborTestWindows
ctl status
summary

step "summonStays"
ctl zoom "$W1"
# shellcheck disable=SC2046
click $(center_of "$W1")
view=$(camera)
arbor_settings '{"bindings": {"ctrl+opt+`": "summon '$APP'"}, "summonStays": true}'
ctl reload-settings
key 'ctrl+opt+`'
here "summoned"
# Or "nothing covers it" could not fail.
check "it lies over the editor" overlap "$SCRATCH" "$W1"
# shellcheck disable=SC2046
click $(in_the_editor)
check "after a click on the editor the editor has the keyboard" eventually is focused "$W1"
check "it is still summoned" stays trait "$SCRATCH" summoned
check "where it was" at "$SCRATCH" "$chosen"
check "and nothing covers it" eventually uncovered "$SCRATCH"
shot 06-stays
# The window that has the keyboard already: no focus change is reported, only the press tells Arbor to look.
# shellcheck disable=SC2046
click $(in_the_editor)
sleep 1
check "after a second click on the editor nothing covers it either" eventually uncovered "$SCRATCH"
check "the editor still has the keyboard" is focused "$W1"
key 'ctrl+opt+`'
gone "summoned away" "$W1"
arbor_settings '{"bindings": {"ctrl+opt+`": "summon '$APP'"}}'
ctl reload-settings

step "pause and resume"
key 'ctrl+opt+`'
here "summoned"
spot=$(in_the_editor)
ctl pause
sleep 1
check "paused: it has not moved" at "$SCRATCH" "$chosen"
ctl resume
check "running again" eventually running
check "resumed with the keyboard still in it: summoned again" eventually trait "$SCRATCH" summoned
check "where it was" at "$SCRATCH" "$chosen"
ctl pause
sleep 1
# The keyboard goes elsewhere during the pause, which Arbor does not see.
# shellcheck disable=SC2086
click $spot
ctl resume
check "running again" eventually running
check "resumed: out of view" eventually is_not on_screen "$SCRATCH"
check "resumed: stashed" trait "$SCRATCH" stashed

step "4: quit and launch again on the same windows"
echo "> quit"
"$ARBOR_BIN/arborctl" quit
check "Arbor exits" arbor_await_exit "$ARBOR_PID" 50
# Or the wait would never end.
kill -0 "$ARBOR_PID" 2>/dev/null && kill -KILL "$ARBOR_PID"
wait "$ARBOR_PID" 2>/dev/null
check "quit: the scratch window is back in view" eventually is on_screen "$SCRATCH"
shot 07-after-quit
cp "$ARBOR_HOME/arbor.log" "$ARBOR_OUT/arbor-first-run.log"
env ARBOR_ONLY_PIDS="$ARBOR_WINDOWS_PID,$SCRATCH_PID" ARBOR_NO_PROMPT=1 ARBOR_DEBUG=1 ARBOR_NO_HOTKEYS=0 \
  ARBOR_NO_STATUS_ITEM=1 ARBOR_NO_WATCHDOG=1 "$ARBOR_BIN/Arbor" > "$ARBOR_OUT/arbor-stderr-relaunch.log" 2>&1 8>&- 9>&- &
ARBOR_PID=$!
started "$ARBOR_PID"
check "running again" eventually running
check "relaunched: stashed, and out of view again" eventually is_not on_screen "$SCRATCH"
# shellcheck disable=SC2046
click $(center_of "$W1")
view=$(camera)
key 'ctrl+opt+`'
here "relaunched and summoned"
check "where it was put before the restart" eventually at "$SCRATCH" "$chosen"
shot 08-relaunched
ctl float-all
check "float-all: an ordinary window again" eventually is_not_trait "$SCRATCH" summoned
check "float-all: in view" is on_screen "$SCRATCH"

step "5: apps without a window"
ctl summon "No Such App 42"
if [ -n "${ARBOR_REHEARSAL:-}" ]; then
  echo "skipped: the rehearsal's Mac has no Calculator"
elif arbor_may "launch Calculator"; then
  pgrep -x Calculator > /dev/null && echo "Calculator is running already"
  ctl summon Calculator
  check "Calculator was launched by its name" eventually pgrep -x Calculator
  # This session arranges only its own test windows, so Calculator's window is not summoned: that is for a person to see.
  pkill -x Calculator
fi

arbor_stop 09-quit
close_scratch
