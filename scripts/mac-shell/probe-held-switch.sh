#!/bin/bash
# With the view held, the person's own switch to a window that is out of view is turned away. How long after the click or the key does macOS report the window, how
# often, and does Arbor say once why nothing happened? And does it keep quiet where nobody picked anything? A probe, not a check (collab/BOARD.md, 1.71).
#
#   scripts/mac-shell/run.sh scripts/mac-shell/probe-held-switch.sh
#
# Arbor takes a focus report for the person's own doing if it comes within half a second of a click or a modifier key. Nobody had measured that on a Mac, and a pick in
# Mission Control is a click followed by an animation. So Reduce Motion, which GitHub's Macs come with, is switched OFF here (PROBE_REDUCE_MOTION=on leaves it).
# After each act: Arbor's own lines "hold: focus report for w…, N s after the last click or modifier key", what it sent back, and what it said on screen.
#
# The tool that reads the Dock and the way to a window's picture are probe-mission-control.sh's.
#
# Only on GitHub's Macs: it opens Mission Control and clicks in it, presses ⌘Tab, ⌘M and ⌘W, and changes an Accessibility setting.
source "$(dirname "$0")/lib.sh"
needs_throwaway_mac "open Mission Control and click on what it shows, press ⌘Tab, ⌘M and ⌘W, and switch Reduce Motion off"

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
if [ -n "${ARBOR_REHEARSAL:-}" ]; then
  # No AppKit, no Dock and no Mission Control there: it names no picture, and the rest of the script is rehearsed.
  mkdir -p "$(dirname "$DOCKTREE")"
  printf '#!/bin/bash\necho "no Dock in a rehearsal"\n' > "$DOCKTREE"
  chmod +x "$DOCKTREE"
else
  swiftc -O -swift-version 5 "$ARBOR_OUT/docktree.swift" -o "$DOCKTREE" > "$ARBOR_OUT/build-docktree.log" 2>&1 || {
    cat "$ARBOR_OUT/build-docktree.log"
    die "the tool that reads the Dock did not compile"
  }
fi

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
LOG_MARK=0
mark() { LOG_MARK=$(wc -l < "$ARBOR_HOME/arbor.log"); }
# account: what Arbor heard, did and said since the mark, and how often it spoke.
SAID=0
account() {
  tail -n "+$((LOG_MARK + 1))" "$ARBOR_HOME/arbor.log" | cut -c 12- | grep -E "hold: |said on |has the keyboard$" | tail -n 40 | sed 's/^/  log | /'
  SAID=$(tail -n "+$((LOG_MARK + 1))" "$ARBOR_HOME/arbor.log" | grep -c "said on .*the view is held")
  echo "  said on screen that the view is held: $SAID time(s); in front: $(pointer front 2>&1); W1 has the keyboard: $(is focused "$W1" > /dev/null 2>&1 && echo yes || echo no)"
}
# A hold of its own for each act: the line comes once for each app and hold.
hold_anew() {
  ctl release
  # shellcheck disable=SC2046
  click $(titlebar_of "$W1")
  sleep 1
  ctl zoom "$W1"
  ctl hold
  # Longer than any click or key counts for.
  sleep 2
  mark
}
said_is() { [ "$SAID" -eq "$1" ] || { echo "said $SAID time(s), not $1"; return 1; }; }

macos_reduce_motion "${PROBE_REDUCE_MOTION:-off}"

step "two apps, one window framed, four out of view"
ARBOR_TEST_WINDOWS_ARGS="--regular"
ARBOR_SECOND_APP=2
ARBOR_SECOND_APP_ARGS="--regular"
arbor_start 3 ARBOR_NO_HOTKEYS=0 ARBOR_NO_STATUS_ITEM=0
tw2 title "$V1" Other App One
tw2 title "$V2" Other App Two
sleep 3  # regular apps joining the Dock resize it, and with it every slot
ctl dock "$W1" left
ctl dock "$W2" right
ctl dock "$W3" beside "$W2" bottom
ctl dock "$V1" beside "$W1" bottom
summary

step "1. the other app comes forward by itself: no word"
hold_anew
tw2 activate "$V1"
sleep 3
account
check "nothing is said of an app that pushed itself forward" said_is 0
check "its window stays out of view" is parked "$V1"

step "2. ⌘Tab to it"
hold_anew
key cmd+tab
film 02-after-cmd-tab 6
sleep 2
account
check "it is said once" said_is 1
check "its window stays out of view" is parked "$V1"
check "W1 has the keyboard back" eventually is focused "$W1"

step "3. a pick in Mission Control: a window of the other app"
hold_anew
mission_control 03-held
read -r px py <<< "$(picture_of 03-held "Other App One")"
if [ -n "${py:-}" ]; then
  mark
  click "$px" "$py"
  film 03-after-the-pick 8
  sleep 2
  account
  check "it is said once" said_is 1
  check "its window stays out of view" is parked "$V1"
else
  echo "the Dock names no picture of Other App One: nothing to click on"
  key escape
fi
sleep 1

step "4. a pick in Mission Control: another window of the app in front"
hold_anew
mission_control 04-held
read -r px py <<< "$(picture_of 04-held "Arbor Test 3")"
if [ -n "${py:-}" ]; then
  mark
  click "$px" "$py"
  film 04-after-the-pick 8
  sleep 2
  account
  check "it is said once" said_is 1
  check "its window stays out of view" is parked "$W3"
else
  echo "the Dock names no picture of Arbor Test 3: nothing to click on"
  key escape
fi
sleep 1

step "5. twice within five seconds: where is the keyboard then?"
hold_anew
for round in 1 2; do
  mission_control "05-held-$round"
  read -r px py <<< "$(picture_of "05-held-$round" "Other App One")"
  if [ -n "${py:-}" ]; then click "$px" "$py"; else key escape; fi
  sleep 0.8
done
sleep 2
account
echo "  Other App One has the keyboard: $(is focused "$V1" > /dev/null 2>&1 && echo yes || echo no); is it in view: $(is on_screen "$V1" > /dev/null 2>&1 && echo yes || echo no)"
shot 05-after-two-picks

step "6. ⌘M on the window in view: macOS hands the keyboard on, and nobody picked anything"
hold_anew
key cmd+m
sleep 3
account
check "nothing is said" said_is 0
shot 06-after-cmd-m
tw restore "$W1"
sleep 2

step "7. ⌘W on the window in view"
hold_anew
key cmd+w
sleep 3
account
check "nothing is said" said_is 0
shot 07-after-cmd-w
ctl release

arbor_stop 08-quit
