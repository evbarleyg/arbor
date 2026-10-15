#!/bin/bash
# What a person asks of macOS about a docked window stays (board 0.24): the two acts of which the stand-ins only guess what macOS does.
#
#   scripts/mac-shell/run.sh --no-preflight "a real app's Window menu, which the fake Mac has not" scripts/mac-shell/check-asked-of-macos.sh
#
# probe-macos-own-moves.sh has shown on a Mac that ⌥-click on the green button, Window ▸ Zoom, Fill and Move & Resize ▸ Left stay. Two rulings came
# after it, from playing against the stand-ins (Controller+AskedOfMacOS.swift):
#
#   A slot's size is never a window's own. Window ▸ Center moves a window and gives it no size: it is let be, as large as its slot. Quit gives back
#   what Arbor took: its own size, where it lies.
#
#   Nobody is let be on another display than its own. Window ▸ Move to <the other display>: it leaves the arrangement and floats where macOS put
#   it, in its own size; the neighbour is moved once at the most; and a key that names another window leaves it there.
#
# What is not known until a Mac has said it: whether Center keeps the size; what Move to… makes of the size, on a lower display above all; how
# long after the click the first frame comes. So every frame is printed, and where macOS does something else the checks say so.
source "$(dirname "$0")/lib-day.sh"
source "$(dirname "$0")/lib-menus.sh"
needs_throwaway_mac "open TextEdit, ask System Events where its menus are, and plug in a virtual display"

size_of() { echo "$1" | awk '{ print $3, $4 }'; }
# near "<a b>" "<a b>" <points>: both numbers within so many points.
near() { echo "$1 $2 $3" | awk '{ exit !(($1 - $3 <= $5 && $3 - $1 <= $5) && ($2 - $4 <= $5 && $4 - $2 <= $5)) }'; }
# The middle of its top edge, which is where it lies for whoever looks at its title bar.
top_middle_of() { echo "$1" | awk '{ print $1 + $3 / 2, $2 }'; }
same() { [ "$1" = "$2" ]; }
# frames_set_on <window> <trace>: how many frames Arbor set on it while the trace ran.
frames_set_on() { grep -c -E "\"call\":\"setFrame\".*\"id\":$1[,}]" "$2"; }

# text_edit: opens it as a person does. Sets PID; its window is A once Arbor runs.
text_edit() {
  open -a TextEdit 2> /dev/null || { echo "TextEdit: cannot open"; return 1; }
  sleep 4
  PID=$(pgrep -x TextEdit | head -n 1)
  [ -n "$PID" ] || { echo "TextEdit is not running"; return 1; }
  apps_remember "$PID"
}
# Asked to quit, and not killed: macOS restores the windows of an app that was killed, in the frames it saved, which may be a slot's.
text_edit_quits() {
  app_quit "$PID"
  sleep 2
}
# brought_forward: an app's menu is its own only while it is in front, and docking another window has just brought that one forward.
brought_forward() {
  click_window "$A" || check "TextEdit's window can be clicked" false
  sleep 2
  check "TextEdit is in front" front_is "$PID"
}
# move_to_item: what the Window menu calls it, once the menu has been open and macOS has filled it in.
move_to_item() {
  arbor_within 10 osascript -e 'tell application "System Events" to tell process "TextEdit" to get name of first menu item of menu 1 of menu bar item "Window" of menu bar 1 whose name begins with "Move to "' 2> /dev/null
}
its_window() {
  state | python3 -c '
import json, sys
print(next((w["id"] for w in json.load(sys.stdin)["windows"] if w["managed"] and w["pid"] == int(sys.argv[1])), ""))' "$PID"
}
# the_trace <name>: where lib.sh has put the trace of that name.
the_trace() { ls "$ARBOR_HOME"/traces/*"$1".jsonl 2> /dev/null | tail -n 1; }

day_build

step "session: Center, and Quit"
if text_edit; then
  arbor_settings '{}'
  ARBOR_EXTRA_PIDS=$PID
  arbor_start 1
  A=$(its_window)
  if [ -n "$A" ]; then
    own=$(real_frame_of "$A")
    echo "its own frame, before Arbor has touched it: $own"
    ctl dock "$A" left
    ctl dock "$W1" right
    sleep 2
    slot=$(real_frame_of "$A")
    beside=$(real_frame_of "$W1")
    echo "in its slot: $slot"
    check "its slot's size is not its own, or this says nothing" not near "$(size_of "$slot")" "$(size_of "$own")" 4
    brought_forward

    step "Window ▸ Center"
    ctl trace on asked-center
    if menu_pick TextEdit Center; then
      sleep 2
      centred=$(real_frame_of "$A")
      echo "macOS put it at: $centred"
      check "macOS moved it" not same "$centred" "$slot"
      check "and gave it no size" near "$(size_of "$centred")" "$(size_of "$slot")" 4
      sleep 3
      check "five seconds later it is where macOS put it" same "$(real_frame_of "$A")" "$centred"
      check "docked as before" is docked "$A"
      check "and let be" is letBe "$A"
      check "the neighbour did not move" same "$(real_frame_of "$W1")" "$beside"
      ctl trace off
      check "Arbor set no frame on it" same "$(frames_set_on "$A" "$(the_trace asked-center)")" 0
      shot centred

      step "Quit"
      arbor_quit
      sleep 1
      after=$(real_frame_of "$A")
      echo "after Quit: $after"
      check "it has its own size again" near "$(size_of "$after")" "$(size_of "$own")" 2
      check "where it lies: the middle of its title bar is where it was" near "$(top_middle_of "$after")" "$(top_middle_of "$centred")" 20
      check "the neighbour has its own size again" not same "$(real_frame_of "$W1")" "$beside"
      shot after-quit
      arbor_relaunch
    else
      ctl trace off
      check "Window ▸ Center could be played" false
    fi
  else
    check "TextEdit has a window that Arbor arranges" false
  fi
  arbor_stop
  ARBOR_EXTRA_PIDS=""
  text_edit_quits
else
  check "TextEdit opens" false
fi

step "session: Move to the other display"
if text_edit; then
  arbor_settings '{}'
  ARBOR_EXTRA_PIDS=$PID
  # With its shortcuts, which the harness leaves out unless asked: the last step presses one.
  arbor_start 2 ARBOR_NO_HOTKEYS=0
  # Lower than the main one's slots are high, which is the harder case: does macOS cut what does not fit?
  display_add 1280 600 right
  A=$(its_window)
  if [ -n "$A" ]; then
    own=$(real_frame_of "$A")
    echo "its own frame, before Arbor has touched it: $own"
    ctl dock "$A" left
    ctl dock "$W1" right
    sleep 2
    slot=$(real_frame_of "$A")
    beside=$(real_frame_of "$W1")
    echo "in its slot: $slot; the other display shows $(screen_of 2)"
    check "its slot's size is not its own, or this says nothing" not near "$(size_of "$slot")" "$(size_of "$own")" 4
    brought_forward

    step "Window ▸ Move to Arbor Test Display"
    ctl trace on asked-move-to
    if menu_pick TextEdit "Move to Arbor Test Display" || { item=$(move_to_item) && [ -n "$item" ] && echo "it is called \"$item\"" && menu_pick TextEdit "$item"; }; then
      sleep 0.2
      echo "0.2 s after the click: $(real_frame_of "$A")"
      sleep 3
      there=$(real_frame_of "$A")
      echo "three seconds later: $there"
      ctl trace off
      summary
      check "it is on the other display" inside "$there" "$(display_frame_of 2)"
      check "it has left the arrangement" not is docked "$A"
      check "and floats" is floating "$A"
      check "nobody is let be there" not is letBe "$A"
      check "in its own size" near "$(size_of "$there")" "$(size_of "$own")" 2
      check "Arbor set one frame on it at the most" test "$(frames_set_on "$A" "$(the_trace asked-move-to)")" -le 1
      # What room there is to take is the arrangement's business: without a column for the Desktop the one window that is left keeps its half.
      echo "the neighbour was at $beside and is at $(real_frame_of "$W1")"
      check "the neighbour is in its slot" is in_slot "$W1"
      check "and was moved once at the most" test "$(frames_set_on "$W1" "$(the_trace asked-move-to)")" -le 1
      echo "what macOS reported of it, and what Arbor asked of it:"
      grep -E "\"id\":$A[,}]" "$(the_trace asked-move-to)" | grep -E '"event":"changed"|"call":"setFrame"' | cut -c 1-170 | head -n 20
      shot moved-to-the-other-display

      step "a key that names another window"
      click_window "$W2" || check "the other window can be clicked" false
      sleep 1.5
      key_to "$W2" ctrl+opt+left
      sleep 3
      check "the other window is docked" is docked "$W2"
      check "and this one is where its person sent it" same "$(real_frame_of "$A")" "$there"
      shot after-the-key
    else
      ctl trace off
      echo "the Window menu's items:"
      arbor_within 10 osascript -e 'tell application "System Events" to tell process "TextEdit" to get name of menu items of menu 1 of menu bar item "Window" of menu bar 1' 2> /dev/null
      check "Window ▸ Move to Arbor Test Display could be played" false
    fi
  else
    check "TextEdit has a window that Arbor arranges" false
  fi
  arbor_stop
  display_remove
  ARBOR_EXTRA_PIDS=""
  text_edit_quits
else
  check "TextEdit opens" false
fi
exit 0
