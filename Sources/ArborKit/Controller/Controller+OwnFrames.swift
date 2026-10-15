import ArborCore
import CoreGraphics

/// A floating window's frame is its person's (collab/QUESTIONS.md, Q20): **Arbor sets a floating window's frame only to take it
/// out of view and to put it back exactly where it was.**
///
/// That is how Arbor ships, with `floatingWindowsMakeWay` off. No layout places, shoves or squeezes a floating window; one
/// that floats alone is not stretched over the Desktop (F18); and when room is made for docked windows the Desktop counts
/// as not in use (F61). Floating and docked windows may overlap, as windows on a Mac do, and macOS's order says which
/// is in front.
///
/// With the setting on, floating windows are kept on the Desktop as they were until Q20: `floatingMoves` places them,
/// and everything that follows from that (own sizes of squeezed windows, pushed windows going back) is at work.
///
/// `Workspace.floating` holds the frame the window's person gave it, as ever. With the setting off that is also where the
/// window is, for as long as it is in view.
extension Controller {
  // MARK: Out of view and back

  /// What a layout does to a window that lives on the Desktop, or is the guest of a space: nothing, while it is where it
  /// belongs. `reason` is `.camera` only if the view really moved (`floatingMoves`).
  func moveKeepingItsFrame(
    _ window: WindowID, floatingAt own: CGRect, in workspace: Workspace, layout: Layout, desktopIsInView: Bool,
    reason: RelayoutReason, isTheFirstLayout: Bool, on display: DisplaySnapshot
  ) -> FloatingMove? {
    // (In view as a tile too: however small the Desktop is drawn, its windows are in view with it.)
    if desktopIsInView || hostInView(of: window, in: workspace, layout: layout) != nil {
      // One that no display shows is out of view whoever put it there. And one that is nowhere a window can be used, where no hand
      // is known to have left it, is what a change of displays made of it while Arbor could not act (its app hung, Arbor had
      // crashed): never lost outranks never moved. Not at a start, which sets no frame (Q16): the next layout, ⌃⌥0 for one.
      guard
        parked.contains(window) || showsOnlyASliver(window)
          || (!isTheFirstLayout && windows[window].map { !isAPlace($0.frame) && !wasLeftThereByItsUser($0.frame, of: window, on: display) } == true)
      else { return nil }
      // Nothing is raised: going out of view and coming back changes nobody's place in macOS's order.
      return .putBack(whereItWas(own, of: window, on: display))
    }
    if parked.contains(window) { return hasLeftItsCorner(window) ? .park : nil }
    // Only a move of the view takes it away. Or a display that shrank has left it where nothing shows it: parked, it
    // comes back when it is switched to. Or its app did not answer when the view moved.
    return reason == .camera || showsOnlyASliver(window) || owedMoves.contains(window) ? .park : nil
  }

  /// Called before a layout takes `window` out of view. Where it is at that moment is where it comes back to: whoever put
  /// it there, and whether or not Arbor has heard of it (moved while Arbor was not running, say). That its person's own hand
  /// left it there is not noted here: a frame of which less than half shows has to have that on record already
  /// (`noteWhereItsUserLeftIt`), or it may be what a change of displays made of it, during a pause for one.
  func noteWhereItLeavesFrom(_ window: WindowID, on displayID: DisplayID) {
    guard !settings.floatingWindowsMakeWay, !parked.contains(window), !showsOnlyASliver(window),
      // An undo that sends it out of view finds it in the shape of the slot it was docked in.
      !leavingView.contains(window), workspaces[displayID]?.role(of: window) == nil, let frame = windows[window]?.frame,
      let own = workspaces[displayID]?.floating[window], let display = display(displayID),
      // (macOS puts windows on whole points, whatever was asked for. A whole point off is another place.)
      !own.approximatelyEquals(frame, tolerance: 0.99),
      // Nor is the size of a slot it left where macOS might have tiled it, and did not, anything to come back to (Controller+LeftToMacOS.swift).
      ownSize(of: window, ifItIsAsLargeAsTheSlotItLeft: frame.size) == nil
    else { return }
    // Where Arbor fitted it, it is for the displays' sake, and its own frame is still its own, as long as it will be fitted
    // to the same place again.
    if fittedFrames[window] == frame, whereItWas(own, of: window, on: display).approximatelyEquals(frame, tolerance: 1) { return }
    workspaces[displayID]?.floating[window] = frame
  }

  /// Brings `window` back into view at `frame`, for `placeFloatingWindows`.
  func putBackWhereItWas(_ window: WindowID, at frame: CGRect, on display: DisplaySnapshot) {
    let own = workspaces[display.id]?.floating[window]
    putBack(window, at: frame, on: display)
    // Fitted, it is there for the displays' sake, and what is remembered is still its own: there and back is nothing, for a
    // lid that closes and opens too (`countAsOutOfViewWhatTheDisplaysDisplaced`).
    // (Its app may not have answered: then it is still out of view, and is placed when the app does.)
    fittedFrames[window] = frame == own || parked.contains(window) ? nil : windows[window]?.frame
  }

  /// Where a window that floated at `own` goes when it comes back into view: there, to the point.
  ///
  /// The one exception, because "never lost" outranks "never moved": if the displays have changed meanwhile and that frame
  /// would show less than half of the window, or leave its title bar out of reach, it is fitted: moved the least
  /// that brings it wholly into view, and made smaller only if it is larger than the display. With its display as it
  /// was, a window pushed aside by hand until a strip shows goes back to that strip. (A display that only moved takes its
  /// windows and what is remembered of them along, `followDisplaysThatMoved`, and shows as much of each as before.)
  /// That the display has not changed under a frame is known only from the hand's own note. Where in doubt, the window is in view.
  func whereItWas(_ own: CGRect, of window: WindowID, on display: DisplaySnapshot) -> CGRect {
    // Not where no hand could get hold of it: Arbor puts no window there, whoever did before.
    if wasLeftThereByItsUser(own, of: window, on: display), titleBarIsWithinReach(own) { return own }
    return isAPlace(own) ? own : own.fitted(into: display.visibleFrame)
  }

  /// Whether a window at `frame` is within sight and reach whoever put it there: half of it shows, on all displays together
  /// (`showsLessThanHalf`, the one measure of that), and a hand could get hold of its title bar (`titleBarIsWithinReach`, likewise). Not behind a menu bar, where
  /// macOS lets no window lie: it is what a change of displays made of a window that lay at the top of a display without one.
  func isAPlace(_ frame: CGRect) -> Bool {
    !showsLessThanHalf(frame) && titleBarIsWithinReach(frame)
      && !displays.contains {
        $0.frame.minY <= frame.minY && frame.minY < $0.visibleFrame.minY && frame.minX < $0.frame.maxX && frame.maxX > $0.frame.minX
      }
  }

  /// Called where a net for lost windows has brought a floating window into view (quitting, a pause): no window is left with less
  /// than half of it showing when Arbor is not there to fetch it, whoever left it so. If Arbor comes back, what is remembered
  /// is still the window's own frame, and this one counts as fitted.
  func noteThatItWasFetched(_ window: WindowID) {
    guard !settings.floatingWindowsMakeWay, let frame = windows[window]?.frame,
      let own = workspaceID(containing: window).flatMap({ workspaces[$0]?.floating[window] }), own != frame
    else { return }
    fittedFrames[window] = frame
  }

  /// The same for what a pause fetches late, when its app answers again. By then Arbor keeps no list of windows.
  func noteThatThePauseFetched(_ window: WindowID, to frame: CGRect) {
    guard !settings.floatingWindowsMakeWay, let own = workspaceID(containing: window).flatMap({ workspaces[$0]?.floating[window] }),
      own != frame
    else { return }
    fittedFrames[window] = frame
  }

  /// Called when Arbor starts. (What its person did to a floating window meanwhile is its own: Controller+FoundAtAStart.swift.) After a
  /// pause, what the pause's net fetched goes back where it was, with everything else that comes back. After a quit that stays
  /// too: it was the end, whatever runs next.
  func sendBackWhatThePauseFetched() {
    if !isResuming { fittedFrames.removeAll() }
    guard !settings.floatingWindowsMakeWay else { return }
    for (window, frame) in fittedFrames.sorted(by: { $0.key < $1.key })
    where windows[window]?.frame == frame && windows[window]?.isPresent == true && !parked.contains(window) && isManaged(window) {
      guard workspaces.values.contains(where: { $0.isFloating(window) && $0.role(of: window) == nil }) else { continue }
      parked.insert(window)
      settled[window] = nil
    }
  }

  // MARK: A change of displays

  /// What has to be known of the floating windows before the displays change.
  struct BeforeTheDisplaysChanged {
    /// The windows that were in view where they belong, or were until macOS moved them before Arbor heard of the change
    /// (`noteMoveBehindArborsBack`).
    var inTheirPlaces: Set<WindowID> = []
    /// How large each display was.
    var sizes: [DisplayID: CGSize] = [:]
  }

  func noteBeforeTheDisplaysChange() -> BeforeTheDisplaysChanged {
    var note = BeforeTheDisplaysChanged()
    guard !settings.floatingWindowsMakeWay else { return note }
    note.sizes = Dictionary(displays.map { ($0.id, $0.frame.size) }) { first, _ in first }
    note.inTheirPlaces = movedBehindArborsBack
    for workspace in workspaces.values {
      for (window, own) in workspace.floating where !parked.contains(window) && windows[window]?.frame == own {
        note.inTheirPlaces.insert(window)
      }
    }
    return note
  }

  /// A change of displays moves windows that are in view, or the ground under them, and nobody chose where that leaves them.
  /// Such a window counts as out of view, so that the layout that follows puts it where it belongs (`whereItWas`), or
  /// out of view with the rest of its Desktop:
  /// - one that was in its place and is not now, because macOS has shuffled it or has not taken it along with its display, goes back
  ///   where it was on its display, if that is as large as it was (on one that shrank macOS may have found it a better place);
  /// - one that Arbor fitted for the displays as they were goes back to its own frame, if that is a place again;
  /// - one of which less than half shows now, or whose title bar is out of reach, is fitted. Not one that its person's own hand left
  ///   hanging, as long as its display is as it was then and no less of it shows than it left showing (`wasLeftThereByItsUser`).
  /// Returns those that the layout is going to put in view.
  func countAsOutOfViewWhatTheDisplaysDisplaced(since before: BeforeTheDisplaysChanged) -> Set<WindowID> {
    guard !settings.floatingWindowsMakeWay else { return [] }
    var displaced: Set<WindowID> = []
    for (id, workspace) in workspaces.sorted(by: { $0.key < $1.key }) {
      guard let display = display(id) else { continue }
      let isAsLargeAsItWas = before.sizes[id] == display.frame.size
      let desktopShows = layout(of: id).map { workspace.tree.subtree($0.camera, contains: workspace.tree.desktop) } ?? false
      for (window, own) in workspace.floating.sorted(by: { $0.key < $1.key }) where workspace.role(of: window) == nil {
        guard !parked.contains(window), window != drag?.window, isManaged(window), let current = windows[window],
          current.isPresent
        else { continue }
        let hangsAsItWasLeft = wasLeftThereByItsUser(current.frame, of: window, on: display)
        guard
          (isAsLargeAsItWas && before.inTheirPlaces.contains(window) && current.frame != own)
            || fittedFrames[window] == current.frame
            || (!isAPlace(current.frame) && !hangsAsItWasLeft),
          // Not one that is where it would be sent: a call to its app costs more than everything Arbor does itself.
          !whereItWas(own, of: window, on: display).approximatelyEquals(current.frame, tolerance: 0.99)
        else { continue }
        if desktopShows { displaced.insert(window) }
        parked.insert(window)
        // Where it is now is no corner it was sent to: if its Desktop is out of view, it has yet to go (`hasLeftItsCorner`).
        settled[window] = nil
      }
    }
    return displaced
  }

  // MARK: The setting goes off

  /// The floating windows in view that docked windows have pushed aside or squeezed, or that fill the Desktop (F18), with their
  /// displays. Asked while floating windows still make way.
  func windowsPushedAside() -> [(window: WindowID, display: DisplayID)] {
    guard isRunning, settings.floatingWindowsMakeWay else { return [] }
    return workspaces.sorted { $0.key < $1.key }.flatMap { display, workspace in
      workspace.floating.sorted { $0.key < $1.key }
        .filter { !parked.contains($0.key) && windows[$0.key]?.isPresent == true && wasPushedAside($0.key, from: $0.value) }
        .map { ($0.key, display) }
    }
  }

  /// From now on nothing would give them back the frames their person gave them, and where they are would pass for that.
  func giveBackTheirOwnFrames(to pushedAside: [(window: WindowID, display: DisplayID)]) {
    for (window, displayID) in pushedAside where isManaged(window) {
      guard let own = workspaces[displayID]?.floating[window], let display = display(displayID) else { continue }
      putBackWhereItWas(window, at: whereItWas(own, of: window, on: display), on: display)
    }
  }

  // MARK: Windows a command is about

  /// Where Arbor may put a floating window that a command is about (`float`, `grow`, `move-to-display`): on the
  /// Desktop while floating windows are kept there, and otherwise anywhere on the display.
  func roomToFloat(_ desktop: CGRect, on display: DisplaySnapshot) -> CGRect {
    settings.floatingWindowsMakeWay ? floatingRegion(desktop, on: display) : display.visibleFrame
  }

  /// Whether a window that floats alone takes the Desktop (F18). That is placing and sizing a floating window, so it
  /// takes both settings.
  var soleFloatIsOn: Bool { settings.soleFloatTakesDesktop && settings.floatingWindowsMakeWay }
}
