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
    stream <seconds> <ms> <x> <y>   every <ms> milliseconds: a click at x y, the key F19 and one notch of the wheel, numbered
    arrivals <seconds>              print each of those that reaches the end of the taps: the time, its kind, its number, how late
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

func stream(seconds: Double, every milliseconds: Double, at point: CGPoint) {
  let source = CGEventSource(stateID: .hidSystemState)
  var number: Int64 = 0
  func post(_ event: CGEvent?) {
    guard let event else { fail("macOS made no event") }
    number += 1
    event.setIntegerValueField(.eventSourceUserData, value: streamMark + number)
    event.post(tap: .cghidEventTap)
  }
  let f19: CGKeyCode = 80
  let end = Date().addingTimeInterval(seconds)
  print("\(now()) stream begins")
  while Date() < end {
    post(CGEvent(mouseEventSource: source, mouseType: .leftMouseDown, mouseCursorPosition: point, mouseButton: .left))
    post(CGEvent(mouseEventSource: source, mouseType: .leftMouseUp, mouseCursorPosition: point, mouseButton: .left))
    post(CGEvent(keyboardEventSource: source, virtualKey: f19, keyDown: true))
    post(CGEvent(keyboardEventSource: source, virtualKey: f19, keyDown: false))
    post(CGEvent(scrollWheelEvent2Source: source, units: .line, wheelCount: 1, wheel1: 1, wheel2: 0, wheel3: 0))
    Thread.sleep(forTimeInterval: milliseconds / 1000)
  }
  print("\(now()) stream ends: \(number) events posted")
}

var arrivalsPort: CFMachPort?

func arrivals(seconds: Double) {
  var mask = CGEventMask(0)
  for type in [1, 2, 10, 11, 22] { mask |= CGEventMask(1) << CGEventMask(type) }
  let callback: CGEventTapCallBack = { _, type, event, _ in
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
      print("\(now()) switched-off \(type.rawValue)")
      if let port = arrivalsPort { CGEvent.tapEnable(tap: port, enable: true) }
      return Unmanaged.passUnretained(event)
    }
    let names: [UInt32: String] = [1: "down", 2: "up", 10: "key-down", 11: "key-up", 22: "wheel"]
    let data = event.getIntegerValueField(.eventSourceUserData)
    // An event's timestamp is in nanoseconds on the clock that stops while the Mac sleeps.
    let late = (Int64(clock_gettime_nsec_np(CLOCK_UPTIME_RAW)) - Int64(event.timestamp)) / 1000
    let whose = data > streamMark && data < streamMark + 0x1000_0000 ? "n=\(data - streamMark)" : "other=\(data)"
    print("\(now()) \(names[type.rawValue] ?? "type\(type.rawValue)") \(whose) late_us=\(late)")
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

// MARK: Go

let arguments = Array(CommandLine.arguments.dropFirst())
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
  stream(seconds: number(1), every: number(2), at: CGPoint(x: number(3), y: number(4)))
case "arrivals":
  arrivals(seconds: number(1))
case "now":
  print(now())
default:
  fail(usage)
}
