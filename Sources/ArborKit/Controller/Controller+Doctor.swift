import ArborCore
import CoreGraphics

/// The answer to `doctor`: everything that can keep Arbor from working as expected, checked.
public struct DoctorReport: Equatable, Sendable {
  public enum Mark: String, Sendable {
    case ok = "✔"
    case problem = "✘"
    /// Neither good nor bad: optional, switched off on purpose, or unknown.
    case note = "–"
  }

  public struct Check: Equatable, Sendable {
    public var mark: Mark
    public var title: String
    public var detail: String
    /// More lines, shown indented under the check.
    public var notes: [String]

    public init(mark: Mark, title: String, detail: String, notes: [String] = []) {
      self.mark = mark
      self.title = title
      self.detail = detail
      self.notes = notes
    }
  }

  public var checks: [Check] = []

  public var problems: Int { checks.filter { $0.mark == .problem }.count }

  public func check(_ title: String) -> Check? { checks.first { $0.title == title } }

  /// One line per check, with its notes indented below it. The worst first: whoever runs `doctor` has a problem, and should
  /// not have to look for it among what is in order.
  public var text: String {
    let order: [Mark] = [.problem, .note, .ok]
    return order.flatMap { mark in checks.filter { $0.mark == mark } }.flatMap { check in
      ["\(check.mark.rawValue) \(check.title): \(check.detail)"] + check.notes.map { "    \($0)" }
    }.joined(separator: "\n")
  }

  mutating func add(_ mark: Mark, _ title: String, _ detail: String, notes: [String] = []) {
    checks.append(Check(mark: mark, title: title, detail: detail, notes: notes))
  }
}

extension Controller {
  /// `doctor`. A query, so it works before `start()`, which is when it is needed most. It fails
  /// (and `arborctl doctor` exits with 1) when a check found a problem.
  func doctor() -> CommandResult {
    let report = doctorReport()
    let count = report.problems
    return CommandResult(
      ok: count == 0, message: count == 0 ? "no problems" : "\(count) problem(s)", text: report.text)
  }

  public func doctorReport() -> DoctorReport {
    let facts = systemFacts?()
    var report = DoctorReport()
    if isPaused, accessibilityGranted {
      report.add(.note, "Arbor", "paused: windows, shortcuts and gestures are left alone until `resume`")
    }
    checkPermissions(facts, into: &report)
    checkMacOS(facts, into: &report)
    checkEventTaps(facts, into: &report)
    checkShortcuts(facts, into: &report)
    checkKeyboard(facts, into: &report)
    checkSettings(into: &report)
    checkMenuBarItem(into: &report)

    let connected = isRunning ? displays : system.displays()
    if connected.isEmpty {
      report.add(.problem, "Displays", "none")
    } else {
      let sizes = connected.map { "\(Int($0.frame.width))×\(Int($0.frame.height))" + ($0.isMain ? " main" : "") }
      report.add(.ok, "Displays", "\(connected.count) (\(sizes.joined(separator: ", ")))")
    }
    report.add(.note, "Version", buildInfo.text)
    checkSignature(into: &report)
    return report
  }

  /// What the next build or update will cost. Never a problem: this build works as well as any. Nothing where nobody stamped it.
  private func checkSignature(into report: inout DoctorReport) {
    let title = "Signature"
    switch buildInfo.signature {
    case .adHoc?:
      report.add(
        .note, title,
        "ad hoc, so to macOS every build is a new app: after each `make install` or update it asks for the Accessibility "
          + "permission again. `scripts/make-signing-identity.sh`, run once in a clone, ends that for builds made there "
          + "(docs/INSTALL.md)")
    case .local?: report.add(.ok, title, "this Mac’s own certificate: permissions carry over to the next build signed with it")
    case .issued?: report.add(.ok, title, "a certificate: permissions carry over from build to build")
    case nil: break
    }
  }

  private static let unknown = "unknown here"

  private func checkPermissions(_ facts: SystemFacts?, into report: inout DoctorReport) {
    if facts?.accessibility ?? accessibilityGranted {
      report.add(.ok, "Accessibility", "granted")
    } else {
      report.add(
        .problem, "Accessibility",
        "not granted, so Arbor cannot move windows (System Settings → Privacy & Security → Accessibility; "
          + "the `check-setup` command opens a window that explains it)")
    }
    guard offersScreenRecording else { return }
    switch facts?.screenRecording {
    case true?: report.add(.ok, "Screen Recording", "granted")
    case false?:
      report.add(
        .note, "Screen Recording", "not granted (optional: moving windows show their app’s color, not their contents)")
    case nil: report.add(.note, "Screen Recording", Self.unknown)
    }
  }

  /// System settings and other apps that get in the way (docs/KEYBOARD.md, "Conflicts").
  private func checkMacOS(_ facts: SystemFacts?, into report: inout DoctorReport) {
    let titles = (
      switches: "Desktop & Dock settings", spaces: "Displays have separate Spaces", apps: "Other window managers",
      voiceOver: "VoiceOver", sources: "Input sources"
    )
    guard let facts else {
      for title in [titles.switches, titles.spaces, titles.apps, titles.voiceOver, titles.sources] {
        report.add(.note, title, Self.unknown)
      }
      return
    }

    if let switches = facts.switches {
      let lent = macSwitchesLent
      let inTheWay = macSwitchesInTheWay(facts) ?? switches
      // Nothing to put right, only something to know (Q24), the more so while Arbor keeps those clicks from macOS itself (F60).
      let guardNote =
        !switches.contains(.clickWallpaper)
        ? []
        : guardsDesktopClicks
          ? [
            "“\(MacSwitch.clickWallpaper.label)” is on; Arbor keeps clicks on the Desktop from sweeping windows away "
              + "(guardDesktopClicks). “Only in Stage Manager” is surer still"
          ]
          : [
            "“\(MacSwitch.clickWallpaper.label)” is on: a click on the wallpaper sweeps the windows aside, and the next one brings "
              + "them back where they were. “Only in Stage Manager” switches that off"
          ]
      // What Arbor does for somebody is said for as long as it does it.
      // One that somebody has switched on again by hand is theirs.
      let changed = macSwitchesChangedByArbor.filter { !inTheWay.contains($0) }.count
      let undoNote =
        changed == 0
        ? []
        : [
          lent.isEmpty
            ? "Arbor keeps \(changed) of them off while it runs, and gives \(changed == 1 ? "it" : "them") back at a quit and at a pause; "
              + "`fix-setup undo` ends that"
            : "macOS has \(lent.count) of them back until Arbor arranges windows again; `fix-setup undo` leaves \(lent.count == 1 ? "it" : "them") on"
        ]
      if inTheWay.isEmpty {
        report.add(.ok, titles.switches, "none in the way", notes: guardNote + undoNote)
      } else {
        let oneStep =
          macSwitchboard != nil && inTheWay.contains(where: \.canBeSwitchedOffForYou)
          ? "`fix-setup` keeps them off for you while Arbor runs (and `fix-setup undo` ends that), or do it in" : "In"
        report.add(
          .problem, titles.switches,
          "as they stand, macOS reacts to the same clicks and drags as Arbor. \(oneStep) System Settings → Desktop & Dock:",
          notes: inTheWay.map(\.advice) + guardNote + undoNote)
      }
    } else {
      report.add(.note, titles.switches, Self.unknown)
    }

    switch facts.separateSpaces {
    case true?: report.add(.ok, titles.spaces, "yes")
    case false?: report.add(.note, titles.spaces, "no, so the menu bar, and Arbor’s item in it, is on the main display only")
    case nil: report.add(.note, titles.spaces, Self.unknown)
    }

    if facts.competingApps.isEmpty {
      report.add(.ok, titles.apps, "none running")
    } else {
      let several = facts.competingApps.count > 1
      report.add(
        .problem, titles.apps,
        "\(OnboardingModel.sentenceList(facts.competingApps)) running: the same ⌃⌥ shortcuts, or arranging windows as well, "
          + "so both react or one silently wins. Quit \(several ? "them" : "it") or switch \(several ? "their" : "its") shortcuts off")
    }

    let shortcutsAreOn = settings.hotkeysEnabled && !facts.inputDisabled
    if !facts.voiceOver {
      report.add(.ok, titles.voiceOver, "off")
    } else if shortcutsAreOn {
      report.add(
        .problem, titles.voiceOver,
        "on, and ⌃⌥ is its modifier, so Arbor’s shortcuts are VoiceOver commands too. Make Caps Lock the VoiceOver "
          + "modifier (VoiceOver Utility → General) or set hotkeysEnabled to false")
    } else {
      report.add(.note, titles.voiceOver, "on; Arbor’s shortcuts are off, so nothing collides")
    }

    // Who wins has not been tried on a Mac, and the macOS shortcut can be switched off, so this is only a note.
    let space = KeyChord(.hyperless, .space)
    if let count = facts.inputSources {
      if count > 1, shortcutsAreOn, let taken = bindingsInEffect.first(where: { $0.chord == space }) {
        report.add(
          .note, titles.sources,
          "\(count), so macOS may keep \(space.label) (`\(taken.command.text)`) for “Select next source in Input menu” "
            + "(System Settings → Keyboard → Keyboard Shortcuts → Input Sources)"
            + (shortcut(for: .home).map { "; \($0.label) shows everything too" } ?? ""))
      } else {
        report.add(.ok, titles.sources, "\(count)")
      }
    } else {
      report.add(.note, titles.sources, Self.unknown)
    }
  }

  /// Each gesture listens through an event tap. The ones the settings ask for must be installed; taps this
  /// does not know about are only listed.
  private func checkEventTaps(_ facts: SystemFacts?, into report: inout DoctorReport) {
    let title = "Gestures"
    guard let facts else { return report.add(.note, title, Self.unknown) }
    guard !facts.inputDisabled else { return report.add(.note, title, "off (ARBOR_NO_HOTKEYS)") }
    guard isRunning else {
      return report.add(.note, title, isPaused && accessibilityGranted ? "off while Arbor is paused" : "not listening yet")
    }
    // What the taps themselves go by, which is less than the settings say whenever Arbor keeps its hands off.
    let input = inputSettings
    var wanted: [String] = []
    if input.gesturesEnabled { wanted.append("pinch") }
    if GestureRouter.listensToScrolls(input) { wanted.append("scroll") }
    // The rectangle, ⇧-drag on the Desktop and the guard against the wallpaper click share a tap. Asked of the rule the tap
    // itself goes by, so that the two cannot come to differ.
    var presses = RectangleGesture()
    _ = presses.follow(input)
    if presses.isEnabled { wanted.append("rectangle") }
    let missing = wanted.filter { !facts.eventTaps.contains($0) }
    let installed = facts.eventTaps.isEmpty ? "none" : facts.eventTaps.joined(separator: ", ")
    if !missing.isEmpty {
      report.add(
        .problem, title,
        OnboardingModel.sentenceList(missing)
          + (missing.count > 1 ? " do nothing: their event taps are" : " does nothing: its event tap is")
          + " not installed (installed: \(installed))")
    } else if facts.eventTaps.isEmpty {
      report.add(.note, title, "none, as the settings ask")
    } else {
      report.add(.ok, title, installed)
    }
  }

  private func checkShortcuts(_ facts: SystemFacts?, into report: inout DoctorReport) {
    let title = "Shortcuts"
    guard settings.hotkeysEnabled else { return report.add(.note, title, "off (hotkeysEnabled is false)") }
    guard facts?.inputDisabled != true else { return report.add(.note, title, "off (ARBOR_NO_HOTKEYS)") }
    guard let registered = registeredBindings else {
      let wanted = effectiveBindings.bindings
      return report.add(.note, title, "\(wanted.count) in the settings, not registered yet")
    }
    // What the app holds against what Arbor wants to hold now, not against what the settings describe: it wants fewer
    // shortcuts, or other keys, during a pause, in an app that keeps its own ⌃⌥ and on another keyboard layout.
    let held = keysHeld
    let refused = held.all(.refused)
    let missing = held.all(.missing)
    if !missing.isEmpty {
      // Not one by one: if this ever happens it is likely to be all of them.
      report.add(
        .problem, title,
        "\(registered.count) registered; \(missing.count) that Arbor wants "
          + "\(missing.count == 1 ? "is" : "are") not, and \(missing.count == 1 ? "reaches" : "reach") the app in front",
        notes: (refused.isEmpty ? [] : ["macOS refused \(refused.map(\.label).joined(separator: " "))"])
          + ["Quit Arbor and open it again; its log says what macOS answered"])
    } else if refused.isEmpty, isRunning, isPassingThrough {
      // Not a tick: whoever asks because the keys do nothing should read why. A terminal is a likely app to have them off in.
      report.add(
        .note, title,
        "all but \(registered.count) off in \(frontmostAppName), the app in front (`pass-through off` brings them back)")
    } else if refused.isEmpty, !isPaused, let why = whyKeysAreTheApps(appInFront: frontmostAppName) {
      // Not a tick either: Arbor is there and most of its keys are not.
      report.add(.note, title, "\(registered.count) registered; the others are the apps’ \(why)")
    } else if refused.isEmpty {
      // What the tick is worth is said under it: whoever asks because a key did something else somewhere should not be sent away by it.
      report.add(
        .ok, title, "\(registered.count) registered" + (isPaused ? " while Arbor is paused" : ""),
        notes: registered.isEmpty ? [] : [Self.whatRegisteredIsWorth])
    } else {
      report.add(
        .problem, title,
        "\(registered.count) registered; macOS refused \(refused.map(\.label).joined(separator: " ")), "
          + "which Arbor so does not hear",
        notes: ["Give the command\(refused.count == 1 ? "" : "s") another shortcut (Settings → Shortcuts, or `bind`)"])
    }
  }

  /// Seen on macOS 26: it says yes to Arbor whoever else holds the key (`KeysHeld`).
  static let whatRegisteredIsWorth =
    "macOS does not tell Arbor when another program has registered the same key: then both get it, or the other alone"

  /// The keyboard layout the shortcuts are made for (F44), and the apps that want ⌃⌥ for themselves (F41).
  private func checkKeyboard(_ facts: SystemFacts?, into report: inout DoctorReport) {
    guard settings.hotkeysEnabled, facts?.inputDisabled != true else { return }
    let layout = layoutInEffect
    // Signs this keyboard cannot type alone stay where a US keyboard has them, under whatever is printed there.
    let moved = effectiveBindings.bindings.filter { !$0.chord.isPositional && layout.fallsBack($0.chord.key) }
    report.add(
      .ok, "Keyboard layout",
      layout.name
        + (moved.isEmpty
          ? ""
          : "; it does not type \(OnboardingModel.sentenceList(moved.map { $0.chord.key.label })) alone, so "
            + moved.map { "`\($0.command.text)` is \($0.label)" }.joined(separator: ", ")))

    let apps = passThroughSuggestions.map(\.name)
    if !apps.isEmpty {
      report.add(
        .note, "Apps with their own ⌃⌥",
        "\(OnboardingModel.sentenceList(apps)) use\(apps.count == 1 ? "s" : "") ⌃⌥ too, and Arbor’s shortcuts come first. To give "
          + "the keys back there, bring the app to the front and choose Shortcuts Off in “App” in Arbor’s menu "
          + "(or `pass-through`)")
    }
  }

  /// What is wrong on this Mac goes into the log once, at launch: most people never run `doctor`, and whoever reads their log
  /// later should see what Arbor saw.
  public func logSetupProblems() {
    for line in setupProblemLines { Log.error(line) }
  }

  /// The entries of `bindings` that were skipped go there too, whenever they change (`KeyBindings.problemsForTheLog`).
  public func logSkippedBindings() {
    for problem in KeyBindings.problemsForTheLog(effectiveBindings.problems, settings: settings, layout: layoutInEffect) {
      Log.error("settings.json bindings: skipped \(problem)")
    }
  }

  /// One line per problem, with its notes. Names of apps and of settings, never a window's title.
  ///
  /// `doctor` answers whoever asks, on their own screen, and may quote their own file to them. The log is passed on. So of what is wrong in
  /// settings.json the log gets how much, not what: the notes quote the file (a shortcut's command that cannot be read is somebody's
  /// words), and so does the reason why the whole file cannot be read.
  public var setupProblemLines: [String] {
    doctorReport().checks.filter { $0.mark == .problem }.map { check in
      let notes = check.title == Self.settingsFileCheck ? ["`doctor` lists them"] : check.notes
      return forTheLog("setup: \(check.title): \(([check.detail] + notes).joined(separator: " | "))")
    }
  }

  private static let settingsFileCheck = "settings.json"

  /// Arbor has no window and no Dock icon: if macOS leaves its item out of a full menu bar, it has no face at all.
  private func checkMenuBarItem(into report: inout DoctorReport) {
    let title = "Menu bar item"
    let door = "Opening Arbor again shows the welcome window; `arborctl` and the shortcuts work as ever"
    switch (menuBarRoom.isShowing, menuBarRoom.tooWide) {
    case (nil, _):
      report.add(.note, title, Self.unknown)
    case (true?, nil):
      report.add(.ok, title, "showing")
    case (true?, let width?):
      report.add(
        .note, title,
        "showing as a single icon: macOS had no room for \(Int(width)) points of buttons (a notch takes some). Fewer saved "
          + "views, `historyButtons` false or fewer other menu bar items make room; `reload-settings` tries again")
    case (false?, _):
      // Said with less confidence while macOS has never been heard to say anything else on this Mac.
      report.add(
        menuBarRoom.hasBeenSeen ? .problem : .note, title,
        (menuBarRoom.hasBeenSeen ? "not showing: no room" : "not showing, as far as macOS says: no room")
          + " in the menu bar (a notch takes some). Quit other menu bar items to make some. \(door)")
    }
  }

  /// What Arbor could not use in settings.json. The same lines are in `rules` and `bindings`; the log says only where (`problemsForTheLog`).
  private func checkSettings(into report: inout DoctorReport) {
    if let problem = settingsFileProblem {
      return report.add(
        .problem, Self.settingsFileCheck,
        "cannot be read (\(problem)). Arbor goes on with the settings it had, and refuses to change any until the file is "
          + "mended; `reset everything` writes a new one and keeps this one")
    }
    // One way of reporting each kind: what `settings`, `rules`, `displays` and `bindings` say.
    let notes =
      settings.valueProblems + settings.skippedRules.map { "rules: \($0)" }
      + settings.skippedDisplays.map { "displays: \($0)" } + effectiveBindings.problems.map { "bindings: \($0)" }
    if notes.isEmpty {
      report.add(.ok, Self.settingsFileCheck, "no problems")
    } else {
      report.add(.problem, Self.settingsFileCheck, "\(notes.count) entries skipped", notes: notes)
    }
  }
}
