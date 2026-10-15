#!/bin/bash
# Is anything left on the Mac when arbor-e2e is ended in the middle of a run? The runner starts a guardian for that
# (Sources/arbor-e2e/Guardian.swift). scripts/test-e2e-guardian.py holds the guardian to a table of endings against stand-ins; this ends
# the real runner, with the real Arbor arranging real windows and its real watchdog beside it:
#   - the runner alone, with a signal nobody can catch;
#   - its whole process group, as a caller's time limit does (Foundation gives every child a group of its own, so on a Mac that may be the runner
#     alone once more: the groups are printed);
#   - Arbor, and the runner a moment later: the watchdog is about to start another Arbor, which nobody is left to know of;
#   - with SIGTERM, which the runner catches and cleans up after.
# Each time it first sees Arbor, the watchdog, the guardian and the folder there, so that "nothing is left" is not said of nothing.
# Then it runs the table itself, with macOS's own perl and locks.
#
#   scripts/mac-shell/run.sh scripts/mac-shell/check-e2e-guardian.sh      # about three minutes
source "$(dirname "$0")/lib.sh"
needs_throwaway_mac "end arbor-e2e in the middle of a run, with its Arbor arranging windows, to see what is left"
arbor_build
# The rehearsal on Linux has no stand-in for it.
[ -x "$ARBOR_BIN/arbor-e2e" ] || { echo "there is no arbor-e2e here, which only a Mac builds"; exit 64; }

now() { perl -MTime::HiRes=time -e 'printf "%.1f", time'; }
since() { perl -e 'printf "%.1f", $ARGV[1] - $ARGV[0]' "$1" "$(now)"; }
# within <seconds> <command…>: tries it until it holds.
within() {
  local tenths=$(($1 * 10))
  shift
  while [ "$tenths" -gt 0 ]; do
    "$@" && return 0
    sleep 0.1
    tenths=$((tenths - 1))
  done
  "$@"
}
# By the end of the command line, whatever folder it runs from. Nobody's Arbor runs on a throwaway Mac.
arbors() { pgrep -f '/Arbor( --watchdog [0-9]+)?$'; }
test_apps() { pgrep -f '/ArborTestWindows( |$)'; }
# By the number the runner printed.
guardian_waits() { [ -n "$GUARDIAN" ] && kill -0 "$GUARDIAN" 2> /dev/null; }
guardian_has_left() { ! guardian_waits; }
under_way() { [ "$(grep -c '^▸ ' "$1")" -ge 6 ]; }
count() { "$@" | wc -l | tr -d ' '; }
none() { [ "$(count "$@")" = 0 ]; }
another_arbor() { pgrep -f '/Arbor$' | grep -qvx "$1"; }
holder() { cat "$RUN_HOME/arbor.lock" 2> /dev/null; }
holder_lives() { local pid; pid=$(holder); [ -n "$pid" ] && kill -0 "$pid" 2> /dev/null; }
# Keeps the last number seen in the lock: the file goes with the folder.
folder_is_gone() { LAST_HOLDER=$(holder || echo "${LAST_HOLDER:-}"); [ ! -e "$RUN_HOME" ]; }

# Starts a run, in a process group of its own, and waits until its Arbor has been arranging windows for a while.
begin() {
  step "$1"
  none arbors || die "an Arbor is running before the run has begun"
  perl -e 'setpgrp(0, 0); exec { $ARGV[0] } @ARGV' "$ARBOR_BIN/arbor-e2e" > "$ARBOR_OUT/run-$2.txt" 2>&1 < /dev/null &
  RUNNER=$!
  started "$RUNNER"
  RUN_HOME="$(getconf DARWIN_USER_TEMP_DIR)arbor-e2e-$RUNNER"
  within 30 holder_lives || { tail -n 20 "$ARBOR_OUT/run-$2.txt"; die "no Arbor holds the lock in the run's folder"; }
  within 60 under_way "$ARBOR_OUT/run-$2.txt" || { tail -n 20 "$ARBOR_OUT/run-$2.txt"; die "the run does not get under way"; }
  GUARDIAN=$(sed -n 's/^guardian: pid //p' "$ARBOR_OUT/run-$2.txt")
  echo "  in the step: $(grep '^▸ ' "$ARBOR_OUT/run-$2.txt" | tail -n 1)"
  echo "  process, group and command of the runner, the guardian, Arbor and its watchdog:"
  ps -o pid=,pgid=,ucomm= -p "$(echo "$RUNNER" $GUARDIAN $(arbors) | tr ' ' ',')" | sed 's/^/    /'
  check "before: Arbor and its watchdog run" test "$(count arbors)" = 2
  check "before: the test windows' app runs" test "$(count test_apps)" = 1
  check "before: the guardian waits" guardian_waits
  check "before: the run's folder is there" test -d "$RUN_HOME"
  check "before: the runner is in the middle of its run" kill -0 "$RUNNER"
}

# What the guardian is for. It gives an Arbor that does not answer five seconds, then holds the lock for fifteen and removes the folder.
nothing_is_left() {
  local from
  from=$(now)
  check "no Arbor and no watchdog is left" within 20 none arbors
  echo "  after $(since "$from") s"
  check "the test windows' app has left" within 10 none test_apps
  check "the run's folder is gone" within 30 folder_is_gone
  check "the guardian has left" within 5 guardian_has_left
  echo "  after $(since "$from") s"
  sleep 3
  check "and nothing comes back" none arbors
}

begin "the runner alone is killed (kill -9)" alone
kill -9 "$RUNNER"
nothing_is_left

begin "its whole process group is killed, as by a caller's time limit (kill -9)" group
# safe anywhere: the group of the runner started eight lines above, which setpgrp made for it alone
kill -9 -- "-$RUNNER"
nothing_is_left

begin "Arbor is killed, and the runner a moment later: the watchdog's next Arbor is nobody's (kill -9, twice)" orphan
first=$(holder)
from=$(now)
kill -9 "$first"
kill -9 "$RUNNER"
# The guardian has the lock by now. What it is patient for: how long until the watchdog's Arbor has come, found the lock held and left.
check "the watchdog starts another Arbor" within 10 another_arbor "$first"
echo "  after $(since "$from") s"
nothing_is_left
if [ "$LAST_HOLDER" = "$first" ]; then echo "  that Arbor never had the lock"; else echo "  that Arbor had the lock, and was asked to quit"; fi

begin "the runner is asked to end (kill -TERM): it cleans up itself" asked
kill -TERM "$RUNNER"
nothing_is_left
check "the runner said why it ended" grep -q "stopped by signal 15" "$ARBOR_OUT/run-asked.txt"

step "the table of endings, with macOS's own perl and locks"
python3 scripts/test-e2e-guardian.py -v > "$ARBOR_OUT/table.txt" 2>&1
table=$?
cat "$ARBOR_OUT/table.txt"
check "every ending comes out as expected" test "$table" = 0
