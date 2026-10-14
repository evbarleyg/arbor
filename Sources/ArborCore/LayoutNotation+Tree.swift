/// From an arrangement that is written down to a `LayoutTree` of real windows, and back.
extension LayoutNotation {
  /// Which windows the slots of an arrangement got.
  public struct Resolution: Equatable, Sendable {
    /// The windows of each slot, in the order of `Spec.slots`.
    public var windows: [[WindowID]]
    /// What was asked for and has no window at all, as written, each once.
    public var missing: [WindowSlot.Owner]
    /// Apps that were asked for more windows than they have (or than other slots left them), and how many they have.
    public var short: [Shortfall]

    public struct Shortfall: Equatable, Sendable {
      public var app: String
      public var found: Int

      public init(app: String, found: Int) {
        self.app = app
        self.found = found
      }
    }

    public var allWindows: [WindowID] { windows.flatMap { $0 } }
  }
}

extension LayoutNotation.Spec {
  /// The id that the space of each slot has in the tree `tree(filling:)` builds, in the order of `slots`.
  public var nodeOfEachSlot: [NodeID] {
    var result: [NodeID] = []
    var next = 1
    func visit(_ space: LayoutNotation.Space) {
      let id = NodeID(next)
      next += 1
      switch space.kind {
      case .desktop: break
      case .windows(let slots): result += slots.map { _ in id }
      case .group(_, let members): members.forEach(visit)
      }
    }
    visit(root)
    return result
  }

  /// Matches the slots to `candidates`, which come best first (`WindowSlot.assign`).
  ///
  /// With `current`, the display's tree as it is, windows that are already where this arrangement would put them stay there:
  /// ids depend only on the text, so a stack under a slot's id is that slot's place if the same line made the tree, and
  /// means nothing (and is ignored, unless its windows happen to fit) if another did.
  public func resolve(_ candidates: [WindowCandidate], current: LayoutTree? = nil) -> LayoutNotation.Resolution {
    let slots = self.slots
    let inPlace = current.map { tree in
      nodeOfEachSlot.map { node -> [WindowID] in
        if case .stack(let windows, _) = tree[node]?.kind { return windows }
        return []
      }
    }
    let windows = WindowSlot.assign(slots, from: candidates, preferring: inPlace ?? [])
    // Slots that mean the same, counted together: `Safari | Safari` with one window is short of one.
    var order: [WindowSlot.Owner] = []
    var found: [String: Int] = [:]
    var unfilled: [String: Int] = [:]
    for (slot, got) in zip(slots, windows) {
      let key: String
      switch slot.owner {
      case .app(let name): key = "app " + name.lowercased()
      case .window(let id): key = "window \(id.rawValue)"
      }
      if found[key] == nil { order.append(slot.owner) }
      found[key, default: 0] += got.count
      // Taking "all that remain" is content with none, as long as the app has a window somewhere.
      if got.isEmpty, !slot.takesAll { unfilled[key, default: 0] += 1 }
    }
    var missing: [WindowSlot.Owner] = []
    var short: [LayoutNotation.Resolution.Shortfall] = []
    for owner in order {
      switch owner {
      case .app(let name):
        let key = "app " + name.lowercased()
        // What the app has, whoever got it: `412 | Safari` with 412 Safari's only window is short, not missing.
        let has = AppName.windows(of: name, in: candidates).count
        if has == 0 {
          missing.append(owner)
        } else if unfilled[key, default: 0] > 0 || found[key] == 0 {
          short.append(.init(app: name, found: has))
        }
      case .window(let id):
        if found["window \(id.rawValue)"] == 0 { missing.append(owner) }
      }
    }
    return LayoutNotation.Resolution(windows: windows, missing: missing, short: short)
  }

  /// The tree this arrangement makes of `windows`, which lists the windows of each slot in the
  /// order of `slots` (see `resolve`).
  ///
  /// - Slots without windows are closed up: an empty space vanishes, a group left with one member
  ///   becomes that member, and a group inside a group of the same direction joins it, keeping
  ///   its share. So the tree's invariants hold whatever was found.
  /// - If the Desktop is not mentioned it is added at the right, `desktopSize` times as wide as the
  ///   average space beside it.
  /// - A tab group shows the window that comes first in `recent`.
  /// - **Node ids depend only on the text**: each space has the number of its place in the line,
  ///   filled or not. A window that arrives later (`layout --open`) is added by building the tree again,
  ///   and everything that was there keeps its id, so the view, its history and saved views hold.
  public func tree(
    filling windows: [[WindowID]], recent: [WindowID] = [], desktopSize: Double = 0.5
  ) -> LayoutTree {
    var builder = TreeBuilder(windows: windows)
    let built = builder.build(root)
    // Taken whether or not it is used, so that the numbers do not depend on what was found.
    let wrapperID = builder.takeID()
    // As in `LayoutTree.grid`: the number comes from settings.json, where it can be anything.
    let desktopSize = desktopSize.isNaN ? 0.5 : min(max(desktopSize, 0.05), 20)
    var desktop = TreeBuilder.Part(id: TreeBuilder.desktopID, weight: desktopSize, kind: .desktop)
    let whole: TreeBuilder.Part
    if var top = built, !mentionsDesktop {
      if case .split(.horizontal, let parts) = top.kind {
        desktop.weight *= parts.reduce(0) { $0 + $1.weight } / Double(parts.count)
        top.kind = .split(.horizontal, parts + [desktop])
        whole = top
      } else {
        top.weight = 1
        whole = TreeBuilder.Part(id: wrapperID, weight: 1, kind: .split(.horizontal, [top, desktop]))
      }
    } else {
      whole = built ?? desktop
    }
    var rank: [WindowID: Int] = [:]
    for (index, window) in recent.enumerated() where rank[window] == nil { rank[window] = index }
    var nodes: [NodeID: LayoutTree.Node] = [:]
    func emit(_ part: TreeBuilder.Part, parent: NodeID?) {
      let kind: LayoutTree.Kind
      switch part.kind {
      case .desktop:
        kind = .desktop
      case .stack(let windows):
        let shown = windows.indices.min { rank[windows[$0], default: .max] < rank[windows[$1], default: .max] }
        kind = .stack(windows: windows, active: shown ?? 0)
      case .split(let axis, let parts):
        kind = .split(axis: axis, children: parts.map(\.id))
        // Groups that joined their parent can leave shares far too small to lay out or to drag.
        let floor = parts.reduce(0) { max($0, $1.weight) } * 1e-6
        for var child in parts {
          child.weight = max(child.weight, floor)
          emit(child, parent: part.id)
        }
      }
      nodes[part.id] = LayoutTree.Node(id: part.id, parent: parent, kind: kind, weight: part.weight)
    }
    emit(whole, parent: nil)
    return LayoutTree(assembled: nodes, root: whole.id, desktop: TreeBuilder.desktopID, nextRawID: builder.takeID().rawValue)
  }

  /// Reads `tree` back. `slot` says how to write each window.
  ///
  /// Sizes are written relative to the smallest window or group of each group, to three decimals, so
  /// `Safari:2 | Mail | Desktop:0.5` comes back as it was typed and a gap dragged by hand becomes `:1.373`.
  public init(_ tree: LayoutTree, slot: (WindowID) -> WindowSlot) {
    func space(_ id: NodeID, size: Double) -> LayoutNotation.Space? {
      switch tree[id]?.kind {
      case nil:
        return nil
      case .desktop:
        return LayoutNotation.Space(.desktop, size: size)
      case .stack(let windows, _):
        return LayoutNotation.Space(.windows(windows.map(slot)), size: size)
      case .split(let axis, let children):
        let weights = children.filter { $0 != tree.desktop }.compactMap { tree[$0]?.weight }
        let unit = weights.min() ?? 1
        let members = children.compactMap { child -> LayoutNotation.Space? in
          let ratio = (tree[child]?.weight ?? unit) / unit
          return space(child, size: ratio.isFinite && ratio > 0 ? ratio : 1)
        }
        return LayoutNotation.Space(.group(axis, members), size: size)
      }
    }
    self.init(root: space(tree.root, size: 1) ?? LayoutNotation.Space(.desktop))
  }
}

extension LayoutTree {
  /// For the nodes of this tree, the node of `other` that holds the same: the same docked windows, and the Desktop or not.
  /// Everything stands for everything. A node whose windows are no longer together has no entry.
  public func counterparts(in other: LayoutTree) -> [NodeID: NodeID] {
    struct Content: Hashable {
      var windows: Set<WindowID>
      var desktop: Bool
    }
    func content(of id: NodeID, in tree: LayoutTree) -> Content {
      Content(windows: Set(tree.windows(under: id)), desktop: tree.subtree(id, contains: tree.desktop))
    }
    var there: [Content: NodeID] = [:]
    for id in other.preorder() { there[content(of: id, in: other)] = id }
    var result: [NodeID: NodeID] = [:]
    for id in preorder() { result[id] = there[content(of: id, in: self)] }
    result[root] = other.root
    return result
  }

  /// The tree as a line of text, e.g. `Safari | (Mail / Notes) | Desktop:0.5`. `names` gives each
  /// window's app.
  public func notation(names: (WindowID) -> String) -> String {
    LayoutNotation.Spec(self) { .app(names($0)) }.text
  }
}

/// The first half of `Spec.tree`: which spaces are left when the empty ones are closed up.
private struct TreeBuilder {
  struct Part {
    enum Kind {
      case desktop
      case stack([WindowID])
      case split(Axis, [Part])
    }
    var id: NodeID
    var weight: Double
    var kind: Kind
  }

  /// The id `LayoutTree()` gives it.
  static let desktopID = NodeID(0)

  let windows: [[WindowID]]
  private var nextSlot = 0
  private var nextID = 1
  private var placed = Set<WindowID>()

  init(windows: [[WindowID]]) { self.windows = windows }

  mutating func takeID() -> NodeID {
    defer { nextID += 1 }
    return NodeID(nextID)
  }

  mutating func build(_ space: LayoutNotation.Space) -> Part? {
    let id = takeID()
    switch space.kind {
    case .desktop:
      return Part(id: Self.desktopID, weight: space.size, kind: .desktop)
    case .windows(let slots):
      var found: [WindowID] = []
      for _ in slots {
        // Whatever the caller lists, a window is docked once and a slot that is not listed is empty.
        if nextSlot < windows.count { found += windows[nextSlot].filter { placed.insert($0).inserted } }
        nextSlot += 1
      }
      return found.isEmpty ? nil : Part(id: id, weight: space.size, kind: .stack(found))
    case .group(let axis, let members):
      var parts: [Part] = []
      for member in members {
        guard let part = build(member) else { continue }
        guard case .split(let inner, let grandchildren) = part.kind, inner == axis else {
          parts.append(part)
          continue
        }
        let total = grandchildren.reduce(0) { $0 + $1.weight }
        parts += grandchildren.map { Part(id: $0.id, weight: $0.weight / total * part.weight, kind: $0.kind) }
      }
      guard parts.count > 1 else {
        return parts.first.map { Part(id: $0.id, weight: space.size, kind: $0.kind) }
      }
      return Part(id: id, weight: space.size, kind: .split(axis, parts))
    }
  }
}
