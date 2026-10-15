#!/bin/bash
# Arbor is asked for a window that is OUT OF VIEW, of the app in front, while another app's window was used after it: has the window named the keyboard afterwards? (collab/BOARD.md, 1.89.)
#
#   scripts/mac-shell/run.sh scripts/mac-shell/check-the-keyboard-goes-to-a-window-out-of-view.sh          about ten minutes of play
#
# check-the-keyboard-goes-to-the-window-named.sh asked with `zoom <floating window>`, which fills the view since and sends nobody away: the road on which the fault was found was not entered. A model of a Mac found
# roads that enter it on today's trunk. This is the plainest.
#
# THE STAGE of a round: app A has a docked window D and a floating window N; app B has a floating window O. They are used by clicks in the order N, O, D: so O was used after N, and D has the keyboard, with A in front.
# `arborctl zoom D`: the view is framed on D, and N and O are out of view. THE ACT: `arborctl focus N`.
# By reading: the view changes first; D, which has the keyboard, goes out of view; Arbor hands the keyboard to the window in view that was used last, which is O, and brings B forward; the request for N follows in the
# same breath and spares itself the bringing forward, because macOS still calls A the app in front. B's coming forward lands last.
#
# THE ARMS, one after the other within a round's number (the road ten rounds, the others five: every second time), with two test apps and with real apps (A is TextEdit with two documents, B is Script Editor with one):
#   road        as above
#   dock        control: O lies in the Dock, so that there is nobody else to hand the keyboard to
#   order       control: used in the order O, N, D: the window used last but one is the window named
#   everything  control: no `zoom D`: the act comes from the view of everything, and nobody goes out of view
#   menu        the road, and the act is a real click on N's row in Arbor's menu, Windows ▸
#
# THE FORECAST, by the model: road and menu end with B in front and the keyboard in O; dock, order and everything end with A in front and the keyboard in N.
# How it is to be read, fixed beforehand: wrong in any round of road AND right in all rounds of the controls = the fault is seen on a Mac. Right in all rounds = the Mac lets A's window stand.
# A rehearsal on Linux cannot show the fault: there a request for the keyboard lands at once, so all arms end with N.
#
# After the act: who has the keyboard (`pointer keyboard`: the app in front and its window that keys go to) at once, 0.2 s and 1 s later; the app in front; which window Arbor calls focused; whether N is in view; then a plain x
# is typed: in which window did it land (the test windows count their keys; of the documents typed.swift reads the length). From the act on every round is a trace of its own, traces/<part>-<arm>-<round>.jsonl (docs/TRACES.md).
#
# rounds.jsonl has one JSON object for each round. "verdict": right (N has the keyboard at all three looks, and got the x); flipped (another app's window had it at one look, and at 1 s N has it and gets the x); late (D
# still had it at an earlier look, nobody else); wrong (anything else); void (the stage did not come about: "why" says which part of it; the act is not played). It EXPECTS right: the script is red where the fault shows.
# A round that counts shows its stage as a check. A void round is one line and no check; an arm of which more than a fifth is void is red once, at the end.
#
# NOT VARIED: one Mac, one macOS, one display; Reduce Motion as the image has it; A in front at the act; D docked alone; the windows apart, so that each can be clicked; two pairs of apps, all AppKit's; the act by arborctl
# or by the menu, never by Go to… or a shortcut.
#
# Only on GitHub's Macs: it types plain letters, which land in whatever has the keyboard, clicks in the menu bar, and opens and quits real apps.
ARBOR_TIME_LIMIT=1800
source "$(dirname "${BASH_SOURCE[0]}")/lib-apps.sh"
needs_throwaway_mac "type plain letters, which land in whichever app has the keyboard, click in the menu bar, and open and quit real apps"

TYPED="$ARBOR_ROOT/.build/mac-shell/typed"
ROUNDS="$ARBOR_OUT/rounds.jsonl"
TRACES="$ARBOR_OUT/traces"
TIMES=${CHECK_TIMES:-10}
ARMS=${CHECK_ARMS:-road dock order everything menu}
: > "$ROUNDS"
mkdir -p "$TRACES"

if [ -n "${ARBOR_REHEARSAL:-}" ]; then
  echo "REHEARSAL: no swiftc and no real apps here: part 1 only, and no traces. A request for the keyboard lands at once here: every arm ends with the window named"
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
  apps_watchdog 1700
fi

# MARK: A round. The part sets A B DOCKED NAMED OTHER WORD (a word of N's title), and the functions keys_in, away and back.

keyboard_now() { pointer keyboard | tr '\n' ' ' | sed 's/ *$//'; }
has_the_keyboard() { [ "$(keyboard_now)" = "$1 $2" ]; }
focused_by_arbor() { state | python3 -c 'import json, sys; print(json.load(sys.stdin).get("focused"))'; }
title_of_the_window_named() {
  "$ARBOR_BIN/arborctl" state --titles | python3 -c 'import json, sys; print(next((w.get("title") or "" for w in json.load(sys.stdin)["state"]["windows"] if w["id"] == int(sys.argv[1])), ""))' "$NAMED"
}
row_of_the_window_named() { "$ARBOR_BIN/arborctl" menu | grep -F -e "$WORD" | head -n 1 | sed 's/^[ ✓]*//; s/  \[.*//'; }
record() {
  [ -z "${ARBOR_REHEARSAL:-}" ] || return 0
  "$ARBOR_BIN/arborctl" trace on "$1" > /dev/null
}
recorded() {
  [ -z "${ARBOR_REHEARSAL:-}" ] || return 0
  "$ARBOR_BIN/arborctl" trace off > /dev/null
  cp "$ARBOR_HOME"/traces/*-"$1".jsonl "$TRACES/$1.jsonl" || echo "no trace $1"
}

# Why the stage of this round did not come about. In words without quotes: it goes into a line of JSON.
WHY=""
# take <process> <window> <what to call it>: a click gives it the keyboard, and Arbor hears of it. In a shell of its own, where a click that cannot be aimed is said and not counted: it makes the round void, not red.
take() {
  local said
  said=$(click_window "$2" 2>&1) || { WHY="$3 could not be clicked"; echo "    $said"; return 1; }
  eventually has_the_keyboard "$1" "$2" > /dev/null || { WHY="$3 was clicked and the keyboard is with $(keyboard_now)"; return 1; }
  eventually is focused "$2" > /dev/null 2>&1 || { WHY="$3 was clicked and Arbor calls $(focused_by_arbor) focused"; return 1; }
}
# holds <what to say if not> <command…>
holds() {
  local what=$1
  shift
  eventually "$@" > /dev/null 2>&1 || { WHY=$what; return 1; }
}

# stage <arm>
stage() {
  case "$1" in
    dock) take "$A" "$NAMED" N && take "$A" "$DOCKED" D ;;
    order) take "$B" "$OTHER" O && take "$A" "$NAMED" N && take "$A" "$DOCKED" D ;;
    *) take "$A" "$NAMED" N && take "$B" "$OTHER" O && take "$A" "$DOCKED" D ;;
  esac || return 1
  if [ "$1" = everything ]; then
    holds "N is not in view before the act" is on_screen "$NAMED" && holds "O is not in view before the act" is on_screen "$OTHER" || return 1
  else
    ctl zoom "$DOCKED"
    sleep 0.2
    holds "N is still in view after zoom D" out_of_view "$NAMED" || return 1
    [ "$1" = dock ] || holds "O is still in view after zoom D" out_of_view "$OTHER" || return 1
  fi
  holds "D is not in view before the act" is on_screen "$DOCKED" && holds "D has not the keyboard before the act" has_the_keyboard "$A" "$DOCKED" \
    && holds "A is not in front before the act" front_is "$A" && holds "Arbor does not call D focused before the act" is focused "$DOCKED"
}

said_of_the_stage() {
  case "$1" in
    dock) echo "O in the Dock; used in the order N, D; the view on D, N out of view" ;;
    order) echo "used in the order O, N, D; the view on D, N and O out of view" ;;
    everything) echo "used in the order N, O, D; the view of everything, all three in view" ;;
    *) echo "used in the order N, O, D; the view on D, N and O out of view" ;;
  esac
}

written() {
  printf '{"kind":"round","part":"%s","arm":"%s","time":%s,"a":%s,"b":%s,"docked":%s,"named":%s,"other":%s,"began":"%s","once":"%s","at200":"%s","at1000":"%s","front":"%s","arbor":"%s","inView":"%s","landed":"%s","verdict":"%s","why":"%s"}\n' \
    "$@" | tee -a "$ROUNDS"
}

# round <part> <arm> <which time>
round() {
  local part=$1 arm=$2 time=$3 name="$1-$2-$3" began once soon later front focused docked named other landed verdict look view=no row acted=yes
  step "$name"
  WHY=""
  ctl show-all
  sleep 0.3
  if [ "$arm" = dock ]; then
    away
    sleep 0.8
  fi
  if stage "$arm"; then
    began=$(keyboard_now)
    docked=$(keys_in "$A" "$DOCKED") named=$(keys_in "$A" "$NAMED") other=$(keys_in "$B" "$OTHER")
    record "$name"
    if [ "$arm" = menu ]; then
      row=$(row_of_the_window_named)
      [ -n "$WORD" ] && [ -n "$row" ] && look=$(click_menu "Windows" "$row" 2>&1) || { acted=no WHY="the row of N could not be clicked"; echo "    ${look:-no row reads \"$WORD\"}"; }
    else
      ctl focus "$NAMED"
    fi
  else
    acted=no
  fi
  if [ "$acted" = no ]; then
    [ -z "${began:-}" ] || recorded "$name"
    echo "  void: $WHY"
    summary | sed 's/^/    /'
    written "$part" "$arm" "$time" "$A" "$B" "$DOCKED" "$NAMED" "$OTHER" "${began:-}" "" "" "" "" "" "" "" void "$WHY" > /dev/null
  else
    once=$(keyboard_now)
    sleep 0.2
    soon=$(keyboard_now)
    sleep 0.8
    later=$(keyboard_now)
    front=$(pointer front)
    focused=$(focused_by_arbor)
    ! is on_screen "$NAMED" > /dev/null 2>&1 || view=yes
    key x
    sleep 0.4
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
    written "$part" "$arm" "$time" "$A" "$B" "$DOCKED" "$NAMED" "$OTHER" "$began" "$once" "$soon" "$later" "$front" "$focused" "$view" "$landed" "$verdict" ""
    check "$name: the stage stood: $(said_of_the_stage "$arm"); D had the keyboard, A was in front" true
    check "$name: the window named is in view" test "$view" = yes
    check "$name: the window named has the keyboard, at once and for good, and gets the x" test "$verdict" = right
  fi
  if [ "$arm" = dock ]; then
    back
    sleep 0.8
  fi
}

tally() {
  python3 - "$ROUNDS" << 'PYTHON'
import collections, json, sys
count = collections.OrderedDict()
for line in open(sys.argv[1], encoding="utf-8"):
    o = json.loads(line)
    count.setdefault((o["part"], o["arm"]), collections.Counter())[o["verdict"]] += 1
for (part, arm), verdicts in count.items():
    counted = sum(verdicts.values()) - verdicts["void"]
    print("%-10s %-10s %d of the %d that count right, %d wrong, %d flipped and came back, %d late; %d void (the stage did not come about)" % (
        part, arm, verdicts["right"], counted, verdicts["wrong"], verdicts["flipped"], verdicts["late"], verdicts["void"]))
PYTHON
}

enough_count() {
  local played void
  played=$(grep -c "\"part\":\"$1\",\"arm\":\"$2\"" "$ROUNDS")
  void=$(grep -c "\"part\":\"$1\",\"arm\":\"$2\".*\"verdict\":\"void\"" "$ROUNDS")
  [ "$played" -gt 0 ] && [ "$void" -le $((played / 5)) ] || { echo "$void of its $played rounds are void"; return 1; }
}

# rounds <part>
rounds() {
  local time arm
  echo "A is process $A: docked D $DOCKED, floating and named N $NAMED. B is process $B: floating O $OTHER"
  summary
  for time in $(seq 1 "$TIMES"); do
    for arm in $ARMS; do
      # On the model the fault shows every time, so rounds buy little and a Mac's minutes are dear: all but the road every second time.
      [ "$arm" = road ] || [ $((time % 2)) -eq 1 ] || continue
      round "$1" "$arm" "$time"
    done
  done
  step "$1: do enough rounds count?"
  for arm in $ARMS; do check "$1 $arm: at most a fifth of its rounds is void" enough_count "$1" "$arm"; done
}

# MARK: 1. Two test apps

step "1  two test apps"
ARBOR_TEST_WINDOWS_ARGS="--regular" ARBOR_SECOND_APP=1 ARBOR_SECOND_APP_ARGS="--regular"
arbor_start 2 ARBOR_NO_STATUS_ITEM=0
tw title "$W2" zqxnamed
ctl arrange
ctl float "$W2"
ctl float "$V1"
sleep 3 # regular apps joining the Dock resize it, and with it every slot
# Apart, and low over the docked window: whoever lies on top, something of each of the three can be clicked.
tw move "$W2" 40 430 290 220 > /dev/null
tw2 move "$V1" 350 430 290 220 > /dev/null
sleep 1
A=$ARBOR_WINDOWS_PID B=$ARBOR_WINDOWS_PID_2 DOCKED=$W1 NAMED=$W2 OTHER=$V1 WORD=zqxnamed
keys_in() { events_of "$2" key; }
away() { tw2 minimize "$OTHER" > /dev/null; }
back() { tw2 restore "$OTHER" > /dev/null; }
check "A's first window is docked" is docked "$DOCKED"
check "A's second floats" is floating "$NAMED"
check "B's floats" is floating "$OTHER"
check "Arbor tells N's title to whoever asks for titles" test "$(title_of_the_window_named)" = "$WORD"
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
  arbor_start_apps "$A" "$B" ARBOR_NO_STATUS_ITEM=0
  ctl arrange
  ctl float "$NAMED"
  ctl float "$OTHER"
  sleep 2
  echo "N is put at $(apptool set-frame "$NAMED" 20 430 440 250), O at $(apptool set-frame "$OTHER" 480 430 520 250)"
  sleep 1
  WORD=$(title_of_the_window_named)
  echo "N's title is '$WORD': a file of this script's own"
  keys_in() { "$TYPED" "$1" "$2"; }
  away() { apptool minimize "$OTHER"; }
  back() { apptool unminimize "$OTHER"; }
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
