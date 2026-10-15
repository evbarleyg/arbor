#!/bin/bash
# Proves on a real Mac that scripts/make-signing-identity.sh gives codesign the use of the key it makes, that it tells the truth when it
# cannot, and that scripts/sign.sh stamps what it signs. Four minutes, nothing of Arbor is compiled. check-F13.sh has the whole of F13.
#
#   scripts/mac-shell/run.sh --bare scripts/mac-shell/check-signing.sh                   # macOS 26
#   scripts/mac-shell/run.sh --bare --on macos-14 scripts/mac-shell/check-signing.sh     # and macos-15: the key's label differs
#
#   1  it is made and tried, with macOS's own openssl and with OpenSSL 3; run again; --remove
#   2  a keychain off the search list: it fails, says why, and leaves nothing
#   3  a throwaway HOME has a search list of its own, which codesign follows (check-F13.sh rests on it)
#   4  beside somebody's key and a certificate whose name begins like ours: nothing of theirs changes, whatever is made or removed
#   5  sign.sh: the stamp agrees with codesign, ad hoc and with the certificate
#   6  at a terminal, a keychain of its own: no password is asked for, and no dialog is promised
#   7  the account's own login keychain, whose password nobody here knows: macOS asks; nobody answers; Deny
#   8  as a person runs it: the login keychain made anew with a known password, the dialog, the password, Always Allow
#
# Only on one of GitHub's Macs: it puts keychains of its own on the account's search list and takes them off again, answers macOS's dialogs,
# and in the end REPLACES THE ACCOUNT'S LOGIN KEYCHAIN by an empty one.
ARBOR_TIME_LIMIT=${ARBOR_TIME_LIMIT:-480}
source "$(dirname "$0")/lib.sh"
needs_throwaway_mac "make keychains, put them on the account's search list and take them off again, answer macOS's dialogs, and replace the login keychain by an empty one"
[ -z "${ARBOR_REHEARSAL:-}" ] || { echo "a rehearsal has no keychains and no codesign"; exit 77; }

AXFIND="$ARBOR_ROOT/.build/mac-shell/axfind"
scratch_dir signing work real
make_identity="$ARBOR_ROOT/scripts/make-signing-identity.sh"
name="Arbor Local Signing"
pw="probe$RANDOM"
listed_before=$(security list-keychains -d user | sed 's/^ *"//; s/"$//')
# list [keychain]: the account's search list as it was, and that keychain.
list() { { echo "$listed_before"; [ $# -eq 0 ] || echo "$1"; } | tr '\n' '\0' | xargs -0 security list-keychains -d user -s; }
at_exit list

with() { case "$1" in *"$2"*) return 0 ;; *) return 1 ;; esac; }
without() { ! with "$@"; }
same() { [ -n "$1" ] && [ "$1" = "$2" ]; }
differs() { ! cmp -s "$1" "$2"; }
# Read whole, then matched: a grep -q that leaves at the match would fail the pipe under pipefail.
asks() { with "$(printf '\n%s\n' "$(on_screen)")" $'\nSecurityAgent\n'; }
quiet() { ! asks; }
# await_dialog <seconds>: whether SecurityAgent has come on screen in that time
await_dialog() { local n=0; while [ "$n" -lt $(($1 * 4)) ]; do asks && return 0; sleep 0.25; n=$((n + 1)); done; return 1; }
press() {
  local point; point=$(limit 5 "$AXFIND" "$(pid_named SecurityAgent)" point AXButton "$1" 2> /dev/null) || { echo "no button $1"; return 1; }
  # shellcheck disable=SC2086
  click $point > /dev/null
}
# partitions <keychain>: who may use the key without being asked, as macOS has it; nothing where a key has no such list
partitions() { limit 20 security dump-keychain -a "$1" 2> /dev/null | awk '/authorizations \(1\): partition_id/ { mine = 1 } mine && /description: / { sub(/.*description: /, ""); print; mine = 0 }'; }
on_screen() { "$ARBOR_POINTER" windows --on-screen | awk '{ $1 = $2 = $3 = $4 = $5 = $6 = $7 = $8 = ""; sub(/^ +/, ""); print }' | sort -u; }
pid_named() {
  "$ARBOR_POINTER" windows --on-screen | awk -v name="$1" '{ pid = $2; $1 = $2 = $3 = $4 = $5 = $6 = $7 = $8 = ""; sub(/^ +/, ""); if ($0 == name) { print pid; exit } }'
}
told() {
  local pid; pid=$(pid_named "$1"); [ -n "$pid" ] || return 0
  limit 5 "$AXFIND" "$pid" tree 2>/dev/null | grep -E "AXStaticText|AXButton|AXTextField|AXCheckBox" | grep -vE '"" "" ' | sed -E 's/^ +//; s/ -?[0-9]+ -?[0-9]+ [0-9]+ [0-9]+$//' \
    | cut -c 1-220 | head -n 12 | sed 's/^/        /'
}
label_of() { security dump-keychain "$1" 2> /dev/null | awk '/class: 0x00000010/ { key = 1 } key && /0x00000001 <blob>=/ { sub(/.*<blob>=/, ""); print; exit }'; }
# fresh <name> [unlisted]: a keychain of this run's, unlocked, in $kc.
fresh() {
  kc="$work/$1.keychain-db"
  security create-keychain -p "$pw" "$kc" && security set-keychain-settings "$kc" && security unlock-keychain -p "$pw" "$kc" || die "no keychain"
  if [ "${2:-}" = unlisted ]; then list; else list "$kc"; fi
}
# made <file> [NAME=value…] [-- argument…]: runs the script with nobody at a terminal; what it said is shown and kept, its exit code is in $code.
made() {
  local file="$ARBOR_OUT/$1.txt" settings=()
  shift
  while [ $# -gt 0 ] && [ "$1" != -- ]; do settings+=("$1"); shift; done
  [ $# -eq 0 ] || shift
  limit 60 env ${settings[@]+"${settings[@]}"} "$make_identity" "$@" < /dev/null > "$file" 2>&1
  code=$?
  sed 's/^/    /' "$file" | cut -c 1-200
  echo "    exit code $code"
  said=$(cat "$file")
}
# signs <keychain>: codesign signs with the certificate, within seconds, and nothing new is on screen afterwards.
signs() {
  local before; before=$(on_screen)
  cp /usr/bin/true "$work/signed"
  limit 15 codesign --force --sign "$name" --keychain "$1" --timestamp=none --identifier com.evbarleyg.arbor.probe "$work/signed" || return 1
  # Read whole: a grep -q that leaves at the match kills codesign, and under pipefail that makes a no of the yes.
  with "$(codesign --display --verbose=2 "$work/signed" 2>&1)" "Authority=$name" || { echo "not signed with it"; return 1; }
  [ "$(on_screen)" = "$before" ] || { echo "something came on screen"; return 1; }
}

step "the Mac"
echo "macOS $(sw_vers -productVersion) on $(uname -m); /usr/bin/openssl: $(/usr/bin/openssl version)"
other=$(ls -d /opt/homebrew/opt/openssl@3/bin/openssl /usr/local/opt/openssl@3/bin/openssl 2>/dev/null | head -n 1)
echo "another openssl: ${other:-none} $([ -n "$other" ] && "$other" version)"
newest=$(ls -d /Applications/Xcode*.app 2>/dev/null | grep -viE 'beta|_rc' | sort -V | tail -n 1)
[ -n "$newest" ] && export DEVELOPER_DIR="$newest/Contents/Developer"
mkdir -p "$(dirname "$ARBOR_POINTER")"
limit 150 swiftc -O -swift-version 5 "$ARBOR_ROOT/scripts/mac-shell/pointer.swift" -o "$ARBOR_POINTER" > "$ARBOR_OUT/build-pointer.log" 2>&1 &
started $!; first=$!
limit 150 swiftc -O -swift-version 5 "$ARBOR_ROOT/scripts/mac-shell/axfind.swift" -o "$AXFIND" > "$ARBOR_OUT/build-axfind.log" 2>&1
ended "$first" 1600
[ -x "$ARBOR_POINTER" ] && [ -x "$AXFIND" ] || { cat "$ARBOR_OUT"/build-*.log; die "the tools did not compile"; }

step "1  made and tried"
fresh first
made first -- --keychain "$kc"
echo "  macOS calls the key $(label_of "$kc")"
check "it succeeds" same "$code" 0
check "and says that codesign can sign with the key" with "$said" "codesign can sign with it"
check "not a word about a password" without "$(echo "$said" | tr 'A-Z' 'a-z')" "password"
check "codesign signs again, and asks nobody" signs "$kc"
made again -- --keychain "$kc"
check "run again, it changes nothing, having tried a signature" same "$code $(echo "$said" | grep -c "Nothing to do") $(echo "$said" | grep -c "codesign can sign with it")" "0 1 1"
made removed -- --keychain "$kc" --remove
check "--remove says that it deleted one certificate" same "$code $(echo "$said" | grep -c "^Deleted the certificate")" "0 1"
check "the identity has gone" without "$(security find-identity -p codesigning "$kc")" "\"$name\""
check "and the key" same "$(label_of "$kc")x" "x"
if [ -n "$other" ]; then
  fresh second
  made openssl3 ARBOR_OPENSSL="$other" -- --keychain "$kc"
  echo "  macOS calls the key $(label_of "$kc")"
  check "packed by $("$other" version | cut -d ' ' -f 1-2): the same" same "$code $(echo "$said" | grep -c "codesign can sign with it")" "0 1"
  check "codesign signs again, and asks nobody" signs "$kc"
fi

step "2  off the search list"
fresh third unlisted
made unlisted -- --keychain "$kc"
# macOS 14, 15 and 26 find no identity there, in two sets of words. Should another: either it signs, or the script says why not.
if [ "$code" = 0 ]; then
  echo "  THIS macOS SIGNS FROM A KEYCHAIN OFF THE SEARCH LIST"
  check "and the script says so" with "$said" "codesign can sign with it"
else
  check "it fails, and says that that is why" with "$said" "is not on the keychain search list"
  check "it says that it took the certificate out again" with "$said" "taken out of the keychain again"
  check "nothing is left of the certificate" without "$(security find-certificate -a -c "$name" "$kc" 2>&1)" "$name"
  check "nor of the key" same "$(label_of "$kc")x" "x"
fi

step "3  a throwaway HOME"
home="$work/home"
mkdir -p "$home/Library/Keychains" "$home/Library/Preferences"
apart="$work/apart.keychain-db"
HOME=$home security create-keychain -p "$pw" "$apart" && HOME=$home security set-keychain-settings "$apart" && HOME=$home security unlock-keychain -p "$pw" "$apart"
HOME=$home security list-keychains -d user -s "$apart"
echo "  under the throwaway HOME the search list reads: $(HOME=$home security list-keychains -d user | tr -d '\n')"
# Looked at as it stands, with nothing put right in between: lib-F13.sh does the same on people's Macs on the strength of this.
check "the account's own search list is as it was" same "$(security list-keychains -d user | sed 's/^ *"//; s/"$//')" "$listed_before"
made apart HOME="$home" -- --keychain "$apart"
check "on that list and not on the account's: codesign follows HOME to the search list" same "$code $(echo "$said" | grep -c "codesign can sign with it")" "0 1"

step "4  beside what is somebody's"
fresh fourth
/usr/bin/openssl genrsa -out "$work/theirs.pem" 2048 2> /dev/null
security import "$work/theirs.pem" -k "$kc" -x > /dev/null
made like-named -- --keychain "$kc" --name "$name 2" > /dev/null
# Every attribute and every access list in the keychain, which holds their key and an identity whose name begins like ours.
whole() { limit 20 security dump-keychain -a "$kc" 2>&1; }
whole > "$work/before.txt"
echo "  the keychain's attributes and access lists fill $(grep -c "" "$work/before.txt") lines, $(grep -c "entry " "$work/before.txt") entries; its keys are called:"
security dump-keychain "$kc" 2> /dev/null | awk '/^class: / { key = ($2 == "0x00000010") } key && /0x00000001 <blob>=/ { sub(/.*<blob>=/, "    "); print }'
check "there is something to compare" test "$(grep -c "entry " "$work/before.txt")" -gt 3
made beside -- --keychain "$kc"
check "ours is made beside them" same "$code $(echo "$said" | grep -c "codesign can sign with it")" "0 1"
whole > "$work/with-ours.txt"
check "and the keychain reads otherwise for it, so the comparison can tell" differs "$work/before.txt" "$work/with-ours.txt"
made beside-removed -- --keychain "$kc" --remove
check "--remove deletes ours alone" same "$code $(echo "$said" | grep -c "^Deleted the certificate")" "0 1"
whole > "$work/after.txt"
check "with ours taken out again, not an attribute and not an access list of theirs has changed" cmp -s "$work/before.txt" "$work/after.txt" \
  || diff "$work/before.txt" "$work/after.txt" | head -n 12
check "the identity whose name begins like ours still signs" \
  limit 15 codesign --force --sign "$name 2" --keychain "$kc" --timestamp=none --identifier com.evbarleyg.arbor.probe "$work/signed"

step "5  sign.sh"
fresh fifth
made for-sign -- --keychain "$kc" > /dev/null
app="$work/Arbor.app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Helpers"
cp /usr/bin/true "$app/Contents/MacOS/Arbor"
cp /usr/bin/true "$app/Contents/Helpers/arborctl"
cat > "$app/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleIdentifier</key><string>com.evbarleyg.arbor</string>
  <key>CFBundleExecutable</key><string>Arbor</string>
  <key>CFBundlePackageType</key><string>APPL</string>
</dict></plist>
PLIST
stamp() { plutil -extract ArborSignature raw "$app/Contents/Info.plist"; }
kind() { codesign --display --verbose=2 "$app" 2>&1 | grep -E '^(Signature=|Authority=)' | head -n 1; }
ARBOR_SIGN_IDENTITY=- limit 60 "$ARBOR_ROOT/scripts/sign.sh" "$app" | sed 's/^/    /'
check "ad hoc: the stamp and codesign agree" same "$(stamp) $(kind)" "adhoc Signature=adhoc"
check "the signature covers the stamp" codesign --verify --deep --strict "$app"
ARBOR_SIGN_KEYCHAIN=$kc limit 60 "$ARBOR_ROOT/scripts/sign.sh" "$app" | sed 's/^/    /'
check "with the certificate: the stamp and codesign agree" same "$(stamp) $(kind)" "local Authority=$name"
check "the signature covers the stamp" codesign --verify --deep --strict "$app"

step "6  at a terminal, a keychain of its own"
fresh sixth
limit 70 "$ARBOR_ROOT/scripts/at-a-terminal.py" 60 "$make_identity" --keychain "$kc" > "$ARBOR_OUT/terminal.txt" 2>&1
code=$?
tr -d '\r' < "$ARBOR_OUT/terminal.txt" | sed 's/^/    /' | head -n 8 | cut -c 1-200
echo "  the key's partition list: [$(partitions "$kc")]"
check "it succeeds" same "$code" 0
check "it asks for no password" without "$(cat "$ARBOR_OUT/terminal.txt")" "assword:"
check "it allows for a dialog and does not promise one" with "$(cat "$ARBOR_OUT/terminal.txt")" "If macOS now asks for the keychain's password"
check "none came" quiet
check "the script ends by saying that codesign can sign" with "$(cat "$ARBOR_OUT/terminal.txt")" "codesign can sign with it"
check "and the next signature asks nobody" signs "$kc"

step "7  the account's own login keychain"
list
login="$HOME/Library/Keychains/login.keychain-db"
identities() { security find-identity -p codesigning "$login" 2>&1 | grep -E '^ +[0-9]+\)' | sort -u; }
identities > "$work/login-before.txt"
echo "  the login keychain holds $(grep -c "" "$work/login-before.txt") identities for signing code"
at_exit 'limit 30 "$make_identity" --remove < /dev/null > /dev/null 2>&1'
made login ARBOR_DIALOG_WAIT=6
check "told nothing, it uses the login keychain" with "$said" "in $login"
check "macOS asks, nobody answers, and it gives up in the time it was given" same "$code $(echo "$said" | grep -c "It had no answer in 6 seconds")" "1 1"
check "it says that the dialog may still be there, and what to do about it" \
  with "$said" "A dialog of macOS's may still be on screen. It asks about a key that is gone: close it with Deny."
check "which is so: the dialog has outlived codesign and the key" asks
echo "  it says:"; told SecurityAgent; shot orphan
check "it calls the key by the certificate's name" with "$(told SecurityAgent)" "codesign wants to access key “${name}” in your keychain."
check "Deny closes it" press Deny
sleep 1
check "and it has gone" quiet
identities > "$work/login-after.txt"
check "the login keychain lists what it listed before" cmp -s "$work/login-before.txt" "$work/login-after.txt"
check "nothing is left of the certificate" without "$(security find-certificate -a -c "$name" "$login" 2>&1)" "$name"
limit 70 "$ARBOR_ROOT/scripts/at-a-terminal.py" 60 "$make_identity" > "$ARBOR_OUT/denied.txt" 2>&1 &
started $!; asking=$!
if check "at a terminal: the dialog comes" await_dialog 15; then sleep 1; press Deny; fi
ended "$asking" 700
tr -d '\r' < "$ARBOR_OUT/denied.txt" | sed 's/^/    /' | cut -c 1-200
check "it had said that macOS would ask, and what to choose" with "$(cat "$ARBOR_OUT/denied.txt")" "macOS will now ask for your login keychain's password"
check "after Deny it says what codesign's word means" with "$(cat "$ARBOR_OUT/denied.txt")" "answered Deny or closed: nothing was signed"
check "and speaks of no dialog left behind" without "$(cat "$ARBOR_OUT/denied.txt")" "still be on screen"
check "nothing is left of the certificate" without "$(security find-certificate -a -c "$name" "$login" 2>&1)" "$name"

step "8  as a person runs it"
# Nobody here knows the password of the account's login keychain, so the Mac gets a new one. It asks as the old one did.
security delete-keychain "$login"
security create-keychain -p "$pw" "$login" && security set-keychain-settings "$login"
security default-keychain -d user -s "$login"
security list-keychains -d user -s "$login"
listed_before=$login
if ! security unlock-keychain -p "$pw" "$login"; then
  # macOS 26: for a file of that name it refuses the very password it was made with, here and in its dialog.
  echo "  THIS macOS DOES NOT TAKE THE PASSWORD THE LOGIN KEYCHAIN WAS MADE WITH: the road cannot be gone to its end here"
  exit 0
fi
limit 90 "$ARBOR_ROOT/scripts/at-a-terminal.py" 80 "$make_identity" > "$ARBOR_OUT/road.txt" 2>&1 &
started $!; asking=$!
if check "the dialog comes" await_dialog 15; then
  sleep 1
  told SecurityAgent; shot road-dialog
  # The field has the keyboard. Letters and digits only, one key each.
  for ((i = 0; i < ${#pw}; i++)); do key "${pw:i:1}" > /dev/null; done
  check "the password, and Always Allow" press "Always Allow"
fi
ended "$asking" 900
tr -d '\r' < "$ARBOR_OUT/road.txt" | sed 's/^/    /' | head -n 9 | cut -c 1-200
check "the script ends by saying that codesign can sign" with "$(cat "$ARBOR_OUT/road.txt")" "codesign can sign with it"
check "no dialog is left" quiet
echo "  the key's partition list: [$(partitions "$login")]"
check "Always Allow has put codesign's partition on the key's list" with "$(partitions "$login")" "apple:"
check "the next signature asks nobody" signs "$login"
limit 60 "$ARBOR_ROOT/scripts/sign.sh" "$app" | sed 's/^/    /'
check "sign.sh, told nothing, finds it and signs twice with it, and nobody is asked" same "$(stamp) $(kind) $(asks && echo asked)" "local Authority=$name "
made again-login
check "run again with nobody there: nothing to do, and nobody is asked" same "$code $(echo "$said" | grep -c "Nothing to do") $(asks && echo asked)" "0 1 "
made login-removed -- --remove
check "--remove takes it out again" same "$code $(echo "$said" | grep -c "^Deleted the certificate")" "0 1"
limit 60 "$ARBOR_ROOT/scripts/sign.sh" "$app" | sed 's/^/    /'
check "sign.sh is back to ad hoc, and says so in the bundle" same "$(stamp) $(kind)" "adhoc Signature=adhoc"
true
