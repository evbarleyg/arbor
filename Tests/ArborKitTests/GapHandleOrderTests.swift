import ArborCore
import ArborKit
import ArborTesting
import CoreGraphics
import Foundation
import Testing

/// The same walk every time.
private struct SplitMix: RandomNumberGenerator {
  var state: UInt64
  mutating func next() -> UInt64 {
    state &+= 0x9E37_79B9_7F4A_7C15
    var z = state
    z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
    z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
    return z ^ (z >> 31)
  }
}

/// Where a gap's handle lies among the windows: just below the rearmost of its two neighbours. What lies behind both shows
/// through the gap and does not get the press meant for it; what lies in front of either keeps its clicks.
/// The controller names the window (`Seam.liesBelow`), and whoever draws the handle obeys.
@Suite @MainActor struct GapHandleOrderTests {
  /// `left` and `right` docked side by side, whatever else has a column, and a floating window that was there before either.
  func makeHarness(
    displays: [DisplaySnapshot] = [FakeWindowSystem.standardDisplay], oneApp: Bool = false
  ) -> (Harness, left: WindowID, right: WindowID, floating: WindowID) {
    let h = Harness(displays: displays)
    let floating = h.system.open(app: "Notes", pid: 1001, frame: CGRect(x: 170, y: 220, width: 480, height: 348))
    let left = h.system.open(app: "Editor", pid: 1002)
    let right = h.system.open(app: oneApp ? "Editor" : "Browser", pid: oneApp ? 1002 : 1003)
    h.start()
    h.run("dock \(left.rawValue) left")
    h.run("dock \(right.rawValue) beside \(left.rawValue) right")
    settle(h)
    return (h, left, right, floating)
  }

  /// Lets what Arbor put off until the command or event was over happen, and its later looks at the stacking.
  func settle(_ h: Harness) { h.scheduler.advance(by: 1) }

  /// Only what Arbor put off until the command or event was over.
  func finishEvent(_ h: Harness) { h.scheduler.advance(by: 0) }

  /// The gap that has `first` on one side and `second` on the other, as it was last shown.
  func gap(_ h: Harness, between first: WindowID, and second: WindowID, on display: DisplayID? = nil) throws -> Seam {
    let display = display ?? h.display
    let slots = try #require(h.controller.layouts[display]).windowFrames
    return try #require(
      h.overlays.scenes[display]?.seams.first {
        let (leading, trailing) = $0.neighbours(among: slots)
        return Set(leading + trailing) == [first, second]
      })
  }

  /// The Dock's icon, ⌘Tab: the app's windows come forward in one go, in the order they had, and what is heard of it is heard afterwards.
  func comeForwardTogether(_ frontToBack: [WindowID], _ h: Harness) {
    for window in frontToBack.dropFirst().reversed() { h.system.raise(window) }
    h.system.userSwitchesApp(to: frontToBack[0])
  }

  /// How many windows lie in front of this one.
  func depth(_ window: WindowID, _ h: Harness) throws -> Int {
    try #require(h.system.windowsFrontToBack().firstIndex(of: window))
  }

  func seen(_ h: Harness, on display: DisplayID? = nil) -> Int { h.overlays.scenes[display ?? h.display]?.stackingSeen ?? -1 }

  // MARK: Which window it names

  @Test func whatLiesBehindBothNeighboursLiesBehindTheHandleToo() throws {
    let (h, left, right, floating) = makeHarness()
    let below = try #require(try gap(h, between: left, and: right).liesBelow)
    #expect([left, right].contains(below))
    #expect(try depth(below, h) == max(try depth(left, h), try depth(right, h)))
    #expect(try depth(floating, h) > depth(below, h))
    expectWindowsMatchLayout(h)
  }

  @Test func whatLiesInFrontOfEitherNeighbourLiesInFrontOfTheHandle() throws {
    let (h, left, right, floating) = makeHarness()
    h.system.userClick(floating)
    settle(h)
    let below = try #require(try gap(h, between: left, and: right).liesBelow)
    #expect([left, right].contains(below))
    #expect(try depth(floating, h) < depth(below, h))

    // Between the two it is in front of one of them.
    h.system.userClick(left)
    h.system.userClick(floating)
    h.system.userClick(right)
    settle(h)
    #expect(h.system.windowsFrontToBack().prefix(3) == [right, floating, left])
    #expect(try gap(h, between: left, and: right).liesBelow == left)
  }

  @Test func theHandleFollowsWhicheverNeighbourIsFurtherBack() throws {
    let (h, left, right, _) = makeHarness()
    h.system.userClick(left)
    settle(h)
    #expect(try gap(h, between: left, and: right).liesBelow == right)
    h.system.userClick(right)
    settle(h)
    #expect(try gap(h, between: left, and: right).liesBelow == left)
  }

  /// [only | Desktop]: what lies on the Desktop lies in plain view, across the gap too, and is meant by whoever presses there.
  @Test func aGapWithNoWindowOnOneSideKeepsItsHandleBehindEverything() throws {
    let h = Harness()
    let only = h.system.open(app: "Editor", pid: 1001)
    h.start()
    h.run("dock \(only.rawValue) left")
    settle(h)
    let seams = try #require(h.overlays.scenes[h.display]?.seams)
    #expect(!seams.isEmpty)
    #expect(seams.allSatisfy { $0.liesBelow == nil })
  }

  /// [left | (right over a tile)]: what stands where no window is stands in plain view.
  @Test func aGapWithATileAlongPartOfASideToo() throws {
    let (h, left, right, _) = makeHarness()
    let wide = h.system.open(app: "Mail", pid: 1004)
    h.system.setMinimumSize(wide, CGSize(width: 1350, height: 300))
    h.run("dock \(wide.rawValue) beside \(right.rawValue) bottom")
    settle(h)
    try #require(h.layout?.tiles.contains { $0.windows == [wide] } == true)
    #expect(try gap(h, between: left, and: right).liesBelow == nil)
  }

  @Test func whereTheStackingCannotBeToldTheHandleStaysBehindEverything() throws {
    let (h, left, right, _) = makeHarness()
    h.system.stackingIsUnknown = true
    h.system.userClick(left)
    settle(h)
    #expect(try gap(h, between: left, and: right).liesBelow == nil)
  }

  // MARK: When Arbor looks

  /// The handle would still name the same window, and be left behind by it: the floating window would lie over the handle and
  /// under both neighbours.
  @Test func neighboursThatComeForwardTogetherTakeTheirHandleAlong() throws {
    let (h, left, right, floating) = makeHarness(oneApp: true)
    h.system.userClick(left)
    h.system.userClick(right)
    h.system.userClick(floating)
    settle(h)
    #expect(try gap(h, between: left, and: right).liesBelow == left)
    let before = seen(h)

    comeForwardTogether([right, left], h)
    settle(h)
    #expect(h.system.windowsFrontToBack().prefix(3) == [right, left, floating])
    #expect(try gap(h, between: left, and: right).liesBelow == left)
    #expect(seen(h) > before)
  }

  /// A clicked window takes the keyboard first and comes to the front afterwards, and nothing reports the second.
  @Test func aWindowThatComesToTheFrontLateIsStillSeen() throws {
    let (h, left, right, _) = makeHarness()
    h.system.userClick(right)
    settle(h)
    #expect(try gap(h, between: left, and: right).liesBelow == left)

    h.system.mouseDown = true
    h.controller.pointerPressed()
    finishEvent(h)
    #expect(try gap(h, between: left, and: right).liesBelow == left)
    // However long the button is held: a click is not over until it is up.
    h.scheduler.advance(by: 2)
    h.system.raise(left)
    h.system.mouseDown = false
    settle(h)
    #expect(try gap(h, between: left, and: right).liesBelow == right)
  }

  /// `side-by-side` lays out first and brings its windows forward afterwards, which no app reports; and of the keyboard nothing is
  /// reported either where the first of them has it already. The handle names the same window before and after.
  @Test func windowsThatArborItselfBringsForwardTakeTheirHandleAlong() throws {
    let (h, left, right, floating) = makeHarness()
    h.system.userClick(right)
    h.system.userClick(floating)
    h.system.userClick(left)
    settle(h)
    #expect(h.system.stackedWindows().map(\.id).prefix(3) == [left, floating, right])
    #expect(try gap(h, between: left, and: right).liesBelow == right)
    let before = seen(h)

    h.run("side-by-side \(left.rawValue) \(right.rawValue)")
    settle(h)
    #expect(h.system.stackedWindows().map(\.id).prefix(3) == [left, right, floating])
    #expect(try gap(h, between: left, and: right).liesBelow == right)
    #expect(seen(h) > before)
    #expect(h.controller.stackingSeenForHandles.frontToBack == h.system.stackedWindows().map(\.id))
    expectWindowsMatchLayout(h)
  }

  /// One of the two was in the Dock and is asked back first: it is brought forward when it has come, from a timer, with nothing to report.
  @Test func soDoThoseThatHadToBeAskedBackFirst() throws {
    let (h, left, right, floating) = makeHarness()
    h.system.setMinimized(right, true)
    h.system.userClick(floating)
    h.system.userClick(left)
    settle(h)

    h.run("side-by-side \(left.rawValue) \(right.rawValue)")
    h.scheduler.advance(by: 5)
    let order = h.system.stackedWindows().map(\.id)
    #expect(Set(order.prefix(2)) == [left, right] && order.last == floating)
    #expect(try gap(h, between: left, and: right).liesBelow == order[1])
    #expect(h.controller.stackingSeenForHandles.frontToBack == order)
    #expect(seen(h) == h.controller.stackingSeenForHandles.changes)
    expectWindowsMatchLayout(h)
  }

  /// A text is selected, a window carried about: the list of windows is not read five times a second all the while.
  @Test func aButtonHeldDownIsWorthOneLook() throws {
    let (h, _, _, _) = makeHarness()
    h.system.mouseDown = true
    h.controller.pointerPressed()
    finishEvent(h)
    let before = h.system.stackedWindowsReads
    h.scheduler.advance(by: 10)
    #expect(h.system.stackedWindowsReads == before)
    #expect(h.scheduler.pendingKeys.contains("order-handles"), "nothing tells that the button came up, so Arbor goes on asking")
    h.system.mouseDown = false
    settle(h)
    #expect(h.system.stackedWindowsReads > before)
    #expect(!h.scheduler.pendingKeys.contains("order-handles"))
  }

  @Test func aLookThatFindsTheOrderItKnowsShowsNothingAgain() throws {
    let (h, left, _, _) = makeHarness()
    h.system.userClick(left)
    settle(h)
    let shown = h.overlays.updateLog.count
    let before = seen(h)
    h.system.userClick(left)
    settle(h)
    #expect(h.overlays.updateLog.count == shown)
    #expect(seen(h) == before)
  }

  /// The window server lists what Arbor does not arrange and has never heard of: a dialog, a palette, a window of an app that is not
  /// observed. It gets between a window and its handle like any other.
  @Test func aWindowArborKnowsNothingOfCountsLikeAnyOther() throws {
    let (h, left, _, _) = makeHarness()
    h.system.userClick(left)
    settle(h)
    let before = seen(h)
    h.system.strangers = [StackedWindow(id: WindowID(9001), frame: CGRect(x: 200, y: 200, width: 300, height: 200))]
    h.system.click()
    settle(h)
    #expect(seen(h) > before)
  }

  @Test func arborStopsLooking() throws {
    let (h, left, _, _) = makeHarness()
    h.system.userClick(left)
    #expect(h.scheduler.pendingKeys.contains("order-handles"))
    settle(h)
    #expect(!h.scheduler.pendingKeys.contains("order-handles"))
  }

  @Test func withNoGapNothingIsLookedAfter() throws {
    let h = Harness()
    let only = h.system.open(app: "Editor", pid: 1001)
    h.start()
    settle(h)
    h.system.userClick(only)
    #expect(!h.scheduler.pendingKeys.contains("order-handles"))
  }

  @Test func withGapsThatCannotBeDraggedNeither() throws {
    let (h, left, _, _) = makeHarness()
    h.run("set gapHandles off")
    settle(h)
    let before = h.system.stackedWindowsReads
    h.system.userClick(left)
    #expect(!h.scheduler.pendingKeys.contains("order-handles"))
    settle(h)
    #expect(h.system.stackedWindowsReads == before)
  }

  /// One order for all displays: a look made for the sake of one display's gaps is news for the other's.
  @Test func everyDisplaysGapsHearOfAnotherOrder() throws {
    let (h, left, right, _) = makeHarness(displays: [FakeWindowSystem.standardDisplay, sideDisplay])
    let far = h.system.open(app: "Mail", pid: 1004, frame: CGRect(x: 1500, y: 100, width: 400, height: 300))
    let farther = h.system.open(app: "Music", pid: 1005, frame: CGRect(x: 1600, y: 100, width: 400, height: 300))
    h.run("dock \(far.rawValue) left")
    h.run("dock \(farther.rawValue) beside \(far.rawValue) right")
    settle(h)
    #expect(seen(h) == seen(h, on: sideDisplay.id))

    h.system.userClick(far)
    settle(h)
    #expect(try gap(h, between: far, and: farther, on: sideDisplay.id).liesBelow == farther)
    #expect(seen(h) == seen(h, on: sideDisplay.id))
    h.system.userClick(left)
    settle(h)
    #expect(try gap(h, between: left, and: right).liesBelow == right)
    #expect(try gap(h, between: far, and: farther, on: sideDisplay.id).liesBelow == farther)
    #expect(seen(h) == seen(h, on: sideDisplay.id))
  }

  // MARK: What comes of obeying

  /// A panel that obeys as the one on a Mac does (`SeamPanel.show`): it goes just below the window its model names when the model is
  /// another or the windows have been seen in another order, and else stays where it is, while windows come forward past it.
  @MainActor final class ObedientHandle {
    /// The windows the handle lies over.
    var covers: Set<WindowID> = []
    private var shown: (seam: Seam, seen: Int)?

    func obey(_ seam: Seam, seen: Int, order: [WindowID]) {
      if let shown, shown.seam == seam, shown.seen == seen { return }
      shown = (seam, seen)
      covers = seam.liesBelow.flatMap { order.firstIndex(of: $0) }.map { Set(order[($0 + 1)...]) } ?? []
    }
  }

  /// Whatever is clicked and in whatever order: at rest the handle lies over all that is behind both neighbours, and over nothing else.
  @Test(arguments: [false, true]) func afterAnyClicksTheHandleLiesOverWhatIsBehindBothAndNothingElse(oneApp: Bool) throws {
    let (h, left, right, floating) = makeHarness(oneApp: oneApp)
    let other = h.system.open(app: "Mail", pid: 1004, frame: CGRect(x: 200, y: 300, width: 400, height: 300))
    settle(h)
    let handle = ObedientHandle()
    func obey(_ scene: OverlayScene) {
      let slots = h.layout?.windowFrames ?? [:]
      let between = scene.seams.first {
        let (leading, trailing) = $0.neighbours(among: slots)
        return Set(leading + trailing) == [left, right]
      }
      guard let seam = between else { return }
      handle.obey(seam, seen: scene.stackingSeen, order: h.system.stackedWindows().map(\.id))
    }
    obey(try #require(h.overlays.scenes[h.display]))
    h.overlays.onCall = { if case .update(_, let scene) = $0 { obey(scene) } }

    var random = SplitMix(state: oneApp ? 193 : 1093)
    var told: [String] = []
    for _ in 1...300 {
      switch Int.random(in: 0..<6, using: &random) {
      case 0...3:
        let window = [left, right, floating, other].randomElement(using: &random)!
        told.append("click \(window.rawValue)")
        handle.covers.remove(window)
        h.system.userClick(window)
      case 4:
        let both = h.system.stackedWindows().map(\.id).filter { [left, right].contains($0) }
        told.append("both forward")
        handle.covers.subtract(both)
        comeForwardTogether(both, h)
      default:
        let window = [floating, other].randomElement(using: &random)!
        told.append("switch to \(window.rawValue)")
        handle.covers.remove(window)
        h.system.userSwitchesApp(to: window)
      }
      settle(h)
      let order = h.system.stackedWindows().map(\.id)
      let rearmost = max(try depth(left, h), try depth(right, h))
      #expect(handle.covers == Set(order[(rearmost + 1)...]), "after \(told.suffix(6).joined(separator: ", "))")
    }
  }

  /// Dragging a gap lays out with every move of the mouse. No order changes by it, and the window list is not cheap to read.
  @Test func draggingAGapAsksForNoOrderWithEveryMove() throws {
    let (h, left, right, _) = makeHarness()
    let seam = try gap(h, between: left, and: right)
    h.system.mouseDown = true
    h.controller.pointerPressed()
    finishEvent(h)
    let before = h.system.stackedWindowsReads
    for _ in 1...20 { h.overlays.dragSeam(try gap(h, between: left, and: right), by: -2) }
    #expect(h.system.stackedWindowsReads == before)
    #expect(try gap(h, between: left, and: right).frame.minX == seam.frame.minX - 40)
    h.system.mouseDown = false
    settle(h)
    #expect([left, right].contains(try #require(try gap(h, between: left, and: right).liesBelow)))
    expectWindowsMatchLayout(h)
  }
}
