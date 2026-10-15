#!/bin/bash
# F48 on real windows: a window that leaves the arrangement gets its own size back.
#
#   scripts/mac-shell/run.sh scripts/mac-shell/shots-F48.sh
#
# What only a Mac can settle:
# - a real title-bar drag out of a slot: does the window shrink under the pointer, with the pointer still on its
#   title bar, after a slow drag and after a fast one released without a pause (macOS reports moves only about
#   eight times a second, so Arbor reads the frame once more on mouse-up);
# - `float`, `float-all`, quitting: do real windows end at the frames they started from, to the point;
# - a pause while framed: is every window, the framed one too, back where it started, and framed again after the resume;
#   a quit during a pause, which has nothing left to do;
# - a kill -9 and a relaunch: is what was remembered still there;
# - does a minimized window accept a frame.
source "$(dirname "$0")/lib.sh"

# near "<x y w h>" "<x y w h>" [first field] [tolerance]: whether the frames agree from that field on.
near() {
  awk -v from="${3:-1}" -v tolerance="${4:-2}" 'BEGIN {
    split(ARGV[1], a, " "); split(ARGV[2], b, " ")
    for (i = from; i <= 4; i++) { d = a[i] - b[i]; if (d < 0) d = -d; if (d > tolerance) exit 1 }
    exit 0 }' "$1" "$2"
}
is_at() { near "$(real_frame_of "$1")" "$2"; }
has_size_of() { near "$(real_frame_of "$1")" "$2" 3; }
# Whether the pointer is over the top 32 points of the window.
pointer_on_titlebar() {
  awk 'BEGIN {
    split(ARGV[1], p, " "); split(ARGV[2], f, " ")
    exit !(p[1] >= f[1] && p[1] <= f[1] + f[3] && p[2] >= f[2] && p[2] <= f[2] + 32) }' \
    "$(pointer where)" "$(real_frame_of "$1")"
}
# How far along the window's width the pointer is, in hundredths.
pointer_along() {
  awk 'BEGIN { split(ARGV[1], p, " "); split(ARGV[2], f, " "); printf "%d\n", 100 * (p[1] - f[1]) / f[3] }' \
    "$(pointer where)" "$(real_frame_of "$1")"
}
# Whether Arbor ends within five seconds. If not it is killed, so that no `wait` for it can hang the script.
arbor_gone() { arbor_await_exit "$ARBOR_PID" 50 || { kill -KILL "$ARBOR_PID" 2>/dev/null; return 1; }; }
arbor_ready() { "$ARBOR_BIN/arborctl" state 2>/dev/null | python3 "$ARBOR_STATE_PY" ready "$1" 2>/dev/null; }

arbor_build
# minimize "<title>" true|false: what the yellow button and a click in the Dock do, for a window of the test app.
mkdir -p "$ARBOR_ROOT/.build/mac-shell"
cat > "$ARBOR_ROOT/.build/mac-shell/minimize.swift" <<'SWIFT'
import ApplicationServices
let arguments = CommandLine.arguments
let app = AXUIElementCreateApplication(pid_t(arguments[1])!)
var list: CFTypeRef?
AXUIElementCopyAttributeValue(app, kAXWindowsAttribute as CFString, &list)
for window in (list as? [AXUIElement]) ?? [] {
  var title: CFTypeRef?
  AXUIElementCopyAttributeValue(window, kAXTitleAttribute as CFString, &title)
  guard title as? String == arguments[2] else { continue }
  let value: CFBoolean = arguments[3] == "true" ? kCFBooleanTrue : kCFBooleanFalse
  print("AXMinimized \(arguments[3]):", AXUIElementSetAttributeValue(window, kAXMinimizedAttribute as CFString, value).rawValue)
}
SWIFT
swiftc -swift-version 5 "$ARBOR_ROOT/.build/mac-shell/minimize.swift" -o "$ARBOR_ROOT/.build/mac-shell/minimize" \
  2> "$ARBOR_OUT/build-minimize.log" || echo "note: the minimize tool did not compile"
minimize() { "$ARBOR_ROOT/.build/mac-shell/minimize" "$ARBOR_WINDOWS_PID" "$@"; }

# The third window cannot grow beyond 300×200.
ARBOR_TEST_WINDOWS_ARGS=${ARBOR_TEST_WINDOWS_ARGS:---max-size 3:300x200}
arbor_start 4
B1=$(real_frame_of "$W1"); B2=$(real_frame_of "$W2"); B3=$(real_frame_of "$W3"); B4=$(real_frame_of "$W4")
echo "before Arbor touched them: w$W1 $B1 | w$W2 $B2 | w$W3 $B3 | w$W4 $B4"
shot 01-before

step "float: the old size, centred on the slot"
ctl dock "$W1" left
ctl dock "$W2" right
slot=$(arbor_ask slot "$W1")
shot 02-docked
ctl float "$W1"
check "the floated window has its old size" eventually has_size_of "$W1" "$B1"
echo "its slot was $slot; it floats at $(real_frame_of "$W1"); the Desktop is $(arbor_ask desktop)"
shot 03-floated

step "float a framed window: the old size, and the Desktop in view"
ctl dock "$W1" left
ctl zoom "$W1"
shot 04-framed
ctl float "$W1"
check "the floated window has its old size" eventually has_size_of "$W1" "$B1"
check "the Desktop is in view" arbor_ask desktop
check "another floating window is back in view with it" eventually is on_screen "$W4"
shot 05-framed-floated
summary

step "drag it out of its slot, slowly, grabbed in the middle"
# Alone beside the Desktop, which is what is left over: of two halves there is no wallpaper to let a window go over. (By Float All, which puts
# the second window where it started.)
ctl float-all
ctl dock "$W1" left
sleep 0.5
read -r x y w h <<< "$(frame_of "$W1")"
read -r dx dy dw dh <<< "$(arbor_ask desktop)"
[ -n "${dh:-}" ] || die "the Desktop has no room, and the window wants a bare place to be let go over"
drag "$((x + w / 2))" "$((y + 12))" "$((dx + dw / 2))" 300 --no-release
echo "held: the window server has it at $(real_frame_of "$W1"), Arbor at $(frame_of "$W1"), pointer $(pointer where)"
shot 06-drag-held
release &
film 07-drag-released 3
wait $!
check "it floats" eventually is floating "$W1"
check "it has its old size" eventually has_size_of "$W1" "$B1"
echo "released: the window server has it at $(real_frame_of "$W1"), pointer $(pointer where), $(pointer_along "$W1")/100 along"
check "the pointer is still on its title bar" pointer_on_titlebar "$W1"
along=$(pointer_along "$W1")
check "about half way along, as it was grabbed" test "$along" -ge 42 -a "$along" -le 58
shot 08-drag-settled

step "drag it out fast, grabbed near the left end, released without a pause"
ctl dock "$W1" left
sleep 0.5
read -r x y w h <<< "$(frame_of "$W1")"
grabbed=$((100 * 100 / w))
drag "$((x + 100))" "$((y + 12))" "$((dx + dw / 3))" 420 --duration 0.25 --steps 12 --hold 0
check "it floats" eventually is floating "$W1"
check "it has its old size" eventually has_size_of "$W1" "$B1"
echo "released: the window server has it at $(real_frame_of "$W1"), pointer $(pointer where), $(pointer_along "$W1")/100 along (grabbed at $grabbed/100)"
check "the pointer is still on its title bar" pointer_on_titlebar "$W1"
along=$(pointer_along "$W1")
check "about as far along as it was grabbed" test "$along" -ge "$((grabbed - 8))" -a "$along" -le "$((grabbed + 8))"
shot 09-fast-drag-settled
D1=$(real_frame_of "$W1")

step "arrange, frame one, float-all: everything exactly where it was"
ctl arrange
shot 10-arranged
ctl zoom "$W2"
ctl float-all
check "w$W1 is where it was dropped" eventually is_at "$W1" "$D1"
check "w$W2 is where it started" eventually is_at "$W2" "$B2"
check "w$W3 (cannot grow) is where it started" eventually is_at "$W3" "$B3"
check "w$W4 is where it started" eventually is_at "$W4" "$B4"
shot 11-float-all
summary

step "framed on a window, a pause lets go as a quit does: every window is back where it was, at its own size"
ctl arrange
ctl zoom "$W2"
sleep 0.5
P2=$(real_frame_of "$W2")
ctl pause &
film 12-pausing 3
wait $!
check "the framed window is where it started" eventually is_at "$W2" "$B2"
check "w$W1 is back where it was" eventually is_at "$W1" "$D1"
check "w$W4 is back where it was" eventually is_at "$W4" "$B4"
shot 12-paused
ctl resume
check "the framed window is framed again" eventually is_at "$W2" "$P2"
check "w$W1 is out of view again" eventually is parked "$W1"
shot 13-resumed
ctl show-all

step "a minimized window comes back as it was, not in the shape of its slot"
minimize "Arbor Test 4" true
if eventually is minimized "$W4"; then
  ctl float-all
  echo "minimized, after float-all: Arbor (Accessibility) has it at $(frame_of "$W4"); it started at $B4"
  minimize "Arbor Test 4" false
  check "restored, it is where it started" eventually is_at "$W4" "$B4"
  echo "restored: the window server has it at $(real_frame_of "$W4")"
  shot 13b-restored
  ctl arrange
else
  echo "note: the window did not minimize; nothing learned"
fi
summary

step "kill -9 with windows out of view, start again: the sizes are still known"
ctl zoom "$W2"
sleep 1.5 # the save that follows every change
kill -KILL "$ARBOR_PID"
wait "$ARBOR_PID" 2>/dev/null
shot 14-killed
env ARBOR_ONLY_PIDS="$ARBOR_WINDOWS_PID" ARBOR_NO_PROMPT=1 ARBOR_DEBUG=1 ARBOR_NO_HOTKEYS=1 ARBOR_NO_STATUS_ITEM=1 ARBOR_NO_WATCHDOG=1 \
  "$ARBOR_BIN/Arbor" > "$ARBOR_OUT/arbor-stderr-relaunched.log" 2>&1 9>&- &
ARBOR_PID=$!
started "$ARBOR_PID"
if check "Arbor is back" eventually arbor_ready 4; then
  check "w$W1 is still docked" is docked "$W1"
  ctl show-all
  ctl float "$W1"
  check "floated after the relaunch, it has its old size" eventually has_size_of "$W1" "$B1"
  shot 15-relaunched-floated
  D1=$(real_frame_of "$W1")
  ctl arrange
  ctl desktop
  shot 16-everything-out-of-view

  step "quit: everything exactly where it was"
  ctl quit
  check "Arbor exits within 5 s of quit" arbor_gone
  wait "$ARBOR_PID" 2>/dev/null
  ARBOR_PID=""
  check "w$W1 is where it floated last" eventually is_at "$W1" "$D1"
  check "w$W2 is where it started" eventually is_at "$W2" "$B2"
  check "w$W3 is where it started" eventually is_at "$W3" "$B3"
  echo "after quitting: w$W1 $(real_frame_of "$W1") | w$W2 $(real_frame_of "$W2") | w$W3 $(real_frame_of "$W3") | w$W4 $(real_frame_of "$W4")"
  shot 17-after-quit
  arbor_log
fi

step "quit during a pause: the pause has left no window in the shape of its slot, and the quit moves nothing"
arbor_close_windows
arbor_new_home
ARBOR_TEST_WINDOWS_ARGS=" "
arbor_start 3
B1=$(real_frame_of "$W1"); B2=$(real_frame_of "$W2"); B3=$(real_frame_of "$W3")
ctl arrange
shot 18-arranged
ctl pause
check "in view, w$W1 is where it started as soon as Arbor is paused" eventually is_at "$W1" "$B1"
ctl quit
check "Arbor exits within 5 s of quit" arbor_gone
wait "$ARBOR_PID" 2>/dev/null
ARBOR_PID=""
check "w$W1 is where it started" eventually is_at "$W1" "$B1"
check "w$W2 is where it started" eventually is_at "$W2" "$B2"
check "w$W3 is where it started" eventually is_at "$W3" "$B3"
shot 19-after-quit-while-paused
arbor_log
