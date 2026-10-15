#!/bin/bash
# F02, animated transitions, on real windows: catches the stage in mid-motion and checks that it always
# comes down. Run it with
#
#   scripts/mac-shell/run.sh scripts/mac-shell/shots-F02.sh
#
# The tour plays everything slowly (1.2 s), so that a few pictures show the way things travel: docking,
# zooming in and out, moving to a neighbour, a window that refuses its slot and ends as a tile, unfolding
# that tile, the Desktop, a second command in mid-motion, a click in mid-motion.
# Then the real thing at 0.46 s; the look without pictures of windows, as without Screen Recording
# permission; and the motion switched off, by the setting and by macOS's "Reduce motion".
source "$(dirname "$0")/lib.sh"

# The stage is the only window of Arbor's at this level (one above floating).
stage_up() { has_overlay 4; }
stage_down() { ! has_overlay 4; }
alive() { kill -0 "$ARBOR_PID" 2>/dev/null; }
# Whether this is one of GitHub's throwaway Macs. Only there does the script touch system settings or
# collect crash reports.
throwaway() { [ "${GITHUB_ACTIONS:-}" = true ]; }

# slowly <name> <command…>: runs the command and takes seven pictures of it, about 0.2 s apart.
slowly() {
  local name=$1 index=1
  shift
  alive || { echo "Arbor is gone: no pictures of $name"; return 1; }
  ctl "$@" &
  while [ "$index" -le 7 ]; do
    arbor_capture "$name-$index"
    sleep 0.13
    index=$((index + 1))
  done
  wait $!
  echo "pictures: mac-shell/$name-1.png … $name-7.png"
  check "$name: the stage comes down" eventually stage_down
}

# quickly <name> <command…>: the same, seven pictures as fast as they can be taken.
quickly() {
  local name=$1
  shift
  alive || { echo "Arbor is gone: no pictures of $name"; return 1; }
  ctl "$@" &
  film "$name" 7
  wait $!
  check "$name: the stage comes down" eventually stage_down
}

# Copies the reports of Arbor's crashes, if any, to where they come back from.
crash_reports() {
  throwaway || return 0
  sleep 5
  find "$HOME/Library/Logs/DiagnosticReports" /Library/Logs/DiagnosticReports -name "Arbor*" 2>/dev/null | while read -r report; do
    cp "$report" "$ARBOR_OUT/crash-$(basename "$report").txt"
    echo "crash report: mac-shell/crash-$(basename "$report").txt"
  done
}

# "Reduce motion" is a setting of the person's. GitHub's Macs have it on, which switches the motion off.
reduce_motion() {
  throwaway || return 0
  defaults write com.apple.universalaccess reduceMotion -bool "$1"
  echo "Reduce motion: $(defaults read com.apple.universalaccess reduceMotion 2>&1 | tail -n 1)"
}

# Until lib.sh has its own `wallpaper gradient`: a gradient with a line every 100 points, which shows at once
# whether the stage's picture of the desktop sits where the desktop is.
if ! type wallpaper > /dev/null 2>&1; then
  wallpaper() {
    cat > "$ARBOR_SESSION_DIR/wallpaper.swift" <<'SWIFT'
import AppKit
let screen = NSScreen.screens[0]
let size = screen.frame.size
let image = NSImage(size: size, flipped: true) { rect in
  NSGradient(starting: NSColor(red: 0.11, green: 0.17, blue: 0.39, alpha: 1), ending: NSColor(red: 0.97, green: 0.63, blue: 0.25, alpha: 1))!
    .draw(in: rect, angle: 60)
  NSColor.white.withAlphaComponent(0.5).setFill()
  for x in stride(from: 0, to: size.width, by: 100) { NSRect(x: x, y: 0, width: 1, height: size.height).fill() }
  for y in stride(from: 0, to: size.height, by: 100) { NSRect(x: 0, y: y, width: size.width, height: 1).fill() }
  return true
}
let url = URL(fileURLWithPath: CommandLine.arguments[1])
try NSBitmapImageRep(data: image.tiffRepresentation!)!.representation(using: .png, properties: [:])!.write(to: url)
for screen in NSScreen.screens { try NSWorkspace.shared.setDesktopImageURL(url, for: screen, options: [:]) }
SWIFT
    swiftc -swift-version 5 "$ARBOR_SESSION_DIR/wallpaper.swift" -o "$ARBOR_ROOT/.build/mac-shell/wallpaper" 2>&1 | tail -n 5
    "$ARBOR_ROOT/.build/mac-shell/wallpaper" "$ARBOR_ROOT/.build/mac-shell/wallpaper-gradient.png"
    echo "> wallpaper $1: exit code $?"
    sleep 1.5
  }
fi

arbor_build
grep -E "warning:" "$ARBOR_OUT/build.log" | sort -u | head -n 40
echo "Screen Recording for a child process: $(pointer screen-access)"
# As it was, whatever ends the script: the next script on the same Mac must find the Mac as it would alone. (On its first run this one left Reduce Motion
# off, and the two scripts after it ran with stages that they would not have had.)
motion_before=$(defaults read com.apple.universalaccess reduceMotion 2>/dev/null)
at_exit 'reduce_motion "$([ "$motion_before" = 1 ] && echo true || echo false)"'
reduce_motion false
throwaway && wallpaper gradient
if ! throwaway && [ "$(defaults read com.apple.universalaccess reduceMotion 2>/dev/null)" = 1 ]; then
  echo "Reduce motion is on (System Settings, Accessibility, Motion): there will be no stage to look at"
fi

# The third window refuses to be smaller than 700×500, so a small slot turns it into a tile.
ARBOR_TEST_WINDOWS_ARGS="--min-size 3:700x500"

step "the tour"
arbor_settings "{\"animationDuration\": 1.2, $ARBOR_TILES_ON}"
arbor_start 4
sleep 2 # the first pictures of windows are taken 0.6 s after Arbor starts
check "Arbor is still running" alive
shot 10-start
slowly 11-dock-left dock "$W1" left
ctl dock "$W2" right
sleep 1.6
slowly 13-dock-below dock "$W4" beside "$W1" bottom
shot 14-overview
summary
slowly 15-zoom-in zoom "$W1"
shot 16-zoomed
check "the framed window is on screen" is on_screen "$W1"
check "the others are parked" is parked "$W2"
slowly 17-neighbour neighbor down
slowly 18-zoom-out show-all
slowly 20-refuses-its-slot dock "$W3" beside "$W2" bottom
ctl show-all
sleep 1.6
shot 21-tile
summary
if is tile "$W3"; then
  slowly 22-unfold-the-tile zoom "$W3"
  slowly 23-fold-it-again back
fi
slowly 24-desktop desktop
ctl back
sleep 1.6

step "a second command in mid-motion carries on from where things are"
ctl zoom "$W2"
sleep 0.2
slowly 26-retarget back

step "a click in mid-motion ends it"
arbor_settings '{"animationDuration": 2}'
ctl reload-settings
ctl zoom "$W1"
sleep 0.3
check "the stage is up in mid-motion" stage_up
# shellcheck disable=SC2046
click $(center_of "$W1")
shot_after 0.05 27-after-the-click
check "the click took the stage down" stage_down
ctl show-all
check "the stage comes down" eventually stage_down
arbor_stop 29-after-quit

step "the real thing: 0.46 s"
arbor_start 4
sleep 2
ctl dock "$W1" left
ctl dock "$W2" right
ctl dock "$W4" beside "$W1" bottom
sleep 1.5
shot 30-overview
quickly 31-zoom-in zoom "$W1"
sleep 1
quickly 32-zoom-out back
step "four commands in quick succession"
ctl zoom "$W2"
ctl back
ctl zoom "$W4"
quickly 33-quick show-all
shot 34-settled
overlays
arbor_stop

step "without pictures of windows"
arbor_settings '{"animationDuration": 1.2}'
arbor_start 4 ARBOR_NO_PICTURES=1
sleep 1
ctl dock "$W1" left
ctl dock "$W2" right
sleep 1.6
shot 40-overview
slowly 41-covers-zoom-in zoom "$W1"
slowly 42-covers-zoom-out back
arbor_stop

step "switched off by the setting"
arbor_settings '{"animationDuration": 0}'
arbor_start 3
ctl dock "$W1" left
ctl dock "$W2" right
ctl zoom "$W1" &
film 50-off 3
wait $!
check "there is no stage" stage_down
check "no stage was ever put up" test -z "$(grep "stage up" "$ARBOR_HOME/arbor.log")"
arbor_stop

if throwaway; then
  step "switched off by Reduce motion"
  reduce_motion true
  arbor_start 3
  ctl dock "$W1" left
  ctl dock "$W2" right
  ctl zoom "$W1"
  check "there is no stage" stage_down
  check "the framed window is on screen all the same" is on_screen "$W1"
  check "and the others are out of view" is parked "$W2"
  check "no stage was ever put up" test -z "$(grep "stage up" "$ARBOR_HOME/arbor.log")"
  check "the log says why" grep -q "Reduce motion is on" "$ARBOR_HOME/arbor.log"
  arbor_stop
  reduce_motion false
fi

crash_reports

step "what the logs say about stages and pictures"
grep -hE "stage|pictures:" "$ARBOR_OUT"/arbor*.log | cut -c 1-200 | head -n 200
