#!/bin/bash
# The product review's quick wins on real windows, with real key presses:
#
#   scripts/mac-shell/run.sh scripts/mac-shell/check-review-ux.sh
#
# ⌃⌥↩ twice, ⌃⌥0, ⌃⌥⇧F; ⌃⌥⎋ pauses (every window in view, no overlays, one shortcut left, a real drag to the edge
# docks nothing) and resumes (arrangement and view back, without a window closed meanwhile is left to the
# unit tests); ⌘Tab to an app whose focused window is out of view; the menu, running and paused;
# arborctl without Arbor. It also records, without judging, what a click on the wallpaper does to
# the windows ("Click wallpaper to reveal desktop", macOS 14 and later), for F42 and F14.
ARBOR_SHORTCUTS=all  # it presses keys of the whole map, of which nine ship
source "$(dirname "$0")/lib.sh"

paused() { "$ARBOR_BIN/arborctl" status | grep -q "^paused"; }
running() { "$ARBOR_BIN/arborctl" status | grep -q "^running"; }
no_overlays() { [ -z "$(overlays | awk '$8 == "on"')" ]; }
# But for the line that says what happened (F43, level 6).
only_the_line() { [ -z "$(overlays | awk '$8 == "on" && $3 != 6')" ]; }
logged() { grep -q "$1" "$ARBOR_HOME/arbor.log"; }
all_on_screen() { is on_screen "$W1" && is on_screen "$W2" && is on_screen "$W3"; }
in_slot() { [ "$(arbor_ask slot "$1")" = "$(frame_of "$1")" ]; }
# Not by name: on a person's Mac that is an app of theirs.
front() {
  case "$(pointer front 2>/dev/null)" in
    "$ARBOR_WINDOWS_PID") echo "the test windows' app" ;;
    "$ARBOR_PID") echo "Arbor" ;;
    "") echo "nobody says" ;;
    *) echo "another app" ;;
  esac
}
# Where the window server has a window's title bar: Arbor's own state lists no windows during a pause.
real_titlebar_of() {
  local x y w h
  read -r x y w h <<< "$(real_frame_of "$1")"
  echo "$((${x%.*} + ${w%.*} / 2)) $((${y%.*} + 12))"
}

arbor_build
step "three windows: [1 | Desktop | 2 / 3], shortcuts and the menu bar item on"
# An ordinary app, so that ⌘Tab can switch to it.
ARBOR_TEST_WINDOWS_ARGS="--regular"
arbor_start 3 ARBOR_NO_HOTKEYS=0 ARBOR_NO_STATUS_ITEM=0
ctl dock "$W1" left
ctl dock "$W2" right
ctl dock "$W3" beside "$W2" bottom
summary
grep "registered" "$ARBOR_HOME/arbor.log" | tail -n 2

step "the frame shortcut, twice"
# shellcheck disable=SC2046
click $(center_of "$W3")
key ctrl+opt+return
check "⌃⌥↩ frames the focused window: the others go out of view" eventually is parked "$W1"
key ctrl+opt+return
check "⌃⌥↩ again returns to everything" eventually all_on_screen

step "home, and the neighbour with ⇧"
ctl zoom "$W1"
check "framed on 1" eventually is parked "$W3"
key ctrl+opt+shift+right
check "⌃⌥⇧→ moves to the neighbouring space (the Desktop): 1 goes out of view" eventually is parked "$W1"
key ctrl+opt+0
check "⌃⌥0 shows everything" eventually all_on_screen

step "the menu while running"
# The item is a row of buttons, and its middle is Show the Desktop: a secondary click opens the menu wherever it lands.
# shellcheck disable=SC2046
rightclick $(status_item)
shot 01-menu-running
key escape

step "pause with ⌃⌥⎋ while framed"
ctl zoom "$W3"
check "1 and 2 are out of view" eventually is parked "$W1"
shot 02-framed
key ctrl+opt+escape
check "status says paused" eventually paused
check "every window is back in view" eventually all_on_screen
check "of Arbor's own windows only the line that says so is on screen" eventually only_the_line
# "Paused until ⌃⌥⎋…" stays just under four seconds and goes by itself, which is about as long as `eventually` has patience: on
# a Mac that was a race, and in a rehearsal, where short waits take no time, it was lost.
sleep 4
check "none of Arbor's own windows is on screen" eventually no_overlays
check "only the shortcut that ends the pause is registered" eventually logged "registered 1 shortcuts"
shot 03-paused
ctl status
ctl dock "$W1" right
"$ARBOR_BIN/arborctl" state | python3 -c 'import json, sys; s = json.load(sys.stdin)["state"]; print("state: paused", s["paused"], "running", s["running"], "windows", len(s["windows"]))'

step "while paused Arbor reacts to nothing"
before=$(real_frame_of "$W2")
key ctrl+opt+space
key ctrl+opt+shift+f
# A pause gives every window its own frame back (Q21), and there window 1 lies under the others: it comes to the front first, by a click low in it, or
# the drag takes hold of another window's content and drags nothing.
read -r x y w h <<< "$(real_frame_of "$W1")"
click $((x + 30)) $((y + h - 30))
own=$(real_frame_of "$W1")
# shellcheck disable=SC2046
drag $(real_titlebar_of "$W1") 3 400 --no-release
check "a real drag to the left edge shows no preview" no_overlays
release
sleep 1
check "the drag was one: window 1 is somewhere else" test "$(real_frame_of "$W1")" != "$own"
check "still paused" paused
check "window 2 has not moved" test "$(real_frame_of "$W2")" = "$before"
echo "window 1 was left where it was dropped: $(real_frame_of "$W1")"
shot 04-dragged-while-paused
# The keyboard goes back to the window that was framed, or the resume would rightly follow it to window 1.
read -r x y w h <<< "$(real_frame_of "$W3")"
click $((x + w - 30)) $((y + h - 30))

step "the menu while paused"
# Asked again: paused, the item is one glyph, somewhere else.
# shellcheck disable=SC2046
rightclick $(status_item)
shot 05-menu-paused
key escape

step "resume with ⌃⌥⎋"
key ctrl+opt+escape
check "status says running" eventually running
check "the view is back on 3: 1 is out of view again" eventually is parked "$W1"
check "2 is out of view again" eventually is parked "$W2"
check "3 is docked and in view" eventually is on_screen "$W3"
check "all the shortcuts are registered again" test "$(grep -c "registered [0-9][0-9] shortcuts" "$ARBOR_HOME/arbor.log")" -ge 2
summary
shot 06-resumed
key ctrl+opt+space
check "⌃⌥Space works again" eventually all_on_screen
check "window 1, dragged away during the pause, is back in its slot" eventually in_slot "$W1"

step "a timed pause"
ctl pause 0.05
check "paused" paused
sleep 4
check "it resumed by itself after three seconds" eventually running

step "for the record: what a click on the wallpaper does"
for key_name in EnableStandardClickToShowDesktop EnableTilingByEdgeDrag EnableTopTilingByEdgeDrag \
  EnableTilingOptionAccelerator GloballyEnabled; do
  echo "com.apple.WindowManager $key_name: $(defaults read com.apple.WindowManager "$key_name" 2>&1 | tail -n 1)"
done
ctl home
read -r dx dy dw dh <<< "$(arbor_ask desktop)"
wall_x=$((dx + dw / 2))
wall_y=$((dy + dh / 2))
echo "the Desktop is at $dx $dy $dw $dh and nothing floats on it; clicking its middle"
# shellcheck disable=SC2046
click $(center_of "$W2")
check "2 has the focus" eventually is focused "$W2"
click "$wall_x" "$wall_y"
sleep 1
shot 07-after-wallpaper-click
echo "in front: $(front)"
for id in $ARBOR_WINDOW_IDS; do
  echo "window $id: window server $(real_frame_of "$id"), share on screen $(pointer visible "$id"), Arbor $(frame_of "$id")"
done
# If the first click sent the windows away, the second brings them back; otherwise it does nothing.
click "$wall_x" "$wall_y"
sleep 1
shot 08-after-second-click
check "every window is in view after the second click" eventually all_on_screen

step "float all with ⌃⌥⇧F"
ctl zoom "$W1"
check "framed on 1" eventually is parked "$W2"
key ctrl+opt+shift+f
check "nothing is docked" eventually is floating "$W1"
check "every window is in view" eventually all_on_screen

step "arborctl without Arbor"
arbor_stop 11-after-quit
check "help needs no running Arbor" sh -c "'$ARBOR_BIN/arborctl' help | grep -q 'pause \[minutes\]'"
"$ARBOR_BIN/arborctl" status
echo "exit code $?"

step "a window that cannot grow sits in the middle of its slot"
ARBOR_TEST_WINDOWS_ARGS="--max-size 1:300x240"
arbor_start 2
# The first session's app has just left the Dock, which is still shrinking: that changes the visible
# frame, and with it every slot, for a second or so.
sleep 3
ctl dock "$W1" left
ctl dock "$W2" right
read -r sx sy sw sh <<< "$(arbor_ask slot "$W1")"
read -r fx fy fw fh <<< "$(frame_of "$W1")"
echo "slot $sx $sy $sw $sh, window $fx $fy $fw $fh, window server $(real_frame_of "$W1")"
check "it kept its own width" test "$fw" -le 300
check "it is centred across" test "$((fx + fw / 2 - sx - sw / 2))" -ge -2 -a "$((fx + fw / 2 - sx - sw / 2))" -le 2
check "it is centred down" test "$((fy + fh / 2 - sy - sh / 2))" -ge -2 -a "$((fy + fh / 2 - sy - sh / 2))" -le 2
shot 12-cannot-grow
ctl resize "$W2" left 40
echo "slot $(arbor_ask slot "$W1"), window $(frame_of "$W1")"
check "it stays put when a neighbour's other edge moves" test "$(frame_of "$W1")" = "$fx $fy $fw $fh"
arbor_stop

step "⌘Tab to an app whose focused window is out of view"
# ⌘Tab leads to the app that was used before, whoever's it is, so the net declines it on a person's Mac.
if ! on_throwaway_mac; then
  echo "skipped: ⌘Tab is not pressed on somebody's Mac"
  exit 0
fi
# Another app with a window Arbor knows has the keyboard meanwhile. (From the Desktop it does not work: a command that moves the view while
# no window Arbor knows has the keyboard gives it to a window in view, and then there is nothing left for ⌘Tab to find.)
mkfifo "$ARBOR_SESSION_DIR/other-stdin"
"${ARBOR_TEST_WINDOWS_2:-$ARBOR_BIN/ArborTestWindows}" --count 1 --regular < "$ARBOR_SESSION_DIR/other-stdin" > "$ARBOR_SESSION_DIR/other-hello" \
  2>> "$ARBOR_OUT/test-windows.log" 9>&- &
OTHER_PID=$!
started "$OTHER_PID"
exec 8> "$ARBOR_SESSION_DIR/other-stdin"
said() { [ -s "$ARBOR_SESSION_DIR/other-hello" ]; }
eventually said || die "the second app did not report its window"
OTHER=$(python3 -c 'import json, sys; print(json.loads(sys.argv[1])["windows"][0])' "$(head -n 1 "$ARBOR_SESSION_DIR/other-hello")") \
  || die "the second app did not report its window"
ARBOR_EXTRA_PIDS=$OTHER_PID
ARBOR_TEST_WINDOWS_ARGS="--regular"
arbor_start 2
sleep 3
ctl dock "$W1" left
ctl dock "$W2" right
ctl dock "$OTHER" beside "$W2" bottom
# shellcheck disable=SC2046
click $(center_of "$W2")
check "2 is its app's focused window" eventually is focused "$W2"
# shellcheck disable=SC2046
click $(center_of "$OTHER")
check "the other app has the keyboard" eventually is focused "$OTHER"
ctl zoom "$OTHER"
check "2 is out of view, its app in the background" eventually is parked "$W2"
echo "in front: $(front)"
shot 13-before-cmd-tab
key cmd+tab
sleep 0.5
echo "in front: $(front)"
check "⌘Tab to its app brings 2 back into view" eventually is on_screen "$W2"
summary
arbor_stop 14-after-cmd-tab
exec 8>&-
ended "$OTHER_PID" 30 || kill_started "$OTHER_PID"
