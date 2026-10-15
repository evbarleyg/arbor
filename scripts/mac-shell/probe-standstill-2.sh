#!/bin/bash
# Who holds the display? Part 2: Arbor, with one thing changed at a time (part 1 has the story and the control).
#
# THE QUESTION ONLY A MAC CAN ANSWER: which of the things Arbor shows or does around a move of the view has to be there for the display to stand still:
# the tile's fade, the stage, the focus ring, the ground behind docked windows, the gap handles; whose the windows are, whether their apps sleep, whether
# anything of theirs stays in view; how many come back, and after how long.
# Settings are changed in a running session. What says most comes first; what comes last is left out if time runs short.
ARBOR_TIME_LIMIT=1170
source "$(dirname "$0")/lib-standstill.sh"
needs_throwaway_mac "film the whole display, change Accessibility settings and the test apps' defaults, and sample every process as root"

still_build
still_begin
pulse_start

# session [NAME=value…]: four windows of four apps, arranged as in the films in which the standstill was found
session() {
  cast_start 4 "$@"
  sleep 3
  still_arrange
  still_press "$W3"
}

session $STILL_FACE
summary

step "as it ships"
away_and_back ships 2

step "tiles come and go at once: tileFade 0"
ctl set tileFade 0
away_and_back no-fade 3
ctl reset tileFade

step "A. no stage: animationDuration 0"
ctl set animationDuration 0
away_and_back no-stage 2

step "A2. neither"
ctl set tileFade 0
away_and_back no-stage-no-fade 2
ctl reset tileFade
ctl reset animationDuration

step "no ring, no ground, no handles, no words: the stage and the tile"
ctl set focusRing false
ctl set dimBehindArranged 0
ctl set desktopEdge 0
ctl set gapHandles off
ctl set messages off
away_and_back stage-and-tile 2
for key in focusRing dimBehindArranged desktopEdge gapHandles messages; do ctl reset "$key"; done

step "B. the moves that were never seen to stand still, under the same eyes and in this arrangement: one window framed, and everything again"
i=1
while [ "$i" -le 2 ]; do
  filmed "frame-$i-away" "presses ⌃⌥↩ on a docked window" key ctrl+opt+return
  filmed "frame-$i-back" "presses ⌃⌥Space" key ctrl+opt+space
  i=$((i + 1))
done
cast_stop

step "C. all windows one app's; a fifth is in the Dock"
STILL_CAST=$FILM_CAST
FILM_CAST=""
cast_start 5 $STILL_FACE
sleep 3
tell 5 "minimize $W5"
sleep 1.5
still_arrange
still_press "$W3"
away_and_back one-app 3
step "C2. and the fifth floats on the Desktop: something of the app's is always in view"
tell 5 "restore $W5"
sleep 1.5
tell 5 "move $W5 460 300 200 160"
sleep 1
still_press "$W3"
away_and_back stays 2
cast_stop
FILM_CAST=$STILL_CAST

step "apps that macOS may not put to sleep while none of their windows shows (no App Nap)"
for name in $FILM_CAST_NAMES; do defaults write "dev.arbor.cast.$name" NSAppSleepDisabled -bool YES; done
session $STILL_FACE
away_and_back no-nap 3
cast_stop
for name in $FILM_CAST_NAMES; do defaults delete "dev.arbor.cast.$name" NSAppSleepDisabled; done

session $STILL_FACE
step "one thing less at a time"
if still_has 60 "no focus ring"; then
  ctl set focusRing false
  away_and_back no-ring 2
  ctl reset focusRing
fi
if still_has 60 "no ground"; then
  ctl set dimBehindArranged 0
  ctl set desktopEdge 0
  away_and_back no-ground 2
  ctl reset dimBehindArranged
  ctl reset desktopEdge
fi
if still_has 60 "no gap handles"; then
  ctl set gapHandles off
  away_and_back no-handles 2
  ctl reset gapHandles
fi

both_keys() {
  key ctrl+opt+d
  sleep 0.3
  key ctrl+opt+[
}
if still_has 60 "back at once, and after a quarter of a minute"; then
  step "back at once, and back after a quarter of a minute"
  filmed soon-1-back "presses ⌃⌥D and, as soon as may be, ⌃⌥[" both_keys
  filmed soon-2-back "presses ⌃⌥D and, as soon as may be, ⌃⌥[" both_keys
  key ctrl+opt+d
  sleep 15
  filmed late-1-back "presses ⌃⌥[ a quarter of a minute after ⌃⌥D" key ctrl+opt+[
fi

if still_has 40 "by command"; then
  step "by command instead of by key"
  filmed command-1-away "arborctl desktop" ctl desktop
  filmed command-1-back "arborctl back" ctl back
  filmed command-2-away "arborctl desktop" ctl desktop
  filmed command-2-back "arborctl back" ctl back
fi

if still_has 80 "how many windows come back"; then
  step "how many windows come back: two, one"
  ctl float "$W1"
  tell 1 "minimize $W1"
  ctl float "$W2"
  tell 2 "minimize $W2"
  sleep 1.5
  still_press "$W3"
  summary
  away_and_back two 2
  ctl float "$W4"
  tell 4 "minimize $W4"
  sleep 1.5
  still_press "$W3"
  away_and_back one 2
  for n in 1 2 4; do eval "tell $n \"restore \$W$n\""; done
  sleep 1.5
fi
cast_stop

if still_has 90 "no menu bar item"; then
  step "no menu bar item"
  session ARBOR_NO_HOTKEYS=0
  away_and_back no-item 2
  cast_stop
fi

if still_has 90 "Reduce Transparency"; then
  step "with Reduce Transparency, as GitHub's Macs come"
  glass off
  session $STILL_FACE
  away_and_back no-glass 2
  cast_stop
  glass on
fi

still_end
system_log_of_the_worst 3
