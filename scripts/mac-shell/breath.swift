// breath: gives several apps' windows new frames through Accessibility in one of three ways, and says how long the display
// showed something in between. For scripts/mac-shell/probe-breath.sh. Arbor is not involved: this asks macOS what is possible.
//
//   breath <way> <rounds | grid | pile> <pid>…
//     one-by-one    as Arbor does today: a window at a time, each answer waited for (size, position, size, then the frame read back)
//     side-by-side  a thread to an app; within an app a window at a time; the caller waits for all of them
//     no-wait       every size and position is sent with a time limit of a millisecond, so that nobody is waited for (a call that
//                   times out is still delivered); then the limit is put back and every frame is read, which waits for its app
//     one-by-one-in-two, side-by-side-in-two    the same with two calls where two will do: what grows is moved and then grows, what
//                   shrinks shrinks and is then moved, so that no state lies outside both the old frame and the new
//
//   BREATH_OBSERVED=main | thread    listen to the windows' moves and resizes meanwhile, as Arbor does: with the listener on the main run
//                   loop, which stands still while the main thread waits for an answer (Arbor today), or on a thread of its own, which
//                   never does. Does an app that has somebody to tell take longer to answer, and does it matter who is listening?
//
//   BREATH_GUARD=1  before each window its APP is asked whether assistive tools have "enhanced user interface" on, as Arbor asks
//   BREATH_REST=2   so many seconds of rest after each round (0.4): an app that is left alone for a while may be slower to answer
//   BREATH_EACH=1   also say how long each window took
//   BREATH_PILE=700x480   the size of the windows in the pile (420x300): real apps have minimum sizes
//
// Each round takes the windows from a pile to a grid or back. `grid` or `pile` for a number: that one act from wherever the windows
// are, for a film. Meanwhile a thread of its own asks the window server for these windows'
// bounds as fast as it answers. A line a round: how long the calls took, when the first and the last change showed, in how many
// sixtieths of a second something changed ("pieces"), and how many windows ended where they were sent.
//
// A script compiles it itself (swiftc -O -swift-version 5 scripts/mac-shell/breath.swift -o …). Needs Accessibility.

import AppKit
import ApplicationServices

func fail(_ message: String) -> Never {
  FileHandle.standardError.write(Data("breath: \(message)\n".utf8))
  exit(64)
}

@_silgen_name("_AXUIElementGetWindow")
func _AXUIElementGetWindow(_ element: AXUIElement, _ identifier: UnsafeMutablePointer<CGWindowID>) -> AXError

struct Window {
  var pid: pid_t
  var id: CGWindowID
  var element: AXUIElement
}

func windows(of pid: pid_t) -> [Window] {
  var value: CFTypeRef?
  guard AXUIElementCopyAttributeValue(AXUIElementCreateApplication(pid), kAXWindowsAttribute as CFString, &value) == .success,
    let items = value as? [AnyObject]
  else { return [] }
  return items.compactMap { item in
    guard CFGetTypeID(item) == AXUIElementGetTypeID() else { return nil }
    let element = item as! AXUIElement
    var id = CGWindowID(0)
    guard _AXUIElementGetWindow(element, &id) == .success, id != 0 else { return nil }
    return Window(pid: pid, id: id, element: element)
  }
}

@discardableResult func set(_ element: AXUIElement, size: CGSize) -> AXError {
  var size = size
  guard let value = AXValueCreate(.cgSize, &size) else { return .failure }
  return AXUIElementSetAttributeValue(element, kAXSizeAttribute as CFString, value)
}

@discardableResult func set(_ element: AXUIElement, position: CGPoint) -> AXError {
  var position = position
  guard let value = AXValueCreate(.cgPoint, &position) else { return .failure }
  return AXUIElementSetAttributeValue(element, kAXPositionAttribute as CFString, value)
}

func frame(of element: AXUIElement) -> CGRect? {
  var position: CFTypeRef?
  var size: CFTypeRef?
  guard AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &position) == .success,
    AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &size) == .success,
    let position, let size
  else { return nil }
  var rect = CGRect.zero
  AXValueGetValue(position as! AXValue, .cgPoint, &rect.origin)
  AXValueGetValue(size as! AXValue, .cgSize, &rect.size)
  return rect
}

func now() -> Double { ProcessInfo.processInfo.systemUptime }

nonisolated(unsafe) var inTwo = false
let guarded = ProcessInfo.processInfo.environment["BREATH_GUARD"] != nil
let pause = Double(ProcessInfo.processInfo.environment["BREATH_REST"] ?? "") ?? 0.4
let sayEach = ProcessInfo.processInfo.environment["BREATH_EACH"] != nil
nonisolated(unsafe) var guardTook: [Double] = []

/// As `AXWindowSystem.setFrame` does it for a window that changes its size (`FramePlan.full`), or in two calls.
func move(_ window: Window, to target: CGRect) {
  if guarded {
    let began = now()
    var value: CFTypeRef?
    _ = AXUIElementCopyAttributeValue(AXUIElementCreateApplication(window.pid), "AXEnhancedUserInterface" as CFString, &value)
    // Only where one thread does it all.
    if sayEach { guardTook.append((now() - began) * 1000) }
  }
  if inTwo, let now = frame(of: window.element) {
    let (grows, shrinks) = (
      target.width >= now.width && target.height >= now.height, target.width <= now.width && target.height <= now.height
    )
    if grows {
      set(window.element, position: target.origin)
      set(window.element, size: target.size)
    } else if shrinks {
      set(window.element, size: target.size)
      set(window.element, position: target.origin)
    } else {
      set(window.element, size: CGSize(width: min(now.width, target.width), height: min(now.height, target.height)))
      set(window.element, position: target.origin)
      set(window.element, size: target.size)
    }
  } else {
    set(window.element, size: target.size)
    set(window.element, position: target.origin)
    set(window.element, size: target.size)
  }
  _ = frame(of: window.element)
}

// MARK: What the window server shows

final class Watcher: @unchecked Sendable {
  private let ids: [CGWindowID]
  private let lock = NSLock()
  private var changes: [(at: Double, id: CGWindowID, bounds: CGRect)] = []
  private var looks = 0
  private var stopped = false

  init(_ ids: [CGWindowID]) { self.ids = ids }

  /// A question a window: the whole list takes a hosted Mac 25 ms, which is more than there is to measure.
  static func bounds(of ids: [CGWindowID]) -> [CGWindowID: CGRect] {
    var found: [CGWindowID: CGRect] = [:]
    for id in ids {
      guard let list = CGWindowListCopyWindowInfo([.optionIncludingWindow], id) as? [[String: Any]], let entry = list.first,
        let box = entry[kCGWindowBounds as String] as? NSDictionary, let rect = CGRect(dictionaryRepresentation: box as CFDictionary)
      else { continue }
      found[id] = rect
    }
    return found
  }

  func start() {
    let thread = Thread { [self] in
      var last = Self.bounds(of: ids)
      while true {
        let seen = Self.bounds(of: ids)
        let at = now()
        lock.lock()
        looks += 1
        for (id, rect) in seen where last[id] != rect { changes.append((at, id, rect)) }
        let done = stopped
        lock.unlock()
        last = seen
        if done { return }
      }
    }
    thread.qualityOfService = .userInteractive
    thread.start()
  }

  func stop() -> (changes: [(at: Double, id: CGWindowID, bounds: CGRect)], looks: Int) {
    lock.lock()
    defer { lock.unlock() }
    stopped = true
    return (changes, looks)
  }
}

// MARK: Listening, as Arbor does

nonisolated(unsafe) var heard = 0
nonisolated(unsafe) var observers: [AXObserver] = []

func listen(to windows: [Window], on loop: CFRunLoop) {
  for (pid, own) in Dictionary(grouping: windows, by: \.pid) {
    var made: AXObserver?
    guard AXObserverCreate(pid, { _, _, _, _ in heard += 1 }, &made) == .success, let observer = made else { continue }
    for window in own {
      AXObserverAddNotification(observer, window.element, kAXMovedNotification as CFString, nil)
      AXObserverAddNotification(observer, window.element, kAXResizedNotification as CFString, nil)
    }
    CFRunLoopAddSource(loop, AXObserverGetRunLoopSource(observer), .commonModes)
    observers.append(observer)
  }
}

// MARK: The rounds

let arguments = Array(CommandLine.arguments.dropFirst())
guard arguments.count >= 3, let rounds = ["grid": 1, "pile": 1][arguments[1]] ?? Int(arguments[1]), rounds > 0 else {
  fail("usage: breath <one-by-one|side-by-side|no-wait|one-by-one-in-two|side-by-side-in-two> <rounds|grid|pile> <pid>…")
}
let oneAct = Int(arguments[1]) == nil ? arguments[1] : nil
inTwo = arguments[0].hasSuffix("-in-two")
let name = arguments[0]
let way = inTwo ? String(name.dropLast("-in-two".count)) : name
guard ["one-by-one", "side-by-side", "no-wait"].contains(way), !(inTwo && way == "no-wait") else { fail("no such way: \(name)") }
guard AXIsProcessTrusted() else { fail("no Accessibility permission") }
let all = arguments.dropFirst(2).compactMap { pid_t($0) }.flatMap { windows(of: $0) }
guard all.count > 1 else { fail("found \(all.count) windows") }
for window in all { AXUIElementSetMessagingTimeout(window.element, 1) }

guard let screen = NSScreen.main else { fail("no display") }
// Global coordinates with the origin at the top left, as Accessibility and the window server have them.
let visible = CGRect(
  x: screen.visibleFrame.minX, y: screen.frame.maxY - screen.visibleFrame.maxY, width: screen.visibleFrame.width,
  height: screen.visibleFrame.height)
let columns = Int(Double(all.count).squareRoot().rounded(.up))
let rows = (all.count + columns - 1) / columns
let cell = CGSize(width: (visible.width / CGFloat(columns)).rounded(.down), height: (visible.height / CGFloat(rows)).rounded(.down))
let grid = all.indices.map { index in
  CGRect(
    x: visible.minX + CGFloat(index % columns) * cell.width, y: visible.minY + CGFloat(index / columns) * cell.height,
    width: cell.width - 8, height: cell.height - 8)
}
let piled = (ProcessInfo.processInfo.environment["BREATH_PILE"] ?? "420x300").split(separator: "x").compactMap { Double($0) }
guard piled.count == 2 else { fail("BREATH_PILE: <width>x<height>") }
let pile = all.indices.map { index in
  CGRect(x: visible.minX + 40 + CGFloat(index) * 24, y: visible.minY + 30 + CGFloat(index) * 20, width: piled[0], height: piled[1])
}
let apps = Dictionary(grouping: all.indices, by: { all[$0].pid }).values.map { $0.sorted() }.sorted { $0[0] < $1[0] }

let observed = ProcessInfo.processInfo.environment["BREATH_OBSERVED"] ?? "nobody"
switch observed {
case "main":
  listen(to: all, on: CFRunLoopGetMain())
case "thread":
  let ready = DispatchSemaphore(value: 0)
  let thread = Thread {
    listen(to: all, on: CFRunLoopGetCurrent())
    ready.signal()
    CFRunLoopRun()
  }
  thread.qualityOfService = .userInteractive
  thread.start()
  ready.wait()
default:
  break
}
/// Between two acts the main run loop turns, as an app's does.
func rest(_ seconds: Double) {
  if observed == "main" { CFRunLoopRunInMode(.defaultMode, seconds, false) } else { Thread.sleep(forTimeInterval: seconds) }
}

if oneAct == nil {
  for (index, window) in all.enumerated() { move(window, to: pile[index]) }
  rest(0.5)
}
print("\(name), \(observed) listening: \(all.count) windows of \(apps.count) apps, cells of \(Int(cell.width))×\(Int(cell.height))")

for round in 1...rounds {
  let toTheGrid = oneAct.map { $0 == "grid" } ?? (round % 2 == 1)
  let targets = toTheGrid ? grid : pile
  let watcher = Watcher(all.map(\.id))
  watcher.start()
  rest(0.1)
  let before = heard
  var each: [Double] = []
  guardTook = []
  let began = now()
  var sent = began
  switch way {
  case "one-by-one":
    for (index, window) in all.enumerated() {
      let before = now()
      move(window, to: targets[index])
      each.append((now() - before) * 1000)
    }
  case "side-by-side":
    DispatchQueue.concurrentPerform(iterations: apps.count) { app in
      for index in apps[app] { move(all[index], to: targets[index]) }
    }
  default:
    for window in all { AXUIElementSetMessagingTimeout(window.element, 0.001) }
    for (index, window) in all.enumerated() {
      set(window.element, size: targets[index].size)
      set(window.element, position: targets[index].origin)
      set(window.element, size: targets[index].size)
    }
    sent = now()
    for window in all { AXUIElementSetMessagingTimeout(window.element, 1) }
    for window in all { _ = frame(of: window.element) }
  }
  let answered = now()
  rest(max(pause, 0.4))
  let (changes, looks) = watcher.stop()
  let final = Watcher.bounds(of: all.map(\.id))
  let arrived = all.indices.filter { index in
    guard let rect = final[all[index].id] else { return false }
    return abs(rect.minX - targets[index].minX) <= 1 && abs(rect.minY - targets[index].minY) <= 1
      && abs(rect.width - targets[index].width) <= 1 && abs(rect.height - targets[index].height) <= 1
  }.count
  func ms(_ time: Double) -> String { String(format: "%.1f", (time - began) * 1000) }
  let after = changes.filter { $0.at >= began }
  let pieces = Set(after.map { Int(($0.at - began) * 60) }).count
  let span = after.isEmpty ? "-" : String(format: "%.1f", (after.last!.at - after.first!.at) * 1000)
  print(
    "  round \(round) to the \(toTheGrid ? "grid" : "pile"): answered \(ms(answered)) ms"
      + (way == "no-wait" ? " (sent \(ms(sent)))" : "")
      + ", first change \(after.first.map { ms($0.at) } ?? "-"), last \(after.last.map { ms($0.at) } ?? "-"), span \(span) ms, "
      + "\(pieces) pieces, \(after.count) changes, \(arrived) of \(all.count) arrived, \(looks) looks, \(heard - before) heard")
  if sayEach, !each.isEmpty {
    print("    each window, ms: " + each.map { String(format: "%.1f", $0) }.joined(separator: " "))
    if guarded { print("    of that the question to its app: " + guardTook.map { String(format: "%.1f", $0) }.joined(separator: " ")) }
  }
}
