#!/bin/bash
# Mission Control with windows out of view: what does it show of them, and what does Arbor do when one is picked there? A probe, not a check (collab/BOARD.md, 0.11).
#
#   scripts/mac-shell/run.sh scripts/mac-shell/probe-mission-control.sh
#
# A window that is not in the framed space lies at the display's corner with a point of it showing. Mission Control is how a person on any Mac finds a window
# they have lost sight of. So: five windows docked, one framed, four out of view. A picture of Mission Control, with everything in view first for comparison. Where
# the Dock, which draws it, says each window's picture is, and how large. Then a click on the picture of a window that is out of view, and what follows: who has the
# keyboard, where the view is, how often each window was moved (the trace has that).
#
# Only on GitHub's Macs: it opens Mission Control and clicks in it, on whatever lies there.
source "$(dirname "$0")/lib.sh"
needs_throwaway_mac "open Mission Control and click on what it shows"

arbor_build
# What the Dock tells Accessibility, which while Mission Control is up includes a button for each window's picture. In the script, as no other needs it.
DOCKTREE="$ARBOR_ROOT/.build/mac-shell/docktree"
cat > "$ARBOR_OUT/docktree.swift" <<'SWIFT'
import AppKit
import ApplicationServices

func attribute(_ element: AXUIElement, _ name: String) -> CFTypeRef? {
  var value: CFTypeRef?
  return AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success ? value : nil
}
func text(_ element: AXUIElement, _ name: String) -> String { (attribute(element, name) as? String) ?? "" }
func frame(_ element: AXUIElement) -> String {
  var point = CGPoint.zero, size = CGSize.zero
  guard let position = attribute(element, kAXPositionAttribute), let extent = attribute(element, kAXSizeAttribute),
    AXValueGetValue(position as! AXValue, .cgPoint, &point), AXValueGetValue(extent as! AXValue, .cgSize, &size)
  else { return "- - - -" }
  return "\(Int(point.x)) \(Int(point.y)) \(Int(size.width)) \(Int(size.height))"
}
func walk(_ element: AXUIElement, _ depth: Int) {
  let role = text(element, kAXRoleAttribute)
  // The Dock's own row of icons is not what is asked about.
  if role == "AXList" && depth <= 1 { return }
  print(
    "\(depth) \(role) \(text(element, kAXSubroleAttribute).isEmpty ? "-" : text(element, kAXSubroleAttribute)) "
      + "[\(text(element, kAXIdentifierAttribute))] \"\(text(element, kAXTitleAttribute))\" \"\(text(element, kAXDescriptionAttribute))\" \(frame(element))")
  guard depth < 9, let children = attribute(element, kAXChildrenAttribute) as? [AXUIElement] else { return }
  for child in children { walk(child, depth + 1) }
}
guard let dock = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dock").first else {
  print("no Dock")
  exit(1)
}
walk(AXUIElementCreateApplication(dock.processIdentifier), 0)
SWIFT
swiftc -O -swift-version 5 "$ARBOR_OUT/docktree.swift" -o "$DOCKTREE" > "$ARBOR_OUT/build-docktree.log" 2>&1 || {
  cat "$ARBOR_OUT/build-docktree.log"
  die "the tool that reads the Dock did not compile"
}

# mission_control <name>: up, a picture, and what the Dock says, kept in <name>.txt.
mission_control() {
  key ctrl+up
  sleep 2
  shot "$1"
  limit 20 "$DOCKTREE" > "$ARBOR_OUT/$1.txt" 2>&1
  echo "what the Dock says of windows' pictures ($(grep -c . "$ARBOR_OUT/$1.txt") lines in $1.txt):"
  grep "Arbor Test" "$ARBOR_OUT/$1.txt" | sed 's/^/  /'
}
# picture_of <name> <title>: x y of the middle of that window's picture.
picture_of() { grep "\"$2\"" "$ARBOR_OUT/$1.txt" | awk '{ n = NF; if ($(n - 1) > 0) { print int($(n - 3) + $(n - 1) / 2), int($(n - 2) + $n / 2); exit } }'; }
where_all() {
  summary
  for id in "$W1" "$W2" "$W3" "$W4" "$W5"; do
    echo "  window $id: the window server has it at $(real_frame_of "$id"); on a display: $(pointer visible "$id")"
  done
  echo "  in front: $(pointer front 2>&1)"
}
LOG_MARK=0
log_since() {
  tail -n "+$((LOG_MARK + 1))" "$ARBOR_HOME/arbor.log" | cut -c 26- | tail -n "${1:-30}" | sed 's/^/  log | /'
  LOG_MARK=$(wc -l < "$ARBOR_HOME/arbor.log")
}

step "five windows docked, shortcuts on"
ARBOR_TEST_WINDOWS_ARGS="--regular"
arbor_start 5 ARBOR_NO_HOTKEYS=0 ARBOR_NO_STATUS_ITEM=0
ctl arrange
sleep 3  # a regular app joining the Dock resizes it, and with it every slot
where_all

step "for comparison: Mission Control with everything in view"
mission_control 01-everything-in-view
key escape
sleep 1.5
settled

step "one framed, four out of view: what Mission Control shows of them"
ctl zoom "$W1"
sleep 1
where_all
shot 02-framed
log_since 0 > /dev/null
mission_control 03-four-out-of-view
log_since 20
key escape
sleep 1.5
echo "after ⎋:"
where_all
log_since 20

step "a click on the picture of a window that is out of view"
mission_control 04-before-the-click
read -r px py <<< "$(picture_of 04-before-the-click "Arbor Test 3")"
if [ -n "${py:-}" ]; then
  echo "the picture of Arbor Test 3 is at $px $py"
  click "$px" "$py"
  film 05-after-the-click 8
  sleep 1.5
  shot 06-settled
  where_all
  log_since 40
  echo "is window 3 in view? $(is on_screen "$W3" > /dev/null 2>&1 && echo yes || echo no); has it the keyboard? $(is focused "$W3" > /dev/null 2>&1 && echo yes || echo no)"
else
  echo "the Dock names no picture of Arbor Test 3: nothing to click on"
  key escape
fi
sleep 1

step "the same with the view held, as on a shared screen"
ctl show-all
ctl zoom "$W1"
ctl hold
sleep 1
mission_control 07-held
read -r px py <<< "$(picture_of 07-held "Arbor Test 4")"
if [ -n "${py:-}" ]; then
  click "$px" "$py"
  film 08-held-after-the-click 8
  sleep 1.5
  where_all
  log_since 40
else
  key escape
fi
ctl release

step "⌃↓, the windows of the app in front, with four of them out of view"
ctl show-all
ctl zoom "$W1"
sleep 1
key ctrl+down
sleep 2
shot 09-app-windows
limit 20 "$DOCKTREE" | grep "Arbor Test" | sed 's/^/  /'
key escape
sleep 1

arbor_stop 10-quit
