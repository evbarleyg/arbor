// takeback: asks for the keyboard for a window of another app and takes the request back at once, as Arbor does when ⌃⌥→ and ⌃⌥← are pressed in one roll of
// the fingers, and writes down what macOS makes of it.
//
// Arbor's `focus` makes the window its app's main window, raises it, and activates the app unless that app is in front already. Activation takes a few
// hundredths of a second. A second request, for a window of the app that is STILL in front, therefore activates nobody. Does the first activation
// land all the same? In which order do the reports come? Would activating the app in front again recall it?
//
//   takeback <pid A> <window A> <pid B> <window B> <mode>          A's app is in front and A has the keyboard
//
// Modes:
//   there        the keyboard is asked for B, and that is all: the control
//   back         … and at once for A, as Arbor's layer does it: main, raise, and no activation, because A's app is still in front
//   back-20, back-60, back-150     the same after that many milliseconds
//   recall       … and at once for A, with an activation of A's app whoever is in front
//   recall-20, recall-60           the same after that many milliseconds
//
// One line per fact for a second and a half: milliseconds since the start, who says it, what. It reads no title. Needs Accessibility.

import AppKit
import ApplicationServices

@_silgen_name("_AXUIElementGetWindow")
func _AXUIElementGetWindow(_ element: AXUIElement, _ identifier: UnsafeMutablePointer<CGWindowID>) -> AXError

let began = ProcessInfo.processInfo.systemUptime
func elapsed() -> Double { (ProcessInfo.processInfo.systemUptime - began) * 1000 }
let printing = NSLock()
func say(_ who: String, _ what: String) {
  printing.lock()
  print(String(format: "%8.1f  %@  %@", elapsed(), who, what))
  fflush(stdout)
  printing.unlock()
}

func number(of element: AXUIElement) -> CGWindowID {
  var identifier = CGWindowID(0)
  return _AXUIElementGetWindow(element, &identifier) == .success ? identifier : 0
}

let arguments = Array(CommandLine.arguments.dropFirst())
let modes = ["there", "back", "back-20", "back-60", "back-150", "recall", "recall-20", "recall-60"]
func fail(_ code: Int32, _ message: String) -> Never {
  FileHandle.standardError.write(Data("takeback: \(message)\n".utf8))
  exit(code)
}
func needed<T>(_ value: T?) -> T {
  guard let value else { fail(64, "usage: takeback <pid A> <window A> <pid B> <window B> \(modes.joined(separator: "|"))") }
  return value
}
// Not `guard let`: what that binds at the top of a file is no global, and the observers' callback, a C function, could not use it.
let pidA: pid_t = needed(arguments.count == 5 ? pid_t(arguments[0]) : nil)
let idA: CGWindowID = needed(CGWindowID(arguments[1]))
let pidB: pid_t = needed(pid_t(arguments[2]))
let idB: CGWindowID = needed(CGWindowID(arguments[3]))
let mode: String = needed(modes.contains(arguments[4]) ? arguments[4] : nil)

func name(_ pid: pid_t) -> String { pid == pidA ? "A's app" : pid == pidB ? "B's app" : "another app" }
func name(_ window: CGWindowID) -> String { window == idA ? "A" : window == idB ? "B" : window == 0 ? "no window" : "another window" }

func window(_ id: CGWindowID, of pid: pid_t) -> AXUIElement {
  let app = AXUIElementCreateApplication(pid)
  AXUIElementSetMessagingTimeout(app, 1)
  var listed: CFTypeRef?
  AXUIElementCopyAttributeValue(app, "AXWindows" as CFString, &listed)
  let elements = (listed as? [AnyObject] ?? []).filter { CFGetTypeID($0) == AXUIElementGetTypeID() }.map { $0 as! AXUIElement }
  guard let found = elements.first(where: { number(of: $0) == id }) else { fail(65, "process \(pid) lists no window \(id)") }
  AXUIElementSetMessagingTimeout(found, 1)
  return found
}
let elementA: AXUIElement = window(idA, of: pidA)
let elementB: AXUIElement = window(idB, of: pidB)

func front() -> pid_t { NSWorkspace.shared.frontmostApplication?.processIdentifier ?? -1 }

/// `AXWindowSystem.focus`, with how long each part took. `always`: activates the app although it is in front.
func focus(_ element: AXUIElement, _ pid: pid_t, _ what: String, always: Bool = false) {
  let start = elapsed()
  let main = AXUIElementSetAttributeValue(element, "AXMain" as CFString, kCFBooleanTrue)
  let afterMain = elapsed()
  let raised = AXUIElementPerformAction(element, "AXRaise" as CFString)
  let afterRaise = elapsed()
  let inFront = front()
  var activation = "no activation: its app is in front"
  if always || inFront != pid {
    let accepted = NSRunningApplication(processIdentifier: pid)?.activate() ?? false
    activation = "activate() says \(accepted), with \(name(inFront)) in front"
  }
  say(
    "probe ",
    String(
      format: "focus %@: main %d in %.1f ms, raise %d in %.1f ms, %@, %.1f ms in all", what, main.rawValue, afterMain - start, raised.rawValue,
      afterRaise - afterMain, activation, elapsed() - start))
}

func callback(_ observer: AXObserver, _ element: AXUIElement, _ notification: CFString, _ refcon: UnsafeMutableRawPointer?) {
  var pid: pid_t = 0
  AXUIElementGetPid(element, &pid)
  let text = notification as String
  let about = text.hasSuffix("WindowChanged") ? " " + name(number(of: element)) : ""
  say("ax    ", "\(name(pid)): \(text)\(about)")
}
func observe(_ pid: pid_t) -> AXObserver {
  var created: AXObserver?
  guard AXObserverCreate(pid, callback, &created) == .success, let created else { fail(66, "cannot observe process \(pid)") }
  let app = AXUIElementCreateApplication(pid)
  for text in ["AXFocusedWindowChanged", "AXMainWindowChanged", "AXApplicationActivated", "AXApplicationDeactivated"] {
    AXObserverAddNotification(created, app, text as CFString, nil)
  }
  CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(created), .defaultMode)
  return created
}
let observers: [AXObserver] = [observe(pidA), observe(pidB)]

let center = NSWorkspace.shared.notificationCenter
for notification in [NSWorkspace.didActivateApplicationNotification, NSWorkspace.didDeactivateApplicationNotification] {
  _ = center.addObserver(forName: notification, object: nil, queue: .main) { note in
    let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
    let short = notification == NSWorkspace.didActivateApplicationNotification ? "didActivate" : "didDeactivate"
    say("space ", "\(short) \(name(app?.processIdentifier ?? -1))")
  }
}

// Who is in front, and which window Accessibility says has the keyboard, asked all the time.
Thread.detachNewThread {
  let everything = AXUIElementCreateSystemWide()
  AXUIElementSetMessagingTimeout(everything, 1)
  var last = ""
  while true {
    var focusedApp: CFTypeRef?
    var keys = "nobody"
    if AXUIElementCopyAttributeValue(everything, "AXFocusedApplication" as CFString, &focusedApp) == .success, let focusedApp,
      CFGetTypeID(focusedApp) == AXUIElementGetTypeID()
    {
      let app = focusedApp as! AXUIElement
      var pid: pid_t = 0
      AXUIElementGetPid(app, &pid)
      var focusedWindow: CFTypeRef?
      var which = "no window"
      if AXUIElementCopyAttributeValue(app, "AXFocusedWindow" as CFString, &focusedWindow) == .success, let focusedWindow,
        CFGetTypeID(focusedWindow) == AXUIElementGetTypeID()
      {
        which = name(number(of: focusedWindow as! AXUIElement))
      }
      keys = "\(name(pid)), \(which)"
    }
    let now = "in front: \(name(front())); keys go to \(keys)"
    if now != last { say("looked", now) }
    last = now
    usleep(2000)
  }
}

say("probe ", "mode \(mode)")
DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
  focus(elementB, pidB, "B")
  guard mode != "there" else { return }
  let parts = mode.split(separator: "-")
  let wait = parts.count > 1 ? (Double(parts[1]) ?? 0) / 1000 : 0
  let always = parts[0] == "recall"
  if wait == 0 {
    focus(elementA, pidA, "A", always: always)
  } else {
    DispatchQueue.main.asyncAfter(deadline: .now() + wait) { focus(elementA, pidA, "A", always: always) }
  }
}
DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
  say("probe ", "the end")
  exit(0)
}
let application = NSApplication.shared
application.setActivationPolicy(.prohibited)
application.run()
