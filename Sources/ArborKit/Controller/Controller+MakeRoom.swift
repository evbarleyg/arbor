import ArborCore
import CoreGraphics

/// Room before tiles (docs/features/F61-room-before-tiles.md). Before a layout turns a window into a tile only
/// because its slot is smaller than the window will go, Arbor moves the gaps around it, as the person would, and
/// takes the missing points from the Desktop and from neighbours that can spare them. Who gives how much and who
/// comes first is decided in `ArborCore.MakeRoom`; this is when it happens and when it must not.
extension Controller {
  /// The layout of a display after room has been made for the windows in view that are short of it.
  ///
  /// A minimum is only learned when a window refuses its slot, in the middle of a layout, after room may have been
  /// made for others on what was known till then. `before` is the workspace as that layout found it: starting from
  /// its gaps again, the outcome is what it would have been had everything been known at the start, and who comes
  /// first does not depend on whom Arbor happened to have met before.
  func roomyLayout(
    of displayID: DisplayID, for reason: RelayoutReason, startingFrom before: Workspace? = nil
  ) -> Layout? {
    if settings.makeRoom, !gapsInHand, let before, before.tree.preorder() == workspaces[displayID]?.tree.preorder() {
      workspaces[displayID]?.tree = before.tree
      workspaces[displayID]?.desktopIsOwedRoom = before.desktopIsOwedRoom
    }
    guard let (plain, late, atAWindowsCost) = layoutAndWhoIsLate(of: displayID) else { return nil }
    if atAWindowsCost { giveUpRoom(on: displayID) }
    // Which `MakeRoom.serve` sees to otherwise.
    if !settings.makeRoom, !plain.tiles.isEmpty, !gapsInHand, drag == nil, edgeResize == nil, var tree = workspaces[displayID]?.tree,
      MakeRoom.shareWhereTooLittleWasLeft(
        &tree, laidOutAs: plain, options: options(for: displayID).layoutOptions, leaving: squeezedByHand[displayID] ?? [])
    {
      workspaces[displayID]?.tree = tree
      scheduleSave()
      return roomyLayout(of: displayID, for: reason)
    }
    // Framed on its own the Desktop has the whole display, which says nothing about its share beside the others.
    let tree = workspaces[displayID]?.tree
    if plain.desktopFrame != nil, plain.camera != tree?.desktop || tree?.root == tree?.desktop {
      workspaces[displayID]?.desktopIsOwedRoom = nil
    }
    // No tiles, nobody short, nothing to give back: most of the time. And no gap moves under a window or an edge that is
    // being dragged.
    guard settings.makeRoom, !gapsInHand, drag == nil, edgeResize == nil, var workspace = workspaces[displayID],
      !plain.tiles.isEmpty || (workspace.tree.hasLoans && reason != .enforce), let display = display(displayID)
    else { return plain }
    let present = presentWindowIDs().union(late)
    let minimums = minimumSizes
    var terms = roomTerms(on: displayID)
    // What the Desktop is owed it gets when something moves anyway, not because an app has moved its own window. (An
    // app that makes the window being typed in larger than its slot is still served, at a neighbour's cost if need
    // be; one in the background never.)
    if reason == .enforce {
      terms.desktopIsOwed = false
      terms.givesBack = false
    }
    // A move of the view includes a launch, when nobody's minimum is known, and a change of displays.
    terms.emptyDesktopAsksNobody = reason == .camera
    // `plain` has looked for the view among the windows that are there.
    let (served, roomy, gaveBack) = MakeRoom.serve(
      &workspace.tree, camera: late.isEmpty ? workspace.camera : plain.camera, in: display.visibleFrame,
      options: options(for: displayID).layoutOptions, isPresent: { present.contains($0) },
      minimumSize: { minimums[$0] }, terms: terms)
    guard !served.isEmpty || gaveBack else { return plain }
    let layout = roomy.leavingOpen(late, in: workspace.tree)
    // Moving the gaps has cost somebody their place beside a hole (Controller+KeptRoom.swift). Once more, without.
    if !late.isEmpty, !layout.tiles.allSatisfy({ $0.kind == .desktop }) {
      giveUpRoom(on: displayID)
      return roomyLayout(of: displayID, for: reason, startingFrom: before)
    }
    if plain.desktopFrame != nil, layout.desktopFrame == nil { workspace.desktopIsOwedRoom = true }
    if layout.desktopFrame != nil { workspace.desktopIsOwedRoom = nil }
    noteThatRoomIsMade(on: displayID)
    workspaces[displayID] = workspace
    scheduleSave()
    if !served.isEmpty {
      Log.info("made room for \(served.map { $0.window?.description ?? "the Desktop" }.joined(separator: ", "))")
    }
    return layout
  }

  /// Whether the layout of a display as it stands now would show `window`: in its slot, or with the room `roomyLayout` would make
  /// for it. On paper: no gap moves.
  func theNextLayoutShows(_ window: WindowID, on displayID: DisplayID) -> Bool {
    // It begins as the layout does: where windows have only gone or come back, from the gaps that stood, and there no room is made
    // (Controller+ThereAndBack.swift). Only a look.
    let (asItIs, noted, standing) = (workspaces[displayID], treesBeforeRoomWasMade[displayID], standingGaps[displayID])
    defer { (workspaces[displayID], treesBeforeRoomWasMade[displayID], standingGaps[displayID]) = (asItIs, noted, standing) }
    if let stood = startFromTheGapsThatStood(on: displayID, for: .structure) { return stood.windowFrames[window] != nil }
    guard let plain = layout(of: displayID), plain.windowFrames[window] == nil else { return true }
    guard settings.makeRoom, !gapsInHand, drag == nil, edgeResize == nil, var tree = workspaces[displayID]?.tree,
      let display = display(displayID)
    else { return false }
    let present = presentWindowIDs()
    let minimums = minimumSizes
    let (_, roomy, _) = MakeRoom.serve(
      &tree, camera: plain.camera, in: display.visibleFrame, options: options(for: displayID).layoutOptions,
      isPresent: { present.contains($0) }, minimumSize: { minimums[$0] }, terms: roomTerms(on: displayID))
    return roomy.windowFrames[window] != nil
  }

  /// - Parameter docking: a floating window about to be docked, for a preview: it no longer counts as on the Desktop.
  func roomTerms(on displayID: DisplayID, docking: WindowID? = nil) -> MakeRoom.Terms {
    // Windows that keep their frames need no Desktop of any size: it counts as not in use, and docked windows come first.
    let onDesktop = settings.floatingWindowsMakeWay ? windowsOnDesktop(of: displayID, without: docking) : []
    let frames = onDesktop.compactMap { workspaces[displayID]?.floating[$0] }
    // Who has it now, not who had it last: it can cost a neighbour its place.
    let keyboard = keyboardFocus()
    var terms = MakeRoom.Terms(
      desktopIsInUse: !onDesktop.isEmpty,
      keyboard: keyboard,
      // (Squeezed against a neighbour that has left since, with everything else left over, it is squeezed by nobody. Squeezed against the
      // Desktop it is as narrow as its person wants it.)
      leaving: (squeezedByHand[displayID] ?? []).filter { node in
        guard squeezedAgainstWindows[displayID]?.contains(node) == true, let tree = workspaces[displayID]?.tree,
          let row = tree.parent(of: node)
        else { return true }
        return Set(tree.children(of: row)) != [node, tree.desktop]
      },
      // What is left over is owed nothing (Q28).
      desktopIsOwed: settings.desktopColumn && workspaces[displayID]?.desktopIsOwedRoom == true,
      desktopWish: CGSize(width: frames.map(\.width).max() ?? 0, height: frames.map(\.height).max() ?? 0))
    // Only at a layout that follows a person's act. Not at a start, nor while the window is let be since, until a person asks
    // for a layout (Controller+LetBe.swift); not for a report of the displays; not for the window that is docked as it
    // opens. Those send nothing away (board 0.9).
    terms.neighboursPay = !layingOutUnasked && keyboard.map { isLetBe($0) || $0 == dockingAsItOpens } != true
    return terms
  }

  /// Runs a layout that nobody asked for: Arbor starts, or macOS has reported a change of displays.
  func unasked(_ body: () -> Void) {
    layingOutUnasked = true
    defer { layingOutUnasked = false }
    body()
  }

  /// Runs what docks `window` as it opens: a rule, or the place that was kept for it. Nobody asked for that either, and it has the
  /// keyboard by now, as a rule. It is this window that costs no neighbour its place: whoever was being typed in before keeps theirs.
  func asItOpens(_ window: WindowID, _ body: () -> Void) {
    dockingAsItOpens = window
    defer { dockingAsItOpens = nil }
    body()
  }

  /// The windows that float on the Desktop: not kept in view wherever the view goes (pinned, summoned), not waiting out of
  /// view (stashed), and not the guest of a space, with which it comes and goes. Asked only with `floatingWindowsMakeWay`.
  private func windowsOnDesktop(of displayID: DisplayID, without docking: WindowID?) -> [WindowID] {
    guard let workspace = workspaces[displayID] else { return [] }
    return workspace.floating.keys.filter {
      $0 != docking && windows[$0]?.isPresent == true && isManaged($0) && workspace.role(of: $0) == nil
        && workspace.guests?[$0] == nil
    }
  }

  /// Runs a layout that follows the person's own hand: a drag of a gap or of a window's edge, `resize`. Someone who
  /// squeezes a window below its minimum on purpose gets the tile they asked for, and Arbor does not push back.
  func byHand(_ body: () -> Void) {
    gapsInHand = true
    defer { gapsInHand = false }
    body()
  }

  /// For whatever replaces a display's tree with another (`arrange`): node ids start again, and would be mistaken.
  func forgetSqueezes(on displayID: DisplayID) {
    squeezedByHand[displayID] = nil
    squeezedAgainstWindows[displayID] = nil
    workspaces[displayID]?.desktopIsOwedRoom = nil
  }

  /// Keeps track of the slots the person squeezed into tiles, so that no later layout widens them again. Their hand
  /// undoes it, and so does giving the window another place, which gives it another slot.
  func rememberSqueezes(in layout: Layout, on displayID: DisplayID) {
    // However wide the Desktop is after the person has moved one of its gaps, that is how wide they want it. And after they have moved
    // another gap of its row, or one that runs the same way inside what is in that row: they have seen the row and set it, and the
    // points they gave to a window are not for the Desktop to take.
    if gapsInHand, let tree = workspaces[displayID]?.tree, let shown = layouts[displayID] {
      var isSet = layout.nodeFrames[tree.desktop] != shown.nodeFrames[tree.desktop]
      if !isSet, let row = tree.parent(of: tree.desktop), case .split(let axis, _) = tree[row]?.kind {
        isSet = tree.preorder(from: row).contains {
          layout.nodeFrames[$0]?.length(along: axis) != shown.nodeFrames[$0]?.length(along: axis)
        }
      }
      if isSet { workspaces[displayID]?.desktopIsOwedRoom = nil }
    }
    guard settings.makeRoom, gapsInHand || squeezedByHand[displayID] != nil, let view = treeView(displayID) else {
      return
    }
    var squeezed = (squeezedByHand[displayID] ?? []).filter { view.tree.contains($0) }
    if gapsInHand {
      let minimums = minimumSizes
      let short = MakeRoom.shortSlots(
        in: layout, view: view, options: options(for: displayID).layoutOptions, minimumSize: { minimums[$0] })
      // Only what the hand has made short, or shorter. A window that was a tile for want of room before, somewhere else
      // in the view, is still waiting for room.
      let shown = layouts[displayID]
      let byThisHand = short.filter { slot in
        guard let window = slot.window else { return false }
        guard let shown, shown.windowFrames[window] == nil, let was = shown.nodeFrames[slot.node],
          let now = layout.nodeFrames[slot.node]
        else { return true }
        return now.width < was.width - 0.5 || now.height < was.height - 0.5
      }.map(\.node)
      squeezed.formUnion(byThisHand)
      if view.tree.desktopHasRoom {
        squeezedAgainstWindows[displayID]?.subtract(byThisHand)
      } else {
        squeezedAgainstWindows[displayID, default: []].formUnion(byThisHand)
      }
      for window in layout.windowFrames.keys {
        if let leaf = view.tree.leaf(containing: window) { squeezed.remove(leaf) }
      }
      // A row or column that the hand has made one tile, or a smaller one, likewise: nothing in it is fetched out of
      // it.
      let groups = layout.tiles.filter { $0.kind == .group }
      squeezed.subtract(squeezed.filter { node in view.tree.isSplit(node) && !groups.contains { $0.node == node } })
      squeezed.formUnion(
        groups.filter { tile in
          guard let shown, shown.tiles.contains(where: { $0.node == tile.node }), let was = shown.nodeFrames[tile.node]
          else { return true }
          return tile.frame.width < was.width - 0.5 || tile.frame.height < was.height - 0.5
        }.map(\.node))
    }
    squeezedByHand[displayID] = squeezed.isEmpty ? nil : squeezed
    squeezedAgainstWindows[displayID]?.formIntersection(squeezed)
  }
}
