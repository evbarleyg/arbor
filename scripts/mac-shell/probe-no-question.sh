#!/bin/bash
# Do the release tools' test and serve.py, as they now bind, leave the screen as they found it? A watcher notes the moment an alert appears, and
# forty seconds of nothing follow each step. Last comes a control: Python's own server, which must raise the alert, or all this shows nothing.
# It does not ask every time, so it gets three tries. For GitHub's Macs only, which are thrown away: it takes a picture of the whole screen.
[ "${GITHUB_ACTIONS:-}" = true ] && [ "$(id -un)" = runner ] || { echo "skipped: for one of GitHub's Macs only"; exit 77; }
cd "$(dirname "$0")/../.." || exit 2
mkdir -p mac-shell
work=$(mktemp -d) || exit 2
began=$(date +%s)
at() { printf '%4d s  ' $(($(date +%s) - began)); }
alerts() { .build/mac-shell/pointer windows 2>/dev/null | grep -cE " on (UserNotificationCenter|CoreServicesUIAgent|SecurityAgent)"; }
( seen=0
  while [ ! -e "$work/done" ]; do
    now=$(alerts)
    [ "$now" = "$seen" ] || { at; echo "** WATCHER: $seen -> $now alert(s) on screen"; seen=$now; }
    sleep 0.5
  done ) &
watcher=$!
quiet() { sleep 40; at; echo "   forty seconds later: $(alerts) alert(s)"; }
echo "python3 is $(python3 --version 2>&1)"
at; echo "STEP 1: scripts/release-tools-test.sh as it now is"
from=$(date +%s)
./scripts/release-tools-test.sh > mac-shell/release-tools-test.log 2>&1
at; echo "   exit $?, $(($(date +%s) - from)) s, $(grep -c ✔ mac-shell/release-tools-test.log) ✔, $(grep -c ✘ mac-shell/release-tools-test.log) ✘"
quiet
at; echo "STEP 2: scripts/mac-shell/serve.py, asked for a file"
echo yes > "$work/file"
(cd "$work" && exec python3 "$OLDPWD/scripts/mac-shell/serve.py" 8765 > /dev/null 2>&1) & server=$!
for _ in $(seq 100); do answer=$(NO_PROXY=127.0.0.1 curl -s -m 2 http://127.0.0.1:8765/file) && break; sleep 0.1; done
at; echo "   answered: $answer"
kill "$server" 2>/dev/null; wait "$server" 2>/dev/null
quiet
clean=$(alerts)
for try in 1 2 3; do
  at; echo "CONTROL, try $try: python3 -m http.server --bind 127.0.0.1"
  (cd "$work" && exec python3 -m http.server 8766 --bind 127.0.0.1 > /dev/null 2>&1) & server=$!
  sleep 45
  kill "$server" 2>/dev/null; wait "$server" 2>/dev/null
  at; echo "   $(alerts) alert(s)"
  [ "$(alerts)" = 0 ] || break
done
control=$(alerts)
# safe anywhere: the script has ended by now anywhere but on one of GitHub's Macs, where nobody has anything open
screencapture -x mac-shell/at-the-end.png
: > "$work/done"; wait "$watcher" 2>/dev/null
echo "RESULT: after the two as they now are: $clean alert(s); after the control: $control"
[ "$clean" = 0 ] && [ "$control" != 0 ]
