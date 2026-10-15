#!/bin/bash
# Drives the real arborctl as a shell script would: options, exit codes, what goes to which output, batches from
# standard input, timeouts and completions. Against `arbor-sim --serve` (the real socket, server and controller, with
# pretend windows) and against a server that never answers. Part of `make check`; watch-smoke.sh covers `watch`.
set -uo pipefail
cd "$(dirname "$0")/.."

sim=$PWD/.build/debug/arbor-sim
ctl=$PWD/.build/debug/arborctl
[ -x "$sim" ] && [ -x "$ctl" ] || { echo "run swift build first"; exit 2; }

# A short path: a socket's is limited to about a hundred bytes.
dir=$(mktemp -d /tmp/arbor-cli.XXXXXX) || exit 2
export ARBOR_HOME=$dir ARBOR_SOCKET=$dir/arbor.sock
# The simulator takes words of its own (`open Safari`), which an arborctl that checks commands first (F50) would refuse.
export ARBOR_UNCHECKED=1
server=""
mute=""
failed=0
cleanup() {
  [ -n "$server" ] && kill -9 "$server" 2>/dev/null
  [ -n "$mute" ] && kill -9 "$mute" 2>/dev/null
  rm -rf "$dir"
}
trap cleanup EXIT

check() { # check "<what should hold>" <command…>
  local what=$1
  shift
  if "$@"; then echo "  ✔ $what"; else echo "  ✘ $what"; failed=1; fi
}
is() { [ "$1" = "$2" ] || { echo "    got '$1', expected '$2'"; return 1; }; }
has() { grep -q -- "$2" "$1" 2> /dev/null || { echo "    no '$2' in:"; sed 's/^/      /' "$1" | head -n 8; return 1; }; }
empty() { [ ! -s "$1" ] || { echo "    not empty:"; sed 's/^/      /' "$1" | head -n 8; return 1; }; }
# try <arguments…>: runs arborctl; $code, $dir/out and $dir/err hold what came of it. Standard input is passed on.
try() {
  "$ctl" "$@" > "$dir/out" 2> "$dir/err"
  code=$?
}
# batch '<lines, as for printf>' <options…>: the same with the lines on standard input. (Not through a pipe: `try` would
# run in a shell of its own and take $code with it.)
batch() {
  # shellcheck disable=SC2059
  printf "$1" > "$dir/batch"
  shift
  try "$@" - < "$dir/batch"
}

echo "without Arbor"
for arguments in "" "--help" "-h" "help" "--json --help"; do
  # shellcheck disable=SC2086
  try $arguments < /dev/null
  check "arborctl $arguments: the help, exit code 0" is "$code" 0
  check "  with arborctl's own options" has "$dir/out" "--keep-going"
  check "  and Arbor's commands" has "$dir/out" "show-all"
done
try --version
check "--version answers" is "$code: $(cut -d' ' -f1 "$dir/out")" "0: arborctl"
try status
check "a command: exit code 2" is "$code" 2
check "  nothing on standard output" empty "$dir/out"
check "  the reason on standard error" has "$dir/err" "arborctl: Arbor is not running"
batch 'status\nstatus\nstatus\n' --keep-going
check "a batch stops at once when nobody is there, even with --keep-going" is "$code: $(wc -l < "$dir/err" | tr -d ' ')" "2: 1"

echo "arguments arborctl does not understand: exit code 64, nothing sent"
for arguments in "--bogus status" "--timeout" "--timeout soon status" "--timeout 0 status" "status --timeout" "- status" "completions" "completions powershell" \
  "--titles watch" ", status" "status ," "status , watch"; do
  # shellcheck disable=SC2086
  try $arguments < /dev/null
  check "arborctl $arguments" is "$code" 64
  check "  says why on standard error only" is "$(wc -c < "$dir/out" | tr -d ' '): $(cut -c 1-9 "$dir/err")" "0: arborctl:"
done
try exclude "a
quit"
check "a line break inside an argument" is "$code" 64

echo "completions"
for shell in zsh bash fish; do
  try completions $shell
  check "$shell: a script that offers the commands" has "$dir/out" "show-all.*toggle-float.*quit"
done
try completions bash
offered=$(bash -c "source '$dir/out'; COMP_WORDS=(arborctl toggle-); COMP_CWORD=1; _arborctl; echo \"\${COMPREPLY[*]}\"")
# Not the whole list: commands are added all the time.
check "bash completes toggle- to the commands that start so" is \
  "$(echo "$offered" | tr ' ' '\n' | grep -c -e '^toggle-float$' -e '^toggle-pause$'): $(echo "$offered" | tr ' ' '\n' | grep -vc '^toggle-')" "2: 0"
offered=$(bash -c "source '$dir/out'; COMP_WORDS=(arborctl dock b); COMP_CWORD=2; _arborctl; echo \"\${COMPREPLY[*]}\"")
check "and an edge after dock" is "$offered" "bottom beside"

echo "with Arbor"
"$sim" --serve "$ARBOR_SOCKET" > "$dir/sim.log" 2>&1 &
server=$!
for _ in $(seq 200); do "$ctl" status > /dev/null 2>&1 && break; sleep 0.05; done
try open Safari
try open Notes
try status
check "yes: exit code 0, the answer on standard output, no complaint" is "$code: $(head -n 1 "$dir/out" | cut -d: -f1): $(wc -c < "$dir/err" | tr -d ' ')" "0: running: 0"
try zoom 999
check "no: exit code 1" is "$code" 1
check "  nothing on standard output" empty "$dir/out"
check "  the reason on standard error" has "$dir/err" "arborctl: .*999"
try --json zoom 999
# A refusal is a refusal whatever was asked for. The exit code always tells the truth.
check "--json: a refusal is still 1, with nothing on standard output" is "$code: $(wc -c < "$dir/out" | tr -d ' ')" "1: 0"
check "  and the reason on standard error" has "$dir/err" "arborctl: .*999"
try --timeout 2 --json status
check "options combine" is "$code: $(grep -c '"ok":true' "$dir/out")" "0: 1"
try zoom 999 --json
check "options count after the command too" is "$code: $(wc -c < "$dir/out" | tr -d ' '): $(grep -c 'arborctl: .*999' "$dir/err")" "1: 0: 1"
try status --timeout 2 --json
check "  several of them" is "$code: $(grep -c '"ok":true' "$dir/out")" "0: 1"
try -- status
check "-- ends the options" is "$code" 0
try -- status --json
check "  so what follows it is sent, and Arbor refuses it" is "$code" 1
try status -q
check "-q: exit code 0" is "$code" 0
check "  and nothing printed" is "$(cat "$dir/out" "$dir/err" | wc -c | tr -d ' ')" 0
try -q zoom 999
check "-q: a refusal is exit code 1" is "$code" 1
check "  and nothing printed" is "$(cat "$dir/out" "$dir/err" | wc -c | tr -d ' ')" 0

"$ctl" "watch view" > "$dir/out" 2> "$dir/err" &
watcher=$!
for _ in 1 2 3 4 5 6 7 8 9 10; do [ -s "$dir/out" ] && break; sleep 0.2; done
kill "$watcher" 2> /dev/null
wait "$watcher" 2> /dev/null
check "watch is watch also when the shell hands it over as one word with its arguments" has "$dir/out" '"hello"'

try exclude "$(head -c 70000 /dev/zero | tr '\0' a)"
check "a request that is too long is refused by Arbor: exit code 1, not 2" is "$code" 1
check "  with the reason" has "$dir/err" "longer than"

echo "several commands on one line"
try show-all , relayout , desktop
check "a , b , c: exit code 0" is "$code" 0
check "  one answer per command" is "$(wc -l < "$dir/out" | tr -d ' ')" 3
try show-all , zoom 999 , desktop
check "they stop at the first refusal: exit code 1" is "$code" 1
check "  and what follows is not run" is "$(wc -l < "$dir/out" | tr -d ' ')" 1
try show-all , zoom 999 , desktop --keep-going
check "--keep-going: still exit code 1" is "$code" 1
check "  and the rest is run" is "$(wc -l < "$dir/out" | tr -d ' ')" 2

echo "batches"
try - <<'BATCH'
# A morning's arrangement.
dock 101 left

   dock   102	right
show-all
BATCH
check "comments, blank lines and odd spacing: exit code 0" is "$code" 0
check "  one answer per command" is "$(wc -l < "$dir/out" | tr -d ' ')" 3
try status
check "  and both are docked" has "$dir/out" "2 docked"
batch 'show-all\nzoom 999\ndesktop\n'
check "a batch stops at the first refusal: exit code 1" is "$code" 1
check "  which names its line" has "$dir/err" "arborctl: line 2: .*999"
check "  and what follows is not run" is "$(wc -l < "$dir/out" | tr -d ' ')" 1
batch 'show-all\nzoom 999\nteleport\ndesktop' --keep-going
check "--keep-going: still exit code 1" is "$code" 1
check "  every refusal with its line" is "$(cut -d: -f2 "$dir/err" | tr -d '\n')" " line 2 line 3"
check "  and the rest is run, the last line without a line break too" is "$(wc -l < "$dir/out" | tr -d ' ')" 2
batch 'show-all\rrelayout\rdesktop\r'
check "lines that end in a carriage return alone are all run" is "$code: $(wc -l < "$dir/out" | tr -d ' ')" "0: 3"
batch 'show-all\nwatch view\ndesktop\n'
check "watch in a batch is refused: exit code 64" is "$code" 64
check "  with its line" has "$dir/err" "arborctl: line 2: watch"
check "  and what follows is not run" is "$(wc -l < "$dir/out" | tr -d ' ')" 1
try - < /dev/null
check "an empty batch is done: exit code 0" is "$code" 0
# A program at the other end that waits for each answer before it sends the next command.
mkfifo "$dir/in" "$dir/answers"
"$ctl" - < "$dir/in" > "$dir/answers" 2> "$dir/err" &
talker=$!
exec 7> "$dir/in" 8< "$dir/answers"
echo desktop >&7
read -r -t 10 first <&8
echo show-all >&7
read -r -t 10 second <&8
exec 7>&- 8<&-
wait "$talker"
check "each answer comes before the next command is sent" is "$?: ${first:+answered}: ${second:+answered}" "0: answered: answered"

echo "a server that never answers"
python3 - "$dir/mute.sock" <<'PYTHON' &
import socket, sys, time
listener = socket.socket(socket.AF_UNIX)
listener.bind(sys.argv[1])
listener.listen(8)
kept = []
while True:
    kept.append(listener.accept())
PYTHON
mute=$!
for _ in $(seq 200); do [ -S "$dir/mute.sock" ] && break; sleep 0.05; done
began=$SECONDS
ARBOR_SOCKET=$dir/mute.sock try --timeout 0.5 status
check "exit code 4, not 2: Arbor is there" is "$code" 4
check "  after the time given" test $((SECONDS - began)) -le 3
check "  and it says how long it waited" has "$dir/err" "did not answer within 0.5 s"
ARBOR_SOCKET=$dir/mute.sock try watch --timeout 0.3
check "watch waits no longer for its first line: exit code 4" is "$code" 4
ARBOR_SOCKET=$dir/mute.sock "$ctl" watch --timeout 0.3 2> "$dir/err" | cat > "$dir/out"
check "  nor into a pipe" has "$dir/err" "did not answer within 0.3 s"
ARBOR_SOCKET=$dir/mute.sock batch 'status\nstatus\n' --timeout 0.2 --keep-going
check "in a batch with --keep-going each line gets its time" is "$code: $(wc -l < "$dir/err" | tr -d ' ')" "4: 2"
kill "$mute" 2> /dev/null
wait "$mute" 2> /dev/null
mute=""

try quit
check "quit" is "$code" 0
wait "$server" 2> /dev/null
server=""

[ "$failed" = 0 ] || { echo "cli smoke test FAILED"; exit 1; }
echo "cli smoke test passed"
