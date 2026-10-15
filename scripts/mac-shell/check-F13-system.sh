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
f13_clone

step "1  the identity, in a keychain on the search list"
# Not one named login.keychain-db: there macOS asks in a dialog, which check-signing.sh answers (steps 7 and 8). What follows needs an identity
# that sign.sh finds by itself, through the search list.
keychain="$HOME/Library/Keychains/arbor-f13.keychain-db"
f13_make_keychain
echo "the search list: $(security list-keychains -d user | tr -d '\n')"
limit 120 ./scripts/make-signing-identity.sh --keychain "$keychain" < /dev/null 2>&1 | tee "$ARBOR_OUT/identity.txt"
security find-identity -p codesigning
check "codesign could use the key at once, without a dialog" says "$ARBOR_OUT/identity.txt" "codesign can sign with it"
check "the identity is found through the search list, as sign.sh looks for it" \
  with "$(security find-identity -p codesigning)" "\"$identity\""

# From here on Arbor is started as a person would start it, and lives in the account's real home whatever this shell's
# HOME says.
unset ARBOR_HOME
export ARBOR_SOCKET="$real_home/Library/Application Support/Arbor/arbor.sock"

step "2  make install, as a person runs it"
tcc_sql "DELETE FROM access WHERE client = '$bundle_id';" 2>/dev/null
if ! limit 900 make install > "$ARBOR_OUT/install.txt" 2>&1; then
  grep "error:" "$ARBOR_OUT/install.txt" | sort -u | head -n 40
  tail -n 30 "$ARBOR_OUT/install.txt"
  die "make install failed"
fi
grep -E "^Signed|^Installed|^Linked|^Started|^  " "$ARBOR_OUT/install.txt"
check "it found the identity by itself" says "$ARBOR_OUT/install.txt" "with \"$identity\", this Mac's own certificate"
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
else
  echo "columns: $(tcc_sql "SELECT group_concat(name, ' ') FROM pragma_table_info('access');")"
  check "started by macOS and never granted anything, Arbor waits for permission" within 5 status_starts "waiting for Accessibility"
  # What switching Arbor on in System Settings records: the bundle id and the designated requirement, compiled.
  requirement "$installed" | csreq -r- -b "$sandbox/requirement.bin"
  hex=$(xxd -p "$sandbox/requirement.bin" | tr -d '\n')
  granted_cdhash=$(cdhash "$installed")
  if tcc_sql "INSERT OR REPLACE INTO access (service, client, client_type, auth_value, auth_reason, auth_version, csreq, indirect_object_identifier, flags, last_modified) VALUES ('kTCCServiceAccessibility', '$bundle_id', 0, 2, 3, 1, X'$hex', 'UNUSED', 0, strftime('%s', 'now'));"; then
    echo "granted to this build: $(tcc_rows)"
    if within 6 status_starts "running"; then
      echo "  Arbor noticed by itself"
    else
      sudo killall -9 tccd 2>/dev/null
      within 6 status_starts "running" && echo "  Arbor noticed once tccd had been restarted"
    fi
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
    echo "  the entry is still there, and still says allowed: $(tcc_rows)"
    shot 03-stale-signature
    tccutil reset Accessibility "$bundle_id"
    check "tccutil reset removes the entry" test -z "$(tcc_rows)"
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
echo "  login items that still mention Arbor: $(sudo sfltool dumpbtm 2>/dev/null | grep -ci "$bundle_id")"
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
