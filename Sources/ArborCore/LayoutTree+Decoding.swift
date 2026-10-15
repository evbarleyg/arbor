// Reading a tree from `state.json`. The file can be hand-edited, written by another version, or
// damaged, and everything else in Arbor relies on the tree's invariants without checking them (a
// child list that names a missing node is a crash, a cycle is a hang). So they are enforced here,
// once, on the way in.

extension LayoutTree {
  /// A file with more nodes than this is refused, before anything walks them.
  static let mostReadableNodes = 10_000
  /// Node ids outside `0..<idLimit` are not read: new ids count up from the largest.
  static let idLimit = 1 << 48

  private enum Keys: String, CodingKey {
    case nodes, root, desktop, nextRawID, visits, loans
  }

  /// Reads a tree, repairing what can be repaired so that the result always satisfies
  /// `invariantViolations().isEmpty`. A valid tree comes back exactly as it was written.
  ///
  /// The child lists reachable from the root are taken as the truth. Parent links are rebuilt from
  /// them; children that are missing, unreadable or already used (a cycle, a node with two
  /// parents) are dropped, as are windows already seen, empty stacks, extra Desktops and nodes
  /// nothing refers to; splits left with one child collapse and same-axis nesting is flattened,
  /// as in `remove`, which spares the splits that are kept (LayoutTree+Keeps.swift); weights that
  /// are not positive numbers, or are beyond `maximumWeight`, become 1; a missing Desktop is added at
  /// the right. Windows that lose their place this way are simply not docked any more: the
  /// controller finds them floating. Each repair is noted in the decoder's `DecodingNotes`, if it has one.
  ///
  /// Throws if the root is missing, or the file or its ids are absurdly large or deep, so the caller
  /// starts afresh.
  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: Keys.self)
    func refuse(_ why: String) -> DecodingError {
      DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: why))
    }
    let root = try container.decode(NodeID.self, forKey: .root)
    let read = try container.decode(LossyDictionary<NodeID, Node>.self, forKey: .nodes).entries
    guard read.count <= Self.mostReadableNodes else { throw refuse("the tree has \(read.count) nodes") }
    var repair = Repair(read: read.filter { (0..<Self.idLimit).contains($0.key.rawValue) })
    if repair.read.count < read.count { repair.notes.append("dropped nodes with ids out of range") }
    guard repair.read[root] != nil else { throw refuse("the tree's root \(root) is missing") }

    repair.chooseDesktop(preferring: try? container.decodeIfPresent(NodeID.self, forKey: .desktop), from: root)
    // Repairing and laying out a tree recurse once per level, at up to 5 KB of stack a level in a debug
    // build: `maximumDepth` levels take about half a megabyte of the main thread's eight.
    guard repair.depth(from: root) <= Self.maximumDepth else {
      throw refuse("the tree nests deeper than \(Self.maximumDepth) levels")
    }
    let newRoot = repair.build(root, parent: nil)
    // With all that is in them: a child list that lost an entry costs every window under it its place.
    let unreached = repair.unreached
    if !unreached.isEmpty {
      let some = unreached.prefix(5).map(\.description).joined(separator: ", ")
      repair.notes.append("nothing refers to \(some)\(unreached.count > 5 ? " and \(unreached.count - 5) more" : "")")
    }

    // New ids must be larger than any id the file mentions, kept or not: cameras, history and
    // saved views may still name a dropped node, and must not come to mean a new one.
    let stored = (try? container.decodeIfPresent(Int.self, forKey: .nextRawID)) ?? 0
    let smallestFree = (repair.read.keys.max()?.rawValue ?? -1) + 1
    // Half the limit leaves room for 2^47 nodes before one made in a session could be refused on
    // the way back in. No session gets near it, so ids beyond it were not Arbor's doing.
    guard smallestFree <= Self.idLimit / 2 else { throw refuse("the tree's ids leave no room for new ones") }
    // A count beyond what is read back is as wrong as one in use: the nodes made from it would be
    // dropped the next time, and the windows docked since would lose their places at every launch.
    let usable = (smallestFree...Self.idLimit / 2).contains(stored)
    if !usable { repair.tidied.append("nextRawID \(stored) is in use or out of range") }
    repair.nextRawID = usable ? stored : smallestFree

    let (finalRoot, desktop) = repair.ensureDesktop(root: newRoot)
    self.init(checkedNodes: repair.kept, root: finalRoot, desktop: desktop, nextRawID: repair.nextRawID)
    for id in preorder() where isSplit(id) { steadyWeights(of: id) }
    // Not checked against the tree: they are whenever they are used.
    do {
      visits = Array((try container.decodeIfPresent([Visit].self, forKey: .visits) ?? []).suffix(Self.mostVisits))
    } catch {
      repair.tidied.append("the visits cannot be read")
    }
    do {
      loans = Array((try container.decodeIfPresent([Loan].self, forKey: .loans) ?? []).suffix(Self.mostLoans))
    } catch {
      repair.tidied.append("the loans cannot be read")
    }
    (decoder.userInfo[DecodingNotes.key] as? DecodingNotes)?.add(repair.notes, tidied: repair.tidied, at: decoder.codingPath)
  }

  /// Rebuilds a tree from what a file said, keeping only what fits together.
  private struct Repair {
    let read: [NodeID: Node]
    var kept: [NodeID: Node] = [:]
    /// What a person could tell, and what they could not (`DecodingNotes`).
    var notes: [String] = []
    var tidied: [String] = []
    var nextRawID = 0
    /// The one Desktop leaf to keep, if the root reaches any.
    var desktop: NodeID?
    private var used = Set<NodeID>()
    private var seenWindows = Set<WindowID>()

    init(read: [NodeID: Node]) { self.read = read }

    /// After `build`: the nodes it never came to.
    var unreached: [NodeID] { read.keys.filter { !used.contains($0) }.sorted() }

    private func listedChildren(of id: NodeID) -> [NodeID] {
      if case .split(_, let children) = read[id]?.kind { return children }
      return []
    }

    /// Keeps the Desktop the file names if the root reaches it, else the first one in tree order.
    mutating func chooseDesktop(preferring named: NodeID?, from root: NodeID) {
      var visited = Set<NodeID>()
      var pending = [root]
      while let id = pending.popLast() {
        guard visited.insert(id).inserted, let node = read[id] else { continue }
        if case .desktop = node.kind, desktop == nil || id == named { desktop = id }
        pending.append(contentsOf: listedChildren(of: id).reversed())
      }
    }

    /// How deep the deepest node under `root` is, counting each node the first time it is met, as
    /// `build` does. Not recursive, because its job is to say whether recursion is safe.
    func depth(from root: NodeID) -> Int {
      var visited = Set<NodeID>()
      var pending = [(id: root, depth: 0)]
      var deepest = 0
      while let (id, depth) = pending.popLast() {
        guard visited.insert(id).inserted, read[id] != nil else { continue }
        deepest = max(deepest, depth)
        for child in listedChildren(of: id).reversed() { pending.append((child, depth + 1)) }
      }
      return deepest
    }

    /// Copies the subtree at `id` into `kept` and returns the node that now stands for it: `id`,
    /// the only child left of it, or nil if nothing is left.
    mutating func build(_ id: NodeID, parent: NodeID?) -> NodeID? {
      guard var node = read[id] else {
        notes.append("\(parent?.description ?? "the root") lists \(id), which is missing or unreadable")
        return nil
      }
      if let keeps = node.keeps, keeps.contains(.move) {
        // Nothing would ever take it off again.
        tidied.append("\(id) is kept for a move, which is over")
        node.keeps = keeps == .move ? nil : keeps.subtracting(.move)
      }
      guard used.insert(id).inserted else {
        notes.append("\(id) is listed more than once")
        return nil
      }
      var weight = node.weight
      // Also of a root, which has no siblings for `steadyWeights` to measure it against.
      if !(weight > 0 && weight <= LayoutTree.maximumWeight) {
        notes.append("\(id) has weight \(weight)")
        weight = 1
      }

      let kind: Kind
      switch node.kind {
      case .desktop:
        guard id == desktop else {
          notes.append("\(id) is a second Desktop")
          return nil
        }
        kind = .desktop

      case .stack(let windows, let active):
        let fresh = windows.filter { seenWindows.insert($0).inserted }
        if fresh.count < windows.count { notes.append("\(id) holds windows that are already docked") }
        guard !fresh.isEmpty else {
          tidied.append("\(id) is an empty stack")
          return nil
        }
        // The same window stays in front if it can.
        let front = windows.indices.contains(active) ? fresh.firstIndex(of: windows[active]) : nil
        if front == nil { tidied.append("\(id) has active index \(active)") }
        kind = .stack(windows: fresh, active: front ?? 0)

      case .split(let axis, let listed):
        var children: [NodeID] = []
        for child in listed {
          guard let built = build(child, parent: id) else { continue }
          guard case .split(let childAxis, let grandchildren) = kept[built]!.kind, childAxis == axis,
            kept[built]!.keeps == nil
          else {
            children.append(built)
            continue
          }
          // Same-axis nesting: the grandchildren move up, dividing the child's share as they did.
          tidied.append("\(built) nests the same axis as \(id)")
          let share = kept[built]!.weight
          let total = grandchildren.reduce(0) { $0 + kept[$1]!.weight }
          for grandchild in grandchildren {
            kept[grandchild]!.weight = kept[grandchild]!.weight / total * share
            kept[grandchild]!.parent = id
          }
          kept[built] = nil
          children.append(contentsOf: grandchildren)
        }
        let firmly = !(node.keeps ?? []).isDisjoint(with: .firm)
        guard children.count >= (firmly ? 1 : 2) else {
          tidied.append("\(id) is a split with \(children.count) children")
          guard let only = children.first else { return nil }
          kept[only]!.parent = parent
          kept[only]!.weight = weight
          // As in `settle`: what pointed at the split points at the child now.
          if let keeps = node.keeps, !keeps.isEmpty, case .split = kept[only]!.kind {
            kept[only]!.keeps = (kept[only]!.keeps ?? []).union(keeps)
          }
          return only
        }
        kind = .split(axis: axis, children: children)
      }

      if node.parent != parent { tidied.append("\(id) names the wrong parent") }
      // A copy, so that whatever else a node comes to hold is kept. Its id cannot be changed, so
      // one filed under another id is made afresh.
      var repaired = node.id == id ? node : Node(id: id, parent: parent, kind: kind, weight: weight)
      repaired.parent = parent
      repaired.kind = kind
      repaired.weight = weight
      if let keeps = repaired.keeps {
        var isSplit = false
        if case .split = kind { isSplit = true }
        if !isSplit || keeps.isEmpty {
          tidied.append("\(id) is kept for nothing")
          repaired.keeps = nil
        }
      }
      kept[id] = repaired
      return id
    }

    /// Adds a Desktop at the right of everything if none was kept, and returns the root and the Desktop.
    mutating func ensureDesktop(root: NodeID?) -> (root: NodeID, desktop: NodeID) {
      if let root, let desktop, kept[desktop] != nil { return (root, desktop) }
      notes.append("the Desktop is missing")
      let desktop = NodeID(nextRawID)
      nextRawID += 1
      guard let root else {
        kept[desktop] = Node(id: desktop, parent: nil, kind: .desktop, weight: 1)
        return (desktop, desktop)
      }
      if case .split(.horizontal, let children) = kept[root]!.kind {
        let mean = children.reduce(0) { $0 + kept[$1]!.weight } / Double(children.count)
        kept[desktop] = Node(id: desktop, parent: root, kind: .desktop, weight: mean)
        kept[root]!.kind = .split(axis: .horizontal, children: children + [desktop])
        return (root, desktop)
      }
      let split = NodeID(nextRawID)
      nextRawID += 1
      kept[split] = Node(
        id: split, parent: nil, kind: .split(axis: .horizontal, children: [root, desktop]), weight: 1)
      kept[root]!.parent = split
      kept[root]!.weight = 1
      kept[desktop] = Node(id: desktop, parent: split, kind: .desktop, weight: 1)
      return (split, desktop)
    }
  }
}

/// What decoding repaired or skipped, for whoever reads a file to log. Put one in the decoder's
/// `userInfo` under `DecodingNotes.key` before decoding, and read `notes` afterwards.
///
/// A decoder works on one thread, and so must whoever shares this with it.
public final class DecodingNotes: @unchecked Sendable {
  public static let key = CodingUserInfoKey(rawValue: "arbor.decodingNotes")!

  /// One line per repair, each starting with where in the file it was: "workspaces.main.tree: n7 is …". For the log.
  public private(set) var notes: [String] = []
  /// Those of `notes` that a person could tell: something they made is gone or different (a display, a window's
  /// place, a size, a saved view, a name, where they were looking). Worth telling them about.
  ///
  /// The rest is `tidied`: bookkeeping put right that shows nowhere, such as history that repeats itself, a parent link, a pin
  /// of a window that does not float here. Arbor can write some of that itself, so to call the arrangement damaged
  /// for it would be a false alarm.
  public private(set) var losses: [String] = []
  public private(set) var tidied: [String] = []

  public init() {}

  func add(_ losses: [String], tidied: [String] = [], at path: [any CodingKey]) {
    let place = path.map(\.stringValue).joined(separator: ".")
    func placed(_ lines: [String]) -> [String] { lines.map { place.isEmpty ? $0 : "\(place): \($0)" } }
    self.losses += placed(losses)
    self.tidied += placed(tidied)
    notes += placed(losses) + placed(tidied)
  }

  /// For what is outside the core, or shows only once the whole file is read.
  public func add(_ line: String, isLoss: Bool = true) { add(isLoss ? [line] : [], tidied: isLoss ? [] : [line], at: []) }
}

/// A JSON object read one entry at a time, so that an entry that cannot be read is skipped (and
/// noted in the decoder's `DecodingNotes`) instead of failing everything around it.
public struct LossyDictionary<Key: Hashable & CodingKeyRepresentable, Value: Decodable>: Decodable {
  public var entries: [Key: Value] = [:]

  public init() {}

  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: StringKey.self)
    var skipped: [String] = []
    for key in container.allKeys {
      do {
        guard let name = Key(codingKey: key) else {
          skipped.append("skipped `\(key.stringValue)`: not a valid key")
          continue
        }
        entries[name] = try container.decode(Value.self, forKey: key)
      } catch {
        skipped.append("skipped `\(key.stringValue)`: \(Self.reason(for: error))")
      }
    }
    (decoder.userInfo[DecodingNotes.key] as? DecodingNotes)?.add(skipped.sorted(), at: decoder.codingPath)
  }

  private static func reason(for error: any Error) -> String {
    guard let error = error as? DecodingError else { return "\(error)" }
    switch error {
    case .keyNotFound(let key, _): return "`\(key.stringValue)` is missing"
    case .typeMismatch(_, let context), .valueNotFound(_, let context), .dataCorrupted(let context):
      return context.debugDescription
    @unknown default: return "\(error)"
    }
  }
}
