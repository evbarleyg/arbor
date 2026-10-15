import ArborCore
import CoreGraphics
import Foundation

/// Double-clicks that are not Arbor's: what macOS, or the app, makes of a docked window stays (`AppsDoubleClick`).
extension Controller {
  /// Notes that what `window` does next was asked for. Only a docked window in view is ever put back, so only such a
  /// window needs the note.
  public func doubleClickReached(_ window: WindowID) {
    appsDoubleClick = nil
    guard isRunning, isManaged(window), !parked.contains(window), let display = workspaceID(containing: window),
      workspaces[display]!.isDocked(window)
    else { return }
    appsDoubleClick = AppsDoubleClick(window: window, time: now().timeIntervalSinceReferenceDate)
    Log.debug("a double-click reached \(window)")
  }

  /// Whether the new frame of a docked window is what macOS, or its app, made of a double-click. It then stays, like a
  /// window Arbor has given up on, until it is back in its slot, which is where macOS's own second double-click sends it, or
  /// a person asks Arbor for a layout: any command that lays out takes the window back, in one move (`stillLetBe`).
  func standsAsideAfterADoubleClick(on window: WindowSnapshot, display: DisplayID) -> Bool {
    // Asked in this order, so that the button is looked at only for the window that was double-clicked.
    guard let note = appsDoubleClick, note.window == window.id else { return false }
    let time = now().timeIntervalSinceReferenceDate
    guard note.isFresh(at: time) else {
      appsDoubleClick = nil
      return false
    }
    // With the button still down the note is kept: what comes of the double-click comes when it is up.
    guard note.explains(aChangeOf: window.id, at: time, buttonIsDown: system.isMouseButtonDown()) else { return false }
    appsDoubleClick = nil
    let began = settled[window.id]
    settled[window.id] = window.frame
    // Sent into its very slot (framed, without a gap), it is where it belongs, and is kept there.
    let slot = layouts[display]?.windowFrames[window.id]
    if let slot, slot.approximatelyEquals(window.frame, tolerance: 4) { return true }
    enforcement.leave(window.id)
    if let stood = began ?? slot { whereAZoomBegan[window.id] = (stood, slot) }
    scheduleSave()
    // It covers its neighbours now. The first few times, how to get them back. Not for whatever else an app made of it.
    if let slot, window.frame.width > slot.width + 4 || window.frame.height > slot.height + 4 { teach(.zoomedByMacOS, on: display) }
    Log.info("\(window.id) has a new frame after a double-click; it stays there until it is back in its slot or somebody asks for a layout")
    return true
  }

  /// Whether what is being done was asked of Arbor by a person: a command, from wherever it comes, or a hand on a window, a gap or
  /// a tile. Whatever says nothing counts as not asked, a timer too: then a window too many is let be, which a key mends, and
  /// none is taken back that its person had made big.
  var aPersonAsks: Bool { following.decides || actsOfAHand > 0 || drag != nil }

  /// The windows that a layout of `display` leaves where a double-click put them: every one that stays in view, unless a person
  /// asked for the layout. That a neighbour closed, was minimized or hidden, or that a rule docked a new window, says nothing about
  /// this one: the others share the room behind it, and what its person asked macOS for is not undone by the way (Q22). A display
  /// that comes, goes, moves or changes its size ends it for the windows on it (`updateDisplays`).
  func stillLetBe(in layout: Layout, on display: DisplayID) -> Set<WindowID> {
    // A resume is asked for, and is not about this: there and back a pause is nothing. Nor is a doubt about the permission.
    guard !aPersonAsks || isStartingUnasked else { return [] }
    return enforcement.leftAlone.filter { id in
      guard let window = windows[id], workspaces[display]?.isDocked(id) == true else { return false }
      // In the Dock, hidden with its app or on another Space it has no slot, and nobody has said a word about its size: macOS brings
      // it back as it went.
      guard window.isPresent else { return true }
      guard let slot = layout.windowFrames[id] else { return false }
      // If its slot has come to it, it is where it belongs, and is kept there. And nothing is let be where nobody can reach it.
      return !slot.approximatelyEquals(window.frame, tolerance: 4) && isWithinReach(window.frame) && !isUnderTheMenuBar(window.frame)
    }
  }

  /// The displays that stand as they stood in `then`: the same one, where it was, as large as it was, in whatever order macOS lists them. Not
  /// what the Dock and the menu bar leave of it. The Dock grows and shrinks with what is in it: seen on a Mac, a neighbour went to the Dock, the
  /// visible frame's height went from 674 to 676, macOS reported a change of the displays a third of a second later, and the window that was
  /// let be was docked for it. No frame outlives the display it was made for; one that is plugged in beside it takes nothing from it.
  func displaysThatStand(since then: [DisplaySnapshot]) -> Set<DisplayID> {
    Set(displays.filter { now in then.contains { $0.id == now.id && $0.frame == now.frame } }.map(\.id))
  }

  /// Nobody gets hold of a title bar that is under the menu bar, which has stopped hiding for one.
  func isUnderTheMenuBar(_ frame: CGRect) -> Bool {
    displays.first { $0.frame.contains(CGPoint(x: frame.midX, y: frame.minY + 1)) }.map { frame.minY < $0.visibleFrame.minY - 1 } ?? false
  }

  /// Half of it shows, or it covers half a display: a window whose app keeps it larger than the display is never mostly in view.
  func isWithinReach(_ frame: CGRect) -> Bool {
    displays.contains { display in
      let showing = frame.intersection(display.frame)
      return !showing.isNull && showing.width * showing.height >= 0.5 * min(frame.width * frame.height, display.frame.width * display.frame.height)
    }
  }

  /// What a layout that is no put-back does about the windows Arbor leaves to their apps: each gets a fresh start, but for those
  /// that are still let be. One that is docked nowhere any more (floated, or left out of a new arrangement) is nobody's to let be.
  func giveAFreshStart(in layout: Layout, on display: DisplayID) {
    guard let tree = workspaces[display]?.tree else { return }
    let kept = stillLetBe(in: layout, on: display)
    enforcement.reset(tree.allWindows.filter { !kept.contains($0) })
    enforcement.reset(enforcement.leftAlone.filter { id in !workspaces.values.contains { $0.isDocked(id) } })
    if !whereAZoomBegan.isEmpty { whereAZoomBegan = whereAZoomBegan.filter { enforcement.leftAlone.contains($0.key) } }
    if !isStartingUnasked { forgetWhoWasLetBeAndWaitsNoMore() }
  }

  // MARK: A pause, and Quit

  /// What is written: while Arbor runs, who is let be now; during a pause, who was when it began.
  func whoIsLetBeAndWhere() -> [WindowID: PersistedState.ZoomedWindow] {
    guard isRunning else { return letBeWhenThePauseBegan }
    var zoomed = letBeWhenThePauseBegan.filter { pendingSlots.contains($0.key) }
    for id in enforcement.leftAlone {
      guard let frame = windows[id]?.frame else { continue }
      zoomed[id] = PersistedState.ZoomedWindow(frame: frame, began: whereAZoomBegan[id]?.frame, slot: whereAZoomBegan[id]?.slot)
    }
    return zoomed
  }

  /// Before `shutdown`, which leaves these windows where they are (`letGo`) and forgets what is known about them.
  func noteWhoIsLetBeAsThePauseBegins() {
    letBeWhenThePauseBegan = whoIsLetBeAndWhere()
    displaysWhenThePauseBegan = displays
  }

  /// Called by `start()` before its first layout. A start that nobody asked for ends nothing: the end of a pause, a doubt about the
  /// permission that has passed, the watchdog after a crash. Nothing is let be across a quit and a start, which docks what was docked.
  /// Nor on a display that has changed, as while Arbor runs; after a crash nobody knows what they were, and the frames have to do.
  func letBeAgainWhatWasLetBe(saved: PersistedState?, nobodyAskedForThisStart: Bool) {
    defer { displaysWhenThePauseBegan = [] }
    guard nobodyAskedForThisStart else { return letBeWhenThePauseBegan = [:] }
    isStartingUnasked = true
    letBeWhenThePauseBegan = saved?.zoomedByMacOS ?? [:]
    let stand = displaysThatStand(since: displaysWhenThePauseBegan)
    // Of a window that is not listed nobody knows the display: any change ends it.
    if !displaysWhenThePauseBegan.isEmpty, stand.count != displays.count || stand.count != displaysWhenThePauseBegan.count {
      letBeWhenThePauseBegan = letBeWhenThePauseBegan.filter { workspaceID(containing: $0.key).map(stand.contains) == true && windows[$0.key] != nil }
    }
    for id in letBeWhenThePauseBegan.keys.sorted() { if let window = windows[id] { letBeAgainIfThePauseLeftItAlone(window) } }
    forgetWhoWasLetBeAndWaitsNoMore()
  }

  /// `window` is listed: at the resume, or later, when its person comes to the Space it is on (macOS lists only what shows, and its slot
  /// has waited for it: `claimPendingSlot`). One that anybody has moved or sized meanwhile is an ordinary docked window.
  func letBeAgainIfThePauseLeftItAlone(_ window: WindowSnapshot) {
    guard let note = letBeWhenThePauseBegan.removeValue(forKey: window.id), window.frame.approximatelyEquals(note.frame, tolerance: 2),
      workspaces.values.contains(where: { $0.isDocked(window.id) })
    else { return }
    enforcement.leave(window.id)
    settled[window.id] = window.frame
    whereAZoomBegan[window.id] = note.began.map { ($0, note.slot) }
  }

  /// A note lasts as long as the slot that waits for its window.
  func forgetWhoWasLetBeAndWaitsNoMore() {
    if !letBeWhenThePauseBegan.isEmpty { letBeWhenThePauseBegan = letBeWhenThePauseBegan.filter { pendingSlots.contains($0.key) } }
  }

  /// `window` stands for `old` from now on: another tab of its group, at the same frame.
  func handTheZoomOver(to window: WindowID, from old: WindowID) {
    guard enforcement.leftAlone.contains(old) else { return }
    enforcement.leave(window)
    whereAZoomBegan[window] = whereAZoomBegan.removeValue(forKey: old)
  }

  /// A hand has taken `window` by its title bar: where it ends up is for the hand to say, and for the layout that follows when it lets
  /// go. (Not so at an edge: a pull that moves no gap is followed by no layout, and the window stays as the hand left it, let be.)
  func aHandTakes(_ window: WindowID) {
    appsDoubleClick = nil
    if enforcement.leftAlone.contains(window) { isADockedWindowAgain(window) }
  }

  /// A window that was let be has a new frame. Back in its slot it is a docked window like any other again: kept there,
  /// and resized by its edges. Whatever brought it there has also used up the double-click that came before.
  ///
  /// macOS's second double-click returns it to the very frame it had before the first. That is home too, as long as its slot is the one
  /// it had: seen on a Mac, Terminal stands three or four points out of its slot, on its grid of characters.
  ///
  /// If the slot is another by now (a neighbour has closed meanwhile), the window would end up lying across the others, docked and let
  /// be. So from that double-click on it is a docked window that something has moved: once macOS has stopped moving it, Arbor moves
  /// it once more, into the slot as it is.
  func noteWhetherItIsBackInItsSlot(_ window: WindowSnapshot, on display: DisplayID) {
    let isOnItsWayBack = appsDoubleClick.map { $0.window == window.id && $0.isFresh(at: now().timeIntervalSinceReferenceDate) } ?? false
    if appsDoubleClick?.window == window.id { appsDoubleClick = nil }
    guard enforcement.leftAlone.contains(window.id), let slot = layouts[display]?.windowFrames[window.id] else { return }
    let began = whereAZoomBegan[window.id]
    // To the few points by which the Dock, which changes its size, changes every slot.
    let hasTheSlotItHad = began?.slot.map { $0.approximatelyEquals(slot, tolerance: 4) } ?? true
    if slot.approximatelyEquals(window.frame, tolerance: 4)
      || hasTheSlotItHad && began?.frame.approximatelyEquals(window.frame, tolerance: 2) == true
    {
      isADockedWindowAgain(window.id)
      Log.info("\(window.id) is back in its slot")
    } else if isOnItsWayBack, !hasTheSlotItHad {
      isADockedWindowAgain(window.id)
      Log.info("\(window.id) is on its way back from where a double-click sent it, and its slot is another now")
      scheduleEnforce(display)
    }
  }

  private func isADockedWindowAgain(_ window: WindowID) {
    enforcement.reset([window])
    whereAZoomBegan[window] = nil
    scheduleSave()
    // The line on screen does not outlive what it says.
    hideHeadsUp()
  }
}
