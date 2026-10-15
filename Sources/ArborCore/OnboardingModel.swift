/// The three moves a newcomer tries on the welcome window's second page, ticked off as they happen:
/// dock a window, frame it, show everything again. Each is recognised from the arrangement itself, so
/// it does not matter whether the keyboard, the pointer or the menu did it, nor in which order.
public struct FirstSteps: Equatable, Sendable {
  public private(set) var docked = false
  public private(set) var framed = false
  public private(set) var showedEverything = false
  /// The displays whose view has been somewhere else than on everything. Show Everything counts on those: showing
  /// everything from the start is no move.
  private var away: Set<DisplayID> = []

  public init() {}

  public var isComplete: Bool { docked && framed && showedEverything }

  /// Looks at the arrangement after a change. A tick stays.
  public mutating func observe(_ workspaces: [DisplayID: Workspace]) {
    if !docked { docked = workspaces.values.contains { !$0.tree.allWindows.isEmpty } }
    // The view is on a single docked window (or tab group).
    if !framed { framed = workspaces.values.contains { $0.tree.isStack($0.camera) } }
    guard !showedEverything else { return }
    // If such a display has gone, its windows are on another one, in view.
    showedEverything = away.contains { display in workspaces[display].map { $0.camera == $0.tree.root } ?? true }
    for (display, workspace) in workspaces where workspace.camera != workspace.tree.root { away.insert(display) }
  }
}

/// Which page the welcome window shows. It opens on the permissions, goes on to the first steps by
/// itself the moment Arbor may arrange windows, unless something else on the page is still in the way, and
/// comes back if the permission is taken away.
public struct OnboardingFlow: Equatable, Sendable {
  public enum Page: Sendable {
    case permissions, firstSteps
  }

  public private(set) var page = Page.permissions
  public var steps = FirstSteps()
  private var isReady: Bool
  /// The three moves have been on show. Whoever has passed the first page by is not held at it again.
  private var hasGoneOn = false

  /// - Parameter isReady: Arbor has Accessibility permission.
  public init(isReady: Bool) { self.isReady = isReady }

  /// - Parameter needsAttention: the first page has advice that has not been taken (`OnboardingModel.needsAttention`). Asked only
  ///   at the moment the permission arrives.
  public mutating func update(isReady: Bool, needsAttention: @autoclosure () -> Bool) {
    if !isReady {
      page = .permissions
    } else if !self.isReady, hasGoneOn || !needsAttention() {
      // What the window was waiting for. Closing now would leave a newcomer looking at an unchanged screen.
      // Not past what is in the way: whoever comes back from granting the permission has read nothing else on the page, and the offer to
      // have the screen edges, which macOS as it comes keeps for itself, is made there.
      page = .firstSteps
      hasGoneOn = true
    }
    self.isReady = isReady
  }

  /// The Continue and Back buttons. There is nothing to try before Arbor may move windows.
  public mutating func go(to page: Page) {
    self.page = isReady ? page : .permissions
    if self.page == .firstSteps { hasGoneOn = true }
  }
}

/// What the welcome window says (docs/features/F10-menu-bar-and-onboarding.md). The first page: what Arbor
/// is, and one row per permission, macOS setting or other app that matters, with whether it is in
/// order. The second: three moves to try, ticked off live, and the ways back to a normal Mac.
/// Built from `SystemFacts`, so that the wording and the logic are tested without a Mac. The words are
/// those of docs/GLOSSARY.md.
public struct OnboardingModel: Equatable, Sendable {
  public struct Row: Equatable, Sendable, Identifiable {
    public enum ID: String, Sendable, CaseIterable {
      case accessibility, screenRecording, desktopAndDock, competingApps, voiceOver, inputSources, ownShortcuts
    }

    public enum State: Sendable {
      /// In order.
      case done
      /// Arbor cannot work until this is dealt with.
      case required
      /// Arbor works, but something will get in its way.
      case recommended
      /// Arbor works; this only makes it nicer.
      case optional
      /// Nothing to do, only something to know.
      case note
    }

    public var id: ID
    public var title: String
    /// How much it matters, next to the title: "Required", "Optional", "Best changed". Once the row is in order, the state instead:
    /// "Best changed" beside a tick reads as if there were still something to change.
    public var importance: String
    public var state: State
    /// The state in a word or two, for VoiceOver: "Granted", "Not granted", "In order".
    public var status: String
    /// Why it matters and what to do. Empty once the row is in order: a tick says enough.
    public var detail: String
    /// What is on, one line each, listed under the detail.
    public var points: [String] = []
    /// The title of the button that opens the right pane of System Settings, if one helps.
    public var button: String?
    /// A button that has Arbor do something itself: the one step.
    public var action: Action?
    /// Said under the points: what the action changes, and how to undo it.
    public var afterword: String = ""
    /// What Arbor has done to this Mac for its owner, said for as long as it can be undone, and the button that undoes it.
    public var done: String = ""
    public var undo: Action?
    /// Why the button that was just pressed did nothing. A button that seems dead gets pressed again.
    public var failure: String = ""

    public struct Action: Equatable, Sendable {
      public var title: String
      public var command: Command

      public init(_ title: String, _ command: Command) {
        self.title = title
        self.command = command
      }
    }

    public var isSatisfied: Bool { state == .done }
    /// Something is missing or in the way, and there is something to do about it.
    public var needsAttention: Bool { state == .required || state == .recommended }
  }

  /// One of the moves to try: what to do, and what happens.
  public struct Step: Equatable, Sendable, Identifiable {
    public enum ID: String, Sendable, CaseIterable {
      case dock, frame, showEverything
    }

    public var id: ID
    public var lead: String
    public var text: String
    public var isDone: Bool
  }

  public var page: OnboardingFlow.Page
  public var title: String
  public var summary: String
  /// The first page.
  public var rows: [Row]
  /// The second page.
  public var steps: [Step]
  /// What the signs on the keys are called, over the moves: the key to the signs before the signs. Empty when the page shows none.
  public var keysLegend: String
  public var waysBackTitle: String
  /// Always these three, in this order.
  public var waysBack: [String]
  /// Whether Arbor opens at login, for the tick box on the second page. Nil leaves the box out.
  public var opensAtLogin: Bool?
  public var loginTitle: String
  public var footnote: String
  /// The footnote speaks of Arbor's mark in the menu bar, so the window shows it beside the text.
  public var footnoteShowsMark: Bool
  /// The button that goes on: Continue, then Done.
  public var primaryButton: String
  public var isPrimaryEnabled: Bool
  /// The button that goes back to the first page, on the second.
  public var backButton: String?

  /// Arbor has what it needs to arrange windows.
  public var isReady: Bool { rows.allSatisfy { $0.state != .required } }

  /// Something is missing or in the way: a reason to show the first page before the three moves.
  public var needsAttention: Bool { rows.contains(where: \.needsAttention) }

  /// The page to show somebody who has seen neither.
  public var pageToOpenOn: OnboardingFlow.Page { needsAttention ? .permissions : .firstSteps }

  /// Whether this is good news that somebody is waiting for in another window: the permission has arrived, or the last thing in the
  /// way has gone. They are in System Settings then, which covers this window, and Arbor has no other face: it comes forward.
  public func isWorthComingForward(after old: OnboardingModel) -> Bool {
    (isReady && !old.isReady) || (!needsAttention && old.needsAttention)
  }

  public func row(_ id: Row.ID) -> Row? { rows.first { $0.id == id } }
  public func step(_ id: Step.ID) -> Step? { steps.first { $0.id == id } }

  /// - Parameters:
  ///   - windowsOutOfView: how many windows were out of view when the permission was taken away while Arbor ran, and
  ///     still are (F63 counts them).
  ///   - offersScreenRecording: whether the optional permission has a row. Only where Arbor makes good use of it.
  ///   - appsWithOwnShortcuts: the names of open apps known to use ⌃⌥ themselves, for which nothing has been decided (F41).
  ///   - canFixSetup: Arbor can switch macOS's own settings off for whoever asks (`fix-setup`).
  ///   - switchesChangedByArbor: the ones it has switched off and not put back.
  ///   - fixSetupFailure: what `fix-setup` answered when it last failed in this showing of the window.
  ///   - isNewcomer: Arbor has never run on this Mac and nothing is docked.
  ///   - isPaused: the user has paused Arbor, so none of the moves would do anything.
  ///   - shortcut: the label of the shortcut that runs a command, e.g. ⌃⌥Space. A move without one is
  ///     explained by the menu instead, and with no shortcuts at all the rows about what collides
  ///     with them are left out.
  public init(
    _ facts: SystemFacts, flow: OnboardingFlow? = nil, windowsOutOfView: Int = 0, offersScreenRecording: Bool = false,
    appsWithOwnShortcuts: [String] = [], canFixSetup: Bool = false, switchesChangedByArbor: [MacSwitch] = [],
    fixSetupFailure: String? = nil, isNewcomer: Bool = false, isPaused: Bool = false,
    shortcut: (Command) -> String? = { _ in nil }
  ) {
    let flow = flow ?? OnboardingFlow(isReady: facts.accessibility)
    page = flow.page
    rows = Self.rows(
      facts, windowsOutOfView: windowsOutOfView, offersScreenRecording: offersScreenRecording,
      appsWithOwnShortcuts: appsWithOwnShortcuts, canFixSetup: canFixSetup, changed: switchesChangedByArbor,
      failure: fixSetupFailure, canDock: facts.accessibility && !isPaused, isNewcomer: isNewcomer, shortcut: shortcut)
    steps = Self.steps(
      flow.steps, macOSTakesTheEdges: facts.switches?.contains(.screenEdges) == true, shortcut: shortcut)
    opensAtLogin = facts.opensAtLogin
    loginTitle = "Open at Login"

    func named(_ title: String, _ command: Command) -> String { shortcut(command).map { "\(title) (\($0))" } ?? title }
    waysBackTitle = "Three ways back"
    waysBack = [
      named("Show Everything", .showAll),
      named("Float All Windows", .floatAll) + " puts your Mac back to normal",
      "Quitting Arbor brings every window back into view",
    ]
    keysLegend = Self.legend(for: steps.flatMap { [$0.lead, $0.text] } + waysBack)

    switch page {
    case .permissions:
      title =
        !facts.accessibility
        ? (windowsOutOfView > 0 ? "Arbor needs its permission back" : "Welcome to Arbor")
        : isPaused ? "Arbor is paused" : Self.title(inTheWay: rows.filter(\.needsAttention).count)
      // What it is, in words that need no glossary ("dock" is taken for the Dock, "zoom" for bigger text), teaching the one word the menu uses.
      // And the promise somebody wants who is about to let an app move their windows. Only where it holds: a later start brings
      // back what was docked, and a permission that returns brings back what was out of view.
      summary =
        "Put windows side by side (“dock” them), make any one fill the screen, then return to the side-by-side view."
        + (isNewcomer ? " Nothing moves until you dock a window." : "")
      primaryButton = "Continue"
      isPrimaryEnabled = facts.accessibility
      backButton = nil
      footnote =
        facts.accessibility
        ? Self.whereArborLives : ""
      footnoteShowsMark = facts.accessibility
    case .firstSteps:
      title = flow.steps.isComplete ? "That is all there is to it" : "Three moves to try"
      summary =
        isPaused
        ? "Arbor is paused and leaves windows and shortcuts alone. Choose Resume in its menu first."
        : flow.steps.isComplete
          ? "Dock more windows, onto each other’s edges too, and zoom between them."
          : "On your own windows, one after the other. Each is ticked off here as you do it."
      primaryButton = "Done"
      isPrimaryEnabled = true
      backButton = "Back"
      footnote = Self.whereArborLives
      footnoteShowsMark = true
    }
  }

  /// ⌃⌥⌘← as Control-Option-Command-←.
  static func spelledOut(_ label: String) -> String {
    var parts: [String] = []
    var rest = Substring(label)
    while let sign = rest.first, let name = signs.first(where: { $0.0 == sign })?.1 {
      parts.append(name)
      rest = rest.dropFirst()
    }
    return (parts + (rest.isEmpty ? [] : [String(rest)])).joined(separator: "-")
  }

  private static let signs: [(Character, String)] = [("⌃", "Control"), ("⌥", "Option"), ("⇧", "Shift"), ("⌘", "Command"), ("↩", "Return")]

  /// What the signs in `texts` are called: "⌃ is Control, ⌥ Option, ↩ Return." Only those that are there, and nothing without any.
  static func legend(for texts: [String]) -> String {
    let shown = signs.filter { sign, _ in texts.contains { $0.contains(sign) } }
    guard let first = shown.first else { return "" }
    return (["\(first.0) is \(first.1)"] + shown.dropFirst().map { "\($0.0) \($0.1)" }).joined(separator: ", ") + "."
  }

  /// True of a newcomer and of whoever chooses Check Setup… after a year. Not "Arbor is ready" over a warning sign, and nothing that alarms
  /// beside a Continue that can be pressed: with the permission there Arbor works, by the keys if need be.
  private static func title(inTheWay count: Int) -> String {
    switch count {
    case 0: "Arbor is ready"
    case 1: "Ready, with one suggestion"
    default: "Ready, with \(["two", "three", "four", "five"][min(count, 5) - 2]) suggestions"
    }
  }

  /// Said from the start, not after the last tick: a right click is nothing anybody would guess.
  private static let whereArborLives =
    "Arbor lives in the menu bar, under this icon. Right-click it for all commands, including Quit Arbor. Can’t see the icon? Open Arbor "
    + "again and this window returns."

  // MARK: The first page

  private static func rows(
    _ facts: SystemFacts, windowsOutOfView: Int, offersScreenRecording: Bool, appsWithOwnShortcuts apps: [String],
    canFixSetup: Bool, changed: [MacSwitch], failure: String?, canDock: Bool, isNewcomer: Bool, shortcut: (Command) -> String?
  ) -> [Row] {
    let settings = "Open Settings…"
    let stranded =
      windowsOutOfView == 0
      ? ""
      : (windowsOutOfView == 1 ? "1 window is" : "\(windowsOutOfView) windows are")
        + " out of view, not closed. Grant the permission again to get \(windowsOutOfView == 1 ? "it" : "them") back. "
    var rows = [
      Row(
        id: .accessibility, title: "Accessibility", importance: "Required",
        state: facts.accessibility ? .done : .required, status: facts.accessibility ? "Granted" : "Not granted",
        detail: facts.accessibility
          ? ""
          : stranded + "macOS asks your permission before an app may move other apps’ windows. Arbor reads only each window’s position "
            + "and title, and nothing leaves your Mac. Flip the switch next to Arbor in System Settings. This window comes back by itself."
            // Not to somebody who has never run Arbor: it cannot be in the list.
            + (isNewcomer ? "" : " If Arbor is already switched on in the list, this is a new build: switch it off and on again."),
        button: settings),
    ]
    if offersScreenRecording {
      rows.append(
        Row(
          id: .screenRecording, title: "Screen Recording", importance: "Optional",
          state: facts.screenRecording ? .done : .optional, status: facts.screenRecording ? "Granted" : "Not granted",
          detail: facts.screenRecording
            ? ""
            : "With it, windows show their contents while they move. Without it they show their app’s color and "
              + "icon. Nothing is recorded or stored. macOS restarts Arbor to apply it.",
          button: settings))
    }
    if let all = facts.switches?.filter(\.isInArborsWay) {
      // What a newcomer is about to run into comes first: the first thing they will try is a drag.
      let order: [MacSwitch] = [.screenEdges, .menuBar, .optionKey, .stageManager]
      let switches = order.filter(all.contains) + all.filter { !order.contains($0) }
      let mine = switches.filter(\.canBeSwitchedOffForYou).count
      // While macOS's switch for an edge is on, that whole edge is macOS's (collab/QUESTIONS.md, Q23).
      let takesEdges = switches.contains(.screenEdges) || switches.contains(.menuBar)
      let offers = canFixSetup && mine > 0
      var sentences: [String] = []
      if mine > 0 {
        // What it is, what it does to a person, and what they get and lose either way: nobody changes a setting of their Mac's for an app
        // they have had for half a minute without knowing what for. That it can be undone makes it a small thing to ask.
        sentences = [
          "Your Mac has window tiling of its own: drag a window \(takesEdges ? "to a screen edge" : "with Option held"), and macOS reacts before "
            + "Arbor can."
        ]
        if switches.contains(.screenEdges) {
          sentences.append(
            "Switch it off, and you dock with the mouse. Leave it on, and you dock with the keyboard"
              // Spelled out: the key to the signs is on the next page.
              + (shortcut(.dock(nil, .left)).map { " (\(spelledOut($0)))" } ?? "") + ".")
        }
        if offers { sentences.append("You can put it back at any time.") }
      }
      if switches.contains(.stageManager) { sentences.append("Stage Manager moves windows itself: use one or the other.") }
      let names = switches.filter(\.canBeSwitchedOffForYou).map(\.named)
      var row = Row(
        id: .desktopAndDock, title: mine > 0 || switches.isEmpty ? "macOS tiling" : "Stage Manager", importance: "Recommended",
        state: switches.isEmpty ? .done : .recommended, status: switches.isEmpty ? "Off" : "On",
        detail: sentences.joined(separator: " "),
        // By their names in System Settings, for whoever goes there. With the offer they are the small print under the button.
        points: offers ? [] : names, button: offers ? "Or do it yourself in Desktop & Dock…" : "Open Desktop & Dock…")
      if offers {
        // One step instead of a search for three switches. What it touches and the way back are said before it is taken.
        row.action = Row.Action("Switch Off macOS Tiling", .fixSetup(undo: false))
        row.afterword =
          "Changes \(mine) setting\(mine == 1 ? "" : "s") in Desktop & Dock, nothing else: \(names.joined(separator: ", ")). A "
          + "\(mine == 1 ? "Put It Back" : "Put Them Back") button appears here afterwards."
      }
      if canFixSetup, !changed.isEmpty {
        // A tick says enough, except of what Arbor did to somebody's Mac. Whatever else the row has to say: the way back was promised here.
        let one = changed.count == 1
        row.done =
          "Arbor switched off \(changed.count) setting\(one ? "" : "s") of macOS for you. \(one ? "It stays" : "They stay") off, even after you quit "
          + "Arbor, until you put \(one ? "it" : "them") back: here, or later under Help → Check Setup… in Arbor’s menu."
          // What it was for, where that has come true: every edge is Arbor's, and Arbor may and does move windows.
          + (changed.contains(.screenEdges) && !takesEdges && canDock ? " A window dragged to a screen edge docks now." : "")
        row.undo = Row.Action(one ? "Put It Back" : "Put Them Back", .fixSetup(undo: true))
      }
      if let failure { row.failure = "That did not work: \(failure)." }
      rows.append(row)
    }
    if !facts.competingApps.isEmpty {
      let several = facts.competingApps.count > 1
      rows.append(
        Row(
          id: .competingApps, title: "\(sentenceList(facts.competingApps)) \(several ? "are" : "is") running",
          importance: "Best quit", state: .recommended, status: "Running",
          detail: "\(several ? "They use" : "It uses") the same ⌃⌥ shortcuts or \(several ? "arrange" : "arranges") windows as well, so both "
            + "react or one silently wins. Quit \(several ? "them" : "it"), or switch "
            + "\(several ? "their" : "its") shortcuts off.",
          button: nil))
    }
    let everything = shortcut(.showAll)
    if facts.voiceOver, everything != nil || shortcut(.zoom(nil)) != nil {
      rows.append(
        Row(
          id: .voiceOver, title: "VoiceOver is on", importance: "Shortcuts collide", state: .recommended, status: "On",
          detail: "⌃⌥ is the VoiceOver modifier, so Arbor’s shortcuts are VoiceOver commands too. Make Caps Lock "
            + "the VoiceOver modifier (VoiceOver Utility → General), or set hotkeysEnabled to false in Arbor’s settings.",
          button: nil))
    }
    if let count = facts.inputSources, count > 1, everything == "⌃⌥Space" {
      let alternative = shortcut(.home).map { " \($0) does the same." } ?? ""
      rows.append(
        Row(
          id: .inputSources, title: "\(count) input sources", importance: "Good to know", state: .note,
          status: "May collide",
          detail: "macOS can switch input sources with ⌃⌥Space. If Show Everything does not answer to it, switch off "
            + "“Select next source in Input menu” under Keyboard → Keyboard Shortcuts → Input Sources.\(alternative)",
          button: settings))
    }
    if !apps.isEmpty, everything != nil || shortcut(.zoom(nil)) != nil {
      let several = apps.count > 1
      rows.append(
        Row(
          id: .ownShortcuts, title: "\(sentenceList(apps)) use\(several ? "" : "s") ⌃⌥ too", importance: "Good to know",
          state: .note, status: "Shares its keys",
          detail: "Arbor’s shortcuts come first, in every app. To give the keys back in \(several ? "one of them" : "it"), "
            + "bring it to the front and choose Shortcuts Off in “App” in Arbor’s menu.",
          button: nil))
    }
    return rows.map { row in
      var row = row
      // Nor is there anything to go to System Settings for.
      if row.isSatisfied {
        row.importance = row.status
        row.button = nil
      }
      return row
    }
  }

  // MARK: As text

  /// The window written out, top to bottom as it is laid out, buttons in square brackets: for arbor-sim, for tests that pin the whole of
  /// it, and for whoever wants to read the words without a Mac.
  public var text: String {
    var lines = [title, summary, ""]
    switch page {
    case .permissions:
      for row in rows {
        let mark =
          switch row.state {
          case .done: "✔"
          case .required: "→"
          case .recommended: "*"
          case .optional: "○"
          case .note: "i"
          }
        // Beside the title: the button of a row that has no step to offer, as `OnboardingView` places them.
        let beside = row.action != nil ? nil : row.isSatisfied ? row.undo?.title ?? row.button : row.button
        lines.append("\(mark) \(row.title) (\(row.importance))" + (beside.map { "  [\($0)]" } ?? ""))
        if !row.detail.isEmpty { lines.append("    \(row.detail)") }
        lines += row.points.map { "    • \($0)" }
        if let action = row.action { lines.append("    [\(action.title)]" + (row.button.map { " [\($0)]" } ?? "")) }
        if !row.afterword.isEmpty { lines.append("    \(row.afterword)") }
        if !row.failure.isEmpty { lines.append("    \(row.failure)") }
        if !row.done.isEmpty {
          lines.append("    \(row.done)" + (row.isSatisfied ? "" : row.undo.map { " [\($0.title)]" } ?? ""))
        }
      }
    case .firstSteps:
      if !keysLegend.isEmpty { lines.append(keysLegend) }
      for step in steps {
        lines.append("\(step.isDone ? "✔" : "○") \(step.lead)")
        lines.append("    \(step.text)")
      }
      lines += ["", waysBackTitle] + waysBack.map { "• \($0)" }
      if let opensAtLogin { lines += ["", "[\(opensAtLogin ? "x" : " ")] \(loginTitle)"] }
    }
    lines.append("")
    if !footnote.isEmpty { lines.append(footnote) }
    lines.append((backButton.map { "[\($0)] " } ?? "") + (isPrimaryEnabled ? "[\(primaryButton)]" : "(\(primaryButton))"))
    return lines.joined(separator: "\n")
  }

  /// "Rectangle", "Rectangle and Magnet", "Rectangle, Magnet and Amethyst".
  public static func sentenceList(_ words: [String]) -> String {
    guard let last = words.last, words.count > 1 else { return words.first ?? "" }
    return words.dropLast().joined(separator: ", ") + " and " + last
  }

  // MARK: The second page

  /// - Parameter macOSTakesTheEdges: macOS's own tiling is on. A hand that drags to a screen edge ends at the very edge, which is where
  ///   macOS takes the window: a first move that cannot work is no welcome, so the keys come first.
  private static func steps(
    _ done: FirstSteps, macOSTakesTheEdges: Bool, shortcut: (Command) -> String?
  ) -> [Step] {
    func lead(_ command: Command, menu item: String) -> String {
      shortcut(command).map { "Press \($0)" } ?? "Choose \(item) in Arbor’s menu"
    }
    let dock =
      macOSTakesTheEdges
      ? Step(
        id: .dock,
        lead: shortcut(.dock(nil, .left)).map { "Click a window and press \($0)" }
          ?? "Click a window and choose Dock Focused Window → Left in Arbor’s menu",
        text: "It docks: it takes the left half of the screen and stays there. Prefer the mouse? Click Back and switch off macOS tiling; "
          + "then you just drag a window to the edge.",
        isDone: done.docked)
      : Step(
        id: .dock, lead: "Drag a window to the left edge of the screen",
        text: "A preview shows where it will land. Let go, and it docks: it takes that half of the screen and stays there.",
        isDone: done.docked)
    // One breath: the dock alone looks like little, and the two moves after it are where Arbor pays.
    func then(_ lead: String) -> String { "Then " + lead.prefix(1).lowercased() + lead.dropFirst() }
    return [
      dock,
      Step(
        id: .frame, lead: then(lead(.zoom(nil), menu: "Frame Focused Window")),
        text: "The docked window fills the screen (it is “framed”). Your other windows are out of view, not closed: ⌘Tab and the Dock "
          + "still reach them.",
        isDone: done.framed),
      Step(
        id: .showEverything, lead: then(lead(.showAll, menu: "Show Everything")),
        // What it is all for, which one docked window does not show.
        text: "Every window is back in view. "
          + (macOSTakesTheEdges
            ? (shortcut(.dock(nil, .right)).map { "Click another and press \($0)" } ?? "Dock another at the right")
            : "Drag another to the right edge") + ", and the two share the screen.",
        isDone: done.showedEverything),
    ]
  }
}
