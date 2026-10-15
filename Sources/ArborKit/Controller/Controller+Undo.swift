import ArborCore
import CoreGraphics

/// Undo and redo for changes to the arrangement (docs/features/F19-undo.md).
///
/// Recording: whatever may change a workspace runs between `beginUndoStep` and `endUndoStep` (or
/// inside `recordingUndo`). `perform` does that for every command; the entry points that are not
/// commands (drops, seam drags, edge resizes, rules, windows closing) do it themselves. Afterwards the
/// workspaces are compared with how they were, and each display whose arrangement changed gets a step.
///
/// Restoring: a step holds a workspace from the past, so it is first fitted to the windows that
/// exist now (`restorations`), then installed and laid out.
extension Controller {
  /// A change that is being made: what to call it, and how things were before.
  struct UndoScope {
    var label: String
    /// See `UndoStep.title`. Nil: the first word of the label.
    var title: String?
    var before: [DisplayID: Workspace]
    var framesBefore: [DisplayID: [WindowID: CGRect]]
    var continuation: UndoContinuation?
    /// See `UndoHistory.record`.
    var keepsRedo = false
  }

  /// Makes one step of changes that follow each other under the same key with no other step in
  /// between (see `UndoHistory.record`), until it ends.
  struct UndoContinuation {
    enum End {
      /// A gesture made with the mouse.
      case whenTheButtonIsUp
      /// Repeated presses of a key: `undoMergePause` seconds without another.
      case afterAPause
      /// Whoever began it calls `undoHistory.finishContinuation(key)`.
      case whenToldTo
    }

    var key: String
    var ends: End
  }

  /// Presses of a shortcut further apart than this are separate adjustments.
  public static let undoMergePause = 1.0

  // MARK: Recording

  /// Call before changing any workspace, and hand the result to `endUndoStep` afterwards.
  /// `label` says what the change is, in the words of a command; `title`, in a word or two for the menu ("Dock"), if
  /// the first word of the label will not do.
  func beginUndoStep(
    _ label: @autoclosure () -> String, title: String? = nil, continuing continuation: UndoContinuation? = nil
  ) -> UndoScope? {
    undoScopeDepth += 1
    // Inside a change that is already being recorded, which will cover this one.
    guard undoScopeDepth == 1 else { return nil }
    treesBeforeRoomWasMade = [:]
    slotsDroppedDuringUndoStep = []
    undoHistory.forgetRenumberings()
    return UndoScope(
      label: label(), title: title, before: workspaces, framesBefore: floatingFramesOnScreen(),
      continuation: continuation)
  }

  func beginUndoStep(for command: Command) -> UndoScope? {
    var scope = beginUndoStep(command.label(focused: system.focusedWindow()), title: command.undoTitle)
    switch command {
    case .toggleFloat(let window):
      let docked = (window ?? system.focusedWindow()).map { id in workspaces.values.contains { $0.isDocked(id) } }
      scope?.title = docked == true ? "Float" : "Dock"
    case .exclude(let bundleID):
      // It cannot be undone, being a setting. `undo` says so, and then it should say what can be done.
      if let bundle = bundleID ?? system.focusedWindow().flatMap({ windows[$0]?.bundleID }) {
        scope?.label = "exclude \(bundle) (`include \(bundle)`, or Arrangement → Arrange Again in the menu, takes that back)"
      }
    default:
      break
    }
    // Walking through the history is not itself a step.
    if command == .undo || command == .redo { scope?.before = [:] }
    // Nor is a visit of ten seconds, though it can bring a floating window over from another display.
    if case .summon = command { scope?.before = [:] }
    if command.mergesWithRepeats, let label = scope?.label {
      scope?.continuation = UndoContinuation(key: label, ends: .afterAPause)
    }
    return scope
  }

  /// Records a step on every display whose arrangement differs from what it was at `beginUndoStep`.
  func endUndoStep(_ scope: UndoScope?) {
    undoScopeDepth -= 1
    guard let scope else { return }
    var changes: [DisplayID: UndoHistory.Change] = [:]
    for (display, var before) in scope.before {
      // A window that changed its number meanwhile (its slot waits again under a stand-in's) is still the same window.
      for change in undoHistory.renumberings { before.renumber(change.old, as: change.new) }
      // A place whose time was up went with this change's layout (`dropOverdueSlots`). That is Arbor giving up its
      // waiting, not a change anybody made: a move of the view would otherwise be a step, and one that cannot be
      // taken back.
      for slot in slotsDroppedDuringUndoStep { before.forget(slot, shareSpace: settings.shareRemovedSpace) }
      guard let after = workspaces[display], !before.hasSameArrangement(as: after) else { continue }
      // Nothing happened but that Arbor moved the gaps to make room for a window (F61): the view moved, say. That is
      // not a change anybody made, and taking it back would only make Arbor do it again.
      if let found = treesBeforeRoomWasMade[display], before.tree.hasSameArrangement(as: found),
        before.tree.preorder() == after.tree.preorder(), Set(before.floating.keys) == Set(after.floating.keys)
      {
        continue
      }
      changes[display] = UndoHistory.Change(
        before: before, framesBefore: scope.framesBefore[display] ?? [:], after: after)
    }
    guard !changes.isEmpty else { return }
    let steps = changes.mapValues { UndoStep(id: 0, label: scope.label, workspace: $0.before, changedTo: $0.after) }
    // Tried out against what the change itself left: the room Arbor then made (F61) it would only make again.
    var left = workspaces
    for (display, tree) in treesBeforeRoomWasMade { left[display]?.tree = tree }
    guard restorations(from: steps).contains(where: { left[$0.key]?.hasSameArrangement(as: $0.value.workspace) != true }) else {
      // It cannot be taken back: a window that closed stays closed, and `exclude` removes windows an undo
      // would not bring back. If it changed what is docked, the user saw it happen, and `undo` says
      // so once instead of silently taking back something older.
      let seen = changes.filter { !$0.value.before.tree.hasSameArrangement(as: $0.value.after.tree) }
      undoHistory.recordIrreversible(scope.label, leaving: seen.mapValues(\.after))
      return
    }
    undoHistory.record(
      scope.label, title: scope.title, changes: changes, continuing: scope.continuation?.key,
      keepingRedo: scope.keepsRedo)
    if let continuation = scope.continuation { scheduleEnd(of: continuation) }
  }

  /// Called before a layout moves gaps by itself (Controller+MakeRoom.swift).
  func noteThatRoomIsMade(on display: DisplayID) {
    guard undoScopeDepth > 0, treesBeforeRoomWasMade[display] == nil else { return }
    treesBeforeRoomWasMade[display] = workspaces[display]?.tree
  }

  /// Runs `change` as one undoable step. `keepingRedo`: see `UndoHistory.record`.
  func recordingUndo<T>(
    _ label: @autoclosure () -> String, title: String? = nil, keepingRedo: Bool = false, _ change: () -> T
  ) -> T {
    var scope = beginUndoStep(label(), title: title)
    scope?.keepsRedo = keepingRedo
    defer { endUndoStep(scope) }
    return change()
  }

  /// A space in the label of a step: by what is in it, also when it has a name (see `Command.label(focused:)`).
  private func words(for node: NodeID, on display: DisplayID) -> String { name(of: node, on: display, byName: false) }

  /// A seam drag arrives as many small moves. Those made on one seam while the button stays down are one step.
  func beginUndoStep(dragging seam: Seam, on display: DisplayID) -> UndoScope? {
    let key = "seam \(display) \(seam.split) \(seam.leading) \(seam.trailing)"
    return beginUndoStep(
      "drag the gap between \(words(for: seam.leading, on: display)) and \(words(for: seam.trailing, on: display))",
      title: "Resize",
      continuing: system.isMouseButtonDown() ? UndoContinuation(key: key, ends: .whenTheButtonIsUp) : nil)
  }

  private func scheduleEnd(of continuation: UndoContinuation) {
    let wait: Double
    switch continuation.ends {
    // Nothing tells the controller that the button went up over one of Arbor's own panels, so it looks.
    case .whenTheButtonIsUp: wait = 0.25
    // Every further change under the key asks again, which puts the end off.
    case .afterAPause: wait = Self.undoMergePause
    case .whenToldTo: return
    }
    scheduler.schedule("undo-continuation \(continuation.key)", after: wait) { [weak self] in
      guard let self else { return }
      // Paused or stopped, Arbor looks at nothing, and what is done when it runs again is not more of the same change.
      if self.isRunning, case .whenTheButtonIsUp = continuation.ends, self.system.isMouseButtonDown() {
        self.scheduleEnd(of: continuation)
      } else {
        self.undoHistory.finishContinuation(continuation.key)
      }
    }
  }

  /// Call when a drag begins, before anything moves. By the time the window is dropped it is
  /// wherever the pointer took it (and others may have made room for it), and undoing the drop
  /// should send everything back to where it was when the window was picked up.
  func rememberDragOrigin(of window: WindowID) {
    dragOrigin = (window, floatingFramesOnScreen())
  }

  /// Call before a dragged window is dropped on `target`, which refers to `display`'s tree.
  func beginUndoStep(dropping window: WindowID, on target: DropTarget, of display: DisplayID?) -> UndoScope? {
    func space(_ node: NodeID) -> String { display.map { words(for: node, on: $0) } ?? "\(node)" }
    let label =
      switch target {
      case .cameraEdge(let edge): "drag \(window) to the \(edge.rawValue) edge"
      case .beside(let node, let edge): "drag \(window) to the \(edge.rawValue) of \(space(node))"
      case .stack(let node): "drag \(window) onto \(space(node)) as a tab"
      case .float: "drag \(window) to the Desktop"
      case .none: "drag \(window) back"
      }
    let title =
      switch target {
      case .cameraEdge, .beside, .stack: "Dock"
      case .float: "Float"
      case .none: "Drag"
      }
    var scope = beginUndoStep(label, title: title)
    if let origin = dragOrigin, origin.window == window {
      scope?.framesBefore = origin.frames
    } else {
      // Nobody saw it picked up. Where it is now is not where it belongs.
      for display in workspaces.keys { scope?.framesBefore[display]?[window] = nil }
    }
    dragOrigin = nil
    return scope
  }

  /// Where each display's floating windows are, leaving out those that are out of view.
  private func floatingFramesOnScreen() -> [DisplayID: [WindowID: CGRect]] {
    var result: [DisplayID: [WindowID: CGRect]] = [:]
    for (display, workspace) in workspaces {
      // All of the Desktop is not a place anybody chose for the window that has it to itself (F18).
      let filling = windowThatTakesDesktop(of: display)
      var frames: [WindowID: CGRect] = [:]
      for window in workspace.floating.keys where !parked.contains(window) && window != filling {
        if let snapshot = windows[window], snapshot.isPresent { frames[window] = snapshot.frame }
      }
      result[display] = frames
    }
    return result
  }

  // MARK: Commands

  func undo() -> CommandResult { stepThroughHistory(.undo) }
  func redo() -> CommandResult { stepThroughHistory(.redo) }

  /// What `undo` or `redo` would take back or put back on a display (by default the one they would
  /// act on now if they came from `source`), or nil when it has nothing to do.
  public func nextStepLabel(
    _ direction: UndoHistory.Direction, on display: DisplayID? = nil, from source: CommandSource = .script
  ) -> String? {
    nextStep(direction, on: display, from: source)?.label
  }

  /// The same for a menu: "Dock", for "Undo Dock".
  public func nextStepTitle(_ direction: UndoHistory.Direction, from source: CommandSource = .menu) -> String? {
    nextStep(direction, on: nil, from: source)?.title
  }

  /// What `undo` or `redo`, which has just succeeded, says on screen: "Undid Dock". On the display a person reads the
  /// menu's language; the reply, for a terminal, keeps the words of commands.
  func wordsOnScreen(after command: Command) -> String? {
    switch command {
    case .undo: titleOfTheStepJustTaken.map { "Undid \($0)" }
    case .redo: titleOfTheStepJustTaken.map { "Redid \($0)" }
    default: nil
    }
  }

  private func nextStep(
    _ direction: UndoHistory.Direction, on display: DisplayID?, from source: CommandSource
  ) -> UndoStep? {
    // Choosing a display is remembered, so that shortcuts pressed one after another stay on it. Asking is not choosing.
    let lead = following.lead
    defer { following.lead = lead }
    guard let display = display ?? from(source, { cameraDisplay()?.0 }) else { return nil }
    // Tried out on a copy, passing over what `stepThroughHistory` would pass over.
    var history = undoHistory
    while true {
      let steps = history.take(direction, on: display)
      guard let step = steps[display] else { return nil }
      if !step.isIrreversible, changesAnArrangement(restorations(from: steps)) { return step }
    }
  }

  private func stepThroughHistory(_ direction: UndoHistory.Direction) -> CommandResult {
    let (verb, done) = direction == .undo ? ("undo", "undid") : ("redo", "redid")
    titleOfTheStepJustTaken = nil
    // The display every command without a window of its own acts on (F56 decides which that is).
    guard let (display, _) = cameraDisplay() else { return .failure("no display") }
    // Its arrangement is on another of the macOS Spaces: a shortcut pressed here would rearrange what cannot be seen.
    if let focused = system.focusedWindow(), windows[focused]?.isFullScreen == true {
      return .failure("\(focused) is full screen")
    }
    // Laying out now would pull the window out of the user's hand.
    if system.isMouseButtonDown(), drag != nil || edgeResize != nil {
      return .failure("cannot \(verb) while a window is being dragged")
    }
    undoHistory.finishContinuation()
    while true {
      let steps = undoHistory.take(direction, on: display)
      guard let step = steps[display] else { return .failure("nothing to \(verb)" + onPointerDisplay) }
      if step.isIrreversible {
        let next = nextStepLabel(direction, on: display).map { "; \(verb) again to take back \($0)" } ?? ""
        return .failure("cannot \(verb) \(step.label)\(next)")
      }
      var plan = restorations(from: steps)
      // Every window the step was about has closed since. Go on to one that still shows.
      guard changesAnArrangement(plan) else { continue }
      for id in steps.keys { plan[id] = plan[id].map { steppingOutToShowTheChange($0, on: id) } }
      let frames = floatingFramesOnScreen()
      for (id, restoration) in plan {
        guard let current = workspaces[id] else { continue }
        undoHistory.push(
          UndoStep(
            id: step.id, label: step.label, title: step.title, workspace: current, frames: frames[id] ?? [:],
            changedTo: restoration.workspace),
          to: direction.opposite, on: id)
      }
      install(plan)
      titleOfTheStepJustTaken = step.title
      return .success("\(done) \(step.label)")
    }
  }

  // MARK: Restoring

  /// A workspace from the past fitted to the present.
  struct Restoration {
    var workspace: Workspace
    /// Where floating windows were on screen when the step was saved, for those that go back there.
    var frames: [WindowID: CGRect] = [:]
    /// The camera ends up where it was when the step was saved, so what was in view then is again.
    var showsTheViewOfTheStep = false
  }

  private func changesAnArrangement(_ restorations: [DisplayID: Restoration]) -> Bool {
    restorations.contains { workspaces[$0.key]?.hasSameArrangement(as: $0.value.workspace) != true }
  }

  /// What to install to go back to `steps` (one per display), fitted to what has happened since
  /// they were saved. Changes nothing. Every window stays in exactly one workspace:
  /// - windows that closed, or that Arbor no longer arranges, leave the restored tree the usual way;
  /// - windows docked on a display that is not being restored stay there, as when a display
  ///   reconnects. Windows floating on one come back to their slots, so that display is in the result
  ///   as well; but a window that only floated here was moved there since, and stays;
  /// - windows on a restored display that its old workspace does not know (they opened since) float.
  /// Minimized windows and windows on other Spaces are still arranged, so they keep their slots. So do slots
  /// that still wait for their window (Controller+PendingSlots.swift).
  func restorations(from steps: [DisplayID: UndoStep]) -> [DisplayID: Restoration] {
    // A waiting slot is a place in a tree and nothing else: there is no window that could float.
    func exists(_ window: WindowID, in workspace: Workspace) -> Bool {
      isManaged(window) || (pendingSlots.contains(window) && workspace.isDocked(window))
    }
    let restoring = steps.keys.filter { workspaces[$0] != nil }.sorted()
    let others = workspaces.filter { steps[$0.key] == nil }.values
    let dockedElsewhere = Set(others.flatMap(\.tree.allWindows))
    let floatingElsewhere = Set(others.flatMap(\.floating.keys))
    var fitted: [DisplayID: Workspace] = [:]
    var claimed = Set<WindowID>()
    for display in restoring {
      guard var workspace = steps[display]?.workspace else { continue }
      for window in workspace.allWindows {
        let staysElsewhere =
          dockedElsewhere.contains(window) || (floatingElsewhere.contains(window) && workspace.isFloating(window))
        if exists(window, in: workspace), !staysElsewhere, claimed.insert(window).inserted { continue }
        workspace.forget(window, shareSpace: settings.shareRemovedSpace)
      }
      fitted[display] = workspace
    }

    var result: [DisplayID: Restoration] = [:]
    for display in restoring {
      guard let step = steps[display], var old = fitted[display], let current = workspaces[display] else { continue }
      for window in current.allWindows where !claimed.contains(window) && !pendingSlots.contains(window) {
        old.floating[window] = current.floating[window] ?? floatingFrame(for: window, on: display)
      }
      // Compare like with like: the current workspace has already lost the windows that closed.
      var reference = step.changedTo
      for window in reference.allWindows where !exists(window, in: reference) { reference.forget(window, shareSpace: settings.shareRemovedSpace) }
      let workspace = old.restored(over: current, since: reference)
      // A floating window the user has moved since stays where it is now.
      let frames = step.frames.filter { workspace.floating[$0.key] != nil && workspace.floating[$0.key] == old.floating[$0.key] }
      result[display] = Restoration(
        workspace: workspace, frames: frames, showsTheViewOfTheStep: workspace.camera == old.camera)
    }
    for (display, workspace) in workspaces where steps[display] == nil {
      let leaving = workspace.floating.keys.filter { claimed.contains($0) }
      guard !leaving.isEmpty else { continue }
      var updated = workspace
      for window in leaving { updated.floating[window] = nil }
      updated.dropGuestsThatLeft()
      result[display] = Restoration(workspace: updated)
    }
    return result
  }

  /// With one window framed, a change elsewhere in the tree would show nothing, and the user would press
  /// again. Or it would show only that a window has left, and not where it went. So when the view would stay
  /// put, it steps out just far enough to look different and to have the windows that changed places in it.
  /// `back` returns.
  private func steppingOutToShowTheChange(_ restoration: Restoration, on display: DisplayID) -> Restoration {
    let restored = restoration.workspace
    guard let current = workspaces[display], current.camera == restored.camera,
      current.tree.isSameNode(current.camera, in: restored.tree)
    else { return restoration }
    // Where the windows that change places end up: in their slots, or on the Desktop.
    let destinations = restored.allWindows
      .filter { windows[$0]?.isPresent == true && !restored.staysInView($0) && !restored.isStashed($0) }
      .filter { restored.tree.place(of: $0) != current.tree.place(of: $0) }
      .map { restored.tree.leaf(containing: $0) ?? restored.tree.desktop }
    var node = restored.camera
    while looksTheSame(current, restored, from: node, on: display)
      || !destinations.allSatisfy({ restored.tree.subtree(node, contains: $0) })
    {
      // Nothing to see from anywhere: every window the change is about is minimized, say.
      guard let parent = restored.tree.parent(of: node) else { return restoration }
      node = parent
    }
    guard node != restored.camera else { return restoration }
    var widened = restoration
    widened.workspace.moveCamera(to: node)
    widened.showsTheViewOfTheStep = false
    return widened
  }

  /// Whether both workspaces put the same picture on `display` with the camera on `node`.
  private func looksTheSame(_ a: Workspace, _ b: Workspace, from node: NodeID, on display: DisplayID) -> Bool {
    guard a.tree.isSameNode(node, in: b.tree), let before = layout(of: a, camera: node, on: display),
      let after = layout(of: b, camera: node, on: display)
    else { return false }
    return before.windowFrames == after.windowFrames && before.tiles == after.tiles
      && before.desktopFrame == after.desktopFrame
      && (before.desktopFrame == nil || Set(a.floating.keys) == Set(b.floating.keys))
  }

  /// How `display` would be laid out if `workspace` were its workspace.
  private func layout(of workspace: Workspace, camera: NodeID, on display: DisplayID) -> Layout? {
    let installed = workspaces[display]
    workspaces[display] = workspace
    defer { workspaces[display] = installed }
    return layout(of: display, camera: camera)
  }

  private func install(_ restorations: [DisplayID: Restoration]) {
    let previous = workspaces
    for (display, restoration) in restorations { workspaces[display] = restoration.workspace }
    for (display, restoration) in restorations.sorted(by: { $0.key < $1.key }) {
      let plan = floatingPlan(for: restoration, replacing: previous[display], on: display)
      // What the person squeezed into a tile is remembered by node (Controller+MakeRoom.swift), and a number can mean another place now.
      if let old = previous[display]?.tree {
        let kept = squeezedByHand[display]?.filter { old.isSameNode($0, in: restoration.workspace.tree) }
        squeezedByHand[display] = kept?.isEmpty == false ? kept : nil
      }
      // The layout moves them itself, once its stage is up: a window moved before that would vanish without a trace, and
      // one moved after it would jump when the stage lifts (Controller+Transitions.swift).
      placedOnPurpose = Set(plan.places.keys).union(plan.homes.keys)
      leavingView = plan.leaving
      if let window = plan.inHand { soleFloats.inHand[display] = window }
      let moving = plan.places.merging(plan.homes) { place, _ in place }.filter { window, frame in
        parked.contains(window) || windows[window]?.frame.approximatelyEquals(frame, tolerance: 1) != true
      }
      // By hand: the person has asked for these very gaps. If Arbor moved them again to make room (F61), an undo could end
      // where it began, and the redo after it would find nothing to do and reach for an older step.
      byHand {
        relayout(
          display, reason: .structure,
          puttingBack: moving.sorted { $0.key < $1.key }.map { (window: $0.key, frame: $0.value) })
      }
      workspaces[display]?.desktopIsOwedRoom = restoration.workspace.desktopIsOwedRoom
      placedOnPurpose = []
      leavingView = []
      // Layouts take a floating window that is where Arbor put it for one on the Desktop, which these are.
      for window in plan.homes.keys { settled[window] = windows[window]?.frame }
      ensureFocusIsVisible(on: display)
      notify(.camera(display))
      notify(.savedViews(display))
      notify(.names(display))
    }
    forgetPendingSlotsWithoutAPlace()
    scheduleSave()
  }

  /// What becomes of the floating windows of a restored workspace that a layout would leave alone or treat otherwise.
  struct FloatingPlan {
    /// Back to where they were in view when the step was saved, be it off the Desktop: a new window stays over a framed
    /// one until the camera moves, and comes back with that view.
    var places: [WindowID: CGRect] = [:]
    /// To their place on the Desktop (or, for a pinned window or a guest, on the display).
    var homes: [WindowID: CGRect] = [:]
    /// Out of view.
    var leaving: Set<WindowID> = []
    /// Alone on the Desktop without filling it when the step was saved: its user had taken it in hand (F18), and has again.
    var inHand: WindowID?
  }

  /// A layout keeps the windows on the Desktop on it, and leaves the other floating windows alone. After an undo these may
  /// still be in the slot they were docked in, or on another display. Changes nothing.
  private func floatingPlan(
    for restoration: Restoration, replacing previous: Workspace?, on displayID: DisplayID
  ) -> FloatingPlan {
    guard let display = display(displayID) else { return FloatingPlan() }
    let workspace = restoration.workspace
    let layout = layout(of: displayID)
    let desktop = layout?.desktopFrame.map { floatingRegion($0, on: display) }
    let desktopIsPartOfTheView = workspace.tree.subtree(workspace.camera, contains: workspace.tree.desktop)
    let alone = windowThatTakesDesktop(of: displayID)
    let cameraStayed =
      previous.map { $0.camera == workspace.camera && $0.tree.isSameNode($0.camera, in: workspace.tree) } ?? false
    var plan = FloatingPlan()
    for (window, preferred) in workspace.floating.sorted(by: { $0.key < $1.key }) {
      // A stashed window is out of view whatever the camera shows, and every layout sees to that (Controller+Summon.swift).
      guard let current = windows[window], current.isPresent, !workspace.isStashed(window) else { continue }
      let isOutOfView = parked.contains(window)
      let floatsInView = previous?.isFloating(window) == true && !isOutOfView
      // The display may have shrunk or moved since: a place that is no longer on it does not count. Half of the
      // window, because that is what `putBack`, which takes it there, asks for before it slides it onto the display.
      // **Keep the two in step**: a place accepted here that `putBack` refuses is a window made smaller or slid aside.
      let known = restoration.frames[window].flatMap { $0.fractionInside(display.frame) >= 0.5 ? $0 : nil }
      // A pinned or summoned window keeps its place whatever is in view (Controller+Pin.swift), a guest while its host is in view and
      // the Desktop is not (Controller+Guests.swift).
      let isGuestInView = desktop == nil && layout.map { hostInView(of: window, in: workspace, layout: $0) != nil } == true
      if workspace.staysInView(window) || isGuestInView {
        if let known {
          plan.places[window] = known
        } else if !floatsInView {
          plan.homes[window] = preferred.fitted(into: display.visibleFrame)
        }
      } else if window == alone, desktop != nil, restoration.frames[window] == nil {
        // Alone on the Desktop, it takes all of it, which is for the layout to see to (Controller+SoleFloat.swift).
      } else if let desktop {
        if window == alone { plan.inHand = window }
        // Where its app opened it is not a place anybody chose: layouts move it onto the Desktop from there.
        let whereItsAppPutIt = appPlacedFrames[window] == preferred
        // Nor may any other hang over the edge of the screen, as in `floatingMoves`: of a place left across two displays, one of which
        // has gone since, a strip would show. (This display's history outlives the other display.)
        let leftThere = !whereItsAppPutIt && wasLeftThereByItsUser(preferred, of: window, on: display)
        let room = leftThere ? reach(of: desktop, for: preferred, on: display) : desktop
        let home = floatingFrame(preferred, on: room, of: display, minimum: minimumSizes[window])
        if let known, !known.approximatelyEquals(home, tolerance: 2), !whereItsAppPutIt {
          plan.places[window] = known
        } else if known != nil || !floatsInView {
          plan.homes[window] = home
        }
      } else if let known, restoration.showsTheViewOfTheStep {
        plan.places[window] = known
      } else if desktopIsPartOfTheView {
        // The Desktop is in the view, only too small to use: its windows are in view all the same, over the docked
        // ones, each where the user last had it (`floatingMoves`). One that is there already is left alone.
        if !floatsInView { plan.homes[window] = preferred.fitted(into: display.visibleFrame) }
      } else if restoration.showsTheViewOfTheStep, floatsInView, restoration.frames[window] == current.frame {
        // In view with this view when the step was saved, and still there: nothing to move, so what `putBack` would make of
        // the place does not matter. A window larger than the display, or pushed aside until a strip shows.
      } else if !isOutOfView, !(floatsInView && cameraStayed) {
        plan.leaving.insert(window)
      }
    }
    return plan
  }
}
