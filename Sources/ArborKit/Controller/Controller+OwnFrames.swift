import ArborCore
import CoreGraphics
import Foundation

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
/// `Workspace.floating` holds the frame the window's person gave it, as ever, or macOS at a change of displays
/// (`takeFloatingWindowsFromWhereTheyAre`). With the setting off that is also where the window is, for as long as it is in view.
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
      // One that no display shows is out of view whoever put it there. And one that lies where nobody left it, out of sight or out of
      // reach, is what a change of displays made of it. It is fetched when its person asks, with ⌃⌥0 for one, a key that means
      // "bring my windows back", and by nothing else: by whatever layout comes next, because its app wakes, it leaves the Dock or
      // another window opens, it would leap out of nowhere. Nor at a start, which sets no frame (Q16).
      guard
        parked.contains(window) || showsOnlyASliver(window)
          || (isLookingForWindows && !isTheFirstLayout && windows[window].map { liesWhereNobodyLeftIt(window, at: $0.frame, on: display) } == true)
      else { return nil }
      // Nothing is raised: going out of view and coming back changes nobody's place in macOS's order.
      return .putBack(whereItWas(own, of: window, on: display))
    }
    if parked.contains(window) { return hasLeftItsCorner(window) ? .park : nil }
    // Only a move of the view takes it away. Or a display that shrank has left it where nothing shows it: parked, it
    // comes back when it is switched to. Or its app did not answer when the view moved.
    return reason == .camera || showsOnlyASliver(window) || owedMoves.contains(window) ? .park : nil
  }

  /// For what takes the place of such a command (a look at everything, Controller+Peek.swift).
  func lookingForWindows(_ layOut: () -> Void) {
    let wasLooking = isLookingForWindows
    isLookingForWindows = true
    defer { isLookingForWindows = wasLooking }
    layOut()
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
      !own.approximatelyEquals(frame, tolerance: 0.99)
    else { return }
    // Where Arbor fitted it, it is for the displays' sake, and its own frame is still its own, as long as it will be fitted
    // to the same place again.
    if fittedFrames[window] == frame, whereItWas(own, of: window, on: display).approximatelyEquals(frame, tolerance: 1) { return }
    // Nor is the point its own that the screen keeps from a window which ends on the Dock's line (Controller+TheScreensAnswer.swift): it would
    // lose one every time it went out of view.
    if own.width - frame.width <= 2, own.height - frame.height <= 2, ownFrame(of: frame, askedFor: own.size).approximatelyEquals(own, tolerance: 0.99) {
      return
    }
    workspaces[displayID]?.floating[window] = frame
  }

  /// Brings `window` back into view at `frame`, for `placeFloatingWindows`.
  func putBackWhereItWas(_ window: WindowID, at frame: CGRect, on display: DisplaySnapshot) {
    let own = workspaces[display.id]?.floating[window]
    // In view all along, and fetched because its person asked.
    let isFetched = isLookingForWindows && !parked.contains(window) && !showsOnlyASliver(window)
    putBack(window, at: frame, on: display)
    // Its app hangs just now. What its person asked for is owed: it counts as out of view, and is placed when the app answers.
    if isFetched, unplaced.contains(window) { parked.insert(window) }
    // From where no hand ever left it: a frame that is no place and that nobody chose is no frame to remember. Where it goes is its
    // frame, and no later change of displays sends it back. But for its size: what Arbor did to that is given back.
    if isFetched, chosenOnShape[window]?.frame != own, frame.size == own?.size {
      workspaces[display.id]?.floating[window] = unplaced.contains(window) ? frame : windows[window]?.frame ?? frame
      fittedFrames[window] = nil
      return
    }
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
  /// Where Arbor puts a window. Where it lets one lie is another question (`liesWhereNobodyLeftIt`).
  func isAPlace(_ frame: CGRect) -> Bool {
    !showsLessThanHalf(frame) && titleBarIsWithinReach(frame)
      && !displays.contains {
        $0.frame.minY <= frame.minY && frame.minY < $0.visibleFrame.minY && frame.minX < $0.frame.maxX && frame.maxX > $0.frame.minX
      }
  }

  /// What a key that brings windows back fetches of the floating windows in view: one that nobody can get hold of, or of which less
  /// than half shows, unless a hand left it so.
  ///
  /// Of a window wider or higher than its display half of what the display can show of it is enough: more never shows if its app keeps it
  /// that large, and then no fit would change that.
  func liesWhereNobodyLeftIt(_ window: WindowID, at frame: CGRect, on display: DisplaySnapshot) -> Bool {
    if wasLeftThereByItsUser(frame, of: window, on: display) { return false }
    guard aHandCanTakeIt(at: frame, on: displays) else { return true }
    return areaShowing(of: frame) * 2 < min(frame.width, display.visibleFrame.width) * min(frame.height, display.visibleFrame.height)
  }

  /// Its title bar is within reach (`titleBarIsWithinReach`, the one measure of that), on `displays` as they are or as they were, by what their
  /// menu bars leave of them: behind one no hand gets hold of it. On one display is enough: across two, its top may be behind the higher
  /// menu bar of the one and free on the other.
  func aHandCanTakeIt(at frame: CGRect, on displays: [DisplaySnapshot]) -> Bool {
    frame.titleBarIsWithinReach(
      on: displays.map { CGRect(x: $0.frame.minX, y: $0.visibleFrame.minY, width: $0.frame.width, height: $0.frame.maxY - $0.visibleFrame.minY) })
  }

  /// Called where Arbor, letting go (quitting, a pause), has brought a floating window into view somewhere else than at its own frame:
  /// it was out of view and its own frame is no place now, nobody could have got hold of it where it lay, or most of it was off screen
  /// and nobody is known to have left it so. (What its person pushed aside stays, however little of it shows: `isWhereItWasLeft`.) If
  /// Arbor comes back, what is remembered is still the window's own frame, and this one counts as fitted.
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

  /// A change of displays moves windows that are in view, or the ground under them, and nobody chose where that leaves them. What macOS
  /// does to a floating window then is macOS's, and Arbor acts only where nobody could get hold of the window: however little of it
  /// shows, one whose title bar is within reach stays, as at a start, a pause and a quit; whoever misses it has ⌃⌥0. Two kinds
  /// count as out of view, so that the layout that follows puts them where they belong (`whereItWas`), or out of view with the rest of
  /// their Desktop:
  /// - one that Arbor fitted for the displays as they were, when it came back into view, goes back to its own frame, if that is a place again,
  ///   also if macOS has moved it on since at the size Arbor gave it (`isAsArborFittedIt`);
  /// - one that the change took out of reach (`theChangeTookOutOfReach`) is fitted, and unless a hand chose where it lay that is its
  ///   frame from now on: a frame that is no place is no frame to remember. Not one that its person's own hand left there on the displays
  ///   as they are (`wasLeftThereByItsUser`).
  /// Returns those that the layout is going to put in view. `earlier` are the displays as they were; `movedByMacOS`, the windows that are not
  /// where Arbor knew them.
  func countAsOutOfViewWhatTheDisplaysDisplaced(since earlier: [DisplaySnapshot], movedByMacOS: Set<WindowID>) -> Set<WindowID> {
    guard !settings.floatingWindowsMakeWay else { return [] }
    var displaced: Set<WindowID> = []
    let lately = now().addingTimeInterval(-Self.spokenLately)
    for (id, workspace) in workspaces.sorted(by: { $0.key < $1.key }) {
      guard let display = display(id) else { continue }
      let layout = layout(of: id)
      let desktopShows = layout.map { workspace.tree.subtree($0.camera, contains: workspace.tree.desktop) } ?? false
      for (window, remembered) in workspace.floating.sorted(by: { $0.key < $1.key }) where workspace.role(of: window) == nil {
        guard !parked.contains(window), window != drag?.window, isManaged(window), let current = windows[window] else { continue }
        let hangsAsItWasLeft = wasLeftThereByItsUser(current.frame, of: window, on: display)
        let hasMoved = movedByMacOS.contains(window) || spokeOfItsPlace[window].map { $0 >= lately } == true
        let isOutOfReach = !hangsAsItWasLeft && theChangeTookOutOfReach(current.frame, since: earlier, hasMoved: hasMoved)
        guard isAsArborFittedIt(window, at: current.frame, whoseOwnSizeIs: remembered.size) || isOutOfReach else {
          // A report that came just before Arbor heard of the displays passes for a hand's, and its note says how much new numbers
          // showed on old displays. In doubt no hand vouches: whoever speaks first, the end is the same.
          if let left = chosenOnShape[window], left.display != display.frame, spokeOfItsPlace[window].map({ $0 >= lately }) == true {
            chosenOnShape[window] = nil
          }
          continue
        }
        // (One in the Dock, hidden or on another Space comes back where it went.)
        guard current.isPresent else { continue }
        // Where a hand once left it, on other displays, is still its own, and it goes back when they are as they were.
        // So is its size, if it has to be made smaller: what Arbor did to a window is given back. And what fills the view has a frame of its own.
        let fitted = current.frame.fitted(into: display.visibleFrame)
        let isItsFrameNow = isOutOfReach && chosenOnShape[window]?.frame != current.frame && fitted.size == current.frame.size && !workspace.isFilled(window)
        let own = isItsFrameNow ? fitted : remembered
        if isItsFrameNow { workspaces[id]?.floating[window] = own }
        // Not one that is where it would be sent: a call to its app costs more than everything Arbor does itself.
        guard !whereItWas(own, of: window, on: display).approximatelyEquals(current.frame, tolerance: 0.99) else { continue }
        if desktopShows || layout.flatMap({ hostInView(of: window, in: workspace, layout: $0) }) != nil { displaced.insert(window) }
        parked.insert(window)
        // Where it is now is no corner it was sent to: if its Desktop is out of view, it has yet to go (`hasLeftItsCorner`).
        settled[window] = nil
      }
    }
    return displaced
  }

  /// Whether nobody can get hold of a window at `frame`, and the change of displays is why: somebody could, where it was before
  /// (`whereItMayHaveBeen`). In doubt somebody could: where that may have been more than one place, and where macOS has moved the
  /// window itself, from wherever (from a display that went, for one). One that was out of reach all along, wherever its app or a
  /// tool put it, is none of Arbor's business at a report about the Dock.
  func theChangeTookOutOfReach(_ frame: CGRect, since earlier: [DisplaySnapshot], hasMoved: Bool) -> Bool {
    guard !aHandCanTakeIt(at: frame, on: displays) else { return false }
    func frames(_ displays: [DisplaySnapshot]) -> [DisplayID: CGRect] { Dictionary(displays.map { ($0.id, $0.frame) }) { first, _ in first } }
    return hasMoved || frame.whereItMayHaveBeen(on: frames(earlier), whichAreNow: frames(displays)).contains { aHandCanTakeIt(at: $0, on: earlier) }
  }

  /// Called after the layout that follows a change of displays. A window whose app did not answer is left as it is, and nothing is
  /// owed: minutes later, when the app wakes, the move would come out of nowhere, and the displays may be as they were. It is taken
  /// from where it lies, place and display, or Arbor would go on acting as if it lay where it was to go; unless that is where Arbor
  /// had fitted it. What no display shows is fetched by any layout, as ever (`moveKeepingItsFrame`).
  func leaveAsItIsWhatCouldNotBeMoved(of displaced: Set<WindowID>) {
    guard !settings.floatingWindowsMakeWay else { return }
    for window in displaced.sorted() where unplaced.contains(window) && parked.contains(window) && !showsOnlyASliver(window) {
      guard let home = workspaceID(containing: window), workspaces[home]?.isFloating(window) == true, workspaces[home]?.role(of: window) == nil,
        let frame = windows[window]?.frame
      else { continue }
      parked.remove(window)
      unplaced.remove(window)
      guard let remembered = workspaces[home]?.floating[window], !isAsArborFittedIt(window, at: frame, whoseOwnSizeIs: remembered.size) else { continue }
      let lies = displayID(at: frame.center).flatMap { workspaces[$0] == nil ? nil : $0 } ?? home
      if lies != home { workspaces[home]?.floating[window] = nil }
      workspaces[lies]?.floating[window] = frame
      if lies != home { notify(.windows) }
    }
  }

  // MARK: The setting goes off

  /// The floating windows in view that docked windows have pushed aside or squeezed, or that fill the Desktop (F18), with their
  /// displays. Asked while floating windows still make way.
  func windowsPushedAside() -> [(window: WindowID, display: DisplayID)] {
    guard isRunning, settings.floatingWindowsMakeWay else { return [] }
    return workspaces.sorted { $0.key < $1.key }.flatMap { display, workspace in
      workspace.floating.sorted { $0.key < $1.key }
        // (Not one that fills the view: that is its person's asking, whatever floating windows do for docked ones.)
        .filter { !workspace.isFilled($0.key) }
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
