import CoreGraphics

/// Stretches and shifts the plane. x and y are scaled independently, so a rectangle stays a
/// rectangle. Moving the camera is applying one of these to everything on the plane.
public struct PlaneMap: Equatable, Sendable {
  public var scaleX: CGFloat
  public var scaleY: CGFloat
  public var offsetX: CGFloat
  public var offsetY: CGFloat

  public static let identity = PlaneMap(scaleX: 1, scaleY: 1, offsetX: 0, offsetY: 0)

  public init(scaleX: CGFloat, scaleY: CGFloat, offsetX: CGFloat, offsetY: CGFloat) {
    self.scaleX = scaleX
    self.scaleY = scaleY
    self.offsetX = offsetX
    self.offsetY = offsetY
  }

  /// The map that carries `source` onto `target`. Nil when `source` is thinner than a point, which
  /// would blow everything else up beyond reason, or when a number is not finite.
  public init?(carrying source: CGRect, onto target: CGRect) {
    guard source.isFinite, target.isFinite, source.width >= 1, source.height >= 1 else { return nil }
    scaleX = target.width / source.width
    scaleY = target.height / source.height
    offsetX = target.minX - source.minX * scaleX
    offsetY = target.minY - source.minY * scaleY
  }

  public func apply(_ point: CGPoint) -> CGPoint {
    CGPoint(x: point.x * scaleX + offsetX, y: point.y * scaleY + offsetY)
  }

  public func apply(_ rect: CGRect) -> CGRect {
    CGRect(
      x: rect.minX * scaleX + offsetX, y: rect.minY * scaleY + offsetY, width: rect.width * scaleX,
      height: rect.height * scaleY)
  }
}

/// A display's tree seen as an infinite plane with the camera on one node: where every window and
/// node is, including the ones beyond the edges of the screen.
///
/// The layout only says where things inside the camera's node go. The plane adds the rest, so
/// that a camera move can be shown as one continuous zoom. An ancestor of the camera's node is
/// laid out on the screen without tiles, and everything in it is carried along by the map that makes
/// the camera's node fill the screen. With the ancestor two cameras have in common, the two planes
/// are two views of one arrangement: windows leaving the view slide and stretch out past the screen
/// edges, and windows coming into view arrive from there.
///
/// Inside the camera's node the real layout wins, because gaps do not scale: they are the same
/// number of points at every zoom level.
public struct Plane: Equatable, Sendable {
  /// How a window is drawn while it moves.
  public enum Look: String, Equatable, Sendable, Codable {
    /// As itself: a still picture of it, if Arbor may take one.
    case picture
    /// As a tile, or its part of a group's tile: the app's colour and icon.
    case cover
  }

  public enum Visibility: Equatable, Sendable {
    /// Inside the camera's node and drawn there, as itself or as (part of) a tile.
    case inView
    /// Beyond the camera's node, so out of view.
    case outside
    /// An inactive tab: wherever its stack is, the active tab covers it.
    case behind
  }

  /// One window's place on the plane.
  public struct Spot: Equatable, Sendable {
    public var frame: CGRect
    public var look: Look
    public var visibility: Visibility

    public init(frame: CGRect, look: Look, visibility: Visibility) {
      self.frame = frame
      self.look = look
      self.visibility = visibility
    }
  }

  /// The node that fills the screen.
  public let camera: NodeID
  /// The node whose subtree this plane holds: the camera's node or one of its ancestors.
  public let ancestor: NodeID
  /// The rectangle the camera's node fills: the display's visible frame minus the outer gap.
  public let content: CGRect
  /// Every node under `ancestor` that takes up space, except those inside tiles.
  public private(set) var nodes: [NodeID: CGRect] = [:]
  /// Every present docked window under `ancestor`.
  public private(set) var windows: [WindowID: Spot] = [:]

  /// The plane that goes with `layout`, the display's real layout of `tree`.
  ///
  /// - Parameters:
  ///   - ancestor: how much of the tree to place. If it does not hold the layout's camera, the
  ///     nearest node that holds both is used.
  ///   - options, isPresent: what `layout` was made with.
  public init(
    tree: LayoutTree, layout: Layout, ancestor requested: NodeID, options: LayoutOptions,
    isPresent: @escaping (WindowID) -> Bool
  ) {
    let camera = layout.camera
    let ancestor =
      tree.subtree(requested, contains: camera)
      ? requested : Navigation.commonAncestor(requested, camera, in: tree)
    self.camera = camera
    self.ancestor = ancestor
    content = LayoutEngine.content(of: layout.frame, options: options)

    if ancestor != camera {
      var flat = options
      flat.minimumUsableSize = .zero
      let base = LayoutEngine.layout(
        tree, camera: ancestor, in: layout.frame, options: flat, isPresent: isPresent)
      if let rect = base.nodeFrames[camera], let map = PlaneMap(carrying: rect, onto: content) {
        for (node, frame) in base.nodeFrames where !tree.subtree(camera, contains: node) {
          nodes[node] = map.apply(frame).integralRounded
        }
      }
    }
    for (node, frame) in layout.nodeFrames { nodes[node] = frame }

    let view = TreeView(tree: tree, isPresent: isPresent)
    for (leaf, frame) in nodes {
      guard case .stack(let stacked, _) = tree[leaf]?.kind else { continue }
      let shown = view.visibleWindow(of: leaf)
      let inside = layout.nodeFrames[leaf] != nil
      for window in stacked where isPresent(window) {
        windows[window] = Spot(
          frame: frame, look: .picture,
          visibility: window != shown ? .behind : inside ? .inView : .outside)
      }
    }
    for tile in layout.tiles {
      for window in tile.windows {
        switch tile.kind {
        case .window:
          windows[window]?.look = .cover
        case .group:
          // The layout does not place the nodes inside a group's tile, only its miniature.
          windows[window] =
            tile.miniature[window].map { Spot(frame: $0, look: .cover, visibility: .inView) }
            ?? Spot(frame: tile.frame, look: .cover, visibility: .behind)
        case .desktop:
          break
        }
      }
    }
  }

  /// The plane seen with the camera on `camera`, laying the display out first.
  public init(
    tree: LayoutTree, camera: NodeID, ancestor: NodeID, in frame: CGRect, options: LayoutOptions = .init(),
    isPresent: @escaping (WindowID) -> Bool,
    minimumSize: @escaping (WindowID) -> CGSize? = { _ in nil }
  ) {
    let layout = LayoutEngine.layout(
      tree, camera: camera, in: frame, options: options, isPresent: isPresent, minimumSize: minimumSize)
    self.init(tree: tree, layout: layout, ancestor: ancestor, options: options, isPresent: isPresent)
  }
}

extension CGRect {
  /// Whether all four numbers are finite. Core Animation raises an exception for a frame that is not.
  public var isFinite: Bool {
    origin.x.isFinite && origin.y.isFinite && size.width.isFinite && size.height.isFinite
  }
}
