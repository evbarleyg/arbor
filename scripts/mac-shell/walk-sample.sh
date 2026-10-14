#!/bin/bash
# A walk from the seed 4711: scripts/mac-shell/walk.py 4711 --acts 100 --display laptop --tiling defaults
# Written by a program. Change the program, not this file.
source "$(dirname "${BASH_SOURCE[0]}")/lib-walk.sh"
walk_begin stock laptop defaults 4711
view back
switch_click textedit
switch_click terminal
dock_key up
switch_click textedit
float_key
switch_dock textedit
hide
unhide textedit
switch_menu textedit
switch_dock mail
hide
resize_gap mail -40
drag_edge textedit left
drag_onto terminal calendar right
unhide mail
view out
switch_dock safari
full_screen on
full_screen off
switch_dock textedit
hide
idle_act
unhide textedit
drag_edge finder right
switch_dock safari
full_screen on
full_screen off
quit_app preview
view left
switch_dock textedit
reopen preview
view back
switch_dock notes
switch_click settings
dock_key right
switch_click mail
dock_key left
switch_click safari
view forward
view out
view in
switch_click safari
dock_key down
quit_app preview
switch_cmdtab 3
switch_dock finder
hide
reopen preview
unhide finder
quit_and_start
switch_dock terminal
open_new
wallpaper_click
close_new
view out
close_new
idle_act
drag_edge safari right
switch_dock finder
open_new
switch_dock safari
full_screen on
full_screen off
close_new
close_new
switch_cmdtab 3
view in
switch_dock terminal
open_new
switch_tile
close_new
view left
wallpaper_click
switch_click textedit
switch_click textedit
drag_onto textedit preview bottom
wallpaper_click
pause
switch_click settings
dock_key down
view back
drag_by mail -126 75
resume
drag_onto preview notes right
switch_click preview
walk_end
