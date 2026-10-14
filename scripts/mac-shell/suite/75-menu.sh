#!/bin/bash
# The menu bar item, clicked for real.
# T16 Arrange Windows, T17 Float All Windows, T18 don't arrange an app, T61 quitting, T62 back to a normal Mac,
# T73 open at login (by command).
source "$(dirname "$0")/../lib.sh"
arbor_build
# From an app bundle, as installed, where that is harmless: only the installed app can launch at login.
if on_throwaway_mac; then ARBOR_BUNDLED=1; fi
ARBOR_SECOND_APP=1
arbor_start 3 ARBOR_NO_STATUS_ITEM=0 ARBOR_NO_HOTKEYS=0

claim "the menu bar item opens a menu of commands"
check "Arbor has an item in the menu bar" eventually status_item
open_menu
check "the menu offers Show Everything" eventually pointer menu-item "$ARBOR_PID" "Show Everything"
echo "Arbor's own windows with the menu open (id pid level x y w h on owner):"
overlays
check "and Arrange Windows" pointer menu-item "$ARBOR_PID" "Arrange Windows"
check "and Float All Windows" pointer menu-item "$ARBOR_PID" "Float All Windows"
check "and Quit Arbor" pointer menu-item "$ARBOR_PID" "Quit Arbor"
key escape
sleep 0.5
echo "and with the menu closed:"
overlays
echo "Accessibility on a closed menu's item: $(pointer menu-item "$ARBOR_PID" "Quit Arbor" 2>&1)"

claim "choose Arrange Windows from the menu: every window docks"
proves T16
check "the item can be clicked" click_menu "Arrange Windows"
check "Arbor ran arrange" eventually ran arrange
check "all four are docked" eventually count docked 4
check "nothing overlaps" eventually no_overlaps
check "the first window is in view" eventually in_view "$W1"
settled

claim "choose Float All Windows from the menu: back to a normal Mac"
proves T17 T62
ctl zoom "$W1"
check "the others are out of view" eventually out_of_view "$W2"
check "the item can be clicked" click_menu "Float All Windows"
check "Arbor ran float-all" eventually ran float-all
check "nothing is docked" eventually count docked 0
check "the first window is in view" eventually in_view "$W1"
check "the second window is in view" eventually in_view "$W2"
check "the third window is in view" eventually in_view "$W3"
check "the other app's window is in view" eventually in_view "$V1"

claim "choose Dock Focused Window, Left from the menu"
click_window "$W2"
check "the submenu's item can be clicked" click_menu "Dock Focused Window" "Left"
check "Arbor ran dock left" eventually ran dock left
check "the focused window docked at the left edge" eventually at_edge "$W2" left
settled

claim "choose Don’t Arrange for the focused app: its windows are released, the other app's stay"
proves T18
ctl dock "$V1" right
ctl dock "$W1" beside "$W2" bottom
click_window "$W2"
check "the item can be clicked" click_menu "Don’t Arrange"
check "Arbor ran exclude" eventually ran exclude "$ARBOR_TEST_BUNDLE"
check "the app's windows are no longer arranged" eventually fails is managed "$W2"
check "none of them" fails is managed "$W1"
check "the other app's window is still docked" is docked "$V1"
check "one is docked" count docked 1
check "the released windows stay in view" eventually in_view "$W2"
check "a command on one of them is refused" fails ctl dock "$W2" left
check "settings.json has the app" grep -q "$ARBOR_TEST_BUNDLE" "$ARBOR_HOME/settings.json"

claim "choose the app under Arrange Again: its windows are arranged again"
proves T18
check "the submenu's item can be clicked" click_menu "Arrange Again" "ArborTestWindows"
check "Arbor ran include" eventually ran include "$ARBOR_TEST_BUNDLE"
check "the app's windows are arranged again" eventually is managed "$W2"
check "they float" is floating "$W2"
check "a command on one of them works" ctl dock "$W2" left
settled

claim "exclude and include an app by command"
proves T18
check "exclude succeeds" ctl exclude "$ARBOR_TEST_BUNDLE_2"
check "its docked window is released" eventually fails is managed "$V1"
check "it stays in view" eventually in_view "$V1"
check "include succeeds" ctl include "$ARBOR_TEST_BUNDLE_2"
check "its window is arranged again" eventually is managed "$V1"

# It changes the person's Login Items, so only on a throwaway Mac. The tick itself lives in the settings window.
if on_throwaway_mac; then
  claim "launch-at-login on and off, by command: macOS takes the installed app on and lets it go again"
  proves T73
  check "at first it does not open at login" says "off" arborctl launch-at-login
  check "launch-at-login on succeeds" ctl launch-at-login on
  check "macOS says that it opens at login" says "on" arborctl launch-at-login
  check "launch-at-login off succeeds" ctl launch-at-login off
  check "macOS says that it does not any more" says "off" arborctl launch-at-login
fi

claim "choose Quit Arbor from the menu while zoomed in: every window comes back"
proves T61
ctl dock "$W1" right
ctl zoom "$W2"
check "the others are out of view" eventually out_of_view "$W1"
arbor=$ARBOR_PID
check "the item can be clicked" click_menu "Quit Arbor"
check "Arbor exits" arbor_await_exit "$ARBOR_PID" 50
# If it has not, it is ended here, so that what follows speaks of a Mac without Arbor either way.
arbor_ended
check "the first window is in view" eventually in_view "$W1"
check "the second window is in view" eventually in_view "$W2"
check "the third window is in view" eventually in_view "$W3"
check "the other app's window is in view" eventually in_view "$V1"
check "its menu bar item is gone" eventually fails pointer status-item "$arbor"
