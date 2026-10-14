import ArborCore
import CoreGraphics

/// Rearranging docked windows from the keyboard: `swap`, `equalize`, `rotate`, `mirror`, `grow`, `shrink`
/// and `move-to-display` (docs/features/F22-keyboard-tiling-tools.md).
extension Controller {
  // MARK: swap

  /// Exchanges what the slot of a docked window holds with the nearest slot in `direction`. The
  /// slots keep their sizes, unlike `dock <edge>`, which moves the window and its size along.
  func swap(_ window: WindowID?, toward direction: Edge) -> CommandResult {
    if let refusal = refusalWhileFullScreen() { return refusal }
    let (id, display): (WindowID, DisplayID)
    switch target(window) {
    case .failure(let result): return result
    case .window(let w, let d): (id, display) = (w, d)
    }
    guard var workspace = workspaces[display], let leaf = workspace.tree.leaf(containing: id) else {
      return .failure("\(id) is floating; only docked windows trade places")
    }
    guard let layout = layouts[display], let origin = layout.nodeFrames[leaf] else {
      return .failure("\(id) is out of view")
    }
    guard layout.camera != leaf else { return .failure("\(id) fills the view; step out first") }

    // Every other slot in view. The Desktop is passed over: it holds no window to trade with.
    var candidates: [DirectionalSearch.Candidate<NodeID>] = []
    for other in workspace.tree.windows(under: layout.camera) {
      guard layout.windowFrames[other] != nil, let node = workspace.tree.leaf(containing: other), node != leaf,
        let frame = layout.nodeFrames[node]
      else { continue }
      candidates.append(.init(id: node, frame: frame, recency: focusRecency(of: [other])))
    }
    for tile in layout.tiles where tile.node != leaf && tile.kind != .desktop {
      candidates.append(.init(id: tile.node, frame: tile.frame, recency: focusRecency(of: tile.windows)))
    }
    guard let found = DirectionalSearch.nearest(from: origin, toward: direction, among: candidates) else {
      return .failure("no docked window \(direction.sidePhrase)")
    }
    guard let other = workspace.tree.activeWindow(of: found.id) else {
      return .failure("a group of windows is \(direction.sidePhrase); name one of them: swap \(id.rawValue) <window>")
    }
    // What a tile stands for would come into a held view (F58).
    if holdLevel == .view, isOutOfView(other) { return .failure("\(other) is out of view, and \(heldMessage)") }
    workspace.tree.tradePlaces(of: id, and: other)
    workspaces[display] = workspace
    tradeSqueezes(leaf, found.id, on: display)
    relayout(display, reason: .structure)
    // Focus stays with the window, unless the slot it moved to is too small to show it.
    if frameInView(of: id, on: display) != nil { giveFocus(to: id) } else { ensureFocusIsVisible(on: display) }
    scheduleSave()
    return .success("swapped \(id) with \(other)")
  }

  /// Exchanges what the slots of two docked windows hold, on one display or across two.
  func swap(_ first: WindowID, with second: WindowID) -> CommandResult {
    guard first != second else { return .failure("a window cannot trade places with itself") }
    if let refusal = refusalWhileFullScreen() { return refusal }
    var displayOf: [WindowID: DisplayID] = [:]
    for id in [first, second] {
      switch target(id) {
      case .failure(let result): return result
      case .window(_, let display):
        guard workspaces[display]?.isDocked(id) == true else {
          return .failure("\(id) is floating; only docked windows trade places")
        }
        displayOf[id] = display
      }
    }
    if holdLevel == .view, let hidden = [first, second].first(where: isOutOfView) {
      return .failure("\(hidden) is out of view, and \(heldMessage)")
    }
    guard let a = displayOf[first], let b = displayOf[second], var treeA = workspaces[a]?.tree,
      var treeB = workspaces[b]?.tree
    else { return .failure("no display") }

    if a == b {
      guard treeA.leaf(containing: first) != treeA.leaf(containing: second) else {
        return .failure("\(first) and \(second) are tabs of one tab group")
      }
      treeA.tradePlaces(of: first, and: second)
      workspaces[a]!.tree = treeA
      if let one = treeA.leaf(containing: first), let other = treeA.leaf(containing: second) {
        tradeSqueezes(one, other, on: a)
      }
    } else {
      // Each would come into a view it is no part of (F58).
      guard holdLevel != .view else { return .failure("\(first) and \(second) are on different displays, and \(heldMessage)") }
      // Whatever is out of view must be parked again, on the display it now belongs to.
      let leavingA = treeA.leaf(containing: first).map { treeA.windows(under: $0) } ?? []
      let leavingB = treeB.leaf(containing: second).map { treeB.windows(under: $0) } ?? []
      for window in leavingA + leavingB { parked.remove(window) }
      // The size a window had before it was docked goes along, for the day it floats again (F48).
      func ownFrames(of windows: [WindowID], from source: DisplayID, to destination: DisplayID) -> [WindowID: CGRect] {
        var frames: [WindowID: CGRect] = [:]
        for window in windows { frames[window] = frameAfterTransfer(of: window, from: source, to: destination) }
        return frames
      }
      let (comingToB, comingToA) = (ownFrames(of: leavingA, from: a, to: b), ownFrames(of: leavingB, from: b, to: a))
      // What opened over a window that leaves the display cannot follow it, and has nothing to do with the newcomer.
      for (display, host) in [(a, treeA.leaf(containing: first)), (b, treeB.leaf(containing: second))] {
        for (guest, itsHost) in workspaces[display]?.guests ?? [:] where itsHost == host {
          workspaces[display]!.endVisit(of: guest)
        }
      }
      LayoutTree.swapLeaves(of: first, in: &treeA, and: second, in: &treeB)
      workspaces[a]!.tree = treeA
      workspaces[b]!.tree = treeB
      workspaces[a]!.rememberUndockedFrames(ofArrivals: comingToA)
      workspaces[b]!.rememberUndockedFrames(ofArrivals: comingToB)
    }
    for display in Set([a, b]).sorted() {
      relayout(display, reason: .structure)
      // Only from a window that went out of view: a keyboard that is in a sheet or a panel stays there.
      ensureFocusIsVisible(on: display, alsoFromNothing: false)
    }
    scheduleSave()
    return .success("swapped \(first) with \(second)")
  }

  /// A slot the person squeezed into a tile stays as they left it (F61). That is noted by its leaf, and the leaves have
  /// just traded slots.
  private func tradeSqueezes(_ one: NodeID, _ other: NodeID, on display: DisplayID) {
    guard var squeezed = squeezedByHand[display], squeezed.contains(one) != squeezed.contains(other) else { return }
    squeezed.formSymmetricDifference([one, other])
    squeezedByHand[display] = squeezed
  }

  // MARK: equalize

  /// Equal shares for the children of every split in view, or with `all` on the whole display.
  func equalize(all: Bool) -> CommandResult {
    if let refusal = refusalWhileFullScreen() { return refusal }
    guard let (display, current) = cameraDisplay() else { return .failure("no display") }
    var workspace = current
    let start = all ? workspace.tree.root : workspace.camera
    let splits = workspace.tree.preorder(from: start).filter(workspace.tree.isSplit).count
    guard splits > 0 else {
      return .failure(workspace.tree.allWindows.isEmpty ? "nothing is docked" : "the view holds one space; step out first")
    }
    workspace.tree.equalize(under: start, desktopWeight: settings.arrangeDesktopWeight)
    workspaces[display] = workspace
    // The sizes start afresh, also where a gap was once dragged until a window became a tile (F61).
    forgetSqueezes(on: display)
    relayout(display, reason: .structure)
    // An equal share can be too small for the focused window. A keyboard that is in a sheet or a panel stays there.
    ensureFocusIsVisible(on: display, alsoFromNothing: false)
    scheduleSave()
    return .success("balanced \(Self.count(splits, "group"))")
  }

  /// The arrangement is on another of the macOS Spaces than a full-screen window: a shortcut pressed there would rearrange
  /// what cannot be seen. `target(_:)` says the same for commands that act on the window itself.
  private func refusalWhileFullScreen() -> CommandResult? {
    guard let focused = keyboardFocus(), windows[focused]?.isFullScreen == true else { return nil }
    return .failure("\(focused) is full screen")
  }

  // MARK: rotate and mirror

  enum GroupLookup {
    case group(NodeID, DisplayID)
    case failure(CommandResult)
  }

  /// The split `rotate` and `mirror` act on: the nearest one around the focused window that shows more
  /// than that window, if it is in view; without a docked window in focus, the view itself.
  func focusedGroup() -> GroupLookup {
    if let refusal = refusalWhileFullScreen() { return .failure(refusal) }
    guard let display = keyboardDisplayID, let workspace = workspaces[display], let view = treeView(display) else {
      return .failure(.failure("no display"))
    }
    let tree = workspace.tree
    let camera = view.effectiveAncestor(of: workspace.camera)
    if let focused = keyboardFocus(), windows[focused]?.isPresent == true,
      let leaf = tree.leaf(containing: focused), tree.subtree(camera, contains: leaf)
    {
      guard let group = Navigation.stepOut(from: leaf, in: view), tree.subtree(camera, contains: group) else {
        return .failure(.failure("\(focused) fills the view; step out first"))
      }
      return .group(group, display)
    }
    let shown = view.passThrough(camera)
    guard tree.isSplit(shown) else { return .failure(.failure("the view holds no group of windows")) }
    return .group(shown, display)
  }

  /// Turns the focused window's group from a row into a column or back.
  func rotate() -> CommandResult {
    let (group, display): (NodeID, DisplayID)
    switch focusedGroup() {
    case .failure(let result): return result
    case .group(let g, let d): (group, display) = (g, d)
    }
    guard var workspace = workspaces[display] else { return .failure("no display") }
    let before = workspace
    let words = name(of: group, on: display)
    workspace.changeStructure {
      $0.rotate(group)
      return Remap()
    }
    workspaces[display] = workspace
    // Someone who turns a group wants to see the same windows the other way round, not tiles.
    let shown = layouts[display].map { Set($0.windowFrames.keys) } ?? []
    func refusal(_ turned: Layout?) -> CommandResult? {
      guard let turned else { return nil }
      let lost = shown.filter { turned.windowFrames[$0] == nil }.count
      guard lost > 0 else { return nil }
      workspaces[display] = before
      return .failure(
        "not enough room: rotated, \(Self.count(lost, "window")) would be too small to show; "
          + "`grow` them first, or frame the group (`zoom`, then `out`) and rotate it there")
    }
    // Judged as it will be laid out: with room made for windows that need it, if their neighbours can spare it (F61).
    if let refusal = refusal(roomyLayout(of: display, for: .structure)) { return refusal }
    workspaces[display] = workspace
    relayout(display, reason: .structure)
    // How small an app lets its window get is known only once it has been asked.
    if let refusal = refusal(layouts[display]) {
      relayout(display, reason: .structure)
      return refusal
    }
    scheduleSave()
    return .success("rotated \(words)")
  }

  /// Reverses the order of the focused window's group.
  func mirror() -> CommandResult {
    switch focusedGroup() {
    case .failure(let result): return result
    case .group(let group, let display):
      workspaces[display]?.tree.mirror(group)
      relayout(display, reason: .structure)
      scheduleSave()
      return .success("mirrored \(name(of: group, on: display))")
    }
  }

  // MARK: grow and shrink

  /// No floating window is shrunk below this, the limit `moveBoundary` keeps for docked ones.
  static let minimumFloatingSide: CGFloat = 80

  /// Makes the focused window bigger (or smaller) by `points` in each direction it has room to change:
  /// a docked window by moving the seams beside it, two seams on opposite sides sharing the amount; a
  /// floating window about its middle.
  func resizeFocusedWindow(by points: Double?, growing: Bool, isSecondTry: Bool = false) -> CommandResult {
    let (id, display): (WindowID, DisplayID)
    switch target(nil) {
    case .failure(let result): return result
    case .window(let w, let d): (id, display) = (w, d)
    }
    let verb = growing ? "grow" : "shrink"
    // `parse` bounds the number, but a command can also be built in code, and the setting typed by hand.
    let configured = settings.resizeStep
    let step = points ?? (configured.isFinite && configured > 0 ? configured : 40)
    guard step.isFinite, step > 0 else { return .failure("expected a positive number of points, got \(step)") }
    let amount = CGFloat(min(step, 1_000_000)) * (growing ? 1 : -1)

    guard let before = workspaces[display]?.tree, let leaf = before.leaf(containing: id) else {
      return resizeFloatingWindow(id, on: display, by: amount, verb: verb)
    }
    guard let layout = layouts[display], layout.windowFrames[id] != nil, let slot = layout.nodeFrames[leaf],
      let view = treeView(display)
    else { return .failure("\(id) is out of view") }

    // Where each edge with a seam beside it should end up.
    var wanted: [(edge: Edge, coordinate: CGFloat)] = []
    var hasSeams = false
    for axis in Axis.allCases {
      let sides = (axis == .horizontal ? [Edge.left, .right] : [.top, .bottom]).filter { edge in
        if case .seam = Self.seam(on: edge, of: leaf, in: view, layout: layout) { return true }
        return false
      }
      guard !sides.isEmpty else { continue }
      hasSeams = true
      var change = amount
      if !growing {
        // It stops while it can still be shown: a window shrunk into a tile could not be grown back.
        let usable = options(for: display).layoutOptions.minimumUsableSize
        let learned = minimumSizes[id] ?? .zero
        let floor = axis == .horizontal ? max(usable.width, learned.width) : max(usable.height, learned.height)
        change = -min(-amount, max(slot.length(along: axis) - floor - 1, 0))
      }
      guard change != 0 else { continue }
      let share = change / CGFloat(sides.count)
      for edge in sides { wanted.append((edge, slot.coordinate(of: edge) + (edge.isLeading ? -share : share))) }
    }
    guard hasSeams else { return .failure("\(id) has nothing beside it in view to trade room with") }
    guard moveSeams(beside: leaf, on: display, toward: wanted) else {
      // To the last digit: a command that fails has changed nothing.
      workspaces[display]?.tree = before
      return .failure("\(id) cannot \(verb) any further")
    }
    // The person's own hand, like `resize` and a drag of the gap: Arbor does not push back (F61).
    byHand { relayout(display, reason: .structure) }
    if layouts[display]?.windowFrames[id] == nil {
      // Its app refused the smaller slot, so it became a tile. Put the seams back, and now that Arbor
      // has learned how small the window can get, go as far as that.
      workspaces[display]?.tree = before
      byHand { relayout(display, reason: .structure) }
      if !isSecondTry, layouts[display]?.windowFrames[id] != nil {
        return resizeFocusedWindow(by: points, growing: growing, isSecondTry: true)
      }
      ensureFocusIsVisible(on: display)
      return .failure("\(id) cannot \(verb) any further")
    }
    scheduleSave()
    return .success(growing ? "\(id) grew" : "\(id) shrank")
  }

  /// Whether `grow` and `shrink` have anything to move for `window`: a gap beside it in view, or its own edges if it floats.
  /// For the menu, which greys out what would only beep.
  func hasRoomToTrade(_ window: WindowID) -> Bool {
    guard let display = workspaceID(containing: window), let tree = workspaces[display]?.tree else { return false }
    guard let leaf = tree.leaf(containing: window) else { return frameInView(of: window, on: display) != nil }
    guard let layout = layouts[display], layout.windowFrames[window] != nil, let view = treeView(display) else { return false }
    return Edge.allCases.contains { edge in
      if case .seam = Self.seam(on: edge, of: leaf, in: view, layout: layout) { return true }
      return false
    }
  }

  /// Moves the seams beside `leaf` so that each of the edges in `wanted` comes as near to its coordinate
  /// as the limits on both sides of the seam allow. Returns whether anything moved. Like an edge
  /// resize, it moves the seams nearest the root first and measures each edge again in a fresh layout,
  /// because moving an outer seam rescales the splits inside it.
  private func moveSeams(
    beside leaf: NodeID, on display: DisplayID, toward wanted: [(edge: Edge, coordinate: CGFloat)]
  ) -> Bool {
    guard let before = workspaces[display]?.tree, let layout = layouts[display], let view = treeView(display) else {
      return false
    }
    func depth(_ edge: Edge) -> Int {
      if case .seam(let seam) = Self.seam(on: edge, of: leaf, in: view, layout: layout) {
        return before.depth(of: seam.split)
      }
      return .max
    }
    for (edge, coordinate) in wanted.sorted(by: { depth($0.edge) < depth($1.edge) }) {
      guard let fresh = self.layout(of: display), let freshView = treeView(display),
        let slot = fresh.nodeFrames[leaf],
        case .seam(let seam) = Self.seam(on: edge, of: leaf, in: freshView, layout: fresh)
      else { continue }
      // By the seam, so that beside a group that runs along the row (a turned pair, F62) only the window at its end gives.
      workspaces[display]!.tree.moveBoundary(at: seam, by: Double(coordinate - slot.coordinate(of: edge)))
    }
    // Judged by the slot, in whole points: at a limit the weights can still change in their last digit.
    return self.layout(of: display)?.nodeFrames[leaf] != layout.nodeFrames[leaf]
  }

  private func resizeFloatingWindow(_ id: WindowID, on displayID: DisplayID, by amount: CGFloat, verb: String)
    -> CommandResult
  {
    guard let current = frameInView(of: id, on: displayID), let display = display(displayID) else {
      return .failure("\(id) is out of view")
    }
    // A window on the Desktop stays on it: grown over its docked neighbours, it would be squeezed back at the next
    // change of the arrangement (`placeFloatingWindows`). One the user put elsewhere has the whole display.
    let desktop = layouts[displayID]?.desktopFrame.map { floatingRegion($0, on: display) }
    let isOnDesktop = desktop?.insetBy(dx: -1, dy: -1).contains(current) == true && !isPinned(id)
    let room = isOnDesktop ? desktop ?? display.visibleFrame : display.visibleFrame
    func side(_ length: CGFloat, limit: CGFloat) -> CGFloat {
      // Never past the room, never below the minimum, and never the wrong way for a window already past either.
      amount > 0 ? max(length, min(length + amount, limit)) : min(length, max(length + amount, Self.minimumFloatingSide))
    }
    func centred(_ size: CGSize) -> CGRect {
      CGRect(x: current.midX - size.width / 2, y: current.midY - size.height / 2, width: size.width, height: size.height)
        .integralRounded.fitted(into: room)
    }
    let size = CGSize(width: side(current.width, limit: room.width), height: side(current.height, limit: room.height))
    guard abs(size.width - current.width) > 1 || abs(size.height - current.height) > 1 else {
      return .failure("\(id) cannot \(verb) any further")
    }
    // No layout follows, so no motion either. A stage still up from an earlier change would lift on a window that is elsewhere.
    overlays.finishAnimations()
    guard var actual = system.setFrame(centred(size), of: id) else { return .failure("\(id) cannot \(verb) any further") }
    // An app that took another size than asked (or kept its own) is now off centre.
    let settledFrame = centred(actual.size)
    if !settledFrame.approximatelyEquals(actual) { actual = system.setFrame(settledFrame, of: id) ?? actual }
    windows[id]?.frame = actual
    // Off the Desktop it is where its user wants it, not where Arbor put it, and is left there like a window moved by hand.
    settled[id] = isOnDesktop ? actual : nil
    // No relayout follows, which would have moved the ring along.
    refreshFocusRing(.geometry)
    guard !actual.approximatelyEquals(current) else { return .failure("\(id) cannot \(verb) any further") }
    workspaces[displayID]?.floating[id] = actual
    // Its user has taken it in hand: alone on the Desktop, it is not stretched over it again (F18).
    floatingWindowMoved(id, from: displayID)
    scheduleSave()
    return .success(amount > 0 ? "\(id) grew" : "\(id) shrank")
  }

  // MARK: move-to-display

  /// Sends a window to another display, docked or floating as it was: a docked window docks at the
  /// edge of that display's view that faces the display it came from, a floating one floats in the
  /// middle. Focus goes with it.
  func move(_ window: WindowID?, to target: DisplayTarget) -> CommandResult {
    if let refusal = refusalWhileFullScreen() { return refusal }
    let (id, source): (WindowID, DisplayID)
    switch self.target(window) {
    case .failure(let result): return result
    case .window(let w, let d): (id, source) = (w, d)
    }
    guard let (destination, number) = resolve(target, from: source) else { return noSuchDisplay(target) }
    guard destination.id != source else {
      return .failure(displays.count == 1 ? "there is only one display" : "\(id) is already on display \(number)")
    }
    guard let from = display(source), workspaces[destination.id] != nil, let workspace = workspaces[source] else {
      return .failure("no display")
    }

    let wasDocked = workspace.isDocked(id)
    // A pin (F49) goes along, and so does being summoned (F53), as when the window is carried there by hand. Where another
    // window is summoned already the newcomer would be sent away, and one that was sent away was named to be seen.
    var role = workspace.role(of: id)
    if case .summoned = role, workspaces[destination.id]?.summoned != nil { role = nil }
    if role == .stashed { role = nil }
    let size = workspace.floating[id]?.size ?? windows[id]?.frame.size ?? CGSize(width: 800, height: 600)
    let edge = DirectionalSearch.facingEdge(of: destination.frame, from: from.frame)
    // Asked before it leaves this display: a window that is refused there stays where it was.
    if wasDocked, let why = workspaces[destination.id]!.wouldDock(id, at: .cameraEdge(edge)).refusal(of: id) {
      return .failure(why)
    }
    if wasDocked {
      // If it is out of view at the other end, it is parked again there.
      parked.remove(id)
      // With the frame it goes back to when it floats again (F48).
      transfer(id, from: source, to: destination.id)
      workspaces[destination.id]!.dock(id, at: .cameraEdge(edge), shareSpace: settings.shareRemovedSpace)
      workspaces[destination.id] = keepingDesktopUsable(workspaces[destination.id]!, on: destination.id)
      relayout(source, reason: .structure)
      relayout(destination.id, reason: .structure)
    } else {
      // On the Desktop if it is in view; otherwise in front of the view, like a window that just opened.
      let desktop = layouts[destination.id]?.desktopFrame
      let room = desktop.map { floatingRegion($0, on: destination) } ?? destination.visibleFrame
      let middle = (desktop ?? room).center
      // The frame it has when there is room for it. On a smaller Desktop it is squeezed, as by `placeFloatingWindows`.
      let preferred = CGRect(
        x: middle.x - size.width / 2, y: middle.y - size.height / 2, width: size.width, height: size.height
      ).integralRounded.fitted(into: destination.visibleFrame)
      var wanted = floatingFrame(preferred, on: room, of: destination, minimum: minimumSizes[id])
      // It is placed before the layouts below; a motion still playing would end on a window that has left.
      overlays.finishAnimations()
      // Asked before anything is written down: a window whose app does not answer is where it was.
      guard var actual = system.setFrame(wanted, of: id) else {
        return .failure("\(id) stays where it is: its app does not answer")
      }
      parked.remove(id)
      workspaces[source]!.forget(id, shareSpace: settings.shareRemovedSpace)
      if actual.width > wanted.width + 2 || actual.height > wanted.height + 2 {
        // Its app will not make it that small. From the Desktop's far corner it would hang off the display.
        minimumSizes[id] = CGSize(
          width: actual.width > wanted.width + 2 ? actual.width : minimumSizes[id]?.width ?? 0,
          height: actual.height > wanted.height + 2 ? actual.height : minimumSizes[id]?.height ?? 0)
        wanted = floatingFrame(preferred, on: room, of: destination, minimum: minimumSizes[id])
        actual = system.setFrame(wanted, of: id) ?? actual
      }
      windows[id]?.frame = actual
      settled[id] = actual
      workspaces[destination.id]!.floating[id] = preferred
      if role != nil { workspaces[destination.id]!.setRole(role, of: id) } else { receiveAsGuestOfTheView(id) }
      // Both Desktops have a different number of windows now (F18), which lays both displays out.
      floatingWindowMoved(id, from: source)
      if !settings.soleFloatTakesDesktop {
        // Without F18 too: a Desktop with nothing on it gives up room that one in use keeps (F61).
        relayout(source, reason: .structure)
        relayout(destination.id, reason: .structure)
      }
    }
    if windows[id]?.isPresent == true { giveFocus(to: id) }
    // The window that left may have had the keyboard, and the newcomer takes room from the one that has it there.
    // Only from a window that went out of view: a minimized window takes no focus, nor the keyboard out of a sheet or a panel.
    ensureFocusIsVisible(on: source, alsoFromNothing: false)
    ensureFocusIsVisible(on: destination.id, alsoFromNothing: false)
    scheduleSave()
    return .success("moved \(id) to display \(number)")
  }
}

extension CGRect {
  /// The x of a left or right edge, or the y of a top or bottom edge.
  fileprivate func coordinate(of edge: Edge) -> CGFloat {
    switch edge {
    case .left: minX
    case .right: maxX
    case .top: minY
    case .bottom: maxY
    }
  }
}
