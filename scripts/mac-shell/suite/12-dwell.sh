#!/bin/bash
# Dragging on purpose: a window's edge is a target only once the pointer has rested on it, a screen edge at once, and ⌘ turns
# docking off, before the drag or in the middle of it.
# T10 hold over a target before it activates.
#
# What the pointer tool does matters here (pointer.swift). `drag` rests at its end for a quarter of a second and then for --hold
# (0.2 s), which is longer than the hold Arbor asks for (`dropDwell`, 0.15 s): that is holding. `release x y` after a
# `drag --no-release` goes there in one step and lets go 0.05 s later: that is sweeping. --steps 60, because these drags cross
# the screen, and on a wide one thirty steps are so long that Arbor can miss the first.
source "$(dirname "$0")/../lib.sh"
arbor_build
# Where macOS tiles at the screen's edges, the left, the right and the top one are macOS's. The bottom one is always Arbor's.
if screen_edges_dock; then edges=ours; else edges=""; fi

# over <a> <b>: part of the first window lies over the second, as the window server has both.
over() {
  local ax ay aw ah bx by bw bh
  take "ax ay aw ah" resting_frame_of "$1"
  take "bx by bw bh" resting_frame_of "$2"
  [ "$ax" -lt "$((bx + bw))" ] && [ "$bx" -lt "$((ax + aw))" ] && [ "$ay" -lt "$((by + bh))" ] && [ "$by" -lt "$((ay + ah))" ] \
    || { echo "one is at $ax $ay $aw $ah, the other at $bx $by $bw $bh"; return 1; }
}
preview_is() {
  local shown
  shown=$(overlay_frame 3) || { echo "there is no preview"; return 1; }
  [ "$shown" = "$1" ] || { echo "the preview is at $shown, not at $1"; return 1; }
}
# shortly <command…>: it holds now or within half a second, which is well before a hold of two seconds is over. (`eventually` would
# wait longer than the hold.)
shortly() {
  local tries=0
  until "$@"; do
    [ "$tries" -lt 2 ] || return 1
    sleep 0.2
    tries=$((tries + 1))
  done
}
# The third window, floating, back on the Desktop, where the next drag finds it.
# shellcheck disable=SC2046
home() {
  drag_window "$W3" $(desktop_point) --steps 60
  eventually is floating "$W3" > /dev/null || die "the third window does not float on the Desktop"
}

arbor_start 3
ctl dock "$W1" left
ctl dock "$W2" right
summary

claim "sweep a window over a docked window's edge and let go without stopping: no preview shows, and it floats where it was let go"
proves T10
take "x y" zone_of "$W2" top
slot=$(resting_frame_of "$W2")
before=$(resting_frame_of "$W3")
# shellcheck disable=SC2046
drag_window "$W3" $(desktop_point) --steps 60 --no-release
# shellcheck disable=SC2086
check "the window is in the hand" fails frame_is "$W3" ${before:-0 0 0 0}
release "$x" "$y"
place=$(resting_frame_of "$W3")
check "no preview is on screen" stays fails has_overlay 3
check "the window floats" is floating "$W3"
check "Arbor saw it let go, and docked nothing" logged "dropped w$W3 on float"
# shellcheck disable=SC2086
check "it has stayed where it was let go" frame_is "$W3" ${place:-0 0 0 0}
check "which is over the docked window" over "$W3" "$W2"
# shellcheck disable=SC2086
check "the docked window has not moved" frame_is "$W2" ${slot:-0 0 0 0}
check "two are docked" count docked 2
settled

claim "sweep a docked window the same way: it goes back into its slot"
proves T10
home
place=$(resting_frame_of "$W1")
# shellcheck disable=SC2046
drag_window "$W1" $(desktop_point) --steps 60 --no-release
check "the window has left its slot with the pointer" fails in_slot "$W1"
release "$x" "$y"
# shellcheck disable=SC2086
check "it is back exactly where it was" eventually frame_is "$W1" ${place:-0 0 0 0}
check "it is still docked" is docked "$W1"
check "no preview is on screen" stays fails has_overlay 3
# shellcheck disable=SC2086
check "the other docked window has not moved" frame_is "$W2" ${slot:-0 0 0 0}
check "two are docked" count docked 2
settled

claim "hold ⌘ and hold a window over a docked window's edge: no preview shows, and let go there it floats"
proves T10
drag_window "$W3" "$x" "$y" --steps 60 --mods cmd --hold 0.5 --no-release
check "the window is over the docked one" over "$W3" "$W2"
check "no preview shows, however long it is held" stays fails has_overlay 3
release --mods cmd
check "the window floats" stays is floating "$W3"
check "Arbor saw it let go, and docked nothing" logged "dropped w$W3 on float"
# shellcheck disable=SC2086
check "the docked window has not moved" frame_is "$W2" ${slot:-0 0 0 0}
check "two are docked" count docked 2

# At the top, where the window stays on the screen when it is let go.
if [ -n "$edges" ]; then
  claim "hold ⌘ and drag a window to the screen edge: no preview shows, and let go there it floats"
  proves T10
  # shellcheck disable=SC2046
  drag_window "$W3" $(edge_point top) --steps 60 --mods cmd --no-release
  check "no preview shows" stays fails has_overlay 3
  release --mods cmd
  check "the window floats" stays is floating "$W3"
  check "Arbor saw it let go, and docked nothing" logged "dropped w$W3 on float"
  check "two are docked" count docked 2
  settled
fi

claim "hold ⌘ and let go of a docked window over its own slot: it floats"
proves T10
take "tx ty" titlebar_of "$W1"
drag "$tx" "$ty" "$((tx + 20))" "$((ty + 40))" --mods cmd --no-release
check "no preview shows" stays fails has_overlay 3
release --mods cmd
check "the window floats" eventually is floating "$W1"
check "one is docked" count docked 1
settled
ctl dock "$W1" left

claim "press ⌘ while a preview shows, without moving the pointer: it goes; let go of ⌘: it comes back, and the window docks there"
proves T10
home
take "x y" zone_of "$W2" top
drag_window "$W3" "$x" "$y" --steps 60 --no-release
check "a preview shows" eventually has_overlay 3
preview=$(overlay_frame 3)
# The key alone: with another key it would be a shortcut of the app in front.
key cmd --down
check "with ⌘ down the preview goes" eventually fails has_overlay 3
check "and stays away, however long the window is held" stays fails has_overlay 3
key cmd --up
check "with ⌘ up it comes back" eventually has_overlay 3
check "where it was" preview_is "$preview"
release
check "the window is docked" eventually is docked "$W3"
# shellcheck disable=SC2086
check "it landed exactly where the preview was" eventually frame_is "$W3" ${preview:-0 0 0 0}
check "the preview is gone" eventually fails has_overlay 3
settled

claim "hold a window over one edge of a docked window, then over another: the preview shows the new place, and the window docks there"
proves T10 T11
ctl float "$W3"
home
# shellcheck disable=SC2046
drag_window "$W3" $(zone_of "$W2" top) --steps 60 --no-release
check "a preview shows" eventually has_overlay 3
first=$(overlay_frame 3)
# shellcheck disable=SC2046
drag_on $(zone_of "$W2" bottom)
check "a preview shows at the other edge" eventually has_overlay 3
check "and not where the first was" eventually fails preview_is "${first:-none}"
second=$(overlay_frame 3)
release
check "the window docked below the other" eventually above "$W2" "$W3"
# shellcheck disable=SC2086
check "it landed exactly where the second preview was" eventually frame_is "$W3" ${second:-0 0 0 0}
check "the preview is gone" eventually fails has_overlay 3
settled
arbor_stop

# The hold made long enough to look at: as it comes, it is over before anybody can ask whether a preview shows.
arbor_settings '{"dropDwell": 2}'
arbor_start 3
ctl dock "$W1" left
ctl dock "$W2" right

claim "hold a window over a docked window's edge: the preview waits until the hold is over"
proves T10
take "x y" zone_of "$W2" top
drag_window "$W3" "$x" "$y" --steps 60 --hold 0 --no-release
check "at first no preview shows" fails has_overlay 3
# The hold ends by itself, two seconds after the pointer came to rest, and nothing that can be asked says how far it has got.
sleep 1
check "then it does" eventually has_overlay 3
preview=$(overlay_frame 3)
release
check "the window is docked" eventually is docked "$W3"
check "above the other" eventually above "$W3" "$W2"
# shellcheck disable=SC2086
check "it landed exactly where the preview was" eventually frame_is "$W3" ${preview:-0 0 0 0}
settled

claim "let go of a window over a docked window's edge before the hold is over: it floats"
proves T10
ctl float "$W3"
home
take "x y" zone_of "$W2" top
drag_window "$W3" "$x" "$y" --steps 60
check "the window floats" stays is floating "$W3"
check "no preview is on screen" fails has_overlay 3
check "two are docked" count docked 2

claim "drag a window to the screen edge: the preview does not wait for the hold"
proves T10 T11
# From the Desktop: quitting puts a window back where it floated before it was docked, and hanging over the side of the screen is not
# where arbor_stop expects it.
home
# shellcheck disable=SC2046
drag_window "$W3" $(edge_point bottom) --steps 60 --hold 0 --no-release
check "a preview shows long before the hold would be over" shortly has_overlay 3
release
check "the window is docked" eventually is docked "$W3"
check "it reaches the bottom edge of the screen" eventually at_edge "$W3" bottom
settled
arbor_stop
