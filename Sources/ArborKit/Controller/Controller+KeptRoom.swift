import ArborCore
import CoreGraphics

/// At a start a waiting place keeps its room (collab/QUESTIONS.md, Q16).
///
/// At a login Arbor is up long before the apps whose windows it arranged, and they come one after the other. A
/// waiting place (Controller+PendingSlots.swift) that took no room gave it to its neighbours, who gave it back when
/// the late window came: whoever was early moved twice, or three times. So the place of a window that **does not
/// exist yet** is laid out as if the window were there, and left open: whoever is early goes straight to where it
/// ends up, and a hole waits for who is late.
///
/// - **In the hole** there is nothing: no tile, no icon, nothing to click or to drop a window on. The surface
///   behind docked windows runs through it as behind any place. The menu and `status` say that a place is kept.
/// - **Who keeps room:** places that wait under a stand-in's number since this start. A window that exists and
///   takes no room now (minimized, its app hidden, on another macOS Space) is away, not late, and the gaps depend
///   on who is away as they do all day.
/// - **Late, or closed?** Whoever quits Arbor at noon, closes three of four docked windows and starts it in the
///   evening does not want the fourth in its quarter beside three holes. After a restart of the Mac every window
///   has a new number; so if a saved window is found again under its own, with its own app, this is the login it
///   was saved in, and what is missing was closed: its place waits without room, as it always has. But for a place
///   that kept its room when the arrangement was saved (a quit, an update, a crash, a pause in the middle of a
///   login): it waits on as it did (`PersistedState.roomKept`). If after a restart a window happens to get an old
///   number, that morning is as mornings were: windows move more than once, and nothing is lost.
/// - **Until when:** until its window comes; or until the wait is over, and then the room goes back with the next
///   layout that moves something anyway or is asked for (`dropOverdueSlots`), never by the timer under anybody's
///   eyes (where its going changes nothing that is in view, it goes unseen: `expireSlots`). Until then it takes its
///   window, at seven minutes as at two: what a person sees is the promise, not the clock. Or until the arrangement
///   of its display is another: whoever docks, floats, closes or swaps a window, arranges or lays out has taken it
///   in hand, and the hole closes in the same move. The place still waits then, without room. A gap that is dragged
///   changes no arrangement: it stays in the hand, with the hole on its other side.
/// - **Where:** while everything shows, which is how a start begins. A view on a part of the arrangement is filled
///   by who is there, as it always was; back at everything the holes are where they were.
/// - **Never at a window's cost** (`laidOut`): with holes, Arbor does no worse than without. If a window that is
///   there would be a tile beside them, the display's holes are given up, for good (`giveUpRoom`): a start takes
///   nothing out of view. And while nobody docked is back they get no room: a floating window is not kept off a
///   place nobody can see.
///
/// Nobody has to be told any of this: room is kept while the tree has the shape it had at the start, which every
/// layout asks afresh. So whatever tries out another arrangement (the preview of a drop, automatic docking, undo)
/// sees it without the hole, as it will be; and `undo` of a dock, a float or a swap brings the hole back with
/// everything else. (Not `undo` of `arrange`, Float All or `layout`, which give the waiting places up.)
extension Controller {
  struct KeptRoom {
    /// The leaves whose room is kept while nobody is in them. By leaf and not by window: a stand-in gets another
    /// number when its place waits again.
    var leaves: Set<NodeID>
    /// The display's tree at the start, under the numbers of today.
    var tree: LayoutTree
  }

  /// Called by `start()`, once the saved trees are matched against the windows that are there.
  /// - Parameter saved: the leaves that kept their room when the arrangement was saved.
  func keepRoomForWhoIsLate(saved: [DisplayID: [NodeID]]?) {
    keptRoom.removeAll()
    let late = pendingSlots.filter(Self.isStandIn)
    // Also in what is remembered of a display that is not connected: it may only be slow to wake.
    let trees = workspaces.mapValues(\.tree).merging(dormant.mapValues(\.workspace.tree)) { connected, _ in connected }
    for (display, tree) in trees {
      var leaves = Set(late.compactMap { tree.leaf(containing: $0) })
      if startIsInTheSameLogin { leaves.formIntersection(saved?[display] ?? []) }
      if !leaves.isEmpty { keptRoom[display] = KeptRoom(leaves: leaves, tree: tree) }
    }
  }

  /// The leaves that keep their room now, for the file: those that are open, or held for now by a window that may
  /// yet turn out to be a welcome window. Not those whose windows have come: if one of them is missing at the next
  /// start, its person closed it. Nil if there are none, which is nearly always.
  func leavesThatKeepRoom() -> [DisplayID: [NodeID]]? {
    var kept: [DisplayID: [NodeID]] = [:]
    for (display, room) in keptRoom {
      guard let tree = (workspaces[display] ?? dormant[display]?.workspace)?.tree, tree.hasSameShape(as: room.tree)
      else { continue }
      let open = room.leaves.filter { leaf in
        tree.windows(under: leaf).contains { pendingSlots.contains($0) || provisionalSlots[$0] != nil }
      }
      if !open.isEmpty { kept[display] = open.sorted() }
    }
    return kept.isEmpty ? nil : kept
  }

  /// `old` has become `new`, the same window or place under another number: a window took a waiting place, a place
  /// waits again, another tab of a window came to the front. Nobody has changed the arrangement. **Whatever
  /// renumbers a docked window calls this**, or the tree no longer has the shape of the start and every hole on its
  /// display closes.
  func renumber(_ old: WindowID, as new: WindowID) {
    undoHistory.renumber(old, as: new)
    for display in keptRoom.keys { keptRoom[display]!.tree.replaceWindow(old, with: new) }
  }

  /// The waiting places in `tree`, which is or might become that of `display`, that want room. `present` are the
  /// windows that are there.
  private func placesThatWantRoom(in tree: LayoutTree, on display: DisplayID, present: Set<WindowID>) -> Set<WindowID> {
    guard let kept = keptRoom[display], tree.hasSameShape(as: kept.tree) else { return [] }
    var places = Set<WindowID>()
    for leaf in kept.leaves {
      let tabs = tree.windows(under: leaf)
      // A tab that is there has the room, and shows.
      guard !tabs.contains(where: present.contains) else { continue }
      // Nothing is kept open for an app that Arbor has been told not to arrange.
      places.formUnion(
        tabs.filter {
          pendingSlots.contains($0) && Self.isStandIn($0)
            && hints[$0]?.bundleID.map(filter.excludedBundleIDs.contains) != true
        })
    }
    return places
  }

  /// `tree` laid out on `display`, and the waiting places that were given room in it. **The one place where that is
  /// decided**: whatever lays out an arrangement that is, or may be, the real one goes through here, so that no two
  /// of them disagree.
  func laidOut(
    _ tree: LayoutTree, camera: NodeID, on display: DisplaySnapshot, options: LayoutOptions, present: Set<WindowID>
  ) -> (layout: Layout, late: Set<WindowID>, atAWindowsCost: Bool) {
    let minimums = minimumSizes
    func layout(_ camera: NodeID, counting present: Set<WindowID>) -> Layout {
      LayoutEngine.layout(
        tree, camera: camera, in: display.visibleFrame, options: options, isPresent: { present.contains($0) },
        minimumSize: { minimums[$0] })
    }
    let plain = layout(camera, counting: present)
    let late = placesThatWantRoom(in: tree, on: display.id, present: present)
    // `plain` has looked for the view among the windows that are there: the one asked for may be a hole.
    guard !late.isEmpty, plain.camera == tree.root else { return (plain, [], false) }
    let open = layout(tree.root, counting: present.union(late)).leavingOpen(late, in: tree)
    // Whoever is there shows.
    guard open.tiles.allSatisfy({ $0.kind == .desktop }) else { return (plain, [], true) }
    guard !open.windowFrames.isEmpty else { return (plain, [], false) }
    return (open, late, false)
  }

  /// Holes that would cost a window its place in view are given up for good, not until the next window comes: room
  /// that is kept, not kept and kept again moves windows more often than none at all. Called wherever a layout that
  /// is for real finds it so, which can be in the middle of one: an app has just refused the size of its place.
  func giveUpRoom(on display: DisplayID) {
    guard keptRoom.removeValue(forKey: display) != nil else { return }
    scheduleSave()
  }

  func giveUpAllRoom() {
    for display in keptRoom.keys.sorted() { giveUpRoom(on: display) }
  }

  /// A window has come back under its own number, so the Mac has not been restarted. If the start took it for a
  /// restart (none of the saved windows was listed: they were on another macOS Space), what is missing was closed,
  /// and is not late. `settling` is laid out by the caller.
  func theMacWasNotRestarted(settling: DisplayID?) {
    guard !startIsInTheSameLogin else { return }
    startIsInTheSameLogin = true
    let open = keptRoom.keys.sorted()
    giveUpAllRoom()
    for display in open where display != settling { relayout(display, reason: .structure) }
  }
}
