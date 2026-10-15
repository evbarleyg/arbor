import CoreGraphics

/// Everything Arbor remembers about one display: its tree, where the camera
/// is, the back/forward history, saved views, and the floating windows that
/// live on its Desktop.
public struct Workspace: Codable, Sendable, Equatable {
  public var tree: LayoutTree
  public private(set) var camera: NodeID
  public private(set) var back: [NodeID] = []
  public private(set) var forward: [NodeID] = []
  /// Saved camera positions keyed by slot ("1"…"9").
  public private(set) var savedViews: [String: NodeID] = [:]
  /// Floating windows and the frame each was last placed at by the user.
  public var floating: [WindowID: CGRect] = [:] {
    // Only a floating window can be pinned or a guest: however one stops floating here, that goes with it.
    didSet {
      if pinned != nil { setPins(pinned?.filter { floating[$0] != nil }) }
      if guests != nil { dropGuestsThatLeft() }
      followSummonedWindows()
    }
  }
  /// Floating windows that stay in view wherever the camera goes (see "Pins" below). Nil when there
  /// are none, as in files written before pins existed.
  public private(set) var pinned: Set<WindowID>?
  /// Floating windows that belong to a space instead of the Desktop: they opened over it while it was framed, and
  /// go out of view and come back with it (F57). Keyed by window; the value is the space, their host.
  /// Nil when there are none, and in files written before this existed.
  public private(set) var guests: [WindowID: NodeID]?
  /// Docked windows and the frame each floated at before it was docked, so that it can have that
  /// size back (Workspace+UndockedFrames.swift). Optional, and nil rather than empty, so that
  /// files saved before this existed load and compare equal.
  public internal(set) var undockedFrames: [WindowID: CGRect]?
  /// The floating window that `summon` has brought over the view (see "Summoning" below).
  public private(set) var summoned: Summon?
  /// Floating windows that were summoned and sent away again. They stay out of view whatever the
  /// camera shows, the Desktop included, until they are summoned again. Nil when there are none.
  public private(set) var stashed: Set<WindowID>?
  /// Where each app's window was the last time it was summoned here, by `Summon.app`.
  public private(set) var summonFrames: [String: CGRect]?
  /// The names given to spaces, as typed. No two are alike and no space has two: change them only
  /// through `setName` and `removeName` (Workspace+Names.swift).
  public internal(set) var names: [String: NodeID] = [:]
  /// True while the Desktop is a tile because Arbor took room from it for a docked window (F61), not because
  /// somebody wanted it narrow. Nil otherwise, and in files written before this existed.
  public var desktopIsOwedRoom: Bool?

  public static let historyLimit = 50

  public init(tree: LayoutTree = LayoutTree()) {
    self.tree = tree
    self.camera = tree.root
  }

  // MARK: Membership

  public func isDocked(_ window: WindowID) -> Bool { tree.leaf(containing: window) != nil }
  public func isFloating(_ window: WindowID) -> Bool { floating[window] != nil }
  public func contains(_ window: WindowID) -> Bool { isDocked(window) || isFloating(window) }

  /// Every window this workspace manages, docked first (tree order), then floating.
  public var allWindows: [WindowID] { tree.allWindows + floating.keys.sorted() }

  // MARK: Camera

  /// Moves the camera, recording the old position for Back unless `record` is false.
  public mutating func moveCamera(to node: NodeID, record: Bool = true) {
    let node = tree.contains(node) ? node : tree.root
    guard node != camera else { return }
    if record {
      back.append(camera)
      if back.count > Self.historyLimit { back.removeFirst(back.count - Self.historyLimit) }
      forward.removeAll()
    }
    camera = node
    tidyHistory()
  }

  /// Puts the camera and what Back and Forward held back as they were, for whoever moved the camera only to look (a peek).
  /// An unrecorded move is not enough for that: a look at the view that Back leads to makes history repeat the camera, and
  /// the entry is tidied away. Spaces that have gone meanwhile are left out.
  public mutating func returnFromALook(to node: NodeID, back earlier: [NodeID], forward later: [NodeID]) {
    camera = tree.contains(node) ? node : tree.root
    back = earlier.filter(tree.contains)
    forward = later.filter(tree.contains)
    tidyHistory()
  }

  /// Steps back to the most recent camera position that still exists. Returns false if none.
  public mutating func goBack() -> Bool {
    while let previous = back.popLast() {
      guard tree.contains(previous), previous != camera else { continue }
      forward.append(camera)
      camera = previous
      tidyHistory()
      return true
    }
    return false
  }

  public mutating func goForward() -> Bool {
    while let next = forward.popLast() {
      guard tree.contains(next), next != camera else { continue }
      back.append(camera)
      camera = next
      tidyHistory()
      return true
    }
    return false
  }

  /// Takes the last recorded move back as if it had never been made: unlike `goBack`, it leaves nothing to
  /// go forward to. Returns false if there is none.
  public mutating func retractLastMove() -> Bool {
    while let previous = back.popLast() {
      guard tree.contains(previous) else { continue }
      camera = previous
      tidyHistory()
      return true
    }
    return false
  }

  /// Nothing here is out of view any more, whatever the view was, as after `home`: the camera goes to the root, with the old
  /// view one step back, and a window that `summon` had sent away is an ordinary floating window. The arrangement, the saved
  /// views, the names and what Back led to stay. As after any move of the view, there is nothing to go forward to.
  public mutating func showEverything() {
    moveCamera(to: tree.root)
    forgetSummons()
  }

  public mutating func saveView(slot: Int) { savedViews[String(slot)] = camera }

  public func savedView(slot: Int) -> NodeID? {
    guard let node = savedViews[String(slot)], tree.contains(node) else { return nil }
    return node
  }

  // MARK: Docking

  /// Removes `window` from the tree and from floating, fixing up references. Here and below,
  /// `shareSpace` says who gets a docked window's space (`LayoutTree.remove`).
  public mutating func forget(_ window: WindowID, shareSpace: Bool = true) {
    floating[window] = nil
    endVisit(of: window)
    changeStructure { $0.remove(window, shareSpace: shareSpace) }
    setUndockedFrame(nil, of: window)
  }

  /// Undocks `window` and makes it float at `frame`.
  public mutating func undock(_ window: WindowID, floatingAt frame: CGRect, shareSpace: Bool = true) {
    changeStructure { $0.remove(window, shareSpace: shareSpace) }
    floating[window] = frame
    setUndockedFrame(nil, of: window)
  }

  /// Docks `window` according to `target`, removing it from wherever it was in
  /// this workspace first. Returns false for `.float` and `.none`, which do
  /// not dock. `evenShare` is `LayoutTree.dock`'s, for `.beside`.
  @discardableResult
  public mutating func dock(
    _ window: WindowID, at target: DropTarget, evenShare: Bool = false, shareSpace: Bool = true
  ) -> Bool {
    tryDock(window, at: target, evenShare: evenShare, shareSpace: shareSpace) == .docked
  }

  /// What became of a dock. Anything but `docked` has changed nothing.
  public enum DockOutcome: Equatable, Sendable {
    case docked
    /// The target was `.float` or `.none`.
    case notADock
    /// The window is the only thing in view, and the target an edge of the view.
    case nothingToDockBeside
    /// The arrangement would nest deeper than `LayoutTree.maximumDepth`, which is as deep as a file may
    /// be: it would not come back after a restart.
    case tooDeep
  }

  /// `dock`, saying why not.
  public mutating func tryDock(
    _ window: WindowID, at target: DropTarget, evenShare: Bool = false, shareSpace: Bool = true
  ) -> DockOutcome {
    switch target {
    case .float, .none:
      return .notADock
    case .cameraEdge:
      guard tree.windows(under: camera) != [window] || tree.subtree(camera, contains: tree.desktop) else {
        return .nothingToDockBeside
      }
    case .beside, .stack:
      break
    }
    // On a copy, because how deep it ends up depends on what taking the window out collapses first.
    var trial = self
    trial.place(window, at: target, evenShare: evenShare, shareSpace: shareSpace)
    guard trial.tree.nesting <= LayoutTree.maximumDepth else { return .tooDeep }
    self = trial
    return .docked
  }

  /// What `tryDock` would answer, for whoever has something to do first that a refusal must not follow.
  public func wouldDock(_ window: WindowID, at target: DropTarget) -> DockOutcome {
    var copy = self
    return copy.tryDock(window, at: target)
  }

  private mutating func place(_ window: WindowID, at target: DropTarget, evenShare: Bool, shareSpace: Bool) {
    // History and saved views that frame this window on its own should still frame it where it
    // lands, not whatever closes over the slot it leaves.
    let ownLeaf = tree.leaf(containing: window).flatMap { tree.windows(under: $0) == [window] ? $0 : nil }
    let ownNames = takeNames(ofSpacesHoldingOnly: window)
    // Removing the window can delete or merge nodes the target refers to. A group it refers to is
    // kept until the window has landed, so that "beside that group" still means that group.
    switch target {
    case .beside(let node, _), .stack(let node): keepWhatIsViewed(and: [node])
    case .cameraEdge, .float, .none: keepWhatIsViewed()
    }
    // Down to one window as well, until this one has landed: it may be on its way back in.
    let held = tree.kept(for: .view)
    for group in held { tree.keep(group, for: .move) }
    defer {
      for group in held { apply(tree.stopKeeping(group, for: .move)) }
      keepWhatIsViewed(done: true)
    }
    let remap = tree.remove(window, shareSpace: shareSpace)
    apply(remap, except: ownLeaf)
    // A docked window that is only moving is not in `floating`, and keeps what is remembered.
    if let frame = floating.removeValue(forKey: window) { setUndockedFrame(frame, of: window) }
    endVisit(of: window)

    let leaf: NodeID
    switch target {
    case .cameraEdge(let edge):
      // Beside everything in view (T01) and nothing else: as a group with it, which the view then is on.
      leaf = tree.dock(window, beside: camera, edge: edge, groupingFor: .view)
    case .beside(let node, let edge):
      leaf = tree.dock(window, beside: remap.resolve(node, in: tree), edge: edge, evenShare: evenShare)
    case .stack(let node):
      let stack = remap.resolve(node, in: tree)
      if tree.isStack(stack) {
        tree.addToStack(window, leaf: stack)
        leaf = stack
      } else {
        leaf = tree.dock(window, beside: stack, edge: .right)
      }
    case .float, .none:
      return
    }
    if let ownLeaf {
      back = Self.dedupe(back.map { $0 == ownLeaf ? leaf : $0 })
      forward = Self.dedupe(forward.map { $0 == ownLeaf ? leaf : $0 })
      savedViews = savedViews.mapValues { $0 == ownLeaf ? leaf : $0 }
      guests = guests?.mapValues { $0 == ownLeaf ? leaf : $0 }
    }
    give(ownNames, to: leaf)
    // Docking can wrap the camera node in a new split (for example the very
    // first dock wraps the Desktop). Widen the camera so the docked window
    // is in view.
    if !tree.subtree(camera, contains: leaf) {
      let viewed = camera
      camera = Navigation.commonAncestor(camera, leaf, in: tree)
      if case .cameraEdge = target { moveName(from: viewed, to: camera) }
    }
    tidyHistory()
  }

  /// Replaces the tree, resetting the camera to the root and clearing history. Floating windows
  /// that the new tree docks stop floating.
  public mutating func reset(tree newTree: LayoutTree) {
    tree = newTree
    camera = newTree.root
    back.removeAll()
    forward.removeAll()
    savedViews.removeAll()
    guests = nil
    stopFloatingDockedWindows()
    names.removeAll()
  }

  /// Runs a change to the tree's structure, which returns where references to deleted nodes should
  /// point. Every change that can delete, collapse or merge a node belongs in here: the groups
  /// the view and the saved views are on, and `others` (what the change is aimed at), stay whole
  /// while it runs, and camera, history and saved views follow the remap.
  public mutating func changeStructure(
    keeping others: Set<NodeID> = [], _ change: (inout LayoutTree) -> Remap
  ) {
    keepWhatIsViewed(and: others)
    apply(change(&tree))
    keepWhatIsViewed(done: true)
  }

  /// Marks the groups the view and the saved views are on, and those that have guest windows (F57),
  /// as kept (LayoutTree+Keeps.swift), and lets go of those they have left. Called before and after (`done`) every change of structure,
  /// and not when the view moves: letting go can dissolve a group, which shifts its neighbours by
  /// a gap's width, and that belongs with a change the person made to the arrangement. Between
  /// changes only the marks that make a difference stay in the tree. History does not keep
  /// anything: a place visited long ago must not decide how a drag or a resize behaves today.
  private mutating func keepWhatIsViewed(and others: Set<NodeID> = [], done: Bool = false) {
    let viewed = others.union(savedViews.values).union((guests ?? [:]).values).union([camera])
    apply(tree.keep(exactly: viewed, for: .view))
    if done { tree.stopKeepingWhereItChangesNothing(for: [.view, .turned]) }
  }

  /// Replaces the tree and shows everything, like `reset(tree:)`, but keeps the saved views and the history that
  /// `counterparts` can carry over (from a node of the old tree to the node of the new one that stands for it).
  /// Where the view was is the last entry of the history, so `back` returns there.
  public mutating func reset(tree newTree: LayoutTree, carrying counterparts: [NodeID: NodeID]) {
    let (views, history) = (savedViews, back + [camera])
    reset(tree: newTree)
    savedViews = views.compactMapValues { counterparts[$0] }.filter { newTree.contains($0.value) }
    back = Self.dedupe(history.compactMap { counterparts[$0] }.filter(newTree.contains))
    while back.last == camera { back.removeLast() }
  }

  /// Replaces the tree by one that has the same spaces under the same ids and more windows, leaving the view where
  /// it is. Floating windows that the new tree docks stop floating, and where they floated is remembered.
  ///
  /// Much of a workspace lives half in the tree and half beside it: a group is kept because a view is on it or because
  /// it has a name, and the mark is in the tree. A tree made afresh has no marks, so they are worked out again here.
  public mutating func grow(into newTree: LayoutTree) {
    tree = newTree
    // Nothing was removed; this only sends what pointed at a node that is gone to the root.
    apply(Remap())
    stopFloatingDockedWindows()
    keepWhatIsNamed()
    changeStructure { _ in Remap() }
  }

  /// Points the camera, history and saved views at surviving nodes.
  public mutating func apply(_ remap: Remap) { apply(remap, except: nil) }

  /// History and saved views on `kept` are left pointing at it although it is gone; the caller
  /// points them somewhere else.
  private mutating func apply(_ remap: Remap, except kept: NodeID?) {
    func resolve(_ id: NodeID) -> NodeID { id == kept ? id : remap.resolve(id, in: tree) }
    camera = remap.resolve(camera, in: tree)
    back = back.map(resolve)
    forward = forward.map(resolve)
    tidyHistory()
    savedViews = savedViews.mapValues(resolve)
    follow(remap)
    // A group left with one member hands it its guests, as it does its saved views. A guest whose host is gone
    // with all it held is an ordinary floating window.
    let remaining = tree
    guests = guests?.compactMapValues { $0 == kept ? $0 : remap.survivor(of: $0, in: remaining) }
    if guests?.isEmpty == true { guests = nil }
  }

  // MARK: Guests

  /// Makes the floating window `window` a guest of `host`.
  public mutating func receive(_ window: WindowID, asGuestOf host: NodeID) {
    guard isFloating(window), tree.contains(host) else { return }
    guests = (guests ?? [:]).merging([window: host]) { _, new in new }
  }

  public mutating func endVisit(of window: WindowID) { keepGuests { guest, _ in guest != window } }

  /// Drops guests that no longer float here (`floating` can be changed directly).
  public mutating func dropGuestsThatLeft() {
    let here = floating
    keepGuests { guest, _ in here[guest] != nil }
  }

  private mutating func keepGuests(where keep: (WindowID, NodeID) -> Bool) {
    guard let kept = guests?.filter({ keep($0.key, $0.value) }) else { return }
    guests = kept.isEmpty ? nil : kept
  }

  /// History is a list of places. The view can come to be where a list ends without being moved there
  /// (a dock widens it, a remap carries it), and two places can become one. So after every change
  /// to the view or to history: no place twice in a row, and neither list ends where the view is,
  /// which Back and Forward would only skip.
  private mutating func tidyHistory() {
    back = Self.dedupe(back)
    forward = Self.dedupe(forward)
    while back.last == camera { back.removeLast() }
    while forward.last == camera { forward.removeLast() }
  }

  private static func dedupe(_ ids: [NodeID]) -> [NodeID] {
    var result: [NodeID] = []
    for id in ids where result.last != id { result.append(id) }
    return result
  }

  // MARK: Codable

  // Every stored property needs a case here and a line in `init(from:)`, or it is silently not saved.
  private enum CodingKeys: String, CodingKey {
    case tree, camera, back, forward, savedViews, floating, guests, pinned, undockedFrames
    case summoned, stashed, summonFrames, names
    case desktopIsOwedRoom
  }

  /// A floating frame further out or larger than this is not believed. It is far beyond any
  /// arrangement of displays, and small enough that sums of coordinates stay exact.
  static let farthestFloatingCoordinate: CGFloat = 1_000_000

  /// Reads a workspace from `state.json`, which can be hand-edited, old or damaged. Only the tree
  /// is required (and repairs itself, see LayoutTree+Decoding.swift). Everything that refers to
  /// it is checked against it: a camera that points nowhere goes to the root, history and saved
  /// views that point nowhere are dropped, as are guests, pins and summons, a window that is both docked and floating
  /// is docked,
  /// and a floating frame that is not a sensible rectangle is dropped, which leaves the window for the
  /// controller to find where it really is. Repairs are noted in the decoder's `DecodingNotes`.
  public init(from decoder: any Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    // What a person could tell, and what they could not (`DecodingNotes`).
    var notes: [String] = []
    var tidied: [String] = []
    /// A key that is missing or cannot be read takes `fallback`.
    func read<T: Decodable>(_ key: CodingKeys, or fallback: T) -> T {
      do {
        return try c.decodeIfPresent(T.self, forKey: key) ?? fallback
      } catch {
        notes.append("`\(key.stringValue)` could not be read")
        return fallback
      }
    }
    let tree = try c.decode(LayoutTree.self, forKey: .tree)
    self.tree = tree

    camera = read(.camera, or: tree.root)
    if !tree.contains(camera) {
      notes.append("the camera was on \(camera), which does not exist")
      camera = tree.root
    }
    func history(_ key: CodingKeys) -> [NodeID] {
      let saved = read(key, or: [NodeID]())
      let known = Self.dedupe(saved.filter(tree.contains)).suffix(Self.historyLimit)
      let dropped = saved.count - known.count
      if dropped > 0 { tidied.append("dropped \(dropped) entries of `\(key.stringValue)`") }
      return Array(known)
    }
    back = history(.back)
    forward = history(.forward)
    let listed = back.count + forward.count
    tidyHistory()
    if back.count + forward.count < listed { tidied.append("history ended where the view is") }

    let views = read(.savedViews, or: [String: NodeID]())
    savedViews = views.filter { slot, node in tree.contains(node) && Int(slot).map((1...9).contains) == true }
    for slot in views.keys.sorted() where savedViews[slot] == nil {
      notes.append(
        tree.contains(views[slot]!)
          ? "`\(slot)` is not a slot for a saved view" : "saved view \(slot) was of \(views[slot]!), which does not exist")
    }

    names = Self.readable(read(.names, or: [String: Lenient<NodeID>]()), in: tree, notes: &notes)

    // At least a point each way, as `undockedFrame(of:)` asks: half a point passes for a size until the window is
    // placed, which rounds it to nothing, or docked, which remembers it; and that is saved, and refused the next time.
    let limit = Self.farthestFloatingCoordinate
    let docked = Set(tree.allWindows)
    let saved = read(.floating, or: LossyDictionary<WindowID, CGRect>()).entries
    for (window, frame) in saved.sorted(by: { $0.key < $1.key }) {
      let numbers = [frame.origin.x, frame.origin.y, frame.size.width, frame.size.height]
      if docked.contains(window) {
        tidied.append("\(window) was both docked and floating")
      } else if !numbers.allSatisfy({ abs($0) <= limit }) || frame.size.width < 1 || frame.size.height < 1 {
        notes.append("\(window) had a floating frame that is not a rectangle on any display")
      } else {
        floating[window] = frame
      }
    }

    let visitors = read(.guests, or: LossyDictionary<WindowID, NodeID>()).entries
    let staying = visitors.filter { floating[$0.key] != nil && tree.contains($0.value) }
    if staying.count < visitors.count {
      tidied.append("dropped guests that do not float here or whose host does not exist")
    }
    guests = staying.isEmpty ? nil : staying

    let pins = read(.pinned, or: Set<WindowID>())
    let kept = pins.filter { floating[$0] != nil }
    if kept.count < pins.count { tidied.append("dropped pins of windows that do not float here") }
    pinned = kept.isEmpty ? nil : kept

    // `undockedFrame(of:)` says what is believed: a frame a window could take, of a window that is docked.
    let before = read(.undockedFrames, or: LossyDictionary<WindowID, CGRect>()).entries
    undockedFrames = before
    let remembered = before.filter { window, _ in undockedFrame(of: window) != nil }
    undockedFrames = remembered.isEmpty ? nil : remembered
    if remembered.count < before.count {
      tidied.append("frames were remembered for windows that are not docked, or were impossible")
    }

    // A floating window has one role at most. A stashed window stays out of view, so when in doubt it is not stashed.
    let summon = read(.summoned, or: Summon?.none)
    summoned = summon.flatMap { floating[$0.window] != nil && !kept.contains($0.window) ? $0 : nil }
    if summon != nil, summoned == nil { tidied.append("the summoned window does not float here, or is pinned") }
    let away = read(.stashed, or: Set<WindowID>())
    let stillAway = away.filter { floating[$0] != nil && !kept.contains($0) && $0 != summoned?.window }
    if stillAway.count < away.count { tidied.append("dropped stashed windows that do not float here or have another role") }
    stashed = stillAway.isEmpty ? nil : stillAway
    let places = read(.summonFrames, or: LossyDictionary<String, CGRect>()).entries
    let believed = places.filter { _, frame in
      [frame.origin.x, frame.origin.y, frame.size.width, frame.size.height].allSatisfy { abs($0) <= limit }
        && frame.size.width >= 1 && frame.size.height >= 1
    }
    if believed.count < places.count { tidied.append("dropped places of summoned windows that are not rectangles on any display") }
    summonFrames = believed.isEmpty ? nil : believed
    desktopIsOwedRoom = read(.desktopIsOwedRoom, or: false) ? true : nil
    // The table decides which groups are kept for a name, so that it and the tree cannot disagree.
    apply(self.tree.keep(exactly: Set(names.values), for: .name))
    (decoder.userInfo[DecodingNotes.key] as? DecodingNotes)?.add(notes, tidied: tidied, at: decoder.codingPath)
  }

  // MARK: Preview

  /// Where `window` would land if dropped on `target`, found by trying the
  /// drop on a copy and laying it out.
  public func previewFrame(
    for window: WindowID, at target: DropTarget, in frame: CGRect, options: LayoutOptions,
    isPresent: @escaping (WindowID) -> Bool, minimumSize: @escaping (WindowID) -> CGSize? = { _ in nil },
    makingRoom terms: MakeRoom.Terms? = nil
  ) -> CGRect? {
    var copy = self
    guard copy.dock(window, at: target, shareSpace: options.shareRemovedSpace) else { return nil }
    var layout = LayoutEngine.layout(
      copy.tree, camera: copy.camera, in: frame, options: options,
      isPresent: { $0 == window || isPresent($0) }, minimumSize: minimumSize)
    // The drop will make room (F61), so the preview does.
    if let terms, !layout.tiles.isEmpty || copy.tree.hasLoans {
      layout =
        MakeRoom.serve(
          &copy.tree, camera: copy.camera, in: frame, options: options,
          isPresent: { $0 == window || isPresent($0) }, minimumSize: minimumSize, terms: terms
        ).layout
    }
    if let placed = layout.windowFrames[window] { return placed }
    return layout.tiles.first(where: { $0.windows.contains(window) })?.frame
  }
}

// MARK: Pins

extension Workspace {
  /// Whether `window` floats here and stays in view wherever the camera goes.
  public func isPinned(_ window: WindowID) -> Bool { pinned?.contains(window) == true && isFloating(window) }

  public var pinnedWindows: [WindowID] { (pinned ?? []).filter(isFloating).sorted() }

  /// Pins a window that floats here. Returns false, changing nothing, for any other window.
  @discardableResult
  public mutating func pin(_ window: WindowID) -> Bool {
    guard isFloating(window) else { return false }
    // It belongs to the display now, not to the space it opened over.
    endVisit(of: window)
    forgetSummon(of: window)
    setPins((pinned ?? []).union([window]))
    return true
  }

  public mutating func unpin(_ window: WindowID) { setPins(pinned?.subtracting([window])) }

  /// No pins is always nil, so that pinning and unpinning leaves a workspace equal to what it was.
  private mutating func setPins(_ pins: Set<WindowID>?) { pinned = pins?.isEmpty == false ? pins : nil }
}

// MARK: Summoning

/// A window brought over the view for a moment, and the app it belongs to.
public struct Summon: Codable, Sendable, Equatable {
  public var window: WindowID
  /// What `Workspace.summonFrames` files the window's frame under: its bundle id, or its app's name
  /// if it has none.
  public var app: String

  public init(window: WindowID, app: String) {
    self.window = window
    self.app = app
  }
}

/// What is remembered about a floating window besides its frame. It goes along when the window
/// moves to another display's workspace.
public enum FloatingRole: Equatable, Sendable {
  case pinned
  case summoned(app: String)
  case stashed
}

extension Workspace {
  public func isSummoned(_ window: WindowID) -> Bool { summoned?.window == window && isFloating(window) }
  public func isStashed(_ window: WindowID) -> Bool { stashed?.contains(window) == true && isFloating(window) }
  /// Pinned or summoned: it keeps its place on the display whatever the camera shows.
  public func staysInView(_ window: WindowID) -> Bool { isPinned(window) || isSummoned(window) }

  public var stashedWindows: [WindowID] { (stashed ?? []).filter(isFloating).sorted() }

  /// Makes `window` the summoned window, floating at `frame`, whatever it was here before. The window
  /// that was summoned until now is stashed, and returned so that the caller can move it out of view.
  @discardableResult
  public mutating func summon(_ window: WindowID, app: String, at frame: CGRect) -> WindowID? {
    let previous = summoned?.window == window ? nil : dismissSummon()
    if isDocked(window) { apply(tree.remove(window)) }
    unpin(window)
    endVisit(of: window)
    setStash(stashed?.subtracting([window]))
    summoned = Summon(window: window, app: app)
    floating[window] = frame
    return previous
  }

  /// Ends the summon: the window is stashed. Returns it, or nil if none was summoned.
  @discardableResult
  public mutating func dismissSummon() -> WindowID? {
    guard let window = summoned?.window else { return nil }
    summoned = nil
    guard isFloating(window) else { return nil }
    setStash((stashed ?? []).union([window]))
    return window
  }

  /// Makes `window` an ordinary floating window again. Where it was summoned is still remembered.
  public mutating func forgetSummon(of window: WindowID) {
    if summoned?.window == window { summoned = nil }
    setStash(stashed?.subtracting([window]))
  }

  /// Makes every summoned or stashed window an ordinary floating window again. Returns them.
  @discardableResult
  public mutating func forgetSummons() -> [WindowID] {
    let windows = (stashedWindows + [summoned?.window].compactMap { $0 }).sorted()
    summoned = nil
    stashed = nil
    return windows
  }

  public func role(of window: WindowID) -> FloatingRole? {
    if isPinned(window) { return .pinned }
    if isSummoned(window), let app = summoned?.app { return .summoned(app: app) }
    return isStashed(window) ? .stashed : nil
  }

  /// Gives a window that floats here the role it had on the display it came from. There is one
  /// summoned window at a time: if there is one here already, the newcomer is stashed.
  public mutating func setRole(_ role: FloatingRole?, of window: WindowID) {
    guard let frame = floating[window] else { return }
    unpin(window)
    forgetSummon(of: window)
    switch role {
    case .pinned: pin(window)
    case .summoned(let app) where summoned == nil: summon(window, app: app, at: frame)
    case .summoned, .stashed:
      endVisit(of: window)
      setStash((stashed ?? []).union([window]))
    case nil: break
    }
  }

  /// The display this workspace belongs to has another place among the displays. Every frame remembered here is in
  /// global coordinates, so all of them go with it, as the windows themselves do: macOS moves those without a word.
  public mutating func shift(by offset: CGPoint) {
    guard offset != .zero else { return }
    func moved(_ frame: CGRect) -> CGRect { frame.offsetBy(dx: offset.x, dy: offset.y) }
    // First, or `floating`'s observer would take the summoned window's new frame for a place it was moved to.
    summonFrames = summonFrames?.mapValues(moved)
    floating = floating.mapValues(moved)
    undockedFrames = undockedFrames?.mapValues(moved)
  }

  /// Called whenever `floating` changes: a window that stops floating here is neither summoned nor
  /// stashed any more, and where the summoned window is now is where it will be summoned next time.
  fileprivate mutating func followSummonedWindows() {
    if stashed != nil { setStash(stashed?.filter { floating[$0] != nil }) }
    guard let summon = summoned else { return }
    if let frame = floating[summon.window] {
      if summonFrames?[summon.app] != frame { summonFrames = (summonFrames ?? [:]).merging([summon.app: frame]) { $1 } }
    } else {
      summoned = nil
    }
  }

  private mutating func setStash(_ windows: Set<WindowID>?) { stashed = windows?.isEmpty == false ? windows : nil }
}

// MARK: Undo

extension Workspace {
  /// Whether both arrange the same windows the same way: the same tree (whichever tabs are
  /// showing) and the same windows floating (wherever they float). Where the camera is, its
  /// history, the saved views, the names of spaces, who is a guest of what and who is pinned, summoned or stashed do not count.
  /// Only a change to the arrangement is an undo step.
  public func hasSameArrangement(as other: Workspace) -> Bool {
    tree.hasSameArrangement(as: other.tree) && floating.count == other.floating.count
      && floating.keys.allSatisfy { other.floating[$0] != nil }
  }

  /// This workspace, saved before a change, made ready to replace `current` when the change is
  /// undone. `reference` is the workspace as the change left it.
  ///
  /// Undo takes back the arrangement, not what the user has done since that is no arrangement.
  /// Whatever differs between `reference` and `current` was done since, and is carried over as far
  /// as it still makes sense in the restored tree:
  /// - the camera stays where it was moved to, and history keeps the places that still exist;
  /// - views saved since are kept if their node still exists, and so are names given since; names taken off since stay off;
  /// - floating windows moved since stay where they were put;
  /// - windows that became guests since stay guests if their host still exists, and visits that ended stay over;
  /// - windows pinned since stay pinned while they float, and pins taken away stay away; the same goes for the summoned
  ///   window and the stashed ones, and for where each app was last summoned;
  /// - a floating window moved since, which the undo docks again, is remembered where it was moved to;
  /// - stacks keep showing the tab switched to since.
  ///
  /// With nothing done since, the result is exactly this workspace, camera and history included:
  /// a change can move the camera itself (floating the framed window does), and that is undone with it.
  ///
  /// **Every stored property of `Workspace` is dealt with in here**, and a test reads this function to see that
  /// it is (`UndoHistoryTests`). The rule for a new one is in docs/ARCHITECTURE.md, "Undo and redo".
  public func restored(over current: Workspace, since reference: Workspace) -> Workspace {
    var result = self
    func survives(_ node: NodeID) -> Bool { current.tree.isSameNode(node, in: tree) }

    if current.camera != reference.camera || current.back != reference.back || current.forward != reference.forward {
      if survives(current.camera) { result.camera = current.camera }
      result.back = Self.dedupe(current.back.filter(survives))
      result.forward = Self.dedupe(current.forward.filter(survives))
    }
    for (slot, node) in current.savedViews where reference.savedViews[slot] != node && survives(node) {
      result.savedViews[slot] = node
    }
    // Names (F20) taken off since stay off; names given, moved or changed since are kept if their space survives.
    for name in SpaceName.sorted(reference.names.keys) where current.node(named: name) == nil {
      if let node = result.node(named: name) { result.removeName(of: node) }
    }
    for name in SpaceName.sorted(current.names.keys) {
      guard let node = current.names[name], reference.names[name] != node, survives(node) else { continue }
      _ = try? result.setName(name, of: node)
    }
    for (window, frame) in current.floating where result.floating[window] != nil {
      if let left = reference.floating[window], left != frame { result.floating[window] = frame }
    }
    var visits = guests ?? [:]
    for (window, host) in current.guests ?? [:] where reference.guests?[window] != host && survives(host) {
      visits[window] = host
    }
    for window in (reference.guests ?? [:]).keys where current.guests?[window] == nil { visits[window] = nil }
    result.guests = visits
    let (floats, nodes) = (result.floating, result.tree)
    result.keepGuests { window, host in floats[window] != nil && nodes.contains(host) }
    let (pinnedNow, pinnedThen) = (current.pinned ?? [], reference.pinned ?? [])
    let pins = (pinned ?? []).union(pinnedNow.subtracting(pinnedThen)).subtracting(pinnedThen.subtracting(pinnedNow))
    result.setPins(pins.filter { floats[$0] != nil })
    // Summoning (F53). A floating window has one role at most, and when in doubt it is not stashed: a stashed window
    // stays out of view whatever the camera shows.
    if current.summoned != reference.summoned { result.summoned = current.summoned }
    if let window = result.summoned?.window, floats[window] == nil || result.isPinned(window) { result.summoned = nil }
    let (stashedNow, stashedThen) = (current.stashed ?? [], reference.stashed ?? [])
    let stash = (stashed ?? []).union(stashedNow.subtracting(stashedThen)).subtracting(stashedThen.subtracting(stashedNow))
    result.setStash(stash.filter { floats[$0] != nil && !result.isPinned($0) && result.summoned?.window != $0 })
    var places = summonFrames ?? [:]
    for (app, frame) in current.summonFrames ?? [:] where reference.summonFrames?[app] != frame { places[app] = frame }
    result.summonFrames = places.isEmpty ? nil : places
    // `undockedFrames` (F48) follows from the arrangement: it changes only when a window is docked or undocked, so what was
    // remembered then is right again. But a window that floats now, and that the user has moved since, is docked
    // again from where it is now.
    for (window, frame) in current.floating where result.isDocked(window) {
      if let left = reference.floating[window], left != frame { result.setUndockedFrame(frame, of: window) }
    }
    // `desktopIsOwedRoom` (F61) follows from the arrangement: it says how the gaps of this very tree came about, so it comes
    // back with them. Every layout looks at it afresh.
    for leaf in tree.preorder() {
      guard case .stack(let windows, _) = tree[leaf]?.kind, windows.count > 1, survives(leaf),
        let showing = current.tree.activeWindow(of: leaf), showing != reference.tree.activeWindow(of: leaf),
        windows.contains(showing)
      else { continue }
      result.tree.activate(showing)
    }
    // The view can have gone back to where it was while the history is today's, which may end there.
    result.tidyHistory()
    return result
  }

  /// `old` has become `new`: the same window under another number (a saved slot was taken by the window it
  /// waited for, a native tab came to the front). For workspaces kept from the past, which must go on
  /// meaning the same windows. If `new` had a place of its own, it loses that.
  public mutating func renumber(_ old: WindowID, as new: WindowID) {
    guard old != new, contains(old) else { return }
    if contains(new) { forget(new) }
    if isDocked(old) {
      replaceWindow(old, with: new)
    } else {
      let (role, host) = (role(of: old), guests?[old])
      floating[new] = floating.removeValue(forKey: old)
      if let host { receive(new, asGuestOf: host) }
      if role != nil { setRole(role, of: new) }
    }
  }
}
