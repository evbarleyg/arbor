#!/bin/bash
# A walk from the seed 3deb36a.3: arbor-sim walk 3deb36a.3 85 --for-a-mac stock laptop defaults 3deb36a2f43398d682a3ee60c78b60c6fd018d69 --stranger --docked 2
# Written by a program. Change the program, not this file.
# 2 windows are docked first. From then on by somebody who does not know Arbor: nothing more is asked of it.
source "$(dirname "${BASH_SOURCE[0]}")/lib-walk.sh"
walk_begin stock laptop defaults 3deb36a.3 3deb36a2f43398d682a3ee60c78b60c6fd018d69
switch_to preview
dock_key left
switch_to notes
dock_key right
switch_to safari
hide
switch_dock terminal
open_new
switch_cmdtab 1
unhide safari
switch_cmdtab 1
close_new
switch_dock calendar
switch_dock calendar
drag_by safari 143 156
drag_by settings -175 148
switch_cmdtab 1
drag_edge textedit top
switch_cmdtab 1
switch_cmdtab 1
title_double_click mail
quit_app safari
switch_dock mail
reopen safari
switch_to terminal
hide
quit_app safari
switch_click mail
unhide terminal
reopen safari
idle_act
title_double_click calendar
quit_app textedit
reopen textedit
drag_by textedit -93 125 click
full_screen on
full_screen off
switch_click preview
title_double_click terminal
drag_by mail -106 8 click
switch_cmdtab 1
drag_by finder 203 -36
switch_menu textedit
full_screen on
full_screen off
switch_to preview
minimize
restore preview
drag_edge preview right
drag_edge textedit top
switch_cmdtab 1
drag_edge preview right
switch_to textedit
minimize
restore textedit
drag_by textedit -138 121
drag_edge safari top
quit_app textedit
reopen textedit
walk_end
# 87 acts on the stand-ins: switch 43, open-close 18, dock-key 2, drag 6, drag-where-macos-tiles 5, macos-own 10, quit-and-start 2, idle 1
