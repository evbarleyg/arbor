#!/bin/bash
# Arbor from the outside: arborctl's replies and exit codes, the state as JSON, the drawing, and arbor:// URLs.
# A02 command line with JSON state and ASCII layout, T71 every action as a URL.
source "$(dirname "$0")/../lib.sh"
arbor_build

# From an app bundle, as installed: macOS delivers URLs to apps, not to bare executables.
if on_throwaway_mac; then ARBOR_BUNDLED=1; fi
arbor_start 3

claim "arborctl says what Arbor did and exits with 0, or why not and exits with 1"
proves A02
check "a command that works exits with 0" exits_with 0 arborctl dock "$W1" left
check "and the window is docked" eventually at_edge "$W1" left
check "it says what it did" says "docked" arborctl dock "$W2" right
check "a window Arbor does not know exits with 1" exits_with 1 arborctl dock 999999 left
check "it says why" says "no window w999999" arborctl dock 999999 left
check "an unknown command exits with 1" exits_with 1 arborctl frobnicate
check "it says so" says "unknown command" arborctl frobnicate
check "a command that cannot apply exits with 1" exits_with 1 arborctl view 7
check "status says how many windows it arranges" says "2 docked and 1 floating" arborctl status
check "help lists the commands" says "dock [window] beside <window> <edge>" arborctl help
check "no arguments mean help" says "Arbor commands" arborctl

claim "replies are in words, and a failure says what to do next"
proves A44
arborctl zoom "$W1" > /dev/null
echo "out: $(arborctl out)"
arborctl zoom "$W1" > /dev/null
check "a camera move says where it went" says "stepped out to everything" arborctl out
check "no reply speaks of nodes" fails says " n2" arborctl show-all
check "a view that is not saved says how to save it" says "save-view 7" arborctl view 7
check "a window Arbor does not know says where to look" says "\`state\` lists" arborctl zoom 999999
arborctl show-all > /dev/null

claim "arborctl state is JSON that agrees with the window server"
proves A02
arborctl state > "$ARBOR_SESSION_DIR/state.json"
check "it is one JSON object with ok, message and state" python3 -c '
import json, sys
reply = json.load(open(sys.argv[1]))
assert reply["ok"] is True and reply["message"] and reply["state"]["running"] and reply["state"]["accessibility"]
assert len(reply["state"]["displays"]) >= 1 and len(reply["state"]["windows"]) == 3
for window in reply["state"]["windows"]:
    assert window["bundleID"] == sys.argv[2] and window["title"].startswith("Arbor Test") and window["managed"]
' "$ARBOR_SESSION_DIR/state.json" "$ARBOR_TEST_BUNDLE"
# shellcheck disable=SC2046
check "the first window is where the state says" frame_is "$W1" $(frame_of "$W1")
# shellcheck disable=SC2046
check "the floating window too" frame_is "$W3" $(frame_of "$W3")
check "--json gives the raw reply of any command" says '"ok":true' arborctl --json zoom "$W1"
check "and of one that fails, still exiting with 0" says '"ok":false' arborctl --json dock 999999 left
arborctl show-all > /dev/null

claim "arborctl ascii draws the layout"
proves A02
arborctl ascii
check "the drawing names the docked windows" says "w$W1" arborctl ascii
check "and the Desktop" says "desktop" arborctl ascii
check "docked windows have boxes" says "+--" arborctl ascii

# Registering a bundle for arbor:// changes which app a person's own links open, so only on a throwaway Mac.
if on_throwaway_mac; then
  lsregister=/System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister
  [ -n "${ARBOR_REHEARSAL:-}" ] || "$lsregister" -f "$ARBOR_APP"

  claim "open an arbor:// URL: the running Arbor does what it says"
  proves T71
  open "arbor://zoom/$W2"
  check "arbor://zoom/<window> ran" eventually ran zoom "$W2"
  check "the window fills the screen" eventually fills "$W2"
  open "arbor://show-all"
  check "arbor://show-all ran" eventually ran show-all
  check "everything is in view" eventually in_view "$W1"
  open "arbor://dock/$W3/beside/$W1/bottom"
  check "a URL with several words ran" eventually ran dock "$W3" beside "$W1" bottom
  check "the window docked below the other" eventually above "$W1" "$W3"
  open "arbor://save-view/3"
  open "arbor://desktop"
  check "arbor://desktop ran" eventually ran desktop
  check "the windows left" eventually out_of_view "$W1"
  open "arbor://view/3"
  check "arbor://view/3 brought the saved view back" eventually in_view "$W1"
  open "arbor://zoom/$W1"
  check "the window fills the screen again" eventually fills "$W1"
  open "arbor://zoom-out"
  check "arbor://zoom-out, TrellisWM's spelling, stepped out" eventually ran out
  check "the window below it is back" eventually in_view "$W3"
  open "arbor://show-all"
  open "arbor://no-such-command"
  check "a URL that makes no sense is logged and ignored" eventually logged "refused a URL"
  open "arbor://quit"
  check "a URL may not quit Arbor" eventually logged "\`quit\` is not accepted from URLs"
  check "Arbor is still running" stays kill -0 "$ARBOR_PID"
  check "macOS did not start a second Arbor for them" test "$(pgrep -f "/Arbor.app/Contents/MacOS/Arbor" | wc -l | tr -d ' ')" -le 1
  settled
  [ -n "${ARBOR_REHEARSAL:-}" ] || "$lsregister" -u "$ARBOR_APP"
  # Should macOS have started one after all, it must not outlive the step: it would arrange everything.
  for other in $(pgrep -f "/Arbor.app/Contents/MacOS/Arbor"); do
    [ "$other" = "$ARBOR_PID" ] || kill -TERM "$other"
  done
fi

arbor_stop

ARBOR_BUNDLED=""
arbor_start 2
ctl dock "$W1" left
ctl zoom "$W1"

claim "a client that hangs up before Arbor replies does it no harm"
# The stand-ins have no socket.
[ -n "${ARBOR_REHEARSAL:-}" ] || python3 - "$ARBOR_SOCKET" <<'PYTHON'
import socket, sys
for _ in range(3):
    client = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    client.connect(sys.argv[1])
    client.sendall(b"state\n")
    client.close()
PYTHON
check "Arbor is still running" stays kill -0 "$ARBOR_PID"
check "and still answers" ctl status
check "a line that is no command gets an answer too" says "empty command" arborctl ""
arbor_stop

claim "arborctl without Arbor says so and exits with 2"
proves A02
check "the exit code is 2" exits_with 2 arborctl status
check "it says that Arbor is not running" says "Arbor is not running" arborctl status
check "and how to start it" says "start it with \`open -a Arbor\`" arborctl status
check "help needs no running Arbor" says "Arbor commands" arborctl help
check "and exits with 0" exits_with 0 arborctl help
