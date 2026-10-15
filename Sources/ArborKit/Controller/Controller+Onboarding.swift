import ArborCore
import CoreGraphics

/// The welcome window (docs/features/F10-menu-bar-and-onboarding.md). The controller says what it shows;
/// `OnboardingWindow` lays that out and reports the buttons.
extension Controller {
  /// What the welcome window says, given what the app found out and how far the user has got.
  public func onboardingModel(
    _ facts: SystemFacts, flow: OnboardingFlow? = nil, fixSetupFailure: String? = nil
  ) -> OnboardingModel {
    // During a pause nearly every shortcut is handed back; the window names the ones that will be there again.
    let bindings =
      facts.inputDisabled || !settings.hotkeysEnabled
      ? [] : isPaused ? effectiveBindings.bindings : bindingsInEffect
    var facts = facts
    facts.switches = macSwitchesInTheWay(facts)
    facts.accessibility = hasPermission(facts)
    return OnboardingModel(
      facts, flow: flow, windowsOutOfView: permissionLoss?.windows ?? 0, offersScreenRecording: offersScreenRecording, appsWithOwnShortcuts: passThroughSuggestions.map(\.name),
      canFixSetup: macSwitchboard != nil, switchesChangedByArbor: macSwitchesChangedByArbor, switchesGivenBack: macSwitchesLent,
      fixSetupFailure: fixSetupFailure,
      menuBarIsOneIcon: menuBarIsSurelyOneIcon, desktops: desktopsBetweenWhatIsDocked,
      isNewcomer: isFirstLaunch && workspaces.values.allSatisfy { $0.tree.allWindows.isEmpty }, isPaused: isPaused && accessibilityGranted,
      shortcut: { KeyBindings.label(for: $0, in: bindings) })
  }

  /// Short of asking `menuBarModel()`, which looks where the pointer is: this is asked once a second. Where it says no the item may still be
  /// one icon (the pointer is on an empty display, the menu bar is full), and a right click opens that too.
  private var menuBarIsSurelyOneIcon: Bool {
    !isRunning || !settings.menuBarControls || workspaces.values.allSatisfy { $0.tree.allWindows.isEmpty }
  }

  /// The Desktop's part of each display on which something is docked, while it is in view.
  fileprivate var desktopsBetweenWhatIsDocked: [CGRect] {
    displays.compactMap { display in
      workspaces[display.id]?.tree.allWindows.isEmpty == false ? layouts[display.id]?.desktopFrame : nil
    }
  }

  /// Both must say yes: macOS's own flag, and Arbor, whose probe can find the permission gone before the flag follows (F63). Otherwise
  /// the window that opens because it went would show a tick, under a menu that says it is missing.
  func hasPermission(_ facts: SystemFacts) -> Bool { facts.accessibility && accessibilityGranted }

  /// `check-setup` and `welcome`. They work before `start()`: the window is for exactly that time.
  func showWelcomeWindow(_ page: OnboardingFlow.Page) -> CommandResult {
    guard let openWelcomeWindow else { return .failure("there is no window to open here; try `doctor`") }
    openWelcomeWindow(page)
    noteWelcomed()
    return .success("showing the welcome window")
  }

  // MARK: The first launch (docs/features/F46-first-run-coach.md)

  /// The page to open the welcome window on by itself, now that Arbor arranges windows, or nil if this person has seen
  /// it. With the permission already there a first launch changes nothing on the display, and the one new icon may be
  /// behind a notch. What there is to put right comes first; with nothing of the kind, the four moves.
  public func pageToWelcomeOn() -> OnboardingFlow.Page? {
    guard isRunning, !hasWelcomed else { return nil }
    let facts =
      systemFacts?() ?? SystemFacts(accessibility: accessibilityGranted, screenRecording: false, switches: nil)
    return onboardingModel(facts).pageToOpenOn
  }

  /// The welcome window is on the display, whoever opened it.
  public func noteWelcomed() {
    guard !hasWelcomed else { return }
    hasWelcomed = true
    // Only while Arbor runs: before that it has not read what it saved, and would write an empty arrangement over it.
    // `start()` saves by itself.
    if isRunning { scheduleSave() }
  }
}

/// One showing of the welcome window, from `begin()` to `end()`: keeps its model in step with the facts
/// about the Mac (which nothing reports, so the window asks for `refresh()` once a second) and with the
/// arrangement (which the controller reports, so the moves on the second page are ticked off as they
/// happen). Calls `onChange` whenever the window has something else to show. Make one per controller.
@MainActor
public final class OnboardingSession {
  public private(set) var model: OnboardingModel
  private var facts: SystemFacts
  private var flow: OnboardingFlow
  private var isOpen = false
  /// What a button of the page on show answered when it last failed.
  private var failure: String?
  private weak var controller: Controller?
  private let onChange: @MainActor (OnboardingModel) -> Void

  public init(controller: Controller, onChange: @escaping @MainActor (OnboardingModel) -> Void) {
    self.controller = controller
    self.onChange = onChange
    facts = Self.facts(of: controller)
    flow = OnboardingFlow(isReady: facts.accessibility)
    model = controller.onboardingModel(facts, flow: flow)
    controller.observe { [weak self] _ in self?.arrangementChanged() }
    // With the facts of a second ago the window would hold what Arbor has just done against the Mac.
    controller.macSwitchesDidChange = { [weak self] in self?.refresh() }
  }

  private static func facts(of controller: Controller) -> SystemFacts {
    var facts =
      controller.systemFacts?()
      ?? SystemFacts(accessibility: controller.accessibilityGranted, screenRecording: false, switches: nil)
    // Here too, so that the page turns by the same answer.
    facts.accessibility = controller.hasPermission(facts)
    return facts
  }

  /// The window opens: start over on `page`, with nothing ticked but what is already so.
  public func begin(on page: OnboardingFlow.Page = .permissions) {
    guard let controller else { return }
    isOpen = true
    facts = Self.facts(of: controller)
    flow = OnboardingFlow(isReady: facts.accessibility)
    failure = nil
    flow.go(to: page)
    flow.steps.observe(controller.workspaces)
    publish()
  }

  /// The window closed: nothing is watching any more.
  public func end() { isOpen = false }

  /// Reads the facts about the Mac again.
  public func refresh() {
    guard isOpen, let controller else { return }
    facts = Self.facts(of: controller)
    let page = flow.page
    flow.update(isReady: facts.accessibility, needsAttention: controller.onboardingModel(facts).needsAttention)
    if flow.page != page { failure = nil }
    publish()
  }

  /// A row's button has run its command. The window follows at once, not at the next look at the Mac, and says so if nothing came of it:
  /// before Arbor runs there is no display to say it on.
  public func actionEnded(_ result: CommandResult) {
    failure = result.ok ? nil : result.message
    refresh()
  }

  /// The Continue and Back buttons.
  public func go(to page: OnboardingFlow.Page) {
    guard isOpen else { return }
    // What went wrong is said beside the button that was pressed, which is on the page being left.
    if flow.page != page { failure = nil }
    flow.go(to: page)
    publish()
  }

  private func arrangementChanged() {
    guard isOpen, let controller else { return }
    // Most changes tick nothing off (every step of a gap being dragged is one), so look before wording it all again.
    let before = flow.steps
    flow.steps.observe(controller.workspaces)
    // The window rests over the Desktop, so it follows that too.
    if flow.steps != before || (flow.page == .firstSteps && controller.desktopsBetweenWhatIsDocked != model.desktops) { publish() }
  }

  private func publish() {
    guard let controller else { return }
    let current = controller.onboardingModel(facts, flow: flow, fixSetupFailure: failure)
    guard current != model else { return }
    model = current
    onChange(current)
  }
}
