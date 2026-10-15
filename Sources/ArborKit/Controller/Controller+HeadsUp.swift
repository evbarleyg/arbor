import ArborCore
import CoreGraphics
import Foundation

/// Saying what happened (docs/features/F43-say-what-happened.md).
///
/// Every command answers in a sentence, which `arborctl` prints. Someone who pressed a key, pinched or chose a menu
/// item has nowhere to read it, so the answers that matter to them go on screen as one line, low on the
/// display the command acted on: what went wrong, what changed unseen, and, a few times ever, what a newcomer
/// needs to hear at that moment. What earns a line, its words, its place and how long it stays are decided in
/// ArborCore (HeadsUp.swift); this file gathers the facts, shows the line and takes it away again.
extension Controller {
  struct HeadsUpState {
    /// Who asked for the command being performed. Nil while none is: what happens then is the user's doing (a drop,
    /// a click on a tile, ⌘Tab) or an app's.
    var source: CommandSource?
    /// The display the line is on.
    var showing: DisplayID?
    /// The line as it was placed there, to place it again when the minimap below it comes or goes.
    var line: HeadsUpModel?
    /// Each display as it was when last looked at, to tell a teaching moment by what changed.
    var facts: [DisplayID: HeadsUpFacts] = [:]
    /// How often each teaching moment has been shown, ever. Saved with the arrangement.
    var hintsShown: [String: Int] = [:]
    /// The display the panel of shortcuts is on (Controller+CheatSheet.swift).
    var cheatSheet: DisplayID?
    /// When a person last asked for something, to tell what follows from it (macOS reports the app that came to the
    /// front a moment after the command that brought it there).
    var lastAsked: Date?
    /// Whether the frontmost app kept its own ⌃⌥ when last looked at.
    var wasPassingThrough = false
    /// How many things are being tried whose layouts on the way are not news (`summingUpForTheLine`).
    var trying = 0
    /// The last line as the log got it.
    var logged = ""
  }

  /// The inside of `perform(_:from:)` (Controller+Lead.swift): runs a command and, when a person asked for it with keys, a
  /// gesture or the menu, says on screen what they need to know about the outcome. The reply is the same whoever asked.
  func executeAndSay(_ command: Command, from source: CommandSource) -> CommandResult {
    let outer = headsUp.source
    headsUp.source = source
    defer { headsUp.source = outer }
    // "Any key puts it away" includes Arbor's own shortcuts, which never reach the panel.
    if command != .showShortcuts, !command.isQuery { hideCheatSheet() }
    let answered = source.isAnsweredOnScreen && settings.messageLevel != .off
    let before = answered ? seen() : nil
    let names = answered ? everyName() : []
    // Asked first: afterwards the window may be somewhere else, or Arbor may have stopped looking. During a pause it
    // is not looking yet, and the answer to `resume` goes where the question is asked afterwards.
    // Not asked for a script, which is answered in its reply. Only asked: it is the command that decides (F56).
    let display = isRunning && source.isAnsweredOnScreen ? deciding(false) { display(actedOnBy: command) } : nil
    let result = execute(command)
    if source.isAnsweredOnScreen { headsUp.lastAsked = now() }
    say(result, to: command, from: source, on: display, changedNothing: before.map { $0 == seen() } ?? false, namesBefore: names)
    return result
  }

  /// What a person can see or feel of what Arbor does: the views, the arrangement, where every window is, and which
  /// one has the keyboard.
  private struct Seen: Equatable {
    var views: [DisplayID: NodeID]
    var trees: [DisplayID: LayoutTree]
    var floating: [DisplayID: [WindowID: CGRect]]
    var frames: [WindowID: CGRect]
    var focused: WindowID?
    var isRunning: Bool
  }

  private func seen() -> Seen {
    Seen(
      views: workspaces.mapValues(\.camera), trees: workspaces.mapValues(\.tree), floating: workspaces.mapValues(\.floating),
      frames: windows.mapValues(\.frame), focused: isRunning ? system.focusedWindow() : nil, isRunning: isRunning)
  }

  // MARK: What to say

  private func say(
    _ result: CommandResult, to command: Command, from source: CommandSource, on display: DisplayID?, changedNothing: Bool,
    namesBefore: Set<String>
  ) {
    // Looked at whoever asked, so that what a script changed is not taken for the next event's doing.
    let moment = noteFacts(on: ([display].compactMap { $0 } + workspaces.keys.sorted()))
    let level = settings.messageLevel
    guard source.isAnsweredOnScreen, level != .off else { return }
    // What was lost comes before what a newcomer might like to know. The hint keeps its showing for the next time.
    let loss = result.ok && HeadsUpText.namesALoss(result.message)
    // Whoever went back or forth is told what was taken back or put back, not taught what a dock is (F19).
    if result.ok, let moment, !loss, command != .undo, command != .redo {
      teach(moment)
      return
    }
    guard
      let kind = HeadsUpPolicy.kind(
        of: command, ok: result.ok, from: source, level: level, changedNothing: changedNothing, namesALoss: loss)
    else {
      // The line that is up answered the last thing this person asked. What they asked now has changed something, so
      // it may no longer be true: "out of view, not closed" with everything in view again.
      if !command.isQuery, !command.opensItsOwnAnswer { hideHeadsUp() }
      return
    }
    // Only for what failed for want of the permission: whatever else goes wrong meanwhile has a reason of its own.
    if !result.ok, result.message == statusText, let why = whyAKeyDidNothing { return showWithoutLooking(why) }
    guard let display = display ?? cameraDisplay()?.0 ?? pointerDisplayID else { return }
    if var line = lineOfItsOwn(for: command, result, changedNothing: changedNothing) {
      line.kind = kind
      showHeadsUp(line, on: display)
      return
    }
    if result.ok, let words = wordsOnScreen(after: command) {
      showHeadsUp(HeadsUpModel(kind: kind, text: words), on: display)
      return
    }
    // Which display a command chose is what the line's place says.
    let chosen = onPointerDisplay
    func sentence(_ reply: String) -> String {
      HeadsUpText.sentence(
        from: chosen.isEmpty ? reply : reply.replacing(chosen, with: ""),
        appName: { [windows] in windows[$0]?.appName },
        bundleName: { bundle in
          let name = self.appName(forBundleID: bundle)
          return name == bundle ? nil : name
        }, shortcut: shortcutLabel(for:))
    }
    let names = namesBefore.union(everyName()).union(command.namesInText)
    // "w7 fills the view, and the view is held; release it with …": the same few words as for the held message alone.
    let endsHeld = !result.ok && result.message.hasSuffix(heldMessage)
    let reply = endsHeld ? result.message.dropLast(heldMessage.count) + "the view is held" : result.message
    // The log gets the reply as `execute` gives it to the log. The commands that change settings have words of their own
    // for it, since their replies can quote a rule's part of a window title.
    var logged = "the reply to `\(command.verb)`"
    switch command {
    case .settings: break
    // That nothing matches repeats what was typed, which may be part of a window title.
    case .find where !result.ok: break
    default: logged = sentence(Self.withoutNames(forTheLog(reply), names))
    }
    // A space's name is the person's own word and is said as they wrote it. One that reads like Arbor's shorthand ("w12", for
    // the twelfth week) stands aside while the shorthand is put into words.
    let shorthand = names.filter { sentence("x \($0)") != "X \($0)" }.sorted { ($0.count, $0) > ($1.count, $1) }
    var text = reply
    for (index, name) in shorthand.enumerated() { text = text.replacing(name, with: "‹\(index)›") }
    text = sentence(text)
    for (index, name) in shorthand.enumerated() { text = text.replacing("‹\(index)›", with: name) }
    let wayBack = endsHeld ? wayOutOfAHold : loss ? shortcutLabel(for: .undo).map { "\($0) takes it back" } : nil
    showHeadsUp(
      HeadsUpModel(kind: kind, text: text, hint: wayBack), on: display, inTheLog: wayBack.map { "\(logged) · \($0)" } ?? logged)
  }

  /// The few outcomes where the reply, written for someone who can name windows and apps at a terminal, has nothing to
  /// offer someone at the keyboard.
  /// What follows "The view is held" on screen, in place of the reply's three ways, the last of which is a command to type.
  private var wayOutOfAHold: String {
    let keys = [Command.toggleHold, .release, .togglePause].lazy.compactMap(shortcutLabel(for:)).first
    return keys.map { "\($0) releases it" } ?? "Release it from Arbor’s menu"
  }

  private func lineOfItsOwn(for command: Command, _ result: CommandResult, changedNothing: Bool) -> HeadsUpModel? {
    let ok = result.ok
    // Said in front of an audience, so in as few words as will do. The reply ends in a command to type.
    if !ok, result.message == heldMessage { return HeadsUpModel(kind: .problem, text: "The view is held", hint: wayOutOfAHold) }
    // The pause Arbor took by itself at a logout that somebody cancelled: its keys are still its own, and do nothing.
    if !ok, isPaused, result.message == statusText {
      let keys = [Command.togglePause, .resume].lazy.compactMap(shortcutLabel(for:)).first
      return HeadsUpModel(kind: .problem, text: "Arbor is paused", hint: keys.map { "\($0) resumes" } ?? "Resume from Arbor’s menu")
    }
    // From here on the keys land in whatever app is in front, and some apps do with them what cannot be taken back. So that is what is said:
    // that the windows are back in their own sizes can be seen.
    if ok, isPaused, !isPausedForApp, command.beginsPause {
      let length = pauseEnd == nil ? "" : result.message.split(separator: ";").first.map { " " + $0.dropFirst("paused ".count) } ?? ""
      let keys = [Command.togglePause, .resume].lazy.compactMap(shortcutLabel(for:)).first
      return HeadsUpModel(
        kind: .change, text: "Arbor is paused\(length): its keys are the apps’ again",
        hint: keys.map { "\($0) resumes" } ?? "Resume from Arbor’s menu")
    }
    guard isRunning, command.actsOnTheFocusedWindow, let id = system.focusedWindow(), let window = windows[id] else {
      return nil
    }
    if !ok, let bundle = window.bundleID, filter.excludedBundleIDs.contains(bundle) {
      return HeadsUpModel(kind: .problem, text: "Arbor does not arrange \(window.appName)", hint: "Arrangement → Arrange Again in the menu")
    }
    // The headline key, pressed before anything is docked: the Desktop, where the window floats, is in view already.
    if ok, changedNothing, command == .zoom(nil), workspaceID(containing: id).map({ workspaces[$0]?.isFloating(id) == true }) == true {
      var hint: String?
      if let dock = shortcutLabel(for: .dock(nil, .left)), let frame = shortcutLabel(for: .zoom(nil)) {
        hint = "\(dock) docks it, then \(frame) frames it"
      }
      return HeadsUpModel(kind: .change, text: "\(window.appName) floats", hint: hint)
    }
    return nil
  }

  /// Part of `notify`: teaching moments also come without a command, and the line goes when Arbor stops.
  func headsUpNoticed(_ change: Change) {
    switch change {
    case .layout(let display):
      // A command sums up once it is done; the layouts on the way there are not news.
      // Nor is the end of a peek: whoever held ⌃⌥Space to look around and let go knows where the windows went, and how to get them back.
      guard headsUp.source == nil, headsUp.trying == 0, let moment = noteFacts(on: [display]), settings.messageLevel != .off,
        peeking == nil
      else { return }
      teach(moment)
    case .input:
      let landed = isPassingThrough && !headsUp.wasPassingThrough
      headsUp.wasPassingThrough = isPassingThrough
      // Only when Arbor's own command brought the person there, who may go on pressing its keys. Someone who switched
      // to the app knows where they are, and `pass-through` says its own piece.
      guard landed, headsUp.source == nil, settings.messageLevel != .off, let asked = headsUp.lastAsked,
        now().timeIntervalSince(asked) <= 1, let display = focusedPlace?.display ?? pointerDisplayID
      else { return }
      let pause = shortcutLabel(for: .togglePause).map { ", \($0) pauses" } ?? ""
      showHeadsUp(
        HeadsUpModel(kind: .change, text: "Shortcuts are off in \(frontmostAppName)", hint: "⌘Tab leaves" + pause), on: display)
    case .hold:
      // What was said before the hold began, by command or because a call started, is not for the audience either.
      if !mayShowUnasked, headsUp.line?.kind != .problem { hideHeadsUp() }
    case .lifecycle where !isRunning:
      // `shutdown` has removed every overlay. A pause says that it began after this.
      scheduler.cancel("heads-up")
      headsUp.showing = nil
      headsUp.cheatSheet = nil
      headsUp.facts.removeAll()
    case .lifecycle:
      // A pause hears of no display that goes. What it said may be on one.
      if let gone = headsUp.showing, display(gone) == nil { hideHeadsUp() }
      // Arbor has started: that it needs the permission, or is paused, is no longer true.
      if headsUp.line?.kind == .problem { hideHeadsUp() }
    default:
      break
    }
  }

  /// Does `body`, which may lay `display` out several times before it knows what it wants (automatic docking tries a place and
  /// takes it back), and then looks once at what came of it: one event, one hint at most, and none for what did not last.
  func summingUpForTheLine<Result>(on display: DisplayID, _ body: () -> Result) -> Result {
    headsUp.trying += 1
    defer {
      headsUp.trying -= 1
      headsUpNoticed(.layout(display))
    }
    return body()
  }

  private struct Moment {
    var hint: HeadsUpHint
    var display: DisplayID
    var facts: HeadsUpFacts
  }

  /// Brings the remembered facts of `displays` up to date and returns the first teaching moment in what changed
  /// that has not been shown often enough. A display seen for the first time (at launch, after a pause,
  /// plugged in) only sets the baseline: what Arbor restores there is not the user's doing.
  private func noteFacts(on displays: [DisplayID]) -> Moment? {
    var found: Moment?
    for display in displays {
      guard let after = facts(on: display) else {
        headsUp.facts[display] = nil
        continue
      }
      let before = headsUp.facts.updateValue(after, forKey: display)
      guard found == nil, let before else { continue }
      let due = before.moments(to: after).first { headsUp.hintsShown[$0.rawValue, default: 0] < HeadsUpHint.timesShown }
      if let due { found = Moment(hint: due, display: display, facts: after) }
    }
    return found
  }

  private func facts(on display: DisplayID) -> HeadsUpFacts? {
    guard isRunning, let workspace = workspaces[display], let layout = layouts[display] else { return nil }
    let docked = workspace.tree.allWindows
    // Outside the view, not merely parked: the other tabs of a tab group are parked too, and no change of view
    // brings those out.
    let inView = Set(workspace.tree.windows(under: workspace.camera))
    let outside = docked.filter { !inView.contains($0) && windows[$0]?.isPresent == true }.count
    // Not the ones `summon` sent away: whoever did that knows, and showing everything does not bring them back.
    let floatingAway = workspace.floating.keys.filter { parked.contains($0) && !workspace.isStashed($0) }.count
    // The Desktop with nothing on it is a tile too when room is short, and nobody has a reason to click that one.
    let tiles = layout.tiles.filter { $0.kind != .desktop || !$0.windows.isEmpty }.count
    return HeadsUpFacts(docked: docked.count, outOfView: outside + floatingAway, tiles: tiles)
  }

  /// A teaching moment that is an event and no change of the facts. Shown as often as the others.
  func teach(_ hint: HeadsUpHint, on display: DisplayID) {
    guard headsUp.source == nil, headsUp.trying == 0, peeking == nil, settings.messageLevel != .off,
      headsUp.hintsShown[hint.rawValue, default: 0] < HeadsUpHint.timesShown, let facts = facts(on: display)
    else { return }
    teach(Moment(hint: hint, display: display, facts: facts))
  }

  private func teach(_ moment: Moment) {
    // Not in front of an audience, and not counted as shown (Controller+Hold.swift).
    guard mayShowUnasked else { return }
    headsUp.hintsShown[moment.hint.rawValue, default: 0] += 1
    scheduleSave()
    showHeadsUp(moment.hint.model(facts: moment.facts, shortcut: shortcutLabel(for:)), on: moment.display)
  }

  // MARK: Showing it

  /// `inTheLog`: the same words made from what the log may hold, where the line repeats a command's reply. Arbor's own
  /// sentences hold app names at most, and `HeadsUpText` has no way to learn a window's title.
  func showHeadsUp(_ model: HeadsUpModel, on id: DisplayID, inTheLog: String? = nil) {
    guard let display = display(id) else { return }
    showHeadsUp(model, on: display, inTheLog: inTheLog)
  }

  /// Without the permission Arbor is not looking, and before its first start it never has. So where the line goes is asked now, which needs no
  /// permission. `displays` stays what it was when Arbor stopped: `start()` holds the displays it finds against it.
  private func showWithoutLooking(_ model: HeadsUpModel) {
    let found = system.displays()
    let pointer = system.cursorLocation()
    guard let display = found.first(where: { $0.frame.contains(pointer) }) ?? found.first(where: \.isMain) ?? found.first else { return }
    showHeadsUp(model, on: display)
  }

  private func showHeadsUp(_ model: HeadsUpModel, on display: DisplaySnapshot, inTheLog: String? = nil) {
    let id = display.id
    // During a hold only the reason why a key did nothing: the rest is Arbor speaking unasked on a screen that may be shared.
    guard mayShowUnasked || model.kind == .problem else { return }
    if let old = headsUp.showing, old != id { overlays.showHeadsUp(nil, on: old) }
    headsUp.showing = id
    var placed = model.placed(in: display.visibleFrame, above: minimapFrame(on: id))
    // Said while a person's command is being carried out. What follows from one a moment later is Arbor's own remark.
    placed.isAnswer = headsUp.source?.isAnsweredOnScreen == true
    headsUp.line = placed
    headsUp.logged = inTheLog ?? placed.line
    Log.debug("said on \(id): \(headsUp.logged)")
    overlays.showHeadsUp(placed, on: id)
    scheduler.schedule("heads-up", after: placed.duration) { [weak self] in self?.hideHeadsUp() }
  }

  /// The minimap came, went or grew on `id`. The line keeps directly above it, and its time runs on.
  func placeHeadsUpAgain(on id: DisplayID) {
    guard headsUp.showing == id, let line = headsUp.line, let display = display(id) else { return }
    let placed = line.placed(in: display.visibleFrame, above: minimapFrame(on: id))
    guard placed != line else { return }
    headsUp.line = placed
    overlays.showHeadsUp(placed, on: id)
  }

  func hideHeadsUp() {
    scheduler.cancel("heads-up")
    guard let display = headsUp.showing else { return }
    headsUp.showing = nil
    overlays.showHeadsUp(nil, on: display)
  }

  // MARK: Facts for the sentences

  /// The display a command's outcome shows on: its window's, or the one camera commands act on.
  private func display(actedOnBy command: Command) -> DisplayID? {
    if let window = command.window, let id = window ?? system.focusedWindow(), let display = workspaceID(containing: id) {
      return display
    }
    return cameraDisplay()?.0 ?? pointerDisplayID
  }

  /// The keys to name in a sentence for `command`, e.g. ⌃⌥Space: the user's own where they changed them, and
  /// nil, so that the sentence does without, where they removed them.
  func shortcutLabel(for command: Command) -> String? {
    // The ones held right now: none with shortcuts switched off, few during a pause or in an app that keeps its own ⌃⌥.
    let bindings = activeBindings
    return ([command] + command.standIns).lazy.compactMap { KeyBindings.label(for: $0, in: bindings) }.first
  }
}
