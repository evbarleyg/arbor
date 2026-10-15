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
//                              and leaves. `cover:<seconds>:clear` has no ground: what happens under it shows
//   move:<window>:<x>:<y>      the window's position through Accessibility, as AXWindowSystem.setFrame does where the size stays: ask the
//                              app for AXEnhancedUserInterface, set AXPosition, read AXPosition and AXSize back
//   main:<window>              AXMain = true
//   raise:<window>             AXRaise
//   activate:<window>          NSRunningApplication.activate() for its app
//   focus:<window>             the three, as AXWindowSystem.focus does: the last only if the app is not in front
//   panel:<x>:<y>:<w>:<h>      a borderless panel of the tool's own is ordered in at the normal level, behind everything of that level, as Arbor's tiles are
//   ring:<window>              a clear borderless panel is ordered in straight above that window, as Arbor's focus ring is
//   hold:<ms>                  asks the window server to hold screen updates (NSDisableScreenUpdates), sleeps for that long and lets go: what a hold that
//                              is KNOWN to be one looks like in a film, in macOS's own pictures and in the system's log, and after how long macOS ends it
//
// It ends 0.3 s after the last step, or after the cover has left. Windows are the window server's numbers. It needs Accessibility, reads no title, and moves
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
guard let logFile = fopen(arguments[0], "a") else { fail("cannot write to \(arguments[0])") }
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

func cover(seconds: Double, clear: Bool, cards: [(from: CGRect, to: CGRect)]) {
  let panel = overlayPanel()
  panel.level = NSWindow.Level(rawValue: NSWindow.Level.floating.rawValue + 1)
  panel.ignoresMouseEvents = true
  panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
  let view = NSView(frame: .zero)
  let root = CALayer()
  view.layer = root
  view.wantsLayer = true
  panel.contentView = view
  let canvas = CALayer()
  root.addSublayer(canvas)
  kept.append(panel)

  CATransaction.begin()
  CATransaction.setDisableActions(true)
  panel.setFrame(display, display: false)
  canvas.frame = CGRect(origin: .zero, size: display.size)
  if !clear {
    let ground = CALayer()
    ground.backgroundColor = NSColor.black.cgColor
    ground.frame = canvas.bounds
    ground.zPosition = -1
    canvas.addSublayer(ground)
  }
  var layers: [CALayer] = []
  for card in cards {
    let layer = CALayer()
    layer.backgroundColor = NSColor.systemGray.cgColor
    layer.cornerRadius = 16
    layer.shadowColor = NSColor.black.cgColor
    layer.shadowOpacity = 0.3
    layer.shadowRadius = 14
    layer.frame = local(card.from)
    canvas.addSublayer(layer)
    layers.append(layer)
  }
  CATransaction.commit()
  panel.orderFrontRegardless()
  CATransaction.flush()
  coverIsUp = true

  CATransaction.begin()
  CATransaction.setDisableActions(false)
  CATransaction.setAnimationDuration(seconds)
  CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(controlPoints: 0.2, 0, 0, 1))
  for (layer, card) in zip(layers, cards) { layer.frame = local(card.to) }
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
      panel.orderOut(nil)
      write("cover down \(Int(now() - began))")
      coverIsUp = false
    }
    RunLoop.main.add(drop, forMode: .common)
  }
  RunLoop.main.add(lift, forMode: .common)
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
  case "panel":
    let numbers = words.dropFirst().compactMap { Double($0) }
    guard numbers.count == 4 else { fail("panel:<x>:<y>:<w>:<h>") }
    let panel = overlayPanel()
    panel.level = .normal
    panel.backgroundColor = NSColor.systemGray.withAlphaComponent(0.5)
    panel.setFrame(appKit(CGRect(x: numbers[0], y: numbers[1], width: numbers[2], height: numbers[3])), display: true)
    panel.order(.below, relativeTo: 0)
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
  case "hold":
    guard words.count == 2, let ms = Double(words[1]) else { fail("hold:<ms>") }
    NSDisableScreenUpdates()
    usleep(useconds_t(ms * 1000))
    NSEnableScreenUpdates()
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
  DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
    write("end")
    exit(0)
  }
}

DispatchQueue.main.async { perform(0) }
application.run()
