import ArborCore
@testable import ArborKit
import ArborTesting
import CoreGraphics
import Testing

/// A floating window's frame is its person's (collab/QUESTIONS.md, Q20). **Arbor sets a floating window's frame only to take
/// it out of view and to put it back exactly where it was.**
///
/// The desk is the one of the first day played with real apps on a hosted Mac: a display 1600 points wide, nine apps,
/// the frames and the smallest sizes they had there. On that day a dock squeezed Safari from 1324 to 794 points, ⌘M, ⌘H and
/// ⌘Q of a docked window shoved seven windows nobody had touched, and after Frame and Show Everything they came back
/// somewhere else. Each test here is one of its steps.
@Suite @MainActor struct FloatingFrameTests {
  static let display = DisplaySnapshot(
    id: DisplayID("main"), frame: CGRect(x: 0, y: 0, width: 1600, height: 900),
    visibleFrame: CGRect(x: 0, y: 31, width: 1600, height: 791), isMain: true, isBuiltIn: true)

  /// The desk, and what floats on it with the frame each window's person gave it.
  struct Desk {
    var h: Harness
    var finder, safari, textEdit: WindowID
    /// The windows that float all day.
    var own: [WindowID: CGRect] = [:]
  }

  func makeDesk(_ change: (inout Settings) -> Void = { _ in }) -> Desk {
    var settings = Settings()
    change(&settings)
    let h = Harness(displays: [Self.display], settings: settings)
    func open(_ app: String, _ pid: Int32, _ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ height: CGFloat, least: CGFloat = 0) -> WindowID {
      h.system.open(
        app: app, pid: pid, frame: CGRect(x: x, y: y, width: w, height: height), minimumSize: CGSize(width: least, height: 200))
    }
    let finder = open("Finder", 2001, 340, 120, 920, 436, least: 501)
    let safari = open("Safari", 2002, 138, 31, 1324, 791, least: 574)
    let textEdit = open("TextEdit", 2003, 165, 65, 673, 439, least: 252)
    var desk = Desk(h: h, finder: finder, safari: safari, textEdit: textEdit)
    for window in [
      open("Terminal", 2004, 40, 51, 877, 499, least: 240), open("Notes", 2005, 300, 105, 1000, 660, least: 709),
      open("Calendar", 2006, 200, 86, 935, 598, least: 680), open("System Settings", 2007, 437, 85, 723, 625, least: 723),
      open("Preview", 2008, 4, 35, 708, 424, least: 708), open("Mail", 2009, 240, 72, 1120, 630, least: 871),
      open("Mail", 2009, 565, 179, 470, 416, least: 470),
    ] { desk.own[window] = h.frame(window)! }
    h.start()
    return desk
  }

  /// Finder left, Safari right, TextEdit right of that, as the day had it by noon. That day there was a column for the Desktop between
  /// Finder and Safari (`desktopColumn`); as Arbor ships the three have the display to themselves, and what floats lies over them.
  func makeArrangedDesk(_ change: (inout Settings) -> Void = { _ in }) -> Desk {
    let desk = makeDesk(change)
    desk.h.run("dock \(desk.finder.rawValue) left")
    desk.h.run("dock \(desk.safari.rawValue) right")
    desk.h.run("dock \(desk.textEdit.rawValue) right")
    desk.h.system.clearFrameLog()
    return desk
  }

  /// Every window that floats is where its person has it, and since the log was last cleared Arbor has not touched one.
  func expectUntouched(_ desk: Desk, _ when: Comment, sourceLocation: SourceLocation = #_sourceLocation) {
    for (window, frame) in desk.own.sorted(by: { $0.key < $1.key }) {
      #expect(desk.h.frame(window) == frame, "\(window) \(when)", sourceLocation: sourceLocation)
    }
    let touched = Set(desk.h.system.frameLog.map(\.window)).intersection(desk.own.keys).sorted()
    #expect(touched.isEmpty, "Arbor set the frame of \(touched) \(when)", sourceLocation: sourceLocation)
  }

  // MARK: The docks (steps 25, 27, 29)

  @Test func aDockMovesAndSizesNoFloatingWindow() {
    var desk = makeDesk()
    for window in [desk.safari, desk.textEdit] { desk.own[window] = desk.h.frame(window)! }
    desk.h.run("dock \(desk.finder.rawValue) left")
    expectUntouched(desk, "after Finder was docked on the left")
    #expect(desk.h.system.focused == desk.finder, "the window acted on comes to the front")

    desk.own[desk.safari] = nil
    desk.h.run("dock \(desk.safari.rawValue) right")
    expectUntouched(desk, "after Safari was docked on the right")

    desk.own[desk.textEdit] = nil
    desk.h.run("dock \(desk.textEdit.rawValue) right")
    expectUntouched(desk, "after TextEdit was docked on the right")
    expectWindowsMatchLayout(desk.h)
  }

  /// The control: the same desk as it was until now. If this stops moving windows, the test above proves nothing.
  @Test func withTheSettingOnADockShovesAndSqueezesAsItDidOnTheDay() {
    let desk = makeDesk { $0.floatingWindowsMakeWay = true }
    desk.h.run("dock \(desk.finder.rawValue) left")
    #expect(desk.h.frame(desk.safari) == CGRect(x: 806, y: 31, width: 794, height: 791), "step 25, to the point")
    #expect(desk.own.allSatisfy { desk.h.frame($0.key) != $0.value }, "every one of the seven was moved")
  }

  // MARK: There and back is nothing (steps 47 to 59)

  @Test(arguments: [false, true]) func frameThenShowEverythingBringsEveryFloatingWindowBackToItsOwnFrame(desktopColumn: Bool) {
    let desk = makeArrangedDesk { $0.desktopColumn = desktopColumn }
    desk.h.run("zoom \(desk.safari.rawValue)")
    for window in desk.own.keys.sorted() { #expect(!desk.h.system.isVisible(window), "\(window) leaves with the Desktop") }
    desk.h.run("show-all")
    for (window, frame) in desk.own.sorted(by: { $0.key < $1.key }) {
      #expect(desk.h.frame(window) == frame, "\(window) is back where it was")
      // One move out, one move back.
      #expect(desk.h.system.frameLog.filter { $0.window == window }.count == 2, "\(window): \(desk.h.system.frameLog.filter { $0.window == window })")
    }
    expectWindowsMatchLayout(desk.h)
  }

  @Test func everyWayOutAndBackIsNothing() {
    for (out, back) in [("zoom", "back"), ("zoom", "home"), ("zoom", "show-all"), ("zoom", "desktop"), ("zoom", "out")] {
      let desk = makeArrangedDesk()
      desk.h.run("\(out) \(desk.finder.rawValue)")
      desk.h.run(back)
      for (window, frame) in desk.own.sorted(by: { $0.key < $1.key }) {
        #expect(desk.h.frame(window) == frame, "\(window) after \(out) and \(back)")
      }
    }
  }

  /// Where it is when the view leaves is where it comes back to, whoever put it there and whether or not Arbor heard of it.
  @Test func aWindowMovedByHandComesBackWhereTheHandLeftIt() {
    var desk = makeArrangedDesk()
    let notes = desk.own.keys.sorted()[1]
    // Over Finder and the gap, hanging over the left edge of the screen: all of that is its person's business.
    desk.own[notes] = CGRect(x: -300, y: 200, width: 1000, height: 560)
    desk.h.system.userMove(notes, to: desk.own[notes]!)
    desk.h.system.clearFrameLog()
    desk.h.run("resize \(desk.finder.rawValue) right 100")
    expectUntouched(desk, "after a gap was moved")
    desk.h.run("zoom \(desk.safari.rawValue)")
    desk.h.run("show-all")
    #expect(desk.h.frame(notes) == desk.own[notes], "overhang and all")
  }

  // MARK: ⌘M, ⌘H, ⌘Q and ⌘W of a docked window (steps 71 to 77)

  @Test(arguments: [false, true]) func minimizingADockedWindowAndRestoringItTouchesNoFloatingWindow(desktopColumn: Bool) {
    let desk = makeArrangedDesk { $0.desktopColumn = desktopColumn }
    desk.h.system.setMinimized(desk.safari, true)
    expectUntouched(desk, "after ⌘M in Safari")
    desk.h.system.setMinimized(desk.safari, false)
    expectUntouched(desk, "after Safari came out of the Dock")
    expectWindowsMatchLayout(desk.h)
  }

  @Test(arguments: [false, true]) func hidingADockedWindowsAppAndShowingItTouchesNoFloatingWindow(desktopColumn: Bool) {
    let desk = makeArrangedDesk { $0.desktopColumn = desktopColumn }
    desk.h.system.setHidden(pid: 2001, true)
    desk.h.scheduler.advance(by: 1)
    expectUntouched(desk, "after ⌘H in Finder")
    desk.h.system.setHidden(pid: 2001, false)
    desk.h.scheduler.advance(by: 1)
    expectUntouched(desk, "after Finder was shown again")
    expectWindowsMatchLayout(desk.h)
  }

  @Test(arguments: [false, true]) func quittingADockedWindowsAppTouchesNoFloatingWindow(desktopColumn: Bool) {
    let desk = makeArrangedDesk { $0.desktopColumn = desktopColumn }
    desk.h.system.quit(pid: 2003)
    expectUntouched(desk, "after ⌘Q in TextEdit")
    desk.h.system.close(desk.safari)
    expectUntouched(desk, "after ⌘W in Safari")
    expectWindowsMatchLayout(desk.h)
  }

  /// The control for all of the above: with the setting on, each of those steps sets the frame of a floating window nobody touched, as
  /// on the day. If one of them stops doing so, the test of that step proves nothing any more. With a column for the Desktop, as on the
  /// day: it is onto the Desktop that they are pushed, and with no room of its own there is nowhere to push them.
  @Test(arguments: ["⌘M", "⌘H", "⌘Q", "Frame and Show Everything"])
  func withTheSettingOnEachOfThoseStepsMovesFloatingWindows(step: String) {
    let desk = makeArrangedDesk { $0 = .makingWay.withDesktopColumn }
    let before = desk.own.keys.reduce(into: [WindowID: CGRect]()) { $0[$1] = desk.h.frame($1)! }
    switch step {
    case "⌘M": desk.h.system.setMinimized(desk.safari, true)
    case "⌘H":
      desk.h.system.setHidden(pid: 2001, true)
      desk.h.scheduler.advance(by: 1)
    case "⌘Q": desk.h.system.quit(pid: 2003)
    default:
      // There and back was not nothing.
      desk.h.run("zoom \(desk.safari.rawValue)")
      desk.h.run("show-all")
    }
    #expect(before.contains { desk.h.frame($0.key) != $0.value }, "\(step)")
  }

  // MARK: What else used to place them

  @Test func commandsOnTheArrangementTouchNoFloatingWindow() {
    let desk = makeArrangedDesk()
    for command in [
      "dock \(desk.safari.rawValue) left", "resize \(desk.finder.rawValue) right 120", "swap \(desk.finder.rawValue) right",
      "relayout", "home", "show-all", "float \(desk.textEdit.rawValue)", "dock \(desk.textEdit.rawValue) bottom", "undo", "redo",
    ] {
      desk.h.run(command)
      expectUntouched(desk, "after `\(command)`")
    }
  }

  @Test func aNewWindowAndAClosedOneTouchNoFloatingWindow() {
    let desk = makeArrangedDesk()
    let new = desk.h.system.open(app: "Maps", pid: 2010, frame: CGRect(x: 500, y: 300, width: 700, height: 400))
    expectUntouched(desk, "after ⌘N")
    #expect(desk.h.frame(new) == CGRect(x: 500, y: 300, width: 700, height: 400), "it floats where its app opened it")
    desk.h.system.close(new)
    expectUntouched(desk, "after ⌘W")
  }

  @Test func aStartTouchesNoFloatingWindowInView() {
    let desk = makeArrangedDesk()
    desk.h.controller.saveNow()
    let again = Harness(settings: Settings(), saved: desk.h.store.saved, system: desk.h.system)
    desk.h.system.clearFrameLog()
    again.start()
    var second = desk
    second.h = again
    expectUntouched(second, "after Arbor crashed and was started again")
  }

  @Test func quittingAndFloatAllTouchNoFloatingWindowInView() {
    for way in ["float-all", "quit"] {
      let desk = makeArrangedDesk()
      if way == "quit" { desk.h.controller.shutdown() } else { desk.h.run(way) }
      expectUntouched(desk, "after \(way)")
    }
  }

  @Test func quittingWhileTheyAreOutOfViewPutsThemBackWhereTheyWere() {
    let desk = makeArrangedDesk()
    desk.h.run("zoom \(desk.safari.rawValue)")
    desk.h.controller.shutdown()
    for (window, frame) in desk.own.sorted(by: { $0.key < $1.key }) { #expect(desk.h.frame(window) == frame, "\(window)") }
  }

  /// A window that floats by command is the window acted on: it takes its own size, around where it was docked, whatever
  /// is docked there. The others stay.
  @Test func aWindowFloatedByCommandTakesItsOwnSizeAndIsNotSqueezedOntoTheDesktop() {
    let desk = makeArrangedDesk()
    desk.h.run("float \(desk.safari.rawValue)")
    // A point short of its own 791, which is the height of the visible frame: an app can make itself that high, but asked to grow, a window
    // stops a point above the Dock, in whatever order it is sized and moved (970 of 971 on a hosted Mac).
    #expect(desk.h.frame(desk.safari)?.size == CGSize(width: 1324, height: 790), "\(String(describing: desk.h.frame(desk.safari)))")
    #expect(Self.display.visibleFrame.contains(desk.h.frame(desk.safari)!))
    expectUntouched(desk, "after Safari was floated")
  }

  // MARK: F18 and F61

  @Test func aWindowThatFloatsAloneIsNotStretchedOverTheDesktop() {
    var settings = Settings()
    settings.soleFloatTakesDesktop = true
    let h = Harness(displays: [Self.display], settings: settings)
    let a = h.system.open(app: "Finder", frame: CGRect(x: 340, y: 120, width: 920, height: 436))
    let f = h.system.open(app: "Terminal", frame: CGRect(x: 40, y: 51, width: 877, height: 499))
    h.start()
    h.run("dock \(a.rawValue) left")
    h.scheduler.advance(by: 3)
    #expect(h.frame(f) == CGRect(x: 40, y: 51, width: 877, height: 499), "F18 needs floatingWindowsMakeWay")
    h.run("zoom \(a.rawValue)")
    h.run("show-all")
    #expect(h.frame(f) == CGRect(x: 40, y: 51, width: 877, height: 499))
  }

  /// F61's own example, with a Calculator floating: both docked windows are in view, the Desktop is the tile, and what floats
  /// shows over the arrangement, where it was.
  @Test func dockedWindowsComeBeforeADesktopWithAWindowOnIt() {
    let h = Harness(settings: .withDesktopColumn)
    let notes = h.system.open(app: "Notes", frame: CGRect(x: 100, y: 100, width: 1000, height: 660), minimumSize: CGSize(width: 709, height: 300))
    let safari = h.system.open(app: "Safari", frame: CGRect(x: 60, y: 60, width: 1324, height: 800), minimumSize: CGSize(width: 574, height: 240))
    let calculator = h.system.open(app: "Calculator", frame: CGRect(x: 600, y: 300, width: 230, height: 408), isResizable: false)
    h.start()
    h.run("dock \(notes.rawValue) left")
    h.run("dock \(safari.rawValue) right")
    #expect(h.layout?.windowFrames[notes] != nil && h.layout?.windowFrames[safari] != nil, "\(h.ascii())")
    #expect(h.layout?.desktopFrame == nil, "the Desktop gives down to a tile")
    #expect(h.frame(calculator) == CGRect(x: 600, y: 300, width: 230, height: 408))
    h.run("zoom \(notes.rawValue)")
    h.run("show-all")
    #expect(h.layout?.windowFrames[notes] != nil && h.layout?.windowFrames[safari] != nil)
    #expect(h.frame(calculator) == CGRect(x: 600, y: 300, width: 230, height: 408))
    expectWindowsMatchLayout(h)
  }

  /// For F61 the Desktop counts as not in use, whatever floats on it, and wishes for nothing. With the setting on it is in use,
  /// and would like to be as wide as the widest window on it: the control.
  @Test(arguments: [false, true]) func theDesktopAsksForNoRoomForAFloatingWindowsSake(makingWay: Bool) {
    let desk = makeArrangedDesk { $0.floatingWindowsMakeWay = makingWay }
    let terms = desk.h.controller.roomTerms(on: desk.h.display)
    #expect(terms.desktopIsInUse == makingWay)
    #expect(terms.desktopWish == (makingWay ? CGSize(width: 1120, height: 660) : .zero))
  }

  /// So a window that docks by itself may leave the Desktop a tile, though something floats: nobody needs the Desktop's points.
  @Test(arguments: [false, true]) func aNewWindowThatDocksByItselfMayLeaveTheDesktopATile(makingWay: Bool) {
    var settings = (makingWay ? Settings.makingWay : Settings()).withDesktopColumn
    settings.newWindows = "dock"
    let h = Harness(settings: settings)
    let least = CGSize(width: 640, height: 600)
    let a = h.system.open(app: "Safari", frame: CGRect(x: 100, y: 100, width: 700, height: 650), minimumSize: least)
    let f = h.system.open(app: "Calculator", frame: CGRect(x: 60, y: 300, width: 230, height: 408), isResizable: false)
    h.start()
    h.run("dock \(a.rawValue) right")
    h.system.userFocus(a)
    let new = h.system.open(app: "Safari", frame: CGRect(x: 200, y: 120, width: 700, height: 650), minimumSize: least)
    h.scheduler.advance(by: 1)
    #expect(h.workspace.isDocked(new) == !makingWay, "\(h.ascii())")
    #expect(h.frame(f) == CGRect(x: 60, y: 300, width: 230, height: 408))
    expectWindowsMatchLayout(h)
  }

  // MARK: The one exception: never lost outranks never moved

  @Test func ifTheDisplaysChangedMeanwhileAndLessThanHalfWouldShowItIsFitted() {
    let desk = makeArrangedDesk()
    desk.h.run("zoom \(desk.safari.rawValue)")
    let smaller = DisplaySnapshot(
      id: DisplayID("main"), frame: CGRect(x: 0, y: 0, width: 1024, height: 768),
      visibleFrame: CGRect(x: 0, y: 31, width: 1024, height: 659), isMain: true, isBuiltIn: true)
    desk.h.system.setDisplays([smaller])
    desk.h.run("show-all")
    for (window, own) in desk.own.sorted(by: { $0.key < $1.key }) {
      let frame = desk.h.frame(window)!
      if own.fractionInside(smaller.frame) >= 0.5 {
        #expect(frame == own, "\(window) still shows more than half: exactly where it was")
      } else {
        #expect(smaller.visibleFrame.contains(frame), "\(window) is wholly in view at \(frame)")
        #expect(frame.width == min(own.width, 1024) && frame.height == min(own.height, 659), "\(window) is smaller only if larger than the display")
      }
    }
  }

  /// The least move that brings it wholly into view.
  @Test func theFitMovesItTheLeast() {
    let h = Harness(displays: [Self.display], settings: Settings())
    let a = h.system.open(app: "Finder", frame: CGRect(x: 340, y: 120, width: 920, height: 436))
    let f = h.system.open(app: "Terminal", frame: CGRect(x: 1100, y: 300, width: 400, height: 300))
    h.start()
    h.run("dock \(a.rawValue) left")
    h.run("zoom \(a.rawValue)")
    h.system.setDisplays([
      DisplaySnapshot(
        id: DisplayID("main"), frame: CGRect(x: 0, y: 0, width: 1280, height: 800),
        visibleFrame: CGRect(x: 0, y: 31, width: 1280, height: 691), isMain: true, isBuiltIn: true)
    ])
    h.run("show-all")
    #expect(h.frame(f) == CGRect(x: 880, y: 300, width: 400, height: 300), "180 of 400 points would show: slid left, no further than it must")
  }

  /// With the displays as they were, a strip left showing by hand is a place like any other.
  @Test func aWindowPushedAsideByHandUntilAStripShowsComesBackToThatStrip() {
    let h = Harness(displays: [Self.display], settings: Settings())
    let a = h.system.open(app: "Finder", frame: CGRect(x: 340, y: 120, width: 920, height: 436))
    let f = h.system.open(app: "Terminal", frame: CGRect(x: 40, y: 51, width: 877, height: 499))
    h.start()
    h.run("dock \(a.rawValue) left")
    let strip = CGRect(x: 1540, y: 400, width: 877, height: 499)
    h.system.userMove(f, to: strip)
    h.run("zoom \(a.rawValue)")
    h.run("show-all")
    #expect(h.frame(f) == strip)
  }

  /// At a pause and at a quit Arbor gives back what Arbor has put out of view, and nothing else. What its person pushed aside stays
  /// where it was left, however little of it shows, as long as somebody can get hold of it: at a pause, a resume, a quit and a start,
  /// whether or not floating windows make way.
  @Test(arguments: [false, true]) func whatItsPersonPushedAsideStaysAtAPauseAResumeAQuitAndAStart(makingWay: Bool) {
    let old = Harness(displays: [Self.display], settings: makingWay ? .makingWay : Settings())
    let f = old.system.open(app: "Mail", frame: CGRect(x: 240, y: 72, width: 1017, height: 584))
    old.start()
    let aside = CGRect(x: -425, y: 718, width: 1017, height: 584)
    old.system.userMove(f, to: aside)
    old.scheduler.advance(by: 5)
    old.system.clearFrameLog()
    for act in ["pause", "resume", "home", "show-all"] {
      #expect(old.run(act).ok)
      old.scheduler.advance(by: 5)
      #expect(old.frame(f) == aside && old.system.frameLog.isEmpty, "\(act): \(old.system.frameLog)")
    }
    old.controller.shutdown()
    #expect(old.frame(f) == aside && old.system.frameLog.isEmpty, "a quit: \(old.system.frameLog)")
    let h = old.newProcess()
    h.start()
    h.scheduler.advance(by: 5)
    h.run("home")
    #expect(h.frame(f) == aside && h.system.frameLog.isEmpty, "a start: \(h.system.frameLog)")
  }

  /// Two displays of unequal height, and a window dropped over the foot of the lower one, beside the higher: under half of it shows.
  /// The drop goes by the pointer, which is on the lower display. The window's middle is on neither, and nearer to the higher.
  func droppedBetweenTwoDisplays(makingWay: Bool) -> (Harness, f: WindowID, other: WindowID, dropped: CGRect) {
    let low = ReviewFloatingFrameTests.display("low", CGRect(x: -1440, y: 0, width: 1440, height: 900))
    let high = ReviewFloatingFrameTests.display("high", CGRect(x: 0, y: 0, width: 2560, height: 1440), isMain: true)
    let h = Harness(displays: [low, high], settings: makingWay ? .makingWay : Settings())
    h.start()
    let other = h.system.open(app: "Notes", frame: CGRect(x: 900, y: 200, width: 600, height: 400))
    let f = h.system.open(app: "Music", frame: CGRect(x: -1285, y: 78, width: 1126, height: 654))
    h.system.drag(f, through: [CGPoint(x: -722, y: 88), CGPoint(x: -168, y: 793)])
    h.scheduler.advance(by: 5)
    let dropped = CGRect(x: -731, y: 783, width: 1126, height: 654)
    #expect(h.frame(f) == dropped)
    h.system.clearFrameLog()
    return (h, f, other, dropped)
  }

  func letGo(_ h: Harness, by lettingGo: String) {
    if lettingGo == "pause" { #expect(h.run("pause").ok) } else { h.controller.shutdown() }
  }

  /// A hand that drags an edge leaves a window somewhere as much as one that drops it. Sized by an edge there, the window changed its
  /// display without a drop, which passed for an app's or a tool's doing, and a pause and a quit pulled it in.
  @Test(arguments: [false, true], ["pause", "quit"]) func whatAHandSizedByAnEdgeStaysToo(makingWay: Bool, lettingGo: String) {
    let (h, f, _, dropped) = droppedBetweenTwoDisplays(makingWay: makingWay)
    let sized = CGRect(origin: dropped.origin, size: CGSize(width: 1126, height: 600))
    h.system.userResize(f, to: sized)
    h.scheduler.advance(by: 5)
    letGo(h, by: lettingGo)
    #expect(h.frame(f) == sized && h.system.frameLog.isEmpty, "\(h.system.frameLog)")
  }

  /// Nor is it pulled from under the hand that still holds its edge, by whatever lays the display out meanwhile.
  @Test(arguments: [false, true]) func aWindowWhoseEdgeIsInTheHandIsNotPulledFromUnderIt(makingWay: Bool) {
    let (h, f, other, dropped) = droppedBetweenTwoDisplays(makingWay: makingWay)
    let sized = CGRect(origin: dropped.origin, size: CGSize(width: 1126, height: 600))
    h.system.userResize(f, to: sized, release: false)
    h.system.close(other)
    h.scheduler.advance(by: 5)
    h.run("home")
    h.scheduler.advance(by: 5)
    #expect(h.frame(f) == sized && h.system.frameLog.isEmpty, "held: \(h.system.frameLog)")
    h.system.releaseMouse()
    h.scheduler.advance(by: 5)
    for act in ["pause", "resume", "home"] {
      #expect(h.run(act).ok)
      h.scheduler.advance(by: 5)
      #expect(h.frame(f) == sized && h.system.frameLog.isEmpty, "\(act): \(h.system.frameLog)")
    }
  }

  /// Seven points further down crosses no border. It changed the window's display all the same, from the pointer's to the one nearest its
  /// middle, and that cost it the note of the hand.
  @Test(arguments: [false, true], ["pause", "quit"]) func aNudgeWhereItWasDroppedCrossesNoBorder(makingWay: Bool, lettingGo: String) {
    let (h, f, _, dropped) = droppedBetweenTwoDisplays(makingWay: makingWay)
    let nudged = dropped.offsetBy(dx: 0, dy: 7)
    h.system.userMove(f, to: nudged)
    h.scheduler.advance(by: 5)
    letGo(h, by: lettingGo)
    #expect(h.frame(f) == nudged && h.system.frameLog.isEmpty, "\(h.system.frameLog)")
  }

  /// The control of the three: what comes to the same place from the middle of the lower display, without a drag and with no edge in
  /// anybody's hand, is an app's or a tool's doing. Nobody chose that place, and Arbor does not leave it there.
  @Test(arguments: [false, true], ["pause", "quit"]) func whatComesAcrossABorderInNobodysHandIsFetched(makingWay: Bool, lettingGo: String) {
    let (h, f, _, dropped) = droppedBetweenTwoDisplays(makingWay: makingWay)
    h.system.drag(f, through: [CGPoint(x: -168, y: 793), CGPoint(x: -722, y: 88)])
    h.scheduler.advance(by: 5)
    h.system.userMove(f, to: dropped)
    h.scheduler.advance(by: 5)
    letGo(h, by: lettingGo)
    #expect(h.system.isVisible(f), "\(h.frame(f)!)")
  }

  /// The control: pushed so far that nobody could get hold of its title bar, it is fetched when Arbor lets go.
  @Test(arguments: [false, true]) func whatNobodyCouldGetHoldOfIsFetchedAtAPause(makingWay: Bool) {
    let h = Harness(displays: [Self.display], settings: makingWay ? .makingWay : Settings())
    let f = h.system.open(app: "Mail", frame: CGRect(x: 240, y: 72, width: 1017, height: 584))
    h.start()
    let outOfReach = CGRect(x: -1007, y: 718, width: 1017, height: 584)
    h.system.userMove(f, to: outOfReach)
    h.scheduler.advance(by: 5)
    #expect(h.frame(f) == outOfReach, "or something before the pause fetches it")
    #expect(h.run("pause").ok)
    #expect(h.system.isVisible(f), "\(h.frame(f)!)")
  }

  /// A change of displays can also cut off a window that is in view. It had more than half showing, and has not now.
  @Test func aWindowInViewThatAChangeOfDisplaysCutOffIsFitted() {
    let h = Harness(displays: [Self.display], settings: Settings())
    let a = h.system.open(app: "Finder", frame: CGRect(x: 340, y: 120, width: 920, height: 436))
    let f = h.system.open(app: "Terminal", frame: CGRect(x: 1100, y: 300, width: 400, height: 300))
    let g = h.system.open(app: "Notes", frame: CGRect(x: 100, y: 100, width: 700, height: 400))
    h.start()
    h.run("dock \(a.rawValue) left")
    h.system.setDisplays([
      DisplaySnapshot(
        id: DisplayID("main"), frame: CGRect(x: 0, y: 0, width: 1280, height: 800),
        visibleFrame: CGRect(x: 0, y: 31, width: 1280, height: 691), isMain: true, isBuiltIn: true)
    ])
    #expect(h.frame(f) == CGRect(x: 880, y: 300, width: 400, height: 300))
    #expect(h.frame(g) == CGRect(x: 100, y: 100, width: 700, height: 400), "the one that still shows is not touched")
  }

  // MARK: Order

  /// Out of view and back changes nobody's place in the order, and Arbor raises nothing but the window acted on.
  @Test func nothingIsRaisedWhenFloatingWindowsComeBack() {
    let desk = makeArrangedDesk()
    desk.h.run("zoom \(desk.safari.rawValue)")
    desk.h.system.clearRaiseLog()
    desk.h.run("show-all")
    #expect(desk.h.system.raiseLog.isEmpty, "\(desk.h.system.raiseLog)")
  }

  // MARK: The rule of the walks

  /// Three finds of the walks, cut down. A window opens over docked ones and stays, and the next unrelated event, a click on
  /// another window's title bar, shoved and shrank it. And with nothing docked at all, a window left hanging over an edge before Arbor
  /// started was pulled in when another window closed. And one that a hand had widened by its left edge, over the left edge of the main
  /// display and its foot, was pulled in by the next view key: its middle had left the display below, and nobody had noted the hand.
  @Test(arguments: [
    """
    launch
    open 102 Mail pid 1002 at 994 188 1320 686 min 760 400
    key down dock top
    open 104 Music pid 1006 at 1329 186 696 528 min 680 480
    grab 102
    release
    """,
    """
    open 101 Finder pid 1005 at 112 32 1058 458 min 501 300
    grab 101
    carry 1303 40
    release
    launch
    open 104 Safari pid 1000 at 20 113 1068 656 min 574 240
    close 104
    """,
    """
    launch
    open 105 Preview pid 1007 at 820 956 636 233
    displays side:188,1080,800,600:0,73,0,0 main:0,0,1920,1080:37,0,0,0* windows-silent
    dock right
    open 109 Preview pid 1007 at 59 803 397.5 559.25 title Untitled
    edge 109 -158 803 614.5 559.25 hold
    release
    in
    """,
  ]) func whatTheWalksFound(script: String) {
    #expect(ChaosRunner.replay(script) == nil)
  }

  /// The control of the rule itself: it speaks when something sets a floating window's frame as Arbor would, in the middle of a
  /// dock that is about another window.
  @Test func theRuleOfTheWalksSpeaksWhenAFloatingWindowIsMovedThatNobodyTouched() {
    let world = ChaosRunner()
    for line in [
      "open 101 Finder pid 1005 at 340 120 920 436", "open 102 Terminal pid 1004 at 40 51 877 499", "launch", "focus 101",
    ] { #expect(world.step(ChaosAction(text: line)).isEmpty) }
    var isDone = false
    world.system.willSetFrame = { [system = world.system] window, _ in
      guard !isDone, window == WindowID(101) else { return }
      isDone = true
      _ = system.setFrame(CGRect(x: 806, y: 51, width: 600, height: 499), of: WindowID(102))
    }
    #expect(world.step(.command("dock 101 left")).map(\.rule).contains("own-frame"))
  }

  /// And when one comes back somewhere else than it left from.
  @Test func theRuleOfTheWalksSpeaksWhenAFloatingWindowComesBackElsewhere() {
    let world = ChaosRunner()
    for line in [
      "open 101 Finder pid 1005 at 340 120 920 436", "open 102 Terminal pid 1004 at 40 51 877 499", "launch", "dock 101 left",
      "zoom 101",
    ] { #expect(world.step(ChaosAction(text: line)).isEmpty) }
    world.beforeTheNextCheck = { _ = $0.system.setFrame(CGRect(x: 806, y: 51, width: 600, height: 499), of: WindowID(102)) }
    #expect(world.step(.command("show-all")).map(\.rule).contains("own-frame-back"))
  }
}
