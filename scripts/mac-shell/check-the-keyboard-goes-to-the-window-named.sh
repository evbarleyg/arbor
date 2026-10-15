#!/bin/bash
# Arbor is asked for a window by name: has that window the keyboard afterwards? (collab/BOARD.md, 1.89.)
#
#   scripts/mac-shell/run.sh scripts/mac-shell/check-the-keyboard-goes-to-the-window-named.sh          under six minutes
#
# Found in a model of a Mac, and nowhere else so far: app A is in front, with the keyboard in A's DOCKED window; A and B have a FLOATING window each; `arborctl zoom <A's floating window>`. The window comes into
# view, and the keyboard ends in B's floating window. By reading: the view changes first; the docked window, which has the keyboard, goes out of view; Arbor hands the keyboard to a window that is in view, which is
# B's, and brings B forward; the request for the window that was named follows in the same breath, and spares itself the bringing forward because macOS still calls A the app in front. B's coming forward lands last.
#
# So, ten times each:
#   1  two test apps: A with a docked and a floating window, B with a floating one. A click gives A's docked window the keyboard; `arborctl zoom` names A's floating one
#   2  real apps: A is TextEdit with two documents, B is Script Editor with one
# and after each of them THE CONTROL: the same with B's window minimized, so that there is nobody else to hand the keyboard to.
#
# What the command does to frames is not asked here (it may show the Desktop, or let the window fill the view): only that the window named is in view, and who has the keyboard.
# After the command: who has the keyboard (`pointer keyboard`: the app in front and its window that keys go to) at once, 0.2 s and 1 s later; the app in front; which window Arbor calls focused; then a plain x is typed: in which
# window did it land (the test windows count their keys; of the documents typed.swift reads the length). Every round is recorded as a trace of its own, traces/<part>-<round>.jsonl (docs/TRACES.md).
#
# rounds.jsonl has one JSON object for each round. "verdict": right (the window named has the keyboard at all three looks, and got the x); flipped (another app's window had it at one look, and at 1 s the window named has
# it and gets the x); late (A's docked window still had it at an earlier look, nobody else); wrong (anything else). It EXPECTS right: a check for each round, so that the script is red where the fault shows.
#
# Not here: the same by the menu's list of windows, which is not on the trunk.
#
# HOW TO READ RUN 38746844791 (mac-shell-out/check.named, this script one commit earlier, macOS 26.6.2): its "113 passed, 27 failed" is the script's own fault, not Arbor's.
# The 27 are nine rounds times three checks: real-apps-with-b-2 to real-apps-with-b-10. From the second round on the other app's window, back from the Dock at 0,32 700×677, covered the docked window (12,43 659×655)
# wholly, so the click that is to give the docked window the keyboard found "no part of window 56 is in reach". Those rounds began with the keyboard already in the window named: they are void. (`back` is mended since.)
# What counts, from rounds.jsonl: 31 rounds, 31 right, 0 wrong. Test apps with another app's floating window there 10 of 10, control 10 of 10; real apps 1 of 1 (9 void), control 10 of 10.
# What it does not show: since `zoom` of a floating window fills the view, the view does not change and nobody is sent away, so the road on which the fault was found is not entered on that build. From the command to the
# last look every trace holds one setFrame and one focus, both of the window named, and no app comes forward; the traces with the other app's window and without it have the same shape. The command is right; the race
# underneath is neither shown nor refuted.
#
# Only on GitHub's Macs: it types plain letters, which land in whatever has the keyboard, and opens and quits real apps.
source "$(dirname "${BASH_SOURCE[0]}")/lib-apps.sh"
needs_throwaway_mac "type plain letters, which land in whichever app has the keyboard, and open and quit real apps"

TYPED="$ARBOR_ROOT/.build/mac-shell/typed"
ROUNDS="$ARBOR_OUT/rounds.jsonl"
TRACES="$ARBOR_OUT/traces"
TIMES=${CHECK_TIMES:-10}
: > "$ROUNDS"
mkdir -p "$TRACES"

if [ -n "${ARBOR_REHEARSAL:-}" ]; then
  echo "REHEARSAL: no swiftc and no real apps here: part 1 only, and no traces"
  arbor_build
else
  mkdir -p "$(dirname "$TYPED")"
  swiftc -O -swift-version 5 "$ARBOR_ROOT/scripts/mac-shell/typed.swift" -o "$TYPED" > "$ARBOR_OUT/build-typed.log" 2>&1 &
  TYPED_COMPILER=$!
  apps_build
  if ! wait "$TYPED_COMPILER"; then
    grep -A 6 "error:" "$ARBOR_OUT/build-typed.log" | head -n 40
    die "scripts/mac-shell/typed.swift did not compile"
  fi
  apps_watchdog 480
fi

# MARK: A round. The part sets A B DOCKED NAMED OTHER, and the functions keys_in, away and back.

keyboard_now() { pointer keyboard | tr '\n' ' ' | sed 's/ *$//'; }
has_the_keyboard() { [ "$(keyboard_now)" = "$1 $2" ]; }
focused_by_arbor() { state | python3 -c 'import json, sys; print(json.load(sys.stdin).get("focused"))'; }
record() {
  [ -z "${ARBOR_REHEARSAL:-}" ] || return 0
  "$ARBOR_BIN/arborctl" trace on "$1" > /dev/null
}
recorded() {
  [ -z "${ARBOR_REHEARSAL:-}" ] || return 0
  "$ARBOR_BIN/arborctl" trace off > /dev/null
  cp "$ARBOR_HOME"/traces/*-"$1".jsonl "$TRACES/$1.jsonl" || echo "no trace $1"
}

# round <part> <with-b|control> <which time>
round() {
  local part=$1 kind=$2 time=$3 name="$1-$2-$3" began once soon later front focused docked named other landed verdict look view=no
  step "$name"
  ctl show-all
  sleep 0.6
  click_window "$DOCKED"
  eventually has_the_keyboard "$A" "$DOCKED" > /dev/null
  began=$(keyboard_now)
  docked=$(keys_in "$A" "$DOCKED") named=$(keys_in "$A" "$NAMED") other=$(keys_in "$B" "$OTHER")
  record "$name"
  ctl zoom "$NAMED"
  once=$(keyboard_now)
  sleep 0.2
  soon=$(keyboard_now)
  sleep 0.8
  later=$(keyboard_now)
  front=$(pointer front)
  focused=$(focused_by_arbor)
  ! is on_screen "$NAMED" > /dev/null 2>&1 || view=yes
  key x
  sleep 0.5
  landed=nowhere
  [ "$(keys_in "$A" "$DOCKED")" = "$docked" ] || landed=docked
  [ "$(keys_in "$B" "$OTHER")" = "$other" ] || landed=other
  [ "$(keys_in "$A" "$NAMED")" = "$named" ] || landed=named
  recorded "$name"
  verdict=right
  for look in "$once" "$soon"; do
    case "$look" in
      "$A $NAMED") ;;
      "$A $DOCKED") [ "$verdict" = flipped ] || verdict=late ;;
      *) verdict=flipped ;;
    esac
  done
  [ "$later" = "$A $NAMED" ] && [ "$landed" = named ] || verdict=wrong
  [ "$began" = "$A $DOCKED" ] || verdict=void
  printf '{"kind":"round","part":"%s","with":"%s","time":%s,"a":%s,"b":%s,"docked":%s,"named":%s,"other":%s,"began":"%s","once":"%s","at200":"%s","at1000":"%s","front":"%s","arbor":"%s","inView":"%s","landed":"%s","verdict":"%s"}\n' \
    "$part" "$kind" "$time" "$A" "$B" "$DOCKED" "$NAMED" "$OTHER" "$began" "$once" "$soon" "$later" "$front" "$focused" "$view" "$landed" "$verdict" | tee -a "$ROUNDS"
  check "$name: the docked window had the keyboard to begin with" test "$began" = "$A $DOCKED"
  check "$name: the window named is in view" test "$view" = yes
  check "$name: the window named has the keyboard, at once and for good, and gets the x" test "$verdict" = right
}

# rounds <part>
rounds() {
  local time
  echo "A is process $A: docked $DOCKED, floating and named $NAMED. B is process $B: floating $OTHER"
  summary
  for time in $(seq 1 "$TIMES"); do
    round "$1" with-b "$time"
    away
    sleep 0.8
    round "$1" control "$time"
    back
    sleep 0.8
  done
}

tally() {
  python3 - "$ROUNDS" << 'PYTHON'
import collections, json, sys
count = collections.OrderedDict()
for line in open(sys.argv[1], encoding="utf-8"):
    o = json.loads(line)
    count.setdefault((o["part"], o["with"]), collections.Counter())[o["verdict"]] += 1
for (part, kind), verdicts in count.items():
    total = sum(verdicts.values())
    print("%-10s %-8s %d of %d right, %d wrong, %d flipped and came back, %d late, %d void (the docked window had not the keyboard to begin with)" % (
        part, kind, verdicts["right"], total, verdicts["wrong"], verdicts["flipped"], verdicts["late"], verdicts["void"]))
PYTHON
}

# MARK: 1. Two test apps

step "1  two test apps"
ARBOR_TEST_WINDOWS_ARGS="--regular" ARBOR_SECOND_APP=1 ARBOR_SECOND_APP_ARGS="--regular"
arbor_start 2
ctl arrange
ctl float "$W2"
ctl float "$V1"
sleep 3 # regular apps joining the Dock resize it, and with it every slot
A=$ARBOR_WINDOWS_PID B=$ARBOR_WINDOWS_PID_2 DOCKED=$W1 NAMED=$W2 OTHER=$V1
keys_in() { events_of "$2" key; }
away() { tw2 minimize "$OTHER" > /dev/null; }
back() { tw2 restore "$OTHER" > /dev/null; }
check "A's first window is docked" is docked "$DOCKED"
check "A's second floats" is floating "$NAMED"
check "B's floats" is floating "$OTHER"
shot 1-the-stage
rounds test-apps
arbor_stop
tally

if [ -n "${ARBOR_REHEARSAL:-}" ]; then
  echo "REHEARSAL: part 2 needs real apps"
  exit 0
fi

# MARK: 2. Real apps

step "2  TextEdit with two documents, Script Editor with one"
apps_scratch
if app_open com.apple.TextEdit "$APPS_SCRATCH/oak.txt" "$APPS_SCRATCH/elm.txt" && [ "$(echo "$APP_WINDOWS" | wc -w)" -lt 2 ]; then
  # The second document's window may come a moment after the first.
  sleep 2
  APP_WINDOWS=$(app_windows "$APP_PID")
fi
A=$APP_PID
read -r DOCKED NAMED _ <<< "$APP_WINDOWS"
app_open com.apple.ScriptEditor2 "$APPS_SCRATCH/hello.applescript"
B=$APP_PID OTHER=$APP_WINDOW
if [ -z "${NAMED:-}" ] || [ -z "$OTHER" ]; then
  echo "TextEdit lists '$DOCKED ${NAMED:-}', Script Editor '$OTHER': not the three windows this needs"
  check "the real apps opened their three windows" false
else
  app_dismiss "$A"
  app_dismiss "$B"
  arbor_start_apps "$A" "$B"
  ctl arrange
  ctl float "$NAMED"
  ctl float "$OTHER"
  sleep 2
  keys_in() { "$TYPED" "$1" "$2"; }
  away() { apptool minimize "$OTHER"; }
  # Back from the Dock the window lies on top, and Script Editor's covers the docked one wholly: nothing of that is left to click (run 38746844791, above). So the docked one is raised again; the click follows as before.
  back() { apptool unminimize "$OTHER"; sleep 0.8; apptool raise "$DOCKED"; }
  check "TextEdit's first document is docked" is docked "$DOCKED"
  check "its second floats" is floating "$NAMED"
  check "Script Editor's floats" is floating "$OTHER"
  shot 2-the-stage
  rounds real-apps
  arbor_stop
fi
app_quit "$A"
app_quit "$B"

step "the tally"
tally
