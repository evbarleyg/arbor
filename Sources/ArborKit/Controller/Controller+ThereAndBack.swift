import ArborCore
import CoreGraphics

/// There and back is nothing: a docked window that is hidden or minimized and comes back, nothing else having changed,
/// gets its place back and its neighbours their exact sizes.
///
/// A window that takes no space keeps its slot and its weight, so a plain layout has always come back to what it was. Room
/// before tiles (Controller+MakeRoom.swift) did not: it moves the gaps, from where it finds them. While Finder was hidden
/// Safari could spare what TextEdit had lent it and paid it back; when Finder showed again Safari borrowed afresh, from
/// the Desktop first, and TextEdit stayed 95 points wider than it had been. Where the gaps were depended on the way there.
///
/// So Arbor remembers the gaps as they stood with the docked windows that took space when somebody last changed the
/// arrangement. Whoever has gone or come since, room is made starting from those gaps: what it looks like depends on who is
/// away, not on the order they went in, and once the same windows are there again the gaps are exactly those.
///
/// Whatever else changes the arrangement meanwhile (a gap moved by hand, a window docked, floated or closed, `arrange`,
/// `undo`) makes it, as it then stands, the person's: the memory starts again from there. That is found out by comparing
/// the tree with what Arbor last left, so that no change to a tree, present or future, has to know about this. Moving the
/// view is no change of the arrangement, nor is a pause. Not saved: after a restart the gaps are as state.json has them.
///
/// What it does not know: a change that Arbor tries, lays out and takes back (a `rotate` that is refused) looks like
/// anybody's, and the memory starts again. And while somebody is away a move of the view goes on from the gaps as they are.
extension Controller {
  struct StandingGaps {
    /// The tree after the layout that followed the last change anybody made, whether the Desktop was owed room in it, that
    /// layout, and what was known then of how small the docked windows go.
    var tree: LayoutTree
    var desktopIsOwedRoom: Bool?
    var layout: Layout
    var sizes: [WindowID: CGSize]
    /// The docked windows that took space then, and those that have come back since.
    var present: Set<WindowID>
    /// What Arbor's own layouts have made of the tree since: the same nodes, other weights.
    var left: LayoutTree
    /// For which windows room was last made from the gaps that stood. Nil: a layout that was not for whoever was there
    /// (`isForWhoeverIsThere`) has been at the gaps since.
    var leftFor: Set<WindowID>?
  }

  private func dockedWindowsThatTakeSpace(on displayID: DisplayID) -> Set<WindowID> {
    // Also the places that are kept open for windows that are not there yet (Controller+KeptRoom.swift): one that is given
    // up has gone like anybody else.
    Set(workspaces[displayID]?.tree.allWindows ?? []).intersection(presentWindowIDs())
      .union(layoutAndWhoIsLate(of: displayID)?.late ?? [])
  }

  private func sizesKnownOfDockedWindows(on displayID: DisplayID) -> [WindowID: CGSize] {
    let docked = Set(workspaces[displayID]?.tree.allWindows ?? [])
    return minimumSizes.filter { docked.contains($0.key) }
  }

  /// Whether a layout for `reason` is one for the windows that are there now. Not under a window, an edge or a gap that is in
  /// somebody's hand, where no gap moves (`roomyLayout`). Nor when a window is only put back where it was, which moves nothing
  /// else, and can come between the reports that windows have gone or come back and the layout for them
  /// (Controller+Spaces.swift). The next layout that is one starts from the gaps that stood.
  private func isForWhoeverIsThere(_ reason: RelayoutReason) -> Bool {
    reason != .enforce && !gapsInHand && drag == nil && edgeResize == nil
  }

  /// Before a layout. If all that has happened to the arrangement since the last one is that docked windows have gone or come
  /// back, the layout starts from the gaps that stood.
  ///
  /// Returns the layout that stood if that is what those gaps give now: the same windows are there, and the view, the
  /// display and what is known of the windows' sizes are what they were. Then it stands, and no room is made. What could be
  /// made now could have been made before anybody went, and was not: a gap that a hand has moved is not looked at
  /// again until something changes, and that a window went and came back changes nothing.
  func startFromTheGapsThatStood(on displayID: DisplayID, for reason: RelayoutReason) -> Layout? {
    guard var standing = standingGaps[displayID] else { return nil }
    guard settings.makeRoom, let found = workspaces[displayID], found.tree.hasSameArrangement(as: standing.left) else {
      standingGaps[displayID] = nil
      return nil
    }
    // What the Desktop is owed can be settled after a layout (an undo, a dock taken back). If that was everybody's, it stands so.
    if standing.leftFor == standing.present {
      standing.desktopIsOwedRoom = found.desktopIsOwedRoom
      standingGaps[displayID] = standing
    }
    let present = dockedWindowsThatTakeSpace(on: displayID)
    guard present != standing.leftFor, isForWhoeverIsThere(reason), display(displayID) != nil else { return nil }
    if !found.tree.hasSameArrangement(as: standing.tree) {
      noteThatRoomIsMade(on: displayID)
      workspaces[displayID]?.tree.takeGaps(from: standing.tree)
      scheduleSave()
    }
    workspaces[displayID]?.desktopIsOwedRoom = standing.desktopIsOwedRoom
    var stood = layout(of: displayID)
    if stood != standing.layout || sizesKnownOfDockedWindows(on: displayID) != standing.sizes { stood = nil }
    // The window somebody is typing in does not leave the view for this: it is the last to become a tile (F61). It may have
    // room only because another went. Then the gaps go on from where they are, and that is the arrangement from now on.
    if let keyboard = focusHistory.first, present.contains(keyboard), layouts[displayID]?.windowFrames[keyboard] != nil,
      (stood ?? layoutToCome(on: displayID, for: reason))?.windowFrames[keyboard] == nil
    {
      workspaces[displayID] = found
      standingGaps[displayID] = nil
      return nil
    }
    return stood
  }

  /// After a layout, which may have moved the gaps to make room.
  func noteWhereTheGapsStand(in layout: Layout, on displayID: DisplayID, for reason: RelayoutReason) {
    guard settings.makeRoom, let workspace = workspaces[displayID] else { return }
    let present = dockedWindowsThatTakeSpace(on: displayID)
    var standing =
      standingGaps[displayID]
      ?? StandingGaps(
        tree: workspace.tree, desktopIsOwedRoom: workspace.desktopIsOwedRoom, layout: layout,
        sizes: sizesKnownOfDockedWindows(on: displayID), present: present, left: workspace.tree, leftFor: present)
    standing.left = workspace.tree
    if isForWhoeverIsThere(reason) { standing.leftFor = present } else if standing.leftFor != present { standing.leftFor = nil }
    // With everybody there, and the gaps theirs, room made now (for a move of the view, say) stands. So it does once windows
    // are back that were away when somebody last changed the arrangement: from now on they are of the party.
    if present.isSuperset(of: standing.present), present == standing.leftFor {
      (standing.tree, standing.desktopIsOwedRoom, standing.present) = (workspace.tree, workspace.desktopIsOwedRoom, present)
      (standing.layout, standing.sizes) = (layout, sizesKnownOfDockedWindows(on: displayID))
    }
    standingGaps[displayID] = standing
  }
}
