import ArborCore
import ArborKit
import ArborTesting
import CoreGraphics
import Testing

/// F05: `frame-rect`, the command a ⌃⌥-drag sends on release.
@Suite @MainActor struct FrameRectTests {
  /// root(h)[column(v)[a, c], desktop, b], showing everything.
  func makeHarness() -> (Harness, WindowID, WindowID, WindowID) {
    let h = Harness()
    let a = h.system.open(app: "Safari", frame: CGRect(x: 100, y: 100, width: 600, height: 400))
    let b = h.system.open(app: "Notes", frame: CGRect(x: 300, y: 200, width: 600, height: 400))
    let c = h.system.open(app: "Mail", frame: CGRect(x: 500, y: 300, width: 600, height: 400))
    h.start()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) right")
    h.run("dock \(c.rawValue) beside \(a.rawValue) bottom")
    return (h, a, b, c)
  }

  @discardableResult
  func frameRect(_ h: Harness, _ rect: CGRect) -> CommandResult {
    h.run("frame-rect \(rect.minX) \(rect.minY) \(rect.width) \(rect.height)")
  }

  @Test func aRectangleAroundOneWindowFramesIt() {
    let (h, a, b, c) = makeHarness()
    // Drawn by hand: a little larger than the window.
    let result = frameRect(h, h.frame(a)!.insetBy(dx: -20, dy: -15))
    #expect(result.ok, "\(result.message)")
    #expect(h.workspace.camera == h.workspace.tree.leaf(containing: a))
    #expect(h.frame(a) == h.visibleFrame.insetBy(dx: 12, dy: 12))
    #expect(!h.system.isVisible(b) && !h.system.isVisible(c))
    expectWindowsMatchLayout(h, on: h.display)
  }

  @Test func aRectangleAroundAColumnFramesTheColumn() {
    let (h, a, b, c) = makeHarness()
    let column = h.workspace.tree.parent(of: h.workspace.tree.leaf(containing: a)!)!
    // Drawn by hand: a little inside the two windows.
    #expect(frameRect(h, h.frame(a)!.union(h.frame(c)!).insetBy(dx: 15, dy: 10)).ok)
    #expect(h.workspace.camera == column)
    #expect(h.system.isVisible(a) && h.system.isVisible(c))
    #expect(!h.system.isVisible(b))
    #expect(h.frame(a)!.width == h.visibleFrame.width - 24)
    expectWindowsMatchLayout(h, on: h.display)
  }

  @Test func aRectangleAroundEverythingShowsEverything() {
    let (h, a, b, c) = makeHarness()
    h.system.clearFrameLog()
    #expect(frameRect(h, h.system.displayList[0].frame) == .failure("that is already the view"))
    #expect(h.workspace.camera == h.workspace.tree.root)
    for window in [a, b, c] { #expect(h.system.isVisible(window)) }
    #expect(h.system.frameLog.isEmpty, "nothing should move")
  }

  @Test func onlyWhatIsInViewCanBeFramed() {
    // The rectangle is matched against the current view, so drawing around
    // the whole screen while zoomed in keeps the zoomed-in node.
    let (h, a, _, _) = makeHarness()
    frameRect(h, h.frame(a)!)
    #expect(frameRect(h, h.system.displayList[0].frame) == .failure("that is already the view"))
    #expect(h.workspace.camera == h.workspace.tree.leaf(containing: a))
  }

  @Test func withNothingDockedThereIsNothingToFrame() {
    let h = Harness()
    _ = h.system.open(app: "Safari", frame: CGRect(x: 100, y: 100, width: 600, height: 400))
    h.start()
    #expect(frameRect(h, CGRect(x: 100, y: 100, width: 600, height: 600)) == .failure("that is already the view"))
  }

  @Test func aRectangleThatChangesNothingLeavesNoStepToGoBack() {
    let (h, a, b, _) = makeHarness()
    frameRect(h, h.frame(b)!)
    frameRect(h, h.frame(b)!)
    frameRect(h, h.frame(b)!)
    #expect(h.run("back").ok)
    #expect(h.workspace.camera == h.workspace.tree.root, "one step back, not three")
    #expect(h.system.isVisible(a))
  }

  @Test func whatCountsIsWhatTheViewShows() {
    // With Mail minimized the column looks exactly like Safari, so a rectangle around Safari changes nothing to look at.
    let (h, a, _, c) = makeHarness()
    let column = h.workspace.tree.parent(of: h.workspace.tree.leaf(containing: a)!)!
    #expect(frameRect(h, h.frame(a)!.union(h.frame(c)!)).ok)
    #expect(h.workspace.camera == column)
    h.system.setMinimized(c, true)
    h.scheduler.runPending()
    #expect(frameRect(h, h.frame(a)!) == .failure("that is already the view"))
    #expect(h.workspace.camera == column)
  }

  @Test func tinyRectanglesDoNothing() {
    let (h, a, _, _) = makeHarness()
    let centre = h.frame(a)!.center
    h.system.clearFrameLog()
    for size in [CGSize(width: 39, height: 300), CGSize(width: 300, height: 39), CGSize(width: 2, height: 2)] {
      let result = frameRect(h, CGRect(origin: centre, size: size))
      #expect(!result.ok)
      #expect(result.message.contains("40"))
    }
    #expect(h.workspace.camera == h.workspace.tree.root)
    #expect(h.system.frameLog.isEmpty)
    #expect(h.workspace.back.isEmpty)

    // 40 × 40 is big enough.
    #expect(frameRect(h, CGRect(origin: centre, size: CGSize(width: 40, height: 40))).ok)
    #expect(h.workspace.camera == h.workspace.tree.leaf(containing: a))
  }

  @Test func aRectangleDrawnUpAndLeftIsTheSameRectangle() {
    let (h, a, _, _) = makeHarness()
    let frame = h.frame(a)!
    #expect(h.run("frame-rect \(frame.maxX) \(frame.maxY) \(-frame.width) \(-frame.height)").ok)
    #expect(h.workspace.camera == h.workspace.tree.leaf(containing: a))
  }

  @Test func aRectangleOverNothingInViewFails() {
    let (h, _, _, _) = makeHarness()
    // Above the display, clear of every node.
    let result = frameRect(h, CGRect(x: 100, y: -200, width: 300, height: 150))
    #expect(!result.ok)
    #expect(h.workspace.camera == h.workspace.tree.root)
  }

  @Test func framingIsRecordedInHistory() {
    let (h, a, b, _) = makeHarness()
    frameRect(h, h.frame(b)!)
    #expect(h.workspace.camera == h.workspace.tree.leaf(containing: b))
    #expect(h.run("back").ok)
    #expect(h.workspace.camera == h.workspace.tree.root)
    #expect(h.system.isVisible(a) && h.system.isVisible(b))
  }

  @Test(.withTiles) func aRectangleOverATileZoomsOntoIt() {
    let h = Harness()
    let a = h.system.open(app: "Safari", frame: CGRect(x: 100, y: 100, width: 600, height: 400))
    let b = h.system.open(app: "Notes", frame: CGRect(x: 300, y: 200, width: 600, height: 400))
    let big = h.system.open(app: "Xcode", frame: CGRect(x: 400, y: 200, width: 700, height: 500))
    // More than its neighbours and the Desktop could spare between them (F61).
    h.system.setMinimumSize(big, CGSize(width: 1200, height: 600))
    h.start()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) right")
    h.run("dock \(big.rawValue) beside \(b.rawValue) bottom")
    let tile = h.overlays.tiles[h.display]!.first!
    #expect(!h.system.isVisible(big))
    #expect(frameRect(h, tile.frame.insetBy(dx: -6, dy: -6)).ok)
    #expect(h.workspace.camera == tile.node)
    #expect(h.system.isVisible(big))
  }

  @Test func theDisplayUnderTheRectanglesCentreIsFramed() {
    let side = DisplaySnapshot(
      id: DisplayID("side"), frame: CGRect(x: 1440, y: 0, width: 1280, height: 800),
      visibleFrame: CGRect(x: 1440, y: 0, width: 1280, height: 800), isMain: false)
    let h = Harness(displays: [FakeWindowSystem.standardDisplay, side])
    let main = h.system.open(app: "Safari", frame: CGRect(x: 100, y: 100, width: 600, height: 400))
    let left = h.system.open(app: "Notes", frame: CGRect(x: 1500, y: 100, width: 500, height: 400))
    let right = h.system.open(app: "Mail", frame: CGRect(x: 2100, y: 100, width: 500, height: 400))
    h.start()
    h.run("dock \(main.rawValue) left")
    h.run("dock \(left.rawValue) left")
    h.run("dock \(right.rawValue) right")
    // The pointer stays on the main display; the rectangle decides.
    h.system.cursor = CGPoint(x: 700, y: 450)
    #expect(frameRect(h, h.frame(right)!.insetBy(dx: 10, dy: 10)).ok)
    let sideWorkspace = h.controller.workspaces[side.id]!
    #expect(sideWorkspace.camera == sideWorkspace.tree.leaf(containing: right))
    #expect(!h.system.isVisible(left))
    #expect(h.workspace.camera == h.workspace.tree.root, "the main display does not move")
    #expect(h.system.isVisible(main))
  }

  @Test func aPauseLeavesNoWayToDrawARectangle() {
    // While paused no event may pass through Arbor, so both ways must be off for the taps to go.
    let h = Harness(settings: .withGestures)
    h.start()
    h.run("pause")
    var gesture = RectangleGesture()
    gesture.follow(h.controller.inputSettings)
    #expect(!gesture.isEnabled)
    #expect(h.controller.settings.frameRectangleOnDesktop, "the user's own settings are untouched")
    h.run("resume")
    #expect(h.controller.inputSettings.frameRectangleOnDesktop)
  }

  // MARK: During a peek, whose keys are the rectangle's too

  /// Three docked windows, the first framed, ⌃⌥Space held until the outline shows, the pointer on the second.
  func peeking() -> (Harness, framed: WindowID, pointedAt: WindowID) {
    let (h, a, b, _) = makeHarness()
    h.run("zoom \(a.rawValue)")
    h.system.userFocus(a)
    h.keyDown("ctrl+opt+space")
    h.scheduler.advance(by: 0.4)
    h.system.cursor = h.frame(b)!.center
    h.scheduler.advance(by: 0.1)
    #expect(h.controller.isPeeking && h.overlays.scenes[h.display]?.peekOutline != nil)
    return (h, a, b)
  }

  func letGo(_ h: Harness) {
    h.scheduler.advance(by: 0.2)
    h.keyUp("ctrl+opt+space")
    h.scheduler.advance(by: 1)
  }

  @Test func aClickOnThePeeksOutlineThatSlipsStillLands() {
    // ⌃⌥ is down, so the press is held as the beginning of a rectangle. Six points of a slip, and it arrives as one.
    let (h, _, b) = peeking()
    let point = h.frame(b)!.center
    #expect(h.run("frame-rect \(point.x) \(point.y) 6 3").ok)
    #expect(h.workspace.camera == h.workspace.tree.leaf(containing: b))
    #expect(!h.controller.isPeeking)
    letGo(h)
    #expect(h.workspace.camera == h.workspace.tree.leaf(containing: b), "and stays")
    expectWindowsMatchLayout(h, on: h.display)
  }

  @Test func aRealRectangleDuringAPeekIsFramed() {
    let (h, _, b) = peeking()
    #expect(frameRect(h, h.frame(b)!.insetBy(dx: 10, dy: 10)).ok)
    #expect(h.workspace.camera == h.workspace.tree.leaf(containing: b))
    letGo(h)
    #expect(h.workspace.camera == h.workspace.tree.leaf(containing: b))
  }

  @Test func withoutAPeekARectangleTooSmallIsStillRefused() {
    let (h, a, _, _) = makeHarness()
    let before = h.workspace
    let point = h.frame(a)!.center
    #expect(h.run("frame-rect \(point.x) \(point.y) 6 3").message == "the rectangle is smaller than 40 × 40 points")
    #expect(h.workspace == before)
  }

  @Test func aSlipBeforeTheOutlineShowsIsNoClickOnIt() {
    // The keys have only just gone down: nothing is outlined, so there is nothing to have clicked on.
    let (h, a, b, _) = makeHarness()
    h.run("zoom \(a.rawValue)")
    h.keyDown("ctrl+opt+space")
    h.scheduler.advance(by: 0.05)
    let point = h.frame(b)!.center
    #expect(!h.run("frame-rect \(point.x) \(point.y) 6 3").ok)
    #expect(!h.controller.isPeeking, "like any other command it ends the peek, and the view stays on everything")
    #expect(h.workspace.camera == h.workspace.tree.root)
  }

  @Test func itWaitsForAccessibilityLikeEveryOtherCommand() {
    let h = Harness()
    h.controller.accessibilityGranted = false
    let result = h.run("frame-rect 0 0 500 500")
    #expect(!result.ok)
    #expect(result.message.contains("Accessibility"))
  }
}
