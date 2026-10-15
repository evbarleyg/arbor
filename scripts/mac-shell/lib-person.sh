# Arbor started as a person starts it, for Mac shell scripts. Source it after lib.sh; do not run it.
#
#   source "$(dirname "$0")/lib.sh"
#   source "$(dirname "$0")/lib-person.sh"
#   arbor_build
#   arbor_start_as_a_person 3 ARBOR_NO_HOTKEYS=0      # whatever arbor_start takes
#
# arbor_start runs the bare binary as the shell's child. Such an Arbor borrows the permission of the hosted Mac's agent, and macOS tells it things that it does
# not tell the app: whether a key is down that another app has the keyboard for, by the session's table (2026-10-15: 288 looks of 288 true in the child, 19 of
# 19 false in the app, the key down in all). A script that starts Arbor as nobody does cannot see what only the app meets.
#
# Here: a copy of the app under an identifier of its own, opened by Launch Services, WITHOUT the permission; it is granted while Arbor waits, as on a first day.
# arbor_relaunch_as_a_person starts the same copy again in the same session, with the grant in place from before it starts: as on any later day.
# (A plain arbor_relaunch, or an arbor_start after arbor_stop, is the shell's child again.)
# THE START IS A PERSON'S, THE GRANT IS A SCRIPT'S: a row, the daemon restarted, the word posted, in the order in which flag and taps both say yes
# (README-permission-probes.md). No script can click the switch in System Settings on a hosted Mac.
#
# Only on GitHub's Macs. Anywhere else, and in a rehearsal, it is arbor_start, and it says so.

ARBOR_PERSON_ID=com.evbarleyg.arbor.as-a-person
ARBOR_PERSON_APP=""
# safe anywhere: a name; nothing is done with it here
ARBOR_PERSON_TCC="/Library/Application Support/com.apple.TCC/TCC.db"

# safe anywhere: called from inside `if on_throwaway_mac` below and from nowhere else
arbor_person_tcc() { sudo sqlite3 "$ARBOR_PERSON_TCC" "$1"; }
arbor_person_forget() { arbor_person_tcc "DELETE FROM access WHERE client = '$ARBOR_PERSON_ID';"; }
arbor_person_manages() {
  # shellcheck disable=SC2086
  set -- $ARBOR_WINDOW_IDS
  "$ARBOR_BIN/arborctl" state 2>/dev/null | python3 "$ARBOR_STATE_PY" ready $# 2>/dev/null
}

# What System Settings posts when its switch is flicked: a running process learns of a grant through nothing else.
arbor_person_builds_the_word() {
  swiftc -O -swift-version 5 - -o "$1" > "$ARBOR_OUT/build-word.log" 2>&1 <<'SWIFT' || die "the three lines that announce a change did not compile"
import Foundation
DistributedNotificationCenter.default().postNotificationName(
  Notification.Name("com.apple.accessibility.api"), object: nil, userInfo: nil, deliverImmediately: true)
SWIFT
}

arbor_start_as_a_person() {
  local app word hex
  if [ -n "${ARBOR_REHEARSAL:-}" ]; then
    echo "a rehearsal: started as the shell's child, NOT as a person starts it"
    arbor_start "$@"
    return
  fi
  if on_throwaway_mac; then
    app="$ARBOR_SESSION_DIR/Arbor.app"
    word="$ARBOR_SESSION_DIR/word"
    arbor_person_tcc "SELECT count(*) FROM access;" > /dev/null 2>&1 || die "the permission database cannot be read here"
    arbor_person_builds_the_word "$word"
    mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
    cp "$ARBOR_BIN/Arbor" "$app/Contents/MacOS/Arbor"
    cp "$ARBOR_ROOT/Resources/Info.plist" "$app/Contents/Info.plist"
    /usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier $ARBOR_PERSON_ID" -c "Delete :CFBundleURLTypes" "$app/Contents/Info.plist" || die "could not edit Info.plist"
    # As scripts/sign.sh stamps what it signs without a certificate, which is how this copy is signed on the next line but one.
    /usr/libexec/PlistBuddy -c "Add :ArborSignature string adhoc" "$app/Contents/Info.plist" 2>/dev/null \
      || /usr/libexec/PlistBuddy -c "Set :ArborSignature adhoc" "$app/Contents/Info.plist"
    codesign --force --sign - --identifier "$ARBOR_PERSON_ID" "$app" || die "codesign failed"
    arbor_person_forget
    at_exit arbor_person_forget

    # For this call alone: arbor_stop makes a new folder for the next session, and the copy lies in this one's.
    ARBOR_PERSON_APP=$app
    ARBOR_BUNDLE=$app ARBOR_MAY_LACK_PERMISSION=1 arbor_start "$@"
    case "$("$ARBOR_BIN/arborctl" status 2>&1)" in
      waiting*) ;;
      *) die "the copy of the app has the permission before anybody gave it: it is not answering for itself" ;;
    esac

    codesign --display --requirements - "$app" 2>/dev/null | sed -n 's/^\(# \)\{0,1\}designated => //p' | csreq -r- -b "$ARBOR_SESSION_DIR/requirement.bin"
    hex=$(xxd -p "$ARBOR_SESSION_DIR/requirement.bin" | tr -d '\n')
    # From an entry that is there, so that it has whatever columns this macOS has.
    arbor_person_tcc "CREATE TEMP TABLE one AS SELECT * FROM access WHERE service = 'kTCCServiceAccessibility' AND auth_value = 2 LIMIT 1;
      UPDATE one SET client = '$ARBOR_PERSON_ID', client_type = 0, csreq = X'$hex';
      INSERT INTO access SELECT * FROM one;" || die "the grant could not be written"
    sudo killall -9 tccd 2>/dev/null
    sleep 3
    "$word"
    eventually arbor_person_manages || eventually arbor_person_manages || eventually arbor_person_manages \
      || die "granted while it waited, Arbor did not start managing the test windows"
    echo "started as a person starts it: the app, through Launch Services, granted while it waited (pid $ARBOR_PID)"
    "$ARBOR_BIN/arborctl" status
  else
    echo "started as the shell's child, NOT as a person starts it: what only the app meets is not seen here"
    arbor_start "$@"
  fi
}

arbor_relaunch_as_a_person() {
  if [ -n "$ARBOR_PERSON_APP" ]; then
    ARBOR_BUNDLE=$ARBOR_PERSON_APP arbor_relaunch "$@"
  else
    arbor_relaunch "$@"
  fi
}
