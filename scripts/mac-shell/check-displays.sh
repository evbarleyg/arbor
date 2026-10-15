#!/bin/bash
# Arbor on two displays, on real macOS: the second one is virtual (lib.sh's display_add, vdisplay.m).
#
#   scripts/mac-shell/run.sh scripts/mac-shell/check-displays.sh
#
# Plugs a display in to the right of the main one, arranges windows on both, and checks what F08 and the
# multi-display parts of F01 promise: a camera per display, real drags across, parked windows that show on
# neither display, unplugging (nothing lost) and replugging (the arrangement returns). Then the same geometry
# with the display to the left (negative x), above (negative y) and low on the right, where it covers the
# corner the main display parks in; and last a Retina display. Pictures: <name>.png is the main display,
# <name>-d2.png the second, <name>-all.png both as they are arranged.
#
# On GitHub's Macs plugging the display in also switches the main one from 1024×768 to 1920×1080, and
# unplugging switches it back, so every plug is a change of resolution too.
source "$(dirname "$0")/lib.sh"
needs_throwaway_mac "plug a virtual display in and out and rearrange the displays, at which macOS moves every window"

WIDTH=1280
HEIGHT=800

arbor_build
echo "displays (id uuid x y w h scale main vendor model serial):"
"$ARBOR_VDISPLAY" list

# Every change of displays is recorded as a trace of its own (docs/TRACES.md), which comes back in traces/: in which order, and how far apart,
# macOS reports displays and windows. Nothing asks Arbor anything while one is recorded, so that it holds what happened and not
# the script's questions: where to point is worked out before, and the checks come after.
# recorded <name> <command…>
TRACES="$ARBOR_OUT/traces"
mkdir -p "$TRACES"
recorded() {
  local name=$1
  shift
  "$ARBOR_BIN/arborctl" trace on "$name" > /dev/null
  "$@"
  # Echoes, put-backs and saves arrive up to a second after the last thing that happened; windows that macOS moves along, later still.
  sleep 3
  "$ARBOR_BIN/arborctl" trace off > /dev/null
  cp "$ARBOR_HOME"/traces/*-"$name".jsonl "$TRACES/$name.jsonl" || echo "no trace $name"
}

# MARK: What every arrangement is checked for

arranges() { [ "$(arbor_ask displays)" = "$1" ]; }
docked_on() { is docked "$2" && is "display$1" "$2"; }
hidden() { [ "$(pointer visible "$1" | tr -d .)" -le 3 ]; }
lands_at() { arbor_close "$1" "$(real_frame_of "$2")"; }

# The middle of display n's visible frame.
middle_of() {
  # shellcheck disable=SC2046
  arbor_point $(screen_of "$1") "x + w / 2" "y + h / 2"
}

# A point three points inside display 2's edge that faces away from the main display.
far_edge() {
  case "$1" in
    # shellcheck disable=SC2046
    left) arbor_point $(screen_of 2) "x + 3" "y + h / 2" ;;
    # shellcheck disable=SC2046
    *) arbor_point $(screen_of 2) "x + w - 3" "y + h / 2" ;;
  esac
}

# Arbor and macOS agree about the displays. Every docked window in view sits where the layout says, by the window
# server's account; every parked one shows on no display, its own or the neighbour; and Arbor's own
# windows (seams, tiles, the preview) lie on one display or the other, not across or beyond.
check_geometry() {
  local id rect first second
  summary
  echo "macOS: $("$ARBOR_VDISPLAY" list | awk '{ print $3, $4, $5, $6, $8 }' | tr '\n' ';')"
  first=$(display_frame_of 1)
  second=$(display_frame_of 2)
  check "$1: Arbor's frame for the second display is macOS's" \
    arbor_close "$second" "$("$ARBOR_VDISPLAY" list | awk -v id="$DISPLAY2_ID" '$1 == id { print $3, $4, $5, $6 }')"
  for id in $ARBOR_WINDOW_IDS; do
    if is parked "$id"; then
      check "$1: parked window $id shows on no display (it is at $(real_frame_of "$id"))" eventually hidden "$id"
    elif is docked "$id"; then
      check "$1: window $id is in its slot ($(arbor_ask slot "$id"))" eventually is in_slot "$id"
    fi
  done
  overlays | awk '$8 == "on" { print $4, $5, $6, $7 }' | while read -r rect; do
    inside "$rect" "$first" || inside "$rect" "$second" || echo "stray overlay at $rect"
  done > "$ARBOR_SESSION_DIR/strays"
  cat "$ARBOR_SESSION_DIR/strays"
  check "$1: every overlay lies within a display" test ! -s "$ARBOR_SESSION_DIR/strays"
}

# Each display has a camera of its own, and what one parks the other does not show.
# Expects W1 and W2 docked on the main display, W5 and W4 on the second.
check_cameras() {
  local before

  step "$1: zoom on the second display leaves the main one alone"
  before="$(real_frame_of "$W1") $(real_frame_of "$W2")"
  ctl zoom "$W5"
  shot "$1-2-zoom-second"
  check "$1: the zoomed window fills the second display" eventually is in_slot "$W5"
  check "$1: the main display's windows did not move" test "$before" = "$(real_frame_of "$W1") $(real_frame_of "$W2")"
  check "$1: parked window $W4 shows on no display (it is at $(real_frame_of "$W4"))" eventually hidden "$W4"
  # Camera commands without a window act on the display under the pointer.
  # shellcheck disable=SC2046
  move $(middle_of 2)
  ctl back
  check "$1: back on the second display brings its window back" eventually is in_slot "$W4"

  step "$1: zoom on the main display, with a neighbour to park beside"
  before="$(real_frame_of "$W4") $(real_frame_of "$W5")"
  ctl zoom "$W1"
  shot "$1-3-zoom-main"
  check "$1: the second display's windows did not move" test "$before" = "$(real_frame_of "$W4") $(real_frame_of "$W5")"
  check "$1: parked window $W2 shows on no display (it is at $(real_frame_of "$W2"))" eventually hidden "$W2"
  # shellcheck disable=SC2046
  move $(middle_of 1)
  ctl back
  check "$1: back on the main display brings its window back" eventually is in_slot "$W2"
}

# A docked window is dragged by its title bar out of its slot onto the other display, and back to the far edge.
check_drags() {
  local preview

  step "$1: drag a window from the second display to the main one and back to the far edge"
  # shellcheck disable=SC2046
  drag $(titlebar_of "$W4") $(middle_of 1)
  check "$1: dropped on the main display it floats there" eventually is display1 "$W4"
  summary
  shot "$1-4-dragged-to-main"
  # shellcheck disable=SC2046
  drag $(titlebar_of "$W4") $(far_edge "$1") --no-release
  shot "$1-5-preview"
  preview=$(overlays | awk '$3 == 3 && $8 == "on" { print $4, $5, $6, $7 }')
  echo "the preview is at: ${preview:-nowhere}"
  check "$1: the drop preview lies on the second display" inside "$preview" "$(display_frame_of 2)"
  release
  check "$1: released there it docks on the second display" eventually docked_on 2 "$W4"
  check "$1: and lands where the preview was" eventually lands_at "$preview" "$W4"
}

check_arrangement() {
  step "$1: where everything is"
  panorama "$1-all"
  shot "$1-1-arranged"
  check_geometry "$1"
  check_cameras "$1"
  check_drags "$1"
  step "$1: where everything is afterwards"
  shot "$1-6-afterwards"
  check_geometry "$1"
}

# MARK: One display, then two

# The third window refuses to be smaller than 700×500, so a small slot turns it into a tile.
ARBOR_TEST_WINDOWS_ARGS="--min-size 3:700x500"
step "one display: five windows, one docked"
arbor_start 5
ctl dock "$W1" left
summary

step "plug a display in on the right"
recorded display-plugged-in display_add $WIDTH $HEIGHT right
check "Arbor arranges two displays" eventually arranges 2
check "Arbor knows the new display by its UUID" test "$(arbor_ask display-id 2)" = "$DISPLAY2_UUID"
first_uuid=$DISPLAY2_UUID
summary
spaces
shot plugged-in

step "drag three windows across: one dropped in the middle, one at the far edge, one to become a tile"
# The windows open in a cascade, so the last one is in front and its title bar is free.
# shellcheck disable=SC2046
recorded drag-to-the-second-display drag $(titlebar_of "$W5") $(middle_of 2)
check "dropped on the second display it belongs to the second display" eventually is display2 "$W5"
ctl dock "$W5" left
check "docked with a command it stays on the second display" docked_on 2 "$W5"
# shellcheck disable=SC2046
recorded drag-to-the-far-edge drag $(titlebar_of "$W4") $(far_edge right)
check "dropped at the second display's right edge it docks there" eventually docked_on 2 "$W4"
# shellcheck disable=SC2046
drag $(titlebar_of "$W3") $(middle_of 2)
check "the third window went across too" eventually is display2 "$W3"
ctl dock "$W3" beside "$W5" bottom
# Docking a window that becomes a tile throws the camera onto it (report of 2026-10-14, finding 2): let that
# happen, then look at everything again.
sleep 1
# shellcheck disable=SC2046
move $(middle_of 2)
ctl show-all
check "the window that cannot shrink is a tile on the second display" inside "$(arbor_ask tile "$W3")" "$(display_frame_of 2)"
ctl dock "$W2" right

check_arrangement right

step "unplug the display"
arranged="$(arbor_ask slot "$W4") / $(arbor_ask slot "$W5") / $(arbor_ask tile "$W3")"
recorded display-unplugged display_remove
check "Arbor arranges one display" eventually arranges 1
sleep 1
summary
shot unplugged
for id in $ARBOR_WINDOW_IDS; do
  check "unplugged: window $id is on the screen that is left" eventually is on_screen "$id"
  check "unplugged: window $id belongs to the main display" is display1 "$id"
done
check "unplugged: window $W1 is in its slot" eventually is in_slot "$W1"
check "unplugged: window $W2 is in its slot" eventually is in_slot "$W2"

step "plug it in again"
recorded display-plugged-in-again display_add $WIDTH $HEIGHT right
echo "the UUID was $first_uuid and is $DISPLAY2_UUID"
check "a virtual display with the same serial number keeps its UUID" test "$first_uuid" = "$DISPLAY2_UUID"
check "Arbor arranges two displays again" eventually arranges 2
sleep 1
shot plugged-in-again
for id in "$W3" "$W4" "$W5"; do
  check "replugged: window $id is docked on the second display again" eventually docked_on 2 "$id"
done
echo "arranged before: $arranged"
echo "arranged now:    $(arbor_ask slot "$W4") / $(arbor_ask slot "$W5") / $(arbor_ask tile "$W3")"
check "replugged: the arrangement is the one that went away" \
  test "$arranged" = "$(arbor_ask slot "$W4") / $(arbor_ask slot "$W5") / $(arbor_ask tile "$W3")"
check_geometry replugged

step "move the display to the left of the main one (negative x)"
recorded display-moved-left display_move left
check_arrangement left

step "move the display above the main one (negative y)"
recorded display-moved-above display_move above
check_arrangement above

step "move the display low on the right, over the corner where the main display parks"
recorded display-moved-low-right display_move right 400
panorama right-low-all
check_geometry right-low
check_cameras right-low

step "swap it for a Retina display"
recorded display-unplugged-arranged display_remove
check "Arbor arranges one display" eventually arranges 1
ARBOR_DISPLAY_SERIAL=2
ARBOR_DISPLAY_ARGS=--hidpi
recorded display-retina-plugged-in display_add $WIDTH $HEIGHT right
"$ARBOR_VDISPLAY" list
check "another serial number is another display" test "$first_uuid" != "$DISPLAY2_UUID"
check "Arbor arranges two displays" eventually arranges 2
sleep 1
# Docked first, which brings it to the front: the windows that came over from the unplugged display lie in a heap.
ctl dock "$W5" left
# shellcheck disable=SC2046
drag $(titlebar_of "$W5") $(far_edge left) --no-release
shot retina-1-preview
release
check "retina: dropped at the left edge the window docks there" eventually docked_on 2 "$W5"
shot retina-2-docked
check_geometry retina

step "quit with two displays, then unplug"
grep -i "display" "$ARBOR_HOME/arbor.log" | cut -c 26- | uniq -c | tail -n 30
arbor_stop after-quit
display_remove
