import ArborCore

/// Which shortcuts the app is to hold, what became of them, and who is told (`KeysHeld`, `HotKeyTable`).
///
/// The app, which alone can talk to macOS, does three things whenever it hears that the answer may have changed: it asks
/// `shortcutsToRegister()`, hands what it gets to `HotKeyCenter`, and reports with `shortcutsWereRegistered`. What
/// to try again, what is news and what goes into the log is decided here, where tests run it.
extension Controller {
  /// What Arbor wants to hold now: what the rule says (`activeBindings`), unless whoever started it wants none held.
  var shortcutsWanted: [KeyBinding] { shortcutsAreDisabled ? [] : activeBindings }

  /// Whose each shortcut of the map in effect is now.
  public var keysHeld: KeysHeld {
    KeysHeld(
      map: effectiveBindings.bindings, wanted: shortcutsWanted, registered: registeredBindings, refused: refusedBindings)
  }

  /// Why Arbor does not ask for all its shortcuts now, to follow "all but 1 off"; nil while it asks for all of them. It goes by what
  /// `shortcutsWanted` answers, and only looks for the words, in the order in which that decides.
  func whyKeysAreTheApps(appInFront: String) -> String? {
    guard shortcutsWanted.count < effectiveBindings.bindings.count else { return nil }
    if shortcutsAreDisabled { return "because ARBOR_NO_HOTKEYS is set" }
    if !settings.hotkeysEnabled { return "because hotkeysEnabled is false" }
    if isRecordingShortcut { return "while a shortcut is being recorded" }
    // Never for want of the permission: without it Arbor keeps its keys, takes the press and says why.
    if isPaused { return "while Arbor is paused" }
    if permissionLoss?.duringAPause == true { return "since the pause in which the Accessibility permission went" }
    if isPassingThrough || settings.pausesFor(frontmostApp?.bundleID) { return "in \(appInFront)" }
    // A reason this does not know of yet must not be laid at an app's door.
    return "for now"
  }

  /// For the log's line about what is registered: what there is to say beyond "all of them". Never an app's name.
  public var keysHeldForTheLog: String? { keysHeld.news(why: whyKeysAreTheApps(appInFront: "the app in front")) }

  /// The shortcuts the app is to hold from now on, or nil if there is nothing to do: it holds them already. So applying settings that
  /// leave the shortcuts as they were (`exclude`, say) asks macOS for nothing. What was wanted and is not held is tried
  /// again at every occasion; that costs the others nothing (`HotKeyChanges`).
  public func shortcutsToRegister() -> [KeyBinding]? {
    let bindings = shortcutsWanted
    let problems = effectiveBindings.problems
    let isNews = shortcutsLastAsked.map { $0.bindings != bindings || $0.problems != problems } ?? true
    guard isNews || registeredBindings != bindings || shortcutsLackATwin else { return nil }
    shortcutsLastAsked = (bindings, problems, isNews)
    if isNews {
      logSkippedBindings()
      logSystemShortcutClashes()
    }
    return bindings
  }

  /// How it went. `outcome` is nil if the app cannot listen for shortcuts at all, and so holds none.
  ///
  /// Every change of what Arbor holds for good gets a line in the log, also when that is nothing: a key of the map that Arbor
  /// does not hold is another app's. Trying again what failed is said only if it went otherwise this time. Returns what it logged.
  @discardableResult
  public func shortcutsWereRegistered(_ outcome: HotKeyOutcome?, microseconds: UInt64) -> [String] {
    var lines: [String] = []
    let before = registeredBindings
    refusedBindings = outcome?.refused.map(\.binding) ?? []
    registeredBindings = outcome?.held ?? []
    // A key without its twin is Arbor's all the same: for the log, and no problem in `doctor`. Sorted, so that the same in another order
    // is not news; counted if there are many, which is what a macOS that will have none of them would make of it.
    let twinless = (outcome?.withoutTwin ?? []).map { "no to fn \($0.text)" }.sorted()
    shortcutsLackATwin = !twinless.isEmpty
    let refusals =
      (outcome?.refused.map { "no to \($0.text)" } ?? []) + (outcome?.stuck.map { "would not take back \($0.text)" } ?? [])
      + (twinless.count > 3 ? ["no to \(twinless.count) shortcuts with fn, \(twinless[0].dropFirst(6)) among them"] : twinless)
    if refusals != shortcutRefusalsSaid, !refusals.isEmpty {
      lines.append("shortcuts: macOS said \(refusals.joined(separator: ", "))")
      Log.error(lines[0])
    }
    shortcutRefusalsSaid = refusals
    guard shortcutsLastAsked?.isNews != false || registeredBindings != before else { return lines }
    // Scripts read it as far as "shortcuts": how many Arbor holds from now on.
    lines.append(
      "registered \(registeredBindings?.count ?? 0) shortcuts in \(microseconds) µs" + (keysHeldForTheLog.map { ": " + $0 } ?? ""))
    Log.info(lines[lines.count - 1])
    return lines
  }
}

extension KeysHeld.Fate {
  /// What `bindings` puts at the end of the key's line.
  var mark: String? {
    switch self {
    case .held: nil
    case .handedOver: "the apps' now"
    case .refused: "macOS refused it: Arbor does not hear it"
    case .missing: "not registered: the app in front gets it"
    }
  }
}
