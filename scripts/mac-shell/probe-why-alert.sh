#!/bin/bash
# release-tools-test.sh leaves macOS asking whether "Python" may find devices on local networks, though its stand-in for GitHub listens on
# 127.0.0.1 only. What in it asks? The steps go from the least suspect to the most; the first after which an alert is on screen is the one.
# The first step is the cure that is proposed; the last is the script itself, a control: by then there must be an alert, or this shows nothing.
# For GitHub's Macs only, which are thrown away: it takes pictures of the whole screen.
[ "${GITHUB_ACTIONS:-}" = true ] && [ "$(id -un)" = runner ] || { echo "skipped: for one of GitHub's Macs only"; exit 77; }
cd "$(dirname "$0")/../.." || exit 2
mkdir -p mac-shell
work=$(mktemp -d) || exit 2
alerts() { .build/mac-shell/pointer windows 2>/dev/null | grep -E " on (UserNotificationCenter|CoreServicesUIAgent|SecurityAgent|universalAccessAuthWarn|loginwindow)"; }
look() {
  sleep 3
  echo "-- after $1: $(alerts | wc -l | tr -d ' ') alert(s) on screen"
  # safe anywhere: the script has ended by now anywhere but on one of GitHub's Macs, where nobody has anything open
  screencapture -x "mac-shell/after-$1.png"
}
# serve <file.py>: starts it, asks it one thing over the loopback, stops it.
serve() {
  rm -f "$work/port"
  python3 "$1" "$work" & local server=$!
  for _ in $(seq 50); do [ -s "$work/port" ] && break; sleep 0.1; done
  echo "   answered: $(NO_PROXY=127.0.0.1 curl -s -m 5 "http://127.0.0.1:$(cat "$work/port")/")"
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

echo "python3 is $(command -v python3), $(python3 --version 2>&1); the Mac calls itself $(hostname | sed 's/[0-9A-Fa-f-]\{8,\}/…/g')"
look nothing
serve "$work/without-the-name.py"
look 1-a-server-that-does-not-ask-its-name
python3 -c 'import socket, time; t = time.time(); n = socket.getfqdn("127.0.0.1"); print("   getfqdn took %.2f s and ends in .%s" % (time.time() - t, n.rsplit(".", 1)[-1]))'
look 2-only-the-question-for-the-name
serve "$work/as-it-is.py"
look 3-the-server-as-it-is
./scripts/release-tools-test.sh > mac-shell/release-tools-test.log 2>&1
echo "   release-tools-test.sh: exit $?"
look 4-the-script-itself
alerts
# Can what is on screen be taken away again, for the script that comes next on this Mac?
killall UserNotificationCenter 2>&1 | sed 's/^/   /'
look 5-its-owner-ended
alerts
exit 0
