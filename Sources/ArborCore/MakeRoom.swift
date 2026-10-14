import CoreGraphics

/// Room before tiles (F61).
///
/// A window whose slot is smaller than the window will go becomes a tile. Often there is room right beside it:
/// the Desktop keeps a share of its own between docked windows, so on a laptop's display a third of the width is all a
/// window gets, and most apps will not go that narrow. A person would drag the gap. This does it for them:
/// it moves weight to the window's slot from whoever in view can spare it, once, as if the gaps had been dragged.
///
/// The weights change, not the layout: a layout stays a pure function of the tree, and a gap still follows the
/// pointer, because frames stay proportional to weights (`Seam.pointsPerWeight`).
public enum MakeRoom {
  /// On what terms room is made.
  public struct Terms: Equatable, Sendable {
    /// A window floats on the Desktop. Docked windows come first all the same: somebody has asked for each of them, and
    /// nobody for the Desktop's points, so it gives down to a tile either way, and what floats on it then shows over the
    /// arrangement. In use it is the first to be served from what can be spared, and gets more of it: see `desktopWish`.
    public var desktopIsInUse: Bool
    /// The window that has the keyboard. It is served before anybody else, so it is the last to be a tile: a person who types
    /// into a window that nobody can see has lost it. The window, not its slot: whoever rehearses a dock (a drop's preview) does
    /// so on a copy of the tree, and the slot of the window in the hand is one that only the copy has.
    public var keyboard: WindowID?
    /// Slots that stay as they are: the person squeezed them by hand.
    public var leaving: Set<NodeID>
    /// The Desktop is a tile because room was taken from it, not because somebody wanted it narrow. Then it is served
    /// too, from what others can spare by now: last of all while it is empty, first of all with a window floating on it.
    public var desktopIsOwed: Bool
    /// For an empty Desktop only windows whose minimum is known give. What the others can spare could only be found out
    /// by asking them, and an empty Desktop is no reason to.
    public var emptyDesktopAsksNobody: Bool
    /// As wide as the widest and as tall as the tallest window that floats on the Desktop. A Desktop in use that is owed room
    /// gets more than the smallest usable size if its neighbours can spare it: up to this, and to an even share.
    public var desktopWish: CGSize
    /// Whether what was taken for a window goes back where the window can spare it by now. (What goes back for the sake of the window
    /// with the keyboard does so either way: there is no occasion on which that one may be the tile.)
    public var givesBack = true

    public init(
      desktopIsInUse: Bool, keyboard: WindowID? = nil, leaving: Set<NodeID> = [], desktopIsOwed: Bool = false, emptyDesktopAsksNobody: Bool = false,
      desktopWish: CGSize = .zero
    ) {
      self.desktopIsInUse = desktopIsInUse
      self.keyboard = keyboard
      self.leaving = leaving
      self.desktopIsOwed = desktopIsOwed
      self.emptyDesktopAsksNobody = emptyDesktopAsksNobody
      self.desktopWish = desktopWish
    }
  }

  /// A slot in view that is a tile for want of room.
  public struct Short: Equatable, Sendable {
    public var node: NodeID
    /// The window that would show in it; nil for the Desktop.
    public var window: WindowID?
    /// What it takes for it not to be a tile.
    public var minimum: CGSize
  }

  /// Lays out `tree` and, for every window that is a tile although its minimum size is known, tries to make room.
  /// Returns the slots room was made for, and the layout of the tree as it is now.
  ///
  /// When there is not enough for all, the window with the keyboard comes first, then the one that was given its place last:
  /// node ids only grow. So the outcome depends on the arrangement and on where the person is, not on what came before.
  ///
  /// Nobody in view pays with their place, for a window or for the Desktop: room is what others can spare. But for the window with
  /// the keyboard: for its sake what was lent to the others in view goes back, which can cost them theirs.
  public static func serve(
    _ tree: inout LayoutTree, camera: NodeID, in frame: CGRect, options: LayoutOptions,
    isPresent: @escaping (WindowID) -> Bool, minimumSize: @escaping (WindowID) -> CGSize?, terms: Terms
  ) -> (served: [Short], layout: Layout, gaveBack: Bool) {
    func layOut(_ tree: LayoutTree) -> Layout {
      LayoutEngine.layout(
        tree, camera: camera, in: frame, options: options, isPresent: isPresent, minimumSize: minimumSize)
    }
    var layout = layOut(tree)
    var gaveBack = false
    var hadDesktop = false
    let desktopIsInUse = terms.desktopIsInUse
    // Making room moves weights and no window.
    let keyboard = terms.keyboard.flatMap { tree.leaf(containing: $0) }
    var served: [Short] = []
    var tried = terms.leaving

    /// The tree and its layout with `slot` grown to what it needs, or nil. To that and no more: in a slot a point larger a
    /// window that stopped at its minimum would be near enough for `apply`, and one that came from elsewhere would
    /// fill it, so that where a window is would depend on how it got there. On a copy, one axis after the other: half
    /// a solution helps nobody, so it is all or nothing. Nobody in view pays with their place.
    ///
    /// Tiles give too, at first only what leaves them large enough for a window: whatever is docked beside a tile later
    /// shares its row or column. Only if that is not enough do they go as far as a tile goes.
    ///
    /// From the tree as it is, or from `start`.
    func grown(_ slot: Short, from start: (tree: LayoutTree, layout: Layout)? = nil) -> (tree: LayoutTree, layout: Layout)? {
      let start = start ?? (tree, layout)
      return grown(slot, from: start, tilesKeep: options.minimumUsableSize) ?? grown(slot, from: start, tilesKeep: tileFloor)
    }
    func grown(
      _ slot: Short, from start: (tree: LayoutTree, layout: Layout), tilesKeep: CGSize
    ) -> (tree: LayoutTree, layout: Layout)? {
      var (copy, after) = start
      for axis in [Axis.horizontal, .vertical] {
        let giver = Giver(
          view: TreeView(tree: copy, isPresent: isPresent), layout: after, axis: axis, options: options,
          minimumSize: minimumSize, tilesKeep: tilesKeep,
          strangersGive: slot.window != nil || desktopIsInUse || !terms.emptyDesktopAsksNobody)
        let needed = length(slot.minimum, axis)
        var wished = needed
        if slot.window == nil, desktopIsInUse, let even = giver.evenShare(of: slot.node) {
          wished = max(needed, min(even, length(terms.desktopWish, axis)))
        }
        guard let shares = giver.shares(growing: slot.node, to: wished, atLeast: needed) else { return nil }
        guard !shares.isEmpty else { continue }
        // With `shareRemovedSpace` off a weight covers a slot and the gap after it (`LayoutEngine.keptExtents`).
        let withEach = options.shareRemovedSpace ? 0 : Double(options.gap)
        for share in shares {
          copy.setShares(share.mapValues { $0 + withEach }, for: slot.window == nil ? nil : slot.node)
        }
        after = layOut(copy)
      }
      guard slot.window.map({ after.windowFrames[$0] != nil }) ?? (after.desktopFrame != nil),
        start.layout.windowFrames.keys.allSatisfy({ after.windowFrames[$0] != nil })
      else { return nil }
      return (copy, after)
    }

    /// The tree and its layout with what was lent to the neighbours of `slot` given back, whether or not they can spare it, or nil if
    /// there is nothing of the kind. Like `giveBackWhatCanBeSpared` only in a row that is in view as a whole, and of those only in the
    /// rows and columns that `slot` is in: elsewhere it could not help, and would only decide anew who shows there.
    ///
    /// The ledger can say more than is true by now (a window docked beside a borrower has taken half of its slot, lent room and all). So
    /// nobody is left with less than a tile, and what cannot go back stays owed. A slot that the person squeezed stays as it is.
    func withWhatWasLentToTheOthersBack(for slot: NodeID) -> (tree: LayoutTree, layout: Layout)? {
      var rows: Set<NodeID> = []
      var current = slot
      while current != layout.camera, let parent = tree.parent(of: current) {
        rows.insert(parent)
        current = parent
      }
      let view = TreeView(tree: tree, isPresent: isPresent)
      // With `shareRemovedSpace` off a weight covers a slot and the gap after it (`LayoutEngine.keptExtents`).
      let withEach = options.shareRemovedSpace ? 0 : options.gap
      var copy = tree
      var changed = false
      for index in tree.loans.indices.reversed() {
        let loan = tree.loans[index]
        guard loan.borrower != slot, terms.leaving.isDisjoint(with: [loan.borrower, loan.receiver]),
          let row = tree.parent(of: loan.receiver), row == tree.parent(of: loan.giver), rows.contains(row),
          case .split(let axis, _) = tree[row]?.kind
        else { continue }
        let children = view.effectiveChildren(of: row)
        let lengths = children.compactMap { layout.nodeFrames[$0]?.length(along: axis) }
        guard children.contains(loan.giver), children.contains(loan.receiver), lengths.count == children.count else { continue }
        let points = lengths.reduce(0) { $0 + $1 + withEach }
        let weight = children.reduce(0) { $0 + (tree[$1]?.weight ?? 0) }
        guard points > 0, weight > 0, let has = copy[loan.receiver]?.weight else { continue }
        // The receiver can be a group, which shrinks in proportion: as far as the one in it with the least to lose allows.
        let giver = Giver(
          view: view, layout: layout, axis: axis, options: options, minimumSize: minimumSize, tilesKeep: tileFloor,
          strangersGive: true, windowsGiveLikeTiles: true)
        let floor = Double(giver.floor(of: loan.receiver) + withEach) * weight / Double(points)
        guard has > floor else { continue }
        copy.repay(min(loan.weight, has - floor), ofLoanAt: index)
        changed = true
      }
      guard changed else { return nil }
      copy.dropSettledLoans()
      return (copy, layOut(copy))
    }

    // Boundaries are whole points, so what has just been served can have a point to spare. Round again until nothing moves,
    // so that another layout finds nothing to do.
    for _ in 0..<3 {
      let back =
        terms.givesBack
        && giveBackWhatCanBeSpared(&tree, &layout, options: options, isPresent: isPresent, minimumSize: minimumSize, layOut)
      gaveBack = gaveBack || back
      hadDesktop = hadDesktop || layout.desktopFrame != nil
      let servedBefore = served.count
      tried = terms.leaving
      serveAll()
      if !back, served.count == servedBefore { break }
    }
    return (served, layout, gaveBack)

    func serveAll() {
    while true {
      let view = TreeView(tree: tree, isPresent: isPresent)
      // A Desktop that has just given so much that it is a tile is owed at once: the others top it up if they can.
      let desktopIsOwed = terms.desktopIsOwed || (hadDesktop && layout.desktopFrame == nil)
      let short = shortSlots(in: layout, view: view, options: options, minimumSize: minimumSize)
        .filter { !tried.contains($0.node) && ($0.window != nil || desktopIsOwed) }
      func turn(_ slot: Short) -> (Int, Int) {
        if slot.node == keyboard { return (-1, 0) }
        return slot.window == nil ? (desktopIsInUse ? 0 : 2, 0) : (1, -slot.node.rawValue)
      }
      guard let next = short.min(by: { turn($0) < turn($1) }) else { break }
      tried.insert(next.node)

      var result = grown(next)
      if result == nil, next.node == keyboard {
        // The one exception to "nobody pays with their place": whoever types into a window that nobody can see has lost it.
        // What was lent to the others goes back, the window with the keyboard is served, and then the others, from what is left.
        result = withWhatWasLentToTheOthersBack(for: next.node).flatMap { grown(next, from: $0) }
      }
      guard let result else { continue }
      (tree, layout) = result
      served.append(next)
      // What was out of reach may be within it now: a column widened for one window is wider for all in it.
      tried = terms.leaving
    }
    }
  }

  /// What was taken for a window goes back as soon as the window can spare it: its neighbour has closed, the display is
  /// larger. So the arrangement stays what the person made it, plus the least that the windows in it need. Only
  /// windows whose minimum is known give back: what the others can spare could only be found out by asking them.
  private static func giveBackWhatCanBeSpared(
    _ tree: inout LayoutTree, _ layout: inout Layout, options: LayoutOptions, isPresent: @escaping (WindowID) -> Bool,
    minimumSize: @escaping (WindowID) -> CGSize?, _ layOut: (LayoutTree) -> Layout
  ) -> Bool {
    // (With `shareRemovedSpace` off a weight covers a slot and the gap after it, which the sums below do not know. There room
    // goes back when the window leaves, and not before.)
    guard tree.hasLoans, options.shareRemovedSpace else { return false }
    var changed = false
    for axis in [Axis.horizontal, .vertical] {
      var moved = false
      // The newest first: what was taken last goes back first.
      for index in tree.loans.indices.reversed() {
        let loan = tree.loans[index]
        // Only in a row that is in view as a whole. Framed on its own a window has the whole display, which says nothing about
        // what it can spare beside the others.
        guard let parent = tree.parent(of: loan.receiver), parent == tree.parent(of: loan.giver),
          case .split(axis, _) = tree[parent]?.kind, layout.nodeFrames[parent] != nil
        else { continue }
        let view = TreeView(tree: tree, isPresent: isPresent)
        let giver = Giver(
          view: view, layout: layout, axis: axis, options: options, minimumSize: minimumSize,
          tilesKeep: options.minimumUsableSize, strangersGive: false)
        let row = view.effectiveChildren(of: parent)
        guard row.contains(loan.giver), row.contains(loan.receiver), let length = giver.length(of: loan.receiver) else { continue }
        let points = row.compactMap(giver.length(of:)).reduce(0, +)
        let weight = row.reduce(0) { $0 + (tree[$1]?.weight ?? 0) }
        guard points > 0, weight > 0 else { continue }
        let spare = length - giver.floor(of: loan.receiver)
        var copy = tree
        if spare >= CGFloat(loan.weight) * points / CGFloat(weight) {
          copy.repay(loan.weight, ofLoanAt: index)
        } else {
          // In whole points: less than one moves nothing that anybody could see.
          guard spare >= 1 else { continue }
          copy.repay(Double(spare.rounded(.down)) * weight / Double(points), ofLoanAt: index)
        }
        // Nobody pays with their place for this either, nor does the Desktop, which may be in the group that shrinks.
        let after = layOut(copy)
        guard layout.windowFrames.keys.allSatisfy({ after.windowFrames[$0] != nil }),
          layout.desktopFrame == nil || after.desktopFrame != nil
        else { continue }
        (tree, layout) = (copy, after)
        moved = true
      }
      if moved { changed = true }
    }
    tree.dropSettledLoans()
    return changed
  }

  /// The least a tile is left with, the empty Desktop's too: as far as a gap can be dragged (`LayoutTree.moveBoundary`).
  public static let tileFloor = CGSize(width: 80, height: 80)

  /// The windows in view that are tiles although Arbor knows what they need, and the Desktop if it is a tile.
  public static func shortSlots(
    in layout: Layout, view: TreeView, options: LayoutOptions, minimumSize: (WindowID) -> CGSize?
  ) -> [Short] {
    let usable = options.minimumUsableSize
    return layout.tiles.compactMap { tile in
      if tile.kind == .desktop { return Short(node: tile.node, window: nil, minimum: usable) }
      guard tile.kind == .window, let window = view.visibleWindow(of: tile.node), let minimum = minimumSize(window)
      else { return nil }
      return Short(
        node: tile.node, window: window,
        minimum: CGSize(width: max(minimum.width, usable.width), height: max(minimum.height, usable.height)))
    }
  }

  static func length(_ size: CGSize, _ axis: Axis) -> CGFloat { axis == .horizontal ? size.width : size.height }

  /// Works out, along one axis, who gives how much.
  private struct Giver {
    let view: TreeView
    let layout: Layout
    let axis: Axis
    let options: LayoutOptions
    let minimumSize: (WindowID) -> CGSize?
    /// The least a window's tile is left with.
    let tilesKeep: CGSize
    /// Whether windows whose minimum is not known give, down to the smallest usable size.
    let strangersGive: Bool
    /// Whether a window in view gives as far as its tile would, which costs it its place.
    var windowsGiveLikeTiles = false

    func length(of node: NodeID) -> CGFloat? { layout.nodeFrames[node]?.length(along: axis) }

    /// What each would have if the nearest row (or column) along the axis that `leaf` is in were shared out evenly.
    func evenShare(of leaf: NodeID) -> CGFloat? {
      var current = leaf
      while current != layout.camera, let parent = view.tree.parent(of: current) {
        if case .split(let direction, _) = view.tree[parent]?.kind, direction == axis {
          let lengths = view.effectiveChildren(of: parent).compactMap(length(of:))
          if lengths.count > 1 { return lengths.reduce(0, +) / CGFloat(lengths.count) }
        }
        current = parent
      }
      return nil
    }

    /// The new lengths of the children of every row (or column) that has to change for `leaf` to be `needed` long:
    /// none if it is long enough already, nil if what can be spared is not enough for it to be `atLeast` that long.
    func shares(growing leaf: NodeID, to needed: CGFloat, atLeast: CGFloat) -> [[NodeID: Double]]? {
      guard let now = length(of: leaf) else { return nil }
      var missing = needed - now
      guard missing > 0 else { return [] }

      // The rows along this axis between the leaf and the edge of the view, nearest first.
      var levels: [(branch: NodeID, lengths: [NodeID: CGFloat])] = []
      var current = leaf
      while current != layout.camera, let parent = view.tree.parent(of: current) {
        if case .split(let direction, _) = view.tree[parent]?.kind, direction == axis {
          let children = view.effectiveChildren(of: parent)
          if children.count > 1 {
            var lengths: [NodeID: CGFloat] = [:]
            for child in children {
              guard let length = length(of: child) else { return nil }
              lengths[child] = length
            }
            guard lengths[current] != nil else { return nil }
            levels.append((current, lengths))
          }
        }
        current = parent
      }

      for index in levels.indices where missing > 0 {
        let branch = levels[index].branch
        var spare: [NodeID: CGFloat] = [:]
        for (sibling, length) in levels[index].lengths where sibling != branch {
          spare[sibling] = max(length - floor(of: sibling), 0)
        }
        var taken: CGFloat = 0
        // The Desktop first: nobody is looking at the part of it that goes.
        if let desktop = spare.removeValue(forKey: view.tree.desktop) {
          taken = min(missing, desktop)
          levels[index].lengths[view.tree.desktop]! -= taken
        }
        let others = spare.keys.sorted()
        let total = others.reduce(0) { $0 + spare[$1]! }
        if missing > taken, total > 0 {
          let share = min(missing - taken, total)
          for sibling in others { levels[index].lengths[sibling]! -= share * spare[sibling]! / total }
          taken += share
        }
        // What a row gains goes to the leaf alone: in the rows below, its neighbours keep their lengths.
        for lower in 0...index { levels[lower].lengths[levels[lower].branch]! += taken }
        missing -= taken
      }
      guard needed - missing > atLeast - 0.01 else { return nil }
      return levels.map { level in level.lengths.mapValues { Double($0) } }
    }

    /// The least `node` can be along the axis without anything in it losing its place. A row shrinks in proportion, so
    /// it can shrink only as far as the child with the least to spare allows.
    func floor(of node: NodeID) -> CGFloat {
      guard let kind = view.tree[node]?.kind, let length = length(of: node) else { return .infinity }
      // The Desktop gives down to its floor whether or not that has made a tile of it already.
      if case .desktop = kind { return min(length, MakeRoom.length(tileFloor, axis)) }
      // A window that is a tile has no place to lose, so it gives as far as a tile goes. A group's tile is left as it is.
      if let tile = layout.tiles.first(where: { $0.node == node }) {
        return tile.kind == .window ? min(length, MakeRoom.length(tilesKeep, axis)) : length
      }
      switch kind {
      case .desktop:
        return length
      case .stack:
        if windowsGiveLikeTiles { return min(length, MakeRoom.length(tilesKeep, axis)) }
        guard let learned = view.visibleWindow(of: node).flatMap(minimumSize).map({ MakeRoom.length($0, axis) }) else {
          return strangersGive ? min(length, MakeRoom.length(options.minimumUsableSize, axis)) : length
        }
        return min(length, max(learned, MakeRoom.length(options.minimumUsableSize, axis)))
      case .split(let direction, _):
        let children = view.effectiveChildren(of: node)
        if children.count == 1 { return floor(of: children[0]) }
        if direction != axis { return min(length, children.map(floor(of:)).max() ?? length) }
        var inside: CGFloat = 0
        var factor: CGFloat = 0
        for child in children {
          guard let childLength = self.length(of: child), childLength > 0 else { return length }
          inside += childLength
          factor = max(factor, floor(of: child) / childLength)
        }
        return (length - inside) + inside * min(factor, 1)
      }
    }
  }
}
