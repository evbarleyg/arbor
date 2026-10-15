// pointer: real pointer and key events, and a few facts about the screen, for Mac shell scripts.
//
// Arbor's drags, double-clicks, seams, menus and shortcuts react to what the window server delivers,
// which no command over the control socket can stand in for. This tool posts events where a mouse and
// a keyboard do (the HID event tap), so everything downstream sees them as it would a person's: the
// window server's own window dragging, AppKit, Arbor's event monitors and taps, Carbon hot keys.
//
// scripts/mac-shell/lib.sh compiles it on the Mac (swiftc -O -swift-version 5) and wraps it as `drag`,
// `click`, `dblclick`, `key` and so on. Posting needs Accessibility permission, as Arbor does.
// Coordinates are global points, origin top-left, y down: the space `arborctl state` reports.

import AppKit
import ApplicationServices
import CoreGraphics
import Foundation
import ImageIO

/// Private, stable for over a decade, and what Arbor itself uses: the window server's number for an
/// Accessibility window. Two parked windows have the same frame, so nothing else tells them apart.
@_silgen_name("_AXUIElementGetWindow")
func _AXUIElementGetWindow(_ element: AXUIElement, _ identifier: UnsafeMutablePointer<CGWindowID>) -> AXError

func fail(_ message: String) -> Never {
  FileHandle.standardError.write(Data("pointer: \(message)\n".utf8))
  exit(64)
}

func rest(_ seconds: Double) {
  if seconds > 0 { Thread.sleep(forTimeInterval: seconds) }
}

/// `12` for 12.0 and `12.5` for 12.5, so that shell arithmetic can use whole numbers as they are.
func text(_ value: CGFloat) -> String {
  let number = Double(value)
  return number == number.rounded() ? String(Int(number)) : String(format: "%.1f", number)
}

func text(_ rect: CGRect) -> String {
  "\(text(rect.minX)) \(text(rect.minY)) \(text(rect.width)) \(text(rect.height))"
}

@MainActor
func showOnEveryDesktop(_ picture: URL?) throws {
  for screen in NSScreen.screens {
    if let picture { try NSWorkspace.shared.setDesktopImageURL(picture, for: screen, options: [:]) }
    print(NSWorkspace.shared.desktopImageURL(for: screen)?.path ?? "-")
  }
}

struct Modifier {
  let names: [String]
  let flag: CGEventFlags
  let code: CGKeyCode
}

struct Pointer {
  static let usage = """
    usage: pointer <command>
      move x y                      glide the pointer there
      click x y [count] [--right]   click (count 2 is a double-click), with the right button if asked
          [--quick]                 the button comes up at once, as with tap to click (otherwise after 0.04 s)
      drag x1 y1 x2 y2              press at the first point, drag to the second, release
          [--steps n]               intermediate events (default 30)
          [--duration s]            how long the movement takes (default 0.6)
          [--hold s]                wait at the end before releasing (default 0.2)
          [--no-release]            leave the button down; finish with `release`
          [--no-settle]             without the small movement at the end that lets Arbor catch up
      drag-on x y                   with the button down since a `drag --no-release`: carry on to that point and rest there
          [--steps n] [--duration s] [--hold s]      as for drag
      release [x y]                 release the button there (default: where the pointer is)
      key <chord>                   press a shortcut, e.g. ctrl+opt+space, cmd+shift+f5, escape
          [--down]                  press the modifiers and the key, and leave them all down
          [--up]                    release the key, then the modifiers (modifiers alone, or a key alone, work too)
          [--held]                  press and release the key only: its modifiers are down already, and stay down
          [--repeat n]              n more key-down events marked as auto-repeat, as a key that is held sends
      calm                          let go of every mouse button and key that is down, and say which, if any: for the end of a run
      pinch x y <amount>            spread two fingers there (negative: pinch them together) by that much
          [--steps n]               magnification, in that many events (default 10)
      where                         the pointer's position and whether the left button is down
      activity                      seconds since the pointer was used, seconds since a key was released, and the count
                                    of key presses, as Arbor reads them (AXWindowSystem+Input.swift)
      displays                      id x y w h pixel-width pixel-height scale, one line per display
      windows [--pid n]             id pid layer x y w h on|off owner, as the window server sees them
          [--on-screen]             only those on screen, from the frontmost to the one at the back
      frame <window id>             x y w h, as the window server sees it
      visible <window id>           the share of the window that is on some display, 0 to 1; 0 when the window
                                    server does not show it (minimized, hidden, on another Space)
      grab <window id>              x y: a point on its title bar that no other window covers
      spot <window id>              x y: a point on its content that no other window covers
      button <window id> <which>    x y: the middle of its close, minimize or zoom button
      ax <window id>                its Accessibility role and subrole, e.g. AXWindow AXStandardWindow
      front                         the process id of the app in front, which has the keyboard
      status-item <pid> [--frame]   x y: the middle of that process's menu bar item (--frame: x y w h)
      menu-item <pid> <title>       x y: the middle of the item of its open menu whose title starts so
      menu-mark <pid> <title>       that item's mark, e.g. ✓, or - when it has none
      button <pid> x y <name>       x y: the middle of the close, minimize or zoom button of that process's
                                    window whose top-left corner is nearest the point
      screen-access | ax-access     true or false: Screen Recording, Accessibility
      reduce-motion                 true or false: what an app launched now is told about Reduce Motion
      asleep                        true or false: whether the main display is asleep
      picture <file> <w> <h> <#rrggbb> [<#rrggbb>]
                                    write a PNG: one colour, or a gradient between two under a grid
      wallpaper [file]              show that picture on the desktop of every display; print what each shows
    click, drag, release and pinch take --mods <chord of modifiers>, e.g. --mods shift+cmd, held meanwhile.
    Every command that posts events takes --tap session, to post them after the window server's own handling.
    """

  static let modifiers: [Modifier] = [
    Modifier(names: ["ctrl", "control", "⌃"], flag: .maskControl, code: 59),
    Modifier(names: ["opt", "option", "alt", "⌥"], flag: .maskAlternate, code: 58),
    Modifier(names: ["shift", "⇧"], flag: .maskShift, code: 56),
    Modifier(names: ["cmd", "command", "⌘"], flag: .maskCommand, code: 55),
    Modifier(names: ["fn", "globe"], flag: .maskSecondaryFn, code: 63),
  ]

  /// Virtual key codes under the names settings.json uses (`KeyChord.Key` in ArborCore).
  static let keys: [String: CGKeyCode] = [
    "a": 0, "b": 11, "c": 8, "d": 2, "e": 14, "f": 3, "g": 5, "h": 4, "i": 34, "j": 38, "k": 40, "l": 37,
    "m": 46, "n": 45, "o": 31, "p": 35, "q": 12, "r": 15, "s": 1, "t": 17, "u": 32, "v": 9, "w": 13,
    "x": 7, "y": 16, "z": 6,
    "0": 29, "1": 18, "2": 19, "3": 20, "4": 21, "5": 23, "6": 22, "7": 26, "8": 28, "9": 25,
    "space": 49, "return": 36, "enter": 36, "tab": 48, "escape": 53, "esc": 53, "delete": 51,
    "left": 123, "right": 124, "down": 125, "up": 126,
    "[": 33, "]": 30, "-": 27, "=": 24, ",": 43, ".": 47, "/": 44, ";": 41, "'": 39, "`": 50, "\\": 42,
    "f1": 122, "f2": 120, "f3": 99, "f4": 118, "f5": 96, "f6": 97, "f7": 98, "f8": 100, "f9": 101,
    "f10": 109, "f11": 103, "f12": 111,
  ]

  /// What a keyboard adds to these keys' events. The window server compares it too when it looks for a
  /// shortcut: without it ⌃⌥⌘← reaches the frontmost app as a key press and no hot key fires.
  static func intrinsicFlags(of code: CGKeyCode) -> CGEventFlags {
    switch code {
    case 123...126: return [.maskNumericPad, .maskSecondaryFn]  // the arrows
    case 96...101, 103, 109, 111, 118, 120, 122: return .maskSecondaryFn  // f1 to f12
    default: return []
    }
  }

  var arguments: [String]
  let source = CGEventSource(stateID: .hidSystemState)
  /// The modifiers held now; every event carries them.
  var flags: CGEventFlags = []
  var tap = CGEventTapLocation.cghidEventTap

  // MARK: Arguments

  /// Takes `--name value` out of the arguments.
  mutating func option(_ name: String) -> String? {
    guard let index = arguments.firstIndex(of: name) else { return nil }
    guard index + 1 < arguments.count else { fail("\(name) needs a value") }
    let value = arguments[index + 1]
    arguments.removeSubrange(index...(index + 1))
    return value
  }

  mutating func flag(_ name: String) -> Bool {
    guard let index = arguments.firstIndex(of: name) else { return false }
    arguments.remove(at: index)
    return true
  }

  func number(_ word: String) -> Double {
    guard let value = Double(word), value.isFinite, abs(value) < 1_000_000 else {
      fail("expected a number, got \(word)")
    }
    return value
  }

  func point(at index: Int) -> CGPoint {
    guard arguments.count > index + 1 else { fail("expected x and y\n\(Pointer.usage)") }
    return CGPoint(x: number(arguments[index]), y: number(arguments[index + 1]))
  }

  func windowID(at index: Int) -> UInt32 {
    guard arguments.count > index, let id = UInt32(arguments[index]) else { fail("expected a window id") }
    return id
  }

  /// Splits `ctrl+opt+space` into its modifiers and its key, if it has one.
  func parse(chord: String) -> (modifiers: [Modifier], key: CGKeyCode?) {
    var found: [Modifier] = []
    var key: CGKeyCode?
    for part in chord.lowercased().split(separator: "+").map(String.init) {
      if let modifier = Pointer.modifiers.first(where: { $0.names.contains(part) }) {
        found.append(modifier)
      } else if let code = Pointer.keys[part], key == nil {
        key = code
      } else {
        fail("cannot read `\(part)` in the shortcut \(chord)")
      }
    }
    return (found, key)
  }

  // MARK: Events

  var location: CGPoint { CGEvent(source: nil)?.location ?? .zero }

  func mouse(
    _ type: CGEventType, at point: CGPoint, clicks: Int64, from previous: CGPoint? = nil, button: CGMouseButton = .left
  ) {
    guard
      let event = CGEvent(mouseEventSource: source, mouseType: type, mouseCursorPosition: point, mouseButton: button)
    else { fail("could not create a mouse event") }
    event.setIntegerValueField(.mouseEventClickState, value: clicks)
    if let previous {
      event.setIntegerValueField(.mouseEventDeltaX, value: Int64((point.x - previous.x).rounded()))
      event.setIntegerValueField(.mouseEventDeltaY, value: Int64((point.y - previous.y).rounded()))
    }
    if !flags.isEmpty { event.flags = flags }
    event.post(tap: tap)
  }

  func keyboard(_ code: CGKeyCode, down: Bool, autorepeat: Bool = false) {
    guard let event = CGEvent(keyboardEventSource: source, virtualKey: code, keyDown: down) else {
      fail("could not create a key event")
    }
    if autorepeat { event.setIntegerValueField(.keyboardEventAutorepeat, value: 1) }
    event.flags = flags.union(Pointer.intrinsicFlags(of: code))
    event.post(tap: tap)
    rest(0.02)
  }

  mutating func hold(_ modifiers: [Modifier]) {
    for modifier in modifiers {
      flags.insert(modifier.flag)
      keyboard(modifier.code, down: true)
    }
  }

  mutating func letGo(_ modifiers: [Modifier]) {
    for modifier in modifiers.reversed() {
      flags.remove(modifier.flag)
      keyboard(modifier.code, down: false)
    }
  }

  /// Moves in a straight line, one event per step, as a hand would: nothing that follows the pointer
  /// (tracking areas, window dragging, drop targets) copes with a single jump.
  func glide(_ type: CGEventType, from start: CGPoint, to end: CGPoint, steps: Int, duration: Double) {
    let count = max(steps, 1)
    var previous = start
    for step in 1...count {
      let share = CGFloat(step) / CGFloat(count)
      let next = CGPoint(x: start.x + (end.x - start.x) * share, y: start.y + (end.y - start.y) * share)
      mouse(type, at: next, clicks: type == .mouseMoved ? 0 : 1, from: previous)
      previous = next
      rest(duration / Double(count))
    }
  }

  func move(to point: CGPoint) {
    glide(.mouseMoved, from: location, to: point, steps: 12, duration: 0.12)
    rest(0.05)
  }

  /// A last small movement at the end of a drag. Arbor learns that a window is being dragged from an
  /// Accessibility notification, which can arrive after the pointer has stopped; only an event after
  /// that tells it where the pointer is.
  func settle(at point: CGPoint) {
    let aside = CGPoint(x: point.x + 1, y: point.y)
    rest(0.15)
    mouse(.leftMouseDragged, at: aside, clicks: 1, from: point)
    rest(0.05)
    mouse(.leftMouseDragged, at: point, clicks: 1, from: aside)
    rest(0.05)
  }

  /// One event of a trackpad's magnify gesture. Nothing public makes gesture events: the fields are the ones the
  /// window server fills in for a real trackpad, as open-source tools that turn mouse buttons into gestures have
  /// worked out, and set and posted exactly as a probe on GitHub's Macs found to arrive (October 2026): field 55
  /// is the event's type (29, what NSEvent calls `.gesture`), 110 the kind of gesture (8: magnification), 113 the
  /// amount, 132 the phase (IOKit's: 1 began, 2 changed, 4 ended); posted after the window server's own handling.
  func magnify(phase: Double, by magnification: Double, at point: CGPoint) {
    func field(_ number: UInt32) -> CGEventField {
      CGEventField(rawValue: number) ?? unsafeBitCast(number, to: CGEventField.self)
    }
    guard let event = CGEvent(source: nil) else { fail("could not create a gesture event") }
    event.setDoubleValueField(field(55), value: 29)
    event.setDoubleValueField(field(110), value: 8)
    event.setDoubleValueField(field(132), value: phase)
    event.setDoubleValueField(field(113), value: magnification)
    event.location = point
    event.flags = flags
    event.post(tap: .cgSessionEventTap)
    rest(0.01)
  }

  // MARK: The window server's view

  func displays() -> [CGDirectDisplayID] {
    var count: UInt32 = 0
    CGGetActiveDisplayList(0, nil, &count)
    var ids = [CGDirectDisplayID](repeating: 0, count: Int(count))
    CGGetActiveDisplayList(count, &ids, &count)
    return ids
  }

  func windows(onScreenOnly: Bool = false) -> [[String: Any]] {
    let options: CGWindowListOption = onScreenOnly ? [.optionOnScreenOnly] : [.optionAll]
    return (CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]]) ?? []
  }

  func bounds(_ info: [String: Any]) -> CGRect? {
    guard let dictionary = info[kCGWindowBounds as String] as? NSDictionary else { return nil }
    return CGRect(dictionaryRepresentation: dictionary as CFDictionary)
  }

  func frame(of id: UInt32) -> CGRect {
    for info in windows() where (info[kCGWindowNumber as String] as? NSNumber)?.uint32Value == id {
      if let rect = bounds(info) { return rect }
    }
    fail("the window server has no window \(id)")
  }

  // MARK: Pictures

  func colour(_ word: String) -> CGColor {
    let digits = word.hasPrefix("#") ? String(word.dropFirst()) : word
    guard digits.count == 6, let value = UInt32(digits, radix: 16) else {
      fail("expected a colour like #336699, got \(word)")
    }
    func part(_ shift: UInt32) -> CGFloat { CGFloat((value >> shift) & 255) / 255 }
    return CGColor(red: part(16), green: part(8), blue: part(0), alpha: 1)
  }

  func writePicture(to path: String, width: Int, height: Int, colours: [CGColor]) {
    let space = CGColorSpaceCreateDeviceRGB()
    guard
      let context = CGContext(
        data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0, space: space,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
    else { fail("could not make a picture of \(width) by \(height)") }
    context.setFillColor(colours[0])
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    if colours.count > 1, let gradient = CGGradient(colorsSpace: space, colors: colours as CFArray, locations: nil) {
      context.drawLinearGradient(
        gradient, start: CGPoint(x: 0, y: height), end: CGPoint(x: width, y: 0), options: [])
      // A grid, so that a copy of the picture that is out of place or out of scale gives itself away.
      context.setStrokeColor(CGColor(gray: 1, alpha: 0.3))
      context.setLineWidth(1)
      for x in stride(from: 0, through: width, by: 100) {
        context.move(to: CGPoint(x: x, y: 0))
        context.addLine(to: CGPoint(x: x, y: height))
      }
      for y in stride(from: 0, through: height, by: 100) {
        context.move(to: CGPoint(x: 0, y: y))
        context.addLine(to: CGPoint(x: width, y: y))
      }
      context.strokePath()
    }
    guard let image = context.makeImage(),
      let destination = CGImageDestinationCreateWithURL(
        URL(fileURLWithPath: path) as CFURL, "public.png" as CFString, 1, nil)
    else { fail("could not write \(path)") }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else { fail("could not write \(path)") }
  }

  func isOnScreen(_ id: UInt32) -> Bool {
    for info in windows() where (info[kCGWindowNumber as String] as? NSNumber)?.uint32Value == id {
      return (info[kCGWindowIsOnscreen as String] as? NSNumber)?.boolValue ?? false
    }
    return false
  }

  func owner(of id: UInt32) -> pid_t? {
    for info in windows() where (info[kCGWindowNumber as String] as? NSNumber)?.uint32Value == id {
      return (info[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value
    }
    return nil
  }

  /// The point of `area` nearest its middle that is on a display and that no ordinary window in front of
  /// window `id` covers. The list of windows on screen comes front to back. Other layers hold the menu
  /// bar, the Dock's screen-sized window and Arbor's previews, none of which takes a click meant for a window.
  /// Nor does Arbor's focus ring, a panel at the ordinary level that lies around the whole window and lets clicks through.
  func freePoint(of id: UInt32, in area: (CGRect) -> CGRect) -> CGPoint? {
    let list = (CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]]) ?? []
    var covers: [(frame: CGRect, isArbors: Bool)] = []
    var own: CGRect?
    for info in list {
      guard let number = (info[kCGWindowNumber as String] as? NSNumber)?.uint32Value, let rect = bounds(info) else {
        continue
      }
      if number == id {
        own = rect
        break
      }
      if (info[kCGWindowLayer as String] as? NSNumber)?.intValue == 0 {
        covers.append((rect.insetBy(dx: -3, dy: -3), info[kCGWindowOwnerName as String] as? String == "Arbor"))
      }
    }
    guard let own else { return nil }
    covers.removeAll { $0.isArbors && $0.frame.contains(own) }
    let wanted = area(own)
    guard wanted.width >= 1, wanted.height >= 1 else { return nil }
    let screens = displays().map { CGDisplayBounds($0).insetBy(dx: 2, dy: 2) }
    var best: CGPoint?
    var bestDistance = CGFloat.infinity
    for x in stride(from: wanted.minX, through: wanted.maxX, by: 6) {
      for y in stride(from: wanted.minY, through: wanted.maxY, by: 6) {
        let point = CGPoint(x: x.rounded(), y: y.rounded())
        let distance = abs(point.x - wanted.midX) + abs(point.y - wanted.midY)
        guard distance < bestDistance, screens.contains(where: { $0.contains(point) }),
          !covers.contains(where: { $0.frame.contains(point) })
        else { continue }
        best = point
        bestDistance = distance
      }
    }
    return best
  }

  // MARK: Accessibility's view

  func attribute(_ element: AXUIElement, _ name: String) -> CFTypeRef? {
    var value: CFTypeRef?
    guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else { return nil }
    return value
  }

  func elements(_ element: AXUIElement, _ name: String) -> [AXUIElement] {
    ((attribute(element, name) as? [AnyObject]) ?? []).compactMap { item in
      CFGetTypeID(item) == AXUIElementGetTypeID() ? (item as! AXUIElement) : nil
    }
  }

  func frame(of element: AXUIElement) -> CGRect? {
    var origin = CGPoint.zero
    var size = CGSize.zero
    guard let position = attribute(element, kAXPositionAttribute), CFGetTypeID(position) == AXValueGetTypeID(),
      AXValueGetValue(position as! AXValue, .cgPoint, &origin),
      let extent = attribute(element, kAXSizeAttribute), CFGetTypeID(extent) == AXValueGetTypeID(),
      AXValueGetValue(extent as! AXValue, .cgSize, &size)
    else { return nil }
    return CGRect(origin: origin, size: size)
  }

  /// The window as its app's accessibility tree lists it, which is how Arbor sees it.
  func accessibilityWindow(_ id: UInt32) -> AXUIElement? {
    guard let pid = owner(of: id) else { return nil }
    for element in elements(AXUIElementCreateApplication(pid), kAXWindowsAttribute) {
      var number = CGWindowID(0)
      if _AXUIElementGetWindow(element, &number) == .success, number == id { return element }
    }
    return nil
  }

  /// The first element below `element`, in the order the tree lists them, whose title starts with `prefix`.
  func descendant(of element: AXUIElement, titled prefix: String, depth: Int) -> AXUIElement? {
    guard depth > 0 else { return nil }
    for child in elements(element, kAXChildrenAttribute) {
      if let title = attribute(child, kAXTitleAttribute) as? String, title.hasPrefix(prefix) { return child }
      if let found = descendant(of: child, titled: prefix, depth: depth - 1) { return found }
    }
    return nil
  }

  /// Since macOS 26 the menu bar draws every app's item in windows of Control Center's, so the window list
  /// no longer says whose an item is. The app's own accessibility tree still does.
  func statusItemFrame(pid: pid_t) -> CGRect? {
    let application = AXUIElementCreateApplication(pid)
    guard let bar = attribute(application, "AXExtrasMenuBar"), CFGetTypeID(bar) == AXUIElementGetTypeID(),
      let children = attribute(bar as! AXUIElement, kAXChildrenAttribute) as? [AnyObject],
      let first = children.first, CFGetTypeID(first) == AXUIElementGetTypeID()
    else { return nil }
    let item = first as! AXUIElement
    var origin = CGPoint.zero
    var size = CGSize.zero
    guard let position = attribute(item, kAXPositionAttribute), CFGetTypeID(position) == AXValueGetTypeID(),
      AXValueGetValue(position as! AXValue, .cgPoint, &origin),
      let extent = attribute(item, kAXSizeAttribute), CFGetTypeID(extent) == AXValueGetTypeID(),
      AXValueGetValue(extent as! AXValue, .cgSize, &size)
    else { return nil }
    return CGRect(origin: origin, size: size)
  }

  func frame(ofElement element: AXUIElement) -> CGRect? {
    var origin = CGPoint.zero
    var size = CGSize.zero
    guard let position = attribute(element, kAXPositionAttribute), CFGetTypeID(position) == AXValueGetTypeID(),
      AXValueGetValue(position as! AXValue, .cgPoint, &origin),
      let extent = attribute(element, kAXSizeAttribute), CFGetTypeID(extent) == AXValueGetTypeID(),
      AXValueGetValue(extent as! AXValue, .cgSize, &size)
    else { return nil }
    return CGRect(origin: origin, size: size)
  }

  /// Where the title bar's buttons are differs between versions of macOS and between apps. Accessibility knows.
  func titleBarButton(_ attributeName: String, pid: pid_t, corner: CGPoint) -> CGRect? {
    let application = AXUIElementCreateApplication(pid)
    guard let candidates = attribute(application, kAXWindowsAttribute) as? [AnyObject] else { return nil }
    var nearest: AXUIElement?
    var shortest = CGFloat.infinity
    for candidate in candidates where CFGetTypeID(candidate) == AXUIElementGetTypeID() {
      let window = candidate as! AXUIElement
      guard let rect = frame(ofElement: window) else { continue }
      let distance = abs(rect.minX - corner.x) + abs(rect.minY - corner.y)
      if distance < shortest {
        shortest = distance
        nearest = window
      }
    }
    guard let window = nearest, let button = attribute(window, attributeName),
      CFGetTypeID(button) == AXUIElementGetTypeID()
    else { return nil }
    return frame(ofElement: button as! AXUIElement)
  }

  // MARK: Commands

  mutating func run() {
    guard !arguments.isEmpty else { fail(Pointer.usage) }
    let command = arguments.removeFirst()
    let held = option("--mods").map { parse(chord: $0).modifiers } ?? []
    if let name = option("--tap") {
      guard name == "session" || name == "hid" else { fail("--tap takes hid or session") }
      tap = name == "session" ? .cgSessionEventTap : .cghidEventTap
    }

    switch command {
    case "move":
      move(to: point(at: 0))

    case "click":
      // First: they take their words out of the arguments, which the count is read from.
      let press = flag("--quick") ? 0 : 0.04
      let right = flag("--right")
      let target = point(at: 0)
      let count = arguments.count > 2 ? max(1, min(3, Int(number(arguments[2])))) : 1
      move(to: target)
      hold(held)
      for click in 1...count {
        mouse(right ? .rightMouseDown : .leftMouseDown, at: target, clicks: Int64(click), button: right ? .right : .left)
        rest(press)
        mouse(right ? .rightMouseUp : .leftMouseUp, at: target, clicks: Int64(click), button: right ? .right : .left)
        rest(0.08)
      }
      letGo(held)

    case "drag":
      let steps = option("--steps").map { max(1, min(1000, Int(number($0)))) } ?? 30
      let duration = option("--duration").map { max(0, min(30, number($0))) } ?? 0.6
      let wait = option("--hold").map { max(0, min(30, number($0))) } ?? 0.2
      let release = !flag("--no-release")
      let settles = !flag("--no-settle")
      let start = point(at: 0)
      let end = point(at: 2)
      // A misspelt option would otherwise be a drag that quietly does something else.
      guard arguments.count == 4 else { fail("drag takes x1 y1 x2 y2 and its options, not \(arguments.dropFirst(4))") }
      move(to: start)
      hold(held)
      mouse(.leftMouseDown, at: start, clicks: 1)
      rest(0.15)  // AppKit decides what the press means before the first movement
      glide(.leftMouseDragged, from: start, to: end, steps: steps, duration: duration)
      if settles { settle(at: end) }
      rest(wait)
      if release {
        mouse(.leftMouseUp, at: end, clicks: 1)
        letGo(held)
      }

    case "drag-on":
      let steps = option("--steps").map { max(1, min(1000, Int(number($0)))) } ?? 30
      let duration = option("--duration").map { max(0, min(30, number($0))) } ?? 0.6
      let wait = option("--hold").map { max(0, min(30, number($0))) } ?? 0.2
      let end = point(at: 0)
      guard arguments.count == 2 else { fail("drag-on takes x y and its options, not \(arguments.dropFirst(2))") }
      guard CGEventSource.buttonState(.hidSystemState, button: .left) else { fail("drag-on, but the button is not down") }
      // The modifiers were pressed by the `drag --no-release` this carries on.
      for modifier in held { flags.insert(modifier.flag) }
      glide(.leftMouseDragged, from: location, to: end, steps: steps, duration: duration)
      settle(at: end)
      rest(wait)

    case "release":
      let target = arguments.count >= 2 ? point(at: 0) : location
      // The modifiers were pressed by the `drag --no-release` this finishes.
      for modifier in held { flags.insert(modifier.flag) }
      mouse(.leftMouseDragged, at: target, clicks: 1, from: location)
      rest(0.05)
      mouse(.leftMouseUp, at: target, clicks: 1)
      letGo(held)

    case "key":
      // ---- F51 (peek): keys that stay down from one call of this tool to the next --------------------------
      let (down, up, held) = (flag("--down"), flag("--up"), flag("--held"))
      let repeats = option("--repeat").map { max(0, min(200, Int(number($0)))) }
      if down || up || held || repeats != nil {
        guard let chord = arguments.first else { fail("expected a shortcut, e.g. ctrl+opt+space") }
        let parsed = parse(chord: chord)
        if down {
          hold(parsed.modifiers)
          if let key = parsed.key { keyboard(key, down: true) }
          break
        }
        // The modifiers were pressed by an earlier `key --down`; every event carries them.
        for modifier in parsed.modifiers { flags.insert(modifier.flag) }
        if up {
          if let key = parsed.key { keyboard(key, down: false) }
          letGo(parsed.modifiers)
          break
        }
        guard let key = parsed.key else { fail("no key in \(chord), only modifiers") }
        if held {
          keyboard(key, down: true)
          rest(0.04)
          keyboard(key, down: false)
        }
        for _ in 0..<(repeats ?? 0) {
          keyboard(key, down: true, autorepeat: true)
          rest(0.03)
        }
        break
      }
      // ---- end of F51's block ---------------------------------------------------------------------------------
      guard let chord = arguments.first else { fail("expected a shortcut, e.g. ctrl+opt+space") }
      let parsed = parse(chord: chord)
      guard let key = parsed.key else { fail("no key in \(chord), only modifiers") }
      hold(parsed.modifiers)
      keyboard(key, down: true)
      rest(0.04)
      keyboard(key, down: false)
      letGo(parsed.modifiers)

    case "calm":
      // What a script that died in the middle of a drag or of a held shortcut left down. Nobody else lets go of it: the
      // window server goes on believing it until a person presses that very button or key.
      func isDown(_ probe: (CGEventSourceStateID) -> Bool) -> Bool { probe(.hidSystemState) || probe(.combinedSessionState) }
      var released: [String] = []
      let buttons: [(button: CGMouseButton, up: CGEventType, name: String)] = [
        (.left, .leftMouseUp, "the left button"), (.right, .rightMouseUp, "the right button"),
        (.center, .otherMouseUp, "the middle button"),
      ]
      for entry in buttons where isDown({ CGEventSource.buttonState($0, button: entry.button) }) {
        guard
          let event = CGEvent(
            mouseEventSource: source, mouseType: entry.up, mouseCursorPosition: location, mouseButton: entry.button)
        else { continue }
        event.post(tap: tap)
        released.append(entry.name)
      }
      // 54 to 63 are the modifiers of both hands, Caps Lock and Fn. Keys first, as a hand lets go of a shortcut.
      for code in CGKeyCode(0)..<CGKeyCode(128) where !(54...63).contains(code) {
        guard isDown({ CGEventSource.keyState($0, key: code) }) else { continue }
        keyboard(code, down: false)
        released.append("key \(code)")
      }
      // The modifiers whatever the tables say: a key-up too many does nothing, and a ⌘ that stays down turns the next Q into ⌘Q.
      for modifier in Pointer.modifiers.reversed() {
        if isDown({ CGEventSource.keyState($0, key: modifier.code) || CGEventSource.flagsState($0).contains(modifier.flag) }) {
          released.append(modifier.names[0])
        }
        keyboard(modifier.code, down: false)
      }
      if !released.isEmpty { print("calm: let go of \(released.joined(separator: ", "))") }

    case "pinch":
      let steps = option("--steps").map { max(1, min(200, Int(number($0)))) } ?? 10
      let target = point(at: 0)
      guard arguments.count > 2 else { fail("expected x y and an amount, e.g. pinch 500 400 0.6") }
      let amount = number(arguments[2])
      move(to: target)
      hold(held)
      magnify(phase: 1, by: 0, at: target)
      for _ in 1...steps { magnify(phase: 2, by: amount / Double(steps), at: target) }
      magnify(phase: 4, by: 0, at: target)
      letGo(held)

    case "where":
      let down = CGEventSource.buttonState(.hidSystemState, button: .left)
      print("\(text(location.x)) \(text(location.y)) \(down ? "down" : "up")")

    case "activity":
      func idle(_ type: CGEventType) -> Double {
        CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: type)
      }
      let used: [CGEventType] = [
        .mouseMoved, .leftMouseDown, .leftMouseDragged, .rightMouseDown, .rightMouseDragged, .otherMouseDown,
        .scrollWheel,
      ]
      let presses = CGEventSource.counterForEventType(.combinedSessionState, eventType: .keyDown)
      print(String(format: "pointer %.2f keys %.2f presses %u", used.map(idle).min() ?? -1, idle(.keyUp), presses))

    case "displays":
      for id in displays() {
        let rect = CGDisplayBounds(id)
        let mode = CGDisplayCopyDisplayMode(id)
        let pixels = (mode?.pixelWidth ?? Int(rect.width), mode?.pixelHeight ?? Int(rect.height))
        let scale = rect.width > 0 ? CGFloat(pixels.0) / rect.width : 1
        print("\(id) \(text(rect)) \(pixels.0) \(pixels.1) \(text(scale))")
      }

    case "windows":
      let pid = option("--pid").map { Int(number($0)) }
      for info in windows(onScreenOnly: flag("--on-screen")) {
        guard let id = (info[kCGWindowNumber as String] as? NSNumber)?.uint32Value, let rect = bounds(info) else {
          continue
        }
        let owner = (info[kCGWindowOwnerPID as String] as? NSNumber)?.intValue ?? 0
        if let pid, pid != owner { continue }
        let layer = (info[kCGWindowLayer as String] as? NSNumber)?.intValue ?? 0
        let onScreen = (info[kCGWindowIsOnscreen as String] as? NSNumber)?.boolValue ?? false
        let name = info[kCGWindowOwnerName as String] as? String ?? "?"
        print("\(id) \(owner) \(layer) \(text(rect)) \(onScreen ? "on" : "off") \(name)")
      }

    case "frame":
      print(text(frame(of: windowID(at: 0))))

    case "visible":
      let rect = frame(of: windowID(at: 0))
      let area = isOnScreen(windowID(at: 0)) ? rect.width * rect.height : 0
      var best: CGFloat = 0
      for id in displays() where area > 0 {
        let shared = rect.intersection(CGDisplayBounds(id))
        if !shared.isNull { best = max(best, shared.width * shared.height / area) }
      }
      print(String(format: "%.2f", Double(best)))

    case "grab":
      // Right of the three buttons, and clear of the rounded corner.
      guard
        let point = freePoint(
          of: windowID(at: 0),
          in: { CGRect(x: $0.minX + 84, y: $0.minY + 12, width: max($0.width - 100, 0), height: 1) })
      else { fail("no part of the title bar of window \(windowID(at: 0)) is in reach") }
      print("\(text(point.x)) \(text(point.y))")

    case "spot":
      guard
        let point = freePoint(
          of: windowID(at: 0),
          in: { CGRect(x: $0.minX + 8, y: $0.minY + 40, width: max($0.width - 16, 0), height: max($0.height - 48, 0)) })
      else { fail("no part of window \(windowID(at: 0)) is in reach") }
      print("\(text(point.x)) \(text(point.y))")

    case "button":
      // By process and place, for windows whose number is not known.
      if arguments.count == 4 {
        guard let word = arguments.first, let pid = pid_t(word), arguments.count == 4 else {
          fail("expected a process id, x, y and close, minimize or zoom")
        }
        let names = ["close": "AXCloseButton", "minimize": "AXMinimizeButton", "zoom": "AXZoomButton"]
        guard let name = names[arguments[3]] else { fail("expected close, minimize or zoom, got \(arguments[3])") }
        guard let rect = titleBarButton(name, pid: pid, corner: point(at: 1)) else {
          fail("process \(pid) has no window with a \(arguments[3]) button")
        }
        print("\(text(rect.midX)) \(text(rect.midY))")
        break
      }
      let names = ["close": kAXCloseButtonAttribute, "minimize": kAXMinimizeButtonAttribute, "zoom": kAXZoomButtonAttribute]
      guard arguments.count > 1, let name = names[arguments[1]] else { fail("expected close, minimize or zoom") }
      guard let window = accessibilityWindow(windowID(at: 0)), let button = attribute(window, name),
        CFGetTypeID(button) == AXUIElementGetTypeID(), let rect = frame(of: button as! AXUIElement)
      else { fail("window \(windowID(at: 0)) shows no \(arguments[1]) button") }
      print("\(text(rect.midX)) \(text(rect.midY))")

    case "ax":
      guard let window = accessibilityWindow(windowID(at: 0)) else {
        fail("Accessibility lists no window \(windowID(at: 0))")
      }
      let role = attribute(window, kAXRoleAttribute) as? String ?? "?"
      let subrole = attribute(window, kAXSubroleAttribute) as? String ?? "?"
      print("\(role) \(subrole)")

    case "front":
      // As Arbor asks. Accessibility's system-wide "focused application" answered nothing on GitHub's Macs (macOS 26), with an
      // ordinary app in front and its name in the menu bar.
      guard let application = NSWorkspace.shared.frontmostApplication else { fail("no app is in front") }
      print(application.processIdentifier)

    case "menu-item", "menu-mark":
      guard arguments.count > 1, let pid = pid_t(arguments[0]) else { fail("expected a process id and a title") }
      let title = arguments.dropFirst().joined(separator: " ")
      guard let bar = attribute(AXUIElementCreateApplication(pid), "AXExtrasMenuBar"),
        CFGetTypeID(bar) == AXUIElementGetTypeID(),
        let item = descendant(of: bar as! AXUIElement, titled: title, depth: 6), let rect = frame(of: item),
        rect.width > 0
      else { fail("process \(pid) shows no menu item starting with \(title)") }
      if command == "menu-mark" {
        let mark = attribute(item, kAXMenuItemMarkCharAttribute) as? String ?? ""
        print(mark.isEmpty ? "-" : mark)
      } else {
        print("\(text(rect.midX)) \(text(rect.midY))")
      }

    case "status-item":
      let whole = flag("--frame")
      guard let word = arguments.first, let pid = pid_t(word) else { fail("expected a process id") }
      guard let rect = statusItemFrame(pid: pid) else { fail("process \(pid) shows no menu bar item") }
      print(whole ? text(rect) : "\(text(rect.midX)) \(text(rect.midY))")

    case "picture":
      guard arguments.count == 4 || arguments.count == 5 else { fail("expected a file, a size and one or two colours") }
      let width = Int(number(arguments[1]))
      let height = Int(number(arguments[2]))
      guard (1...16384).contains(width), (1...16384).contains(height) else { fail("a picture is 1 to 16384 pixels a side") }
      writePicture(to: arguments[0], width: width, height: height, colours: arguments.dropFirst(3).map { colour($0) })

    case "wallpaper":
      if let path = arguments.first, !FileManager.default.fileExists(atPath: path) { fail("there is no file \(path)") }
      // As lib.sh's wrapper refuses it too: the desktop picture is the person's, except on a Mac that is thrown away.
      // The variable and the account, as there: a runner on a person's own Mac sets the variable too.
      if !arguments.isEmpty, ProcessInfo.processInfo.environment["GITHUB_ACTIONS"] != "true" || NSUserName() != "runner" {
        fail("this Mac is somebody's: the wallpaper is changed only on GitHub's throwaway Macs")
      }
      let picture = arguments.first.map { URL(fileURLWithPath: $0) }
      do {
        try MainActor.assumeIsolated { try showOnEveryDesktop(picture) }
      } catch {
        fail("could not set the wallpaper: \(error)")
      }

    case "screen-access":
      print(CGPreflightScreenCaptureAccess())

    case "ax-access":
      print(AXIsProcessTrusted())

    case "reduce-motion":
      print(NSWorkspace.shared.accessibilityDisplayShouldReduceMotion)

    case "asleep":
      print(CGDisplayIsAsleep(CGMainDisplayID()) != 0)

    default:
      fail("unknown command \(command)\n\(Pointer.usage)")
    }
  }
}

var pointer = Pointer(arguments: Array(CommandLine.arguments.dropFirst()))
pointer.run()
