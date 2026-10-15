import ArborCore
import ArborKit
import ArborTesting
import CoreGraphics
import Foundation

/// ArborTestWindows (Sources/ArborTestWindows): its arguments, where it opens its windows, the commands it
/// takes on stdin (Commands.swift) and what it prints. Most commands print nothing. Unlike the real one on the
/// trunk it refuses arguments it does not know, and answers a command it does not know, or that names a window
/// it does not have, with `{"error":"…"}`, so that a script's typo shows.
extension World {
  private struct AppRefusal: Error {
    let reason: String
    init(_ reason: String) { self.reason = reason }
  }

  /// `700x500`
  private func parseSize(_ text: String) -> CGSize? {
    let parts = text.lowercased().split(separator: "x").compactMap { Double($0) }
    return parts.count == 2 ? CGSize(width: parts[0], height: parts[1]) : nil
  }

  // MARK: Starting and ending

  /// `app-start <pid> <bundle id> <name> [--count n] [--min-size i:WxH] [--max-size i:WxH] [--regular]
  /// [--extras]`
  func startApp(_ words: [String]) throws -> Reply {
    guard words.count >= 3, let pid = Int32(words[0]) else {
      throw Refusal(message: "arbor-fakemac: usage: app-start <pid> <bundle id> <name> <arguments…>")
    }
    var app = TestApp(pid: pid, bundleID: words[1], name: words[2])
    var count = 3
    var minimumSizes: [Int: CGSize] = [:]
    var maximumSizes: [Int: CGSize] = [:]
    var opensExtras = false
    var arguments = Array(words.dropFirst(3))
    func value(of flag: String) throws -> String {
      guard !arguments.isEmpty else {
        throw Refusal(message: "ArborTestWindows (rehearsal): \(flag) needs a value")
      }
      return arguments.removeFirst()
    }
    func unreadable(_ flag: String, _ text: String) -> Refusal {
      Refusal(message: "ArborTestWindows (rehearsal): cannot read \(flag) \(text)")
    }
    while !arguments.isEmpty {
      let flag = arguments.removeFirst()
      switch flag {
      case "--count":
        let text = try value(of: flag)
        guard let number = Int(text) else { throw unreadable(flag, text) }
        count = number
      case "--min-size", "--max-size":
        let text = try value(of: flag)
        let parts = text.split(separator: ":")
        guard parts.count == 2, let index = Int(parts[0]), let limit = parseSize(String(parts[1])) else {
          throw unreadable(flag, text)
        }
        if flag == "--min-size" { minimumSizes[index] = limit } else { maximumSizes[index] = limit }
      case "--regular":
        app.regular = true
      case "--extras":
        opensExtras = true
      case "-ApplePersistenceIgnoreState":
        // For AppKit, which reads `-name value` as a default: no saved state is kept. There is none to keep here.
        _ = try value(of: flag)
      default:
        throw Refusal(message: "ArborTestWindows (rehearsal): unknown argument \(flag)")
      }
    }
    apps[pid] = app
    var ids: [UInt32] = []
    for index in 1...max(count, 1) {
      if let id = try? openWindow(
        of: pid, title: "Arbor Test \(index)", content: initialContent(index, maximum: maximumSizes[index]),
        minimum: minimumSizes[index], maximum: maximumSizes[index])
      {
        ids.append(id)
      }
    }
    if opensExtras, let first = ids.first {
      _ = try? openWindow(
        of: pid, title: "Arbor Test Panel", content: CGRect(x: 20, y: 90, width: 160, height: 80), kind: "panel"
      )
      _ = try? openWindow(
        of: pid, title: "Arbor Test Sheet", content: CGRect(x: 0, y: 0, width: 220, height: 90),
        kind: "sheet:\(first)")
    }
    return .printing("{\"pid\":\(pid),\"windows\":[\(ids.map(String.init).joined(separator: ","))]}")
  }

  /// Where `openWindows` puts its window number `index`, in AppKit's coordinates.
  private func initialContent(_ index: Int, maximum: CGSize? = nil) -> CGRect {
    var content = CGRect(x: CGFloat(120 + index * 50), y: CGFloat(160 + index * 40), width: 480, height: 320)
    if let maximum {
      // The real app shrinks the window it has just made with `setContentSize`. That its top left corner is
      // what stays put is a guess; no run has printed such a window's frame before Arbor moved it.
      let top = content.maxY
      content.size = CGSize(
        width: min(480, maximum.width), height: min(320, maximum.height - World.titleBarHeight))
      content.origin.y = top - content.height
    }
    return content
  }

  /// `app-exit <pid>`: its stdin closed. Arbor hears that the app ended and forgets its windows in order.
  func endApp(_ words: [String]) throws -> Reply {
    guard let pid = words.first.flatMap({ Int32($0) }) else {
      throw Refusal(message: "arbor-fakemac: usage: app-exit <pid>")
    }
    guard apps[pid] != nil else { return Reply() }
    for id in windowIDs(of: pid) { remove(id) }
    apps[pid] = nil
    hungUntil[pid] = nil
    tabGroups.removeAll { group in group.pid == pid }
    leaveFront(pid)
    return Reply()
  }

  /// In the order they were opened: both kinds of number only ever grow.
  func windowIDs(of pid: Int32) -> [UInt32] {
    let standard = system.windows.values.filter { $0.snapshot.pid == pid }.map(\.snapshot.id.rawValue)
    return standard.sorted() + extras.values.filter { $0.pid == pid }.map(\.id).sorted()
  }

  private func remove(_ id: UInt32) {
    for sheet in extras.values.filter({ $0.kind == .sheet(parent: WindowID(id)) }).map(\.id).sorted() {
      remove(sheet)
    }
    forget(.window(id))
    counts[id] = nil
    extras[id] = nil
    system.close(WindowID(id))
    switch held {
    case .title(let window, _, _, _) where window.rawValue == id: held = .idle
    case .resize(let window, _, _, _) where window.rawValue == id: held = .idle
    case .button(let window, _) where window.rawValue == id: held = .idle
    case .content(let window) where window == id: held = .idle
    case .panelTitle(let window, _) where window == id: held = .idle
    default: break
    }
  }

  /// What the red button, ⌘W and the `close` command do. `FakeWindowSystem` hands the keyboard on.
  func closeWindow(_ id: UInt32) {
    if let index = tabGroups.firstIndex(where: { $0.front == id }) {
      // The tab behind takes its place first, then the closed one is reported gone.
      if let next = tabGroups[index].behind.popLast() {
        system.closeTab(WindowID(id), revealing: WindowID(next))
        replace(id, by: next)
        tabGroups[index].front = next
        followKeyboard()
        return
      }
      tabGroups.remove(at: index)
    }
    remove(id)
    followKeyboard()
  }

  /// What the yellow button, ⌘M and the `minimize` command do.
  func minimizeWindow(_ window: WindowID) {
    system.setMinimized(window, true)
    followKeyboard()
  }

  /// What ⌘H and the `hide` command do.
  func hideApp(_ pid: Int32) {
    apps[pid]?.hidden = true
    system.setHidden(pid: pid, true)
    leaveFront(pid)
  }

  // MARK: Opening windows

  /// `content` is in AppKit's coordinates (y up, from the bottom of the screen), as the real app gives it.
  private func openWindow(
    of pid: Int32, title: String, content: CGRect, minimum: CGSize? = nil, maximum: CGSize? = nil,
    kind: String = "window", takesKeyboard: Bool = false
  ) throws -> UInt32 {
    guard let app = apps[pid] else { throw AppRefusal("no such app") }
    func frame(titleBar: CGFloat) -> CGRect {
      let height = content.height + titleBar
      // AppKit keeps a new window's title bar from hiding under the menu bar.
      let y = max(display.frame.height - content.minY - height, display.visibleFrame.minY)
      return CGRect(x: content.minX, y: y, width: content.width, height: height)
    }
    let id: UInt32
    if kind == "window" {
      // `FakeWindowSystem` gives every new window the keyboard, as apps do that open one in front of their
      // user. These are only ordered front; and what an app in the background does with its focus, the
      // Accessibility layer keeps to itself (`AXWindowSystem.reportFocus`).
      let usual = system.echoes.keyboard
      system.echoes.keyboard = usual && takesKeyboard && frontApp == pid
      defer { system.echoes.keyboard = usual }
      let window = system.open(
        app: app.name, bundleID: app.bundleID, title: title, pid: pid,
        frame: frame(titleBar: World.titleBarHeight),
        minimumSize: minimum ?? .zero)
      if let maximum { system.setMaximumSize(window, maximum) }
      id = window.rawValue
    } else if kind == "panel" {
      id = newExtraID()
      extras[id] = ExtraWindow(
        id: id, pid: pid, kind: .panel, frame: frame(titleBar: World.panelTitleBarHeight))
    } else if kind == "dialog" {
      id = newExtraID()
      extras[id] = ExtraWindow(id: id, pid: pid, kind: .dialog, frame: frame(titleBar: World.titleBarHeight))
    } else if kind.hasPrefix("sheet:") {
      let parent = try find(String(kind.dropFirst("sheet:".count)), of: pid)
      guard system.windows[WindowID(parent)] != nil else {
        throw AppRefusal("the rehearsal has sheets on windows only")
      }
      id = newExtraID()
      extras[id] = ExtraWindow(
        id: id, pid: pid, kind: .sheet(parent: WindowID(parent)), frame: frame(titleBar: 0))
    } else {
      throw AppRefusal("kind is window, panel or sheet:<id>, not \(kind)")
    }
    apps[pid]?.opened += 1
    counts[id] = ["down": 0, "up": 0, "dragged": 0, "key": 0, "magnify": 0]
    raise(.window(id))
    followKeyboard()
    return id
  }

  // MARK: Commands

  /// `app-request <pid> <line>`
  func appRequest(_ words: [String]) throws -> Reply {
    guard words.count == 2, let pid = Int32(words[0]) else {
      throw Refusal(message: "arbor-fakemac: usage: app-request <pid> <line>")
    }
    let request = words[1].trimmingCharacters(in: .whitespaces)
    guard !request.isEmpty, apps[pid] != nil else { return Reply() }
    do {
      let answer = try perform(request, of: pid)
      return answer.isEmpty ? Reply() : .printing(answer)
    } catch let refusal as AppRefusal {
      return .printing("{\"error\":\"\(refusal.reason.replacingOccurrences(of: "\"", with: "'"))\"}")
    }
  }

  private func find(_ word: String?, of pid: Int32) throws -> UInt32 {
    guard let word, let number = UInt32(word) else { throw AppRefusal("expected a window id") }
    guard owner(of: number) == pid || tabGroups.contains(where: { $0.pid == pid && $0.behind.contains(number) })
    else { throw AppRefusal("no window \(number)") }
    return number
  }

  /// Words 2 to 5 as a frame.
  private func frame(_ words: [String], usage: String) throws -> CGRect {
    let numbers = words.dropFirst(2).prefix(4).compactMap { Double($0) }
    guard numbers.count == 4 else { throw AppRefusal("usage: \(usage)") }
    return CGRect(x: numbers[0], y: numbers[1], width: numbers[2], height: numbers[3])
  }

  /// Carries out one command and returns the line it prints, if any.
  private func perform(_ request: String, of pid: Int32) throws -> String {
    let words = request.split(separator: " ").map(String.init)
    let verb = words[0]
    switch verb {
    // What the stand-in writes when it catches one of the two signals the real app listens for.
    case "SIGUSR1":
      switchTo(app: pid)
      return ""
    case "SIGUSR2":
      // `openWindows` for one more window, then `makeKeyAndOrderFront`.
      _ = try openWindow(of: pid, title: "Arbor Test 1", content: initialContent(1), takesKeyboard: true)
      return ""
    case "ping":
      guard words.count == 2 else { throw AppRefusal("usage: ping <token>") }
      return "{\"pong\":\(words[1])}"
    case "open":
      return try openRequested(request, of: pid)
    case "hide":
      hideApp(pid)
      return ""
    case "unhide":
      // `unhideWithoutActivation`
      apps[pid]?.hidden = false
      system.setHidden(pid: pid, false)
      followKeyboard()
      return ""
    case "activate" where words.count == 1:
      switchTo(app: pid)
      return ""
    case "hang":
      guard words.count == 2, let seconds = Double(words[1]) else { throw AppRefusal("usage: hang <seconds>") }
      hungUntil[pid] = elapsed + min(max(seconds, 0), 60)
      system.setUnresponsive(pid: pid, true)
      return ""
    case "list":
      let listed = windowIDs(of: pid).filter { id in
        isOnScreen(id)
          || (system.windows[WindowID(id)]?.snapshot.isMinimized == true && apps[pid]?.hidden == false)
      }
      return "{\"windows\":[\(listed.map(String.init).joined(separator: ","))]}"
    default:
      break
    }

    let known = [
      "minimize", "restore", "close", "key", "move", "insist", "relent", "min-size", "tab", "dialog", "select",
      "full-screen", "front", "activate", "title", "events",
    ]
    guard known.contains(verb) else { throw AppRefusal("unknown command \(verb)") }
    let id = try find(words.count > 1 ? words[1] : nil, of: pid)
    let window = WindowID(id)
    let isStandard = system.windows[window] != nil
    func standardOnly() throws {
      guard isStandard else { throw AppRefusal("the rehearsal can \(verb) ordinary windows in front only") }
    }
    switch verb {
    case "close":
      guard owner(of: id) != nil else {
        throw AppRefusal("the rehearsal cannot close a tab that is not in front")
      }
      closeWindow(id)
    case "minimize":
      try standardOnly()
      minimizeWindow(window)
    case "restore":
      try standardOnly()
      system.setMinimized(window, false)
      raise(.window(id))
      followKeyboard()
    case "key", "activate":
      guard owner(of: id) != nil else {
        throw AppRefusal("the rehearsal cannot \(verb) a tab that is not in front")
      }
      if verb == "activate" {
        bringForward(app: pid)
        raiseAll(of: pid)
      }
      raise(.window(id))
      apps[pid]?.focused = id
      // In the background the app's focused window changes and nobody is told.
      guard frontApp == pid else { break }
      if isStandard { giveKeyboard(to: window) } else { takeKeyboard(extra: id) }
    case "front":
      raise(.window(id))
    case "move":
      let frame = try frame(words, usage: "move <id> <x> <y> <w> <h>")
      if isStandard { system.userMove(window, to: frame) } else { extras[id]?.frame = frame }
    case "insist":
      try standardOnly()
      // Quick or slow, it has happened by the time a quarter of a second is over.
      guard words.count == 6 || (words.count == 7 && words[6] == "quick") else {
        throw AppRefusal("usage: insist <id> <x> <y> <w> <h> [quick]")
      }
      let frame = try frame(words, usage: "insist <id> <x> <y> <w> <h> [quick]")
      system.stubbornFrames[window] = frame
      system.userMove(window, to: frame)
    case "relent":
      system.stubbornFrames[window] = nil
    case "min-size":
      let numbers = words.dropFirst(2).compactMap { Double($0) }
      guard numbers.count == 2, words.count == 4 else { throw AppRefusal("usage: min-size <id> <w> <h>") }
      system.setMinimumSize(window, CGSize(width: numbers[0], height: numbers[1]))
    case "tab":
      try standardOnly()
      let title = (system.windows[window]?.snapshot.title ?? "") + ", tab \(windowIDs(of: pid).count)"
      guard let tab = system.openTab(in: window, title: title) else { throw AppRefusal("no window \(id)") }
      if let index = tabGroups.firstIndex(where: { $0.front == id }) {
        tabGroups[index].behind.append(id)
        tabGroups[index].front = tab.rawValue
      } else {
        tabGroups.append(TabGroup(pid: pid, front: tab.rawValue, behind: [id]))
      }
      replace(id, by: tab.rawValue)
      apps[pid]?.opened += 1
      followKeyboard()
      return "{\"window\":\(tab.rawValue)}"
    case "select":
      guard let index = tabGroups.firstIndex(where: { $0.behind.contains(id) }) else {
        if tabGroups.contains(where: { $0.front == id }) { break }
        throw AppRefusal("window \(id) is no tab")
      }
      let front = tabGroups[index].front
      system.selectTab(window, insteadOf: WindowID(front))
      tabGroups[index].behind.removeAll { $0 == id }
      tabGroups[index].behind.append(front)
      tabGroups[index].front = id
      replace(front, by: id)
      followKeyboard()
    case "dialog":
      guard let around = self.frame(of: id) else { throw AppRefusal("no window \(id)") }
      // Centred over the window, wherever that is.
      let content = CGRect(
        x: around.midX - 130, y: display.frame.height - around.midY - 60, width: 260, height: 120)
      let dialog = try openWindow(of: pid, title: "Dialog", content: content, kind: "dialog")
      bringIntoViewIfStray(dialog, of: pid)
      return "{\"window\":\(dialog)}"
    case "full-screen":
      // A Space of its own, an animation, and Accessibility's view of both: nothing here could say anything
      // true.
      throw AppRefusal("the rehearsal has no full screen")
    case "title":
      let parts = request.split(separator: " ", maxSplits: 2, omittingEmptySubsequences: true)
      system.setTitle(window, parts.count > 2 ? String(parts[2]) : "")
    case "events":
      let fields = (counts[id] ?? [:]).sorted { $0.key < $1.key }.map { "\"\($0.key)\":\($0.value)" }
      return "{\(fields.joined(separator: ","))}"
    default:
      break
    }
    return ""
  }

  /// Another tab of the group shows where `old` did.
  private func replace(_ old: UInt32, by new: UInt32) {
    if let index = order.firstIndex(of: .window(old)) {
      order[index] = .window(new)
    } else {
      raise(.window(new))
    }
    if counts[new] == nil { counts[new] = ["down": 0, "up": 0, "dragged": 0, "key": 0, "magnify": 0] }
    for pid in apps.keys where apps[pid]?.focused == old { apps[pid]?.focused = new }
  }

  /// `AXWindowSystem.bringIntoViewIfDialog` (F47)
  private func bringIntoViewIfStray(_ id: UInt32, of pid: Int32) {
    guard arbor?.controller.isRunning == true, let app = apps[pid], let frame = extras[id]?.frame,
      let home = StrayDialog.home(
        for: frame,
        siblings: system.windows.values.filter { $0.snapshot.pid == pid }.sorted {
          $0.snapshot.id < $1.snapshot.id
        }
        .map(\.snapshot.frame),
        displays: [StrayDialog.Display(frame: display.frame, visibleFrame: display.visibleFrame)])
    else { return }
    Log.info(
      "\(WindowID(id)), a dialog of \(app.bundleID), opened out of view; moving it to the middle of the display"
    )
    extras[id]?.frame.origin = home
  }

  /// `open [size=WxH] [min=WxH] [max=WxH] [at=X,Y] [kind=window|panel|sheet:<id>] [title=the rest of the line]`
  private func openRequested(_ request: String, of pid: Int32) throws -> String {
    let opened = apps[pid]?.opened ?? 0
    var size = CGSize(width: 480, height: 320)
    var minimum: CGSize?
    var maximum: CGSize?
    var origin: CGPoint?
    var kind = "window"
    var title = "Arbor Test \(opened + 1)"
    var options = String(request.dropFirst("open".count))
    // `title=` takes the rest of the line, so it is taken off first.
    if let range = options.range(of: "title=") {
      title = String(options[range.upperBound...])
      options = String(options[..<range.lowerBound])
    }
    for word in options.split(separator: " ").map(String.init) {
      let parts = word.split(separator: "=", maxSplits: 1).map(String.init)
      guard parts.count == 2 else { throw AppRefusal("expected name=value, got \(word)") }
      switch parts[0] {
      case "size":
        guard let value = parseSize(parts[1]) else { throw AppRefusal("size=WxH") }
        size = value
      case "min":
        guard let value = parseSize(parts[1]) else { throw AppRefusal("min=WxH") }
        minimum = value
      case "max":
        guard let value = parseSize(parts[1]) else { throw AppRefusal("max=WxH") }
        maximum = value
      case "at":
        let numbers = parts[1].split(separator: ",").compactMap { Double($0) }
        guard numbers.count == 2 else { throw AppRefusal("at=X,Y") }
        origin = CGPoint(x: numbers[0], y: numbers[1])
      case "kind":
        guard parts[1] != "dialog" else { throw AppRefusal("kind is window, panel or sheet:<id>, not dialog") }
        kind = parts[1]
      default:
        throw AppRefusal("unknown option \(parts[0])")
      }
    }
    var content = CGRect(
      x: CGFloat(140 + opened * 30), y: CGFloat(200 + opened * 20), width: size.width, height: size.height)
    if let origin {
      // `at` is where the window's frame goes, title bar included. The real app opens the window and then moves
      // it, in one turn of its run loop; Arbor reads the frame after that.
      let titleBar = kind == "window" ? World.titleBarHeight : kind == "panel" ? World.panelTitleBarHeight : 0
      content.origin = CGPoint(x: origin.x, y: display.frame.height - origin.y - size.height - titleBar)
    }
    let id = try openWindow(
      of: pid, title: title, content: content, minimum: minimum, maximum: maximum, kind: kind)
    return "{\"window\":\(id)}"
  }
}
