#!/bin/bash
# A probe, not to be merged. Two questions only a Mac can answer, in one run:
#   A  What does macOS do to the Arbor another Mac built (the Release workflow's files, in downloaded/), from the download to the first
#      docked window, dialog by dialog, and what does a person have to click?
#   B  Does the oldest Xcode on the runner (26.0.1, Swift 6.2) build Arbor, tests included?
[ "${GITHUB_ACTIONS:-}" = true ] || { echo "for a throwaway Mac only"; exit 2; }
cd "$(dirname "$0")/../.." || exit 2
root=$PWD
out=$root/mac-shell
served=$root/downloaded
mkdir -p "$out" /tmp/tools
PATH=$(printf '%s' "$PATH" | tr ':' '\n' | grep -v swiftly | paste -sd: -)
export PATH
n=0
password=arborprobe
shot() { n=$((n + 1)); screencapture -x "$out/$(printf %02d "$n")-$1.png"; echo "  [picture $(printf %02d "$n")-$1]"; }
step() { echo; echo "== $*  ($(date -u +%T))"; }
quiet='(Window Server|Dock|Control Cent|SystemUIServer|Spotlight|Notification Cent|TextInput|Wallpaper|loginwindow|WindowManager|Finder|Terminal)'
# pid and owner of everything with a window on screen, apart from the furniture
owners() { /tmp/tools/pointer windows --on-screen | awk '{ pid = $2; $1 = $2 = $3 = $4 = $5 = $6 = $7 = $8 = ""; sub(/^ +/, ""); print pid, $0 }' | sort -u | grep -vE "^[0-9]+ $quiet"; }
tree() { /tmp/tools/ax "$1" tree 2>&1 | grep -vE 'AXGroup - "" ""|AXScrollBar|AXValueIndicator|AXUnknown|AXImage - "" ""|AXSplitter|AXCell - "" ""|AXRow - "" ""' | cut -c 1-300 | head -n "${2:-45}"; }
look() { owners | while read -r pid owner; do echo "  -- $owner ($pid) shows:"; tree "$pid" "${1:-45}" | sed 's/^/     /'; done; }
# where <role> <text> [owner pattern]: "pid x y" of the first such control on screen
where() {
  owners | grep -E "^[0-9]+ ${3:-.}" | while read -r pid _; do
    point=$(/tmp/tools/ax "$pid" point "$1" "$2" 2>/dev/null) && { echo "$pid $point"; break; }
  done
}
press() {  # press <role> <text> [owner pattern]
  local found
  found=$(where "$@")
  [ -n "$found" ] || return 1
  set -- $found "$2"
  echo "  CLICK '$4' (process $1) at $2 $3"
  /tmp/tools/pointer click "$2" "$3"
}
type_text() { local i; for ((i = 0; i < ${#1}; i++)); do /tmp/tools/pointer key "${1:$i:1}"; done; }
asks_for_password() { /tmp/tools/pointer windows --on-screen | grep -qiE "SecurityAgent|coreauth|LocalAuthentication|authorizationhost"; }
arbors() { pgrep -fl "Arbor.app/Contents/MacOS/Arbor" | grep -v watchdog | cut -c 1-220; }
settings_pane() { open "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?$1"; sleep 6; }
# Clicks through whatever stands between `open` and a running Arbor, and writes down each thing it met.
get_past_gatekeeper() {
  local round
  for round in 1 2 3 4 5 6 7 8 9 10; do
    sleep 3
    if [ -n "$(arbors)" ]; then echo "  Arbor runs after $((round - 1)) actions"; return 0; fi
    shot "$1-round-$round"
    look 40
    if asks_for_password; then
      echo "  TYPE the account's password, Return"
      type_text "$password"; /tmp/tools/pointer key return
    elif press AXButton "Open Anyway" "(CoreServicesUIAgent|UserNotificationCenter|SecurityAgent)"; then :
    elif [ -n "$(where AXButton "Open Anyway" "System Settings")" ]; then
      /tmp/tools/ax "$(pgrep -x "System Settings" | head -1)" reveal AXButton "Open Anyway" > /dev/null 2>&1
      sleep 1; shot "$1-open-anyway-in-view"
      press AXButton "Open Anyway" "System Settings"
    elif press AXButton "Done" "CoreServicesUIAgent"; then
      sleep 1; echo "  OPEN System Settings, Privacy & Security"; settings_pane Security
    elif press AXButton "Open" "CoreServicesUIAgent"; then :
    elif press AXButton "OK" "CoreServicesUIAgent"; then
      sleep 1; echo "  OPEN System Settings, Privacy & Security"; settings_pane Security
    else
      echo "  nothing known to click"
    fi
  done
  return 1
}

step "the Mac"
sw_vers | tr '\n' ' '; echo "$(uname -m)"
spctl --status 2>&1
csrutil status 2>&1
swiftc -O -swift-version 5 scripts/mac-shell/pointer.swift -o /tmp/tools/pointer > "$out/tools.log" 2>&1 &
swiftc -O -swift-version 5 scripts/mac-shell/probe-ax.swift -o /tmp/tools/ax >> "$out/tools.log" 2>&1 &
wait
cat "$out/tools.log"
echo "ax access: $(/tmp/tools/pointer ax-access), screen access: $(/tmp/tools/pointer screen-access)"
sudo dscl . -passwd /Users/"$(id -un)" "$password" && echo "the account has the probe's password now"

step "A0  the files, as the other Mac left them"
ls -l "$served"
(cd "$served" && shasum -a 256 -c Arbor-*-checksums.txt)
version=$(ls "$served" | sed -n 's/^Arbor-\(.*\)\.zip$/\1/p')
echo "version $version"
cat "$served/arbor.rb"
python3 -m http.server 8123 --bind 127.0.0.1 --directory "$served" > "$out/server.log" 2>&1 &
server=$!
sleep 1

step "A1  download the zip with Safari"
open -a Safari "http://127.0.0.1:8123/Arbor-$version.zip"
sleep 8
shot safari-download
look 30
press AXButton Allow Safari && sleep 5 && shot safari-after-allow
for _ in $(seq 1 15); do [ -e ~/Downloads/Arbor.app ] && break; sleep 1; done
ls -la@ ~/Downloads
how="Safari downloaded and unpacked it"
if [ ! -e ~/Downloads/Arbor.app ]; then
  if [ -e ~/Downloads/"Arbor-$version.zip" ]; then
    how="Safari downloaded it; Archive Utility unpacked it"
  else
    how="SAFARI DID NOT DOWNLOAD IT: a copy marked by hand as Safari marks one; Archive Utility unpacked it"
    cp "$served/Arbor-$version.zip" ~/Downloads/
    xattr -w com.apple.quarantine "0083;$(printf '%x' "$(date +%s)");Safari;$(uuidgen)" ~/Downloads/"Arbor-$version.zip"
  fi
  xattr -l ~/Downloads/"Arbor-$version.zip"
  open ~/Downloads/"Arbor-$version.zip"; sleep 6
  ls -la@ ~/Downloads
fi
echo "$how"
app=~/Downloads/Arbor.app
ctl="$app/Contents/Helpers/arborctl"
echo "the mark on the app: $(xattr -p com.apple.quarantine "$app" 2>&1)"
echo "the mark on its program: $(xattr -p com.apple.quarantine "$app/Contents/MacOS/Arbor" 2>&1)"
codesign --verify --deep --strict --verbose=2 "$app" 2>&1 | sed 's/^/  codesign: /'
spctl --assess --type execute --verbose=4 "$app" 2>&1 | sed 's/^/  spctl: /'
lipo -archs "$app/Contents/MacOS/Arbor"
echo "what it is linked against that is not the system's:"; otool -arch arm64 -L "$app/Contents/MacOS/Arbor" | grep -vE "^\s+/(System|usr/lib)/" | head
echo "where it looks for @rpath:"; otool -arch arm64 -l "$app/Contents/MacOS/Arbor" | grep -A2 LC_RPATH | grep path
echo "a toolchain from swift.org on this Mac? $(ls ~/Library/Developer/Toolchains 2>&1 | head -2)"
otool -l "$app/Contents/MacOS/Arbor" | grep -A4 LC_BUILD_VERSION | grep -E "minos|sdk" | sort -u | tr '\n' ' '; echo
osascript -e 'tell application "Safari" to quit' 2>&1

step "A2  the command line tool and the Intel half, still marked"
"$ctl" --version 2>&1 | head -3
arch -x86_64 "$ctl" --version 2>&1 | head -3
sleep 2; shot after-arborctl; look 25
press AXButton "Done" "CoreServicesUIAgent"

step "A3  open it, as a double click does, and get past what comes"
(open "$app" 2>&1 | head -3) &
get_past_gatekeeper zip && echo "PAST GATEKEEPER" || echo "NOT PAST GATEKEEPER"
arbors
echo "the mark on the app now: $(xattr -p com.apple.quarantine "$app" 2>&1)"
spctl --assess --type execute --verbose=4 "$app" 2>&1 | sed 's/^/  spctl: /'

step "A4  the first run"
sleep 3
shot first-run
look 70
"$ctl" status 2>&1 | head -5
"$ctl" version 2>&1 | head -3
"$ctl" doctor 2>&1 | head -30

step "A5  Accessibility, by hand"
press AXButton "Open System Settings" || settings_pane Privacy_Accessibility
sleep 6
shot accessibility-pane
settings=$(pgrep -x "System Settings" | head -1)
tree "$settings" 200 | grep -iE "arbor|AXCheckBox|AXSwitch|AXButton" | head -30
for role in AXCheckBox AXSwitch; do press "$role" Arbor "System Settings" && break; done
sleep 3
shot accessibility-after-the-switch
if asks_for_password; then echo "  TYPE the account's password, Return"; type_text "$password"; /tmp/tools/pointer key return; sleep 4; shot accessibility-after-the-password; fi
look 30 | head -80
"$ctl" status 2>&1 | head -3
case "$("$ctl" status 2>&1)" in
  running*) echo "SWITCHED ON BY HAND" ;;
  *)
    echo "the switch did not do it: writing the entry as System Settings would"
    codesign --display --requirements - "$app" 2>/dev/null | sed -n 's/^\(# \)\{0,1\}designated => //p' | tee /tmp/requirement.txt
    csreq -r- -b /tmp/requirement.bin < /tmp/requirement.txt
    hex=$(xxd -p /tmp/requirement.bin | tr -d '\n')
    sudo sqlite3 "/Library/Application Support/com.apple.TCC/TCC.db" "INSERT OR REPLACE INTO access (service, client, client_type, auth_value, auth_reason, auth_version, csreq, indirect_object_identifier, flags, last_modified) VALUES ('kTCCServiceAccessibility', 'com.evbarleyg.arbor', 0, 2, 3, 1, X'$hex', 'UNUSED', 0, strftime('%s', 'now'));" 2>&1
    sleep 5
    "$ctl" status 2>&1 | head -3
    ;;
esac
osascript -e 'tell application "System Settings" to quit' 2>&1

step "A6  does it work? two windows, docked side by side"
sleep 2
shot after-the-permission
look 60 | head -90
open -a TextEdit "$root/VERSION"; open -a TextEdit "$root/LICENSE"
sleep 4
"$ctl" ascii 2>&1 | head -30
"$ctl" arrange 2>&1 | head -3
sleep 2
shot arranged
"$ctl" layout 2>&1 | head -20
"$ctl" status 2>&1 | head -5
"$ctl" quit 2>&1 | head -2
sleep 3
echo "still running? $(arbors)"
shot after-quit
cp ~/Library/"Application Support"/Arbor/arbor.log "$out/arbor.log" 2>/dev/null

step "A7  the second launch asks nothing?"
(open "$app" 2>&1 | head -3) &
sleep 6
shot second-launch
arbors
"$ctl" status 2>&1 | head -2
"$ctl" quit 2>&1 | head -1
sleep 2

step "A8  the other way: take the mark off in Terminal"
mkdir -p /tmp/second && cp "$served/Arbor-$version.zip" /tmp/second/
xattr -w com.apple.quarantine "0083;$(printf '%x' "$(date +%s)");Safari;$(uuidgen)" "/tmp/second/Arbor-$version.zip"
(cd /tmp/second && ditto -x -k "Arbor-$version.zip" .)
echo "after ditto: $(xattr -p com.apple.quarantine /tmp/second/Arbor.app 2>&1)"
xattr -dr com.apple.quarantine /tmp/second/Arbor.app
echo "after xattr -dr: $(xattr -p com.apple.quarantine /tmp/second/Arbor.app 2>&1)"
(open /tmp/second/Arbor.app 2>&1 | head -3) &
sleep 6
shot without-the-mark
arbors
/tmp/second/Arbor.app/Contents/Helpers/arborctl status 2>&1 | head -2
/tmp/second/Arbor.app/Contents/Helpers/arborctl quit 2>&1 | head -1
sleep 2

step "A9  the disk image"
cp "$served/Arbor-$version.dmg" ~/Downloads/
xattr -w com.apple.quarantine "0083;$(printf '%x' "$(date +%s)");Safari;$(uuidgen)" ~/Downloads/"Arbor-$version.dmg"
open ~/Downloads/"Arbor-$version.dmg"
sleep 8
shot disk-image-open
look 25 | head -50
ls -la@ "/Volumes/Arbor $version" 2>&1 | head
cp -R "/Volumes/Arbor $version/Arbor.app" /Applications/ 2>&1
echo "the mark on the copy in /Applications: $(xattr -p com.apple.quarantine /Applications/Arbor.app 2>&1)"
(open /Applications/Arbor.app 2>&1 | head -3) &
sleep 5
shot disk-image-first-open
look 25 | head -40
arbors
press AXButton "Done" "CoreServicesUIAgent"
/Applications/Arbor.app/Contents/Helpers/arborctl quit > /dev/null 2>&1
hdiutil detach "/Volumes/Arbor $version" -quiet
rm -rf /Applications/Arbor.app

step "A10  the cask, from a tap of this run's own, with the address pointed at this Mac"
export HOMEBREW_NO_AUTO_UPDATE=1 HOMEBREW_NO_INSTALL_CLEANUP=1 HOMEBREW_NO_ENV_HINTS=1 HOMEBREW_NO_ANALYTICS=1
brew --version | head -1
brew tap-new --no-git arbor/probe > /dev/null 2>&1
tap=$(brew --repository)/Library/Taps/arbor/homebrew-probe
mkdir -p "$tap/Casks"
sed "s|https://github.com/evbarleyg/arbor/releases/download/v#{version}/|http://127.0.0.1:8123/|" "$served/arbor.rb" > "$tap/Casks/arbor.rb"
perl -e 'alarm 150; exec @ARGV' brew install --cask arbor/probe/arbor 2>&1 | tail -25
ls -ld /Applications/Arbor.app "$(brew --prefix)/bin/arborctl" 2>&1
echo "the mark Homebrew leaves: $(xattr -p com.apple.quarantine /Applications/Arbor.app 2>&1)"
perl -e 'alarm 90; exec @ARGV' brew style arbor/probe/arbor 2>&1 | tail -12
perl -e 'alarm 90; exec @ARGV' brew audit --cask arbor/probe/arbor 2>&1 | tail -12
perl -e 'alarm 60; exec @ARGV' brew uninstall --cask arbor/probe/arbor 2>&1 | tail -6
kill "$server" 2>/dev/null
log show --last 15m --style compact --predicate 'process == "syspolicyd" AND eventMessage CONTAINS[c] "arbor"' 2>/dev/null | cut -c 1-260 | tail -60 > "$out/syspolicyd.log"

step "B  the oldest Xcode on the runner"
export DEVELOPER_DIR=/Applications/Xcode_26.0.1.app/Contents/Developer
swift --version 2>&1 | head -1
swift build --build-tests > "$out/build-oldest.log" 2>&1
code=$?
grep -E "^/.*: error:|^error:|While emitting IR|While evaluating request IRGen" "$out/build-oldest.log" | sed "s|$PWD/||g" | sort -u | cut -c 1-260 | head -n 40
tail -n 1 "$out/build-oldest.log"
echo "Xcode 26.0.1: exit code $code  ($(date -u +%T))"
exit "$code"
