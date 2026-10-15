#!/bin/bash
# The fill's size is Arbor's and never the window's own, whatever macOS does between (collab/QUESTIONS.md, Q29; board 0.16).
# A real app, never docked, the real key and the real pointer: the key fills the screen with it; a double-click on its title bar, and macOS
# zooms it; a second one, and macOS gives it back what it had before its zoom, which is the fill's frame. Then the key, and in a second
# round Quit: its own frame, to the point.
# What only a Mac can tell: whether macOS does give the fill's frame back at the second double-click. The frames after every step are printed.
#
#   scripts/mac-shell/run.sh scripts/mac-shell/check-fill-given-back.sh
source "$(dirname "$0")/lib-apps.sh"

is_at() { arbor_close "$(real_frame_of "$1")" "$2"; }
# on_its_title_bar <id>: a real double-click where a hand would take hold of it, and the pointer off it again
on_its_title_bar() {
  local x y role
  read -r x y role <<< "$(apptool grab "$1" 2>/dev/null)"
  [ -n "${x:-}" ] || return 1
  dblclick "$x" "$y" || return 1
  move "$x" "$((y + 160))"
}

apps_build
apps_scratch
apps_watchdog 300
echo "AppleActionOnDoubleClick: $(defaults read -g AppleActionOnDoubleClick 2>/dev/null || echo "not set")"
app_open com.apple.TextEdit "$APPS_SCRATCH/oak.txt" || die "TextEdit did not open"
app_dismiss "$APP_PID"
WINDOW=$APP_WINDOW

# filled_zoomed_and_back <round>: sets OWN and FILLED
filled_zoomed_and_back() {
  OWN=$(real_frame_of "$WINDOW")
  apptool activate "$APP_PID"
  sleep 0.5
  check "a real click gives it the keyboard" app_focus "$WINDOW"
  check "the real key runs the command" pressed ctrl+opt+return zoom
  sleep 1
  FILLED=$(real_frame_of "$WINDOW")
  echo "FRAMES $1 own: $OWN filled: $FILLED"
  check "it fills the view" fills "$WINDOW"
  check "a real double-click on its title bar" on_its_title_bar "$WINDOW"
  sleep 2
  echo "FRAMES $1 after the first double-click: $(real_frame_of "$WINDOW")"
  check "macOS has given it another frame" not is_at "$WINDOW" "$FILLED"
  snap "$1-1-zoomed-by-macos"
  check "a second real double-click" on_its_title_bar "$WINDOW"
  sleep 2
  echo "FRAMES $1 after the second double-click: $(real_frame_of "$WINDOW")"
  check "macOS has given it back what it had before: the fill's frame" is_at "$WINDOW" "$FILLED"
  check "which is not its own: Arbor knows that it fills" is filled "$WINDOW"
  snap "$1-2-given-back"
}

arbor_start_apps "$APP_PID" ARBOR_NO_HOTKEYS=0
sleep 1
claim "filled, zoomed by macOS and given back: the key gives the window its own frame"
filled_zoomed_and_back key
check "the real key runs the command" pressed ctrl+opt+return zoom
check "it is exactly where and as large as it was" eventually is_at "$WINDOW" "$OWN"
echo "FRAMES key after the key: $(real_frame_of "$WINDOW")"
check "Arbor knows that it no longer fills" not is filled "$WINDOW"
snap key-3-back
# Whatever came of that, the second round begins where the first did.
apptool set-frame "$WINDOW" $OWN > /dev/null
sleep 1

claim "filled, zoomed by macOS and given back: Quit gives the window its own frame"
filled_zoomed_and_back quit
arbor_stop
echo "FRAMES quit after Quit: $(real_frame_of "$WINDOW")"
check "it is exactly where and as large as it was" is_at "$WINDOW" "$OWN"
snap quit-3-after-quit
