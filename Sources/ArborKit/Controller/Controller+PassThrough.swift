import ArborCore

/// Apps that keep their own ⌃⌥ (docs/features/F41-pass-through-apps.md).
///
/// A global shortcut is taken from every app, and ⌃⌥ is Emacs's C-M-, AltGr in a Windows remote desktop
/// or virtual machine and a dozen commands of an IDE. While an app on `passThroughApps` is frontmost Arbor
/// lets go of its shortcuts and pointer gestures, as it does during a pause, and goes on arranging
/// windows: this is about who gets the keys, not about who places the windows. For an app on
/// `pauseForApps` (a game that changes the display's resolution) Arbor pauses altogether.
///
/// Everything is decided here. The app reports which app came to the front, and registers
/// `activeBindings` and follows `inputSettings` again when told that they changed (`Change.input`,
/// `.lifecycle`, `.settings`), which an ordinary switch between two apps does not do.
extension Controller {
  /// Whether the frontmost app keeps its own ⌃⌥.
  public var isPassingThrough: Bool { settings.passesThrough(frontmostApp?.bundleID) }

  /// The shortcuts to hold right now: the ones in effect, less what the person has given away.
  ///
  /// **While Arbor's item is in the menu bar, a key of the map in effect never reaches another app, unless the person said so themselves**: for
  /// an app (`passThroughApps`, `pauseForApps`), for all (`hotkeysEnabled`), or by pausing Arbor. The icon says that Arbor is there, and the
  /// fingers believe it: on a tester's Mac a key of Arbor's ran what the app in front has on that key, which could not be taken back
  /// (collab/IDEAS.md, I16). So where nobody said anything and Arbor merely cannot act (it waits for the Accessibility permission, at a first launch
  /// or as a new build that an old grant does not fit; the permission was taken away, or seems to have been for a second) it keeps its keys, takes the
  /// press, does nothing and says why (`whyAKeyDidNothing`). A hot key needs no permission.
  public var activeBindings: [KeyBinding] {
    guard settings.hotkeysEnabled, !isRecordingShortcut else { return [] }
    let bindings = effectiveBindings.bindings
    // A pause the person took. Not the one Arbor takes at a logout, which any app can cancel: nobody said anything then.
    if isPaused, !pauseIsArborsOwn { return KeyBindings.whilePaused(bindings) }
    // The permission went during such a pause, or was doubted for a second. The pause is over (F63), and the keys stay given away until Arbor can
    // do something with them again.
    if permissionLoss?.duringAPause == true { return KeyBindings.whilePaused(bindings) }
    // While Arbor is not running it pauses for nobody, and the list is the person's word all the same.
    if isPassingThrough || (!isRunning && settings.pausesFor(frontmostApp?.bundleID)) {
      // The app's own. But for the keys of someone who misses a window: they are there to say why it stays away.
      guard accessibilityGranted else {
        return (permissionLoss?.windows ?? 0) > 0 ? KeyBindings.whileWindowsAreOutOfReach(bindings) : []
      }
      return bindings.filter { $0.command.worksInPassThroughApps || sendsAwayWhatIsSummoned($0.command) }
    }
    return bindings
  }

  /// Whether the command is the `summon` of the app whose window is summoned now, so that it would send it away. A key that
  /// brought an app has to be there to send it away again, also in an app that otherwise keeps its own ⌃⌥: a terminal is
  /// the first thing people summon, and the first they switch Arbor's shortcuts off in.
  private func sendsAwayWhatIsSummoned(_ command: Command) -> Bool {
    guard case .summon(let app) = command else { return false }
    return workspaces.values.contains { workspace in
      workspace.summoned.flatMap { windows[$0.window] }.map { Self.isWindow($0, of: app) } ?? false
    }
  }

  /// Called after every change of a layout: what is summoned may have changed, and with it what Arbor holds in
  /// an app that keeps its own ⌃⌥. Tells observers only if it did.
  func summonKeysMayHaveChanged() {
    let kept = isPassingThrough ? activeBindings.filter { sendsAwayWhatIsSummoned($0.command) }.map(\.chord) : []
    guard kept != summonKeysLastTold else { return }
    summonKeysLastTold = kept
    notify(.input)
  }

  public func applicationActivated(_ app: FrontmostApp?) {
    guard app != frontmostApp else { return }
    frontmostApp = app
    holdNotesActivation(of: app)
    followFrontmostApp(justActivated: true)
  }

  /// Brings the pause and what Arbor holds into line with the frontmost app and the two lists. Called when
  /// either may have changed; tells observers only if the answer did.
  func followFrontmostApp(justActivated: Bool = false) {
    // A pause brings every window into view. On a held view only the person may ask for that; this one waits
    // for `release`, which asks again (Controller+Hold.swift).
    let pauses = settings.pausesFor(frontmostApp?.bundleID) && holdLevel != .view
    // Before `start()` there is nothing to pause; `start()` asks again.
    defer { frontmostAppPaused = pauses && (isRunning || isPaused) }
    if pauses {
      // Only on the way in. Someone who resumed by hand inside the app meant it, and must not be
      // paused again by the next change of a setting.
      if isRunning, justActivated || !frontmostAppPaused {
        _ = pause(minutes: nil, forApp: true)
        Log.info("paused for \(frontmostAppName)")
      }
    } else if isPausedForApp {
      _ = resume()
    }
    guard isPassingThrough != wasPassingThrough else { return }
    wasPassingThrough = isPassingThrough
    // Told with this.
    summonKeysLastTold = isPassingThrough ? activeBindings.filter { sendsAwayWhatIsSummoned($0.command) }.map(\.chord) : []
    Log.info(
      "shortcuts and gestures are \(isPassingThrough ? "off" : "on again"): "
        + "\(frontmostApp?.bundleID ?? "an app without a bundle id") is frontmost")
    notify(.input)
  }

  /// A pause with an end has reached it. In an app Arbor pauses for, the pause goes on as that app's.
  func timedPauseEnded() {
    if settings.pausesFor(frontmostApp?.bundleID) {
      isPausedForApp = true
      pauseEnd = nil
      savePause()
    } else {
      _ = resume()
    }
  }

  /// `pass-through [bundle-id] [on|off]`. Without the last word: on the list if it was off, off if it was on.
  func passThrough(_ bundleID: String?, on: Bool?) -> CommandResult {
    guard let bundle = bundleID ?? frontmostApp?.bundleID else {
      return .failure(
        frontmostApp.map { "\($0.name) has no bundle id to list it by" } ?? "no bundle id given and no app in front")
    }
    if let refusal = refusalToChangeSettings() { return refusal }
    let app = appName(forBundleID: bundle)
    var updated = settings
    let wasListed = updated.passesThrough(bundle)
    let list = on ?? !wasListed
    guard list != wasListed else {
      return .success("shortcuts and gestures \(list ? "are already off" : "already work") in \(app)")
    }
    if list {
      updated.passThroughApps.append(bundle)
    } else {
      updated.passThroughApps.removeAll { Settings.list([$0], contains: bundle) }
    }
    let unsaved = change(settings: updated)
    guard list else { return reply("shortcuts and gestures work in \(app) again", unsaved: unsaved) }
    let kept = KeyBindings.whilePassingThrough(effectiveBindings.bindings).map(\.label)
    return reply(
      "shortcuts and gestures are off in \(app)" + (kept.isEmpty ? "" : ", except \(kept.joined(separator: " and "))"),
      unsaved: unsaved)
  }

  /// The menu's first line while the keys are the app's: walking onto a listed app with the keyboard switches the
  /// shortcuts off, and something has to say so.
  public var passThroughNotice: String? {
    isRunning && isPassingThrough ? "Shortcuts are off in “\(frontmostAppName)”" : nil
  }

  /// For replies that are only given while there is one.
  var frontmostAppName: String { frontmostApp?.name ?? "this app" }

  /// What people call the app, if Arbor has met it; otherwise its bundle id.
  func appName(forBundleID bundle: String) -> String {
    if let app = frontmostApp, Settings.list([bundle], contains: app.bundleID) { return app.name }
    return windows.values.sorted { $0.id < $1.id }.first { Settings.list([bundle], contains: $0.bundleID) }?.appName
      ?? bundle
  }

  /// Apps with a window open that are known to use ⌃⌥ themselves and are on neither list, by name:
  /// what to suggest `pass-through` for.
  public var passThroughSuggestions: [(bundleID: String, name: String)] {
    var found: [String: String] = [:]
    for window in windows.values.sorted(by: { $0.id < $1.id }) {
      guard let bundle = window.bundleID, ControlOptionApps.contains(bundle), found[bundle] == nil,
        !settings.passesThrough(bundle), !settings.pausesFor(bundle)
      else { continue }
      found[bundle] = window.appName
    }
    return found.map { (bundleID: $0.key, name: $0.value) }.sorted { ($0.name, $0.bundleID) < ($1.name, $1.bundleID) }
  }
}
