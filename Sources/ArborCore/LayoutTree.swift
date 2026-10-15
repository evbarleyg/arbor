/// One display's arrangement: a tree of splits whose leaves are window stacks
/// and exactly one Desktop leaf.
///
/// - A **split** lays its children out along an axis, sized by their weights.
/// - A **stack** holds one or more windows; only the active one is shown. A
///   stack with one window is an ordinary docked window; more is a tab group.
/// - The **desktop** leaf is the space where floating windows live. It is never
///   removed. It is what is left over, which can be nothing: see `desktopHasRoom`.
///
/// The tree is a value type, so callers can copy it, try an operation and lay
/// out the result (drop previews do exactly that).
///
/// Invariants (see `invariantViolations()`):
/// - every split has at least two children, or one if it is kept firmly (LayoutTree+Keeps.swift);
/// - no split has a child split on the same axis (same-axis nesting is flattened) unless the
///   child is kept;
/// - every stack has at least one window, and each window appears once;
/// - parent links match child lists; weights are positive, but for a Desktop without room.
public struct LayoutTree: Codable, Sendable, Equatable {
  public enum Kind: Codable, Sendable, Equatable {
    case split(axis: Axis, children: [NodeID])
    case stack(windows: [WindowID], active: Int)
    case desktop
  }

  public struct Node: Codable, Sendable, Equatable {
    public let id: NodeID
    public var parent: NodeID?
    public var kind: Kind
    /// Relative size among siblings. Only ratios matter.
    public var weight: Double
    /// Why this split must go on existing (LayoutTree+Keeps.swift). Nil for no reason, so that trees
    /// saved before this existed still load and equal trees compare equal.
    public var keeps: Keeps? = nil
  }

  public internal(set) var nodes: [NodeID: Node]
  public internal(set) var root: NodeID
  public let desktop: NodeID
  private var nextRawID: Int
  /// The last few docks that took half of one node's room (LayoutTree+Room.swift).
  var visits: [Visit] = []
  /// LayoutTree+Loans.swift.
  var loans: [Loan] = []

  /// A tree holding only the Desktop.
  public init() {
    let desktop = NodeID(0)
    nodes = [desktop: Node(id: desktop, parent: nil, kind: .desktop, weight: 1)]
    root = desktop
    self.desktop = desktop
    nextRawID = 1
  }

  /// A tree put together elsewhere in the core, by code that answers for the invariants
  /// (LayoutNotation+Tree.swift builds one from a line of text).
  init(assembled nodes: [NodeID: Node], root: NodeID, desktop: NodeID, nextRawID: Int) {
    self.nodes = nodes
    self.root = root
    self.desktop = desktop
    self.nextRawID = nextRawID
  }

  // MARK: Queries

  public subscript(id: NodeID) -> Node? { nodes[id] }

  public func contains(_ id: NodeID) -> Bool { nodes[id] != nil }

  public func children(of id: NodeID) -> [NodeID] {
    if case .split(_, let children) = nodes[id]?.kind { return children }
    return []
  }

  public func parent(of id: NodeID) -> NodeID? { nodes[id]?.parent }

  public func isSplit(_ id: NodeID) -> Bool {
    if case .split = nodes[id]?.kind { return true }
    return false
  }

  public func isStack(_ id: NodeID) -> Bool {
    if case .stack = nodes[id]?.kind { return true }
    return false
  }

  /// Ancestors from the parent up to the root.
  public func ancestors(of id: NodeID) -> [NodeID] {
    var result: [NodeID] = []
    var current = nodes[id]?.parent
    while let node = current {
      result.append(node)
      current = nodes[node]?.parent
    }
    return result
  }

  /// True if `descendant` is `ancestor` or lies inside its subtree.
  public func subtree(_ ancestor: NodeID, contains descendant: NodeID) -> Bool {
    descendant == ancestor || ancestors(of: descendant).contains(ancestor)
  }

  /// Node IDs in depth-first pre-order starting at `start` (default: root).
  public func preorder(from start: NodeID? = nil) -> [NodeID] {
    var result: [NodeID] = []
    var pending = [start ?? root]
    while let id = pending.popLast() {
      guard nodes[id] != nil else { continue }
      result.append(id)
      pending.append(contentsOf: children(of: id).reversed())
    }
    return result
  }

  /// Every docked window under `start`, in tree order.
  public func windows(under start: NodeID? = nil) -> [WindowID] {
    preorder(from: start).flatMap { id -> [WindowID] in
      if case .stack(let windows, _) = nodes[id]?.kind { return windows }
      return []
    }
  }

  public var allWindows: [WindowID] { windows(under: root) }

  /// The stack leaf holding `window`, if it is docked in this tree.
  public func leaf(containing window: WindowID) -> NodeID? {
    for (id, node) in nodes {
      if case .stack(let windows, _) = node.kind, windows.contains(window) { return id }
    }
    return nil
  }

  public func depth(of id: NodeID) -> Int { ancestors(of: id).count }

  /// Whether the Desktop has a share of the row or column it is in. Without one (weight 0) it is still there, in its place, for
  /// the view to go to and for names, history and saved views to mean. But beside docked windows it takes no room: no
  /// rectangle, no tile, no gap (`TreeView.isEffective`). Docked windows have taken all there was (`dock`), or Arrange
  /// Windows left nothing over (`grid`). Alone in the tree it has everything.
  public var desktopHasRoom: Bool { hasRoom(desktop) }

  /// The row or column that everything consists of: the root, or, where that holds one group and a Desktop without room, which is the
  /// group to look at, that group.
  var everything: NodeID {
    guard !desktopHasRoom else { return root }
    var top = root
    while case let others = children(of: top).filter({ $0 != desktop }), others.count == 1, isSplit(others[0]) { top = others[0] }
    return top
  }

  /// Whether `id` has everything to itself but for a Desktop without room, as after Arrange Windows with one window.
  public func isAloneBesideADesktopWithoutRoom(_ id: NodeID) -> Bool {
    guard !desktopHasRoom, id != desktop, let parent = nodes[id]?.parent, parent == root else { return false }
    return Set(children(of: parent)) == [id, desktop]
  }

  /// False only for a Desktop without room.
  func hasRoom(_ id: NodeID) -> Bool { (nodes[id]?.weight ?? 0) > 0 }

  /// What one of `row` weighs on average, counting those that have a share at all.
  private func meanWeight(of row: [NodeID]) -> Double {
    let sharing = row.filter(hasRoom)
    return sharing.reduce(0) { $0 + nodes[$1]!.weight } / Double(max(sharing.count, 1))
  }

  /// All that is left over in `row`, for `leaf`; from now on that is nothing. Nil if the Desktop is not in it, or has nothing.
  /// With the room goes what the Desktop is owed (LayoutTree+Loans.swift). Alone in its row the Desktop is all there is in it, and a dock
  /// there is a first dock: it takes a half.
  private mutating func takeWhatIsLeft(in row: [NodeID], for leaf: NodeID) -> Double? {
    guard row.contains(desktop), let left = nodes[desktop]?.weight, left > 0 else { return nil }
    guard row.contains(where: { $0 != desktop && hasRoom($0) }) else {
      nodes[desktop]!.weight = left / 2
      return left / 2
    }
    nodes[desktop]!.weight = 0
    passClaims(from: desktop, to: leaf)
    return left
  }

  /// How deep the deepest node is; 0 for a tree that is only the Desktop.
  public var nesting: Int {
    var deepest = 0
    var pending = [(id: root, depth: 0)]
    while let (id, depth) = pending.popLast() {
      deepest = max(deepest, depth)
      for child in children(of: id) { pending.append((child, depth + 1)) }
    }
    return deepest
  }

  // MARK: Docking

  /// Docks `window` beside `target` on `edge` and returns the new leaf.
  ///
  /// - If `target` is a split along the same axis, the window joins it as the
  ///   first or last child, sized like the average child ("dock at the edge of
  ///   everything in view").
  /// - Else if `target`'s parent splits along that axis, the window is inserted
  ///   next to `target` and takes half of its share, or with `evenShare` is
  ///   sized like the average child, which takes a little from every child.
  /// - Otherwise `target` is wrapped in a new split with the window beside it.
  ///
  /// With `groupingFor`, the window and `target` end up as a group of their own, whatever is around
  /// them: the second case is skipped, so `target` is wrapped also where its parent runs along that
  /// axis, and the new split (the leaf's parent) is kept for that reason (LayoutTree+Keeps.swift).
  /// It takes the same room either way: half of what `target` had.
  ///
  /// **What is left over goes first** (QUESTIONS Q28). In the first two cases, if the Desktop is in that row and has room, the
  /// window takes that, all of it, and nobody else gives anything: the second of two docks takes the other half, and
  /// the first stays as it is. Docked windows give only when nothing is left. The room is left over again when one of two
  /// leaves (`detach`), or when the window leaves a row that is still as it found it (LayoutTree+Room.swift). With `desktopColumn` the
  /// Desktop has a share of its own like any window's, as in the first build.
  ///
  /// A `target` that is not in the tree stands for the root. A window that is already docked stays
  /// where it is, and its leaf is returned: remove it first to move it (`Workspace.dock` does).
  @discardableResult
  public mutating func dock(
    _ window: WindowID, beside target: NodeID, edge: Edge, evenShare: Bool = false,
    groupingFor reason: Keeps? = nil, desktopColumn: Bool = false
  ) -> NodeID {
    if let existing = leaf(containing: window) { return existing }
    var host: NodeID?
    defer {
      if let leaf = leaf(containing: window), let parent = nodes[leaf]?.parent {
        steadyWeights(of: parent)
        if let host { noteVisit(of: leaf, to: host) }
      }
    }
    let target = nodes[target] == nil ? root : target
    let axis = edge.axis
    let leafID = makeNode(kind: .stack(windows: [window], active: 0), parent: nil, weight: 1)

    if case .split(let splitAxis, var children) = nodes[target]!.kind, splitAxis == axis {
      if !desktopColumn, let left = takeWhatIsLeft(in: children, for: leafID) {
        nodes[leafID]!.weight = left
        host = desktop
      } else {
        nodes[leafID]!.weight = meanWeight(of: children)
      }
      nodes[leafID]!.parent = target
      if edge.isLeading { children.insert(leafID, at: 0) } else { children.append(leafID) }
      nodes[target]!.kind = .split(axis: axis, children: children)
      return leafID
    }

    if reason == nil, let parent = nodes[target]!.parent,
      case .split(let parentAxis, var siblings) = nodes[parent]!.kind, parentAxis == axis
    {
      let index = siblings.firstIndex(of: target)!
      if !desktopColumn, let left = takeWhatIsLeft(in: siblings, for: leafID) {
        nodes[leafID]!.weight = left
        host = desktop
      } else if evenShare || !hasRoom(target) {
        // (Half of nothing is no share.)
        nodes[leafID]!.weight = meanWeight(of: siblings)
      } else {
        let half = nodes[target]!.weight / 2
        nodes[target]!.weight = half
        nodes[leafID]!.weight = half
        host = target
      }
      nodes[leafID]!.parent = parent
      siblings.insert(leafID, at: edge.isLeading ? index : index + 1)
      nodes[parent]!.kind = .split(axis: axis, children: siblings)
      return leafID
    }

    let oldParent = nodes[target]!.parent
    // Beside a Desktop without room, which only the view on it shows: the window gets a share like the others', and the Desktop goes on
    // without, so that no column is left when the window goes again (`settle`).
    let hadRoom = hasRoom(target)
    let share = hadRoom ? nodes[target]!.weight : meanWeight(of: oldParent.map(children(of:)) ?? [])
    let splitID = makeNode(
      kind: .split(axis: axis, children: edge.isLeading ? [leafID, target] : [target, leafID]),
      parent: oldParent, weight: share > 0 ? share : 1)
    replaceChild(of: oldParent, old: target, new: splitID)
    nodes[target]!.parent = splitID
    nodes[target]!.weight = hadRoom ? 1 : 0
    nodes[leafID]!.parent = splitID
    nodes[leafID]!.weight = 1
    if let reason { keep(splitID, for: reason) }
    return leafID
  }

  /// Adds `window` to the stack `leaf` as its active window (a tab group). Nothing changes if
  /// `leaf` is not a stack or the window is already docked.
  public mutating func addToStack(_ window: WindowID, leaf stack: NodeID) {
    guard leaf(containing: window) == nil else { return }
    guard case .stack(var windows, _) = nodes[stack]?.kind else { return }
    windows.append(window)
    nodes[stack]!.kind = .stack(windows: windows, active: windows.count - 1)
  }

  /// Makes `window` the visible window of its stack.
  public mutating func activate(_ window: WindowID) {
    guard let leaf = leaf(containing: window),
      case .stack(let windows, _) = nodes[leaf]!.kind,
      let index = windows.firstIndex(of: window)
    else { return }
    nodes[leaf]!.kind = .stack(windows: windows, active: index)
  }

  /// The window a stack shows when all of its windows are present.
  public func activeWindow(of leaf: NodeID) -> WindowID? {
    guard case .stack(let windows, let active) = nodes[leaf]?.kind, !windows.isEmpty else {
      return nil
    }
    return windows[min(max(active, 0), windows.count - 1)]
  }

  // MARK: Removal

  /// Removes `window`. Empty leaves are deleted, splits left with one child
  /// collapse into it, and same-axis nesting created by the collapse is
  /// flattened. The returned remap says where references to deleted nodes
  /// (cameras, history, saved views) should point now.
  ///
  /// The leaf's siblings share its space in proportion to their weights. With `shareSpace` false
  /// its weight goes to the sibling before it (after it, if it was the first) instead, which under
  /// `LayoutOptions.shareRemovedSpace` false leaves the other siblings exactly where they were. Either way, if that leaves one
  /// sibling alone beside a Desktop without room, it stays as it is and the space is left over (`detach`).
  ///
  /// `away`: the window takes up no space just now (it is minimized or hidden, or a place kept for one that is not open). Whoever is
  /// there has its space already, and staying as it is means keeping that.
  @discardableResult
  public mutating func remove(_ window: WindowID, shareSpace: Bool = true, away: Bool = false) -> Remap {
    var remap = Remap()
    guard let leaf = leaf(containing: window),
      case .stack(var windows, var active) = nodes[leaf]!.kind,
      let index = windows.firstIndex(of: window)
    else { return remap }

    windows.remove(at: index)
    if !windows.isEmpty {
      if index < active || active >= windows.count { active = max(active - 1, 0) }
      nodes[leaf]!.kind = .stack(windows: windows, active: active)
      return remap
    }
    detach(leaf, shareSpace: shareSpace, away: away, remap: &remap)
    return remap
  }

  /// Replaces a window ID in place (used to re-match a window after an app restart). Returns
  /// false, changing nothing, if `old` is not docked or `new` already is.
  @discardableResult
  public mutating func replaceWindow(_ old: WindowID, with new: WindowID) -> Bool {
    guard leaf(containing: new) == nil, let leaf = leaf(containing: old),
      case .stack(var windows, let active) = nodes[leaf]!.kind,
      let index = windows.firstIndex(of: old)
    else { return false }
    windows[index] = new
    nodes[leaf]!.kind = .stack(windows: windows, active: active)
    return true
  }

  /// Exchanges the positions of two children of the same split. Each keeps
  /// its weight, so sizes travel with the nodes.
  public mutating func swapSiblings(_ x: NodeID, _ y: NodeID) {
    guard let parent = nodes[x]?.parent, parent == nodes[y]?.parent,
      case .split(let axis, var children) = nodes[parent]!.kind,
      let i = children.firstIndex(of: x), let j = children.firstIndex(of: y)
    else { return }
    children.swapAt(i, j)
    nodes[parent]!.kind = .split(axis: axis, children: children)
  }

  /// Swaps the contents of the two leaves holding `a` and `b`.
  public mutating func swapLeaves(of a: WindowID, and b: WindowID) {
    guard let leafA = leaf(containing: a), let leafB = leaf(containing: b), leafA != leafB else {
      return
    }
    let kindA = nodes[leafA]!.kind
    nodes[leafA]!.kind = nodes[leafB]!.kind
    nodes[leafB]!.kind = kindA
  }

  // MARK: Resizing

  /// The least `moveBoundary` leaves on either side unless told otherwise.
  public static let minimumPointsBesideBoundary: Double = 80

  /// In points. Less than this is what is left over when weights are added up, not a move.
  static let leastMoveOfABoundary = 0.01

  /// Moves the boundary between two adjacent children of a split by
  /// `deltaPoints` (positive moves it right/down). `pointsPerWeight` converts
  /// points to weight units for this split; layouts report it on each seam.
  /// Neither child shrinks below `minimumPoints`. Nothing moves if the two are not children of
  /// the same split (a seam from a layout the tree has since left behind), if they are already too
  /// small to give anything up, if one is a Desktop without room (which has no boundary), or if a number is not one.
  /// `byHand`: a person has moved it, by whatever means, and what Arbor has lent around it is forgotten
  /// (`forgetLoans`). False where Arbor moves it for ends of its own.
  public mutating func moveBoundary(
    leading: NodeID, trailing: NodeID, by deltaPoints: Double, pointsPerWeight: Double,
    minimumPoints: Double = LayoutTree.minimumPointsBesideBoundary, byHand: Bool = true
  ) {
    // A distance that is not a number would make both weights not a number, for good.
    guard !deltaPoints.isNaN, pointsPerWeight > 0, let a = nodes[leading]?.weight,
      let b = nodes[trailing]?.weight
    else { return }
    guard pointsPerWeight.isFinite, minimumPoints >= 0, leading != trailing, a > 0, b > 0,
      let parent = nodes[leading]?.parent, parent == nodes[trailing]?.parent
    else { return }
    let total = a + b
    let minimumWeight = minimumPoints / pointsPerWeight
    guard total > 2 * minimumWeight else { return }
    let newA = min(max(a + deltaPoints / pointsPerWeight, minimumWeight), total - minimumWeight)
    nodes[leading]!.weight = newA
    nodes[trailing]!.weight = total - newA
    // At its limit a gap stays where it is, however far the hand goes: then nothing has been decided.
    if hasLoans, abs(newA - a) * pointsPerWeight > Self.leastMoveOfABoundary {
      forgetLoans(across: leading, trailing, resized: byHand ? preorder(from: leading) + preorder(from: trailing) : nil)
    }
    steadyWeights(of: parent)
  }

  /// Shares the weight these nodes have between them out again, in proportion to `lengths` (points, say). What
  /// they weigh together stays the same, so nodes that are not named (absent siblings) keep their share.
  /// Does nothing unless every node exists and every length is a positive number.
  public mutating func setShares(_ lengths: [NodeID: Double]) {
    // In order of id: a sum of fractions depends on its order in the last digit, and the weights are saved.
    let ids = lengths.keys.sorted()
    let total = ids.reduce(0) { $0 + lengths[$1]! }
    guard ids.count > 1, total.isFinite, ids.allSatisfy({ nodes[$0] != nil && lengths[$0]! > 0 }) else { return }
    let weight = ids.reduce(0) { $0 + nodes[$1]!.weight }
    guard weight > 0, weight.isFinite else { return }
    for id in ids { nodes[id]!.weight = weight * lengths[id]! / total }
  }

  /// Moves the boundary at `seam`, from a layout of this tree, by `deltaPoints`. What changes size is what is seen
  /// on either side of the gap. That is `seam.leading` and `seam.trailing`, except where one of them is a group on
  /// the same axis (F62), which looks like part of the row: then it is the window at that end of the group, the
  /// others in the group stay as they are, and `minimumPoints` is the least for that window.
  public mutating func moveBoundary(at seam: Seam, by deltaPoints: Double, minimumPoints: Double = 80, byHand: Bool = true) {
    let outer = Double(seam.pointsPerWeight)
    guard !(seam.leadingEnds.isEmpty && seam.trailingEnds.isEmpty) else {
      return moveBoundary(
        leading: seam.leading, trailing: seam.trailing, by: deltaPoints, pointsPerWeight: outer,
        minimumPoints: minimumPoints, byHand: byHand)
    }
    /// Each node that grows (or shrinks) by the same number of points, with its own rate, outermost first.
    func side(_ node: NodeID, _ ends: [Seam.End]) -> [(node: NodeID, rate: Double)]? {
      let side = [(node, outer)] + ends.map { ($0.node, Double($0.pointsPerWeight)) }
      let holds = zip(side, side.dropFirst()).allSatisfy { $0.0 != $1.0 && subtree($0.0, contains: $1.0) }
      return holds && side.allSatisfy { nodes[$0.0] != nil && $0.1 > 0 && $0.1.isFinite } ? side : nil
    }
    guard !deltaPoints.isNaN, minimumPoints >= 0, seam.leading != seam.trailing,
      let parent = nodes[seam.leading]?.parent, parent == nodes[seam.trailing]?.parent,
      let leading = side(seam.leading, seam.leadingEnds), let trailing = side(seam.trailing, seam.trailingEnds)
    else { return }
    let a = nodes[leading.last!.node]!.weight * leading.last!.rate
    let b = nodes[trailing.last!.node]!.weight * trailing.last!.rate
    guard a + b > 2 * minimumPoints else { return }
    let applied = min(max(a + deltaPoints, minimumPoints), a + b - minimumPoints) - a
    for (node, rate) in leading { nodes[node]!.weight += applied / rate }
    for (node, rate) in trailing { nodes[node]!.weight -= applied / rate }
    // Of a group that runs along the row only what is at its end has changed, and with it each group it is the end of.
    if hasLoans, abs(applied) > Self.leastMoveOfABoundary {
      forgetLoans(
        across: seam.leading, seam.trailing,
        resized: byHand
          ? (leading + trailing).map(\.node) + preorder(from: leading.last!.node) + preorder(from: trailing.last!.node) : nil)
    }
    for (node, _) in leading + trailing { steadyWeights(of: nodes[node]!.parent!) }
  }

  // MARK: Construction helpers

  /// A fresh tree that docks `windows` in columns of equal height, give or take one window (the
  /// taller columns come first), followed by a Desktop column of `desktopWeight`, or with nil by a Desktop without room: nothing
  /// is left over. Windows fill
  /// the first column from top to bottom, then the next. A window listed twice is docked once.
  public static func grid(of windows: [WindowID], desktopWeight: Double? = nil) -> LayoutTree {
    var seen = Set<WindowID>()
    let windows = windows.filter { seen.insert($0).inserted }
    var tree = LayoutTree()
    guard !windows.isEmpty else { return tree }
    // The weight comes from settings.json, where it can be any number, and is saved with the tree.
    // Zero or less breaks the layout for good, and a huge one overflows when weights are added up.
    let desktopWeight = desktopWeight.map { $0.isNaN ? 0.5 : min(max($0, 0.05), 20) } ?? 0
    let columns = Int(Double(windows.count).squareRoot().rounded(.up))
    var remaining = windows[...]
    // Each column is docked to the left of the Desktop, so the Desktop ends up last.
    for column in 0..<columns {
      let columnsLeft = columns - column
      let slice = remaining.prefix((remaining.count + columnsLeft - 1) / columnsLeft)
      remaining = remaining.dropFirst(slice.count)
      guard let first = slice.first else { break }
      var below = tree.dock(first, beside: tree.desktop, edge: .left, desktopColumn: true)
      for window in slice.dropFirst() {
        below = tree.dock(window, beside: below, edge: .bottom)
      }
    }
    // Docking halves shares as it goes; even everything out.
    for id in tree.preorder() where tree.isSplit(id) {
      for child in tree.children(of: id) {
        tree.nodes[child]!.weight = child == tree.desktop ? desktopWeight : 1
      }
    }
    return tree
  }

  // MARK: Validation

  /// Human-readable descriptions of broken invariants. Empty means valid. Safe to call on a tree
  /// decoded from a damaged file: it visits each node once, so links that form a loop end the walk
  /// instead of extending it for ever (`preorder` and `ancestors` trust the links).
  public func invariantViolations() -> [String] {
    var problems: [String] = []
    guard nodes[root] != nil else { return ["root \(root) missing"] }
    if nodes[root]!.parent != nil { problems.append("root has a parent") }
    guard case .desktop = nodes[desktop]?.kind else { return problems + ["desktop leaf missing"] }
    if let highest = nodes.keys.max(), highest.rawValue >= nextRawID {
      problems.append("the next node would reuse a number up to \(highest)")
    }

    var seenWindows = Set<WindowID>()
    var reachable = Set<NodeID>()
    var pending = [(id: root, depth: 0)]
    while let (id, depth) = pending.popLast() {
      // A missing child is reported with the split that lists it.
      guard let node = nodes[id] else { continue }
      guard reachable.insert(id).inserted else {
        problems.append("\(id) is listed twice")
        continue
      }
      if node.id != id { problems.append("\(id) calls itself \(node.id)") }
      if depth > Self.maximumDepth { return problems + ["nested deeper than \(Self.maximumDepth) levels"] }
      // Written so that not-a-number fails too.
      let isDesktopWithoutRoom = id == desktop && node.weight == 0 && node.parent.map { children(of: $0).contains(where: hasRoom) } == true
      if !(node.weight > 0 && node.weight <= Self.maximumWeight), !isDesktopWithoutRoom {
        problems.append("\(id) has weight \(node.weight)")
      }
      if node.keeps != nil, !isSplit(id) || node.keeps!.isEmpty { problems.append("\(id) is kept for nothing") }
      switch node.kind {
      case .split(let axis, let children):
        if children.count < (isKeptFirmly(id) ? 1 : 2) {
          problems.append("\(id) split has \(children.count) children")
        }
        for child in children {
          guard let childNode = nodes[child] else {
            problems.append("\(id) lists missing child \(child)")
            continue
          }
          if childNode.parent != id { problems.append("\(child) parent is not \(id)") }
          if case .split(let childAxis, _) = childNode.kind, childAxis == axis, !isKept(child) {
            problems.append("\(child) nests the same axis as \(id)")
          }
        }
        pending.append(contentsOf: children.reversed().map { ($0, depth + 1) })
      case .stack(let windows, let active):
        if windows.isEmpty { problems.append("\(id) stack is empty") }
        if active < 0 || active >= max(windows.count, 1) {
          problems.append("\(id) active index \(active) out of range")
        }
        for window in windows where !seenWindows.insert(window).inserted {
          problems.append("\(window) appears twice")
        }
      case .desktop:
        if id != desktop { problems.append("extra desktop \(id)") }
      }
    }
    for id in nodes.keys.sorted() where !reachable.contains(id) {
      problems.append("\(id) is unreachable")
    }
    return problems
  }

  /// Far beyond what docking produces. Laying out recurses once per level, and weights are summed.
  public static let maximumDepth = 100
  static let maximumWeight = 1e12

  // MARK: Private

  private mutating func makeNode(kind: Kind, parent: NodeID?, weight: Double) -> NodeID {
    let id = NodeID(nextRawID)
    nextRawID += 1
    nodes[id] = Node(id: id, parent: parent, kind: kind, weight: weight)
    return id
  }

  mutating func replaceChild(of parent: NodeID?, old: NodeID, new: NodeID) {
    guard let parent else {
      root = new
      return
    }
    guard case .split(let axis, var children) = nodes[parent]!.kind,
      let index = children.firstIndex(of: old)
    else { return }
    children[index] = new
    nodes[parent]!.kind = .split(axis: axis, children: children)
  }

  /// Deletes a leaf (or a split that has lost its last child) and repairs the tree above it.
  mutating func detach(_ id: NodeID, shareSpace: Bool, away: Bool = false, remap: inout Remap) {
    guard let parent = nodes[id]?.parent,
      case .split(let axis, var children) = nodes[parent]!.kind
    else { return }
    // Whoever is left alone stays as it is (QUESTIONS Q28): of the two places that everything consists of one leaves, and the other
    // has what it had, however it came to be alone. The room that is freed is left over, where it was freed. A Desktop without room
    // can lie anywhere and nobody sees the difference, so it takes the place of what leaves, with what that is owed. What the one
    // that stays had lent for its sake goes back first (F61): that is its own, and a gap its person dragged is where they left it.
    // (From three or more down the others share. So they do inside a group: no hole opens among docked windows.)
    if !away, !hasRoom(desktop), parent == everything, id != desktop, nodes[id] != nil, children.filter({ $0 != desktop }).count == 2 {
      passClaims(from: id, to: desktop)
      repayLoans(of: id)
      let freed = nodes[id]!.weight
      visits.removeAll { $0.guest == id || $0.host == id }
      let home = nodes[desktop]!.parent!
      if home != parent, case .split(let inner, var others) = nodes[home]!.kind {
        others.removeAll { $0 == desktop }
        nodes[home]!.kind = .split(axis: inner, children: others)
      }
      children.removeAll { $0 == desktop }
      children[children.firstIndex(of: id)!] = desktop
      nodes[desktop]!.parent = parent
      nodes[desktop]!.weight = freed
      nodes[id] = nil
      remap.recordDeletion(of: id, nearest: parent)
      nodes[parent]!.kind = .split(axis: axis, children: children)
      steadyWeights(of: parent)
      if home != parent { settle(home, shareSpace: shareSpace, remap: &remap) }
      return
    }
    // Whoever took all that was left over hands back what came with it.
    if visits.contains(where: { $0.guest == id && $0.host == desktop }) { passClaims(from: id, to: desktop) }
    // (One that is away has lent its room to whoever is there, who keep it: no column opens under them.)
    if away { visits.removeAll { $0.guest == id && $0.host == desktop } }
    repayLoans(of: id)
    // A visitor's room goes back to its host either way, and only once. With two children the one that stays
    // takes the whole split.
    if !endVisit(of: id, leaving: parent), !shareSpace, children.count > 2,
      let index = children.firstIndex(of: id), let freed = nodes[id]?.weight,
      // Not to a Desktop without room: no column opens because a window has left.
      let heir = children[..<index].last(where: hasRoom) ?? children[(index + 1)...].first(where: hasRoom)
    {
      nodes[heir]?.weight += freed
    }
    children.removeAll { $0 == id }
    nodes[id] = nil
    remap.recordDeletion(of: id, nearest: parent)
    nodes[parent]!.kind = .split(axis: axis, children: children)
    settle(parent, shareSpace: shareSpace, away: away, remap: &remap)
  }

  /// If `child` is a split on the same axis as `parent`, splices its children
  /// into `parent`, keeping their proportions. A split that is kept stays as it is.
  mutating func flattenIfSameAxis(_ child: NodeID, into parent: NodeID, remap: inout Remap)
  {
    guard case .split(let childAxis, let grandchildren) = nodes[child]!.kind,
      case .split(let parentAxis, var siblings) = nodes[parent]!.kind,
      childAxis == parentAxis, !isKept(child),
      let index = siblings.firstIndex(of: child)
    else { return }
    let share = nodes[child]!.weight
    let total = grandchildren.map { nodes[$0]!.weight }.reduce(0, +)
    for grandchild in grandchildren {
      // (A group that is down to a Desktop without room: it has the group's.)
      nodes[grandchild]!.weight = total > 0 ? nodes[grandchild]!.weight / total * share : share / Double(grandchildren.count)
      nodes[grandchild]!.parent = parent
    }
    siblings.replaceSubrange(index...index, with: grandchildren)
    nodes[parent]!.kind = .split(axis: parentAxis, children: siblings)
    nodes[child] = nil
    remap.record(child, movedTo: parent)
    steadyWeights(of: parent)
  }

  /// The smallest a weight may be next to its largest sibling: a hundredth of a point beside a
  /// sibling ten thousand points wide.
  static let smallestRatio = 1e-6

  /// Keeps a split's weights in a range where arithmetic on them stays exact enough. Only ratios
  /// matter, and every dock beside a node halves its weight while a removal gives nothing back to
  /// the number itself, so without this a long session (or a script) walks weights down to zero,
  /// where the layout divides by them. Weights a person could tell apart are left exactly as they
  /// are, and doing this twice changes nothing more.
  ///
  /// A Desktop without room has none on purpose, and takes no part.
  mutating func steadyWeights(of split: NodeID) {
    let children = children(of: split).filter { $0 != desktop || nodes[$0]!.weight != 0 }
    guard !children.isEmpty else { return }
    let mean = children.reduce(0) { $0 + nodes[$1]!.weight } / Double(children.count)
    if !(mean > 1.0 / 1024 && mean < 1024) {
      // Also the way back from a sum that overflowed, or that holds something that is not a number.
      let scale = mean > 0 && mean.isFinite ? 1 / mean : 0
      for child in children {
        let scaled = nodes[child]!.weight * scale
        nodes[child]!.weight = scaled.isFinite && scaled > 0 ? scaled : 1
      }
    }
    // Measured against the largest sibling, which raising the small ones does not move.
    let floor = children.reduce(0) { max($0, nodes[$1]!.weight) } * Self.smallestRatio
    for child in children where !(nodes[child]!.weight >= floor) { nodes[child]!.weight = floor }
  }

  /// For `init(from:)`, which has checked every invariant (LayoutTree+Decoding.swift).
  init(checkedNodes nodes: [NodeID: Node], root: NodeID, desktop: NodeID, nextRawID: Int) {
    self.nodes = nodes
    self.root = root
    self.desktop = desktop
    self.nextRawID = nextRawID
  }
}

/// Where references to deleted nodes should point after a tree change.
public struct Remap: Sendable, Equatable {
  public private(set) var moved: [NodeID: NodeID] = [:]

  public init() {}

  /// The nodes whose content is gone. `moved` sends them to their parent, the nearest thing left.
  private var deleted: Set<NodeID> = []

  mutating func record(_ old: NodeID, movedTo new: NodeID) { moved[old] = new }

  mutating func recordDeletion(of old: NodeID, nearest: NodeID) {
    moved[old] = nearest
    deleted.insert(old)
  }

  public var isEmpty: Bool { moved.isEmpty }

  /// Follows moves until reaching a node that exists in `tree`; falls back to the root.
  public func resolve(_ id: NodeID, in tree: LayoutTree) -> NodeID {
    var current = id
    var hops = 0
    while !tree.contains(current), let next = moved[current], hops < 64 {
      current = next
      hops += 1
    }
    return tree.contains(current) ? current : tree.root
  }

  /// The node that holds what `id` held: `id` itself if it is still there, or what it collapsed or
  /// merged into. Nil if its content is gone, where `resolve` answers with the parent. A view can
  /// fall back on the parent; a name must not come to mean it.
  public func survivor(of id: NodeID, in tree: LayoutTree) -> NodeID? {
    var current = id
    var hops = 0
    while !tree.contains(current), !deleted.contains(current), let next = moved[current], hops < 64 {
      current = next
      hops += 1
    }
    return tree.contains(current) ? current : nil
  }
}

// MARK: - Keyboard tiling tools (docs/features/F22-keyboard-tiling-tools.md)

extension LayoutTree {
  /// Gives the children of `start` and of every split inside it equal shares: what looks like one place gets one. The Desktop counts
  /// as `desktopWeight` of a window where `grid` puts it (last in a root that runs left to right), so
  /// evening out an arranged display gives what `arrange` made; anywhere else, and with nil everywhere, it counts as one.
  /// A Desktop without room, which is what `arrange` makes with nil, looks like no place and with nil stays without.
  public mutating func equalize(under start: NodeID, desktopWeight: Double? = nil) {
    // Bounded exactly as `grid` bounds it: the number comes from settings.json, where it can be anything.
    let narrow = desktopWeight.map { $0.isNaN ? 0.5 : min(max($0, 0.05), 20) }
    for id in preorder(from: start) {
      guard case .split(let axis, let children) = nodes[id]!.kind else { continue }
      let isArranged = id == root && axis == .horizontal && children.last == desktop
      for child in children where hasRoom(child) || narrow != nil {
        nodes[child]!.weight = (isArranged && child == desktop ? narrow : nil) ?? Double(places(in: child, along: axis))
      }
    }
  }

  /// How many places `id` shows along `axis`: one, or for a group that runs the same way (kept, F62), which looks like part of
  /// the row around it, as many as its children show. (With gaps that is a point or two off; the tree does not know the gap.)
  public func places(in id: NodeID, along axis: Axis) -> Int {
    guard case .split(axis, let children) = nodes[id]?.kind else { return 1 }
    return max(children.filter(hasRoom).reduce(0) { $0 + places(in: $1, along: axis) }, 1)
  }

  /// Turns the split `id` the other way: a row becomes a column and a column a row, keeping the
  /// order and the weights of its children.
  ///
  /// Axes alternate down the tree, so two more things follow. Every split inside `id` turns as well: groups stay groups.
  /// And a split that is not the root now runs the same way as its parent, where the tree would dissolve it. It is kept
  /// (`Keeps.turned`), so that it holds the same windows in the same room and turning it again gives back the same tree,
  /// mark and all. No node is created or deleted.
  public mutating func rotate(_ id: NodeID) {
    guard isSplit(id) else { return }
    for node in preorder(from: id) {
      guard case .split(let axis, let children) = nodes[node]!.kind else { continue }
      nodes[node]!.kind = .split(axis: axis.perpendicular, children: children)
    }
    keep(id, for: .turned)
    stopKeepingWhereItChangesNothing(for: .turned)
  }

  /// Reverses the order of the children of the split `id`. Each keeps its weight, and what is
  /// inside each child stays as it is.
  public mutating func mirror(_ id: NodeID) {
    guard case .split(let axis, let children) = nodes[id]?.kind else { return }
    nodes[id]!.kind = .split(axis: axis, children: children.reversed())
  }

  /// Exchanges the places of the leaves holding `a` and `b`: each takes the other's parent, position and weight,
  /// so the slots keep their sizes. Unlike `swapLeaves`, the leaves keep their ids, so whatever refers to a window's
  /// leaf (the camera, history, saved views, guests) goes with the window, as it does when the window is docked
  /// somewhere else. Nothing changes if either is not docked or both are tabs of one group.
  public mutating func tradePlaces(of a: WindowID, and b: WindowID) {
    guard let leafA = leaf(containing: a), let leafB = leaf(containing: b), leafA != leafB,
      let parentA = nodes[leafA]?.parent, let parentB = nodes[leafB]?.parent,
      case .split(let axisA, var childrenA) = nodes[parentA]?.kind, let placeA = childrenA.firstIndex(of: leafA),
      case .split(let axisB, var childrenB) = nodes[parentB]?.kind, let placeB = childrenB.firstIndex(of: leafB)
    else { return }
    if parentA == parentB {
      childrenA.swapAt(placeA, placeB)
    } else {
      childrenA[placeA] = leafB
      childrenB[placeB] = leafA
      nodes[parentB]!.kind = .split(axis: axisB, children: childrenB)
    }
    nodes[parentA]!.kind = .split(axis: axisA, children: childrenA)
    let (weightA, weightB) = (nodes[leafA]!.weight, nodes[leafB]!.weight)
    nodes[leafA]!.parent = parentB
    nodes[leafA]!.weight = weightB
    nodes[leafB]!.parent = parentA
    nodes[leafB]!.weight = weightA
  }

  /// `swapLeaves` for windows docked in two different trees (two displays): the leaf holding `a` in
  /// `first` and the leaf holding `b` in `second` exchange what they hold. A leaf cannot leave its tree, so
  /// here what refers to a leaf stays with the slot.
  public static func swapLeaves(
    of a: WindowID, in first: inout LayoutTree, and b: WindowID, in second: inout LayoutTree
  ) {
    guard let leafA = first.leaf(containing: a), let leafB = second.leaf(containing: b) else { return }
    let kindA = first.nodes[leafA]!.kind
    first.nodes[leafA]!.kind = second.nodes[leafB]!.kind
    second.nodes[leafB]!.kind = kindA
  }
}
