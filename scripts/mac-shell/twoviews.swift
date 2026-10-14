// twoviews: where Accessibility says some apps' windows are and where the window server has them, side by side and over time, with
// every notice that might announce that macOS itself has moved them.
//
// macOS can show the desktop by sweeping every window aside: a click on the wallpaper (macOS 14 and later, on as it comes), F11, a hot
// corner, a spread of the fingers. The window server moves the windows; the apps are not told. Arbor sees windows through
// Accessibility, which asks the apps. So this tool asks both, sixty times a second, and writes down each answer that changed, and
// listens meanwhile to whatever could serve as a sign: the apps' own Accessibility notifications, the Dock's and WindowManager's,
// the workspace's, and the notifications processes send to all. probe-sweep.sh plays the sweeps.
//
//   twoviews watch <log file> <pid>…     until it is killed
//   twoviews now <pid>…                  id | ax x y w h | server x y w h on|off: one line per window the apps list, now
//
// It only looks. It never reads a window's title. The log is in sampler.swift's grammar, `<milliseconds since 1970> <kind> …`, so
// that the two files can be merged by time; the kinds are its own:
//   X id x y w h            Accessibility's answer for the window changed (or `X id gone`)
//   C id x y w h on|off     the window server's did
//   N pid name id frame     an Accessibility notification of a watched app, with the frame Accessibility gives at that moment
//   E owner name            one of the Dock's or WindowManager's
//   K name pid              one of the workspace's
//   U name                  one that a process sent to all
//   R down|up               the left mouse button, as other apps hear of it
//   I text                  about the tool itself
//
// Compile it as lib.sh compiles pointer.swift: swiftc -O -swift-version 5. Needs Accessibility permission.

import AppKit
import ApplicationServices
import CoreGraphics
import Foundation

@_silgen_name("_AXUIElementGetWindow")
func _AXUIElementGetWindow(_ element: AXUIElement, _ identifier: UnsafeMutablePointer<CGWindowID>) -> AXError

func fail(_ message: String) -> Never {
  FileHandle.standardError.write(Data("twoviews: \(message)\n".utf8))
  exit(64)
}

func text(_ value: CGFloat) -> String {
  let number = Double(value)
  return number == number.rounded() ? String(Int(number)) : String(format: "%.1f", number)
}

func text(_ rect: CGRect) -> String {
  "\(text(rect.minX)) \(text(rect.minY)) \(text(rect.width)) \(text(rect.height))"
}

// MARK: The two views

func attribute(_ element: AXUIElement, _ name: String) -> CFTypeRef? {
  var value: CFTypeRef?
  guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else { return nil }
  return value
}

func number(of element: AXUIElement) -> CGWindowID {
  var identifier = CGWindowID(0)
  return _AXUIElementGetWindow(element, &identifier) == .success ? identifier : 0
}

func accessibilityFrame(of window: AXUIElement) -> CGRect? {
  var origin = CGPoint.zero
  var size = CGSize.zero
  guard let position = attribute(window, "AXPosition"), CFGetTypeID(position) == AXValueGetTypeID(),
    let extent = attribute(window, "AXSize"), CFGetTypeID(extent) == AXValueGetTypeID(),
    AXValueGetValue(position as! AXValue, .cgPoint, &origin), AXValueGetValue(extent as! AXValue, .cgSize, &size)
  else { return nil }
  return CGRect(origin: origin, size: size)
}

func windows(of pid: pid_t) -> [(id: CGWindowID, element: AXUIElement)] {
  let app = AXUIElementCreateApplication(pid)
  var found: [(id: CGWindowID, element: AXUIElement)] = []
  for item in (attribute(app, "AXWindows") as? [AnyObject] ?? []) where CFGetTypeID(item) == AXUIElementGetTypeID() {
    let element = item as! AXUIElement
    let id = number(of: element)
    if id != 0 { found.append((id, element)) }
  }
  return found
}

struct Served: Equatable {
  var frame: CGRect
  var isOnScreen: Bool
}

/// Every window there is, as the window server has it.
func served() -> [CGWindowID: Served] {
  var answer: [CGWindowID: Served] = [:]
  let list = (CGWindowListCopyWindowInfo([.optionAll], kCGNullWindowID) as NSArray?) ?? []
  for case let info as NSDictionary in list {
    guard let id = (info[kCGWindowNumber] as? NSNumber)?.uint32Value,
      let bounds = info[kCGWindowBounds] as? NSDictionary,
      let frame = CGRect(dictionaryRepresentation: bounds as CFDictionary)
    else { continue }
    answer[id] = Served(frame: frame, isOnScreen: (info[kCGWindowIsOnscreen] as? NSNumber)?.boolValue ?? false)
  }
  return answer
}

func text(_ served: Served?) -> String {
  guard let served else { return "gone" }
  return "\(text(served.frame)) \(served.isOnScreen ? "on" : "off")"
}

var arguments = Array(CommandLine.arguments.dropFirst())
guard let command = arguments.first else { fail("usage: twoviews watch <log file> <pid>… | now <pid>…") }
arguments.removeFirst()

if command == "now" {
  let list = served()
  for pid in arguments.compactMap({ pid_t($0) }) {
    for window in windows(of: pid).sorted(by: { $0.id < $1.id }) {
      print("\(window.id) | ax \(accessibilityFrame(of: window.element).map { text($0) } ?? "gone") | server \(text(list[window.id]))")
    }
  }
  exit(0)
}
guard command == "watch", arguments.count >= 2 else { fail("usage: twoviews watch <log file> <pid>… | now <pid>…") }

// MARK: The log

/// Not `guard let`: what that binds at the top of a file is no global, and the functions below could not use it.
let logFile: UnsafeMutablePointer<FILE> = {
  guard let file = fopen(arguments[0], "a") else { fail("cannot write to \(arguments[0])") }
  return file
}()
let pids = arguments.dropFirst().compactMap { pid_t($0) }

func write(_ line: String) {
  fputs("\(Int64(Date().timeIntervalSince1970 * 1000)) \(line)\n", logFile)
  fflush(logFile)
}

// MARK: Notices

let appNotifications = [
  "AXWindowCreated", "AXFocusedWindowChanged", "AXMainWindowChanged", "AXApplicationActivated", "AXApplicationDeactivated",
  "AXApplicationHidden", "AXApplicationShown",
]
let windowNotifications = [
  "AXUIElementDestroyed", "AXMoved", "AXResized", "AXWindowMiniaturized", "AXWindowDeminiaturized",
]
/// What the Dock is known to tell about Mission Control. Whether a click on the wallpaper counts is the question.
let exposeNotifications = ["AXExposeShowAllWindows", "AXExposeShowFrontWindows", "AXExposeShowDesktop", "AXExposeExit"]

var observers: [pid_t: AXObserver] = [:]
var owners: [pid_t: String] = [:]
var elements: [CGWindowID: AXUIElement] = [:]

func watch(_ window: AXUIElement, id: CGWindowID, pid: pid_t) {
  guard elements[id] == nil, let observer = observers[pid] else { return }
  elements[id] = window
  let refcon = UnsafeMutableRawPointer(bitPattern: UInt(id))
  for name in windowNotifications { AXObserverAddNotification(observer, window, name as CFString, refcon) }
}

func callback(
  _ observer: AXObserver, _ element: AXUIElement, _ notification: CFString, _ refcon: UnsafeMutableRawPointer?
) {
  let name = notification as String
  var pid: pid_t = 0
  AXUIElementGetPid(element, &pid)
  if let owner = owners[pid] {
    write("E \(owner) \(name)")
    return
  }
  let id = refcon.map { CGWindowID(truncatingIfNeeded: UInt(bitPattern: $0)) } ?? number(of: element)
  if name == "AXWindowCreated", id != 0 { watch(element, id: id, pid: pid) }
  write("N \(pid) \(name) \(id) \(accessibilityFrame(of: element).map { text($0) } ?? "-")")
}

func observe(_ pid: pid_t) -> AXObserver? {
  var created: AXObserver?
  guard AXObserverCreate(pid, callback, &created) == .success, let observer = created else { return nil }
  observers[pid] = observer
  CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .defaultMode)
  return observer
}

for pid in pids {
  guard let observer = observe(pid) else {
    write("I cannot observe \(pid)")
    continue
  }
  let app = AXUIElementCreateApplication(pid)
  for name in appNotifications { AXObserverAddNotification(observer, app, name as CFString, nil) }
  for window in windows(of: pid) { watch(window.element, id: window.id, pid: pid) }
}

for bundle in ["com.apple.dock", "com.apple.WindowManager", "com.apple.finder"] {
  guard let running = NSRunningApplication.runningApplications(withBundleIdentifier: bundle).first else {
    write("I no process of \(bundle)")
    continue
  }
  let pid = running.processIdentifier
  guard let observer = observe(pid) else {
    write("I cannot observe \(bundle)")
    continue
  }
  owners[pid] = bundle
  let app = AXUIElementCreateApplication(pid)
  for name in exposeNotifications + ["AXApplicationActivated", "AXApplicationDeactivated", "AXFocusedUIElementChanged"] {
    let code = AXObserverAddNotification(observer, app, name as CFString, nil)
    write("I \(bundle) (pid \(pid)) \(name): \(code == .success ? "subscribed" : "refused, \(code.rawValue)")")
  }
}

let workspace = NSWorkspace.shared.notificationCenter
for name in [
  NSWorkspace.didActivateApplicationNotification, NSWorkspace.didDeactivateApplicationNotification,
  NSWorkspace.didHideApplicationNotification, NSWorkspace.didUnhideApplicationNotification,
  NSWorkspace.activeSpaceDidChangeNotification,
] {
  _ = workspace.addObserver(forName: name, object: nil, queue: .main) { note in
    let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
    write("K \(name.rawValue) \(app.map { String($0.processIdentifier) } ?? "-")")
  }
}

// Names only. Since macOS 11 a process that asks for every name may be told nothing; then the log has no U line at all.
_ = DistributedNotificationCenter.default().addObserver(forName: nil, object: nil, queue: .main) { note in
  write("U \(note.name.rawValue)")
}

_ = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .leftMouseUp]) { event in
  write("R \(event.type == .leftMouseDown ? "down" : "up")")
}

// MARK: Asking both, again and again

var lastAccessibility: [CGWindowID: CGRect] = [:]
var lastServed: [CGWindowID: Served] = [:]
var ticks = 0

func look() {
  ticks += 1
  // A window that opened without a notice, once a second.
  if ticks % 60 == 0 {
    for pid in pids { for window in windows(of: pid) { watch(window.element, id: window.id, pid: pid) } }
  }
  let list = served()
  for (id, element) in elements.sorted(by: { $0.key < $1.key }) {
    let served = list[id]
    if served != lastServed[id] {
      lastServed[id] = served
      write("C \(id) \(text(served))")
    }
    guard served != nil else {
      elements[id] = nil
      lastAccessibility[id] = nil
      continue
    }
    let frame = accessibilityFrame(of: element)
    if frame != lastAccessibility[id] {
      lastAccessibility[id] = frame
      write("X \(id) \(frame.map { text($0) } ?? "gone")")
    }
  }
}

write("I watching \(pids.map { String($0) }.joined(separator: " ")): windows \(elements.keys.sorted().map { String($0) }.joined(separator: " "))")
Timer.scheduledTimer(withTimeInterval: 1.0 / 60, repeats: true) { _ in look() }

let application = NSApplication.shared
application.setActivationPolicy(.prohibited)
application.run()
