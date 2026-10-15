// witness: what is left of the pointer's events after every event tap, and gesture events to test with.
//
// Arbor's event taps hold back, swallow and re-post events. What they let through cannot be read from
// Arbor itself, so this tool sits at the far end of the same chain of taps, where only apps come after it,
// and prints every event that arrives, with how long it took to get there. It also lists the taps of
// every process with the window server's own measurements, and posts pinches and rotations.
//
// scripts/mac-shell/input-taps.sh compiles it (swiftc -O -swift-version 5) and uses it.
//
// Gesture events have no public constructor. The field numbers below are not documented; they are what
// tools that simulate trackpads use. That is good enough for a test tool and is why Arbor itself reads
// gestures through NSEvent instead.

import AppKit
import CoreGraphics
import Foundation

setvbuf(stdout, nil, _IOLBF, 0)

func fail(_ message: String) -> Never {
  FileHandle.standardError.write(Data("witness: \(message)\n".utf8))
  exit(64)
}

func rest(_ seconds: Double) {
  if seconds > 0 { Thread.sleep(forTimeInterval: seconds) }
}

let usage = """
  usage: witness <command>
    watch <seconds>                     print every left mouse, scroll and gesture event that reaches the end of the taps
    log <file>                          until killed: write every left mouse, scroll and key event that gets there, in sampler.swift's grammar, to be merged
                                        with its samples by time: `<ms since 1970> E down|up|dragged|scroll|key <delay in µs> arbor|none`. Never which key
    taps                                every event tap on the Mac, as the window server lists them
    pinch x y <total> [--steps n] [--opt] [--rotate] [--tap hid|session]
                                        a pinch of that much magnification, with ⌥ held, with a rotation inside it
    scroll x y <dx> <dy> [--steps n] [--opt] [--ctrl] [--momentum n] [--tap hid|session]
                                        a two-finger scroll of that many points in all, with ⌥ or ⌃ held, then coasting for n events
    hold <seconds> [--opt] [--ctrl]     keep ⌥ or ⌃ down that long
    wheel x y <notches> [--opt] [--ctrl] [--tap hid|session]
                                        a mouse wheel turned that many notches, up if positive, with ⌥ or ⌃ held
    hold-space <repeats>                ⌃⌥Space held down: one key-down, then that many auto-repeats, then key-up
    round ax ay bx by x y               a round of input (lib-walk.sh, input_round): a dozen presses in turn at b and at a, a dozen at a, a dozen arrow keys, a scroll
                                        at x y there and back, a drag there, one key more. Prints what it posted, by kind: `press:25,up:25,key:13,scroll:28,dragged:20`
  """

// MARK: Watching

var witnessPort: CFMachPort?

func field(_ number: UInt32) -> CGEventField {
  CGEventField(rawValue: number) ?? unsafeBitCast(number, to: CGEventField.self)
}

func modifiers(_ flags: CGEventFlags) -> String {
  var text = ""
  if flags.contains(.maskControl) { text += "ctrl+" }
  if flags.contains(.maskAlternate) { text += "opt+" }
  if flags.contains(.maskShift) { text += "shift+" }
  if flags.contains(.maskCommand) { text += "cmd+" }
  return text.isEmpty ? "none" : String(text.dropLast())
}

func describe(_ type: CGEventType, _ event: CGEvent) -> String {
  // An event's timestamp is in nanoseconds on the clock that stops while the Mac sleeps.
  let delay = (Int64(clock_gettime_nsec_np(CLOCK_UPTIME_RAW)) - Int64(event.timestamp)) / 1000
  let names: [UInt32: String] = [1: "down", 2: "up", 6: "dragged", 22: "scroll", 29: "gesture"]
  var line = names[type.rawValue] ?? "type\(type.rawValue)"
  line += " \(Int(event.location.x)) \(Int(event.location.y)) mods=\(modifiers(event.flags))"
  line += " clicks=\(event.getIntegerValueField(.mouseEventClickState))"
  line += " mark=\(event.getIntegerValueField(.eventSourceUserData) == 0x4152_424F ? "arbor" : "none")"
  line += " delay_us=\(delay)"
  if type.rawValue == 22 {
    line += " phase=\(event.getIntegerValueField(.scrollWheelEventScrollPhase))"
    line += " momentum=\(event.getIntegerValueField(.scrollWheelEventMomentumPhase))"
    line += " dx=\(event.getIntegerValueField(.scrollWheelEventPointDeltaAxis2))"
    line += " dy=\(event.getIntegerValueField(.scrollWheelEventPointDeltaAxis1))"
  }
  if type.rawValue == 29, let translated = NSEvent(cgEvent: event) {
    switch translated.type {
    case .magnify: line += " magnify phase=\(translated.phase.rawValue) value=\(translated.magnification)"
    case .rotate: line += " rotate phase=\(translated.phase.rawValue) value=\(translated.rotation)"
    default: line += " nstype=\(translated.type.rawValue)"
    }
  }
  return line
}

func watch(seconds: Double) {
  var mask = CGEventMask(0)
  for type in [1, 2, 6, 22, 29] { mask |= CGEventMask(1) << CGEventMask(type) }
  let callback: CGEventTapCallBack = { _, type, event, _ in
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
      print("witness-switched-off \(type.rawValue)")
      if let port = witnessPort { CGEvent.tapEnable(tap: port, enable: true) }
    } else {
      print(describe(type, event))
    }
    return Unmanaged.passUnretained(event)
  }
  var kind = "listen-only"
  witnessPort = CGEvent.tapCreate(
    tap: .cgSessionEventTap, place: .tailAppendEventTap, options: .listenOnly, eventsOfInterest: mask,
    callback: callback, userInfo: nil)
  if witnessPort == nil {
    kind = "active"
    witnessPort = CGEvent.tapCreate(
      tap: .cgSessionEventTap, place: .tailAppendEventTap, options: .defaultTap, eventsOfInterest: mask,
      callback: callback, userInfo: nil)
  }
  guard let port = witnessPort else { fail("macOS refused the tap") }
  CFRunLoopAddSource(CFRunLoopGetCurrent(), CFMachPortCreateRunLoopSource(kCFAllocatorDefault, port, 0), .commonModes)
  CGEvent.tapEnable(tap: port, enable: true)
  print("witness-ready \(kind)")
  CFRunLoopRunInMode(.defaultMode, seconds, false)
}

var witnessLog: UnsafeMutablePointer<FILE>?

func log(to path: String) {
  guard let file = fopen(path, "a") else { fail("cannot write to \(path)") }
  witnessLog = file
  var mask = CGEventMask(0)
  for type in [1, 2, 6, 10, 22] { mask |= CGEventMask(1) << CGEventMask(type) }
  let callback: CGEventTapCallBack = { _, type, event, _ in
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
      if let port = witnessPort { CGEvent.tapEnable(tap: port, enable: true) }
      return Unmanaged.passUnretained(event)
    }
    let names: [UInt32: String] = [1: "down", 2: "up", 6: "dragged", 10: "key", 22: "scroll"]
    let delay = (Int64(clock_gettime_nsec_np(CLOCK_UPTIME_RAW)) - Int64(event.timestamp)) / 1000
    let mark = event.getIntegerValueField(.eventSourceUserData) == 0x4152_424F ? "arbor" : "none"
    if let file = witnessLog, let name = names[type.rawValue] {
      fputs("\(Int64(Date().timeIntervalSince1970 * 1000)) E \(name) \(delay) \(mark)\n", file)
      fflush(file)
    }
    return Unmanaged.passUnretained(event)
  }
  witnessPort = CGEvent.tapCreate(
    tap: .cgSessionEventTap, place: .tailAppendEventTap, options: .listenOnly, eventsOfInterest: mask,
    callback: callback, userInfo: nil)
  if witnessPort == nil {
    // As `watch` does where macOS refuses one that only listens.
    witnessPort = CGEvent.tapCreate(
      tap: .cgSessionEventTap, place: .tailAppendEventTap, options: .defaultTap, eventsOfInterest: mask,
      callback: callback, userInfo: nil)
  }
  guard let port = witnessPort else { fail("macOS refused the tap") }
  CFRunLoopAddSource(CFRunLoopGetCurrent(), CFMachPortCreateRunLoopSource(kCFAllocatorDefault, port, 0), .commonModes)
  CGEvent.tapEnable(tap: port, enable: true)
  CFRunLoopRun()
}

func listTaps() {
  var count: UInt32 = 0
  CGGetEventTapList(0, nil, &count)
  var list = [CGEventTapInformation](repeating: CGEventTapInformation(), count: Int(count))
  CGGetEventTapList(count, &list, &count)
  for tap in list.prefix(Int(count)) {
    print(
      "tap \(tap.eventTapID) pid=\(tap.tappingProcess) point=\(tap.tapPoint.rawValue) options=\(tap.options.rawValue)"
        + " mask=0x\(String(tap.eventsOfInterest, radix: 16)) enabled=\(tap.enabled)"
        + " latency_us min=\(tap.minUsecLatency) avg=\(tap.avgUsecLatency) max=\(tap.maxUsecLatency)")
  }
}

// MARK: Posting

var arguments = Array(CommandLine.arguments.dropFirst())

func option(_ name: String) -> String? {
  guard let index = arguments.firstIndex(of: name) else { return nil }
  guard index + 1 < arguments.count else { fail("\(name) needs a value") }
  let value = arguments[index + 1]
  arguments.removeSubrange(index...(index + 1))
  return value
}

func flag(_ name: String) -> Bool {
  guard let index = arguments.firstIndex(of: name) else { return false }
  arguments.remove(at: index)
  return true
}

func number(_ index: Int) -> Double {
  guard arguments.count > index, let value = Double(arguments[index]), value.isFinite else {
    fail("expected a number\n\(usage)")
  }
  return value
}

var postAt = CGEventTapLocation.cgSessionEventTap

enum Phase: Double {
  case began = 1, changed = 2, ended = 4
}

/// subtype 8 is a magnification, whose amount is field 113; subtype 5 a rotation, field 114.
func gesture(subtype: Double, amountField: UInt32, amount: Double, phase: Phase, at point: CGPoint, flags: CGEventFlags) {
  guard let event = CGEvent(source: nil) else { fail("could not create an event") }
  event.setDoubleValueField(field(55), value: 29)  // the event's type: a gesture
  event.setDoubleValueField(field(110), value: subtype)
  event.setDoubleValueField(field(132), value: phase.rawValue)
  event.setDoubleValueField(field(amountField), value: amount)
  event.location = point
  event.flags = flags
  event.post(tap: postAt)
}

func magnify(_ amount: Double, _ phase: Phase, at point: CGPoint, flags: CGEventFlags) {
  gesture(subtype: 8, amountField: 113, amount: amount, phase: phase, at: point, flags: flags)
}

func rotate(_ amount: Double, _ phase: Phase, at point: CGPoint, flags: CGEventFlags) {
  gesture(subtype: 5, amountField: 114, amount: amount, phase: phase, at: point, flags: flags)
}

/// A trackpad's scroll event. These fields are public. Phases: 1 began, 2 changed, 4 ended; momentum: 1 begin,
/// 2 continue, 3 end.
func scroll(dx: Int32, dy: Int32, phase: Int64, momentum: Int64, at point: CGPoint, flags: CGEventFlags) {
  guard
    let event = CGEvent(
      scrollWheelEvent2Source: nil, units: .pixel, wheelCount: 2, wheel1: dy, wheel2: dx, wheel3: 0)
  else { fail("could not create a scroll event") }
  event.setIntegerValueField(.scrollWheelEventIsContinuous, value: 1)
  event.setIntegerValueField(.scrollWheelEventScrollPhase, value: phase)
  event.setIntegerValueField(.scrollWheelEventMomentumPhase, value: momentum)
  event.location = point
  event.flags = flags
  event.post(tap: postAt)
}

/// One notch of a mouse wheel: counted in lines, not continuous, no phases.
func notch(up: Bool, at point: CGPoint, flags: CGEventFlags) {
  guard
    let event = CGEvent(scrollWheelEvent2Source: nil, units: .line, wheelCount: 1, wheel1: up ? 1 : -1, wheel2: 0, wheel3: 0)
  else { fail("could not create a scroll event") }
  event.location = point
  event.flags = flags
  event.post(tap: postAt)
}

/// Presses or lets go of ⌃ (59) and ⌥ (58), and answers with the flags events carry meanwhile.
func hold(control: Bool, option: Bool, down: Bool) -> CGEventFlags {
  var flags: CGEventFlags = []
  if control { flags.insert(.maskControl) }
  if option { flags.insert(.maskAlternate) }
  if control { key(59, down: down, flags: down ? .maskControl : []) }
  if option { key(58, down: down, flags: down ? flags : []) }
  return flags
}

func key(_ code: CGKeyCode, down: Bool, flags: CGEventFlags, repeating: Bool = false) {
  let source = CGEventSource(stateID: .hidSystemState)
  guard let event = CGEvent(keyboardEventSource: source, virtualKey: code, keyDown: down) else {
    fail("could not create a key event")
  }
  event.flags = flags
  if repeating { event.setIntegerValueField(.keyboardEventAutorepeat, value: 1) }
  event.post(tap: .cghidEventTap)
  rest(0.03)
}

/// What a round has posted so far, by kind. Whoever posts knows; nobody else has to reckon it.
var posted: [String: Int] = [:]

func mouse(_ type: CGEventType, at point: CGPoint) {
  guard let event = CGEvent(mouseEventSource: CGEventSource(stateID: .hidSystemState), mouseType: type, mouseCursorPosition: point, mouseButton: .left)
  else { fail("could not create a mouse event") }
  if type != .mouseMoved { event.setIntegerValueField(.mouseEventClickState, value: 1) }
  event.post(tap: .cghidEventTap)
  let kinds: [CGEventType: String] = [.leftMouseDown: "press", .leftMouseUp: "up", .leftMouseDragged: "dragged"]
  if let kind = kinds[type] { posted[kind, default: 0] += 1 }
}

/// The button stays down for three of the sampler's looks, so that it sees every press the taps see.
func press(at point: CGPoint, then pause: Double) {
  mouse(.mouseMoved, at: point)
  rest(0.03)
  mouse(.leftMouseDown, at: point)
  rest(0.08)
  mouse(.leftMouseUp, at: point)
  rest(pause)
}

func stroke(_ code: CGKeyCode) {
  key(code, down: true, flags: [])
  key(code, down: false, flags: [])
  posted["key", default: 0] += 1
}

func scrolled(by dy: Int32, steps: Int, at point: CGPoint) {
  scroll(dx: 0, dy: 0, phase: 1, momentum: 0, at: point, flags: [])
  rest(0.01)
  for _ in 1...steps {
    scroll(dx: 0, dy: dy, phase: 2, momentum: 0, at: point, flags: [])
    rest(0.01)
  }
  scroll(dx: 0, dy: 0, phase: 4, momentum: 0, at: point, flags: [])
  posted["scroll", default: 0] += steps + 2
}

// MARK: Commands

guard !arguments.isEmpty else { fail(usage) }
let command = arguments.removeFirst()
if let name = option("--tap") {
  guard name == "hid" || name == "session" else { fail("--tap takes hid or session") }
  postAt = name == "hid" ? .cghidEventTap : .cgSessionEventTap
}

switch command {
case "watch":
  watch(seconds: number(0))

case "log":
  guard let path = arguments.first else { fail(usage) }
  log(to: path)

case "taps":
  listTaps()

case "pinch":
  let steps = max(1, min(500, Int(option("--steps").flatMap(Double.init) ?? 10)))
  let withOption = flag("--opt")
  let withRotation = flag("--rotate")
  let point = CGPoint(x: number(0), y: number(1))
  let total = number(2)
  let flags: CGEventFlags = withOption ? .maskAlternate : []
  if withOption { key(58, down: true, flags: .maskAlternate) }
  magnify(0, .began, at: point, flags: flags)
  rest(0.01)
  if withRotation { rotate(0, .began, at: point, flags: flags) }
  for _ in 1...steps {
    magnify(total / Double(steps), .changed, at: point, flags: flags)
    if withRotation { rotate(1, .changed, at: point, flags: flags) }
    rest(0.01)
  }
  magnify(0, .ended, at: point, flags: flags)
  rest(0.01)
  // After the pinch, as fingers that are still turning would.
  if withRotation { rotate(0, .ended, at: point, flags: flags) }
  if withOption { key(58, down: false, flags: []) }

case "scroll":
  let steps = max(1, min(500, Int(option("--steps").flatMap(Double.init) ?? 10)))
  let coasting = max(0, min(500, Int(option("--momentum").flatMap(Double.init) ?? 0)))
  let withOption = flag("--opt")
  let withControl = flag("--ctrl")
  let point = CGPoint(x: number(0), y: number(1))
  let dx = Int32(max(-10_000, min(10_000, number(2) / Double(steps))))
  let dy = Int32(max(-10_000, min(10_000, number(3) / Double(steps))))
  let flags = hold(control: withControl, option: withOption, down: true)
  scroll(dx: 0, dy: 0, phase: 1, momentum: 0, at: point, flags: flags)
  rest(0.01)
  for _ in 1...steps {
    scroll(dx: dx, dy: dy, phase: 2, momentum: 0, at: point, flags: flags)
    rest(0.01)
  }
  scroll(dx: 0, dy: 0, phase: 4, momentum: 0, at: point, flags: flags)
  // The keys are let go with the fingers; what coasts on carries none.
  _ = hold(control: withControl, option: withOption, down: false)
  if coasting > 0 {
    for index in 1...coasting {
      scroll(dx: dx, dy: dy, phase: 0, momentum: index == 1 ? 1 : 2, at: point, flags: [])
      rest(0.01)
    }
    scroll(dx: 0, dy: 0, phase: 0, momentum: 3, at: point, flags: [])
  }

case "hold":
  let withOption = flag("--opt")
  let withControl = flag("--ctrl")
  _ = hold(control: withControl, option: withOption, down: true)
  rest(max(0, min(30, number(0))))
  _ = hold(control: withControl, option: withOption, down: false)

case "wheel":
  let withOption = flag("--opt")
  let withControl = flag("--ctrl")
  let point = CGPoint(x: number(0), y: number(1))
  let notches = max(-50, min(50, Int(number(2))))
  let flags = hold(control: withControl, option: withOption, down: true)
  for _ in 0..<abs(notches) {
    notch(up: notches > 0, at: point, flags: flags)
    rest(0.05)
  }
  _ = hold(control: withControl, option: withOption, down: false)

case "hold-space":
  let repeats = max(0, min(50, Int(number(0))))
  let flags: CGEventFlags = [.maskControl, .maskAlternate]
  key(59, down: true, flags: .maskControl)
  key(58, down: true, flags: flags)
  key(49, down: true, flags: flags)
  for _ in 0..<repeats { key(49, down: true, flags: flags, repeating: true) }
  key(49, down: false, flags: flags)
  key(58, down: false, flags: .maskControl)
  key(59, down: false, flags: [])

case "round":
  let a = CGPoint(x: number(0), y: number(1))
  let b = CGPoint(x: number(2), y: number(3))
  let inside = CGPoint(x: number(4), y: number(5))
  // Each on the app that is not in front. macOS takes up to 140 ms to bring one forward, and jolts.py asks who was in front 150 ms before a press.
  for _ in 1...6 {
    press(at: b, then: 0.3)
    press(at: a, then: 0.3)
  }
  // Six points to either side in turn, so that no two are a double-click, whatever counts them.
  for _ in 1...6 {
    press(at: CGPoint(x: a.x - 6, y: a.y), then: 0.06)
    press(at: CGPoint(x: a.x + 6, y: a.y), then: 0.06)
  }
  for _ in 1...6 {
    stroke(124)
    stroke(123)
  }
  mouse(.mouseMoved, at: inside)
  rest(0.05)
  scrolled(by: -3, steps: 12, at: inside)
  rest(0.05)
  scrolled(by: 3, steps: 12, at: inside)
  rest(0.05)
  mouse(.leftMouseDown, at: inside)
  rest(0.15)  // AppKit decides what the press means before the first movement
  for step in 1...20 {
    mouse(.leftMouseDragged, at: CGPoint(x: inside.x + CGFloat(step) * 3, y: inside.y + CGFloat(step)))
    rest(0.02)
  }
  mouse(.leftMouseUp, at: CGPoint(x: inside.x + 60, y: inside.y + 20))
  rest(0.05)
  // What was selected is let go of again.
  stroke(123)
  print(["press", "up", "key", "scroll", "dragged"].map { "\($0):\(posted[$0] ?? 0)" }.joined(separator: ","))

default:
  fail("unknown command \(command)\n\(usage)")
}
