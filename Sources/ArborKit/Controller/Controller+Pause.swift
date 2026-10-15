import ArborCore
import CoreGraphics
import Foundation

/// Pausing (docs/features/F40-pause.md): for a game, a remote desktop or virtual machine that needs
/// ⌃⌥, or an app Arbor is fighting with.
///
/// Arbor lets go and nothing is lost: **a pause leaves the Mac as a quit would, and comes back.** Every window Arbor has
/// moved or resized goes back to where it was before, in its own size and in view, in one move: a docked one to the frame it
/// floated at (Controller+UndockedFrames.swift), or into its slot with everything shown if that is not known; a floating one
/// that docked windows pushed aside or squeezed to where its user left it. Nothing is raised, so the window in use stays in
/// front. (Whoever only wants ⌃⌥ for the app in front has Controller+PassThrough.swift, which moves nothing.) Tiles and seam
/// handles go away; Arbor stops observing windows; and the app hands back every shortcut except the ones that end the pause,
/// and both pointer taps (`inputSettings`, `KeyBindings.whilePaused`). Resuming is a launch that keeps the view: the arrangement and
/// camera are matched against the windows that exist by then. It also puts the floating windows back on the Desktop that the pause
/// took off it (`isBackFromThePause`), each in one move. Both ends are the paths that quitting and launching take.
extension Controller {
  func pause(minutes: Double?, forApp: Bool = false) -> CommandResult {
    guard isRunning || isPaused else { return .failure(statusText) }
    // Asked for by hand, even during a pause for an app: from now on only `resume` or its own end ends it.
    isPausedForApp = forApp
    // Both before `shutdown` saves, so that one write says it all.
    pauseEnd = minutes.map { now().addingTimeInterval($0 * 60) }
    if !isPaused {
      // Whatever the mouse was doing is over as far as Arbor is concerned.
      cancelDrag()
      edgeResize = nil
      // Set first: observers of the `.lifecycle` change that `shutdown` sends read it.
      isPaused = true
      endSummonsWithoutMoving()
      // Kept in memory as well, so that resuming does not depend on the file having been written.
      resumeState = persistedState()
      let before = windows.mapValues(\.frame)
      shutdown()
      pausedFrames = windows.mapValues(\.frame).filter { before[$0.key] != $0.value }
      // Arbor is not looking any more, so `state` and `ascii` must not pass off old frames as current.
      layouts.removeAll()
      windows.removeAll()
      lookOutForWindowsLeftInFullScreen()
      lookOutForWhatCouldNotComeBack()
      Log.info("paused")
    }
    // A second `pause` replaces the first one's end.
    scheduler.cancel("resume")
    savePause()
    guard let minutes else { return .success("paused until `resume`; \(Self.whatThePauseDid)") }
    scheduler.schedule("resume", after: minutes * 60) { [weak self] in self?.timedPauseEnded() }
    return .success("paused for \(Self.minutesText(minutes)); \(Self.whatThePauseDid)")
  }

  func resume() -> CommandResult {
    guard isPaused else { return .failure(isRunning ? "not paused" : statusText) }
    scheduler.cancel("resume")
    isPaused = false
    isPausedForApp = false
    pauseEnd = nil
    scheduler.cancel(Self.lookForFullScreenReturnsKey)
    // Windows and displays came and went unobserved. Start from what was saved and what exists
    // now, as a launch does.
    windows.removeAll()
    workspaces.removeAll()
    dormant.removeAll()
    layouts.removeAll()
    settled.removeAll()
    misfits.removeAll()
    isResuming = true
    start()
    isResuming = false
    pausedFrames.removeAll()
    // What was learned about windows that still exist stays; the rest closed during the pause.
    minimumSizes = minimumSizes.filter { windows[$0.key] != nil }
    focusHistory.removeAll { windows[$0] == nil }
    filter.ignoredWindowIDs.formIntersection(windows.keys)
    // Arbor was not looking when the keyboard went where it is now, and the view that just came back may not include
    // that window. A resume always ends with the focused window in view.
    if isRunning, let focused = system.focusedWindow() { windowFocused(focused) }
    Log.info("resumed")
    return .success("resumed")
  }

  func togglePause() -> CommandResult { isPaused ? resume() : pause(minutes: nil) }

  /// Whether the pause that is ending took floating `window` off the Desktop, to where its user had left it, and nobody has
  /// moved it since. A launch leaves floating windows where it finds them; a resume brings back what the pause undid.
  func isBackFromThePause(_ window: WindowID) -> Bool {
    guard isResuming, let left = pausedFrames[window], let now = windows[window]?.frame else { return false }
    return now.approximatelyEquals(left, tolerance: 2)
  }

  // MARK: A pause outlives an accident

  /// Writes what kind of pause this is, and when it ends, beside the arrangement it will bring back.
  func savePause() {
    guard isPaused, var state = resumeState else { return }
    state.pause = PersistedState.Pause(until: pauseEnd, forApp: isPausedForApp)
    resumeState = state
    guard state != lastSaved else { return }
    lastSaved = state
    store.save(state)
  }

  /// Someone paused Arbor for a game or a remote desktop, Arbor crashed, and the watchdog started it again. To
  /// run now would send windows out of view and take ⌃⌥ back in the middle of the game. Called first thing
  /// in `start()`: returns true if Arbor is paused again instead, having touched nothing.
  func comesBackPaused() -> Bool {
    guard restartedAfterAccident else { return false }
    // Only the first start of the process is the watchdog's doing.
    restartedAfterAccident = false
    guard !isPaused, resumeState == nil else { return false }
    // Read once: reading sets a file aside if it cannot be used, and a second reading would find nothing wrong.
    lastSaved = store.load()
    noteHowLoadingWent()
    let saved = lastSaved ?? PersistedState(workspaces: [:], hints: [:])
    resumeState = saved
    guard let pause = saved.pause else { return false }
    // No pause is asked for that lasts more than a day, so a clock set back does not stretch one beyond that.
    let left = pause.until.map { min($0.timeIntervalSince(now()), 24 * 60 * 60) }
    if let left, left <= 0 { return false }
    isPaused = true
    isPausedForApp = pause.forApp
    pauseEnd = pause.until
    // What `state` shows during a pause: the arrangement that will come back.
    displays = system.displays()
    hints = saved.hints
    dormant = saved.dormant
    for display in displays { workspaces[display.id] = saved.workspaces[display.id] ?? Workspace() }
    if let left {
      scheduler.schedule("resume", after: left) { [weak self] in self?.timedPauseEnded() }
    }
    Log.info("paused, as before Arbor ended without quitting")
    notify(.lifecycle)
    // The app the pause was for may not be in front any more.
    followFrontmostApp()
    return true
  }

  // MARK: Logout and shutdown

  /// How long Arbor stays out of the way when the session is said to end, in minutes.
  static let sessionEndPause: Double = 2

  /// Logout, restart or shutdown has begun. Apps save their windows' frames as they quit, so every window
  /// is let go of now as a quit would, in view and in its own size, before Arbor's own turn to quit comes. Not by
  /// quitting: any app can still cancel the logout, and Arbor would be gone from a session that goes on.
  public func sessionIsEnding() {
    guard isRunning else { return }
    Log.info("the session is ending")
    _ = pause(minutes: Self.sessionEndPause)
  }

  /// Quitting during a pause. The pause has let go of every window as a quit does, so nothing is left but to stop looking
  /// for what it still owed.
  func letGoAfterPause() {
    forgetWindowsLeftInFullScreen()
    pausedFrames.removeAll()
  }

  /// The settings the pointer taps should follow: the user's, with pinch and rectangle framing off
  /// while paused, while an app that keeps its own ⌃⌥ is frontmost (Controller+PassThrough.swift) and
  /// without Accessibility permission, so that no event passes through Arbor; and while the view is held, so
  /// that a slip of the fingers draws no band on a shared screen.
  public var inputSettings: Settings {
    guard isPaused || isPassingThrough || !accessibilityGranted || holdLevel == .view else { return settings }
    var quiet = settings
    quiet.gesturesEnabled = false
    quiet.frameRectangleModifier = "none"
    quiet.frameRectangleOnDesktop = false
    quiet.guardDesktopClicks = false
    return quiet
  }

  private static let whatThePauseDid = "windows are back in view, in their own sizes"

  static func minutesText(_ minutes: Double) -> String {
    let number = minutes == minutes.rounded() ? String(Int(minutes)) : String(minutes)
    return number == "1" ? "1 minute" : "\(number) minutes"
  }
}
