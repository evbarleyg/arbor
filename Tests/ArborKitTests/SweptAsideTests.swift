import ArborCore
import ArborKit
import ArborTesting
import CoreGraphics
import Testing

/// macOS shows its desktop (a click on the wallpaper, as it comes): a picture, in which the window server lists every window at
/// the side of its display while Accessibility has it where it is. Arbor goes by Accessibility, and takes nothing the
/// window server lists meanwhile, or on the way back, for anybody's hand.
@Suite @MainActor struct SweptAsideTests {
  /// root(h)[a, desktop, b], showing everything, with `low` floating in the lower half of the Desktop and `high` in the upper.
  func makeHarness() -> (h: Harness, a: WindowID, b: WindowID, low: WindowID, high: WindowID) {
    let h = Harness()
    let a = h.system.open(app: "Safari", frame: CGRect(x: 100, y: 100, width: 600, height: 400))
    let b = h.system.open(app: "Notes", frame: CGRect(x: 300, y: 200, width: 600, height: 400))
    h.start()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) right")
    let desktop = h.layout!.desktopFrame!
    let low = h.system.open(
      app: "Mail", frame: CGRect(x: desktop.minX + 20, y: desktop.maxY - 260, width: desktop.width - 40, height: 240))
    let high = h.system.open(
      app: "Music", frame: CGRect(x: desktop.minX + 20, y: desktop.minY + 20, width: desktop.width - 40, height: 240))
    h.scheduler.advance(by: 2)
    return (h, a, b, low, high)
  }

  /// Everything Arbor can do to a window, counted.
  func touches(_ h: Harness) -> [Int] { [h.system.frameLog.count, h.system.raiseLog.count, h.system.focusLog.count] }

  func listed(_ h: Harness) -> [WindowID: CGRect] {
    Dictionary(uniqueKeysWithValues: h.system.stackedWindows().map { ($0.id, $0.frame) })
  }

  func believed(_ h: Harness) -> [WindowID: CGRect] {
    Dictionary(uniqueKeysWithValues: h.system.allWindows().map { ($0.id, $0.frame) })
  }

  @Test func theStandInSweepsAsAMacDoes() throws {
    let (h, a, _, low, high) = makeHarness()
    let before = believed(h)
    h.system.clickOnTheWallpaper()
    #expect(believed(h) == before, "Accessibility has them where they are")
    for (window, frame) in listed(h) {
      #expect(frame.size == before[window]?.size)
      #expect(frame.fractionInside(h.system.displayList[0].frame) < 0.2, "\(window) is listed at \(frame)")
    }
    #expect(try #require(listed(h)[a]).maxX == 12, "to the left")
    #expect(try #require(listed(h)[low]).minY == h.system.displayList[0].frame.maxY - 12, "down")
    #expect(try #require(listed(h)[high]).maxY == h.visibleFrame.minY + 12, "up, as far as the menu bar")
    // What is done to a window meanwhile is done, and nothing of it shows.
    let swept = listed(h)
    h.system.userMove(low, to: before[low]!.offsetBy(dx: 0, dy: -40).insetBy(dx: 10, dy: 10))
    h.system.raise(a)
    #expect(listed(h) == swept)
    h.system.setMinimized(a, true)
    h.system.setMinimized(a, false)
    #expect(listed(h) == swept)
    // What opens meanwhile opens in view.
    let new = h.system.open(app: "Chat", frame: CGRect(x: 500, y: 300, width: 300, height: 200))
    #expect(listed(h)[new] == believed(h)[new])
    #expect(h.system.isSweptAside)
    h.system.clickOnTheWallpaper()
    #expect(listed(h) == believed(h))
  }

  @Test func anAppThatComesForwardBringsThemBack() {
    let (h, a, _, _, _) = makeHarness()
    h.system.clickOnTheWallpaper()
    h.system.userSwitchesApp(to: a)
    #expect(!h.system.isSweptAside)
    h.system.pressShowDesktopKey()
    #expect(h.system.isSweptAside)
    h.system.pressShowDesktopKey()
    #expect(listed(h) == believed(h))
  }

  @Test func twoClicksOnTheWallpaperAndArborTouchesNothing() {
    let (h, _, _, _, _) = makeHarness()
    let (before, touched, arrangement) = (believed(h), touches(h), h.run("layout --ids").text)
    h.system.clickOnTheWallpaper()
    h.scheduler.advance(by: 12)
    #expect(h.system.isSweptAside)
    h.system.clickOnTheWallpaper()
    h.scheduler.advance(by: 5)
    #expect(touches(h) == touched)
    #expect(listed(h) == before, "every window is where it was")
    #expect(h.run("layout --ids").text == arrangement)
    expectWindowsMatchLayout(h)
  }

  /// The fault a Mac showed: the window leaps back in the window server's list with the button down, at the edge of the display.
  @Test(arguments: [0, 0.8]) func aClickOnAStripThatSlipsIsNoDrag(resting: Double) {
    let (h, a, b, low, high) = makeHarness()
    let (before, touched, arrangement) = (believed(h), touches(h), h.run("layout --ids").text)
    for window in [a, b, low, high] {
      h.system.clickOnTheWallpaper()
      h.system.clickOnTheStrip(of: window, resting: resting)
      h.scheduler.advance(by: 2)
      #expect(!h.system.isSweptAside)
      #expect(h.overlays.previewHistory.compactMap { $0 }.isEmpty, "a drop preview showed at the click on \(window)'s strip")
      #expect(h.run("layout --ids").text == arrangement, "after the click on \(window)'s strip")
      #expect(listed(h) == before, "after the click on \(window)'s strip")
    }
    #expect(touches(h) == touched)
    expectWindowsMatchLayout(h)
  }

  /// Laid out meanwhile, a window comes back with another size as well, and a change of size is judged by other rules. The
  /// outermost points of the strip are more than ten points from the border of the window as it is listed.
  @Test(arguments: [0, 1, 6, 11]) func norIsOneOnTheStripOfAWindowThatWasLaidOutMeanwhile(edge: CGFloat) {
    let (h, a, b, _, _) = makeHarness()
    h.system.clickOnTheWallpaper()
    h.system.close(b)
    h.scheduler.advance(by: 2)
    let (before, touched, arrangement) = (believed(h), touches(h), h.run("layout --ids").text)
    h.system.clickOnTheStrip(of: a, at: edge, resting: 0.8)
    h.scheduler.advance(by: 2)
    #expect(h.overlays.previewHistory.compactMap { $0 }.isEmpty)
    #expect(h.run("layout --ids").text == arrangement)
    #expect(listed(h) == before)
    #expect(touches(h) == touched)
    expectWindowsMatchLayout(h)
  }

  @Test func aCommandGivenMeanwhileDoesWhatItSaysAndBringsThemBack() {
    let (h, _, _, low, _) = makeHarness()
    h.system.clickOnTheWallpaper()
    #expect(h.run("dock \(low.rawValue) bottom").ok)
    #expect(!h.system.isSweptAside, "the docked window has the keyboard, so its app came forward")
    h.scheduler.advance(by: 2)
    #expect(listed(h) == believed(h))
    expectWindowsMatchLayout(h)
  }

  @Test func theControlWithNothingSweptTheSameIsShownAsMotion() {
    let (h, a, _, _, _) = makeHarness()
    h.overlays.clearTransitions()
    h.system.close(a)
    h.scheduler.advance(by: 2)
    #expect(!h.overlays.transitions.isEmpty)
  }

  /// Put off until they are back, it would be a jolt that everybody sees. Done at once it is one that nobody sees.
  @Test func whatHappensMeanwhileIsLaidOutAtOnceSoThatNothingMovesOnceTheyAreBack() {
    let (h, a, b, _, _) = makeHarness()
    let narrow = h.frame(b)!
    h.overlays.clearTransitions()
    h.system.clickOnTheWallpaper()
    h.system.close(a)
    h.scheduler.advance(by: 2)
    #expect(h.system.isSweptAside)
    #expect(h.frame(b)! != narrow, "the room of the window that closed is shared out")
    #expect(h.overlays.transitions.isEmpty, "stand-ins travelled over a desktop that somebody wanted bare")
    let touched = touches(h)
    h.system.clickOnTheWallpaper()
    h.scheduler.advance(by: 5)
    #expect(touches(h) == touched)
    #expect(listed(h) == believed(h))
    expectWindowsMatchLayout(h)
  }
}
