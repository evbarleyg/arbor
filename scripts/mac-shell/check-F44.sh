#!/bin/bash
# F44, shortcuts follow the keyboard layout, with real keys and macOS's own layouts:
#
#   scripts/mac-shell/run.sh scripts/mac-shell/check-F44.sh
#
# `key ctrl+opt+y` presses a position (the key where a US keyboard has Y), as a finger does. On a German keyboard that
# key is labelled Z, so it must run what ⌃⌥Z is bound to; on a French one the key where a US keyboard has Q is A; on
# Dvorak nothing is where a US keyboard has it.
#
# First part, safe on a person's Mac: Arbor is told to go by a layout that is installed but not selected
# (ARBOR_KEYBOARD_LAYOUT), which proves the reading of macOS's tables, the registration and the labels.
# Second part, only on one of GitHub's throwaway Macs: the layouts are really selected (keys.swift) while Arbor runs, which
# proves that it hears of the change although it is never the active app, and shows how soon.
ARBOR_SHORTCUTS=all  # it presses keys of the whole map, of which nine ship
source "$(dirname "$0")/lib.sh"

KEYS="$ARBOR_ROOT/.build/mac-shell/keys"
# ⌃⌥A is no key of Arbor's any more. Here it is somebody's own, for a letter that a French keyboard has elsewhere.
BINDINGS='"bindings": {"ctrl+opt+z": "desktop", "ctrl+opt+y": "home", "ctrl+opt+us:k": "relayout", "ctrl+opt+a": "arrange"}'

ran() { grep -c "INFO  $1" "$ARBOR_HOME/arbor.log"; }
ran_is() { [ "$(ran "$1")" = "$2" ]; }
logged() { grep -q "$1" "$ARBOR_HOME/arbor.log"; }
last_layout_is() { grep "keyboard layout: " "$ARBOR_HOME/arbor.log" | tail -n 1 | grep -q "keyboard layout: $1\$"; }
shows() { "$ARBOR_BIN/arborctl" bindings | grep -qF "$1"; }
hides() { ! shows "$1"; }
# press <keys> <command>: that press makes the command, as the log writes it, run once more.
press() {
  local before
  before=$(ran "$2:")
  key "$1"
  eventually ran_is "$2:" $((before + 1))
}
# leaves <keys> <command>: that press does not run the command.
leaves() {
  local before
  before=$(ran "$2:")
  key "$1"
  sleep 0.5
  ran_is "$2:" "$before"
}
choose() { "$KEYS" select "com.apple.keylayout.$1"; }
# session [NAME=value…]: [1 | 2] with window 1 focused, shortcuts and the menu bar item on.
session() {
  arbor_settings "{$BINDINGS}"
  arbor_start 2 ARBOR_NO_HOTKEYS=0 ARBOR_NO_STATUS_ITEM=0 "$@"
  ctl dock "$W1" left
  ctl dock "$W2" right
  # shellcheck disable=SC2046
  click $(center_of "$W1")
  grep -E "keyboard layout|registered" "$ARBOR_HOME/arbor.log"
}
german_checks() {
  check "the key labelled Z (where a US keyboard has Y) shows the Desktop" press ctrl+opt+y desktop
  check "the docked windows went out of view" eventually is parked "$W1"
  check "the key labelled Y (where a US keyboard has Z) shows everything" press ctrl+opt+z home
  check "the key labelled Ü (where a US keyboard has [) goes back" press ctrl+opt+[ back
  ctl home
  check "a shortcut written as a position has not moved" press ctrl+opt+k relayout
  check "bindings shows what is printed on the key" shows "ctrl+opt+[ (⌃⌥Ü)"
  check "and names the layout" shows "on the German keyboard layout"
  ctl bindings | grep -E "back|forward|desktop|home|relayout|layout"
}

arbor_build
swiftc -O -swift-version 5 "$ARBOR_ROOT/scripts/mac-shell/keys.swift" -o "$KEYS" > "$ARBOR_OUT/build-keys.log" 2>&1 || {
  cat "$ARBOR_OUT/build-keys.log"
  die "scripts/mac-shell/keys.swift did not compile"
}
# Which layouts a person has switched on says where they come from, and this gets pasted into pull requests.
on_throwaway_mac && "$KEYS" layout
on_throwaway_mac && "$KEYS" layouts

step "going by the German layout: ⌃⌥Z shows the Desktop, ⌃⌥Y everything"
session ARBOR_KEYBOARD_LAYOUT=com.apple.keylayout.German
check "Arbor read the layout" last_layout_is German
german_checks
read -r item_x item_y <<< "$(status_item)"
rightclick "$item_x" "$item_y"
shot 01-menu-german
key escape
arbor_stop

step "going by the French layout: letters move, digits stay"
session ARBOR_KEYBOARD_LAYOUT=com.apple.keylayout.French
check "Arbor read the layout" last_layout_is French
check "the key labelled A (where a US keyboard has Q) arranges" press ctrl+opt+q arrange
check "the key labelled Q (where a US keyboard has A) is not Arbor's" leaves ctrl+opt+a arrange
check "the key labelled Z (where a US keyboard has W) shows the Desktop" press ctrl+opt+w desktop
ctl home
check "⌃⌥⇧1 saves a view from the key that has 1 on it" press ctrl+opt+shift+1 "save-view 1"
check "⌃⌥1 recalls it" press ctrl+opt+1 "view 1"
ctl bindings | grep -E "view 1|arrange|back|layout"
arbor_stop

step "going by Dvorak: nothing is where a US keyboard has it"
session ARBOR_KEYBOARD_LAYOUT=com.apple.keylayout.Dvorak
check "Arbor read the layout" last_layout_is Dvorak
check "the key that types D (where a US keyboard has H) shows the Desktop" press ctrl+opt+h desktop
ctl home
check "so does the key that types Z (where a US keyboard has /)" press ctrl+opt+/ desktop
ctl home
check "the key that types [ (where a US keyboard has -) goes back" press ctrl+opt+- back
ctl home
check "the key where a US keyboard has D is not Arbor's" leaves ctrl+opt+d desktop
check "the position shortcut is where a US keyboard has K" press ctrl+opt+k relayout
arbor_stop

step "shortcutsFollowLayout: false gives positions back"
session ARBOR_KEYBOARD_LAYOUT=com.apple.keylayout.German
arbor_settings "{\"shortcutsFollowLayout\": false, $BINDINGS}"
ctl reload-settings
check "where a US keyboard has Z shows the Desktop, whatever is printed there" press ctrl+opt+z desktop
check "where a US keyboard has Y shows everything" press ctrl+opt+y home
check "bindings says so" shows "because shortcutsFollowLayout is false"
check "and shows US labels" hides "(⌃⌥Ü)"
echo "K126, on this Mac as it is:"
"$ARBOR_BIN/arborctl" bindings | grep "as well" || echo "none of Arbor's shortcuts is macOS's as well"
arbor_stop

step "K126, for the record: macOS's own shortcuts, raw (which bits come with arrow keys, and with the Globe key?)"
"$KEYS" hotkeys

step "for the record: what the layouts' keys type"
"$KEYS" dump com.apple.keylayout.US com.apple.keylayout.ABC com.apple.keylayout.British com.apple.keylayout.German \
  com.apple.keylayout.SwissGerman com.apple.keylayout.French com.apple.keylayout.ABC-AZERTY com.apple.keylayout.Dvorak \
  com.apple.keylayout.DVORAK-QWERTYCMD com.apple.keylayout.Colemak com.apple.keylayout.Spanish-ISO \
  com.apple.keylayout.Italian-Pro com.apple.keylayout.Swedish-Pro com.apple.keylayout.Czech com.apple.keylayout.Turkish-QWERTY-PC \
  com.apple.keylayout.Russian com.apple.keylayout.Greek > "$ARBOR_OUT/layouts.jsonl"
wc -l "$ARBOR_OUT/layouts.jsonl"

arbor_may "switch keyboard layouts and add some to the Input menu" || exit 0

# Whatever ends the script, the Mac gets its layout back. arbor_exit takes the script's exit code from $?.
trap 'code=$?; "$KEYS" select com.apple.keylayout.US > /dev/null
  for name in German Dvorak Russian; do "$KEYS" remove "com.apple.keylayout.$name" > /dev/null; done
  (exit "$code"); arbor_exit' EXIT

step "a US keyboard, really selected"
choose US
session
check "Arbor read the layout at launch" logged "keyboard layout: "
check "the key labelled Z shows the Desktop" press ctrl+opt+z desktop
check "the key labelled Y shows everything" press ctrl+opt+y home

step "German, selected while Arbor runs in the background"
choose German
check "Arbor hears of it" eventually last_layout_is German
german_checks

step "K126: with two keyboards in the Input menu, ⌃⌥Space is macOS's as well. Who gets it?"
if shows "Select next source in Input menu"; then
  ctl bindings | grep "as well"
  check "the log says so too" logged "Select next source in Input menu"
  source_before=$("$KEYS" layout)
  ctl desktop
  if press ctrl+opt+space show-all; then echo "Arbor got the key"; else echo "Arbor did not get the key"; fi
  echo "the input source before: $source_before"
  echo "the input source after:  $("$KEYS" layout)"
  choose German
  ctl home
else
  echo "NOTE: macOS does not list ⌃⌥Space among its ticked shortcuts here, so there is nothing to see"
fi

step "Dvorak, then Russian: macOS pairs it with a Latin layout, as for ⌘-shortcuts"
choose Dvorak
check "Arbor hears of it" eventually last_layout_is Dvorak
check "the key that types D (where a US keyboard has H) shows the Desktop" press ctrl+opt+h desktop
ctl home
registered_before=$(grep -c "registered [0-9]* shortcuts" "$ARBOR_HOME/arbor.log")
choose Russian
sleep 1
"$KEYS" layout
grep "keyboard layout: " "$ARBOR_HOME/arbor.log" | tail -n 2
echo "registrations since Russian was selected: $(($(grep -c "registered [0-9]* shortcuts" "$ARBOR_HOME/arbor.log") - registered_before))"
case "$("$KEYS" layout)" in
  *"ascii com.apple.keylayout.Dvorak"*) d_key=ctrl+opt+h ;;
  *) d_key=ctrl+opt+d ;;
esac
check "⌃⌥D still shows the Desktop, on the key that types D in that Latin layout" press "$d_key" desktop
ctl home

step "for the record: how soon after the selection Arbor has registered again"
grep -E "keyboard layout: |registered [0-9]+ shortcuts" "$ARBOR_HOME/arbor.log"
choose US
arbor_stop 02-after-quit
