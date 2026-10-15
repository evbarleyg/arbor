#!/bin/bash
# Proves the parts of F13 (distribution) that cannot be tried without changing the Mac they run on. check-F13.sh has
# everything else, and is safe anywhere.
#
#   scripts/mac-shell/run.sh scripts/mac-shell/check-F13-system.sh      # about five minutes
#
#   1  with the identity in a keychain on the search list, `make app` finds it by itself
#   2  `make install` as a person runs it: Arbor is started by macOS, on the account's own settings
#   3  macOS's permission database honours a grant made to one build for the next, and not for an ad-hoc build
#   4  launch at login, from ~/Applications, across a reinstall, until `make uninstall`
#   5  the menu: Check for Updates… and the version
#   6  what macOS does when a downloaded copy is opened
source "$(dirname "$0")/lib-F13.sh"
needs_throwaway_mac "write to the permission database with sudo, restart tccd, change the login items, set a keychain search list, \
start an Arbor that arranges every window on the account's own settings, click in the menu bar, and dismiss a system dialog"

tcc="/Library/Application Support/com.apple.TCC/TCC.db"
tcc_sql() { sudo sqlite3 "$tcc" "$1"; }
tcc_rows() { tcc_sql "SELECT service, client, client_type, auth_value, auth_reason, length(csreq) FROM access WHERE client = '$bundle_id';"; }
# What macOS's list of login items says of each entry of Arbor's, as "[enabled, allowed, notified] (0xb)". The disposition stands above the
# identifier ("2.com.evbarleyg.arbor"); the line "Bundle Identifier:" belongs to the same entry.
login_dispositions() {
  sudo sfltool dumpbtm 2> /dev/null | awk -v id="$bundle_id" '
    /^ *Disposition:/ { said = $0; sub(/^ *Disposition: */, "", said) }
    /^ *Identifier:/ && index($0, id) { print said }'
}
system_cleanup() {
  if [ -d "$installed" ]; then (cd "$src" && limit 120 make uninstall) > /dev/null 2>&1; fi
  tcc_sql "DELETE FROM access WHERE client = '$bundle_id';" 2>/dev/null
  cp "$real_home/Library/Application Support/Arbor/arbor.log" "$ARBOR_OUT/arbor-installed.log" 2>/dev/null
}
f13_also_clean=system_cleanup

f13_describe_the_mac
mkdir -p "$(dirname "$ARBOR_POINTER")"
swiftc -O -swift-version 5 "$ARBOR_ROOT/scripts/mac-shell/pointer.swift" -o "$ARBOR_POINTER" > "$ARBOR_OUT/build-pointer.log" 2>&1 &
pointer_build=$!
# What System Settings posts when its switch is flipped (first-five-minutes.sh).
cat > "$sandbox/notice.swift" << 'SWIFT'
import Foundation
DistributedNotificationCenter.default().postNotificationName(
  Notification.Name("com.apple.accessibility.api"), object: nil, userInfo: nil, deliverImmediately: true)
SWIFT
swiftc -O -swift-version 5 "$sandbox/notice.swift" -o "$sandbox/notice" > "$ARBOR_OUT/build-notice.log" 2>&1 \
  || { cat "$ARBOR_OUT/build-notice.log"; die "the tool that posts the notice did not compile"; }
f13_clone

step "1  the identity, in a keychain on the search list"
# lib-F13.sh's, in the run's folder, and not one in ~/Library/Keychains: about a key in a keychain that lies there macOS asks in a dialog,
# whatever the file is called and whoever made it (seen here, with arbor-f13.keychain-db under the throwaway HOME), which check-signing.sh
# answers (steps 7 and 8). What follows needs an identity that sign.sh finds by itself, through the search list.
f13_make_keychain
echo "the search list: $(security list-keychains -d user | tr -d '\n')"
limit 120 ./scripts/make-signing-identity.sh --keychain "$keychain" < /dev/null 2>&1 | tee "$ARBOR_OUT/identity.txt"
security find-identity -p codesigning
# Without the identity every build below is ad hoc, which is not what this script asks about, and the dialog lies over every picture.
check "codesign could use the key at once, without a dialog" says "$ARBOR_OUT/identity.txt" "codesign can sign with it" \
  || die "codesign cannot use the key without a dialog; the rest would be about ad-hoc builds"
check "the identity is found through the search list, as sign.sh looks for it" \
  with "$(security find-identity -p codesigning)" "\"$identity\""

# From here on Arbor is started as a person would start it, and lives in the account's real home whatever this shell's
# HOME says. `open` hands none of this shell's variables on. The folder is named and not left out: lib.sh reads Arbor's log from it.
export ARBOR_HOME="$real_home/Library/Application Support/Arbor"
export ARBOR_SOCKET="$ARBOR_HOME/arbor.sock"

step "2  make install, as a person runs it"
tcc_sql "DELETE FROM access WHERE client = '$bundle_id';" 2>/dev/null
if ! limit 900 make install > "$ARBOR_OUT/install.txt" 2>&1; then
  grep "error:" "$ARBOR_OUT/install.txt" | sort -u | head -n 40
  tail -n 30 "$ARBOR_OUT/install.txt"
  die "make install failed"
fi
grep -E "^Signed|^Installed|^Linked|^Started|^  " "$ARBOR_OUT/install.txt"
by_identity=""
check "it found the identity by itself" says "$ARBOR_OUT/install.txt" "with \"$identity\", this Mac's own certificate" && by_identity=yes
check "it starts Arbor and prints its status" says "$ARBOR_OUT/install.txt" "Started Arbor: "
check "Arbor runs from ~/Applications" runs "$installed"
check "to this shell, as to a person's, arborctl is the link in ~/.local/bin" same "$(command -v arborctl)" "$home/.local/bin/arborctl"
# As a person has it: started by macOS, with its watchdog.
check_watchdog "$real_home/Library/Application Support/Arbor/arbor.log" "$installed" "$(app_pid "$installed")"
check "the running app reports its version" same "$(arborctl version | head -n 1)" "Arbor $expected"
echo "  without ARBOR_SOCKET, under this shell's HOME: $(env -u ARBOR_SOCKET arborctl status 2>&1 | head -n 1)"

step "3  does the permission survive a rebuild?"
if ! tcc_sql "SELECT count(*) FROM access;" > /dev/null 2>&1; then
  echo "skipped: the permission database cannot be read here"
elif [ -z "$by_identity" ]; then
  echo "skipped: the build is not signed with the identity, which is red above, and this step is about builds that are"
else
  echo "columns: $(tcc_sql "SELECT group_concat(name, ' ') FROM pragma_table_info('access');")"
  check "started by macOS and never granted anything, Arbor waits for permission" within 5 status_starts "waiting for Accessibility"
  # What switching Arbor on in System Settings records: the bundle id and the designated requirement, compiled.
  requirement "$installed" | csreq -r- -b "$sandbox/requirement.bin"
  hex=$(xxd -p "$sandbox/requirement.bin" | tr -d '\n')
  granted_cdhash=$(cdhash "$installed")
  if tcc_sql "INSERT OR REPLACE INTO access (service, client, client_type, auth_value, auth_reason, auth_version, csreq, indirect_object_identifier, flags, last_modified) VALUES ('kTCCServiceAccessibility', '$bundle_id', 0, 2, 3, 1, X'$hex', 'UNUSED', 0, strftime('%s', 'now'));"; then
    echo "granted to this build: $(tcc_rows)"
    # The switch in System Settings does more than write the row: it posts a notice, and a running process learns of a grant through nothing
    # else (seen on hosted Macs, here too: neither the row nor a restart of tccd is noticed). In this order: announced before tccd has read
    # the row, the flag says yes and event taps stay refused in that process. A relaunch is the last resort.
    took="the row alone"
    if ! within 6 status_starts "running"; then
      took="the row, a restart of tccd, and the notice System Settings posts"
      sudo killall -9 tccd 2>/dev/null
      sleep 3
      "$sandbox/notice"
      if ! within 8 status_starts "running"; then
        took="a relaunch"
        arborctl quit > /dev/null 2>&1
        within 10 gone "$installed"
        open "$installed"
        within 10 status_starts "running"
      fi
    fi
    echo "  what it took for Arbor to see the grant: $took"
    echo "  $(arborctl status | head -n 1)"
    check "with the grant, this build runs" status_starts "running"

    change_the_source
    limit 600 make install 2>&1 | grep -E "error|^Signed|^Installed|^Started|^Asked"
    restore_the_source
    echo "  the grant was made to the build with cdhash $granted_cdhash; installed now is $(cdhash "$installed")"
    check "what is installed now is different code" differ "$granted_cdhash" "$(cdhash "$installed")"
    check "THE NEXT BUILD, SIGNED WITH THE SAME IDENTITY, RUNS WITHOUT BEING GRANTED ANYTHING" within 8 status_starts "running"
    echo "  $(arborctl status | tr '\n' '|')"

    ARBOR_SIGN_IDENTITY=- limit 600 make install 2>&1 | tee "$ARBOR_OUT/install-adhoc.txt" | grep -E "error|^Signed|^Installed|^Started|^  |^Asked"
    check "an ad-hoc build does not inherit the grant: the stale-signature case" within 8 status_starts "waiting for Accessibility"
    check "make install explains that case" says "$ARBOR_OUT/install-adhoc.txt" "tccutil reset Accessibility $bundle_id"
    echo "  the entry after that (the fourth field: 2 allowed, 0 denied): $(tcc_rows)"
    shot 03-stale-signature
    # What `make install` advises. It can be tried only from a real ~/Applications.
    tccutil reset Accessibility "$bundle_id"
    known "tccutil knows no bundle under /tmp, where this copy is installed, lsregister or not; it does know one in ~/Applications \
(docs/REALITY.md: tccutil-knows-a-bundle-only-from-where-and-by-whom-it-was-opened)"
    check "tccutil reset removes the entry" test -z "$(tcc_rows)"
    known ""
  else
    echo "skipped: the permission database cannot be written here"
  fi
fi

step "4  launch at login"
limit 600 make install 2>&1 | grep -E "error|^Signed|^Installed|^Started"
echo "  $(arborctl launch-at-login)"
check "off to begin with" same "$(arborctl launch-at-login)" off
echo "  $(arborctl launch-at-login on)"
check "launch-at-login on, from ~/Applications" same "$(arborctl launch-at-login)" on
check "the binary agrees, without asking the running app" \
  same "$("$installed/Contents/MacOS/Arbor" --launch-at-login)" on
check "and macOS's own list of login items has the entry enabled" with "$(login_dispositions)" "[enabled"
sudo sfltool dumpbtm 2>/dev/null | grep -i -B 4 -A 14 "$bundle_id" | head -n 60 > "$ARBOR_OUT/login-item.txt"
grep -iE "^ *(name|disposition|identifier|url|bundle id|type|developer)" "$ARBOR_OUT/login-item.txt" | head -n 16
limit 600 make install 2>&1 | grep -E "error|^Installed|^Started"
echo "  after installing again: $(arborctl launch-at-login)"
check "the entry survives a new build copied over the old one" same "$(arborctl launch-at-login)" on

step "5  the menu"
wait "$pointer_build" || cat "$ARBOR_OUT/build-pointer.log"
menu_pid=$(app_pid "$installed")
if item=$(pointer status-item "$menu_pid"); then
  # shellcheck disable=SC2086
  click $item
  shot 05-menu
  key escape
else
  echo "Arbor's menu bar item was not found"
fi

limit 120 make uninstall 2>&1 | tee "$ARBOR_OUT/uninstall.txt"
check "make uninstall removed the login item" says "$ARBOR_OUT/uninstall.txt" "Arbor does not open at login"
check "asked Arbor to quit" says "$ARBOR_OUT/uninstall.txt" "Asked the running Arbor to quit"
check "removed the app" test ! -e "$installed"
check "nothing of it is left running" gone "$installed"
echo "  what macOS's list of login items says of Arbor's entries now: $(login_dispositions | tr '\n' ';')"
check "none of them is enabled: Arbor does not open at the next login" without "$(login_dispositions)" "[enabled"
check "settings are still there" test -f "$real_home/Library/Application Support/Arbor/settings.json"

step "6  a downloaded copy"
mkdir -p "$sandbox/download"
ARBOR_SIGN_IDENTITY=- limit 600 make app 2>&1 | grep -E "error|^Signed"
cp -R "$app" "$sandbox/download/Arbor.app"
download="$sandbox/download/Arbor.app"
xattr -w com.apple.quarantine "0083;$(printf '%x' "$(date +%s)");Safari;$(uuidgen)" "$download"
echo "    $(spctl --status 2>&1)"
spctl --assess --type execute --verbose=4 "$download" 2>&1 | sed 's/^/    /'
# In the background: `open` may wait for the answer to a dialog that nobody is there to answer.
(limit 20 open "$download" 2>&1 | head -n 3) &
shot_after 4 06-first-launch-of-a-download
# macOS may run a copy that carries the mark of a download from a folder of its own making.
echo "  running after that? $(listed "$download" | grep . || pgrep -fl "/AppTranslocation/[^ ]*/Arbor.app/Contents/MacOS/Arbor" || echo no)"
killall CoreServicesUIAgent 2>/dev/null
wait $!
"$download/$tool" quit > /dev/null 2>&1

ls -l "$ARBOR_OUT" | awk '{ print $5, $9 }'
