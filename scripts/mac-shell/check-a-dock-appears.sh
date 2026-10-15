#!/bin/bash
# A Dock appears under two rows of docked windows: is anybody's smallest height learnt from it, and is the arrangement what it was?
#
#   scripts/mac-shell/run.sh --no-preflight "<why>" scripts/mac-shell/check-a-dock-appears.sh
#
# Why no pre-flight: the fake Mac has no stand-in for showing and hiding the Dock.
#
# With the Dock hidden the lower row ends a gap above the display's bottom. Shown, the Dock lies under it: the windows' feet stand in its strip, where a size
# call that would still end in the strip is not obeyed (Sources/ArborCore/ScreenLines.swift). The lower row is sized where it stands and then moved, so
# it came to its slot too tall, and Arbor took that for its app's smallest height and made room for it: the upper row paid. Now that answer is
# the screen's: nothing is learnt from it, and the window is asked once more in its slot.
#
# Only on GitHub's Macs: it hides and shows the Dock, and puts it back as it was.
source "$(dirname "$0")/lib.sh"
needs_throwaway_mac "hide and show the Dock"

whole() { awk '{ for (i = 1; i <= NF; i++) printf "%d ", $i + 0.5 }' | sed 's/ $//'; }
now_at() { real_frame_of "$1" | whole; }
height() { now_at "$1" | cut -d' ' -f4; }
as_high_as_each_other() {
  local a b
  a=$(height "$W1") b=$(height "$W2")
  [ $((a - b)) -le 2 ] && [ $((b - a)) -le 2 ] || { echo "    the upper is $a high, the lower $b"; return 1; }
}
asked_of() { arbor_log_since "$ARBOR_STEP_MARK" | grep -E "w$1\b" | tail -n 8 | sed 's/^.*DEBUG /    (/; s/$/)/' || true; }

HIDDEN_WAS="$(defaults read com.apple.dock autohide 2> /dev/null || echo 0)"
dock_hidden() {
  defaults write com.apple.dock autohide -bool "$1"
  killall Dock
  sleep 5 # the Dock comes back, and the visible frame follows a moment later
  echo "> the Dock hidden: $1"
}
at_exit "dock_hidden $([ "$HIDDEN_WAS" = 1 ] && echo true || echo false)"

arbor_build
dock_hidden true
arbor_start 2
take "sx sy sw sh" screen_of 1
echo "with the Dock hidden the visible frame is $sx $sy $sw $sh"
ctl dock "$W1" left
ctl dock "$W2" beside "$W1" bottom
check "two rows are docked" eventually is in_slot "$W2"
check "as high as each other" as_high_as_each_other
echo "    the upper at $(now_at "$W1"), the lower at $(now_at "$W2")"

claim "the Dock appears under them"
dock_hidden false
# macOS does not always say that the Dock has changed; a layout looks.
ctl home > /dev/null
sleep 2
take "tx ty tw th" screen_of 1
echo "with the Dock shown the visible frame is $tx $ty $tw $th"
check "the visible frame is lower by more than the gap" test "$((sh - th))" -gt 12
check "the upper row is in its slot" eventually is in_slot "$W1"
check "the lower row is in its slot" eventually is in_slot "$W2"
check "they are as high as each other still: nobody's smallest height was learnt" as_high_as_each_other
check "and stay so" stays as_high_as_each_other
echo "    the upper at $(now_at "$W1"), the lower at $(now_at "$W2")"
summary
asked_of "$W1"
asked_of "$W2"
shot the-dock-has-appeared

arbor_stop
