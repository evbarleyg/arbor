import ArborCore
import CoreGraphics

/// A trial behind the switch `outOfViewIsBehind` (collab/QUESTIONS.md, Q29, point 8): out of view means behind, not away.
///
/// Without the switch a window that is not in the framed space goes to the display's corner (`park`). With it the window gets no
/// frame at all: it stays where it is, and what is in view comes in front of it. Mission Control, the app switcher and a glance find it
/// where it was left, it is not moved twice, and no app that hangs and no display that goes can leave it off screen.
///
/// `parked` goes on meaning "out of view": what the view follows, who may have the keyboard and what `state` says do not change.
/// Only where such a window is changes. So a click on what shows through is what ⌘Tab to it is: the view follows (rule 4).
extension Controller {
  /// Whether `window` stays where it is when it goes out of view. What its person sent away (a summoned window dismissed) was
  /// asked to be gone, and goes to the corner as ever.
  func staysBehind(_ window: WindowID) -> Bool {
    guard settings.outOfViewIsBehind else { return false }
    return workspaceID(containing: window).map { workspaces[$0]?.isStashed(window) != true } ?? true
  }

  /// Whether `window` is out of sight as well as out of view: in a corner, where nobody sees what is asked of it and where it is says nothing of
  /// where it belongs. Without the switch that is every window out of view. With it, one that was left behind is where it was.
  func isAway(_ window: WindowSnapshot) -> Bool {
    parked.contains(window.id) && !(settings.outOfViewIsBehind && !isOutOfView(window.frame))
  }

  /// `park` for a window that stays behind: the books are kept, and nothing is asked of its app.
  func leaveBehind(_ window: WindowID) {
    // In the corner since before the switch was thrown: there it stays until it is framed.
    guard !parked.contains(window), let frame = windows[window]?.frame else { return }
    // Nothing is owed by an app that is asked nothing.
    unplaced.remove(window)
    parkedAgain[window] = nil
    settled[window] = frame
    parked.insert(window)
  }

  /// Brings what `layout` has in view in front of what it leaves behind. Called by `relayout` before anything is moved, while a docked
  /// window still overlaps nothing and a raise changes nothing to see, so that no window grows underneath another; and once more
  /// when all are in place, for what the apps made of it.
  ///
  /// As few windows as will do are raised, from the back, so that what is in view keeps its order: one that something behind
  /// covers, and one that a window just raised would otherwise bury (a guest over its host, a pinned window). The keyboard stays where
  /// it is. Where the stacking cannot be told nothing is raised.
  func bringTheViewInFront(for layout: Layout, on displayID: DisplayID, reason: RelayoutReason) {
    guard settings.outOfViewIsBehind, let workspace = workspaces[displayID], let display = display(displayID) else { return }
    func frame(_ window: WindowID) -> CGRect? {
      guard window != drag?.window, let snapshot = windows[window], snapshot.isPresent else { return nil }
      return snapshot.frame
    }
    var inView = layout.windowFrames.filter { frame($0.key) != nil }
    var behind: [WindowID: CGRect] = [:]
    for window in parked.union(layout.hiddenWindows) where inView[window] == nil { behind[window] = frame(window) }
    for window in workspace.floating.keys where behind[window] == nil { inView[window] = frame(window) }
    for (window, move) in floatingMoves(on: displayID, layout: layout, reason: reason) {
      switch move {
      case .place(let target, _): (inView[window], behind[window]) = (target, nil)
      case .fill(let desktop): (inView[window], behind[window]) = (frameWhenFilling(desktop, with: window, on: display), nil)
      case .park: (inView[window], behind[window]) = (nil, frame(window))
      }
    }
    guard !behind.isEmpty else { return }
    let frontToBack = system.windowsFrontToBack()
    var raised: [CGRect] = []
    for (place, window) in frontToBack.enumerated().reversed() {
      guard let frame = inView[window] else { continue }
      guard frontToBack[..<place].contains(where: { behind[$0]?.overlaps(frame) == true }) || raised.contains(where: { $0.overlaps(frame) })
      else { continue }
      system.raise(window)
      raised.append(frame)
      Log.debug("raised \(window), which is in view, over what is behind")
    }
  }

  /// The keyboard has moved. A Mac's raise lifts a window over everything but the one that has the keyboard (collab/reality.json,
  /// raise-does-not-lift-a-window-over-the-active-apps-key-window), so a window that went behind with the keyboard in it has stayed in front
  /// of what was raised then. Now that the keyboard is in the view, the view can come in front of it.
  func theViewComesInFrontOnceItHasTheKeyboard() {
    guard settings.outOfViewIsBehind, !parked.isEmpty, let window = system.focusedWindow(), !parked.contains(window),
      let displayID = workspaceID(containing: window), let layout = layouts[displayID]
    else { return }
    bringTheViewInFront(for: layout, on: displayID, reason: .structure)
  }

  /// The switch has just been turned off. What was left behind is in plain view and no longer counts as out of view, so that the layout
  /// that follows sends it where windows out of view go without the switch.
  func whatWasLeftBehindIsInView() {
    parked = parked.filter { window in windows[window].map { isOutOfView($0.frame) } ?? true }
  }
}
