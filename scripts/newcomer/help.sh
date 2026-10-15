#!/bin/bash
# Where the rig lends the newcomer a hand, because a hosted Mac is nobody's: every time, the score says so.
#
#   scripts/newcomer/help.sh password|install <the tools' folder> <code hash of the Arbor under test> <the Arbor.app that runs, or ->
#
# rig.py calls it; its last line is for the newcomer, or the journal, to read.
#
# password   The newcomer said `password`: macOS is asking for the account's, and nobody knows a hosted Mac's. A person would type theirs, and that they know it
#            says nothing about Arbor. So the dialog is put away and what it stood before is done by other means. There are two such moments on the
#            way to a running Arbor, and the state of things tells which it is:
#              Arbor runs and waits, System Settings is open     the switch under Privacy & Security > Accessibility was flipped: what that switch records is written
#                                                                into the permission database, the service that keeps it starts again, the change is announced
#              Arbor does not run, and bears a browser's mark    "Open Anyway" was pressed: the mark is taken off and the app is opened
#            Nothing is done unless macOS is asking: a password nobody wanted opens no door.
# install    The time for installing is up and Arbor is not ready. One wall must not cost the other tasks: it is unpacked if need be, the mark taken off,
#            the permission written down and the app started.
#
# Only the Arbor under test is ever helped: an app of that name with another code hash is somebody else's, and stays where macOS's guards put it.
set -uo pipefail
[ "${GITHUB_ACTIONS:-}" = true ] && [ "$(uname -s)" = Darwin ] && [ "$(id -un)" = runner ] || { echo "only on one of GitHub's Macs"; exit 77; }
how=${1:?} tools=${2:?} wanted=${3:?} app=${4:?}
tcc="/Library/Application Support/com.apple.TCC/TCC.db"

on_screen() { "$tools/pointer" windows --on-screen | awk '{ $1 = $2 = $3 = $4 = $5 = $6 = $7 = $8 = ""; sub(/^ +/, ""); print }'; }
asking() { on_screen | grep -qxE "coreautha|SecurityAgent|LocalAuthenticationRemoteService"; }
ours() { [ -d "$1" ] && [ "$(codesign --display --verbose=3 "$1" 2>&1 | sed -n 's/^CDHash=//p')" = "$wanted" ]; }
found() {
  local each
  for each in "$HOME/Applications/Arbor.app" /Applications/Arbor.app "$HOME/Downloads/Arbor.app" "$HOME/Desktop/Arbor.app"; do
    if ours "$each"; then echo "$each"; return 0; fi
  done
  return 1
}
put_dialogs_away() {
  local tries=0 pid
  while asking && [ "$tries" -lt 5 ]; do "$tools/pointer" key escape; sleep 1; tries=$((tries + 1)); done
  # Gatekeeper's own: while one stands, nothing can be opened.
  pid=$("$tools/pointer" windows --on-screen | awk '$9 == "CoreServicesUIAgent" { print $2; exit }')
  [ -z "$pid" ] || "$tools/apptool" press "$pid" Done Cancel OK > /dev/null 2>&1
}
# grant <app>: what the switch in System Settings records.
grant() {
  local work
  work=$(mktemp -d) || return 1
  [ -n "$work" ] || return 1
  codesign --display --requirements - "$1" 2>/dev/null | sed -n 's/^\(# \)\{0,1\}designated => //p' > "$work/requirement.txt"
  csreq -r- -b "$work/requirement.bin" < "$work/requirement.txt" || { rm -rf "${work:?}"; return 1; }
  sudo sqlite3 "$tcc" "INSERT OR REPLACE INTO access (service, client, client_type, auth_value, auth_reason, auth_version, csreq, indirect_object_identifier, flags, last_modified) VALUES ('kTCCServiceAccessibility', 'com.evbarleyg.arbor', 0, 2, 3, 1, X'$(xxd -p "$work/requirement.bin" | tr -d '\n')', 'UNUSED', 0, strftime('%s', 'now'));"
  rm -rf "${work:?}"
  # In this order: announced before the service has started again, a running process is told yes and its event taps stay refused.
  sudo killall -9 tccd
  sleep 2
  osascript -l JavaScript -e 'ObjC.import("Foundation"); $.NSDistributedNotificationCenter.defaultCenter.postNotificationNameObjectUserInfoDeliverImmediately("com.apple.accessibility.api", $(), $(), true)' > /dev/null
}

case "$how" in
  password)
    asking || { echo "nobody is asking for a password"; exit 0; }
    settings=$(on_screen | grep -cx "System Settings")
    put_dialogs_away
    if [ "$app" != - ]; then
      ours "$app" || { echo "typed for you; macOS did not take it"; exit 0; }
      [ "$settings" -gt 0 ] || { echo "typed for you; nothing came of it"; exit 0; }
      grant "$app" && echo "typed for you, and accepted" || echo "typed for you; macOS did not take it"
    elif app=$(found) && xattr -p com.apple.quarantine "$app" > /dev/null 2>&1; then
      xattr -dr com.apple.quarantine "$app"
      open "$app"
      echo "typed for you, and accepted"
    else
      echo "typed for you; nothing came of it"
    fi ;;
  install)
    put_dialogs_away
    did=""
    if [ "$app" = - ] || ! ours "$app"; then
      if ! app=$(found); then
        ditto -x -k "$HOME/Downloads/Arbor.zip" "$HOME/Downloads" && did="unpacked, "
        app=$(found) || { echo "the download could not be unpacked"; exit 1; }
      fi
      if xattr -p com.apple.quarantine "$app" > /dev/null 2>&1; then xattr -dr com.apple.quarantine "$app"; did="${did}the browser's mark taken off, "; fi
      grant "$app" && did="${did}given the permission, "
      open "$app" && did="${did}started"
      sleep 4
    else
      grant "$app" && did="given the permission"
    fi
    echo "${did:-nothing}" ;;
  *) echo "help.sh: password or install"; exit 64 ;;
esac
