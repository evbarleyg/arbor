import ArborCore

/// One thing that happens is one layout. Whatever an event sets off is worked out to its end before the first frame is set, so
/// that every window moves once, to where it ends up.
extension Controller {
  /// Lays out `display` after a report that brought `window` back to it: out of the Dock, or with its app. It may have been given the
  /// keyboard before it was reported back (Controller+Focus.swift), and then it ends in view.
  ///
  /// Where its place does not show, the view follows the keyboard, and that is a layout of its own. Laid out first for the view that
  /// is about to go, the window went from where it stood to the corner, its neighbours made room for a tile, in plain sight, and
  /// everything moved again a moment later. So the view has its turn first, as for a new window that a rule docks
  /// (`theViewGoesStraightTo`), which also says where it must not: looking at the keyboard has side effects, judged by what
  /// is on screen, so wherever the view may stay they come after the layout, once.
  func relayout(_ display: DisplayID, motion: Motion = .animated, forTheReturnOf window: WindowID) {
    let isAwaited = windows[window].flatMap { snapshot in awaitedSummon.map { Self.isWindow(snapshot, of: $0.app) } } ?? false
    // `summon` is waiting for it: it hears of it from the layout, and goes there itself, with a way back. And a tile by a record so
    // old that the layout asks it again may show after all (Controller+LearnedSizes.swift).
    if isAwaited || hasARecordToBeAskedAbout(window) || !theViewGoesStraightTo(window, dockedOn: display) {
      relayout(display, reason: .structure, motion: motion)
    }
    // Who has the keyboard goes on record either way.
    bringIntoViewIfFocused(window, retries: 0)
  }
}
