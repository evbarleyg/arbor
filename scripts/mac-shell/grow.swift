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

func emit(_ object: [String: Any]) {
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
  : listed.first { number(of: $0) == CGWindowID(arguments[1]) ?? 0 }
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
func rest(_ seconds: Double) { RunLoop.main.run(until: Date().addingTimeInterval(seconds)) }

// MARK: Calls

var context: [String: Any] = [:]
var serial = 0
var later = false
/// When the last call returned.
var returned = 0.0

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
  case size(CGSize), position(CGPoint)
  var word: String { if case .size = self { return "size" } else { return "pos" } }
  var asked: [Double] {
    switch self {
    case .size(let size): return [Double(size.width), Double(size.height)]
    case .position(let point): return [Double(point.x), Double(point.y)]
    }
  }
}

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
    value = AXValueCreate(.cgPoint, &point)
    name = "AXPosition"
  }
  guard let value else { return nil }
  let start = now()
  let error = AXUIElementSetAttributeValue(window, name as CFString, value)
  let end = now()
  returned = end
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

  default:
    fail("no such step: \(text)")
  }
}
readDisplays("end")
exit(0)
