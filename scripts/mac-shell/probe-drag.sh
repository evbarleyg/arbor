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


# quick <name> <window> <x1 y1 x2 y2> [options]: the same without pictures of the end
grab_of() {
  local x y w h left right
  read -r x y w h <<< "$(real_frame_of "$1")"
  x=${x%.*}; y=${y%.*}; w=${w%.*}
  left=$x; right=$((x + w))
  [ "$left" -lt 0 ] && left=0
  [ "$right" -gt 1024 ] && right=1024
  echo "$(((left + right) / 2)) $((y + 12))"
}

home() {
  is docked "$1" && ctl float "$1" > /dev/null
  echo "move $2 300 200 480 348" >&9
  sleep 0.8
}

# to <name> <x> <y> [options]: W3 from the middle of the screen to that point, held a second and a half, let go
to() {
  local name=$1 x=$2 y=$3 mark
  shift 3
  step "$name: to $x $y $*"
  "$ARBOR_BIN/arborctl" float "$W3" > /dev/null 2>&1
  sleep 0.5
  # shellcheck disable=SC2046
  drag $(grab_of "$W3") 512 300 > /dev/null
  sleep 0.5
  mark=$(wc -l < "$ARBOR_HOME/arbor.log")
  echo "--- $name" >> "$ARBOR_OUT/ax-events.txt"
  # shellcheck disable=SC2046
  drag $(grab_of "$W3") "$x" "$y" --hold 1.5 --no-release "$@"
  echo "held: pointer $(pointer where), window $(real_frame_of "$W3")"
  echo "Arbor shows: $(overlays | awk '$8 == "on" { print $3, $4, $5, $6, $7 }' | tr '\n' ';')"
  echo "macOS shows: $(strangers | awk '{ print $9, $4, $5, $6, $7 }' | sort -u | tr '\n' ';')"
  ARBOR_SETTLE=0 shot "$name"
  release "$@"
  sleep 2
  echo "let go: window $(real_frame_of "$W3"), Arbor $(frame_of "$W3") $(is docked "$W3" && echo docked || echo floating)"
  since "$mark" | grep -v "Reduce motion\|said on"
}

step "how long this Mac has been left alone, and what it does then"
uptime
echo "HIDIdleTime: $(ioreg -c IOHIDSystem | awk '/HIDIdleTime/ { print int($NF / 1000000000); exit }') s"
echo "screen saver:"; defaults -currentHost read com.apple.screensaver 2>&1
pmset -g custom 2>&1 | grep -i -E "sleep|Power"
pmset -g assertions 2>&1 | head -n 12
echo "locked: $(ioreg -n Root -d1 | grep -c '"CGSSessionScreenIsLocked"=Yes')"

arbor_start 3
read -r sx sy sw sh <<< "$(arbor_ask screen)"
"$ARBOR_ROOT/.build/mac-shell/axwatch" "$ARBOR_WINDOWS_PID" >> "$ARBOR_OUT/ax-events.txt" 2>&1 &
watcher=$!
started "$watcher"
sleep 1

for x in 2 1 0; do to "left-$x" "$x" 368; done
for x in 1021 1022 1023; do to "right-$x" "$x" 368; done
for y in 42 32 30 24 16 8 4 1 0; do to "top-$y" 512 "$y"; done
to corner-top-left 0 31
to corner-top-left-0 0 0
to corner-bottom-left 0 700
to corner-bottom-left-767 0 767
to bottom-767 512 767
to option-left-third 200 368 --mods opt
to option-middle 512 368 --mods opt
to cmd-top-0 512 0 --mods cmd
to cmd-left-0 0 368 --mods cmd

step "a docked window carried to the menu bar"
ctl dock "$W3" left
ctl dock "$W2" right
sleep 1
summary
mark=$(wc -l < "$ARBOR_HOME/arbor.log")
echo "--- docked to the menu bar" >> "$ARBOR_OUT/ax-events.txt"
# shellcheck disable=SC2046
drag $(grab_of "$W3") 512 0 --hold 1.5
sleep 2
summary
since "$mark" | grep -v "Reduce motion\|said on"
shot docked-to-menu-bar
ctl float-all
sleep 1

step "a double-click on the title bar of a floating window that nothing covers"
# shellcheck disable=SC2046
drag $(grab_of "$W3") 700 500 > /dev/null
sleep 0.5
echo "--- double-click" >> "$ARBOR_OUT/ax-events.txt"
echo "before: $(real_frame_of "$W3")"
# shellcheck disable=SC2046
dblclick $(grab_of "$W3")
sleep 2
echo "after: $(real_frame_of "$W3")"
summary
kill_started "$watcher"
arbor_stop

step "the first drag of e2e-drag.sh with the screen saver up"
arbor_start 3
open -a ScreenSaverEngine
sleep 4
echo "ScreenSaverEngine: $(pgrep -x ScreenSaverEngine | tr '\n' ' ')"
pointer windows --on-screen | head -n 12
ARBOR_SETTLE=0 shot saver-0-up
mark=$(wc -l < "$ARBOR_HOME/arbor.log")
# shellcheck disable=SC2046
drag $(titlebar_of "$W3") $((sx + 3)) $((sy + sh / 2)) --no-release
echo "held: pointer $(pointer where), window $(real_frame_of "$W3"); preview: $(has_overlay 3 && echo yes || echo no)"
ARBOR_SETTLE=0 shot saver-1-held
release
sleep 2
echo "ScreenSaverEngine: $(pgrep -x ScreenSaverEngine | tr '\n' ' ')"
pointer windows --on-screen | head -n 12
summary
since "$mark"
shot saver-2-after
arbor_stop
