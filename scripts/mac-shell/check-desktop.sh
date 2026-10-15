#!/bin/bash
# Dark mode, wallpapers and Spaces on the Mac that runs Mac shell scripts: the proof that lib.sh's `appearance`,
# `wallpaper`, `space_add` and `space_go` work there, with pictures of Arbor in both appearances, and what F08
# promises about Spaces on real windows.
#
#   scripts/mac-shell/run.sh scripts/mac-shell/check-desktop.sh
source "$(dirname "$0")/lib.sh"
needs_throwaway_mac "switch to dark mode, replace the wallpaper, add a Space, and change Reduce Motion and edge tiling"
arbor_build
# Its drags dock at the left and right edges of the screen, which are Arbor's only with macOS's own tiling off (MacTiling.swift). It declines on a
# person's Mac, where the setting is theirs; with the tiling on there, those steps fail.
macos_tiling off

style() { defaults read -g AppleInterfaceStyle 2>/dev/null || echo Light; }
shows() { [ "$(basename "$(pointer wallpaper | head -n 1)")" = "$1" ]; }
on_space() { [ "$(spaces | awk 'NR == 1 { print $3 }')" = "$1" ]; }
# Every switch of Spaces is recorded as a trace of its own (docs/TRACES.md), which comes back in traces/: what macOS reports of the windows
# that go and come, in which order and how far apart. Nothing asks Arbor anything while one is recorded.
# recorded <name> <command…>
TRACES="$ARBOR_OUT/traces"
mkdir -p "$TRACES"
recorded() {
  local name=$1
  shift
  "$ARBOR_BIN/arborctl" trace on "$name" > /dev/null
  "$@"
  sleep 3
  "$ARBOR_BIN/arborctl" trace off > /dev/null
  cp "$ARBOR_HOME"/traces/*-"$name".jsonl "$TRACES/$name.jsonl" || echo "no trace $name"
}

# What Arbor draws itself, in one picture each: a tile and seams, the drop preview, the menu.
portraits() {
  shot "$1-1-tile"
  # shellcheck disable=SC2046
  drag $(titlebar_of "$W3") $(arbor_point $(screen_of 1) "x + w - 3" "y + h / 2") --no-release
  shot "$1-2-preview"
  # Dropped back on the Desktop, so that the next round starts from the same arrangement.
  # shellcheck disable=SC2046
  release $(arbor_point $(arbor_ask desktop) "x + w / 2" "y + 60")
  open_menu
  shot "$1-3-menu"
  key escape
}

step "as the Mac comes"
macos_reduce_motion
echo "appearance: $("$ARBOR_VDISPLAY" appearance), AppleInterfaceStyle: $(style)"
echo "wallpaper: $(pointer wallpaper)"
spaces

ARBOR_TEST_WINDOWS_ARGS="--min-size 2:700x500"
arbor_settings "{$ARBOR_TILES_ON}"
arbor_start 3 ARBOR_NO_STATUS_ITEM=0
ctl dock "$W1" left
ctl dock "$W2" beside "$W1" bottom
# Docking a window that becomes a tile throws the camera onto it (report of 2026-10-14, finding 2): let that
# happen, then look at everything again.
sleep 1
ctl show-all
summary
check "a tile, a docked window and the Desktop are in view" eval 'is tile "$W2" && is in_slot "$W1" && arbor_ask desktop'
portraits light

step "dark mode"
appearance dark
check "the system says dark" test "$(style)" = Dark
portraits dark

step "a wallpaper: a gradient under a grid, then one colour"
wallpaper gradient
check "the desktop shows the gradient" eventually shows wallpaper-gradient.png
portraits dark-gradient
appearance light
check "the system says light" test "$(style)" = Light
shot light-gradient
wallpaper "#2e7d32"
check "the desktop shows the colour" eventually shows wallpaper-2e7d32.png
shot light-green

step "Reduce Motion"
macos_reduce_motion off
check "an app launched now is told that motion is fine" test "$(pointer reduce-motion)" = false

step "Spaces: a second one, there and back, with a tile and seams on the first"
is docked "$W3" || ctl dock "$W3" right
summary
slots="$(arbor_ask slot "$W1") / $(arbor_ask slot "$W3")"
recorded space-added space_add
spaces
check "the main display has two Spaces" test "$(spaces | awk 'NR == 1 { print $2 }')" = 2
recorded space-to-the-second space_go right
check "⌃→ shows the second Space" on_space 2
shot spaces-1-second
summary
recorded space-back-to-the-first space_go left
check "⌃← shows the first Space again" on_space 1
shot spaces-2-first-again
summary
check "both docked windows are back in their slots" eval 'eventually is in_slot "$W1" && eventually is in_slot "$W3"'
check "and the slots are the ones they had" test "$slots" = "$(arbor_ask slot "$W1") / $(arbor_ask slot "$W3")"

step "Spaces: there and back with one window framed"
ctl zoom "$W1"
check "the window fills the screen" eventually fills "$W1"
check "its neighbour is out of view" eventually out_of_view "$W3"
space_go right
check "⌃→ shows the second Space" on_space 2
space_go left
check "⌃← shows the first Space again" on_space 1
check "the window is still framed" eventually fills "$W1"
check "and stays so" stays fills "$W1"
check "its neighbour is still out of view" out_of_view "$W3"
ctl show-all
check "with everything in view both are in the slots they had" eval 'eventually is in_slot "$W1" && eventually is in_slot "$W3"'

step "Spaces: carry a docked window to the second Space, as a person does: hold its title bar and press ⌃→"
ctl float "$W2"
read -r x y <<< "$(titlebar_of "$W3")"
carry() {
  drag "$x" "$y" "$((x - 40))" "$((y + 40))" --no-release
  space_go right
  release
}
recorded space-window-carried carry
check "the second Space shows" on_space 2
shot spaces-3-carried
summary
echo "the window server has the carried window at $(real_frame_of "$W3")"
recorded space-left-without-the-window space_go left
shot spaces-4-without-it
summary
check "the window that stayed is in its slot" eventually is in_slot "$W1"
recorded space-right-to-the-window space_go right
shot spaces-5-with-it
summary
space_go left

step "Mission Control with a tile on the screen"
ctl dock "$W2" beside "$W1" bottom
sleep 1
ctl show-all
mission_control() {
  open -a "Mission Control"
  sleep 1.5
  shot mission-control
  key escape
  sleep 1
}
recorded mission-control mission_control
grep -i -E "space|display" "$ARBOR_HOME/arbor.log" | cut -c 26- | uniq -c | tail -n 20

arbor_stop after-quit
