import ArborCore
import ArborKit
import ArborTesting
import CoreGraphics
import Testing

/// Tiles: windows too small to use, and windows whose app would not take the slot.
@Suite(.withTiles) @MainActor struct TileTests {
  /// `[a | b]`, two halves (thirds, where the Desktop has a column between them), and `c` to dock below one of them.
  func makeHarness() -> (Harness, a: WindowID, b: WindowID, c: WindowID) {
    let h = Harness()
    let a = h.system.open(app: "Safari", frame: CGRect(x: 100, y: 100, width: 600, height: 400))
    let b = h.system.open(app: "Notes", frame: CGRect(x: 300, y: 200, width: 600, height: 400))
    let c = h.system.open(app: "Slack", frame: CGRect(x: 400, y: 200, width: 900, height: 700))
    h.start()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) right")
    return (h, a, b, c)
  }

  func isTile(_ h: Harness, _ window: WindowID) -> Bool {
    h.layout!.tiles.contains { $0.windows.contains(window) }
  }

  @Test func aWindowSeenSmallerThanItsLearnedMinimumIsNoLongerATile() {
    let (h, _, b, c) = makeHarness()
    // Slack is slow: when Arbor reads the frame back it still has the old size, which looks like a
    // refusal to shrink.
    h.system.setMinimumSize(c, CGSize(width: 900, height: 700))
    h.run("dock \(c.rawValue) beside \(b.rawValue) bottom")
    #expect(isTile(h, c))
    // A moment later the resize Arbor asked for arrives after all.
    h.system.setMinimumSize(c, .zero)
    var frame = h.frame(c)!
    frame.size = CGSize(width: 464, height: 420)
    h.system.userMove(c, to: frame)
    h.scheduler.advance(by: 1)
    #expect(!isTile(h, c), "the window has shown it can be that small")
    #expect(h.frame(c) == h.layout!.windowFrames[c])
  }

  @Test func anAppThatBouncesBetweenSizesIsNotChasedForever() {
    let (h, _, b, c) = makeHarness()
    h.system.setMinimumSize(c, CGSize(width: 900, height: 700))
    h.run("dock \(c.rawValue) beside \(b.rawValue) bottom")
    // Each time it is parked the app reports a small size for a moment, then refuses the slot again.
    var attempts = 0
    for _ in 0..<10 {
      h.system.clearFrameLog()
      var frame = h.frame(c)!
      frame.size = CGSize(width: 400, height: 300)
      h.system.userMove(c, to: frame)
      if !h.system.frameLog.isEmpty { attempts += 1 }
      #expect(isTile(h, c))
    }
    #expect(attempts == 3)
  }

  @Test func shrinkingAWindowBelowItsLearnedMinimumByHandIsNotInterrupted() {
    let (h, a, _, c) = makeHarness()
    h.system.setMinimumSize(c, CGSize(width: 900, height: 700))
    h.run("dock \(c.rawValue) beside \(a.rawValue) bottom")
    h.run("zoom \(c.rawValue)")
    h.system.setMinimumSize(c, .zero)
    h.system.clearFrameLog()
    var frame = h.frame(c)!
    frame.size.width = 700
    h.system.userResize(c, to: frame, release: false)
    #expect(h.system.frameLog.isEmpty, "nothing moves while the button is down")
    h.system.releaseMouse()
  }

  @Test func relayoutTriesWindowsThatRefusedTheirSlotAgain() {
    let (h, _, b, c) = makeHarness()
    h.system.setMinimumSize(c, CGSize(width: 900, height: 700))
    h.run("dock \(c.rawValue) beside \(b.rawValue) bottom")
    #expect(isTile(h, c))
    // The sheet that kept the window large is gone.
    h.system.setMinimumSize(c, .zero)
    h.run("show-all")
    #expect(isTile(h, c), "nothing has said otherwise yet")
    #expect(h.run("relayout").ok)
    #expect(!isTile(h, c))
  }

  @Test func aWindowThatStillRefusesStaysATileAfterRelayout() {
    let (h, _, b, c) = makeHarness()
    h.system.setMinimumSize(c, CGSize(width: 900, height: 700))
    h.run("dock \(c.rawValue) beside \(b.rawValue) bottom")
    h.run("relayout")
    #expect(isTile(h, c))
    #expect(!h.system.isVisible(c))
    #expect(h.frame(b) == h.layout!.windowFrames[b])
  }

  @Test func aNeighbourSqueezedBelowItsMinimumByAnEdgeDragComesBackWhenTheEdgeDoes() {
    let h = Harness()
    let a = h.system.open(app: "Safari", frame: CGRect(x: 100, y: 100, width: 600, height: 400))
    let b = h.system.open(app: "Xcode", frame: CGRect(x: 300, y: 200, width: 600, height: 400))
    h.start()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) beside \(a.rawValue) right")
    let slot = h.frame(b)!
    h.system.setMinimumSize(b, CGSize(width: slot.width - 25, height: 200))
    var pulled = h.frame(a)!
    pulled.size.width += 60
    h.system.userResize(a, to: pulled)
    #expect(isTile(h, b), "it cannot be that narrow, and must not hang over what is to its right")
    #expect(!h.system.isVisible(b))
    pulled.size.width -= 60
    h.system.userResize(a, to: pulled)
    #expect(!isTile(h, b))
    #expect(h.frame(b) == slot)
  }

  @Test func aSeamDraggedBackAndForthAcrossTheThresholdLeavesNoWindowBehind() {
    let (h, a, _, _) = makeHarness()
    // Down to 224 points, which is too narrow to use.
    let distance = Int(h.frame(a)!.width) - 224
    for _ in 0..<3 {
      h.run("resize \(a.rawValue) right -\(distance)")
      #expect(isTile(h, a))
      #expect(!h.system.isVisible(a))
      h.run("resize \(a.rawValue) right \(distance)")
      #expect(!isTile(h, a))
      #expect(h.frame(a) == h.layout!.windowFrames[a])
    }
  }

  // MARK: The shortcut for framing, pressed again and again

  /// Three windows arranged, of which `big` is too wide for its place and is a tile; framed on `big`.
  func framedOnATile() -> (Harness, big: WindowID) {
    let h = Harness()
    let big = h.system.open(app: "Xcode", pid: 11, minimumSize: CGSize(width: 1000, height: 600))
    _ = h.system.open(app: "Mail", pid: 12)
    _ = h.system.open(app: "Notes", pid: 13)
    h.start()
    // Otherwise room is made for it instead (F61).
    h.run("set makeRoom off")
    h.run("arrange")
    #expect(!h.system.isVisible(big))
    h.system.userFocus(big)
    #expect(h.workspace.camera == h.workspace.tree.leaf(containing: big))
    return (h, big)
  }

  @Test func theFramingShortcutGoesBackAndForthAlsoForAWindowThatIsATileOutside() {
    let (h, big) = framedOnATile()
    h.run("zoom")
    #expect(h.workspace.camera == h.workspace.tree.root)
    #expect(h.system.focusedWindow() != big, "it is out of view, so another window has the focus")
    h.run("zoom")
    #expect(h.workspace.camera == h.workspace.tree.leaf(containing: big), "a third press frames what the first two were about")
    #expect(h.system.focusedWindow() == big)
    h.run("zoom")
    #expect(h.workspace.camera == h.workspace.tree.root)
  }

  /// Across apps a Mac moves the keyboard only after the call has returned. Asked in the same breath who has it, it still names the
  /// window that has just gone out of view, so nothing was remembered, and the next press framed whoever had the keyboard by then.
  @Test func alsoWhenMacOSTakesAMomentToMoveTheKeyboard() throws {
    let (h, big) = framedOnATile()
    h.system.focusIsSlow = true
    h.run("zoom")
    #expect(h.workspace.camera == h.workspace.tree.root)
    let heir = try #require(h.system.focusRequests.last)
    #expect(heir != big)
    h.system.finishSlowFocus()
    #expect(h.system.focusedWindow() == heir)
    h.run("zoom")
    #expect(h.workspace.camera == h.workspace.tree.leaf(containing: big), "and not \(heir)")
    h.system.finishSlowFocus()
    #expect(h.system.focusedWindow() == big)
    h.run("zoom")
    #expect(h.workspace.camera == h.workspace.tree.root)
  }

  /// The key pressed twice in one roll of the fingers.
  @Test func andWhenTheSecondPressComesBeforeMacOSHasMovedIt() {
    let (h, big) = framedOnATile()
    h.system.focusIsSlow = true
    h.run("zoom")
    #expect(h.workspace.camera == h.workspace.tree.root)
    h.run("zoom")
    #expect(h.workspace.camera == h.workspace.tree.leaf(containing: big))
    h.system.finishSlowFocus()
    #expect(h.system.focusedWindow() == big)
  }

  /// Whom Arbor asked for counts for a moment only, and not against a person.
  @Test func aClickWhileMacOSIsStillOnItsWayHasTheLastWord() {
    let (h, big) = framedOnATile()
    h.system.focusIsSlow = true
    h.run("zoom")
    let other = h.workspace.tree.allWindows.first { $0 != big && $0 != h.system.focusRequests.last }!
    h.system.userFocus(other)
    h.run("zoom")
    #expect(h.workspace.camera == h.workspace.tree.leaf(containing: other))
  }

  @Test func afterTheUserPicksAnotherWindowTheShortcutIsAboutThatOne() {
    let (h, big) = framedOnATile()
    h.run("zoom")
    let other = h.workspace.tree.allWindows.first { $0 != big && $0 != h.system.focusedWindow() }!
    h.system.userFocus(other)
    h.run("zoom")
    #expect(h.workspace.camera == h.workspace.tree.leaf(containing: other))
  }

  @Test func andAMomentLaterItIsAboutTheFocusedWindow() {
    let (h, big) = framedOnATile()
    h.run("zoom")
    let heir = h.system.focusedWindow()!
    h.scheduler.advance(by: 10)
    h.run("zoom")
    #expect(h.workspace.camera == h.workspace.tree.leaf(containing: heir))
    _ = big
  }
}
