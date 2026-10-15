import ArborCore
import CoreGraphics

/// Dragging a window by its title bar: finding the drop target under the pointer, previewing where
/// the window would land, and docking or floating it on release. The three `drag…` methods are
/// part of `WindowSystemEvents`.
///
/// A drag is one `DragSession`. Every pointer move goes through `updateHover()`, which decides what
/// the pointer is over (`hover(of:)`) and whether that has to be held first; `showHover(active:)`
/// shows the result. Every drag ends in `endDrag(on:)`, dropped or not, so that is the one place
/// that has to leave nothing behind: no timer, no preview, no trial layout. The real workspaces
/// change only in `finishDrop(_:on:at:after:)`, which it ends with.
extension Controller {
  /// What the pointer of a drag is over.
  struct Hover: Equatable {
    /// The display under the pointer, whose workspace `target` refers to. Nil if there is none.
    var display: DisplayID?
    var target: DropTarget
    /// The target is `.none` although the pointer is away from the window's own slot: nothing can be dropped here.
    /// Live reflow does not open the slot again for it.
    var isNowhere = false
    /// Let go here, the window is macOS's, which tiles it, and this is why (`MacTiling`). Arbor stands aside: the target is
    /// `.float`, nothing is previewed, and no frame is set on a window that macOS is about to move.
    var leftToMacOS: MacTiling.Claim?
  }

  /// A drag in progress, from `dragBegan` to `endDrag(on:)`.
  struct DragSession {
    var window: WindowID
    /// The display whose workspace held the window when the drag began.
    var sourceDisplay: DisplayID?
    /// Where the pointer was last seen.
    var point: CGPoint
    /// What the pointer is over. Nil whenever the arrangement has changed under the drag, so that
    /// the next move looks afresh.
    var hover: Hover?
    /// Whether `hover` has been held long enough: a release drops the window there.
    var isActive = false
    /// Where the window would land on the active target, if it would dock.
    var landing: CGRect?
    /// The size a command meant to give the window while it was in the hand (`putBack`), or its own if it was taken in hand while it
    /// was small out of view. It takes it when it is let go.
    var sizeOwed: CGSize?
    /// What live reflow has moved (Controller+Reflow.swift).
    var reflow = Reflow()
    /// macOS's own tiling as it stood when the drag began.
    var macTiling = MacTiling.off
    /// The screen edges in whose band the pointer took hold and has been ever since. A window that lies under the menu bar has its title
    /// bar in the top band: slid sideways, or merely nudged, it has not been carried to that edge. Nothing is offered along it
    /// until the pointer has left the band once.
    var edgesNeverLeft: Set<Edge> = []
  }

  /// Held while dragging, this turns docking off. Not ⌥: since macOS 15 that brings up macOS's own
  /// tiling preview during a window drag.
  static let dragSuppressModifier: KeyChord.Modifiers = .command

  /// Whether `held` turns docking off: ⌘, whatever else is held, except ⌃⌥⌘, which is the beginning of a shortcut of
  /// Arbor's own (⌃⌥⌘ + arrow moves the focused window).
  static func suppressesDocking(_ held: KeyChord.Modifiers) -> Bool {
    held.contains(dragSuppressModifier) && !held.isSuperset(of: [.control, .option])
  }
  /// The timer that activates the target under the pointer.
  static let dragDwellKey = "drag-dwell"
  /// The timer that looks at what macOS made of a window that was left to it.
  static let leftToMacOSKey = "left-to-macos"

  // MARK: Events

  public func dragBegan(_ id: WindowID, at point: CGPoint) {
    stopWatchingTitle(of: id)
    // The end of the last drag can be lost (a missed mouse-up). What it left must go first.
    cancelDrag()
    closeFinderBecauseTheUserLeft()
    guard isRunning, isManaged(id) else { return }
    rememberDragOrigin(of: id)
    // Out of view a floating window may have been made small (`shrinkOutOfView`). It takes its own size when it is let go. (A docked
    // one that is let go over the Desktop takes the size it floated at, as ever.)
    let wasMadeSmall = parked.contains(id) && sizeInView(of: id) != windows[id]?.frame.size
    let own = wasMadeSmall ? workspaceID(containing: id).flatMap { workspaces[$0]?.floating[id]?.size } : nil
    // Whatever Arbor did with it before, it is in the user's hand and in view now.
    parked.remove(id)
    drag = DragSession(window: id, sourceDisplay: workspaceID(containing: id), point: point)
    // Asked at every drag: people change it while Arbor runs, in the window that Check Setup sent them to.
    drag?.macTiling = system.macTiling()
    drag?.edgesNeverLeft = screenEdges(near: point)
    drag?.sizeOwed = own
    soleFloatTakenInHand(id)
    // Word of a drag can come late, when the pointer has already stopped where it is going. The
    // hold counts from now, without waiting for a move that may not come.
    updateHover()
  }

  public func dragMoved(_ id: WindowID, to point: CGPoint) {
    guard drag?.window == id else { return }
    drag?.point = point
    if drag?.edgesNeverLeft.isEmpty == false { drag?.edgesNeverLeft.formIntersection(screenEdges(near: point)) }
    updateHover()
  }

  public func dragEnded(_ id: WindowID, at point: CGPoint) {
    guard drag?.window == id else { return }
    drag?.point = point
    if drag?.edgesNeverLeft.isEmpty == false { drag?.edgesNeverLeft.formIntersection(screenEdges(near: point)) }
    guard let session = drag else { return }
    let hover = hover(of: session)
    let held =
      hover == session.hover ? session.isActive : dwell(for: hover) <= 0
    // Let go before the target was held long enough, nothing the preview has not shown happens: a
    // floating window stays where it is. A docked one goes back to its slot rather than lie undocked over
    // the others: word of a drag reaches Arbor late, so a brisk drag ends before any hold can.
    if held { endDrag(on: hover) } else { cancelDrag() }
  }

  // MARK: The target under the pointer

  /// How long the pointer must rest on what it is over, by the options of the display that is on (F25).
  private func dwell(for hover: Hover) -> Double {
    (hover.display.map { options(for: $0) } ?? settings).dropOptions.dwell(for: hover.target)
  }

  /// Looks at what the pointer is over now. A new target shows at once or, if it is a window or a
  /// tile, after the pointer has rested on it for `dropDwell` seconds.
  func updateHover() {
    guard let session = drag else { return }
    let hover = hover(of: session)
    guard hover != session.hover else { return }
    scheduler.cancel(Self.dragDwellKey)
    drag?.hover = hover
    let dwell = dwell(for: hover)
    showHover(active: dwell <= 0)
    if dwell > 0 {
      scheduler.schedule(Self.dragDwellKey, after: dwell) { [weak self] in self?.dwellElapsed() }
    }
  }

  func dwellElapsed() {
    guard let session = drag, !session.isActive else { return }
    // ⌘ may have gone down since the pointer last moved.
    guard hover(of: session) == session.hover else { return updateHover() }
    showHover(active: true)
  }

  /// What `session`'s pointer is over.
  func hover(of session: DragSession) -> Hover {
    let point = session.point
    let held = system.modifierKeysDown()
    // First, because it holds whatever else is held: macOS asks nobody.
    if let macOSs = hoverLeftToMacOS(session, optionHeld: held.contains(.option)) { return macOSs }
    // ⌘ turns docking off: wherever it is let go, even on its own slot, the window floats. A pinned window
    // lives over docked windows, so nudging it would dock it nearly every time.
    if Self.suppressesDocking(held) || staysInView(session.window) {
      return Hover(display: displayID(at: point).flatMap { workspaces[$0] == nil ? nil : $0 }, target: .float)
    }
    if settings.reflowWhileDragging, session.isActive, let hover = session.hover,
      session.landing?.contains(point) == true
    {
      // The others have made room, so what the pointer was over has moved away from under it.
      // The gap they opened is the target now.
      return hover
    }
    return dropTarget(for: session.window, at: point)
  }

  /// The edges of the display under `point` in whose band it lies.
  private func screenEdges(near point: CGPoint) -> Set<Edge> {
    guard let id = displayID(at: point), let display = display(id) else { return [] }
    return DropResolver.screenEdges(near: point, visibleFrame: display.visibleFrame, options: options(for: id).dropOptions)
  }

  /// What `session`'s pointer is over if the window is macOS's there, otherwise nil.
  func hoverLeftToMacOS(_ session: DragSession, optionHeld: Bool) -> Hover? {
    guard let id = displayID(at: session.point), workspaces[id] != nil, let display = display(id),
      let claim = session.macTiling.claim(
        onWindowLetGoAt: session.point, on: display.frame, visibleFrame: display.visibleFrame, optionHeld: optionHeld)
    else { return nil }
    return Hover(display: id, target: .float, leftToMacOS: claim)
  }

  func dropTarget(for window: WindowID, at point: CGPoint) -> Hover {
    guard let displayID = displayID(at: point), let workspace = workspaces[displayID],
      let layout = layouts[displayID], let display = display(displayID)
    else { return Hover(display: nil, target: .float) }
    // The display under the pointer has gone, and macOS has not said yet where the pointer is now. Measured from the
    // nearest display that is one of its edges, where nobody carried the window.
    if display.frame.distance(to: point) > 1 {
      let docked = workspaces.values.contains { $0.isDocked(window) }
      return Hover(display: displayID, target: docked ? .none : .float, isNowhere: docked)
    }
    var dropOptions = options(for: displayID).dropOptions
    dropOptions.silentEdges = (drag?.macTiling.edges ?? []).union(drag?.edgesNeverLeft ?? [])
    func resolve(_ layout: Layout, _ tree: LayoutTree) -> DropTarget {
      DropResolver.resolve(
        point: point, window: window, layout: layout, tree: tree, visibleFrame: display.visibleFrame, options: dropOptions)
    }
    var seen = (layout: layout, tree: workspace.tree)
    var target = resolve(seen.layout, seen.tree)
    // With live reflow, a docked window that has left its slot is no longer in what the user
    // sees, so the pointer is matched against the arrangement without it.
    if target != .none, let lifted = arrangement(without: window, on: displayID) {
      seen = lifted
      target = resolve(seen.layout, seen.tree)
    }
    // A docked window leaves the arrangement only where that is plainly meant: over the Desktop (or with ⌘). Over the
    // middle of another window, or a gap, nothing is previewed and nothing happens: it goes back to its slot.
    if target == .float, workspaces.values.contains(where: { $0.isDocked(window) }) {
      let onDesktop =
        seen.layout.leafOrTile(at: point, in: seen.tree) == seen.tree.desktop
        || seen.layout.desktopFrame.map { floatingRegion($0, on: display).contains(point) } == true
      if !onDesktop { return Hover(display: displayID, target: .none, isNowhere: true) }
    }
    // Dropped there it would widen a held view (Controller+Hold.swift). A docked window goes back to its
    // place; a floating one stays where it is let go.
    if holdWouldLetSomethingIn(dropping: window, on: target, of: displayID) {
      let floats = workspaceID(containing: window).map { workspaces[$0]?.isFloating(window) == true } ?? false
      return Hover(display: displayID, target: floats ? .float : .none, isNowhere: !floats)
    }
    return Hover(display: displayID, target: target)
  }

  /// Shows what letting go now would do: the preview of an active target that docks, and, with
  /// live reflow, the other windows where they would end up.
  func showHover(active: Bool) {
    guard let session = drag, let hover = session.hover else { return }
    let landing = active ? hover.display.flatMap { previewFrame(for: session.window, at: hover.target, on: $0) } : nil
    drag?.isActive = active
    drag?.landing = landing
    Log.debug(
      "drag of \(session.window): \(active ? "on" : "waiting over") \(hover.target)\(hover.leftToMacOS != nil ? ", left to macOS’s tiling" : "")")
    overlays.showDropPreview(settings.previewDrags ? landing : nil)
    reflow()
  }

  func previewFrame(for window: WindowID, at target: DropTarget, on displayID: DisplayID) -> CGRect? {
    guard let workspace = workspaces[displayID], let display = display(displayID) else { return nil }
    let present = presentWindowIDs()
    let minimums = minimumSizes
    return workspace.previewFrame(
      for: window, at: target, in: display.visibleFrame, options: options(for: displayID).layoutOptions,
      isPresent: { present.contains($0) }, minimumSize: { minimums[$0] },
      makingRoom: settings.makeRoom ? roomTerms(on: displayID, docking: window) : nil)
  }

  // MARK: The arrangement changing under a drag

  /// Forgets what the pointer was over, so the next move looks afresh and holds again.
  func forgetHover() {
    guard drag != nil else { return }
    scheduler.cancel(Self.dragDwellKey)
    if drag?.landing != nil { overlays.showDropPreview(nil) }
    drag?.hover = nil
    drag?.isActive = false
    drag?.landing = nil
  }

  /// Called by every `relayout`. One that happens during a drag (a command, a window opening or
  /// closing) has put `display` back as its real tree says and may have removed the target.
  func arrangementChangedDuringDrag(on display: DisplayID, for reason: RelayoutReason) {
    guard drag != nil else { return }
    forgetHover()
    drag?.reflow.trials[display] = nil
    // What is known about its windows' sizes by now, from trials too, is what that layout went by. Forgotten at the end of
    // the drag, it would leave the layout saying something else than a fresh one.
    if drag?.reflow.minimumsBefore != nil {
      for window in workspaces[display]?.allWindows ?? [] { drag?.reflow.minimumsBefore?[window] = minimumSizes[window] }
    }
    // That layout has placed the display's floating windows for real. Unless it only put docked windows back: then
    // the ones that trials pushed aside are still there, and `settle` still has to know where from.
    guard reason != .enforce else { return }
    for window in workspaces[display]?.floating.keys.sorted() ?? [] { drag?.reflow.floatsBefore[window] = nil }
  }

  func displaysChangedDuringDrag() {
    guard drag != nil else { return }
    forgetHover()
    drag?.reflow.trials.removeAll()
    // The windows of a display that went away have been given new places. Where they were
    // before the drag may not be on any display now.
    drag?.reflow.floatsBefore.removeAll()
  }

  // MARK: The end

  /// Ends the drag in progress with the window dropped on `hover`.
  func endDrag(on hover: Hover) {
    guard let session = drag else { return }
    scheduler.cancel(Self.dragDwellKey)
    drag = nil
    overlays.showDropPreview(nil)
    finishDrop(session.window, on: hover, at: session.point, sizeOwed: session.sizeOwed, after: session.reflow)
    soleFloatDropped(session.window, from: session.sourceDisplay, leftToMacOS: hover.leftToMacOS != nil)
    noteWhereItsUserLeftIt(session.window)
    // Whoever meant Arbor's edge and got macOS's tile is told where that can be changed. Whoever held ⌥ asked macOS. Said once macOS
    // has moved the window, which it does not always do: thrown into the menu bar and let go at once, it stays as it is.
    // Whoever has no edges of Arbor's there (a band of 0) meant none.
    if let claim = hover.leftToMacOS, claim != .optionKey, let display = hover.display,
      options(for: display).dropOptions.offersScreenEdges, let letGo = windows[session.window]?.frame
    {
      scheduler.schedule(Self.leftToMacOSKey, after: 0.5) { [weak self] in
        guard let self, let now = self.windows[session.window]?.frame, now != letGo else { return }
        self.teach(.leftToMacOS, on: display)
      }
    }
  }

  /// Puts `window` where letting go of it over `hover` puts it, and lays out what that changes. The one place where a
  /// window changes its place because it was let go somewhere, whatever carried it there. `pointer` is where the
  /// pointer let go of it, if one did; `sizeOwed` and `reflow` are the drag session's.
  func finishDrop(
    _ window: WindowID, on hover: Hover, at pointer: CGPoint? = nil, sizeOwed: CGSize? = nil,
    after reflow: Reflow = Reflow()
  ) {
    let undoScope = beginUndoStep(dropping: window, on: hover.target, of: hover.display)
    defer { endUndoStep(undoScope) }
    // While the drop is laid out, a window dropped to float stays where it was dropped (`placeFloatingWindows`).
    placedOnPurpose = [window]
    defer { placedOnPurpose = [] }
    // Dropped to float, it is where its user let go of it.
    defer { noteWhereItsUserLeftIt(window) }
    var changed: [DisplayID] = []
    // The window may have closed, or its app been excluded, since it was picked up. Or it has left the screen: ⌘M, ⌘H
    // and full screen all work with the button down. What is under no pointer is dropped nowhere, and its frame
    // (the whole display, in full screen) is no place to float at. One reported on another Space is dropped all the
    // same: carried along with ⌃→ it is on this one, whatever its app's list says yet.
    if let current = windows[window], isManaged(window),
      !current.isMinimized, !current.isHidden, !current.isFullScreen,
      let display = hover.display ?? workspaceID(containing: window) ?? mainDisplayID,
      let drop = drop(
        of: window, on: hover.target, display: display, at: pointer, sizeOwed: sizeOwed, leftToMacOS: hover.leftToMacOS != nil)
    {
      let wasDocked = workspaces.values.contains { $0.isDocked(window) }
      let home = workspaceID(containing: window)
      summonedWindowIsCarried(window, to: display)
      // A drag by the title bar moves and never resizes (Controller+UndockedFrames.swift). Asked while it still floats there.
      let remembered = frameToRemember(of: window, movedFrom: current.frame, to: current.frame)
      // Asked while the display it leaves still remembers it, and noted if it is docked on the other, which may be refused.
      let own = home.flatMap { $0 == display ? nil : frameToTakeAlong(of: window, from: $0)?.size }
      changed = drop.apply(to: &workspaces)
      if let own, let arrived = workspaces[display]?.undockedFrame(of: window) {
        noteFit(of: window, own: own, into: arrived.size, on: display)
      }
      // Out of its slot, it has shrunk back to the size it floated at (Controller+UndockedFrames.swift).
      if drop.frame != current.frame {
        shrinkDropped(window, to: drop.frame, on: display)
      } else if !wasDocked, hover.target == .float {
        workspaces[display]?.floating[window] = remembered
      }
      // With the Desktop out of view it would be gone at the next move of the view: it belongs to this one.
      if wasDocked, hover.target == .float, layout(of: display)?.desktopFrame == nil {
        stayWithTheView(window, on: display)
      }
      // It floats on another display now, which no layout need show (F24's events).
      if hover.target == .float, let home, home != display { notify(.windows) }
      Log.info("dropped \(window) on \(hover.target), display \(display)\(hover.leftToMacOS != nil ? ", left to macOS’s tiling" : "")")
    }
    // Sent out of view while the hand kept it in view (a summoned window whose key was pressed again, or that lost the
    // keyboard to a new window). Now that it is free, the layout says again where it belongs.
    if parked.remove(window) != nil, let home = workspaceID(containing: window), !changed.contains(home) {
      changed.append(home)
    }
    settle(reflow, layingOut: changed)
    scheduleSave()
  }

  /// What letting go of `window` over `target` on `display` would do, for the real drop and for live reflow's trials.
  /// Made while the window is still where it was: what is remembered about a docked window goes when it is undocked.
  /// `leftToMacOS`: it floats as it is, because macOS is about to give it a frame.
  func drop(
    of window: WindowID, on target: DropTarget, display: DisplayID, at pointer: CGPoint?, sizeOwed: CGSize? = nil,
    leftToMacOS: Bool = false
  ) -> Drop? {
    guard let current = windows[window]?.frame else { return nil }
    let home = workspaceID(containing: window)
    var drop = Drop(
      window: window, target: target, display: display, frame: current, shareSpace: settings.shareRemovedSpace)
    switch target {
    case .float where leftToMacOS: break
    case .float:
      drop.frame = droppedFrame(of: window, on: home, at: pointer, sizeOwed: sizeOwed) ?? current
      // A hand on its title bar keeps some of a window on a display, unless the display has gone meanwhile.
      if isOutOfView(drop.frame), let visible = self.display(display)?.visibleFrame {
        drop.frame = drop.frame.fitted(into: visible)
      }
    case .cameraEdge, .beside, .stack:
      if let home, home != display { drop.arrivingFrame = frameAfterTransfer(of: window, from: home, to: display) }
    case .none: break
    }
    return drop
  }

  /// Ends the drag in progress, if any, without a drop: the window was let go over a target not held
  /// long enough, or no release will come, or it no longer matters. A docked window goes back to
  /// its slot and a floating one stays where it is.
  func cancelDrag() {
    guard let session = drag else { return }
    if let display = workspaceID(containing: session.window), workspaces[display]?.isDocked(session.window) == true {
      endDrag(on: Hover(display: display, target: .none))
    } else {
      endDrag(on: Hover(display: dropTarget(for: session.window, at: session.point).display, target: .float))
    }
  }
}
