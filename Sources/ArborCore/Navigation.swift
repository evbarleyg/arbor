import CoreGraphics

/// Camera moves. The camera is a node; the layout makes that node fill the
/// screen. All functions are pure and return the node to move the camera to,
/// or nil when the move is not possible.
public enum Navigation {
  /// The nearest ancestor that shows more than the camera does now. Splits
  /// with a single effective child are skipped because they look identical.
  public static func stepOut(from camera: NodeID, in view: TreeView) -> NodeID? {
    var current = view.effectiveAncestor(of: camera)
    while let parent = view.tree.parent(of: current) {
      if view.effectiveChildren(of: parent).count >= 2 { return parent }
      current = parent
    }
    return nil
  }

  /// The child of the camera under `point` (or holding `focused`, or the
  /// nearest to `point`, or the first). Nil when the camera is a leaf.
  public static func stepIn(
    from camera: NodeID, toward point: CGPoint?, focused: WindowID?, in view: TreeView,
    layout: Layout
  ) -> NodeID? {
    let start = view.passThrough(view.effectiveAncestor(of: camera))
    let children = view.effectiveChildren(of: start)
    guard !children.isEmpty else { return nil }

    if let point,
      let hit = children.first(where: { layout.nodeFrames[$0]?.contains(point) == true })
    {
      return hit
    }
    if let focused,
      let holder = children.first(where: { view.tree.windows(under: $0).contains(focused) })
    {
      return holder
    }
    if let point {
      return children.min { a, b in
        let da = layout.nodeFrames[a]?.distance(to: point) ?? .infinity
        let db = layout.nodeFrames[b]?.distance(to: point) ?? .infinity
        return da < db
      }
    }
    return children.first
  }

  /// The child of the camera that is or holds `node`: one step toward it, wherever the pointer is.
  /// Nil when the camera is a leaf or `node` is not inside it.
  public static func stepIn(from camera: NodeID, toward node: NodeID, in view: TreeView) -> NodeID? {
    let start = view.passThrough(view.effectiveAncestor(of: camera))
    return view.effectiveChildren(of: start).first { view.tree.subtree($0, contains: node) }
  }

  /// The sibling space next to the camera in `direction`, found by walking up
  /// to the first split along that axis that has a neighbour on that side.
  public static func neighbor(of camera: NodeID, toward direction: Edge, in view: TreeView)
    -> NodeID?
  {
    var current = view.effectiveAncestor(of: camera)
    while let parent = view.tree.parent(of: current) {
      if case .split(let axis, _) = view.tree[parent]?.kind, axis == direction.axis {
        let siblings = view.effectiveChildren(of: parent)
        if let index = siblings.firstIndex(of: current) {
          let next = direction.isLeading ? index - 1 : index + 1
          if siblings.indices.contains(next) { return siblings[next] }
        }
      }
      current = parent
    }
    return nil
  }

  /// The deepest node whose subtree contains both `a` and `b`.
  public static func commonAncestor(_ a: NodeID, _ b: NodeID, in tree: LayoutTree) -> NodeID {
    let lineage = Set([a] + tree.ancestors(of: a))
    var current: NodeID? = b
    while let node = current {
      if lineage.contains(node) { return node }
      current = tree.parent(of: node)
    }
    return tree.root
  }

  /// The laid-out node that best matches `rect` (highest intersection over
  /// union; ties go to the smaller node). Used to frame a dragged rectangle.
  ///
  /// A split that shows one child has exactly that child's rectangle. Of such a pair the inner
  /// node wins, which takes `tree` to tell; without it, the lower id, so that the answer at least
  /// never depends on the order a dictionary happens to be walked in.
  public static func bestFit(for rect: CGRect, in layout: Layout, tree: LayoutTree? = nil) -> NodeID? {
    var best: (node: NodeID, score: CGFloat, area: CGFloat)?
    for (node, frame) in layout.nodeFrames {
      let score = frame.intersectionOverUnion(rect)
      guard score > 0 else { continue }
      if let current = best {
        if score != current.score {
          if score < current.score { continue }
        } else if frame.area != current.area {
          if frame.area > current.area { continue }
        } else {
          let (depth, currentDepth) = (tree?.depth(of: node) ?? 0, tree?.depth(of: current.node) ?? 0)
          if depth < currentDepth || (depth == currentDepth && node > current.node) { continue }
        }
      }
      best = (node, score, frame.area)
    }
    return best?.node
  }

  /// The visible leaf, tile or Desktop nearest to `leaf` in `direction`,
  /// judged by geometry: it must lie beyond that edge and overlap on the
  /// other axis. Neighbours across a gap are all equally near: of those, the one that shares the
  /// most of the edge wins, then the one that comes first (topmost or leftmost).
  public static func adjacentLeaf(
    to leaf: NodeID, toward direction: Edge, in layout: Layout, tree: LayoutTree
  ) -> NodeID? {
    guard let origin = layout.nodeFrames[leaf] else { return nil }
    var candidates: [NodeID: CGRect] = [:]
    for (window, frame) in layout.windowFrames {
      if let node = tree.leaf(containing: window), node != leaf { candidates[node] = frame }
    }
    for tile in layout.tiles where tile.node != leaf { candidates[tile.node] = tile.frame }
    if let desktop = layout.desktopFrame, leaf != tree.desktop { candidates[tree.desktop] = desktop }

    /// Smaller is better, compared field by field. The id settles what geometry cannot, so the
    /// order `candidates` is walked in never matters.
    typealias Rank = (distance: CGFloat, unshared: CGFloat, start: CGFloat, id: Int)
    var best: (node: NodeID, rank: Rank)?
    for (node, frame) in candidates {
      let beyond: Bool
      let distance: CGFloat
      switch direction {
      case .left:
        beyond = frame.maxX <= origin.minX + 1
        distance = origin.minX - frame.maxX
      case .right:
        beyond = frame.minX >= origin.maxX - 1
        distance = frame.minX - origin.maxX
      case .top:
        beyond = frame.maxY <= origin.minY + 1
        distance = origin.minY - frame.maxY
      case .bottom:
        beyond = frame.minY >= origin.maxY - 1
        distance = frame.minY - origin.maxY
      }
      let along = direction.axis.perpendicular
      let start = along == .horizontal ? frame.minX : frame.minY
      let shared =
        along == .horizontal
        ? min(frame.maxX, origin.maxX) - max(frame.minX, origin.minX)
        : min(frame.maxY, origin.maxY) - max(frame.minY, origin.minY)
      guard beyond, shared > 0 else { continue }
      let rank: Rank = (distance, -shared, start, node.rawValue)
      if best == nil || rank < best!.rank { best = (node, rank) }
    }
    return best?.node
  }
}
