#!/bin/bash
# Who comes forward when the app in front quits, is hidden, or has its only window minimized or closed?
#
#   scripts/mac-shell/run.sh scripts/mac-shell/who-comes-forward-1-without.sh scripts/mac-shell/who-comes-forward-2-with.sh scripts/mac-shell/who-comes-forward-3-without.sh
#
# One playing to a Mac cannot tell Arbor from the Mac. A walk by somebody who does not know Arbor was played on four hosted Macs: on three (two without Arbor, one with
# the first build) macOS brought the app used before forward; on the fourth, with a later Arbor, the Finder came forward after every quit and every hide, and Arbor had asked
# macOS for nothing then. So the same short walk is played three times on ONE Mac: without Arbor, with it, without it again. What follows Arbor is Arbor's. What is there all three times, or
# none, is the Mac's. Lay them beside each other: walk-diff.py --with <2> --without <1>, the same with <3>, and the two without Arbor as walk-diff.py <1> <3>.
#
# Played so on 2026-10-15: quits and hides end alike all three times, so that was the Mac. One act of the 25 follows Arbor: after ⌘M on Calendar's only window Calendar stays in
# front without Arbor, and with it Terminal comes forward, because Arbor asks for it: wanted is that it stays, and that Arbor's trace holds no request for the keyboard.
# Played again the same day on the change that lets macOS decide after a person's own act, with the acts since added: 35 acts, nothing differs between any two of the three, and
# Arbor's trace of the walk holds questions only.
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

walk_begin stock laptop defaults who-comes-forward
switch_dock safari
switch_dock mail
switch_dock preview
quit_app preview
reopen preview
switch_dock textedit
switch_dock calendar
hide
unhide calendar
switch_dock notes
switch_dock safari
quit_app safari
reopen safari
switch_dock settings
switch_dock textedit
quit_app textedit
reopen textedit
switch_dock preview
switch_dock finder
hide
unhide finder
switch_dock terminal
switch_dock calendar
minimize
restore calendar
# So far it is what was played on 2026-10-15, act for act. Since then: ⌘M in a second app, and ⌘W.
switch_dock safari
switch_dock notes
minimize
restore notes
switch_dock mail
switch_dock preview
close_only
switch_dock textedit
switch_dock calendar
close_only
walk_end
