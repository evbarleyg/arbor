import ArborCore
@testable import ArborKit
import ArborTesting
import CoreGraphics
import Testing

/// What is found counts as left (collab/QUESTIONS.md, "Decided by the executor", 2026-10-15; the second of the seven rules). People park
/// windows three quarters off an edge. At a start, and when a window opens, nothing has changed, so nothing is in doubt: Arbor
/// fetches only what nobody could get hold of, a window with no 24 points of its title bar on any display, and that once.
@Suite @MainActor struct FoundCountsAsLeftTests {
  /// A quarter of each shows on a display of 1440 × 900, and its title bar can be taken hold of.
  nonisolated static let parkedByHand: [CGRect] = [
    CGRect(x: 1290, y: 300, width: 600, height: 400),  // over the right edge
    CGRect(x: -450, y: 300, width: 600, height: 400),  // over the left edge
    CGRect(x: 400, y: 800, width: 600, height: 400),  // over the bottom edge
    CGRect(x: 1140, y: 700, width: 600, height: 400),  // in the corner
    CGRect(x: 1416, y: 300, width: 600, height: 400),  // the least that counts: 24 points
    CGRect(x: -576, y: 300, width: 600, height: 400),
  ]

  /// Under half of each shows, and nobody could pull it back by its title bar.
  nonisolated static let outOfReach: [CGRect] = [
    CGRect(x: 1439, y: 868, width: 600, height: 400),  // where a run that did not quit cleanly leaves a window
    CGRect(x: 1439, y: 899, width: 600, height: 400),
    CGRect(x: -599, y: 868, width: 600, height: 400),
    CGRect(x: 1417, y: 300, width: 600, height: 400),  // a point short of 24
    CGRect(x: -577, y: 300, width: 600, height: 400),
    CGRect(x: 400, y: -300, width: 600, height: 400),  // its title bar is above the display
    CGRect(x: 400, y: 895, width: 600, height: 400),  // five points of it: too little to hit
    CGRect(x: 3000, y: 300, width: 600, height: 400),  // on no display at all
  ]

  private func moves(of window: WindowID, _ h: Harness) -> [CGRect] { h.system.frameLog.filter { $0.window == window }.map(\.frame) }

  /// Nothing comes later either: no timer, no report from macOS.
  private func letTimePass(_ h: Harness) {
    h.system.deliverEchoes()
    h.scheduler.advance(by: 5)
  }

  // MARK: What stays

  @Test(arguments: parkedByHand) func atAStartAWindowParkedOverTheEdgeIsSetNoFrame(frame: CGRect) {
    let h = Harness()
    let notes = h.system.open(app: "Notes", frame: frame)
    h.start()
    letTimePass(h)
    #expect(h.system.frameLog.isEmpty, "\(h.system.frameLog)")
    #expect(h.frame(notes) == frame)
    #expect(h.workspace.floating[notes] == frame, "and that is where it floats")
    #expect(h.controller.parked.isEmpty)
  }

  @Test(arguments: parkedByHand) func aWindowThatOpensOverTheEdgeIsSetNoFrame(frame: CGRect) {
    let h = Harness()
    h.system.open(app: "Safari")
    h.start()
    let notes = h.system.open(app: "Notes", frame: frame)
    letTimePass(h)
    #expect(h.system.frameLog.isEmpty, "\(h.system.frameLog)")
    #expect(h.frame(notes) == frame)
    #expect(h.workspace.floating[notes] == frame)
    #expect(h.controller.parked.isEmpty)
  }

  /// On a macOS Space that was not showing when Arbor started: it was there all along.
  @Test(arguments: parkedByHand) func aWindowFoundLaterOverTheEdgeIsSetNoFrame(frame: CGRect) {
    let h = Harness()
    let notes = h.system.open(app: "Notes", frame: frame)
    h.system.setListed(notes, false)
    h.start()
    h.system.setListed(notes, true)
    letTimePass(h)
    #expect(h.system.frameLog.isEmpty, "\(h.system.frameLog)")
    #expect(h.frame(notes) == frame)
    #expect(h.workspace.floating[notes] == frame)
  }

  /// Its app was excluded, and is not any more. Nobody has touched the window.
  @Test(arguments: parkedByHand) func aWindowArborBeginsToArrangeIsSetNoFrame(frame: CGRect) {
    var settings = Settings()
    settings.excludedBundleIDs = ["com.example.notes"]
    let h = Harness(settings: settings)
    let notes = h.system.open(app: "Notes", frame: frame)
    h.start()
    h.controller.apply(settings: Settings())
    letTimePass(h)
    #expect(h.system.frameLog.isEmpty, "\(h.system.frameLog)")
    #expect(h.workspace.floating[notes] == frame)
  }

  /// Arbor knows it from the last run, which quit while it was elsewhere. Its person has parked it since. The start sets no frame, takes
  /// the place for the window's own (FoundAtAStartTests), and no key that moves the view pulls it in.
  @Test(arguments: parkedByHand) func aWindowParkedWhileArborWasNotRunningStays(frame: CGRect) {
    let old = Harness()
    let notes = old.system.open(app: "Notes", frame: CGRect(x: 300, y: 200, width: 600, height: 400))
    old.start()
    old.controller.shutdown()
    let h = old.newProcess()
    h.system.moveSilently(notes, to: frame)
    h.system.clearFrameLog()
    h.start()
    letTimePass(h)
    #expect(h.workspace.floating[notes] == frame)
    for command in ["home", "desktop", "show-all", "relayout"] { h.run(command) }
    letTimePass(h)
    #expect(h.system.frameLog.isEmpty, "\(h.system.frameLog)")
    #expect(h.frame(notes) == frame)
  }

  /// The ordinary start, which is not the first: it was found there yesterday, state.json remembers it there, and there it is. The note of
  /// a hand is not saved, so it is found again: no start, no key that moves the view and no quit moves it, run after run.
  @Test(arguments: ["home", "desktop", "show-all", "relayout"], parkedByHand) func fromTheSecondStartOnItStaysToo(command: String, frame: CGRect) {
    var h = Harness()
    let notes = h.system.open(app: "Notes", frame: frame)
    h.system.open(app: "Safari")
    h.start()
    for _ in 1...2 {
      h.controller.shutdown()
      h = h.newProcess()
      h.start()
      h.run(command)
      letTimePass(h)
    }
    #expect(h.system.frameLog.isEmpty, "\(h.system.frameLog)")
    #expect(h.frame(notes) == frame)
    #expect(h.workspace.floating[notes] == frame)
  }

  /// Left is left: the keys that move the view or lay out afresh, with nothing docked, do not pull it in afterwards either.
  @Test(arguments: ["home", "desktop", "show-all", "relayout"], parkedByHand) func noLaterLayoutPullsInWhatWasFound(command: String, frame: CGRect) {
    let h = Harness()
    let notes = h.system.open(app: "Notes", frame: frame)
    h.system.open(app: "Safari")
    h.start()
    h.run(command)
    letTimePass(h)
    #expect(h.system.frameLog.isEmpty, "\(h.system.frameLog)")
    #expect(h.frame(notes) == frame)
  }

  /// The same for one that opened there, whatever lays out next: a key, or another window that closes.
  @Test(arguments: ["home", "desktop", "show-all", "relayout", "close"], parkedByHand)
  func noLaterLayoutPullsInWhatOpenedOverTheEdge(what: String, frame: CGRect) {
    let h = Harness()
    let safari = h.system.open(app: "Safari")
    h.start()
    let notes = h.system.open(app: "Notes", frame: frame)
    if what == "close" { h.system.close(safari) } else { h.run(what) }
    letTimePass(h)
    #expect(h.system.frameLog.isEmpty, "\(h.system.frameLog)")
    #expect(h.frame(notes) == frame)
  }

  /// Over a framed window, where there is no Desktop: it is a guest of that view, goes when the view goes, and comes back exactly there.
  @Test func whatOpensOverTheEdgeOfAFramedViewComesBackExactlyThere() {
    // Floating windows that make way: only they leave with the Desktop.
    let h = Harness(settings: .makingWay)
    let (safari, mail) = (h.system.open(app: "Safari"), h.system.open(app: "Mail"))
    h.start()
    h.run("dock \(safari.rawValue) left")
    h.run("dock \(mail.rawValue) right")
    h.run("zoom \(safari.rawValue)")
    h.system.userFocus(safari)
    let frame = CGRect(x: 1200, y: 100, width: 800, height: 600)
    let notes = h.system.open(app: "Notes", frame: frame)
    #expect(h.frame(notes) == frame)
    h.run("zoom \(mail.rawValue)")
    #expect(h.controller.parked.contains(notes), "or this proves nothing")
    h.run("back")
    letTimePass(h)
    #expect(h.frame(notes) == frame)
  }

  /// A switch of native tabs gives the window another number, and the note goes with it.
  @Test func anotherTabOfAWindowThatWasFoundStaysWhereTheGroupIs() {
    let h = Harness()
    let notes = h.system.open(app: "Notes", frame: Self.parkedByHand[0])
    h.system.open(app: "Safari")
    h.start()
    var tab = h.controller.windows[notes]!
    tab.id = WindowID(900)
    h.controller.windowReplaced(notes, by: tab)
    letTimePass(h)
    #expect(h.system.frameLog.isEmpty, "\(h.system.frameLog)")
    #expect(h.controller.chosenOnShape[tab.id]?.frame == Self.parkedByHand[0])
  }

  /// Nor does a dock on the other side of the display, which needs none of its room.
  @Test func aDockThatNeedsNoneOfItsRoomLeavesWhatWasFound() {
    let h = Harness()
    let notes = h.system.open(app: "Notes", frame: Self.parkedByHand[0])
    let safari = h.system.open(app: "Safari")
    h.start()
    h.run("dock \(safari.rawValue) left")
    letTimePass(h)
    #expect(moves(of: notes, h).isEmpty, "\(h.system.frameLog)")
    #expect(h.frame(notes) == Self.parkedByHand[0])
  }

  /// No display shows half of it. 200 points of its title bar are on the main one.
  @Test func aWindowAcrossTwoDisplaysWithUnderHalfOnEachIsSetNoFrame() {
    let side = DisplaySnapshot(
      id: DisplayID("side"), frame: CGRect(x: 1440, y: 500, width: 1280, height: 800),
      visibleFrame: CGRect(x: 1440, y: 525, width: 1280, height: 775), isMain: false)
    let h = Harness(displays: [FakeWindowSystem.standardDisplay, side])
    // 200 of its 1000 points of width on the main display; of the rest only the lower part is on the other.
    let frame = CGRect(x: 1240, y: 300, width: 1000, height: 400)
    let notes = h.system.open(app: "Notes", frame: frame)
    h.start()
    letTimePass(h)
    #expect(h.system.displayList.allSatisfy { frame.fractionInside($0.frame) < 0.5 }, "or this proves nothing")
    for command in ["home", "desktop", "show-all", "relayout"] { h.run(command) }
    letTimePass(h)
    #expect(h.system.frameLog.isEmpty, "\(h.system.frameLog)")
    #expect(h.frame(notes) == frame)
  }

  /// The title bar is within reach on the display next door, though the window counts as the main display's.
  @Test func aTitleBarWithinReachOnAnotherDisplayCounts() {
    let above = DisplaySnapshot(
      id: DisplayID("above"), frame: CGRect(x: 0, y: -800, width: 1280, height: 800),
      visibleFrame: CGRect(x: 0, y: -775, width: 1280, height: 775), isMain: false)
    let h = Harness(displays: [FakeWindowSystem.standardDisplay, above])
    // Over the right edge of both; its top 100 points are on the upper display.
    let frame = CGRect(x: 1200, y: -100, width: 1000, height: 400)
    let notes = h.system.open(app: "Notes", frame: frame)
    h.start()
    letTimePass(h)
    #expect(h.system.displayList.allSatisfy { frame.fractionInside($0.frame) < 0.5 }, "or this proves nothing")
    for command in ["home", "desktop", "show-all", "relayout"] { h.run(command) }
    letTimePass(h)
    #expect(h.system.frameLog.isEmpty, "\(h.system.frameLog)")
    #expect(h.frame(notes) == frame)
  }

  /// Found by a random walk. Its title bar is above the main display and within reach on the taller one next door. A dock needs its room,
  /// and pushed aside it must not keep hanging over the top, where its title bar would be on no display at all.
  @Test func pushedAsideItIsStillWithinReach() {
    let side = DisplaySnapshot(
      id: DisplayID("side"), frame: CGRect(x: 1080, y: -232, width: 2560, height: 1440),
      visibleFrame: CGRect(x: 1080, y: -232, width: 2560, height: 1440), isMain: false)
    let main = DisplaySnapshot(
      id: DisplayID("main"), frame: CGRect(x: 0, y: 0, width: 1080, height: 1920),
      visibleFrame: CGRect(x: 0, y: 25, width: 1080, height: 1895), isMain: true)
    let h = Harness(displays: [main, side])
    let frame = CGRect(x: 654, y: -50, width: 771, height: 655)
    let safari = h.system.open(app: "Safari", frame: frame)
    let notes = h.system.open(app: "Notes", frame: CGRect(x: 440, y: 1312, width: 345, height: 467))
    h.start()
    #expect(h.controller.titleBarIsWithinReach(frame) && h.frame(safari) == frame, "or this proves nothing")
    for edge in ["right", "left", "top", "bottom"] {
      h.run("dock \(notes.rawValue) \(edge)")
      letTimePass(h)
      #expect(h.controller.titleBarIsWithinReach(h.frame(safari)!), "docked at the \(edge): \(h.frame(safari)!)")
      h.run("float-all")
    }
  }

  /// The same, and it will not be as small as Arbor asks: the second try is held to the measure too.
  @Test func pushedAsideAWindowThatRefusesTheSizeIsStillWithinReach() {
    let side = DisplaySnapshot(
      id: DisplayID("side"), frame: CGRect(x: -1920, y: -285, width: 1920, height: 1080),
      visibleFrame: CGRect(x: -1920, y: -285, width: 1920, height: 1006), isMain: false)
    let main = DisplaySnapshot(
      id: DisplayID("main"), frame: CGRect(x: 0, y: 0, width: 1280, height: 800),
      visibleFrame: CGRect(x: 0, y: 0, width: 1280, height: 717), isMain: true)
    let h = Harness(displays: [main, side])
    let mail = h.system.open(app: "Mail", frame: CGRect(x: 178, y: 348, width: 481, height: 298))
    h.start()
    let frame = CGRect(x: -591, y: -88, width: 1526, height: 2068)
    let notes = h.system.open(app: "Notes", frame: frame, minimumSize: frame.size)
    #expect(h.controller.titleBarIsWithinReach(frame) && h.frame(notes) == frame, "or this proves nothing")
    h.run("dock \(mail.rawValue) left")
    letTimePass(h)
    #expect(h.controller.titleBarIsWithinReach(h.frame(notes)!), "\(h.frame(notes)!)")
  }

  /// A palette narrower than 24 points has no 24 points to show. All of its width is enough.
  @Test func aVeryNarrowWindowIsWithinReachWhenItsWholeWidthShows() {
    let h = Harness()
    let frame = CGRect(x: 700, y: 880, width: 20, height: 400)
    let palette = h.system.open(app: "Palette", frame: frame)
    h.start()
    for command in ["home", "desktop", "show-all", "relayout"] { h.run(command) }
    letTimePass(h)
    #expect(h.system.frameLog.isEmpty, "\(h.system.frameLog)")
    #expect(h.frame(palette) == frame)
  }

  // MARK: What is fetched, once

  @Test(arguments: outOfReach) func atAStartAWindowNobodyCouldGetHoldOfIsFetchedOnce(frame: CGRect) {
    let h = Harness()
    let notes = h.system.open(app: "Notes", frame: frame)
    h.start()
    letTimePass(h)
    #expect(moves(of: notes, h).count == 1, "\(h.system.frameLog)")
    #expect(h.visibleFrame.contains(h.frame(notes)!), "\(h.frame(notes)!)")
    #expect(h.frame(notes)!.size == frame.size)
    #expect(h.workspace.floating[notes] == h.frame(notes))
    #expect(h.controller.parked.isEmpty)
  }

  @Test(arguments: outOfReach) func aWindowThatOpensWhereNobodyCouldGetHoldOfItIsFetchedOnce(frame: CGRect) {
    let h = Harness()
    h.system.open(app: "Safari")
    h.start()
    let notes = h.system.open(app: "Notes", frame: frame)
    letTimePass(h)
    #expect(moves(of: notes, h).count == 1, "\(h.system.frameLog)")
    #expect(h.visibleFrame.contains(h.frame(notes)!), "\(h.frame(notes)!)")
    #expect(h.frame(notes)!.size == frame.size)
    #expect(h.controller.parked.isEmpty)
  }

  /// A guard, which held before: what was fetched is its person's from then on. They push it over the edge again, and there it stays.
  @Test func whatWasFetchedAndIsParkedByHandAfterwardsStays() {
    let h = Harness()
    let notes = h.system.open(app: "Notes", frame: Self.outOfReach[0])
    h.start()
    #expect(moves(of: notes, h).count == 1)
    h.system.clearFrameLog()
    h.system.userMove(notes, to: Self.parkedByHand[0])
    letTimePass(h)
    #expect(h.system.frameLog.isEmpty, "\(h.system.frameLog)")
    #expect(h.frame(notes) == Self.parkedByHand[0])
  }

  /// Nothing new moves: more than half of it shows, so it was never fetched, title bar or no.
  @Test func aWindowOfWhichMoreThanHalfShowsStaysWhereverItsTitleBarIs() {
    let h = Harness()
    let frame = CGRect(x: 400, y: -100, width: 600, height: 400)
    let notes = h.system.open(app: "Notes", frame: frame)
    h.start()
    letTimePass(h)
    #expect(h.system.frameLog.isEmpty, "\(h.system.frameLog)")
    #expect(h.frame(notes) == frame)
  }

  // MARK: Where Arbor itself is the reason

  /// [safari | Desktop | mail], framed on Safari: Mail is in the corner, by Arbor's doing.
  private func mailOutOfView() -> (h: Harness, mail: WindowID) {
    let h = Harness()
    let safari = h.system.open(app: "Safari")
    let mail = h.system.open(app: "Mail")
    h.start()
    h.run("dock \(safari.rawValue) left")
    h.run("dock \(mail.rawValue) right")
    h.run("zoom \(safari.rawValue)")
    h.system.userFocus(safari)
    h.system.clearFrameLog()
    return (h, mail)
  }

  /// Apps open a window beside the one they have. Nobody left it there: the place follows from where Arbor put the other.
  @Test func aWindowThatOpensBesideItsAppsWindowOutOfViewIsFetchedOnce() {
    let (h, mail) = mailOutOfView()
    let beside = CGRect(origin: h.frame(mail)!.origin, size: CGSize(width: 500, height: 300)).offsetBy(dx: -200, dy: -20)
    let message = h.system.open(app: "Mail", frame: beside)
    letTimePass(h)
    #expect(moves(of: message, h).count == 1, "\(h.system.frameLog)")
    #expect(h.visibleFrame.contains(h.frame(message)!), "\(h.frame(message)!)")
  }

  /// Arbor was killed with Mail in the corner, or lost its permission, and Mail opened the message while nobody listened. The next start
  /// finds it, and the reason it is there is still Arbor.
  @Test func aWindowFoundBesideItsAppsWindowThatACrashLeftInTheCornerIsFetchedOnce() {
    let (old, mail) = mailOutOfView()
    let beside = CGRect(origin: old.frame(mail)!.origin, size: CGSize(width: 500, height: 300)).offsetBy(dx: -200, dy: -20)
    old.controller.saveNow()
    let h = old.newProcess()
    let message = h.system.open(app: "Mail", frame: beside)
    h.system.clearFrameLog()
    h.start()
    letTimePass(h)
    #expect(h.controller.titleBarIsWithinReach(beside), "or this proves nothing")
    #expect(moves(of: message, h).count == 1, "\(h.system.frameLog)")
    #expect(h.visibleFrame.contains(h.frame(message)!), "\(h.frame(message)!)")
  }

  /// Its person, not Arbor, has Mail's docked window in the Dock. Where Mail opens another has nothing to do with Arbor.
  @Test func aWindowThatOpensWhileItsAppsWindowIsInTheDockStays() {
    let h = Harness()
    let (safari, mail) = (h.system.open(app: "Safari"), h.system.open(app: "Mail"))
    h.start()
    h.run("dock \(safari.rawValue) left")
    h.run("dock \(mail.rawValue) right")
    h.system.setMinimized(mail, true)
    letTimePass(h)
    h.system.clearFrameLog()
    let message = h.system.open(app: "Mail", frame: Self.parkedByHand[2])
    #expect(moves(of: message, h).isEmpty, "\(h.system.frameLog)")
    #expect(h.frame(message) == Self.parkedByHand[2])
  }

  /// The control: the same place, and no window of its app is out of view.
  @Test func anotherAppsWindowThatOpensThereStays() {
    let (h, mail) = mailOutOfView()
    let beside = CGRect(origin: h.frame(mail)!.origin, size: CGSize(width: 500, height: 300)).offsetBy(dx: -200, dy: -20)
    let notes = h.system.open(app: "Notes", pid: 2000, frame: beside)
    #expect(moves(of: notes, h).isEmpty, "\(h.system.frameLog)")
    #expect(h.frame(notes) == beside)
  }

  /// With a display on either side no corner hides a window: macOS stops it with its title bar above the bottom edge, and the
  /// display next door shows all of that. A hand could take it, but no hand put it there: a run that did not quit cleanly did.
  @Test func whatACrashLeftInItsCornerBetweenTwoDisplaysIsFetchedOnce() {
    func display(_ name: String, x: CGFloat, isMain: Bool = false) -> DisplaySnapshot {
      DisplaySnapshot(
        id: DisplayID(name), frame: CGRect(x: x, y: 0, width: 1440, height: 900),
        visibleFrame: CGRect(x: x, y: 25, width: 1440, height: 875), isMain: isMain)
    }
    let three = [display("left", x: -1440), display("main", x: 0, isMain: true), display("right", x: 1440)]
    let old = Harness(displays: three)
    let (safari, mail) = (old.system.open(app: "Safari"), old.system.open(app: "Mail", frame: CGRect(x: 300, y: 200, width: 600, height: 400)))
    old.start()
    old.run("dock \(safari.rawValue) left")
    old.run("dock \(mail.rawValue) right")
    old.run("zoom \(safari.rawValue)")
    let left = old.frame(mail)!
    #expect(old.controller.parked.contains(mail))
    #expect(old.controller.titleBarIsWithinReach(left), "or this proves nothing: \(left)")

    // Killed, and its state file lost: the next run knows nothing of either window.
    let h = Harness(displays: three)
    h.system.open(app: "Safari", frame: old.frame(safari)!)
    #expect(h.system.open(app: "Mail", frame: left) == mail)
    h.start()
    letTimePass(h)
    #expect(moves(of: mail, h).count == 1, "\(h.system.frameLog)")
    #expect(three.contains { $0.visibleFrame.contains(h.frame(mail)!) }, "\(h.frame(mail)!), from \(left)")
  }

  /// The same, and the state file is there, which is the ordinary case: Mail floated, went out with the view, and Arbor was killed.
  @Test func whatACrashLeftInItsCornerBetweenTwoDisplaysIsFetchedThoughItIsRemembered() {
    func display(_ name: String, x: CGFloat, isMain: Bool = false) -> DisplaySnapshot {
      DisplaySnapshot(
        id: DisplayID(name), frame: CGRect(x: x, y: 0, width: 1440, height: 900),
        visibleFrame: CGRect(x: x, y: 25, width: 1440, height: 875), isMain: isMain)
    }
    let three = [display("left", x: -1440), display("main", x: 0, isMain: true), display("right", x: 1440)]
    // Floating windows that make way: only they leave with the Desktop.
    let old = Harness(displays: three, settings: .makingWay)
    let own = CGRect(x: 780, y: 200, width: 600, height: 400)
    let (safari, mail) = (old.system.open(app: "Safari"), old.system.open(app: "Mail", frame: own))
    old.start()
    old.run("dock \(safari.rawValue) left")
    old.run("zoom \(safari.rawValue)")
    #expect(old.controller.parked.contains(mail) && old.controller.titleBarIsWithinReach(old.frame(mail)!), "or this proves nothing")
    old.controller.saveNow()
    let h = old.newProcess()
    h.system.clearFrameLog()
    h.start()
    letTimePass(h)
    #expect(h.frame(mail) == own, "\(h.frame(mail)!)")
    #expect(moves(of: mail, h).count == 1, "\(h.system.frameLog)")
  }

  /// The same, in the Dock when Arbor starts, so that it cannot be fetched yet. That is no place its person left it in: out of the Dock
  /// again it does not go on hanging there.
  @Test func whatACrashLeftInItsCornerAndIsInTheDockAtTheStartIsNotTakenForLeft() {
    func display(_ name: String, x: CGFloat, isMain: Bool = false) -> DisplaySnapshot {
      DisplaySnapshot(
        id: DisplayID(name), frame: CGRect(x: x, y: 0, width: 1440, height: 900),
        visibleFrame: CGRect(x: x, y: 25, width: 1440, height: 875), isMain: isMain)
    }
    let three = [display("left", x: -1440), display("main", x: 0, isMain: true), display("right", x: 1440)]
    let h = Harness(displays: three)
    let corner = CGRect(x: 1439, y: 868, width: 600, height: 400)
    let mail = h.system.open(app: "Mail", frame: corner)
    h.system.setMinimized(mail, true)
    h.start()
    #expect(h.controller.titleBarIsWithinReach(corner) && h.controller.isInAParkingCorner(mail), "or this proves nothing")
    #expect(h.controller.chosenOnShape[mail] == nil)
    h.system.setMinimized(mail, false)
    h.run("home")
    letTimePass(h)
    #expect(three.contains { $0.visibleFrame.contains(h.frame(mail)!) }, "\(h.frame(mail)!)")
  }

  // MARK: On the way out Arbor gives back what it took, and touches nothing else

  nonisolated static let waysOut = ["quit", "pause", "float-all"]

  private func leave(_ h: Harness, by way: String) {
    if way == "quit" { h.controller.shutdown() } else { #expect(h.run(way).ok, "\(way)") }
    letTimePass(h)
  }

  /// (Float All has its turn below: with nothing docked it refuses.)
  @Test(arguments: ["quit", "pause"], parkedByHand) func aWindowFoundOverTheEdgeIsSetNoFrameOnTheWayOut(way: String, frame: CGRect) {
    let h = Harness()
    let notes = h.system.open(app: "Notes", frame: frame)
    h.start()
    leave(h, by: way)
    #expect(moves(of: notes, h).isEmpty, "\(h.system.frameLog)")
    #expect(h.frame(notes) == frame)
  }

  /// Over the right edge, with Safari docked on the left: before that dock, or after it.
  @Test(arguments: waysOut, [true, false]) func aWindowParkedByHandIsSetNoFrameOnTheWayOut(way: String, beforeTheDock: Bool) {
    let h = Harness()
    let safari = h.system.open(app: "Safari")
    let notes = h.system.open(app: "Notes", frame: CGRect(x: 800, y: 300, width: 600, height: 400))
    h.start()
    if beforeTheDock { h.system.userMove(notes, to: Self.parkedByHand[0]) }
    h.run("dock \(safari.rawValue) left")
    if !beforeTheDock { h.system.userMove(notes, to: Self.parkedByHand[0]) }
    letTimePass(h)
    leave(h, by: way)
    #expect(moves(of: notes, h).isEmpty, "\(h.system.frameLog)")
    #expect(h.frame(notes) == Self.parkedByHand[0])
  }

  /// What Arbor took it gives back as it was: found over the edge, out of view with the Desktop, and back exactly there, in one move.
  @Test(arguments: waysOut, parkedByHand) func whatWasFoundOverTheEdgeAndWentOutWithTheViewIsGivenBackAsItWas(way: String, frame: CGRect) {
    // Floating windows that make way: only they leave with the Desktop.
    let h = Harness(settings: .makingWay)
    let notes = h.system.open(app: "Notes", frame: frame)
    let safari = h.system.open(app: "Safari")
    h.start()
    // On the side that needs none of its room.
    h.run("dock \(safari.rawValue) \(frame.minX < 0 ? "right" : "left")")
    h.run("zoom \(safari.rawValue)")
    #expect(h.controller.parked.contains(notes))
    h.system.clearFrameLog()
    leave(h, by: way)
    #expect(h.frame(notes) == frame)
    #expect(moves(of: notes, h).count == 1, "\(h.system.frameLog)")
  }

  /// Dropped where nobody could get hold of it again, it is not given back there: the next layout would fetch it, a second move.
  @Test(arguments: waysOut, outOfReach) func whatWasLeftOutOfReachAndWentOutWithTheViewComesBackIntoViewInOneMove(way: String, frame: CGRect) {
    // Floating windows that make way: only they leave with the Desktop.
    let h = Harness(settings: .makingWay)
    let notes = h.system.open(app: "Notes", frame: CGRect(x: 700, y: 200, width: 600, height: 400))
    let (safari, mail) = (h.system.open(app: "Safari"), h.system.open(app: "Mail"))
    h.start()
    h.run("dock \(safari.rawValue) left")
    h.system.userMove(notes, to: frame)
    h.run("zoom \(safari.rawValue)")
    h.system.clearFrameLog()
    leave(h, by: way)
    #expect(h.visibleFrame.contains(h.frame(notes)!), "\(h.frame(notes)!)")
    #expect(moves(of: notes, h).count == 1, "\(h.system.frameLog)")
    guard way == "float-all" else { return }
    h.system.setMinimized(mail, true)
    letTimePass(h)
    #expect(moves(of: notes, h).count == 1, "\(h.system.frameLog)")
  }

  /// Its title bar is above its own display and within reach on the one above, which is unplugged a moment before the quit, so that
  /// Arbor has not heard. Given back where it was left, nobody could get hold of it any more. (Arbor looks at the displays first.)
  @Test(arguments: ["quit", "pause"]) func whatWasWithinReachOnADisplayThatHasJustGoneIsNotGivenBackThere(way: String) {
    let above = DisplaySnapshot(
      id: DisplayID("above"), frame: CGRect(x: 0, y: -1080, width: 1920, height: 1080),
      visibleFrame: CGRect(x: 0, y: -1080, width: 1920, height: 1080), isMain: false)
    // Floating windows that make way: only they leave with the Desktop.
    let h = Harness(displays: [FakeWindowSystem.standardDisplay, above], settings: .makingWay)
    let frame = CGRect(x: 100, y: -60, width: 800, height: 700)
    let notes = h.system.open(app: "Notes", frame: frame)
    let safari = h.system.open(app: "Safari")
    h.start()
    h.run("dock \(safari.rawValue) right")
    h.run("zoom \(safari.rawValue)")
    #expect(h.controller.parked.contains(notes) && h.controller.chosenOnShape[notes]?.frame == frame, "or this proves nothing")
    let listener = h.system.events
    h.system.events = nil
    h.system.unplug(above.id)
    h.system.events = listener
    leave(h, by: way)
    #expect(h.frame(notes)!.minY >= h.visibleFrame.minY, "\(h.frame(notes)!)")
  }

  /// Let go by hand across two displays, one above the other. Its app hangs, the lower display is unplugged, and 25 points of its top are
  /// left on the upper one, title bar within reach. No hand left it there: the change of displays did, and the fit it is owed could not
  /// be made. The net spares what is known to be where it was left, not whatever can be reached.
  @Test(arguments: ["quit", "pause"]) func whatAChangeOfDisplaysLeftHangingIsFetchedOnTheWayOutThoughItIsWithinReach(way: String) {
    let main = DisplaySnapshot(
      id: DisplayID("main"), frame: CGRect(x: 0, y: 0, width: 2560, height: 1440),
      visibleFrame: CGRect(x: 0, y: 25, width: 2560, height: 1415), isMain: true)
    let below = DisplaySnapshot(
      id: DisplayID("side"), frame: CGRect(x: 524, y: 1440, width: 1512, height: 982),
      visibleFrame: CGRect(x: 524, y: 1440, width: 1512, height: 982), isMain: false)
    let h = Harness(displays: [main, below])
    let notes = h.system.open(app: "Notes", pid: 1001, frame: CGRect(x: 300, y: 200, width: 800, height: 600))
    h.start()
    let across = CGRect(x: 800, y: 1415, width: 800, height: 600)
    h.system.userMove(notes, to: across)
    h.system.setUnresponsive(pid: 1001, true)
    h.system.unplug(below.id)
    letTimePass(h)
    h.system.setUnresponsive(pid: 1001, false)
    #expect(h.frame(notes) == across && h.controller.titleBarIsWithinReach(across), "or this proves nothing: \(h.frame(notes)!)")
    leave(h, by: way)
    #expect(main.visibleFrame.contains(h.frame(notes)!), "\(h.frame(notes)!)")
  }

  /// Found by the random walks. A window that is kept in view is dragged over the edge, and its pin brings it in again, as ever. Given back
  /// where the hand left it, the pin would fetch it once more: there and back for one key. What its pin promises comes first.
  @Test(arguments: waysOut) func aWindowKeptInViewIsNotGivenBackOverTheEdge(way: String) {
    let h = Harness()
    let (safari, mail) = (h.system.open(app: "Safari"), h.system.open(app: "Mail"))
    let notes = h.system.open(app: "Notes", frame: CGRect(x: 700, y: 200, width: 600, height: 400))
    h.start()
    h.run("dock \(safari.rawValue) left")
    h.run("pin \(notes.rawValue)")
    h.system.userMove(notes, to: Self.parkedByHand[2])
    h.system.setMinimized(mail, true)
    letTimePass(h)
    let broughtIn = h.frame(notes)!
    #expect(h.system.isVisible(notes) && broughtIn != Self.parkedByHand[2], "or this proves nothing: \(broughtIn)")
    h.system.clearFrameLog()
    leave(h, by: way)
    #expect(moves(of: notes, h).count <= 1, "\(h.system.frameLog)")
    #expect(h.system.isVisible(notes), "\(h.frame(notes)!)")
  }

  /// Found by the random walks. Left lower than macOS lets Arbor put a window: it keeps a title bar above the bottom edge, and stops the
  /// window 12 points short. That is as near as it can be given back, and the net has no reason to fetch it from there: one move.
  @Test(arguments: ["quit", "pause"]) func givenBackAsNearAsMacOSAllowsItIsNotFetchedFromThere(way: String) {
    // Floating windows that make way: only they leave with the Desktop.
    let h = Harness(settings: .makingWay)
    let notes = h.system.open(app: "Notes", frame: CGRect(x: 700, y: 200, width: 600, height: 400))
    let safari = h.system.open(app: "Safari")
    h.start()
    h.run("dock \(safari.rawValue) left")
    let left = CGRect(x: 800, y: 880, width: 600, height: 400)
    h.system.userMove(notes, to: left)
    h.run("zoom \(safari.rawValue)")
    #expect(h.controller.parked.contains(notes) && h.controller.titleBarIsWithinReach(left), "or this proves nothing")
    h.system.clearFrameLog()
    leave(h, by: way)
    #expect(moves(of: notes, h).count == 1, "\(h.system.frameLog)")
    let now = h.frame(notes)!
    #expect(now.minX == left.minX && now.size == left.size && h.controller.titleBarIsWithinReach(now), "\(now)")
    #expect(now.minY < left.minY, "macOS stopped it short, or this proves nothing: \(now)")
  }

  /// The last net is still there. This is where the window floats as far as Arbor knows, so nothing before the net has a reason to
  /// move it; and whoever put it where nobody could get hold of it, it is not left there.
  @Test(arguments: ["quit", "pause"], outOfReach) func aWindowNobodyCouldGetHoldOfIsFetchedOnTheWayOut(way: String, frame: CGRect) {
    let h = Harness()
    let notes = h.system.open(app: "Notes", frame: CGRect(x: 300, y: 200, width: 600, height: 400))
    h.start()
    h.system.userMove(notes, to: frame)
    #expect(h.workspace.floating[notes] == frame && h.frame(notes) == frame, "or something before the net fetches it")
    leave(h, by: way)
    #expect(h.visibleFrame.contains(h.frame(notes)!), "\(h.frame(notes)!)")
  }

  /// What Arbor itself took out of view comes back, as ever.
  @Test(arguments: waysOut) func whatArborTookOutOfViewComesBackOnTheWayOut(way: String) {
    let (h, mail) = mailOutOfView()
    leave(h, by: way)
    #expect(h.visibleFrame.contains(h.frame(mail)!), "\(h.frame(mail)!)")
    #expect(moves(of: mail, h).count == 1, "\(h.system.frameLog)")
  }

  // MARK: After the displays have changed, something has changed

  /// It opened while there was no display at all, so it belongs to no arrangement, remembered or not. One comes: where the window is was
  /// no choice on this display.
  @Test(arguments: parkedByHand) func aWindowThatHadNoDisplayAndShowsUnderHalfOnTheOneThatComesIsBroughtIn(frame: CGRect) {
    let h = Harness()
    h.system.open(app: "Safari")
    h.start()
    h.system.setDisplays([])
    let notes = h.system.open(app: "Notes", frame: frame)
    #expect(h.controller.workspaceID(containing: notes) == nil, "or this proves nothing")
    h.system.setDisplays([FakeWindowSystem.standardDisplay])
    letTimePass(h)
    #expect(h.visibleFrame.contains(h.frame(notes)!), "\(h.frame(notes)!)")
  }
}
