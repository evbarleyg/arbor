import CoreGraphics

/// Whether a key went down or came up.
public enum KeyPhase: String, Sendable {
  case pressed
  case released
}

/// Peek: hold to look, let go to land (docs/features/F51-peek.md).
///
/// Show Everything is spring-loaded. A tap of its shortcut shows everything, as ever. Held, everything shows
/// while the keys are down, one space is outlined, and letting go frames it. A hold of under a second in which
/// nothing was chosen is a tap as well.
///
/// This is the whole decision, as a value: what a press, a release, the passing of time, the pointer, the arrow
/// keys, ⎋, a click and anything that gets in the way do to a peek. It moves no camera and reads no
/// clock. The controller tells it what happened and does what it answers (`Controller+Peek.swift`).
public struct Peek: Equatable, Sendable {
  /// Released sooner than this, the press was a tap. Until then nothing differs from a plain Show Everything, but for the keys that are kept.
  public static let holdThreshold = 0.3
  /// Let go sooner than this with nothing chosen, the press was a slow tap. Show Everything is the first way home, and
  /// someone who is lost presses three keys slowly and on purpose: it must not spring back for them.
  public static let slowTap = 1.0
  /// How far the pointer has to travel to count as moved: a hand resting on a mouse is never quite still.
  public static let pointerSlop: CGFloat = 4

  public enum Phase: String, Sendable {
    /// The keys are down, too briefly to tell a tap from a hold.
    case pressed
    /// Held: one space is outlined, and the arrow keys and ⎋ belong to the peek.
    case holding
    /// Decided, but the keys are still down. Their auto-repeat must not start another peek, and their
    /// release must do nothing.
    case spent
    /// Decided, and the keys are up: forget this value.
    case over
  }

  /// How a peek ends.
  public enum Ending: Equatable, Sendable {
    /// The view stays on everything, and history gets one entry: from the view that was left to everything.
    case stay
    /// This space is framed, and history gets one entry: from the view that was left to the space.
    case land(NodeID)
    /// The view that was left comes back, and history gets no entry.
    case goBack
  }

  public private(set) var phase: Phase = .pressed
  /// The view that was left.
  public private(set) var origin: NodeID
  /// Everything. Its number can change while the keys are down: see `spacesChanged`.
  public private(set) var root: NodeID
  /// The space that letting go would frame. It starts as the view that was left; nil when that was everything.
  public private(set) var outline: NodeID?

  private let pressedAt: Double
  /// Where the pointer was when something other than the pointer last chose the outline.
  private var pointerAtRest: CGPoint
  private var buttonDown: Bool
  /// What the button went down on, during the hold.
  private var pressedOn: NodeID?
  /// Whether the pointer has moved or an arrow key was pressed since the press, wherever that led.
  private var hasChosen = false

  /// The shortcut went down at `time` (in seconds, from any fixed moment) and everything is showing.
  public init(origin: NodeID, root: NodeID, at time: Double, pointer: CGPoint, buttonDown: Bool) {
    self.origin = origin
    self.root = root
    outline = origin == root ? nil : origin
    pressedAt = time
    pointerAtRest = pointer
    self.buttonDown = buttonDown
  }

  /// Whether the arrow keys and ⎋ mean the peek rather than what they are bound to.
  public var takesKeys: Bool { phase == .holding }
  /// Whether those of them that are bound to nothing are kept from the app in front: for as long as the keys are down, from the press on. Whoever
  /// has ⌃⌥Space down takes ⌃⌥↑ for Arbor's, a tenth of a second after the press and after the peek is decided as much as in between.
  public var keepsKeys: Bool { phase != .over }
  /// What to draw an outline around now.
  public var shownOutline: NodeID? { phase == .holding ? outline : nil }

  // MARK: What can happen

  /// The shortcut's key came up, or one of its modifiers did.
  public mutating func released(at time: Double) -> Ending? {
    switch phase {
    case .pressed where time - pressedAt < Self.holdThreshold:
      phase = .over
      return .stay
    case .pressed, .holding:
      // `.pressed` here: the timer that would have said "held" is late.
      phase = .over
      if !hasChosen, time - pressedAt < Self.slowTap { return .stay }
      guard let outline, outline != origin else { return origin == root ? .stay : .goBack }
      return .land(outline)
    case .spent, .over:
      phase = .over
      return nil
    }
  }

  /// Time has passed. `under` is the space under the pointer, if any. `stillHeld` is whether the shortcut's key and
  /// modifier keys are all down: ⌃ or ⌥ going up first ends the hold as well, and a release that was never
  /// reported must not leave Show Everything springing back for ever after.
  public mutating func tick(
    at time: Double, pointer: CGPoint, under: NodeID?, buttonDown isDown: Bool, stillHeld: Bool
  ) -> Ending? {
    guard stillHeld else { return released(at: time) }
    if phase == .pressed, time - pressedAt >= Self.holdThreshold { phase = .holding }
    guard phase == .holding else { return nil }

    if abs(pointer.x - pointerAtRest.x) > Self.pointerSlop || abs(pointer.y - pointerAtRest.y) > Self.pointerSlop {
      pointerAtRest = pointer
      hasChosen = true
      // Over a gap or the menu bar the outline stays where it was.
      if let under { outline = under }
    }

    defer { buttonDown = isDown }
    if isDown, !buttonDown {
      pressedOn = under
    } else if !isDown, buttonDown, let clicked = pressedOn {
      pressedOn = nil
      // Released somewhere else, it was a drag.
      if clicked == under { return end(clicked == origin ? .goBack : .land(clicked)) }
    }
    return nil
  }

  /// The outline itself was clicked. The timer can miss a click (a tap on a trackpad is over in a moment);
  /// whichever of the two notices first ends the peek.
  public mutating func clicked() -> Ending? {
    guard phase == .holding, let outline else { return nil }
    return end(outline == origin ? .goBack : .land(outline))
  }

  /// An arrow key or ⎋ came while it was too early to tell a tap from a hold, and it is the peek's: left to itself it would rearrange windows, or
  /// it is bound to nothing. Whoever presses one with the key down is holding it: the hold begins now.
  public mutating func heldForAKey() {
    if phase == .pressed { phase = .holding }
  }

  /// An arrow key, while `takesKeys`. `space` is where it leads from the outline (`Peek.step`), nil if nowhere.
  public mutating func arrow(to space: NodeID?, pointer: CGPoint) {
    guard phase == .holding else { return }
    // The pointer has to move again to take the outline back.
    pointerAtRest = pointer
    hasChosen = true
    if let space { outline = space }
  }

  /// ⎋, while `takesKeys`.
  public mutating func escape() -> Ending? {
    guard phase == .holding else { return nil }
    return end(origin == root ? .stay : .goBack)
  }

  /// Something else wants the view or the windows: another command, a drag, a pause. Nothing may jump under it,
  /// now or when the keys come up, so the view stays where it is.
  public mutating func interrupted() -> Ending? {
    guard phase == .pressed || phase == .holding else { return nil }
    return end(.stay)
  }

  /// The camera is being moved by something else (a clicked tile, a window that took the keyboard): that is
  /// the landing. The caller records it.
  public mutating func yielded() {
    if phase == .pressed || phase == .holding { phase = .spent }
  }

  /// The tree changed, and `root` is everything now. An outlined space that is gone gives the outline back to the view
  /// that was left, and if that is gone too there is nothing to go back to but everything.
  public mutating func spacesChanged(root now: NodeID? = nil, origin followed: NodeID? = nil, exists: (NodeID) -> Bool) {
    if let now, now != root {
      // The first window to be docked gets a new root above the Desktop, and the old number lives on as the Desktop
      // alone. What meant everything goes on meaning everything.
      if origin == root { origin = now }
      root = now
    }
    // What has taken the place of the view that was left (a group gives way to its last member) is where letting go leads.
    if let followed, origin != root, exists(followed) { origin = followed }
    if !exists(origin) { origin = root }
    if let current = outline, !exists(current) { outline = nil }
    if let current = pressedOn, !exists(current) { pressedOn = nil }
    if outline == nil, origin != root { outline = origin }
  }

  private mutating func end(_ ending: Ending) -> Ending {
    phase = .spent
    return ending
  }

  // MARK: Where the arrow keys lead

  /// The space an arrow key moves the outline to: the nearest window, tile or Desktop beyond that edge of the
  /// outlined space. With nothing outlined (everything was already showing) it starts from the focused
  /// window, which it outlines if nothing lies beyond it, and failing that from the top left.
  public static func step(
    from outline: NodeID?, toward edge: Edge, focused: WindowID?, in layout: Layout, tree: LayoutTree
  ) -> NodeID? {
    // A space inside a tile is outlined as that tile.
    let shown = outline.flatMap { space in
      layout.nodeFrames[space] != nil ? space : layout.tiles.first { tree.subtree($0.node, contains: space) }?.node
    }
    if let shown { return Navigation.adjacentLeaf(to: shown, toward: edge, in: layout, tree: tree) }
    if let focused, layout.windowFrames[focused] != nil, let leaf = tree.leaf(containing: focused) {
      return Navigation.adjacentLeaf(to: leaf, toward: edge, in: layout, tree: tree) ?? leaf
    }
    var spaces = layout.tiles.map { ($0.node, $0.frame) }
    for (window, frame) in layout.windowFrames {
      if let leaf = tree.leaf(containing: window) { spaces.append((leaf, frame)) }
    }
    return spaces.min { ($0.1.minY, $0.1.minX, $0.0) < ($1.1.minY, $1.1.minX, $1.0) }?.0
  }

  /// Where to draw the outline of `space`: its own rectangle, or that of the tile it is inside.
  public static func frame(of space: NodeID, in layout: Layout, tree: LayoutTree) -> CGRect? {
    if let frame = layout.nodeFrames[space] { return frame }
    return layout.tiles.first { tree.subtree($0.node, contains: space) }?.frame
  }
}
