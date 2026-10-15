#!/bin/bash
# Does Arbor miss a drag whose first movement is a long one?
#
#   scripts/mac-shell/run.sh scripts/mac-shell/probe-coarse-drag.sh      (about three minutes)
#
# check-displays.sh drags windows from one display to the other, and on a hosted Mac Arbor took three of four such drags for nothing at all: no
# "is being dragged" in its log, no preview, no dock. pointer.swift cuts every drag into 30 steps whatever its length, so those steps were 42 to 66
# points long, and `WindowGrab.classify` gives a press up for good when the pointer is more than 24 points from it (`patience`) and the window
# has not moved yet. If that is the cause, whether a drag is seen depends on the length of its first step and on nothing else.
#
# Part 1, one display: a floating window is dragged 500 points to and fro, a step every 20 ms as in that script, in steps of 71, 45, 29, 22, 14 and 7 points,
# six times each. Part 2, two displays: the very drag of check-displays.sh, to the middle of the second display and back, in 30 steps and in
# steps of under 20 points, four times each. For every drag: did the window arrive, and did Arbor see a drag? The first drag of each kind is
# recorded as a trace (docs/TRACES.md), which comes back in traces/ and holds every raw event with its place and time.
#
# The fine steps are the control: they must always be seen. What the coarse ones do is the question.
# Found on 2026-10-15 on the code of that morning: seen in 26 drags of 26 with steps of 24 points or less, in 3 of 26 above; the window went along in all 52. Since "a window that starts late is still being
# dragged" every one of them should be seen.
source "$(dirname "$0")/lib.sh"
needs_throwaway_mac "plug in a virtual display, at which macOS moves every window"

TRACES="$ARBOR_OUT/traces"
mkdir -p "$TRACES"
RESULTS="$ARBOR_OUT/results.txt"
: > "$RESULTS"

# one_drag <kind> <x1> <y1> <x2> <y2> <steps> <record?>: prints and notes whether the window went along and whether Arbor saw a drag.
one_drag() {
  local kind=$1 x1=$2 y1=$3 x2=$4 y2=$5 steps=$6 record=$7 mark before after seen moved
  before=$(real_frame_of "$W1")
  mark=$(wc -l < "$ARBOR_HOME/arbor.log")
  [ -z "$record" ] || "$ARBOR_BIN/arborctl" trace on "$kind" > /dev/null
  pointer drag "$x1" "$y1" "$x2" "$y2" --steps "$steps" --duration "$(echo "$steps * 0.02" | bc)"
  sleep 0.8
  if [ -n "$record" ]; then
    "$ARBOR_BIN/arborctl" trace off > /dev/null
    cp "$ARBOR_HOME"/traces/*-"$kind".jsonl "$TRACES/$kind.jsonl" || echo "no trace $kind"
  fi
  after=$(real_frame_of "$W1")
  seen=$(tail -n "+$((mark + 1))" "$ARBOR_HOME/arbor.log" | grep -c "w$W1 is being dragged")
  [ "$before" = "$after" ] && moved=0 || moved=1
  echo "  $kind: $x1 $y1 to $x2 $y2 in $steps steps: the window went from ($before) to ($after); Arbor saw a drag: $seen"
  echo "$kind $moved $seen" >> "$RESULTS"
}
# tally <kind>: "seen 2 of 6 (the window moved in 6)"
tally() { awk -v kind="$1" '$1 == kind { n++; moved += $2; seen += ($3 > 0) } END { printf "seen %d of %d (the window moved in %d)", seen, n, moved }' "$RESULTS"; }
all_seen() { awk -v kind="$1" '$1 == kind { n++; seen += ($3 > 0) } END { exit !(n > 0 && seen == n) }' "$RESULTS"; }
all_moved() { awk -v kind="$1" '$1 == kind { n++; moved += $2 } END { exit !(n > 0 && moved == n) }' "$RESULTS"; }

arbor_build
arbor_start 1
macos_tiling

step "part 1, one display: 500 points to and fro, a step every 20 ms"
for steps in 7 11 17 22 34 63; do
  kind="steps-of-$((500 / steps))"
  for turn in 1 2 3 4 5 6; do
    read -r x y w _ <<< "$(real_frame_of "$W1")"
    x=${x%.*} y=${y%.*} w=${w%.*}
    if [ "$x" -lt 270 ]; then to=$((x + w / 2 + 500)); else to=$((x + w / 2 - 500)); fi
    one_drag "$kind" "$((x + w / 2))" "$((y + 12))" "$to" "$((y + 12))" "$steps" "$([ "$turn" = 1 ] && echo yes)"
  done
done
echo
for steps in 7 11 17 22 34 63; do echo "steps of $((500 / steps)) points: $(tally "steps-of-$((500 / steps))")"; done
for steps in 7 11 17 22 34 63; do
  check "steps of $((500 / steps)) points: the window went along every time, so these were drags" all_moved "steps-of-$((500 / steps))"
done
check "the control: steps of 14 points are always seen" all_seen steps-of-14
check "the control: steps of 7 points are always seen" all_seen steps-of-7
check "steps of 22 points, just within the patience, are always seen" all_seen steps-of-22
check "steps of 29 points are always seen" all_seen steps-of-29
check "steps of 45 points are always seen" all_seen steps-of-45
check "steps of 71 points are always seen" all_seen steps-of-71

step "part 2, two displays: check-displays.sh's own drag, to the middle of the second display and back"
display_add 1280 800 right
sleep 2
read -r sx sy sw sh <<< "$(screen_of 2)"
read -r mx my mw mh <<< "$(screen_of 1)"
for turn in 1 2 3 4; do
  for kind in in-30-steps in-fine-steps; do
    for target in "$((sx + sw / 2)) $((sy + sh / 2))" "$((mx + mw / 2)) $((my + mh / 2))"; do
      read -r x y w _ <<< "$(real_frame_of "$W1")"
      x=${x%.*} y=${y%.*} w=${w%.*}
      read -r tx ty <<< "$target"
      length=$((tx - x - w / 2))
      [ "$length" -lt 0 ] && length=$((-length))
      if [ "$kind" = in-30-steps ]; then steps=30; else steps=$((length / 16 + 1)); fi
      one_drag "$kind" "$((x + w / 2))" "$((y + 12))" "$tx" "$ty" "$steps" "$([ "$turn" = 1 ] && [ "$tx" -gt "$mw" ] && echo yes)"
    done
  done
done
echo
echo "in 30 steps:   $(tally in-30-steps)"
echo "in fine steps: $(tally in-fine-steps)"
check "in 30 steps the window went along every time" all_moved in-30-steps
check "in fine steps the window went along every time" all_moved in-fine-steps
check "the control: in steps of under 20 points the long drag is always seen" all_seen in-fine-steps
check "in 30 steps the long drag is always seen" all_seen in-30-steps
display_remove
arbor_stop after-quit
