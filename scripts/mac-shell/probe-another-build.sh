#!/bin/bash
# What does a person find under System Settings → Privacy & Security → Accessibility after an update of an Arbor that is signed ad hoc?
#
#   MAC_SHELL_TAG=another-build scripts/mac-shell/run.sh --no-preflight "<why>" scripts/mac-shell/probe-another-build.sh    (about three minutes; LOOK AT THE PICTURES)
#
# To macOS a build signed ad hoc is another program: the grant is for the first build's hash. The welcome window says "Already on? Switch it off and on
# again", and so do the release notes. Whether the switch is on then, nobody had seen: in the permission database the entry has been found rewritten to
# "denied" once the second build had asked, and a switch that looks off would make "Already on?" a question nobody answers with yes.
#
#   1  a first build, granted: it runs. The pane, pictured and read: the control, in which the switch must read on
#   2  a second build in its place: the same bundle, one more key in its Info.plist, signed ad hoc again. It waits for the permission
#   3  Open Settings… in its window, as a person would: does macOS ask again, what becomes of the entry, how does the switch look
#
# The bundle lies in ~/Applications and is registered, or the pane would not list it (README-permission-probes.md, "Traps").
# No script can move the switch on a hosted Mac: macOS wants a password (probe-the-switch.sh). So THAT OFF AND ON AGAIN HELPS IS NOT SHOWN HERE.
# An experiment: lines that begin with FACT are what it is for. Only what must hold for them to mean anything is checked.
source "$(dirname "$0")/lib.sh"
needs_throwaway_mac "write to the permission database with sudo, restart tccd, and open System Settings at Privacy & Security"

BUILD_ID=com.evbarleyg.arbor.probe-another-build
BUILD_NAME=ArborAnotherBuild
TCC="/Library/Application Support/com.apple.TCC/TCC.db"
LSREGISTER=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister
AXFIND="$ARBOR_ROOT/.build/mac-shell/axfind"
PANE="x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"

tcc() { sudo sqlite3 "$TCC" "$1"; }
ax() { limit 20 "$AXFIND" "$ARBOR_PID" "$@"; }
status_starts() { case "$("$ARBOR_BIN/arborctl" status 2>&1)" in "$1"*) return 0 ;; *) return 1 ;; esac; }
gone() { ! kill -0 "$1" 2>/dev/null; }
settings_pid() { pgrep -x "System Settings" | head -n 1; }
settings_are_closed() { [ -z "$(settings_pid)" ]; }
cdhash_of() { codesign --display --verbose=3 "$1" 2>&1 | sed -n 's/^CDHash=//p' | head -n 1; }
requirement_of() {
  codesign --display --requirements - "$1" 2>/dev/null | sed -n 's/^\(# \)\{0,1\}designated => //p' > "$ARBOR_SESSION_DIR/requirement.txt"
  csreq -r "$ARBOR_SESSION_DIR/requirement.txt" -b "$ARBOR_SESSION_DIR/requirement.bin" || die "csreq could not read the requirement of $1"
  xxd -p "$ARBOR_SESSION_DIR/requirement.bin" | tr -d '\n' | tr 'a-f' 'A-F'
}
# The entry: whether it allows (2) or denies (0), why (4 is "the system set it"), when it was last written, and whose signature it is for.
entry() {
  local row whose
  row=$(tcc "SELECT auth_value || '|' || auth_reason || '|' || last_modified || '|' || ifnull(hex(csreq), '') FROM access WHERE service = 'kTCCServiceAccessibility' AND client = '$BUILD_ID';")
  [ -n "$row" ] || { echo "there is none"; return 0; }
  case "${row##*|}" in
    "$FIRST_REQUIREMENT") whose="the first build's" ;;
    "${SECOND_REQUIREMENT:-none yet}") whose="THE SECOND BUILD'S" ;;
    "") whose="nobody's: it has no requirement" ;;
    *) whose="neither build's" ;;
  esac
  echo "$row" | awk -F '|' -v whose="$whose" '{ printf "auth_value %s, auth_reason %s, last written %s, for a signature that is %s\n", $1, $2, $3, whose }'
}
allows() { [ "$(tcc "SELECT auth_value FROM access WHERE service = 'kTCCServiceAccessibility' AND client = '$BUILD_ID';")" = 2 ]; }

# macOS's own dialog is a window of a process of its own.
asking_pid() { pointer windows --on-screen | awk '$9 == "universalAccessAuthWarn" { print $2; found = 1; exit } END { exit !found }'; }
macos_asks() { asking_pid > /dev/null; }
# press_in <pid> <title>: a real click on the button of that title.
press_in() {
  local place
  place=$(limit 20 "$AXFIND" "$1" point AXButton "$2" 2>/dev/null) || return 1
  # shellcheck disable=SC2086
  click $place
}

# The list comes late: 9 to 21 s after the pane was asked for, on a hosted Mac.
list_is_there() { limit 20 "$AXFIND" "$(settings_pid)" point - "Allow the applications below" > /dev/null 2>&1; }
await_the_list() {
  local tries=0
  until list_is_there; do
    tries=$((tries + 1))
    [ "$tries" -gt 20 ] && return 1
    sleep 2
  done
  sleep 2
}
# read_the_pane <name>: a picture, everything Accessibility says of the window, and SWITCH: 1, 0, or nothing where the row or its switch is not found.
SWITCH=""
read_the_pane() {
  shot "$1"
  limit 30 "$AXFIND" "$(settings_pid)" tree > "$ARBOR_OUT/$1.txt" 2>&1
  echo "tree: mac-shell/$1.txt, $(wc -l < "$ARBOR_OUT/$1.txt" | tr -d ' ') elements"
  grep -n -A 8 "$BUILD_NAME" "$ARBOR_OUT/$1.txt" | sed 's/  */ /g' | cut -c 1-170 | head -n 24
  SWITCH=$(python3 - "$ARBOR_OUT/$1.txt" "$BUILD_NAME" <<'PYTHON'
import re, sys
# The switch's own line names the bundle (its identifier is <name>_Toggle). Never the nearest switch: that may be the neighbour's.
for line in open(sys.argv[1], errors="replace").read().splitlines():
    if sys.argv[2] in line and re.search(r"AXSwitch|AXCheckBox|AXToggle", line):
        quoted = re.findall(r'"([^"]*)"', line)
        print(quoted[-1] if quoted else "")
        break
PYTHON
  )
}
close_settings() {
  killall "System Settings" 2>/dev/null
  eventually settings_are_closed || echo "System Settings is still there"
}

open_the_build() {
  # safe anywhere: a bundle this run made, limited to the run's own test window, on a home folder of the run's
  limit 20 open -n "$app" --env ARBOR_HOME="$ARBOR_HOME" --env ARBOR_SOCKET="$ARBOR_SOCKET" --env ARBOR_DEBUG=1 \
    --env ARBOR_ONLY_PIDS="$ARBOR_WINDOWS_PID" --env ARBOR_NO_WATCHDOG=1 --env ARBOR_NO_PICTURES=1 --env ARBOR_NO_PROMPT=0 --env ARBOR_NO_STATUS_ITEM=1 \
    --env ARBOR_NO_HOTKEYS=1 || die "could not open $app"
  sleep 2
  ARBOR_PID=$(pgrep -f "$app/Contents/MacOS/Arbor" | head -n 1)
  [ -n "$ARBOR_PID" ] || die "the bundle did not start"
  started "$ARBOR_PID"
}
quit_the_build() {
  "$ARBOR_BIN/arborctl" quit > /dev/null 2>&1
  eventually gone "$ARBOR_PID" || kill_started "$ARBOR_PID"
  gone "$ARBOR_PID" || die "the build did not go"
  ARBOR_PID=""
}

arbor_build
swiftc -O -swift-version 5 "$ARBOR_ROOT/scripts/mac-shell/axfind.swift" -o "$AXFIND" > "$ARBOR_OUT/build-axfind.log" 2>&1 \
  || { cat "$ARBOR_OUT/build-axfind.log"; die "scripts/mac-shell/axfind.swift did not compile"; }
tcc "SELECT count(*) FROM access;" > /dev/null 2>&1 || die "the permission database cannot be read here"
sw_vers | tr '\n' ' '; echo

step "1  a first build, granted"
arbor_start 1
"$ARBOR_BIN/arborctl" quit > /dev/null
ended "$ARBOR_PID" || die "the session's own Arbor did not quit"
ARBOR_PID=""
app="$HOME/Applications/$BUILD_NAME.app"
at_exit 'rm -rf "${app:?}"'
rm -rf "${app:?}"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp "$ARBOR_BIN/Arbor" "$app/Contents/MacOS/Arbor"
cp Resources/Info.plist "$app/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier $BUILD_ID" -c "Set :CFBundleName $BUILD_NAME" -c "Delete :CFBundleURLTypes" "$app/Contents/Info.plist" \
  || die "could not edit Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleDisplayName $BUILD_NAME" "$app/Contents/Info.plist" 2>/dev/null \
  || /usr/libexec/PlistBuddy -c "Add :CFBundleDisplayName string $BUILD_NAME" "$app/Contents/Info.plist"
# As scripts/sign.sh stamps what it signs without a certificate.
/usr/libexec/PlistBuddy -c "Add :ArborSignature string adhoc" "$app/Contents/Info.plist" 2>/dev/null \
  || /usr/libexec/PlistBuddy -c "Set :ArborSignature adhoc" "$app/Contents/Info.plist"
codesign --force --sign - --identifier "$BUILD_ID" "$app" || die "codesign failed"
"$LSREGISTER" -f "$app" || echo "lsregister could not register the bundle"
at_exit "tcc \"DELETE FROM access WHERE client = '$BUILD_ID';\"; killall 'System Settings' 2>/dev/null"
FIRST_HASH=$(cdhash_of "$app")
FIRST_REQUIREMENT=$(requirement_of "$app")
SECOND_REQUIREMENT=""
tcc "INSERT OR REPLACE INTO access (service, client, client_type, auth_value, auth_reason, auth_version, csreq, indirect_object_identifier, flags, last_modified) VALUES ('kTCCServiceAccessibility', '$BUILD_ID', 0, 2, 3, 1, X'$FIRST_REQUIREMENT', 'UNUSED', 0, strftime('%s', 'now'));" \
  || die "the grant could not be written"
sudo killall -9 tccd 2>/dev/null
sleep 6
echo "FACT the entry as it was written for the first build: $(entry)"
open_the_build
check "the control: the grant fits the first build, which runs" eventually status_starts running
quit_the_build
echo "FACT the entry after the first build has run and quit: $(entry)"
check "it still allows" allows
limit 20 open "$PANE"
if await_the_list; then
  read_the_pane 10-the-pane-with-the-first-build
  echo "FACT beside the first build, which is allowed, the switch reads: ${SWITCH:-NOT FOUND}"
  check "the control: the pane lists the bundle and its switch reads on, so the reader can tell on from off" test "$SWITCH" = 1
else
  shot 10-the-pane-with-the-first-build
  check "the list under Accessibility came within 40 s" false
fi
close_settings

step "2  a second build in its place"
/usr/libexec/PlistBuddy -c "Add :ArborSecondBuild string yes" "$app/Contents/Info.plist" || die "could not edit Info.plist"
codesign --force --sign - --identifier "$BUILD_ID" "$app" || die "codesign failed"
"$LSREGISTER" -f "$app" || echo "lsregister could not register the bundle"
SECOND_HASH=$(cdhash_of "$app")
SECOND_REQUIREMENT=$(requirement_of "$app")
echo "the first build's hash: $FIRST_HASH; the second's: $SECOND_HASH"
check "to macOS it is another program: both have a hash, and they differ" test -n "$FIRST_HASH" -a -n "$SECOND_HASH" -a "$FIRST_HASH" != "$SECOND_HASH"
open_the_build
check "the old grant does not fit it: Arbor waits for the permission" eventually status_starts waiting
sleep 3
shot 20-the-second-build-waits
limit 20 "$AXFIND" "$ARBOR_PID" tree 2>/dev/null | grep -E "AXStaticText|AXButton" | sed 's/^ *//' | cut -c 1-260 > "$ARBOR_OUT/20-the-second-build-waits.txt"
check "its window says what to do where the switch is on already" grep -q "Already on? Switch it off and on again" "$ARBOR_OUT/20-the-second-build-waits.txt"
echo "FACT the entry once the second build has started and asked nothing of anybody but “may I?”: $(entry)"
echo "FACT macOS asks by itself at that launch: $(macos_asks && echo yes || echo no)"

step "3  Open Settings…, as a person would"
if press_in "$ARBOR_PID" "Open Settings…"; then
  # Arbor asks macOS first, and opens the pane itself two seconds later where no dialog has come.
  if eventually macos_asks; then
    echo "FACT macOS asks with its own dialog, for the second build too"
    shot 30-macos-asks-again
    echo "FACT the entry while the dialog is up: $(entry)"
    press_in "$(asking_pid)" "Open System Settings" || { echo "the dialog has no button Open System Settings that could be found"; limit 20 open "$PANE"; }
  else
    echo "FACT macOS does not ask for the second build within four seconds: Arbor opens the pane itself"
  fi
  if await_the_list; then
    read_the_pane 31-the-pane-after-another-build
    echo "FACT the entry at that picture: $(entry)"
    case "$SWITCH" in
      1) echo "ANSWER: THE SWITCH LOOKS ON beside a build that may do nothing: “Already on?” is what a person sees" ;;
      0) echo "ANSWER: THE SWITCH LOOKS OFF: nobody who looks there will say yes to “Already on?”" ;;
      *) echo "NOT ANSWERED BY THE READER: no row or no switch found for $BUILD_NAME. See the picture and the tree" ;;
    esac
  else
    shot 31-the-pane-after-another-build
    check "the list under Accessibility came within 40 s" false
  fi
  echo "FACT macOS's dialog is on the screen at the end: $(macos_asks && echo yes || echo no)"
else
  check "the window has a button Open Settings… to press" false
fi
"$ARBOR_BIN/arborctl" status | head -n 1 | cut -c 1-120
grep -i "accessibility\|permission" "$ARBOR_HOME/arbor.log" | grep -v "DEBUG said" | tail -n 8 | cut -c 12-190

# Nothing of macOS's is left lying for the next script on this Mac.
if macos_asks; then press_in "$(asking_pid)" "Deny" || echo "the dialog could not be dismissed"; fi
close_settings
quit_the_build
arbor_log
arbor_close_windows
