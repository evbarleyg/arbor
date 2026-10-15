// A group keeps its identity (docs/features/F62-groups-keep-their-identity.md).
//
// The tree tidies itself: a split left with one child gives way to that child, and a split that
// comes to lie inside another on the same axis dissolves into it. Both are right for the layout,
// which looks the same either way, and wrong for anything that points at the split. What a person
// frames, saves or names is a group of windows, and after a merge the nearest thing left to point
// at is the parent, which holds more: the view jumps to everything.
//
// So a split that something points at is marked as kept, with the reason, and is left standing.

/// Why a split must go on existing. A set, because a group can be framed, named and a guest at once.
public struct Keeps: OptionSet, Codable, Hashable, Sendable {
  public let rawValue: Int
  public init(rawValue: Int) { self.rawValue = rawValue }

  /// The view is on it, or a saved view is. `Workspace` sees to this one by itself.
  public static let view = Keeps(rawValue: 1 << 0)
  /// It has a name.
  public static let name = Keeps(rawValue: 1 << 1)
  /// It is the arrangement of a display that is not connected, waiting here for it to return.
  public static let guest = Keeps(rawValue: 1 << 2)
  /// A window is being moved, and the view or a saved view is on this group. Moving takes the window out and
  /// puts it in again, and in between a group of two must not give way to the one that stays: put back beside
  /// that one, the window would land outside. Set and taken off again within `Workspace.dock`, never saved.
  static let move = Keeps(rawValue: 1 << 3)
  /// It was turned (`rotate`) and now runs the same way as the group around it. Kept so that turning it again turns the
  /// same windows back. So is a group that a line of text has in brackets that run like the group around them
  /// (LayoutNotation+Tree.swift): somebody wrote them. `rotate`, `Spec.tree` and `Workspace` see to this one.
  public static let turned = Keeps(rawValue: 1 << 4)

  /// The reasons that keep a split even when it is down to one child, so that windows docked beside
  /// that child still land inside it. A view does not: it looks the same on the child, and follows it there.
  public static let firm: Keeps = [.name, .guest, .move]
}

extension Keeps: CustomStringConvertible {
  /// "view", "view and name"; a reason this version does not know is a number.
  public var description: String {
    var words = [(Keeps.view, "view"), (.name, "name"), (.guest, "guest"), (.move, "move"), (.turned, "turned")]
      .filter { contains($0.0) }.map(\.1)
    let unknown = subtracting([.view, .name, .guest, .move, .turned])
    if !unknown.isEmpty { words.append(String(unknown.rawValue)) }
    return words.isEmpty ? "nothing" : words.joined(separator: " and ")
  }
}

extension LayoutTree {
  /// Whether anything keeps `id` from dissolving into a parent on the same axis.
  public func isKept(_ id: NodeID) -> Bool { !(nodes[id]?.keeps ?? []).isEmpty }

  /// Whether `id` also stays when it is down to one child.
  public func isKeptFirmly(_ id: NodeID) -> Bool { !(nodes[id]?.keeps ?? []).isDisjoint(with: .firm) }

  /// The splits kept for `reason`, in tree order.
  public func kept(for reason: Keeps) -> [NodeID] {
    preorder().filter { !(nodes[$0]?.keeps ?? []).isDisjoint(with: reason) }
  }

  /// Keeps the split `id` for `reason` until `stopKeeping`. From then on its id stays good for as
  /// long as a window or the Desktop is left under it: it is never merged into its parent and, for a
  /// firm reason, never replaced by its last child. When the last thing under it goes, so does it.
  /// Returns false for anything but a split: a leaf has nothing to dissolve into.
  @discardableResult
  public mutating func keep(_ id: NodeID, for reason: Keeps) -> Bool {
    guard isSplit(id), !reason.isEmpty else { return false }
    nodes[id]!.keeps = (nodes[id]!.keeps ?? []).union(reason)
    return true
  }

  /// Takes `reason` away from `id`. If nothing else keeps it, it dissolves now wherever the tree
  /// would have dissolved it before, and the remap says where references to it should point.
  @discardableResult
  public mutating func stopKeeping(_ id: NodeID, for reason: Keeps) -> Remap {
    var remap = Remap()
    guard let keeps = nodes[id]?.keeps else { return remap }
    let left = keeps.subtracting(reason)
    nodes[id]!.keeps = left.isEmpty ? nil : left
    tidy(&remap)
    return remap
  }

  /// Makes `ids` exactly the splits kept for `reason`: the others stop being kept for it, and
  /// dissolve if nothing else keeps them.
  @discardableResult
  public mutating func keep(exactly ids: Set<NodeID>, for reason: Keeps) -> Remap {
    var remap = Remap()
    var released = false
    for id in nodes.keys where isSplit(id) {
      let keeps = nodes[id]!.keeps ?? []
      let wanted = ids.contains(id) ? keeps.union(reason) : keeps.subtracting(reason)
      guard wanted != keeps else { continue }
      nodes[id]!.keeps = wanted.isEmpty ? nil : wanted
      if !ids.contains(id) { released = true }
    }
    if released { tidy(&remap) }
    return remap
  }

  /// Takes `reason` off every split that stands without it: one that does not lie in a parent on its
  /// own axis. Nothing dissolves. For a reason that is worked out afresh before every change, like
  /// `.view`, this leaves the tree carrying only the marks that make a difference, so that trees which
  /// look alike compare equal and what is saved does not depend on where the view has been.
  mutating func stopKeepingWhereItChangesNothing(for reason: Keeps) {
    for id in nodes.keys {
      guard let keeps = nodes[id]!.keeps, !keeps.isDisjoint(with: reason),
        case .split(let axis, _) = nodes[id]!.kind
      else { continue }
      if let parent = nodes[id]!.parent, case .split(axis, _) = nodes[parent]!.kind { continue }
      let left = keeps.subtracting(reason)
      nodes[id]!.keeps = left.isEmpty ? nil : left
    }
  }

  /// Puts right a split whose children have just changed: without any it is deleted, with one it gives
  /// way to that child unless it is kept firmly.
  mutating func settle(_ split: NodeID, shareSpace: Bool = true, away: Bool = false, remap: inout Remap) {
    guard let node = nodes[split], case .split(_, let children) = node.kind else { return }
    guard let only = children.first else {
      detach(split, shareSpace: shareSpace, away: away, remap: &remap)
      return
    }
    guard children.count == 1, !isKeptFirmly(split) else {
      // Alone in a group that is kept, the Desktop has all of it.
      if children == [desktop], !hasRoom(desktop) { nodes[desktop]!.weight = 1 }
      steadyWeights(of: split)
      return
    }
    // The child takes the split's place. A Desktop without room takes it without the room, which the others share: no column opens. But
    // where everything is this and one other place it does take it, so that the other stays as it is (`detach`), unless what left was
    // away, and the other has the room already. So it does where there are no others (a group that is kept, down to this).
    let opensNoColumn =
      only == desktop && !hasRoom(only) && node.parent.map { self.children(of: $0).contains { $0 != split && hasRoom($0) } } == true
      && (away || !(node.parent == everything && self.children(of: everything).count == 2))
    if opensNoColumn, !shareSpace, let row = node.parent.map({ self.children(of: $0) }), let index = row.firstIndex(of: split),
      let heir = row[..<index].last(where: hasRoom) ?? row[(index + 1)...].first(where: hasRoom)
    {
      nodes[heir]!.weight += node.weight
    }
    nodes[only]!.parent = node.parent
    nodes[only]!.weight = opensNoColumn ? 0 : node.weight
    replaceChild(of: node.parent, old: split, new: only)
    nodes[split] = nil
    remap.record(split, movedTo: only)
    // What was lent to the split, or by it, is the child's affair now: it has all of its room.
    for index in loans.indices {
      if loans[index].receiver == split { loans[index].receiver = only }
      if loans[index].giver == split { loans[index].giver = only }
    }
    // What pointed at the split points at the child now, which must not dissolve under it either.
    if let keeps = node.keeps { keep(only, for: keeps) }
    if let grandparent = node.parent { flattenIfSameAxis(only, into: grandparent, remap: &remap) }
  }

  /// Dissolves every split that nothing keeps any more and that the tree would not have left
  /// standing. From the leaves up, so that what rises a level is looked at again there.
  private mutating func tidy(_ remap: inout Remap) {
    for id in preorder().reversed() where isSplit(id) {
      settle(id, remap: &remap)
      if let parent = nodes[id]?.parent { flattenIfSameAxis(id, into: parent, remap: &remap) }
    }
  }
}
