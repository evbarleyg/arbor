// glide: sets a real window's frame once for every frame of the display, through Accessibility, and writes down what every asking cost.
// For scripts/mac-shell/probe-glide.sh, which compiles it (swiftc -O -swift-version 5); judge-glide.py reads what it writes.
//
// Arbor shows a change of layout as cards that glide on a stage while the real windows are moved once, underneath. macOS's own tiling moves the window
// itself: it glides and grows for 0.3 s, a new frame with every frame of the display, all four edges in step. For Arbor to do as much without a picture of
// the window, and so without Screen Recording, it has to ask the app again and again. This does that and nothing else: no Arbor, no stage.
// Needs Accessibility. It knows windows by their numbers and never reads a title.
//
//   glide <log> <act> [--steps n] [--duration seconds] [--order place-first|size-first|by-edges] <window>:<x>,<y>,<w>,<h> [<window>:<x>,<y>,<w>,<h>…]
//   glide <log> <act> --menu "Window/Move & Resize/Left" <window>
//
// THE FIRST WINDOW GLIDES: step k of n is due k/n of the duration after the start, with the frame Arbor's own curve has reached by then. A step that is late is
// made all the same. THE OTHERS JUMP: each is set once, at the start, from a thread of their own, so that no slow app keeps the glide waiting.
//   --steps 1 --duration 0    the control: the window is set once, which is what Arbor does with its motion off
//   --menu                    the bar: that item of the app's own menu is pressed, and macOS moves the window. Nothing is asked for; 0.8 s later the frame is read
//
// PLACE AND SIZE ARE TWO ASKINGS, and the display can show a frame between them: the new place with the old size, or the old place with the new size. The near
// edges (left, top) are right either way: they are where they were or where they are going. The far edges may not be. Along one axis, with the near edge moving
// by n and the width changing by d, the far edge is to go n + d, and between the askings it stands n from where it was (place first) or d (size first). With n and d
// of one sign (to the right and growing, to the left and shrinking) that is on its road either way. Otherwise it is beyond both ends of its road, with either order:
//   place first   outwards if the window shrinks while its near edge moves inwards (d < 0 < n), inwards if it grows while that edge moves outwards (n < 0 < d)
//   size first    the other way round
// Outwards it lies over whatever is beside the window; inwards it lets a strip of what is behind show. So A WINDOW THAT GROWS IS PLACED FIRST, ONE THAT SHRINKS IS SIZED
// FIRST: then nothing ever lies outside the two frames together. `by-edges` reckons for both orders how far outwards a far edge would lie, on either axis, and takes the
// lesser (place first if they are alike), anew at every step. WHAT NO ORDER CAN MEND is the giving way inwards, by the lesser of |n| and |d|: so wherever the far
// edge is to stand still while the near one moves.
// An asking that would change nothing on the whole road is never made: a window that keeps its size is only placed.
//
// What is added to the log, one line each, `<milliseconds since 1970> <kind> <act> …`, on the clock sampler.swift writes its samples by:
//   act <act> <steps> <duration ms> <order>          before the first asking. Of the bar: 0 0 macos
//   ask <act> <window> <pid> glides|jumps <x y w h> <x y w h>      the frame the window has, and the frame asked for (of the bar: the one it had in the end)
//   call <act> <window> place|size <step> <took ms> <AXError> <late ms> <x y w h>
//                                                    at the moment the asking began, which is <late ms> after the step was due; the frame of that step.
//                                                    AXError 0 is success, -25204 an app that did not answer within a second
//   read <act> <window> <took ms> <x y w h>          the frame read back when the last asking had returned
//   sum <act> <window> <askings> <mean ms> <p95 ms> <worst ms> <late ms, all together> <points between the frame read back and the one asked for>
//   done <act> <ms of processor time this process used>

import Foundation

#if os(macOS)
  import ApplicationServices
#endif

func fail(_ message: String, code: Int32 = 64) -> Never {
  FileHandle.standardError.write(Data("glide: \(message)\n".utf8))
  exit(code)
}

// MARK: The clock and the curve

let wallAtStart = Date().timeIntervalSince1970 * 1000
let ticksAtStart = DispatchTime.now().uptimeNanoseconds
/// Milliseconds since 1970, as the sampler counts them, told on by a clock that nobody sets.
func now() -> Double { wallAtStart + Double(DispatchTime.now().uptimeNanoseconds - ticksAtStart) / 1_000_000 }

func processorTime() -> Double {
  var time = timespec()
  clock_gettime(CLOCK_PROCESS_CPUTIME_ID, &time)
  return Double(time.tv_sec) * 1000 + Double(time.tv_nsec) / 1_000_000
}

/// `Transition.curve` in Sources/ArborCore/Transition.swift, the curve of every motion in Arbor: the control points of a cubic Bézier timing function.
let curve = (x1: 0.2, y1: 0.0, x2: 0.0, y2: 1.0)

/// How much of the road is behind after that much of the time.
func eased(_ progress: Double) -> Double {
  func bezier(_ t: Double, _ first: Double, _ second: Double) -> Double {
    3 * (1 - t) * (1 - t) * t * first + 3 * (1 - t) * t * t * second + t * t * t
  }
  var (low, high) = (0.0, 1.0)
  for _ in 0..<40 {
    let middle = (low + high) / 2
    if bezier(middle, curve.x1, curve.x2) < progress { low = middle } else { high = middle }
  }
  return bezier((low + high) / 2, curve.y1, curve.y2)
}

/// Whole points, as Arbor asks for. Edges are rounded, not sizes: an edge that stands still stands still at every step.
func onTheRoad(from: CGRect, to: CGRect, atStep step: Int, of steps: Int) -> CGRect {
  if step >= steps { return to }
  let share = CGFloat(eased(Double(step) / Double(steps)))
  func between(_ a: CGFloat, _ b: CGFloat) -> CGFloat { (a + (b - a) * share).rounded() }
  let (left, top) = (between(from.minX, to.minX), between(from.minY, to.minY))
  return CGRect(x: left, y: top, width: between(from.maxX, to.maxX) - left, height: between(from.maxY, to.maxY) - top)
}

/// The rule in the header. How far beyond both frames a far edge would lie between the two askings.
func placeComesFirst(from: CGRect, to: CGRect, order: String) -> Bool {
  if order != "by-edges" { return order == "place-first" }
  func overshoot(_ between: CGFloat, _ a: CGFloat, _ b: CGFloat) -> CGFloat { max(between - max(a, b), 0) }
  let placed = max(overshoot(to.minX + from.width, from.maxX, to.maxX), overshoot(to.minY + from.height, from.maxY, to.maxY))
  let sized = max(overshoot(from.minX + to.width, from.maxX, to.maxX), overshoot(from.minY + to.height, from.maxY, to.maxY))
  return placed <= sized
}

// MARK: A window

#if os(macOS)
  /// The window server's number for an Accessibility window; Arbor uses the same call (AX/AXHelpers.swift).
  @_silgen_name("_AXUIElementGetWindow")
  func _AXUIElementGetWindow(_ element: AXUIElement, _ identifier: UnsafeMutablePointer<CGWindowID>) -> AXError

  func children(of element: AXUIElement) -> [AXUIElement] {
    var value: CFTypeRef?
    guard AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &value) == .success else { return [] }
    return (value as? [AXUIElement]) ?? []
  }

  struct Window {
    let number: UInt32
    let pid: Int32
    private let element: AXUIElement

    init?(number: UInt32) {
      let list = (CGWindowListCopyWindowInfo([.optionIncludingWindow], number) as? [[String: Any]]) ?? []
      guard let pid = (list.first?[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value else { return nil }
      var value: CFTypeRef?
      guard AXUIElementCopyAttributeValue(AXUIElementCreateApplication(pid), kAXWindowsAttribute as CFString, &value) == .success,
        let windows = value as? [AXUIElement],
        let element = windows.first(where: { window in
          var found = CGWindowID(0)
          return _AXUIElementGetWindow(window, &found) == .success && found == number
        })
      else { return nil }
      // As long as Arbor waits for an app (AXWindowSystem.messagingTimeout).
      AXUIElementSetMessagingTimeout(element, 1)
      self.number = number
      self.pid = pid
      self.element = element
    }

    func frame() -> CGRect? {
      var origin = CGPoint.zero
      var size = CGSize.zero
      var value: CFTypeRef?
      guard AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &value) == .success, let position = value,
        AXValueGetValue(position as! AXValue, .cgPoint, &origin),
        AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &value) == .success, let extent = value,
        AXValueGetValue(extent as! AXValue, .cgSize, &size)
      else { return nil }
      return CGRect(origin: origin, size: size)
    }

    func set(position: CGPoint) -> Int32 {
      var point = position
      guard let boxed = AXValueCreate(.cgPoint, &point) else { return AXError.failure.rawValue }
      return AXUIElementSetAttributeValue(element, kAXPositionAttribute as CFString, boxed).rawValue
    }

    func set(size: CGSize) -> Int32 {
      var extent = size
      guard let boxed = AXValueCreate(.cgSize, &extent) else { return AXError.failure.rawValue }
      return AXUIElementSetAttributeValue(element, kAXSizeAttribute as CFString, boxed).rawValue
    }

    /// Presses an item of the app's menu bar, found by the titles on the way to it. A menu's items are the children of its one child.
    func press(menu titles: [String]) -> Bool {
      var value: CFTypeRef?
      guard AXUIElementCopyAttributeValue(AXUIElementCreateApplication(pid), kAXMenuBarAttribute as CFString, &value) == .success, let bar = value
      else { return false }
      var items = children(of: bar as! AXUIElement)
      for (depth, title) in titles.enumerated() {
        guard
          let item = items.first(where: { item in
            var name: CFTypeRef?
            return AXUIElementCopyAttributeValue(item, kAXTitleAttribute as CFString, &name) == .success && name as? String == title
          })
        else { return false }
        if depth == titles.count - 1 { return AXUIElementPerformAction(item, kAXPressAction as CFString) == .success }
        items = children(of: item).first.map { children(of: $0) } ?? []
      }
      return false
    }
  }
#else
  /// A rehearsal on Linux (rehearse.sh) runs this very tool, so that all of it but the struct above has run before it meets a Mac. There a window
  /// is a file, as rehearse/real-apps makes them and says: `pid bundle-id x y w h <ms its app takes to answer> [fixed-size]`.
  struct Window {
    let number: UInt32
    let pid: Int32
    private let path: String

    init?(number: UInt32) {
      path = (ProcessInfo.processInfo.environment["ARBOR_REHEARSAL_DIR"] ?? ".") + "/apps/\(number)"
      self.number = number
      guard let text = try? String(contentsOfFile: path, encoding: .utf8), let pid = Int32(text.split(separator: " ").first ?? "") else { return nil }
      self.pid = pid
    }

    private func fields() -> [String] {
      ((try? String(contentsOfFile: path, encoding: .utf8)) ?? "").split(whereSeparator: { $0 == " " || $0 == "\n" }).map(String.init)
    }

    func frame() -> CGRect? {
      let numbers = fields().dropFirst(2).prefix(4).compactMap(Double.init)
      return numbers.count == 4 ? CGRect(x: numbers[0], y: numbers[1], width: numbers[2], height: numbers[3]) : nil
    }

    private func put(_ values: [CGFloat], at index: Int) -> Int32 {
      var all = fields()
      guard all.count >= 7 else { return -25202 }
      Thread.sleep(forTimeInterval: (Double(all[6]) ?? 0) / 1000)
      for (offset, value) in values.enumerated() { all[index + offset] = String(Int(value)) }
      return (try? all.joined(separator: " ").write(toFile: path, atomically: true, encoding: .utf8)) == nil ? -25200 : 0
    }

    func set(position: CGPoint) -> Int32 { put([position.x, position.y], at: 2) }
    // As a real app of one size answers: all is well, and nothing has changed.
    func set(size: CGSize) -> Int32 { put(fields().count > 7 ? [] : [size.width, size.height], at: 4) }

    /// As macOS tiles: place and size at once, eighteen times in 0.3 s, into the left half of a small display.
    func press(menu titles: [String]) -> Bool {
      guard let from = frame() else { return false }
      for step in 1...18 {
        Thread.sleep(forTimeInterval: 0.3 / 18)
        let next = onTheRoad(from: from, to: CGRect(x: 0, y: 31, width: 512, height: 674), atStep: step, of: 18)
        _ = put([next.minX, next.minY, next.width, next.height], at: 2)
      }
      return true
    }
  }
#endif

// MARK: What was asked for

let usage = """
  usage: glide <log> <act> [--steps n] [--duration seconds] [--order place-first|size-first|by-edges] <window>:<x>,<y>,<w>,<h>…
         glide <log> <act> --menu "Window/Move & Resize/Left" <window>
  """
var words = Array(CommandLine.arguments.dropFirst())

func option(_ name: String) -> String? {
  guard let index = words.firstIndex(of: name) else { return nil }
  guard words.count > index + 1 else { fail(usage) }
  defer { words.removeSubrange(index...(index + 1)) }
  return words[index + 1]
}

guard let steps = Int(option("--steps") ?? "18"), steps >= 1, steps <= 240 else { fail("--steps takes a number from 1 to 240") }
guard let seconds = Double(option("--duration") ?? "0.3"), seconds >= 0, seconds <= 5 else { fail("--duration takes 0 to 5 seconds") }
let order = option("--order") ?? "by-edges"
guard ["place-first", "size-first", "by-edges"].contains(order) else { fail("--order takes place-first, size-first or by-edges") }
let menu = option("--menu")
guard words.count >= 3 else { fail(usage) }
let (logPath, act) = (words[0], words[1])
let duration = seconds * 1000

struct Target {
  let window: Window
  let from: CGRect
  let to: CGRect
}

let targets: [Target] = words.dropFirst(2).map { word in
  let halves = word.split(separator: ":")
  let numbers = (halves.count == 2 ? halves[1] : "").split(separator: ",").compactMap { Double($0) }
  guard let number = UInt32(halves.first ?? ""), numbers.count == (menu == nil ? 4 : 0) else { fail("\(word)?\n\(usage)") }
  guard let window = Window(number: number), let from = window.frame() else {
    fail("no app lists a window \(number) to Accessibility, or it does not say where it is", code: 1)
  }
  return Target(window: window, from: from, to: menu == nil ? CGRect(x: numbers[0], y: numbers[1], width: numbers[2], height: numbers[3]) : from)
}

// MARK: The journal

func text(_ value: Double) -> String { String(format: "%.2f", value) }
func text(_ value: CGFloat) -> String { Double(value) == Double(value).rounded() ? String(Int(value)) : String(format: "%.1f", Double(value)) }
func text(_ rect: CGRect) -> String { "\(text(rect.minX)) \(text(rect.minY)) \(text(rect.width)) \(text(rect.height))" }

/// Kept in memory until all is over: no asking waits for the disk.
final class Journal {
  private let lock = NSLock()
  private var lines: [(time: Double, text: String)] = []
  private var calls: [UInt32: [(took: Double, late: Double)]] = [:]

  func note(_ time: Double, _ text: String) {
    lock.lock()
    lines.append((time, text))
    lock.unlock()
  }

  func call(_ window: UInt32, _ kind: String, step: Int, began: Double, due: Double, error: Int32, _ frame: CGRect) {
    let took = now() - began
    note(began, "call \(act) \(window) \(kind) \(step) \(text(took)) \(error) \(text(began - due)) \(text(frame))")
    lock.lock()
    calls[window, default: []].append((took, began - due))
    lock.unlock()
  }

  func calls(of window: UInt32) -> [(took: Double, late: Double)] { calls[window] ?? [] }

  func write(to path: String) {
    // Stable: lines of one moment stay in the order they were noted in.
    let sorted = lines.enumerated().sorted { ($0.element.time, $0.offset) < ($1.element.time, $1.offset) }
    let all = sorted.map { "\(text($0.element.time)) \($0.element.text)\n" }.joined()
    guard let file = fopen(path, "a") else { fail("cannot write to \(path)", code: 1) }
    fputs(all, file)
    fclose(file)
  }
}

let journal = Journal()

#if os(macOS)
  // A process without a window is put to sleep between its timers, which are run together with others' (sampler.swift met the same).
  let awake = ProcessInfo.processInfo.beginActivity(options: [.userInitiated, .latencyCritical], reason: "moving windows by the clock")
#endif

// MARK: The bar: macOS moves the window

if let menu {
  let target = targets[0]
  let began = now()
  journal.note(began, "act \(act) 0 0 macos")
  guard target.window.press(menu: menu.split(separator: "/").map(String.init)) else { fail("the app's menu bar has no item \(menu), or it cannot be pressed", code: 1) }
  Thread.sleep(forTimeInterval: 0.8)
  let end = target.window.frame() ?? target.from
  journal.note(began, "ask \(act) \(target.window.number) \(target.window.pid) glides \(text(target.from)) \(text(end))")
  journal.note(now(), "done \(act) \(text(processorTime()))")
  journal.write(to: logPath)
  print("glide \(act): macOS took w\(target.window.number) from \(text(target.from)) to \(text(end))")
  exit(0)
}

// MARK: The journey

/// One step for one window: the askings that the road needs, in the order that suits this step.
@Sendable func set(_ target: Target, from last: CGRect, to next: CGRect, step: Int, due: Double) {
  let place = { () -> Void in
    guard target.from.origin != target.to.origin else { return }
    let began = now()
    journal.call(target.window.number, "place", step: step, began: began, due: due, error: target.window.set(position: next.origin), next)
  }
  let size = { () -> Void in
    guard target.from.size != target.to.size else { return }
    let began = now()
    journal.call(target.window.number, "size", step: step, began: began, due: due, error: target.window.set(size: next.size), next)
  }
  if placeComesFirst(from: last, to: next, order: order) { place(); size() } else { size(); place() }
}

journal.note(now(), "act \(act) \(steps) \(Int(duration)) \(order)")
for (index, target) in targets.enumerated() {
  journal.note(now(), "ask \(act) \(target.window.number) \(target.window.pid) \(index == 0 ? "glides" : "jumps") \(text(target.from)) \(text(target.to))")
}
let start = now()
let arrived = DispatchGroup()
func onAThread(_ work: @escaping @Sendable () -> Void) {
  arrived.enter()
  let thread = Thread {
    work()
    arrived.leave()
  }
  thread.qualityOfService = .userInteractive
  thread.start()
}
onAThread {
  let target = targets[0]
  var last = target.from
  for step in 1...steps {
    let due = start + duration * Double(step) / Double(steps)
    let early = due - now()
    if early > 0 { Thread.sleep(forTimeInterval: early / 1000) }
    let next = onTheRoad(from: target.from, to: target.to, atStep: step, of: steps)
    set(target, from: last, to: next, step: step, due: due)
    last = next
  }
}
if targets.count > 1 {
  onAThread { for target in targets.dropFirst() { set(target, from: target.from, to: target.to, step: 1, due: start) } }
}
arrived.wait()

var said: [String] = []
for target in targets {
  let began = now()
  let end = target.window.frame() ?? .null
  journal.note(began, "read \(act) \(target.window.number) \(text(now() - began)) \(end.isNull ? "? ? ? ?" : text(end))")
  let calls = journal.calls(of: target.window.number)
  let took = calls.map(\.took).sorted()
  let mean = took.reduce(0, +) / Double(max(took.count, 1))
  let p95 = took.isEmpty ? 0 : took[max(Int((Double(took.count) * 0.95).rounded(.up)) - 1, 0)]
  let late = calls.map { max($0.late, 0) }.reduce(0, +)
  let off =
    end.isNull
    ? -1 : Double(max(abs(end.minX - target.to.minX), abs(end.minY - target.to.minY), abs(end.maxX - target.to.maxX), abs(end.maxY - target.to.maxY)))
  journal.note(
    now(), "sum \(act) \(target.window.number) \(calls.count) \(text(mean)) \(text(p95)) \(text(took.last ?? 0)) \(text(late)) \(text(off))")
  said.append("w\(target.window.number) \(calls.count) askings, \(text(mean)) ms each, the worst \(text(took.last ?? 0)), off by \(text(off))")
}
journal.note(now(), "done \(act) \(text(processorTime()))")
journal.write(to: logPath)
print("glide \(act): \(steps) steps in \(Int(duration)) ms, \(order): \(said.joined(separator: "; "))")
