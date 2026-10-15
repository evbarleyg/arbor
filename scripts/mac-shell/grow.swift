// grow: asks one window for sizes and positions through Accessibility, call by call, and writes down what came of each. For
// probe-how-far-a-window-grows.sh: how far does macOS let a window grow or go, and in which order must size and position be set?
//
//   grow <pid> <window id|first> <label> [steps file]     (or the steps on stdin) one JSON object per line on stdout
//
// Nothing of Arbor's is in it: AXUIElementSetAttributeValue on AXSize and AXPosition, as Sources/ArborKit/AX does it, and nothing else.
//
// The steps, one to a line (# starts a comment):
//   round <words…>                                  a heading; prints the displays as they are then
//   reads on|off|both                               whether a journey reads the frame back after every call (on), only at its end, as Arbor
//                                                   does (off), or is made twice (both). Default on
//   orders SPS,PS,SP,sPS                            which orders the journeys to come are made in. Default all four
//   later on|off                                    on: after a `one`'s call, and after the LAST call of a journey, look again 50, 200 and 600 ms after the call
//                                                   returned: does an app say yes at once and carry the frame out later? Default off
//   one <name> <x y w h> size <w> <h>               put the window at x y w h, then make that one call
//   one <name> <x y w h> pos <x> <y>
//   journey <name> <x y w h> <x y w h>              from the first frame to the second, once in each order, put back before each:
//                                                     SPS size, position, size (FramePlan.full)      PS position, size      SP size, position
//                                                     sPS the smaller of both widths and of both heights, position, size
//   turn <name> <x y w h> <x y w h> <waits> <n> <orders>   to and fro between two frames, which lie on different displays: when does the new display begin to judge a size call?
//                                                   waits: milliseconds, 0,10,25; n: how often the whole is made; orders: PS position, WAIT, size; SP size, WAIT, position; SPSS size,
//                                                   position, size back to back, WAIT, size once more. Nothing is read between the calls. The waits are spun, and the result says how long they really were:
//                                                   "waited" from the return of the call before the wait, "sincePosition" from the return of the position call, to the start of the last call
//   put <name> <x y w h>                            put the window there, and say where it is then
//   look <name>                                     where the window is by Accessibility and by the window server, where the pointer is, whether the button is down
//   pause <ms>                                      let that long pass
//   chain <name> [after-release <ms> | after-move <points>] (size <w> <h> | pos <x> <y> | under <dx> <dy>)…      those calls back to back where the window is, nothing read between them; then the frame at once and 50, 200 and 500 ms after the
//                                                   last call returned (spun, so on time), each with the pointer and the button. For a window that a hand holds. after-release: first wait
//                                                   until the left button comes up, and that many milliseconds more. after-move: first wait until the pointer has gone that many points from where
//                                                   it is now: for a call made while the hand moves. under: a position call that puts the window's origin dx, dy up and left of where the pointer is
//                                                   at that moment
// With GROW_BRIEF in the environment the lines about the window and the displays are left out.
// A number is a sum of numbers and of these, for display 1 (the main one) and 2: l1 t1 r1 b1 (its frame's edges) and vl1 vt1 vr1 vb1 (its
// visible frame's), in global coordinates, y down: `vb1-12.5`, `r1-494`. A step that names a display that is not there is skipped, and says so.
//
// What is printed: {"kind":"displays"…}, for every call {"kind":"call"…} with what was asked, the frame before, the AXError, how long the call took,
// the frame read back through Accessibility and the one the window server lists; for every one and journey {"kind":"result"…} with the
// end frames at once and at rest, how far short of the target, the frames half way, and the AXMoved and AXResized that arrived with
// their times; with `later on` also "later": for each look how long after the call's return each of the two readings began (ms), how long Accessibility took to
// answer, and the two frames. The notifications are taken on a thread of their own, so their times are those of their arrival and not of somebody's turn to look.
//
// Compile it as lib.sh compiles pointer.swift: swiftc -O -swift-version 5. Needs Accessibility permission. It moves and resizes the window it is given.

import AppKit
import ApplicationServices

@_silgen_name("_AXUIElementGetWindow")
func _AXUIElementGetWindow(_ element: AXUIElement, _ identifier: UnsafeMutablePointer<CGWindowID>) -> AXError

func fail(_ message: String, _ code: Int32 = 64) -> Never {
  FileHandle.standardError.write(Data("grow: \(message)\n".utf8))
  exit(code)
}

let began = Date()
func now() -> Double { Date().timeIntervalSince(began) }
func round3(_ value: Double) -> Double { (value * 1000).rounded() / 1000 }

let brief = !(ProcessInfo.processInfo.environment["GROW_BRIEF"] ?? "").isEmpty
func epoch(_ time: Double) -> Double { ((began.timeIntervalSince1970 + time) * 1000 * 1000).rounded() / 1000 }

func emit(_ object: [String: Any]) {
  if brief, let kind = object["kind"] as? String, kind == "window" || kind == "displays" { return }
  guard let data = try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]) else { return }
  print(String(decoding: data, as: UTF8.self))
  fflush(stdout)
}

func list(_ rect: CGRect?) -> Any {
  guard let rect else { return NSNull() }
  return [Double(rect.minX), Double(rect.minY), Double(rect.width), Double(rect.height)]
}

// MARK: The window

func attribute(_ element: AXUIElement, _ name: String) -> CFTypeRef? {
  var value: CFTypeRef?
  guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else { return nil }
  return value
}

func number(of element: AXUIElement) -> CGWindowID {
  var identifier = CGWindowID(0)
  return _AXUIElementGetWindow(element, &identifier) == .success ? identifier : 0
}

func frame(of window: AXUIElement) -> CGRect? {
  var origin = CGPoint.zero
  var size = CGSize.zero
  guard let position = attribute(window, "AXPosition"), CFGetTypeID(position) == AXValueGetTypeID(),
    let extent = attribute(window, "AXSize"), CFGetTypeID(extent) == AXValueGetTypeID()
  else { return nil }
  AXValueGetValue(position as! AXValue, .cgPoint, &origin)
  AXValueGetValue(extent as! AXValue, .cgSize, &size)
  return CGRect(origin: origin, size: size)
}

func serverFrame(of id: CGWindowID) -> CGRect? {
  let found = (CGWindowListCopyWindowInfo([.optionIncludingWindow], id) as? [[String: Any]]) ?? []
  for info in found where (info[kCGWindowNumber as String] as? NSNumber)?.uint32Value == id {
    if let dictionary = info[kCGWindowBounds as String] as? NSDictionary {
      return CGRect(dictionaryRepresentation: dictionary as CFDictionary)
    }
  }
  return nil
}

let arguments = Array(CommandLine.arguments.dropFirst())
guard arguments.count == 3 || arguments.count == 4, let pid = pid_t(arguments[0]) else {
  fail("usage: grow <pid> <window id|first> <label> [steps file]")
}
if arguments.count == 4, freopen(arguments[3], "r", stdin) == nil { fail("cannot read \(arguments[3])") }
let label = arguments[2]
let app = AXUIElementCreateApplication(pid)
AXUIElementSetMessagingTimeout(app, 3)
let listed = (attribute(app, "AXWindows") as? [AnyObject] ?? [])
  .filter { CFGetTypeID($0) == AXUIElementGetTypeID() }.map { $0 as! AXUIElement }
let chosen =
  arguments[1] == "first"
  ? listed.first { attribute($0, "AXSubrole") as? String == "AXStandardWindow" }
  // Safari, with the panel under its address field open, lists under its main window's number something that is not that window.
  : listed.first { number(of: $0) == CGWindowID(arguments[1]) ?? 0 && attribute($0, "AXSubrole") as? String == "AXStandardWindow" }
    ?? listed.first { number(of: $0) == CGWindowID(arguments[1]) ?? 0 }
guard let window = chosen else { fail("process \(pid) lists no window \(arguments[1]) (it lists \(listed.count))", 69) }
AXUIElementSetMessagingTimeout(window, 3)
let windowID = number(of: window)

// MARK: Displays

_ = NSApplication.shared
NSApplication.shared.setActivationPolicy(.prohibited)

var names: [String: Double] = [:]

func readDisplays(_ why: String) {
  let screens = NSScreen.screens
  // AppKit's y goes up from the bottom of the first screen.
  let height = screens.first?.frame.maxY ?? 0
  func global(_ rect: NSRect) -> CGRect { CGRect(x: rect.minX, y: height - rect.maxY, width: rect.width, height: rect.height) }
  names = [:]
  var all: [[String: Any]] = []
  for (index, screen) in screens.enumerated() {
    let whole = global(screen.frame)
    let visible = global(screen.visibleFrame)
    let n = index + 1
    names["l\(n)"] = Double(whole.minX); names["t\(n)"] = Double(whole.minY)
    names["r\(n)"] = Double(whole.maxX); names["b\(n)"] = Double(whole.maxY)
    names["vl\(n)"] = Double(visible.minX); names["vt\(n)"] = Double(visible.minY)
    names["vr\(n)"] = Double(visible.maxX); names["vb\(n)"] = Double(visible.maxY)
    all.append(["n": n, "frame": list(whole), "visible": list(visible), "scale": Double(screen.backingScaleFactor)])
  }
  emit(["kind": "displays", "label": label, "why": why, "t": round3(now()), "displays": all])
}

/// The display with the most room: where a window is given its size before it is put where a step wants it.
func roomy() -> CGPoint {
  var best = CGPoint(x: 12, y: 43)
  var area = 0.0
  var n = 1
  while let left = names["vl\(n)"], let top = names["vt\(n)"], let right = names["vr\(n)"], let bottom = names["vb\(n)"] {
    if (right - left) * (bottom - top) > area {
      area = (right - left) * (bottom - top)
      best = CGPoint(x: left + 2, y: top + 2)
    }
    n += 1
  }
  return best
}

// MARK: Notifications, on a thread of their own

final class Notes: @unchecked Sendable {
  private let lock = NSLock()
  private var all: [(Double, String)] = []
  func add(_ name: String) {
    let time = now()
    lock.lock()
    all.append((time, name))
    lock.unlock()
  }
  func take() -> [(Double, String)] {
    lock.lock()
    defer { lock.unlock() }
    let taken = all
    all = []
    return taken
  }
}
let notes = Notes()

func noted(_ observer: AXObserver, _ element: AXUIElement, _ notification: CFString, _ refcon: UnsafeMutableRawPointer?) {
  notes.add(notification as String)
}

var made: AXObserver?
guard AXObserverCreate(pid, noted, &made) == .success, let observer = made else { fail("cannot observe process \(pid)", 69) }
for name in ["AXMoved", "AXResized"] {
  let error = AXObserverAddNotification(observer, window, name as CFString, nil)
  if error != .success { emit(["kind": "note", "label": label, "text": "cannot subscribe to \(name): AXError \(error.rawValue)"]) }
}
let source = AXObserverGetRunLoopSource(observer)
let listener = Thread {
  CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .defaultMode)
  CFRunLoopRun()
}
listener.start()

/// Lets time pass with the main run loop turning, so that AppKit hears of displays that change.
/// A run loop with nothing to wait for returns at once, and one that has served something returns early: so it is asked until the time is up.
func rest(_ seconds: Double) {
  let deadline = Date().addingTimeInterval(seconds)
  while Date() < deadline {
    if !RunLoop.main.run(mode: .default, before: deadline) { usleep(1000) }
  }
}

// MARK: Calls

var context: [String: Any] = [:]
var serial = 0
var later = false
/// When the last call returned, and when it began.
var returned = 0.0
var begun = 0.0

/// Where the window is 50, 200 and 600 ms after the last call returned, by Accessibility and by the window server.
func looks() -> [[String: Any]] {
  var all: [[String: Any]] = []
  for after in [0.05, 0.2, 0.6] {
    let wait = returned + after - now()
    if wait > 0 { rest(wait) }
    let asked = now()
    let ax = frame(of: window)
    let answered = now()
    let server = serverFrame(of: windowID)
    all.append([
      "after": Int(after * 1000), "axAt": round3((asked - returned) * 1000), "axTook": round3((answered - asked) * 1000), "ax": list(ax),
      "wsAt": round3((answered - returned) * 1000), "ws": list(server),
    ])
  }
  return all
}

enum Call {
  case size(CGSize), position(CGPoint), under(CGPoint)
  var word: String {
    switch self {
    case .size: return "size"
    case .position: return "pos"
    case .under: return "under"
    }
  }
  var asked: [Double] {
    switch self {
    case .size(let size): return [Double(size.width), Double(size.height)]
    case .position(let point), .under(let point): return [Double(point.x), Double(point.y)]
    }
  }
}
/// Where the last position call asked the window to go.
var sentTo = CGPoint.zero

/// Makes the call. With `reads`, says what came of it and returns the frame read back.
@discardableResult
func make(_ call: Call, reads: Bool, quiet: Bool = false) -> CGRect? {
  let before = reads ? frame(of: window) : nil
  let value: AXValue?
  let name: String
  switch call {
  case .size(var size):
    value = AXValueCreate(.cgSize, &size)
    name = "AXSize"
  case .position(var point):
    sentTo = point
    value = AXValueCreate(.cgPoint, &point)
    name = "AXPosition"
  case .under(let offset):
    let pointer = CGEvent(source: nil)?.location ?? .zero
    var point = CGPoint(x: pointer.x - offset.x, y: pointer.y - offset.y)
    sentTo = point
    value = AXValueCreate(.cgPoint, &point)
    name = "AXPosition"
  }
  guard let value else { return nil }
  let start = now()
  let error = AXUIElementSetAttributeValue(window, name as CFString, value)
  let end = now()
  returned = end
  begun = start
  serial += 1
  var line: [String: Any] = [
    "kind": "call", "label": label, "n": serial, "call": call.word, "asked": call.asked, "error": Int(error.rawValue), "t": round3(start),
    "ms": round3((end - start) * 1000),
  ]
  for (key, value) in context { line[key] = value }
  guard reads else {
    if !quiet { emit(line) }
    return nil
  }
  let after = frame(of: window)
  line["before"] = list(before)
  line["ax"] = list(after)
  line["axTook"] = round3((now() - end) * 1000)
  line["ws"] = list(serverFrame(of: windowID))
  if !quiet { emit(line) }
  return after
}

func same(_ a: CGRect?, _ b: CGRect) -> Bool {
  guard let a else { return false }
  return abs(a.minX - b.minX) < 0.01 && abs(a.minY - b.minY) < 0.01 && abs(a.width - b.width) < 0.01 && abs(a.height - b.height) < 0.01
}

/// Puts the window at a frame to start from: its size where there is room for it, then its place. Returns what it has then.
func place(_ rect: CGRect) -> CGRect? {
  make(.position(roomy()), reads: false, quiet: true)
  make(.size(rect.size), reads: false, quiet: true)
  make(.position(rect.origin), reads: false, quiet: true)
  rest(later ? 0.7 : 0.2)
  _ = notes.take()
  return frame(of: window)
}

/// To the microsecond, which no timer on a hosted Mac is: it burns a core for as long.
func spin(until time: Double) { while now() < time {} }

/// After a journey between displays, and after the app has had time to learn where its window is: the frame to the point.
func settle(at rect: CGRect) {
  make(.size(rect.size), reads: false, quiet: true)
  make(.position(rect.origin), reads: false, quiet: true)
  make(.size(rect.size), reads: false, quiet: true)
  spin(until: now() + 0.06)
  _ = notes.take()
}

func turn(_ name: String, from start: CGRect, to target: CGRect, order: String, wait: Double) {
  let placed = frame(of: window)
  let plan: [Call]
  switch order {
  case "PS": plan = [.position(target.origin), .size(target.size)]
  case "SP": plan = [.size(target.size), .position(target.origin)]
  case "SPSS": plan = [.size(target.size), .position(target.origin), .size(target.size), .size(target.size)]
  default: fail("turn knows PS, SP and SPSS, not \(order)")
  }
  var positioned = 0.0
  var waited = 0.0
  let time = now()
  for (index, call) in plan.enumerated() {
    if index == plan.count - 1 {
      let before = returned
      spin(until: before + wait / 1000)
      waited = now() - before
    }
    make(call, reads: false, quiet: true)
    if case .position = call { positioned = returned }
  }
  let atOnce = frame(of: window)
  spin(until: now() + 0.3)
  let atRest = frame(of: window)
  let arrived = notes.take()
  var line: [String: Any] = [
    "kind": "turn", "label": label, "name": name, "order": order, "wait": wait, "waited": round3(waited * 1000),
    "sincePosition": order == "SP" ? NSNull() as Any : round3((begun - positioned) * 1000), "placed": list(placed), "placedRight": same(placed, start), "target": list(target),
    "end": list(atOnce), "rest": list(atRest), "right": same(atRest, target), "ms": round3((returned - time) * 1000),
    "moved": arrived.filter { $0.1 == "AXMoved" }.count, "resized": arrived.filter { $0.1 == "AXResized" }.count,
    "notes": arrived.map { [round3(($0.0 - time) * 1000), $0.1] as [Any] },
  ]
  if let atRest {
    line["short"] = [
      Double(atRest.minX - target.minX), Double(atRest.minY - target.minY), Double(target.width - atRest.width), Double(target.height - atRest.height),
    ]
  }
  for (key, value) in context { line[key] = value }
  emit(line)
}

/// The window by both accounts, the pointer and the button, now.
func glance(since time: Double) -> [String: Any] {
  let asked = now()
  let ax = frame(of: window)
  let answered = now()
  let place = CGEvent(source: nil)?.location
  return [
    "at": round3((asked - time) * 1000), "axTook": round3((answered - asked) * 1000), "ax": list(ax), "ws": list(serverFrame(of: windowID)),
    "pointer": place.map { [Double($0.x), Double($0.y)] as Any } ?? NSNull(), "button": CGEventSource.buttonState(.hidSystemState, button: .left),
  ]
}

func chain(_ name: String, _ plan: [Call], afterRelease: Double?, afterMove: Double?) {
  var line: [String: Any] = ["kind": "hand", "label": label, "name": name]
  if let afterMove {
    let from = CGEvent(source: nil)?.location ?? .zero
    let patience = now() + 15
    var gone = 0.0
    while gone < afterMove, now() < patience {
      let here = CGEvent(source: nil)?.location ?? from
      gone = Double(hypot(here.x - from.x, here.y - from.y))
    }
    line["afterMove"] = afterMove
    line["gone"] = round3(gone)
    line["before"] = glance(since: now())
  } else if let afterRelease {
    let patience = now() + 15
    while CGEventSource.buttonState(.hidSystemState, button: .left), now() < patience {}
    let up = now()
    spin(until: up + afterRelease / 1000)
    line["afterRelease"] = afterRelease
    line["epochRelease"] = epoch(up)
    line["sinceRelease"] = round3((now() - up) * 1000)
  } else {
    line["before"] = glance(since: now())
  }
  _ = notes.take()
  let time = now()
  var made: [[String: Any]] = []
  for call in plan {
    make(call, reads: false, quiet: true)
    var said: [String: Any] = ["call": call.word, "asked": call.asked, "epoch": epoch(begun), "began": round3((begun - time) * 1000), "ms": round3((returned - begun) * 1000)]
    if case .size = call {} else { said["sentTo"] = [Double(sentTo.x), Double(sentTo.y)] }
    made.append(said)
  }
  let last = returned
  line["once"] = glance(since: last)
  var later: [[String: Any]] = []
  for after in [0.05, 0.2, 0.5] {
    spin(until: last + after)
    var seen = glance(since: last)
    seen["after"] = Int(after * 1000)
    later.append(seen)
  }
  line["epoch"] = epoch(time)
  line["calls"] = made
  line["later"] = later
  line["notes"] = notes.take().map { [round3(($0.0 - time) * 1000), $0.1] as [Any] }
  emit(line)
}

func finish(_ name: String, start: CGRect, placed: CGRect?, target: CGRect?, halfway: [Any], began: Double) {
  let atOnce = frame(of: window)
  let atOnceServer = serverFrame(of: windowID)
  let took = now() - began
  let seen = later ? looks() : []
  if !later { rest(0.35) }
  let atRest = frame(of: window)
  let arrived = notes.take()
  var line: [String: Any] = [
    "kind": "result", "label": label, "name": name, "start": list(start), "placed": list(placed), "placedRight": same(placed, start),
    "end": list(atOnce), "endServer": list(atOnceServer), "rest": list(atRest), "restServer": list(serverFrame(of: windowID)),
    "halfway": halfway, "ms": round3(took * 1000), "moved": arrived.filter { $0.1 == "AXMoved" }.count,
    "resized": arrived.filter { $0.1 == "AXResized" }.count,
    "notes": arrived.map { [round3(($0.0 - began) * 1000), $0.1] as [Any] },
  ]
  for (key, value) in context { line[key] = value }
  if later { line["later"] = seen }
  if let target {
    line["target"] = list(target)
    line["right"] = same(atRest, target)
    if let atRest {
      line["short"] = [
        Double(atRest.minX - target.minX), Double(atRest.minY - target.minY), Double(target.width - atRest.width),
        Double(target.height - atRest.height),
      ]
    }
  }
  emit(line)
}

// MARK: The steps

/// `vb1-12.5`: a sum of numbers and names. Nil if it names a display that is not there.
func value(_ text: String) -> Double? {
  var total = 0.0
  var sign = 1.0
  var term = ""
  func endTerm() -> Bool {
    guard !term.isEmpty else { return true }
    guard let number = Double(term) ?? names[term] else { return false }
    total += sign * number
    term = ""
    return true
  }
  for character in text {
    if character == "+" || character == "-" {
      guard endTerm() else { return nil }
      sign = character == "+" ? 1 : -1
    } else {
      term.append(character)
    }
  }
  return endTerm() ? total : nil
}

func rect(_ words: ArraySlice<String>) -> CGRect? {
  let numbers = words.compactMap(value)
  guard numbers.count == 4 else { return nil }
  return CGRect(x: numbers[0], y: numbers[1], width: numbers[2], height: numbers[3])
}

var readsModes = [true]
var orders = ["SPS", "PS", "SP", "sPS"]

func calls(_ order: String, from start: CGRect, to target: CGRect) -> [Call] {
  switch order {
  case "SPS": return [.size(target.size), .position(target.origin), .size(target.size)]
  case "PS": return [.position(target.origin), .size(target.size)]
  case "SP": return [.size(target.size), .position(target.origin)]
  case "sPS":
    let smaller = CGSize(width: min(start.width, target.width), height: min(start.height, target.height))
    return [.size(smaller), .position(target.origin), .size(target.size)]
  default: fail("no such order: \(order)")
  }
}

emit([
  "kind": "window", "label": label, "pid": Int(pid), "window": Int(windowID), "frame": list(frame(of: window)),
  "role": attribute(window, "AXRole") as? String ?? "-", "subrole": attribute(window, "AXSubrole") as? String ?? "-",
  "enhanced": (attribute(app, "AXEnhancedUserInterface") as? Bool).map { $0 as Any } ?? NSNull(),
  "bundle": NSRunningApplication(processIdentifier: pid)?.bundleIdentifier ?? "-",
])
readDisplays("start")

while let raw = readLine() {
  let text = raw.split(separator: "#", maxSplits: 1, omittingEmptySubsequences: false).first.map(String.init) ?? ""
  let words = text.split(separator: " ").map(String.init)
  guard let verb = words.first else { continue }
  switch verb {
  case "round":
    context["round"] = words.dropFirst().joined(separator: " ")
    readDisplays(words.dropFirst().joined(separator: " "))

  case "reads":
    guard words.count == 2 else { fail("reads on|off|both") }
    readsModes = words[1] == "both" ? [true, false] : [words[1] == "on"]

  case "later":
    guard words.count == 2 else { fail("later on|off") }
    later = words[1] == "on"

  case "orders":
    guard words.count == 2 else { fail("orders SPS,PS,SP,sPS") }
    orders = words[1].split(separator: ",").map(String.init)

  case "one":
    guard words.count == 9, ["size", "pos"].contains(words[6]) else { fail("one <name> <x y w h> size|pos <a> <b>: \(text)") }
    guard let start = rect(words[2...5]), let a = value(words[7]), let b = value(words[8]) else {
      emit(["kind": "skipped", "label": label, "name": words[1], "text": text])
      continue
    }
    let placed = place(start)
    context["name"] = words[1]
    context["order"] = words[6]
    let call: Call = words[6] == "size" ? .size(CGSize(width: a, height: b)) : .position(CGPoint(x: a, y: b))
    let from = placed ?? start
    let target =
      words[6] == "size" ? CGRect(origin: from.origin, size: CGSize(width: a, height: b)) : CGRect(origin: CGPoint(x: a, y: b), size: from.size)
    let time = now()
    make(call, reads: true)
    finish(words[1], start: start, placed: placed, target: target, halfway: [], began: time)
    context["name"] = nil
    context["order"] = nil

  case "journey":
    guard words.count == 10 else { fail("journey <name> <x y w h> <x y w h>: \(text)") }
    guard let start = rect(words[2...5]), let target = rect(words[6...9]) else {
      emit(["kind": "skipped", "label": label, "name": words[1], "text": text])
      continue
    }
    for order in orders {
      for reads in readsModes {
        let placed = place(start)
        context["name"] = words[1]
        context["order"] = order
        context["reads"] = reads
        var halfway: [Any] = []
        let time = now()
        for call in calls(order, from: placed ?? start, to: target) {
          let after = make(call, reads: reads)
          if reads { halfway.append(list(after)) }
        }
        finish(words[1], start: start, placed: placed, target: target, halfway: Array(halfway.dropLast()), began: time)
      }
    }
    context["name"] = nil
    context["order"] = nil
    context["reads"] = nil

  case "put":
    guard words.count == 6 else { fail("put <name> <x y w h>: \(text)") }
    guard let wanted = rect(words[2...5]) else { fail("put: \(text)") }
    let placed = place(wanted)
    emit(["kind": "put", "label": label, "name": words[1], "epoch": epoch(now()), "wanted": list(wanted), "ax": list(placed), "ws": list(serverFrame(of: windowID)), "right": same(placed, wanted)])

  case "pause":
    guard words.count == 2, let time = Double(words[1]) else { fail("pause <ms>") }
    spin(until: now() + time / 1000)

  case "look":
    guard words.count == 2 else { fail("look <name>") }
    var line = glance(since: now())
    line["kind"] = "look"
    line["label"] = label
    line["name"] = words[1]
    line["epoch"] = epoch(now())
    line["notes"] = notes.take().count
    emit(line)

  case "chain":
    var rest = Array(words.dropFirst(2))
    var wait: Double?
    var move: Double?
    if rest.first == "after-release", rest.count > 2 {
      wait = Double(rest[1])
      rest.removeFirst(2)
    } else if rest.first == "after-move", rest.count > 2 {
      move = Double(rest[1])
      rest.removeFirst(2)
    }
    var plan: [Call] = []
    while rest.count >= 3, let a = value(rest[1]), let b = value(rest[2]) {
      switch rest[0] {
      case "size": plan.append(.size(CGSize(width: a, height: b)))
      case "pos": plan.append(.position(CGPoint(x: a, y: b)))
      case "under": plan.append(.under(CGPoint(x: a, y: b)))
      default: fail("chain: size, pos or under, not \(rest[0])")
      }
      rest.removeFirst(3)
    }
    guard words.count > 2, !plan.isEmpty, rest.isEmpty else { fail("chain <name> [after-release <ms> | after-move <points>] (size <w> <h> | pos <x> <y> | under <dx> <dy>)…: \(text)") }
    chain(words[1], plan, afterRelease: wait, afterMove: move)

  case "turn":
    guard words.count == 13, let times = Int(words[11]) else { fail("turn <name> <x y w h> <x y w h> <waits> <n> <orders>: \(text)") }
    guard let here = rect(words[2...5]), let there = rect(words[6...9]) else {
      emit(["kind": "skipped", "label": label, "name": words[1], "text": text])
      continue
    }
    let waits = words[10].split(separator: ",").compactMap { Double($0) }
    _ = place(here)
    rest(0.3)
    settle(at: here)
    for round in 1...max(times, 1) {
      context["repeat"] = round
      for wait in waits {
        for order in words[12].split(separator: ",").map(String.init) {
          turn(words[1] + "-there", from: here, to: there, order: order, wait: wait)
          settle(at: there)
          turn(words[1] + "-back", from: there, to: here, order: order, wait: wait)
          settle(at: here)
        }
      }
    }
    context["repeat"] = nil

  default:
    fail("no such step: \(text)")
  }
}
readDisplays("end")
exit(0)
