#!/bin/bash
# A window that has not got the keyboard is taken by its title bar and dragged, without a click on it first.
#
#   scripts/mac-shell/run.sh scripts/mac-shell/check-drag-from-behind.sh
#
# That is how a person does it: the press that takes hold of the window is also the one that brings it forward, and its app with it. On a
# real Mac (macOS 26, as it comes, 2026-10-15) such a drag was not seen as a drag at all: no preview, nothing docked; the window in front
# docked fine. The press, the report that another app came forward and the report of the focus reach Arbor within a millisecond, and
# what Arbor then asks the app keeps its main thread while the hand goes on.
#
# Each drag is played three times over: the window in front (the control), another window of the app in front, a window of an app in the
# background. To the side of a docked window, and to the bottom edge of the screen. What Arbor made of each is in arbor.log, which comes back, and in
# the trace.
source "$(dirname "$0")/lib.sh"

# dragged <id> <words> <x> <y>: by the title bar as it lies, whoever has the keyboard.
dragged() {
  local id=$1 words=$2 x=$3 y=$4 tx ty
  take "tx ty" titlebar_of "$id"
  drag "$tx" "$ty" "$x" "$y" --steps 24 --duration 0.7 --no-release
  # The line is the real Accessibility layer's, which a rehearsal has not got.
  [ -n "${ARBOR_REHEARSAL:-}" ] || check "$words: Arbor sees a drag" eventually logged "$id is being dragged"
  check "$words: a preview shows where it would go" eventually has_overlay 3
  shot "preview-$id"
  release
  check "$words: let go, it is docked" eventually is docked "$id"
  if logged "the press is served late" > /dev/null 2>&1; then echo "    (the press was served late, with the window in the hand)"; fi
  summary
  ctl float "$id"
  sleep 0.5
}

# places: the floating windows side by side on the Desktop's part, where nothing covers their title bars.
places() {
  local dx dy dw dh
  take "dx dy dw dh" arbor_ask desktop
  tw move "$W2" "$dx" "$((dy + 20))" "$((dw / 3 - 8))" 220
  tw move "$W3" "$((dx + dw / 3))" "$((dy + 20))" "$((dw / 3 - 8))" 220
  tw2 move "$V1" "$((dx + 2 * dw / 3))" "$((dy + 20))" "$((dw / 3 - 8))" 220
  sleep 1
}

arbor_build
ARBOR_SECOND_APP=1
arbor_start 3
ctl dock "$W1" left
sleep 1
places
summary

for target in side bottom; do
  if [ "$target" = side ]; then where="onto the side of a docked window"; else where="to the bottom edge of the screen"; fi
  point() { if [ "$target" = side ]; then zone_of "$W1" right; else edge_point bottom; fi; }

  claim "the window in front is dragged $where"
  click_window "$W2"
  check "it has the keyboard" eventually is focused "$W2"
  take "x y" point
  dragged "$W2" "in front" "$x" "$y"
  places

  claim "another window of the app in front is dragged $where, without a click first"
  click_window "$W1"
  check "the docked window has the keyboard" eventually is focused "$W1"
  take "x y" point
  dragged "$W3" "of the same app" "$x" "$y"
  places

  claim "a window of an app in the background is dragged $where, without a click first"
  click_window "$W1"
  check "the docked window has the keyboard" eventually is focused "$W1"
  take "x y" point
  dragged "$V1" "of another app" "$x" "$y"
  places
done
arbor_stop
