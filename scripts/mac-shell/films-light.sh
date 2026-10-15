#!/bin/bash
# How "at once" looks: Arbor without motion, without the ring and with one icon, filmed act by act; and macOS's own tiling of the same windows.
#
#   scripts/mac-shell/rehearse.sh scripts/mac-shell/films-light.sh    on Linux, first, for nothing
#   scripts/mac-shell/run.sh scripts/mac-shell/films-light.sh         about six minutes on a hosted Mac
#   scripts/polish/judge.py acts .mac-shell/films-light-<run id>      anywhere, afterwards
#
# While windows move Arbor used to cover the display with a stage. Without one the real windows are seen going to their places: each is another app's, is
# asked for its place and its size one after the other, and obeys when it gets round to it. What only a Mac can answer: how long one act takes
# from the first change on the display to the last, and whether any window is ever seen at a place or size that is neither its old nor its new one.
# The bar is macOS alone: its own tiling, chosen from the Window menu, of the same windows, with Arbor not running.
#
# The settings are written out, so that the films mean the same whatever ships. The keys are the whole map's: it is the acts that are filmed, not the keys.
ARBOR_TIME_LIMIT=700
source "$(dirname "$0")/lib-film.sh"
needs_throwaway_mac "film the whole display, and change Reduce Motion, the wallpaper and the display's size"

LIGHT='{"animationDuration": 0, "focusRing": false, "menuBarControls": false}'
FACE="ARBOR_NO_HOTKEYS=0 ARBOR_NO_STATUS_ITEM=0"

press() {
  # shellcheck disable=SC2046
  click $(titlebar_of "$1")
  sleep 0.6
}

# act <name> "<what the person does>" <key>: one key, one film.
act() {
  scene "$1" instant "$2"
  key "$3"
  scene_end 1.6
}

# Floating windows that lie beside one another.
spread() {
  tell 4 "move $W4 40 70 300 200"
  tell 1 "move $W1 400 70 300 190"
  tell 2 "move $W2 400 285 300 190"
  tell 3 "move $W3 400 500 300 190"
  sleep 1.5
}

# Two columns of two: W4 over W2 on the left, W3 over W1 on the right.
arrange() {
  ctl float-all
  sleep 1
  ctl dock "$W4" left
  ctl dock "$W3" right
  ctl dock "$W2" beside "$W4" bottom
  ctl dock "$W1" beside "$W3" bottom
  sleep 1.5
}

# macos <name> <n> "<what the person does>" <item> [<item of its submenu>]: macOS's own tiling of the nth window, from its app's Window menu. System Events presses the item,
# so no key and no button says when: the film's own mark does, to a few hundredths of a second.
macos() {
  local name=$1 app item=$4 inner=${5:-} what
  app=$(cast_name "$2")
  eval "press \"\$W$2\""
  what="menu item \"$item\" of menu \"Window\" of menu bar 1"
  [ -z "$inner" ] || what="menu item \"$inner\" of menu 1 of $what"
  scene "$name" bare "$3"
  if [ -n "${ARBOR_REHEARSAL:-}" ]; then
    echo "> System Events: $app: $item $inner (not rehearsed)"
  else
    arbor_within 10 osascript -e "tell application \"System Events\" to tell process \"$app\" to click $what" > /dev/null \
      || echo "macos $name: System Events could not press $item $inner"
  fi
  scene_end 1.6
}

film_build
cast_build
step "the Mac"
echo "Screen Recording for a child process: $(pointer screen-access)"
pointer displays
macos_reduce_motion off
glass on
macos_tiling
camera_start || die "no camera"
sampler_start
ARBOR_TEST_WINDOWS_ARGS="--regular"
# The fake Mac has no menus of macOS's to fill.
[ -n "${ARBOR_REHEARSAL:-}" ] || ARBOR_TEST_WINDOWS_ARGS="--regular --window-menu"
wallpaper "#000000"

step "1. the camera's own square: what this camera on this Mac is worth"
metronome good

step "2. four windows, each another app's"
arbor_settings "$LIGHT"
cast_start 4 $FACE
sleep 3
spread
press "$W4"
act light-dock-first "docks a floating window at the left (⌃⌥←): the first dock" ctrl+opt+left
press "$W3"
act light-dock-second "docks a second window at the right (⌃⌥→)" ctrl+opt+right
press "$W2"
act light-dock-third "docks a third window at the right (⌃⌥→)" ctrl+opt+right
press "$W1"
act light-dock-fourth "docks a fourth window at the left (⌃⌥←)" ctrl+opt+left
summary

arrange
press "$W4"
act light-fill "fills the screen with a docked window (⌃⌥↩)" ctrl+opt+return
act light-everything "shows everything again (⌃⌥Space)" ctrl+opt+space
key ctrl+opt+return
sleep 1.3
act light-back "goes back (⌃⌥[)" "ctrl+opt+["
press "$W1"
act light-float "floats a docked window (⌃⌥F)" ctrl+opt+f
act light-undo "undoes that (⌃⌥Z)" ctrl+opt+z
act light-pause "pauses Arbor (⌃⌥⎋): every window gets its own size back" ctrl+opt+escape
act light-resume "resumes (⌃⌥⎋)" ctrl+opt+escape

ctl float-all
sleep 1
spread
press "$W4"
scene light-arrange instant "chooses Arrange Windows: four floating windows at once"
ctl arrange
scene_end 1.6
summary

arrange
scene light-close instant "closes a docked window"
tell 1 "close $W1"
scene_end 1.6
ARBOR_WINDOW_IDS="$W2 $W3 $W4"

trace_ends
scene light-quit instant "quits Arbor: every window gets its own size back"
ctl quit
scene_end 1.6

step "3. macOS alone, the same windows: Arbor is not running"
if [ -z "${ARBOR_REHEARSAL:-}" ]; then
  echo "the Window menu of $(cast_name 4):"
  arbor_within 10 osascript -e "tell application \"System Events\" to tell process \"$(cast_name 4)\" to get name of menu items of menu \"Window\" of menu bar 1"
  arbor_within 10 osascript -e "tell application \"System Events\" to tell process \"$(cast_name 4)\" to get name of menu items of menu 1 of menu item \"Move & Resize\" of menu \"Window\" of menu bar 1"
fi
tell 4 "move $W4 40 70 300 200"
tell 2 "move $W2 400 285 300 190"
tell 3 "move $W3 400 500 300 190"
sleep 1.5
macos macos-left 4 "chooses Window ▸ Move & Resize ▸ Left" "Move & Resize" "Left"
macos macos-right 3 "chooses Window ▸ Move & Resize ▸ Right" "Move & Resize" "Right"
macos macos-fill 4 "chooses Window ▸ Fill" "Fill"
macos macos-previous 4 "chooses Window ▸ Move & Resize ▸ Return to Previous Size" "Move & Resize" "Return to Previous Size"
macos macos-left-and-right 4 "chooses Window ▸ Move & Resize ▸ Left & Right: two windows at once" "Move & Resize" "Left & Right"
macos macos-quarters 4 "chooses Window ▸ Move & Resize ▸ Quarters: several windows at once" "Move & Resize" "Quarters"
cast_stop

step "4. eight windows on a large display"
display_size 1920 1080
arbor_settings "$LIGHT"
cast_start 8 $FACE
sleep 3
press "$W8"
scene light-eight-arrange instant "chooses Arrange Windows: eight floating windows at once"
ctl arrange
scene_end 2
summary
press "$W8"
act light-eight-fill "fills the screen with one of eight (⌃⌥↩)" ctrl+opt+return
act light-eight-everything "shows everything again (⌃⌥Space)" ctrl+opt+space
cast_stop
display_size 1024 768

sampler_stop
camera_stop
