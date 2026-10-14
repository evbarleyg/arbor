#!/bin/bash
# F18 on real windows (docs/features/F18-sole-floating-window.md): with `soleFloatTakesDesktop` on, a window that floats
# alone takes the Desktop. What the fakes only assume: that macOS's late reports of Arbor's own moves are not taken
# for the user's (that would replace the window's own frame with the Desktop's), that a real title-bar drag gives the
# window its own size back under the pointer, and that a real resize sticks.
#
#   scripts/mac-shell/run.sh scripts/mac-shell/check-F18.sh
#
# Touches only its own test windows and changes nothing about the system, so it is safe on a person's Mac.
source "$(dirname "$0")/lib.sh"

not() { ! "$@"; }
# takes_desktop <id>: the window server has the window where Arbor's layout has the Desktop
takes_desktop() { arbor_close "$(arbor_ask desktop)" "$(real_frame_of "$1")"; }
# has_size <id> "<w> <h>"
has_size() {
  local w h
  read -r _ _ w h <<< "$(real_frame_of "$1")"
  arbor_close "0 0 $w $h" "0 0 $2"
}

arbor_build
arbor_settings '{"soleFloatTakesDesktop": true}'
arbor_start 3
read -r _ _ OWN_W OWN_H <<< "$(real_frame_of "$W3")"
OWN="$OWN_W $OWN_H"
echo "W3 is $OWN before Arbor touches it"

step "alone on the Desktop"
ctl dock "$W1" left
check "with company it keeps its size" has_size "$W3" "$OWN"
ctl dock "$W2" beside "$W1" bottom
check "alone, it takes the Desktop" eventually takes_desktop "$W3"
check "and is still floating" is floating "$W3"
shot 01-alone

step "company"
# Long enough for every late report of the move above to have arrived.
sleep 2
ctl float "$W2"
check "it has its own size back" eventually has_size "$W3" "$OWN"
shot 02-company
ctl dock "$W2" beside "$W1" bottom
check "alone again, it takes the Desktop" eventually takes_desktop "$W3"

step "it follows the Desktop"
read -r GAP_X GAP_Y <<< "$(seam_right_of "$W1")"
[ -n "$GAP_Y" ] || die "Arbor does not answer"
drag "$GAP_X" "$GAP_Y" "$((GAP_X - 80))" "$GAP_Y"
check "after a gap was dragged" eventually takes_desktop "$W3"
shot 03-gap-dragged
ctl zoom "$W1"
check "out of view with the Desktop" eventually not is on_screen "$W3"
ctl back
check "and back" eventually takes_desktop "$W3"

step "dragged by its title bar"
read -r BAR_X BAR_Y <<< "$(titlebar_of "$W3")"
[ -n "$BAR_Y" ] || die "Arbor does not answer"
drag "$BAR_X" "$BAR_Y" "$((BAR_X - 30))" "$((BAR_Y + 80))"
check "it is its own size again" eventually has_size "$W3" "$OWN"
check "and still floating" is floating "$W3"
read -r X Y W _ <<< "$(real_frame_of "$W3")"
check "with the pointer still on its title bar" inside "$((BAR_X - 30)) $((BAR_Y + 80)) 1 1" "${X%.*} ${Y%.*} ${W%.*} 60"
shot 04-dropped
ctl resize "$W1" right 20
sleep 1
check "where it was dropped it stays that size" has_size "$W3" "$OWN"

step "resized by hand"
ctl dock "$W3" right
ctl float "$W3"
check "floated again, it takes the Desktop" eventually takes_desktop "$W3"
read -r X Y W H <<< "$(frame_of "$W3")"
[ -n "$H" ] || die "Arbor does not answer"
drag "$((X + W / 2))" "$((Y + H - 1))" "$((X + W / 2))" "$((Y + H - 151))"
sleep 1
read -r _ _ _ RESIZED_H <<< "$(real_frame_of "$W3")"
check "the bottom edge came up" [ "${RESIZED_H%.*}" -lt "$((H - 100))" ]
ctl resize "$W1" right -20
sleep 1
check "and later layouts leave the height alone" has_size "$W3" "$(real_frame_of "$W3" | cut -d' ' -f3) $RESIZED_H"
check "it does not take the Desktop" not takes_desktop "$W3"
shot 05-resized

step "pausing"
ctl dock "$W3" right
ctl float "$W3"
check "it takes the Desktop" eventually takes_desktop "$W3"
FILLED=$(real_frame_of "$W3")
ctl pause
sleep 1
check "paused, it stays as it is, like everything in view" arbor_close "$FILLED" "$(real_frame_of "$W3")"
shot 06-paused
ctl resume
check "resumed, it still takes the Desktop" eventually takes_desktop "$W3"

arbor_stop 07-quit
