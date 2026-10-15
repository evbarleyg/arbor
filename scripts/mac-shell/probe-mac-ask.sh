#!/bin/bash
# Leaves a question of macOS's on the screen, as a script once did without knowing: scripts/ci-mac-shell.sh is to name it, picture it and take it away.
source "$(dirname "$0")/lib.sh"
needs_throwaway_mac "would make macOS ask whether Python may find devices on local networks, and leave the question on the screen"
arbor_build
step "asking for this machine's name until macOS asks back"
questions() { "$ARBOR_POINTER" windows | grep -cE " on UserNotificationCenter$"; }
for try in 1 2 3 4 5 6; do
  # It does not ask back every time. The question for the name can take 35 s; the alert is up after three.
  python3 -c 'import socket; socket.getfqdn("127.0.0.1")' &
  sleep 6
  echo "try $try: $(questions) on the screen"
  [ "$(questions)" = 0 ] || break
done
echo "left on the screen: $(questions)"
