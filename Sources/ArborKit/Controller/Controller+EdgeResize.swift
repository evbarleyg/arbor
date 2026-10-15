import ArborCore
import CoreGraphics

/// Edges that moved this little are the app rounding its size, as in `windowChanged`.
private let edgeTolerance: CGFloat = 4

/// Resizing a docked window by dragging its own edges. When the mouse is
/// released, each edge the user moved takes the seam on that side with it, as
/// if the user had dragged that seam; an edge with nothing beside it in view
/// is put back. Docked windows moved without the mouse are still put back by
/// `scheduleEnforce`.
extension Controller {
  /// An edge resize in progress, from `resizeBegan` to `resizeEnded`.
  struct EdgeResize {
    var window: WindowID
    var display: DisplayID
    /// Enforcement found the button up and has waited one round for `resizeEnded`.
    var waitedAfterRelease = false
  }

  public func resizeBegan(_ id: WindowID) {
    edgeResize = nil
    appsDoubleClick = nil
    stopWatchingTitle(of: id)
    guard isRunning, isManaged(id), let display = workspaceID(containing: id),
      workspaces[display]!.isDocked(id)
    else { return }
    edgeResize = EdgeResize(window: id, display: display)
  }

  public func resizeEnded(_ id: WindowID) {
    if edgeResize?.window == id { edgeResize = nil }
    guard isRunning, isManaged(id) else { return }
    if workspaces.values.contains(where: { $0.isFloating(id) }) { aHandHasPlaced(id) }
    if isPinned(id), let display = workspaceID(containing: id) { return makeRoomWhereKeptWindowsAre(on: [display], asked: true) }
    recordingUndo("resize \(id) by its edges", title: "Resize") { applyEdgeResize(of: id) }
  }

  /// Whether enforcement on `display` should wait because the user is resizing
  /// a docked window there. `resizeEnded` comes with the window system's
  /// mouse-up event, which can arrive a moment after the button is physically
  /// up; putting the window back in that moment would undo the resize. So the
  /// wait lasts one round past the button. If the event has still not come,
  /// it was lost, and the window is put back as before.
  func isAwaitingResizeEnd(on display: DisplayID) -> Bool {
    guard let session = edgeResize, session.display == display else { return false }
    if system.isMouseButtonDown() { return true }
    if session.waitedAfterRelease || windows[session.window] == nil {
      edgeResize = nil
      return false
    }
    edgeResize?.waitedAfterRelease = true
    return true
  }

  /// Moves the seam beside each edge of `window` that the user dragged, so its
  /// slot matches the frame the window ended at (after any clamping by its
  /// app), and lays the display out again.
  func applyEdgeResize(of window: WindowID) {
    guard let display = workspaceID(containing: window),
      let leaf = workspaces[display]?.tree.leaf(containing: window),
      let layout = layouts[display], let slot = layout.windowFrames[window],
      let frame = windows[window]?.frame, let view = treeView(display)
    else { return }

    // An app that rounds its size (a terminal snapping to character cells) can
    // sit some points inside its slot. Measuring each edge against where the
    // window sat before the resize as well keeps an edge the user did not
    // touch from counting as moved.
    let before = settled[window] ?? slot
    let moved = Edge.allCases.filter { edge in
      abs(frame.position(of: edge) - slot.position(of: edge)) > edgeTolerance
        && abs(frame.position(of: edge) - before.position(of: edge)) > edgeTolerance
    }
    guard !moved.isEmpty else {
      // Too little to tell from an app's rounding which gap was meant, so none follows. But this is the end of a resize: it was a hand, and
      // the window is not a few points out of its slot because its app wants it so. It goes back, in one move.
      // (A point is in place to every layout: boundaries are rounded to whole points.)
      if !frame.approximatelyEquals(before, tolerance: 1) {
        scheduler.cancel("enforce-\(display.rawValue)")
        byHand { relayout(display, reason: .enforce) }
      }
      return
    }

    // Outer seams first: moving a seam near the root rescales the splits under
    // it, so each edge is measured again, in a fresh layout, before its seam moves.
    var seams: [(edge: Edge, depth: Int)] = []
    for edge in moved {
      if case .seam(let seam) = Self.seam(on: edge, of: leaf, in: view, layout: layout) {
        seams.append((edge, view.tree.depth(of: seam.split)))
      }
    }
    var resized = false
    for edge in seams.sorted(by: { $0.depth < $1.depth }).map({ $0.edge }) {
      guard let fresh = self.layout(of: display), let freshView = treeView(display),
        let freshSlot = fresh.nodeFrames[leaf],
        case .seam(let seam) = Self.seam(on: edge, of: leaf, in: freshView, layout: fresh)
      else { continue }
      let delta = frame.position(of: edge) - freshSlot.position(of: edge)
      guard abs(delta) >= 1 else { continue }
      workspaces[display]!.tree.moveBoundary(at: seam, by: Double(delta), minimumPoints: minimumPointsBesideSeam(on: display))
      resized = true
    }

    // Edges with nothing beside them in view go back to the slot with the
    // rest. The put-back the resize's own changes scheduled is not needed.
    scheduler.cancel("enforce-\(display.rawValue)")
    byHand { relayout(display, reason: resized ? .structure : .enforce) }
    if resized { scheduleSave() }
    Log.debug(
      "edge resize of \(window): edges \(moved.map(\.rawValue)), seams beside \(seams.map { $0.edge.rawValue })")
  }

  // MARK: Seams

  /// What is beside one edge of a docked window's leaf.
  enum SeamLookup {
    /// The seam between the leaf's branch and its neighbour on that side.
    case seam(Seam)
    /// There is a neighbour on that side, but the seam is outside the view.
    case notInView
    /// Nothing is on that side.
    case noNeighbour
  }

  /// The seam on `edge` of `leaf`: walks up to the nearest split along that
  /// edge's axis in which the leaf's branch has a neighbour on that side.
  /// Shared by the `resize` command and edge resizes.
  static func seam(on edge: Edge, of leaf: NodeID, in view: TreeView, layout: Layout) -> SeamLookup {
    let tree = view.tree
    var current = leaf
    while let parent = tree.parent(of: current) {
      defer { current = parent }
      guard case .split(let axis, _) = tree[parent]?.kind, axis == edge.axis else { continue }
      // Also a place that is kept open for a window that is not there yet (Controller+KeptRoom.swift).
      let siblings = tree.children(of: parent).filter { view.isEffective($0) || layout.openPlaces[$0] != nil }
      guard let index = siblings.firstIndex(of: current) else { continue }
      let neighborIndex = edge.isLeading ? index - 1 : index + 1
      guard siblings.indices.contains(neighborIndex) else { continue }
      let leading = siblings[min(index, neighborIndex)]
      let trailing = siblings[max(index, neighborIndex)]
      guard
        let seam = layout.seams.first(where: {
          $0.split == parent && $0.leading == leading && $0.trailing == trailing
        })
      else { return .notInView }
      return .seam(seam)
    }
    return .noNeighbour
  }
}

extension CGRect {
  /// The x of a left or right edge, or the y of a top or bottom edge.
  fileprivate func position(of edge: Edge) -> CGFloat {
    switch edge {
    case .left: minX
    case .right: maxX
    case .top: minY
    case .bottom: maxY
    }
  }
}
