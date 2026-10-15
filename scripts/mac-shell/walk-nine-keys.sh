#!/bin/bash
# Every word of lib-walk.sh that runs a command of Arbor's, once and more, as Arbor ships: by its key where it is one of the nine, else from the menu (way_to).
# Written by hand, for one playing on a hosted Mac: the rehearsal on Linux plays the words over again in Swift and does not run lib-walk.sh's bash.
source "$(dirname "${BASH_SOURCE[0]}")/lib-walk.sh"
walk_begin stock laptop defaults nine-keys
switch_dock safari
dock_key left
switch_dock notes
dock_key right
switch_dock textedit
dock_key up
switch_dock calendar
dock_key down
focus_key left
view frame
view out
view in
view left
view right
view back
view forward
view desktop
view all
view home
save_view 2
view frame
view_n 2
peek
view home
switch_dock notes
resize_key grow
resize_key shrink
resize_key balance
rotate
mirror
undo
redo
float_key
undo
arrange_key
hold_view
float_all
undo
pause
resume
walk_end
