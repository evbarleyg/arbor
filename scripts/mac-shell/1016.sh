#!/bin/bash
# A walk from the seed 1016: scripts/mac-shell/walk.py 1016 --acts 110 --display laptop --tiling defaults
# Written by a program. Change the program, not this file.
source "$(dirname "${BASH_SOURCE[0]}")/lib-walk.sh"
walk_begin stock laptop defaults 1016
drag_edge preview right
switch_to finder
undo
view all
view frame
switch_dock safari
full_screen on
full_screen off
switch_click safari
drag_edge notes left
view all
drag_onto finder terminal top
idle_act
switch_to textedit
rotate
switch_to textedit
dock_key right
switch_to textedit
dock_key down
pause
view frame
resume
switch_to safari
undo
switch_to calendar
dock_key up
drag_onto preview safari top
resize_gap textedit 80
switch_dock notes
close_new
switch_to notes
dock_key up
resize_edge calendar top 60
view frame
switch_click safari
view frame
idle_act
idle_act
resize_edge textedit bottom -60
pause
view back
view back
switch_dock textedit
open_new
resume
close_new
view all
drag_edge textedit right
wallpaper_click
drag_edge safari right
switch_dock finder
hide
unhide finder
hold_view
quit_and_start
view all
pause
resume
view desktop
switch_to notes
pin
switch_click notes
switch_to mail
mirror
drag_by terminal 186 13
view all
tile_click 1
idle_act
save_view 1
switch_dock textedit
minimize
switch_dock safari
open_new
restore textedit
switch_to notes
dock_key down
close_new
view all
quit_app preview
view frame
reopen preview
view out
switch_dock safari
minimize
float_all
switch_to textedit
float_key
switch_dock terminal
open_new
restore safari
close_new
switch_dock textedit
open_new
close_new
resize_key shrink
switch_cmdtab 3
drag_edge textedit top
close_new
switch_dock safari
hide
switch_to safari
undo
unhide safari
walk_end
