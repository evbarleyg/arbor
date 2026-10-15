import ArborCore
import Foundation

/// Keys follow the keyboard, gestures follow the pointer (docs/features/F56-keys-follow-the-keyboard.md).
///
/// Camera commands name no display, and `in` names no window. `InputLead` (ArborCore) decides whether
/// the pointer or the keyboard chooses for them; this file gives it what it needs to know and turns
/// its answer into a display and a space.
extension Controller {
  /// What the decision rests on. One stored property of the controller.
  struct Following {
    /// Where the command being performed came from. Whoever calls `perform(_:)` without saying
    /// is taken for a script.
    var source: CommandSource = .script
    /// Whether a command is being performed, as opposed to a question being asked: see `currentLead()`.
    var decides = false
    var lead = InputLead()
    /// What the keyboard focus last went to (nil: nothing Arbor knows), and when.
    var focus: (window: WindowID?, since: Date)?
    /// Set once Controller+Peek.swift has its observer in place.
    var watchesLifecycleForPeek = false
    /// Where the last peek landed and where it had come from (Controller+Peek.swift).
    var peekLanding: (display: DisplayID, space: NodeID, origin: NodeID)?
    /// The value of `stepInToward` that was last reported as unreadable.
    var reportedRule: String?
  }

  /// Runs a command for a shortcut, the menu, a gesture, `arborctl` or a URL. Commands that have to choose a
  /// display or a direction care which, and so does what Arbor says on screen afterwards (Controller+HeadsUp.swift).
  @discardableResult
  public func perform(_ command: Command, from source: CommandSource) -> CommandResult {
    perform(command, from: source, inTraces: source)
  }

  /// Whoever does not say who they are is taken for a script. A trace holds that nothing was said.
  @discardableResult
  public func perform(_ command: Command) -> CommandResult { perform(command, from: .script, inTraces: nil) }

  private func perform(_ command: Command, from source: CommandSource, inTraces recorded: CommandSource?) -> CommandResult {
    traced(command, from: recorded) { from(source) { executeAndSay(command, from: source) } }
  }

  /// Does `body` as something that came from `source`.
  func from<Result>(_ source: CommandSource, _ body: () -> Result) -> Result {
    let outer = following.source
    following.source = source
    defer { following.source = outer }
    return body()
  }

  /// Does `body` as a command does, if `decides`: what it follows is remembered. `execute` sees to that for every
  /// command that is not a query; this is for a peek's press, which performs nothing, and for whoever only asks.
  func deciding<Result>(_ decides: Bool, _ body: () -> Result) -> Result {
    let outer = following.decides
    following.decides = decides
    defer { following.decides = outer }
    return body()
  }

  /// The display a command from `source` that names none would act on now. For whoever shows it: asking changes nothing.
  public func displayForCommands(from source: CommandSource) -> DisplayID? {
    deciding(false) { from(source) { commandDisplayID() } }
  }

  /// Called whenever the keyboard may have moved (`keyboardFocusMoved()`, where every `windowFocused` ends up too).
  /// The reports only say when to look: an app in the background reports focus changes as well, another app
  /// coming forward moves the keyboard with no report, some changes are reported twice, and Arbor's own
  /// `focus` calls are reported back. A window that already had the keyboard is no change. `window` is what the window system
  /// answered just now.
  func noteFocus(_ window: WindowID?) {
    confirmFocusRequest(at: window)
    if let focus = following.focus, focus.window == window { return }
    following.focus = (window, now())
    following.lead.focusChanged()
  }

  /// Whether the command being performed follows the pointer or the keyboard.
  ///
  /// `cameraDisplay()` and `commandDisplayID()` read like questions, and menus, captions and queries ask them. Only a
  /// command's answer is remembered. Were a question's, a menu that was merely opened (its items follow the pointer)
  /// would turn the next shortcut toward the pointer, and no trace would say why.
  func currentLead() -> InputLead.Lead {
    let activity = system.inputActivity()
    let focusIdle = following.focus.map { now().timeIntervalSince($0.since) } ?? .infinity
    guard following.decides else {
      return following.lead.answer(
        for: following.source, rule: stepInTowardRule(), activity: activity, focusIdle: focusIdle)
    }
    let before = following.lead.last
    let lead = following.lead.lead(for: following.source, rule: stepInTowardRule(), activity: activity, focusIdle: focusIdle)
    if lead != before {
      Log.debug(
        "commands follow the \(lead.rawValue): a \(following.source.rawValue), pointer idle "
          + "\(Self.seconds(activity.pointerIdle)), keys \(Self.seconds(activity.keyboardIdle)), "
          + "focus \(Self.seconds(focusIdle))")
    }
    return lead
  }

  /// The focused window and its display, if Arbor arranges it.
  var focusedPlace: (window: WindowID, display: DisplayID)? {
    // `keyboardFocus()`: a command may have sent the keyboard to another display a moment ago, and macOS not be there yet.
    guard let window = keyboardFocus(), isManaged(window), let display = workspaceID(containing: window)
    else { return nil }
    return (window, display)
  }

  /// The display a camera command acts on. The focused window says which even if Arbor does not arrange it (a
  /// call in an app set to Don't Arrange): whoever types there is looking at that display. With no
  /// focused window the pointer decides.
  func commandDisplayID() -> DisplayID? {
    if currentLead() == .keyboard, let display = focusedDisplayID { return display }
    return pointerDisplayID
  }

  /// The display the focused window is on: its workspace's, or for a window Arbor does not arrange the one it sits on.
  var focusedDisplayID: DisplayID? {
    if let place = focusedPlace { return place.display }
    guard let window = system.focusedWindow(), let frame = windows[window]?.frame else { return nil }
    return displayID(at: frame.center)
  }

  /// The setting, read. A value nobody defined means `auto`, and is reported once.
  func stepInTowardRule() -> StepInToward {
    let text = settings.stepInToward
    if StepInToward(rawValue: text.lowercased()) == nil, following.reportedRule != text {
      following.reportedRule = text
      let values = StepInToward.allCases.map(\.rawValue).joined(separator: ", ")
      Log.error("settings.json: stepInToward is none of \(values); using auto")
    }
    return StepInToward(setting: text)
  }

  /// Where `in` goes when it steps toward the focused window: the space inside `camera` that holds it,
  /// or the Desktop if it floats. Nil when `in` follows the pointer, or the window is not inside `camera`.
  func stepTowardFocus(from camera: NodeID, on display: DisplayID, in view: TreeView) -> NodeID? {
    let rule = stepInTowardRule()
    guard InputLead.stepsTowardFocus(lead: currentLead(), source: following.source, rule: rule),
      let place = focusedPlace, place.display == display
    else { return nil }
    return Navigation.stepIn(
      from: camera, toward: view.tree.leaf(containing: place.window) ?? view.tree.desktop, in: view)
  }

  private static func seconds(_ value: Double) -> String {
    value.isFinite && value < 86_400 ? "\((value * 10).rounded() / 10) s" : "for ever"
  }
}
