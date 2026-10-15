#!/bin/bash
# Proves F13 (distribution) on a real Mac: the part that changes nothing outside a folder in /tmp.
# About ten minutes, most of it compiling. check-F13-system.sh has the rest, for GitHub's throwaway Macs.
#
#   mkdir -p mac-shell && bash scripts/mac-shell/check-F13.sh 2>&1 | tee mac-shell/output.txt   # on the Mac in front of you
#   scripts/mac-shell/run.sh scripts/mac-shell/check-F13.sh                                     # on one of GitHub's
#
#   1  without an identity, `make app` signs ad hoc as before, and stamps the version
#   2  scripts/make-signing-identity.sh makes the identity without a dialog, and running it again changes nothing
#   3  `make install` installs and links arborctl; the version shows everywhere
#   4  a different build signed with the identity has another hash and the very same designated requirement;
#      installing it quits the running copy first, in good order: its watchdog does not start it again
#   5  `make uninstall`
#   6  update checks against GitHub (404 while no release is published) and against a stand-in with a newer release
#   7  an identity that is neither ad hoc nor the local one gets the hardened runtime, and Arbor runs under it
#   8  `make release`: universal binaries, zip, disk image, checksums, cask, notes; what Gatekeeper says to a download
#   9  what the scripts rely on in `security` and `openssl`
#   10 --remove, and back to ad hoc
#
# SAFE ON A PERSON'S MAC. No sudo. It works in a place apart (lib-F13.sh): a throwaway HOME, ARBOR_HOME and keychain in
# /tmp, and a clone of this checkout to build in. It does not touch the account's keychains, their search list or the
# default keychain (its keychain is on the throwaway HOME's search list only, it compares the account's settings before and after,
# and stops at once if `security` turns out not to follow HOME), nor ~/Applications, the PATH, Arbor's folder in Application Support, the
# permission database, the login items, what Launch Services knows (nothing is started with `open`), or a file of this
# checkout. The copies of Arbor it starts arrange nobody's windows and ask for nothing, so an Arbor that is already
# running is neither quit nor disturbed. Pictures are of Arbor's own window only, and only where this shell may
# already record the screen. Whatever could put a dialog of macOS's on the screen is tried first with a time limit of
# seconds, and the script ends there if it does. What a person may notice: a small window, twice, for a few
# seconds in step 6.
# One exception, in steps 3 to 5 only: those copies run with their watchdog, because that `make install` and the watchdog
# get along is what a daily rebuild depends on. Should such a copy crash, the watchdog starts it again through `open`, with
# the same switches (nobody's windows, no questions, this run's ARBOR_HOME); the script's end stops it like the rest.
# It needs the network once, for step 6, and about 2 GB in /tmp while it runs.
source "$(dirname "$0")/lib-F13.sh"

f13_describe_the_mac
other_openssl=""
for candidate in /opt/homebrew/opt/openssl@3/bin/openssl /usr/local/opt/openssl@3/bin/openssl; do
  if [ -x "$candidate" ]; then other_openssl=$candidate; fi
done
echo "another openssl: ${other_openssl:-none} $([ -z "$other_openssl" ] || "$other_openssl" version)"
mkdir -p "$(dirname "$ARBOR_POINTER")"
limit 300 swiftc -O -swift-version 5 "$ARBOR_ROOT/scripts/mac-shell/pointer.swift" -o "$ARBOR_POINTER" > "$ARBOR_OUT/build-pointer.log" 2>&1 &
pointer_build=$!
f13_clone
f13_make_keychain
export ARBOR_SIGN_KEYCHAIN=$keychain

step "1  no identity: ad hoc, as before"
make_app "$ARBOR_OUT/build.log"
adhoc_requirement=$(requirement "$app")
echo "  designated => $adhoc_requirement"
signature "$app"
(cd "$app/.." && find Arbor.app -type f | sort | sed 's/^/    /')
check "make app says the signature is ad hoc" says "$ARBOR_OUT/build.log" "Signed build/Arbor.app ad hoc"
check "an ad-hoc build's requirement is its own hash" with "$adhoc_requirement" "cdhash H\""
check "codesign --verify --deep --strict passes" codesign --verify --deep --strict "$app"
check "arborctl has an identifier of its own" with "$(codesign --display --verbose=3 "$app/$tool" 2>&1)" "Identifier=$bundle_id.arborctl"
echo "  Info.plist: $(stamp CFBundleShortVersionString "$app") / $(stamp CFBundleVersion "$app") / $(stamp ArborCommit "$app")"
check "the version is stamped" same "$(stamp CFBundleShortVersionString "$app")" "$(cat VERSION)"
check "the build number is stamped" same "$(stamp CFBundleVersion "$app")" "$(git rev-list --count HEAD)"
check "the commit is stamped" same "$(stamp ArborCommit "$app")" "$(git rev-parse --short HEAD)"
check "so is the kind of signature, and codesign agrees" same "$(stamp ArborSignature "$app") $(codesign --display --verbose=2 "$app" 2>&1 | grep '^Signature=')" "adhoc Signature=adhoc"
install_here > "$ARBOR_OUT/install-adhoc.txt" 2>&1
tail -n 6 "$ARBOR_OUT/install-adhoc.txt"
check "make install says aloud that the build is signed ad hoc" says "$ARBOR_OUT/install-adhoc.txt" "NOTE: THIS BUILD IS SIGNED AD HOC"
check "and what that costs" says "$ARBOR_OUT/install-adhoc.txt" "macOS will ask for the Accessibility permission again"
start_copy "$installed"
# With a ✘ among its rows `doctor` fails, and arborctl writes the answer of a command that failed to the other output. A Mac as it comes has
# such a row: macOS's own tiling is on.
check "doctor names it" with "$(ask doctor 2>&1)" "– Signature: ad hoc, so to macOS every build is a new app"
stop_copy
check "the property list is still valid" plutil -lint "$app/Contents/Info.plist"

step "2  the signing identity"
limit 120 ./scripts/make-signing-identity.sh --keychain "$keychain" < /dev/null 2>&1 | tee "$ARBOR_OUT/identity.txt"
security find-identity -p codesigning "$keychain"
echo "the key's attributes in the keychain:"
security dump-keychain "$keychain" 2>/dev/null | grep -E '^class|0x00000001|"labl"' | head -n 12
check "the identity is in the keychain" with "$(security find-identity -p codesigning "$keychain")" "\"$identity\""
check "nobody trusts the certificate, and nothing was asked to" \
  without "$(security find-identity -v -p codesigning "$keychain")" "\"$identity\""
# Every build from here on signs with the key. A keychain made with `security create-keychain` gives its keys no partition list, so macOS asks
# nobody (check-signing.sh). Should it ask all the same, the script has given up after a minute, has taken the identity out again and has said
# that the dialog stays until it is closed; this run ends here: better than to learn it from a `make install`.
check "codesign could use the key at once, without a dialog" says "$ARBOR_OUT/identity.txt" "codesign can sign with it" \
  || die "codesign cannot use the key without a dialog; the rest would put dialogs on this Mac's screen"
cp /usr/bin/true "$sandbox/signed-first"
check "codesign signs with the key, and asks nobody" \
  limit 20 codesign --force --sign "$identity" --keychain "$keychain" --timestamp=none "$sandbox/signed-first" \
  || die "codesign cannot use the key without a dialog; the rest would put dialogs on this Mac's screen"
first_hash=$(security find-identity -p codesigning "$keychain" | sed -n 's/^ *1) \([0-9A-F]*\) .*/\1/p' | head -n 1)
limit 60 ./scripts/make-signing-identity.sh --keychain "$keychain" < /dev/null 2>&1 | tee "$ARBOR_OUT/identity-again.txt"
check "running it again changes nothing" says "$ARBOR_OUT/identity-again.txt" "Nothing to do"
check "there is still one identity, the same one" same "$first_hash" \
  "$(security find-identity -p codesigning "$keychain" | sed -n 's/^ *[0-9]*) \([0-9A-F]*\) .*/\1/p' | sort -u)"

step "3  installing"
install_here 2>&1 | tee "$ARBOR_OUT/install.txt" | grep -vE "^\[|Compiling|Building|Build complete"
first_requirement=$(requirement "$installed")
first_cdhash=$(cdhash "$installed")
echo "  designated => $first_requirement"
signature "$installed"
ls -la "$home/Applications" "$home/.local/bin"
check "it says which signature it made and what that means" says "$ARBOR_OUT/install.txt" "with \"$identity\", this Mac's own certificate"
check "and has nothing to warn of" without "$(cat "$ARBOR_OUT/install.txt")" "AD HOC"
check "the bundle says so itself" same "$(stamp ArborSignature "$installed")" local
check "the app is in ~/Applications" test -x "$installed/Contents/MacOS/Arbor"
check "the installed copy verifies (--deep --strict)" codesign --verify --deep --strict "$installed"
check "arborctl is linked into ~/.local/bin" same "$(readlink "$home/.local/bin/arborctl")" "$installed/$tool"
check "LAUNCH=0 leaves it at that" gone "$installed"
check "to this shell, as to a person's, arborctl is that link" same "$(command -v arborctl)" "$home/.local/bin/arborctl"
start_copy "$installed" ARBOR_NO_WATCHDOG=0
check "the installed app starts and answers" within 10 arborctl status
check_watchdog "$ARBOR_HOME/arbor.log" "$installed" "$copy_pid"
check "what runs from ~/Applications is the copy that was started" same "$(app_pid "$installed")" "$copy_pid"
echo "  arborctl --version:  $(arborctl --version | tr '\n' '|')"
echo "  arborctl version:    $(arborctl version | tr '\n' '|')"
echo "  arborctl status:     $(arborctl status | tr '\n' '|')"
echo "  Arbor --version:     $("$installed/Contents/MacOS/Arbor" --version)"
check "arborctl --version, through the link, knows its version, and has nothing to add" same "$(arborctl --version)" "arborctl $expected"
check "the running app reports the same" same "$(arborctl version | head -n 1)" "Arbor $expected"
check "status shows it, on a line of its own" same "$(arborctl status | tail -n 1)" "Arbor $expected"
check "so does the binary itself, beside the running copy" same "$("$installed/Contents/MacOS/Arbor" --version)" "Arbor $expected"
check "doctor names the signature" with "$(arborctl doctor 2>&1)" "✔ Signature: this Mac’s own certificate"
echo "  launch at login, only asked about: $(arborctl launch-at-login)"

step "4  a different build, the same requirement"
change_the_source
make_app "$ARBOR_OUT/build-second.log"
second_requirement=$(requirement "$app")
second_cdhash=$(cdhash "$app")
echo "  designated => $second_requirement"
signature "$app"
{
  echo "ad hoc:        $adhoc_requirement"
  echo "first build:   $first_requirement   (cdhash $first_cdhash)"
  echo "second build:  $second_requirement   (cdhash $second_cdhash)"
} > "$ARBOR_OUT/requirements.txt"
check "the second build verifies (--deep --strict)" codesign --verify --deep --strict "$app"
check "the two builds are different code" differ "$first_cdhash" "$second_cdhash"
check "their designated requirements are identical" same "$first_requirement" "$second_requirement"
check "the requirement contains no cdhash" without "$first_requirement" cdhash
check "it names the app and the certificate" with "$first_requirement" "identifier \"$bundle_id\" and certificate"
check "the second build satisfies the first one's requirement" codesign --verify -R="$first_requirement" "$app"
check "arborctl does not: it cannot pass for the app" sh -c "! codesign --verify -R='$first_requirement' '$app/$tool'"
check "uncommitted changes show in the stamp" with "$(stamp ArborCommit "$app")" "-dirty"
echo "  the new arborctl, while the old build runs: $("$app/$tool" --version | tr '\n' '|')"
check "arborctl --version says when the running Arbor is another build" with "$("$app/$tool" --version)" "another build, Arbor $expected"
install_here 2>&1 | tee "$ARBOR_OUT/install-over.txt" | grep -E "error|^Asked|^Arbor is still|^Installed|^Linked|^Not started"
restore_the_source
check "installing asked the running copy to quit" says "$ARBOR_OUT/install-over.txt" "Asked the running Arbor to quit"
check "and did not have to stop it" without "$(cat "$ARBOR_OUT/install-over.txt")" "still running"
check "the copy has gone" copy_has_gone
copy_pid=""  # `check` asks in a shell of its own, and a number that is kept may be somebody else's process by the time the script ends
# The watchdog starts Arbor again 0.3 s after an end it takes for an accident.
sleep 2
check "nothing of the old copy is left running, and its watchdog started nothing" gone "$installed"
check "the watchdog took it for a proper end" without "$(cat "$ARBOR_HOME/arbor.log")" "ended without quitting"
check "what is installed is the second build" same "$(cdhash "$installed")" "$second_cdhash"
start_copy "$installed" ARBOR_NO_WATCHDOG=0
check "the new build starts where the old one was" within 10 arborctl status
echo "  $(arborctl version | head -n 1)"

step "5  uninstalling"
uninstall_here 2>&1 | tee "$ARBOR_OUT/uninstall.txt"
check "it asked Arbor to quit" says "$ARBOR_OUT/uninstall.txt" "Asked the running Arbor to quit"
check "the copy has gone" copy_has_gone
copy_pid=""  # `check` asks in a shell of its own, and a number that is kept may be somebody else's process by the time the script ends
check "it removed the app" test ! -e "$installed"
check "and the link" test ! -L "$home/.local/bin/arborctl"
sleep 2
check "nothing of it is left running, and its watchdog started nothing" gone "$installed"
check "the watchdog took it for a proper end" without "$(cat "$ARBOR_HOME/arbor.log")" "ended without quitting"
check "it says where settings and state are" says "$ARBOR_OUT/uninstall.txt" "Library/Application Support/Arbor"
check "settings are still there" test -f "$ARBOR_HOME/settings.json"

step "6  update checks"
wait "$pointer_build" || cat "$ARBOR_OUT/build-pointer.log"
mkdir -p "$sandbox/feed"
echo '{"tag_name": "v9.9.9", "html_url": "https://example.invalid/ignored"}' > "$sandbox/feed/latest.json"
(cd "$sandbox/feed" && exec python3 "$ARBOR_ROOT/scripts/mac-shell/serve.py" 8765 > /dev/null 2>&1) &
feed_pid=$!
updates_say() { case "$(ask version | tail -n 1)" in "Updates: $1"*) return 0 ;; *) return 1 ;; esac; }

make_app "$ARBOR_OUT/build-third.log" | tail -n 1
start_copy "$app"
echo "  $(ask status | tr '\n' '|')"
echo "  before: $(ask version | tail -n 1)"
echo "  $(ask check-for-updates)"
# 404 while no release is published; GitHub may also turn a shared address away with 403, which reads the same to the user.
check "what GitHub answers while no release is published is no update information, not an error" within 20 updates_say "no update information"
echo "  after:  $(ask version | tail -n 1)"
window_shot 06-no-update-information
stop_copy

# Plain http to this machine: whether App Transport Security lets an address or a name through is to be seen. The last
# try is a copy of the app that is told to allow it, so that the window is seen in this run either way.
for address in http://127.0.0.1:8765/latest.json http://localhost:8765/latest.json "http://127.0.0.1:8765/latest.json allowed"; do
  if [ "${address#* }" = allowed ]; then
    address=${address% *}
    echo "  in this copy only: NSAllowsLocalNetworking"
    plutil -insert NSAppTransportSecurity -json '{"NSAllowsLocalNetworking": true}' "$app/Contents/Info.plist"
    limit 60 ./scripts/sign.sh "$app" | head -n 1
  fi
  start_copy "$app" ARBOR_RELEASES_URL="$address"
  echo "  asking $address: $(ask check-for-updates)"
  within 10 updates_say "Arbor 9.9.9" && break
  echo "  $(ask version | tail -n 1)"
  stop_copy
done
check "a newer release is offered, with a page made from its tag" \
  updates_say "Arbor 9.9.9 is available: https://github.com/evbarleyg/arbor/releases/tag/v9.9.9"
echo "  $(ask version | tail -n 1)"
window_shot 06-update-available
echo "Arbor's own windows (id pid level x y w h on owner):"
[ -z "$copy_pid" ] || pointer windows --pid "$copy_pid"
grep -E "update check|starting" "$ARBOR_HOME/arbor.log" | cut -c 26-
stop_copy
kill "$feed_pid" 2>/dev/null
feed_pid=""

step "7  another identity: the hardened runtime"
limit 120 ./scripts/make-signing-identity.sh --keychain "$keychain" --name "F13 Stand-in" < /dev/null 2>&1 | tail -n 4
make_app "$ARBOR_OUT/build-hardened.log" ARBOR_SIGN_IDENTITY="F13 Stand-in"
signature "$app"
check "the hardened runtime is on" with "$(codesign --display --verbose=3 "$app" 2>&1 | grep '^CodeDirectory')" "runtime"
check "for arborctl too" with "$(codesign --display --verbose=3 "$app/$tool" 2>&1 | grep '^CodeDirectory')" "runtime"
check "it verifies (--deep --strict)" codesign --verify --deep --strict "$app"
check "the bundle says that a certificate signed it" same "$(stamp ArborSignature "$app")" issued
start_copy "$app"
echo "  $(ask status | tr '\n' '|')"
# "running" where this shell has Accessibility to pass on, "waiting" where it has not.
check "Arbor starts and answers under the hardened runtime" ask status
stop_copy
limit 60 ./scripts/make-signing-identity.sh --keychain "$keychain" --name "F13 Stand-in" --remove | head -n 1

step "8  make release"
if ARBOR_SIGN_IDENTITY=- limit 1500 make release > "$ARBOR_OUT/release.log" 2>&1; then
  grep -vE "^\[|Compiling|Building for|^Build |note:|^ *$" "$ARBOR_OUT/release.log" | tail -n 40
else
  tail -n 60 "$ARBOR_OUT/release.log"
fi
version=$(cat VERSION)
check "both architectures were built in one go" without "$(cat "$ARBOR_OUT/release.log")" "building each by itself"
echo "  Arbor:    $(lipo -archs "$app/Contents/MacOS/Arbor"), $(stat -f %z "$app/Contents/MacOS/Arbor") bytes"
echo "  arborctl: $(lipo -archs "$app/$tool"), $(stat -f %z "$app/$tool") bytes"
check "Arbor is universal" same "$(lipo -archs "$app/Contents/MacOS/Arbor" | tr ' ' '\n' | sort | tr '\n' ' ')" "arm64 x86_64 "
check "arborctl is universal" same "$(lipo -archs "$app/$tool" | tr ' ' '\n' | sort | tr '\n' ' ')" "arm64 x86_64 "
check "the universal app verifies (--deep --strict)" codesign --verify --deep --strict "$app"
check "the checksums hold" sh -c "cd build && shasum -a 256 -c Arbor-$version-checksums.txt"
check "the cask is Ruby, with the version and the disk image's sum" sh -c \
  "ruby -c build/arbor.rb && grep -q 'version \"$version\"' build/arbor.rb && grep -q \"\$(shasum -a 256 build/Arbor-$version.dmg | cut -d ' ' -f 1)\" build/arbor.rb"
check "the notes explain the first launch" says "build/Arbor-$version-notes.md" "Open Anyway"
echo "  x86_64 under Rosetta: $(arch -x86_64 "$app/$tool" --version 2>&1 | head -n 1)"
mkdir -p "$sandbox/mount" "$sandbox/unzipped"
if hdiutil attach -quiet -nobrowse -readonly -mountpoint "$sandbox/mount" "build/Arbor-$version.dmg"; then
  ls -la "$sandbox/mount" | sed 's/^/    /'
  check "the disk image holds the app, intact" codesign --verify --deep --strict "$sandbox/mount/Arbor.app"
  check "and a link to /Applications" same "$(readlink "$sandbox/mount/Applications")" /Applications
  hdiutil detach -quiet "$sandbox/mount"
else
  check "the disk image mounts" false
fi
ditto -x -k "build/Arbor-$version.zip" "$sandbox/unzipped"
download="$sandbox/unzipped/Arbor.app"
check "the zip holds the app, intact" codesign --verify --deep --strict "$download"
cp "build/Arbor-$version-notes.md" "build/Arbor-$version-checksums.txt" build/arbor.rb "$ARBOR_OUT/"
GITHUB_SHA=$(git rev-parse HEAD) ./scripts/publish-release.sh --dry-run
echo "what Gatekeeper makes of a downloaded copy (only asked; check-F13-system.sh tries to open one):"
xattr -w com.apple.quarantine "0083;$(printf '%x' "$(date +%s)");Safari;$(uuidgen)" "$download"
echo "    $(spctl --status 2>&1)"
spctl --assess --type execute --verbose=4 "$download" 2>&1 | sed 's/^/    /'
xattr -dr com.apple.quarantine "$download"
check "xattr -dr takes the mark off" test -z "$(xattr -lr "$download" | grep quarantine)"
start_copy "$download"
check "and the copy from the zip starts" ask status
stop_copy

step "9  what the scripts rely on"
probe="$sandbox/probe.keychain-db"
new_keychain "$probe"
search_list "$keychain" "$probe"
if [ -n "$other_openssl" ]; then
  # Into a file: a reader that leaves after three lines would end the script.
  ARBOR_OPENSSL=$other_openssl limit 60 ./scripts/make-signing-identity.sh --keychain "$probe" < /dev/null > "$ARBOR_OUT/identity-openssl.txt" 2>&1
  head -n 3 "$ARBOR_OUT/identity-openssl.txt"
  check "a PKCS#12 file packed by $("$other_openssl" version | cut -d ' ' -f 1-2) with -legacy imports, and codesign signs with the key" \
    says "$ARBOR_OUT/identity-openssl.txt" "codesign can sign with it"
fi
echo "is a keychain that was made here on the throwaway HOME's search list? $(security list-keychains -d user | tr -d '\n')"
drop_keychain "$probe"

step "10  --remove"
limit 60 ./scripts/make-signing-identity.sh --keychain "$keychain" --remove
check "the identity is gone" without "$(security find-identity -p codesigning "$keychain")" "\"$identity\""
check "the certificate too" sh -c "! security find-certificate -c '$identity' '$keychain'"
limit 60 ./scripts/make-signing-identity.sh --keychain "$keychain" --remove
make_app "$ARBOR_OUT/build-last.log" | tail -n 3
check "builds are ad hoc again" with "$(requirement "$app")" "cdhash H\""
check "and say so themselves" same "$(stamp ArborSignature "$app")" adhoc
drop_keychain "$keychain"
check "the account's own search list and default keychain are still as they were" unchanged "$real_settings" "$(real_keychain_settings)"
check "this checkout is as it was" unchanged "$checkout_before" "$(git -C "$ARBOR_ROOT" status --porcelain)"

ls -l "$ARBOR_OUT" | awk '{ print $5, $9 }'
