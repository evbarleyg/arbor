#!/bin/bash
# What the rig does when the newcomer says `password`: macOS is asking for the account's password, and nobody knows a hosted Mac's.
#
#   scripts/newcomer/password.sh <the pointer tool> <the Arbor.app that runs, or ->          rig.py calls it; its last line is for the newcomer to read
#
# A person would type theirs, and that they know it says nothing about Arbor. So the dialog is put away and what it stood before is done by
# other means. There are two such moments on the way to a running Arbor, and the state of things tells which it is:
#   Arbor runs and waits for the permission     the switch under Privacy & Security > Accessibility was flipped: what that switch records is written into
#                                               the permission database, the service that keeps it is started again, and the change is announced
#   Arbor does not run, and bears a browser's mark    "Open Anyway" was pressed: the mark is taken off and the app is opened
# Nothing is done unless macOS is asking: a password nobody wanted opens no door.
set -uo pipefail
[ "${GITHUB_ACTIONS:-}" = true ] && [ "$(uname -s)" = Darwin ] || { echo "only on one of GitHub's Macs"; exit 77; }
pointer=${1:?} app=${2:?}
tcc="/Library/Application Support/com.apple.TCC/TCC.db"

asking() { "$pointer" windows --on-screen | awk '{ $1 = $2 = $3 = $4 = $5 = $6 = $7 = $8 = ""; sub(/^ +/, ""); print }' | grep -qxE "coreautha|SecurityAgent|LocalAuthenticationRemoteService"; }
asking || { echo "nobody is asking for a password"; exit 0; }
tries=0
while asking && [ "$tries" -lt 5 ]; do "$pointer" key escape; sleep 1; tries=$((tries + 1)); done

if [ "$app" != - ]; then
  work=$(mktemp -d) || exit 2
  [ -n "$work" ] || exit 2
  codesign --display --requirements - "$app" 2>/dev/null | sed -n 's/^\(# \)\{0,1\}designated => //p' > "$work/requirement.txt"
  csreq -r- -b "$work/requirement.bin" < "$work/requirement.txt" || { echo "it was typed, and macOS did not take it"; exit 1; }
  sudo sqlite3 "$tcc" "INSERT OR REPLACE INTO access (service, client, client_type, auth_value, auth_reason, auth_version, csreq, indirect_object_identifier, flags, last_modified) VALUES ('kTCCServiceAccessibility', 'com.evbarleyg.arbor', 0, 2, 3, 1, X'$(xxd -p "$work/requirement.bin" | tr -d '\n')', 'UNUSED', 0, strftime('%s', 'now'));"
  rm -rf "${work:?}"
  # In this order: announced before the service has started again, a running process is told yes and its event taps stay refused.
  sudo killall -9 tccd
  sleep 2
  osascript -l JavaScript -e 'ObjC.import("Foundation"); $.NSDistributedNotificationCenter.defaultCenter.postNotificationNameObjectUserInfoDeliverImmediately("com.apple.accessibility.api", $(), $(), true)' > /dev/null
  echo "typed for you, and accepted"
  exit 0
fi
for found in "$HOME/Downloads/Arbor.app" "$HOME/Applications/Arbor.app" /Applications/Arbor.app "$HOME/Desktop/Arbor.app"; do
  if xattr -p com.apple.quarantine "$found" > /dev/null 2>&1; then
    xattr -dr com.apple.quarantine "$found"
    open "$found"
    echo "typed for you, and accepted"
    exit 0
  fi
done
echo "typed for you; nothing came of it"
