import ArborCore
import CoreGraphics

/// The controller's state in the words of `arborctl watch` (docs/features/F24-events.md).
extension Controller {
  /// Everything events report, as it is now. Reads only what the controller already knows: it runs
  /// after every burst of changes while someone is watching, so it must not ask other apps anything.
  /// That is why the caller says which window has the keyboard (`EventFeed` keeps track).
  public func eventSummary(focused: WindowID?) -> ArborEvent.Summary {
    var summary = ArborEvent.Summary(running: isRunning, accessibility: accessibilityGranted)
    summary.paused = isPaused
    guard isRunning else { return summary }

    for display in displays {
      guard let workspace = workspaces[display.id] else { continue }
      let tree = workspace.tree
      let layout = layouts[display.id]
      summary.displays.append(
        ArborEvent.Display(
          display: display.id, main: display.isMain, frame: display.frame,
          name: display.name.flatMap { $0.isEmpty ? nil : $0 }, builtIn: display.isBuiltIn))
      summary.layouts.append(
        ArborEvent.Arrangement(
          display: display.id, docked: tree.allWindows.count, floating: workspace.floating.count,
          tiles: layout?.tiles.count ?? 0, frames: layout?.windowFrames ?? [:]))

      var outOfView = 0
      for window in workspace.allWindows {
        guard let snapshot = windows[window] else { continue }
        let state = eventState(of: snapshot, in: layout, docked: workspace.isDocked(window))
        if state == .outOfView { outOfView += 1 }
        summary.windows.append(
          ArborEvent.Window(
            id: window, app: snapshot.appName, bundleID: snapshot.bundleID, display: display.id,
            docked: workspace.isDocked(window), state: state, title: snapshot.title))
      }

      // What fills the display: the camera, or the nearest space around it that has anything to show.
      let node = layout?.camera ?? workspace.camera
      let inView = tree.windows(under: node).filter { layout?.windowFrames[$0] != nil }
      summary.views.append(
        ArborEvent.View(
          display: display.id, node: node, kind: viewKind(of: node, in: tree), label: label(of: node, on: display.id),
          depth: stepsOut(from: node, on: display.id), windows: inView, apps: inView.map { windows[$0]?.appName ?? "" },
          outOfView: outOfView,
          // Whether `back` and `forward` would do anything: history can hold spaces that are gone.
          canGoBack: workspace.back.contains { tree.contains($0) && $0 != workspace.camera },
          canGoForward: workspace.forward.contains { tree.contains($0) && $0 != workspace.camera },
          savedView: workspace.savedViews.filter { $0.value == node }.keys.compactMap { Int($0) }.min(),
          name: spaceName(of: node, on: display.id)))
    }
    summary.windows.sort { $0.id < $1.id }
    let arranged = Set(summary.windows.map(\.id))
    summary.notArranged = windows.keys.filter { !arranged.contains($0) }.sorted()

    if let focused, let snapshot = windows[focused] {
      summary.focus = ArborEvent.Focus(
        window: focused, app: snapshot.appName, bundleID: snapshot.bundleID,
        display: workspaceID(containing: focused), title: snapshot.title)
    }
    return summary
  }

  func eventState(of window: WindowSnapshot, in layout: Layout?, docked: Bool) -> ArborEvent.Window.State {
    if window.isMinimized { return .minimized }
    if window.isHidden { return .hidden }
    if window.isFullScreen { return .fullScreen }
    if !window.isPresent { return .otherSpace }
    if layout?.tiles.contains(where: { $0.windows.contains(window.id) }) == true { return .tile }
    if parked.contains(window.id) { return .outOfView }
    // A docked window without a frame of its own is outside the view, or a tab behind another.
    return docked && layout?.windowFrames[window.id] == nil ? .outOfView : .inView
  }

  private func viewKind(of node: NodeID, in tree: LayoutTree) -> ArborEvent.View.Kind {
    // With nothing docked the Desktop is the whole arrangement, and the view is of everything.
    if node == tree.root { return .everything }
    if node == tree.desktop { return .desktop }
    return tree.isStack(node) ? .window : .group
  }

  /// The space in the words replies use (`name(of:on:)`), without the number that follows them there.
  func label(of node: NodeID, on display: DisplayID) -> String {
    // Arbor's own words. What a person called the space is `name`.
    let name = name(of: node, on: display, byName: false)
    // Replies have only the number for a space of which nothing can be seen just now (minimized, hidden, on another of
    // macOS's Spaces). A status bar shows the label to a person: say what the space holds.
    guard name != "\(node)" else {
      let apps = workspaces[display]?.tree.windows(under: node).compactMap { windows[$0]?.appName } ?? []
      return apps.isEmpty ? "nothing" : apps.joined(separator: ", ")
    }
    let number = " (\(node))"
    return name.hasSuffix(number) ? String(name.dropLast(number.count)) : name
  }

  /// How often `out` can be run from `node`.
  func stepsOut(from node: NodeID, on display: DisplayID) -> Int {
    guard let view = treeView(display) else { return 0 }
    var steps = 0
    var current = node
    // A tree is never this deep; the bound is for a tree that is not one.
    while steps < 64, let next = Navigation.stepOut(from: current, in: view) {
      steps += 1
      current = next
    }
    return steps
  }
}
