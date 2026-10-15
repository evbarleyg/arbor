import ArborCore
@testable import ArborKit
import ArborTesting
import CoreGraphics
import Testing

/// What Arbor remembers of a floating window is what the window has when it has come to rest (board 1.68).
///
/// macOS eases its windows into a tile and out of one, and its last steps are a point apart. While each report was held against the one before, and sizes a
/// point apart at most passed for a move, the books stopped at the first such step, a few points from where the window came to rest. At the next
/// pause, Quit or Float All Arbor then set a window that nobody had touched to a size it no longer had. Seen on hosted Macs: 481×352 for 481×349,
/// 514 for 513, 723 for 721. Steps of a point add up.
///
/// As Arbor ships that is over, by two changes that were about something else: a floating window's frame is its person's, so a report is taken at its
/// word (Controller+OwnFrames.swift), and half a second after a window is left to macOS Arbor writes down where the window server has it
/// (Controller+LeftToMacOS.swift). These tests hold it, with the steps as they were recorded. Where floating windows make way
/// (`floatingWindowsMakeWay`) 1.68 is still open.
///
/// The arrangement is [a | Desktop | b] with c floating, 400×300.
@Suite @MainActor struct AtRestTests {
  /// Reports `sizes` for `window`, one after the other, 16 ms apart, its corner staying where it is, as its app does while macOS sizes it.
  func report(_ sizes: [(CGFloat, CGFloat)], of window: WindowID, _ s: DragScene) {
    for (width, height) in sizes {
      s.h.system.userMove(window, to: CGRect(origin: s.frame(window).origin, size: CGSize(width: width, height: height)))
      s.h.scheduler.advance(by: 0.016)
    }
  }

  func expectTheBooksSayWhatIsOnTheScreen(_ window: WindowID, _ s: DragScene, sourceLocation: SourceLocation = #_sourceLocation) {
    #expect(
      s.h.workspace.floating[window] == s.frame(window), "remembered: \(String(describing: s.h.workspace.floating[window])), is: \(s.frame(window))",
      sourceLocation: sourceLocation)
  }

  /// No way out sets a frame on a window that nobody has touched since it came to rest.
  func expectNoWayOutTouches(_ window: WindowID, _ s: DragScene, _ wayOut: String, sourceLocation: SourceLocation = #_sourceLocation) {
    let rest = s.frame(window)
    s.h.system.clearFrameLog()
    s.h.run(wayOut)
    if wayOut == "quit" { s.h.controller.shutdown() }
    s.h.scheduler.advance(by: 3)
    #expect(!s.h.system.frameLog.contains { $0.window == window }, "\(wayOut): \(s.h.system.frameLog)", sourceLocation: sourceLocation)
    #expect(s.frame(window) == rest, sourceLocation: sourceLocation)
  }

  nonisolated static let waysOut = ["float-all", "pause", "quit"]

  /// As recorded on a hosted Mac, macOS 26.6: a window dragged off its tile shrinks in the hand. The last reports: 356, 354, 352, 351, 350, 349 high.
  /// Board 1.68.
  @Test(arguments: waysOut) func shrunkInTheHandOffItsTileTheLastStepsCountToo(wayOut: String) {
    let s = DragScene()
    s.h.system.drag(s.c, through: [s.frame(s.c).center, CGPoint(x: 0, y: 450)])
    s.h.scheduler.advance(by: 3)
    // Played by hand: the fake gives the size back in one step.
    _ = s.h.system.takeSizeBeforeTile(of: s.c)
    s.h.system.beginDrag(s.c)
    report(
      [(640, 700), (560, 520), (500, 420), (486, 385), (483, 372), (482, 365), (482, 360), (481, 356), (481, 354), (481, 352), (481, 351), (481, 350), (481, 349)],
      of: s.c, s)
    s.h.system.moveDrag(to: CGPoint(x: 700, y: 400), holding: 0.3)
    s.h.system.endDrag()
    s.h.scheduler.advance(by: 3)
    #expect(s.frame(s.c).size == CGSize(width: 481, height: 349))
    expectTheBooksSayWhatIsOnTheScreen(s.c, s)
    expectNoWayOutTouches(s.c, s, wayOut)
  }

  /// Arbor can hear of the drag after macOS has begun: the first steps come as reports about a window in nobody's hand.
  /// Board 1.68.
  @Test func heardOfTheDragInTheMiddleOfTheShrinking() {
    let s = DragScene()
    s.h.system.drag(s.c, through: [s.frame(s.c).center, CGPoint(x: 0, y: 450)])
    s.h.scheduler.advance(by: 3)
    _ = s.h.system.takeSizeBeforeTile(of: s.c)
    report([(640, 700), (500, 420), (483, 372), (482, 360), (481, 354), (481, 352), (481, 351)], of: s.c, s)
    s.h.system.beginDrag(s.c)
    report([(481, 350), (481, 349)], of: s.c, s)
    s.h.system.moveDrag(to: CGPoint(x: 700, y: 400), holding: 0.3)
    s.h.system.endDrag()
    s.h.scheduler.advance(by: 3)
    expectTheBooksSayWhatIsOnTheScreen(s.c, s)
  }

  /// As recorded: a window of 554×650 let go at the left edge travels into 513×674. The widths at the end: 519 517 516 515 514 514 513 513.
  /// Board 1.68.
  @Test(arguments: waysOut) func easedIntoItsTileTheLastStepsCountToo(wayOut: String) {
    let s = DragScene()
    s.h.system.userMove(s.c, to: CGRect(x: 300, y: 100, width: 554, height: 650))
    s.h.scheduler.advance(by: 3)
    s.h.system.beginDrag(s.c)
    s.h.system.moveDrag(to: CGPoint(x: 0, y: 450), holding: 1)
    // Played by hand.
    s.h.system.macOSOverlooksTheNextDrop = true
    s.h.system.endDrag()
    s.h.scheduler.advance(by: 0.02)
    report([(548, 655), (536, 664), (527, 670), (522, 673), (519, 674), (517, 674), (516, 674), (515, 674), (514, 674), (514, 674), (513, 674), (513, 674)], of: s.c, s)
    s.h.scheduler.advance(by: 3)
    #expect(s.frame(s.c).size == CGSize(width: 513, height: 674))
    expectTheBooksSayWhatIsOnTheScreen(s.c, s)
    expectNoWayOutTouches(s.c, s, wayOut)
  }

  /// A release that Arbor never saw: macOS's steps arrive while Arbor still takes the window to be in the hand, and go by the rule for a drag.
  /// Board 1.68.
  @Test(arguments: waysOut) func withTheReleaseLostTheStepsComeDuringTheDragAndCountToo(wayOut: String) {
    let s = DragScene()
    s.h.system.userMove(s.c, to: CGRect(x: 200, y: 25, width: 1000, height: 875))
    s.h.scheduler.advance(by: 3)
    s.h.system.beginDrag(s.c)
    s.h.system.moveDrag(to: CGPoint(x: 400, y: 300), holding: 0.3)
    s.h.system.moveDrag(to: CGPoint(x: 0, y: 450), holding: 1)
    s.h.system.loseTheReleaseOfTheDrag()
    // Before anything looks again: what the drop itself writes down.
    #expect(s.frame(s.c).width == 721)
    expectTheBooksSayWhatIsOnTheScreen(s.c, s)
    s.h.scheduler.advance(by: 3)
    expectTheBooksSayWhatIsOnTheScreen(s.c, s)
    expectNoWayOutTouches(s.c, s, wayOut)
  }

  /// A height that stays while the width shrinks: nothing broke the chain, and 723 was remembered for 721.
  /// Board 1.68.
  @Test func asHighAsTheDisplayAndShrunkIntoAHalf() {
    let s = DragScene()
    s.h.system.userMove(s.c, to: CGRect(x: 200, y: 25, width: 1000, height: 875))
    s.h.scheduler.advance(by: 3)
    report([(900, 875), (800, 875), (750, 875), (733, 875), (727, 875), (725, 875), (723, 875), (722, 875), (721, 875)], of: s.c, s)
    s.h.scheduler.advance(by: 3)
    expectTheBooksSayWhatIsOnTheScreen(s.c, s)
    expectNoWayOutTouches(s.c, s, "float-all")
  }

  /// A hand that makes a window smaller a point at a time, with rests between: every point counts.
  /// Board 1.68.
  @Test func madeSmallerByHandAPointAtATime() {
    let s = DragScene()
    for width in stride(from: CGFloat(399), through: 390, by: -1) {
      s.h.system.userResize(s.c, to: CGRect(origin: s.frame(s.c).origin, size: CGSize(width: width, height: 300)))
      s.h.scheduler.advance(by: 1)
    }
    #expect(s.frame(s.c).width == 390)
    expectTheBooksSayWhatIsOnTheScreen(s.c, s)
  }
}
