#!/bin/bash
# What a person gets who downloads Arbor instead of building it: from the files of a release to two windows docked side by side, on a Mac
# that did not build them.
#
#   scripts/mac-shell/check-download.sh        the files are in build/, as `make release` leaves them, or in $ARBOR_DOWNLOAD
#
# The Release workflow runs it on a fresh Mac, between the build and the releases page: what does not start there goes nowhere. No
# toolchain is needed and nothing of Arbor is compiled, so it takes three minutes.
#
#   1  the files: the checksums hold, the cask names the disk image's
#   2  the zip, marked as a browser marks a download and unpacked: the signature holds, both programs for both kinds of Mac from macOS 14 on, nothing
#      but the system's libraries, both halves say their version
#   3  opened as it is: macOS refuses it, in the words docs/INSTALL.md and the release notes quote
#   4  the way past that in System Settings, as far as a script can follow it: to the dialog that wants an administrator's password (told,
#      not judged: they are macOS's windows, not Arbor's)
#   5  the way past it in Terminal, as docs/INSTALL.md has it: Arbor starts, says its version, shows its welcome window and waits for permission
#   6  with the permission: the process that waited runs, docks two windows side by side, and gives them back at their own sizes when it quits
#   7  the disk image holds the same app, its signature whole, and the link to drag it onto
# A build that Apple has notarized is not refused: then 3 says so, 4 is left out, and the notes have no detour to tell (ARBOR_NOTARIZED).
ARBOR_TIME_LIMIT=${ARBOR_TIME_LIMIT:-540}
source "$(dirname "$0")/lib.sh"
needs_throwaway_mac "mark files as downloaded and open them, write to the permission database with sudo, start an Arbor from a download that \
arranges every window on the account's own settings, click in System Settings and in macOS's own dialogs, restart the service that keeps the permissions, and quit TextEdit"
[ -z "${ARBOR_REHEARSAL:-}" ] || { echo "a rehearsal has no Gatekeeper, no code signatures and no disk images: only a real Mac can judge this"; exit 77; }

files=${ARBOR_DOWNLOAD:-$ARBOR_ROOT/build}
bundle_id=com.evbarleyg.arbor
AXFIND="$ARBOR_ROOT/.build/mac-shell/axfind"
ANNOUNCE="$ARBOR_ROOT/.build/mac-shell/announce"
tcc="/Library/Application Support/com.apple.TCC/TCC.db"
# The Arbor under test is started by macOS, as a person's is, and lives in the account's own home, whatever lib.sh has set up for a session.
unset ARBOR_HOME ARBOR_ONLY_PIDS
export ARBOR_SOCKET="$HOME/Library/Application Support/Arbor/arbor.sock"
scratch_dir download work real

with() { case "$1" in *"$2"*) return 0 ;; *) return 1 ;; esac; }
same() { [ -n "$1" ] && [ "$1" = "$2" ]; }
not() { ! "$@"; }
within() { local deadline=$((SECONDS + $1)); shift; until "$@"; do [ "$SECONDS" -lt "$deadline" ] || return 1; sleep 0.3; done; }
mark() { xattr -w com.apple.quarantine "0083;$(printf '%x' "$(date +%s)");Safari;$(uuidgen)" "$1"; }
mark_of() { xattr -p com.apple.quarantine "$1" 2>/dev/null; }
cdhash() { codesign --display --verbose=3 "$1" 2>&1 | sed -n 's/^CDHash=//p'; }
ask() { limit 5 "$app/Contents/Helpers/arborctl" "$@" 2>&1; }
status_starts() { case "$(ask status)" in "$1"*) return 0 ;; *) return 1 ;; esac; }
# A process is listed from the moment macOS looks the app over, long before it may run: only an answer says that Arbor runs.
answers() { ask status | grep -qvE "is not running"; }
# Whose window is on screen under that name, as the window server has it. Not pgrep -x: it goes by a name cut off after 16 characters.
pid_named() {
  "$ARBOR_POINTER" windows --on-screen | awk -v name="$1" '{ pid = $2; $1 = $2 = $3 = $4 = $5 = $6 = $7 = $8 = ""; sub(/^ +/, ""); if ($0 == name) { print pid; exit } }'
}
# Everybody with a window on screen, one name a line.
on_screen() { "$ARBOR_POINTER" windows --on-screen | awk '{ $1 = $2 = $3 = $4 = $5 = $6 = $7 = $8 = ""; sub(/^ +/, ""); print }' | sort -u; }
# Who has come on screen since `before` was taken: macOS's dialog that asks for a password belongs to a process of its own.
newcomer() { on_screen | grep -vxF -e "$before" | head -n 1; }
has_come() { [ -n "$(newcomer)" ]; }
# shows <process> <role> <text>, point_of likewise: through Accessibility, as assistive software reads a window
shows() { local pid; pid=$(pid_named "$1"); [ -n "$pid" ] && limit 5 "$AXFIND" "$pid" point "$2" "$3" > /dev/null 2>&1; }
press() {
  local pid point
  pid=$(pid_named "$1"); [ -n "$pid" ] || { echo "  no $1 is running"; return 1; }
  point=$(limit 5 "$AXFIND" "$pid" point "$2" "$3" 2>/dev/null) || { echo "  $1 shows no $2 “$3”"; return 1; }
  # shellcheck disable=SC2086
  click $point
}
# value_of <process> <text>: the whole of the text that holds those words.
value_of() { local pid; pid=$(pid_named "$1"); [ -n "$pid" ] && limit 5 "$AXFIND" "$pid" value AXStaticText "$2" 2>/dev/null; }
# page_has <file> <words>, wherever the file breaks its lines.
page_has() { [ -n "$2" ] && tr '\n' ' ' < "$1" | tr -s ' ' | grep -qF -- "$2"; }
# For what is told and not judged.
quoted() {
  if page_has "$ARBOR_ROOT/docs/INSTALL.md" "$1"; then echo "    (docs/INSTALL.md has these words)"; else echo "    DOCS/INSTALL.MD DOES NOT HAVE THESE WORDS: $1"; fi
}
# What a window says, without the furniture.
told() {
  local pid; pid=$(pid_named "$1"); [ -n "$pid" ] || return 0
  limit 5 "$AXFIND" "$pid" tree 2>/dev/null | grep -E "AXStaticText|AXButton|AXTextField|AXCheckBox" | grep -vE '"" "" ' | sed -E 's/^ +//; s/ -?[0-9]+ -?[0-9]+ [0-9]+ [0-9]+$//' \
    | cut -c 1-200 | head -n "${2:-12}" | sed 's/^/    /'
}
# open_it <name>: as a double click does. In the background, into a file: `open` waits as long as macOS's dialog stands.
open_it() {
  limit 30 open "$app" > "$ARBOR_OUT/open-$1.txt" 2>&1 &
  started $!
}
put_away_dialogs() {
  local tries=0 name
  while [ "$tries" -lt 4 ]; do
    for name in Done Cancel OK ""; do shows CoreServicesUIAgent AXButton "${name:-no such button}" && break; done
    [ -n "$name" ] || return 0
    press CoreServicesUIAgent AXButton "$name"
    sleep 1
    tries=$((tries + 1))
  done
}
# Whatever of macOS's stands between a script and the next launch: Gatekeeper's dialogs, and the one that wants a password, which comes late.
# While any of them stands, `open` fails with -10673.
clear_the_way() {
  local tries=0
  put_away_dialogs
  while [ "$tries" -lt 5 ] && on_screen | grep -qxE "coreautha|SecurityAgent"; do key escape; sleep 1; tries=$((tries + 1)); done
}
# launch <name>: open it until it answers, three times at most, with the way cleared in between.
launch() {
  local try
  for try in 1 2 3; do
    open_it "$1-$try"
    # A notarized download is asked about once: "… is an app downloaded from the Internet. Are you sure you want to open it?" (Never tried.)
    [ -n "$notarized" ] && within 8 shows CoreServicesUIAgent AXButton Open && press CoreServicesUIAgent AXButton Open
    within 15 answers && return 0
    clear_the_way
    sleep 2
  done
  return 1
}
# The process itself: its watchdog runs the same program, with an argument.
process() { pgrep -f "^$program\$" | head -n 1; }
minos() { otool -arch "$1" -l "$2" | awk '/LC_BUILD_VERSION/ { found = 1 } found && /minos/ { print $2; exit }'; }
# TextEdit's windows, as the window server has them.
texts() { "$ARBOR_POINTER" windows --on-screen | awk '$3 == 0 && $9 == "TextEdit" && NF == 9 { print $1 }' | sort -n; }
sizes() { local id; for id in $(texts); do "$ARBOR_POINTER" frame "$id" | cut -d ' ' -f 3-4; done | tr '\n' ','; }
all_in_view() { local id; for id in $(texts); do [ "$("$ARBOR_POINTER" visible "$id")" = 1.00 ] || return 1; done; [ "$(texts | wc -l)" -ge 2 ]; }
clean_up() {
  [ -n "${app:-}" ] && [ -x "$app/Contents/Helpers/arborctl" ] && ask quit > /dev/null
  clear_the_way > /dev/null 2>&1
  sudo sqlite3 "$tcc" "DELETE FROM access WHERE client = '$bundle_id';" 2>/dev/null
  [ -n "${volume:-}" ] && limit 20 hdiutil detach "$volume" -quiet 2>/dev/null
  cp "$HOME/Library/Application Support/Arbor/arbor.log" "$ARBOR_OUT/arbor-downloaded.log" 2>/dev/null
  kill_started --all
}
at_exit clean_up

step "the Mac"
echo "macOS $(sw_vers -productVersion) on $(uname -m); Gatekeeper: $(spctl --status 2>&1)"
echo "a Swift toolchain of swift.org's here? $(ls "$HOME/Library/Developer/Toolchains" 2>/dev/null | head -n 1 || true)"
mkdir -p "$(dirname "$ARBOR_POINTER")" "$(dirname "$AXFIND")"
# With the newest Xcode that is here and no beta: the default of an older Mac may be older than the tools are written for.
newest=$(ls -d /Applications/Xcode*.app 2>/dev/null | grep -viE 'beta|_rc' | sort -V | tail -n 1)
[ -n "$newest" ] && export DEVELOPER_DIR="$newest/Contents/Developer"
echo "the tools are compiled by $(swiftc --version 2>&1 | head -n 1 | cut -c 1-90)"
builds=""
for tool in pointer axfind announce; do
  case "$tool" in pointer) made=$ARBOR_POINTER ;; axfind) made=$AXFIND ;; announce) made=$ANNOUNCE ;; esac
  limit 120 swiftc -O -swift-version 5 "$ARBOR_ROOT/scripts/mac-shell/$tool.swift" -o "$made" > "$ARBOR_OUT/build-$tool.log" 2>&1 &
  started $!
  builds="$builds $!"
done
for build in $builds; do ended "$build" 1300; done
for made in "$ARBOR_POINTER" "$AXFIND" "$ANNOUNCE"; do
  [ -x "$made" ] || { cat "$ARBOR_OUT"/build-*.log; die "$(basename "$made") did not compile"; }
done

step "1  the files"
version=$(ls "$files" | sed -n 's/^Arbor-\(.*\)\.zip$/\1/p' | head -n 1)
[ -n "$version" ] || die "there is no Arbor-<version>.zip in $files: run \`make release\` first, or point ARBOR_DOWNLOAD at the files"
zip="$files/Arbor-$version.zip" dmg="$files/Arbor-$version.dmg"
echo "Arbor $version: $(du -h "$zip" | cut -f 1 | tr -d ' ') zip, $(du -h "$dmg" | cut -f 1 | tr -d ' ') disk image"
check "the checksums hold" sh -c 'cd "$1" && shasum -a 256 -c "$2"' sh "$files" "Arbor-$version-checksums.txt"
check "the cask names this version" grep -qF "version \"$version\"" "$files/arbor.rb"
check "and the disk image's checksum" grep -qF "sha256 \"$(shasum -a 256 "$dmg" | cut -d ' ' -f 1)\"" "$files/arbor.rb"
check "the cask is Ruby that parses" ruby -c "$files/arbor.rb"

step "2  the zip, marked as a browser marks a download, and unpacked"
cp "$zip" "$work/"
mark "$work/Arbor-$version.zip"
(cd "$work" && limit 60 ditto -x -k "Arbor-$version.zip" .)
app="$work/Arbor.app"
program="$app/Contents/MacOS/Arbor"
check "unpacking passes the mark on to the app" with "$(mark_of "$app")" ";Safari;"
check "and to the program inside" with "$(mark_of "$program")" ";Safari;"
check "the signature holds" codesign --verify --deep --strict "$app"
codesign --display --verbose=2 "$app" 2>&1 | grep -E '^(Identifier|Signature|Authority|TeamIdentifier)' | sed 's/^/    /'
for binary in "$program" "$app/Contents/Helpers/arborctl"; do
  check "$(basename "$binary") is for Apple silicon and for Intel" same "$(lipo -archs "$binary" | tr ' ' '\n' | sort | tr '\n' ' ')" "arm64 x86_64 "
  for arch in arm64 x86_64; do check "  its $arch half from macOS 14 on" same "$(minos "$arch" "$binary")" 14.0; done
done
foreign=$(for arch in arm64 x86_64; do otool -arch "$arch" -L "$program" "$app/Contents/Helpers/arborctl" | grep -E "^\s" | grep -vE "^\s+/(System/Library|usr/lib)/"; done)
check "it needs no library but the system's" [ -z "$foreign" ] || echo "$foreign"
check "arborctl says the version" with "$("$app/Contents/Helpers/arborctl" --version 2>&1 | head -n 1)" "arborctl $version "
check "and so does Arbor" with "$(limit 10 "$program" --version 2>&1 | head -n 1)" " $version "
# On Apple silicon through Rosetta, where there is one; on an Intel Mac the two lines above were it.
if [ "$(uname -m)" = arm64 ] && arch -x86_64 /usr/bin/true 2>/dev/null; then
  check "arborctl's Intel half says it too" with "$(arch -x86_64 "$app/Contents/Helpers/arborctl" --version 2>&1 | head -n 1)" "arborctl $version "
  check "and Arbor's" with "$(limit 10 arch -x86_64 "$program" --version 2>&1 | head -n 1)" " $version "
fi
verdict=$(spctl --assess --type execute --verbose=4 "$app" 2>&1)
echo "    $verdict" | head -n 3

step "3  opened as it is"
if with "$verdict" ": accepted"; then
  echo "macOS accepts this build (notarized?): there is no detour, and docs/INSTALL.md and the notes should not tell of one"
  notarized=yes
else
  notarized=""
  open_it refused
  check "macOS puts up its dialog" within 15 shows CoreServicesUIAgent AXStaticText "Arbor"
  shot 03-refused
  told CoreServicesUIAgent
  # macOS 14 words it otherwise, and lets a right click and Open past it.
  if [ "$(sw_vers -productVersion | cut -d . -f 1)" -ge 15 ]; then
    words=$(value_of CoreServicesUIAgent "Apple could not verify")
    check "in the words the install page quotes" page_has "$ARBOR_ROOT/docs/INSTALL.md" "$words"
    check "and the notes of this very release" page_has "$files/Arbor-$version-notes.md" "$words"
    check "with Done to click" shows CoreServicesUIAgent AXButton Done
  fi
  check "Arbor does not run" not answers
  put_away_dialogs

  step "4  the way past it in System Settings (told, not judged)"
  limit 20 open "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Security"
  if within 15 shows "System Settings" AXButton "Open Anyway"; then
    told "System Settings" 400 | grep -iE "arbor|anyway" | head -n 6
    quoted "$(value_of "System Settings" "was blocked")"
    shot 04-open-anyway
    press "System Settings" AXButton "Open Anyway"
    within 10 shows CoreServicesUIAgent AXButton "Open Anyway"
    shot 04-asked-again
    told CoreServicesUIAgent
    quoted "$(value_of CoreServicesUIAgent "Apple is not able")"
    before=$(on_screen)
    if press CoreServicesUIAgent AXButton "Open Anyway"; then
      # It takes its time: five seconds and more on a hosted Mac.
      if within 15 has_come && ! answers; then
        asker=$(newcomer)
        echo "  asked by: $asker"
        shot 04-asked-who
        told "$asker"
        quoted "$(value_of "$asker" "You are attempting")"
        # Here the road ends for a script. Nobody knows the password of the account GitHub's Macs run jobs under, it cannot be given another
        # ("not permitted without secure token unlock"), and an administrator made on the spot is turned away.
        clear_the_way
        on_screen | grep -qxF "$asker" && echo "  $asker's dialog is still there"
      else
        echo "  nothing more was asked"
        shot 04-nothing-asked
      fi
    fi
  else
    echo "  System Settings shows no Open Anyway"
    shot 04-no-open-anyway
  fi
  clear_the_way
  limit 10 osascript -e 'tell application "System Settings" to quit'
  if answers; then
    echo "  ARBOR RUNS: that road leads through. From where: $(pgrep -fl "Arbor.app/Contents/MacOS/Arbor" | grep -v watchdog | cut -d ' ' -f 2- | sed "s|$work|<where it was unpacked>|" | cut -c 1-110 | head -n 1)"
    echo "  the mark now: $(mark_of "$app")"
    ask quit > /dev/null
    within 10 not answers
  else
    echo "  Arbor does not run yet"
  fi
fi

step "5  the way past it in Terminal, and the first run"
# A copy of its own, as marked as the first was: whatever macOS has noted about that one does not count.
mkdir -p "$work/again"
(cd "$work/again" && limit 60 ditto -x -k "$work/Arbor-$version.zip" .)
app="$work/again/Arbor.app"
program="$app/Contents/MacOS/Arbor"
if [ -z "$notarized" ]; then
  check "a second copy is marked like the first" with "$(mark_of "$app")" ";Safari;"
  xattr -dr com.apple.quarantine "$app"
  check "xattr -dr com.apple.quarantine takes the mark off" [ -z "$(mark_of "$app")$(mark_of "$program")" ]
fi
sudo sqlite3 "$tcc" "DELETE FROM access WHERE client = '$bundle_id';" 2>/dev/null
check "Arbor starts" launch first-run
check "no dialog of macOS's stands in the way" not shows CoreServicesUIAgent AXStaticText "Arbor"
echo "    $(ask status | head -n 1)"
check "it says its version" with "$(ask version | head -n 1)" "Arbor $version "
check "never given anything, it waits for the permission" status_starts "waiting for Accessibility"
check "its welcome window is up and names the permission" within 8 shows Arbor AXStaticText Accessibility
shot 05-first-run
told Arbor 14
told universalAccessAuthWarn

step "6  with the permission"
waiting=$(process)
# What switching Arbor on in System Settings records: the bundle id and the signature's designated requirement, compiled.
codesign --display --requirements - "$app" 2>/dev/null | sed -n 's/^\(# \)\{0,1\}designated => //p' > "$work/requirement.txt"
echo "    designated => $(cut -c 1-120 "$work/requirement.txt")"
csreq -r- -b "$work/requirement.bin" < "$work/requirement.txt"
sudo sqlite3 "$tcc" "INSERT OR REPLACE INTO access (service, client, client_type, auth_value, auth_reason, auth_version, csreq, indirect_object_identifier, flags, last_modified) VALUES ('kTCCServiceAccessibility', '$bundle_id', 0, 2, 3, 1, X'$(xxd -p "$work/requirement.bin" | tr -d '\n')', 'UNUSED', 0, strftime('%s', 'now'));"
# The other two things the switch does, in this order (announce.swift says why).
sudo killall -9 tccd
sleep 2
"$ANNOUNCE"
check "it runs, without having been started again" within 15 status_starts "running"
check "the very process that was waiting" same "$(process)" "$waiting"
echo one > "$work/one.txt"; echo two > "$work/two.txt"
limit 20 open -a TextEdit "$work/one.txt" "$work/two.txt"
check "it sees two windows" within 12 eval 'ask status | grep -qE "[2-9] floating"'
own=$(sizes)
echo "    $(ask arrange | head -n 1)"
check "and docks them" within 8 eval 'ask status | grep -qE "[2-9] docked"'
shot 06-docked
ask ascii | head -n 24
echo "    $(ask quit | head -n 1)"
check "asked to quit, it has gone" within 10 not answers
check "both windows are wholly in view" within 5 all_in_view
check "at the sizes they had before" within 5 eval '[ -n "$own" ] && [ "$(sizes)" = "$own" ]'
shot 06-after-quit
limit 10 osascript -e 'tell application "TextEdit" to quit'

step "7  the disk image"
cp "$dmg" "$work/"
mark "$work/Arbor-$version.dmg"
volume="$work/volume"
limit 60 hdiutil attach -nobrowse -readonly -mountpoint "$volume" "$work/Arbor-$version.dmg" > "$ARBOR_OUT/attach.txt" 2>&1
check "it mounts" [ -d "$volume/Arbor.app" ]
check "the signature of the app on it holds" codesign --verify --deep --strict "$volume/Arbor.app"
check "it holds the very app that is in the zip" same "$(cdhash "$volume/Arbor.app")" "$(cdhash "$app")"
check "and the link to drag it onto" same "$(readlink "$volume/Applications")" /Applications
limit 20 hdiutil detach "$volume" -quiet && volume=""
# What unmounting said is not the script's verdict: a volume that is busy for a moment is let go of at the end (clean_up).
true
