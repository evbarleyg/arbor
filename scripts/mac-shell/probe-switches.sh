#!/bin/bash
# When does macOS obey its own switches under Desktop & Dock, if somebody other than System Settings writes them?
# Nothing here is a check: the output is the point.
#
#   scripts/mac-shell/run.sh scripts/mac-shell/probe-switches.sh
#
# Four things macOS does with a drag or a click are tried again and again: a window held at the left edge, at the menu bar, anywhere
# with ⌥ down, and a click on the wallpaper. First as the Mac comes; then after `defaults write … false` alone; after WindowManager was
# restarted; after the keys were deleted again; after another restart; and the same written by a program, as an app would.
# Arbor is paused throughout: the question is macOS's.
source "$(dirname "$0")/lib.sh"
needs_throwaway_mac "switch macOS's own tiling and the wallpaper click off and on"

arbor_build
DOMAIN=com.apple.WindowManager
KEYS="EnableTilingByEdgeDrag EnableTopTilingByEdgeDrag EnableTilingOptionAccelerator EnableStandardClickToShowDesktop"

step "the Mac"
sw_vers
defaults read $DOMAIN 2>&1
echo "WindowManager: $(pgrep -x WindowManager | tr '\n' ' ')"
ls -l ~/Library/Preferences/$DOMAIN.plist 2>&1
binary=/System/Library/CoreServices/WindowManager.app/Contents/MacOS/WindowManager
ls -l "$binary" 2>&1
echo "what it says about its settings:"
strings -a "$binary" 2>/dev/null | grep -i -E "EnableTil|EnableTopTil|EnableStandardClick|defaultsDidChange|UserDefaults|notify|prefs" | sort -u | head -n 60

arbor_start 3
ctl pause

strangers() {
  pointer windows | awk -v arbor="$ARBOR_PID" '$8 == "on" && $2 != arbor' \
    | grep -v -E " (ArborTestWindows|Dock|Finder|Window Server|Control Center|Spotlight|Notification Center|Wallpaper)$"
}
grab_of() {
  local x y w h left right
  read -r x y w h <<< "$(real_frame_of "$1")"
  x=${x%.*}; y=${y%.*}; w=${w%.*}
  left=$x; right=$((x + w))
  [ "$left" -lt 0 ] && left=0
  [ "$right" -gt 1024 ] && right=1024
  echo "$(((left + right) / 2)) $((y + 12))"
}
frames() { echo "$(real_frame_of "$W1") | $(real_frame_of "$W2") | $(real_frame_of "$W3")"; }

# to <name> <x> <y> [options]: W3 from the middle of the display to that point, held, let go
to() {
  local name=$1 x=$2 y=$3 preview
  shift 3
  # shellcheck disable=SC2046
  drag $(grab_of "$W3") 512 300 > /dev/null
  sleep 0.5
  # shellcheck disable=SC2046
  drag $(grab_of "$W3") "$x" "$y" --hold 1.2 --no-release "$@" > /dev/null
  preview=$(strangers | awk '{ print $9, $4, $5, $6, $7 }' | sort -u | tr '\n' ';')
  release "$@" > /dev/null
  sleep 1.5
  echo "$name: preview [${preview}] ended at $(real_frame_of "$W3")"
}

wallpaper() {
  local before after
  # shellcheck disable=SC2046
  drag $(grab_of "$W3") 512 300 > /dev/null
  sleep 0.5
  before=$(frames)
  click 1010 400 > /dev/null
  sleep 1.5
  after=$(frames)
  if [ "$before" = "$after" ]; then echo "wallpaper click: nothing moved"; else
    echo "wallpaper click: SWEPT: $before -> $after"
    click 1010 400 > /dev/null
    sleep 1.5
    echo "  a second click: $(frames)"
  fi
}

all_four() {
  step "$1"
  for name in $KEYS; do echo "  $name: $(defaults read $DOMAIN "$name" 2>/dev/null || echo "not set")"; done
  to "left edge" 0 368
  to "menu bar" 512 0
  to "with ⌥" 200 368 --mods opt
  wallpaper
}

restart() {
  local old new before began waited=0
  step "WindowManager is restarted"
  old=$(pgrep -x WindowManager | head -n 1)
  before=$(frames)
  began=$(arbor_now)
  killall WindowManager & film "$1" 6
  while [ "$waited" -lt 50 ]; do
    new=$(pgrep -x WindowManager | head -n 1)
    [ -n "$new" ] && [ "$new" != "$old" ] && break
    sleep 0.1
    waited=$((waited + 1))
  done
  echo "pid $old -> ${new:-none} after $waited tenths (from $began to $(arbor_now))"
  sleep 1
  [ "$before" = "$(frames)" ] && echo "no window moved" || echo "WINDOWS MOVED: $before -> $(frames)"
  echo "in front: $(pointer front)"
}

echo "the windows: $(frames)"
pointer windows --on-screen
all_four "1. as the Mac comes"

for name in $KEYS; do defaults write $DOMAIN "$name" -bool false; done
sleep 1
all_four "2. defaults write false, nothing restarted, a second later"
sleep 10
all_four "3. the same, ten seconds later"
restart restart-1
all_four "4. after the restart"

for name in $KEYS; do defaults delete $DOMAIN "$name"; done
sleep 1
all_four "5. the keys deleted again, nothing restarted"
restart restart-2
all_four "6. after the restart"

step "written by a program, as an app would"
scratch_dir switches TOOL_DIR
cat > "$TOOL_DIR/set.swift" <<'SWIFT'
import Foundation
let value = CommandLine.arguments[1]
let keys = Array(CommandLine.arguments.dropFirst(2))
let domain = "com.apple.WindowManager" as CFString
for key in keys {
  let new: CFPropertyList? = value == "delete" ? nil : (value == "true") as CFBoolean
  CFPreferencesSetAppValue(key as CFString, new, domain)
}
print("synchronized:", CFPreferencesAppSynchronize(domain))
SWIFT
swiftc -O "$TOOL_DIR/set.swift" -o "$TOOL_DIR/set" 2>&1 | tail -n 5
# shellcheck disable=SC2086
"$TOOL_DIR/set" false $KEYS
sleep 1
all_four "7. CFPreferencesSetAppValue false, nothing restarted"
restart restart-3
all_four "8. after the restart"
# shellcheck disable=SC2086
"$TOOL_DIR/set" true $KEYS
sleep 1
all_four "9. CFPreferencesSetAppValue true, nothing restarted"
# shellcheck disable=SC2086
"$TOOL_DIR/set" delete $KEYS
restart restart-4
all_four "10. deleted and restarted: as the Mac came"
defaults read $DOMAIN 2>&1
ctl resume
arbor_stop
