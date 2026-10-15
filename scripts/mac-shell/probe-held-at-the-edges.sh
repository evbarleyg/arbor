#!/bin/bash
# How does macOS hold a window that is dragged across an edge of the screen?
#
#   scripts/mac-shell/run.sh scripts/mac-shell/probe-held-at-the-edges.sh      (about twelve minutes; no Arbor runs)
#
# A walk played on two hosted Macs without Arbor showed that a window dragged by its title bar does not always go as far as the pointer. It follows point for point
# until its edge meets the edge of the screen, is held there while the pointer goes on, and when it lets go it goes on from the edge: it never catches up. Held at the left
# edge for 31 points of the pointer's way at some 90 points a second, for 19 at 130 to 160. With its lower edge a point above the Dock it did not move for 88 points, which was
# all there was; lying under the menu bar it did not come away in 64. The stand-in's window goes wherever the pointer goes.
#
# Asked here, of each of the four edges: how far does the pointer go on before the window lets go, slowly, at a walk and fast? On the way out across the edge, and on
# the way back in? Does it let go at all at the Dock and under the menu bar? Does it ever catch up?
#
# One window, TextEdit's, with every other app hidden: macOS lines a dragged window up with other windows' edges too, and that is another question.
# Nothing is checked. The samples hold the pointer and the window some forty times a second; scripts/mac-shell/held.py reads what is asked out of them afterwards.
#
# ANSWERED on a hosted Mac, macOS 26.6.2, 2026-10-15 (collab/reality.json, macos-holds-a-slowly-dragged-window-at-the-edges-of-the-screen): 31 points outwards at the
# left and the right edge, a distance and not a time; twice that downwards, at the Dock's top and at the bottom of the screen; nothing inwards; nothing on the way from the menu
# bar, under which the window stopped for the ten points it was pushed. THE SPEED ASKED FOR IS NOT THE SPEED: in steps of two points, 50, 150 and 600 points a second came out as
# 24, 45 and some 150: a step took 5 to 50 ms longer than its rest, on average, and the more the longer the rest. held.py says what it was. At those 150 (600 asked) one stand of
# four was still 31 points long and the others 9 or 10. So a step now grows with the speed, and 2000 is asked for as well, to come nearer to a hand: of that form the syntax and the arithmetic
# have been checked, and no Mac has played it. In steps that long expect no stand at all from held.py, at 600 and at 2000: read what the window is short of in the end.
export WALK_WITHOUT_ARBOR=1
source "$(dirname "${BASH_SOURCE[0]}")/lib-walk.sh"
walk_begin stock laptop defaults held-at-the-edges

# pull <slug> <across> <down> <points a second>: takes the window by its title bar, wherever a free point of it shows, and goes so far at that speed, thirty steps a second, two points a step at the least and three steps: nothing copes with a single jump.
pull() {
  local x y role window way steps seconds
  window=$(window_of textedit)
  read -r x y role <<< "$(apptool grab "$window" 2>/dev/null)"
  [ -n "${x:-}" ] || { left_out "pull $*: no free point of the title bar shows"; return; }
  way=$(echo "sqrt($2 * $2 + $3 * $3)" | bc -l)
  steps=$(printf '%.0f' "$(echo "s = $4 / 30; if (s < 2) s = 2; n = $way / s; if (n < 3) n = 3; n" | bc -l)")
  seconds=$(printf '%.2f' "$(echo "$way / $4" | bc -l)")
  walk_act drag "$1" "drags textedit by its title bar $2 across and $3 down, at $4 points a second"
  must drag_window "$window" "$((x + $2))" "$((y + $3))" --steps "$steps" --duration "$seconds" --hold 0.5
  changed
  acted drags="$window" front="$window" own="$window"
}

# carry <x> <y>: puts the window there, or near it, fast: what it was held by on its way adds up, and the pointer must not come to an edge, where macOS tiles.
carry() {
  local x y
  read -r x y _ <<< "$(real_frame_of "$(window_of textedit)")"
  # It is there already: what was not held on its way out comes back to where it was.
  [ "${x%.*}" != "$1" ] || [ "${y%.*}" != "$2" ] || return 0
  pull "carry-to-$1-$2" "$(($1 - ${x%.*}))" "$(($2 - ${y%.*}))" 600
}

switch_dock textedit
walk_act open-close hide-others "presses ⌥⌘H: every other app is hidden"
key cmd+opt+h
for name in $WALK_CAST; do [ "$name" = textedit ] || WALK_HIDDEN="$WALK_HIDDEN $name"; done
changed
acted leaves=any

# 673 wide and 439 high, on 1600×900 with the menu bar's 31 and the Dock's 78. Out means 215 points across the edge. The pointer stays 60 points and more from the sides and the Dock, where macOS
# would tile.
for speed in 50 150 600 2000; do
  chapter "The left edge, at $speed points a second"
  carry 165 120
  pull "left-out-$speed" -380 0 "$speed"
  pull "left-in-$speed" 380 0 "$speed"
done
for speed in 50 150 600 2000; do
  chapter "The right edge, at $speed points a second"
  carry 762 120
  pull "right-out-$speed" 380 0 "$speed"
  pull "right-in-$speed" -380 0 "$speed"
done
for speed in 50 150 600 2000; do
  chapter "The Dock, at $speed points a second"
  carry 460 120
  pull "dock-out-$speed" 0 500 "$speed"
  pull "dock-in-$speed" 0 -500 "$speed"
done
for speed in 20 50 150 600 2000; do
  chapter "The menu bar, at $speed points a second"
  # 34 points up to the menu bar and ten more against it; the pointer itself stays below the bar.
  carry 460 65
  pull "menu-bar-against-$speed" 0 -44 "$speed"
  pull "menu-bar-away-$speed" 0 240 "$speed"
done
walk_end
