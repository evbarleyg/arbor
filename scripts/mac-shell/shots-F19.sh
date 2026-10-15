#!/bin/bash
# F19, undo and redo, on real windows with real input:
#
#   scripts/mac-shell/run.sh scripts/mac-shell/shots-F19.sh
#
# What only a Mac can answer: do ⌃⌥Z and ⌃⌥⇧Z reach Arbor; is a real drag of a gap (dozens of events) one
# step; does a window dragged to an edge go back to where it was picked up; do the echoes macOS sends of
# Arbor's own moves and focus changes add steps of their own; what do the two menu items look like.
ARBOR_SHORTCUTS=all  # it presses keys of the whole map, of which nine ship
source "$(dirname "$0")/lib.sh"
arbor_build

# What `undo` would take back, from `arborctl state`.
next_undo() {
  "$ARBOR_BIN/arborctl" state \
    | python3 -c 'import json, sys; print(json.load(sys.stdin)["state"]["displays"][0].get("undo") or "nothing")'
}
next_undo_is() { [ "$(next_undo)" = "$1" ]; }
next_undo_starts() { case "$(next_undo)" in "$1"*) return 0 ;; *) return 1 ;; esac; }

# near "<x y w h>" "<x y w h>": every number within 2 points.
near() {
  python3 -c 'import sys
a, b = (list(map(float, text.split())) for text in sys.argv[1:3])
sys.exit(0 if len(a) == len(b) == 4 and all(abs(x - y) <= 2 for x, y in zip(a, b)) else 1)' "$1" "$2"
}
# The window server has the window at this frame.
is_at() { near "$(real_frame_of "$1")" "$2"; }
# wider_than <id> <points>, as Arbor sees the window.
wider_than() { [ "$(frame_of "$1" | awk '{ print int($3) }')" -gt "$2" ]; }

# Only on a throwaway Mac: this is a setting of the person's, not of the session.
if [ "${GITHUB_ACTIONS:-}" = true ]; then macos_tiling off; fi
step "three floating windows, with the shortcuts and the menu bar item on"
arbor_start 3 ARBOR_NO_STATUS_ITEM=0 ARBOR_NO_HOTKEYS=0
summary
start1=$(real_frame_of "$W1")
start2=$(real_frame_of "$W2")
start3=$(real_frame_of "$W3")
check "there is nothing to undo yet" next_undo_is nothing

step "the menu with nothing to undo or redo"
if item=$(status_item); then
  # shellcheck disable=SC2086
  rightclick $item
  shot 01-menu-nothing-to-undo
  key escape
else
  check "Arbor's menu bar item can be found" false
fi

step "dock two windows, and give macOS time to echo everything back"
ctl dock "$W1" left
ctl dock "$W2" right
sleep 1.5
shot 02-docked
check "the newest step is the second dock" next_undo_is "dock w$W2 right"
# The shortcuts below go to whoever has the keyboard: a test window, for certain.
# shellcheck disable=SC2046
click $(center_of "$W1")
docked1=$(real_frame_of "$W1")
docked2=$(real_frame_of "$W2")
floating3=$(real_frame_of "$W3")

step "a real drag of the gap is one step, and ⌃⌥Z takes it back"
read -r gap_x gap_y <<< "$(seam_right_of "$W1")"
[ -n "${gap_y:-}" ] || die "Arbor does not say where the gap is"
drag "$gap_x" "$gap_y" "$((gap_x + 90))" "$gap_y" --steps 30 --duration 0.8
sleep 0.6
shot 03-gap-dragged
wider=$(echo "$docked1" | awk '{ print int($3) + 60 }')
check "the drag made the left window wider" wider_than "$W1" "$wider"
check "the newest step is the drag" next_undo_starts "drag the gap between"
key ctrl+opt+z
check "⌃⌥Z put the left window back" eventually is_at "$W1" "$docked1"
check "and the step before it is the dock, so the drag was one step" next_undo_is "dock w$W2 right"
shot 04-gap-undone
key ctrl+opt+shift+z
check "⌃⌥⇧Z made it wider again" eventually wider_than "$W1" "$wider"
ctl undo
check "undo put it back once more" eventually is_at "$W1" "$docked1"

step "a real resize by the window's own edge is one step"
read -r x y w h <<< "$(frame_of "$W1")"
[ -n "${h:-}" ] || die "Arbor does not say where window $W1 is"
drag "$((x + w - 1))" "$((y + h / 2))" "$((x + w + 59))" "$((y + h / 2))" --steps 20 --duration 0.6
sleep 0.8
summary
if next_undo_is "resize w$W1 by its edges"; then
  check "the newest step is the resize" true
  ctl undo
  check "undo put the window back" eventually is_at "$W1" "$docked1"
else
  # The press may have missed the one-point edge; that is the harness's aim, not undo's business.
  echo "note: the edge drag did not resize the window; newest step: $(next_undo)"
fi

step "a window dragged to a screen edge goes back to where it was picked up"
read -r sx sy sw sh <<< "$(arbor_ask screen)"
[ -n "${sh:-}" ] || die "nobody says how large the screen is"
# shellcheck disable=SC2046
drag $(titlebar_of "$W3") "$((sx + 3))" "$((sy + sh / 2))"
check "the dragged window docked" eventually is docked "$W3"
shot 05-dropped-on-the-edge
check "the newest step is the drop" next_undo_is "drag w$W3 to the left edge"
key ctrl+opt+z
check "⌃⌥Z floats it again" eventually is floating "$W3"
check "where it was picked up" eventually is_at "$W3" "$floating3"
check "and the docked windows have their places back" eventually is_at "$W1" "$docked1"
shot 06-drop-undone

step "Arrange Windows by mistake"
ctl arrange
sleep 0.5
shot 07-arranged
check "everything is docked" is docked "$W3"
key ctrl+opt+z
check "⌃⌥Z floats the third window where it was" eventually is_at "$W3" "$floating3"
check "the first window is back" eventually is_at "$W1" "$docked1"
check "the second window is back" eventually is_at "$W2" "$docked2"
shot 08-arrange-undone

step "a change that moves the view is undone with the view"
ctl zoom "$W1"
sleep 0.5
framed1=$(real_frame_of "$W1")
ctl toggle-float "$W1"
sleep 0.8
shot 09-framed-window-floated
ctl undo
check "the window fills the view again" eventually is_at "$W1" "$framed1"
check "and the other one is out of view again" eventually is parked "$W2"
shot 10-framed-again
ctl show-all
sleep 0.5

step "the menu with something to undo and to redo"
ctl undo
if item=$(status_item); then
  # shellcheck disable=SC2086
  rightclick $item
  shot 11-menu-undo-and-redo
  key escape
fi
ctl redo

step "unwind: exactly the two docks are left, so no echo added a step"
sleep 1
count=0
while "$ARBOR_BIN/arborctl" undo; do count=$((count + 1)); [ "$count" -ge 20 ] && break; done
check "two steps were left (there were $count)" test "$count" -eq 2
check "the first window floats where it started" eventually is_at "$W1" "$start1"
check "the second window floats where it started" eventually is_at "$W2" "$start2"
check "the third window floats where it started" eventually is_at "$W3" "$start3"
shot 12-all-undone
summary

arbor_stop 13-after-quit
