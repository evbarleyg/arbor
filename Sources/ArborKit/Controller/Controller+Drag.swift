import ArborCore
import CoreGraphics
import Foundation

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
    /// Nothing is offered, by what is set and what is held (`dragDocks`): the drag is a plain one.
    var isPlain = false
  }

  /// A drag in progress, from `dragBegan` to `endDrag(on:)`.
  struct DragSession {
    var window: WindowID
    /// The display whose workspace held the window when the drag began.
    var sourceDisplay: DisplayID?
    /// Where the pointer was last seen.
    var point: CGPoint
    /// Where the pointer was when word of the drag came, and the window's place then: where Arbor had put it, or where Arbor knew a
    /// window to be that the layout does not place (`isASlip`).
    var taken: (at: CGPoint, frame: CGRect?)
    /// Whether the drag was a plain one when Arbor last looked. For a drag that ends without a release: which keys were down when
    /// the button came up, nobody knows by then.
    var wasPlain = false
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
    /// until the pointer has left the band once. With ⌘ held too: a ⌘-click on such a title bar that slips would dock the window.
    /// Where it took hold is a matter of where the window stood (`whereTheHandTook`).
    var edgesNeverLeft: Set<Edge> = []
  }

  /// When a dragged window docks, as it is set.
  var dragDocks: DragDocks { DragDocks(setting: settings.dragDocks) }

  /// What a command that finds nothing docked tells a newcomer to do.
  var howToDockAFirstWindow: String { (dragDocks.howToDockByDragging.map { "\($0), or " } ?? "") + "try `dock left`" }

  /// How far a docked window must have been carried for a plain drag to have taken it out of its place. A click on a title bar
  /// slips by a few points, and nobody who clicked meant to undock a window and see it change its size.
  static let slip: CGFloat = 24
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
    // A second press that drags is no double-click.
    aHandTakes(id)
    guard isRunning, isManaged(id) else { return }
    rememberDragOrigin(of: id)
    // Out of view a floating window may have been made small (`shrinkOutOfView`). It takes its own size when it is let go. (A docked
    // one that is let go over the Desktop takes the size it floated at, as ever.)
    let wasMadeSmall = parked.contains(id) && sizeInView(of: id) != windows[id]?.frame.size
    // So does one that fills the view: it comes out of that as a docked window comes out of its slot (Controller+Fill.swift).
    let own = wasMadeSmall ? workspaceID(containing: id).flatMap { workspaces[$0]?.floating[id]?.size } : ownSizeOfFilledWindow(id)
    // Whatever Arbor did with it before, it is in the user's hand and in view now.
    parked.remove(id)
    // Word of a drag can come after word of where it has carried the window. Where Arbor put a docked one is older than both: the frame
    // it took, which is not its slot's if it cannot grow to that (a calculator lies in the middle of its slot).
    // Of any other, what Arbor knew when the button went down.
    let slot = workspaceID(containing: id).flatMap { layouts[$0]?.windowFrames[id] }
    let place = slot.map { settled[id] ?? $0 } ?? whereItStoodAtThePress(id) ?? windows[id]?.frame
    drag = DragSession(window: id, sourceDisplay: workspaceID(containing: id), point: point, taken: (point, place))
    // Asked at every drag: people change it while Arbor runs, in the window that Check Setup sent them to.
    drag?.macTiling = system.macTiling()
    drag?.edgesNeverLeft = screenEdges(near: point).intersection(screenEdges(near: whereTheHandTook(place, nearest: point)))
    drag?.sizeOwed = own
    soleFloatTakenInHand(id)
    // Word of a drag can come late, when the pointer has already stopped where it is going. The
    // hold counts from now, without waiting for a move that may not come.
    updateHover()
  }

  public func dragMoved(_ id: WindowID, to point: CGPoint) {
    actsOfAHand += 1
    defer { actsOfAHand -= 1 }
    guard drag?.window == id else { return }
    drag?.point = point
    if drag?.edgesNeverLeft.isEmpty == false { drag?.edgesNeverLeft.formIntersection(screenEdges(near: point)) }
    updateHover()
  }

  public func dragEnded(_ id: WindowID, at point: CGPoint) {
    actsOfAHand += 1
    defer { actsOfAHand -= 1 }
    guard drag?.window == id else { return }
    drag?.point = point
    if drag?.edgesNeverLeft.isEmpty == false { drag?.edgesNeverLeft.formIntersection(screenEdges(near: point)) }
    guard let session = drag else { return }
    let hover = hover(of: session)
    drag?.wasPlain = hover.isPlain
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
    drag?.wasPlain = hover.isPlain
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
    // ⌘ may have gone down or up since the pointer last moved.
    guard hover(of: session) == session.hover else { return updateHover() }
    showHover(active: true)
  }

  /// What `session`'s pointer is over.
  func hover(of session: DragSession) -> Hover {
    let point = session.point
    let held = system.modifierKeysDown()
    let isPlain = !dragDocks.docks(holding: held)
    // First, because it holds whatever else is held: macOS asks nobody.
    if var macOSs = hoverLeftToMacOS(session, optionHeld: held.contains(.option)) {
      macOSs.isPlain = isPlain
      return macOSs
    }
    // A plain drag is macOS's own: wherever it is let go, even on its own slot, the window floats, and nothing is shown on the
    // way. Only with ⌘ held is anything offered (`dragDocks`). A pinned window lives over docked windows, so nudging it
    // would dock it nearly every time.
    if isPlain || staysInView(session.window) {
      // Where every drag docks, ⌘ is held to take a window out, wherever. Otherwise nobody has said so, and a docked window that has
      // hardly left its place was not taken out of it.
      let saidSo = dragDocks == .always && DragDocks.isKeyHeld(held)
      return saidSo ? dropTarget(for: session.window, at: point, offering: false) : plainDrop(of: session)
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

  /// What letting go of a plain drag does: the window floats where it lies, but a docked one that has only slipped goes back.
  func plainDrop(of session: DragSession) -> Hover {
    if isASlip(session), let home = workspaceID(containing: session.window), workspaces[home]?.isDocked(session.window) == true {
      return Hover(display: home, target: .none, isPlain: true)
    }
    return dropTarget(for: session.window, at: session.point, offering: false)
  }

  /// Whether the hand has carried `session`'s window less than `slip` from its place. Both the window and the pointer have to
  /// say so: word of where a window is can be a moment old, and word of a drag can come when the pointer is nearly there.
  func isASlip(_ session: DragSession) -> Bool {
    guard let before = session.taken.frame, let now = windows[session.window]?.frame else { return false }
    return hypot(now.minX - before.minX, now.minY - before.minY) < Self.slip
      && hypot(session.point.x - session.taken.at.x, session.point.y - session.taken.at.y) < Self.slip
  }

  /// Called at every press of the button, before anything it moves is heard of.
  func noteWhereWindowsStandAtAPress() { lastPress = (now(), windows.mapValues(\.frame)) }

  /// Where Arbor knew `window` to be when the button went down for the drag that begins now. Not every press is heard of, so one of
  /// a while ago is none of this drag's: word of a drag comes within a second of its press.
  private func whereItStoodAtThePress(_ window: WindowID) -> CGRect? {
    guard let press = lastPress, now().timeIntervalSince(press.at) < Self.aPressIsRemembered else { return nil }
    return press.frames[window]
  }
  static let aPressIsRemembered: TimeInterval = 3

  /// Where the hand took hold of a window that stood at `place`, as near as can be told: the point of its title bar nearest to the
  /// pointer. A busy Mac serves the press late, and word of the drag comes with the pointer at the edge the window was carried to.
  /// A drag began where the window stood when the button went down, not where the pointer is when Arbor hears of it.
  private func whereTheHandTook(_ place: CGRect?, nearest point: CGPoint) -> CGPoint {
    guard let place else { return point }
    return CGPoint(
      x: min(max(point.x, place.minX), place.maxX),
      y: min(max(point.y, place.minY), place.minY + min(Self.titleBarReach, place.height)))
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

  /// What a window let go at `point` is let go over. Not `offering`: nowhere to dock, so it floats, unless that cannot be.
  func dropTarget(for window: WindowID, at point: CGPoint, offering: Bool = true) -> Hover {
    var hover = whatIsUnder(point, for: window, offering: offering)
    hover.isPlain = !offering
    return hover
  }

  private func whatIsUnder(_ point: CGPoint, for window: WindowID, offering: Bool) -> Hover {
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
      guard offering else { return .float }
      return DropResolver.resolve(
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
    // While it is offered places to dock, a docked window leaves the arrangement only where that is plainly meant: over the
    // Desktop. Over the middle of another window, or a gap, nothing is previewed and nothing happens: it goes back to its slot.
    if offering, target == .float, workspaces.values.contains(where: { $0.isDocked(window) }) {
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
    // the ones that trials pushed aside are still there, and `settle` still has to know where from. The same where nothing is kept for
    // the Desktop: what floats lies over the docked windows there and no layout places it, while a trial, with the window
    // in the hand out of its slot, had a Desktop to push it onto.
    guard reason != .enforce, let layout = layouts[display], let workspace = workspaces[display],
      layout.desktopFrame != nil || !showsWhatFloats(layout, in: workspace)
    else { return }
    for window in workspaces[display]?.floating.keys.sorted() ?? [] { drag?.reflow.floatsBefore[window] = nil }
  }

  func displaysChangedDuringDrag() {
    guard drag != nil else { return }
    forgetHover()
    drag?.reflow.trials.removeAll()
    // The windows of a display that went away have been given new places. Where they were
    // before the drag may not be on any display now. (The rest is for the layouts that follow: `arrangementChangedDuringDrag`.)
    let visible = displays.map(\.visibleFrame)
    let still = drag?.reflow.floatsBefore.filter { _, was in visible.contains { $0.contains(was.frame) } }
    drag?.reflow.floatsBefore = still ?? [:]
  }

  // MARK: The end

  /// Ends the drag in progress with the window dropped on `hover`.
  func endDrag(on hover: Hover) {
    guard let session = drag else { return }
    scheduler.cancel(Self.dragDwellKey)
    drag = nil
    aHandWasOn(session.window)
    overlays.showDropPreview(nil)
    // The hand slipped on a window that fills the view: it has been carried nowhere, and goes on filling it.
    let hover = isFilled(session.window) && isASlip(session) ? Hover(display: session.sourceDisplay, target: .none) : hover
    finishDrop(session.window, on: hover, at: session.point, sizeOwed: session.sizeOwed, after: session.reflow)
    filledWindowDropped(session.window)
    soleFloatDropped(session.window, from: session.sourceDisplay, leftToMacOS: hover.leftToMacOS != nil)
    noteWhereItsUserLeftIt(session.window)
    // Whoever meant Arbor's edge and got macOS's tile is told where that can be changed. Whoever held ⌥ asked macOS, and so did
    // whoever dragged it there while Arbor offered nothing. Said once macOS has moved the window, which it does not always
    // do: thrown into the menu bar and let go at once, it stays as it is. Whoever has no edges of Arbor's there (a band
    // of 0) meant none.
    if let claim = hover.leftToMacOS, claim != .optionKey, !hover.isPlain, let display = hover.display, options(for: display).dropOptions.offersScreenEdges, let letGo = windows[session.window]?.frame
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
  /// `settling: false`: whoever drops several windows at once lays out once, afterwards, the displays this returns. `whole`: no hand holds it, so
  /// in its own size it is slid onto the display as far as it takes.
  @discardableResult
  func finishDrop(
    _ window: WindowID, on hover: Hover, at pointer: CGPoint? = nil, sizeOwed: CGSize? = nil,
    after reflow: Reflow = Reflow(), settling: Bool = true, whole: Bool = false
  ) -> [DisplayID] {
    var undoScope = beginUndoStep(dropping: window, on: hover.target, of: hover.display)
    // A plain drag of a floating window is what it is without Arbor, to another display too: nothing is left for Undo to take back.
    // (One that fills the view has Arbor's size, as a docked one has, and comes out of it.)
    if hover.isPlain, !isFilled(window), !workspaces.values.contains(where: { $0.isDocked(window) }) { undoScope?.before = [:] }
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
        of: window, on: hover.target, display: display, at: pointer, sizeOwed: sizeOwed, leftToMacOS: hover.leftToMacOS != nil,
        whole: whole)
    {
      let wasDocked = workspaces.values.contains { $0.isDocked(window) }
      let home = workspaceID(containing: window)
      summonedWindowIsCarried(window, to: display)
      // A drag by the title bar moves and never resizes (Controller+UndockedFrames.swift). Asked while it still floats there.
      // The size of a fill is Arbor's: where it lies, its own size is what is remembered (Controller+Fill.swift).
      let remembered =
        ownSizeOfFilledWindow(window).map { CGRect(origin: current.frame.origin, size: $0) }
        ?? frameToRemember(of: window, movedFrom: current.frame, to: current.frame)
      // Asked while the display it leaves still remembers it, and noted if it is docked on the other, which may be refused.
      let own = home.flatMap { $0 == display ? nil : frameToTakeAlong(of: window, from: $0)?.size }
      changed = drop.apply(to: &workspaces)
      // Let go to float, a window that filled the view is out of that, in its own size (`sizeOwed`).
      if hover.target == .float, unmarkFill(of: window, on: display), hover.leftToMacOS != nil {
        lookAtWhatMacOSMadeOfAFilledWindow(window, letGoAt: current.frame)
      }
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
      if hover.target == .float { aHandHasPlaced(window) }
      // It floats on another display now, which no layout need show (F24's events).
      if hover.target == .float, let home, home != display { notify(.windows) }
      Log.info("dropped \(window) on \(hover.target), display \(display)\(hover.leftToMacOS != nil ? ", left to macOS’s tiling" : "")")
    }
    // Sent out of view while the hand kept it in view (a summoned window whose key was pressed again, or that lost the
    // keyboard to a new window). Now that it is free, the layout says again where it belongs.
    if parked.remove(window) != nil, let home = workspaceID(containing: window), !changed.contains(home) {
      changed.append(home)
    }
    if settling { settle(reflow, layingOut: changed) }
    scheduleSave()
    return changed
  }

  /// What letting go of `window` over `target` on `display` would do, for the real drop and for live reflow's trials.
  /// Made while the window is still where it was: what is remembered about a docked window goes when it is undocked.
  /// `leftToMacOS`: it floats as it is, because macOS is about to give it a frame.
  func drop(
    of window: WindowID, on target: DropTarget, display: DisplayID, at pointer: CGPoint?, sizeOwed: CGSize? = nil,
    leftToMacOS: Bool = false, whole: Bool = false
  ) -> Drop? {
    guard let current = windows[window]?.frame else { return nil }
    let home = workspaceID(containing: window)
    var drop = Drop(
      window: window, target: target, display: display, frame: current, shareSpace: settings.shareRemovedSpace, desktopColumn: settings.desktopColumn)
    switch target {
    case .float where leftToMacOS: break
    case .float:
      drop.frame = droppedFrame(of: window, on: home, at: pointer, sizeOwed: sizeOwed) ?? current
      // A hand on its title bar keeps some of a window on a display, unless the display has gone meanwhile.
      if whole || isOutOfView(drop.frame), let visible = self.display(display)?.visibleFrame {
        drop.frame = drop.frame.fitted(into: visible)
      }
      // One that filled the view shrinks at the drop, which is Arbor's doing: not to where less than half of it shows.
      if isFilled(window), let screen = self.display(display), drop.frame.fractionInside(screen.frame) < 0.5 {
        drop.frame = drop.frame.fitted(into: screen.visibleFrame)
      }
    case .cameraEdge, .beside, .stack:
      if let home, home != display { drop.arrivingFrame = frameAfterTransfer(of: window, from: home, to: display) }
    case .none: break
    }
    return drop
  }

  /// Ends the drag in progress, if any, without a drop: the window was let go over a target not held
  /// long enough, or no release will come, or it no longer matters. A docked window goes back to
  /// its slot and a floating one stays where it is. But where a drag docks only when asked, a plain one means out, wherever it
  /// ends: what it has carried out of its place floats where it lies.
  func cancelDrag() {
    guard let session = drag else { return }
    if let display = workspaceID(containing: session.window), workspaces[display]?.isDocked(session.window) == true {
      let isOut = session.wasPlain && dragDocks != .always
      endDrag(on: isOut ? plainDrop(of: session) : Hover(display: display, target: .none))
    } else {
      endDrag(on: Hover(display: dropTarget(for: session.window, at: session.point).display, target: .float, isPlain: session.wasPlain))
    }
  }

  /// The same for Arbor letting go of every window (a quit, a pause). A docked window in the hand is about to get its own frame,
  /// and does not go to its slot first; what trials of the drop have moved is about to be given back as well.
  func cancelDragLettingGo() {
    guard let session = drag, workspaces.values.contains(where: { $0.isDocked(session.window) }) else { return cancelDrag() }
    scheduler.cancel(Self.dragDwellKey)
    drag = nil
    dragOrigin = nil
    overlays.showDropPreview(nil)
    // As `settle` does: what a trial taught goes with the trials.
    if let known = session.reflow.minimumsBefore { minimumSizes = known.filter { windows[$0.key] != nil } }
  }
}
