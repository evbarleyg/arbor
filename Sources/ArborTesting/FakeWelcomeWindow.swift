import ArborCore
import ArborKit

/// The welcome window without AppKit: what `OnboardingWindow` and the few lines of `ArborApp` around it do, on the real
/// `OnboardingSession` and the real controller. Tests and `arbor-sim first-launch` read it as text and click its buttons by their titles.
@MainActor
public final class FakeWelcomeWindow {
  public private(set) var isOpen = false
  /// How often it has come in front of whatever lay over it (System Settings, mostly).
  public private(set) var timesComeForward = 0
  /// The panes of System Settings its buttons have opened, in order.
  public private(set) var panesOpened: [OnboardingModel.Row.ID] = []
  /// How often macOS has been asked to put Arbor in the list under Accessibility.
  public private(set) var timesMacOSWasAsked = 0
  /// macOS answers that with a dialog of its own. False: this once it does not.
  public var macOSAnswersWithItsDialog = true
  /// That dialog is on the screen. Its button opens the pane and puts it away (`clickOpenSystemSettingsInMacOSsDialog`).
  public private(set) var macOSsDialogIsOpen = false
  /// Called whenever it shows something else, opens or closes.
  public var onChange: (() -> Void)?

  private let controller: Controller
  private var session: OnboardingSession!
  private var shown: OnboardingModel?

  /// Takes the controller's `openWelcomeWindow` and `askForAccessibility`, as the app does.
  public init(controller: Controller) {
    self.controller = controller
    session = OnboardingSession(controller: controller) { [weak self] _ in self?.render() }
    controller.openWelcomeWindow = { [weak self] page in self?.show(page) }
    controller.askForAccessibility = { [weak self] in self?.show(nil) }
    controller.accessibilityErrand = AccessibilityErrand(
      askMacOS: { [weak self] in
        guard let self else { return }
        self.timesMacOSWasAsked += 1
        self.macOSsDialogIsOpen = self.macOSAnswersWithItsDialog
      },
      macOSIsAsking: { [weak self] in self?.macOSsDialogIsOpen ?? false },
      openPane: { [weak self] in self?.panesOpened.append(.accessibility) })
  }

  public var model: OnboardingModel { session.model }
  /// What it says, or nil while it is closed.
  public var text: String? { isOpen ? model.text : nil }

  /// `ArborApp.showWelcomeWindow`: opens it on `page`, or turns it to that page. Nil: an open window stays as it is.
  public func show(_ page: OnboardingFlow.Page?) {
    if isOpen {
      if let page { session.go(to: page) }
    } else {
      isOpen = true
      session.begin(on: page)
      shown = session.model
      onChange?()
    }
    controller.noteWelcomed()
  }

  /// The person does what macOS's dialog asks.
  public func clickOpenSystemSettingsInMacOSsDialog() {
    guard macOSsDialogIsOpen else { return }
    macOSsDialogIsOpen = false
    panesOpened.append(.accessibility)
  }

  /// A second passes: the window looks at the Mac again.
  public func tick() {
    guard isOpen else { return }
    session.refresh()
  }

  public func close() {
    guard isOpen else { return }
    isOpen = false
    session.end()
    onChange?()
  }

  /// Every button that can be clicked now, by its title, top to bottom.
  public var buttons: [String] {
    guard isOpen else { return [] }
    var titles: [String] = []
    if model.page != .firstSteps {
      for row in model.rows { titles += [row.action?.title, row.button, row.undo?.title].compactMap { $0 } }
    }
    titles += [model.backButton, model.isPrimaryEnabled ? model.primaryButton : nil].compactMap { $0 }
    return titles
  }

  /// A click on the first button of that title. False if there is none to click.
  @discardableResult
  public func click(_ title: String) -> Bool {
    guard buttons.contains(title) else { return false }
    if model.page != .firstSteps {
      for row in model.rows {
        if let action = [row.action, row.undo].compactMap({ $0 }).first(where: { $0.title == title }) {
          session.actionEnded(controller.perform(action.command, from: .script))
          return true
        }
        if row.button == title {
          if row.id == .accessibility { controller.sendToAccessibilitySettings() } else { panesOpened.append(row.id) }
          return true
        }
      }
    }
    if title == model.backButton {
      session.go(to: .permissions)
    } else if model.page == .permissions {
      session.go(to: .firstSteps)
    } else {
      close()
    }
    return true
  }

  private func render() {
    if let shown, model.isWorthComingForward(after: shown) { timesComeForward += 1 }
    shown = model
    onChange?()
  }
}

extension Harness {
  /// A Mac as it comes and an Arbor that has never run on it: macOS's own switches are on, nothing is saved, and unless `permitted` Arbor
  /// has no Accessibility permission. Does what `ArborApp` does at launch: without the permission the welcome window opens and Arbor
  /// waits; with it Arbor starts, and the window opens because nobody has seen it. Open the windows first.
  public func launchForTheFirstTime(permitted: Bool = false) {
    controller.isFirstLaunch = true
    controller.systemFacts = { [unowned self] in
      SystemFacts(
        accessibility: self.controller.accessibilityGranted, screenRecording: false, switches: self.mac.on, separateSpaces: true,
        inputSources: 1, eventTaps: self.controller.isRunning ? ["pinch", "scroll", "rectangle"] : [])
    }
    _ = welcome
    controller.accessibilityGranted = permitted
    if permitted { startAsTheAppDoes() } else { welcome.show(nil) }
  }

  /// The switch under Privacy & Security → Accessibility is flipped. The app notices within a second and starts the controller.
  public func permissionArrives() {
    guard !controller.isRunning else { return }
    controller.accessibilityGranted = true
    startAsTheAppDoes()
    welcome.tick()
  }

  private func startAsTheAppDoes() {
    start()
    controller.registeredBindings = controller.activeBindings
    if let page = controller.pageToWelcomeOn() { welcome.show(page) }
  }
}
