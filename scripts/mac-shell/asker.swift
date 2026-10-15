// asker: what one running process is told about the Accessibility permission, and whether input goes on while another loses it.
//
// macOS announces neither the arrival nor the loss of the permission, so Arbor asks. What a process that has asked before is told
// when the answer changes behind it cannot be read from Arbor: `ask` is such a process, and writes down both questions
// Arbor has (the flag, and a tap made and thrown away) twice a second. Put into a bundle and opened by Launch Services it
// answers for its own permission, so that it can be given and taken without touching anybody else's.
//
// `stream` posts a click, a key and a notch of the wheel every so many milliseconds, each with a number of its own, and `arrivals` sits
// at the far end of the chain of event taps and writes down which of them got there and when: the longest hole in that list
// is how long the Mac's input stood still.
//
// scripts/mac-shell/probe-permission.sh compiles it (swiftc -O -swift-version 5) and shows how it is used.

import AppKit
import ApplicationServices
import CoreGraphics
import Foundation

setvbuf(stdout, nil, _IOLBF, 0)

let usage = """
  usage: asker <command>
    ask <seconds> <file>            append to <file>, twice a second: the time, flag=yes|no (AXIsProcessTrusted), tap=yes|no (an active
                                    tap made and thrown away, as Arbor does it), listen=yes|no (a tap that only listens)
    hear <seconds>                  print every distributed notification com.apple.accessibility.api
    announce                        post that notification
    stream <seconds> <ms> <x> <y> [--kinds click,key,wheel,pinch] [--ctrl-opt <from> <until>]
                                    every <ms> milliseconds, numbered: a click at x y, the key F19, one notch of the wheel (those three
                                    unless told otherwise), a whole small pinch. ⌃⌥ go down <from> seconds in and up at <until>
    arrivals <seconds>              print each of those that reaches the end of the taps: the time, its kind, its number, how late, its modifiers;
                                    and every other press, drag, key, scroll and gesture, as other=…
    pairs <seconds> <x> <y>         the button, the key F19 and ⇧, each down for 400 ms and up for 400 ms, a third of that apart from one another, numbered: so that
                                    at any moment something is down. Ends with everything up
    window <seconds> <file> x y w h an app with one window there (global top-left coordinates) that appends to <file> every press, release, drag, key and change of
                                    modifiers IT is given, and, whenever one of them changes, what the window server holds to be down
    tap <seconds> <file>            install one active tap on mouse-downs, at the head of the session's taps as Arbor's are, pass everything on, and never let
                                    go of it; append to <file> when it is in, whenever macOS switches it off, and, asked every 10 ms on another thread, whenever one
                                    of the cheap questions changes its answer; at the end what one call of each costs
    now                             the time as all of these write it, and as arbor.log does
  """

func fail(_ message: String) -> Never {
  FileHandle.standardError.write(Data("asker: \(message)\n".utf8))
  exit(64)
}

/// The time of day as arbor.log writes it (UTC, to the millisecond), to line the two up.
let clock: DateFormatter = {
  let formatter = DateFormatter()
  formatter.dateFormat = "HH:mm:ss.SSS"
  formatter.timeZone = TimeZone(identifier: "UTC")
  return formatter
}()
func now() -> String { clock.string(from: Date()) }

let announcement = Notification.Name("com.apple.accessibility.api")
/// Above every number is this, so that nobody else's events are taken for the stream's.
let streamMark: Int64 = 0x4153_4B00_0000

// MARK: Asking

let nobody: CGEventTapCallBack = { _, _, event, _ in Unmanaged.passUnretained(event) }

/// A tap is born switched on, and nothing serves this one, so it watches only for a drawing tablet's pen coming near
/// (`EventTap.refusal` in Sources/ArborKit/Input/EventTap.swift, which this copies).
func canTap(_ options: CGEventTapOptions) -> Bool {
  let mask = CGEventMask(1) << CGEventMask(CGEventType.tabletProximity.rawValue)
  guard
    let probe = CGEvent.tapCreate(
      tap: .cgSessionEventTap, place: .tailAppendEventTap, options: options, eventsOfInterest: mask, callback: nobody, userInfo: nil)
  else { return false }
  CGEvent.tapEnable(tap: probe, enable: false)
  CFMachPortInvalidate(probe)
  return true
}

func ask(seconds: Double, into path: String) {
  if !FileManager.default.fileExists(atPath: path) { FileManager.default.createFile(atPath: path, contents: nil) }
  guard let file = FileHandle(forWritingAtPath: path) else { fail("cannot write \(path)") }
  file.seekToEndOfFile()
  let word = { (yes: Bool) in yes ? "yes" : "no" }
  let end = Date().addingTimeInterval(seconds)
  // On a timer of the main run loop, as Arbor waits: whatever wakes the flag may need the run loop to be served.
  let timer = Timer(timeInterval: 0.5, repeats: true) { _ in
    let line = "\(now()) pid=\(getpid()) flag=\(word(AXIsProcessTrusted())) tap=\(word(canTap(.defaultTap))) listen=\(word(canTap(.listenOnly)))\n"
    file.write(Data(line.utf8))
    if Date() >= end { exit(0) }
  }
  RunLoop.main.add(timer, forMode: .common)
  timer.fire()
  RunLoop.main.run()
}

func hear(seconds: Double) {
  let observer = DistributedNotificationCenter.default().addObserver(forName: announcement, object: nil, queue: .main) { note in
    print("\(now()) heard \(note.name.rawValue) from \(note.object.map { "\($0)" } ?? "nobody")")
  }
  print("\(now()) listening")
  RunLoop.main.run(until: Date().addingTimeInterval(seconds))
  DistributedNotificationCenter.default().removeObserver(observer)
}

// MARK: The stream and its arrivals

func field(_ number: UInt32) -> CGEventField {
  CGEventField(rawValue: number) ?? unsafeBitCast(number, to: CGEventField.self)
}

func stream(seconds: Double, every milliseconds: Double, at point: CGPoint, kinds: Set<String>, held: ClosedRange<Double>?) {
  let source = CGEventSource(stateID: .hidSystemState)
  var number: Int64 = 0
  var flags: CGEventFlags = []
  func post(_ event: CGEvent?, at tap: CGEventTapLocation = .cghidEventTap) {
    guard let event else { fail("macOS made no event") }
    number += 1
    event.setIntegerValueField(.eventSourceUserData, value: streamMark + number)
    if !flags.isEmpty { event.flags = flags }
    event.post(tap: tap)
  }
  /// ⌃ is key 59, ⌥ key 58: pressed and let go as witness.swift does it, which is what switches Arbor's scroll tap on.
  func modifiers(down: Bool) {
    let both: CGEventFlags = [.maskControl, .maskAlternate]
    let control: CGEventFlags = .maskControl
    let none: CGEventFlags = []
    // Down: ⌃, then ⌥. Up: ⌥, then ⌃. Each event carries what is down after it.
    let controlKey: CGKeyCode = 59
    let optionKey: CGKeyCode = 58
    let pressing: [(CGKeyCode, CGEventFlags)] = [(controlKey, control), (optionKey, both)]
    let letting: [(CGKeyCode, CGEventFlags)] = [(optionKey, control), (controlKey, none)]
    let steps = down ? pressing : letting
    for (code, after) in steps {
      guard let event = CGEvent(keyboardEventSource: source, virtualKey: code, keyDown: down) else { fail("macOS made no event") }
      event.flags = after
      event.post(tap: .cghidEventTap)
      Thread.sleep(forTimeInterval: 0.01)
    }
    flags = down ? both : none
    print("\(now()) ctrl+opt \(down ? "down" : "up") after n=\(number)")
  }
  /// Gesture events have no public constructor: the fields are those of witness.swift. Subtype 8 is a magnification, its amount field 113.
  func magnify(_ amount: Double, phase: Double) {
    guard let event = CGEvent(source: nil) else { fail("macOS made no event") }
    event.setDoubleValueField(field(55), value: 29)
    event.setDoubleValueField(field(110), value: 8)
    event.setDoubleValueField(field(132), value: phase)
    event.setDoubleValueField(field(113), value: amount)
    event.location = point
    post(event, at: .cgSessionEventTap)
  }
  let f19: CGKeyCode = 80
  let began = Date()
  let end = began.addingTimeInterval(seconds)
  var up = true
  var beat = 0.0
  print("\(now()) stream begins")
  while Date() < end {
    if let held {
      let elapsed = Date().timeIntervalSince(began)
      if flags.isEmpty, held.contains(elapsed) { modifiers(down: true) }
      if !flags.isEmpty, !held.contains(elapsed) { modifiers(down: false) }
    }
    if kinds.contains("click") {
      post(CGEvent(mouseEventSource: source, mouseType: .leftMouseDown, mouseCursorPosition: point, mouseButton: .left))
      post(CGEvent(mouseEventSource: source, mouseType: .leftMouseUp, mouseCursorPosition: point, mouseButton: .left))
    }
    if kinds.contains("key") {
      post(CGEvent(keyboardEventSource: source, virtualKey: f19, keyDown: true))
      post(CGEvent(keyboardEventSource: source, virtualKey: f19, keyDown: false))
    }
    if kinds.contains("wheel") {
      // Up and down in turn, so that a view that follows them goes nowhere.
      let notch = CGEvent(scrollWheelEvent2Source: source, units: .line, wheelCount: 1, wheel1: up ? 1 : -1, wheel2: 0, wheel3: 0)
      notch?.location = point
      post(notch)
      if held != nil { up.toggle() }
    }
    if kinds.contains("pinch") {
      magnify(0, phase: 1)
      magnify(0.01, phase: 2)
      magnify(0, phase: 4)
    }
    // By the clock and not by a pause after each beat: posting takes its time too, on a hosted Mac as long again as the pause.
    beat += 1
    let wait = began.addingTimeInterval(beat * milliseconds / 1000).timeIntervalSinceNow
    if wait > 0 { Thread.sleep(forTimeInterval: wait) }
  }
  if !flags.isEmpty { modifiers(down: false) }
  print("\(now()) stream ends: \(number) events posted")
}

/// Downs and ups far apart, so that whatever happens in between falls between them.
func pairs(seconds: Double, at point: CGPoint) {
  let source = CGEventSource(stateID: .hidSystemState)
  var number: Int64 = 0
  func post(_ event: CGEvent?, _ what: String) {
    guard let event else { fail("macOS made no event") }
    number += 1
    event.setIntegerValueField(.eventSourceUserData, value: streamMark + number)
    event.post(tap: .cghidEventTap)
    print("\(now()) posted n=\(number) \(what)")
  }
  let f19: CGKeyCode = 80
  let shift: CGKeyCode = 56
  func button(_ down: Bool) {
    post(CGEvent(mouseEventSource: source, mouseType: down ? .leftMouseDown : .leftMouseUp, mouseCursorPosition: point, mouseButton: .left), down ? "down" : "up")
  }
  func key(_ down: Bool) { post(CGEvent(keyboardEventSource: source, virtualKey: f19, keyDown: down), down ? "key-down" : "key-up") }
  func modifier(_ down: Bool) {
    let event = CGEvent(keyboardEventSource: source, virtualKey: shift, keyDown: down)
    let flags: CGEventFlags = down ? .maskShift : []
    event?.flags = flags
    post(event, down ? "shift-down" : "shift-up")
  }
  // In sixths of a cycle of 800 ms: the button goes down at 0 and up at 3, the key at 1 and 4, ⇧ at 2 and 5.
  let began = Date()
  var step = 0
  print("\(now()) stream begins")
  while Date().timeIntervalSince(began) < seconds || step % 6 != 0 {
    switch step % 6 {
    case 0: button(true)
    case 1: key(true)
    case 2: modifier(true)
    case 3: button(false)
    case 4: key(false)
    default: modifier(false)
    }
    step += 1
    let wait = began.addingTimeInterval(Double(step) * 0.8 / 6).timeIntervalSinceNow
    if wait > 0 { Thread.sleep(forTimeInterval: wait) }
  }
  print("\(now()) stream ends: \(number) events posted")
}

var arrivalsPort: CFMachPort?

func arrivals(seconds: Double) {
  var mask = CGEventMask(0)
  for type in [1, 2, 6, 10, 11, 12, 22, 29] { mask |= CGEventMask(1) << CGEventMask(type) }
  let callback: CGEventTapCallBack = { _, type, event, _ in
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
      print("\(now()) switched-off \(type.rawValue)")
      if let port = arrivalsPort { CGEvent.tapEnable(tap: port, enable: true) }
      return Unmanaged.passUnretained(event)
    }
    let names: [UInt32: String] = [
      1: "down", 2: "up", 6: "dragged", 10: "key-down", 11: "key-up", 12: "modifiers", 22: "wheel", 29: "gesture",
    ]
    var mods = ""
    if event.flags.contains(.maskControl) { mods += "ctrl+" }
    if event.flags.contains(.maskAlternate) { mods += "opt+" }
    if event.flags.contains(.maskShift) { mods += "shift+" }
    if event.flags.contains(.maskCommand) { mods += "cmd+" }
    let data = event.getIntegerValueField(.eventSourceUserData)
    // An event's timestamp is in nanoseconds on the clock that stops while the Mac sleeps.
    let late = (Int64(clock_gettime_nsec_np(CLOCK_UPTIME_RAW)) - Int64(event.timestamp)) / 1000
    let whose = data > streamMark && data < streamMark + 0x1000_0000 ? "n=\(data - streamMark)" : "other=\(data)"
    print("\(now()) \(names[type.rawValue] ?? "type\(type.rawValue)") \(whose) late_us=\(late) mods=\(mods.isEmpty ? "none" : String(mods.dropLast()))")
    return Unmanaged.passUnretained(event)
  }
  arrivalsPort = CGEvent.tapCreate(
    tap: .cgSessionEventTap, place: .tailAppendEventTap, options: .listenOnly, eventsOfInterest: mask, callback: callback, userInfo: nil)
  guard let port = arrivalsPort else { fail("macOS refused the tap") }
  CFRunLoopAddSource(CFRunLoopGetCurrent(), CFMachPortCreateRunLoopSource(kCFAllocatorDefault, port, 0), .commonModes)
  CGEvent.tapEnable(tap: port, enable: true)
  print("\(now()) arrivals-ready")
  CFRunLoopRunInMode(.defaultMode, seconds, false)
}

// MARK: What an app sees

final class Onlooker: NSObject, NSApplicationDelegate {
  let log: FileHandle
  let frame: CGRect
  var window: NSWindow?
  var held = ""

  init(log: FileHandle, frame: CGRect) {
    self.log = log
    self.frame = frame
  }

  func write(_ line: String) { log.write(Data("\(now()) \(line)\n".utf8)) }

  /// What is down, by AppKit's word in this app and by the window server's for the whole session.
  func look() {
    let server = CGEventSourceStateID.combinedSessionState
    let state =
      "button=\(CGEventSource.buttonState(server, button: .left) ? "down" : "up") appkit-button=\(NSEvent.pressedMouseButtons & 1 != 0 ? "down" : "up")"
      + " f19=\(CGEventSource.keyState(server, key: 80) ? "down" : "up") shift-key=\(CGEventSource.keyState(server, key: 56) ? "down" : "up")"
      + " shift-flag=\(CGEventSource.flagsState(server).contains(.maskShift) ? "on" : "off") appkit-shift=\(NSEvent.modifierFlags.contains(.shift) ? "on" : "off")"
    if state != held {
      held = state
      write("held \(state)")
    }
  }

  func applicationDidFinishLaunching(_ notification: Notification) {
    let height = NSScreen.screens.first?.frame.height ?? 768
    let rect = NSRect(x: frame.minX, y: height - frame.maxY, width: frame.width, height: frame.height)
    let window = NSWindow(contentRect: rect, styleMask: [.titled], backing: .buffered, defer: false)
    window.title = "Onlooker"
    window.setFrame(rect, display: true)
    window.makeKeyAndOrderFront(nil)
    self.window = window
    let kinds: NSEvent.EventTypeMask = [.leftMouseDown, .leftMouseUp, .leftMouseDragged, .keyDown, .keyUp, .flagsChanged]
    NSEvent.addLocalMonitorForEvents(matching: kinds) { [weak self] event in
      let names: [NSEvent.EventType: String] = [
        .leftMouseDown: "down", .leftMouseUp: "up", .leftMouseDragged: "dragged", .keyDown: "key-down", .keyUp: "key-up", .flagsChanged: "modifiers",
      ]
      let data = event.cgEvent?.getIntegerValueField(.eventSourceUserData) ?? 0
      var line = "saw \(names[event.type] ?? "?") \(data > streamMark ? "n=\(data - streamMark)" : "other")"
      if event.type == .keyDown { line += " repeat=\(event.isARepeat)" }
      line += " shift=\(event.modifierFlags.contains(.shift) ? "on" : "off")"
      self?.write(line)
      // Keys are swallowed, so that nothing beeps; the mouse's events go on to the window.
      return event.type == .keyDown || event.type == .keyUp ? nil : event
    }
    let timer = Timer(timeInterval: 0.02, repeats: true) { [weak self] _ in MainActor.assumeIsolated { self?.look() } }
    RunLoop.main.add(timer, forMode: .common)
    NSApp.activate(ignoringOtherApps: true)
    write("window-ready pid=\(getpid())")
  }
}

func onlook(seconds: Double, into path: String, frame: CGRect) -> Never {
  if !FileManager.default.fileExists(atPath: path) { FileManager.default.createFile(atPath: path, contents: nil) }
  guard let log = FileHandle(forWritingAtPath: path) else { fail("cannot write \(path)") }
  log.seekToEndOfFile()
  let delegate = Onlooker(log: log, frame: frame)
  let application = NSApplication.shared
  application.delegate = delegate
  application.setActivationPolicy(.accessory)
  DispatchQueue.main.asyncAfter(deadline: .now() + seconds) { exit(0) }
  withExtendedLifetime(delegate) { application.run() }
  exit(0)
}

// MARK: A bare tapper

var bareTap: CFMachPort?
var bareLog: FileHandle?

/// What any tool with an event tap is, and nothing more: to tell what macOS does to a tapper that loses the permission from what Arbor does about it.
func tap(seconds: Double, into path: String) {
  if !FileManager.default.fileExists(atPath: path) { FileManager.default.createFile(atPath: path, contents: nil) }
  guard let file = FileHandle(forWritingAtPath: path) else { fail("cannot write \(path)") }
  file.seekToEndOfFile()
  bareLog = file
  let callback: CGEventTapCallBack = { _, type, event, _ in
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
      bareLog?.write(Data("\(now()) switched-off \(type == .tapDisabledByTimeout ? "by timeout" : "by user input")\n".utf8))
    }
    return Unmanaged.passUnretained(event)
  }
  bareTap = CGEvent.tapCreate(
    tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap,
    eventsOfInterest: CGEventMask(1) << CGEventMask(CGEventType.leftMouseDown.rawValue), callback: callback, userInfo: nil)
  guard let port = bareTap else {
    file.write(Data("\(now()) refused\n".utf8))
    fail("macOS refused the tap")
  }
  CFRunLoopAddSource(CFRunLoopGetCurrent(), CFMachPortCreateRunLoopSource(kCFAllocatorDefault, port, 0), .commonModes)
  CGEvent.tapEnable(tap: port, enable: true)
  file.write(Data("\(now()) tap-ready pid=\(getpid())\n".utf8))

  // Which question turns at the instant of the withdrawal, and what does asking cost? On a thread of its own: the tap's must not wait for them.
  let questions: [(String, () -> Bool)] = [
    ("tapIsEnabled", { CGEvent.tapIsEnabled(tap: port) }),
    ("AXIsProcessTrusted", { AXIsProcessTrusted() }),
    ("CGPreflightListenEventAccess", { CGPreflightListenEventAccess() }),
    ("CGPreflightPostEventAccess", { CGPreflightPostEventAccess() }),
    ("a trial tapCreate", { canTap(.defaultTap) }),
  ]
  let asking = Thread {
    var answers = [Bool?](repeating: nil, count: questions.count)
    var costs = [[UInt64]](repeating: [], count: questions.count)
    let end = Date().addingTimeInterval(seconds - 0.5)
    while Date() < end {
      for (index, question) in questions.enumerated() {
        let start = clock_gettime_nsec_np(CLOCK_UPTIME_RAW)
        let answer = question.1()
        costs[index].append((clock_gettime_nsec_np(CLOCK_UPTIME_RAW) - start) / 1000)
        if answers[index] != answer {
          answers[index] = answer
          file.write(Data("\(now()) question \(question.0) = \(answer ? "yes" : "no")\n".utf8))
        }
      }
      Thread.sleep(forTimeInterval: 0.01)
    }
    for (index, question) in questions.enumerated() {
      let sorted = costs[index].sorted()
      guard !sorted.isEmpty else { continue }
      file.write(Data(
        "\(now()) cost \(question.0): \(sorted.count) calls, µs: median \(sorted[sorted.count / 2]), 99th \(sorted[min(sorted.count - 1, sorted.count * 99 / 100)]), worst \(sorted[sorted.count - 1])\n".utf8))
    }
  }
  asking.start()
  CFRunLoopRunInMode(.defaultMode, seconds, false)
  file.write(Data("\(now()) the end: the tap is \(CGEvent.tapIsEnabled(tap: port) ? "on" : "off")\n".utf8))
}

// MARK: Go

var arguments = Array(CommandLine.arguments.dropFirst())
/// Takes an option and its values out of the arguments.
func option(_ name: String, values: Int) -> [String]? {
  guard let index = arguments.firstIndex(of: name) else { return nil }
  guard index + values < arguments.count else { fail(usage) }
  let found = Array(arguments[(index + 1)...(index + values)])
  arguments.removeSubrange(index...(index + values))
  return found
}
func number(_ index: Int) -> Double {
  guard index < arguments.count, let value = Double(arguments[index]) else { fail(usage) }
  return value
}

switch arguments.first {
case "ask":
  guard arguments.count == 3 else { fail(usage) }
  ask(seconds: number(1), into: arguments[2])
case "hear":
  hear(seconds: number(1))
case "announce":
  DistributedNotificationCenter.default().postNotificationName(announcement, object: nil, userInfo: nil, deliverImmediately: true)
  print("\(now()) announced \(announcement.rawValue)")
case "stream":
  let kinds = Set((option("--kinds", values: 1)?[0] ?? "click,key,wheel").split(separator: ",").map(String.init))
  let held = option("--ctrl-opt", values: 2).map { $0.compactMap(Double.init) }
  if let held, held.count != 2 || held[0] > held[1] { fail(usage) }
  stream(seconds: number(1), every: number(2), at: CGPoint(x: number(3), y: number(4)), kinds: kinds, held: held.map { $0[0]...$0[1] })
case "arrivals":
  arrivals(seconds: number(1))
case "pairs":
  pairs(seconds: number(1), at: CGPoint(x: number(2), y: number(3)))
case "window":
  guard arguments.count == 7 else { fail(usage) }
  onlook(seconds: number(1), into: arguments[2], frame: CGRect(x: number(3), y: number(4), width: number(5), height: number(6)))
case "tap":
  guard arguments.count == 3 else { fail(usage) }
  tap(seconds: number(1), into: arguments[2])
case "now":
  print(now())
default:
  fail(usage)
}
