#!/bin/bash
# A walk from the seed 4711: scripts/mac-shell/walk.py 4711 --acts 100 --display laptop --tiling defaults
# Written by a program. Change the program, not this file.
source "$(dirname "${BASH_SOURCE[0]}")/lib-walk.sh"
walk_begin stock laptop defaults 4711
drag_onto mail preview right
switch_to mail
float_key
switch_to terminal
arrange_key
switch_dock finder
open_new
close_new
close_new
switch_dock notes
hide
unhide notes
switch_to finder
arrange_key
switch_cmdtab 2
wallpaper_click
switch_to mail
dock_key right
drag_edge terminal left
drag_edge notes left
drag_onto textedit safari top
view all
view back
view right
drag_edge textedit top
drag_out safari
pause
switch_dock mail
minimize
resume
restore mail
resize_key balance
view right
switch_dock safari
hide
unhide safari
resize_key shrink
resize_key shrink
resize_edge notes top -30
view right
drag_onto mail settings top
quit_app safari
view frame
reopen safari
view out
view all
wallpaper_click
switch_to calendar
redo
quit_and_start
switch_dock notes
hide
unhide notes
view_n 3
peek
view all
drag_out mail
view all
view all
switch_to calendar
dock_key up
switch_to safari
dock_key up
drag_by calendar 74 -68 click
view all
view in
switch_to notes
float_key
title_double_click calendar
view back
focus_key up
close_new
idle_act
drag_by mail 40 -72 click
drag_edge settings right
view all
view all
switch_dock terminal
minimize
restore terminal
switch_click terminal
view all
tile_click 2
view left
resize_edge terminal right -30
switch_to finder
pin
resize_edge safari left 30
view out
view back
switch_menu finder
view in
walk_end
