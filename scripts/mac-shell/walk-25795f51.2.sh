#!/bin/bash
# A walk from the seed 25795f51.2: arbor-sim walk 25795f51.2 100 --for-a-mac stock laptop off 25795f51721b4804119f5cd9984d60f87c278528
# Written by a program. Change the program, not this file.
source "$(dirname "${BASH_SOURCE[0]}")/lib-walk.sh"
walk_begin stock laptop off 25795f51.2 25795f51721b4804119f5cd9984d60f87c278528
idle_act
switch_to calendar
dock_key up
view back
pause
resume
view right
switch_to textedit
undo
switch_cmdtab 3
switch_cmdtab 2
quit_app preview
switch_to safari
dock_key left
view frame
reopen preview
view out
view back
switch_to notes
dock_key right
switch_to textedit
dock_key right
drag_onto calendar notes bottom
switch_to settings
minimize
drag_onto preview textedit bottom
restore settings
drag_onto settings preview left
drag_edge finder top
dock_key left
float_all
view frame
view all
switch_cmdtab 2
switch_cmdtab 2
switch_to mail
minimize
view all
switch_dock finder
restore mail
switch_dock textedit
switch_dock settings
switch_dock finder
open_new
quit_app safari
arrange_key
view all
tile_click 1
reopen safari
quit_and_start
switch_dock textedit
quit_app safari
quit_app textedit
reopen safari
reopen textedit
drag_onto mail terminal right
switch_dock finder
view home
dock_key down
drag_edge safari left
view all
drag_edge safari right
view all
quit_app safari
drag_onto finder textedit bottom
view left
view all
tile_click 2
reopen safari
drag_edge safari right
view left
drag_onto preview safari right
resize_edge preview top 30
switch_click preview
view frame
view frame
resize_key balance
switch_to settings
minimize
restore settings
walk_end
# 100 acts on the stand-ins: switch 36, open-close 17, dock-key 8, drag 6, drag-where-macos-tiles 4, view 17, resize 2, way-out 3, quit-and-start 4, idle 1, tile-click 2
