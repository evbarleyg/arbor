import ArborCore
import CoreGraphics

/// Moving a docked window out of its group with `dock <edge>` (the rest is in `dock(_:edge:)`).
extension Controller {
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
      copy.dock(window, at: .beside(neighbour, edge.opposite), shareSpace: settings.shareRemovedSpace) ? copy : nil
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
        window, at: .beside(branch, edge.opposite), evenShare: true, shareSpace: settings.shareRemovedSpace)
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
    guard holdsWindows, layouts[display]?.desktopFrame != nil, let trial = trialLayout(of: candidate, on: display),
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
      result.tree.moveBoundary(at: seam, by: Double(seam.leading == desktop ? lacking + 1 : -(lacking + 1)))
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
