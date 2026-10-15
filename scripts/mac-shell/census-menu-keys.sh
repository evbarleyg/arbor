#!/bin/bash
# Which shortcuts do the apps on a Mac have in their own menu bars? (collab/IDEAS.md, I16: so that the next clash is found before a person meets it.)
#
#   scripts/mac-shell/run.sh --macs 2 scripts/mac-shell/census-menu-keys.sh
#
# Opens the apps a hosted Mac comes with (all but those `list` leaves out, and says why), one after the other and in the background, reads each menu bar
# through Accessibility (menukeys.swift) and ends the app. Then it installs some widely used free apps from the package manager (chat, calls, editors,
# design, terminals, notes: where the risk is), without an account, and reads theirs at whatever first window they show. What comes back is raw:
# mac-shell/menu-keys/<bundle id>.tsv, one line per menu item with a shortcut, and mac-shell/not-read.txt. What clashes with Arbor's own keys is worked
# out on Linux from those files (MenuKeyCensusTests); collab/evidence/menu-keys keeps them, without the titles, and its README says how.
#
# It takes two Macs side by side to be through within a script's time limit: the first reads what the Mac comes with, the second the added apps
# ($MAC_SHELL_SHARE). On one Mac it goes as far as the time allows and says what it left out.
#
# THE QUESTIONS ONLY A MAC CAN ANSWER: what the attributes hold for letters, digits, signs, arrows, ↩, Space and ⎋; how long a whole menu bar takes to
# read; and the list itself.
#
# Only on GitHub's Macs, and alone on its Mac: it opens and ends every app there is, prints the titles of their menu items, which on a person's Mac can hold
# their words, and leaves behind the apps it installed and three browsers without their quarantine mark.
source "$(dirname "$0")/lib.sh"
needs_throwaway_mac "open and quit every app on the Mac, and print the titles of their menu items"

TOOL="$ARBOR_ROOT/.build/mac-shell/menukeys"
OUT="$ARBOR_OUT/menu-keys"
NOT_READ="$ARBOR_OUT/not-read.txt"
mkdir -p "$OUT" "$(dirname "$TOOL")"
: > "$NOT_READ"
swiftc -O -swift-version 5 "$ARBOR_ROOT/scripts/mac-shell/menukeys.swift" -o "$TOOL" > "$ARBOR_OUT/build-menukeys.log" 2>&1 || {
  cat "$ARBOR_OUT/build-menukeys.log"
  die "scripts/mac-shell/menukeys.swift did not compile"
}
sw_vers -productVersion

pid_of() { lsappinfo info -only pid "$1" 2>/dev/null | sed -n 's/.*=//p'; }
bundle_of() { /usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "$1/Contents/Info.plist" 2>/dev/null; }

# One Xcode of the many. Nothing that logs out, erases, migrates or installs. Nothing that is a view of macOS's own and no app with a menu bar (Siri, Launchpad,
# Mission Control, Time Machine, Apps, Screenshot, which did not start as an app in two runs and left its toolbar on the screen). Not PowerShell, which is
# a shell in a Terminal window and had no menu bar in two runs.
list() {
  ls -d /System/Applications/*.app /System/Applications/Utilities/*.app /Applications/*.app /System/Library/CoreServices/Finder.app 2>/dev/null \
    | grep -v -e "/Xcode[_ ].*\.app" -e "Migration Assistant" -e "Boot Camp" -e "Install " -e "Erase " -e "Siri.app" -e "Launchpad" -e "Mission Control" \
      -e "Time Machine" -e "Apps.app" -e "Screenshot.app" -e "PowerShell"
  ls -d "$(dirname "$(dirname "$(xcode-select -p)")")" 2>/dev/null
}

read_one() {
  local app=$1 bundle pid was items before="" tries=0
  bundle=$(bundle_of "$app")
  [ -n "$bundle" ] || return 0
  [ -f "$OUT/$bundle.tsv" ] && return 0
  was=$(pid_of "$bundle")
  # Or macOS asks whether an app from the internet may be opened, and nobody is there to answer: that is what kept the three large browsers, which the
  # Mac's keepers install from the package manager, without a menu bar in two runs (2026-10-15).
  if xattr -p com.apple.quarantine "$app" > /dev/null 2>&1; then
    limit 60 xattr -dr com.apple.quarantine "$app" 2>/dev/null || limit 60 sudo -n xattr -dr com.apple.quarantine "$app" 2>/dev/null
  fi
  limit 20 open -g -j "$app" > /dev/null 2>&1 || limit 20 open -g "$app" > /dev/null 2>&1
  until pid=$(pid_of "$bundle") && [ -n "$pid" ]; do
    tries=$((tries + 1))
    [ "$tries" -ge 80 ] && { echo "$bundle: did not start" | tee -a "$NOT_READ"; return 0; }
    sleep 0.25
  done
  # An app builds its menu bar as it finishes launching, and some go on building: of two runs one found 39 shortcuts in an app and the other 50, one 58
  # and the other none. So it is read until two readings three seconds apart hold as many items, for half a minute at most; after ten seconds
  # the app is shown.
  tries=0
  while [ "$tries" -lt 10 ]; do
    tries=$((tries + 1))
    [ "$tries" -eq 4 ] && limit 20 open "$app" > /dev/null 2>&1
    limit 30 "$TOOL" "$pid" --titles > "$OUT/$bundle.tsv" 2>&1
    items=$(sed -n 's/^read \([0-9]*\) items.*/\1/p' "$OUT/$bundle.tsv")
    [ -n "$items" ] && [ "$items" -gt 0 ] && [ "$items" = "$before" ] && break
    before=$items
    sleep 3
  done
  echo "$bundle: $(tail -n 1 "$OUT/$bundle.tsv")"
  grep -q "^read [1-9]" "$OUT/$bundle.tsv" || echo "$bundle: no menu bar in $tries readings" >> "$NOT_READ"
  # What ran before this script stays: the Finder, and whatever the Mac's keepers started.
  [ -n "$was" ] || { kill -TERM "$pid" 2>/dev/null; sleep 0.3; kill -KILL "$pid" 2>/dev/null; }
}

share=${MAC_SHELL_SHARE:-1/1}
read_well() { grep -l "^read [1-9][0-9]* items" "$OUT"/*.tsv 2>/dev/null | wc -l | tr -d ' '; }
at_least() { [ "$1" -ge "$2" ] || { echo "$1"; return 1; }; }

if [ "${share%/*}" = 1 ]; then
  step "every app the Mac comes with, one after the other"
  list | while read -r app; do read_one "$app"; done
  check "sixty menu bars or more were read" at_least "$(read_well)" 60
  for browser in com.google.Chrome org.mozilla.firefox com.microsoft.edgemac; do
    check "and that of $browser" grep -q "^read [1-9]" "$OUT/$browser.tsv"
  done
fi

# Named as common apps and as nobody's: what many people have beside what a Mac comes with.
CASKS="slack discord telegram signal whatsapp zoom visual-studio-code sublime-text zed iterm2 warp notion obsidian figma spotify vlc raycast postman github"
case "$share" in
  1/1 | 2/*) ;;
  *) CASKS="" ;;
esac
step "widely used free apps, from the package manager"
stock=$(read_well) asked=0
for cask in $CASKS; do
  asked=$((asked + 1))
  # The script is stopped at its time limit (1,100 s), and what was read by then must have been counted. An app takes about forty seconds, and at
  # the worst four minutes to install and one to read.
  [ "$SECONDS" -lt 780 ] || { echo "$cask: left out, the time is up" | tee -a "$NOT_READ"; continue; }
  before=$(ls -d /Applications/*.app | sort)
  if ! HOMEBREW_NO_AUTO_UPDATE=1 HOMEBREW_NO_ANALYTICS=1 HOMEBREW_NO_INSTALL_CLEANUP=1 limit 240 brew install --cask "$cask" > "$ARBOR_OUT/brew-$cask.log" 2>&1; then
    echo "$cask: did not install: $(tail -n 1 "$ARBOR_OUT/brew-$cask.log" | cut -c 1-120)" | tee -a "$NOT_READ"
    continue
  fi
  ls -d /Applications/*.app | sort | comm -13 <(echo "$before") - | while read -r app; do
    echo "$cask $(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$app/Contents/Info.plist" 2>/dev/null)"
    read_one "$app"
  done
done
[ "$asked" -eq 0 ] || check "of the $asked that were asked for, all but three or fewer were installed and read" at_least "$(($(read_well) - stock + 3))" "$asked"

step "what has ⌃⌥ and no ⌘ (modifiers 14, with ⇧ 15), or ⌃⌥⌘ (6, with ⇧ 7)"
grep -H -E "^(14|15|6|7)	" "$OUT"/*.tsv | sed "s|$OUT/||" || echo "nothing"
echo
echo "$(read_well) menu bars read. Not read:"
cat "$NOT_READ"
