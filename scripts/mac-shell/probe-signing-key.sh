#!/bin/bash
# Why could codesign not use the key that scripts/make-signing-identity.sh had just made? A probe, not a check: it asks macOS, one thing at a time, and prints
# every tool's own words.
#
#   scripts/mac-shell/run.sh scripts/mac-shell/probe-signing-key.sh
#
# check-F13.sh ran for the first time on a hosted Mac on 2026-10-15 (macOS 26.6.2, LibreSSL 3.3.6) and ended in its second step of ten:
#   - given the keychain's password, the tool said "$ARBOR_KEYCHAIN_PASSWORD is not this keychain's password". It was. The tool lets codesign at "the key
#     with our label", and the keychain showed the key under the label "Imported Private Key";
#   - with every key of that keychain let at, label or no label, codesign still did not sign within twenty seconds. What it said, nobody kept.
#
# Everything happens in lib-F13.sh's place apart: a throwaway HOME and keychains of this run's own in /tmp. Only on GitHub's Macs all the same: a
# codesign that may not use a key asks in a dialog.
source "$(dirname "$0")/lib-F13.sh"
needs_throwaway_mac "let codesign ask for a key, which it does in a dialog on the screen"
f13_describe_the_mac

# say <what> <command…>: the command, its words and its exit code; never the end of the script.
say() {
  local what=$1 code
  shift
  echo "-- $what"
  echo "   \$ $*" | sed "s/$password/<the password>/g"
  limit 20 "$@" 2>&1 | sed "s/$password/<the password>/g" | tail -n "${SAY_LINES:-12}" | sed 's/^/   | /'
  code=${PIPESTATUS[0]}
  echo "   exit code $code"
  return "$code"
}
# The private keys of a keychain: label, application label (the hash of the public key) and whether they may sign.
keys_of() {
  security dump-keychain "$1" 2>/dev/null | awk '
    /^class: 0x00000010/ { key = 1; print "   key:" }
    /^class:/ && !/0x00000010/ { key = 0 }
    key && (/0x00000001 / || /0x00000006 / || /0x00000017 / || /"labl"/) { print "     " $0 }'
}
# sign_with <keychain> <what to name the identity by>
sign_with() {
  cp /usr/bin/true "$sandbox/to-sign"
  say "codesign, the identity named by $2" codesign --force --verbose=4 --sign "$2" --keychain "$1" --timestamp=none "$sandbox/to-sign"
}
tool() { ARBOR_KEYCHAIN_PASSWORD=$password limit 120 "$ARBOR_ROOT/scripts/make-signing-identity.sh" --keychain "$1" < /dev/null 2>&1 | sed 's/^/   | /'; }
hash_in() { security find-identity -p codesigning "$1" | sed -n 's/^ *1) \([0-9A-F]*\) .*/\1/p' | head -n 1; }

step "1  as check-F13.sh did it: the tool, with the password"
f13_make_keychain
tool "$keychain" | head -n 6
keys_of "$keychain"
hash=$(hash_in "$keychain")
echo "the identity's hash: $hash"
sign_with "$keychain" "$identity" && echo "SIGNED: as the tool left it"

step "2  which word lets codesign at the key?"
say "by our label, as the tool asks" security set-key-partition-list -S apple-tool:,apple: -s -l "$identity" -k "$password" "$keychain"
say "by the label the keychain shows" security set-key-partition-list -S apple-tool:,apple: -s -l "Imported Private Key" -k "$password" "$keychain"
say "every key that can sign" security set-key-partition-list -S apple-tool:,apple: -s -k "$password" "$keychain"
say "the same, with codesign's own partition named as well" security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "$password" "$keychain"
say "a wrong password, for what that looks like" security set-key-partition-list -S apple-tool:,apple: -s -k "not-$password" "$keychain"

step "3  does codesign sign now, and what does it say?"
sign_with "$keychain" "$identity" && echo "SIGNED: by its name, the keychain named, on no search list"
sign_with "$keychain" "$hash" && echo "SIGNED: by its hash, the keychain named, on no search list"

step "4  with the keychain on the throwaway HOME's search list"
# safe anywhere: HOME is the throwaway one, which f13_make_keychain has made sure `security` follows
say "onto the search list" security list-keychains -d user -s "$keychain"
say "the search list" security list-keychains -d user
say "identities, as codesign would look for them" security find-identity -p codesigning
sign_with "$keychain" "$identity" && echo "SIGNED: by its name, on the search list"
cp /usr/bin/true "$sandbox/to-sign"
say "codesign without --keychain" codesign --force --verbose=4 --sign "$identity" --timestamp=none "$sandbox/to-sign" && echo "SIGNED: without --keychain"
check "the account's own search list and default keychain are as they were" unchanged "$real_settings" "$(real_keychain_settings)"

step "5  is it the trust? The same certificate, trusted for code signing in the throwaway HOME only"
security find-certificate -c "$identity" -p "$keychain" > "$sandbox/certificate.pem"
# safe anywhere: user trust settings under the throwaway HOME; if macOS wants to ask somebody, twenty seconds end it
say "trusted for code signing" security add-trusted-cert -r trustRoot -p codeSign -k "$keychain" "$sandbox/certificate.pem"
say "valid identities" security find-identity -v -p codesigning "$keychain"
sign_with "$keychain" "$identity" && echo "SIGNED: once trusted"

step "6  is it how the key came in? A second keychain, the key imported for every application (-A)"
second="$sandbox/second.keychain-db"
new_keychain "$second" || die "could not make a second keychain"
work="$sandbox/second"
mkdir -p "$work"
cat > "$work/openssl.cnf" <<CNF
[req]
distinguished_name = dn
x509_extensions = ext
prompt = no
[dn]
CN = Arbor Probe Signing
[ext]
basicConstraints = critical, CA:false
keyUsage = critical, digitalSignature
extendedKeyUsage = critical, codeSigning
CNF
for openssl in /usr/bin/openssl /opt/homebrew/opt/openssl@3/bin/openssl; do
  [ -x "$openssl" ] || continue
  echo "== with $("$openssl" version)"
  legacy=""
  case "$("$openssl" version)" in LibreSSL* | "OpenSSL 1."*) ;; *) legacy=-legacy ;; esac
  "$openssl" req -x509 -newkey rsa:2048 -nodes -sha256 -days 2 -config "$work/openssl.cnf" -keyout "$work/key.pem" -out "$work/certificate.pem" 2> /dev/null
  # shellcheck disable=SC2086
  "$openssl" pkcs12 -export $legacy -inkey "$work/key.pem" -in "$work/certificate.pem" -name "Arbor Probe Signing" -out "$work/identity.p12" -passout pass:probe
  say "what the file calls the key and the certificate" sh -c "'$openssl' pkcs12 -in '$work/identity.p12' $legacy -passin pass:probe -nodes -info 2>&1 | grep -iE 'friendlyName|localKeyID|MAC|PKCS7|bag'"
  say "imported, for every application" security import "$work/identity.p12" -k "$second" -f pkcs12 -P probe -A
  keys_of "$second"
  cp /usr/bin/true "$sandbox/to-sign"
  say "codesign before any partition list" codesign --force --verbose=4 --sign "Arbor Probe Signing" --keychain "$second" --timestamp=none "$sandbox/to-sign" \
    && echo "SIGNED: imported with -A, no partition list"
  say "every key that can sign" security set-key-partition-list -S apple-tool:,apple: -s -k "$password" "$second"
  cp /usr/bin/true "$sandbox/to-sign"
  say "codesign after it" codesign --force --verbose=4 --sign "Arbor Probe Signing" --keychain "$second" --timestamp=none "$sandbox/to-sign" \
    && echo "SIGNED: imported with -A, with the partition list"
  say "the identity goes again" security delete-identity -c "Arbor Probe Signing" "$second"
done

step "7  is it the throwaway HOME? The same keychain file, asked under the account's own HOME, on no search list"
cp /usr/bin/true "$sandbox/to-sign"
# safe anywhere: a throwaway Mac's account, and the keychain is named: nothing is put on a list
HOME=$real_home say "codesign under the account's HOME" codesign --force --verbose=4 --sign "$identity" --keychain "$keychain" --timestamp=none "$sandbox/to-sign" \
  && echo "SIGNED: under the account's own HOME"
check "the account's own search list and default keychain are as they were" unchanged "$real_settings" "$(real_keychain_settings)"

step "what signed"
echo "(the lines above that begin with SIGNED)"
