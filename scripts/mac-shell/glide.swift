// glide: sets a real window's PLACE once for every frame of the display, through Accessibility, and writes down every tick and every asking.
// For scripts/mac-shell/probe-place.sh, which compiles it (swiftc -O -swift-version 5); judge-place.py reads what it writes.
//
// macOS's own tiling moves the window itself: it glides for 0.3 s, a new place with nearly every frame of the display. For Arbor to do as much without a picture of the window,
// and so without Screen Recording, it has to ask the app again and again. Place and size are two askings with a state between them that the display shows, so a move that
// changes a size is out of the question. This asks for the place alone, which is one asking: what the camera's own moves are, and a swap of two equal tiles.
// No Arbor, no stage. Needs Accessibility. It knows windows by their numbers and never reads a title.
//
//   glide <log> <act> [--pace link|spin] [--duration seconds] <window>:<x>,<y> [<window>:<x>,<y>…]
//   glide <log> <act> --menu "Window/Move & Resize/Left" <window>
//
// EVERY WINDOW GLIDES, each asked from a thread of its own that the same tick wakes, so that a slow app holds up nobody but itself.
// PACED BY THE DISPLAY, never by a timer: on GitHub's Macs a thread that sleeps wakes tens of milliseconds late, and what was to be a glide goes out in bursts.
//   --pace link    the screen's display link, as Arbor's own log of its stage gets it (Sources/ArborKit/UI/StageSampler.swift) and pulse.swift. The default
//   --pace spin    a thread that does nothing but read the clock, at the display's rate. It knows nothing of when the display draws, and takes a core
// BY THE CLOCK: at each tick a window is asked for the place Arbor's curve has reached by now. A tick that comes late, or finds the app still busy with the last asking, leaves
// places out; it never makes the glide longer. The last asking is the end itself. The first three ticks are let go by: a pacer may need a moment, and time counts from the third.
//   --duration 0   the control: the place is set once, which is what Arbor does with its motion off
//   --menu         the bar: that item of the app's own menu is pressed, and macOS moves the window. Nothing is asked for; 0.6 s later the frame is read
//
// IT SAYS WHETHER IT GLIDED. `paced`: no window's thread ever waited for a tick longer than a frame and a half. Otherwise what the display showed is what was asked for, a
// few jumps, and says nothing about the app or about macOS.
//
// What is added to the log, one line each, `<milliseconds since 1970> <kind> <act> …`, on the clock camera.swift stamps its frames by:
//   act <act> <pace> <duration ms> <ms a frame of the display lasts>     before anything else. Of the bar: macos 0 <ms>
//   ask <act> <window> <pid> <x y w h> <x y w h>     the frame the window has, and the one it is to have (of the bar: the one it had in the end)
//   tick <act> <n> <ms since the tick before> <late ms>      late: after the moment the display link gives for the frame; spinning, after the tick was due
//   go <act> <n>                                     the tick from which the time counts
//   call <act> <window> <n> <took ms> <AXError> <x y>        at the moment the asking began, woken by tick n. AXError 0 is success, -25204 an app that did not answer
//                                                    within a second: IT IS NOT ASKED AGAIN in this act
//   mute <act> <window>                              no tick came for a second: the window's thread gave up
//   read <act> <window> <took ms> <x y w h>          the frame read back when all was over
//   sum <act> <window> <askings> <mean ms> <worst ms> <longest wait for a tick, ms> <points between the place read back and the one asked for> paced|unpaced
//   done <act> <ms of processor time this process used>
// Exit code 3: the pacer gave no tick at all.

import Foundation

#if os(macOS)
  import AppKit
  import ApplicationServices
  import QuartzCore
#endif

func fail(_ message: String, code: Int32 = 64) -> Never {
  FileHandle.standardError.write(Data("glide: \(message)\n".utf8))
  exit(code)
}

// What is piped is kept back by the kilobyte otherwise, and a run that is cut off loses it.
setvbuf(stdout, nil, _IOLBF, 0)

// MARK: The clock and the curve

let wallAtStart = Date().timeIntervalSince1970 * 1000
let ticksAtStart = DispatchTime.now().uptimeNanoseconds
/// Milliseconds since 1970, told on by a clock that nobody sets.
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

/// Whole points, as Arbor asks for.
func onTheRoad(from: CGPoint, to: CGPoint, after progress: Double) -> CGPoint {
  let share = CGFloat(eased(progress))
  return CGPoint(x: (from.x + (to.x - from.x) * share).rounded(), y: (from.y + (to.y - from.y) * share).rounded())
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

    /// Presses an item of the app's menu bar, found by the titles on the way to it. A menu's items are the children of its one child.
    func press(menu titles: [String]) -> Bool {
      var value: CFTypeRef?
      guard AXUIElementCopyAttributeValue(AXUIElementCreateApplication(pid), kAXMenuBarAttribute as CFString, &value) == .success, let bar = value
      else { return false }
      func name(of element: AXUIElement) -> String? {
        var name: CFTypeRef?
        return AXUIElementCopyAttributeValue(element, kAXTitleAttribute as CFString, &name) == .success ? name as? String : nil
      }
      var items = children(of: bar as! AXUIElement)
      for (depth, title) in titles.enumerated() {
        // An item that was made without a title of its own shows its menu's.
        guard let item = items.first(where: { name(of: $0) == title || children(of: $0).first.flatMap(name(of:)) == title }) else { return false }
        if depth == titles.count - 1 { return AXUIElementPerformAction(item, kAXPressAction as CFString) == .success }
        items = children(of: item).first.map { children(of: $0) } ?? []
      }
      return false
    }
  }
#else
  /// A rehearsal on Linux (rehearse.sh) runs this very tool, so that all of it but the struct above and the display link has run before it meets a Mac. There a
  /// window is a file, as rehearse/real-apps makes them and says: `pid bundle-id x y w h <ms its app takes to answer>`.
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

    private func put(_ values: [CGFloat]) -> Int32 {
      var all = fields()
      guard all.count >= 7 else { return -25202 }
      // As Accessibility does with an app that takes longer than it is given: a second, and nothing has changed.
      if (Double(all[6]) ?? 0) >= 1000 {
        Thread.sleep(forTimeInterval: 1)
        return -25204
      }
      Thread.sleep(forTimeInterval: (Double(all[6]) ?? 0) / 1000)
      for (offset, value) in values.enumerated() { all[2 + offset] = String(Int(value)) }
      return (try? all.joined(separator: " ").write(toFile: path, atomically: true, encoding: .utf8)) == nil ? -25200 : 0
    }

    func set(position: CGPoint) -> Int32 { put([position.x, position.y]) }

    /// As macOS tiles: place and size at once, eighteen times in 0.3 s, into that half of a small display.
    func press(menu titles: [String]) -> Bool {
      guard let from = frame() else { return false }
      let to = CGRect(x: titles.last == "Right" ? 512 : 0, y: 31, width: 512, height: 674)
      for step in 1...18 {
        Thread.sleep(forTimeInterval: 0.3 / 18)
        let corner = onTheRoad(from: from.origin, to: to.origin, after: Double(step) / 18)
        let far = onTheRoad(from: CGPoint(x: from.maxX, y: from.maxY), to: CGPoint(x: to.maxX, y: to.maxY), after: Double(step) / 18)
        _ = put([corner.x, corner.y, far.x - corner.x, far.y - corner.y])
      }
      return true
    }
  }
#endif

// MARK: What was asked for

let usage = """
  usage: glide <log> <act> [--pace link|spin] [--duration seconds] <window>:<x>,<y> [<window>:<x>,<y>…]
         glide <log> <act> --menu "Window/Move & Resize/Left" <window>
  """
var words = Array(CommandLine.arguments.dropFirst())

func option(_ name: String) -> String? {
  guard let index = words.firstIndex(of: name) else { return nil }
  guard words.count > index + 1 else { fail(usage) }
  defer { words.removeSubrange(index...(index + 1)) }
  return words[index + 1]
}

let pace = option("--pace") ?? "link"
guard ["link", "spin"].contains(pace) else { fail("--pace takes link or spin") }
guard let seconds = Double(option("--duration") ?? "0.3"), seconds >= 0, seconds <= 5 else { fail("--duration takes 0 to 5 seconds") }
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
  guard let number = UInt32(halves.first ?? ""), numbers.count == (menu == nil ? 2 : 0) else { fail("\(word)?\n\(usage)") }
  guard let window = Window(number: number), let from = window.frame() else {
    fail("no app lists a window \(number) to Accessibility, or it does not say where it is", code: 1)
  }
  return Target(window: window, from: from, to: menu == nil ? CGRect(origin: CGPoint(x: numbers[0], y: numbers[1]), size: from.size) : from)
}

#if os(macOS)
  let told = NSScreen.screens.first?.maximumFramesPerSecond ?? 0
#else
  let told = 0
#endif
/// How long the display shows a frame, in milliseconds. A virtual display may not say how many it shows in a second.
let period = 1000 / Double(told > 0 ? told : 60)
/// A thread that waited longer than this for a tick was not paced.
let patience = 1.5 * period

// MARK: The journal

func text(_ value: Double) -> String { String(format: "%.2f", value) }
func text(_ value: CGFloat) -> String { Double(value) == Double(value).rounded() ? String(Int(value)) : String(format: "%.1f", Double(value)) }
func text(_ point: CGPoint) -> String { "\(text(point.x)) \(text(point.y))" }
func text(_ rect: CGRect) -> String { "\(text(rect.origin)) \(text(rect.width)) \(text(rect.height))" }

/// Kept in memory until all is over: no asking waits for the disk.
final class Journal {
  private let lock = NSLock()
  private var lines: [(time: Double, text: String)] = []
  private var calls: [UInt32: [(began: Double, took: Double)]] = [:]

  func note(_ time: Double, _ text: String) {
    lock.lock()
    lines.append((time, text))
    lock.unlock()
  }

  func call(_ window: UInt32, tick: Int, began: Double, error: Int32, _ place: CGPoint) {
    let took = now() - began
    note(began, "call \(act) \(window) \(tick) \(text(took)) \(error) \(text(place))")
    lock.lock()
    calls[window, default: []].append((began, took))
    lock.unlock()
  }

  func calls(of window: UInt32) -> [(began: Double, took: Double)] {
    lock.lock()
    defer { lock.unlock() }
    return calls[window] ?? []
  }

  func write(to path: String) {
    // The ticks go on meanwhile.
    lock.lock()
    let lines = self.lines
    lock.unlock()
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
  let awake = ProcessInfo.processInfo.beginActivity(options: [.userInitiated, .latencyCritical], reason: "moving windows by the display")
#endif

// MARK: The bar: macOS moves the window

if let menu {
  let target = targets[0]
  let began = now()
  journal.note(began, "act \(act) macos 0 \(text(period))")
  guard target.window.press(menu: menu.split(separator: "/").map(String.init)) else { fail("the app's menu bar has no item \(menu), or it cannot be pressed", code: 1) }
  Thread.sleep(forTimeInterval: 0.6)
  let end = target.window.frame() ?? target.from
  journal.note(began, "ask \(act) \(target.window.number) \(target.window.pid) \(text(target.from)) \(text(end))")
  journal.note(now(), "done \(act) \(text(processorTime()))")
  journal.write(to: logPath)
  print("glide \(act): macOS took w\(target.window.number) from \(text(target.from)) to \(text(end))")
  exit(0)
}

// MARK: The beat

/// The ticks, from whoever makes them to the threads that wait for them.
final class Beat {
  /// The tick from which the time counts.
  static let first = 3
  private let condition = NSCondition()
  private var count = 0
  private var last = 0.0
  private(set) var start = 0.0

  func strike(late: Double) {
    let time = now()
    condition.lock()
    count += 1
    journal.note(time, "tick \(act) \(count) \(text(count == 1 ? 0 : time - last)) \(text(late))")
    last = time
    if count == Beat.first {
      start = time
      journal.note(time, "go \(act) \(count)")
    }
    condition.broadcast()
    condition.unlock()
  }

  /// The newest tick after that one: those that came while the caller was busy are left out. Nil if none comes within a second.
  func next(after seen: Int) -> Int? {
    condition.lock()
    defer { condition.unlock() }
    let limit = Date(timeIntervalSinceNow: 1)
    while count <= seen { if !condition.wait(until: limit) { return nil } }
    return count
  }
}

let beat = Beat()

func onAThread(_ work: @escaping @Sendable () -> Void) {
  let thread = Thread(block: work)
  thread.qualityOfService = .userInteractive
  thread.start()
}

/// A tick that is missed is left out, and the next one comes when it would have.
func tickByTheClock(waiting: @escaping @Sendable (Double) -> Void) {
  onAThread {
    var due = now()
    while true {
      waiting(due)
      beat.strike(late: now() - due)
      while due <= now() { due += period }
    }
  }
}

#if os(macOS)
  final class Link: NSObject {
    @objc func ticked(_ link: CADisplayLink) { beat.strike(late: (CACurrentMediaTime() - link.timestamp) * 1000) }
  }
  let link = Link()
#endif

// MARK: The journey

/// kAXErrorCannotComplete: the app did not answer within the time it is given.
let noAnswer: Int32 = -25204

journal.note(now(), "act \(act) \(pace) \(Int(duration)) \(text(period))")
for target in targets { journal.note(now(), "ask \(act) \(target.window.number) \(target.window.pid) \(text(target.from)) \(text(target.to))") }

let arrived = DispatchGroup()
for target in targets {
  arrived.enter()
  onAThread {
    defer { arrived.leave() }
    var seen = Beat.first - 1
    while let tick = beat.next(after: seen) {
      seen = tick
      // The tick from which the time counts finds the window where it is.
      if tick == Beat.first { continue }
      let began = now()
      let isLast = duration - (began - beat.start) < period / 2
      let place = isLast ? target.to.origin : onTheRoad(from: target.from.origin, to: target.to.origin, after: (began - beat.start) / duration)
      let error = target.window.set(position: place)
      journal.call(target.window.number, tick: tick, began: began, error: error, place)
      if isLast || error == noAnswer { return }
    }
    journal.note(now(), "mute \(act) \(target.window.number)")
  }
}

/// Reads back, sums up, writes the log and ends the process.
func finish() -> Never {
  arrived.wait()
  var said: [String] = []
  var isPaced = true
  for target in targets {
    let began = now()
    let end = target.window.frame() ?? .null
    journal.note(began, "read \(act) \(target.window.number) \(text(now() - began)) \(end.isNull ? "? ? ? ?" : text(end))")
    let calls = journal.calls(of: target.window.number)
    let took = calls.map(\.took)
    let mean = took.reduce(0, +) / Double(max(took.count, 1))
    // From the end of an asking, or from the start, to the beginning of the next.
    let free = [beat.start] + calls.map { $0.began + $0.took }
    let waited = zip(calls, free).map { $0.began - $1 }.max() ?? .infinity
    let off = end.isNull ? -1 : Double(max(abs(end.minX - target.to.minX), abs(end.minY - target.to.minY)))
    let word = waited <= patience ? "paced" : "unpaced"
    isPaced = isPaced && waited <= patience
    journal.note(
      now(), "sum \(act) \(target.window.number) \(calls.count) \(text(mean)) \(text(took.max() ?? 0)) \(waited.isFinite ? text(waited) : "-1") \(text(off)) \(word)")
    said.append(
      "w\(target.window.number) \(calls.count) askings, \(text(mean)) ms each, the worst \(text(took.max() ?? 0)), "
        + "waited \(waited.isFinite ? text(waited) : "for ever") ms for a tick at the most, off by \(text(off))")
  }
  journal.note(now(), "done \(act) \(text(processorTime()))")
  journal.write(to: logPath)
  print("glide \(act): \(pace), \(Int(duration)) ms: \(said.joined(separator: "; ")): \(isPaced ? "paced" : "NOT PACED")")
  exit(beat.start == 0 ? 3 : 0)
}

#if os(macOS)
  if pace == "link" {
    // Call for call as pulse.swift gets its link, which has ticked on GitHub's Macs.
    let application = NSApplication.shared
    application.setActivationPolicy(.accessory)
    guard let screen = NSScreen.screens.first else { fail("no display", code: 3) }
    let ticks = screen.displayLink(target: link, selector: #selector(Link.ticked(_:)))
    // It ticks on the run loop it is added to: this thread's, which from here on does nothing else.
    ticks.add(to: .main, forMode: .common)
    onAThread { finish() }
    application.run()
  }
#else
  // There is no display: a loop that sleeps will do for a rehearsal.
  if pace == "link" { tickByTheClock { due in Thread.sleep(forTimeInterval: max(due - now(), 0) / 1000) } }
#endif
if pace == "spin" { tickByTheClock { due in while now() < due {} } }
finish()
