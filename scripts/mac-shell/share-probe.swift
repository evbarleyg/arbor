// share-probe: what somebody watching a shared screen, or choosing a window to share, sees of windows that Arbor
// has moved out of view (docs/features/F58-hold-the-view.md). For scripts/mac-shell/check-F58.sh.
//
// A script compiles it itself (swiftc -O -swift-version 5 scripts/mac-shell/share-probe.swift -o …). `place` needs
// Accessibility, `shareable` and `capture` Screen Recording.

import AppKit
import ApplicationServices
import ImageIO
import ScreenCaptureKit

let usage = """
  usage: share-probe <command>
    place <pid> <window id> <x> <y>     ask for that position as Arbor does; prints the AXError and where the window is then
    edges <png> <reference png> <band> <top> <bottom>
                                        where the two pictures differ within <band> pixels of the left and right edges,
                                        in the rows from <top> to <bottom>: one line per column, then a summary
    shareable <window id>…              what ScreenCaptureKit, which Zoom, Meet and Teams build their pickers on, says of them
    capture <window id> <png>           the picture a share of that one window would send
    colours <png>                       its size, and how much of it is one flat colour
  """

func fail(_ message: String) -> Never {
  FileHandle.standardError.write(Data("share-probe: \(message)\n".utf8))
  exit(64)
}

@_silgen_name("_AXUIElementGetWindow")
func _AXUIElementGetWindow(_ element: AXUIElement, _ identifier: UnsafeMutablePointer<CGWindowID>) -> AXError

func windowElement(pid: pid_t, id: CGWindowID) -> AXUIElement? {
  var value: CFTypeRef?
  guard AXUIElementCopyAttributeValue(AXUIElementCreateApplication(pid), kAXWindowsAttribute as CFString, &value) == .success,
    let windows = value as? [AXUIElement]
  else { return nil }
  for window in windows {
    var number = CGWindowID(0)
    if _AXUIElementGetWindow(window, &number) == .success, number == id { return window }
  }
  return nil
}

func position(of element: AXUIElement) -> CGPoint? {
  var value: CFTypeRef?
  guard AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &value) == .success, let value else {
    return nil
  }
  var point = CGPoint.zero
  guard AXValueGetValue(value as! AXValue, .cgPoint, &point) else { return nil }
  return point
}

struct Bitmap {
  var width: Int
  var height: Int
  /// RGBA, rows from the top.
  var bytes: [UInt8]

  init?(path: String) {
    guard let source = CGImageSourceCreateWithURL(URL(fileURLWithPath: path) as CFURL, nil),
      let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
    else { return nil }
    self.init(image)
  }

  init?(_ image: CGImage) {
    width = image.width
    height = image.height
    bytes = [UInt8](repeating: 0, count: image.width * image.height * 4)
    let (w, h) = (width, height)
    let drawn = bytes.withUnsafeMutableBytes { buffer -> Bool in
      guard
        let context = CGContext(
          data: buffer.baseAddress, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
          space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
      else { return false }
      context.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
      return true
    }
    if !drawn { return nil }
  }

  /// The largest difference in any of red, green and blue.
  func difference(from other: Bitmap, x: Int, y: Int) -> Int {
    let index = (y * width + x) * 4
    return (0..<3).map { abs(Int(bytes[index + $0]) - Int(other.bytes[index + $0])) }.max() ?? 0
  }
}

func shareableWindows(onScreenOnly: Bool) -> [SCWindow] {
  var found: [SCWindow] = []
  let done = DispatchSemaphore(value: 0)
  SCShareableContent.getExcludingDesktopWindows(false, onScreenWindowsOnly: onScreenOnly) { content, error in
    if let error { print("error: \(error.localizedDescription)") }
    found = content?.windows ?? []
    done.signal()
  }
  // Without Screen Recording it may never answer, and nobody is there to press a key.
  if done.wait(timeout: .now() + 10) == .timedOut { fail("ScreenCaptureKit did not answer") }
  return found
}

func write(_ image: CGImage, to path: String) -> Bool {
  guard let destination = CGImageDestinationCreateWithURL(URL(fileURLWithPath: path) as CFURL, "public.png" as CFString, 1, nil)
  else { return false }
  CGImageDestinationAddImage(destination, image, nil)
  return CGImageDestinationFinalize(destination)
}

let arguments = Array(CommandLine.arguments.dropFirst())
guard let command = arguments.first else { fail(usage) }

switch command {
case "place":
  guard arguments.count == 5, let pid = pid_t(arguments[1]), let id = CGWindowID(arguments[2]), let x = Double(arguments[3]),
    let y = Double(arguments[4])
  else { fail(usage) }
  guard let element = windowElement(pid: pid, id: id) else { fail("process \(pid) lists no window \(id)") }
  var point = CGPoint(x: x, y: y)
  guard let value = AXValueCreate(.cgPoint, &point) else { fail("no AXValue") }
  let error = AXUIElementSetAttributeValue(element, kAXPositionAttribute as CFString, value)
  let now = position(of: element)
  print("asked \(Int(x)),\(Int(y)) error \(error.rawValue) now \(now.map { "\(Int($0.x)),\(Int($0.y))" } ?? "unknown")")

case "edges":
  guard arguments.count == 6, let picture = Bitmap(path: arguments[1]), let reference = Bitmap(path: arguments[2]),
    let band = Int(arguments[3]), let top = Int(arguments[4]), let bottom = Int(arguments[5])
  else { fail(usage) }
  guard picture.width == reference.width, picture.height == reference.height else {
    fail("the pictures are \(picture.width)x\(picture.height) and \(reference.width)x\(reference.height)")
  }
  var pixels = 0
  var plain = 0
  var strongest = 0
  let columns = Array(0..<min(band, picture.width)) + Array(max(picture.width - band, band)..<picture.width)
  for x in columns {
    var count = 0
    var most = 0
    var first = -1
    var last = -1
    for y in max(top, 0)..<min(bottom, picture.height) {
      let difference = picture.difference(from: reference, x: x, y: y)
      guard difference > 0 else { continue }
      count += 1
      most = max(most, difference)
      if first < 0 { first = y }
      last = y
      // What an eye, or a video codec, would keep.
      if difference >= 16 { plain += 1 }
    }
    guard count > 0 else { continue }
    print("column \(x): \(count) pixels differ, rows \(first) to \(last), by up to \(most) of 255")
    pixels += count
    strongest = max(strongest, most)
  }
  print("edges: \(pixels) pixels differ, \(plain) of them plainly (16 or more of 255), by up to \(strongest)")

case "shareable":
  let ids = Set(arguments.dropFirst().compactMap { CGWindowID($0) })
  let onScreen = Set(shareableWindows(onScreenOnly: true).map(\.windowID))
  for window in shareableWindows(onScreenOnly: false).sorted(by: { $0.windowID < $1.windowID }) where ids.contains(window.windowID) {
    let frame = window.frame
    print(
      "\(window.windowID): listed among on-screen windows \(onScreen.contains(window.windowID) ? "yes" : "no"), "
        + "isOnScreen \(window.isOnScreen), frame \(Int(frame.minX)),\(Int(frame.minY)) \(Int(frame.width))x\(Int(frame.height))")
  }

case "capture":
  guard arguments.count == 3, let id = CGWindowID(arguments[1]) else { fail(usage) }
  guard let window = shareableWindows(onScreenOnly: false).first(where: { $0.windowID == id }) else {
    fail("ScreenCaptureKit lists no window \(id)")
  }
  let configuration = SCStreamConfiguration()
  configuration.width = Int(window.frame.width)
  configuration.height = Int(window.frame.height)
  configuration.showsCursor = false
  let done = DispatchSemaphore(value: 0)
  var saved = false
  let path = arguments[2]
  SCScreenshotManager.captureImage(
    contentFilter: SCContentFilter(desktopIndependentWindow: window), configuration: configuration
  ) { image, error in
    if let error { print("error: \(error.localizedDescription)") }
    if let image { saved = write(image, to: path) }
    done.signal()
  }
  if done.wait(timeout: .now() + 10) == .timedOut { fail("ScreenCaptureKit did not answer") }
  print(saved ? "captured \(id): \(configuration.width)x\(configuration.height)" : "no picture of \(id)")
  exit(saved ? 0 : 1)

case "colours":
  guard arguments.count == 2, let picture = Bitmap(path: arguments[1]) else { fail(usage) }
  var counts: [UInt32: Int] = [:]
  for index in stride(from: 0, to: picture.bytes.count, by: 4) {
    let key = UInt32(picture.bytes[index]) << 16 | UInt32(picture.bytes[index + 1]) << 8 | UInt32(picture.bytes[index + 2])
    counts[key, default: 0] += 1
  }
  let total = picture.width * picture.height
  let top = counts.sorted { $0.value > $1.value }.prefix(3)
    .map { String(format: "#%06x %ld%%", $0.key, $0.value * 100 / max(total, 1)) }
  print("\(picture.width)x\(picture.height): \(top.joined(separator: ", "))")

default:
  fail(usage)
}
