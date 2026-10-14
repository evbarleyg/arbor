// scenery: something to look at behind Arbor, for Mac shell scripts that take pictures of its looks.
//
// GitHub's Macs have a black wallpaper, on which darkening and blurring show nothing. This tool draws a
// landscape with soft gradients and hard edges (hills, a sun or a moon, stars), so that both can be
// judged; lib.sh's `wallpaper <file>` shows it. The picture is Arbor's own, so screenshots of it can go anywhere.
//
// A person's Mac keeps its wallpaper, and a picture of its screen would show what that person has open. There the
// landscape hangs in front of the wallpaper as a curtain, and pictures hold the script's own windows only.
//
//   scenery landscape <day|night> <width> <height> <file>   draw it that many pixels large and save it as a PNG
//   scenery curtain <day|night> <seconds>                   hang it over the main display's wallpaper and icons, under
//                                                           every window, Arbor's backdrop included; at most that long
//   scenery capture <file> <x,y,w,h|-> <pid>…               a picture of that rectangle of the main display (global points;
//                                                           - is all of it) on which only these processes' windows
//                                                           are, and the pointer
//   scenery materials <seconds> [light|dark]                RUN 1 ONLY: a sheet of blur materials to choose from
//
// A script compiles it as lib.sh compiles pointer.swift: swiftc -O -swift-version 5.

import AppKit
import ScreenCaptureKit

func fail(_ message: String) -> Never {
  FileHandle.standardError.write(Data("scenery: \(message)\n".utf8))
  exit(64)
}

func colour(_ hex: UInt32) -> CGColor {
  CGColor(
    srgbRed: CGFloat((hex >> 16) & 0xff) / 255, green: CGFloat((hex >> 8) & 0xff) / 255, blue: CGFloat(hex & 0xff) / 255,
    alpha: 1)
}

/// The same picture every time: a small generator instead of the system's.
struct Dice {
  var state: UInt64 = 7
  mutating func roll(_ sides: Int) -> Int {
    state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
    return Int((state >> 33) % UInt64(max(sides, 1)))
  }
}

func landscape(night: Bool, width: Int, height: Int) -> CGImage? {
  guard let space = CGColorSpace(name: CGColorSpace.sRGB),
    let context = CGContext(
      data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0, space: space,
      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
  else { return nil }
  let w = CGFloat(width)
  let h = CGFloat(height)

  // The sky, from the top of the picture down to the horizon. y grows upward here.
  let sky = (night ? [0x0b1030, 0x2a2a6a, 0x7a4f8f] : [0x3f8fd6, 0x9fd0ee, 0xffe3b3]).map { colour(UInt32($0)) }
  if let gradient = CGGradient(colorsSpace: space, colors: sky as CFArray, locations: [0, 0.6, 1]) {
    context.drawLinearGradient(
      gradient, start: CGPoint(x: 0, y: h), end: CGPoint(x: 0, y: h * 0.25), options: [.drawsAfterEndLocation])
  }

  if night {
    var dice = Dice()
    context.setFillColor(colour(0xffffff))
    for _ in 0..<160 {
      let x = CGFloat(dice.roll(width))
      let y = h - CGFloat(dice.roll(Int(h * 0.6)))
      let radius = 1 + CGFloat(dice.roll(3)) / 2
      context.fillEllipse(in: CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2))
    }
  }

  let radius = h * 0.075
  context.setFillColor(colour(night ? 0xf4f1de : 0xfff4c2))
  context.fillEllipse(in: CGRect(x: w * 0.68 - radius, y: h * 0.70 - radius, width: radius * 2, height: radius * 2))

  // Four ranges of hills, the nearest last and darkest.
  let hills: [UInt32] = night ? [0x3a3a7a, 0x2c2c62, 0x1f2049, 0x141533] : [0x8fc7a0, 0x5fae7f, 0x3c8f68, 0x256b52]
  for (index, hex) in hills.enumerated() {
    let range = CGFloat(index)
    let path = CGMutablePath()
    path.move(to: .zero)
    var x: CGFloat = 0
    while x <= w {
      let t = x / w * .pi * 2
      let wave = sin(t * (1.3 + 0.5 * range) + range * 1.7) + 0.4 * sin(t * 3.1 + range)
      path.addLine(to: CGPoint(x: x, y: h * (0.46 - 0.10 * range) + h * 0.06 * wave))
      x += 2
    }
    path.addLine(to: CGPoint(x: w, y: 0))
    path.closeSubpath()
    context.addPath(path)
    context.setFillColor(colour(hex))
    context.fillPath()
  }
  return context.makeImage()
}

func saveLandscape(night: Bool, width: Int, height: Int, path: String) {
  guard (16...16384).contains(width), (16...16384).contains(height),
    let image = landscape(night: night, width: width, height: height),
    let data = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])
  else { fail("could not draw a \(width)×\(height) picture") }
  do {
    try data.write(to: URL(fileURLWithPath: path))
    print("landscape: \(path) (\(width)×\(height))")
  } catch {
    fail("could not save \(path): \(error)")
  }
}

/// The level of the Finder's window with the Desktop's icons. Arbor's backdrop lies one above it.
let desktopLevel = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)))

/// A window of this process's own and nothing more: the wallpaper, the icons and the settings stay as they are, clicks
/// go through it, and it is gone when the process ends, which it does by itself after `seconds`.
@MainActor
func showCurtain(night: Bool, seconds: Double) {
  let application = NSApplication.shared
  application.setActivationPolicy(.accessory)
  guard let screen = NSScreen.screens.first else { fail("no display") }
  let scale = screen.backingScaleFactor
  guard
    let image = landscape(
      night: night, width: Int(screen.frame.width * scale), height: Int(screen.frame.height * scale))
  else { fail("could not draw the landscape") }
  let window = NSWindow(contentRect: screen.frame, styleMask: [.borderless], backing: .buffered, defer: false)
  window.level = desktopLevel
  window.hasShadow = false
  window.ignoresMouseEvents = true
  window.collectionBehavior = [.stationary, .ignoresCycle]
  let view = NSImageView(frame: NSRect(origin: .zero, size: screen.frame.size))
  view.image = NSImage(cgImage: image, size: screen.frame.size)
  view.imageScaling = .scaleAxesIndependently
  window.contentView = view
  window.setFrame(screen.frame, display: true)
  window.orderFrontRegardless()
  DispatchQueue.main.asyncAfter(deadline: .now() + seconds) { exit(0) }
  application.run()
}

/// Asks the window server to draw the main display with the windows of `pids` and no others: not the menu bar, not
/// the Dock, not the wallpaper, nobody else's windows. So the picture cannot show anything of the person whose Mac it is.
@MainActor
func capture(path: String, part: CGRect?, pids: Set<pid_t>) -> Never {
  // Asking ScreenCaptureKit without the permission raises macOS's dialog. This only looks, and nobody is asked.
  guard CGPreflightScreenCaptureAccess() else { fail("no Screen Recording permission") }
  _ = NSApplication.shared  // Connects to the window server, which ScreenCaptureKit takes for granted.
  Task {
    do {
      let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
      guard let display = content.displays.first(where: { $0.displayID == CGMainDisplayID() }) else {
        fail("the main display is not among those that can be captured")
      }
      let windows = content.windows.filter { window in
        guard let pid = window.owningApplication?.processID else { return false }
        return pids.contains(pid)
      }
      let filter = SCContentFilter(display: display, including: windows)
      let configuration = SCStreamConfiguration()
      // The main display's origin is that of the global coordinates, so a rectangle means the same in both.
      let area = part ?? CGRect(x: 0, y: 0, width: display.width, height: display.height)
      configuration.sourceRect = area
      configuration.width = Int(area.width * CGFloat(filter.pointPixelScale))
      configuration.height = Int(area.height * CGFloat(filter.pointPixelScale))
      configuration.showsCursor = true
      let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: configuration)
      guard let data = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) else {
        fail("could not make a PNG")
      }
      try data.write(to: URL(fileURLWithPath: path))
      exit(0)
    } catch {
      fail("no picture (does the terminal have the Screen Recording permission?): \(error)")
    }
  }
  dispatchMain()
}

/// RUN 1 ONLY. Every candidate material over the wallpaper, and two of them at reduced opacity, to see what each
/// does to the picture and whether an effect view can be faded.
@MainActor
func showMaterials(seconds: Double, mode: String?) {
  let application = NSApplication.shared
  application.setActivationPolicy(.accessory)
  if let mode { application.appearance = NSAppearance(named: mode == "dark" ? .darkAqua : .aqua) }
  guard let area = NSScreen.screens.first?.visibleFrame else { fail("no display") }
  let window = NSWindow(contentRect: area, styleMask: [.borderless], backing: .buffered, defer: false)
  // Where Arbor's backdrop lies, so that what the materials blur is what it would blur.
  window.level = NSWindow.Level(rawValue: desktopLevel.rawValue + 1)
  window.isOpaque = false
  window.backgroundColor = .clear
  window.hasShadow = false
  window.ignoresMouseEvents = true
  let content = NSView(frame: NSRect(origin: .zero, size: area.size))
  let samples: [(String, NSVisualEffectView.Material, CGFloat)] = [
    ("hudWindow", .hudWindow, 1), ("underWindowBackground", .underWindowBackground, 1),
    ("fullScreenUI", .fullScreenUI, 1), ("sidebar", .sidebar, 1),
    ("popover", .popover, 1), ("menu", .menu, 1), ("headerView", .headerView, 1),
    ("underPageBackground", .underPageBackground, 1),
    ("hudWindow 0.33", .hudWindow, 0.33), ("hudWindow 0.66", .hudWindow, 0.66),
    ("underWindowBackground 0.33", .underWindowBackground, 0.33),
    ("underWindowBackground 0.66", .underWindowBackground, 0.66),
  ]
  let columns = 4
  let rows = 3
  let cell = NSSize(width: area.width / CGFloat(columns), height: area.height / CGFloat(rows))
  for (index, sample) in samples.enumerated() {
    let frame = NSRect(
      x: CGFloat(index % columns) * cell.width, y: area.height - CGFloat(index / columns + 1) * cell.height,
      width: cell.width, height: cell.height
    ).insetBy(dx: 10, dy: 10)
    let view = NSVisualEffectView(frame: frame)
    view.material = sample.1
    view.blendingMode = .behindWindow
    view.state = .active
    view.alphaValue = sample.2
    content.addSubview(view)
    let label = NSTextField(labelWithString: sample.0)
    label.font = .systemFont(ofSize: 11, weight: .semibold)
    label.textColor = .labelColor
    label.frame = NSRect(x: frame.minX + 8, y: frame.maxY - 22, width: frame.width - 16, height: 16)
    content.addSubview(label)
  }
  window.contentView = content
  window.orderFrontRegardless()
  DispatchQueue.main.asyncAfter(deadline: .now() + seconds) { exit(0) }
  application.run()
}

MainActor.assumeIsolated {
  let arguments = Array(CommandLine.arguments.dropFirst())
  let command = arguments.first ?? ""
  if command == "landscape", arguments.count == 5, ["day", "night"].contains(arguments[1]),
    let width = Int(arguments[2]), let height = Int(arguments[3])
  {
    saveLandscape(night: arguments[1] == "night", width: width, height: height, path: arguments[4])
  } else if command == "curtain", arguments.count == 3, ["day", "night"].contains(arguments[1]) {
    showCurtain(night: arguments[1] == "night", seconds: min(max(Double(arguments[2]) ?? 60, 1), 900))
  } else if command == "capture", arguments.count >= 4 {
    let numbers = arguments[2].split(separator: ",").compactMap { Double($0) }
    guard arguments[2] == "-" || (numbers.count == 4 && numbers[2] >= 1 && numbers[3] >= 1) else {
      fail("capture: the rectangle is x,y,w,h or -, not \(arguments[2])")
    }
    capture(
      path: arguments[1],
      part: numbers.count == 4 ? CGRect(x: numbers[0], y: numbers[1], width: numbers[2], height: numbers[3]) : nil,
      pids: Set(arguments.dropFirst(3).compactMap { pid_t($0) }))
  } else if command == "materials", (2...3).contains(arguments.count) {
    showMaterials(seconds: Double(arguments[1]) ?? 3, mode: arguments.count == 3 ? arguments[2] : nil)
  } else {
    fail(
      "usage: scenery landscape <day|night> <width> <height> <file> | curtain <day|night> <seconds> | "
        + "capture <file> <x,y,w,h|-> <pid>… | materials <seconds> [light|dark]")
  }
}
