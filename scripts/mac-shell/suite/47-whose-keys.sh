#!/bin/bash
# Apps that keep their own keys: in an app on passThroughApps Arbor's shortcuts are the app's, for one on pauseForApps Arbor
# pauses altogether. What counts is the app in front.
# A61 apps that keep their own ⌃⌥, and apps Arbor pauses for.
source "$(dirname "$0")/../lib.sh"
arbor_build

paused() { "$ARBOR_BIN/arborctl" status | grep "^paused" > /dev/null || { echo "Arbor is not paused"; return 1; }; }
running() { "$ARBOR_BIN/arborctl" status | grep "^running" > /dev/null || { echo "Arbor is not running"; return 1; }; }
# What settings.json has under that key, with commas between.
listed() {
  python3 -c 'import json, sys; print(",".join(json.load(open(sys.argv[1])).get(sys.argv[2], [])))' "$ARBOR_HOME/settings.json" "$1"
}
# Not what it has instead: with somebody's app in front when the menu was clicked that would be their app's, in the evidence.
lists() { [ "$(listed "$1")" = "$2" ] || { echo "settings.json has something else under $1, or nothing"; return 1; }; }
marked() { [ "$(pointer menu-mark "$ARBOR_PID" "Shortcuts Off in")" = "$1" ]; }
# goes_to_app <id> <chord> <command…>: the shortcut, pressed with that window in front, reaches the window and not Arbor.
goes_to_app() {
  local id=$1 chord=$2 keys mark
  shift 2
  keys=$(events_of "$id" key) || return 1
  mark=$(arbor_log_lines)
  key_to "$id" "$chord" || return 1
  eventually received "$id" key -gt "$keys" || return 1
  stays fails arbor_ran_since "$mark" "$@"
}

ARBOR_SECOND_APP=1
# In the Dock and in ⌘Tab, like a person's apps. Not on a person's Mac, where the Dock would grow, and every slot with it, for two minutes.
if on_throwaway_mac; then
  ARBOR_TEST_WINDOWS_ARGS="--regular"
  ARBOR_SECOND_APP_ARGS="--regular"
fi
arbor_start 2 ARBOR_NO_HOTKEYS=0 ARBOR_NO_STATUS_ITEM=0
ctl dock "$W1" left
ctl dock "$V1" right
summary
shortcuts=$("$ARBOR_BIN/arborctl" bindings | grep -c "^[a-z].* → ")

claim "turn Arbor's shortcuts off in the app in front, by command: they reach the app instead"
proves A61
click_window "$W1"
check "the app is in front" eventually front_is "$ARBOR_WINDOWS_PID"
check "before, ⌃⌥↩ is Arbor's" pressed ctrl+opt+return zoom
check "and so is ⌃⌥Space" pressed ctrl+opt+space show-all
check "pass-through on succeeds" ctl pass-through "$ARBOR_TEST_BUNDLE" on
check "settings.json lists the app" lists passThroughApps "$ARBOR_TEST_BUNDLE"
check "Arbor lets go of all its shortcuts but one" eventually logged "registered 1 shortcuts"
check "status says where they are off" says "shortcuts and gestures are off in" arborctl status
check "⌃⌥↩ goes to the app" goes_to_app "$W1" ctrl+opt+return zoom
check "⌃⌥D goes to the app" goes_to_app "$W1" ctrl+opt+d desktop
check "⌃⌥⌘→ goes to the app" goes_to_app "$W1" ctrl+opt+cmd+right dock right
check "the camera stayed on everything" camera_on root
check "the other app's window is still in view" in_view "$V1"
settled

claim "with the shortcuts off in its app, a window dragged onto another still docks"
proves A61
# shellcheck disable=SC2046
drag_window "$W2" $(zone_of "$W1" bottom)
check "it is docked" eventually is docked "$W2"
check "below the first window" eventually above "$W1" "$W2"
check "in its column" eventually same_column "$W1" "$W2"
check "the shortcuts are still the app's" goes_to_app "$W2" ctrl+opt+f toggle-float
settled

claim "⌃⌥⎋ answers even in an app that keeps its keys: Arbor pauses, and resumes"
proves A61
click_window "$W1"
keys=$(events_of "$W1" key)
key_to "$W1" ctrl+opt+escape
check "Arbor is paused" eventually paused
key ctrl+opt+escape
check "Arbor runs again" eventually running
check "the app saw neither press" stays received "$W1" key -eq "$keys"
check "the other shortcuts are still the app's" goes_to_app "$W1" ctrl+opt+space show-all
settled

claim "click another app's window: Arbor's shortcuts work again, and are off again back in the listed app"
proves A61
click_window "$V1"
check "the other app is in front" eventually front_is "$ARBOR_WINDOWS_PID_2"
check "all the shortcuts are registered again" eventually logged "registered $shortcuts shortcuts"
keys=$(events_of "$V1" key)
check "⌃⌥↩ reaches Arbor" pressed ctrl+opt+return zoom
check "the focused window fills the screen" eventually fills "$V1"
check "the listed app's windows go out of view like any others" eventually out_of_view "$W1"
check "⌃⌥Space reaches Arbor" pressed ctrl+opt+space show-all
check "and they come back" eventually in_slot "$W1"
check "the app in front saw neither" received "$V1" key -eq "$keys"
# The next claim clicks an item that is about the app in front, whosever it is.
click_window "$W1" || exit 1
check "the listed app is in front" eventually front_is "$ARBOR_WINDOWS_PID" || exit 1
check "⌃⌥↩ goes to the app again" goes_to_app "$W1" ctrl+opt+return zoom
settled

claim "the menu says that the shortcuts are off in the app in front, and its ticked item switches them on again"
proves A61
open_menu
check "the first line says so" eventually pointer menu-item "$ARBOR_PID" "Shortcuts are off in"
check "Shortcuts Off in the app is ticked" marked "✓"
key escape
check "the item can be clicked" click_menu "Shortcuts Off in"
check "Arbor ran pass-through for the app" eventually ran pass-through "$ARBOR_TEST_BUNDLE"
check "settings.json no longer lists it" eventually lists passThroughApps ""
check "the app is still in front" front_is "$ARBOR_WINDOWS_PID"
check "⌃⌥↩ reaches Arbor" pressed ctrl+opt+return zoom
check "⌃⌥Space too" pressed ctrl+opt+space show-all
settled

claim "choose Shortcuts Off for the app in front from the menu: the shortcuts are the app's"
proves A61
# The item is about the app in front, whosever it is.
click_window "$W1" || exit 1
check "the first app is in front" eventually front_is "$ARBOR_WINDOWS_PID" || exit 1
# While they are on the row is in its submenu alone; once off, it also stands under the line that says so, which is what is read below.
check "the submenu's item can be clicked" click_menu "Focused Window" "Shortcuts Off in"
check "settings.json lists the app" eventually lists passThroughApps "$ARBOR_TEST_BUNDLE"
check "⌃⌥↩ goes to the app" goes_to_app "$W1" ctrl+opt+return zoom
open_menu
check "the item is ticked" eventually marked "✓"
key escape
settled

# The first app's window and the other app's in one column, so that a view can hold both and leave the third window out.
ctl dock "$V1" beside "$W1" bottom
ctl dock "$W2" right
summary

claim "put an app on pauseForApps in settings.json: Arbor pauses when it comes to the front"
proves A61
# This also takes the first app off passThroughApps.
arbor_settings "{\"pauseForApps\": [\"$ARBOR_TEST_BUNDLE_2\"]}"
check "reload-settings succeeds" ctl reload-settings
click_window "$W1"
check "Arbor runs while another app is in front" running
check "⌃⌥↩ frames the focused window" pressed ctrl+opt+return zoom
check "⌃⌥↑ steps out to its column" pressed ctrl+opt+up out
check "the listed app's window is in view" eventually in_view "$V1"
check "the window at the other edge is not" eventually out_of_view "$W2"
click_window "$V1"
check "the listed app is in front" eventually front_is "$ARBOR_WINDOWS_PID_2"
check "Arbor is paused" eventually paused
check "status says for which app" says "paused for" arborctl status
check "the window that was out of view is back" eventually in_view "$W2"
check "only the shortcut that ends a pause is still registered" eventually logged "registered 1 shortcuts"
keys=$(events_of "$V1" key)
key ctrl+opt+space
check "⌃⌥Space goes to the app" eventually received "$V1" key -gt "$keys"
check "and not to Arbor" stays fails ran show-all
open_menu
check "the menu says for which app Arbor is paused" eventually pointer menu-item "$ARBOR_PID" "Arbor is paused for"
key escape

claim "leave the app Arbor paused for: Arbor resumes, with the view it had"
proves A61
click_window "$W1"
check "the first app is in front" eventually front_is "$ARBOR_WINDOWS_PID"
check "Arbor runs again" eventually running
check "the window at the other edge is out of view again" eventually out_of_view "$W2"
check "the clicked window is in its slot" eventually in_slot "$W1"
check "and so is the listed app's" eventually in_slot "$V1"
check "all the shortcuts are registered again" eventually logged "registered $shortcuts shortcuts"
check "⌃⌥Space reaches Arbor" pressed ctrl+opt+space show-all
check "everything is in view" eventually in_view "$W2"
settled

claim "a pause begun with ⌃⌥⎋ is not ended by visiting and leaving the app Arbor pauses for"
proves A61
key_to "$W1" ctrl+opt+escape
check "Arbor is paused" eventually paused
click_window "$V1"
check "the listed app is in front" eventually front_is "$ARBOR_WINDOWS_PID_2"
click_window "$W1"
check "the first app is in front again" eventually front_is "$ARBOR_WINDOWS_PID"
check "Arbor stays paused" stays paused
key ctrl+opt+escape
check "⌃⌥⎋ ends it" eventually running
settled

arbor_stop
