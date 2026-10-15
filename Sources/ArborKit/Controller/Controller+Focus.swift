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
  /// `retries` times. `saysMacOS`: this is a report, which the going of the window that had the keyboard may be about to
  /// overtake (`waitsForAGoing`), and not something Arbor found out or has waited for already.
  func bringIntoViewIfFocused(_ id: WindowID, retries: Int = Controller.focusCheckRetries, saysMacOS: Bool = false) {
    guard isRunning, isManaged(id) else { return }
    runPostponedRelayouts()
    guard system.focusedWindow() == id, windows[id]?.isPresent == true else {
      Log.debug("focus report for \(id), which does not have the keyboard or takes no space; \(retries) checks left")
      // A pinned window is in view already, so there is nothing to bring into view. Raising one can make its app report it.
      if retries > 0, !isPinned(id) || parked.contains(id) { scheduleFocusCheck(id, retries: retries - 1) }
      return
    }
    Log.debug("\(id) has the keyboard")
    // Said again. The moment is counted from the first time.
    if saysMacOS, keyboardHandOver.waiting?.window == id { return }
    // Only now. A report is not the keyboard: an app in the background reports its windows too, and taking one of those for the
    // window in use made the going of the one that was no loss (`hadKeyboard`), so that nobody got the keyboard.
    recordFocus(id)
    cancelFocusLooks()
    let opened = keyboardHandOver.newcomers.removeValue(forKey: id)
    // macOS picks once. Whatever this report is, the next one is somebody's own doing.
    let loss = keyboardHandOver.loss
    keyboardHandOver.loss = nil
    guard let display = workspaceID(containing: id), isOutOfView(id, on: display) else {
      bringIntoView(id)  // at most another tab of its group
      return
    }
    // The window that had the keyboard has just gone, and macOS picked this one. Nobody asked to see it.
    if let loss, now().timeIntervalSince(loss.time) < Self.handOverTime, loss.app == nil || loss.app == windows[id]?.pid,
      aWindowInViewGetsTheKeyboard(after: loss.display, picked: display)
    {
      return
    }
    if saysMacOS, opened.map({ now().timeIntervalSince($0) < Self.handOverTime }) != true, waitsForAGoing(id) { return }
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
  /// stays and a window in view gets the keyboard. Only if nothing is in view, on any display, does the view follow,
  /// because typing into a window out of view is worse. (A view that has followed already and is taken back still
  /// looks at its own display alone.)
  ///
  /// macOS was seen to report the new focus a millisecond BEFORE the close or the minimize, and after a hide, and
  /// not at all when another app comes forward whose own focused window did not change. All three are covered.
  /// Both orders were recorded at a close: test windows name the next one up to 12 ms before, Safari and Finder 4 to 91 ms after.
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
    /// `window`, out of view, has taken the keyboard from `holder`, a window of the same app, and the view has not followed yet
    /// (`waitsForAGoing`). `views`: what each display's view was on then.
    var waiting: (window: WindowID, holder: WindowID, views: [DisplayID: NodeID])?
    /// The windows that have opened and have not had the keyboard yet, and when they opened.
    var newcomers: [WindowID: Date] = [:]
  }

  /// Reports this close together belong to one event. The ones recorded were within 91 ms, most of them within 13.
  static let handOverTime: TimeInterval = 0.3

  /// How long the view waits before it follows the keyboard from one window of an app to another that is out of view.
  /// At a close the report of the going was recorded 12 ms behind the one that names the next window, at a minimize 7 ms.
  public static let timeForAGoing: TimeInterval = 0.05

  /// The keyboard went from one window of an app to another, which is out of view. That is what ⌘` looks like, and it is what a
  /// close or a minimize looks like until the going is reported, a few milliseconds later. Followed at once and taken back,
  /// the whole view went there and back for one ⌘W. So the view waits that long: if the window goes, this was macOS's pick, and
  /// all is as if the going had been reported first (`keyboardLeft`).
  ///
  /// Only a report waits, and only within one app: after a going macOS picks no other, so ⌘Tab, a click and the Dock are followed
  /// at once, as are Arbor's own commands. Nor does macOS pick a window that has only just opened and takes the keyboard for
  /// the first time: ⌘N is shown in the same breath. What a hold turns away moves no view, and the keyboard goes back the
  /// sooner the better. But holding still lets in what follows a key, and ⌘W is one.
  private func waitsForAGoing(_ id: WindowID) -> Bool {
    // Who had the keyboard at the last look, also a window that Arbor does not arrange, or nobody: ⌘Tab out of such an app is a
    // switch between apps, whatever the history of the arranged ones says.
    guard !isHeld || (holdLevel == .still && hold.askedFor == id), let holder = following.focus?.window, holder != id,
      let had = windows[holder], had.isPresent, had.pid == windows[id]?.pid
    else { return false }
    keyboardHandOver.waiting = (id, holder, workspaces.mapValues(\.camera))
    scheduler.schedule(Self.lookWithinOneApp, after: Self.timeForAGoing) { [weak self] in
      guard let self, let waiting = self.keyboardHandOver.waiting else { return }
      self.keyboardHandOver.waiting = nil
      // Whoever has moved a view meanwhile has said where it goes, and the keyboard is on its way there.
      if self.workspaces.mapValues(\.camera) == waiting.views { self.bringIntoViewIfFocused(id) }
    }
    return true
  }

  private func stopWaitingForAGoing() {
    scheduler.cancel(Self.lookWithinOneApp)
    keyboardHandOver.waiting = nil
  }

  /// Called whenever a look finds the keyboard somewhere else (`noteFocus`), with or without a report. That the view followed it from `holder` to
  /// another window is over once it is back in `holder`, or has gone on after the time in which a going could still belong to it. Kept, the
  /// record made the going of `holder`, seconds later and with the keyboard in it, the late end of that story, and no loss: nobody got the
  /// keyboard. Within that time a third window changes nothing: an app can name two on the way.
  func theKeyboardHasGoneOn(to window: WindowID?) {
    guard let reveal = keyboardHandOver.reveal, reveal.window != window else { return }
    if reveal.holder == window || now().timeIntervalSince(reveal.time) >= Self.handOverTime { keyboardHandOver.reveal = nil }
  }

  /// Whether `id` had the keyboard until now, or until the report that just moved the view or is waiting to. Ask before
  /// forgetting the window.
  func hadKeyboard(_ id: WindowID) -> Bool {
    focusHistory.first == id || keyboardHandOver.reveal?.holder == id || keyboardHandOver.waiting?.holder == id
  }

  /// Call before `display` is laid out without `id`, which `hadKeyboard` and has closed or stopped taking space, and before a window that
  /// has closed is taken out of the arrangement. If the view has followed its heir it goes back now, on paper, and what is returned
  /// goes to `keyboardLeft`, whose layout is then the only one on that display: it shows the going and the way back as one move.
  /// Laid out for the going first, every window in view moved twice. And a group is kept whole only while the view is on it: what is
  /// left of one that `id` was part of can be a row in a row, which the tree does not keep, and history then led to everything.
  func theViewGoesBack(aheadOfTheGoingOf id: WindowID, of app: Int32?) -> KeyboardHandOver.Reveal? {
    // (A window that a rule has come to leave alone is in no arrangement, and nothing would be laid out for it.)
    guard isRunning, workspaceID(containing: id) != nil, let reveal = keyboardHandOver.reveal, isTheHeirs(reveal, after: id, of: app),
      workspaces[reveal.display]?.retractLastMove() == true
    else { return nil }
    keyboardHandOver.reveal = nil
    return reveal
  }

  /// Whether the view moved just now for the window macOS picked when `id` went, and a layout of where it came from shows something: otherwise
  /// it would only have to follow again. (A view with nothing in it shows what is around it, so this is seldom no.)
  private func isTheHeirs(_ reveal: KeyboardHandOver.Reveal, after id: WindowID, of app: Int32?) -> Bool {
    guard reveal.holder == id, now().timeIntervalSince(reveal.time) < Self.handOverTime, app == nil || app == windows[reveal.window]?.pid
    else { return false }
    var before = workspaces[reveal.display]
    guard before?.retractLastMove() == true, let view = before?.camera else { return false }
    return somethingWouldBeInView(on: reveal.display, at: view)
  }

  /// Call after `id`, which `hadKeyboard`, closed or stopped taking space, and `display` was laid out without it.
  /// `app` is its process, or nil if the whole app was hidden. `wentBack`: what `theViewGoesBack` returned; its display has not been laid out.
  func keyboardLeft(_ id: WindowID, of app: Int32?, on display: DisplayID, wentBack: KeyboardHandOver.Reveal? = nil) {
    guard isRunning else { return }
    // Its heir was named first and has waited for this. From here on it is the order in which the going comes first.
    let heir = keyboardHandOver.waiting.flatMap { $0.holder == id ? $0.window : nil }
    defer { if let heir { bringIntoViewIfFocused(heir, retries: 0) } }
    if heir != nil {
      stopWaitingForAGoing()
      keyboardHandOver.reveal = nil
    }
    var followed = wentBack
    if followed == nil, let reveal = keyboardHandOver.reveal, reveal.holder == id {
      keyboardHandOver.reveal = nil
      // The new focus was reported first and the view has followed it. Take that back, unless nothing would be
      // in view there: then the view would only have to follow again.
      guard isTheHeirs(reveal, after: id, of: app), workspaces[reveal.display]?.retractLastMove() == true else { return }
      followed = reveal
    }
    if let reveal = followed {
      if let view = workspaces[reveal.display]?.camera {
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
      if !self.aWindowInViewGetsTheKeyboard(after: display, picked: home) { self.bringIntoView(heir) }
    }
  }

  /// The window with the keyboard went, on `display`, and macOS picked one that Arbor keeps out of view, on `picked`. A window in
  /// view gets the keyboard, and "in view" is asked of all displays: first of `display`, where the eyes and the pointer are, then
  /// of `picked`, where the app goes on, then of the others; on each it is the window used last. A display that shows only its
  /// wallpaper once its last window has closed is what closing the last window means, and nobody at another display asked
  /// for its view to move. Returns whether there was one.
  ///
  /// Not where macOS picked none: no window is out of view with the keyboard in it then, and no app is brought forward on
  /// another display for it.
  private func aWindowInViewGetsTheKeyboard(after display: DisplayID, picked: DisplayID) -> Bool {
    // Each display once: asking costs a question to macOS.
    var asked: Set<DisplayID> = []
    return ([display, picked] + workspaces.keys.sorted()).first { asked.insert($0).inserted && ensureFocusIsVisible(on: $0) } != nil
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
  private static let lookWithinOneApp = "focus-within-one-app"
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
    stopWaitingForAGoing()
    for id in keyboardHandOver.secondLooks.sorted() { scheduler.cancel(secondLook(at: id)) }
    keyboardHandOver.secondLooks.removeAll()
  }
}
