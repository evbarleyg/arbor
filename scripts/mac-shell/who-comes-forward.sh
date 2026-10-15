#!/bin/bash
# Who comes forward when the app in front quits, is hidden, or has its only window minimized or closed?
#
#   scripts/mac-shell/run.sh scripts/mac-shell/who-comes-forward-1-without.sh scripts/mac-shell/who-comes-forward-2-with.sh scripts/mac-shell/who-comes-forward-3-without.sh
#
# One playing to a Mac cannot tell Arbor from the Mac. A walk by somebody who does not know Arbor was played on four hosted Macs: on three (two without Arbor, one with
# the first build) macOS brought the app used before forward; on the fourth, with a later Arbor, the Finder came forward, five times of five, and Arbor had asked macOS for
# nothing. So the same short walk is played three times on ONE Mac: without Arbor, with it, without it again. What follows Arbor is Arbor's. What is there all three times, or
# none, is the Mac's. Lay the three beside each other with walk-diff.py --with … --without …, the two without Arbor too.
#
# Played so on 2026-10-15: quits and hides end alike all three times, so that was the Mac. The last two acts follow Arbor: after ⌘M on Calendar's only window Calendar stays in
# front without Arbor, and with it Terminal comes forward, because Arbor asks for it: wanted is that it stays, and that Arbor's trace holds no request for the keyboard.
source "$(dirname "${BASH_SOURCE[0]}")/lib-walk.sh"

# ⌘W on the only window of the app in front. The walk's words know an app by its first window, so it is forgotten, and nothing is asked of that app afterwards.
close_only() {
  local window name
  window=$(front_window)
  name=$(name_of_pid "$(front_pid)") && [ "$window" = "$(window_of "$name")" ] || { left_out "close_only: the window in front is not a first window of the cast's"; return; }
  walk_act open-close "close-only-$name" "presses ⌘W on the only window of $name"
  key cmd+w
  changed
  acted moves=docked leaves="$window"
  eval "W_$name="
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
