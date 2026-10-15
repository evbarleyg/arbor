#!/bin/bash
# Pictures of Arbor arranging real apps, for the README: mac-shell/readme-*.png, each under 300 KB.
#
#   scripts/mac-shell/run.sh scripts/mac-shell/compat-pictures.sh      then copy the ones you like to docs/images/
#
# Only on GitHub's Macs: it changes the wallpaper and arranges every window there is.
source "$(dirname "${BASH_SOURCE[0]}")/compat.sh"
needs_throwaway_mac "change the wallpaper and the display's size, and arrange every window there is"

# A picture 1200 points wide, with as few colours as it takes to stay under 300 KB.
portrait() {
  local path="$ARBOR_OUT/readme-$1.png"
  sleep 1
  screencapture -x "$path" || return 1
  sips --resampleWidth 1200 "$path" > /dev/null 2>&1
  if [ "$(wc -c < "$path")" -gt 300000 ]; then
    sips -s format jpeg -s formatOptions 80 "$path" --out "${path%.png}.jpg" > /dev/null 2>&1 && rm "$path"
  fi
  ls -l "$ARBOR_OUT"/readme-"$1".* | awk '{ print "picture:", $9, $5 }'
}

# Types lower-case letters, digits and spaces into the frontmost app, then Return.
type_line() {
  local text=$1 index=0 character
  while [ "$index" -lt "${#text}" ]; do
    character=${text:$index:1}
    [ "$character" = " " ] && character=space
    pointer key "$character"
    index=$((index + 1))
  done
  pointer key return
}

# open_app <variable> <app from compat.sh's table>: the window's id goes into the variable
open_app() {
  configure "$2"
  subject_open || echo "note: $2 did not open a window"
  app_dismiss "$P"
  eval "$1=\$S"
}

COMPAT_DISPLAY=1600x900
prepare
companions_stop

step "a wallpaper and something to read"
apps_picture "$APPS_TEMP/wallpaper.png" 1600 900
wallpaper "$APPS_TEMP/wallpaper.png"
cat > "$APPS_SCRATCH/page.html" << 'HTML'
<!doctype html><meta charset="utf-8"><title>Arbor</title>
<body style="font: 19px/1.5 system-ui; margin: 3em auto; max-width: 30em; color: #222233">
<h1 style="font-size: 2.6em; margin: 0">Arbor</h1>
<p>Your real windows dock into nested splits, with the Desktop kept as a space between them, and a camera zooms
between those spaces: frame one window, step out to its group, step out again to see everything.</p>
<p>Drag a window to a screen edge to dock it beside everything you can see, or onto another window's edge to dock beside that window.</p>
</body>
HTML
printf 'Things to try\n\n- dock a window on each side\n- zoom in with ctrl-opt-return\n- step out with ctrl-opt-up\n- quit: everything comes back\n' > "$APPS_SCRATCH/oak.txt"

step "the apps"
open_app SAFARI safari
open_app TERMINAL terminal
open_app FINDER finder
open_app TEXTEDIT textedit
open_app CALCULATOR calculator
open_app SETTINGS settings
if app_focus "$TERMINAL"; then
  type_line clear
  type_line "cal 2026"
fi

arbor_start_apps all ARBOR_NO_HOTKEYS=0 ARBOR_NO_STATUS_ITEM=0 || exit 2
APP=readme
ctl exclude com.apple.systempreferences
apptool minimize "$SETTINGS"

step "docked on both sides, the Desktop between"
ctl dock "$SAFARI" left
ctl dock "$TERMINAL" right
ctl dock "$FINDER" beside "$TERMINAL" bottom
ctl resize "$SAFARI" right 120
brief
move 800 880
portrait arranged

step "a drag onto the lower part of a window, with its preview"
read -r x y w h <<< "$(frame_of "$SAFARI")"
S=$TEXTEDIT
if grab_and_drag "$((x + w / 2))" "$((y + h * 5 / 6))"; then
  portrait drag
  release
fi
brief
portrait docked

step "zoomed in on a group, then on a window"
ctl zoom "$TERMINAL"
portrait zoom-window
ctl out
portrait zoom-group
ctl show-all

step "a window too large for its slot is a tile"
ctl include com.apple.systempreferences
apptool unminimize "$SETTINGS"
sleep 1
ctl show-all
ctl dock "$SETTINGS" beside "$TEXTEDIT" right
ctl show-all
brief
portrait tile

arbor_stop
portrait after-quit
ls -l "$ARBOR_OUT" | awk '{ print $5, $9 }'
