// A window that comes and goes leaves the row as it found it.
//
// Docking beside a node in a row takes half of that node's room, so that nothing else moves. What leaves
// a row leaves its room to the whole row (T06). Put together, each window that came and went beside
// another left it narrower, until it was a tile. So the tree remembers its last few docks of that kind,
// each with the row as it was just afterwards. If the row is still exactly that when the newcomer leaves,
// the room goes back where it came from. Once anything else in the row has changed (an arrival, a
// departure, a resize, a swap) it is an arrangement somebody made, and T06 holds. It holds too when it
// is the other of the two that leaves.
//
// The same goes for a window that took what was left over, all the Desktop's room (`dock`): if it leaves the row as it found it,
// the Desktop has its room back and nobody else moves. After any other change the others share it, and no column opens.
//
// Comparing with the row as it is, rather than forgetting at every change, means that no change to a tree,
// present or future, has to know about this, and that nonsense in a file matches nothing.

extension LayoutTree {
  /// A dock that took half of `host`'s room for `guest` (all of it, if the host is the Desktop), and their row just afterwards.
  struct Visit: Codable, Sendable, Equatable {
    var guest: NodeID
    var host: NodeID
    var row: [NodeID]
    var weights: [Double]
  }

  /// Visits unwind last in, first out, so this is how deep they can be nested and still leave no trace.
  static let mostVisits = 8

  private func rowAndWeights(of parent: NodeID) -> (row: [NodeID], weights: [Double]) {
    let row = children(of: parent)
    return (row, row.map { nodes[$0]!.weight })
  }

  /// (Give or take a point. Room that was made for the guest has just been given back, and making room sets the
  /// weights of the whole row by its lengths, which are whole points: a neighbour that is 172.5 points wide comes
  /// out of it weighing 173. A thousandth of the row is a point or two on any display; a hand moves a gap further
  /// than that.)
  private func isAsItWas(at visit: Visit, _ now: (row: [NodeID], weights: [Double])) -> Bool {
    let (then, sum) = (visit.weights.reduce(0, +), now.weights.reduce(0, +))
    guard visit.row == now.row, then > 0, sum > 0 else { return false }
    return zip(visit.weights, now.weights).allSatisfy { abs($0 / then - $1 / sum) <= 1e-3 }
  }

  mutating func noteVisit(of guest: NodeID, to host: NodeID) {
    guard let parent = nodes[guest]?.parent else { return }
    let (row, weights) = rowAndWeights(of: parent)
    visits.removeAll { nodes[$0.guest] == nil || nodes[$0.host] == nil }
    visits.append(Visit(guest: guest, host: host, row: row, weights: weights))
    visits.removeFirst(max(0, visits.count - Self.mostVisits))
  }

  /// `guest` took all that was left over, and that turns out too little to show a window in. It is as if nothing had been left: everybody in
  /// the row gives, and it has a share like the others'. False if it is no such guest, or the row has changed since: as little as a hand
  /// has left it since is what that hand wanted.
  mutating func shareWithWhoTookWhatWasLeft(_ guest: NodeID) -> Bool {
    guard let parent = nodes[guest]?.parent, let visit = visits.last(where: { $0.guest == guest }), visit.host == desktop,
      isAsItWas(at: visit, rowAndWeights(of: parent))
    else { return false }
    let others = children(of: parent).filter { $0 != guest && hasRoom($0) }
    guard !others.isEmpty else { return false }
    // Weight moves, none is made: the others keep their proportions.
    let theirs = others.reduce(0) { $0 + nodes[$1]!.weight }
    let whole = theirs + nodes[guest]!.weight
    for other in others { nodes[other]!.weight *= whole * Double(others.count) / Double(others.count + 1) / theirs }
    nodes[guest]!.weight = whole / Double(others.count + 1)
    visits.removeAll { $0.guest == guest }
    // With all that was left it had taken over what the Desktop was owed. A share like the others' is reckoned from what they have, lent
    // room and all: it is not paid that on top.
    loans.removeAll { $0.giver == guest }
    steadyWeights(of: parent)
    return true
  }

  /// `id` is about to leave `parent`. Says whether its room has been given back, so that nothing else
  /// gives it away as well.
  @discardableResult mutating func endVisit(of id: NodeID, leaving parent: NodeID) -> Bool {
    defer { visits.removeAll { $0.guest == id || $0.host == id } }
    let (row, weights) = rowAndWeights(of: parent)
    guard let visit = visits.last(where: { $0.guest == id }), isAsItWas(at: visit, (row, weights)),
      visit.host != id, let host = row.firstIndex(of: visit.host), let guest = row.firstIndex(of: id)
    else { return false }
    // As it was written down, so that nothing adds up over many visits.
    for (node, weight) in zip(row, visit.weights) { nodes[node]!.weight = weight }
    nodes[visit.host]!.weight = visit.weights[host] + visit.weights[guest]
    return true
  }
}
