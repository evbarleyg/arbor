# What reality-dock-left.sh, reality-dock-right.sh and reality-second-display.sh share. Read in before reality.sh, which reads lib.sh in; nothing here runs until reality.sh calls reality_before. Do not run it.
#
# reality.sh plays its journeys on a hosted Mac as it comes: one display, the Dock at the bottom. That a docked window fills its slot again (the board, 0.19) was seen there. These ask
# the same of a Mac with the Dock at the left, of one with it at the right, and of one with a second display. Compare Mac with Mac: reality.sh plain, first, in the same run; a rehearsal has one display and the Dock at the bottom.

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
    printf '%s\n' '#!/bin/bash' 'case "$(defaults read com.apple.dock orientation 2>/dev/null)" in left) echo "screen 0 0 1024 768 visible 63 0 961 737" ;; right) echo "screen 0 0 1024 768 visible 0 0 961 737" ;; *) echo "screen 0 0 1024 768 visible 0 63 1024 674" ;; esac' \
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
# Whether the main screen's visible frame begins right of the screen's left edge, or ends left of its right edge: the Dock stands there.
dock_stands() {
  case "$1" in
    left) "$REALITY_SCREENS" | awk 'NR == 1 { exit !($7 > $2) }' ;;
    right) "$REALITY_SCREENS" | awk 'NR == 1 { exit !($7 + $9 < $2 + $4) }' ;;
  esac
}

# dock_to left|right
dock_to() {
  needs_throwaway_mac "move the Dock to the $1 and restart it"
  step "the Dock goes to the $1"
  screens_tool
  the_mac_now "as it comes"
  if on_throwaway_mac; then
    # As it comes the key is not set, which means the bottom.
    at_exit 'defaults delete com.apple.dock orientation 2>/dev/null; killall Dock 2>/dev/null'
    defaults write com.apple.dock orientation -string "$1"
    killall Dock
  fi
  check "the Dock stands at the $1: the visible frame leaves room at that edge of the screen" eventually dock_stands "$1"
  sleep 3
  the_mac_now "with the Dock at the $1"
  shot "00-dock-$1"
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

# MARK: Out of view, beside a Dock at the side (the board, 1.95). Called after the journeys, with the Dock still where dock_to has put it.

# With the Dock at the right every window Arbor took out of view, asked to 1023 767, rested at 934 740: by its frame a piece 40 wide and 28 high, with its three buttons, lay in the visible
# frame. That is geometry. Part 1 takes the picture. Part 2 asks macOS alone, through Accessibility as Arbor does, how far it lets a window go at the left and at the bottom, and takes a picture of each.
out_of_view_beside_the_dock() {
  local tool="$ARBOR_ROOT/.build/mac-shell/apptool" name
  step "out of view, 1: what is to be seen of a window that Arbor has taken out of view"
  if [ -z "${ARBOR_REHEARSAL:-}" ]; then
    swiftc -swift-version 5 "$ARBOR_ROOT/scripts/mac-shell/apptool.swift" -o "$tool" > "$ARBOR_OUT/build-apptool.log" 2>&1 || die "apptool.swift did not compile: build-apptool.log"
  fi
  # Every launch is recorded, so that the trace says whether Arbor asked anything of a window during its pause.
  ARBOR_RECORD=1
  arbor_start 3
  ctl dock "$W1" left
  ctl dock "$W2" right
  ctl zoom "$W1"
  sleep 1
  for name in W2 W3; do
    eval "echo \"out of view: $name \$(real_frame_of \"\$$name\"), \$(arbor_share_in_view \"\$$name\" 2>&1) hundredths of it on a display, by its frame\""
  done
  shot 10-out-of-view
  step "out of view, 2: how far macOS lets a window go. Arbor is paused and asks nothing"
  ctl show-all
  ctl float "$W2"
  ctl pause
  sleep 1
  "$ARBOR_BIN/arborctl" status | head -n 1
  # asked <name> <x> <y>: W2, at its own size.
  asked() {
    local took
    took=$("$tool" set-frame "$W2" "$2" "$3" 480 348 2>&1)
    sleep 0.7
    echo "asked $1: $2 $3 480 348 | Accessibility says $took | the window server $(real_frame_of "$W2" 2>&1) | $(arbor_share_in_view "$W2" 2>&1) hundredths of it on a display, by its frame"
    shot "11-$1"
  }
  asked where-arbor-asks 1023 767
  asked in-the-middle 300 200
  asked a-point-at-the-left-at-the-bottom -479 767
  asked in-the-middle-again 300 200
  asked a-point-at-the-left-half-way-down -479 400
  asked in-the-middle-once-more 300 200
  asked wholly-off-at-the-left -600 767
  asked in-the-middle-a-fourth-time 300 200
  asked at-the-bottom-alone 300 767
  asked in-the-middle-a-fifth-time 300 200
  asked a-point-inside-the-visible-frame-at-the-right 973 767
  ctl resume
  arbor_stop
}
