#!/bin/bash
# What cannot fit overlaps (F69, board 0.26), on two real apps that cannot both fit: Notes will not go under 709 points and System Settings is 723 wide and
# nothing else, and a display 1344 wide has 1320 for the two. ⌃⌥← on the one, ⌃⌥→ on the other, by the real keys, Arbor as a person gets it.
# (Not Mail: on a Mac without an account it holds a sheet, "Add Account", which has the keyboard and is no window Arbor arranges.)
#
#   scripts/mac-shell/run.sh scripts/mac-shell/shots-what-cannot-fit-overlaps.sh
#
# THE QUESTIONS ONLY A MAC CAN ANSWER. Which window lies in front is macOS's business, and the stand-ins play it only in part:
#   1. after the second key both are in view, each flush with its outer side, and THE ONE THE KEY NAMED LIES IN FRONT;
#   2. a real click on the one behind brings it forward, and no window moves or changes its size for it, then or a moment later;
#   3. each window moves once at each key (jolts.py reads sixty samples a second);
#   4. nothing of Arbor's is drawn over a window: no handle, no tile;
#   5. a gap dragged with the real pointer until it lies under a window goes on following the pointer: its handle is what hears the mouse.
# The pictures to look at: <nnn>-dock-left.jpg, <nnn>-dock-right.jpg, <nnn>-click-the-one-behind.jpg, <nnn>-click-back.jpg.
#
# Only on GitHub's Macs: it opens real apps, quits them, and changes the display's size.
export DAY_KEEP_PICTURES=1
source "$(dirname "${BASH_SOURCE[0]}")/lib-day.sh"
needs_throwaway_mac "open two real apps, quit them, and switch the display's size"
apps_watchdog 800

step "the Mac"
echo "macOS $(sw_vers -productVersion) ($(sw_vers -buildVersion)) on $(uname -m)"
day_build
# The runner's own 1024×768 is smaller than any Mac's. On each of these the two do not fit.
display_mode 1344x756 1280x800
day_scratch
sampler_start

# x, and x + width, as the window server has the window.
left_of_it() { local x y w h; read -r x y w h <<< "$(real_of "$1")"; echo "$x"; }
right_of_it() { local x y w h; read -r x y w h <<< "$(real_of "$1")"; echo $((x + w)); }
width_of_it() { local x y w h; read -r x y w h <<< "$(real_of "$1")"; echo "$w"; }
# What `state` says of how far a window hangs over its place, in width; nothing if it says nothing.
over_by() {
  ctl state | python3 -c '
import json, sys
state = json.load(sys.stdin)["state"]
for window in state["windows"]:
    if window["id"] == int(sys.argv[1]) and window.get("overItsPlaceBy"):
        print(round(window["overItsPlaceBy"][0]))' "$1"
}
they_overlap() { [ "$(right_of_it "$1")" -gt "$(left_of_it "$2")" ]; }
# Whether the first of the two is what a press in the middle of where they overlap would land on.
lies_in_front() {
  local x y w h from to
  from=$(left_of_it "$W_settings") to=$(right_of_it "$W_notes")
  read -r x y w h <<< "$(real_of "$1")"
  [ "$(apptool top-at $(((from + to) / 2)) $((y + h / 2)) | cut -d ' ' -f 1)" = "$1" ]
}
same_frames() { [ "$(real_of "$W_notes") $(real_of "$W_settings")" = "$1" ]; }

open_app() {
  local name=$1 bundle=$2
  shift 2
  act open-close "open-$name" "opens $name"
  APP_WAIT=25 APP_OPEN_LIMIT=90 meet "$name" "$bundle" "$@" || echo "$name opened no standard window"
  app_dismiss "$APP_PID" || echo "a sheet or dialog stayed in the way"
  acted setup=1
}

chapter "Before Arbor: two apps are open"
open_app notes com.apple.Notes
open_app settings com.apple.systempreferences

chapter "The coach's first two keys"
act quit-and-start launch "starts Arbor"
day_launch || die "Arbor did not start"
acted moves=none everything=1
# It comes a moment after the start.
welcome=""
for _ in 1 2 3 4 5 6 7 8 9 10; do
  welcome=$(arbor_window)
  [ -z "$welcome" ] || break
  sleep 0.3
done
if [ -n "$welcome" ]; then
  act open-close close-welcome "closes Arbor's welcome window with its red button"
  # shellcheck disable=SC2046
  must click $(apptool button "$welcome" close)
  acted
fi
echo "windowsThatDoNotFit: $(ctl get windowsThatDoNotFit 2>&1 | tail -n 1)"

act switch click-notes "clicks Notes' title bar"
must click_window "$W_notes"
acted front="$W_notes"

act dock-key dock-left "presses ⌃⌥←"
key ctrl+opt+left
want "Notes is docked" eventually is docked "$W_notes"
acted moves="$W_notes" first=1 front="$W_notes"
echo "Notes: $(real_of "$W_notes")"

act switch click-settings "clicks System Settings' title bar"
must click_window "$W_settings"
acted front="$W_settings"

act dock-key dock-right "presses ⌃⌥→"
key ctrl+opt+right
want "System Settings is docked" eventually is docked "$W_settings"
want "Notes is in view" in_view "$W_notes"
want "System Settings is in view" in_view "$W_settings"
want "neither is parked" test -z "$(ctl state | grep -c '"parked" *: *true' | grep -v '^0$')"
want "they overlap" they_overlap "$W_notes" "$W_settings"
want "state says that one of them hangs over its place" test -n "$(over_by "$W_notes")$(over_by "$W_settings")"
want "the one the key named lies in front" lies_in_front "$W_settings"
acted moves="$W_notes,$W_settings" docked="$W_notes,$W_settings" front="$W_settings" everything=1
echo "Notes: $(real_of "$W_notes") over by '$(over_by "$W_notes")'; System Settings: $(real_of "$W_settings") over by '$(over_by "$W_settings")'"
echo "Arbor's own windows: $(overlays | tr '\n' ';')"
brief
frames="$(real_of "$W_notes") $(real_of "$W_settings")"

chapter "Which lies in front later is macOS's business"
act switch click-the-one-behind "clicks the part of Notes that shows"
must click_window "$W_notes"
want "Notes lies in front" eventually lies_in_front "$W_notes"
want "no window has moved or changed its size" stays same_frames "$frames"
acted moves=none front="$W_notes" everything=1

act switch click-back "clicks the part of System Settings that shows"
must click_window "$W_settings"
want "System Settings lies in front" eventually lies_in_front "$W_settings"
want "no window has moved or changed its size" stays same_frames "$frames"
acted moves=none front="$W_settings" everything=1

act switch cmd-tab "presses ⌘Tab"
cmd_tab
want "Notes lies in front" eventually lies_in_front "$W_notes"
want "no window has moved or changed its size" stays same_frames "$frames"
acted moves=none front="$W_notes" everything=1

act idle idle "does nothing for ten seconds"
idle 10
want "no window has moved or changed its size" same_frames "$frames"
acted moves=none everything=1

chapter "Framed and back, and one step back"
act view frame "presses ⌃⌥↩"
key ctrl+opt+return
acted moves=docked leaves=any
act view frame-again "and again"
key ctrl+opt+return
want "the overlap is as it was" eventually same_frames "$frames"
acted moves=docked everything=1

act way-out undo "takes the last dock back"
ctl undo
want "System Settings floats" eventually is floating "$W_settings"
acted moves="$W_notes,$W_settings" restores="$W_settings" everything=1
echo "Notes: $(real_of "$W_notes"); System Settings: $(real_of "$W_settings")"

act dock-key redo "and docks it again"
ctl redo
want "the overlap is as it was" eventually same_frames "$frames"
acted moves="$W_notes,$W_settings" everything=1

chapter "It ends when the neighbour goes"
act dock-key float-settings "floats System Settings"
ctl float "$W_settings"
want "nobody hangs over" test -z "$(over_by "$W_notes")$(over_by "$W_settings")"
acted moves="$W_notes,$W_settings" restores="$W_settings" everything=1

chapter "The option: the tile, as it was"
act dock-key tile "asks for tiles, and docks System Settings at the right"
ctl set windowsThatDoNotFit tile
ctl dock "$W_settings" right
want "one of the two is out of view" test "$(ctl state | grep -c '"parked" *: *true')" -ge 1
acted moves="$W_notes,$W_settings" tiles=ok leaves=any
act dock-key overlap-again "asks for the overlap again"
ctl set windowsThatDoNotFit overlap
want "the overlap is as it was" eventually same_frames "$frames"
acted moves="$W_notes,$W_settings" everything=1

chapter "A gap dragged until it lies under a window"
act dock-key float-settings-again "floats System Settings"
ctl float "$W_settings"
acted moves="$W_notes,$W_settings" restores="$W_settings" everything=1
notes_was=$(real_of "$W_notes")
read -r _ ny _ nh <<< "$notes_was"
gap_x=$(($(right_of_it "$W_notes") + 6))
act resize drag-the-gap "drags the gap at the right of Notes 300 points to the left"
# Near the foot of the gap: what floats again lies over its middle.
must drag "$gap_x" $((ny + nh - 12)) $((gap_x - 300)) $((ny + nh - 12))
want "Notes is in view" in_view "$W_notes"
want "Notes stands where it stood, as large" test "$(real_of "$W_notes")" = "$notes_was"
echo "Notes: $(real_of "$W_notes") over by '$(over_by "$W_notes")'"
want "the gap followed the pointer under the window: the place is some 300 points short" test "0$(over_by "$W_notes")" -ge 250
acted moves="$W_notes" everything=1
act idle idle-after-the-drag "does nothing for three seconds"
idle 3
echo "Arbor's own windows: $(overlays | tr '\n' ';')"
want "nothing has moved" test "$(real_of "$W_notes")" = "$notes_was"
acted moves=none everything=1

chapter "The way out"
act quit-and-start quit "quits Arbor"
ctl quit
want "Arbor ends within five seconds" day_gone
day_forgets
acted moves=any restores=all everything=1

day_report
