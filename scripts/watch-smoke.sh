#!/bin/bash
# Drives the real arborctl against `arbor-sim --serve`: the real control socket, server, event feed and
# controller, with pretend windows. Checks what only separate processes can show: that `arborctl watch`
# hands each event on at once, even into a pipe or a file, its exit codes, and that clients that
# misbehave (leave early, say nothing, stop reading) cost the server nothing. Part of `make check`.
set -uo pipefail
cd "$(dirname "$0")/.."

sim=$PWD/.build/debug/arbor-sim
ctl=$PWD/.build/debug/arborctl
[ -x "$sim" ] && [ -x "$ctl" ] || { echo "run swift build first"; exit 2; }

# A short path: a socket's is limited to about a hundred bytes.
dir=$(mktemp -d /tmp/arbor-watch.XXXXXX) || exit 2
export ARBOR_HOME=$dir ARBOR_SOCKET=$dir/arbor.sock
# The simulator takes words of its own (`arborctl open Safari`), which an arborctl that checks commands before sending them (F50) would refuse.
export ARBOR_UNCHECKED=1
server=""
failed=0
cleanup() {
  [ -n "$server" ] && kill -9 "$server" 2>/dev/null
  rm -rf "$dir"
}
trap cleanup EXIT

check() { # check "<what should hold>" <command…>
  local what=$1
  shift
  if "$@"; then echo "  ✔ $what"; else echo "  ✘ $what"; failed=1; fi
}
eventually() { # try a command for up to ten seconds
  local tries=0
  until "$@"; do
    tries=$((tries + 1))
    [ "$tries" -ge 200 ] && return 1
    sleep 0.05
  done
}
is() { [ "$1" = "$2" ] || { echo "    got $1, expected $2"; return 1; }; }
has() { grep -q -- "$2" "$1" 2> /dev/null; }
lacks() { ! has "$1" "$2"; }
running() { kill -0 "$1" 2>/dev/null; }
gone() { ! running "$1"; }
# Sets $code to the exit code of a background process, which gets ten seconds to end.
exit_code_of() {
  if eventually gone "$1"; then
    wait "$1"
    code=$?
  else
    kill -9 "$1"
    code="none: it was still running"
  fi
}
answers() { "$ctl" status > /dev/null 2>&1; }

start_server() {
  "$sim" --serve "$ARBOR_SOCKET" > "$dir/sim.log" 2>&1 &
  server=$!
  eventually answers || { echo "arbor-sim --serve did not answer"; cat "$dir/sim.log"; exit 1; }
  "$ctl" open Safari > /dev/null
  "$ctl" open Notes > /dev/null
}

echo "watch, from hello to quitting"
start_server
"$ctl" watch > "$dir/all.jsonl" 2> "$dir/all.err" &
all=$!
"$ctl" watch view | grep --line-buffered '^{"event":"view"' > "$dir/view.jsonl" &
check "hello arrives at once, in a file" eventually has "$dir/all.jsonl" '^{"event":"hello","protocol":1,'
"$ctl" dock 101 left > /dev/null
"$ctl" zoom 101 > /dev/null
check "a move of the view arrives while arborctl is still running" eventually has "$dir/all.jsonl" '"kind":"window","label":"Safari","node":1,"outOfView":1,"windows":\[101\]'
check "and through a pipe" eventually has "$dir/view.jsonl" '"kind":"window","label":"Safari","node":1,"outOfView":1,"windows":\[101\]'
check "arborctl is still watching" running "$all"
check "no titles unless asked for" lacks "$dir/all.jsonl" title
"$ctl" pause > /dev/null
check "a pause is reported" eventually has "$dir/all.jsonl" '^{"event":"paused"}'
check "and ends no watch" running "$all"
"$ctl" resume > /dev/null
check "nor does resuming" eventually has "$dir/all.jsonl" '^{"event":"resumed"}'
"$ctl" show-all > /dev/null
check "and the events go on" eventually has "$dir/all.jsonl" '"kind":"everything","label":"everything"'
"$ctl" quit > /dev/null
check "quit succeeds" is $? 0
exit_code_of "$all"
check "watch exits with 0 when Arbor quits" is "$code" 0
check "the last line is quitting" is "$(tail -n 1 "$dir/all.jsonl")" '{"event":"quitting"}'
check "nothing was complained about" is "$(cat "$dir/all.err")" ""
check "the filtered watcher saw view events only" is "$(grep -c -v '^{"event":"view"' "$dir/view.jsonl")" 0
# It was asked to quit. Should it not, this must not wait for ever on somebody's Mac.
eventually gone "$server" || kill -9 "$server" 2> /dev/null
wait "$server" 2> /dev/null
server=""

echo "exit codes"
"$ctl" watch > /dev/null 2> "$dir/err"
check "2 when Arbor is not running" is $? 2
check "and it says so" has "$dir/err" "not running"
"$ctl" status > /dev/null 2>&1
check "2 for any other command too" is $? 2
"$ctl" help > "$dir/out" 2>&1
check "but help needs no Arbor" is $? 0
start_server
out=$("$ctl" zoom 999 2> "$dir/err")
check "1 when Arbor says no" is $? 1
check "with nothing on standard output" is "$out" ""
check "and the reason on standard error" has "$dir/err" "arborctl: .*999"
out=$("$ctl" --json zoom 999 2> "$dir/err")
check "--json keeps the exit code" is $? 1
check "and puts the whole reply on standard output" is "${out##*,}" '"ok":false}'
out=$("$ctl" status 2> "$dir/err")
check "0 when it says yes, with the answer on standard output" is "$?: ${out%%:*}" "0: running"
"$ctl" watch views > "$dir/out" 2> "$dir/err"
check "1 for an event that does not exist" is $? 1
check "and it lists the ones that do" has "$dir/err" "the events are hello, displays, window, layout, view, focus"
"$ctl" zoom 999 2>&-
check "1 when Arbor says no and nobody reads standard error, not a crash" is $? 1
"$ctl" watch --titles > "$dir/titles.jsonl" 2> "$dir/err" &
titles=$!
check "titles when asked for" eventually has "$dir/titles.jsonl" '"title":"Safari 101"'

echo "clients that misbehave"
# Nothing happens after hello, so arborctl has nothing to write that would tell it that head has left.
("$ctl" watch; echo "exit code $?" > "$dir/head.code") | head -n 1 > "$dir/head" &
check "a watcher whose reader leaves does too, with 0" eventually has "$dir/head.code" '^exit code 0$'
check "and the reader got its line" has "$dir/head" '^{"event":"hello"'
# Ask for a long reply and leave without reading it; connect and say nothing.
python3 - "$ARBOR_SOCKET" <<'EOF' || failed=1
import socket, sys
for request in (b"state\n", b"watch\n", b"help\n", b"sta", b""):
    for _ in range(20):
        client = socket.socket(socket.AF_UNIX)
        client.connect(sys.argv[1])
        client.sendall(request)
        client.close()
silent = socket.socket(socket.AF_UNIX)
silent.connect(sys.argv[1])
silent.settimeout(10)
assert silent.recv(1) == b"", "a client that says nothing should be hung up on"
EOF
check "the server outlives clients that leave without reading or never speak" answers
# A watcher that never reads, while the view moves until the server gives up on it.
python3 - "$ARBOR_SOCKET" "$ctl" <<'EOF' || failed=1
import errno, socket, subprocess, sys, time
stuck = socket.socket(socket.AF_UNIX)
stuck.setsockopt(socket.SOL_SOCKET, socket.SO_RCVBUF, 4096)
stuck.connect(sys.argv[1])
stuck.sendall(b"watch\n")
def send(line):
    client = socket.socket(socket.AF_UNIX)
    client.connect(sys.argv[1])
    client.sendall(line)
    try:
        client.shutdown(socket.SHUT_WR)
    except OSError as error:
        # The server has answered and hung up already. Linux does not mind; macOS says that the socket is not connected. The reply is
        # there to be read all the same. (Seen once in these 2000 on a hosted Mac.)
        if error.errno != errno.ENOTCONN:
            raise
    started = time.time()
    while client.recv(65536):
        pass
    return time.time() - started
send(b"dock 101 left\n")
slowest = max(send(b"zoom 101\n" if n % 2 else b"show-all\n") for n in range(2000))
assert slowest < 4, f"a command took {slowest:.2f} s while a watcher was stuck"
received = 0
stuck.settimeout(10)
while True:
    data = stuck.recv(65536)
    if not data:
        break
    received += len(data)
print(f"    the stuck watcher was hung up on {received} bytes in; the slowest command took {slowest * 1000:.0f} ms")
EOF
check "the server outlives a watcher that stops reading" answers
check "the well-behaved watcher is still served" running "$titles"

echo "Arbor goes away without a word"
kill -9 "$server"
wait "$server" 2> /dev/null
exit_code_of "$titles"
check "watch exits with 3" is "$code" 3
check "and it says so" has "$dir/err" "went away"
server=""

[ "$failed" -eq 0 ] && echo "watch smoke test passed" || echo "watch smoke test FAILED"
exit "$failed"
