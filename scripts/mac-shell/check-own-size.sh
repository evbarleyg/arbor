#!/bin/bash
# A window keeps its own size, wherever it is let go and wherever its person had left it.
#
#   scripts/mac-shell/run.sh scripts/mac-shell/check-own-size.sh
#
# Where a window stands, macOS lets it grow no further than to the bottom of the visible frame (less a point above a Dock) and the right edge of
# its display; a move is not held back so. So a window cannot grow into a frame that hangs over such a line once it stands there, and Arbor took
# the room there was for the window's own size: 400×319 for 400×600, for good. Now it is sized where the size fits and then only moved
# (Sources/ArborKit/Controller/Controller+TheScreensAnswer.swift). The rule was measured with bare calls; what only a Mac can say is whether
# Arbor's own calls, through its Accessibility layer, end as the stand-ins say:
#   - a tall window dragged out of a low slot with the real pointer and let go low: its own size? Docked and floated again: still?
#   - left hanging over the bottom, or over the right edge, docked where there is no room for its size, and given back by Float All, a pause and
#     Quit: whole, and where it was?
#   - as high as the visible frame: a point short and no more?
#   - let be at a start, ten points over the right edge: as wide as it stood?
# How it got there is printed from arbor.log after each: how many frames Arbor asked for.
#
# Safe on a person's Mac: it changes no setting, touches only windows it opened, and moves the pointer.
source "$(dirname "$0")/lib.sh"

whole() { awk '{ for (i = 1; i <= NF; i++) printf "%d ", $i + 0.5 }' | sed 's/ $//'; }
now_at() { real_frame_of "$1" | whole; }
# is_at <id> <x y w h>, has_size <id> <w h>: by the window server, to the point.
is_at() { [ "$(now_at "$1")" = "$2" ] || { echo "    it is at $(now_at "$1"), not at $2"; return 1; }; }
has_size() { [ "$(now_at "$1" | cut -d' ' -f3-4)" = "$2" ] || { echo "    it is at $(now_at "$1"), not $2 in size"; return 1; }; }
# What Arbor asked of the window since the claim began.
asked_of() { arbor_log_since "$ARBOR_STEP_MARK" | grep -E "w$1\b.*(frame|size|took|dropped)" | tail -n 8 | sed 's/^.*DEBUG /    (/; s/$/)/' || true; }

# low_slot: W1 on the left, W2 below it, in a slot with no room for W2's own height.
low_slot() {
  ctl dock "$W1" left
  ctl dock "$W2" beside "$W1" bottom
  check "it is docked in the lower slot" eventually is in_slot "$W2"
}
# narrow_slot: W1 on the left, W2 at the right, in a slot with no room for W2's own width.
narrow_slot() {
  ctl dock "$W1" left
  ctl dock "$W2" right
  check "it is docked in the slot at the right" eventually is in_slot "$W2"
}
# left_at <x y w h>: W2 floats there, as its person left it.
left_at() {
  # shellcheck disable=SC2086
  tw move "$W2" $1
  sleep 1.5
  check "it stands where it was put" is_at "$W2" "$1"
}

arbor_build
arbor_start 2
take "sx sy sw sh" screen_of 1
take "fx fy fw fh" display_frame_of 1
bottom=$((sy + sh)) right=$((fx + fw))
echo "the visible frame ends at $bottom, the display at $((fy + fh)); its right edge is at $right"
tall="400 $((sh - 74))"
tw move "$W1" "$((sx + 170))" "$((sy + 70))" 480 348

claim "a tall window dragged out of a low slot and let go low has its own size"
left_at "$((sx + 300)) $((sy + 30)) $tall"
low_slot
take "tx ty" titlebar_of "$W2"
drag "$tx" "$ty" "$((sx + sw * 3 / 4))" "$((ty + 30))" --steps 24 --duration 0.8
check "it floats" eventually is floating "$W2"
check "at its own size" eventually has_size "$W2" "$tall"
check "and stays so" stays has_size "$W2" "$tall"
asked_of "$W2"
shot let-go-low
ctl dock "$W2" right
sleep 1
ctl float "$W2"
check "docked and floated again it is no more than a point short of it" eventually taller_than "$W2" "$((sh - 76))"
ctl float-all > /dev/null
sleep 1

for way in float-all pause quit; do
  claim "left hanging over the bottom, docked in a low slot, given back by $way: whole, where it was"
  hanging="$((sx + 560)) $((bottom - 325)) $tall"
  left_at "$hanging"
  low_slot
  if [ "$way" = quit ]; then arbor_quit; else ctl "$way"; fi
  check "it is where it was left, at its own size" eventually is_at "$W2" "$hanging"
  check "and stays there" stays is_at "$W2" "$hanging"
  [ "$way" = quit ] || asked_of "$W2"
  shot "over-the-bottom-$way"
  case "$way" in
    pause) ctl resume; sleep 1; ctl float-all > /dev/null ;;
    quit) arbor_relaunch; ctl float-all > /dev/null ;;
  esac
  sleep 1

  claim "left hanging over the right edge, docked in a narrow slot, given back by $way: whole, where it was"
  hanging="$((right - 520)) $((sy + 40)) 640 300"
  left_at "$hanging"
  narrow_slot
  if [ "$way" = quit ]; then arbor_quit; else ctl "$way"; fi
  check "it is where it was left, at its own size" eventually is_at "$W2" "$hanging"
  check "and stays there" stays is_at "$W2" "$hanging"
  [ "$way" = quit ] || asked_of "$W2"
  shot "over-the-right-edge-$way"
  case "$way" in
    pause) ctl resume; sleep 1; ctl float-all > /dev/null ;;
    quit) arbor_relaunch; ctl float-all > /dev/null ;;
  esac
  sleep 1
done

claim "as high as the visible frame, it comes back a point short at most"
left_at "$((sx + 300)) $sy 400 $sh"
low_slot
ctl float-all
check "as wide as it was" eventually width_is "$W2" 400
check "no more than a point short" eventually taller_than "$W2" "$((sh - 2))"
asked_of "$W2"
sleep 1

claim "let be at a start, ten points over the right edge, it is as wide as it stood"
# Too wide for whatever the other can spare, so that it would be a tile; with the keyboard in it, it is let be where it stands. (Two docks are two
# halves, with no column for the Desktop, and the neighbour gives down to a tile of 80 points: that leaves the display less 116.)
tw min-size "$W2" "$((fw - 100))" 300
wide="$((fx + 84)) $((sy + 70)) $((fw - 74)) 400"
left_at "$wide"
click_window "$W2"
ctl dock "$W2" left
ctl dock "$W1" right
sleep 1
arbor_quit
check "Quit gives it back as it stood" eventually is_at "$W2" "$wide"
click_window "$W2"
arbor_relaunch
sleep 2
summary
check "it has the keyboard, so it is let be" eventually is focused "$W2"
check "as it stood" eventually is_at "$W2" "$wide"
check "and stays so" stays is_at "$W2" "$wide"
asked_of "$W2"

arbor_stop
