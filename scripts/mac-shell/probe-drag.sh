#!/bin/bash
# What happens to a real title-bar drag on this Mac, and who reacts to it: the window server, macOS's own tiling, Arbor.
# Nothing here is a check: the output is the point.
#
#   scripts/mac-shell/run.sh scripts/mac-shell/probe-drag.sh
#
# The same drags are made twice: with macOS's tiling as the Mac comes (its default: on), and with it switched off.
# For every drag: where the pointer and the window were meanwhile (trace-<name>.txt), a picture with the button held, what
# else was on the screen then, where the window ended, and what Arbor's log says about it.
source "$(dirname "$0")/lib.sh"
needs_throwaway_mac "switch macOS's own tiling off and on"

arbor_build
for tool in axwatch witness; do
  swiftc -O -swift-version 5 "$ARBOR_ROOT/scripts/mac-shell/$tool.swift" -o "$ARBOR_ROOT/.build/mac-shell/$tool" \
    > "$ARBOR_OUT/build-$tool.log" 2>&1 || cat "$ARBOR_OUT/build-$tool.log"
done

step "the Mac"
sw_vers
echo "com.apple.WindowManager:"
defaults read com.apple.WindowManager 2>&1
echo "AppleActionOnDoubleClick: $(defaults read -g AppleActionOnDoubleClick 2>&1 | tail -n 1)"
echo "AppleMiniaturizeOnDoubleClick: $(defaults read -g AppleMiniaturizeOnDoubleClick 2>&1 | tail -n 1)"
macos_tiling
macos_click_wallpaper
echo "displays:"; pointer displays
echo "pointer: $(pointer where); front: $(pointer front)"
echo "event taps:"; "$ARBOR_ROOT/.build/mac-shell/witness" taps 2>&1 | head -n 30
echo "on the screen, front to back (id pid level x y w h on owner):"
pointer windows --on-screen

# Whatever is on the screen besides the test windows, Arbor and the furniture: macOS's preview, if it shows one.
strangers() {
  pointer windows | awk -v arbor="$ARBOR_PID" '$8 == "on" && $2 != arbor' \
    | grep -v -E " (ArborTestWindows|Dock|Finder|Window Server|Control Center|Spotlight|Notification Center|Wallpaper)$"
}

# trace <id> <count> <name>
trace() {
  local index=0
  while [ "$index" -lt "$2" ]; do
    echo "$(arbor_now) pointer $("$ARBOR_POINTER" where) window $("$ARBOR_POINTER" frame "$1")"
    index=$((index + 1))
  done > "$ARBOR_OUT/trace-$3.txt"
}

since() { tail -n "+$(($1 + 1))" "$ARBOR_HOME/arbor.log" | cut -c 12-; }

# try <name> <window> <x1 y1 x2 y2> [options of drag]
try() {
  local name=$1 id=$2 mark tracer
  shift 2
  step "$name"
  mark=$(wc -l < "$ARBOR_HOME/arbor.log")
  echo "--- $name" >> "$ARBOR_OUT/ax-events.txt"
  echo "--- $name" >> "$ARBOR_OUT/pointer-events.txt"
  echo "before: window server $(real_frame_of "$id"), Arbor $(frame_of "$id")"
  trace "$id" 40 "$name" &
  tracer=$!
  drag "$@" --no-release
  ended "$tracer" 100
  echo "held: pointer $(pointer where), window server $(real_frame_of "$id")"
  echo "Arbor's own windows on screen:"; overlays | awk '$8 == "on"'
  echo "strangers:"; strangers
  ARBOR_SETTLE=0.5 shot "$name-1-held"
  echo "after a second in the hand, strangers:"; strangers
  release
  sleep 1.5
  echo "let go: window server $(real_frame_of "$id"), Arbor $(frame_of "$id")"
  ARBOR_SETTLE=0 shot "$name-2-let-go"
  summary
  echo "Arbor's log:"; since "$mark"
}

round() {
  local tag=$1 x y w h
  step "ROUND $tag"
  macos_tiling
  arbor_start 3
  ctl doctor
  read -r sx sy sw sh <<< "$(arbor_ask screen)"
  echo "on the screen, front to back:"
  pointer windows --on-screen
  "$ARBOR_ROOT/.build/mac-shell/axwatch" "$ARBOR_WINDOWS_PID" >> "$ARBOR_OUT/ax-events.txt" 2>&1 &
  watcher=$!
  started "$watcher"
  "$ARBOR_ROOT/.build/mac-shell/witness" watch 200 >> "$ARBOR_OUT/pointer-events.txt" 2>&1 &
  witness=$!
  started "$witness"
  sleep 1
  shot "$tag-0-start"

  # shellcheck disable=SC2046
  try "$tag-1-middle" "$W3" $(titlebar_of "$W3") $((sx + sw / 2 + 60)) $((sy + 200))
  # shellcheck disable=SC2046
  try "$tag-2-left-edge" "$W3" $(titlebar_of "$W3") $((sx + 3)) $((sy + sh / 2))
  is docked "$W3" && ctl float "$W3"
  sleep 1
  read -r x y w h <<< "$(real_frame_of "$W3")"
  try "$tag-3-pushed-left" "$W3" $((${x%.*} + ${w%.*} / 2)) $((${y%.*} + 12)) $((sx - 40)) $((sy + sh / 2)) --hold 1
  is docked "$W3" && ctl float "$W3"
  sleep 1
  read -r x y w h <<< "$(real_frame_of "$W3")"
  try "$tag-4-near-the-top" "$W3" $((${x%.*} + ${w%.*} / 2)) $((${y%.*} + 12)) $((sx + sw / 2)) $((sy + 72))
  is docked "$W3" && ctl float "$W3"
  sleep 1
  read -r x y w h <<< "$(real_frame_of "$W3")"
  try "$tag-5-menu-bar" "$W3" $((${x%.*} + ${w%.*} / 2)) $((${y%.*} + 12)) $((sx + sw / 2)) 2 --hold 1
  is docked "$W3" && ctl float "$W3"
  sleep 1

  step "$tag-6: a double-click on a floating window's title bar"
  mark=$(wc -l < "$ARBOR_HOME/arbor.log")
  read -r x y w h <<< "$(real_frame_of "$W2")"
  echo "before: $x $y $w $h"
  pointer windows --on-screen | head -n 8
  # Its left part, which the window in front of it leaves free.
  dblclick $((${x%.*} + 100)) $((${y%.*} + 12))
  sleep 1.5
  echo "after: $(real_frame_of "$W2")"
  shot "$tag-6-double-click"
  summary
  since "$mark"

  kill_started "$watcher" "$witness"
  arbor_stop
}

round default
macos_tiling off
round off
macos_tiling on
