// Room that was made for a window goes back where it came from when the window goes (F61).
//
// Before a window becomes a tile because its slot is smaller than the window will go, `MakeRoom` moves weight to
// its slot from the Desktop and from neighbours that can spare it. What leaves a row leaves its room to the whole
// row (T06), so without a record the Desktop that gave 350 points for Notes would get a sliver of them back when
// Notes closes. So the tree keeps a ledger: who gave how much to whom, and for whose sake.
//
// In amounts, not in pictures of the row (compare LayoutTree+Room.swift): several windows borrow in one row, and they
// leave in any order. A gap that a person has moved since is theirs: what was lent across it is forgotten.

extension LayoutTree {
  /// `weight` went from `giver` to `receiver`, two children of one row or column, so that the window in `borrower` has
  /// room. The receiver is the borrower itself, or the group it is in where that had to grow.
  struct Loan: Codable, Sendable, Equatable {
    var borrower: NodeID
    var giver: NodeID
    var receiver: NodeID
    var weight: Double
  }

  /// More than any arrangement a person can look at needs. The oldest are forgotten first.
  static let mostLoans = 64

  /// `setShares`, for the sake of the window in `borrower`: what each node loses by it is written down as lent to the one
  /// that gains. Without a borrower (the Desktop getting room back) nothing new is lent: what the losers owed the gainer is
  /// paid off by it, and what others owed the gainer they owe the losers from now on.
  public mutating func setShares(_ lengths: [NodeID: Double], for borrower: NodeID?) {
    let before = lengths.keys.reduce(into: [NodeID: Double]()) { $0[$1] = nodes[$1]?.weight }
    setShares(lengths)
    let change = before.compactMapValues { $0 }.reduce(into: [NodeID: Double]()) { $0[$1.key] = (nodes[$1.key]?.weight ?? $1.value) - $1.value }
    guard let receiver = change.filter({ $0.value > 0 }).max(by: { ($0.value, $1.key) < ($1.value, $0.key) })?.key else { return }
    for giver in change.keys.sorted() where change[giver]! < 0 {
      var given = -change[giver]!
      // First what the giver had from the receiver.
      for index in loans.indices where loans[index].giver == receiver && loans[index].receiver == giver && given > 0 {
        let paid = min(given, loans[index].weight)
        loans[index].weight -= paid
        given -= paid
      }
      if let borrower {
        if given > 0 { loans.append(Loan(borrower: borrower, giver: giver, receiver: receiver, weight: given)) }
        continue
      }
      // The Desktop is given back part of what it lent, by somebody else than it lent it to: from now on that one is owed it.
      for index in loans.indices.reversed() where loans[index].giver == receiver && given > 0 {
        guard loans[index].receiver != giver, nodes[loans[index].receiver]?.parent == nodes[giver]?.parent else { continue }
        let passed = min(given, loans[index].weight)
        loans[index].weight -= passed
        given -= passed
        loans.append(Loan(borrower: loans[index].borrower, giver: giver, receiver: loans[index].receiver, weight: passed))
      }
    }
    tidyLoans()
  }

  /// One entry for each borrower, giver and receiver, in the order of their numbers, so that trees which owe the same compare
  /// equal however they came to. The last are the newest borrowers': node ids only grow.
  private mutating func tidyLoans() {
    var sums: [[NodeID]: Double] = [:]
    for loan in loans where loan.weight > 1e-12 { sums[[loan.borrower, loan.giver, loan.receiver], default: 0] += loan.weight }
    loans = sums.keys.sorted { $0.lexicographicallyPrecedes($1) }
      .map { Loan(borrower: $0[0], giver: $0[1], receiver: $0[2], weight: sums[$0]!) }
    loans.removeFirst(max(0, loans.count - Self.mostLoans))
  }

  /// `id` is about to leave the tree: what was taken for it goes back to whom it was taken from.
  mutating func repayLoans(of id: NodeID) {
    for loan in loans where loan.borrower == id {
      guard let giver = nodes[loan.giver], let receiver = nodes[loan.receiver], giver.parent == receiver.parent,
        giver.parent != nil, loan.weight.isFinite, loan.weight > 0
      else { continue }
      // Whatever has happened since, the receiver is left with something.
      let back = min(loan.weight, receiver.weight * 0.9)
      nodes[loan.giver]!.weight += back
      nodes[loan.receiver]!.weight -= back
    }
    loans.removeAll { $0.borrower == id || $0.giver == id || $0.receiver == id }
  }

  public var hasLoans: Bool { !loans.isEmpty }

  /// Gives `weight` of the loan at `index` back now, because the receiver can spare it.
  mutating func repay(_ weight: Double, ofLoanAt index: Int) {
    let loan = loans[index]
    guard weight > 0, nodes[loan.giver] != nil, let receiver = nodes[loan.receiver] else { return }
    let back = min(weight, loan.weight, receiver.weight * 0.9)
    nodes[loan.giver]!.weight += back
    nodes[loan.receiver]!.weight -= back
    loans[index].weight -= back
  }

  mutating func dropSettledLoans() { tidyLoans() }

  /// A person has moved the gap between these two neighbours: where it is now is their decision. What was lent across it,
  /// from one side of the gap to the other, is forgotten.
  mutating func forgetLoans(across leading: NodeID, _ trailing: NodeID) {
    guard let parent = nodes[leading]?.parent, parent == nodes[trailing]?.parent else { return }
    let row = children(of: parent)
    guard let first = row.firstIndex(of: leading), let second = row.firstIndex(of: trailing) else { return }
    let gap = min(first, second)
    loans.removeAll { loan in
      guard let giver = row.firstIndex(of: loan.giver), let receiver = row.firstIndex(of: loan.receiver) else { return false }
      return min(giver, receiver) <= gap && max(giver, receiver) > gap
    }
  }
}
