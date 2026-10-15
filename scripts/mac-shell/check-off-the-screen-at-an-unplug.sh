#!/bin/bash
# A floating window that is off the screen when its display goes, on real macOS: its app hidden, or the window in the Dock.
# The second display is virtual (lib.sh's display_add, vdisplay.m). Nothing is docked.
#
#   scripts/mac-shell/run.sh scripts/mac-shell/check-off-the-screen-at-an-unplug.sh
#
# What only a Mac can answer, and what this brings back besides its checks (the lines that begin with "measured:", and a trace of every
# change in traces/):
#   1. What does macOS do to such a window when its display goes, and when it comes back? With Arbor and, at the end, without.
#   2. Does such a window obey a move? Arbor asks one of it only where macOS has not put it in its place already.
#   3. With Arbor: it is not in the corner, it lies on the display it belongs to, and nothing moves when it shows.
#
# On GitHub's Macs plugging the display in also switches the main one from 1024×768 to 1920×1080, and unplugging switches it back, so
# every plug is a change of resolution too.
source "$(dirname "$0")/lib.sh"
needs_throwaway_mac "plug a virtual display in and out, at which macOS moves every window"

WIDTH=1280
HEIGHT=800

arbor_build

# As in check-displays.sh: nothing asks Arbor anything while a trace is recorded.
# recorded <name> <command…>
TRACES="$ARBOR_OUT/traces"
mkdir -p "$TRACES"
recorded() {
  local name=$1
  shift
  "$ARBOR_BIN/arborctl" trace on "$name" > /dev/null
  "$@"
  sleep 3
  "$ARBOR_BIN/arborctl" trace off > /dev/null
  cp "$ARBOR_HOME"/traces/*-"$name".jsonl "$TRACES/$name.jsonl" || echo "no trace $name"
}

arranges() { [ "$(arbor_ask displays)" = "$1" ]; }

# Whether at least half of the window lies on display n, by the window server's frame: it has one for a window that is off the screen too.
# mostly_on <n> <id>
mostly_on() {
  local x y w h dx dy dw dh
  take "x y w h" real_frame_of "$2"
  take "dx dy dw dh" display_frame_of "$1"
  awk -v x="$x" -v y="$y" -v w="$w" -v h="$h" -v dx="$dx" -v dy="$dy" -v dw="$dw" -v dh="$dh" 'BEGIN {
    r = (x + w < dx + dw) ? x + w : dx + dw; l = (x > dx) ? x : dx
    b = (y + h < dy + dh) ? y + h : dy + dh; t = (y > dy) ? y : dy
    exit !(r > l && b > t && (r - l) * (b - t) * 2 >= w * h)
  }'
}

hide_it() { tw2 hide; }
unhide_it() { tw2 unhide; }
minimize_it() { tw minimize "$W2"; }
restore_it() { tw restore "$W2"; }

# there_and_back <name> <id> <hidden|minimized> <put it away> <bring it back>
there_and_back() {
  local name=$1 id=$2 state=$3 away=$4 back=$5 own there

  claim "$name when the cable is pulled, a floating window is not taken to the corner, and nothing moves when it shows"
  own=$(real_frame_of "$id")
  "$away"
  check "it is $state" eventually is "$state" "$id"
  recorded "$name-unplugged" display_remove
  check "Arbor arranges one display" eventually arranges 1
  sleep 1
  echo "measured: $name, unplugged: it was at $own; the window server has it at $(real_frame_of "$id"), Arbor at $(frame_of "$id")"
  check "it belongs to the display that is left" is display1 "$id"
  check "it floats" is floating "$id"
  check "it does not count as out of view" fails is parked "$id"
  check "most of it lies on the display that is left" mostly_on 1 "$id"
  there=$(real_frame_of "$id")
  recorded "$name-shown-on-the-main-display" "$back"
  check "shown, it is in view" eventually in_view "$id"
  echo "measured: $name, shown on the main display: the window server has it at $(real_frame_of "$id")"
  # shellcheck disable=SC2086
  check "it is where it lay while it was away: nothing moved when it showed" frame_is "$id" $there
  shot "$name-1-shown-on-the-main-display"

  claim "$name when the display is plugged in again, a floating window is back where it floated before it shows"
  "$away"
  check "it is $state again" eventually is "$state" "$id"
  recorded "$name-plugged-in-again" display_add $WIDTH $HEIGHT right
  check "Arbor arranges two displays" eventually arranges 2
  sleep 1
  echo "measured: $name, plugged in again: the window server has it at $(real_frame_of "$id"), Arbor at $(frame_of "$id")"
  check "it belongs to the second display again" eventually is display2 "$id"
  check "it does not count as out of view" fails is parked "$id"
  # shellcheck disable=SC2086
  check "it is where it floated, while still away" frame_is "$id" $own
  recorded "$name-shown-on-the-second-display" "$back"
  check "shown, it is in view" eventually in_view "$id"
  # shellcheck disable=SC2086
  check "nothing moved when it showed" frame_is "$id" $own
  shot "$name-2-shown-on-the-second-display"
}

step "two displays, nothing docked: a window of each of two apps floats on the second"
ARBOR_SECOND_APP=1
arbor_start 2
display_add $WIDTH $HEIGHT right
check "Arbor arranges two displays" eventually arranges 2
take "dx dy dw dh" display_frame_of 2
tw move "$W2" $((dx + 120)) $((dy + 140)) 480 348
tw2 move "$V1" $((dx + 640)) $((dy + 260)) 480 348
sleep 2
check "the first app's window is the second display's" eventually is display2 "$W2"
check "the second app's window is the second display's" eventually is display2 "$V1"
check "nothing is docked" count docked 0
summary
shot 0-two-displays

there_and_back hidden "$V1" hidden hide_it unhide_it
there_and_back minimized "$W2" minimized minimize_it restore_it

step "without Arbor: what macOS alone does to a hidden window and to one in the Dock"
arbor_quit
echo "measured: macOS alone, before: hidden-to-be $(real_frame_of "$V1"), minimized-to-be $(real_frame_of "$W2")"
hide_it
minimize_it
sleep 2
display_remove
sleep 4
echo "measured: macOS alone, unplugged, still away: $(real_frame_of "$V1"), $(real_frame_of "$W2")"
unhide_it
restore_it
sleep 2
echo "measured: macOS alone, unplugged, shown: $(real_frame_of "$V1"), $(real_frame_of "$W2")"
hide_it
minimize_it
sleep 2
display_add $WIDTH $HEIGHT right
sleep 4
echo "measured: macOS alone, plugged in again, still away: $(real_frame_of "$V1"), $(real_frame_of "$W2")"
unhide_it
restore_it
sleep 2
echo "measured: macOS alone, plugged in again, shown: $(real_frame_of "$V1"), $(real_frame_of "$W2")"
shot 3-macos-alone

step "the end"
arbor_relaunch
display_remove
check "Arbor arranges one display" eventually arranges 1
arbor_stop 4-after-quit
