// ax: does to a test window what a person does with its title-bar buttons, the Dock or ⌘H, for Mac
// shell scripts, and says what Accessibility reports about a process's windows.
//
// `pointer` moves the mouse and presses keys. Some things a person does have no fixed place to click (the
// traffic lights move between macOS versions, an accessory app has no Dock icon and no menu), so this
// tool asks for them through the same public API that assistive software uses. Arbor hears about them
// exactly as it would had a person done them: through its own Accessibility notifications.
//
// Compile it as lib.sh compiles pointer.swift: swiftc -O -swift-version 5. Needs Accessibility permission.

import AppKit
import ApplicationServices

let usage = """
  usage: ax <command>
    list <pid>                        id role subrole minimized full-screen x y w h, one line per window
    minimize <pid> <window> on|off    as the yellow button, and a click on the Dock's miniature
    fullscreen <pid> <window> on|off  as the green button
    close <pid> <window>              presses the red button
    hide <pid> | unhide <pid>         as ⌘H, and a click on the app's Dock icon
    activate <pid>                    brings the app to the front, as ⌘Tab or its Dock icon does
    frontmost                         the pid of the app in front
  """

func fail(_ message: String) -> Never {
  FileHandle.standardError.write(Data("ax: \(message)\n".utf8))
  exit(64)
}

/// The window-server number behind an Accessibility window; Arbor uses the same call (AXHelpers.swift).
@_silgen_name("_AXUIElementGetWindow")
func _AXUIElementGetWindow(_ element: AXUIElement, _ identifier: UnsafeMutablePointer<CGWindowID>) -> AXError

func attribute(_ element: AXUIElement, _ name: String) -> CFTypeRef? {
  var value: CFTypeRef?
  guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else { return nil }
  return value
}

func flag(_ element: AXUIElement, _ name: String) -> Bool {
  guard let value = attribute(element, name), CFGetTypeID(value) == CFBooleanGetTypeID() else { return false }
  return CFBooleanGetValue((value as! CFBoolean))
}

func windows(of pid: pid_t) -> [AXUIElement] {
  guard let value = attribute(AXUIElementCreateApplication(pid), "AXWindows") else { return [] }
  return (value as? [AnyObject] ?? []).compactMap { item in
    CFGetTypeID(item) == AXUIElementGetTypeID() ? (item as! AXUIElement) : nil
  }
}

func number(of window: AXUIElement) -> CGWindowID {
  var identifier = CGWindowID(0)
  return _AXUIElementGetWindow(window, &identifier) == .success ? identifier : 0
}

func frame(of window: AXUIElement) -> CGRect {
  var origin = CGPoint.zero
  var size = CGSize.zero
  if let value = attribute(window, "AXPosition"), CFGetTypeID(value) == AXValueGetTypeID() {
    AXValueGetValue(value as! AXValue, .cgPoint, &origin)
  }
  if let value = attribute(window, "AXSize"), CFGetTypeID(value) == AXValueGetTypeID() {
    AXValueGetValue(value as! AXValue, .cgSize, &size)
  }
  return CGRect(origin: origin, size: size)
}

let arguments = Array(CommandLine.arguments.dropFirst())
guard let command = arguments.first else { fail(usage) }

func pidArgument() -> pid_t {
  guard arguments.count > 1, let pid = pid_t(arguments[1]) else { fail(usage) }
  return pid
}

func windowArgument() -> AXUIElement {
  guard arguments.count > 2, let wanted = CGWindowID(arguments[2]) else { fail(usage) }
  guard let window = windows(of: pidArgument()).first(where: { number(of: $0) == wanted }) else {
    fail("process \(pidArgument()) lists no window \(wanted)")
  }
  return window
}

func switchArgument() -> Bool {
  guard arguments.count > 3, ["on", "off"].contains(arguments[3]) else { fail(usage) }
  return arguments[3] == "on"
}

func setFlag(_ name: String) {
  let on = switchArgument()
  let result = AXUIElementSetAttributeValue(windowArgument(), name as CFString, on ? kCFBooleanTrue : kCFBooleanFalse)
  if result != .success { fail("setting \(name) failed with AXError \(result.rawValue)") }
}

func application() -> NSRunningApplication {
  guard let app = NSRunningApplication(processIdentifier: pidArgument()) else { fail("no such process") }
  return app
}

switch command {
case "list":
  for window in windows(of: pidArgument()) {
    let rect = frame(of: window)
    let role = attribute(window, "AXRole") as? String ?? "-"
    let subrole = attribute(window, "AXSubrole") as? String ?? "-"
    print(
      number(of: window), role, subrole, flag(window, "AXMinimized") ? "minimized" : "-",
      flag(window, "AXFullScreen") ? "full-screen" : "-", Int(rect.minX), Int(rect.minY), Int(rect.width),
      Int(rect.height))
  }
case "minimize":
  setFlag("AXMinimized")
case "fullscreen":
  setFlag("AXFullScreen")
case "close":
  guard let value = attribute(windowArgument(), "AXCloseButton"), CFGetTypeID(value) == AXUIElementGetTypeID() else {
    fail("the window has no close button")
  }
  let result = AXUIElementPerformAction(value as! AXUIElement, "AXPress" as CFString)
  if result != .success { fail("pressing the close button failed with AXError \(result.rawValue)") }
case "hide", "unhide":
  // NSRunningApplication.hide() refuses for an accessory app; this is what System Events sets.
  let result = AXUIElementSetAttributeValue(
    AXUIElementCreateApplication(pidArgument()), "AXHidden" as CFString, command == "hide" ? kCFBooleanTrue : kCFBooleanFalse)
  if result != .success { fail("setting AXHidden failed with AXError \(result.rawValue)") }
case "activate":
  // Without the option macOS 14 and later leave a request from a background process unanswered.
  if !application().activate(options: [.activateIgnoringOtherApps]) { fail("the app did not accept the activation") }
case "frontmost":
  print(NSWorkspace.shared.frontmostApplication?.processIdentifier ?? 0)
default:
  fail(usage)
}
