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
      // Not past what is in the way: whoever comes back from granting the permission has read nothing else on the page, and
      // the first move is a drag to a screen edge, which macOS as it comes takes for itself.
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
      case lostShortcuts
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
    /// What to change, one line each, listed under the detail.
    public var points: [String] = []
    /// The title of the button that opens the right pane of System Settings, if one helps.
    public var button: String?

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
  ///   - isPaused: the user has paused Arbor, so none of the moves would do anything.
  ///   - shortcut: the label of the shortcut that runs a command, e.g. ⌃⌥Space. A move without one is
  ///     explained by the menu instead, and with no shortcuts at all the rows about what collides
  ///     with them are left out.
  public init(
    _ facts: SystemFacts, flow: OnboardingFlow? = nil, windowsOutOfView: Int = 0, offersScreenRecording: Bool = false,
    appsWithOwnShortcuts: [String] = [], isPaused: Bool = false, lostShortcuts: [String] = [],
    shortcut: (Command) -> String? = { _ in nil }
  ) {
    let flow = flow ?? OnboardingFlow(isReady: facts.accessibility)
    page = flow.page
    rows = Self.rows(
      facts, windowsOutOfView: windowsOutOfView, offersScreenRecording: offersScreenRecording,
      appsWithOwnShortcuts: appsWithOwnShortcuts, lostShortcuts: lostShortcuts, shortcut: shortcut)
    steps = Self.steps(flow.steps, shortcut: shortcut)
    opensAtLogin = facts.opensAtLogin
    loginTitle = "Open at Login"

    func named(_ title: String, _ command: Command) -> String { shortcut(command).map { "\(title) (\($0))" } ?? title }
    waysBackTitle = "Three ways back"
    waysBack = [
      named("Show Everything", .showAll),
      named("Float All Windows", .floatAll) + " puts your Mac back to normal",
      "Quitting Arbor brings every window back into view",
    ]

    switch page {
    case .permissions:
      title =
        !facts.accessibility
        ? (windowsOutOfView > 0 ? "Arbor needs its permission back" : "Welcome to Arbor")
        : isPaused ? "Arbor is paused" : Self.title(inTheWay: rows.filter(\.needsAttention).count)
      summary =
        "Dock windows side by side, then zoom between them: a camera frames one window, its group, or "
        + "everything at once."
      primaryButton = "Continue"
      isPrimaryEnabled = facts.accessibility
      backButton = nil
      footnote =
        facts.accessibility
        ? Self.whereArborLives : "Arbor notices by itself when the permission arrives."
      footnoteShowsMark = facts.accessibility
    case .firstSteps:
      title = flow.steps.isComplete ? "That is all there is to it" : "Three moves to try"
      summary =
        isPaused
        ? "Arbor is paused and leaves windows and shortcuts alone. Choose Resume in its menu first."
        : flow.steps.isComplete
          ? "Dock more windows, onto each other’s edges too, and zoom between them."
          : "Try them on your own windows. Each is ticked off here as you do it."
      primaryButton = "Done"
      isPrimaryEnabled = true
      backButton = "Back"
      footnote = Self.whereArborLives
      footnoteShowsMark = true
    }
  }

  /// True of a newcomer and of whoever chooses Check Setup… after a year. Not "Arbor is ready" over a warning sign.
  private static func title(inTheWay count: Int) -> String {
    switch count {
    case 0: "Arbor is ready"
    case 1: "One thing is in the way"
    default: "\(["Two", "Three", "Four", "Five"][min(count, 5) - 2]) things are in the way"
    }
  }

  /// Said from the start, not after the last tick: a right click is nothing anybody would guess.
  private static let whereArborLives =
    "Arbor lives in the menu bar, under this mark. Right-click it for every command. If a full menu bar or the notch hides "
    + "it, open Arbor again: that brings this window back, as Help → Welcome… does."

  // MARK: The first page

  private static func rows(
    _ facts: SystemFacts, windowsOutOfView: Int, offersScreenRecording: Bool, appsWithOwnShortcuts apps: [String],
    lostShortcuts lost: [String], shortcut: (Command) -> String?
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
          : stranded + "macOS lets an app move other apps’ windows only with Accessibility permission. Arbor reads "
            + "where windows are and their titles, moves them, and sends nothing anywhere. If Arbor is already "
            + "switched on in the list, this is a new build: switch it off and on again.",
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
    if let switches = facts.switches {
      rows.append(
        Row(
          id: .desktopAndDock, title: "Desktop & Dock settings", importance: "Best changed",
          state: switches.isEmpty ? .done : .recommended, status: switches.isEmpty ? "In order" : "In the way",
          detail: switches.isEmpty ? "" : "As they stand, macOS reacts to the same clicks and drags as Arbor:",
          points: switches.map(\.advice), button: settings))
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
    if !lost.isEmpty {
      let several = lost.count > 1
      rows.append(
        Row(
          id: .lostShortcuts,
          title: (lost.count > 3 ? "\(lost.count) shortcuts" : sentenceList(lost)) + " \(several ? "are" : "is") not Arbor’s",
          importance: "Best changed", state: .recommended, status: "Not registered",
          detail: "Arbor does not hear \(several ? "them" : "it"), so what you press there goes elsewhere, most likely to the app in "
            + "front, which may have a use of its own for it. Quit Arbor and open it again. If that does not help, give the "
            + "command\(several ? "s" : "") another shortcut under Settings → Shortcuts.",
          button: nil))
    }
    return rows.map { row in
      var row = row
      if row.isSatisfied { row.importance = row.status }
      return row
    }
  }

  /// "Rectangle", "Rectangle and Magnet", "Rectangle, Magnet and Amethyst".
  public static func sentenceList(_ words: [String]) -> String {
    guard let last = words.last, words.count > 1 else { return words.first ?? "" }
    return words.dropLast().joined(separator: ", ") + " and " + last
  }

  // MARK: The second page

  private static func steps(_ done: FirstSteps, shortcut: (Command) -> String?) -> [Step] {
    func lead(_ command: Command, menu item: String) -> String {
      shortcut(command).map { "Press \($0)" } ?? "Choose \(item) in Arbor’s menu"
    }
    return [
      Step(
        id: .dock, lead: "Drag a window to a screen edge",
        text: "It docks there, beside everything in view."
          + (arrowModifiers(shortcut).map { " Holding \($0) and pressing an arrow key docks the focused window." } ?? ""),
        isDone: done.docked),
      Step(
        id: .frame, lead: lead(.zoom(nil), menu: "Frame Focused Window"),
        text: "The focused window is framed: it fills the view. Your other windows are out of view, not closed.",
        isDone: done.framed),
      Step(
        id: .showEverything, lead: lead(.showAll, menu: "Show Everything"), text: "Every window is back in view.",
        isDone: done.showedEverything),
    ]
  }

  /// ⌃⌥⌘ when the four `dock` shortcuts are one set of modifiers with the arrow keys.
  private static func arrowModifiers(_ shortcut: (Command) -> String?) -> String? {
    let arrows: [(Edge, Character)] = [(.left, "←"), (.right, "→"), (.top, "↑"), (.bottom, "↓")]
    var modifiers: Set<String> = []
    for (edge, arrow) in arrows {
      guard let label = shortcut(.dock(nil, edge)), label.last == arrow else { return nil }
      modifiers.insert(String(label.dropLast()))
    }
    guard modifiers.count == 1, let shared = modifiers.first, !shared.isEmpty else { return nil }
    return shared
  }
}
