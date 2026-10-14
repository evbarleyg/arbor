import CoreGraphics

/// Automatic docking (docs/features/F23-automatic-docking.md): where a new window goes when nobody said where.
///
/// Docking is the easy part. What matters is what is left alone: windows that are not worth a place, and
/// arrangements with no room left. "Room" means that everything that was showing still shows afterwards, and so
/// does the new window: nothing turns into a tile, and nothing comes into view, because a window opened.
public enum AutoDock {
  /// Whether a window is worth a place in the arrangement, judged by how it opened. Inspectors, palettes and small
  /// dialogs open small; calculators, "About" boxes and most settings windows cannot be resized.
  public static func accepts(size: CGSize, isResizable: Bool, minimum: CGSize) -> Bool {
    isResizable && size.width >= minimum.width && size.height >= minimum.height
  }

  /// A place for the new window that, as far as is known, has room.
  public struct Placement: Equatable, Sendable {
    public var target: DropTarget
    /// The frame the window would get there.
    public var slot: CGRect
    /// The window it would cover, when it joins that window as a tab.
    public var covers: WindowID?
    /// The Desktop's share next to the window's, counted in windows, if docking changes it.
    public var desktopWeight: Double?

    public init(target: DropTarget, slot: CGRect = .zero, covers: WindowID? = nil, desktopWeight: Double? = nil) {
      self.target = target
      self.slot = slot
      self.covers = covers
      self.desktopWeight = desktopWeight
    }

    /// Docks `window` there.
    @discardableResult
    public func apply(to workspace: inout Workspace, docking window: WindowID, shareSpace: Bool = true) -> Bool {
      guard workspace.dock(window, at: target, shareSpace: shareSpace) else { return false }
      let tree = workspace.tree
      if let desktopWeight, let leaf = tree.leaf(containing: window), let a = tree[tree.desktop]?.weight,
        let b = tree[leaf]?.weight
      {
        // The two keep what they weigh together. `moveBoundary` does nothing unless they are side by side.
        let share = (a + b) * desktopWeight / (1 + desktopWeight)
        let desktopLeads = tree.parent(of: leaf).map { tree.children(of: $0).first == tree.desktop } ?? true
        workspace.tree.moveBoundary(
          leading: desktopLeads ? tree.desktop : leaf, trailing: desktopLeads ? leaf : tree.desktop,
          by: desktopLeads ? share - a : a - share, pointsPerWeight: 1, minimumPoints: 0)
      }
      return true
    }
  }

  /// Why a window is not docked.
  public enum Refusal: Equatable, Sendable {
    /// The view is on one window or tab group. What a window that opens over it does is F57's business.
    case framed
    /// The view is on the Desktop alone, where floating windows live.
    case onTheDesktop
    case noRoom
  }

  public enum Plan: Equatable, Sendable {
    case dock(Placement)
    case float(Refusal)
  }

  /// Where `window`, which floats, should dock in `workspace`.
  ///
  /// - Parameters:
  ///   - recent: windows that had the keyboard, most recent first. The first that is docked and showing is
  ///     the one to dock beside.
  ///   - frame: the display's visible frame.
  ///   - minimumSize: sizes apps have refused to go below, `window`'s own included once it is known.
  ///   - emptyDesktopWeight: the share of a Desktop nothing floats on, next to the first window docked, counted
  ///     in windows (`arrangeDesktopWeight`). Nil if something floats on it: it then keeps half, as after `dock right`.
  ///   - terms: on what terms the layout that follows will make room before it makes a tile (F61), or nil if it will
  ///     not. The rehearsal does what that layout will do.
  public static func plan(
    for window: WindowID, in workspace: Workspace, recent: [WindowID], frame: CGRect, options: LayoutOptions,
    tabsEnabled: Bool, isPresent: @escaping (WindowID) -> Bool,
    minimumSize: @escaping (WindowID) -> CGSize? = { _ in nil }, emptyDesktopWeight: Double? = nil,
    makingRoom terms: MakeRoom.Terms? = nil
  ) -> Plan {
    func layout(_ workspace: Workspace, makingRoom: Bool = true) -> Layout {
      let plain = LayoutEngine.layout(
        workspace.tree, camera: workspace.camera, in: frame, options: options,
        isPresent: { $0 == window || isPresent($0) }, minimumSize: minimumSize)
      guard makingRoom, let terms, !plain.tiles.isEmpty || workspace.tree.hasLoans else { return plain }
      var tree = workspace.tree
      return MakeRoom.serve(
        &tree, camera: workspace.camera, in: frame, options: options,
        isPresent: { $0 == window || isPresent($0) }, minimumSize: minimumSize, terms: terms
      ).layout
    }
    let tree = workspace.tree
    // What shows now, not what the next layout would show. The two differ while the Desktop is owed room: it became a
    // tile while it was empty, and a window floats on it since. Whoever pays for that must not pay because a window opened.
    let before = layout(workspace, makingRoom: false)
    // What fills the display. It is not `workspace.camera` when nothing there takes up room just now.
    let view = before.camera
    if tree.isStack(view) { return .float(.framed) }
    if view == tree.desktop, view != tree.root { return .float(.onTheDesktop) }

    /// Halving a slot along its longer side keeps windows as near to square as halving allows.
    func halves(of neighbour: WindowID) -> [(target: DropTarget, covers: WindowID?)] {
      guard let leaf = tree.leaf(containing: neighbour), let slot = before.windowFrames[neighbour] else { return [] }
      let edges: [Edge] = slot.width >= slot.height ? [.right, .bottom] : [.bottom, .right]
      return edges.map { (.beside(leaf, $0), nil) }
    }
    var candidates: [(target: DropTarget, covers: WindowID?)] = []
    if let neighbour = recent.first(where: { $0 != window && before.windowFrames[$0] != nil }) {
      candidates = halves(of: neighbour)
      if tabsEnabled, let leaf = tree.leaf(containing: neighbour) { candidates.append((.stack(leaf), neighbour)) }
      // The window the person was in is too small to share. The largest one has the most to give.
      let largest = tree.windows(under: view).filter { $0 != neighbour && before.windowFrames[$0] != nil }
        .max { area(before.windowFrames[$0]) < area(before.windowFrames[$1]) }
      if let largest { candidates += halves(of: largest) }
    } else {
      candidates = [Edge.right, .bottom].map { (view == workspace.camera ? .cameraEdge($0) : .beside(view, $0), nil) }
    }

    // Whoever wants windows to dock by themselves wants them to fill the display. With nothing docked yet and nothing
    // on the Desktop, the first window leaves it what Arrange Windows would.
    let desktopWeight = tree.root == tree.desktop ? emptyDesktopWeight.map { $0.isNaN ? 0.5 : min(max($0, 0.05), 20) } : nil
    let inView = Set(tree.windows(under: view))
    let desktopInView = tree.subtree(view, contains: tree.desktop)
    for candidate in candidates {
      var rehearsal = workspace
      var placement = Placement(target: candidate.target, covers: candidate.covers, desktopWeight: desktopWeight)
      guard placement.apply(to: &rehearsal, docking: window) else { continue }
      let after = layout(rehearsal)
      // Docking at the edge of a view can put the window beside it in the row or column around it, and
      // the view then widens to that whole row.
      guard Set(rehearsal.tree.windows(under: after.camera)) == inView.union([window]),
        rehearsal.tree.subtree(after.camera, contains: rehearsal.tree.desktop) == desktopInView,
        keepsEverythingShowing(
          before: before, after: after, adding: window, covering: candidate.covers,
          desktopMayGo: terms.map { desktopMayBecomeATile(on: $0, options: options) } ?? false),
        let slot = after.windowFrames[window]
      else { continue }
      placement.slot = slot
      return .dock(placement)
    }
    return .float(.noRoom)
  }

  private static func area(_ frame: CGRect?) -> CGFloat { (frame?.width ?? 0) * (frame?.height ?? 0) }

  /// Whether a window that nobody has asked to be docked may leave the Desktop a tile: while nothing floats on it. It is one
  /// click away. (For a window somebody docks, F61 lets it either way.)
  public static func desktopMayBecomeATile(on terms: MakeRoom.Terms, options: LayoutOptions) -> Bool {
    !terms.desktopIsInUse
  }

  /// Whether `window` shows in `after`, along with everything that showed in `before`: each window (but
  /// `covered`, which is now behind `window` as a tab) and, unless `desktopMayGo`, the Desktop.
  public static func keepsEverythingShowing(
    before: Layout, after: Layout, adding window: WindowID, covering covered: WindowID? = nil,
    desktopMayGo: Bool = false
  ) -> Bool {
    guard after.windowFrames[window] != nil, desktopMayGo || before.desktopFrame == nil || after.desktopFrame != nil
    else { return false }
    return before.windowFrames.keys.allSatisfy { $0 == covered || $0 == window || after.windowFrames[$0] != nil }
  }
}

extension AppRule {
  /// What `"newWindows": "dock"` stands for.
  public static let dockEveryNewWindow = AppRule(app: "*", action: .dockAuto)
}

extension Settings {
  public var docksNewWindows: Bool { newWindows == "dock" }

  /// The rules new windows are checked against: `rules`, and the one `newWindows` stands for after them.
  public var newWindowRules: [AppRule] { docksNewWindows ? rules + [.dockEveryNewWindow] : rules }

  /// The smallest window a cautious rule takes (`AppRule.isCautious`).
  public var autoDockMinimumSize: CGSize { CGSize(width: autoDockMinimumWidth, height: autoDockMinimumHeight) }
}
