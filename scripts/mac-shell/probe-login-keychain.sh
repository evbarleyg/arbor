#!/bin/bash
# A probe, not to be merged: what macOS asks when codesign uses a key that a script has just imported into the LOGIN keychain.
#
#   scripts/mac-shell/run.sh --bare --on macos-15 scripts/mac-shell/probe-login-keychain.sh
#
# In keychains that a test makes for itself no dialog comes; in the account's own login keychain one does, calls the key "identity", and stays
# after codesign has been killed. A: the account's own login keychain, whose password nobody knows: what the dialog calls the key when the
# imported file has another name, what Deny makes codesign say, how long a dialog outlives codesign, how the key's access list differs from one in
# a keychain of the test's own. B: the login keychain made anew with a known password: does it ask too? If so, the whole road.
ARBOR_TIME_LIMIT=${ARBOR_TIME_LIMIT:-520}
source "$(dirname "$0")/lib.sh"
needs_throwaway_mac "put keys into the account's login keychain, answer macOS's dialogs, and replace the login keychain by a new one"
[ -z "${ARBOR_REHEARSAL:-}" ] || { echo "a rehearsal has no keychains and no codesign"; exit 77; }

AXFIND="$ARBOR_ROOT/.build/mac-shell/axfind"
scratch_dir login work real
make_identity="$ARBOR_ROOT/scripts/make-signing-identity.sh"
name="Arbor Local Signing"
pw="probe$RANDOM"
login="$HOME/Library/Keychains/login.keychain-db"

with() { case "$1" in *"$2"*) return 0 ;; *) return 1 ;; esac; }
on_screen() { "$ARBOR_POINTER" windows --on-screen | awk '{ $1 = $2 = $3 = $4 = $5 = $6 = $7 = $8 = ""; sub(/^ +/, ""); print }' | sort -u; }
pid_named() {
  "$ARBOR_POINTER" windows --on-screen | awk -v name="$1" '{ pid = $2; $1 = $2 = $3 = $4 = $5 = $6 = $7 = $8 = ""; sub(/^ +/, ""); if ($0 == name) { print pid; exit } }'
}
told() {
  local pid; pid=$(pid_named "$1"); [ -n "$pid" ] || return 0
  limit 5 "$AXFIND" "$pid" tree 2>/dev/null | grep -E "AXStaticText|AXButton|AXTextField|AXCheckBox" | grep -vE '"" "" ' | sed -E 's/^ +//; s/ -?[0-9]+ -?[0-9]+ [0-9]+ [0-9]+$//' \
    | cut -c 1-220 | head -n 12 | sed 's/^/        /'
}
press() {
  local point; point=$(limit 5 "$AXFIND" "$(pid_named "$1")" point AXButton "$2" 2> /dev/null) || { echo "     no button $2"; return 1; }
  # shellcheck disable=SC2086
  click $point > /dev/null
}
asks() { on_screen | grep -qx SecurityAgent; }
# await_dialog <seconds>: whether SecurityAgent has come on screen in that time
await_dialog() { local n=0; while [ "$n" -lt $(($1 * 4)) ]; do asks && return 0; sleep 0.25; n=$((n + 1)); done; return 1; }
# how_long <seconds>: for how many seconds the dialog is still there
how_long() { local n=0; while [ "$n" -lt "$1" ] && asks; do sleep 1; n=$((n + 1)); done; echo "$n"; }
# pack <stem of the file>: a key and a certificate as make-signing-identity.sh makes them
pack() {
  /usr/bin/openssl req -x509 -newkey rsa:2048 -nodes -sha256 -days 3650 -config "$work/openssl.cnf" -keyout "$work/key.pem" -out "$work/cert.pem" 2> /dev/null
  /usr/bin/openssl pkcs12 -export -inkey "$work/key.pem" -in "$work/cert.pem" -name "$name" -out "$work/$1.p12" -passout pass:transport 2> /dev/null
  /usr/bin/openssl x509 -in "$work/cert.pem" -noout -fingerprint -sha1 | sed 's/.*=//' | tr -d ':'
}
# acl_of <keychain>: the access lists of the private keys in it that an import has named; nothing else of the keychain is shown
acl_of() {
  limit 20 security dump-keychain -a "$1" 2> /dev/null | awk '
    /^keychain: / { show = 0; block = "" }
    /^class: / { private = ($2 == "0x00000010") }
    private && /0x00000001 <blob>=("Imported Private Key"|"Arbor Local Signing")/ { show = 1 }
    show && /^(access:|    entry|        (authorizations|don.t-require-password|require-password|description|applications)|            [0-9]+:)/ { print "        " $0 }' | cut -c 1-400
}
sign() { cp /usr/bin/true "$work/probe"; limit "$1" codesign --force --sign "$2" --keychain "$3" --timestamp=none --identifier com.evbarleyg.arbor.probe "$work/probe"; }

step "the Mac"
echo "macOS $(sw_vers -productVersion) on $(uname -m)"
echo "the search list: $(security list-keychains -d user | tr -d '\n'); the default: $(security default-keychain -d user | tr -d '\n')"
limit 10 security show-keychain-info "$login" 2>&1 | sed "s#$HOME#~#"
newest=$(ls -d /Applications/Xcode*.app 2>/dev/null | grep -viE 'beta|_rc' | sort -V | tail -n 1)
[ -n "$newest" ] && export DEVELOPER_DIR="$newest/Contents/Developer"
mkdir -p "$(dirname "$ARBOR_POINTER")"
limit 150 swiftc -O -swift-version 5 "$ARBOR_ROOT/scripts/mac-shell/pointer.swift" -o "$ARBOR_POINTER" > "$ARBOR_OUT/build-pointer.log" 2>&1 &
started $!; first=$!
limit 150 swiftc -O -swift-version 5 "$ARBOR_ROOT/scripts/mac-shell/axfind.swift" -o "$AXFIND" > "$ARBOR_OUT/build-axfind.log" 2>&1
ended "$first" 1600
[ -x "$ARBOR_POINTER" ] && [ -x "$AXFIND" ] || { cat "$ARBOR_OUT"/build-*.log; die "the tools did not compile"; }
cat > "$work/openssl.cnf" <<CONFIG
[ req ]
prompt = no
distinguished_name = subject
x509_extensions = extensions
[ subject ]
CN = $name
[ extensions ]
basicConstraints = critical,CA:false
keyUsage = critical,digitalSignature
extendedKeyUsage = critical,codeSigning
CONFIG

step "A1  the account's own login keychain: the file is named after the certificate; Deny"
sha=$(pack "$name")
security import "$work/$name.p12" -k "$login" -f pkcs12 -P transport -x -T /usr/bin/codesign
at_exit 'security delete-identity -Z "$sha" "$login" > /dev/null 2>&1'
sign 40 "$sha" "$login" > "$work/a1.txt" 2>&1 &
started $!; signing=$!
if await_dialog 10; then
  sleep 1
  echo "  A DIALOG CAME:"; told SecurityAgent; shot a1-dialog
  press SecurityAgent Deny
  ended "$signing" 100
  echo "  after Deny codesign said: $(tr '\n' '|' < "$work/a1.txt" | cut -c 1-300)"
  echo "  the dialog is still there after Deny: $(how_long 5) s"
else
  ended "$signing" 450
  echo "  NO DIALOG CAME; codesign said: $(tr '\n' '|' < "$work/a1.txt" | cut -c 1-300)"
fi

step "A2  the key's access list there, and in a keychain of the test's own"
echo "  in the login keychain:"
acl_of "$login"
own="$work/own.keychain-db"
security create-keychain -p "$pw" "$own" && security set-keychain-settings "$own" && security unlock-keychain -p "$pw" "$own"
security import "$work/$name.p12" -k "$own" -f pkcs12 -P transport -x -T /usr/bin/codesign > /dev/null
echo "  in a keychain of the test's own:"
acl_of "$own"
security delete-keychain "$own"

step "A3  how long a dialog outlives codesign"
for signal in TERM INT; do
  sign 40 "$sha" "$login" > "$work/a3.txt" 2>&1 &
  started $!; signing=$!
  if await_dialog 10; then
    pkill "-$signal" -x codesign
    ended "$signing" 100
    echo "  codesign ended with $signal; the dialog stayed $(how_long 20) s of 20"
    if asks; then key escape > /dev/null; sleep 1; echo "  after Escape it is $(asks && echo "STILL THERE" || echo gone)"; fi
  else
    ended "$signing" 450
    echo "  no dialog this time; codesign said: $(tr '\n' '|' < "$work/a3.txt" | cut -c 1-200)"
  fi
done
sign 40 "$sha" "$login" > "$work/a3.txt" 2>&1 &
started $!; signing=$!
if await_dialog 10; then
  security delete-identity -Z "$sha" "$login" > /dev/null 2>&1
  echo "  the key deleted under the dialog; it stayed $(how_long 8) s of 8; codesign $(kill -0 "$signing" 2> /dev/null && echo "still waits" || echo "has ended")"
  asks && { press SecurityAgent Deny; sleep 1; }
fi
ended "$signing" 450
security delete-identity -Z "$sha" "$login" > /dev/null 2>&1
echo "  left on screen: $(asks && echo "A DIALOG" || echo nothing)"

step "B  the login keychain made anew, with a known password"
security delete-keychain "$login"
security create-keychain -p "$pw" "$login"; echo "  create: $?"
security set-keychain-settings "$login"; echo "  settings: $?"
security unlock-keychain -p "$pw" "$login"; echo "  unlock with the password it was made with: $?"
security default-keychain -d user -s "$login"
security list-keychains -d user -s "$login"
limit 90 "$ARBOR_ROOT/scripts/at-a-terminal.py" 80 "$make_identity" > "$ARBOR_OUT/road.txt" 2>&1 &
started $!; asking=$!
if await_dialog 15; then
  sleep 1
  echo "  IT ASKS TOO:"; told SecurityAgent; shot b-dialog
  for ((i = 0; i < ${#pw}; i++)); do key "${pw:i:1}" > /dev/null; done
  shot b-typed
  press SecurityAgent "Always Allow"
  sleep 2
  if asks; then echo "  A SECOND DIALOG, OR THE SAME STILL:"; told SecurityAgent; shot b-second; fi
else
  echo "  A LOGIN KEYCHAIN MADE ANEW DOES NOT ASK"
fi
ended "$asking" 900
tr -d '\r' < "$ARBOR_OUT/road.txt" | sed 's/^/    /' | head -n 12 | cut -c 1-200
check "the script ends by saying that codesign can sign" with "$(cat "$ARBOR_OUT/road.txt")" "codesign can sign with it"
sign 15 "$name" "$login" 2>&1 | head -n 2
echo "  the next signature: exit codes ${PIPESTATUS[*]}; a dialog: $(asks && echo YES || echo no)"
echo "  the key's access list now:"
acl_of "$login"
asks && key escape > /dev/null
true
