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

/// The minimap (docs/features/F26-minimap.md): when it shows, what it holds, what a click does, when it goes.
@Suite @MainActor struct MinimapScenarioTests {
  /// Safari and Notes docked left and right of the Desktop, Mail floating. The passing minimap is on, unless `settings` say otherwise.
  func makeHarness(settings: Settings? = nil) -> (Harness, WindowID, WindowID, WindowID) {
    let h = Harness(settings: settings ?? passing)
    // Each app a process of its own: when a window closes, macOS gives the keyboard to another of the same app first.
    let a = h.system.open(app: "Safari", pid: 1001, frame: CGRect(x: 100, y: 100, width: 600, height: 400))
    let b = h.system.open(app: "Notes", pid: 1002, frame: CGRect(x: 300, y: 200, width: 600, height: 400))
    let c = h.system.open(app: "Mail", pid: 1003, frame: CGRect(x: 600, y: 300, width: 300, height: 300))
    h.start()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) right")
    return (h, a, b, c)
  }

  func map(_ h: Harness) -> MinimapModel? { h.overlays.minimaps[h.display] }
  func timers(_ h: Harness) -> [String] { h.scheduler.pendingKeys.filter { $0.hasPrefix("minimap") } }
  /// As it ships: only ⌃⌥M brings it up.
  var off: Settings { Settings() }
  var passing: Settings {
    var settings = Settings()
    settings.minimapDuration = 0.9
    return settings
  }

  // MARK: When it shows

  @Test func movingTheViewShowsTheMinimapForAMoment() throws {
    let (h, a, b, _) = makeHarness()
    #expect(h.overlays.minimapHistory.isEmpty, "docking from the widest view does not move it")
    h.run("zoom \(a.rawValue)")
    let model = try #require(map(h))
    #expect(model.items.map(\.window) == [a, b])
    #expect(model.items.map(\.bundleID) == ["com.example.safari", "com.example.notes"])
    #expect(model.items.map(\.isInView) == [true, false])
    #expect(model.highlight == model.items[0].frame)
    #expect(model.desktop != nil)
    #expect(model.caption == nil)
    #expect(!model.takesClicks)

    h.scheduler.advance(by: 0.89)
    #expect(map(h) != nil)
    h.scheduler.advance(by: 0.02)
    #expect(map(h) == nil, "gone after 0.9 s")
    #expect(timers(h).isEmpty)
  }

  /// [Safari / Xcode | Desktop | Notes], Mail floating: with a column, so that one level out is a group and not everything.
  func makeColumn(settings: Settings? = nil) -> (Harness, WindowID, WindowID, WindowID, WindowID) {
    let (h, a, b, c) = makeHarness(settings: settings)
    let d = h.system.open(app: "Xcode", pid: 1004, frame: CGRect(x: 200, y: 300, width: 500, height: 300))
    h.run("dock \(d.rawValue) beside \(a.rawValue) bottom")
    return (h, a, b, c, d)
  }

  @Test func everyWayOfMovingTheViewShowsIt() {
    let (h, a, b, _, d) = makeColumn()
    h.run("zoom \(b.rawValue)")
    h.run("save-view 1")
    h.run("show-all")
    h.system.cursor = h.frame(a)!.center
    let moves: [(String, () -> Void)] = [
      ("zoom", { h.run("zoom \(a.rawValue)") }), ("out", { h.run("out") }), ("in", { h.run("in") }),
      ("neighbor", { h.run("neighbor bottom") }), ("back", { h.run("back") }), ("forward", { h.run("forward") }),
      ("desktop", { h.run("desktop") }), ("view", { h.run("view 1") }),
      ("zoom-node", { h.run("zoom-node \(h.workspace.tree.leaf(containing: a)!.rawValue)") }),
      ("switching to a window that is out of view", { h.system.userFocus(d) }),
      ("a click on a tile, or anything else that goes that way", {
        h.overlays.clickTile(h.workspace.tree.leaf(containing: b)!)
      }),
    ]
    for (name, move) in moves {
      h.scheduler.advance(by: 5)
      #expect(map(h) == nil)
      let before = h.layout?.camera
      move()
      #expect(h.layout?.camera != before && h.layout?.camera != h.workspace.tree.root, "\(name) goes somewhere")
      #expect(map(h) != nil, "\(name)")
    }
  }

  @Test func framingARectangleShowsItToo() {
    let (h, a, _, _, _) = makeColumn()
    let frame = h.frame(a)!.insetBy(dx: 20, dy: 20)
    h.run("frame-rect \(Int(frame.minX)) \(Int(frame.minY)) \(Int(frame.width)) \(Int(frame.height))")
    #expect(h.workspace.camera == h.workspace.tree.leaf(containing: a))
    #expect(map(h) != nil)
  }

  /// Nobody announces these moves, and they are the ones that leave people lost.
  @Test func theViewMovingByItselfShowsItToo() throws {
    for (name, event) in [
      ("closing", { (h: Harness, a: WindowID) in h.system.close(a) }),
      ("minimizing", { h, a in h.system.setMinimized(a, true) }),
      ("hiding the app of", { h, _ in h.system.setHidden(pid: 1001, true) }),
    ] as [(String, (Harness, WindowID) -> Void)] {
      let (h, a, b, _, d) = makeColumn()
      h.run("zoom \(a.rawValue)")
      h.scheduler.advance(by: 5)
      #expect(map(h) == nil)
      event(h, a)
      let model = try #require(map(h), "\(name) the framed window")
      #expect(model.items.map(\.window) == [d, b], "\(name)")
      #expect(model.items.map(\.isInView) == [true, false], "\(name): the view is on what is left of the column")
    }
  }

  // MARK: Everything

  /// It would be a small picture of what is on screen.
  @Test func goingToEverythingShowsNoneAndTakesAwayTheOneThatIsUp() {
    for command in ["show-all", "home", "out"] {
      let (h, a, _, _) = makeHarness()
      h.run("zoom \(a.rawValue)")
      h.scheduler.advance(by: 5)
      let before = h.overlays.minimapHistory.count
      h.run(command)
      #expect(h.workspace.camera == h.workspace.tree.root)
      #expect(h.overlays.minimapHistory.count == before, "\(command)")

      h.run("zoom \(a.rawValue)")
      h.scheduler.advance(by: 0.3)
      #expect(map(h) != nil)
      h.run(command)
      #expect(map(h) == nil, "\(command): it marked a place the view has left")
      #expect(timers(h).isEmpty, "\(command)")
    }
  }

  @Test func theFramedWindowLeavingWithTheViewGoingToEverythingShowsNone() {
    for (name, event) in [
      ("closing", { (h: Harness, a: WindowID) in h.system.close(a) }),
      ("floating", { h, a in h.run("float \(a.rawValue)") }),
    ] as [(String, (Harness, WindowID) -> Void)] {
      let (h, a, _, _) = makeHarness()
      h.run("zoom \(a.rawValue)")
      h.scheduler.advance(by: 5)
      let before = h.overlays.minimapHistory.count
      event(h, a)
      #expect(h.layout?.camera == h.workspace.tree.root, "\(name)")
      #expect(h.overlays.minimapHistory.count == before, "\(name)")
    }
  }

  @Test func oneThatWasAskedForStaysWhenTheViewGoesToEverything() throws {
    let (h, a, _, _) = makeHarness()
    h.run("zoom \(a.rawValue)")
    h.run("minimap")
    h.run("show-all")
    let model = try #require(map(h))
    #expect(model.takesClicks)
    #expect(model.highlight == CGRect(origin: .zero, size: model.frame.size).insetBy(dx: 10, dy: 10), "the whole of it is marked")
    #expect(model.items.map(\.isInView) == [true, true] && model.desktopIsInView)
  }

  // MARK: macOS Spaces and full screen

  /// macOS changes what is there, and what fills the view changes with it. Nobody has gone anywhere in the arrangement.
  @Test func anotherMacOSSpaceOrFullScreenIsNotAMove() {
    let changes: [(String, (Harness, WindowID, Bool) -> Void)] = [
      ("another macOS Space", { h, window, away in h.system.setOnActiveSpace(window, !away) }),
      ("full screen", { h, window, away in h.system.setFullScreen(window, away) }),
    ]
    for (name, change) in changes {
      let (h, a, _, _, _) = makeColumn()
      h.run("zoom \(a.rawValue)")
      h.scheduler.advance(by: 5)
      let before = h.overlays.minimapHistory.count
      let framed = h.layout?.camera
      change(h, a, true)
      h.scheduler.advance(by: 3)
      #expect(h.layout?.camera != framed, "\(name): its surroundings show meanwhile")
      #expect(h.overlays.minimapHistory.count == before, "\(name), going")
      change(h, a, false)
      h.scheduler.advance(by: 3)
      #expect(h.overlays.minimapHistory.count == before, "\(name), coming back")
      h.run("desktop")
      #expect(map(h) != nil, "\(name): the next move of the view shows it as ever")
    }
  }

  @Test func withEveryDockedWindowOnAnotherSpaceTheCommandSaysSo() {
    let (h, a, b, _) = makeHarness()
    h.system.setOnActiveSpace(a, false)
    h.system.setOnActiveSpace(b, false)
    h.scheduler.advance(by: 3)
    let result = h.run("minimap")
    #expect(!result.ok)
    #expect(result.message.contains("on another macOS Space"))
  }

  @Test func dockingAtTheEdgeOfAFramedWindowWidensTheViewAndShowsWhere() throws {
    let (h, a, _, c) = makeHarness()
    h.run("zoom \(a.rawValue)")
    h.scheduler.advance(by: 5)
    h.run("dock \(c.rawValue) bottom")
    let model = try #require(map(h))
    #expect(model.items.filter(\.isInView).map(\.window) == [a, c])
  }

  @Test func aNewMoveReplacesTheMapAndStartsTheTimeAgain() throws {
    let (h, a, b, _) = makeHarness()
    h.run("zoom \(a.rawValue)")
    let first = try #require(map(h))
    h.scheduler.advance(by: 0.6)
    h.run("zoom \(b.rawValue)")
    let second = try #require(map(h))
    #expect(second.highlight == second.items[1].frame)
    #expect(second.highlight != first.highlight)
    #expect(second.frame == first.frame, "the panel stays where it is")
    h.scheduler.advance(by: 0.6)
    #expect(map(h) == second, "0.9 s from the second move, not the first")
    h.scheduler.advance(by: 0.4)
    #expect(map(h) == nil)
  }

  // MARK: When it does not

  @Test func startingArborShowsNothing() {
    let (h, a, _, _) = makeHarness()
    h.run("zoom \(a.rawValue)")
    h.scheduler.runPending()
    for byTheWatchdog in [false, true] {
      let again = Harness(settings: passing, saved: h.store.saved)
      for window in h.system.allWindows() {
        again.system.open(
          app: window.appName, bundleID: window.bundleID, title: window.title, pid: window.pid, frame: window.frame)
      }
      again.controller.restartedAfterAccident = byTheWatchdog
      again.start()
      // The view of a moment ago, or everything.
      #expect(again.workspace.camera == (byTheWatchdog ? h.workspace.camera : h.workspace.tree.root))
      #expect(again.overlays.minimapHistory.isEmpty, "silently")
    }
  }

  @Test func aMoveThatGoesNowhereShowsNothing() {
    let (h, a, _, _) = makeHarness()
    h.run("show-all")
    h.run("home")
    #expect(!h.run("out").ok)
    #expect(h.overlays.minimapHistory.isEmpty, "the view was on everything already")
    h.run("zoom \(a.rawValue)")
    h.scheduler.advance(by: 5)
    let before = h.overlays.minimapHistory.count
    h.run("zoom \(a.rawValue)")
    #expect(h.overlays.minimapHistory.count == before, "framed already")
  }

  @Test func aChangeOfArrangementAloneShowsNothing() {
    let (h, a, b, c) = makeHarness()
    h.run("dock \(c.rawValue) bottom")
    h.run("float \(c.rawValue)")
    h.run("relayout")
    h.run("arrange")
    h.run("float-all")
    h.run("dock \(a.rawValue) left")
    #expect(h.overlays.minimapHistory.isEmpty, "the view was on everything all along, whatever node that is")

    // Framed on one window while others, out of view, go.
    h.run("dock \(b.rawValue) right")
    h.run("dock \(c.rawValue) right")
    h.run("zoom \(a.rawValue)")
    h.scheduler.advance(by: 5)
    let before = h.overlays.minimapHistory.count
    h.system.setMinimized(b, true)
    h.system.close(c)
    #expect(h.workspace.camera == h.workspace.tree.leaf(containing: a))
    #expect(h.overlays.minimapHistory.count == before)
  }

  @Test func aWindowThatComesBackFromTheDockOutOfViewMovesTheViewAndShowsWhere() throws {
    let (h, a, _, _, d) = makeColumn()
    h.run("zoom \(a.rawValue)")
    h.system.setMinimized(d, true)
    h.scheduler.advance(by: 5)
    #expect(map(h) == nil)
    // macOS gives it the keyboard, and the view goes where the keyboard is.
    h.system.setMinimized(d, false)
    #expect(h.workspace.camera != h.workspace.tree.leaf(containing: a))
    #expect(try #require(map(h)).items.first { $0.window == d }?.isInView == true)
  }

  @Test func theDesktopInViewBecomingAllThereIsIsNotAMove() {
    let (h, a, b, _) = makeHarness()
    h.run("desktop")
    h.scheduler.advance(by: 5)
    let before = h.overlays.minimapHistory.count
    h.run("float \(a.rawValue)")
    #expect(h.overlays.minimapHistory.count == before, "out of view, and the view stays on the Desktop")
    h.run("float \(b.rawValue)")
    #expect(h.workspace.camera == h.workspace.tree.root, "the Desktop is everything now")
    #expect(h.overlays.minimapHistory.count == before)
    #expect(timers(h).isEmpty)
  }

  @Test func withNothingDockedThereIsNothingToShow() {
    let h = Harness(settings: passing)
    h.system.open(app: "Safari")
    h.start()
    h.run("show-all")
    h.run("desktop")
    #expect(h.overlays.minimapHistory.isEmpty)
    let result = h.run("minimap")
    #expect(!result.ok)
    #expect(result.message.contains("nothing is docked yet"))
    #expect(timers(h).isEmpty)
  }

  @Test func withEveryDockedWindowMinimizedTheCommandSaysSo() {
    let (h, a, b, _) = makeHarness()
    h.system.setMinimized(a, true)
    h.system.setMinimized(b, true)
    let result = h.run("minimap")
    #expect(!result.ok)
    #expect(result.message.contains("they are minimized, hidden or on another macOS Space"))
    #expect(!result.message.contains(" map"), "the glossary: never \"map\" on its own")
  }

  /// As it ships: nothing appears by itself.
  @Test func aDurationOfZeroWhichIsTheDefaultTurnsItOffButNotTheCommand() {
    #expect(Settings().minimapDuration == 0)
    let (h, a, _, _, d) = makeColumn(settings: Settings())
    h.run("zoom \(a.rawValue)")
    h.run("out")
    h.run("zoom \(d.rawValue)")
    h.system.close(d)
    #expect(h.overlays.minimapHistory.isEmpty)
    #expect(timers(h).isEmpty)
    #expect(h.run("minimap").ok)
    #expect(map(h) != nil)
  }

  @Test func theDurationIsASetting() throws {
    let settings = try JSONDecoder().decode(Settings.self, from: Data(#"{"minimapDuration": 3}"#.utf8))
    let (h, a, _, _) = makeHarness(settings: settings)
    h.run("zoom \(a.rawValue)")
    h.scheduler.advance(by: 2.9)
    #expect(map(h) != nil)
    h.scheduler.advance(by: 0.2)
    #expect(map(h) == nil)
    #expect(try JSONDecoder().decode(Settings.self, from: Data("{}".utf8)).minimapDuration == 0, "old files get the default")
    let written = try JSONDecoder().decode(Settings.self, from: JSONEncoder().encode(settings))
    #expect(written.minimapDuration == 3)
  }

  @Test func aNonsensicalDurationDoesNoHarm() {
    for (duration, staysFor) in [(-5, 0), (1e300, 10), (Double.infinity, 10), (Double.nan, 0), (-Double.infinity, 0)] {
      var settings = Settings()
      settings.minimapDuration = duration
      let (h, a, _, _) = makeHarness(settings: settings)
      h.run("zoom \(a.rawValue)")
      #expect((map(h) != nil) == (staysFor > 0), "\(duration)")
      h.scheduler.advance(by: Double(staysFor) + 0.1)
      #expect(map(h) == nil, "\(duration)")
      #expect(timers(h).isEmpty, "\(duration)")
    }
  }

  // MARK: What it holds

  @Test func thePanelSitsNearTheBottomCentreOfItsDisplay() throws {
    let (h, a, _, _) = makeHarness()
    h.run("zoom \(a.rawValue)")
    let model = try #require(map(h))
    let visible = h.visibleFrame
    #expect(visible.contains(model.frame))
    #expect(abs(model.frame.midX - visible.midX) <= 1)
    #expect(visible.maxY - model.frame.maxY == 56)
    #expect(model.frame.width == 240 && model.frame.height <= 160)
    #expect(h.controller.minimapFrame(on: h.display) == model.frame, "for the heads-up line, which sits above it")
    h.scheduler.advance(by: 1)
    #expect(h.controller.minimapFrame(on: h.display) == nil)
  }

  @Test func aSavedViewIsNamedInTheCaption() throws {
    let (h, a, _, _) = makeHarness()
    h.run("zoom \(a.rawValue)")
    let plain = try #require(map(h))
    h.run("save-view 7")
    h.run("save-view 3")
    h.run("show-all")
    #expect(map(h)?.caption == nil)
    h.run("view 7")
    let model = try #require(map(h))
    #expect(model.caption == "View 3", "the lowest of the numbers that lead here")
    #expect(model.frame.height == plain.frame.height + 18, "the panel grows by a line")
    #expect(model.frame.maxY == plain.frame.maxY, "upwards")
  }

  @Test func aSpacesNameIsTheCaptionAheadOfASavedViewsNumber() throws {
    let (h, a, b, _) = makeHarness()
    h.run("zoom \(a.rawValue)")
    h.run("save-view 3")
    h.run("name Writing room")
    h.run("zoom \(b.rawValue)")
    #expect(map(h)?.caption == nil)
    h.run("go Writing")
    #expect(try #require(map(h)).caption == "Writing room", "as it was typed")
    h.run("unname")
    h.run("zoom \(b.rawValue)")
    h.run("view 3")
    #expect(map(h)?.caption == "View 3")
  }

  @Test func namingTheSpaceInViewWhileTheMinimapIsUpShowsTheNameAtOnce() {
    let (h, a, _, _) = makeHarness()
    h.run("zoom \(a.rawValue)")
    h.run("minimap")
    #expect(map(h)?.caption == nil)
    h.run("name Reading")
    #expect(map(h)?.caption == "Reading")
    h.run("unname")
    #expect(map(h)?.caption == nil)
  }

  @Test func savingTheViewWhileTheMapIsUpDoesNotNeedToShowAtOnce() {
    // `save-view` lays nothing out. The caption is there the next time the map is.
    let (h, a, _, _) = makeHarness()
    h.run("zoom \(a.rawValue)")
    h.run("save-view 2")
    h.scheduler.advance(by: 5)
    h.run("minimap")
    #expect(map(h)?.caption == "View 2")
  }

  @Test func windowTitlesAndAppNamesAreNotInTheModel() {
    let h = Harness(settings: passing)
    let a = h.system.open(app: "Pages", bundleID: "com.example.writer", title: "Resignation letter")
    h.start()
    h.run("dock \(a.rawValue) left")
    h.run("zoom \(a.rawValue)")
    let text = String(describing: map(h))
    #expect(map(h) != nil)
    #expect(!text.contains("Resignation") && !text.contains("Pages"))
  }

  @Test func whileItShowsItFollowsTheArrangement() throws {
    let (h, a, b, c, d) = makeColumn()
    h.run("zoom \(a.rawValue)")
    h.scheduler.advance(by: 0.5)
    h.system.close(d)
    #expect(try #require(map(h)).items.map(\.window) == [a, b], "never a picture of an arrangement that is gone")
    h.scheduler.advance(by: 0.3)
    #expect(map(h) != nil)
    h.scheduler.advance(by: 0.2)
    #expect(map(h) == nil, "but that does not keep it up any longer")

    h.run("minimap")
    for window in [a, b, c] { h.system.close(window) }
    #expect(map(h) == nil, "nothing is left to show")
    #expect(timers(h).isEmpty)
  }

  @Test func thePresenterIsNotToldTheSameThingTwice() {
    let (h, a, _, _) = makeHarness()
    h.run("zoom \(a.rawValue)")
    let before = h.overlays.minimapHistory.count
    h.run("relayout")
    h.scheduler.advance(by: 0.3)  // enforcement and the like lay out again
    #expect(h.overlays.minimapHistory.count == before)
  }

  // MARK: On demand

  @Test func askedForItStaysFiveSecondsAndTakesClicks() throws {
    let (h, _, _, _) = makeHarness()
    #expect(!isTicked(h))
    #expect(h.run("minimap").message == "showing the minimap")
    #expect(try #require(map(h)).takesClicks)
    #expect(isTicked(h))
    h.scheduler.advance(by: 4.9)
    #expect(map(h) != nil)
    h.scheduler.advance(by: 0.2)
    #expect(map(h) == nil)
    #expect(timers(h).isEmpty)
    #expect(!isTicked(h))
    h.run("desktop")
    #expect(map(h) != nil && !isTicked(h), "one that passes by is not ticked")
  }

  /// The tick of the menu's row.
  private func isTicked(_ h: Harness) -> Bool { h.controller.menuModel().item("Show Minimap")?.isTicked == true }

  // MARK: With the heads-up line (F43)

  /// ⌃⌥M moves no view, no window and no keyboard, which is what otherwise earns a key a line ("it is not dead"). The panel is
  /// its own answer.
  @Test func askingForItAndPuttingItAwaySayNothingOnScreen() {
    let (h, _, _, _) = makeHarness()
    #expect(h.press("minimap").ok)
    #expect(map(h) != nil)
    #expect(h.press("minimap").ok)
    #expect(map(h) == nil)
    #expect(h.overlays.messages.isEmpty)
  }

  @Test func aRefusalIsSaidOnScreen() throws {
    let h = Harness(settings: passing)
    h.system.open(app: "Safari")
    h.start()
    #expect(!h.press("minimap").ok)
    let line = try #require(h.overlays.headsUp[h.display])
    #expect(line.kind == .problem)
    #expect(line.text.hasPrefix("Nothing is docked yet"))
  }

  /// Both are low on the display, centred. The line is directly above the minimap for as long as there is one, and its own time
  /// runs on whatever the minimap does.
  @Test func theHeadsUpLineKeepsDirectlyAboveTheMinimap() throws {
    let (h, _, _, _) = makeHarness()
    func line() -> HeadsUpModel? { h.overlays.headsUp[h.display] }
    let bottom = FakeWindowSystem.standardDisplay.visibleFrame.maxY
    h.press("save-view 1")
    let alone = try #require(line())
    #expect(alone.anchor.y == bottom - HeadsUpModel.bottomMargin)

    h.scheduler.advance(by: 0.5)
    h.press("minimap")
    let model = try #require(map(h))
    #expect(model.frame.maxY == bottom - HeadsUpModel.bottomMargin, "the lowest of the two has the margin")
    #expect(line()?.anchor.y == model.frame.minY - HeadsUpModel.spacing)
    #expect(line()?.text == alone.text)

    h.scheduler.advance(by: 0.5)
    h.press("minimap")
    #expect(map(h) == nil)
    #expect(line() == alone, "back where it was")
    #expect(h.overlays.messages.count == 3, "shown, moved up, moved down: nothing new was said")

    h.scheduler.advance(by: alone.duration - 1.1)
    #expect(line() != nil)
    h.scheduler.advance(by: 0.2)
    #expect(line() == nil, "its time ran from when it was said")
  }

  @Test func aLineSaidWhileTheMinimapIsUpBeginsAboveIt() throws {
    let (h, _, _, _) = makeHarness()
    h.press("minimap")
    let model = try #require(map(h))
    h.press("save-view 1")
    #expect(h.overlays.headsUp[h.display]?.anchor.y == model.frame.minY - HeadsUpModel.spacing)
    #expect(h.overlays.messages.count == 1)
  }

  /// The menu greys a row out when choosing it would only fail (docs/MENU.md): the row and the command go by one rule.
  @Test func theMenusRowIsGreyWhereTheCommandWouldRefuse() throws {
    func row(_ h: Harness) throws -> MenuModel.Item { try #require(h.controller.menuModel().item("Show Minimap")) }
    let empty = Harness(settings: passing)
    empty.system.open(app: "Safari")
    empty.start()
    #expect(try !row(empty).isEnabled && !empty.run("minimap").ok, "nothing is docked")

    let (h, a, b, _) = makeHarness()
    #expect(try row(h).isEnabled)
    #expect(try row(h).shortcut?.label == "⌃⌥M")
    h.run("minimap")
    h.system.setMinimized(a, true)
    h.system.setMinimized(b, true)
    #expect(map(h) == nil, "nothing is left to show")
    #expect(try !row(h).isEnabled && !row(h).isTicked && !h.run("minimap").ok, "no docked window takes up room")
    h.system.setMinimized(a, false)
    #expect(try row(h).isEnabled)
  }

  /// A command from the menu acts on the display under the pointer, so that is the display the row is about: a tick says
  /// that choosing the row puts a minimap away, which it would not do to one on another display.
  @Test func theMenusRowIsAboutTheDisplayUnderThePointer() throws {
    let h = Harness(displays: [FakeWindowSystem.standardDisplay, side], settings: passing)
    let a = h.system.open(app: "Safari")
    h.start()
    h.run("dock \(a.rawValue) left")
    h.system.cursor = CGPoint(x: 700, y: 400)
    #expect(h.controller.perform(.minimap, from: .menu).ok)
    #expect(isTicked(h))
    h.system.cursor = CGPoint(x: 2000, y: 400)
    let there = try #require(h.controller.menuModel().item("Show Minimap"))
    #expect(!there.isTicked && !there.isEnabled, "nothing is docked on this one, and nothing is up")
    #expect(!h.controller.perform(.minimap, from: .menu).ok)
    #expect(h.overlays.minimaps[FakeWindowSystem.standardDisplay.id]?.takesClicks == true, "the other's is left alone")
  }

  @Test func askingAgainPutsItAway() {
    let (h, _, _, _) = makeHarness()
    h.run("minimap")
    #expect(h.run("minimap").message == "put the minimap away")
    #expect(map(h) == nil)
    #expect(timers(h).isEmpty)
    h.run("minimap")
    #expect(map(h) != nil)
  }

  @Test func askingWhileOnePassesByKeepsItAndMakesItTakeClicks() throws {
    let (h, a, _, _) = makeHarness()
    h.run("zoom \(a.rawValue)")
    h.scheduler.advance(by: 0.5)
    #expect(h.run("minimap").message == "showing the minimap")
    #expect(try #require(map(h)).takesClicks)
    h.scheduler.advance(by: 4.9)
    #expect(map(h) != nil, "five seconds from the asking")
  }

  @Test func walkingWithTheMapOpen() throws {
    let (h, a, b, _) = makeHarness(settings: off)
    h.run("zoom \(a.rawValue)")
    h.run("minimap")
    h.scheduler.advance(by: 4)
    h.run("neighbor right")
    h.scheduler.advance(by: 4)
    h.run("neighbor right")
    let model = try #require(map(h), "each move starts the five seconds again")
    #expect(model.takesClicks)
    #expect(model.items.filter(\.isInView).map(\.window) == [b])
    h.scheduler.advance(by: 5.1)
    #expect(map(h) == nil)
  }

  @Test func aClickOnAWindowFramesItAndGivesItTheKeyboard() throws {
    let (h, a, b, _) = makeHarness()
    h.run("zoom \(a.rawValue)")
    h.run("minimap")
    h.overlays.clickMinimap(at: try #require(map(h)).items[1].frame.center)
    #expect(h.workspace.camera == h.workspace.tree.leaf(containing: b))
    #expect(h.system.focusedWindow() == b)
    #expect(h.run("back").ok, "a move like any other: `back` returns")
    #expect(h.workspace.camera == h.workspace.tree.leaf(containing: a))
  }

  @Test func afterAClickTheMapMarksTheNewPlaceAndGoesLikeAnyOther() throws {
    let (h, a, b, _) = makeHarness()
    h.run("zoom \(a.rawValue)")
    h.run("minimap")
    h.overlays.clickMinimap(at: try #require(map(h)).items[1].frame.center)
    let model = try #require(map(h))
    #expect(model.items.filter(\.isInView).map(\.window) == [b])
    #expect(!model.takesClicks)
    h.scheduler.advance(by: 0.89)
    #expect(map(h) != nil)
    h.scheduler.advance(by: 0.02)
    #expect(map(h) == nil)
    #expect(timers(h).isEmpty)
  }

  @Test func aClickOnTheDesktopsOutlineShowsTheDesktop() throws {
    let (h, a, _, c) = makeHarness()
    h.run("zoom \(a.rawValue)")
    #expect(h.controller.parked.contains(c))
    h.run("minimap")
    let outline = try #require(map(h)?.desktop)
    h.overlays.clickMinimap(at: outline.center)
    #expect(h.workspace.camera == h.workspace.tree.desktop)
    #expect(!h.controller.parked.contains(c), "and the window floating on it")
  }

  @Test func aClickBesideTheMapPutsItAway() {
    let (h, a, _, _) = makeHarness()
    h.run("zoom \(a.rawValue)")
    h.run("minimap")
    h.overlays.clickMinimap(at: CGPoint(x: 2, y: 2))
    #expect(map(h) == nil)
    #expect(timers(h).isEmpty)
    #expect(h.workspace.camera == h.workspace.tree.leaf(containing: a))
  }

  @Test func aClickOnWhereTheViewAlreadyIsPutsItAway() throws {
    let (h, a, _, _) = makeHarness()
    h.run("zoom \(a.rawValue)")
    h.run("minimap")
    h.overlays.clickMinimap(at: try #require(map(h)).items[0].frame.center)
    #expect(map(h) == nil)
    #expect(timers(h).isEmpty)
    #expect(h.workspace.camera == h.workspace.tree.leaf(containing: a))
  }

  @Test func withPassingMinimapsOffAClickGoesThereAndPutsItAway() throws {
    let (h, a, b, _) = makeHarness(settings: off)
    h.run("zoom \(a.rawValue)")
    h.run("minimap")
    h.overlays.clickMinimap(at: try #require(map(h)).items[1].frame.center)
    #expect(h.workspace.camera == h.workspace.tree.leaf(containing: b))
    #expect(map(h) == nil)
    #expect(timers(h).isEmpty)
  }

  @Test func onlyAMinimapThatWasAskedForHearsClicks() throws {
    let (h, a, _, _) = makeHarness()
    h.run("zoom \(a.rawValue)")
    let spot = try #require(map(h)).items[1].frame.center
    // Straight at the controller, past the panel that would have let the click through.
    h.controller.minimapClicked(display: h.display, at: spot)
    #expect(h.workspace.camera == h.workspace.tree.leaf(containing: a))
    h.scheduler.advance(by: 5)
    h.controller.minimapClicked(display: h.display, at: spot)
    h.controller.minimapClicked(display: DisplayID("nowhere"), at: spot)
    #expect(h.workspace.camera == h.workspace.tree.leaf(containing: a), "nor one that has gone")
  }

  @Test func aClickOnAWindowThatHasJustClosedDoesNoHarm() throws {
    let (h, a, b, _) = makeHarness()
    h.run("zoom \(a.rawValue)")
    h.run("minimap")
    let stale = try #require(map(h)).items[1].frame.center
    h.system.close(b)
    h.overlays.clickMinimap(at: stale)  // the map has been redrawn: something else, or nothing, is there now
    #expect(h.workspace.tree.contains(h.workspace.camera))
    h.scheduler.advance(by: 6)
    #expect(map(h) == nil && timers(h).isEmpty)
  }

  // MARK: The pointer over it

  /// Where a rectangle of the panel is on screen.
  func onScreen(_ rect: CGRect, _ model: MinimapModel) -> CGPoint {
    CGPoint(x: model.frame.minX + rect.midX, y: model.frame.minY + rect.midY)
  }

  @Test func theSpaceUnderThePointerIsOutlined() throws {
    let (h, a, _, _) = makeHarness()
    h.run("zoom \(a.rawValue)")
    h.run("minimap")
    let model = try #require(map(h))
    #expect(model.hover == nil, "the pointer is somewhere else")
    h.system.cursor = onScreen(model.items[1].frame, model)
    h.scheduler.advance(by: 0.05)
    #expect(map(h)?.hover == model.items[1].frame)
    h.system.cursor = onScreen(try #require(model.desktop), model)
    h.scheduler.advance(by: 0.05)
    #expect(map(h)?.hover == model.desktop)
    h.system.cursor = CGPoint(x: model.frame.minX + 2, y: model.frame.minY + 2)
    h.scheduler.advance(by: 0.05)
    #expect(map(h) == model, "beside the map, nothing is")
  }

  @Test func broughtUpUnderThePointerItIsOutlinedAtOnce() throws {
    let (h, a, _, _) = makeHarness()
    h.run("zoom \(a.rawValue)")
    h.run("minimap")
    let model = try #require(map(h))
    h.run("minimap")
    h.system.cursor = onScreen(model.items[0].frame, model)
    h.run("minimap")
    #expect(map(h)?.hover == model.items[0].frame)
  }

  @Test func aPassingMinimapOutlinesNothingAndWatchesNothing() throws {
    let (h, a, b, _) = makeHarness()
    h.run("zoom \(a.rawValue)")
    let model = try #require(map(h))
    h.system.cursor = onScreen(model.items[1].frame, model)
    h.scheduler.advance(by: 0.1)
    #expect(map(h) == model)
    h.run("zoom \(b.rawValue)")
    #expect(try #require(map(h)).hover == nil)
    #expect(timers(h) == ["minimap-main"], "its own time, and no watching of the pointer")
  }

  @Test func theOutlineSurvivesAChangeOfTheArrangement() throws {
    let (h, a, _, c) = makeHarness()
    h.run("zoom \(a.rawValue)")
    h.run("show-all")
    h.run("minimap")
    let model = try #require(map(h))
    h.system.cursor = onScreen(model.items[0].frame, model)
    h.scheduler.advance(by: 0.05)
    h.run("dock \(c.rawValue) bottom")
    let after = try #require(map(h))
    #expect(after.items.count == 3)
    #expect(after.hover != nil && after.hover == after.items.first { $0.frame.contains(after.hover!.center) }?.frame)
  }

  // MARK: Holding the keys

  @Test func aTapBringsItUpForItsFiveSeconds() throws {
    let (h, _, _, _) = makeHarness()
    #expect(h.key("ctrl+opt+m")?.ok == true)
    #expect(try #require(map(h)).takesClicks)
    h.scheduler.advance(by: 4.9)
    #expect(map(h) != nil)
    h.scheduler.advance(by: 0.2)
    #expect(map(h) == nil)
    #expect(timers(h).isEmpty)
    h.key("ctrl+opt+m")
    #expect(h.key("ctrl+opt+m")?.message == "put the minimap away")
    #expect(map(h) == nil && timers(h).isEmpty)
  }

  @Test func heldItStaysForAsLongAsTheKeysAreDown() {
    let (h, a, _, _) = makeHarness()
    h.run("zoom \(a.rawValue)")
    h.keyDown("ctrl+opt+m")
    h.scheduler.advance(by: 12)
    #expect(map(h) != nil, "well past the five seconds")
    h.keyUp("ctrl+opt+m")
    #expect(map(h) == nil, "the pointer is over nothing: letting go puts it away")
    #expect(h.workspace.camera == h.workspace.tree.leaf(containing: a))
    #expect(timers(h).isEmpty)
  }

  @Test func lettingGoLandsOnWhatThePointerIsOver() throws {
    let (h, a, b, _) = makeHarness()
    h.run("zoom \(a.rawValue)")
    h.keyDown("ctrl+opt+m")
    let model = try #require(map(h))
    h.system.cursor = onScreen(model.items[1].frame, model)
    h.scheduler.advance(by: 0.5)
    #expect(map(h)?.hover == model.items[1].frame)
    h.keyUp("ctrl+opt+m")
    #expect(h.workspace.camera == h.workspace.tree.leaf(containing: b))
    #expect(h.system.focusedWindow() == b)
    let after = try #require(map(h), "it marks the landing and goes like any other")
    #expect(!after.takesClicks && after.hover == nil)
    h.scheduler.advance(by: 1)
    #expect(map(h) == nil && timers(h).isEmpty)
    #expect(h.run("back").ok)
    #expect(h.workspace.camera == h.workspace.tree.leaf(containing: a), "one move, one entry in the history")
  }

  @Test func letGoBeforeItCountsAsHeldThePointerDecidesNothing() throws {
    let (h, a, _, _) = makeHarness()
    h.run("zoom \(a.rawValue)")
    h.keyDown("ctrl+opt+m")
    let model = try #require(map(h))
    h.system.cursor = onScreen(model.items[1].frame, model)
    h.scheduler.advance(by: 0.25)
    h.keyUp("ctrl+opt+m")
    #expect(h.workspace.camera == h.workspace.tree.leaf(containing: a), "a tap with the pointer resting there by chance")
    #expect(map(h)?.takesClicks == true)
  }

  @Test func lettingGoOverWhereTheViewAlreadyIsPutsItAway() throws {
    let (h, a, _, _) = makeHarness()
    h.run("zoom \(a.rawValue)")
    h.keyDown("ctrl+opt+m")
    let model = try #require(map(h))
    h.system.cursor = onScreen(model.items[0].frame, model)
    h.scheduler.advance(by: 0.5)
    h.keyUp("ctrl+opt+m")
    #expect(map(h) == nil && timers(h).isEmpty)
    #expect(h.workspace.camera == h.workspace.tree.leaf(containing: a))
  }

  @Test func aReleaseNobodyReportsIsFound() throws {
    let (h, a, b, _) = makeHarness()
    h.run("zoom \(a.rawValue)")
    h.keyDown("ctrl+opt+m")
    let model = try #require(map(h))
    h.system.cursor = onScreen(model.items[1].frame, model)
    h.scheduler.advance(by: 0.5)
    h.keyUp("ctrl+opt+m", reported: false)
    #expect(h.workspace.camera == h.workspace.tree.leaf(containing: a))
    h.scheduler.advance(by: 0.05)
    #expect(h.workspace.camera == h.workspace.tree.leaf(containing: b), "⌃ or ⌥ went up first")
  }

  @Test func autoRepeatDoesNotToggleIt() {
    let (h, _, _, _) = makeHarness()
    h.keyDown("ctrl+opt+m")
    for _ in 0..<5 {
      h.scheduler.advance(by: 0.1)
      #expect(h.keyDown("ctrl+opt+m") == nil)
      #expect(map(h) != nil)
    }
    h.keyUp("ctrl+opt+m")
  }

  @Test func aClickWhileHoldingDecidesAndTheReleaseDoesNothingMore() throws {
    let (h, a, b, _) = makeHarness()
    h.run("zoom \(a.rawValue)")
    h.keyDown("ctrl+opt+m")
    let model = try #require(map(h))
    h.scheduler.advance(by: 0.5)
    h.system.cursor = onScreen(model.items[1].frame, model)
    h.overlays.clickMinimap(at: model.items[1].frame.center)
    #expect(h.workspace.camera == h.workspace.tree.leaf(containing: b))
    // The pointer wanders over another space before the keys come up.
    h.system.cursor = onScreen(model.items[0].frame, model)
    h.scheduler.advance(by: 0.3)
    #expect(h.keyDown("ctrl+opt+m") == nil, "still down: auto-repeat")
    h.keyUp("ctrl+opt+m")
    #expect(h.workspace.camera == h.workspace.tree.leaf(containing: b))
    h.scheduler.advance(by: 1)
    #expect(map(h) == nil && timers(h).isEmpty)
  }

  @Test func afterAClickWhileHoldingTheMapGoesInItsOwnTimeThoughTheKeysAreStillDown() throws {
    let (h, a, b, _) = makeHarness()
    h.run("zoom \(a.rawValue)")
    h.keyDown("ctrl+opt+m")
    let model = try #require(map(h))
    h.scheduler.advance(by: 0.5)
    h.overlays.clickMinimap(at: model.items[1].frame.center)
    #expect(h.workspace.camera == h.workspace.tree.leaf(containing: b))
    #expect(map(h)?.takesClicks == false)
    h.scheduler.advance(by: 1)
    #expect(map(h) == nil, "the hold is over, whatever the fingers do")
    h.keyUp("ctrl+opt+m")
    #expect(timers(h).isEmpty)
  }

  @Test func aHoldOnOneDisplayLeavesTheOthersMinimapToItsOwnTime() {
    let h = Harness(displays: [FakeWindowSystem.standardDisplay, side], settings: passing)
    let a = h.system.open(app: "Safari", frame: CGRect(x: 100, y: 100, width: 600, height: 400))
    let b = h.system.open(app: "Notes", frame: CGRect(x: 1600, y: 100, width: 600, height: 400))
    h.start()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) left")
    h.system.userFocus(b)
    h.system.cursor = CGPoint(x: 2000, y: 400)
    h.keyDown("ctrl+opt+m")
    h.scheduler.advance(by: 6)
    #expect(h.overlays.minimaps[side.id]?.takesClicks == true, "held up")
    h.run("zoom \(a.rawValue)")
    #expect(h.overlays.minimaps[h.display] != nil)
    h.scheduler.advance(by: 1)
    #expect(h.overlays.minimaps[h.display] == nil, "a passing one, elsewhere, passes")
    #expect(h.overlays.minimaps[side.id] != nil, "and takes nothing along")
    h.keyUp("ctrl+opt+m")
    #expect(h.overlays.minimaps[side.id] == nil, "its going did not end the hold: letting go still does")
    #expect(timers(h).isEmpty)
  }

  @Test func theKeyThatPutsAwayWhatACommandBroughtUpHoldsNothing() {
    let (h, _, _, _) = makeHarness()
    h.run("minimap")
    #expect(h.keyDown("ctrl+opt+m")?.message == "put the minimap away")
    #expect(map(h) == nil)
    #expect(timers(h).isEmpty, "nothing is up and nothing is held: nothing to watch")
    // So a release that nobody reports must not matter either: nothing would ever find it.
    h.keyUp("ctrl+opt+m", reported: false)
    h.scheduler.advance(by: 0.1)
    #expect(h.key("ctrl+opt+m")?.message == "showing the minimap")
  }

  /// The one thing that must never happen: a hold that is never over, which would take every later press for auto-repeat.
  @Test func theKeyNeverGoesDead() throws {
    let endings: [(String, (Harness) -> Void)] = [
      ("a click beside the map", { $0.overlays.clickMinimap(at: CGPoint(x: 2, y: 2)) }),
      ("the last docked window closing", { h in h.workspace.tree.allWindows.forEach { h.system.close($0) } }),
      ("a pause", { h in
        h.run("pause")
        h.run("resume")
      }),
    ]
    for (name, ending) in endings {
      for reported in [true, false] {
        let (h, _, _, c) = makeHarness()
        h.keyDown("ctrl+opt+m")
        h.scheduler.advance(by: 0.5)
        ending(h)
        #expect(map(h) == nil, "\(name)")
        h.keyUp("ctrl+opt+m", reported: reported)
        h.scheduler.advance(by: 0.1)
        #expect(timers(h).isEmpty, "\(name), release reported: \(reported)")
        h.run("dock \(c.rawValue) left")
        #expect(h.key("ctrl+opt+m")?.ok == true, "\(name), release reported: \(reported)")
        #expect(map(h) != nil, "\(name), release reported: \(reported)")
      }
    }
  }

  @Test func withPeekingOffHeldIsTapped() throws {
    var settings = passing
    settings.peek = false
    let (h, a, _, _) = makeHarness(settings: settings)
    h.run("zoom \(a.rawValue)")
    h.keyDown("ctrl+opt+m")
    h.scheduler.advance(by: 4.9)
    let model = try #require(map(h))
    h.scheduler.advance(by: 0.2)
    #expect(map(h) == nil, "five seconds, keys down or not")
    h.keyUp("ctrl+opt+m")
    #expect(timers(h).isEmpty)

    h.keyDown("ctrl+opt+m")
    h.system.cursor = onScreen(model.items[1].frame, model)
    h.scheduler.advance(by: 1)
    h.keyUp("ctrl+opt+m")
    #expect(h.workspace.camera == h.workspace.tree.leaf(containing: a), "and letting go lands nowhere")
    #expect(map(h)?.takesClicks == true)
  }

  // MARK: ⎋ while holding

  /// With ⌃⌥ down, ⎋ is ⌃⌥⎋, which pauses Arbor and brings every window into view: the last thing someone means who
  /// wants out of a minimap. In a peek the same gesture gives up.
  @Test func escapeWhileHoldingPutsItAwayAndPausesNothing() {
    for held in [0.1, 0.5, 8] {
      let (h, a, b, _) = makeHarness()
      h.run("zoom \(a.rawValue)")
      h.keyDown("ctrl+opt+m")
      h.scheduler.advance(by: held)
      #expect(h.key("ctrl+opt+escape") == nil, "no command runs")
      #expect(!h.controller.isPaused && h.controller.isRunning, "held for \(held) s")
      #expect(h.controller.parked.contains(b), "what is out of view stays there")
      #expect(map(h) == nil, "held for \(held) s")
      #expect(h.workspace.camera == h.workspace.tree.leaf(containing: a))
      h.keyUp("ctrl+opt+m")
      #expect(map(h) == nil && timers(h).isEmpty)
    }
  }

  @Test func escapeOnceItHasGoneAndWhenNothingIsHeldPausesAsEver() {
    let (h, _, _, _) = makeHarness()
    h.keyDown("ctrl+opt+m")
    h.scheduler.advance(by: 0.5)
    h.key("ctrl+opt+escape")
    #expect(!h.controller.isPaused)
    #expect(h.key("ctrl+opt+escape")?.ok == true, "the minimap has gone; the keys are still down, and ⌃⌥⎋ is itself again")
    #expect(h.controller.isPaused)
    h.keyUp("ctrl+opt+m")
    h.key("ctrl+opt+escape")
    #expect(!h.controller.isPaused)

    h.key("ctrl+opt+m")
    #expect(map(h) != nil)
    h.key("ctrl+opt+escape")
    #expect(h.controller.isPaused, "tapped, nothing is held")
  }

  // MARK: Its time and the pointer

  /// The click that was on its way would land in the app below.
  @Test func itsTimeDoesNotRunOutUnderThePointer() throws {
    let (h, a, _, _) = makeHarness()
    h.run("zoom \(a.rawValue)")
    h.run("minimap")
    let model = try #require(map(h))
    h.scheduler.advance(by: 4.5)
    // Anywhere on the panel: aiming starts at its edge.
    h.system.cursor = CGPoint(x: model.frame.minX + 3, y: model.frame.midY)
    h.scheduler.advance(by: 20)
    #expect(map(h) != nil)
    h.system.cursor = CGPoint(x: model.frame.minX - 40, y: model.frame.midY)
    h.scheduler.advance(by: 4.8)
    #expect(map(h) != nil, "it starts again when the pointer leaves")
    h.scheduler.advance(by: 0.4)
    #expect(map(h) == nil)
    #expect(timers(h).isEmpty)
  }

  @Test func aPassingMinimapGoesWhereverThePointerIs() throws {
    let (h, a, _, _) = makeHarness()
    h.run("zoom \(a.rawValue)")
    let model = try #require(map(h))
    h.system.cursor = model.frame.center
    h.scheduler.advance(by: 1)
    #expect(map(h) == nil, "no click can hit it, so none can miss it")
  }

  // MARK: The guard of the Desktop (F60)

  /// A click in a minimap over bare Desktop is the minimap's, not one to keep from macOS.
  @Test func oneThatTakesClicksIsAmongTheGuardsPanelsAndSaysWhenThatChanges() throws {
    var settings = passing
    (settings.guardDesktopClicks, settings.pointerGestures) = (true, true)
    let (h, a, b, _) = makeHarness(settings: settings)
    var published = h.controller.desktopGuardZones()
    h.controller.observe { if $0.mayChangeDesktopGuardZones { published = h.controller.desktopGuardZones() } }
    func panels() -> [CGRect] { h.controller.desktopGuardZones().displays.flatMap(\.panels) }
    func check(_ what: String, has frame: CGRect?, sourceLocation: SourceLocation = #_sourceLocation) {
      #expect(published == h.controller.desktopGuardZones(), "\(what): announced", sourceLocation: sourceLocation)
      if let frame { #expect(panels().contains(frame), "\(what)", sourceLocation: sourceLocation) }
    }

    h.run("desktop")
    let passingBy = try #require(map(h)).frame
    #expect(!panels().contains(passingBy), "a passing one lets every press through")
    h.run("minimap")
    check("asked for", has: passingBy)
    h.run("minimap")
    #expect(!panels().contains(passingBy))
    check("put away", has: nil)

    h.run("minimap")
    h.scheduler.advance(by: 5.1)
    #expect(!panels().contains(passingBy))
    check("gone by itself", has: nil)

    h.run("minimap")
    h.overlays.clickMinimap(at: try #require(map(h)).items[1].frame.center)
    #expect(h.workspace.camera == h.workspace.tree.leaf(containing: b))
    #expect(map(h) != nil && !panels().contains(passingBy), "after the click it only passes by")
    check("clicked", has: nil)

    // A caption makes it taller.
    h.run("save-view 4")
    h.run("zoom \(a.rawValue)")
    h.run("minimap")
    h.run("view 4")
    let taller = try #require(map(h)).frame
    #expect(taller != passingBy)
    check("resized", has: taller)
  }

  @Test func walkingWhileHolding() throws {
    let (h, a, b, _) = makeHarness()
    h.run("zoom \(a.rawValue)")
    h.keyDown("ctrl+opt+m")
    h.scheduler.advance(by: 0.5)
    h.run("neighbor right")
    h.run("neighbor right")
    h.scheduler.advance(by: 7)
    #expect(try #require(map(h)).items.filter(\.isInView).map(\.window) == [b], "still up, and up to date")
    h.keyUp("ctrl+opt+m")
    #expect(map(h) == nil)
    #expect(h.workspace.camera == h.workspace.tree.leaf(containing: b))
  }

  @Test func theDisplayGoingAwayEndsTheHold() {
    let h = Harness(displays: [FakeWindowSystem.standardDisplay, side], settings: passing)
    let b = h.system.open(app: "Notes", frame: CGRect(x: 1600, y: 100, width: 600, height: 400))
    h.start()
    h.run("dock \(b.rawValue) left")
    h.system.userFocus(b)
    h.system.cursor = CGPoint(x: 2000, y: 400)
    h.keyDown("ctrl+opt+m")
    #expect(h.overlays.minimaps[side.id] != nil)
    h.scheduler.advance(by: 0.5)
    h.system.setDisplays([FakeWindowSystem.standardDisplay])
    #expect(h.overlays.minimaps[side.id] == nil)
    h.keyUp("ctrl+opt+m")
    #expect(timers(h).isEmpty)
  }

  // MARK: With a peek (F51)

  @Test func thePeekHasTheDisplayToItselfAndTheLandingShowsWhere() throws {
    let (h, a, b, _) = makeHarness()
    h.run("zoom \(a.rawValue)")
    h.scheduler.advance(by: 0.2)
    #expect(map(h) != nil)
    h.keyDown("ctrl+opt+space")
    #expect(map(h) == nil, "everything is on screen: a picture of it in small is in the way")
    #expect(timers(h).isEmpty)
    h.scheduler.advance(by: 0.4)
    #expect(h.controller.isPeeking)
    h.system.cursor = h.frame(b)!.center
    h.scheduler.advance(by: 0.1)
    #expect(map(h) == nil)
    h.keyUp("ctrl+opt+space")
    #expect(h.workspace.camera == h.workspace.tree.leaf(containing: b))
    #expect(try #require(map(h)).items.filter(\.isInView).map(\.window) == [b])
  }

  @Test func lettingGoWithoutHavingChosenShowsThatTheViewIsBack() throws {
    let (h, a, _, _) = makeHarness()
    h.run("zoom \(a.rawValue)")
    h.scheduler.advance(by: 5)
    h.keyDown("ctrl+opt+space")
    h.scheduler.advance(by: 1.2)
    h.keyUp("ctrl+opt+space")
    #expect(h.workspace.camera == h.workspace.tree.leaf(containing: a))
    #expect(try #require(map(h)).items.filter(\.isInView).map(\.window) == [a])
  }

  @Test func aSlowPressInWhichNothingWasChosenMovesNothingMoreAndShowsNothingMore() {
    let (h, a, _, _) = makeHarness()
    h.run("zoom \(a.rawValue)")
    h.scheduler.advance(by: 5)
    h.keyDown("ctrl+opt+space")
    h.scheduler.advance(by: 0.5)
    #expect(map(h) == nil)
    h.keyUp("ctrl+opt+space")
    #expect(h.workspace.camera == h.workspace.tree.root, "it counts as a tap: everything stays")
    #expect(map(h) == nil && timers(h).isEmpty)
  }

  @Test func aMinimapThatWasAskedForStaysThroughAPeek() throws {
    let (h, a, _, _) = makeHarness()
    h.run("zoom \(a.rawValue)")
    h.key("ctrl+opt+m")
    h.keyDown("ctrl+opt+space")
    h.scheduler.advance(by: 0.5)
    #expect(h.controller.isPeeking)
    #expect(try #require(map(h)).takesClicks)
    h.keyUp("ctrl+opt+space")
  }

  // MARK: Displays

  @Test func eachDisplayHasItsOwn() throws {
    let h = Harness(displays: [FakeWindowSystem.standardDisplay, side], settings: passing)
    let a = h.system.open(app: "Safari", frame: CGRect(x: 100, y: 100, width: 600, height: 400))
    let b = h.system.open(app: "Notes", frame: CGRect(x: 1600, y: 100, width: 600, height: 400))
    h.start()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) left")
    h.run("zoom \(b.rawValue)")
    #expect(h.overlays.minimaps[h.display] == nil)
    let model = try #require(h.overlays.minimaps[side.id])
    #expect(side.visibleFrame.contains(model.frame))
    #expect(model.items.map(\.window) == [b])
    #expect(model.frame.size == CGSize(width: 240, height: 158), "that display's proportions: 220×138")

    h.scheduler.advance(by: 0.5)
    h.run("zoom \(a.rawValue)")
    #expect(h.overlays.minimaps.count == 2)
    h.scheduler.advance(by: 0.5)
    #expect(h.overlays.minimaps[side.id] == nil, "each goes in its own time")
    #expect(h.overlays.minimaps[h.display] != nil)

    h.system.cursor = CGPoint(x: 2000, y: 400)
    h.run("minimap")
    #expect(h.overlays.minimaps[side.id]?.takesClicks == true, "on demand: the display under the pointer")
  }

  @Test func aMoveOnOneDisplayShowsNothingOnTheOther() {
    let h = Harness(displays: [FakeWindowSystem.standardDisplay, side], settings: passing)
    let a = h.system.open(app: "Safari", frame: CGRect(x: 100, y: 100, width: 600, height: 400))
    let b = h.system.open(app: "Notes", frame: CGRect(x: 1600, y: 100, width: 600, height: 400))
    h.start()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) left")
    h.run("zoom \(b.rawValue)")
    #expect(h.overlays.minimaps[side.id] != nil)
    #expect(h.overlays.minimaps[h.display] == nil, "its view stayed")
    h.scheduler.advance(by: 5)
    let before = h.overlays.minimapHistory.count
    h.run("home")
    #expect(h.overlays.minimapHistory.count == before, "everything, on every display: none anywhere")
  }

  @Test func aDisplayThatGoesAwayTakesItsMinimapAlong() {
    let h = Harness(displays: [FakeWindowSystem.standardDisplay, side], settings: passing)
    let b = h.system.open(app: "Notes", frame: CGRect(x: 1600, y: 100, width: 600, height: 400))
    h.start()
    h.run("dock \(b.rawValue) left")
    h.run("zoom \(b.rawValue)")
    #expect(h.overlays.minimaps[side.id] != nil)
    h.system.setDisplays([FakeWindowSystem.standardDisplay])
    #expect(h.overlays.minimaps[side.id] == nil)
    #expect(timers(h).isEmpty)
  }

  @Test func aDisplayThatComesBackShowsNothingUntilItsViewMoves() {
    let h = Harness(displays: [FakeWindowSystem.standardDisplay, side], settings: passing)
    let b = h.system.open(app: "Notes", frame: CGRect(x: 1600, y: 100, width: 600, height: 400))
    h.start()
    h.run("dock \(b.rawValue) left")
    h.run("zoom \(b.rawValue)")
    h.scheduler.advance(by: 5)
    h.system.setDisplays([FakeWindowSystem.standardDisplay])
    let before = h.overlays.minimapHistory.count
    h.system.setDisplays([FakeWindowSystem.standardDisplay, side])
    #expect(h.controller.workspaces[side.id]?.isDocked(b) == true, "its arrangement is back")
    #expect(h.overlays.minimapHistory.count == before, "what Arbor restores is not a move")
    h.system.cursor = CGPoint(x: 2000, y: 400)
    h.system.userFocus(b)
    h.run("desktop")
    #expect(h.overlays.minimaps[side.id] != nil)
  }

  @Test func aDisplayThatComesBackWithAnotherViewThanItLeftWithStillShowsNothing() {
    let h = Harness(displays: [FakeWindowSystem.standardDisplay, side], settings: passing)
    let b = h.system.open(app: "Notes", frame: CGRect(x: 1600, y: 100, width: 600, height: 400))
    let d = h.system.open(app: "Mail", frame: CGRect(x: 1700, y: 200, width: 600, height: 400))
    h.start()
    h.run("dock \(b.rawValue) left")
    h.run("dock \(d.rawValue) right")
    h.run("zoom \(b.rawValue)")
    h.scheduler.advance(by: 5)
    let left = h.controller.layouts[side.id]?.camera
    h.system.setDisplays([FakeWindowSystem.standardDisplay])
    // The window it framed closes while it is away, so its view comes back on something else.
    h.system.close(b)
    h.scheduler.advance(by: 5)
    let before = h.overlays.minimapHistory.count
    h.system.setDisplays([FakeWindowSystem.standardDisplay, side])
    #expect(h.controller.workspaces[side.id]?.isDocked(d) == true, "its arrangement is back")
    #expect(h.controller.layouts[side.id]?.camera != left)
    #expect(h.overlays.minimapHistory.count == before, "what Arbor restores is not a move")
  }

  // MARK: Going away, and staying out of the way

  @Test func theLastDockedWindowClosingWhileFramedTakesTheMapAlong() {
    for asked in [false, true] {
      let h = Harness(settings: passing)
      let a = h.system.open(app: "Safari")
      h.start()
      h.run("dock \(a.rawValue) left")
      h.run("zoom \(a.rawValue)")
      if asked { h.run("minimap") }
      #expect(map(h) != nil)
      h.system.close(a)
      #expect(map(h) == nil, "the view moved, to a Desktop that is all there is")
      #expect(timers(h).isEmpty)
    }
  }

  @Test func quittingAndPausingTakeItDownAtOnce() {
    for ending in ["quit", "pause"] {
      for asked in [false, true] {
        let (h, a, _, _) = makeHarness()
        h.run("zoom \(a.rawValue)")
        if asked { h.run("minimap") }
        #expect(map(h) != nil)
        if ending == "quit" { h.controller.shutdown() } else { h.run("pause") }
        #expect(map(h) == nil, "\(ending)")
        #expect(timers(h).isEmpty, "\(ending): no timer is left behind")
        #expect(h.controller.minimapFrame(on: h.display) == nil, "\(ending)")
        #expect(!h.run("minimap").ok, "\(ending)")
        #expect(map(h) == nil, "\(ending)")
      }
    }
  }

  @Test func resumingShowsNothingUntilTheViewMoves() {
    let (h, a, _, _) = makeHarness()
    h.run("zoom \(a.rawValue)")
    h.run("pause")
    let before = h.overlays.minimapHistory.count
    h.run("resume")
    #expect(h.overlays.minimapHistory.count == before)
    h.run("desktop")
    #expect(map(h) != nil)
  }

  @Test func windowsEndUpInTheSamePlacesWithAndWithoutIt() {
    var frames: [[CGRect?]] = []
    var focus: [WindowID?] = []
    for settings in [passing, off] {
      let (h, a, b, c) = makeHarness(settings: settings)
      h.run("zoom \(a.rawValue)")
      h.run("minimap")
      h.run("back")
      h.run("dock \(c.rawValue) bottom")
      h.run("zoom \(b.rawValue)")
      h.scheduler.advance(by: 6)
      frames.append([a, b, c].map { h.frame($0) })
      focus.append(h.system.focusedWindow())
    }
    #expect(frames[0] == frames[1])
    #expect(focus[0] == focus[1])
  }

  // MARK: In a trace

  /// A click in the minimap and a held shortcut are things a person did: a trace has to carry them, or its replay ends somewhere else.
  @Test func aRecordedSessionWithTheMinimapReplaysToTheSameEnd() throws {
    let (h, a, b, _) = makeHarness()
    h.run("zoom \(a.rawValue)")
    h.scheduler.advance(by: 2)
    h.run("trace on minimap")
    h.key("ctrl+opt+m")
    h.overlays.clickMinimap(at: try #require(map(h)).items[1].frame.center)
    #expect(h.workspace.camera == h.workspace.tree.leaf(containing: b))
    h.scheduler.advance(by: 2)
    h.keyDown("ctrl+opt+m")
    let model = try #require(map(h))
    h.system.cursor = onScreen(model.items[0].frame, model)
    h.scheduler.advance(by: 0.6)
    h.keyUp("ctrl+opt+m")
    #expect(h.workspace.camera == h.workspace.tree.leaf(containing: a))
    h.scheduler.advance(by: 2)
    h.run("trace off")

    let trace = recordedTrace(h)
    let clicks = trace.entries.filter { if case .other(.action, "minimapClicked", _, _) = $0.line { true } else { false } }
    #expect(clicks.count == 1, "the click; letting go after a hold is a release, not a click")
    for mode in [TraceReplayer.Mode.strict, .free] {
      let replayer = TraceReplayer(trace, mode: mode)
      #expect(replayer.run().problems == [], "\(mode)")
      #expect(replayer.harness.controller.workspaces == h.controller.workspaces, "\(mode)")
      #expect(replayer.harness.overlays.minimaps.isEmpty, "\(mode)")
      #expect(
        replayer.harness.overlays.minimapHistory.map(\.model) == Array(h.overlays.minimapHistory.map(\.model).suffix(replayer.harness.overlays.minimapHistory.count)),
        "\(mode): the same pictures, in the same order")
    }
  }

  // MARK: The command

  @Test func minimapIsACommandWithAShortcut() throws {
    #expect(try Command.parse("minimap") == .minimap)
    #expect(try Command.parse(url: "arbor://minimap") == .minimap)
    #expect(Command.minimap.text == "minimap")
    #expect(!Command.minimap.isQuery, "so it can be bound to a key")
    #expect(Command.minimap.isAllowedFromURL, "it only looks")
    #expect(!Command.minimap.endsPause)
    #expect(throws: Command.ParseError.self) { try Command.parse("minimap now") }
    #expect(KeyBindings.label(for: .minimap) == "⌃⌥M")
    #expect(KeyBindings.defaults.filter { $0.label == "⌃⌥M" }.count == 1, "nothing else has the key")
    #expect(Command.helpText.contains("\n  minimap "))
  }
}
