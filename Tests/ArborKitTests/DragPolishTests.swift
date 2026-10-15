import ArborCore
import ArborKit
import ArborTesting
import CoreGraphics
import Testing

/// F09 (docs/features/F09-drag-polish.md): holding over a target, ⌘ to suppress docking, the
/// preview setting, live reflow, pushed windows staying pushed, and drags that end oddly.
///
/// The arrangement in most tests is [a | b], a half each, with c floating over the two. Where a test is about the Desktop between
/// docked windows (a window dragged out onto it, what floats on it pushed about) it is [a | Desktop | b], thirds, with c floating on
/// the Desktop: `DragScene(settings: .withDesktopColumn)`.
@MainActor
struct DragScene {
  let h: Harness
  let a: WindowID
  let b: WindowID
  let c: WindowID

  init(
    settings: Settings = Settings(), _ configure: (inout Settings) -> Void = { _ in },
    displays: [DisplaySnapshot] = [FakeWindowSystem.standardDisplay]
  ) {
    var settings = settings
    configure(&settings)
    h = Harness(displays: displays, settings: settings)
    a = h.system.open(app: "Safari", frame: CGRect(x: 100, y: 100, width: 600, height: 400))
    b = h.system.open(app: "Notes", frame: CGRect(x: 300, y: 200, width: 600, height: 400))
    c = h.system.open(app: "Mail", frame: CGRect(x: 520, y: 300, width: 400, height: 300))
    h.start()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) right")
    h.scheduler.runPending()
    h.system.clearFrameLog()
  }

  func frame(_ window: WindowID) -> CGRect { h.frame(window)! }
  /// With a column for the Desktop only: two halves leave it no room.
  var desktop: CGRect { h.layout!.desktopFrame! }
  /// A point on the Desktop, also as it is with live reflow once a has left its slot and the others have closed up.
  var onDesktop: CGPoint { CGPoint(x: desktop.minX + 60, y: desktop.midY) }
  /// A point in the gap left of b: in nobody's slot and no place to dock. Let go there a docked window goes back, a floating one stays.
  var inTheGap: CGPoint { CGPoint(x: h.layout!.windowFrames[b]!.minX - 6, y: 450) }

  /// A point in the band along one edge of a docked window's slot.
  func edge(_ edge: Edge, of window: WindowID) -> CGPoint {
    let slot = h.layout!.windowFrames[window]!
    switch edge {
    case .left: return CGPoint(x: slot.minX + 20, y: slot.midY)
    case .right: return CGPoint(x: slot.maxX - 20, y: slot.midY)
    case .top: return CGPoint(x: slot.midX, y: slot.minY + 20)
    case .bottom: return CGPoint(x: slot.midX, y: slot.maxY - 20)
    }
  }

  /// Where every window in view is, which ones are out of view, and everything Arbor remembers about
  /// every display. (A window out of view keeps the size of the last slot it was seen in, which nobody sees.)
  var outcome: Outcome {
    let inView = h.system.allWindows().filter { !h.controller.parked.contains($0.id) }
    return Outcome(
      frames: Dictionary(uniqueKeysWithValues: inView.map { ($0.id, $0.frame) }),
      workspaces: h.controller.workspaces, parked: h.controller.parked)
  }

  struct Outcome: Equatable {
    var frames: [WindowID: CGRect]
    var workspaces: [DisplayID: Workspace]
    var parked: Set<WindowID>
  }

  /// No timer, no preview, and every display showing its own layout: windows, tiles and seams.
  func expectNothingLeftBehind(sourceLocation: SourceLocation = #_sourceLocation) {
    #expect(!h.scheduler.pendingKeys.contains { $0.hasPrefix("drag") }, sourceLocation: sourceLocation)
    #expect(h.overlays.preview == nil, sourceLocation: sourceLocation)
    for display in h.controller.workspaces.keys {
      expectWindowsMatchLayout(h, on: display, sourceLocation: sourceLocation)
      #expect(h.overlays.seams[display] == h.controller.layouts[display]?.seamsInReach, sourceLocation: sourceLocation)
      #expect(
        h.overlays.tiles[display]?.map(\.node) == h.controller.layouts[display]?.tiles.map(\.node),
        sourceLocation: sourceLocation)
    }
  }
}

/// For tests that must hold with a setting off and on.
private let both = [false, true]

private let side = DisplaySnapshot(
  id: DisplayID("side"), frame: CGRect(x: 1440, y: 0, width: 1280, height: 800),
  visibleFrame: CGRect(x: 1440, y: 0, width: 1280, height: 800), isMain: false)

// MARK: Holding over a target (T10)

@Suite @MainActor struct DragDwellTests {
  @Test func passingQuicklyOverAWindowEdgeDoesNotDock() {
    let s = DragScene()
    let drop = s.edge(.bottom, of: s.b)
    s.h.system.drag(s.c, through: [s.frame(s.c).center, s.edge(.left, of: s.b), drop], holding: 0)
    #expect(s.h.workspace.isFloating(s.c))
    #expect(s.h.workspace.tree.allWindows == [s.a, s.b])
    #expect(s.h.overlays.previewHistory.allSatisfy { $0 == nil }, "nothing was promised")
    #expect(s.frame(s.c).contains(drop), "it stays where it was let go")
    s.expectNothingLeftBehind()
  }

  @Test(arguments: both) func aDockedWindowLetGoBeforeTheHoldIsOverGoesBackToItsSlot(reflow: Bool) {
    let s = DragScene { $0.reflowWhileDragging = reflow }
    let before = s.outcome
    s.h.system.drag(s.a, through: [s.frame(s.a).center, s.inTheGap, s.edge(.bottom, of: s.b)], holding: 0)
    #expect(s.outcome == before, "not undocked and left lying over the others")
    #expect(s.h.overlays.previewHistory.allSatisfy { $0 == nil })
    s.expectNothingLeftBehind()
  }

  /// Only the Desktop, or ⌘, takes a docked window out of the arrangement (the product owner's decision).
  @Test(arguments: both, [0, 0.5]) func aDockedWindowLetGoWhereNothingIsPreviewedGoesBackToItsSlot(reflow: Bool, held: Double) {
    let s = DragScene(settings: .withDesktopColumn) { $0.reflowWhileDragging = reflow }
    let before = s.outcome
    let gap = CGPoint(x: s.frame(s.b).minX - 6, y: 450)
    for nowhere in [s.frame(s.b).center, gap] {
      s.h.system.drag(s.a, through: [s.frame(s.a).center, s.onDesktop, nowhere], holding: held)
      #expect(s.outcome == before, "\(nowhere)")
      #expect(s.h.overlays.previewHistory.allSatisfy { $0 == nil })
      s.expectNothingLeftBehind()
    }
    s.h.system.drag(s.a, through: [s.frame(s.a).center, s.frame(s.b).center, s.onDesktop], holding: held)
    #expect(s.h.workspace.isFloating(s.a), "the Desktop does, at once")
  }

  @Test(arguments: both) func aDockedWindowGoesBackFromTheMiddleOfAWindowOnAnotherDisplay(reflow: Bool) {
    let s = DragScene({ $0.reflowWhileDragging = reflow }, displays: [FakeWindowSystem.standardDisplay, side])
    let d = s.h.system.open(app: "Terminal", frame: CGRect(x: 1600, y: 100, width: 500, height: 300))
    s.h.system.cursor = CGPoint(x: 1800, y: 300)
    s.h.run("dock \(d.rawValue) left")
    let before = s.outcome
    s.h.system.drag(s.a, through: [s.frame(s.a).center, s.inTheGap, s.frame(d).center])
    #expect(s.outcome == before)
    s.expectNothingLeftBehind()
  }

  @Test func theDesktopTakesADockedWindowAlsoWhenItIsATile() {
    let s = DragScene(settings: .withDesktopColumn)
    // With nothing on it, the Desktop is not kept at a usable size.
    s.h.system.close(s.c)
    // The window itself stays in view: nobody can take hold of one that is a tile.
    s.h.run("resize \(s.b.rawValue) left 300")
    #expect(s.h.layout!.windowFrames[s.b] != nil)
    guard let tile = s.h.layout!.tiles.first(where: { $0.node == s.h.workspace.tree.desktop }) else {
      Issue.record("the Desktop should be a tile by now")
      return
    }
    s.h.system.drag(s.b, through: [s.frame(s.b).center, tile.frame.center])
    #expect(s.h.workspace.isFloating(s.b))
    s.expectNothingLeftBehind()
  }

  @Test func aFloatingWindowLetGoOverTheMiddleOfADockedOneStaysThere() {
    let s = DragScene()
    let middle = s.frame(s.b).center
    s.h.system.drag(s.c, through: [s.frame(s.c).center, middle])
    #expect(s.h.workspace.isFloating(s.c))
    #expect(s.frame(s.c).contains(middle))
    #expect(s.h.workspace.floating[s.c] == s.frame(s.c))
  }

  @Test func holdingOverAWindowEdgeDocks() {
    let s = DragScene()
    s.h.system.beginDrag(s.c)
    s.h.system.moveDrag(to: s.edge(.bottom, of: s.b))
    #expect(s.h.overlays.preview == nil)
    s.h.scheduler.advance(by: 0.14)
    #expect(s.h.overlays.preview == nil, "the default is 0.15 s")
    s.h.scheduler.advance(by: 0.02)
    let preview = s.h.overlays.preview
    #expect(preview != nil)
    s.h.system.endDrag()
    #expect(s.h.workspace.isDocked(s.c))
    #expect(s.frame(s.c) == preview, "the preview showed where it landed")
    #expect(s.frame(s.c).minY > s.frame(s.b).maxY)
    s.expectNothingLeftBehind()
  }

  @Test func movingToAnotherTargetStartsTheHoldAgainAndHidesThePreview() {
    let s = DragScene()
    s.h.system.beginDrag(s.c)
    s.h.system.moveDrag(to: s.edge(.bottom, of: s.b), holding: 0.1)
    s.h.system.moveDrag(to: s.edge(.left, of: s.b), holding: 0.1)
    #expect(s.h.overlays.preview == nil, "0.2 s in all, but only 0.1 s on this target")
    s.h.system.holdDrag(for: 0.06)
    let left = s.h.overlays.preview
    #expect(left != nil)

    s.h.system.moveDrag(to: s.edge(.top, of: s.b))
    #expect(s.h.overlays.preview == nil, "an active target's preview goes when the pointer leaves it")
    s.h.system.holdDrag(for: 0.16)
    #expect(s.h.overlays.preview != nil && s.h.overlays.preview != left)
    s.h.system.endDrag()
    #expect(s.frame(s.c).maxY < s.frame(s.b).minY)
  }

  @Test func movingWithinATargetKeepsTheHold() {
    let s = DragScene()
    let point = s.edge(.bottom, of: s.b)
    s.h.system.beginDrag(s.c)
    s.h.system.moveDrag(to: point, holding: 0.1)
    s.h.system.moveDrag(to: CGPoint(x: point.x + 40, y: point.y - 5), holding: 0.06)
    #expect(s.h.overlays.preview != nil)
  }

  @Test func screenEdgesAndTheWindowsOwnSlotDoNotWait() {
    let s = DragScene()
    s.h.system.tiling = .off  // the screen's edges are Arbor's only with macOS's tiling off
    s.h.system.beginDrag(s.c)
    s.h.system.moveDrag(to: CGPoint(x: 3, y: 450))
    #expect(s.h.overlays.preview != nil, "a screen edge shows at once")
    s.h.system.endDrag()
    #expect(s.h.workspace.isDocked(s.c))
    #expect(s.frame(s.c).minX == s.h.visibleFrame.minX + 12)

    let slot = s.frame(s.a)
    s.h.system.drag(s.a, through: [slot.center, s.inTheGap, slot.center], holding: 0)
    #expect(s.h.workspace.isDocked(s.a))
    #expect(s.frame(s.a) == slot)
    s.expectNothingLeftBehind()
  }

  /// 0 means off, for whoever wants no docking at the screen's edges or beside windows: no preview, and a floating window
  /// stays where it is let go of.
  @Test(arguments: [false, true]) func withBothBandsAtNoughtNoDragDocks(reflow: Bool) {
    let s = DragScene {
      $0.screenEdgeBand = 0
      $0.windowEdgeFraction = 0
      $0.dropDwell = 0
      $0.reflowWhileDragging = reflow
    }
    s.h.system.tiling = .off  // the screen's edges are Arbor's only with macOS's tiling off
    let slot = s.frame(s.b)
    for point in [
      CGPoint(x: 720, y: 20),  // in the menu bar
      CGPoint(x: 720, y: s.h.visibleFrame.minY), CGPoint(x: 0, y: 450), CGPoint(x: slot.minX, y: slot.midY),
      CGPoint(x: slot.midX, y: slot.minY),
    ] {
      s.h.system.clearFrameLog()
      s.h.system.beginDrag(s.c)
      s.h.system.moveDrag(to: point)
      #expect(s.h.overlays.preview == nil, "\(point)")
      let held = s.frame(s.c)
      s.h.system.endDrag()
      s.h.scheduler.advance(by: 3)
      #expect(s.h.workspace.isFloating(s.c) && s.frame(s.c) == held, "\(point)")
      #expect(s.h.system.frameLog.isEmpty, "Arbor moved nothing: \(s.h.system.frameLog)")
    }
    // A docked window carried into the menu bar is docked nowhere else: it goes back to its slot.
    let own = s.frame(s.a)
    s.h.system.drag(s.a, through: [own.center, CGPoint(x: 720, y: 300), CGPoint(x: 720, y: 20)])
    s.h.scheduler.advance(by: 3)
    #expect(s.h.workspace.isDocked(s.a) && s.frame(s.a) == own)
    s.expectNothingLeftBehind()
  }

  /// A display can have a band of its own, and so none of its own.
  @Test func aDisplayWithABandOfNoughtOffersNoEdgeOfItsOwn() {
    let s = DragScene { $0.displays = [DisplayOptions(match: .main, screenEdgeBand: 0)] }
    s.h.system.tiling = .off
    s.h.system.beginDrag(s.c)
    s.h.system.moveDrag(to: CGPoint(x: 3, y: 450))
    #expect(s.h.overlays.preview == nil)
    s.h.system.endDrag()
    #expect(s.h.workspace.isFloating(s.c))
    s.expectNothingLeftBehind()
  }

  @Test func aDwellOfZeroActivatesEveryTargetAtOnce() {
    let s = DragScene { $0.dropDwell = 0 }
    s.h.system.beginDrag(s.c)
    s.h.system.moveDrag(to: s.edge(.bottom, of: s.b))
    #expect(s.h.overlays.preview != nil)
    #expect(!s.h.scheduler.pendingKeys.contains("drag-dwell"))
    s.h.system.endDrag()
    #expect(s.h.workspace.isDocked(s.c))
  }

  @Test func aLongerDwellWaitsLonger() {
    let s = DragScene { $0.dropDwell = 1 }
    s.h.system.drag(s.c, through: [s.frame(s.c).center, s.edge(.bottom, of: s.b)], holding: 0.9)
    #expect(s.h.workspace.isFloating(s.c))
    s.h.system.drag(s.c, through: [s.frame(s.c).center, s.edge(.bottom, of: s.b)], holding: 1.1)
    #expect(s.h.workspace.isDocked(s.c))
  }

  @Test(.withTiles) func tilesWaitLikeWindows() {
    let s = DragScene()
    let big = s.h.system.open(app: "Xcode", frame: CGRect(x: 500, y: 200, width: 440, height: 300))
    // More than anybody can spare, or room would be made for it (F61).
    s.h.system.setMinimumSize(big, CGSize(width: 1250, height: 700))
    s.h.run("dock \(big.rawValue) beside \(s.b.rawValue) bottom")
    guard let tile = s.h.layout!.tiles.first else {
      Issue.record("Xcode should be a tile")
      return
    }
    let point = CGPoint(x: tile.frame.minX + 20, y: tile.frame.midY)
    s.h.system.drag(s.c, through: [s.frame(s.c).center, point], holding: 0)
    #expect(s.h.workspace.isFloating(s.c))
    s.h.system.drag(s.c, through: [s.frame(s.c).center, point])
    #expect(s.h.workspace.isDocked(s.c))
  }

  @Test func theMiddleOfAWindowWaitsTooWhenItMakesATabGroup() {
    let s = DragScene { $0.tabsEnabled = true }
    let middle = s.frame(s.b).center
    s.h.system.drag(s.c, through: [s.frame(s.c).center, middle], holding: 0)
    #expect(s.h.workspace.isFloating(s.c))
    s.h.system.drag(s.c, through: [s.frame(s.c).center, s.inTheGap, middle])
    #expect(s.h.workspace.tree.leaf(containing: s.c) == s.h.workspace.tree.leaf(containing: s.b))
    s.expectNothingLeftBehind()
  }

  @Test func aDragReportedLateCountsTheHoldFromThen() {
    let s = DragScene()
    // The pointer is already resting on the target when Arbor first hears of the drag.
    s.h.system.beginDrag(s.c, at: s.edge(.bottom, of: s.b))
    #expect(s.h.overlays.preview == nil)
    s.h.system.holdDrag(for: 0.16)
    #expect(s.h.overlays.preview != nil)
    s.h.system.endDrag()
    #expect(s.h.workspace.isDocked(s.c))
  }

  @Test func onlyTheTargetThatWasHeldCounts() {
    let s = DragScene()
    s.h.system.beginDrag(s.c)
    s.h.system.moveDrag(to: s.edge(.bottom, of: s.b), holding: 0.3)
    #expect(s.h.overlays.preview != nil)
    // The button comes up over another target before any move there was reported.
    s.h.system.mouseDown = false
    s.h.controller.dragEnded(s.c, at: s.edge(.left, of: s.b))
    #expect(s.h.workspace.isFloating(s.c))
    s.expectNothingLeftBehind()
  }
}

// MARK: ⌘ suppresses docking

/// Where a plain drag docks (`dragDocks` "always", as in the first build). As Arbor ships it is the other way round:
/// APlainDragFloatsTests.
@Suite @MainActor struct DragSuppressTests {
  static let always: (inout Settings) -> Void = { $0 = $0.withPlainDragsDocking }

  @Test func withCommandHeldADropOverAnyTargetFloatsTheWindow() {
    let s = DragScene(Self.always)
    s.h.system.heldModifiers = .command
    for point in [CGPoint(x: 3, y: 450), s.edge(.bottom, of: s.b), s.edge(.left, of: s.a)] {
      s.h.system.drag(s.c, through: [s.frame(s.c).center, point])
      #expect(s.h.workspace.isFloating(s.c), "\(point)")
    }
    #expect(s.h.workspace.tree.allWindows == [s.a, s.b])
    #expect(s.h.overlays.previewHistory.allSatisfy { $0 == nil })
    s.expectNothingLeftBehind()
  }

  @Test func withCommandHeldADockedWindowIsUndockedEvenOverItsOwnSlot() {
    let s = DragScene(Self.always)
    let slot = s.frame(s.a)
    s.h.system.heldModifiers = .command
    s.h.system.drag(s.a, through: [CGPoint(x: slot.midX, y: slot.minY + 10), CGPoint(x: slot.midX + 30, y: slot.midY)])
    #expect(s.h.workspace.isFloating(s.a))
    #expect(s.h.workspace.tree.allWindows == [s.b])
    s.expectNothingLeftBehind()
  }

  /// As far as Arbor is concerned. With "Hold ⌥ key while dragging windows to tile" on, ⌥ makes the window macOS's (MacTilingTests).
  @Test func theOtherModifiersDoNotSuppressDocking() {
    let s = DragScene(Self.always)
    s.h.system.tiling.optionKey = false
    s.h.system.heldModifiers = [.option, .shift, .control]
    s.h.system.drag(s.c, through: [s.frame(s.c).center, s.edge(.bottom, of: s.b)])
    #expect(s.h.workspace.isDocked(s.c))
    s.h.system.heldModifiers = [.option, .command]
    s.h.system.drag(s.c, through: [s.frame(s.c).center, CGPoint(x: 3, y: 450)])
    #expect(s.h.workspace.isFloating(s.c), "⌘ counts whatever else is held")
  }

  @Test func commandAtTheMomentOfReleaseIsEnough() {
    let s = DragScene(Self.always)
    s.h.system.beginDrag(s.c)
    s.h.system.moveDrag(to: s.edge(.bottom, of: s.b), holding: 0.3)
    #expect(s.h.overlays.preview != nil)
    s.h.system.heldModifiers = .command
    s.h.system.endDrag()
    #expect(s.h.workspace.isFloating(s.c))
    s.expectNothingLeftBehind()
  }

  @Test func pressingCommandHidesThePreviewAndLettingGoOfItStartsTheHoldAgain() {
    let s = DragScene(Self.always)
    s.h.system.beginDrag(s.c)
    s.h.system.moveDrag(to: s.edge(.bottom, of: s.b), holding: 0.3)
    #expect(s.h.overlays.preview != nil)
    s.h.system.holdModifierKeys(.command)
    #expect(s.h.overlays.preview == nil)
    s.h.system.holdModifierKeys([])
    #expect(s.h.overlays.preview == nil)
    s.h.system.holdDrag(for: 0.16)
    #expect(s.h.overlays.preview != nil)
    s.h.system.endDrag()
    #expect(s.h.workspace.isDocked(s.c))
  }

  /// ⌃⌥⌘ + arrow moves the focused window. Pressed with a window in the hand it is a command, not "do not dock".
  /// With macOS's ⌥ switch off: with it on, macOS tiles a window let go with ⌃⌥⌘ held, as it was seen to (MacTilingTests).
  @Test func arborsOwnShortcutsHeldDuringADragDoNotTurnDockingOff() {
    let s = DragScene(Self.always)
    s.h.system.tiling.optionKey = false
    s.h.system.beginDrag(s.c)
    s.h.system.moveDrag(to: s.edge(.bottom, of: s.b), holding: 0.3)
    let preview = s.h.overlays.preview
    #expect(preview != nil)
    s.h.system.holdModifierKeys([.control, .option, .command])
    #expect(s.h.overlays.preview == preview)
    s.h.system.endDrag()
    #expect(s.h.workspace.isDocked(s.c))
    s.h.system.heldModifiers = []
    // With ⇧ it is still ⌘.
    s.h.system.heldModifiers = [.shift, .command]
    s.h.system.drag(s.c, through: [s.frame(s.c).center, s.edge(.top, of: s.a)])
    #expect(s.h.workspace.isFloating(s.c))
  }

  @Test func commandPressedWhileHoldingKeepsTheTargetFromActivating() {
    let s = DragScene(Self.always)
    s.h.system.beginDrag(s.c)
    s.h.system.moveDrag(to: s.edge(.bottom, of: s.b), holding: 0.1)
    // No event tells the controller; it has to look when the hold is over.
    s.h.system.heldModifiers = .command
    s.h.system.holdDrag(for: 0.3)
    #expect(s.h.overlays.preview == nil)
    #expect(!s.h.scheduler.pendingKeys.contains("drag-dwell"))
  }
}

// MARK: The preview setting (T11)

@Suite @MainActor struct DragPreviewTests {
  /// Nothing would show when the hold is over (the product owner's decision).
  @Test func withoutPreviewsNothingHasToBeHeld() {
    let s = DragScene { $0.previewDrags = false }
    s.h.system.drag(s.c, through: [s.frame(s.c).center, s.edge(.bottom, of: s.b)], holding: 0)
    #expect(s.h.workspace.isDocked(s.c))
    #expect(s.frame(s.c).minY > s.frame(s.b).maxY)
    s.expectNothingLeftBehind()
  }

  @Test func withoutPreviewsDragsStillDockWhereTheyWould() {
    let s = DragScene { $0.previewDrags = false }
    let shown = DragScene()
    for scene in [s, shown] {
      scene.h.system.drag(scene.c, through: [scene.frame(scene.c).center, scene.edge(.bottom, of: scene.b)])
      scene.h.system.drag(scene.a, through: [scene.frame(scene.a).center, CGPoint(x: 720, y: 897)])
    }
    #expect(s.h.overlays.previewHistory.allSatisfy { $0 == nil })
    #expect(shown.h.overlays.previewHistory.contains { $0 != nil })
    #expect(s.outcome == shown.outcome)
  }
}

// MARK: Live reflow (T09)

@Suite @MainActor struct DragReflowTests {
  static let reflow: (inout Settings) -> Void = { $0.reflowWhileDragging = true }

  @Test func withoutReflowNothingMovesUntilTheDrop() {
    let s = DragScene()
    s.h.system.beginDrag(s.a)
    s.h.system.moveDrag(to: s.inTheGap, holding: 0.3)
    s.h.system.moveDrag(to: s.edge(.bottom, of: s.b), holding: 0.3)
    #expect(s.h.system.frameLog.isEmpty)
  }

  @Test func neighboursTakeTheSpaceOfADockedWindowThatLeavesItsSlot() {
    let s = DragScene(settings: .withDesktopColumn, Self.reflow)
    let before = s.h.workspace
    let layout = s.h.layout
    let slotB = s.frame(s.b)
    s.h.system.beginDrag(s.a)
    s.h.system.moveDrag(to: CGPoint(x: s.frame(s.a).midX + 30, y: 300))
    #expect(s.h.system.frameLog.isEmpty, "still over its own slot")

    s.h.system.moveDrag(to: s.onDesktop)
    let during = s.frame(s.b)
    #expect(during.width > slotB.width && during.maxX == slotB.maxX, "b takes its share at once")
    #expect(s.h.system.frameLog.allSatisfy { $0.window != s.a }, "the dragged window stays in the hand")
    #expect(s.h.workspace == before, "nothing is decided yet")
    #expect(s.h.layout == layout)
    #expect(s.h.overlays.seams[s.h.display] != layout?.seams, "the seam handles follow the windows")

    s.h.system.endDrag()
    #expect(s.h.workspace.isFloating(s.a))
    #expect(s.frame(s.b) == during, "what was shown is what the drop produced")
    s.expectNothingLeftBehind()
  }

  @Test func droppedBackTheNeighboursMakeRoomAgainAndNothingHasChanged() {
    let s = DragScene(Self.reflow)
    // Some history and a saved view, which a drop that was never made must not disturb.
    s.h.run("zoom \(s.a.rawValue)")
    s.h.run("save-view 1")
    s.h.run("show-all")
    s.h.run("zoom \(s.b.rawValue)")
    s.h.run("back")
    let before = s.outcome
    let slot = s.frame(s.a)

    s.h.system.beginDrag(s.a)
    s.h.system.moveDrag(to: s.inTheGap, holding: 0.3)
    s.h.system.moveDrag(to: s.edge(.top, of: s.b), holding: 0.3)
    #expect(s.frame(s.b) != before.frames[s.b])
    s.h.system.moveDrag(to: slot.center)
    #expect(s.frame(s.b) == before.frames[s.b], "they make room while it is still held")
    s.h.system.endDrag()
    #expect(s.outcome == before)
    s.expectNothingLeftBehind()
  }

  @Test func theOthersMakeRoomAtATargetOnceItIsActive() {
    let s = DragScene(Self.reflow)
    let slotB = s.frame(s.b)
    s.h.system.beginDrag(s.c)
    s.h.system.moveDrag(to: s.edge(.bottom, of: s.b), holding: 0.1)
    #expect(s.frame(s.b) == slotB, "not before the hold is over")
    s.h.system.holdDrag(for: 0.1)
    let preview = s.h.overlays.preview!
    let during = s.frame(s.b)
    #expect(during.height < slotB.height && during.minY == slotB.minY)
    #expect(!during.overlaps(preview), "the gap is where the preview is")
    #expect(s.h.workspace.isFloating(s.c))

    s.h.system.endDrag()
    #expect(s.frame(s.b) == during)
    #expect(s.frame(s.c) == preview)
    s.expectNothingLeftBehind()
  }

  @Test func leavingAnActiveTargetClosesTheGap() {
    let s = DragScene(Self.reflow)
    let before = s.outcome
    s.h.system.beginDrag(s.c)
    s.h.system.moveDrag(to: s.edge(.bottom, of: s.b), holding: 0.3)
    #expect(s.frame(s.b) != before.frames[s.b])
    s.h.system.moveDrag(to: s.inTheGap)
    #expect(s.frame(s.b) == before.frames[s.b])
    #expect(s.h.overlays.seams[s.h.display] == s.h.layout?.seams)
  }

  @Test func theOldSlotStaysClosedWhereNothingCanBeDropped() {
    let s = DragScene(settings: .withDesktopColumn, Self.reflow)
    let before = s.outcome
    s.h.system.beginDrag(s.a)
    s.h.system.moveDrag(to: s.onDesktop)
    let closedUp = s.frame(s.b)
    #expect(closedUp != before.frames[s.b])
    s.h.system.clearFrameLog()
    s.h.system.moveDrag(to: closedUp.center, holding: 0.3)
    #expect(s.h.system.frameLog.isEmpty, "nothing moves for a place that is on the way to somewhere")
    s.h.system.endDrag()
    #expect(s.outcome == before, "let go there, it goes back and they make room")
    s.expectNothingLeftBehind()
  }

  @Test func theGapOpenedForTheWindowIsItsTarget() {
    let s = DragScene(Self.reflow)
    let slotB = s.frame(s.b)
    s.h.system.beginDrag(s.c)
    s.h.system.moveDrag(to: s.edge(.bottom, of: s.b), holding: 0.3)
    let preview = s.h.overlays.preview!
    // In b's slot as it was this is the middle, which docks nothing. But b has moved out of the way.
    let inTheGap = CGPoint(x: slotB.midX, y: preview.minY + 30)
    #expect(slotB.insetBy(dx: slotB.width * 0.31, dy: slotB.height * 0.31).contains(inTheGap))
    s.h.system.moveDrag(to: inTheGap)
    #expect(s.h.overlays.preview == preview)
    s.h.system.endDrag()
    #expect(s.frame(s.c) == preview)
  }

  @Test func targetsAreWhatTheUserSeesOnceTheWindowHasLeft() {
    let s = DragScene(settings: .withDesktopColumn, Self.reflow)
    let desktopBefore = s.desktop
    s.h.system.beginDrag(s.a)
    s.h.system.moveDrag(to: s.onDesktop)
    // b has grown to the left, over what the resting layout still calls the Desktop.
    let point = CGPoint(x: s.frame(s.b).minX + 20, y: s.frame(s.b).midY)
    #expect(desktopBefore.contains(point))
    s.h.system.moveDrag(to: point, holding: 0.3)
    #expect(s.h.overlays.preview != nil)
    s.h.system.endDrag()
    #expect(s.h.workspace.isDocked(s.a))
    #expect(s.frame(s.a).maxX < s.frame(s.b).minX && s.frame(s.a).minX > s.desktop.maxX)
    s.expectNothingLeftBehind()
  }

  @Test func floatingWindowsComeIntoViewWithTheDesktopAndGoOutAgain() {
    // Floating windows that make way: only they leave with the Desktop.
    let s = DragScene {
      $0.reflowWhileDragging = true
      $0.floatingWindowsMakeWay = true
    }
    s.h.run("zoom \(s.a.rawValue)")
    let before = s.outcome
    #expect(!s.h.system.isVisible(s.c))

    s.h.system.beginDrag(s.a, plainly: true)
    s.h.system.moveDrag(to: CGPoint(x: s.h.system.cursor.x + 30, y: s.h.system.cursor.y + 30))
    #expect(s.h.system.isVisible(s.c), "let go now, a would leave the view it fills, which falls back to everything")
    #expect(s.h.system.isVisible(s.b))
    s.h.system.holdModifierKeys(.command)
    #expect(!s.h.system.isVisible(s.c) && !s.h.system.isVisible(s.b), "they leave again while a is still held")
    s.h.system.endDrag()
    #expect(s.outcome == before)
    s.expectNothingLeftBehind()
  }

  /// As Arbor ships, what floats never left. The same trials fetch what is docked and send it away again, and ask nothing of c.
  @Test func theTrialsThatShowTheDesktopAndLeaveItAgainTouchNothingThatFloats() {
    let s = DragScene(Self.reflow)
    s.h.run("zoom \(s.a.rawValue)")
    let before = s.outcome
    let own = s.frame(s.c)
    #expect(s.h.system.isVisible(s.c) && !s.h.system.isVisible(s.b))
    s.h.system.clearFrameLog()

    s.h.system.beginDrag(s.a, plainly: true)
    s.h.system.moveDrag(to: CGPoint(x: s.h.system.cursor.x + 30, y: s.h.system.cursor.y + 30))
    #expect(s.h.system.isVisible(s.b), "let go now, a would leave the view it fills, which falls back to everything")
    s.h.system.holdModifierKeys(.command)
    #expect(!s.h.system.isVisible(s.b), "it leaves again while a is still held")
    s.h.system.endDrag()
    #expect(s.frame(s.c) == own)
    #expect(!s.h.system.frameLog.contains { $0.window == s.c }, "Arbor set no frame on it: \(s.h.system.frameLog)")
    #expect(s.outcome == before)
    s.expectNothingLeftBehind()
  }

  @Test(.withTiles) func aWindowThatCannotShrinkToMakeRoomBecomesATileAndComesBack() {
    let s = DragScene(Self.reflow)
    s.h.system.setMinimumSize(s.b, CGSize(width: 300, height: 600))
    let before = s.outcome
    s.h.system.beginDrag(s.c)
    s.h.system.moveDrag(to: s.edge(.bottom, of: s.b), holding: 0.3)
    #expect(s.h.overlays.tiles[s.h.display]?.first?.items.first?.window == s.b)
    #expect(!s.h.system.isVisible(s.b))
    s.h.system.moveDrag(to: s.frame(s.c).center)
    s.h.system.moveDrag(to: s.inTheGap)
    #expect(s.frame(s.b) == before.frames[s.b])
    #expect(s.h.overlays.tiles[s.h.display] == [])
  }

  /// Acceptance criterion 3, for every way a drag can end: the same journey with reflow off, on,
  /// and on without `keepPushed` leaves every window and every workspace the same. (A journey ends
  /// on the same target each time. The same point can be another target with reflow, because the
  /// pointer is matched against what is on screen: `targetsAreWhatTheUserSeesOnceTheWindowHasLeft`.)
  ///
  /// As it ships, and with a column for the Desktop, where a docked window let go on the Desktop floats ("nothing").
  /// (All but one of them both ways. "nothing" ends aside of everything, and two halves have no such place: the gap between them is gone
  /// while the trial shows the one above the other.)
  /// Each with floating windows that make way too, which the trials of a drag fetch and send away.
  @Test(
    arguments: [
      "back", "nothing", "beside", "edge", "quick", "wander", "command", "across", "across-float", "zoomed-back",
      "zoomed-beside", "zoomed-out", "zoomed-edge", "zoomed-edge-back", "tab", "tab-away", "guest-edge", "guest-back",
      "beside-a-host", "framed-command", "framed-command-back",
    ].flatMap { journey in both.filter { $0 || journey != "nothing" }.flatMap { column in both.map { (journey, column, $0) } } })
  func everyJourneyEndsAsItDoesWithoutReflow(journey: String, column: Bool, makingWay: Bool) {
    func run(_ configure: (inout Settings) -> Void) -> DragScene.Outcome {
      let s = DragScene(
        settings: column ? .withDesktopColumn : Settings(),
        {
          $0.tabsEnabled = journey.hasPrefix("tab")
          $0.floatingWindowsMakeWay = makingWay
          configure(&$0)
        }, displays: [FakeWindowSystem.standardDisplay, side])
      // Where nothing is docked: the Desktop, or between two halves the gap, where a docked window let go goes back to its slot.
      let aside = column ? s.onDesktop : s.inTheGap
      let d = s.h.system.open(app: "Terminal", frame: CGRect(x: 1600, y: 100, width: 500, height: 300))
      let e = s.h.system.open(app: "Music", frame: CGRect(x: 1900, y: 300, width: 500, height: 300))
      s.h.system.cursor = CGPoint(x: 1800, y: 300)
      s.h.run("dock \(d.rawValue) left")
      s.h.system.cursor = CGPoint(x: 720, y: 450)
      let system = s.h.system
      system.tiling = .off  // the screen's edges are Arbor's only with macOS's tiling off
      let sideSlot = s.h.controller.layouts[side.id]!.windowFrames[d]!
      switch journey {
      case "back":
        system.drag(s.a, through: [s.frame(s.a).center, aside, s.edge(.top, of: s.b), s.frame(s.a).center])
      case "nothing":
        system.drag(s.a, through: [s.frame(s.a).center, s.edge(.top, of: s.b), aside])
      case "beside":
        system.drag(s.a, through: [s.frame(s.a).center, aside, s.edge(.right, of: s.b)])
      case "edge":
        system.drag(s.c, through: [s.frame(s.c).center, s.edge(.top, of: s.a), CGPoint(x: 720, y: 28)])
      case "quick":
        system.drag(s.a, through: [s.frame(s.a).center, aside, s.edge(.right, of: s.b)], holding: 0)
      case "wander":
        system.drag(
          s.c,
          through: [
            s.frame(s.c).center, CGPoint(x: 3, y: 450), s.edge(.bottom, of: s.b), CGPoint(x: 1437, y: 450),
            s.edge(.left, of: s.a), aside,
          ])
      case "command":
        system.beginDrag(s.a)
        system.moveDrag(to: s.edge(.right, of: s.b), holding: 0.3)
        system.holdModifierKeys(.command)
        system.endDrag()
      case "across":
        system.drag(
          s.a, through: [s.frame(s.a).center, aside, CGPoint(x: sideSlot.midX, y: sideSlot.maxY - 20)])
      case "across-float":
        system.drag(
          s.a,
          through: [s.frame(s.a).center, CGPoint(x: sideSlot.midX, y: sideSlot.maxY - 20), CGPoint(x: 2300, y: 600)])
      case "zoomed-back", "zoomed-beside", "zoomed-out", "zoomed-edge", "zoomed-edge-back":
        // The view is the column [a / c]: the Desktop is out of view, and with it b, and the floating windows that make way.
        let f = system.open(app: "Finder", frame: CGRect(x: 520, y: 100, width: 300, height: 200))
        s.h.run("dock \(s.c.rawValue) beside \(s.a.rawValue) bottom")
        s.h.run("zoom-node \(s.h.workspace.tree.parent(of: s.h.workspace.tree.leaf(containing: s.a)!)!.rawValue)")
        #expect(s.h.controller.parked.contains(s.b))
        #expect(s.h.controller.parked.contains(f) == makingWay)
        let own = s.frame(s.a).center
        // With reflow c fills the view once a has left, so a point can come to mean something else. The
        // last one has to mean the same either way: between a and c it is the gap, in c alone the middle.
        let nothing = CGPoint(x: s.frame(s.c).midX, y: s.frame(s.c).minY - 6)
        let screenEdge = CGPoint(x: 3, y: 450)
        let ends = [
          "zoomed-back": [own], "zoomed-beside": [s.edge(.bottom, of: s.c)], "zoomed-out": [nothing],
          "zoomed-edge": [screenEdge], "zoomed-edge-back": [screenEdge, own],
        ]
        system.drag(s.a, through: [own, s.frame(s.c).center, s.edge(.right, of: s.c)] + ends[journey]!)
      case "framed-command", "framed-command-back":
        // The view is a alone. Taken out of it, the view falls back to everything, the Desktop included.
        s.h.run("zoom \(s.a.rawValue)")
        system.beginDrag(s.a)
        system.moveDrag(to: CGPoint(x: 700, y: 300), holding: 0.3)
        system.holdModifierKeys(.command)
        system.holdDrag(for: 0.3)
        if journey == "framed-command-back" { system.holdModifierKeys([]) }
        system.endDrag()
        system.heldModifiers = []
      case "guest-edge", "guest-back", "beside-a-host":
        // The view is a alone, with a window that opened over it and stays with it (F57).
        s.h.run("zoom \(s.a.rawValue)")
        let guest = system.open(app: "Finder", frame: CGRect(x: 500, y: 300, width: 300, height: 200))
        #expect(s.h.workspace.guests?[guest] != nil)
        let screenEdge = CGPoint(x: 1437, y: 450)
        if journey == "beside-a-host" {
          // Another window comes from the other display. The guest stays in view whatever the trials show.
          system.drag(e, through: [s.frame(e).center, s.edge(.top, of: s.a), screenEdge, s.edge(.bottom, of: s.a)])
          #expect(system.isVisible(guest))
        } else {
          let end = journey == "guest-edge" ? [screenEdge] : [screenEdge, CGPoint(x: 700, y: 500)]
          system.drag(guest, through: [s.frame(guest).center, s.edge(.left, of: s.a)] + end)
          #expect((s.h.workspace.guests?[guest] != nil) == (journey == "guest-back"))
        }
      case "tab":
        system.drag(s.c, through: [s.frame(s.c).center, s.edge(.top, of: s.b), s.frame(s.b).center])
      case "tab-away":
        system.drag(s.c, through: [s.frame(s.c).center, s.frame(s.b).center, s.frame(s.a).center, aside])
      default:
        Issue.record("no such journey")
      }
      s.expectNothingLeftBehind()
      _ = e
      return s.outcome
    }
    let plain = run { _ in }
    #expect(run { $0.reflowWhileDragging = true } == plain)
    #expect(
      run {
        $0.reflowWhileDragging = true
        $0.keepPushed = false
      } == plain)
  }
}

// MARK: Pushed windows stay pushed (T08)

/// Floating windows make way here, as until Q20 (`floatingWindowsMakeWay`): as Arbor ships, the trial layouts of a drag move
/// no floating window that is in view, so none is pushed.
@Suite @MainActor struct DragKeepPushedTests {
  /// c rests in the middle of the Desktop, which has a column of its own between a and b. Another window is dragged to the top
  /// screen edge and then away: while it is at the edge the Desktop has given up its top half, which pushes c down.
  func pushAndRelease(
    _ configure: @escaping (inout Settings) -> Void
  ) -> (DragScene, rest: CGRect, pushed: CGRect, after: CGRect) {
    let s = DragScene(settings: .withDesktopColumn) {
      $0.reflowWhileDragging = true
      $0.floatingWindowsMakeWay = true
      configure(&$0)
    }
    let d = s.h.system.open(app: "Terminal", frame: CGRect(x: 600, y: 500, width: 300, height: 200))
    let rest = CGRect(x: s.desktop.minX + 10, y: 400, width: 300, height: 200)
    s.h.system.userMove(s.c, to: rest)
    s.h.system.tiling = .off  // the screen's edges are Arbor's only with macOS's tiling off
    s.h.system.beginDrag(d)
    s.h.system.moveDrag(to: CGPoint(x: 720, y: 28))
    let pushed = s.frame(s.c)
    s.h.system.moveDrag(to: CGPoint(x: 720, y: 700))
    return (s, rest, pushed, s.frame(s.c))
  }

  @Test func pushedFloatingWindowsStayPushedUntilTheDragEnds() {
    let (s, rest, pushed, after) = pushAndRelease { _ in }
    #expect(pushed.minY > rest.minY, "the window docking above pushes it down")
    #expect(after == pushed, "it stays there when the target changes")
    s.h.system.endDrag()
    #expect(s.frame(s.c) == rest, "nothing was docked, so it ends where it was")
    s.expectNothingLeftBehind()
  }

  @Test func withoutKeepPushedTheyGoBackAsSoonAsTheSpaceIsFree() {
    let (s, rest, pushed, after) = pushAndRelease { $0.keepPushed = false }
    #expect(pushed.minY > rest.minY)
    #expect(after == rest)
    s.h.system.endDrag()
    #expect(s.frame(s.c) == rest)
  }

  /// The button is up, so a docked window that something moved is put back, and only then does word come that the
  /// release was lost. A put-back places no floating windows.
  @Test func aPutBackBetweenALostReleaseAndWordOfItLeavesNoWindowPushed() {
    let (s, rest, pushed, _) = pushAndRelease { _ in }
    #expect(pushed != rest)
    s.h.system.mouseDown = false
    s.h.system.userMove(s.a, to: s.frame(s.a).offsetBy(dx: 40, dy: 0))
    s.h.scheduler.advance(by: 0.3)
    s.h.system.loseTheReleaseOfTheDrag()
    #expect(s.frame(s.c) == rest)
    s.expectNothingLeftBehind()
  }

  @Test func aPushedWindowWhoseAppDoesNotAnswerAtTheEndKeepsThePlaceItsUserGaveIt() {
    let s = DragScene(settings: .withDesktopColumn) {
      $0.reflowWhileDragging = true
      $0.floatingWindowsMakeWay = true
    }
    let rest = CGRect(x: s.desktop.minX + 10, y: 400, width: 300, height: 200)
    let slow = s.h.system.open(app: "Slow", pid: 77, frame: rest)
    s.h.system.userMove(slow, to: rest)
    s.h.system.tiling = .off  // the screen's edges are Arbor's only with macOS's tiling off
    s.h.system.beginDrag(s.c)
    s.h.system.moveDrag(to: CGPoint(x: 720, y: 28))
    let pushed = s.frame(slow)
    #expect(pushed != rest)
    s.h.system.setUnresponsive(pid: 77, true)
    s.h.system.moveDrag(to: CGPoint(x: 720, y: 700))
    s.h.system.endDrag()
    #expect(s.frame(slow) == pushed, "it could not be moved")
    #expect(s.h.controller.windows[slow]?.frame == pushed, "and Arbor knows where it is")
    s.h.system.setUnresponsive(pid: 77, false)
    s.h.scheduler.advance(by: 1)
    #expect(s.h.workspace.floating[slow] == rest, "where it was pushed to is not taken for its user's choice")
    s.h.run("relayout")
    #expect(s.frame(slow) == rest)
  }

  @Test func aPushThatTheDropConfirmsIsNotMadeTwice() {
    let s = DragScene(settings: .withDesktopColumn) {
      $0.reflowWhileDragging = true
      $0.floatingWindowsMakeWay = true
    }
    let d = s.h.system.open(app: "Terminal", frame: CGRect(x: 600, y: 500, width: 300, height: 200))
    let rest = CGRect(x: s.desktop.minX + 10, y: 400, width: 300, height: 200)
    s.h.system.userMove(s.c, to: rest)
    s.h.system.tiling = .off  // the screen's edges are Arbor's only with macOS's tiling off
    s.h.system.beginDrag(d)
    s.h.system.moveDrag(to: CGPoint(x: 720, y: 28))
    let pushed = s.frame(s.c)
    #expect(pushed != rest)
    s.h.system.clearFrameLog()
    s.h.system.endDrag()
    #expect(s.frame(s.c) == pushed)
    let moves = s.h.system.frameLog.filter { $0.window == s.c }
    #expect(moves.allSatisfy { $0.frame == pushed }, "no jump back on the way")
    #expect(s.desktop.contains(pushed))
  }
}

// MARK: Drags that end oddly

@Suite @MainActor struct DragRobustnessTests {
  /// c held over the bottom of b: with `active`, long enough to show the preview (and the trial layout).
  func holding(reflow: Bool, active: Bool) -> DragScene {
    let s = DragScene { $0.reflowWhileDragging = reflow }
    s.h.system.beginDrag(s.c)
    s.h.system.moveDrag(to: s.edge(.bottom, of: s.b), holding: active ? 0.3 : 0.05)
    #expect((s.h.overlays.preview != nil) == active)
    #expect(s.h.scheduler.pendingKeys.contains("drag-dwell") == !active)
    return s
  }

  @Test(arguments: both, both) func aCommandDuringADragLeavesNothingBehind(reflow: Bool, active: Bool) {
    for command in ["float-all", "arrange", "zoom 102", "desktop", "relayout", "float 102", "dock 103 left"] {
      let s = holding(reflow: reflow, active: active)
      let held = s.frame(s.c)
      #expect(s.h.run(command).ok, "\(command)")
      #expect(s.h.overlays.preview == nil, "\(command): what the preview promised may no longer be true")
      #expect(!s.h.scheduler.pendingKeys.contains("drag-dwell"), "\(command)")
      #expect(s.frame(s.c) == held, "\(command): the dragged window stays in the hand")
      s.h.system.endDrag()
      s.expectNothingLeftBehind()
      #expect(s.h.workspace.tree.invariantViolations().isEmpty, "\(command)")
    }
  }

  /// The command leaves it in the hand, at its slot's size. What it owes the window (F48) is paid when it is let go.
  @Test(arguments: ["float 101", "toggle-float 101", "float-all"], both)
  func aWindowFloatedByCommandWhileInTheHandTakesItsOwnSizeWhenLetGo(command: String, lost: Bool) {
    let s = DragScene()
    let pointer = s.inTheGap
    s.h.system.beginDrag(s.a)
    s.h.system.moveDrag(to: pointer, holding: 0.3)
    let held = s.frame(s.a)
    #expect(s.h.run(command).ok)
    #expect(s.frame(s.a) == held, "it stays in the hand")
    if lost { s.h.system.loseTheReleaseOfTheDrag() } else { s.h.system.endDrag() }
    #expect(s.h.workspace.isFloating(s.a))
    #expect(s.frame(s.a).size == CGSize(width: 600, height: 400), "the size it had before it was docked")
    #expect(s.frame(s.a).contains(pointer), "under the pointer")
    #expect(s.h.workspace.floating[s.a] == s.frame(s.a))
    s.expectNothingLeftBehind()
  }

  /// Whether or not it changes size as it is let go: with its own size the same as its slot's, or none remembered.
  @Test func aWindowTakenOutWithTheDesktopOutOfViewBelongsToThatViewThoughItKeepsItsSize() {
    /// The view is the column [a / c].
    func column(_ s: DragScene) {
      s.h.run("dock \(s.c.rawValue) beside \(s.a.rawValue) bottom")
      s.h.run("zoom-node \(s.h.workspace.tree.parent(of: s.h.workspace.tree.leaf(containing: s.a)!)!.rawValue)")
    }
    let rehearsal = DragScene()
    column(rehearsal)
    // Before it was docked, a happened to have the size its slot has in this view.
    let s = DragScene()
    s.h.run("float \(s.a.rawValue)")
    s.h.system.userMove(s.a, to: CGRect(origin: CGPoint(x: 12, y: 37), size: rehearsal.frame(rehearsal.a).size))
    s.h.run("dock \(s.a.rawValue) left")
    column(s)
    #expect(s.h.workspace.undockedFrame(of: s.a)?.size == s.frame(s.a).size)
    s.h.system.drag(s.a, through: [s.frame(s.a).center, CGPoint(x: s.frame(s.a).midX + 30, y: s.frame(s.a).midY + 30)], plainly: true)
    #expect(s.h.workspace.isFloating(s.a))
    #expect(s.h.workspace.guests?[s.a] != nil)
    s.h.run("show-all")
    s.h.run("back")
    #expect(s.h.system.isVisible(s.a), "it comes back with the view it was left over")
  }

  /// What trials learn about a window's size goes with the drag, but not what a real layout has gone by meanwhile.
  @Test(.withTiles) func aMinimumSizeThatARealLayoutWentByDuringTheDragIsKept() {
    let s = DragScene { $0.reflowWhileDragging = true }
    s.h.system.setMinimumSize(s.b, CGSize(width: 300, height: 600))
    s.h.system.beginDrag(s.c)
    s.h.system.moveDrag(to: s.edge(.bottom, of: s.b), holding: 0.3)
    #expect(s.h.overlays.tiles[s.h.display]?.first?.items.first?.window == s.b, "it refused the trial's slot")
    // A real layout in which it is short of room as well.
    let d = s.h.system.open(app: "Terminal")
    s.h.run("dock \(d.rawValue) beside \(s.b.rawValue) bottom")
    s.h.system.endDrag()
    s.h.scheduler.runPending()
    #expect(s.h.staleLayouts().isEmpty, "\(s.h.staleLayouts())")
    s.expectNothingLeftBehind()
  }

  @Test(arguments: both) func afterACommandTheTargetHasToBeHeldAgain(reflow: Bool) {
    let s = holding(reflow: reflow, active: true)
    s.h.run("relayout")
    s.h.system.moveDrag(to: s.edge(.bottom, of: s.b))
    #expect(s.h.overlays.preview == nil)
    s.h.system.holdDrag(for: 0.16)
    #expect(s.h.overlays.preview != nil)
    s.h.system.endDrag()
    #expect(s.h.workspace.isDocked(s.c))
    s.expectNothingLeftBehind()
  }

  @Test(arguments: both, both) func closingTheDraggedWindowEndsTheDrag(reflow: Bool, active: Bool) {
    let s = holding(reflow: reflow, active: active)
    let slotB = s.h.layout!.windowFrames[s.b]!
    s.h.system.close(s.c)
    s.expectNothingLeftBehind()
    #expect(s.frame(s.b) == slotB)
    #expect(!s.h.workspace.contains(s.c))
    // A mouse-up that still arrives finds nothing to do.
    s.h.system.mouseDown = false
    s.h.controller.dragEnded(s.c, at: s.h.system.cursor)
    s.expectNothingLeftBehind()
    #expect(!s.h.workspace.contains(s.c))
  }

  @Test(arguments: both, both) func closingTheTargetWindowForgetsTheTarget(reflow: Bool, active: Bool) {
    let s = holding(reflow: reflow, active: active)
    s.h.system.close(s.b)
    #expect(s.h.overlays.preview == nil)
    #expect(!s.h.scheduler.pendingKeys.contains("drag-dwell"))
    s.h.system.endDrag()
    #expect(s.h.workspace.isFloating(s.c))
    #expect(s.h.workspace.tree.allWindows == [s.a])
    s.expectNothingLeftBehind()
  }

  @Test(arguments: both, both) func aDisplayThatDisappearsMidDragTakesItsTargetWithIt(reflow: Bool, active: Bool) {
    // With a column for the Desktop: that is where a is let go in the end, to float.
    let s = DragScene(
      settings: .withDesktopColumn, { $0.reflowWhileDragging = reflow }, displays: [FakeWindowSystem.standardDisplay, side])
    let d = s.h.system.open(app: "Terminal", frame: CGRect(x: 1600, y: 100, width: 500, height: 300))
    let e = s.h.system.open(app: "Music", frame: CGRect(x: 2000, y: 100, width: 500, height: 300))
    s.h.system.cursor = CGPoint(x: 1800, y: 300)
    s.h.run("dock \(d.rawValue) left")
    let slot = s.h.controller.layouts[side.id]!.windowFrames[d]!
    // a leaves the main display and is held over d on the other one.
    s.h.system.beginDrag(s.a)
    s.h.system.moveDrag(to: CGPoint(x: slot.midX, y: slot.maxY - 20), holding: active ? 0.3 : 0.05)
    #expect((s.h.overlays.preview != nil) == active)

    s.h.system.setDisplays([FakeWindowSystem.standardDisplay])
    #expect(s.h.overlays.preview == nil)
    #expect(!s.h.scheduler.pendingKeys.contains("drag-dwell"))
    s.h.system.moveDrag(to: s.onDesktop)
    s.h.system.endDrag()
    s.expectNothingLeftBehind()
    #expect(s.h.workspace.isFloating(s.a))
    for window in [s.a, s.b, s.c, d, e] { #expect(s.h.system.isVisible(window), "\(window)") }
  }

  /// Unplugged, or the lid of the laptop it hangs on closed, with a window in the hand. macOS may leave it where it was.
  @Test(arguments: both, both) func aFloatingWindowLetGoWhereADisplayWasComesIntoView(pinned: Bool, lost: Bool) {
    let s = DragScene(displays: [FakeWindowSystem.standardDisplay, side])
    if pinned { s.h.run("pin \(s.c.rawValue)") }
    s.h.system.beginDrag(s.c)
    s.h.system.moveDrag(to: CGPoint(x: 2100, y: 300), holding: 0.3)
    s.h.system.setDisplays([FakeWindowSystem.standardDisplay])
    #expect(!s.h.system.isVisible(s.c), "it stays in the hand")
    if lost { s.h.system.loseTheReleaseOfTheDrag() } else { s.h.system.endDrag() }
    #expect(FakeWindowSystem.standardDisplay.visibleFrame.contains(s.frame(s.c)), "\(s.frame(s.c))")
    #expect(s.h.workspace.floating[s.c] == s.frame(s.c), "beyond the display that is left is not at its edge: it floats")
    #expect(s.h.workspace.isPinned(s.c) == pinned)
    s.expectNothingLeftBehind()
  }

  /// Arbor leaves the window in the hand alone, and the hand brings back at once what Arbor moves all the same.
  @Test(arguments: both, both) func aSummonedWindowSentAwayWhileInTheHandGoesWhenItIsLetGo(byItsKey: Bool, lost: Bool) {
    let s = DragScene()
    s.h.system.userFocus(s.a)
    s.h.run("summon Mail")
    let middle = s.frame(s.b).center  // nothing docks there
    s.h.system.beginDrag(s.c)
    s.h.system.moveDrag(to: middle, holding: 0.3)
    if byItsKey { s.h.run("summon Mail") } else { s.h.system.userFocus(s.b) }
    s.h.system.moveDrag(to: CGPoint(x: middle.x - 20, y: middle.y - 20), holding: 0.3)
    #expect(s.h.system.isVisible(s.c), "it is in the hand")
    if lost { s.h.system.loseTheReleaseOfTheDrag() } else { s.h.system.endDrag() }
    #expect(s.h.workspace.isStashed(s.c))
    #expect(s.h.controller.parked.contains(s.c))
    #expect(!s.h.system.isVisible(s.c), "\(s.frame(s.c))")
    s.expectNothingLeftBehind()
    s.h.run("summon Mail")
    #expect(s.h.system.isVisible(s.c))
  }

  @Test(arguments: ["summon Mail", "pin c"], both) func aWindowATrialBroughtInAndACommandGaveARoleStaysWhereThatPutIt(
    command: String, lost: Bool
  ) {
    // Floating windows that make way: only they leave with the Desktop, for a trial to bring in.
    let s = DragScene(
      {
        $0.reflowWhileDragging = true
        $0.floatingWindowsMakeWay = true
      }, displays: [FakeWindowSystem.standardDisplay, side])
    s.h.run("zoom \(s.a.rawValue)")
    #expect(s.h.controller.parked.contains(s.c))
    s.h.system.beginDrag(s.a)
    s.h.system.moveDrag(to: CGPoint(x: 2000, y: 400), holding: 0)
    #expect(s.h.system.isVisible(s.c), "without a the view is everything, with the Desktop and what floats on it")
    s.h.run(command == "pin c" ? "pin \(s.c.rawValue)" : command)
    let placed = s.frame(s.c)
    s.h.system.moveDrag(to: CGPoint(x: 700, y: 300), holding: 0.05)
    if lost { s.h.system.loseTheReleaseOfTheDrag() } else { s.h.system.endDrag() }
    #expect(s.frame(s.c) == placed)
    #expect(!s.h.controller.parked.contains(s.c))
    s.expectNothingLeftBehind()
  }

  @Test(arguments: both, both) func aDockedWindowLetGoWhereADisplayWasGoesBackToItsSlot(reflow: Bool, lost: Bool) {
    let s = DragScene({ $0.reflowWhileDragging = reflow }, displays: [FakeWindowSystem.standardDisplay, side])
    let before = (frames: s.outcome.frames, workspace: s.h.workspace)
    s.h.system.beginDrag(s.a)
    s.h.system.moveDrag(to: CGPoint(x: 2100, y: 300), holding: 0.3)
    s.h.system.setDisplays([FakeWindowSystem.standardDisplay])
    #expect(s.h.overlays.preview == nil)
    if lost { s.h.system.loseTheReleaseOfTheDrag() } else { s.h.system.endDrag() }
    #expect(s.outcome.frames == before.frames)
    #expect(s.h.workspace == before.workspace)
    s.expectNothingLeftBehind()
  }

  @Test(arguments: both, both) func aSecondDragWithoutAnEndToTheFirstStartsClean(reflow: Bool, active: Bool) {
    let s = DragScene { $0.reflowWhileDragging = reflow }
    let before = s.outcome
    // Where c rests, which is over the gap, where nothing docks. (With live reflow it is pushed aside while a is out of its slot.)
    let grab = s.frame(s.c).center
    s.h.system.tiling = .off  // the screen's edges are Arbor's only with macOS's tiling off
    s.h.system.beginDrag(s.a)
    s.h.system.moveDrag(to: s.edge(.bottom, of: s.b), holding: active ? 0.3 : 0.05)
    // The mouse-up was lost; the next thing Arbor hears is another drag.
    s.h.system.heldModifiers = DragDocks.key
    s.h.controller.dragBegan(s.c, at: grab)
    #expect(s.outcome == before, "a is back in its slot and nothing else has moved")
    s.expectNothingLeftBehind()
    s.h.controller.dragMoved(s.a, to: s.edge(.top, of: s.b))
    s.h.scheduler.advance(by: 0.3)
    #expect(s.h.overlays.preview == nil, "word of another window's move is not about this drag")
    s.h.controller.dragEnded(s.a, at: s.edge(.top, of: s.b))
    #expect(s.outcome == before, "the first drag is over")

    s.h.controller.dragMoved(s.c, to: CGPoint(x: 3, y: 450))
    s.h.system.mouseDown = false
    s.h.controller.dragEnded(s.c, at: CGPoint(x: 3, y: 450))
    #expect(s.h.workspace.isDocked(s.c))
    s.expectNothingLeftBehind()
  }

  @Test(arguments: both, both) func aReleaseNobodySawCallsTheDragOff(reflow: Bool, active: Bool) {
    let s = holding(reflow: reflow, active: active)
    let others = [s.frame(s.a), s.h.layout!.windowFrames[s.b]!]
    s.h.scheduler.advance(by: 5)
    #expect(s.h.overlays.preview != nil, "however long the button is held, the drag goes on")
    let held = s.frame(s.c)
    s.h.system.loseTheReleaseOfTheDrag()
    #expect(s.h.workspace.isFloating(s.c), "where the pointer is by now says nothing")
    #expect(s.frame(s.c) == held)
    #expect(s.h.workspace.floating[s.c] == held, "and that is where it belongs from now on")
    #expect([s.frame(s.a), s.frame(s.b)] == others)
    s.expectNothingLeftBehind()
  }

  @Test(arguments: both, both) func aDockedWindowWhoseReleaseNobodySawGoesBackToItsSlot(reflow: Bool, active: Bool) {
    let s = DragScene { $0.reflowWhileDragging = reflow }
    let before = s.outcome
    s.h.system.beginDrag(s.a)
    s.h.system.moveDrag(to: s.edge(.bottom, of: s.b), holding: active ? 0.3 : 0.05)
    s.h.system.loseTheReleaseOfTheDrag()
    #expect(s.outcome == before)
    s.expectNothingLeftBehind()
  }

  @Test(arguments: both, both) func aNativeTabTakingOverTheDraggedWindowEndsTheDrag(reflow: Bool, active: Bool) {
    let s = DragScene { $0.reflowWhileDragging = reflow }
    s.h.system.beginDrag(s.a)
    s.h.system.moveDrag(to: s.edge(.bottom, of: s.b), holding: active ? 0.3 : 0.05)
    let tab = s.h.system.openTab(in: s.a)!
    s.expectNothingLeftBehind()
    #expect(s.h.workspace.isDocked(tab) && !s.h.workspace.contains(s.a))
    s.h.system.mouseDown = false
    s.h.controller.dragEnded(s.a, at: s.h.system.cursor)
    #expect(s.h.workspace.tree.allWindows == [tab, s.b])
    s.expectNothingLeftBehind()
  }

  /// Out of view, windows are made small, and floating windows make way: only they leave with the Desktop.
  static let smallOutOfView: (inout Settings) -> Void = {
    $0.shrinkOutOfView = true
    $0.floatingWindowsMakeWay = true
  }

  /// With `shrinkOutOfView` what is taken by its sliver is small.
  @Test(arguments: both) func aWindowMadeSmallOutOfViewHasItsOwnSizeWhenItIsDraggedBack(lost: Bool) {
    let s = DragScene(Self.smallOutOfView)
    let own = s.frame(s.c).size
    s.h.run("zoom \(s.a.rawValue)")
    #expect(s.frame(s.c).size != own)
    s.h.system.beginDrag(s.c)
    s.h.system.moveDrag(to: CGPoint(x: 700, y: 400), holding: 0.3)
    if lost { s.h.system.loseTheReleaseOfTheDrag() } else { s.h.system.endDrag() }
    #expect(s.frame(s.c).size == own)
    #expect(s.frame(s.c).contains(CGPoint(x: 700, y: 400)), "under the pointer")
    #expect(s.h.workspace.floating[s.c] == s.frame(s.c))
    s.h.run("show-all")
    #expect(s.frame(s.c).size == own)
    s.expectNothingLeftBehind()
    expectWindowsMatchLayout(s.h)
  }

  /// Let go where macOS tiles, it is macOS's, which is about to give it a frame: Arbor keeps its hands off. What it owed the window it has
  /// paid by then: the press on what shows of it gives it the keyboard, and what has the keyboard comes into view at its own size.
  @Test func letGoWhereMacOSTilesAWindowMadeSmallIsLeftToMacOS() {
    let s = DragScene(Self.smallOutOfView)
    s.h.system.tiling = .on
    let own = s.frame(s.c).size
    s.h.run("zoom \(s.a.rawValue)")
    #expect(s.frame(s.c).size != own)
    s.h.system.beginDrag(s.c)
    #expect(s.frame(s.c).size == own)
    s.h.system.clearFrameLog()
    s.h.system.moveDrag(to: CGPoint(x: 0, y: 450), holding: 1)
    s.h.system.endDrag()
    s.h.scheduler.advance(by: 3)
    #expect(s.frame(s.c) == CGRect(x: -1, y: 25, width: 720, height: 875), "where macOS put it")
    #expect(!s.h.system.frameLog.contains { $0.window == s.c }, "Arbor set no frame on it: \(s.h.system.frameLog)")
    s.expectNothingLeftBehind()
  }

  /// A few points further in macOS does not act, and with its tiling on Arbor offers nothing along that edge either: the window
  /// floats where it is let go, and nobody but Arbor is there to give it its size.
  @Test func letGoInTheBandWhereNobodyActsAWindowMadeSmallHasItsOwnSize() {
    let s = DragScene(Self.smallOutOfView)
    s.h.system.tiling = .on
    let own = s.frame(s.c).size
    s.h.run("zoom \(s.a.rawValue)")
    #expect(s.frame(s.c).size != own)
    s.h.system.beginDrag(s.c)
    s.h.system.moveDrag(to: CGPoint(x: 700, y: 400), holding: 0.3)
    s.h.system.moveDrag(to: CGPoint(x: 3, y: 450), holding: 1)
    s.h.system.endDrag()
    s.h.scheduler.advance(by: 3)
    #expect(s.h.workspace.isFloating(s.c))
    #expect(s.frame(s.c).size == own)
    s.expectNothingLeftBehind()
  }

  /// In view again and made as small by hand as it was out of view, it is as small as its person made it.
  @Test func aWindowInViewIsNotGivenAnOlderSizeWhenItIsDragged() {
    let s = DragScene(Self.smallOutOfView)
    s.h.run("zoom \(s.a.rawValue)")
    let small = s.frame(s.c).size
    s.h.run("show-all")
    #expect(s.frame(s.c).size != small)
    s.h.system.userResize(s.c, to: CGRect(origin: s.frame(s.c).origin, size: small))
    s.h.system.beginDrag(s.c)
    s.h.system.moveDrag(to: s.frame(s.b).center, holding: 0.3)  // nothing docks there
    s.h.system.endDrag()
    #expect(s.frame(s.c).size == small)
    s.expectNothingLeftBehind()
  }

  /// A window out of view shows a sliver, and Mission Control shows all of it.
  @Test(arguments: both) func aWindowDraggedBackFromOutOfViewStaysWhereItIsDropped(reflow: Bool) {
    // Floating windows that make way: only they leave with the Desktop.
    let s = DragScene {
      $0.reflowWhileDragging = reflow
      $0.floatingWindowsMakeWay = true
    }
    s.h.run("zoom \(s.a.rawValue)")
    #expect(s.h.controller.parked.contains(s.c))
    s.h.system.drag(s.c, through: [s.frame(s.c).center, CGPoint(x: 700, y: 400)])
    s.h.scheduler.runPending()
    #expect(s.frame(s.c).contains(CGPoint(x: 700, y: 400)))
    #expect(!s.h.controller.parked.contains(s.c))
    s.h.run("relayout")
    #expect(s.frame(s.c).contains(CGPoint(x: 700, y: 400)), "and the next layout leaves it there")
  }

  @Test(arguments: both, both) func quittingDuringADragLeavesEveryWindowVisible(reflow: Bool, active: Bool) {
    let s = holding(reflow: reflow, active: active)
    s.h.controller.shutdown()
    #expect(!s.h.scheduler.pendingKeys.contains { $0.hasPrefix("drag") })
    #expect(s.h.overlays.preview == nil)
    let held = s.frame(s.c)
    for window in [s.a, s.b] { #expect(s.h.system.isVisible(window)) }
    s.h.system.endDrag()
    s.h.scheduler.runPending()
    #expect(s.h.overlays.preview == nil)
    #expect(s.frame(s.c) == held, "the user still had hold of it")
  }

  @Test(arguments: both, both) func pausingDuringADragEndsIt(reflow: Bool, active: Bool) {
    let s = holding(reflow: reflow, active: active)
    #expect(s.h.run("pause").ok)
    #expect(!s.h.scheduler.pendingKeys.contains { $0.hasPrefix("drag") })
    #expect(s.h.overlays.preview == nil)
    s.h.system.endDrag()
    s.h.scheduler.runPending()
    #expect(s.h.overlays.preview == nil)
    #expect(s.h.run("resume").ok)
    #expect(s.h.workspace.isFloating(s.c))
    #expect(s.h.workspace.tree.allWindows == [s.a, s.b])
    s.expectNothingLeftBehind()
  }

  @Test(arguments: both) func draggingAWindowArborDoesNotArrangeDoesNothing(reflow: Bool) {
    let s = DragScene {
      $0.reflowWhileDragging = reflow
      $0.excludedBundleIDs = ["com.example.mail"]
    }
    s.h.system.beginDrag(s.c)
    s.h.system.moveDrag(to: CGPoint(x: 720, y: 28), holding: 0.3)
    s.h.system.endDrag()
    #expect(s.h.overlays.previewHistory.allSatisfy { $0 == nil })
    #expect(s.h.system.frameLog.isEmpty)
    #expect(!s.h.workspace.contains(s.c))
  }

  @Test(arguments: both) func excludingTheAppOfTheDraggedWindowLetsGoOfIt(reflow: Bool) {
    let s = holding(reflow: reflow, active: true)
    s.h.run("exclude com.example.mail")
    s.h.system.endDrag()
    #expect(!s.h.workspace.contains(s.c))
    s.expectNothingLeftBehind()
  }

  @Test(arguments: both) func theDraggedWindowStaysInTheHandWhileTheCameraMoves(reflow: Bool) {
    let s = DragScene { $0.reflowWhileDragging = reflow }
    s.h.system.tiling = .off  // the screen's edges are Arbor's only with macOS's tiling off
    s.h.system.beginDrag(s.a)
    s.h.system.moveDrag(to: s.inTheGap, holding: 0.3)
    let held = s.frame(s.a)
    s.h.run("zoom \(s.b.rawValue)")
    #expect(s.frame(s.a) == held)
    #expect(!s.h.controller.parked.contains(s.a))
    // Dropped at the edge of the new view, it docks beside b there.
    s.h.system.moveDrag(to: CGPoint(x: 3, y: 450))
    s.h.system.endDrag()
    #expect(s.frame(s.a).maxX < s.frame(s.b).minX)
    s.expectNothingLeftBehind()
  }

  @Test(arguments: both) func turningReflowOffMidDragPutsEverythingBack(reflow: Bool) {
    let s = holding(reflow: true, active: true)
    var settings = s.h.controller.settings
    settings.reflowWhileDragging = reflow
    s.h.controller.apply(settings: settings)
    s.h.system.moveDrag(to: s.inTheGap)
    s.h.system.endDrag()
    s.expectNothingLeftBehind()
    #expect(s.h.workspace.isFloating(s.c))
  }
}

// MARK: Against every other feature

/// A drag that comes to nothing (let go too early, let go where nothing is previewed, its release lost) leaves things as
/// they were, whatever else is going on: pins, a summoned window, a held or framed view, names, tiles, automatic docking.
@Suite @MainActor struct DragsThatComeToNothingTests {
  nonisolated static let states: [[String]] = [
    [], ["pin c"], ["focus a", "summon Mail"], ["zoom a"], ["zoom b"], ["hold"], ["hold still"], ["zoom a", "hold"],
    ["set soleFloatTakesDesktop true"], ["zoom b", "name work", "home"], ["toggle-auto-dock"], ["desktop", "back"],
    ["set makeRoom false", "min b"], ["set makeRoom true", "min b"], ["min a", "min b", "relayout"], ["save-view 1"], ["float c", "dock c beside b bottom"],
    ["dock c beside b bottom", "zoom c", "out", "name pair", "hold"], ["pin c", "zoom a"], ["set gap 24"],
    ["set tabsEnabled true"], ["set tabsEnabled true", "layout [Safari Mail] | Desktop | Notes"],
  ]
  enum Ending: CaseIterable { case early, nowhere, lost, lostEarly }

  static func scene(_ state: [String], reflow: Bool) -> DragScene {
    let s = DragScene { $0.reflowWhileDragging = reflow }
    let names = ["a": s.a, "b": s.b, "c": s.c]
    for line in state {
      let words = line.split(separator: " ").map { word in names[String(word)].map { "\($0.rawValue)" } ?? String(word) }
      switch words[0] {
      case "focus": s.h.system.userFocus(WindowID(UInt32(words[1])!))
      case "min":
        // Its app makes it larger, as an app whose window has become too small does.
        let window = WindowID(UInt32(words[1])!)
        s.h.system.setMinimumSize(window, CGSize(width: 1000, height: 700))
        s.h.system.userMove(window, to: CGRect(origin: s.frame(window).origin, size: CGSize(width: 1000, height: 700)))
        s.h.scheduler.runPending()
      default: s.h.run(words.joined(separator: " "))
      }
    }
    s.h.scheduler.runPending()
    return s
  }

  /// What the press alone makes of a scene. Whoever takes hold of a window gives it the keyboard before anything is dragged, and a
  /// summoned window leaves when the keyboard does. A drag that comes to nothing changes nothing beyond that.
  static func afterAPress(on window: WindowID, _ state: [String], reflow: Bool) -> DragScene.Outcome {
    let s = scene(state, reflow: reflow)
    s.h.system.userClick(window)
    s.h.scheduler.runPending()
    return s.outcome
  }

  @Test(arguments: states, both) func nothingChanges(state: [String], reflow: Bool) {
    // With tab groups the middle of a window is a place to drop.
    for ending in Ending.allCases where ending != .nowhere || !state.contains("set tabsEnabled true") {
      for docked in 0..<2 {
        let s = Self.scene(state, reflow: reflow)
        let window = [s.a, s.b][docked]
        let other = [s.b, s.a][docked]
        guard let slot = s.h.layout!.windowFrames[window], s.h.workspace.isDocked(window) else { continue }
        let said = "\(state) \(ending) \(docked == 0 ? "a" : "b")"
        // The middle of another window if one is in view, or else of its own slot.
        let nowhere = (s.h.layout!.windowFrames[other] ?? slot).center
        let edge = s.h.layout!.windowFrames[other].map { CGPoint(x: $0.midX, y: $0.maxY - 20) } ?? nowhere
        let before = Self.afterAPress(on: window, state, reflow: reflow)
        s.h.system.beginDrag(window)
        switch ending {
        case .early:
          s.h.system.moveDrag(to: edge, holding: 0.05)
          s.h.system.endDrag()
        case .nowhere:
          s.h.system.moveDrag(to: edge, holding: 0.3)
          // With live reflow the other window is not where it was once the dragged one has left the arrangement: what was lent to
          // that one has gone back (F61). Its middle is where it is then.
          s.h.system.moveDrag(to: nowhere)
          let middle = reflow && s.h.layout!.windowFrames[other] != nil ? s.frame(other).center : nowhere
          s.h.system.moveDrag(to: middle, holding: 0.3)
          s.h.system.endDrag()
        case .lost:
          s.h.system.moveDrag(to: edge, holding: 0.3)
          s.h.system.loseTheReleaseOfTheDrag()
        case .lostEarly:
          s.h.system.moveDrag(to: edge, holding: 0.05)
          s.h.system.loseTheReleaseOfTheDrag()
        }
        s.h.scheduler.runPending()
        let after = s.outcome
        if after.frames != before.frames {
          let moved = before.frames.filter { after.frames[$0.key] != $0.value }.map { "\($0.key): \($0.value) → \(String(describing: after.frames[$0.key]))" }
          Issue.record("\(said): windows are elsewhere: \(moved)")
        }
        if after.parked != before.parked { Issue.record("\(said): out of view were \(before.parked), are \(after.parked)") }
        if after.workspaces != before.workspaces { Issue.record("\(said): what Arbor remembers has changed") }
        if !s.h.staleLayouts().isEmpty { Issue.record("\(said): \(s.h.staleLayouts())") }
        if s.h.overlays.preview != nil { Issue.record("\(said): a preview is left") }
      }
    }
  }

  /// Held anywhere, in any of those states: the window lands where the preview was, or, with no preview, a docked window
  /// goes back and a floating one stays under the pointer; nothing that was in view is lost from it.
  /// (Not where a window will turn out not to fit: how low it can go, Arbor learns by asking.)
  @Test(arguments: states.filter { !$0.contains("min b") }, both) func thePreviewIsAPromise(state: [String], reflow: Bool) {
    let probe = Self.scene(state, reflow: reflow)
    let visible = FakeWindowSystem.standardDisplay.visibleFrame
    var points: [CGPoint] = []
    for x in stride(from: visible.minX + 3, through: visible.maxX - 3, by: (visible.width - 6) / 8) {
      for y in stride(from: visible.minY + 3, through: visible.maxY - 3, by: (visible.height - 6) / 6) { points.append(CGPoint(x: x, y: y)) }
    }
    for window in [probe.a, probe.b, probe.c] where probe.h.system.isVisible(window) {
      let before = Self.afterAPress(on: window, state, reflow: reflow)
      for point in points {
        let s = Self.scene(state, reflow: reflow)
        let said = "\(state) \(window) held at \(Int(point.x)),\(Int(point.y))"
        let wasDocked = s.h.workspace.isDocked(window)
        s.h.system.beginDrag(window)
        s.h.system.moveDrag(to: point, holding: 0.3)
        let promised = s.h.overlays.preview
        s.h.system.endDrag()
        s.h.scheduler.runPending()
        let frame = s.frame(window)
        if let promised {
          if !frame.approximatelyEquals(promised, tolerance: 1), s.h.layout!.windowFrames[window] != nil {
            Issue.record("\(said): promised \(promised), is at \(frame)")
          }
          if !s.h.workspace.isDocked(window) { Issue.record("\(said): a preview, and it is not docked") }
        } else if wasDocked, s.h.workspace.isDocked(window) {
          if s.outcome != before { Issue.record("\(said): nothing was promised, it is docked as before, and something has changed") }
        } else if s.h.workspace.isDocked(window) {
          Issue.record("\(said): docked without a preview")
        } else if s.h.controller.parked.contains(window) || frame.intersection(visible).isEmpty {
          Issue.record("\(said): let go in view, it is at \(frame)")
        }
        for other in before.frames.keys where other != window && !s.h.system.isVisible(other) && s.h.layout!.camera == probe.h.layout!.camera {
          if s.h.layout!.tiles.contains(where: { s.h.workspace.tree.windows(under: $0.node).contains(other) }) { continue }
          // Behind it, in the tab group it was dropped on.
          if let group = s.h.workspace.tree.leaf(containing: window), group == s.h.workspace.tree.leaf(containing: other) { continue }
          Issue.record("\(said): \(other) was in view and is not")
        }
        if !s.h.staleLayouts().isEmpty { Issue.record("\(said): \(s.h.staleLayouts())") }
        if s.h.overlays.preview != nil { Issue.record("\(said): a preview is left") }
      }
    }
  }
}
