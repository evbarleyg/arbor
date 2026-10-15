#!/bin/bash
# release-tools-test.sh leaves macOS asking whether "Python" may find devices on local networks, though its stand-in for GitHub listens on
# 127.0.0.1 only. What in it asks? Second try. The first looked three seconds after each step, and an alert that takes longer than that to
# come up is then put down to the step after. So: a watcher notes the moment the alert appears, and each step is followed by forty seconds
# of nothing. The steps go from the least suspect to the most; the first is the cure that is proposed, the last a control.
# For GitHub's Macs only, which are thrown away: it takes a picture of the whole screen.
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
# serve <file.py>: starts it, says how long it took to listen, asks it one thing over the loopback, stops it.
serve() {
  rm -f "$work/port"
  python3 "$1" "$work" & local server=$! tenths=0
  while [ ! -s "$work/port" ] && [ "$tenths" -lt 400 ]; do sleep 0.1; tenths=$((tenths + 1)); done
  at; echo "   listening after about $((tenths / 10)).$((tenths % 10)) s"
  [ -s "$work/port" ] && { at; echo "   answered: $(NO_PROXY=127.0.0.1 curl -s -m 5 "http://127.0.0.1:$(cat "$work/port")/")"; }
  kill "$server" 2>/dev/null
  wait "$server" 2>/dev/null
}
handler='
import http.server, socketserver, sys
class Handler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        self.send_response(200); self.end_headers(); self.wfile.write(b"yes")
    def log_message(self, *a): pass
def go(server):
    open(sys.argv[1] + "/port", "w").write(str(server.server_address[1]))
    server.serve_forever()
'
printf '%s\n' "$handler" '
class Quiet(http.server.HTTPServer):
    def server_bind(self):  # as HTTPServer does it, but for the look-up of its own name
        socketserver.TCPServer.server_bind(self)
        self.server_name, self.server_port = self.server_address[:2]
go(Quiet(("127.0.0.1", 0), Handler))' > "$work/without-the-name.py"
printf '%s\n' "$handler" 'go(http.server.HTTPServer(("127.0.0.1", 0), Handler))' > "$work/as-it-is.py"

echo "python3 is $(command -v python3), $(python3 --version 2>&1)"
echo "What this Python's HTTPServer does when it binds, and what getfqdn does:"
python3 -c 'import http.server, inspect, socket; print(inspect.getsource(http.server.HTTPServer.server_bind)); print(inspect.getsource(socket.getfqdn))' | grep -vE '^\s*$|^\s+"""|^\s+[A-Z][a-z].*[a-z.,]$' | sed 's/^/    /'
at; echo "STEP 1: a server that does not ask its name, and one question to it over the loopback"
serve "$work/without-the-name.py"; quiet
at; echo "STEP 2: only the question for the name"
python3 -c 'import socket, time; t = time.time(); n = socket.getfqdn("127.0.0.1"); print("           getfqdn took %.2f s and ends in .%s" % (time.time() - t, n.rsplit(".", 1)[-1]))'; quiet
at; echo "STEP 3: the server as it is"
serve "$work/as-it-is.py"; quiet
# safe anywhere: the script has ended by now anywhere but on one of GitHub's Macs, where nobody has anything open
screencapture -x mac-shell/at-the-end.png
: > "$work/done"; wait "$watcher" 2>/dev/null
echo "What macOS wrote down about asking (times are the Mac's; the script began at $(date -r "$began" +%T)):"
log show --last 4m --style compact --predicate '(eventMessage CONTAINS[c] "local network" OR eventMessage CONTAINS[c] "LocalNetwork") AND (eventMessage CONTAINS[c] "python" OR process == "nehelper" OR process == "UserNotificationCenter")' 2>/dev/null \
  | tail -n 30 | cut -c 1-300 | sed -E 's/[0-9a-f]{8}-[0-9a-f-]{27}/<uuid>/Ig'
exit 0
