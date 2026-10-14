/// Comparing two versions of a display's tree, for undo.
extension LayoutTree {
  /// Whether both trees arrange the same windows the same way: the same nodes, nesting, order and
  /// weights. Which tab of a stack is showing does not count; switching tabs rearranges nothing.
  public func hasSameArrangement(as other: LayoutTree) -> Bool {
    guard root == other.root, nodes.count == other.nodes.count else { return false }
    for (id, node) in nodes {
      guard let theirs = other.nodes[id], node.parent == theirs.parent, node.weight == theirs.weight else {
        return false
      }
      if case .stack(let mine, _) = node.kind, case .stack(let others, _) = theirs.kind {
        if mine != others { return false }
      } else if node.kind != theirs.kind {
        return false
      }
    }
    return true
  }

  /// Where a docked window is: its leaf, what that lies in, and where among its siblings. Nil if it is not docked.
  /// A window whose place differs between two versions of a tree has been moved, or something beside it has.
  public struct Place: Equatable, Sendable {
    public var leaf: NodeID
    public var parent: NodeID?
    public var index: Int
  }

  public func place(of window: WindowID) -> Place? {
    guard let leaf = leaf(containing: window) else { return nil }
    guard let parent = parent(of: leaf), case .split(_, let children) = nodes[parent]?.kind else {
      return Place(leaf: leaf, parent: nil, index: 0)
    }
    return Place(leaf: leaf, parent: parent, index: children.firstIndex(of: leaf) ?? 0)
  }

  /// Whether `id` is the same place in `other` as it is here. An id alone does not say: `arrange`
  /// and `float-all` start a new tree that numbers its nodes from 1 again. So the two nodes must
  /// also be of the same kind and have something in common: a window, or the Desktop.
  public func isSameNode(_ id: NodeID, in other: LayoutTree) -> Bool {
    guard let mine = nodes[id], let theirs = other.nodes[id] else { return false }
    switch (mine.kind, theirs.kind) {
    case (.desktop, .desktop):
      return true
    case (.stack(let a, _), .stack(let b, _)):
      return !Set(a).isDisjoint(with: b)
    case (.split(let a, _), .split(let b, _)):
      guard a == b else { return false }
      if subtree(id, contains: desktop), other.subtree(id, contains: other.desktop) { return true }
      return !Set(windows(under: id)).isDisjoint(with: other.windows(under: id))
    default:
      return false
    }
  }
}
