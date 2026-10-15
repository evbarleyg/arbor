// mover: does to other apps' windows what Arbor's Accessibility layer and stage do when the view moves, one thing at a time, with no Arbor
// anywhere. The control for whatever is seen on the display while Arbor moves windows: is it Arbor's doing, or macOS's own?
//
//   mover <log file> <pid,pid,…> <step>…
//
// The steps are done in the order given, one straight after the other, on the main thread, as Arbor does them:
//   wait:<ms>                  nothing, for that long
//   go                         writes `M go`: the moment that stands for the key going down
//   cover:<seconds>            a panel over the whole display goes up, as Arbor's stage does (same kind, level and order of calls), with a card for every
//                              window that a later step moves. The cards travel for that long on Arbor's curve; then the cover fades for 0.08 s
//                              and leaves. `cover:<seconds>:clear` has no ground: what happens under it shows. The panel is made, and has been up once
//                              unseen, before the first step: Arbor's is kept from one motion to the next
//   move:<window>:<x>:<y>      the window's position through Accessibility, as AXWindowSystem.setFrame does where the size stays: ask the
//                              app for AXEnhancedUserInterface, set AXPosition, read AXPosition and AXSize back
//   main:<window>              AXMain = true
//   raise:<window>             AXRaise
//   activate:<window>          NSRunningApplication.activate() for its app
//   focus:<window>             the three, as AXWindowSystem.focus does: the last only if the app is not in front
//   tile:<x>:<y>:<w>:<h>:<fade>   a borderless panel of the tool's own is shown call for call as `TilePanel.show` shows a tile of Arbor's: what it draws is marked for drawing, the frame
//                              is set, the shadow asked for and invalidated, the panel ordered in at the normal level behind everything of that level, and it fades
//                              in over <fade> seconds through the window's own alpha (0: at once). It draws what a tile draws: a gradient inside a
//                              rounded outline, a border, an app's icon, a symbol and a word with a soft shadow
//   leave:<fade>               the tiles fade out over that long and are then ordered out, as a tile of Arbor's leaves
//   show:<fade>                the tiles that have left are shown again, by the same calls as the first time: Arbor keeps its panels and hands them out again
//   redraw                     the tiles are marked for drawing and nothing else
//   look:plain                 from here on a tile draws a rounded rectangle and nothing else
//   look:bitmap                from here on a tile draws nothing itself: the same look is drawn into a bitmap in memory, which is handed over as its layer's contents
//   handle:<x>:<y>:<w>:<h>     a clear borderless panel that wants clicks, kept out of view until `handles:in`: a gap handle of Arbor's
//   handles:in | handles:out   the handles are ordered in behind everything of their level | ordered out
//   ground                     a panel over the whole display just above the Desktop's icons, with a dark shape in a layer, is ordered in: what Arbor darkens the
//                              wallpaper with behind docked windows
//   ring:<window>              a clear borderless panel is ordered in straight above that window, and again 0.15 s later, as Arbor's focus ring is
//   observe                    from here on the tool listens, as Arbor does, to AXMoved and AXResized of every window of the processes named and to who has the
//                              keyboard there, and reads position and size of whatever it hears of
//
// It ends 0.5 s after the last step, or after the cover has left. Windows are the window server's numbers. It needs Accessibility, reads no title, and moves
// only the windows it is told to, which belong to the processes it is told. The log is in the grammar of sampler.swift's: `<ms since 1970> M <step> <ms it took>`.

import AppKit
import ApplicationServices
import QuartzCore

func fail(_ message: String) -> Never {
  FileHandle.standardError.write(Data("mover: \(message)\n".utf8))
  exit(64)
}

@_silgen_name("_AXUIElementGetWindow")
func _AXUIElementGetWindow(_ element: AXUIElement, _ identifier: UnsafeMutablePointer<CGWindowID>) -> AXError

var arguments = Array(CommandLine.arguments.dropFirst())
guard arguments.count >= 3 else { fail("usage: mover <log file> <pid,pid,…> <step>…") }
/// Not `guard let`: what that binds at the top of a file is no global, and the functions below could not use it.
let logFile: UnsafeMutablePointer<FILE> = {
  guard let file = fopen(arguments[0], "a") else { fail("cannot write to \(arguments[0])") }
  return file
}()
let pids = arguments[1].split(separator: ",").compactMap { pid_t($0) }
let steps = Array(arguments.dropFirst(2))

func now() -> Double { Date().timeIntervalSince1970 * 1000 }
func write(_ line: String, at time: Double = now()) {
  fputs("\(Int64(time)) M \(line)\n", logFile)
  fflush(logFile)
}

// MARK: Windows

func attribute(_ element: AXUIElement, _ name: String) -> CFTypeRef? {
  var value: CFTypeRef?
  guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else { return nil }
  return value
}

func frame(of element: AXUIElement) -> CGRect {
  var origin = CGPoint.zero
  var size = CGSize.zero
  if let value = attribute(element, kAXPositionAttribute), CFGetTypeID(value) == AXValueGetTypeID() {
    AXValueGetValue(value as! AXValue, .cgPoint, &origin)
  }
  if let value = attribute(element, kAXSizeAttribute), CFGetTypeID(value) == AXValueGetTypeID() {
    AXValueGetValue(value as! AXValue, .cgSize, &size)
  }
  return CGRect(origin: origin, size: size)
}

struct Known {
  let pid: pid_t
  let app: AXUIElement
  let element: AXUIElement
}

// Looked up before anything is timed, as Arbor has them at hand.
var known: [CGWindowID: Known] = [:]
for pid in pids {
  let app = AXUIElementCreateApplication(pid)
  guard let value = attribute(app, kAXWindowsAttribute), CFGetTypeID(value) == CFArrayGetTypeID() else { continue }
  for item in value as? [AnyObject] ?? [] where CFGetTypeID(item) == AXUIElementGetTypeID() {
    let element = item as! AXUIElement
    var id = CGWindowID(0)
    _ = _AXUIElementGetWindow(element, &id)
    known[id] = Known(pid: pid, app: app, element: element)
  }
}

func window(_ word: Substring) -> Known {
  guard let id = CGWindowID(word), let found = known[id] else { fail("no window \(word) among the processes named") }
  return found
}

// MARK: The cover

let application = NSApplication.shared
application.setActivationPolicy(.accessory)
guard let screen = NSScreen.screens.first else { fail("no display") }
let display = screen.frame

/// Global points, y down, into a layer of the cover, y up.
func local(_ rect: CGRect) -> CGRect {
  CGRect(x: rect.minX, y: display.height - rect.maxY, width: rect.width, height: rect.height)
}

func appKit(_ rect: CGRect) -> NSRect {
  NSRect(x: rect.minX, y: display.maxY - rect.maxY, width: rect.width, height: rect.height)
}

/// As Arbor's `OverlayPanel`.
func overlayPanel() -> NSPanel {
  let panel = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
  panel.isOpaque = false
  panel.backgroundColor = .clear
  panel.hasShadow = false
  panel.hidesOnDeactivate = false
  panel.isReleasedWhenClosed = false
  panel.animationBehavior = .none
  panel.collectionBehavior = [.ignoresCycle, .transient]
  return panel
}

var coverIsUp = false
var kept: [NSPanel] = []
var tiles: [NSPanel] = []
var handles: [NSPanel] = []
var observers: [AXObserver] = []

/// The cover's panel and its layers, made once, as Arbor keeps its stage.
let coverPanel = overlayPanel()
let canvas = CALayer()
let ground = CALayer()

/// A picture the size of the display, as the stage has one of the desktop.
func blackPicture() -> CGImage? {
  let context = CGContext(
    data: nil, width: Int(display.width), height: Int(display.height), bitsPerComponent: 8, bytesPerRow: 0,
    space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue)
  context?.setFillColor(CGColor(gray: 0, alpha: 1))
  context?.fill(CGRect(origin: .zero, size: display.size))
  return context?.makeImage()
}

func makeCover() {
  coverPanel.level = NSWindow.Level(rawValue: NSWindow.Level.floating.rawValue + 1)
  coverPanel.ignoresMouseEvents = true
  coverPanel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
  let view = NSView(frame: .zero)
  let root = CALayer()
  view.layer = root
  view.wantsLayer = true
  coverPanel.contentView = view
  root.addSublayer(canvas)
  ground.contentsGravity = .resizeAspectFill
  ground.zPosition = -1
  canvas.addSublayer(ground)
  // Up and down again with nothing to be seen, as `Stage.rehearse` does.
  coverPanel.alphaValue = 0
  CATransaction.begin()
  CATransaction.setDisableActions(true)
  coverPanel.setFrame(display, display: false)
  canvas.frame = CGRect(origin: .zero, size: display.size)
  ground.frame = canvas.bounds
  ground.contents = blackPicture()
  CATransaction.commit()
  coverPanel.orderFrontRegardless()
  CATransaction.flush()
  coverPanel.orderOut(nil)
  coverPanel.alphaValue = 1
}

func cover(seconds: Double, clear: Bool, cards: [(from: CGRect, to: CGRect)]) {
  let timing = CAMediaTimingFunction(controlPoints: 0.2, 0, 0, 1)
  CATransaction.begin()
  CATransaction.setDisableActions(true)
  coverPanel.setFrame(display, display: false)
  canvas.opacity = 1
  ground.isHidden = clear
  var layers: [CALayer] = []
  for card in cards {
    let layer = CALayer()
    layer.backgroundColor = NSColor.systemGray.cgColor
    layer.cornerRadius = 16
    layer.shadowColor = NSColor.black.cgColor
    layer.shadowOpacity = 0.3
    layer.shadowRadius = 14
    layer.shadowOffset = CGSize(width: 0, height: -6)
    layer.frame = local(card.from)
    layer.shadowPath = CGPath(rect: layer.bounds, transform: nil)
    canvas.addSublayer(layer)
    layers.append(layer)
  }
  CATransaction.commit()
  coverPanel.orderFrontRegardless()
  CATransaction.flush()
  coverIsUp = true

  CATransaction.begin()
  CATransaction.setDisableActions(false)
  CATransaction.setAnimationDuration(seconds)
  CATransaction.setAnimationTimingFunction(timing)
  for (layer, card) in zip(layers, cards) {
    let shadow = CABasicAnimation(keyPath: "shadowPath")
    shadow.fromValue = layer.shadowPath
    layer.frame = local(card.to)
    layer.shadowPath = CGPath(rect: layer.bounds, transform: nil)
    shadow.toValue = layer.shadowPath
    shadow.duration = seconds
    shadow.timingFunction = timing
    layer.add(shadow, forKey: "shadowPath")
  }
  CATransaction.commit()
  CATransaction.flush()

  let lift = Timer(timeInterval: seconds, repeats: false) { _ in
    write("cover lifts")
    CATransaction.begin()
    CATransaction.setAnimationDuration(0.08)
    canvas.opacity = 0
    CATransaction.commit()
    let drop = Timer(timeInterval: 0.08, repeats: false) { _ in
      let began = now()
      coverPanel.orderOut(nil)
      write("cover down \(Int(now() - began))")
      coverIsUp = false
    }
    RunLoop.main.add(drop, forMode: .common)
  }
  RunLoop.main.add(lift, forMode: .common)
}

var looksPlain = false
var looksBitmap = false

/// What a tile of Arbor's draws, in kind (Sources/ArborKit/UI/TileDrawing.swift).
final class TileLook: NSView {
  override var isFlipped: Bool { true }

  override var wantsUpdateLayer: Bool { looksBitmap }

  /// In place of `draw(_:)`: Core Animation is given a finished picture and has nothing to draw.
  override func updateLayer() {
    let scale = window?.backingScaleFactor ?? 1
    guard bounds.width >= 1, bounds.height >= 1,
      let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: Int(bounds.width * scale), pixelsHigh: Int(bounds.height * scale), bitsPerSample: 8, samplesPerPixel: 4,
        hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0),
      let context = NSGraphicsContext(bitmapImageRep: bitmap)
    else { return }
    bitmap.size = bounds.size
    NSGraphicsContext.saveGraphicsState()
    // Flipped, as the view is.
    NSGraphicsContext.current = NSGraphicsContext(cgContext: context.cgContext, flipped: true)
    context.cgContext.translateBy(x: 0, y: bounds.height)
    context.cgContext.scaleBy(x: 1, y: -1)
    paint()
    NSGraphicsContext.restoreGraphicsState()
    layer?.contents = bitmap.cgImage
  }

  override func draw(_ dirtyRect: NSRect) { paint() }

  func paint() {
    let outline = NSBezierPath(roundedRect: bounds.insetBy(dx: 1, dy: 1), xRadius: 16, yRadius: 16)
    guard !looksPlain else {
      NSColor.systemGray.withAlphaComponent(0.6).setFill()
      return outline.fill()
    }
    NSGraphicsContext.saveGraphicsState()
    outline.addClip()
    NSGradient(starting: .systemGray, ending: .darkGray)?.draw(
      from: NSPoint(x: bounds.midX, y: bounds.minY), to: NSPoint(x: bounds.midX, y: bounds.maxY), options: [])
    NSGraphicsContext.restoreGraphicsState()
    outline.lineWidth = 1
    NSColor.white.withAlphaComponent(0.25).setStroke()
    outline.stroke()

    let side = min(bounds.width, bounds.height) * 0.4
    NSGraphicsContext.current?.imageInterpolation = .high
    NSRunningApplication.current.icon?.draw(
      in: NSRect(x: bounds.midX - side / 2, y: bounds.midY - side / 2, width: side, height: side), from: .zero, operation: .sourceOver,
      fraction: 1, respectFlipped: true, hints: nil)

    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.5)
    shadow.shadowBlurRadius = 2
    shadow.shadowOffset = NSSize(width: 0, height: -1)
    let configuration = NSImage.SymbolConfiguration(pointSize: 24, weight: .medium)
      .applying(NSImage.SymbolConfiguration(paletteColors: [.white]))
    if let symbol = NSImage(systemSymbolName: "menubar.dock.rectangle", accessibilityDescription: nil)?.withSymbolConfiguration(configuration) {
      NSGraphicsContext.saveGraphicsState()
      shadow.set()
      symbol.draw(
        in: NSRect(x: bounds.midX - 16, y: 24, width: 32, height: 24), from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true,
        hints: nil)
      NSGraphicsContext.restoreGraphicsState()
    }
    ("Tile" as NSString).draw(
      in: NSRect(x: 12, y: bounds.maxY - 40, width: bounds.width - 24, height: 20),
      withAttributes: [.font: NSFont.systemFont(ofSize: 13, weight: .medium), .foregroundColor: NSColor.white, .shadow: shadow])
  }
}

/// `TilePanel.show`, call for call.
func showTile(_ panel: NSPanel, at frame: NSRect, fade: Double) {
  let isSameTile = panel.isVisible
  panel.ignoresMouseEvents = false
  panel.contentView?.needsDisplay = true
  panel.setFrame(frame, display: true)
  panel.hasShadow = true
  panel.invalidateShadow()
  guard !isSameTile, fade > 0 else {
    setAlphaAtOnce(panel, 1)
    panel.order(.below, relativeTo: 0)
    return
  }
  setAlphaAtOnce(panel, 0)
  panel.order(.below, relativeTo: 0)
  NSAnimationContext.runAnimationGroup { context in
    context.duration = fade
    panel.animator().alphaValue = 1
  }
}

func setAlphaAtOnce(_ panel: NSPanel, _ alpha: CGFloat) {
  NSAnimationContext.runAnimationGroup { context in
    context.duration = 0
    panel.animator().alphaValue = alpha
  }
}

// MARK: The steps

func perform(_ index: Int) {
  guard index < steps.count else {
    finish()
    return
  }
  let words = steps[index].split(separator: ":")
  let began = now()
  switch words.first.map(String.init) {
  case "wait":
    guard words.count == 2, let ms = Double(words[1]) else { fail("wait:<ms>") }
    DispatchQueue.main.asyncAfter(deadline: .now() + ms / 1000) { perform(index + 1) }
    return
  case "go":
    break
  case "cover":
    guard words.count >= 2, let seconds = Double(words[1]) else { fail("cover:<seconds>[:clear]") }
    var cards: [(from: CGRect, to: CGRect)] = []
    for later in steps[(index + 1)...] {
      let parts = later.split(separator: ":")
      guard parts.first == "move", parts.count == 4, let x = Double(parts[2]), let y = Double(parts[3]) else { continue }
      let from = frame(of: window(parts[1]).element)
      cards.append((from, CGRect(origin: CGPoint(x: x, y: y), size: from.size)))
    }
    cover(seconds: seconds, clear: words.count > 2, cards: cards)
  case "move":
    guard words.count == 4, let x = Double(words[2]), let y = Double(words[3]) else { fail("move:<window>:<x>:<y>") }
    let target = window(words[1])
    _ = attribute(target.app, "AXEnhancedUserInterface")
    var origin = CGPoint(x: x, y: y)
    if let value = AXValueCreate(.cgPoint, &origin) {
      _ = AXUIElementSetAttributeValue(target.element, kAXPositionAttribute as CFString, value)
    }
    _ = frame(of: target.element)
  case "main":
    guard words.count == 2 else { fail("main:<window>") }
    _ = AXUIElementSetAttributeValue(window(words[1]).element, kAXMainAttribute as CFString, kCFBooleanTrue)
  case "raise":
    guard words.count == 2 else { fail("raise:<window>") }
    _ = AXUIElementPerformAction(window(words[1]).element, kAXRaiseAction as CFString)
  case "activate":
    guard words.count == 2 else { fail("activate:<window>") }
    _ = NSRunningApplication(processIdentifier: window(words[1]).pid)?.activate()
  case "focus":
    guard words.count == 2 else { fail("focus:<window>") }
    let target = window(words[1])
    _ = AXUIElementSetAttributeValue(target.element, kAXMainAttribute as CFString, kCFBooleanTrue)
    _ = AXUIElementPerformAction(target.element, kAXRaiseAction as CFString)
    if NSWorkspace.shared.frontmostApplication?.processIdentifier != target.pid {
      _ = NSRunningApplication(processIdentifier: target.pid)?.activate()
    }
  case "tile":
    let numbers = words.dropFirst().compactMap { Double($0) }
    guard numbers.count == 5 else { fail("tile:<x>:<y>:<w>:<h>:<fade>") }
    let panel = overlayPanel()
    panel.level = .normal
    let look = TileLook()
    // Otherwise as AppKit sees fit, which is how a tile of Arbor's has its layer.
    if looksBitmap { look.wantsLayer = true }
    panel.contentView = look
    tiles.append(panel)
    showTile(panel, at: appKit(CGRect(x: numbers[0], y: numbers[1], width: numbers[2], height: numbers[3])), fade: numbers[4])
  case "show":
    guard words.count == 2, let fade = Double(words[1]) else { fail("show:<fade>") }
    for panel in tiles { showTile(panel, at: panel.frame, fade: fade) }
  case "look":
    looksPlain = words.count == 2 && words[1] == "plain"
    looksBitmap = words.count == 2 && words[1] == "bitmap"
  case "leave":
    guard words.count == 2, let fade = Double(words[1]) else { fail("leave:<fade>") }
    for panel in tiles {
      panel.ignoresMouseEvents = true
      guard fade > 0 else {
        setAlphaAtOnce(panel, 1)
        panel.orderOut(nil)
        continue
      }
      NSAnimationContext.runAnimationGroup(
        { context in
          context.duration = fade
          panel.animator().alphaValue = 0
        },
        completionHandler: {
          let began = now()
          panel.orderOut(nil)
          write("tile out \(Int(now() - began))", at: began)
        })
    }
  case "handle":
    let numbers = words.dropFirst().compactMap { Double($0) }
    guard numbers.count == 4 else { fail("handle:<x>:<y>:<w>:<h>") }
    let panel = overlayPanel()
    panel.level = .normal
    panel.ignoresMouseEvents = false
    panel.contentView = NSView()
    panel.setFrame(appKit(CGRect(x: numbers[0], y: numbers[1], width: numbers[2], height: numbers[3])), display: false)
    handles.append(panel)
  case "handles":
    guard words.count == 2 else { fail("handles:in | handles:out") }
    for panel in handles {
      if words[1] == "in" { panel.order(.below, relativeTo: 0) } else { panel.orderOut(nil) }
    }
  case "ground":
    let panel = overlayPanel()
    panel.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)) + 1)
    panel.ignoresMouseEvents = true
    panel.collectionBehavior = [.transient, .ignoresCycle, .canJoinAllSpaces]
    let view = NSView()
    view.layer = CALayer()
    view.wantsLayer = true
    let shape = CAShapeLayer()
    shape.frame = CGRect(origin: .zero, size: display.size)
    shape.path = CGPath(roundedRect: shape.frame.insetBy(dx: 6, dy: 40), cornerWidth: 16, cornerHeight: 16, transform: nil)
    shape.fillColor = CGColor(gray: 0, alpha: 0.25)
    view.layer?.addSublayer(shape)
    panel.contentView = view
    panel.setFrame(display, display: false)
    panel.orderFrontRegardless()
    kept.append(panel)
  case "ring":
    guard words.count == 2, let id = Int(words[1]) else { fail("ring:<window>") }
    let panel = overlayPanel()
    panel.level = .normal
    panel.ignoresMouseEvents = true
    panel.collectionBehavior = [.canJoinAllSpaces, .transient, .ignoresCycle]
    panel.setFrame(appKit(frame(of: window(words[1]).element).insetBy(dx: -6, dy: -6)), display: false)
    panel.order(.above, relativeTo: id)
    kept.append(panel)
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { panel.order(.above, relativeTo: id) }
  case "observe":
    for pid in pids {
      var made: AXObserver?
      let heard: AXObserverCallback = { _, element, _, _ in _ = frame(of: element) }
      guard AXObserverCreate(pid, heard, &made) == .success, let observer = made else { continue }
      for one in known.values where one.pid == pid {
        AXObserverAddNotification(observer, one.element, kAXMovedNotification as CFString, nil)
        AXObserverAddNotification(observer, one.element, kAXResizedNotification as CFString, nil)
      }
      for name in [
        kAXFocusedWindowChangedNotification, kAXMainWindowChangedNotification, kAXApplicationActivatedNotification,
        kAXApplicationDeactivatedNotification,
      ] {
        AXObserverAddNotification(observer, AXUIElementCreateApplication(pid), name as CFString, nil)
      }
      CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .commonModes)
      observers.append(observer)
    }
  case "redraw":
    for panel in tiles { panel.contentView?.needsDisplay = true }
  default:
    fail("no such step: \(steps[index])")
  }
  write("\(steps[index]) \(Int(now() - began))", at: began)
  perform(index + 1)
}

func finish() {
  guard !coverIsUp else {
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { finish() }
    return
  }
  DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
    write("end")
    exit(0)
  }
}

DispatchQueue.main.async {
  if steps.contains(where: { $0.hasPrefix("cover") }) { makeCover() }
  perform(0)
}
application.run()
