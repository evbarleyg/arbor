#!/bin/bash
# Board 0.23, the second half, on real windows. Nothing is docked. Notes is pushed aside by hand over the left edge of the screen until less than two fifths of
# it show. Then the second display comes and goes, as large as it was and smaller, and with it macOS gives the main display another size each time; after
# each change ⌃⌥0 is pressed (`display` does). The question: does Arbor set that window a frame at any of it? In the words of lib-walk.sh, by hand.
source "$(dirname "${BASH_SOURCE[0]}")/lib-walk.sh"

# A hand takes hold of what shows of the title bar, so it takes a few goes.
push_aside() {
  local window x y role fx fy fw fh tries=0
  can_be_dragged "$1" || { left_out "push_aside $1: nothing to take hold of"; return; }
  window=$(window_of "$1")
  while [ "$tries" -lt 4 ]; do
    read -r fx fy fw fh <<< "$(real_frame_of "$window")"
    [ $(((${fx%.*} + ${fw%.*} - WALK_X) * 5)) -gt $((${fw%.*} * 2)) ] || break
    read -r x y role <<< "$(apptool grab "$window")"
    walk_act drag "push-$1-aside" "drags $1, which floats, by its title bar towards the left edge of the screen and lets go"
    must drag_window "$window" "$((WALK_X + 70))" "$y"
    changed
    acted drags="$window" front="$window" own="$window"
    tries=$((tries + 1))
  done
}

walk_begin stock two defaults a-strip
push_aside notes
display plug
display unplug
display plug
display smaller
display unplug
idle_act
walk_end
