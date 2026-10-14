// axwatch: prints what macOS tells an Accessibility client about some processes' windows, in the order
// and at the times it arrives. It subscribes to everything AXWindowSystem subscribes to and to the
// notifications it could subscribe to, so that a Mac shell script can write down what really follows a
// move, a focus change, a minimize, ⌘H, a close, full screen. FakeWindowSystem is held to that record
// (scripts/mac-shell/events.sh; collab/evidence/ax-events.txt).
//
//   axwatch <pid> [<pid>…]      runs until it is killed; one line per event on stdout:
//   seconds  source  name  window  details
//
// Compile it as lib.sh compiles pointer.swift: swiftc -O -swift-version 5. Needs Accessibility permission.

import AppKit
import ApplicationServices

@_silgen_name("_AXUIElementGetWindow")
func _AXUIElementGetWindow(_ element: AXUIElement, _ identifier: UnsafeMutablePointer<CGWindowID>) -> AXError

let started = Date()

func say(_ source: String, _ name: String, _ window: String, _ details: String = "") {
  let seconds = String(format: "%8.3f", Date().timeIntervalSince(started))
  let button = NSEvent.pressedMouseButtons & 1 != 0 ? " [button down]" : ""
  print("\(seconds)  \(source)  \(name)  \(window)  \(details)\(button)")
  fflush(stdout)
}

func attribute(_ element: AXUIElement, _ name: String) -> CFTypeRef? {
  var value: CFTypeRef?
  guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else { return nil }
  return value
}

func flag(_ element: AXUIElement, _ name: String) -> Bool {
  guard let value = attribute(element, name), CFGetTypeID(value) == CFBooleanGetTypeID() else { return false }
  return CFBooleanGetValue((value as! CFBoolean))
}

func number(of element: AXUIElement) -> CGWindowID {
  var identifier = CGWindowID(0)
  return _AXUIElementGetWindow(element, &identifier) == .success ? identifier : 0
}

func frame(of window: AXUIElement) -> String {
  var origin = CGPoint.zero
  var size = CGSize.zero
  if let value = attribute(window, "AXPosition"), CFGetTypeID(value) == AXValueGetTypeID() {
    AXValueGetValue(value as! AXValue, .cgPoint, &origin)
  }
  if let value = attribute(window, "AXSize"), CFGetTypeID(value) == AXValueGetTypeID() {
    AXValueGetValue(value as! AXValue, .cgSize, &size)
  }
  return "\(Int(origin.x)),\(Int(origin.y)) \(Int(size.width))x\(Int(size.height))"
}

let appNotifications = [
  "AXWindowCreated", "AXFocusedWindowChanged", "AXMainWindowChanged", "AXApplicationActivated",
  "AXApplicationDeactivated", "AXApplicationHidden", "AXApplicationShown",
]
let windowNotifications = [
  "AXUIElementDestroyed", "AXMoved", "AXResized", "AXWindowMiniaturized", "AXWindowDeminiaturized", "AXTitleChanged",
]
var observers: [pid_t: AXObserver] = [:]
var watched = Set<CGWindowID>()

func watch(_ window: AXUIElement, pid: pid_t) {
  let id = number(of: window)
  guard id != 0, !watched.contains(id), let observer = observers[pid] else { return }
  watched.insert(id)
  // As in AXWindowSystem: the number travels with the subscription, because a destroyed element has none.
  let refcon = UnsafeMutableRawPointer(bitPattern: UInt(id))
  for name in windowNotifications { AXObserverAddNotification(observer, window, name as CFString, refcon) }
}

func callback(
  _ observer: AXObserver, _ element: AXUIElement, _ notification: CFString, _ refcon: UnsafeMutableRawPointer?
) {
  let name = notification as String
  var pid: pid_t = 0
  AXUIElementGetPid(element, &pid)
  let id = refcon.map { CGWindowID(truncatingIfNeeded: UInt(bitPattern: $0)) } ?? number(of: element)
  var details = ""
  switch name {
  case "AXMoved", "AXResized":
    details = frame(of: element) + (flag(element, "AXFullScreen") ? " full-screen" : "")
  case "AXWindowCreated":
    details = "\(attribute(element, "AXSubrole") as? String ?? "-") \(frame(of: element))"
    watch(element, pid: pid)
  case "AXFocusedWindowChanged", "AXMainWindowChanged":
    details = flag(element, "AXMinimized") ? "still minimized" : ""
  default:
    break
  }
  say("ax \(pid)", name, id == 0 ? "-" : "w\(id)", details)
}

let pids = CommandLine.arguments.dropFirst().compactMap { pid_t($0) }
guard !pids.isEmpty else {
  FileHandle.standardError.write(Data("usage: axwatch <pid> [<pid>…]\n".utf8))
  exit(64)
}

for pid in pids {
  var created: AXObserver?
  guard AXObserverCreate(pid, callback, &created) == .success, let observer = created else {
    say("axwatch", "cannot observe", "-", "pid \(pid)")
    continue
  }
  observers[pid] = observer
  let app = AXUIElementCreateApplication(pid)
  for name in appNotifications { AXObserverAddNotification(observer, app, name as CFString, nil) }
  CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .defaultMode)
  for item in (attribute(app, "AXWindows") as? [AnyObject] ?? []) where CFGetTypeID(item) == AXUIElementGetTypeID() {
    watch(item as! AXUIElement, pid: pid)
  }
}

let workspace = NSWorkspace.shared.notificationCenter
for name in [
  NSWorkspace.didActivateApplicationNotification, NSWorkspace.didDeactivateApplicationNotification,
  NSWorkspace.didHideApplicationNotification, NSWorkspace.didUnhideApplicationNotification,
  NSWorkspace.didLaunchApplicationNotification, NSWorkspace.didTerminateApplicationNotification,
  NSWorkspace.activeSpaceDidChangeNotification,
] {
  _ = workspace.addObserver(forName: name, object: nil, queue: .main) { note in
    let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
    say("workspace", name.rawValue, "-", app.map { "pid \($0.processIdentifier)" } ?? "")
  }
}

var drags = 0
_ = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .leftMouseUp, .leftMouseDragged]) { event in
  switch event.type {
  case .leftMouseDown:
    drags = 0
    say("mouse", "down", "-")
  case .leftMouseUp:
    say("mouse", "up", "-", "after \(drags) drag events")
  default:
    drags += 1
  }
}

say("axwatch", "watching", "-", "pids \(pids.map(String.init).joined(separator: " ")), windows \(watched.sorted().map(String.init).joined(separator: " "))")
let application = NSApplication.shared
application.setActivationPolicy(.prohibited)
application.run()
