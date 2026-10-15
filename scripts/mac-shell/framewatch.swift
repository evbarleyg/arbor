// framewatch: writes down WHEN the main display showed a new picture, and keeps no picture.
//
// A check asks where things are once they have settled. It cannot see a display that showed one picture for a second in the middle of a motion. ScreenCaptureKit
// hands over a frame whenever the display changed, up to sixty times a second, and says when it was shown and which part changed. This tool keeps those
// two facts and lets go of the frame: no pixel is read, copied or stored, so it costs next to nothing and what it writes shows nothing of what was on
// the screen. With pulse.swift's strip on the display every frame differs from the one before, and a wait between two lines IS a display that
// stood still. scripts/mac-shell/standstill.py reads the log.
//
//   framewatch [--blind] <log file>   commands on stdin, one per line; the end of stdin ends it
//     --blind                      no stream: keys, the button and marks only. For telling what the display does while nobody films it from what it
//                                  does because somebody does
//     mark <text>                  an M line. `mark scene <name>` begins a scene, `mark action` says that the thing is about to be done
//     stop
//
// It prints `framewatch-ready` once the first frame is there, or `framewatch-failed <why>` and exits with 3. It needs Screen Recording, which on GitHub's Macs
// a script's processes have. Of a key it writes only that one went down or up.
//
// The log is in the grammar of sampler.swift's, `<milliseconds since 1970> <kind> …`, in points, origin top-left, y down:
//   F n x y w h                    the nth new picture, and the smallest rectangle that holds what changed
//   K down|up                      a key (not a modifier)
//   B down|up x y                  the left mouse button
//   M text                         a mark of the script's

import AppKit
import ScreenCaptureKit

func fail(_ message: String) -> Never {
  print("framewatch-failed \(message)")
  exit(3)
}

setvbuf(stdout, nil, _IOLBF, 0)
var arguments = Array(CommandLine.arguments.dropFirst())
let isBlind = arguments.first == "--blind"
if isBlind { arguments.removeFirst() }
guard arguments.count == 1 else { fail("usage: framewatch [--blind] <log file>") }
/// Not `guard let`: what that binds at the top of a file is no global, and the functions below could not use it.
let logFile: UnsafeMutablePointer<FILE> = {
  guard let file = fopen(arguments[0], "a") else { fail("cannot write to \(arguments[0])") }
  return file
}()

// Frames are stamped on the clock that counts from the Mac's start. The two clocks were seen to part by a tenth of a second in four minutes on a hosted
// Mac, so they are tied together anew at every mark.
func uptime() -> UInt64 { clock_gettime_nsec_np(CLOCK_UPTIME_RAW) }
let lock = NSLock()
var tied = (calendar: Date().timeIntervalSince1970 * 1000, uptime: uptime())
func milliseconds(atUptime nanoseconds: UInt64) -> Int64 {
  Int64((tied.calendar + (Double(nanoseconds) - Double(tied.uptime)) / 1_000_000).rounded())
}
var timebase = mach_timebase_info_data_t()
mach_timebase_info(&timebase)
func nanoseconds(ofTicks ticks: UInt64) -> UInt64 { ticks * UInt64(timebase.numer) / UInt64(timebase.denom) }

func write(_ text: String, atUptime time: UInt64 = uptime(), tying: Bool = false) {
  lock.lock()
  if tying { tied = (Date().timeIntervalSince1970 * 1000, uptime()) }
  fputs("\(milliseconds(atUptime: time)) \(text)\n", logFile)
  // Whoever reads the log while it is being written finds everything up to the last mark.
  if tying { fflush(logFile) }
  lock.unlock()
}

var isReady = false
var count = 0

final class Watch: NSObject, SCStreamOutput, SCStreamDelegate {
  func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
    guard type == .screen, CMSampleBufferIsValid(sampleBuffer),
      let attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: false) as? [[SCStreamFrameInfo: Any]],
      let info = attachments.first, let raw = info[.status] as? Int, SCFrameStatus(rawValue: raw) == .complete
    else { return }
    var changed = CGRect.null
    for entry in info[.dirtyRects] as? [NSDictionary] ?? [] {
      if let rect = CGRect(dictionaryRepresentation: entry as CFDictionary) { changed = changed.union(rect) }
    }
    if changed.isNull { changed = .zero }
    let shown = (info[.displayTime] as? UInt64).map { nanoseconds(ofTicks: $0) } ?? uptime()
    count += 1
    write("F \(count) \(Int(changed.minX)) \(Int(changed.minY)) \(Int(changed.width)) \(Int(changed.height))", atUptime: shown)
    if !isReady {
      isReady = true
      print("framewatch-ready")
    }
  }

  func stream(_ stream: SCStream, didStopWithError error: any Error) {
    fail("the stream stopped: \(error.localizedDescription)")
  }
}

var tapPort: CFMachPort?

func listen() {
  var mask = CGEventMask(0)
  for type in [1, 2, 10, 11] { mask |= CGEventMask(1) << CGEventMask(type) }
  let callback: CGEventTapCallBack = { _, type, event, _ in
    switch type.rawValue {
    case 1: write("B down \(Int(event.location.x)) \(Int(event.location.y))")
    case 2: write("B up \(Int(event.location.x)) \(Int(event.location.y))")
    case 10: if event.getIntegerValueField(.keyboardEventAutorepeat) == 0 { write("K down") }
    case 11: write("K up")
    default: if let port = tapPort { CGEvent.tapEnable(tap: port, enable: true) }
    }
    return Unmanaged.passUnretained(event)
  }
  // Where a keyboard comes in, ahead of every tap of the session's, and only listening: nothing waits for this tool.
  tapPort = CGEvent.tapCreate(
    tap: .cghidEventTap, place: .headInsertEventTap, options: .listenOnly, eventsOfInterest: mask, callback: callback, userInfo: nil)
  guard let port = tapPort else { return }
  CFRunLoopAddSource(CFRunLoopGetMain(), CFMachPortCreateRunLoopSource(kCFAllocatorDefault, port, 0), .commonModes)
  CGEvent.tapEnable(tap: port, enable: true)
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
guard CGPreflightScreenCaptureAccess() else { fail("no Screen Recording permission, and nobody is asked for it") }
listen()

/// Kept for as long as the tool runs.
var stream: SCStream?
let watch = Watch()

func startTheStream() {
  var content: SCShareableContent?
  let asked = DispatchSemaphore(value: 0)
  SCShareableContent.getExcludingDesktopWindows(false, onScreenWindowsOnly: true) { found, _ in
    content = found
    asked.signal()
  }
  // Without the permission it may never answer, and nobody is there to press a key.
  if asked.wait(timeout: .now() + 10) == .timedOut { fail("ScreenCaptureKit did not answer") }
  guard let main = content?.displays.first(where: { $0.displayID == CGMainDisplayID() }) else {
    fail("ScreenCaptureKit lists no main display")
  }
  let configuration = SCStreamConfiguration()
  configuration.width = main.width
  configuration.height = main.height
  configuration.minimumFrameInterval = CMTime(value: 1, timescale: 60)
  configuration.pixelFormat = kCVPixelFormatType_32BGRA
  configuration.showsCursor = true
  configuration.queueDepth = 8
  let made = SCStream(filter: SCContentFilter(display: main, excludingWindows: []), configuration: configuration, delegate: watch)
  stream = made
  do {
    try made.addStreamOutput(watch, type: .screen, sampleHandlerQueue: DispatchQueue(label: "framewatch.frames"))
  } catch {
    fail("the stream takes no output: \(error.localizedDescription)")
  }
  made.startCapture { error in
    if let error { fail("the stream did not start: \(error.localizedDescription)") }
  }
  DispatchQueue.main.asyncAfter(deadline: .now() + 8) {
    if !isReady { fail("no frame in eight seconds") }
  }
}

if isBlind {
  print("framewatch-ready")
} else {
  startTheStream()
}

Thread.detachNewThread {
  while let line = readLine() {
    let words = line.split(separator: " ", maxSplits: 1).map(String.init)
    switch words.first ?? "" {
    case "mark": if words.count == 2 { write("M \(words[1])", tying: true) }
    case "stop":
      fflush(logFile)
      exit(0)
    default: print("framewatch: no command \(line)")
    }
  }
  fflush(logFile)
  exit(0)
}

app.run()
