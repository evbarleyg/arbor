#!/bin/bash
# F63, Accessibility permission taken away while Arbor runs, on a real Mac:
#
#   scripts/mac-shell/run.sh scripts/mac-shell/check-F63.sh
#
# With windows out of view the permission is switched off for everything (what the switch in System Settings records, written
# straight into the privacy database), and later on again. In between this script cannot press or click
# either: its tools lose the permission too. What it can do is ask Arbor over the socket, count event taps, read the
# log and ask the window server where the windows are.
source "$(dirname "$0")/lib.sh"
needs_throwaway_mac "switch Accessibility off for every app in the privacy database"

KEYS="$ARBOR_ROOT/.build/mac-shell/keys"
TCC="/Library/Application Support/com.apple.TCC/TCC.db"

tcc() { sudo sqlite3 "$TCC" "$1"; }
status_starts() { case "$("$ARBOR_BIN/arborctl" status 2>&1)" in "$1"*) return 0 ;; *) return 1 ;; esac; }
taps_are() { [ "$("$KEYS" taps "$ARBOR_PID")" = "$1" ]; }
# How many there are grows with the features; what matters here is some or none.
has_taps() { [ "$("$KEYS" taps "$ARBOR_PID")" -gt 0 ]; }
last_registered_is() { grep "registered [0-9]* shortcuts" "$ARBOR_HOME/arbor.log" | tail -n 1 | grep -q "registered $1 shortcuts"; }
all_on_screen() { is on_screen "$W1" && is on_screen "$W2" && is on_screen "$W3"; }
off_screen() { ! is on_screen "$1"; }
# allow 0|2: what the switch records, for the entries that were allowed when the script began and for no other: an app that was
# refused, or never answered, must not come out of this with the permission. Which entry Arbor runs under depends on who
# started the script, so it is all of those. tccd caches, so it is restarted if nothing happens.
ALLOWED_ROWS=""
allow() {
  [ -n "$ALLOWED_ROWS" ] || return 0
  tcc "UPDATE access SET auth_value = $1 WHERE service = 'kTCCServiceAccessibility' AND rowid IN ($ALLOWED_ROWS);"
  echo "$(arbor_now) Accessibility set to $1 for entries $ALLOWED_ROWS"
}
# until_status <prefix>: waits for it, says how long it took, and nudges tccd once if six seconds were not enough.
until_status() {
  local started tries=0
  started=$(arbor_now)
  until status_starts "$1"; do
    tries=$((tries + 1))
    [ "$tries" -eq 60 ] && { echo "  nothing after 6 s: restarting tccd"; sudo killall -9 tccd 2>/dev/null; }
    [ "$tries" -ge 120 ] && return 1
    sleep 0.1
  done
  echo "  after $(echo "$(arbor_now) - $started" | bc) s"
}

# expect_status "<what should hold>" <prefix>: the same as a check, with the time it took in the output.
expect_status() {
  local result=0
  until_status "$2" || result=1
  check "$1" test "$result" = 0
}
bindings_say() { "$ARBOR_BIN/arborctl" bindings 2>&1 | tail -n 1 | grep -q "$1"; }

arbor_build
swiftc -O -swift-version 5 "$ARBOR_ROOT/scripts/mac-shell/keys.swift" -o "$KEYS" > "$ARBOR_OUT/build-keys.log" 2>&1 \
  || die "scripts/mac-shell/keys.swift did not compile"
tcc "SELECT count(*) FROM access;" > /dev/null 2>&1 || die "the privacy database cannot be read here"
ALLOWED_ROWS=$(tcc "SELECT group_concat(rowid) FROM access WHERE service = 'kTCCServiceAccessibility' AND auth_value = 2;")
[ -n "$ALLOWED_ROWS" ] || die "nothing has the Accessibility permission here, so there is none to take away"
tcc "SELECT rowid, client, auth_value FROM access WHERE service = 'kTCCServiceAccessibility';"
# Whatever ends the script, those entries are as they were.
at_exit 'allow 2 > /dev/null'

# What everybody does first with a new build: reset, launch, grant. Until its first start Arbor waits as it did before F63 (a timer on
# AXIsProcessTrusted, the welcome window). What nobody has seen: whether a process that gets the permission while it runs may
# make event taps at once. If not, Arbor must go on arranging windows (it believes the flag until a tap has worked once).
step "the first minute: launched without the permission, then granted"
allow 0
# A new process asks the daemon, which answers from memory.
sudo killall -9 tccd 2>/dev/null
sleep 1
ARBOR_MAY_LACK_PERMISSION=1 arbor_start 3 ARBOR_NO_HOTKEYS=0 ARBOR_NO_STATUS_ITEM=0 ARBOR_NO_PROMPT=0
expect_status "Arbor waits for the permission" "waiting for Accessibility permission"
check "it holds no event tap" taps_are 0
check "it has not spoken of a loss" test "$(grep -c "was taken away" "$ARBOR_HOME/arbor.log")" = 0
shot 00-waiting
allow 2
expect_status "it starts by itself when the permission arrives" "running"
check "no window has moved" all_on_screen
if eventually has_taps; then
  echo "  a process that was given the permission while it ran may make event taps at once"
else
  echo "  NEWS: no event tap in a process that was given the permission while it ran"
  grep "event tap" "$ARBOR_HOME/arbor.log" | tail -n 5
fi
sleep 10
check "ten seconds later it is still running: no false alarm in front of the welcome window" status_starts "running"
check "and has still not spoken of a loss" test "$(grep -c "was taken away" "$ARBOR_HOME/arbor.log")" = 0
shot 00-granted

step "[1 | Desktop with 3 | 2], framed on 1: 2 and 3 are out of view"
ctl dock "$W1" left
ctl dock "$W2" right
ctl zoom "$W1"
check "2 is out of view" eventually off_screen "$W2"
check "3 is out of view" eventually off_screen "$W3"
check "the event taps are installed" eventually has_taps
shot 01-framed

step "the permission goes"
allow 0
expect_status "Arbor notices" "Arbor's Accessibility permission was taken away"
ctl status
check "it counts the windows out of view" status_starts "Arbor's Accessibility permission was taken away, so it cannot move windows. 2 windows (ArborTestWindows) are out of view"
check "no event tap is left" eventually taps_are 0
check "only the four ways home are registered" eventually last_registered_is 4
check "none of Arbor's own windows is on screen" test -z "$(overlays | awk '$8 == "on"')"
ctl show-all
check "a command fails" test "$("$ARBOR_BIN/arborctl" show-all > /dev/null 2>&1; echo $?)" = 1
check "2 is still out of view: nothing could be done" off_screen "$W2"
"$ARBOR_BIN/arborctl" state | python3 -c 'import json, sys; s = json.load(sys.stdin)["state"]; print("state: accessibility", s["accessibility"], "running", s["running"], "windows", len(s["windows"]))'
shot 02-lost
grep -E "ermission|registered|stopped|started" "$ARBOR_HOME/arbor.log" | tail -n 12

step "the permission returns"
allow 2
expect_status "Arbor starts again" "running"
check "every window is in view" eventually all_on_screen
check "the event taps are back" eventually has_taps
check "all the shortcuts are registered again" eventually last_registered_is "[0-9][0-9]"
summary
shot 03-back
ctl back
check "Back returns to the view it had: 2 is out of view" eventually off_screen "$W2"
# shellcheck disable=SC2046
click $(center_of "$W1")
key ctrl+opt+space
check "⌃⌥Space shows everything, with a real key" eventually all_on_screen

step "with nothing out of view Arbor keeps quiet"
allow 0
expect_status "Arbor notices" "Arbor's Accessibility permission was taken away, so it cannot move windows. Grant it again"
check "no shortcut is left" eventually bindings_say "all off without Accessibility permission"
shot 04-lost-with-nothing-missing
allow 2
expect_status "Arbor starts again" "running"
check "the windows are where they were" eventually all_on_screen
grep -E "ermission|registered|stopped|started" "$ARBOR_HOME/arbor.log" | tail -n 12
arbor_stop 05-after-quit
