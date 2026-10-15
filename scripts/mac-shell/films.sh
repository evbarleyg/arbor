#!/bin/bash
# The films of the second column of docs/POLISH.md, the options: everything of Arbor's that moves once motion is switched on, done as a person does it, in one run.
# (What ships is films-light.sh's.)
#
#   scripts/mac-shell/rehearse.sh scripts/mac-shell/films.sh      on Linux, first, for nothing
#   scripts/mac-shell/run.sh scripts/mac-shell/films.sh           about a quarter of an hour on a hosted Mac
#   scripts/polish/judge.py score --options .mac-shell/films-<run id>     anywhere, afterwards
#
# What only a Mac can answer: what the display really showed, frame by frame, while Arbor moved things. What the sandbox judges
# afterwards: all of it. The script checks only that its scenes played; it has no opinion on how they looked.
#
# 1. The metronome: the camera and the judge are tried on a motion that is known, right once and wrong in five ways.
# 2. Motion, the ring and the menu bar's buttons on, in so many words (OPTIONS), everything else as it ships, at macOS's default settings (GitHub's Macs come with
#    Reduce Motion and Reduce Transparency on: both are switched off). The moves (below), whether or not they do anything so, then
#    the rest of the camera, peek, a seam, Arbor's own panels, quitting; then docking by key, floating, undo and closing.
# 3. A window too large for its slot: the tile, and opening it.
# 4. The moves again in dark mode, on a light wallpaper, where shadows and dark lines show.
# 5. With Reduce Motion on: the same result at once, and no stage.
# 6. With pictures of the windows (`windowPictures`, which ships off): judged, not counted.
# 7. Eight windows on a large display.
# 8. The moves again, light and dark, with "Trackpad and mouse gestures" on as well, and macOS's own tiling off: where a move was filmed so, that film counts.
ARBOR_TIME_LIMIT=1120
source "$(dirname "$0")/lib-film.sh"
needs_throwaway_mac "film the whole display, and change Reduce Motion, the appearance, the wallpaper and the display's size"

# press <window>: a real click on its title bar, so that it has the keyboard, and a moment for the focus ring to settle.
press() {
  # shellcheck disable=SC2046
  click $(titlebar_of "$1")
  sleep 0.6
}

gone() { ! "$ARBOR_BIN/arborctl" state | python3 "$ARBOR_STATE_PY" frame "$1" > /dev/null 2>&1; }

# Everything in view and at rest, between two scenes.
home() {
  key ctrl+opt+space
  sleep 1.3
}

# Two columns of two: W4 over W2 on the left, W3 over W1 on the right.
arrange() {
  # From nothing, so that the shares are even whatever the scenes before have left.
  ctl float-all
  sleep 1
  ctl dock "$W4" left
  ctl dock "$W3" right
  ctl dock "$W2" beside "$W4" bottom
  ctl dock "$W1" beside "$W3" bottom
  sleep 1.5
}

# moves <prefix> shipped|on: what docs/POLISH.md calls the five moves, as far as Arbor has them, from four floating windows.
# shipped: every switch of Arbor's and of macOS's as it comes. A move that does nothing then is filmed doing nothing: that is its score.
# on: the session has switched Arbor's gestures on and macOS's own tiling off, and every scene has to play.
moves() {
  local p=$1 how=$2 x y w h x2 y2 w2 h2 view
  read -r x y w h <<< "$(screen_of 1)"
  if [ "$how" = shipped ]; then
    # As a person meets it on a Mac as it comes: the edge is macOS's, which tiles the window; Arbor stands aside, and says so.
    scene "${p}dock-drag-edge" aside "drags a window by its title bar to the left edge of the screen, waits, lets go"
    # shellcheck disable=SC2046
    hold_drag $(titlebar_of "$W4") "$x" $((y + h / 2)) --duration 0.8
    scene_end 4
    summary
    ctl dock "$W4" left
    sleep 1.5
  else
    scene "${p}dock-drag-edge" drag "drags a window by its title bar to the left edge of the screen, waits, lets go"
    # shellcheck disable=SC2046
    hold_drag $(titlebar_of "$W4") $((x + 3)) $((y + h / 2)) --duration 0.8
    scene_end
    check "the dragged window docked" is docked "$W4"
  fi

  read -r x y w h <<< "$(frame_of "$W4")"
  scene "${p}dock-drag-beside" drag "drags a window onto the right part of a docked one, waits, lets go"
  # shellcheck disable=SC2046
  hold_drag $(titlebar_of "$W3") $((x + w - 120)) $((y + h / 2)) --duration 0.8
  scene_end
  check "it docked" is docked "$W3"

  arrange
  read -r x y w h <<< "$(frame_of "$W3")"
  scene "${p}rearrange" drag "drags a docked window to the top of the other column, waits, lets go"
  # shellcheck disable=SC2046
  hold_drag $(titlebar_of "$W2") $((x + w / 2)) $((y + 50)) --duration 0.8
  scene_end
  arrange

  press "$W4"
  scene "${p}frame" camera "presses ⌃⌥↩ on a docked window"
  key ctrl+opt+return
  # Long enough to see the line of words go.
  scene_end 6
  check "the framed window is in view" is on_screen "$W4"
  check "another is out of view" is parked "$W1"

  scene "${p}show-everything" camera "presses ⌃⌥Space"
  key ctrl+opt+space
  scene_end
  check "everything is in view" is on_screen "$W1"

  read -r x y w h <<< "$(frame_of "$W4")"
  read -r x2 y2 w2 h2 <<< "$(frame_of "$W2")"
  view=$(view_now)
  scene "${p}rectangle" drag "holds ⌃⌥ and drags a rectangle over the left column"
  drag $((x + 30)) $((y + 60)) $((x2 + w2 - 30)) $((y2 + h2 - 30)) --mods ctrl+opt --duration 0.7 --hold 0.3
  scene_end
  if [ "$how" = shipped ]; then
    # The gesture ships off, so the view is still everything, and a view saved now would be the one ⌃⌥1 is pressed in: nothing would move. The keys do ship.
    press "$W4"
    key ctrl+opt+return
    sleep 1.3
  else
    played "${p}rectangle" "$view"
  fi

  scene "${p}save-view" panel "presses ⌃⌥⇧1"
  key ctrl+opt+shift+1
  scene_end 6
  home
  view=$(view_now)
  scene "${p}view" camera "presses ⌃⌥1"
  key ctrl+opt+1
  scene_end
  played "${p}view" "$view"
  home

  # shellcheck disable=SC2046
  set -- $(center_of "$W3")
  move "$1" "$2"
  view=$(view_now)
  scene "${p}pinch-in" camera "holds ⌥ and spreads two fingers over a window"
  pinch "$1" "$2" 0.8 --opt
  scene_end
  [ "$how" = shipped ] || [ -n "${ARBOR_REHEARSAL:-}" ] || played "${p}pinch-in" "$view"
  view=$(view_now)
  scene "${p}pinch-out" camera "holds ⌥ and pinches"
  pinch "$1" "$2" -0.8 --opt
  scene_end
  [ "$how" = shipped ] || [ -n "${ARBOR_REHEARSAL:-}" ] || played "${p}pinch-out" "$view"
  home
}

# Four floating windows that lie beside one another, and still do once one of them is docked at the left: of windows that
# overlap, the judge's ruler can tell neither where one ends nor which is which.
spread() {
  ctl float-all
  sleep 1
  tell 4 "move $W4 40 70 300 200"
  tell 1 "move $W1 400 70 300 190"
  tell 2 "move $W2 400 285 300 190"
  tell 3 "move $W3 400 500 300 190"
  sleep 1.5
}

# The three moves that say most, for the sessions that differ only in how Arbor is set.
three_moves() {
  spread
  press "$W4"
  scene "$1-dock-key" "$2" "presses ⌃⌥⌘← on a floating window"
  key ctrl+opt+cmd+left
  scene_end
  arrange
  press "$W4"
  scene "$1-frame" "$3" "presses ⌃⌥↩ on a docked window"
  key ctrl+opt+return
  scene_end
  scene "$1-show-everything" "$3" "presses ⌃⌥Space"
  key ctrl+opt+space
  scene_end
}

film_build
cast_build
step "the Mac"
echo "Screen Recording for a child process: $(pointer screen-access)"
pointer displays
macos_reduce_motion off
glass on
macos_tiling
if ! camera_start; then
  echo "the stream gave no frames; trying one picture after another"
  camera_start --poll || die "no camera: neither the stream nor pictures"
fi
sampler_start
# A regular app, as people's apps are: in the Dock and in ⌘⇥.
ARBOR_TEST_WINDOWS_ARGS="--regular"
# Shortcuts on, as a person has them; and the two panels that keep out of shared screens let the camera see them.
FACE="ARBOR_NO_HOTKEYS=0 ARBOR_PANELS_IN_PICTURES=1"
# The options these films are about, in so many words, whatever ships: motion, the ring, the menu bar's buttons.
OPTIONS='"animationDuration": 0.46, "focusRing": true, "menuBarControls": true'

step "1. the metronome"
for kind in good linear slow twice hop flash; do metronome "$kind"; done

step "2. motion, the ring and the buttons on; everything else as it ships"
arbor_settings "{$OPTIONS}"
cast_start 4 $FACE ARBOR_NO_STATUS_ITEM=0
# The Dock grows by an icon, which changes the room there is.
sleep 3
summary

# What macOS alone does with a dragged window, to hold the drags that follow against: ⌘ keeps Arbor out of it.
scene drag-alone bare "drags a floating window a little way with ⌘ held, which Arbor leaves alone"
# shellcheck disable=SC2046
set -- $(titlebar_of "$W4")
drag "$1" "$2" $(($1 - 120)) $(($2 + 90)) --duration 0.8 --mods cmd
scene_end 1

moves "" shipped
summary
shot still-everything

press "$W4"
key ctrl+opt+return
sleep 1.3
scene neighbour camera "presses ⌃⌥→"
key ctrl+opt+right
scene_end

scene back camera "presses ⌃⌥["
key ctrl+opt+[
scene_end

scene out camera "presses ⌃⌥↑"
key ctrl+opt+up
scene_end
home

scene in camera "presses ⌃⌥↓"
key ctrl+opt+down
scene_end
home

# The tool that presses a key takes half a second to start, so the two are started a fifth of a second apart, not one after the other.
scene twice-quickly camera "presses ⌃⌥↩ and, a fifth of a second later, ⌃⌥Space"
key ctrl+opt+return &
sleep 0.2
key ctrl+opt+space
scene_end

press "$W3"
key ctrl+opt+return
sleep 1.3
scene peek hold "holds ⌃⌥Space for two seconds, presses ← meanwhile, lets go"
key ctrl+opt+space --down
sleep 1.2
key ctrl+opt+left --held
sleep 0.8
key ctrl+opt+space --up
scene_end
home

# shellcheck disable=SC2046
set -- $(seam_right_of "$W4")
scene seam drag "drags the seam beside the left column 100 points to the right"
drag "$1" "$2" $(($1 + 100)) "$2" --duration 0.9
scene_end

scene desktop camera "presses ⌃⌥D"
key ctrl+opt+d
scene_end
# This one was seen to stand still for a second half-way. Whether the display did or only the camera's stream: macOS's own
# screenshots, which come another way, are taken beside it.
scene desktop-back camera "presses ⌃⌥["
key ctrl+opt+[ &
film witness-desktop-back 16
scene_end

scene drag-out drag "drags a docked window out by its title bar and drops it over the middle with ⌘ held"
# shellcheck disable=SC2046
drag $(titlebar_of "$W2") 512 330 --duration 0.8 --hold 0.4 --mods cmd
scene_end
ctl dock "$W2" beside "$W4" bottom
sleep 1.5

scene panel-shortcuts panel "presses ⌃⌥⇧/, and again"
key ctrl+opt+shift+/
sleep 1.5
key ctrl+opt+shift+/
scene_end 1.5

scene panel-go-to panel "presses ⌃⌥G, then ⎋"
key ctrl+opt+g
sleep 1.5
key escape
scene_end 1.5

scene panel-minimap panel "presses ⌃⌥M, and again"
key ctrl+opt+m
sleep 1.5
key ctrl+opt+m
scene_end 1.5

# The item is a row of buttons once something is docked; the last one opens the menu. The item centres its image.
read -r ix iy iw ih <<< "$(status_item_frame)"
# Without a frame awk would still print a point: the top left corner, which is the Apple menu.
at=$([ -n "${ih:-}" ] && "$ARBOR_BIN/arborctl" menu-bar | awk -v ix="$ix" -v iy="$iy" -v iw="$iw" -v ih="$ih" '
  { width = $2 + $3 }
  $1 == "menu" { middle = $2 + $3 / 2; found = 1 }
  END { if (!found) exit 1; printf "%d %d\n", ix + (iw - width) / 2 + middle, iy + ih / 2 }') || at=$(status_item)
scene panel-menu panel "clicks the menu bar item's last button, then ⎋"
# shellcheck disable=SC2086
click $at
sleep 1.2
key escape
scene_end 1.5

trace_ends
# Filmed and not scored. Arbor as it ships records nothing; the sessions here do, for whoever looks for a cause. Whether that costs the motion anything
# is seen by holding these two against `frame` and `show-everything`.
arrange
press "$W4"
scene untraced-frame bare "presses ⌃⌥↩ on a docked window, with no trace being recorded"
key ctrl+opt+return
scene_end
scene untraced-show-everything bare "presses ⌃⌥Space"
key ctrl+opt+space
scene_end
scene quit instant "quits Arbor"
ctl quit
scene_end
cast_stop

step "2b. the keys that change the arrangement, on windows that do not overlap"
arbor_settings "{$OPTIONS}"
cast_start 4 $FACE
sleep 3
spread
press "$W4"
scene dock-key structure "presses ⌃⌥⌘← on a floating window"
key ctrl+opt+cmd+left
scene_end
check "the window docked" is docked "$W4"

scene float structure "presses ⌃⌥F on the docked window"
key ctrl+opt+f
scene_end
check "it floats" is floating "$W4"

scene undo structure "presses ⌃⌥Z"
key ctrl+opt+z
scene_end
check "it is docked again" is docked "$W4"

arrange
scene close structure "closes a docked window"
tell 1 "close $W1"
scene_end
check "Arbor has let go of it" eventually gone "$W1"
# arbor_stop looks for every window it knows of.
ARBOR_WINDOW_IDS="$W2 $W3 $W4"
cast_stop

step "3. a window too large for its slot"
ARBOR_TEST_WINDOWS_ARGS="--regular --min-size 3:700x500"
arbor_settings "{$OPTIONS}"
cast_start 3 $FACE
sleep 3
ctl dock "$W1" left
ctl dock "$W2" right
sleep 1.5
press "$W3"
scene tile structure "presses ⌃⌥⌘→ on a window that cannot be as narrow as its slot"
key ctrl+opt+cmd+right
scene_end
summary
if is tile "$W3"; then
  scene tile-open camera "clicks the tile"
  # shellcheck disable=SC2046
  click $(tile_of "$W3")
  scene_end
  scene tile-back camera "presses ⌃⌥["
  key ctrl+opt+[
  scene_end
fi
cast_stop
ARBOR_TEST_WINDOWS_ARGS="--regular"

step "4. dark, on a light wallpaper"
appearance dark
wallpaper "#b9bec6"
arbor_settings "{$OPTIONS}"
cast_start 4 $FACE ARBOR_NO_STATUS_ITEM=0
sleep 3
moves dark- shipped
shot still-dark-everything
cast_stop
appearance light
wallpaper "#000000"

step "5. with Reduce Motion"
macos_reduce_motion on
arbor_settings "{$OPTIONS}"
cast_start 4 $FACE
sleep 3
three_moves reduced instant instant
# Filmed and not scored. With a stage the display stands still in the middle of these three, for up to a second. Whether it does without one
# says where the cause is to be looked for: in the stage and what Arbor does around it, or in macOS.
scene reduced-desktop bare "presses ⌃⌥D"
key ctrl+opt+d
scene_end
scene reduced-desktop-back bare "presses ⌃⌥["
key ctrl+opt+[
scene_end
press "$W4"
key ctrl+opt+return
sleep 1.3
scene reduced-neighbour bare "presses ⌃⌥→"
key ctrl+opt+right
scene_end
check "no stage was ever put up" test -z "$(grep "stage up" "$ARBOR_HOME/arbor.log")"
cast_stop
macos_reduce_motion off

step "6. with pictures of the windows"
arbor_settings "{$OPTIONS, \"windowPictures\": true}"
cast_start 4 $FACE
sleep 3
three_moves pictures structure camera
cast_stop

step "7. eight windows on a large display"
display_size 1920 1080
arbor_settings "{$OPTIONS}"
cast_start 8 $FACE
sleep 3
ctl arrange
sleep 1.5
summary
press "$W8"
scene eight-frame camera "presses ⌃⌥↩ with eight windows docked"
key ctrl+opt+return
scene_end
scene eight-show-everything camera "presses ⌃⌥Space"
key ctrl+opt+space
scene_end
cast_stop

display_size 1024 768

step "8. the moves with everything on: Arbor's gestures, and every edge Arbor's"
macos_tiling off
arbor_settings "{$OPTIONS, $ARBOR_GESTURES_ON}"
cast_start 4 $FACE ARBOR_NO_STATUS_ITEM=0
sleep 3
moves on- on
cast_stop
appearance dark
wallpaper "#b9bec6"
arbor_settings "{$OPTIONS, $ARBOR_GESTURES_ON}"
cast_start 4 $FACE ARBOR_NO_STATUS_ITEM=0
sleep 3
moves on-dark- on
cast_stop
appearance light
wallpaper "#000000"
macos_tiling on

sampler_stop
camera_stop
