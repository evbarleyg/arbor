#!/bin/bash
# F10 on a real Mac, in pictures and checks: the app icon, the menu bar item and its buttons, the full menu,
# the welcome window with its live ticks, `doctor`, and a first launch without Accessibility permission.
#
#   scripts/mac-shell/run.sh scripts/mac-shell/shots-F10.sh
#
# Session 1 runs Arbor as every Mac shell script does (a child process, which has the runner's permissions), with the
# menu bar item and the shortcuts on. Real clicks on the item's buttons must move the view; a right click, a
# ⌃-click and an ⌥-click must open the menu; the moves of the welcome window are made with a real drag and
# real key presses. Session 2 wraps the same binary in a bundle and opens it through Launch Services, which
# makes it answer for its own permissions: it has none, as on a newcomer's Mac. Session 3 is dark.
#
# Safe on a person's Mac: whatever changes a setting of the Mac's (the appearance, the input sources, the list of apps that
# asked for Accessibility) or quits an app the script did not start happens only on GitHub's throwaway Macs. The two bundles
# it opens are made by this run, under identifiers of their own that claim no URL and no document, so an installed Arbor
# keeps its permission, its arbor:// links and its login item. It ends no process by name or by pattern, only ones whose
# number it got from starting them. It moves the pointer and presses keys: hands off meanwhile.
#
# Pictures: `shot` does nothing on a person's Mac, whatever ARBOR_SHOTS says (below): what stands in front of the curtain here is, half the time,
# the welcome window. `look` (lib.sh) is what this script takes there: one window of Arbor's own as the window server keeps it, whatever lies
# over or under it, and only if the terminal already has Screen Recording permission: nobody is asked for it. No rectangle of the screen is taken there.
# Words: what `doctor` and `menu` say about the Mac and the apps on it (`doctor`, `menu` below) stays on a person's Mac, and so does the
# welcome window, whose first page shows the same (`look_welcome`).
source "$(dirname "$0")/lib.sh"
# run-list.sh --pictures sets it for every script. Here it would photograph the welcome window with what doctor found on the Mac.
on_throwaway_mac || unset ARBOR_SHOTS ARBOR_SHOTS_WHOLE_SCREEN_I_HAVE_CLOSED_EVERYTHING
# Everything below that is made, opened or ended is named by a path under this folder.
case "${ARBOR_SESSION_DIR:-}" in /tmp/arbor-shell.*) ;; *) die "no session folder of this run's" ;; esac

screen_width=1024
screen_height=768

# The menu bar item at full resolution, so that the glyphs can be judged. On a throwaway Mac with the right part of the menu
# bar around it; on a person's the item's own window, in which there is nothing but what Arbor drew.
item_id() { overlays | awk '$3 == 25 && $8 == "on" { print $1; exit }'; }
bar() {
  if on_throwaway_mac; then
    sleep "${ARBOR_SETTLE:-0.7}"
    screencapture -x -R "$((screen_width - 560)),0,560,40" "$ARBOR_OUT/$1.png" && echo "shot: mac-shell/$1.png"
  else
    look "$1" "$(item_id)"
  fi
  return 0
}

# The ids of Arbor's open menus (a submenu is a window of its own), its welcome window and its About panel.
menu_ids() { overlays | awk '$3 == 101 && $8 == "on" { print $1 }'; }
welcome_id() { overlays | awk '$8 == "on" && ($6 == 560 || ($6 == 420 && $3 == 3)) { print $1; exit }'; }
about_id() { overlays | awk '$8 == "on" && $3 == 0 && $6 != 560 && $6 > 200 && $7 > 100 { print $1; exit }'; }
# look_menu <name>: every open menu, the submenu as <name>-2.
look_menu() {
  local id index=1
  for id in $(menu_ids); do
    if [ "$index" = 1 ]; then look "$1" "$id"; else look "$1-$index" "$id"; fi
    index=$((index + 1))
  done
  [ "$index" -gt 1 ] || echo "look_menu $1: no menu of Arbor's own is open (another process may draw it)"
}

# x y: the middle of a button of the menu bar item, by the name `menu-bar` gives it. The item centres its image.
button_at() {
  local ix iy iw ih
  read -r ix iy iw ih <<< "$(status_item_frame)"
  # Without a frame awk would still print a point: the top left corner, which is the Apple menu.
  [ -n "${ih:-}" ] || { echo "button_at $1: Arbor shows no menu bar item" >&2; return 1; }
  "$ARBOR_BIN/arborctl" menu-bar | awk -v name="$1" -v ix="$ix" -v iy="$iy" -v iw="$iw" -v ih="$ih" '
    { width = $2 + $3 }
    $1 == name { middle = $2 + $3 / 2; found = 1 }
    END { if (!found) exit 1; printf "%d %d\n", ix + (iw - width) / 2 + middle, iy + ih / 2 }'
}

# shows <button> <current|disabled|->: what `menu-bar` says about a button.
shows() {
  "$ARBOR_BIN/arborctl" menu-bar | awk -v name="$1" -v state="$2" '$1 == name && index($4, state) { found = 1 } END { exit !found }'
}

single_icon() { "$ARBOR_BIN/arborctl" menu-bar | grep -q "single icon"; }
has_buttons() { ! single_icon; }

# Menus are windows at level 101, whoever draws them.
menu_is_open() { pointer windows | awk '$3 == 101 && $8 == "on" { found = 1 } END { exit !found }'; }
menu_is_closed() { ! menu_is_open; }
# press <button> [options]: a click on a button of the item, or nothing at all if it cannot be found. A press that was not made
# is a failure of its own: "changed nothing" and "opened no menu" are true of a click that never happened.
press() {
  local at name=$1
  shift
  # shellcheck disable=SC2086
  if at=$(button_at "$name") && click $at "$@"; then return 0; fi
  check "the press on $name was made" false
  return 1
}
rightpress() {
  local at
  # shellcheck disable=SC2086
  if at=$(button_at "$1") && rightclick $at; then return 0; fi
  check "the right press on $1 was made" false
  return 1
}
# in_menu <key>…: the keys, one after another, but only while a menu is open to take them. A `check` that failed has only printed
# ✘: without this the letters would be typed into whatever has the keyboard.
in_menu() {
  local chord
  for chord in "$@"; do
    menu_is_open || { echo "in_menu: no menu is open; $chord not pressed"; return 1; }
    key "$chord"
  done
}
# shortcut <chord> <command…>: the real keys where they are sure to be Arbor's, otherwise the command they stand for. ⌃⌥Space that Arbor
# does not hold is macOS's "select next input source".
holds_every_shortcut() { "$ARBOR_BIN/arborctl" doctor | grep -q "^✔ Shortcuts: [0-9]* registered"; }
shortcut() {
  local chord=$1
  shift
  if on_throwaway_mac || holds_every_shortcut; then key "$chord" || ctl "$@"; else echo "shortcut $chord: not surely Arbor's here"; ctl "$@"; fi
}
# `doctor` tells which window managers run here, how Desktop & Dock is set, of VoiceOver, input sources and the displays' sizes. Of a
# person's Mac only the marks and the names of the rows are printed, and what the rows about Arbor alone say. By bytes, and only lines
# that are rows: in the C locale a `.` is a third of a ✔, and a pattern that does not match must not let the line through.
doctor() {
  echo "> doctor"
  if on_throwaway_mac; then "$ARBOR_BIN/arborctl" doctor; return; fi
  "$ARBOR_BIN/arborctl" doctor | perl -ne '
    next unless /^([^ ]+ ([^:]*)):(.*)/;
    my ($row, $name, $says) = ($1, $2, $3);
    print $name =~ /^(?:Accessibility|Shortcuts|Menu bar item|Version)$/ ? "$row:$says\n" : "$row\n"'
}
# `menu` names the app in front, in “ ”, and under Windows every open window by app and title. On a person's Mac the names are left out, by
# bytes as above, and of the list only how long it is stays: whatever is further in than Windows, up to the next row that is not.
menu() {
  echo "> menu"
  if on_throwaway_mac; then "$ARBOR_BIN/arborctl" menu; return; fi
  "$ARBOR_BIN/arborctl" menu | perl -ne '
    if ($list) { if (/^ {5}/) { $rows++; next } print "        ($rows rows)\n"; $list = 0 }
    if (/^    Windows /) { $list = 1; $rows = 0 }
    s/\xe2\x80\x9c.*\xe2\x80\x9d/\xe2\x80\x9c\xe2\x80\xa6\xe2\x80\x9d/;
    print'
}

# On a person's Mac keys are let through only to an app this script started. An open menu must not be left behind for
# want of an Escape: it would take every click that follows. A second click on the item closes it too.
close_menu() {
  # shellcheck disable=SC2046
  menu_is_open || return 0
  key escape || click $(status_item)
  eventually menu_is_closed
}

# x y w h of the welcome window, which is 560 points wide, and for the four moves 420 and above other windows.
welcome_frame() { overlays | awk '$8 == "on" && ($6 == 560 || ($6 == 420 && $3 == 3)) { print $4, $5, $6, $7; found = 1; exit } END { exit !found }'; }
no_welcome_window() { ! welcome_frame > /dev/null; }
# press_button <title>: a real click on the button of that title in a window of Arbor's, found as VoiceOver finds it: where it lies depends on the words.
AXFIND="$ARBOR_ROOT/.build/mac-shell/axfind"
press_button() {
  local where
  where=$("$AXFIND" "$ARBOR_PID" point AXButton "$1" 2>/dev/null) || { check "there is a button “$1” to press" false; return 1; }
  # shellcheck disable=SC2086
  click $where
}
# It glides there.
rests_at_the_right() {
  local wx wy ww wh
  read -r wx wy ww wh <<< "$(welcome_frame)"
  [ "$((wx + ww))" -ge "$((screen_width - 40))" ]
}
# Its second page floats above other windows (level 3).
on_second_page() { overlays | awk '$8 == "on" && $6 == 420 && $3 == 3 { found = 1 } END { exit !found }'; }
on_first_page() { [ "$(overlays | awk '$8 == "on" && $6 == 560 { print $3; exit }')" = 0 ]; }
# look_welcome <name>: a picture of the welcome window. Its first page shows what `doctor` found on the Mac: other window managers by name, the
# Desktop & Dock switches, VoiceOver, input sources. What is kept out of the words must not leave in a picture, so on a person's Mac the
# window is not taken at all. Not "only its second page": from outside the pages are told apart by the window's level, which is a matter of
# looks and may change, and a click on Continue that missed leaves the first page up. `MenuBarDrawingTests` draws every page off screen, with facts that are made up.
look_welcome() {
  if ! on_throwaway_mac; then
    echo "look $1: left out here: the welcome window shows what doctor found on this Mac"
    return 0
  fi
  look "$1" "$(welcome_id)"
}
# x y w h of another ordinary window of Arbor's: the About panel.
about_frame() {
  overlays | awk '$8 == "on" && $3 == 0 && $6 != 560 && $6 > 200 && $7 > 100 { print $4, $5, $6, $7; found = 1; exit } END { exit !found }'
}
no_about_panel() { ! about_frame > /dev/null; }
# Clicks the close button of the window at x y (w h).
close_window_at() {
  [ $# -ge 2 ] || { echo "close_window_at: there is no such window"; return 1; }
  click "$(($1 + 16))" "$(($2 + 15))"
}

arbor_build
# The fake Mac of a rehearsal has no welcome window, so nothing to find in one.
[ -n "${ARBOR_REHEARSAL:-}" ] || swiftc -O -swift-version 5 "$ARBOR_ROOT/scripts/mac-shell/axfind.swift" -o "$AXFIND" > "$ARBOR_OUT/build-axfind.log" 2>&1 \
  || { cat "$ARBOR_OUT/build-axfind.log"; die "scripts/mac-shell/axfind.swift did not compile"; }
read -r _ _ _ screen_width screen_height _ <<< "$(pointer displays | head -n 1)"
echo "the display is $screen_width by $screen_height points"

step "the app icon"
scratch_dir icon ICON_DIR
if swift scripts/make-icon.swift "$ICON_DIR/Arbor.iconset" && iconutil -c icns "$ICON_DIR/Arbor.iconset" -o "$ICON_DIR/Arbor.icns"; then
  ls -l "$ICON_DIR/Arbor.iconset" "$ICON_DIR/Arbor.icns" | awk '{ print $5, $9 }'
  for name in icon_256x256 icon_128x128 icon_32x32@2x icon_32x32 icon_16x16@2x icon_16x16; do
    cp "$ICON_DIR/Arbor.iconset/$name.png" "$ARBOR_OUT/00-$name.png"
  done
fi
check "the icon script and iconutil made Arbor.icns" test -s "$ICON_DIR/Arbor.icns"

step "session 1: the menu bar item"
arbor_start 3 ARBOR_NO_STATUS_ITEM=0 ARBOR_NO_HOTKEYS=0 ARBOR_NO_PROMPT=0
# A home folder nobody has used: the first launch of a lifetime (F46).
check "with the permission there, the welcome window still opens at the first launch" eventually welcome_frame
echo "the welcome window is at: $(welcome_frame)"
shot 05-first-launch-with-permission
look_welcome 05-first-launch-with-permission-own
# shellcheck disable=SC2046
close_window_at $(welcome_frame)
check "and closes" eventually no_welcome_window
doctor
ctl menu-bar
echo "the item is at: $(status_item_frame)"
bar 10-start
check "with nothing docked the item is Arbor's mark alone" single_icon
# A test window has the keyboard from here on, so that keys go to an app of this script's, and the menu speaks of that app.
# shellcheck disable=SC2046
click $(center_of "$W1")
menu
# shellcheck disable=SC2046
click $(status_item)
check "and a plain click opens the menu" eventually menu_is_open
shot 10-first-menu
look_menu 10-first-menu-own
check "which closes again" close_menu

step "two saved views"
ctl dock "$W1" left
check "the first dock brings the buttons" eventually shows everything current
check "there is nowhere to go back to" shows back disabled
ctl dock "$W2" right
ctl zoom "$W1"
ctl save-view 1
ctl zoom "$W2"
ctl save-view 3
ctl show-all
ctl menu-bar
echo "the item is at: $(status_item_frame)"
bar 11-two-views
shot 12-whole-screen

step "real clicks on the buttons"
press view-1
check "a click on 1 went to view 1" eventually shows view-1 current
check "the other docked window is out of view" eventually is parked "$W2"
bar 13-view-1
press back
check "a click on back went back to everything" eventually shows everything current
press forward
check "a click on forward went to view 1 again" eventually shows view-1 current
press desktop
check "a click on the Desktop button showed the Desktop" eventually shows desktop current
bar 14-desktop
press forward
check "a click on the disabled forward button changed nothing" shows desktop current
check "and opened no menu" menu_is_closed
press view-3
check "a click on 3 went to view 3" eventually shows view-3 current
press everything
check "a click on the Arbor mark showed everything" eventually shows everything current
bar 15-everything
press menu
check "a plain click on the last button opened the menu" eventually menu_is_open
check "escape closed it again" close_menu

step "a tooltip"
# shellcheck disable=SC2046
if button_at view-1 > /dev/null; then move $(button_at view-1); fi
sleep 2.5
shot 16-tooltip

step "the menu: right click, ⌃-click, ⌥-click"
# A test window has the focus, so that the items about the focused window have something to say.
# shellcheck disable=SC2046
click $(center_of "$W1")
rightpress everything
check "a right click opened the menu" eventually menu_is_open
menu
shot 20-menu
look_menu 20-menu-own
in_menu s a right
shot 21-saved-views
look_menu 21-saved-views-own
in_menu escape
check "escape closed it" close_menu
check "and the view did not move" shows everything current
press desktop --mods ctrl
check "a ⌃-click opened the menu" eventually menu_is_open
close_menu
sleep 0.3
press desktop --mods opt
check "an ⌥-click opened the menu" eventually menu_is_open
close_menu
check "neither ran the button" shows everything current

step "an item of the menu, chosen with the keyboard"
rightpress everything
in_menu v i right s h return
check "the first item under View, Show the Desktop, showed the Desktop" eventually shows desktop current
ctl show-all

step "Help, and About Arbor in it"
rightpress everything
in_menu h e right
shot 22-help
look_menu 22-help-own
in_menu a b return
check "About Arbor opened a panel" eventually about_frame
shot 23-about
look 23-about-own "$(about_id)"
# shellcheck disable=SC2046
close_window_at $(about_frame)
check "and its close button closed it" eventually no_about_panel
# The panel made Arbor the app in front, and what macOS brings forward when it closes is anybody's. A test window again, so that keys go to
# an app of this script's and the menu speaks of that app.
# shellcheck disable=SC2046
click $(center_of "$W1")

step "nine saved views"
for slot in 2 4 5 6 7 8 9; do "$ARBOR_BIN/arborctl" save-view "$slot" > /dev/null; done
ctl menu-bar
echo "the item is at: $(status_item_frame)"
bar 24-nine-views

step "a pause"
ctl pause
check "paused, the item is a single icon" eventually single_icon
bar 25-paused
# shellcheck disable=SC2046
click $(status_item)
check "a click opens the menu" eventually menu_is_open
menu
shot 26-paused-menu
look_menu 26-paused-menu-own
# The first row says that Arbor is paused, and resumes.
in_menu down return
check "Resume, chosen from the menu, brought the buttons back" eventually has_buttons
menu_is_open && close_menu
# Whatever became of that, the rest is not about a paused Arbor.
has_buttons || ctl resume

step "the settings"
arbor_settings '{"historyButtons": false, "menuBarFill": 0.12}'
ctl reload-settings
ctl menu-bar
bar 30-no-history-faint-fill
arbor_settings '{"menuBarControls": false}'
ctl reload-settings
ctl menu-bar
bar 31-single-icon
# shellcheck disable=SC2046
click $(status_item)
check "a plain click on the single icon opened the menu" eventually menu_is_open
shot 32-single-icon-menu
look_menu 32-single-icon-menu-own
close_menu
arbor_settings '{}'
ctl reload-settings
check "the buttons are back" eventually shows everything current

step "the welcome window, with everything granted"
ctl float-all
check "with everything floating the item is the mark again" eventually single_icon
ctl welcome
check "welcome opens the window on the four moves" eventually on_second_page
check "where it waits at the right of the display, clear of the left edge" eventually rests_at_the_right
ctl check-setup
check "check-setup turns it to a wide page" eventually on_first_page
check "the welcome window is on screen" eventually welcome_frame
echo "the welcome window is at: $(welcome_frame)"
overlays
shot 40-check-setup
look_welcome 40-check-setup-own
ctl welcome
check "welcome turns it to the moves" eventually on_second_page
press_button "Back"
check "Back turned to the welcome" eventually on_first_page
shot 40-welcome-ready
look_welcome 40-welcome-ready-own
press_button "Continue"
check "a click on Continue turned the page" eventually on_second_page
eventually rests_at_the_right
shot 41-first-steps
look_welcome 41-first-steps-own
read -r wx wy ww wh <<< "$(welcome_frame)"
# Out of the way of the test windows' title bars: to the bottom right corner.
drag "$((wx + ww / 2))" "$((wy + 14))" "$((screen_width - ww / 2 - 4))" "$((screen_height - 70 - wh + 14))"
echo "the welcome window is at: $(welcome_frame)"
summary

step "the four moves, for real"
# shellcheck disable=SC2046
drag $(titlebar_of "$W1") 3 400
check "the dragged window docked" eventually is docked "$W1"
shot 42-docked
look_welcome 42-docked-own
ctl dock "$W2" right
check "the second window docked" eventually is docked "$W2"
shot 42-two-docked
look_welcome 42-two-docked-own
# A click on the welcome window must not take the focus from the window that was docked.
read -r wx wy ww wh <<< "$(welcome_frame)"
click "$((wx + 300))" "$((wy + 70))"
shortcut ctrl+opt+return zoom
check "⌃⌥↩ framed the docked window although the welcome window was clicked last" eventually is parked "$W3"
shot 43-framed
look_welcome 43-framed-own
shortcut ctrl+opt+space show-all
check "⌃⌥Space showed everything" eventually shows everything current
shot 44-all-ticked
look_welcome 44-all-ticked-own

step "Back, and the close button"
press_button "Back"
check "Back turned to the first page" eventually on_first_page
# shellcheck disable=SC2046
close_window_at $(welcome_frame)
check "its close button closed the welcome window" eventually no_welcome_window
first_home=$ARBOR_HOME
arbor_stop 59-after-quit

step "the second launch, with what the first one saved"
# Every session gets a home folder of its own; what says that the window has been seen is in state.json.
check "the first launch wrote down that the window was seen" grep -q '"welcomed" *: *true' "$first_home/state.json"
cp "$first_home/state.json" "$ARBOR_HOME/state.json"
arbor_start 3 ARBOR_NO_STATUS_ITEM=0 ARBOR_NO_HOTKEYS=0 ARBOR_NO_PROMPT=0
sleep 2
check "the welcome window does not open by itself again" no_welcome_window
arbor_stop

step "session 2: a first launch without Accessibility permission"
app="$ARBOR_SESSION_DIR/Arbor.app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp "$ARBOR_BIN/Arbor" "$app/Contents/MacOS/Arbor"
cp Resources/Info.plist "$app/Contents/Info.plist"
[ -s "$ICON_DIR/Arbor.icns" ] && cp "$ICON_DIR/Arbor.icns" "$app/Contents/Resources/Arbor.icns"
# Safe beside an installed Arbor: another identifier, so that macOS keeps the two and their permissions apart, and no
# claim on arbor:// URLs, which Launch Services would otherwise hand to a bundle that is deleted a minute later.
# safe anywhere: it edits the copy of Info.plist in this run's temporary folder
/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier com.evbarleyg.arbor.first-launch-check" \
  -c "Delete :CFBundleURLTypes" "$app/Contents/Info.plist" || die "could not edit Info.plist"
codesign --force --sign - --identifier com.evbarleyg.arbor.first-launch-check "$app" || die "codesign failed"
# ARBOR_ONLY_PIDS: should it have the permission after all, it must not touch anything.
# safe anywhere: a bundle this run just made, under an identifier of its own that handles no URL or document
limit 20 open -n "$app" --env ARBOR_HOME="$ARBOR_HOME" --env ARBOR_SOCKET="$ARBOR_SOCKET" --env ARBOR_DEBUG=1 --env ARBOR_ONLY_PIDS=1 \
  --env ARBOR_NO_HOTKEYS=1 --env ARBOR_NO_WATCHDOG=1 --env ARBOR_NO_PICTURES=1
sleep 3
ARBOR_PID=$(pgrep -f "$app/Contents/MacOS/Arbor" | head -n 1)
# Whatever else may be called Arbor on this Mac is somebody's.
if [ -n "$ARBOR_PID" ] && ! arbor_started_here "$ARBOR_PID"; then ARBOR_PID=""; fi
[ -n "$ARBOR_PID" ] || die "the bundle did not start"
# On the run's record, so that it is ended with the run whatever becomes of this script.
started "$ARBOR_PID"
echo "Arbor pid $ARBOR_PID"
ctl status
doctor
ctl menu-bar
check "the welcome window opened by itself" eventually welcome_frame
shot 60-first-launch
look_welcome 60-first-launch-own
bar 61-first-launch-bar
if item=$(status_item); then
  # shellcheck disable=SC2086
  click $item
  menu
  shot 62-first-launch-menu
  look_menu 62-first-launch-menu-own
  close_menu
fi

step "closed, then Arbor is opened again"
if welcome_frame > /dev/null; then
  # shellcheck disable=SC2046
  close_window_at $(welcome_frame)
  check "the welcome window closed" eventually no_welcome_window
fi
# Only while the first instance lives, which then takes the call. Were it gone, this would start a new Arbor, so it gets the same
# fences: without them that one would arrange every window on this Mac, on its owner's real settings.
# safe anywhere: the same bundle of this run's, which is running, under the same home, socket and limits
kill -0 "$ARBOR_PID" 2>/dev/null && limit 20 open "$app" --env ARBOR_HOME="$ARBOR_HOME" --env ARBOR_SOCKET="$ARBOR_SOCKET" \
  --env ARBOR_ONLY_PIDS=1 --env ARBOR_NO_HOTKEYS=1 --env ARBOR_NO_WATCHDOG=1 --env ARBOR_NO_PICTURES=1
check "opening Arbor again brought the welcome window back" eventually welcome_frame
shot 63-reopened
look_welcome 63-reopened-own

step "its button"
# It makes macOS ask its own question and put this copy of Arbor in the Accessibility list.
if on_throwaway_mac && welcome_frame > /dev/null; then
  press_button "Open Settings…"
  sleep 9
  shot 64-open-settings
fi

echo "> quit"
"$ARBOR_BIN/arborctl" quit
sleep 1
on_throwaway_mac && killall "System Settings" 2>/dev/null
cp "$ARBOR_HOME/arbor.log" "$ARBOR_OUT/arbor-first-launch.log" 2>/dev/null
[ -n "${ARBOR_PID:-}" ] && kill_started "$ARBOR_PID"
ARBOR_PID=""
arbor_new_home

step "session 3: dark"
# The whole Mac if it lets us, which shows the menu bar item on a dark menu bar; otherwise only what Arbor draws itself.
dark=system
appearance dark || dark=app
echo "dark: $dark"
arbor_start 2 ARBOR_NO_STATUS_ITEM=0 ARBOR_NO_HOTKEYS=0 ARBOR_APPEARANCE=dark
ctl dock "$W1" left
ctl zoom "$W1"
ctl save-view 1
ctl show-all
bar 70-dark-bar
# shellcheck disable=SC2046
click $(center_of "$W1")
rightpress everything
shot 71-dark-menu
look_menu 71-dark-menu-own
close_menu

step "what gets in the way: another window manager, a second input source"
# Something that calls itself TrellisWM, as far as Launch Services can tell.
rival="$ARBOR_SESSION_DIR/TrellisWM.app"
mkdir -p "$rival/Contents/MacOS"
cp /bin/sleep "$rival/Contents/MacOS/TrellisWM"
cat > "$rival/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>TrellisWM</string>
<key>CFBundleIdentifier</key><string>com.example.stand-in.trelliswm</string>
<key>CFBundleName</key><string>TrellisWM</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>LSUIElement</key><true/>
</dict></plist>
PLIST
on_throwaway_mac && open -n "$rival" --args 90
if on_throwaway_mac; then
  echo 'import Carbon
    let filter = [kTISPropertyInputSourceID as String: "com.apple.keylayout.German"] as CFDictionary
    if let list = TISCreateInputSourceList(filter, true)?.takeRetainedValue() as? [TISInputSource], let source = list.first {
      print("enabling the German layout:", TISEnableInputSource(source))
    }' | swift - 2>&1 | tail -n 3
fi
sleep 1
doctor
if on_throwaway_mac; then
  # Nobody has seen who gets ⌃⌥Space when macOS wants it for "Select next source in Input menu".
  # shellcheck disable=SC2046
  click $(center_of "$W1")
  ctl zoom "$W1"
  key ctrl+opt+space
  if eventually shows everything current; then
    echo "with two input sources, ⌃⌥Space still reached Arbor"
  else
    echo "with two input sources, ⌃⌥Space did NOT reach Arbor"
    ctl show-all
  fi
fi
shot 72-after-ctrl-opt-space
ctl check-setup
shot 73-dark-welcome
look_welcome 73-dark-welcome-own
# Five rows are more than this display is tall: they scroll, and Done stays above the Dock.
read -r _ vy _ vh <<< "$(arbor_ask screen)"
read -r wx wy ww wh <<< "$(welcome_frame)"
echo "the welcome window is at: $wx $wy $ww $wh; the display shows $vy to $((vy + vh))"
check "the welcome window fits between the menu bar and the Dock" test "$((wy + wh))" -le "$((vy + vh))"
ctl welcome
sleep 0.8
shot 74-dark-first-steps
look_welcome 74-dark-first-steps-own
# shellcheck disable=SC2046
close_window_at $(welcome_frame)
arbor_stop
# The stand-in is /bin/sleep 90 and ends by itself.
[ "$dark" = system ] && appearance light
ls -l "$ARBOR_OUT" | awk '{ print $5, $9 }'
