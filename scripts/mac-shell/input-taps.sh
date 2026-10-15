#!/bin/bash
# Real input against Arbor's event taps (Sources/ArborKit/Input), judged by a witness at the far end of the
# chain of taps (witness.swift): what reaches apps, in which order, and how late. Run it after any change
# to that folder; nothing else exercises the taps.
#   scripts/mac-shell/run.sh scripts/mac-shell/input-taps.sh      (about four minutes)
#
# Unlike the other scripts it clicks and drags at places on the screen that it takes to be empty: the wallpaper,
# the menu bar, beside the Dock. On a Mac in use those clicks land in whatever is there, so it only runs on
# GitHub's, or with ARBOR_INPUT_TAPS_HERE=1 on a Mac with nothing else on screen and no other Arbor running. What
# changes the Mac itself (a system setting, the Accessibility permission) runs on GitHub's only, whatever is set.
source "$(dirname "$0")/lib.sh"
source "$(dirname "$0")/lib-gestures.sh"
[ "${ARBOR_INPUT_TAPS_HERE:-}" = 1 ] || needs_throwaway_mac "click and drag at fixed places on the screen (see its header)"

arbor_build
WITNESS="$ARBOR_ROOT/.build/mac-shell/witness"
if ! swiftc -O -swift-version 5 "$ARBOR_ROOT/scripts/mac-shell/witness.swift" -o "$WITNESS" \
  > "$ARBOR_OUT/build-witness.log" 2>&1; then
  cat "$ARBOR_OUT/build-witness.log"
  die "scripts/mac-shell/witness.swift did not compile"
fi

SEEN="$ARBOR_OUT/witness.txt"
: > "$SEEN"
"$WITNESS" watch 900 >> "$SEEN" 2>&1 &
WITNESS_PID=$!
started "$WITNESS_PID"
# Left alone it would go on for a quarter of an hour, writing down every click anybody makes.
at_exit 'kill_started $WITNESS_PID'
eventually grep -q witness-ready "$SEEN" || die "the witness did not start: $(cat "$SEEN")"
head -n 1 "$SEEN"

# Everything the witness prints after `mark` belongs to the experiment that follows it.
mark() {
  sleep 0.4
  echo "## $*" >> "$SEEN"
  LOG_MARK=0
  [ -f "$ARBOR_HOME/arbor.log" ] && LOG_MARK=$(wc -l < "$ARBOR_HOME/arbor.log")
}
# What the witness printed under one mark.
section() { awk -v name="## $1" '$0 == name { on = 1; next } /^## / { on = 0 } on' "$SEEN"; }
seen() {
  sleep 0.4
  awk '/^## / { text = ""; next } { text = text $0 "\n" } END { printf "%s", text }' "$SEEN"
}
# How many of the events since the mark match a pattern.
count() { seen | grep -c -- "$1"; }
# How many mouse-downs and mouse-ups there were since the mark.
clicks_seen() { seen | grep -cE -- '^(down|up) '; }
logged() { tail -n "+$((LOG_MARK + 1))" "$ARBOR_HOME/arbor.log" | cut -c 26-; }
delays_of() {
  grep "^$1 " | sed 's/.*delay_us=\([0-9-]*\).*/\1/' | sort -n \
    | awk '{ v[NR] = $1 } END { if (NR) printf "%d events, delay µs: min %d, median %d, max %d\n", NR, v[1], v[int((NR + 1) / 2)], v[NR]; else print "no events" }'
}
delays() { seen | delays_of "$1"; }
no_band() { ! has_overlay 3; }
arbor_taps() { "$WITNESS" taps | grep "pid=$ARBOR_PID "; }
# tap_is <mask> <true|false>: whether Arbor's tap with that mask is switched on. 0x2 is mouse-downs, 0x44 drags
# and mouse-ups, 0x400000 scrolls, 0x20000000 gestures.
tap_is() { arbor_taps | grep -q "mask=$1 enabled=$2"; }
none_is_on() { [ "$(arbor_taps | grep -c "enabled=true")" -eq 0 ]; }
# This script is about the taps, so it asks for them, whatever Arbor ships with. with_gestures '<json object>': a settings.json with
# every gesture that needs a tap switched on and, on top of that, what the object says.
with_gestures() {
  python3 -c 'import json, sys; print(json.dumps({**json.loads("{" + sys.argv[1] + "}"), **json.loads(sys.argv[2])}))' \
    "$ARBOR_GESTURES_ON" "$1" > "$ARBOR_HOME/settings.json"
}

# Since macOS 14 a click on the wallpaper slides every window off the screen, and the next one brings them
# back. This script clicks the wallpaper a lot, also where Arbor does not guard it (F60), so the switch is off except
# in the session that is about it. Only on a throwaway Mac: it is a setting of the person's.
# wallpaper_click <on|off>
wallpaper_click() {
  on_throwaway_mac || return 0
  if [ "$1" = on ]; then
    defaults delete com.apple.WindowManager EnableStandardClickToShowDesktop 2>/dev/null  # absent means on
  else
    defaults write com.apple.WindowManager EnableStandardClickToShowDesktop -bool false
  fi
  killall WindowManager 2>/dev/null
  sleep 1
}
wallpaper_click off

step "without Arbor: how long a click takes to reach the end of the taps"
"$WITNESS" taps
mark baseline
for _ in 1 2 3 4 5 6 7 8; do pointer click 500 400; done
echo "mouse-down: $(delays down)"
echo "mouse-up:   $(delays up)"

step "do posted pinches arrive at all? (no Arbor)"
mark "pinch at the session tap"
"$WITNESS" pinch 500 400 0.3 --steps 3
seen
PINCH_TAP=session
if [ "$(count magnify)" -eq 0 ]; then
  mark "pinch at the HID tap"
  "$WITNESS" pinch 500 400 0.3 --steps 3 --tap hid
  seen
  PINCH_TAP=hid
fi
PINCHES=yes
[ "$(count magnify)" -gt 0 ] || PINCHES=no
echo "posted pinches arrive: $PINCHES (posted at the $PINCH_TAP tap)"

step "session 1: three windows, taps and shortcuts on"
# Launched as on a Mac that has run an earlier build: its settings.json holds the four gestures switched on, as the first launch wrote them
# down (and the guard, which shipped on for a while), and cannot hold the switch above them, which ships off (Q26). Only then are the gestures asked for.
printf '%s\n' '{"gesturesEnabled": true, "scrollZoom": true, "frameRectangleModifier": "ctrl+opt", "frameRectangleOnDesktop": true, "guardDesktopClicks": true}' \
  > "$ARBOR_HOME/settings.json"
arbor_start 3 ARBOR_NO_HOTKEYS=0
sleep 1
arbor_taps
check "launched with an earlier build's settings Arbor holds no event tap" test "$(arbor_taps | wc -l)" -eq 0
with_gestures '{}'
ctl reload-settings
ctl dock "$W1" left
ctl dock "$W2" right
ctl dock "$W3" beside "$W1" bottom
sleep 0.5
summary
read -r dx dy dw dh <<< "$(arbor_ask desktop)"
BARE_X=$((dx + dw / 2))
BARE_Y=$((dy + dh / 2))
echo "a bare point of the Desktop: $BARE_X $BARE_Y"
grep "event tap" "$ARBOR_HOME/arbor.log" | cut -c 26-
echo "Arbor's taps:"
arbor_taps
check "four taps are installed" test "$(arbor_taps | wc -l)" -eq 4
check "the one on drags and mouse-ups is paused" tap_is 0x44 false
check "with none of Arbor's keys down none of the four is switched on" test "$(arbor_taps | grep -c "enabled=true")" -eq 0
"$WITNESS" hold 1.5 --ctrl --opt &
sleep 0.7
arbor_taps
check "while ⌃⌥ is down the tap on mouse-downs is switched on" tap_is 0x2 true
check "and so is the pinch tap, which goes by ⌥" tap_is 0x20000000 true
check "the one on drags and mouse-ups is not: no press is being followed" tap_is 0x44 false
wait $!
check "when the keys go up all are off again" eventually none_is_on
"$WITNESS" hold 1.5 --opt &
sleep 0.7
check "while ⌥ alone is down the pinch tap is switched on" tap_is 0x20000000 true
check "and the tap on mouse-downs is not" tap_is 0x2 false
wait $!
check "and off again" eventually tap_is 0x20000000 false
echo "windows on screen (id pid layer x y w h on owner):"
if on_throwaway_mac; then pointer windows | awk '$8 == "on"'; else pointer windows --pid "$ARBOR_WINDOWS_PID"; overlays; fi

step "with Arbor: how long a click on a docked window takes"
mark "latency with Arbor"
# shellcheck disable=SC2046
for _ in 1 2 3 4 5 6 7 8; do pointer click $(center_of "$W2"); done
echo "mouse-down: $(delays down)"
echo "mouse-up:   $(delays up)"
check "every plain click arrives: 8 downs" test "$(count '^down ')" -eq 8
check "none of them was held back" test "$(count '^down .*mark=none')" -eq 8
check "every plain click arrives: 8 ups" test "$(count '^up ')" -eq 8
arbor_taps

step "a plain drag of a floating window passes untouched"
ctl float "$W3"
sleep 0.5
mark "plain drag"
read -r x y w h <<< "$(frame_of "$W3")"
drag "$((x + w / 2))" "$((y + 12))" "$((x + w / 2 + 40))" "$((y + 52))" --steps 10
check "the app saw the mouse-down" test "$(count '^down ')" -eq 1
check "the app saw the drag" test "$(count '^dragged ')" -ge 10
check "the app saw the mouse-up" test "$(count '^up ')" -eq 1
check "the drag tap stayed paused" tap_is 0x44 false
ctl dock "$W3" beside "$W1" bottom
sleep 0.5

step "⌃⌥-click: handed back, once, in order"
# shellcheck disable=SC2046
click $(center_of "$W1")
check "a plain click focuses the first window" eventually is focused "$W1"
mark "ctrl+opt click"
# shellcheck disable=SC2046
click $(center_of "$W2") --mods ctrl+opt
seen
check "one mouse-down reached the app" test "$(count '^down ')" -eq 1
check "it is the one Arbor sent on" test "$(count '^down .*mark=arbor')" -eq 1
check "it still carries ⌃⌥" test "$(count '^down .*mods=ctrl+opt')" -eq 1
check "one mouse-up reached the app" test "$(count '^up ')" -eq 1
check "the mouse-down came first" test "$(seen | grep -E '^(down|up) ' | head -n 1 | cut -d' ' -f1)" = down
# macOS does not bring a window forward for a ⌘-click, so this is only worth knowing.
sleep 0.5
if is focused "$W2"; then echo "the ⌃⌥-click focused the second window"; else echo "the ⌃⌥-click did not change the focus"; fi
check "the drag tap is paused again" tap_is 0x44 false

step "⌃⌥ double-click: both clicks handed back with their click counts"
mark "ctrl+opt double-click"
# shellcheck disable=SC2046
dblclick $(center_of "$W1") --mods ctrl+opt
seen
check "two mouse-downs" test "$(count '^down ')" -eq 2
check "the second says it is the second" test "$(count '^down .*clicks=2')" -eq 1
check "two mouse-ups" test "$(count '^up ')" -eq 2

step "⌃⌥-drag: nothing reaches the app, the band shows, release frames"
read -r x y w h <<< "$(frame_of "$W2")"
mark "ctrl+opt drag"
drag "$((x + 30))" "$((y + 60))" "$((x + w - 30))" "$((y + h - 40))" --mods ctrl+opt --no-release
check "the band is on screen while the button is held" has_overlay 3
check "the drag tap is on while the button is held" tap_is 0x44 true
shot 01-band
release --mods ctrl+opt
check "no mouse-down reached an app" test "$(count '^down ')" -eq 0
check "no drag reached an app" test "$(count '^dragged ')" -eq 0
check "no mouse-up reached an app" test "$(count '^up ')" -eq 0
check "the rectangle framed the window inside it" eventually is parked "$W1"
check "the band is gone" eventually no_band
check "the drag tap is paused again" tap_is 0x44 false
logged | grep -v "^DEBUG" | tail -n 5
ctl show-all
sleep 0.5

if [ "$PINCHES" = yes ]; then
  step "pinches"
  read -r x y w h <<< "$(frame_of "$W2")"
  mark "pinch over a window without ⌥"
  "$WITNESS" pinch "$((x + w / 2))" "$((y + h / 2))" 0.6 --steps 6 --tap "$PINCH_TAP"
  check "the app gets all of it (8 events)" test "$(count magnify)" -eq 8
  logged | grep -i pinch

  pointer move "$((x + w / 2))" "$((y + h / 2))"
  mark "⌥-pinch over a window, with a rotation"
  "$WITNESS" pinch "$((x + w / 2))" "$((y + h / 2))" 0.3 --steps 6 --opt --rotate --tap "$PINCH_TAP"
  seen | grep gesture
  check "the app gets none of the pinch" test "$(count magnify)" -eq 0
  check "the app gets none of the rotation that began during it" test "$(count rotate)" -eq 0
  logged | grep -iE "pinch|^INFO" | tail -n 6
  check "Arbor stepped in" eventually is parked "$W1"
  ctl show-all
  sleep 0.5

  mark "pinch on the bare Desktop without ⌥, as Arbor ships"
  "$WITNESS" pinch "$BARE_X" "$BARE_Y" 0.1 --steps 2 --tap "$PINCH_TAP"
  check "it is not Arbor's: no key of Arbor's is down" test "$(count magnify)" -eq 4

  with_gestures '{"pinchOnDesktop": true}'
  ctl reload-settings
  check "with pinchOnDesktop the pinch tap is on all day" eventually tap_is 0x20000000 true
  mark "pinch on the bare Desktop without ⌥"
  "$WITNESS" pinch "$BARE_X" "$BARE_Y" 0.1 --steps 2 --tap "$PINCH_TAP"
  check "it is Arbor's" test "$(count magnify)" -eq 0
  logged | grep -i pinch

  mark "pinch on the menu bar without ⌥"
  "$WITNESS" pinch 400 10 0.1 --steps 2 --tap "$PINCH_TAP"
  check "it is not Arbor's" test "$(count magnify)" -eq 4
  logged | grep -i pinch

  mark "a huge delta"
  "$WITNESS" pinch "$BARE_X" "$BARE_Y" 1e300 --steps 1 --tap "$PINCH_TAP"
  sleep 1
  check "Arbor still answers" ctl status
  ctl show-all
  with_gestures '{}'
  ctl reload-settings
  check "with pinchOnDesktop off again the pinch tap is off" eventually tap_is 0x20000000 false
fi

step "⇧-drag that starts on the bare Desktop: nothing reaches an app, release frames"
read -r x y w h <<< "$(frame_of "$W2")"
mark "shift drag from the Desktop"
# From the Desktop's column, left of the second window, to beyond its far corner.
drag "$((x - 20))" "$((y + 4))" "$((x + w + 2))" "$((y + h + 2))" --mods shift --no-release
check "the band is on screen while the button is held" has_overlay 3
shot 02-band-from-the-desktop
release --mods shift
check "no mouse-down reached an app" test "$(count '^down ')" -eq 0
check "no drag reached an app" test "$(count '^dragged ')" -eq 0
check "no mouse-up reached an app" test "$(count '^up ')" -eq 0
check "the rectangle framed the window inside it" eventually is parked "$W1"
check "the band is gone" eventually no_band
logged | grep -v "^DEBUG" | tail -n 3
ctl show-all
sleep 0.5

step "⇧-click on the bare Desktop still reaches Finder"
mark "shift click on the Desktop"
click "$BARE_X" "$BARE_Y" --mods shift
seen
check "one mouse-down, sent on by Arbor, with ⇧" test "$(count '^down .*mods=shift clicks=1 mark=arbor')" -eq 1
check "no other mouse-down" test "$(count '^down ')" -eq 1
check "one mouse-up" test "$(count '^up ')" -eq 1
check "the mouse-down came first" test "$(seen | grep -E '^(down|up) ' | head -n 1 | cut -d' ' -f1)" = down

step "⇧-drag that starts over a window is the app's"
mark "shift drag over a window"
drag "$((x + 60))" "$((y + 100))" "$((x + 160))" "$((y + 200))" --mods shift --steps 10
check "the app saw the mouse-down as it was" test "$(count '^down .*mark=none')" -eq 1
check "the app saw the drag" test "$(count '^dragged ')" -ge 10
check "the app saw the mouse-up" test "$(count '^up ')" -eq 1
check "no band" no_band
echo "a ⇧ mouse-down waits for the window list: $(delays down)"

step "⇧-click on the menu bar is not held back"
mark "shift click on the menu bar"
click 600 10 --mods shift
check "the mouse-down arrived as it was" test "$(count '^down .*mark=none')" -eq 1
key escape

step "⇧-click beside the Dock is outside Arbor's view: not held back"
mark "shift click on the Dock's edge"
read -r sx sy sw sh <<< "$(arbor_ask screen)"
click 20 "$((sy + sh + 30))" --mods shift
check "the mouse-down arrived as it was" test "$(count '^down .*mark=none')" -eq 1

step "with frameRectangleOnDesktop off, ⇧-drag on the Desktop is Finder's"
with_gestures '{"frameRectangleOnDesktop": false}'
ctl reload-settings
mark "shift drag with the setting off"
drag "$BARE_X" "$BARE_Y" "$((BARE_X + 80))" "$((BARE_Y + 80))" --mods shift --steps 10
check "Finder saw the mouse-down as it was" test "$(count '^down .*mark=none')" -eq 1
check "Finder saw the drag" test "$(count '^dragged ')" -ge 10
"$WITNESS" hold 1.5 --ctrl --opt &
sleep 0.7
check "⌃⌥-drag is still watched for, while the keys are down" tap_is 0x2 true
wait $!
# The guard ships off, so it is asked for.
with_gestures '{"frameRectangleOnDesktop": false, "frameRectangleModifier": "none", "guardDesktopClicks": true}'
ctl reload-settings
check "with both off the guard of the Desktop still watches the mouse, all day" eventually tap_is 0x2 true
with_gestures '{"frameRectangleOnDesktop": false, "frameRectangleModifier": "none", "guardDesktopClicks": false}'
ctl reload-settings
check "with all three off, only the pinch and scroll taps are left" test "$(arbor_taps | wc -l)" -eq 2
with_gestures '{}'
ctl reload-settings
check "and back" test "$(arbor_taps | wc -l)" -eq 4

step "pointerGestures off: no tap is left, whatever the other settings say"
with_gestures '{"pointerGestures": false, "guardDesktopClicks": true, "continuousZoom": true, "scrollOnDesktopZooms": true}'
ctl reload-settings
arbor_taps
check "Arbor holds no event tap" test "$(arbor_taps | wc -l)" -eq 0
mark "a shift drag with the switch off"
drag "$BARE_X" "$BARE_Y" "$((BARE_X + 80))" "$((BARE_Y + 80))" --mods shift --steps 10
check "a ⇧-drag on the Desktop is Finder's: the mouse-down arrived as it was" test "$(count '^down .*mark=none')" -eq 1
check "and the drag" test "$(count '^dragged ')" -ge 10
with_gestures '{}'
ctl reload-settings
check "switched on again all four are back" test "$(arbor_taps | wc -l)" -eq 4

step "continuousZoom: ⌃⌥-scroll and pinch are streamed, every other scroll is left alone"
read -r x y w h <<< "$(frame_of "$W2")"
pointer move "$((x + w / 2))" "$((y + h / 2))"
mark "a scroll before the setting is on"
"$WITNESS" scroll "$((x + w / 2))" "$((y + h / 2))" 0 -120 --steps 6 --opt
check "an ⌥-scroll is the app's (8 events)" test "$(count '^scroll ')" -eq 8
echo "a scroll event with ⌥ held, past Arbor's paused scroll tap: $(delays scroll)"
check "at rest the scroll tap is installed and paused" eventually tap_is 0x400000 false
mark "a scroll past the paused tap"
"$WITNESS" scroll "$((x + w / 2))" "$((y + h / 2))" 0 -120 --steps 6
echo "a scroll event past Arbor's paused scroll tap: $(delays scroll)"
"$WITNESS" hold 1.5 --ctrl --opt &
sleep 0.7
check "while ⌃⌥ is down it is switched on" tap_is 0x400000 true
wait $!
check "and paused again when the keys go up" eventually tap_is 0x400000 false
for keys in --ctrl --opt; do
  "$WITNESS" hold 1 "$keys" &
  sleep 0.5
  check "$keys alone leaves it paused" tap_is 0x400000 false
  wait $!
done
# R1's and R2's finding on #68: a key that goes up unheard must not make Arbor deaf to the next press.
"$WITNESS" hold 0.5 --ctrl --opt &
sleep 0.2
wait $!
"$WITNESS" hold 1.5 --ctrl --opt &
sleep 0.7
check "pressed a second time it is switched on again" tap_is 0x400000 true
wait $!
check "and paused again" eventually tap_is 0x400000 false
with_gestures '{"scrollZoom": false}'
ctl reload-settings
check "with scrollZoom off as well there is no scroll tap" test "$(arbor_taps | wc -l)" -eq 3
mark "a scroll without the tap"
"$WITNESS" scroll "$((x + w / 2))" "$((y + h / 2))" 0 -120 --steps 6
echo "a scroll event without Arbor's scroll tap: $(delays scroll)"
with_gestures '{"continuousZoom": true, "scrollZoom": false}'
ctl reload-settings
check "the scroll tap is installed, and paused" tap_is 0x400000 false
mark "a plain scroll"
"$WITNESS" scroll "$((x + w / 2))" "$((y + h / 2))" 0 -120 --steps 6 --momentum 3
check "the app gets all of it, momentum too (12 events)" test "$(count '^scroll ')" -eq 12
echo "a scroll event past Arbor's paused scroll tap: $(delays scroll)"
mark "an ⌥-scroll"
"$WITNESS" scroll "$((x + w / 2))" "$((y + h / 2))" 40 -120 --steps 6 --opt --momentum 3
check "⌥ alone is never Arbor's: the app gets all of it, momentum too (12 events)" test "$(count '^scroll ')" -eq 12
mark "a ⌃⌥-scroll, sideways"
"$WITNESS" scroll "$((x + w / 2))" "$((y + h / 2))" 120 10 --steps 6 --ctrl --opt --momentum 3
seen | grep '^scroll '
check "the app gets none of it, nor of its momentum" test "$(count '^scroll ')" -eq 0
echo "a scroll event through Arbor's scroll tap, which ⌃⌥ switched on: $(delays scroll)"
logged | grep -i scroll
mark "a plain scroll afterwards"
"$WITNESS" scroll "$((x + w / 2))" "$((y + h / 2))" 0 -120 --steps 6
check "the next plain scroll is the app's again (8 events)" test "$(count '^scroll ')" -eq 8
if [ "$PINCHES" = yes ]; then
  mark "a streamed ⌥-pinch"
  "$WITNESS" pinch "$((x + w / 2))" "$((y + h / 2))" 0.3 --steps 6 --opt --tap "$PINCH_TAP"
  check "the app gets none of the pinch" test "$(count magnify)" -eq 0
  check "the view moved in" eventually is parked "$W1"
  ctl show-all
  sleep 0.5
fi
with_gestures '{}'
ctl reload-settings
check "with continuousZoom off again the scroll tap stays, for ⌃⌥-scroll" test "$(arbor_taps | wc -l)" -eq 4

step "F55: ⌃⌥ and a scroll zoom; every other scroll is left alone"
ctl show-all
read -r x y w h <<< "$(frame_of "$W2")"
cx=$((x + w / 2))
cy=$((y + h / 2))
pointer move "$cx" "$cy"
mark "a wheel, no keys"
"$WITNESS" wheel "$cx" "$cy" 3
check "the app gets all three notches" test "$(count '^scroll ')" -eq 3
check "and Arbor does nothing" test "$(logged | grep -c -E "^INFO  (in|out):")" -eq 0
echo "a notch past Arbor's paused scroll tap: $(delays scroll)"
for keys in --opt --ctrl; do
  mark "a wheel with $keys alone"
  "$WITNESS" wheel "$cx" "$cy" 2 "$keys"
  check "with $keys alone the app gets both notches" test "$(count '^scroll ')" -eq 2
done
mark "⌃⌥ and one notch up, over window 2"
"$WITNESS" wheel "$cx" "$cy" 1 --ctrl --opt
seen | grep '^scroll '
check "the app gets nothing" test "$(count '^scroll ')" -eq 0
check "the view stepped in once" test "$(logged | grep -c "^INFO  in:")" -eq 1
check "toward the pointer: window 1 went out of view" eventually is parked "$W1"
mark "⌃⌥ and one notch down"
"$WITNESS" wheel "$cx" "$cy" -1 --ctrl --opt
check "the view stepped out once" test "$(logged | grep -c "^INFO  out:")" -eq 1
check "window 1 is back" eventually is on_screen "$W1"
mark "⌃⌥ and two fingers, 100 points up, then coasting"
"$WITNESS" scroll "$cx" "$cy" 0 100 --steps 10 --ctrl --opt --momentum 5
check "the app gets none of it, nor of its momentum" test "$(count '^scroll ')" -eq 0
echo "steps in: $(logged | grep -c -E "^(INFO |DEBUG) in") (two of 40 points; the second may have nowhere to go)"
check "the momentum made no further steps" test "$(logged | grep -c -E "^(INFO |DEBUG) in")" -le 2
check "with the momentum over the tap is paused again" eventually tap_is 0x400000 false
ctl show-all
mark "a plain scroll afterwards"
"$WITNESS" scroll "$cx" "$cy" 0 -120 --steps 6
check "the next plain scroll is the app's again (8 events)" test "$(count '^scroll ')" -eq 8

# The product owner's question on #68. Many people with big displays have "Use scroll gesture with modifier keys to zoom" on, with ⌃.
# The switch is the person's to set, so this part runs only where there is no person.
if on_throwaway_mac; then
  step "F55: with macOS's own zoom on ⌃ + scroll, whose is ⌃⌥ + scroll?"
  macos_zoom() { defaults read com.apple.universalaccess closeViewZoomFactor 2>/dev/null || echo 1; }
  defaults write com.apple.universalaccess closeViewScrollWheelToggle -bool true
  defaults write com.apple.universalaccess closeViewScrollWheelModifiersInt -int 262144  # ⌃
  killall universalaccessd 2>/dev/null
  sleep 2
  at_rest=$(macos_zoom)
  mark "⌃ alone and three notches, with macOS's zoom on"
  "$WITNESS" wheel "$cx" "$cy" 3 --ctrl
  sleep 1
  echo "the app got $(count '^scroll ') of 3 notches; macOS's zoom factor went from $at_rest to $(macos_zoom)"
  shot 02a-macos-zoom-with-ctrl
  if [ "$(count '^scroll ')" -eq 3 ] && [ "$at_rest" = "$(macos_zoom)" ]; then
    echo "NOTE: macOS did not zoom for a posted ⌃-scroll, so the two checks below prove nothing: try it by hand (docs/TESTING.md)"
  fi
  "$WITNESS" wheel "$cx" "$cy" -3 --ctrl
  sleep 1
  before=$(macos_zoom)
  mark "⌃⌥ and one notch up, with macOS's zoom on"
  "$WITNESS" wheel "$cx" "$cy" 1 --ctrl --opt
  sleep 1
  echo "Arbor stepped in $(logged | grep -c "^INFO  in:") time(s); macOS's zoom factor went from $before to $(macos_zoom)"
  shot 02b-ctrl-opt-scroll-with-macos-zoom-on
  check "Arbor stepped in once" test "$(logged | grep -c "^INFO  in:")" -eq 1
  check "and macOS did not zoom the screen as well" test "$before" = "$(macos_zoom)"
  defaults write com.apple.universalaccess closeViewScrollWheelToggle -bool false
  killall universalaccessd 2>/dev/null
  sleep 1
  ctl show-all
fi

step "the permission check leaves the taps alone while permission is there"
sleep 3
check "the taps are still installed" test "$(arbor_taps | wc -l)" -eq 4
check "the log does not say that permission went away" test "$(grep -c "permission is gone" "$ARBOR_HOME/arbor.log")" -eq 0
echo "all taps now (a probe tap would show as a fifth of Arbor's):"
"$WITNESS" taps

step "a shortcut held down"
mark "⌃⌥Space with ten auto-repeats"
# Elsewhere through the net, which declines this chord where macOS takes it to switch somebody's keyboard layout.
if on_throwaway_mac; then "$WITNESS" hold-space 10; else key ctrl+opt+space --repeat 10; fi
sleep 0.5
check "the command ran once: shortcuts do not repeat" test "$(logged | grep -c "show-all")" -eq 1

step "Arbor is killed in the middle of a ⌃⌥-drag"
read -r x y w h <<< "$(frame_of "$W2")"
mark "killed mid-drag"
drag "$((x + 30))" "$((y + 60))" "$((x + w - 30))" "$((y + h - 40))" --mods ctrl+opt --no-release
kill -KILL "$ARBOR_PID"
sleep 0.5
release --mods ctrl+opt
seen | tail -n 4
mark "after the kill"
pointer click "$((x + w / 2))" "$((y + h / 2))"
check "the next click arrives whole: a mouse-down" test "$(count '^down ')" -eq 1
check "the next click arrives whole: a mouse-up" test "$(count '^up ')" -eq 1
echo "mouse-down: $(delays down)"
check "the killed process leaves no tap behind" test "$("$WITNESS" taps | grep -c "pid=$ARBOR_PID ")" -eq 0
wait "$ARBOR_PID" 2>/dev/null # safe anywhere: it was killed above
ARBOR_PID=""
arbor_log
arbor_close_windows
arbor_new_home

step "session 2: Arbor stops answering, again and again"
# The guard, because it keeps the tap on mouse-downs on with no key held, so that a plain click meets it.
with_gestures '{"guardDesktopClicks": true}'
arbor_start 1 ARBOR_NO_HOTKEYS=0
mark "before the rounds"
# Quick, so that three rounds fit into the ten seconds within which Arbor counts them (TapHealth).
for round in 1 2 3; do
  echo "## stopped, round $round" >> "$SEEN"
  kill -STOP "$ARBOR_PID" # safe anywhere: elsewhere only with ARBOR_INPUT_TAPS_HERE=1, whose owner the header has told
  pointer click 512 60
  sleep 1.6
  kill -CONT "$ARBOR_PID"
  sleep 0.5
  [ "$round" -lt 3 ] && check "round $round: the mouse-down tap is back on" eventually tap_is 0x2 true
done
sleep 1
for round in 1 2 3; do
  echo "round $round, mouse-down: $(section "stopped, round $round" | delays_of down)"
done
logged | grep -i "event tap"
check "after three in a row the mouse-down tap is left off" tap_is 0x2 false
check "and so is every other tap: they share the thread that was too slow" test "$(arbor_taps | grep -c "enabled=true")" -eq 0
mark "a click while the tap rests and Arbor is stopped"
kill -STOP "$ARBOR_PID" # safe anywhere: elsewhere only with ARBOR_INPUT_TAPS_HERE=1, whose owner the header has told
pointer click 512 60
echo "mouse-down: $(delays down)"
check "it does not wait for Arbor" test "$(count '^down ')" -eq 1
kill -CONT "$ARBOR_PID"
arbor_stop

# F60. It needs the macOS switch at its default, which is the person's to set, and a file on the Desktop.
if on_throwaway_mac; then
  step "session 3: a click on the Desktop does not sweep the windows away"
  wallpaper_click on
  # Off by default until this session has been seen to pass.
  with_gestures '{"guardDesktopClicks": true}'
  arbor_start 3 ARBOR_NO_HOTKEYS=0 ARBOR_NO_STATUS_ITEM=0
  server_frames() { for id in $ARBOR_WINDOW_IDS; do printf '%s | ' "$(real_frame_of "$id")"; done; }
  echo "nothing docked yet: Arbor takes no interest"
  mark "a shift drag with nothing docked"
  drag 900 600 980 680 --mods shift --steps 10
  check "⇧-drag on the wallpaper is Finder's: the mouse-down arrived as it was" test "$(count '^down .*mark=none')" -eq 1
  check "and no band was drawn" no_band
  mark "a click with nothing docked"
  before=$(server_frames)
  pointer click 1000 690
  sleep 1
  check "the click reached macOS as it was" test "$(count '^down .*mark=none')" -eq 1
  echo "before: $before"
  echo "after:  $(server_frames)"
  if [ "$before" = "$(server_frames)" ]; then
    echo "NOTE: macOS swept nothing, so the switch is not on and the checks below prove little"
  else
    pointer click 1000 690
    sleep 1
  fi

  ctl dock "$W1" left
  ctl dock "$W2" right
  sleep 0.5
  summary
  read -r dx dy dw dh <<< "$(arbor_ask desktop)"
  read -r fx fy fw fh <<< "$(frame_of "$W3")"
  # Below the floating window, on the Desktop's part of the layout.
  BARE_X=$((dx + dw / 2))
  BARE_Y=$((dy + dh - 20))
  before=$(server_frames)

  mark "a click on the Desktop"
  pointer click "$BARE_X" "$BARE_Y"
  sleep 1
  check "no mouse-down reached macOS" test "$(count '^down ')" -eq 0
  check "no mouse-up reached macOS" test "$(count '^up ')" -eq 0
  check "every window is where it was, by the window server" test "$before" = "$(server_frames)"
  check "the drag tap is paused again" tap_is 0x44 false
  shot 03-after-a-click-on-the-desktop

  mark "a click in the gap at the edge of the display"
  pointer click "$((dx + dw / 2))" "$((dy - 6))"
  sleep 1
  check "nothing reached macOS" test "$(clicks_seen)" -eq 0
  check "every window is where it was" test "$before" = "$(server_frames)"

  mark "a double-click on the Desktop"
  pointer click "$BARE_X" "$BARE_Y" 2
  sleep 1
  check "nothing reached macOS" test "$(clicks_seen)" -eq 0
  check "every window is where it was" test "$before" = "$(server_frames)"

  mark "a tap on the Desktop: the button is up before Finder can have answered"
  pointer click "$BARE_X" "$BARE_Y" --quick
  sleep 1
  check "nothing reached macOS" test "$(clicks_seen)" -eq 0
  check "every window is where it was" test "$before" = "$(server_frames)"
  check "the drag tap is paused again" tap_is 0x44 false

  mark "a drag on the Desktop"
  drag "$BARE_X" "$BARE_Y" "$((BARE_X - 60))" "$((BARE_Y - 60))" --steps 10 --no-release
  shot 04-finders-selection-rectangle
  release
  check "Finder got the mouse-down, sent on by Arbor" test "$(count '^down .*mark=arbor')" -eq 1
  check "and no other" test "$(count '^down ')" -eq 1
  check "it came before the first drag" test "$(seen | grep -E '^(down|dragged) ' | head -n 1 | cut -d' ' -f1)" = down
  check "Finder got the drag" test "$(count '^dragged ')" -ge 8
  check "Finder got the mouse-up" test "$(count '^up ')" -eq 1
  check "every window is where it was" test "$before" = "$(server_frames)"

  mark "a click on a floating window over the Desktop"
  pointer click "$((fx + fw / 2))" "$((fy + fh / 2))"
  check "it arrived as it was" test "$(count '^down .*mark=none')" -eq 1
  echo "Arbor knows where the window is, so nobody reads the window list: $(delays down)"

  # People click the wallpaper to be rid of these. Nobody has measured their levels, so each prints its own.
  above_the_palettes() { pointer windows --on-screen | awk '$3 > 3'; }
  furniture=$(above_the_palettes | wc -l)
  echo "above the palettes with nothing going on:"
  above_the_palettes
  something_is_up() { [ "$(above_the_palettes | wc -l)" -gt "$furniture" ]; }
  nothing_is_up() { ! something_is_up; }
  # click_away <what is open>: it is open already; a click on the Desktop must reach whoever closes it.
  click_away() {
    sleep 0.7
    check "$1 is open" something_is_up
    echo "above the palettes with $1 open:"
    above_the_palettes
    mark "a click on the Desktop with $1 open"
    pointer click "$BARE_X" "$BARE_Y"
    sleep 0.7
    check "$1: the click arrived as it was" test "$(count '^down .*mark=none')" -eq 1
    check "$1: and its mouse-up" test "$(count '^up ')" -eq 1
    check "$1 is closed" eventually nothing_is_up
    logged | grep "is left alone" | tail -n 1
    # If macOS swept the windows aside for that click, a second one brings them back.
    [ "$before" = "$(server_frames)" ] || { echo "NOTE: that click swept the windows aside"; pointer click "$BARE_X" "$BARE_Y"; sleep 1; }
    key escape
  }
  pointer click 20 10
  click_away "the Apple menu"
  key cmd+space
  click_away "Spotlight"
  pointer click $(pointer status-item "$ARBOR_PID")
  click_away "Arbor's own menu"
  read -r _ _ _ cx cy cw ch _ <<< "$(pointer windows --on-screen | awk '$3 == 25' | tail -n 1)"
  pointer click "$((cx + cw / 2))" "$((cy + ch / 2))"
  click_away "the last item of the menu bar"
  mark "a click on the Desktop when all that is over"
  pointer click "$BARE_X" "$BARE_Y"
  sleep 1
  check "the guard is back: nothing reached macOS" test "$(clicks_seen)" -eq 0
  check "every window is where it was" test "$before" = "$(server_frames)"

  echo "a file on the Desktop; Finder puts the first icon in the top right corner"
  touch "$HOME/Desktop/arbor-f60.txt"
  sleep 3
  ctl desktop
  sleep 0.5
  read -r sx sy sw sh <<< "$(arbor_ask screen)"
  ICON_X=$((sx + sw - 66))
  ICON_Y=$((sy + 40))
  shot 05-an-icon-on-the-desktop
  mark "a click on the icon"
  pointer click "$ICON_X" "$ICON_Y"
  sleep 0.5
  seen
  check "the icon got its click: a mouse-down sent on by Arbor" test "$(count '^down .*mark=arbor')" -eq 1
  check "and the mouse-up" test "$(count '^up ')" -eq 1
  shot 06-the-icon-selected
  mark "a tap on the icon"
  pointer click "$ICON_X" "$ICON_Y" --quick
  sleep 0.7
  seen
  check "the icon got the mouse-down, sent on by Arbor" test "$(count '^down .*mark=arbor')" -eq 1
  check "and the mouse-up, sent on as well" test "$(count '^up .*mark=arbor')" -eq 1
  check "in that order" test "$(seen | grep -E '^(down|up) ' | head -n 1 | cut -d' ' -f1)" = down
  check "and nothing twice" test "$(clicks_seen)" -eq 2
  mark "a shift drag that starts on the icon"
  drag "$ICON_X" "$ICON_Y" "$((ICON_X - 120))" "$((ICON_Y + 120))" --mods shift --steps 10 --no-release
  check "no band: the drag is Finder's" no_band
  release --mods shift
  check "Finder got the mouse-down, sent on by Arbor" test "$(count '^down .*mark=arbor')" -eq 1
  check "and the drag" test "$(count '^dragged ')" -ge 8
  rm -f "$HOME/Desktop/arbor-f60.txt"
  ctl show-all
  sleep 0.5

  with_gestures '{"guardDesktopClicks": false}'
  ctl reload-settings
  mark "a click on the Desktop with the guard off"
  before=$(server_frames)
  pointer click "$BARE_X" "$BARE_Y"
  sleep 1
  check "the click reached macOS as it was" test "$(count '^down .*mark=none')" -eq 1
  check "and macOS swept the windows aside, as it intends" test "$before" != "$(server_frames)"
  pointer click "$BARE_X" "$BARE_Y"
  sleep 1
  arbor_stop
  wallpaper_click off
fi

# Last, and only on a throwaway Mac: the permission is taken from everything, this script's tools included.
if on_throwaway_mac; then
  step "session 4: Accessibility is taken away while the taps are installed"
  with_gestures '{}'
  arbor_start 1 ARBOR_NO_HOTKEYS=0
  check "the taps are installed" test "$(arbor_taps | wc -l)" -eq 4
  sudo tccutil reset Accessibility
  no_taps() { [ "$(arbor_taps | wc -l)" -eq 0 ]; }
  check "Arbor removes its taps within three seconds" eventually no_taps
  check "and says so" grep -q "permission is gone" "$ARBOR_HOME/arbor.log"
  arbor_stop
fi

kill "$WITNESS_PID" 2>/dev/null
