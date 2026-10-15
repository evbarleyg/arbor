#!/bin/bash
# A walk from the seed 1018: scripts/mac-shell/walk.py 1018 --acts 95 --display laptop --tiling defaults --cast browsers
# Written by a program. Change the program, not this file.
source "$(dirname "${BASH_SOURCE[0]}")/lib-walk.sh"
walk_begin browsers laptop defaults 1018
view all
drag_out chrome
view all
tile_click 1
switch_menu safari
switch_dock safari
minimize
view in
wallpaper_click
restore safari
resize_key shrink
resize_gap textedit 80
switch_to finder
dock_key down
view all
switch_dock textedit
minimize
restore textedit
view back
resize_key grow
resize_key grow
switch_to terminal
dock_key up
drag_onto firefox edge bottom
view home
switch_cmdtab 3
quit_app textedit
save_view 1
pause
drag_onto firefox edge left
reopen textedit
resume
switch_dock edge
hide
view in
wallpaper_click
idle_act
unhide edge
resize_key shrink
switch_to safari
dock_key up
switch_dock safari
full_screen on
full_screen off
switch_to terminal
dock_key right
quit_and_start
close_new
drag_by firefox 54 57
view frame
switch_click chrome
switch_to chrome
float_key
resize_key balance
switch_to textedit
dock_key right
switch_dock edge
open_new
view in
close_new
view out
switch_to finder
undo
view out
drag_out textedit
idle_act
switch_to textedit
float_key
view out
drag_by terminal -142 19
switch_to finder
pin
view out
drag_edge safari left
view desktop
view frame
drag_by chrome 32 37
drag_edge safari left
switch_dock firefox
switch_dock textedit
view frame
quit_app safari
drag_by edge 131 15 click
resize_edge terminal bottom 60
reopen safari
drag_onto finder edge bottom
view_n 3
switch_dock terminal
hide
unhide terminal
walk_end
