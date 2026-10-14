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
// Comparing with the row as it is, rather than forgetting at every change, means that no change to a tree,
// present or future, has to know about this, and that nonsense in a file matches nothing.

extension LayoutTree {
  /// A dock that took half of `host`'s room for `guest`, and their row just afterwards.
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

  mutating func noteVisit(of guest: NodeID, to host: NodeID) {
    guard let parent = nodes[guest]?.parent else { return }
    let (row, weights) = rowAndWeights(of: parent)
    visits.removeAll { nodes[$0.guest] == nil || nodes[$0.host] == nil }
    visits.append(Visit(guest: guest, host: host, row: row, weights: weights))
    visits.removeFirst(max(0, visits.count - Self.mostVisits))
  }

  /// `id` is about to leave `parent`. Says whether its room has been given back, so that nothing else
  /// gives it away as well.
  @discardableResult mutating func endVisit(of id: NodeID, leaving parent: NodeID) -> Bool {
    defer { visits.removeAll { $0.guest == id || $0.host == id } }
    let (row, weights) = rowAndWeights(of: parent)
    // (To the last digits but a few: room that was made for the guest has just been given back, by arithmetic.)
    func same(_ a: [Double], _ b: [Double]) -> Bool { zip(a, b).allSatisfy { abs($0 - $1) <= 1e-9 * max(abs($0), abs($1)) } }
    guard let visit = visits.last(where: { $0.guest == id }), visit.row == row, same(visit.weights, weights),
      visit.host != id, row.contains(visit.host)
    else { return false }
    nodes[visit.host]!.weight += nodes[id]!.weight
    return true
  }
}
