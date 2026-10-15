#!/bin/bash
# The key that fills the screen, on real windows that were never docked (collab/QUESTIONS.md, Q29; Controller+Fill.swift).
# What the fakes only assume: that the real ⌃⌥↩ reaches Arbor with a floating window in front, that macOS's late reports of Arbor's
# own move are not taken for a hand's (that would end the fill, and make the view's size the window's own), that a real title-bar
# drag brings the window out in its own size under the pointer, that a slip of the hand does not, and that a real resize sticks.
# And how a window got where it is, which a look at it at rest does not tell: the frames Arbor asked it to take, counted in Arbor's own trace.
#
#   scripts/mac-shell/run.sh scripts/mac-shell/check-fill.sh scripts/mac-shell/check-fill-apps.sh
#
# Touches only its own test windows and changes nothing about the system, so it is safe on a person's Mac.
source "$(dirname "$0")/lib.sh"

not() { ! "$@"; }
# is_at <id> "<x y w h>": the window server has it there
is_at() { arbor_close "$(real_frame_of "$1")" "$2"; }
# has_size <id> "<w> <h>"
has_size() {
  local w h
  read -r _ _ w h <<< "$(real_frame_of "$1")"
  arbor_close "0 0 $w $h" "0 0 $2"
}
# calls_of <id> <command>: "2 calls in 73 ms: …": what Arbor asked of that window since the command last came (calls.py)
calls_of() {
  arbor_trace_note "at rest"
  python3 "$ARBOR_ROOT/scripts/mac-shell/calls.py" "$ARBOR_HOME/traces" "$1" "$2"
}
# On a person's Mac nothing is recorded, so there is nothing to count.
in_one_call() { ! arbor_records || [ "${1%% *}" = 1 ] || { echo "$1"; return 1; }; }

arbor_build
ARBOR_TEST_WINDOWS_ARGS="--regular --max-size 3:500x400"
arbor_start 3 ARBOR_NO_HOTKEYS=0
OWN1=$(real_frame_of "$W1")
OWN2=$(real_frame_of "$W2")
OWN3=$(real_frame_of "$W3")
read -r _ _ OWN_W OWN_H <<< "$OWN1"
echo "before Arbor touches anything: W1 $OWN1, W2 $OWN2, W3 $OWN3"

claim "the key fills the screen with a window that was never docked, and nothing else moves"
click_window "$W1"
check "the real key runs the command" pressed ctrl+opt+return zoom
check "it fills the view" eventually fills "$W1"
check "and went there in one call" in_one_call "$(calls_of "$W1" zoom)"
check "it still floats" is floating "$W1"
check "Arbor knows that it fills" is filled "$W1"
check "the second window has not moved" is_at "$W2" "$OWN2"
check "nor the third" is_at "$W3" "$OWN3"
shot 01-filled

claim "it stays filled: macOS's late reports of the move are not a hand's"
sleep 3
check "it fills the view" stays fills "$W1"
check "Arbor knows that it fills" is filled "$W1"
click_window "$W1"
tw title "$W1" "Another title"
open_window N1 size=300x200
check "a window opened, and it fills the view" stays fills "$W1"
tw close "$N1"
forget_window "$N1"
check "that window closed, and it fills the view" stays fills "$W1"

claim "the same key again gives back exactly the frame it had"
click_window "$W1"
check "the real key runs the command" pressed ctrl+opt+return zoom
check "it is where and as large as it was" eventually is_at "$W1" "$OWN1"
check "and went there in one call" in_one_call "$(calls_of "$W1" zoom)"
check "Arbor knows that it no longer fills" not is filled "$W1"
check "the second window has not moved" is_at "$W2" "$OWN2"
shot 02-back

claim "Show Everything means everything: it gives the window its own frame back"
key ctrl+opt+return
check "it fills the view" eventually fills "$W1"
check "the real key runs the command" pressed ctrl+opt+space show-all
check "it is where and as large as it was" eventually is_at "$W1" "$OWN1"
check "Arbor knows that it no longer fills" not is filled "$W1"
check "the second window has not moved" is_at "$W2" "$OWN2"

claim "a window that will not grow that far goes as far as it can, in the middle, and back"
click_window "$W3"
key ctrl+opt+return
check "it is as large as it goes" eventually has_size "$W3" "500 400"
read -r X Y W H <<< "$(real_frame_of "$W3")"
echo "W3 is at $X $Y $W $H"
FIRST=$(calls_of "$W3" zoom)
echo "CALLS W3, the first time: $FIRST"
check "Arbor knows that it fills" is filled "$W3"
shot 03-no-larger
sleep 2
check "it stays there" stays is_at "$W3" "$X $Y $W $H"
key ctrl+opt+return
check "it is where and as large as it was" eventually is_at "$W3" "$OWN3"
check "and went there in one call" in_one_call "$(calls_of "$W3" zoom)"
key ctrl+opt+return
check "the key once more, and it is in the middle again" eventually is_at "$W3" "$X $Y $W $H"
check "known not to grow, it went straight there: one call" in_one_call "$(calls_of "$W3" zoom)"
key ctrl+opt+return
check "it is where and as large as it was" eventually is_at "$W3" "$OWN3"

claim "the first time, too, a window that will not grow that far goes to the middle in one call"
known "board 1.120: how large a window goes is learned by offering it the whole view in the view's corner; after the cut"
check "it did" in_one_call "$FIRST"

claim "dragged by its title bar it comes out in its own size, under the pointer"
click_window "$W1"
key ctrl+opt+return
check "it fills the view" eventually fills "$W1"
read -r BAR_X BAR_Y <<< "$(titlebar_of "$W1")"
[ -n "$BAR_Y" ] || die "Arbor does not answer"
drag "$BAR_X" "$BAR_Y" "$((BAR_X - 60))" "$((BAR_Y + 150))"
check "it is its own size again" eventually has_size "$W1" "$OWN_W $OWN_H"
check "and still floats" is floating "$W1"
check "Arbor knows that it no longer fills" not is filled "$W1"
read -r X Y W _ <<< "$(real_frame_of "$W1")"
check "with the pointer still on its title bar" inside "$((BAR_X - 60)) $((BAR_Y + 150)) 1 1" "${X%.*} ${Y%.*} ${W%.*} 60"
check "the second window has not moved" is_at "$W2" "$OWN2"
DROPPED=$(real_frame_of "$W1")
shot 04-dropped

claim "after a slip of the hand it goes on filling"
key ctrl+opt+return
check "it fills the view" eventually fills "$W1"
read -r BAR_X BAR_Y <<< "$(titlebar_of "$W1")"
drag "$BAR_X" "$BAR_Y" "$((BAR_X + 10))" "$((BAR_Y + 8))"
check "it fills the view" eventually fills "$W1"
check "and stays" stays fills "$W1"
check "Arbor knows that it fills" is filled "$W1"

claim "a size given by hand is its own from then on"
read -r X Y W H <<< "$(frame_of "$W1")"
drag "$((X + W / 2))" "$((Y + H - 1))" "$((X + W / 2))" "$((Y + H - 201))"
sleep 1
read -r _ _ _ RESIZED_H <<< "$(real_frame_of "$W1")"
check "the bottom edge came up" [ "${RESIZED_H%.*}" -lt "$((H - 150))" ]
BY_HAND=$(real_frame_of "$W1")
check "it stays as the hand left it" stays is_at "$W1" "$BY_HAND"
check "Arbor knows that it no longer fills" not is filled "$W1"
click_window "$W1"
key ctrl+opt+return
check "the key fills again" eventually fills "$W1"
key ctrl+opt+return
check "and gives back what the hand made" eventually is_at "$W1" "$BY_HAND"

claim "a pause gives the own frame back, a resume fills again, Undo takes it back"
key ctrl+opt+return
check "it fills the view" eventually fills "$W1"
ctl pause
check "paused, it has its own frame" eventually is_at "$W1" "$BY_HAND"
ctl resume
check "resumed, it fills again" eventually fills "$W1"
ctl undo
check "undone, it has its own frame" eventually is_at "$W1" "$BY_HAND"
ctl redo
check "redone, it fills" eventually fills "$W1"

claim "Quit gives the own frame back"
arbor_quit
shot 05-after-quit
check "it is where and as large as it was" is_at "$W1" "$BY_HAND"
check "the second window never moved" is_at "$W2" "$OWN2"
check "the third is where it was" is_at "$W3" "$OWN3"
