#!/bin/bash
# The focus ring (docs/features/F37-focus-ring.md) on real windows, in pictures and checks. Run it with
#
#   scripts/mac-shell/run.sh scripts/mac-shell/shots-focus-ring.sh
#
# Session 1, default settings: the ring on a floating window, on three docked windows focused by real clicks
# and by commands, its flash, where it sits in the window server's stack (also after a click into the window that
# already has it), gone while a window, a seam and an edge are dragged, gone when the desktop is clicked.
# Session 2, no gap: the ring inside the window, in a colour of its own; a window inside a tile has none;
# then other settings applied with reload-settings, a light wallpaper, and Mission Control.
source "$(dirname "$0")/lib.sh"

# The panel reaches beyond the line's outer edge by the flash, twice the line's width.
# ring_around <window> [line width] [how far the line's outer edge is outside the window]
ring_around() {
  local width=${2:-3} x y w h margin
  local outset=${3:-$width}
  read -r x y w h <<< "$(real_frame_of "$1")"
  margin=$((outset + 2 * width))
  overlays | awk -v x="$((x - margin))" -v y="$((y - margin))" -v w="$((w + 2 * margin))" -v h="$((h + 2 * margin))" \
    '$3 == 0 && $8 == "on" && $4 == x && $5 == y && $6 == w && $7 == h { found = 1 } END { exit !found }'
}

# Seams are a gap wide and this script looks for "no ring" only while there are no tiles.
rings() { overlays | awk '$3 == 0 && $8 == "on" && $6 > 60 && $7 > 60'; }
no_ring() { [ -z "$(rings)" ]; }

# The normal level from front to back: id, owner, frame.
stack() { pointer windows --on-screen | awk '$3 == 0 { print "  " $1, $9, $4, $5, $6, $7 }'; }

# Whether the ring is the window directly in front of <window>.
ring_directly_above() {
  local ring
  ring=$(rings | awk '{ print $1; exit }')
  [ -n "$ring" ] || return 1
  pointer windows --on-screen | awk -v ring="$ring" -v window="$1" \
    '$3 == 0 { if ($1 == window) { ok = (previous == ring); exit } previous = $1 } END { exit !ok }'
}

not() { ! "$@"; }

# The ring is around the window Arbor says has the keyboard; there is none if that window is minimized or nothing has it.
ring_matches_focus() {
  local focused
  focused=$(state | python3 -c 'import json, sys; print(json.load(sys.stdin).get("focused") or "")')
  if [ -n "$focused" ] && ! is minimized "$focused"; then ring_around "$focused"; else no_ring; fi
}

arbor_build

# The runners have "Reduce motion" on, and then the ring does not flash. Declines on a person's Mac: it is their setting.
macos_reduce_motion off

# The ring is an option: Arbor ships without it (collab/QUESTIONS.md, Q29). Every file of settings below says whether it is on.
step "session 1: the ring on, everything else as it ships"
arbor_settings '{"focusRing": true}'
arbor_start 3
read -r sx sy sw sh <<< "$(arbor_ask screen)"
summary
shot 01-start
echo "rings: $(rings)"

step "nothing is docked yet: no ring"
# shellcheck disable=SC2046
click $(center_of "$W3")
check "the click focused the window" eventually is focused "$W3"
sleep 0.5
check "there is no ring while nothing is docked" no_ring
shot 02-nothing-docked

step "dock a window, then click a floating one"
ctl dock "$W1" left
check "the ring is around the window docked by command" eventually ring_around "$W1"
# shellcheck disable=SC2046
click $(center_of "$W3")
check "the click focused the window" eventually is focused "$W3"
check "the ring is around the floating window" eventually ring_around "$W3"
shot 02-floating
overlays
stack

step "dock the other two; each dock command moves the keyboard"
ctl dock "$W2" right
check "the ring is around the second" eventually ring_around "$W2"
ctl dock "$W3" beside "$W2" bottom &
film 03-dock-flash 5
wait $!
check "the ring is around the third" eventually ring_around "$W3"
shot 04-docked
summary
overlays
stack
check "the ring is directly above its window" ring_directly_above "$W3"

step "focus each by a real click"
# shellcheck disable=SC2046
click $(center_of "$W1")
check "the ring follows the click to the first window" eventually ring_around "$W1"
check "the ring is directly above its window" eventually ring_directly_above "$W1"
shot 05-click-first
# shellcheck disable=SC2046
click $(center_of "$W2")
check "the ring follows the click to the second window" eventually ring_around "$W2"
check "the ring is directly above its window" eventually ring_directly_above "$W2"
shot 06-click-second
stack

step "click into the window that already has the ring, and on its title bar"
# shellcheck disable=SC2046
click $(center_of "$W2")
sleep 0.3
stack
check "the ring is still directly above its window after a click into it" ring_directly_above "$W2"
# shellcheck disable=SC2046
click $(titlebar_of "$W2")
sleep 0.3
check "and after a click on its title bar" ring_directly_above "$W2"
shot 07-click-again

step "zoom by command, with the flash, and back"
ctl zoom "$W1" &
film 08-zoom-flash 5
wait $!
check "the ring is around the zoomed window" eventually ring_around "$W1"
shot 09-zoomed
ctl back
check "the ring is around the same window after going back" eventually ring_around "$W1"
shot 10-back

step "drag the focused window by its title bar"
# High enough that the window, which gets its own size back when it is dropped (F48), ends clear of the bottom of the
# screen: at an edge of the visible frame the ring stays inside it, and `ring_around` expects it all round the window.
# shellcheck disable=SC2046
drag $(titlebar_of "$W1") "$((sx + sw / 2))" "$((sy + sh / 3))" --no-release
check "no ring while the window is dragged" no_ring
shot 11-drag-held
release
check "the ring is back around the dropped window" eventually ring_around "$W1"
shot 12-drag-released
summary
ctl dock "$W1" left
check "the ring is around it when it is docked again" eventually ring_around "$W1"

step "drag the seam beside the focused window"
read -r seam_x seam_y <<< "$(seam_right_of "$W1")"
drag "$seam_x" "$seam_y" "$((seam_x + 70))" "$seam_y" --no-release
check "no ring while the seam is dragged" no_ring
shot 13-seam-held
release
check "the ring is back after the seam drag" eventually ring_around "$W1"
shot 14-seam-released

step "drag the focused window's own edge"
read -r x y w h <<< "$(frame_of "$W1")"
drag "$((x + w - 1))" "$((y + h / 2))" "$((x + w - 51))" "$((y + h / 2))" --no-release
check "no ring while the edge is dragged" no_ring
shot 15-edge-held
release
check "the ring is back after the edge drag" eventually ring_around "$W1"
shot 16-edge-released

step "click the desktop, then a window: another app comes to the front and goes again"
# By default a click on the wallpaper sweeps every window aside and the next click only brings them back.
macos_click_wallpaper off
# It declines on a person's Mac. There the click would throw their windows aside too, and prove nothing about the ring.
if [ "$(defaults read com.apple.WindowManager EnableStandardClickToShowDesktop 2>/dev/null)" = 0 ]; then
  read -r dx dy dw dh <<< "$(arbor_ask desktop)"
  click "$((dx + dw / 2))" "$((dy + dh / 2))"
  check "no ring when the desktop has the keyboard" eventually no_ring
  shot 17-desktop-clicked
  # shellcheck disable=SC2046
  click $(center_of "$W1")
  check "the ring is back with the window's app" eventually ring_around "$W1"
  check "the ring is directly above its window" eventually ring_directly_above "$W1"
  shot 17b-window-clicked
else
  echo "skipped: a click on the wallpaper would sweep every window on this Mac aside"
fi

step "minimize the focused window with its yellow button"
read -r x y w h <<< "$(frame_of "$W1")"
click "$((x + 39))" "$((y + 16))"
check "the window is minimized" eventually is minimized "$W1"
sleep 1
summary
echo "rings: $(rings)"
check "the ring is around whichever window has the keyboard now, or gone" eventually ring_matches_focus
shot 18-minimized
# `arbor_stop` expects every window on screen afterwards, and quitting takes nothing out of the Dock.
echo "restore $W1" >&9
check "the window is back from the Dock" eventually not is minimized "$W1"
check "the ring is around whichever window has the keyboard after that" eventually ring_matches_focus
arbor_stop 19-after-quit

# Without `makeRoom` (F61), which would move the gaps until the third window fits: this session wants it in a tile.
step "session 2: no gap, a thicker yellow line; the third window cannot shrink"
ARBOR_TEST_WINDOWS_ARGS="--min-size 3:700x500"
arbor_settings "{\"focusRing\": true, \"makeRoom\": false, \"gap\": 0, \"focusRingWidth\": 4, \"focusRingColour\": \"#FFCC00\", $ARBOR_TILES_ON}"
arbor_start 3
ctl dock "$W1" left
ctl dock "$W2" right
check "without a gap the ring is inside the window" eventually ring_around "$W2" 4 0
shot 20-no-gap
# shellcheck disable=SC2046
click $(center_of "$W1")
check "it follows a click" eventually ring_around "$W1" 4 0
check "it is directly above its window, or it could not be seen" eventually ring_directly_above "$W1"
# shellcheck disable=SC2046
click $(center_of "$W1")
sleep 0.3
check "it is still directly above its window after another click" ring_directly_above "$W1"
shot 21-no-gap-clicked
stack

step "a window inside a tile has no ring"
ctl dock "$W3" beside "$W2" bottom
sleep 0.5
ctl show-all
check "the window that cannot shrink is a tile" eventually is tile "$W3"
summary
overlays
shot 22-tile
check "there is no ring around the tiled window" not ring_around "$W3" 4 0

step "other settings, applied with reload-settings"
arbor_settings '{"focusRing": true, "makeRoom": false, "gap": 24, "focusRingWidth": 8, "focusRingColour": "#FF2D55CC"}'
ctl reload-settings
ctl zoom "$W1"
ctl back
check "a thick line in a wide gap" eventually ring_around "$W1" 8
shot 23-thick
arbor_settings '{"focusRing": true, "makeRoom": false, "gap": 12, "focusRingWidth": 1}'
ctl reload-settings
check "a hairline" eventually ring_around "$W1" 1
shot 24-hairline
arbor_settings '{"focusRing": true, "makeRoom": false, "gap": 12, "focusRingColour": "mauve"}'
ctl reload-settings
check "an unknown colour is reported in the log" grep -q "focusRingColour" "$ARBOR_HOME/arbor.log"
arbor_settings '{"makeRoom": false, "gap": 12, "focusRing": false}'
ctl reload-settings
check "switched off" eventually not ring_around "$W1"
shot 25-off
arbor_settings '{"focusRing": true, "makeRoom": false, "gap": 12}'
ctl reload-settings
check "switched on again" eventually ring_around "$W1"

step "on a light wallpaper"
picture="/System/Library/Desktop Pictures/Solid Colors/Silver.png"
ls "/System/Library/Desktop Pictures/Solid Colors" 2>/dev/null | head -n 30 | tr '\n' ' '
echo
if [ -f "$picture" ] && wallpaper "$picture"; then
  shot 26-light-wallpaper
  # shellcheck disable=SC2046
  click $(center_of "$W2")
  shot 27-light-wallpaper-second
fi

step "Mission Control"
if on_throwaway_mac; then
  open -a "Mission Control"
  sleep 1.5
  shot 28-mission-control
  key escape
  sleep 1
  shot 29-after-mission-control
fi

arbor_stop
ls -l "$ARBOR_OUT" | awk '{ print $5, $9 }'
