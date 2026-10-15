#!/bin/bash
# The newcomer's eval, the Mac's part: an ordinary desk of real apps on a hosted Mac, then the loop in which somebody who knows nothing sees pictures of it
# and acts on it with a real pointer and real keys, one act at a time, through Git.
#
#   scripts/newcomer/start.sh <run> arbor <commit> | scripts/newcomer/start.sh <run> macos        from anywhere; scripts/newcomer/README.md says all of it
#
# The workflow "Newcomer" (.github/workflows/newcomer.yml) runs this, not run.sh: it takes up to two hours, and beside it runs the courier
# (scripts/newcomer/courier.sh), which pushes a picture every round. What it finds in the environment:
#   NEWCOMER_RUN      the run's name          NEWCOMER_ARM    arbor | macos: with Arbor to install, or with what macOS itself offers
#   NEWCOMER_BOX      the folder it shares with the courier
#   NEWCOMER_ZIP      with Arbor: the build, zipped, as a download would be; NEWCOMER_README: that build's README; NEWCOMER_BUILD: its commit
#   NEWCOMER_MARK     yes: the zip is marked as a browser marks a download, so that macOS's Gatekeeper refuses it as it would a stranger's
#   NEWCOMER_UNTIL    seconds since 1970: when all of it has to be over
#
# macOS is as it comes: its own tiling and "click wallpaper to reveal desktop" on. Motion and transparency are as on a person's Mac, not as the runners come.
# What comes back in mac-shell/: journal.jsonl (what score.py reads), samples.log (every frame of every window, sixty times a second),
# screens/ (every picture, small), and Arbor's own log.
#
# Only on GitHub's Macs: it does whatever it is told from afar.
ARBOR_TIME_LIMIT=${ARBOR_TIME_LIMIT:-7000}
source "$(dirname "${BASH_SOURCE[0]}")/lib-walk.sh"
needs_throwaway_mac "hand the pointer and the keyboard to whoever can push to the repository, publish pictures of the screen, and put a download into the account's own Downloads"
[ -z "${ARBOR_REHEARSAL:-}" ] || { echo "the loop is rehearsed by scripts/newcomer/rehearse.py, with a Mac of its own: here there are no real apps to set a desk with"; exit 77; }

run=${NEWCOMER_RUN:?} arm=${NEWCOMER_ARM:?} box=${NEWCOMER_BOX:?}
[ -d "$box" ] || die "no folder $box"
helped="the account's password is typed for it, since nobody knows a hosted Mac's"

step "the Mac"
echo "macOS $(sw_vers -productVersion) ($(sw_vers -buildVersion)) on $(uname -m)"
day_build_tools
# The runner's own 1024×768 is smaller than any Mac's.
display_mode 1440x900 1600x900 1680x1050 1920x1080
macos_tiling
macos_click_wallpaper
macos_reduce_motion off
defaults write com.apple.universalaccess reduceTransparency -bool false
# ⌃ pressed twice starts Dictation, which asks first, in an alert in front of everything: two chords with ⌃ in a row are that to it.
macos_dictation_shortcut off
apps_scratch
sampler_start

step "the desk"
cast=""
for name in finder safari textedit notes calendar; do
  case "$name" in
    finder) set -- "$APPS_SCRATCH/grove" ;;
    safari) set -- "$APPS_SCRATCH/page.html" ;;
    textedit) set -- "$APPS_SCRATCH/oak.txt" ;;
    *) set -- ;;
  esac
  if APP_WAIT=25 APP_OPEN_LIMIT=90 meet "$name" "$(bundle_of "$name")" "$@"; then
    app_dismiss "$APP_PID" || echo "a sheet or dialog stayed in the way"
    cast="$cast,$name=$(window_of "$name")"
  else
    die "$name opened no window: every task names one of these"
  fi
done
sleep 3
# An app may have swapped the window it opened with for another meanwhile.
cast=""
for name in finder safari textedit notes calendar; do
  listed=$(app_windows "$(pid_of "$name")")
  case " $listed " in *" $(window_of "$name") "*) ;; *) [ -z "$listed" ] || eval "W_$name=\${listed%% *}" ;; esac
  cast="$cast,$name=$(window_of "$name")"
done
echo "the cast: ${cast#,}"
pointer windows --on-screen | awk '$3 == 0'

if [ "$arm" = arbor ]; then
  step "the download"
  [ -f "${NEWCOMER_ZIP:-}" ] || die "no build to download: NEWCOMER_ZIP"
  cp "$NEWCOMER_ZIP" "$HOME/Downloads/Arbor.zip"
  if [ "${NEWCOMER_MARK:-no}" = yes ]; then
    xattr -w com.apple.quarantine "0083;$(printf '%x' "$(date +%s)");Safari;$(uuidgen)" "$HOME/Downloads/Arbor.zip"
  else
    helped="$helped; the download bears no mark of a browser's, so macOS does not refuse to open it as it would for a stranger"
  fi
  # Nobody has been asked, and nobody has answered.
  sudo sqlite3 "/Library/Application Support/com.apple.TCC/TCC.db" "DELETE FROM access WHERE client = 'com.evbarleyg.arbor';"
  ls -l "$HOME/Downloads"
fi
"$ARBOR_ROOT/scripts/newcomer/lay-kit.sh" "$box" "$run" "$arm" "${NEWCOMER_README:-}" || die "the kit could not be laid out"

step "the loop"
# Off every window, where it hides nothing.
move 720 450
python3 "$ARBOR_ROOT/scripts/newcomer/rig.py" --run "$run" --arm "$arm" --box "$box" --remote "https://github.com/${GITHUB_REPOSITORY:?}.git" \
  --out "$ARBOR_OUT" --cast "${cast#,}" --build "${NEWCOMER_BUILD:-}" --system "$(sw_vers -productVersion)" --helped "$helped" \
  --until "${NEWCOMER_UNTIL:-0}" --tools "$ARBOR_ROOT/.build/mac-shell" --samples "$DAY_SAMPLES" --sampler-in 6 --sampler-out 5
code=$?
echo "the loop ended with $code"

step "what is left"
sampler_stop
pointer windows --on-screen | awk '$3 == 0'
cp "$HOME/Library/Application Support/Arbor/arbor.log" "$ARBOR_OUT/arbor-newcomer.log" 2>/dev/null
pkill -f "Arbor.app/Contents/MacOS/Arbor"
python3 "$ARBOR_ROOT/scripts/newcomer/score.py" "$ARBOR_OUT" | tee "$ARBOR_OUT/score.md"
exit "$code"
