#!/bin/bash
# Who comes forward when the app in front quits, is hidden, or has its only window minimized?
#
# A walk by somebody who does not know Arbor, played on four hosted Macs: on three (two without Arbor, one with the first build) macOS brought the app used before forward. On the
# fourth, with the trunk's Arbor, the Finder came forward, five times of five, and Arbor had asked macOS for nothing. One playing to a Mac: was it Arbor, or that Mac?
# So here the same short walk is played three times on ONE Mac: without Arbor, with it, without it again (who-comes-forward-1-without.sh, -2-with.sh, -3-without.sh).
# What follows Arbor is Arbor's. What is there all three times is the Mac's.
source "$(dirname "${BASH_SOURCE[0]}")/lib-walk.sh"
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
walk_end
