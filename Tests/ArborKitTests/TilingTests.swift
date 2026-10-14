import ArborCore
import ArborKit
import ArborTesting
import CoreGraphics
import Foundation
import Testing

/// The windows of a node's children, in order (`[]` is the Desktop).
@MainActor
private func children(_ h: Harness, of node: NodeID? = nil) -> [[WindowID]] {
  let tree = h.workspace.tree
  return tree.children(of: node ?? tree.root).map { tree.windows(under: $0) }
}

@MainActor
private func parent(_ h: Harness, of window: WindowID) -> NodeID {
  h.workspace.tree.parent(of: h.workspace.tree.leaf(containing: window)!)!
}

private func near(_ a: CGFloat, _ b: CGFloat) -> Bool { abs(a - b) <= 1 }

/// [ a / c | Desktop | b ]
@MainActor
private func columns(settings: Settings = Settings()) -> (Harness, WindowID, WindowID, WindowID) {
  let (h, w) = tilingScenario(
    ["Safari", "Notes", "Mail"], ["dock $0 left", "dock $1 right", "dock $2 beside $0 bottom"], settings: settings)
  return (h, w[0], w[1], w[2])
}

/// Scenario tests for `swap` (docs/features/F22-keyboard-tiling-tools.md).
@Suite @MainActor struct SwapTests {
  @Test func swapTradesPlacesAndTheSlotsKeepTheirSizes() {
    let (h, w) = tilingScenario(["A", "B"], ["dock $0 left", "dock $1 right", "resize $0 right 100"])
    let (a, b) = (w[0], w[1])
    let (wide, narrow) = (h.frame(a)!, h.frame(b)!)
    #expect(wide.width == narrow.width + 100)
    h.system.userFocus(a)
    #expect(runOK(h, "swap right").message == "swapped \(a) with \(b)")
    #expect(h.frame(a) == narrow && h.frame(b) == wide, "over the Desktop, which holds nothing to trade with")
    #expect(h.system.focused == a, "focus stays with the window")
    #expect(children(h) == [[b], [], [a]])
    runOK(h, "swap left")
    #expect(h.frame(a) == wide && h.frame(b) == narrow)
    expectSound(h)

    // `dock <edge>` is the one that takes the size along.
    runOK(h, "dock \(a.rawValue) right")
    #expect(h.frame(a)!.width == wide.width)
  }

  @Test func swapWorksAcrossLevelsOfTheTree() {
    let (h, a, b, c) = columns()
    let (slotA, slotB, slotC) = (h.frame(a)!, h.frame(b)!, h.frame(c)!)
    h.system.userFocus(c)
    runOK(h, "swap right")
    #expect(h.frame(c) == slotB && h.frame(b) == slotC && h.frame(a) == slotA)
    // Of two equal neighbours, the one that had focus last.
    h.system.userFocus(a)
    h.system.userFocus(c)
    runOK(h, "swap left")
    #expect(h.frame(c) == slotA && h.frame(a) == slotB && h.frame(b) == slotC)
    expectSound(h)
  }

  @Test func aNamedWindowSwapsAndTakesFocus() {
    let (h, a, b, c) = columns()
    let (slotA, slotC) = (h.frame(a)!, h.frame(c)!)
    h.system.userFocus(b)
    runOK(h, "swap \(a.rawValue) down")
    #expect(h.frame(a) == slotC && h.frame(c) == slotA)
    #expect(h.system.focused == a, "as with `dock <window> <edge>`")
  }

  @Test func swapRefusesWhatItCannotDo() {
    let (h, w) = tilingScenario(["A", "B", "F"], ["dock $0 left", "dock $1 right"])
    let (a, b, floating) = (w[0], w[1], w[2])
    let before = h.workspace
    h.system.userFocus(a)
    #expect(h.run("swap left").message == "no docked window to the left")
    #expect(h.run("swap up").message == "no docked window above")
    h.system.userFocus(floating)
    #expect(h.run("swap left").message == "\(floating) is floating; only docked windows trade places")
    h.system.focused = nil
    #expect(!h.run("swap left").ok, "no window has the keyboard")
    #expect(!h.run("swap 999 left").ok)
    #expect(h.workspace == before)

    runOK(h, "zoom \(a.rawValue)")
    #expect(h.run("swap right").message == "\(a) fills the view; step out first")
    #expect(h.run("swap \(b.rawValue) left").message == "\(b) is out of view")
    #expect(h.workspace.tree == before.tree)
  }

  @Test func swapStaysInsideTheView() {
    let (h, a, b, c) = columns()
    let column = parent(h, of: a)
    runOK(h, "zoom-node \(column.rawValue)")
    h.system.userFocus(a)
    #expect(!h.run("swap right").ok, "b is outside the view")
    runOK(h, "swap down")
    #expect(children(h, of: column) == [[c], [a]])
    #expect(h.workspace.camera == column)
    #expect(h.frame(c)!.maxY < h.frame(a)!.minY)
    #expect(!h.system.isVisible(b))
    expectSound(h)
  }

  @Test func swappingWithATileBringsItsWindowOut() {
    let (h, w) = tilingScenario(["A"], ["dock $0 left"], settings: noRoomMade)
    let a = w[0]
    let big = h.system.open(app: "Xcode", frame: CGRect(x: 400, y: 200, width: 720, height: 520))
    h.system.setMinimumSize(big, CGSize(width: 700, height: 500))
    runOK(h, "dock \(big.rawValue) right")
    runOK(h, "resize \(a.rawValue) right 300")
    #expect(h.layout!.tiles.contains { $0.windows == [big] })
    let wide = h.frame(a)!
    h.system.userFocus(a)
    runOK(h, "swap right")
    #expect(h.frame(big) == wide)
    #expect(h.system.isVisible(a) && h.system.focused == a)
    #expect(!h.layout!.tiles.contains { $0.kind == .window })
    expectSound(h)
  }

  @Test func focusLeavesAWindowThatSwapsIntoASlotTooSmallForIt() {
    let h = Harness(settings: noRoomMade)
    let a = h.system.open(app: "Xcode", frame: CGRect(x: 100, y: 100, width: 720, height: 520), minimumSize: CGSize(width: 700, height: 500))
    let b = h.system.open(app: "Notes", frame: CGRect(x: 300, y: 200, width: 400, height: 300))
    h.start()
    for command in ["dock \(a.rawValue) left", "dock \(b.rawValue) right", "resize \(a.rawValue) right 300"] { runOK(h, command) }
    h.system.userFocus(a)
    runOK(h, "swap right")
    #expect(h.layout!.tiles.contains { $0.windows == [a] })
    #expect(h.system.focused == b)
    #expect(h.workspace.camera == h.workspace.tree.root, "the view stays")
    expectSound(h)
  }

  @Test func aGroupShownAsATileIsNotSwappedWith() {
    let (h, w) = tilingScenario(
      ["A", "B", "C"], ["dock $0 left", "dock $1 right", "dock $2 beside $1 bottom", "resize $1 left -250"])
    #expect(h.layout!.tiles.map(\.kind) == [.group])
    let before = h.workspace
    h.system.userFocus(w[0])
    let result = h.run("swap right")
    #expect(!result.ok)
    #expect(result.message == "a group of windows is to the right; name one of them: swap \(w[0].rawValue) <window>")
    #expect(h.workspace == before)
    // Naming one works.
    runOK(h, "swap \(w[0].rawValue) \(w[1].rawValue)")
    #expect(children(h) == [[w[1]], [], [w[0], w[2]]])
    expectSound(h)
  }

  @Test func aTabGroupTravelsWhole() {
    var settings = Settings()
    settings.tabsEnabled = true
    let (h, w) = tilingScenario(["A", "B", "C"], ["dock $0 left", "dock $1 right"], settings: settings)
    let (a, b, c) = (w[0], w[1], w[2])
    let start = h.frame(c)!
    h.system.drag(c, through: [CGPoint(x: start.midX, y: start.minY + 10), h.frame(b)!.center])
    #expect(children(h) == [[a], [], [b, c]])
    h.system.userFocus(c)
    runOK(h, "swap left")
    #expect(children(h) == [[b, c], [], [a]])
    #expect(h.workspace.tree.activeWindow(of: h.workspace.tree.leaf(containing: c)!) == c)
    #expect(h.system.isVisible(c) && !h.system.isVisible(b))
    #expect(h.run("swap \(b.rawValue) \(c.rawValue)").message == "\(b) and \(c) are tabs of one tab group")
    expectSound(h)
  }

  @Test func twoNamedWindowsSwapAndFocusStaysWhereItWas() {
    let (h, a, b, c) = columns()
    let (slotB, slotC) = (h.frame(b)!, h.frame(c)!)
    h.system.userFocus(a)
    #expect(runOK(h, "swap \(b.rawValue) \(c.rawValue)").message == "swapped \(b) with \(c)")
    #expect(h.frame(b) == slotC && h.frame(c) == slotB)
    #expect(h.system.focused == a)
    expectSound(h)
  }

  @Test func namedWindowsOutOfViewSwapToo() {
    let (h, a, b, c) = columns()
    runOK(h, "zoom \(a.rawValue)")
    runOK(h, "swap \(b.rawValue) \(c.rawValue)")
    #expect(children(h) == [[a, b], [], [c]])
    #expect(!h.system.isVisible(b) && !h.system.isVisible(c))
    // One in view with one out of view: what shows changes, and focus does not stay on the one that left.
    runOK(h, "out")
    let slot = h.frame(a)!
    #expect(h.system.isVisible(b) && h.system.focused == a)
    runOK(h, "swap \(a.rawValue) \(c.rawValue)")
    #expect(h.frame(c) == slot && !h.system.isVisible(a))
    #expect(h.system.focused != a && h.system.focused != nil)
    expectSound(h)
  }

  @Test func namedSwapsRefuseWhatTheyCannotDo() {
    let (h, w) = tilingScenario(["A", "B", "F"], ["dock $0 left", "dock $1 right"])
    let (a, floating) = (w[0], w[2])
    let before = h.workspace
    #expect(h.run("swap \(a.rawValue) \(a.rawValue)").message == "a window cannot trade places with itself")
    #expect(h.run("swap \(a.rawValue) \(floating.rawValue)").message == "\(floating) is floating; only docked windows trade places")
    #expect(h.run("swap \(floating.rawValue) \(a.rawValue)").message == "\(floating) is floating; only docked windows trade places")
    #expect(!h.run("swap \(a.rawValue) 999").ok)
    #expect(h.workspace == before)
  }

  /// As when a window is docked somewhere else (`aSavedViewOfAWindowFollowsItWhenItIsMoved`): what was saved is the window.
  @Test func savedViewsAndHistoryOfAWindowFollowItThroughASwap() {
    let (h, a, b, _) = columns()
    for command in ["zoom \(a.rawValue)", "save-view 1", "show-all", "zoom \(b.rawValue)", "show-all"] { runOK(h, command) }
    h.system.userFocus(a)
    runOK(h, "swap right")
    runOK(h, "view 1")
    #expect(h.layout!.windowFrames.keys.sorted() == [a], "view 1 was saved of Safari")
    runOK(h, "show-all")
    runOK(h, "swap \(a.rawValue) \(b.rawValue)")
    runOK(h, "view 1")
    #expect(h.layout!.windowFrames.keys.sorted() == [a])
    // view 1, everything, view 1, everything, Notes
    for _ in 0..<4 { runOK(h, "back") }
    #expect(h.layout!.windowFrames.keys.sorted() == [b], "and the history has Notes where Notes was framed")
    expectSound(h)
  }

  @Test func framedOnOneOfTheTwoTheViewStaysWithItsWindow() {
    let (h, a, b, _) = columns()
    let slotB = h.frame(b)!
    runOK(h, "zoom \(a.rawValue)")
    let framed = h.frame(a)!
    h.system.clearFrameLog()
    runOK(h, "swap \(a.rawValue) \(b.rawValue)")
    #expect(h.frame(a) == framed && h.system.focused == a && !h.system.isVisible(b), "nothing a person can see changes")
    #expect(h.system.frameLog.isEmpty)
    runOK(h, "show-all")
    #expect(h.frame(a) == slotB)
    expectSound(h)
  }

  @Test func aGuestStaysWithTheWindowItOpenedOver() {
    let (h, a, b, _) = columns()
    runOK(h, "zoom \(a.rawValue)")
    let guest = h.system.open(app: "Safari", frame: CGRect(x: 500, y: 300, width: 300, height: 200))
    #expect(h.workspace.guests?[guest] != nil)
    runOK(h, "swap \(a.rawValue) \(b.rawValue)")
    runOK(h, "zoom \(b.rawValue)")
    #expect(!h.system.isVisible(guest))
    runOK(h, "zoom \(a.rawValue)")
    #expect(h.system.isVisible(guest))
    expectSound(h)
  }

  @Test func windowsOnTwoDisplaysSwap() {
    let h = Harness(displays: [FakeWindowSystem.standardDisplay, sideDisplay])
    let a = h.system.open(app: "A", frame: CGRect(x: 100, y: 100, width: 500, height: 400))
    let b = h.system.open(app: "B", frame: CGRect(x: 300, y: 200, width: 500, height: 400))
    let c = h.system.open(app: "C", frame: CGRect(x: 1600, y: 100, width: 500, height: 400))
    h.start()
    for command in ["dock \(a.rawValue) left", "dock \(b.rawValue) right", "dock \(c.rawValue) left"] { runOK(h, command) }
    let (slotA, slotC) = (h.frame(a)!, h.frame(c)!)
    runOK(h, "swap \(a.rawValue) \(c.rawValue)")
    #expect(h.frame(a) == slotC && h.frame(c) == slotA)
    #expect(h.workspace.isDocked(c) && h.controller.workspaces[sideDisplay.id]!.isDocked(a))
    expectSound(h)

    // One of them out of view: it is tucked away on the display it moved to, not the one it left.
    runOK(h, "zoom \(b.rawValue)")
    #expect(!h.system.isVisible(c))
    runOK(h, "swap \(c.rawValue) \(a.rawValue)")
    #expect(h.frame(c) == slotC)
    #expect(h.controller.parked.contains(a))
    #expect(FakeWindowSystem.standardDisplay.frame.overlaps(h.frame(a)!) && !sideDisplay.frame.overlaps(h.frame(a)!))
    expectSound(h)

    // Both out of view: each is tucked away again where it now belongs.
    let d = h.system.open(app: "D", frame: CGRect(x: 1700, y: 200, width: 500, height: 400))
    runOK(h, "dock \(d.rawValue) right")
    runOK(h, "zoom \(d.rawValue)")
    #expect(h.controller.parked.isSuperset(of: [a, c]))
    runOK(h, "swap \(a.rawValue) \(c.rawValue)")
    #expect(h.controller.parked.isSuperset(of: [a, c]))
    #expect(sideDisplay.frame.overlaps(h.frame(a)!) && !FakeWindowSystem.standardDisplay.frame.overlaps(h.frame(a)!))
    #expect(FakeWindowSystem.standardDisplay.frame.overlaps(h.frame(c)!) && !sideDisplay.frame.overlaps(h.frame(c)!))
    expectSound(h)
  }
  /// A space cannot cross to another display, so what opened over the window that left is an ordinary floating window.
  @Test func acrossDisplaysAGuestIsLeftBehindAsAnOrdinaryFloatingWindow() {
    let h = Harness(displays: [FakeWindowSystem.standardDisplay, sideDisplay])
    let a = h.system.open(app: "A", frame: CGRect(x: 100, y: 100, width: 500, height: 400))
    let b = h.system.open(app: "B", frame: CGRect(x: 300, y: 200, width: 500, height: 400))
    let c = h.system.open(app: "C", frame: CGRect(x: 1600, y: 100, width: 500, height: 400))
    h.start()
    for command in ["dock \(a.rawValue) left", "dock \(b.rawValue) right", "dock \(c.rawValue) left", "zoom \(a.rawValue)"] {
      runOK(h, command)
    }
    let guest = h.system.open(app: "A", frame: CGRect(x: 500, y: 300, width: 300, height: 200))
    #expect(h.workspace.guests?[guest] != nil)
    runOK(h, "swap \(a.rawValue) \(c.rawValue)")
    #expect(h.workspace.guests == nil && h.workspace.isFloating(guest))
    expectSound(h)
  }

  /// Found by the chaos test: the size was still remembered on the display the window had left, where nothing read it.
  @Test func acrossDisplaysAWindowsOwnSizeGoesAlong() throws {
    let h = Harness(displays: [FakeWindowSystem.standardDisplay, sideDisplay])
    let a = h.system.open(app: "A", frame: CGRect(x: 100, y: 100, width: 500, height: 400))
    let c = h.system.open(app: "C", frame: CGRect(x: 1600, y: 100, width: 620, height: 340))
    h.start()
    for command in ["dock \(a.rawValue) left", "dock \(c.rawValue) left", "swap \(a.rawValue) \(c.rawValue)"] { runOK(h, command) }
    let (main, side) = (h.workspace, try #require(h.controller.workspaces[sideDisplay.id]))
    #expect(main.undockedFrames.map { Array($0.keys) } == [c] && side.undockedFrames.map { Array($0.keys) } == [a])
    runOK(h, "float \(a.rawValue)")
    runOK(h, "float \(c.rawValue)")
    #expect(h.frame(a)!.size == CGSize(width: 500, height: 400) && sideDisplay.frame.contains(h.frame(a)!))
    #expect(h.frame(c)!.size == CGSize(width: 620, height: 340) && FakeWindowSystem.standardDisplay.frame.contains(h.frame(c)!))
    expectSound(h)
  }
}

/// Scenario tests for `equalize`.
@Suite @MainActor struct EqualizeTests {
  @Test func equalizeEvensOutEveryGroupInView() {
    let (h, a, b, c) = columns()
    runOK(h, "resize \(a.rawValue) right 150")
    runOK(h, "resize \(a.rawValue) bottom -120")
    h.system.userFocus(a)
    #expect(runOK(h, "balance").message == "balanced 2 groups")
    #expect(near(h.frame(a)!.width, h.frame(b)!.width) && near(h.frame(a)!.width, h.layout!.desktopFrame!.width))
    #expect(near(h.frame(a)!.height, h.frame(c)!.height))
    expectSound(h)
    // Doing it again changes nothing.
    let tree = h.workspace.tree
    runOK(h, "balance")
    #expect(h.workspace.tree == tree)
  }

  @Test func zoomedInOnlyTheViewIsEvenedOutUnlessAllIsAsked() {
    let (h, a, b, c) = columns()
    runOK(h, "resize \(a.rawValue) right 150")
    runOK(h, "resize \(a.rawValue) bottom -120")
    let column = parent(h, of: a)
    let share = h.workspace.tree[column]!.weight
    runOK(h, "zoom-node \(column.rawValue)")
    h.system.userFocus(a)
    #expect(runOK(h, "balance").message == "balanced 1 group")
    #expect(near(h.frame(a)!.height, h.frame(c)!.height))
    #expect(h.workspace.tree[column]!.weight == share, "the rest of the display keeps its sizes")
    #expect(h.workspace.camera == column)

    runOK(h, "equalize all")
    #expect(h.workspace.tree[column]!.weight == 1)
    #expect(h.workspace.camera == column, "and the camera stays")
    runOK(h, "show-all")
    #expect(near(h.frame(a)!.width, h.frame(b)!.width))
    expectSound(h)
  }

  @Test func afterArrangeTheDesktopKeepsItsNarrowColumn() {
    let (h, w) = tilingScenario(["A", "B", "C", "D"], ["arrange"])
    let arranged = h.workspace.tree
    let frames = w.map { h.frame($0)! }
    runOK(h, "resize \(w[0].rawValue) right 120")
    runOK(h, "resize \(w[3].rawValue) right -90")
    #expect(h.workspace.tree != arranged)
    h.system.userFocus(w[0])
    runOK(h, "equalize")
    #expect(h.workspace.tree == arranged)
    #expect(w.map { h.frame($0)! } == frames)
    #expect(near(h.layout!.desktopFrame!.width * 2, h.frame(w[0])!.width))
  }

  /// `arrange` keeps the setting between 0.05 and 20, whatever the file says. So must the way back to what it made.
  @Test(arguments: [2, 0.001, 0, -3, Double.nan])
  func anAbsurdDesktopWeightIsBoundedAsArrangeBoundsIt(weight: Double) {
    var settings = Settings()
    settings.arrangeDesktopWeight = weight
    let (h, w) = tilingScenario(["A", "B", "C", "D"], ["arrange"], settings: settings)
    let arranged = h.workspace.tree
    runOK(h, "resize \(w[0].rawValue) right 60")
    h.system.userFocus(w[0])
    runOK(h, "equalize")
    #expect(h.workspace.tree == arranged)
    expectSound(h)
  }

  @Test func windowsThatAreAwayGetAnEqualShareToComeBackTo() {
    let (h, a, _, c) = columns()
    runOK(h, "resize \(a.rawValue) bottom -120")
    h.system.setMinimized(c, true)
    h.system.userFocus(a)
    runOK(h, "equalize")
    h.system.setMinimized(c, false)
    #expect(near(h.frame(a)!.height, h.frame(c)!.height))
  }

  /// F61: as equal as the apps allow.
  @Test func aWindowWhoseEqualShareIsTooSmallIsGivenTheRoomItNeeds() {
    let h = Harness()
    let a = h.system.open(app: "A", frame: CGRect(x: 100, y: 100, width: 400, height: 300))
    let b = h.system.open(
      app: "B", frame: CGRect(x: 300, y: 100, width: 720, height: 520), minimumSize: CGSize(width: 700, height: 300))
    h.start()
    for command in ["dock \(a.rawValue) left", "dock \(b.rawValue) right", "show-all", "resize \(b.rawValue) left 300"] {
      runOK(h, command)
    }
    h.system.userFocus(b)
    runOK(h, "balance")
    #expect(h.layout!.tiles.allSatisfy { $0.kind == .desktop } && h.system.isVisible(a))
    #expect(h.frame(b)!.width >= 700 && h.frame(b)!.width < 710 && h.system.focused == b)
    expectSound(h)
  }

  /// A gap once dragged until a window became a tile is no longer the person's wish once they ask for equal sizes.
  @Test func balanceBringsBackAWindowThatWasSqueezedIntoATileByHand() {
    let h = Harness()
    let a = h.system.open(app: "A", frame: CGRect(x: 100, y: 100, width: 400, height: 300))
    let b = h.system.open(
      app: "B", frame: CGRect(x: 300, y: 100, width: 620, height: 520), minimumSize: CGSize(width: 600, height: 300))
    h.start()
    for command in ["dock \(a.rawValue) left", "dock \(b.rawValue) right", "show-all", "resize \(b.rawValue) left 200"] {
      runOK(h, command)
    }
    #expect(h.system.isVisible(b))
    runOK(h, "resize \(b.rawValue) left -300")
    #expect(h.layout!.tiles.contains { $0.windows == [b] }, "squeezed on purpose, and left so")
    h.system.userFocus(a)
    runOK(h, "balance")
    #expect(h.system.isVisible(b) && h.frame(b)!.width >= 600)
    expectSound(h)
  }

  /// Found by the random run.
  @Test func theKeyboardDoesNotStayWithAWindowWhoseEqualShareIsTooSmall() {
    let h = Harness(settings: noRoomMade)
    let a = h.system.open(app: "A", frame: CGRect(x: 100, y: 100, width: 400, height: 300))
    let b = h.system.open(
      app: "B", frame: CGRect(x: 300, y: 100, width: 720, height: 520), minimumSize: CGSize(width: 700, height: 300))
    h.start()
    runOK(h, "dock \(a.rawValue) left")
    runOK(h, "dock \(b.rawValue) right")
    runOK(h, "show-all")
    runOK(h, "resize \(b.rawValue) left 300")
    h.system.userFocus(b)
    #expect(h.system.isVisible(b) && h.workspace.camera == h.workspace.tree.root)
    runOK(h, "equalize")
    #expect(h.layout!.tiles.contains { $0.windows == [b] } && h.workspace.camera == h.workspace.tree.root)
    #expect(h.system.focused == a)
    expectSound(h)
  }

  @Test func equalizeRefusesWhenThereIsNothingToEvenOut() {
    let (h, w) = tilingScenario(["A", "B"])
    #expect(h.run("equalize").message == "nothing is docked")
    #expect(h.run("equalize all").message == "nothing is docked")
    runOK(h, "dock \(w[0].rawValue) left")
    runOK(h, "zoom \(w[0].rawValue)")
    #expect(h.run("equalize").message == "the view holds one space; step out first")
    #expect(h.run("equalize all").ok)
  }

  /// It is about the view, so it chooses its display as the commands that move the view do (F56).
  @Test func equalizeActsOnTheDisplayTheKeyboardIsOn() {
    let h = Harness(displays: [FakeWindowSystem.standardDisplay, sideDisplay])
    let a = h.system.open(app: "A", frame: CGRect(x: 100, y: 100, width: 500, height: 400))
    let c = h.system.open(app: "C", frame: CGRect(x: 1600, y: 100, width: 500, height: 400))
    h.start()
    for command in ["dock \(a.rawValue) left", "dock \(c.rawValue) right", "resize \(a.rawValue) right 100", "resize \(c.rawValue) left 100"] {
      runOK(h, command)
    }
    let other = h.controller.workspaces[sideDisplay.id]!
    h.system.cursor = CGPoint(x: 2000, y: 400)
    h.scheduler.advance(by: 1)
    h.system.userFocus(a)
    #expect(h.press("equalize").ok)
    #expect(h.controller.workspaces[sideDisplay.id]! == other)
    #expect(h.workspace.tree[h.workspace.tree.leaf(containing: a)!]!.weight == 1)
    // Someone who has pointed at the other display since means that one, as for `arrange`.
    h.scheduler.advance(by: 1)
    h.system.cursor = CGPoint(x: 2010, y: 400)
    #expect(h.press("equalize").ok)
    #expect(h.controller.workspaces[sideDisplay.id]! != other)
  }
}

/// Scenario tests for `rotate` and `mirror`.
@Suite @MainActor struct RotateAndMirrorTests {
  @Test func rotateTurnsTheRowOfTheFocusedWindowIntoAColumnAndBack() {
    let (h, a, b, c) = columns()
    let before = h.workspace
    h.system.userFocus(b)
    #expect(runOK(h, "rotate").message == "rotated everything")
    // [ a | c ] above the Desktop above b.
    #expect(children(h) == [[a, c], [], [b]])
    #expect(h.frame(a)!.maxX < h.frame(c)!.minX && h.frame(a)!.minY == h.frame(c)!.minY, "the group inside turned too")
    #expect(h.frame(a)!.maxY < h.layout!.desktopFrame!.minY && h.layout!.desktopFrame!.maxY < h.frame(b)!.minY)
    #expect(h.frame(b)!.width == h.visibleFrame.width - 24)
    #expect(h.system.focused == b)
    expectSound(h)
    runOK(h, "rotate")
    #expect(h.workspace == before)
  }

  @Test func rotatingAnInnerGroupPutsItsWindowsSideBySideInTheSameRoom() {
    var settings = Settings()
    settings.minimumUsableWidth = 150
    let (h, a, b, c) = columns(settings: settings)
    let (before, column) = (h.workspace, parent(h, of: a))
    let room = h.frame(a)!.union(h.frame(c)!)
    let frames = [a, b, c].map { h.frame($0)! }
    let desktop = h.layout!.desktopFrame!
    h.system.userFocus(a)
    #expect(runOK(h, "rotate").message == "rotated Safari and Mail (\(column))")
    #expect(h.frame(a)!.union(h.frame(c)!) == room, "to the point")
    #expect(h.frame(a)!.maxX < h.frame(c)!.minX && h.frame(a)!.height == room.height)
    #expect(near(h.frame(a)!.width, h.frame(c)!.width))
    #expect(h.frame(b) == frames[1] && h.layout!.desktopFrame == desktop, "nothing else changes places")
    #expect(h.workspace.camera == h.workspace.tree.root)
    expectSound(h)

    // The pair is still a pair: the same key turns the same two windows back, from either of them.
    #expect(children(h) == [[a, c], [], [b]])
    h.system.userFocus(c)
    #expect(runOK(h, "rotate").message == "rotated Safari and Mail (\(column))")
    #expect([a, b, c].map { h.frame($0)! } == frames)
    #expect(h.workspace == before)
  }

  /// The product owner's replay: the second press used to turn the whole display into one column.
  @Test func rotateIsItsOwnWayBack() {
    let (h, w) = tilingScenario(
      ["Safari", "Slack", "Term"], ["dock $0 left", "dock $1 right", "dock $2 beside $1 bottom", "resize $1 left 300"])
    let (before, frames) = (h.workspace, w.map { h.frame($0)! })
    h.system.userFocus(w[1])
    runOK(h, "rotate")
    #expect(h.frame(w[1])!.maxX < h.frame(w[2])!.minX && h.frame(w[0]) == frames[0])
    runOK(h, "rotate")
    #expect(w.map { h.frame($0)! } == frames && h.workspace == before)
  }

  /// A turned pair is a space like any other group: it can be framed, stepped out to, and docked into.
  @Test func aTurnedPairIsAGroupLikeAnyOther() {
    var settings = Settings()
    settings.minimumUsableWidth = 150
    let (h, a, b, c) = columns(settings: settings)
    let column = parent(h, of: a)
    h.system.userFocus(a)
    runOK(h, "rotate")
    runOK(h, "zoom \(a.rawValue)")
    runOK(h, "out")
    #expect(h.workspace.camera == column && h.layout!.windowFrames.keys.sorted() == [a, c])
    runOK(h, "show-all")
    // It survives changes elsewhere, and a restart.
    runOK(h, "float \(b.rawValue)")
    #expect(h.workspace.tree.windows(under: column) == [a, c])
    let saved = try? JSONDecoder().decode(Workspace.self, from: JSONEncoder().encode(h.workspace))
    #expect(saved == h.workspace)
    // Down to one window it is gone.
    h.system.close(c)
    #expect(!h.workspace.tree.contains(column))
    expectSound(h)
  }

  /// F62: what a person saved is that group of windows, whichever way it runs.
  @Test func aGroupWithASavedViewStaysAGroupWhenItIsTurned() {
    var settings = Settings()
    settings.minimumUsableWidth = 150
    let (h, a, _, c) = columns(settings: settings)
    let column = parent(h, of: a)
    for command in ["zoom-node \(column.rawValue)", "save-view 1", "show-all"] { runOK(h, command) }
    h.system.userFocus(a)
    runOK(h, "rotate")
    #expect(h.frame(a)!.maxX < h.frame(c)!.minX && h.frame(a)!.minY == h.frame(c)!.minY)
    #expect(h.workspace.savedView(slot: 1) == column && h.workspace.tree.windows(under: column) == [a, c])
    runOK(h, "view 1")
    #expect(h.layout!.windowFrames.keys.sorted() == [a, c])
    expectSound(h)
  }

  @Test func rotateRefusesWhenTheWindowsWouldBecomeTiles() {
    // Side by side in a column 464 points wide, a and c would be 226 points each: tiles.
    let (h, a, _, _) = columns()
    let before = h.workspace
    h.system.userFocus(a)
    h.system.clearFrameLog()
    let result = h.run("rotate")
    #expect(!result.ok)
    #expect(
      result.message == "not enough room: rotated, 2 windows would be too small to show; "
        + "`grow` them first, or frame the group (`zoom`, then `out`) and rotate it there")
    #expect(h.workspace == before)
    #expect(h.system.frameLog.isEmpty)
  }

  /// Found by the random run: how small an app lets its window get is known only once it has been asked.
  @Test func rotateTakesItselfBackWhenAnAppRefusesItsNewSlot() {
    let h = Harness()
    // One above the other they need 1000 points of the display's 875: no room can be made (F61).
    let a = h.system.open(
      app: "A", frame: CGRect(x: 100, y: 100, width: 400, height: 520), minimumSize: CGSize(width: 300, height: 500))
    let b = h.system.open(
      app: "B", frame: CGRect(x: 300, y: 100, width: 400, height: 520), minimumSize: CGSize(width: 300, height: 500))
    h.start()
    runOK(h, "dock \(a.rawValue) left")
    runOK(h, "dock \(b.rawValue) right")
    let (before, frames) = (h.workspace, [h.frame(a)!, h.frame(b)!])
    #expect(h.system.focused == b)
    let result = h.run("rotate")
    #expect(result.message.hasPrefix("not enough room: rotated, "))
    #expect(h.workspace == before && [h.frame(a)!, h.frame(b)!] == frames)
    #expect(h.layout!.tiles.isEmpty && h.system.focused == b)
    expectSound(h)
    // The second time Arbor knows, and moves nothing.
    h.system.clearFrameLog()
    #expect(!h.run("rotate").ok && h.system.frameLog.isEmpty)
  }

  /// F61: the gaps move for a window that needs more than its share, if the others can spare it.
  @Test func rotateMakesRoomForAWindowThatNeedsIt() {
    let h = Harness()
    let a = h.system.open(app: "A", frame: CGRect(x: 100, y: 100, width: 400, height: 300))
    let b = h.system.open(
      app: "B", frame: CGRect(x: 300, y: 100, width: 400, height: 520), minimumSize: CGSize(width: 300, height: 500))
    h.start()
    runOK(h, "dock \(a.rawValue) left")
    runOK(h, "dock \(b.rawValue) right")
    runOK(h, "rotate")
    #expect(h.frame(a)!.maxY < h.frame(b)!.minY && h.frame(b)!.height >= 500)
    #expect(h.system.isVisible(a) && h.system.isVisible(b) && h.system.focused == b)
    expectSound(h)
  }

  /// F62 again: the view is on the group, so the group stays, and so does the view.
  @Test func theWholeViewTurnsAndStaysTheView() {
    let (h, a, b, c) = columns()
    let column = parent(h, of: a)
    runOK(h, "zoom-node \(column.rawValue)")
    h.system.userFocus(a)
    runOK(h, "rotate")
    #expect(h.workspace.camera == column && h.layout!.windowFrames.keys.sorted() == [a, c])
    #expect(h.frame(a)!.maxX < h.frame(c)!.minX && h.frame(a)!.height == h.frame(c)!.height)
    #expect(!h.system.isVisible(b))
    runOK(h, "rotate")
    #expect(h.frame(a)!.maxY < h.frame(c)!.minY && h.workspace.camera == column)
    expectSound(h)
  }

  @Test func aWindowThatFillsTheViewHasNoGroupToTurn() {
    let (h, a, _, _) = columns()
    runOK(h, "zoom \(a.rawValue)")
    let before = h.workspace
    #expect(h.run("rotate").message == "\(a) fills the view; step out first")
    #expect(h.run("mirror").message == "\(a) fills the view; step out first")
    #expect(h.workspace == before)
  }

  @Test func withoutADockedWindowInFocusTheViewItselfTurns() {
    let (h, w) = tilingScenario(["A", "B", "F"], ["dock $0 left", "dock $1 right"])
    h.system.userFocus(w[2])
    runOK(h, "rotate")
    #expect(h.frame(w[0])!.maxY < h.frame(w[1])!.minY)
    h.system.focused = nil
    runOK(h, "mirror")
    #expect(h.frame(w[1])!.maxY < h.frame(w[0])!.minY)
    expectSound(h)
  }

  @Test func aGroupThatShowsOnlyTheFocusedWindowIsPassedOver() {
    let (h, a, b, c) = columns()
    h.system.setMinimized(c, true)
    h.system.userFocus(a)
    runOK(h, "mirror")
    #expect(children(h) == [[b], [], [a, c]], "the row, not the column whose other window is minimized")
    runOK(h, "rotate")
    #expect(h.frame(b)!.maxY < h.frame(a)!.minY)
    expectSound(h)
  }

  @Test func mirrorReversesTheGroupOfTheFocusedWindow() {
    let (h, a, b, c) = columns()
    runOK(h, "resize \(b.rawValue) left 100")
    let (widthA, widthB) = (h.frame(a)!.width, h.frame(b)!.width)
    h.system.userFocus(b)
    runOK(h, "mirror")
    #expect(children(h) == [[b], [], [a, c]])
    #expect(h.frame(b)!.minX == 12 && h.frame(a)!.maxX == h.visibleFrame.maxX - 12)
    #expect(near(h.frame(b)!.width, widthB) && near(h.frame(a)!.width, widthA), "sizes go with the windows")
    #expect(h.frame(a)!.maxY < h.frame(c)!.minY, "the column inside is as it was")

    h.system.userFocus(a)
    #expect(runOK(h, "mirror").message == "mirrored Mail and Safari (\(parent(h, of: a)))")
    #expect(children(h) == [[b], [], [c, a]])
    #expect(h.frame(c)!.maxY < h.frame(a)!.minY)
    #expect(h.system.focused == a)
    expectSound(h)
  }

  @Test func mirrorWorksOnTheWholeView() {
    let (h, a, _, c) = columns()
    let column = parent(h, of: a)
    runOK(h, "zoom-node \(column.rawValue)")
    h.system.userFocus(a)
    runOK(h, "mirror")
    #expect(children(h, of: column) == [[c], [a]])
    #expect(h.workspace.camera == column)
    expectSound(h)
  }

  /// The arrangement is on another of the macOS Spaces then: nothing is rearranged unseen, as for `grow` and `swap`.
  @Test func nothingIsRearrangedWhileTheFocusedWindowIsFullScreen() {
    let (h, a, b, c) = columns()
    runOK(h, "resize \(a.rawValue) right 60")
    h.system.userFocus(a)
    h.system.setFullScreen(a, true)
    let before = h.workspace
    let named = ["swap \(b.rawValue) \(c.rawValue)", "swap \(b.rawValue) left", "move-to-display next \(b.rawValue)"]
    for command in ["balance", "balance all", "rotate", "mirror", "grow", "shrink", "swap right"] + named {
      #expect(h.run(command).message == "\(a) is full screen", "\(command)")
    }
    #expect(h.workspace == before)
  }

  @Test func withNothingDockedThereIsNothingToTurn() {
    let (h, w) = tilingScenario(["A"])
    h.system.userFocus(w[0])
    #expect(h.run("rotate").message == "the view holds no group of windows")
    #expect(h.run("mirror").message == "the view holds no group of windows")
    let (empty, _) = tilingScenario([])
    #expect(!empty.run("rotate").ok && !empty.run("mirror").ok)
  }
}

/// Scenario tests for `grow` and `shrink`.
@Suite @MainActor struct GrowAndShrinkTests {
  @Test func withOneSeamItMovesByTheWholeAmount() {
    let (h, w) = tilingScenario(["A", "B"], ["dock $0 left", "dock $1 right"])
    let (a, b) = (w[0], w[1])
    let (before, other) = (h.frame(a)!, h.frame(b)!)
    h.system.userFocus(a)
    #expect(runOK(h, "grow").message == "\(a) grew")
    #expect(h.frame(a) == CGRect(x: before.minX, y: before.minY, width: before.width + 40, height: before.height))
    #expect(h.frame(b) == other, "the room comes from the Desktop beside it")
    #expect(runOK(h, "shrink").message == "\(a) shrank")
    #expect(h.frame(a) == before)
    runOK(h, "grow 100")
    #expect(h.frame(a)!.width == before.width + 100)
    runOK(h, "shrink 12.5")
    #expect(near(h.frame(a)!.width, before.width + 87.5))
    expectSound(h)
  }

  @Test func seamsOnBothSidesShareTheAmount() {
    let (h, w) = tilingScenario(
      ["A", "M", "B"], ["dock $0 left", "dock $1 beside $0 right", "dock $2 beside $1 right", "equalize"])
    let (a, m, b) = (w[0], w[1], w[2])
    let (beforeA, before, beforeB) = (h.frame(a)!, h.frame(m)!, h.frame(b)!)
    h.system.userFocus(m)
    runOK(h, "grow 40")
    #expect(near(h.frame(m)!.minX, before.minX - 20) && near(h.frame(m)!.maxX, before.maxX + 20))
    #expect(near(h.frame(a)!.width, beforeA.width - 20) && near(h.frame(b)!.width, beforeB.width - 20))
    #expect(h.frame(a)!.minX == beforeA.minX && h.frame(b)!.maxX == beforeB.maxX)
    runOK(h, "shrink 40")
    #expect(h.frame(m)!.approximatelyEquals(before))
    expectSound(h)
  }

  @Test func itChangesInBothDirectionsWhereThereIsASeam() {
    let (h, a, b, c) = columns()
    let (before, below, other) = (h.frame(a)!, h.frame(c)!, h.frame(b)!)
    h.system.userFocus(a)
    runOK(h, "grow 40")
    #expect(h.frame(a)!.approximatelyEquals(
      CGRect(x: before.minX, y: before.minY, width: before.width + 40, height: before.height + 40)))
    #expect(near(h.frame(c)!.height, below.height - 40) && near(h.frame(c)!.width, below.width + 40))
    #expect(h.frame(b) == other)
    expectSound(h)
  }

  /// [ x | Desktop | ( y | w ) / z | q ]: w's left seam is two levels below its right one, and moving the outer
  /// seam rescales the inner split.
  @Test func seamsAtDifferentDepthsStillGiveTheExactAmount() {
    var settings = Settings()
    settings.minimumUsableWidth = 60
    let (h, v) = tilingScenario(
      ["X", "Y", "Z", "W", "Q"],
      ["dock $0 left", "dock $1 right", "dock $2 beside $1 bottom", "dock $3 beside $1 right", "dock $4 right"],
      settings: settings)
    let (y, w, q) = (v[1], v[3], v[4])
    let (before, beforeY, beforeQ) = (h.frame(w)!, h.frame(y)!, h.frame(q)!)
    h.system.userFocus(w)
    runOK(h, "grow 40")
    #expect(near(h.frame(w)!.minX, before.minX - 20) && near(h.frame(w)!.maxX, before.maxX + 20))
    #expect(near(h.frame(y)!.width, beforeY.width - 20) && near(h.frame(q)!.width, beforeQ.width - 20))
    #expect(near(h.frame(w)!.height, before.height + 40), "and its one seam below by the whole amount")
    expectSound(h)
  }

  @Test func growingStopsWhenTheNeighbourIsDownToTheLimit() {
    let (h, w) = tilingScenario(["A", "B"], ["dock $0 left", "dock $1 right"])
    let a = w[0]
    h.system.userFocus(a)
    runOK(h, "grow 1000000")
    let desktop = h.layout!.tiles.first { $0.kind == .desktop }
    #expect(near(desktop?.frame.width ?? 0, 80), "the limit every seam keeps")
    let (frame, before) = (h.frame(a)!, h.workspace)
    let result = h.run("grow")
    #expect(!result.ok && result.message == "\(a) cannot grow any further")
    #expect(h.frame(a) == frame)
    #expect(h.workspace == before, "to the last digit of every weight")
    expectSound(h)
  }

  @Test func shrinkingStopsWhileTheWindowCanStillBeShown() {
    let (h, a, _, _) = columns()
    h.system.userFocus(a)
    runOK(h, "shrink 1000000")
    #expect(h.layout!.windowFrames[a] != nil, "it never shrinks into a tile")
    #expect((240...242).contains(h.frame(a)!.width) && (160...162).contains(h.frame(a)!.height))
    let result = h.run("shrink")
    #expect(!result.ok && result.message == "\(a) cannot shrink any further")
    #expect(h.system.focused == a)
    runOK(h, "grow")
    expectSound(h)
  }

  @Test func shrinkingStopsAtTheSizeTheAppInsistsOn() {
    let h = Harness()
    let a = h.system.open(app: "Xcode", frame: CGRect(x: 100, y: 100, width: 500, height: 400), minimumSize: CGSize(width: 400, height: 300))
    h.start()
    runOK(h, "dock \(a.rawValue) left")
    h.system.userFocus(a)
    // Arbor does not know the minimum yet. The window refuses the slot, and instead of leaving it as a
    // tile the seam goes back as far as the window needs.
    runOK(h, "shrink 400")
    #expect(h.layout!.windowFrames[a] != nil && h.layout!.tiles.isEmpty)
    #expect((400...402).contains(h.frame(a)!.width))
    #expect(h.system.focused == a)
    #expect(h.run("shrink").message == "\(a) cannot shrink any further")
    expectSound(h)
  }

  @Test func aWindowWithNothingBesideItInViewRefuses() {
    let (h, w) = tilingScenario(["A", "B"], ["dock $0 left", "dock $1 right", "zoom $0"])
    #expect(h.run("grow").message == "\(w[0]) has nothing beside it in view to trade room with")
    #expect(h.run("shrink").message == "\(w[0]) has nothing beside it in view to trade room with")
    h.system.focused = nil
    #expect(!h.run("grow").ok, "no window has the keyboard")
  }

  @Test func theStepComesFromTheSettings() {
    var settings = Settings()
    settings.resizeStep = 64
    let (h, w) = tilingScenario(["A"], ["dock $0 left"], settings: settings)
    let width = h.frame(w[0])!.width
    h.system.userFocus(w[0])
    runOK(h, "grow")
    #expect(h.frame(w[0])!.width == width + 64)
    runOK(h, "shrink 64")
    for useless in [0, -5, Double.nan, Double.infinity] {
      settings.resizeStep = useless
      h.controller.apply(settings: settings)
      runOK(h, "grow")
      #expect(h.frame(w[0])!.width == width + 40, "\(useless) counts as the default")
      runOK(h, "shrink")
    }
  }

  @Test func numbersThatAreNotAmountsAreRefusedHoweverTheyArrive() {
    // `parse` lets none of these through; a command built in code can hold them.
    let (h, w) = tilingScenario(["A", "F"], ["dock $0 left"])
    for window in w {
      h.system.userFocus(window)
      let before = (h.workspace, h.frame(window))
      for amount in [Double.nan, .infinity, -.infinity, 0, -40] {
        #expect(!h.controller.perform(.grow(amount)).ok, "\(amount)")
        #expect(!h.controller.perform(.shrink(amount)).ok, "\(amount)")
      }
      #expect(h.workspace == before.0 && h.frame(window) == before.1)
      #expect(h.controller.perform(.grow(1e300)).ok, "more than any display is as much as there is room for")
      #expect(h.controller.perform(.shrink(.greatestFiniteMagnitude)).ok)
      expectSound(h)
    }
  }

  @Test func aFloatingWindowBiggerThanItsDisplayDoesNotShrinkWhenAskedToGrow() {
    let h = Harness()
    let f = h.system.open(app: "F", frame: CGRect(x: -100, y: 25, width: 1700, height: 1000))
    h.start()
    h.system.userFocus(f)
    #expect(h.run("grow").message == "\(f) cannot grow any further")
    #expect(h.frame(f) == CGRect(x: -100, y: 25, width: 1700, height: 1000))
  }

  @Test func aFloatingWindowChangesAboutItsMiddle() {
    let (h, w) = tilingScenario(["F"])
    let f = w[0]
    h.system.userFocus(f)
    runOK(h, "grow")
    #expect(h.frame(f) == CGRect(x: 500, y: 280, width: 440, height: 340))
    #expect(h.workspace.floating[f] == h.frame(f), "and that is where it comes back to")
    runOK(h, "shrink 140")
    #expect(h.frame(f) == CGRect(x: 570, y: 350, width: 300, height: 200))

    runOK(h, "shrink 1000000")
    #expect(h.frame(f) == CGRect(x: 680, y: 410, width: 80, height: 80))
    #expect(h.run("shrink").message == "\(f) cannot shrink any further")

    runOK(h, "grow 1000000")
    #expect(h.frame(f) == h.visibleFrame, "no further than the display")
    #expect(h.run("grow").message == "\(f) cannot grow any further")
  }

  /// Floating windows live on the Desktop. One that grew over its docked neighbours would be squeezed back at the next
  /// change of the arrangement, so it stops at the Desktop's edge.
  @Test func aFloatingWindowOnTheDesktopGrowsNoFurtherThanTheDesktop() {
    let (h, w) = tilingScenario(["A", "B", "F"], ["dock $0 left", "dock $1 right"])
    let f = w[2]
    h.system.userFocus(f)
    let desktop = h.layout!.desktopFrame!
    #expect(desktop.contains(h.frame(f)!))
    runOK(h, "grow 1000000")
    let grown = h.frame(f)!
    #expect(grown.minX == desktop.minX && grown.maxX == desktop.maxX, "docked windows on both sides")
    #expect(grown.minY == h.visibleFrame.minY && grown.maxY == h.visibleFrame.maxY, "nothing docked above or below")
    #expect(h.run("grow").message == "\(f) cannot grow any further")
    // Nothing jumps when the arrangement next changes.
    runOK(h, "relayout")
    #expect(h.frame(f) == grown)
    expectSound(h)
  }

  /// Someone who put it over docked windows meant it, and means it when making it bigger.
  @Test func aFloatingWindowPutOverDockedWindowsGrowsWhereItIs() {
    let (h, w) = tilingScenario(["A", "B", "F"], ["dock $0 left", "dock $1 right"])
    let f = w[2]
    h.system.userMove(f, to: CGRect(x: 100, y: 200, width: 300, height: 200))
    h.system.userFocus(f)
    runOK(h, "grow 100")
    #expect(h.frame(f) == CGRect(x: 50, y: 150, width: 400, height: 300))
    #expect(h.overlays.scenes[h.display]?.focusRing?.frame == h.frame(f), "the focus ring goes along")
    runOK(h, "relayout")
    #expect(h.frame(f) == CGRect(x: 50, y: 150, width: 400, height: 300), "and it is left there")
    expectSound(h)
  }

  /// F02: the stage covers the real windows while a motion plays, and lifts on what it led to.
  @Test func aMotionStillPlayingEndsBeforeAFloatingWindowChangesUnderIt() {
    let (h, w) = tilingScenario(["A", "F"], ["dock $0 left"])
    h.system.userFocus(w[1])
    let before = h.overlays.finishedAnimations
    runOK(h, "grow")
    #expect(h.overlays.finishedAnimations == before + 1)
    #expect(!h.run("shrink 0.5").ok && h.overlays.finishedAnimations == before + 1, "nothing moved, nothing ends")
  }

  /// F18, which is off by default: a window that floats alone fills the Desktop until its user takes it in hand.
  @Test func aWindowThatFilledTheDesktopKeepsTheSizeItWasShrunkTo() {
    var settings = Settings()
    settings.soleFloatTakesDesktop = true
    let (h, w) = tilingScenario(["A", "F"], ["dock $0 left"], settings: settings)
    let f = w[1]
    h.system.userFocus(f)
    let filling = h.frame(f)!
    #expect(filling.width > 600, "it fills the Desktop")
    runOK(h, "shrink 200")
    #expect(h.frame(f)!.width == filling.width - 200)
    let shrunk = h.frame(f)!
    runOK(h, "relayout")
    #expect(h.frame(f) == shrunk, "and is not stretched again")
  }

  @Test func aFloatingWindowNearAnEdgeStaysOnTheDisplay() {
    let h = Harness()
    let f = h.system.open(app: "F", frame: CGRect(x: 0, y: 25, width: 300, height: 200))
    h.start()
    h.system.userFocus(f)
    runOK(h, "grow 100")
    #expect(h.frame(f) == CGRect(x: 0, y: 25, width: 400, height: 300))
  }

  @Test func aFloatingWindowThatWillNotChangeSaysSo() {
    let h = Harness()
    let f = h.system.open(app: "F", frame: CGRect(x: 300, y: 200, width: 300, height: 200), minimumSize: CGSize(width: 300, height: 200))
    h.start()
    h.system.setMaximumSize(f, CGSize(width: 300, height: 200))
    h.system.userFocus(f)
    #expect(h.run("grow").message == "\(f) cannot grow any further")
    #expect(h.run("shrink").message == "\(f) cannot shrink any further")
    #expect(h.workspace.floating[f] == CGRect(x: 300, y: 200, width: 300, height: 200))
  }
}
