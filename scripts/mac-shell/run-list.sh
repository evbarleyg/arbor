#!/bin/bash
# Runs the Mac shell scripts that are cleared for a person's own Mac, one after the other, with one command and hands off:
#
#   scripts/mac-shell/run-list.sh                  the first two: do the helper tools compile, does the harness itself work here?
#   scripts/mac-shell/run-list.sh --all            those, and if they come back clean everything else on the list below
#   scripts/mac-shell/run-list.sh <script>…        those two, then these (names as in the list, e.g. shots-demo.sh)
#   … --pictures                                   with pictures of what is in front of the curtain (ARBOR_SHOTS=1; see lib.sh)
#   … --busy-ok                                    start although an app keeps the display awake, as a call or a film does, or somebody seems
#                                                  to be using the Mac (ARBOR_BUSY_OK=1): for the Mac's owner to say, nobody else
#   … --plan                                       print what would run, and run nothing
#
# Nothing is on the list below that was not read line by line, as a person's
# Mac would run it (docs/TESTING.md, "On a person's own Mac", says for each script what it does there and how long it holds the pointer).
#
# Started from a terminal, it builds first (some eight minutes in a new folder; use the Mac as you like meanwhile), then asks for Return: hands
# off from that moment. Started by anything else: the Mac must have been left alone for five minutes. Leave it alone while it runs: a dark curtain hangs over every display, test windows open in front of
# it, the pointer moves and keys are pressed. ⌃C here, or a right-click on the curtain, ends the script that is running in good
# order, and the list with it.
#
# It stops at the first sign of trouble: a script that declines (77: the Mac is not free), is cut off or interrupted, ends in a way nobody
# planned, or after which this Mac differs from before. Checks that fail (exit code 1) are findings about Arbor, and the list goes on.
#
# What comes of it is in .mac-shell/list-<date>/, which git ignores: summary.txt, and for each script a folder with output.txt and what
# the script left in mac-shell/. Nothing is sent anywhere. Read it before you share any of it, and never share a
# stays-on-this-mac.txt.
cd "$(dirname "$0")/../.." || exit 2

FIRST="compile-tools.sh check-harness.sh"
# In the order of the backlog: what most depends on first. check-F13.sh takes up to 25 minutes; watchdog-bundle.sh leaves an entry with
# LaunchServices for a while, so it is run once and last.
REST="shots-demo.sh shots-review-controller.sh check-F51.sh check-F44.sh check-review-ux.sh
  proof.sh check-F41.sh e2e-drag.sh check-F56.sh check-F49.sh check-F53.sh check-F09.sh check-F18.sh check-F20.sh check-F54.sh shots-F45.sh
  shots-F48.sh shots-F02.sh perf.sh check-F12.sh shots-focus-ring.sh events.sh trace-demo.sh check-F58.sh shots-finder.sh
  probe-keyboard.sh shots-minimap.sh shots-F43.sh shots-F15.sh
  check-F13.sh watchdog-bundle.sh"

folder=scripts/mac-shell
left=mac-shell
results=.mac-shell/list-$(date +%Y-%m-%d-%H%M%S)
# For scripts/test-tooling.py, which brings scripts of its own.
if [ -n "${ARBOR_REHEARSAL:-}" ]; then
  folder=${ARBOR_LIST_FOLDER:-$folder}
  left=${ARBOR_OUT:-$left}
  results=${ARBOR_LIST_RESULTS:-$results}
  FIRST=${ARBOR_LIST_FIRST-$FIRST}
  REST=${ARBOR_LIST_REST-$REST}
fi

chosen="" pictures="" plan="" busy=""
for word in "$@"; do
  case "$word" in
    --all) chosen=$REST ;;
    --pictures) pictures=1 ;;
    --plan) plan=1 ;;
    --busy-ok) busy=1 ;;
    -*) echo "run-list.sh: no option $word (--all, --pictures, --busy-ok, --plan)" >&2; exit 64 ;;
    *)
      name=$(basename "$word")
      case " $(echo $REST) " in
        *" $name "*) chosen="$chosen $name" ;;
        *) echo "run-list.sh: $name is not on the list of what may run on a person's Mac" >&2; exit 64 ;;
      esac ;;
  esac
done

if [ -n "$plan" ]; then
  for name in $FIRST $chosen; do echo "$name"; done
  exit 0
fi
mkdir -p "$results" "$left" || exit 2
summary=$results/summary.txt
say() { echo "$*" | tee -a "$summary"; }
say "run-list at $(git rev-parse --short HEAD 2>/dev/null), macOS $(sw_vers -productVersion 2>/dev/null), $(date -u +%Y-%m-%dT%H:%MZ)${pictures:+, with pictures}"

# show <file>: print what has been added to it since the last time.
show() {
  local size
  size=$(wc -c < "$1" | tr -d ' ')
  [ "${size:-0}" -gt "$shown" ] || return 0
  tail -c "+$((shown + 1))" "$1" | head -c "$((size - shown))"
  shown=$size
}

stop=""
# Passed on as TERM: bash starts what runs in the background with ⌃C's signal ignored, for good. The script's supervisor takes it for an
# interruption, and cleans up before it ends.
script=""
trap 'stop="interrupted"; [ -n "$script" ] && kill -TERM "$script" 2>/dev/null' INT TERM HUP
number=0
# Whoever starts this from a terminal has touched the keyboard this very second, and knows what is coming: five quiet minutes could never
# be had that way. For them quiet counts from now; a hand on the Mac after this moment still makes the next script decline.
quiet_since=""
person=""
if [ -t 0 ] || { [ -n "${ARBOR_REHEARSAL:-}" ] && [ -n "${ARBOR_LIST_AT_A_TERMINAL:-}" ]; }; then
  person=yes
  # Nobody sits still through a build. What takes minutes is done before the hands have to come off.
  echo "First the builds, which take minutes in a new folder. Use the Mac as you like meanwhile."
  if [ -z "${ARBOR_REHEARSAL:-}" ] && ! swift build > "$results/build.log" 2>&1; then
    grep "error:" "$results/build.log" | sort -u | head -n 20
    say "STOPPED before anything ran: swift build failed (build.log)"
    exit 1
  fi
fi
for name in $FIRST $chosen; do
  if [ -n "$person" ] && [ "$name" != compile-tools.sh ]; then
    person=""
    printf '\nEverything is built. Press Return (or ⌃C to leave it at that), then hands off the keyboard and the pointer until this says that it has ended. '
    # A second at a time: bash runs a trap only when `read` has returned, so a plain one would be deaf to ⌃C, and Return would then start the script.
    if [ -t 0 ]; then until read -r -t 1 _ || [ -n "$stop" ]; do :; done; fi
    [ -z "$stop" ] || break
    quiet_since=$(date +%s)
  fi
  number=$((number + 1))
  kept=$results/$(printf '%02d' "$number")-${name%.sh}
  mkdir -p "$kept" || exit 2
  echo
  echo "=== $number: $name"
  began=$SECONDS
  # Nothing from the caller's environment that opens a gate or steers a build. ARBOR_QUIET_SINCE: the input since then was the last script's.
  env -u GITHUB_ACTIONS -u ARBOR_SHOTS -u ARBOR_SHOTS_WHOLE_SCREEN_I_HAVE_CLOSED_EVERYTHING -u ARBOR_BUSY_OK -u ARBOR_APPS_HERE \
    -u ARBOR_INPUT_TAPS_HERE -u ARBOR_UNATTENDED -u PREFIX -u BINDIR -u LAUNCH -u ARBOR_SIGN_IDENTITY -u ARBOR_NOTARY_PROFILE -u ARBOR_VERSION \
    -u ARBOR_CONFIGURATION -u GITHUB_TOKEN ${pictures:+ARBOR_SHOTS=1} ${busy:+ARBOR_BUSY_OK=1} ${quiet_since:+ARBOR_QUIET_SINCE=$quiet_since} \
    bash "$folder/$name" > "$kept/output.txt" 2>&1 &
  script=$!
  # Shown as it comes, without a pipe between this script and that one's exit code, and with a signal heard within half a second.
  shown=0
  while kill -0 "$script" 2>/dev/null; do
    show "$kept/output.txt"
    sleep 0.5
  done
  wait "$script"
  code=$?
  script=""
  show "$kept/output.txt"
  quiet_since=$(date +%s)
  # What the script left, beside what it said. The next one empties mac-shell/.
  find "${left:?}" -mindepth 1 -maxdepth 1 ! -name output.txt ! -name exit-code.txt -exec mv {} "$kept/" \;
  counts=$(grep -E "^[0-9]+ passed, [0-9]+ failed" "$kept/output.txt" | tail -n 1)
  say "$(printf '%2d %-30s exit %-3s %4d s  %s' "$number" "$name" "$code" "$((SECONDS - began))" "$counts")"
  grep -E "^skipped: " "$kept/output.txt" | sort | uniq -c | sort -rn | head -n 5 | sed 's/^/     /' >> "$summary"
  # compile-tools.sh ends with the number of tools that did not compile. That is a finding about those tools and the scripts that use them;
  # only without the pointer or the curtain is there no going on.
  if [ "$name" = compile-tools.sh ] && [ "$code" != 0 ] && grep -q "^✘ " "$kept/output.txt" && ! grep -qE "^✘ (pointer|curtain)$" "$kept/output.txt"; then
    code=0
  fi
  case "$code" in
    0 | 1) ;;
    77) stop=${stop:-"$name declined: $(grep -E "^skipped: " "$kept/output.txt" | tail -n 1)"} ;;
    *) stop=${stop:-"$name ended with exit code $code"} ;;
  esac
  if grep -q "this Mac differs from before the run" "$kept/output.txt"; then stop=${stop:-"this Mac differs from before $name ran: see the end of $kept/output.txt"}; fi
  # Everything after the first two leans on the tools, the curtain and the nets.
  case " $FIRST " in *" $name "*) [ "$code" = 0 ] || stop=${stop:-"$name did not come back clean, and everything else leans on it"} ;; esac
  [ -z "$stop" ] || break
done

echo
if [ -n "$stop" ]; then
  say "STOPPED after $number of $(echo $FIRST $chosen | wc -w | tr -d ' '): $stop"
else
  say "all $number ran"
fi
echo "results: $results (summary.txt first). Nothing was sent anywhere."
[ -z "$stop" ]
