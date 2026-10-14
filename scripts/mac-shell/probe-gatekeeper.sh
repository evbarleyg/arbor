#!/bin/bash
# A probe, not to be merged: what does macOS do to a downloaded, ad-hoc-signed Arbor, dialog by dialog?
[ "${GITHUB_ACTIONS:-}" = true ] || { echo "for a throwaway Mac only"; exit 2; }
cd "$(dirname "$0")/../.." || exit 2
root=$PWD
out=$root/mac-shell
mkdir -p "$out" /tmp/tools /tmp/served
n=0
shot() { n=$((n + 1)); screencapture -x "$out/$(printf %02d "$n")-$1.png"; echo "  [picture $(printf %02d "$n")-$1]"; }
step() { echo; echo "== $*  ($(date -u +%T))"; }
pid_of() { pgrep -x "$1" | head -1; }
tree() { local pid; pid=$(pid_of "$1"); [ -n "$pid" ] && { echo "  -- what $1 shows:"; /tmp/tools/ax "$pid" tree 2>&1 | grep -vE 'AXGroup - "" ""|AXScrollBar|AXValueIndicator|AXUnknown|AXImage - "" ""' | cut -c 1-260 | head -n "${2:-60}"; }; }
# press <process> <role> <text>: click it as a person would, in its middle
press() {
  local pid point
  pid=$(pid_of "$1"); [ -n "$pid" ] || { echo "  no process $1"; return 1; }
  point=$(/tmp/tools/ax "$pid" point "$2" "$3" 2>&1) || { echo "  $1 shows no $2 '$3': $point"; return 1; }
  echo "  clicking $2 '$3' of $1 at $point"
  # shellcheck disable=SC2086
  /tmp/tools/pointer click $point
}
type_text() { local i; for ((i = 0; i < ${#1}; i++)); do /tmp/tools/pointer key "${1:$i:1}"; done; }
dialogs() { for name in CoreServicesUIAgent SecurityAgent coreautha UserNotificationCenter universalAccessAuthWarn "System Settings" Safari; do tree "$name" "$1"; done; }
arbors() { pgrep -fl "Arbor.app/Contents/MacOS/Arbor" | cut -c 1-200 || true; }

step "the Mac"
sw_vers | tr '\n' ' '; echo
uname -m
spctl --status 2>&1
csrutil status 2>&1
sudo -n true && echo "sudo without a password: yes"
defaults read com.apple.LaunchServices LSQuarantine 2>&1 | tail -1
swift --version 2>&1 | head -1
swiftc -O -swift-version 5 scripts/mac-shell/pointer.swift -o /tmp/tools/pointer > "$out/tools.log" 2>&1 &
swiftc -O -swift-version 5 scripts/mac-shell/probe-ax.swift -o /tmp/tools/ax >> "$out/tools.log" 2>&1 &

step "build, ad hoc"
ARBOR_SIGN_IDENTITY=- make app > "$out/make-app.log" 2>&1 || { tail -30 "$out/make-app.log"; exit 1; }
tail -4 "$out/make-app.log"
wait
cat "$out/tools.log"
echo "ax access: $(/tmp/tools/pointer ax-access), screen access: $(/tmp/tools/pointer screen-access)"
version=$(./scripts/version.sh version)
ditto -c -k --keepParent build/Arbor.app "/tmp/served/Arbor-$version.zip"
mkdir -p /tmp/staging && cp -R build/Arbor.app /tmp/staging/ && ln -s /Applications /tmp/staging/Applications
hdiutil create -quiet -volname "Arbor $version" -srcfolder /tmp/staging -format UDZO -ov "/tmp/served/Arbor-$version.dmg"
ls -l /tmp/served
codesign -dvvv build/Arbor.app 2>&1 | grep -E "Signature|flags|Identifier|TeamIdentifier"
python3 -m http.server 8123 --bind 127.0.0.1 --directory /tmp/served > "$out/server.log" 2>&1 &
server=$!
sleep 1

step "1  download the zip with Safari"
ls -la ~/Downloads
open -a Safari "http://127.0.0.1:8123/Arbor-$version.zip"
sleep 8
shot safari-download
tree Safari 40
press Safari AXButton Allow && sleep 6 && shot safari-after-allow
for _ in $(seq 1 20); do [ -e ~/Downloads/Arbor.app ] && break; sleep 1; done
ls -la@ ~/Downloads
if [ ! -e ~/Downloads/Arbor.app ]; then
  if [ -e ~/Downloads/"Arbor-$version.zip" ]; then
    echo "Safari left the zip packed; opening it with Archive Utility, as a double click does"
    xattr -l ~/Downloads/"Arbor-$version.zip"
    open ~/Downloads/"Arbor-$version.zip"; sleep 5
  else
    echo "SAFARI DID NOT DOWNLOAD IT: marking a copy by hand, as Safari marks a download"
    cp "/tmp/served/Arbor-$version.zip" ~/Downloads/
    xattr -w com.apple.quarantine "0083;$(printf '%x' "$(date +%s)");Safari;$(uuidgen)" ~/Downloads/"Arbor-$version.zip"
    open ~/Downloads/"Arbor-$version.zip"; sleep 5
  fi
  ls -la@ ~/Downloads
fi
app=~/Downloads/Arbor.app
echo "the mark on the app: $(xattr -p com.apple.quarantine "$app" 2>&1)"
echo "the mark on its program: $(xattr -p com.apple.quarantine "$app/Contents/MacOS/Arbor" 2>&1)"
spctl --assess --type execute --verbose=4 "$app" 2>&1 | sed 's/^/  spctl: /'
osascript -e 'tell application "Safari" to quit' 2>&1

step "2  open it, as a double click does"
(open "$app" 2>&1 | head -3) &
sleep 4
shot first-open
dialogs 40
echo "running? $(arbors)"

step "3  Done, then System Settings"
press CoreServicesUIAgent AXButton Done || press CoreServicesUIAgent AXButton OK
sleep 1
open "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Security"
sleep 8
shot privacy-and-security
settings=$(pid_of "System Settings")
/tmp/tools/ax "$settings" tree 2>&1 | grep -iE "arbor|anyway|blocked|AXButton" | cut -c 1-240 | head -30
echo "reveal: $(/tmp/tools/ax "$settings" reveal AXButton "Open Anyway" 2>&1)"
sleep 1
shot open-anyway-in-view
press "System Settings" AXButton "Open Anyway"
sleep 3
shot after-open-anyway
dialogs 40

step "4  the second question"
press CoreServicesUIAgent AXButton "Open Anyway" || press "System Settings" AXButton "Open Anyway"
sleep 3
shot asked-for-a-password
dialogs 40
echo "running? $(arbors)"

step "5  the password"
password=arborprobe
sudo dscl . -passwd /Users/"$(id -un)" "$password" && echo "the account has a password of the probe's now"
type_text "$password"
sleep 0.5
shot password-typed
/tmp/tools/pointer key return
sleep 6
shot after-the-password
dialogs 30
echo "running? $(arbors)"
echo "the mark on the app now: $(xattr -p com.apple.quarantine "$app" 2>&1)"

step "6  the first run"
ctl="$app/Contents/Helpers/arborctl"
"$ctl" status 2>&1 | head -5
"$ctl" version 2>&1 | head -3
tree Arbor 80
tail -20 ~/Library/"Application Support"/Arbor/arbor.log 2>&1 | cut -c 1-220

step "7  the other way: take the mark off"
"$ctl" quit 2>&1 | head -2
sleep 2
mkdir -p /tmp/second && ditto -x -k "/tmp/served/Arbor-$version.zip" /tmp/second
xattr -w -r com.apple.quarantine "0083;$(printf '%x' "$(date +%s)");Safari;$(uuidgen)" /tmp/second/Arbor.app
xattr -dr com.apple.quarantine /tmp/second/Arbor.app
(open /tmp/second/Arbor.app 2>&1 | head -3) &
sleep 5
shot without-the-mark
echo "running? $(arbors)"
/tmp/second/Arbor.app/Contents/Helpers/arborctl status 2>&1 | head -3
dialogs 30

kill "$server" 2>/dev/null
log show --last 12m --style compact --predicate 'process == "syspolicyd" AND eventMessage CONTAINS[c] "arbor"' 2>/dev/null | cut -c 1-260 | tail -40 > "$out/syspolicyd.log"
wc -l "$out/syspolicyd.log"
exit 0
