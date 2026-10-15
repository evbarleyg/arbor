#!/bin/bash
# Records traces of real windows on a Mac (docs/TRACES.md): what macOS reports, and in what order, when a
# person drags, resizes, minimizes and closes windows, and how real apps answer when Arbor moves them. Run it with
#
#   scripts/mac-shell/run.sh scripts/mac-shell/trace-demo.sh
#
# The traces come back in traces/, with a replay of each in replays/. The useful ones are committed under
# collab/evidence/traces/, where a test replays them on every platform.
#
# Session 1: ArborTestWindows, driven by a real pointer. Session 2: test windows that do things by themselves, as odd apps
# do. Then one real app per session (TextEdit, Finder, System Settings, Terminal, Calculator), whichever can be launched,
# and all of them together.
#
# On a person's Mac only the sessions with test windows run; they move the pointer and touch nothing else.
#
# Positions are worked out before a trace starts and nothing polls Arbor while one is recorded, so that a trace holds
# what happened and not the script's questions.
source "$(dirname "$0")/lib.sh"
# It records its own, one for each gesture.
ARBOR_NO_TRACE=1

TRACES="$ARBOR_OUT/traces"
REPLAYS="$ARBOR_OUT/replays"
mkdir -p "$TRACES" "$REPLAYS"

# tw <command…>: tell ArborTestWindows to do something to its own windows (descriptor 9 is its stdin).
tw() {
  echo "> test windows: $*"
  echo "$*" >&9
  sleep 0.4
}

trace_on() {
  step "trace $1: $2"
  ctl trace on "$1"
  "$ARBOR_BIN/arborctl" trace note "$2" > /dev/null
}

note() {
  echo "# $*"
  "$ARBOR_BIN/arborctl" trace note "$*" > /dev/null
}

# Echoes, put-backs and saves arrive up to a second after the last thing that happened.
trace_off() {
  sleep "${1:-1.5}"
  ctl trace off
  summary
}

# Brings the traces of the session in folder $1 back, without the date in their names.
collect() {
  local file base
  for file in "$1"/traces/*.jsonl; do
    [ -f "$file" ] || continue
    base=${file##*/}
    cp "$file" "$TRACES/${base:18}"
  done
}

pid_of() { "$ARBOR_BIN/arborctl" state | python3 -c '
import json, sys
wanted = int(sys.argv[1])
print(next(w["pid"] for w in json.load(sys.stdin)["state"]["windows"] if w["id"] == wanted))' "$1"; }

# button_of <window> close|minimize|zoom
button_of() {
  local x y
  read -r x y _ _ <<< "$(frame_of "$1")"
  pointer button "$(pid_of "$1")" "$x" "$y" "$2"
}

arbor_build
step "the Mac"
echo "macOS $(sw_vers -productVersion) ($(sw_vers -buildVersion)) on $(uname -m)"
pointer displays
# Its drags dock at the left and right edges of the screen, which are Arbor's only with macOS's own tiling off (MacTiling.swift). It declines on a
# person's Mac, where the setting is theirs; with the tiling on there, those steps fail.
macos_tiling off

# MARK: Test windows

BUILD="ARBOR_BUILD=$(git rev-parse --short HEAD)"

# The runner's display is 1024 points wide and a slot under 240 becomes a tile, so layouts are kept to two docked windows
# and the Desktop, and every press is on a window that is in view.
pressable() { is on_screen "$1" || { echo "skipped: window $1 is not in view"; return 1; }; }

step "session 1: three test windows and a real pointer"
ARBOR_TEST_WINDOWS_ARGS=""
arbor_start 3 "$BUILD"
summary
read -r sx sy sw sh <<< "$(arbor_ask screen)"
left_x=$((sx + 3))
right_x=$((sx + sw - 3))
middle_y=$((sy + sh / 2))

read -r x y <<< "$(titlebar_of "$W3")"
trace_on click-title-bar "a press and release on a floating window's title bar, without moving"
click "$x" "$y"
trace_off 1

read -r x y <<< "$(titlebar_of "$W3")"
trace_on drag-to-edge "a floating window is dragged by its title bar to the left screen edge and released there"
drag "$x" "$y" "$left_x" "$middle_y"
trace_off
check "the window docked" is docked "$W3"
shot 01-drag-to-edge

tw front "$W2"
read -r x y <<< "$(titlebar_of "$W2")"
read -r fx fy fw fh <<< "$(frame_of "$W3")"
trace_on drag-onto-window "a floating window is dragged onto the right part of a docked window and released"
drag "$x" "$y" "$((fx + fw * 85 / 100))" "$((fy + fh / 2))"
trace_off
check "the window docked beside the other" is docked "$W2"
shot 02-drag-onto-window

# Room for the neighbour to give 60 points and stay a window.
ctl resize "$W2" right 200
sleep 1
read -r fx fy fw fh <<< "$(frame_of "$W3")"
trace_on edge-resize "the right edge of a docked window, which has a docked neighbour, is dragged 60 points to the right"
drag "$((fx + fw - 1))" "$((fy + fh / 2))" "$((fx + fw + 59))" "$((fy + fh / 2))"
trace_off
read -r _ _ fw_after _ <<< "$(frame_of "$W3")"
echo "the window was $fw wide and is now $fw_after"
check "the neighbour is still a window" is on_screen "$W2"

read -r x y <<< "$(seam_right_of "$W3")"
trace_on seam-drag "the seam between two docked windows is dragged 40 points to the left"
drag "$x" "$y" "$((x - 40))" "$y" --steps 12
trace_off

if pressable "$W2"; then
  read -r x y <<< "$(button_of "$W2" minimize)"
  echo "the minimize button is at $x $y; the window at $(frame_of "$W2")"
  trace_on minimize-restore "a docked window is minimized with its yellow button; two seconds later its app restores it"
  click "$x" "$y"
  sleep 2
  note "the app restores the window"
  tw restore "$W2"
  trace_off 2
  shot 03-restored
  # macOS reports the focus before the restoring, and Arbor frames the window (bug B7).
  ctl show-all
  sleep 1
fi

if pressable "$W3"; then
  read -r x y <<< "$(titlebar_of "$W3")"
  trace_on double-click-docked "a double-click on the title bar of a docked window"
  dblclick "$x" "$y"
  trace_off 2.5
  shot 04-double-click-docked
fi

tw front "$W1"
if pressable "$W1"; then
  read -r x y <<< "$(titlebar_of "$W1")"
  trace_on double-click-floating "a double-click on the title bar of a floating window"
  dblclick "$x" "$y"
  trace_off 2.5
  shot 05-double-click-floating
  ctl relayout
  sleep 0.5
fi

tw front "$W3"
if pressable "$W3"; then
  read -r x y <<< "$(titlebar_of "$W3")"
  read -r dx dy dw dh <<< "$(arbor_ask desktop)"
  trace_on drag-out "a docked window is dragged by its title bar out onto the Desktop and released"
  drag "$x" "$y" "$((dx + dw / 2))" "$((dy + dh / 3))"
  trace_off
  check "the window floats" is floating "$W3"
fi

tw front "$W3"
if pressable "$W3"; then
  read -r x y <<< "$(titlebar_of "$W3")"
  trace_on flick-to-edge "a floating window is flicked to the left screen edge: 0.12 s, released at once"
  drag "$x" "$y" "$left_x" "$middle_y" --duration 0.12 --steps 6 --hold 0 --no-settle
  trace_off
  shot 06-flick
fi

if pressable "$W2"; then
  read -r x y <<< "$(button_of "$W2" close)"
  trace_on close "a docked window is closed with its red button"
  click "$x" "$y"
  trace_off
fi

home=$ARBOR_HOME
trace_on quit "Arbor is told to quit while windows are docked"
arbor_stop 07-after-quit
collect "$home"

step "session 2: four test windows that do things by themselves"
ARBOR_TEST_WINDOWS_ARGS="--min-size 3:700x500"
arbor_start 4 "$BUILD"
ctl dock "$W4" left
ctl dock "$W2" beside "$W4" right
sleep 1
summary

trace_on too-big "a window that refuses to be smaller than 700×500 is docked into a smaller slot by a command"
ctl dock "$W3" beside "$W4" bottom
sleep 1.5
note "show-all"
ctl show-all
trace_off
shot 10-too-big

if is tile "$W3"; then
  read -r x y <<< "$(tile_of "$W3")"
  trace_on tile-click "a click on the tile of the window that is too big for its slot, then show-all"
  click "$x" "$y"
  sleep 1.5
  ctl show-all
  trace_off
fi

trace_on zoom-back "zoom onto a docked window and back, by commands: the others are parked and return"
ctl zoom "$W4"
sleep 1.5
ctl back
trace_off

trace_on title-change "the app changes the title of a docked window, then of a floating one"
tw title "$W4" Another title
tw title "$W1" Yet another title
trace_off 1

read -r x y w h <<< "$(frame_of "$W4")"
trace_on self-move "the app moves its own docked window 30 points right and 20 down, without the mouse"
tw move "$W4" "$((x + 30))" "$((y + 20))" "$w" "$h"
trace_off 2

trace_on app-minimize "the app minimizes its own docked window; two seconds later it restores it"
tw minimize "$W2"
sleep 2
note "restore"
tw restore "$W2"
trace_off 2
ctl show-all
sleep 1

# A window that goes back to a frame of its own after every move. It takes that frame while it floats somewhere else
# than its slot, or docking would not move it.
# stubborn <trace> <how soon, in words> <seconds to record> [quick]
stubborn() {
  local x y w h
  ctl float "$W4"
  sleep 0.5
  read -r x y w h <<< "$(frame_of "$W4")"
  tw insist "$W4" "$((x + 260))" "$((y + 90))" "$w" "$h" ${4:-}
  sleep 0.5
  trace_on "$1" "a window that goes back to its old frame $2 after every move is docked by a command"
  ctl dock "$W4" left
  trace_off "$3"
  tw relent "$W4"
  shot "11-$1"
  ctl relayout
  sleep 0.5
}
stubborn stubborn-fast "within 0.05 s" 4 quick
stubborn stubborn-slow "a quarter of a second" 6

trace_on hide-unhide "the app hides itself; two seconds later it unhides"
tw hide
sleep 2
note "unhide"
tw unhide
trace_off 2
shot 12-unhidden
home=$ARBOR_HOME
arbor_stop
collect "$home"

# MARK: Real apps

scratch_dir trace-demo scratch
mkdir -p "$scratch/empty"
echo "nothing to see" > "$scratch/note.txt"

# window_of <bundle id>: the first window of that app that Arbor arranges
window_of() { "$ARBOR_BIN/arborctl" state | python3 -c '
import json, sys
windows = json.load(sys.stdin)["state"]["windows"]
print(next((w["id"] for w in windows if w["bundleID"] == sys.argv[1] and w["managed"]), ""))' "$1"; }

# Where to press to drag a window: a share of its width in percent and a depth, both free of buttons in that app.
grab_of() {
  local x y w h
  read -r x y w h <<< "$(frame_of "$1")"
  echo "$((x + w * GRAB_PERCENT / 100)) $((y + GRAB_DEPTH))"
}

# real_app <name for the trace> <process name> <bundle id> <arguments for open…>
real_app() {
  local name=$1 process=$2 bundle=$3 pid id tries=0 home x y w h
  shift 3
  step "real app: $name"
  # On a person's Mac these would be their documents and their shells.
  arbor_may "arrange whatever windows $process has open, and quit it afterwards" || return 0
  open "$@" || { echo "could not open $name"; return; }
  while ! pid=$(pgrep -x "$process" | head -n 1) || [ -z "$pid" ]; do
    [ "$tries" -ge 50 ] && { echo "$process did not start"; return; }
    sleep 0.2
    tries=$((tries + 1))
  done
  sleep 3
  ALL_PIDS="${ALL_PIDS:+$ALL_PIDS,}$pid"
  ARBOR_TEST_WINDOWS_ARGS=""
  # No test window is waited for: Arbor is limited to the app, which may turn out to have no window.
  arbor_start 0 ARBOR_ONLY_PIDS="$pid" "$BUILD"
  tw hide  # The harness's own test window opens in front of the app.
  id=$(window_of "$bundle")
  if [ -z "$id" ]; then
    echo "$name shows no window Arbor would arrange"
    summary
    shot "20-$name-no-window"
    arbor_stop
    return
  fi
  summary
  home=$ARBOR_HOME

  open "$@"  # In front, so that it can be pressed.
  sleep 1
  read -r x y <<< "$(grab_of "$id")"
  trace_on "$name-drag" "$name, floating: dragged by its title bar 150 points right and 60 down, then to the left screen edge"
  drag "$x" "$y" "$((x + 150))" "$((y + 60))"
  sleep 1.5
  read -r x y <<< "$(grab_of "$id")"
  note "to the left screen edge"
  drag "$x" "$y" "$left_x" "$middle_y"
  trace_off
  shot "21-$name-after-drag"

  # A slot 760 points wide, which every one of these apps fits.
  ctl dock "$id" left
  ctl resize "$id" right 266
  ctl show-all
  sleep 1
  if pressable "$id"; then
    read -r x y w h <<< "$(frame_of "$id")"
    trace_on "$name-edge" "$name, docked on the left in a slot 760 points wide: its right edge is dragged 80 points to the left"
    drag "$((x + w - 1))" "$((y + h / 2))" "$((x + w - 81))" "$((y + h / 2))"
    trace_off
    shot "22-$name-after-edge"
    read -r x y <<< "$(grab_of "$id")"
    trace_on "$name-drag-out" "$name, docked: dragged by its title bar out onto the Desktop"
    drag "$x" "$y" "$((sx + sw - 120))" "$((sy + sh / 3))"
    trace_off
  fi
  ctl float "$id"
  sleep 1

  trace_on "$name-commands" "$name: dock left, make the slot 250 points narrower, frame it, show the Desktop, show all, float"
  ctl dock "$id" left
  sleep 1.5
  ctl resize "$id" right -250
  sleep 1.5
  ctl zoom "$id"
  sleep 1.5
  ctl desktop
  sleep 1.5
  ctl show-all
  sleep 1.5
  ctl float "$id"
  trace_off
  shot "23-$name-after-commands"

  arbor_stop
  collect "$home"
}

ALL_PIDS=""
GRAB_PERCENT=50
GRAB_DEPTH=12
real_app textedit TextEdit com.apple.TextEdit -a TextEdit "$scratch/note.txt"
real_app finder Finder com.apple.finder "$scratch/empty"
real_app settings "System Settings" com.apple.systempreferences -a "System Settings"
real_app terminal Terminal com.apple.Terminal -a Terminal
# Between the two buttons on the right of its title bar.
GRAB_PERCENT=75
GRAB_DEPTH=26
real_app calculator Calculator com.apple.calculator -a Calculator

if on_throwaway_mac && [ -n "$ALL_PIDS" ]; then
  step "all the real apps together"
  arbor_start 0 ARBOR_ONLY_PIDS="$ALL_PIDS" "$BUILD"
  summary
  home=$ARBOR_HOME
  trace_on apps-arrange "every real app's window: arrange, show the Desktop, show all, float all"
  ctl arrange
  sleep 2
  ctl desktop
  sleep 1.5
  ctl show-all
  sleep 1.5
  ctl float-all
  trace_off
  shot 30-apps
  id=$(window_of com.apple.TextEdit)
  if [ -n "$id" ]; then
    ctl dock "$id" left
    ctl zoom "$id"
    sleep 1
    trace_on app-quits "TextEdit quits while its docked window is framed"
    killall TextEdit
    trace_off 2
  fi
  arbor_stop
  collect "$home"
fi
if on_throwaway_mac; then
  for process in TextEdit Calculator "System Settings" Terminal; do killall "$process" 2> /dev/null; done
fi

# MARK: What came of it

step "the traces, each replayed here"
for file in "$TRACES"/*.jsonl; do
  [ -f "$file" ] || continue
  name=$(basename "$file" .jsonl)
  "$ARBOR_BIN/arbor-sim" replay "$file" > "$REPLAYS/$name.txt" 2>&1
  free=$?
  "$ARBOR_BIN/arbor-sim" replay "$file" --strict > "$REPLAYS/$name.strict.txt" 2>&1
  strict=$?
  echo "$name: $(wc -l < "$file" | tr -d ' ') lines, $(wc -c < "$file" | tr -d ' ') bytes; free replay exit $free, strict $strict"
done
check "no window title is in any trace" sh -c "! grep -l 'Arbor Test\|Another title\|note.txt' '$TRACES'/*.jsonl"
