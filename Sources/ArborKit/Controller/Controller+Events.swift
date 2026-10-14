import ArborCore
import CoreGraphics

extension Controller: WindowSystemEvents {
  public func windowAppeared(_ window: WindowSnapshot) {
    windows[window.id] = window
    // A window can have the keyboard before Arbor hears of it.
    defer { refreshFocusRing(.focus) }
    refreshHoldCaller()
    guard isRunning else { return }
    guard filter.manages(window) else {
      giveUpPendingSlot(of: window.id)
      return
    }
    if claimPendingSlot(for: window) { return }
    if let display = workspaceID(containing: window.id) {
      relayout(display, reason: .structure)
      return
    }
    // New windows float where their app put them, unless a rule says
    // otherwise (Controller+Rules.swift). They stay visible even if the camera
    // is away from the Desktop, until the camera next moves.
    if !joinPendingLayout(window.id) { adoptNewWindow(window.id) }
    summonAwaitedWindow()
    floatingWindowArrived(window.id)
    scheduleSave()
  }

  public func windowDestroyed(_ id: WindowID) {
    defer { holdForgets(id) }
    let app = windows[id]?.pid
    let appName = windows[id]?.appName
    windows[id] = nil
    parked.remove(id)
    settled[id] = nil
    misfits[id] = nil
    minimumSizes[id] = nil
    disprovedMinimums[id] = nil
    parkedAgain[id] = nil
    landsAt[id] = nil
    leftInFullScreen.notes[id] = nil
    chosenOnShape[id] = nil
    appPlacedFrames[id] = nil
    spokeOfItsPlace[id] = nil
    shrunk[id] = nil
    hints[id] = nil
    let hadKeyboard = hadKeyboard(id)
    unplaced.remove(id)
    owedTheWayBack[id] = nil
    owedMoves.remove(id)
    returningWindows.remove(id)
    if unframedIntoATile?.window == id || unframedIntoATile?.heir == id { unframedIntoATile = nil }
    enforcement.reset([id])
    forgetRuleState(of: id)
    releasePendingSlot(of: id)
    if drag?.window == id { cancelDrag() }
    guard isRunning else { return }
    // It cannot be undone, and `undo` says so if the window was docked (Controller+Undo.swift).
    let undoScope = beginUndoStep("the closing of \(appName.map { "a window of \($0)" } ?? "\(id)")")
    defer { endUndoStep(undoScope) }
    for display in workspaces.keys.sorted() where workspaces[display]!.contains(id) {
      if !slotWaitsAgain(after: id, on: display) {
        workspaces[display]!.forget(id, shareSpace: settings.shareRemovedSpace)
      }
      relayout(display, reason: .structure)
      if hadKeyboard { keyboardLeft(id, of: app, on: display) }
    }
    // The arrangement of a display that is away would carry the number, and its pin, into state.json, and
    // numbers start again after a reboot: another window would be taken for this one.
    forgetInDormantWorkspaces(id)
    scheduleSave()
  }

  public func windowChanged(_ window: WindowSnapshot, userInitiated: Bool) {
    let previous = windows[window.id]
    // Every window Arbor moves reports back what Arbor knows already. Storing that would count as a change of `windows`.
    if previous != window { windows[window.id] = window }
    if owedTheWayBack[window.id] != nil { payTheWayBack(to: window.id) }
    noteWhetherItCameBack(window, was: previous)
    putBackIfItLeftFullScreen(window, was: previous)
    meetAtItsSlotIfItLeftFullScreen(window, was: previous)
    defer { focusRingFollows(window) }
    if previous?.title != window.title { refreshHoldCaller() }
    defer { if previous?.frame != window.frame { notify(.frames) } }
    // Before the check below, because a late title can also end an `ignore`. If a rule takes over, it
    // moves the window, and the rest of this is about where `window` says the window is.
    if previous?.title != window.title, recheckRules(for: window.id) { return }
    guard isRunning, filter.manages(window) else { return }
    guard let display = workspaceID(containing: window.id) else {
      adopt(window.id, rescue: false)
      floatingWindowArrived(window.id)
      scheduleSave()
      return
    }
    hints[window.id] = WindowHint(bundleID: window.bundleID, title: window.title)
    if previous?.title != window.title {
      notify(.windows)
      if claimPendingSlot(for: window) { return }
    }

    // A Space switch reports each window separately: see Controller+Spaces.swift.
    if previous?.isOnActiveSpace != window.isOnActiveSpace {
      scheduleSpaceRelayout(display)
      return
    }

    // Hiding or showing an app also reports each of its windows separately. Laying out after each would move
    // windows of the app that is being hidden, and their neighbours once per window.
    if let previous, previous.isHidden != window.isHidden {
      scheduleSpaceRelayout(display)
      if window.isPresent {
        returningWindows.insert(window.id)
      } else if hadKeyboard(window.id) {
        keyboardLeft(window.id, of: nil, on: display)
      }
      scheduleSave()
      return
    }

    // Minimizing or restoring changes who takes up space.
    if previous?.isPresent != window.isPresent {
      relayout(display, reason: .structure)
      // It may have been given the keyboard before it was reported back (Controller+Focus.swift).
      if window.isPresent {
        bringIntoViewIfFocused(window.id, retries: 0)
      } else if hadKeyboard(window.id) {
        keyboardLeft(window.id, of: window.pid, on: display)
      }
      scheduleSave()
      return
    }

    if lowerDisprovedMinimum(of: window) {
      relayout(display, reason: .structure)
      return
    }
    noteThatTheAppAnswers(window, on: display)

    // macOS sometimes pulls a window that is mostly off screen back onto it (seen when another window of
    // its app leaves full screen). It goes back to the corner with the next put-back.
    if hasLeftItsCorner(window.id) { scheduleEnforce(display) }

    guard userInitiated, drag?.window != window.id, !parked.contains(window.id) else { return }

    // A display has come or gone and Arbor has not heard yet: the report waits until the displays have settled
    // (`DisplayChange`), and macOS moves windows itself meanwhile. Taken for the user's doing, that would give a
    // floating window a new home, and it would not go back with its display. Which displays there are counts,
    // not their order, which is never reported by itself.
    guard knowsTheDisplays else { return noteMoveBehindArborsBack(of: window.id) }

    if workspaces[display]!.isFloating(window.id) {
      // A new title arrives the same way as a move. Taking it for one would replace the frame
      // the user chose with wherever docked windows have pushed the window to since.
      guard previous?.frame != window.frame, !isOnlySettlingOnDesktop(window, on: display) else { return }
      // Remember where the user put it, following it to another display.
      let destination = displayID(at: window.frame.center) ?? display
      let role = workspaces[display]!.role(of: window.id)
      summonedWindowIsCarried(window.id, to: destination)
      let remembered = frameToRemember(of: window.id, movedFrom: previous?.frame, to: window.frame)
      if destination != display { workspaces[display]!.floating[window.id] = nil }
      workspaces[destination]?.floating[window.id] = remembered
      spokeOfItsPlace[window.id] = now()
      // No hand takes a window to another display without a drag, and a drag writes its own note at the drop.
      // What comes here across a border is an app's, a tool's or macOS's doing, and while the displays change
      // it is judged by the old ones: such a place is remembered, and fitted like any other that nobody chose.
      if destination == display { noteWhereItsUserLeftIt(window.id) } else { chosenOnShape[window.id] = nil }
      if destination != display { workspaces[destination]?.setRole(role, of: window.id) }
      if destination != display { notify(.windows) }
      scheduleSave()
      floatingWindowMoved(window.id, from: display)
      return
    }

    // A docked window was moved or resized by something else (an edge drag,
    // another tool, the app itself). Small differences are the app rounding
    // the size we asked for; anything bigger is put back once the mouse is up.
    if let settledFrame = settled[window.id], settledFrame.approximatelyEquals(window.frame, tolerance: 4) {
      return
    }
    if enforcement.givenUp.contains(window.id) {
      settled[window.id] = window.frame
      return
    }
    scheduleEnforce(display)
  }

  public func windowFocused(_ id: WindowID) {
    endFocusRequest(unlessFor: id)
    closeFinderBecauseTheUserLeft(for: id)
    namePromptNoticesFocus(on: id)
    holdNotesFocus(of: id)
    defer { notify(.focus(id)) }
    bringIntoViewIfFocused(id)
  }

  /// Moves the camera, or switches tabs, so that `id` shows. Does nothing if it already does.
  /// `onItsWayBack`: see `reveal(_:leaf:on:onItsWayBack:)`.
  func bringIntoView(_ id: WindowID, onItsWayBack: Bool = false) {
    guard isRunning, drag == nil, isManaged(id), let display = workspaceID(containing: id) else {
      return
    }
    guard !holdTurnsAway(id) else { return }
    holdLetsIn(id)
    let workspace = workspaces[display]!
    if let leaf = workspace.tree.leaf(containing: id) {
      let inactiveTab = workspace.tree.activeWindow(of: leaf) != id
      if inactiveTab { workspaces[display]!.tree.activate(id) }
      if parked.contains(id) || layouts[display]?.windowFrames[id] == nil {
        reveal(id, leaf: leaf, on: display, onItsWayBack: onItsWayBack)
      } else if inactiveTab {
        relayout(display, reason: .structure)
      }
    } else if parked.contains(id), let host = workspace.guests?[id] {
      moveCamera(on: display, to: host)
    } else if parked.contains(id) {
      if summonIfStashed(id) { return }
      // A floating window out of view: zoom out until the Desktop is part of the view, as a tile if need be. Onto the
      // Desktop itself if the view is on one window, whose level is kept (`isFramedOnOneSpace`).
      let desktop = workspace.tree.desktop
      let common = Navigation.commonAncestor(workspace.camera, desktop, in: workspace.tree)
      moveCamera(on: display, to: isFramedOnOneSpace(workspace) ? desktop : common)
    }
  }

  public func displaysChanged() {
    // The places of the line and the panel of shortcuts were worked out for displays as they were, and macOS would move
    // what is on a display that goes to one where nobody put it. Also during a pause, which says that it began.
    hideCheatSheet()
    hideHeadsUp()
    guard isRunning else { return }
    closeFinderBecauseTheUserLeft()
    // Displays that go away keep their arrangement and get it back when they
    // return: see Controller+Displays.swift.
    updateDisplays()
  }
}

extension Controller: OverlayActions {
  public func tileActivated(display: DisplayID, node: NodeID) {
    guard isRunning, workspaces[display]?.tree.contains(node) == true else { return }
    // Refused as the command it stands for, so that a click that does nothing is told why in the words a key is.
    guard holdLevel != .view else { return _ = perform(.zoomNode(node), from: .gesture) }
    moveCamera(on: display, to: node)
    if let layout = layouts[display],
      let first = workspaces[display]?.tree.windows(under: node).first(where: { layout.windowFrames[$0] != nil })
    {
      system.focus(first)
    }
  }

  public func seamDragged(display: DisplayID, seam: Seam, by delta: CGFloat) {
    guard isRunning, settings.appearanceOptions.gapHandles != .off, workspaces[display] != nil else { return }
    let undoScope = beginUndoStep(dragging: seam, on: display)
    defer { endUndoStep(undoScope) }
    workspaces[display]!.tree.moveBoundary(at: seam, by: Double(delta), minimumPoints: minimumPointsBesideSeam(on: display))
    // The windows follow the mouse.
    byHand { relayout(display, reason: .structure, motion: .instant) }
    scheduleSave()
  }
}
