#!/bin/bash
# F12, the settings window, on a real Mac: every pane in light and in dark, and what only a Mac can settle about it.
#
#   scripts/mac-shell/run.sh scripts/mac-shell/shots-F12.sh          (one of GitHub's Macs)
#   scripts/mac-shell/shots-F12.sh                                   (this Mac)
#
# What the window shows and what a click means is covered by tests of SettingsPanelModel. This looks at the rest: does
# it open in front and take the keyboard, from the command and from ⌃⌥,; does it stay above tiles and gap handles; do typed
# values, the slider, a switch and a recorded shortcut reach Arbor; do Arbor's own shortcuts and ⌘-chords reach the recorder;
# who has the keyboard after ⌘W. And it takes the pictures somebody has to LOOK at.
#
# On a person's own Mac: it uses its own test windows and a temporary ARBOR_HOME, and changes no setting of the system (dark
# comes from ARBOR_APPEARANCE, which concerns this Arbor alone). It moves the pointer and presses keys, so hands off; lib.sh
# declines a press or a key that would reach anything the script did not start, and `press` below declines a point
# outside the settings window. The pictures `wshot` takes are of Arbor's settings window alone, which shows this script's settings and
# nobody else's; the three of the whole screen (`shot`) are taken on throwaway Macs only, so leave ARBOR_SHOTS alone. It never opens the menus that
# list running apps, never clicks Open the File (that would start the person's editor), and the shortcuts it presses
# (⌃⌥⇧F6, F8 and F9, and once ⌃⌥,) are no default of Arbor's but the last, in case an installed Arbor is running too. A beep is
# to be expected: Arbor beeps when settings.json breaks.
source "$(dirname "$0")/lib.sh"

AXFIND="$ARBOR_ROOT/.build/mac-shell/axfind"
TITLE="Arbor Settings"

not() { ! "$@"; }
ax() { "$AXFIND" "$ARBOR_PID" "$@"; }
shows() { ax point "$@" > /dev/null 2>&1; }
setting_is() { [ "$("$ARBOR_BIN/arborctl" get "$1")" = "$2" ]; }
field_is() { [ "$(ax value AXTextField "$1" 2> /dev/null)" = "$2" ]; }
# runs <shortcut> <command>: whether `bindings` has that line.
runs() {
  "$ARBOR_BIN/arborctl" bindings | awk -v chord="$1" -v command="$2" '
    $1 == chord { $1 = ""; $2 = ""; sub(/^ +/, ""); if ($0 == command) found = 1 }
    END { exit !found }'
}
has_rule() { "$ARBOR_BIN/arborctl" rules | grep -Fq "$1"; }
window_count() { state | python3 -c 'import json, sys; print(len(json.load(sys.stdin)["windows"]))'; }
window_is_open() { ax window "$TITLE" > /dev/null 2>&1; }
front_pid() { pointer front 2> /dev/null; }
front_is() { [ "$(front_pid)" = "$1" ]; }
level_is() { [ "$(overlays | awk -v id="$(ax window "$TITLE")" '$1 == id { print $3 }')" = "$1" ]; }

# Whether W1, docked at the left edge, starts that many points from it, as the window server sees it.
inset_is() {
  local x rest sx
  read -r x rest <<< "$(real_frame_of "$W1")"
  read -r sx rest <<< "$(arbor_ask screen)"
  [ "${x%.*}" -eq $((sx + $1)) ]
}

# press <role> <identifier or text>: a real click on that control, if it is in the window and in view. A form scrolls, and
# what is scrolled out of view still has a place, which may lie outside the window, over something else.
press() {
  local where
  where=$(ax point "$@" 2> /dev/null) || { echo "  no $* to press"; return 1; }
  # shellcheck disable=SC2086
  if ! inside "${where% *} ${where#* } 0 0" "$(ax frame AXWindow "$TITLE")"; then
    echo "  $* is at $where, outside the window: not pressed"
    return 1
  fi
  # shellcheck disable=SC2086
  click $where
}

# A switch's element may be the switch alone or its whole line with the label, so the click goes to its right end.
press_switch() {
  local x y w h
  read -r x y w h <<< "$(ax frame - "$1" 2> /dev/null)"
  [ -n "${h:-}" ] || { echo "  no switch $1 to press"; return 1; }
  inside "$x $y $w $h" "$(ax frame AXWindow "$TITLE")" || { echo "  the switch $1 is not in view: not pressed"; return 1; }
  click $((x + w - 14)) $((y + h / 2))
}

# Types digits and small letters, one key at a time.
type_text() {
  local index
  for ((index = 0; index < ${#1}; index++)); do key "${1:index:1}" > /dev/null || return 1; done
  echo "> typed $1"
}

# enter <field> <text>: replaces what is in a field and presses Return.
enter() {
  press AXTextField "$1" && key cmd+a && type_text "$2" && key return
}

# A picture of the settings window alone, so it is taken on anybody's Mac: nothing else that is open is in it (behind the
# sidebar's frosted glass are this script's test windows, which fill the display).
wshot() {
  local id log="$ARBOR_OUT/window-pictures.log"
  sleep "${ARBOR_SETTLE:-0.7}"
  id=$(ax window "$TITLE" 2> /dev/null) || { echo "wshot $1: there is no settings window"; return 1; }
  # safe anywhere: -l takes one window by its number, Arbor's own, and nothing of what lies around it
  if ! screencapture -x -o "-l$id" "$ARBOR_OUT/$1.png" 2>> "$log" || [ ! -s "$ARBOR_OUT/$1.png" ]; then
    echo "wshot $1: no picture ($(tail -n 1 "$log"))"
    return 1
  fi
  arbor_finish_shot "$1"
}

# The window as text: every control with its place and value. Without the menus' items, which name running apps.
tree() { ax tree | grep -v AXMenuItem > "$ARBOR_OUT/$1.txt"; }

SETTINGS='{
  "focusRing": false,
  "bindings": { "ctrl+opt+shift+f9": "desktop", "ctrl+opt+shift+f6": "set gap 0", "ctrl+opt+d": null },
  "rules": [
    { "app": "com.example.mail", "title": "Inbox", "action": "dock left" },
    { "app": "com.example.terminal", "action": "dock beside com.example.mail bottom" },
    { "app": "com.example.player", "action": "float" },
    { "app": "com.example.palette", "action": "ignore" }
  ],
  "excludedBundleIDs": ["com.example.music", "com.example.game"]
}'

# session <light|dark>: three columns of test windows and the settings window over them.
session() {
  arbor_settings "$SETTINGS"
  arbor_start 3 ARBOR_NO_HOTKEYS=0 "ARBOR_APPEARANCE=$1"
  ctl dock "$W1" left
  ctl dock "$W2" right
  ctl dock "$W3" right
  ctl settings-window
  check "the settings window opens" eventually window_is_open
}

# panes <prefix>: a picture and the text of each pane. A section with nothing to show is no pane, and is refused.
panes() {
  local pane
  for pane in general windows dragging tabs gestures appearance menu-bar scripting shortcuts rules apps; do
    "$ARBOR_BIN/arborctl" settings-window "$pane" > /dev/null 2>&1 || continue
    wshot "$1-$pane"
    tree "$1-$pane"
  done
}

arbor_build
swiftc -O -swift-version 5 "$ARBOR_ROOT/scripts/mac-shell/axfind.swift" -o "$AXFIND" > "$ARBOR_OUT/build-axfind.log" 2>&1 \
  || { cat "$ARBOR_OUT/build-axfind.log"; die "scripts/mac-shell/axfind.swift did not compile"; }

step "light: the window opens in front, with the keyboard, above Arbor's own panels"
session light
check "Arbor is the app in front" eventually front_is "$ARBOR_PID"
check "the window floats while it has the keyboard" eventually level_is 3
check "Arbor knows three windows, not its own" [ "$(window_count)" -eq 3 ]
shot 01-over-three-columns

step "light: every pane"
panes light

step "Advanced opens"
ctl settings-window windows
check "arrangeDesktopWeight is behind Advanced" not shows AXTextField arrangeDesktopWeight.field
press AXDisclosureTriangle ""
check "and shows after a click on the triangle" eventually shows AXTextField arrangeDesktopWeight.field
wshot light-windows-advanced

step "a number typed into Gap moves real windows; one out of range is refused under the field"
enter gap.field 40
check "gap is 40" eventually setting_is gap 40
check "the real window starts 40 points from the edge" eventually inset_is 40
check "the window is still above the gap handles, which were drawn again" level_is 3
enter gap.field 500
check "500 is refused" setting_is gap 40
check "the reason stands in the window" eventually shows AXStaticText "Must be from 0 to 100"
check "the field is back at the real value" eventually field_is gap.field 40
wshot light-gap-refused

step "the slider changes the setting when it is let go of, not on the way"
read -r sx sy sw sh <<< "$(ax frame AXSlider gap.slider 2> /dev/null)"
if check "the slider is found" [ -n "${sh:-}" ]; then
  drag $((sx + sw * 2 / 5)) $((sy + sh / 2)) $((sx + sw * 4 / 5)) $((sy + sh / 2)) --no-release
  check "held: gap is still 40" setting_is gap 40
  check "held: the field follows the slider" not field_is gap.field 40
  wshot light-slider-held
  release
  check "let go: gap has changed" eventually not setting_is gap 40
  ctl get gap
fi
check "the refusal is gone after the next change" not shows AXStaticText "Must be from 0 to 100"

step "a change from outside shows in the open window"
ctl set gap 20
check "the field says 20" eventually field_is gap.field 20
printf '{"gap": 28, "focusRing": false}\n' > "$ARBOR_HOME/settings.json"
check "and 28 after an edit of the file" eventually field_is gap.field 28
arbor_settings "$SETTINGS"
check "and 12 when the file no longer names it" eventually field_is gap.field 12

step "a switch, and Restore Defaults"
ctl settings-window gestures
press_switch frameRectangleOnDesktop
check "the switch reached Arbor" eventually setting_is frameRectangleOnDesktop false
press AXButton "Restore Defaults"
check "Restore Defaults put it back" eventually setting_is frameRectangleOnDesktop true

step "search finds advanced settings and the lists"
press AXTextField search
type_text ring
check "the focus ring's width is found, though advanced" eventually shows AXTextField focusRingWidth.field
wshot light-search
key cmd+a
key delete

step "recording: new keys for a command"
ctl settings-window shortcuts
press AXButton record.show-all
check "the button asks for keys" eventually shows AXButton "Press the keys"
wshot light-recording
key ctrl+opt+shift+f8
check "⌃⌥⇧F8 runs show-all" eventually runs ctrl+opt+shift+f8 show-all
check "⌃⌥Space no longer does" not runs ctrl+opt+space show-all

step "recording: one of Arbor's own shortcuts reaches the recorder instead of running, and clashes"
view=$("$ARBOR_BIN/arborctl" status)
press AXButton record.show-all
key ctrl+opt+shift+f9
check "the window says who has the keys" eventually shows AXStaticText "runs Show the Desktop now"
check "the shortcut did not run: the view is where it was" [ "$("$ARBOR_BIN/arborctl" status)" = "$view" ]
check "nothing is bound yet" runs ctrl+opt+shift+f9 desktop
wshot light-clash
press AXButton "Use It Here Instead"
check "now it runs show-all" eventually runs ctrl+opt+shift+f9 show-all
check "and the keys from before are free" not runs ctrl+opt+shift+f8 show-all

step "recording: Escape cancels, and a ⌘-chord of the hidden menu is recorded, not obeyed"
press AXButton record.show-all
key escape
check "Escape ended the recording" eventually not shows AXButton "Press the keys"
check "and changed nothing" runs ctrl+opt+shift+f9 show-all
key ctrl+opt+shift+f6
check "Arbor has its shortcuts again: ⌃⌥⇧F6 ran set gap 0" eventually setting_is gap 0
press AXButton record.show-all
key cmd+w
check "⌘W did not close the window" window_is_open
check "it was recorded" eventually runs cmd+w show-all
check "with a word of caution on the line" eventually shows AXStaticText "no app gets ⌘W"
wshot light-caution
# At once: while it lasts, no app on this Mac gets ⌘W.
ctl reset bindings
check "the defaults are back" eventually runs ctrl+opt+space show-all
check "and ⌘W is everybody's again" not runs cmd+w show-all
arbor_settings "$SETTINGS"

step "rules: a title typed on a line goes with its rule when the line's arrow is clicked"
ctl settings-window rules
sleep 0.5
press AXTextField rule.2.title
type_text abc
press AXButton rule.2.down
ctl rules
check "rule 3 is the terminal's, with the title" eventually has_rule '3. com.example.terminal, title contains "abc"'
check "rule 2 got none of it" has_rule '2. com.example.player → float'
wshot light-rules-moved

step "a file that cannot be read is said above everything, and can be replaced"
ctl settings-window general
printf '{"gap": 40,\n  "rules": [\n' > "$ARBOR_HOME/settings.json"
check "the banner is up" eventually shows AXStaticText "settings.json cannot be read"
wshot light-file-broken
press_switch hotkeysEnabled
check "a switch is refused meanwhile" setting_is hotkeysEnabled true
check "with the reason under it" eventually shows AXStaticText "so nothing was changed"
wshot light-file-broken-refusal
press AXButton "Replace It with the Defaults"
check "it asks first" eventually shows AXButton question.yes
check "and has replaced nothing yet" shows AXStaticText "settings.json cannot be read"
wshot light-file-broken-question
press AXButton question.yes
check "the banner is gone" eventually not shows AXStaticText "settings.json cannot be read"
check "the old file is kept beside the new one" [ -s "$ARBOR_HOME/settings.unreadable.json" ]
check "the new one can be read" python3 -c 'import json, sys; json.load(open(sys.argv[1]))' "$ARBOR_HOME/settings.json"
printf '{"gap": 500, "focusRingColour": "mauve", "focusRing": false}\n' > "$ARBOR_HOME/settings.json"
check "values that could not be used are listed" eventually shows AXStaticText "could not be used as written"
wshot light-values-unusable
arbor_settings "$SETTINGS"

step "⌘W closes the window and the app from before has the keyboard again; what was being typed is handed over"
# shellcheck disable=SC2046
click $(titlebar_of "$W2")
check "a test window has the keyboard" eventually front_is "$ARBOR_WINDOWS_PID"
check "the settings window is an ordinary window meanwhile" eventually level_is 0
shot 02-behind-a-clicked-window
key ctrl+opt+,
check "⌃⌥, brings it to the front" eventually front_is "$ARBOR_PID"
check "and it floats again" eventually level_is 3
shot 03-brought-back-by-the-shortcut
ctl settings-window windows
press AXTextField gap.field
key cmd+a
type_text 33
key cmd+w
check "the window is closed" eventually not window_is_open
check "the test windows' app is in front again" eventually front_is "$ARBOR_WINDOWS_PID"
check "33, typed and not entered, was handed over" eventually setting_is gap 33
ctl settings-window
check "it opens again" eventually window_is_open
check "and shows what is so" eventually field_is gap.field 33
arbor_stop

step "dark: every pane, a refusal, a clash and the banner"
session dark
panes dark
ctl settings-window windows
enter gap.field 500
check "the reason stands in the window" eventually shows AXStaticText "Must be from 0 to 100"
wshot dark-gap-refused
ctl settings-window shortcuts
press AXButton record.show-all
key ctrl+opt+shift+f9
check "the window says who has the keys" eventually shows AXStaticText "runs Show the Desktop now"
wshot dark-clash
press AXButton Cancel
ctl settings-window general
printf '{"gap": 40,\n' > "$ARBOR_HOME/settings.json"
check "the banner is up" eventually shows AXStaticText "settings.json cannot be read"
wshot dark-file-broken
arbor_stop
