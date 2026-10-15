import ArborCore
import ArborKit
import ArborTesting
import CoreGraphics
import Foundation
import Testing

/// A 1280×800 display to the right of the standard one.
private let side = DisplaySnapshot(
  id: DisplayID("side"), frame: CGRect(x: 1440, y: 0, width: 1280, height: 800),
  visibleFrame: CGRect(x: 1440, y: 0, width: 1280, height: 800), isMain: false)
/// The same, but reaching below the standard display, so that windows there park bottom-left.
private let tallSide = DisplaySnapshot(
  id: DisplayID("side"), frame: CGRect(x: 1440, y: 0, width: 1280, height: 1200),
  visibleFrame: CGRect(x: 1440, y: 0, width: 1280, height: 1200), isMain: false)
@MainActor private let main = FakeWindowSystem.standardDisplay
private let small = CGSize(width: 320, height: 200)

private func settings(_ change: (inout Settings) -> Void) -> Settings {
  var settings = Settings()
  change(&settings)
  return settings
}

/// Three floating windows, started.
@MainActor
private func makeHarness(
  _ settings: Settings = Settings(), displays: [DisplaySnapshot] = [FakeWindowSystem.standardDisplay]
) -> (Harness, WindowID, WindowID, WindowID) {
  let h = Harness(displays: displays, settings: settings)
  let a = h.system.open(app: "Safari", pid: 1001, frame: CGRect(x: 100, y: 100, width: 600, height: 400))
  let b = h.system.open(app: "Notes", pid: 1002, frame: CGRect(x: 300, y: 200, width: 610, height: 410))
  let c = h.system.open(app: "Mail", pid: 1003, frame: CGRect(x: 500, y: 300, width: 620, height: 420))
  h.start()
  return (h, a, b, c)
}

/// The same, docked as the row [a | b | c | Desktop] with equal widths.
@MainActor
private func makeRow(
  _ settings: Settings = Settings(), displays: [DisplaySnapshot] = [FakeWindowSystem.standardDisplay]
) -> (Harness, WindowID, WindowID, WindowID) {
  let (h, a, b, c) = makeHarness(settings, displays: displays)
  for window in [c, b, a] { h.run("dock \(window.rawValue) left") }
  return (h, a, b, c)
}

@MainActor
private func frames(_ h: Harness) -> [WindowID: CGRect] {
  Dictionary(uniqueKeysWithValues: h.system.allWindows().map { ($0.id, $0.frame) })
}

/// A new Arbor process that finds the windows of `old` exactly as they are now, and the state `old`
/// saved: what the watchdog's start after a crash sees. With `savingFirst` false the state is as old as the last save.
@MainActor
private func relaunchAfterCrash(
  _ old: Harness, settings: Settings = Settings(), savingFirst: Bool = true, forgetState: Bool = false
) -> Harness {
  if savingFirst { old.controller.saveNow() }
  let new = Harness(
    displays: old.system.displayList, settings: settings, saved: forgetState ? nil : old.store.saved)
  for window in old.system.allWindows() {
    new.system.open(
      app: window.appName, bundleID: window.bundleID, title: window.title, pid: window.pid, frame: window.frame)
  }
  new.controller.restartedAfterAccident = true
  new.start()
  return new
}

/// The windows and the arrangement of `old`, seen by an Arbor whose state file remembers no frames for docked
/// windows, like one written before F48. A docked window that leaves the arrangement normally gets the
/// frame it floated at. With none remembered it goes by its slot, or by its own size if it is out of view.
@MainActor
private func withNothingRemembered(_ old: Harness) -> Harness {
  old.controller.saveNow()
  func stripped(_ value: Any) -> Any {
    if let list = value as? [Any] { return list.map(stripped) }
    guard var object = value as? [String: Any] else { return value }
    object["undockedFrames"] = nil
    return object.mapValues(stripped)
  }
  let saved = try! JSONDecoder().decode(
    PersistedState.self,
    from: JSONSerialization.data(
      withJSONObject: stripped(JSONSerialization.jsonObject(with: JSONEncoder().encode(old.store.saved!)))))
  let new = Harness(displays: old.system.displayList, settings: old.controller.settings, saved: saved)
  for window in old.system.allWindows() {
    new.system.open(
      app: window.appName, bundleID: window.bundleID, title: window.title, pid: window.pid, frame: window.frame)
  }
  new.system.cursor = old.system.cursor
  new.system.focused = old.system.focused
  // It goes on where `old` was, view included, which a launch would not.
  new.controller.restartedAfterAccident = true
  new.start()
  return new
}

// MARK: previewDrags

@Suite @MainActor struct PreviewDragsTests {
  /// Drags `a` over the middle of the Desktop to the left screen edge.
  func dragToTheLeftEdge(_ h: Harness, _ a: WindowID) {
    h.system.tiling = .off  // the screen's edges are Arbor's only with macOS's tiling off
    h.system.drag(a, through: [CGPoint(x: 400, y: 110), CGPoint(x: 200, y: 300), CGPoint(x: 3, y: 450)])
  }

  @Test func withThePreviewOffNothingIsDrawnAndTheDropIsTheSame() {
    let (with, a, _, _) = makeHarness()
    let (without, _, _, _) = makeHarness(settings { $0.previewDrags = false })
    dragToTheLeftEdge(with, a)
    dragToTheLeftEdge(without, a)
    #expect(with.overlays.previewHistory.contains { $0 != nil }, "the drag passes over a target")
    #expect(without.overlays.previewHistory.allSatisfy { $0 == nil })
    #expect(without.workspace.isDocked(a))
    #expect(without.workspace == with.workspace)
    #expect(frames(without) == frames(with))
  }

  @Test func turningThePreviewOffDuringADragHidesIt() {
    let (h, a, _, _) = makeHarness()
    h.system.tiling = .off  // the screen's edges are Arbor's only with macOS's tiling off
    h.controller.dragBegan(a, at: CGPoint(x: 400, y: 110))
    h.controller.dragMoved(a, to: CGPoint(x: 3, y: 450))
    #expect(h.overlays.preview != nil)
    h.controller.apply(settings: settings { $0.previewDrags = false })
    #expect(h.overlays.preview == nil)
    h.controller.dragMoved(a, to: CGPoint(x: 1437, y: 450))
    #expect(h.overlays.preview == nil)
    h.controller.dragEnded(a, at: CGPoint(x: 1437, y: 450))
    #expect(h.workspace.isDocked(a))
  }
}

// MARK: gapHandles

@Suite @MainActor struct GapHandlesTests {
  @Test func withHandlesOffTheGapsAreNotHandles() {
    let (h, _, _, _) = makeRow(settings { $0.gapHandles = "off" })
    #expect(h.overlays.seams[h.display] == [])
    #expect(h.layout!.seams.count == 3, "the layout still knows where the seams are")
  }

  @Test func theResizeCommandStillWorksWithHandlesOff() {
    let (h, a, b, c) = makeRow(settings { $0.gapHandles = "off" })
    let before = frames(h)
    #expect(h.run("resize \(a.rawValue) right 60").ok)
    #expect(h.frame(a)!.width == before[a]!.width + 60)
    #expect(h.frame(b)!.width == before[b]!.width - 60)
    #expect(h.frame(c) == before[c])
    #expect(h.overlays.seams[h.display] == [])
  }

  @Test func draggingAWindowsOwnEdgeStillWorksWithHandlesOff() {
    let (h, a, b, _) = makeRow(settings { $0.gapHandles = "off" })
    let before = frames(h)
    var wider = before[a]!
    wider.size.width += 50
    h.system.userResize(a, to: wider)
    #expect(h.frame(a) == wider)
    #expect(h.frame(b)!.minX == before[b]!.minX + 50)
    #expect(h.frame(b)!.maxX == before[b]!.maxX)
  }

  @Test func aHandleStillBeingDraggedWhenHandlesGoOffDoesNothingMore() {
    let (h, _, _, _) = makeRow()
    let seam = h.overlays.seams[h.display]![0]
    h.controller.apply(settings: settings { $0.gapHandles = "off" })
    #expect(h.overlays.seams[h.display] == [])
    let before = frames(h)
    h.overlays.dragSeam(seam, by: 40)
    #expect(frames(h) == before)
  }

  @Test func withHandlesOffAPressInAGapIsKeptFromTheWallpaper() {
    // No panel of Arbor's takes it, and macOS would sweep every window aside (F60).
    // The guard asks where the wallpaper shows; with it off nobody is told.
    let (off, _, _, _) = makeRow(settings { ($0.gapHandles, $0.guardDesktopClicks, $0.pointerGestures) = ("off", true, true) })
    let (hidden, _, _, _) = makeRow(settings { ($0.gapHandles, $0.guardDesktopClicks, $0.pointerGestures) = ("hidden", true, true) })
    for seam in off.layout!.seams {
      #expect(off.controller.desktopGuardZones().mayBeBare(seam.frame.center))
      #expect(!hidden.controller.desktopGuardZones().mayBeBare(seam.frame.center))
    }
  }

  @Test func turningHandlesOnAgainBringsThemBack() {
    let (h, _, _, _) = makeRow(settings { $0.gapHandles = "off" })
    h.controller.apply(settings: Settings())
    #expect(h.overlays.seams[h.display] == h.layout!.seams)
    #expect(h.overlays.seams[h.display]!.count == 3)
  }

  @Test func hiddenHandlesStillWorkButAreNotDrawn() {
    let (h, a, b, _) = makeRow(settings { $0.gapHandles = "hidden" })
    #expect(h.overlays.scenes[h.display]?.showsSeamHandles == false)
    #expect(h.overlays.seams[h.display] == h.layout!.seams)
    let before = frames(h)
    h.overlays.dragSeam(h.overlays.seams[h.display]![0], by: 40)
    #expect(h.frame(a)!.width == before[a]!.width + 40)
    #expect(h.frame(b)!.width == before[b]!.width - 40)
  }

  @Test func byDefaultHandlesAreShown() {
    let (h, _, _, _) = makeRow()
    #expect(h.overlays.scenes[h.display]?.showsSeamHandles == true)
    #expect(h.overlays.seams[h.display]!.count == 3)
  }

  @Test func theFramesAreTheSameWhateverTheHandlesDo() {
    let shown = frames(makeRow().0)
    #expect(frames(makeRow(settings { $0.gapHandles = "hidden" }).0) == shown)
    #expect(frames(makeRow(settings { $0.gapHandles = "off" }).0) == shown)
  }
}

// MARK: shareRemovedSpace

@Suite @MainActor struct ShareRemovedSpaceScenarioTests {
  let keep = settings { $0.shareRemovedSpace = false }

  /// `b` has left the row: `a` took its slot and the gap between them, and nothing else moved.
  func expectOnlyTheNeighbourGrew(
    _ h: Harness, from before: [WindowID: CGRect], desktop: CGRect?, _ a: WindowID, _ b: WindowID, _ c: WindowID,
    sourceLocation: SourceLocation = #_sourceLocation
  ) {
    #expect(h.frame(c) == before[c], sourceLocation: sourceLocation)
    #expect(h.layout!.desktopFrame == desktop, sourceLocation: sourceLocation)
    #expect(h.frame(a)!.minX == before[a]!.minX, sourceLocation: sourceLocation)
    #expect(h.frame(a)!.width == before[a]!.width + before[b]!.width + 12, sourceLocation: sourceLocation)
    expectWindowsMatchLayout(h, on: h.display, sourceLocation: sourceLocation)
  }

  @Test func closingAWindowWidensOnlyTheNeighbourBeforeIt() {
    let (h, a, b, c) = makeRow(keep)
    let (before, desktop) = (frames(h), h.layout!.desktopFrame)
    h.system.close(b)
    expectOnlyTheNeighbourGrew(h, from: before, desktop: desktop, a, b, c)
  }

  @Test func closingTheFirstWindowWidensTheNeighbourAfterIt() {
    let (h, a, b, c) = makeRow(keep)
    let (before, desktop) = (frames(h), h.layout!.desktopFrame)
    h.system.close(a)
    #expect(h.frame(b)!.minX == before[a]!.minX)
    #expect(h.frame(b)!.maxX == before[b]!.maxX)
    #expect(h.frame(c) == before[c])
    #expect(h.layout!.desktopFrame == desktop)
  }

  @Test func byDefaultTheWholeRowSharesTheSpace() {
    let (h, a, b, c) = makeRow()
    let (before, desktop) = (frames(h), h.layout!.desktopFrame!)
    h.system.close(b)
    #expect(h.frame(a)!.width > before[a]!.width)
    #expect(h.frame(c)!.width == h.frame(a)!.width)
    #expect(h.layout!.desktopFrame!.width > desktop.width)
  }

  @Test func minimizingAndRestoringReturnsEveryoneToTheirWidths() {
    let (h, a, b, c) = makeRow(keep)
    let (before, desktop) = (frames(h), h.layout!.desktopFrame)
    h.system.setMinimized(b, true)
    expectOnlyTheNeighbourGrew(h, from: before, desktop: desktop, a, b, c)
    h.system.setMinimized(b, false)
    #expect(frames(h) == before)
    #expect(h.layout!.desktopFrame == desktop)
  }

  @Test func hidingAnAppAndSwitchingSpacesDoTheSame() {
    let (h, a, b, c) = makeRow(keep)
    let (before, desktop) = (frames(h), h.layout!.desktopFrame)
    h.system.setHidden(pid: 1002, true)
    expectOnlyTheNeighbourGrew(h, from: before, desktop: desktop, a, b, c)
    h.system.setHidden(pid: 1002, false)
    #expect(frames(h) == before)
    h.system.setOnActiveSpace(b, false)
    h.scheduler.runPending()
    expectOnlyTheNeighbourGrew(h, from: before, desktop: desktop, a, b, c)
    h.system.setOnActiveSpace(b, true)
    h.scheduler.runPending()
    #expect(frames(h) == before)
  }

  @Test func floatingAWindowWidensOnlyTheNeighbour() {
    let (h, a, b, c) = makeRow(keep)
    let (before, desktop) = (frames(h), h.layout!.desktopFrame)
    #expect(h.run("float \(b.rawValue)").ok)
    expectOnlyTheNeighbourGrew(h, from: before, desktop: desktop, a, b, c)
  }

  @Test func pinningADockedWindowWidensOnlyTheNeighbour() {
    let (h, a, b, c) = makeRow(keep)
    let (before, desktop) = (frames(h), h.layout!.desktopFrame)
    #expect(h.run("pin \(b.rawValue)").ok)
    #expect(h.workspace.isFloating(b))
    expectOnlyTheNeighbourGrew(h, from: before, desktop: desktop, a, b, c)
  }

  @Test func draggingAWindowOutWidensOnlyTheNeighbour() {
    let (h, a, b, c) = makeRow(keep)
    let (before, desktop) = (frames(h), h.layout!.desktopFrame)
    h.system.drag(b, through: [CGPoint(x: before[b]!.midX, y: before[b]!.minY + 10), desktop!.center])
    #expect(h.workspace.isFloating(b))
    expectOnlyTheNeighbourGrew(h, from: before, desktop: desktop, a, b, c)
  }

  @Test func draggingAWindowBelowAnotherWidensOnlyTheNeighbour() {
    let (h, a, b, c) = makeRow(keep)
    let (before, desktop) = (frames(h), h.layout!.desktopFrame)
    h.system.drag(
      b,
      through: [
        CGPoint(x: before[b]!.midX, y: before[b]!.minY + 10), CGPoint(x: before[c]!.midX, y: 600),
        CGPoint(x: before[c]!.midX, y: before[c]!.maxY - 20),
      ])
    #expect(h.frame(b)!.minY > h.frame(c)!.maxY)
    #expect(h.frame(a)!.width == before[a]!.width + before[b]!.width + 12)
    #expect(h.frame(c)!.minX == before[c]!.minX && h.frame(c)!.width == before[c]!.width)
    #expect(h.layout!.desktopFrame == desktop)
    #expect(h.overlays.previewHistory.compactMap { $0 }.last == h.frame(b))
  }

  @Test func draggingAWindowOntoAnotherDisplaysDesktopWidensOnlyTheNeighbour() {
    let (h, a, b, c) = makeRow(keep, displays: [main, side])
    let (before, desktop) = (frames(h), h.layout!.desktopFrame)
    h.system.drag(b, through: [CGPoint(x: before[b]!.midX, y: before[b]!.minY + 10), CGPoint(x: 2000, y: 300)])
    #expect(h.controller.workspaces[side.id]!.isFloating(b))
    expectOnlyTheNeighbourGrew(h, from: before, desktop: desktop, a, b, c)
  }

  @Test func draggingAWindowToAnotherDisplayWidensOnlyTheNeighbour() {
    let (h, a, b, c) = makeRow(keep, displays: [main, side])
    let (before, desktop) = (frames(h), h.layout!.desktopFrame)
    h.system.tiling = .off  // the screen's edges are Arbor's only with macOS's tiling off
    h.system.drag(b, through: [CGPoint(x: before[b]!.midX, y: before[b]!.minY + 10), CGPoint(x: 2717, y: 400)])
    #expect(h.controller.workspaces[side.id]!.isDocked(b))
    expectOnlyTheNeighbourGrew(h, from: before, desktop: desktop, a, b, c)
  }

  @Test func excludingAnAppWidensOnlyTheNeighbour() {
    let (h, a, b, c) = makeRow(keep)
    let (before, desktop) = (frames(h), h.layout!.desktopFrame)
    #expect(h.run("exclude com.example.notes").ok)
    expectOnlyTheNeighbourGrew(h, from: before, desktop: desktop, a, b, c)
  }

  @Test func thePreviewOfADockedWindowsMoveMatchesWhereItLands() {
    let (h, _, b, _) = makeRow(keep)
    let start = h.frame(b)!
    h.system.tiling = .off  // the screen's edges are Arbor's only with macOS's tiling off
    h.system.drag(
      b, through: [CGPoint(x: start.midX, y: start.minY + 10), CGPoint(x: 900, y: 400), CGPoint(x: 1437, y: 450)])
    #expect(h.overlays.previewHistory.compactMap { $0 }.last == h.frame(b))
  }

  @Test func aWindowClosedWhileItsNeighbourIsMinimizedGoesToWhoeverStandsInForIt() {
    let (h, a, b, c) = makeRow(keep)
    let (before, desktop) = (frames(h), h.layout!.desktopFrame)
    h.system.setMinimized(b, true)
    h.system.close(c)
    #expect(h.frame(a)!.minX == before[a]!.minX)
    #expect(h.frame(a)!.maxX == before[c]!.maxX)
    #expect(h.layout!.desktopFrame == desktop)
    h.system.setMinimized(b, false)
    #expect(h.frame(a) == before[a])
    #expect(h.frame(b)!.minX == before[b]!.minX)
    #expect(h.frame(b)!.maxX == before[c]!.maxX)
  }

  @Test func movingAWindowOutOfTheRowWithTheKeyboardWidensOnlyTheNeighbour() {
    // b goes below c: it leaves the row, and c's slot is what the two then share.
    let (h, a, b, c) = makeRow(keep)
    let (before, desktop) = (frames(h), h.layout!.desktopFrame)
    #expect(h.run("dock \(b.rawValue) beside \(c.rawValue) bottom").ok)
    #expect(h.frame(a)!.width == before[a]!.width + before[b]!.width + 12)
    #expect(h.frame(c)!.minX == before[c]!.minX && h.frame(c)!.width == before[c]!.width)
    #expect(h.frame(b)!.minX == before[c]!.minX && h.frame(b)!.minY > h.frame(c)!.maxY)
    #expect(h.layout!.desktopFrame == desktop)
  }

  @Test func movingAWindowOutOfAColumnWithTheKeyboardGrowsOnlyTheNeighbour() {
    // [a | [c / b / x] | Desktop]: ⌃⌥⌘← takes b out of the column, next to a.
    let (h, a, b, c) = makeHarness(keep)
    for window in [c, a] { h.run("dock \(window.rawValue) left") }
    h.run("dock \(b.rawValue) beside \(c.rawValue) bottom")
    let x = h.system.open(app: "Xcode")
    h.run("dock \(x.rawValue) beside \(b.rawValue) bottom")
    let before = frames(h)
    #expect(h.run("dock \(b.rawValue) left").ok)
    #expect(h.frame(c)!.minY == before[c]!.minY)
    #expect(h.frame(c)!.maxY == before[b]!.maxY, "c, before b in the column, takes its slot")
    #expect(h.frame(x)!.minY == before[x]!.minY && h.frame(x)!.maxY == before[x]!.maxY)
  }

  @Test func movingAWindowToTheEdgeOfTheViewWithTheKeyboardWidensOnlyTheNeighbour() {
    // ⌃⌥⌘↑ finds nothing above b, so b leaves the row for the top of the view.
    let (h, a, b, c) = makeRow(keep)
    let (before, desktop) = (frames(h), h.layout!.desktopFrame!)
    #expect(h.run("dock \(b.rawValue) top").ok)
    #expect(h.frame(b)!.maxY < h.frame(a)!.minY)
    #expect(h.frame(a)!.minX == before[a]!.minX)
    #expect(h.frame(a)!.width == before[a]!.width + before[b]!.width + 12)
    #expect(h.frame(c)!.minX == before[c]!.minX && h.frame(c)!.width == before[c]!.width)
    #expect(h.layout!.desktopFrame!.minX == desktop.minX && h.layout!.desktopFrame!.width == desktop.width)
  }

  @Test func dockingBesideAWindowOnAnotherDisplayWidensOnlyTheNeighbour() {
    let (h, a, b, c) = makeRow(keep, displays: [main, side])
    let x = h.system.open(app: "Xcode", frame: CGRect(x: 1600, y: 100, width: 500, height: 400))
    h.system.cursor = CGPoint(x: 2000, y: 400)
    h.run("dock \(x.rawValue) left")
    let (before, desktop) = (frames(h), h.layout!.desktopFrame)
    #expect(h.run("dock \(b.rawValue) beside \(x.rawValue) right").ok)
    #expect(h.controller.workspaces[side.id]!.isDocked(b))
    expectOnlyTheNeighbourGrew(h, from: before, desktop: desktop, a, b, c)
  }

  @Test func aWindowThatIsGoneAtTheNextLaunchLeavesItsSpaceToTheNeighbour() {
    let (old, a, b, c) = makeRow(keep)
    let (before, desktop) = (frames(old), old.layout!.desktopFrame)
    old.controller.saveNow()
    let h = Harness(settings: keep, saved: old.store.saved)
    for window in old.system.allWindows() {
      // The same numbers; b's now belongs to a window of another app.
      h.system.open(
        app: window.id == b ? "Other" : window.appName, title: window.title, pid: window.pid, frame: window.frame)
    }
    h.start()
    #expect(!h.workspace.isDocked(b))
    expectOnlyTheNeighbourGrew(h, from: before, desktop: desktop, a, b, c)
  }

  /// The row on the side display, which then goes away.
  func makeRowOnTheSideDisplayAndUnplugIt() -> (Harness, [WindowID], [WindowID: CGRect]) {
    let h = Harness(displays: [main, side], settings: keep)
    let row = ["Safari", "Notes", "Mail"].map {
      h.system.open(app: $0, frame: CGRect(x: 1600, y: 100, width: 500, height: 400))
    }
    h.start()
    h.system.cursor = CGPoint(x: 2000, y: 400)
    for window in row.reversed() { h.run("dock \(window.rawValue) left") }
    let before = frames(h)
    h.system.setDisplays([main])
    return (h, row, before)
  }

  func expectOnlyTheNeighbourGrewOnTheSideDisplay(
    _ h: Harness, _ row: [WindowID], from before: [WindowID: CGRect],
    sourceLocation: SourceLocation = #_sourceLocation
  ) {
    #expect(h.frame(row[2]) == before[row[2]], sourceLocation: sourceLocation)
    #expect(h.frame(row[0])!.minX == before[row[0]]!.minX, sourceLocation: sourceLocation)
    #expect(h.frame(row[0])!.maxX == before[row[1]]!.maxX, sourceLocation: sourceLocation)
  }

  @Test func aWindowClosedWhileItsDisplayIsAwayLeavesItsSpaceToTheNeighbour() {
    let (h, row, before) = makeRowOnTheSideDisplayAndUnplugIt()
    h.system.close(row[1])
    h.system.setDisplays([main, side])
    expectOnlyTheNeighbourGrewOnTheSideDisplay(h, row, from: before)
  }

  @Test func aWindowDockedElsewhereWhileItsDisplayIsAwayLeavesItsSpaceToTheNeighbour() {
    let (h, row, before) = makeRowOnTheSideDisplayAndUnplugIt()
    h.system.cursor = CGPoint(x: 400, y: 400)
    h.run("dock \(row[1].rawValue) left")
    h.system.setDisplays([main, side])
    #expect(h.workspace.isDocked(row[1]))
    expectOnlyTheNeighbourGrewOnTheSideDisplay(h, row, from: before)
  }

  @Test func aWindowDockedOnADisplayThatAlsoGoesAwayLeavesTheOlderArrangementToTheNeighbour() {
    // b is docked on a third display meanwhile; when that one goes away too, its arrangement is
    // the one that keeps b, and the side display's row closes over b's slot.
    let third = DisplaySnapshot(
      id: DisplayID("third"), frame: CGRect(x: -1280, y: 0, width: 1280, height: 800),
      visibleFrame: CGRect(x: -1280, y: 0, width: 1280, height: 800), isMain: false)
    let (h, row, before) = makeRowOnTheSideDisplayAndUnplugIt()
    h.system.setDisplays([main, third])
    h.system.userMove(row[1], to: CGRect(x: -1000, y: 100, width: 500, height: 400))
    h.system.cursor = CGPoint(x: -600, y: 400)
    #expect(h.run("dock \(row[1].rawValue) left").ok)
    h.system.setDisplays([main])
    h.system.setDisplays([main, side])
    expectOnlyTheNeighbourGrewOnTheSideDisplay(h, row, from: before)
  }

  @Test func aWindowGoneAtLaunchLeavesARememberedArrangementToTheNeighbour() {
    let (old, row, before) = makeRowOnTheSideDisplayAndUnplugIt()
    old.controller.saveNow()
    let h = Harness(displays: [main], settings: keep, saved: old.store.saved)
    for window in old.system.allWindows() {
      h.system.open(
        app: window.id == row[1] ? "Other" : window.appName, title: window.title, pid: window.pid,
        frame: window.frame)
    }
    h.start()
    h.system.setDisplays([main, side])
    expectOnlyTheNeighbourGrewOnTheSideDisplay(h, row, from: before)
  }

  @Test func seamsStopAt80PointsEitherWay() {
    for settings in [Settings(), keep] {
      let (h, a, b, _) = makeRow(settings)
      #expect(h.run("resize \(a.rawValue) right 900").ok)
      #expect(abs(h.layout!.nodeFrames[h.workspace.tree.leaf(containing: b)!]!.width - 80) <= 1)
      let seam = h.overlays.seams[h.display]![0]
      h.overlays.dragSeam(seam, by: -2000)
      #expect(abs(h.layout!.nodeFrames[h.workspace.tree.leaf(containing: a)!]!.width - 80) <= 1)
      let slot = h.frame(b)!
      h.system.userResize(b, to: CGRect(x: slot.maxX - 20, y: slot.minY, width: 20, height: slot.height))
      #expect(abs(h.layout!.nodeFrames[h.workspace.tree.leaf(containing: b)!]!.width - 80) <= 1)
    }
  }

  @Test func quittingAndFloatAllPlaceWindowsByTheSameRule() {
    let (row, a, b, c) = makeRow(keep)
    let h = withNothingRemembered(row)
    let before = frames(h)
    h.system.setMinimized(b, true)
    let without = frames(h)
    h.run("desktop")
    #expect(h.run("float-all").ok)
    #expect(h.frame(a) == without[a])
    #expect(h.frame(c) == before[c])

    let quitting = withNothingRemembered(makeRow(keep).0)
    quitting.system.setMinimized(b, true)
    quitting.run("zoom \(c.rawValue)")
    quitting.controller.shutdown()
    #expect(quitting.frame(a) == without[a])
    #expect(quitting.frame(c) == before[c])
  }
}

// MARK: shrinkOutOfView

@Suite @MainActor struct ParkSmallTests {
  let shrinking = settings { $0.shrinkOutOfView = true }

  /// [a | Desktop | b] with c floating on the Desktop.
  func makeDesk(
    _ settings: Settings, displays: [DisplaySnapshot] = [FakeWindowSystem.standardDisplay]
  ) -> (Harness, WindowID, WindowID, WindowID) {
    let (h, a, b, c) = makeHarness(settings, displays: displays)
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) right")
    h.system.userMove(c, to: CGRect(x: 520, y: 300, width: 400, height: 420))
    return (withNothingRemembered(h), a, b, c)
  }

  func expectOutOfSight(_ h: Harness, _ window: WindowID, sourceLocation: SourceLocation = #_sourceLocation) {
    for display in h.system.displayList {
      let showing = h.frame(window)!.intersection(display.frame)
      // macOS stops a window 32 points above the bottom of the display, and so does the fake: a sliver 1 × 32.
      #expect(showing.area <= 32, "\(window) shows \(showing) on \(display.id)", sourceLocation: sourceLocation)
    }
  }

  @Test func windowsOutOfViewAreShrunkAndComeBackExactly() {
    let (h, a, b, c) = makeDesk(shrinking)
    let before = frames(h)
    #expect(h.run("zoom \(a.rawValue)").ok)
    for window in [b, c] {
      #expect(h.frame(window)!.size == small)
      expectOutOfSight(h, window)
    }
    #expect(h.run("back").ok)
    #expect(frames(h) == before)
    #expect(h.controller.parked.isEmpty)
  }

  @Test func byDefaultWindowsOutOfViewKeepTheirSize() {
    let (h, a, b, c) = makeDesk(Settings())
    let before = frames(h)
    h.run("zoom \(a.rawValue)")
    #expect(h.frame(b)!.size == before[b]!.size)
    #expect(h.frame(c)!.size == before[c]!.size)
  }

  @Test func aWindowAlreadySmallerIsNotMadeLarger() {
    let (h, a, _, c) = makeDesk(shrinking)
    h.system.userMove(c, to: CGRect(x: 520, y: 300, width: 250, height: 500))
    h.run("zoom \(a.rawValue)")
    #expect(h.frame(c)!.size == CGSize(width: 250, height: 200))
    h.run("back")
    #expect(h.frame(c) == CGRect(x: 520, y: 300, width: 250, height: 500))
    h.system.userMove(c, to: CGRect(x: 520, y: 300, width: 400, height: 150))
    h.run("zoom \(a.rawValue)")
    #expect(h.frame(c)!.size == CGSize(width: 320, height: 150))
    h.run("back")
    #expect(h.frame(c) == CGRect(x: 520, y: 300, width: 400, height: 150))
  }

  @Test func theFloatingFrameTheUserChoseSurvivesParking() {
    let (h, a, _, c) = makeDesk(shrinking)
    let chosen = h.workspace.floating[c]
    h.run("zoom \(a.rawValue)")
    // What the real window system reports a moment after Arbor shrinks a window.
    h.controller.windowChanged(h.system.windows[c]!.snapshot, userInitiated: true)
    #expect(h.workspace.floating[c] == chosen)
  }

  @Test func anAppThatRefusesToShrinkIsStillOutOfSightAndIsNotTakenForATile() {
    // With a display beside the bottom-right corner, windows park bottom-left, where width shows.
    let (h, a, b, c) = makeDesk(shrinking, displays: [main, tallSide])
    h.system.setMinimumSize(b, CGSize(width: 450, height: 300))
    h.system.setMinimumSize(c, CGSize(width: 400, height: 150))
    let before = frames(h)
    h.run("zoom \(a.rawValue)")
    #expect(h.frame(b)!.size == CGSize(width: 450, height: 300))
    #expect(h.frame(c)!.size == CGSize(width: 400, height: 200))
    #expect(h.frame(b)!.maxX == 1 && h.frame(c)!.maxX == 1, "bottom-left")
    expectOutOfSight(h, b)
    expectOutOfSight(h, c)
    h.run("back")
    #expect(frames(h) == before)
    #expect(h.layout!.tiles.isEmpty, "a size refused in the corner says nothing about the slot")
  }

  @Test func floatingAWindowThatIsOutOfViewGivesItItsSizeBack() {
    let (h, a, b, _) = makeDesk(shrinking)
    let size = h.frame(b)!.size
    h.run("zoom \(a.rawValue)")
    #expect(h.run("float \(b.rawValue)").ok)
    #expect(h.workspace.floating[b]!.size == size)
    h.run("show-all")
    #expect(h.frame(b)!.size == size)
    #expect(h.system.isVisible(b))
  }

  @Test func aWindowWhoseFloatingFrameIsRememberedGetsThatSizeNotTheSmallOne() {
    // The usual case since F48: b floated at 610 × 410 before it was docked.
    let (h, a, b, _) = makeHarness(shrinking)
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) right")
    h.run("zoom \(a.rawValue)")
    #expect(h.frame(b)!.size == small)
    #expect(h.run("float \(b.rawValue)").ok)
    #expect(h.workspace.floating[b]!.size == CGSize(width: 610, height: 410))
  }

  @Test func floatAllGivesEveryWindowAUsableSize() {
    let (h, a, b, c) = makeDesk(shrinking)
    let before = frames(h)
    h.run("zoom \(a.rawValue)")
    #expect(h.run("float-all").ok)
    #expect(h.frame(b) == before[b])
    #expect(h.frame(c) == before[c])
  }

  @Test func excludingAnAppWhoseWindowIsOutOfViewGivesItItsSizeBack() {
    let (h, a, b, _) = makeDesk(shrinking)
    let size = h.frame(b)!.size
    h.run("zoom \(a.rawValue)")
    #expect(h.run("exclude com.example.notes").ok)
    #expect(h.frame(b)!.size == size)
    #expect(h.system.isVisible(b))
  }

  @Test func aDisplayGoingAwayGivesItsParkedWindowsTheirSizesBack() {
    let first = Harness(displays: [main, side], settings: shrinking)
    let a = first.system.open(app: "Safari", frame: CGRect(x: 1500, y: 100, width: 500, height: 400))
    let b = first.system.open(app: "Notes", frame: CGRect(x: 1700, y: 150, width: 510, height: 410))
    let c = first.system.open(app: "Mail", frame: CGRect(x: 1900, y: 200, width: 520, height: 420))
    first.start()
    first.system.cursor = CGPoint(x: 2000, y: 400)
    first.run("dock \(a.rawValue) left")
    first.run("dock \(b.rawValue) right")
    let h = withNothingRemembered(first)
    let before = frames(h)
    h.run("zoom \(a.rawValue)")
    #expect(h.frame(b)!.size == small && h.frame(c)!.size == small)
    h.system.setDisplays([main])
    #expect(h.frame(b)!.size == before[b]!.size)
    #expect(h.frame(c)!.size == CGSize(width: 520, height: 420), "the size the user gave it, now that there is room")
    #expect(h.system.isVisible(b) && h.system.isVisible(c))
    h.system.setDisplays([main, side])
    h.system.cursor = CGPoint(x: 2000, y: 400)
    h.run("show-all")
    #expect(frames(h) == before)
  }

  @Test func aWindowHiddenWhileItsDisplayComesAndGoesKeepsItsSize() {
    // Small and out of view on the side display, then hidden with its app. The display goes, comes back
    // (the window is docked there again, takes no space, and is not moved) and goes again.
    let first = Harness(displays: [main, side], settings: shrinking)
    let a = first.system.open(app: "Safari", pid: 1001, frame: CGRect(x: 1500, y: 100, width: 500, height: 400))
    let b = first.system.open(app: "Notes", pid: 1002, frame: CGRect(x: 1700, y: 150, width: 510, height: 410))
    first.start()
    first.system.cursor = CGPoint(x: 2000, y: 400)
    first.system.userFocus(a)
    first.run("dock \(a.rawValue) left")
    first.run("dock \(b.rawValue) right")
    let h = withNothingRemembered(first)
    let size = h.frame(b)!.size
    h.run("zoom \(a.rawValue)")
    #expect(h.frame(b)!.size == small)
    h.system.setHidden(pid: 1002, true)
    h.system.setDisplays([main])
    h.system.setDisplays([main, side])
    h.system.setDisplays([main])
    #expect(h.workspace.floating[b]?.size == size)
    h.system.setHidden(pid: 1002, false)
    h.scheduler.runPending()
    #expect(h.frame(b)!.size == size)
    #expect(h.system.isVisible(b))
  }

  @Test func aWindowParkedAgainOnAnotherDisplayKeepsTheSizeItHadInView() {
    // b is parked small on the side display; the display goes away while the main display's
    // Desktop is out of view, so b is parked again, still small.
    let first = Harness(displays: [main, side], settings: shrinking)
    let m = first.system.open(app: "Xcode", frame: CGRect(x: 100, y: 100, width: 600, height: 400))
    let a = first.system.open(app: "Safari", frame: CGRect(x: 1500, y: 100, width: 500, height: 400))
    let b = first.system.open(app: "Notes", frame: CGRect(x: 1700, y: 150, width: 510, height: 410))
    first.start()
    first.system.cursor = CGPoint(x: 400, y: 400)
    first.run("dock \(m.rawValue) left")
    first.run("zoom \(m.rawValue)")
    first.system.cursor = CGPoint(x: 2000, y: 400)
    first.run("dock \(a.rawValue) left")
    first.run("dock \(b.rawValue) right")
    let h = withNothingRemembered(first)
    let size = h.frame(b)!.size
    h.run("zoom \(a.rawValue)")
    // The keyboard is on the display that stays: a change of displays ends with the focused window in view, and
    // one that arrives floating would bring the Desktop, and b with it.
    h.system.userFocus(m)
    h.system.setDisplays([main])
    #expect(h.frame(b)!.size == small)
    #expect(h.controller.parked.contains(b))
    #expect(h.run("exclude com.example.notes").ok)
    #expect(h.frame(b)!.size == size)
    #expect(h.system.isVisible(b))
  }

  @Test func anAppThatChangesItsSizeInTheCornerStillGetsItsSizeBack() {
    let (h, a, b, _) = makeDesk(shrinking)
    let size = h.frame(b)!.size
    h.run("zoom \(a.rawValue)")
    var corner = h.frame(b)!
    corner.size = CGSize(width: 360, height: 240)
    h.system.userMove(b, to: corner)
    #expect(h.run("float \(b.rawValue)").ok)
    #expect(h.workspace.floating[b]!.size == size)
  }

  @Test func quittingLeavesEveryWindowVisibleAtItsSize() {
    let (h, a, _, _) = makeDesk(shrinking)
    let before = frames(h)
    h.run("zoom \(a.rawValue)")
    h.controller.shutdown()
    #expect(frames(h) == before)
  }

  @Test func pausingBringsEveryWindowBackAtItsSizeAndResumingCarriesOn() {
    let (h, a, b, c) = makeDesk(shrinking)
    let before = frames(h)
    h.run("zoom \(a.rawValue)")
    #expect(h.run("pause").ok)
    #expect(h.frame(b) == before[b] && h.frame(c) == before[c])
    #expect(h.run("resume").ok)
    #expect(h.frame(b)!.size == small && h.frame(c)!.size == small)
    h.run("show-all")
    #expect(frames(h) == before)
  }

  @Test func aWindowHiddenThroughAPauseKeepsTheSizeItHadInView() {
    let (h, a, b, _) = makeDesk(shrinking)
    let size = h.frame(b)!.size
    h.run("zoom \(a.rawValue)")
    h.system.setHidden(pid: 1002, true)
    h.run("pause")
    #expect(h.frame(b)!.size == size)
    h.run("resume")
    h.system.setHidden(pid: 1002, false)
    #expect(h.run("float \(b.rawValue)").ok)
    #expect(h.workspace.floating[b]!.size == size)
    h.run("show-all")
    #expect(h.frame(b)!.size == size)
    #expect(h.system.isVisible(b))
  }

  @Test func turningTheSwitchOffWhileWindowsAreParkedStillBringsThemBackExactly() {
    let (h, a, b, _) = makeDesk(shrinking)
    let before = frames(h)
    h.run("zoom \(a.rawValue)")
    h.controller.apply(settings: Settings())
    #expect(h.run("float \(b.rawValue)").ok)
    #expect(h.workspace.floating[b]!.size == before[b]!.size)
    h.run("show-all")
    #expect(h.frame(b)!.size == before[b]!.size)
  }

  @Test func aSizeRememberedFromAnEarlierParkingIsNotUsedLater() {
    let (h, a, b, _) = makeDesk(shrinking)
    h.run("zoom \(a.rawValue)")
    h.run("back")
    h.controller.apply(settings: Settings())
    #expect(h.run("resize \(b.rawValue) left 100").ok)
    let size = h.frame(b)!.size
    h.run("zoom \(a.rawValue)")
    #expect(h.run("float \(b.rawValue)").ok)
    #expect(h.workspace.floating[b]!.size == size)
  }

  @Test func tabsAndTilesParkSmallToo() {
    let (h, a, b, c) = makeRow(settings { $0.shrinkOutOfView = true; $0.minimumUsableWidth = 400 })
    for window in [a, b, c] {
      #expect(h.frame(window)!.size == small, "\(window) is inside a tile")
      expectOutOfSight(h, window)
    }
    h.run("zoom \(b.rawValue)")
    #expect(h.frame(b) == h.visibleFrame.insetBy(dx: 12, dy: 12))
  }

  // MARK: After a crash

  @Test func afterACrashWindowsTheStateKnowsComeBackExactly() {
    let (old, a, _, _) = makeDesk(shrinking)
    let before = frames(old)
    old.run("zoom \(a.rawValue)")
    old.run("show-all")
    old.run("zoom \(a.rawValue)")
    let h = relaunchAfterCrash(old, settings: shrinking)
    #expect(h.workspace.camera == h.workspace.tree.leaf(containing: a))
    h.run("show-all")
    #expect(frames(h) == before)
  }

  @Test func afterACrashAFloatingWindowLeftInTheCornerReturnsToTheDesktop() {
    // Without the switch too: the saved arrangement lists it as floating where the user left it.
    for settings in [Settings(), shrinking] {
      let (old, a, _, c) = makeDesk(settings)
      let before = frames(old)
      // The state on disk is from before the zoom, so the Desktop is in view at the next launch.
      old.controller.saveNow()
      old.run("zoom \(a.rawValue)")
      let h = relaunchAfterCrash(old, settings: settings, savingFirst: false)
      #expect(h.workspace.camera == h.workspace.tree.root)
      #expect(h.frame(c) == before[c])
      #expect(frames(h) == before)
      #expect(h.controller.parked.isEmpty)
    }
  }

  /// Found by the trace `hide-unhide`: macOS brings the windows of an app that is unhidden back on screen.
  @Test func afterACrashAWindowStillOutOfViewThatMacOSBringsBackGoesOutOfViewAgain() {
    for settings in [Settings(), shrinking] {
      let (old, a, b, _) = makeDesk(settings)
      old.run("zoom \(a.rawValue)")
      let h = relaunchAfterCrash(old, settings: settings)
      #expect(h.controller.parked.contains(b))
      h.system.userMove(b, to: CGRect(x: 24, y: 55, width: 600, height: 400))
      h.scheduler.runPending()
      #expect(h.controller.parked.contains(b))
      #expect(h.system.displayList.allSatisfy { h.frame(b)!.fractionInside($0.frame) < 0.02 }, "\(h.frame(b)!)")
    }
  }

  @Test func afterACrashAWindowNobodyRemembersIsRescuedAtAUsableSize() {
    let (old, a, b, c) = makeDesk(shrinking)
    old.system.userMove(c, to: CGRect(x: 520, y: 300, width: 250, height: 500))
    old.run("zoom \(a.rawValue)")
    let h = relaunchAfterCrash(old, forgetState: true)
    #expect(h.frame(b)!.size == CGSize(width: 800, height: 600))
    #expect(h.frame(c)!.size == CGSize(width: 250, height: 600), "only the side that was cut is replaced")
    for window in [a, b, c] {
      #expect(h.visibleFrame.contains(h.frame(window)!), "\(window)")
      #expect(h.workspace.isFloating(window))
    }
  }

  @Test func afterACrashFloatingADockedWindowStillOutOfViewGivesItAUsableSize() {
    let (old, a, b, _) = makeDesk(shrinking)
    old.run("zoom \(a.rawValue)")
    let h = relaunchAfterCrash(old, settings: shrinking)
    #expect(h.controller.parked.contains(b))
    #expect(h.run("float \(b.rawValue)").ok)
    #expect(h.workspace.floating[b]!.size == CGSize(width: 800, height: 600))
  }

  @Test func afterACrashAFloatingWindowStillOutOfViewIsKnownByTheSizeTheUserGaveIt() {
    let (old, a, _, c) = makeDesk(shrinking)
    let size = old.frame(c)!.size
    old.run("zoom \(a.rawValue)")
    let h = relaunchAfterCrash(old, settings: shrinking)
    #expect(h.controller.parked.contains(c))
    #expect(h.frame(c)!.size == small)
    #expect(h.run("exclude com.example.mail").ok)
    #expect(h.frame(c)!.size == size)
    #expect(h.system.isVisible(c))
  }

  @Test func aWindowTheUserKeepsPartlyOffScreenIsLeftAloneAtLaunch() {
    let (old, _, _, c) = makeDesk(Settings())
    let halfOff = CGRect(x: 1240, y: 300, width: 400, height: 420)
    old.system.userMove(c, to: halfOff)
    let h = relaunchAfterCrash(old)
    #expect(h.frame(c) == halfOff)
    #expect(h.controller.parked.isEmpty)
  }
}

// MARK: Everything at once

/// A small repeatable random number generator, so that a failure can be run again.
private struct Dice {
  var state: UInt64
  mutating func roll(_ sides: Int) -> Int {
    state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
    return Int((state >> 33) % UInt64(sides))
  }
}

@Suite @MainActor struct EverySwitchTurnedRoundTests {
  /// Random commands and events with every switch at its other value. Whatever happens, the trees stay
  /// valid, windows are where the layout says, and quitting leaves every window in view at a size
  /// it had in view.
  @Test(arguments: 1...8) func aLongRandomSessionLosesNothing(seed: Int) {
    var dice = Dice(state: UInt64(seed))
    let h = Harness(
      displays: [main, side],
      settings: settings {
        $0.previewDrags = false
        $0.gapHandles = "off"
        $0.shareRemovedSpace = false
        $0.shrinkOutOfView = true
      })
    h.start()
    var open: [WindowID] = []
    func any() -> UInt32 { open.isEmpty ? 1 : open[dice.roll(open.count)].rawValue }
    func edge() -> String { ["left", "right", "top", "bottom"][dice.roll(4)] }
    /// Somewhere the pointer can be: on a display that is connected.
    func point() -> CGPoint {
      CGPoint(x: dice.roll(h.system.displayList.count == 2 ? 2720 : 1440), y: dice.roll(800))
    }
    func bringEveryoneBack() {
      for window in open {
        h.system.setMinimized(window, false)
        h.system.setOnActiveSpace(window, true)
      }
      for pid in 2000..<2004 { h.system.setHidden(pid: Int32(pid), false) }
      h.scheduler.runPending()
    }

    for step in 0..<400 {
      switch dice.roll(20) {
      case 0, 1:
        if open.count < 9 {
          let size = CGSize(width: 330 + dice.roll(500), height: 210 + dice.roll(400))
          // Every real window has some minimum size; a few refuse to be parked small.
          let minimum = dice.roll(4) == 0 ? CGSize(width: 330, height: 210) : CGSize(width: 100, height: 60)
          open.append(
            h.system.open(
              app: "App\(open.count % 4)", pid: Int32(2000 + open.count % 4),
              frame: CGRect(origin: point(), size: size).fitted(into: h.system.displayList[0].frame),
              minimumSize: minimum))
        }
      case 2:
        if !open.isEmpty { h.system.close(open.remove(at: dice.roll(open.count))) }
      case 3: h.system.setMinimized(WindowID(any()), dice.roll(2) == 0)
      case 4: h.system.setHidden(pid: Int32(2000 + dice.roll(4)), dice.roll(2) == 0)
      case 5: h.system.setOnActiveSpace(WindowID(any()), dice.roll(2) == 0)
      case 6, 7, 8: h.run("dock \(any()) \(edge())")
      case 9: h.run("dock \(any()) beside \(any()) \(edge())")
      case 10: h.run("float \(any())")
      case 11: h.run("zoom \(any())")
      case 12: h.run(["in", "out", "back", "forward", "show-all", "desktop"][dice.roll(6)])
      case 13: h.system.cursor = point()
      case 14: h.system.userFocus(WindowID(any()))
      case 15:
        let window = WindowID(any())
        if let frame = h.frame(window), h.system.isVisible(window) {
          h.system.drag(window, through: [CGPoint(x: frame.midX, y: frame.minY + 10), point(), point()])
        }
      case 16: h.run("resize \(any()) \(edge()) \(dice.roll(400) - 200)")
      case 17 where h.controller.isRunning:
        // Not during a pause: macOS moves the windows of a display that goes away onto another, the
        // fake leaves that to Arbor, which is not looking.
        h.system.setDisplays(dice.roll(2) == 0 ? [main] : [main, side])
      case 18: h.run(["arrange", "float-all", "relayout", "pause", "resume", "resume"][dice.roll(6)])
      default: h.run("neighbor \(edge())")
      }
      h.scheduler.runPending()
      h.scheduler.runPending()

      for (display, workspace) in h.controller.workspaces {
        #expect(workspace.tree.invariantViolations().isEmpty, "step \(step)")
        guard let layout = h.controller.layouts[display], let visible = h.controller.display(display)?.visibleFrame
        else { continue }
        for (window, frame) in layout.windowFrames {
          #expect(visible.contains(frame), "step \(step): the slot of \(window)")
          #expect(frame.size.width >= 0 && frame.size.height >= 0, "step \(step)")
        }
        let slots =
          Array(layout.windowFrames.values) + layout.tiles.map(\.frame) + [layout.desktopFrame].compactMap { $0 }
        for (index, slot) in slots.enumerated() {
          for other in slots.dropFirst(index + 1) { #expect(!slot.overlaps(other), "step \(step)") }
        }
        for window in layout.hiddenWindows {
          #expect(!h.system.isVisible(window), "step \(step): \(window) should be out of view")
        }
      }
    }

    h.run("resume")
    bringEveryoneBack()
    let parked = h.controller.parked
    h.controller.shutdown()
    for window in open {
      let frame = h.frame(window)!
      // The others are in their slots or where the user dropped them.
      if parked.contains(window) { #expect(h.system.isVisible(window), "\(window) at \(frame)") }
      let cutToWidth = abs(frame.width - small.width) < 1 && frame.height <= small.height
      let cutToHeight = abs(frame.height - small.height) < 1 && frame.width <= small.width
      #expect(!cutToWidth && !cutToHeight, "\(window) was left small: \(frame)")
    }
  }
}
