import CoreGraphics

/// The four moves a newcomer tries on the welcome window's second page, ticked off as they happen:
/// dock a window, dock a second beside it, fill the screen with one, bring both back. Each is recognised from the arrangement itself, so
/// it does not matter whether the keyboard, the pointer or the menu did it, nor in which order.
///
/// Two docks, because one docked window looks like macOS's own tiling and shows nothing of what Arbor is for: readers who knew nothing
/// said "I never see two side by side".
public struct FirstSteps: Equatable, Sendable {
  public private(set) var docked = false
  public private(set) var dockedTwo = false
  public private(set) var framed = false
  public private(set) var showedEverything = false
  /// The displays whose view has been somewhere else than on everything. Show Everything counts on those: showing
  /// everything from the start is no move.
  private var away: Set<DisplayID> = []

  public init() {}

  public var isComplete: Bool { docked && dockedTwo && framed && showedEverything }

  /// Looks at the arrangement after a change. A tick stays.
  public mutating func observe(_ workspaces: [DisplayID: Workspace]) {
    if !docked { docked = workspaces.values.contains { !$0.tree.allWindows.isEmpty } }
    // On one display: side by side is what there is to see.
    if !dockedTwo { dockedTwo = workspaces.values.contains { $0.tree.allWindows.count >= 2 } }
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
/// comes back if the permission is taken away. Whoever knows Arbor is not shown the first steps unasked (`update`).
public struct OnboardingFlow: Equatable, Sendable {
  public enum Page: Sendable {
    /// The welcome: what Arbor is for, and the one permission. The first minute asks for nothing else (Q29, 11).
    case permissions
    /// The four moves.
    case firstSteps
    /// Check Setup…: everything on this Mac that matters to Arbor, with whether it is in order. Only for whoever asks, and only once
    /// Arbor may arrange windows: until then there is one thing to put right, and the welcome has it.
    case setup
  }

  public private(set) var page = Page.permissions
  public var steps = FirstSteps()
  private var isReady: Bool
  /// The four moves have been on show. Whoever has passed the first page by is not held at it again.
  private var hasGoneOn = false
  /// The page that was asked for while there was only the welcome to show.
  private var asked: Page?

  /// - Parameter isReady: Arbor has Accessibility permission.
  public init(isReady: Bool) { self.isReady = isReady }

  /// How things stand, whatever they are: for whoever wants every row and shows no window (`OnboardingModel.init` without a flow).
  static func checkingSetup(isReady: Bool) -> OnboardingFlow {
    var flow = OnboardingFlow(isReady: isReady)
    flow.page = .setup
    return flow
  }

  /// - Parameters:
  ///   - knowsArbor: this person had seen the window before this launch. Nobody is taught twice.
  ///   - needsAttention: the first page has advice that has not been taken (`OnboardingModel.needsAttention`). Asked only
  ///     at the moment the permission arrives.
  public mutating func update(isReady: Bool, knowsArbor: Bool = false, needsAttention: @autoclosure () -> Bool) {
    if !isReady {
      page = .permissions
    } else if !self.isReady, page == .permissions, knowsArbor {
      // What they asked for, the moves too if it was those; or how things stand, which has whatever is in the way.
      go(to: asked ?? .setup, isReady: true)
    } else if !self.isReady, page == .permissions, hasGoneOn || !needsAttention() {
      // What the window was waiting for. Closing now would leave a newcomer looking at an unchanged screen.
      // Not past what is in the way: whoever comes back from granting the permission has read nothing else on the page.
      page = .firstSteps
      hasGoneOn = true
    }
    self.isReady = isReady
  }

  /// The Continue and Back buttons. There is nothing to try before Arbor may move windows.
  public mutating func go(to page: Page) { go(to: page, isReady: isReady) }

  private mutating func go(to page: Page, isReady: Bool) {
    self.page = isReady ? page : .permissions
    asked = isReady || page == .permissions ? nil : page
    if self.page == .firstSteps { hasGoneOn = true }
  }
}

/// What the welcome window says (docs/features/F10-menu-bar-and-onboarding.md). The first page: what Arbor
/// is, and one row per permission, macOS setting or other app that matters, with whether it is in
/// order. The second: four moves to try, ticked off live, and the ways back to a normal Mac.
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
    /// Why it matters and what to do. Empty once the row is in order: a tick says enough. But for one that will not last, on Check Setup….
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
    /// Its words are to be read in order to act, so they are drawn in the primary ink: macOS's secondary grey is 3.7 to 1 in the light look.
    /// What stands under a tick is only good to know.
    public var mustBeRead: Bool { !isSatisfied }
    /// Something is missing or in the way, and there is something to do about it.
    public var needsAttention: Bool { state == .required || state == .recommended }
  }

  /// One of the moves to try: what to do, and what happens.
  public struct Step: Equatable, Sendable, Identifiable {
    public enum ID: String, Sendable, CaseIterable {
      case dock, dockSecond, frame, showEverything
    }

    public var id: ID
    public var lead: String
    public var text: String
    public var isDone: Bool
    /// The first that has not been made. It alone is explained: the window lies over the windows the moves are made on, so it is kept small.
    public var isNext = false
  }

  public var page: OnboardingFlow.Page
  public var title: String
  public var summary: String
  /// The first page.
  public var rows: [Row]
  /// The second page.
  public var steps: [Step]
  /// The welcome: the keys in a sentence, so that whoever closes the window here has them. Empty on the other pages and without shortcuts.
  public var keysLine: String
  /// What the signs on the keys are called: the key to the signs. Empty when the page shows none.
  public var keysLegend: String
  /// The second page: the one way back a newcomer needs. ("Three ways back" blurred: four readers of six could not tell them apart.)
  public var wayBack: String
  /// Whether Arbor opens at login, for the tick box on the second page. Nil leaves the box out.
  public var opensAtLogin: Bool?
  public var loginTitle: String
  public var footnote: String
  /// The footnote says "under this icon", so the window shows it beside the text: the one that is in the menu bar now. While Arbor waits for
  /// its permission that is a warning sign, and that is the one time a newcomer looks for it.
  public var footnoteIcon: MenuBarModel.Icon
  /// Where the Desktop lies between what is docked, in global coordinates, on each display that has something docked and its Desktop in view.
  public var desktops: [CGRect]
  /// The button that goes on: Continue, then Done.
  public var primaryButton: String
  public var isPrimaryEnabled: Bool
  /// The button that goes back to the first page, on the second.
  public var backButton: String?

  /// Arbor has what it needs to arrange windows.
  public var isReady: Bool { rows.allSatisfy { $0.state != .required } }

  /// Something on the page is missing or in the way: a reason to show it before the four moves.
  public var needsAttention: Bool { rows.contains(where: \.needsAttention) }

  /// Arbor has never run on this Mac and nothing is docked.
  public var isNewcomer: Bool

  /// The page to show somebody who has seen neither. A newcomer is told what Arbor is for first.
  public var pageToOpenOn: OnboardingFlow.Page { needsAttention || isNewcomer ? .permissions : .firstSteps }

  /// Whether this is good news that somebody is waiting for in another window: the permission has arrived, or the last thing in the
  /// way has gone. They are in System Settings then, which covers this window, and Arbor has no other face: it comes forward.
  public func isWorthComingForward(after old: OnboardingModel) -> Bool {
    (isReady && !old.isReady) || (!needsAttention && old.needsAttention)
  }

  public func row(_ id: Row.ID) -> Row? { rows.first { $0.id == id } }
  public func step(_ id: Step.ID) -> Step? { steps.first { $0.id == id } }

  /// - Parameters:
  ///   - flow: which page, and what is ticked. Nil: Check Setup…, where every row is.
  ///   - windowsOutOfView: how many windows were out of view when the permission was taken away while Arbor ran, and
  ///     still are (F63 counts them).
  ///   - offersScreenRecording: whether the optional permission has a row. Only where Arbor makes good use of it.
  ///   - appsWithOwnShortcuts: the names of open apps known to use ⌃⌥ themselves, for which nothing has been decided (F41).
  ///   - canFixSetup: Arbor can switch macOS's own settings off for whoever asks (`fix-setup`).
  ///   - switchesChangedByArbor: the ones it keeps off while it runs, because somebody asked it to.
  ///   - switchesGivenBack: those of them macOS has back for the time being: Arbor is paused, or may not arrange windows.
  ///   - fixSetupFailure: what `fix-setup` answered when it last failed in this showing of the window.
  ///   - menuBarIsOneIcon: the menu bar item is Arbor's icon alone, which a plain click opens; with something docked it is a row of buttons.
  ///   - menuBarIcon: that icon as it is now.
  ///   - desktops: see `desktops`.
  ///   - isNewcomer: Arbor has never run on this Mac and nothing is docked.
  ///   - isPaused: the user has paused Arbor, so none of the moves would do anything.
  ///   - signature: how this build is signed, if anybody said: it decides how long the permission lasts. Without the permission that is
  ///     said on every page; under the tick on Check Setup… alone.
  ///   - shortcut: the label of the shortcut that runs a command, e.g. ⌃⌥Space. A move without one is
  ///     explained by the menu instead, and with no shortcuts at all the rows about what collides
  ///     with them are left out.
  public init(
    _ facts: SystemFacts, flow: OnboardingFlow? = nil, windowsOutOfView: Int = 0, offersScreenRecording: Bool = false,
    appsWithOwnShortcuts: [String] = [], canFixSetup: Bool = false, switchesChangedByArbor: [MacSwitch] = [],
    switchesGivenBack: [MacSwitch] = [],
    fixSetupFailure: String? = nil, menuBarIsOneIcon: Bool = true, menuBarIcon: MenuBarModel.Icon = MenuBarModel.Icon(),
    desktops: [CGRect] = [], isNewcomer: Bool = false,
    isPaused: Bool = false, lostShortcuts: [String] = [], signature: BuildInfo.Signature? = nil, dragDocks: DragDocks = .held,
    shortcut: (Command) -> String? = { _ in nil }
  ) {
    let flow = flow ?? .checkingSetup(isReady: facts.accessibility)
    page = flow.page
    self.desktops = desktops
    self.isNewcomer = isNewcomer
    let whereArborLives = Self.whereArborLives(isOneIcon: menuBarIsOneIcon)
    footnoteIcon = menuBarIcon
    // The first minute asks for the one permission and for nothing else. What would spoil the four moves is said all the same, because no
    // move is taught that cannot work: who takes the same keys, and Stage Manager, which moves windows itself. macOS's tiling spoils none of
    // them: they are keys. It and the rest are for whoever asks (Check Setup…).
    var told = facts
    if page != .setup { told.switches = facts.switches?.filter { $0 == .stageManager } }
    let all = Self.rows(
      told, windowsOutOfView: windowsOutOfView, offersScreenRecording: offersScreenRecording,
      appsWithOwnShortcuts: appsWithOwnShortcuts, canFixSetup: canFixSetup, changed: page == .setup ? switchesChangedByArbor : [],
      givenBack: page == .setup ? switchesGivenBack : [], isPaused: isPaused,
      failure: fixSetupFailure, canDock: facts.accessibility && !isPaused,
      lostShortcuts: lostShortcuts, isCheckSetup: page == .setup, isNewcomer: isNewcomer, signature: signature, dragDocks: dragDocks,
      shortcut: shortcut)
    rows =
      page == .setup
      ? all
      : all.filter { [.accessibility, .competingApps, .voiceOver, .lostShortcuts].contains($0.id) || ($0.id == .desktopAndDock && !$0.isSatisfied) }
    steps = Self.steps(flow.steps, shortcut: shortcut)
    // During the moves the window lies over the windows they are made on: whatever is not about them waits for the last tick.
    let isBusy = page == .firstSteps && !flow.steps.isComplete
    opensAtLogin = isBusy ? nil : facts.opensAtLogin
    loginTitle = "Open at Login"

    let pause = shortcut(.togglePause)
    wayBack =
      isPaused
      ? (pause.map { "\($0) resumes Arbor." } ?? "Resume in Arbor’s menu resumes it.")
      : (pause.map { "\($0) pauses Arbor" } ?? "Pause Arbor in its menu pauses it") + ": every window is as it was. Quit does the same."
    keysLine = ""
    let hasLostIt = windowsOutOfView > 0 && !facts.accessibility

    switch page {
    case .permissions:
      // A newcomer wants to know what this is before how it stands: three readers of three, asked why they would use it rather than what
      // their Mac does, said "I do not know".
      title =
        hasLostIt ? "Arbor needs its permission back" : isPaused && facts.accessibility ? "Arbor is paused" : "Arbor keeps your windows arranged"
      // The product's one sentence (README.md has the same): what it is for, and what it has over the tiling a Mac comes with. With the
      // third part three readers of three could say why they would use it; without it none.
      summary = Self.whatArborIsFor
      if let left = shortcut(.dock(nil, .left)), let right = shortcut(.dock(nil, .right)), let fill = shortcut(.zoom(nil)) {
        // The promise somebody wants who is about to let an app move their windows. Only where it holds: a later start brings back
        // what was docked, and a permission that returns brings back what was out of view.
        keysLine =
          (isNewcomer ? "Nothing moves until you ask. " : "")
          + "\(left) and \(right) put a window left or right. \(fill) fills the screen with it, and brings both back."
      }
      primaryButton = "Continue"
      isPrimaryEnabled = facts.accessibility
      backButton = nil
      footnote = Self.whereArborLivesInShort
    case .setup:
      title =
        hasLostIt ? "Arbor needs its permission back"
        : !facts.accessibility ? "Arbor needs one permission"
        : isPaused ? "Arbor is paused" : Self.title(inTheWay: rows.filter(\.needsAttention).count)
      summary = "What on this Mac matters to Arbor, and how it stands."
      primaryButton = "Done"
      isPrimaryEnabled = true
      backButton = nil
      footnote = whereArborLives
    case .firstSteps:
      title = flow.steps.isComplete ? "That is all there is to it" : "Four moves to try"
      summary =
        isPaused
        ? "Arbor is paused and leaves windows and shortcuts alone. Resume it first."
        : flow.steps.isComplete
          ? "The arrangement stays until you change it." + (shortcut(.undo).map { " \($0) takes back the last change." } ?? "")
          : "On your own windows, one after the other. Each is ticked off here as you do it."
      primaryButton = "Done"
      isPrimaryEnabled = true
      backButton = "Back"
      footnote = isBusy ? Self.whereArborLivesInShort : whereArborLives
    }
    let shown: [String] =
      switch page {
      case .permissions: [keysLine]
      case .setup: []
      case .firstSteps: steps.flatMap { $0.isNext ? [$0.lead, $0.text] : [$0.lead] } + [summary, wayBack]
      }
    keysLegend = Self.legend(for: shown)
  }

  /// Decided by the product owner after three readers of three could not say why they would use Arbor rather than what their Mac does.
  public static let whatArborIsFor =
    "Arrange windows side by side once. Fill the screen with any one, and one key brings the arrangement back. Your Mac’s own tiling forgets an "
    + "arrangement; Arbor keeps it."

  private static let signs: [(Character, String)] = [
    ("⌃", "Control"), ("⌥", "Option"), ("⇧", "Shift"), ("⌘", "Command"), ("↩", "Return"), ("⎋", "Escape"),
  ]

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

  /// In Check Setup… and after the last tick.
  /// Only what is true of the item as it is: a plain click opens the single icon's menu, and runs a button of the row.
  private static func whereArborLives(isOneIcon: Bool) -> String {
    "Arbor lives in the menu bar, under this icon. \(isOneIcon ? "Click" : "Right-click") it for all commands, including Quit Arbor. Can’t see "
      + "the icon? Open Arbor again and this window returns."
  }

  private static let whereArborLivesInShort = "Arbor lives in the menu bar, under this icon."

  /// How wide the window is on each page. For the moves it is small.
  public static func width(of page: OnboardingFlow.Page) -> CGFloat { page == .firstSteps ? 420 : 560 }

  /// Where the window goes when it has something else to show. All in global coordinates, y down.
  public struct Placement: Equatable, Sendable {
    public var frame: CGRect
    /// It glides there instead of jumping: it is on its way to or between its resting places.
    public var glides: Bool

    public init(frame: CGRect, glides: Bool) {
      self.frame = frame
      self.glides = glides
    }
  }

  /// - Parameters:
  ///   - page: the page it shows now.
  ///   - previous: the page it showed before. Nil: it is just opening.
  ///   - staysPut: somebody has taken hold of it during the moves, in this showing. From then on it stays where it is put.
  ///   - old: its frame so far.
  ///   - size: what it needs now.
  ///   - visible: the visible frame of its display.
  public static func placement(
    page: OnboardingFlow.Page, previous: OnboardingFlow.Page?, staysPut: Bool, old: CGRect, size: CGSize, visible: CGRect, desktops: [CGRect]
  ) -> Placement {
    if page == .firstSteps, !staysPut {
      return Placement(
        frame: CGRect(
          origin: restingPlace(
            size: size, visible: visible, desktops: desktops, isAtTheLeft: previous == .firstSteps && old.midX < visible.midX),
          size: size),
        glides: previous != nil)
    }
    // Opening, or back from where it rested: where macOS centres a window, a little above the middle.
    if page != .firstSteps, previous == nil || (previous == .firstSteps && !staysPut) {
      let origin = CGPoint(
        x: (visible.midX - size.width / 2).rounded(), y: (visible.minY + max(visible.height - size.height, 0) / 3).rounded())
      return Placement(frame: CGRect(origin: origin, size: size), glides: false)
    }
    // Its title bar stays where it is.
    var frame = CGRect(origin: old.origin, size: size)
    // Growing must not push the buttons under the Dock or off the display. Only growing: where somebody has put it, half off the display
    // if they like, it stays.
    if size.height > old.height, frame.maxY > visible.maxY { frame.origin.y = max(visible.maxY - size.height, visible.minY) }
    if size.width > old.width, frame.maxX > visible.maxX { frame.origin.x = max(visible.maxX - size.width, visible.minX) }
    return Placement(frame: frame, glides: false)
  }

  /// Where the window waits during the moves: its top left corner. Its promise is to keep out of the windows' way, and a dock touches only
  /// what is docked: the others lie where they lay, and what shows of them shows in the free part of the display. So it rests in the
  /// bottom corner on that side, farthest from what has been docked, a gap's width in: at the right while nothing is docked, because
  /// the first move goes to the left. It crosses the display for nothing else: where the free part reaches both sides or neither (between two
  /// docked windows, out of view, none at all) it stays on the side where it is. Where the line that says what each move did could reach
  /// it, it gives way upward.
  /// - Parameter isAtTheLeft: where it rests now.
  static func restingPlace(size: CGSize, visible: CGRect, desktops: [CGRect], isAtTheLeft: Bool) -> CGPoint {
    var isAtTheLeft = isAtTheLeft
    if let free = desktops.first(where: { $0.overlaps(visible) }) {
      // Within two gaps of the display's edge.
      let (reachesLeft, reachesRight) = (free.minX - visible.minX <= 2 * inset, visible.maxX - free.maxX <= 2 * inset)
      if reachesLeft != reachesRight { isAtTheLeft = reachesLeft }
    }
    let x = isAtTheLeft ? visible.minX + inset : visible.maxX - size.width - inset
    // The line is centred, and as wide as its words, up to this.
    let reach = HeadsUpModel(kind: .hint, text: "").placed(in: visible).maximumWidth / 2
    let meetsTheLine = x < visible.midX + reach && x + size.width > visible.midX - reach
    let y = visible.maxY - (meetsTheLine ? roomBelow : inset) - size.height
    // On whole points, or the window would be asked for a frame it cannot have, again at every look.
    return CGPoint(x: x.rounded(), y: max(y, visible.minY).rounded())
  }

  /// As wide as the gap between docked windows comes.
  static let inset: CGFloat = 12
  /// The heads-up line and a little air.
  static let roomBelow = HeadsUpModel.bottomMargin + 48

  // MARK: The first page

  /// What somebody can do at a screen edge now that it is Arbor's, by how a dragged window docks. Nothing where no drag does.
  private static func whatTheEdgesAreFor(_ dragDocks: DragDocks) -> String {
    switch dragDocks {
    case .held: " To dock a window there, hold ⌘ and drag it to a screen edge."
    case .always: " A window dragged to a screen edge docks now."
    case .never: ""
    }
  }

  private static func rows(
    _ facts: SystemFacts, windowsOutOfView: Int, offersScreenRecording: Bool, appsWithOwnShortcuts apps: [String],
    canFixSetup: Bool, changed: [MacSwitch], givenBack: [MacSwitch], isPaused: Bool, failure: String?, canDock: Bool,
    lostShortcuts lost: [String], isCheckSetup: Bool, isNewcomer: Bool, signature: BuildInfo.Signature?, dragDocks: DragDocks,
    shortcut: (Command) -> String?
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
          // For whoever opens Check Setup while all is well, before the next time comes. Whoever downloads Arbor reads this too, so in a
          // stranger's words: "signed ad hoc" is a builder's, and `doctor` and `make install` have it. By the page and not by the person: there
          // somebody has asked, on the first day too; the welcome stays bare for everybody.
          ? (signature?.outlivesTheBuild == false && isCheckSetup
            ? "macOS will ask for this permission again after each update of Arbor, because Arbor is not yet signed with an Apple "
              + "Developer ID."
            : "")
          : stranded + "macOS asks your permission before an app may move other apps’ windows. Arbor reads only each window’s position "
            + "and title, and nothing leaves your Mac. Flip the switch next to Arbor in System Settings."
            // True for a newcomer alone: for whoever knows Arbor it goes away by itself then, or stays where it was asked for.
            + (isNewcomer ? " This window comes back by itself." : "")
            // Another build over an old grant: the switch looks on, and Arbor waits. It looks like a first launch too, so this is said to
            // everybody, or whoever meets it finds nothing to flip. The reason, not where the permission went while Arbor ran, nor of a build
            // signed with a certificate, of which it is not true.
            + " Already on? Switch it off and on again"
            + (windowsOutOfView == 0 && signature?.outlivesTheBuild != true ? ": macOS asks anew after every update." : "."),
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
      // What Arbor has given back for the time being is on by Arbor's own doing, and in nobody's way: Arbor is not arranging windows.
      let lent = givenBack
      let switches = (order.filter(all.contains) + all.filter { !order.contains($0) }).filter { !lent.contains($0) }
      let mine = switches.filter(\.canBeSwitchedOffForYou).count
      // While macOS's switch for an edge is on, that whole edge is macOS's (collab/QUESTIONS.md, Q23).
      let takesEdges = switches.contains(.screenEdges) || switches.contains(.menuBar)
      let offers = canFixSetup && mine > 0
      var sentences: [String] = []
      if mine > 0 {
        // What it does to a person, what the step gets them, and for how long. No word that has to be learnt, and no keys: six readers of
        // six called the longer text a wall.
        sentences = [
          "Your Mac tiles a window dragged \(takesEdges ? "to a screen edge" : "with Option held"), before Arbor gets it."
        ]
        if offers {
          sentences.append("Switch that off, only while Arbor runs, and Arbor has \(takesEdges ? "the edges" : "the drag").")
        }
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
          // By their names: without them "3 settings" made six readers of six uneasy.
          "Changes \(mine) setting\(mine == 1 ? "" : "s") in Desktop & Dock, nothing else: \(names.joined(separator: ", "))."
      }
      if canFixSetup, !changed.isEmpty {
        // A tick says enough, except of what Arbor did to somebody's Mac. Whatever else the row has to say: the way back was promised here.
        // One that somebody has switched on again by hand is theirs.
        let off = changed.filter { !switches.contains($0) }.count
        let one = off == 1
        if lent.isEmpty, off > 0 {
          row.done =
            "While Arbor runs, \(off) setting\(one ? "" : "s") of macOS \(one ? "is" : "are") off. Quit or pause Arbor, and your Mac is as "
            + "it was. To end that for good: here, or later under Help → Check Setup… in Arbor’s menu."
            // What it was for, where that has come true: every edge is Arbor's, and Arbor may and does move windows.
            + (changed.contains(.screenEdges) && !takesEdges && canDock ? Self.whatTheEdgesAreFor(dragDocks) : "")
          row.undo = Row.Action(one ? "Put It Back" : "Put Them Back", .fixSetup(undo: true))
        } else if !lent.isEmpty {
          // Neither a tick, which would say "off", nor advice: this is Arbor keeping its word.
          if switches.isEmpty {
            row.state = .note
            row.status = "On for now"
            row.importance = row.status
            row.button = nil
          }
          row.done =
            isPaused
            ? "Arbor is paused, so macOS has its tiling back. Arbor switches it off again when it resumes."
            : "Until Arbor may arrange windows, macOS keeps its tiling. Arbor switches it off when it starts, and only while it runs."
          row.undo = Row.Action(lent.count == 1 ? "Leave It On" : "Leave Them On", .fixSetup(undo: true))
        }
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
    case .permissions, .setup:
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
      if !keysLine.isEmpty { lines += ["", keysLine, keysLegend] }
    case .firstSteps:
      if !keysLegend.isEmpty { lines.append(keysLegend) }
      for step in steps {
        lines.append("\(step.isDone ? "✔" : "○") \(step.lead)")
        if step.isNext { lines.append("    \(step.text)") }
      }
      lines += ["", wayBack]
      if let opensAtLogin { lines += ["", "[\(opensAtLogin ? "x" : " ")] \(loginTitle)"] }
    }
    lines.append("")
    // The icon by what VoiceOver reads of it, where it is not simply Arbor's mark.
    if !footnote.isEmpty { lines.append(footnote + (footnoteIcon == MenuBarModel.Icon() ? "" : " [\(footnoteIcon.label)]")) }
    lines.append((backButton.map { "[\($0)] " } ?? "") + (isPrimaryEnabled ? "[\(primaryButton)]" : "(\(primaryButton))"))
    return lines.joined(separator: "\n")
  }

  /// "Rectangle", "Rectangle and Magnet", "Rectangle, Magnet and Amethyst".
  public static func sentenceList(_ words: [String]) -> String {
    guard let last = words.last, words.count > 1 else { return words.first ?? "" }
    return words.dropLast().joined(separator: ", ") + " and " + last
  }

  // MARK: The second page

  /// All four by key, whatever macOS's switches say: a key works on every Mac as it is set, and the first act of a newcomer is not the one
  /// act a fresh Mac takes away from Arbor (Q29, 11). Worded from the shortcuts in effect.
  private static func steps(_ done: FirstSteps, shortcut: (Command) -> String?) -> [Step] {
    let fill = shortcut(.zoom(nil))
    var steps = [
      Step(
        id: .dock,
        lead: shortcut(.dock(nil, .left)).map { "Click a window and press \($0)" }
          ?? "Click a window and choose Dock Focused Window → Left in Arbor’s menu",
        text: "It docks: it takes the left side of the screen and stays there.", isDone: done.docked),
      // Not "halves": today the two and the Desktop share the width (Q28 will make them halves).
      Step(
        id: .dockSecond,
        lead: shortcut(.dock(nil, .right)).map { "Click another and press \($0)" }
          ?? "Click another and choose Dock Focused Window → Right in Arbor’s menu",
        text: "It takes the other side.", isDone: done.dockedTwo),
      // One breath: the docks alone look like little, and the two moves after them are where Arbor pays.
      Step(
        id: .frame, lead: fill.map { "Then press \($0)" } ?? "Then choose Frame Focused Window in Arbor’s menu",
        // Twelve readers of twelve could not tell it from the green button's full screen.
        text: "The window you are in fills the screen; the menu bar stays, and it is not macOS’s full screen. Your other windows are out "
          + "of view, not closed: ⌘Tab and the Dock still reach them.",
        isDone: done.framed),
      // The same key: one to learn, not two.
      Step(
        id: .showEverything, lead: fill.map { "Press \($0) again" } ?? "Then choose Show Everything in Arbor’s menu",
        text: "The arrangement is back.", isDone: done.showedEverything),
    ]
    if let next = steps.firstIndex(where: { !$0.isDone }) { steps[next].isNext = true }
    return steps
  }
}
