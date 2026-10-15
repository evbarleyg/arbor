import ArborCore
import ArborKit
import ArborTesting
import CoreGraphics
import Foundation
import Testing

/// How low macOS lets a window go is the window's own affair: its title bar stays above the bottom of the visible frame, and title bars
/// are not all one height. The fake and the fake Mac held one number, 32. Hosted Macs showed 28, 32 and 52 on one and the same macOS.
@Suite @MainActor struct TitleBarTests {
  /// A hosted Mac's display: a menu bar of 31 points, a Dock of 63.
  static let hosted = DisplaySnapshot(
    id: DisplayID("hosted"), frame: CGRect(x: 0, y: 0, width: 1024, height: 768),
    visibleFrame: CGRect(x: 0, y: 31, width: 1024, height: 674), isMain: true)
  let corner = CGRect(x: 1023, y: 767, width: 480, height: 348)

  @Test(arguments: [("Safari", 677.0), ("Terminal", 673.0), ("TextEdit", 673.0), ("Finder", 653.0), ("Calculator", 653.0)])
  func aWindowStopsItsOwnTitleBarAboveTheBottom(app: String, y: Double) {
    let system = FakeWindowSystem(displays: [Self.hosted])
    let window = system.open(app: app)
    #expect(system.setFrame(corner, of: window) == CGRect(x: 1023, y: y, width: 480, height: 348))
    #expect(system.windows[window]?.snapshot.frame.minY == CGFloat(y), "and that is where it is")
  }

  @Test func aTestSaysHowHighATitleBarIs() {
    let system = FakeWindowSystem(displays: [Self.hosted])
    let window = system.open(app: "Finder", frame: CGRect(x: 100, y: 660, width: 480, height: 348))
    system.setTitleBar(window, 40)
    #expect(system.windows[window]?.titleBar == 40)
    #expect(system.windows[window]?.snapshot.frame.minY == 660, "nothing moves until somebody asks")
    #expect(system.setFrame(corner, of: window)?.minY == 665)
  }

  @Test func withTheSwitchOffAWindowGoesWhereItIsSent() {
    let system = FakeWindowSystem(displays: [Self.hosted])
    system.echoes.titleBarStaysReachable = false
    let window = system.open(app: "Finder")
    #expect(system.setFrame(corner, of: window) == corner)
  }

  // MARK: Which place out of view

  /// A display to the right that ends `above` points above the bottom of the standard one.
  static func neighbour(endingAbove above: CGFloat) -> DisplaySnapshot {
    let frame = CGRect(x: 1440, y: 0, width: 1280, height: 900 - above)
    return DisplaySnapshot(id: DisplayID("shorter"), frame: frame, visibleFrame: frame, isMain: false)
  }

  /// `[a | Desktop]` beside such a display, with `f` floating, whose title bar is this high.
  func besideADisplay(endingAbove above: CGFloat, titleBar: CGFloat) -> (Harness, a: WindowID, f: WindowID) {
    let h = Harness(displays: [FakeWindowSystem.standardDisplay, Self.neighbour(endingAbove: above)])
    let a = h.system.open(app: "Safari", pid: 11, frame: CGRect(x: 100, y: 100, width: 600, height: 400))
    let f = h.system.open(app: "Editor", pid: 12, frame: CGRect(x: 560, y: 300, width: 640, height: 420))
    h.system.setTitleBar(f, titleBar)
    h.start()
    h.run("dock \(a.rawValue) left")
    return (h, a, f)
  }

  func whatShows(_ h: Harness, of window: WindowID) -> CGFloat {
    let frame = h.frame(window)!
    return h.system.displayList.map { frame.intersection($0.frame).area }.reduce(0, +)
  }

  /// Arbor judges the places out of view by where a window would stop, so that none shows along the bottom of a neighbour that ends a
  /// little higher. One point across and the title bar's height is what macOS leaves of a window in a corner.
  @Test(arguments: [28.0, 32.0, 52.0, 80.0], [20.0, 30.0, 40.0, 50.0, 60.0, 70.0, 90.0])
  func aParkedWindowDoesNotShowAlongTheBottomOfANeighbour(titleBar: Double, above: Double) {
    let (h, a, f) = besideADisplay(endingAbove: CGFloat(above), titleBar: CGFloat(titleBar))
    h.run("zoom \(a.rawValue)")
    #expect(whatShows(h, of: f) <= CGFloat(titleBar), "\(h.frame(f)!) beside a display that ends \(above) points higher")
  }

  /// A title bar no higher than was reckoned with costs no second move: no less of the window would show elsewhere.
  @Test(arguments: [28.0, 32.0], [20.0, 30.0, 40.0, 50.0, 60.0])
  func aWindowGoesOutOfViewInOneMove(titleBar: Double, above: Double) {
    let (h, a, _) = besideADisplay(endingAbove: CGFloat(above), titleBar: CGFloat(titleBar))
    let budget = h.measure { h.run("zoom \(a.rawValue)") }
    #expect(budget.repeatMoves == 0 && budget.idleMoves == 0, "\(budget)")
  }

  /// What can lie around the standard display: a neighbour that ends higher, one below, displays on both sides that begin lower, or
  /// that hem it in, a neighbour and one below.
  nonisolated static let surroundings: [[CGRect]] = [
    [],
    [CGRect(x: 1440, y: 0, width: 1280, height: 860)],
    [CGRect(x: 1440, y: 0, width: 1280, height: 900)],
    [CGRect(x: 223, y: 900, width: 1512, height: 982)],
    [CGRect(x: -240, y: 900, width: 1920, height: 1080)],
    [CGRect(x: 1440, y: 380, width: 1920, height: 1080), CGRect(x: -1920, y: 380, width: 1920, height: 1080)],
    [CGRect(x: 1440, y: 0, width: 1440, height: 900), CGRect(x: -1440, y: 0, width: 1440, height: 900)],
    [CGRect(x: 1440, y: 0, width: 1280, height: 860), CGRect(x: 0, y: 900, width: 1440, height: 900)],
  ]
  nonisolated static let sizes = [CGSize(width: 640, height: 420), CGSize(width: 67, height: 47)]

  static func displays(_ around: [CGRect]) -> [DisplaySnapshot] {
    [FakeWindowSystem.standardDisplay]
      + around.enumerated().map { DisplaySnapshot(id: DisplayID("other\($0)"), frame: $1, visibleFrame: $1, isMain: false) }
  }

  /// `[a | Desktop]` framed on `a`, so that `f`, which floats, is out of view.
  func withAWindowOutOfView(_ around: [CGRect], size: CGSize, titleBar: CGFloat) -> (Harness, f: WindowID) {
    let h = Harness(displays: Self.displays(around))
    let a = h.system.open(app: "Safari", pid: 11, frame: CGRect(x: 100, y: 100, width: 600, height: 400))
    let f = h.system.open(app: "Editor", bundleID: Self.editor, pid: 12, frame: CGRect(origin: CGPoint(x: 560, y: 300), size: size))
    h.system.setTitleBar(f, titleBar)
    h.start()
    h.run("dock \(a.rawValue) left")
    h.run("zoom \(a.rawValue)")
    return (h, f)
  }

  /// The least that shows of a window in any of the places around the standard display, by where the fake, not Arbor, says it stops.
  func leastThatShows(_ h: Harness, size: CGSize, titleBar: CGFloat) -> CGFloat {
    [(1439.0, 899.0), (1 - size.width, 899.0), (0.0, 899.0), (1439.0, 0.0), (1 - size.width, 0.0)].map { place -> CGFloat in
      let stopped = h.system.whereMacOSPuts(CGRect(origin: CGPoint(x: place.0, y: place.1), size: size), titleBar: titleBar)
      return h.system.displayList.map { stopped.intersection($0.frame).area }.reduce(0, +)
    }.min()!
  }

  /// As little shows as can, whatever lies around the display. A window reaches the further into a display below the LOWER its title bar is.
  @Test(arguments: [28.0, 32.0, 52.0, 80.0], surroundings)
  func asLittleOfAParkedWindowShowsAsCan(titleBar: Double, around: [CGRect]) {
    for size in Self.sizes {
      let (h, f) = withAWindowOutOfView(around, size: size, titleBar: CGFloat(titleBar))
      #expect(whatShows(h, of: f) == leastThatShows(h, size: size, titleBar: CGFloat(titleBar)), "\(h.frame(f)!)")
      #expect(h.measure { h.system.setDisplays(h.system.displayList) }.moves == 0, "and there it stays")
    }
  }

  /// And when what lies around it changes: a display plugged in beside a window that waits at the top, say, where macOS stops
  /// nothing and so nothing was learnt.
  @Test(arguments: [28.0, 52.0], surroundings)
  func stillWhenTheDisplaysAroundItChange(titleBar: Double, around: [CGRect]) {
    for size in Self.sizes {
      for later in Self.surroundings {
        let (h, f) = withAWindowOutOfView(around, size: size, titleBar: CGFloat(titleBar))
        h.system.setDisplays(Self.displays(later))
        h.scheduler.runPending()
        #expect(h.controller.parked.contains(f))
        #expect(whatShows(h, of: f) == leastThatShows(h, size: size, titleBar: CGFloat(titleBar)), "\(h.frame(f)!), then \(later)")
      }
    }
  }

  /// A higher one is put right by the answer: one move more, once, and only where the window would show otherwise.
  @Test(arguments: [(52.0, 40.0), (52.0, 50.0), (80.0, 60.0)])
  func aTitleBarHigherThanReckonedWithCostsASecondMoveOnce(titleBar: Double, above: Double) {
    let (h, a, f) = besideADisplay(endingAbove: CGFloat(above), titleBar: CGFloat(titleBar))
    #expect(h.measure { h.run("zoom \(a.rawValue)") }.repeatMoves == 1, "where macOS stops it is not known before it is sent there")
    #expect(h.frame(f)?.maxX == CGFloat(1), "the other corner: \(h.frame(f)!)")
    h.run("back")
    let again = h.measure { h.run("zoom \(a.rawValue)") }
    #expect(again.repeatMoves == 0 && again.idleMoves == 0, "\(again)")
    #expect(h.measure { h.system.setDisplays(h.system.displayList) }.moves == 0)
  }

  /// Its app falls silent between the two questions. The first answer stands, and the window is fetched like any other.
  @Test func anAppThatDoesNotAnswerTheSecondQuestionKeepsItsWindowWithinArborsReach() {
    let (h, a, f) = besideADisplay(endingAbove: 60, titleBar: 80)
    var questions = 0
    h.system.willSetFrame = { [system = h.system] window, _ in
      guard window == f else { return }
      questions += 1
      if questions == 2 { system.setUnresponsive(pid: 12, true) }
    }
    h.run("zoom \(a.rawValue)")
    #expect(questions == 2 && h.controller.parked.contains(f))
    #expect(h.frame(f)?.origin == CGPoint(x: 1439, y: 820), "where macOS stopped it the first time")
    h.system.willSetFrame = nil
    h.system.setUnresponsive(pid: 12, false)
    h.run("back")
    h.scheduler.advance(by: 1)
    #expect(h.system.isVisible(f) && !h.controller.parked.contains(f))
    expectWindowsMatchLayout(h)
  }

  /// A person hides the toolbar, and the window can go lower: the next answer says so.
  @Test func aTitleBarThatChangesIsLearntAgain() {
    let h = Harness()
    let a = h.system.open(app: "Safari", pid: 11)
    let f = h.system.open(app: "Finder", pid: 12)
    h.start()
    h.run("dock \(a.rawValue) left")
    h.run("zoom \(a.rawValue)")
    #expect(h.frame(f)?.minY == CGFloat(848))
    h.run("back")
    h.system.setTitleBar(f, 28)
    h.run("zoom \(a.rawValue)")
    #expect(h.frame(f)?.minY == CGFloat(872))
    h.system.clearFrameLog()
    h.system.setDisplays(h.system.displayList)
    #expect(h.system.frameLog.isEmpty, "\(h.system.frameLog)")
  }

  // MARK: A report of the displays

  /// With and without a Dock: the bottom of the visible frame is not the display's.
  nonisolated static let desks = [0, 1]
  static func desk(_ index: Int) -> DisplaySnapshot { [FakeWindowSystem.standardDisplay, hosted][index] }

  /// macOS reports the displays in bursts, most of which change nothing. A window that is where macOS stopped it would stop there
  /// again: asking costs a round trip to its app and changes nothing.
  @Test(arguments: [20.0, 28.0, 32.0, 52.0, 80.0], desks)
  func aReportOfTheDisplaysSendsNoWindowToTheCornerItIsIn(titleBar: Double, desk: Int) {
    let display = Self.desk(desk)
    let h = Harness(displays: [display])
    let a = h.system.open(app: "Safari", pid: 11)
    let b = h.system.open(app: "Notes", pid: 12)
    let f = h.system.open(app: "Mail", pid: 13)
    for window in [b, f] { h.system.setTitleBar(window, CGFloat(titleBar)) }
    h.start()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) right")
    h.run("zoom \(a.rawValue)")
    let stop = CGPoint(x: display.frame.maxX - 1, y: display.visibleFrame.maxY - CGFloat(titleBar))
    #expect(h.frame(b)?.origin == stop && h.frame(f)?.origin == stop)
    h.system.clearFrameLog()
    h.system.setDisplays([display])
    #expect(h.system.frameLog.isEmpty, "\(h.system.frameLog)")
  }

  /// Found out of view by the Arbor that the watchdog starts after an accident, which keeps the view: how high their title bars are is
  /// not known yet.
  @Test(arguments: [28.0, 32.0, 52.0], desks)
  func norThoseItFoundThereAtAStart(titleBar: Double, desk: Int) {
    let display = Self.desk(desk)
    let first = Harness(displays: [display])
    let a = first.system.open(app: "Safari", pid: 11)
    let b = first.system.open(app: "Notes", pid: 12)
    first.system.setTitleBar(b, CGFloat(titleBar))
    first.start()
    first.run("dock \(a.rawValue) left")
    first.run("dock \(b.rawValue) right")
    first.run("zoom \(a.rawValue)")
    first.controller.saveNow()
    let again = first.newProcess(byTheWatchdog: true)
    again.start()
    #expect(again.controller.parked.contains(b), "the view is as it was")
    again.system.clearFrameLog()
    again.system.setDisplays([display])
    #expect(again.system.frameLog.isEmpty, "\(again.system.frameLog)")
  }

  /// The control: where the corner is another, every window out of view goes there.
  @Test(arguments: [28.0, 52.0]) func aDisplayThatGrewSendsThemToItsNewCorner(titleBar: Double) {
    let h = Harness()
    let a = h.system.open(app: "Safari", pid: 11)
    let b = h.system.open(app: "Notes", pid: 12)
    h.system.setTitleBar(b, CGFloat(titleBar))
    h.start()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) right")
    h.run("zoom \(a.rawValue)")
    for height in [960.0, 1200.0] {
      h.system.setDisplays([
        DisplaySnapshot(
          id: FakeWindowSystem.standardDisplay.id, frame: CGRect(x: 0, y: 0, width: 1440, height: height),
          visibleFrame: CGRect(x: 0, y: 25, width: 1440, height: height - 25), isMain: true)
      ])
      #expect(h.frame(b)?.origin == CGPoint(x: 1439, y: height - titleBar))
    }
  }

  // MARK: After a crash

  static let editor = "com.example.editor"
  static let own = CGRect(x: 300, y: 200, width: 500, height: 350)

  /// Arbor had a window of Editor out of view and died. It starts again told to leave Editor alone, by a rule or by the list of
  /// excluded apps, and Editor's window has another number by now (its app started again, too), so that nothing but its place says
  /// whose doing that place is. Returns where the crash left it as well.
  func afterACrash(
    titleBar: CGFloat, displays: [DisplaySnapshot] = [FakeWindowSystem.standardDisplay], excluded: Bool = false
  ) -> (Harness, WindowID, left: CGRect) {
    let first = Harness(displays: displays)
    let e = first.system.open(app: "Editor", bundleID: Self.editor, pid: 21, frame: Self.own)
    let m = first.system.open(app: "Mail", pid: 22)
    first.system.setTitleBar(e, titleBar)
    first.start()
    first.run("dock \(e.rawValue) left")
    first.run("dock \(m.rawValue) right")
    first.run("zoom \(m.rawValue)")
    first.controller.saveNow()
    var settings = Settings()
    if excluded { settings.excludedBundleIDs = [Self.editor] } else { settings.rules = [AppRule(app: Self.editor, action: .ignore)] }
    let again = Harness(displays: displays, settings: settings, saved: first.store.saved)
    var renumbered: [WindowID] = []
    for window in [m, e] {
      let old = first.controller.windows[window]!
      renumbered.append(again.system.open(app: old.appName, bundleID: old.bundleID, title: old.title, pid: old.pid, frame: old.frame))
    }
    again.system.setTitleBar(renumbered[1], titleBar)
    again.start()
    return (again, renumbered[1], first.frame(e)!)
  }

  @Test(arguments: [20.0, 28.0, 32.0, 52.0, 80.0, 104.0], desks)
  func aWindowLeftInArborsCornerIsFetchedWhateverItsTitleBar(titleBar: Double, desk: Int) {
    let display = Self.desk(desk)
    let (h, e, left) = afterACrash(titleBar: CGFloat(titleBar), displays: [display])
    #expect(left.origin == CGPoint(x: display.frame.maxX - 1, y: display.visibleFrame.maxY - titleBar), "where the crash left it")
    #expect(h.controller.filter.ignoredWindowIDs == [e])
    #expect(h.system.isVisible(e), "\(h.frame(e)!): ignored from now on, so nothing would ever fetch it")
  }

  @Test(arguments: [28.0, 52.0, 80.0]) func soIsTheWindowOfAnExcludedApp(titleBar: Double) {
    let (h, e, _) = afterACrash(titleBar: CGFloat(titleBar), excluded: true)
    #expect(!h.workspace.contains(e))
    #expect(h.system.isVisible(e), "\(h.frame(e)!)")
  }

  /// Beside a display that ends a little higher it is the other corner.
  @Test(arguments: [(28.0, 20.0), (28.0, 30.0), (52.0, 40.0), (52.0, 50.0), (80.0, 60.0), (80.0, 70.0)])
  func aWindowLeftInTheOtherCornerIsFetchedToo(titleBar: Double, above: Double) {
    let (h, e, left) = afterACrash(
      titleBar: CGFloat(titleBar), displays: [FakeWindowSystem.standardDisplay, Self.neighbour(endingAbove: CGFloat(above))])
    #expect(left.maxX == 1 && left.minY == 900 - titleBar, "where the crash left it: \(left)")
    #expect(h.controller.filter.ignoredWindowIDs == [e])
    #expect(h.system.isVisible(e), "\(h.frame(e)!)")
  }

  /// The neighbour that made it the other corner is unplugged before Arbor starts again.
  @Test(arguments: [28.0, 52.0]) func aWindowLeftInACornerThatWouldNotBeChosenNowIsFetchedToo(titleBar: Double) {
    let first = Harness(displays: [FakeWindowSystem.standardDisplay, Self.neighbour(endingAbove: 0)])
    let e = first.system.open(app: "Editor", bundleID: Self.editor, pid: 21, frame: Self.own)
    let m = first.system.open(app: "Mail", pid: 22)
    first.system.setTitleBar(e, CGFloat(titleBar))
    first.start()
    first.run("dock \(e.rawValue) left")
    first.run("dock \(m.rawValue) right")
    first.run("zoom \(m.rawValue)")
    first.controller.saveNow()
    #expect(first.frame(e)?.maxX == CGFloat(1), "the left corner: \(first.frame(e)!)")
    first.system.displayList = [FakeWindowSystem.standardDisplay]
    let again = first.newProcess()
    var settings = again.controller.settings
    settings.rules = [AppRule(app: Self.editor, action: .ignore)]
    again.controller.apply(settings: settings)
    let new = again.system.renumber(e)!
    again.start()
    #expect(again.controller.filter.ignoredWindowIDs == [new])
    #expect(again.system.isVisible(new), "\(again.frame(new)!)")
  }

  /// Wherever Arbor puts a window out of view, whatever lies around the display, there it knows it again: all of it shows afterwards.
  /// (Hemmed in, all of a window lower than its title bar shows where Arbor put it, across the edge: that one may stay.)
  @Test(arguments: [28.0, 32.0, 52.0, 80.0], surroundings)
  func everyPlaceArborChoosesItKnowsAgainAfterACrash(titleBar: Double, around: [CGRect]) {
    for size in Self.sizes {
      let (first, f) = withAWindowOutOfView(around, size: size, titleBar: CGFloat(titleBar))
      first.controller.saveNow()
      let (left, showedWhole) = (first.frame(f)!, whatShows(first, of: f) == size.width * size.height)
      let again = first.newProcess()
      var settings = again.controller.settings
      settings.rules = [AppRule(app: Self.editor, action: .ignore)]
      again.controller.apply(settings: settings)
      let new = again.system.renumber(f)!
      again.start()
      #expect(again.controller.filter.ignoredWindowIDs == [new])
      let frame = again.frame(new)!
      #expect(whatShows(again, of: new) == frame.width * frame.height, "left at \(left), and now at \(frame)")
      #expect(frame != left || showedWhole)
    }
  }

  /// An Arbor that reckoned with 32 points for every window chose the right corner beside a display that ends 40 points higher, also
  /// for a window with a toolbar, of which a strip showed there. So does this one, if the window's app does not answer its second question.
  @Test func aWindowLeftWhereAnOlderArborChoseIsFetchedToo() {
    var settings = Settings()
    settings.rules = [AppRule(app: Self.editor, action: .ignore)]
    let h = Harness(displays: [FakeWindowSystem.standardDisplay, Self.neighbour(endingAbove: 40)], settings: settings)
    let e = h.system.open(app: "Editor", bundleID: Self.editor, frame: CGRect(x: 1439, y: 848, width: 500, height: 350))
    h.system.setTitleBar(e, 52)
    h.start()
    #expect(h.controller.filter.ignoredWindowIDs == [e])
    #expect(h.system.isVisible(e), "\(h.frame(e)!)")
  }

  /// One point across and nothing to get hold of: however high up, as after the Dock was hidden or the display changed meanwhile.
  @Test(arguments: [CGPoint(x: 1439, y: 780), CGPoint(x: 1439, y: 400), CGPoint(x: -499, y: 600)])
  func onePointAcrossAndOutOfReachIsArborsMark(origin: CGPoint) {
    var settings = Settings()
    settings.rules = [AppRule(app: Self.editor, action: .ignore)]
    let h = Harness(settings: settings)
    let e = h.system.open(app: "Editor", bundleID: Self.editor, frame: CGRect(origin: origin, size: Self.own.size))
    h.start()
    #expect(h.controller.filter.ignoredWindowIDs == [e])
    #expect(h.system.isVisible(e), "\(h.frame(e)!)")
  }

  /// The control: a place a person can have chosen is theirs. Three points across, thirty, or along the bottom with all its width in view.
  @Test(arguments: [CGPoint(x: 1437, y: 848), CGPoint(x: 1410, y: 400), CGPoint(x: -497, y: 600), CGPoint(x: 0, y: 848)])
  func aWindowSomebodyPushedAsideIsIgnoredWhereItIs(origin: CGPoint) {
    var settings = Settings()
    settings.rules = [AppRule(app: Self.editor, action: .ignore)]
    let h = Harness(settings: settings)
    let e = h.system.open(app: "Editor", bundleID: Self.editor, frame: CGRect(origin: origin, size: Self.own.size))
    h.start()
    #expect(h.controller.filter.ignoredWindowIDs == [e])
    #expect(h.frame(e)?.origin == origin)
  }

  /// With two displays side by side, one display's corner is the other's edge: a window in full view there is nobody's but its person's.
  /// At the foot of the right display's left edge, of the left one's right edge, and at the top of either.
  @Test(arguments: [
    CGRect(x: 1440, y: 800, width: 300, height: 100), CGRect(x: 1439, y: 800, width: 300, height: 100),
    CGRect(x: 1140, y: 800, width: 300, height: 100), CGRect(x: 1141, y: 820, width: 300, height: 80),
    CGRect(x: 1440, y: 0, width: 1280, height: 900), CGRect(x: 1439, y: 0, width: 600, height: 400),
  ])
  func aWindowInViewAtTheEdgeBetweenTwoDisplaysIsIgnoredWhereItIs(frame: CGRect) {
    var settings = Settings()
    settings.rules = [AppRule(app: Self.editor, action: .ignore)]
    let h = Harness(displays: [FakeWindowSystem.standardDisplay, Self.neighbour(endingAbove: 0)], settings: settings)
    let e = h.system.open(app: "Editor", bundleID: Self.editor, frame: frame)
    h.start()
    #expect(h.controller.filter.ignoredWindowIDs == [e])
    #expect(h.frame(e) == frame)
    let later = h.system.open(app: "Editor", bundleID: Self.editor, frame: frame)
    #expect(h.frame(later) == h.system.whereItOpens(frame), "nor one that opens there, which under a menu bar none does")
  }

  /// Hemmed in on both sides, every place shows as much of a window as any other, so Arbor's choice says little. What shows whole is in
  /// view, on one display or across the edge between two, and so is what hangs over the bottom flush with that edge.
  @Test(arguments: [
    CGRect(x: 1439, y: 800, width: 300, height: 100), CGRect(x: -299, y: 800, width: 300, height: 100),
    CGRect(x: 1440, y: 800, width: 300, height: 100), CGRect(x: 1440, y: 500, width: 600, height: 400),
    CGRect(x: -300, y: 800, width: 300, height: 100), CGRect(x: 1140, y: 800, width: 300, height: 100),
    CGRect(x: 1440, y: 850, width: 600, height: 400), CGRect(x: -600, y: 850, width: 600, height: 400),
  ])
  func norOneBesideADisplayThatIsHemmedIn(frame: CGRect) {
    var settings = Settings()
    settings.rules = [AppRule(app: Self.editor, action: .ignore)]
    let left = CGRect(x: -1440, y: 0, width: 1440, height: 900)
    let h = Harness(
      displays: [
        FakeWindowSystem.standardDisplay, Self.neighbour(endingAbove: 0),
        DisplaySnapshot(id: DisplayID("left"), frame: left, visibleFrame: left, isMain: false),
      ], settings: settings)
    let e = h.system.open(app: "Editor", bundleID: Self.editor, frame: frame)
    h.start()
    #expect(h.controller.filter.ignoredWindowIDs == [e])
    #expect(h.frame(e) == frame)
  }

  /// Every answer in the recordings to a request that would have put a title bar under the Dock: how much of the window stayed above
  /// the bottom of the visible frame there was at that moment, by the app's name.
  static func stopsInTheRecordings() throws -> [String: Set<CGFloat>] {
    var stops: [String: Set<CGFloat>] = [:]
    for name in TraceCorpusTests.names {
      let trace = try Trace(contentsOf: TraceCorpusTests.folder.appendingPathComponent(name + ".jsonl"))
      var displays = trace.header.displays
      var apps = Dictionary(trace.header.windows.map { ($0.id, $0.app) }, uniquingKeysWith: { $1 })
      for entry in trace.entries {
        switch entry.line {
        case .displaysChanged(let now), .displays(let now): displays = now
        case .appeared(let window), .changed(let window, _): apps[window.id] = window.app
        case .allWindows(let windows): for window in windows { apps[window.id] = window.app }
        case .setFrame(let id, let asked, let took?, _):
          guard displays.count == 1, let bottom = displays.first?.visible.maxY, let app = apps[id] else { continue }
          if asked.minY > bottom, took.minY < asked.minY { stops[app, default: []].insert(bottom - took.minY) }
        default: break
        }
      }
    }
    return stops
  }

  /// The table in the fake is what the recordings of real apps say, each read against its own visible frame: the Dock is three and six
  /// points lower in some of them, which once made 26, 29 and 47 of these numbers.
  @Test func theHeightsOfRealAppsAreTheRecordings() throws {
    let stops = try Self.stopsInTheRecordings()
    for (app, height) in FakeWindowSystem.measuredTitleBars {
      #expect(stops[app] == [height], "\(app)")
    }
  }

  /// The same test windows on the same macOS, built on two mornings.
  @Test func thereIsNoOneHeight() throws {
    let stops = try #require(try Self.stopsInTheRecordings()["ArborTestWindows"])
    #expect(stops.isSuperset(of: [28, 32]), "\(stops.sorted())")
    #expect(stops.contains(FakeWindowSystem.usualTitleBar))
  }
}
