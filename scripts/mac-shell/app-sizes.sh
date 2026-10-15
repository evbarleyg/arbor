#!/bin/bash
# How small and how large the apps go that come with macOS, or with GitHub's Macs: the measurements behind the table Arbor ships with (F64).
#
#   scripts/mac-shell/run.sh --priority 2 --no-preflight "real apps: the fake Mac has none" scripts/mac-shell/app-sizes.sh
#   scripts/mac-shell/run.sh --on macos-15 …                          the same on another macOS: a table for each
#
# THE QUESTION ONLY A MAC CAN ANSWER: asked through Accessibility for 40×40 and for 3200×2400, what does the first ordinary window of each app
# take? Nothing else tells: minimum and maximum sizes cannot be read, only met. Arbor is not started.
#
# Each app in turn is opened in the background, whatever first-run sheet is in the way is dismissed, its first standard window is asked
# (apptool limits, which puts it back), and the app is quit. One app that fails does not stop the next. About eight seconds an app.
#
# What comes back: mac-shell/app-sizes.tsv, a line for each app:
#     bundle id, the app's version, macOS's version, the display's size, verdict, smallest w×h, largest w×h, what else `limits` said
# No titles, and nothing of what is in a window. The verdict is `clean`, or why the line is not fit for the table: `no-window` (none that
# is standard within the wait), `in-the-way` (a sheet or a dialog stayed: a window with a sheet open goes less small than it does
# without), `absent` (not on this Mac). scripts/app-sizes.py makes the table of the clean ones.
#
# Only on one of GitHub's Macs: it opens three dozen apps for the first time, and quits them.
ARBOR_TIME_LIMIT=${ARBOR_TIME_LIMIT:-900}
source "$(dirname "${BASH_SOURCE[0]}")/lib-apps.sh"
needs_throwaway_mac "open three dozen apps, each for the first time, and quit them"

# Stop opening apps after this many seconds, and say which were not reached.
SIZES_BUDGET=${SIZES_BUDGET:-540}
TABLE="$ARBOR_OUT/app-sizes.tsv"

# What a person may want to dock, of what comes with macOS, and the browsers of other makers that GitHub's Macs happen to have: a browser is the window
# most people dock first. Not: what has no ordinary window (Stickies, Digital Color Meter, Screenshot), what asks for a
# camera or a microphone at once (FaceTime, Photo Booth), what would change the Mac (Migration Assistant, Boot Camp Assistant, installers).
# `bundle id` or `bundle id=what to open with it` (a name in $APPS_SCRATCH). Those most used first: the time may run out.
APPS="
com.apple.finder=grove com.apple.Safari=page.html com.google.Chrome=page.html org.mozilla.firefox=page.html com.microsoft.edgemac=page.html com.apple.mail com.apple.Notes com.apple.iCal com.apple.MobileSMS com.apple.Terminal
com.apple.systempreferences com.apple.Preview=leaf.png com.apple.TextEdit=oak.txt com.apple.Music com.apple.Photos com.apple.reminders
com.apple.Maps com.apple.AddressBook com.apple.AppStore com.apple.calculator com.apple.ActivityMonitor com.apple.podcasts com.apple.TV
com.apple.iBooksX com.apple.news com.apple.stocks com.apple.weather com.apple.Home com.apple.VoiceMemos com.apple.freeform
com.apple.clock com.apple.shortcuts com.apple.Dictionary com.apple.FontBook com.apple.Console com.apple.DiskUtility
com.apple.ScriptEditor2=hello.applescript com.apple.SystemProfiler com.apple.Passwords com.apple.findmy com.apple.Automator
com.apple.ColorSyncUtility com.apple.dt.Xcode
"

# Only the view through Accessibility is needed: no Arbor, no pointer.
tool_build() {
  mkdir -p "$(dirname "$ARBOR_APPTOOL")"
  swiftc -swift-version 5 "$ARBOR_ROOT/scripts/mac-shell/apptool.swift" -o "$ARBOR_APPTOOL" > "$ARBOR_OUT/build-apptool.log" 2>&1 \
    || { grep -A 6 "error:" "$ARBOR_OUT/build-apptool.log" | head -n 80; die "scripts/mac-shell/apptool.swift did not compile"; }
}

# Where an app is, by its bundle id; nothing when it is not on this Mac.
path_of() { mdfind "kMDItemCFBundleIdentifier == '$1'" 2>/dev/null | grep -E '^(/System)?/Applications/' | head -n 1; }

version_of() { defaults read "$1/Contents/Info" CFBundleShortVersionString 2>/dev/null || echo "?"; }

row() { printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$@" >> "$TABLE"; }

measure() {
  local bundle=${1%%=*} with="" where version verdict=clean limits small large
  case "$1" in *=*) with="$APPS_SCRATCH/${1#*=}" ;; esac
  step "$bundle"
  where=$(path_of "$bundle")
  # Finder lives elsewhere, and is on every Mac.
  [ "$bundle" = com.apple.finder ] && where=/System/Library/CoreServices/Finder.app
  if [ -z "$where" ]; then
    echo "not on this Mac"
    row "$bundle" "?" "$MACOS" "$DISPLAY_SIZE" absent - - -
    return 0
  fi
  version=$(version_of "$where")
  APP_WAIT=20
  [ "$bundle" = com.apple.dt.Xcode ] && APP_WAIT=40
  # shellcheck disable=SC2086
  app_open "$bundle" $with
  if [ -z "$APP_WINDOW" ]; then
    # What is in the way may be all there is: once it is gone the window comes.
    [ -n "$APP_PID" ] && app_dismiss "$APP_PID" && app_await_window "$APP_PID" "" 6 && APP_WINDOW=$NEW_WINDOW
  fi
  if [ -z "$APP_WINDOW" ]; then
    [ -n "$APP_PID" ] && apptool windows "$APP_PID" 2>/dev/null | cut -d ' ' -f 1-8 | sed 's/^/  /'
    row "$bundle" "$version" "$MACOS" "$DISPLAY_SIZE" no-window - - -
  else
    app_dismiss "$APP_PID" || verdict=in-the-way
    apptool windows "$APP_PID" 2>/dev/null | grep -Eq "sheets=|AXDialog|AXSystemDialog" && verdict=in-the-way
    limits=$(bounded 20 "$ARBOR_APPTOOL" limits "$APP_WINDOW")
    echo "limits: $limits"
    small=$(echo "$limits" | awk '$1 == "min" { print $2 }')
    large=$(echo "$limits" | awk '$3 == "max" { print $4 }')
    [ -n "$small" ] && [ -n "$large" ] || { verdict=no-answer small=- large=-; }
    row "$bundle" "$version" "$MACOS" "$DISPLAY_SIZE" "$verdict" "$small" "$large" "$(echo "$limits" | cut -d ' ' -f 5-)"
  fi
  # Finder cannot be quit for good, and its window is this script's own folder.
  if [ "$bundle" = com.apple.finder ]; then
    [ -n "$APP_WINDOW" ] && apptool close "$APP_WINDOW" > /dev/null 2>&1
    apps_forget "$APP_PID"
  else
    app_quit "$APP_PID"
  fi
}

apps_watchdog $((SIZES_BUDGET + 240))
tool_build
apps_scratch
echo "display modes (w h pixel-w pixel-h): $(apptool modes | tr '\n' ';')"
# As large as there is: the display is what stops a window that can grow for ever, and a largest size says something only where it is well below it.
apptool set-mode 1920 1080 2>/dev/null || apptool set-mode 1680 1050 2>/dev/null || apptool set-mode 1440 900 2>/dev/null
sleep 2
MACOS=$(sw_vers -productVersion)
DISPLAY_SIZE=$(apptool modes | awk '/\*/ { print $1 "x" $2; exit }')
[ -n "$DISPLAY_SIZE" ] || DISPLAY_SIZE="?"
echo "macOS $MACOS, display $DISPLAY_SIZE"
printf '# bundle\tversion\tmacOS\tdisplay\tverdict\tsmallest\tlargest\tnotes\n' > "$TABLE"

for app in $APPS; do
  if [ "$SECONDS" -gt "$SIZES_BUDGET" ]; then
    row "${app%%=*}" "?" "$MACOS" "$DISPLAY_SIZE" out-of-time - - -
    continue
  fi
  began=$SECONDS
  measure "$app"
  echo "${app%%=*}: $((SECONDS - began)) s"
done

step "the table"
cat "$TABLE"
clean=$(awk -F '\t' '$5 == "clean"' "$TABLE" | wc -l | tr -d ' ')
check "at least twenty apps were measured with nothing in the way ($clean)" test "$clean" -ge 20
