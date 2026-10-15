import ArborCore
import CoreGraphics
import Foundation

/// Accessibility permission taken away while Arbor runs (docs/features/F63-permission-taken-away.md).
///
/// Without it Arbor can move nothing, not even back into view. So it notices quickly, stops without touching
/// a window, says what happened and what to do, and starts again, as at launch, when the permission returns.
/// Stopping is `shutdown` without the moves and recovering is `start`: paths that quitting, pausing and
/// launching exercise all the time. The one exception: a doubt that passes by itself ends no pause (`goOnPausing`).
extension Controller {
  /// What was out of view, and so out of reach, when the permission went.
  public struct PermissionLoss: Equatable, Sendable {
    public var windows: Int
    /// The names of their apps, each once, in alphabetical order. Never titles: this goes into replies and the log.
    public var apps: [String]
    /// When it went.
    public var since: Date
    /// Whether the person had paused Arbor, and so given its keys away.
    public var duringAPause = false
    /// When macOS last said no: as far as Arbor knows, the loss lasted from `since` until then.
    var lastNo: Date
    /// The pause that was on, for the case that nobody took anything away (`regainAccessibility`).
    var pause: Pause?
    /// The app Arbor pauses for in which it ran all the same, because its person had resumed it there by hand.
    var resumedInside: String?

    /// A pause as it was when the permission went. Its end stays where it is, in `pauseEnd`.
    struct Pause: Equatable, Sendable {
      var forApp: Bool
      var isArborsOwn: Bool
      var frames: [WindowID: CGRect]
    }

    /// Whether it was over so soon that nobody can have mended it: the privacy daemon restarted, say. Arbor cannot tell a person's grant from a
    /// doubt that passes but by the time it lasted. Measured to the last no, not to the yes, which is heard up to a second late: so
    /// no loss that was really shorter counts as longer. One that was a little longer may count as a doubt, which is the milder error.
    var wasADoubt: Bool { lastNo.timeIntervalSince(since) < Controller.shortestLossWorthAFuss }
  }

  /// A loss shorter than this is taken for a false alarm, or for a slip of the finger: the view stays as it was.
  nonisolated static let shortestLossWorthAFuss: TimeInterval = 3
  /// The ways home lead to the Accessibility pane at most this often, however hard they are hammered.
  static let secondsBetweenVisitsToSettings: TimeInterval = 10
  static let secondsAThoroughYesHolds: TimeInterval = 1

  /// Whether Arbor is in business: running, paused, or waiting to get its permission back. False before the first
  /// start and after quitting. While it is true the app follows `inputSettings`. What `activeBindings` says it holds for longer: from before
  /// its menu bar item is made until it quits.
  public var isInBusiness: Bool { isRunning || isPaused || permissionLoss != nil }

  // MARK: Noticing

  /// Asks macOS now and acts on the answer. `beyondDoubt`: there is a second reason to believe a "no".
  /// Does nothing before the first `start()`: until then the app waits for the first grant itself.
  ///
  /// `inPassing`: before a command. A held shortcut or the steps of a pinch are tens of commands a second, and asking
  /// thoroughly costs a visit to the window server and to the privacy daemon each time. So within a second of a
  /// thorough "yes" only the flag is read. If it lags, the calls that follow are refused, which is heard too.
  public func askAboutAccessibility(beyondDoubt: Bool = false, inPassing: Bool = false) {
    guard isWatchingPermission, let probe = accessibilityProbe else { return }
    let isFresh = lastThoroughYes.map { now().timeIntervalSince($0) < Self.secondsAThoroughYesHolds } ?? false
    let thoroughly = !(inPassing && isFresh)
    // The one thing Arbor asks of macOS that does not go through a protocol in Platform/, so it sees to its own line in a trace.
    func ask(_ thoroughly: Bool) -> Bool {
      traceRecorder?.read("mayUseAccessibility", [thoroughly]) { probe(thoroughly) } ?? probe(thoroughly)
    }
    var answer = ask(thoroughly)
    if answer, thoroughly { thoroughWayHasSaidYes = true }
    if !answer, thoroughly, !thoroughWayHasSaidYes, ask(false) {
      // The thorough way has never yet said yes in this process, and the flag does. Nobody has seen what macOS lets a process
      // do that was given the permission while it ran, which is everybody's first minute with Arbor: if it has to be
      // started again before it may make an event tap, that is no reason to stop arranging windows. The flag is
      // believed, as it was before there was a thorough way, until the thorough way has shown that it works here.
      if !saidThatTheThoroughWayFails { Log.error("macOS says Arbor has the Accessibility permission and refuses it an event tap") }
      saidThatTheThoroughWayFails = true
      answer = true
    } else if !answer {
      lastThoroughYes = nil
    } else if thoroughly {
      lastThoroughYes = now()
    }
    if !answer { permissionLoss?.lastNo = now() }
    switch permissionWatch.heard(answer, beyondDoubt: beyondDoubt) {
    case .lost: loseAccessibility()
    case .returned: regainAccessibility()
    case .none: break
    }
    scheduleAccessibilityQuestion()
  }

  /// A call was refused. That is a second opinion, but it arrives in the middle of whatever made the call (a layout, a
  /// drop), which must not have the ground pulled from under it: the question is put as soon as that has returned.
  public func accessibilityWasRefused() {
    guard isWatchingPermission, accessibilityGranted else { return }
    scheduler.schedule("accessibility", after: 0) { [weak self] in self?.askAboutAccessibility(beyondDoubt: true) }
  }

  /// Begins to ask, from `start()`. Without a probe (tests, arbor-sim unless they set one) nobody asks.
  func watchAccessibility() {
    guard accessibilityProbe != nil else { return }
    if !isWatchingPermission {
      isWatchingPermission = true
      permissionWatch = PermissionWatch()
    }
    scheduleAccessibilityQuestion()
  }

  private func scheduleAccessibilityQuestion() {
    scheduler.schedule("accessibility", after: permissionWatch.secondsToNextQuestion) { [weak self] in
      self?.askAboutAccessibility()
    }
  }

  // MARK: Stopping and starting

  private func loseAccessibility() {
    let apps = Set(parked.compactMap { windows[$0]?.appName }).sorted()
    // Granting it again means wanting Arbor, as launching it does: a pause does not outlive this. Unless nobody granted anything, so the pause
    // is kept aside: see `regainAccessibility`.
    let loss = PermissionLoss(
      windows: parked.count, apps: apps, since: now(), duringAPause: isPaused && !isPausedForApp && !pauseIsArborsOwn, lastNo: now(),
      pause: isPaused ? .init(forApp: isPausedForApp, isArborsOwn: pauseIsArborsOwn, frames: pausedFrames) : nil,
      resumedInside: isRunning && frontmostAppPaused ? frontmostApp?.bundleID : nil)
    // Set first: observers of the `.lifecycle` change read them.
    accessibilityGranted = false
    permissionLoss = loss
    Log.error("Accessibility permission was taken away with \(loss.windows) window(s) out of view")
    scheduler.cancel("resume")
    isPausedForApp = false
    pauseIsArborsOwn = false
    // If an app Arbor pauses for is still in front when it starts again, that is a new pause.
    frontmostAppPaused = false
    if isPaused {
      isPaused = false
      pausedFrames.removeAll()
      // Nothing is shut down here that would take the pause's own line away, and whoever hears of this forgets that it is up.
      hideHeadsUp()
      notify(.lifecycle)
    } else if isRunning {
      overlays.showDropPreview(nil)
      dropOverdueSlotsBeforeAStop()
      // Kept in memory as well, so that coming back does not depend on the file having been written.
      resumeState = persistedState()
      shutdown(movingWindows: false)
      // Arbor cannot look any more, so `state` and `ascii` must not pass off old frames as current.
      layouts.removeAll()
      windows.removeAll()
    }
    // Whoever switched Arbor off on purpose, with nothing missing, is not nagged.
    if loss.windows > 0 { askForAccessibility?() }
  }

  private func regainAccessibility() {
    let loss = permissionLoss
    accessibilityGranted = true
    isListedUnderAccessibility = true
    permissionLoss = nil
    Log.info("Accessibility permission is back")
    // A doubt that passes by itself ends nothing. Nobody granted anything, so nobody said that they want Arbor back: to run now would end the
    // pause they asked for, take their keys back and lay their windows out, in the middle of the game: three unasked acts from one false alarm.
    if let loss, loss.wasADoubt, let pause = loss.pause { return goOnPausing(pause) }
    // Nor is it a new way into an app Arbor pauses for (`followFrontmostApp`).
    if let loss, loss.wasADoubt, let app = loss.resumedInside, app == frontmostApp?.bundleID { frontmostAppPaused = true }
    start()
    filter.ignoredWindowIDs.formIntersection(windows.keys)
    lastVisitToSettings = nil
    // They were promised their windows back. Back returns to the view this replaces. Not after a false alarm, which
    // is over in a second: nobody read a promise, and the view must not change for nothing.
    if let loss, loss.windows > 0, isRunning, !loss.wasADoubt {
      _ = home()
    }
    // As after a pause: Arbor was not looking when the keyboard went where it is now.
    if isRunning, let focused = system.focusedWindow() { keyboardIs(in: focused, saysMacOS: false) }
  }

  /// The pause goes on: no window is touched, no key taken.
  private func goOnPausing(_ pause: PermissionLoss.Pause) {
    isPaused = true
    isPausedForApp = pause.forApp
    pauseIsArborsOwn = pause.isArborsOwn
    pausedFrames = pause.frames
    Log.info("still paused: the permission was gone for a moment only")
    // What a key was told meanwhile is no longer true, and nothing starts here that would take it away by the way.
    hideHeadsUp()
    notify(.lifecycle)
    if let pauseEnd {
      // Its end may have come meanwhile.
      scheduler.schedule("resume", after: max(pauseEnd.timeIntervalSince(now()), 0)) { [weak self] in self?.timedPauseEnded() }
    }
    // What the pause still owes. Each of these looks again only while there is a pause, so a look that fell into the doubt was the last.
    lookOutForWindowsLeftInFullScreen()
    lookOutForWhatCouldNotComeBack()
    // The app it was for may have left the front meanwhile.
    followFrontmostApp()
  }

  /// Whether a shortcut that failed for want of the permission should open the Accessibility pane now. Only one of the ways home, pressed by
  /// someone who misses a window: every other key is answered by the line on screen, which takes nobody out of the app they are
  /// in (`whyAKeyDidNothing`). And someone hammering ⌃⌥Space in a fright must not get a stack of System Settings coming forward.
  public func shouldOpenAccessibilitySettings(after command: Command = .showAll) -> Bool {
    guard !accessibilityGranted, command.bringsWindowsBack, (permissionLoss?.windows ?? 0) > 0 else { return false }
    if let last = lastVisitToSettings, abs(now().timeIntervalSince(last)) < Self.secondsBetweenVisitsToSettings {
      return false
    }
    lastVisitToSettings = now()
    return true
  }

  /// "Open Settings…" in the permission's row, and a shortcut that failed for want of it.
  ///
  /// An app is in the list under Accessibility only once macOS has been asked about it, and macOS answers with a dialog of its own, whose
  /// button opens the pane. With the pane opened from here as well, that dialog is covered, and is left lying over the person's windows
  /// long after the grant (seen on a hosted Mac). So an Arbor that is not in the list leaves it to macOS, and opens the pane only if macOS
  /// has not asked after all. One that is in the list opens the pane and asks nothing.
  public func sendToAccessibilitySettings() {
    guard let errand = accessibilityErrand else { return }
    scheduler.cancel(Self.paneKey)
    guard !isListedUnderAccessibility else { return errand.openPane() }
    isListedUnderAccessibility = true
    errand.askMacOS()
    scheduler.schedule(Self.paneKey, after: Self.secondsMacOSHasToAsk) { [weak self] in
      guard let self, !self.accessibilityGranted, !errand.macOSIsAsking() else { return }
      errand.openPane()
    }
  }

  private static let paneKey = "accessibility-pane"
  static let secondsMacOSHasToAsk: TimeInterval = 2

  // MARK: Saying so

  static let whereToGrantAccessibility = "System Settings → Privacy & Security → Accessibility"
  /// The first sentence everywhere: `status`, refused commands, the menu.
  static let whatHappened = "Arbor's Accessibility permission was taken away, so it cannot move windows"

  /// The reply to `status` and to every command that cannot run, while the permission is missing.
  var permissionSentence: String {
    guard let loss = permissionLoss else {
      return "waiting for Accessibility permission (\(Self.whereToGrantAccessibility))"
    }
    let start = Self.whatHappened + ". "
    guard loss.windows > 0 else { return start + "Grant it again under \(Self.whereToGrantAccessibility)" }
    return start + "\(Self.strandedWindows(loss)) and \(loss.windows == 1 ? "comes" : "come") back as soon as it is "
      + "granted again: \(Self.whereToGrantAccessibility)"
  }

  /// What the line on screen says when a key was taken and nothing could be done, or nil while Arbor has the permission. The same each
  /// time, and short-lived: never a dialog, and nobody is taken out of the app they are in.
  var whyAKeyDidNothing: HeadsUpModel? {
    guard !accessibilityGranted else { return nil }
    // Not the way to the switch: for a new build over an old grant the switch there looks on. Check Setup says to switch it off and on again.
    return HeadsUpModel(kind: .problem, text: "Arbor needs the Accessibility permission", hint: "Check Setup… in its menu")
  }

  /// The same in lines short enough for a menu; empty unless the permission was taken away.
  public var permissionMenuLines: [String] {
    guard let loss = permissionLoss else { return [] }
    // Menus have typographic apostrophes, replies plain ones. What follows the comma the lines under it say better.
    let first = Self.whatHappened.replacingOccurrences(of: "'", with: "’").split(separator: ",")[0].description
    guard loss.windows > 0 else { return [first] }
    return [
      first,
      Self.strandedWindows(loss),
      loss.windows == 1 ? "It comes back as soon as you grant it again" : "They come back as soon as you grant it again",
    ]
  }

  /// Quitting is the last of the three ways home, and the one time it does not lead there it has to say so.
  public var quitTitle: String {
    guard let loss = permissionLoss, loss.windows > 0 else { return "Quit Arbor" }
    return "Quit Arbor (\(Self.count(loss.windows, "window")) \(loss.windows == 1 ? "stays" : "stay") out of view)"
  }

  /// "1 window (Safari) is out of view", "3 windows (Mail, Notes and Safari) are out of view".
  private static func strandedWindows(_ loss: PermissionLoss) -> String {
    var names = loss.apps.prefix(3).map { $0 }
    if loss.apps.count > 3 { names.append(count(loss.apps.count - 3, "other app")) }
    let list =
      names.count < 2 ? names.joined() : names.dropLast().joined(separator: ", ") + " and " + names[names.count - 1]
    return count(loss.windows, "window") + (list.isEmpty ? "" : " (\(list))") + (loss.windows == 1 ? " is" : " are")
      + " out of view"
  }
}

/// What only the app can do about the Accessibility pane.
public struct AccessibilityErrand {
  /// Has macOS put Arbor in the list; it answers with its own dialog.
  public var askMacOS: @MainActor () -> Void
  /// Whether that dialog is on the screen.
  public var macOSIsAsking: @MainActor () -> Bool
  public var openPane: @MainActor () -> Void

  public init(
    askMacOS: @escaping @MainActor () -> Void, macOSIsAsking: @escaping @MainActor () -> Bool, openPane: @escaping @MainActor () -> Void
  ) {
    self.askMacOS = askMacOS
    self.macOSIsAsking = macOSIsAsking
    self.openPane = openPane
  }
}
