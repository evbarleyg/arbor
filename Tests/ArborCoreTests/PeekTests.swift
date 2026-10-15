import ArborCore
import CoreGraphics
import Foundation
import Testing

/// Peek: hold to look, let go to land (docs/features/F51-peek.md). The decisions, without a controller.
@Suite struct PeekTests {
  private let root = NodeID(0)
  private let origin = NodeID(1)
  private let other = NodeID(2)
  private let third = NodeID(3)
  private let rest = CGPoint(x: 100, y: 100)
  private let away = CGPoint(x: 600, y: 300)

  /// The shortcut went down at time 0 with `origin` framed and the pointer at `rest`.
  private func pressed(from view: NodeID? = nil, buttonDown: Bool = false) -> Peek {
    Peek(origin: view ?? origin, root: root, at: 0, pointer: rest, buttonDown: buttonDown)
  }

  /// The same, held past the threshold.
  private func held(from view: NodeID? = nil, buttonDown: Bool = false) -> Peek {
    var peek = pressed(from: view, buttonDown: buttonDown)
    #expect(peek.look(at: 0.35, pointer: rest, under: view ?? origin, buttonDown: buttonDown) == nil)
    #expect(peek.phase == .holding)
    return peek
  }

  // MARK: Tap or hold

  @Test func aTapStaysOnEverything() {
    var peek = pressed()
    #expect(peek.released(at: 0.12) == .stay)
    #expect(peek.phase == .over)
  }

  @Test func nothingDiffersFromAPlainPressUntilTheThreshold() {
    var peek = pressed()
    #expect(peek.look(at: 0.2, pointer: away, under: other) == nil)
    #expect(peek.phase == .pressed)
    #expect(peek.shownOutline == nil)
    #expect(!peek.takesKeys)
    #expect(peek.escape() == nil)
    peek.arrow(to: other, pointer: rest)
    #expect(peek.released(at: 0.25) == .stay)
  }

  /// What is bound to nothing is kept from the app in front for as long as the keys are down, whatever the peek makes of it meanwhile.
  @Test func theKeysAreKeptFromThePressUntilTheKeysAreUp() {
    var peek = pressed()
    #expect(peek.keepsKeys && !peek.takesKeys, "too early to tell a tap from a hold")
    #expect(peek.look(at: 0.4, pointer: rest, under: nil) == nil)
    #expect(peek.keepsKeys && peek.takesKeys, "held")
    #expect(peek.escape() == .goBack)
    #expect(peek.keepsKeys && !peek.takesKeys, "decided, and the keys still down")
    #expect(peek.released(at: 0.9) == nil)
    #expect(!peek.keepsKeys)
    var tap = pressed()
    #expect(tap.released(at: 0.1) == .stay)
    #expect(!tap.keepsKeys)
  }

  /// Whoever presses an arrow with the key down is holding it.
  @Test func aKeyOfThePeeksBeginsTheHoldEarly() {
    var peek = pressed()
    peek.heldForAKey()
    #expect(peek.phase == .holding)
    peek.arrow(to: other, pointer: rest)
    #expect(peek.released(at: 0.2) == .land(other), "well before the threshold")
    var spent = held()
    #expect(spent.escape() == .goBack)
    spent.heldForAKey()
    #expect(spent.phase == .spent, "it begins nothing anew")
  }

  @Test func heldPastTheThresholdTheViewThatWasLeftIsOutlined() {
    let peek = held()
    #expect(peek.shownOutline == origin)
    #expect(peek.takesKeys)
  }

  @Test func heldAndReleasedWithoutMovingGoesBack() {
    var peek = held()
    #expect(peek.released(at: 1.5) == .goBack)
    #expect(peek.phase == .over)
  }

  @Test func aReleaseHeardBeforeALateTimerStillCountsAsAHold() {
    var peek = pressed()
    #expect(peek.released(at: 1.2) == .goBack)
  }

  /// The product owner's rule: the first way home must not spring back for a slow press.
  @Test func aSlowPressInWhichNothingWasChosenIsATap() {
    for time in [0.31, 0.35, 0.6, 0.99] {
      var peek = held()
      #expect(peek.released(at: max(time, 0.36)) == .stay, "\(time)")
      #expect(peek.phase == .over)
      var late = pressed()
      #expect(late.released(at: time) == .stay, "the timer is late, \(time)")
      var modifiersFirst = held()
      #expect(modifiersFirst.look(at: max(time, 0.36), pointer: rest, under: other, stillHeld: false) == .stay)
    }
    var long = held()
    #expect(long.released(at: 1) == .goBack, "from a second on it was a look")
  }

  @Test func aSlowPressInWhichSomethingWasChosenIsAPeekHoweverShort() {
    var pointed = held()
    #expect(pointed.look(at: 0.4, pointer: away, under: other) == nil)
    #expect(pointed.released(at: 0.5) == .land(other))

    var pointedBack = held()
    #expect(pointedBack.look(at: 0.4, pointer: away, under: other) == nil)
    #expect(pointedBack.look(at: 0.5, pointer: rest, under: origin) == nil)
    #expect(pointedBack.released(at: 0.6) == .goBack, "chosen, and the choice was to go back")

    var overAGap = held()
    #expect(overAGap.look(at: 0.4, pointer: away, under: nil) == nil)
    #expect(overAGap.released(at: 0.6) == .goBack, "the hand was looking for something")

    var keyed = held()
    keyed.arrow(to: third, pointer: rest)
    #expect(keyed.released(at: 0.5) == .land(third))

    var nowhere = held()
    nowhere.arrow(to: nil, pointer: rest)
    #expect(nowhere.released(at: 0.5) == .goBack)

    var escaped = held()
    #expect(escaped.escape() == .goBack, "⎋ says so in as many words")
  }

  // MARK: The pointer

  @Test func aPointerThatMovesOverASpaceOutlinesItAndLettingGoLandsThere() {
    var peek = held()
    #expect(peek.look(at: 0.5, pointer: away, under: other) == nil)
    #expect(peek.shownOutline == other)
    #expect(peek.released(at: 0.8) == .land(other))
    #expect(peek.phase == .over)
  }

  @Test func aPointerAtRestOverAnotherSpaceChoosesNothing() {
    var peek = pressed()
    #expect(peek.look(at: 0.35, pointer: rest, under: other) == nil)
    #expect(peek.look(at: 0.7, pointer: rest, under: other) == nil)
    #expect(peek.shownOutline == origin)
    #expect(peek.released(at: 1) == .goBack)
  }

  @Test func aHandRestingOnTheMouseIsNotAMove() {
    var peek = held()
    #expect(peek.look(at: 0.5, pointer: CGPoint(x: rest.x + 3, y: rest.y - 4), under: other) == nil)
    #expect(peek.shownOutline == origin)
    #expect(peek.look(at: 0.6, pointer: CGPoint(x: rest.x + 5, y: rest.y), under: other) == nil)
    #expect(peek.shownOutline == other)
  }

  @Test func movementBeforeTheThresholdCounts() {
    var peek = pressed()
    #expect(peek.look(at: 0.1, pointer: away, under: other) == nil)
    #expect(peek.look(at: 0.35, pointer: away, under: other) == nil)
    #expect(peek.shownOutline == other)
  }

  @Test func overAGapTheOutlineStaysWhereItWas() {
    var peek = held()
    #expect(peek.look(at: 0.5, pointer: away, under: other) == nil)
    #expect(peek.look(at: 0.6, pointer: CGPoint(x: 700, y: 300), under: nil) == nil)
    #expect(peek.shownOutline == other)
  }

  @Test func pointingBackAtTheViewThatWasLeftGoesBack() {
    var peek = held()
    #expect(peek.look(at: 0.5, pointer: away, under: other) == nil)
    #expect(peek.look(at: 0.7, pointer: rest, under: origin) == nil)
    #expect(peek.released(at: 0.9) == .goBack)
  }

  // MARK: The arrow keys and ⎋

  @Test func anArrowMovesTheOutlineAndThePointerHasToMoveToTakeItBack() {
    var peek = held()
    #expect(peek.look(at: 0.5, pointer: away, under: other) == nil)
    peek.arrow(to: third, pointer: away)
    #expect(peek.shownOutline == third)
    #expect(peek.look(at: 0.6, pointer: away, under: other) == nil)
    #expect(peek.shownOutline == third, "the pointer is still over the other space, and still")
    #expect(peek.look(at: 0.7, pointer: CGPoint(x: away.x + 20, y: away.y), under: other) == nil)
    #expect(peek.shownOutline == other)
  }

  @Test func anArrowBeforeTheHoldOrAfterTheEndMovesNothing() {
    var early = pressed()
    early.arrow(to: other, pointer: rest)
    #expect(early.look(at: 0.35, pointer: rest, under: origin) == nil)
    #expect(early.shownOutline == origin, "the arrow ran its own command; the outline starts where it always does")
    var late = held()
    #expect(late.escape() == .goBack)
    late.arrow(to: other, pointer: rest)
    #expect(late.outline == origin)
  }

  @Test func aPointerThatMovedByTheSlopExactlyIsStillAtRest() {
    var peek = held()
    #expect(peek.look(at: 0.5, pointer: CGPoint(x: rest.x + Peek.pointerSlop, y: rest.y - Peek.pointerSlop), under: other) == nil)
    #expect(peek.shownOutline == origin)
    #expect(peek.look(at: 0.6, pointer: CGPoint(x: rest.x + Peek.pointerSlop + 0.5, y: rest.y), under: other) == nil)
    #expect(peek.shownOutline == other)
  }

  @Test func afterAnArrowThePointersSlopIsCountedFromWhereItIsNow() {
    var peek = held()
    // The hand drifts three points, an arrow is pressed, it drifts three more: six from the start, still at rest.
    let drifted = CGPoint(x: rest.x + 3, y: rest.y)
    #expect(peek.look(at: 0.5, pointer: drifted, under: other) == nil)
    peek.arrow(to: third, pointer: drifted)
    #expect(peek.look(at: 0.6, pointer: CGPoint(x: rest.x + 6, y: rest.y), under: other) == nil)
    #expect(peek.shownOutline == third)
  }

  @Test func lettingGoLandsWhereTheArrowsLed() {
    var peek = held()
    peek.arrow(to: other, pointer: rest)
    peek.arrow(to: third, pointer: rest)
    #expect(peek.released(at: 1) == .land(third))
  }

  @Test func anArrowThatLeadsNowhereLeavesTheOutline() {
    var peek = held()
    peek.arrow(to: other, pointer: rest)
    peek.arrow(to: nil, pointer: rest)
    #expect(peek.shownOutline == other)
  }

  @Test func escapeGoesBackAndTheReleaseThatFollowsDoesNothing() {
    var peek = held()
    #expect(peek.look(at: 0.5, pointer: away, under: other) == nil)
    #expect(peek.escape() == .goBack)
    #expect(peek.phase == .spent)
    #expect(peek.shownOutline == nil)
    #expect(!peek.takesKeys)
    #expect(peek.look(at: 0.7, pointer: rest, under: third) == nil)
    #expect(peek.released(at: 0.9) == nil)
    #expect(peek.phase == .over)
  }

  // MARK: A click

  @Test func aClickLandsAtOnceAndTheReleaseThatFollowsDoesNothing() {
    var peek = held()
    #expect(peek.look(at: 0.5, pointer: away, under: other) == nil)
    #expect(peek.look(at: 0.6, pointer: away, under: other, buttonDown: true) == nil)
    #expect(peek.look(at: 0.7, pointer: away, under: other, buttonDown: false) == .land(other))
    #expect(peek.phase == .spent)
    #expect(peek.released(at: 1) == nil)
  }

  @Test func aClickOnTheOutlineLandsEvenIfNoTickSawTheButton() {
    var peek = held()
    #expect(peek.look(at: 0.5, pointer: away, under: other) == nil)
    #expect(peek.clicked() == .land(other))
    #expect(peek.phase == .spent)
    #expect(peek.clicked() == nil, "once")
    // The timer catches up with the button.
    #expect(peek.look(at: 0.6, pointer: away, under: other, buttonDown: true) == nil)
    #expect(peek.look(at: 0.7, pointer: away, under: other, buttonDown: false) == nil)
    #expect(peek.released(at: 1) == nil)

    var back = held()
    #expect(back.clicked() == .goBack)
    var early = pressed()
    #expect(early.clicked() == nil)
    var nothing = held(from: root)
    #expect(nothing.clicked() == nil)
  }

  @Test func aClickOnTheViewThatWasLeftGoesBack() {
    var peek = held()
    #expect(peek.look(at: 0.6, pointer: rest, under: origin, buttonDown: true) == nil)
    #expect(peek.look(at: 0.7, pointer: rest, under: origin, buttonDown: false) == .goBack)
  }

  @Test func aButtonReleasedOverAnotherSpaceWasADrag() {
    var peek = held()
    #expect(peek.look(at: 0.6, pointer: away, under: other, buttonDown: true) == nil)
    #expect(peek.look(at: 0.7, pointer: rest, under: third, buttonDown: false) == nil)
    #expect(peek.phase == .holding)
  }

  @Test func aButtonThatWasDownBeforeThePressIsNoClick() {
    var peek = held(buttonDown: true)
    #expect(peek.look(at: 0.6, pointer: away, under: other, buttonDown: false) == nil)
    #expect(peek.phase == .holding)
  }

  @Test func aClickInAGapDoesNothing() {
    var peek = held()
    #expect(peek.look(at: 0.6, pointer: away, under: nil, buttonDown: true) == nil)
    #expect(peek.look(at: 0.7, pointer: away, under: nil, buttonDown: false) == nil)
    #expect(peek.phase == .holding)
  }

  // MARK: Releases that come another way

  @Test func aModifierGoingUpFirstEndsTheHold() {
    var peek = held()
    #expect(peek.look(at: 0.5, pointer: away, under: other) == nil)
    #expect(peek.look(at: 0.6, pointer: away, under: other, stillHeld: false) == .land(other))
    #expect(peek.phase == .over)
    #expect(peek.released(at: 0.7) == nil, "the key itself comes up a moment later")
  }

  @Test func aModifierGoingUpFirstWithinTheThresholdIsATap() {
    var peek = pressed()
    #expect(peek.look(at: 0.1, pointer: rest, under: origin, stillHeld: false) == .stay)
    #expect(peek.phase == .over)
  }

  // MARK: Things that get in the way

  @Test func anotherCommandLeavesTheViewOnEverythingForGood() {
    for start in [pressed(), held()] {
      var peek = start
      #expect(peek.interrupted() == .stay)
      #expect(peek.phase == .spent)
      #expect(peek.interrupted() == nil, "only once")
      #expect(peek.look(at: 0.8, pointer: away, under: other) == nil)
      #expect(peek.shownOutline == nil)
      #expect(peek.released(at: 1) == nil, "nothing jumps when the keys come up")
      #expect(peek.phase == .over)
    }
  }

  @Test func aSpentPeekEndsWhenTheModifiersComeUpEvenIfNoReleaseIsReported() {
    var peek = held()
    #expect(peek.escape() == .goBack)
    #expect(peek.look(at: 1, pointer: rest, under: origin) == nil)
    #expect(peek.phase == .spent)
    #expect(peek.look(at: 1.1, pointer: rest, under: origin, stillHeld: false) == nil)
    #expect(peek.phase == .over)
  }

  @Test func aCameraMovedBySomethingElseIsTheLanding() {
    var peek = held()
    peek.yielded()
    #expect(peek.phase == .spent)
    #expect(peek.shownOutline == nil)
    #expect(peek.released(at: 1) == nil)
  }

  @Test func aPeekThatIsOverStaysOverWhateverMovesTheCamera() {
    var peek = held()
    #expect(peek.released(at: 1) == .goBack)
    peek.yielded()
    #expect(peek.phase == .over)
  }

  // MARK: From everything

  @Test func withEverythingAlreadyShowingNothingIsOutlinedAndNothingMoves() {
    var peek = held(from: root)
    #expect(peek.shownOutline == nil)
    #expect(peek.released(at: 1) == .stay)
    var cancelled = held(from: root)
    #expect(cancelled.escape() == .stay)
  }

  @Test func fromEverythingThePointerAndTheArrowsStillChoose() {
    var peek = held(from: root)
    #expect(peek.look(at: 0.5, pointer: away, under: other) == nil)
    #expect(peek.released(at: 1) == .land(other))
    var keyed = held(from: root)
    keyed.arrow(to: third, pointer: rest)
    #expect(keyed.released(at: 1) == .land(third))
  }

  // MARK: Spaces that go away

  @Test func anOutlinedSpaceThatGoesAwayGivesTheOutlineBack() {
    var peek = held()
    #expect(peek.look(at: 0.5, pointer: away, under: other) == nil)
    peek.spacesChanged { $0 != other }
    #expect(peek.shownOutline == origin)
    #expect(peek.released(at: 1) == .goBack)
  }

  @Test func whenTheViewThatWasLeftIsGoneTooTheViewStays() {
    var peek = held()
    peek.spacesChanged { $0 == root }
    #expect(peek.shownOutline == nil)
    #expect(peek.origin == root)
    #expect(peek.released(at: 1) == .stay)
  }

  @Test func everythingCanChangeItsNumberWhileTheKeysAreDown() {
    // Only the Desktop was there, so it was everything. A window is docked: a new root, and the old number is the Desktop.
    let above = NodeID(9)
    var peek = held(from: root)
    peek.spacesChanged(root: above) { _ in true }
    #expect(peek.root == above)
    #expect(peek.origin == above, "everything was left, not the Desktop")
    #expect(peek.shownOutline == nil)
    #expect(peek.released(at: 2) == .stay)

    var framed = held()
    framed.spacesChanged(root: above) { _ in true }
    #expect(framed.root == above)
    #expect(framed.origin == origin)
    #expect(framed.released(at: 2) == .goBack)

    var gone = held()
    gone.spacesChanged(root: above) { $0 != origin }
    #expect(gone.origin == above, "nothing to go back to but what is everything now")
    #expect(gone.released(at: 2) == .stay)
  }

  @Test func aSpaceThatGoesAwayUnderThePressedButtonIsNotClicked() {
    var peek = held()
    #expect(peek.look(at: 0.6, pointer: away, under: other, buttonDown: true) == nil)
    peek.spacesChanged { $0 != other }
    #expect(peek.look(at: 0.7, pointer: away, under: nil, buttonDown: false) == nil)
    #expect(peek.phase == .holding)
  }

  // MARK: Where the arrows lead

  private let screen = CGRect(x: 0, y: 25, width: 1440, height: 875)

  /// root(h)[ column(v)[a, c], desktop, b ]
  private struct Fixture {
    var tree = LayoutTree()
    let a, b, c: NodeID
    var column: NodeID { tree.parent(of: a)! }

    init() {
      a = tree.dock(WindowID(1), beside: tree.root, edge: .left)
      b = tree.dock(WindowID(2), beside: tree.root, edge: .right)
      c = tree.dock(WindowID(3), beside: a, edge: .bottom)
    }
  }

  @Test func arrowsGoToTheNearestSpaceBeyondThatEdge() {
    let f = Fixture()
    let layout = LayoutEngine.layout(f.tree, camera: f.tree.root, in: screen, isPresent: { _ in true })
    func step(_ from: NodeID?, _ edge: Edge, focused: WindowID? = nil) -> NodeID? {
      Peek.step(from: from, toward: edge, focused: focused, in: layout, tree: f.tree)
    }
    #expect(step(f.a, .bottom) == f.c)
    #expect(step(f.c, .top) == f.a)
    #expect(step(f.a, .right) == f.tree.desktop)
    #expect(step(f.tree.desktop, .right) == f.b)
    #expect(step(f.b, .right) == nil)
    #expect(step(f.column, .right) == f.tree.desktop, "from a group that was framed")
    #expect(step(f.column, .left) == nil)
  }

  @Test func withNothingOutlinedTheArrowsStartFromTheFocusedWindow() {
    let f = Fixture()
    let layout = LayoutEngine.layout(f.tree, camera: f.tree.root, in: screen, isPresent: { _ in true })
    func step(_ edge: Edge, focused: WindowID?) -> NodeID? {
      Peek.step(from: nil, toward: edge, focused: focused, in: layout, tree: f.tree)
    }
    #expect(step(.bottom, focused: WindowID(1)) == f.c)
    #expect(step(.left, focused: WindowID(1)) == f.a, "nothing lies beyond it, so it is outlined itself")
    #expect(step(.right, focused: nil) == f.a, "nobody has the keyboard: the top left")
    #expect(step(.right, focused: WindowID(99)) == f.a)
  }

  @Test func theTopLeftIsTheTopLeftInWhateverOrderTheWindowsCome() {
    // The windows come out of a dictionary, so other numbers mean another order.
    for first in stride(from: UInt32(1), to: 400, by: 13) {
      var tree = LayoutTree()
      let a = tree.dock(WindowID(first), beside: tree.root, edge: .left)
      let b = tree.dock(WindowID(first + 1), beside: tree.root, edge: .right)
      _ = tree.dock(WindowID(first + 2), beside: a, edge: .bottom)
      _ = tree.dock(WindowID(first + 3), beside: b, edge: .bottom)
      let layout = LayoutEngine.layout(tree, camera: tree.root, in: screen, isPresent: { _ in true })
      #expect(Peek.step(from: nil, toward: .right, focused: nil, in: layout, tree: tree) == a)
    }
  }

  @Test func aSpaceInsideATileIsOutlinedAsThatTile() {
    let f = Fixture()
    // Too narrow for the column's windows: the column is one tile.
    let options = LayoutOptions(minimumUsableSize: CGSize(width: 500, height: 160))
    let layout = LayoutEngine.layout(f.tree, camera: f.tree.root, in: screen, options: options, isPresent: { _ in true })
    let tile = layout.tiles.first { f.tree.subtree($0.node, contains: f.a) }
    #expect(tile != nil)
    #expect(Peek.frame(of: f.a, in: layout, tree: f.tree) == tile?.frame)
    #expect(Peek.step(from: f.a, toward: .right, focused: nil, in: layout, tree: f.tree) != nil)
    #expect(Peek.frame(of: NodeID(999), in: layout, tree: f.tree) == nil)
  }

  // MARK: The setting

  @Test func peekIsOnUnlessTheFileSaysOtherwise() throws {
    #expect(Settings().peek)
    #expect(try JSONDecoder().decode(Settings.self, from: Data(#"{"gap": 8}"#.utf8)).peek)
    let off = try JSONDecoder().decode(Settings.self, from: Data(#"{"peek": false}"#.utf8))
    #expect(!off.peek)
    #expect(try JSONDecoder().decode(Settings.self, from: JSONEncoder().encode(off)) == off)
  }
}

extension Peek {
  /// `tick` with the arguments most tests leave alone.
  fileprivate mutating func look(
    at time: Double, pointer: CGPoint, under: NodeID?, buttonDown: Bool = false, stillHeld: Bool = true
  ) -> Ending? {
    tick(at: time, pointer: pointer, under: under, buttonDown: buttonDown, stillHeld: stillHeld)
  }
}
