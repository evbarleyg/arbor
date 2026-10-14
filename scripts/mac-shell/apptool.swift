// apptool: what Mac shell scripts need to know about other apps' windows, and to do to them.
//
// pointer.swift is the hand and the eye on the screen; this is the view through Accessibility, the API
// Arbor itself uses: which windows an app lists and what kind they are, where a title bar can be
// grabbed, where the traffic lights are, how small and how large a window will go, which buttons a first-run
// sheet offers. `watch` writes down every Accessibility and workspace notification as it arrives, which is
// the only way to learn in what order macOS really reports things.
//
// scripts/mac-shell/lib-apps.sh compiles it on the Mac (swiftc -swift-version 5) and wraps it. Needs Accessibility
// permission. Coordinates are global points, origin top-left, y down. It never prints a window's title.

import AppKit
import ApplicationServices
import CoreGraphics
import Foundation

/// The window server's number for an Accessibility window; Arbor uses the same call (AX/AXHelpers.swift).
@_silgen_name("_AXUIElementGetWindow")
func _AXUIElementGetWindow(_ element: AXUIElement, _ identifier: UnsafeMutablePointer<CGWindowID>) -> AXError

let usage = """
  usage: apptool <command>
    apps                          pid policy state bundle-id, one line per app that is not background-only
    pid <bundle id | name>        the running app's process id (exit code 1: not running)
    front                         pid bundle-id of the frontmost app
    focused [pid]                 id pid: the window of the frontmost app (or of that one) that has the keyboard, or would
                                  have it if the app were in front (exit code 1: none)
    dock <bundle id | name>       x y: the middle of that app's icon in the Dock (exit code 1: it has none)
    dock-window <window>          x y: the middle of that minimized window's miniature in the Dock (exit code 1: none)
    menu <pid> <title>            x y: the middle of that menu's title in the menu bar, e.g. Window (exit code 1: none)
    menu-window <window>          x y: the middle of that window's line in its app's Window menu, which must be open
    windows <pid>                 id role subrole x y w h flags, as the app lists them to Accessibility
    wait-window <pid> [seconds]   the same, once a standard window is among them (exit code 1: none came)
    describe <window>             that line for one window
    grab <window>                 x y role: a point of the title bar that moves the window when dragged
    button <window> <close|minimize|zoom>       x y: the middle of that title-bar button (exit code 1: none, or disabled)
    limits <window>               how small and large it goes, whether it rounds sizes, whether it can be parked
    set-frame <window> x y w h    position and size, as Arbor sets them; prints the frame it took
    minimize | unminimize | raise | close <window>
    hide | unhide | activate | quit | kill <pid>
    tree <pid> [depth]            roles, subroles and frames; buttons with their titles
    press <pid> <title>…          press the first button with one of these titles (exit code 1: none)
    top-at x y                    id pid: the frontmost ordinary window there
    modes                         w h pixel-w pixel-h, one line per mode of the main display; * marks the current one
    set-mode w h                  switch the main display to that many points
    watch [pid…]                  print notifications until killed; without pids, of every regular app
  """

func fail(_ message: String, code: Int32 = 64) -> Never {
  FileHandle.standardError.write(Data("apptool: \(message)\n".utf8))
  exit(code)
}

func rest(_ seconds: Double) {
  if seconds > 0 { Thread.sleep(forTimeInterval: seconds) }
}

/// `12` for 12.0 and `12.5` for 12.5, so that shell arithmetic can use whole numbers as they are.
func text(_ value: CGFloat) -> String {
  let number = Double(value)
  return number == number.rounded() ? String(Int(number)) : String(format: "%.1f", number)
}

func text(_ rect: CGRect) -> String {
  "\(text(rect.minX)) \(text(rect.minY)) \(text(rect.width)) \(text(rect.height))"
}

func text(_ size: CGSize) -> String { "\(text(size.width))x\(text(size.height))" }

// MARK: Accessibility

extension AXUIElement {
  func attribute(_ name: String) -> CFTypeRef? {
    var raw: CFTypeRef?
    guard AXUIElementCopyAttributeValue(self, name as CFString, &raw) == .success else { return nil }
    return raw
  }

  func string(_ name: String) -> String? { attribute(name) as? String }

  func bool(_ name: String) -> Bool? {
    guard let raw = attribute(name), CFGetTypeID(raw) == CFBooleanGetTypeID() else { return nil }
    return CFBooleanGetValue((raw as! CFBoolean))
  }

  func element(_ name: String) -> AXUIElement? {
    guard let raw = attribute(name), CFGetTypeID(raw) == AXUIElementGetTypeID() else { return nil }
    return (raw as! AXUIElement)
  }

  func elements(_ name: String) -> [AXUIElement] {
    guard let raw = attribute(name), CFGetTypeID(raw) == CFArrayGetTypeID() else { return [] }
    return (raw as? [AnyObject] ?? []).compactMap { item in
      CFGetTypeID(item) == AXUIElementGetTypeID() ? (item as! AXUIElement) : nil
    }
  }

  var position: CGPoint? {
    guard let raw = attribute(kAXPositionAttribute), CFGetTypeID(raw) == AXValueGetTypeID() else { return nil }
    var point = CGPoint.zero
    return AXValueGetValue(raw as! AXValue, .cgPoint, &point) ? point : nil
  }

  var size: CGSize? {
    guard let raw = attribute(kAXSizeAttribute), CFGetTypeID(raw) == AXValueGetTypeID() else { return nil }
    var extent = CGSize.zero
    return AXValueGetValue(raw as! AXValue, .cgSize, &extent) ? extent : nil
  }

  var frame: CGRect? {
    guard let origin = position, let extent = size else { return nil }
    return CGRect(origin: origin, size: extent)
  }

  @discardableResult
  func set(position: CGPoint) -> AXError {
    var point = position
    guard let boxed = AXValueCreate(.cgPoint, &point) else { return .failure }
    return AXUIElementSetAttributeValue(self, kAXPositionAttribute as CFString, boxed)
  }

  @discardableResult
  func set(size: CGSize) -> AXError {
    var extent = size
    guard let boxed = AXValueCreate(.cgSize, &extent) else { return .failure }
    return AXUIElementSetAttributeValue(self, kAXSizeAttribute as CFString, boxed)
  }

  @discardableResult
  func set(_ name: String, _ flag: Bool) -> AXError {
    AXUIElementSetAttributeValue(self, name as CFString, flag ? kCFBooleanTrue : kCFBooleanFalse)
  }

  func isSettable(_ name: String) -> Bool {
    var settable = DarwinBoolean(false)
    return AXUIElementIsAttributeSettable(self, name as CFString, &settable) == .success && settable.boolValue
  }

  @discardableResult
  func perform(_ action: String) -> AXError { AXUIElementPerformAction(self, action as CFString) }

  var windowNumber: UInt32? {
    var identifier = CGWindowID(0)
    guard _AXUIElementGetWindow(self, &identifier) == .success, identifier != 0 else { return nil }
    return identifier
  }

  var role: String { string(kAXRoleAttribute) ?? "?" }
  var subrole: String { string(kAXSubroleAttribute) ?? "-" }
}

func application(_ pid: pid_t) -> AXUIElement {
  let element = AXUIElementCreateApplication(pid)
  // An app that is busy launching must not hang the script.
  AXUIElementSetMessagingTimeout(element, 2)
  return element
}

// MARK: The window server

func windowList(_ options: CGWindowListOption) -> [[String: Any]] {
  (CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]]) ?? []
}

func number(_ info: [String: Any], _ key: CFString) -> Int? { (info[key as String] as? NSNumber)?.intValue }

func bounds(_ info: [String: Any]) -> CGRect? {
  guard let dictionary = info[kCGWindowBounds as String] as? NSDictionary else { return nil }
  return CGRect(dictionaryRepresentation: dictionary as CFDictionary)
}

func owner(of window: UInt32) -> pid_t? {
  for info in windowList([.optionAll]) where number(info, kCGWindowNumber) == Int(window) {
    return number(info, kCGWindowOwnerPID).map { pid_t($0) }
  }
  return nil
}

/// The frontmost window at the ordinary level under a point: the list comes front to back. `ringAround` looks through Arbor's focus
/// ring: a window at the ordinary level, right in front of the focused window and a few points larger all round, that lets presses
/// through. Arbor's other windows (its welcome, its settings) take presses like anybody's.
func topWindow(at point: CGPoint, ringAround framed: CGRect? = nil) -> (id: UInt32, pid: pid_t)? {
  for info in windowList([.optionOnScreenOnly, .excludeDesktopElements]) where number(info, kCGWindowLayer) == 0 {
    guard let rect = bounds(info), rect.contains(point), let id = number(info, kCGWindowNumber) else { continue }
    if let framed, info[kCGWindowOwnerName as String] as? String == "Arbor", rect.contains(framed),
      framed.insetBy(dx: -24, dy: -24).contains(rect)
    {
      continue
    }
    return (UInt32(id), pid_t(number(info, kCGWindowOwnerPID) ?? 0))
  }
  return nil
}

/// The Accessibility element of a window, found through its owner. Exit code 1 when there is none: closed, on
/// another Space, or never listed.
func axWindow(_ id: UInt32) -> AXUIElement {
  guard let pid = owner(of: id) else { fail("the window server has no window \(id)", code: 1) }
  for window in application(pid).elements(kAXWindowsAttribute) where window.windowNumber == id { return window }
  fail("process \(pid) does not list window \(id)", code: 1)
}

func describe(_ window: AXUIElement) -> String {
  var flags: [String] = []
  if window.bool(kAXMinimizedAttribute) == true { flags.append("minimized") }
  if window.bool(kAXMainAttribute) == true { flags.append("main") }
  if window.bool(kAXFocusedAttribute) == true { flags.append("focused") }
  if window.bool(kAXModalAttribute) == true { flags.append("modal") }
  if window.bool("AXFullScreen") == true { flags.append("fullscreen") }
  if !window.isSettable(kAXSizeAttribute) { flags.append("fixed-size") }
  if !window.isSettable(kAXPositionAttribute) { flags.append("fixed-position") }
  for (name, attribute) in [
    ("close", kAXCloseButtonAttribute), ("minimize", kAXMinimizeButtonAttribute), ("zoom", kAXZoomButtonAttribute),
  ] {
    guard let button = window.element(attribute) else {
      flags.append("no-\(name)")
      continue
    }
    if button.bool(kAXEnabledAttribute) == false { flags.append("\(name)-disabled") }
  }
  let children = window.elements(kAXChildrenAttribute)
  let sheets = children.filter { $0.role == kAXSheetRole }.count
  if sheets > 0 { flags.append("sheets=\(sheets)") }
  if children.contains(where: { $0.role == kAXToolbarRole }) { flags.append("toolbar") }
  // A window with native tabs shows them as a tab group of its own; the other tabs are windows that are not on screen.
  if let group = children.first(where: { $0.role == kAXTabGroupRole }) {
    let tabs = group.elements(kAXChildrenAttribute).filter { $0.role == kAXRadioButtonRole }.count
    if tabs > 0 { flags.append("tabs=\(tabs)") }
  }
  let frame = window.frame.map { text($0) } ?? "? ? ? ?"
  return "\(window.windowNumber ?? 0) \(window.role) \(window.subrole) \(frame) \(flags.isEmpty ? "-" : flags.joined(separator: ","))"
}

func isStandard(_ window: AXUIElement) -> Bool {
  window.role == kAXWindowRole && window.subrole == kAXStandardWindowSubrole
}

// MARK: Apps

func runningApp(_ word: String) -> NSRunningApplication? {
  if let pid = pid_t(word) { return NSRunningApplication(processIdentifier: pid) }
  let apps = NSWorkspace.shared.runningApplications.filter { !$0.isTerminated }
  return apps.first { $0.bundleIdentifier == word } ?? apps.first { $0.localizedName == word }
}

func policy(_ app: NSRunningApplication) -> String {
  switch app.activationPolicy {
  case .regular: return "regular"
  case .accessory: return "accessory"
  case .prohibited: return "background"
  @unknown default: return "unknown"
  }
}

// MARK: Where a title bar can be grabbed

/// Controls take the press for themselves; everything else in a title bar or a toolbar moves the window.
let controls: Set<String> = [
  "AXButton", "AXTextField", "AXTextArea", "AXPopUpButton", "AXMenuButton", "AXCheckBox", "AXRadioButton", "AXSlider",
  "AXComboBox", "AXTabGroup", "AXSegmentedControl", "AXDisclosureTriangle", "AXIncrementor", "AXLink", "AXImage",
  "AXCell", "AXRow", "AXOutline", "AXTable", "AXScrollBar", "AXWebArea", "AXColorWell", "AXMenuItem",
]
let surelyDraggable: Set<String> = ["AXWindow", "AXToolbar", "AXStaticText"]

/// Looks along the top of the window, from the middle outwards, for a point that this window shows (nothing in front)
/// and where Accessibility finds the window itself, its toolbar or its title. Safari's address field, a search
/// field or a tab would take the press instead.
func grabPoint(_ window: AXUIElement, id: UInt32, pid: pid_t) -> (CGPoint, String)? {
  guard let frame = window.frame else { return nil }
  let app = application(pid)
  var columns: [CGFloat] = []
  var x = frame.minX + 84  // past the traffic lights
  while x < frame.maxX - 20 {
    columns.append(x)
    x += 14
  }
  if columns.isEmpty { columns = [frame.midX] }
  columns.sort { abs($0 - frame.midX) < abs($1 - frame.midX) }
  var second: (CGPoint, String)?
  for offset in [12, 20, 7] as [CGFloat] {
    for column in columns {
      let point = CGPoint(x: column.rounded(), y: (frame.minY + offset).rounded())
      guard topWindow(at: point, ringAround: frame)?.id == id else { continue }
      var found: AXUIElement?
      guard AXUIElementCopyElementAtPosition(app, Float(point.x), Float(point.y), &found) == .success,
        let element = found
      else { continue }
      let role = element.role
      if surelyDraggable.contains(role) { return (point, role) }
      if second == nil, !controls.contains(role) { second = (point, role) }
    }
  }
  return second
}

// MARK: How a window resists

struct Attempt {
  var asked: CGSize
  var atOnce: CGSize
  var later: CGSize
  var milliseconds: Double
  var error: AXError
}

func attempt(_ window: AXUIElement, _ size: CGSize) -> Attempt {
  let started = Date()
  let error = window.set(size: size)
  let atOnce = window.size ?? .zero
  let milliseconds = Date().timeIntervalSince(started) * 1000
  rest(0.45)
  return Attempt(asked: size, atOnce: atOnce, later: window.size ?? .zero, milliseconds: milliseconds, error: error)
}

func limits(_ window: AXUIElement) {
  guard let original = window.frame else { fail("the window has no frame", code: 1) }
  let display = CGDisplayBounds(CGMainDisplayID())
  // From the top-left corner, so that the screen's edges are not what stops it from growing.
  window.set(position: CGPoint(x: display.minX + 4, y: display.minY + 40))
  let small = attempt(window, CGSize(width: 40, height: 40))
  let large = attempt(window, CGSize(width: 3200, height: 2400))
  let middle = CGSize(
    width: min(small.later.width + 137, large.later.width), height: min(small.later.height + 113, large.later.height))
  let odd = attempt(window, middle)
  let attempts = [small, large, odd]
  let late = attempts.contains { $0.atOnce != $0.later }
  let slowest = attempts.map { $0.milliseconds }.max() ?? 0
  let errors = attempts.filter { $0.error != .success }.map { String($0.error.rawValue) }

  // Where Arbor parks a window: one point of it on screen, in the bottom right corner.
  window.set(size: original.size)
  let corner = CGPoint(x: display.maxX - 1, y: display.maxY - 1)
  window.set(position: corner)
  rest(0.3)
  let parked = window.position ?? .zero

  window.set(size: original.size)
  window.set(position: original.origin)
  window.set(size: original.size)
  rest(0.3)
  let restored = window.frame ?? .zero
  print(
    "min \(text(small.later)) max \(text(large.later)) asked \(text(odd.asked)) got \(text(odd.later))"
      + " late \(late ? "yes" : "no") slowest-ms \(Int(slowest)) errors \(errors.isEmpty ? "none" : errors.joined(separator: ","))"
      + " parked-at \(text(parked.x)),\(text(parked.y)) of \(text(corner.x)),\(text(corner.y))"
      + " restored \(restored.equalTo(original) ? "yes" : text(restored))")
}

// MARK: The tree, and pressing buttons in it

func walk(_ element: AXUIElement, depth: Int, limit: Int, budget: inout Int, visit: (AXUIElement, Int) -> Bool) -> Bool {
  guard budget > 0 else { return false }
  budget -= 1
  if visit(element, depth) { return true }
  guard depth < limit else { return false }
  for child in element.elements(kAXChildrenAttribute) {
    if walk(child, depth: depth + 1, limit: limit, budget: &budget, visit: visit) { return true }
  }
  return false
}

// MARK: Watching

/// Prints one line per notification, stamped like arbor.log, so that the two files sort into one story.
final class Watcher {
  private var observers: [pid_t: AXObserver] = [:]
  private var watched = Set<UInt32>()
  private let only: Set<pid_t>?
  private let formatter: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter
  }()

  static let ofApps = [
    kAXWindowCreatedNotification, kAXFocusedWindowChangedNotification, kAXMainWindowChangedNotification,
    kAXApplicationActivatedNotification, kAXApplicationDeactivatedNotification, kAXApplicationHiddenNotification,
    kAXApplicationShownNotification, kAXSheetCreatedNotification, kAXDrawerCreatedNotification,
  ]
  static let ofWindows = [
    kAXUIElementDestroyedNotification, kAXMovedNotification, kAXResizedNotification,
    kAXWindowMiniaturizedNotification, kAXWindowDeminiaturizedNotification, kAXTitleChangedNotification,
  ]

  init(only: Set<pid_t>?) { self.only = only }

  func log(_ line: String) {
    print("\(formatter.string(from: Date())) MACOS \(line)")
    fflush(stdout)
  }

  func wants(_ app: NSRunningApplication) -> Bool {
    if app.processIdentifier == getpid() { return false }
    if let only = only { return only.contains(app.processIdentifier) }
    return app.activationPolicy == .regular
  }

  func start() {
    for app in NSWorkspace.shared.runningApplications where wants(app) { observe(app.processIdentifier, attempt: 0) }
    let center = NSWorkspace.shared.notificationCenter
    let names: [(NSNotification.Name, String)] = [
      (NSWorkspace.didLaunchApplicationNotification, "didLaunch"),
      (NSWorkspace.didTerminateApplicationNotification, "didTerminate"),
      (NSWorkspace.didActivateApplicationNotification, "didActivate"),
      (NSWorkspace.didDeactivateApplicationNotification, "didDeactivate"),
      (NSWorkspace.didHideApplicationNotification, "didHide"),
      (NSWorkspace.didUnhideApplicationNotification, "didUnhide"),
      (NSWorkspace.activeSpaceDidChangeNotification, "activeSpaceDidChange"),
    ]
    for (name, label) in names {
      center.addObserver(forName: name, object: nil, queue: .main) { [weak self] note in
        guard let self = self else { return }
        guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else {
          self.log("workspace \(label)")
          return
        }
        let pid = app.processIdentifier
        self.log("workspace \(label) pid \(pid) \(app.bundleIdentifier ?? "?") \(policy(app))")
        if label == "didLaunch", self.wants(app) { self.observe(pid, attempt: 0) }
        if label == "didTerminate" { self.observers[pid] = nil }
      }
    }
  }

  func observe(_ pid: pid_t, attempt: Int) {
    guard observers[pid] == nil else { return }
    var created: AXObserver?
    let element = application(pid)
    var failed: [String] = []
    if AXObserverCreate(pid, watchCallback, &created) == .success, let observer = created {
      for name in Watcher.ofApps {
        let result = AXObserverAddNotification(observer, element, name as CFString, nil)
        if result != .success { failed.append("\(name)=\(result.rawValue)") }
      }
      // Apps that are still launching refuse everything; the drawer notification alone is refused by many for good.
      if failed.count < Watcher.ofApps.count - 1 {
        CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .defaultMode)
        observers[pid] = observer
        log("watching pid \(pid), attempt \(attempt)\(failed.isEmpty ? "" : ", refused: " + failed.joined(separator: " "))")
        for window in element.elements(kAXWindowsAttribute) { observe(window: window, pid: pid, how: "listed") }
        return
      }
    }
    guard attempt < 20 else {
      log("gave up watching pid \(pid): \(failed.joined(separator: " "))")
      return
    }
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in self?.observe(pid, attempt: attempt + 1) }
  }

  func observe(window: AXUIElement, pid: pid_t, how: String) {
    guard let observer = observers[pid], let id = window.windowNumber else { return }
    log("pid \(pid) \(how) \(summary(window))")
    guard watched.insert(id).inserted else { return }
    let refcon = UnsafeMutableRawPointer(bitPattern: UInt(id))
    for name in Watcher.ofWindows { AXObserverAddNotification(observer, window, name as CFString, refcon) }
  }

  func summary(_ element: AXUIElement) -> String {
    let frame = element.frame.map { text($0) } ?? "no frame"
    var line = "w\(element.windowNumber ?? 0) \(element.role)/\(element.subrole) \(frame)"
    if element.bool(kAXMinimizedAttribute) == true { line += " minimized" }
    if element.bool("AXFullScreen") == true { line += " fullscreen" }
    return line
  }

  func handle(_ name: String, _ element: AXUIElement, _ refcon: UnsafeMutableRawPointer?) {
    var pid: pid_t = 0
    AXUIElementGetPid(element, &pid)
    if name == kAXUIElementDestroyedNotification {
      let id = refcon.map { UInt32(truncatingIfNeeded: UInt(bitPattern: $0)) } ?? 0
      watched.remove(id)
      log("pid \(pid) \(name) w\(id)")
    } else if element.role == kAXApplicationRole {
      log("pid \(pid) \(name)")
    } else if name == kAXWindowCreatedNotification || name == kAXFocusedWindowChangedNotification
      || name == kAXMainWindowChangedNotification
    {
      observe(window: element, pid: pid, how: name)
    } else {
      log("pid \(pid) \(name) \(summary(element))")
    }
  }
}

var watcher: Watcher?

func watchCallback(
  _ observer: AXObserver, _ element: AXUIElement, _ notification: CFString, _ refcon: UnsafeMutableRawPointer?
) {
  watcher?.handle(notification as String, element, refcon)
}

// MARK: Commands

var arguments = Array(CommandLine.arguments.dropFirst())
guard !arguments.isEmpty else { fail(usage) }
let command = arguments.removeFirst()

func word(_ index: Int, _ what: String) -> String {
  guard arguments.count > index else { fail("expected \(what)\n\(usage)") }
  return arguments[index]
}

func double(_ index: Int, _ what: String) -> CGFloat {
  guard let value = Double(word(index, what)), value.isFinite, abs(value) < 1_000_000 else {
    fail("expected \(what), got \(arguments[index])")
  }
  return CGFloat(value)
}

func windowArgument() -> UInt32 {
  guard let id = UInt32(word(0, "a window id")) else { fail("expected a window id, got \(arguments[0])") }
  return id
}

func pidArgument() -> pid_t {
  guard let pid = pid_t(word(0, "a process id")) else { fail("expected a process id, got \(arguments[0])") }
  return pid
}

func appArgument() -> NSRunningApplication {
  guard let app = runningApp(word(0, "a process id, a bundle id or a name")) else {
    fail("\(arguments[0]) is not running", code: 1)
  }
  return app
}

switch command {
case "apps":
  for app in NSWorkspace.shared.runningApplications where app.activationPolicy != .prohibited {
    var state: [String] = []
    if app.isActive { state.append("active") }
    if app.isHidden { state.append("hidden") }
    if !app.isFinishedLaunching { state.append("launching") }
    print(
      "\(app.processIdentifier) \(policy(app)) \(state.isEmpty ? "-" : state.joined(separator: ",")) \(app.bundleIdentifier ?? "?")")
  }

case "pid":
  print(appArgument().processIdentifier)

case "front":
  guard let app = NSWorkspace.shared.frontmostApplication else { fail("no app is in front", code: 1) }
  print("\(app.processIdentifier) \(app.bundleIdentifier ?? "?")")

case "focused":
  guard let app = arguments.isEmpty ? NSWorkspace.shared.frontmostApplication : appArgument() else {
    fail("no app is in front", code: 1)
  }
  let element = application(app.processIdentifier)
  guard let window = element.element(kAXFocusedWindowAttribute) ?? element.element(kAXMainWindowAttribute),
    let id = window.windowNumber
  else { fail("the app has no focused window", code: 1) }
  print("\(id) \(app.processIdentifier)")

case "dock", "dock-window":
  guard let dock = runningApp("com.apple.dock") else { fail("the Dock is not running", code: 1) }
  var items: [AXUIElement] = []
  for list in application(dock.processIdentifier).elements(kAXChildrenAttribute) where list.role == kAXListRole {
    items += list.elements(kAXChildrenAttribute)
  }
  var found: AXUIElement?
  if command == "dock" {
    let wanted = word(0, "a bundle id or a name")
    found = items.first { item in
      guard item.subrole == "AXApplicationDockItem" else { return false }
      if item.string(kAXTitleAttribute) == wanted { return true }
      guard let url = item.attribute(kAXURLAttribute) as? URL else { return false }
      return Bundle(url: url)?.bundleIdentifier == wanted
    }
  } else {
    // Compared here and never printed: the miniature is called what the window is called.
    let title = axWindow(windowArgument()).string(kAXTitleAttribute)
    found = items.first { $0.subrole == "AXMinimizedWindowDockItem" && $0.string(kAXTitleAttribute) == title }
  }
  guard let frame = found?.frame else { fail("the Dock shows no such thing", code: 1) }
  print("\(text(frame.midX.rounded())) \(text(frame.midY.rounded()))")

case "menu":
  let title = word(1, "the title of a menu")
  guard let bar = application(pidArgument()).element(kAXMenuBarAttribute),
    let frame = bar.elements(kAXChildrenAttribute).first(where: { $0.string(kAXTitleAttribute) == title })?.frame
  else { fail("no menu called \(title)", code: 1) }
  print("\(text(frame.midX.rounded())) \(text(frame.midY.rounded()))")

case "menu-window":
  let id = windowArgument()
  guard let pid = owner(of: id) else { fail("the window server has no window \(id)", code: 1) }
  // Compared here and never printed: the line is called what the window is called.
  let title = axWindow(id).string(kAXTitleAttribute)
  guard let bar = application(pid).element(kAXMenuBarAttribute),
    let menu = bar.elements(kAXChildrenAttribute).first(where: { $0.string(kAXTitleAttribute) == "Window" })?
      .elements(kAXChildrenAttribute).first,
    let frame = menu.elements(kAXChildrenAttribute).last(where: { $0.string(kAXTitleAttribute) == title })?.frame,
    frame.height > 0
  else { fail("the Window menu has no line for window \(id), or is not open", code: 1) }
  print("\(text(frame.midX.rounded())) \(text(frame.midY.rounded()))")

case "windows":
  for window in application(pidArgument()).elements(kAXWindowsAttribute) { print(describe(window)) }

case "wait-window":
  let pid = pidArgument()
  let deadline = Date().addingTimeInterval(arguments.count > 1 ? Double(double(1, "seconds")) : 15)
  var windows: [AXUIElement] = []
  repeat {
    windows = application(pid).elements(kAXWindowsAttribute)
    if windows.contains(where: isStandard) { break }
    rest(0.2)
  } while Date() < deadline
  for window in windows { print(describe(window)) }
  exit(windows.contains(where: isStandard) ? 0 : 1)

case "describe":
  print(describe(axWindow(windowArgument())))

case "grab":
  let id = windowArgument()
  guard let pid = owner(of: id) else { fail("the window server has no window \(id)", code: 1) }
  guard let (point, role) = grabPoint(axWindow(id), id: id, pid: pid) else {
    fail("no point of window \(id)'s title bar is both uncovered and free of controls", code: 1)
  }
  print("\(text(point.x)) \(text(point.y)) \(role)")

case "button":
  let names = ["close": kAXCloseButtonAttribute, "minimize": kAXMinimizeButtonAttribute, "zoom": kAXZoomButtonAttribute]
  guard let attribute = names[word(1, "close, minimize or zoom")] else { fail("expected close, minimize or zoom") }
  guard let button = axWindow(windowArgument()).element(attribute), let frame = button.frame else {
    fail("the window has no \(arguments[1]) button", code: 1)
  }
  guard button.bool(kAXEnabledAttribute) != false else { fail("the \(arguments[1]) button is disabled", code: 1) }
  print("\(text(frame.midX.rounded())) \(text(frame.midY.rounded()))")

case "limits":
  limits(axWindow(windowArgument()))

case "set-frame":
  let window = axWindow(windowArgument())
  let frame = CGRect(x: double(1, "x"), y: double(2, "y"), width: double(3, "w"), height: double(4, "h"))
  window.set(size: frame.size)
  window.set(position: frame.origin)
  window.set(size: frame.size)
  print(window.frame.map { text($0) } ?? "no frame")

case "minimize", "unminimize":
  let result = axWindow(windowArgument()).set(kAXMinimizedAttribute, command == "minimize")
  if result != .success { fail("\(command) failed: \(result.rawValue)", code: 1) }

case "raise":
  let window = axWindow(windowArgument())
  window.set(kAXMainAttribute, true)
  window.perform(kAXRaiseAction)

case "close":
  guard let button = axWindow(windowArgument()).element(kAXCloseButtonAttribute) else {
    fail("the window has no close button", code: 1)
  }
  let result = button.perform(kAXPressAction)
  if result != .success { fail("close failed: \(result.rawValue)", code: 1) }

case "hide": exit(appArgument().hide() ? 0 : 1)
case "unhide": exit(appArgument().unhide() ? 0 : 1)
case "activate": exit(appArgument().activate(options: []) ? 0 : 1)
case "quit": exit(appArgument().terminate() ? 0 : 1)
case "kill": exit(appArgument().forceTerminate() ? 0 : 1)

case "tree":
  let limit = arguments.count > 1 ? Int(double(1, "a depth")) : 3
  var budget = 250
  _ = walk(application(pidArgument()), depth: 0, limit: limit, budget: &budget) { element, depth in
    var line = String(repeating: "  ", count: depth) + "\(element.role)/\(element.subrole)"
    if let frame = element.frame { line += " \(text(frame))" }
    // What a button says is the app's text, not the person's.
    if element.role == kAXButtonRole, let title = element.string(kAXTitleAttribute) ?? element.string(kAXDescriptionAttribute) {
      line += " \"\(title)\""
    }
    print(line)
    return false
  }
  if budget == 0 { print("… (cut off)") }

case "press":
  let titles = Set(arguments.dropFirst())
  guard !titles.isEmpty else { fail("expected the title of a button") }
  var budget = 5000
  let pressed = walk(application(pidArgument()), depth: 0, limit: 24, budget: &budget) { element, _ in
    // Catalyst apps name their buttons in the description.
    guard element.role == kAXButtonRole,
      let title = [kAXTitleAttribute, kAXDescriptionAttribute].compactMap({ element.string($0) }).first(where: titles.contains),
      element.bool(kAXEnabledAttribute) != false
    else { return false }
    print("pressed \"\(title)\": \(element.perform(kAXPressAction).rawValue)")
    return true
  }
  exit(pressed ? 0 : 1)

case "top-at":
  guard let top = topWindow(at: CGPoint(x: double(0, "x"), y: double(1, "y"))) else { exit(1) }
  print("\(top.id) \(top.pid)")

case "modes", "set-mode":
  let display = CGMainDisplayID()
  let options = [kCGDisplayShowDuplicateLowResolutionModes as String: true] as CFDictionary
  let modes = (CGDisplayCopyAllDisplayModes(display, options) as? [CGDisplayMode]) ?? []
  if command == "modes" {
    let current = CGDisplayCopyDisplayMode(display)
    for mode in modes {
      let mark = mode.ioDisplayModeID == current?.ioDisplayModeID ? " *" : ""
      print("\(mode.width) \(mode.height) \(mode.pixelWidth) \(mode.pixelHeight)\(mark)")
    }
  } else {
    let width = Int(double(0, "a width")), height = Int(double(1, "a height"))
    // The fewest pixels for that many points: pictures stay small.
    guard
      let mode = modes.filter({ $0.width == width && $0.height == height && $0.isUsableForDesktopGUI() })
        .min(by: { $0.pixelWidth < $1.pixelWidth })
    else { fail("the display has no mode \(width)x\(height)", code: 1) }
    // Through a configuration, and for good: a mode set any other way is undone when this process exits.
    var configuration: CGDisplayConfigRef?
    var result = CGBeginDisplayConfiguration(&configuration)
    if result == .success { result = CGConfigureDisplayWithDisplayMode(configuration, display, mode, nil) }
    if result == .success { result = CGCompleteDisplayConfiguration(configuration, .permanently) }
    if result != .success { fail("could not switch to \(width)x\(height): \(result.rawValue)", code: 1) }
    print("\(mode.width) \(mode.height) \(mode.pixelWidth) \(mode.pixelHeight)")
  }

case "watch":
  let pids = arguments.compactMap { pid_t($0) }
  let created = Watcher(only: pids.isEmpty ? nil : Set(pids))
  watcher = created
  created.start()
  RunLoop.main.run()

default:
  fail("unknown command \(command)\n\(usage)")
}
