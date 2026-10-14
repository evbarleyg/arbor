#!/bin/bash
# An ordinary day: the rehearsal of the acceptance pass. Real apps, macOS at its default settings, Arbor as a person runs it,
# and every frame of every window written down meanwhile.
#
#   scripts/mac-shell/run.sh scripts/mac-shell/day.sh          on one of GitHub's Macs, from anywhere (`make day`): ten minutes
#
# A release is decided by half an hour on a person's ordinary Mac: no jolts, no lost or stuck window, nothing moved that they
# did not move. This plays such a day: the apps are open already when Arbor starts; windows are docked by key and by real
# drags; apps are switched with ⌘Tab, the Dock and the Window menu; ⌘H, ⌘M, ⌘W, ⌘N, ⌘Q; full screen; the view goes in and out;
# a click lands on the wallpaper; pause, Float All, Quit, and a second launch. macOS's own tiling and "click wallpaper to
# reveal desktop" stay as they come, which is on. Each step is one thing a person does and says what that may move
# (lib-day.sh); jolts.py then reads the samples and says which step broke which rule.
#
# What comes back in .mac-shell/day-<run>/: day-report.md (the findings per rule, each with the step that shows it, then every
# step with what moved and how often), day-findings.json, samples.log, and for every step with a finding its picture
# <nnn>-<slug>.jpg and its story <nnn>-<slug>.story.log: what the screen showed, what macOS reported and what Arbor logged, in order.
#
# run.sh hands a script no arguments and no environment, so each way of playing the day is a script of three lines that sets a variable:
# DAY_WITHOUT_ARBOR=1 (day-control.sh) plays the same day without Arbor, leaving out the steps that are Arbor's own keys: what is found
# then is macOS's doing or an app's, and no fault of Arbor's when it shows up in the real day too.
# DAY_TILING=off (day-off.sh) plays it with macOS's own window management switched off: edges, menu bar, ⌥, the wallpaper click.
# DAY_REDUCE_MOTION=on (day-still.sh) leaves Reduce Motion on, as the runners come: then Arbor puts up no stage, and every move of every window shows.
# DAY_DISPLAY=desk plays it at 1920×1080 instead of a laptop's 1440×900 or the nearest on offer. DAY_KEEP_PICTURES=1 keeps every step's picture.
#
# Only on GitHub's Macs: it quits apps, closes windows, clicks in the Dock and on the wallpaper, and changes the display's size.
source "$(dirname "${BASH_SOURCE[0]}")/lib-day.sh"
needs_throwaway_mac "open a dozen real apps, press ⌘Q and ⌘W in them, click in the Dock and on the wallpaper, and switch the display's size"

CAST=""
with_arbor() { [ -z "${DAY_WITHOUT_ARBOR:-}" ]; }

bundle_of() {
  case "$1" in
    finder) echo com.apple.finder ;;
    safari) echo com.apple.Safari ;;
    textedit) echo com.apple.TextEdit ;;
    terminal) echo com.apple.Terminal ;;
    notes) echo com.apple.Notes ;;
    calendar) echo com.apple.iCal ;;
    settings) echo com.apple.systempreferences ;;
    preview) echo com.apple.Preview ;;
    mail) echo com.apple.mail ;;
  esac
}

window_of() { eval "echo \"\${W_$1:-}\""; }
pid_of() { eval "echo \"\${P_$1:-}\""; }

# Before Arbor runs nothing is judged: apps place and size their own windows as they open.
open_app() {
  local name=$1
  shift
  act open-close "open-$name" "opens $name"
  if APP_WAIT=25 meet "$name" "$(bundle_of "$name")" "$@"; then
    app_dismiss "$APP_PID" || echo "a sheet or dialog stayed in the way"
    CAST="$CAST $name"
  else
    echo "$name opened no standard window: the day goes on without it"
    [ -n "$APP_PID" ] && apptool tree "$APP_PID" 3 | head -n 20
  fi
  acted judge=no
}

# The way a person gets at a window: its title bar if that shows, otherwise its app's icon in the Dock.
reach() {
  local name=$1 window
  shift
  window=$(window_of "$name")
  act switch "reach-$name" "clicks $name's title bar, or its Dock icon if that is covered"
  click_window "$window" || must dock_click "$(bundle_of "$name")"
  acted front="$window" "$@"
}

# One of Arbor's shortcuts, pressed.
press() {
  local kind=$1 slug=$2 keys=$3 chord=$4
  shift 4
  act "$kind" "$slug" "presses $keys"
  key "$chord"
  acted "$@"
}

front_pid() { apptool front | cut -d ' ' -f 1; }

# MARK: The Mac

apps_watchdog "${DAY_LIMIT:-1060}"
step "the Mac"
echo "macOS $(sw_vers -productVersion) ($(sw_vers -buildVersion)) on $(uname -m)"
day_build
# The runner's own 1024×768 is smaller than any Mac's.
case "${DAY_DISPLAY:=laptop}" in
  laptop) display_mode 1440x900 1600x900 1680x1050 1920x1080 ;;
  desk) display_mode 1920x1080 ;;
  *) die "DAY_DISPLAY: laptop or desk, not $DAY_DISPLAY" ;;
esac
case "${DAY_TILING:=defaults}" in
  defaults)
    echo "macOS's own window management, as it comes:"
    macos_tiling
    macos_click_wallpaper ;;
  off)
    echo "macOS's own window management, switched off:"
    defaults write com.apple.WindowManager EnableTilingOptionAccelerator -bool false
    macos_tiling off
    macos_click_wallpaper off ;;
  *) die "DAY_TILING: defaults or off, not $DAY_TILING" ;;
esac
# GitHub's Macs come with Reduce Motion on. A person's Mac does not, and with it on Arbor shows no motion.
macos_reduce_motion "${DAY_REDUCE_MOTION:-off}"
day_scratch
sampler_start
watch_start day-macos.log

# MARK: The day

chapter "Before Arbor: the apps are open already"
open_app finder "$DAY_DOCUMENTS/$APPS_CANARY-grove"
open_app safari "$DAY_DOCUMENTS/$APPS_CANARY-page.html"
open_app textedit "$DAY_DOCUMENTS/$APPS_CANARY-oak.txt"
open_app terminal
open_app notes
open_app calendar
open_app settings
open_app preview "$DAY_DOCUMENTS/$APPS_CANARY-leaf.png"
open_app mail
# The Dock grows with every app that joins it, and the space between it and the menu bar shrinks.
sleep 3
# An app may have swapped the window it opened with for another meanwhile: Mail's first one gives way to its real one.
for name in $CAST; do
  listed=$(app_windows "$(pid_of "$name")")
  case " $listed " in
    *" $(window_of "$name") "*) ;;
    *) [ -z "$listed" ] || { eval "W_$name=\${listed%% *}"; label "$(window_of "$name")" "$name"; } ;;
  esac
done
echo "the cast:$CAST"
# shellcheck disable=SC2086
set -- $CAST
[ $# -ge 6 ] || die "only $# apps opened a window: no day to speak of"
# "Windows come and go" and "Full screen" are played in these two.
[ -n "$(window_of safari)" ] && [ -n "$(window_of textedit)" ] || die "Safari or TextEdit opened no window: no day to speak of"
# Five that get docked in the course of the day, and one that floats all day.
NA=$1 NB=$2 NC=$3 ND=$4 NE=$5 NX=$6
A=$(window_of "$NA") B=$(window_of "$NB") C=$(window_of "$NC") D=$(window_of "$ND") E=$(window_of "$NE") X=$(window_of "$NX")
echo "docked in the course of the day: $NA $NB $NC $ND $NE; floating all day: $NX and the rest"

# A switch that is written and not obeyed proves nothing: before anything counts, macOS is seen to fill the screen, or not to.
read -r _ dx dy dw dh _ <<< "$(pointer displays | head -n 1)"
fills_the_display() {
  local x y w h
  read -r x y w h <<< "$(real_of "$1")"
  [ "${w:-0}" -ge $((dw - 40)) ] && [ "${h:-0}" -ge $((dh - 160)) ]
}
act drag-where-macos-tiles tiling-acts "without Arbor: drags $NX by its title bar against the menu bar and lets go"
click_window "$X" || dock_click "$(bundle_of "$NX")"
must drag_window "$X" "$((dx + dw / 2))" "$dy" --hold 1
acted judge=no
if eventually fills_the_display "$X"; then TILING_SEEN=true; else TILING_SEEN=false; fi
echo "$NX is at $(real_frame_of "$X"): macOS's tiling was seen to act: $TILING_SEEN"
if [ "$DAY_TILING" = defaults ]; then check "macOS's own tiling acts" test "$TILING_SEEN" = true; else check "macOS's own tiling is off" test "$TILING_SEEN" = false; fi
act drag-where-macos-tiles tiling-acts-back "drags it away again, a hand's breadth down"
must drag_window "$X" "$((dx + dw / 2))" "$((dy + 130))"
acted judge=no

act idle look-around "looks at the screen"
sleep 2
acted judge=no own=all
day_manifest kind "\"$(with_arbor && echo day || echo control)\""
day_manifest tiling "\"$DAY_TILING\""
day_manifest tiling_seen_to_act "$TILING_SEEN"
day_manifest display "\"$DAY_DISPLAY\""
day_manifest cast '"stock"'
day_manifest apps "[$(for name in $CAST; do printf '"%s",' "$(bundle_of "$name")"; done | sed 's/,$//')]"
apptool apps | sed 's/^/  /'

chapter "Arbor starts"
if with_arbor; then
  act quit-and-start launch "starts Arbor"
  day_launch || die "Arbor did not start"
  acted
  for name in $CAST; do
    check "$name's window is arranged, and floats" is floating "$(window_of "$name")"
  done
  # What Arbor has to say at its first start lies in the middle of the screen, over the windows. A person reads it and closes it.
  welcome=$(arbor_window)
  if [ -n "$welcome" ]; then
    act open-close close-welcome "closes Arbor's welcome window with its red button"
    # shellcheck disable=SC2046
    must click $(apptool button "$welcome" close)
    acted
  fi
fi
act idle leave-alone "does nothing for half a minute"
idle 30
acted

chapter "Switching between apps, nothing docked yet"
for name in $CAST; do
  act switch "dock-icon-$name" "clicks $name's icon in the Dock"
  must dock_click "$(bundle_of "$name")"
  acted front="$(main_window_of "$(pid_of "$name")")"
done
act switch cmd-tab "presses ⌘Tab"
before=$(front_pid)
cmd_tab
sleep 0.5
want "another app came to the front" test "$(front_pid)" != "$before"
acted front="$(main_window_of "$(front_pid)")"
act switch cmd-tab-twice "holds ⌘ and presses Tab twice"
cmd_tab 2
sleep 0.5
acted front="$(main_window_of "$(front_pid)")"

if with_arbor; then
  chapter "The first docks, by key"
  reach "$NA"
  press dock-key "dock-$NA-left" "⌃⌥⌘←" ctrl+opt+cmd+left moves=docked front="$A"
  check "$NA is docked" is docked "$A"
  reach "$NB"
  press dock-key "dock-$NB-right" "⌃⌥⌘→" ctrl+opt+cmd+right moves=docked front="$B"
  check "$NB is docked" is docked "$B"
  reach "$NC"
  press dock-key "dock-$NC-right" "⌃⌥⌘→" ctrl+opt+cmd+right moves=docked front="$C"
  check "$NC is docked" is docked "$C"
  brief | sed 's/^/    /'

  chapter "Docking by real drags"
  reach "$ND"
  read -r x y w h <<< "$(frame_of "$A")"
  act drag "drag-$ND-onto-$NA" "drags $ND by its title bar onto the right part of $NA and lets go"
  must drag_window "$D" "$((x + w * 5 / 6))" "$((y + h / 2))"
  want "$ND is docked" eventually is docked "$D"
  acted drags="$D" moves=docked front="$D"
  if read -r x y w h <<< "$(arbor_ask desktop 2>/dev/null)" && [ -n "${w:-}" ]; then
    act drag "drag-$ND-out" "drags $ND out of the arrangement onto the Desktop and lets go"
    must drag_window "$D" "$((x + w / 2))" "$((y + h / 3))"
    want "$ND floats" eventually is floating "$D"
    # Its own size again, and where it was dropped is its own place from now on.
    acted drags="$D" moves=docked front="$D" restores="$D" place="$D"
  fi
  brief | sed 's/^/    /'
fi

if with_arbor; then
  chapter "Sizes"
  reach "$NA"
  read -r x y <<< "$(seam_right_of "$A")"
  act resize "drag-gap-beside-$NA" "drags the gap to the right of $NA sixty points to the right"
  drag "$x" "$y" "$((x + 60))" "$y"
  acted moves=docked
  press resize "grow-$NA" "⌃⌥⌘=" ctrl+opt+cmd+= moves=docked front="$A"
  press resize "shrink-$NA" "⌃⌥⌘-" ctrl+opt+cmd+- moves=docked front="$A"
  press resize balance "⌃⌥⌘0" ctrl+opt+cmd+0 moves=docked front="$A"
fi

chapter "Switching between apps, with an arrangement"
HOME_STEP=$DAY_STEP
for name in $CAST; do
  act switch "dock-icon-$name-2" "clicks $name's icon in the Dock"
  must dock_click "$(bundle_of "$name")"
  acted front="$(main_window_of "$(pid_of "$name")")"
done
act switch cmd-tab-2 "presses ⌘Tab"
cmd_tab
sleep 0.5
acted front="$(main_window_of "$(front_pid)")" returns="$HOME_STEP"

if with_arbor; then
  chapter "The view goes in and out"
  reach "$NA"
  HOME_STEP=$DAY_STEP
  press view "frame-$NA" "⌃⌥↩" ctrl+opt+return moves=any front="$A"
  act switch "dock-icon-$NB-while-framed" "clicks $NB's icon in the Dock, whose window is out of view"
  must dock_click "$(bundle_of "$NB")"
  acted moves=any front="$B"
  act switch cmd-tab-while-framed "presses ⌘Tab, back to $NA"
  cmd_tab
  acted moves=any front="$A"
  act switch "dock-icon-$NX-while-framed" "clicks $NX's icon in the Dock, whose window floats and is out of view"
  must dock_click "$(bundle_of "$NX")"
  acted moves=any front="$X"
  press view show-everything "⌃⌥Space" ctrl+opt+space moves=any everything=1 tiles=ok returns="$HOME_STEP"
  reach "$NB"
  press view "frame-$NB" "⌃⌥↩" ctrl+opt+return moves=any front="$B"
  press view neighbour-left "⌃⌥←" ctrl+opt+left moves=any
  press view back "⌃⌥[" "ctrl+opt+[" moves=any front="$B"
  press view step-out "⌃⌥↑" ctrl+opt+up moves=any
  press view show-desktop "⌃⌥D" ctrl+opt+d moves=any
  press view show-everything-2 "⌃⌥Space" ctrl+opt+space moves=any everything=1 tiles=ok returns="$HOME_STEP"
fi

chapter "Windows come and go"
reach safari
HOME_STEP=$DAY_STEP
known=$(app_windows "$P_safari")
act open-close new-window "presses ⌘N in Safari"
key cmd+n
app_await_window "$P_safari" "$known" 8 && label "$NEW_WINDOW" safari-new
acted front="$NEW_WINDOW"
N=$NEW_WINDOW
if [ -n "$N" ]; then
  act switch window-menu "chooses Safari's first window in the Window menu"
  must window_menu "$W_safari"
  acted front="$W_safari"
  act switch cmd-backtick "presses ⌘\` for Safari's other window"
  key 'cmd+`'
  acted front="$N"
  act open-close close-window "presses ⌘W"
  key cmd+w
  acted leaves="$N" returns="$HOME_STEP"
fi
if with_arbor; then
  reach safari
  press view frame-safari "⌃⌥↩" ctrl+opt+return moves=any front="$W_safari"
  known=$(app_windows "$P_safari")
  act open-close new-window-while-framed "presses ⌘N in Safari while its window is framed"
  key cmd+n
  app_await_window "$P_safari" "$known" 8 && label "$NEW_WINDOW" safari-new-2
  acted moves=any front="$NEW_WINDOW"
  N=$NEW_WINDOW
  # Without a new window ⌘W would close the framed one.
  if [ -n "$N" ]; then
    act open-close close-window-while-framed "presses ⌘W"
    key cmd+w
    acted moves=any leaves="$N"
  fi
  press view show-everything-3 "⌃⌥Space" ctrl+opt+space moves=any everything=1 tiles=ok returns="$HOME_STEP"
fi

reach "$NB"
HOME_STEP=$DAY_STEP
act open-close "minimize-$NB" "presses ⌘M"
key cmd+m
acted moves=docked leaves="$B"
act open-close "restore-$NB" "clicks its miniature in the Dock"
if read -r x y <<< "$(apptool dock-window "$B" 2>/dev/null)" && [ -n "${x:-}" ]; then click "$x" "$y"; move "$x" "$((y - 200))"; else echo "no miniature in the Dock"; apptool unminimize "$B"; fi
acted moves=docked comes="$B" front="$B" returns="$HOME_STEP"

reach "$NA"
HOME_STEP=$DAY_STEP
act open-close "hide-$NA" "presses ⌘H"
key cmd+h
acted moves=docked leaves="$A"
act open-close "unhide-$NA" "clicks its icon in the Dock"
must dock_click "$(bundle_of "$NA")"
acted moves=docked comes="$A" front="$A" returns="$HOME_STEP"

reach textedit
HOME_STEP=$DAY_STEP
act open-close quit-textedit "presses ⌘Q in TextEdit"
key cmd+q
arbor_await_exit "$P_textedit" 50 && apps_forget "$P_textedit"
acted moves=docked leaves="$W_textedit"
act open-close reopen-textedit "opens the document again"
OLD=$W_textedit
# Not in the background: a person who opens a document gets its app in front.
open -b com.apple.TextEdit "$DAY_DOCUMENTS/$APPS_CANARY-oak.txt"
sleep 1
meet textedit com.apple.TextEdit "$DAY_DOCUMENTS/$APPS_CANARY-oak.txt"
acted moves=docked front="$W_textedit"
[ "$A" = "$OLD" ] && A=$W_textedit
[ "$B" = "$OLD" ] && B=$W_textedit
[ "$C" = "$OLD" ] && C=$W_textedit
[ "$D" = "$OLD" ] && D=$W_textedit
[ "$E" = "$OLD" ] && E=$W_textedit
[ "$X" = "$OLD" ] && X=$W_textedit

chapter "Full screen"
reach safari
HOME_STEP=$DAY_STEP
act macos-own full-screen "presses ⌃⌘F in Safari"
key ctrl+cmd+f
sleep 2
acted moves=any leaves=any audit=no
act macos-own leave-full-screen "presses ⌃⌘F again"
key ctrl+cmd+f
sleep 2
acted moves=any leaves=any comes="$W_safari" front="$W_safari" returns="$HOME_STEP"

chapter "A click lands on the wallpaper"
HOME_STEP=$DAY_STEP
if spot=$(bare_spot); then
  act macos-own click-wallpaper "clicks on the wallpaper: macOS sweeps every window aside"
  # shellcheck disable=SC2086
  click $spot
  sleep 1
  acted moves=any leaves=any audit=no
  act macos-own click-wallpaper-again "clicks on the wallpaper again: macOS brings them back"
  # shellcheck disable=SC2086
  click $spot
  sleep 1
  acted moves=any leaves=any returns="$HOME_STEP" everything=1
else
  echo "no bare spot of wallpaper shows"
fi

chapter "Where macOS tiles too"
# Late in the day: whatever comes of two window managers answering one drag, the chapters above have been played by then.
reach "$NE"
act drag-where-macos-tiles "drag-$NE-to-left-edge" "drags $NE by its title bar against the left edge of the screen and lets go"
must drag_window "$E" "$dx" "$((dy + dh / 2))"
# Docked by Arbor, or tiled by macOS with Arbor standing aside: then that is where its person put it, and its own frame from now on.
if with_arbor && eventually is docked "$E"; then edge=""; else edge="own=$E"; fi
acted drags="$E" moves=docked front="$E" $edge
echo "$NE is at $(real_frame_of "$E")"
reach "$NX"
act drag-where-macos-tiles "drag-$NX-to-top" "drags $NX by its title bar against the menu bar and lets go: macOS fills the screen with it"
must drag_window "$X" "$((dx + dw / 2))" "$dy" --hold 1
acted drags="$X" front="$X"
echo "$NX is at $(real_frame_of "$X")"
act drag-where-macos-tiles "drag-$NX-back" "drags $NX away from the top again, a hand's breadth down"
must drag_window "$X" "$((dx + dw / 2))" "$((dy + 130))"
acted drags="$X" front="$X" restores="$X" place="$X"
echo "$NX is at $(real_frame_of "$X")"
if with_arbor; then
  brief | sed 's/^/    /'
  press view show-everything-4 "⌃⌥Space" ctrl+opt+space moves=any everything=1 tiles=ok
fi

if with_arbor; then
  chapter "The ways out"
  reach "$NB"
  HOME_STEP=$DAY_STEP
  press way-out pause "⌃⌥⎋" ctrl+opt+escape moves=any restores=all everything=1
  act drag "drag-$NX-while-paused" "moves $NX a little while Arbor is paused"
  read -r x y w h <<< "$(real_of "$X")"
  must drag_window "$X" "$((x + w / 2 + 60))" "$((y + 72))"
  acted drags="$X" place="$X"
  press way-out resume "⌃⌥⎋" ctrl+opt+escape moves=any
  # The pause ended the chapter's trace.
  day_trace
  press way-out float-all "⌃⌥⇧F" ctrl+opt+shift+f moves=any restores=all places=1 everything=1

  reach "$NA"
  press dock-key "dock-$NA-left-2" "⌃⌥⌘←" ctrl+opt+cmd+left moves=docked front="$A"
  reach "$NB"
  press dock-key "dock-$NB-right-2" "⌃⌥⌘→" ctrl+opt+cmd+right moves=docked front="$B"
  press view "frame-$NB-2" "⌃⌥↩" ctrl+opt+return moves=any front="$B"
  act quit-and-start quit "chooses Quit Arbor in Arbor's menu"
  must arbor_menu up return
  want "Arbor ends within five seconds" day_gone
  acted moves=any restores=all places=1 everything=1

  chapter "After Arbor: can every window be reached?"
  for name in $CAST; do
    act switch "dock-icon-$name-3" "clicks $name's icon in the Dock"
    must dock_click "$(bundle_of "$name")"
    acted front="$(main_window_of "$(pid_of "$name")")"
  done

  chapter "The next morning: Arbor starts again"
  act quit-and-start launch-2 "starts Arbor again"
  day_launch || die "Arbor did not start again"
  # What was docked when it stopped may go back. No window that is in view goes out of view.
  acted moves=docked everything=1
  brief | sed 's/^/    /'
  act idle leave-alone-2 "does nothing for half a minute"
  idle 30
  acted
  act quit-and-start quit-2 "quits Arbor"
  ctl quit
  want "Arbor ends within five seconds" day_gone
  acted moves=any restores=all places=1 everything=1
fi

day_report
