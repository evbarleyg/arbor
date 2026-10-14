# What check-F13.sh and check-F13-system.sh share. Source it; do not run it.
#
# It sets up a place apart, which both scripts work in and which is deleted when they end:
#
#   $sandbox          a folder in /tmp
#   $HOME             $sandbox/home: ~/Applications, ~/.local/bin and whatever `security` and `swift` keep per user
#   $ARBOR_HOME       $sandbox/arbor: settings, state, log and socket of every Arbor started here, and of every arborctl
#   $src              a clone of this checkout at HEAD, where everything is built and the source is changed; the
#                     checkout itself gets nothing but the output in mac-shell/ and the pointer tool in .build/
#   $keychain         a keychain of its own, $sandbox/signing.keychain-db, with the password $password
#
# The copies of Arbor started with start_copy arrange nobody's windows (ARBOR_ONLY_PIDS=1), ask for no permission and
# register no shortcuts, so an Arbor that is already running is neither quit nor disturbed. They are started from this
# shell and not with `open`, which would make the copy known to Launch Services under the real bundle id, and without
# the watchdog, which starts a copy that ends badly again through `open` (a script asks for it with ARBOR_NO_WATCHDOG=0).
# Seven builds, one of them for two architectures: more than lib.sh gives a script.
ARBOR_TIME_LIMIT=${ARBOR_TIME_LIMIT:-2400}
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

tool=Contents/Helpers/arborctl
bundle_id=com.evbarleyg.arbor
identity="Arbor Local Signing"
# Ends the script when there is none; on the run's record, so that the supervisor removes it if this script is killed.
scratch_dir f13 sandbox real
# Everything below deletes, and stops processes, by this name. Were it empty or some other folder (a full disk: no
# folder is made, and bash 3.2 takes `cd ""` for "stay here"), that would be the checkout, or every process of the account.
f13_sandbox_is_ours() { case "$sandbox" in /tmp/arbor-f13.?????? | /private/tmp/arbor-f13.??????) [ -d "$sandbox" ] ;; *) return 1 ;; esac; }
f13_sandbox_is_ours || die "no folder of this run's own in /tmp (got '$sandbox'); nothing was touched"
real_home=$HOME
home="$sandbox/home"
export HOME=$home # safe anywhere: nothing here is started with `open`, which is what would get the real one
mkdir -p "$home/Library/Keychains" "$home/Library/Preferences" "$home/.local/bin"
export PATH="$home/.local/bin:$PATH"
# lib.sh points these at a session folder of its own.
unset ARBOR_SOCKET # safe anywhere: with the next line it is $sandbox/arbor/arbor.sock
export ARBOR_HOME="$sandbox/arbor"
# What the build scripts would take from the caller's environment.
unset PREFIX BINDIR LAUNCH ARBOR_SIGN_IDENTITY ARBOR_NOTARY_PROFILE ARBOR_VERSION ARBOR_RELEASE ARBOR_CONFIGURATION GITHUB_TOKEN
mkdir -p "$ARBOR_HOME"
src="$sandbox/src"
app="$src/build/Arbor.app"
installed="$home/Applications/Arbor.app"
keychain="$sandbox/signing.keychain-db"
password="f13-$RANDOM$RANDOM"
copy=""
copy_pid=""
feed_pid=""

# `limit <seconds> <program…>` is lib.sh's. A dialog nobody can answer must cost seconds, not the rest of the half hour; and when the
# time is up, or this script is interrupted, the program goes with everything it started: a `make` that is stopped alone
# leaves its compilers running, and a codesign that waits for an answer leaves its dialog on the screen.
within() {  # within <seconds> <command…>
  local deadline=$((SECONDS + $1))
  shift
  until "$@"; do
    [ "$SECONDS" -lt "$deadline" ] || return 1
    sleep 0.2
  done
}
# A requirement that is worked out and not stored in the signature, as for an ad-hoc one, is printed as a comment.
requirement() { codesign --display --requirements - "$1" 2>/dev/null | sed -n 's/^\(# \)\{0,1\}designated => //p'; }
cdhash() { codesign --display --verbose=3 "$1" 2>&1 | sed -n 's/^CDHash=//p'; }
signature() { codesign --display --verbose=3 "$1" 2>&1 | grep -E '^(Identifier|CodeDirectory|Signature|Authority|TeamIdentifier|CDHash)' | sed 's/^/    /'; }
stamp() { plutil -extract "$1" raw "$2/Contents/Info.plist"; }
status_starts() { case "$(arborctl status 2>&1)" in "$1"*) return 0 ;; *) return 1 ;; esac; }
says() { grep -qF -- "$2" "$1"; }
same() { [ -n "$1" ] && [ "$1" = "$2" ]; }
differ() { [ -n "$1" ] && [ -n "$2" ] && [ "$1" != "$2" ]; }
unchanged() { [ "$1" = "$2" ]; }
without() { case "$1" in *"$2"*) return 1 ;; *) return 0 ;; esac; }
with() { case "$1" in *"$2"*) return 0 ;; *) return 1 ;; esac; }
gone() { ! pgrep -f "$1" > /dev/null; }
# In the clone.
change_the_source() { echo 'print("F13: a different build")' >> "$src/Sources/Arbor/main.swift"; }
restore_the_source() { git -C "$src" checkout --quiet -- Sources/Arbor/main.swift; }
# What the account's own keychain settings read, whatever HOME says here.
real_keychain_settings() {
  HOME=$real_home security list-keychains -d user
  # safe anywhere: without -s it only prints
  HOME=$real_home security default-keychain -d user 2>&1
}

# A keychain file of this run's own, unlocked and without a time limit. Nothing puts it on a search list or makes it
# the default: see f13_make_keychain for what guards the account's own settings.
new_keychain() {
  # safe anywhere: a new file in this run's folder in /tmp, under the throwaway HOME
  security create-keychain -p "$password" "$1" || return 1
  # safe anywhere: that file's own settings
  security set-keychain-settings "$1"
  # safe anywhere: that file
  security unlock-keychain -p "$password" "$1"
}
# safe anywhere: only a file that new_keychain made
drop_keychain() { security delete-keychain "$1"; }
# Lets codesign use every signing key in a keychain of this run's own, whatever its label.
allow_every_key() {
  # safe anywhere: only a file that new_keychain made
  security set-key-partition-list -S apple-tool:,apple: -s -k "$password" "$1"
}

# Into the throwaway HOME. arborctl, with this ARBOR_HOME, cannot reach an Arbor that was running before, so none is quit.
install_here() {
  # safe anywhere: ~/Applications and ~/.local/bin are the throwaway HOME's, in /tmp, and nothing is started
  ARBOR_UNATTENDED=1 limit 600 make install LAUNCH=0
}
uninstall_here() {
  # ARBOR_LEAVE_WINDOWS: uninstalling looks at the whole Mac's windows, and this is about a copy in a sandbox that has moved none.
  # safe anywhere: the same, and ARBOR_KEEP_LOGIN_ITEM leaves the login items alone
  ARBOR_UNATTENDED=1 ARBOR_KEEP_LOGIN_ITEM=1 ARBOR_LEAVE_WINDOWS=1 limit 120 make uninstall
}

# start_copy <Arbor.app> [NAME=value…]: starts that copy apart from everything (see the header) and waits for its answer.
start_copy() {
  copy=$1
  shift
  env ARBOR_ONLY_PIDS=1 ARBOR_NO_PROMPT=1 ARBOR_NO_HOTKEYS=1 ARBOR_NO_STATUS_ITEM=1 ARBOR_NO_WATCHDOG=1 ARBOR_DEBUG=1 "$@" \
    "$copy/Contents/MacOS/Arbor" >> "$ARBOR_OUT/arbor-stderr.log" 2>&1 &
  copy_pid=$!
  within 10 ask status > /dev/null 2>&1
}
# The arborctl of the copy that was started last.
ask() { "$copy/$tool" "$@"; }
stop_copy() {
  [ -n "$copy_pid" ] || return 0
  ask quit > /dev/null 2>&1
  copy_has_gone
}
# For a copy that something else asked to quit. Never waits for ever; a copy that stays is stopped, its watchdog
# first, which would take that for an accident and start it again.
copy_has_gone() {
  local gone=0
  [ -n "$copy_pid" ] || return 0
  if ! arbor_await_exit "$copy_pid" 50; then
    gone=1
    pkill -f "^${copy:?}/Contents/MacOS/Arbor --watchdog" 2>/dev/null  # safe anywhere: only the copy in this run's folder in /tmp
    kill -9 "$copy_pid" 2>/dev/null
    arbor_await_exit "$copy_pid" 20
  fi
  wait "$copy_pid" 2>/dev/null # safe anywhere: it has ended by itself, or was killed above
  copy_pid=""
  return "$gone"
}
# A picture of the window Arbor shows after an update check (a floating window: level 3), and of nothing else.
window_shot() {
  local id
  sleep "${ARBOR_SETTLE:-0.7}"
  # Asked without permission, screencapture makes macOS put the question to whoever sits there.
  if [ "$(pointer screen-access)" != true ]; then
    echo "no picture $1: this shell may not record the screen, and nobody is asked for it"
    return 0
  fi
  id=$(pointer windows --pid "$copy_pid" | awk '$3 == 3 && $8 == "on" { print $1; exit }')
  # safe anywhere: -l takes one window, Arbor's own, and nothing of the screen around it
  if [ -n "$id" ] && screencapture -x -o -l "$id" "$ARBOR_OUT/$1.png" 2>> "$ARBOR_OUT/pictures.log" && [ -s "$ARBOR_OUT/$1.png" ]; then
    echo "shot: mac-shell/$1.png (window $id)"
  else
    echo "no picture $1: window '$id', $(tail -n 1 "$ARBOR_OUT/pictures.log" 2>/dev/null)"
  fi
}

# More to clean up: a script names a function of its own here.
f13_also_clean=""
f13_cleanup() {
  f13_sandbox_is_ours || return 0
  [ -z "$feed_pid" ] || kill "$feed_pid" 2>/dev/null
  stop_copy
  [ -z "$f13_also_clean" ] || "$f13_also_clean"
  # safe anywhere: only what was started from this run's folder in /tmp, by either of the folder's two names
  pkill -f "^(/private)?/tmp/${sandbox##*/}/" 2>/dev/null
  hdiutil detach -quiet "$sandbox/mount" 2>/dev/null
  [ ! -f "$keychain" ] || drop_keychain "$keychain" 2>/dev/null
  cp "$sandbox/arbor/arbor.log" "$ARBOR_OUT/arbor.log" 2>/dev/null
  cd "$ARBOR_ROOT" || true
  rm -rf "$sandbox"
}
trap 'code=$?; f13_cleanup; (exit $code); arbor_exit' EXIT

f13_describe_the_mac() {
  step "the Mac"
  echo "macOS $(sw_vers -productVersion) ($(sw_vers -buildVersion)) on $(uname -m); bash $BASH_VERSION; $(make --version | head -n 1)"
  swift --version 2>&1 | head -n 1
  echo "/usr/bin/openssl: $(/usr/bin/openssl version)"
  # safe anywhere: a word in a message, and a question about the version
  echo "$(csrutil status 2>&1); curl $(curl --version | head -n 1 | cut -d ' ' -f 2); $(python3 --version 2>&1)"
  if on_throwaway_mac; then echo "one of GitHub's throwaway Macs"; else echo "somebody's Mac"; fi
  echo "the place apart: $sandbox"
}

# Everything is built in a clone, so that the checkout is left as it is, local changes included.
f13_clone() {
  step "a clone to build in"
  checkout_before=$(git -C "$ARBOR_ROOT" status --porcelain)
  [ -z "$checkout_before" ] || echo "note: uncommitted changes in $ARBOR_ROOT are not part of this; HEAD is what is tried"
  git clone --quiet --no-hardlinks "$ARBOR_ROOT" "$src" || die "could not clone $ARBOR_ROOT"
  cd "$src" || die "no $src"
  echo "HEAD $(git rev-parse --short HEAD), $(git rev-list --count HEAD) commits (a shallow checkout has 1); version.sh: $(./scripts/version.sh)"
  expected="$(cat VERSION) (build $(git rev-list --count HEAD), $(git rev-parse --short HEAD))"
}

# A keychain of this run's own. It is made under the throwaway HOME, and stops the script if `security` does not follow
# HOME: making and deleting a keychain may add it to, and take it off, the search list, which must then be the throwaway one.
f13_make_keychain() {
  step "a keychain of its own"
  real_settings=$(real_keychain_settings)
  echo "under the throwaway HOME the search list reads: $(security list-keychains -d user | tr -d '\n')"
  if with "$(security list-keychains -d user)" "$real_home/"; then
    die "security does not follow HOME on this Mac, so this script might touch the account's keychain search list; stopping"
  fi
  new_keychain "$keychain" || die "could not make a keychain"
  echo "after making $keychain: $(security list-keychains -d user | tr -d '\n')"
  if ! check "the account's own search list and default keychain are as they were" unchanged "$real_settings" "$(real_keychain_settings)"; then
    echo "they were:"
    echo "$real_settings"
    die "the account's keychain settings changed"
  fi
}

# make_app <log> [NAME=value…]: `make app` in the clone; a build that fails ends the script with the compiler's errors.
make_app() {
  local log=$1
  shift
  if ! limit 900 env "$@" make app > "$log" 2>&1; then
    grep "error:" "$log" | sort -u | head -n 40
    tail -n 30 "$log"
    die "make app failed: $(grep -c "error:" "$log") error lines, see $(basename "$log")"
  fi
  grep "warning:" "$log" | sort -u | head -n 20
  tail -n 3 "$log"
}
