import ArborCore
import ArborKit
import ArborTesting
import CoreGraphics
import Testing

/// Scenario tests for resizing docked windows by their own edges
/// (docs/features/F07-resize-by-window-edges.md).
@Suite @MainActor struct EdgeResizeTests {
  /// `[a | Desktop | b]`, every column 464 points wide, with c floating on the Desktop.
  func columns(configure: (Harness, WindowID, WindowID, WindowID) -> Void = { _, _, _, _ in })
    -> (Harness, WindowID, WindowID, WindowID)
  {
    let h = Harness()
    let a = h.system.open(app: "Safari", frame: CGRect(x: 100, y: 100, width: 600, height: 400))
    let b = h.system.open(app: "Notes", frame: CGRect(x: 300, y: 200, width: 600, height: 400))
    let c = h.system.open(app: "Mail", frame: CGRect(x: 500, y: 300, width: 600, height: 400))
    configure(h, a, b, c)
    h.start()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) right")
    return (h, a, b, c)
  }

  /// `frame` with one edge moved by `points` (positive is right or down).
  func dragging(_ frame: CGRect, _ edge: Edge, by points: CGFloat) -> CGRect {
    var moved = frame
    switch edge {
    case .left:
      moved.origin.x += points
      moved.size.width -= points
    case .right:
      moved.size.width += points
    case .top:
      moved.origin.y += points
      moved.size.height -= points
    case .bottom:
      moved.size.height += points
    }
    return moved
  }

  /// Layout boundaries are rounded to whole points, so allow one point.
  func expectFrame(_ actual: CGRect?, _ expected: CGRect, sourceLocation: SourceLocation = #_sourceLocation) {
    guard let actual else {
      Issue.record("no frame, expected \(expected)", sourceLocation: sourceLocation)
      return
    }
    #expect(
      actual.approximatelyEquals(expected, tolerance: 1), "\(actual) is not \(expected)",
      sourceLocation: sourceLocation)
  }

  func noEnforcePending(_ h: Harness) -> Bool {
    !h.scheduler.pendingKeys.contains { $0.hasPrefix("enforce") }
  }

  // MARK: Acceptance criteria

  @Test func draggingAnEdgeMovesTheSeamOnThatSide() {
    let (h, a, b, _) = columns()
    let slotA = h.frame(a)!
    let slotB = h.frame(b)!
    let desktop = h.layout!.desktopFrame!

    // a's right edge 100 to the right: a is 100 wider, the Desktop 100 narrower.
    h.system.userResize(a, to: dragging(slotA, .right, by: 100))
    expectFrame(h.frame(a), dragging(slotA, .right, by: 100))
    expectFrame(h.layout!.desktopFrame, dragging(desktop, .left, by: 100))
    #expect(h.frame(b) == slotB)
    expectWindowsMatchLayout(h)
    #expect(noEnforcePending(h), "the resize is not put back")
    #expect(h.overlays.seams[h.display]?.first?.frame.minX == h.frame(a)!.maxX, "the seam handle follows")

    // b's left edge 50 to the left: the seam on b's leading side moves too.
    h.system.userResize(b, to: dragging(slotB, .left, by: -50))
    expectFrame(h.frame(b), dragging(slotB, .left, by: -50))
    expectFrame(h.layout!.desktopFrame, dragging(dragging(desktop, .left, by: 100), .right, by: -50))
    expectFrame(h.frame(a), dragging(slotA, .right, by: 100))
  }

  @Test func draggingTheBottomOfAWindowInAColumnShortensTheOneBelow() {
    let (h, a, b, c) = columns()
    h.run("dock \(c.rawValue) beside \(a.rawValue) bottom")
    let slotA = h.frame(a)!
    let slotB = h.frame(b)!
    let slotC = h.frame(c)!

    h.system.userResize(a, to: dragging(slotA, .bottom, by: 80))
    expectFrame(h.frame(a), dragging(slotA, .bottom, by: 80))
    expectFrame(h.frame(c), dragging(slotC, .top, by: 80))
    #expect(h.frame(b) == slotB)

    // Dragging c's top edge back up 30 gives c the room back.
    h.system.userResize(c, to: dragging(dragging(slotC, .top, by: 80), .top, by: -30))
    expectFrame(h.frame(a), dragging(slotA, .bottom, by: 50))
    expectFrame(h.frame(c), dragging(slotC, .top, by: 50))
    expectWindowsMatchLayout(h)
  }

  @Test func draggingACornerMovesBothSeams() {
    let (h, a, b, c) = columns()
    // [a / c] | Desktop | b: a's right edge belongs to the column, its bottom edge to a and c.
    h.run("dock \(c.rawValue) beside \(a.rawValue) bottom")
    let slotA = h.frame(a)!
    let slotB = h.frame(b)!
    let slotC = h.frame(c)!
    let desktop = h.layout!.desktopFrame!

    h.system.userResize(a, to: dragging(dragging(slotA, .right, by: 100), .bottom, by: 80))
    expectFrame(h.frame(a), dragging(dragging(slotA, .right, by: 100), .bottom, by: 80))
    expectFrame(h.frame(c), dragging(dragging(slotC, .right, by: 100), .top, by: 80))
    expectFrame(h.layout!.desktopFrame, dragging(desktop, .left, by: 100))
    #expect(h.frame(b) == slotB)
    expectWindowsMatchLayout(h)
  }

  @Test func outerEdgesArePutBack() {
    let (h, a, _, _) = columns()
    h.scheduler.runPending()
    let slotA = h.frame(a)!
    let tree = h.workspace.tree

    // a's left edge is against the screen; nothing is beside it.
    h.system.userResize(a, to: dragging(slotA, .left, by: 50))
    #expect(h.frame(a) == slotA)
    #expect(h.workspace.tree == tree)
    #expect(h.scheduler.pendingKeys.isEmpty, "nothing changed, so nothing to save or put back")

    // A corner with one outer edge: the top goes back, the right edge moves its seam.
    h.system.userResize(a, to: dragging(dragging(slotA, .top, by: -20), .right, by: 100))
    expectFrame(h.frame(a), dragging(slotA, .right, by: 100))
    expectWindowsMatchLayout(h)
  }

  @Test func edgesOfAZoomedWindowArePutBack() {
    let (h, a, b, _) = columns()
    h.run("zoom \(a.rawValue)")
    let full = h.frame(a)!
    let tree = h.workspace.tree
    // The neighbours are out of view, so every edge is an edge of the view.
    h.system.userResize(a, to: dragging(dragging(full, .right, by: -200), .bottom, by: -100))
    #expect(h.frame(a) == full)
    #expect(h.workspace.tree == tree)
    #expect(!h.system.isVisible(b))
  }

  @Test func aResizeTheAppClampsUsesTheFrameTheWindowEndedAt() {
    let (h, a, b, _) = columns()
    h.system.setMinimumSize(a, CGSize(width: 400, height: 0))
    h.system.setMaximumSize(b, CGSize(width: 500, height: 2000))
    let slotA = h.frame(a)!
    let slotB = h.frame(b)!

    // a will not shrink below 400 wide: dragging its right edge 200 to the left
    // stops after 64, and the seam follows the window, not the pointer.
    h.system.userResize(a, to: dragging(slotA, .right, by: -200))
    expectFrame(h.frame(a), dragging(slotA, .right, by: -64))
    #expect(h.layout!.desktopFrame!.minX - h.frame(a)!.maxX == 12)

    // b will not grow past 500 wide: dragging its left edge 150 to the left stops after 36.
    h.system.userResize(b, to: dragging(slotB, .left, by: -150))
    expectFrame(h.frame(b), dragging(slotB, .left, by: -36))
    #expect(h.frame(b)!.minX - h.layout!.desktopFrame!.maxX == 12)
    expectWindowsMatchLayout(h)
  }

  @Test func resizesWithoutTheMouseAreStillPutBack() {
    let (h, a, b, _) = columns()
    let slotA = h.frame(a)!
    let slotB = h.frame(b)!
    let tree = h.workspace.tree
    // Another tool (or the keyboard) widens a; no mouse is involved.
    h.system.userMove(a, to: dragging(slotA, .right, by: 100))
    #expect(!noEnforcePending(h))
    h.scheduler.runPending()
    #expect(h.frame(a) == slotA)
    #expect(h.frame(b) == slotB)
    #expect(h.workspace.tree == tree)
  }

  @Test func seamsStopAtTheMinimumOf80Points() {
    let (h, a, b, _) = columns()
    let slotA = h.frame(a)!
    let slotB = h.frame(b)!
    let tree = { h.workspace.tree }

    // Dragging a's right edge across the Desktop and over b leaves the Desktop 80 points.
    h.system.userResize(a, to: dragging(slotA, .right, by: 900))
    #expect(abs(h.layout!.nodeFrames[tree().desktop]!.width - 80) <= 1)
    #expect(h.frame(b) == slotB)

    // Squeezing a to 28 points leaves it 80 (too small to use, so a tile).
    let wide = h.frame(a)!
    h.system.userResize(a, to: CGRect(x: wide.minX, y: wide.minY, width: 28, height: wide.height))
    let leafA = tree().leaf(containing: a)!
    #expect(abs(h.layout!.nodeFrames[leafA]!.width - 80) <= 1)
    #expect(h.overlays.tiles[h.display]?.map(\.node) == [leafA])
    #expect(tree().invariantViolations().isEmpty)
  }

  // MARK: While the mouse is down

  @Test func nothingElseMovesWhileTheEdgeIsDragged() {
    let (h, a, b, c) = columns()
    let slotA = h.frame(a)!
    let others = [h.frame(b), h.frame(c)]
    let desktop = h.layout!.desktopFrame!
    h.system.clearFrameLog()

    h.system.userResize(a, to: dragging(slotA, .right, by: 50), release: false)
    h.system.userResize(a, to: dragging(slotA, .right, by: 100), release: false)
    h.scheduler.runPending()  // timers that fire mid-drag change nothing
    #expect(h.system.frameLog.isEmpty)
    #expect(h.frame(a) == dragging(slotA, .right, by: 100))
    #expect([h.frame(b), h.frame(c)] == others)

    h.system.releaseMouse()
    expectFrame(h.frame(a), dragging(slotA, .right, by: 100))
    expectFrame(h.layout!.desktopFrame, dragging(desktop, .left, by: 100))
  }

  @Test func aPutBackDueJustAfterTheButtonGoesUpWaitsForTheRelease() {
    let (h, a, _, _) = columns()
    let slotA = h.frame(a)!
    let desktop = h.layout!.desktopFrame!
    let wider = dragging(slotA, .right, by: 100)
    h.system.userResize(a, to: wider, release: false)

    // The button is up, but the window system has not delivered the release yet.
    h.system.mouseDown = false
    h.scheduler.runPending()
    #expect(h.frame(a) == wider)

    h.system.releaseMouse()
    expectFrame(h.frame(a), wider)
    expectFrame(h.layout!.desktopFrame, dragging(desktop, .left, by: 100))
    #expect(noEnforcePending(h))
  }

  @Test func aLostReleaseFallsBackToPuttingTheWindowBack() {
    let (h, a, _, _) = columns()
    let slotA = h.frame(a)!
    let tree = h.workspace.tree
    h.system.userResize(a, to: dragging(slotA, .right, by: 100), release: false)

    // The button is up and the window system never reports the release.
    h.system.mouseDown = false
    h.scheduler.runPending()
    #expect(h.frame(a) == dragging(slotA, .right, by: 100), "one round of grace")
    h.scheduler.runPending()
    #expect(h.frame(a) == slotA)
    #expect(h.workspace.tree == tree)
  }

  // MARK: Details

  @Test func smallChangesAreTheAppRoundingAndAreAccepted() {
    let (h, a, _, _) = columns()
    let slotA = h.frame(a)!
    let tree = h.workspace.tree
    h.system.clearFrameLog()
    h.system.userResize(a, to: dragging(slotA, .right, by: 3))
    #expect(h.system.frameLog.isEmpty)
    #expect(h.workspace.tree == tree)
    #expect(noEnforcePending(h))
  }

  @Test func anEdgeTheAppKeepsInsideItsSlotDoesNotCountAsMoved() {
    // a will not grow past 400 wide, so it sits 64 points inside the right
    // side of its 464-point column, like a terminal snapping to its character grid.
    let (h, a, b, c) = columns { h, a, _, _ in h.system.setMaximumSize(a, CGSize(width: 400, height: 2000)) }
    h.run("dock \(c.rawValue) beside \(a.rawValue) bottom")
    let sitting = h.frame(a)!
    #expect(sitting.width == 400)
    let slotB = h.frame(b)!
    let slotC = h.frame(c)!
    let desktop = h.layout!.desktopFrame!

    // Dragging a's bottom edge moves only the seam below a; the column keeps its width.
    h.system.userResize(a, to: dragging(sitting, .bottom, by: 80))
    expectFrame(h.frame(a), dragging(sitting, .bottom, by: 80))
    expectFrame(h.frame(c), dragging(slotC, .top, by: 80))
    #expect(h.layout!.desktopFrame == desktop)
    #expect(h.frame(b) == slotB)
  }

  @Test func bothEdgesOfANestedWindowLandWhereTheyWereReleased() {
    let h = Harness()
    let a = h.system.open(app: "Safari")
    let y = h.system.open(app: "Notes")
    let z = h.system.open(app: "Mail")
    h.start()
    // ((y | a) / z) | Desktop: a's left seam is inside the column, its right seam is the root's.
    h.run("dock \(a.rawValue) left")
    h.run("dock \(z.rawValue) beside \(a.rawValue) bottom")
    h.run("dock \(y.rawValue) beside \(a.rawValue) left")
    let slotA = h.frame(a)!
    let slotY = h.frame(y)!

    // ⌥-dragging an edge moves the opposite edge too. Moving the root seam
    // widens (y | a), so a's left edge has to be measured again after it moves.
    let released = dragging(dragging(slotA, .left, by: -60), .right, by: 60)
    h.system.userResize(a, to: released)
    expectFrame(h.frame(a), released)
    #expect(h.frame(y)!.minX == slotY.minX)
    #expect(h.frame(z)!.maxX == released.maxX)
    expectWindowsMatchLayout(h)
  }

  @Test func resizingAFloatingWindowWithTheMouseOnlyRemembersItsFrame() {
    let (h, a, b, c) = columns()
    let docked = [h.frame(a), h.frame(b)]
    let placed = CGRect(x: 520, y: 320, width: 380, height: 300)
    h.system.clearFrameLog()
    h.system.userResize(c, to: placed)
    #expect(h.workspace.floating[c] == placed)
    #expect(h.frame(c) == placed)
    #expect([h.frame(a), h.frame(b)] == docked)
    #expect(h.system.frameLog.isEmpty)
  }

  @Test func theNewSizesAreSaved() {
    let (h, a, _, _) = columns()
    h.scheduler.runPending()
    h.system.userResize(a, to: dragging(h.frame(a)!, .right, by: 100))
    #expect(h.scheduler.pendingKeys == ["save"])
    h.scheduler.runPending()
    #expect(h.store.saved?.workspaces[h.display]?.tree == h.workspace.tree)
  }

  /// The `resize` command shares the seam search with edge resizes.
  @Test func theResizeCommandStillExplainsWhyAnEdgeCannotMove() {
    let (h, a, _, _) = columns()
    h.run("zoom \(a.rawValue)")
    let outOfView = h.run("resize \(a.rawValue) right 100")
    #expect(!outOfView.ok)
    #expect(outOfView.message == "that edge is not in view; step out first")
    #expect(h.run("resize \(a.rawValue) left 100").message == "\(a) has no neighbor on the left")
  }
}
