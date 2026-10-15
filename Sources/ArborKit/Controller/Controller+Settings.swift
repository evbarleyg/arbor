import ArborCore

/// Settings as commands (docs/features/F12-settings-window.md): `set`, `get`, `settings`, `reset`, `bind`,
/// `unbind` and `rule …`, and taking in a settings.json that was edited by hand. What a setting is
/// called and which values it takes is `SettingsSchema`'s business; nothing here knows any one setting.
extension Controller {
  /// Runs a settings command. These work before `start()` too: the settings window can be open, and a
  /// script can run, while Arbor still waits for Accessibility permission.
  func performSettings(_ command: SettingsCommand) -> CommandResult {
    // Before anything is worked out from the settings in use: this can replace them with the file's.
    if command.saves, let refusal = refusalToChangeSettings(), command != .resetAll(everything: true) {
      return refusal
    }
    do {
      switch command {
      case .get(let key): return try getSetting(key)
      case .list(let format): return listSettings(format)
      case .set(let key, let value): return try setSetting(key, to: value)
      case .reset(let key): return try resetSetting(key)
      case .resetAll(let everything): return resetSettings(everything: everything)
      case .bind(let chord, let command): return try bind(chord, to: command)
      case .unbind(let chord): return try unbind(chord)
      case .addRule(let written):
        let (rule, note) = try withBundleIDs(written)
        return editRules("rule \(settings.rules.count + 1)", about: rule, note: note) { $0.append(rule) }
      case .changeRule(let number, let written):
        let (rule, note) = try withBundleIDs(written)
        return editRules("rule \(number)", about: rule, note: note, needing: [number]) { $0[number - 1] = rule }
      case .removeRule(let number):
        return editRules("removed rule \(number); \(settings.rules.count - 1) left", needing: [number]) {
          $0.remove(at: number - 1)
        }
      case .moveRule(let number, let place):
        return editRules("rule \(number) is now rule \(place)", needing: [number, place]) { rules in
          let rule = rules.remove(at: number - 1)
          rules.insert(rule, at: place - 1)
        }
      case .addApp(let key, let app): return try editApps(key, app, add: true)
      case .removeApp(let key, let app): return try editApps(key, app, add: false)
      case .closeWindow:
        guard let onCloseSettingsWindow else { return .failure("there is no settings window here") }
        onCloseSettingsWindow()
        return .success("the settings window is closed")
      case .showWindow(let pane):
        guard let onShowSettingsWindow else { return .failure("there is no settings window here") }
        onShowSettingsWindow(pane)
        return .success("the settings window is open" + (pane.map { " at \($0.title)" } ?? ""))
      }
    } catch {
      // `Command.parse` has checked keys, values and shortcuts, but a command can also be built in code.
      return .failure("\(error)")
    }
  }

  // MARK: One setting

  private func getSetting(_ key: String) throws -> CommandResult {
    let entry = try SettingsSchema.entry(named: key)
    let value = entry.value(in: settings)
    // `text` is the bare value, which is what arborctl prints, so a script can use it as it is.
    return CommandResult(ok: true, message: "\(entry.key) = \(value.summary)" + ownValuesNote(for: entry.key), text: value.text)
  }

  private func listSettings(_ format: SettingsCommand.ListFormat) -> CommandResult {
    let changed = SettingsSchema.entries.filter { !$0.isDefault(in: settings) }.count
    let text: String
    switch format {
    case .json: text = SettingsSchema.json(settings)
    case .markdown: text = SettingsSchema.markdown()
    case .text:
      // First, because nothing below is what the user wrote.
      let warning = settingsFileProblem.map {
        "settings.json cannot be read: \($0).\nArbor keeps the settings below, and saves nothing until the file "
          + "is mended or `reset everything` replaces it.\n\n"
      }
      text = (warning ?? "") + SettingsSchema.report(settings)
    }
    return CommandResult(
      ok: true, message: "\(SettingsSchema.entries.count) settings, \(changed) changed from the default", text: text)
  }

  private func setSetting(_ key: String, to text: String) throws -> CommandResult {
    let entry = try SettingsSchema.entry(named: key)
    let old = entry.value(in: settings)
    var text = text
    if text == SettingsCommand.toggle, case .bool(let isOn) = old { text = isOn ? "false" : "true" }
    let value = try entry.parse(text)
    // What the file says may still be something else, which Arbor could not use: then this puts it right.
    guard value != old || entry.hasProblem(in: settings) else {
      return .success("\(entry.key) is already \(value.text)" + ownValuesNote(for: entry.key))
    }
    let note = value == .bool(false) ? entry.whenOff.map { "; \($0)" } ?? "" : ""
    return sayingWhoKeepsTheirOwn(entry.key) {
      change(message: "\(entry.key) = \(value.text) (was \(old.text))\(note)") { try entry.set(value, in: &$0) }
    }
  }

  /// The reply with `ownValuesNote` after it. Added here and not to the message `change` is given, which it logs as it is:
  /// the note names displays, and names are not logged.
  private func sayingWhoKeepsTheirOwn(_ key: String, _ change: () throws -> CommandResult) rethrows -> CommandResult {
    var result = try change()
    if result.ok { result.message += ownValuesNote(for: key) }
    return result
  }

  private func resetSetting(_ key: String) throws -> CommandResult {
    let entry = try SettingsSchema.entry(named: key)
    let standard = entry.defaultValue.summary
    guard !entry.isDefault(in: settings) || entry.hasProblem(in: settings) else {
      return .success("\(entry.key) is already the default, \(standard)")
    }
    var isList = false
    if case .list = entry.kind { isList = true }
    let old = isList ? entry.tally(in: settings) : entry.value(in: settings).summary
    return sayingWhoKeepsTheirOwn(entry.key) {
      change(message: "\(entry.key) = \(standard), the default (was \(old))", keepingACopy: isList) { entry.reset(in: &$0) }
    }
  }

  private func resetSettings(everything: Bool) -> CommandResult {
    let entries = SettingsSchema.entries.filter { entry in
      if case .list = entry.kind, !everything { return false }
      // The default may be in use because the file holds something Arbor could not use. That goes too.
      return !entry.isDefault(in: settings) || entry.hasProblem(in: settings)
    }
    // Starting over is the way out when settings.json cannot be read, so `reset everything` replaces
    // such a file, even if Arbor, having read nothing, is running on the defaults already.
    // `reset all` must not sound as if nothing of the user's were left.
    let kept = SettingsSchema.entries.filter { entry in
      // Only what people made with Arbor's own commands and window. A list for a text editor (`holdStillFor`) is kept in silence:
      // a trace holds marks for its titles, so whether it is the default is not the same in a replay.
      if case .list = entry.kind, !everything { return entry.isCountedInWords && !entry.isDefault(in: settings) }
      return false
    }
    let tallies = kept.map { $0.tally(in: settings) }
    let keptNote =
      tallies.isEmpty
      ? ""
      : "; your " + (tallies.count > 1 ? tallies.dropLast().joined(separator: ", ") + " and " : "") + tallies[tallies.count - 1]
        + " \(tallies == ["1 shortcut"] || tallies == ["1 rule"] ? "is" : "are") kept (`reset everything` resets those too)"
    guard !entries.isEmpty || settingsFileProblem != nil else {
      return .success("every setting is already the default" + keptNote)
    }
    let keys = entries.map(\.key).joined(separator: ", ")
    return change(
      message: keys.isEmpty ? "replaced settings.json with the defaults" : "back to the default: \(keys)\(keptNote)",
      replacingTheFile: settingsFileProblem != nil, orIfItCannotBeChanged: everything, keepingACopy: everything
    ) {
      for entry in entries { entry.reset(in: &$0) }
    }
  }

  // MARK: Shortcuts

  /// A shortcut as `bind` and `unbind` were given it, read as settings.json's are: on the keyboard layout in use, where a key
  /// can also be named by what it types (`ctrl+opt+ö`).
  private struct NamedChord {
    let chord: KeyChord
    /// How to write it, in replies and in the file: tidied, and with the key as the person named it. `ö` is a place to Arbor
    /// (`us:;` on a German keyboard), which is not what anybody typed or would look for.
    let text: String

    init(_ text: String, layout: KeyLayout) throws {
      do {
        chord = try KeyChord(text: text, layout: layout)
      } catch {
        throw Refusal(SettingsCommand.notAShortcut(text, error))
      }
      if (try? KeyChord(text: text)) == nil, let named = KeyChord.modifiersAndOneCharacter(in: text) {
        self.text = KeyChord.text(named.modifiers, typing: named.character)
      } else {
        self.text = chord.text
      }
    }
  }

  /// What runs when the keys of `chord` are pressed, whichever way its shortcut is written: now, or with other settings.
  private func binding(on chord: KeyChord, with other: Settings? = nil) -> KeyBinding? {
    let layout = layoutInEffect
    let bindings = other.map { KeyBindings.effective(settings: $0, layout: layout).bindings } ?? effectiveBindings.bindings
    return bindings.first { $0.modifiers == chord.modifiers && $0.keyCode == chord.code(in: layout) }
  }

  /// Takes from `updated` the defaults that sit on the key of `chord`, each under its own name. That name frees it whatever the
  /// key's own name is (`'` is where ⌃⌥4 falls back to on a French keyboard, and is no place), and on every other layout too.
  private func freeTheKey(of chord: KeyChord, in updated: inout Settings) {
    // One default at a time: each gone may uncover another that had lost the key to it.
    while let standing = binding(on: chord, with: updated), updated.bindings[standing.chord.text] == nil {
      updated.bindings.updateValue(nil, forKey: standing.chord.text)
    }
  }

  private func bind(_ chordText: String, to commandText: String) throws -> CommandResult {
    let layout = layoutInEffect
    let named = try NamedChord(chordText, layout: layout)
    let chord = named.chord
    let command = try Command.parse(commandText)
    let before = binding(on: chord)?.command
    var updated = settings
    // The key is taken from whatever has it, however that is written: `us:z` and `y` are one key on a German keyboard. What
    // freed it goes too.
    updated.removeBindings(onTheKeyOf: chord, layout: layout)
    // No entry is needed to say what the defaults already say. Unless a place was asked for outright (`us:z`): that is to hold
    // on every layout, and the default moves with the letter.
    let asksForThePlace = chord.isPositional && named.text == chord.text
    if asksForThePlace || binding(on: chord, with: updated)?.command != command {
      // A default under another name goes under its own: this entry may not stand in for it (`'` is no place, and the default
      // would be reported for ever as having lost the key), or not everywhere (`ü` cannot be read on a US keyboard, and the
      // default would be back there).
      if !asksForThePlace, binding(on: chord, with: updated)?.chord != chord { freeTheKey(of: chord, in: &updated) }
      updated.bindings[named.text] = command.text
    }
    // One set of rules for shortcuts wherever they come from: what settings.json may not bind (a
    // query, a key that would no longer type), `bind` may not either.
    let problems = KeyBindings.effective(settings: updated, layout: layout).problems
    if let problem = problems.first(where: { $0.hasPrefix("\(named.text): ") }) { throw Refusal(problem) }
    // What is said has to be what has happened.
    guard binding(on: chord, with: updated)?.command == command else {
      throw Refusal("\(named.text) could not be given to `\(command.text)`; `bindings` shows what has that key")
    }
    guard updated != settings else { return .success("\(named.text) already runs `\(command.text)`") }
    let message =
      "\(named.text) runs `\(command.text)`" + (before.flatMap { $0 == command ? nil : " (it ran `\($0.text)`)" } ?? "")
      + (chord.caution(shownAs: chord.label(in: layout)).map { "; mind that \($0)" } ?? "")
    // The command is left out of the log: it can be `rule add …` with part of a window title in it.
    return change(message: message, log: "bound \(named.text)") { $0 = updated }
  }

  private func unbind(_ chordText: String) throws -> CommandResult {
    let layout = layoutInEffect
    let named = try NamedChord(chordText, layout: layout)
    let chord = named.chord
    guard let before = binding(on: chord) else { return .success("\(named.text) already runs nothing") }
    // Two entries meant one key, and this is the one that lost (`bindings` says so). The one that works stays. (An entry that
    // frees a shortcut has lost nothing: taking it away would give Arbor the key back.)
    let isWritten = settings.bindings.contains { $0.value != nil && (try? KeyChord(text: $0.key, layout: layout)) == chord }
    if before.chord != chord, isWritten {
      let message = "\(named.text) ran nothing: \(before.chord.text) has that key, and still runs `\(before.command.text)`"
      return change(message: message, log: "unbound \(named.text)") { $0.removeBindings(for: chord, layout: layout) }
    }
    let others = effectiveBindings.bindings.filter { $0.command == before.command && $0.chord != before.chord }
    let message =
      "\(named.text) no longer runs `\(before.command.text)`"
      + (others.first.map { "; \($0.chord.text) still does" } ?? "; no shortcut does now")
    var updated = settings
    updated.removeBindings(onTheKeyOf: chord, layout: layout)
    // A default comes back when settings.json says nothing about its shortcut; null is what removes it.
    freeTheKey(of: chord, in: &updated)
    // What is said has to be what has happened: Arbor must not go on holding a key it says it has let go of.
    guard binding(on: chord, with: updated) == nil else {
      throw Refusal("\(named.text) could not be freed; `bindings` shows what has that key")
    }
    return change(message: message, log: "unbound \(named.text)") { $0 = updated }
  }

  // MARK: Rules

  /// `rule add Safari dock left`: people know apps by name, and a rule for a word that is no app's bundle
  /// id would be accepted and never match. A word that is the name or, but for its case, the bundle id of
  /// an app with a window open becomes that app's bundle id. Any other word must at least look like one.
  /// Also returns a word of caution, to end the reply with, about an id that nothing vouches for.
  private func withBundleIDs(_ rule: AppRule) throws -> (rule: AppRule, note: String) {
    var rule = rule
    var notes: [String] = []
    func resolve(_ word: String) throws -> String {
      let (id, isKnown) = try bundleID(word)
      if !isKnown { notes.append(Self.strangerNote(id)) }
      return id
    }
    // `*` and `com.jetbrains.*` (F23) name no one app for a window to vouch for.
    if !rule.hasWildcard { rule.app = try resolve(rule.app) }
    if case .dockBeside(let neighbour, let edge) = rule.action {
      rule.action = .dockBeside(bundleID: try resolve(neighbour), edge)
    }
    return (rule, notes.joined())
  }

  /// `isKnown` is whether an app with a window open answers to the id. An app's name can have a dot in it as well
  /// (zoom.us), and taken for an id it would never match anything.
  private func bundleID(_ word: String) throws -> (id: String, isKnown: Bool) {
    // The app in front as well: during a pause Arbor knows no windows, and the app it pauses for is the one in front.
    var known = windows.values.sorted { $0.id < $1.id }.map { (id: $0.bundleID, name: $0.appName) }
    if let app = frontmostApp { known.append((app.bundleID, app.name)) }
    let lowered = word.lowercased()
    if let exact = known.compactMap(\.id).first(where: { $0.lowercased() == lowered }) { return (exact, true) }
    if let named = known.first(where: { $0.name.lowercased() == lowered })?.id { return (named, true) }
    guard word.contains(".") else {
      throw Refusal(
        "`\(word)` is not a bundle id (they look like com.apple.Safari), nor the name of an app with a window open; "
          + "`rules` names the focused window's")
    }
    return (word, false)
  }

  private static func strangerNote(_ id: String) -> String {
    "; mind that no app with the id \(id) has a window open: it may be a name, which never matches"
  }

  // MARK: Lists of apps

  /// `add <list> <app>` and `remove <list> <app>`. An app is on a list whatever the case of its bundle id, as
  /// everything that reads these lists sees it, and can be named as in `rule add`.
  private func editApps(_ key: String, _ word: String, add: Bool) throws -> CommandResult {
    let entry = try SettingsSchema.entry(named: key)
    guard entry.isAppList else { throw Refusal("`\(entry.key)` is not a list of apps") }
    let listed = entry.apps(in: settings)
    // What is on the list can always be taken off it, whether or not it looks like a bundle id.
    var note = ""
    var app = listed.first { $0.lowercased() == word.lowercased() }
    if app == nil {
      let (id, isKnown) = try bundleID(word)
      app = id
      if add, !isKnown { note = Self.strangerNote(id) }
    }
    guard let app else { return .failure("no app") }
    let isListed = listed.contains { $0.lowercased() == app.lowercased() }
    let name = appName(forBundleID: app)
    guard isListed != add else {
      return .success(add ? "\(name) is already under “\(entry.label)”" : "\(name) was not under “\(entry.label)”")
    }
    let updated = add ? listed + [app] : listed.filter { $0.lowercased() != app.lowercased() }
    return change(
      message: entry.sentence(about: name, added: add) + note, log: "\(add ? "added to" : "removed from") \(entry.key): \(app)"
    ) {
      entry.setApps(updated, in: &$0)
    }
  }

  /// Changes the list of rules.
  ///
  /// - Parameters:
  ///   - message: what to say when it is done.
  ///   - rule: the rule the command is about, which is added to the message.
  ///   - numbers: the places `edit` indexes, counted from 1. One that is not in the list fails the
  ///     command before `edit` runs.
  private func editRules(
    _ message: String, about rule: AppRule? = nil, note: String = "", needing numbers: [Int] = [],
    _ edit: (inout [AppRule]) -> Void
  ) -> CommandResult {
    let count = settings.rules.count
    if let missing = numbers.first(where: { $0 < 1 || $0 > count }) {
      return .failure(
        count == 0 ? "there are no rules" : "there is no rule \(missing); `rules` lists all \(count)")
    }
    var rules = settings.rules
    edit(&rules)
    guard rules != settings.rules else { return .success("that changes nothing") }
    // The log gets the rule without its title pattern: that is part of a window title, and titles are
    // never logged.
    return change(
      message: message + (rule.map { ": \($0)" } ?? "") + note,
      log: message + (rule.map { ": \($0.app) → \($0.action.text)" } ?? "")
    ) { $0.rules = rules }
  }

  // MARK: Applying and saving

  private struct Refusal: Error, CustomStringConvertible {
    let description: String
    init(_ description: String) { self.description = description }
  }

  /// The one way the commands above change settings: edits a copy, saves what changed and applies it
  /// at once. An edit that throws changes nothing. `log` is what to log when `message` holds
  /// something that must not be.
  private func change(
    message: String, log: String? = nil, replacingTheFile: Bool = false, orIfItCannotBeChanged: Bool = false,
    keepingACopy: Bool = false, _ edit: (inout Settings) throws -> Void
  ) -> CommandResult {
    var updated = settings
    do {
      try edit(&updated)
    } catch {
      return .failure("\(error)")
    }
    // What is about to go took somebody a while to make. Replacing a file keeps a copy by itself.
    var copy: String?
    if keepingACopy, !replacingTheFile {
      do {
        copy = try keepCopyOfSettingsFile?()
      } catch {
        return .failure("nothing was reset: \(error)")
      }
    }
    var replaced = replacingTheFile
    var unsaved = change(settings: updated, replacingTheFile: replacingTheFile)
    // A file in UTF-16, say, loads but cannot be edited. `reset everything` is the way out of that as well.
    if unsaved != nil, orIfItCannotBeChanged, !replacingTheFile {
      unsaved = change(settings: updated, replacingTheFile: true)
      replaced = true
    }
    if unsaved == nil { Log.info("settings: \(log ?? message)") }
    let kept = replaced ? copyOfReplacedSettingsFile : copy
    return reply(message + (kept.map { "; the file as it was is kept as \($0)" } ?? ""), unsaved: unsaved)
  }

  // The settings in use are what settings.json says, always. So every command that changes settings
  // 1. asks `refusalToChangeSettings()`, which takes in the file as it is now;
  // 2. works out the new settings from the ones in use;
  // 3. returns `reply("…", unsaved: change(settings: updated))`.
  // A change that cannot be saved is refused as a whole. The other way (in use, but gone after the next
  // launch, or as soon as the file is read again) is harder to live with than a plain no with a reason.

  /// What every command that changes settings asks first. Nil means go ahead.
  ///
  /// It takes in the file as it is now, so the command starts from what the user wrote, even if they
  /// wrote it a moment ago. While the file cannot be read, what Arbor holds is not what the user
  /// wrote, and Arbor will not write to the file (`SettingsFile.update`).
  func refusalToChangeSettings() -> CommandResult? {
    guard case .invalid(let reason, _) = takeInSettingsFile() else { return nil }
    return .failure(
      "settings.json cannot be read, so nothing was changed: \(reason). "
        + "Mend the file, or run `reset everything` to replace it with the defaults")
  }

  /// Saves settings a command changed and puts them into use. Returns nil, or why they could not be
  /// saved (the file is read-only, say, as a dotfile manager's is), and then nothing has changed.
  ///
  /// What is saved is the difference from the settings in use, written into the text of
  /// settings.json, the rest of which stays as it is (`Settings.rewrite`). `replacingTheFile` writes a
  /// whole new file instead.
  func change(settings updated: Settings, replacingTheFile: Bool = false) -> String? {
    do {
      if replacingTheFile {
        copyOfReplacedSettingsFile = try replaceSettingsFile?(updated)
        settingsFileProblem = nil
      } else {
        try saveSettings?(settings, updated)
      }
    } catch {
      Log.error("settings.json could not be saved: \(SettingsFile.forTheLog(error))")
      return "\(error)"
    }
    // Read back, so that what is in use is what the file says down to the reports on what could not be
    // used in it: "entry 3" of `rules` is entry 2 once the rule before it is gone. (Nothing was saved
    // if nothing is wired to save: then there is nothing new to read.)
    apply(settings: saveSettings == nil ? updated : (try? loadSettings?()) ?? updated)
    return nil
  }

  /// A reply as it may be logged. One that says why settings.json cannot be read quotes the file, where
  /// the typo can be in a rule's `title`.
  func forTheLog(_ message: String) -> String {
    guard let problem = settingsFileProblem, let safe = settingsFileProblemForTheLog, problem != safe,
      let range = message.firstRange(of: problem)
    else { return message }
    var message = message
    message.replaceSubrange(range, with: safe)
    return message
  }

  /// The reply of a command that changes settings: a failure if they could not be saved, so that
  /// `arborctl` exits with an error and the menu beeps.
  func reply(_ message: String, unsaved reason: String?) -> CommandResult {
    guard let reason else { return .success(message) }
    return .failure("settings.json could not be saved, so nothing was changed: \(reason)")
  }

  // MARK: The file

  /// What became of a look at settings.json.
  public enum SettingsFileOutcome: Equatable, Sendable {
    /// It says what Arbor already uses: Arbor wrote it itself, or the edit changed nothing that counts
    /// (spacing, the order of the keys, a key Arbor does not know).
    case unchanged
    case applied
    /// There is no file. An editor replacing the file can leave such a moment, so nothing is done.
    case missing
    /// It could not be read, and the settings in use stay. `isNews` is false when the look before
    /// this one failed for the same reason.
    case invalid(reason: String, isNews: Bool)
  }

  /// `reload-settings`: reads settings.json and applies it, changed or not (which also tries again to
  /// register shortcuts that another app held).
  func reloadSettings() -> CommandResult {
    switch takeInSettingsFile(evenIfUnchanged: true) {
    case .applied, .unchanged:
      let problems = settings.valueProblems.count + settings.skippedRules.count + settings.skippedDisplays.count
      let places = settings.skippedDisplays.isEmpty ? "`settings` and `rules`" : "`settings`, `rules` and `displays`"
      return .success("settings reloaded" + (problems == 0 ? "" : "; \(problems) problem(s), see \(places)"))
    case .missing:
      // As at launch: with no file, start from the defaults and write them so there is a file to edit.
      if let reason = change(settings: Settings()) {
        return .failure("there is no settings.json, and none could be written: \(reason)")
      }
      return .success("there was no settings.json; wrote one with the defaults")
    case .invalid(let reason, _):
      return .failure("settings.json cannot be read, keeping the settings in use: \(reason)")
    }
  }

  /// Call when settings.json may have changed (the app watches its folder). Editors save in several
  /// steps, and Arbor's other files live in the same folder, so this waits for 0.3 s of quiet.
  public func settingsFileMayHaveChanged() {
    traced("settingsFileMayHaveChanged") {
      scheduler.schedule("settings-file", after: 0.3) { [weak self] in
        guard let self, !self.holdPutsOffTheSettingsFile() else { return }
        self.takeInSettingsFile()
      }
    }
  }

  /// Reads settings.json through `loadSettings` and applies it if it says something new.
  @discardableResult
  public func takeInSettingsFile(evenIfUnchanged: Bool = false) -> SettingsFileOutcome {
    let loaded: Settings
    do {
      loaded = try loadSettings?() ?? settings
    } catch is SettingsFile.Missing {
      settingsFileProblem = nil
      return .missing
    } catch {
      let reason = "\(error)"
      let isNews = reason != settingsFileProblem
      settingsFileProblem = reason
      settingsFileProblemForTheLog = SettingsFile.forTheLog(error)
      // Once per mistake, not once per save of a file someone is still typing in.
      if isNews {
        Log.error("settings.json cannot be read, keeping the settings in use: \(SettingsFile.forTheLog(error))")
      }
      return .invalid(reason: reason, isNews: isNews)
    }
    settingsFileProblem = nil
    guard evenIfUnchanged || loaded != settings else { return .unchanged }
    SettingsFile.logProblems(in: loaded)
    apply(settings: loaded)
    Log.info("settings.json read and applied")
    return .applied
  }
}
