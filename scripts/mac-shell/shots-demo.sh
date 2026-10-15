#!/bin/bash
# A tour of the real app on real windows, in pictures: the example for scripts built on lib.sh, and the
# check that the harness itself works. Run it with
#
#   scripts/mac-shell/run.sh scripts/mac-shell/shots-demo.sh
#
# First session: commands over the socket (dock, zoom, a tile, back), a real title-bar drag to the left
# screen edge with a picture while the button is held, real drags of a seam and of a window's edge, a
# real click on a tile.
# Second session, with the menu bar item and the shortcuts on: the menu, shortcuts, a drag to the right
# edge, a ⌃⌥-drag around a window, a double-click on a title bar.
# It also prints what scripts need to know about the Mac they run on.
ARBOR_SHORTCUTS=all  # it presses keys of the whole map, of which nine ship
source "$(dirname "$0")/lib.sh"
source "$(dirname "$0")/lib-gestures.sh"

step "the Mac"
echo "macOS $(sw_vers -productVersion) ($(sw_vers -buildVersion)) on $(uname -m), $(sysctl -n hw.ncpu) cores"
echo "session: $(launchctl managername 2>/dev/null || echo unknown); bash $BASH_VERSION; $(python3 --version 2>&1)"
swift --version 2>&1 | head -n 2
arbor_build
echo "displays (id x y w h pixel-width pixel-height scale):"
pointer displays
system_profiler SPDisplaysDataType 2>/dev/null | grep -E "Resolution|Chipset|Display Type|UI Looks" | sed 's/^ */  /'
echo "Accessibility for a child process: $(pointer ax-access)"
echo "Screen Recording for a child process: $(pointer screen-access)"
echo "pointer: $(pointer where)"
# Its drags dock at the left and right edges of the screen, which are Arbor's only with macOS's own tiling off (MacTiling.swift). It declines on a
# person's Mac, where the setting is theirs; with the tiling on there, those steps fail.
macos_tiling off
# On a person's Mac that is the list of the apps they have open, in output that gets pasted into pull requests.
if on_throwaway_mac; then
  echo "windows on screen before the session (id pid layer x y w h on owner):"
  pointer windows | awk '$8 == "on"' | head -n 30
fi

# The third window refuses to be smaller than 700×500, so a small slot turns it into a tile.
ARBOR_TEST_WINDOWS_ARGS="--min-size 3:700x500"
# On a large screen Arbor would make room for it instead (F61), and there would be no tile to show.
arbor_settings "{\"makeRoom\": false, $ARBOR_TILES_ON}"
step "session 1: four windows"
arbor_start 4
summary
shot 01-start

step "dock a window with a command"
ctl dock "$W1" left
shot 02-dock-left
summary

step "drag a window by its title bar to the left screen edge"
read -r sx sy sw sh <<< "$(arbor_ask screen)"
edge_x=$((sx + 3))
edge_y=$((sy + sh / 2))
# shellcheck disable=SC2046
drag $(titlebar_of "$W4") "$edge_x" "$edge_y" --no-release
echo "pointer: $(pointer where)"
shot 03-drag-held
echo "Arbor's own windows while the button is held (the drop preview is at level 3):"
overlays
check "a drop preview is on screen while the button is held" has_overlay 3
release "$edge_x" "$edge_y"
shot 04-drag-released
check "the dragged window is docked after the release" eventually is docked "$W4"
summary
echo "the window server has it at: $(real_frame_of "$W4")"
is docked "$W4" || ctl dock "$W4" left

step "drag the seam between the two docked windows 80 points to the right"
read -r _ _ width_before _ <<< "$(frame_of "$W4")"
read -r seam_x _ <<< "$(seam_right_of "$W4")"
# Near the foot of the seam. A floating window keeps the place it has (Q20), and on a small display the one of 700 by 500 lies over the middle of
# both docked windows: a press there is a press on it.
read -r _ seam_y <<< "$(arbor_point_on "$W4" "x" "y + h - 20")"
move "$seam_x" "$seam_y"
shot 05-seam-hover
drag "$seam_x" "$seam_y" "$((seam_x + 80))" "$seam_y"
shot 06-seam-dragged
read -r _ _ width_after _ <<< "$(frame_of "$W4")"
echo "the left window was $width_before wide and is now $width_after"
check "the seam drag made the left window about 80 points wider" test "$((width_after - width_before))" -ge 60

step "drag a docked window's own right edge 60 points to the right"
read -r x y w h <<< "$(frame_of "$W1")"
drag "$((x + w - 1))" "$((y + h - 20))" "$((x + w + 59))" "$((y + h - 20))" --no-release
shot 06b-edge-held
release
shot 06c-edge-released
read -r _ _ w_after _ <<< "$(frame_of "$W1")"
echo "the window was $w wide and is now $w_after"
check "the edge drag made the window about 60 points wider" test "$((w_after - w))" -ge 40
summary

step "dock below, and a window too big for its slot"
ctl dock "$W2" beside "$W1" bottom
shot 07-dock-below
ctl dock "$W3" beside "$W4" bottom
shot 08-dock-too-big
summary
# Not a check, so that this script's exit code speaks for the harness.
is tile "$W3" || echo "note: the camera jumped onto the window instead of leaving a tile in its slot"
ctl show-all
shot 09-tile
ctl ascii
check "the window that cannot shrink is a tile" is tile "$W3"

step "zoom and back"
ctl zoom "$W1"
shot 10-zoom
ctl back
shot 11-back

step "catch a camera move half way"
ctl zoom "$W2" &
shot_after 0.15 12-mid-zoom
wait $!
ctl back &
film 12-back 4
wait $!

step "click the tile"
if is tile "$W3"; then
  # shellcheck disable=SC2046
  click $(tile_of "$W3")
  shot 13-tile-clicked
  summary
  check "the click on the tile framed its window" eventually is on_screen "$W3"
  ctl show-all
fi

step "the Desktop, then quit"
ctl desktop
shot 14-desktop
arbor_stop 15-after-quit

step "session 2: the menu bar item and the shortcuts, macOS's own edge tiling off"
macos_tiling off # declines on a person's Mac: it is their setting, not the session's
ARBOR_TEST_WINDOWS_ARGS=""
# The gestures for the ⌃⌥ rectangle further down.
arbor_settings "{\"gap\": 24, $ARBOR_GESTURES_ON}"
arbor_start 2 ARBOR_NO_STATUS_ITEM=0 ARBOR_NO_HOTKEYS=0
if on_throwaway_mac; then
  echo "menu bar items, as the window server sees them (id pid level x y w h on owner):"
  pointer windows | awk '$3 == 25'
fi
# So that the Escape below goes to the session: an open menu does not change which app is in front.
# shellcheck disable=SC2046
click $(center_of "$W2")
shot 20-menu-bar
if item=$(status_item); then
  echo "Arbor's menu bar item is at $item"
  # shellcheck disable=SC2086
  rightclick $item
  shot 21-menu-open
  key escape
else
  check "Arbor's menu bar item can be found" false
fi

# Presses a shortcut and checks that Arbor ran a command because of it: with ARBOR_DEBUG the log has a
# line for every command, whether or not it succeeded.
shortcut() {
  local mark
  mark=$(wc -l < "$ARBOR_HOME/arbor.log")
  key "$@"
  sleep 0.5
  tail -n "+$((mark + 1))" "$ARBOR_HOME/arbor.log" | cut -c 26-
  check "$* made Arbor run a command" test "$(wc -l < "$ARBOR_HOME/arbor.log")" -gt "$mark"
}

step "shortcuts: click a window to focus it, then ⌃⌥⌘← and ⌃⌥Space"
# Its lower left corner: the second window covers the rest.
# shellcheck disable=SC2046
click $(arbor_point $(frame_of "$W1") "x + 20" "y + h - 20")
check "the click focused the window" eventually is focused "$W1"
shortcut ctrl+opt+cmd+left
shot 23-shortcut-dock-left
check "⌃⌥⌘← docked the focused window" eventually is docked "$W1"
shortcut ctrl+opt+space
summary

step "drag the other window to the right edge, this time without macOS's tiling"
# shellcheck disable=SC2046
drag $(titlebar_of "$W2") "$((sx + sw - 3))" "$edge_y" --no-release
shot 24-drag-right-held
release
shot 25-drag-right-released
check "the dragged window is docked after the release" eventually is docked "$W2"
summary

step "⌃⌥-drag a rectangle around the window on the right"
read -r x y w h <<< "$(frame_of "$W2")"
drag "$((x + 30))" "$((y + 60))" "$((x + w - 30))" "$((y + h - 40))" --mods ctrl+opt --no-release
shot 25b-rectangle-held
release --mods ctrl+opt
shot 25c-rectangle-released
check "the rectangle framed the window inside it" eventually is parked "$W1"
summary
ctl show-all

step "double-click a title bar"
before=$(real_frame_of "$W2")
# shellcheck disable=SC2046
dblclick $(titlebar_of "$W2")
shot 26-double-click
echo "before: $before, after: $(real_frame_of "$W2")"
summary

arbor_stop
ls -l "$ARBOR_OUT" | awk '{ print $5, $9 }'
