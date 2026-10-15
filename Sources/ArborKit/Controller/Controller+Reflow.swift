import ArborCore
import CoreGraphics

/// Live reflow (`reflowWhileDragging`): while a window is dragged, the other windows show the
/// arrangement that letting go right now would produce. They close up when a docked window leaves
/// its slot, make room at a target once it is active, and make room again over its old slot.
///
/// Nothing here touches the real workspaces or `layouts`. Each arrangement shown is a trial: the
/// drop is applied to a copy of the workspaces (`Drop.apply`, the code the real drop uses) and the
/// copy is laid out. So the camera, history and saved views cannot change because of a drop
/// that was never made, and when the drag ends `settle` derives everything from the real trees again.
extension Controller {
  /// What live reflow has done during one drag.
  struct Reflow {
    /// The trial layout each display is showing instead of its own.
    var trials: [DisplayID: Layout] = [:]
    /// Every display that has shown a trial. They are laid out for real when the drag ends.
    var touched: Set<DisplayID> = []
    /// How the floating windows that trials have moved were before the drag.
    var floatsBefore: [WindowID: FloatingState] = [:]
    /// The minimum sizes that were known before the first trial.
    var minimumsBefore: [WindowID: CGSize]?
  }

  /// What `placeFloatingWindows` reads and changes about one floating window.
  struct FloatingState {
    var frame: CGRect
    var settled: CGRect?
    var isParked: Bool
  }

  /// Shows the arrangement a release would produce now, on every display it would change and
  /// every display still showing an earlier trial.
  func reflow() {
    guard let session = drag, settings.reflowWhileDragging || !session.reflow.trials.isEmpty else { return }
    // While a target waits to be held long enough, and where nothing can be dropped, the window counts as out of
    // the arrangement. (Let go then, a docked window goes back to its slot, but opening that for every target
    // passed would flicker.)
    let target = session.isActive && session.hover?.isNowhere != true ? session.hover?.target ?? .float : .float
    var trial = workspaces
    if let display = session.hover?.display ?? workspaceID(containing: session.window) {
      drop(of: session.window, on: target, display: display, at: session.point, sizeOwed: session.sizeOwed)?
        .apply(to: &trial)
    }
    for display in workspaces.keys.sorted() {
      guard let real = workspaces[display], let candidate = trial[display] else { continue }
      let differs = candidate.tree != real.tree || candidate.camera != real.camera
      // This moves windows without a layout, so past the fence of a held view (Controller+Hold.swift).
      if differs || session.reflow.trials[display] != nil, holdLetsShow(candidate, on: display) { show(candidate, on: display) }
    }
  }

  /// Moves the windows of `displayID`, all but the dragged one, to where `trial` puts them.
  private func show(_ trial: Workspace, on displayID: DisplayID) {
    // First: what Accessibility says of a window no trial has taught, so it does not go with the trials.
    noteFixedSizes(of: trial.tree.allWindows)
    if drag?.reflow.minimumsBefore == nil { drag?.reflow.minimumsBefore = minimumSizes }
    guard let dragged = drag?.window, var layout = layout(ofTrial: trial, on: displayID, without: dragged),
      layout != drag?.reflow.trials[displayID]
    else { return }
    layout = askingFirst(layout, on: displayID) { self.layout(ofTrial: trial, on: displayID, without: dragged) }
    if apply(layout, on: displayID), let retry = self.layout(ofTrial: trial, on: displayID, without: dragged) {
      // As in `relayout`: a window refused its slot, so it becomes a tile.
      layout = retry
      _ = apply(layout, on: displayID)
    }
    placeFloatingWindows(forTrial: trial, laidOutAs: layout, on: displayID)
    overlays.update(display: displayID, scene: overlayScene(for: layout, on: displayID))
    drag?.reflow.trials[displayID] = layout
    drag?.reflow.touched.insert(displayID)
  }

  /// `trial` laid out on `displayID`, leaving out `dragged` itself, which stays under the pointer:
  /// its slot is kept open, but nothing is put in it.
  private func layout(ofTrial trial: Workspace, on displayID: DisplayID, without dragged: WindowID) -> Layout? {
    guard let display = display(displayID) else { return nil }
    // A trial can be the real arrangement again: the window was carried over a target and away.
    var layout = laidOut(
      trial.tree, camera: trial.camera, on: display, options: options(for: displayID).layoutOptions,
      present: presentWindowIDs().union([dragged])
    ).layout
    layout.windowFrames[dragged] = nil
    layout.hiddenWindows.remove(dragged)
    layout.tiles.removeAll { $0.windows == [dragged] }
    return layout
  }

  /// With live reflow on and `window` docked on `displayID`: what that display shows once the
  /// window has left its slot, for matching the pointer against. Nil otherwise.
  func arrangement(without window: WindowID, on displayID: DisplayID) -> (layout: Layout, tree: LayoutTree)? {
    guard settings.reflowWhileDragging, var lifted = workspaces[displayID], lifted.isDocked(window) else {
      return nil
    }
    lifted.forget(window, shareSpace: settings.shareRemovedSpace)
    return layout(ofTrial: lifted, on: displayID, without: window).map { ($0, lifted.tree) }
  }

  /// Puts the floating windows of `displayID` where they would be if `trial`, laid out as `layout`, were real,
  /// by the rule that would put them there: `placeFloatingWindows`. With `keepPushed`, a window that a trial has
  /// moved aside stays there when a later trial gives the space back, and moves again only if it must.
  private func placeFloatingWindows(forTrial trial: Workspace, laidOutAs layout: Layout, on displayID: DisplayID) {
    guard let real = workspaces[displayID], let display = display(displayID) else { return }
    let resting = layouts[displayID]
    var before: [WindowID: FloatingState] = [:]
    for window in real.floating.keys {
      guard let frame = windows[window]?.frame else { continue }
      before[window] = FloatingState(frame: frame, settled: settled[window], isParked: parked.contains(window))
    }
    // The rule reads the workspace and what was on screen until now. For a trial those are the trial and the
    // last trial. They are lent to it for the length of this call, during which nothing else looks at them.
    var lent = trial
    if settings.keepPushed {
      // It keeps each window as near as it can to where the user put it: here, to where the last trial left it.
      for window in trial.floating.keys where drag?.reflow.floatsBefore[window] != nil && !parked.contains(window) {
        lent.floating[window] = windows[window]?.frame
      }
    }
    workspaces[displayID] = lent
    if let shown = drag?.reflow.trials[displayID] { layouts[displayID] = shown }
    placeFloatingWindows(on: displayID, layout: layout, reason: .structure)
    if layout.desktopFrame == nil {
      // A change of the arrangement takes no floating window out of view. But the ones an earlier trial
      // brought in with the Desktop were out of view before the drag, and leave with the Desktop.
      for window in lent.floating.keys.sorted()
      where window != drag?.window && drag?.reflow.floatsBefore[window]?.isParked == true && !parked.contains(window)
        && hostInView(of: window, in: lent, layout: layout) == nil
      {
        park(window, on: display)
      }
    }
    workspaces[displayID] = real
    layouts[displayID] = resting
    for (window, was) in before where drag?.reflow.floatsBefore[window] == nil {
      if windows[window]?.frame != was.frame || parked.contains(window) != was.isParked {
        drag?.reflow.floatsBefore[window] = was
      }
    }
  }

  /// After a drag: lays out `displays` (what the drop changed) and every display that showed a
  /// trial from their real trees, and leaves the floating windows that trials moved exactly where
  /// a drag without reflow would have.
  func settle(_ reflow: Reflow, layingOut displays: [DisplayID]) {
    // A window that refused a trial's slot has taught Arbor its minimum size. A drag without reflow would not have
    // asked, and what is known decides what later layouts do (room is made for a window whose minimum is known,
    // F61). So it goes with the trials; a real layout that needs it finds it out again.
    if let known = reflow.minimumsBefore { minimumSizes = known.filter { windows[$0.key] != nil } }
    // For the layouts below, those windows count as being where and as they were before the drag. So
    // each is placed from there if the final arrangement moves it at all, in one move and not two.
    var returning: [WindowID: (to: CGRect, from: CGRect)] = [:]
    // (One that was pinned, summoned or sent away meanwhile has been placed for that, and no trial moves it.)
    for (window, was) in reflow.floatsBefore
    where workspaces.values.contains(where: { $0.isFloating(window) && $0.role(of: window) == nil }) {
      guard let shown = windows[window]?.frame else { continue }
      windows[window]?.frame = was.frame
      settled[window] = was.settled
      if was.isParked { parked.insert(window) } else { parked.remove(window) }
      if shown != was.frame { returning[window] = (was.frame, shown) }
    }
    for display in displays { relayout(display, reason: .structure) }
    // Where the drop changed nothing, a drag without reflow lays nothing out: only put back what
    // the trials moved, without placing floating windows afresh.
    for display in reflow.touched.subtracting(displays).sorted() { relayout(display, reason: .enforce) }
    // The ones those layouts had no reason to move have yet to go back.
    for (window, way) in returning.sorted(by: { $0.key < $1.key }) where windows[window]?.frame == way.to {
      // An app that does not answer leaves its window where the trials put it, and that is what Arbor has to know:
      // when the app wakes, a frame that differs from the one on record is taken for its user's doing.
      // And what `give` has to know to reckon the way.
      windows[window]?.frame = way.from
      _ = give(way.to, to: window)
    }
  }
}
