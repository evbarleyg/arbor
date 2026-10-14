# Real-window sessions for Mac shell scripts: launch the real Arbor on test windows, drive it with
# commands and with real pointer and key events, check what the window server says happened, and take
# pictures. Source it; do not run it.
#
#   #!/bin/bash
#   source "$(dirname "$0")/lib.sh"
#   arbor_build
#   arbor_start 3
#   claim "dock by dragging to the left screen edge"
#   drag_window $W2 $(edge_point left) --no-release;  shot 02-preview;  release
#   check "the dragged window docked" eventually is docked $W2
#   arbor_stop
#
# Run such a script on a Mac from anywhere with scripts/mac-shell/run.sh; see "Seeing the real app from
# anywhere" and "The real-window suite" in docs/TESTING.md, shots-demo.sh for pictures and suite/ for checks.
#
# On a person's own Mac (the terminal needs Accessibility) a session touches only its own test windows and
# temporary files, but it does move the pointer and press keys, so hands off meanwhile. Everything that would
# change the system itself asks on_throwaway_mac first and declines politely anywhere but on GitHub's
# Macs, which are thrown away after the run. On a person's Mac, too:
#   - nothing starts from a checkout that scripts/lint-mac-shell.py finds fault with, as root, or with a disk that is nearly full;
#   - arbor_start declines (exit code 77) beside an Arbor or another window manager that is running, while somebody has used the
#     Mac in the last five minutes, and while an app keeps the display awake, as a call does;
#   - a curtain (curtain.swift) hangs over every display, in front of everything that was open and behind the test windows;
#   - a press is let through only between the menu bar and the Dock and only where a window the run opened is the first to get it;
#     keys only to an app the run started, and never a shortcut that macOS itself takes; an Arbor pointed at a process
#     that was running before the run is declined;
#   - `look` takes a picture of one window of the run's own and nothing else. `shot` and `film` take none unless the person asks
#     (ARBOR_SHOTS=1), and then the main display between the menu bar and the Dock, only while nothing but the run's own
#     windows shows in front of the curtain. No ordinary switch gets the whole screen, with whatever is on it;
#   - what the run prints and the logs it leaves name no app of the person's and no window title, and say `<checkout>` and `~` for
#     where the checkout and the home folder are. What only the person should read is in mac-shell/stays-on-this-mac.txt.
#     Nothing is sent anywhere: a script never pushes, uploads or posts what it wrote;
#   - an Arbor started past arbor_start arranges nothing (ARBOR_ONLY_PIDS=1 is in the environment).
# docs/TESTING.md says which script is safe where.
#
# Every script runs under supervision, without doing anything for it: the process that sources this file starts the
# script again as a child in a process group of its own and only watches it. Whatever ends the script (its last line, a
# failed step, ⌃C, the time limit, kill -9), the supervisor then lets go of the mouse button and of every key, puts the
# pointer back, stops what the run started and is still running, and removes the run's folders. On a person's Mac it
# also looks the Mac over before and after, and prints what differs. So lines above `source lib.sh` run twice.
#
# Everything a script leaves in mac-shell/ comes back to the caller. Written for bash 3.2, macOS's own.
# Sets -u and pipefail but not -e: a step that fails should not cost the steps after it.
#
# Whose Mac is this?
#   on_throwaway_mac                whether this is one of GitHub's Macs ($GITHUB_ACTIONS is true)
#   needs_throwaway_mac "<would…>"  for a script that is nothing without changing the system: elsewhere it says so and
#                                     ends the script with exit code 77, "skipped"
#   scratch_dir <name> [VARIABLE [real]]   make /tmp/arbor-<name>.XXXXXX and export its path as VARIABLE (default SCRATCH_DIR); ends
#                                     the script when that fails (a full disk), so the variable is never empty. Removed at the
#                                     end of the run. Call it as a command, never as $(scratch_dir …). real: the path without
#                                     symbolic links (/private/tmp/…), which is how a program that runs from there is listed
#   scratch_remove <path…>          rm -rf, but only for such a folder or something inside one; anything else is refused
#   started <pid>                   put a process the script started itself on record (arbor_start does for its own)
#   ended <pid> [tenths]            whether that child has ended, waiting up to so many tenths of a second (50). Instead of
#                                     `wait "$pid"`, which waits for ever for an Arbor that does not quit
#   kill_started <pid…> | --all     stop those processes, or all on record: TERM, two seconds, KILL. A process that is
#                                     not on record is left alone. Never kill by name or by pattern
#   limit <seconds> <command…>      run a program for at most that long, then stop it and everything it started (TERM, up to five
#                                     seconds for an orderly end, KILL); 124 then
#   at_exit '<command>'             run that when the script ends, however it ends, before Arbor is stopped (the last one
#                                     first). Do not set a trap on EXIT: it would replace the one that cleans up
# Sessions
#   arbor_build                     swift build, the pointer tool, and app bundles for the test windows and Arbor;
#                                     exits 2 with the errors
#   arbor_settings '<json>'         settings.json for the next arbor_start (or `ctl reload-settings`)
#   arbor_start [count] [NAME=v…]   test windows W1…Wcount (default 4), then Arbor limited to them
#   arbor_stop [name]               quit Arbor, check that every test window is back on screen (and take the
#                                     picture <name> of that), close the test windows
#   arbor_quit | arbor_kill [sig]   end Arbor alone, politely or with a signal (default KILL); the windows,
#   arbor_relaunch [NAME=v…]          the settings and the saved state stay for arbor_relaunch
#   arbor_ended                     Arbor has ended some other way (its menu, say): there is nothing left to stop
#   reopen_test_windows <count>     while Arbor is not running: the test app quits and starts again (new window ids)
# Talking to Arbor and to the test windows
#   ctl <command…>                  arborctl: prints the command and the reply
#   state | summary                 the state as JSON | as a few readable lines
#   tw <request…> (tw2: second app) ask ArborTestWindows to do what an app does: minimize 31, hide, activate 32, move 31 x y w h,
#                                     title 31 Inbox… (Commands.swift and MoreCommands.swift in Sources/ArborTestWindows list them)
#   open_window <NAME> [options]    a new test window while Arbor runs; its id goes into $NAME:
#                                     open_window N1 size=400x300 min=700x500 title=Inbox   (open_window2: second app)
#   open_dialog <NAME> <id>, open_tab <NAME> <id>   a dialog centred over that window; a native tab in front of it
#   forget_window <id>              it was closed: arbor_stop no longer expects it back
#   events_of <id> <kind>           how many down, up, dragged, key or magnify events the window's content got
#                                     (as a check: received <id> <kind> -gt 0)
# Real input (pointer.swift has the options: --steps, --duration, --hold, --no-release, --mods)
#   drag x1 y1 x2 y2 [options] | release [x y] | click x y | dblclick x y | rightclick x y | move x y | key <chord>
#   key <chord> --down | --up | --held | --repeat n   hold a shortcut, let go of it later, press another key
#                                     meanwhile, send its auto-repeat (pointer.swift)
#   key_to <id> <chord>             the same key, but only once that window has the keyboard: for ⌘W, ⌘M, ⌘H and whatever
#                                     else would hit a person's own window if the click before it had missed
#   pinch x y <amount> [options]    spread (positive) or pinch two fingers there
#   drag_window <id> x y [options]  by its title bar, from a point that nothing covers (clicks it forward first if needed)
#   click_window <id>               on a part of its content that nothing covers (its app brings it forward first if all is)
#   click_button <id> <which>       its close, minimize or zoom button
#   open_menu                       opens Arbor's menu, as a right click on its menu bar item does whatever that shows
#   click_menu <title> [<title>]    opens Arbor's menu and clicks the item that starts so (then the submenu's)
# Where things are: x y
#   titlebar_of <id> | center_of <id> | tile_of <id> | status_item (status_item_frame: x y w h)
#   seam_right_of <id> | seam_below <id>     the middle of the gap on that side of a docked window
#   edge_point <edge>               just inside that edge of the screen: where a drag docks at the edge
#   zone_of <id> <edge>             the part of a docked window where a drop docks beside it on that side
#   desktop_point                   the middle of the Desktop's part of the layout
#   desktop_is_bare                 whether the wallpaper is what lies there: on a person's Mac the curtain hangs in front of it, and to
#                                     Arbor the curtain is an app's window. Ask before a claim about a press or a pinch on the Desktop
#   frame_of <id> (x y w h)         as Arbor sees the window; real_frame_of: as the window server does; slot_of: its slot
#   take "x y w h" <command…>       what one of these prints, into those variables: take "x y" center_of $W1. Ends the script when
#                                     there is no answer: `read` and arithmetic would make a press at 0 0 of it
#   width_of <id> | height_of <id>  as the window server sees it
#   overlays                        Arbor's own windows (previews, tiles, seams), as the window server sees them:
#                                     id pid level x y w h on|off owner
#   overlay_frame <level>           x y w h of the one on screen at that level: 3 is the drop preview's
# Claims and checks: what they print is the evidence `make parity` reads (mac-shell/evidence/<script>.txt)
#   claim "<title>"                 ▸ title: a real-window step. parity.json's `e2e` lists refer to it, so it says what a
#                                     user does and what happens. The checks that follow are its proof
#   proves <id…>                    on the line after a claim: the items of collab/parity.json it is proof of (T01 A11).
#                                     scripts/mac-shell/suite-parity.py lists the claim under them once all their claims hold
#   known "<why, and who is on it>" after a claim that fails because Arbor is wrong: its ✘ are printed and recorded as ever (so
#                                     nothing is verified by it) but do not fail the script, whose exit code then
#                                     speaks of what is new. Take it off when the claim holds: the script says when
#   step "<title>"                  == title: a heading. It ends the claim: what follows is preparation
#   check "<what should hold>" <command…>    ✔ or ✘ — why; a ✘ takes a picture, prints the state and the log
#                                     since the claim, and makes the script exit with 1
#   settled                         the check that every docked window in view is where Arbor's layout says
#   eventually <command…>           try it for up to three seconds: `eventually is docked $W2`
#   stays <command…>                it holds now and for the next second: for things that must not happen
#   fails <command…>                it fails
#   exits_with <code> <command…> | says <text> <command…>    its exit code; its output has that text (`arborctl …`)
#   pressed <chord> <command…>      presses the shortcut; holds when Arbor ran exactly that command because of it
#   ran <command…>                  Arbor ran that command since the claim began (whether or not it succeeded)
#   logged <text>                   arbor.log has gained a line with that text since the claim began
#   about <a> <b> [tolerance]       two whole numbers at most 3 (or tolerance) apart
#   is <what> <id>                  docked floating parked tile focused minimized hidden fullScreen pinned managed known on_screen
#                                     in_slot display1 display2 (whose workspace holds it)
#   in_view <id> | out_of_view <id>          at least 90 %, at most 5 % of it is on a display (none, when it is minimized,
#                                     hidden or on another Space)
#   has_overlay <level>             Arbor shows a window of its own at that level
#   front_is <pid>                  that process is the app in front, which has the keyboard ($ARBOR_WINDOWS_PID, $ARBOR_WINDOWS_PID_2)
#   The rest compare what the window server reports, within 3 points:
#   at_edge <id> <edge> | fills <id> | in_slot <id> | frame_is <id> x y w h | corner_is <id> x y
#   left_of <a> <b> | above <a> <b> | same_column <a> <b> | same_row <a> <b> | desktop_between <a> <b>
#   width_is <id> <n> [tolerance] | height_is … | wider_than <id> <n> | narrower_than … | taller_than … | shorter_than …
#   camera_on root|desktop|<id> | can back|forward | depth_is <id> <n> | count <what> <n> | no_overlaps | layout_matches
#   tile_is <id> window|group       the kind of tile that stands in for it; tile_shown <id>: Arbor draws it where it says
# Pictures
#   shot <name>                     let things settle, then save the screen as mac-shell/<name>.png (a second
#                                     display as <name>-d2.png)
#   look <name> <window id>         save that window alone, which must be of a process the run started: a test window, a
#                                     panel of Arbor's (`overlays` lists them). Nothing else can be in the picture
#   panorama <name>                 one picture of all displays as they are arranged
#   shot_after <seconds> <name>     the same after exactly that long: `ctl zoom $W1 & shot_after 0.2 mid-zoom`
#   film <name> <count>             <name>-1.png … as fast as pictures can be taken: `ctl zoom $W1 & film zoom 4`
# Other
#   arbor_log                       copy arbor.log to mac-shell/ now (arbor_stop and the exit trap do it too)
#   macos_tiling [on|off]           print, or set, macOS's own "drag windows to screen edges to tile"
#   macos_tiles | screen_edges_dock whether macOS tiles at the screen's edges, where Arbor then stands aside | before arbor_start, for a script that
#                                     docks by dragging to a screen edge: switches that off on a throwaway Mac; false where a person has it on
#   macos_dictation_shortcut off    ⌃ pressed twice no longer asks whether to enable Dictation
#   macos_click_wallpaper [on|off]  print, or set, "click wallpaper to reveal desktop", which sweeps every window aside
#   macos_reduce_motion [on|off]    print, or set (before arbor_start), Reduce Motion, which GitHub's Macs come with
#                                     and which turns Arbor's motion off
#   macos_increase_contrast [on|off] | macos_reduce_transparency [on|off]   the same for those two settings
#   display_add <w> <h> [side]      plug in a virtual second display: right (default), left, above or below the main one
#   display_move <side> [offset]    rearrange it, that many points further down (or right) than flush with the main one
#   display_remove                  unplug it (the end of the script does too)
#   screen_of <n> | display_frame_of <n>              x y w h: display n's visible frame | all of it, as Arbor sees it
#   display_of <id>                 the number of the display whose workspace holds the window (1 is the main one)
#   inside "<x y w h>" "<x y w h>"  whether the first rectangle lies within the second
#   appearance dark|light           the system's appearance
#   wallpaper <file>|#rrggbb|gradient                 the desktop picture of every display
#   spaces                          per display: its identifier, how many Spaces it has, which one shows
#   space_add                       one more Space on the main display (there is no space_remove)
#   space_go left|right             switch Spaces as a person does, with ⌃← and ⌃→
#
# Settings: ARBOR_SETTLE (seconds `shot` waits first, default 0.7), ARBOR_TEST_WINDOWS_ARGS (more arguments
# for ArborTestWindows, e.g. "--min-size 3:700x500"), ARBOR_SECOND_APP (that many windows V1… of a second
# app, with ARBOR_SECOND_APP_ARGS), ARBOR_EXTRA_PIDS (processes the script started itself whose windows Arbor should
# arrange too, comma-separated), ARBOR_BUNDLED=1 (run Arbor from an app bundle, as installed; on a throwaway Mac only), ARBOR_RECORD=1 (a trace
# of every launch on a throwaway Mac, in mac-shell/traces/), ARBOR_TIME_LIMIT
# (seconds the whole script may take, default 900, on
# GitHub's Macs 1100; set it above `source lib.sh`). On a person's Mac: ARBOR_SHOTS=1 (take the pictures of what is in front of the
# curtain), ARBOR_BUSY_OK=1 (start although somebody seems to be using the Mac), ARBOR_QUIET_SINCE (run-list.sh sets it: the time, in seconds since
# 1970, when the script before this one ended; no input since then counts for five quiet minutes).

set -uo pipefail

ARBOR_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd) || exit 2
# bash 3.2 takes `cd ""` for a success, so an empty answer would go unnoticed and every path below would start at /.
if [ -z "$ARBOR_ROOT" ] || [ ! -f "$ARBOR_ROOT/Package.swift" ]; then
  echo "lib.sh: cannot tell where the checkout is" >&2
  exit 2
fi
case "$0" in
  /*) ARBOR_SCRIPT=$0 ;;
  *) ARBOR_SCRIPT=$PWD/$0 ;;
esac
cd "$ARBOR_ROOT" || exit 2
# A rehearsal (scripts/mac-shell/rehearse.sh, scripts/test-tooling.py) sets ARBOR_REHEARSAL, points these at stand-ins and sets
# ARBOR_BUILT, to run a script without a Mac. From anybody else's environment they are not taken: files get deleted in ARBOR_OUT.
if [ -z "${ARBOR_REHEARSAL:-}" ]; then
  unset ARBOR_OUT ARBOR_BIN ARBOR_APPS ARBOR_POINTER ARBOR_TEST_WINDOWS ARBOR_TEST_WINDOWS_2 ARBOR_APP ARBOR_VDISPLAY ARBOR_CURTAIN ARBOR_BUILT
fi
ARBOR_OUT=${ARBOR_OUT:-$ARBOR_ROOT/mac-shell}
ARBOR_BIN=${ARBOR_BIN:-$ARBOR_ROOT/.build/debug}
ARBOR_APPS=${ARBOR_APPS:-$ARBOR_ROOT/.build/mac-shell}
ARBOR_POINTER=${ARBOR_POINTER:-$ARBOR_APPS/pointer}
ARBOR_TEST_WINDOWS=${ARBOR_TEST_WINDOWS:-$ARBOR_APPS/ArborTestWindows.app/Contents/MacOS/ArborTestWindows}
ARBOR_TEST_WINDOWS_2=${ARBOR_TEST_WINDOWS_2:-$ARBOR_APPS/ArborTestWindows2.app/Contents/MacOS/ArborTestWindows}
ARBOR_APP=${ARBOR_APP:-$ARBOR_APPS/Arbor.app}
ARBOR_VDISPLAY=${ARBOR_VDISPLAY:-$ARBOR_APPS/vdisplay}
ARBOR_CURTAIN=${ARBOR_CURTAIN:-$ARBOR_APPS/curtain}
ARBOR_CURTAIN_IS_MINE=""
ARBOR_STATE_PY="$ARBOR_ROOT/scripts/mac-shell/state.py"
# The test apps' bundle ids, for rules, `exclude` and `include`.
ARBOR_TEST_BUNDLE=dev.arbor.testwindows
ARBOR_TEST_BUNDLE_2=dev.arbor.testwindows2
mkdir -p "$ARBOR_OUT"

ARBOR_NAME=$(basename "$0" .sh)
ARBOR_EVIDENCE="$ARBOR_OUT/evidence/$ARBOR_NAME.txt"
ARBOR_PID=""
ARBOR_WINDOWS_PID=""
ARBOR_WINDOWS_PID_2=""
ARBOR_WINDOW_IDS=""
ARBOR_LAUNCH_ENV=""
ARBOR_SESSION=0
ARBOR_PASSED=0
ARBOR_FAILED=0
ARBOR_GAP=12
ARBOR_SESSION_DIRS=""
ARBOR_DISPLAY_COUNT=1
ARBOR_DISPLAY_PID=""
# The virtual display's CGDirectDisplayID, its UUID (Arbor's identifier for it) and its size.
DISPLAY2_ID=""
DISPLAY2_UUID=""
DISPLAY2_SIZE=""
ARBOR_STEP_MARK=0
ARBOR_STEP_EXPLAINED=""
ARBOR_KNOWN=""
ARBOR_KNOWN_FAILED=0
ARBOR_CLAIM_PASSED=0
ARBOR_CLAIM_FAILED=0

# What a script does is worth reading even where its output is being captured, as `check` does.
exec 3>&1

# MARK: Whose Mac is this?

# GitHub's Macs are thrown away after the run; any other belongs to somebody. $CI is not enough: people set it.
on_throwaway_mac() { [ "${GITHUB_ACTIONS:-}" = true ]; }
# A second lock, because the first is one exported variable away from `tccutil reset`, `killall` and `rm -rf ~/Applications/Arbor.app` on
# somebody's Mac: GitHub's Macs run jobs as `runner`, and no variable changes what the account is called. Taken out of the
# environment, so that the tools and the scripts that look at the variable themselves find it gone too.
# safe anywhere: the name is compared, not printed
if on_throwaway_mac && [ "$(uname)" = Darwin ] && [ "$(id -un)" != runner ]; then
  echo "GITHUB_ACTIONS is true, but GitHub's Macs run jobs as \`runner\` and this account is called something else: this Mac is somebody's"
  unset GITHUB_ACTIONS
fi

# For the helpers that change the system: arbor_may "<what it would do>" || return. Says why not.
arbor_may() {
  on_throwaway_mac && return 0
  echo "skipped: this would $*, and this Mac is somebody's (only GitHub's throwaway Macs are treated like that)"
  return 1
}

needs_throwaway_mac() {
  on_throwaway_mac && return 0
  echo "skipped: this script would $*, and this Mac is somebody's. It runs only on GitHub's throwaway Macs."
  exit 77
}

# Whether a process began after this run did. What was running before is somebody's.
arbor_started_here() {
  local age now
  age=$(ps -o etime= -p "$1" 2>/dev/null | awk '{
    parts = split($1, day, "-"); count = split(day[parts], unit, ":"); seconds = 0
    for (i = 1; i <= count; i++) seconds = seconds * 60 + unit[i]
    print (parts == 2 ? day[1] * 86400 : 0) + seconds }')
  now=$(date +%s)
  # ARBOR_RUN_ENDED: of a run that is over, so that a number which has come round again is not taken for one of its processes.
  # One more, because all three times are cut off to whole seconds.
  [ -n "$age" ] && [ "$age" -le $((now - ARBOR_RUN_STARTED + 1)) ] && [ "$age" -ge $((now - ${ARBOR_RUN_ENDED:-now})) ]
}

# A shortcut with its parts in one spelling and in alphabetical order: ⌘⇧Q, shift+cmd+q and command+shift+Q are all cmd+q+shift.
arbor_chord() {
  echo "$1" | tr 'A-Z+' 'a-z\n' | sed -e 's/^control$/ctrl/; s/^⌃$/ctrl/; s/^option$/opt/; s/^alt$/opt/; s/^⌥$/opt/' \
    -e 's/^command$/cmd/; s/^⌘$/cmd/; s/^⇧$/shift/; s/^esc$/escape/; s/^enter$/return/' | LC_ALL=C sort | tr '\n' '+' | sed 's/+$//'
}

# On somebody's Mac their own windows lie behind the test windows and may come forward, and a click or a ⌘W there is theirs to
# make. So a press must be between the menu bar and the Dock, and the first window to get it must belong to a process this
# run started: a test window, or the curtain that arbor_start hangs in front of everything else. Keys must go to such a
# process, and must not be a shortcut macOS itself takes. Letting go is never declined. $@: the pointer tool's arguments.
arbor_input_is_ours() {
  local hit pid x y fx fy fw fh within=""
  on_throwaway_mac && return 0
  case "${1:-}" in
    click | drag | pinch)
      x=${2:-} y=${3:-}
      x=${x%.*} y=${y%.*}
      # `read -r x y <<< ""` and arithmetic make 0 of an answer that never came; nothing makes a number of these.
      case "$x" in "" | - | *[!0-9-]*) echo "skipped: no place to press in: $*"; return 1 ;; esac
      case "$y" in "" | - | *[!0-9-]*) echo "skipped: no place to press in: $*"; return 1 ;; esac
      [ -f "$ARBOR_LEDGER/visible" ] || { echo "skipped: no curtain hangs yet (arbor_start hangs it), so the press at $x,$y could land on anything"; return 1; }
      while read -r fx fy fw fh; do
        [ "$x" -ge "$fx" ] && [ "$x" -lt $((fx + fw)) ] && [ "$y" -ge "$fy" ] && [ "$y" -lt $((fy + fh)) ] && within=yes
      done < "$ARBOR_LEDGER/visible"
      if [ -z "$within" ]; then
        # The one thing up there that is the session's own, from its first point to its last: with its buttons Arbor's item is up to 336
        # points wide. Its neighbours begin where it ends.
        read -r fx fy fw fh <<< "$("$ARBOR_POINTER" status-item "${ARBOR_PID:-0}" --frame 2>/dev/null)"
        fx=${fx%.*} fw=${fw%.*}
        if [ -n "$fw" ] && [ "$x" -ge "$fx" ] && [ "$x" -lt $((fx + fw)) ] && [ "$y" -ge 0 ] && [ "$y" -le 40 ]; then return 0; fi
        # And one thing down there: on a small display the session's own open menu reaches over the Dock, in front of it.
        if [ -n "${ARBOR_PID:-}" ] && "$ARBOR_POINTER" windows --on-screen --pid "$ARBOR_PID" | awk -v x="$x" -v y="$y" '
          $3 == 101 && x >= $4 && x < $4 + $6 && y >= $5 && y < $5 + $7 { found = 1 } END { exit !found }'; then return 0; fi
        echo "skipped: the press at $x,$y would land in the menu bar, in the Dock or beyond the displays, which are somebody's"
        return 1
      fi
      # From front to back, so the first window that holds the point is the one the press would reach. Arbor's own panels are
      # passed over: some of them let presses through (the preview, the ring, the stage), and what lies under them decides.
      # So is the furniture where it spans a display and lets presses through; a banner or a popover of its does not.
      hit=$("$ARBOR_POINTER" windows --on-screen | awk -v x="$x" -v y="$y" -v arbor="${ARBOR_PID:-0}" '
        $3 < 0 || $2 == arbor { next }
        { owner = $9; for (i = 10; i <= NF; i++) owner = owner " " $i }
        owner ~ /^(Dock|Window Server|WindowManager)$/ && $6 >= 800 && $7 >= 500 { next }
        x >= $4 && x < $4 + $6 && y >= $5 && y < $5 + $7 { print $2; exit }')
      if [ -z "$hit" ]; then
        echo "skipped: nothing of this script's lies at $x,$y: the press would land on the wallpaper, which sweeps somebody's windows aside"
        return 1
      fi
      # A right click is how a person takes the curtain down, and the script ends with it (curtain.swift).
      case " $* " in
        *" --right "*)
          if [ "$hit" = "${ARBOR_CURTAIN_PID:-}" ]; then echo "skipped: a right click at $x,$y would take the curtain down"; return 1; fi ;;
      esac
      arbor_started_here "$hit" && return 0
      echo "skipped: the press at $x,$y would land on a window of process $hit, which was running before this script"
      return 1 ;;
    key)
      case " $* " in *" --up "*) return 0 ;; esac
      case "$(arbor_chord "${2:-}")" in
        cmd+tab | cmd+shift+tab | cmd+space | cmd+opt+space | cmd+q+shift | cmd+opt+q+shift | cmd+ctrl+q | cmd+d+opt | cmd+escape+opt | cmd+h+opt | cmd+f5 \
          | [3-6]+cmd+shift | [3-6]+cmd+ctrl+shift | ctrl+up | ctrl+down | ctrl+left | ctrl+right | ctrl+f[1-9] | f11)
          echo "skipped: macOS itself takes $2, whatever is in front: the app used before, Spotlight, logging out, the Dock, Spaces, pictures of the screen"
          return 1 ;;
        ctrl+opt+space | ctrl+space)
          if [ "$(defaults read com.apple.HIToolbox AppleEnabledInputSources 2>/dev/null | grep -c "InputSourceKind")" -gt 1 ]; then
            echo "skipped: with several input sources macOS takes $2 to switch somebody's keyboard layout"
            return 1
          fi ;;
      esac
      # An open menu of Arbor's has the keyboard whatever app is in front.
      if [ -n "${ARBOR_PID:-}" ] && has_overlay 101; then return 0; fi
      pid=$("$ARBOR_POINTER" front 2>/dev/null)
      arbor_is_pid "$pid" && arbor_started_here "$pid" && return 0
      echo "skipped: the keys would go to the app that has the keyboard, which is not one this script started (click a test window first)"
      return 1 ;;
  esac
  return 0
}

# curtain.swift says what it is for. One for the whole run, hung before the first test windows open so that they open in front of it.
arbor_hang_curtain() {
  local tries=0
  if on_throwaway_mac && [ "${ARBOR_CURTAIN_HERE:-}" != 1 ]; then return 0; fi
  if [ -n "${ARBOR_CURTAIN_PID:-}" ]; then
    kill -0 "$ARBOR_CURTAIN_PID" 2>/dev/null && return 0
    # Not a new one: whoever took it down would find the next session, or the suite's next section, behind another.
    echo "the curtain was taken down: somebody wants their Mac back. Ending the script"
    exit 75
  fi
  if [ ! -x "$ARBOR_CURTAIN" ]; then
    echo "skipped: there is no curtain to hang between the test windows and somebody's own (arbor_build compiles it: see build-curtain.log)"
    return 1
  fi
  rm -f "$ARBOR_LEDGER/visible"
  "$ARBOR_CURTAIN" "$ARBOR_SUPERVISOR" 1800 "$ARBOR_LEDGER/visible" >> "$ARBOR_OUT/curtain.log" 2>&1 3>&- 7>&- 8>&- 9>&- &
  ARBOR_CURTAIN_PID=$!
  ARBOR_CURTAIN_IS_MINE=yes
  export ARBOR_CURTAIN_PID
  started "$ARBOR_CURTAIN_PID"
  until [ -s "$ARBOR_LEDGER/visible" ]; do
    if [ "$tries" -ge 50 ] || ! kill -0 "$ARBOR_CURTAIN_PID" 2>/dev/null; then
      echo "skipped: the curtain did not go up ($(tail -n 1 "$ARBOR_OUT/curtain.log" 2>/dev/null))"
      return 1
    fi
    sleep 0.1
    tries=$((tries + 1))
  done
  echo "a curtain hangs over every display, between the test windows and everything that was open; a right-click takes it down"
}

# Asked at the end of arbor_build and by arbor_start: may windows open, the pointer move and keys be pressed on this Mac now?
arbor_make_room() {
  arbor_mac_is_free && arbor_hang_curtain || return 1
  # From here on the run may press buttons and keys, with this file's helpers or with a tool of its own.
  : > "$ARBOR_LEDGER/input"
}

# A picture of the whole screen shows whatever else the person has open: mail, chats, documents. So nothing that is set in passing
# gets one on their Mac, ARBOR_SHOTS=1 least of all. (shot, film and shot_after ask arbor_can_shoot, which knows a way to take
# a picture of less, and `look` takes one window.)
arbor_may_shoot() {
  if on_throwaway_mac || [ "${ARBOR_SHOTS_WHOLE_SCREEN_I_HAVE_CLOSED_EVERYTHING:-}" = 1 ]; then return 0; fi
  echo "shot $1: skipped: a picture of the whole screen would show what else is open on somebody's Mac"
  return 1
}

# MARK: Steps and evidence

arbor_record() { printf '%s\n' "$1" >> "$ARBOR_EVIDENCE"; }

# Anew with every run of the script: what an earlier one proved is not this one's.
arbor_begin_evidence() {
  mkdir -p "$ARBOR_OUT/evidence"
  if [ -n "${ARBOR_REHEARSAL:-}" ]; then
    echo "# $ARBOR_NAME: a REHEARSAL against stand-ins, which proves nothing about real windows" > "$ARBOR_EVIDENCE"
  else
    echo "# $ARBOR_NAME $(date -u +%Y-%m-%dT%H:%MZ) on macOS $(sw_vers -productVersion 2>/dev/null || echo "?")," \
      "commit $(git rev-parse --short HEAD 2>/dev/null || echo "?")" > "$ARBOR_EVIDENCE"
  fi
}

arbor_log_lines() {
  if [ -f "$ARBOR_HOME/arbor.log" ]; then wc -l < "$ARBOR_HOME/arbor.log" | tr -d ' '; else echo 0; fi
}

# The lines arbor.log has gained since it had $1.
arbor_log_since() {
  if [ -f "$ARBOR_HOME/arbor.log" ]; then tail -n "+$(($1 + 1))" "$ARBOR_HOME/arbor.log"; fi
}

# A rehearsal does not count: the stand-ins lack most of what makes Arbor fail on real windows.
arbor_close_claim() {
  if [ -n "$ARBOR_KNOWN" ] && [ "$ARBOR_CLAIM_FAILED" -eq 0 ] && [ "$ARBOR_CLAIM_PASSED" -gt 0 ] \
    && [ -z "${ARBOR_REHEARSAL:-}" ]; then
    echo "  note: this claim is marked as known to fail ($ARBOR_KNOWN) and held: take the mark off"
  fi
  ARBOR_KNOWN=""
  ARBOR_CLAIM_PASSED=0
  ARBOR_CLAIM_FAILED=0
}

arbor_heading() {
  arbor_close_claim
  ARBOR_STEP_MARK=$(arbor_log_lines)
  ARBOR_STEP_EXPLAINED=""
  echo
  echo "$*"
  arbor_record ""
  arbor_record "$*"
}
claim() { arbor_heading "▸ $*"; }
# Read from the script by suite-parity.py; nothing to do at run time.
proves() { :; }
known() { ARBOR_KNOWN=$*; }
step() { arbor_heading "== $*"; }

# Also an annotation, for readers who see nothing else of the run.
die() {
  echo "::error title=mac-shell::$*"
  exit 2
}

# MARK: Only what this run made

# The supervisor's folder, $ARBOR_LEDGER, keeps the record: `dirs` (folders made), `pids` (processes started, each with the
# moment it began, because a number alone may be somebody else's process by now), `groups` (process groups of `limit`).

# Every folder a script makes for itself is /tmp/arbor-<name>.XXXXXX, and nothing else is ever removed. A variable that is
# empty because `mktemp` failed on a full disk, or that holds / or the home folder, is refused here and not by luck.
# (/private/tmp is what macOS's /tmp is a link to, and how the path of a program that runs from there reads.)
arbor_is_scratch() {
  local pattern='^(/private)?/tmp/arbor-[A-Za-z0-9_-]+\.[A-Za-z0-9]{6}(/.*)?$'
  [[ "${1:-}" =~ $pattern ]] || return 1
  case "$1" in
    */.. | */../*) return 1 ;;
  esac
}

# A short path: a socket's is limited to 103 bytes, and macOS's own temporary folder uses half of them.
scratch_dir() {
  local name=${1:-} variable=${2:-SCRATCH_DIR} real=${3:-} made
  case "$name" in
    "" | *[!A-Za-z0-9_-]*) die "scratch_dir: a name of letters, digits, - and _, not '$name'" ;;
  esac
  case "$variable" in
    "" | [0-9]* | *[!A-Za-z0-9_]*) die "scratch_dir: '$variable' cannot be the name of a variable" ;;
  esac
  # never empty: the next lines end the script unless it is a folder of the right name
  made=$(mktemp -d "/tmp/arbor-$name.XXXXXX" 2>/dev/null) || made=""
  if ! arbor_is_scratch "$made" || [ ! -d "$made" ]; then
    die "scratch_dir: no temporary folder /tmp/arbor-$name.XXXXXX (is the disk full?)"
  fi
  echo "$made" >> "$ARBOR_LEDGER/dirs"
  if [ "$real" = real ]; then
    # never empty: the next line ends the script unless it is a folder of the right name
    made=$(cd "$made" && pwd -P)
    arbor_is_scratch "$made" && [ -d "$made" ] || die "scratch_dir: no way into the folder just made"
  fi
  eval "$variable=\$made; export $variable"
}

scratch_remove() {
  local path top refused=0
  for path in "$@"; do
    top=${path#/private}
    top=${top#/tmp/}
    top=/tmp/${top%%/*}
    if ! arbor_is_scratch "$path" || [ -L "$top" ]; then
      echo "scratch_remove: refused '$path': only /tmp/arbor-<name>.XXXXXX and what is inside one is removed"
      refused=1
      continue
    fi
    rm -rf "$path" # never empty: arbor_is_scratch has just vouched for it
  done
  return "$refused"
}

arbor_birth() { ps -o lstart= -p "$1" 2>/dev/null | tr -s ' ' | sed 's/^ //; s/ $//'; }

arbor_is_pid() {
  case "${1:-}" in
    "" | *[!0-9]* | 0 | 1) return 1 ;;
  esac
}

started() {
  local birth
  arbor_is_pid "${1:-}" || { echo "started: not a process id: '${1:-}'"; return 1; }
  if ! arbor_started_here "$1"; then
    echo "started: process $1 has ended, or was running before this script and is somebody's: not put on record"
    return 1
  fi
  birth=$(arbor_birth "$1")
  echo "$1 $birth" >> "$ARBOR_LEDGER/pids"
}

# Waits up to $2 tenths of a second for process $1 to end.
arbor_await_exit() {
  local tries=0
  while kill -0 "$1" 2>/dev/null; do
    [ "$tries" -ge "$2" ] && return 1
    sleep 0.1
    tries=$((tries + 1))
  done
}

ended() { arbor_await_exit "$1" "${2:-50}" && { wait "$1" 2>/dev/null; true; }; }

kill_started() {
  local pid birth alive="" all=""
  [ -f "$ARBOR_LEDGER/pids" ] || return 0
  # Not "all": `kill_started $helper` with nothing in the variable would stop Arbor and the curtain in the middle of a script.
  if [ $# -eq 0 ]; then
    echo "kill_started: no process named, so none is stopped (--all stops everything on record)"
    return 0
  fi
  if [ "$*" = --all ]; then
    all=yes
    set --
  fi
  for pid in "$@"; do
    if ! arbor_is_pid "$pid" || ! grep -q "^$pid " "$ARBOR_LEDGER/pids"; then
      echo "kill_started: '$pid' is not a process this script put on record with \`started\`: left alone"
    fi
  done
  while read -r pid birth; do
    arbor_is_pid "$pid" || continue
    case "$all $* " in
      "yes "* | *" $pid "*) ;;
      *) continue ;;
    esac
    [ "$(arbor_birth "$pid")" = "$birth" ] || continue
    kill -TERM "$pid" 2>/dev/null && alive="$pid $alive"
  done < "$ARBOR_LEDGER/pids"
  for pid in $alive; do
    arbor_await_exit "$pid" 20 || kill -KILL "$pid" 2>/dev/null
  done
  return 0
}

# A program that waits for a dialog nobody answers would hang the run. It gets a process group of its own, so that what it
# started goes with it, and the group goes on record, so that the supervisor finds it if the script dies meanwhile.
arbor_within() {
  perl -e '
    use POSIX ":sys_wait_h";
    my ($seconds, $record) = (shift, shift);
    my $pid = fork();
    exit 125 unless defined $pid;
    if (!$pid) { setpgrp(0, 0); exec { $ARGV[0] } @ARGV or exit 127; }
    setpgrp($pid, $pid);
    if (open my $file, ">>", $record) { print $file "$pid\n"; close $file; } # safe anywhere: this open is a function of perl and writes the record of this run
    my $stop = sub {
      kill "TERM", -$pid;
      for (1 .. 50) { last if waitpid($pid, WNOHANG) != 0; select(undef, undef, undef, 0.1); }
      kill "KILL", -$pid;
      exit shift;
    };
    $SIG{ALRM} = sub { $stop->(124) };
    $SIG{$_} = sub { $stop->(143) } for qw(INT TERM HUP);
    alarm $seconds;
    waitpid($pid, 0);
    exit($? & 127 ? 128 + ($? & 127) : $? >> 8);
  ' "$1" "$ARBOR_LEDGER/groups" "${@:2}"
}
limit() { arbor_within "$@"; }

ARBOR_AT_EXIT=""
at_exit() { ARBOR_AT_EXIT="$1"$'\n'"$ARBOR_AT_EXIT"; }

arbor_new_home() {
  scratch_dir shell ARBOR_SESSION_DIR
  ARBOR_SESSION_DIRS="$ARBOR_SESSION_DIRS $ARBOR_SESSION_DIR"
  export ARBOR_HOME="$ARBOR_SESSION_DIR/home"
  export ARBOR_SOCKET="$ARBOR_HOME/arbor.sock"
  mkdir -p "$ARBOR_HOME" || die "cannot make $ARBOR_HOME"
  ARBOR_GAP=12
}

# MARK: Supervision

arbor_supervised() { kill -0 "${ARBOR_SUPERVISOR:-}" 2>/dev/null; }

# A caller's own time limit may kill the supervisor and miss the script, which is in another process group. Then nobody is waiting
# for what the script finds out, and nobody would clean up after it: it ends, and sweeps for itself (arbor_exit).
arbor_still_watched() {
  arbor_supervised && return 0
  echo "the supervisor of this run is gone: ending the script"
  exit 129
}

# What the run started and is still running: the members of its process groups, the processes on record (an app started
# through `open` is launchd's child and in no group of ours), and what runs from the run's own folders. One pid a line.
arbor_leftovers() {
  local pid birth groups
  groups=$(cat "$ARBOR_LEDGER/groups" 2>/dev/null | tr '\n' ' ')
  {
    ps -A -o pid=,pgid= | awk -v groups=" $groups" 'index(groups, " " $2 " ") { print $1 }'
    # Arbor's watchdog, and the Arbor it starts again, have groups of their own. What runs from this checkout's build folder or
    # from one of the run's folders, and began after the run did, is the run's all the same. (/tmp is /private/tmp to ps.)
    ps -A -o pid=,comm= | awk -v places="${ARBOR_ROOT#/private}/.build/|$(sed 's|$|/|' "$ARBOR_LEDGER/dirs" 2>/dev/null | tr '\n' '|')" '
      BEGIN { count = split(places, place, "|") }
      { pid = $1; $1 = ""; path = substr($0, 2); sub(/^\/private/, "", path)
        for (i = 1; i <= count; i++) if (place[i] != "" && index(path, place[i]) == 1) { print pid; break } }'
    cat "$ARBOR_LEDGER/pids" | while read -r pid birth; do
      [ "$(arbor_birth "$pid")" = "$birth" ] && echo "$pid"
    done
  } 2>/dev/null | sort -un | while read -r pid; do
    arbor_is_pid "$pid" && [ "$pid" != $$ ] && [ "$pid" != "${ARBOR_SUPERVISOR:-}" ] || continue
    # A process that has ended and waits for its parent to ask after it does nothing any more.
    case "$(ps -o stat= -p "$pid" 2>/dev/null)" in
      "" | Z*) continue ;;
    esac
    arbor_started_here "$pid" && echo "$pid"
  done
}

arbor_release_keys() {
  local chord
  [ -f "$ARBOR_LEDGER/keys" ] || return 0
  while read -r chord; do
    "$ARBOR_POINTER" key "$chord" --up 2>/dev/null # safe anywhere: letting go harms nobody
  done < "$ARBOR_LEDGER/keys"
  rm -f "$ARBOR_LEDGER/keys"
}

# arbor_signal <signal> <pid…>, one process at a time: never a group, never a name, never a pattern.
arbor_signal() {
  local signal=$1 pid
  shift
  for pid in "$@"; do
    arbor_is_pid "$pid" && kill "-$signal" "$pid" 2>/dev/null
  done
  return 0
}

# What must not outlive a run, whatever became of the script.
arbor_sweep() {
  local left pid tries=0 where
  if [ -x "$ARBOR_POINTER" ] && [ -f "$ARBOR_LEDGER/input" ]; then
    # A button or a key that stays down is the person's problem until they press it themselves.
    arbor_release_keys
    "$ARBOR_POINTER" calm 2>/dev/null
    where=$(cut -d ' ' -f 1,2 "$ARBOR_LEDGER/pointer" 2>/dev/null)
    # shellcheck disable=SC2086
    [ -n "$where" ] && "$ARBOR_POINTER" move $where 2>/dev/null # safe anywhere: it presses nothing
  fi
  left=$(arbor_leftovers)
  if [ -n "$left" ]; then
    echo "still running when the script had ended, and stopped now:"
    for pid in $left; do
      echo "  $pid $(basename "$(ps -o comm= -p "$pid" 2>/dev/null)" 2>/dev/null)"
    done
    # shellcheck disable=SC2086
    arbor_signal TERM $left
    while [ "$tries" -lt 30 ] && [ -n "$(arbor_leftovers)" ]; do
      sleep 0.1
      tries=$((tries + 1))
    done
    # shellcheck disable=SC2046
    arbor_signal KILL $(arbor_leftovers)
    # Once more: one of them may have been a tool that pressed a key after the first time and was stopped before it let go.
    if [ -x "$ARBOR_POINTER" ] && [ -f "$ARBOR_LEDGER/input" ]; then "$ARBOR_POINTER" calm 2>/dev/null; fi
  fi
  # Through cat: of a run that was cut off, the record itself may go at any moment, if its script is still about and cleaning up.
  cat "$ARBOR_LEDGER/dirs" 2>/dev/null | while read -r left; do
    [ -e "$left" ] && scratch_remove "$left"
  done
}

# A run that was killed together with its supervisor (a caller's own time limit does that) left its record behind. The next
# run finishes its clean-up before anything else; sweep.sh does nothing but that. Fails when another run is going on.
arbor_sweep_stale() {
  local ledger owner began birth
  for ledger in /tmp/arbor-run.??????; do
    [ -d "$ledger" ] && [ -O "$ledger" ] && [ "$ledger" != "$ARBOR_LEDGER" ] && arbor_is_scratch "$ledger" || continue
    owner="" began="" birth=""
    { read -r owner; read -r began; read -r birth; } < "$ledger/run" 2>/dev/null
    if arbor_is_pid "$owner" && arbor_is_pid "$began"; then
      if [ "$(arbor_birth "$owner")" = "$birth" ]; then
        # Rehearsals have no pointer to fight over.
        [ -n "${ARBOR_REHEARSAL:-}" ] && continue
        echo "skipped: another Mac shell script is running (its supervisor is process $owner), and two would fight over the pointer"
        return 1
      fi
      echo "an earlier run was cut off before it could clean up; doing that now"
      (ARBOR_LEDGER=$ledger ARBOR_RUN_STARTED=$began ARBOR_RUN_ENDED=$((began + 1800)) arbor_sweep)
    elif [ -z "$(find "$ledger" -maxdepth 0 -mmin +2 2>/dev/null)" ]; then
      # Made this minute and not yet filled in: a run that is just starting.
      continue
    fi
    scratch_remove "$ledger"
  done
}

# Test windows appear, the pointer moves and keys are pressed: not under somebody's hands, not into a call, and not beside
# the person's own Arbor, which would take the script's shortcuts and gestures for theirs and arrange THEIR windows (the
# lock that keeps two Arbors apart lies in $ARBOR_HOME, so it does not keep a session's Arbor from theirs).
arbor_mac_is_free() {
  local id idle held ours
  on_throwaway_mac && return 0
  for id in $(pgrep -x Arbor 2>/dev/null); do
    arbor_started_here "$id" && continue
    # One that has ended and waits for a parent that never asks does nothing.
    case "$(ps -o stat= -p "$id" 2>/dev/null)" in Z*) continue ;; esac
    echo "skipped: an Arbor is running on this Mac already (process $id), and real keys and gestures would reach it too. Its owner may quit it; a script may not"
    return 1
  done
  # They hold the same ⌃⌥ shortcuts, snap what is dragged to an edge, or tile every window anew when one opens.
  for id in TrellisWM Rectangle "Rectangle Pro" Magnet Amethyst yabai skhd AeroSpace Moom BetterSnapTool Spectacle Hammerspoon Loop Swish Lasso Divvy; do
    if pgrep -x "$id" > /dev/null 2>&1; then
      # Which one is the person's business, and this gets pasted into pull requests.
      echo "skipped: another window manager is running on this Mac and would answer the script's keys, drags or new windows by moving somebody's windows"
      return 1
    fi
  done
  # Before every session: on a Mac left alone the display goes to sleep in the middle of a list. Nothing that opens then shows, Accessibility lists
  # no window that does not show, and every check fails in a way that looks like Arbor's fault.
  if ioreg -n Root -d1 2>/dev/null | grep -q '"CGSSessionScreenIsLocked"=Yes'; then
    echo "skipped: the screen is locked, so no window that opens would show. Unlock it, and keep the display awake for as long as this takes"
    return 1
  fi
  if pgrep -x ScreenSaverEngine > /dev/null 2>&1; then
    echo "skipped: the screen saver is up, so no window that opens would show"
    return 1
  fi
  # Once the tool is there to ask, which it is before the first window opens.
  if [ -x "$ARBOR_POINTER" ] && [ "$("$ARBOR_POINTER" asleep 2>/dev/null)" = true ]; then
    echo "skipped: the display is asleep, so no window that opens would show. Wake it, and keep it awake for as long as this takes"
    return 1
  fi
  # Asked once: after the first session the last input is the script's own.
  [ "${ARBOR_BUSY_OK:-}" = 1 ] || [ -f "$ARBOR_LEDGER/free" ] && return 0
  idle=$(ioreg -c IOHIDSystem 2>/dev/null | awk '/HIDIdleTime/ { print int($NF / 1000000000); exit }')
  # run-list.sh says when the script before this one ended: input up to then was that script's, and none since is as good as five minutes.
  case "${ARBOR_QUIET_SINCE:-}" in
    "" | *[!0-9]*) ;;
    *) [ -n "$idle" ] && [ "$idle" -ge $(($(date +%s) - ARBOR_QUIET_SINCE - 1)) ] && idle=300 ;;
  esac
  if [ -n "$idle" ] && [ "$idle" -lt 300 ]; then
    echo "skipped: somebody used this Mac's keyboard or pointer $idle s ago, and this would move windows and the pointer under their hands (five quiet minutes, or ARBOR_BUSY_OK=1)"
    return 1
  fi
  # safe anywhere: -g only reads
  held=$(pmset -g assertions 2>/dev/null)
  if grep -Eq "PreventUserIdleDisplaySleep +[1-9]" <<< "$held"; then
    # run-list.sh keeps the display awake itself, for as long as the list takes, and says with which process. It counts for nothing only if the
    # list of who holds what names that very process, as a caffeinate, and nobody else.
    ours=0
    case "${ARBOR_KEEPS_AWAKE:-}" in
      "" | *[!0-9]*) ;;
      *) ours=$(grep -Ec "pid $ARBOR_KEEPS_AWAKE\(caffeinate\).* PreventUserIdleDisplaySleep " <<< "$held") ;;
    esac
    if [ "$ours" -eq 0 ] || [ "$(grep -Ec "pid [0-9]+\(.* PreventUserIdleDisplaySleep " <<< "$held")" -gt "$ours" ]; then
      echo "skipped: an app keeps the display awake, as a call, a shared screen or a film does (ARBOR_BUSY_OK=1 if it is none of these)"
      return 1
    fi
  fi
  : > "$ARBOR_LEDGER/free"
}

# Before anything is built or started on a person's Mac.
arbor_preflight() {
  local free
  on_throwaway_mac && return 0
  if [ "$(id -u)" -eq 0 ]; then
    echo "skipped: not as root on somebody's Mac"
    return 77
  fi
  free=$(df -k /tmp 2>/dev/null | awk 'NR == 2 { print int($4 / 1024) }')
  if [ "${free:-0}" -lt 2048 ]; then
    echo "skipped: ${free:-0} MB are free, and a build and its logs on a disk that fills up end badly for everybody (2048 MB or more)"
    return 77
  fi
  if ! python3 "$ARBOR_ROOT/scripts/lint-mac-shell.py"; then
    echo "skipped: scripts/lint-mac-shell.py finds lines that could change this Mac, so nothing from this checkout runs here"
    return 77
  fi
}

arbor_fact() {
  local label=$1
  shift
  "$@" 2>/dev/null | sed "s|^|$label: |"
}

arbor_count_spaces() { defaults read com.apple.spaces SpacesDisplayConfiguration | grep -c ManagedSpaceID; }
arbor_registered() {
  # safe anywhere: -dump only reads
  /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -dump \
    | grep -E "^path:.*[Aa]rbor" | sed -E "s/ +\(0x[0-9a-f]+\)$//" | sort -u
}
arbor_services() { launchctl print "gui/$(id -u)" | grep -i arbor | tr -s ' \t' ' ' | sort; }
arbor_apps() {
  # safe anywhere: for the comparison before and after; arbor_tell_what_differs prints none of it
  lsappinfo list | awk '/bundleID=/ { split($0, part, "\""); id = part[2] } / pid = / && /Foreground/ { print id, $3 }' | sort
}
arbor_own_processes() { ps -A -o pid=,comm= | grep -F "$ARBOR_ROOT/.build/" | sed "s|$ARBOR_ROOT/||"; }
arbor_folders() { ls -d /tmp/arbor-* | grep -v -x -F "$ARBOR_LEDGER"; }
arbor_windows_by_owner() { "$ARBOR_POINTER" windows --on-screen | cut -d ' ' -f 9- | sort | uniq -c | tr -s ' '; }

# What a script could change on a person's Mac without meaning to, as lines that can be compared. It only reads. Contents
# stay out of it (check sums stand in for files); bundle ids and paths do appear, so arbor_tell_what_differs prints only some of
# the lines. Not the clipboard: macOS may ask the person whether a program that reads it unbidden may.
arbor_fingerprint() {
  local file
  arbor_fact "setting WindowManager" defaults read com.apple.WindowManager
  arbor_fact "setting Reduce Motion" defaults read com.apple.universalaccess reduceMotion
  arbor_fact "setting Increase Contrast" defaults read com.apple.universalaccess increaseContrast
  arbor_fact "setting Reduce Transparency" defaults read com.apple.universalaccess reduceTransparency
  arbor_fact "setting appearance" defaults read -g AppleInterfaceStyle
  arbor_fact "setting Dock hides" defaults read com.apple.dock autohide
  arbor_fact "keyboard layouts" defaults read com.apple.HIToolbox AppleEnabledInputSources
  arbor_fact "keyboard layout in use" defaults read com.apple.HIToolbox AppleSelectedInputSources
  arbor_fact "Spaces" arbor_count_spaces
  arbor_fact "keychains" security list-keychains -d user
  arbor_fact "default keychain" security default-keychain -d user # safe anywhere: without -s it only reads
  for file in "$HOME/Applications/Arbor.app/Contents/MacOS/Arbor" /Applications/Arbor.app/Contents/MacOS/Arbor \
    "$HOME/Library/Application Support/Arbor"/*; do
    [ -f "$file" ] && arbor_fact "file" cksum "$file"
  done
  arbor_fact "known to LaunchServices" arbor_registered
  arbor_fact "known to launchd" arbor_services
  arbor_fact "app" arbor_apps
  arbor_fact "process of this checkout" arbor_own_processes
  arbor_fact "folder" arbor_folders
  arbor_fact "working tree" git -C "$ARBOR_ROOT" status --porcelain
  if [ -f "$ARBOR_LEDGER/pointer-tool" ]; then
    arbor_fact "display" "$ARBOR_POINTER" displays
    arbor_fact "wallpaper" "$ARBOR_POINTER" wallpaper
    # A dialog that was left open shows up here, under the name of the agent that put it up.
    arbor_fact "windows on screen" arbor_windows_by_owner
  fi
}

# Lines about Arbor, this checkout and macOS's settings are printed. Of the rest (which apps run, whose windows show, the
# wallpaper, the keychains, the keyboard layouts) only how many differ: what they say is the person's, and stays in a file on their Mac.
arbor_tell_what_differs() {
  local private="^[<>] (app|windows on screen|wallpaper|keychains|default keychain|keyboard layouts|keyboard layout in use): "
  echo "::warning title=mac-shell::this Mac differs from before the run (< before, > after):"
  grep "^[<>]" "$ARBOR_LEDGER/changed" | grep -v -E "$private"
  if grep -E "$private" "$ARBOR_LEDGER/changed" > "$ARBOR_OUT/stays-on-this-mac.txt"; then
    sed -E 's/^[<>] ([^:]*): .*/\1/' "$ARBOR_OUT/stays-on-this-mac.txt" | sort | uniq -c | sed -E 's/^ *([0-9]+) (.*)/  \2: \1 line(s) differ/'
    echo "  which ones is for the owner of this Mac to read, in mac-shell/stays-on-this-mac.txt: do not send that file anywhere"
  else
    rm -f "$ARBOR_OUT/stays-on-this-mac.txt"
  fi
}

# What a run prints on a person's Mac gets pasted into pull requests, and so do its logs. Where the checkout and the home folder lie
# says who the person is and how they keep their disk, and nothing about Arbor. So do the lines Arbor logs at its start about what it found
# amiss on the Mac (`setup: Other window managers: …`, their Desktop & Dock switches, which of its shortcuts macOS uses as well). The signals are the supervisor's to handle: this
# must live to print what it says afterwards.
ARBOR_DISCREET='BEGIN { $| = 1; $SIG{$_} = "IGNORE" for qw(INT TERM HUP);
  @hide = map { [quotemeta($_->[0]), $_->[1]] } grep { length($_->[0]) > 1 }
    (["/private$ENV{ARBOR_ROOT}", "<checkout>"], [$ENV{ARBOR_ROOT}, "<checkout>"], ["/private$ENV{HOME}", "~"], [$ENV{HOME}, "~"]) }
  for $pair (@hide) { s/$pair->[0]/$pair->[1]/g }
  s{/Users/[^/\s"\x27:,;)]+}{~}g;
  s/(\bsetup: [^:]*):.*/$1: (stays on this Mac)/;
  s/(\bshortcuts: ).*macOS\x27s as well.*/$1(stays on this Mac)/;'
arbor_discreet() { ARBOR_ROOT=$ARBOR_ROOT perl -pe "$ARBOR_DISCREET"; }
arbor_discreet_files() {
  find "$ARBOR_OUT" -type f \( -name "*.txt" -o -name "*.log" -o -name "*.json" -o -name "*.jsonl" \) \
    ! -name output.txt ! -name exit-code.txt ! -name stays-on-this-mac.txt -exec env ARBOR_ROOT="$ARBOR_ROOT" perl -pi -e "$ARBOR_DISCREET" {} +
}

# The end of the supervisor: $1 is the exit code.
arbor_leave() {
  scratch_remove "$ARBOR_LEDGER"
  if [ -n "$ARBOR_DISCREET_PID" ]; then
    # It ends when nobody can write to it any more. Something that outlived the sweep might.
    exec >&- 2>&-
    arbor_await_exit "$ARBOR_DISCREET_PID" 50 || kill -KILL "$ARBOR_DISCREET_PID"
  fi
  exit "$1"
}

# The process that sourced this file becomes the supervisor and never returns from here.
ARBOR_DISCREET_PID=""
arbor_supervise() {
  local child code group reason="" limit=${ARBOR_TIME_LIMIT:-} anonymous
  # On GitHub's Macs under the workflow's twenty minutes, so that the output of a script that hangs still comes back.
  if [ -z "$limit" ]; then on_throwaway_mac && limit=1100 || limit=900; fi
  [ -f "$ARBOR_SCRIPT" ] || die "lib.sh is for scripts: source it from one ($ARBOR_SCRIPT is no file)"
  ARBOR_SUPERVISOR=$$
  ARBOR_RUN_STARTED=$(date +%s)
  # never empty: the next lines end the script unless it is a folder of the right name
  ARBOR_LEDGER=$(mktemp -d /tmp/arbor-run.XXXXXX 2>/dev/null) || ARBOR_LEDGER=""
  if ! arbor_is_scratch "$ARBOR_LEDGER" || [ ! -d "$ARBOR_LEDGER" ]; then
    die "no temporary folder /tmp/arbor-run.XXXXXX (is the disk full?): nothing was started"
  fi
  export ARBOR_SUPERVISOR ARBOR_RUN_STARTED ARBOR_LEDGER
  : > "$ARBOR_LEDGER/pids" && : > "$ARBOR_LEDGER/groups" && : > "$ARBOR_LEDGER/dirs" \
    && printf '%s\n' $$ "$ARBOR_RUN_STARTED" "$(arbor_birth $$)" > "$ARBOR_LEDGER/run" \
    || die "cannot write to $ARBOR_LEDGER (is the disk full?): nothing was started"
  if ! on_throwaway_mac; then
    mkfifo "$ARBOR_LEDGER/said" || die "cannot write to $ARBOR_LEDGER (is the disk full?): nothing was started"
    arbor_discreet < "$ARBOR_LEDGER/said" &
    ARBOR_DISCREET_PID=$!
    exec > "$ARBOR_LEDGER/said" 2>&1
  fi
  if ! arbor_sweep_stale || ! arbor_preflight; then arbor_leave 77; fi
  if ! on_throwaway_mac; then
    # GitHub's Macs start with an empty folder. Here the last run's logs and pictures would pass for this one's, and a process id
    # read from an old log is somebody else's process by now. The caller may be writing output.txt at this moment.
    find "$ARBOR_OUT" -mindepth 1 -maxdepth 1 ! -name output.txt ! -name exit-code.txt -exec rm -rf {} +
    [ -x "$ARBOR_POINTER" ] && : > "$ARBOR_LEDGER/pointer-tool"
    arbor_fingerprint > "$ARBOR_LEDGER/before"
  fi

  # From here, not from the start: cleaning up after an earlier run and looking the Mac over are not the script's time.
  limit=$((SECONDS + limit))
  trap 'reason=${reason:-interrupted}' INT TERM HUP
  # With job control a background job gets a process group of its own: ⌃C then reaches only the supervisor, which passes
  # it on in good order, and whatever the script starts can be told from everything else on the Mac.
  set -m
  "$BASH" "$ARBOR_SCRIPT" "$@" < /dev/null &
  child=$!
  set +m
  # Should arbor_discreet die, the supervisor must not die of writing to it: it has cleaning up to do. Only now, because the
  # script would inherit it, and a shell cannot take back what was ignored when it started: `… | head -n 1` counts on the signal.
  trap '' PIPE
  group=$(ps -o pgid= -p "$child" 2>/dev/null | tr -d ' ')
  # Otherwise the group is the caller's too, and only what is on record can be told apart.
  [ "$group" = "$child" ] && echo "$child" >> "$ARBOR_LEDGER/groups"

  while kill -0 "$child" 2>/dev/null; do
    [ -z "$reason" ] && [ "$SECONDS" -ge "$limit" ] && reason="still running after its time limit (ARBOR_TIME_LIMIT)"
    if [ -n "$reason" ]; then
      echo "::error title=mac-shell::$reason: stopping $(basename "$ARBOR_SCRIPT")"
      # The script alone first, so that it asks Arbor to quit and the windows come back.
      arbor_signal TERM "$child"
      if ! arbor_await_exit "$child" 30; then
        # bash sees a signal only when the program in its foreground has ended: a sleep, a build, a dialog nobody answers.
        anonymous=$(arbor_leftovers | awk -v known=" $child $(cut -d ' ' -f 1 "$ARBOR_LEDGER/pids" | tr '\n' ' ')" '!index(known, " " $1 " ")')
        # shellcheck disable=SC2086
        arbor_signal TERM $anonymous
        arbor_await_exit "$child" 300 || arbor_signal KILL "$child"
      fi
      break
    fi
    sleep 0.5
  done
  wait "$child" 2>/dev/null
  code=$?
  trap : INT TERM HUP
  case "$reason" in
    "") ;;
    interrupted) code=130 ;;
    *) code=124 ;;
  esac

  arbor_sweep
  if ! on_throwaway_mac; then
    arbor_fingerprint > "$ARBOR_LEDGER/after"
    echo
    if diff "$ARBOR_LEDGER/before" "$ARBOR_LEDGER/after" > "$ARBOR_LEDGER/changed"; then
      echo "this Mac after the run: nothing that was looked at differs from before"
    else
      arbor_tell_what_differs
    fi
    arbor_discreet_files
  fi
  arbor_leave "$code"
}

# MARK: Building

# arbor_bundle <name> <bundle id> <executable>: a minimal app bundle, so that the process has a bundle id as a
# person's apps do. Rules, `exclude` and the saved state's hints all go by it.
arbor_bundle() {
  local app="$ARBOR_APPS/$1.app"
  rm -rf "${app:?}"
  mkdir -p "$app/Contents/MacOS"
  cp "$3" "$app/Contents/MacOS/$(basename "$3")" || return 1
  cat > "$app/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleIdentifier</key><string>$2</string>
  <key>CFBundleName</key><string>$1</string>
  <key>CFBundleExecutable</key><string>$(basename "$3")</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSUIElement</key><true/>
</dict></plist>
PLIST
}

# The copied executable's signature knows nothing of the bundle around it. macOS runs it anyway; LaunchServices and
# Login Items are more particular.
arbor_sign() { limit 30 codesign --force --sign - "$ARBOR_APPS/$1.app" >> "$ARBOR_OUT/build-bundles.log" 2>&1; }

# arbor_is_current <source> <program>
arbor_is_current() { [ -x "$2" ] && [ "$2" -nt "$1" ]; }

arbor_build() {
  local started=$SECONDS compiler helper curtain
  # A rehearsal has nothing to build, and a script that another script of the same run started (the suite's sections) finds it done.
  if [ -n "${ARBOR_BUILT:-}" ] || [ -f "$ARBOR_LEDGER/built" ]; then
    arbor_count_displays
    arbor_make_room || exit 77
    return 0
  fi
  mkdir -p "$ARBOR_APPS"
  # Each only if its source is newer than what the last script compiled: a minute saved for every script of a list.
  arbor_is_current "$ARBOR_ROOT/scripts/mac-shell/vdisplay.m" "$ARBOR_VDISPLAY" \
    || clang -fobjc-arc -O1 -framework Foundation -framework ApplicationServices -framework CoreGraphics -framework ColorSync \
      "$ARBOR_ROOT/scripts/mac-shell/vdisplay.m" -o "$ARBOR_VDISPLAY" > "$ARBOR_OUT/build-vdisplay.log" 2>&1 &
  helper=$!
  # Language mode 5: it is a script, and strict concurrency has nothing to protect in it.
  arbor_is_current "$ARBOR_ROOT/scripts/mac-shell/pointer.swift" "$ARBOR_POINTER" \
    || swiftc -O -swift-version 5 "$ARBOR_ROOT/scripts/mac-shell/pointer.swift" -o "$ARBOR_POINTER" \
      > "$ARBOR_OUT/build-pointer.log" 2>&1 &
  compiler=$!
  arbor_is_current "$ARBOR_ROOT/scripts/mac-shell/curtain.swift" "$ARBOR_CURTAIN" \
    || swiftc -O -swift-version 5 "$ARBOR_ROOT/scripts/mac-shell/curtain.swift" -o "$ARBOR_CURTAIN" \
      > "$ARBOR_OUT/build-curtain.log" 2>&1 &
  curtain=$!
  if ! swift build > "$ARBOR_OUT/build.log" 2>&1; then
    echo "swift build failed. Its errors, then the end of mac-shell/build.log:"
    grep "error:" "$ARBOR_OUT/build.log" | sort -u | head -n 40
    tail -n 30 "$ARBOR_OUT/build.log"
    # Both compilers' errors in one run: another run takes far longer than the extra lines take to read.
    wait "$compiler" || cat "$ARBOR_OUT/build-pointer.log"
    die "swift build failed: $(grep -c "error:" "$ARBOR_OUT/build.log") error lines, see output.txt"
  fi
  if ! wait "$compiler"; then
    cat "$ARBOR_OUT/build-pointer.log"
    die "scripts/mac-shell/pointer.swift did not compile"
  fi
  # Needed on a person's Mac only, where arbor_start declines without it.
  if ! wait "$curtain"; then
    echo "scripts/mac-shell/curtain.swift did not compile: no session on a person's Mac"
    cat "$ARBOR_OUT/build-curtain.log"
  fi
  # It leans on private API, so a new macOS may break it, which must not cost the scripts that do not use it.
  if ! wait "$helper"; then
    echo "scripts/mac-shell/vdisplay.m did not compile: no virtual display, appearance or spaces in this run"
    cat "$ARBOR_OUT/build-vdisplay.log"
  fi
  ARBOR_DISPLAY_COUNT=$("$ARBOR_POINTER" displays | wc -l | tr -d ' ')
  arbor_bundle ArborTestWindows "$ARBOR_TEST_BUNDLE" "$ARBOR_BIN/ArborTestWindows" \
    && arbor_bundle ArborTestWindows2 "$ARBOR_TEST_BUNDLE_2" "$ARBOR_BIN/ArborTestWindows" \
    || die "could not make the app bundles in $ARBOR_APPS"
  arbor_sign ArborTestWindows && arbor_sign ArborTestWindows2 \
    || echo "note: could not sign the app bundles: $(tail -n 1 "$ARBOR_OUT/build-bundles.log")"
  # A second bundle with Arbor's identifier could come between a person's installed Arbor and its arbor:// links.
  if on_throwaway_mac; then
    arbor_bundle Arbor com.evbarleyg.arbor "$ARBOR_BIN/Arbor" \
      && cp "$ARBOR_ROOT/Resources/Info.plist" "$ARBOR_APP/Contents/Info.plist" \
      || die "could not make $ARBOR_APP"
    arbor_sign Arbor || echo "note: could not sign $ARBOR_APP: $(tail -n 1 "$ARBOR_OUT/build-bundles.log")"
  fi
  echo "built Arbor, the pointer tool and the app bundles in $((SECONDS - started))s"
  : > "$ARBOR_LEDGER/built"
  # Now, before the script opens its first window: whatever opens later opens in front of the curtain.
  arbor_make_room || exit 77
}

# MARK: Sessions

arbor_settings() {
  ARBOR_GAP=$(python3 -c 'import json, sys; print(round(json.loads(sys.argv[1]).get("gap", 12)))' "$1") \
    || die "arbor_settings: not a JSON object: $1"
  printf '%s\n' "$1" > "$ARBOR_HOME/settings.json"
}

# Several scripts can leave their logs in one folder, as the suite's sections do.
arbor_log_name() {
  if [ "$ARBOR_SESSION" -le 1 ]; then echo "$1-$ARBOR_NAME.log"; else echo "$1-$ARBOR_NAME-$ARBOR_SESSION.log"; fi
}

arbor_log() {
  if [ -f "$ARBOR_HOME/arbor.log" ]; then cp "$ARBOR_HOME/arbor.log" "$ARBOR_OUT/$(arbor_log_name arbor)"; fi
  if ls "$ARBOR_HOME"/traces/*.jsonl > /dev/null 2>&1; then
    mkdir -p "$ARBOR_OUT/traces"
    cp "$ARBOR_HOME"/traces/*.jsonl "$ARBOR_OUT/traces/"
  fi
}

# arbor_open_app <1|2> <executable> <count> [arguments…]: starts a test app and sets W1… (or V1…).
# ArborTestWindows lives until its stdin closes, so this shell holds the other end (descriptor 9, or 8), and no
# other process may: an app that inherited the other's would keep it alive.
arbor_open_app() {
  local which=$1 binary=$2 count=$3 hello="" tries=0 index=0 id ids letter=W
  shift 3
  [ "$which" = 2 ] && letter=V
  rm -f "$ARBOR_SESSION_DIR/stdin$which" "$ARBOR_SESSION_DIR/hello$which"
  mkfifo "$ARBOR_SESSION_DIR/stdin$which"
  # An app with a bundle id would leave its windows' saved state in the person's Library.
  "$binary" --count "$count" "$@" -ApplePersistenceIgnoreState YES < "$ARBOR_SESSION_DIR/stdin$which" > "$ARBOR_SESSION_DIR/hello$which" \
    2>> "$ARBOR_OUT/test-windows.log" 3>&- 7>&- 8>&- 9>&- &
  started $!
  if [ "$which" = 2 ]; then
    ARBOR_WINDOWS_PID_2=$!
    exec 8> "$ARBOR_SESSION_DIR/stdin$which"
  else
    ARBOR_WINDOWS_PID=$!
    exec 9> "$ARBOR_SESSION_DIR/stdin$which"
  fi
  while [ -z "$hello" ] && [ "$tries" -lt 100 ]; do
    sleep 0.1
    hello=$(head -n 1 "$ARBOR_SESSION_DIR/hello$which" 2>/dev/null)
    tries=$((tries + 1))
  done
  ids=$(python3 -c 'import json, sys; print(*json.loads(sys.argv[1])["windows"])' "$hello" 2>/dev/null) \
    || die "ArborTestWindows did not report its windows (got: $hello)"
  for id in $ids; do
    index=$((index + 1))
    eval "$letter$index=$id"
  done
  ARBOR_WINDOW_IDS="$ARBOR_WINDOW_IDS $ids"
}

arbor_start() {
  local count=4
  case "${1:-}" in
    "" | *[!0-9]*) ;;
    *) count=$1; shift ;;
  esac
  [ -z "$ARBOR_PID" ] || die "arbor_start: a session is running; call arbor_stop first"
  [ -x "$ARBOR_BIN/Arbor" ] && [ -x "$ARBOR_POINTER" ] && [ -x "$ARBOR_TEST_WINDOWS" ] \
    || die "arbor_start: call arbor_build first"
  arbor_make_room || exit 77
  ARBOR_SESSION=$((ARBOR_SESSION + 1))
  ARBOR_WINDOW_IDS=""
  ARBOR_LAUNCH_ENV=""
  # shellcheck disable=SC2086
  arbor_open_app 1 "$ARBOR_TEST_WINDOWS" "$count" ${ARBOR_TEST_WINDOWS_ARGS:-}
  if [ "${ARBOR_SECOND_APP:-0}" -gt 0 ]; then
    # shellcheck disable=SC2086
    arbor_open_app 2 "$ARBOR_TEST_WINDOWS_2" "$ARBOR_SECOND_APP" ${ARBOR_SECOND_APP_ARGS:-}
  fi
  arbor_launch "$@"
  # On a person's Mac an app of theirs is in front until a test window is clicked. Until then keys are declined, an ⌥-click hides that
  # app, and Arbor's menu, which a picture may show, names it ("Shortcuts Off in …"). So the test windows' app comes forward by itself.
  # Not when Arbor alone starts again: a test app is in front by then, and all of this one's windows coming forward would upset what is claimed.
  on_throwaway_mac || echo activate >&9
}

reopen_test_windows() {
  [ -z "$ARBOR_PID" ] || die "reopen_test_windows: Arbor is limited to the processes it was started with; end it first"
  arbor_make_room || exit 77
  arbor_close_windows
  # shellcheck disable=SC2086
  arbor_open_app 1 "$ARBOR_TEST_WINDOWS" "$1" ${ARBOR_TEST_WINDOWS_ARGS:-}
}

# Starts Arbor on the session's windows, settings and saved state, and waits until it manages the windows.
# Without arguments, with those of the session's last launch.
arbor_relaunch() { arbor_launch "$@"; }
# Under names of their own in here, so that a script's own function of the same name changes nothing in this file.
arbor_launch() {
  local argument status="" deadline binary="$ARBOR_BIN/Arbor" expected pids id
  for argument in "$@"; do
    case "$argument" in
      [A-Za-z_]*=*) ;;
      *) die "arbor_start: expected NAME=value, got $argument" ;;
    esac
  done
  [ -z "$ARBOR_PID" ] || die "arbor_relaunch: Arbor is running; call arbor_quit or arbor_kill first"
  arbor_make_room || exit 77
  [ $# -gt 0 ] && ARBOR_LAUNCH_ENV="$*"
  if [ -n "${ARBOR_BUNDLED:-}" ]; then
    on_throwaway_mac || die "ARBOR_BUNDLED: only on a throwaway Mac (write: if on_throwaway_mac; then ARBOR_BUNDLED=1; fi)"
    binary="$ARBOR_APP/Contents/MacOS/Arbor"
  fi
  # ARBOR_ONLY_PIDS among the arguments (and the lists some scripts add to it) point Arbor at other processes' windows.
  if ! on_throwaway_mac; then
    for argument in "$@" "+=${ARBOR_EXTRA_PIDS:-}" "+=${ARBOR_MORE_PIDS:-}"; do
      case "$argument" in
        ARBOR_ONLY_PIDS=* | +=*) ;;
        *) continue ;;
      esac
      for id in $(echo "${argument#*=}" | tr ',' ' '); do
        if ! arbor_started_here "$id"; then
          echo "skipped: Arbor would arrange the windows of process $id, which was running before this script: they are somebody's"
          exit 77
        fi
      done
    done
  fi
  pids=$ARBOR_WINDOWS_PID${ARBOR_WINDOWS_PID_2:+,$ARBOR_WINDOWS_PID_2}${ARBOR_EXTRA_PIDS:+,$ARBOR_EXTRA_PIDS}
  # shellcheck disable=SC2086
  set -- $ARBOR_WINDOW_IDS
  expected=$#

  # Later assignments win, so ARBOR_NO_STATUS_ITEM=0 or ARBOR_NO_HOTKEYS=0 among the arguments switches that part on.
  # shellcheck disable=SC2086
  # No watchdog: arbor_kill and arbor_stop end an Arbor that must then stay dead (ARBOR_NO_WATCHDOG=0 brings it back).
  env ARBOR_ONLY_PIDS="$pids" ARBOR_NO_PROMPT=1 ARBOR_DEBUG=1 ARBOR_NO_HOTKEYS=1 ARBOR_NO_STATUS_ITEM=1 \
    ARBOR_NO_WATCHDOG=1 $ARBOR_LAUNCH_ENV "$binary" >> "$ARBOR_OUT/$(arbor_log_name arbor-stderr)" 2>&1 3>&- 7>&- 8>&- 9>&- &
  ARBOR_PID=$!
  started "$ARBOR_PID"

  deadline=$((SECONDS + 20))
  while [ "$SECONDS" -lt "$deadline" ]; do
    "$ARBOR_BIN/arborctl" state 2>/dev/null | python3 "$ARBOR_STATE_PY" ready "$expected" 2>/dev/null
    case $? in
      0)
        echo "session $ARBOR_SESSION: Arbor pid $ARBOR_PID, test windows$ARBOR_WINDOW_IDS (pid $pids)"
        "$ARBOR_BIN/arborctl" status
        # With ARBOR_RECORD=1 every launch on a throwaway Mac is recorded (docs/TRACES.md): what macOS reported and what Arbor asked of
        # it comes back in mac-shell/traces/ and replays on Linux from then on. Never on a person's Mac: a trace holds every press
        # of the button, wherever it landed.
        if [ "${ARBOR_RECORD:-}" = 1 ] && on_throwaway_mac && [ -z "${ARBOR_REHEARSAL:-}" ]; then
          ARBOR_LAUNCHES=$((${ARBOR_LAUNCHES:-0} + 1))
          "$ARBOR_BIN/arborctl" trace on "$ARBOR_NAME-$ARBOR_LAUNCHES" > /dev/null 2>&1 || echo "note: this launch is not recorded"
        fi
        # So that nobody takes a film in which nothing moves for a bug.
        [ "$("$ARBOR_POINTER" reduce-motion 2>/dev/null)" = true ] \
          && echo "Reduce Motion is on, so Arbor shows no motion (macos_reduce_motion off, before arbor_start, changes that)"
        return 0 ;;
      3)
        # For a script that is about exactly that (check-F63.sh).
        [ -n "${ARBOR_MAY_LACK_PERMISSION:-}" ] && { echo "session $ARBOR_SESSION: Arbor pid $ARBOR_PID, launched without the permission"; return 0; }
        die "Arbor has no Accessibility permission here, so it cannot move windows" ;;
    esac
    kill -0 "$ARBOR_PID" 2>/dev/null || break
    sleep 0.2
  done
  status=$("$ARBOR_BIN/arborctl" status 2>&1)
  echo "Arbor did not get going; its last status: $status"
  tail -n 30 "$ARBOR_HOME/arbor.log" "$ARBOR_OUT/$(arbor_log_name arbor-stderr)" 2>/dev/null
  die "Arbor did not start managing the $expected test windows"
}

# A drag or a modifier left held (the script was stopped half way through one) would outlive the session: nobody
# else is there to let go.
arbor_let_go() { "$ARBOR_POINTER" calm 2>/dev/null; }

arbor_quit() {
  [ -n "$ARBOR_PID" ] || return 0
  arbor_let_go
  echo "> quit"
  "$ARBOR_BIN/arborctl" quit
  check "Arbor exits within 5 s of quit" arbor_await_exit "$ARBOR_PID" 50
  kill -TERM "$ARBOR_PID" 2>/dev/null && { arbor_await_exit "$ARBOR_PID" 20 || kill -KILL "$ARBOR_PID" 2>/dev/null; }
  wait "$ARBOR_PID" 2>/dev/null
  ARBOR_PID=""
}

arbor_kill() {
  [ -n "$ARBOR_PID" ] || return 0
  echo "> kill -${1:-KILL} (Arbor)"
  kill "-${1:-KILL}" "$ARBOR_PID" 2>/dev/null
  arbor_await_exit "$ARBOR_PID" 50 || kill -KILL "$ARBOR_PID" 2>/dev/null
  wait "$ARBOR_PID" 2>/dev/null
  ARBOR_PID=""
}

# If it has not after all (the click on Quit missed, or was declined), it is ended here: nothing may wait for it for ever.
arbor_ended() {
  [ -n "$ARBOR_PID" ] || return 0
  if ! ended "$ARBOR_PID"; then
    arbor_kill TERM
    return 1
  fi
  ARBOR_PID=""
}

arbor_stop() {
  local id number=0
  arbor_release_keys
  [ -n "$ARBOR_PID" ] || return 0
  # The same title every time: one claim, which every session of every script has to bear out.
  # parity.json lists it under T61 by hand: proof.sh makes it too, so it is not suite-parity.py's to list or take off.
  arbor_heading "▸ quitting puts every window back in view"
  arbor_quit
  for id in $ARBOR_WINDOW_IDS; do
    number=$((number + 1))
    check "window $number is back on screen after quitting" eventually arbor_in_view "$id"
  done
  [ -n "${1:-}" ] && shot "$1"
  arbor_log
  arbor_close_windows
  arbor_new_home
}

arbor_close_windows() {
  if [ -n "$ARBOR_WINDOWS_PID" ]; then
    exec 9>&-
    arbor_await_exit "$ARBOR_WINDOWS_PID" 30 || kill -TERM "$ARBOR_WINDOWS_PID" 2>/dev/null
    wait "$ARBOR_WINDOWS_PID" 2>/dev/null
  fi
  if [ -n "$ARBOR_WINDOWS_PID_2" ]; then
    exec 8>&-
    arbor_await_exit "$ARBOR_WINDOWS_PID_2" 30 || kill -TERM "$ARBOR_WINDOWS_PID_2" 2>/dev/null
    wait "$ARBOR_WINDOWS_PID_2" 2>/dev/null
  fi
  ARBOR_WINDOWS_PID=""
  ARBOR_WINDOWS_PID_2=""
  ARBOR_WINDOW_IDS=""
}

# Whatever ends the script, the processes stop and the log comes back. This is the orderly half, in which Arbor is asked to
# quit and puts the windows back; the supervisor sees to what is left, and to a script that never got here.
arbor_exit() {
  local code=$?
  trap - EXIT
  # Not '': what is ignored here would be ignored by every program the clean-up starts, too.
  trap : INT TERM HUP
  eval "$ARBOR_AT_EXIT"
  if [ "$code" -ge 2 ] && [ "$code" -ne 77 ]; then
    # Whatever claim was under way did not get to finish, so it must not count as borne out. (77: it never began.)
    ARBOR_FAILED=$((ARBOR_FAILED + 1))
    echo "  ✘ the script ended early, with exit code $code"
    arbor_record "  ✘ the script ended early, with exit code $code"
  fi
  arbor_stop
  arbor_close_claim
  arbor_log
  arbor_close_windows
  display_remove
  [ -n "$ARBOR_CURTAIN_IS_MINE" ] && kill_started "$ARBOR_CURTAIN_PID"
  # shellcheck disable=SC2086
  scratch_remove $ARBOR_SESSION_DIRS
  find "$ARBOR_OUT" -name "*.log" -size 0 -delete
  if [ $((ARBOR_PASSED + ARBOR_FAILED)) -gt 0 ]; then
    echo
    echo "$ARBOR_PASSED passed, $ARBOR_FAILED failed"
    [ "$ARBOR_KNOWN_FAILED" -eq 0 ] || echo "$ARBOR_KNOWN_FAILED of the failures are known"
    arbor_record ""
    arbor_record "$ARBOR_PASSED passed, $ARBOR_FAILED failed"
  else
    # A script without claims or checks has no evidence to leave.
    rm -f "$ARBOR_EVIDENCE"
    rmdir "$ARBOR_OUT/evidence" 2>/dev/null
  fi
  [ "$code" -eq 0 ] && [ "$ARBOR_FAILED" -gt "$ARBOR_KNOWN_FAILED" ] && code=1
  if ! arbor_supervised; then
    arbor_sweep
    scratch_remove "$ARBOR_LEDGER"
  fi
  exit "$code"
}

# MARK: Talking to Arbor

ctl() {
  arbor_still_watched
  echo "> $*" >&3
  "$ARBOR_BIN/arborctl" "$@"
}

# Arbor's state, then the window server's list of windows: state.py answers from both.
arbor_ask() {
  { "$ARBOR_BIN/arborctl" state && "$ARBOR_POINTER" windows; } \
    | ARBOR_PID="$ARBOR_PID" ARBOR_GAP="$ARBOR_GAP" python3 "$ARBOR_STATE_PY" "$@"
}
state() { arbor_ask json; }
summary() { arbor_ask summary; }

# MARK: Talking to the test windows

# arbor_tell <descriptor> <process id> <file of replies> <request…>: prints what the app answers, which for most requests
# is nothing, once it has carried the request out: a `ping` sent after it comes back then. Fails when the answer is an error.
arbor_tell() {
  local descriptor=$1 pid=$2 file=$3 before tries=0 reply token=$RANDOM$RANDOM
  shift 3
  echo "> test windows: $*" >&3
  # Writing to a pipe nobody reads would end this script with SIGPIPE, exit trap and all.
  if [ -z "$pid" ] || ! kill -0 "$pid" 2>/dev/null; then
    echo "the test windows' process is gone"
    return 1
  fi
  before=$(wc -l < "$file" | tr -d ' ')
  printf '%s\nping %s\n' "$*" "$token" >&"$descriptor"
  until grep -F "{\"pong\":$token}" "$file" > /dev/null; do
    if [ "$tries" -ge 100 ]; then
      echo "the test windows did not answer: $*"
      return 1
    fi
    sleep 0.05
    tries=$((tries + 1))
  done
  # Any pong: one that an app which hung for a while sends late belongs to a request that gave up on it.
  reply=$(tail -n "+$((before + 1))" "$file" | grep -v '^{"pong":' || true)
  [ -z "$reply" ] || printf '%s\n' "$reply"
  case "$reply" in *'"error"'*) return 1 ;; esac
}
tw() { arbor_tell 9 "$ARBOR_WINDOWS_PID" "$ARBOR_SESSION_DIR/hello1" "$@"; }
tw2() { arbor_tell 8 "$ARBOR_WINDOWS_PID_2" "$ARBOR_SESSION_DIR/hello2" "$@"; }

# arbor_open_window <tw|tw2> <request that opens a window> <variable> <the request's arguments…>
arbor_open_window() {
  local teller=$1 request=$2 name=$3 reply id
  shift 3
  if ! reply=$("$teller" "$request" "$@"); then
    echo "$reply"
    eval "$name=0"
    return 1
  fi
  id=$(printf '%s' "$reply" | sed -E 's/.*"window":([0-9]+).*/\1/')
  case "$id" in
    "" | *[!0-9]*)
      echo "the test windows opened nothing: $reply"
      eval "$name=0"
      return 1 ;;
  esac
  eval "$name=$id"
  ARBOR_WINDOW_IDS="$ARBOR_WINDOW_IDS $id"
}
open_window() { arbor_open_window tw open "$@"; }
open_window2() { arbor_open_window tw2 open "$@"; }
open_dialog() { arbor_open_window tw dialog "$@"; }
open_tab() { arbor_open_window tw tab "$@"; }

forget_window() {
  local id kept=""
  for id in $ARBOR_WINDOW_IDS; do
    [ "$id" = "$1" ] || kept="$kept $id"
  done
  ARBOR_WINDOW_IDS=$kept
}

# Whichever of the two apps the window belongs to.
events_of() {
  local reply
  reply=$(tw events "$1" 3> /dev/null) || reply=$(tw2 events "$1" 3> /dev/null) || { echo "$reply" >&2; return 1; }
  printf '%s\n' "$reply" | sed -E "s/.*\"$2\":([0-9]+).*/\1/"
}

# MARK: Where things are

frame_of() { arbor_ask frame "$1"; }
slot_of() { arbor_ask slot "$1"; }
real_frame_of() { "$ARBOR_POINTER" frame "$1"; }
width_of() { real_frame_of "$1" | awk '{ print int($3 + 0.5) }'; }
height_of() { real_frame_of "$1" | awk '{ print int($4 + 0.5) }'; }

desktop_is_bare() { [ -z "${ARBOR_CURTAIN_PID:-}" ]; }

take() {
  local names=$1 answer word count=0
  shift
  answer=$("$@" 2>&1) || die "no place to work with: $* says: $answer"
  for word in $answer; do
    case "$word" in
      "" | - | *[!0-9.-]*) die "no place to work with: $* says: $answer" ;;
    esac
    count=$((count + 1))
  done
  # shellcheck disable=SC2086
  set -- $names
  [ "$count" -eq $# ] || die "expected $# numbers ($names), got: $answer"
  # shellcheck disable=SC2086,SC2229
  read -r $names <<< "$answer"
}

# arbor_point <x y w h> <expression for x> <expression for y>
arbor_point() {
  local x=$1 y=$2 w=$3 h=$4
  echo "$(($5)) $(($6))"
}

# A point of the title bar that no other window covers, if there is one.
# shellcheck disable=SC2046
titlebar_of() { "$ARBOR_POINTER" grab "$1" 2>/dev/null || arbor_point $(frame_of "$1") "x + w / 2" "y + 12"; }
# arbor_point_on <id> <expression for x> <expression for y>: fails for a window that is out of view, where there is
# nothing to aim at.
arbor_point_on() {
  local frame
  frame=$(arbor_ask shown "$1") || return 1
  # shellcheck disable=SC2086
  arbor_point $frame "$2" "$3"
}
center_of() { arbor_point_on "$1" "x + w / 2" "y + h / 2"; }
seam_right_of() { arbor_point_on "$1" "x + w + $ARBOR_GAP / 2" "y + h / 2"; }
seam_below() { arbor_point_on "$1" "x + w / 2" "y + h + $ARBOR_GAP / 2"; }
# shellcheck disable=SC2046
tile_of() { arbor_point $(arbor_ask tile "$1") "x + w / 2" "y + h / 2"; }
# shellcheck disable=SC2046
desktop_point() { arbor_point $(arbor_ask desktop) "x + w / 2" "y + h / 2"; }

# shellcheck disable=SC2046
edge_point() {
  case "$1" in
    left) arbor_point $(arbor_ask screen) "x + 3" "y + h / 2" ;;
    right) arbor_point $(arbor_ask screen) "x + w - 3" "y + h / 2" ;;
    top | up) arbor_point $(arbor_ask screen) "x + w / 2" "y + 3" ;;
    bottom | down) arbor_point $(arbor_ask screen) "x + w / 2" "y + h - 3" ;;
    *) echo "edge_point: left, right, top or bottom, not $1" >&2; return 1 ;;
  esac
}

# An eighth of the way in: well inside the outer 30 % that docks beside the window.
zone_of() {
  case "$2" in
    left) arbor_point_on "$1" "x + w / 8" "y + h / 2" ;;
    right) arbor_point_on "$1" "x + w - w / 8" "y + h / 2" ;;
    top | up) arbor_point_on "$1" "x + w / 2" "y + h / 8" ;;
    bottom | down) arbor_point_on "$1" "x + w / 2" "y + h - h / 8" ;;
    *) echo "zone_of: left, right, top or bottom, not $2" >&2; return 1 ;;
  esac
}

screen_of() { arbor_ask screen "$1"; }
display_frame_of() { arbor_ask display-frame "$1"; }
display_of() { arbor_ask display "$1"; }

overlays() { "$ARBOR_POINTER" windows --pid "$ARBOR_PID"; }

has_overlay() { overlays | awk -v level="$1" '$3 == level && $8 == "on" { found = 1 } END { exit !found }'; }

overlay_frame() {
  overlays | awk -v level="$1" '$3 == level && $8 == "on" && !found { print $4, $5, $6, $7; found = 1 } END { exit !found }'
}

status_item() { "$ARBOR_POINTER" status-item "$ARBOR_PID"; }
status_item_frame() { "$ARBOR_POINTER" status-item "$ARBOR_PID" --frame; }

# MARK: Checks

# In per cent. `visible` prints 0.07 or 1.00.
arbor_share_in_view() {
  local share
  share=$("$ARBOR_POINTER" visible "$1") || return 1
  share=${share/./}
  echo "$((10#$share))"
}

in_view() { arbor_in_view "$@"; }
arbor_in_view() {
  local share
  share=$(arbor_share_in_view "$1") || return 1
  [ "$share" -ge 90 ] || { echo "only $share % of it is to be seen: $(real_frame_of "$1")"; return 1; }
}

out_of_view() {
  local share
  share=$(arbor_share_in_view "$1") || return 1
  [ "$share" -le 5 ] || { echo "$share % of it is to be seen: $(real_frame_of "$1")"; return 1; }
}

is() {
  case "$1" in
    on_screen) arbor_in_view "$2" ;;
    in_slot) arbor_ask in_slot "$2" ;;
    display[1-9]) [ "$(arbor_ask display "$2")" = "${1#display}" ] ;;
    *) arbor_ask is "$2" "$1" ;;
  esac
}

# Whether two rectangles are the same to within three points, as arbor-e2e allows.
arbor_close() {
  # shellcheck disable=SC2086
  set -- $1 $2
  [ $# -eq 8 ] || return 1
  local index=1 a b
  while [ "$index" -le 4 ]; do
    eval "a=\${$index%.*} b=\${$((index + 4))%.*}"
    [ $((a - b)) -le 3 ] && [ $((b - a)) -le 3 ] || return 1
    index=$((index + 1))
  done
}

inside() {
  # shellcheck disable=SC2086
  set -- $1 $2
  [ $# -eq 8 ] || return 1
  [ "${1%.*}" -ge "${5%.*}" ] && [ "${2%.*}" -ge "${6%.*}" ] \
    && [ $((${1%.*} + ${3%.*})) -le $((${5%.*} + ${7%.*})) ] && [ $((${2%.*} + ${4%.*})) -le $((${6%.*} + ${8%.*})) ]
}


for arbor_name in at_edge fills in_slot frame_is corner_is left_of above same_column same_row desktop_between camera_on can \
  depth_is count no_overlaps layout_matches tile_is tile_shown; do
  eval "$arbor_name() { arbor_ask $arbor_name \"\$@\"; }"
done
unset arbor_name

# Tries a command for up to three seconds: the window server applies moves a moment after Arbor makes them.
# Prints what the last try printed, which is where `check` finds why it failed.
eventually() {
  local deadline=$((SECONDS + 3)) output
  while :; do
    if output=$("$@" 2>&1); then
      [ -n "$output" ] && printf '%s\n' "$output"
      return 0
    fi
    if [ "$SECONDS" -gt "$deadline" ]; then
      printf '%s\n' "$output"
      return 1
    fi
    sleep 0.1
  done
}

stays() {
  local tries=0
  while [ "$tries" -lt 3 ]; do
    "$@" || return 1
    sleep 0.4
    tries=$((tries + 1))
  done
  "$@"
}

fails() {
  if "$@" > /dev/null 2>&1; then
    echo "it succeeded: $*"
    return 1
  fi
}

exits_with() {
  local expected=$1 code
  shift
  "$@" > /dev/null 2>&1
  code=$?
  [ "$code" -eq "$expected" ] || { echo "exit code $code, not $expected: $*"; return 1; }
}

says() {
  local text=$1 output
  shift
  output=$("$@" 2>&1)
  case "$output" in *"$text"*) ;; *) echo "it said: $(printf '%s' "$output" | head -n 1 | cut -c 1-120)"; return 1 ;; esac
}

# The command line itself, when its words and its exit code are the point (`ctl` prints and records them).
arborctl() { "$ARBOR_BIN/arborctl" "$@"; }

about() {
  [ -n "$1" ] && [ -n "$2" ] || { echo "nothing to compare: '$1' and '$2'"; return 1; }
  local difference=$(($1 - $2))
  [ "${difference#-}" -le "${3:-3}" ] || { echo "$1 is not about $2"; return 1; }
}

width_is() { about "$(width_of "$1")" "$2" "${3:-3}"; }
height_is() { about "$(height_of "$1")" "$2" "${3:-3}"; }
# arbor_compare <what it is called> <actual> <test's operator> <bound>
arbor_compare() { [ "$2" "$3" "$4" ] || { echo "it is $2 $1, which is not $3 $4"; return 1; }; }
wider_than() { arbor_compare wide "$(width_of "$1")" -gt "$2"; }
narrower_than() { arbor_compare wide "$(width_of "$1")" -lt "$2"; }
taller_than() { arbor_compare high "$(height_of "$1")" -gt "$2"; }
shorter_than() { arbor_compare high "$(height_of "$1")" -lt "$2"; }

front_is() {
  local front
  front=$("$ARBOR_POINTER" front 2>&1)
  [ "$front" = "$1" ] || { echo "the app in front is $front, not $1"; return 1; }
}

received() { arbor_compare "$2 events" "$(events_of "$1" "$2")" "$3" "$4"; }

logged() {
  arbor_log_since "$ARBOR_STEP_MARK" | grep -F -e "$*" > /dev/null || { echo "arbor.log does not say: $*"; return 1; }
}

# With ARBOR_DEBUG the log has a line for every command, whether or not it succeeded.
arbor_ran_since() {
  local mark=$1
  shift
  arbor_log_since "$mark" | grep -F -e "INFO  $*: " -e "DEBUG $* failed: " > /dev/null \
    || { echo "Arbor did not run: $*"; return 1; }
}
ran() { arbor_ran_since "$ARBOR_STEP_MARK" "$@"; }

pressed() {
  local chord=$1 mark
  shift
  mark=$(arbor_log_lines)
  key "$chord"
  eventually arbor_ran_since "$mark" "$@"
}

# What a failed check leaves behind: a picture every time; the state and the log since the claim once per claim.
arbor_explain() {
  local name="fail-$ARBOR_NAME-$ARBOR_FAILED"
  # Never on a person's Mac, whatever ARBOR_SHOTS says: there a check fails just when a window of theirs has come forward.
  if on_throwaway_mac; then
    arbor_capture "$name" && echo "      picture: mac-shell/$name.png"
  fi
  [ -z "$ARBOR_STEP_EXPLAINED" ] || return 0
  ARBOR_STEP_EXPLAINED=yes
  if [ -n "$ARBOR_PID" ] && kill -0 "$ARBOR_PID" 2>/dev/null; then
    summary 2>&1 | sed 's/^/      | /'
  fi
  arbor_log_since "$ARBOR_STEP_MARK" | tail -n 25 | cut -c 26-230 | sed 's/^/      log | /'
  on_throwaway_mac && arbor_in_the_way | sed 's/^/      in the way? | /'
}

# What shows above the apps' windows and is neither Arbor's nor the Mac's furniture: an alert of macOS's own takes the presses and
# the keys meant for the windows under it, and every check after it fails for a reason that no log has.
arbor_in_the_way() {
  "$ARBOR_POINTER" windows --on-screen | awk -v arbor="${ARBOR_PID:-0}" '
    $3 <= 0 || $2 == arbor { next }
    { owner = $9; for (i = 10; i <= NF; i++) owner = owner " " $i }
    owner !~ /^(Dock|Window Server|WindowManager|Control Center|SystemUIServer|Spotlight|Notification Center)$/ { print }'
}

check() {
  local what=$1 detail outcome
  shift
  arbor_still_watched
  detail=$("$@" 2>&1)
  outcome=$?
  # What is checked runs in a shell of its own, so an `exit 75` in there ends only that.
  if [ -n "${ARBOR_CURTAIN_PID:-}" ] && ! kill -0 "$ARBOR_CURTAIN_PID" 2>/dev/null; then
    echo "the curtain was taken down: somebody wants their Mac back. Ending the script"
    exit 75
  fi
  if [ "$outcome" -eq 0 ]; then
    ARBOR_PASSED=$((ARBOR_PASSED + 1))
    ARBOR_CLAIM_PASSED=$((ARBOR_CLAIM_PASSED + 1))
    echo "  ✔ $what"
    arbor_record "  ✔ $what"
  else
    ARBOR_FAILED=$((ARBOR_FAILED + 1))
    ARBOR_CLAIM_FAILED=$((ARBOR_CLAIM_FAILED + 1))
    detail=$(printf '%s\n' "$detail" | grep -v '^$' | tail -n 1 | cut -c 1-200)
    if [ -n "$ARBOR_KNOWN" ]; then
      ARBOR_KNOWN_FAILED=$((ARBOR_KNOWN_FAILED + 1))
      detail="${detail:+$detail }(known: $ARBOR_KNOWN)"
    fi
    echo "  ✘ $what${detail:+ — $detail}"
    # Why a press or a key was declined names what else is open on somebody's Mac, and evidence gets committed.
    case "$detail" in skipped:*) detail="declined on this Mac" ;; esac
    arbor_record "  ✘ $what${detail:+ — $detail}"
    arbor_explain
    return 1
  fi
}

settled() { check "windows match Arbor's layout" eventually layout_matches; }

# MARK: Pictures

# Whether nothing but the script's own windows and Arbor's shows in front of the curtain within the rectangle x y w h. From front
# to back: what comes after the curtain that covers the rectangle is hidden by it. Prints the first stranger's process, not its name.
arbor_only_ours_shows() {
  local pid owner
  while read -r pid owner; do
    [ -n "$pid" ] || continue
    arbor_started_here "$pid" && continue
    echo "${owner:-process $pid}"
    return 1
  done << LIST
$("$ARBOR_POINTER" windows --on-screen | awk -v x="$1" -v y="$2" -v w="$3" -v h="$4" -v arbor="${ARBOR_PID:-0}" -v curtain="${ARBOR_CURTAIN_PID:-0}" '
    $2 == curtain && $4 <= x && $5 <= y && $4 + $6 >= x + w && $5 + $7 >= y + h { hung = 1; exit }
    $3 < 0 || $2 == arbor || $2 == curtain { next }
    $4 >= x + w || $4 + $6 <= x || $5 >= y + h || $5 + $7 <= y { next }
    { owner = $9; for (i = 10; i <= NF; i++) owner = owner " " $i }
    owner ~ /^(Dock|Window Server|WindowManager)$/ && $6 >= 800 && $7 >= 500 { next }
    !seen[$2]++ { print $2 }
    END { if (!hung) print 1, "nobody: the curtain does not cover it" }')
LIST
}

# On a person's Mac a picture is taken when they ask for pictures, shows the main display between the menu bar and the Dock, and
# is taken only while the curtain hides everything of theirs there. Sets ARBOR_SHOT_AREA, to nothing where the whole screen may be
# seen; says why not.
ARBOR_SHOT_AREA=""
arbor_can_shoot() {
  local stranger
  ARBOR_SHOT_AREA=""
  arbor_may_shoot "$1" > /dev/null && return 0
  if [ "${ARBOR_SHOTS:-}" != 1 ]; then
    echo "shot $1: skipped: on somebody's Mac pictures are taken when they are asked for (ARBOR_SHOTS=1: what is in front of the curtain)"
    return 1
  fi
  if [ -z "${ARBOR_CURTAIN_PID:-}" ] || ! read -r ARBOR_SHOT_AREA < "$ARBOR_LEDGER/visible"; then
    ARBOR_SHOT_AREA=""
    echo "shot $1: skipped: no curtain hangs, so the picture would show what else is open on somebody's Mac"
    return 1
  fi
  # Asked without raising the dialog that screencapture would raise.
  if [ "$("$ARBOR_POINTER" screen-access 2>/dev/null)" != true ]; then
    ARBOR_SHOT_AREA=""
    echo "shot $1: skipped: this terminal has no Screen Recording permission, and nobody is asked for it"
    return 1
  fi
  # shellcheck disable=SC2086
  if ! stranger=$(arbor_only_ours_shows $ARBOR_SHOT_AREA); then
    ARBOR_SHOT_AREA=""
    echo "shot $1: skipped: a window of $stranger shows in front of the curtain, and it is somebody's"
    return 1
  fi
}

# One file per display, the main one first. $2: `unasked` when the caller asks arbor_can_shoot before and after a burst itself.
arbor_capture() {
  local name=$1 asked=${2:-} index=2
  [ "$asked" = unasked ] || arbor_can_shoot "$name" || return 1
  set -- "$ARBOR_OUT/$name.png"
  if [ -n "$ARBOR_SHOT_AREA" ]; then
    set -- "-R$(echo "$ARBOR_SHOT_AREA" | tr ' ' ',')" "$@"
  else
    # Asked again here: without an area the picture is of everything, however this line was reached.
    arbor_may_shoot "$name" || return 1
    while [ "$index" -le "$ARBOR_DISPLAY_COUNT" ]; do
      set -- "$@" "$ARBOR_OUT/$name-d$index.png"
      index=$((index + 1))
    done
  fi
  # -x: no sound. -C: with the pointer, which is half the story of a drag.
  if ! screencapture -x -C "$@" 2>> "$ARBOR_OUT/screencapture.log" || [ ! -s "$ARBOR_OUT/$name.png" ]; then
    echo "shot $name: screencapture failed ($(tail -n 1 "$ARBOR_OUT/screencapture.log"))"
    return 1
  fi
  [ "$asked" = unasked ] || arbor_keep_shots "$name"
}

# A banner may have come up between the look and the picture: then the picture goes. $@: the pictures' names.
arbor_keep_shots() {
  local name stranger
  [ -n "$ARBOR_SHOT_AREA" ] || return 0
  # shellcheck disable=SC2086
  stranger=$(arbor_only_ours_shows $ARBOR_SHOT_AREA) && return 0
  for name in "$@"; do rm -f "$ARBOR_OUT/$name.png"; done
  echo "shot $*: thrown away: a window of $stranger came up in front of the curtain meanwhile, and it is somebody's"
  return 1
}

# At most 1600 pixels wide: enough to judge a layout by, and a Retina screen's picture is four times the bytes.
arbor_finish_shot() {
  local path width also=""
  for path in "$ARBOR_OUT/$1.png" "$ARBOR_OUT/$1"-d[2-9].png; do
    [ -f "$path" ] || continue
    width=$(sips -g pixelWidth "$path" 2>/dev/null | awk '/pixelWidth/ { print $2 }')
    [ "${width:-0}" -gt 1600 ] && sips --resampleWidth 1600 "$path" > /dev/null 2>&1
    [ "$path" = "$ARBOR_OUT/$1.png" ] || also="$also and $(basename "$path")"
  done
  echo "shot: mac-shell/$1.png$also"
}

shot() {
  sleep "${ARBOR_SETTLE:-0.7}"
  arbor_capture "$1" && arbor_finish_shot "$1"
}

# The window server hands over that window's own picture, whatever lies over or under it, so nothing of anybody's can be in it.
look() {
  local pid
  sleep "${ARBOR_SETTLE:-0.7}"
  case "${2:-}" in "" | *[!0-9]*) echo "look $1: skipped: '${2:-}' is no window id"; return 1 ;; esac
  pid=$("$ARBOR_POINTER" windows | awk -v id="$2" '$1 == id { print $2; exit }')
  if ! arbor_is_pid "$pid" || ! arbor_started_here "$pid"; then
    echo "look $1: skipped: window $2 is not of a process this run started"
    return 1
  fi
  if [ "$("$ARBOR_POINTER" screen-access 2>/dev/null)" != true ]; then
    echo "look $1: skipped: this terminal has no Screen Recording permission, and nobody is asked for it"
    return 1
  fi
  # safe anywhere: -l takes one window, which the lines above found to be the run's own. -o: without its shadow
  if ! screencapture -x -o "-l$2" "$ARBOR_OUT/$1.png" 2>> "$ARBOR_OUT/screencapture.log" || [ ! -s "$ARBOR_OUT/$1.png" ]; then
    echo "look $1: screencapture failed ($(tail -n 1 "$ARBOR_OUT/screencapture.log"))"
    return 1
  fi
  arbor_finish_shot "$1"
}

# -R takes a rectangle in global coordinates, and it may span displays.
panorama() {
  local all
  sleep "${ARBOR_SETTLE:-0.7}"
  arbor_may_shoot "$1" || return 1
  all=$("$ARBOR_POINTER" displays | awk '
    NR == 1 { left = $2; top = $3; right = $2 + $4; bottom = $3 + $5 }
    { if ($2 < left) left = $2; if ($3 < top) top = $3 }
    { if ($2 + $4 > right) right = $2 + $4; if ($3 + $5 > bottom) bottom = $3 + $5 }
    END { printf "%d,%d,%d,%d", left, top, right - left, bottom - top }')
  if ! screencapture -x -C "-R$all" "$ARBOR_OUT/$1.png" 2>> "$ARBOR_OUT/screencapture.log"; then
    echo "panorama $1: screencapture failed ($(tail -n 1 "$ARBOR_OUT/screencapture.log"))"
    return 1
  fi
  arbor_finish_shot "$1"
}

# The look at what shows takes a moment, so on a person's Mac the picture is that much late.
shot_after() {
  sleep "$1"
  arbor_capture "$2" && arbor_finish_shot "$2"
}

arbor_now() { perl -MTime::HiRes=time -e 'printf "%.2f", time'; }

film() {
  local index=1 started names=""
  arbor_can_shoot "$1" || return 1
  started=$(arbor_now)
  while [ "$index" -le "$2" ]; do
    arbor_capture "$1-$index" unasked
    names="$names $1-$index"
    index=$((index + 1))
  done
  echo "film: $2 pictures in $(echo "$(arbor_now) - $started" | bc) s"
  # shellcheck disable=SC2086
  arbor_keep_shots $names || return 1
  index=1
  while [ "$index" -le "$2" ]; do
    arbor_finish_shot "$1-$index"
    index=$((index + 1))
  done
}

# MARK: Real input

# Nothing is pressed once nobody is left to let go of it, and the pointer's place is noted before it first moves.
arbor_before_input() {
  arbor_still_watched
  if [ -n "${ARBOR_CURTAIN_PID:-}" ] && ! kill -0 "$ARBOR_CURTAIN_PID" 2>/dev/null; then
    echo "the curtain was taken down: somebody wants their Mac back. Ending the script"
    exit 75
  fi
  [ -f "$ARBOR_LEDGER/pointer" ] && return 0
  : > "$ARBOR_LEDGER/input"
  "$ARBOR_POINTER" where > "$ARBOR_LEDGER/pointer" 2>/dev/null
}
# The window server's list names every app the person has open. What a script prints of it names the run's own and macOS's furniture.
arbor_nameless() {
  ARBOR_PROCESSES=$(ps -A -o pid=,etime=) awk -v age="$(($(date +%s) - ARBOR_RUN_STARTED + 1))" '
    BEGIN {
      rows = split(ENVIRON["ARBOR_PROCESSES"], row, "\n")
      for (r = 1; r <= rows; r++) {
        if (split(row[r], field, " ") != 2) continue
        parts = split(field[2], day, "-"); count = split(day[parts], unit, ":"); seconds = 0
        for (i = 1; i <= count; i++) seconds = seconds * 60 + unit[i]
        if ((parts == 2 ? day[1] * 86400 : 0) + seconds <= age) ours[field[1]] = 1
      }
    }
    {
      owner = $9; for (i = 10; i <= NF; i++) owner = owner " " $i
      if (!($2 in ours) && owner !~ /^(Dock|Window Server|WindowManager|Control Cent(er|re)|Notification Cent(er|re)|SystemUIServer|Spotlight|Wallpaper|loginwindow)$/)
        owner = "somebody"
      print $1, $2, $3, $4, $5, $6, $7, $8, owner
    }'
}
pointer() {
  arbor_before_input
  arbor_input_is_ours "$@" || return 1
  if [ "${1:-}" = windows ] && ! on_throwaway_mac; then "$ARBOR_POINTER" "$@" | arbor_nameless; else "$ARBOR_POINTER" "$@"; fi
}
arbor_input() {
  echo "> $*" >&3
  arbor_before_input
  if ! arbor_input_is_ours "$@"; then
    # Whatever the checks after it find: "nothing happened" would hold for the wrong reason.
    arbor_missed "real input is let through on this Mac"
    return 1
  fi
  "$ARBOR_POINTER" "$@"
}
move() { arbor_input move "$@"; }
click() { arbor_input click "$@"; }
rightclick() { arbor_input click "$@" --right; }
dblclick() {
  local x=$1 y=$2
  shift 2
  arbor_input click "$x" "$y" 2 "$@"
}
drag() { arbor_input drag "$@"; }
release() { arbor_input release "$@"; }
# A key left down would outlive the script, as a button would: whatever `key … --down` pressed is let go of when the
# session stops or the script ends, interrupted or not. Letting go of a key that is up already does nothing.
# On the run's record, so that the supervisor can do it for a script that was killed; `pointer calm` goes by what macOS says is down.
key() {
  case " $* " in *" --down "*) echo "$1" >> "$ARBOR_LEDGER/keys" ;; esac
  arbor_input key "$@"
}
pinch() { arbor_input pinch "$@"; }

key_to() {
  local why
  why=$(eventually is focused "$1" 2>&1) || { arbor_missed "the window has the keyboard for $2 ($why)"; return 1; }
  key "$2"
}

# Input that could not be aimed: the claim it was part of cannot hold, whatever the checks after it find. Inside
# `check`, which runs its command in a subshell, saying why and failing is enough.
arbor_missed() {
  if [ "$BASH_SUBSHELL" -gt 0 ]; then
    echo "$*"
  else
    check "$*" false
  fi
  return 1
}

# A window wholly behind others cannot be clicked forward. Its app brings it forward, as ⌘` or its Dock menu would.
arbor_bring_forward() { tw front "$1" > /dev/null 2>&1 || tw2 front "$1" > /dev/null 2>&1; }

click_window() {
  local point
  if ! point=$("$ARBOR_POINTER" spot "$1" 2>&1); then
    arbor_bring_forward "$1"
    sleep 0.2
    point=$("$ARBOR_POINTER" spot "$1" 2>&1) || { arbor_missed "the window can be clicked ($point)"; return 1; }
  fi
  # shellcheck disable=SC2086
  click $point
}

click_button() {
  local point
  point=$("$ARBOR_POINTER" button "$1" "$2" 2>&1) || { arbor_missed "its $2 button can be clicked ($point)"; return 1; }
  arbor_in_view "$1" > /dev/null 2>&1 || { arbor_missed "its $2 button can be clicked (the window is out of view)"; return 1; }
  # shellcheck disable=SC2086
  click $point
}

drag_window() {
  local id=$1 from
  shift
  # `drag_window $W1 $(zone_of $W2 left)` with nowhere to go
  case "${1:-}" in "" | -*) arbor_missed "the window can be dragged (there is no point to drag it to)"; return 1 ;; esac
  if ! from=$("$ARBOR_POINTER" grab "$id" 2>/dev/null); then
    click_window "$id" || return 1
    sleep 0.2
    from=$("$ARBOR_POINTER" grab "$id" 2>&1) || { arbor_missed "the window can be dragged ($from)"; return 1; }
  fi
  # shellcheck disable=SC2086
  drag $from "$@"
}

# Once something is docked the icon grows into a row of buttons, and a plain click in its middle presses one of them. A right click
# anywhere on it opens the menu, on the single icon too.
open_menu() {
  local point
  point=$(status_item) || return 1
  # shellcheck disable=SC2086
  rightclick $point
}

# arbor_in_open_menu x y: the point is in a menu as far as it shows. A menu taller than the display is cut off at its foot, and
# Accessibility gives the rows below the cut the places they would have.
arbor_in_open_menu() {
  overlays | awk -v x="$1" -v y="$2" '
    $3 == 101 && $8 == "on" && x >= $4 && x < $4 + $6 && y >= $5 && y < $5 + $7 { found = 1 } END { exit !found }'
}

# The menu is rebuilt as it opens, so an item's place is asked for only then.
click_menu() {
  local point
  open_menu || return 1
  sleep 0.4
  while [ $# -gt 0 ]; do
    if ! point=$(eventually "$ARBOR_POINTER" menu-item "$ARBOR_PID" "$1"); then
      echo "$point"
      key escape
      return 1
    fi
    # shellcheck disable=SC2086
    if ! arbor_in_open_menu $point; then
      # With no row chosen ↑ goes to the last one, and the menu scrolls to its end.
      key up
      sleep 0.3
      point=$("$ARBOR_POINTER" menu-item "$ARBOR_PID" "$1" 2>&1)
      # A press out there would choose nothing and close the menu, and look like a click that worked.
      # shellcheck disable=SC2086
      if ! arbor_in_open_menu $point; then
        echo "$1 is at $point, which the open menu does not show: it is taller than the display"
        key escape
        return 1
      fi
    fi
    # A press that was declined chose nothing, and the menu is still open.
    # shellcheck disable=SC2086
    if ! click $point; then
      key escape
      return 1
    fi
    sleep 0.3
    shift
  done
}

# MARK: macOS

# macOS 15 and later tile a window dragged to a screen edge, which competes with Arbor's edge docking.
macos_tiling() {
  local name value
  case "${1:-}" in
    on | off)
      if arbor_may "change the setting \"drag windows to screen edges to tile\" and restart WindowManager"; then
        [ "$1" = on ] && value=true || value=false
        for name in EnableTilingByEdgeDrag EnableTopTilingByEdgeDrag; do
          defaults write com.apple.WindowManager "$name" -bool "$value"
        done
        # The setting is read when WindowManager starts; launchd starts it again.
        killall WindowManager 2>/dev/null
        sleep 1
      fi ;;
  esac
  for name in EnableTilingByEdgeDrag EnableTopTilingByEdgeDrag EnableTilingOptionAccelerator EnableTiledWindowMargins; do
    echo "com.apple.WindowManager $name: $(defaults read com.apple.WindowManager "$name" 2>/dev/null || echo "not set")"
  done
}

# Whether macOS itself tiles a window that is dragged to the left, right or top edge of the screen. A key that is not there means
# on, from macOS 15 on, which is the first that tiles.
macos_tiles() {
  case "$(sw_vers -productVersion)" in 1[0-4].*) return 1 ;; esac
  [ "$(defaults read com.apple.WindowManager EnableTilingByEdgeDrag 2>/dev/null || echo 1)" = 1 ] \
    || [ "$(defaults read com.apple.WindowManager EnableTopTilingByEdgeDrag 2>/dev/null || echo 1)" = 1 ]
}

# Where macOS tiles, those edges are macOS's and Arbor stands aside. So a script that docks by dragging to a screen edge asks this before
# arbor_start: on a throwaway Mac it switches macOS's tiling off; a person's setting is theirs, and the answer there is what they chose.
screen_edges_dock() {
  macos_tiles || return 0
  on_throwaway_mac || return 1
  macos_tiling off > /dev/null
  ! macos_tiles
}

# As macOS comes, ⌃ pressed twice starts Dictation, and asks first, in an alert that stays in front of everything. Two shortcuts of
# Arbor's posted one after the other were that to it (seen on GitHub's Macs, in the middle of the suite).
macos_dictation_shortcut() {
  case "${1:-}" in
    off)
      if arbor_may "switch the shortcut for Dictation off"; then
        defaults write com.apple.HIToolbox AppleDictationAutoEnable -int 0
        defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add 164 "{ enabled = 0; }"
        # Makes the system read its shortcuts again, which it otherwise does at login.
        if [ -x /System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings ]; then
          /System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings -u
        fi
      fi ;;
  esac
}

# Since macOS 14 a click on the wallpaper sweeps every window aside, and the next one only brings them back.
macos_click_wallpaper() {
  local value
  case "${1:-}" in
    on | off)
      if arbor_may "change the setting \"click wallpaper to reveal desktop\" and restart WindowManager"; then
        [ "$1" = on ] && value=true || value=false
        defaults write com.apple.WindowManager EnableStandardClickToShowDesktop -bool "$value"
        killall WindowManager 2>/dev/null
        sleep 1
      fi ;;
  esac
  echo "com.apple.WindowManager EnableStandardClickToShowDesktop: $(defaults read com.apple.WindowManager EnableStandardClickToShowDesktop 2>/dev/null || echo "not set")"
}

# Arbor reads it when it starts.
macos_reduce_motion() {
  local value
  case "${1:-}" in
    on | off)
      if arbor_may "change the Accessibility setting Reduce Motion"; then
        [ "$1" = on ] && value=true || value=false
        defaults write com.apple.universalaccess reduceMotion -bool "$value"
      fi ;;
  esac
  echo "Reduce Motion: $("$ARBOR_POINTER" reduce-motion)"
}

# Both are read by an app when it starts, like Reduce Motion. In System Settings the first switches the second on with it; here each
# is set alone, and whoever wants what a person gets sets both.
macos_increase_contrast() {
  local value
  case "${1:-}" in
    on | off)
      if arbor_may "change the Accessibility setting Increase Contrast"; then
        [ "$1" = on ] && value=true || value=false
        defaults write com.apple.universalaccess increaseContrast -bool "$value"
      fi ;;
  esac
  echo "Increase Contrast: $("$ARBOR_POINTER" increase-contrast)"
}

macos_reduce_transparency() {
  local value
  case "${1:-}" in
    on | off)
      if arbor_may "change the Accessibility setting Reduce Transparency"; then
        [ "$1" = on ] && value=true || value=false
        defaults write com.apple.universalaccess reduceTransparency -bool "$value"
      fi ;;
  esac
  echo "Reduce Transparency: $("$ARBOR_POINTER" reduce-transparency)"
}

# MARK: A second display (vdisplay.m: private API, for tests only)

arbor_count_displays() { ARBOR_DISPLAY_COUNT=$("$ARBOR_POINTER" displays | wc -l | tr -d ' '); }

# Waits up to five seconds for macOS to have that many displays.
arbor_await_displays() {
  local tries=0
  arbor_count_displays
  while [ "$ARBOR_DISPLAY_COUNT" -ne "$1" ]; do
    [ "$tries" -ge 50 ] && return 1
    sleep 0.1
    tries=$((tries + 1))
    arbor_count_displays
  done
}

# The same vendor, product and serial number every time, so that macOS takes it for the same display coming
# back; ARBOR_DISPLAY_SERIAL makes it another one. ARBOR_DISPLAY_ARGS: more arguments, e.g. --hidpi.
display_add() {
  local width=${1:?display_add <width> <height> [side]} height=${2:?display_add <width> <height> [side]} hello="" tries=0
  arbor_may "plug in a virtual display, at which macOS rearranges every window" || return 1
  [ -z "$ARBOR_DISPLAY_PID" ] || die "display_add: there is a virtual display already; call display_remove first"
  [ -x "$ARBOR_VDISPLAY" ] || die "display_add: no vdisplay tool; call arbor_build first and read build-vdisplay.log"
  : > "$ARBOR_SESSION_DIR/display"
  # shellcheck disable=SC2086
  "$ARBOR_VDISPLAY" add "$width" "$height" "Arbor Test Display" --serial "${ARBOR_DISPLAY_SERIAL:-1}" ${ARBOR_DISPLAY_ARGS:-} \
    > "$ARBOR_SESSION_DIR/display" 2>> "$ARBOR_OUT/vdisplay.log" 9>&- 8>&- 3>&- &
  ARBOR_DISPLAY_PID=$!
  started "$ARBOR_DISPLAY_PID"
  while [ -z "$hello" ] && [ "$tries" -lt 80 ] && kill -0 "$ARBOR_DISPLAY_PID" 2>/dev/null; do
    sleep 0.1
    hello=$(head -n 1 "$ARBOR_SESSION_DIR/display")
    tries=$((tries + 1))
  done
  if [ -z "$hello" ]; then
    kill "$ARBOR_DISPLAY_PID" 2>/dev/null
    ARBOR_DISPLAY_PID=""
    die "display_add: no virtual display ($(tail -n 1 "$ARBOR_OUT/vdisplay.log"))"
  fi
  DISPLAY2_ID=${hello%% *}
  DISPLAY2_UUID=${hello##* }
  DISPLAY2_SIZE="$width $height"
  arbor_await_displays 2
  echo "> display_add $width $height: display $DISPLAY2_ID, $DISPLAY2_UUID"
  display_move "${3:-right}"
}

display_move() {
  local main x y offset=${2:-0}
  arbor_may "rearrange the displays" || return 1
  [ -n "$ARBOR_DISPLAY_PID" ] || die "display_move: there is no virtual display"
  main=$("$ARBOR_VDISPLAY" list | awk '$8 == "main" { print $5, $6 }')
  case "$1" in
    right) x=${main% *} y=$offset ;;
    left) x=-${DISPLAY2_SIZE% *} y=$offset ;;
    above) x=$offset y=-${DISPLAY2_SIZE#* } ;;
    below) x=$offset y=${main#* } ;;
    *) die "display_move: right, left, above or below, not $1" ;;
  esac
  echo "> display_move $*: now at $("$ARBOR_VDISPLAY" move "$DISPLAY2_ID" "$x" "$y" 2>&1)"
  sleep 3 # macOS tells the apps, and moves the windows along, a moment later: one second proved too short for the real-app suite
}

display_remove() {
  [ -n "$ARBOR_DISPLAY_PID" ] || return 0
  echo "> display_remove"
  kill -TERM "$ARBOR_DISPLAY_PID" 2>/dev/null
  wait "$ARBOR_DISPLAY_PID" 2>/dev/null
  ARBOR_DISPLAY_PID=""
  arbor_await_displays 1 || echo "display_remove: macOS still lists $ARBOR_DISPLAY_COUNT displays"
}

# MARK: Appearance, wallpaper, Spaces

appearance() {
  case "${1:-}" in
    dark | light) ;;
    *) die "appearance: dark or light" ;;
  esac
  arbor_may "switch the system to $1 mode" || return 1
  echo "> appearance $1: now $("$ARBOR_VDISPLAY" appearance "$1" 2>&1)"
  sleep 1 # apps redraw a moment later
}

wallpaper() {
  local picture=${1:?wallpaper <file>|#rrggbb|gradient} folder size
  arbor_may "replace the desktop picture of every display" || return 1
  folder=$(dirname "$ARBOR_POINTER")
  case "$picture" in
    gradient)
      # The main display's size, so that the grid's lines are 100 pixels apart on the screen too.
      size=$("$ARBOR_POINTER" displays | awk 'NR == 1 { print $6, $7 }')
      picture="$folder/wallpaper-gradient.png"
      # shellcheck disable=SC2086
      "$ARBOR_POINTER" picture "$picture" $size "#1d2b64" "#f8a13f" || return 1 ;;
    \#*)
      picture="$folder/wallpaper-${picture#?}.png"
      "$ARBOR_POINTER" picture "$picture" 64 64 "$1" || return 1 ;;
  esac
  echo "> wallpaper $1"
  "$ARBOR_POINTER" wallpaper "$picture" || return 1
  sleep 1 # the wallpaper fades in
}

spaces() { "$ARBOR_VDISPLAY" spaces; }

# Nothing public makes a Space, so this does what a person does: Mission Control, then the + at the end of the
# Spaces bar, which System Events can press. Needs permission to control System Events (GitHub's Macs have it).
space_add() {
  arbor_may "add a Space, which nothing here can remove again" || return 1
  echo "> space_add"
  open -a "Mission Control"
  sleep 1.5
  arbor_within 20 osascript -e 'tell application "System Events" to click button 1 of group "Spaces Bar" of group 1 of group "Mission Control" of process "Dock"' \
    > /dev/null || echo "space_add: System Events could not press the button"
  sleep 0.5
  "$ARBOR_POINTER" key escape
  sleep 1
}

space_go() {
  case "${1:-}" in
    left | right) ;;
    *) die "space_go: left or right" ;;
  esac
  arbor_may "switch Spaces" || return 1
  arbor_input key "ctrl+$1"
  sleep 1.5 # the slide
}

# MARK: Go

# Last, so that the supervisor has every function above.
case $- in
  *i*)
    echo "lib.sh is for scripts: source it from one, not from a shell somebody types in" >&2
    return 2 ;;
esac
arbor_supervised || arbor_supervise "$@"
[ -d "${ARBOR_LEDGER:-}" ] && arbor_is_scratch "$ARBOR_LEDGER" || die "this run's record ($ARBOR_LEDGER) is gone"
# The supervisor puts the script's process group on record as well, a moment after it has started the script. Should it be killed in that
# moment, nobody could tell afterwards what the script started. Twice on record does no harm.
[ "$(ps -o pgid= -p $$ 2>/dev/null | tr -d ' ')" = "$$" ] && echo "$$" >> "$ARBOR_LEDGER/groups"
# An Arbor that a script starts by itself, past arbor_start, inherits these: on a person's Mac it arranges no window (process 1 has
# none), is not started again when it is killed, and raises no dialog, unless the script says otherwise on that very line.
# And no Arbor there photographs windows for its stage: with Screen Recording it takes pictures of every app's, and of the Desktop
# with the names of the files on it, and shows the latter on a panel of its own, which would then be in the script's pictures.
# Nor does it open an app: it knows only test windows, so `summon` would take every app of the person's for one that has to be opened.
on_throwaway_mac || export ARBOR_ONLY_PIDS=1 ARBOR_NO_WATCHDOG=1 ARBOR_NO_PROMPT=1 ARBOR_NO_PICTURES=1 ARBOR_NO_OPENING=1
arbor_new_home
arbor_begin_evidence
trap arbor_exit EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
trap 'exit 129' HUP
