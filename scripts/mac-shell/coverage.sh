#!/bin/bash
# How much of the macOS-only code do the automatic real-window checks execute? A measurement, not a check.
#
#   scripts/mac-shell/run.sh scripts/mac-shell/coverage.sh          about seven minutes on the Mac
#
# Sources/ArborKit/AX, UI, Input and App cannot run in tests. What runs them without being asked is CI's job `real-windows`: arbor-e2e
# (scripts/e2e.sh --full-screen) and e2e-drag.sh. This script builds everything with the compiler's coverage instrumentation, runs those
# two as CI does, and lets llvm-cov say which lines, functions and regions ran. Then, while there is time, it plays shots-demo.sh and
# proof.sh with Reduce Motion off: sessions with the shortcuts, the event taps and the menu bar item on, which is nearer to
# the Arbor a person runs, to show what such a session would add.
#
# It leaves in mac-shell/coverage/
#   report.txt, report.md     every measurement side by side, per folder and per file (scripts/coverage-report.py)
#   processes.txt             per part: how many Arbors ran, how many left a profile
#   <measurement>/            e2e, drag, both; session (the two played scripts alone), with-session (all of it)
#     summary.txt             llvm-cov report: per file regions, functions and lines, and how many of each never ran
#     functions.txt           per file the functions that never ran, then the largest of them
#     lines/<file>.txt        the source with how often each line ran: 0 is a line nothing reached
#     coverage.json           llvm-cov export -summary-only, which coverage-report.py reads
#     export.json             the same with every function and region
#   <part>/output.txt         what the part printed
#
# The build has a folder of its own, .build/coverage: it takes nothing from the plain build beside it, which may have come out of a cache that
# other runs share, and leaves it as it was. The scripts are run unchanged, and they look in .build/debug and call `swift build` themselves. So
# .build/debug, a link that SwiftPM makes, points at the instrumented build while this runs, and a `swift` at the front of the PATH adds the
# folder and the flags to every `swift build`.
#
# How every Arbor is caught. Arbor is started many times, by the runner, by scripts and by its own watchdog, and all
# of them hand their environment on, so LLVM_PROFILE_FILE reaches each: %p gives every process a file of its own, %m names the program it
# ran. Some Arbors are killed with -9 on purpose and never get to write. With %c the counters live in the file from the start,
# which needs their sections aligned to pages; the script tries that first and says which way it went. `ps` is asked five times a second
# which Arbors run, so that one that left nothing is counted and not just missing.
#
# Exit code 0: measured, and both of CI's checks passed. 1: measured, but a check failed or was cut off, so less ran than CI runs.
# 2: no build, or no tables.
ARBOR_TIME_LIMIT=1150
source "$(dirname "$0")/lib.sh"
needs_throwaway_mac "point .build/debug at an instrumented build, which writes a profile wherever it is started, and switch Reduce Motion off"
if [ -n "${ARBOR_REHEARSAL:-}" ]; then
  echo "skipped: the fake Mac's Arbor is a script, which no compiler instruments: there is nothing to measure in a rehearsal"
  exit 77
fi

COVERAGE_OUT="$ARBOR_OUT/coverage"
COVERAGE_BUILD="$ARBOR_ROOT/.build/coverage"
COVERAGE_BINARY="$ARBOR_BIN/Arbor"
COVERAGE_SOURCES="$ARBOR_ROOT/Sources/ArborKit/AX $ARBOR_ROOT/Sources/ArborKit/UI $ARBOR_ROOT/Sources/ArborKit/Input
  $ARBOR_ROOT/Sources/ArborKit/App $ARBOR_ROOT/Sources/ArborKit/IPC"
# When the last part must have ended, for the tables to be written within ARBOR_TIME_LIMIT.
COVERAGE_LAST_CALL=1030
mkdir -p "$COVERAGE_OUT"
scratch_dir coverage COVERAGE_DIR

# MARK: Tables

# tables <measurement> <part…>: merges what the Arbors of those parts left and writes mac-shell/coverage/<measurement>/.
tables() {
  local name=$1 out="$COVERAGE_OUT/$1" data="$COVERAGE_DIR/$1.profdata" part began=$SECONDS
  shift
  mkdir -p "$out/lines"
  for part in "$@"; do
    ls "$COVERAGE_DIR/$part/$COVERAGE_SIGNATURE"*.profraw 2>/dev/null
  done > "$COVERAGE_DIR/$name.list"
  # Not "any": a process killed while it was starting may leave a file without a head, which must not cost the others.
  "$LLVM_PROFDATA" merge -sparse -failure-mode=all -f "$COVERAGE_DIR/$name.list" -o "$data" > "$out/merge.log" 2>&1 \
    || { echo "$name: no profile could be merged: $(tail -n 1 "$out/merge.log")"; return 1; }
  # shellcheck disable=SC2086
  {
    "$LLVM_COV" report "$COVERAGE_BINARY" -instr-profile="$data" $COVERAGE_SOURCES > "$out/summary.txt"
    "$LLVM_COV" export "$COVERAGE_BINARY" -instr-profile="$data" -summary-only $COVERAGE_SOURCES > "$out/coverage.json"
    "$LLVM_COV" export "$COVERAGE_BINARY" -instr-profile="$data" $COVERAGE_SOURCES > "$out/export.json"
    "$LLVM_COV" show "$COVERAGE_BINARY" -instr-profile="$data" -format=text -output-dir="$COVERAGE_DIR/$name.lines" $COVERAGE_SOURCES
  } 2>> "$out/merge.log"
  python3 "$ARBOR_ROOT/scripts/coverage-report.py" --functions "$out/export.json" | "$SWIFT_DEMANGLE" -simplified > "$out/functions.txt"
  # llvm-cov repeats the whole path of each source under its output folder.
  find "$COVERAGE_DIR/$name.lines" -name "*.swift.txt" -exec mv {} "$out/lines/" \;
  echo "$name ($(wc -l < "$COVERAGE_DIR/$name.list" | tr -d ' ') profiles, $(grep -c -i "warning\|error" "$out/merge.log") complaints in merge.log," \
    "$((SECONDS - began)) s): $(python3 "$ARBOR_ROOT/scripts/coverage-report.py" "$out/coverage.json" | tail -n 1)"
}

# MARK: Parts

arbors_running() {
  while :; do
    # By its name alone. What ps shows is what the process was started as: a script gives the whole path, and of the eighteen Arbors that
    # arbor-e2e and the watchdog start, a pattern that asked for the build folder found none. No other Arbor runs on a throwaway Mac.
    ps -A -o pid=,comm= | awk '{ sub(/.*\//, "", $2) } $2 == "Arbor" { print $1 }'
    sleep 0.2
  done
}

# part <name> <seconds> <program…>: runs it with a folder of its own for the profiles. Several calls may share a name.
part() {
  local name=$1 seconds=$2 began=$SECONDS code watcher seen silent
  shift 2
  step "$name: $* (at most $seconds s)"
  mkdir -p "$COVERAGE_DIR/$name" "$COVERAGE_OUT/$name" "$ARBOR_OUT/$name"
  arbors_running >> "$COVERAGE_DIR/$name.seen" &
  watcher=$!
  started "$watcher"
  (
    export LLVM_PROFILE_FILE="$COVERAGE_DIR/$name/$COVERAGE_PATTERN"
    limit "$seconds" "$@"
  ) >> "$COVERAGE_OUT/$name/output.txt" 2>&1
  code=$?
  kill_started "$watcher"
  wait "$watcher" 2>/dev/null
  # The next part's logs and pictures have the same names.
  find "$ARBOR_OUT" -maxdepth 1 -type f \( -name "*.log" -o -name "*.png" \) -exec mv {} "$ARBOR_OUT/$name/" \;
  echo "exit code $code after $((SECONDS - began)) s: $(grep -c "✔" "$COVERAGE_OUT/$name/output.txt") ✔, $(grep -c "✘" "$COVERAGE_OUT/$name/output.txt") ✘"
  grep "✘\|no verdict\|::error" "$COVERAGE_OUT/$name/output.txt" | sort -u | head -n 20
  seen=$(sort -un "$COVERAGE_DIR/$name.seen" | wc -l | tr -d ' ')
  silent=$(sort -un "$COVERAGE_DIR/$name.seen" | while read -r pid; do
    ls "$COVERAGE_DIR/$name/"*"-$pid.profraw" > /dev/null 2>&1 || echo "$pid"
  done | wc -l | tr -d ' ')
  echo "$name: ps saw $seen Arbors, $silent of them left no profile;" \
    "$(ls "$COVERAGE_DIR/$name/$COVERAGE_SIGNATURE"*.profraw 2>/dev/null | wc -l | tr -d ' ') profiles of Arbor's," \
    "$(ls "$COVERAGE_DIR/$name" | wc -l | tr -d ' ') of all programs" | tee -a "$COVERAGE_OUT/processes.txt"
  return "$code"
}

# MARK: The tools

step "the tools"
# The ones that came with the compiler: Xcode's may be a release behind and not read its profiles.
COVERAGE_SWIFT=$(command -v swift) || die "there is no swift on the PATH"
toolchain=$(swift -print-target-info 2>/dev/null | python3 -c 'import json, os, sys
print(os.path.normpath(os.path.join(json.load(sys.stdin)["paths"]["runtimeResourcePath"], "..", "..", "bin")))')
tool() {
  local place
  for place in "$toolchain" "$(dirname "$COVERAGE_SWIFT")"; do
    if [ -x "$place/$1" ]; then echo "$place/$1"; return 0; fi
  done
  xcrun --find "$1" 2>/dev/null
}
LLVM_PROFDATA=$(tool llvm-profdata) || die "no llvm-profdata beside swift ($toolchain) or in Xcode"
LLVM_COV=$(tool llvm-cov) || die "no llvm-cov beside swift ($toolchain) or in Xcode"
SWIFT_DEMANGLE=$(tool swift-demangle) || die "no swift-demangle beside swift ($toolchain) or in Xcode"
swift --version 2>&1 | head -n 1
echo "$LLVM_COV: $("$LLVM_COV" --version 2>&1 | grep -i "version" | head -n 1 | tr -s ' ')"
echo "$LLVM_PROFDATA"

# MARK: The build

step "an instrumented build"
instrument="--scratch-path $COVERAGE_BUILD -Xswiftc -profile-generate -Xswiftc -profile-coverage-mapping"
# What clang's own driver passes for -fprofile-instr-generate on a Mac, and the Swift driver does not: %c maps the counters onto the file,
# page by page, and what follows them must not share their last page.
align=""
for section in __llvm_prf_cnts __llvm_prf_bits __llvm_prf_data; do
  align="$align -Xlinker -sectalign -Xlinker __DATA -Xlinker $section -Xlinker 0x4000"
done
mkdir -p "$COVERAGE_DIR/bin"
export PATH="$COVERAGE_DIR/bin:$PATH"

# build_with <flags>: from here on every `swift build` of this run, whoever calls it, gets them.
build_with() {
  cat > "$COVERAGE_DIR/bin/swift" <<EOF
#!/bin/bash
if [ "\${1:-}" = build ]; then
  shift
  exec "$COVERAGE_SWIFT" build $1 "\$@"
fi
exec "$COVERAGE_SWIFT" "\$@"
EOF
  chmod +x "$COVERAGE_DIR/bin/swift"
  echo "swift build $1"
  swift build > "$COVERAGE_OUT/build.log" 2>&1
}
if ! build_with "$instrument$align"; then
  echo "that failed: $(grep "error:" "$COVERAGE_OUT/build.log" | sort -u | head -n 5)"
  echo "once more without the alignment"
  build_with "$instrument"
fi
echo "$(tail -n 1 "$COVERAGE_OUT/build.log") ($SECONDS s so far)"
# Should this script be killed before it puts the link back, the next plain `swift build` does: SwiftPM makes it anew every time.
[ ! -e "$ARBOR_ROOT/.build/debug" ] || [ -L "$ARBOR_ROOT/.build/debug" ] || die ".build/debug is no link, so it cannot be pointed elsewhere"
plain=$(readlink "$ARBOR_ROOT/.build/debug")
at_exit "rm -f '$ARBOR_ROOT/.build/debug'; [ -z '$plain' ] || ln -s '$plain' '$ARBOR_ROOT/.build/debug'"
rm -f "$ARBOR_ROOT/.build/debug"
ln -s coverage/debug "$ARBOR_ROOT/.build/debug"
echo ".build/debug pointed at '${plain:-nothing}' and points at $(readlink "$ARBOR_ROOT/.build/debug") until this script ends"
# Finds nothing left to build, or says what failed and ends the script; compiles the pointer tool.
arbor_build

# MARK: Which pattern

step "can the counters live in the file?"
# try_pattern <name> <pattern>: `Arbor --version` is the shortest life an Arbor has. In a folder that no measurement reads.
try_pattern() {
  mkdir -p "$COVERAGE_DIR/$1"
  LLVM_PROFILE_FILE="$COVERAGE_DIR/$1/$2" "$COVERAGE_BINARY" --version > "$COVERAGE_OUT/$1.txt" 2>&1
  cat "$COVERAGE_OUT/$1.txt"
  ! grep -q "LLVM Profile" "$COVERAGE_OUT/$1.txt" && "$LLVM_PROFDATA" show "$COVERAGE_DIR/$1/"*.profraw 2>&1 | grep "Total functions"
}
if try_pattern try-continuous "%m-%p%c.profraw"; then
  COVERAGE_PATTERN="%m-%p%c.profraw"
  echo "yes: an Arbor that is killed leaves what it had counted"
elif try_pattern try-at-exit "%m-%p.profraw"; then
  COVERAGE_PATTERN="%m-%p.profraw"
  echo "no: profiles are written at exit, so what an Arbor did that was then killed with -9 is lost; processes.txt counts them"
else
  die "an instrumented Arbor leaves no profile that llvm-profdata reads"
fi
# <signature>_0-<pid>.profraw. Empty means every program's profiles are merged, which costs time and changes nothing: only Arbor holds this code.
COVERAGE_SIGNATURE=$(ls "$COVERAGE_DIR"/try-*/ | sed -n 's/-[0-9]*\.profraw$//p' | tail -n 1)
echo "Arbor's profiles begin with '$COVERAGE_SIGNATURE'"

# MARK: What CI runs

part e2e 540 ./scripts/e2e.sh --full-screen
check "arbor-e2e passed, as it must in CI" [ $? -eq 0 ]
part drag 200 bash scripts/mac-shell/e2e-drag.sh
check "e2e-drag.sh passed, as it must in CI" [ $? -eq 0 ]

step "what the two executed"
tables e2e e2e
tables drag drag
tables both e2e drag || die "no tables"
measured="$COVERAGE_OUT/e2e/coverage.json $COVERAGE_OUT/drag/coverage.json $COVERAGE_OUT/both/coverage.json"

# MARK: What one session nearer to a person's would add

# Their checks are not this script's business: they are played for what they make Arbor do.
if [ $((COVERAGE_LAST_CALL - SECONDS)) -ge 150 ]; then
  macos_reduce_motion off
  at_exit 'macos_reduce_motion on'
  part session $((COVERAGE_LAST_CALL - SECONDS)) bash scripts/mac-shell/shots-demo.sh
  if [ $((COVERAGE_LAST_CALL - SECONDS)) -ge 200 ]; then
    part session $((COVERAGE_LAST_CALL - SECONDS)) bash scripts/mac-shell/proof.sh
  else
    echo "no time left for proof.sh ($SECONDS s so far)"
  fi
  step "what that adds"
  tables session session
  tables with-session e2e drag session && measured="$measured $COVERAGE_OUT/with-session/coverage.json"
else
  echo "no time left for a session nearer to a person's ($SECONDS s so far)"
fi

step "all of it"
# shellcheck disable=SC2086
python3 "$ARBOR_ROOT/scripts/coverage-report.py" $measured --markdown "$COVERAGE_OUT/report.md" | tee "$COVERAGE_OUT/report.txt"
echo
cat "$COVERAGE_OUT/processes.txt"
echo "$SECONDS s in all"
