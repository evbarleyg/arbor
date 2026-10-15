#!/bin/bash
# Mission Control with windows out of view, as a person's Mac comes: motion on, real apps. A film, not a check (collab/BOARD.md, 0.11; IDEAS I17).
#
#   scripts/mac-shell/run.sh scripts/mac-shell/film-mission-control.sh
#
# probe-mission-control.sh showed on a hosted Mac on 2026-10-15 that Mission Control and the app's windows (⌃↓) show every window that Arbor keeps out of view, whole, and that a
# pick there frames it in one move. But Reduce Motion was on, as hosted Macs come, so Mission Control faded; and the windows were one app's test windows. With motion a person sees windows
# fly out of the display's corner and back into it. This films that: five stock apps docked, one framed; Mission Control coming up, going away by ⎋, and going away by a
# pick of a window that is out of view.
source "$(dirname "$0")/lib-apps.sh"
needs_throwaway_mac "switch Reduce Motion off, open Mission Control and click on what it shows"

apps_build
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


dock_says() {
  # Without the titles: these are real apps' windows.
  limit 20 "$DOCKTREE" 2>&1 | sed 's/"[^"]*"/""/g' > "$ARBOR_OUT/$1.txt"
  echo "what the Dock says of windows' pictures ($1.txt): role, size"
  awk '$2 == "AXButton" && $(NF - 1) > 60 { print "  " $(NF - 3), $(NF - 2), $(NF - 1), $NF }' "$ARBOR_OUT/$1.txt"
}
# The middle of the smallest picture: with one window framed, that is one of those that are out of view. No title is printed or kept: these are real apps' windows.
smallest_picture() { awk '$2 == "AXButton" && $(NF - 1) > 60 { print $(NF - 1) * $NF, int($(NF - 3) + $(NF - 1) / 2), int($(NF - 2) + $NF / 2) }' "$ARBOR_OUT/$1.txt" | sort -n | head -n 1 | cut -d ' ' -f 2-; }
at_exit 'macos_reduce_motion on > /dev/null'

step "motion on, five stock apps"
macos_reduce_motion off
apps_scratch
pids=""
FIRST=""
for app in "com.apple.finder $APPS_SCRATCH/grove" "com.apple.Safari $APPS_SCRATCH/page.html" "com.apple.TextEdit $APPS_SCRATCH/oak.txt" "com.apple.Preview $APPS_SCRATCH/leaf.png" com.apple.Terminal; do
  # shellcheck disable=SC2086
  if app_open $app; then pids="$pids $APP_PID"; FIRST=${FIRST:-$APP_WINDOW}; else echo "NOTE: ${app%% *} gave no window"; fi
done
[ -n "$FIRST" ] || die "no app gave a window"
# shellcheck disable=SC2086
arbor_start_apps $pids ARBOR_NO_HOTKEYS=0 ARBOR_NO_STATUS_ITEM=0
ctl arrange
sleep 2
brief
shot 01-arranged

step "everything in view: Mission Control comes and goes"
"$ARBOR_POINTER" key ctrl+up
film 02-all-in-view-coming 10
dock_says 02-all-in-view
"$ARBOR_POINTER" key escape
film 03-all-in-view-going 8
sleep 1

step "one framed, the others out of view: Mission Control comes and goes"
ctl zoom "$FIRST"
sleep 2
brief
shot 04-framed
"$ARBOR_POINTER" key ctrl+up
film 05-out-of-view-coming 12
dock_says 05-out-of-view
"$ARBOR_POINTER" key escape
film 06-out-of-view-going 12
sleep 1
brief

step "a pick of a window that is out of view"
"$ARBOR_POINTER" key ctrl+up
sleep 2
dock_says 07-before-the-pick
read -r px py <<< "$(smallest_picture 07-before-the-pick)"
if [ -n "${py:-}" ]; then
  "$ARBOR_POINTER" click "$px" "$py"
  film 08-after-the-pick 14
  sleep 1.5
  shot 09-settled
  brief
else
  echo "the Dock names no picture"
  "$ARBOR_POINTER" key escape
fi

arbor_stop 10-quit
# shellcheck disable=SC2086
for pid in $pids; do app_quit "$pid"; done
