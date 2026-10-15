import CoreGraphics

/// Room before tiles (F61).
///
/// A window whose slot is smaller than the window will go becomes a tile. Often there is room right beside it:
/// the Desktop keeps a share of its own between docked windows, so on a laptop's display a third of the width is all a
/// window gets, and most apps will not go that narrow. A person would drag the gap. This does it for them:
/// it moves weight to the window's slot from whoever in view can spare it, once, as if the gaps had been dragged.
/// For the window with the keyboard the neighbours give more than they can spare: see `serve`.
///
/// The weights change, not the layout: a layout stays a pure function of the tree, and a gap still follows the
/// pointer, because frames stay proportional to weights (`Seam.pointsPerWeight`).
///
/// With `LayoutOptions.overlaps` a window that is short of room hangs over its place instead of being a tile. Whatever is said
/// of a window's tile here goes for it too: it is served in the same order, on the same terms, and gives as a tile gives. One thing
/// is added: see `serve`.
public enum MakeRoom {
  /// On what terms room is made.
  public struct Terms: Equatable, Sendable {
    /// A window floats on the Desktop. Docked windows come first all the same: somebody has asked for each of them, and
    /// nobody for the Desktop's points, so it gives down to a tile either way, and what floats on it then shows over the
    /// arrangement. In use it is the first to be served from what can be spared, and gets more of it: see `desktopWish`.
    public var desktopIsInUse: Bool
    /// The window that has the keyboard. It is served before anybody else, so it is the last to be a tile: a person
    /// who types into a window that nobody can see has lost it. The window, not its slot: whoever rehearses a dock (a
    /// drop's preview) does so on a copy of the tree, and the slot of the window in the hand is one that only the
    /// copy has.
    public var keyboard: WindowID?
    /// Slots that stay as they are: the person squeezed them by hand. They are not served, and while they are tiles pay nothing back.
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
    /// Whether what was taken for a window goes back where the window can spare it by now. (What goes back for the
    /// sake of the window with the keyboard goes by `neighboursPay` alone.)
    public var givesBack = true
    /// Whether the neighbours of the window with the keyboard pay for it with their places: what was lent to them goes
    /// back, and they lend. Only at a layout that follows a person's act: what nobody asked for sends nothing away
    /// (`Controller.roomTerms`). It is still served first from what can be spared.
    public var neighboursPay = true

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
  /// node ids only grow. (Whoever is in view keeps their place while nobody has a better claim, so who else shows
  /// beside the window with the keyboard still depends on who had it before.)
  ///
  /// Nobody in view pays with their place, for a window or for the Desktop: room is what others can spare. But for
  /// the window with the keyboard: for its sake what was lent to the others in view goes back, and if it takes that
  /// they lend what they need themselves.
  ///
  /// With `LayoutOptions.overlaps` that exception does not hold: the window with the keyboard is in view, and in front, however short its place, and a
  /// change of focus moves nothing. It is served first and takes nothing from anybody who fits. For the rest, where this gives everybody what they
  /// need the gaps are the ones it gives with tiles. Where it leaves somebody hanging over, the room is shared out `forTheLeastOverlap` instead.
  public static func serve(
    _ tree: inout LayoutTree, camera: NodeID, in frame: CGRect, options: LayoutOptions,
    isPresent: @escaping (WindowID) -> Bool, minimumSize: @escaping (WindowID) -> CGSize?, terms: Terms
  ) -> (served: [Short], layout: Layout, gaveBack: Bool) {
    var copy = tree
    let result = serve(
      &copy, camera: camera, in: frame, options: options, isPresent: isPresent, minimumSize: minimumSize, terms: terms, forTheLeastOverlap: false)
    if result.layout.tightPlaces.isEmpty {
      tree = copy
      return result
    }
    return serve(
      &tree, camera: camera, in: frame, options: options, isPresent: isPresent, minimumSize: minimumSize, terms: terms, forTheLeastOverlap: true)
  }

  /// - Parameter forTheLeastOverlap: there is not room for all, and whoever is short hangs over its place. For a tile half a solution helps
  ///   nobody; for a window that hangs over, every point it gets is a point less of its neighbour covered. So:
  ///   - whoever is still short when all have been served takes what those who fit have above an even share of their row, the Desktop first
  ///     and all of it, and keeps it (`grownAsFarAsItGoes`);
  ///   - whoever took what was left over, and that is less than it needs, has an even share first (`shareWhereTooLittleWasLeft`);
  ///   - the Desktop is not served: docked windows come first, and what it got they would take back at once;
  ///   So the gaps come to rest: another layout, for whatever reason and whoever has the keyboard by then, moves none.
  private static func serve(
    _ tree: inout LayoutTree, camera: NodeID, in frame: CGRect, options: LayoutOptions,
    isPresent: @escaping (WindowID) -> Bool, minimumSize: @escaping (WindowID) -> CGSize?, terms: Terms, forTheLeastOverlap: Bool
  ) -> (served: [Short], layout: Layout, gaveBack: Bool) {
    func layOut(_ tree: LayoutTree) -> Layout {
      LayoutEngine.layout(
        tree, camera: camera, in: frame, options: options, isPresent: isPresent, minimumSize: minimumSize)
    }
    var layout = layOut(tree)
    let shared = shareWhereTooLittleWasLeft(
      &tree, laidOutAs: layout, options: options, leaving: terms.leaving, minimumSize: forTheLeastOverlap ? minimumSize : nil)
    if shared { layout = layOut(tree) }
    var gaveBack = shared
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
    /// From the tree as it is, or from `start`. `whateverItCosts`: windows in view give like tiles, and lose their
    /// place by it. `group`: not the slot itself grows but a group that it is in and that is a tile, until it is one
    /// no longer.
    func grown(
      _ slot: Short, group: NodeID? = nil, from start: (tree: LayoutTree, layout: Layout)? = nil,
      whateverItCosts: Bool = false
    ) -> (tree: LayoutTree, layout: Layout)? {
      let start = start ?? (tree, layout)
      return grown(slot, group, from: start, tilesKeep: options.minimumUsableSize, whateverItCosts)
        ?? grown(slot, group, from: start, tilesKeep: tileFloor, whateverItCosts)
    }
    func grown(
      _ slot: Short, _ group: NodeID?, from start: (tree: LayoutTree, layout: Layout), tilesKeep: CGSize,
      _ whateverItCosts: Bool
    ) -> (tree: LayoutTree, layout: Layout)? {
      var (copy, after) = start
      for axis in [Axis.horizontal, .vertical] {
        let giver = Giver(
          view: TreeView(tree: copy, isPresent: isPresent), layout: after, axis: axis, options: options,
          minimumSize: minimumSize, tilesKeep: tilesKeep,
          strangersGive: slot.window != nil || desktopIsInUse || !terms.emptyDesktopAsksNobody,
          windowsGiveLikeTiles: whateverItCosts, tilesOfGroupsGive: whateverItCosts)
        // A group is laid out again at a size at which nothing in it is smaller than a tile goes.
        let needed = max(length(slot.minimum, axis), group.map { giver.leastLaidOut($0) } ?? 0)
        var wished = needed
        if slot.window == nil, desktopIsInUse, let even = giver.evenShare(of: slot.node) {
          wished = max(needed, min(even, length(terms.desktopWish, axis)))
        }
        guard let shares = giver.shares(growing: group ?? slot.node, to: wished, atLeast: needed) else { return nil }
        guard !shares.isEmpty else { continue }
        for share in shares {
          copy.setShares(giver.ownStretches(for: share), for: slot.window == nil ? nil : slot.node)
        }
        after = layOut(copy)
      }
      if let group { return after.tiles.contains { $0.node == group } ? nil : (copy, after) }
      guard slot.window.map({ after.fits($0) }) ?? (after.desktopFrame != nil),
        whateverItCosts || start.layout.windowFrames.keys.allSatisfy({ after.fits($0) || !start.layout.fits($0) })
      else { return nil }
      return (copy, after)
    }

    /// The tree and its layout with `slot`, which cannot have all it needs, grown by what those who fit can spare, or nil if that
    /// is less than a point. Those who are short themselves give nothing: they would only take it back in their turn. **And nobody who fits is
    /// made narrower, or lower, than an even share of its row for one that does not fit anyway**: a terminal goes down to a slit, and whoever
    /// pressed the key for the right half has asked for the half. What it has above that it gives, the Desktop first and all it has. Each way by
    /// itself: too wide whatever is done, it can still be as high as it needs, and that way it has all of it.
    func grownAsFarAsItGoes(_ slot: Short) -> (tree: LayoutTree, layout: Layout)? {
      var (copy, after) = (tree, layout)
      var changed = false
      for axis in [Axis.horizontal, .vertical] {
        func giver(keepsAnEvenShare: Bool) -> Giver {
          Giver(
            view: TreeView(tree: copy, isPresent: isPresent), layout: after, axis: axis, options: options,
            minimumSize: minimumSize, tilesKeep: options.minimumUsableSize, strangersGive: true, theShortGive: false,
            keepsAnEvenShare: keepsAnEvenShare)
        }
        let (freely, sparingly, needed) = (giver(keepsAnEvenShare: false), giver(keepsAnEvenShare: true), length(slot.minimum, axis))
        guard let now = freely.length(of: slot.node) else { continue }
        let all = freely.shares(growing: slot.node, to: needed, atLeast: needed)
        let giver = all == nil ? sparingly : freely
        guard let shares = all ?? sparingly.shares(growing: slot.node, to: needed, atLeast: now + 1), !shares.isEmpty
        else { continue }
        var trial = copy
        for share in shares { trial.setShares(giver.ownStretches(for: share), for: slot.node) }
        let laidOut = layOut(trial)
        guard after.windowFrames.keys.allSatisfy({ laidOut.fits($0) || !after.fits($0) }) else { continue }
        (copy, after, changed) = (trial, laidOut, true)
      }
      return changed ? (copy, after) : nil
    }

    /// `start` with every group that `slot` is in and that is a tile grown, whatever it costs, until it is laid out
    /// again: the outermost first, each to what the window needs, which is the least that any group around it needs.
    /// Nil if that cannot be done.
    func unfolded(_ slot: Short, from start: (tree: LayoutTree, layout: Layout)) -> (tree: LayoutTree, layout: Layout)? {
      var state = start
      while state.layout.nodeFrames[slot.node] == nil {
        guard let group = tileOfTheGroup(around: slot.node, in: state.layout, of: state.tree),
          let next = grown(slot, group: group, from: state, whateverItCosts: true)
        else { return nil }
        state = next
      }
      return state
    }
    /// The window being typed in is short wherever it is a tile for want of room. Also inside the tile of a group: a
    /// row or column that is too small for anything is one tile, and what is in it waits until somebody looks, unless
    /// the person's hand made it so.
    ///
    /// A window that Arbor has never learned anything about is a tile only in a slot too small for any window. It is
    /// left there as ever, unless that is Arbor's doing: it, or a group around it, has lent room. Then it needs the
    /// smallest usable size.
    func slotOfTheKeyboard(in view: TreeView) -> Short? {
      guard terms.neighboursPay, let keyboard, let window = view.visibleWindow(of: keyboard),
        layout.windowFrames[window] == nil
      else { return nil }
      if let group = tileOfTheGroup(around: keyboard, in: layout, of: tree) {
        guard !terms.leaving.contains(group) else { return nil }
      } else if !layout.tiles.contains(where: { $0.node == keyboard }) {
        return nil
      }
      let hasLent = tree.loans.contains { tree.subtree($0.giver, contains: keyboard) }
      guard let minimum = minimumSize(window) ?? (hasLent ? .zero : nil) else { return nil }
      let usable = options.minimumUsableSize
      return Short(
        node: keyboard, window: window,
        minimum: CGSize(width: max(minimum.width, usable.width), height: max(minimum.height, usable.height)))
    }
    func tileOfTheGroup(around node: NodeID, in layout: Layout, of tree: LayoutTree) -> NodeID? {
      layout.tiles.first { $0.kind == .group && tree.subtree($0.node, contains: node) }?.node
    }

    /// The tree and its layout with what was lent to the neighbours of `slot` given back, whether or not they can
    /// spare it, or nil if there is nothing of the kind. Like `giveBackWhatCanBeSpared` only in a row that is in view
    /// as a whole, and of those only in the rows and columns that `slot` is in: elsewhere it could not help, and
    /// would only decide anew who shows there.
    ///
    /// The ledger can say more than is true by now (a window docked beside a borrower has taken half of its slot,
    /// lent room and all). So nobody is left with less than a tile, and what cannot go back stays owed. A slot that
    /// the person squeezed stays as it is.
    ///
    /// `everywhere`: in every row and column in view. A group beside the window shrinks in proportion, so what was
    /// lent inside it decides how far it can shrink.
    func withWhatWasLentToTheOthersBack(
      for slot: NodeID, everywhere: Bool = false
    ) -> (tree: LayoutTree, layout: Layout)? {
      var rows = everywhere ? Set(layout.nodeFrames.keys) : []
      var current = slot
      while current != layout.camera, let parent = tree.parent(of: current) {
        rows.insert(parent)
        current = parent
      }
      // With `shareRemovedSpace` off a weight covers a slot and the gap after it (`LayoutEngine.keptExtents`).
      let withEach = options.shareRemovedSpace ? 0 : options.gap
      // Laid out again after each: what goes back in a column and in the row around it adds up.
      var (copy, now) = (tree, layout)
      var changed = false
      for index in tree.loans.indices.reversed() {
        let loan = tree.loans[index]
        guard loan.borrower != slot, terms.leaving.isDisjoint(with: [loan.borrower, loan.receiver]),
          let row = tree.parent(of: loan.receiver), row == tree.parent(of: loan.giver), rows.contains(row),
          case .split(let axis, _) = tree[row]?.kind
        else { continue }
        let view = TreeView(tree: copy, isPresent: isPresent)
        let children = view.effectiveChildren(of: row)
        let lengths = children.compactMap { now.nodeFrames[$0]?.length(along: axis) }
        guard children.contains(loan.giver), children.contains(loan.receiver), lengths.count == children.count
        else { continue }
        let points = lengths.reduce(0) { $0 + $1 + withEach }
        let weight = children.reduce(0) { $0 + (copy[$1]?.weight ?? 0) }
        guard points > 0, weight > 0, let has = copy[loan.receiver]?.weight else { continue }
        // The receiver can be a group, which shrinks in proportion: as far as the one in it with the least to lose
        // allows.
        let giver = Giver(
          view: view, layout: now, axis: axis, options: options, minimumSize: minimumSize, tilesKeep: tileFloor,
          strangersGive: true, windowsGiveLikeTiles: true)
        let floor = Double(giver.floor(of: loan.receiver) + withEach) * weight / Double(points)
        guard has > floor else { continue }
        copy.repay(min(loan.weight, has - floor), ofLoanAt: index)
        now = layOut(copy)
        changed = true
      }
      guard changed else { return nil }
      copy.dropSettledLoans()
      return (copy, now)
    }

    // Boundaries are whole points, so what has just been served can have a point to spare. Round again until nothing moves,
    // so that another layout finds nothing to do. Three rounds do, but where places have changed hands for the
    // keyboard's sake: then debts can go round in a circle (A owes B, B owes C, C owes A), what one can spare comes
    // back to it, and each lap moves no gap and pays a little of each off, until one is settled and the circle is
    // open.
    for _ in 0..<12 {
      // Where nothing goes back because nothing but an app's own window has moved, whoever has just been served is moving anyway:
      // it gets what it is owed in the same move, and not its bare minimum now and the rest at the next occasion.
      let back =
        (terms.givesBack || !served.isEmpty)
        && giveBackWhatCanBeSpared(
          &tree, &layout, to: terms.givesBack ? nil : Set(served.map(\.node)), options: options, isPresent: isPresent,
          minimumSize: minimumSize, leaving: terms.leaving, theShortKeepWhatTheyHave: forTheLeastOverlap, layOut)
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
      // Only where it has a share of its own: what is left over is owed nothing.
      let desktopIsOwed = options.desktopColumn && (terms.desktopIsOwed || (hadDesktop && layout.desktopFrame == nil))
      var short = shortSlots(in: layout, view: view, options: options, minimumSize: minimumSize)
      if !options.overlaps, let slot = slotOfTheKeyboard(in: view) {
        short.removeAll { $0.node == slot.node }
        short.append(slot)
      }
      short = short.filter { !tried.contains($0.node) && ($0.window != nil || (desktopIsOwed && !forTheLeastOverlap)) }
      func turn(_ slot: Short) -> (Int, Int) {
        if slot.node == keyboard { return (-1, 0) }
        return slot.window == nil ? (desktopIsInUse ? 0 : 2, 0) : (1, -slot.node.rawValue)
      }
      guard let next = short.min(by: { turn($0) < turn($1) }) else { break }
      tried.insert(next.node)

      var result = grown(next)
      if result == nil, next.node == keyboard, terms.neighboursPay, !options.overlaps {
        // The one exception to "nobody pays with their place": whoever types into a window that nobody can see has
        // lost it. What was lent to the others goes back first. If that is not enough they lend what they need
        // themselves: it is written down like any loan, so a gap that a person has put somewhere is back there
        // afterwards. Then the others are served, from what is left.
        func atWhateverCost(from start: (tree: LayoutTree, layout: Layout)) -> (tree: LayoutTree, layout: Layout)? {
          unfolded(next, from: start).flatMap { grown(next, from: $0, whateverItCosts: true) }
        }
        let afresh = withWhatWasLentToTheOthersBack(for: next.node)
        result = afresh.flatMap { grown(next, from: $0) } ?? atWhateverCost(from: afresh ?? (tree, layout))
          ?? withWhatWasLentToTheOthersBack(for: next.node, everywhere: true).flatMap(atWhateverCost)
      }
      guard let result else { continue }
      (tree, layout) = result
      served.append(next)
      // What was out of reach may be within it now: a column widened for one window is wider for all in it.
      tried = terms.leaving
    }
    guard forTheLeastOverlap else { return }
    // All who could have what they need have it. What is left over goes to the others, in the same order.
    let stillShort = shortSlots(
      in: layout, view: TreeView(tree: tree, isPresent: isPresent), options: options, minimumSize: minimumSize
    ).filter { $0.window != nil && !terms.leaving.contains($0.node) }
    for slot in stillShort.sorted(by: { ($0.node == keyboard ? 0 : 1, -$0.node.rawValue) < ($1.node == keyboard ? 0 : 1, -$1.node.rawValue) }) {
      guard let result = grownAsFarAsItGoes(slot) else { continue }
      (tree, layout) = result
      served.append(slot)
    }
    }
  }

  /// Whoever took what was left over (`LayoutTree.dock`) took it however much it was. Too little to show any window in is nothing: then
  /// everybody in the row gives, as with nothing left. This is no making of room, and holds with `makeRoom` off as well. Says whether
  /// the tree has changed, so that `layout` no longer holds.
  ///
  /// `minimumSize`: where not all fit and somebody will hang over whatever is done, too little for the very window that took it is nothing either. It
  /// has an even share then, like the key that docked it says, whoever its neighbour is and whichever of the two came first.
  public static func shareWhereTooLittleWasLeft(
    _ tree: inout LayoutTree, laidOutAs layout: Layout, options: LayoutOptions, leaving: Set<NodeID> = [],
    minimumSize: ((WindowID) -> CGSize?)? = nil
  ) -> Bool {
    guard !options.desktopColumn else { return false }
    var shared = false
    // A window's tile, or the place of one that hangs over it (`LayoutOptions.overlaps`): the arrangement is the same either way.
    let places =
      layout.tiles.filter { $0.kind == .window }.map { (node: $0.node, frame: $0.frame) }
      + layout.tightPlaces.sorted { $0.key < $1.key }.compactMap { window, place in tree.leaf(containing: window).map { (node: $0, frame: place) } }
    for place in places where !leaving.contains(place.node) {
      // Along the row, which is where it took what was left. Across it a share like the others' would be no help.
      let needs = minimumSize.flatMap { known in tree.windows(under: place.node).compactMap(known).first } ?? .zero
      guard let row = tree.parent(of: place.node), case .split(let axis, _) = tree[row]?.kind,
        axis == .horizontal
          ? place.frame.width < max(options.minimumUsableSize.width, needs.width)
          : place.frame.height < max(options.minimumUsableSize.height, needs.height),
        tree.shareWithWhoTookWhatWasLeft(place.node)
      else { continue }
      shared = true
    }
    return shared
  }

  /// What was taken for a window goes back as soon as the window can spare it: its neighbour has closed, the display is
  /// larger. So the arrangement stays what the person made it, plus the least that the windows in it need. Only
  /// windows whose minimum is known give back: what the others can spare could only be found out by asking them.
  /// `to`: only to these, or to everybody.
  private static func giveBackWhatCanBeSpared(
    _ tree: inout LayoutTree, _ layout: inout Layout, to givers: Set<NodeID>?, options: LayoutOptions,
    isPresent: @escaping (WindowID) -> Bool,
    minimumSize: @escaping (WindowID) -> CGSize?, leaving: Set<NodeID>, theShortKeepWhatTheyHave: Bool, _ layOut: (LayoutTree) -> Layout
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
        // A window squeezed into a tile by hand, in height say, could spare as a tile nearly all the width it was lent, or its column
        // was for its sake. But then it would not fit when the same hand lets it out again. (One that is a window again, because
        // a neighbour has left, pays like anybody.)
        guard !layout.tiles.contains(where: { leaving.contains($0.node) && [loan.receiver, loan.borrower].contains($0.node) })
        else { continue }
        // Only in a row that is in view as a whole. Framed on its own a window has the whole display, which says nothing about
        // what it can spare beside the others.
        guard givers?.contains(loan.giver) != false, let parent = tree.parent(of: loan.receiver),
          parent == tree.parent(of: loan.giver), case .split(axis, _) = tree[parent]?.kind, layout.nodeFrames[parent] != nil
        else { continue }
        let view = TreeView(tree: tree, isPresent: isPresent)
        // A window that hangs over can spare nothing: what it gave back it would take again at once.
        let giver = Giver(
          view: view, layout: layout, axis: axis, options: options, minimumSize: minimumSize,
          tilesKeep: options.minimumUsableSize, strangersGive: false, theShortGive: !theShortKeepWhatTheyHave)
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
        guard layout.windowFrames.keys.allSatisfy({ after.fits($0) || !layout.fits($0) }),
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

  /// The windows in view that are tiles, or hang over their places, although Arbor knows what they need, and the Desktop if it
  /// is a tile.
  public static func shortSlots(
    in layout: Layout, view: TreeView, options: LayoutOptions, minimumSize: (WindowID) -> CGSize?
  ) -> [Short] {
    let usable = options.minimumUsableSize
    func short(_ node: NodeID) -> Short? {
      guard let window = view.visibleWindow(of: node), let minimum = minimumSize(window) else { return nil }
      return Short(
        node: node, window: window,
        minimum: CGSize(width: max(minimum.width, usable.width), height: max(minimum.height, usable.height)))
    }
    return layout.tiles.compactMap { tile in
      if tile.kind == .desktop { return Short(node: tile.node, window: nil, minimum: usable) }
      return tile.kind == .window ? short(tile.node) : nil
    } + layout.tightPlaces.keys.sorted().compactMap { view.tree.leaf(containing: $0).flatMap(short) }
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
    /// Whether the tile of a group gives like a window's. It has no place to lose either.
    var tilesOfGroupsGive = false
    /// Whether a window that hangs over its place gives of that as a tile does. Otherwise it keeps what it has.
    var theShortGive = true
    /// Whether a window gives only what it has above an even share of its row. The Desktop gives as ever.
    var keepsAnEvenShare = false

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
        let borrowed = borrowedPoints(among: Array(levels[index].lengths.keys))
        for (sibling, length) in levels[index].lengths where sibling != branch {
          // What it shows of an absent neighbour's place is not its own to give, and of its own it keeps what it would without one: when
          // the neighbour comes back it must not have paid with its place.
          spare[sibling] = max(length - floor(of: sibling) - (borrowed[sibling]?.points ?? 0), 0)
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

    /// With `shareRemovedSpace` off, the place of a sibling that is absent (minimized, hidden, on another Space) stays reserved and
    /// shows as part of the neighbour before it, or of the first in view (`LayoutEngine.keptExtents`). For each of `shown`, the
    /// children in view of one row, that has such a place: how long it is. With it, the gap in that row. Empty with
    /// the switch on, when absent siblings take no room.
    func borrowedPoints(among shown: [NodeID]) -> [NodeID: (points: CGFloat, gap: CGFloat)] {
      guard !options.shareRemovedSpace, let parent = shown.first.flatMap({ view.tree.parent(of: $0) }),
        let seam = layout.seams.first(where: { $0.split == parent })
      else { return [:] }
      let inView = Set(shown)
      var weights: [NodeID: Double] = [:]
      var beforeTheFirst = 0.0
      var last: NodeID?
      for child in view.tree.children(of: parent) {
        if inView.contains(child) {
          weights[child, default: 0] += beforeTheFirst
          beforeTheFirst = 0
          last = child
        } else if let weight = view.tree[child]?.weight {
          if let last { weights[last, default: 0] += weight } else { beforeTheFirst += weight }
        }
      }
      let gap = seam.frame.length(along: axis)
      return weights.mapValues { (CGFloat($0) * seam.pointsPerWeight, gap) }
    }

    /// `lengths`, the lengths wanted for the children in view of one row, as `LayoutTree.setShares` has to be told them. With
    /// `shareRemovedSpace` off a weight covers a slot and the gap after it, and not the reserved places that show as part of it.
    func ownStretches(for lengths: [NodeID: Double]) -> [NodeID: Double] {
      let borrowed = borrowedPoints(among: Array(lengths.keys))
      guard !borrowed.isEmpty else { return lengths }
      return Dictionary(
        uniqueKeysWithValues: lengths.map { node, length in
          (node, length + Double(borrowed[node]?.gap ?? 0) - Double(borrowed[node]?.points ?? 0))
        })
    }

    /// The least `node` can be along the axis with nothing in it smaller than a tile goes, by its weights: it need
    /// not be laid out.
    func leastLaidOut(_ node: NodeID) -> CGFloat {
      let floor = MakeRoom.length(tileFloor, axis)
      guard case .split(let direction, _) = view.tree[node]?.kind else { return floor }
      let children = view.effectiveChildren(of: node)
      guard direction == axis, children.count > 1 else { return children.map(leastLaidOut).max() ?? floor }
      func weight(_ child: NodeID) -> Double { max(view.tree[child]?.weight ?? 0, .leastNonzeroMagnitude) }
      let sum = children.reduce(0) { $0 + weight($1) }
      let inside = children.map { leastLaidOut($0) * CGFloat(sum / weight($0)) }.max() ?? 0
      return inside + options.gap * CGFloat(children.count - 1)
    }

    /// The least `node` can be along the axis without anything in it losing its place. A row shrinks in proportion, so
    /// it can shrink only as far as the child with the least to spare allows.
    func floor(of node: NodeID) -> CGFloat {
      guard let kind = view.tree[node]?.kind, let length = length(of: node) else { return .infinity }
      // The Desktop gives down to its floor whether or not that has made a tile of it already.
      if case .desktop = kind { return min(length, MakeRoom.length(tileFloor, axis)) }
      // A window that is a tile has no place to lose, so it gives as far as a tile goes. A group's tile is left as it is.
      if let tile = layout.tiles.first(where: { $0.node == node }) {
        return tile.kind == .window || tilesOfGroupsGive ? min(length, MakeRoom.length(tilesKeep, axis)) : length
      }
      switch kind {
      case .desktop:
        return length
      case .stack:
        if windowsGiveLikeTiles { return min(length, MakeRoom.length(tilesKeep, axis)) }
        // Nor has one that hangs over, along the side that is too short as it is. Along the other it is a window like any.
        if let over = view.visibleWindow(of: node).flatMap({ layout.overhangs[$0] }), MakeRoom.length(over, axis) > 0 {
          return theShortGive ? min(length, MakeRoom.length(tilesKeep, axis)) : length
        }
        let even = keepsAnEvenShare ? (evenShare(of: node) ?? 0).rounded(.down) : 0
        guard let learned = view.visibleWindow(of: node).flatMap(minimumSize).map({ MakeRoom.length($0, axis) }) else {
          return strangersGive ? min(length, max(even, MakeRoom.length(options.minimumUsableSize, axis))) : length
        }
        return min(length, max(learned, even, MakeRoom.length(options.minimumUsableSize, axis)))
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
