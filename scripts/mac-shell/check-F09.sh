#!/bin/bash
# F09 (drag polish) on real windows, with real title-bar drags:
#
#   scripts/mac-shell/run.sh scripts/mac-shell/check-F09.sh
#
# Session 1, default settings, with ⌘ held as lib.sh's `drag` holds it: let go at once over a window's edge, a floating window stays
# there and a docked one goes back to its slot; held there, a preview shows and the window docks exactly where it was. With
# nothing held (--plain) nothing docks and no preview shows.
# Session 2, dropDwell 2 s, so that the wait is long enough to look at: no preview before it is over, one
# after; an ordinary drag does not dock; a screen edge does not wait.
# Session 3, reflowWhileDragging: the others close up, make room, and go back, also when a docked window is let go
# before the hold is over, and the dragged window stays under the pointer.
#
# What `drag` does matters here (pointer.swift): it rests about 0.25 s at the end, plus --hold (0.2 s), before it
# lets go, which is longer than the default dwell. `release x y` jumps to the point and lets go 0.05 s later.
source "$(dirname "$0")/lib.sh"

not() { ! "$@"; }

# The drop preview as the window server sees it: x y w h, or nothing.
preview_frame() { overlays | awk '$3 == 3 && $8 == "on" { print $4, $5, $6, $7 }'; }

real_frame_is() { [ "$(real_frame_of "$1")" = "$2" ]; }

# Whether the pointer is on the window's title bar, as the window server sees both.
in_the_hand() {
  local x y w h px py rest
  read -r x y w h <<< "$(real_frame_of "$1")"
  read -r px py rest <<< "$(pointer where)"
  px=${px%.*}; py=${py%.*}; x=${x%.*}; y=${y%.*}; w=${w%.*}
  [ "$px" -ge "$x" ] && [ "$px" -le $((x + w)) ] && [ "$py" -ge "$y" ] && [ "$py" -le $((y + 32)) ]
}

# Where to press on a window that may hang off the side of the screen: the middle of the part of its title bar that
# is on it. (titlebar_of gives the middle of the whole title bar, which can be off screen.)
grab_of() {
  local x y w h left right
  read -r x y w h <<< "$(frame_of "$1")"
  left=$x; right=$((x + w))
  [ "$left" -lt "$sx" ] && left=$sx
  [ "$right" -gt $((sx + sw)) ] && right=$((sx + sw))
  echo "$(((left + right) / 2)) $((y + 12))"
}

# How far the pointer is from a window's top-left corner, as the window server sees both: dx dy.
grip() {
  local x y w h px py rest
  read -r x y w h <<< "$(real_frame_of "$1")"
  read -r px py rest <<< "$(pointer where)"
  echo "$((${px%.*} - ${x%.*})) $((${py%.*} - ${y%.*}))"
}

# trace <id> <count> <name>: the pointer and the window, asked as fast as that goes, into mac-shell/<name>.txt.
trace() {
  local index=0
  while [ "$index" -lt "$2" ]; do
    echo "$(arbor_now) pointer $(pointer where) window $(real_frame_of "$1")"
    index=$((index + 1))
  done > "$ARBOR_OUT/$3.txt"
}

# W1 | Desktop | W2, with W3 floating on the Desktop, and the points the drags go to.
arrange() {
  local x y w h
  ctl dock "$W1" left
  ctl dock "$W2" right
  read -r sx sy sw sh <<< "$(arbor_ask screen)"
  read -r x y w h <<< "$(arbor_ask desktop)"
  desk_x=$((x + w / 2)); desk_y=$((y + h / 2))
  read -r x y w h <<< "$(arbor_ask slot "$W2")"
  # With no answer every number is 0, and the drags would end at the corner of the screen.
  [ -n "$h" ] && [ -n "$sh" ] || die "Arbor does not answer"
  # In the band along the top of W2's slot: dropped here a window docks above W2.
  top_x=$((x + w / 2)); top_y=$((y + 40))
  edge_x=$((sx + 3)); edge_y=$((sy + sh / 2))
  summary
}

# Takes W3 back to the middle of the Desktop, floating.
# shellcheck disable=SC2046
home() {
  is docked "$W3" && ctl float "$W3"
  drag $(titlebar_of "$W3") "$desk_x" "$desk_y"
  check "(W3 is floating on the Desktop again)" eventually is floating "$W3"
}

arbor_build
# Its drags dock at the left and right edges of the screen, which are Arbor's only with macOS's own tiling off (MacTiling.swift). It declines on a
# person's Mac, where the setting is theirs; with the tiling on there, those steps fail.
macos_tiling off

step "the Mac: does it ask for less motion?"
# With Reduce Motion the preview does not fade or glide, and the bursts of pictures below show nothing in between.
macos_reduce_motion off

# All three sessions want a Desktop beside two docked windows, to drop a window on: `desktopColumn`, which ships off.
step "session 1: default settings"
arbor_settings '{"desktopColumn": true}'
arbor_start 3
arrange

step "how a docked window follows the pointer without reflow, to compare with session 3"
# A window does not stay under a posted pointer exactly: macOS holds it back for a while whenever one of its edges
# meets another window's, the Dock's or the screen's (trace-docked.txt: x stops where W1's right edge meets W3's left one,
# y where its bottom edge meets the top of the Dock and then the bottom of the screen), and it does not catch up
# afterwards. How far it trails differs from run to run: 12 and 60 points, 100 and 112.
slot1=$(real_frame_of "$W1")
# Without it the arithmetic of a `release` below is a syntax error, bash skips the line, and the button stays down.
[ -n "$slot1" ] || die "no frame for W1"
read -r x1 y1 w1 h1 <<< "$slot1"
trace "$W1" 45 trace-docked &
# shellcheck disable=SC2046
drag $(titlebar_of "$W1") "$((desk_x - 100))" "$desk_y" --no-release
wait $!
grip_plain=$(grip "$W1")
echo "the pointer took hold $((${w1%.*} / 2)) 12 from W1's corner and is now $grip_plain from it"
shot 00-docked-held
release "$((${x1%.*} + ${w1%.*} / 2))" "$((${y1%.*} + 60))"
check "let go over its own slot, W1 is back in it" eventually real_frame_is "$W1" "$slot1"

step "a docked window swept over the top of W2 and let go at once: back in its slot"
slot2=$(real_frame_of "$W2")
# shellcheck disable=SC2046
drag $(titlebar_of "$W1") "$((desk_x - 100))" "$desk_y" --no-release
release "$top_x" "$top_y"
check "W1 is back in its slot" eventually real_frame_is "$W1" "$slot1"
check "it still counts as docked" is docked "$W1"
check "W2 has not moved" real_frame_is "$W2" "$slot2"
check "no preview is on screen" not has_overlay 3
shot 00-docked-quick-pass
summary

step "let go at once over the top of W2: it floats"
trace "$W3" 45 trace-floating &
# shellcheck disable=SC2046
drag $(titlebar_of "$W3") "$desk_x" "$desk_y" --no-release
wait $!
echo "the pointer is $(grip "$W3") from W3's corner"
release "$top_x" "$top_y"
sleep 0.6
check "the window let go at once is floating" is floating "$W3"
check "no preview is on screen" not has_overlay 3
shot 01-quick-pass
summary

step "held there: a preview, and it docks where the preview was"
home
# shellcheck disable=SC2046
drag $(titlebar_of "$W3") "$top_x" "$top_y" --no-release
check "a preview is on screen" eventually has_overlay 3
promised=$(preview_frame)
echo "preview: $promised"
shot 02-held
release &
film 03-release 4
wait $!
check "the window that was held is docked" eventually is docked "$W3"
sleep 0.5
echo "landed: $(frame_of "$W3") (the window server: $(real_frame_of "$W3"))"
check "it landed where the preview was" real_frame_is "$W3" "$promised"
overlays
check "the preview has left the screen, not only faded" not has_overlay 3
shot 04-docked

step "nothing held: a docked window let go over its own slot floats"
read -r x y w h <<< "$(frame_of "$W3")"
# shellcheck disable=SC2046
drag $(titlebar_of "$W3") "$((x + w / 2 + 20))" "$((y + 70))" --plain --no-release
check "no preview with nothing held" not has_overlay 3
shot 05-plain-own-slot
release
sleep 0.6
check "it is floating" is floating "$W3"
summary

step "nothing held: neither a window's edge nor the screen edge docks"
# shellcheck disable=SC2046
drag $(titlebar_of "$W3") "$top_x" "$top_y" --plain --hold 0.5 --no-release ||
  check "the drag was let through (W3 floats already: declined, the checks below would pass for nothing)" false
check "no preview over a window's edge with nothing held" not has_overlay 3
release
sleep 0.6
check "it is floating after the window's edge" is floating "$W3"
# shellcheck disable=SC2046
drag $(titlebar_of "$W3") "$edge_x" "$edge_y" --plain --no-release || check "the drag was let through" false
check "no preview at the screen edge with nothing held" not has_overlay 3
shot 06-plain-screen-edge
release
sleep 0.6
check "it is floating after the screen edge" is floating "$W3"
summary

step "and with ⌘ the screen edge docks"
# From the Desktop: quitting puts a window back where it floated before it was docked (F48), and half off the screen
# is not where arbor_stop expects it.
# shellcheck disable=SC2046
drag $(grab_of "$W3") "$desk_x" "$desk_y"
# shellcheck disable=SC2046
drag $(titlebar_of "$W3") "$edge_x" "$edge_y" --no-release
check "a preview at the screen edge" has_overlay 3
release
check "it is docked" eventually is docked "$W3"
arbor_stop 07-after-quit

step "session 2: dropDwell 2 s"
arbor_settings '{"dropDwell": 2, "desktopColumn": true}'
arbor_start 3
arrange

step "the preview waits until the hold is over"
# shellcheck disable=SC2046
drag $(titlebar_of "$W3") "$top_x" "$top_y" --hold 0 --no-release
check "no preview yet" not has_overlay 3
shot_after 0 10-before-the-dwell
# The hold is over about now: a burst of pictures to catch the preview fading in.
sleep 0.6
film 10-fade-in 14
sleep 1
check "a preview after two seconds" has_overlay 3
shot 11-after-the-dwell
# ⌘ up and down again while the pointer rests. The key alone: with another key it would be a shortcut of the app in front.
key cmd --up
key cmd --down
check "⌘ let go of for a moment: the preview goes" not has_overlay 3
sleep 2.2
check "and comes back when the target has been held again" has_overlay 3
release &
film 12-fade-out 6
wait $!
check "it is docked" eventually is docked "$W3"

step "an ordinary drag, which rests for under half a second, does not dock"
home
# shellcheck disable=SC2046
drag $(titlebar_of "$W3") "$top_x" "$top_y"
sleep 0.6
check "it is floating" is floating "$W3"
check "no preview is on screen" not has_overlay 3

step "a screen edge does not wait"
home
# shellcheck disable=SC2046
drag $(titlebar_of "$W3") "$edge_x" "$edge_y" --hold 0 --no-release
check "a preview at once" has_overlay 3
release
check "it is docked" eventually is docked "$W3"
arbor_stop

step "session 3: reflowWhileDragging"
arbor_settings '{"reflowWhileDragging": true, "desktopColumn": true}'
arbor_start 3
arrange
slot1=$(real_frame_of "$W1")
slot2=$(real_frame_of "$W2")
[ -n "$slot1" ] || die "no frame for W1"
read -r x1 y1 w1 h1 <<< "$slot1"
read -r _ _ w2 h2 <<< "$slot2"

step "W1 leaves its slot: the others close up at once"
# shellcheck disable=SC2046
drag $(titlebar_of "$W1") "$((desk_x - 100))" "$desk_y" --no-release
sleep 0.4
read -r _ _ w2_during _ <<< "$(real_frame_of "$W2")"
echo "W2 was $w2 wide and is $w2_during wide while W1 is held"
check "W2 has taken its share of the space" test "${w2_during%.*}" -gt "${w2%.*}"
grip_reflow=$(grip "$W1")
echo "the pointer is $grip_reflow from W1's corner; without reflow it was $grip_plain"
# Not a check, because of what macOS does by itself (see session 1): three runs gave 100 102 here against 12 60
# without reflow, then 99 81 against 100 112. Arbor sets no frame on a window that is being dragged.
check "nothing is decided: W1 still counts as docked" is docked "$W1"
shot 20-closed-up

step "let go over its old slot: everything is as it was"
release "$((${x1%.*} + ${w1%.*} / 2))" "$((${y1%.*} + 60))"
check "W1 is back in its slot" eventually real_frame_is "$W1" "$slot1"
check "W2 is back in its slot" eventually real_frame_is "$W2" "$slot2"
shot 21-dropped-back
summary

step "W1 leaves its slot, is swept over the top of W2 and let go at once: everything is as it was"
# shellcheck disable=SC2046
drag $(titlebar_of "$W1") "$((desk_x - 100))" "$desk_y" --no-release
sleep 0.4
check "W2 has taken its share of the space" not real_frame_is "$W2" "$slot2"
release "$top_x" "$top_y"
check "W1 is back in its slot" eventually real_frame_is "$W1" "$slot1"
check "W2 is back in its slot" eventually real_frame_is "$W2" "$slot2"
check "W1 still counts as docked" is docked "$W1"
check "no preview is on screen" not has_overlay 3
shot 21-quick-pass
summary

step "W3 held over the top of W2: W2 makes room where the preview is"
# shellcheck disable=SC2046
drag $(titlebar_of "$W3") "$top_x" "$top_y" --no-release
check "a preview is on screen" eventually has_overlay 3
sleep 0.4
promised=$(preview_frame)
room=$(real_frame_of "$W2")
read -r _ _ _ h2_during <<< "$room"
echo "preview: $promised; W2 was $h2 high and is $h2_during high"
check "W2 has made room" test "${h2_during%.*}" -lt "${h2%.*}"
check "W3 is under the pointer" in_the_hand "$W3"
check "nothing is decided: W3 still counts as floating" is floating "$W3"
shot 22-made-room
release
check "W3 is docked" eventually is docked "$W3"
sleep 0.5
check "it landed where the preview was" real_frame_is "$W3" "$promised"
check "W2 stayed where it had made room" real_frame_is "$W2" "$room"
check "the preview has left the screen" not has_overlay 3
shot 23-docked
summary

step "W3 leaves again and is let go on the Desktop: W2 has its slot back"
# shellcheck disable=SC2046
drag $(titlebar_of "$W3") "$desk_x" "$desk_y" --no-release
check "W2 fills its slot while W3 is held" eventually real_frame_is "$W2" "$slot2"
release
check "W3 is floating" eventually is floating "$W3"
check "W2 still fills its slot" real_frame_is "$W2" "$slot2"
arbor_stop 24-after-quit
