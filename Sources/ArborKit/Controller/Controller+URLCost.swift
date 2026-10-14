import ArborCore

/// What a link may not cost. URLs never run commands that delete things, because any web page can open one. `arrange` and `layout`
/// arrange, which a link may do, but they start the arrangement afresh, and saved views and names of spaces that are no more go with
/// the old one. Those a person made. So from a link the two are refused where they would take one away, and allowed where they would not.
extension Controller {
  /// The saved views and names that would be gone if `command` ran now, coming from a link. Nothing is changed by asking.
  ///
  /// It does to copies of the workspaces what the commands do to the workspaces, and counts as `notingWhatIsLost` counts afterwards.
  /// `URLCostTests` holds the two together.
  func whatALinkWouldCost(_ command: Command) -> (views: Int, names: Int) {
    var after = workspaces
    switch command {
    case .arrange:
      if let display = displayForCommands(from: .url) { startAfresh(&after, on: display) }
    case .arrangeAll:
      for display in workspaces.keys { startAfresh(&after, on: display) }
    case .layout(let spec, let name, _):
      guard case .display(let display) = deciding(false, { from(.url) { chooseDisplay(name) } }), let workspace = workspaces[display]
      else { break }
      let candidates = windowCandidates()
      let resolution = spec.resolve(candidates, current: workspace.tree)
      let placed = Set(resolution.allWindows)
      // A line that finds none of its windows changes nothing.
      guard !placed.isEmpty else { break }
      // Windows it fetches from other displays leave their spaces there.
      for other in workspaces.keys where other != display {
        for window in workspaces[other]?.allWindows ?? [] where placed.contains(window) {
          after[other]?.forget(window, shareSpace: settings.shareRemovedSpace)
        }
      }
      // How wide the Desktop comes out is decided later, and makes no difference to which spaces there are.
      let tree = spec.tree(filling: resolution.windows, recent: candidates.map(\.id), desktopSize: settings.arrangeDesktopWeight)
      after[display]?.reset(tree: tree, carrying: workspace.tree.counterparts(in: tree))
    default: break
    }
    func count(_ workspaces: [DisplayID: Workspace]) -> (views: Int, names: Int) {
      workspaces.values.reduce((0, 0)) { ($0.0 + $1.savedViews.count, $0.1 + $1.names.count) }
    }
    return (count(workspaces).views - count(after).views, count(workspaces).names - count(after).names)
  }

  /// What `arrange` does to a display's saved views and names, if it finds a window to arrange.
  private func startAfresh(_ workspaces: inout [DisplayID: Workspace], on display: DisplayID) {
    guard let workspace = workspaces[display] else { return }
    let floats = workspace.floating.keys.contains { windows[$0]?.isPresent == true && workspace.role(of: $0) == nil }
    guard floats || !workspace.tree.allWindows.isEmpty else { return }
    workspaces[display]?.reset(tree: workspace.tree)
  }

  /// Why `command` is not run for a link, if it would take away something a person made.
  func refusalForWhatALinkWouldCost(_ command: Command) -> String? {
    let cost = whatALinkWouldCost(command)
    guard cost.views > 0 || cost.names > 0 else { return nil }
    let lost = [cost.views > 0 ? Self.count(cost.views, "saved view") : nil, cost.names > 0 ? Self.count(cost.names, "name") : nil]
      .compactMap { $0 }.joined(separator: " and ")
    return "`\(command.nameWhenRefusedFromURL)` would cost \(lost), which a URL may not; "
      + "use a shortcut, the menu or arborctl, or set allowAllURLCommands to true in settings.json to allow it"
  }
}
