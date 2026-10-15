#!/bin/bash
# Who comes forward when a window that Arbor arranges goes by its person's own act? who-comes-forward.sh over again, with two windows docked.
#
#   scripts/mac-shell/run.sh scripts/mac-shell/who-comes-forward-docked-1-without.sh scripts/mac-shell/who-comes-forward-docked-2-with.sh scripts/mac-shell/who-comes-forward-docked-3-without.sh
#
# ⌘M, ⌘H and ⌘W on a docked window that is its app's only one, ⌘W on a framed one, a click on the wallpaper: without Arbor, with it, without it again on ONE Mac. Without
# Arbor its own keys are left out and the rest is played. Wanted: the app in front is the same all three times; Arbor asks for the keyboard only at a key of its own; and it sets
# no frame but the docked windows', the neighbour's closing up, and those of the view that was asked for.
#
# Played on 2026-10-15, macOS 26.6.2: so it was. At the dockings only the two docked windows were set a frame. At ⌘M and at ⌘H the neighbour closed up in one call, to the frames
# the stand-ins had foretold to the point. Framing a window put the other eight out of view, and ⌘W on it brought them back, one call each, each to its own frame. The wallpaper and the last
# ⌘W: no call at all. Read the trace by its own events: `recorded` is to the second only, and the files are there twice.
#
# AN APP REMEMBERS THE FRAME ITS WINDOW HAD WHEN IT WAS CLOSED, Arbor's too: that day the third playing found Notes as large as the screen and no bare spot of wallpaper. So what ⌘W
# closed is opened again at the end of each playing and given the frame it had at the beginning (put_back: not yet played).
source "$(dirname "${BASH_SOURCE[0]}")/lib-walk.sh"

# ⌘W on the only window of the app in front. The walk's words know an app by its first window, so it is forgotten, and nothing is asked of that app afterwards.
# close_only any: the window is framed. Its view ends with it, and whoever it had put out of view comes back.
close_only() {
  local window name
  window=$(front_window)
  [ -n "$window" ] && name=$(name_of_pid "$(front_pid)") && [ "$window" = "$(window_of "$name")" ] || { left_out "close_only: the window in front is not a first window of the cast's"; return; }
  [ "$(app_windows "$(pid_of "$name")" | wc -w)" -eq 1 ] || { left_out "close_only: $name has not just the one window"; return; }
  walk_act open-close "close-only-$name" "presses ⌘W on the only window of $name"
  key cmd+w
  # An app does not obey every time.
  if must eventually closed "$window" "$(pid_of "$name")"; then eval "W_$name="; CLOSED="$CLOSED $name"; fi
  changed
  acted moves="${1:-docked}" leaves="$window"
}
closed() {
  local list
  # An app that does not answer has not said that the window went. One that is gone has taken it along.
  list=$(apptool windows "$2" 2> /dev/null) || { ! kill -0 "$2" 2> /dev/null; return; }
  ! echo "$list" | awk -v id="$1" '$1 == id' | grep -q .
}

# Opens the window of an app again that close_only closed, and gives it the frame it had when the walk began. No act: Arbor has quit, and nothing is judged any more. A click on its icon in
# the Dock is the way that is known to bring a window up. macOS may have ended an app that was left without one: app_open starts it again, and it is quit with the others. What went wrong is
# said: the next playing is the one that suffers.
put_back() {
  local frame pid window=""
  eval "frame=\${FIRST_$1:-}"
  [ -n "$frame" ] || { echo "put_back $1: no frame was noted as the walk began"; return 0; }
  pid=$(pid_of "$1")
  if kill -0 "$pid" 2> /dev/null; then
    dock_click "$(bundle_of "$1")" > /dev/null || echo "put_back $1: the Dock shows no icon of it"
    if app_await_window "$pid" "" 8; then window=$NEW_WINDOW; fi
  elif app_open "$(bundle_of "$1")"; then
    window=$APP_WINDOW
  fi
  [ -n "$window" ] || { echo "put_back $1: NO WINDOW CAME: its next one opens where ⌘W closed the last"; return 0; }
  # shellcheck disable=SC2086
  echo "put_back $1: asked for $frame, took $(apptool set-frame "$window" $frame 2>&1)"
  sleep 0.5
}

CLOSED=""
walk_begin stock laptop defaults who-comes-forward-docked
for name in $WALK_CAST; do eval "FIRST_$name=\$(resting_frame_of \"\$(window_of \"$name\")\")"; done
switch_dock safari
dock_key left
switch_dock notes
dock_key right
switch_dock calendar
switch_dock notes
minimize
restore notes
switch_dock textedit
switch_dock safari
hide
unhide safari
switch_dock preview
wallpaper_click
switch_dock calendar
switch_dock notes
view frame
close_only any
switch_dock textedit
switch_dock safari
close_only
walk_end
verdict=$?
for name in $CLOSED; do put_back "$name"; done
exit "$verdict"
