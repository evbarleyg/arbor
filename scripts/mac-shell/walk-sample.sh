#!/bin/bash
# A walk from the seed 4711: scripts/mac-shell/walk.py 4711 --acts 100 --display laptop --tiling defaults
# Written by a program. Change the program, not this file.
source "$(dirname "${BASH_SOURCE[0]}")/lib-walk.sh"
walk_begin stock laptop defaults 4711
view all
switch_dock calendar
minimize
view frame
restore calendar
view all
close_new
switch_dock notes
hide
unhide notes
focus_key up
switch_to finder
dock_key left
switch_backtick
view desktop
view in
close_new
drag_edge finder right
title_double_click finder
quit_app preview
view all
switch_dock calendar
minimize
reopen preview
switch_dock safari
full_screen on
full_screen off
switch_cmdtab 1
restore calendar
switch_dock textedit
view frame
quit_app safari
reopen safari
drag_onto safari mail top
idle_act
quit_app preview
switch_cmdtab 3
switch_click finder
reopen preview
switch_menu safari
view desktop
idle_act
view out
switch_cmdtab 2
switch_cmdtab 3
switch_dock settings
view in
tile_click 1
switch_to mail
redo
quit_and_start
float_all
switch_to safari
dock_key left
drag_onto textedit preview bottom
title_double_click terminal
float_all_here
switch_to settings
dock_key down
view all
switch_dock safari
full_screen on
full_screen off
switch_click notes
tile_click 2
quit_app textedit
tile_click 1
drag_onto terminal mail top
reopen textedit
switch_dock notes
switch_dock notes
minimize
view left
drag_edge preview left
restore notes
title_double_click finder
switch_dock safari
open_new
switch_dock textedit
minimize
close_new
pause
restore textedit
float_all
resume
drag_by textedit -190 27
walk_end
