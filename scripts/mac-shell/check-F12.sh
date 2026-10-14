#!/bin/bash
# F12 (settings as commands, and settings.json applied as it is saved) on a real Mac:
#
#   scripts/mac-shell/run.sh scripts/mac-shell/check-F12.sh
#
# The commands are covered by tests; what only a Mac can show is the part that watches the file
# (App/SettingsWatcher.swift). So this saves settings.json the ways real tools do (moved over the old
# file, written in place, sed -i, deleted and made again) and looks at where the window server has a docked
# window afterwards. It also breaks the file, to see that nothing moves, nothing is saved over it, and the
# log says so once.
source "$(dirname "$0")/lib.sh"

not() { ! "$@"; }

setting_is() { [ "$("$ARBOR_BIN/arborctl" get "$1")" = "$2" ]; }
gap_is() { setting_is gap "$1"; }

# Whether W1, docked at the left edge, starts that many points from it, as the window server sees it.
inset_is() {
  local x rest sx
  read -r x rest <<< "$(real_frame_of "$W1")"
  read -r sx rest <<< "$(arbor_ask screen)"
  [ "${x%.*}" -eq $((sx + $1)) ]
}

# How often the log has a line with this text.
logged() { grep -c "$1" "$ARBOR_HOME/arbor.log"; }

# noticed <gap>: Arbor uses that gap and the real window has moved, without any command.
noticed() {
  check "Arbor uses gap $1" eventually gap_is "$1"
  check "the real window starts $1 points from the edge" eventually inset_is "$1"
}

arbor_build
arbor_start 3
file="$ARBOR_HOME/settings.json"
ctl dock "$W1" left
ctl dock "$W2" right
check "the window starts at the default gap" eventually inset_is 12

step "set moves real windows at once and saves"
ctl set gap 40
check "the real window starts 40 points from the edge" eventually inset_is 40
check "settings.json has the new gap" grep -Eq '"gap" ?: ?40' "$file"
ctl get gap
ctl set gap 500
check "a value out of range is refused" not "$ARBOR_BIN/arborctl" set gap 500
check "and changes nothing" gap_is 40
ctl set gpa 10
ctl settings | head -n 12
sleep 1
check "Arbor did not read its own write back in" [ "$(logged "settings.json read and applied")" -eq 0 ]

step "a new file moved over the old one, as most editors save"
printf '{"gap": 24}\n' > "$file.new" && mv "$file.new" "$file"
noticed 24

step "written in place, as VS Code, nano and the shell do (into the file that has just replaced the old one)"
printf '{"gap": 8}\n' > "$file"
noticed 8

step "sed -i"
sed -i '' 's/8/32/' "$file"
noticed 32

step "python, in place"
python3 -c 'import sys; open(sys.argv[1], "w").write("{\"gap\": 16, \"noteToSelf\": \"hello\"}")' "$file"
noticed 16
ctl set tabsEnabled true
check "a command leaves the rest of the file as it was written" \
  [ "$(cat "$file")" = '{"gap": 16, "noteToSelf": "hello", "tabsEnabled": true}' ]

step "a file that is not JSON changes nothing, is reported once, and is not saved over"
applied=$(logged "settings.json read and applied")
printf '{"gap": 60,, "rules": [' > "$file"
sleep 1
check "the gap in use stays" gap_is 16
check "the real window stays" inset_is 16
printf '{"gap": 60,, "rules": [' > "$file"
sleep 1
touch "$file"
sleep 1
check "the log says so once" [ "$(logged "settings.json cannot be read, keeping")" -eq 1 ]
grep "cannot be read" "$ARBOR_HOME/arbor.log"
ctl set gap 20
check "set is refused" not "$ARBOR_BIN/arborctl" set gap 20
check "reload-settings fails" not "$ARBOR_BIN/arborctl" reload-settings
check "the unfinished edit is still in the file" [ "$(cat "$file")" = '{"gap": 60,, "rules": [' ]
check "nothing was applied meanwhile" [ "$(logged "settings.json read and applied")" -eq "$applied" ]

step "mended, it applies"
printf '{"gap": 28}\n' > "$file"
noticed 28
check "set works again" "$ARBOR_BIN/arborctl" set tabsEnabled true

step "numbers out of range in the file are moved into it"
printf '{"gap": -500, "windowEdgeFraction": 7, "pinchThreshold": "far"}\n' > "$file"
noticed 0
ctl settings | tail -n 5
# With this one every space is too small to use, so the windows give way to tiles; Arbor must still answer.
printf '{"gap": -500, "minimumUsableWidth": 1e9}\n' > "$file"
check "the smallest usable width stops at the end of its range" eventually setting_is minimumUsableWidth 1000
ctl ascii

step "deleted: nothing happens; the next save makes a new file, which is watched too"
rm "$file"
sleep 1
check "the gap in use stays" gap_is 0
check "no file was written" not test -e "$file"
ctl set gap 36
check "set wrote a new file" test -s "$file"
printf '{"gap": 12}\n' > "$file"
noticed 12

step "the other files in the folder cost nothing"
applied=$(logged "settings.json read and applied")
for edge in top bottom top bottom; do
  ctl dock "$W3" "$edge" > /dev/null
  sleep 0.7
done
check "state.json was saved meanwhile" test -s "$ARBOR_HOME/state.json"
check "settings.json was not applied again" [ "$(logged "settings.json read and applied")" -eq "$applied" ]

step "shortcuts and rules by command"
ctl bind ctrl+opt+h dock left
ctl unbind ctrl+opt+d
ctl rule add com.apple.Terminal dock right title Build log
ctl get bindings
ctl get rules
check "no part of a title is in the log" not grep -q "Build log" "$ARBOR_HOME/arbor.log"
cat "$file"
ctl reset everything
check "everything is back to the default" setting_is rules "[]"

arbor_stop
