#!/bin/bash
# A docked Terminal keeps one frame (board 1.62). Terminal sizes its window in whole character cells and takes the cells NEAREST to what it is asked for, which half
# the time is more. It used to grow a line past its slot and be talked down again every time its slot came back.
#
#   scripts/mac-shell/run.sh scripts/mac-shell/check-terminal-cells.sh          five minutes
#
# THE QUESTION only a Mac can answer: does the real Terminal take the whole cells Arbor works out for it AS THEY ARE, at once, so that a return of the view is one frame set?
# The stand-in does (`CellsTests`, collab/scenarios/62-a-terminal-keeps-its-frame.sim); the recordings say how Terminal rounds, not what it makes of a size that is on its grid.
#
# Real apps, real keys. Terminal is docked left and Safari right. Then ten times: Safari framed (⌃⌥↩), so that Terminal goes out of view, and everything again (⌃⌥0). After each
# return Terminal's frame is read from the window server. Then the same with the gap beside Terminal moved (⌃⌥⌘=), so that the slot has another width, and with a larger font (⌘+).
#
# What comes back: terminal.txt, a line a return (the slot, the frame); the day's report with every frame sampled, where a line up and a line down would be a jolt; and the
# traces, in which every request to Terminal stands beside what it took.
#
# Only on GitHub's Macs, as every journey (lib-walk.sh asks).
WALK_KIND=hunt
source "$(dirname "${BASH_SOURCE[0]}")/lib-walk.sh"

walk_begin stock laptop defaults
TERMINAL=$(window_of terminal)
: > "$ARBOR_OUT/terminal.txt"

# In the slot's top-left corner, not over it by more than the two points any window is allowed, and less than 36 points short of it: no cell is larger.
in_its_corner() {
  local x y w h sx sy sw sh
  read -r x y w h <<< "$(real_of "$TERMINAL")"
  read -r sx sy sw sh <<< "$(slot_of "$TERMINAL" | awk '{ for (i = 1; i <= NF; i++) printf "%d ", $i + 0.5 }')"
  echo "$1: slot $sx $sy $sw $sh, frame $x $y $w $h" | tee -a "$ARBOR_OUT/terminal.txt"
  [ "$x" = "$sx" ] && [ "$y" = "$sy" ] && [ $((w - sw)) -le 2 ] && [ $((h - sh)) -le 2 ] && [ $((sw - w)) -lt 36 ] && [ $((sh - h)) -lt 36 ]
}

# Ten times away and back, and each time the frame it had before.
ten_returns() {
  local round first now
  first=$(real_of "$TERMINAL")
  check "$1: it is in its slot's corner, within a cell" in_its_corner "$1, to begin with"
  for round in 1 2 3 4 5 6 7 8 9 10; do
    view frame
    view home
    now=$(real_of "$TERMINAL")
    check "$1, return $round: in its slot's corner, within a cell" in_its_corner "$1, return $round"
    check "$1, return $round: the frame it had before ($first)" [ "$now" = "$first" ]
  done
}

switch_to terminal;  dock_key left
switch_to safari;    dock_key right

chapter "Ten times away and back"
ten_returns "as docked"

# A chapter whose act was left out would be the first chapter over again, under another heading.
chapter "Another width"
BEFORE=$(slot_of "$TERMINAL")
# By the key: a floating window of the cast's can lie over the gap, and a drag there would be left out.
switch_to terminal
resize_key grow
check "the gap was moved: Terminal's slot is another ($BEFORE)" [ "$(slot_of "$TERMINAL")" != "$BEFORE" ]
switch_to safari
ten_returns "the gap moved"

chapter "A larger font"
switch_to terminal
BEFORE=$(real_of "$TERMINAL")
walk_act macos-own larger-font "presses ⌘+ in Terminal"
key "cmd+="
acted moves=any
echo "with the larger font: $(real_of "$TERMINAL"), before: $BEFORE" | tee -a "$ARBOR_OUT/terminal.txt"
check "the font is larger: Terminal has another size ($BEFORE)" [ "$(real_of "$TERMINAL")" != "$BEFORE" ]
switch_to safari
ten_returns "a larger font"

walk_end
