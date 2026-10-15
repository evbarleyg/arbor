#!/bin/bash
# A walk from the seed 25795f51.1: arbor-sim walk 25795f51.1 100 --for-a-mac stock laptop defaults 25795f51721b4804119f5cd9984d60f87c278528
# Written by a program. Change the program, not this file.
source "$(dirname "${BASH_SOURCE[0]}")/lib-walk.sh"
walk_begin stock laptop defaults 25795f51.1 25795f51721b4804119f5cd9984d60f87c278528
switch_cmdtab 3
hold_view
view all
drag_edge settings right
switch_dock calendar
view back
view out
switch_dock terminal
view all
quit_app textedit
reopen textedit
open_new
drag_edge notes left
close_new
focus_key down
idle_act
view in
view all
switch_to preview
dock_key down
drag_out preview
focus_key down
switch_dock finder
open_new
view all
switch_to settings
pin
close_new
switch_dock textedit
open_new
switch_dock mail
switch_to preview
minimize
restore preview
save_view 3
switch_to finder
dock_key right
quit_app preview
view frame
switch_menu finder
drag_by settings 54 102 click
reopen preview
quit_and_start
arrange_key
view all
drag_onto terminal preview bottom
resize_edge textedit left 30
view frame
view frame
switch_dock textedit
open_new
drag_by settings -28 58 click
close_new
switch_to finder
minimize
drag_by settings 106 -30 click
restore finder
view frame
drag_edge safari right
drag_edge mail top
view right
switch_to terminal
undo
view back
drag_onto textedit terminal left
dock_key down
drag_by safari -19 74
view left
switch_dock terminal
open_new
view home
close_new
resize_edge textedit left -30
pause
switch_to terminal
switch_to preview
switch_to calendar
switch_to terminal
switch_to settings
switch_to terminal
switch_to notes
resume
walk_end
# 106 acts on the stand-ins: switch 43, open-close 17, dock-key 6, drag 7, drag-where-macos-tiles 4, view 18, resize 2, way-out 4, quit-and-start 4, idle 1
