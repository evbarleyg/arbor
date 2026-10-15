// sampler: writes down where every window on the screen is, sixty times a second, for as long as a script plays.
//
// Checks ask where a window is once things have settled. They cannot see how it got there: a window that went
// somewhere else first, moved twice, flashed into view and out again, or moved although nobody touched it looks the
// same at the end as one that moved once. A person sees all of that. So this tool asks the window server, which is what
// the screen shows, and keeps every change with its time; jolts.py reads the file afterwards and says, for each step
// of the script, which windows moved, how often, and by which road.
//
//   sampler <log file> <commands fifo> <replies fifo> [--hz n]
//
// It only looks: no Accessibility, no events, nothing is moved. It never reads a window's title. It does write down which
// apps have windows on the screen, so what it writes on a person's Mac is that person's. lib-day.sh compiles and wraps it.
//
// The log has one line per change, `<milliseconds since 1970> <kind> …`, in global points, origin top-left, y down:
//   W id pid layer x y w h owner   a window came on screen, or its frame changed (spaces in the owner's name are _). One that is wholly
//                                  transparent is not on the screen: nobody sees it
//   G id                           it left the screen: closed, hidden, minimized, or on another Space
//   Z id,id,…                      the order of the ordinary windows (layer 0) changed: from the frontmost to the one at the back
//   A pid bundle-id                another app came to the front
//   B down|up x y                  the left mouse button. A click that began and ended between two samples is written as both, at the later one
//   P x y                          the pointer moved while the button was down
//   K n                            n keys went down since the last sample. Never which
//   D x y w h                      the main display
//   V x y w h                      the main display between the menu bar and the Dock
//   Y id x y w h vx vy vw vh       another display: all of it, and the part of it between its menu bar and the Dock. `Y id` alone: it has gone
//   M text                         a mark of the script's
//   L ms                           this sample came late, over 100 ms after the one before (docs/VIABLE.md, sampler.late_ms): nothing was seen for that long
//   S …                            at the end: how many samples, how long one took, how many came late
//
// The grammar stays as it is: other tools write files in it that are merged with this one by time. A new kind is a new capital
// letter, and a reader skips the kinds it does not know. Taken besides the ones above: F, by whoever films the screen; E, by witness.swift.
//
// Commands, one per line:
//   mark <text>                    write an M line
//   quiet <ms> <limit ms> <word>   reply once no W (of an ordinary window), G, Z, B or K line was written for <ms>: `quiet <waited ms> <word>`, or
//                                  after <limit ms> at the latest: `restless <waited ms> <word>`. Never sooner than 350 ms after it was asked: what the
//                                  asker did last may not have shown yet. The word tells the asker which question is being answered
//   stop                           write the S line and end (so does the end of the fifo)

import AppKit
import CoreGraphics
import Foundation

func fail(_ message: String) -> Never {
  FileHandle.standardError.write(Data("sampler: \(message)\n".utf8))
  exit(64)
}

var arguments = Array(CommandLine.arguments.dropFirst())
var hertz = 60.0
if let index = arguments.firstIndex(of: "--hz") {
  guard arguments.count > index + 1, let value = Double(arguments[index + 1]), value >= 1, value <= 240 else {
    fail("--hz takes a number from 1 to 240")
  }
  hertz = value
  arguments.removeSubrange(index...(index + 1))
}
guard arguments.count == 3 else { fail("usage: sampler <log file> <commands fifo> <replies fifo> [--hz n]") }
/// Not `guard let`: what that binds at the top of a file is no global, and the class below could not use it.
nonisolated(unsafe) let logFile: UnsafeMutablePointer<FILE> = {
  guard let file = fopen(arguments[0], "a") else { fail("cannot write to \(arguments[0])") }
  return file
}()

@Sendable func now() -> Double { Date().timeIntervalSince1970 * 1000 }

/// `12` for 12.0 and `12.5` for 12.5.
@Sendable func text(_ value: CGFloat) -> String {
  let number = Double(value)
  return number == number.rounded() ? String(Int(number)) : String(format: "%.1f", number)
}

@Sendable func text(_ rect: CGRect) -> String {
  "\(text(rect.minX)) \(text(rect.minY)) \(text(rect.width)) \(text(rect.height))"
}

/// Three threads write: the one that samples, the one that reads commands, and the main one, which hears about apps.
let lock = NSLock()
/// When a line that `quiet` waits for was last written.
var lastChange = now()

@Sendable func write(_ time: Double, _ line: String, isChange: Bool = false) {
  lock.lock()
  fputs("\(Int64(time)) \(line)\n", logFile)
  if isChange { lastChange = time }
  lock.unlock()
}

@Sendable func sinceLastChange() -> Double {
  lock.lock()
  defer { lock.unlock() }
  return now() - lastChange
}

// MARK: Sampling

struct Seen: Equatable {
  var pid: Int
  var layer: Int
  var frame: CGRect
}

final class Sampler {
  /// A person sees a gap of this many milliseconds. One or two frames more or less they do not.
  static let late = 100.0
  private var windows: [Int: Seen] = [:]
  private var order: [Int] = []
  private var buttonIsDown = false
  private var pointer = CGPoint(x: -1, y: -1)
  private var keys = CGEventSource.counterForEventType(.combinedSessionState, eventType: .keyDown)
  private var presses = CGEventSource.counterForEventType(.combinedSessionState, eventType: .leftMouseDown)
  private(set) var samples = 0
  private(set) var late = 0
  private(set) var longestGap = 0.0
  private(set) var spent = 0.0

  func sample(gap: Double, period: Double) {
    let started = now()
    if gap > Sampler.late {
      late += 1
      write(started, "L \(Int(gap))")
    }
    longestGap = max(longestGap, gap)

    let list = (CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as NSArray?) ?? []
    var present = Set<Int>()
    var front: [Int] = []
    for case let info as NSDictionary in list {
      guard let id = (info[kCGWindowNumber] as? NSNumber)?.intValue,
        let bounds = info[kCGWindowBounds] as? NSDictionary,
        let frame = CGRect(dictionaryRepresentation: bounds as CFDictionary),
        // Arbor rehearses its stage after a start with a panel nobody can see, and apps keep such windows about.
        ((info[kCGWindowAlpha] as? NSNumber)?.doubleValue ?? 1) > 0
      else { continue }
      let seen = Seen(
        pid: (info[kCGWindowOwnerPID] as? NSNumber)?.intValue ?? 0, layer: (info[kCGWindowLayer] as? NSNumber)?.intValue ?? 0,
        frame: frame)
      present.insert(id)
      if seen.layer == 0 { front.append(id) }
      if windows[id] != seen {
        windows[id] = seen
        let owner = ((info[kCGWindowOwnerName] as? String) ?? "?").replacingOccurrences(of: " ", with: "_")
        write(started, "W \(id) \(seen.pid) \(seen.layer) \(text(frame)) \(owner)", isChange: seen.layer == 0)
      }
    }
    for (id, seen) in windows where !present.contains(id) {
      windows[id] = nil
      write(started, "G \(id)", isChange: seen.layer == 0)
    }
    if front != order {
      order = front
      write(started, "Z \(front.map(String.init).joined(separator: ","))", isChange: true)
    }

    let down = CGEventSource.buttonState(.combinedSessionState, button: .left)
    let pressedButton = CGEventSource.counterForEventType(.combinedSessionState, eventType: .leftMouseDown)
    if !down, !buttonIsDown, pressedButton != presses, let place = CGEvent(source: nil)?.location {
      // What a click sets off comes a moment later: whoever waits for quiet has to know that there was one.
      write(started, "B down \(text(place.x)) \(text(place.y))", isChange: true)
      write(started, "B up \(text(place.x)) \(text(place.y))", isChange: true)
    }
    presses = pressedButton
    if down || buttonIsDown, let place = CGEvent(source: nil)?.location {
      if down != buttonIsDown {
        write(started, "B \(down ? "down" : "up") \(text(place.x)) \(text(place.y))", isChange: true)
      } else if place != pointer {
        write(started, "P \(text(place.x)) \(text(place.y))")
      }
      pointer = place
    }
    buttonIsDown = down
    let pressed = CGEventSource.counterForEventType(.combinedSessionState, eventType: .keyDown)
    if pressed != keys {
      write(started, "K \(pressed &- keys)", isChange: true)
      keys = pressed
    }

    samples += 1
    spent += now() - started
    lock.lock()
    fflush(logFile)
    lock.unlock()
  }
}

let sampler = Sampler()
let started = now()
var stopping = false

let sampling = Thread {
  let period = 1000 / hertz
  var last = now()
  var next = last + period
  while !stopping {
    let time = now()
    autoreleasepool { sampler.sample(gap: time - last, period: period) }
    last = time
    // A sample that took longer than a period is not made up for: the next one is a period from now.
    next = max(next + period, now() + 1)
    Thread.sleep(forTimeInterval: max(0, next - now()) / 1000)
  }
}
sampling.qualityOfService = .userInteractive

@Sendable func finish() -> Never {
  stopping = true
  Thread.sleep(forTimeInterval: 0.1)
  let seconds = (now() - started) / 1000
  write(
    now(),
    String(
      format: "S samples %d seconds %.1f hz %.1f cost-ms %.2f late %d longest-gap-ms %d", sampler.samples, seconds,
      Double(sampler.samples) / max(seconds, 0.001), sampler.spent / Double(max(sampler.samples, 1)), sampler.late,
      Int(sampler.longestGap)))
  fflush(logFile)
  exit(0)
}

// MARK: Commands

// In this order, which is the order the script opens them in: opening a fifo waits for the other end.
guard let opened = fopen(arguments[1], "r") else { fail("cannot read \(arguments[1])") }
guard let answering = fopen(arguments[2], "w") else { fail("cannot write to \(arguments[2])") }
nonisolated(unsafe) let commands = opened
nonisolated(unsafe) let replies = answering

let listening = Thread {
  var buffer = [CChar](repeating: 0, count: 4096)
  while fgets(&buffer, Int32(buffer.count), commands) != nil {
    let line = String(cString: buffer).trimmingCharacters(in: .whitespacesAndNewlines)
    let words = line.split(separator: " ", maxSplits: 1).map(String.init)
    switch words.first {
    case "mark":
      write(now(), "M \(words.count > 1 ? words[1] : "")")
    case "quiet":
      let parts = (words.count > 1 ? words[1] : "").split(separator: " ").map(String.init)
      let wanted = parts.first.flatMap(Double.init) ?? 1000
      let limit = parts.count > 1 ? Double(parts[1]) ?? 8000 : 8000
      let word = parts.count > 2 ? " \(parts[2])" : ""
      let asked = now()
      var answer = "restless"
      while now() - asked < limit {
        if sinceLastChange() >= wanted, now() - asked >= 350 {
          answer = "quiet"
          break
        }
        Thread.sleep(forTimeInterval: 0.02)
      }
      fputs("\(answer) \(Int(now() - asked))\(word)\n", replies)
      fflush(replies)
    case "stop":
      finish()
    default:
      break
    }
  }
  finish()
}

// MARK: Apps and the display, which only a run loop hears about

let app = NSApplication.shared
app.setActivationPolicy(.prohibited)
// A process without a window is put to sleep between its timers (App Nap) and its timers are run together with others': on a hosted
// Mac every other sample came 40 to 70 ms late, with nothing else going on.
let awake = ProcessInfo.processInfo.beginActivity(
  options: [.userInitiated, .latencyCritical], reason: "sampling the window list at a steady rate")

@Sendable func noteFront(_ running: NSRunningApplication?) {
  guard let running else { return }
  write(now(), "A \(running.processIdentifier) \(running.bundleIdentifier ?? "?")")
}

@MainActor final class Display {
  private var bounds = CGRect.null
  private var visible = CGRect.null
  private var others: [String: String] = [:]

  func note() {
    let whole = CGDisplayBounds(CGMainDisplayID())
    if whole != bounds {
      bounds = whole
      write(now(), "D \(text(whole))")
    }
    guard let screen = NSScreen.screens.first else { return }
    // AppKit counts from the bottom of the main display.
    let frame = screen.visibleFrame
    let flipped = CGRect(x: frame.minX, y: screen.frame.maxY - frame.maxY, width: frame.width, height: frame.height)
    if flipped != visible {
      visible = flipped
      write(now(), "V \(text(flipped))")
    }
    var present: [String: String] = [:]
    for other in NSScreen.screens.dropFirst() {
      let id = (other.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.stringValue ?? "?"
      let all = CGRect(x: other.frame.minX, y: screen.frame.maxY - other.frame.maxY, width: other.frame.width, height: other.frame.height)
      let part = other.visibleFrame
      present[id] = "\(text(all)) \(text(CGRect(x: part.minX, y: screen.frame.maxY - part.maxY, width: part.width, height: part.height)))"
    }
    for (id, said) in present where others[id] != said { write(now(), "Y \(id) \(said)") }
    for id in others.keys where present[id] == nil { write(now(), "Y \(id)") }
    others = present
  }
}
let display = MainActor.assumeIsolated { Display() }

write(started, "M sampler at \(Int(hertz)) Hz")
noteFront(NSWorkspace.shared.frontmostApplication)
MainActor.assumeIsolated { display.note() }
NSWorkspace.shared.notificationCenter.addObserver(
  forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
) { note in
  noteFront(note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication)
}
// The Dock grows and shrinks as apps come and go, without a notification of its own.
Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { _ in MainActor.assumeIsolated { display.note() } }

sampling.start()
listening.start()
app.run()
