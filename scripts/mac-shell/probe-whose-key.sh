#!/bin/bash
# Can a key that Arbor shows as its own ever arrive elsewhere, and does Arbor know when it does not hold it? A probe (collab/BOARD.md, 0.1; IDEAS I16).
#
#   scripts/mac-shell/run.sh scripts/mac-shell/probe-whose-key.sh
#
# On a tester's Mac ⌃⌥A, which is `arrange`, reached the app in front, twice, and did that app's own ⌃⌥A. Three guesses: the key was never registered; it was let go of
# meanwhile; the app listens below the point where macOS takes a hot key away. This asks a Mac, with ears of every kind:
#
#   in the app in front      local    a local monitor: whatever the app is given at all
#                            equiv    its view is asked whether the key is an equivalent of its own
#                            menu     a menu item with that key equivalent fires
#                            view     keyDown in the first responder
#   in the background        global   a global monitor: what some OTHER app was given
#                            tap-hid, tap-session, tap-annotated    listen-only event taps at the three points macOS offers, from the keyboard inwards
#   on demand                rival    another process that has registered the SAME Carbon hot keys, as an Electron app's globalShortcut does
#
# And with hands of more than one kind: an ordinary press is left ⌃, left ⌥ and the key, put in at the keyboard's end. Here also the right-hand keys, a mix, both of each pair, Caps Lock on,
# fn held, flags without any modifier key going down, a key held until it repeats; and the same key put in at the two points further in, and posted to the app itself, which
# is how tools that remap keys or play macros may post.
#
# It takes the keys from `arborctl bindings`, presses each with the app in front, and prints which ears heard it and whether Arbor's log grew. Rounds: no Arbor (the
# control: every ear has to hear); from the moment of launch; running; paused; shortcuts off for the app; secure input on; Arbor stopped (a main thread that is
# busy); a rival registered after Arbor, and before it; the display asleep and awake again; Arbor killed. Then ⌃⌥A a dozen times a second through everything that might make
# Arbor let go of its keys for a moment (a reload, `set`, a panel, a hold, a pause, a switch of apps). And Arbor as a bundle that answers for its own permission: in the
# menu bar without it; granted; and replaced by a build with another hash, signed ad hoc, as `make install` leaves it where there is no signing identity.
# Not tried: real sleep and wake (a hosted Mac may not come back from it), the watchdog's restart (watchdog-bundle.sh), a finger on a real keyboard: every key here is a posted event.
#
# Only on GitHub's Macs: it presses some fifty shortcuts a dozen times over, into whatever is in front, and installs event taps that listen.
ARBOR_TIME_LIMIT=1500
source "$(dirname "$0")/lib.sh"
needs_throwaway_mac "press every shortcut into the app in front, with and without Arbor, and listen with event taps"
source "$(dirname "$0")/lib-ears.sh"

# MARK: The ears

step "the keys: Arbor's own list"
arbor_start 3 ARBOR_NO_HOTKEYS=0 ARBOR_NO_STATUS_ITEM=0
"$ARBOR_BIN/arborctl" bindings | awk '/→/ { print $1 }' > "$CHORDS"
echo "$(grep -c . "$CHORDS") keys"
arbor_stop 00-listed
# ⌃⌥⎋ pauses and resumes, so it gets rounds of its own.
ALL=$(grep -v "^ctrl+opt+escape$" "$CHORDS" | tr '\n' ' ')
# The nine of the second build, less ⌃⌥⎋, and ⌃⌥A.
FEW="ctrl+opt+a ctrl+opt+left ctrl+opt+right ctrl+opt+return ctrl+opt+space ctrl+opt+[ ctrl+opt+z ctrl+opt+f ctrl+opt+g"

ears_open

step "0  no Arbor: the control. Every key has to reach the app"
# shellcheck disable=SC2086
press_all control $ALL ctrl+opt+escape
# What each key is called further in: its code and modifiers, as the app was given them.
python3 - "$HEARD" > "$CODES" <<'PY'
import sys
chord = None
seen = set()
for line in open(sys.argv[1], encoding="utf-8", errors="replace"):
    words = line.split()
    if len(words) > 3 and words[1] == "MARK":
        chord = words[3] if words[2] == "control" else None
    elif chord not in (None, "-") and len(words) > 4 and words[1] == "local" and chord not in seen:
        seen.add(chord)
        print(words[3].split("=")[1], words[4].split("=")[1], chord)
PY
check "every key's code is known" test "$(grep -c . "$CODES")" -eq "$(grep -c . "$CHORDS")"
shot 01-control

step "0b  no Arbor, odd hands and odd roads: the control. Each has to reach the app"
odd_hands control

step "1  from the moment of launch: how long is ⌃⌥A not Arbor's?"
ROUND=launch
mark -
since=$(wall)
hammer 8
arbor_start 3 ARBOR_NO_HOTKEYS=0 ARBOR_NO_STATUS_ITEM=0
check "the hammer came to an end" ended "$HAMMER_PID" 150
echo "Arbor was started at or after $since"
timeline "$since"

step "2  running"
ctl arrange
sleep 1
what_arbor_says
# shellcheck disable=SC2086
press_all running $ALL
shot 02-running
ROUND=running-pause-key
front_again
press_all pause-key ctrl+opt+escape
"$ARBOR_BIN/arborctl" status | head -n 1
press_all resume-key ctrl+opt+escape
"$ARBOR_BIN/arborctl" status | head -n 1

step "2a  running, odd hands and odd roads: the right-hand keys, both of a pair, Caps Lock, fn; and keys put in further in than the keyboard"
odd_hands running
ctl show-all

step "2b  is there a moment at which Arbor lets go? ⌃⌥A a dozen times a second through whatever might register shortcuts anew"
ROUND=holes
mark -
front_again
since=$(wall)
hammer 34
sleep 1
act "$ARBOR_BIN/arborctl" reload-settings
arbor_settings '{"gap": 14}'
act "$ARBOR_BIN/arborctl" reload-settings
act "$ARBOR_BIN/arborctl" set gap 12
act "$ARBOR_BIN/arborctl" set shortcutsFollowLayout false
act "$ARBOR_BIN/arborctl" set shortcutsFollowLayout true
act "$ARBOR_BIN/arborctl" ask-name
act "$ARBOR_BIN/arborctl" ask-name cancel
act "$ARBOR_BIN/arborctl" find
act "$ARBOR_BIN/arborctl" show-all
act "$ARBOR_BIN/arborctl" show-shortcuts
act "$ARBOR_BIN/arborctl" show-all
act "$ARBOR_BIN/arborctl" minimap
act "$ARBOR_BIN/arborctl" minimap
act "$ARBOR_BIN/arborctl" hold
act "$ARBOR_BIN/arborctl" release
# shellcheck disable=SC2046
act "$ARBOR_POINTER" click $(center_of "$W1")
act kill -USR1 "$FRONT_PID"
act "$ARBOR_BIN/arborctl" pass-through "$EARS_ID" on
act "$ARBOR_BIN/arborctl" pass-through "$EARS_ID" off
act "$ARBOR_BIN/arborctl" pause
act "$ARBOR_BIN/arborctl" resume
check "the hammer came to an end" ended "$HAMMER_PID" 200
holes "$since"
echo "how often Arbor registered its shortcuts meanwhile:"
grep -E "registered [0-9]+ shortcuts" "$ARBOR_HOME/arbor.log" | awk -v since="$since" 'substr($1, 12, 12) >= since' | cut -c 12- | sed 's/^/  /' | head -n 30
ROUND=after-holes
tidy
ctl show-all

step "3  paused"
ctl pause
what_arbor_says
# shellcheck disable=SC2086
press_all paused $ALL
ctl resume

step "4  shortcuts off for the app in front"
ctl pass-through "$EARS_ID" on
front_again
sleep 0.5
what_arbor_says
# shellcheck disable=SC2086
press_all off-for-the-app $ALL
ctl pass-through "$EARS_ID" off
sleep 0.5

step "5  secure input on, as with a password field"
front_again
kill -USR2 "$FRONT_PID"
sleep 0.5
grep "secure input" "$HEARD" | tail -n 1 | cut -c 14-
ioreg -l -w 0 | grep -o "kCGSSessionSecureInputPID[^,]*" | head -n 1
what_arbor_says
# shellcheck disable=SC2086
press_all secure-input $ALL
kill -USR2 "$FRONT_PID"
sleep 0.5
grep "secure input" "$HEARD" | tail -n 1 | cut -c 14-

step "6  Arbor stopped in its tracks: a main thread that is busy"
kill -STOP "$ARBOR_PID"
saved_pid=$ARBOR_PID
# Nothing can be asked of it meanwhile.
ARBOR_PID=""
# shellcheck disable=SC2086
press_all stopped $FEW
ARBOR_PID=$saved_pid
before=$(arbor_lines)
kill -CONT "$ARBOR_PID"
sleep 2
echo "going again, Arbor's log grew by $(($(arbor_lines) - before)) lines:"
tail -n "+$((before + 1))" "$ARBOR_HOME/arbor.log" | grep " INFO " | cut -c 12- | head -n 12 | sed 's/^/  /'
ROUND=after-stopped
tidy
ctl show-all

step "7  a rival registers the same hot keys AFTER Arbor"
"$EARS" rival "$HEARD" "$CODES" 9>&- 8>&- &
RIVAL_PID=$!
started "$RIVAL_PID"
check "the rival is up" eventually says_in_log "rival ready pid=$RIVAL_PID"
grep "rival ready" "$HEARD" | tail -n 1 | cut -c 14-
# shellcheck disable=SC2086
press_all rival-after-arbor $ALL
what_arbor_says

step "8  the rival was there BEFORE Arbor"
arbor_stop 03-before-the-rival
arbor_start 3 ARBOR_NO_HOTKEYS=0 ARBOR_NO_STATUS_ITEM=0
ctl arrange
what_arbor_says
# shellcheck disable=SC2086
press_all rival-before-arbor $ALL
kill_started "$RIVAL_PID"
RIVAL_PID=""
sleep 0.5
# shellcheck disable=SC2086
press_all rival-gone $FEW

step "9  Arbor killed"
echo "> kill -KILL (Arbor)"
kill -KILL "$ARBOR_PID"
ended "$ARBOR_PID"
ARBOR_PID=""
# shellcheck disable=SC2086
press_all killed $FEW
# What arbor_stop does after a quit: the log comes back, the test windows close, the next session gets a folder of its own.
arbor_log
arbor_close_windows
arbor_new_home

# MARK: A bundle that answers for its own permission

# As the probes of the permission do it: an identifier of its own, opened by Launch Services, so that one entry of the database is Arbor's alone and this script's tools keep theirs.
BUNDLE_ID=com.evbarleyg.arbor.probe-whose-key
TCC="/Library/Application Support/com.apple.TCC/TCC.db"
tcc() { sudo sqlite3 "$TCC" "$1"; }
app="$HOME/Applications/ArborProbeWhoseKey.app"
entry() { echo "the entry in the database (2 is what the switch shows as on): $(tcc "SELECT client, auth_value FROM access WHERE service = 'kTCCServiceAccessibility' AND client = '$BUNDLE_ID';" | tr '\n' ' ')"; }
hash_of_the_bundle() { codesign --display --verbose=3 "$app" 2>&1 | sed -n 's/^CDHash=//p'; }
sign_the_bundle() {
  codesign --force --sign - --identifier "$BUNDLE_ID" "$app" || die "codesign failed"
  /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$app" || echo "lsregister could not register the bundle"
  echo "the bundle's hash: $(hash_of_the_bundle)"
}
open_the_bundle() {
  limit 20 open -n "$app" --env ARBOR_HOME="$ARBOR_HOME" --env ARBOR_SOCKET="$ARBOR_SOCKET" --env ARBOR_DEBUG=1 \
    --env ARBOR_ONLY_PIDS="$ARBOR_WINDOWS_PID" --env ARBOR_NO_WATCHDOG=1 --env ARBOR_NO_PICTURES=1 --env ARBOR_NO_PROMPT=1 \
    --env ARBOR_NO_STATUS_ITEM=0 --env ARBOR_NO_HOTKEYS=0
  sleep 3
  ARBOR_PID=$(pgrep -f "$app/Contents/MacOS/Arbor" | head -n 1)
  [ -n "$ARBOR_PID" ] || die "the bundle did not start"
  started "$ARBOR_PID"
}
leave_the_bundle() {
  [ -n "$ARBOR_PID" ] || return 0
  "$ARBOR_BIN/arborctl" quit > /dev/null 2>&1
  ended "$ARBOR_PID" || kill_started "$ARBOR_PID"
  ARBOR_PID=""
}

step "10  the bundle"
if tcc "SELECT count(*) FROM access;" > /dev/null 2>&1; then
  # The test windows come with a session; its Arbor, a child of this shell that shares the shell's permission, makes way for the bundle.
  arbor_start 3
  "$ARBOR_BIN/arborctl" quit > /dev/null
  ended "$ARBOR_PID" || die "the session's own Arbor did not quit"
  ARBOR_PID=""
  at_exit 'rm -rf "${app:?}"'
  at_exit "tcc \"DELETE FROM access WHERE client = '$BUNDLE_ID';\""
  rm -rf "${app:?}"
  mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
  cp "$ARBOR_BIN/Arbor" "$app/Contents/MacOS/Arbor"
  cp "$ARBOR_ROOT/Resources/Info.plist" "$app/Contents/Info.plist"
  /usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier $BUNDLE_ID" -c "Delete :CFBundleURLTypes" "$app/Contents/Info.plist" || die "could not edit Info.plist"
  sign_the_bundle

  step "10a  never granted: Arbor is in the menu bar. Which keys does it hold?"
  entry
  open_the_bundle
  what_arbor_says
  shot 05-no-permission
  # shellcheck disable=SC2086
  press_all never-granted $ALL ctrl+opt+escape
  leave_the_bundle

  step "10b  granted, as the switch in System Settings records it"
  codesign --display --requirements - "$app" 2>/dev/null | sed -n 's/^\(# \)\{0,1\}designated => //p' | tee "$ARBOR_SESSION_DIR/requirement.txt"
  csreq -r "$ARBOR_SESSION_DIR/requirement.txt" -b "$ARBOR_SESSION_DIR/requirement.bin" || die "csreq could not read the bundle's requirement"
  tcc "INSERT OR REPLACE INTO access (service, client, client_type, auth_value, auth_reason, auth_version, csreq, indirect_object_identifier, flags, last_modified) VALUES ('kTCCServiceAccessibility', '$BUNDLE_ID', 0, 2, 3, 1, X'$(xxd -p "$ARBOR_SESSION_DIR/requirement.bin" | tr -d '\n')', 'UNUSED', 0, strftime('%s', 'now'));" \
    || die "the grant could not be written"
  sudo killall -9 tccd 2>/dev/null
  # Whoever posts events has been blocked for seconds after such a kill.
  sleep 6
  entry
  open_the_bundle
  what_arbor_says
  # shellcheck disable=SC2086
  press_all granted $FEW
  leave_the_bundle

  step "10c  replaced by another build, signed ad hoc: the entry stays, the hash is another"
  /usr/libexec/PlistBuddy -c "Add :ArborProbe string another-build" "$app/Contents/Info.plist" || die "could not edit Info.plist"
  sign_the_bundle
  entry
  open_the_bundle
  what_arbor_says
  shot 06-reinstalled
  # shellcheck disable=SC2086
  press_all reinstalled $ALL ctrl+opt+escape
  grep -iE "permission|accessib" "$ARBOR_HOME/arbor.log" | tail -n 6 | cut -c 12- | sed 's/^/  log | /'
  leave_the_bundle
else
  echo "left out: the permission database cannot be read here"
fi

# Last, because a hosted Mac may take it badly.
step "11  the display asleep, and awake again"
arbor_log
arbor_close_windows
arbor_new_home
arbor_start 3 ARBOR_NO_HOTKEYS=0 ARBOR_NO_STATUS_ITEM=0
ctl arrange
pmset displaysleepnow
sleep 4
caffeinate -u -t 2
sleep 2
what_arbor_says
# shellcheck disable=SC2086
press_all after-display-sleep $FEW
shot 04-after-display-sleep
arbor_stop 07-quit

step "when the app came to the front and left it"
grep -E " front (active|resigned)" "$HEARD" | awk '{ print $3 }' | sort | uniq -c
