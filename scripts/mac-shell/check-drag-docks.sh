#!/bin/bash
# A plain drag only moves a window; ⌘ held during the drag docks (`dragDocks`; QUESTIONS Q29, 3). What e2e-drag.sh does not ask:
#
#   scripts/mac-shell/run.sh scripts/mac-shell/check-drag-docks.sh
#
# The windows of e2e-drag.sh are one app's, and the one that is dragged is mostly in front. Here a second app has a window, so that a
# press can land on a window whose app is in the background:
#   1. dragged plainly, such a window is seen as dragged, and a docked one comes out;
#   2. with ⌘ down from BEFORE the press macOS moves it without bringing it forward (macOS's own meaning of a ⌘-drag): does Arbor
#      see the drag, does it dock, and what lies in front afterwards;
#   3. with ⌘ down from before the press on the window in front;
#   4. key and button let go together: the key first by a hair, and the button first;
#   5. `always` and `never`.
# All at macOS's settings as the Mac has them, with no event tap (`pointerGestures` as it ships).
source "$(dirname "$0")/lib.sh"

arbor_build
ARBOR_SECOND_APP=1
arbor_start 2
OTHER=$V1
read -r sx sy sw sh <<< "$(arbor_ask screen)"
# Side by side, so that a title bar can be pressed whichever window is in front.
tw move "$W1" $((sx + 30)) $((sy + 40)) 400 260
tw move "$W2" $((sx + 30)) $((sy + 330)) 400 260
tw2 move "$OTHER" $((sx + 520)) $((sy + 80)) 420 300
sleep 1
summary

not() { ! "$@"; }
unmoved() { [ "$(real_frame_of "$1")" = "$2" ]; }
middle() { echo "$((sx + sw * 3 / 5)) $((sy + sh / 3))"; }
# The bottom edge is Arbor's at every setting of macOS's tiling (Q23).
bottom() { echo "$((sx + sw / 2)) $((sy + sh - 3))"; }

claim "a window of an app in the background, dragged plainly, is seen as dragged and floats where it is let go"
click_window "$W1"
check "another app's window has the keyboard" eventually is focused "$W1"
start=$(real_frame_of "$OTHER")
# shellcheck disable=SC2046
drag $(titlebar_of "$OTHER") $(bottom) --plain --hold 0.6 --no-release
check "the window is in the hand" not unmoved "$OTHER" "$start"
check "Arbor knows that it is dragged" logged "drag of w$OTHER"
check "no preview" not has_overlay 3
held=$(real_frame_of "$OTHER")
release
sleep 1
check "it floats" is floating "$OTHER"
check "where it was let go" arbor_close "$(real_frame_of "$OTHER")" "$held"
# shellcheck disable=SC2046
drag_window "$OTHER" $(middle) --plain

claim "docked, in the background and dragged plainly, it comes out"
own=$(real_frame_of "$OTHER" | awk '{ print int($3 + 0.5), int($4 + 0.5) }')
ctl dock "$OTHER" left
ctl dock "$W2" right
check "docked" eventually is docked "$OTHER"
click_window "$W1"
check "another app's window has the keyboard" eventually is focused "$W1"
# shellcheck disable=SC2046
drag $(titlebar_of "$OTHER") $(middle) --plain --hold 0.6
check "it floats" eventually is floating "$OTHER"
check "and stays out" stays is floating "$OTHER"
check "at the size it had before it was docked" eventually [ "$(real_frame_of "$OTHER" | awk '{ print int($3 + 0.5), int($4 + 0.5) }')" = "$own" ]
check "the other docked window is in its slot" eventually is in_slot "$W2"
summary

claim "⌘ down from before the press, on a window of an app in the background: it docks"
click_window "$W1"
check "another app's window has the keyboard" eventually is focused "$W1"
start=$(real_frame_of "$OTHER")
# shellcheck disable=SC2046
drag $(titlebar_of "$OTHER") $(bottom) --mods cmd --hold 0.6 --no-release
check "the window is in the hand" not unmoved "$OTHER" "$start"
check "Arbor knows that it is dragged" logged "drag of w$OTHER"
check "a preview shows" has_overlay 3
release --mods cmd
check "it docks" eventually is docked "$OTHER"
check "in its slot" eventually is in_slot "$OTHER"
echo "who has the keyboard afterwards: $(arbor_ask json | python3 -c 'import json, sys; print(json.load(sys.stdin).get("focused"))')"
echo "front to back:"
pointer windows --on-screen | awk '$3 == 0' | head -6
summary

claim "⌘ down from before the press, on the window in front: it docks"
ctl float "$OTHER"
# shellcheck disable=SC2046
drag_window "$W1" $(middle) --plain
# shellcheck disable=SC2046
drag $(titlebar_of "$W1") $(bottom) --mods cmd --hold 0.6 --no-release
check "a preview shows" has_overlay 3
release --mods cmd
check "it docks" eventually is docked "$W1"
ctl float "$W1"

claim "the key comes up a hair before the button: nothing docks, and nothing else moves"
# shellcheck disable=SC2046
drag_window "$W1" $(middle) --plain
others="$(real_frame_of "$W2") $(real_frame_of "$OTHER")"
# shellcheck disable=SC2046
drag $(titlebar_of "$W1") $(bottom) --hold 0.6 --no-release
check "a preview shows" has_overlay 3
key cmd --up
release
sleep 1
check "it floats" is floating "$W1"
check "no preview is left" not has_overlay 3
check "the others are where they were" [ "$(real_frame_of "$W2") $(real_frame_of "$OTHER")" = "$others" ]

claim "the button comes up first: it docks"
# shellcheck disable=SC2046
drag_window "$W1" $(middle) --plain
# shellcheck disable=SC2046
drag $(titlebar_of "$W1") $(bottom) --hold 0.6
check "it docks" eventually is docked "$W1"
ctl float "$W1"

claim "dragDocks always: a plain drag docks, and ⌘ turns that off"
ctl set dragDocks always
# shellcheck disable=SC2046
drag_window "$W1" $(middle) --mods cmd
check "with ⌘ it floats" is floating "$W1"
# shellcheck disable=SC2046
drag $(titlebar_of "$W1") $(bottom) --plain --hold 0.6 --no-release
check "a preview shows with nothing held" has_overlay 3
release
check "it docks" eventually is docked "$W1"
ctl float "$W1"

claim "dragDocks never: no drag docks"
ctl set dragDocks never
# shellcheck disable=SC2046
drag_window "$W1" $(middle) --plain
# shellcheck disable=SC2046
drag $(titlebar_of "$W1") $(bottom) --mods cmd --hold 0.6 --no-release
check "no preview with ⌘" not has_overlay 3
release --mods cmd
sleep 1
check "it floats" is floating "$W1"
# shellcheck disable=SC2046
drag_window "$W1" $(middle) --plain
ctl set dragDocks held

arbor_stop
