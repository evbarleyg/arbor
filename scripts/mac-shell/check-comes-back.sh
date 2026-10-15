#!/bin/bash
# A docked window that is in the Dock, or hidden with its app, is fetched while the view is elsewhere. On real windows: one layout.
#
#   scripts/mac-shell/run.sh scripts/mac-shell/check-comes-back.sh
#
# What only a Mac can say. Arbor asks the window back and waits for macOS's word that it is there; what is on screen stays meanwhile, and
# the report brings one layout, for the view that shows the window (Controller+OneLayout.swift). The stand-ins play the order of the reports.
# They do not play the flight out of the Dock, nor what macOS makes of a size asked of a window where it stands. So, in each round:
#   - how long after the request does macOS say that the window is back, and is that within `timeToLand` (0.5 s), after which the view
#     goes without it? Arbor's log and the recording have the times;
#   - does the neighbour, which nobody asked for, ever show while the window is on its way?
#   - does what was on screen stay until the window is there?
#   - DOES THE WINDOW FILL THE SCREEN AT THE END? It is asked to grow where it stands, in its old slot, and macOS holds a window that grows
#     back at the display's edge and the top of the Dock. Taken for "it cannot grow", the window would sit short in the middle.
# Several rounds, because what goes wrong here goes wrong by milliseconds. The run records itself: the recording is judged afterwards.
#
# Safe on a person's Mac: it touches its own test windows and changes no setting.
source "$(dirname "$0")/lib.sh"

ROUNDS=3

arbor_build

step "two apps: W1 on the left, W2 above the other app's V1 on the right"
ARBOR_SECOND_APP=1
arbor_start 2
check "Arbor manages the other app's window too" eventually is managed "$V1"
# Two apps have just joined the Dock, which changes the visible frame for a second or so.
sleep 3
ctl dock "$W1" left
ctl dock "$W2" right
ctl dock "$V1" beside "$W2" bottom
summary

not() { ! "$@"; }
# What Arbor has logged since line $1, without the date.
logged_since() { tail -n "+$(($1 + 1))" "$ARBOR_HOME/arbor.log" | cut -c 12-; }

# Everything in view, the keyboard in W1; V1 goes away as $1 says; the view is framed on W1.
start_over() {
  ctl show-all > /dev/null
  click_window "$W1"
  eventually is focused "$W1" || return 1
  case "$1" in
    minimized) tw2 minimize "$V1"; eventually is minimized "$V1" || return 1 ;;
    hidden) tw2 hide; eventually is hidden "$V1" || return 1 ;;
  esac
  # Longer than the flight into the Dock.
  sleep 1.5
  ctl zoom "$W1" > /dev/null
  eventually fills "$W1" && eventually is parked "$W2"
}

# Looks for a second and a half, as often as it can, at the two windows nobody asked for. Prints what it saw; fails if W2 ever showed, or if W1
# left before V1 was there.
watch_the_flight() {
  local looks=0 w2_showed=0 w1_left_early=0 deadline=$((SECONDS + 2))
  while [ "$SECONDS" -lt "$deadline" ] && [ "$looks" -lt 30 ]; do
    looks=$((looks + 1))
    in_view "$W2" && w2_showed=$((w2_showed + 1))
    if not in_view "$W1" && not in_view "$V1"; then w1_left_early=$((w1_left_early + 1)); fi
  done
  echo "looked $looks times: W2 showed $w2_showed times; neither W1 nor V1 was in view $w1_left_early times"
  [ "$w2_showed" -eq 0 ] && [ "$w1_left_early" -eq 0 ]
}

the_end() {
  check "V1 fills the screen: whole, not short of its slot" eventually fills "$V1" || summary
  check "and has the keyboard" eventually is focused "$V1"
  check "W1 and W2 are out of view" eventually is parked "$W1"
  check "" is parked "$W2"
  check "and it stays so" stays fills "$V1"
  settled
}

for away in minimized hidden; do
  round=1
  while [ "$round" -le "$ROUNDS" ]; do
    claim "A window that is $away is fetched by name while the view is on another: nothing else shows, and it fills the screen ($round of $ROUNDS)"
    check "V1 is $away, the view is on W1" start_over "$away"
    mark=$(wc -l < "$ARBOR_HOME/arbor.log")
    ctl reveal "$V1" &
    asking=$!
    check "while it is on its way what is on screen stays, and its neighbour never shows" watch_the_flight
    wait "$asking"
    the_end
    logged_since "$mark" | grep -E "reveal|keyboard|made room|framed|showing|asked" | tail -n 12
    round=$((round + 1))
  done
done

round=1
while [ "$round" -le "$ROUNDS" ]; do
  claim "A window comes back out of the Dock by its app's own doing, with the keyboard, while the view is on another: one layout ($round of $ROUNDS)"
  check "V1 is minimized, the view is on W1" start_over minimized
  mark=$(wc -l < "$ARBOR_HOME/arbor.log")
  # As a click on its miniature in the Dock does: the app takes the window out and makes it key.
  tw2 activate "$V1"
  tw2 restore "$V1"
  check "its neighbour never shows" watch_the_flight
  the_end
  logged_since "$mark" | grep -E "keyboard|made room|framed|showing" | tail -n 12
  round=$((round + 1))
done

arbor_stop
