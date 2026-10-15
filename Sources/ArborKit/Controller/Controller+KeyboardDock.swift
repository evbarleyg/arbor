import ArborCore
import CoreGraphics

/// Moving a docked window out of its group with `dock <edge>` (the rest is in `dock(_:edge:)`).
extension Controller {
  /// What `dock <edge>` makes of a window that is docked already.
  enum KeyboardMove {
    case moved(Workspace)
    case refused(String)
  }

  /// `workspace` with the docked window `id`, which is at `leaf`, one place further toward `edge`. **A key acts on what a person sees:** what
  /// is away (in the Dock, hidden) is neither a neighbour to pass nor company in a group, and a step that leaves the window left of and above
  /// whom it was is no step, whatever it does to the sizes. The press goes on until something shows, or says why it cannot and changes
  /// nothing. The menu asks here too, so that a row looks the way it acts.
  func moving(_ id: WindowID, at leaf: NodeID, toward edge: Edge, in workspace: Workspace, on display: DisplayID) -> KeyboardMove {
    guard var layout = layouts[display] else { return .refused("display not laid out") }
    // Nobody looks at a window that does not show. No key reaches it; named by its id, it goes one place, as it always went.
    guard layout.windowFrames[id] != nil else { return step(id, at: leaf, toward: edge, in: workspace, laidOutAs: layout, on: display) }
    let before = place(of: id, in: layout, of: workspace)
    var (workspace, leaf) = (workspace, leaf)
    // (Each step takes it out of a group or past a neighbour, so there are fewer than there are nodes.)
    for _ in 0..<workspace.tree.nodes.count {
      let outcome = step(id, at: leaf, toward: edge, in: workspace, laidOutAs: layout, on: display)
      guard case .moved(let next) = outcome else { return outcome }
      guard let trial = trialLayout(of: next, on: display), place(of: id, in: trial, of: next) == before,
        let itsLeaf = next.tree.leaf(containing: id)
      else { return .moved(next) }
      (workspace, leaf, layout) = (next, itsLeaf, trial)
    }
    return .refused("\(id) is already at the \(edge.rawValue) edge")
  }

  /// Where `id` lies to the eye: whom it is left of, right of, above and below, of the windows that show, whole or as tiles, and the Desktop (as
  /// window 0). Only what is said of the window itself, which is what its person is looking at: other sizes alone can part two
  /// bystanders that lay one above the other, or send them into a tile.
  private func place(of id: WindowID, in layout: Layout, of workspace: Workspace) -> [[UInt32]] {
    guard let own = layout.windowFrames[id] ?? layout.tiles.first(where: { $0.windows.contains(id) })?.frame else { return [] }
    var others = layout.windowFrames.map { (id: $0.key.rawValue, frame: $0.value) }
    if let desktop = layout.desktopFrame { others.append((0, desktop)) }
    for tile in layout.tiles {
      for window in tile.windows { others.append((window.rawValue, tile.frame)) }
      // A Desktop too small to use is a tile, or in the tile of its group, perhaps with nobody beside it, and a place all the same.
      if workspace.tree.subtree(tile.node, contains: workspace.tree.desktop) { others.append((0, tile.frame)) }
    }
    var place: [[UInt32]] = []
    for other in others.sorted(by: { $0.id < $1.id }) where other.id != id.rawValue {
      if own.maxX <= other.frame.minX { place.append([other.id, 0]) }
      if other.frame.maxX <= own.minX { place.append([other.id, 1]) }
      if own.maxY <= other.frame.minY { place.append([other.id, 2]) }
      if other.frame.maxY <= own.minY { place.append([other.id, 3]) }
    }
    return place
  }

  /// One step of `moving`, in a `workspace` that is, or would be, laid out as `layout`.
  private func step(
    _ id: WindowID, at leaf: NodeID, toward edge: Edge, in workspace: Workspace, laidOutAs layout: Layout, on display: DisplayID
  ) -> KeyboardMove {
    var workspace = workspace
    let present = presentWindowIDs()
    let view = TreeView(tree: workspace.tree, isPresent: { present.contains($0) })
    // The view can also be on a named group that is down to this window (F20), or on one of which it is all that shows: there is
    // nowhere to go in it either.
    // (Out of a tab group that fills the view a window can still go.)
    let shown = workspace.tree.windows(under: workspace.camera).filter { present.contains($0) }
    guard !workspace.holdsOnly(id, in: workspace.camera), shown != [id] || workspace.tree.subtree(workspace.camera, contains: workspace.tree.desktop)
    else { return .refused("\(id) fills the view\(adviceToStepOut)") }

    // 1. A sibling on that side of the same split: trade places with it
    //    (sizes travel with the nodes). With it goes a group of which the window is all that shows.
    let branch = whatShows(as: leaf, in: view, of: workspace)
    if let parent = workspace.tree.parent(of: branch),
      case .split(let axis, _) = workspace.tree[parent]?.kind, axis == edge.axis
    {
      let siblings = view.effectiveChildren(of: parent)
      if let index = siblings.firstIndex(of: branch) {
        let next = edge.isLeading ? index - 1 : index + 1
        if siblings.indices.contains(next) {
          workspace.tree.swapSiblings(branch, siblings[next])
          return .moved(workspace)
        }
      }
    }

    // 2. Otherwise step out of its group, next to whatever is beyond that edge.
    if let neighbor = Navigation.adjacentLeaf(to: leaf, toward: edge, in: layout, tree: workspace.tree) {
      guard let stepped = stepping(id, outBeside: neighbor, toward: edge, in: workspace, on: display) else {
        return .refused(Workspace.DockOutcome.tooDeep.refusal(of: id)!)
      }
      workspace = stepped
    } else {
      // Nothing visible beyond that edge. If the window is already the
      // outermost thing that shows in the view along that axis there is nowhere
      // to go; otherwise it becomes the outermost child.
      // (Alone beside a Desktop without room it has everything, and goes to that half: a first dock again.)
      if isOutermostThatShows(leaf, toward: edge, in: view, of: workspace), !workspace.tree.isAloneBesideADesktopWithoutRoom(leaf) {
        return .refused("\(id) is already at the \(edge.rawValue) edge")
      }
      let outcome = workspace.tryDock(
        id, at: .cameraEdge(edge), shareSpace: settings.shareRemovedSpace, desktopColumn: settings.desktopColumn)
      if let why = outcome.refusal(of: id) { return .refused(why) }
    }
    return .moved(keepingDesktopUsable(workspace, on: display))
  }

  /// What `leaf` is to the eye: itself, or the widest group around it, inside the view, of which it is all that shows. A column whose
  /// other windows are in the Dock or hidden does not look like a column. Taking a window out of such a group is a step nobody can see:
  /// the same picture, for a key that says "moved". So the group goes where the window goes, and is whole when the others come back.
  /// A window that is itself away or out of view is nothing to the eye. No key reaches it; named by its id, it goes alone, as it always went.
  func whatShows(as leaf: NodeID, in view: TreeView, of workspace: Workspace) -> NodeID {
    guard view.isEffective(leaf), workspace.tree.subtree(workspace.camera, contains: leaf) else { return leaf }
    var branch = leaf
    while branch != workspace.camera, let parent = workspace.tree.parent(of: branch), parent != workspace.camera,
      view.effectiveChildren(of: parent) == [branch]
    {
      branch = parent
    }
    return branch
  }

  /// Whether `leaf` is the outermost thing that shows in the view toward `edge`: `dock` has nowhere to take it. What is away does not count,
  /// neither beside it nor beyond it, nor around the row or column it is in: if that is all that shows of the view, its ends are the view's.
  func isOutermostThatShows(_ leaf: NodeID, toward edge: Edge, in view: TreeView, of workspace: Workspace) -> Bool {
    let branch = whatShows(as: leaf, in: view, of: workspace)
    guard let parent = workspace.tree.parent(of: branch), isAll(parent, thatShowsOf: workspace.camera, in: view, of: workspace),
      case .split(let axis, let everyone) = workspace.tree[parent]?.kind, axis == edge.axis
    else { return false }
    let siblings = view.isEffective(branch) ? view.effectiveChildren(of: parent) : everyone
    return (edge.isLeading ? siblings.first : siblings.last) == branch
  }

  /// Whether `node` is `group`, or all that shows of it.
  func isAll(_ node: NodeID, thatShowsOf group: NodeID, in view: TreeView, of workspace: Workspace) -> Bool {
    var node = node
    while node != group {
      guard let parent = workspace.tree.parent(of: node), view.effectiveChildren(of: parent) == [node] else { return false }
      node = parent
    }
    return true
  }

  /// `workspace` with `window` docked next to `neighbour`, the leaf, tile or Desktop beyond its
  /// `edge`. It takes half of the neighbour's slot, so nothing else moves. If that leaves the
  /// window or its neighbour too small to use (the narrow Desktop `arrange` makes, a slim column),
  /// it becomes a space of its own in the row or column the two share, sized like the average
  /// one there. A window being walked across the screen must not vanish into a tile half-way.
  /// Nil if the arrangement is too deep for either.
  func stepping(
    _ window: WindowID, outBeside neighbour: NodeID, toward edge: Edge, in workspace: Workspace,
    on display: DisplayID
  ) -> Workspace? {
    /// Whether the window would show, and how many tiles there would be.
    func outcome(_ candidate: Workspace) -> (shown: Bool, tiles: Int) {
      guard let layout = trialLayout(of: candidate, on: display) else { return (false, .max) }
      return (layout.windowFrames[window] != nil, layout.tiles.count)
    }

    var copy = workspace
    let halved =
      copy.dock(window, at: .beside(neighbour, edge.opposite), shareSpace: settings.shareRemovedSpace, desktopColumn: settings.desktopColumn) ? copy : nil
    let half = halved.map(outcome) ?? (false, .max)
    if half.shown, half.tiles <= layouts[display]?.tiles.count ?? 0 { return halved }

    // The child of the split the two share that holds the neighbour.
    guard let leaf = workspace.tree.leaf(containing: window) else { return halved }
    let shared = Navigation.commonAncestor(leaf, neighbour, in: workspace.tree)
    let branch = ([neighbour] + workspace.tree.ancestors(of: neighbour)).first {
      workspace.tree.parent(of: $0) == shared
    }
    guard let branch else { return halved }
    var evened = workspace
    guard
      evened.dock(
        window, at: .beside(branch, edge.opposite), evenShare: true, shareSpace: settings.shareRemovedSpace, desktopColumn: settings.desktopColumn)
    else { return halved }
    let even = outcome(evened)
    return halved == nil || even.shown && (!half.shown || even.tiles < half.tiles) ? evened : halved
  }

  /// `candidate`, the arrangement a `dock` command is about to make, with the Desktop kept wide and tall enough to use
  /// if it is in view now and has windows on it. Docking takes room from everything in the row, and a narrow
  /// Desktop (the column `arrange` makes) would become a tile under the windows on it: a call, a note being typed. What
  /// it lacks is taken from the neighbour that has most to give.
  func keepingDesktopUsable(_ candidate: Workspace, on display: DisplayID) -> Workspace {
    let holdsWindows = candidate.floating.keys.contains { windows[$0]?.isPresent == true && !parked.contains($0) }
    // Without a share of its own the Desktop is what is left over, and what floats is in view wherever it lies.
    guard settings.floatingWindowsMakeWay, settings.desktopColumn, holdsWindows, layouts[display]?.desktopFrame != nil,
      let trial = trialLayout(of: candidate, on: display),
      let tile = trial.tiles.first(where: { $0.kind == .desktop })
    else { return candidate }
    let desktop = candidate.tree.desktop
    let minimum = options(for: display).layoutOptions.minimumUsableSize
    var result = candidate
    for axis in Axis.allCases {
      let lacking = axis == .horizontal ? minimum.width - tile.frame.width : minimum.height - tile.frame.height
      let beside = trial.seams.filter { $0.axis == axis && ($0.leading == desktop || $0.trailing == desktop) }
      func room(_ seam: Seam) -> CGFloat {
        let giver =
          seam.leading == desktop
          ? seam.trailingEnds.last?.node ?? seam.trailing : seam.leadingEnds.last?.node ?? seam.leading
        return trial.nodeFrames[giver]?.length(along: axis) ?? 0
      }
      guard lacking > 0, let seam = beside.max(by: { room($0) < room($1) }) else { continue }
      result.tree.moveBoundary(at: seam, by: Double(seam.leading == desktop ? lacking + 1 : -(lacking + 1)), byHand: false)
    }
    // Not at the price of another tile.
    guard let better = trialLayout(of: result, on: display), better.desktopFrame != nil,
      better.tiles.count < trial.tiles.count
    else { return candidate }
    return result
  }

  /// How `workspace` would be laid out on `display`.
  private func trialLayout(of workspace: Workspace, on displayID: DisplayID) -> Layout? {
    guard let display = display(displayID) else { return nil }
    let present = presentWindowIDs()
    let minimums = minimumSizes
    return LayoutEngine.layout(
      workspace.tree, camera: workspace.camera, in: display.visibleFrame, options: options(for: displayID).layoutOptions,
      isPresent: { present.contains($0) }, minimumSize: { minimums[$0] })
  }
}

extension Workspace.DockOutcome {
  /// What a command answers when `window` was not docked; nil if it was.
  func refusal(of window: WindowID) -> String? {
    switch self {
    case .docked: nil
    case .notADock: "that is not a place to dock \(window)"
    case .nothingToDockBeside: "\(window) is the only thing in view; there is nothing to dock it beside"
    case .tooDeep:
      "\(window) stays where it is: groups can nest \(LayoutTree.maximumDepth) deep, and this would be one more"
    }
  }
}
