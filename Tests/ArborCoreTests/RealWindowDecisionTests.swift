import ArborCore
import CoreGraphics
import Foundation
import Testing

/// The decisions behind the Accessibility layer (F17 and the review of 2026-10-14). The code that talks to
/// macOS cannot run in tests, so what it decides is decided here.
/// `#expect` cannot call a mutating method, so the tests keep these value types in a box.
final class Box<Value> {
  var value: Value
  init(_ value: Value) { self.value = value }
}

extension Box where Value == EnforcementLimiter {
  func allowsPuttingBack(_ window: WindowID, at time: TimeInterval) -> Bool { value.allowsPuttingBack(window, at: time) }
  func reset(_ windows: [WindowID]) { value.reset(windows) }
  var givenUp: Set<WindowID> { value.givenUp }
}

extension Box where Value == EchoFilter {
  func expect(_ frame: CGRect, for window: WindowID, at time: TimeInterval) { value.expect(frame, for: window, at: time) }
  func isEcho(_ frame: CGRect, of window: WindowID, at time: TimeInterval) -> Bool { value.isEcho(frame, of: window, at: time) }
  func judge(_ frame: CGRect, of window: WindowID, at time: TimeInterval) -> EchoFilter.Verdict {
    value.judge(frame, of: window, at: time)
  }
  func forget(_ window: WindowID) { value.forget(window) }
  var count: Int { value.count }
}

@Suite struct EnforcementLimiterTests {
  let w = WindowID(7)

  @Test func theFourthPutBackWithinThreeSecondsIsRefused() {
    let limiter = Box(EnforcementLimiter())
    #expect(limiter.allowsPuttingBack(w, at: 10.0))
    #expect(limiter.allowsPuttingBack(w, at: 10.5))
    #expect(limiter.allowsPuttingBack(w, at: 11.0))
    #expect(!limiter.allowsPuttingBack(w, at: 11.5))
    #expect(limiter.givenUp == [w])
    #expect(!limiter.allowsPuttingBack(w, at: 100), "giving up lasts until the layout changes")
  }

  @Test func putBacksSpreadOverTimeAreAllAllowed() {
    let limiter = Box(EnforcementLimiter())
    for step in 0..<20 { #expect(limiter.allowsPuttingBack(w, at: Double(step) * 1.6)) }
    #expect(limiter.givenUp.isEmpty)
  }

  @Test func eachWindowIsCountedOnItsOwn() {
    let limiter = Box(EnforcementLimiter())
    let other = WindowID(8)
    for _ in 0..<3 { #expect(limiter.allowsPuttingBack(w, at: 1)) }
    #expect(!limiter.allowsPuttingBack(w, at: 1))
    #expect(limiter.allowsPuttingBack(other, at: 1))
  }

  @Test func aResetGivesAFreshStart() {
    let limiter = Box(EnforcementLimiter())
    for _ in 0..<4 { _ = limiter.allowsPuttingBack(w, at: 1) }
    limiter.reset([w])
    #expect(limiter.givenUp.isEmpty)
    #expect(limiter.allowsPuttingBack(w, at: 1.1))
  }

  @Test func aClockThatJumpsBackDoesNotCountOldPutBacksForEver() {
    let limiter = Box(EnforcementLimiter())
    for _ in 0..<3 { _ = limiter.allowsPuttingBack(w, at: 1000) }
    #expect(limiter.allowsPuttingBack(w, at: 5))
  }
}

@Suite struct WindowGrabTests {
  let frame = CGRect(x: 100, y: 100, width: 600, height: 400)
  var titleBar: CGPoint { CGPoint(x: 400, y: 114) }

  func verdict(pressedAt: CGPoint, now: CGRect, pointer: CGPoint? = nil) -> WindowGrab.Verdict {
    WindowGrab.classify(pressedAt: pressedAt, frameAtPress: frame, frameNow: now, pointerNow: pointer ?? pressedAt)
  }

  @Test func aWindowThatFollowsThePointerIsBeingDragged() {
    #expect(verdict(pressedAt: titleBar, now: frame.offsetBy(dx: -8, dy: 6)) == .drag)
    #expect(verdict(pressedAt: titleBar, now: frame.offsetBy(dx: 0, dy: 1)) == .drag)
  }

  @Test func nothingIsDecidedWhileTheWindowStandsStillAndThePointerIsNear() {
    #expect(verdict(pressedAt: titleBar, now: frame) == .undecided)
    #expect(verdict(pressedAt: titleBar, now: frame, pointer: CGPoint(x: 410, y: 120)) == .undecided)
    #expect(verdict(pressedAt: titleBar, now: frame.offsetBy(dx: 0.4, dy: 0)) == .undecided, "less than a point is noise")
  }

  @Test func aPointerThatTravelsWhileTheWindowStandsStillIsNotAboutTheWindow() {
    let inside = CGPoint(x: 300, y: 300)
    #expect(verdict(pressedAt: inside, now: frame, pointer: CGPoint(x: 330, y: 300)) == .neither)
  }

  @Test func aSizeChangeAfterAPressOnTheBorderIsAnEdgeResize() {
    let wider = CGRect(x: 100, y: 100, width: 660, height: 400)
    #expect(verdict(pressedAt: CGPoint(x: 699, y: 300), now: wider) == .resize)
    #expect(verdict(pressedAt: CGPoint(x: 704, y: 300), now: wider) == .resize, "the resize area reaches outside the window")
    // The left and top edges move the origin too.
    #expect(verdict(pressedAt: CGPoint(x: 101, y: 300), now: CGRect(x: 60, y: 100, width: 640, height: 400)) == .resize)
    #expect(verdict(pressedAt: CGPoint(x: 103, y: 497), now: CGRect(x: 60, y: 100, width: 640, height: 440)) == .resize)
  }

  /// H5: macOS zooms a window whose title bar is double-clicked. That must never move a seam.
  @Test func aSizeChangeAfterAPressInTheTitleBarIsNotAnEdgeResize() {
    let zoomed = CGRect(x: 0, y: 25, width: 1440, height: 875)
    #expect(verdict(pressedAt: titleBar, now: zoomed) != .resize)
    #expect(verdict(pressedAt: titleBar, now: CGRect(x: 100, y: 100, width: 700, height: 400)) == .neither)
  }

  /// A window macOS had tiled or zoomed gets its old size back as soon as it is dragged away.
  @Test func aWindowThatChangesSizeWhileItIsDraggedByItsTitleBarIsStillDragged() {
    #expect(verdict(pressedAt: titleBar, now: CGRect(x: 250, y: 130, width: 300, height: 200)) == .drag)
  }

  @Test func nearTheEdgeMeansWithinTenPointsOfTheBorderOnEitherSide() {
    #expect(WindowGrab.isNearEdge(CGPoint(x: 100, y: 300), of: frame))
    #expect(WindowGrab.isNearEdge(CGPoint(x: 109, y: 300), of: frame))
    #expect(WindowGrab.isNearEdge(CGPoint(x: 91, y: 300), of: frame))
    #expect(!WindowGrab.isNearEdge(CGPoint(x: 111, y: 300), of: frame))
    #expect(!WindowGrab.isNearEdge(CGPoint(x: 89, y: 300), of: frame))
    #expect(WindowGrab.isNearEdge(CGPoint(x: 400, y: 495), of: frame))
    #expect(WindowGrab.isNearEdge(CGPoint(x: 400, y: 104), of: frame), "the top few points of the title bar resize")
    #expect(!WindowGrab.isNearEdge(titleBar, of: frame), "the middle of the title bar does not")
    #expect(!WindowGrab.isNearEdge(CGPoint(x: 400, y: 300), of: frame))
  }

  @Test func everyPointOfATinyWindowIsNearItsEdge() {
    let tiny = CGRect(x: 0, y: 0, width: 12, height: 12)
    #expect(WindowGrab.isNearEdge(CGPoint(x: 6, y: 6), of: tiny))
  }
}

@Suite struct EchoFilterTests {
  let w = WindowID(7)
  let set = CGRect(x: 12, y: 37, width: 700, height: 851)

  @Test func anythingRightAfterAMoveIsAnEcho() {
    let filter = Box(EchoFilter())
    filter.expect(set, for: w, at: 100)
    #expect(filter.isEcho(CGRect(x: 12, y: 37, width: 640, height: 420), of: w, at: 100.1), "position set, size not yet")
  }

  @Test func theExpectedFrameIsAnEchoForASecond() {
    let filter = Box(EchoFilter())
    filter.expect(set, for: w, at: 100)
    #expect(filter.isEcho(set.offsetBy(dx: 1, dy: -2), of: w, at: 100.9))
    #expect(!filter.isEcho(set, of: w, at: 101.1))
  }

  @Test func anotherFrameAfterTheFirstMomentIsSomeoneElsesMove() {
    let filter = Box(EchoFilter())
    filter.expect(set, for: w, at: 100)
    #expect(!filter.isEcho(set.offsetBy(dx: 30, dy: 0), of: w, at: 100.2))
  }

  @Test func windowsNobodyMovedHaveNoEchoes() {
    let filter = Box(EchoFilter())
    filter.expect(set, for: w, at: 100)
    #expect(!filter.isEcho(set, of: WindowID(8), at: 100.01))
  }

  @Test func aClockBehindTheExpectationDoesNotKeepItFresh() {
    let filter = Box(EchoFilter())
    filter.expect(set, for: w, at: 4000)
    #expect(!filter.isEcho(set.offsetBy(dx: 50, dy: 0), of: w, at: 400))
    #expect(filter.count == 0)
  }

  /// Seen in real traces: a window resized itself 0.1 s after being docked, and stayed out of its slot for good.
  @Test func anotherFrameInTheFirstMomentIsLookedAtAgain() {
    let filter = Box(EchoFilter())
    filter.expect(set, for: w, at: 100)
    let own = CGRect(x: 12, y: 37, width: 640, height: 851)
    #expect(filter.judge(own, of: w, at: 100.1) == .early)
    #expect(filter.judge(set, of: w, at: 100.1) == .echo)
    #expect(filter.judge(own, of: w, at: 100.2) == .other)
    #expect(filter.value.hasStrayed(w, now: own), "still there when the dust has settled: the app's own doing")
    #expect(!filter.value.hasStrayed(w, now: set.offsetBy(dx: 1, dy: 1)), "a stage of Arbor's move: it arrived")
    #expect(!filter.value.hasStrayed(WindowID(8), now: own), "nothing is expected of a window nobody moved")
  }

  @Test func aNewerMoveIsWhatCounts() {
    let filter = Box(EchoFilter())
    filter.expect(set, for: w, at: 100)
    let next = set.offsetBy(dx: 300, dy: 0)
    filter.expect(next, for: w, at: 100.2)
    #expect(!filter.value.hasStrayed(w, now: next))
    #expect(filter.value.hasStrayed(w, now: set))
  }

  @Test func expectationsDoNotPileUp() {
    let filter = Box(EchoFilter())
    filter.expect(set, for: w, at: 100)
    filter.expect(set, for: WindowID(8), at: 100)
    _ = filter.isEcho(set, of: w, at: 200)
    filter.forget(WindowID(8))
    #expect(filter.count == 0)
  }
}

@Suite struct FramePlanTests {
  let known = CGRect(x: 12, y: 37, width: 700, height: 851)

  @Test func aWindowThatOnlyChangesPlaceNeedsOneCall() {
    let parked = CGRect(x: 1439, y: 899, width: 700, height: 851)
    #expect(FramePlan.steps(from: known, to: parked) == [.position])
  }

  @Test func aChangeOfSizeTakesTheFullPlan() {
    #expect(FramePlan.steps(from: known, to: CGRect(x: 12, y: 37, width: 701, height: 851)) == FramePlan.full)
    #expect(FramePlan.steps(from: nil, to: known) == FramePlan.full)
  }

  @Test func evenAWindowBelievedToBeInPlaceIsMoved() {
    #expect(FramePlan.steps(from: known, to: known) == [.position], "the belief may be out of date")
  }

  @Test func aWrongBeliefAboutTheSizeIsCaughtByReadingBack() {
    let target = CGRect(x: 1439, y: 899, width: 700, height: 851)
    let surprise = CGRect(x: 1439, y: 899, width: 500, height: 851)
    #expect(FramePlan.needsFullPlan(after: [.position], result: surprise, target: target))
    #expect(!FramePlan.needsFullPlan(after: [.position], result: target, target: target))
    // macOS keeps title bars on screen, so a parked window ends up higher than asked. That is not a reason.
    #expect(!FramePlan.needsFullPlan(after: [.position], result: target.offsetBy(dx: 0, dy: -94), target: target))
    #expect(!FramePlan.needsFullPlan(after: FramePlan.full, result: surprise, target: target), "the app refused; once is enough")
  }
}

@Suite struct WindowKindTests {
  func kind(_ role: String?, _ subrole: String?, minimized: Bool = false, hidden: Bool = false) -> WindowKind {
    WindowKind.classify(role: role, subrole: subrole, isMinimized: minimized, appIsHidden: hidden)
  }

  @Test func standardWindowsAreWindows() {
    #expect(kind("AXWindow", "AXStandardWindow") == .window)
    #expect(kind("AXWindow", "AXStandardWindow", minimized: true, hidden: true) == .window)
  }

  @Test func everythingElseInViewIsNot() {
    for subrole in ["AXDialog", "AXSystemDialog", "AXFloatingWindow", "AXSystemFloatingWindow", "AXUnknown", "Quick Look", nil] {
      #expect(kind("AXWindow", subrole) == .other)
    }
    #expect(kind("AXSheet", nil) == .other)
    #expect(kind("AXPopover", "AXStandardWindow") == .other)
    #expect(kind(nil, nil) == .other, "an app that does not answer")
  }

  /// Seen on macOS 26: minimized windows and the windows of hidden apps all say they are dialogs.
  @Test func aDialogOutOfSightMayBeAWindow() {
    #expect(kind("AXWindow", "AXDialog", minimized: true) == .unconfirmed)
    #expect(kind("AXWindow", "AXDialog", hidden: true) == .unconfirmed)
    #expect(kind("AXWindow", "AXFloatingWindow", hidden: true) == .other)
  }
}

@Suite struct NativeTabsTests {
  let frame = CGRect(x: 76, y: 160, width: 360, height: 272)

  func candidate(_ id: UInt32, _ frame: CGRect, tab: Bool = false) -> NativeTabs.Candidate {
    NativeTabs.Candidate(id: WindowID(id), frame: frame, wasBackgroundTab: tab)
  }

  @Test func aNewWindowInExactlyTheSamePlaceTakesOver() {
    #expect(NativeTabs.successor(toWindowAt: frame, among: [candidate(45, frame)]) == WindowID(45))
    #expect(NativeTabs.successor(toWindowAt: frame, among: [candidate(45, frame.offsetBy(dx: 1, dy: 0))]) == WindowID(45))
  }

  /// Seen in Terminal (collab/evidence/compat-lab/tabs-terminal.log): it keeps its rows, so the window grows by the height
  /// of the tab bar at the first ⌘T (625 × 940, then 625 × 971), and the two tabs go on differing by as much.
  @Test func aTabMayDifferInHeightByATabBar() {
    let left = CGRect(x: 12, y: 43, width: 625, height: 940)
    #expect(NativeTabs.successor(toWindowAt: left, among: [candidate(392, CGRect(x: 12, y: 43, width: 625, height: 971))]) == WindowID(392))
    #expect(NativeTabs.successor(toWindowAt: left, among: [candidate(392, CGRect(x: 12, y: 43, width: 625, height: 904))]) == WindowID(392))
    #expect(NativeTabs.successor(toWindowAt: left, among: [candidate(392, CGRect(x: 12, y: 43, width: 625, height: 990))]) == nil)
    #expect(NativeTabs.successor(toWindowAt: left, among: [candidate(392, CGRect(x: 12, y: 74, width: 625, height: 909))]) == nil, "the top edge stays")
  }

  @Test func theOneThatFitsBestTakesOver() {
    let exact = candidate(50, frame)
    let taller = candidate(40, CGRect(x: frame.minX, y: frame.minY, width: frame.width, height: frame.height + 31))
    #expect(NativeTabs.successor(toWindowAt: frame, among: [taller, exact]) == WindowID(50))
  }

  /// New windows open a little down and to the right of the last one.
  @Test func aWindowSomewhereElseDoesNot() {
    let cascaded = frame.offsetBy(dx: 22, dy: 22)
    #expect(NativeTabs.successor(toWindowAt: frame, among: [candidate(45, cascaded, tab: true)]) == nil)
    let larger = CGRect(x: frame.minX, y: frame.minY, width: frame.width + 40, height: frame.height)
    #expect(NativeTabs.successor(toWindowAt: frame, among: [candidate(45, larger)]) == nil)
  }

  @Test func aKnownBackgroundTabIsPreferredToANewcomer() {
    let found = NativeTabs.successor(toWindowAt: frame, among: [candidate(30, frame), candidate(36, frame, tab: true)])
    #expect(found == WindowID(36))
  }

  @Test func nobodyTakesOverWhenNobodyJoined() {
    #expect(NativeTabs.successor(toWindowAt: frame, among: []) == nil)
  }
}

@Suite struct RetryScheduleTests {
  @Test func retriesStartQuicklyAndLastHalfAMinute() {
    let delays = (0..<20).compactMap { RetrySchedule.delay(beforeRetry: $0) }
    #expect(delays == [0.25, 0.5, 1, 2, 4, 8, 8, 8])
    #expect(delays.reduce(0, +) > 30)
    #expect(RetrySchedule.delay(beforeRetry: -1) == nil)
    #expect(RetrySchedule.delay(beforeRetry: Int.max) == nil)
  }
}

@Suite struct AppThatCameForwardTests {
  @Test func anAppThatMacOSNamesIsReportedAtOnce() {
    #expect(AppThatCameForward.verdict(isNamedInFront: true, earlierLooks: 0) == .report)
  }

  /// It used to be dropped, and nothing else tells of ⌘Tab.
  @Test func oneThatMacOSDoesNotNameYetIsLookedAtAgainWithinTheBlinkOfAnEye() {
    #expect(AppThatCameForward.verdict(isNamedInFront: false, earlierLooks: 0) == .lookAgain(after: 0.01))
    #expect(AppThatCameForward.verdict(isNamedInFront: true, earlierLooks: 1) == .report)
  }

  @Test func theLookingEndsAfterHalfASecond() {
    let verdicts = (0..<100).map { AppThatCameForward.verdict(isNamedInFront: false, earlierLooks: $0) }
    let waits = verdicts.compactMap { if case .lookAgain(let seconds) = $0 { seconds } else { nil } }
    #expect(abs(waits.reduce(0, +) - 0.5) < 0.001)
    #expect(verdicts[waits.count...].allSatisfy { $0 == .giveUp })
    #expect(AppThatCameForward.verdict(isNamedInFront: true, earlierLooks: Int.max) == .report, "better late than never")
  }
}

@Suite struct StrayDialogTests {
  let main = StrayDialog.Display(
    frame: CGRect(x: 0, y: 0, width: 1440, height: 900), visibleFrame: CGRect(x: 0, y: 25, width: 1440, height: 805))
  let side = StrayDialog.Display(
    frame: CGRect(x: -1280, y: 0, width: 1280, height: 800), visibleFrame: CGRect(x: -1280, y: 0, width: 1280, height: 800))
  /// Where Arbor keeps a window that is out of view.
  let corner = CGRect(x: 1439, y: 805, width: 700, height: 600)
  let dialog = CGRect(x: 1639, y: 905, width: 300, height: 160)

  @Test func aDialogOverAWindowThatIsOutOfViewComesToTheMiddleOfTheDisplay() {
    let home = StrayDialog.home(for: dialog, siblings: [corner], displays: [main])
    #expect(home == CGPoint(x: 570, y: 348))
  }

  @Test func aDialogThatCanBeSeenIsLeftAlone() {
    let half = CGRect(x: 1280, y: 400, width: 300, height: 160)
    #expect(StrayDialog.home(for: half, siblings: [corner], displays: [main]) == nil)
    #expect(StrayDialog.home(for: CGRect(x: 500, y: 300, width: 300, height: 160), siblings: [corner], displays: [main]) == nil)
  }

  @Test func whatIsTinyIsOffScreenOnPurpose() {
    #expect(StrayDialog.home(for: CGRect(x: 2000, y: 1000, width: 39, height: 200), siblings: [corner], displays: [main]) == nil)
    #expect(StrayDialog.home(for: CGRect(x: 2000, y: 1000, width: 200, height: 1), siblings: [corner], displays: [main]) == nil)
  }

  @Test func anAppWhoseWindowsAreAllInViewIsNotArborsBusiness() {
    let inView = CGRect(x: 100, y: 100, width: 700, height: 600)
    #expect(StrayDialog.home(for: dialog, siblings: [inView], displays: [main]) == nil)
    #expect(StrayDialog.home(for: dialog, siblings: [], displays: [main]) == nil)
  }

  @Test func withoutDisplaysNothingIsMoved() {
    #expect(StrayDialog.home(for: dialog, siblings: [corner], displays: []) == nil)
  }

  @Test func itGoesToTheDisplayItsAppsWindowWaitsAt() {
    // Out of view at the bottom left corner of the display on the left.
    let waiting = CGRect(x: -1979, y: 799, width: 700, height: 600)
    let there = CGRect(x: -1800, y: 900, width: 300, height: 160)
    let home = StrayDialog.home(for: there, siblings: [waiting], displays: [main, side])
    #expect(home == CGPoint(x: -790, y: 320))
  }

  @Test func aDialogLargerThanTheDisplayKeepsItsTitleBarInReach() {
    let huge = CGRect(x: 1639, y: 905, width: 1600, height: 1000)
    #expect(StrayDialog.home(for: huge, siblings: [corner], displays: [main]) == CGPoint(x: 0, y: 25))
  }
}
