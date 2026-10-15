#!/bin/bash
# A walk from the seed 1017: scripts/mac-shell/walk.py 1017 --acts 95 --display two --tiling defaults
# Written by a program. Change the program, not this file.
source "$(dirname "${BASH_SOURCE[0]}")/lib-walk.sh"
walk_begin stock two defaults 1017
switch_to notes
arrange_key
display plug
drag_onto textedit safari bottom
view back
float_all
switch_to settings
undo
hold_view
display unplug
display plug
display smaller
drag_onto calendar settings right
view in
view all
switch_to terminal
undo
view back
drag_out safari
drag_onto calendar terminal top
drag_by notes 126 53
switch_to settings
pin
switch_to finder
redo
display right
idle_act
view frame
switch_to settings
dock_key down
drag_onto terminal mail left
switch_to notes
dock_key left
switch_dock finder
open_new
drag_edge mail right
display left
close_new
resize_gap terminal -40
drag_onto preview finder top
view all
resize_edge mail top 30
display unplug
switch_cmdtab 1
switch_dock safari
full_screen on
full_screen off
idle_act
resize_key grow
view out
drag_out calendar
save_view 2
quit_and_start
view in
switch_to safari
float_key
drag_onto mail safari left
view frame
switch_to calendar
pin
drag_edge calendar right
drag_out notes
view all
drag_edge terminal right
drag_by preview -112 46 click
display plug
close_new
drag_by safari -100 91
close_new
float_all
view out
view frame
display smaller
focus_key up
switch_dock safari
open_new
switch_to preview
dock_key down
close_new
view all
peek
switch_dock notes
minimize
resize_gap textedit -40
switch_dock finder
switch_click textedit
restore notes
hold_view
drag_edge preview left
display larger
send_across
float_all
switch_to settings
dock_key up
quit_app safari
view right
view home
reopen safari
walk_end
