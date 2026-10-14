import ArborCore
import ArborKit
import ArborTesting
import CoreGraphics
import Testing

/// Windows on other Spaces (docs/features/F08-displays-and-spaces.md).
@Suite @MainActor struct SpaceTests {
  /// Three windows docked as [a / c | Desktop | b].
  func makeHarness() -> (Harness, WindowID, WindowID, WindowID) {
    let h = Harness()
    let a = h.system.open(app: "Safari", frame: CGRect(x: 100, y: 100, width: 600, height: 400))
    let b = h.system.open(app: "Notes", frame: CGRect(x: 300, y: 200, width: 600, height: 400))
    let c = h.system.open(app: "Mail", frame: CGRect(x: 500, y: 300, width: 600, height: 400))
    h.start()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(c.rawValue) beside \(a.rawValue) bottom")
    h.run("dock \(b.rawValue) right")
    return (h, a, b, c)
  }

  /// Switches Spaces as the Accessibility layer reports it: one change per
  /// window that leaves or comes into view, then the scheduled layout.
  func switchSpaces(_ h: Harness, hiding: [WindowID] = [], showing: [WindowID] = []) {
    for window in hiding { h.system.setOnActiveSpace(window, false) }
    for window in showing { h.system.setOnActiveSpace(window, true) }
    h.scheduler.runPending()
  }

  @Test func onlyWindowsOnTheActiveSpaceArePresent() {
    var window = WindowSnapshot(id: WindowID(1), pid: 1, bundleID: nil, appName: "App", title: "", frame: .zero)
    #expect(window.isOnActiveSpace)
    #expect(window.isPresent)
    window.isOnActiveSpace = false
    #expect(!window.isPresent)
  }

  @Test func aWindowOnAnotherSpaceKeepsItsSlotAndTakesNoSpace() {
    let (h, a, _, c) = makeHarness()
    let tree = h.workspace.tree
    let slots = h.layout!.windowFrames

    switchSpaces(h, hiding: [c])
    #expect(h.workspace.tree == tree, "c keeps its slot")
    #expect(h.controller.windows[c] != nil)
    #expect(h.layout!.windowFrames[c] == nil, "c takes no space")
    #expect(!h.layout!.hiddenWindows.contains(c))
    #expect(!h.controller.parked.contains(c))
    #expect(h.frame(c) == slots[c], "Arbor does not move a window on another Space")
    #expect(h.frame(a)!.height > slots[a]!.height, "a takes the whole column")
    expectWindowsMatchLayout(h, on: h.display)

    switchSpaces(h, showing: [c])
    #expect(h.workspace.tree == tree)
    #expect(h.layout!.windowFrames == slots)
    for (window, frame) in slots {
      #expect(h.frame(window) == frame, "\(window) is back in its slot")
    }
  }

  @Test func switchingSpacesMovesOnlyTheWindowsOnTheSpaceInView() {
    let (h, a, b, c) = makeHarness()
    let tree = h.workspace.tree
    // a and b are on this Space, c on another.
    switchSpaces(h, hiding: [c])
    let frameA = h.frame(a)!
    let frameB = h.frame(b)!

    // To c's Space and back. While a Space is away, nothing on it is moved,
    // even though its windows are reported one at a time.
    h.system.clearFrameLog()
    switchSpaces(h, hiding: [a, b], showing: [c])
    #expect(h.layout!.windowFrames.keys.sorted() == [c])
    #expect(h.workspace.tree == tree)
    #expect(h.system.frameLog.allSatisfy { $0.window == c }, "only c was moved")
    #expect(h.frame(a) == frameA && h.frame(b) == frameB)

    h.system.clearFrameLog()
    switchSpaces(h, hiding: [c], showing: [a, b])
    #expect(h.layout!.windowFrames.keys.sorted() == [a, b])
    #expect(h.workspace.tree == tree)
    #expect(h.system.frameLog.isEmpty, "a and b are where they were left")
    expectWindowsMatchLayout(h, on: h.display)
  }

  @Test func aSpaceSwitchDuringADragWaitsForTheDrop() {
    let (h, a, b, c) = makeHarness()
    let slotA = h.frame(a)!
    let slotB = h.frame(b)!
    let carried = slotB.offsetBy(dx: -300, dy: 40)
    h.system.mouseDown = true
    h.controller.dragBegan(b, at: CGPoint(x: slotB.midX, y: slotB.minY + 10))
    h.system.userMove(b, to: carried)

    switchSpaces(h, hiding: [c])
    #expect(h.frame(b) == carried, "the dragged window stays under the pointer")
    #expect(h.frame(a) == slotA, "nothing is laid out during the drag")

    h.system.mouseDown = false
    h.controller.dragEnded(b, at: CGPoint(x: slotB.midX + 30, y: slotB.midY))
    h.scheduler.runPending()
    #expect(h.frame(b) == slotB)
    #expect(h.frame(a)!.height > slotA.height, "a takes the space c left")
    expectWindowsMatchLayout(h, on: h.display)
  }

  @Test func aWindowThatMovedWhileAwayReturnsToItsSlot() {
    let (h, _, _, c) = makeHarness()
    let slot = h.frame(c)!
    let elsewhere = CGRect(x: 700, y: 400, width: 300, height: 300)
    switchSpaces(h, hiding: [c])
    h.system.userMove(c, to: elsewhere)
    h.scheduler.runPending()
    #expect(h.frame(c) == elsewhere, "left alone while its Space is away")
    switchSpaces(h, showing: [c])
    #expect(h.frame(c) == slot)
  }

  @Test func onlyClosingRemovesAWindowOnAnotherSpace() {
    let (h, a, b, _) = makeHarness()
    switchSpaces(h, hiding: [b])
    h.run("zoom \(a.rawValue)")
    h.run("show-all")
    h.run("relayout")
    h.scheduler.runPending()
    #expect(h.workspace.isDocked(b))
    h.system.close(b)
    #expect(!h.workspace.contains(b))
    #expect(h.workspace.tree.invariantViolations().isEmpty)
  }

  @Test func aFloatingWindowOnAnotherSpaceIsLeftAlone() {
    let (h, a, _, _) = makeHarness()
    let d = h.system.open(app: "Terminal", frame: CGRect(x: 600, y: 300, width: 300, height: 200))
    let spot = h.frame(d)!
    switchSpaces(h, hiding: [d])
    h.run("zoom \(a.rawValue)")
    #expect(!h.controller.parked.contains(d), "not parked: it is not on this Space")
    #expect(h.frame(d) == spot)
    h.run("back")
    switchSpaces(h, showing: [d])
    #expect(h.workspace.isFloating(d))
    #expect(h.frame(d) == spot)
  }
}
