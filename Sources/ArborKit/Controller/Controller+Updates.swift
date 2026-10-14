import ArborCore
import Foundation

/// What the controller remembers about update checks. Nothing here is saved: a restart starts afresh.
public struct UpdateState {
  /// The answer of the last finished check, nil before the first.
  public internal(set) var lastDecision: UpdateDecision?
  /// When the next automatic check is due, nil while `automaticUpdateChecks` is off.
  public internal(set) var nextAutomaticCheck: Date?
  /// The check that is waiting for its answer, and whether a person is waiting for it too.
  var inFlight: (id: Int, userInitiated: Bool)?
  var lastID = 0

  public init() {}
}

extension Controller {
  /// Late enough that a Mac that has just logged in is online.
  static let firstUpdateCheckDelay: TimeInterval = 60
  static let updateCheckInterval: TimeInterval = 7 * 24 * 3600
  /// How long Arbor waits at most before looking at the clock again, and before trying again after a
  /// check that got no answer. Scheduled delays stand still while the Mac sleeps, so one week-long
  /// delay could take a month on a laptop.
  static let updateCheckTick: TimeInterval = 6 * 3600

  /// `version`: a query, so it works before `start()`.
  func versionReport() -> CommandResult {
    let version = "Arbor \(buildInfo.text)"
    // One line, for scripts, until somebody or the setting has asked about updates.
    let json = JSONValue(encoding: Query.Version(buildInfo))
    guard let update = updates.inFlight != nil ? "checking" : updates.lastDecision?.summary else {
      return CommandResult(ok: true, message: version, json: json)
    }
    return CommandResult(ok: true, message: version, text: "\(version)\nUpdates: \(update)", json: json)
  }

  /// What the menu calls `check-for-updates`. The one sign an automatic check gives of what it found.
  public var updateMenuTitle: String {
    updates.lastDecision?.page == nil ? "Check for Updates…" : "Update Available…"
  }

  /// `check-for-updates`, and the automatic checks. The answer arrives later: it goes to the log,
  /// `version` and the menu's title, and to `onUpdateDecision` if somebody asked. Needs no
  /// Accessibility permission.
  @discardableResult
  func checkForUpdates(userInitiated: Bool = true) -> CommandResult {
    guard let releaseFeed else { return .failure("this build cannot check for updates") }
    if let running = updates.inFlight {
      // One request is enough; whoever asked by hand still gets to see its answer.
      updates.inFlight = (running.id, running.userInitiated || userInitiated)
      return .success("already checking for updates")
    }
    updates.lastID += 1
    let id = updates.lastID
    updates.inFlight = (id, userInitiated)
    // The real feed gives up by itself sooner than this. A check must end whatever the feed does,
    // or every later one would be told that one is already running.
    scheduler.schedule("update-check-timeout", after: 30) { [weak self] in
      self?.finishUpdateCheck(id, .failed("no answer"))
    }
    releaseFeed.latestRelease { [weak self] lookup in self?.finishUpdateCheck(id, lookup) }
    if updates.inFlight == nil, let decision = updates.lastDecision { return .success(decision.summary) }
    return .success("checking for updates; `version` shows the answer")
  }

  private func finishUpdateCheck(_ id: Int, _ lookup: ReleaseLookup) {
    // A feed that answers twice, or after its check was given up, is not listened to.
    guard let check = updates.inFlight, check.id == id else { return }
    updates.inFlight = nil
    scheduler.cancel("update-check-timeout")
    let decision = UpdateCheck.decide(current: buildInfo.version, lookup: lookup)
    // Being offline for a moment does not make a release that was seen go away again.
    if case .failed = lookup, updates.lastDecision?.page != nil {} else { updates.lastDecision = decision }
    Log.info("update check: \(decision.summary)")

    if updates.nextAutomaticCheck != nil {
      var wait = Self.updateCheckInterval
      if case .failed = lookup { wait = Self.updateCheckTick }
      updates.nextAutomaticCheck = now().addingTimeInterval(wait)
      armUpdateTimer()
    }

    // Nothing may appear unasked: the user may be in a call or sharing the screen. What an automatic
    // check found waits in the menu.
    if check.userInitiated { onUpdateDecision?(decision) }
  }

  /// Starts or stops the automatic checks to match `settings.automaticUpdateChecks`. Runs when Arbor
  /// starts, stops or pauses and after every settings change; a check that is already due keeps its time.
  func scheduleUpdateChecks() {
    guard settings.automaticUpdateChecks, releaseFeed != nil else {
      updates.nextAutomaticCheck = nil
      scheduler.cancel("update-check")
      return
    }
    guard isRunning else {
      // Stopped or paused: no timer. The date stays, so that a pause does not bring the next check forward.
      scheduler.cancel("update-check")
      return
    }
    if updates.nextAutomaticCheck == nil {
      updates.nextAutomaticCheck = now().addingTimeInterval(Self.firstUpdateCheckDelay)
    }
    armUpdateTimer()
  }

  private func armUpdateTimer() {
    // No timer while Arbor is stopped or paused; starting and resuming arm it again.
    guard isRunning, let due = updates.nextAutomaticCheck else { return }
    // Never less than a second, so that a clock and a timer that disagree by a hair cannot spin.
    let wait = min(max(due.timeIntervalSince(now()), 1), Self.updateCheckTick)
    scheduler.schedule("update-check", after: wait) { [weak self] in self?.updateTimerFired() }
  }

  private func updateTimerFired() {
    guard isRunning, let due = updates.nextAutomaticCheck else { return }
    if now() >= due {
      // Moved on first, so that a feed that never answers cannot make this fire in a loop.
      updates.nextAutomaticCheck = now().addingTimeInterval(Self.updateCheckInterval)
      checkForUpdates(userInitiated: false)
    }
    armUpdateTimer()
  }
}
