import ArborCore
import ArborKit
import ArborTesting
import CoreGraphics
import Foundation
import Testing

/// At a change of displays macOS moves windows and their apps say so. With eleven real apps on a hosted Mac, in 10 of 13 changes exactly
/// one window said so 0.003 to 0.7 s before macOS's own list of displays was new: nothing told that report from an app's or a tool's own
/// move, and it was booked as one. The others spoke under the new list and were turned away.
///
/// Whoever speaks first, the end is the same.
@Suite @MainActor struct SpokeAheadTests {
  static let laptop = FakeWindowSystem.standardDisplay
  static let side = LookBeforeLettingGoTests.side

  enum Change: String, CaseIterable, CustomTestStringConvertible {
    case theSideGoes, theLidShuts, theSideChangesSides, theSideGoesBelow
    var testDescription: String { rawValue }
    var aDisplayGoes: Bool { self == .theSideGoes || self == .theLidShuts }
  }

  /// Where every display stays, a floating window in view is taken from where it is once Arbor is told, and whatever an early report booked is
  /// overtaken. Where one goes that is not enough: the early report has filed the window under a display chosen by the old geometry, so it has left
  /// the arrangement that goes to sleep, or joined it. Strict: whoever cures a case is told so.
  static let notYet: Comment = "board 0.23: who speaks before the list is new is filed by the old geometry, and a display goes"

  /// Three windows that float on each display: 101 to 103 on the laptop, 104 to 106 on the side.
  func make() -> Harness {
    let h = Harness(displays: [Self.laptop, Self.side], settings: Settings())
    for index in 0..<6 {
      h.system.open(
        app: "App\(index)", pid: 1001 + Int32(index),
        frame: CGRect(x: (index < 3 ? 100 : 1600) + 90 * CGFloat(index % 3), y: 100 + 60 * CGFloat(index % 3), width: 480, height: 348))
    }
    h.start()
    h.system.cursor = CGPoint(x: 700, y: 600)
    h.system.userFocus(WindowID(101))
    h.scheduler.advance(by: 5)
    return h
  }

  /// The displays afterwards, and where macOS takes which window.
  func plan(_ change: Change, _ h: Harness) -> (displays: [DisplaySnapshot], moves: [(WindowID, CGRect)]) {
    func shifted(_ display: DisplaySnapshot, to corner: CGPoint, main: Bool? = nil) -> DisplaySnapshot {
      var moved = display
      let (dx, dy) = (corner.x - display.frame.minX, corner.y - display.frame.minY)
      moved.frame = display.frame.offsetBy(dx: dx, dy: dy)
      moved.visibleFrame = display.visibleFrame.offsetBy(dx: dx, dy: dy)
      if let main { moved.isMain = main }
      return moved
    }
    func along(_ windows: ClosedRange<UInt32>, dx: CGFloat, dy: CGFloat = 0) -> [(WindowID, CGRect)] {
      windows.compactMap { number in h.frame(WindowID(number)).map { (WindowID(number), $0.offsetBy(dx: dx, dy: dy)) } }
    }
    switch change {
    case .theSideGoes: return ([Self.laptop], along(104...106, dx: -1440))
    // Every coordinate is another: what is on the side goes with its corner, what was on the laptop is brought over.
    case .theLidShuts: return ([shifted(Self.side, to: .zero, main: true)], along(101...103, dx: 0) + along(104...106, dx: -1440))
    case .theSideChangesSides: return ([Self.laptop, shifted(Self.side, to: CGPoint(x: -1920, y: 0))], along(104...106, dx: -3360))
    case .theSideGoesBelow: return ([Self.laptop, shifted(Self.side, to: CGPoint(x: 0, y: 900))], along(104...106, dx: -1440, dy: 900))
    }
  }

  /// `ahead`: these speak while macOS's list is the old one, `lead` seconds before it is new. The others speak under the new list. Arbor hears
  /// of the displays when they have settled.
  func play(_ change: Change, ahead: Set<WindowID>, lead: TimeInterval = 0.3, on h: Harness) {
    let (displays, moves) = plan(change, h)
    for (window, frame) in moves where ahead.contains(window) { h.system.userMove(window, to: frame) }
    h.scheduler.advance(by: lead)
    h.system.displayList = displays
    for (window, frame) in moves where !ahead.contains(window) { h.system.userMove(window, to: frame) }
    h.scheduler.advance(by: DisplayChange.comingAndGoing)
    h.system.setDisplays(displays)
    h.scheduler.advance(by: 5)
  }

  func expectTheSameEnd(_ one: Harness, _ other: Harness, _ what: String, sourceLocation: SourceLocation = #_sourceLocation) {
    for window in (101...106).map({ WindowID($0) }) {
      #expect(one.frame(window) == other.frame(window), "\(what): \(window)", sourceLocation: sourceLocation)
    }
    #expect(one.controller.workspaces == other.controller.workspaces, "\(what): where windows float", sourceLocation: sourceLocation)
    #expect(one.controller.dormant.mapValues(\.workspace) == other.controller.dormant.mapValues(\.workspace), "\(what): what sleeps", sourceLocation: sourceLocation)
    #expect(one.controller.parked == other.controller.parked, "\(what): who is out of view", sourceLocation: sourceLocation)
  }

  // MARK: Whoever speaks first, the end is the same

  @Test(arguments: Change.allCases, [WindowID(104), WindowID(105), WindowID(106)])
  func oneWindowSpeaksBeforeTheListIsNew(_ change: Change, _ window: WindowID) {
    let (early, late) = (make(), make())
    play(change, ahead: [window], on: early)
    play(change, ahead: [], on: late)
    withKnownIssue(Self.notYet) { expectTheSameEnd(early, late, "\(change), \(window) first") } when: { change.aDisplayGoes }
    expectWindowsMatchLayout(early)
  }

  @Test(arguments: Change.allCases, [0.003, 0.7, 0.99])
  func howeverLongBefore(_ change: Change, _ lead: TimeInterval) {
    let (early, late) = (make(), make())
    play(change, ahead: [WindowID(105)], lead: lead, on: early)
    play(change, ahead: [], lead: lead, on: late)
    withKnownIssue(Self.notYet) { expectTheSameEnd(early, late, "\(change), \(lead) s before") } when: { change.aDisplayGoes }
  }

  @Test(arguments: Change.allCases)
  func allOfThemSpeakBeforeTheListIsNew(_ change: Change) {
    let (early, late) = (make(), make())
    play(change, ahead: Set((101...106).map { WindowID($0) }), on: early)
    play(change, ahead: [], on: late)
    withKnownIssue(Self.notYet) { expectTheSameEnd(early, late, "\(change)") } when: { change.aDisplayGoes }
  }

  /// A display comes, and none goes: the case that was recorded. macOS leaves a window of the laptop astride the border, its centre on the newcomer.
  /// Speaking late it is taken from where it is and belongs to the newcomer. Speaking early it was booked where it is while only the laptop was
  /// there: it lies where the books say, some of it still shows on the laptop, and nothing tells it from a window a hand left hanging over
  /// that edge, which keeps its home. So the two have different homes, and part at the next unplug. Strict: whoever cures it is told so.
  @Test func aDisplayComesAndTheWindowEndsAstrideTheBorder() {
    func play(early: Bool) -> Harness {
      let h = Harness(displays: [Self.laptop], settings: Settings())
      for index in 0..<3 {
        h.system.open(app: "App\(index)", pid: 1001 + Int32(index), frame: CGRect(x: 100 + 90 * CGFloat(index), y: 100 + 60 * CGFloat(index), width: 480, height: 348))
      }
      h.start()
      h.scheduler.advance(by: 5)
      let astride = CGRect(x: 1240, y: 100, width: 480, height: 348)
      if early { h.system.userMove(WindowID(101), to: astride) }
      h.scheduler.advance(by: 0.05)
      h.system.displayList = [Self.laptop, Self.side]
      if !early { h.system.userMove(WindowID(101), to: astride) }
      h.scheduler.advance(by: DisplayChange.comingAndGoing)
      h.system.setDisplays([Self.laptop, Self.side])
      h.scheduler.advance(by: 5)
      #expect(h.frame(WindowID(101)) == astride, "no frame is set either way")
      return h
    }
    let (early, late) = (play(early: true), play(early: false))
    withKnownIssue("board 0.23: who speaks before the list is new lies where the books say, and keeps the home its report gave it") {
      expectTheSameEnd(early, late, "a display comes")
    }
  }

  /// It goes back with its display, like the others.
  @Test(arguments: [WindowID(104), WindowID(105), WindowID(106)])
  func whoSpokeFirstComesBackWithItsDisplay(_ window: WindowID) {
    let h = make()
    let homes = (104...106).map { h.frame(WindowID($0))! }
    play(.theSideGoes, ahead: [window], on: h)
    h.system.plug(Self.side)
    h.scheduler.advance(by: 5)
    withKnownIssue(Self.notYet) {
      #expect((104...106).map { h.frame(WindowID($0))! } == homes)
      #expect(h.controller.workspaces[Self.side.id]?.floating.keys.sorted() == [WindowID(104), WindowID(105), WindowID(106)])
    }
  }

  /// Nobody else speaks and no key is pressed: Arbor finds out by itself, a moment after the report.
  @Test func theOnlyWindowThatMoves() {
    let (early, late) = (make(), make())
    for h in [early, late] {
      for window in [WindowID(105), WindowID(106)] { h.system.close(window) }
      h.scheduler.advance(by: 2)
    }
    play(.theSideGoes, ahead: [WindowID(104)], on: early)
    play(.theSideGoes, ahead: [], on: late)
    withKnownIssue(Self.notYet) {
      #expect(early.frame(WindowID(104)) == late.frame(WindowID(104)))
      #expect(early.controller.workspaces == late.controller.workspaces)
      #expect(early.controller.dormant.mapValues(\.workspace) == late.controller.dormant.mapValues(\.workspace))
    }
  }

  // MARK: A blink

  /// The display is back before Arbor would have heard, so Arbor never does. macOS does not always put back what it took away. What it did to a
  /// floating window is macOS's here too: nobody is put back, each is where macOS left it, and belongs to the display it is on.
  @Test func inABlinkTooTheEndIsTheSame() {
    func blink(oneSpeaksFirst: Bool) -> (Harness, [(WindowID, CGRect)]) {
      let h = make()
      let (displays, moves) = plan(.theSideGoes, h)
      h.system.clearFrameLog()
      if oneSpeaksFirst { h.system.userMove(moves[0].0, to: moves[0].1) }
      h.scheduler.advance(by: 0.3)
      h.system.displayList = displays
      for (window, frame) in moves.dropFirst(oneSpeaksFirst ? 1 : 0) { h.system.userMove(window, to: frame) }
      h.scheduler.advance(by: 0.6)
      h.system.displayList = [Self.laptop, Self.side]
      h.scheduler.advance(by: 10)
      return (h, moves)
    }
    let ((early, moves), (late, _)) = (blink(oneSpeaksFirst: true), blink(oneSpeaksFirst: false))
    expectTheSameEnd(early, late, "a blink")
    for h in [early, late] {
      #expect(h.system.frameLog.isEmpty, "\(h.system.frameLog)")
      for (window, frame) in moves {
        #expect(h.frame(window) == frame)
        #expect(h.controller.workspaces[Self.laptop.id]?.floating[window] == frame)
      }
    }
  }

  // MARK: What stays booked

  /// An app's, a tool's or a keyboard's move, and the displays stay as they are.
  @Test func aMoveWithNoChangeOfDisplaysStays() {
    let h = make()
    let there = CGRect(x: 300, y: 200, width: 480, height: 348)
    h.system.userMove(WindowID(105), to: there)
    h.scheduler.advance(by: 5)
    #expect(h.controller.workspaces[h.display]?.floating[WindowID(105)] == there)
    #expect(h.frame(WindowID(105)) == there)
    // Later changes of displays have nothing to take back.
    play(.theSideGoes, ahead: [], on: h)
    #expect(h.frame(WindowID(105)) == there)
    h.system.plug(Self.side)
    h.scheduler.advance(by: 5)
    #expect(h.frame(WindowID(105)) == there, "it lives on the laptop now")
  }

  /// More than a second before: that was no part of the change.
  @Test func aMoveLongBeforeTheChangeStays() {
    let h = make()
    let there = CGRect(x: 300, y: 200, width: 480, height: 348)
    h.system.userMove(WindowID(105), to: there)
    h.scheduler.advance(by: 1.2)
    play(.theSideGoes, ahead: [], on: h)
    #expect(h.frame(WindowID(105)) == there)
    #expect(h.controller.dormant[Self.side.id]?.workspace.floating[WindowID(105)] == nil)
  }

  /// With the button down it is a hand's.
  @Test func aMoveWithTheButtonDownStays() {
    let h = make()
    let there = CGRect(x: 300, y: 200, width: 480, height: 348)
    h.system.mouseDown = true
    h.system.userMove(WindowID(105), to: there)
    h.system.mouseDown = false
    play(.theSideGoes, ahead: [], lead: 0.1, on: h)
    #expect(h.frame(WindowID(105)) == there)
    #expect(h.controller.dormant[Self.side.id]?.workspace.floating[WindowID(105)] == nil)
  }

  /// Somebody has decided since.
  @Test func dockedMeanwhileItStaysDocked() {
    let h = make()
    let (displays, moves) = plan(.theSideGoes, h)
    h.system.userMove(moves[0].0, to: moves[0].1)
    #expect(h.run("dock 104 left").ok)
    h.scheduler.advance(by: 0.3)
    h.system.displayList = displays
    for (window, frame) in moves.dropFirst() { h.system.userMove(window, to: frame) }
    h.scheduler.advance(by: DisplayChange.comingAndGoing)
    h.system.setDisplays(displays)
    h.scheduler.advance(by: 5)
    #expect(h.controller.workspaces[h.display]?.isDocked(WindowID(104)) == true)
    expectWindowsMatchLayout(h)
  }
}
