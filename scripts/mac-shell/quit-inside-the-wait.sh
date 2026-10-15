#!/bin/bash
# Nothing is docked, nine real apps float. The second display comes, or goes, and Arbor is quit within the second: inside its own wait for the displays to settle.
# The question (board 0.23): on its way out, does Arbor set a frame to a floating window that macOS has just moved? The trace says: every `setFrame` after the change.
source "$(dirname "${BASH_SOURCE[0]}")/lib-walk.sh"
walk_begin stock two defaults quit-inside-the-wait

quit_inside_the_wait() {
  walk_act display-change "display-$1-and-quit" "the second display: $1, and Arbor is quit within the second"
  case "$1" in
    # display_add comes back seconds after the display is there, so the quit is sent from beside it.
    plug)
      (sleep 0.8; ctl quit > /dev/null 2>&1) &
      display_add 1920 1080 right
      WALK_SECOND=yes ;;
    unplug)
      display_remove
      WALK_SECOND=""
      ctl quit > /dev/null 2>&1 ;;
  esac
  want "Arbor ends within five seconds" day_gone
  day_forgets
  sleep 2
  read -r _ WALK_X WALK_Y WALK_W WALK_H _ <<< "$(pointer displays | head -n 1)"
  changed
  acted moves=any leaves=any
  walk_start
}

quit_inside_the_wait plug
quit_inside_the_wait unplug
quit_inside_the_wait plug
quit_inside_the_wait unplug
walk_end
