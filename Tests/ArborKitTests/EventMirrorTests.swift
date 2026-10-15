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
    case .hold(let hold):
      state.hold = hold
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

/// The promise behind `arborctl watch`: whoever follows the events knows what a newcomer is told.
@Suite @MainActor struct EventMirrorTests {
  @Test(arguments: 1...40)
  func whoeverFollowsTheEventsKnowsWhatANewcomerIsTold(seed: Int) throws {
    var dice = RandomJourney.Dice(state: UInt64(seed))
    let h = Harness(settings: RandomJourney.settings)
    for app in ["Safari", "Mail", "Notes"] {
      h.system.open(app: app, pid: RandomJourney.pid(of: app), frame: CGRect(x: 100 + CGFloat(dice.roll(600)), y: 100, width: 500, height: 400))
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
      history.append(RandomJourney.step(h, &dice))
      // Long enough for whatever the controller puts off, and for the feed's second look at the keyboard.
      h.scheduler.advance(by: 3)
      for line in lines { mirror.take(try ArborEvent(line: line)) }
      lines.removeAll()

      var told: ArborEvent.Summary?
      let newcomer = feed.subscribe(options) { line in
        if case .hello(let hello)? = try? ArborEvent(line: line) { told = hello.snapshot }
      }
      if let newcomer { feed.unsubscribe(newcomer) }
      // The newcomer's arrival makes the feed look again; what it saw then is news for the old hand as well. Not about a hold:
      // the controller says when that changes, so it has been said.
      for line in lines {
        let event = try ArborEvent(line: line)
        if event.kind == .hold { Issue.record("seed \(seed), step \(step): after \(history.suffix(6).joined(separator: "; ")), late: \(line)") }
        mirror.take(event)
      }
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
      // A held view does not widen by itself: when its last window goes, the display shows the wallpaper until `release`.
      let heldEmpty = state.hold.level == .view && view.windows.isEmpty
      if !heldEmpty, view.depth == 0, view.outOfView > 0, !here.contains(where: { $0.state == .outOfView && !$0.docked }) {
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
    var dice = RandomJourney.Dice(state: UInt64(seed) &* 7919)
    let h = Harness(settings: RandomJourney.settings)
    for app in ["Safari", "Mail", "Notes"] {
      h.system.open(app: app, pid: RandomJourney.pid(of: app), frame: CGRect(x: 100 + CGFloat(dice.roll(600)), y: 100, width: 500, height: 400))
    }
    h.start()
    let feed = EventFeed(controller: h.controller)
    var lines: [String] = []
    _ = feed.subscribe(WatchOptions()) { lines.append($0) }
    var mirror = Mirror(state: ArborEvent.Summary(running: false, accessibility: true))
    var history: [String] = []
    for step in 1...150 {
      history.append(RandomJourney.step(h, &dice))
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
