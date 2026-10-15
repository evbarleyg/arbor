// glide: moves real windows along a straight road in steps, through Accessibility, and writes down what every call cost.
// For scripts/mac-shell/probe-glide.sh, which compiles it (swiftc -O -swift-version 5); judge-glide.py reads what it writes.
//
// Arbor shows a change of layout as cards that glide on a stage while the real windows are moved once, underneath. For the window itself to
// be seen moving, without a picture of it and so without Screen Recording, it has to be moved many times. This does that and nothing else:
// no Arbor, no stage. Needs Accessibility. It knows windows by their numbers and never reads a title.
//
//   glide <log> <act> [--steps n] [--duration seconds] [--order by-window|threads] <window>:<x>,<y>[,<w>,<h>]…
//
// Each window gets its final size first, in one call, if that differs from the size it has: a resize cannot be glided. Then the clock starts, and
// step k of n is due k/n of the duration later, at the place Arbor's own curve has reached by then. A step that is late is made all the same.
//   --steps 1 --duration 0    the control: one call, which is what Arbor does with its motion off
//   --order by-window         one thread makes all of a step's calls, one after the other (the default)
//   --order threads           a thread for each app, because a call waits for its app's answer and for nobody else's
//
// What is added to the log, one line each, `<milliseconds since 1970> <kind> <act> …`, on the clock sampler.swift writes its samples by:
//   act <act> <steps> <duration ms> <order>          before the first call
//   ask <act> <window> <pid> <x y w h> <x y w h>     the frame the window has, and the frame asked for
//   call <act> <window> size|move <step> <took ms> <AXError> <late ms> <x> <y>
//                                                    at the moment the call began, which is <late ms> after it was due; what was asked for (of a
//                                                    size: w h, step 0, never late). AXError 0 is success, -25204 an app that did not answer within a second
//   read <act> <window> <took ms> <x y w h>          the frame read back when the last call had returned
//   sum <act> <window> <calls> <mean ms> <p95 ms> <worst ms> <late ms, all steps together> <points between the place read back and the one asked for>
//   done <act> <ms of processor time this process used>

import Foundation

#if os(macOS)
  import ApplicationServices
#endif

func fail(_ message: String, code: Int32 = 64) -> Never {
  FileHandle.standardError.write(Data("glide: \(message)\n".utf8))
  exit(code)
}

// MARK: A window

#if os(macOS)
  /// The window server's number for an Accessibility window; Arbor uses the same call (AX/AXHelpers.swift).
  @_silgen_name("_AXUIElementGetWindow")
  func _AXUIElementGetWindow(_ element: AXUIElement, _ identifier: UnsafeMutablePointer<CGWindowID>) -> AXError

  struct Window {
    let number: UInt32
    let pid: Int32
    private let element: AXUIElement

    init?(number: UInt32) {
      let list = (CGWindowListCopyWindowInfo([.optionIncludingWindow], number) as? [[String: Any]]) ?? []
      guard let pid = (list.first?[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value else { return nil }
      let app = AXUIElementCreateApplication(pid)
      var value: CFTypeRef?
      guard AXUIElementCopyAttributeValue(app, kAXWindowsAttribute as CFString, &value) == .success,
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

    private func fields() -> [String] { ((try? String(contentsOfFile: path, encoding: .utf8)) ?? "").split(separator: " ").map(String.init) }

    func frame() -> CGRect? {
      let numbers = fields().dropFirst(2).prefix(4).compactMap(Double.init)
      return numbers.count == 4 ? CGRect(x: numbers[0], y: numbers[1], width: numbers[2], height: numbers[3]) : nil
    }

    private func put(_ values: [Double], at index: Int) -> Int32 {
      var all = fields()
      guard all.count >= 7 else { return -25202 }
      Thread.sleep(forTimeInterval: (Double(all[6].trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0) / 1000)
      for (offset, value) in values.enumerated() { all[index + offset] = String(Int(value)) }
      return (try? all.joined(separator: " ").write(toFile: path, atomically: true, encoding: .utf8)) == nil ? -25200 : 0
    }

    func set(position: CGPoint) -> Int32 { put([Double(position.x), Double(position.y)], at: 2) }
    // As a real app of one size answers: all is well, and nothing has changed.
    func set(size: CGSize) -> Int32 { put(fields().count > 7 ? [] : [Double(size.width), Double(size.height)], at: 4) }
  }
#endif

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

// MARK: What was asked for

let usage = "usage: glide <log> <act> [--steps n] [--duration seconds] [--order by-window|threads] <window>:<x>,<y>[,<w>,<h>]…"
var words = Array(CommandLine.arguments.dropFirst())

func option(_ name: String) -> String? {
  guard let index = words.firstIndex(of: name) else { return nil }
  guard words.count > index + 1 else { fail(usage) }
  defer { words.removeSubrange(index...(index + 1)) }
  return words[index + 1]
}

guard let steps = Int(option("--steps") ?? "12"), steps >= 1, steps <= 240 else { fail("--steps takes a number from 1 to 240") }
guard let seconds = Double(option("--duration") ?? "0.2"), seconds >= 0, seconds <= 5 else { fail("--duration takes 0 to 5 seconds") }
let order = option("--order") ?? "by-window"
guard order == "by-window" || order == "threads" else { fail("--order takes by-window or threads") }
guard words.count >= 3 else { fail(usage) }
let (logPath, act) = (words[0], words[1])
let duration = seconds * 1000

struct Target {
  let window: Window
  let from: CGRect
  let to: CGRect

  /// Whole points, as Arbor asks for. The last step is the end itself.
  func place(atStep step: Int, of steps: Int) -> CGPoint {
    let share = step == steps ? 1 : eased(Double(step) / Double(steps))
    return CGPoint(x: (from.minX + (to.minX - from.minX) * share).rounded(), y: (from.minY + (to.minY - from.minY) * share).rounded())
  }
}

let targets: [Target] = words.dropFirst(2).map { word in
  let halves = word.split(separator: ":")
  let numbers = (halves.count == 2 ? halves[1] : "").split(separator: ",").compactMap { Double($0) }
  guard let number = UInt32(halves.first ?? ""), numbers.count == 2 || numbers.count == 4 else { fail("\(word)? \(usage)") }
  guard let window = Window(number: number), let from = window.frame() else {
    fail("no app lists a window \(number) to Accessibility, or it does not say where it is", code: 1)
  }
  let size = numbers.count == 4 ? CGSize(width: numbers[2], height: numbers[3]) : from.size
  return Target(window: window, from: from, to: CGRect(origin: CGPoint(x: numbers[0], y: numbers[1]), size: size))
}

// MARK: The journal

func text(_ value: Double) -> String { String(format: "%.2f", value) }
func text(_ value: CGFloat) -> String { Double(value) == Double(value).rounded() ? String(Int(value)) : String(format: "%.1f", Double(value)) }
func text(_ rect: CGRect) -> String { "\(text(rect.minX)) \(text(rect.minY)) \(text(rect.width)) \(text(rect.height))" }

/// Kept in memory until all is over: no call waits for the disk.
final class Journal {
  private let lock = NSLock()
  private var lines: [(time: Double, text: String)] = []
  private var calls: [UInt32: [(took: Double, late: Double)]] = [:]

  func note(_ time: Double, _ text: String) {
    lock.lock()
    lines.append((time, text))
    lock.unlock()
  }

  func call(_ window: UInt32, _ kind: String, step: Int, began: Double, due: Double, error: Int32, _ x: CGFloat, _ y: CGFloat) {
    let took = now() - began
    note(began, "call \(act) \(window) \(kind) \(step) \(text(took)) \(error) \(text(began - due)) \(text(x)) \(text(y))")
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

// MARK: The journey

#if os(macOS)
  // A process without a window is put to sleep between its timers, which are run together with others' (sampler.swift met the same).
  let awake = ProcessInfo.processInfo.beginActivity(options: [.userInitiated, .latencyCritical], reason: "moving windows by the clock")
#endif

journal.note(now(), "act \(act) \(steps) \(Int(duration)) \(order)")
for target in targets {
  journal.note(now(), "ask \(act) \(target.window.number) \(target.window.pid) \(text(target.from)) \(text(target.to))")
}
for target in targets where abs(target.to.width - target.from.width) > 0.5 || abs(target.to.height - target.from.height) > 0.5 {
  let began = now()
  let error = target.window.set(size: target.to.size)
  journal.call(target.window.number, "size", step: 0, began: began, due: began, error: error, target.to.width, target.to.height)
}

var lanes: [[Target]] = []
if order == "threads" {
  for target in targets {
    if let index = lanes.firstIndex(where: { $0[0].window.pid == target.window.pid }) { lanes[index].append(target) } else { lanes.append([target]) }
  }
} else {
  lanes = [targets]
}
let start = now()
let arrived = DispatchGroup()
for lane in lanes {
  arrived.enter()
  let thread = Thread {
    for step in 1...steps {
      let due = start + duration * Double(step) / Double(steps)
      let early = due - now()
      if early > 0 { Thread.sleep(forTimeInterval: early / 1000) }
      for target in lane {
        let place = target.place(atStep: step, of: steps)
        let began = now()
        let error = target.window.set(position: place)
        journal.call(target.window.number, "move", step: step, began: began, due: due, error: error, place.x, place.y)
      }
    }
    arrived.leave()
  }
  thread.qualityOfService = .userInteractive
  thread.start()
}
arrived.wait()

var said: [String] = []
for target in targets {
  let began = now()
  let frame = target.window.frame() ?? .null
  journal.note(began, "read \(act) \(target.window.number) \(text(now() - began)) \(frame.isNull ? "? ? ? ?" : text(frame))")
  let calls = journal.calls(of: target.window.number)
  let took = calls.map(\.took).sorted()
  let mean = took.reduce(0, +) / Double(max(took.count, 1))
  let p95 = took.isEmpty ? 0 : took[max(Int((Double(took.count) * 0.95).rounded(.up)) - 1, 0)]
  let late = calls.map { max($0.late, 0) }.reduce(0, +)
  let off = frame.isNull ? -1 : Double(max(abs(frame.minX - target.to.minX), abs(frame.minY - target.to.minY)))
  journal.note(
    now(), "sum \(act) \(target.window.number) \(calls.count) \(text(mean)) \(text(p95)) \(text(took.last ?? 0)) \(text(late)) \(text(off))")
  said.append("w\(target.window.number) \(calls.count) calls, \(text(mean)) ms each, the worst \(text(took.last ?? 0)), late \(text(late)), off by \(text(off))")
}
journal.note(now(), "done \(act) \(text(processorTime()))")
journal.write(to: logPath)
print("glide \(act): \(steps) steps in \(Int(duration)) ms, \(order): \(said.joined(separator: "; "))")
