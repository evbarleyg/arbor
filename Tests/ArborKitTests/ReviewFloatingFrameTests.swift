import ArborCore
import ArborKit
import ArborTesting
import CoreGraphics
import Testing

/// What a reader of F64 found in its first version, each as the story that showed it. All with the settings as they ship.
@Suite @MainActor struct ReviewFloatingFrameTests {
  static func display(_ id: String, _ frame: CGRect, top: CGFloat = 25, isMain: Bool = false) -> DisplaySnapshot {
    DisplaySnapshot(
      id: DisplayID(id), frame: frame,
      visibleFrame: CGRect(x: frame.minX, y: frame.minY + top, width: frame.width, height: frame.height - top), isMain: isMain)
  }

  /// `[a | Desktop]` with `f` floating.
  func makeHarness(displays: [DisplaySnapshot] = [FakeWindowSystem.standardDisplay], f: CGRect) -> (Harness, a: WindowID, b: WindowID, f: WindowID) {
    let h = Harness(displays: displays, settings: Settings())
    let a = h.system.open(app: "Safari", pid: 11, frame: CGRect(x: 100, y: 100, width: 600, height: 400))
    let b = h.system.open(app: "Notes", pid: 12, frame: CGRect(x: 300, y: 200, width: 600, height: 400))
    let f = h.system.open(app: "Mail", pid: 13, frame: f)
    h.start()
    h.run("dock \(a.rawValue) left")
    return (h, a, b, f)
  }

  // MARK: Undo

  /// What is remembered of a floating window can be behind the window: nobody tells Arbor what happens during a pause. An undo
  /// that is about another window went by what was remembered.
  @Test func anUndoOfAnotherWindowsDockLeavesAWindowMovedDuringAPauseWhereItIs() {
    let (h, _, b, f) = makeHarness(f: CGRect(x: 100, y: 100, width: 400, height: 300))
    h.run("pause")
    let chosen = CGRect(x: 700, y: 400, width: 400, height: 300)
    h.system.userMove(f, to: chosen)
    h.run("resume")
    h.run("dock \(b.rawValue) right")
    h.system.clearFrameLog()
    #expect(h.run("undo").ok)
    #expect(h.frame(f) == chosen)
    #expect(!h.system.frameLog.contains { $0.window == f })
    #expect(h.run("redo").ok)
    #expect(h.frame(f) == chosen)
  }

  /// So that it is behind as seldom as can be: a start takes the floating windows in view as it finds them.
  @Test func aStartRemembersFloatingWindowsInViewWhereTheyAre() {
    let (h, _, _, f) = makeHarness(f: CGRect(x: 100, y: 100, width: 400, height: 300))
    h.run("pause")
    let chosen = CGRect(x: 700, y: 400, width: 400, height: 300)
    h.system.userMove(f, to: chosen)
    h.run("resume")
    #expect(h.workspace.floating[f] == chosen)
  }

  // MARK: What is a place

  /// Half of it on one display, and its title bar on none: 20 points of it on the small display, fewer than a hand can get hold of
  /// (`titleBarIsWithinReach`), the rest above the top of the other.
  @Test func aTitleBarInTheDeadCornerBetweenTwoDisplaysIsNoPlace() {
    let (h, a, _, f) = makeHarness(
      displays: [Self.display("main", CGRect(x: 0, y: 0, width: 2560, height: 1440), isMain: true)],
      f: CGRect(x: 780, y: 187, width: 837, height: 622))
    h.run("zoom \(a.rawValue)")
    let after = [
      Self.display("main", CGRect(x: 0, y: 0, width: 800, height: 600), isMain: true),
      Self.display("side", CGRect(x: 800, y: 297, width: 2560, height: 1440)),
    ]
    h.system.setDisplays(after)
    h.run("show-all")
    let frame = h.frame(f)!
    #expect(after.contains { $0.visibleFrame.contains(CGRect(x: frame.minX, y: frame.minY, width: min(frame.width, 40), height: 20)) }, "\(frame)")
  }

  // MARK: What is noted of a window goes where the window goes

  /// Fitted for a display that shrank. The display then moves (another one becomes the main display) and grows back.
  @Test func whatWasFittedGoesBackThoughItsDisplayMovedMeanwhile() {
    let own = CGRect(x: 1000, y: 500, width: 400, height: 300)
    let (h, _, _, f) = makeHarness(f: own)
    h.system.setDisplays([Self.display("main", CGRect(x: 0, y: 0, width: 1024, height: 768), isMain: true)])
    let fitted = h.frame(f)!
    #expect(fitted == CGRect(x: 624, y: 468, width: 400, height: 300))
    // macOS takes the windows along.
    for window in h.system.allWindows() { h.system.moveSilently(window.id, to: window.frame.offsetBy(dx: 1920, dy: 0)) }
    h.system.setDisplays([
      Self.display("big", CGRect(x: 0, y: 0, width: 1920, height: 1080), isMain: true),
      Self.display("main", CGRect(x: 1920, y: 0, width: 1024, height: 768)),
    ])
    #expect(h.frame(f) == fitted.offsetBy(dx: 1920, dy: 0))
    h.system.setDisplays([
      Self.display("big", CGRect(x: 0, y: 0, width: 1920, height: 1080), isMain: true),
      Self.display("main", CGRect(x: 1920, y: 0, width: 1440, height: 900)),
    ])
    #expect(h.frame(f) == own.offsetBy(dx: 1920, dy: 0))
  }

  /// To its person another tab of a native tab group is the same window.
  @Test func aStripLeftByHandIsStillAStripWhenAnotherTabIsInFront() throws {
    let (h, a, _, f) = makeHarness(f: CGRect(x: 800, y: 300, width: 400, height: 300))
    let strip = CGRect(x: 1380, y: 500, width: 400, height: 300)
    h.system.userMove(f, to: strip)
    let tab = try #require(h.system.openTab(in: f))
    h.run("zoom \(a.rawValue)")
    h.run("show-all")
    #expect(h.frame(tab) == strip)
  }

  @Test func whatWasFittedGoesBackThoughAnotherTabIsInFront() throws {
    let own = CGRect(x: 1000, y: 500, width: 400, height: 300)
    let (h, _, _, f) = makeHarness(f: own)
    h.system.setDisplays([Self.display("main", CGRect(x: 0, y: 0, width: 1024, height: 768), isMain: true)])
    let tab = try #require(h.system.openTab(in: f))
    h.system.setDisplays([FakeWindowSystem.standardDisplay])
    #expect(h.frame(tab) == own)
  }

  // MARK: The setting goes off

  /// Its own frame is the one its person's hand gave it, hanging or not. With a column for the Desktop: there is one to be pushed onto.
  @Test func whenTheSettingGoesOffAWindowThatWasPushedAsideGoesBackToTheStripItsPersonLeft() {
    let h = Harness(settings: .makingWay.withDesktopColumn)
    let a = h.system.open(app: "Safari", pid: 11, frame: CGRect(x: 100, y: 100, width: 600, height: 400))
    let f = h.system.open(app: "Mail", pid: 13, frame: CGRect(x: 800, y: 300, width: 400, height: 300))
    let b = h.system.open(app: "Notes", pid: 12, frame: CGRect(x: 300, y: 200, width: 600, height: 400))
    h.start()
    h.run("dock \(a.rawValue) left")
    let strip = CGRect(x: 1380, y: 500, width: 400, height: 300)
    h.system.userMove(f, to: strip)
    h.run("dock \(b.rawValue) right")
    #expect(h.frame(f) != strip, "pushed aside")
    #expect(h.run("set floatingWindowsMakeWay false").ok)
    #expect(h.frame(f) == strip)
    h.run("zoom \(a.rawValue)")
    h.run("show-all")
    #expect(h.frame(f) == strip)
  }

  // MARK: A setting that needs another says so

  @Test func theLoneWindowsSettingSaysThatItNeedsTheOther() {
    let h = Harness(settings: Settings())
    h.start()
    #expect(h.run("set soleFloatTakesDesktop true").message.contains("floatingWindowsMakeWay"))
    #expect(h.run("set floatingWindowsMakeWay true").ok)
    h.run("set soleFloatTakesDesktop false")
    #expect(!h.run("set soleFloatTakesDesktop true").message.contains("floatingWindowsMakeWay"))
  }

  // MARK: A report of displays that changes nothing

  /// A window that is fitted, or left hanging by hand, is asked nothing when a report changes nothing for it.
  @Test func aChangeOfDisplaysThatLeavesAWindowWhereItBelongsAsksItsAppNothing() {
    let (h, _, _, f) = makeHarness(f: CGRect(x: 1000, y: 500, width: 400, height: 300))
    let small = Self.display("main", CGRect(x: 0, y: 0, width: 1024, height: 768), isMain: true)
    h.system.setDisplays([small])
    h.system.clearFrameLog()
    h.system.setDisplays([small, Self.display("side", CGRect(x: 1024, y: 0, width: 800, height: 600))])
    #expect(!h.system.frameLog.contains { $0.window == f }, "\(h.system.frameLog)")
  }

  // MARK: A hand's choice and a display that is another now

  /// The walks found it. A hand chose a strip on the display as it was. On a display of another size nobody chose anything: the displays have
  /// changed and less than half of the window shows, so it is fitted, though no less of it shows than did (Q20: "the price, accepted").
  @Test func aStripLeftByHandIsFittedWhenItsDisplayChangesItsSize() {
    let (h, _, _, f) = makeHarness(f: CGRect(x: 800, y: 300, width: 400, height: 300))
    let strip = CGRect(x: 1380, y: 500, width: 400, height: 300)
    h.system.userMove(f, to: strip)
    h.system.setDisplays([Self.display("main", CGRect(x: 0, y: 0, width: 1440, height: 800), isMain: true)])
    #expect(h.frame(f) == CGRect(x: 1040, y: 500, width: 400, height: 300))
  }

  /// The control: another display comes, its own is as it was, and the strip is still its person's.
  @Test func aStripLeftByHandStaysWhenItsDisplayIsAsItWas() {
    let (h, _, _, f) = makeHarness(f: CGRect(x: 800, y: 300, width: 400, height: 300))
    let strip = CGRect(x: 1380, y: 500, width: 400, height: 300)
    h.system.userMove(f, to: strip)
    h.system.setDisplays([FakeWindowSystem.standardDisplay, Self.display("side", CGRect(x: -800, y: 0, width: 800, height: 600))])
    #expect(h.frame(f) == strip)
  }
}
