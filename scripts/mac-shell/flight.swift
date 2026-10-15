// flight: watches one window on its way to the Dock from three sides at once, and can do to it what Arbor's `focus` does.
//
// A window that is minimized flies for half a second. Its app names its next window as focused at some point, and says
// "miniaturized" at some point. In between somebody may ask for the keyboard to go back to the window that is flying, and it has been seen
// to come straight back out of the Dock. What can be known of a window in flight, by whom, and how soon? Which call fetches it back?
//
//   flight <pid> <window id> <seconds> <mode>
//
// Modes. All of them print the notifications of the app and what the window server says of the window, every 4 ms.
//   poll      also reads AXMinimized every 4 ms, from a thread of its own, and prints each change and each slow answer; and before each
//             read the same of another window of the app: does the whole app wait, or the window?
//   sparse    the same every 50 ms: a dense poll may itself hold the app up
//   read      at the first AXFocusedWindowChanged that names another window: reads AXMinimized once, of the other window and then of this one
//   main      … sets AXMain
//   raise     … performs AXRaise
//   both      … AXMain, then AXRaise: Arbor's `focus` within one app
//   guarded   … reads AXMinimized, and only if the answer is not yes: AXMain, then AXRaise
//   late      … waits 100 ms, then as guarded
//   rest-main, rest-raise   half a second after "miniaturized", with the window at rest in the Dock: AXMain, or AXRaise
//
// One line per fact: milliseconds since the start, who says it, what. It reads no title. Needs Accessibility.

import AppKit
import ApplicationServices

@_silgen_name("_AXUIElementGetWindow")
func _AXUIElementGetWindow(_ element: AXUIElement, _ identifier: UnsafeMutablePointer<CGWindowID>) -> AXError

let began = ProcessInfo.processInfo.systemUptime
func elapsed() -> Double { (ProcessInfo.processInfo.systemUptime - began) * 1000 }
let printing = NSLock()
func say(_ who: String, _ what: String, at time: Double? = nil) {
  printing.lock()
  print(String(format: "%8.1f  %@  %@", time ?? elapsed(), who, what))
  fflush(stdout)
  printing.unlock()
}

func number(of element: AXUIElement) -> CGWindowID {
  var identifier = CGWindowID(0)
  return _AXUIElementGetWindow(element, &identifier) == .success ? identifier : 0
}

/// yes, no, or the error's number.
func minimized(_ window: AXUIElement) -> String {
  var value: CFTypeRef?
  let error = AXUIElementCopyAttributeValue(window, "AXMinimized" as CFString, &value)
  guard error == .success, let value, CFGetTypeID(value) == CFBooleanGetTypeID() else { return "error \(error.rawValue)" }
  return CFBooleanGetValue((value as! CFBoolean)) ? "yes" : "no"
}

let arguments = Array(CommandLine.arguments.dropFirst())
let modes = ["poll", "sparse", "read", "main", "raise", "both", "guarded", "late", "rest-main", "rest-raise"]
func fail(_ code: Int32, _ message: String) -> Never {
  FileHandle.standardError.write(Data("flight: \(message)\n".utf8))
  exit(code)
}
func needed<T>(_ value: T?) -> T {
  guard let value else { fail(64, "usage: flight <pid> <window id> <seconds> \(modes.joined(separator: "|"))") }
  return value
}
// Not `guard let`: what that binds at the top of a file is no global, and the observer's callback, a C function, could not use it.
let pid: pid_t = needed(arguments.count == 4 ? pid_t(arguments[0]) : nil)
let id: CGWindowID = needed(CGWindowID(arguments[1]))
let seconds: Double = needed(Double(arguments[2]))
let mode: String = needed(modes.contains(arguments[3]) ? arguments[3] : nil)

let app = AXUIElementCreateApplication(pid)
let elements: [AXUIElement] = {
  var listed: CFTypeRef?
  AXUIElementCopyAttributeValue(app, "AXWindows" as CFString, &listed)
  return (listed as? [AnyObject] ?? []).filter { CFGetTypeID($0) == AXUIElementGetTypeID() }.map { $0 as! AXUIElement }
}()
let window: AXUIElement = {
  guard let found = elements.first(where: { number(of: $0) == id }) else { fail(65, "process \(pid) lists no window \(id)") }
  return found
}()
let sibling = elements.first { number(of: $0) != id }
// As Arbor has it (AXWindowSystem.messagingTimeout).
AXUIElementSetMessagingTimeout(app, 1)
AXUIElementSetMessagingTimeout(window, 1)

/// Does `what`, says how long it took and what came of it.
func timed(_ name: String, _ what: () -> String) -> String {
  let start = elapsed()
  let answer = what()
  say("probe ", String(format: "%@ -> %@, asked at %.1f, %.1f ms", name, answer, start, elapsed() - start))
  return answer
}
func setMain() { _ = timed("set AXMain") { "error \(AXUIElementSetAttributeValue(window, "AXMain" as CFString, kCFBooleanTrue).rawValue)" } }
func raise() { _ = timed("AXRaise") { "error \(AXUIElementPerformAction(window, "AXRaise" as CFString).rawValue)" } }
func guarded() {
  if timed("read AXMinimized", { minimized(window) }) == "yes" {
    say("probe ", "left alone")
  } else {
    setMain()
    raise()
  }
}

var acted = false
func act() {
  guard !acted, !mode.hasPrefix("rest-") else { return }
  acted = true
  switch mode {
  case "read":
    if let sibling { _ = timed("read AXMinimized of the other window") { minimized(sibling) } }
    _ = timed("read AXMinimized") { minimized(window) }
  case "main": setMain()
  case "raise": raise()
  case "both":
    setMain()
    raise()
  case "guarded": guarded()
  case "late": DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { guarded() }
  default: break
  }
}

func callback(_ observer: AXObserver, _ element: AXUIElement, _ notification: CFString, _ refcon: UnsafeMutableRawPointer?) {
  let name = notification as String
  let about = refcon.map { CGWindowID(truncatingIfNeeded: UInt(bitPattern: $0)) } ?? number(of: element)
  say("app   ", "\(name) w\(about)")
  if name == "AXFocusedWindowChanged", about != id { act() }
  if name == "AXWindowMiniaturized", mode.hasPrefix("rest-"), !acted {
    acted = true
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { if mode == "rest-main" { setMain() } else { raise() } }
  }
}
let observer: AXObserver = {
  var created: AXObserver?
  guard AXObserverCreate(pid, callback, &created) == .success, let created else { fail(66, "cannot observe process \(pid)") }
  return created
}()
for name in ["AXFocusedWindowChanged", "AXMainWindowChanged", "AXApplicationActivated", "AXApplicationDeactivated"] {
  AXObserverAddNotification(observer, app, name as CFString, nil)
}
for name in ["AXWindowMiniaturized", "AXWindowDeminiaturized", "AXMoved", "AXResized", "AXUIElementDestroyed"] {
  AXObserverAddNotification(observer, window, name as CFString, UnsafeMutableRawPointer(bitPattern: UInt(id)))
}
CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .defaultMode)

// The window server, which answers whatever the app is busy with.
Thread.detachNewThread {
  var last = ""
  while true {
    var now = "not listed"
    if let list = CGWindowListCopyWindowInfo([.optionIncludingWindow], id) as? [[String: Any]], let info = list.first {
      let shown = (info[kCGWindowIsOnscreen as String] as? NSNumber)?.boolValue ?? false
      let alpha = (info[kCGWindowAlpha as String] as? NSNumber)?.doubleValue ?? -1
      var bounds = CGRect.zero
      if let dictionary = info[kCGWindowBounds as String] as? NSDictionary {
        bounds = CGRect(dictionaryRepresentation: dictionary as CFDictionary) ?? .zero
      }
      now = String(
        format: "%@ alpha %.2f at %d,%d %dx%d", shown ? "on screen" : "off screen", alpha, Int(bounds.minX), Int(bounds.minY),
        Int(bounds.width), Int(bounds.height))
    }
    if now != last { say("server", now) }
    last = now
    usleep(4000)
  }
}

if mode == "poll" || mode == "sparse" {
  Thread.detachNewThread {
    var last = ""
    while true {
      if let sibling {
        let start = elapsed()
        let answer = minimized(sibling)
        let took = elapsed() - start
        if took > 10 { say("asked ", String(format: "the other window's AXMinimized %@, asked at %.1f, %.1f ms", answer, start, took)) }
      }
      let start = elapsed()
      let now = minimized(window)
      let took = elapsed() - start
      if now != last || took > 10 { say("asked ", String(format: "AXMinimized %@, asked at %.1f, %.1f ms", now, start, took)) }
      last = now
      usleep(mode == "poll" ? 4000 : 50000)
    }
  }
}

// Keys and buttons, as the window server counts them: when the hand did it.
Thread.detachNewThread {
  var wasRecent = false
  while true {
    let key = CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: .keyDown)
    let button = CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: .leftMouseUp)
    let recent = min(key, button) < 0.05
    if recent, !wasRecent { say("hand  ", String(format: "a key went down %.0f ms ago, a button came up %.0f ms ago", key * 1000, button * 1000)) }
    wasRecent = recent
    usleep(4000)
  }
}

say("flight", "watching w\(id) of \(pid), mode \(mode); AXMinimized \(minimized(window))")
DispatchQueue.main.asyncAfter(deadline: .now() + seconds) {
  say("flight", "the end: AXMinimized \(minimized(window))")
  exit(0)
}
let application = NSApplication.shared
application.setActivationPolicy(.prohibited)
application.run()
