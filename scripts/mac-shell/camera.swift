// camera: films the main display while a script plays, every frame the screen showed with the moment it showed it.
//
// A check asks where things are once they have settled, and a burst of screenshots gets fourteen pictures a second. Neither sees
// what a person sees of a motion that lasts half a second: whether it is eased, whether it is one motion, whether anything
// flickers, flashes or hops at the end. So this tool takes every frame from ScreenCaptureKit, which hands over a frame
// whenever the screen changed, up to sixty times a second, and says when it was shown. scripts/polish/judge.py reads the
// films afterwards and scores them against docs/POLISH.md. lib-film.sh compiles and wraps the tool.
//
//   camera [--fps n] [--poll]      commands on stdin, one per line; the end of stdin ends it
//
// It needs Screen Recording. It films the WHOLE main display, so it is for GitHub's Macs only: lib-film.sh starts it nowhere else.
// It never reads a window's title, and of a key it writes only that one went down or up.
//
// Commands:
//   begin <folder>                 keep every frame from now on. The folder exists and is empty. `<folder>/rolling` appears
//   mark <text>                    an M line
//   end                            stop keeping frames and write the film. `<folder>/done` appears last
//   metronome <kind>               a square of the camera's own crosses the display, so that a film of something KNOWN says what the
//                                  camera and the judge are worth on this Mac: `good` is the motion docs/POLISH.md asks for; `linear`,
//                                  `slow`, `twice`, `hop` and `flash` each break one of its rules, and the judge must say which
//   stop
//
// It prints `camera-ready <pixels wide> <pixels high> <scale> <stream|poll> <tap: listen-only|active|…|none>` once the first frame
// is there, or `camera-failed <why>` and exits with 3.
//
// A film is a folder: 0000.png is the whole display when it began. Every later NNNN.png is the smallest rectangle that holds
// what differs from the film so far, and is clear wherever nothing does: edges stay where they are to the pixel, as they would not in
// a video, and a frame in which two edges moved is a few hundred bytes. A pixel differs when red, green or blue is more than 2 of 255
// from what the film shows there (translucent things shimmer by 1 all the time, which nobody sees and which would be most of the
// bytes), and a frame in which nothing differs is left out. film.log is in the grammar of sampler.swift's log, so that the two
// merge by time: `<milliseconds since 1970> <kind> …`, in global points, origin top-left, y down:
//   D x y w h                      the main display
//   V x y w h                      the main display between the menu bar and the Dock
//   R w h scale                    the film's size in pixels, and pixels per point
//   F n x y w h                    frame n was shown, and its picture goes there, in pixels (0 is older than its line: it is what the
//                                  screen showed when the film began)
//   K down|up                      a key, or a modifier
//   B down|up x y                  the left mouse button
//   P x y                          the pointer moved while the button was down
//   M text                         a mark of the script's, or of the metronome's
//   L n                            n frames were dropped: the film was longer than the camera has room for
//   S frames=n seconds=s           at the end

import AppKit
import ImageIO
import ScreenCaptureKit

func fail(_ message: String) -> Never {
  print("camera-failed \(message)")
  exit(3)
}

setvbuf(stdout, nil, _IOLBF, 0)

var arguments = Array(CommandLine.arguments.dropFirst())
var framesPerSecond = 60
if let index = arguments.firstIndex(of: "--fps") {
  guard arguments.count > index + 1, let value = Int(arguments[index + 1]), value >= 1, value <= 120 else {
    fail("--fps takes a number from 1 to 120")
  }
  framesPerSecond = value
  arguments.removeSubrange(index...(index + 1))
}
var polls = false
if let index = arguments.firstIndex(of: "--poll") {
  polls = true
  arguments.remove(at: index)
}
guard arguments.isEmpty else { fail("usage: camera [--fps n] [--poll]") }

// MARK: Clocks

/// Frames and events are stamped on the clock that counts from the Mac's start. One reading of both clocks ties it to the calendar,
/// anew when a film begins: on a hosted Mac the two were seen to part by a tenth of a second in four minutes, and a film is
/// read beside Arbor's log.
func uptime() -> UInt64 { clock_gettime_nsec_np(CLOCK_UPTIME_RAW) }
var startedAt = (calendar: Date().timeIntervalSince1970 * 1000, uptime: uptime())
func milliseconds(atUptime nanoseconds: UInt64) -> Int64 {
  Int64((startedAt.calendar + (Double(nanoseconds) - Double(startedAt.uptime)) / 1_000_000).rounded())
}
func now() -> Int64 { milliseconds(atUptime: uptime()) }

var timebase = mach_timebase_info_data_t()
mach_timebase_info(&timebase)
func nanoseconds(ofTicks ticks: UInt64) -> UInt64 { ticks * UInt64(timebase.numer) / UInt64(timebase.denom) }

// MARK: The film

/// One frame: BGRA, rows from the top, no padding.
typealias Pixels = [UInt32]

/// Frames wait in memory until the film ends, so that writing them takes nothing from what is being filmed. This many bytes of
/// them: at 1024 × 768 six seconds in which every frame differs.
let room = 1_200_000_000

final class Reel {
  let lock = NSLock()
  var width = 0
  var height = 0
  /// What the screen shows now.
  var latest: Pixels?
  var folder: String?
  var frames: [(time: Int64, pixels: Pixels)] = []
  var lines: [(time: Int64, text: String)] = []
  var dropped = 0
  /// When the film began. A frame that was shown before, and handed over after, is what the film's first frame already shows.
  var began: Int64 = 0

  func note(_ text: String, at time: Int64 = now()) {
    lock.lock()
    if folder != nil { lines.append((time, text)) }
    lock.unlock()
  }

  func show(_ pixels: Pixels, width: Int, height: Int, at time: Int64) {
    lock.lock()
    self.width = width
    self.height = height
    latest = pixels
    if folder != nil, time > began {
      if (frames.count + 1) * pixels.count * 4 <= room {
        frames.append((time, pixels))
      } else {
        dropped += 1
      }
    }
    lock.unlock()
  }
}

let reel = Reel()

func write(_ pixels: Pixels, width: Int, height: Int, to path: String) -> Bool {
  var copy = pixels
  let image = copy.withUnsafeMutableBytes { buffer -> CGImage? in
    CGContext(
      data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
      space: CGColorSpaceCreateDeviceRGB(),
      bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)?.makeImage()
  }
  guard let image,
    let destination = CGImageDestinationCreateWithURL(URL(fileURLWithPath: path) as CFURL, "public.png" as CFString, 1, nil)
  else { return false }
  CGImageDestinationAddImage(destination, image, nil)
  return CGImageDestinationFinalize(destination)
}

func touch(_ path: String) { FileManager.default.createFile(atPath: path, contents: nil) }

func text(_ rect: CGRect) -> String { "\(Int(rect.minX)) \(Int(rect.minY)) \(Int(rect.width)) \(Int(rect.height))" }

func begin(_ folder: String) {
  // A screen on which nothing changes sends no frames, so the first one is the last that came.
  var tries = 0
  while reel.latest == nil, tries < 100 {
    usleep(20_000)
    tries += 1
  }
  reel.lock.lock()
  guard let first = reel.latest else {
    reel.lock.unlock()
    print("camera: no frame yet, so no film in \(folder)")
    return
  }
  startedAt = (Date().timeIntervalSince1970 * 1000, uptime())
  let time = now()
  reel.folder = folder
  reel.began = time
  reel.frames = [(time, first)]
  reel.lines = []
  reel.dropped = 0
  reel.lock.unlock()
  touch(folder + "/rolling")
}

/// Whether red, green or blue are more than 2 apart.
@inline(__always) func differs(_ a: UInt32, _ b: UInt32) -> Bool {
  if a == b { return false }
  return abs(Int32(a & 0xFF) - Int32(b & 0xFF)) > 2 || abs(Int32((a >> 8) & 0xFF) - Int32((b >> 8) & 0xFF)) > 2
    || abs(Int32((a >> 16) & 0xFF) - Int32((b >> 16) & 0xFF)) > 2
}

func end(display: CGRect, scale: Int) {
  reel.lock.lock()
  guard let folder = reel.folder else {
    reel.lock.unlock()
    return
  }
  reel.folder = nil
  var (frames, lines, dropped, width, height) = (reel.frames, reel.lines, reel.dropped, reel.width, reel.height)
  reel.frames = []
  reel.lines = []
  reel.lock.unlock()

  /// What somebody who plays the film sees so far.
  var shown: Pixels = []
  var kept = 0
  for frame in frames {
    guard frame.pixels.count == width * height else { continue }
    var picture = frame.pixels
    var (left, top, right, bottom) = (0, 0, width, height)
    if !shown.isEmpty {
      (left, top, right, bottom) = (width, height, 0, 0)
      for y in 0..<height {
        for x in 0..<width {
          let place = y * width + x
          if differs(picture[place], shown[place]) {
            shown[place] = picture[place]
            // Opaque wherever something is said, whatever the screen's own alpha was.
            picture[place] |= 0xFF00_0000
            (left, top, right, bottom) = (min(left, x), min(top, y), max(right, x + 1), max(bottom, y + 1))
          } else {
            picture[place] = 0
          }
        }
      }
      guard right > left else { continue }
      var part = Pixels()
      part.reserveCapacity((right - left) * (bottom - top))
      for y in top..<bottom { part.append(contentsOf: picture[(y * width + left)..<(y * width + right)]) }
      picture = part
    } else {
      shown = picture
    }
    if !write(picture, width: right - left, height: bottom - top, to: folder + "/" + String(format: "%04d.png", kept)) {
      print("camera: could not write frame \(kept) of \(folder)")
    }
    lines.append((frame.time, "F \(kept) \(left) \(top) \(right - left) \(bottom - top)"))
    kept += 1
  }
  frames = []
  // The Dock grows and shrinks with the apps that run, so the room between it and the menu bar is asked for film by film.
  var visible = display
  DispatchQueue.main.sync {
    guard let screen = NSScreen.screens.first else { return }
    // AppKit counts from the bottom of the main display.
    visible = CGRect(
      x: screen.visibleFrame.minX, y: screen.frame.maxY - screen.visibleFrame.maxY, width: screen.visibleFrame.width,
      height: screen.visibleFrame.height)
  }
  // Three threads write, so lines of the same moment may have come in either order.
  lines.sort { $0.time < $1.time }
  let first = lines.first?.time ?? now()
  let last = lines.last?.time ?? first
  var log = ["\(first) D \(text(display))", "\(first) V \(text(visible))", "\(first) R \(width) \(height) \(scale)"]
  log += lines.map { "\($0.time) \($0.text)" }
  if dropped > 0 { log.append("\(last) L \(dropped)") }
  log.append("\(last) S frames=\(kept) seconds=\(String(format: "%.2f", Double(last - first) / 1000))")
  try? (log.joined(separator: "\n") + "\n").write(toFile: folder + "/film.log", atomically: true, encoding: .utf8)
  touch(folder + "/done")
}

// MARK: Frames

func pixels(of buffer: CVPixelBuffer) -> (Pixels, Int, Int)? {
  guard CVPixelBufferGetPixelFormatType(buffer) == kCVPixelFormatType_32BGRA else { return nil }
  CVPixelBufferLockBaseAddress(buffer, .readOnly)
  defer { CVPixelBufferUnlockBaseAddress(buffer, .readOnly) }
  guard let base = CVPixelBufferGetBaseAddress(buffer) else { return nil }
  let (width, height, stride) = (CVPixelBufferGetWidth(buffer), CVPixelBufferGetHeight(buffer), CVPixelBufferGetBytesPerRow(buffer))
  var result = Pixels(repeating: 0, count: width * height)
  result.withUnsafeMutableBytes { target in
    guard let start = target.baseAddress else { return }
    for row in 0..<height { memcpy(start + row * width * 4, base + row * stride, width * 4) }
  }
  return (result, width, height)
}

func pixels(of image: CGImage) -> (Pixels, Int, Int)? {
  let (width, height) = (image.width, image.height)
  var result = Pixels(repeating: 0, count: width * height)
  let drawn = result.withUnsafeMutableBytes { buffer -> Bool in
    guard
      let context = CGContext(
        data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)
    else { return false }
    context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
    return true
  }
  return drawn ? (result, width, height) : nil
}

var isReady = false
var tapKind = "none"
func ready(_ width: Int, _ height: Int, _ scale: Int) {
  guard !isReady else { return }
  isReady = true
  print("camera-ready \(width) \(height) \(scale) \(polls ? "poll" : "stream") \(tapKind)")
}

final class Lens: NSObject, SCStreamOutput, SCStreamDelegate {
  let scale: Int
  init(scale: Int) { self.scale = scale }

  func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
    guard type == .screen, CMSampleBufferIsValid(sampleBuffer),
      let attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: false) as? [[SCStreamFrameInfo: Any]],
      let info = attachments.first, let raw = info[.status] as? Int, SCFrameStatus(rawValue: raw) == .complete,
      let buffer = CMSampleBufferGetImageBuffer(sampleBuffer), let (frame, width, height) = pixels(of: buffer)
    else { return }
    // When the frame was on the display, where macOS says so; else when it got here. A frame gets here within a few hundredths of a second. After a long rest macOS was seen to hand over
    // the first frame that changes with a time three quarters of a second old, before the key that caused it: a time that old is not believed.
    let here = now()
    var shown = (info[.displayTime] as? UInt64).map { milliseconds(atUptime: nanoseconds(ofTicks: $0)) } ?? here
    if abs(here - shown) > 250 { shown = here }
    reel.show(frame, width: width, height: height, at: shown)
    ready(width, height, scale)
  }

  func stream(_ stream: SCStream, didStopWithError error: any Error) {
    // Better no camera than one that goes on making films of the last frame it got: the script sees that it is gone.
    fail("the stream stopped: \(error.localizedDescription)")
  }
}

// MARK: Input

var tapPort: CFMachPort?

/// Where in time a frame stands to the key or the button that caused it is what "at once" means, and a script cannot
/// say when its event was posted: the tool that posts it takes longer to start than a frame lasts.
func listen() {
  var mask = CGEventMask(0)
  // Left button down, up and dragged; key down and up; modifiers.
  for type in [1, 2, 6, 10, 11, 12] { mask |= CGEventMask(1) << CGEventMask(type) }
  let callback: CGEventTapCallBack = { _, type, event, _ in
    switch type.rawValue {
    case 1: reel.note("B down \(Int(event.location.x)) \(Int(event.location.y))")
    case 2: reel.note("B up \(Int(event.location.x)) \(Int(event.location.y))")
    case 6: reel.note("P \(Int(event.location.x)) \(Int(event.location.y))")
    case 10: if event.getIntegerValueField(.keyboardEventAutorepeat) == 0 { reel.note("K down") }
    case 11: reel.note("K up")
    case 12: reel.note("K modifiers")
    default: if let port = tapPort { CGEvent.tapEnable(tap: port, enable: true) }
    }
    return Unmanaged.passUnretained(event)
  }
  // Where a mouse and a keyboard come in, ahead of every tap of the session's: Arbor swallows what it takes for its own (a ⌃⌥ drag), and
  // a tap made later goes in front of one made earlier.
  for (kind, place, options) in [
    ("listen-only", CGEventTapLocation.cghidEventTap, CGEventTapOptions.listenOnly),
    ("active", CGEventTapLocation.cghidEventTap, CGEventTapOptions.defaultTap),
    ("listen-only-in-the-session", CGEventTapLocation.cgSessionEventTap, CGEventTapOptions.listenOnly),
  ] {
    tapPort = CGEvent.tapCreate(
      tap: place, place: .headInsertEventTap, options: options, eventsOfInterest: mask, callback: callback, userInfo: nil)
    if tapPort != nil {
      tapKind = kind
      break
    }
  }
  guard let port = tapPort else { return }
  CFRunLoopAddSource(CFRunLoopGetMain(), CFMachPortCreateRunLoopSource(kCFAllocatorDefault, port, 0), .commonModes)
  CGEvent.tapEnable(tap: port, enable: true)
}

// MARK: The metronome

/// A square on a panel of its own, above everything but the menu bar, that takes no clicks.
final class Metronome {
  static let side: CGFloat = 160
  let panel: NSPanel
  let square = CALayer()
  let spark = CALayer()
  let travel: CGFloat

  init(in visible: NSRect) {
    let strip = NSRect(x: visible.minX + 40, y: visible.midY - Self.side / 2, width: visible.width - 80, height: Self.side)
    panel = NSPanel(contentRect: strip, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
    panel.isOpaque = false
    panel.backgroundColor = .clear
    panel.hasShadow = false
    panel.ignoresMouseEvents = true
    panel.level = .statusBar
    let view = NSView(frame: NSRect(origin: .zero, size: strip.size))
    let root = CALayer()
    view.layer = root
    view.wantsLayer = true
    panel.contentView = view
    travel = strip.width - Self.side
    square.backgroundColor = CGColor(srgbRed: 1, green: 0, blue: 1, alpha: 1)
    square.frame = CGRect(x: 0, y: 0, width: Self.side, height: Self.side)
    spark.backgroundColor = CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 1)
    spark.frame = CGRect(x: strip.width / 2 - 60, y: 20, width: 120, height: 120)
    spark.isHidden = true
    root.addSublayer(spark)
    root.addSublayer(square)
  }

  func place(_ x: CGFloat) {
    CATransaction.begin()
    CATransaction.setDisableActions(true)
    square.removeAllAnimations()
    square.frame.origin.x = x
    CATransaction.commit()
  }

  func glide(to x: CGFloat, seconds: Double, curve: CAMediaTimingFunction) {
    CATransaction.begin()
    CATransaction.setDisableActions(false)
    CATransaction.setAnimationDuration(seconds)
    CATransaction.setAnimationTimingFunction(curve)
    square.frame.origin.x = x
    CATransaction.commit()
  }

  func after(_ seconds: Double, _ body: @escaping () -> Void) {
    DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: body)
  }

  func play(_ kind: String) {
    // Arbor's own curve and time (Transition.curve, `animationDuration`).
    let eased = CAMediaTimingFunction(controlPoints: 0.2, 0, 0, 1)
    place(0)
    spark.isHidden = true
    panel.orderFrontRegardless()
    // The square is seen standing still first, as a window is before it moves.
    after(0.5) { [self] in
      reel.note("M metronome \(kind) goes \(Int(travel)) points")
      switch kind {
      case "good": glide(to: travel, seconds: 0.46, curve: eased)
      case "linear": glide(to: travel, seconds: 0.46, curve: CAMediaTimingFunction(name: .linear))
      case "slow": glide(to: travel, seconds: 0.9, curve: eased)
      case "twice":
        glide(to: travel / 2, seconds: 0.3, curve: eased)
        after(0.45) { [self] in glide(to: travel, seconds: 0.3, curve: eased) }
      case "hop":
        glide(to: travel - 9, seconds: 0.46, curve: eased)
        after(0.52) { [self] in place(travel) }
      case "flash":
        glide(to: travel, seconds: 0.46, curve: eased)
        // Two frames long, and timed where the glide is timed, not by a timer of this process: on a busy Mac that came 150 ms late.
        let blink = CAKeyframeAnimation(keyPath: "opacity")
        blink.values = [0, 1, 0]
        // In this mode each time says when its value begins, and the last one when the last value ends.
        blink.keyTimes = [0, 0.5, 0.572, 1]
        blink.calculationMode = .discrete
        blink.duration = 0.46
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        spark.opacity = 0
        spark.isHidden = false
        CATransaction.commit()
        spark.add(blink, forKey: "blink")
      default: print("camera: no metronome \(kind)")
      }
    }
    after(2.0) { [self] in
      reel.note("M metronome \(kind) is over")
      panel.orderOut(nil)
    }
  }
}

// MARK: Running

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
guard CGPreflightScreenCaptureAccess() else { fail("no Screen Recording permission, and nobody is asked for it") }
guard let screen = NSScreen.screens.first else { fail("no display") }
let scale = Int(screen.backingScaleFactor)
let display = CGDisplayBounds(CGMainDisplayID())
let metronome = Metronome(in: screen.visibleFrame)
listen()

var content: SCShareableContent?
let asked = DispatchSemaphore(value: 0)
SCShareableContent.getExcludingDesktopWindows(false, onScreenWindowsOnly: true) { found, error in
  if let error { print("camera: \(error.localizedDescription)") }
  content = found
  asked.signal()
}
// Without the permission it may never answer, and nobody is there to press a key.
if asked.wait(timeout: .now() + 10) == .timedOut { fail("ScreenCaptureKit did not answer") }
guard let main = content?.displays.first(where: { $0.displayID == CGMainDisplayID() }) else {
  fail("ScreenCaptureKit lists no main display")
}

let filter = SCContentFilter(display: main, excludingWindows: [])
let configuration = SCStreamConfiguration()
configuration.width = main.width * scale
configuration.height = main.height * scale
configuration.minimumFrameInterval = CMTime(value: 1, timescale: CMTimeScale(framesPerSecond))
configuration.pixelFormat = kCVPixelFormatType_32BGRA
configuration.showsCursor = true
configuration.queueDepth = 8

let lens = Lens(scale: scale)
var stream: SCStream?

/// For a Mac on which the stream does not come: one picture after another, as fast as they can be had.
func poll() {
  polls = true
  Thread.detachNewThread {
    while true {
      let taken = DispatchSemaphore(value: 0)
      SCScreenshotManager.captureImage(contentFilter: filter, configuration: configuration) { image, error in
        if let image, let (frame, width, height) = pixels(of: image) {
          // Only what differs is a frame, as in a stream.
          reel.lock.lock()
          let same = reel.latest.map { $0 == frame } ?? false
          reel.lock.unlock()
          if !same { reel.show(frame, width: width, height: height, at: now()) }
          ready(width, height, scale)
        } else if !isReady {
          fail("no picture either: \(error?.localizedDescription ?? "no reason given")")
        }
        taken.signal()
      }
      _ = taken.wait(timeout: .now() + 5)
    }
  }
}

if polls {
  poll()
} else {
  let made = SCStream(filter: filter, configuration: configuration, delegate: lens)
  stream = made
  do {
    try made.addStreamOutput(lens, type: .screen, sampleHandlerQueue: DispatchQueue(label: "camera.frames"))
  } catch {
    fail("the stream takes no output: \(error.localizedDescription)")
  }
  made.startCapture { error in
    guard let error else { return }
    print("camera: the stream did not start: \(error.localizedDescription); taking pictures instead")
    poll()
  }
  DispatchQueue.main.asyncAfter(deadline: .now() + 6) {
    guard !isReady, !polls else { return }
    print("camera: no frame from the stream in six seconds; taking pictures instead")
    poll()
  }
}

Thread.detachNewThread {
  while let line = readLine() {
    let words = line.split(separator: " ", maxSplits: 1).map(String.init)
    switch words.first ?? "" {
    case "begin": if words.count == 2 { begin(words[1]) }
    case "mark": if words.count == 2 { reel.note("M \(words[1])") }
    case "end": end(display: display, scale: scale)
    case "metronome":
      let kind = words.count == 2 ? words[1] : "good"
      DispatchQueue.main.async { metronome.play(kind) }
    case "stop": exit(0)
    default: print("camera: no command \(line)")
    }
  }
  exit(0)
}

app.run()
