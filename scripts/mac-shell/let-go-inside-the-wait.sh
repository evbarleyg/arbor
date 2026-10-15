#!/bin/bash
# Nothing is docked, nine real apps float. The second display comes, or goes, and within the second Arbor is quit, or paused: inside its own wait for the displays to settle.
# The question (board 0.23): on its way out, at the resume, or at the ordinary quit that ends the walk, does Arbor set a frame to a floating window that macOS has moved?
# The traces say: every `setFrame` after the change.
source "$(dirname "${BASH_SOURCE[0]}")/lib-walk.sh"
walk_begin stock two defaults let-go-inside-the-wait

# <plug | unplug> <quit | pause>. display_add comes back seconds after the display is there, so the word is sent from beside it.
let_go_inside_the_wait() {
  walk_act display-change "display-$1-and-$2" "the second display: $1, and within the second Arbor is told: $2"
  case "$1" in
    plug)
      (sleep 0.8; ctl "$2" > /dev/null 2>&1) &
      display_add 1920 1080 right
      WALK_SECOND=yes ;;
    unplug)
      display_remove
      WALK_SECOND=""
      ctl "$2" > /dev/null 2>&1 ;;
  esac
  if [ "$2" = quit ]; then
    want "Arbor ends within five seconds" day_gone
    day_forgets
  else
    WALK_PAUSED=yes WALK_AT_PAUSE="" WALK_BEFORE_PAUSE="" WALK_MOVED_IN_PAUSE=""
  fi
  sleep 2
  read -r _ WALK_X WALK_Y WALK_W WALK_H _ <<< "$(pointer displays | head -n 1)"
  changed
  acted moves=any leaves=any
  if [ "$2" = quit ]; then walk_start; else resume; fi
  idle 5
}

let_go_inside_the_wait plug quit
let_go_inside_the_wait unplug quit
let_go_inside_the_wait plug pause
let_go_inside_the_wait unplug pause
let_go_inside_the_wait plug pause
let_go_inside_the_wait unplug quit
walk_end
