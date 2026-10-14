import AppKit

/// Makes the test windows do what real apps and their users do, one command per line on stdin. Windows are named
/// by their numbers; frames are global coordinates, origin top-left, as `arborctl state` reports them.
///
///   minimize <id> | restore <id> | close <id> | key <id>
///   front <id>                      comes to the front without taking the keyboard
///   title <id> <words…>             renames the window
///   move <id> <x> <y> <w> <h>       the app moves its own window
///   insist <id> <x> <y> <w> <h>     and moves it back there, a quarter of a second or so after anyone moves it
///   insist <id> <x> <y> <w> <h> quick   the same within a twentieth of a second
///   relent <id>                     stops insisting
///   min-size <id> <w> <h>           refuses to be smaller from now on
///   tab <id>                        opens a new native tab in front of the window; prints {"window":4504}
///   dialog <id>                     opens a dialog centred over the window, wherever that is; prints {"window":4505}
///   popover <id>                    shows a popover over the window that goes away by itself, as Calendar's and Safari's do
///   open <x> <y> <w> <h> [fixed] [min <w> <h>]
///                                   opens a window of its own, as ⌘N does; prints {"window":4506}. `fixed`: its size
///                                   cannot be changed. `min`: it refuses to be smaller than that
///   select <id>                     brings that tab to the front of its group
///   full-screen <id>                enters or leaves macOS's full-screen mode
///   hide | unhide | activate        the whole app
///   hang <seconds>                  stops answering anyone for that long
///
/// MoreCommands.swift has more: open, front, activate <id>, title, events, list, ping.
@MainActor
final class Commands {
  var windows: [NSWindow]
  /// Input that has not ended in a newline yet.
  private var pending = ""
  /// The frames (AppKit coordinates) windows insist on, by window number.
  private var insisted: [Int: NSRect] = [:]
  /// For how many ticks of the timer each of them has been somewhere else, and how many it puts up with.
  private var ticksAway: [Int: Int] = [:]
  private var patience: [Int: Int] = [:]
  private var insistence: Timer?

  init(_ windows: [NSWindow]) {
    self.windows = windows
  }

  func receive(_ text: String) {
    pending += text
    while let end = pending.firstIndex(of: "\n") {
      let line = String(pending[pending.startIndex..<end])
      pending = String(pending[pending.index(after: end)...])
      perform(line.split(separator: " ").map(String.init))
    }
  }

  func window(_ words: [String]) -> NSWindow? {
    guard words.count > 1, let number = Int(words[1]) else { return nil }
    return windows.first { $0.windowNumber == number }
  }

  /// Words 2 to 5 as a frame in AppKit's coordinates.
  private func frame(_ words: [String]) -> NSRect? {
    let numbers = words.dropFirst(2).compactMap { Double($0) }
    guard numbers.count == 4, let primary = NSScreen.screens.first else { return nil }
    return NSRect(
      x: numbers[0], y: Double(primary.frame.height) - numbers[1] - numbers[3], width: numbers[2], height: numbers[3])
  }

  private func perform(_ words: [String]) {
    guard let command = words.first else { return }
    let target = window(words)
    switch command {
    case "minimize": target?.miniaturize(nil)
    case "restore": target?.deminiaturize(nil)
    case "close": target?.close()
    case "key": target?.makeKeyAndOrderFront(nil)
    // Without such a window here MoreCommands.swift says so, and the script asks the other test app.
    case "front" where target != nil: target?.orderFrontRegardless()
    case "title" where target != nil: target?.title = words.dropFirst(2).joined(separator: " ")
    case "move":
      if let frame = frame(words) { target?.setFrame(frame, display: true) }
    case "insist":
      if let target, let frame = frame(Array(words.prefix(6))) {
        // Slowly: 0.2 to 0.25 s after the move, when Arbor takes it for somebody's move. Quickly: within 0.05 s, when
        // Arbor takes it for a stage of its own move at first.
        patience[target.windowNumber] = words.last == "quick" ? 1 : 5
        insist(on: frame, for: target)
      }
    case "relent":
      if let target { insisted[target.windowNumber] = nil }
    case "min-size":
      let numbers = words.dropFirst(2).compactMap { Double($0) }
      if numbers.count == 2 { target?.minSize = NSSize(width: numbers[0], height: numbers[1]) }
    case "tab":
      if let target { openTab(in: target) }
    case "dialog":
      if let target { openDialog(over: target) }
    case "popover":
      if let target { showPopover(over: target) }
    // `open x y w h …`. `open size=… title=…` is MoreCommands.swift's.
    case "open" where words.count >= 5 && Double(words[1]) != nil:
      if let frame = frame(["open", "new"] + words[1...4]) {
        let minimum = words.firstIndex(of: "min").map { words[($0 + 1)...].prefix(2).compactMap { Double($0) } } ?? []
        openWindow(
          at: frame, resizable: !words.contains("fixed"),
          minimum: minimum.count == 2 ? NSSize(width: minimum[0], height: minimum[1]) : nil)
      }
    case "select": target?.tabGroup?.selectedWindow = target
    case "full-screen": target?.toggleFullScreen(nil)
    case "hide": NSApp.hide(nil)
    case "unhide": NSApp.unhideWithoutActivation()
    // The newer `activate()` is a request that macOS does not grant an accessory app in the background.
    case "activate":
      NSApp.activate(ignoringOtherApps: true)
      target?.makeKeyAndOrderFront(nil)
    case "hang":
      if words.count > 1, let seconds = Double(words[1]) { Thread.sleep(forTimeInterval: min(max(seconds, 0), 60)) }
    default: performMore(words)
    }
  }

  /// Transient: it closes at a click beside it and when its app is left. Nothing is printed: it is no window to Accessibility,
  /// and the window server's list says whether it is there.
  private func showPopover(over window: NSWindow) {
    guard let view = window.contentView else { return }
    let content = NSViewController()
    content.view = NSView(frame: NSRect(x: 0, y: 0, width: 160, height: 90))
    let popover = NSPopover()
    popover.behavior = .transient
    popover.animates = false
    popover.contentViewController = content
    popover.show(relativeTo: NSRect(x: view.bounds.midX, y: view.bounds.midY, width: 1, height: 1), of: view, preferredEdge: .maxY)
  }

  /// As ⌘T does it: the new window is never on screen on its own.
  private func openTab(in window: NSWindow) {
    let tab = NSWindow(
      contentRect: window.contentRect(forFrameRect: window.frame), styleMask: window.styleMask, backing: .buffered,
      defer: false)
    tab.title = "\(window.title), tab \(windows.count)"
    tab.isReleasedWhenClosed = false
    tab.isRestorable = false
    tab.backgroundColor = .systemGray
    windows.append(tab)
    window.addTabbedWindow(tab, ordered: .above)
    tab.makeKeyAndOrderFront(nil)
    print("{\"window\":\(tab.windowNumber)}")
    fflush(nil)
  }

  /// As ⌘N does it.
  private func openWindow(at frame: NSRect, resizable: Bool, minimum: NSSize?) {
    let window = NSWindow(
      contentRect: frame,
      styleMask: resizable ? [.titled, .closable, .miniaturizable, .resizable] : [.titled, .closable, .miniaturizable],
      backing: .buffered, defer: false)
    window.title = "Arbor Test, opened later (\(windows.count))"
    window.isReleasedWhenClosed = false
    window.backgroundColor = .systemGray
    if let minimum { window.minSize = minimum }
    // The frame asked for includes the title bar.
    window.setFrame(frame, display: true)
    windows.append(window)
    window.makeKeyAndOrderFront(nil)
    print("{\"window\":\(window.windowNumber)}")
    fflush(nil)
  }

  /// As many apps place their alerts: over the middle of the window they are about.
  private func openDialog(over window: NSWindow) {
    let size = NSSize(width: 260, height: 120)
    let dialog = NSPanel(
      contentRect: NSRect(
        x: window.frame.midX - size.width / 2, y: window.frame.midY - size.height / 2, width: size.width,
        height: size.height),
      styleMask: [.titled], backing: .buffered, defer: false)
    dialog.title = "Dialog"
    dialog.isReleasedWhenClosed = false
    dialog.isRestorable = false
    // Panels hide while their app is in the background, which this one mostly is.
    dialog.hidesOnDeactivate = false
    windows.append(dialog)
    dialog.orderFrontRegardless()
    print("{\"window\":\(dialog.windowNumber)}")
    fflush(nil)
  }

  private func insist(on frame: NSRect, for window: NSWindow) {
    insisted[window.windowNumber] = frame
    window.setFrame(frame, display: true)
    guard insistence == nil else { return }
    insistence = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
      MainActor.assumeIsolated {
        guard let self else { return }
        for window in self.windows {
          let number = window.windowNumber
          guard let frame = self.insisted[number], window.frame != frame else {
            self.ticksAway[number] = 0
            continue
          }
          self.ticksAway[number, default: 0] += 1
          if self.ticksAway[number, default: 0] >= self.patience[number, default: 5] {
            window.setFrame(frame, display: true)
          }
        }
      }
    }
  }
}
