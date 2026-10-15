import ArborCore
import CoreGraphics
import Foundation

/// The window that has the keyboard when Arbor starts is let be where it stands, if the view that comes up has it as
/// a tile (`collab/QUESTIONS.md`, Q16).
///
/// A launch ends showing everything, and takes no window out of view that is in view. One docked window can be in the
/// way of both: it has the keyboard, and with everything showing there is no room for it, so it is a tile. Sent to
/// the corner it would be typed into unseen. The view used to go to it instead, and every other window left: click an
/// app in the Dock, open Arbor, and eight of nine windows are gone (seen with real apps on a hosted Mac).
///
/// So it stays where it stands. It is docked, its tile shows, which is its place kept, nobody else moves for it, and
/// the keyboard stays in it. That lasts until a person asks for a layout of its display or moves the view: then it is
/// a window like any other. What nobody asked for (a timer, a putting-back, another window coming or going, a report
/// of the displays, a switch of Spaces) lays out the others and leaves it alone.
///
/// The end of a pause, the return of the permission and the watchdog's restart keep their view, and go by the same
/// rule: otherwise a pause and a resume would bring the fault back.
extension Controller {
  struct LetBe {
    var window: WindowID
    /// Where it stood when Arbor started, or where its person has put it since.
    var stood: CGRect
    enum Phase {
      /// The start's own layout is under way, which is no layout a person asked for afterwards.
      case starting
      case standing
      /// It is a window like any other again, and who has the keyboard is still to be seen to
      /// (`theKeyboardLeavesTheTile`).
      case over
    }
    var phase = Phase.starting
  }

  func isLetBe(_ window: WindowID) -> Bool { letBe?.window == window && letBe?.phase != .over }

  /// On record as let be, in sight or not. For the tests of this rule. Whoever compares what Arbor believes with what is on
  /// screen reads `state`, which has `letBe` for it (`whereTheWindowLetBeStands`).
  public var windowLetBe: WindowID? { letBe.flatMap { isLetBe($0.window) ? $0.window : nil } }

  /// Docked, in a tile, and in view all the same: the window, and where it stands. Nil while nobody can see it (another
  /// Space, full screen beside it). One answer for `state`, `ascii` and the choice of who gets the keyboard.
  var whereTheWindowLetBeStands: (window: WindowID, home: DisplayID, frame: CGRect)? {
    guard let window = windowLetBe, let home = workspaceID(containing: window), workspaces[home]?.isDocked(window) == true,
      let snapshot = windows[window], snapshot.isPresent
    else { return nil }
    return (window, home, snapshot.frame)
  }

  // MARK: A start

  /// Called by `start()` before its first layout. Whether the window is a tile is for that layout to find out: real
  /// apps say how small they go only when asked. Until then it is a window that is not sent away.
  ///
  /// Only one a person sees. After a crash it can be in the corner: see `keyboardAfterAStart`.
  func letTheWindowWithTheKeyboardBe() {
    letBe = nil
    noteWhereEverybodyStands()
    guard let window = system.focusedWindow(), isManaged(window), let snapshot = windows[window], snapshot.isPresent,
      !parked.contains(window), let tree = workspaceID(containing: window).flatMap({ workspaces[$0]?.tree }),
      // A tab behind another is brought to the front of its group, which moves nobody else.
      let leaf = tree.leaf(containing: window), tree.activeWindow(of: leaf) == window
    else { return }
    letBe = LetBe(window: window, stood: snapshot.frame)
  }

  /// The start's layout is over. A window that has its place in it is no longer on record
  /// (`lettingBeEndsWithAPlace`).
  func theStartHasLaidOut() {
    guard let state = letBe else { return noteWhoWentIntoATile() }
    sentIntoTilesAtTheStart = nil
    guard let id = workspaceID(containing: state.window), let display = display(id), let layout = layouts[id],
      layout.hiddenWindows.contains(state.window)
    else { return letBe = nil }
    guard layout.tiles.contains(where: { $0.windows.contains(state.window) }) else {
      // The view that came back is somewhere else. It goes out of view like everything that view leaves out, and
      // whether the view follows the keyboard is decided where it always was.
      letBe = nil
      return park(state.window, on: display)
    }
    letBe?.phase = .standing
    Log.info("\(state.window) has the keyboard and would be a tile: let be where it stands")
    // Its person may have moved it while Arbor was not running. Where it stands is where the ways out leave it.
    workspaces[id]?.rememberUndockedFrames(ofArrivals: [state.window: state.stood])
    // It was offered its place, because nobody knew that it would not fit, and is wherever that left it: with a slot
    // on the right, mostly off the display.
    if windows[state.window]?.frame != state.stood, let actual = system.setFrame(state.stood, of: state.window) {
      windows[state.window]?.frame = actual
    }
  }

  /// Nobody told Arbor where the keyboard went while it was not running. A start ends with the focused window in
  /// view: swept out of view with the keyboard in it, ⌘Tab would not fetch it, because its app is in front already
  /// and nothing is reported.
  ///
  /// With one exception, when a person starts Arbor: a docked window that a crash left in the corner and that is a
  /// tile with everything showing. The view would go to it and everything else would leave. Nobody sees it, so there
  /// is nothing to let be: it stays behind its tile, and a window in view gets the keyboard, chosen as Show
  /// Everything chooses when it puts the focused window into a tile. (The one used last, as far as this process
  /// knows, which has only just begun: so the one under the pointer, or the top left one.) A launch is a person's
  /// act. With nothing in view to take the keyboard the view follows after all, which then takes nothing away: there
  /// is no call that gives the keyboard to the desktop.
  func keyboardAfterAStart(byAPerson: Bool) {
    guard let focused = system.focusedWindow() else { return }
    if byAPerson, parked.contains(focused), let display = workspaceID(containing: focused),
      layouts[display]?.tiles.contains(where: { $0.windows.contains(focused) }) == true,
      ensureFocusIsVisible(on: display, alsoFromNothing: false)
    {
      return
    }
    windowFocused(focused)
  }

  // MARK: A report that comes late

  /// macOS does not always say in time who has the keyboard. Whatever started Arbor is still in front and gives the keyboard back
  /// a moment later, or the app does not answer just then. The start names nobody, the window goes into its tile like any
  /// other, the report follows, and the view went to it after all, with everybody else leaving.
  ///
  /// So for its first second a start remembers whom it took for a tile in a person's sight, and where they stood.
  struct SentIntoTilesAtTheStart {
    var found: [WindowID: CGRect]
    /// When the start had laid out. Nil while it does, which is no layout somebody asked for afterwards.
    var at: Date?
  }

  static let lateReport = "focus-late-report"
  /// By decision. Nobody has measured how late a report can be.
  static let aReportIsLateFor: TimeInterval = 1

  private func noteWhereEverybodyStands() {
    scheduler.cancel(Self.lateReport)
    sentIntoTilesAtTheStart = .init(found: windows.filter { !parked.contains($0.key) && $0.value.isPresent }.mapValues(\.frame))
  }

  private func noteWhoWentIntoATile() {
    let inTiles = Set(layouts.values.flatMap { $0.tiles.flatMap(\.windows) })
    guard let found = sentIntoTilesAtTheStart?.found.filter({ inTiles.contains($0.key) }), !found.isEmpty else {
      return sentIntoTilesAtTheStart = nil
    }
    sentIntoTilesAtTheStart = .init(found: found, at: now())
    scheduler.schedule(Self.lateReport, after: Self.aReportIsLateFor) { [weak self] in self?.sentIntoTilesAtTheStart = nil }
  }

  /// `window` has the keyboard, says the first report since the start. If nobody has clicked or pressed anything meanwhile it had
  /// it all along: it is put back where the start found it, in one request, and let be as if it had been named in time.
  /// After a click or a key it is a switch, and gets what a switch gets. Returns whether it is let be.
  func aLateReportLetsItBe(_ window: WindowID) -> Bool {
    guard let sent = sentIntoTilesAtTheStart, let at = sent.at else { return false }
    // macOS says once who had it. The next report is a change.
    sentIntoTilesAtTheStart = nil
    scheduler.cancel(Self.lateReport)
    // A view that is held turns away whoever comes forward unasked, and cannot tell this from that (Controller+Hold.swift).
    guard !isHeld, let found = sent.found[window], system.secondsSinceClickOrModifierKey() > now().timeIntervalSince(at),
      // Still: a neighbour may have gone meanwhile and left it room.
      let id = workspaceID(containing: window), layouts[id]?.tiles.contains(where: { $0.windows.contains(window) }) == true,
      // The displays may have moved meanwhile, and its own with it.
      displayID(at: found.center) == id
    else { return false }
    // Not one whose app did not answer when it was sent away: that stands where it stood.
    if parked.contains(window) {
      guard let corner = windows[window]?.frame, let actual = system.setFrame(found, of: window) else { return false }
      windows[window]?.frame = actual
      // It does not move, or not yet. Typed into unseen it would be worse off than with the view going to it.
      guard !isOutOfView(actual) else { return false }
      Log.info("\(window) had the keyboard when Arbor started, which macOS says only now: back from \(corner) to \(found)")
      parked.remove(window)
      parkedAgain[window] = nil
      settled[window] = nil
    }
    unplaced.remove(window)
    owedMoves.remove(window)
    letBe = LetBe(window: window, stood: found, phase: .standing)
    Log.info("\(window) has the keyboard and is a tile: let be where it stands")
    workspaces[id]?.rememberUndockedFrames(ofArrivals: [window: found])
    scheduleSave()
    return true
  }

  // MARK: It ends when a person asks

  /// Called by `relayout` before it moves anything: a layout within a command, with a gap or an edge in the hand, or
  /// for a window that was dropped. Not for its own drop: whoever takes it by its title bar and lets go of it
  /// somewhere has put it there, and has not asked for it to vanish from under the hand. (Dropped to float it is
  /// docked no longer.)
  func aLayoutSomebodyAskedForEndsLettingBe(on display: DisplayID) {
    let dropped = placedOnPurpose.subtracting([letBe?.window].compactMap { $0 })
    if following.decides || gapsInHand || !dropped.isEmpty { lettingBeIsOver(on: display) }
  }

  /// Also called by `moveCamera`, whoever moves the view: a command, a click on a tile, its own too, a switch to a
  /// window out of view.
  func lettingBeIsOver(on display: DisplayID) {
    if sentIntoTilesAtTheStart?.at != nil { sentIntoTilesAtTheStart = nil }
    guard let state = letBe, state.phase == .standing, workspaceID(containing: state.window) == display,
      // On another Space it goes nowhere now. A timer's layout would send it off when it is back, with nobody to see
      // to the keyboard.
      windows[state.window]?.isPresent == true
    else { return }
    letBe?.phase = .over
  }

  /// Gone into its tile with the keyboard in it, it would be typed into unseen. Called once whoever ended it has had
  /// their own say about the keyboard: at the end of the command, of the move of the view, or of the layout.
  func theKeyboardLeavesTheTile() {
    guard let state = letBe, state.phase == .over else { return }
    // Its app does not answer, so it is where it was, and would be sent off when the app wakes, by nobody's asking. Unless what was
    // asked for has a place for it: there it goes when the app wakes, like any docked window.
    guard !unplaced.contains(state.window) else {
      let isHidden = workspaceID(containing: state.window).flatMap { layouts[$0]?.hiddenWindows.contains(state.window) } == true
      if isHidden { letBe?.phase = .standing } else { letBe = nil }
      return
    }
    letBe = nil
    // `keyboardFocus()`: the command may have sent the keyboard elsewhere a moment ago, and macOS not be there yet.
    guard parked.contains(state.window), keyboardFocus() == state.window,
      let display = workspaceID(containing: state.window)
    else { return }
    if !ensureFocusIsVisible(on: display, alsoFromNothing: false) { bringIntoView(state.window) }
  }

  // MARK: It ends by itself

  /// Called by `relayout` once the windows are in place. A layout that has room for it after all has put it there, in
  /// one move, whoever caused that layout: that is what docked means.
  func lettingBeEndsWithAPlace(in layout: Layout) {
    if let state = letBe, state.phase != .over, layout.windowFrames[state.window] != nil { letBe = nil }
  }

  /// It closed, went into the Dock or was hidden, is docked no longer, or Arbor arranges it no longer, or its display
  /// is gone, or it has ended up out of view after all: nothing is moved. Another Space and full screen are no such
  /// ends: it comes back from there, and the layout that follows is a timer's. Asked at every report about it and
  /// before every layout.
  func lettingBeEndsIfItNoLongerApplies() {
    guard let state = letBe else { return }
    guard let window = windows[state.window], !window.isMinimized, !window.isHidden, isManaged(state.window),
      !parked.contains(state.window),
      let display = workspaceID(containing: state.window), workspaces[display]?.isDocked(state.window) == true
    else { return letBe = nil }
  }

  /// Its person moves or resizes it where it stands, and nothing puts it back. That is its own frame from now on:
  /// where a quit, a pause and Float All leave it.
  func lettingBeNotes(_ window: WindowSnapshot, movedByItsUser: Bool) {
    lettingBeEndsIfItNoLongerApplies()
    guard movedByItsUser, isLetBe(window.id), letBe?.phase == .standing, window.isPresent, window.frame != letBe?.stood,
      let display = workspaceID(containing: window.id)
    else { return }
    letBe?.stood = window.frame
    workspaces[display]?.rememberUndockedFrames(ofArrivals: [window.id: window.frame])
    scheduleSave()
  }
}
