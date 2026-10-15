/// A few windows into one group, in one step (`side-by-side`; `collab/QUESTIONS.md`, Q29, 9).
extension Workspace {
  /// Takes `windows` out of wherever they are here, docked or floating, and docks them side by side in that order, equally
  /// wide, as a group of their own at the right end of the whole arrangement. The view goes onto the group, and Back leads
  /// to where it was. The places they leave close; whatever else is docked stays docked, in its order.
  ///
  /// Anything but `docked` has changed nothing. Fewer than two windows are no group.
  public mutating func dockSideBySide(_ windows: [WindowID], shareSpace: Bool = true) -> DockOutcome {
    guard windows.count >= 2, let first = windows.first else { return .notADock }
    var trial = self
    // One move of the view, however many steps it takes here: the first that leaves where it was is the one recorded.
    let wasOnEverything = trial.camera == trial.tree.root
    trial.moveCamera(to: trial.tree.root)
    // "Beside everything in view", with everything in view: the right end.
    var outcome = trial.tryDock(first, at: .cameraEdge(.right), shareSpace: shareSpace)
    guard outcome == .docked, let leaf = trial.tree.leaf(containing: first) else { return outcome }
    trial.moveCamera(to: leaf, record: wasOnEverything)
    // Beside what is in view and nothing else: the second makes a group of the two, which the view is then on and which stands
    // for as long as it is (LayoutTree+Keeps.swift); the others join it at its end, as wide as the average.
    for window in windows.dropFirst() {
      outcome = trial.tryDock(window, at: .cameraEdge(.right), shareSpace: shareSpace)
      guard outcome == .docked else { return outcome }
    }
    self = trial
    return .docked
  }
}
