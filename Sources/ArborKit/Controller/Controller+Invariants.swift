import ArborCore
import CoreGraphics

/// One rule of the controller's bookkeeping that does not hold.
public struct InvariantViolation: Equatable, Sendable, CustomStringConvertible {
  /// A short, stable name for the rule. The chaos test's shrinker deletes steps from a failing
  /// script for as long as the same rule still breaks.
  public var rule: String
  /// Which window, node or display, and what is wrong with it.
  public var message: String

  public init(_ rule: String, _ message: String) {
    self.rule = rule
    self.message = message
  }

  public var description: String { "[\(rule)] \(message)" }
}

/// What must be true of the controller's own state after every command and every event, whatever
/// came before. `LayoutTree.invariantViolations()` does the same for one tree. The chaos test
/// (`ArborTesting/Chaos.swift`, docs/TESTING.md) checks these after each of thousands of random
/// steps, together with the rules that need the window system's side of the story.
///
/// A feature with state of its own adds its rules here: write
/// `func <feature>Violations(_ problems: inout [InvariantViolation])` in `Controller+<Feature>.swift` and
/// call it at the end of `invariantViolations`. The checks run after every step of the chaos test, so they
/// walk dictionaries in whatever order they come; the result is sorted once at the end.
extension Controller {
  /// - Parameter awaitingLayout: displays with a layout scheduled but not run yet (a Space switch is
  ///   laid out once all of its reports are in), whose `layouts` entry may therefore be out of date.
  /// - Parameter awaitingPutBack: displays whose windows a timer is about to put back (an app that hung has just answered), where
  ///   what is parked may not match the layout yet.
  /// - Returns: the broken rules in a fixed order, whatever order dictionaries are walked in.
  public func invariantViolations(
    awaitingLayout: Set<DisplayID> = [], awaitingPutBack: Set<DisplayID> = []
  ) -> [InvariantViolation] {
    var problems: [InvariantViolation] = []
    var docked: [DisplayID: [WindowID]] = [:]
    for (id, workspace) in workspaces {
      docked[id] = Self.check(workspace, named: "display \(id)", &problems)
      if workspace.lookingFrom != nil, peeking?.display != id {
        problems.append(.init("leak", "display \(id): the view is only visiting, and nobody is peeking there"))
      }
    }
    for (id, entry) in dormant {
      _ = Self.check(entry.workspace, named: "dormant display \(id)", &problems)
      if entry.workspace.lookingFrom != nil {
        problems.append(.init("leak", "dormant display \(id): the view is only visiting"))
      }
    }
    if isRunning {
      membershipViolations(docked, &problems)
      layoutViolations(awaitingLayout: awaitingLayout, &problems)
      // With `reflowWhileDragging` the other windows try out the drop while the window is in the air (F09).
      if drag == nil || !settings.reflowWhileDragging {
        parkingViolations(docked, awaitingLayout: awaitingLayout.union(awaitingPutBack), &problems)
      }
      bookkeepingViolations(&problems)
      pendingSlotViolations(&problems)
      foundAtAStartViolations(&problems)
    }
    return problems.isEmpty ? problems : problems.sorted { ($0.rule, $0.message) < ($1.rule, $1.message) }
  }

  /// The tree is sound, and the camera, history and saved views point into it. Returns the docked windows.
  private static func check(
    _ workspace: Workspace, named name: @autoclosure () -> String, _ problems: inout [InvariantViolation]
  ) -> [WindowID] {
    let tree = workspace.tree
    for problem in tree.invariantViolations() { problems.append(.init("tree", "\(name()): \(problem)")) }
    if !tree.contains(workspace.camera) {
      problems.append(.init("camera", "\(name()): the camera is on \(workspace.camera), which does not exist"))
    }
    for node in workspace.back where !tree.contains(node) {
      problems.append(.init("history", "\(name()): back history holds \(node), which does not exist"))
    }
    for node in workspace.forward where !tree.contains(node) {
      problems.append(.init("history", "\(name()): forward history holds \(node), which does not exist"))
    }
    if workspace.back.count > Workspace.historyLimit || workspace.forward.count > Workspace.historyLimit {
      problems.append(
        .init("history", "\(name()): \(workspace.back.count) back and \(workspace.forward.count) forward entries"))
    }
    if let origin = workspace.lookingFrom, !tree.contains(origin) {
      problems.append(.init("camera", "\(name()): the look began on \(origin), which does not exist"))
    }
    // Back and Forward always go somewhere else: no view is in the history twice in a row, or next to where the camera is, or,
    // while it is only visiting (`Workspace.beginLook`), next to where it belongs.
    let path = workspace.back + [workspace.lookingFrom ?? workspace.camera] + workspace.forward.reversed()
    if let twice = zip(path, path.dropFirst()).first(where: { $0 == $1 })?.0 {
      problems.append(
        .init("history-repeats", "\(name()): \(twice) twice in a row: back \(workspace.back), camera \(workspace.camera), forward \(workspace.forward)"))
    }
    // A guest floats here, and its host exists (F57).
    for (window, host) in workspace.guests ?? [:] where workspace.floating[window] == nil || !tree.contains(host) {
      problems.append(.init("guests", "\(name()): \(window) is a guest of \(host), but does not float here or has no such host"))
    }
    for (slot, node) in workspace.savedViews where !tree.contains(node) {
      problems.append(.init("saved-view", "\(name()): view \(slot) is \(node), which does not exist"))
    }
    let docked = tree.allWindows
    for window in docked where workspace.floating[window] != nil {
      problems.append(.init("membership", "\(name()): \(window) is both docked and floating"))
    }
    for (window, frame) in workspace.floating where !frame.isFinite {
      problems.append(.init("finite", "\(name()): \(window) floats at \(frame.brief)"))
    }
    return docked
  }

  /// Every managed window is in exactly one workspace, and workspaces hold nothing else.
  private func membershipViolations(_ docked: [DisplayID: [WindowID]], _ problems: inout [InvariantViolation]) {
    if workspaces.count != displays.count || !displays.allSatisfy({ workspaces[$0.id] != nil }) {
      problems.append(
        .init("displays", "workspaces for \(workspaces.keys.sorted()), displays \(displays.map(\.id).sorted())"))
    }
    var home: [WindowID: DisplayID] = [:]
    func visit(_ window: WindowID, on id: DisplayID) {
      if let other = home.updateValue(id, forKey: window), other != id {
        problems.append(.init("membership", "\(window) is on both \(min(other, id)) and \(max(other, id))"))
      }
      if let snapshot = windows[window] {
        if !filter.manages(snapshot) {
          problems.append(.init("membership", "\(window) on \(id) is not a window Arbor arranges"))
        }
      } else if !pendingSlots.contains(window) {
        problems.append(.init("membership", "\(window) on \(id) no longer exists"))
      }
    }
    for (id, workspace) in workspaces {
      for window in docked[id] ?? [] { visit(window, on: id) }
      for window in workspace.floating.keys { visit(window, on: id) }
    }
    // With no display connected there is nowhere to put a window; it is adopted when one appears.
    if !displays.isEmpty {
      for (window, snapshot) in windows where home[window] == nil && filter.manages(snapshot) {
        problems.append(.init("membership", "\(window) is managed but on no display"))
      }
    }
  }

  /// `layouts` is what laying out the current state gives, and everything in it is on its display.
  private func layoutViolations(awaitingLayout: Set<DisplayID>, _ problems: inout [InvariantViolation]) {
    if layouts.count != workspaces.count || !layouts.keys.allSatisfy({ workspaces[$0] != nil }) {
      problems.append(.init("layout", "layouts for \(layouts.keys.sorted()), workspaces for \(workspaces.keys.sorted())"))
    }
    for (id, layout) in layouts {
      guard let display = display(id) else { continue }
      // While a key is held to look (F51) the display shows everything and the view is where it was.
      if !awaitingLayout.contains(id), peeking == nil, let fresh = freshLayout(of: id), fresh != layout {
        problems.append(.init("stale-layout", "\(id): \(Self.difference(between: layout, and: fresh))"))
      }
      // Rounding each boundary to whole points can push an edge half a point past a fractional frame.
      let bounds = display.visibleFrame.insetBy(dx: -1, dy: -1)
      var rects: [(window: WindowID?, node: NodeID?, rect: CGRect)] = layout.windowFrames.map { ($0.key, nil, $0.value) }
      for tile in layout.tiles { rects.append((nil, tile.node, tile.frame)) }
      if let desktop = layout.desktopFrame { rects.append((nil, nil, desktop)) }
      func name(_ index: Int) -> String {
        rects[index].window.map { "\($0)" } ?? rects[index].node.map { "tile \($0)" } ?? "the Desktop"
      }
      for (index, entry) in rects.enumerated() {
        let rect = entry.rect
        if !rect.isFinite || rect.width < 0 || rect.height < 0 {
          problems.append(.init("finite", "\(id): the slot of \(name(index)) is \(rect.brief)"))
        } else if !bounds.contains(rect) {
          problems.append(
            .init("slot-outside", "\(id): the slot of \(name(index)), \(rect.brief), leaves \(display.visibleFrame.brief)"))
        }
        for other in (index + 1)..<rects.count where rect.overlaps(rects[other].rect) {
          let pair = [name(index) + " at " + rect.brief, name(other) + " at " + rects[other].rect.brief].sorted()
          problems.append(.init("slots-overlap", "\(id): \(pair[0]) overlaps \(pair[1])"))
        }
      }
    }
  }

  /// A docked window is parked exactly when the layout hides it, and a floating one only while
  /// the Desktop is out of view. Windows that are not present are left wherever they were.
  private func parkingViolations(
    _ docked: [DisplayID: [WindowID]], awaitingLayout: Set<DisplayID>, _ problems: inout [InvariantViolation]
  ) {
    for window in parked {
      if let snapshot = windows[window] {
        if !filter.manages(snapshot) {
          problems.append(.init("parked-unmanaged", "\(window) is parked but is not a window Arbor arranges"))
        }
      } else {
        problems.append(.init("parked", "\(window) is parked but no longer exists"))
      }
    }
    for (id, workspace) in workspaces where !awaitingLayout.contains(id) {
      guard let layout = layouts[id] else { continue }
      if let window = windowLetBe, workspace.contains(window), windows[window]?.isPresent == true,
        !workspace.isDocked(window) || !layout.hiddenWindows.contains(window) || parked.contains(window)
      {
        problems.append(.init("let-be", "\(window) on \(id) is let be, which is for a docked window that the layout hides and that is in view"))
      }
      // The window in the user's hand is left alone until it is dropped.
      // Nor is one whose app does not answer: it is where it was, and is placed when the app answers.
      for window in docked[id] ?? []
      where windows[window]?.isPresent == true && window != drag?.window && !unplaced.contains(window) && !isLetBe(window) {
        let hidden = layout.hiddenWindows.contains(window)
        if hidden, !parked.contains(window) {
          problems.append(.init("parked", "\(window) on \(id) is hidden by the layout but not parked"))
        } else if !hidden, parked.contains(window) {
          problems.append(.init("parked", "\(window) on \(id) has a slot in view but is parked"))
        }
      }
      guard layout.desktopFrame != nil, !parked.isEmpty else { continue }
      for window in workspace.floating.keys
      where parked.contains(window) && windows[window]?.isPresent == true && !workspace.isStashed(window)
        // One that opened off screen during a hold waits there until the view next moves (Controller+Hold.swift).
        && !holdKeepsOut(window)
        // Its app does not answer: it is placed when it does.
        && !unplaced.contains(window)
      {
        problems.append(.init("parked-on-the-desktop", "\(window) floats on \(id), whose Desktop is in view, but is parked"))
      }
    }
  }

  /// Nothing is remembered about windows that are gone, so nothing grows for ever.
  private func bookkeepingViolations(_ problems: inout [InvariantViolation]) {
    func check(_ name: String, _ ids: some Sequence<WindowID>) {
      // A rule for each list, so that a known leak in one does not hide a new one in another.
      for window in ids where windows[window] == nil {
        problems.append(.init("leak-\(name)", "\(name) still lists \(window), which no longer exists"))
      }
    }
    check("settled", settled.keys)
    check("minimumSizes", minimumSizes.keys)
    check("misfits", misfits.keys)
    check("journeys", journeys.keys)
    check("disprovedMinimums", disprovedMinimums.keys)
    check("seenSizes", seenSizes.keys)
    check("justAnswered", justAnswered.keys)
    check("fixedSizesNoted", fixedSizesNoted)
    check("parkedAgain", parkedAgain.keys)
    check("titleBars", titleBars.keys)
    check("appPlacedFrames", appPlacedFrames.keys)
    check("spokeOfItsPlace", spokeOfItsPlace.keys)
    check("returningWindows", returningWindows)
    check("titleWatches", titleWatches.keys)
    check("unplaced", unplaced)
    check("owedMoves", owedMoves)
    check("givenUp", enforcement.givenUp)
    check("appsDoubleClick", [appsDoubleClick?.window].compactMap { $0 })
    check("whereAZoomBegan", whereAZoomBegan.keys)
    check("letBeWhenThePauseBegan", letBeWhenThePauseBegan.keys.filter { !pendingSlots.contains($0) })
    check("focusHistory", focusHistory)
    check("letBe", [letBe?.window].compactMap { $0 })
    check("ignoredWindowIDs", filter.ignoredWindowIDs)
    check("landsAt", landsAt.keys)
    check("sharedItsSpace", sharedItsSpace.keys)
    check("metAhead", metAhead.keys)
    check("windowsOwedAPlace", windowsOwedAPlace)
    check("chosenOnShape", chosenOnShape.keys)
    check("fittedToADisplay", fittedToADisplay.keys)
    check("fittedFrames", fittedFrames.keys)
    if Set(focusHistory).count != focusHistory.count {
      problems.append(.init("leak", "focusHistory lists a window twice: \(focusHistory)"))
    }
    if let drag, windows[drag.window] == nil {
      problems.append(.init("leak", "the dragged window \(drag.window) no longer exists"))
    }
  }

  /// A saved slot that waits for its window (Controller+PendingSlots.swift) is docked somewhere, be it on a display that
  /// is not connected, says which app and title it waits for, and stands for no window that is in sight.
  private func pendingSlotViolations(_ problems: inout [InvariantViolation]) {
    for slot in pendingSlots {
      if windows[slot] != nil { problems.append(.init("pending", "a slot waits for \(slot), which is here")) }
      if hints[slot] == nil { problems.append(.init("pending", "nothing says which window the slot \(slot) waits for")) }
      if !workspaces.values.contains(where: { $0.isDocked(slot) }), !dormant.values.contains(where: { $0.workspace.isDocked(slot) }) {
        problems.append(.init("pending", "the waiting slot \(slot) is in no tree"))
      }
      if parked.contains(slot) { problems.append(.init("pending", "the waiting slot \(slot) is parked")) }
    }
    if pendingSlots.isEmpty, provisionalSlots.isEmpty, !windowsTheFileKnew.isEmpty {
      problems.append(.init("leak", "\(windowsTheFileKnew.count) windows are remembered as the file knew them, and no slot waits"))
    }
    if pendingSlots.isEmpty, provisionalSlots.isEmpty, !keptRoom.isEmpty {
      problems.append(.init("leak", "room is kept on \(keptRoom.keys.sorted()), and no slot waits"))
    }
    // What is laid out as if it were there is left open: nothing that is drawn, moved or clicked goes by a window
    // that does not exist.
    for (display, layout) in layouts {
      let named = Set(layout.windowFrames.keys).union(layout.hiddenWindows).union(layout.tiles.flatMap(\.windows))
      for slot in named.intersection(pendingSlots).sorted() {
        problems.append(.init("pending", "the layout of \(display) speaks of the waiting slot \(slot)"))
      }
    }
  }

  private static func difference(between old: Layout, and fresh: Layout) -> String {
    if old.camera != fresh.camera { return "camera \(old.camera), a fresh layout has \(fresh.camera)" }
    if old.frame != fresh.frame { return "fills \(old.frame.brief), a fresh layout fills \(fresh.frame.brief)" }
    for window in Set(old.windowFrames.keys).union(fresh.windowFrames.keys).sorted()
    where old.windowFrames[window] != fresh.windowFrames[window] {
      let (before, after) = (old.windowFrames[window], fresh.windowFrames[window])
      return "\(window) has slot \(before?.brief ?? "none"), a fresh layout gives \(after?.brief ?? "none")"
    }
    if old.tiles != fresh.tiles {
      return "tiles \(old.tiles.map(\.node)), a fresh layout has \(fresh.tiles.map(\.node)) (or their contents differ)"
    }
    if old.hiddenWindows != fresh.hiddenWindows {
      return "hides \(old.hiddenWindows.sorted()), a fresh layout hides \(fresh.hiddenWindows.sorted())"
    }
    return "seams, node frames or the Desktop differ from a fresh layout"
  }

  // MARK: What the chaos test needs to see

  /// Windows Arbor no longer arranges and still has to bring back into view (`owedTheWayBack`).
  public var windowsOwedTheWayBack: Set<WindowID> { Set(owedTheWayBack.keys) }

  /// The window being dragged by its title bar, if any.
  public var draggedWindow: WindowID? { drag?.window }

  /// What `saveNow()` would write.
  public var stateToSave: PersistedState { persistedState() }

  /// Saved slots that wait for their windows.
  public var waitingSlotIDs: Set<WindowID> { pendingSlots }

  /// Docked windows Arbor no longer puts back, because something kept moving them (Controller+Hardening.swift).
  public var windowsLeftToTheirApps: Set<WindowID> { enforcement.givenUp }

  /// Whether a key that may become a peek is down, held long enough yet or not (F51).
  public var aPeekIsUnderWay: Bool { peeking != nil }

  /// Those of them that are where a double-click put them (Controller+AppsDoubleClick.swift).
  public var windowsLeftWhereADoubleClickPutThem: Set<WindowID> { enforcement.leftAlone }

  /// The docked window whose next change of frame would be put down to a double-click.
  public var windowJustDoubleClicked: WindowID? { appsDoubleClick?.window }

  /// Windows whose app did not answer when they were to be moved, and have not been moved since.
  public var windowsOwedAMove: Set<WindowID> { unplaced.union(owedMoves) }

  /// The docked window being resized by its edges, if any.
  public var edgeResizedWindow: WindowID? { edgeResize?.window }

  /// The tiles and seam handles the overlays should be showing on `display` now. Only the parts of a scene that
  /// follow from the layout alone: putting a whole scene together can change state (the focus ring
  /// notes what it has shown), and looking must not.
  public func expectedTilesAndSeams(on display: DisplayID) -> (tiles: [TileModel], seams: [Seam])? {
    expectedScene(on: display).map { ($0.tiles, $0.seams) }
  }

  /// The same, with the surface behind docked windows (F15).
  public func expectedScene(on display: DisplayID) -> OverlayScene? {
    layouts[display].map { layout in
      var scene = OverlayScene()
      scene.tiles = tileModels(for: layout, on: display)
      scene.seams = layout.seams
      // How tiles look, and whether there are gaps to drag at all (F15), follow from the settings and change nothing.
      applyAppearance(to: &scene, for: layout, on: display)
      return scene
    }
  }
}

extension CGRect {
  /// No coordinate is infinite or not a number (`CGRect.null` has an infinite origin).
  var isFinite: Bool {
    origin.x.isFinite && origin.y.isFinite && size.width.isFinite && size.height.isFinite
  }

  /// `(12,37 622×751)`, for messages.
  public var brief: String {
    func n(_ value: CGFloat) -> String {
      value == value.rounded() && abs(value) < 1e15 ? "\(Int(value))" : "\(Double(value))"
    }
    return "(\(n(origin.x)),\(n(origin.y)) \(n(size.width))×\(n(size.height)))"
  }
}
