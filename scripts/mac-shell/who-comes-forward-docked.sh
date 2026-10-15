#!/bin/bash
# Who comes forward when a window that Arbor arranges goes by its person's own act? who-comes-forward.sh over again, with two windows docked.
#
#   scripts/mac-shell/run.sh scripts/mac-shell/who-comes-forward-docked-1-without.sh scripts/mac-shell/who-comes-forward-docked-2-with.sh scripts/mac-shell/who-comes-forward-docked-3-without.sh
#
# ⌘M, ⌘H and ⌘W on a docked window that is its app's only one, ⌘W on a framed one, a click on the wallpaper: without Arbor, with it, without it again on ONE Mac. Without
# Arbor its own keys are left out and the rest is played. Wanted: the app in front is the same all three times, and Arbor's trace holds no request for the keyboard, and no frame
# but the neighbours' closing up.
source "$(dirname "${BASH_SOURCE[0]}")/lib-walk.sh"

# ⌘W on the only window of the app in front. The walk's words know an app by its first window, so it is forgotten, and nothing is asked of that app afterwards.
close_only() {
  local window name
  window=$(front_window)
  [ -n "$window" ] && name=$(name_of_pid "$(front_pid)") && [ "$window" = "$(window_of "$name")" ] || { left_out "close_only: the window in front is not a first window of the cast's"; return; }
  [ "$(app_windows "$(pid_of "$name")" | wc -w)" -eq 1 ] || { left_out "close_only: $name has not just the one window"; return; }
  walk_act open-close "close-only-$name" "presses ⌘W on the only window of $name"
  key cmd+w
  # An app does not obey every time.
  if must eventually closed "$window" "$(pid_of "$name")"; then eval "W_$name="; fi
  changed
  acted moves=docked leaves="$window"
}
closed() {
  local list
  # An app that does not answer has not said that the window went. One that is gone has taken it along.
  list=$(apptool windows "$2" 2> /dev/null) || { ! kill -0 "$2" 2> /dev/null; return; }
  ! echo "$list" | awk -v id="$1" '$1 == id' | grep -q .
}

walk_begin stock laptop defaults who-comes-forward-docked
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
close_only
switch_dock textedit
switch_dock safari
close_only
walk_end
