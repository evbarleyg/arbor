import ArborCore
import CoreGraphics
import Testing

/// When macOS shows its desktop, told from where Accessibility and the window server have the windows.
@Suite struct SweptAsideJudgementTests {
  let display = CGRect(x: 0, y: 0, width: 1600, height: 900)

  /// Nine windows of real apps on a hosted Mac (macOS 26, 1600 × 900, two of them docked), before a click on the wallpaper
  /// and 0.2 s after it, as the window server listed them. Accessibility reported nothing.
  static let recorded: [(before: CGRect, after: CGRect)] = [
    (CGRect(x: 12, y: 43, width: 517, height: 767), CGRect(x: -505, y: 6, width: 517, height: 767)),
    (CGRect(x: 1014, y: 43, width: 574, height: 767), CGRect(x: 1588, y: -1, width: 574, height: 767)),
    (CGRect(x: 541, y: 51, width: 457, height: 499), CGRect(x: 447, y: -457, width: 457, height: 499)),
    (CGRect(x: 417, y: 105, width: 709, height: 660), CGRect(x: -269, y: -618, width: 709, height: 660)),
    (CGRect(x: 431, y: 86, width: 680, height: 598), CGRect(x: 199, y: -556, width: 680, height: 598)),
    (CGRect(x: 410, y: 85, width: 723, height: 625), CGRect(x: 128, y: -583, width: 723, height: 625)),
    (CGRect(x: 417, y: 35, width: 708, height: 424), CGRect(x: 362, y: -382, width: 708, height: 424)),
    (CGRect(x: 336, y: 72, width: 871, height: 630), CGRect(x: 95, y: -588, width: 871, height: 630)),
    (CGRect(x: 541, y: 65, width: 461, height: 439), CGRect(x: 469, y: -397, width: 461, height: 439)),
  ]

  func believed(_ frames: [CGRect]) -> [WindowID: CGRect] {
    Dictionary(uniqueKeysWithValues: frames.enumerated().map { (WindowID(UInt32(101 + $0.offset)), $0.element) })
  }

  func listed(_ frames: [CGRect]) -> [StackedWindow] {
    frames.enumerated().map { StackedWindow(id: WindowID(UInt32(101 + $0.offset)), frame: $0.element) }
  }

  func isSwept(_ believedFrames: [CGRect], _ listedFrames: [CGRect], displays: [CGRect]? = nil) -> Bool {
    SweptAside.isSwept(believed: believed(believedFrames), listed: listed(listedFrames), displays: displays ?? [display])
  }

  @Test func theSweepAMacRecordedIsOne() {
    #expect(isSwept(Self.recorded.map(\.before), Self.recorded.map(\.after)))
  }

  @Test func atRestNothingIsSwept() {
    #expect(!isSwept(Self.recorded.map(\.before), Self.recorded.map(\.before)))
  }

  @Test func withNoWindowInViewThereIsNothingToTellBy() {
    #expect(!isSwept([], []))
    // Both are where Arbor keeps what is out of view, and the window server agrees.
    let corner = CGRect(x: 1599, y: 859, width: 600, height: 400)
    #expect(!isSwept([corner, corner], [corner, corner]))
  }

  @Test func whatArborKeepsOutOfViewDoesNotSpeakAgainstASweep() {
    // One window framed, two in the corner. macOS sweeps the one, and takes the others wherever.
    let corner = CGRect(x: 1599, y: 859, width: 600, height: 400)
    let framed = CGRect(x: 12, y: 43, width: 1576, height: 767)
    #expect(isSwept([framed, corner, corner], [framed.offsetBy(dx: 0, dy: -768), corner, corner.offsetBy(dx: 0, dy: 40)]))
  }

  @Test func oneWindowThatLeftTheViewAmongOthersThatStayedIsNoSweep() {
    // A hand that is quicker than Accessibility's report, an app that moves its window and says nothing.
    var now = Self.recorded.map(\.before)
    now[2] = now[2].offsetBy(dx: 1500, dy: 0)
    #expect(!isSwept(Self.recorded.map(\.before), now))
  }

  @Test func windowsThatMoveWithinTheViewAreNoSweep() {
    // Every window on its way to a new slot, in apps that take their time.
    #expect(!isSwept(Self.recorded.map(\.before), Self.recorded.map { $0.before.offsetBy(dx: 120, dy: 60) }))
  }

  @Test func whatIsLaidOutMeanwhileDoesNotEndTheSweep() {
    // The list stays as it was, sizes too, whatever becomes of the windows.
    let since = Self.recorded.map { $0.before.insetBy(dx: 40, dy: 30).offsetBy(dx: 25, dy: 0) }
    #expect(isSwept(since, Self.recorded.map(\.after)))
  }

  @Test func aWindowThatOpenedSinceDoesNotEndTheSweep() {
    let new = CGRect(x: 500, y: 300, width: 400, height: 300)
    #expect(isSwept(Self.recorded.map(\.before) + [new], Self.recorded.map(\.after) + [new]))
  }

  @Test func whatOnlyOneOfTheTwoListsIsNotJudged() {
    // On another Space, minimized a moment ago, a panel Arbor does not arrange.
    let frames = Self.recorded.map(\.before)
    let some = listed(Self.recorded.map(\.after)).prefix(2) + [StackedWindow(id: WindowID(900), frame: frames[3])]
    #expect(SweptAside.isSwept(believed: believed(frames), listed: Array(some), displays: [display]))
  }

  @Test func aWindowSweptTowardsANeighbouringDisplayHasStillLeftItsOwn() {
    let right = CGRect(x: 1600, y: 0, width: 1600, height: 900)
    #expect(isSwept(Self.recorded.map(\.before), Self.recorded.map(\.after), displays: [display, right]))
  }
}
