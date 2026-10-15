#!/bin/bash
# The films of the first column of docs/POLISH.md: what ships, act by act; and macOS's own tiling of the same windows, which is the bar.
#
#   scripts/mac-shell/rehearse.sh scripts/mac-shell/films-light.sh    on Linux, first, for nothing
#   scripts/mac-shell/run.sh scripts/mac-shell/films-light.sh         about ten minutes on a hosted Mac
#   scripts/polish/judge.py acts .mac-shell/films-light-<run id>      anywhere, afterwards: the numbers of every act
#   scripts/polish/judge.py score .mac-shell/films-light-<run id>     the table and the score
#
# Arbor ships without motion: windows go to their places at once, and nothing stands in for them. So the real windows are seen going: each is another app's, is
# asked for its place and its size one after the other, and obeys when it gets round to it. What only a Mac can answer: in how many pieces an act
# arrives, how long it takes from the first change on the display to the last, and whether anything is seen on the way that is worse than a frame's delay: a hole, an empty desk,
# a window over what neither its old frame nor its new one covers. The bar is macOS alone: its own tiling, chosen from the Window menu, of the same windows, with Arbor not running.
#
# Whatever of the second build's defaults the commit under test does not ship yet is written out (`second_build`), and said to be: from the day a default lands the film is of what ships.
# The keys are asked of Arbor (`bindings`), so the films follow the map in effect.
ARBOR_TIME_LIMIT=1000
source "$(dirname "$0")/lib-film.sh"
needs_throwaway_mac "film the whole display, and change Reduce Motion, the appearance, the wallpaper and the display's size"

second_build
FACE="ARBOR_NO_HOTKEYS=0 ARBOR_NO_STATUS_ITEM=0 ARBOR_PANELS_IN_PICTURES=1"

press() {
  # shellcheck disable=SC2046
  click $(titlebar_of "$1")
  sleep 0.6
}

# act <name> "<what the person does>" <key>: one key, one film. Without a key there is no such act as it ships, and no film: said aloud, since the scenes after it begin elsewhere than they think.
act() {
  check "$1: a key does that in the map in effect" test -n "$3" || return 0
  scene "$1" instant "$2 ($3)"
  key "$3"
  scene_end 1.6
}

# between <command…>: the same key off film, to set the next scene.
between() {
  local chord
  chord=$(key_for "$@")
  check "a key for $* in the map in effect" test -n "$chord" || return 0
  key "$chord"
  sleep 1.3
}

# from_menu <name> "<what the person does>" <item>: the menu is opened off the record of causes, its frame is noted (macOS fades it out over whatever moves beneath, and the judge looks beside it),
# and the click on the item is the cause.
from_menu() {
  local point
  scene "$1" instant "$2"
  open_menu
  sleep 0.8
  film_overlays held
  if point=$(eventually "$ARBOR_POINTER" menu-item "$ARBOR_PID" "$3"); then
    # shellcheck disable=SC2086
    click $point
  else
    echo "from_menu $1: no item $3"
    key escape
  fi
  scene_end 1.8
}

# Floating windows that lie beside one another.
spread() {
  ctl float-all
  sleep 1
  tell 4 "move $W4 40 70 300 200"
  tell 1 "move $W1 400 70 300 190"
  tell 2 "move $W2 400 285 300 190"
  tell 3 "move $W3 400 500 300 190"
  sleep 1.5
}

# Two columns of two: W4 over W2 on the left, W3 over W1 on the right.
arrange() {
  ctl float-all
  sleep 1
  ctl dock "$W4" left
  ctl dock "$W3" right
  ctl dock "$W2" beside "$W4" bottom
  ctl dock "$W1" beside "$W3" bottom
  sleep 1.5
}

# acts <prefix>: what the gate asks for, from four floating windows.
acts() {
  local p=$1 x y w h
  spread
  press "$W4"
  act "${p}dock-first" "docks a floating window at the left: the first dock" "$(key_for dock left)"
  press "$W3"
  act "${p}dock-second" "docks a second window at the right" "$(key_for dock right)"

  arrange
  press "$W4"
  act "${p}fill" "fills the screen with a docked window" "$(key_for zoom)"
  act "${p}everything" "shows everything again" "$(key_for show-all)"
  between zoom
  act "${p}back" "goes back" "$(key_for back)"
  press "$W1"
  act "${p}float" "floats a docked window" "$(key_for toggle-float)"
  act "${p}undo" "undoes that" "$(key_for undo)"
  between toggle-float
  act "${p}float-back" "takes the floating window back in" "$(key_for toggle-float)"
  act "${p}pause" "pauses Arbor: every window gets its own size back" "$(key_for toggle-pause)"
  act "${p}resume" "resumes" "$(key_for toggle-pause)"

  scene "${p}go-to" panel "opens Go to…, then ⎋"
  key "$(key_for find)"
  sleep 1.5
  key escape
  scene_end 1.5
  press "$W4"
  between zoom
  between find
  key down
  sleep 0.3
  scene "${p}go-to-choose" instant "in Go to…, with another window chosen, presses ↩"
  key return
  scene_end 1.6
  between show-all

  scene "${p}menu" panel "clicks Arbor's icon in the menu bar, then ⎋"
  # With the left button, which the camera's tap sees: the opening is what is judged first.
  # shellcheck disable=SC2046
  click $(status_item)
  sleep 1.2
  key escape
  scene_end 1.5
  spread
  from_menu "${p}menu-arrange" "chooses Arrange Windows from the menu: four floating windows at once" "Arrange Windows"

  # One docked window at the left, three floating ones.
  spread
  ctl dock "$W4" left
  sleep 1.5
  read -r x y w h <<< "$(frame_of "$W4")"
  scene "${p}drag-plain" plain "drags a floating window over a docked one, waits, lets go: a plain drag"
  # shellcheck disable=SC2046
  hold_drag $(titlebar_of "$W1") $((x + w - 100)) $((y + h / 2)) --duration 0.8
  scene_end 1.6
  spread
  ctl dock "$W4" left
  sleep 1.5
  read -r x y w h <<< "$(frame_of "$W4")"
  scene "${p}drag-held" drop "does the same with ⌘ held: asks Arbor to dock it there"
  # shellcheck disable=SC2046
  hold_drag $(titlebar_of "$W1") $((x + w - 100)) $((y + h / 2)) --duration 0.8 --mods cmd
  scene_end 1.6
  arrange
  scene "${p}drag-out" out "drags a docked window out by its title bar and lets go over the middle: a plain drag"
  # shellcheck disable=SC2046
  hold_drag $(titlebar_of "$W1") 512 300 --duration 0.8
  scene_end 1.6
}

# macos <name> <n> "<what the person does>" <item> [<item of its submenu>]: macOS's own tiling of the nth window, from its app's Window menu. System Events presses the item,
# so no key and no button says when: the film's own mark does, to a few hundredths of a second.
macos() {
  local name=$1 app item=$4 inner=${5:-} what
  app=$(cast_name "$2")
  eval "press \"\$W$2\""
  what="menu item \"$item\" of menu \"Window\" of menu bar 1"
  [ -z "$inner" ] || what="menu item \"$inner\" of menu 1 of $what"
  scene "$name" bare "$3"
  if [ -n "${ARBOR_REHEARSAL:-}" ]; then
    echo "> System Events: $app: $item $inner (not rehearsed)"
  else
    arbor_within 10 osascript -e "tell application \"System Events\" to tell process \"$app\" to click $what" > /dev/null \
      || echo "macos $name: System Events could not press $item $inner"
  fi
  scene_end 1.6
}

film_build
cast_build
step "the Mac"
echo "Screen Recording for a child process: $(pointer screen-access)"
pointer displays
macos_reduce_motion off
glass on
macos_tiling
camera_start || die "no camera"
sampler_start
ARBOR_TEST_WINDOWS_ARGS="--regular"
# The fake Mac has no menus of macOS's to fill.
[ -n "${ARBOR_REHEARSAL:-}" ] || ARBOR_TEST_WINDOWS_ARGS="--regular --window-menu"
wallpaper "#000000"

step "1. the camera's own square, right and wrong: whether the judge may be believed"
for kind in good linear slow twice hop flash; do metronome "$kind"; done

# The bare desk: the wallpaper as the display shows it, which the judge cannot tell any more once shadows lie on what is left of it.
scene ground bare "the bare desk"
scene_end 0.3

step "2. four windows, each another app's"
arbor_settings "$LIGHT"
cast_start 4 $FACE
sleep 3
ctl bindings
acts ""
summary

# More docks than the display has room for: every window becomes a tile.
spread
press "$W4"
between dock left
press "$W3"
between dock right
press "$W2"
act dock-third "docks a third window at the right" "$(key_for dock right)"
press "$W1"
act dock-fourth "docks a fourth window at the left" "$(key_for dock left)"
summary
# What is made for the first time takes longer than it ever will again in this session: the same once more.
spread
ctl dock "$W4" left
ctl dock "$W3" right
ctl dock "$W2" right
sleep 1.5
press "$W1"
act dock-fourth-again "docks a fourth window at the left, for the second time in this session" "$(key_for dock left)"

arrange
scene close closes "closes a docked window"
tell 1 "close $W1"
scene_end 1.6
ARBOR_WINDOW_IDS="$W2 $W3 $W4"

trace_ends
scene quit told "quits Arbor: every window gets its own size back"
ctl quit
scene_end 1.6

step "3. macOS alone, the same windows: Arbor is not running"
tell 4 "move $W4 40 70 300 200"
tell 2 "move $W2 400 285 300 190"
tell 3 "move $W3 400 500 300 190"
sleep 1.5
macos macos-left 4 "chooses Window ▸ Move & Resize ▸ Left" "Move & Resize" "Left"
macos macos-right 3 "chooses Window ▸ Move & Resize ▸ Right" "Move & Resize" "Right"
macos macos-fill 4 "chooses Window ▸ Fill" "Fill"
macos macos-previous 4 "chooses Window ▸ Move & Resize ▸ Return to Previous Size" "Move & Resize" "Return to Previous Size"
macos macos-left-and-right 4 "chooses Window ▸ Move & Resize ▸ Left & Right: two windows at once" "Move & Resize" "Left & Right"
cast_stop

step "4. in dark mode, on a light wallpaper"
appearance dark
wallpaper "#b9bec6"
scene dark-ground bare "the bare desk"
scene_end 0.3
arbor_settings "$LIGHT"
cast_start 4 $FACE
sleep 3
acts dark-
cast_stop
appearance light
wallpaper "#000000"

# Arrange Windows has no key: a person chooses it from the menu, which macOS then fades out over whatever moves beneath, and there the ruler cannot look. So each is filmed twice, in a session of its
# own each time, since the first Arrange of a session asks each window for its size where it stands and then moves it, and later ones ask once: as a person does it, for eyes; and by command,
# with nothing over the windows, for the ruler.
# many <prefix> <windows> <columns> <width> <height> <step right> <step down>
many() {
  local p=$1 count=$2 last
  shift 2
  for way in menu told; do
    arbor_settings "$LIGHT"
    # shellcheck disable=SC2086
    cast_start "$count" $FACE
    sleep 3
    eval "last=\$W$count"
    for again in "" -again; do
      ctl float-all
      sleep 1
      grid "$count" "$@"
      press "$last"
      if [ "$way" = menu ]; then
        from_menu "$p-arrange$again" "chooses Arrange Windows: $count floating windows at once${again:+, for the second time in this session}" "Arrange Windows"
      else
        scene "$p-arrange-told$again" told "the same by command, with no menu over the windows${again:+, for the second time in this session}"
        ctl arrange
        scene_end 1.8
      fi
      [ -n "$again" ] || summary
      [ -n "$again" ] || [ "$p" != crowd ] || check "$p-arrange ($way): the display has no room for $count windows: some are tiles" some_tile
    done
    if [ "$way" = menu ] && [ "$p" = eight ]; then
      press "$last"
      act eight-fill "fills the screen with one of eight" "$(key_for zoom)"
      act eight-everything "shows everything again" "$(key_for show-all)"
    fi
    cast_stop
  done
}

some_tile() { summary | grep -q parked; }

# grid <windows> <columns> <width> <height> <step right> <step down>: floating windows that lie beside one another, none over another: the ruler follows a window only while it sees all of it.
grid() {
  local count=$1 columns=$2 w=$3 h=$4 dx=$5 dy=$6 n=1 id
  while [ "$n" -le "$count" ]; do
    eval "id=\$W$n"
    tell "$n" "move $id $((20 + (n - 1) % columns * dx)) $((50 + (n - 1) / columns * dy)) $w $h"
    n=$((n + 1))
  done
  # A word to a test window is not answered: the film waits until each has the size it was sent.
  n=$count
  while [ "$n" -ge 1 ]; do
    eval "id=\$W$n"
    eventually sized "$id" "$w $h" > /dev/null || echo "grid: window $n has not the size it was sent: $(real_frame_of "$id")"
    n=$((n - 1))
  done
  sleep 1.5
}
sized() { case "$(real_frame_of "$1")" in *" $2") ;; *) return 1 ;; esac; }

step "5. eight windows on a large display"
display_size 1920 1080
many eight 8 4 300 200 350 260
display_size 1024 768

step "6. twelve windows on a display that has no room for them"
# What is made for the first time at a new size takes longer than it ever will again: Arrange as the first act of the session that cannot give every window its room, and once more.
many crowd 12 4 230 190 250 225

sampler_stop
camera_stop
