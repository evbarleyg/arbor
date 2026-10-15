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
# background. To the side of a docked window, and to the bottom edge of the screen. Then the two that lie behind with ⌘, held from before the press or going
# down on the way. What Arbor made of each press is printed, from arbor.log, which comes back, as the trace does.
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
  said_of_the_press
  summary
  ctl float "$id"
  sleep 0.5
}

# What the Accessibility layer found the press to be on, and where the pointer was by the time it looked.
said_of_the_press() { arbor_log_since "$ARBOR_STEP_MARK" | grep "the button went down at" | tail -1 | sed 's/^.*DEBUG /    (/; s/$/)/' || true; }

# carried <id> <words> [--mods cmd | late]: 300 points over the Desktop and back to where nothing covers it. Only whether Arbor sees a drag.
carried() {
  local id=$1 words=$2 how=${3:-} tx ty
  take "tx ty" titlebar_of "$id"
  case "$how" in
    late)
      drag "$tx" "$ty" "$((tx - 40))" "$((ty + 30))" --steps 5 --duration 0.2 --no-release
      release "$((tx - 240))" "$((ty + 180))" --mods cmd ;;
    cmd) drag "$tx" "$ty" "$((tx - 240))" "$((ty + 180))" --steps 24 --duration 0.7 --mods cmd ;;
  esac
  [ -n "${ARBOR_REHEARSAL:-}" ] || check "$words: Arbor sees a drag" eventually logged "$id is being dragged"
  said_of_the_press
  is docked "$id" && ctl float "$id"
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

for id in "$W3" "$V1"; do
  if [ "$id" = "$W3" ]; then whose="another window of the app in front"; else whose="a window of an app in the background"; fi
  claim "$whose is dragged with ⌘ held from before the press: macOS does not bring it forward"
  click_window "$W1"
  check "the docked window has the keyboard" eventually is focused "$W1"
  carried "$id" "⌘ from the first" cmd
  places

  claim "$whose is dragged, and ⌘ goes down on the way"
  click_window "$W1"
  check "the docked window has the keyboard" eventually is focused "$W1"
  carried "$id" "⌘ on the way" late
  places
done
arbor_stop
