#!/bin/bash
# Settings from the command line: set, get, settings, reset, bind, unbind and rule, what they refuse and why, what they
# leave of the file a person wrote, and the file applied as it is saved. Then a second copy of Arbor on the same home folder.
# A17 every setting is scriptable and checked, A03 configurable shortcuts (saved in the file), A13 only one Arbor at a time.
source "$(dirname "$0")/../lib.sh"
arbor_build

# How far the window docked at the left edge is from it, as the window server sees it. (at_edge goes by the gap that
# arbor_settings was last given, which knows nothing of a command or an editor.)
inset_is() {
  local x left
  x=$(real_frame_of "$W1" | awk '{ print int($1) }')
  left=$(screen_of 1 | awk '{ print int($1) }')
  about "$((x - left))" "$1" 1 > /dev/null || { echo "it starts $((x - left)) points from the edge, not $1"; return 1; }
}
setting_is() {
  local value
  value=$("$ARBOR_BIN/arborctl" get "$1")
  [ "$value" = "$2" ] || { echo "$1 is $value, not $2"; return 1; }
}
file_is() { [ "$(cat "$file")" = "$1" ] || { echo "the file is: $(head -c 200 "$file")"; return 1; }; }
# On the session's home folder and windows, without a dialog, and stopped should it stay.
second_copy() {
  local quiet="ARBOR_NO_PROMPT=1 ARBOR_NO_HOTKEYS=1 ARBOR_NO_STATUS_ITEM=1"
  # shellcheck disable=SC2086
  limit 10 env ARBOR_ONLY_PIDS="$ARBOR_WINDOWS_PID" ARBOR_NO_WATCHDOG=1 $quiet "$ARBOR_BIN/Arbor"
}

# A file somebody has worked on: a key Arbor does not know, spacing and an order of their own. Written here and not by arbor_settings, which
# writes it anew in its own spacing. With the mark of a file that holds only what somebody chose, which a launch leaves as it is, and the whole map of
# shortcuts, which arbor_settings would have put under it: ⌃⌥D is unbound below.
printf '%s\n' '{"format": 2, "shortcuts": "all", "noteToSelf": "narrower?",   "gap": 12, "tabsEnabled": false}' > "$ARBOR_HOME/settings.json"
arbor_start 2 ARBOR_NO_HOTKEYS=0
file="$ARBOR_HOME/settings.json"
ctl dock "$W1" left
ctl dock "$W2" right
summary

claim "set the gap by command: the windows are laid out again at once, and settings.json has it"
proves A17
check "the docked window starts 12 points from the edge" eventually inset_is 12
check "set gap 16 says what changed" says "gap = 16 (was 12)" arborctl set gap 16
check "the docked window starts 16 points from the edge" eventually inset_is 16
check "the rest of the file is as the person wrote it" file_is '{"format": 2, "shortcuts": "all", "noteToSelf": "narrower?",   "gap": 16, "tabsEnabled": false}'
check "get gap prints it" setting_is gap 16
check "keys ignore case" setting_is GAP 16
check "Arbor does not take its own save for somebody's edit" stays fails logged "settings.json read and applied"
settled

claim "list the settings by command: every key with its value, its range and its default"
proves A17
"$ARBOR_BIN/arborctl" settings > "$ARBOR_SESSION_DIR/settings"
check "the gap, as it is now" grep -q "gap = 16  (0 to 100 pt; default 12)" "$ARBOR_SESSION_DIR/settings"
check "marked as changed" grep -q "^\* *gap = 16" "$ARBOR_SESSION_DIR/settings"
check "a switch" grep -q "focusRing = true  (true or false; default true)" "$ARBOR_SESSION_DIR/settings"
check "a choice" grep -q "stepInToward = auto  (auto or pointer or focus; default auto)" "$ARBOR_SESSION_DIR/settings"
check "a setting left alone is not marked" fails grep -q "^\* *focusRing = " "$ARBOR_SESSION_DIR/settings"

claim "set a value out of range by command: it is refused with the range, and nothing changes"
proves A17
check "set gap 500 exits with 1" exits_with 1 arborctl set gap 500
check "it says what the range is" says "\`gap\` must be from 0 to 100 pt, got 500" arborctl set gap 500
check "a word for a number is refused too" says "\`gap\` needs a number from 0 to 100 pt" arborctl set gap wide
check "and a number for a switch" says "\`tabsEnabled\` is true or false" arborctl set tabsEnabled 7
check "the gap in use stays" setting_is gap 16
check "the docked window stays" stays inset_is 16
check "the file stays" file_is '{"format": 2, "shortcuts": "all", "noteToSelf": "narrower?",   "gap": 16, "tabsEnabled": false}'

claim "misspell a setting by command: Arbor asks whether the nearest one was meant"
proves A17
check "set gpa 10 exits with 1" exits_with 1 arborctl set gpa 10
check "it suggests gap" says "unknown setting \`gpa\`; did you mean \`gap\`?" arborctl set gpa 10
check "get does the same" says "did you mean \`focusRing\`?" arborctl get focusRign
check "and so does reset" says "did you mean \`tabsEnabled\`?" arborctl reset tabEnabled
check "the gap in use stays" setting_is gap 16

claim "reset a setting by command: the default is back and the windows are laid out again"
proves A17
check "reset gap says what changed" says "gap = 12, the default (was 16)" arborctl reset gap
check "the docked window starts 12 points from the edge" eventually inset_is 12
check "the person's own key is still in the file" grep -q '"noteToSelf": "narrower?"' "$file"
check "resetting it again changes nothing and says so" says "already the default" arborctl reset gap
settled

claim "bind a shortcut to a command that changes a setting, by command, and press it"
proves A17
click_window "$W1"
keys=$(events_of "$W1" key)
key_to "$W1" ctrl+opt+cmd+g
check "before, ⌃⌥⌘G goes to the app in front" eventually received "$W1" key -gt "$keys"
check "bind succeeds" ctl bind ctrl+opt+cmd+g set gap 30
check "settings.json has the shortcut" grep -q '"ctrl+opt+cmd+g" *: *"set gap 30"' "$file"
keys=$(events_of "$W1" key)
key_to "$W1" ctrl+opt+cmd+g
# Commands that change settings are logged by what they changed.
check "now ⌃⌥⌘G reaches Arbor" eventually logged "settings: gap = 30 (was 12)"
check "and not the app" received "$W1" key -eq "$keys"
check "the docked window starts 30 points from the edge" eventually inset_is 30
check "arborctl bindings lists it" says "ctrl+opt+cmd+g" arborctl bindings
ctl reset gap
settled

claim "unbind a default shortcut by command: the key goes to the app in front, and reset bindings brings it back"
proves A17
check "unbind succeeds" ctl unbind ctrl+opt+d
check "settings.json has null for it" grep -q '"ctrl+opt+d" *: *null' "$file"
keys=$(events_of "$W1" key)
key_to "$W1" ctrl+opt+d
check "⌃⌥D does not reach Arbor" stays fails ran desktop
check "the app with the keyboard gets the key" eventually received "$W1" key -gt "$keys"
check "reset bindings succeeds" ctl reset bindings
check "⌃⌥D shows the Desktop again" pressed ctrl+opt+d desktop
check "the docked window is out of view" eventually out_of_view "$W1"
check "the shortcut bound before is gone with the rest" fails says "ctrl+opt+cmd+g" arborctl bindings
ctl show-all
settled

claim "bind what cannot work, by command: it is refused with the reason"
proves A17
check "a key that is needed for typing" says "needs ctrl, opt or cmd" arborctl bind x quit
check "a command there is none of" says "unknown command \`frobnicate\`" arborctl bind ctrl+opt+cmd+j frobnicate
check "a setting out of range inside a shortcut" says "must be from 0 to 100 pt" arborctl bind ctrl+opt+cmd+j set gap 500
check "each exits with 1" exits_with 1 arborctl bind x quit
check "no shortcut was added" setting_is bindings "{}"

claim "add a rule by command and open a window that matches: it docks as the rule says"
proves A17
check "rule add succeeds" ctl rule add "$ARBOR_TEST_BUNDLE" dock top title Build log
check "settings.json has the rule" grep -q '"title" *: *"Build log"' "$file"
open_window N1 size=400x300 title=Build log of today
check "the new window is docked" eventually is docked "$N1"
check "at the top edge" eventually at_edge "$N1" top
check "an action there is none of is refused with the ones there are" says "expected float, ignore, pin, dock" \
  arborctl rule add "$ARBOR_TEST_BUNDLE" sideways
check "no part of a title is in the log" fails grep -q "Build log" "$ARBOR_HOME/arbor.log"
settled

claim "remove the rule by command: the next window of the kind floats"
proves A17
check "rule remove succeeds" ctl rule remove 1
check "no rule is left" setting_is rules "[]"
open_window N2 size=300x200 title=Build log of tomorrow
check "Arbor arranges the new window" eventually is managed "$N2"
check "it floats" stays is floating "$N2"
tw close "$N1"
forget_window "$N1"
tw close "$N2"
forget_window "$N2"
settled

claim "save settings.json from an editor: it applies as it is saved, without a command"
proves A17
# As most editors save: a new file moved over the old one.
printf '{"gap": 24}\n' > "$file.new" && mv "$file.new" "$file"
check "a file moved over the old one: the docked window starts 24 points from the edge" eventually inset_is 24
check "Arbor says so too" setting_is gap 24
# As others do, and the shell: into the file where it is, which by now is not the file Arbor started with.
printf '{"gap": 8}\n' > "$file"
check "written in place: the docked window starts 8 points from the edge" eventually inset_is 8
settled

claim "a slip in settings.json costs one key, never the file"
proves A17
printf '{"gap": "wide", "focusRingWidth": 400, "minimumUsableHeight": 150}\n' > "$file"
check "the key after the slip is applied" eventually setting_is minimumUsableHeight 150
check "a value of the wrong type gives way to the default" eventually inset_is 12
check "a number out of range moves to the nearest end" setting_is focusRingWidth 12
check "settings lists what Arbor could not use as written" says "could not use as written" arborctl settings
check "the gap among it" says "  gap: not " arborctl settings
check "the file is left as the person wrote it" file_is '{"gap": "wide", "focusRingWidth": 400, "minimumUsableHeight": 150}'
settled

claim "while settings.json cannot be read, a command that would save over it is refused"
proves A17
printf '{"gap": 60,, "rules": [' > "$file"
check "the settings in use stay" stays inset_is 12
check "set exits with 1" exits_with 1 arborctl set gap 20
check "it says that nothing was changed, and the way out" says "so nothing was changed" arborctl set gap 20
check "bind is refused too" fails ctl bind ctrl+opt+cmd+g set gap 30
check "the unfinished edit is still in the file" file_is '{"gap": 60,, "rules": ['
printf '{"gap": 28}\n' > "$file"
check "mended, it applies" eventually inset_is 28
check "and set works again" ctl set gap 12
check "the docked window starts 12 points from the edge" eventually inset_is 12
settled

claim "save a shortcut in settings.json from an editor: it works without a reload, the menu shows it, and taken out again it is gone"
proves A03 A17
check "before, ⌃⌥⌘H is no shortcut of Arbor's" fails says "ctrl+opt+cmd+h" arborctl bindings
# A command that moves no window: the claims after this one go by where the windows are.
printf '{"gap": 12, "bindings": {"ctrl+opt+cmd+h": "show-all"}}\n' > "$file"
check "arborctl bindings lists it" eventually says "ctrl+opt+cmd+h" arborctl bindings
check "⌃⌥⌘H runs show-all" pressed ctrl+opt+cmd+h show-all
check "the menu shows the keys beside Show Everything" says "Show Everything  ⌃⌥⌘H" arborctl menu
printf '{"gap": 12}\n' > "$file"
check "taken out of the file, it is no longer listed" eventually fails says "ctrl+opt+cmd+h" arborctl bindings
check "and the menu shows the default again" says "Show Everything  ⌃⌥Space" arborctl menu
settled

claim "start a second copy of Arbor on the same home folder: it explains itself and leaves, and the first goes on"
proves A13
first=$(real_frame_of "$W1")
words=$(second_copy 2>&1)
code=$?
echo "$words"
check "it exits with code 75" test "$code" -eq 75
check "it says that Arbor is running already" says "Arbor is already running" echo "$words"
check "and where to find it" says "the icon in the menu bar" echo "$words"
check "the log has who stayed and who left" logged "already runs from"
check "the first copy is still running" kill -0 "$ARBOR_PID"
check "it still answers" says "running" arborctl status
# shellcheck disable=SC2086
check "no window moved" stays frame_is "$W1" $first
# One of the nine: the files written by hand since say nothing of the whole map.
click_window "$W2"
check "its shortcuts still work" pressed ctrl+opt+return zoom
check "the other docked window is out of view" eventually out_of_view "$W1"
check "⌃⌥Space brings it back" pressed ctrl+opt+space show-all
settled

arbor_stop
