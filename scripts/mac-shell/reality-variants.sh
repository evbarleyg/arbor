# What reality-dock-left.sh and reality-second-display.sh share. Read in before reality.sh, which reads lib.sh in; nothing here runs until reality.sh calls reality_before. Do not run it.
#
# reality.sh plays its journeys on a hosted Mac as it comes: one display, the Dock at the bottom. That a docked window fills its slot again (the board, 0.19) was seen there. These ask
# the same of a Mac with the Dock at the left, and of one with a second display. Compare Mac with Mac: reality.sh plain, first, in the same run; a rehearsal has one display and the Dock at the bottom.

# the_mac_now <when>: each display's frame and what the menu bar and the Dock leave of it, in AppKit's coordinates (y up, from the main display's lower left corner), and the settings that matter.
the_mac_now() {
  echo "-- the Mac, $1"
  pointer displays | sed 's/^/  pointer displays: /'
  "$REALITY_SCREENS" | sed 's/^/  /'
  echo "  the Dock's orientation: $(defaults read com.apple.dock orientation 2>&1 | tail -n 1)"
  echo "  WindowManager: $(defaults read com.apple.WindowManager 2>&1 | tr -s ' \n' ' ')"
}
screens_tool() {
  REALITY_SCREENS="$ARBOR_ROOT/.build/mac-shell/screens"
  mkdir -p "$ARBOR_ROOT/.build/mac-shell"
  if [ -n "${ARBOR_REHEARSAL:-}" ]; then
    # No AppKit there, and a Dock that stays at the bottom: a rehearsal proves the bash of this file and nothing else.
    printf '%s\n' '#!/bin/bash' 'case "$(defaults read com.apple.dock orientation 2>/dev/null)" in left) echo "screen 0 0 1024 768 visible 63 0 961 737" ;; *) echo "screen 0 0 1024 768 visible 0 63 1024 674" ;; esac' \
      > "$REALITY_SCREENS"
    chmod +x "$REALITY_SCREENS"
    return
  fi
  cat > "$ARBOR_OUT/screens.swift" <<'SWIFT'
import AppKit
for screen in NSScreen.screens {
  let f = screen.frame, v = screen.visibleFrame
  print("screen \(Int(f.minX)) \(Int(f.minY)) \(Int(f.width)) \(Int(f.height)) visible \(Int(v.minX)) \(Int(v.minY)) \(Int(v.width)) \(Int(v.height))")
}
SWIFT
  swiftc -O -swift-version 5 "$ARBOR_OUT/screens.swift" -o "$REALITY_SCREENS" > "$ARBOR_OUT/build-screens.log" 2>&1 || die "the few lines that print the screens did not compile: build-screens.log"
}
# Whether the main screen's visible frame begins right of the screen's left edge: the Dock stands there.
dock_stands_left() { "$REALITY_SCREENS" | awk 'NR == 1 { exit !($7 > $2) }'; }

dock_to_the_left() {
  needs_throwaway_mac "move the Dock to the left and restart it"
  step "the Dock goes to the left"
  screens_tool
  the_mac_now "as it comes"
  if on_throwaway_mac; then
    # As it comes the key is not set, which means the bottom.
    at_exit 'defaults delete com.apple.dock orientation 2>/dev/null; killall Dock 2>/dev/null'
    defaults write com.apple.dock orientation -string left
    killall Dock
  fi
  check "the Dock stands at the left: the visible frame begins right of the screen's edge" eventually dock_stands_left
  sleep 3
  the_mac_now "with the Dock at the left"
  shot 00-dock-left
}

# lib.sh's display_add wants a session's folder, and here no session has begun: the display is to be there when Arbor starts. The variables are lib.sh's, so that display_move and display_remove work.
a_second_display() {
  local hello="" tries=0
  needs_throwaway_mac "plug in a virtual display, at which macOS rearranges every window"
  step "a second display to the right"
  screens_tool
  the_mac_now "as it comes"
  : > "$ARBOR_OUT/second-display.txt"
  "$ARBOR_VDISPLAY" add 1280 720 "Arbor Test Display" --serial 1 > "$ARBOR_OUT/second-display.txt" 2>> "$ARBOR_OUT/vdisplay.log" 9>&- 8>&- 3>&- &
  ARBOR_DISPLAY_PID=$!
  started "$ARBOR_DISPLAY_PID" # the end of the script unplugs it, after Arbor has quit: lib.sh
  while [ -z "$hello" ] && [ "$tries" -lt 80 ]; do
    sleep 0.1
    hello=$(head -n 1 "$ARBOR_OUT/second-display.txt")
    tries=$((tries + 1))
  done
  [ -n "$hello" ] || die "no virtual display ($(tail -n 1 "$ARBOR_OUT/vdisplay.log"))"
  DISPLAY2_ID=${hello%% *}
  DISPLAY2_UUID=${hello##* }
  DISPLAY2_SIZE="1280 720"
  check "macOS lists two displays" arbor_await_displays 2
  display_move right
  the_mac_now "with the second display"
  REALITY_SECOND_DISPLAY=1
  shot 00-second-display
}
