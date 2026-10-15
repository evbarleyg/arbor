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

  /// A hosted Mac's answers, call for call as far as a request's end tells: a window whose foot is off the display comes in no further than the
  /// display's bottom if it is asked to end in the Dock's strip; right across the strip it comes as asked; and off the display it is free.
  @Test func noFootIsPutIntoTheDocksStrip() {
    #expect(aboveADock.allows(size(325, 348), to: rect(314, 408, 325, 650)) == size(325, 360), "768 less 408")
    #expect(aboveADock.allows(size(325, 348), to: rect(544, 389, 325, 650)) == size(325, 379), "768 less 389, by a fast drag")
    let higherDock = ScreenLines(frame: Self.frame, visibleFrame: CGRect(x: 0, y: 31, width: 1024, height: 677))
    #expect(higherDock.allows(size(495, 439), to: rect(249, 298, 495, 654)) == size(495, 470), "768 less 298")
    #expect(higherDock.allows(size(494, 470), to: rect(260, 288, 494, 653)) == size(494, 480), "768 less 288")
    #expect(higherDock.allows(size(494, 470), to: rect(260, 138, 494, 653)) == size(494, 470), "from 791 to 608, right across")
    #expect(aboveADock.allows(size(325, 360), to: rect(326, 410, 325, 650)) == size(325, 360), "to 770: off the display before and after")
    #expect(aboveADock.allows(size(325, 297), to: rect(314, 408, 325, 650)) == size(325, 297), "onto the visible frame's bottom itself: not seen, and as before")
    #expect(aboveADock.allows(size(325, 298), to: rect(314, 408, 325, 650)) == size(325, 360), "a point past it")
    #expect(noDockBelow.allows(size(325, 348), to: rect(314, 408, 325, 650)) == size(325, 348), "no Dock below, no strip")
  }

  /// There it is held, for less as for more, as long as it would end there.
  @Test func inTheStripAFootIsHeldForLessToo() {
    #expect(aboveADock.allows(size(480, 348), to: rect(220, 392, 325, 360)) == size(480, 360), "the width is free")
    #expect(aboveADock.allows(size(480, 314), to: rect(220, 392, 480, 360)).height == 360, "to 706")
    #expect(aboveADock.allows(size(480, 313), to: rect(220, 392, 480, 360)).height == 313, "to 705, the visible frame's bottom")
    #expect(aboveADock.allows(size(480, 300), to: rect(220, 392, 480, 360)).height == 300, "out of the strip, onto the screen")
    #expect(aboveADock.allows(size(480, 348), to: rect(220, 408, 480, 360)).height == 360, "its foot on the display's bottom")
  }

  /// The bare calls, with the visible frame of their day: it ended at 708 with the Dock below, at 975 with the Dock at the right.
  @Test func theBareCallsOfTheShrinkingSide() {
    let below = ScreenLines(frame: Self.frame, visibleFrame: CGRect(x: 0, y: 31, width: 1024, height: 677))
    #expect(below.allows(size(322, 439), to: rect(344, 288, 322, 653)).height == 480, "from off the display into the strip: the display's bottom")
    #expect(below.allows(size(322, 300), to: rect(344, 288, 322, 653)).height == 300, "right across")
    #expect(below.allows(size(400, 439), to: rect(300, 272, 400, 480)).height == 480, "in the strip, and still in it: kept")
    #expect(below.allows(size(400, 400), to: rect(300, 272, 400, 480)).height == 400, "out of it, onto the screen")
    #expect(noDockBelow.allows(size(322, 439), to: rect(344, 288, 322, 653)).height == 439, "no strip below")
    let atTheRight = ScreenLines(frame: Self.frame, visibleFrame: CGRect(x: 0, y: 31, width: 975, height: 737))
    #expect(atTheRight.allows(size(371, 300), to: rect(624, 100, 700, 300)).width == 400, "the display's right edge")
    #expect(atTheRight.allows(size(320, 300), to: rect(624, 100, 700, 300)).width == 320)
    #expect(atTheRight.allows(size(361, 300), to: rect(624, 100, 381, 300)).width == 381)
    #expect(atTheRight.allows(size(320, 300), to: rect(624, 100, 381, 300)).width == 320)
    for (foot, grows) in [(743, false), (768, false), (769, true), (800, true), (850, true)] as [(CGFloat, Bool)] {
      #expect(below.allows(size(320, 400), to: rect(100, foot - 300, 320, 300)).height == (grows ? 400 : 300), "its foot at \(foot), asked for 100 more")
    }
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
    #expect(after(rect(220, 392, 480, 348), from: rect(314, 408, 325, 650)) == size(480, 360), "as a hosted Mac answered: too high by 12")
    #expect(after(rect(220, 392, 300, 348), from: rect(314, 408, 325, 650)) == size(300, 360), "and if it only shrinks")
  }
}
