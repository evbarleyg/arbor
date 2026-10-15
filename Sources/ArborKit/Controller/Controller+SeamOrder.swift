import ArborCore

/// Keeping gap handles where they belong among the windows (`Seam.rearmostNeighbour`).
///
/// A handle's model names the window it lies just below, and whoever draws it obeys: the panels on a Mac, the stand-ins
/// elsewhere. macOS reports no change of stacking. So after anything that may have changed it Arbor looks, as it does for
/// pinned windows (`keepPinsInFront`), and shows the gaps again if the order is another.
extension Controller {
  /// How the windows were stacked when Arbor last looked, for the gaps' sake.
  struct Stacking {
    var frontToBack: [WindowID] = []
    /// How often a look has found another order than the one before (`OverlayScene.stackingSeen`).
    var changes = 0
    var looksLeft = 0
    /// The one look that a button held down is worth has been taken.
    var hasLookedWhileHeld = false
    /// A look is showing what it found: the scenes it asks for need not look again.
    var isFresh = false
  }

  /// Has each gap of a scene name the window its handle lies just below. Comes last: how Arbor looks decides whether there are
  /// gaps to drag at all.
  func putSeamsInOrder(_ scene: inout OverlayScene, for layout: Layout, on display: DisplayID) {
    guard !scene.seams.isEmpty else { return }
    // Dragging a gap or an edge lays out with every move of the mouse, and changes no order.
    if !stacking.isFresh, !system.isMouseButtonDown() { lookAtTheOrder(whileShowing: display) }
    for index in scene.seams.indices {
      scene.seams[index].liesBelow = layout.windowOverTheHandle(of: scene.seams[index], frontToBack: stacking.frontToBack)
    }
    scene.stackingSeen = stacking.changes
  }

  /// If the windows are stacked otherwise than at the last look, every display's gaps are shown again, but those of the display whose
  /// scene is being put together anyway. Also where every handle still names the same window: that window may have come
  /// forward, with its neighbour, and left its handle behind.
  ///
  /// By the list that leaves out Arbor's overlays, or every handle put in its place would be another order. It holds the windows
  /// Arbor does not arrange and does not even know of, and they too can get between a window and its handle.
  private func lookAtTheOrder(whileShowing busy: DisplayID? = nil) {
    let order = system.stackedWindows().map(\.id)
    guard order != stacking.frontToBack else { return }
    stacking.frontToBack = order
    stacking.changes += 1
    stacking.isFresh = true
    defer { stacking.isFresh = false }
    // The line round the focused window is where it was: this is no reason to ask an app who has the keyboard.
    let ringIsWorkedOut = focusRing.isWorkedOut
    focusRing.isWorkedOut = true
    defer { focusRing.isWorkedOut = ringIsWorkedOut }
    // A display that is about to be laid out again is shown again then: an app that hides is one happening, and one drawing.
    for (display, layout) in layouts.sorted(by: { $0.key < $1.key })
    where display != busy && !postponedRelayouts.contains(display) && !layout.seams.isEmpty {
      overlays.update(display: display, scene: overlayScene(for: layout, on: display))
    }
  }

  /// For whoever checks: the order last seen, and how often it has been another.
  public var stackingSeenForHandles: (frontToBack: [WindowID], changes: Int) { (stacking.frontToBack, stacking.changes) }

  /// Called with every change observers hear of. A layout is none of them: it changes no order, and its scene looks for itself. Nor is
  /// a window that comes, which comes in front, or one that goes, which leaves the others as they lie. Where Arbor itself brings
  /// windows forward and nothing is reported (Controller+SideBySide.swift), it says so by calling `lookAfterHandles`.
  func keepHandlesInOrder(after change: Change) {
    switch change {
    case .focus, .keyboard: lookAfterHandles()
    default: break
    }
  }

  /// The first look waits until the command or event under way is over. The later ones are for what nothing reports: a clicked
  /// window takes the keyboard first and comes to the front afterwards, some apps take their time, and the window server's
  /// list lags behind what Accessibility has already said.
  func lookAfterHandles() {
    guard isRunning, settings.appearanceOptions.gapHandles != .off, layouts.values.contains(where: { !$0.seams.isEmpty })
    else { return }
    stacking.looksLeft = Self.pinChecks
    scheduler.schedule("order-handles", after: 0) { [weak self] in self?.checkHandles() }
  }

  private func checkHandles() {
    guard isRunning else { return }
    // A click is not over until the button is up, however long that takes: a text is selected, a window carried about. All that time
    // is worth one look, for the list of windows is not cheap to read; nothing tells that the button came up, so Arbor goes on asking.
    let isHeld = system.isMouseButtonDown()
    if !isHeld || !stacking.hasLookedWhileHeld { lookAtTheOrder() }
    stacking.hasLookedWhileHeld = isHeld
    if !isHeld { stacking.looksLeft -= 1 }
    guard stacking.looksLeft > 0 else { return }
    scheduler.schedule("order-handles", after: Self.pinCheckInterval) { [weak self] in self?.checkHandles() }
  }
}
