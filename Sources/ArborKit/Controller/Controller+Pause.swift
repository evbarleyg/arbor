import ArborCore
import CoreGraphics
import Foundation

/// Pausing (docs/features/F40-pause.md): for a game, a remote desktop or virtual machine that needs
/// ⌃⌥, or an app Arbor is fighting with.
///
/// Arbor lets go and nothing is lost. The commonest pause is someone framed on a virtual machine who wants
/// ⌃⌥ back for a while, and the best pause for them is one they cannot see. So **what is in view is not
/// touched**: same place, same size. **What is out of view comes back on screen**, because a window parked out
/// of view while nothing reacts to ⌘Tab would be lost: at the frame it floated at before it was docked if that is
/// known (Controller+UndockedFrames.swift), otherwise in its slot with everything shown. It is not raised, so it ends up
/// behind what is in view, as on any Mac. Tiles and seam handles go away; Arbor stops observing windows; and
/// the app hands back every shortcut except the ones that end the pause, and both pointer taps (`inputSettings`,
/// `KeyBindings.whilePaused`). Resuming is a launch: the arrangement and camera are matched against the windows
/// that exist by then; if nothing was touched meanwhile it is as invisible as the pause. Both ends reuse the
/// paths that quitting and launching already exercise.
extension Controller {
  /// - Parameter lettingGoOfEverything: as a quit does, what is in view too: for a pause that most likely ends in one.
  func pause(minutes: Double?, forApp: Bool = false, lettingGoOfEverything: Bool = false) -> CommandResult {
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
      shutdown(leavingWhatIsInView: !lettingGoOfEverything)
      // What a quit during the pause still has to put back: nothing, if everything has been let go of.
      pausedFrames = lettingGoOfEverything ? [:] : windows.mapValues(\.frame)
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
    pausedFrames.removeAll()
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
    _ = pause(minutes: Self.sessionEndPause, lettingGoOfEverything: true)
  }

  /// Quitting during a pause. The pause left what was in view in the shape of its slot, and a quit leaves no
  /// trace: Arbor looks once more, puts the windows back where they floated, and stops looking. Nothing is laid
  /// out or parked on the way. A window somebody has moved since the pause began is theirs, and stays.
  func letGoAfterPause() {
    forgetWindowsLeftInFullScreen()
    guard isPaused, !pausedFrames.isEmpty else { return }
    let left = pausedFrames
    pausedFrames.removeAll()
    system.start()
    defer {
      system.stop()
      windows.removeAll()
    }
    displays = system.displays()
    for window in system.allWindows() { windows[window.id] = window }
    for id in workspaces.keys.sorted() {
      guard let workspace = workspaces[id], let display = display(id) else { continue }
      for window in workspace.allWindows {
        guard isManaged(window), let now = windows[window], let then = left[window],
          now.frame.approximatelyEquals(then, tolerance: 2),
          hints[window].map({ $0.bundleID == now.bundleID }) ?? true
        else { continue }
        if let frame = frameAsItWas(of: window, on: id) {
          if wasPushedAside(window, from: frame) { putBack(window, at: frame, on: display) }
        } else if let preferred = workspace.floating[window], wasPushedAside(window, from: preferred) {
          putBack(window, at: asItWas(preferred, on: display), on: display)
        }
      }
    }
    Log.info("quit while paused; windows nobody had moved went back to where they floated")
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

  private static let whatThePauseDid = "windows that were out of view are back on screen"

  static func minutesText(_ minutes: Double) -> String {
    let number = minutes == minutes.rounded() ? String(Int(minutes)) : String(minutes)
    return number == "1" ? "1 minute" : "\(number) minutes"
  }
}
