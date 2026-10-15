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
    // What the Desktop is owed it gets when something moves anyway, not because an app has moved its own window. (An app that makes
    // the window being typed in larger than its slot is still served, at a neighbour's cost if need be; one in the background never.)
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

  /// The layout of a display as it stands now, if it would leave `window` out: it has no slot there, nor with the room `roomyLayout`
  /// would make for it. Nil if it shows. On paper: no gap moves.
  func theNextLayout(leavingOut window: WindowID, on displayID: DisplayID) -> Layout? {
    // It begins as the layout does: where windows have only gone or come back, from the gaps that stood, and there no room is made
    // (Controller+ThereAndBack.swift). Only a look.
    let (asItIs, noted, standing) = (workspaces[displayID], treesBeforeRoomWasMade[displayID], standingGaps[displayID])
    defer { (workspaces[displayID], treesBeforeRoomWasMade[displayID], standingGaps[displayID]) = (asItIs, noted, standing) }
    if let stood = startFromTheGapsThatStood(on: displayID, for: .structure) { return stood.windowFrames[window] == nil ? stood : nil }
    guard let plain = layout(of: displayID), plain.windowFrames[window] == nil else { return nil }
    guard settings.makeRoom, !gapsInHand, drag == nil, edgeResize == nil, var tree = workspaces[displayID]?.tree,
      let display = display(displayID)
    else { return plain }
    let present = presentWindowIDs()
    let minimums = minimumSizes
    let (_, roomy, _) = MakeRoom.serve(
      &tree, camera: plain.camera, in: display.visibleFrame, options: options(for: displayID).layoutOptions,
      isPresent: { present.contains($0) }, minimumSize: { minimums[$0] }, terms: roomTerms(on: displayID))
    return roomy.windowFrames[window] == nil ? roomy : nil
  }

  /// - Parameter docking: a floating window about to be docked, for a preview: it no longer counts as on the Desktop.
  func roomTerms(on displayID: DisplayID, docking: WindowID? = nil) -> MakeRoom.Terms {
    // Windows that keep their frames need no Desktop of any size: it counts as not in use, and docked windows come first.
    let onDesktop = settings.floatingWindowsMakeWay ? windowsOnDesktop(of: displayID, without: docking) : []
    let frames = onDesktop.compactMap { workspaces[displayID]?.floating[$0] }
    return MakeRoom.Terms(
      desktopIsInUse: !onDesktop.isEmpty,
      // Who has it now, not who had it last: it can cost a neighbour its place.
      keyboard: keyboardFocus(),
      leaving: squeezedByHand[displayID] ?? [], desktopIsOwed: workspaces[displayID]?.desktopIsOwedRoom == true,
      desktopWish: CGSize(width: frames.map(\.width).max() ?? 0, height: frames.map(\.height).max() ?? 0))
  }

  /// The windows that float on the Desktop: not kept in view wherever the view goes (pinned, summoned), not waiting out of
  /// view (stashed), and not the guest of a space, with which it comes and goes.
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
    workspaces[displayID]?.desktopIsOwedRoom = nil
  }

  /// Keeps track of the slots the person squeezed into tiles, so that no later layout widens them again. Their hand
  /// undoes it, and so does giving the window another place, which gives it another slot.
  func rememberSqueezes(in layout: Layout, on displayID: DisplayID) {
    // However wide the Desktop is after the person has moved one of its gaps, that is how wide they want it.
    if gapsInHand, let desktop = workspaces[displayID]?.tree.desktop,
      layout.nodeFrames[desktop] != layouts[displayID]?.nodeFrames[desktop]
    {
      workspaces[displayID]?.desktopIsOwedRoom = nil
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
      squeezed.formUnion(
        short.filter { slot in
          guard let window = slot.window else { return false }
          guard let shown, shown.windowFrames[window] == nil, let was = shown.nodeFrames[slot.node],
            let now = layout.nodeFrames[slot.node]
          else { return true }
          return now.width < was.width - 0.5 || now.height < was.height - 0.5
        }.map(\.node))
      for window in layout.windowFrames.keys {
        if let leaf = view.tree.leaf(containing: window) { squeezed.remove(leaf) }
      }
    }
    squeezedByHand[displayID] = squeezed.isEmpty ? nil : squeezed
  }
}
