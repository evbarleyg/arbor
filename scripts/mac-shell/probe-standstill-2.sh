#!/bin/bash
# Who holds the display? Part 2: Arbor, with one thing changed at a time (part 1 has the story and the control).
#
# THE QUESTION ONLY A MAC CAN ANSWER: which of the things Arbor shows or does around a move of the view has to be there for the display to stand still:
# the stage, the focus ring, the ground behind docked windows, the gap handles, the line of words; how many windows come back; after how long; whose they are.
# Settings are changed in a running session, and the session ends as it began: with everything as it ships.
ARBOR_TIME_LIMIT=1150
source "$(dirname "$0")/lib-standstill.sh"
needs_throwaway_mac "film the whole display, change Accessibility settings and the test apps' defaults, and sample every process as root"

still_build
still_begin
pulse_start

cast_start 4 $STILL_FACE
sleep 3
still_arrange
still_press "$W3"
summary

step "as it ships"
away_and_back ships 2

step "A. no stage: animationDuration 0"
ctl set animationDuration 0
away_and_back no-stage 3
ctl reset animationDuration

step "no focus ring"
ctl set focusRing false
away_and_back no-ring 3
ctl reset focusRing

step "no ground behind docked windows, no line around the Desktop"
ctl set dimBehindArranged 0
ctl set desktopEdge 0
away_and_back no-ground 3
ctl reset dimBehindArranged
ctl reset desktopEdge

step "no gap handles"
ctl set gapHandles off
away_and_back no-handles 3
ctl reset gapHandles

step "none of them, no words, tiles at once: the stage alone"
ctl set focusRing false
ctl set dimBehindArranged 0
ctl set desktopEdge 0
ctl set gapHandles off
ctl set messages off
ctl set tileFade 0
away_and_back stage-alone 3
for key in focusRing dimBehindArranged desktopEdge gapHandles messages tileFade; do ctl reset "$key"; done

step "a slower stage: does the standstill begin with the move or end with the stage?"
ctl set animationDuration 0.9
STILL_REST=2.2
away_and_back slow-stage 2
STILL_REST=1.6
ctl reset animationDuration

step "by command instead of by key"
i=1
while [ "$i" -le 2 ]; do
  filmed "command-$i-away" "arborctl desktop" ctl desktop
  filmed "command-$i-back" "arborctl back" ctl back
  i=$((i + 1))
done

step "back at once, and back after a quarter of a minute"
key ctrl+opt+d
sleep 0.9
filmed soon-1-back "presses ⌃⌥[ a second after ⌃⌥D" key ctrl+opt+[
key ctrl+opt+d
sleep 0.9
filmed soon-2-back "presses ⌃⌥[ a second after ⌃⌥D" key ctrl+opt+[
key ctrl+opt+d
sleep 15
filmed late-1-back "presses ⌃⌥[ a quarter of a minute after ⌃⌥D" key ctrl+opt+[
key ctrl+opt+d
sleep 15
filmed late-2-back "presses ⌃⌥[ a quarter of a minute after ⌃⌥D" key ctrl+opt+[

step "B. the moves that were never seen to stand still, under the same eyes: one window framed, and everything again"
i=1
while [ "$i" -le 3 ]; do
  filmed "frame-$i-away" "presses ⌃⌥↩ on a docked window" key ctrl+opt+return
  filmed "frame-$i-back" "presses ⌃⌥Space" key ctrl+opt+space
  i=$((i + 1))
done

step "how many windows come back: three, two, one"
ctl float "$W1"
tell 1 "minimize $W1"
sleep 1.5
still_press "$W3"
away_and_back three 2
ctl float "$W2"
tell 2 "minimize $W2"
sleep 1.5
still_press "$W3"
away_and_back two 2
ctl float "$W4"
tell 4 "minimize $W4"
sleep 1.5
still_press "$W3"
away_and_back one 2
for n in 1 2 4; do eval "tell $n \"restore \$W$n\""; done
sleep 1.5

step "as it ships, once more"
still_arrange
still_press "$W3"
away_and_back ships-again 2
cast_stop

step "C. all four windows one app's"
STILL_CAST=$FILM_CAST
FILM_CAST=""
cast_start 4 $STILL_FACE
sleep 3
still_arrange
still_press "$W3"
away_and_back one-app 3
cast_stop
FILM_CAST=$STILL_CAST

step "no menu bar item"
cast_start 4 ARBOR_NO_HOTKEYS=0
sleep 3
still_arrange
still_press "$W3"
away_and_back no-item 3
cast_stop

step "apps that macOS may not put to sleep while none of their windows shows (no App Nap)"
for name in $FILM_CAST_NAMES; do defaults write "dev.arbor.cast.$name" NSAppSleepDisabled -bool YES; done
cast_start 4 $STILL_FACE
sleep 3
still_arrange
still_press "$W3"
away_and_back no-nap 3
cast_stop
for name in $FILM_CAST_NAMES; do defaults delete "dev.arbor.cast.$name" NSAppSleepDisabled; done

step "with Reduce Transparency, as GitHub's Macs come"
glass off
cast_start 4 $STILL_FACE
sleep 3
still_arrange
still_press "$W3"
away_and_back no-glass 3
cast_stop
glass on

still_end
system_log_of_the_worst 4
