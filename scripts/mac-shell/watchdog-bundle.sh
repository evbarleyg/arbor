#!/bin/bash
# Does the watchdog bring back a *bundled* Arbor? arbor-e2e covers the bare executable, which the watchdog
# starts again itself. An app bundle it starts through `open -n --env …`, so that macOS attributes the
# Accessibility permission to the app and not to a child of a process that no longer exists. This
# wraps the debug build in a bundle, launches it the way Finder would, and kills it.
#
#   scripts/mac-shell/run.sh scripts/mac-shell/watchdog-bundle.sh
#
# A bundle launched by Launch Services answers for its own permissions, and nobody has granted this
# one any, so Arbor may only get as far as "waiting for Accessibility permission". That is enough: what is
# being tried is who starts whom, with which environment. The status line printed says which it was.
#
# Safe on a person's Mac: it changes no setting, arranges no window (ARBOR_ONLY_PIDS=1), uses its own home
# folder and bundle identifier, and ends only processes it started.
source "$(dirname "$0")/lib.sh"

swift build --product Arbor > "$ARBOR_OUT/build.log" 2>&1 && swift build --product arborctl >> "$ARBOR_OUT/build.log" 2>&1 \
  || { tail -n 30 "$ARBOR_OUT/build.log"; die "swift build failed"; }

app="$ARBOR_SESSION_DIR/Arbor.app"
mkdir -p "$app/Contents/MacOS"
cp "$ARBOR_BIN/Arbor" "$app/Contents/MacOS/Arbor"
cp Resources/Info.plist "$app/Contents/Info.plist"
# Safe beside an installed Arbor: another identifier, so that macOS keeps the two apart, and no claim on arbor://
# URLs, which Launch Services would otherwise hand to a bundle that is deleted a minute later.
# safe anywhere: it edits the copy of Info.plist in this run's temporary folder
/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier com.evbarleyg.arbor.watchdog-check" \
  -c "Delete :CFBundleURLTypes" "$app/Contents/Info.plist" || die "could not edit Info.plist"
codesign --force --sign - --identifier com.evbarleyg.arbor.watchdog-check "$app" || die "codesign failed"

holder() { cat "$ARBOR_HOME/arbor.lock" 2>/dev/null; }
alive() { [ -n "$1" ] && kill -0 "$1" 2>/dev/null; }
answers() { "$ARBOR_BIN/arborctl" status > /dev/null 2>&1; }
# Another Arbor than $1 holds the lock and answers on the same socket.
replaced() { local now; now=$(holder); [ "$now" != "$1" ] && alive "$now" && answers; }
gone() { ! alive "$(holder)" && ! answers; }
# Only this bundle's: an installed Arbor has a watchdog too. (By the folder's name: /tmp is /private/tmp to some.)
watchdogs() {
  [ "$(pgrep -f "$(basename "$ARBOR_SESSION_DIR")/Arbor.app/Contents/MacOS/Arbor --watchdog" | wc -l | tr -d ' ')" = "$1" ]
}
patiently() { eventually "$@" || eventually "$@" || eventually "$@" || eventually "$@"; }
logged() { grep -q "$1" "$ARBOR_HOME/arbor.log"; }

launch() {
  # The bundle arranges no window and uses its own home folder. Launch Services forgets a bundle that is gone.
  # safe anywhere: a bundle this run just made, under an identifier of its own that handles no URL or document
  open -n --env "ARBOR_HOME=$ARBOR_HOME" --env "ARBOR_SOCKET=$ARBOR_SOCKET" --env ARBOR_NO_PROMPT=1 \
    --env ARBOR_NO_STATUS_ITEM=1 --env ARBOR_NO_HOTKEYS=1 --env ARBOR_ONLY_PIDS=1 --env ARBOR_DEBUG=1 "$app"
}

step "launch the bundle through Launch Services"
launch
check "Arbor answers on the socket in the home folder it was given" patiently answers
"$ARBOR_BIN/arborctl" status
first=$(holder)
check "one watchdog is running" eventually watchdogs 1

step "a second copy of the bundle"
launch
sleep 3
check "the first copy still holds the lock" test "$(holder)" = "$first"
check "the second copy said why it left" logged "already runs from"
check "there is still one watchdog" eventually watchdogs 1

step "kill -9"
kill -9 "$first"
check "another Arbor took over, with the same home folder and socket" patiently replaced "$first"
"$ARBOR_BIN/arborctl" status
second=$(holder)
check "the watchdog said so" logged "ended without quitting; starting it again"
check "the new Arbor has a watchdog of its own, and the old one has left" eventually watchdogs 1
check "it runs from the bundle" sh -c "ps -o command= -p $second | grep -q 'Arbor.app/Contents/MacOS/Arbor'"

step "kill -9 twice more: a rescue, then nothing"
kill -9 "$second"
check "Arbor is started a second time" patiently replaced "$second"
third=$(holder)
kill -9 "$third"
check "the third start is a rescue" patiently logged "rescue:"
check "and then Arbor stays away" patiently gone
sleep 2
check "for good" gone
check "no watchdog is left" eventually watchdogs 0

step "a clean quit"
launch
check "Arbor answers" patiently answers
ctl quit
check "Arbor leaves" patiently gone
sleep 2
check "and is not started again" gone
check "no watchdog is left" eventually watchdogs 0

echo
echo "--- arbor.log"
cat "$ARBOR_HOME/arbor.log"
arbor_log
