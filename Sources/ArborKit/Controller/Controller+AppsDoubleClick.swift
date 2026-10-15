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
  /// the layout changes: any command that lays out takes the window back, in one move.
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
    settled[window.id] = window.frame
    // Sent into its very slot (framed, without a gap), it is where it belongs, and is kept there.
    let slot = layouts[display]?.windowFrames[window.id]
    if let slot, slot.approximatelyEquals(window.frame, tolerance: 4) { return true }
    enforcement.leave(window.id)
    // It covers its neighbours now. The first few times, how to get them back. Not for whatever else an app made of it.
    if let slot, window.frame.width > slot.width + 4 || window.frame.height > slot.height + 4 { teach(.zoomedByMacOS, on: display) }
    Log.info("\(window.id) has a new frame after a double-click; it stays there until it is back in its slot or the layout changes")
    return true
  }

  /// A window that was let be has a new frame. Back in its slot it is a docked window like any other again: kept there,
  /// and resized by its edges. Whatever brought it there has also used up the double-click that came before.
  func noteWhetherItIsBackInItsSlot(_ window: WindowSnapshot, on display: DisplayID) {
    if appsDoubleClick?.window == window.id { appsDoubleClick = nil }
    guard enforcement.leftAlone.contains(window.id), let slot = layouts[display]?.windowFrames[window.id],
      slot.approximatelyEquals(window.frame, tolerance: 4)
    else { return }
    enforcement.reset([window.id])
    // The line on screen does not outlive what it says.
    hideHeadsUp()
    Log.info("\(window.id) is back in its slot")
  }
}
