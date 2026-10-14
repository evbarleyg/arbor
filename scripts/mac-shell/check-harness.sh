#!/bin/bash
# The harness itself on a real Mac: does lib.sh's supervision, its curtain and its nets work as they do against stand-ins on
# Linux (scripts/test-tooling.py)? The first script to run on a Mac that is somebody's, before any other.
#
#   bash scripts/mac-shell/check-harness.sh           about a minute after the build; the pointer is taken for some ten seconds
#
# What only a Mac can say: what ps, ioreg, pmset and lsappinfo answer there; whether a script gets a process group of its own;
# whether the curtain goes up over every display, stays behind the test windows when it is clicked, and goes down again;
# which app Accessibility says has the keyboard; whether keys and buttons that were left down are found and let go
# of; whether a picture can be taken; what the look at the Mac before and after the run finds.
#
# Safe on a person's Mac: two test windows and the curtain are all it opens. It presses on them and nowhere else, types nothing,
# holds ⌃⌥ for a moment with a test window in front, and changes no setting.
source "$(dirname "$0")/lib.sh"

not() { ! "$@"; }
says() { grep -q "$1" <<< "$2"; }
# The windows in front of the curtain, from the front: id pid layer owner. What lies behind it is somebody's and is not printed.
in_front_of_the_curtain() {
  pointer windows --on-screen | awk -v curtain="${ARBOR_CURTAIN_PID:-0}" '$2 == curtain { exit } { print "  " $1, $2, $3, $9, $10 }'
}
behind() {
  pointer windows --on-screen | awk -v front="$1" -v back="${ARBOR_CURTAIN_PID:-0}" '
    $1 == front { seen = 1 } $2 == back { exit !seen } END { if (!seen) exit 1 }'
}

step "what this Mac answers"
echo "bash $BASH_VERSION; macOS $(sw_vers -productVersion 2>/dev/null); script $$, supervisor $ARBOR_SUPERVISOR"
check "the script has a process group of its own" test "$(ps -o pgid= -p $$ | tr -d ' ')" = "$$"
check "the supervisor is in another" not test "$(ps -o pgid= -p "$ARBOR_SUPERVISOR" | tr -d ' ')" = "$$"
check "ps says when a process began" test -n "$(arbor_birth $$)"
check "this script began after the run did" arbor_started_here $$
check "launchd did not" not arbor_started_here 1
echo "seconds since anybody touched the keyboard or the pointer: $(ioreg -c IOHIDSystem 2>/dev/null | awk '/HIDIdleTime/ { print int($NF / 1000000000); exit }')"
# safe anywhere: -g only reads
echo "kept awake: $(pmset -g assertions 2>/dev/null | grep -E "PreventUserIdleDisplaySleep +[0-9]" | tr -s ' ')"
echo "input sources switched on: $(defaults read com.apple.HIToolbox AppleEnabledInputSources 2>/dev/null | grep -c InputSourceKind)"

step "folders and processes"
scratch_dir harness
check "scratch_dir made a folder under /tmp/arbor-" test -d "$SCRATCH_DIR"
check "scratch_remove refuses the home folder" not scratch_remove "$HOME"
sleep 300 &
mine=$!
check "a process of the script's own goes on record" started "$mine"
kill_started "$mine"
check "and kill_started ends it" not kill -0 "$mine"
check "limit ends a program and what it started" test "$(limit 1 sh -c 'sleep 30 & sleep 31'; echo $?)" = 124

arbor_build
step "a session: the curtain, then two test windows"
arbor_start 2 ARBOR_NO_HOTKEYS=1
if on_throwaway_mac && [ -z "${ARBOR_CURTAIN_PID:-}" ]; then
  echo "no curtain on a throwaway Mac (ARBOR_CURTAIN_HERE=1 hangs one): the rest is about the curtain and the nets"
  arbor_stop
  exit 0
fi
check "the curtain hangs" kill -0 "$ARBOR_CURTAIN_PID"
echo "between the menu bar and the Dock (x y w h, a line a display):"
sed 's/^/  /' "$ARBOR_LEDGER/visible"
echo "displays (id x y w h pixel-width pixel-height scale):"
pointer displays | sed 's/^/  /'
echo "in front of the curtain (id pid layer owner):"
in_front_of_the_curtain
check "both test windows are in front of it" behind "$W1"
check "both test windows are in front of it" behind "$W2"

step "a press on the curtain changes nothing"
read -r vx vy vw vh < "$ARBOR_LEDGER/visible"
check "it is let through" click $((vx + vw - 60)) $((vy + vh - 60))
sleep 0.5
check "the first test window is still in front of the curtain" behind "$W1"
check "the second too" behind "$W2"
check "the curtain did not take the keyboard" not test "$(pointer front 2>/dev/null)" = "$ARBOR_CURTAIN_PID"

step "what the nets decline"
# Asked, not tried: if a net had a hole, trying would be how to fall through it.
declined() { ! arbor_input_is_ours "$@"; }
check "a press in the menu bar" declined click $((vx + 20)) 5
check "a press below the visible frame" declined click $((vx + 20)) $((vy + vh + 20))
check "a press beyond the displays" declined click 100000 100000
check "a press without a place" declined click "" ""
check "⌘Space, which is Spotlight's" declined key cmd+space
check "⌃←, which switches Spaces" declined key ctrl+left
check "letting go never is" arbor_input_is_ours key ctrl+opt --up

step "the keyboard"
# Before any click: whoever had it keeps it, and keys are declined.
echo "has the keyboard now: process $(pointer front 2>&1)"
# shellcheck disable=SC2046
check "a click on a test window is let through" click $(center_of "$W1")
check "then the test windows' app has the keyboard" eventually test "$(pointer front 2>/dev/null)" = "$ARBOR_WINDOWS_PID"
check "and Arbor sees the window focused" eventually is focused "$W1"
check "holding ⌃⌥ is let through" key ctrl+opt --down
sleep 0.2
let_go=$("$ARBOR_POINTER" calm)
echo "  $let_go"
check "calm finds both keys down and lets go of them" says "opt, ctrl" "$let_go"
key ctrl+opt --up
check "after which nothing is down" test -z "$("$ARBOR_POINTER" calm)"

step "a drag left open"
# shellcheck disable=SC2046
drag $(titlebar_of "$W2") $((vx + vw / 2)) $((vy + vh / 2)) --no-release
check "the button is down" says "down" "$(pointer where)"
let_go=$("$ARBOR_POINTER" calm)
echo "  $let_go"
check "calm lets go of it" says "up" "$(pointer where)"

step "a picture"
echo "Screen Recording for this terminal: $(pointer screen-access)"
shot 01-behind-the-curtain
ls -l "$ARBOR_OUT" | awk '/png/ { print "  " $5, $9 }'

step "the end: something is left running on purpose, and the supervisor must find it"
arbor_stop
sleep 299 &
echo "left running: process $! (sleep 299). Below, the supervisor should name it, and say that nothing on this Mac differs"
