import ArborCore
import CoreGraphics
import Dispatch

extension Controller {
  /// Why a display is being laid out again. It changes how floating windows
  /// are treated.
  enum RelayoutReason {
    /// The camera moved: floating windows follow the Desktop in and out of view.
    case camera
    /// The tree or the set of present windows changed: floating windows that
    /// now overlap docked space are pushed back onto the Desktop.
    case structure
    /// A docked window was moved by something other than Arbor: put it back.
    case enforce
  }

  /// `including` counts a window as present whether it is or not.
  func layout(
    of displayID: DisplayID, camera: NodeID? = nil, options: LayoutOptions? = nil, including: WindowID? = nil
  ) -> Layout? {
    guard let workspace = workspaces[displayID], let display = display(displayID) else { return nil }
    var present = presentWindowIDs()
    if let including { present.insert(including) }
    let minimums = minimumSizes
    return LayoutEngine.layout(
      workspace.tree, camera: camera ?? workspace.camera, in: display.visibleFrame,
      options: options ?? self.options(for: displayID).layoutOptions, isPresent: { present.contains($0) },
      minimumSize: { minimums[$0] })
  }

  /// What `displayID` should look like, worked out now from the arrangement, the view, the windows that take space, the
  /// settings and the sizes apps have refused. `layouts` is what it looked like when it was last laid out. The two
  /// differ when something changed the arrangement or the view and forgot to lay out, which is what tests ask this for.
  /// A held view with nothing left in it should look empty, not like what is around it (Controller+Hold.swift).
  public func freshLayout(of displayID: DisplayID) -> Layout? { layoutOfAnEmptyHeldView(on: displayID) ?? layout(of: displayID) }

  /// What `displayID` would look like with everything showing, for tests that ask what even that leaves out of view.
  public func layoutOfEverything(on displayID: DisplayID) -> Layout? { layout(of: displayID, camera: workspaces[displayID]?.tree.root) }

  func relayoutAll(reason: RelayoutReason, motion: Motion = .animated) {
    for id in workspaces.keys.sorted() { relayout(id, reason: reason, motion: motion) }
  }

  /// Lays out one display and moves windows to match. The change is shown as motion unless
  /// `motion` says otherwise (Controller+Transitions.swift); where the windows end up is the same.
  ///
  /// A command that puts windows back itself (`putBack`) and then lays out hands them over as `puttingBack`
  /// instead: nobody must see a window jump ahead of the motion that explains it, so they are moved
  /// here, first of all, once the stage is up.
  func relayout(
    _ displayID: DisplayID, reason: RelayoutReason, motion: Motion = .animated,
    puttingBack handedOver: [(window: WindowID, frame: CGRect)] = []
  ) {
    let start = DispatchTime.now()
    defer { stats.record("controller", "lay out a display", seconds: CallStats.seconds(since: start)) }
    var waiting = handedOver
    func putBackWhatWaits() {
      guard let display = display(displayID) else { return }
      for (window, frame) in waiting { putBack(window, at: frame, on: display) }
      waiting = []
    }
    // However this ends: a window that was promised a place gets it.
    defer { putBackWhatWaits() }
    guard isRunning, holdFences(displayID) else { return }
    // Not when a window is only put back where it was: that moves nothing else.
    if reason != .enforce { dropOverdueSlots(on: displayID) }
    refreshVisibleFrame(of: displayID)
    let before = workspaces[displayID]
    noteFixedSizes(of: before?.tree.allWindows ?? [])
    guard var layout = roomyLayout(of: displayID, for: reason) else { return }
    // Before anything is moved (Controller+Hold.swift). A new node alone is no move of the view: docking a window at the edge of the
    // view makes a group of the two, with the same things to see, and a rule that waited does that at the very end of a hold.
    if reason == .camera, holdLevel != .view, layouts[displayID]?.camera != layout.camera { holdLetsInWhatWaited(on: displayID) }
    if reason != .enforce, let tree = workspaces[displayID]?.tree { enforcement.reset(tree.allWindows) }
    let staged = stageTransition(on: displayID, to: layout, reason: reason, motion: motion, puttingBack: waiting)
    putBackWhatWaits()
    // Once the stage is up, like everything that moves a window.
    if askBeforeTheyLeave(layout, on: displayID),
      let known = roomyLayout(of: displayID, for: reason, startingFrom: before)
    {
      layout = known
    }
    // Before anybody is moved, so that everybody moves once (Controller+AskFirst.swift).
    layout = askingFirst(layout, on: displayID) { self.roomyLayout(of: displayID, for: reason, startingFrom: before) }
    // After the stage has its pictures of the windows where they are.
    system.moveTogether(movesInSight(for: layout, on: displayID, reason: reason))
    // A window refused its slot after all: lay out again so that room is made for it, or it becomes a tile. Or one that is
    // a tile for having refused takes the size of its slot now (Controller+LearnedSizes.swift): lay out again so it
    // gets it. A neighbour that gave room may refuse in its turn, and a window can take a size out of view and still
    // refuse it in view, so there is a second round. After that no more gaps move, and after two more there is
    // an end: an app that asks for more every time it is asked is not asked for ever.
    var again = apply(layout, on: displayID)
    if askTilesAgain(layout, on: displayID) { again = true }
    var round = 0
    while again, round < 4 {
      round += 1
      guard
        let retry = round <= 2
          ? roomyLayout(of: displayID, for: reason, startingFrom: before) : self.layout(of: displayID)
      else { break }
      layout = retry
      again = apply(layout, on: displayID)
    }
    rememberSqueezes(in: layout, on: displayID)
    placeFloatingWindows(on: displayID, layout: layout, reason: reason)
    layouts[displayID] = layout
    settleTransition(staged, on: displayID, layout: layout)
    stats.time("controller", "update overlays") {
      overlays.update(display: displayID, scene: overlayScene(for: layout, on: displayID))
    }
    arrangementChangedDuringDrag(on: displayID, for: reason)
    notify(.layout(displayID))
  }

  /// What Arbor draws on a display for `layout`. Each kind of overlay fills in its own field.
  func overlayScene(for layout: Layout, on displayID: DisplayID) -> OverlayScene {
    var scene = OverlayScene()
    scene.peekOutline = peekOutline(for: layout, on: displayID)
    scene.tiles = tileModels(for: layout, on: displayID)
    scene.seams = layout.seams
    scene.focusRing = focusRingModel(on: displayID)
    scene.namePrompt = namePromptModel(on: displayID)
    applyAppearance(to: &scene, for: layout, on: displayID)
    return scene
  }

  /// Moves docked windows into their slots and parks hidden ones. Returns
  /// true if a window refused its slot (a new minimum size was learned).
  func apply(_ layout: Layout, on displayID: DisplayID) -> Bool {
    var learnedMinimum = false
    // However this ends, an answer holds for the layout it was given in: next time a sheet may have closed.
    defer { justAnswered.removeAll() }
    // Of some nobody knows whether they can grow as far as their slot, and where they go depends on it (Controller+AskFirst.swift).
    var unknown: [(window: WindowID, slot: CGRect, question: CGRect)] = []
    // A window being dragged stays in the user's hand whatever happens to the layout meanwhile.
    for (window, target) in layout.windowFrames.sorted(by: { $0.key < $1.key }) where window != drag?.window {
      if let current = windows[window], isStillToBePlaced(current, in: target),
        let question = questionBeforePlacing(current, in: target, on: displayID)
      {
        unknown.append((window, target, question))
      } else if place(window, in: target, on: displayID) {
        learnedMinimum = true
      }
    }
    if let display = display(displayID) {
      for window in layout.hiddenWindows.sorted()
      where window != drag?.window && (!parked.contains(window) || hasLeftItsCorner(window)) {
        park(window, on: display)
      }
    }
    // They come last, so that each stands at its old place in its new size no longer than the others' answers take.
    for (window, _, question) in unknown {
      if ask(window, question, on: displayID) { learnedMinimum = true }
    }
    // All that was foretold has been asked for by now, and this foretells anew.
    let moves = unknown.compactMap { window, slot, _ in
      windows[window].flatMap { isStillToBePlaced($0, in: slot) ? (window: window, frame: request(for: $0, in: slot)) : nil }
    }
    if moves.count > 1 { system.moveTogether(moves) }
    // Whatever it answered: a window that is part of the layout is in its slot when the layout has been applied.
    for (window, slot, _) in unknown {
      if place(window, in: slot, on: displayID) { learnedMinimum = true }
    }
    return learnedMinimum
  }

  /// Moves one docked window into its slot. Returns true if it refused the slot (a new minimum size was learned).
  func place(_ window: WindowID, in target: CGRect, on displayID: DisplayID) -> Bool {
    guard let current = windows[window] else { return false }
    guard isStillToBePlaced(current, in: target) else {
      // Not a misfit's: that is where its own answer left it, which is on record.
      if isInPlace(current, at: target) || enforcement.givenUp.contains(window) { settled[window] = current.frame }
      return false
    }
    let asked = request(for: current, in: target)
    // It has answered where it stood, and that is where the answer belongs: there is nothing left to ask for.
    let isThere = justAnswered[window] != nil && !parked.contains(window) && asked.approximatelyEquals(current.frame, tolerance: 1)
    guard var actual = isThere ? current.frame : system.setFrame(asked, of: window) else {
      unplaced.insert(window)
      return false
    }
    unplaced.remove(window)
    // One that was only moved, at the size it has, has been through this where it stood.
    if asked.size == target.size { actual = askForLess(window, slot: target, took: actual) }
    // A window that cannot grow to its slot (Calculator, System Settings) sits in the middle of it,
    // which looks meant, rather than in its top-left corner, which looks broken.
    if actual.width < target.width - 2 || actual.height < target.height - 2 {
      let centred = Self.centred(actual.size, in: target)
      // One that was known not to grow is there already.
      if !actual.approximatelyEquals(centred, tolerance: 1) { actual = system.setFrame(centred, of: window) ?? actual }
    } else if asked.origin != target.origin, !actual.approximatelyEquals(target, tolerance: 1) {
      // It was not expected to grow, and has.
      actual = system.setFrame(target, of: window) ?? actual
    }
    parked.remove(window)
    windows[window]?.frame = actual
    settled[window] = actual
    misfits[window] = actual.approximatelyEquals(target, tolerance: 1) ? nil : (target, actual)
    // Only just back, it may not be ready to take a frame (Controller+OnTheWayBack.swift).
    if misfits[window] != nil, postponesJudgement(of: window, on: displayID) { return false }
    return learn(from: window, was: current.frame.size, took: actual.size, offered: target.size)
  }

  /// Whether a window already sits where it belongs, so there is no need to move it.
  func isInPlace(_ window: WindowSnapshot, at frame: CGRect) -> Bool {
    !parked.contains(window.id) && window.frame.approximatelyEquals(frame, tolerance: 1)
  }

  /// A learned minimum can be wrong: an app that resizes a moment late, or had a sheet open, looks
  /// like one that refuses to shrink, and its window would be a tile for as long as it lives.
  /// A window seen smaller than its learned minimum disproves it, so the minimum comes down to what
  /// was seen. Returns true if the window is a tile, which should now be laid out again (a window
  /// in view may be in the user's hands). An app that keeps bouncing between sizes is believed
  /// three times, so that Arbor never chases it.
  func lowerDisprovedMinimum(of window: WindowSnapshot) -> Bool {
    guard var learned = minimumSizes[window.id], disprovedMinimums[window.id, default: 0] < 3 else {
      return false
    }
    let narrower = learned.width > 0 && window.frame.width < learned.width - 2
    let shorter = learned.height > 0 && window.frame.height < learned.height - 2
    guard narrower || shorter else { return false }
    if narrower { learned.width = window.frame.width }
    if shorter { learned.height = window.frame.height }
    minimumSizes[window.id] = learned
    guard layouts.values.contains(where: { $0.tiles.contains { $0.windows.contains(window.id) } }) else {
      return false
    }
    disprovedMinimums[window.id, default: 0] += 1
    return true
  }

  /// Forgets every learned minimum, so the next layout offers each window its slot again.
  func forgetLearnedMinimums() {
    minimumSizes.removeAll()
    disprovedMinimums.removeAll()
    // How small and how large a window has been it has been. Where it stopped growing is what may have changed.
    for window in seenSizes.keys { seenSizes[window]?.forgetWhereItStopped() }
  }

  /// Counts every managed window that no display shows as parked, whoever put it there. Knowing it as
  /// parked is what brings it back: into its slot, onto the Desktop when that is in view (now, or
  /// once the window is no longer minimized, hidden or on another Space), or on screen when Arbor quits.
  func treatStrandedWindowsAsParked() {
    guard !displays.isEmpty else { return }
    for window in managedWindowIDs where window != drag?.window && isOutOfView(windows[window]!.frame) {
      // Where it was found is where it is expected to stay: macOS pulls such windows back on screen when their app is
      // shown again, and `hasLeftItsCorner` has to notice.
      parked.insert(window)
      if settled[window] == nil { settled[window] = windows[window]!.frame }
    }
  }

  /// No display shows more of `frame` than the sliver, a point or two wide, that parking leaves on screen.
  func isOutOfView(_ frame: CGRect) -> Bool {
    displays.allSatisfy { display in
      let showing = frame.intersection(display.frame)
      return showing.isNull || showing.width <= 2 || showing.height <= 2
    }
  }

  /// Moves a window out of view, leaving one point of it on screen in a
  /// bottom corner (macOS keeps windows that are fully off-screen from
  /// moving reliably).
  func park(_ window: WindowID, on display: DisplaySnapshot) {
    guard let current = windows[window] else { return }
    parkedAgain[window] = parked.contains(window) ? parkedAgain[window, default: 0] + 1 : nil
    let size = parkingSize(for: window, now: current.frame.size)
    let target = CGRect(origin: parkingOrigin(for: size, on: display), size: size)
    // A window that could not be moved is still in view: it does not count as parked, so the next
    // layout tries again.
    guard var actual = system.setFrame(target, of: window) else {
      unplaced.insert(window)
      return
    }
    // An app that answers with another size can reach back into view from a spot chosen for the old one.
    if actual.size != target.size, !isOutOfView(actual),
      let again = system.setFrame(CGRect(origin: parkingOrigin(for: actual.size, on: display), size: actual.size), of: window)
    {
      actual = again
    }
    unplaced.remove(window)
    if settings.shrinkOutOfView { actual = settleParkedSmall(window, took: actual, asked: target, on: display) }
    windows[window]?.frame = actual
    settled[window] = actual
    parked.insert(window)
  }

  /// Whether something other than Arbor has moved a parked window from where Arbor parked it. After three
  /// rounds the answer is no: whatever keeps moving it wins, rather than the two fighting for ever.
  func hasLeftItsCorner(_ window: WindowID) -> Bool {
    guard parked.contains(window), parkedAgain[window, default: 0] < 3, let current = windows[window],
      current.isPresent
    else { return false }
    // Found in a corner at launch, after a crash: where exactly is not on record, but whether it shows can be seen.
    guard let corner = settled[window] else { return !showsOnlyASliver(window) }
    return abs(current.frame.minX - corner.minX) > 4 || abs(current.frame.minY - corner.minY) > 4
  }

  /// Where a window of `size` shows least, on this display and its neighbours on every side: the bottom-right
  /// corner, the bottom-left one, below the bottom edge, or beside the display at its top (a line one point wide
  /// shows there, for when displays lie below); earlier ones win a tie.
  ///
  /// macOS does not let a window go as low as asked: its title bar stays above the Dock and the display's bottom
  /// edge (asked for 1023,767 on a display whose visible frame ends at 705, a window stopped at 1023,673). So a
  /// parked window reaches higher than its origin says, and can show on a neighbour that ends a little
  /// above this display's bottom. The places are judged by where the window would really stop.
  func parkingOrigin(for size: CGSize, on display: DisplaySnapshot) -> CGPoint {
    let frame = display.frame
    let candidates = [
      CGPoint(x: frame.maxX - 1, y: frame.maxY - 1),
      CGPoint(x: frame.minX - size.width + 1, y: frame.maxY - 1),
      CGPoint(x: frame.minX, y: frame.maxY - 1),
      CGPoint(x: frame.maxX - 1, y: frame.minY),
      CGPoint(x: frame.minX - size.width + 1, y: frame.minY),
    ]
    func showing(_ origin: CGPoint) -> CGFloat {
      let rect = CGRect(origin: whereItStops(origin), size: size)
      return displays.map { rect.intersection($0.frame).area }.reduce(0, +)
    }
    var best = (origin: candidates[0], showing: showing(candidates[0]))
    for origin in candidates.dropFirst() where showing(origin) < best.showing { best = (origin, showing(origin)) }
    return best.origin
  }

  /// How much of a window's top macOS keeps above the bottom of the visible frame (measured on macOS 26).
  static let reachableTitleBar: CGFloat = 32

  /// Where a window asked to go to `origin` ends up. The display its corner is on stops it, or the nearest one:
  /// with one display that is what was measured, with several it is a guess that the fake window system shares.
  func whereItStops(_ origin: CGPoint) -> CGPoint {
    let stopper =
      displays.first { $0.frame.contains(origin) }
      ?? displays.min { $0.frame.distance(to: origin) < $1.frame.distance(to: origin) }
    guard let stopper else { return origin }
    return CGPoint(x: origin.x, y: min(origin.y, stopper.visibleFrame.maxY - Self.reachableTitleBar))
  }

  /// Floating windows live on the Desktop. When the camera moves and the Desktop is no longer part of the view they
  /// are parked; when it is again they return to where the user left them. A Desktop too small to use, a tile, is
  /// part of the view like any other: after "show everything" nothing is out of view. While it is usable, the
  /// windows on it stay on it: each sits as near to the frame the user gave it as the Desktop allows,
  /// so docked windows push it aside or shrink it, and it goes back as they make room again. A window
  /// the user put over docked windows on purpose is left alone until the camera next brings the Desktop into view.
  ///
  /// Only a move of the camera takes a floating window out of view or gathers windows onto a Desktop that was not
  /// showing. A change of the arrangement (something else minimized, a seam, a dock) can turn the Desktop into
  /// a tile and back, and must not make the window someone is typing in shrink or vanish. Nor must a command that
  /// leaves the camera where it is (`home` at home, `back` to the same space): it changes nothing a person can see.
  func placeFloatingWindows(on displayID: DisplayID, layout: Layout, reason: RelayoutReason) {
    workspaces[displayID]?.dropGuestsThatLeft()
    guard let workspace = workspaces[displayID], let display = display(displayID) else { return }
    letGoOfWindowsNoLongerInHand(on: displayID)
    // Paid with this layout, or owed again because the app has stopped answering again (`unplaced`).
    defer { owedMoves = owedMoves.filter { !workspace.contains($0) } }
    for (window, move) in floatingMoves(on: displayID, layout: layout, reason: reason) {
      if case .fill(let desktop) = move {
        fill(desktop, with: window, on: display)
        continue
      }
      guard case .place(var target, let room) = move else {
        park(window, on: display)
        continue
      }
      if let current = windows[window], !isInPlace(current, at: target) {
        // Its app does not answer, so it is where it was, out of view if it was. It is placed when the app answers.
        guard var actual = system.setFrame(target, of: window) else {
          unplaced.insert(window)
          continue
        }
        unplaced.remove(window)
        // A few points over can be the nearest character cell, not a refusal (Controller+SizeSteps.swift), as in `apply`.
        actual = askForLess(window, slot: target, took: actual)
        if actual.width > target.width + 2 || actual.height > target.height + 2, let room,
          var preferred = workspace.floating[window]
        {
          // The app will not make it that small. Remember, so that it is placed in one move from now on.
          minimumSizes[window] = CGSize(
            width: actual.width > target.width + 2 ? actual.width : minimumSizes[window]?.width ?? 0,
            height: actual.height > target.height + 2 ? actual.height : minimumSizes[window]?.height ?? 0)
          // Nor as small as it floated, if its app's minimum has grown since. The size it had is then no size
          // to go back to, and `floatingFrame` would take it as proof that the window can be that small.
          let remembered = preferred
          if actual.width > target.width + 2 { preferred.size.width = max(preferred.width, actual.width) }
          if actual.height > target.height + 2 { preferred.size.height = max(preferred.height, actual.height) }
          // It grows away from the edge of the screen, not over it: `reach` would take that for a place its user chose,
          // and the next layout would send it there.
          preferred = preferred.fitted(into: display.visibleFrame.union(remembered))
          workspaces[displayID]?.floating[window] = preferred
          // Knowing all that can change where it should go. If it does not, the same request would get the same answer.
          let informed = floatingFrame(preferred, on: room, of: display, minimum: minimumSizes[window])
          if informed != target {
            target = informed
            actual = system.setFrame(target, of: window) ?? actual
          }
        } else if actual.width < target.width - 2 || actual.height < target.height - 2,
          displays.allSatisfy({ actual.fractionInside($0.frame) < 0.5 })
        {
          // The app will not make it that large any more. A window shrinks towards its top-left corner, so one that
          // hung over the left edge of the screen has gone beyond it. The frame it had is no frame to go back to: it
          // floats on the display from now on. One that took the frame it was asked to goes on hanging, whatever shows.
          target = actual.fitted(into: display.visibleFrame)
          workspaces[displayID]?.floating[window] = target
          actual = system.setFrame(target, of: window) ?? actual
        }
        windows[window]?.frame = actual
        // The last net, whatever the cause: what Arbor puts in view is in view.
        if showsOnlyASliver(window), let fitted = system.setFrame(actual.fitted(into: display.visibleFrame), of: window) {
          target = actual.fitted(into: display.visibleFrame)
          actual = fitted
          windows[window]?.frame = actual
          // That is where it floats from now on, or the next layout would send it off again.
          workspaces[displayID]?.floating[window] = actual
        }
        settled[window] = actual
        misfits[window] = actual.approximatelyEquals(target, tolerance: 1) ? nil : (target, actual)
      }
      // Back in view, at the place in macOS's order that it had. A guest raised over its host would cover the very
      // window its person has just switched to, which is how ⌘Tab brings a view back. ⌃⌥D shows all that floats.
      // Only a window kept in view is raised: pinned while it was out of view, this is the raise at the pin.
      if parked.remove(window) != nil, workspace.staysInView(window) { system.raise(window) }
    }
  }

  /// What a relayout does to a floating window.
  enum FloatingMove {
    /// In view at this frame. It may be there already. What lives on the Desktop has to fit `fitting`, also if its app
    /// turns out not to make it that small; a guest or a pinned window is where it belongs, whatever its size.
    case place(CGRect, fitting: CGRect?)
    case park
    /// All over the Desktop, which is this rectangle, or as near to that as its app lets it come (Controller+SoleFloat.swift).
    case fill(CGRect)
  }

  /// The floating windows `placeFloatingWindows` sees to, and what it does to each. Deciding is kept
  /// apart from moving so that a transition can be planned before anything moves.
  func floatingMoves(
    on displayID: DisplayID, layout: Layout, reason: RelayoutReason
  ) -> [(window: WindowID, move: FloatingMove)] {
    guard var workspace = workspaces[displayID], let display = display(displayID) else { return [] }
    // On a copy: a plan changes nothing.
    workspace.dropGuestsThatLeft()
    var moves: [(window: WindowID, move: FloatingMove)] = []
    // What was on screen until now. Nil at launch, when nothing is moved.
    let previous = layouts[displayID]
    let reason = reason == .camera && previous?.camera == layout.camera ? .structure : reason
    // Nobody lines a window up with the Desktop to the point. Sticking out this far still counts as on it.
    let slack = max(CGFloat(options(for: displayID).gap) * 2, 8)
    let alone = windowThatTakesDesktop(of: displayID)
    let desktopIsPartOfTheView = workspace.tree.subtree(layout.camera, contains: workspace.tree.desktop)
    for (window, preferred) in workspace.floating.sorted(by: { $0.key < $1.key }) where window != drag?.window {
      guard let current = windows[window], current.isPresent, isManaged(window), !holdKeepsOut(window) else { continue }
      if leavingView.contains(window) {
        if !parked.contains(window) { moves.append((window, .park)) }
        continue
      }
      if workspace.staysInView(window) {
        // Nearly always nothing (Controller+Pin.swift).
        if let frame = frameBringingIntoView(window, on: display) { moves.append((window, .place(frame, fitting: nil))) }
        continue
      }
      if workspace.isStashed(window) {
        if !parked.contains(window) || hasLeftItsCorner(window), drag?.window != window { moves.append((window, .park)) }
        continue
      }
      // What has just left the user's hand, or gone back to where it was, is not snatched away.
      // (Nobody puts a window where no display shows it.)
      guard !placedOnPurpose.contains(window) || showsOnlyASliver(window) else { continue }
      // A window too large for the Desktop hangs over its edge, but it is Arbor that put it there.
      let whereArborPutIt = settled[window]?.approximatelyEquals(current.frame, tolerance: 2) == true
      // Where its app opened it is not a place anybody chose. Only a move or a resize by the user is.
      let whereItsAppPutIt = appPlacedFrames[window] == preferred
      // Of a window that hangs over the edge of the screen, the part that showed is what was on the Desktop or not.
      let showed = previous.map { current.frame.intersection($0.frame) } ?? .zero
      let wasOnDesktop =
        displayArrangedAnew == displayID
        || previous?.desktopFrame.map {
          (!showed.isEmpty && $0.insetBy(dx: -slack, dy: -slack).contains(showed)) || whereArborPutIt || whereItsAppPutIt
        }
        // The Desktop was a tile, and it was Arbor that laid the window over the docked ones.
        ?? (whereArborPutIt && previous.map { workspace.tree.subtree($0.camera, contains: workspace.tree.desktop) } == true)
      // Alone on the Desktop, it takes all of it (Controller+SoleFloat.swift).
      if window == alone, let desktop = layout.desktopFrame {
        // At launch, and when windows are only being put back, just one that is out of view is touched, as below.
        if drag?.window != window,
          parked.contains(window) || isBackFromThePause(window) || (previous != nil && reason != .enforce)
        {
          moves.append((window, .fill(desktop)))
        }
        continue
      }
      if let desktop = layout.desktopFrame.map({ floatingRegion($0, on: display) }) {
        let desktopCameIntoView = reason == .camera && previous != nil && previous?.desktopFrame == nil
        // One that no display shows is out of view whoever put it there: a display that shrank, for one.
        guard
          parked.contains(window) || showsOnlyASliver(window) || isBackFromThePause(window)
            || (reason != .enforce && (wasOnDesktop || desktopCameIntoView)),
          drag?.window != window
        else { continue }
        // Where its user left it hanging over the edge of the screen, it may go on doing so. That is known, not guessed:
        // every other frame is fitted.
        let leftThere = !whereItsAppPutIt && wasLeftThereByItsUser(preferred, of: window, on: display)
        let room = leftThere ? reach(of: desktop, for: preferred, on: display) : desktop
        var frame = floatingFrame(preferred, on: room, of: display, minimum: minimumSizes[window])
        // However the remembered frame came to lie there (a display that moved, an app that took its window away):
        // where no display would show it is no place to send a window that is meant to be in view.
        if showsOnlyASliver(frame) { frame = frame.fitted(into: desktop.intersection(display.visibleFrame)) }
        // It could not take this frame and is still where that attempt left it. Asking again at every layout, which
        // is every step of a dragged gap, is a round trip to its app each time for the same answer (as in `apply`).
        // Not if that left it where nothing of it shows.
        if !parked.contains(window), !showsOnlyASliver(window), let misfit = misfits[window], misfit.slot == frame,
          current.frame.approximatelyEquals(misfit.frame, tolerance: 1)
        {
          continue
        }
        moves.append((window, .place(frame, fitting: room)))
      } else if desktopIsPartOfTheView || hostInView(of: window, in: workspace, layout: layout) != nil {
        // The Desktop is in the view, only too small to use: its windows are in view all the same, where the docked
        // ones are. So is a guest of a space in view (Controller+Guests.swift). Each is where the user last had it.
        guard drag?.window != window,
          parked.contains(window) || showsOnlyASliver(window) || isBackFromThePause(window)
            || (reason == .camera && whereArborPutIt)
        else { continue }
        moves.append((window, .place(preferred.fitted(into: display.visibleFrame), fitting: nil)))
      } else if !parked.contains(window), reason == .camera || showsOnlyASliver(window) || owedMoves.contains(window),
        drag?.window != window
      {
        // The second case: a display that shrank left it where nothing shows it. Parked, it comes back when it is
        // switched to. The third: its app did not answer when the camera moved.
        moves.append((window, .park))
      } else if hasLeftItsCorner(window) {
        moves.append((window, .park))
      }
    }
    return moves
  }

  /// Where floating windows may be: the Desktop, out to the edge of the screen on the sides where nothing is docked
  /// beside it. The gap there is a margin for docked windows, not one the Desktop has to keep free.
  func floatingRegion(_ desktop: CGRect, on display: DisplaySnapshot) -> CGRect {
    let visible = display.visibleFrame
    let margin = options(for: display.id).layoutOptions.outerGap
    let content = visible.insetBy(dx: margin, dy: margin)
    let minX = desktop.minX <= content.minX + 1 ? visible.minX : desktop.minX
    let minY = desktop.minY <= content.minY + 1 ? visible.minY : desktop.minY
    let maxX = desktop.maxX >= content.maxX - 1 ? visible.maxX : desktop.maxX
    let maxY = desktop.maxY >= content.maxY - 1 ? visible.maxY : desktop.maxY
    return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
  }

  /// `region`, and beyond the edge of the screen as far as `preferred` hangs over it. People leave windows like that on
  /// purpose, some pushed aside until only a strip shows, and where the region reaches the edge nothing is docked
  /// beyond it that would need the room. Asked only for a frame its user is known to have left (`wasLeftThereByItsUser`). Not over the top: macOS lets no title bar under the menu bar. And not if what
  /// would show is too little to see and grab: that is no place anybody chose on this display, but one left over
  /// from a larger or another one.
  func reach(of region: CGRect, for preferred: CGRect, on display: DisplaySnapshot) -> CGRect {
    let visible = display.visibleFrame
    let showing = preferred.intersection(visible)
    guard !showing.isEmpty, showing.width >= Self.leastStrip, showing.height >= Self.leastStrip,
      preferred.minY >= visible.minY, preferred.minY <= visible.maxY - Self.leastStrip
    else { return region }
    let minX = region.minX <= visible.minX ? min(region.minX, preferred.minX) : region.minX
    let maxX = region.maxX >= visible.maxX ? max(region.maxX, preferred.maxX) : region.maxX
    let maxY = region.maxY >= visible.maxY ? max(region.maxY, preferred.maxY) : region.maxY
    return CGRect(x: minX, y: region.minY, width: maxX - minX, height: maxY - region.minY)
  }

  /// The user's own hand has just given floating `window` the frame now remembered for it: a move or a resize, a drop.
  /// Only such a frame may hang over the edge of the screen when Arbor places the window (`reach`), and only on the display
  /// as it is shaped and placed at this moment. That a frame overlaps a display by a strip says nothing: it may be left
  /// over from a larger display, from another one, or from one that stood elsewhere. The note is not saved, and a frame
  /// written by anybody else no longer equals it. Where in doubt, the window is wholly in view.
  func noteWhereItsUserLeftIt(_ window: WindowID) {
    forgetFitUnlessItStillHolds(window)
    guard let home = workspaceID(containing: window), let frame = workspaces[home]?.floating[window],
      let display = display(home)
    else { return chosenOnShape[window] = nil }
    chosenOnShape[window] = (frame, display.frame)
  }

  func wasLeftThereByItsUser(_ preferred: CGRect, of window: WindowID, on display: DisplaySnapshot) -> Bool {
    guard let chosen = chosenOnShape[window] else { return false }
    return chosen.frame == preferred && chosen.display == display.frame
  }

  /// The narrowest strip of a window that counts as a place for it: about a title bar's height, both ways.
  static let leastStrip: CGFloat = 24

  /// The frame nearest to `preferred` that is on `desktop`. A window whose app will not make it smaller than
  /// `minimum` cannot fit: it sits in the middle of the Desktop and hangs over the docked windows on both sides
  /// alike, rather than hide one of them altogether, but never over the edge of the screen.
  func floatingFrame(
    _ preferred: CGRect, on desktop: CGRect, of display: DisplaySnapshot, minimum: CGSize?
  ) -> CGRect {
    var frame = preferred.fitted(into: desktop)
    guard let minimum else { return frame }
    frame.size.width = max(frame.width, min(minimum.width, preferred.width))
    frame.size.height = max(frame.height, min(minimum.height, preferred.height))
    // How far it may hang over: to the edge of the screen, or where the Desktop is the last thing before that edge, to
    // the Desktop's own, so that it does not slide into the margin.
    let visible = display.visibleFrame
    let margin = options(for: display.id).layoutOptions.outerGap + 1
    if frame.width > desktop.width {
      let least = desktop.minX - visible.minX <= margin ? desktop.minX : visible.minX
      let most = visible.maxX - desktop.maxX <= margin ? desktop.maxX : visible.maxX
      frame.origin.x = max(min(desktop.midX - frame.width / 2, most - frame.width), least)
    }
    if frame.height > desktop.height {
      let most = visible.maxY - desktop.maxY <= margin ? desktop.maxY : visible.maxY
      frame.origin.y = max(min(desktop.midY - frame.height / 2, most - frame.height), visible.minY)
    }
    return frame
  }

  func tileModels(for layout: Layout, on displayID: DisplayID) -> [TileModel] {
    layout.tiles.map { tile in
      TileModel(
        display: displayID, node: tile.node, kind: tile.kind, frame: tile.frame,
        items: tile.windows.compactMap { window in
          guard let snapshot = windows[window] else { return nil }
          return TileModel.Item(
            window: window, pid: snapshot.pid, bundleID: snapshot.bundleID,
            appName: snapshot.appName, miniatureFrame: tile.miniature[window])
        }, name: spaceName(of: tile.node, on: displayID))
    }
  }

  // MARK: Camera

  /// Moves the camera on a display, lays it out, and makes sure keyboard
  /// focus is not left on a window that just went out of view. A caller that
  /// is about to focus a window of its own choice passes `refocus: false`. One that lays out itself passes `layingOut: false`.
  func moveCamera(
    on displayID: DisplayID, to node: NodeID, record: Bool = true, refocus: Bool = true, layingOut: Bool = true
  ) {
    // The last line of defence: whoever asks, a held view does not move (Controller+Hold.swift).
    guard workspaces[displayID] != nil, holdLevel != .view else { return }
    peekYields(on: displayID)
    expectFocusToMove()
    let before = workspaces[displayID]!.camera
    // This is the last move now, and only a move that followed the focus may be taken back (Controller+Focus.swift).
    keyboardHandOver.reveal = nil
    unframedIntoATile = nil
    workspaces[displayID]!.moveCamera(to: node, record: record)
    if layingOut { relayout(displayID, reason: .camera) }
    // A command that leaves the view where it is changes nothing a person can see, the focus included.
    let moved = workspaces[displayID]!.camera != before
    if refocus { ensureFocusIsVisible(on: displayID, alsoFromAPinnedWindow: moved, alsoFromNothing: moved) }
    notify(.camera(displayID))
    scheduleSave()
  }

  /// If the focused window was just parked, or nothing is focused, focuses a window in view: the one used last. Of
  /// windows never used, the one under the pointer (a floating one first: more often than not it lies in
  /// front), or the top-left one.
  /// Returns whether it did.
  ///
  /// The one used last is also the one that was in front when the view left. Focusing raises, so a framed window
  /// given the focus would cover a guest that was used after it.
  @discardableResult
  func ensureFocusIsVisible(
    on displayID: DisplayID, alsoFromAPinnedWindow: Bool = false, alsoFromNothing: Bool = true
  ) -> Bool {
    // A command that moves the view says where the attention goes, so the keyboard goes along, also out of a
    // pinned window, which is still in view: keys meant for the window that arrived must not end up in a call.
    // An app can go on naming a window in the Dock as its focused one.
    let nobody =
      system.focusedWindow().map {
        parked.contains($0) || (alsoFromNothing && windows[$0]?.isMinimized == true)
          || (alsoFromAPinnedWindow && staysInView($0))
      } ?? alsoFromNothing
    return nobody && giveTheKeyboardToTheView(on: displayID)
  }

  /// The choice itself, for a caller that knows the keyboard has to come (a peek that landed beside it).
  @discardableResult
  func giveTheKeyboardToTheView(on displayID: DisplayID) -> Bool {
    guard let layout = layouts[displayID], let workspace = workspaces[displayID] else { return false }
    // The layout can be a moment behind the windows (an app being hidden is laid out once all are reported).
    var candidates = layout.windowFrames.filter { windows[$0.key]?.isPresent == true }
    // Not a pinned window: it did not just arrive, and keys typed into a call by surprise do harm.
    for window in workspace.floating.keys where !parked.contains(window) && !workspace.staysInView(window) {
      if let frame = windows[window]?.frame, windows[window]?.isPresent == true {
        candidates[window] = frame
      }
    }
    // In a fixed order: windows overlap and frames tie, and the choice must not depend on a dictionary's.
    let ordered = candidates.sorted {
      ($0.value.minY, $0.value.minX, $0.key.rawValue) < ($1.value.minY, $1.value.minX, $1.key.rawValue)
    }
    let cursor = system.cursorLocation()
    let underPointer = ordered.filter { $0.value.contains(cursor) }
    let target =
      focusHistory.first { candidates[$0] != nil }
      ?? (underPointer.first { workspace.isFloating($0.key) } ?? underPointer.first ?? ordered.first)?.key
    if let target { askForTheKeyboard(for: target) }
    return target != nil
  }

  /// Whether the view is on one space that is not a group: a window, a tab group, the Desktop. Then the level is kept:
  /// switching to a window out of view (⌘Tab, a click in the Dock) frames that one. Someone who lives framed
  /// must not lose the frame at the first ⌘Tab, nor show the neighbours on a shared screen.
  func isFramedOnOneSpace(_ workspace: Workspace) -> Bool {
    workspace.camera != workspace.tree.root
      && (workspace.tree.isStack(workspace.camera) || workspace.camera == workspace.tree.desktop)
  }

  /// Brings a docked window into view. From a view on one space, by framing it (`isFramedOnOneSpace`). From a
  /// group or everything, by zooming out just far enough, or onto the window itself if it would be too small at
  /// that level.
  ///
  /// `onItsWayBack`: the window has been asked out of the Dock or out of ⌘H, and macOS has not said yet that it
  /// is back. The view is picked as if it were, so it does not depend on when that report comes.
  func reveal(_ window: WindowID, leaf: NodeID, on displayID: DisplayID, onItsWayBack: Bool = false) {
    guard workspaces[displayID] != nil else { return }
    moveCamera(on: displayID, to: viewThatShows(window, leaf: leaf, on: displayID, onItsWayBack: onItsWayBack))
  }

  /// Where `reveal` goes.
  func viewThatShows(_ window: WindowID, leaf: NodeID, on displayID: DisplayID, onItsWayBack: Bool = false) -> NodeID {
    guard let workspace = workspaces[displayID], !isFramedOnOneSpace(workspace) else { return leaf }
    let common = Navigation.commonAncestor(workspace.camera, leaf, in: workspace.tree)
    let trial = layout(of: displayID, camera: common, including: onItsWayBack ? window : nil)
    return trial?.windowFrames[window] != nil ? common : leaf
  }

  /// The view that brings a floating window in: out until the Desktop is part of the view, as a tile if need be. Onto the
  /// Desktop itself if the view is on one window, whose level is kept (`isFramedOnOneSpace`).
  func viewThatBringsInWhatFloats(in workspace: Workspace) -> NodeID {
    let desktop = workspace.tree.desktop
    return isFramedOnOneSpace(workspace) ? desktop : Navigation.commonAncestor(workspace.camera, desktop, in: workspace.tree)
  }

  func scheduleEnforce(_ displayID: DisplayID, havingWaitedForTheDisplays turns: Int = 0) {
    scheduler.schedule("enforce-\(displayID.rawValue)", after: 0.25) { [weak self] in
      guard let self else { return }
      if self.system.isMouseButtonDown() || self.isAwaitingResizeEnd(on: displayID)
        || self.someoneIsOnItsWayOutOfFullScreen(on: displayID)
      {
        self.scheduleEnforce(displayID)
        return
      }
      // Asked now and not when it was scheduled: an app can speak of its window before macOS's list of displays changes. A put-back
      // lays out the whole display, which may be the one that is gone. It waits for the report, which looks after every window, or
      // for the displays to be as they were; for as long as the look-out for a blink does, after which the report has to do.
      guard self.knowsTheDisplays else {
        if Double(turns) * 0.25 < Double(Self.blinkTries) * (DisplayChange.comingAndGoing + 0.5) {
          self.scheduleEnforce(displayID, havingWaitedForTheDisplays: turns + 1)
        }
        return
      }
      self.countPutBacks(on: displayID)
      self.relayout(displayID, reason: .enforce)
    }
  }
}
