import ArborCore
import ArborKit
import ArborTesting
import CoreGraphics
import Testing

@Suite @MainActor struct DisplayChangeTests {
  let main = FakeWindowSystem.standardDisplay
  let side = DisplaySnapshot(
    id: DisplayID("side"), frame: CGRect(x: 1440, y: 0, width: 1280, height: 800),
    visibleFrame: CGRect(x: 1440, y: 0, width: 1280, height: 800), isMain: false)

  /// macOS posts the notification at every minimize, usually about nothing.
  @Test func nothingChangedNothingToReport() {
    #expect(DisplayChange.settleTime(from: [main, side], to: [main, side]) == nil)
    #expect(DisplayChange.settleTime(from: [main, side], to: [side, main]) == nil, "the order says nothing")
    #expect(DisplayChange.settleTime(from: [], to: []) == nil)
  }

  @Test func theDockGrowingIsReportedSoon() {
    var taller = main
    taller.visibleFrame.size.height -= 2
    #expect(DisplayChange.settleTime(from: [main], to: [taller]) == DisplayChange.visibleFrameOnly)
  }

  @Test func aDisplayComingOrGoingIsGivenTimeToChangeItsMind() {
    #expect(DisplayChange.settleTime(from: [main, side], to: [main]) == DisplayChange.comingAndGoing)
    #expect(DisplayChange.settleTime(from: [main], to: [main, side]) == DisplayChange.comingAndGoing)
    #expect(DisplayChange.settleTime(from: [main], to: []) == DisplayChange.comingAndGoing)
  }

  @Test func soIsAnotherResolutionOrAnotherPrimaryDisplay() {
    var larger = main
    larger.frame.size = CGSize(width: 1920, height: 1200)
    #expect(DisplayChange.settleTime(from: [main], to: [larger]) == DisplayChange.comingAndGoing)
    var first = main
    var second = side
    first.isMain = false
    second.isMain = true
    #expect(DisplayChange.settleTime(from: [main, side], to: [first, second]) == DisplayChange.comingAndGoing)
  }
}
