#!/bin/bash
# A walk from the seed 1015: scripts/mac-shell/walk.py 1015 --acts 110 --display two --tiling defaults
# Written by a program. Change the program, not this file.
source "$(dirname "${BASH_SOURCE[0]}")/lib-walk.sh"
walk_begin stock two defaults 1015
switch_to terminal
pin
drag_onto mail safari top
drag_onto calendar finder bottom
switch_to notes
mirror
view all
view right
switch_backtick
drag_onto safari preview top
resize_key balance
switch_to safari
dock_key left
drag_edge textedit left
close_new
switch_to finder
rotate
resize_key grow
resize_edge finder top -30
drag_by preview -121 -22
drag_out textedit
drag_onto preview safari left
display smaller
view forward
close_new
drag_onto textedit calendar top
switch_dock safari
open_new
resize_key balance
close_new
idle_act
idle_act
display left
switch_to terminal
dock_key left
drag_edge calendar right
drag_by notes 67 34
view frame
view in
resize_gap textedit -40
switch_to safari
undo
view all
tile_click 2
view in
switch_to preview
rotate
view right
resize_key shrink
view all
drag_out textedit
view all
switch_to textedit
dock_key up
drag_edge terminal right
switch_dock settings
minimize
restore settings
send_across
quit_and_start
hold_view
drag_edge mail right
peek
switch_to textedit
arrange_key
switch_to preview
dock_key down
drag_by safari -169 13 click
resize_key balance
drag_by calendar 32 53
view right
view right
drag_by safari -178 35
view out
resize_edge preview bottom 30
resize_gap textedit 80
idle_act
switch_to settings
dock_key down
title_double_click finder
switch_dock finder
open_new
send_across
view frame
switch_to settings
redo
close_new
switch_click calendar
drag_edge textedit right
idle_act
pause
display unplug
view right
wallpaper_click
resume
view frame
view right
drag_onto mail mail left
quit_app safari
drag_onto preview safari bottom
switch_menu textedit
reopen safari
view frame
view back
drag_onto finder safari left
drag_by terminal 46 -61
walk_end
