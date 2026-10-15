import AppKit

/// Counts what reaches a window's content, so that a test can tell whether Arbor swallowed an event or let it through.
final class CountingView: NSView {
  var counts: [String: Int] = ["down": 0, "up": 0, "dragged": 0, "key": 0, "magnify": 0]

  /// `by-background`: a press on it takes the window along, as in many of Apple's own apps, and never reaches it.
  var takesTheWindowAlong = false

  override var mouseDownCanMoveWindow: Bool { takesTheWindowAlong }
  override var acceptsFirstResponder: Bool { true }
  override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
  /// The label in the middle, where most presses are aimed, would be asked instead, and it takes no first click.
  override func hitTest(_ point: NSPoint) -> NSView? { super.hitTest(point) == nil ? nil : self }
  override func mouseDown(with event: NSEvent) { counts["down", default: 0] += 1 }
  override func mouseUp(with event: NSEvent) { counts["up", default: 0] += 1 }
  override func mouseDragged(with event: NSEvent) { counts["dragged", default: 0] += 1 }
  override func keyDown(with event: NSEvent) { counts["key", default: 0] += 1 }
  override func magnify(with event: NSEvent) { counts["magnify", default: 0] += 1 }
}

/// The shortcuts every app has. The menu bar shows them only with `--regular`; they work either way.
@MainActor
func makeMenu() -> NSMenu {
  let menu = NSMenu()
  let item = NSMenuItem()
  menu.addItem(item)
  let submenu = NSMenu(title: "ArborTestWindows")
  // By name, in two pairs of brackets, rather than with #selector: `make typecheck-mac` has no Objective-C to look them up in.
  submenu.addItem(withTitle: "Hide", action: Selector(("hide:")), keyEquivalent: "h")
  submenu.addItem(withTitle: "Minimize", action: Selector(("performMiniaturize:")), keyEquivalent: "m")
  submenu.addItem(withTitle: "Close", action: Selector(("performClose:")), keyEquivalent: "w")
  item.submenu = submenu
  return menu
}

/// What the real-window suite (scripts/mac-shell/suite) asks for besides. Those that answer print one line of JSON.
///
///   open [size=WxH] [min=WxH] [max=WxH] [at=X,Y] [kind=window|panel|sheet:<id>] [title=the rest of the line]
///                                   a new window, in front; `at` is its frame's top-left corner; prints {"window":4504}
///   front <id>                      brings it in front of the others without taking the keyboard
///   activate <id>                   what ⌘Tab or a click in the Dock does: the app comes forward with this window (Commands.swift)
///   title <id> <the rest of the line>
///   events <id>                     what its content has received: {"down":1,"dragged":0,"key":0,"magnify":0,"up":1}
///   list                            {"windows":[…]}: the windows on screen or minimized
///   ping <number>                   {"pong":<number>}: everything asked before it has been done
///
/// A command nobody knows, and one of these that names a window that is not there, prints {"error":"…"}.
extension Commands {
  func performMore(_ words: [String]) {
    switch words[0] {
    case "open":
      open(Array(words.dropFirst()))
    case "ping":
      say("{\"pong\":\(words.count > 1 ? words[1] : "0")}")
    case "list":
      let numbers = windows.filter { $0.isVisible || $0.isMiniaturized }.map { String($0.windowNumber) }
      say("{\"windows\":[\(numbers.joined(separator: ","))]}")
    case "front", "title", "events":
      guard let target = window(words) else { return complain("no such window: \(words.joined(separator: " "))") }
      if words[0] == "front" {
        target.orderFrontRegardless()
      } else if words[0] == "title" {
        target.title = words.dropFirst(2).joined(separator: " ")
      } else if let view = target.contentView as? CountingView {
        let fields = view.counts.sorted { $0.key < $1.key }.map { "\"\($0.key)\":\($0.value)" }
        say("{\(fields.joined(separator: ","))}")
      } else {
        complain("that window does not count its events")
      }
    default:
      complain("unknown command \(words[0])")
    }
  }

  private func say(_ line: String) {
    print(line)
    fflush(nil)
  }

  private func complain(_ reason: String) {
    say("{\"error\":\"\(reason.filter { $0 != "\"" && $0 != "\\" })\"}")
  }

  /// `700x500`
  private func size(_ text: String) -> NSSize? {
    let parts = text.lowercased().split(separator: "x").compactMap { Double($0) }
    return parts.count == 2 ? NSSize(width: parts[0], height: parts[1]) : nil
  }

  private func open(_ words: [String]) {
    var content = NSSize(width: 480, height: 320)
    var minimum: NSSize?
    var maximum: NSSize?
    var corner: NSPoint?
    var kind = "window"
    var title = "Arbor Test \(windows.count + 1)"
    for (index, word) in words.enumerated() {
      let parts = word.split(separator: "=", maxSplits: 1).map(String.init)
      guard parts.count == 2 else { return complain("expected name=value, got \(word)") }
      if parts[0] == "title" {
        // It takes the rest of the line.
        title = ([parts[1]] + words.dropFirst(index + 1)).joined(separator: " ")
        break
      }
      switch parts[0] {
      case "size", "min", "max":
        guard let value = size(parts[1]) else { return complain("\(parts[0])=WxH") }
        if parts[0] == "size" { content = value } else if parts[0] == "min" { minimum = value } else { maximum = value }
      case "at":
        let numbers = parts[1].split(separator: ",").compactMap { Double($0) }
        guard numbers.count == 2 else { return complain("at=X,Y") }
        corner = NSPoint(x: numbers[0], y: numbers[1])
      case "kind":
        kind = parts[1]
      default:
        return complain("unknown option \(parts[0])")
      }
    }

    let rect = NSRect(
      x: CGFloat(140 + windows.count * 30), y: CGFloat(200 + windows.count * 20), width: content.width,
      height: content.height)
    let window: NSWindow
    var parent: NSWindow?
    if kind == "window" {
      window = NSWindow(
        contentRect: rect, styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
      window.collectionBehavior = [.fullScreenPrimary]
    } else if kind == "panel" {
      let panel = NSPanel(
        contentRect: rect, styleMask: [.titled, .closable, .utilityWindow], backing: .buffered, defer: false)
      panel.isFloatingPanel = true
      // Panels hide while their app is in the background, which this one mostly is.
      panel.hidesOnDeactivate = false
      window = panel
    } else if kind.hasPrefix("sheet:"), let number = Int(kind.dropFirst("sheet:".count)),
      let found = windows.first(where: { $0.windowNumber == number })
    {
      parent = found
      window = NSWindow(contentRect: rect, styleMask: [.titled], backing: .buffered, defer: false)
    } else {
      return complain("kind is window, panel or sheet:<id of an open window>, not \(kind)")
    }
    window.title = title
    window.isReleasedWhenClosed = false
    window.isRestorable = false
    window.backgroundColor = .systemBrown
    window.contentView = CountingView()
    window.makeFirstResponder(window.contentView)
    if let minimum { window.minSize = minimum }
    if let maximum { window.maxSize = maximum }
    if let corner, let primary = NSScreen.screens.first {
      window.setFrameOrigin(NSPoint(x: corner.x, y: primary.frame.height - corner.y - window.frame.height))
    }
    windows.append(window)
    if let parent {
      parent.beginSheet(window)
    } else {
      window.orderFrontRegardless()
    }
    say("{\"window\":\(window.windowNumber)}")
  }
}
