import ArborCore
import CoreGraphics

/// A window let go where macOS may tile it: the last point of a side of the display, the menu bar, anywhere with ⌥ held (`MacTiling.claim`).
///
/// macOS does not take every window that is left to it. It fills the screen only for a pointer that has rested in the menu bar, it was seen to
/// overlook one that had, and to show its preview with ⌥ alone held and then do nothing. Nobody can tell at the release, and a frame set on
/// a window that macOS is moving is the fight. So Arbor looks when macOS would be done. It asks the window server and not the app, whose
/// last word about the drag comes a tenth of a second after the release and must not pass for a move of macOS's.
///
/// - **Moved or sized**, the window is macOS's. Arbor does not touch it, and what macOS has made of it is the window's own: a hand asked for it.
/// - **Still where it was let go**, nobody is going to size it. One that came out of a slot is as large as the slot, and takes its own size there.
///
/// Either way the books say again what is on the screen. Until then they may not: a slot's size is never a window's own
/// (Controller+UndockedFrames.swift). A difference that lasted would make the next layout size a window that nobody touched, so it lasts half a
/// second, and no layout touches the window meanwhile (`isInOtherHands`). The ways out do: they go by the books, and are Arbor's last word.
extension Controller {
  struct LeftToMacOS {
    /// Where the pointer let go of it.
    var pointer: CGPoint
    /// The frame it had then. If a way out has put it back since, the frame that gave it.
    var letGo: CGRect
    var claim: MacTiling.Claim
    /// The display it was let go on, and what was in view there.
    var display: DisplayID
    var view: NodeID?
    /// For the half second after the release, in which no layout may touch it. If Arbor could not look then (the window was minimized, hidden, on another
    /// Space or in full screen, its app did not answer, the displays changed), the shield ends all the same. The look is still owed, and
    /// comes when the window is next heard of.
    var macOSMayBeMovingIt = true
    /// Whether the timer runs. An app that goes on talking does not put the look off.
    var isToBeLookedAt = false
  }

  /// The timer that looks, one for each window, and how long after the release, in seconds. On hosted Macs macOS's own move began 0.01 to 0.25 s
  /// after the release, and the last of it was reported 0.27 to 0.40 s after.
  static let leftToMacOSKey = "left-to-macos"
  static let timeForMacOSToTile = 0.5

  /// Whether no layout may set a frame on `window`: it is in a hand, or macOS may be moving it.
  func isInOtherHands(_ window: WindowID) -> Bool { window == drag?.window || leftToMacOS[window]?.macOSMayBeMovingIt == true }

  /// Called when the drop has been dealt with. A window that is left again has one look, half a second after the last release.
  func leave(_ window: WindowID, toMacOS left: LeftToMacOS) {
    leftToMacOS[window] = left
    lookLater(at: window)
  }

  private func lookLater(at window: WindowID) {
    leftToMacOS[window]?.isToBeLookedAt = true
    scheduler.schedule("\(Self.leftToMacOSKey)-\(window.rawValue)", after: Self.timeForMacOSToTile) { [weak self] in
      self?.lookAtWhatMacOSMade(of: window)
    }
  }

  private func lookAtWhatMacOSMade(of window: WindowID) {
    guard var left = leftToMacOS[window] else { return }
    left.isToBeLookedAt = false
    leftToMacOS[window] = left
    // In the hand again, it ends in a drop of its own.
    guard drag?.window != window, let now = system.stackedWindows().first(where: { $0.id == window })?.frame ?? windows[window]?.frame
    else { return leftToMacOS[window] = nil }
    let isWhereItWasLeft = now.approximatelyEquals(left.letGo, tolerance: 1)
    guard isRunning, let current = windows[window], isManaged(window), let home = workspaceID(containing: window),
      workspaces[home]?.isFloating(window) == true, !parked.contains(window)
    else {
      // Arbor has let go of everything or of this window, or has docked it again. There is nothing to size. If a way out has given it its own size and it is
      // still there, macOS never had it and has nothing to give back.
      leftToMacOS[window] = nil
      if isWhereItWasLeft && hasItsOwnSizeAgain(window, now.size) || isDockedThoughMacOSNeverHadIt(window) { leftAsLargeAsTheirSlots[window] = nil }
      return
    }
    // A hand is at work, perhaps on this window without Arbor having heard: nothing is moved under it. Or the displays are changing.
    guard !system.isMouseButtonDown(), knowsTheDisplays else { return lookLater(at: window) }
    guard current.isPresent, !current.isFullScreen else { return leftToMacOS[window]!.macOSMayBeMovingIt = false }
    // From here on it is a window like any other.
    leftToMacOS[window] = nil
    // It has missed a move of the view, like a window whose app did not answer at the time (`noteThatTheAppAnswers`).
    let missedAMove = home != left.display || workspaces[home]?.camera != left.view
    let isAsLargeAsItsSlot = ownSize(of: window, ifItIsAsLargeAsTheSlotItLeft: now.size) != nil
    if hasItsOwnSizeAgain(window, now.size), isWhereItWasLeft || !left.macOSMayBeMovingIt {
      // From a way out, or from a layout while it was out of reach. macOS never had it, so there is nothing for macOS to give back.
      // (Elsewhere within the half second, it is in a tile as large as it was before it was docked.)
      leftAsLargeAsTheirSlots[window] = nil
      isAsMacOSMadeIt(window, at: now, on: home)
    } else if left.macOSMayBeMovingIt ? !isWhereItWasLeft || (leftAsLargeAsTheirSlots[window] != nil && !isAsLargeAsItsSlot) : !isAsLargeAsItsSlot {
      // (Arbor can hear of a release when macOS is done: what it took for the frame at the release is then the tile. And at a look that comes
      // late, the place says nothing: macOS puts windows elsewhere when displays change. A slot's size still says that nobody has sized it.)
      isAsMacOSMadeIt(window, at: now, on: home)
      // Whoever meant Arbor's edge and got macOS's tile is told where that can be changed. Whoever held ⌥ asked macOS, and whoever has no
      // edges of Arbor's there (a band of 0) meant none.
      if left.macOSMayBeMovingIt, left.claim != .optionKey, options(for: left.display).dropOptions.offersScreenEdges {
        teach(.leftToMacOS, on: left.display)
      }
    } else if isAsLargeAsItsSlot,
      !takesItsOwnSizeWhereItLies(
        window, letGoAt: isWhereItWasLeft ? left.pointer : CGPoint(x: now.midX, y: now.minY), on: home, unlessItLeavesTheView: missedAMove)
    {
      leftToMacOS[window] = left
      return leftToMacOS[window]!.macOSMayBeMovingIt = false
    }
    if missedAMove, !parked.contains(window) {
      owedMoves.insert(window)
      scheduleEnforce(home)
    }
  }

  private func hasItsOwnSizeAgain(_ window: WindowID, _ size: CGSize) -> Bool {
    leftAsLargeAsTheirSlots[window].map { abs($0.own.width - size.width) <= 1 && abs($0.own.height - size.height) <= 1 } ?? false
  }

  /// In a slot again, by a hand or a key, before anybody could tell what macOS would have made of it. There is nothing for macOS to give back.
  func isDockedThoughMacOSNeverHadIt(_ window: WindowID) -> Bool {
    leftAsLargeAsTheirSlots[window].map { $0.tile == nil } == true && workspaces.values.contains { $0.isDocked(window) }
  }

  /// Part of `windowChanged`: half a second after the first word of a window whose look is still owed.
  func lookAgainIfItIsBackInReach(_ window: WindowSnapshot) {
    guard let left = leftToMacOS[window.id], !left.macOSMayBeMovingIt, !left.isToBeLookedAt, window.isPresent, !window.isFullScreen else { return }
    lookLater(at: window.id)
  }

  /// Part of `displaysChanged`: everything is laid out afresh, these windows too. What that leaves as it was is looked at afterwards.
  func endTheShieldsBecauseTheDisplaysChanged() {
    for window in leftToMacOS.keys.sorted() {
      leftToMacOS[window]!.macOSMayBeMovingIt = false
      lookLater(at: window)
    }
  }

  /// Part of `putBack`: a way out, or whoever else goes by the books, has given the window a frame before Arbor has looked at what macOS makes of it. If it
  /// is still there at the look, macOS has left it alone. The look begins its wait anew: for a fifth of a second after a call of Arbor's own
  /// the window server still lists the window as it was before, which must not pass for a move of macOS's either.
  func arborItselfHasPut(_ window: WindowID, at frame: CGRect) {
    guard leftToMacOS[window] != nil else { return }
    leftToMacOS[window]!.letGo = frame
    lookLater(at: window)
  }

  /// Part of `windowReplaced`: a native tab has taken the window's place, at its frame.
  func lookAtTheTabInstead(of old: WindowID, _ tab: WindowID) {
    guard let left = leftToMacOS.removeValue(forKey: old) else { return }
    leave(tab, toMacOS: left)
  }

  /// macOS has moved or sized `window` (or Arbor has, by the books). Where it is now is what is remembered, also if macOS's tile happens to be as large as the slot (with no
  /// gaps a half is a half). The note stays: the slot's size is what macOS gives back at the next drag. `frame` is the window server's
  /// word: its app may not have told all of the way yet.
  private func isAsMacOSMadeIt(_ window: WindowID, at frame: CGRect, on home: DisplayID) {
    leftAsLargeAsTheirSlots[window]?.tile = frame.size
    guard workspaces[home]?.floating[window] != frame else { return }
    workspaces[home]?.floating[window] = frame
    scheduleSave()
  }

  /// macOS has left `window` alone. If it came out of a slot it is as large as the slot, and takes its own size where it lies: under the point where
  /// the pointer let go of it, like any window dragged out of a slot, brought into view where that would be no place for a window. One move. If
  /// the view has moved on meanwhile and it is to go out of view, that is the one move, and it comes back at its own size.
  /// Returns false if its app did not answer.
  private func takesItsOwnSizeWhereItLies(
    _ window: WindowID, letGoAt pointer: CGPoint, on home: DisplayID, unlessItLeavesTheView mayLeave: Bool
  ) -> Bool {
    guard let own = leftAsLargeAsTheirSlots[window]?.own, let display = display(home),
      let dropped = droppedFrame(of: window, on: home, at: pointer, sizeOwed: own)
    else { return true }
    let frame = asItWas(dropped, on: display)
    defer { scheduleSave() }
    if mayLeave {
      workspaces[home]?.floating[window] = frame
      owedMoves.insert(window)
      relayout(home, reason: .enforce)
      if parked.contains(window) {
        leftAsLargeAsTheirSlots[window] = nil
        return true
      }
    }
    guard shrinkDropped(window, to: frame, on: home) else { return false }
    noteWhereItsUserLeftIt(window)
    return true
  }
}
