#!/bin/bash
# An ordinary day: the rehearsal of the acceptance pass. Real apps, macOS at its default settings, Arbor as a person runs it,
# and every frame of every window written down meanwhile.
#
#   scripts/mac-shell/run.sh scripts/mac-shell/day.sh          on one of GitHub's Macs, from anywhere (`make day`): ten minutes
#
# A release is decided by half an hour on a person's ordinary Mac: no jolts, no lost or stuck window, nothing moved that they
# did not move. This plays such a day: the apps are open already when Arbor starts; windows are docked by key and by real
# drags; apps are switched with ⌘Tab, the Dock and the Window menu; ⌘H, ⌘M, ⌘W, ⌘N, ⌘Q; full screen; the view goes in and out;
# a click lands on the wallpaper; pause, Float All, Quit, and a second launch. macOS's own tiling and "click wallpaper to
# reveal desktop" stay as they come, which is on. Each step is one thing a person does and says what that may move
# (lib-day.sh, in the words of lib-walk.sh); jolts.py then reads the samples and says which step broke which rule.
#
# What comes back in .mac-shell/day-<run>/: day-report.md (the findings per rule, each with the step that shows it, then every
# step with what moved and how often), day-findings.json, samples.log, and for every step with a finding its picture
# <nnn>-<slug>.jpg and its story <nnn>-<slug>.story.log: what the screen showed, what macOS reported and what Arbor logged, in order.
#
# run.sh hands a script no arguments and no environment, so each way of playing the day is a script of three lines that sets a variable:
# DAY_WITHOUT_ARBOR=1 (day-control.sh) plays the same day without Arbor, leaving out the steps that are Arbor's own keys: what is found
# then is macOS's doing or an app's, and no fault of Arbor's when it shows up in the real day too.
# DAY_TILING=off (day-off.sh) plays it with macOS's own window management switched off: edges, menu bar, ⌥, the wallpaper click.
# DAY_REDUCE_MOTION=on (day-still.sh) leaves Reduce Motion on, as the runners come: then Arbor puts up no stage, and every move of every window shows.
# DAY_DISPLAY=desk plays it at 1920×1080 instead of a laptop's 1440×900 or the nearest on offer. DAY_KEEP_PICTURES=1 keeps every step's picture.
#
# Only on GitHub's Macs: it quits apps, closes windows, clicks in the Dock and on the wallpaper, and changes the display's size.
[ -z "${DAY_WITHOUT_ARBOR:-}" ] || WALK_WITHOUT_ARBOR=1
WALK_REDUCE_MOTION=${DAY_REDUCE_MOTION:-off}
source "$(dirname "${BASH_SOURCE[0]}")/lib-walk.sh"

walk_begin stock "${DAY_DISPLAY:-laptop}" "${DAY_TILING:-defaults}"
idle_act

chapter "Switching between apps, nothing docked yet"
for name in $WALK_CAST; do switch_dock "$name"; done
switch_cmdtab 1
switch_cmdtab 2

chapter "The first docks, by key"
switch_to finder;  dock_key left
switch_to safari;  dock_key right
switch_to textedit;  dock_key right

chapter "Docking by real drags"
switch_to terminal
drag_onto terminal finder right
drag_out terminal

chapter "Sizes"
switch_to finder
resize_gap finder 60
resize_key grow
resize_key shrink
resize_key balance

chapter "Switching between apps, with an arrangement"
view all
for name in $WALK_CAST; do switch_dock "$name"; done
switch_cmdtab 1

chapter "The view goes in and out"
switch_to finder
view frame
switch_dock safari
switch_cmdtab 1
switch_dock calendar
view all
switch_to safari
view frame
view left
view back
view out
view desktop
view all

chapter "Windows come and go"
switch_to safari
open_new
switch_menu safari
switch_backtick
close_new
switch_to safari
view frame
open_new
close_new
view all
switch_to safari;  minimize;  restore safari
switch_to finder;  hide;  unhide finder
quit_app textedit
reopen textedit

chapter "Full screen"
switch_to safari
full_screen on
full_screen off

chapter "A click lands on the wallpaper, a double-click on a title bar"
wallpaper_click
title_double_click finder
title_double_click calendar

chapter "Where macOS tiles too"
# Late in the day: whatever comes of two window managers answering one drag, the chapters above have been played by then.
switch_to notes
drag_edge notes left
switch_to calendar
drag_edge calendar top
drag_by calendar 0 118 click
view all
tile_click 1
view all

chapter "The ways out"
switch_to safari
pause
drag_by calendar 60 60
resume
float_all
switch_to finder;  dock_key left
switch_to safari;  dock_key right
view frame

chapter "Quit, and the next morning"
quit_and_start
idle_act
walk_end
