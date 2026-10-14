import CoreGraphics

/// A layout tree seen through which windows are currently present (not
/// minimized, not hidden, still open). Absent windows keep their place in the
/// tree but take no space, so they return to the same spot.
public struct TreeView {
  public let tree: LayoutTree
  public let isPresent: (WindowID) -> Bool

  public init(tree: LayoutTree, isPresent: @escaping (WindowID) -> Bool) {
    self.tree = tree
    self.isPresent = isPresent
  }

  /// Whether a node takes up space: the Desktop always does, a stack does if
  /// any of its windows is present, a split does if any child does.
  public func isEffective(_ id: NodeID) -> Bool {
    guard let node = tree[id] else { return false }
    switch node.kind {
    case .desktop: return true
    case .stack(let windows, _): return windows.contains(where: isPresent)
    case .split(_, let children): return children.contains(where: isEffective)
    }
  }

  public func effectiveChildren(of id: NodeID) -> [NodeID] {
    tree.children(of: id).filter(isEffective)
  }

  /// The stack's window to show: its active window if present, otherwise the
  /// first present one.
  public func visibleWindow(of leaf: NodeID) -> WindowID? {
    guard case .stack(let windows, let active) = tree[leaf]?.kind else { return nil }
    if windows.indices.contains(active), isPresent(windows[active]) { return windows[active] }
    return windows.first(where: isPresent)
  }

  public func presentWindows(under id: NodeID) -> [WindowID] {
    tree.windows(under: id).filter(isPresent)
  }

  /// `id` if it is effective, else its nearest effective ancestor (the root's
  /// subtree always contains the Desktop, so this always succeeds).
  public func effectiveAncestor(of id: NodeID) -> NodeID {
    var current = tree.contains(id) ? id : tree.root
    while !isEffective(current), let parent = tree.parent(of: current) {
      current = parent
    }
    return current
  }

  /// Descends through splits that have exactly one effective child. Such
  /// splits occupy the same rectangle as that child.
  public func passThrough(_ id: NodeID) -> NodeID {
    var current = id
    while tree.isSplit(current) {
      let children = effectiveChildren(of: current)
      guard children.count == 1 else { break }
      current = children[0]
    }
    return current
  }
}

public struct LayoutOptions: Equatable, Sendable {
  /// Space between neighbouring windows.
  public var gap: CGFloat
  /// Space between the windows and the edges of the screen.
  public var outerGap: CGFloat
  /// Nodes smaller than this (other than the camera node) are drawn as tiles.
  public var minimumUsableSize: CGSize
  /// Whether the space of an absent child of a split is shared by the whole row (in proportion to
  /// the weights) or goes to one neighbour: the nearest child before it that takes up space, or
  /// after it if there is none. See `Builder.keptExtents`.
  public var shareRemovedSpace: Bool

  public init(
    gap: CGFloat = 12, outerGap: CGFloat? = nil,
    minimumUsableSize: CGSize = CGSize(width: 240, height: 160), shareRemovedSpace: Bool = true
  ) {
    self.gap = gap
    self.outerGap = outerGap ?? gap
    self.minimumUsableSize = minimumUsableSize
    self.shareRemovedSpace = shareRemovedSpace
  }
}

/// A node too small to show its windows, drawn instead as a tile with the app
/// colour and icon. Selecting it zooms the camera onto it.
public struct Tile: Equatable, Sendable, Codable {
  public enum Kind: String, Equatable, Sendable, Codable {
    /// One docked window (or tab group).
    case window
    /// A split holding several windows.
    case group
    /// The Desktop.
    case desktop
  }

  public var node: NodeID
  public var kind: Kind
  public var frame: CGRect
  /// Present windows inside, in tree order.
  public var windows: [WindowID]
  /// For groups: where each window would sit inside the tile, for drawing a
  /// miniature of the group's splits.
  public var miniature: [WindowID: CGRect]
}

/// The gap between two neighbouring children of a split. Dragging it resizes both.
///
/// Not `Hashable`: `CGRect` is only from macOS 15, and Arbor runs on 14. Whoever needs a key makes one without geometry.
public struct Seam: Equatable, Sendable, Codable {
  public var split: NodeID
  public var leading: NodeID
  public var trailing: NodeID
  public var axis: Axis
  public var frame: CGRect
  /// Converts a drag distance in points into weight units for this split.
  public var pointsPerWeight: CGFloat
  /// If `leading` is a group on this split's own axis (one that is kept, F62): its last child in view, that
  /// child's if it is such a group too, and so on down. The last of these is what is seen beside the gap.
  public var leadingEnds: [End] = []
  /// The same for `trailing` and first children.
  public var trailingEnds: [End] = []

  /// A child at the end of a group, and what converts points into weight units among its siblings.
  public struct End: Equatable, Sendable, Codable {
    public var node: NodeID
    public var pointsPerWeight: CGFloat
  }
}

extension Seam {
  /// A trace recorded before seams knew of the ends of groups holds seams without them.
  public init(from decoder: any Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    split = try c.decode(NodeID.self, forKey: .split)
    leading = try c.decode(NodeID.self, forKey: .leading)
    trailing = try c.decode(NodeID.self, forKey: .trailing)
    axis = try c.decode(Axis.self, forKey: .axis)
    frame = try c.decode(CGRect.self, forKey: .frame)
    pointsPerWeight = try c.decode(CGFloat.self, forKey: .pointsPerWeight)
    leadingEnds = try c.decodeIfPresent([End].self, forKey: .leadingEnds) ?? []
    trailingEnds = try c.decodeIfPresent([End].self, forKey: .trailingEnds) ?? []
  }
}

/// The result of laying out one display.
public struct Layout: Equatable, Sendable {
  /// The node filling the screen (the requested camera, or its nearest
  /// effective ancestor).
  public var camera: NodeID
  /// The rectangle the layout fills (the display's visible frame).
  public var frame: CGRect
  /// Rectangles of every node that was laid out, including tiles.
  public var nodeFrames: [NodeID: CGRect] = [:]
  /// Where each visible docked window goes.
  public var windowFrames: [WindowID: CGRect] = [:]
  public var tiles: [Tile] = []
  public var seams: [Seam] = []
  /// Where the Desktop is, if it is visible and not a tile.
  public var desktopFrame: CGRect?
  /// Present docked windows that must be moved out of view: outside the
  /// camera, inactive tabs, or inside tiles.
  public var hiddenWindows: Set<WindowID> = []

  public init(camera: NodeID, frame: CGRect) {
    self.camera = camera
    self.frame = frame
  }

  /// The leaf (stack or desktop) or tile whose rectangle contains `point`.
  public func leafOrTile(at point: CGPoint, in tree: LayoutTree) -> NodeID? {
    if let tile = tiles.first(where: { $0.frame.contains(point) }) { return tile.node }
    for (window, frame) in windowFrames where frame.contains(point) {
      return tree.leaf(containing: window)
    }
    if let desktopFrame, desktopFrame.contains(point) { return tree.desktop }
    return nil
  }
}

public enum LayoutEngine {
  /// Lays out the subtree under `camera` so it fills `frame`.
  ///
  /// Every rectangle in the result is finite and on whole points, whatever the tree, the display
  /// and the options. The children of a split and the gaps between them tile it exactly, so nothing
  /// overlaps and nothing leaves `frame`. Gaps are the same everywhere, except where there is too
  /// little room for them: see `content(of:options:)` and `placeSplit`.
  ///
  /// - Parameters:
  ///   - isPresent: whether a window currently takes up space.
  ///   - minimumSize: the smallest size a window has accepted (learned from
  ///     apps that refuse to shrink). A window whose slot is smaller is tiled.
  public static func layout(
    _ tree: LayoutTree, camera: NodeID, in frame: CGRect, options: LayoutOptions = .init(),
    isPresent: @escaping (WindowID) -> Bool,
    minimumSize: @escaping (WindowID) -> CGSize? = { _ in nil }
  ) -> Layout {
    var layout = placement(
      tree, camera: camera, in: frame, options: options, isPresent: isPresent, minimumSize: minimumSize)
    for window in tree.allWindows where isPresent(window) && layout.windowFrames[window] == nil {
      layout.hiddenWindows.insert(window)
    }
    return layout
  }

  /// `layout` without `hiddenWindows`, which takes going through every window of the whole tree. A
  /// group tile's miniature is laid out with this: it needs only the frames inside the tile.
  static func placement(
    _ tree: LayoutTree, camera: NodeID, in frame: CGRect, options: LayoutOptions,
    isPresent: @escaping (WindowID) -> Bool,
    minimumSize: @escaping (WindowID) -> CGSize? = { _ in nil }
  ) -> Layout {
    let view = TreeView(tree: tree, isPresent: isPresent)
    let camera = view.effectiveAncestor(of: camera)
    // The gap comes from settings.json, where it can be any number. At least none, and whole
    // points, which keep every frame on whole points. How large it can be depends on the room.
    var options = options
    options.gap = options.gap.isNaN ? 0 : max(options.gap.rounded(), 0)
    var builder = Builder(
      view: view, options: options, minimumSize: minimumSize,
      layout: Layout(camera: camera, frame: frame))
    builder.place(camera, in: content(of: frame, options: options), isCamera: true)
    return builder.layout
  }

  /// The whole points of `frame` that are left inside the outer gap. A gap that takes more room
  /// than there is would make `insetBy` return the null rectangle, whose infinities spread to every
  /// frame, to the overlays, and into state.json. And one that takes all the room (500 for 50 is a
  /// slip of the finger) would leave every window with none. So it takes at most a quarter of
  /// the shorter side, on each side. A frame that is not finite leaves nothing.
  ///
  /// This is the rectangle the camera's node fills. Ask for it here rather than working it out again.
  public static func content(of frame: CGRect, options: LayoutOptions) -> CGRect {
    let frame = frame.standardized
    let outerGap = options.outerGap.isNaN ? 0 : max(options.outerGap.rounded(), 0)
    guard frame.minX.isFinite, frame.minY.isFinite, frame.maxX.isFinite, frame.maxY.isFinite else {
      return .zero
    }
    let inset = min(outerGap, (min(frame.width, frame.height) / 4).rounded(.down))
    let x = (frame.minX + inset).rounded(.up)
    let y = (frame.minY + inset).rounded(.up)
    return CGRect(
      x: x, y: y, width: max((frame.maxX - inset).rounded(.down) - x, 0),
      height: max((frame.maxY - inset).rounded(.down) - y, 0))
  }

  private struct Builder {
    let view: TreeView
    let options: LayoutOptions
    let minimumSize: (WindowID) -> CGSize?
    var layout: Layout
    /// The splits laid out so far that show two children or more, for `ends`.
    var rows: [NodeID: (axis: Axis, first: NodeID, last: NodeID, pointsPerWeight: CGFloat)] = [:]
    /// Those that show one, and which.
    var onlyChildren: [NodeID: NodeID] = [:]

    mutating func place(_ id: NodeID, in rect: CGRect, isCamera: Bool) {
      guard let node = view.tree[id] else { return }
      layout.nodeFrames[id] = rect

      if !isCamera, let kind = tileKind(for: node, in: rect) {
        var miniature: [WindowID: CGRect] = [:]
        if kind == .group {
          let inner = LayoutEngine.placement(
            view.tree, camera: id, in: rect,
            options: LayoutOptions(
              gap: TileMetrics.miniatureGap, outerGap: TileMetrics.miniatureInset(for: rect.size),
              minimumUsableSize: .zero, shareRemovedSpace: options.shareRemovedSpace),
            isPresent: view.isPresent)
          miniature = inner.windowFrames
        }
        layout.tiles.append(
          Tile(
            node: id, kind: kind, frame: rect, windows: view.presentWindows(under: id),
            miniature: miniature))
        return
      }

      switch node.kind {
      case .desktop:
        layout.desktopFrame = rect
      case .stack:
        if let window = view.visibleWindow(of: id) { layout.windowFrames[window] = rect }
      case .split(let axis, _):
        let children = view.effectiveChildren(of: id)
        guard !children.isEmpty else { return }
        if children.count == 1 {
          // It looks exactly like its child, so as the camera it must not turn the child into a tile.
          onlyChildren[id] = children[0]
          place(children[0], in: rect, isCamera: isCamera)
          return
        }
        placeSplit(id, axis: axis, children: children, in: rect)
      }
    }

    mutating func placeSplit(_ id: NodeID, axis: Axis, children: [NodeID], in rect: CGRect) {
      let origin = axis == .horizontal ? rect.minX : rect.minY
      let length = rect.length(along: axis)
      let extents: [Extent]
      let pointsPerWeight: CGFloat
      if options.shareRemovedSpace {
        (extents, pointsPerWeight) = sharedExtents(of: children, length: length)
      } else {
        (extents, pointsPerWeight) = keptExtents(of: children, in: id, length: length)
      }
      rows[id] = (axis, children.first!, children.last!, pointsPerWeight)
      let frames: [CGRect] = extents.map { extent in
        axis == .horizontal
          ? CGRect(x: origin + extent.start, y: rect.minY, width: extent.size, height: rect.height)
          : CGRect(x: rect.minX, y: origin + extent.start, width: rect.width, height: extent.size)
      }

      for (child, childRect) in zip(children, frames) {
        place(child, in: childRect, isCamera: false)
      }

      for index in 0..<(children.count - 1) {
        let a = frames[index]
        let b = frames[index + 1]
        let seamFrame =
          axis == .horizontal
          ? CGRect(x: a.maxX, y: rect.minY, width: b.minX - a.maxX, height: rect.height)
          : CGRect(x: rect.minX, y: a.maxY, width: rect.width, height: b.minY - a.maxY)
        layout.seams.append(
          Seam(
            split: id, leading: children[index], trailing: children[index + 1], axis: axis,
            frame: seamFrame, pointsPerWeight: pointsPerWeight,
            leadingEnds: ends(of: children[index], along: axis, last: true),
            trailingEnds: ends(of: children[index + 1], along: axis, last: false)))
      }
    }

    /// `Seam.leadingEnds` or `trailingEnds`. Children are placed before their parent's seams are made.
    func ends(of node: NodeID, along axis: Axis, last: Bool) -> [Seam.End] {
      var ends: [Seam.End] = []
      var at = node
      while true {
        if let row = rows[at], row.axis == axis {
          at = last ? row.last : row.first
          ends.append(Seam.End(node: at, pointsPerWeight: row.pointsPerWeight))
        } else if let only = onlyChildren[at] {
          at = only  // which has all of it, whatever its weight
        } else {
          return ends
        }
      }
    }

    /// Where each child of a split starts, measured from the split's own origin, and how long it is.
    typealias Extent = (start: CGFloat, size: CGFloat)

    /// The gap in a split `length` points long with `count` children. Gaps give way before windows do:
    /// together they take at most half of the split. At full width, the gaps of a long row would be wider
    /// than the row and push its end off the display.
    func boundedGap(among count: Int, length: CGFloat) -> CGFloat {
      min(options.gap, (length / CGFloat(2 * max(count - 1, 1))).rounded(.down))
    }

    /// `children` are those that take up space. The gaps between them are set aside and the rest is
    /// divided by weight, so when one leaves, everyone grows.
    func sharedExtents(of children: [NodeID], length: CGFloat) -> (extents: [Extent], pointsPerWeight: CGFloat) {
      let gap = boundedGap(among: children.count, length: length)
      let available = length - gap * CGFloat(children.count - 1)
      let weights = children.map { CGFloat(view.tree[$0]!.weight) }
      let total = weights.reduce(0, +)
      let pointsPerWeight = total > 0 && total.isFinite ? available / total : 0

      // Where each child starts, measured without the gaps and from the split's own origin, so
      // that the gaps are exact and the result is the same wherever the display is. (Rounding
      // absolute positions rounds away from zero, which differs on either side of x = 0.)
      var cumulative: CGFloat = 0
      var offsets: [CGFloat] = [0]
      for weight in weights {
        cumulative += weight
        // Halves are common (two equal windows in an odd length) and round up. So must what arithmetic has left a
        // hair below a half, or a boundary moves by a point when weights change that should not concern it.
        offsets.append(min((cumulative * pointsPerWeight + 1e-6).rounded(), available))
      }
      offsets[children.count] = available
      let extents: [Extent] = children.indices.map { index in
        (start: gap * CGFloat(index) + offsets[index], size: offsets[index + 1] - offsets[index])
      }
      return (extents, pointsPerWeight)
    }

    /// With `shareRemovedSpace` off. Every child of `split`, absent ones too, owns a stretch in proportion
    /// to its weight that holds its slot and the gap after it (the last one's gap falls outside the
    /// split, hence `length + gap`). An absent child's stretch is added to its neighbour's. Counting the
    /// gap with the slot is what keeps the others still to the point: adding one child's weight to
    /// another, here or for good in `LayoutTree.remove`, moves no other boundary. The two ways
    /// agree when the weights are equal, and otherwise differ by a few points (about a gap).
    func keptExtents(of children: [NodeID], in split: NodeID, length: CGFloat)
      -> (extents: [Extent], pointsPerWeight: CGFloat)
    {
      let everyChild = view.tree.children(of: split)
      let gap = boundedGap(among: everyChild.count, length: length)
      let whole = length + gap
      let total = everyChild.reduce(0) { $0 + CGFloat(view.tree[$1]?.weight ?? 0) }
      let pointsPerWeight = total > 0 && total.isFinite ? whole / total : 0

      var cumulative: CGFloat = 0
      var bounds: [CGFloat] = [0]
      for child in everyChild {
        cumulative += CGFloat(view.tree[child]?.weight ?? 0)
        bounds.append(min((cumulative * pointsPerWeight + 1e-6).rounded(), whole))
      }
      bounds[everyChild.count] = whole

      let takesSpace = Set(children)
      var extents: [Extent] = []
      for (index, child) in everyChild.enumerated() {
        let end = bounds[index + 1] - gap
        if takesSpace.contains(child) {
          // Absent children before the first one that takes space count for it.
          let start = extents.isEmpty ? 0 : bounds[index]
          extents.append((start, max(end - start, 0)))
        } else if let last = extents.indices.last {
          extents[last].size = max(end - extents[last].start, 0)
        }
      }
      return (extents, pointsPerWeight)
    }

    func tileKind(for node: LayoutTree.Node, in rect: CGRect) -> Tile.Kind? {
      let minimum = options.minimumUsableSize
      let tooSmall = rect.width < minimum.width - 0.5 || rect.height < minimum.height - 0.5
      switch node.kind {
      case .desktop:
        return tooSmall ? .desktop : nil
      case .split:
        return tooSmall ? .group : nil
      case .stack:
        if tooSmall { return .window }
        if let window = view.visibleWindow(of: node.id), let learned = minimumSize(window),
          learned.width > rect.width + 1 || learned.height > rect.height + 1
        {
          return .window
        }
        return nil
      }
    }
  }
}
