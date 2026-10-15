#!/bin/bash
# A window of the SMALL display is dropped, by a hand, just over the border on the LARGE one: does it fill its slot? A probe (collab/BOARD.md, 0.22). For a plain branch.
#
#   scripts/mac-shell/run.sh --no-preflight "<why>" scripts/mac-shell/check-displays.sh scripts/mac-shell/probe-dropped-over-the-border.sh
#
# Seen on a hosted Mac on 2026-10-15: `move-to-display` from a display of 1280×720 to one of 1920×1080 left the docked window 677 high in a slot of 947: a size call right after the
# change of display is judged by the display the window came from; asked again a millisecond later it answered the same, and Arbor centred it in its slot as it does a window that refuses
# to grow. That was a command. This is the hand: the window is taken at the LEFT of its title bar and let go with the pointer some 50 points over the border, over the near side of a
# window that is docked on the large display, so that the larger part of it still lies on the small display at the release.
# Forecast, from a model only: docked, but short (about the small display's height), centred, and filled by a trip out of view and back.
#
# Nothing here is a verdict but its premises: the lines `look …` are the point, and the trace. It cannot be rehearsed: the fake Mac has no virtual display.
# Only on GitHub's Macs: it plugs a display in, at which macOS moves every window, and takes the pointer.
source "$(dirname "$0")/lib.sh"
needs_throwaway_mac "plug a virtual display in, at which macOS moves every window, and drag a window with the real pointer"

arbor_build
# As check-displays.sh has it: the screen's edges are Arbor's only with macOS's own tiling off.
macos_tiling off
ARBOR_RECORD=1
arbor_start 3

# look <when>: where the window server has the window, where Arbor's layout wants it, and what Arbor says of it
look() {
  echo "look $1: W2 the window server $(real_frame_of "$W2" 2>&1) | its slot $(slot_of "$W2" 2>&1 | tail -n 1) | docked $(is docked "$W2" > /dev/null 2>&1 && echo yes || echo no) | display $(arbor_ask display "$W2" 2>&1 | tail -n 1) | in its slot $(is in_slot "$W2" > /dev/null 2>&1 && echo yes || echo no)"
}

step "two displays: the large one is the main one, the small one at its right"
display_add 1280 800 right
"$ARBOR_VDISPLAY" list
arranges() { [ "$(arbor_ask displays)" = "$1" ]; }
check "Arbor arranges two displays" eventually arranges 2
read -r _ _ large_w large_h <<< "$(display_frame_of 1)"
read -r small_x small_y small_w small_h <<< "$(display_frame_of 2)"
echo "the large display is $large_w × $large_h; the small one $small_w × $small_h at $small_x $small_y; the border is at x $small_x"
check "the second display is the lower of the two" test "${small_h%.*}" -lt "${large_h%.*}"
border=${small_x%.*}

step "W1 is docked at the right of the large display; W2 floats on the small one"
ctl dock "$W1" right
ctl move-to-display next "$W2"
sleep 1
summary
check "W1 is docked on the large display" is display1 "$W1"
check "W2 floats" is floating "$W2"
check "W2 is on the small display" is display2 "$W2"
look "before"
shot 01-before

step "the hand: taken at the left of its title bar, carried until the pointer is 50 points over the border, held, let go"
read -r x y w h <<< "$(real_frame_of "$W2")"
x=${x%.*} y=${y%.*} w=${w%.*}
# Right of the three buttons.
from_x=$((x + 90)) from_y=$((y + 12))
read -r _ slot_y _ slot_h <<< "$(slot_of "$W1")"
to_x=$((border - 50)) to_y=$((${slot_y%.*} + ${slot_h%.*} / 2))
echo "from $from_x $from_y to $to_x $to_y: at the release the window should reach from $((to_x - 90)) to $((to_x - 90 + w)): $((border - to_x + 90)) points of its $w on the large display"
drag "$from_x" "$from_y" "$to_x" "$to_y" --no-release
sleep 0.5
look "held"
echo "Arbor's own windows while it is held (id pid level x y w h on owner):"
pointer windows --on-screen | awk -v pid="$ARBOR_PID" '$2 == pid'
shot 02-held
held=$(real_frame_of "$W2")
release
read -r hx _ hw _ <<< "$held"
check "at the release the larger part of it lay on the small display" test "$((${hx%.*} + ${hw%.*} / 2))" -gt "$border"
sleep 1
look "1 s after the release"
shot 03-one-second-after
sleep 2
look "3 s after the release"
summary
shot 04-three-seconds-after

step "a trip out of view and back"
ctl zoom "$W1"
sleep 1
look "with W1 framed"
ctl back
sleep 1
look "back"
summary
shot 05-back

step "the same by command, for comparison: to the small display and back"
ctl move-to-display next "$W2"
sleep 1
look "moved to the small display"
ctl move-to-display next "$W2"
sleep 1
look "1 s after the move to the large display"
sleep 2
look "3 s after the move to the large display"
summary

arbor_stop 06-quit
display_remove
