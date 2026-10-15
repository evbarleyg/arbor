import ArborCore
import CoreGraphics
import Testing

/// The numbers are a hosted Mac's: 1024×768, the visible frame 0,31 1024×674, so the Dock begins at 705.
@Suite struct ScreenLinesTests {
  static let frame = CGRect(x: 0, y: 0, width: 1024, height: 768)
  let aboveADock = ScreenLines(frame: Self.frame, visibleFrame: CGRect(x: 0, y: 31, width: 1024, height: 674))
  let noDockBelow = ScreenLines(frame: Self.frame, visibleFrame: CGRect(x: 0, y: 31, width: 1024, height: 737))

  private func rect(_ x: CGFloat, _ y: CGFloat, _ width: CGFloat, _ height: CGFloat) -> CGRect { CGRect(x: x, y: y, width: width, height: height) }
  private func size(_ width: CGFloat, _ height: CGFloat) -> CGSize { CGSize(width: width, height: height) }

  @Test func growthStopsAPointAboveTheDockAndAtTheRightEdge() {
    #expect(aboveADock.allows(size(494, 650), to: rect(170, 220, 480, 348)) == size(494, 484))
    #expect(aboveADock.allows(size(494, 300), to: rect(687, 106, 325, 300)) == size(337, 300))
    #expect(aboveADock.allows(size(400, 674), to: rect(12, 31, 400, 300)) == size(400, 673), "a frame that ends on the line is a point short")
    #expect(aboveADock.allows(size(400, 673), to: rect(12, 31, 400, 300)) == size(400, 673))
  }

  @Test func withoutADockBelowItGoesAllTheWayToTheBottomOfTheDisplay() {
    #expect(noDockBelow.allows(size(400, 900), to: rect(12, 31, 400, 300)) == size(400, 737))
  }

  /// The rule turned on its side: 309 wide at 494, asked to be 480, which ends on the visible frame's right edge, 974, it became 479.
  @Test func withTheDockAtTheRightGrowthStopsAPointShortOfIt() {
    let dockAtTheRight = ScreenLines(frame: Self.frame, visibleFrame: CGRect(x: 0, y: 31, width: 974, height: 737))
    #expect(dockAtTheRight.allows(size(480, 348), to: rect(494, 226, 309, 348)) == size(479, 348))
    #expect(dockAtTheRight.allows(size(479, 348), to: rect(494, 226, 309, 348)) == size(479, 348))
    #expect(dockAtTheRight.allows(size(900, 348), to: rect(725, 226, 300, 348)).width == 900, "off the display")
  }

  @Test func nobodyIsMadeSmaller() {
    #expect(aboveADock.allows(size(273, 650), to: rect(12, 356, 494, 348)) == size(273, 348))
    #expect(aboveADock.allows(size(200, 100), to: rect(12, 356, 494, 348)) == size(200, 100))
  }

  @Test func anEdgeIsFreeOnlyOffTheDisplayAndEachIsJudgedByItself() {
    for foot in [704, 705, 706, 741, 768] as [CGFloat] {
      #expect(aboveADock.allows(size(400, 600), to: rect(100, foot - 300, 400, 300)).height == 300, "held as it is with its foot at \(foot)")
    }
    #expect(aboveADock.allows(size(400, 900), to: rect(100, 469, 400, 300)).height == 900, "off the display")
    #expect(aboveADock.allows(size(900, 300), to: rect(624, 100, 400, 300)).width == 400, "its right edge on the display's")
    #expect(aboveADock.allows(size(900, 650), to: rect(625, 100, 400, 300)) == size(900, 604), "a point over it: the width is free, the height is not")
    #expect(aboveADock.allows(size(1000, 650), to: rect(1023, 677, 480, 348)) == size(1000, 650), "where Arbor parks windows")
  }

  @Test func oneRequestIsPlayedCallByCall() {
    func after(_ target: CGRect, from standing: CGRect) -> CGSize {
      ScreenLines.sizeAfterOneRequest(
        for: target, from: standing, rooms: [FramePlan.room(onDisplay: Self.frame, visible: CGRect(x: 0, y: 31, width: 1024, height: 674))]
      ) { _ in aboveADock }
    }
    #expect(after(rect(12, 43, 494, 650), from: rect(170, 220, 480, 348)) == size(494, 650), "it grows where it ends up")
    #expect(after(rect(560, 380, 400, 600), from: rect(12, 43, 494, 650)) == size(400, 600), "sized where it stood, where there was room")
    #expect(after(rect(560, 386, 400, 600), from: rect(12, 374, 494, 319)) == size(400, 330), "room at neither end")
    #expect(after(rect(700, 60, 600, 300), from: rect(687, 43, 325, 650)) == size(600, 300), "as wide as the first call made it, it is off the display at its goal")
    #expect(after(rect(500, 60, 600, 300), from: rect(687, 43, 325, 650)) == size(524, 300))
  }
}
