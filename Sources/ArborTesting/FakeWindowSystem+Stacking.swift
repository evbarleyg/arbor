import ArborCore
import ArborKit

/// Which window is in front of which. In a file of its own so that it stays out of the way of other additions.
extension FakeWindowSystem {
  public func raise(_ window: WindowID) {
    guard windows[window] != nil else { return }
    raiseLog.append(window)
    bringToFront(window)
    // It becomes its app's focused window as well, which is the keyboard if that app is in front.
    if comesOutOfTheDockIfRaised(window) {
      if let holder = focused, windows[holder]?.snapshot.pid == windows[window]?.snapshot.pid {
        focused = window
        if echoes.focus { undelivered.append(.focus(window)) }
      }
      if echoes.focus { undelivered.append(.cameBack(window)) }
    }
  }

  /// Focusing or raising a window brings it to the front. Windows that never were lie behind the
  /// ones that were, newest in front, as they do when apps open them one after another.
  public func windowsFrontToBack() -> [WindowID] {
    guard !stackingIsUnknown else { return [] }
    let front = raised.filter { windows[$0] != nil }
    return front + windows.keys.filter { !front.contains($0) }.sorted(by: >)
  }

  public func clearRaiseLog() { raiseLog.removeAll() }

  /// The user clicks in a window: the button goes down, the window comes to the front and, unless it has it
  /// already, takes the keyboard; the button comes up. With `release: false` it stays down.
  public func userClick(_ window: WindowID, release: Bool = true) {
    guard windows[window] != nil else { return }
    mouseDown = true
    events?.pointerPressed()
    if focused == window { bringToFront(window) } else { userFocus(window) }
    if release { mouseDown = false }
  }

  func bringToFront(_ window: WindowID) {
    raised.removeAll { $0 == window }
    raised.insert(window, at: 0)
  }

  /// The user clicks in a window of an app that is not in front, told in the order a Mac tells it (macOS 26, recorded on a hosted Mac,
  /// `collab/reality.json`): macOS brings the app forward first and passes the press on afterwards. So the window is reported as focused
  /// while the button is down already, the app says that it is active, only then is the press heard of, and the app that was in front
  /// says last that it no longer is. `userClick` tells of the press first, which is the order within one app.
  public func userClickBringsAppForward(_ window: WindowID) {
    guard windows[window] != nil else { return }
    mouseDown = true
    userFocus(window)
    events?.keyboardFocusMoved()
    mouseDown = false
    events?.pointerPressed()
    events?.keyboardFocusMoved()
  }
}
