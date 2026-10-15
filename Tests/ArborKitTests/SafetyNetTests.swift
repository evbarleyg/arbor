import ArborCore
import ArborKit
import ArborTesting
import CoreGraphics
import Testing

/// Lines of the controller that `scripts/mutate.py` could break on 2026-10-14 without any test noticing, where a
/// user would have noticed.
@Suite @MainActor struct SafetyNetTests {
  static let side = DisplaySnapshot(
    id: DisplayID("side"), frame: CGRect(x: 1440, y: 0, width: 1280, height: 800),
    visibleFrame: CGRect(x: 1440, y: 25, width: 1280, height: 775), isMain: false)

  func makeHarness(
    displays: [DisplaySnapshot] = [FakeWindowSystem.standardDisplay], settings: Settings = Settings()
  ) -> (Harness, WindowID, WindowID, WindowID) {
    let h = Harness(displays: displays, settings: settings)
    let a = h.system.open(app: "Safari", frame: CGRect(x: 100, y: 100, width: 600, height: 400))
    let b = h.system.open(app: "Notes", frame: CGRect(x: 300, y: 200, width: 600, height: 400))
    let c = h.system.open(app: "Mail", frame: CGRect(x: 500, y: 300, width: 600, height: 400))
    h.start()
    return (h, a, b, c)
  }

  func titleBar(_ h: Harness, _ window: WindowID) -> CGPoint {
    let frame = h.frame(window)!
    return CGPoint(x: frame.midX, y: frame.minY + 10)
  }

  // MARK: Nothing is forgotten

  /// A crash or a power cut must not cost more than the last half second.
  @Test func everythingThatChangesTheArrangementIsSaved() {
    let (h, a, b, c) = makeHarness()
    func expectSave(_ what: String, _ change: () -> Void, sourceLocation: SourceLocation = #_sourceLocation) {
      h.scheduler.runPending()
      #expect(!h.scheduler.pendingKeys.contains("save"), sourceLocation: sourceLocation)
      let before = h.store.saved
      change()
      #expect(h.scheduler.pendingKeys.contains("save"), "\(what) schedules no save", sourceLocation: sourceLocation)
      h.scheduler.runPending()
      #expect(h.store.saved != before, "\(what) changed nothing that is saved", sourceLocation: sourceLocation)
    }
    expectSave("docking at an edge") { h.run("dock \(a.rawValue) left") }
    expectSave("docking at the other edge") { h.run("dock \(b.rawValue) right") }
    expectSave("docking beside a window") { h.run("dock \(c.rawValue) beside \(a.rawValue) bottom") }
    expectSave("trading places") { h.run("dock \(c.rawValue) up") }
    expectSave("stepping out of a column") { h.run("dock \(c.rawValue) right") }
    expectSave("resizing") { h.run("resize \(a.rawValue) right 50") }
    expectSave("dragging a seam") { h.overlays.dragSeam(h.overlays.seams[h.display]![0], by: 20) }
    expectSave("moving the camera") { h.run("zoom \(a.rawValue)") }
    expectSave("going back") { h.run("back") }
    expectSave("going forward") { h.run("forward") }
    expectSave("saving a view") { h.run("save-view 1") }
    expectSave("showing everything") { h.run("show-all") }
    expectSave("floating a window") { h.run("float \(c.rawValue)") }
    expectSave("moving a floating window") {
      h.system.userMove(c, to: h.layout!.desktopFrame!.insetBy(dx: 30, dy: 200))
    }
    expectSave("a drag that docks") { h.system.drag(c, through: [titleBar(h, c), CGPoint(x: 720, y: 897)]) }
    expectSave("a new window") { _ = h.system.open(app: "Terminal") }
    expectSave("a window closing") { h.system.close(c) }
    expectSave("arranging") { h.run("arrange") }
    expectSave("floating everything") { h.run("float-all") }
  }

  // MARK: Keyboard docking

  @Test func aWindowThatFillsTheViewCannotBeMovedWithinIt() {
    let (h, a, b, _) = makeHarness()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) right")
    h.run("zoom \(a.rawValue)")
    let tree = h.workspace.tree
    let result = h.run("dock \(a.rawValue) right")
    #expect(!result.ok && result.message.contains("step out"))
    #expect(h.workspace.tree == tree)
  }

  @Test func keyboardDockWorksUpAndDownToo() {
    let (h, a, b, c) = makeHarness()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) right")
    h.run("dock \(c.rawValue) beside \(a.rawValue) bottom")
    // [a / c]: c trades places with a, and back.
    #expect(h.run("dock \(c.rawValue) up").ok)
    #expect(h.frame(c)!.maxY < h.frame(a)!.minY)
    #expect(h.run("dock \(c.rawValue) down").ok)
    #expect(h.frame(a)!.maxY < h.frame(c)!.minY)
    // b has nothing above it in its column: it becomes the top of everything in view.
    #expect(h.run("dock \(b.rawValue) up").ok)
    let content = h.visibleFrame.insetBy(dx: 12, dy: 12)
    #expect(h.frame(b)!.minY == content.minY && h.frame(b)!.width == content.width)
    #expect(h.frame(a)!.minY > h.frame(b)!.maxY)
    #expect(!h.run("dock \(b.rawValue) up").ok, "it is already there")
    expectWindowsMatchLayout(h, on: h.display)
    #expect(h.workspace.tree.invariantViolations().isEmpty)
  }

  @Test func steppingOutOfAColumnLandsOnTheNearSideOfWhatIsBeyond() {
    let (h, a, b, c) = makeHarness()
    h.run("dock \(a.rawValue) top")
    h.run("dock \(b.rawValue) bottom")
    h.run("dock \(c.rawValue) beside \(a.rawValue) right")
    // root(v)[ row(h)[a, c], Desktop, b ]: c steps down, out of the row, to sit above the Desktop.
    #expect(h.run("dock \(c.rawValue) down").ok)
    let tree = h.workspace.tree
    #expect(tree.children(of: tree.root).map { tree.windows(under: $0) } == [[a], [c], [], [b]])
    #expect(h.run("dock \(c.rawValue) up").ok)
    #expect(h.workspace.tree.children(of: h.workspace.tree.root).first.map { h.workspace.tree.windows(under: $0) } == [c])
  }

  // MARK: The camera

  @Test func arrangingStartsAFreshHistory() {
    let (h, a, b, _) = makeHarness()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) right")
    h.run("zoom \(a.rawValue)")
    h.run("save-view 1")
    #expect(h.run("arrange").ok)
    // Everything is in view at once, side by side.
    #expect(h.layout?.windowFrames.count == 3 && h.controller.parked.isEmpty)
    let frames = h.layout!.windowFrames.keys.sorted().map { h.frame($0)! }
    for (index, frame) in frames.enumerated() {
      #expect(h.visibleFrame.contains(frame))
      for other in frames[(index + 1)...] { #expect(!frame.overlaps(other)) }
    }
    expectWindowsMatchLayout(h, on: h.display)
    // The places history and views pointed at belong to a tree that no longer exists.
    #expect(h.workspace.camera == h.workspace.tree.root)
    #expect(!h.run("back").ok && !h.run("forward").ok && !h.run("view 1").ok)
  }

  @Test func framingAFloatingWindowShowsTheDesktopItLivesOn() {
    let (h, a, _, c) = makeHarness()
    h.run("dock \(a.rawValue) left")
    h.run("zoom \(a.rawValue)")
    #expect(!h.system.isVisible(c))
    #expect(h.run("zoom \(c.rawValue)").ok)
    #expect(h.workspace.camera == h.workspace.tree.desktop)
    #expect(h.system.isVisible(c) && !h.system.isVisible(a))
    #expect(h.system.focused == c)
  }

  @Test func revealingAWindowZoomsOutJustFarEnough() {
    let (h, a, b, c) = makeHarness()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) right")
    h.run("dock \(c.rawValue) beside \(a.rawValue) bottom")
    let d = h.system.open(app: "Mail")
    h.run("dock \(d.rawValue) beside \(c.rawValue) right")
    let tree = h.workspace.tree
    // The view is on a group, the row of c and d. (From a single window the level is kept: FocusTests.)
    h.run("zoom \(c.rawValue)")
    h.run("out")
    #expect(h.workspace.camera == tree.parent(of: tree.leaf(containing: c)!))
    h.system.userFocus(a)  // above the row, in the same column
    #expect(h.workspace.camera == tree.parent(of: tree.leaf(containing: a)!), "the column, not everything")
    #expect(h.system.isVisible(a) && h.system.isVisible(c) && !h.system.isVisible(b))
    h.system.userFocus(b)
    #expect(h.workspace.camera == tree.root)
  }

  @Test func revealingAWindowThatWouldBeATileFramesIt() {
    let (h, a, b, _) = makeHarness()
    // More than its neighbour and the Desktop could spare between them (F61).
    h.system.setMinimumSize(b, CGSize(width: 1200, height: 600))
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) right")
    #expect(h.overlays.tiles[h.display]?.count == 1)
    h.system.userFocus(b)  // ⌘` to it: a tile cannot take the keyboard
    #expect(h.workspace.camera == h.workspace.tree.leaf(containing: b))
    #expect(h.system.isVisible(b))
  }

  // MARK: Focus

  @Test func keyboardFocusLeavesAWindowThatGoesOutOfView() {
    let (h, a, b, c) = makeHarness()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) right")
    h.system.userFocus(a)
    // Typing must not go to a window nobody can see.
    h.run("desktop")
    #expect(h.system.focused == c, "the floating window is all there is to see")
    h.run("neighbor right")
    #expect(h.system.focused == b)
    h.run("back")
    #expect(h.system.focused == c)
    h.run("forward")
    #expect(h.system.focused == b)
    // With several in view: the one under the pointer.
    h.run("zoom \(b.rawValue)")
    h.system.setMinimized(c, true)
    h.run("show-all")
    #expect(h.system.focused == b, "it never left the view")
  }

  @Test func aMinimizedFloatingWindowIsNotGivenTheFocus() {
    let (h, a, _, c) = makeHarness()
    let b = h.workspace.floating.keys.sorted()[1]
    h.run("dock \(a.rawValue) left")
    h.system.setMinimized(b, true)
    h.system.userFocus(a)
    h.run("desktop")
    #expect(h.system.focused == c)
  }

  @Test func openingATileFocusesWhatIsInside() {
    var settings = Settings()
    settings.minimumUsableWidth = 500
    let (h, a, b, _) = makeHarness(settings: settings)
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) right")
    let tile = h.overlays.tiles[h.display]!.first { $0.items.first?.window == b }!
    // The keyboard is somewhere Arbor does not arrange (the Finder, say), so nothing else would move it.
    h.system.focused = nil
    h.overlays.clickTile(tile.node)
    #expect(h.system.focused == b)
    #expect(h.system.isVisible(b))
  }

  /// The AX layer stops reporting a drag when the dragged window closes, so no `dragEnded` follows.
  @Test func aWindowThatClosesWhileItIsDraggedLeavesNoDragBehind() {
    let (h, a, b, c) = makeHarness()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) right")
    h.system.tiling = .off  // the screen's edges are Arbor's only with macOS's tiling off
    h.controller.dragBegan(c, at: titleBar(h, c))
    h.controller.dragMoved(c, to: CGPoint(x: 3, y: 400))
    #expect(h.overlays.preview != nil)
    h.system.close(c)
    #expect(h.overlays.preview == nil)
    // Focus following is off during a drag; it has to be back on.
    h.run("zoom \(a.rawValue)")
    h.system.userFocus(b)
    #expect(h.system.isVisible(b))
  }

  @Test func focusFollowingWorksAgainAfterADrag() {
    let (h, a, b, c) = makeHarness()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) right")
    h.system.drag(c, through: [titleBar(h, c), h.layout!.desktopFrame!.center])
    h.run("zoom \(a.rawValue)")
    h.system.userFocus(b)
    #expect(h.system.isVisible(b))
  }

  // MARK: Drags

  @Test func thePreviewIsDrawnOncePerTargetNotOncePerMouseEvent() {
    let (h, a, _, c) = makeHarness()
    h.run("dock \(a.rawValue) left")
    let slot = h.frame(a)!
    let points = (0..<20).map { CGPoint(x: slot.midX + CGFloat($0), y: slot.maxY - 40) }
    h.system.drag(c, through: [titleBar(h, c)] + points)
    // One frame for the target, and nil when the drag ends.
    #expect(h.overlays.previewHistory.compactMap { $0 }.count == 1)
  }

  @Test func aFloatingWindowStaysWhereItWasDropped() {
    let (h, a, _, c) = makeHarness()
    h.run("dock \(a.rawValue) left")
    let desktop = h.layout!.desktopFrame!
    h.system.drag(c, through: [titleBar(h, c), CGPoint(x: desktop.midX + 20, y: desktop.minY + 60)])
    let dropped = h.frame(c)!
    #expect(desktop.contains(dropped))
    h.run("zoom \(a.rawValue)")
    #expect(!h.system.isVisible(c))
    h.run("back")
    #expect(h.frame(c) == dropped)
  }

  @Test func theRelayoutCommandPutsThingsRightAtOnce() {
    let (h, a, _, _) = makeHarness()
    h.run("dock \(a.rawValue) left")
    let slot = h.frame(a)!
    h.system.userMove(a, to: CGRect(x: 500, y: 300, width: 300, height: 300))
    #expect(h.run("relayout").ok)
    #expect(h.frame(a) == slot, "without waiting for the put-back timer")
  }

  // MARK: Out of view

  /// A parked window keeps one point on its own display and none on the neighbour.
  @Test func parkedWindowsDoNotShowUpOnTheDisplayNextDoor() {
    // Taller than the main display, so that its bottom-right corner is not free.
    let tall = DisplaySnapshot(
      id: DisplayID("tall"), frame: CGRect(x: 1440, y: -100, width: 1280, height: 1200),
      visibleFrame: CGRect(x: 1440, y: -75, width: 1280, height: 1175), isMain: false)
    let (t, ta, tb, tc) = makeHarness(displays: [FakeWindowSystem.standardDisplay, tall])
    // This test is about the corners Arbor asks for. macOS stops a window 32 points higher (OutOfViewTests).
    t.system.echoes.titleBarStaysReachable = false
    t.run("dock \(ta.rawValue) left")
    t.run("dock \(tb.rawValue) right")
    t.run("zoom \(ta.rawValue)")
    for window in [tb, tc] {
      let frame = t.frame(window)!
      #expect(!frame.overlaps(tall.frame), "\(window) at \(frame) shows on the other display")
      #expect(frame.maxX == 1 && frame.minY == 899, "one point in the bottom-left corner instead: \(frame)")
    }

    let (h, a, b, c) = makeHarness(displays: [FakeWindowSystem.standardDisplay, Self.side])
    h.system.echoes.titleBarStaysReachable = false
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) right")
    h.run("zoom \(a.rawValue)")
    let main = FakeWindowSystem.standardDisplay.frame
    for window in [b, c] {
      let frame = h.frame(window)!
      #expect(!frame.overlaps(Self.side.frame), "\(window) at \(frame) shows on the other display")
      #expect(frame.overlaps(main), "macOS moves windows that are wholly off screen")
      #expect(frame.intersection(main).width <= 1 && frame.intersection(main).height <= 1)
    }
    // On the right-hand display the right-hand corner is free.
    let d = h.system.open(app: "Xcode", frame: CGRect(x: 1600, y: 100, width: 600, height: 400))
    let e = h.system.open(app: "Terminal", frame: CGRect(x: 1700, y: 200, width: 600, height: 400))
    h.system.cursor = CGPoint(x: 1800, y: 300)
    h.run("dock \(d.rawValue) left")
    h.run("zoom \(d.rawValue)")
    #expect(h.frame(e)!.origin == CGPoint(x: Self.side.frame.maxX - 1, y: Self.side.frame.maxY - 1))
  }

  @Test func aWindowThatIsOnlyTooTallBecomesATileToo() {
    let (h, a, b, c) = makeHarness()
    // More than the window above it could spare (F61).
    h.system.setMinimumSize(c, CGSize(width: 100, height: 700))
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) right")
    h.run("dock \(c.rawValue) beside \(a.rawValue) bottom")
    #expect(h.overlays.tiles[h.display]?.map { $0.items.map(\.window) } == [[c]])
    #expect(!h.system.isVisible(c))
    #expect(h.system.isVisible(a), "and it does not lie over its neighbour")
    // A slot that is tall enough shows it again.
    h.run("zoom \(c.rawValue)")
    #expect(h.system.isVisible(c))
  }

  // MARK: Floating windows

  @Test func aFloatingWindowMovedToAnotherDisplayBelongsThere() {
    let (h, _, _, c) = makeHarness(displays: [FakeWindowSystem.standardDisplay, Self.side])
    let placed = CGRect(x: 1700, y: 200, width: 500, height: 300)
    h.system.userMove(c, to: placed)
    #expect(!h.workspace.contains(c))
    #expect(h.controller.workspaces[Self.side.id]!.floating[c] == placed)
    // So it leaves and returns with that display's Desktop, not with the first one's.
    let d = h.system.open(app: "Xcode", frame: CGRect(x: 1600, y: 100, width: 600, height: 400))
    h.system.cursor = CGPoint(x: 1800, y: 300)
    h.run("dock \(d.rawValue) left")
    h.run("zoom \(d.rawValue)")
    #expect(!h.system.isVisible(c))
    h.run("back")
    #expect(h.system.isVisible(c))
  }

  // MARK: Restarts

  @Test func aSavedSlotGoesOnlyToAWindowOfTheSameAppAndByTitleWhenThereIsAChoice() {
    let (h, a, _, _) = makeHarness()
    h.run("dock \(a.rawValue) left")
    h.controller.saveNow()
    let saved = h.store.saved!
    let old = h.controller.windows[a]!

    /// The windows that are docked after a restart with these titles open, out of those opened.
    func restart(app: String, bundleID: String?, titles: [String]) -> (docked: [String], harness: Harness) {
      let again = Harness(saved: saved)
      for _ in 0..<5 { again.system.open(app: "Filler") }  // so that the old number means another window
      let opened = titles.map { again.system.open(app: app, bundleID: bundleID, title: $0) }
      again.start()
      return (zip(opened, titles).filter { again.workspace.isDocked($0.0) }.map(\.1), again)
    }
    #expect(restart(app: old.appName, bundleID: old.bundleID, titles: [old.title]).docked == [old.title])
    #expect(restart(app: old.appName, bundleID: old.bundleID, titles: ["Other", old.title, "Third"]).docked == [old.title])
    // Titles rarely survive a reboot. With one slot and one window of the app there is nothing to confuse;
    // with two windows there is, and neither is guessed at (Controller+PendingSlots.swift).
    #expect(restart(app: old.appName, bundleID: old.bundleID, titles: ["Another page"]).docked == ["Another page"])
    #expect(restart(app: old.appName, bundleID: old.bundleID, titles: ["Another page", "A third"]).docked.isEmpty)
    // Another app never gets it, whatever its title. The slot waits a while, taking no space, and is dropped.
    let (docked, chrome) = restart(app: "Chrome", bundleID: "com.example.chrome", titles: [old.title])
    #expect(docked.isEmpty)
    #expect(chrome.layout?.windowFrames.isEmpty == true)
    chrome.scheduler.advance(by: Controller.pendingSlotLifetime + 1)
    #expect(chrome.workspace.tree.allWindows.isEmpty)
  }

  @Test func aSlotSurvivesTwoRebootsInARow() {
    let (h, a, _, _) = makeHarness()
    h.run("dock \(a.rawValue) left")
    h.controller.saveNow()
    let old = h.controller.windows[a]!
    var saved = h.store.saved!
    // Each time the window comes back under a new number; what identifies it has to move along.
    for fillers in [5, 9] {
      let again = Harness(saved: saved)
      for _ in 0..<fillers { again.system.open(app: "Filler") }
      let fresh = again.system.open(app: old.appName, bundleID: old.bundleID, title: old.title)
      again.start()
      #expect(again.workspace.tree.allWindows == [fresh], "after \(fillers) fillers")
      again.controller.saveNow()
      saved = again.store.saved!
    }
  }

  // MARK: Displays that were away over a reboot

  /// Two windows docked on the side display, which is then unplugged; the state as saved.
  func unpluggedState(titles: (String, String)) -> (PersistedState, [WindowSnapshot]) {
    let h = Harness(displays: [FakeWindowSystem.standardDisplay, Self.side])
    let a = h.system.open(app: "Safari", title: titles.0, frame: CGRect(x: 1500, y: 100, width: 500, height: 400))
    let b = h.system.open(app: "Safari", title: titles.1, frame: CGRect(x: 1700, y: 150, width: 500, height: 400))
    h.start()
    h.system.cursor = CGPoint(x: 2000, y: 400)
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) right")
    h.system.setDisplays([FakeWindowSystem.standardDisplay])
    h.controller.saveNow()
    return (h.store.saved!, [a, b].map { h.controller.windows[$0]! })
  }

  @Test func twoRememberedWindowsThatLookAlikeGetAWindowEach() {
    let (saved, old) = unpluggedState(titles: ("Start Page", "Start Page"))
    let again = Harness(saved: saved)
    for _ in 0..<2 { again.system.open(app: "Filler") }  // the old numbers now mean these
    let fresh = old.map { again.system.open(app: $0.appName, bundleID: $0.bundleID, title: $0.title, frame: $0.frame) }
    again.start()
    let tree = again.controller.dormant[Self.side.id]!.workspace.tree
    #expect(Set(tree.allWindows) == Set(fresh), "not the same window twice")
    #expect(tree.invariantViolations().isEmpty)
  }

  @Test func rememberedWindowsThatAreGoneAreDroppedAndAnEmptyArrangementWithThem() {
    let (saved, old) = unpluggedState(titles: ("One", "Two"))
    // Only the first comes back after the reboot.
    let partly = Harness(saved: saved)
    for _ in 0..<2 { partly.system.open(app: "Filler") }
    let one = partly.system.open(app: old[0].appName, bundleID: old[0].bundleID, title: old[0].title)
    partly.start()
    // The other's slot waits a while for its app to restore it (Controller+PendingSlots.swift).
    #expect(partly.controller.dormant[Self.side.id]?.workspace.tree.allWindows.first == one)
    partly.scheduler.advance(by: Controller.pendingSlotLifetime + 1)
    #expect(partly.controller.dormant[Self.side.id]?.workspace.tree.allWindows == [one])
    #expect(partly.controller.dormant[Self.side.id]?.workspace.tree.invariantViolations().isEmpty == true)

    let none = Harness(saved: saved)
    for _ in 0..<2 { none.system.open(app: "Filler") }
    none.start()
    none.scheduler.advance(by: Controller.pendingSlotLifetime + 1)
    #expect(none.controller.dormant.isEmpty, "nothing is left to remember")
    none.system.setDisplays([FakeWindowSystem.standardDisplay, Self.side])
    #expect(none.controller.workspaces[Self.side.id]?.allWindows.isEmpty == true)
  }

  @Test func floatingWindowsOfADisplayThatIsBackAtLaunchGoBackToIt() {
    let h = Harness(displays: [FakeWindowSystem.standardDisplay, Self.side])
    let a = h.system.open(app: "Safari", frame: CGRect(x: 1500, y: 100, width: 500, height: 400))
    let f = h.system.open(app: "Notes", frame: CGRect(x: 2100, y: 300, width: 400, height: 300))
    h.start()
    h.system.cursor = CGPoint(x: 2000, y: 400)
    h.run("dock \(a.rawValue) left")
    let floated = h.frame(f)!
    h.system.setDisplays([FakeWindowSystem.standardDisplay])
    #expect(FakeWindowSystem.standardDisplay.frame.contains(h.frame(f)!), "it waits on the main display")
    h.controller.saveNow()

    let again = Harness(displays: [FakeWindowSystem.standardDisplay, Self.side], saved: h.store.saved)
    for window in h.system.allWindows() {
      again.system.open(
        app: window.appName, bundleID: window.bundleID, title: window.title, pid: window.pid, frame: window.frame)
    }
    again.start()
    #expect(again.controller.workspaces[Self.side.id]!.isFloating(f))
    #expect(again.frame(f) == floated, "where it floated before the display went away")
  }

  // MARK: Words

  @Test func statusCountsWhatThereIs() {
    let (h, a, _, _) = makeHarness(displays: [FakeWindowSystem.standardDisplay, Self.side])
    #expect(h.run("status").message.contains("2 displays, 0 docked and 3 floating"))
    h.run("dock \(a.rawValue) left")
    #expect(h.run("status").message.contains("2 displays, 1 docked and 2 floating"))
  }
}
