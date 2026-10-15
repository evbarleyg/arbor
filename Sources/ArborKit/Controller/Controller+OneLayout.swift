import ArborCore

/// One thing that happens is one layout. Whatever an event sets off is worked out to its end before the first frame is set, so
/// that every window moves once, to where it ends up.
extension Controller {
  /// Lays out `display` after a report that brought `window` back to it: out of the Dock, or with its app. It may have been given the
  /// keyboard before it was reported back (Controller+Focus.swift), or have been asked back by name (`awaitTheReturn`), and then
  /// it ends in view.
  ///
  /// Where its place does not show, the view goes there, and that is a layout of its own. Laid out first for the view that
  /// is about to go, the window went from where it stood to the corner, its neighbours made room for a tile, in plain sight, and
  /// everything moved again a moment later. So the view has its turn first, as for a new window that a rule docks
  /// (`theViewGoesStraightTo`), which also says where it must not: looking at the keyboard has side effects, judged by what
  /// is on screen, so wherever the view may stay they come after the layout, once.
  func relayout(_ display: DisplayID, motion: Motion = .animated, forTheReturnOf window: WindowID) {
    // Whoever has moved a view since it was asked for has said where it goes.
    let byName = askedBack?.window == window && askedBack?.views == workspaces.mapValues(\.camera)
    if askedBack?.window == window { stopAwaitingAReturn() }
    // Asked for by name, a tab comes to the front of its group (`bringIntoView`): before the layout, which would send it to its corner.
    if byName { workspaces[display]?.tree.activate(window) }
    let isAwaited = windows[window].flatMap { snapshot in awaitedSummon.map { Self.isWindow(snapshot, of: $0.app) } } ?? false
    // `summon` is waiting for it: it hears of it from the layout, and goes there itself, with a way back. And a tile by a record so
    // old that the layout asks it again may show after all (Controller+LearnedSizes.swift).
    if isAwaited || hasARecordToBeAskedAbout(window) || !theViewGoesStraightTo(window, dockedOn: display, byName: byName) {
      relayout(display, reason: .structure, motion: motion)
      if byName { bringIntoView(window) }
    }
    // Who has the keyboard goes on record either way.
    bringIntoViewIfFocused(window, retries: 0)
  }

  // MARK: A window that was asked back by name

  /// `window` is in the Dock or hidden with its app, and a command is about to ask it back to show it: Go to…, `reveal`, a row of the
  /// menu. macOS reports that it is back a moment later, when it has flown out. **The view waits for the window.** What is on
  /// screen stays meanwhile, and the report brings the one layout, for the view that shows it (`relayout(_:motion:forTheReturnOf:)`).
  /// Moved at once, the view was on the place of a window that was not there: its neighbour filled the screen for the length
  /// of the flight and was sent away again when the window landed.
  ///
  /// An app that hangs reports nothing. Then the view goes after a moment, picked as if the window were back, as it used to at once.
  func awaitTheReturn(of window: WindowID) {
    askedBack = (window, workspaces.mapValues(\.camera))
    scheduler.schedule(Self.lookForWhoWasAskedBack, after: Self.timeToLand) { [weak self] in
      guard let self, let asked = self.askedBack, asked.window == window else { return }
      self.askedBack = nil
      guard self.isRunning, let snapshot = self.windows[window], self.workspaces.mapValues(\.camera) == asked.views else { return }
      self.bringIntoView(window, onItsWayBack: !snapshot.isPresent)
      // The move gives the keyboard to whatever shows there now.
      self.askForTheKeyboard(for: window)
    }
  }

  /// Called with every report of the keyboard. Somebody has turned to another app since the window was asked for: a click, ⌘Tab. They keep
  /// what they turned to, and the window lands where it belongs. Its own app's other window is macOS's pick as the app comes
  /// forward, and apps in the background report too: only the keyboard really being there counts.
  func whoeverWasAskedBackIsNoLongerAwaited(ifTheKeyboardIsIn id: WindowID) {
    guard let asked = askedBack?.window, asked != id, windows[asked]?.pid != windows[id]?.pid, system.focusedWindow() == id else { return }
    stopAwaitingAReturn()
  }

  func stopAwaitingAReturn() {
    askedBack = nil
    scheduler.cancel(Self.lookForWhoWasAskedBack)
  }

  /// Begins like the other looks at the keyboard, which the tests' nets stand back for.
  private static let lookForWhoWasAskedBack = "focus-asked-back"
}
