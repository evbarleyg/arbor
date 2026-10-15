#!/bin/bash
# A rehearsal: runs Mac shell scripts (built on lib.sh) unchanged, without a Mac, against stand-ins. ON LINUX ONLY.
#
#   scripts/mac-shell/rehearse.sh <script…>        without arguments: suite.sh, where there is one
#   scripts/mac-shell/rehearse.sh --jobs 4         suite.sh on four fake Macs side by side, each with every fourth section, as `run.sh --macs 4`
#                                                  shares them out among real ones. A rehearsal waits for nothing, so it takes a core.
#
# A run on a Mac takes minutes, or somebody's Mac. This takes seconds and catches what has nothing to do
# with real windows: typos, bash mistakes, wrong geometry, and wrong expectations of the controller. Exits with the
# script's exit code (of several scripts: the highest), or 2 when the fake Mac cannot be built.
#
# It refuses to run on a Mac (exit code 77). It tells the scripts that they are on a throwaway Mac, so that the steps
# kept from people's Macs are rehearsed too, and only some of what those steps use is a stand-in: `rm`, `pkill`,
# `osascript`, `tccutil`, `lsregister` by its full path and the rest would be the real ones, on a real Mac.
#
# What stands in for what:
# - Arbor, arborctl, the pointer tool, ArborTestWindows (twice), `open` and `lsappinfo` are small wrappers
#   (rehearse/) around arbor-fakemac (Sources/arbor-fakemac), which runs the REAL controller on the fakes of
#   ArborTesting: one display, test windows where the real ones open, which window is in front, who has the
#   keyboard, title-bar drags, edge resizes, seams, tiles, shortcuts, the ⌃⌥ rectangle, pinches, the menu, URLs,
#   pause, quit, signals, SIGKILL and the watchdog, and macOS's own tiling of a window let go where it acts (on, as a Mac comes,
#   until `defaults write` says otherwise), with its preview in the list of windows while the window is held there. There is
#   no daemon: a session's history is a text file next to its ARBOR_HOME, and every call replays it. The header of
#   Sources/arbor-fakemac/main.swift says more.
#   `trace on` records as in the app (docs/TRACES.md), on the fake clock. arbor-sim is the real one.
# - Real apps, for acts in which Arbor does not run (probe-place.sh): `open -g`, `swiftc` and the helper tool apptool are rehearse/real-apps, whose header
#   says what an app is there. glide.swift is compiled and run as it is.
# - screencapture, sips, sw_vers, defaults, killall, launchctl, system_profiler, and sysctl and bc where they
#   are missing, are rehearse/mac-tools.
# - `sleep`: the fake Mac's clock moves a second with everything that is done to it, not with the real one. So a
#   wait of under a second takes 0.02 s and changes nothing, and a longer one takes no time either but moves the
#   fake clock by that much. ARBOR_REHEARSAL_SLEEP=1 keeps the real `sleep`, which does not move the fake clock.
# A script that uses a tool, a command or an option the stand-ins lack fails loudly, with a message that names
# it and exit code 64: teach it to Sources/arbor-fakemac/World*.swift or rehearse/mac-tools then.
#
# Environment:
#   ARBOR_REHEARSAL_DISPLAY="1440x900 24 70"   the display: width x height, the menu bar's height, the Dock's.
#                                              Default "1024x768 31 63", GitHub's runner.
#   ARBOR_REHEARSAL_BASH=<path>                a bash 3.2, which is what macOS has: runs the scripts, and whatever
#                                              they run as `bash`.
#   ARBOR_REHEARSAL_AS=person                  as on somebody's own Mac: lib.sh's gates stay shut, its nets look at every press
#                                              and key, and a curtain hangs behind the test windows. Shows what a script
#                                              skips there, and what it loses to the nets.
#
# What it cannot tell you: anything about AppKit's and Accessibility's timing and order of events, animations,
# the finer points of which window is in front, the Dock growing and shrinking, Spaces, full
# screen, or what anything looks like (every picture is one black pixel). A ✔ here proves the script, not Arbor.
#
# Left behind in .build/rehearsal/ (with --jobs: .build/rehearsal-1/, -2/ …, and what each printed in log.txt there): out/ (what a Mac would send back: logs, "pictures") and worlds/ (every
# session's history; `.build/debug/arbor-fakemac replay <file>` prints each line with what it answered).
set -uo pipefail

if [ "$(uname -s)" != Linux ]; then
  echo "rehearse.sh: for Linux only. It makes scripts believe that they are on a throwaway Mac, and on a real one they" >&2
  echo "would delete, kill and register real things. Here, run the script itself: lib.sh keeps it harmless." >&2
  exit 77
fi

side_by_side=1
if [ "${1:-}" = --jobs ]; then
  case "${2:-}" in
    [1-9] | [1-9][0-9]) side_by_side=$2 ;;
    *) echo "usage: scripts/mac-shell/rehearse.sh --jobs <how many>" >&2; exit 64 ;;
  esac
  shift 2
  if [ $# -gt 0 ]; then
    echo "rehearse.sh: --jobs shares out the sections of the suite, and takes no scripts" >&2
    exit 64
  fi
fi

root=$(cd "$(dirname "$0")/../.." && pwd) || exit 2
here="${root:?}/scripts/mac-shell/rehearse"
# Each of several side by side has a folder of its own, which is also how the stand-ins tell one fake Mac's processes from another's.
work="${root:?}/.build/rehearsal${ARBOR_REHEARSAL_MAC:+-$ARBOR_REHEARSAL_MAC}"
fakemac="$root/.build/debug/arbor-fakemac"
# Needs no stand-in: a script replays and judges the traces it has recorded with the real one.
sim="$root/.build/debug/arbor-sim"
cd "${root:?}" || exit 2
mkdir -p "$work"

# Built when one of them is missing or older than anything it is made of: an old arbor-sim would judge by yesterday's rules.
if command -v swift > /dev/null 2>&1; then
  changed=""
  if [ -x "$fakemac" ] && [ -x "$sim" ]; then
    changed=$({
      find Package.swift Sources -name '*.swift' -newer "$fakemac"
      find Package.swift Sources -name '*.swift' -not -path 'Sources/arbor-fakemac/*' -newer "$sim"
    } | head -n 1)
  fi
  if [ ! -x "$fakemac" ] || [ ! -x "$sim" ] || [ -n "$changed" ]; then
    if ! swift build --product arbor-fakemac > "$work/build.log" 2>&1 || ! swift build --product arbor-sim >> "$work/build.log" 2>&1; then
      cat "$work/build.log"
      echo "rehearse.sh: arbor-fakemac or arbor-sim does not build" >&2
      exit 2
    fi
  fi
fi
if [ ! -x "$fakemac" ]; then
  echo "rehearse.sh: there is no $fakemac and no swift to build it with" >&2
  exit 2
fi

if [ "$side_by_side" -gt 1 ]; then
  began=$SECONDS
  macs=""
  mac=1
  while [ "$mac" -le "$side_by_side" ]; do
    mkdir -p "$work-$mac"
    ARBOR_REHEARSAL_MAC=$mac MAC_SHELL_SHARE=$mac/$side_by_side "$0" > "$work-$mac/log.txt" 2>&1 &
    macs="$macs $!"
    mac=$((mac + 1))
  done
  worst=0
  mac=1
  for process in $macs; do
    wait "$process"
    code=$?
    [ "$code" -gt "$worst" ] && worst=$code
    cat "$work-$mac/log.txt"
    mac=$((mac + 1))
  done
  echo
  echo "on $side_by_side fake Macs side by side, in $((SECONDS - began)) s:"
  grep -h -E '^(failed: |suite: )' "$work"-[0-9]*/log.txt
  exit "$worst"
fi

# The stand-ins under the names and in the places lib.sh expects them.
stand_ins="$work/stand-ins"
rm -rf "$stand_ins" "$work/out" "$work/worlds" "$work/defaults" "$work/home" "$work/apps"
mkdir -p "$stand_ins/bin" "$stand_ins/path" "$stand_ins/Arbor.app/Contents/MacOS" "$work/out" "$work/worlds" "$work/home"
ln -s "$here/arbor" "$stand_ins/bin/Arbor"
ln -s "$here/arbor" "$stand_ins/Arbor.app/Contents/MacOS/Arbor"
ln -s "$here/fakemac" "$stand_ins/bin/arborctl"
[ -x "$sim" ] && ln -s "$sim" "$stand_ins/bin/arbor-sim"
ln -s "$here/fakemac" "$stand_ins/pointer"
# It hands on to arbor-fakemac whatever is not an app opened in the background.
ln -s "$here/real-apps" "$stand_ins/path/open"
ln -s "$here/real-apps" "$stand_ins/path/swiftc"
ln -s "$here/fakemac" "$stand_ins/path/lsappinfo"
ln -s "$here/test-windows" "$stand_ins/bin/ArborTestWindows"
ln -s "$here/test-windows" "$stand_ins/ArborTestWindows"
ln -s "$here/test-windows" "$stand_ins/ArborTestWindows2"
# safe anywhere: these are names for links to the stand-in, and none of the tools is run
for tool in screencapture sips sw_vers defaults killall launchctl system_profiler pgrep; do
  ln -s "$here/mac-tools" "$stand_ins/path/$tool"
done
sysctl -n hw.ncpu > /dev/null 2>&1 || ln -s "$here/mac-tools" "$stand_ins/path/sysctl"
command -v bc > /dev/null 2>&1 || ln -s "$here/mac-tools" "$stand_ins/path/bc"
[ -n "${ARBOR_REHEARSAL_SLEEP:-}" ] || ln -s "$here/mac-tools" "$stand_ins/path/sleep"
shell=bash
if [ -n "${ARBOR_REHEARSAL_BASH:-}" ]; then
  if [ ! -x "$ARBOR_REHEARSAL_BASH" ]; then
    echo "rehearse.sh: ARBOR_REHEARSAL_BASH is $ARBOR_REHEARSAL_BASH, which cannot be run" >&2
    exit 2
  fi
  # Not a link: a bash that is itself a wrapper finds its parts by its own path.
  printf '#!/bin/sh\nexec "%s" "$@"\n' "$ARBOR_REHEARSAL_BASH" > "$stand_ins/path/bash"
  chmod +x "$stand_ins/path/bash"
  shell="$stand_ins/path/bash"
fi

export ARBOR_REHEARSAL=1
# Nothing is more of a throwaway Mac than one that does not exist: what lib.sh keeps from people's Macs is
# rehearsed too.
export GITHUB_ACTIONS=true
if [ "${ARBOR_REHEARSAL_AS:-}" = person ]; then
  # People set CI; it must open nothing.
  unset GITHUB_ACTIONS
  export CI=true
  ln -s "$here/mac-tools" "$stand_ins/curtain"
  # Containers run as root, as whom nothing starts on a person's Mac.
  ln -s "$here/mac-tools" "$stand_ins/path/id"
fi
# What a script does to ~/Applications, ~/Library or ~/Desktop stays in here.
export HOME="$work/home" # safe anywhere: on Linux only, as the top of this file sees to
export ARBOR_BUILT=1
export ARBOR_OUT="$work/out"
export ARBOR_BIN="$stand_ins/bin"
export ARBOR_POINTER="$stand_ins/pointer"
# Neither has a stand-in, so neither may be found where a build on this machine once left the real one.
export ARBOR_VDISPLAY="$stand_ins/vdisplay"
export ARBOR_CURTAIN="$stand_ins/curtain"
export ARBOR_TEST_WINDOWS="$stand_ins/ArborTestWindows"
export ARBOR_TEST_WINDOWS_2="$stand_ins/ArborTestWindows2"
export ARBOR_APP="$stand_ins/Arbor.app"
export ARBOR_FAKEMAC="$fakemac"
export ARBOR_REHEARSAL_DIR="$work"
export ARBOR_REHEARSAL_WORLDS="$work/worlds"
# Every call replays the session in a new process, and all of them must walk dictionaries in the same order.
export SWIFT_DETERMINISTIC_HASHING=1
export PATH="$stand_ins/path:$PATH"
# A session of the caller's own has nothing to do with the ones the scripts start.
unset ARBOR_HOME ARBOR_SOCKET # safe anywhere: lib.sh sets both anew for every script before anything can use them

if ! problem=$("$fakemac" pointer displays 2>&1); then
  echo "rehearse.sh: $problem" >&2
  exit 2
fi
if [ $# -eq 0 ]; then
  if [ ! -f "$root/scripts/mac-shell/suite.sh" ]; then
    echo "usage: scripts/mac-shell/rehearse.sh <script…>" >&2
    exit 2
  fi
  set -- "$root/scripts/mac-shell/suite.sh"
fi
worst=0
for script in "$@"; do
  "$shell" "$script"
  code=$?
  [ "$code" -gt "$worst" ] && worst=$code
done
exit "$worst"
