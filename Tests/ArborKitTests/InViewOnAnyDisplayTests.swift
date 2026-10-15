import ArborCore
import ArborKit
import ArborTesting
import CoreGraphics
import Testing

/// The window with the keyboard goes, and a window in view gets the keyboard; only if nothing is in view does a view follow.
/// "In view" is asked of all displays: a display that shows nothing but its wallpaper after its last window closed is what a
/// person expects of closing the last window, and nobody at the other display asked for anything. The order is the product
/// owner's (collab/QUESTIONS.md, "closing a window takes nobody elsewhere; verdict, and one case more").
@Suite @MainActor struct InViewOnAnyDisplayTests {
  /// Main: Notes framed, Safari docked beside it and out of view. Second display: nothing but `f`, which floats and has the
  /// keyboard.
  func aLoneWindowOnTheSecondDisplay(of app: String, pid: Int32) -> (Harness, notes: WindowID, safari: WindowID, f: WindowID) {
    let h = Harness(displays: [FakeWindowSystem.standardDisplay, Workload.secondDisplay])
    let second = h.system.displayList[1].frame
    let notes = h.system.open(app: "Notes", pid: 11, frame: CGRect(x: 100, y: 100, width: 600, height: 400))
    let safari = h.system.open(app: "Safari", pid: 12, frame: CGRect(x: 300, y: 200, width: 600, height: 400))
    let f = h.system.open(app: app, pid: pid, frame: Self.place(on: second, x: 200))
    h.start()
    h.run("dock \(notes.rawValue) left")
    h.run("dock \(safari.rawValue) right")
    h.run("zoom \(notes.rawValue)")
    h.system.userFocus(f)
    h.scheduler.advance(by: 2)
    #expect(h.system.focused == f && !h.system.isVisible(safari) && h.system.isVisible(notes))
    return (h, notes, safari, f)
  }

  static let third = DisplaySnapshot(
    id: DisplayID("third"), frame: CGRect(x: 3360, y: 0, width: 1920, height: 1080),
    visibleFrame: CGRect(x: 3360, y: 25, width: 1920, height: 1055), isMain: false)

  static func place(on display: CGRect, x: CGFloat) -> CGRect {
    CGRect(x: display.minX + x, y: display.minY + 200, width: 400, height: 300)
  }

  func realMoves(_ h: Harness, since mark: Int) -> [FakeWindowSystem.Move] {
    h.system.moveLog[mark...].filter { $0.before != $0.after }
  }

  /// macOS picks the app's other window, out of view on the other display, where Notes is in view.
  @Test(arguments: ["close", "minimize"], [false, true])
  func aGoingOnOneDisplayMovesNoViewOnAnother(going: String, goingFirst: Bool) {
    let (h, notes, safari, f) = aLoneWindowOnTheSecondDisplay(of: "Safari", pid: 12)
    let mark = h.system.moveLog.count
    if goingFirst { h.system.echoes.keyboard = false }
    if going == "close" { h.system.close(f) } else { h.system.setMinimized(f, true) }
    if goingFirst { h.system.userFocus(safari) }
    h.scheduler.advance(by: 2)
    #expect(realMoves(h, since: mark).isEmpty, "\(realMoves(h, since: mark))")
    #expect(!h.system.isVisible(safari))
    #expect(h.system.focused == notes)
    expectWindowsMatchLayout(h)
  }

  /// And when nothing says who has the keyboard now.
  @Test func norWhenNothingReportsTheNewFocus() {
    let (h, notes, safari, f) = aLoneWindowOnTheSecondDisplay(of: "Safari", pid: 12)
    let mark = h.system.moveLog.count
    h.system.echoes.keyboard = false
    h.system.close(f)
    h.system.focused = safari
    h.scheduler.advance(by: 2)
    #expect(realMoves(h, since: mark).isEmpty, "\(realMoves(h, since: mark))")
    #expect(h.system.focused == notes)
    expectWindowsMatchLayout(h)
  }

  /// Its app's last window: macOS picks none, and after a person's own act macOS decides (board 0.20). Arbor steps in where
  /// macOS picks a window that Arbor keeps out of view, and only there. A control: so it was before.
  @Test func closingAnAppsLastWindowBringsNoAppForwardOnAnotherDisplay() {
    let (h, _, _, f) = aLoneWindowOnTheSecondDisplay(of: "Preview", pid: 13)
    let (asked, mark) = (h.system.focusLog.count, h.system.moveLog.count)
    h.system.close(f)
    h.scheduler.advance(by: 2)
    #expect(h.system.focused == nil)
    #expect(h.system.focusLog.count == asked)
    #expect(realMoves(h, since: mark).isEmpty)
    expectWindowsMatchLayout(h)
  }

  /// A window beside the one that went comes first, whichever was used last: the eyes and the pointer are there. A control: so
  /// it was while only that display was asked.
  @Test(arguments: [false, true]) func aWindowInViewOnTheSameDisplayComesFirst(theOtherDisplaysWasUsedLast: Bool) {
    let (h, notes, _, f) = aLoneWindowOnTheSecondDisplay(of: "Safari", pid: 12)
    let second = h.system.displayList[1].frame
    let beside = h.system.open(app: "Mail", pid: 14, frame: Self.place(on: second, x: 800))
    h.system.userFocus(theOtherDisplaysWasUsedLast ? beside : notes)
    h.system.userFocus(theOtherDisplaysWasUsedLast ? notes : beside)
    h.system.userFocus(f)
    h.scheduler.advance(by: 2)
    let mark = h.system.moveLog.count
    h.system.close(f)
    h.scheduler.advance(by: 2)
    #expect(h.system.focused == beside)
    #expect(realMoves(h, since: mark).isEmpty)
    expectWindowsMatchLayout(h)
  }

  /// Among several there, the one used last. A control too.
  @Test(arguments: [false, true]) func ofSeveralOnOneDisplayTheOneUsedLastGetsIt(theLeftOne: Bool) {
    let (h, _, _, f) = aLoneWindowOnTheSecondDisplay(of: "Safari", pid: 12)
    let second = h.system.displayList[1].frame
    let left = h.system.open(app: "Mail", pid: 14, frame: Self.place(on: second, x: 700))
    let right = h.system.open(app: "Music", pid: 15, frame: Self.place(on: second, x: 1200))
    h.system.userFocus(theLeftOne ? right : left)
    h.system.userFocus(theLeftOne ? left : right)
    h.system.userFocus(f)
    h.scheduler.advance(by: 2)
    h.system.close(f)
    h.scheduler.advance(by: 2)
    #expect(h.system.focused == (theLeftOne ? left : right))
    expectWindowsMatchLayout(h)
  }

  /// With none there, the display of the window that macOS picked comes next: that is where its app goes on. Mail, on a display
  /// that comes before it in every list, was used after Notes.
  @Test(arguments: ["the next window is named first", "the going is reported first", "nothing names the next window"])
  func thenTheDisplayOfTheWindowThatMacOSPicked(order: String) {
    let third = Self.third
    let h = Harness(displays: [FakeWindowSystem.standardDisplay, Workload.secondDisplay, third])
    let mail = h.system.open(app: "Mail", pid: 14, frame: CGRect(x: 100, y: 100, width: 600, height: 400))
    let notes = h.system.open(app: "Notes", pid: 11, frame: Self.place(on: third.frame, x: 100))
    let safari = h.system.open(app: "Safari", pid: 12, frame: Self.place(on: third.frame, x: 600))
    let f = h.system.open(app: "Safari", pid: 12, frame: Self.place(on: h.system.displayList[1].frame, x: 200))
    h.start()
    h.run("dock \(notes.rawValue) left")
    h.run("dock \(safari.rawValue) right")
    h.run("zoom \(notes.rawValue)")
    h.system.userFocus(mail)
    h.system.userFocus(f)
    h.scheduler.advance(by: 2)
    #expect(h.system.focused == f && !h.system.isVisible(safari) && h.system.isVisible(notes) && h.system.isVisible(mail))
    let mark = h.system.moveLog.count
    if order != "the next window is named first" { h.system.echoes.keyboard = false }
    h.system.close(f)
    if order == "the going is reported first" { h.system.userFocus(safari) }
    if order == "nothing names the next window" { h.system.focused = safari }
    h.scheduler.advance(by: 2)
    #expect(h.system.focused == notes)
    #expect(realMoves(h, since: mark).isEmpty, "\(realMoves(h, since: mark))")
    expectWindowsMatchLayout(h)
  }

  /// With none there either, any other display.
  @Test func thenAnyOtherDisplay() {
    let h = Harness(displays: [FakeWindowSystem.standardDisplay, Workload.secondDisplay, Self.third])
    let mail = h.system.open(app: "Mail", pid: 14, frame: CGRect(x: 100, y: 100, width: 600, height: 400))
    let safari = h.system.open(app: "Safari", pid: 12, frame: Self.place(on: Self.third.frame, x: 600))
    let f = h.system.open(app: "Safari", pid: 12, frame: Self.place(on: h.system.displayList[1].frame, x: 200))
    h.start()
    h.run("dock \(safari.rawValue) left")
    h.system.cursor = CGPoint(x: Self.third.frame.midX, y: Self.third.frame.midY)  // whose view `desktop` is about
    h.run("desktop")
    h.system.userFocus(f)
    h.scheduler.advance(by: 2)
    #expect(h.system.focused == f && !h.system.isVisible(safari) && h.system.isVisible(mail))
    let mark = h.system.moveLog.count
    h.system.close(f)
    h.scheduler.advance(by: 2)
    #expect(h.system.focused == mail)
    #expect(realMoves(h, since: mark).isEmpty, "\(realMoves(h, since: mark))")
    expectWindowsMatchLayout(h)
  }

  /// ⌘H: macOS brings another app forward, and its window is out of view on the other display.
  @Test func hidingTheOnlyAppOnADisplayMovesNoViewOnAnother() {
    let (h, notes, safari, _) = aLoneWindowOnTheSecondDisplay(of: "Preview", pid: 13)
    let mark = h.system.moveLog.count
    h.system.echoes.keyboard = false
    h.system.setHidden(pid: 13, true)
    h.system.userFocus(safari)
    h.scheduler.advance(by: 2)
    #expect(realMoves(h, since: mark).isEmpty, "\(realMoves(h, since: mark))")
    #expect(h.system.focused == notes && !h.system.isVisible(safari))
    expectWindowsMatchLayout(h)
  }

  /// Nothing is in view on any display: typing into a window nobody sees is worse than a view that moves. A control too.
  @Test func withNothingInViewAnywhereTheViewFollows() {
    let h = Harness(displays: [FakeWindowSystem.standardDisplay, Workload.secondDisplay])
    let second = h.system.displayList[1].frame
    let safari = h.system.open(app: "Safari", pid: 12, frame: CGRect(x: 300, y: 200, width: 600, height: 400))
    let f = h.system.open(app: "Safari", pid: 12, frame: Self.place(on: second, x: 200))
    h.start()
    h.run("dock \(safari.rawValue) left")
    h.run("desktop")
    h.system.userFocus(f)
    h.scheduler.advance(by: 2)
    #expect(!h.system.isVisible(safari))
    h.system.close(f)
    #expect(h.system.isVisible(safari))
    #expect(h.system.focused == safari)
    expectWindowsMatchLayout(h)
  }
}
