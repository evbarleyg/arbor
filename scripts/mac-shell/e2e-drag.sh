#!/bin/bash
# Real drags on real windows (F17, H4): `make e2e-drag`, and a step of CI's real-window job.
#
# arbor-e2e drives Arbor with commands. What a person does with the mouse takes another road into Arbor: the window
# server moves the window, Arbor's event monitor sees the button and the pointer, and the Accessibility layer has to
# work out from the window's frame whether this is a drag, an edge resize or neither. This script walks that road with
# the scripted pointer the Mac shell sessions use (lib.sh, pointer.swift), on three test windows of its own.
#
# Needs Accessibility for the terminal it runs from. Exit code 0: every check passed; 1: one failed; 2: no session.
source "$(dirname "$0")/lib.sh"

echo "This takes over the real pointer for about half a minute. Hands off the mouse until it says it is done."
arbor_build
arbor_start 3
read -r sx sy sw sh <<< "$(arbor_ask screen)"
summary

# same_frame <window> <x y w h>: whether Arbor's layout and the window server both have the window there, give or take 3.
same_frame() {
  local id=$1 kind now
  shift
  for kind in slot real; do
    if [ "$kind" = slot ]; then now=$(arbor_ask slot "$id") || return 1; else now=$(real_frame_of "$id"); fi
    python3 -c 'import sys; a = sys.argv[1].split(); b = sys.argv[2:6]
sys.exit(0 if all(abs(float(x) - float(y)) <= 3 for x, y in zip(a, b)) else 1)' "$now" "$@" || return 1
  done
}

not() { ! "$@"; }

# within <number> <low> <high>
within() { [ "$1" -ge "$2" ] && [ "$1" -le "$3" ]; }

step "drag a window by its title bar to the left screen edge"
# shellcheck disable=SC2046
drag $(titlebar_of "$W3") $((sx + 3)) $((sy + sh / 2)) --no-release
check "a drop preview shows while the button is held" has_overlay 3
release
check "the window docks on release" eventually is docked "$W3"
check "no preview is left behind" eventually not has_overlay 3
read -r x3 y3 w3 h3 <<< "$(arbor_ask slot "$W3")"
check "it sits at the left edge" [ "$x3" -le $((sx + 30)) ]
summary

step "drag the right edge of the docked window 60 points to the right"
read -r dx dy dw dh <<< "$(arbor_ask desktop)"
drag $((x3 + w3 - 1)) $((y3 + h3 / 2)) $((x3 + w3 + 59)) $((y3 + h3 / 2))
check "the window is 60 points wider" eventually same_frame "$W3" "$x3" "$y3" $((w3 + 60)) "$h3"
read -r dx2 dy2 dw2 dh2 <<< "$(arbor_ask desktop)"
check "the Desktop gave up the space" within "$dw2" $((dw - 63)) $((dw - 57))
read -r x3 y3 w3 h3 <<< "$(arbor_ask slot "$W3")"
summary

step "drag another window onto the right part of the docked one"
# shellcheck disable=SC2046
drag $(titlebar_of "$W2") $((x3 + w3 * 85 / 100)) $((y3 + h3 / 2))
check "it docks" eventually is docked "$W2"
read -r x3 y3 w3 h3 <<< "$(arbor_ask slot "$W3")"
read -r x2 y2 w2 h2 <<< "$(arbor_ask slot "$W2")"
check "to the right of the first" [ "$x2" -ge $((x3 + w3)) ]
summary

step "double-click the title bar of a docked window (H5)"
# shellcheck disable=SC2046
dblclick $(titlebar_of "$W3")
sleep 1.5
check "the window is in its slot" eventually same_frame "$W3" "$x3" "$y3" "$w3" "$h3"
check "no seam moved" eventually same_frame "$W2" "$x2" "$y2" "$w2" "$h2"

step "press inside a docked window and move the pointer"
drag $((x3 + w3 / 2)) $((y3 + h3 / 2)) $((x3 + w3 / 2 + 90)) $((y3 + h3 / 2 + 60)) --no-release
check "that is not a drag: no preview" not has_overlay 3
release
check "the window is in its slot" eventually same_frame "$W3" "$x3" "$y3" "$w3" "$h3"

step "drag a docked window out onto the Desktop"
read -r dx dy dw dh <<< "$(arbor_ask desktop)"
# Near the top of the Desktop: the pointer holds the title bar, and a window as tall as its slot let go of half way down
# would hang off the bottom of the display, where "back on screen" at the end does not find enough of it.
# shellcheck disable=SC2046
drag $(titlebar_of "$W2") $((dx + dw / 2)) $((dy + 60))
check "it floats" eventually is floating "$W2"
check "the first window is still docked" is docked "$W3"
summary

arbor_stop
echo "Done: the pointer is yours again."
