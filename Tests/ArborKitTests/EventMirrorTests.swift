import ArborCore
import ArborKit
import ArborTesting
import CoreGraphics
import Foundation
import Testing

/// What docs/SCRIPTING.md tells a script to do with the events, done: start from `hello`, keep the last line per window and per
/// display, forget what is said to be gone.
private struct Mirror {
  var state: ArborEvent.Summary

  mutating func take(_ event: ArborEvent) {
    switch event {
    case .hello(let hello):
      state = hello.snapshot
    case .displays(let displays):
      state.displays = displays
      // "Forget what you knew about a display that is no longer listed."
      let listed = Set(displays.map(\.display))
      state.layouts.removeAll { !listed.contains($0.display) }
      state.views.removeAll { !listed.contains($0.display) }
    case .window(let change):
      state.windows.removeAll { $0.id == change.window.id }
      state.notArranged.removeAll { $0 == change.window.id }
      switch change.change {
      case .closed: break
      case .released: state.notArranged.append(change.window.id)
      default: state.windows.append(change.window)
      }
    case .layout(let layout):
      state.layouts.removeAll { $0.display == layout.display }
      state.layouts.append(layout)
    case .view(let view):
      state.views.removeAll { $0.display == view.display }
      state.views.append(view)
    case .focus(let focus):
      state.focus = focus
    case .paused:
      state = ArborEvent.Summary(running: false, accessibility: state.accessibility)
      state.paused = true
    case .started, .resumed:
      state.running = true
      state.paused = false
    case .settings, .quitting:
      break
    }
  }

  /// In the order `hello` lists things, which a script that keeps dictionaries does not care about.
  var inOrder: ArborEvent.Summary {
    var copy = state
    let place = Dictionary(uniqueKeysWithValues: copy.displays.enumerated().map { ($0.element.display, $0.offset) })
    copy.windows.sort { $0.id < $1.id }
    copy.layouts.sort { (place[$0.display] ?? 99) < (place[$1.display] ?? 99) }
    copy.views.sort { (place[$0.display] ?? 99) < (place[$1.display] ?? 99) }
    // Windows that open or close while Arbor leaves them alone are nobody's event: `hello` has them, the stream does not.
    copy.notArranged = []
    return copy
  }
}

private struct Dice {
  var state: UInt64

  mutating func next() -> UInt64 {
    state &+= 0x9E37_79B9_7F4A_7C15
    var z = state
    z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
    z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
    return z ^ (z >> 31)
  }

  mutating func roll(_ sides: Int) -> Int { Int(next() % UInt64(max(sides, 1))) }
  mutating func pick<Element>(_ list: [Element]) -> Element? { list.isEmpty ? nil : list[roll(list.count)] }
}

/// The promise behind `arborctl watch`: whoever follows the events knows what a newcomer is told.
@Suite @MainActor struct EventMirrorTests {
  static let side = DisplaySnapshot(
    id: DisplayID("side"), frame: CGRect(x: 1440, y: 0, width: 1920, height: 1080),
    visibleFrame: CGRect(x: 1440, y: 0, width: 1920, height: 1080), isMain: false, name: "Side Display")

  /// One thing a person, an app or a script does. Returns what it was, for the message of a failure.
  fileprivate func act(_ h: Harness, _ dice: inout Dice) -> String {
    let windows = h.system.allWindows().map(\.id).sorted()
    let window = dice.pick(windows)?.rawValue ?? 0
    let other = dice.pick(windows)?.rawValue ?? 0
    let edge = dice.pick(["left", "right", "top", "bottom"])!
    let apps = ["Safari", "Mail", "Notes", "Terminal", "Xcode"]
    func run(_ text: String) -> String {
      h.run(text)
      return text
    }
    switch dice.roll(44) {
    case 0, 1:
      guard windows.count < 9 else { return run("show-all") }
      let app = dice.pick(apps)!
      let x = CGFloat(dice.roll(h.system.displays().count > 1 ? 2800 : 900))
      h.system.open(app: app, frame: CGRect(x: x, y: CGFloat(60 + dice.roll(300)), width: 500, height: 400))
      return "open \(app) at \(x)"
    case 2:
      guard let id = dice.pick(windows) else { return "nothing" }
      h.system.close(id)
      return "close \(id)"
    case 3, 4, 5: return run("dock \(window) \(edge)")
    case 6: return run("dock \(window) beside \(other) \(edge)")
    case 7: return run("float \(window)")
    case 8, 9: return run("zoom \(window)")
    case 10: return run("out")
    case 11: return run("in")
    case 12: return run("show-all")
    case 13: return run("back")
    case 14: return run("forward")
    case 15: return run("desktop")
    case 16: return run("neighbor \(edge == "top" ? "up" : edge == "bottom" ? "down" : edge)")
    case 17: return run("arrange")
    case 18: return run("float-all")
    case 19: return run("toggle-pin \(window)")
    case 20: return run("summon \(dice.pick(apps)!)")
    case 21: return run("name Space\(dice.roll(3))")
    case 22: return run("unname")
    case 23: return run("save-view \(1 + dice.roll(3))")
    case 24: return run("view \(1 + dice.roll(3))")
    case 25: return run("home")
    case 26: return run(h.controller.isPaused ? "resume" : "pause")
    case 27: return run("exclude com.example.\(dice.pick(apps)!.lowercased())")
    case 28: return run("include com.example.\(dice.pick(apps)!.lowercased())")
    case 29: return run("set gap \(4 + dice.roll(30))")
    case 30: return run("resize \(window) \(edge) \(dice.roll(200) - 100)")
    case 31:
      guard let id = dice.pick(windows), let snapshot = h.system.allWindows().first(where: { $0.id == id }) else { return "nothing" }
      h.system.setMinimized(id, !snapshot.isMinimized)
      return "minimize or restore \(id)"
    case 32:
      guard let snapshot = dice.pick(h.system.allWindows()) else { return "nothing" }
      h.system.setHidden(pid: snapshot.pid, !snapshot.isHidden)
      return "hide or show pid \(snapshot.pid)"
    case 33:
      guard let snapshot = dice.pick(h.system.allWindows()) else { return "nothing" }
      // The whole way, as a Mac goes it: the window gets a Space of its own, and the others of its display are not on it. The report
      // alone, with the others still to be clicked on, is a story no Mac tells.
      let display = h.system.displays().first { $0.frame.contains(snapshot.frame.center) }?.frame ?? .zero
      let others = h.system.allWindows().filter { $0.id != snapshot.id && !$0.isFullScreen && display.contains($0.frame.center) }.map(\.id)
      if snapshot.isFullScreen { h.system.leaveFullScreen(snapshot.id, with: others) } else { h.system.enterFullScreen(snapshot.id, leaving: others) }
      return "full screen on or off \(snapshot.id)"
    case 34:
      guard let snapshot = dice.pick(h.system.allWindows()) else { return "nothing" }
      h.system.setOnActiveSpace(snapshot.id, !snapshot.isOnActiveSpace)
      return "another Space, or back \(snapshot.id)"
    case 35, 36:
      guard let id = dice.pick(windows) else { return "nothing" }
      h.system.userFocus(id)
      return "click \(id)"
    case 37:
      h.system.userFocusesNothing()
      return "click the wallpaper"
    case 38:
      guard let id = dice.pick(windows) else { return "nothing" }
      h.system.setTitle(id, "Title \(dice.roll(5))")
      return "a new title for \(id)"
    case 39:
      let two = h.system.displays().count > 1
      h.system.setDisplays(two ? [FakeWindowSystem.standardDisplay] : [FakeWindowSystem.standardDisplay, Self.side])
      return two ? "unplug" : "plug in"
    case 40:
      guard let id = dice.pick(windows), let frame = h.frame(id) else { return "nothing" }
      let wide = h.system.displays().count > 1 ? 3300 : 1400
      let point = CGPoint(x: CGFloat(20 + dice.roll(wide)), y: CGFloat(40 + dice.roll(800)))
      h.system.drag(id, through: [CGPoint(x: frame.midX, y: frame.minY + 10), frame.center, point])
      return "drag \(id) to \(point)"
    case 41:
      guard let snapshot = dice.pick(h.system.allWindows()) else { return "nothing" }
      h.system.quit(pid: snapshot.pid)
      return "quit pid \(snapshot.pid)"
    case 42:
      guard let id = dice.pick(windows) else { return "nothing" }
      h.system.backgroundFocus(id)
      return "a report from the background, \(id)"
    default:
      h.scheduler.advance(by: Double(dice.roll(30)) / 10)
      return "time passes"
    }
  }

  @Test(arguments: 1...40)
  func whoeverFollowsTheEventsKnowsWhatANewcomerIsTold(seed: Int) throws {
    var dice = Dice(state: UInt64(seed))
    let h = Harness()
    for app in ["Safari", "Mail", "Notes"] {
      h.system.open(app: app, frame: CGRect(x: 100 + CGFloat(dice.roll(600)), y: 100, width: 500, height: 400))
    }
    h.start()
    let feed = EventFeed(controller: h.controller)
    let titles = seed.isMultiple(of: 2)
    let options = WatchOptions(titles: titles)
    var lines: [String] = []
    _ = feed.subscribe(options) { lines.append($0) }
    var mirror = Mirror(state: ArborEvent.Summary(running: false, accessibility: true))
    var history: [String] = []

    for step in 1...150 {
      history.append(act(h, &dice))
      // Long enough for whatever the controller puts off, and for the feed's second look at the keyboard.
      h.scheduler.advance(by: 3)
      for line in lines { mirror.take(try ArborEvent(line: line)) }
      lines.removeAll()

      var told: ArborEvent.Summary?
      let newcomer = feed.subscribe(options) { line in
        if case .hello(let hello)? = try? ArborEvent(line: line) { told = hello.snapshot }
      }
      if let newcomer { feed.unsubscribe(newcomer) }
      // The newcomer's arrival makes the feed look again; what it saw then is news for the old hand as well.
      for line in lines { mirror.take(try ArborEvent(line: line)) }
      lines.removeAll()
      var expected = try #require(told)
      expected.notArranged = []
      guard mirror.inOrder == expected else {
        Issue.record(
          """
          seed \(seed), step \(step): after \(history.suffix(6).joined(separator: "; "))
          followed: \(ArborEvent.hello(ArborEvent.Hello(version: "", snapshot: mirror.inOrder)).line)
          told:     \(ArborEvent.hello(ArborEvent.Hello(version: "", snapshot: expected)).line)
          """)
        return
      }
    }
  }

  /// What a script could trip over in what it has been told so far, or nil. Every batch of lines must leave it with a picture that
  /// agrees with itself: a status bar draws after every line.
  fileprivate func contradiction(in state: ArborEvent.Summary) -> String? {
    guard state.running else { return nil }
    let windows = Dictionary(uniqueKeysWithValues: state.windows.map { ($0.id, $0) })
    for view in state.views {
      let here = state.windows.filter { $0.display == view.display }
      for id in view.windows {
        guard let window = windows[id] else { return "the view of \(view.display) shows \(id), which was never announced" }
        if window.display != view.display { return "the view of \(view.display) shows \(id), which is on \(window.display)" }
        if !window.docked || window.state != .inView { return "the view of \(view.display) shows \(id), which is \(window.docked ? "docked" : "floating") and \(window.state.rawValue)" }
      }
      if view.apps != view.windows.map({ windows[$0]?.app ?? "?" }) { return "apps and windows of the view of \(view.display) differ" }
      let outOfView = here.filter { $0.state == .outOfView }.count
      if view.outOfView != outOfView { return "the view of \(view.display) says \(view.outOfView) out of view, the windows say \(outOfView)" }
      if view.label.isEmpty || view.label.wholeMatch(of: /n[0-9]+/) != nil { return "the label of \(view.display) is \"\(view.label)\"" }
      // Not the other way round: with every docked window minimized or hidden, the Desktop is all there is to see.
      if view.kind == .everything, view.depth != 0 { return "\(view.display): everything at depth \(view.depth)" }
      if view.depth == 0, view.outOfView > 0, !here.contains(where: { $0.state == .outOfView && !$0.docked }) {
        return "\(view.display): \(view.outOfView) docked out of view, and no step out"
      }
    }
    for layout in state.layouts {
      let here = state.windows.filter { $0.display == layout.display }
      if layout.docked != here.filter(\.docked).count { return "\(layout.display): dockedCount \(layout.docked), the windows say \(here.filter(\.docked).count)" }
      if layout.floating != here.filter({ !$0.docked }).count { return "\(layout.display): floatingCount \(layout.floating), the windows say \(here.filter { !$0.docked }.count)" }
      for id in layout.frames.keys.sorted() where windows[id]?.state != .inView || windows[id]?.docked != true {
        return "\(layout.display): a frame for \(id), which is \(windows[id].map { "\($0.docked ? "docked" : "floating"), \($0.state.rawValue)" } ?? "unknown")"
      }
      let framed = Set(layout.frames.keys)
      let shown = Set(state.views.first { $0.display == layout.display }?.windows ?? [])
      if framed != shown { return "\(layout.display): frames for \(framed.sorted()), the view shows \(shown.sorted())" }
    }
    if Set(state.layouts.map(\.display)) != Set(state.displays.map(\.display)) { return "layouts and displays differ" }
    if Set(state.views.map(\.display)) != Set(state.displays.map(\.display)) { return "views and displays differ" }
    if let id = state.focus.window, let display = state.focus.display, windows[id]?.display != display {
      return "the focus is on \(id) on \(display), the window says \(windows[id].map { "\($0.display)" } ?? "nothing")"
    }
    return nil
  }

  /// The same journeys, looked at whenever the main loop comes round and at every tenth of a second after it.
  @Test(arguments: 1...40)
  func whatHasBeenSaidSoFarNeverContradictsItself(seed: Int) throws {
    var dice = Dice(state: UInt64(seed) &* 7919)
    let h = Harness()
    for app in ["Safari", "Mail", "Notes"] {
      h.system.open(app: app, frame: CGRect(x: 100 + CGFloat(dice.roll(600)), y: 100, width: 500, height: 400))
    }
    h.start()
    let feed = EventFeed(controller: h.controller)
    var lines: [String] = []
    _ = feed.subscribe(WatchOptions()) { lines.append($0) }
    var mirror = Mirror(state: ArborEvent.Summary(running: false, accessibility: true))
    var history: [String] = []
    for step in 1...150 {
      history.append(act(h, &dice))
      for tick in 0..<8 {
        h.scheduler.advance(by: tick == 0 ? 0 : 0.1)
        guard !lines.isEmpty else { continue }
        let batch = lines
        lines.removeAll()
        for line in batch { mirror.take(try ArborEvent(line: line)) }
        if let problem = contradiction(in: mirror.inOrder) {
          Issue.record(
            """
            seed \(seed), step \(step), \(Double(tick) / 10) s after \(history.suffix(5).joined(separator: "; ")): \(problem)
            \(batch.joined(separator: "\n"))
            """)
          return
        }
      }
    }
  }
}
