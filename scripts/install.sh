#!/bin/bash
# Installs build/Arbor.app, or removes an installed Arbor. `make install` and `make uninstall` run it.
#
#   scripts/install.sh               quit a running Arbor, replace the installed app, link arborctl, start the new build
#   scripts/install.sh --uninstall   remove the login item, the app and the link; settings and state stay
#
#   PREFIX    the folder Arbor.app goes into (default ~/Applications; /Applications works for an administrator)
#   BINDIR    the folder arborctl is linked into (default: ~/.local/bin if it is on the PATH, else /usr/local/bin
#             if you may write there, else ~/.local/bin all the same, with a hint about the PATH)
#   LAUNCH=0  do not start Arbor after installing
#   ARBOR_KEEP_LOGIN_ITEM=1  leave the login item alone when uninstalling (for tests on a Mac that has another Arbor)
#   ARBOR_UNATTENDED=1  go ahead although nobody is at a terminal
#   ARBOR_LEAVE_WINDOWS=1  uninstall although windows are out of view
set -euo pipefail
cd "$(dirname "$0")/.."

built=build/Arbor.app
prefix=${PREFIX:-$HOME/Applications}

# Both ways quit the Arbor that is running and take away the app its owner uses, with no copy kept; installing then starts this
# build on their windows, their settings and their arrangement. That is for a person to decide. Loops and agents run what a
# page or a hand-back tells them to, and they have no terminal on standard input. GitHub's Macs are nobody's, and run their
# jobs as `runner`; a runner that somebody set up on their own Mac says GITHUB_ACTIONS=true as well, under that person's name.
nobodys_mac() { [ "${GITHUB_ACTIONS:-}" = true ] && [ "$(id -un)" = runner ]; }
if [ ! -t 0 ] && [ "${ARBOR_UNATTENDED:-}" != 1 ] && ! nobodys_mac; then
  echo "install.sh: nobody is at a terminal here, and this would quit a running Arbor and replace or remove $prefix/Arbor.app." >&2
  echo "Nothing was touched. Run it from a terminal; or, if the owner of this Mac asked for it, with ARBOR_UNATTENDED=1." >&2
  exit 77
fi
# The path without symbolic links, which is how a running Arbor's own path reads.
[ "${1:-}" = --uninstall ] || mkdir -p "$prefix" 2>/dev/null || true
if [ -d "$prefix" ]; then prefix=$(cd "$prefix" && pwd -P); fi
installed="$prefix/Arbor.app"
tool=Contents/Helpers/arborctl

on_path() { case ":$PATH:" in *":$1:"*) return 0 ;; *) return 1 ;; esac; }

# The pids of Arbor running from the folder being replaced, its watchdog's among them, and the watchdog's alone. By either name of a
# folder under /private: of a copy in /private/tmp macOS lists the app there and its watchdog, which Arbor starts by its bundle's own idea
# of the path, under /tmp (seen on macOS 26.6.2). In ~/Applications there is one name.
case "$installed" in /private/*) running="^(/private)?${installed#/private}/Contents/MacOS/Arbor" ;; *) running="^$installed/Contents/MacOS/Arbor" ;; esac
installed_pids() { pgrep -f "$running" 2>/dev/null || true; }
watchdog_pids() { pgrep -f "$running --watchdog" 2>/dev/null || true; }

# wait_until <tenths of a second> <command…>: whether the command succeeded in time.
wait_until() {
  local tenths=$1
  shift
  while ! "$@"; do
    tenths=$((tenths - 1))
    [ "$tenths" -gt 0 ] || return 1
    sleep 0.1
  done
}
# Where arborctl looks for a running Arbor (Sources/ArborIPC/ArborPaths.swift). A quitting Arbor removes the file once every
# window is back in view. The file is looked at, and Arbor not asked: while it puts windows back it answers nobody, and
# an arborctl that gave up waiting would pass for an Arbor that has gone.
socket=${ARBOR_SOCKET:-${ARBOR_HOME:-$HOME/Library/Application Support/Arbor}/arbor.sock}
socket_gone() { [ ! -S "$socket" ]; }
not_running() { [ -z "$(installed_pids)" ]; }

# Quits a running Arbor and waits until it has gone. Quitting puts every window back in view, which takes a
# moment, and ends by removing the control socket, which must not happen to the socket of the next build. Only one
# Arbor runs at a time: a copy started beside another leaves at once. And an Arbor that quits in good order tells its
# watchdog so, which otherwise would start it again.
quit_arbor() {
  local arborctl=$1
  if [ -x "$arborctl" ] && "$arborctl" quit >/dev/null 2>&1; then
    echo "Asked the running Arbor to quit; it puts every window back in view first"
    # Seldom more than a second; an app that hangs costs Arbor a second for each of its windows.
    wait_until 200 socket_gone || true
  fi
  wait_until 30 not_running && return 0
  # It did not hear, or hangs. While it lives, macOS would bring it to the front instead of starting the new build.
  # Windows it leaves out of view are brought back by the next Arbor that starts.
  echo "Arbor is still running from $installed; stopping it"
  # The watchdog first: it takes any other end of Arbor for an accident.
  # shellcheck disable=SC2046
  kill $(watchdog_pids) 2>/dev/null || true
  # shellcheck disable=SC2046
  kill $(installed_pids) 2>/dev/null || true
  wait_until 30 not_running && return 0
  # shellcheck disable=SC2046
  kill -9 $(installed_pids) 2>/dev/null || true
  wait_until 30 not_running || echo "It could not be stopped" >&2
}

# How many windows are all but off every display, as the window server has them (scripts/out-of-view.swift). Nothing if nobody can say.
# Arbor is not asked: one that may not move windows (its switch under Accessibility is off, or belongs to a build with another
# signature) or that hangs puts nothing back when it goes, whatever it answers.
out_of_view() {
  local count
  count=$(swift scripts/out-of-view.swift 2>/dev/null) || return 0
  case "$count" in "" | *[!0-9]*) ;; *) echo "$count" ;; esac
}

if [ "${1:-}" = --uninstall ]; then
  if [ -d "$installed" ]; then
    quit_arbor "$installed/$tool"
    # Looked at after it has gone, which is when it puts windows back, and before the only thing is removed that could fetch them.
    stranded=$(out_of_view)
    if [ "${stranded:-0}" != 0 ] && [ "${ARBOR_LEAVE_WINDOWS:-}" != 1 ]; then
      {
        echo "install.sh: Arbor has quit, but $stranded window(s) are still out of view, at the edge of a display with a point showing."
        echo "Arbor is what brings them back, so NOTHING WAS REMOVED. It could not move them: its switch under System Settings → Privacy &"
        echo "Security → Accessibility is off or belongs to another build, or it hung. To fetch them:"
        echo "  open \"$installed\"              a starting Arbor brings back whatever it finds out of view, once that switch is on"
        echo "  \"$installed/$tool\" float-all   then look: every window should be in view"
        echo "  make uninstall"
        echo "If they are not Arbor's doing (other tools keep windows there too): ARBOR_LEAVE_WINDOWS=1 make uninstall"
      } >&2
      exit 75
    fi
    # Builds from before the stamp would take the argument for none and start as the app.
    if [ -z "${ARBOR_KEEP_LOGIN_ITEM:-}" ] && grep -q ArborCommit "$installed/Contents/Info.plist" 2>/dev/null; then
      "$installed/Contents/MacOS/Arbor" --launch-at-login off || true
    fi
    # What Arbor switched off under Desktop & Dock for its owner goes back as it was. A build that does not know the argument would take it
    # for none and start as the app, and the file may be another build's.
    if [ -f "${ARBOR_HOME:-$HOME/Library/Application Support/Arbor}/macos-settings-before.json" ] \
      && grep -q "Arbor --fix-setup undo" "$installed/Contents/MacOS/Arbor" 2>/dev/null; then
      "$installed/Contents/MacOS/Arbor" --fix-setup undo || true
    fi
    rm -rf "$installed"
    echo "Removed $installed"
  else
    echo "There is no $installed"
  fi
  # What an install that was killed may have left, beside the app or alone.
  rm -rf "$prefix/.Arbor.app.new"
  for folder in "${BINDIR:-}" "$HOME/.local/bin" /usr/local/bin; do
    link="$folder/arborctl"
    if [ -L "$link" ] && [ "$(readlink "$link")" = "$installed/$tool" ]; then
      rm -f "$link"
      echo "Removed $link"
    fi
  done
  echo "Left alone:"
  echo "  $HOME/Library/Application Support/Arbor   settings.json, state.json (your arrangement) and arbor.log"
  echo "  Arbor's entry under Accessibility           tccutil reset Accessibility com.evbarleyg.arbor"
  echo "  the signing certificate, if you made one    scripts/make-signing-identity.sh --remove"
  exit 0
fi

[ $# -eq 0 ] || { echo "usage: scripts/install.sh [--uninstall]" >&2; exit 64; }
[ -d "$built" ] || { echo "install.sh: there is no $built; run \`make app\` first" >&2; exit 1; }

[ -d "$prefix" ] && [ -w "$prefix" ] || { echo "install.sh: you may not write to $prefix; choose another with PREFIX=…" >&2; exit 1; }

# Copied beside the old app before anything is touched: a copy that fails half way (a full disk) must not leave the Mac without the
# Arbor that was running, which is what fetches windows that are out of view.
staged="$prefix/.Arbor.app.new"
rm -rf "$staged"
# Whatever ends this before the swap (⌃C while the old Arbor takes its time to quit) leaves no hidden copy behind.
trap 'rm -rf "$staged"' EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM
if ! cp -R "$built" "$staged"; then
  echo "install.sh: $built could not be copied to $prefix. Nothing was changed: the Arbor that was installed is, and goes on running." >&2
  exit 1
fi

# The new arborctl: an Arbor of any age understands `quit`.
quit_arbor "$built/$tool"
# The build that comes fetches them, so this goes on. But it says so: until then they look lost.
stranded=$(out_of_view)
if [ "${stranded:-0}" != 0 ]; then
  echo "NOTE: $stranded window(s) are still out of view: the Arbor that quit could not move them (its switch under Accessibility is off or"
  echo "  belongs to another build, or it hung). The new build brings them back when it starts, once ITS switch is on."
fi
# From here to the end of the swap nothing ends it (nor `rm`, which ⌃C reaches too): the old Arbor has quit, and with the old app
# half removed and the new one cleared away there would be none to fetch windows that are out of view.
trap '' HUP INT TERM
rm -rf "$installed"
mv "$staged" "$installed"
trap - EXIT HUP INT TERM
echo "Installed $installed, version $(./scripts/version.sh)"
# codesign is asked, not the build's log: that has scrolled away, and `make install` may be installing what an earlier `make app` built.
# Read whole and matched here, not with grep -q: that stops reading at the match, codesign dies of it, and pipefail makes a no of the yes.
ad_hoc() {
  local said
  said=$(codesign --display --verbose=2 "$installed" 2>&1) || return 1
  case $'\n'"$said"$'\n' in *$'\nSignature=adhoc\n'*) return 0 ;; *) return 1 ;; esac
}
# Said last, and aloud: it is the one thing here that costs the person something, every time.
say_what_the_signature_costs() {
  ad_hoc || return 0
  echo
  echo "NOTE: THIS BUILD IS SIGNED AD HOC. To macOS it is a new app, so macOS will ask for the Accessibility permission again,"
  echo "  now and after every \`make install\`. An entry an older build left under Accessibility does nothing for this one:"
  echo "  switch it off and on again, or"
  echo "    tccutil reset Accessibility com.evbarleyg.arbor     then switch Arbor on again"
  echo "  To be asked once more and never again:  ./scripts/make-signing-identity.sh  then  make install  (docs/INSTALL.md)."
}

if [ -n "${BINDIR:-}" ]; then
  bindir=$BINDIR
elif on_path "$HOME/.local/bin"; then
  bindir=$HOME/.local/bin
elif [ -d /usr/local/bin ] && [ -w /usr/local/bin ]; then
  bindir=/usr/local/bin
else
  bindir=$HOME/.local/bin
fi
mkdir -p "$bindir"
ln -sfn "$installed/$tool" "$bindir/arborctl"
echo "Linked $bindir/arborctl"
if ! on_path "$bindir"; then
  echo "  $bindir is not on your PATH. To add it: echo 'export PATH=\"$bindir:\$PATH\"' >> ~/.zshrc"
fi

if [ "${LAUNCH:-1}" = 0 ]; then
  echo "Not started (LAUNCH=0): open \"$installed\""
  say_what_the_signature_costs
  exit 0
fi

if ! open "$installed"; then
  echo "Arbor could not be started from here (no login session?): open \"$installed\""
  say_what_the_signature_costs
  exit 0
fi
answers() { "$installed/$tool" status >/dev/null 2>&1; }
if wait_until 100 answers; then
  status=$("$installed/$tool" status | head -n 1)
  echo "Started Arbor: $status"
  case "$status" in
    waiting*)
      echo "  Switch Arbor on there. If it is on already and Arbor keeps waiting, the entry belongs to a build with another"
      echo "  signature: run  tccutil reset Accessibility com.evbarleyg.arbor  and switch it on again (docs/INSTALL.md)."
      ;;
  esac
else
  echo "Started Arbor, but it does not answer yet; see $HOME/Library/Application Support/Arbor/arbor.log"
fi
say_what_the_signature_costs
