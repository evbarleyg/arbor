import ArborCore
import ArborKit
import ArborTesting
import CoreGraphics
import Foundation
import Testing

private let side = sideDisplay

/// Scenario tests for `focus` (docs/features/F22-keyboard-tiling-tools.md).
@Suite @MainActor struct KeyboardFocusTests {
  func harness(
    _ apps: [String], _ commands: [String] = [], settings: Settings = Settings(),
    sourceLocation: SourceLocation = #_sourceLocation
  ) -> (Harness, [WindowID]) {
    tilingScenario(apps, commands, settings: settings, sourceLocation: sourceLocation)
  }

  @discardableResult
  func expectOK(_ h: Harness, _ command: String, sourceLocation: SourceLocation = #_sourceLocation) -> CommandResult {
    runOK(h, command, sourceLocation: sourceLocation)
  }

  /// Presses a direction and says who has focus afterwards.
  func go(_ h: Harness, _ direction: String, sourceLocation: SourceLocation = #_sourceLocation) -> WindowID? {
    expectOK(h, "focus \(direction)", sourceLocation: sourceLocation)
    return h.system.focused
  }

  func leaf(_ h: Harness, _ window: WindowID) -> NodeID? { h.workspace.tree.leaf(containing: window) }

  /// [ a / c | b ]. With a column for the Desktop: [ a / c | Desktop | b ].
  func columns(settings: Settings = Settings()) -> (Harness, WindowID, WindowID, WindowID) {
    let (h, w) = harness(
      ["Safari", "Notes", "Mail"], ["dock $0 left", "dock $1 right", "dock $2 beside $0 bottom"], settings: settings)
    return (h, w[0], w[1], w[2])
  }

  // MARK: In view

  @Test(arguments: [false, true]) func focusGoesToTheNearestWindowInEachDirection(desktopColumn: Bool) {
    let (h, a, b, c) = columns(settings: desktopColumn ? .withDesktopColumn : Settings())
    h.system.userFocus(a)
    h.system.clearFrameLog()
    let camera = h.workspace.camera
    #expect(go(h, "down") == c)
    #expect(go(h, "up") == a)
    #expect(go(h, "right") == b, "an empty Desktop is not a stop")
    #expect(go(h, "left") == a, "of two equal neighbours, the one focused last")
    #expect(go(h, "down") == c)
    #expect(go(h, "right") == b)
    #expect(go(h, "left") == c)
    #expect(h.system.frameLog.isEmpty, "moving focus within the view moves no window")
    #expect(h.workspace.camera == camera)
  }

  @Test func aFloatingWindowInBetweenIsAStop() {
    let (h, w) = harness(["Safari", "Notes", "Calculator"], ["dock $0 left", "dock $1 right"], settings: .withDesktopColumn)
    let (a, b, floating) = (w[0], w[1], w[2])
    #expect(h.layout!.desktopFrame!.contains(h.frame(floating)!))
    h.system.userFocus(a)
    #expect(go(h, "right") == floating)
    #expect(go(h, "right") == b)
    #expect(go(h, "left") == floating)
    #expect(go(h, "left") == a)
  }

  @Test func aFloatingWindowLyingOverADockedOneCanBeReached() {
    let (h, w) = harness(["Safari", "Notes"], ["dock $0 left", "dock $1 right"])
    let (a, b) = (w[0], w[1])
    // A window that opened half over Safari, as new windows do.
    let fresh = h.system.open(app: "Terminal", frame: CGRect(x: 300, y: 200, width: 500, height: 300))
    h.system.userFocus(a)
    #expect(go(h, "right") == fresh)
    #expect(go(h, "left") == a)
    h.system.userFocus(b)
    #expect(go(h, "left") == fresh)
  }

  /// A dialog, a second small window, a guest over a framed window: wholly inside the focused window's frame, so its centre
  /// is past none of that window's edges. It lies the way its centre lies from the focused window's centre.
  @Test func aWindowFloatingInsideTheFocusedOneIsReachedTheWayItLies() {
    let (h, w) = harness(["Safari", "Notes"], ["dock $0 left", "dock $1 right", "zoom $0"])
    let a = w[0]
    let camera = h.workspace.camera
    let small = h.system.open(app: "Safari", frame: CGRect(x: 900, y: 300, width: 300, height: 200))
    h.system.userFocus(a)
    #expect(go(h, "right") == small)
    #expect(h.workspace.camera == camera && h.system.isVisible(a), "the view has not moved")
    #expect(go(h, "left") == a)
    #expect(h.workspace.camera == camera)
    // Not the other way: there it is the neighboring space, as ever.
    #expect(h.run("focus left").message == "no window or space to the left")
  }

  /// In the very middle it lies no way at all. But nobody in it means to move the whole view with an arrow while the window
  /// it lies on has not had its turn.
  @Test func fromAWindowFloatingOverAnotherAnArrowWithNothingThatWayGoesToTheOneBeneath() {
    let (h, w) = harness(["Safari", "Notes"], ["dock $0 left", "dock $1 right", "zoom $0"])
    let (a, b) = (w[0], w[1])
    let (camera, framed) = (h.workspace.camera, h.frame(a)!)
    let middle = h.system.open(
      app: "Safari", frame: CGRect(x: framed.midX - 150, y: framed.midY - 100, width: 300, height: 200))
    #expect(h.system.focused == middle)
    #expect(go(h, "right") == a)
    #expect(h.workspace.camera == camera && h.system.isVisible(middle), "the view has not moved")
    // From the window beneath the same key goes on, as it always has.
    #expect(go(h, "right") == b)
  }

  /// On the Desktop nothing is beneath it, and the arrows do what they did.
  @Test func aWindowFloatingOnTheDesktopHasNothingBeneathIt() {
    let (h, w) = harness(["Safari", "Notes"], ["dock $0 left", "dock $1 right"], settings: .withDesktopColumn)
    let desktop = h.layout!.desktopFrame!
    let f = h.system.open(app: "Calculator", frame: CGRect(x: desktop.midX - 100, y: desktop.midY - 100, width: 200, height: 200))
    #expect(h.system.focused == f)
    #expect(h.run("focus up").message == "no window or space above")
    #expect(go(h, "left") == w[0])
  }

  /// Three columns split at different heights: the tall window in the third shares more of a's
  /// height than either window of the second, and still the second column comes first.
  @Test func theNextColumnComesBeforeATallerWindowBeyondIt() {
    let (h, w) = harness(
      ["A", "D", "B", "C", "E"],
      ["dock $0 left", "dock $1 beside $0 bottom", "dock $2 right", "dock $3 beside $2 bottom", "dock $4 right",
        "resize $2 bottom -120"])
    let (a, b, c, e) = (w[0], w[2], w[3], w[4])
    #expect(h.frame(b)!.height < h.frame(a)!.height && h.frame(e)!.height > h.frame(a)!.height)
    h.system.userFocus(a)
    #expect(go(h, "right") == b)
    #expect(go(h, "right") == e)
    #expect(go(h, "left") == c, "the longer neighbour")
  }

  @Test func atTheLastEdgeFocusStaysAndTheCommandSaysWhy() {
    let (h, a, b, _) = columns()
    h.system.userFocus(a)
    let before = h.workspace
    #expect(h.run("focus left").message == "no window or space to the left")
    #expect(h.run("focus up").message == "no window or space above")
    #expect(!h.run("focus left").ok)
    #expect(h.system.focused == a)
    h.system.userFocus(b)
    #expect(h.run("focus right").message == "no window or space to the right")
    #expect(h.run("focus down").message == "no window or space below")
    #expect(h.workspace == before)
  }

  @Test func withOneWindowThereIsNowhereToGo() {
    let (h, w) = harness(["Safari"], ["dock $0 left"])
    h.system.userFocus(w[0])
    for direction in ["left", "right", "up", "down"] { #expect(!h.run("focus \(direction)").ok) }
    #expect(h.run("focus next").message == "\(w[0]) is the only window in view")
    #expect(!h.run("focus previous").ok)
    #expect(h.system.focused == w[0])
  }

  @Test func withNoWindowsEveryFormFails() {
    let (h, _) = harness([])
    for form in ["left", "right", "up", "down", "next", "previous", "101"] { #expect(!h.run("focus \(form)").ok, "\(form)") }
    #expect(h.run("focus next").message == "no windows in view")
  }

  // MARK: Nothing to start from

  @Test func withNoFocusedWindowThePointerDecidesAndThenTheTopLeft() {
    let (h, a, b, c) = columns()
    h.system.focused = nil
    h.system.cursor = h.frame(c)!.center
    #expect(go(h, "right") == c, "whatever the direction")
    h.system.focused = nil
    h.system.cursor = CGPoint(x: (h.frame(a)!.maxX + h.frame(b)!.minX) / 2, y: h.frame(b)!.midY)  // in the gap
    #expect(go(h, "left") == a, "nothing under the pointer: the top left")
    h.system.focused = nil
    h.system.cursor = h.frame(b)!.center
    #expect(go(h, "up") == b)
  }

  @Test func aFloatingWindowUnderThePointerComesBeforeTheDockedOneBehindIt() {
    let (h, w) = harness(["Safari"], ["dock $0 left"])
    let fresh = h.system.open(app: "Terminal", frame: CGRect(x: 100, y: 200, width: 300, height: 300))
    h.system.userFocus(fresh)  // as macOS does with a window that opens
    h.system.focused = nil
    h.system.cursor = CGPoint(x: 250, y: 350)
    #expect(h.frame(w[0])!.contains(h.system.cursor))
    #expect(go(h, "down") == fresh)
  }

  @Test func aFocusedWindowArborDoesNotArrangeIsNoStartingPoint() {
    var settings = Settings()
    settings.excludedBundleIDs = ["com.example.finder"]
    let (h, w) = harness(["Safari", "Notes", "Finder"], ["dock $0 left", "dock $1 right"], settings: settings)
    h.system.userFocus(w[2])
    h.system.cursor = h.frame(w[1])!.center
    #expect(go(h, "left") == w[1])
    // And focus never goes to it.
    #expect(go(h, "left") == w[0])
    #expect(!h.run("focus \(w[2].rawValue)").ok)
    #expect(go(h, "next") == w[1])
    #expect(go(h, "next") == w[0])
  }

  // MARK: The edge of the view

  @Test func framedOnOneWindowFocusDoesWhatNeighborDoes() {
    let (h, a, b, c) = columns(settings: .withDesktopColumn)
    expectOK(h, "zoom \(a.rawValue)")
    #expect(go(h, "down") == c)
    #expect(h.workspace.camera == leaf(h, c))
    #expect(h.frame(c) == h.visibleFrame.insetBy(dx: 12, dy: 12))
    #expect(!h.system.isVisible(a))
    #expect(go(h, "up") == a)
    #expect(h.workspace.camera == leaf(h, a))

    // To the right lies the Desktop, with nothing to focus; the same key goes on from there.
    let result = expectOK(h, "focus right")
    #expect(h.workspace.camera == h.workspace.tree.desktop)
    #expect(result.message == "moved to the Desktop; no window to focus there")
    #expect(go(h, "right") == b)
    #expect(h.workspace.camera == leaf(h, b))
    #expect(!h.run("focus right").ok)

    // Each step is a camera move like any other.
    expectOK(h, "back")
    #expect(h.workspace.camera == h.workspace.tree.desktop)
    expectOK(h, "back")
    #expect(h.workspace.camera == leaf(h, a))
    expectWindowsMatchLayout(h, on: h.display)
  }

  @Test func theSameKeysTakeTheSamePathAsNeighbor() {
    // What ⌃⌥⇧↑ and ⌃⌥⇧↓ did before they meant `focus`.
    for direction in ["up", "down", "left", "right"] {
      let (viaFocus, a, _, _) = columns()
      let (viaNeighbor, _, _, _) = columns()
      for h in [viaFocus, viaNeighbor] { expectOK(h, "zoom \(a.rawValue)") }
      let focus = viaFocus.run("focus \(direction)")
      let neighbor = viaNeighbor.run("neighbor \(direction)")
      #expect(focus.ok == neighbor.ok, "\(direction)")
      #expect(viaFocus.workspace == viaNeighbor.workspace, "\(direction)")
      #expect(viaFocus.system.focused == viaNeighbor.system.focused, "\(direction)")
    }
  }

  @Test(arguments: [false, true]) func aFloatingWindowOnTheDesktopNextDoorGetsFocus(makingWay: Bool) {
    let (h, w) = harness(
      ["Safari", "Notes", "Calculator"], ["dock $0 left", "dock $1 right"], settings: (makingWay ? .makingWay : Settings()).withDesktopColumn)
    let (a, floating) = (w[0], w[2])
    expectOK(h, "zoom \(a.rawValue)")
    // Away with the Desktop only if it makes way. As Arbor ships it lies over Safari, and the space next door is the Desktop as ever.
    #expect(h.system.isVisible(floating) == !makingWay)
    #expect(go(h, "right") == floating)
    #expect(h.workspace.camera == h.workspace.tree.desktop)
    #expect(h.system.isVisible(floating) && h.layout!.desktopFrame!.contains(h.frame(floating)!), "back on its Desktop")
  }

  /// [ a | ( b | c ) / d | e ]: the middle space is entered from the side one comes from.
  @Test func aSpaceIsEnteredAtTheEdgeOneCameThrough() {
    let (h, w) = harness(
      ["A", "B", "C", "D", "E"],
      ["dock $0 left", "dock $1 right", "dock $3 beside $1 bottom", "dock $2 beside $1 right", "dock $4 right"])
    let (a, b, c, d, e) = (w[0], w[1], w[2], w[3], w[4])
    let middle = h.workspace.tree.parent(of: leaf(h, d)!)!
    #expect(Set(h.workspace.tree.windows(under: middle)) == [b, c, d])

    expectOK(h, "zoom \(a.rawValue)")
    #expect([b, d].contains(go(h, "right")), "something on the left edge, not c")
    #expect(h.workspace.camera == middle)

    expectOK(h, "zoom \(e.rawValue)")
    #expect([c, d].contains(go(h, "left")), "something on the right edge, not b")
    #expect(h.workspace.camera == middle)
  }

  @Test func enteringASpaceTheWindowLevelWithTheOldOneWins() {
    // [ a / c | b / d ], no Desktop in between: framed on the left column, going right from c lands on d.
    let (h, w) = harness(
      ["A", "B", "C", "D"],
      ["dock $0 left", "dock $1 beside $0 right", "dock $2 beside $0 bottom", "dock $3 beside $1 bottom"])
    let (a, c, d) = (w[0], w[2], w[3])
    let left = h.workspace.tree.parent(of: leaf(h, a)!)!
    expectOK(h, "zoom-node \(left.rawValue)")
    h.system.userFocus(c)
    #expect(go(h, "right") == d)
    #expect(h.workspace.camera == h.workspace.tree.parent(of: leaf(h, d)!))
  }

  // MARK: Tiles

  @Test func aWindowTileInTheWayIsEntered() {
    let (h, w) = harness(["Safari", "Notes"], ["dock $0 left", "dock $1 right"], settings: noRoomMade)
    let (a, b) = (w[0], w[1])
    let big = h.system.open(app: "Xcode", frame: CGRect(x: 400, y: 200, width: 700, height: 500))
    h.system.setMinimumSize(big, CGSize(width: 900, height: 600))
    expectOK(h, "dock \(big.rawValue) beside \(b.rawValue) bottom")
    #expect(h.layout!.tiles.map(\.windows) == [[big]])
    h.system.userFocus(b)
    #expect(go(h, "down") == big)
    #expect(h.workspace.camera == leaf(h, big))
    #expect(h.system.isVisible(big) && !h.system.isVisible(a))
    expectWindowsMatchLayout(h, on: h.display)
  }

  @Test func aGroupTileInTheWayIsEnteredAtTheNearSide() {
    // [ a | b / c ], with the column squeezed until it is a tile: 202 points of its 702.
    let (h, w) = harness(["A", "B", "C"], ["dock $0 left", "dock $1 right", "dock $2 beside $1 bottom"])
    let (a, b, c) = (w[0], w[1], w[2])
    let group = h.workspace.tree.parent(of: leaf(h, b)!)!
    expectOK(h, "resize \(b.rawValue) left -500")
    #expect(h.layout!.tiles.map(\.node) == [group])
    h.system.userFocus(b)
    h.system.userFocus(a)
    expectOK(h, "show-all")  // the clicks took the view along
    #expect(go(h, "right") == b, "of two equals, the one that had focus last")
    #expect(h.workspace.camera == group)
    #expect(h.system.isVisible(b) && h.system.isVisible(c))
  }

  @Test func aTileInsideATileIsEnteredToo() {
    // [ a | x1 / x2 ], the column squeezed into a tile. Framed, the column is still too low for
    // either window, so they are tiles again, and focus goes on into the top one.
    let h = Harness(settings: noRoomMade)
    let a = h.system.open(app: "A", frame: CGRect(x: 100, y: 100, width: 500, height: 400))
    let minimum = CGSize(width: 900, height: 600)
    let x1 = h.system.open(app: "X1", frame: CGRect(x: 200, y: 100, width: 900, height: 600), minimumSize: minimum)
    let x2 = h.system.open(app: "X2", frame: CGRect(x: 300, y: 100, width: 900, height: 600), minimumSize: minimum)
    // Neither of the two has had the keyboard as far as Arbor knows: of two equals it would go to the one that had it last.
    h.system.userFocus(a)
    h.start()
    for command in [
      "dock \(a.rawValue) left", "dock \(x1.rawValue) right", "dock \(x2.rawValue) beside \(x1.rawValue) bottom",
      "resize \(x1.rawValue) left -500",
    ] { expectOK(h, command) }
    #expect(h.layout!.tiles.map(\.kind) == [.group])
    h.system.userFocus(a)
    #expect(go(h, "right") == x1)
    #expect(h.workspace.camera == leaf(h, x1))
    #expect(h.system.isVisible(x1) && !h.system.isVisible(x2) && !h.system.isVisible(a))
    expectWindowsMatchLayout(h, on: h.display)
  }

  /// The Desktop as a tile is still part of the view: what floats on it is in view, over the docked windows, and is a
  /// stop itself. The tile holds nothing more to focus and is passed over.
  @Test func aDesktopTileIsNoStopWhatFloatsOnItIs() {
    let (h, w) = harness(["A", "B"], ["dock $0 left", "dock $1 right", "resize $0 right 250"], settings: .withDesktopColumn)
    let (a, b) = (w[0], w[1])
    #expect(h.layout!.tiles.map(\.kind) == [.desktop])
    h.system.userFocus(a)
    #expect(go(h, "right") == b)

    // (Opened with the Desktop in view: over a view without it, it would be a guest of that view, F57.)
    expectOK(h, "resize \(a.rawValue) right -250")
    let floating = h.system.open(app: "Calculator", frame: CGRect(x: 600, y: 100, width: 300, height: 300))
    expectOK(h, "resize \(a.rawValue) right 250")
    #expect(h.layout!.tiles.map(\.kind) == [.desktop] && h.workspace.guests == nil)
    expectOK(h, "zoom \(a.rawValue)")
    expectOK(h, "back")
    #expect(h.system.isVisible(floating))
    let camera = h.workspace.camera
    h.system.userFocus(b)
    #expect(go(h, "left") == floating)
    #expect(go(h, "left") == a)
    #expect(h.workspace.camera == camera, "the view has not moved")
  }

  @Test func withOnlyTilesInViewTheOneUnderThePointerIsEntered() {
    var settings = Settings()
    settings.minimumUsableHeight = 500
    let (h, w) = harness(["A", "B"], ["dock $0 top", "dock $1 bottom"], settings: settings)
    #expect(h.layout!.windowFrames.isEmpty && h.layout!.tiles.count == 2, "halves of 419 points")
    h.system.focused = nil
    h.system.cursor = h.layout!.tiles.first { $0.windows == [w[1]] }!.frame.center
    #expect(go(h, "left") == w[1])
    #expect(h.workspace.camera == leaf(h, w[1]))
  }

  // MARK: Tab groups

  @Test func onlyTheActiveTabOfAGroupIsAStop() {
    var settings = Settings()
    settings.tabsEnabled = true
    let (h, w) = harness(["A", "B", "C"], ["dock $0 left", "dock $1 right"], settings: settings)
    let (a, b, c) = (w[0], w[1], w[2])
    // Drop c on the middle of b: they share a slot and c shows.
    let start = h.frame(c)!
    h.system.drag(c, through: [CGPoint(x: start.midX, y: start.minY + 10), h.frame(b)!.center])
    #expect(leaf(h, c) == leaf(h, b) && h.workspace.tree.activeWindow(of: leaf(h, b)!) == c)
    h.system.userFocus(a)
    #expect(go(h, "right") == c)
    #expect(go(h, "next") == a)
    #expect(go(h, "previous") == c)
    // Named, the hidden tab is shown.
    expectOK(h, "focus \(b.rawValue)")
    #expect(h.system.focused == b)
    #expect(h.workspace.tree.activeWindow(of: leaf(h, b)!) == b)
    #expect(h.system.isVisible(b) && !h.system.isVisible(c))
  }

  // MARK: next and previous

  @Test func nextAndPreviousCycleInTreeOrderThenThroughTheFloatingWindows() {
    let (h, w) = harness(
      ["A", "B", "C", "F1", "F2"], ["dock $0 left", "dock $1 right", "dock $2 beside $0 bottom"])
    let (a, b, c, f1, f2) = (w[0], w[1], w[2], w[3], w[4])
    h.system.userFocus(a)
    #expect(["next", "next", "next", "next", "next"].map { go(h, $0) } == [c, b, f1, f2, a])
    #expect(["previous", "previous", "previous", "previous", "previous"].map { go(h, $0) } == [f2, f1, b, c, a])
  }

  @Test(arguments: [false, true]) func cyclingVisitsOnlyWhatIsInView(makingWay: Bool) {
    let (h, w) = harness(
      ["A", "B", "C", "D", "F"], ["dock $0 left", "dock $1 right", "dock $2 beside $0 bottom", "dock $3 beside $1 bottom"],
      settings: makingWay ? .makingWay : Settings())
    let (a, c, d, floating) = (w[0], w[2], w[3], w[4])
    h.system.setMinimized(d, true)
    expectOK(h, "zoom-node \(h.workspace.tree.parent(of: leaf(h, a)!)!.rawValue)")
    h.system.userFocus(a)
    #expect(go(h, "next") == c)
    // As Arbor ships what floats is in view wherever the view is, so it has its turn.
    if !makingWay { #expect(go(h, "next") == floating) }
    #expect(go(h, "next") == a, "not b (outside the view), d (minimized) or a floating window that is away with the Desktop")
    #expect(h.workspace.camera == h.workspace.tree.parent(of: leaf(h, a)!))
  }

  @Test func withoutAStartingPointNextIsTheFirstAndPreviousTheLast() {
    let (h, w) = harness(["A", "B", "F"], ["dock $0 left", "dock $1 right"])
    h.system.focused = nil
    #expect(go(h, "next") == w[0])
    h.system.focused = nil
    #expect(go(h, "previous") == w[2])
  }

  // MARK: focus <window>

  @Test(arguments: [false, true]) func namingAWindowBringsItIntoView(makingWay: Bool) {
    let (h, w) = harness(["A", "B", "F"], ["dock $0 left", "dock $1 right", "zoom $0"], settings: makingWay ? .makingWay : Settings())
    let (a, b, floating) = (w[0], w[1], w[2])
    #expect(!h.system.isVisible(b) && h.system.isVisible(floating) == !makingWay)
    expectOK(h, "focus \(b.rawValue)")
    #expect(h.system.focused == b && h.system.isVisible(b))
    expectOK(h, "zoom \(a.rawValue)")
    expectOK(h, "focus \(floating.rawValue)")
    #expect(h.system.focused == floating && h.system.isVisible(floating))
    if makingWay {
      #expect(h.layout!.desktopFrame != nil)
    } else {
      #expect(h.workspace.camera == leaf(h, a), "as Arbor ships it is in view already, and the view stays")
    }

    h.system.setMinimized(b, true)
    #expect(h.run("focus \(b.rawValue)").message == "\(b) is minimized, hidden (⌘H) or on another of the macOS Spaces")
    #expect(!h.run("focus 999").ok)
    #expect(h.system.focused == floating)
  }

  // MARK: Two displays

  /// Main: [ a | b ], with the Desktop between them where it has a column. Side: [ c | Desktop ].
  func twoDisplays(settings: Settings = Harness.settingsWhenNoneAreGiven) -> (Harness, WindowID, WindowID, WindowID) {
    let h = Harness(displays: [FakeWindowSystem.standardDisplay, side], settings: settings)
    let a = h.system.open(app: "A", frame: CGRect(x: 100, y: 100, width: 500, height: 400))
    let b = h.system.open(app: "B", frame: CGRect(x: 300, y: 200, width: 500, height: 400))
    let c = h.system.open(app: "C", frame: CGRect(x: 1600, y: 100, width: 500, height: 400))
    h.start()
    for command in ["dock \(a.rawValue) left", "dock \(b.rawValue) right", "dock \(c.rawValue) left"] { expectOK(h, command) }
    #expect(h.controller.workspaces[side.id]!.isDocked(c))
    return (h, a, b, c)
  }

  @Test func pastTheLastSpaceFocusCrossesToTheNextDisplay() {
    let (h, _, b, c) = twoDisplays()
    let pointer = h.system.cursor
    h.scheduler.advance(by: 1)
    h.system.userFocus(b)
    #expect(h.press("focus right").ok && h.system.focused == c)
    // Shortcuts follow the keyboard (F56), so they now act there, with the pointer where the hand left it.
    #expect(h.press("in").ok)
    #expect(h.controller.workspaces[side.id]!.camera == h.controller.workspaces[side.id]!.tree.leaf(containing: c))
    #expect(h.workspace.camera == h.workspace.tree.root)
    #expect(h.press("out").ok)

    #expect(go(h, "left") == b)
    #expect(h.system.cursor == pointer)
    #expect(!h.run("focus up").ok, "no display lies that way")
  }

  @Test func theCameraMovesBeforeFocusLeavesTheDisplay() {
    let (h, a, b, c) = twoDisplays(settings: Settings())
    expectOK(h, "zoom \(a.rawValue)")
    #expect(go(h, "right") == b)
    #expect(go(h, "right") == c)
  }

  @Test func aDisplayWithNothingToFocusIsPassedOver() {
    let far = DisplaySnapshot(
      id: DisplayID("far"), frame: CGRect(x: 2720, y: 0, width: 1280, height: 800),
      visibleFrame: CGRect(x: 2720, y: 0, width: 1280, height: 800), isMain: false)
    let h = Harness(displays: [FakeWindowSystem.standardDisplay, side, far])
    let a = h.system.open(app: "A", frame: CGRect(x: 100, y: 100, width: 500, height: 400))
    let z = h.system.open(app: "Z", frame: CGRect(x: 3000, y: 100, width: 500, height: 400))
    h.start()
    h.system.userFocus(a)
    #expect(go(h, "right") == z)
    h.system.close(z)
    h.system.userFocus(a)
    #expect(!h.run("focus right").ok)
  }

  @Test func theDisplayTheKeyboardIsOnCountsNotThePointers() {
    let (h, a, b, _) = twoDisplays()
    h.system.userFocus(a)
    h.system.cursor = CGPoint(x: 2000, y: 400)
    #expect(go(h, "right") == b)
    #expect(go(h, "next") == a)
  }

  @Test func aTileOnTheNextDisplayIsEntered() {
    let (h, _, b, c) = twoDisplays()
    h.system.setMinimumSize(c, CGSize(width: 1000, height: 600))
    expectOK(h, "resize \(c.rawValue) right -40")  // asked to shrink, it refuses and becomes a tile
    #expect(h.controller.layouts[side.id]!.tiles.map(\.windows) == [[c]])
    h.system.userFocus(b)
    #expect(go(h, "right") == c)
    #expect(h.system.isVisible(c))
  }

  // MARK: Bookkeeping

  @Test func focusCommandsAreRememberedAndAnnouncedLikeClicks() {
    let (h, a, b, _) = columns()
    h.system.userFocus(a)
    var changes: [Controller.Change] = []
    h.controller.observe { changes.append($0) }
    #expect(go(h, "right") == b)
    #expect(changes.contains(.focus(b)))
    #expect(!changes.contains { if case .layout = $0 { true } else { false } })
    // a had focus more recently than c: going back left picks a.
    #expect(go(h, "left") == a)
  }

  /// macOS needs a moment to make a request for focus true. A second key pressed within it goes on from
  /// where the first one was headed, not from the window macOS still reports.
  @Test func keysPressedFasterThanMacOSMovesFocusAreNotLost() {
    let (h, w) = harness(["A", "B", "C"], ["dock $0 left", "dock $1 beside $0 right", "dock $2 beside $1 right", "equalize"])
    let (a, b, c) = (w[0], w[1], w[2])
    h.system.userFocus(a)
    h.system.focusIsSlow = true
    expectOK(h, "focus right")
    #expect(h.system.focused == a && h.system.slowFocus == b)
    expectOK(h, "focus right")
    #expect(h.system.slowFocus == c)
    // Other commands that act on the focused window mean that one too.
    #expect(expectOK(h, "swap left").message == "swapped \(c) with \(b)")
    h.system.finishSlowFocus()
    #expect(h.system.focused == c)
    expectOK(h, "focus right")
    #expect(h.system.slowFocus == b, "b is on the right now")
  }

  /// Whoever asks macOS for the keyboard past the door leaves `keyboardFocus()` with the request before, or with none: for the next key, within
  /// those hundredths of a second, the keyboard is then with a window Arbor itself has overruled. So nobody does.
  @Test func everyRequestForTheKeyboardGoesThroughTheDoor() throws {
    let folder = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
      .appendingPathComponent("Sources/ArborKit/Controller")
    let files = try FileManager.default.contentsOfDirectory(atPath: folder.path).filter { $0.hasSuffix(".swift") }.sorted()
    #expect(files.count > 50, "the controller's sources are where they were")
    var past: [String] = []
    for file in files where file != "Controller+KeyboardFocus.swift" {
      let text = try String(contentsOf: folder.appendingPathComponent(file), encoding: .utf8)
      for (number, line) in text.split(separator: "\n", omittingEmptySubsequences: false).enumerated()
      where line.contains("system.focus(") && !line.trimmingCharacters(in: .whitespaces).hasPrefix("//") {
        past.append("\(file):\(number + 1)")
      }
    }
    #expect(past.isEmpty, "use askForTheKeyboard(for:), or giveFocus(to:): \(past)")
  }

  /// ⌘Tab to an app whose focused window is the same as ever: macOS says that the keyboard has moved and not where to. The request
  /// that was on its way is over all the same.
  @Test func aRequestIsOverWhenMacOSNamesSomebodyNobodyAskedFor() {
    let (h, w) = harness(["A", "B", "C"], ["dock $0 left", "dock $1 beside $0 right", "dock $2 beside $1 right", "equalize"])
    let (a, b, c) = (w[0], w[1], w[2])
    h.system.userFocus(a)
    h.system.focusIsSlow = true
    expectOK(h, "focus right")
    #expect(h.system.focusRequests.last == b)
    h.system.userSwitchesApp(to: c)
    #expect(expectOK(h, "swap left").message == "swapped \(c) with \(b)", "not b, which was only asked for")
  }

  /// Found by the random run. Whoever moves the keyboard after the request has the last word, at once.
  @Test func aRequestForFocusIsOverWhenTheKeyboardGoesSomewhereElse() {
    let (h, w) = harness(["A", "B", "C"], ["dock $0 left", "dock $1 beside $0 right", "dock $2 beside $1 right", "equalize"])
    let (a, b, c) = (w[0], w[1], w[2])
    // The user clicks another window.
    h.system.userFocus(a)
    h.system.focusIsSlow = true
    expectOK(h, "focus right")
    #expect(h.system.slowFocus == b)
    h.system.userFocus(c)
    #expect(expectOK(h, "swap left").message == "swapped \(c) with \(b)", "not b, which was only asked for")
    expectOK(h, "swap right")

    // Another command asks for another window, and macOS gets there.
    h.system.focusIsSlow = false
    h.system.userFocus(a)
    h.system.focusIsSlow = true
    expectOK(h, "focus right")
    expectOK(h, "dock \(c.rawValue) left")
    #expect(h.system.slowFocus == c)
    h.system.finishSlowFocus()
    #expect(expectOK(h, "swap right").message == "swapped \(c) with \(b)", "b is on the right now")
  }

  /// macOS reports every change it was asked for, in order. Word of an earlier request says nothing about the latest.
  @Test func wordOfAnEarlierRequestDoesNotEndTheLatest() {
    let (h, w) = harness(["A", "B", "C"], ["dock $0 left", "dock $1 beside $0 right", "dock $2 beside $1 right", "equalize"])
    let (a, b, c) = (w[0], w[1], w[2])
    h.system.userFocus(a)
    h.system.focusIsSlow = true
    expectOK(h, "focus right")
    expectOK(h, "focus right")
    #expect(h.system.slowFocus == c)
    h.system.userFocus(b)  // what the first request looks like when it comes true
    #expect(h.run("focus right").message == "no window or space to the right", "the keyboard is as good as on c")
    #expect(expectOK(h, "swap left").message == "swapped \(c) with \(b)")
  }

  @Test func aRequestForFocusThatNeverComesTrueIsForgotten() {
    let (h, w) = harness(["A", "B", "C"], ["dock $0 left", "dock $1 beside $0 right", "dock $2 beside $1 right", "equalize"])
    let (a, b) = (w[0], w[1])
    h.system.userFocus(a)
    h.system.focusIsSlow = true
    expectOK(h, "focus right")
    h.scheduler.advance(by: 1)
    expectOK(h, "focus right")
    #expect(h.system.slowFocus == b, "macOS still says a, and by now that counts")

    // Nor does it outlive its window.
    h.system.close(b)
    #expect(h.run("focus left").message == "no window or space to the left")
  }

  @Test func aClosedWindowIsNoLongerAStop() {
    let (h, a, b, c) = columns()
    h.system.userFocus(c)
    h.system.userFocus(b)
    h.system.close(c)
    #expect(go(h, "left") == a)
    #expect(go(h, "next") == b)
    #expect(go(h, "next") == a)
  }

  @Test func theDefaultKeysAreTheOnesOnTheKeyboardMap() throws {
    let expected: [(String, Command)] = [
      ("⌃⌥⇧←", .focus(.direction(.left))), ("⌃⌥⇧→", .focus(.direction(.right))), ("⌃⌥⇧↑", .focus(.direction(.top))),
      ("⌃⌥⇧↓", .focus(.direction(.bottom))), ("⌃⌥⌘=", .grow(nil)), ("⌃⌥⌘-", .shrink(nil)),
      ("⌃⌥⌘0", .equalize(all: false)), ("⌃⌥R", .rotate), ("⌃⌥⇧R", .mirror),
    ]
    for (label, command) in expected {
      #expect(KeyBindings.label(for: command, in: KeyBindings.all) == label, "\(command.text)")
    }
    // Left to `bindings`: the vi keys, swap, cycling and the display commands.
    for text in ["ctrl+opt+h", "ctrl+opt+j", "ctrl+opt+k", "ctrl+opt+l"] {
      let chord = try KeyChord(text: text)
      #expect(!KeyBindings.all.contains { $0.chord == chord })
    }
    for command: Command in [.swap(nil, .left), .focus(.next), .focusDisplay(.next), .moveToDisplay(.next, nil)] {
      #expect(KeyBindings.label(for: command, in: KeyBindings.all) == nil)
    }
    // The recipe in the README works.
    var settings = Settings()
    settings.bindings = ["ctrl+opt+h": "focus left", "ctrl+opt+shift+h": "swap left", "ctrl+opt+o": "focus-display next"]
    let (bindings, problems) = KeyBindings.effective(settings: settings)
    #expect(problems.isEmpty)
    #expect(KeyBindings.label(for: .swap(nil, .left), in: bindings) == "⌃⌥⇧H")
  }
}
