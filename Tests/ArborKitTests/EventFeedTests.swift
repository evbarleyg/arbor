import ArborCore
import ArborKit
import ArborTesting
import CoreGraphics
import Foundation
import Testing

/// A 1280×800 display to the right of the standard one.
private let side = DisplaySnapshot(
  id: DisplayID("side"), frame: CGRect(x: 1440, y: 0, width: 1280, height: 800),
  visibleFrame: CGRect(x: 1440, y: 0, width: 1280, height: 800), isMain: false)

/// A client of the feed: keeps the lines it is sent.
@MainActor
private final class Listener {
  private(set) var lines: [String] = []
  private(set) var subscription: Int?

  init(_ feed: EventFeed, _ request: String = "watch") throws {
    guard case .watch(let options) = try Command.parse(request) else { return }
    subscription = feed.subscribe(options) { [weak self] line in self?.lines.append(line) }
  }

  /// The events since the last call.
  func take() throws -> [ArborEvent] {
    defer { lines.removeAll() }
    return try lines.map { try ArborEvent(line: $0) }
  }

  /// The window changes among them.
  func takeChanges() throws -> [ArborEvent.WindowChange] {
    try take().compactMap { if case .window(let change) = $0 { change } else { nil } }
  }

  /// The last `view` event among them.
  func takeView() throws -> ArborEvent.View? {
    try take().compactMap { if case .view(let view) = $0 { view } else { nil } }.last
  }
}

/// The events of `arborctl watch` (docs/features/F24-events.md): the real controller and feed, with
/// the scheduler standing in for the main loop.
@Suite @MainActor struct EventFeedTests {
  /// Safari and Notes docked left and right of the Desktop, Mail floating, Notes focused, and a feed.
  func makeHarness(settings: Settings = Settings()) -> (Harness, EventFeed, WindowID, WindowID, WindowID) {
    let h = Harness(settings: settings)
    let a = h.system.open(app: "Safari", frame: CGRect(x: 100, y: 100, width: 600, height: 400))
    let b = h.system.open(app: "Notes", frame: CGRect(x: 300, y: 200, width: 600, height: 400))
    let c = h.system.open(app: "Mail", frame: CGRect(x: 600, y: 300, width: 300, height: 300))
    h.start()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) right")
    h.system.userFocus(b)
    h.controller.buildInfo = BuildInfo(version: "9.8.7", build: "214", commit: "47a2ba9")
    return (h, EventFeed(controller: h.controller), a, b, c)
  }

  /// The main loop comes round: work scheduled without delay runs, timers do not.
  func turn(_ h: Harness) { h.scheduler.advance(by: 0) }

  func leaf(_ h: Harness, _ window: WindowID) -> NodeID { h.workspace.tree.leaf(containing: window)! }

  // MARK: hello

  @Test func helloComesFirstAndCarriesTheWholeState() throws {
    let (h, feed, a, b, c) = makeHarness()
    let listener = try Listener(feed)
    let events = try listener.take()
    guard events.count == 1, case .hello(let hello) = events[0] else {
      Issue.record("expected hello alone, at once, got \(events)")
      return
    }
    #expect(hello.version == "9.8.7")
    #expect(hello.protocol == 1)
    let state = hello.snapshot
    #expect(state.running && state.accessibility && !state.paused)
    #expect(
      state.displays == [
        ArborEvent.Display(
          display: h.display, main: true, frame: CGRect(x: 0, y: 0, width: 1440, height: 900), builtIn: true)
      ])
    #expect(state.windows.map(\.id) == [a, b, c])
    #expect(state.windows.map(\.docked) == [true, true, false])
    #expect(state.windows.map(\.state) == [.inView, .inView, .inView])
    #expect(state.windows.map(\.bundleID) == ["com.example.safari", "com.example.notes", "com.example.mail"])
    #expect(state.notArranged.isEmpty)
    #expect(state.layouts == [
      ArborEvent.Arrangement(display: h.display, docked: 2, floating: 1, tiles: 0, frames: h.layout!.windowFrames)
    ])
    #expect(state.views == [
      ArborEvent.View(
        display: h.display, node: h.workspace.tree.root, kind: .everything, label: "everything", depth: 0, windows: [a, b],
        apps: ["Safari", "Notes"], outOfView: 0, canGoBack: false, canGoForward: false)
    ])
    #expect(state.focus == ArborEvent.Focus(window: b, app: "Notes", bundleID: "com.example.notes", display: h.display))
    turn(h)
    #expect(try listener.take().isEmpty, "hello said it all")
  }

  @Test func watchNeedsAConnectionThatStaysOpen() {
    let (h, _, _, _, _) = makeHarness()
    let result = h.run("watch view")
    #expect(!result.ok)
    #expect(result.message.contains("arborctl watch"))
  }

  // MARK: view

  @Test func aMoveOfTheViewSaysWhereItIsAndWhatIsInView() throws {
    let (h, feed, a, b, _) = makeHarness()
    let listener = try Listener(feed, "watch view")
    _ = try listener.take()

    h.run("zoom \(a.rawValue)")
    turn(h)
    #expect(try listener.take() == [
      .view(
        ArborEvent.View(
          display: h.display, node: leaf(h, a), kind: .window, label: "Safari", depth: 1, windows: [a], apps: ["Safari"],
          outOfView: 2, canGoBack: true, canGoForward: false))
    ])

    h.run("desktop")
    turn(h)
    #expect(try listener.take() == [
      .view(
        ArborEvent.View(
          display: h.display, node: h.workspace.tree.desktop, kind: .desktop, label: "the Desktop", depth: 1, windows: [],
          apps: [], outOfView: 2, canGoBack: true, canGoForward: false))
    ])

    h.run("back")
    h.run("back")
    turn(h)
    #expect(try listener.take() == [
      .view(
        ArborEvent.View(
          display: h.display, node: h.workspace.tree.root, kind: .everything, label: "everything", depth: 0, windows: [a, b],
          apps: ["Safari", "Notes"], outOfView: 0, canGoBack: false, canGoForward: true))
    ])
  }

  @Test func aSpaceOfSeveralWindowsIsAGroupNamedInWords() throws {
    let (h, feed, a, _, c) = makeHarness()
    h.run("dock \(c.rawValue) beside \(a.rawValue) bottom")
    let column = h.workspace.tree.parent(of: leaf(h, a))!
    let listener = try Listener(feed, "watch view")
    _ = try listener.take()
    h.run("zoom-node \(column.rawValue)")
    turn(h)
    let group = try #require(try listener.takeView())
    #expect(group.kind == .group)
    #expect(group.node == column)
    #expect(group.label == "Safari and Mail", "as replies say it, without the number")
    #expect(group.depth == 1)
    #expect(group.windows == [a, c], "in tree order")
    #expect(group.apps == ["Safari", "Mail"])
    #expect(group.outOfView == 1)

    h.run("zoom \(c.rawValue)")
    turn(h)
    let framed = try #require(try listener.takeView())
    #expect((framed.label, framed.depth, framed.outOfView) == ("Mail", 2, 2), "two steps out to everything")
  }

  @Test func theNameOfASpaceGoesToEveryWatcher() throws {
    let (h, feed, a, _, _) = makeHarness()
    h.run("zoom \(a.rawValue)")
    turn(h)
    let listener = try Listener(feed, "watch view")
    guard case .hello(let hello)? = try listener.take().first else { return }
    #expect(hello.snapshot.views[0].name == nil)
    #expect(h.run("name Reading").ok)
    turn(h)
    let named = try #require(try listener.takeView())
    #expect((named.name, named.label) == ("Reading", "Safari"), "what a person called it, and Arbor's own words")
    #expect(h.run("unname").ok)
    turn(h)
    #expect(try #require(try listener.takeView()).name == nil)
  }

  @Test func aSavedViewShowsItsNumberWhileTheViewIsThere() throws {
    let (h, feed, a, _, _) = makeHarness()
    h.run("zoom \(a.rawValue)")
    let listener = try Listener(feed, "watch view")
    _ = try listener.take()

    func savedView() throws -> Int?? {
      turn(h)
      return try listener.takeView().map(\.savedView)
    }
    h.run("save-view 4")
    #expect(try savedView() == .some(4), "saving a view is news about the place")
    h.run("save-view 2")
    #expect(try savedView() == .some(2), "the lowest number that leads here")
    h.run("show-all")
    #expect(try savedView() == .some(nil))
    h.run("view 4")
    #expect(try savedView() == .some(2))
  }

  @Test func theViewIsReportedWhereTheDisplayReallyIs() throws {
    let (h, feed, a, b, _) = makeHarness()
    h.run("zoom \(a.rawValue)")
    let listener = try Listener(feed, "watch view")
    _ = try listener.take()
    // With its only window minimized the space has nothing to show, so the display shows what is around it.
    h.system.setMinimized(a, true)
    turn(h)
    let view = try #require(try listener.takeView())
    #expect(view.node == h.layout!.camera)
    #expect(view.windows == [b])
  }

  @Test func aWindowLeavingTheViewIsNewsAboutTheView() throws {
    let (h, feed, a, b, _) = makeHarness()
    let listener = try Listener(feed, "watch view")
    _ = try listener.take()
    h.system.close(b)
    turn(h)
    let view = try #require(try listener.takeView())
    #expect(view.windows == [a])
    #expect(view.apps == ["Safari"])
  }

  @Test func backAndForwardAreOfferedOnlyWhenTheyWouldDoSomething() throws {
    let (h, feed, a, b, _) = makeHarness()
    h.run("zoom \(b.rawValue)")
    h.run("zoom \(a.rawValue)")
    let listener = try Listener(feed, "watch view")
    guard case .hello(let hello)? = try listener.take().first else { return }
    #expect(hello.snapshot.views[0].canGoBack)
    // Everything the history holds goes away: the window that was framed before, and with it the group around both.
    h.system.close(b)
    turn(h)
    _ = try listener.take()
    let offered = h.controller.eventSummary(focused: nil).views[0].canGoBack
    #expect(offered == h.run("back").ok, "what is offered is what works")
  }

  // MARK: Duplicates and bursts

  @Test func aRelayoutThatChangesNothingSendsNothing() throws {
    let (h, feed, a, _, _) = makeHarness()
    let listener = try Listener(feed)
    _ = try listener.take()
    h.run("relayout")
    h.run("show-all")
    h.run("reload-settings")
    h.system.userMove(a, to: h.frame(a)!)
    turn(h)
    h.scheduler.runPending()
    turn(h)
    #expect(try listener.take().isEmpty)
  }

  @Test func nothingIsSentUntilTheMainLoopComesRound() throws {
    let (h, feed, a, _, _) = makeHarness()
    let listener = try Listener(feed)
    _ = try listener.take()
    h.run("zoom \(a.rawValue)")
    #expect(listener.lines.isEmpty)
    turn(h)
    #expect(!listener.lines.isEmpty)
  }

  @Test func aBurstIsReportedAsTheDifferenceItMade() throws {
    let (h, feed, a, b, c) = makeHarness()
    let listener = try Listener(feed, "watch window layout view")
    _ = try listener.take()
    // There and back again, in one go: nobody could have seen it.
    h.run("zoom \(a.rawValue)")
    h.run("dock \(c.rawValue) top")
    h.run("float \(c.rawValue)")
    h.run("show-all")
    h.run("zoom \(b.rawValue)")
    turn(h)
    let events = try listener.take()
    #expect(events.map(\.kind) == [.window, .window, .layout, .view], "one layout and one view")
    let changes = events.compactMap { if case .window(let change) = $0 { change } else { nil } }
    #expect(changes.map(\.change) == [.state, .state], "nothing about docking the window that ended as it began")
    #expect(changes.map(\.window.id) == [a, c])
    #expect(changes.allSatisfy { $0.window.state == .outOfView })
    guard case .view(let view)? = events.last else { return }
    #expect(view.windows == [b])
  }

  @Test func draggingAGapReportsTheNewFrames() throws {
    let (h, feed, a, _, _) = makeHarness()
    let listener = try Listener(feed)
    _ = try listener.take()
    h.overlays.dragSeam(h.layout!.seams[0], by: 40)
    turn(h)
    let events = try listener.take()
    guard events.count == 1, case .layout(let layout) = events[0] else {
      Issue.record("expected one layout event, got \(events)")
      return
    }
    #expect(layout.frames == h.layout!.windowFrames.mapValues(ArborEvent.Rect.init))
    #expect(layout.frames[a] == h.frame(a).map(ArborEvent.Rect.init))
    #expect((layout.docked, layout.floating, layout.tiles) == (2, 1, 0))
  }

  @Test func whileNobodyWatchesNothingIsScheduled() throws {
    let (h, feed, a, _, _) = makeHarness()
    func scheduled() -> Bool { h.scheduler.pendingKeys.contains { $0.hasPrefix("events") } }
    h.scheduler.runPending()
    h.run("zoom \(a.rawValue)")
    #expect(!scheduled())
    let listener = try Listener(feed)
    h.run("back")
    #expect(scheduled())
    h.scheduler.runPending()
    feed.unsubscribe(listener.subscription!)
    h.run("zoom \(a.rawValue)")
    #expect(!scheduled())
  }

  @Test func aLateListenerStartsFromTheStateNowAndTheOthersMissNothing() throws {
    let (h, feed, a, _, _) = makeHarness()
    let early = try Listener(feed, "watch view")
    _ = try early.take()
    h.run("zoom \(a.rawValue)")
    // Before the main loop has come round.
    let late = try Listener(feed, "watch view")
    guard case .hello(let hello)? = try late.take().first else {
      Issue.record("no hello")
      return
    }
    #expect(hello.snapshot.views[0].windows == [a])
    #expect(try early.take().map(\.kind) == [.view])
    turn(h)
    #expect(try early.take().isEmpty && late.take().isEmpty, "nobody is told twice")
  }

  // MARK: Filters

  @Test func aFilterLetsThroughOnlyWhatWasAskedFor() throws {
    let (h, feed, a, _, c) = makeHarness()
    let all = try Listener(feed)
    let some = try Listener(feed, "watch focus window")
    _ = try (all.take(), some.take())
    h.run("zoom \(a.rawValue)")
    h.run("show-all")
    h.run("dock \(c.rawValue) top")
    h.system.userFocus(a)
    h.run("exclude com.example.nothing")
    turn(h)
    #expect(try all.take().map(\.kind) == [.settings, .window, .layout, .view, .focus])
    #expect(try some.take().map(\.kind) == [.window, .focus])
  }

  // MARK: focus and titles

  @Test func focusNamesTheWindowAndItsAppButNotItsTitle() throws {
    let (h, feed, a, _, c) = makeHarness()
    let listener = try Listener(feed, "watch focus")
    _ = try listener.take()
    h.system.userFocus(a)
    turn(h)
    #expect(try listener.take() == [
      .focus(ArborEvent.Focus(window: a, app: "Safari", bundleID: "com.example.safari", display: h.display))
    ])
    h.system.userFocus(a)
    turn(h)
    #expect(try listener.take().isEmpty, "the same window again is not news")
    h.system.userFocus(c)
    h.system.userFocus(a)
    h.system.userFocus(c)
    turn(h)
    #expect(try listener.take() == [
      .focus(ArborEvent.Focus(window: c, app: "Mail", bundleID: "com.example.mail", display: h.display))
    ])
  }

  @Test func aCommandThatMovesTheKeyboardIsReportedToo() throws {
    let (h, feed, a, _, _) = makeHarness()
    let listener = try Listener(feed, "watch focus")
    _ = try listener.take()
    h.run("zoom \(a.rawValue)")
    turn(h)
    guard case .focus(let focus)? = try listener.take().last else {
      Issue.record("no focus event")
      return
    }
    #expect(focus.window == a)
  }

  @Test func focusIsWhoHasTheKeyboardNotWhoReportedLast() throws {
    let (h, feed, a, b, c) = makeHarness()
    h.system.userFocus(a)
    let listener = try Listener(feed, "watch focus")
    _ = try listener.take()
    func window() throws -> WindowID?? {
      turn(h)
      guard case .focus(let focus)? = try listener.take().last else { return nil }
      return focus.window
    }
    // A chat window opened by a notification: its app's focused window changes, the keyboard stays.
    h.system.backgroundFocus(b)
    #expect(try window() == nil, "nothing to report")
    // ⌘Tab: the app's focused window stays the same, so no window reports anything, and the keyboard moves.
    h.system.userSwitchesApp(to: c)
    #expect(try window() == .some(c))
    // A click on the wallpaper.
    h.system.userFocusesNothing()
    #expect(try window() == .some(nil), "no window Arbor knows has it")
    h.system.userSwitchesApp(to: a)
    #expect(try window() == .some(a))
  }

  @Test func aReportThatComesBeforeTheSystemsAnswerIsLookedAtAgain() throws {
    let (h, feed, a, b, _) = makeHarness()
    h.system.userFocus(a)
    let listener = try Listener(feed, "watch focus")
    _ = try listener.take()
    // The report is in, and the system still says `a`.
    h.controller.windowFocused(b)
    turn(h)
    #expect(try listener.take().isEmpty)
    h.system.focused = b
    h.scheduler.advance(by: 0.2)
    #expect(try listener.take().isEmpty)
    h.scheduler.advance(by: 0.1)
    guard case .focus(let focus)? = try listener.take().last else {
      Issue.record("no focus event after the second look")
      return
    }
    #expect(focus.window == b)
  }

  @Test func aWindowArborDoesNotArrangeHasNoDisplay() throws {
    var settings = Settings()
    settings.excludedBundleIDs = ["com.example.mail"]
    let (h, feed, _, _, c) = makeHarness(settings: settings)
    let listener = try Listener(feed, "watch focus")
    guard case .hello(let hello)? = try listener.take().first else { return }
    #expect(hello.snapshot.notArranged == [c])
    #expect(!hello.snapshot.windows.contains { $0.id == c })
    h.system.userFocus(c)
    turn(h)
    #expect(try listener.take() == [.focus(ArborEvent.Focus(window: c, app: "Mail", bundleID: "com.example.mail"))])
  }

  @Test func titlesReachOnlyThoseWhoAskedForThem() throws {
    let h = Harness()
    let secret = "Resignation letter (draft)"
    let a = h.system.open(app: "Pages", title: secret)
    let b = h.system.open(app: "Notes", title: "Shopping")
    h.start()
    let feed = EventFeed(controller: h.controller)
    h.system.userFocus(b)
    let plain = try Listener(feed)
    let titled = try Listener(feed, "watch --titles")

    h.run("dock \(a.rawValue) left")
    h.system.userFocus(a)
    turn(h)
    let later = h.system.open(app: "Pages", title: secret + " 2")
    turn(h)
    h.system.close(later)
    h.run("float \(a.rawValue)")
    turn(h)
    feed.stop()

    #expect(plain.lines.count > 8)
    for line in plain.lines {
      #expect(!line.contains("Resignation") && !line.contains("Shopping") && !line.contains("title"), "\(line)")
    }
    #expect(titled.lines.filter { $0.contains(secret) }.count >= 5, "hello, docked, focus, opened, closed, floated")
    #expect(try titled.take().map(\.kind) == plain.take().map(\.kind), "otherwise the two hear the same")
  }

  @Test func aNewTitleIsNewsOnlyWithTitles() throws {
    let (h, feed, a, b, _) = makeHarness()
    h.system.userFocus(a)
    let plain = try Listener(feed)
    let titled = try Listener(feed, "watch --titles")
    _ = try (plain.take(), titled.take())

    func retitle(_ window: WindowID, _ title: String) {
      var snapshot = h.controller.windows[window]!
      snapshot.title = title
      h.controller.windowChanged(snapshot, userInitiated: true)
    }
    retitle(a, "Swift.org")
    retitle(b, "Groceries")
    turn(h)
    #expect(try plain.take().isEmpty)
    let events = try titled.take()
    #expect(events.map(\.kind) == [.window, .window, .focus])
    guard case .window(let first) = events[0], case .focus(let focus) = events[2] else { return }
    #expect(first.change == .title)
    #expect(first.window.title == "Swift.org")
    #expect(focus.title == "Swift.org")
  }

  // MARK: windows

  @Test func windowsOpenDockFloatAndClose() throws {
    let (h, feed, _, _, _) = makeHarness()
    let listener = try Listener(feed, "watch window")
    _ = try listener.take()
    func changes() throws -> [ArborEvent.WindowChange] {
      turn(h)
      return try listener.takeChanges()
    }
    let d = h.system.open(app: "Terminal")
    func terminal(docked: Bool) -> ArborEvent.Window {
      ArborEvent.Window(id: d, app: "Terminal", bundleID: "com.example.terminal", display: h.display, docked: docked)
    }
    #expect(try changes() == [ArborEvent.WindowChange(.opened, terminal(docked: false))])
    h.run("dock \(d.rawValue) bottom")
    #expect(try changes() == [ArborEvent.WindowChange(.docked, terminal(docked: true))])
    h.run("float \(d.rawValue)")
    #expect(try changes() == [ArborEvent.WindowChange(.floated, terminal(docked: false))])
    h.run("dock \(d.rawValue) bottom")
    _ = try changes()
    h.system.close(d)
    #expect(try changes() == [ArborEvent.WindowChange(.closed, terminal(docked: true))], "its app is still known")
  }

  @Test func aWindowDockedByARuleIsReportedAsOpenedAndDocked() throws {
    var settings = Settings()
    settings.rules = [AppRule(app: "com.example.terminal", action: .dock(.right))]
    let (h, feed, _, _, _) = makeHarness(settings: settings)
    let listener = try Listener(feed, "watch window")
    _ = try listener.take()
    h.system.open(app: "Terminal")
    turn(h)
    #expect(try listener.takeChanges().map(\.change) == [.opened, .docked])
  }

  @Test func anAppThatIsNoLongerArrangedIsReleasedNotClosedAndLaterAdoptedNotOpened() throws {
    let (h, feed, a, _, _) = makeHarness()
    let listener = try Listener(feed, "watch window settings")
    _ = try listener.take()
    h.run("exclude com.example.safari")
    turn(h)
    var events = try listener.take()
    #expect(events.first == .settings(changed: ["excludedBundleIDs"]))
    guard events.count == 2, case .window(let released) = events[1] else {
      Issue.record("expected settings and released, got \(events)")
      return
    }
    #expect((released.change, released.window.id) == (.released, a), "the window is still there")
    h.run("include com.example.safari")
    turn(h)
    events = try listener.take()
    guard events.count == 2, case .window(let adopted) = events[1] else {
      Issue.record("expected settings and adopted, got \(events)")
      return
    }
    #expect((adopted.change, adopted.window.id, adopted.window.docked) == (.adopted, a, false))
  }

  @Test func arrangeAndFloatAllReportEveryWindow() throws {
    let (h, feed, a, b, c) = makeHarness()
    let listener = try Listener(feed, "watch window")
    _ = try listener.take()
    h.run("arrange")
    turn(h)
    #expect(try listener.takeChanges() == [
      ArborEvent.WindowChange(
        .docked, ArborEvent.Window(id: c, app: "Mail", bundleID: "com.example.mail", display: h.display, docked: true))
    ])
    h.run("float-all")
    turn(h)
    let floated = try listener.takeChanges()
    #expect(floated.map(\.change) == [.floated, .floated, .floated])
    #expect(floated.map(\.window.id) == [a, b, c])
  }

  @Test func aWindowsStateSaysWhereItIs() throws {
    let (h, feed, a, b, c) = makeHarness()
    let listener = try Listener(feed, "watch window layout")
    _ = try listener.take()
    func states() throws -> [WindowID: ArborEvent.Window.State] {
      turn(h)
      let changes = try listener.takeChanges()
      #expect(changes.allSatisfy { $0.change == .state })
      return Dictionary(uniqueKeysWithValues: changes.map { ($0.window.id, $0.window.state) })
    }
    h.run("zoom \(a.rawValue)")
    #expect(try states() == [b: .outOfView, c: .outOfView], "floating windows leave with the Desktop")
    h.run("show-all")
    #expect(try states() == [b: .inView, c: .inView])
    h.system.setMinimized(b, true)
    #expect(try states() == [b: .minimized])
    h.system.setMinimized(b, false)
    #expect(try states() == [b: .inView])
    h.system.setOnActiveSpace(c, false)
    h.scheduler.runPending()
    #expect(try states() == [c: .otherSpace])
    h.system.setOnActiveSpace(c, true)
    h.scheduler.runPending()
    #expect(try states() == [c: .inView])
    h.system.setFullScreen(c, true)
    h.scheduler.runPending()
    #expect(try states() == [c: .fullScreen], "which is also a Space of its own, but not what its user would say")
    h.system.setFullScreen(c, false)
    h.scheduler.runPending()
    #expect(try states() == [c: .inView])
    h.system.setHidden(pid: 1000, true)
    #expect(try states() == [a: .hidden, b: .hidden, c: .hidden])
  }

  /// macOS reports a switch of its Spaces window by window, and Arbor lays out when it has heard them all.
  @Test func aSwitchOfSpacesIsReportedOnceItHasBeenLaidOut() throws {
    let (h, feed, a, b, _) = makeHarness()
    h.run("zoom \(a.rawValue)")
    turn(h)
    let listener = try Listener(feed, "watch window layout view")
    _ = try listener.take()
    // The green button on Notes: it gets a Space to itself, and Safari is on the one that no longer shows.
    h.system.setFullScreen(b, true)
    h.system.setOnActiveSpace(a, false)
    h.scheduler.advance(by: 2)
    let events = try listener.take()
    let views = events.compactMap { if case .view(let view) = $0 { view } else { nil } }
    #expect(views.count == 1, "nothing about the moment in between: \(views)")
    #expect(views.last?.windows == [])
    #expect(events.filter { $0.kind == .layout }.count == 1)
  }

  @Test func whileALayoutIsPutOffTheFeedWaitsWithoutKeepingTheMainLoopBusy() throws {
    let (h, feed, a, b, _) = makeHarness()
    let listener = try Listener(feed, "watch window")
    _ = try listener.take()
    // Carried to another of macOS's Spaces: the layout waits for the drop.
    let grab = CGPoint(x: h.frame(b)!.midX, y: h.frame(b)!.minY + 10)
    h.system.mouseDown = true
    h.controller.dragBegan(b, at: grab)
    h.system.setOnActiveSpace(a, false)
    turn(h)
    #expect(try listener.take().isEmpty)
    h.scheduler.advance(by: 1)
    #expect(try listener.take().isEmpty, "still being dragged")
    h.system.mouseDown = false
    h.controller.dragEnded(b, at: grab)
    h.scheduler.advance(by: 1)
    #expect(try listener.takeChanges().contains { $0.window.id == a && $0.window.state == .otherSpace })
  }

  @Test func aSpaceOfWhichNothingCanBeSeenIsStillNamedInWords() throws {
    let (h, feed, a, _, _) = makeHarness()
    h.run("zoom \(a.rawValue)")
    let node = leaf(h, a)
    var snapshot = h.controller.windows[a]!
    snapshot.isOnActiveSpace = false
    // Between the report and the layout after it.
    h.controller.windowChanged(snapshot, userInitiated: false)
    let hello = try #require(try Listener(feed).take().first)
    guard case .hello(let state) = hello else { return }
    #expect(state.snapshot.views[0].node == node)
    #expect(state.snapshot.views[0].label == "Safari", "never a number alone")
  }

  @Test func aWindowTooSmallToUseIsATile() throws {
    let (h, feed, _, _, _) = makeHarness()
    let listener = try Listener(feed, "watch layout window")
    _ = try listener.take()
    let big = h.system.open(
      app: "Xcode", frame: CGRect(x: 400, y: 200, width: 900, height: 500), minimumSize: CGSize(width: 900, height: 500))
    h.run("dock \(big.rawValue) right")
    turn(h)
    let events = try listener.take()
    guard case .layout(let layout)? = events.last else {
      Issue.record("no layout event")
      return
    }
    #expect(layout.tiles == h.layout!.tiles.count)
    #expect(layout.tiles >= 1)
    #expect(layout.docked == 3)
    #expect(layout.frames[big] == nil, "a window a tile stands in for has no frame in view")
    let changes = events.compactMap { if case .window(let change) = $0, change.window.id == big { change } else { nil } }
    #expect(changes.last?.window.state == .tile)
  }

  // MARK: Displays

  @Test func eachDisplayReportsItsOwnViewAndLayout() throws {
    let h = Harness(displays: [FakeWindowSystem.standardDisplay, side])
    h.system.open(app: "Safari", frame: CGRect(x: 100, y: 100, width: 600, height: 400))
    let b = h.system.open(app: "Notes", frame: CGRect(x: 1600, y: 100, width: 600, height: 400))
    h.start()
    let feed = EventFeed(controller: h.controller)
    let listener = try Listener(feed, "watch window layout view")
    guard case .hello(let hello)? = try listener.take().first else { return }
    #expect(hello.snapshot.displays.map(\.display) == [h.display, side.id])
    #expect(hello.snapshot.displays.map(\.main) == [true, false])
    #expect(hello.snapshot.views.map(\.display) == [h.display, side.id])
    #expect(hello.snapshot.windows.map(\.display) == [h.display, side.id])

    h.run("dock \(b.rawValue) left")
    turn(h)
    let events = try listener.take()
    #expect(events.map(\.kind) == [.window, .layout, .view])
    for event in events {
      switch event {
      case .window(let change): #expect(change.window.display == side.id)
      case .layout(let layout): #expect(layout.display == side.id)
      case .view(let view): #expect(view.display == side.id)
      default: break
      }
    }
  }

  @Test func aFloatingWindowDraggedToAnotherDisplayIsReportedThere() throws {
    let h = Harness(displays: [FakeWindowSystem.standardDisplay, side])
    let a = h.system.open(app: "Safari", frame: CGRect(x: 100, y: 100, width: 600, height: 400))
    h.start()
    let feed = EventFeed(controller: h.controller)
    let listener = try Listener(feed, "watch window layout")
    _ = try listener.take()

    h.system.drag(a, through: [CGPoint(x: 400, y: 110), CGPoint(x: 1200, y: 300), CGPoint(x: 2000, y: 400)])
    turn(h)
    var events = try listener.take()
    #expect(events.map(\.kind) == [.window, .layout, .layout])
    guard case .window(let change)? = events.first else { return }
    #expect((change.change, change.window.display) == (.floated, side.id))

    // Moved back without a drag Arbor can see, as another tool or the app itself would.
    h.system.userMove(a, to: CGRect(x: 100, y: 100, width: 600, height: 400))
    turn(h)
    events = try listener.take()
    guard case .window(let back)? = events.first else {
      Issue.record("expected the window to be reported, got \(events)")
      return
    }
    #expect((back.change, back.window.display) == (.floated, h.display))
  }

  @Test func displaysComingAndGoingAreReported() throws {
    let h = Harness(displays: [FakeWindowSystem.standardDisplay, side])
    let b = h.system.open(app: "Notes", frame: CGRect(x: 1600, y: 100, width: 600, height: 400))
    h.start()
    h.system.cursor = CGPoint(x: 2000, y: 400)
    h.run("dock \(b.rawValue) left")
    let feed = EventFeed(controller: h.controller)
    let listener = try Listener(feed, "watch displays window layout view")
    _ = try listener.take()

    h.system.setDisplays([FakeWindowSystem.standardDisplay])
    turn(h)
    var events = try listener.take()
    #expect(events.map(\.kind) == [.displays, .window, .layout])
    guard case .displays(let one)? = events.first, case .window(let moved) = events[1] else { return }
    #expect(one.map(\.display) == [h.display])
    #expect((moved.change, moved.window.display) == (.floated, h.display))

    h.system.setDisplays([FakeWindowSystem.standardDisplay, side])
    turn(h)
    events = try listener.take()
    #expect(events.map(\.kind) == [.displays, .window, .layout, .layout, .view])
    guard case .displays(let two)? = events.first, case .window(let returned) = events[1] else { return }
    #expect(two.map(\.display) == [h.display, side.id])
    #expect((returned.change, returned.window.display) == (.docked, side.id))
  }

  // MARK: settings

  @Test func settingsAreNewsOnlyWhenTheyChangeAndSayWhichKeysDid() throws {
    let (h, feed, _, _, _) = makeHarness()
    var onDisk = h.controller.settings
    h.controller.loadSettings = { onDisk }
    let listener = try Listener(feed, "watch settings")
    _ = try listener.take()
    h.run("reload-settings")
    turn(h)
    #expect(try listener.take().isEmpty)
    onDisk.windowEdgeFraction = 0.4
    h.run("reload-settings")
    onDisk.gap = 20
    h.run("reload-settings")
    h.run("reload-settings")
    turn(h)
    #expect(try listener.take() == [.settings(changed: ["gap", "windowEdgeFraction"])])
  }

  // MARK: Starting, pausing and stopping

  @Test func aListenerFromBeforeArborStartsHearsStartedAndThenTheState() throws {
    let h = Harness()
    let a = h.system.open(app: "Safari")
    h.system.focus(a)
    h.controller.accessibilityGranted = false
    let feed = EventFeed(controller: h.controller)
    let listener = try Listener(feed)
    #expect(try listener.take() == [
      .hello(ArborEvent.Hello(version: "dev", snapshot: ArborEvent.Summary(running: false, accessibility: false)))
    ])

    h.controller.accessibilityGranted = true
    h.start()
    turn(h)
    let events = try listener.take()
    #expect(events.map(\.kind) == [.started, .displays, .window, .layout, .view, .focus])
    guard case .window(let change) = events[2], case .focus(let focus)? = events.last else { return }
    #expect(change.change == .adopted, "it was open before Arbor looked")
    #expect(focus.window == a, "whoever had the keyboard when Arbor started")
  }

  @Test func quittingComesFromTheAppOnceAndIsTheLastWord() throws {
    let (h, feed, a, _, _) = makeHarness()
    let all = try Listener(feed)
    let some = try Listener(feed, "watch focus")
    _ = try (all.take(), some.take())
    h.run("zoom \(a.rawValue)")
    // Quitting: the main loop never comes round again.
    h.controller.shutdown()
    #expect(try all.take().isEmpty, "that the controller stopped does not say that Arbor is quitting")
    feed.stop()
    #expect(try all.take() == [.quitting], "what was pending no longer matters: the windows are back where they belong")
    #expect(try some.take() == [.quitting], "whatever the filter")
    feed.stop()
    h.scheduler.runPending()
    #expect(try all.take().isEmpty && some.take().isEmpty)
    #expect(try Listener(feed).subscription == nil, "nobody joins a feed that has said goodbye")
  }

  @Test func quittingBeforeArborEverStartedStillSaysSo() throws {
    let h = Harness()
    h.controller.accessibilityGranted = false
    let feed = EventFeed(controller: h.controller)
    let listener = try Listener(feed, "watch view")
    _ = try listener.take()
    h.controller.shutdown()
    feed.stop()
    #expect(try listener.take() == [.quitting])
  }

  @Test func stopSendsWhatWasStillPendingFirst() throws {
    let (h, feed, a, _, _) = makeHarness()
    let listener = try Listener(feed, "watch view")
    _ = try listener.take()
    h.run("zoom \(a.rawValue)")
    feed.stop()
    #expect(try listener.take().map(\.kind) == [.view, .quitting])
  }

  @Test func aPauseSaysPausedAtOnceAndResumingBringsTheStateBack() throws {
    let (h, feed, a, b, c) = makeHarness()
    h.system.userFocus(a)
    let all = try Listener(feed)
    let some = try Listener(feed, "watch view")
    _ = try (all.take(), some.take())

    #expect(h.run("pause").ok)
    #expect(try all.take() == [.paused], "at once, and not `quitting`: Arbor is still there")
    #expect(try some.take() == [.paused], "whatever the filter: a status bar must not go on showing the view")
    turn(h)
    #expect(try all.take().isEmpty)
    guard case .hello(let hello)? = try Listener(feed).take().first else { return }
    #expect(hello.snapshot.paused && !hello.snapshot.running)
    #expect(hello.snapshot.windows.isEmpty, "Arbor is not looking")

    #expect(h.run("resume").ok)
    turn(h)
    let events = try all.take()
    #expect(events.map(\.kind) == [.resumed, .displays, .window, .window, .window, .window, .window, .layout, .view, .focus])
    let changes = events.compactMap { if case .window(let change) = $0 { change } else { nil } }
    #expect(changes.map(\.window.id) == [a, a, b, b, c])
    #expect(changes.map(\.change) == [.adopted, .docked, .adopted, .docked, .adopted], "nothing opened: they were there all along")
    #expect(try some.take().map(\.kind) == [.resumed, .view])

    feed.stop()
    #expect(try all.take() == [.quitting])
  }

  @Test func quittingDuringAPauseSaysSo() throws {
    let (h, feed, _, _, _) = makeHarness()
    let listener = try Listener(feed, "watch view")
    _ = try listener.take()
    h.run("pause")
    h.controller.shutdown()
    feed.stop()
    #expect(try listener.take() == [.paused, .quitting])
  }

  // MARK: Subscribers

  @Test func atMostSixteenCanWatch() throws {
    let (h, feed, a, _, _) = makeHarness()
    let listeners = try (0..<EventFeed.maximumSubscribers).map { _ in try Listener(feed, "watch view") }
    #expect(EventFeed.maximumSubscribers == 16)
    #expect(listeners.allSatisfy { $0.subscription != nil })
    #expect(!feed.hasRoom)
    let extra = try Listener(feed)
    #expect(extra.subscription == nil)
    #expect(extra.lines.isEmpty)

    feed.unsubscribe(listeners[3].subscription!)
    #expect(try Listener(feed).subscription != nil, "a place that is given up can be taken")
    h.run("zoom \(a.rawValue)")
    turn(h)
    #expect(listeners[3].lines.count == 1, "only its hello")
    #expect(listeners[4].lines.count == 2)
  }

  @Test func aSinkMayUnsubscribeFromInsideTheCall() throws {
    let (h, feed, a, _, _) = makeHarness()
    var heard: [String] = []
    var subscription: Int?
    subscription = feed.subscribe(WatchOptions()) { line in
      heard.append(line)
      // As the control socket does when it finds the client gone.
      if heard.count == 2, let subscription { feed.unsubscribe(subscription) }
    }
    let other = try Listener(feed, "watch layout view")
    _ = try other.take()
    h.run("zoom \(a.rawValue)")
    turn(h)
    #expect(heard.count == 2, "hello and the first event of the burst, then nothing")
    #expect(feed.subscriberCount == 1)
    #expect(try other.take().map(\.kind) == [.layout, .view], "the others are not disturbed")
  }
}
