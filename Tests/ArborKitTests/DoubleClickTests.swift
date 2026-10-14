import ArborCore
import ArborKit
import ArborTesting
import CoreGraphics
import Foundation
import Testing

/// F14: double-clicks on title bars, the Desktop and tiles, through the real controller.
@Suite @MainActor struct DoubleClickTests {
  /// Both double-clicks on. Both are off by default (`bothDoubleClicksAreOffByDefault`).
  static var bothOn: Settings {
    var settings = titleBarsOn
    settings.desktopDoubleClick = true
    return settings
  }

  /// With the switch above every event tap on as well (`pointerGestures`).
  static var titleBarsOn: Settings {
    var settings = Settings()
    settings.pointerGestures = true
    settings.titleBarDoubleClick = true
    return settings
  }

  /// root(h)[a, Desktop, b] showing everything, with c floating on the Desktop.
  func makeHarness(settings: Settings = bothOn) -> (Harness, WindowID, WindowID, WindowID) {
    let h = Harness(settings: settings)
    let a = h.system.open(app: "Safari", frame: CGRect(x: 100, y: 100, width: 600, height: 400))
    let b = h.system.open(app: "Notes", frame: CGRect(x: 300, y: 200, width: 600, height: 400))
    let c = h.system.open(app: "Mail", frame: CGRect(x: 560, y: 300, width: 300, height: 200))
    h.start()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) right")
    // Docking pushed c about; the user puts it where it will stay.
    h.system.userMove(c, to: CGRect(x: 570, y: 300, width: 300, height: 200))
    return (h, a, b, c)
  }

  /// The middle of a window's title bar, where it is now.
  func titleBar(_ h: Harness, _ window: WindowID) -> CGPoint {
    let frame = h.frame(window)!
    return CGPoint(x: frame.midX, y: frame.minY + 12)
  }

  /// A point of the Desktop that no floating window covers.
  func bareDesktop(_ h: Harness) -> CGPoint {
    let desktop = h.layout!.desktopFrame!
    return CGPoint(x: desktop.midX, y: desktop.minY + 20)
  }

  /// What a user would notice: where the camera is and where every window sits.
  func picture(_ h: Harness) -> [String] {
    ["\(h.workspace.camera)"] + h.system.allWindows().map { "\($0.id) \($0.frame)" }
  }

  // MARK: Title bars

  @Test func doubleClickingATitleBarFramesTheWindowAndAgainGoesBack() {
    let (h, a, b, c) = makeHarness()
    let before = picture(h)

    #expect(h.system.doubleClick(at: titleBar(h, a)))
    #expect(h.workspace.camera == h.workspace.tree.leaf(containing: a))
    #expect(h.frame(a) == h.visibleFrame.insetBy(dx: 12, dy: 12))
    #expect(!h.system.isVisible(b) && !h.system.isVisible(c))
    #expect(h.system.focused == a)
    expectWindowsMatchLayout(h, on: h.display)

    #expect(h.system.doubleClick(at: titleBar(h, a)), "its title bar is at the top of the screen now")
    #expect(h.workspace.camera == h.workspace.tree.root)
    #expect(picture(h) == before)
  }

  @Test func goingBackReturnsToWhereverTheCameraWas() {
    let (h, a, _, c) = makeHarness()
    h.run("dock \(c.rawValue) beside \(a.rawValue) bottom")
    let column = h.workspace.tree.parent(of: h.workspace.tree.leaf(containing: a)!)!
    h.run("zoom-node \(column.rawValue)")
    #expect(h.system.doubleClick(at: titleBar(h, c)))
    #expect(h.workspace.camera == h.workspace.tree.leaf(containing: c))
    #expect(h.system.doubleClick(at: titleBar(h, c)))
    #expect(h.workspace.camera == column, "not all the way out")
  }

  @Test func afterWalkingFromNeighbourToNeighbourItStepsOut() {
    // Going back would only frame the window before this one. A second ⌃⌥↩ decides the same way.
    let (h, a, b, _) = makeHarness()
    h.system.doubleClick(at: titleBar(h, a))
    h.run("neighbor right")
    h.run("neighbor right")
    #expect(h.workspace.camera == h.workspace.tree.leaf(containing: b))
    #expect(h.system.doubleClick(at: titleBar(h, b)))
    #expect(h.workspace.camera == h.workspace.tree.root)

    h.run("zoom \(a.rawValue)")
    h.run("desktop")
    #expect(h.system.doubleClick(at: bareDesktop(h)))
    #expect(h.workspace.camera == h.workspace.tree.root, "the Desktop likewise: not back onto the window")
  }

  @Test func aSecondDoubleClickDoesWhatASecondFrameShortcutDoes() {
    // One rule (`wayOut`), so the two cannot drift apart. Each line: how the view got onto a.
    for path in [["zoom 101"], ["zoom 103", "neighbor up"], ["zoom 102", "neighbor left", "neighbor left", "in"], ["zoom 103", "out", "in"], ["desktop", "zoom 101"]] {
      func arrive() -> (Harness, WindowID) {
        let (h, a, _, c) = makeHarness()
        h.run("dock \(c.rawValue) beside \(a.rawValue) bottom")
        h.system.cursor = h.frame(a)!.center
        for command in path { h.run(command) }
        h.system.focus(a)
        return (h, a)
      }
      let (keys, a) = arrive()
      #expect(keys.workspace.camera == keys.workspace.tree.leaf(containing: a), "\(path)")
      keys.run("zoom")
      let (mouse, _) = arrive()
      #expect(mouse.system.doubleClick(at: titleBar(mouse, a)), "\(path)")
      #expect(mouse.workspace.camera == keys.workspace.camera, "\(path)")
    }
  }

  /// F51: a peek stood in for Show Everything, so the way out of where it landed is everything, for ⌃⌥↩ and for the
  /// double-click alike.
  @Test func afterAPeekLandedTheSecondDoubleClickShowsEverything() {
    let h = Harness(settings: Self.titleBarsOn)
    let a = h.system.open(app: "Safari")
    let b = h.system.open(app: "Notes")
    let c = h.system.open(app: "Mail")
    h.start()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) right")
    h.run("dock \(c.rawValue) beside \(a.rawValue) bottom")
    let whereCShows = h.frame(c)!.center
    h.run("zoom \(a.rawValue)")
    h.system.userFocus(a)
    h.keyDown("ctrl+opt+space")
    h.scheduler.advance(by: 0.4)
    h.system.cursor = whereCShows
    h.scheduler.advance(by: 0.1)
    h.keyUp("ctrl+opt+space")
    #expect(h.workspace.camera == h.workspace.tree.leaf(containing: c))

    #expect(h.controller.doubleClickZones().action(at: titleBar(h, c)) == .showAll)
    #expect(h.system.doubleClick(at: titleBar(h, c)))
    #expect(h.workspace.camera == h.workspace.tree.root, "not the column that c shares with a, nor a, where the peek began")
  }

  @Test func aWindowFramedSomeOtherWayGoesBackToo() {
    let (h, a, _, _) = makeHarness()
    h.run("zoom \(a.rawValue)")
    #expect(h.system.doubleClick(at: titleBar(h, a)))
    #expect(h.workspace.camera == h.workspace.tree.root)
  }

  @Test func aFramedWindowWithNoHistoryStepsOut() {
    // On a leaf with nothing to go back to. A launch ends showing everything, so this is the watchdog's restart, which keeps the
    // view, from a state file written before the camera's moves were recorded; the other window is still in its corner.
    var workspace = Workspace()
    workspace.dock(WindowID(101), at: .cameraEdge(.left))
    workspace.dock(WindowID(102), at: .cameraEdge(.right))
    workspace.moveCamera(to: workspace.tree.leaf(containing: WindowID(101))!, record: false)
    let display = FakeWindowSystem.standardDisplay.id
    let h = Harness(settings: Self.titleBarsOn, saved: PersistedState(workspaces: [display: workspace], hints: [:]))
    let a = h.system.open(app: "Safari")
    let b = h.system.open(app: "Notes", frame: CGRect(x: 1439, y: 899, width: 600, height: 400))
    h.controller.restartedAfterAccident = true
    h.start()
    #expect(h.workspace.camera == h.workspace.tree.leaf(containing: a))
    #expect(h.workspace.back.isEmpty)

    #expect(h.system.doubleClick(at: titleBar(h, a)))
    #expect(h.workspace.camera == h.workspace.tree.root)
    #expect(h.system.isVisible(a) && h.system.isVisible(b))
  }

  @Test func aWindowLeftAloneInItsGroupCountsAsFramed() {
    // The camera is on the column [a / c]. With c minimized, a fills the view: framing it "again"
    // would change nothing on screen, now or on the next double-click.
    let (h, a, b, c) = makeHarness()
    h.run("dock \(c.rawValue) beside \(a.rawValue) bottom")
    let column = h.workspace.tree.parent(of: h.workspace.tree.leaf(containing: a)!)!
    h.run("zoom-node \(column.rawValue)")
    h.system.setMinimized(c, true)
    #expect(h.frame(a) == h.visibleFrame.insetBy(dx: 12, dy: 12))

    #expect(h.system.doubleClick(at: titleBar(h, a)))
    #expect(h.workspace.camera == h.workspace.tree.root)
    #expect(h.system.isVisible(b))
  }

  @Test func goingBackToAViewThatLooksTheSameStepsOutInstead() {
    // Framed a, stepped out to the column [a / c], minimized c: a fills the view, and the place to
    // go back to (a on its own) looks exactly like this one.
    let (h, a, b, c) = makeHarness()
    h.run("dock \(c.rawValue) beside \(a.rawValue) bottom")
    h.run("zoom \(a.rawValue)")
    h.run("out")
    h.system.setMinimized(c, true)
    #expect(h.workspace.back.last == h.workspace.tree.leaf(containing: a))

    #expect(h.system.doubleClick(at: titleBar(h, a)))
    #expect(h.workspace.camera == h.workspace.tree.root)
    #expect(h.system.isVisible(b))
  }

  /// One rule for three (`wayOut(of:on:)`): ⌃⌥↩ pressed again, a second double-click, and whether the menu offers the row.
  /// A window always has something wider, since the Desktop always takes room. The Desktop has not: with every docked
  /// window away, everything, where the camera came from, looks exactly like it.
  @Test func theMenuOffersFrameExactlyWhereTheKeyHasSomewhereToGo() {
    let (h, a, b, c) = makeHarness()
    func row() -> MenuModel.Item? { h.controller.menuModel().item("Frame Focused Window") }
    func way() -> Command? { h.controller.doubleClickZones().displays.first { $0.id == h.display }?.unframe }
    h.system.userFocus(c)
    h.run("desktop")
    let desktop = h.workspace.tree.desktop
    #expect(h.workspace.camera == desktop)
    #expect(h.workspace.back.last == h.workspace.tree.root)
    #expect(way() == .back)
    #expect(row()?.isEnabled == true)

    h.system.setMinimized(a, true)
    h.system.setMinimized(b, true)
    h.system.userFocus(c)
    #expect(h.workspace.back.last == h.workspace.tree.root, "still an ancestor, which is all the menu once asked")
    #expect(way() == nil)
    #expect(row()?.isEnabled == false)
    #expect(!h.run("zoom", from: .menu).ok, "as the command says")
    #expect(h.workspace.camera == desktop)

    h.system.setMinimized(a, false)
    h.system.userFocus(c)
    #expect(row()?.isEnabled == true)
    #expect(h.run("zoom", from: .menu).ok)
    #expect(h.workspace.camera == h.workspace.tree.root)
  }

  @Test func theTitleBarIs28PointsTallUnlessSettingsSayOtherwise() {
    let (h, a, _, _) = makeHarness()
    let frame = h.frame(a)!
    #expect(!h.system.doubleClick(at: CGPoint(x: frame.midX, y: frame.minY + 28)))
    #expect(h.system.doubleClick(at: CGPoint(x: frame.midX, y: frame.minY + 27)))

    var settings = Self.bothOn
    settings.titleBarHeight = 52
    let (tall, window, _, _) = makeHarness(settings: settings)
    let tallFrame = tall.frame(window)!
    #expect(!tall.system.doubleClick(at: CGPoint(x: tallFrame.midX, y: tallFrame.minY + 52)))
    #expect(tall.system.doubleClick(at: CGPoint(x: tallFrame.midX, y: tallFrame.minY + 51)))
  }

  @Test func aWindowThatCannotFillItsSlotHasItsTitleBarWhereItReallyIs() {
    // Calculator, System Settings: centred in the slot, so the top of the slot is bare.
    let h = Harness(settings: Self.titleBarsOn)
    let a = h.system.open(app: "Calculator", frame: CGRect(x: 100, y: 100, width: 230, height: 400))
    h.system.setMaximumSize(a, CGSize(width: 230, height: 400))
    let b = h.system.open(app: "Notes")
    h.start()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) right")
    let slot = h.layout!.windowFrames[a]!
    #expect(h.frame(a)!.minY > slot.minY + 100)
    #expect(!h.system.doubleClick(at: CGPoint(x: slot.midX, y: slot.minY + 12)), "nothing is there")
    #expect(h.system.doubleClick(at: titleBar(h, a)))
    #expect(h.workspace.camera == h.workspace.tree.leaf(containing: a))
    #expect(h.system.doubleClick(at: titleBar(h, a)), "in the middle of the view now")
    #expect(h.workspace.camera == h.workspace.tree.root)
  }

  @Test func titleBarDoubleClicksCanBeTurnedOff() {
    var settings = Self.bothOn
    settings.titleBarDoubleClick = false
    let (h, a, _, _) = makeHarness(settings: settings)
    let before = picture(h)
    #expect(!h.system.doubleClick(at: titleBar(h, a)))
    #expect(picture(h) == before)
    #expect(h.system.doubleClick(at: bareDesktop(h)), "the Desktop has its own switch")
  }

  // MARK: The Desktop

  @Test func doubleClickingTheDesktopFocusesItAndAgainGoesBack() {
    let (h, a, b, c) = makeHarness()
    let before = picture(h)

    #expect(h.system.doubleClick(at: bareDesktop(h)))
    #expect(h.workspace.camera == h.workspace.tree.desktop)
    #expect(h.layout?.desktopFrame == h.visibleFrame.insetBy(dx: 12, dy: 12))
    #expect(!h.system.isVisible(a) && !h.system.isVisible(b))
    #expect(h.system.isVisible(c), "floating windows live on the Desktop")

    #expect(h.system.doubleClick(at: bareDesktop(h)))
    #expect(h.workspace.camera == h.workspace.tree.root)
    #expect(picture(h) == before)
  }

  @Test func theDesktopsDoubleClickHasItsOwnSwitch() {
    let (h, a, _, _) = makeHarness(settings: Self.titleBarsOn)
    let before = picture(h)
    #expect(!h.system.doubleClick(at: bareDesktop(h)))
    #expect(picture(h) == before)
    #expect(h.system.doubleClick(at: titleBar(h, a)), "title bars have their own switch")
  }

  /// Each until `scripts/mac-shell/check-F14.sh` has nothing to say against it on a hosted Mac. With both off there is
  /// nothing to tap for, so nothing of F14 stands between the pointer and the apps.
  @Test func bothDoubleClicksAreOffByDefault() {
    let (h, a, _, _) = makeHarness(settings: Settings())
    let before = picture(h)
    #expect(!h.controller.inputSettings.wantsDoubleClickTap)
    #expect(h.controller.doubleClickZones() == DoubleClickZones())
    #expect(!h.system.doubleClick(at: titleBar(h, a)))
    #expect(!h.system.doubleClick(at: bareDesktop(h)))
    #expect(picture(h) == before)
    #expect(h.run("set titleBarDoubleClick true").ok)
    #expect(!h.controller.inputSettings.wantsDoubleClickTap, "not without the switch above every event tap")
    #expect(!h.system.doubleClick(at: titleBar(h, a)))
    #expect(h.run("set pointerGestures true").ok)
    #expect(h.system.doubleClick(at: titleBar(h, a)), "two commands turn it on")
    #expect(h.workspace.camera == h.workspace.tree.leaf(containing: a))
  }

  /// `pointerGestures`: off, Arbor installs no event tap, whatever the settings below it say.
  @Test func withoutTheSwitchAboveEveryEventTapThereIsNoTapAndNoZone() {
    var settings = Self.bothOn
    settings.pointerGestures = false
    let (h, a, _, _) = makeHarness(settings: settings)
    #expect(!h.controller.inputSettings.wantsDoubleClickTap)
    #expect(h.controller.doubleClickZones() == DoubleClickZones())
    #expect(!h.system.doubleClick(at: titleBar(h, a)))
    #expect(!h.system.doubleClick(at: bareDesktop(h)))
    #expect(h.controller.settings.titleBarDoubleClick && h.controller.settings.desktopDoubleClick, "the person's own settings are untouched")
  }

  @Test func withNothingDockedDoubleClicksOnTheDesktopAreNotArbors() {
    // A Mac Arbor is not arranging: double-clicking a file on the Desktop must simply open it.
    let h = Harness(settings: Self.bothOn)
    h.system.open(app: "Safari", frame: CGRect(x: 100, y: 100, width: 600, height: 400))
    h.start()
    #expect(!h.system.doubleClick(at: CGPoint(x: 1000, y: 700)))
    #expect(h.controller.doubleClickZones().action(at: CGPoint(x: 1000, y: 700)) == nil)
    #expect(h.workspace.back.isEmpty)
  }

  @Test func onASpaceWithNothingDockedTheCameraStaysWhereItIs() {
    // Everything docked is on another Space, so this one shows bare Desktop wherever the camera is.
    // Moving it now would change nothing here and surprise the user back on the first Space.
    let (h, a, b, c) = makeHarness()
    h.run("zoom \(a.rawValue)")
    h.run("show-all")
    for window in [a, b, c] { h.system.setOnActiveSpace(window, false) }
    h.scheduler.runPending()
    let camera = h.workspace.camera
    #expect(h.layout?.desktopFrame == h.visibleFrame.insetBy(dx: 12, dy: 12))
    #expect(!h.workspace.back.isEmpty)

    #expect(!h.system.doubleClick(at: CGPoint(x: 700, y: 400)))
    #expect(h.workspace.camera == camera)
  }

  @Test func onlyFloatingWindowsInViewCoverTheDesktop() {
    let (h, _, _, c) = makeHarness()
    let onC = h.frame(c)!.center
    #expect(!h.system.doubleClick(at: onC))
    h.system.setMinimized(c, true)
    #expect(h.system.doubleClick(at: onC), "nothing is there any more")
    #expect(h.workspace.camera == h.workspace.tree.desktop)
  }

  @Test func aFloatingWindowCoversTheDesktopWhereverTheUserDragsIt() {
    let (h, _, _, c) = makeHarness()
    let desktop = h.layout!.desktopFrame!
    let old = h.frame(c)!.center
    h.system.userMove(c, to: CGRect(x: desktop.minX + 10, y: desktop.maxY - 210, width: 300, height: 200))
    #expect(!h.system.doubleClick(at: h.frame(c)!.center))
    #expect(h.system.doubleClick(at: old))
  }

  @Test func windowsArborDoesNotArrangeKeepTheirDoubleClicks() {
    let (h, a, _, c) = makeHarness()
    h.run("exclude com.example.mail")
    #expect(!h.workspace.contains(c))
    #expect(!h.system.doubleClick(at: h.frame(c)!.center), "over the Desktop")
    // Dragged over a docked window's title bar.
    let bar = titleBar(h, a)
    h.system.userMove(c, to: CGRect(x: bar.x - 150, y: bar.y - 10, width: 300, height: 200))
    #expect(!h.system.doubleClick(at: bar))
    #expect(h.workspace.camera == h.workspace.tree.root)
    h.system.setMinimized(c, true)
    #expect(h.system.doubleClick(at: bar))
  }

  // MARK: Everything else

  @Test func doubleClicksInContentOnFloatingWindowsAndInGapsDoNothing() {
    let (h, a, b, c) = makeHarness()
    let before = picture(h)
    h.system.clearFrameLog()
    let floating = h.frame(c)!
    let points: [(String, CGPoint)] = [
      ("a's content", h.frame(a)!.center),
      ("just below b's title bar", CGPoint(x: h.frame(b)!.midX, y: h.frame(b)!.minY + 30)),
      ("the floating window's title bar", CGPoint(x: floating.midX, y: floating.minY + 12)),
      ("the floating window's content", floating.center),
      ("the gap between a and the Desktop", CGPoint(x: h.frame(a)!.maxX + 6, y: 400)),
      ("the margin at the screen edge", CGPoint(x: 4, y: 400)),
      ("the menu bar", CGPoint(x: 700, y: 10)),
      ("off every display", CGPoint(x: -300, y: 5000)),
    ]
    for (what, point) in points {
      #expect(!h.system.doubleClick(at: point), "\(what)")
    }
    #expect(picture(h) == before)
    #expect(h.system.frameLog.isEmpty)
    #expect(h.workspace.back.isEmpty, "nothing went into the history either")
  }

  @Test func theDisplayThatWasClickedMoves() {
    let side = DisplaySnapshot(
      id: DisplayID("side"), frame: CGRect(x: 1440, y: 0, width: 1280, height: 800),
      visibleFrame: CGRect(x: 1440, y: 0, width: 1280, height: 800), isMain: false)
    let h = Harness(displays: [FakeWindowSystem.standardDisplay, side], settings: Self.bothOn)
    let main = h.system.open(app: "Safari", frame: CGRect(x: 100, y: 100, width: 600, height: 400))
    let left = h.system.open(app: "Notes", frame: CGRect(x: 1500, y: 100, width: 500, height: 400))
    let right = h.system.open(app: "Mail", frame: CGRect(x: 2100, y: 100, width: 500, height: 400))
    h.start()
    h.run("dock \(main.rawValue) left")
    h.run("dock \(left.rawValue) left")
    h.run("dock \(right.rawValue) right")
    func sideWorkspace() -> Workspace { h.controller.workspaces[side.id]! }

    #expect(h.system.doubleClick(at: titleBar(h, right)))
    #expect(sideWorkspace().camera == sideWorkspace().tree.leaf(containing: right))
    #expect(h.workspace.camera == h.workspace.tree.root, "the main display does not move")
    #expect(h.system.doubleClick(at: titleBar(h, right)))
    #expect(sideWorkspace().camera == sideWorkspace().tree.root)

    let desktop = h.controller.layouts[side.id]!.desktopFrame!
    #expect(h.system.doubleClick(at: desktop.center))
    #expect(sideWorkspace().camera == sideWorkspace().tree.desktop)
    #expect(h.workspace.camera == h.workspace.tree.root)
    #expect(h.system.isVisible(main))
    #expect(h.system.doubleClick(at: desktop.center))
    #expect(sideWorkspace().camera == sideWorkspace().tree.root)
    expectWindowsMatchLayout(h, on: side.id)
  }

  /// Shortcuts may follow the keyboard (F56). A double-click is made with the pointer, and `back` and `out` name no display.
  @Test func aDoubleClickActsWhereThePointerIsWhateverShortcutsFollow() {
    let side = DisplaySnapshot(
      id: DisplayID("side"), frame: CGRect(x: 1440, y: 0, width: 1280, height: 800),
      visibleFrame: CGRect(x: 1440, y: 0, width: 1280, height: 800), isMain: false)
    var settings = Self.bothOn
    settings.stepInToward = "focus"
    let h = Harness(displays: [FakeWindowSystem.standardDisplay, side], settings: settings)
    let main = h.system.open(app: "Safari", frame: CGRect(x: 100, y: 100, width: 600, height: 400))
    let left = h.system.open(app: "Notes", frame: CGRect(x: 1500, y: 100, width: 500, height: 400))
    let right = h.system.open(app: "Mail", frame: CGRect(x: 2100, y: 100, width: 500, height: 400))
    h.start()
    h.run("dock \(main.rawValue) left")
    h.run("dock \(left.rawValue) left")
    h.run("dock \(right.rawValue) right")
    func sideWorkspace() -> Workspace { h.controller.workspaces[side.id]! }

    #expect(h.system.doubleClick(at: titleBar(h, right)))
    #expect(sideWorkspace().camera == sideWorkspace().tree.leaf(containing: right))
    h.system.userFocus(main)
    #expect(h.system.doubleClick(at: titleBar(h, right)), "not `back` on the display that has the keyboard")
    #expect(sideWorkspace().camera == sideWorkspace().tree.root)
    #expect(h.workspace.camera == h.workspace.tree.root)
  }

  @Test func doubleClicksBeforeStartingAndAfterQuittingAreNotArbors() {
    let h = Harness()
    h.system.open(app: "Safari")
    #expect(h.controller.doubleClickZones() == DoubleClickZones())
    #expect(!h.controller.doubleClicked(at: CGPoint(x: 700, y: 400)))

    let (running, a, _, _) = makeHarness()
    let point = titleBar(running, a)
    running.controller.shutdown()
    #expect(running.controller.doubleClickZones() == DoubleClickZones())
    #expect(!running.system.doubleClick(at: point))
  }

  @Test func pausingTakesTheTapAway() {
    let (h, a, _, _) = makeHarness()
    let point = titleBar(h, a)
    #expect(h.controller.inputSettings.wantsDoubleClickTap)
    h.run("pause")
    #expect(!h.controller.inputSettings.wantsDoubleClickTap, "no click passes through Arbor meanwhile")
    #expect(h.controller.doubleClickZones() == DoubleClickZones())
    #expect(!h.system.doubleClick(at: point))
    h.run("resume")
    #expect(h.controller.inputSettings.wantsDoubleClickTap)
    #expect(h.system.doubleClick(at: titleBar(h, a)))
  }

  /// F41: no event passes through Arbor while an app that keeps its own ⌃⌥ is in front, and the tap's copy of the
  /// zones hears of it.
  @Test func anAppThatKeepsItsOwnKeysTakesTheTapAwayToo() {
    var settings = Self.bothOn
    settings.passThroughApps = ["com.example.safari"]
    let (h, a, b, _) = makeHarness(settings: settings)
    var copy = DoubleClickZones()
    h.controller.observe { change in
      // As `DoubleClickTap.follow` does.
      if case .focus = change { return }
      copy = h.controller.doubleClickZones()
    }
    let (bar, desktop) = (titleBar(h, b), bareDesktop(h))
    h.system.userFocus(b)
    #expect(h.controller.inputSettings.wantsDoubleClickTap)

    h.system.userFocus(a)
    #expect(!h.controller.inputSettings.wantsDoubleClickTap)
    #expect(h.controller.doubleClickZones().displays.allSatisfy { $0.titleBars.isEmpty && $0.desktop == nil })
    #expect(copy == h.controller.doubleClickZones())
    // Its own title bar: a click on another app's window would bring that app to the front, and the taps back.
    #expect(!h.system.doubleClick(at: titleBar(h, a)))
    #expect(!h.system.doubleClick(at: desktop))
    #expect(h.workspace.camera == h.workspace.tree.root)

    h.system.userFocus(b)
    #expect(h.controller.inputSettings.wantsDoubleClickTap)
    #expect(copy == h.controller.doubleClickZones())
    #expect(h.system.doubleClick(at: bar))
  }

  /// F63: without Accessibility permission Arbor can frame nothing, so it takes no click either.
  @Test func withoutAccessibilityPermissionNoDoubleClickIsArbors() {
    let h = Harness(settings: Self.bothOn)
    h.watchAccessibility()
    let a = h.system.open(app: "Safari")
    let b = h.system.open(app: "Notes")
    h.start()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) right")
    let bar = titleBar(h, a)
    #expect(h.controller.inputSettings.wantsDoubleClickTap)

    h.revokeAccessibility()
    h.scheduler.advance(by: 3)
    #expect(!h.controller.inputSettings.wantsDoubleClickTap)
    #expect(h.controller.doubleClickZones() == DoubleClickZones())
    #expect(!h.system.doubleClick(at: bar))

    h.grantAccessibility()
    h.scheduler.advance(by: 3)
    #expect(h.controller.inputSettings.wantsDoubleClickTap)
    #expect(h.system.doubleClick(at: bar))
    #expect(h.workspace.camera == h.workspace.tree.leaf(containing: a))
  }

  /// F58: on a held view the taps stay, so that macOS's own title-bar action does not run in front of an audience. The
  /// double-click is still Arbor's to hide, and what it would run is refused like any command that moves the view.
  @Test func onAHeldViewADoubleClickMovesNothingAndIsStillHidden() {
    let (h, a, _, _) = makeHarness()
    let bar = titleBar(h, a)
    let before = picture(h)
    #expect(h.run("hold").ok)
    #expect(h.controller.inputSettings.wantsDoubleClickTap, "or macOS would zoom the docked window")
    #expect(!h.controller.inputSettings.gesturesEnabled, "the hold's own doing")
    #expect(h.controller.doubleClickZones().hit(at: bar)?.hidesClickFromApps == true)
    h.system.clearFrameLog()
    #expect(h.system.doubleClick(at: bar), "Arbor's, though what it would run is refused")
    #expect(picture(h) == before)
    #expect(h.system.frameLog.isEmpty)

    #expect(h.run("release").ok)
    #expect(h.system.doubleClick(at: bar))
    #expect(h.workspace.camera == h.workspace.tree.leaf(containing: a))
  }

  /// `hold still` keeps Arbor from moving the view by itself. A double-click is the user's own hand.
  @Test func holdingStillADoubleClickWorks() {
    let (h, a, _, _) = makeHarness()
    #expect(h.run("hold still").ok)
    #expect(h.controller.inputSettings.wantsDoubleClickTap)
    #expect(h.system.doubleClick(at: titleBar(h, a)))
    #expect(h.workspace.camera == h.workspace.tree.leaf(containing: a))
    #expect(h.system.doubleClick(at: titleBar(h, a)))
    #expect(h.workspace.camera == h.workspace.tree.root)
  }

  /// The event tap decides from a copy of the zones that it refreshes whenever an observer is told of
  /// a change. The copy must never be out of date (floating frames aside: see `doubleClickZones`).
  @Test func observersAlwaysHoldTheCurrentZones() {
    let h = Harness(settings: Self.bothOn)
    var copy = DoubleClickZones()
    h.controller.observe { _ in copy = h.controller.doubleClickZones() }
    func expectCurrent(_ what: String, sourceLocation: SourceLocation = #_sourceLocation) {
      #expect(copy == h.controller.doubleClickZones(), "\(what)", sourceLocation: sourceLocation)
    }
    let a = h.system.open(app: "Safari", frame: CGRect(x: 100, y: 100, width: 600, height: 400))
    let b = h.system.open(app: "Notes", frame: CGRect(x: 300, y: 200, width: 600, height: 400))
    let c = h.system.open(app: "Mail", frame: CGRect(x: 560, y: 300, width: 300, height: 200))
    h.start()
    expectCurrent("start")
    for command in [
      "dock \(a.rawValue) left", "dock \(b.rawValue) right", "zoom \(a.rawValue)", "back", "forward", "out", "desktop",
      "show-all", "dock \(c.rawValue) beside \(a.rawValue) bottom", "resize \(a.rawValue) right 60", "in", "neighbor right",
      "save-view 1", "show-all", "view 1", "float \(c.rawValue)", "arrange", "float-all", "exclude com.example.mail",
      "include com.example.mail", "relayout", "reload-settings",
    ] {
      h.run(command)
      expectCurrent(command)
    }
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) right")
    h.system.setMinimized(b, true)
    expectCurrent("minimize")
    h.system.setMinimized(b, false)
    expectCurrent("restore")
    h.overlays.dragSeam(h.overlays.seams[h.display]!.first!, by: 40)
    expectCurrent("seam drag")
    let slot = h.frame(a)!
    h.system.userResize(a, to: CGRect(x: slot.minX, y: slot.minY, width: slot.width + 50, height: slot.height))
    expectCurrent("edge resize")
    h.system.drag(a, through: [CGPoint(x: slot.midX, y: slot.minY + 10), h.layout!.desktopFrame!.center])
    expectCurrent("drag off")
    h.system.close(b)
    expectCurrent("close")
    var settings = h.controller.settings
    settings.titleBarHeight = 40
    settings.desktopDoubleClick = false
    h.controller.apply(settings: settings)
    expectCurrent("settings")
    h.system.setDisplays([
      DisplaySnapshot(
        id: h.display, frame: CGRect(x: 0, y: 0, width: 1920, height: 1080),
        visibleFrame: CGRect(x: 0, y: 25, width: 1920, height: 1055), isMain: true)
    ])
    expectCurrent("display change")
    h.controller.shutdown()
    expectCurrent("shutdown")
    #expect(copy == DoubleClickZones())
  }
}

/// One double-click, one answer: with the switch on it is Arbor's or macOS's, never both (`AppsDoubleClickStaysTests` has the
/// switch off).
@Suite @MainActor struct OneDoubleClickOneAnswerTests {
  /// root(h)[a, Desktop, b] showing everything.
  func makeHarness(settings: Settings) -> (Harness, WindowID, WindowID) {
    let h = Harness(settings: settings)
    let a = h.system.open(app: "Safari", frame: CGRect(x: 100, y: 100, width: 600, height: 400))
    let b = h.system.open(app: "Notes", frame: CGRect(x: 300, y: 200, width: 600, height: 400))
    h.start()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) right")
    h.scheduler.advance(by: 5)
    h.system.clearFrameLog()
    return (h, a, b)
  }

  func titleBar(_ h: Harness, _ window: WindowID) -> CGPoint {
    let frame = h.frame(window)!
    return CGPoint(x: frame.midX, y: frame.minY + 12)
  }

  /// With the switch on, the tap stands aside for a modifier, a control, an unknown thing under the pointer, an app that
  /// does not answer, and while macOS has the taps switched off. The Accessibility layer then hears the press, as here.
  @Test func withTheSwitchOnWhatTheTapLetsThroughIsMacOSsToo() {
    let (h, a, _) = makeHarness(settings: DoubleClickTests.titleBarsOn)
    h.controller.doubleClickReached(a)
    h.system.userMove(a, to: h.visibleFrame)
    h.scheduler.advance(by: 5)
    #expect(h.frame(a) == h.visibleFrame)
    #expect(h.system.frameLog.isEmpty)
    #expect(h.workspace.camera == h.workspace.tree.root, "and Arbor ran nothing")
    // Its title bar is where the window really is, and from there Arbor frames it: one move, to the view less the gap.
    #expect(h.system.doubleClick(at: titleBar(h, a)))
    #expect(h.workspace.camera == h.workspace.tree.leaf(containing: a))
    expectWindowsMatchLayout(h, on: h.display)
  }

  /// A double-click with a modifier key held is never Arbor's.
  @Test func withCommandHeldItIsMacOSs() {
    let (h, a, _) = makeHarness(settings: DoubleClickTests.titleBarsOn)
    h.system.heldModifiers = .command
    h.system.doubleClickTitleBar(of: a)
    h.system.heldModifiers = []
    h.scheduler.advance(by: 5)
    #expect(h.workspace.camera == h.workspace.tree.root)
    #expect(h.frame(a) == h.visibleFrame, "macOS zoomed it, and it stays")
    #expect(h.system.frameLog.isEmpty)
  }

  /// And where Arbor takes it, no app hears of the second press, so there is nothing to stand aside for.
  @Test func aDoubleClickThatIsArborsLeavesNoNote() {
    let (h, a, _) = makeHarness(settings: DoubleClickTests.titleBarsOn)
    #expect(h.system.doubleClick(at: titleBar(h, a)))
    let framed = h.frame(a)!
    h.system.userMove(a, to: h.visibleFrame)
    h.scheduler.advance(by: 1)
    #expect(h.frame(a) == framed, "a window that moves by itself afterwards is put back")
  }
}

/// F14: tiles open on one click, and the second click of a double-click on one goes nowhere.
@Suite @MainActor struct TileClickTests {
  /// [a | Desktop | column(b, big)], where big refuses its slot and is a tile, below b or above it.
  /// Returns the tile.
  func makeHarness(
    settings: Settings = DoubleClickTests.titleBarsOn, tileOnTop: Bool = false
  ) -> (Harness, WindowID, TileModel) {
    // Or the Desktop and the neighbours would give big the room it wants (F61), and there would be no tile.
    var settings = settings
    settings.makeRoom = false
    let h = Harness(settings: settings)
    let a = h.system.open(app: "Safari", frame: CGRect(x: 100, y: 100, width: 600, height: 400))
    let b = h.system.open(app: "Notes", frame: CGRect(x: 300, y: 200, width: 600, height: 400))
    let big = h.system.open(app: "Xcode", frame: CGRect(x: 400, y: 200, width: 700, height: 500))
    h.system.setMinimumSize(big, CGSize(width: 900, height: 600))
    h.start()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) right")
    h.run("dock \(big.rawValue) beside \(b.rawValue) \(tileOnTop ? "top" : "bottom")")
    h.run("show-all")
    return (h, big, h.overlays.tiles[h.display]!.first!)
  }

  @Test func theSecondClickOfADoubleClickOnATileGoesNowhere() {
    // Someone who knows TrellisWM double-clicks. The first click opens the tile; by the second, the
    // window that was framed is under the pointer, and the click would land in the middle of it.
    let (h, big, tile) = makeHarness()
    h.overlays.clickTile(tile.node)
    #expect(h.workspace.camera == h.workspace.tree.leaf(containing: big))
    h.system.clearFrameLog()
    h.scheduler.advance(by: 0.2)
    #expect(h.system.secondClick(at: tile.frame.center), "Arbor takes it")
    #expect(h.workspace.camera == h.workspace.tree.leaf(containing: big), "and does nothing with it")
    #expect(h.system.frameLog.isEmpty)
  }

  @Test func aDoubleClickOnATileAtTheTopDoesNotOpenItAndGoStraightBack() {
    // Where this tile was, the framed window now has its title bar, and double-clicking that goes back.
    let (h, big, tile) = makeHarness(tileOnTop: true)
    let point = CGPoint(x: tile.frame.midX, y: tile.frame.minY + 10)
    h.overlays.clickTile(tile.node)
    #expect(h.controller.doubleClickZones().action(at: point) == .back, "the point is on the title bar")
    h.scheduler.advance(by: 0.2)
    #expect(h.system.secondClick(at: point))
    #expect(h.workspace.camera == h.workspace.tree.leaf(containing: big))
  }

  @Test func afterTheDoubleClickTimeTheSpotIsOrdinaryAgain() {
    let (h, big, tile) = makeHarness(tileOnTop: true)
    h.overlays.clickTile(tile.node)
    h.scheduler.advance(by: 0.6)
    #expect(!h.system.doubleClick(at: tile.frame.center), "a double-click in the window's content is the app's")
    #expect(h.workspace.camera == h.workspace.tree.leaf(containing: big))
    #expect(h.system.doubleClick(at: CGPoint(x: tile.frame.midX, y: tile.frame.minY + 10)))
    #expect(h.workspace.camera == h.workspace.tree.root, "and one on its title bar goes back")
  }

  @Test func onlyAClickOnTheTileLeavesASpotBehind() {
    let (h, _, tile) = makeHarness()
    h.run("zoom-node \(tile.node.rawValue)")
    #expect(!h.system.doubleClick(at: tile.frame.center))
    #expect(h.controller.doubleClickZones().openedTile == nil)
  }

  @Test func withoutTheTapNoSecondClickCanBeSwallowed() {
    let settings = Settings()
    let (h, _, tile) = makeHarness(settings: settings)
    #expect(!settings.wantsDoubleClickTap)
    h.overlays.clickTile(tile.node)
    #expect(!h.system.secondClick(at: tile.frame.center), "what the fakes say is what the Mac would do")
  }

  @Test func theTapHearsOfAnOpenedTileTogetherWithTheNewLayout() {
    let (h, _, tile) = makeHarness()
    var copies: [DoubleClickZones] = []
    h.controller.observe { _ in copies.append(h.controller.doubleClickZones()) }
    h.overlays.clickTile(tile.node)
    #expect(!copies.isEmpty)
    #expect(copies.allSatisfy { $0.openedTile?.frame == tile.frame }, "no moment with the new layout and no spot")
  }

  /// Moving the windows takes a while on a Mac, and the second click may arrive before it is over.
  @Test func theTapHearsOfAnOpenedTileBeforeAnyWindowMoves() {
    let (h, _, tile) = makeHarness()
    h.system.clearFrameLog()
    var first: (moves: Int, spot: CGRect?)?
    h.controller.observe { _ in
      if first == nil { first = (h.system.frameLog.count, h.controller.doubleClickZones().openedTile?.frame) }
    }
    h.overlays.clickTile(tile.node)
    #expect(first?.moves == 0)
    #expect(first?.spot == tile.frame)
    #expect(!h.system.frameLog.isEmpty, "the control: windows did move")
  }

  @Test func doubleClicksOnTilesAreLeftToTheTiles() {
    // The tap must let both clicks through to the tile's panel, whatever lies under it.
    let (h, _, tile) = makeHarness()
    #expect(!h.system.doubleClick(at: tile.frame.center))
    #expect(!h.system.doubleClick(at: CGPoint(x: tile.frame.midX, y: tile.frame.minY + 10)))
    #expect(h.workspace.camera == h.workspace.tree.root)
  }

  @Test func aDesktopTooSmallToUseIsATileLikeAnyOther() {
    var settings = DoubleClickTests.bothOn
    settings.minimumUsableWidth = 500
    let h = Harness(settings: settings)
    let a = h.system.open(app: "Safari")
    let b = h.system.open(app: "Notes")
    h.start()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) right")
    h.run("resize \(a.rawValue) right 150")
    h.run("resize \(b.rawValue) left 150")
    guard let tile = h.overlays.tiles[h.display]?.first(where: { $0.kind == .desktop }) else {
      Issue.record("the Desktop should be a tile: \(h.ascii())")
      return
    }
    #expect(!h.system.doubleClick(at: tile.frame.center), "not the Desktop's double-click")
    h.overlays.clickTile(tile.node)
    #expect(h.workspace.camera == h.workspace.tree.desktop)
    // A double-click on that tile must not open the Desktop and go straight back either.
    #expect(h.system.secondClick(at: tile.frame.center))
    #expect(h.workspace.camera == h.workspace.tree.desktop)
    // Later, it fills the view like any framed Desktop, and double-clicking it goes back.
    h.scheduler.advance(by: 1)
    #expect(h.system.doubleClick(at: tile.frame.center))
    #expect(h.workspace.camera == h.workspace.tree.root)
  }
}
