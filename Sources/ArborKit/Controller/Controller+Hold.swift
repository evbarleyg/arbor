import ArborCore
import CoreGraphics
import Foundation

/// Holding the view (docs/features/F58-hold-the-view.md): for calls, shared screens and recordings, where
/// nothing may jump or appear that the person at the Mac did not ask for.
///
/// Three things move the view uninvited: an app that brings itself forward has its window revealed, a
/// rule docks a new window and the view makes room, and a slipped key or pinch zooms out over
/// everything. There are two strengths:
///
/// - `hold still` stops the first two. The user's own keys, clicks and gestures work as ever. It also
///   starts by itself during a call: while a window listed in `holdStillFor` is open, or a camera or a
///   microphone is on.
/// - `hold` stops all three: the view stays exactly where it is, on every display, until `release`.
///
/// It is the opposite of a pause (Controller+Pause.swift), which lets go of everything and brings **every**
/// window into view: the last thing wanted in front of an audience. Held, Arbor keeps arranging; windows that
/// are out of view stay there.
///
/// macOS has no public way to ask whether the screen is being shared or recorded, which is why `hold` is a
/// mode to choose, and only calls are something Arbor notices.
///
/// Anything new that moves the view or a window **without being asked** (a timer, a window event, a rule) must
/// check `isHeld` first. New commands are refused by `hold` until `Command.isAllowedWhileHeld` lists them.
extension Controller {
  struct Hold {
    /// What `hold` or `hold still` asked for.
    var chosen: HoldLevel?
    /// The sign of a call there is now, in words that follow "while": "Zoom is open", "the camera is on".
    var caller: String?
    /// The user released during that call. Arbor does not start again until it is over.
    var callerDismissed = false
    /// When the view was last not held at all.
    var since = Date.distantPast
    /// When what was chosen ends by itself, if it does.
    var until: Date?
    /// Windows a rule would have docked, in the order they opened. They float until the hold ends.
    var putOff: [(window: WindowID, rule: AppRule)] = []
    /// Windows that opened right after a click or a modifier key.
    var openedByTheUser: Set<WindowID> = []
    /// Floating windows that opened off screen and are not let in, not even onto a Desktop that is in view. They
    /// outlive the hold: they come in when the view next moves (`holdLetsInWhatWaited`).
    var keptOut: Set<WindowID> = []
    /// The window system was told to leave dialogs that open out of view where they are. The same.
    var dialogsWait = false
    /// The window in view that last had the keyboard, arranged by Arbor or not. It gets it back.
    var home: WindowID?
    /// What each display's view takes in, as of its last layout. Nothing else may come in.
    var fences: [DisplayID: Fence] = [:]
    /// The displays that show nothing, because nothing of what their view may show takes up room now.
    var empty: Set<DisplayID> = []
    /// settings.json was saved while the view was held. It is read when the view is let go.
    var settingsFileWaits = false
    /// The window whose focus report came right after a click or a modifier key.
    var askedFor: WindowID?
    /// The window the person asked for by name (`holdNotesRequest`), and until when its focus reports count as asked for.
    var requested: (window: WindowID, until: Date)?
    /// The window last sent away from the keyboard, how often, since when, and when last.
    var sentBack: (window: WindowID, times: Int, since: Date, last: Date)?
    /// The keyboard was asked back and it is not yet known whether it came (`holdLooksAgain`).
    var isSendingBack = false
    /// The apps of which it has been said on screen, during this hold, that they were turned away.
    var saidOf: Set<String> = []
  }

  /// The docked windows of the space a held view is on, showing or not (tabs, tiles, minimized), and
  /// whether the Desktop, and so the floating windows on it, is part of it.
  struct Fence: Equatable {
    var windows: Set<WindowID>
    var desktop: Bool
  }

  /// A focus change this soon after a click or a modifier key counts as the user's own doing: a Dock or
  /// notification click, or letting go of ⌘ after ⌘Tab. Reports arrive within 0.1 s of either on a real Mac
  /// (collab/evidence/ax-events.txt); an app that comes forward by itself rarely picks that moment.
  static let askedWithin = 0.5
  /// A window asked for by name can be on another macOS Space. macOS slides over to it first, which takes most of a second, and only
  /// then reports that it has the keyboard, after reports about whatever had it there before.
  static let requestLasts: TimeInterval = 2
  /// An app that takes the keyboard again and again is sent back this often within `fightSpan` seconds, then
  /// left with it. The view still does not move. Arbor never fights an app for long.
  static let fightLimit = 3
  static let fightSpan: TimeInterval = 5
  /// One arrival is reported two or three times within 0.04 s (the window, its app, the window again), and
  /// macOS takes about as long to give the keyboard back once asked. Within this span it is all one event.
  static let arrivalSpan: TimeInterval = 0.2

  /// A camera or microphone that goes off counts as off after this long. Changing devices in the middle of a call
  /// switches one off before the other is on.
  static let callOverDelay = 5.0

  /// Why a key did nothing, and the way out in the same breath, for someone at the Mac as well as at a terminal.
  var heldMessage: String {
    let bindings = KeyBindings.effective(settings: settings).bindings
    // The key that pauses lets go of the hold first (`holdAnswers`), so there is one unless the user took it away.
    let commands: [Command] = [.toggleHold, .release, .togglePause, .pause(minutes: nil)]
    let keys = settings.hotkeysEnabled ? commands.compactMap { KeyBindings.label(for: $0, in: bindings) }.first : nil
    return "the view is held; release it " + (keys.map { "with \($0), " } ?? "") + "from Arbor's menu or with `release`"
  }

  /// What to do about an edge or a neighbour that is not in view, after "…".
  var adviceToStepOut: String { holdLevel == .view ? ", and \(heldMessage)" : "; step out first" }

  /// How firmly the view is held now, or nil.
  public var holdLevel: HoldLevel? {
    hold.chosen ?? (hold.caller != nil && !hold.callerDismissed ? .still : nil)
  }

  /// Whether Arbor may move the view or a window only when asked.
  public var isHeld: Bool { holdLevel != nil }

  /// Whether a panel or window of Arbor's that the person **asked for** may be shown (Go to…, the minimap on demand, the
  /// shortcuts, a welcome or update window). Not on a held view: what the audience sees stays as it is. Commands
  /// are refused anyway until `Command.isAllowedWhileHeld` lists them; this is for whatever is not a command.
  public var mayShowPanels: Bool { holdLevel != .view }

  /// Whether Arbor may put something on screen **by itself** (a hint, the minimap after a move, a message that is not
  /// the reason why a key did nothing) or make a sound. Not during a call either.
  public var mayShowUnasked: Bool { !isHeld }

  /// The displays whose held view has nothing in it now: all of it is minimized, hidden, closed or away.
  public var displaysHeldEmpty: Set<DisplayID> { hold.empty }

  // MARK: Commands

  func hold(_ level: HoldLevel, minutes: Double?) -> CommandResult {
    if level == .view, holdLevel != .view, workspaces.keys.allSatisfy({ heldWindows(on: $0).isEmpty }) {
      return .failure("there is nothing in view to hold")
    }
    let before = holdLevel
    hold.chosen = level
    holdChanged(from: before)
    // A second `hold` replaces the first one's end.
    scheduler.cancel("release")
    hold.until = minutes.map { now().addingTimeInterval($0 * 60) }
    if let minutes {
      scheduler.schedule("release", after: minutes * 60) { [weak self] in _ = self?.release() }
    }
    let end = minutes.map { "for \(Self.minutesText($0))" } ?? "until `release`"
    switch level {
    case .view: return .success("holding this view \(end)")
    case .still: return .success("holding still \(end): the view moves only when you ask")
    }
  }

  func release() -> CommandResult {
    guard isHeld else { return .failure("the view is not held") }
    let before = holdLevel
    scheduler.cancel("release")
    if hold.chosen != nil { hold.chosen = nil } else { hold.callerDismissed = true }
    hold.until = nil
    let floating = holdChanged(from: before)
    if isHeld, let caller = hold.caller {
      return .success("released; still holding still while \(caller) (`release` again ends that too)")
    }
    return .success("released" + leftFloatingNote(floating))
  }

  /// "; Terminal was left floating". Apps, never titles.
  private func leftFloatingNote(_ left: [WindowID]) -> String {
    var names: [String] = []
    for name in left.compactMap({ windows[$0]?.appName }) where !names.contains(name) { names.append(name) }
    guard let last = names.last else { return "" }
    if left.count == 1 { return "; \(last) was left floating" }
    if names.count == 1 { return "; \(left.count) \(last) windows were left floating" }
    return "; \(names.dropLast().joined(separator: ", ")) and \(last) were left floating"
  }

  func toggleHold() -> CommandResult {
    holdLevel == .view ? release() : hold(.view, minutes: nil)
  }

  /// Called by `perform` before anything else. Pausing and floating everything are ways out of a hold, and both bring
  /// every window into view. From the menu or a terminal that is a choice; on a key it can be a slip, in front of an
  /// audience. So the key that pauses lets go of the hold first, which moves nothing, and of everything at the next
  /// press; the key that floats everything is refused like the others.
  func holdAnswers(_ command: Command) -> CommandResult? {
    guard holdLevel == .view, following.source == .shortcut else { return nil }
    switch command {
    case .pause, .togglePause:
      let result = release()
      return result.ok && !isHeld ? .success(result.message + "; the same key again pauses Arbor") : result
    case .floatAll, .floatAllHere:
      Log.debug("\(command.textWhenRefused) failed: \(heldMessage)")
      return .failure(heldMessage)
    default:
      return nil
    }
  }

  /// Called for every shortcut that goes down or comes up, before it runs. True for a press that is only the key that
  /// released the hold still being down: a slip that lasts must not go on to pause.
  func holdIgnores(_ binding: KeyBinding, _ phase: KeyPhase) -> Bool {
    if let chord = keyThatReleasedTheHold {
      if phase == .pressed, binding.chord == chord, system.isHolding(chord) { return true }
      keyThatReleasedTheHold = nil
    }
    guard phase == .pressed, holdLevel == .view else { return false }
    switch binding.command {
    case .pause, .togglePause: keyThatReleasedTheHold = binding.chord  // as in `holdAnswers`
    default: break
    }
    return false
  }

  /// Whether `command` would be refused now, for a menu: an item that only beeps is a riddle. Changes nothing and logs nothing.
  func holdWouldRefuse(_ command: Command) -> Bool {
    guard holdLevel == .view, !command.bringsEverythingIntoView else { return false }
    return !command.isAllowedWhileHeld || command.arrangedWindows.compactMap({ $0 ?? system.focusedWindow() }).contains(where: isOutOfView)
      || holdWouldLetSomethingIn(command)
  }

  /// Called by `perform` for every command, before anything else but `holdAnswers`. The reason the command may not
  /// run now, or nil.
  func refusalWhileHeld(_ command: Command) -> CommandResult? {
    switch command {
    case .floatAll, .floatAllHere:
      // "Back to a normal Mac" is a way out. What rules were waiting to dock stays floating too.
      if hold.chosen != nil {
        let before = holdLevel
        scheduler.cancel("release")
        hold.chosen = nil
        hold.until = nil
        hold.putOff.removeAll()
        holdChanged(from: before)
      }
      // Everything comes into view, also on a display where nothing is docked, which `float-all` does not lay out. `float-all here`
      // is about one display: what waits there comes in, the rest goes on waiting. Also when the hold is over already.
      holdFetchesWhatWaited(on: command == .floatAll ? nil : cameraDisplay()?.0)
      return nil
    case .showAll, .home, .desktop:
      // Somebody asks for everything, or for the Desktop, and nothing is held. What a hold kept out waits for the view of its
      // display to move (`holdLetsInWhatWaited`), and the view may be there already: where nothing is docked it always is.
      // On every display, wherever the pointer is: whoever misses a window does not know which display it waits on.
      if holdLevel == nil { holdFetchesWhatWaited(on: nil) }
    default:
      break
    }
    guard holdLevel == .view else { return nil }
    var refusal: CommandResult?
    if !command.isAllowedWhileHeld {
      refusal = .failure(heldMessage)
    } else if let window = command.arrangedWindows.compactMap({ $0 ?? system.focusedWindow() }).first(where: isOutOfView) {
      refusal = .failure("\(window) is out of view, and \(heldMessage)")
    } else if holdWouldLetSomethingIn(command) {
      refusal = .failure("that would bring windows that are out of view into it, and \(heldMessage)")
    }
    if let refusal { Log.debug("\(command.textWhenRefused) failed: \(refusal.message)") }
    return refusal
  }

  /// Quitting and pausing end a hold without more ado: nothing is docked on the way out.
  func forgetHold() {
    scheduler.cancel("release")
    scheduler.cancel("call-over")
    if hold.settingsFileWaits { settingsFileMayHaveChanged() }
    hold = Hold()
    system.leaveStrayDialogs(false, exceptOfApp: nil)
  }

  /// Called when settings.json has changed on disk. A new gap resizes everything, and a shorter list of excluded apps
  /// brings windows in: like `reload-settings` and `set`, the file waits for the view to be let go.
  func holdPutsOffTheSettingsFile() -> Bool {
    guard holdLevel == .view else { return false }
    hold.settingsFileWaits = true
    Log.info("hold: settings.json has changed; it is read when the view is released")
    return true
  }

  /// Returns the windows whose rule waited for the end of the hold and was not applied after all.
  @discardableResult
  private func holdChanged(from before: HoldLevel?) -> [WindowID] {
    let level = holdLevel
    guard level != before else { return [] }
    if before == nil {
      hold.home = system.focusedWindow().flatMap { isOutOfView($0) ? nil : $0 }
      hold.since = now()
    }
    let empty = hold.empty.intersection(workspaces.keys)
    hold.empty.removeAll()
    if hold.settingsFileWaits, level != .view {
      hold.settingsFileWaits = false
      settingsFileMayHaveChanged()
    }
    hold.fences.removeAll()
    if level == .view {
      // What is seen is what is held. That is not where the view is if the window it is on was hidden, minimized or on another macOS
      // Space already: then the nearest space around it that has something in it shows.
      for (display, workspace) in workspaces { hold.fences[display] = fence(around: shownNode(of: workspace), of: workspace) }
    }
    Log.info("hold: \(before?.rawValue ?? "none") → \(level?.rawValue ?? "none")")
    // What is up already comes down: the minimap draws the whole arrangement, what is out of view with it. On a held view everything of
    // Arbor's does, the field for a space's name with it; a call that begins takes nothing away that the person has just asked for but that.
    if level != nil { hideMinimaps() }
    if level == .view {
      hideCheatSheet()
      hideHeadsUp()
      closeNamePrompt()
    }
    // F47 moves a dialog that opened beside a window out of view to the middle of the display: an alert of the mail
    // app, in front of the audience. On a held view it waits. Holding still it does not: a call can last an hour, the
    // person can go to that app meanwhile, and an app whose dialog cannot be found looks hung.
    if level == .view {
      hold.dialogsWait = true
      system.leaveStrayDialogs(true, exceptOfApp: appInUse)
    }
    // A view with nothing in it has to go somewhere now.
    for display in empty.sorted() { relayout(display, reason: .structure) }
    var leftFloating: [WindowID] = []
    if level == nil {
      let putOff = hold.putOff
      let (caller, dismissed, keptOut, dialogsWait) = (hold.caller, hold.callerDismissed, hold.keptOut, hold.dialogsWait)
      hold = Hold()
      (hold.caller, hold.callerDismissed, hold.keptOut, hold.dialogsWait) = (caller, dismissed, keptOut, dialogsWait)
      for (window, rule) in putOff {
        // Only windows that are still as the rule would have found them.
        guard isManaged(window), let display = workspaceID(containing: window),
          workspaces[display]?.isFloating(window) == true, let index = settings.newWindowRules.firstIndex(of: rule)
        else { continue }
        // The end of a hold moves the view no more than the hold did: it can come by itself, when the time is up or the
        // call is over, with the screen still shared.
        // A window that opened off screen and was kept out is not in view, so docking it there would bring it in.
        guard !isOutOfView(window), appPlacedFrames[window] == workspaces[display]?.floating[window],
          keepsTheView(rule, for: window, on: display)
        else {
          Log.info("hold: \(window) goes on floating; its rule (\(rule.action.text)) would move the view, or the user has moved the window")
          leftFloating.append(window)
          continue
        }
        apply(ruleAt: index, to: window)
      }
      if !putOff.isEmpty { scheduleSave() }
    }
    notify(.hold)
    // An app Arbor pauses for may have come to the front meanwhile (Controller+PassThrough.swift).
    if before == .view { followFrontmostApp() }
    return leftFloating
  }

  /// Whether docking `id` as `rule` says would leave `display`'s view showing what it shows now and `id`, which floats
  /// over it already. Follows `apply(ruleAt:to:)`; an action that is not listed here waits in vain.
  private func keepsTheView(_ rule: AppRule, for id: WindowID, on display: DisplayID) -> Bool {
    guard let workspace = workspaces[display] else { return false }
    let target: DropTarget
    switch rule.action {
    case .dock(let edge):
      target = .cameraEdge(edge)
    case .dockBeside(let app, let edge):
      let leaf = recentlyFocusedDockedWindow(of: app, on: display, except: id).flatMap { workspace.tree.leaf(containing: $0) }
      target = leaf.map { .beside($0, edge) } ?? .cameraEdge(edge)
    case .dockAuto:
      // F23 sees to it itself: its plan takes no place after which the view shows anything but what it showed and the new window, and
      // lets the window float otherwise. It settles the place in rounds with the window, which cannot be rehearsed on a copy.
      return true
    default:
      return false
    }
    var rehearsal = workspace
    rehearsal.dock(id, at: target, shareSpace: settings.shareRemovedSpace)
    // Both where the view is and what it shows. They differ while what the view is on takes up no room: minimized, or
    // on another macOS Space, where "what it shows" is everything or nothing and proves nothing.
    var (viewed, shown) = (fence(around: workspace.camera, of: workspace), fence(around: shownNode(of: workspace), of: workspace))
    viewed.windows.insert(id)
    shown.windows.insert(id)
    return fence(around: rehearsal.camera, of: rehearsal) == viewed && fence(around: shownNode(of: rehearsal), of: rehearsal) == shown
  }

  // MARK: Calls

  /// Starts and ends holding still as the signs of a call come and go. Called when a window opens, closes or
  /// changes its title, when a camera or microphone goes on or off, when settings change, and at launch.
  /// Minimized and hidden windows and those on another macOS Space count: the call goes on.
  func refreshHoldCaller() {
    guard isRunning else { return }
    let patterns = settings.holdStillFor.map(HoldPattern.init)
    var caller =
      patterns.isEmpty
      ? nil
      : windows.values.sorted { $0.id < $1.id }.first { window in
        patterns.contains { $0.matches(bundleID: window.bundleID, title: window.title) }
      }.map { "\($0.appName) is open" }
    if caller == nil, settings.holdStillWhileCameraIsOn, callSignals.cameraIsOn { caller = "the camera is on" }
    if caller == nil, settings.holdStillWhileMicrophoneIsOn, callSignals.microphoneIsOn { caller = "the microphone is on" }
    guard caller != hold.caller else { return }
    let before = holdLevel
    hold.caller = caller
    if caller == nil { hold.callerDismissed = false }
    holdChanged(from: before)
  }

  /// The app reports what it reads from macOS (App/CallSensor.swift). Whether it matters is decided here.
  public func callSignalsChanged(_ signals: CallSignals) {
    traced("callSignalsChanged", [signals.cameraIsOn, signals.microphoneIsOn]) {
      callSignals = signals
      scheduler.cancel("call-over")
      // Only what is switched on in the settings: a microphone that does not count must not cut the wait short.
      if signals.cameraIsOn && settings.holdStillWhileCameraIsOn || signals.microphoneIsOn && settings.holdStillWhileMicrophoneIsOn {
        refreshHoldCaller()
      } else {
        scheduler.schedule("call-over", after: Self.callOverDelay) { [weak self] in self?.refreshHoldCaller() }
      }
    }
  }

  // MARK: The keyboard

  /// Whether Arbor arranges `id` and it is not showing: outside the view, inside a tile, or a tab behind another.
  func isOutOfView(_ id: WindowID) -> Bool {
    guard isManaged(id), let display = workspaceID(containing: id) else { return false }
    if parked.contains(id) { return true }
    return workspaces[display]?.isDocked(id) == true && layouts[display]?.windowFrames[id] == nil
  }

  /// Called for every focus report, as it arrives.
  func holdNotesFocus(of id: WindowID) {
    guard isRunning, isHeld else { return }
    let seconds = system.secondsSinceClickOrModifierKey()
    Log.debug("hold: focus report for \(id), \(seconds) s after the last click or modifier key")
    let wasRequested = hold.requested.map { $0.window == id && now() < $0.until } ?? false
    // A report nobody asked for unsays only what was said of its own window. One from an app in the background, between ⌘Tab and the
    // moment the view follows, is about another.
    if wasRequested || seconds <= Self.askedWithin { hold.askedFor = id } else if hold.askedFor == id { hold.askedFor = nil }
    if system.focusedWindow() == id, !isOutOfView(id) {
      let before = appInUse
      hold.home = id
      if hold.dialogsWait, appInUse != before { system.leaveStrayDialogs(true, exceptOfApp: appInUse) }
      // The keyboard is back in view: whoever takes it from here arrives anew.
      hold.sentBack?.last = .distantPast
    }
  }

  /// Called when the person has asked for `id` by name (Go to…: `find`, `reveal`, a row chosen in the palette). Holding still lets
  /// through what they do themselves and goes by clicks and modifier keys, and Return in a palette is neither.
  func holdNotesRequest(for id: WindowID) {
    guard holdLevel == .still else { return }
    hold.askedFor = id
    hold.requested = (id, now().addingTimeInterval(Self.requestLasts))
  }

  /// Called when the view is about to follow the keyboard to `id`. True if it must not: `id` stays out
  /// of view, and the keyboard goes back to the window that had it. Typing into a window nobody can
  /// see is worse than losing a switch that can be made again after `release`.
  func holdTurnsAway(_ id: WindowID, lookingAgain: Bool = false) -> Bool {
    guard let level = holdLevel, isOutOfView(id) else { return false }
    // It has had the keyboard all along, in view: no app that pushed itself forward. Its display went, and it arrives out of view, or counts as
    // out of view until it has been laid out (`updateDisplays`). Holding still the view follows it, as without a hold. A held view does
    // not move, so there it keeps the keyboard only if it lands in that view.
    if hold.home == id, system.focusedWindow() == id, level == .still || landsInView(id) { return false }
    if level == .still, hold.askedFor == id {
      // The view follows it, so this is the window in view that has the keyboard. Its report came before it was in view.
      hold.home = id
      if hold.requested?.window == id { hold.requested = nil }
      return false
    }
    let now = self.now()
    if level == .still, let request = hold.requested, now < request.until {
      // On the way to a window that was asked for by name, perhaps on another macOS Space. Whatever has the keyboard in passing is not
      // followed, and not sent away either: asked back to the window that had it, macOS would slide back to the Space just left.
      // If it is still there when the asking has lapsed, it is dealt with then.
      hold.sentBack = (id, 0, now, now)
      scheduler.schedule("focus-held", after: request.until.timeIntervalSince(now)) { [weak self] in self?.holdLooksAgain() }
      return true
    }
    if let last = hold.sentBack, last.window == id, now.timeIntervalSince(last.since) < Self.fightSpan {
      guard lookingAgain || now.timeIntervalSince(last.last) >= Self.arrivalSpan else { return true }
      guard last.times < Self.fightLimit else {
        Log.info("hold: \(id) keeps taking the keyboard; leaving it there, out of view")
        return true
      }
      hold.sentBack = (id, last.times + 1, last.since, now)
    } else {
      hold.sentBack = (id, 1, now, now)
    }
    Log.info("hold: \(id) took the keyboard out of view; sending it back")
    if level == .still { holdSaysThatItTurnedAway(id) }
    hold.isSendingBack = true
    scheduler.schedule("focus-held", after: Self.arrivalSpan) { [weak self] in self?.holdLooksAgain() }
    if let home = hold.home, windows[home]?.isPresent == true, !isOutOfView(home) {
      system.focus(home)
    } else if let display = displayWithSomethingInView(preferring: workspaceID(containing: id)) {
      ensureFocusIsVisible(on: display)
    }
    return true
  }

  /// Whether a layout made now would show `id`, whatever is on record about where it is.
  private func landsInView(_ id: WindowID) -> Bool {
    guard let display = workspaceID(containing: id), let workspace = workspaces[display], let fresh = freshLayout(of: display) else { return false }
    return fresh.windowFrames[id] != nil || (workspace.isFloating(id) && fresh.desktopFrame != nil)
  }

  /// Holding still goes by time and can be wrong: a launcher, `open` in a terminal, or a link whose browser takes more than half a second
  /// are the person's own doing and are turned away like a chat that pushes itself forward. Never in silence: the second try would
  /// end the same, and nothing would say why. Once for each app and hold. Not on a held view, where nothing of Arbor's appears
  /// but the reason why a key did nothing.
  private func holdSaysThatItTurnedAway(_ id: WindowID) {
    guard settings.messageLevel != .off, let window = windows[id], let display = workspaceID(containing: id),
      hold.saidOf.insert(window.bundleID ?? window.appName).inserted
    else { return }
    let ways = ["⌘Tab"] + [shortcutLabel(for: .find(nil))].compactMap { $0 }
    showHeadsUp(
      HeadsUpModel(
        kind: .problem, text: "\(window.appName) is out of view: holding still", hint: "\(ways.joined(separator: " or ")) goes there"),
      on: display)
  }

  /// Reports within `arrivalSpan` are one arrival, so nothing is done about them. But an app can take the keyboard a moment
  /// *after* Arbor asked it back: a new window is activated once it is up. Then what is typed goes to a window nobody sees, and
  /// no further report says so. So once the span is over Arbor looks where the keyboard is, and sends it back again, as
  /// often as `fightLimit` allows.
  private func holdLooksAgain() {
    hold.isSendingBack = false
    if let last = hold.sentBack, system.focusedWindow() == last.window { _ = holdTurnsAway(last.window, lookingAgain: true) }
    // Left where it is, out of view, there is no window to draw the line around.
    keyboardFocusMoved()
  }

  /// The window to show as having the keyboard. While one that was turned away is on its way out, that is still
  /// the window the keyboard is going back to, so that the line around it does not blink on a shared screen.
  func windowShownAsFocused() -> WindowID? {
    let focused = system.focusedWindow()
    guard isHeld, hold.isSendingBack, let focused, hold.sentBack?.window == focused, let home = hold.home else { return focused }
    return home
  }

  private func displayWithSomethingInView(preferring preferred: DisplayID?) -> DisplayID? {
    let order = [pointerDisplayID, preferred].compactMap { $0 } + workspaces.keys.sorted()
    return order.first { display in
      guard let workspace = workspaces[display] else { return false }
      return layouts[display]?.windowFrames.isEmpty == false
        || workspace.floating.keys.contains { !parked.contains($0) && windows[$0]?.isPresent == true }
    }
  }

  // MARK: Rules

  /// Called for every window that opens, before its rule is looked up.
  func holdNotesNewWindow(_ id: WindowID) {
    guard isHeld, system.secondsSinceClickOrModifierKey() <= Self.askedWithin else { return }
    hold.openedByTheUser.insert(id)
  }

  /// Whether `rule` has to wait for the hold to end. Docking makes the windows in view give up room, and
  /// can widen the view. Holding still, a window that opened right after a click or a modifier key (⌘N) is
  /// the user's own doing, like a switch of apps, and is docked at once, or when its title has arrived.
  func holdPutsOff(_ rule: AppRule, for id: WindowID) -> Bool {
    guard let level = holdLevel else { return false }
    if level == .still, hold.openedByTheUser.contains(id) { return false }
    switch rule.action {
    case .dock, .dockBeside, .dockAuto:
      // A late title can bring a better rule into play: the last one counts.
      hold.putOff.removeAll { $0.window == id }
      hold.putOff.append((id, rule))
      Log.info("hold: \(id) floats; its rule (\(rule.action.text)) waits for `release`")
      return true
    default:
      return false
    }
  }

  /// Whether a window that opened mostly off screen, beside its app's window that is out of view, stays out of view
  /// instead of being brought to the middle of the display. Holding still, one the user opened is brought in.
  func holdLeavesOutOfView(_ id: WindowID) -> Bool {
    guard let level = holdLevel, let window = windows[id] else { return false }
    if level == .still, hold.openedByTheUser.contains(id) { return false }
    // That is why it opened there, and what makes it something from out of view. One that is merely larger than the display, or
    // whose app remembers a display that is gone, would have opened over the view like any new window, and only goes missing.
    let isOfTheSameApp: (WindowSnapshot) -> Bool = { window.bundleID != nil ? $0.bundleID == window.bundleID : $0.pid == window.pid }
    guard windows.values.contains(where: { $0.id != id && isOfTheSameApp($0) && isOutOfView($0.id) }) else { return false }
    Log.info("hold: \(id) opened off screen; it stays out of view")
    hold.keptOut.insert(id)
    return true
  }

  /// Whether a layout must leave the floating window `id` in its corner although the Desktop is in view. Not one that is pinned or
  /// summoned: "always in view" is the person's own word about that window, and a call pinned by a rule is what they want to see
  /// during a call.
  func holdKeepsOut(_ id: WindowID) -> Bool { hold.keptOut.contains(id) && !staysInView(id) }

  /// Called when a rule has pinned `id`, which marks it and moves nothing (without a hold it would be in view already), and when somebody
  /// turns to `id` and the hold lets that pass: with the Desktop in view already no view has to move, so no move would let it in.
  func holdLetsIn(_ id: WindowID) {
    guard hold.keptOut.remove(id) != nil, let display = workspaceID(containing: id) else { return }
    relayout(display, reason: .structure)
  }

  /// Called by `relayout` when `display`'s view is about to move, which a held view's does not; with nil, when everything comes
  /// into view anyway. By the layout itself, not by a command that announces a move: it may make none, and then nothing
  /// would bring the windows in. And only by a layout that follows a move of the view, not one that follows an arrangement.
  /// What was kept out of view comes in with that, not with the end of the hold: the end can come by itself with the screen still shared, and an alert of the mail app in the
  /// middle of the display is no better then. Whoever goes to that app moves the view, so no dialog stays lost.
  /// Before the move and not after it: F47 helps a dialog only while a window of its app is still out of view.
  func holdLetsInWhatWaited(on display: DisplayID?) {
    // The other displays' go on waiting: nothing lays those out now.
    hold.keptOut = display.map { moved in hold.keptOut.filter { workspaceID(containing: $0) != moved } } ?? []
    guard hold.dialogsWait else { return }
    hold.dialogsWait = false
    system.leaveStrayDialogs(false, exceptOfApp: nil)
  }

  /// Lets in what waited on `display`, or with nil everywhere, and lays those displays out, whether or not a view moves.
  func holdFetchesWhatWaited(on display: DisplayID?) {
    let displays = Set(hold.keptOut.compactMap(workspaceID(containing:))).filter { display == nil || $0 == display }
    // Also with no window waiting: dialogs wait as well.
    holdLetsInWhatWaited(on: display)
    for display in displays.sorted() { relayout(display, reason: .structure) }
  }

  /// The app of the window in view that has the keyboard. Its dialogs never wait, not even on a held view: an alert over another
  /// window of it, which is out of view, stops it taking input, and the app being shown would look hung. Its Dock icon is
  /// no help, because it is in front already. Not simply the app in front: one that pushes itself forward together
  /// with its alert is in front too, and that is the alert to keep from an audience.
  private var appInUse: String? { hold.home.flatMap { windows[$0]?.bundleID } }

  /// Called when another app has come to the front. An app that is blocked on a dialog beeps at every click, so the person
  /// clicks its Dock icon. The keyboard then goes to the dialog, which Arbor does not arrange: no window's focus report
  /// follows and the view does not move. So going to an app brings in that app's dialogs; those of other apps go on
  /// waiting. Not on a held view, and holding still only if the person did it.
  func holdNotesActivation(of app: FrontmostApp?) {
    guard hold.dialogsWait, let app, holdLevel != .view else { return }
    if holdLevel == .still, system.secondsSinceClickOrModifierKey() > Self.askedWithin { return }
    system.bringInStrayDialogs(ofApp: app.bundleID)
  }

  // MARK: What is held

  /// The windows that take up room in the space `display` shows: docked ones, and floating ones if the
  /// Desktop is part of it. A window floating over a framed window is a visitor, not part of the space.
  func heldWindows(on display: DisplayID) -> Set<WindowID> {
    guard let workspace = workspaces[display] else { return [] }
    let shown = shownNode(of: workspace)
    var held = Set(workspace.tree.windows(under: shown))
    if workspace.tree.subtree(shown, contains: workspace.tree.desktop) {
      held.formUnion(workspace.floating.keys)
    }
    return held.intersection(presentWindowIDs())
  }

  /// Called when `id` has closed.
  func holdForgets(_ id: WindowID) {
    hold.putOff.removeAll { $0.window == id }
    hold.openedByTheUser.remove(id)
    hold.keptOut.remove(id)
    if hold.home == id { hold.home = nil }
    if hold.askedFor == id { hold.askedFor = nil }
    refreshHoldCaller()
  }

  // MARK: The fence

  // A view can only be on a node of the tree, and the tree flattens splits of the same axis. So "what was in
  // view, plus the window just docked at its edge" or "what was in view, minus the window just closed" is
  // sometimes not a node, and the view ends up on the whole row or column around it
  // (`Workspace.dock`, `Remap`). On a shared screen that shows everything the hold is there to keep out of sight.

  private func fence(around node: NodeID, of workspace: Workspace) -> Fence {
    Fence(windows: Set(workspace.tree.windows(under: node)), desktop: workspace.tree.subtree(node, contains: workspace.tree.desktop))
  }

  /// Whether `node` of `workspace` holds nothing but what `display`'s held view may show: what it took
  /// in at the last layout, and windows that are on screen anyway (a new window floating over the
  /// view, one dragged over from another display).
  private func isInsideFence(_ node: NodeID, of workspace: Workspace, on display: DisplayID) -> Bool {
    guard let fence = hold.fences[display] else { return true }
    if !fence.desktop, workspace.tree.subtree(node, contains: workspace.tree.desktop) { return false }
    return workspace.tree.windows(under: node).allSatisfy {
      fence.windows.contains($0) || (!parked.contains($0) && windows[$0]?.isPresent == true)
    }
  }

  /// The node a layout of `workspace` would fill the display with: where the view is or, if nothing there
  /// takes up room (all minimized, say), the nearest space around it that has something in it.
  private func shownNode(of workspace: Workspace) -> NodeID {
    let present = presentWindowIDs()
    return TreeView(tree: workspace.tree, isPresent: { present.contains($0) }).effectiveAncestor(of: workspace.camera)
  }

  /// Called at the start of every layout, which is where every change ends up whatever caused it. False if no window
  /// on the display may be moved. A held view never widens by itself:
  ///
  /// - The tree has changed so that the view takes in something that was out of view. The view narrows to
  ///   the largest part of it that does not, with the window that has the keyboard if possible. What the
  ///   user does is rehearsed first and refused (`holdWouldLetSomethingIn`), so in practice this is for windows that close.
  /// - Nothing of what the view may show takes up room: it is minimized, hidden, closed, in macOS's own full screen or on
  ///   another macOS Space. ⌘M, ⌘H and ⌘W are pressed without a thought, and laying out without the window would
  ///   bring its surroundings into view. The display shows the wallpaper, which gives nothing away, until the window
  ///   is back or the hold is released.
  func holdFences(_ display: DisplayID) -> Bool {
    guard holdLevel == .view, var workspace = workspaces[display], let view = treeView(display) else { return true }
    var isEmpty = false
    defer {
      if isEmpty {
        holdShowsNothing(on: display)
      } else {
        hold.empty.remove(display)
        let workspace = workspaces[display] ?? workspace
        hold.fences[display] = fence(around: shownNode(of: workspace), of: workspace)
      }
    }
    guard let candidates = partsTheFenceLetsShow(on: display) else { return true }
    let keyboard = system.focusedWindow().flatMap {
      workspace.tree.leaf(containing: $0) ?? (workspace.isFloating($0) ? workspace.tree.desktop : nil)
    }
    guard
      let part = candidates.first(where: { node in keyboard.map { workspace.tree.subtree(node, contains: $0) } ?? false })
        ?? candidates.max(by: { view.presentWindows(under: $0).count < view.presentWindows(under: $1).count })
    else {
      isEmpty = true
      return false
    }
    Log.info("hold: the view on \(display) would have widened to \(workspace.camera); keeping it on \(part)")
    workspace.moveCamera(to: part, record: false)
    workspaces[display] = workspace
    return true
  }

  /// Of what a layout of `display` would show now, the parts that its held view may show and that take up room. Nil if it
  /// may show all of it. Changes nothing.
  private func partsTheFenceLetsShow(on display: DisplayID) -> [NodeID]? {
    guard holdLevel == .view, let workspace = workspaces[display], let view = treeView(display) else { return nil }
    let shown = shownNode(of: workspace)
    guard !isInsideFence(shown, of: workspace, on: display) else { return nil }
    func parts(of node: NodeID) -> [NodeID] {
      isInsideFence(node, of: workspace, on: display) ? [node] : workspace.tree.children(of: node).flatMap(parts)
    }
    // The Desktop always takes up room, so if it was held it is one of them.
    return parts(of: shown).filter(view.isEffective)
  }

  /// What `display` should look like now if its held view has nothing in it, or nil if it has: no window, no tile, no gap
  /// handle. Worked out afresh, for `freshLayout(of:)` as well, which asks whether a layout was forgotten.
  func layoutOfAnEmptyHeldView(on displayID: DisplayID) -> Layout? {
    guard partsTheFenceLetsShow(on: displayID)?.isEmpty == true, let workspace = workspaces[displayID],
      let display = display(displayID)
    else { return nil }
    // The view is where it was; an ordinary layout would fall back on the nearest space around it that has something in it.
    var nothing = Layout(camera: workspace.camera, frame: display.visibleFrame)
    nothing.hiddenWindows = Set(workspace.tree.allWindows).intersection(presentWindowIDs())
    return nothing
  }

  /// Nothing is laid out on `display`, and Arbor draws nothing there. What is out of view is in its corner already.
  private func holdShowsNothing(on display: DisplayID) {
    refreshVisibleFrame(of: display)
    guard let nothing = layoutOfAnEmptyHeldView(on: display) else { return }
    if hold.empty.insert(display).inserted { Log.info("hold: nothing is in the view on \(display); it stays held") }
    guard layouts[display] != nothing else { return }
    layouts[display] = nothing
    overlays.update(display: display, scene: overlayScene(for: nothing, on: display))
    notify(.layout(display))
  }

  /// Whether `display`'s held view would take in something that is out of view if `change` were made.
  private func holdWouldLetSomethingIn(on display: DisplayID?, _ change: (inout Workspace) -> Void) -> Bool {
    guard holdLevel == .view, let display, var rehearsal = workspaces[display] else { return false }
    change(&rehearsal)
    return !isInsideFence(shownNode(of: rehearsal), of: rehearsal, on: display)
  }

  /// Whether `display`'s held view may show `trial`, an arrangement tried out during a drag (Controller+Reflow.swift). An audience
  /// watches the drag as well as its end.
  func holdLetsShow(_ trial: Workspace, on display: DisplayID) -> Bool {
    !holdWouldLetSomethingIn(on: display) { $0 = trial }
  }

  /// The same for dropping `id` on `target`.
  func holdWouldLetSomethingIn(dropping id: WindowID, on target: DropTarget, of display: DisplayID?) -> Bool {
    guard holdLevel == .view else { return false }
    let source = workspaceID(containing: id)
    let shareSpace = settings.shareRemovedSpace
    if source != display, holdWouldLetSomethingIn(on: source, { $0.forget(id, shareSpace: shareSpace) }) { return true }
    return holdWouldLetSomethingIn(on: display) { workspace in
      switch target {
      case .none: break
      case .float: workspace.forget(id, shareSpace: settings.shareRemovedSpace)
      case .cameraEdge, .beside, .stack: workspace.dock(id, at: target, shareSpace: settings.shareRemovedSpace)
      }
    }
  }

  /// The same for a command that arranges windows. All of them are in view.
  private func holdWouldLetSomethingIn(_ command: Command) -> Bool {
    guard command.takesAWindowOutOfItsPlace, let named = command.arrangedWindows.first,
      let id = named ?? system.focusedWindow(), let display = workspaceID(containing: id),
      let workspace = workspaces[display]
    else { return false }
    switch command {
    case .float:
      return holdWouldLetSomethingIn(dropping: id, on: .float, of: display)
    case .toggleFloat:
      return holdWouldLetSomethingIn(dropping: id, on: workspace.isDocked(id) ? .float : .cameraEdge(.right), of: display)
    case .dock(_, let edge):
      // A docked window trades places with a neighbour in view or goes to the edge of the view.
      // Only the second can widen the view, so that is the one to rehearse.
      return holdWouldLetSomethingIn(dropping: id, on: .cameraEdge(edge), of: display)
    case .dockBeside(_, let target, let edge):
      guard let there = workspaceID(containing: target), let leaf = workspaces[there]?.tree.leaf(containing: target)
      else { return false }
      return holdWouldLetSomethingIn(dropping: id, on: .beside(leaf, edge), of: there)
    default:
      return false
    }
  }

  // MARK: What the user sees

  /// A line of the menu. Without a command it is a remark.
  public struct HoldMenuEntry: Equatable, Sendable {
    public var title: String
    public var command: Command?
    public var isOn = false
    /// What it does, for a tooltip: the two titles differ by one word.
    public var help = ""
    /// False if choosing it now would only fail.
    public var isEnabled = true
  }

  /// The menu's lines about holding, for a menu that shows them in one block.
  public var holdMenu: [HoldMenuEntry] { holdState + holdRows }

  /// What is going on and the command that ends it (docs/MENU.md, states 4 and 5), or nothing. First in the menu.
  public var holdState: [HoldMenuEntry] {
    let level = holdLevel
    var entries: [HoldMenuEntry] = []
    switch level {
    case .view:
      // On every display, or one of them still shows what it showed.
      let isEmpty = !hold.empty.isEmpty && workspaces.keys.allSatisfy { hold.empty.contains($0) || heldWindows(on: $0).isEmpty }
      entries.append(HoldMenuEntry(title: "The view is held: nothing \(isEmpty ? "is in" : "moves") it", command: nil))
    case .still:
      let reason = hold.chosen == nil ? hold.caller.map { " while \($0)" } : nil
      entries.append(HoldMenuEntry(title: "Holding still" + (reason ?? ": the view moves only when you ask"), command: nil))
    case nil:
      break
    }
    if level != nil { entries.append(HoldMenuEntry(title: "Release", command: .release, help: "Arbor goes back to following you.")) }
    return entries
  }

  /// The two rows (docs/MENU.md, 25 and 26). Choosing the ticked one releases too.
  public var holdRows: [HoldMenuEntry] {
    let level = holdLevel
    return [
      HoldMenuEntry(
        title: "Hold This View", command: level == .view ? .release : .hold(minutes: nil), isOn: level == .view,
        help: "Nothing moves the view, not even your own keys. For a shared screen.",
        isEnabled: level == .view || workspaces.keys.contains { !heldWindows(on: $0).isEmpty }),
      HoldMenuEntry(
        title: "Hold Still", command: level == .still ? .release : .holdStill(minutes: nil), isOn: level == .still,
        help: "Arbor moves nothing by itself; your keys, gestures and ⌘Tab still work. Starts by itself during calls."),
    ]
  }

  /// The end of `status`'s line: how, since when, until when, and why, so that a microphone some app never lets go of
  /// can be found out. For `doctor` as well.
  public var holdStatus: String {
    // After "3 out of view". Arbor does not arrange dialogs, so they are not among those.
    let dialogs = hold.dialogsWait ? system.strayDialogsWaiting() : 0
    return (dialogs == 0 ? "" : " and \(Self.count(dialogs, "dialog"))") + howTheViewIsHeld
  }

  private var howTheViewIsHeld: String {
    guard let level = holdLevel else { return "" }
    let minutes = max(now().timeIntervalSince(hold.since) / 60, 0).rounded(.down)
    let soFar = minutes < 1 ? "" : " (\(Self.minutesText(minutes)) so far)"
    // Rounded up: "0 minutes more" is no answer.
    let more = hold.until.map { " for \(Self.minutesText(max(($0.timeIntervalSince(now()) / 60).rounded(.up), 1))) more" }
    switch level {
    case .view: return "; the view is held\(soFar)\(more ?? " until `release`")"
    case .still:
      let reason = hold.chosen == nil ? hold.caller.map { " while \($0)" } ?? "" : ""
      return "; holding still\(soFar)\(more ?? "")\(reason): the view moves only when you ask"
    }
  }
}
