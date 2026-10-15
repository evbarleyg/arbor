#!/usr/bin/env python3
"""Serves the folder it is started in on 127.0.0.1, for a script that needs something to answer over HTTP.

  python3 scripts/mac-shell/serve.py <port>

What Python's own module `http.server` does when it is started from the command line and bound to 127.0.0.1, but for one thing. Python's
HTTPServer asks the system what this machine is called when it binds (socket.getfqdn), and nothing uses the answer. macOS can take that
question for one about the local network: alone, on a hosted Mac, it took 35 s and left "Allow Python to find devices on local networks?" in
the middle of the screen. No script sees such an alert, and the real pointer presses it and not the window under it: half the checks of a
drag test failed for a night, and none of it was Arbor's doing. scripts/test-tooling.py sees to it that no script starts the server as it is.
"""

import http.server
import socketserver
import sys


class Server(http.server.ThreadingHTTPServer):
    def server_bind(self):
        socketserver.TCPServer.server_bind(self)
        self.server_name, self.server_port = self.server_address[:2]


if __name__ == "__main__":
    if len(sys.argv) != 2 or not sys.argv[1].isdigit():
        sys.exit(__doc__)
    Server(("127.0.0.1", int(sys.argv[1])), http.server.SimpleHTTPRequestHandler).serve_forever()
