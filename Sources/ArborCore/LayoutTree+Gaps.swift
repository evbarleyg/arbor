// Where the gaps of a tree are, apart from what is in it (Controller+ThereAndBack.swift).

extension LayoutTree {
  /// Puts the gaps where they are in `other`, a version of this tree with the same nodes: everybody's weight, and the
  /// ledger of who gave how much of it to whom (LayoutTree+Loans.swift). All else stays: which tab shows, what is kept.
  /// With other nodes in `other` nothing happens: a weight means something only among the siblings it was given among.
  public mutating func takeGaps(from other: LayoutTree) {
    guard nodes.count == other.nodes.count,
      nodes.allSatisfy({ id, node in other.nodes[id].map { $0.parent == node.parent } ?? false })
    else { return }
    for (id, node) in other.nodes { nodes[id]!.weight = node.weight }
    loans = other.loans
  }
}
