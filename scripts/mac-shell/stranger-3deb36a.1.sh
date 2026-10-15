#!/bin/bash
# A walk from the seed 3deb36a.1: arbor-sim walk 3deb36a.1 100 --for-a-mac stock laptop defaults 3deb36a2f43398d682a3ee60c78b60c6fd018d69 --stranger
# Written by a program. Change the program, not this file.
# By somebody who does not know Arbor: nothing is asked of it. Played without Arbor too, and nothing may differ.
source "$(dirname "${BASH_SOURCE[0]}")/lib-walk.sh"
walk_begin stock laptop defaults 3deb36a.1 3deb36a2f43398d682a3ee60c78b60c6fd018d69
full_screen on
full_screen off
drag_edge mail top
quit_app preview
switch_dock finder
switch_dock textedit
open_new
drag_by terminal -193 50
reopen preview
full_screen on
full_screen off
switch_menu finder
drag_by notes -155 38
switch_menu textedit
switch_to calendar
hide
unhide calendar
quit_app safari
reopen safari
switch_cmdtab 1
switch_dock textedit
full_screen on
full_screen off
drag_by finder 204 90 click
drag_edge settings left
switch_to mail
minimize
drag_by settings 114 98 click
restore mail
drag_by settings -291 5 click
switch_dock settings
quit_app textedit
drag_edge preview right
reopen textedit
switch_click preview
title_double_click finder
switch_to finder
hide
title_double_click mail
switch_cmdtab 1
unhide finder
switch_to calendar
minimize
drag_by notes -216 144 click
switch_dock textedit
restore calendar
title_double_click textedit
switch_cmdtab 1
drag_by mail 158 64 click
full_screen on
full_screen off
drag_edge preview top
title_double_click textedit
switch_to finder
hide
quit_app safari
switch_cmdtab 1
title_double_click preview
unhide finder
reopen safari
idle_act
switch_cmdtab 1
full_screen on
full_screen off
walk_end
# 101 acts on the stand-ins: switch 48, open-close 19, drag 7, drag-where-macos-tiles 4, macos-own 20, quit-and-start 2, idle 1
