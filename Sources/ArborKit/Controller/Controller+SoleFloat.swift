import ArborCore
import CoreGraphics

/// A window that floats alone takes the whole Desktop (docs/features/F18-sole-floating-window.md; the setting
/// `soleFloatTakesDesktop`, off by default).
///
/// Nothing more is remembered about the window. `Workspace.floating` goes on holding the frame its user gave it, as
/// it does for a floating window that docked windows have pushed aside, and filling the Desktop is only another answer
/// to "where does it go now?" in `placeFloatingWindows`. So as soon as the window is not alone any more, the setting
/// goes off or nothing is docked, the next layout places it like any floating window: at its own frame. And whatever
/// gives a floating window that Arbor moved its own frame back when Arbor lets go of it (quitting, excluding its app;
/// Controller+UndockedFrames.swift) does so for this one.
///
/// What is left to do here: say who is alone, stretch that window, lay out when a floating window comes or goes (nothing
/// else needs a layout then), and step back when the user takes the window in hand.
extension Controller {
  struct SoleFloats {
    /// On each display, the window that was alone on the Desktop when its user moved or resized it. It keeps the frame
    /// it was given until it has had company. Not saved: after a launch Arbor fills again.
    var inHand: [DisplayID: WindowID] = [:]
    /// The window being dragged, until its drop has been dealt with, and, if it filled the Desktop when the drag
    /// began, the size that is its own.
    var dragged: (window: WindowID, ownSize: CGSize?)?
    /// Arbor has just started and windows may still be turning up (`fillOnceWindowsHaveTurnedUp`).
    var isWaitingAfterLaunch = false
  }

  // MARK: Who

  /// The only floating window that takes up room on `displayID`, whatever the setting says.
  func windowAloneOnDesktop(of displayID: DisplayID) -> WindowID? {
    guard let workspace = workspaces[displayID] else { return nil }
    // Pinned, summoned and stashed windows float but do not live on the Desktop, and whoever adds more of that kind
    // leaves them out here. Guests of a space sit on the Desktop while it is in view, so they count.
    let living = workspace.floating.keys.filter {
      windows[$0]?.isPresent == true && isManaged($0) && workspace.role(of: $0) == nil
    }
    return living.count == 1 ? living[0] : nil
  }

  /// The window that should fill the Desktop of `displayID`, if any. Changes nothing: plans ask too (`floatingMoves`).
  func windowThatTakesDesktop(of displayID: DisplayID) -> WindowID? {
    guard settings.soleFloatTakesDesktop, let workspace = workspaces[displayID],
      let alone = windowAloneOnDesktop(of: displayID), alone != windowStillInHand(on: displayID),
      alone != soleFloats.dragged?.window,
      // Where no docked window takes up room (none is docked, or this is a macOS Space of its own) Arbor has
      // arranged nothing, and "float all" has to mean a normal Mac.
      workspace.tree.allWindows.contains(where: { windows[$0]?.isPresent == true })
    else { return nil }
    return alone
  }

  /// The window its user took in hand on `displayID`, unless that is over: it has company or was docked. While it is
  /// itself away (minimized, hidden, on another macOS Space) nothing has happened that its user would call a reason
  /// to undo their choice.
  private func windowStillInHand(on displayID: DisplayID) -> WindowID? {
    guard settings.soleFloatTakesDesktop, let held = soleFloats.inHand[displayID] else { return nil }
    if held == windowAloneOnDesktop(of: displayID) { return held }
    return windows[held]?.isPresent == false && workspaces[displayID]?.isFloating(held) == true ? held : nil
  }

  /// Called by every layout, so that what is over does not come back to life later.
  func letGoOfWindowsNoLongerInHand(on displayID: DisplayID) {
    soleFloats.inHand[displayID] = windowStillInHand(on: displayID)
  }

  // MARK: Filling

  /// Stretches `window` over `desktop`, for `placeFloatingWindows`.
  func fill(_ desktop: CGRect, with window: WindowID, on display: DisplaySnapshot) {
    guard let current = windows[window] else { return }
    var target = fillingFrame(on: desktop, of: display, minimum: minimumSizes[window])
    guard parked.contains(window) || current.frame != frameWhenFilling(desktop, with: window, on: display) else { return }
    // Its app does not answer: it is where it was, and is placed when the app does (as in `apply`).
    // A few points over can be the nearest character cell, not a refusal (Controller+SizeSteps.swift), as in `apply`.
    guard var actual = offer(target, to: window) else {
      unplaced.insert(window)
      return
    }
    unplaced.remove(window)
    parked.remove(window)
    if actual.width > target.width + 2 || actual.height > target.height + 2 {
      // The app will not make it that small. Remember, so that it is placed in one move from now on.
      minimumSizes[window] = CGSize(
        width: actual.width > target.width + 2 ? actual.width : minimumSizes[window]?.width ?? 0,
        height: actual.height > target.height + 2 ? actual.height : minimumSizes[window]?.height ?? 0)
      target = fillingFrame(on: desktop, of: display, minimum: minimumSizes[window])
      actual = system.setFrame(target, of: window) ?? actual
    }
    if actual.width < target.width - 2 || actual.height < target.height - 2 {
      // Nor that large. In the middle it looks meant, in the top-left corner broken; less than a cell short it has filled it (as in `place`).
      let rest = restingFrame(of: window, actual.size, in: target)
      if !actual.approximatelyEquals(rest, tolerance: 1) { actual = system.setFrame(rest, of: window) ?? actual }
    }
    windows[window]?.frame = actual
    settled[window] = actual
    misfits[window] = actual.approximatelyEquals(target, tolerance: 1) ? nil : (target, actual)
  }

  /// Where `window` will be once it has been asked to fill `desktop`, as far as anybody can tell beforehand: where it is,
  /// if that is it; where the last attempt left it, if it could not take this very frame (as in `apply`); else all of it.
  func frameWhenFilling(_ desktop: CGRect, with window: WindowID, on display: DisplaySnapshot) -> CGRect {
    let target = fillingFrame(on: desktop, of: display, minimum: minimumSizes[window])
    guard let current = windows[window], !parked.contains(window) else { return target }
    if current.frame.approximatelyEquals(target, tolerance: 1) { return current.frame }
    if let misfit = misfits[window], misfit.slot == target, current.frame.approximatelyEquals(misfit.frame, tolerance: 1) {
      return current.frame
    }
    return target
  }

  /// All of `desktop`, or, for a window whose app will not make it smaller than `minimum`, that size, hanging over
  /// the edges `floatingFrame` chooses.
  private func fillingFrame(on desktop: CGRect, of display: DisplaySnapshot, minimum: CGSize?) -> CGRect {
    let wanted = CGSize(
      width: max(desktop.width, minimum?.width ?? 0), height: max(desktop.height, minimum?.height ?? 0))
    return floatingFrame(CGRect(origin: desktop.origin, size: wanted), on: desktop, of: display, minimum: minimum)
  }

  /// The window that is alone on `displayID` and its own frame, if it is in view at a size Arbor gave it instead. That
  /// is the size it took when Arbor last placed it, or, when that has been forgotten (a crash leaves it stretched, and the
  /// launch that follows knows nothing of it), the Desktop's.
  private func ownFrameOfStretchedWindow(on displayID: DisplayID) -> (window: WindowID, frame: CGRect)? {
    guard settings.soleFloatTakesDesktop, let window = windowAloneOnDesktop(of: displayID),
      window != soleFloats.inHand[displayID], !parked.contains(window), let current = windows[window]?.frame,
      let own = workspaces[displayID]?.floating[window], !current.approximatelyEquals(own, tolerance: 1)
    else { return nil }
    var given = settled[window]?.size
    if given == nil, let desktop = layouts[displayID]?.desktopFrame, let display = display(displayID) {
      given = fillingFrame(on: desktop, of: display, minimum: minimumSizes[window]).size
    }
    guard let given, abs(given.width - current.width) <= Self.roundingByApps,
      abs(given.height - current.height) <= Self.roundingByApps
    else { return nil }
    return (window, own)
  }

  /// Apps round the size they are asked for by up to this much (as in `windowChanged`).
  private static let roundingByApps: CGFloat = 4

  // MARK: Floating windows coming and going

  /// A window was adopted. If it floats, the one that was alone until now is not any more, or this one is.
  func floatingWindowArrived(_ window: WindowID) {
    guard settings.soleFloatTakesDesktop, let display = workspaceID(containing: window),
      workspaces[display]?.isFloating(window) == true
    else { return }
    if soleFloats.isWaitingAfterLaunch { fillOnceWindowsHaveTurnedUp() }
    // A Desktop that is a tile is not taken, and nothing is stretched over it: there is nothing to lay out, and a layout
    // nobody asked for can cost a docked window its place (the Desktop asks for room as soon as something floats on it).
    guard layouts[display]?.desktopFrame != nil else { return }
    relayout(display, reason: .structure)
  }

  /// At launch floating windows are left where they are found: not every window is reported at once, and one that grows
  /// and shrinks again as the others turn up would be worse than one that waits. But docked windows go to their places
  /// at once, and the window that looks docked should not sit there small until some unrelated command stretches it. So
  /// it takes the Desktop once, when no window has turned up for a while. Called by `start()`.
  func fillOnceWindowsHaveTurnedUp() {
    guard settings.soleFloatTakesDesktop else { return }
    soleFloats.isWaitingAfterLaunch = true
    scheduler.schedule(Self.afterLaunchKey, after: 2) { [weak self] in
      guard let self else { return }
      self.soleFloats.isWaitingAfterLaunch = false
      // Only where that is all there is to do: other floating windows stay as they were found.
      for display in self.workspaces.keys.sorted() where self.windowThatTakesDesktop(of: display) != nil {
        self.relayout(display, reason: .structure)
      }
    }
  }

  /// The timer of `fillOnceWindowsHaveTurnedUp`, which `shutdown` cancels.
  static let afterLaunchKey = "sole-float-after-launch"

  /// `float` on a window that floats already. Alone on the Desktop and taken in hand, it has no other way to say "take
  /// the Desktop again". Says whether it did.
  func takesDesktopAgain(_ window: WindowID, on display: DisplayID) -> Bool {
    guard windowStillInHand(on: display) == window, windowAloneOnDesktop(of: display) == window else { return false }
    soleFloats.inHand[display] = nil
    guard windowThatTakesDesktop(of: display) == window, layouts[display]?.desktopFrame != nil else {
      soleFloats.inHand[display] = window
      return false
    }
    relayout(display, reason: .structure)
    return true
  }

  /// A floating window on `display` was pinned, unpinned or summoned, which lays nothing out: it left the Desktop, or is
  /// back on it.
  func desktopCompanyChanged(on display: DisplayID) {
    guard settings.soleFloatTakesDesktop else { return }
    relayout(display, reason: .structure)
  }

  /// `window` is about to be pinned where it is. If that is all over the Desktop, it is its own size first: a window
  /// that stays in view wherever the view goes should not be as large as Arbor happened to make it.
  func endStretch(of window: WindowID, on displayID: DisplayID) {
    guard let (stretched, own) = ownFrameOfStretchedWindow(on: displayID), stretched == window,
      let display = display(displayID)
    else { return }
    placeVisibly(window, at: own, on: display)
  }

  // MARK: The user's hand

  /// Whether a change reported as the user's is only the app of a window that fills the Desktop settling near where
  /// Arbor put it. Taken for a move, it would replace the window's own frame with the Desktop's, for good.
  ///
  /// A few points either way are rounding. Terminal goes further: it sizes its windows in whole text cells, and can
  /// say so late. So with no button down, a window that stays in its corner and only shrinks, by a cell at most, is
  /// settling too; it is then as near to filling the Desktop as its app lets it come, and is not asked again.
  func isOnlySettlingOnDesktop(_ window: WindowSnapshot, on display: DisplayID) -> Bool {
    guard windowThatTakesDesktop(of: display) == window.id, !parked.contains(window.id), let given = settled[window.id],
      workspaces[display]?.floating[window.id].map({ !given.approximatelyEquals($0, tolerance: 1) }) == true
    else { return false }
    if given.approximatelyEquals(window.frame, tolerance: Self.roundingByApps) { return true }
    let shrunk = CGSize(width: given.width - window.frame.width, height: given.height - window.frame.height)
    guard !system.isMouseButtonDown(), abs(given.minX - window.frame.minX) <= Self.roundingByApps,
      abs(given.minY - window.frame.minY) <= Self.roundingByApps,
      (-Self.roundingByApps...Self.largestCell).contains(shrunk.width),
      (-Self.roundingByApps...Self.largestCell).contains(shrunk.height)
    else { return false }
    misfits[window.id] = (misfits[window.id]?.slot ?? given, window.frame)
    settled[window.id] = window.frame
    return true
  }

  /// No text cell is larger than this (as in Controller+SizeSteps.swift).
  private static let largestCell = Cells.largest

  /// The user moved or resized a floating window, which was on `source`, without dragging it by its title bar. Its
  /// new frame has been recorded as its own.
  func floatingWindowMoved(_ window: WindowID, from source: DisplayID) {
    guard settings.soleFloatTakesDesktop, let display = workspaceID(containing: window) else { return }
    if windowAloneOnDesktop(of: display) == window { soleFloats.inHand[display] = window }
    // From one Desktop to another: both have a different number of windows now, and nothing has been laid out.
    guard display != source else { return }
    relayout(source, reason: .structure)
    relayout(display, reason: .structure)
  }

  /// Another tab of a native tab group came to the front. To its user it is the same window.
  func soleFloatReplaced(_ old: WindowID, by new: WindowID) {
    for (display, held) in soleFloats.inHand where held == old { soleFloats.inHand[display] = new }
  }

  /// A drag began. Wherever the window is dropped to float, it stays. A docked window's drop is laid out before
  /// `soleFloatDropped` can say so, which is why the drag is remembered until then.
  func soleFloatTakenInHand(_ window: WindowID) {
    soleFloats.dragged = nil
    guard settings.soleFloatTakesDesktop, let display = workspaceID(containing: window) else { return }
    let stretched = ownFrameOfStretchedWindow(on: display)
    soleFloats.dragged = (window, stretched?.window == window ? stretched?.frame.size : nil)
  }

  /// A drag that began on `source` ended, and the drop has been dealt with. `leftToMacOS`: macOS is about to tile the window, so
  /// nothing here gives it a frame.
  func soleFloatDropped(_ window: WindowID, from source: DisplayID?, leftToMacOS: Bool = false) {
    let ownSize = soleFloats.dragged?.window == window ? soleFloats.dragged?.ownSize : nil
    soleFloats.dragged = nil
    guard settings.soleFloatTakesDesktop, let displayID = workspaceID(containing: window) else { return }
    if windowAloneOnDesktop(of: displayID) == window { soleFloats.inHand[displayID] = window }
    // Dragged off the Desktop it filled and still floating, it is its old size again, as a window dragged out of
    // macOS's own tiling is, with the pointer where it was along the title bar.
    if !leftToMacOS, let ownSize, workspaces[displayID]?.isFloating(window) == true, let dropped = windows[window]?.frame,
      let room = display(displayID)?.visibleFrame.size
    {
      let size = CGSize(width: min(ownSize.width, room.width), height: min(ownSize.height, room.height))
      let frame = Self.frame(ofSize: size, inPlaceOf: dropped, under: system.cursorLocation())
      if var actual = system.setFrame(frame, of: window) {
        // Its app may not let it be that size (any more), and keeps the corner it was given, which was reckoned for another
        // width: the window would jump away from under the pointer, off the display if it is near the edge.
        if abs(actual.width - size.width) > 2 || abs(actual.height - size.height) > 2 {
          let again = Self.frame(ofSize: actual.size, inPlaceOf: dropped, under: system.cursorLocation())
          actual = system.setFrame(again, of: window) ?? actual
        }
        windows[window]?.frame = actual
        workspaces[displayID]?.floating[window] = actual
      }
    }
    // From one Desktop to another, as above.
    guard let source, source != displayID else { return }
    relayout(source, reason: .structure)
    if !leftToMacOS { relayout(displayID, reason: .structure) }
  }

  /// A frame of `size` for a window that was dropped as `dragged` with the pointer at `pointer`: the pointer stays
  /// over the title bar, as far along it as it was.
  static func frame(ofSize size: CGSize, inPlaceOf dragged: CGRect, under pointer: CGPoint) -> CGRect {
    // After a drag whose end nobody saw the pointer can be anywhere. The window stays where it was left, so what
    // counts is the point of its title bar nearest to the pointer. 60: how far below a window's top edge a
    // press can be and still drag it (a tall toolbar).
    let hold = CGPoint(
      x: min(max(pointer.x, dragged.minX), dragged.maxX), y: min(max(pointer.y, dragged.minY), dragged.minY + 60))
    let along = dragged.width > 0 ? (hold.x - dragged.minX) / dragged.width : 0.5
    let below = min(hold.y - dragged.minY, size.height)
    return CGRect(
      x: (hold.x - along * size.width).rounded(), y: (hold.y - below).rounded(), width: size.width, height: size.height)
  }
}
