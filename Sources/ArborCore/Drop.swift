import CoreGraphics

/// What happens when a dragged window is released.
public enum DropTarget: Equatable, Sendable, Codable {
  /// Dock at an edge of the camera node, beside everything in view.
  case cameraEdge(Edge)
  /// Dock beside a leaf or tile.
  case beside(NodeID, Edge)
  /// Join a stack as a tab.
  case stack(NodeID)
  /// Leave the window floating where it was dropped (undocking it if needed).
  case float
  /// Put a docked window back in its own slot (it was dropped on itself).
  case none
}

public struct DropOptions: Equatable, Sendable {
  /// How close to a screen edge the pointer must be to dock at the camera edge.
  public var screenEdgeBand: CGFloat
  /// The band along a window's edges, as a fraction of its size, that docks
  /// beside it. The middle docks as a tab (if enabled) or floats.
  public var windowEdgeFraction: CGFloat
  public var tabsEnabled: Bool
  /// How long, in seconds, the pointer must rest on a window or tile before it becomes the drop
  /// target. See `dwell(for:)`.
  public var dwell: Double

  public init(
    screenEdgeBand: CGFloat = 12, windowEdgeFraction: CGFloat = 0.3, tabsEnabled: Bool = false,
    dwell: Double = 0.15
  ) {
    self.screenEdgeBand = screenEdgeBand
    self.windowEdgeFraction = windowEdgeFraction
    self.tabsEnabled = tabsEnabled
    self.dwell = dwell
  }
}

public enum DropResolver {
  /// Decides the drop target for `window` released at `point`.
  ///
  /// - Parameters:
  ///   - layout: the current layout of the display under the pointer.
  ///   - tree: that display's tree (the window may or may not be docked in it).
  ///   - visibleFrame: that display's visible frame, for screen-edge docking.
  public static func resolve(
    point: CGPoint, window: WindowID, layout: Layout, tree: LayoutTree, visibleFrame: CGRect,
    options: DropOptions = .init()
  ) -> DropTarget {
    let ownLeaf = tree.leaf(containing: window)
    if let ownLeaf, let own = layout.nodeFrames[ownLeaf], own.contains(point) {
      return .none
    }

    let band = options.screenEdgeBand
    let edgeDistances: [(Edge, CGFloat)] = [
      (.left, point.x - visibleFrame.minX),
      (.right, visibleFrame.maxX - point.x),
      (.top, point.y - visibleFrame.minY),
      (.bottom, visibleFrame.maxY - point.y),
    ]
    if let nearest = edgeDistances.min(by: { $0.1 < $1.1 }), nearest.1 < band {
      return .cameraEdge(nearest.0)
    }

    guard let node = layout.leafOrTile(at: point, in: tree), node != ownLeaf,
      node != tree.desktop, let frame = layout.nodeFrames[node], frame.width > 0,
      frame.height > 0
    else { return .float }

    let fractions: [(Edge, CGFloat)] = [
      (.left, (point.x - frame.minX) / frame.width),
      (.right, (frame.maxX - point.x) / frame.width),
      (.top, (point.y - frame.minY) / frame.height),
      (.bottom, (frame.maxY - point.y) / frame.height),
    ]
    let nearest = fractions.min(by: { $0.1 < $1.1 })!
    if nearest.1 <= options.windowEdgeFraction { return .beside(node, nearest.0) }
    if options.tabsEnabled, tree.isStack(node) { return .stack(node) }
    return .float
  }
}

// MARK: Holding over a target

extension DropTarget {
  /// Whether the pointer must rest on this target before a drop there counts. A drag crosses
  /// windows and tiles on its way somewhere else, so those wait. A screen edge is somewhere the
  /// pointer only goes on purpose, and floating or going back to its own slot docks nothing.
  public var needsDwell: Bool {
    switch self {
    case .beside, .stack: true
    case .cameraEdge, .float, .none: false
    }
  }
}

extension DropOptions {
  /// How long the pointer must rest on `target` before it activates; 0 means at once.
  public func dwell(for target: DropTarget) -> Double { target.needsDwell ? max(dwell, 0) : 0 }
}

// MARK: Carrying out a drop

/// One window let go of over one target. Applying it only changes values, so the controller can
/// try a drop on a copy of its workspaces (live reflow shows that copy) and the real drop, made
/// by the same code, is bound to end the same way.
public struct Drop: Equatable, Sendable {
  public var window: WindowID
  public var target: DropTarget
  /// The display whose workspace `target` refers to: the one under the pointer.
  public var display: DisplayID
  /// Where the window floats if it ends up floating: where it is, unless it changes size as it is let go.
  public var frame: CGRect
  /// For a window that comes from another display to be docked on this one: where it would float here.
  /// Docking remembers that as the frame to give back when it leaves the arrangement.
  public var arrivingFrame: CGRect?
  /// Who gets the space it leaves: its whole group, or the neighbour before it (`Settings.shareRemovedSpace`).
  public var shareSpace: Bool

  public init(
    window: WindowID, target: DropTarget, display: DisplayID, frame: CGRect, arrivingFrame: CGRect? = nil,
    shareSpace: Bool = true
  ) {
    self.window = window
    self.target = target
    self.display = display
    self.frame = frame
    self.arrivingFrame = arrivingFrame
    self.shareSpace = shareSpace
  }

  /// Moves `window` to where the drop puts it, taking it out of wherever it was, on any display.
  /// Returns the displays to lay out again, the one it left first. A window that was floating
  /// and still floats changes no layout.
  @discardableResult
  public func apply(to workspaces: inout [DisplayID: Workspace]) -> [DisplayID] {
    guard workspaces[display] != nil else { return [] }
    let holders = workspaces.keys.sorted().filter { workspaces[$0]?.contains(window) == true }
    var changed: [DisplayID] = []
    switch target {
    case .none:
      // Nothing changes, but the window has to go back into its slot.
      return holders

    case .float:
      // Forgetting it takes its role off. A pinned or summoned window carried to another display still is.
      let role = holders.compactMap { workspaces[$0]?.role(of: window) }.first
      defer { if let role { workspaces[display]?.setRole(role, of: window) } }
      for holder in holders {
        let wasDocked = workspaces[holder]?.isDocked(window) == true
        guard wasDocked || holder != display else { continue }
        // A floating window's leaving can change the arrangement too: it lets go of a group the view has left,
        // or that only this window, as its guest, kept (F62).
        let arrangement = workspaces[holder]?.tree
        workspaces[holder]?.forget(window, shareSpace: shareSpace)
        if workspaces[holder]?.tree != arrangement { changed.append(holder) }
      }
      workspaces[display]?.floating[window] = frame

    case .cameraEdge, .beside, .stack:
      guard workspaces[display]?.wouldDock(window, at: target) == .docked else {
        // Refused, and nothing was previewed either. A docked window goes back to its slot, as when it is
        // dropped on itself; any other stays where it was let go.
        var instead = self
        instead.target = holders.contains { workspaces[$0]?.isDocked(window) == true } ? .none : .float
        return instead.apply(to: &workspaces)
      }
      for holder in holders where holder != display {
        workspaces[holder]?.forget(window, shareSpace: shareSpace)
        changed.append(holder)
      }
      if let arrivingFrame, !holders.contains(display) { workspaces[display]?.floating[window] = arrivingFrame }
      workspaces[display]?.dock(window, at: target, shareSpace: shareSpace)
      changed.append(display)
    }
    return changed
  }
}
