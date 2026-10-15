import ArborCore
import CoreGraphics
import Foundation

/// Keeping the window that has the keyboard in view.
///
/// The window system reports a focus change whenever any app's focused window changes. That is
/// not the same as the user switching to the window: an app in the background can change its focused
/// window (a chat opened by a notification), and a window can be given the keyboard before it is
/// reported as un-minimized, shown, or back on the active Space. So the camera follows a report
/// only once the window really has the keyboard and takes up space.
extension Controller {
  /// How often a focus report that does not match the keyboard yet is checked again, and how long
  /// apart. macOS says which app is frontmost on a different channel from the report, so either can
  /// be first; a report still unmatched after a second came from the background.
  static let focusCheckRetries = 4
  static let focusCheckInterval = 0.25

  /// Called by `start()` before its first layout. Nobody told Arbor where the keyboard went while it was not running, and a
  /// start ends with that window in view. So the view is worked out first, as `bringIntoView` would after a layout that took
  /// the window out of view: laid out for the view that was saved and then for the one that shows it, every window moved twice.
  ///
  /// The plan of that first layout is asked, on paper, whether it leaves the window out. A docked window inside the view that
  /// is too small to show there is not foreseen: room may be made for it, which only the layout itself can tell. That and
  /// a call (whether the view follows then depends on who asked, Controller+Hold.swift) are seen to
  /// afterwards, as before. Nor if Arbor is about to pause for the app in front: then nothing is laid out for long, and the
  /// view that was saved is the one to come back.
  ///
  /// Where the view does turn, the layout that follows starts from the plan as if it had been carried out: a Desktop that comes
  /// into view gathers what floats, and what opened unseen, which was to stay over the saved view, goes with that view.
  func letTheViewFollowTheKeyboardBeforeTheFirstLayout() {
    guard signOfACall == nil, !settings.pausesFor(frontmostApp?.bundleID), let focused = system.focusedWindow(), isManaged(focused),
      windows[focused]?.isPresent == true, let display = workspaceID(containing: focused)
    else { return }
    // A pause ends a summon and does not touch the window. With the keyboard still in it, it is summoned again where it is,
    // not sent to its corner first.
    guard !summonIfStashed(focused) else { return }
    workspaces[display]!.tree.activate(focused)
    guard let workspace = workspaces[display], let plan = layout(of: display) else { return }
    let sentAway = floatingMoves(on: display, layout: plan, reason: .camera).filter { if case .park = $0.move { true } else { false } }.map(\.window)
    let view: NodeID
    if let leaf = workspace.tree.leaf(containing: focused) {
      guard !workspace.tree.subtree(plan.camera, contains: leaf) else { return }
      view = viewThatShows(focused, leaf: leaf, on: display)
    } else {
      guard sentAway.contains(focused) else { return }
      view = workspace.guests?[focused] ?? viewThatBringsInWhatFloats(in: workspace)
    }
    layouts[display] = plan
    placedOnPurpose.subtract(workspace.floating.keys)
    // Sent away and fetched again, a window is where Arbor has it, also if that is where it stands already.
    for window in sentAway { settled[window] = windows[window]?.frame }
    moveCamera(on: display, to: view, refocus: false, layingOut: false)
    // As after every move that followed the keyboard (`bringIntoViewIfFocused`).
    keyboardHandOver.reveal = .init(
      window: focused, holder: focusHistory.first { $0 != focused }, display: display, time: now(),
      floatingInView: workspace.floating.keys.sorted().filter { !parked.contains($0) && !sentAway.contains($0) }
        .compactMap { window in windows[window].map { (window: window, frame: $0.frame) } })
  }

  /// Moves the camera to show `id` if it has the keyboard. If it does not (yet), looks again
  /// `retries` times.
  func bringIntoViewIfFocused(_ id: WindowID, retries: Int = Controller.focusCheckRetries) {
    guard isRunning, isManaged(id) else { return }
    runPostponedRelayouts()
    guard system.focusedWindow() == id, windows[id]?.isPresent == true else {
      Log.debug("focus report for \(id), which does not have the keyboard or takes no space; \(retries) checks left")
      // A pinned window is in view already, so there is nothing to bring into view. Raising one can make its app report it.
      if retries > 0, !isPinned(id) || parked.contains(id) { scheduleFocusCheck(id, retries: retries - 1) }
      return
    }
    Log.debug("\(id) has the keyboard")
    // Only now. A report is not the keyboard: an app in the background reports its windows too, and taking one of those for the
    // window in use made the going of the one that was no loss (`hadKeyboard`), so that nobody got the keyboard.
    recordFocus(id)
    cancelFocusLooks()
    // macOS picks once. Whatever this report is, the next one is somebody's own doing.
    let loss = keyboardHandOver.loss
    keyboardHandOver.loss = nil
    guard let display = workspaceID(containing: id), isOutOfView(id, on: display) else {
      bringIntoView(id)  // at most another tab of its group
      return
    }
    // The window that had the keyboard has just gone, and macOS picked this one. Nobody asked to see it.
    if let loss, now().timeIntervalSince(loss.time) < Self.handOverTime, loss.app == nil || loss.app == windows[id]?.pid,
      ensureFocusIsVisible(on: loss.display)
    {
      return
    }
    let camera = workspaces[display]?.camera
    let floatingInView = (workspaces[display]?.floating.keys.sorted() ?? []).filter { !parked.contains($0) }
      .compactMap { window in windows[window].map { (window: window, frame: $0.frame) } }
    bringIntoView(id)
    if workspaces[display]?.camera != camera {
      keyboardHandOver.reveal = .init(
        window: id, holder: focusHistory.first { $0 != id }, display: display, time: now(),
        floatingInView: floatingInView)
    }
  }

  // MARK: A keyboard the user did not move

  /// When the window with the keyboard is closed, minimized or hidden, macOS hands the keyboard on: to the app's
  /// next window, or to the app used before. If that window is out of view, following it would move the view
  /// although the user asked for nothing of the kind (and perhaps in front of an audience). So the view
  /// stays and a window in view gets the keyboard. Only if nothing is in view does the view follow, because
  /// typing into a window out of view is worse.
  ///
  /// macOS was seen to report the new focus a millisecond BEFORE the close or the minimize, and after a hide, and
  /// not at all when another app comes forward whose own focused window did not change. All three are covered.
  ///
  /// After a close or a minimize macOS picks a window of the same app, or none. Another app's window taking the
  /// keyboard then is the user's own ⌘Tab or click in the Dock, however soon it comes, and is followed.
  struct KeyboardHandOver {
    /// The view last moved to show `window`, which took the keyboard from `holder`.
    struct Reveal {
      var window: WindowID
      var holder: WindowID?
      var display: DisplayID
      var time: Date
      /// The floating windows that were in view before that move, and where. A window can float over a view that is not
      /// the Desktop's (a change of the arrangement takes none away), and nothing but this says that it did.
      var floatingInView: [(window: WindowID, frame: CGRect)]
    }
    var reveal: Reveal?
    /// The window with the keyboard went away, on this display. `app` is the process macOS picks the next window
    /// from, or nil if it picks another app (its own was hidden).
    var loss: (display: DisplayID, app: Int32?, time: Date)?
    /// The windows that are going to be looked at again (`scheduleFocusCheck`).
    var secondLooks: Set<WindowID> = []
  }

  /// Reports this close together belong to one event. The ones recorded were within 10 ms.
  static let handOverTime: TimeInterval = 0.3

  /// Whether `id` had the keyboard until now, or until the report that just moved the view. Ask before
  /// forgetting the window.
  func hadKeyboard(_ id: WindowID) -> Bool {
    focusHistory.first == id || keyboardHandOver.reveal?.holder == id
  }

  /// Call after `id`, which `hadKeyboard`, closed or stopped taking space, and `display` was laid out without it.
  /// `app` is its process, or nil if the whole app was hidden.
  func keyboardLeft(_ id: WindowID, of app: Int32?, on display: DisplayID) {
    guard isRunning else { return }
    if let reveal = keyboardHandOver.reveal, reveal.holder == id {
      keyboardHandOver.reveal = nil
      guard now().timeIntervalSince(reveal.time) < Self.handOverTime, app == nil || app == windows[reveal.window]?.pid
      else { return }
      // The new focus was reported first and the view has followed it. Take that back, unless nothing would be
      // in view there: then the view would only have to follow again.
      var before = workspaces[reveal.display]
      guard before?.retractLastMove() == true, let view = before?.camera, somethingWouldBeInView(on: reveal.display, at: view)
      else { return }
      if workspaces[reveal.display]?.retractLastMove() == true {
        // As if the view had never moved. Over a view without the Desktop the move back would send out whatever floats there,
        // and the move there may have gathered it onto a Desktop that came into view: each is where it was. With the
        // Desktop in the view the layout knows where they belong, also now that `id` has gone.
        let showsTheDesktop = workspaces[reveal.display].map { $0.tree.subtree(view, contains: $0.tree.desktop) } ?? true
        let back = showsTheDesktop ? [] : reveal.floatingInView.filter {
          windows[$0.window]?.isPresent == true && workspaces[reveal.display]?.isFloating($0.window) == true
        }
        placedOnPurpose.formUnion(back.map(\.window))
        relayout(reveal.display, reason: .camera, puttingBack: back)
        // Only for that layout: should the view have to move on, they go with it like any other.
        placedOnPurpose.subtract(back.map(\.window))
        if !ensureFocusIsVisible(on: reveal.display), let heir = system.focusedWindow(), heir != id,
          windows[heir]?.isPresent == true
        {
          bringIntoView(heir)
        }
        notify(.camera(reveal.display))
        scheduleSave()
      }
      return
    }
    keyboardHandOver.loss = (display, app, now())
    // In case nothing reports who has it now.
    scheduler.schedule(Self.lookAfterLoss, after: Self.focusCheckInterval) { [weak self] in
      guard let self else { return }
      guard let heir = self.system.focusedWindow(), heir != id else {
        // It was its app's last window, so macOS picked none, and shortcuts for the focused window have nothing to
        // act on.
        self.keyboardHandOver.loss = nil
        self.ensureFocusIsVisible(on: display)
        return
      }
      guard self.isManaged(heir), self.windows[heir]?.isPresent == true,
        let home = self.workspaceID(containing: heir), self.isOutOfView(heir, on: home)
      else { return }
      guard app == nil || app == self.windows[heir]?.pid else {
        self.bringIntoView(heir)
        return
      }
      self.keyboardHandOver.loss = nil
      if !self.ensureFocusIsVisible(on: display) { self.bringIntoView(heir) }
    }
  }

  /// Whether a view on `camera` would show a window that can take the focus: a docked one, or a floating one that is in
  /// view there (`floatingMoves`).
  private func somethingWouldBeInView(on display: DisplayID, at camera: NodeID) -> Bool {
    guard let workspace = workspaces[display], let layout = layout(of: display, camera: camera) else { return false }
    if !layout.windowFrames.isEmpty { return true }
    let showsTheDesktop = workspace.tree.subtree(layout.camera, contains: workspace.tree.desktop)
    return workspace.floating.keys.contains {
      windows[$0]?.isPresent == true && isManaged($0) && !workspace.isStashed($0) && !workspace.staysInView($0)
        && (showsTheDesktop || hostInView(of: $0, in: workspace, layout: layout) != nil)
    }
  }

  func isOutOfView(_ id: WindowID, on display: DisplayID) -> Bool {
    if parked.contains(id) { return true }
    // In a tile by the layout, and in plain sight (Controller+LetBe.swift).
    if isLetBe(id) { return false }
    return workspaces[display]?.isDocked(id) == true && layouts[display]?.windowFrames[id] == nil
  }

  // MARK: What waits

  /// The look after a loss and the second looks at reported windows wait under keys of their own, one for each window. Under
  /// one key, a report from an app in the background (a chat window opened by a notification) replaced whatever was due: the
  /// look after a loss, and the keyboard stayed with nobody; or the look at the window that was taking the keyboard, which
  /// stayed out of view and was typed into (K1473).
  private static let lookAfterLoss = "focus-after-loss"
  private func secondLook(at id: WindowID) -> String { "focus-again-\(id.rawValue)" }

  /// A newer report about the same window replaces the look that is due at it.
  private func scheduleFocusCheck(_ id: WindowID, retries: Int) {
    keyboardHandOver.secondLooks.insert(id)
    scheduler.schedule(secondLook(at: id), after: Self.focusCheckInterval) { [weak self] in
      self?.keyboardHandOver.secondLooks.remove(id)
      self?.bringIntoViewIfFocused(id, retries: retries)
    }
  }

  /// A window has the keyboard and has said so, or Arbor stops: nothing is left to find out.
  func cancelFocusLooks() {
    scheduler.cancel(Self.lookAfterLoss)
    for id in keyboardHandOver.secondLooks.sorted() { scheduler.cancel(secondLook(at: id)) }
    keyboardHandOver.secondLooks.removeAll()
  }
}
