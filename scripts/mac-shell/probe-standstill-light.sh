#!/bin/bash
# Does the display stand still where there is no stage at all? Arbor without motion, without the ring and with one icon; and THE CONTROL: a plain tool that does
# the same to the same windows with no Arbor anywhere.
#
#   scripts/mac-shell/rehearse.sh scripts/mac-shell/probe-standstill-light.sh
#   scripts/mac-shell/run.sh scripts/mac-shell/probe-standstill-light.sh          a quarter of an hour on a hosted Mac
#   scripts/mac-shell/standstill.py table .mac-shell/probe-standstill-light-<run id>
#
# Found in films of a hosted Mac, with the stage: back from the Desktop, and back out of a window that is a tile in the view one returns to, the display shows one
# picture for 0.4 to 1 s. Both end with a tile of Arbor's fading in while windows come back from the corner; in the second the keyboard changes hands as well.
# THE QUESTION ONLY A MAC CAN ANSWER: with windows going to their places at once, does the display still stand still (a strip on top of everything
# never stops moving, so a wait between two frames is a display that stood still): in a dock, a fill, a switch to another app, an act in which Arbor moves
# windows and hands the keyboard to another app, a tile that comes and goes? And does a plain tool get the same: the moves alone, with the keyboard
# handed over (AXMain, AXRaise, activate), with a tile that fades, and the activation alone?
#
# The settings are written out, so that the films mean the same whatever ships. What says most comes first; what comes last is left out if time runs short.
ARBOR_TIME_LIMIT=1170
source "$(dirname "$0")/lib-standstill.sh"
needs_throwaway_mac "film the whole display, change Accessibility settings, and sample every process as root"

LIGHT='{"animationDuration": 0, "focusRing": false, "menuBarControls": false}'

still_build
still_begin
pulse_start

step "0. the instruments: nothing is done; then holds that are known to be holds (if macOS still knows the call: a row of 17 ms says that it does not)"
arbor_settings "$LIGHT"
cast_start 4 $STILL_FACE
sleep 3
filmed rest-1 "nothing is done" sleep 0.5
filmed hold-1-700 "a tool holds screen updates for 0.7 s" mover wait:700 go hold:700
filmed hold-1-1600 "a tool holds screen updates for 1.6 s" mover wait:700 go hold:1600

step "1. a dock"
tell 4 "move $W4 40 70 300 200"
tell 1 "move $W1 400 70 300 190"
tell 2 "move $W2 400 285 300 190"
tell 3 "move $W3 400 500 300 190"
sleep 1.5
still_press "$W4"
filmed dock-1 "docks a floating window at the left (⌃⌥⌘←)" key ctrl+opt+cmd+left
still_press "$W3"
filmed dock-2 "docks a second window at the right (⌃⌥⌘→)" key ctrl+opt+cmd+right

step "2. a fill, and everything again: the keyboard stays where it is"
still_arrange wide
still_press "$W4"
i=1
while [ "$i" -le 2 ]; do
  filmed "fill-$i-away" "fills the screen with a docked window (⌃⌥↩)" key ctrl+opt+return
  filmed "fill-$i-back" "shows everything again (⌃⌥Space)" key ctrl+opt+space
  i=$((i + 1))
done

step "3. one act of Arbor's moves windows AND hands the keyboard to another app: from one window that fills the screen to another"
key ctrl+opt+return
sleep 1.5
i=1
while [ "$i" -le 3 ]; do
  filmed "handover-$i-there" "asks Arbor for another app's window, which is out of view" ctl focus "$W3"
  filmed "handover-$i-back" "and for the first again" ctl focus "$W4"
  i=$((i + 1))
done

step "4. a switch: the other app comes forward by itself, as after ⌘Tab or a click in the Dock, and Arbor follows"
i=1
while [ "$i" -le 2 ]; do
  filmed "switch-$i-there" "switches to another app, whose window is out of view" tell 3 activate
  filmed "switch-$i-back" "and to the first again" tell 4 activate
  i=$((i + 1))
done
key ctrl+opt+space
sleep 1.5

step "5. the Desktop and back, with a tile for the Desktop in the view one returns to; the same with tiles at once; the same with no tile"
still_arrange
still_press "$W3"
check "a tile stands for the Desktop" count tiles 1
away_and_back tile-desktop 3
ctl set tileFade 0
away_and_back tile-desktop-no-fade 2
ctl reset tileFade
still_arrange wide
still_press "$W3"
check "there is no tile" count tiles 0
away_and_back wide-desktop 2
cast_stop

# in_and_out <name> <n>: a click on the tile, a film; ⌃⌥[, a film
in_and_out() {
  local name=$1 times=${2:-3} i=1
  while [ "$i" -le "$times" ]; do
    # shellcheck disable=SC2046
    filmed "$name-$i-open" "clicks the tile" click $(tile_of "$W3")
    filmed "$name-$i-back" "presses ⌃⌥[" key ctrl+opt+[
    i=$((i + 1))
  done
}

# Two windows docked side by side and a third that cannot be as narrow as its slot: a tile.
tile_session() {
  ARBOR_TEST_WINDOWS_ARGS="--regular --min-size 3:700x500"
  arbor_settings "$LIGHT"
  cast_start 3 $STILL_FACE "$@"
  sleep 3
  ctl dock "$W1" left
  ctl dock "$W2" right
  sleep 1.5
  still_press "$W3"
  key ctrl+opt+cmd+right
  sleep 2
  summary
  check "the third window is a tile" is tile "$W3"
}

# The frame of the only tile, as x:y:w:h.
tile_frame() {
  "$ARBOR_BIN/arborctl" state | python3 -c '
import json, sys
tiles = [tile for display in json.load(sys.stdin)["state"]["displays"] for tile in display["tiles"]]
(x, y), (w, h) = tiles[0]["frame"] if tiles else ((771, 43), (241, 656))
print(":".join(str(round(value)) for value in (x, y, w, h)))'
}

step "6. into a window that is a tile, and back out: windows come back, a tile fades in, the keyboard changes hands"
tile_session
in_and_out tile 3
ctl set tileFade 0
in_and_out tile-no-fade 2
ctl reset tileFade

# Where things are in the two views, for the control.
read -r AX1 AY1 _ _ <<< "$(frame_of "$W1")"
read -r AX2 AY2 _ _ <<< "$(frame_of "$W2")"
TILE=$(tile_frame)
echo "the tile: $TILE"
# shellcheck disable=SC2046
click $(tile_of "$W3")
sleep 2
read -r BX3 BY3 _ _ <<< "$(frame_of "$W3")"
read -r dx dy dw dh <<< "$(display_frame_of 1)"
PX=$((dx + dw - 1))
PY=$((dy + dh - 1))

step "7. THE CONTROL: no Arbor; the view as it is with the large window open"
trace_ends
# Killed, not asked to quit: a quit gives every window its earlier size back, and the control wants them as they are.
arbor_kill
sleep 1
shot control-open
# control <name> <n> "<after the moves back>"
control() {
  local name=$1 times=$2 after=$3 i=1
  while [ "$i" -le "$times" ]; do
    # shellcheck disable=SC2086
    filmed "$name-$i-back" "a tool brings two windows back and sends the third away" \
      mover observe wait:700 go "move:$W1:${AX1:-12}:${AY1:-43}" "move:$W2:${AX2:-518}:${AY2:-43}" "move:$W3:$PX:$PY" $after
    filmed "$name-$i-open" "a tool does the opposite" \
      mover observe wait:700 go "move:$W3:${BX3:-12}:${BY3:-43}" "move:$W1:$PX:$PY" "move:$W2:$PX:$PY" "focus:$W3"
    i=$((i + 1))
  done
}
control moves-keyboard 3 "focus:$W2"
control moves 2 ""
control moves-tile 2 "tile:$TILE:0.2"
control moves-tile-keyboard 2 "tile:$TILE:0.2 focus:$W2"

step "7a. the activation alone: nothing moves"
mover "move:$W1:${AX1:-12}:${AY1:-43}" "move:$W2:${AX2:-518}:${AY2:-43}" "move:$W3:$PX:$PY" "focus:$W2"
sleep 1
i=1
while [ "$i" -le 2 ]; do
  filmed "keyboard-alone-$i-there" "a tool hands the keyboard to another app's window, which is in view" mover observe wait:700 go "focus:$W1"
  filmed "keyboard-alone-$i-back" "and back" mover observe wait:700 go "focus:$W2"
  i=$((i + 1))
done
arbor_relaunch
cast_stop

if still_has 100 "Arbor that asks for AXMain and AXRaise and leaves the app where it is"; then
  step "8. Arbor, which asks for AXMain and AXRaise and leaves the app where it is"
  tile_session ARBOR_PROBE=no-activate
  in_and_out no-activate 2
  cast_stop
fi

if still_has 150 "who waits for whom"; then
  step "9. who waits for whom"
  tile_session
  # shellcheck disable=SC2046
  click $(tile_of "$W3")
  sleep 3
  watched watched-spindump-tile-back key ctrl+opt+[
  cast_stop
fi

still_end
system_log_of_the_worst 4
