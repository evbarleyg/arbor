#!/bin/bash
# A walk from the seed 1019: scripts/mac-shell/walk.py 1019 --acts 90 --display two --tiling defaults
# Written by a program. Change the program, not this file.
source "$(dirname "${BASH_SOURCE[0]}")/lib-walk.sh"
walk_begin stock two defaults 1019
display plug
carry_across notes
display unplug
display plug
display smaller
wallpaper_click
resize_edge calendar bottom -30
display unplug
view home
drag_by settings -188 -120 click
resize_key balance
switch_dock safari
hide
display plug
switch_to notes
pin
drag_onto safari terminal top
unhide safari
view all
resize_key balance
view frame
switch_dock safari
full_screen on
full_screen off
view all
save_view 1
drag_out safari
view in
drag_out textedit
resize_gap notes 80
switch_click terminal
drag_edge calendar top
view desktop
drag_onto terminal textedit left
send_across
view home
idle_act
view all
send_across
view in
switch_to settings
dock_key down
switch_dock notes
minimize
switch_to finder
dock_key right
switch_to terminal
dock_key right
restore notes
drag_by safari 144 116 click
drag_onto terminal terminal top
drag_onto settings textedit bottom
switch_to safari
dock_key left
quit_and_start
pause
save_view 3
drag_edge terminal top
resize_edge preview left -30
resume
view in
resize_gap mail -40
switch_backtick
quit_app textedit
reopen textedit
resize_edge notes right -60
view left
drag_onto settings finder left
switch_to settings
undo
view back
switch_to settings
dock_key down
save_view 2
view forward
drag_onto notes preview left
switch_click calendar
view forward
drag_onto calendar mail left
wallpaper_click
float_all_here
view left
carry_across calendar
close_new
drag_out textedit
close_new
resize_key balance
drag_by calendar -140 -117
switch_to preview
mirror
switch_click notes
idle_act
drag_edge preview top
walk_end
