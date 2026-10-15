#!/bin/bash
# Tests the parts of the release tooling that need no Mac: version.sh, release-notes.sh, sign.sh and make-signing-identity.sh
# against stand-ins for macOS's tools and, against a stand-in for GitHub's API on this machine, publish-release.sh. Part of
# `make check`. Everything happens in a temporary copy, so a real build/ is left alone and nothing reaches the network.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 2

root=$(mktemp -d) || { echo "release-tools-test.sh: no temporary folder" >&2; exit 2; }
server=""
cleanup() {
  [ -z "$server" ] || kill "$server" 2>/dev/null
  rm -rf "${root:?}"
}
trap cleanup EXIT

failed=0
check() {  # check "<what should hold>" <command…>
  local what=$1
  shift
  if "$@" >/dev/null 2>&1; then echo "  ✔ $what"; else echo "  ✘ $what"; failed=1; fi
}
contains() { grep -qF -- "$2" "$1"; }
lacks() { ! grep -qF -- "$2" "$1"; }
fails() { ! "$@"; }

mkdir -p "$root/scripts" "$root/build"
cp scripts/version.sh scripts/release-notes.sh scripts/publish-release.sh "$root/scripts/"
echo "1.2.3" > "$root/VERSION"
cat > "$root/CHANGELOG.md" <<'CHANGELOG'
# Changelog

Newest first.

## Unreleased

### Added

- **Tabs.** Drop a window on the middle
  of another to stack them.
- Second item.

A paragraph that is
wrapped in the file.

```
code stays
  as it is
```

| a | b |
|---|---|

## 1.2.2

- Old news.
CHANGELOG
# No Git in the copy, as in a source archive.
export GIT_DIR="$root/no-such-repository"
unset ARBOR_VERSION ARBOR_NOTARIZED ARBOR_DRAFT GITHUB_ACTIONS GITHUB_API_URL GITHUB_REPOSITORY GITHUB_SHA GITHUB_TOKEN

echo "version.sh"
check "the version is the VERSION file's" test "$("$root/scripts/version.sh" version)" = 1.2.3
check "without Git the build is 0 and the commit unknown" test "$("$root/scripts/version.sh")" = "1.2.3 (build 0, unknown)"
check "ARBOR_VERSION replaces it" test "$(ARBOR_VERSION=2.0.0-rc.1 "$root/scripts/version.sh" version)" = 2.0.0-rc.1
check "what is not a version is refused" fails env ARBOR_VERSION='1.0;x' "$root/scripts/version.sh" version
check "so is a path" fails env ARBOR_VERSION='1.0.0-../x' "$root/scripts/version.sh" version
check "this repository's own VERSION is accepted" ./scripts/version.sh version

echo "release-notes.sh"
printf 'abc  Arbor-1.2.3.zip\ndef  Arbor-1.2.3.dmg\n' > "$root/build/Arbor-1.2.3-checksums.txt"
notes="$root/notes.md"
"$root/scripts/release-notes.sh" > "$notes"
check "they start with the top section's first line" test "$(head -n 1 "$notes")" = "### Added"
check "wrapped list items are joined" contains "$notes" "- **Tabs.** Drop a window on the middle of another to stack them."
check "wrapped paragraphs are joined" contains "$notes" "A paragraph that is wrapped in the file."
check "the next item starts a new line" contains "$notes" "- Second item."
check "code blocks keep their lines" contains "$notes" "  as it is"
check "tables keep their rows" contains "$notes" "|---|---|"
check "older sections stay out" lacks "$notes" "Old news"
check "the heading of the section stays out" lacks "$notes" "Unreleased"
check "the first launch is explained" contains "$notes" "Open Anyway"
check "and the way around it" contains "$notes" "xattr -dr com.apple.quarantine /Applications/Arbor.app"
check "the files are named after the version" contains "$notes" "Arbor-1.2.3.dmg"
check "the checksums are listed" contains "$notes" "def  Arbor-1.2.3.dmg"
ARBOR_NOTARIZED=1 "$root/scripts/release-notes.sh" > "$root/notarized.md"
check "a notarized build's notes leave Gatekeeper out" lacks "$root/notarized.md" "Open Anyway"

echo "publish-release.sh"
check "it refuses to run before make release" fails "$root/scripts/publish-release.sh" --dry-run
cp "$notes" "$root/build/Arbor-1.2.3-notes.md"
printf 'disk image' > "$root/build/Arbor-1.2.3.dmg"
printf 'archive' > "$root/build/Arbor-1.2.3.zip"
printf 'cask' > "$root/build/arbor.rb"
export GITHUB_SHA=0123456789abcdef0123456789abcdef01234567
"$root/scripts/publish-release.sh" --dry-run > "$root/dry-run.txt" 2>&1
check "a dry run needs no token and names the tag" contains "$root/dry-run.txt" '"tag_name": "v1.2.3"'
check "a dry run says it is a draft" contains "$root/dry-run.txt" '"draft": true'
check "without a token nothing is sent" fails "$root/scripts/publish-release.sh"

finish() {
  if [ "$failed" -eq 0 ]; then echo "release tools test passed"; else echo "release tools test FAILED"; fi
  exit "$failed"
}

# Stand-ins for the tools of macOS that sign.sh and make-signing-identity.sh call, first on the PATH, on a Mac as well: nothing here
# may reach a real keychain. What they answer is what hosted Macs answered to scripts/mac-shell/check-signing.sh (collab/reality.json).
echo "sign.sh"
tools="$root/mac-tools"
mkdir -p "$tools" "$root/signed/Arbor.app/Contents/Helpers"
cp scripts/sign.sh "$root/scripts/"
app="$root/signed/Arbor.app"
cat > "$tools/plutil" <<'TOOL'
#!/bin/bash
# plutil -replace <key> -string <value> <file>
[ "$1" = -replace ] && [ "$3" = -string ] || exit 1
grep -v "^$2=" "$5" > "$5.new" 2>/dev/null
echo "$2=$4" >> "$5.new"
mv "$5.new" "$5"
TOOL
cat > "$tools/codesign" <<'TOOL'
#!/bin/bash
# Writes down what it was asked and, for a bundle, what its property list said at that moment: a signature covers the list.
echo "$*" >> "$FAKE_MAC/codesign.log"
target=${!#}
case "$*" in *--sign*) [ -f "$target/Contents/Info.plist" ] && grep '^ArborSignature=' "$target/Contents/Info.plist" >> "$FAKE_MAC/signed-with-stamp" ;; esac
exit 0
TOOL
cat > "$tools/security" <<'TOOL'
#!/bin/bash
[ "$1" = find-identity ] || exit 1
echo "Policy: Code Signing"
echo "  Matching identities"
[ -f "$FAKE_MAC/has-identity" ] && echo '  1) 0123456789ABCDEF0123456789ABCDEF01234567 "Arbor Local Signing" (CSSMERR_TP_NOT_TRUSTED)'
echo "     1 identities found"
TOOL
chmod +x "$tools"/*
signed() {  # signed <identity, or nothing>: the stamp the bundle had when it was signed, and sign.sh's first line
  rm -f "$root/signed-with-stamp" "$root/codesign.log"
  echo "CFBundleVersion=1" > "$app/Contents/Info.plist"
  env FAKE_MAC="$root" PATH="$tools:$PATH" ${1:+ARBOR_SIGN_IDENTITY="$1"} "$root/scripts/sign.sh" "$app" > "$root/sign.txt" 2>&1 || echo "failed: $?"
  cat "$root/signed-with-stamp" 2>/dev/null
}
unset ARBOR_SIGN_IDENTITY ARBOR_SIGN_KEYCHAIN ARBOR_RELEASE
check "without a certificate the bundle is stamped ad hoc, before it is signed" test "$(signed)" = "ArborSignature=adhoc"
check "and it says so, with what that costs" contains "$root/sign.txt" "ad hoc. The signature changes with every build"
check "the other keys of the list stay" contains "$app/Contents/Info.plist" "CFBundleVersion=1"
touch "$root/has-identity"
check "with this Mac's own certificate, local" test "$(signed)" = "ArborSignature=local"
env FAKE_MAC="$root" PATH="$tools:$PATH" ARBOR_SIGN_IDENTITY=- "$root/scripts/sign.sh" "$app" > /dev/null 2>&1
check "signed again as it stands, the new stamp takes the old one's place" test "$(grep ArborSignature "$app/Contents/Info.plist")" = "ArborSignature=adhoc"
check "told to sign ad hoc all the same, ad hoc" test "$(signed -)" = "ArborSignature=adhoc"
check "with any other certificate, issued" test "$(signed "Developer ID Application: Somebody")" = "ArborSignature=issued"

echo "make-signing-identity.sh"
# A keychain in a folder: `keys` has "<hash of the public key> <name>" a line, `certificates` "<SHA-1> <that hash> <name>", `allowed` the keys
# somebody has answered Always Allow for, `listed` the search list. $FAKE_MACOS is 14, 15 or 26: they differ in what the import calls a key
# and in codesign's words. In a keychain that lies in ~/Library/Keychains, the login keychain or another, a key has a partition list that
# codesign is not on, so macOS asks, in a dialog that calls the key by the name of the file it came in and outlives codesign; in a keychain
# that lies elsewhere nothing is asked. `answer` is what somebody does about it.
tools="$root/keychain-tools"
mkdir -p "$tools" "$root/home/Library/Keychains"
cp scripts/make-signing-identity.sh "$root/scripts/"
cat > "$tools/uname" <<'TOOL'
#!/bin/bash
echo Darwin
TOOL
cat > "$tools/openssl" <<'TOOL'
#!/bin/bash
argument_after() { local wanted=$1; shift; while [ $# -gt 1 ]; do [ "$1" = "$wanted" ] && { echo "$2"; return; }; shift; done; }
case "$1" in
  version) echo "${FAKE_OPENSSL:-LibreSSL 3.3.6}" ;;
  rand) echo 00112233445566778899aabbccddeeff ;;
  req)
    echo key > "$(argument_after -keyout "$@")"
    echo "$(($(cat "$FAKE_MAC/keychain/made") + 1))" > "$FAKE_MAC/keychain/made"
    echo "AB:CD:EF:01:23:45:67:89:AB:CD:EF:01:23:45:67:89:AB:CD:EF:0$(cat "$FAKE_MAC/keychain/made")" > "$(argument_after -out "$@")"
    ;;
  x509)
    case " $* " in
      *" -fingerprint "*) case "${FAKE_OPENSSL:-LibreSSL}" in LibreSSL*) printf 'SHA1' ;; *) printf 'sha1' ;; esac; echo " Fingerprint=$(cat "$(argument_after -in "$@")")" ;;
      *) echo "notAfter=Oct 13 04:00:00 2036 GMT" ;;
    esac
    ;;
  pkcs12)
    form=old
    case "${FAKE_OPENSSL:-LibreSSL}" in "OpenSSL 3"*) case " $* " in *" -legacy "*) ;; *) form=new ;; esac ;; esac
    echo "$form $(tr -d ':' < "$(argument_after -in "$@")") $(argument_after -name "$@")" > "$(argument_after -out "$@")"
    ;;
esac
TOOL
cat > "$tools/security" <<'TOOL'
#!/bin/bash
cd "$FAKE_MAC/keychain" || exit 2
echo "$*" >> asked
echo "$1" >> "$FAKE_MAC/every-command"
argument_after() { local wanted=$1; shift; while [ $# -gt 1 ]; do [ "$1" = "$wanted" ] && { echo "$2"; return; }; shift; done; }
without() { grep -v "$1" "$2" > left; mv left "$2"; }
command=$1
shift
case "$command" in
  find-identity)
    n=0
    while read -r sha id name; do
      grep -q "^$id " keys || continue
      n=$((n + 1)); echo "  $n) $sha \"$name\" (CSSMERR_TP_NOT_TRUSTED)"
    done < certificates
    echo "     $n identities found"
    ;;
  find-certificate)
    # -c finds every name that contains the one asked for. -Z puts the hash before the attributes. The newest first: no order is promised.
    wanted=$(argument_after -c "$@")
    awk '{ line[NR] = $0 } END { for (n = NR; n > 0; n--) print line[n] }' certificates | while read -r sha id name; do
      case "$name" in *"$wanted"*) ;; *) continue ;; esac
      echo "SHA-1 hash: $sha"
      printf 'keychain: "x"\nversion: 512\nclass: 0x80001000 \nattributes:\n    "alis"<blob>="%s"\n    "hpky"<blob>=%s  "\\212?"\n    "labl"<blob>="%s"\n' "$name" "$id" "$name"
    done
    ;;
  import)
    read -r form sha name < "$1"
    [ "$form" = old ] || { echo "security: SecKeychainItemImport: MAC verification failed during PKCS12 import (wrong password?)" >&2; exit 1; }
    if [ "$FAKE_MACOS" = 14 ]; then label=$name; else label="Imported Private Key"; fi
    echo "$sha 0xAB${sha: -2} $name" >> certificates
    file=${1##*/}
    echo "0xAB${sha: -2} ${file%.p12}" >> came-in
    [ -f half-an-import ] || echo "0xAB${sha: -2} \"$label\"" >> keys
    echo "1 identity imported."
    ;;
  list-keychains) sed 's/.*/    "&"/' listed ;;
  delete-identity)
    [ ! -f locked ] || { echo "security: SecKeychainItemDelete: User interaction is not allowed." >&2; exit 1; }
    sha=$(argument_after -Z "$@")
    id=$(grep "^$sha " certificates | cut -d ' ' -f 2)
    grep -q "^${id:-none} " keys || { echo "security: SecIdentitySearchCreate: The specified item could not be found in the keychain." >&2; exit 1; }
    without "^$sha " certificates
    without "^$id " keys
    ;;
  delete-certificate)
    [ ! -f locked ] || { echo "Unable to delete certificate matching \"x\"" >&2; exit 1; }
    without "^$(argument_after -Z "$@") " certificates
    ;;
  *) exit 1 ;;
esac
TOOL
cat > "$tools/codesign" <<'TOOL'
#!/bin/bash
cd "$FAKE_MAC/keychain" || exit 2
argument_after() { local wanted=$1; shift; while [ $# -gt 1 ]; do [ "$1" = "$wanted" ] && { echo "$2"; return; }; shift; done; }
case " $* " in
  *" --display "*) echo 'designated => identifier "com.evbarleyg.arbor.probe" and certificate leaf = H"0123"'; exit 0 ;;
esac
sha=$(argument_after --sign "$@")
if ! grep -qxF "$(argument_after --keychain "$@")" listed; then
  if [ "$FAKE_MACOS" = 26 ]; then echo "$sha: no identity found" >&2; else echo "error: The specified item could not be found in the keychain." >&2; fi
  exit 1
fi
case "$(argument_after --keychain "$@")" in */Library/Keychains/*) ;; *) exit 0 ;; esac
id=$(grep "^$sha " certificates | cut -d ' ' -f 2)
grep -qxF "$id" allowed && exit 0
# codesign waits for the answer: Always Allow, Allow, Deny, or none. Only an answer takes the dialog off the screen.
echo "asked about $(grep "^$id " came-in | cut -d ' ' -f 2-)" >> dialogs
case "$(cat answer 2> /dev/null)" in
  always-allow) echo "$id" >> allowed; exit 0 ;;
  allow) exit 0 ;;
  deny) echo "x: errSecInternalComponent" >&2; exit 1 ;;
  *) touch on-screen; exec sleep 60 ;;
esac
TOOL
chmod +x "$tools"/*
login="$root/home/Library/Keychains/login.keychain-db"
other="$root/other.keychain-db"
beside="$root/home/Library/Keychains/another.keychain-db"
touch "$login" "$other" "$beside"
said="$root/identity.txt"
state="$root/keychain"
# a_mac <14|15|26>: a fresh keychain that holds two keys and a certificate of somebody's, with both files on the search list.
a_mac() {
  rm -rf "$state"
  mkdir -p "$state"
  macos=$1
  : > "$state/allowed"; : > "$state/dialogs"; : > "$state/came-in"; echo 0 > "$state/made"
  printf '%s\n' '0xEE01 "Imported Private Key"' '0xEE02 "Arbor Local Signing 2"' > "$state/keys"
  echo "EEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEE02 0xEE02 Arbor Local Signing 2" > "$state/certificates"
  cat "$state/keys" "$state/certificates" > "$state/theirs"
  printf '%s\n' "$login" "$other" > "$state/listed"
}
mac=(env HOME="$root/home" FAKE_MAC="$root" PATH="$tools:$PATH" ARBOR_OPENSSL="$tools/openssl")
# identity [NAME=value…] [-- argument…]: runs the script with nobody at a terminal; the exit code is in $code.
identity() {
  local settings=()
  while [ $# -gt 0 ] && [ "$1" != -- ]; do settings+=("$1"); shift; done
  [ $# -eq 0 ] || shift
  "${mac[@]}" FAKE_MACOS="$macos" ARBOR_UNATTENDED=1 ${settings[@]+"${settings[@]}"} "$root/scripts/make-signing-identity.sh" "$@" < /dev/null > "$said" 2>&1
  code=$?
}
# somebody [--ctrl-c <seconds>] [argument…]: the same with somebody at a terminal.
somebody() {
  local keys=()
  if [ "${1:-}" = --ctrl-c ]; then keys=(--ctrl-c "$2"); shift 2; fi
  "${mac[@]}" FAKE_MACOS="$macos" scripts/at-a-terminal.py 30 ${keys[@]+"${keys[@]}"} "$root/scripts/make-signing-identity.sh" "$@" > "$said" 2>&1
  code=$?
}
count() { grep -c -- "$1" "$2"; }
# Whatever happened, what was somebody's is as it was; and of ours there is nothing, or one certificate with its key.
as_before() { cat "$state/keys" "$state/certificates" | cmp -s - "$state/theirs"; }
ours_beside_theirs() {
  [ "$(count "^0xAB" "$state/keys") $(count " Arbor Local Signing$" "$state/certificates")" = "1 1" ] \
    && grep -v "^0xAB" "$state/keys" | cat - <(grep -v " Arbor Local Signing$" "$state/certificates") | cmp -s - "$state/theirs"
}
whole_or_nothing() { ours_beside_theirs || as_before; }
unset ARBOR_UNATTENDED ARBOR_OPENSSL ARBOR_DIALOG_WAIT
: > "$root/every-command"

gone='A dialog of macOS'"'"'s may still be on screen. It asks about a key that is gone: close it with Deny.'
for macos_and_openssl in "26 LibreSSL 3.3.6" "26 OpenSSL 3.6.4" "15 LibreSSL 3.3.6" "15 OpenSSL 3.6.4" "14 LibreSSL 3.3.6" "14 OpenSSL 3.6.3"; do
  a_mac "${macos_and_openssl%% *}"
  echo always-allow > "$state/answer"
  FAKE_OPENSSL="${macos_and_openssl#* }" somebody
  check "macOS $macos_and_openssl, as a person runs it: macOS asks once, and it is made" \
    test "$code $(count "codesign can sign with it" "$said") $(cat "$state/dialogs")" = "0 1 asked about Arbor Local Signing"
  check "ours is there, beside what was somebody's" ours_beside_theirs
done
check "the key cannot be exported, and codesign is on its list of applications" contains "$state/asked" " -x -T /usr/bin/codesign"
check "it says beforehand what macOS will ask, and what to choose" \
  contains "$said" "macOS will now ask for your login keychain's password, so that codesign may use Arbor's key. Choose Always Allow, and it"
check "what the dialog will call the key, and what the other two buttons do" \
  contains "$said" 'Its dialog calls the key "Arbor Local Signing". Allow: this once, and it asks again at every build, twice. Deny: nothing is signed.'
check "it asks for no password itself" test "$(grep -ci "password:" "$said")" = 0
check "and has nothing to say about a dialog left behind" lacks "$said" "still be on screen"

echo "  the other answers"
a_mac 26
echo deny > "$state/answer"
somebody
check "Deny: it fails and says what codesign's word means" test "$code $(count "is what codesign says when the dialog was answered Deny or closed: nothing was signed" "$said")" = "1 1"
check "nothing is left" as_before
check "the dialog has gone with the answer, and is not spoken of" lacks "$said" "still be on screen"
a_mac 26
echo allow > "$state/answer"
somebody
check "Allow: it is made" test "$code $(count "codesign can sign with it" "$said")" = "0 1"
somebody
check "and the next signature asks again, as it was told" test "$code $(count "" "$state/dialogs")" = "0 2"
a_mac 26
somebody --ctrl-c 1
check "⌃C at macOS's dialog, the natural way out: the dialog had come" test "$code $(cat "$state/dialogs")" = "130 asked about Arbor Local Signing"
check "nothing is left" as_before
check "but the dialog, which it says" contains "$said" "$gone"

echo "  nobody there"
a_mac 26
identity ARBOR_DIALOG_WAIT=1
check "the dialog is not waited for for ever; it fails and says what to do" \
  test "$code $(count "It had no answer in 1 seconds" "$said") $(count "Run this from a terminal" "$said")" = "1 1 1"
check "in its own words alone: the shell has nothing to add about how the wait was ended" test "$(grep -ciE "alarm|perl|terminated|line [0-9]" "$said")" = 0
check "nothing is left" as_before
check "but the dialog, which it says" contains "$said" "$gone"
identity ARBOR_DIALOG_WAIT=soon
check "a wait that is no number, which would be no limit at all, is refused before anything is made" test "$code $(count "whole number of seconds" "$said")" = "64 1"
check "nothing is left" as_before

echo "  another keychain"
a_mac 26
identity -- --keychain "$other"
check "nobody there, and nothing is asked: it is made and tried" test "$code $(count "codesign can sign with it" "$said") $(count "" "$state/dialogs")" = "0 1 0"
check "ours is there, beside what was somebody's" ours_beside_theirs
a_mac 14
somebody --keychain "$other"
check "somebody there: the words allow for a dialog and do not promise one" \
  test "$code $(count "If macOS now asks for the keychain's password" "$said") $(count "will now ask" "$said") $(count "codesign can sign with it" "$said")" = "0 1 0 1"
# As a hosted Mac had it: it is where the file lies, not what it is called.
a_mac 26
echo "$beside" >> "$state/listed"
identity ARBOR_DIALOG_WAIT=1 -- --keychain "$beside"
check "one that lies beside the login keychain is asked about as that is: nobody there, and it says so and leaves nothing" \
  test "$code $(count "It had no answer in 1 seconds" "$said") $(count "" "$state/dialogs")" = "1 1 1"
check "nothing is left" as_before
a_mac 26
echo "$beside" >> "$state/listed"
echo always-allow > "$state/answer"
somebody --keychain "$beside"
check "somebody there, who answers Always Allow: the words had allowed for the dialog" \
  test "$code $(count "If macOS now asks for the keychain's password" "$said") $(count "codesign can sign with it" "$said") $(count "" "$state/dialogs")" = "0 1 1 1"
rm -f "$state/answer"
a_mac 26
identity -- --keychain "$other" --name "Somebody/Else"
check "a name that no file can have" test "$code $(count "codesign can sign with it" "$said") $(cut -d ' ' -f 2- "$state/came-in")" = "0 1 Somebody-Else"
a_mac 26
echo "$login" > "$state/listed"
identity -- --keychain "$other"
check "off the search list: it fails, and says that that is why" test "$code $(count "is not on the keychain search list" "$said")" = "1 1"
check "with codesign's own words" contains "$said" "no identity found"
check "it says that it took the certificate out again" contains "$said" "taken out of the keychain again"
check "and so it is" as_before
check "no dialog is spoken of: codesign came back by itself" lacks "$said" "still be on screen"
a_mac 15
echo "$login" > "$state/listed"
identity -- --keychain "$other"
check "macOS 14 and 15 say it otherwise, and the script the same" \
  test "$code $(count "is not on the keychain search list" "$said") $(count "could not be found in the keychain" "$said")" = "1 1 1"

echo "  a run that is cut short"
a_mac 26
"${mac[@]}" FAKE_MACOS=26 ARBOR_UNATTENDED=1 ARBOR_DIALOG_WAIT=2 "$root/scripts/make-signing-identity.sh" < /dev/null > "$said" 2>&1 &
run=$!
tries=0
while [ ! -s "$state/dialogs" ] && [ "$tries" -lt 100 ]; do sleep 0.1; tries=$((tries + 1)); done
kill -TERM "$run"
wait "$run"
check "ended from outside while it waits" test $? = 143
check "nothing is left" as_before
a_mac 26
echo "$login" > "$state/listed"
"${mac[@]}" FAKE_MACOS=26 ARBOR_UNATTENDED=1 "$root/scripts/make-signing-identity.sh" --keychain "$other" < /dev/null 2>&1 | head -n 1 > /dev/null
check "a reader of the output that leaves after a line: nothing is left" as_before
a_mac 26
for lines in 1 2 3 4; do
  "${mac[@]}" FAKE_MACOS=26 ARBOR_UNATTENDED=1 "$root/scripts/make-signing-identity.sh" --keychain "$other" --remove < /dev/null > /dev/null 2>&1
  "${mac[@]}" FAKE_MACOS=26 ARBOR_UNATTENDED=1 "$root/scripts/make-signing-identity.sh" --keychain "$other" < /dev/null 2>&1 | head -n "$lines" > /dev/null
  # Two lines come before the trial. A reader that leaves during those ends the run, and nothing is left; one that leaves later misses
  # only the good news, and must not cost the identity that works.
  if [ "$lines" -lt 2 ]; then
    check "of a run that would work, after $lines: all of it or nothing, never half" whole_or_nothing
  else
    check "after $lines, when the signature has been made: the identity stays" ours_beside_theirs
  fi
done
a_mac 26
touch "$state/half-an-import"
identity -- --keychain "$other"
check "an import that brings the certificate and no key: it fails" test "$code $(count "shows no identity" "$said")" = "1 1"
check "nothing is left" as_before
a_mac 26
echo deny > "$state/answer"
touch "$state/locked"
identity
check "what cannot be taken out again is not said to be gone" \
  test "$code $(count "could not be taken out of the keychain again: run this script with --remove" "$said") $(count "were taken out" "$said")" = "1 1 0"

echo "  run again"
a_mac 26
echo always-allow > "$state/answer"
somebody
identity
check "it changes nothing, having seen that codesign can still sign, and nobody is asked again" \
  test "$code $(count "Nothing to do" "$said") $(count "codesign can sign with it" "$said") $(count "" "$state/dialogs")" = "0 1 1 1"
check "ours is there, beside what was somebody's" ours_beside_theirs
: > "$state/allowed"
rm "$state/answer"
identity ARBOR_DIALOG_WAIT=1
check "an identity that is there and of no use, as an earlier version could leave one, is not called fine" \
  test "$code $(count "Nothing to do" "$said") $(count "it is there, but codesign cannot sign with it" "$said") $(count "It had no answer in 1 seconds" "$said")" = "1 0 1 1"
check "to remove it would not help, and is not advised" lacks "$said" "--remove"
check "the dialog that may be left asks about a key that is there" \
  test "$(count "A dialog of macOS's may still be on screen: close it with Deny." "$said") $(count "a key that is gone" "$said")" = "1 0"
check "it is left where it is: macOS's permissions may name it" ours_beside_theirs
echo "$other" > "$state/listed"
identity
check "nor where the keychain has gone from the search list" test "$code $(count "is not on the keychain search list" "$said") $(count "--remove" "$said")" = "1 1 0"
check "it is left where it is" ours_beside_theirs
printf '%s\n' "$login" "$other" > "$state/listed"
echo deny > "$state/answer"
somebody
check "where nothing else explains it, starting afresh is the advice, with what it costs" \
  test "$code $(count "with --remove, then once more; Arbor will need its permission again" "$said")" = "1 1"
check "it is left where it is" ours_beside_theirs
echo always-allow > "$state/answer"
somebody
check "and an answer at a terminal mends it, with nothing made anew" test "$code $(count "Nothing to do" "$said") $(cat "$state/made")" = "0 1 1"

echo "  --remove"
a_mac 26
identity -- --keychain "$other"
identity -- --keychain "$other" --remove
check "it takes ours out, and a certificate whose name only begins like ours stays, with its key" test "$code $(count "^Deleted the certificate" "$said")" = "0 1"
check "what was somebody's is as it was" as_before
identity -- --keychain "$other" --remove
check "again: there is nothing to remove" test "$code $(count "nothing to remove" "$said")" = "0 1"
check "what was somebody's is as it was" as_before
a_mac 26
echo "ABCDEF0123456789ABCDEF0123456789ABCDEF09 0xAB09 Arbor Local Signing" >> "$state/certificates"
identity -- --keychain "$other" --remove
check "a certificate of ours that was left without its key goes too" test "$code $(count "^Deleted the certificate" "$said")" = "0 1"
check "what was somebody's is as it was" as_before
a_mac 26
identity -- --keychain "$other"
touch "$state/locked"
identity -- --keychain "$other" --remove
check "what cannot be deleted is not said to be" test "$code $(count "could not be deleted" "$said") $(count "^Deleted" "$said")" = "1 1 0"

check "in all of this no password went anywhere, no keychain was read through, and no key's access was changed" \
  test "$(sort -u "$root/every-command" | tr '\n' ' ')" = "delete-certificate delete-identity find-certificate find-identity import list-keychains "

echo "publish-release.sh, against a stand-in for GitHub"
# The Swift image for Linux has none. macOS and the machine that publishes do.
if ! command -v curl >/dev/null; then
  echo "  (not tried against a stand-in for GitHub: there is no curl here)"
  finish
fi

# A stand-in for GitHub: answers the four calls the script makes and writes down what it was sent.
cat > "$root/github.py" <<'PYTHON'
import http.server, json, os, socketserver, sys

root = sys.argv[1]

class Handler(http.server.BaseHTTPRequestHandler):
    def answer(self, status, body=None):
        data = json.dumps(body).encode() if body is not None else b""
        self.send_response(status)
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def handle_any(self):
        body = self.rfile.read(int(self.headers.get("Content-Length") or 0))
        with open(os.path.join(root, "requests.log"), "a", encoding="utf-8") as log:
            log.write(f"{self.command} {self.path} auth={self.headers.get('Authorization')} "
                      f"type={self.headers.get('Content-Type')} body={body.decode()[:4000]!r}\n")
        base = f"http://127.0.0.1:{self.server.server_address[1]}"
        if self.command == "GET" and self.path == "/repos/o/r/releases?per_page=100":
            with open(os.path.join(root, "existing.json"), encoding="utf-8") as existing:
                return self.answer(200, json.load(existing))
        if self.command == "DELETE" and self.path.startswith("/repos/o/r/releases/"):
            return self.answer(204)
        if self.command == "POST" and self.path == "/repos/o/r/releases":
            return self.answer(201, {"id": 77, "html_url": "https://example.invalid/releases/77",
                                     "upload_url": base + "/uploads/77/assets{?name,label}"})
        if self.command == "POST" and self.path.startswith("/uploads/77/assets?name="):
            return self.answer(201, {})
        self.answer(422, {"message": "the stand-in does not know this call"})

    do_GET = do_POST = do_DELETE = handle_any

    def log_message(self, *arguments):
        pass

class Server(http.server.HTTPServer):
    # As HTTPServer binds, but for asking the system what this machine is called (socket.getfqdn), which nothing here needs. macOS can take
    # that question for one about the local network: alone, on a hosted Mac, it took 35 s and left "Allow Python to find devices on local networks?" in
    # the middle of the screen, where the real pointer of whatever ran next on that Mac pressed it and not the window under it.
    def server_bind(self):
        socketserver.TCPServer.server_bind(self)
        self.server_name, self.server_port = self.server_address[:2]

server = Server(("127.0.0.1", 0), Handler)
with open(os.path.join(root, "port"), "w", encoding="utf-8") as port:
    port.write(str(server.server_address[1]))
server.serve_forever()
PYTHON
python3 "$root/github.py" "$root" &
server=$!
tries=0
# A hosted Mac once took more than five seconds to get here. Most likely that was the question Server no longer asks; the patience does no harm.
while [ ! -s "$root/port" ] && [ "$tries" -lt 600 ]; do sleep 0.1; tries=$((tries + 1)); done
port=$(cat "$root/port")
export GITHUB_API_URL="http://127.0.0.1:$port" GITHUB_REPOSITORY=o/r GITHUB_TOKEN=s3cret NO_PROXY=127.0.0.1
log="$root/requests.log"

echo '[{"id": 5, "tag_name": "v1.2.2", "draft": false}, {"id": 6, "tag_name": "v1.2.3", "draft": true}]' > "$root/existing.json"
# First, while the log is still empty: what the Release workflow's rehearsal runs, here with all it would take to send.
"$root/scripts/publish-release.sh" --dry-run > /dev/null 2>&1
check "a dry run with a token at hand and GitHub listening succeeds" test $? -eq 0
check "and asks GitHub nothing and sends it nothing" test ! -s "$log"
"$root/scripts/publish-release.sh" > "$root/publish.txt" 2>&1
check "it succeeds" test $? -eq 0
check "(and that reached the same log)" test -s "$log"
check "an earlier draft for the version is replaced" contains "$log" "DELETE /repos/o/r/releases/6 "
check "other releases are left alone" lacks "$log" "DELETE /repos/o/r/releases/5 "
check "the release is a draft on the commit, named after the version" contains "$log" \
  '"tag_name": "v1.2.3", "target_commitish": "0123456789abcdef0123456789abcdef01234567", "name": "Arbor 1.2.3"'
check "not a pre-release" contains "$log" '"draft": true, "prerelease": false'
check "the notes are its body" contains "$log" "Drop a window on the middle of another"
check "the disk image is uploaded as it is" contains "$log" \
  "POST /uploads/77/assets?name=Arbor-1.2.3.dmg auth=Bearer s3cret type=application/octet-stream body='disk image'"
check "so is the archive" contains "$log" "assets?name=Arbor-1.2.3.zip auth=Bearer s3cret type=application/octet-stream body='archive'"
check "so are the checksums" contains "$log" "assets?name=Arbor-1.2.3-checksums.txt "
check "so is the cask" contains "$log" "assets?name=arbor.rb "
check "every call carries the token" lacks "$log" "auth=None"
check "the token is not printed" lacks "$root/publish.txt" s3cret
check "it says where the draft is" contains "$root/publish.txt" "Created the draft release Arbor 1.2.3: https://example.invalid/releases/77"

: > "$log"
echo '[{"id": 6, "tag_name": "v1.2.3", "draft": false}]' > "$root/existing.json"
check "a published release is never replaced" fails "$root/scripts/publish-release.sh"
check "nor is anything sent after finding one" lacks "$log" "POST"

: > "$log"
echo '[]' > "$root/existing.json"
for name in dmg zip; do cp "$root/build/Arbor-1.2.3.$name" "$root/build/Arbor-1.2.4-rc.1.$name"; done
cp "$root/build/Arbor-1.2.3-notes.md" "$root/build/Arbor-1.2.4-rc.1-notes.md"
cp "$root/build/Arbor-1.2.3-checksums.txt" "$root/build/Arbor-1.2.4-rc.1-checksums.txt"
check "a release candidate can be published at once" env ARBOR_VERSION=1.2.4-rc.1 ARBOR_DRAFT=false "$root/scripts/publish-release.sh"
check "as a pre-release" contains "$log" '"draft": false, "prerelease": true'

: > "$log"
check "GitHub's refusal fails the script" fails env GITHUB_REPOSITORY=o/other "$root/scripts/publish-release.sh"

finish
