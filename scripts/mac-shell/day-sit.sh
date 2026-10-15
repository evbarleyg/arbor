#!/bin/bash
# A sit: an arrangement is made, a window is framed, and then nobody touches the Mac for six minutes. What only the clock brings: apps going about
# their business, Arbor with nothing to do (docs/VIABLE.md, "A synthetic user-hour").
#
#   scripts/mac-shell/run.sh scripts/mac-shell/day-sit.sh
WALK_KIND=sit
source "$(dirname "${BASH_SOURCE[0]}")/lib-walk.sh"
walk_begin stock "${DAY_DISPLAY:-laptop}" "${DAY_TILING:-defaults}"
switch_click safari
dock_key left
switch_click terminal
dock_key right
switch_click notes
chapter "Everything in view, and nobody there"
for _ in 1 2 3 4 5 6; do idle_act; done
switch_click safari
view frame
chapter "A window framed, and nobody there"
for _ in 1 2 3 4 5 6; do idle_act; done
view all
walk_end
