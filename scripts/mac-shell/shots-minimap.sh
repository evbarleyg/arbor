#!/bin/bash
# The minimap (docs/features/F26-minimap.md) on a real Mac, in pictures and checks. Nobody has seen it yet: look at every picture.
#
#   scripts/mac-shell/run.sh scripts/mac-shell/shots-minimap.sh
#
# What to judge in the pictures: is the panel near the bottom centre, clear of the Dock? Are its corners round and its background a
# blur, not a grey box? Can the windows be told apart, and the ones out of view from the ones in view? Is the accent frame where the
# view is, and does it leave a small window's colour visible? Is the caption readable, in the light look and the dark one? Does
# the panel fade, and is it gone afterwards? Does it sit above a framed window?
#
# Session 1, `minimapDuration` 3 so that there is time for pictures: where it sits, what it marks, the caption, that a click goes
# through it, that it goes by itself; then ⌃⌥M with real keys and real clicks in the map, tapped and held.
# Sessions 2 and 3: the light and the dark look. Session 4: the fades at 0.9 s. Session 5: as it ships, nothing by itself, and quitting
# while it shows.
#
# Safe on a person's Mac: it touches only its own test windows and temporary files, moves the pointer and presses ⌃⌥M. The one
# system setting it would change (Reduce Motion) is left alone anywhere but on GitHub's Macs: `macos_reduce_motion` declines.
ARBOR_SHORTCUTS=all  # it presses keys of the whole map, of which nine ship
source "$(dirname "$0")/lib.sh"
source "$(dirname "$0")/lib-person.sh"

# The panel keeps out of shared screens and recordings as far as macOS lets it (`sharingType`), and so out of these pictures, unless told
# otherwise: every arbor_start below says ARBOR_PANELS_IN_PICTURES=1.
# To the window server the floating level is 3; the minimap is two above it (UI/MinimapPanel.swift).
minimap_level=5
minimap_frame() { overlays | awk -v level="$minimap_level" '$3 == level && $8 == "on" { print $4, $5, $6, $7; exit }'; }
minimap_up() { has_overlay "$minimap_level"; }
minimap_gone() { ! has_overlay "$minimap_level"; }
not() { ! "$@"; }
within() { [ "$1" -ge "$((0 - $2))" ] && [ "$1" -le "$2" ]; }
# On a person's Mac the harness declines keys and presses it cannot answer for. Left alone the minimap goes by itself, so where the next
# check is that it has gone, a declined one would pass for one that worked.
declined() { check "the harness let it through: $1" false; }

# Where things are in the map of [W1 / W3 | W2], two columns of one width: the map is the panel less 10 points all round, and a
# caption adds its line at the top, so everything is measured from the panel's bottom edge. `left` is W3 until that floats. `middle` is the
# Desktop's where it has room between them, which a `layout` line that names it gives it, and the border of the two where it has none.
in_map() {
  local mx my mw mh
  read -r mx my mw mh <<< "$(minimap_frame)"
  # With no panel up, arithmetic would make a place of nothing, and the press would go there.
  [ -n "$mh" ] || return 1
  case "$1" in
    left) echo "$((mx + 30)) $((my + mh - 60))" ;;
    middle) echo "$((mx + mw / 2)) $((my + mh - 60))" ;;
    right) echo "$((mx + mw - 30)) $((my + mh - 60))" ;;
    # In the padding, away from the rounded corners, where the panel is not.
    beside) echo "$((mx + mw / 2)) $((my + mh - 3))" ;;
  esac
}

arrange() {
  ctl dock "$W1" left
  ctl dock "$W2" right
  ctl dock "$W3" beside "$W1" bottom
}

arbor_build

# The runners have "Reduce motion" on, and then nothing fades. Declines on a person's Mac: it is their setting.
macos_reduce_motion off

step "session 1: an arrangement worth a map: two columns, one of them split"
arbor_settings '{"minimapDuration": 3}'
# As a person starts it: this is the session in which the keys are held (lib-person.sh).
arbor_start_as_a_person 4 ARBOR_NO_HOTKEYS=0 ARBOR_PANELS_IN_PICTURES=1
read -r sx sy sw sh <<< "$(arbor_ask screen)"
arrange
check "docking from the widest view brings no minimap up" minimap_gone

step "frame a window"
ctl zoom "$W1"
check "the minimap is on screen" eventually minimap_up
shot_after 0.4 01-framed
echo "the panel, as the window server sees it: $(minimap_frame); the display's usable area: $sx $sy $sw $sh"
overlays
read -r mx my mw mh <<< "$(minimap_frame)"
check "it is centred" within "$((mx + mw / 2 - sx - sw / 2))" 1
check "its bottom edge is 56 points above the bottom of the usable area" test "$((sy + sh - my - mh))" -eq 56
check "it is at most 240 by 160" test "$mw" -le 240 -a "$mh" -le 160

step "a click where it is goes through to the window below"
# shellcheck disable=SC2046
click $(in_map right)
sleep 0.5
check "the view has not moved" not is parked "$W1"
check "the window on the right is still out of view" is parked "$W2"
check "the framed window has the keyboard" is focused "$W1"

step "a group, the Desktop; not everything"
ctl out
shot_after 0.4 02-group
ctl desktop
shot_after 0.4 03-desktop
ctl show-all
check "none when the view goes to everything" eventually minimap_gone

step "a saved view has a caption, and the map does not jump"
ctl zoom "$W2"
read -r _ plain_y _ plain_h <<< "$(minimap_frame)"
ctl save-view 3
ctl show-all
ctl view 3
shot_after 0.4 05-caption
read -r _ caption_y _ caption_h <<< "$(minimap_frame)"
check "the panel is a line taller" test "$((caption_h - plain_h))" -eq 18
check "and its bottom edge has stayed" test "$((caption_y + caption_h))" -eq "$((plain_y + plain_h))"

step "it goes by itself"
sleep 3.5
check "gone after its time" minimap_gone
shot 06-gone

step "the framed window leaves the arrangement, and the view goes to everything: none"
ctl zoom "$W3"
check "up" eventually minimap_up
ctl float "$W3"
check "the one that was up goes with the view it marked" eventually minimap_gone
sleep 1
check "and none comes" minimap_gone

step "on demand, with real keys: ⌃⌥M"
ctl zoom "$W1"
sleep 3.5
# shellcheck disable=SC2046
click $(center_of "$W1")
key ctrl+opt+m
check "the keys bring it up" eventually minimap_up
shot_after 0.4 08-on-demand
# shellcheck disable=SC2046
click $(in_map right)
check "a click on the window at the right frames it" eventually not is parked "$W2"
check "the window that was framed is out of view" eventually is parked "$W1"
check "the clicked window has the keyboard" eventually is focused "$W2"
shot_after 0.3 09-after-the-click
sleep 3.5
check "then it goes like any other" minimap_gone

step "⌃⌥M again puts it away; so does a click beside the map"
key ctrl+opt+m
check "up" eventually minimap_up
key ctrl+opt+m || declined "⌃⌥M"
check "away" eventually minimap_gone
key ctrl+opt+m
check "up" eventually minimap_up
# shellcheck disable=SC2046
click $(in_map beside) || declined "the click beside the map"
check "away" eventually minimap_gone
check "and the view has not moved" not is parked "$W2"

step "and back to the window at the left"
sleep 3.5
key ctrl+opt+m
check "up" eventually minimap_up
# shellcheck disable=SC2046
click $(in_map left)
check "it is framed" eventually not is parked "$W1"
check "and has the keyboard" eventually is focused "$W1"

step "held, like ⌃⌥Space: hold to look, let go to land"
sleep 3.5
# shellcheck disable=SC2046
click $(center_of "$W1")
key ctrl+opt+m --down
check "the keys bring it up" eventually minimap_up
sleep 6
check "it outlasts its five seconds while they are down" minimap_up
# shellcheck disable=SC2046
move $(in_map right)
shot_after 0.3 09b-held-outline-under-the-pointer
key ctrl+opt+m --up
check "letting go frames the window the pointer is over" eventually not is parked "$W2"
check "the window that was framed is out of view" eventually is parked "$W1"
check "the landing has the keyboard" eventually is focused "$W2"

step "held and let go with the pointer over nothing"
sleep 3.5
# shellcheck disable=SC2046
move $(center_of "$W2")
key ctrl+opt+m --down
check "up" eventually minimap_up
sleep 1
key ctrl+opt+m --up
check "away" eventually minimap_gone
check "and the view has not moved" not is parked "$W2"

step "⎋ while holding gives up, and pauses nothing"
key ctrl+opt+m --down
check "up" eventually minimap_up
sleep 1
key ctrl+opt+escape --held || declined "⎋"
check "away" eventually minimap_gone
check "Arbor is not paused: what is out of view stays there" is parked "$W1"
key ctrl+opt+m --up

step "its time does not run out under the pointer"
key ctrl+opt+m
check "up" eventually minimap_up
# shellcheck disable=SC2046
move $(in_map middle)
sleep 7
check "still up after seven seconds" minimap_up
# shellcheck disable=SC2046
move $(center_of "$W2")
sleep 6
check "gone six seconds after the pointer left" minimap_gone

step "⌃⌥ let go first"
key ctrl+opt+m --down
check "up" eventually minimap_up
sleep 1
key ctrl+opt --up
check "that is letting go too" eventually minimap_gone
key m --up
key ctrl+opt+m
check "and the keys still work" eventually minimap_up
key ctrl+opt+m || declined "⌃⌥M"
check "both ways" eventually minimap_gone

step "left alone, it goes after five seconds"
sleep 3.5
ctl minimap
sleep 3
check "still up after three" minimap_up
sleep 2.5
check "gone after five and a half" minimap_gone
arbor_stop

# Two docks are two halves, and a Desktop without room has no outline in the map. A line that names it gives it room, with no switch; so has whoever
# comes from the first build with its arrangement.
step "the Desktop has room, by a layout line: its outline can be clicked too"
arbor_settings '{"minimapDuration": 3}'
arbor_start 4 ARBOR_NO_HOTKEYS=0 ARBOR_PANELS_IN_PICTURES=1
ctl layout "($W1 / $W3) | Desktop | $W2"
ctl zoom "$W2"
check "framed on the window at the right: the floating window is out of view" eventually is parked "$W4"
sleep 3.5
key ctrl+opt+m
check "up" eventually minimap_up
# shellcheck disable=SC2046
click $(in_map middle)
check "the floating window is back in view" eventually not is parked "$W4"
check "the docked ones are out of view" eventually is parked "$W2"
arbor_stop

for look in light dark; do
  step "the $look look"
  arbor_settings '{"minimapDuration": 3}'
  arbor_start 4 "ARBOR_APPEARANCE=$look" ARBOR_PANELS_IN_PICTURES=1
  arrange
  ctl zoom "$W3"
  ctl save-view 1
  ctl show-all
  ctl view 1
  shot_after 0.4 "10-$look"
  arbor_stop
done

step "the fades, at 0.9 s"
arbor_settings '{"minimapDuration": 0.9}'
arbor_start 3 ARBOR_PANELS_IN_PICTURES=1
ctl dock "$W1" left
ctl dock "$W2" right
ctl zoom "$W1" &
film 11-fade 20
check "gone again" eventually minimap_gone
arbor_stop

step "as it ships: nothing by itself"
arbor_settings '{}'
arbor_start 2 ARBOR_PANELS_IN_PICTURES=1
ctl dock "$W1" left
ctl zoom "$W1"
sleep 0.3
check "no minimap after a move of the view" minimap_gone

step "quitting while it shows"
ctl minimap
check "the command still shows it" eventually minimap_up
arbor_stop 12-after-quit
