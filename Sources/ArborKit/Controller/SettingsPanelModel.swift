import ArborCore

/// Everything the settings window decides, without the window: which panes there are and in what order,
/// which settings each shows and at which level, what a search finds, what a control's change turns
/// into, where a refusal is shown, what "Restore Defaults" restores. `UI/SettingsWindow.swift` draws what
/// this says and calls its methods; tests do the same without a screen.
///
/// It changes nothing itself. Every change is a command, run through the closure the menu and the
/// shortcuts use, and what is shown comes back from the controller's settings, so an edit to
/// settings.json or an `arborctl set` shows up like a click in the window.
@MainActor
public final class SettingsPanelModel {
  // MARK: What the window is given

  /// An app to offer in a menu.
  public struct AppChoice: Equatable, Identifiable, Sendable {
    public let bundleID: String
    public let name: String
    public var id: String { bundleID }

    public init(bundleID: String, name: String) {
      self.bundleID = bundleID
      self.name = name
    }
  }

  private let controller: Controller
  private let run: @MainActor (Command) -> CommandResult
  /// Asks macOS for the apps that are running and have a Dock icon.
  private let runningApps: @MainActor () -> [AppChoice]
  /// What it said the last time, by name.
  private var apps: [AppChoice] = []
  /// For the foot of the window, e.g. "Arbor 0.3 (41)".
  public var version: String { "Arbor \(controller.buildInfo.text)" }

  /// Called after anything the window shows may have changed.
  public var onChange: (@MainActor () -> Void)?
  /// Called when recording a shortcut starts and ends, for the window to listen to the keys meanwhile.
  public var onRecordingChanged: (@MainActor (Bool) -> Void)?

  public init(
    controller: Controller,
    runningApps: @escaping @MainActor () -> [AppChoice] = { [] },
    run: @escaping @MainActor (Command) -> CommandResult
  ) {
    self.controller = controller
    self.runningApps = runningApps
    self.run = run
    controller.observe { [weak self] change in
      if change == .settings { self?.settingsChanged() }
    }
    refreshApps()
  }

  /// Call when the window opens or comes to the front: apps have come and gone meanwhile.
  public func refreshApps() {
    apps = runningApps().sorted { ($0.name.lowercased(), $0.bundleID) < ($1.name.lowercased(), $1.bundleID) }
    changed()
  }

  private var settings: Settings { controller.settings }

  private func changed() { onChange?() }

  /// Whether settings.json could not be read when the window last heard of the settings.
  private var fileWasBroken = false

  private func settingsChanged() {
    // What was refused because of the file is not held against the file that was mended or replaced.
    if fileWasBroken, fileProblem == nil { errors.removeAll() }
    fileWasBroken = fileProblem != nil
    changed()
  }

  // MARK: Panes

  public typealias Pane = SettingsPane

  /// The sidebar.
  public var panes: [Pane] { Pane.all }

  public var pane: Pane = .section(.general) {
    didSet {
      guard pane != oldValue else { return }
      cancelRecording()
      question = nil
      errors.removeAll()
      changed()
    }
  }

  private func entries(in section: SettingsSection) -> [SettingEntry] { SettingsSchema.windowEntries(in: section) }

  // MARK: Rows

  /// One setting, ready to draw.
  public struct Row: Equatable, Identifiable, Sendable {
    public enum Control: Equatable, Sendable {
      case toggle(isOn: Bool)
      case number(value: Double, range: ClosedRange<Double>, step: Double, unit: String)
      case choice(value: String, choices: [SettingEntry.Choice])
      case text(value: String, example: String)
      /// A list of apps: the ones on it, in the file's order, and running apps that are not, by name, to offer.
      case apps(listed: [AppChoice], candidates: [AppChoice])
      /// A list the window has no editor for: how long it is, and that it is edited in the file.
      case list(summary: String)
    }

    public let key: String
    public let label: String
    public let help: String
    public let control: Control
    /// Differs from the default.
    public let isChanged: Bool
    /// Why the last change made here was refused.
    public let error: String?
    public var id: String { key }
  }

  /// Nil only if an entry's value is not of its kind, which a test rules out.
  public func row(for entry: SettingEntry) -> Row? {
    let control: Row.Control
    switch (entry.kind, entry.value(in: settings)) {
    case (.toggle, .bool(let isOn)):
      control = .toggle(isOn: isOn)
    case (.number(let range, let step, _), .number(let value)) where Self.isShare(entry):
      control = .number(
        value: Self.tidy(value * 100), range: Self.tidy(range.lowerBound * 100)...Self.tidy(range.upperBound * 100),
        step: Self.tidy(step * 100), unit: "%")
    case (.number(let range, let step, let unit), .number(let value)):
      control = .number(value: value, range: range, step: step, unit: unit)
    case (.choice(let choices), .text(let value)):
      control = .choice(value: value, choices: choices)
    case (.text(let example), .text(let value)):
      control = .text(value: value, example: example)
    case (.list, _) where entry.isAppList:
      let listed = entry.apps(in: settings)
      let lowered = Set(listed.map { $0.lowercased() })
      control = .apps(
        listed: listed.map { AppChoice(bundleID: $0, name: name(of: $0)) },
        candidates: apps.filter { !lowered.contains($0.bundleID.lowercased()) })
    case (.list, let value):
      control = .list(summary: value.summary)
    default:
      return nil
    }
    return Row(
      key: entry.key, label: entry.label, help: entry.help, control: control,
      isChanged: !entry.isDefault(in: settings), error: errors[entry.key])
  }

  /// A section with nothing but advanced settings shows them at once: a pane that holds only a closed
  /// "Advanced" looks empty, and whoever came to it came for them.
  private func hidesAdvanced(in section: SettingsSection) -> Bool {
    entries(in: section).contains { $0.level == .normal } || (section == .general && hasLoginItem)
  }

  /// What a section shows at once.
  public func rows(in section: SettingsSection) -> [Row] {
    let behind = hidesAdvanced(in: section)
    return entries(in: section).filter { $0.level == .normal || !behind }.compactMap(row(for:))
  }

  /// What it shows under "Advanced".
  public func advancedRows(in section: SettingsSection) -> [Row] {
    guard hidesAdvanced(in: section) else { return [] }
    return entries(in: section).filter { $0.level == .advanced }.compactMap(row(for:))
  }

  /// The sections whose "Advanced" is open.
  public private(set) var openAdvanced: Set<SettingsSection> = []

  public func setAdvanced(_ isOpen: Bool, in section: SettingsSection) {
    if isOpen { openAdvanced.insert(section) } else { openAdvanced.remove(section) }
    changed()
  }

  // MARK: Search

  /// What is typed in the search field. While it is not empty the window shows `found` instead of a pane.
  public var search = "" {
    didSet { if search != oldValue { changed() } }
  }

  public var isSearching: Bool { !search.allSatisfy(\.isWhitespace) }

  public struct Found: Equatable, Sendable {
    /// Settings that match, advanced ones included (whoever searches for one wants to see it), by section.
    public var sections: [FoundSection]
    /// Lines of the Shortcuts pane whose title, command or keys match: whoever types "desktop" may be after ⌃⌥D.
    public var shortcuts: [ShortcutRow]
    /// The lists that match, as panes to go to.
    public var panes: [Pane]
    public var isEmpty: Bool { sections.isEmpty && shortcuts.isEmpty && panes.isEmpty }
  }

  public struct FoundSection: Equatable, Identifiable, Sendable {
    public let section: SettingsSection
    public let rows: [Row]
    public var id: String { section.title }
  }

  public var found: Found {
    let sections = SettingsSection.allCases.compactMap { section -> FoundSection? in
      let rows = entries(in: section).filter { $0.matches(search: search) }.compactMap(row(for:))
      return rows.isEmpty ? nil : FoundSection(section: section, rows: rows)
    }
    let words = search.lowercased().split(whereSeparator: \.isWhitespace)
    let editors: [Pane] = [.shortcuts, .rules]
    let panes = editors.filter { pane in
      words.allSatisfy { pane.title.lowercased().firstRange(of: $0) != nil }
        || SettingsSchema.entries.contains {
          $0.level != .hidden && Pane.editing($0) == pane && $0.matches(search: search)
        }
    }
    let shortcuts = shortcutRows.filter { row in
      let text = "\(row.title) \(row.command.text) \(row.label ?? "") \(row.chord?.text ?? "")".lowercased()
      return !words.isEmpty && words.allSatisfy { text.firstRange(of: $0) != nil }
    }
    return Found(sections: sections, shortcuts: shortcuts, panes: panes)
  }

  /// Leaves the search for one of the panes it found.
  public func go(to pane: Pane) {
    search = ""
    self.pane = pane
  }

  // MARK: Changing a setting

  /// Why the last change was refused, by what it was made on: a setting's key, a row's id, a pane's id.
  public private(set) var errors: [String: String] = [:]

  /// Runs commands in order, stopping at the first that is refused, whose reason is shown at `place`.
  private func perform(_ commands: [Command], at place: String) {
    errors[place] = nil
    defer { changed() }
    for command in commands {
      let result = run(command)
      guard result.ok else {
        errors[place] = inTheWindowsWords(result.message, at: place)
        return
      }
    }
  }

  /// A refusal is written for a terminal: it names the key, marks code as code, and says which command helps. The window shows
  /// it under the control it is about, as plain text, and has buttons for what helps.
  private func inTheWindowsWords(_ message: String, at place: String) -> String {
    // The banner has the reason and the ways out.
    if fileProblem != nil, message.hasPrefix("settings.json cannot be read") {
      return "Nothing was changed: settings.json cannot be read"
    }
    var words = message
    if words.hasPrefix("`\(place)` ") {
      words.removeFirst(place.count + 3)
      words = words.prefix(1).uppercased() + words.dropFirst()
    }
    return Self.withoutCodeMarks(words)
  }

  /// Nothing in the window draws a backtick as anything but a backtick. They come in pairs, and what stands between two of them
  /// is a word of the file's or something somebody typed: quoted.
  static func withoutCodeMarks(_ text: String) -> String {
    let parts = text.split(separator: "`", omittingEmptySubsequences: false)
    return parts.enumerated().map { index, part in index % 2 == 1 && index < parts.count - 1 ? "“\(part)”" : String(part) }.joined()
  }

  private func perform(_ commands: [SettingsCommand], at place: String) {
    perform(commands.map(Command.settings), at: place)
  }

  /// A switch flipped, a choice picked, text entered: `text` is what `set` would be given, but for a share, which the window
  /// counts in per cent.
  public func set(_ key: String, to text: String) {
    guard let entry = try? SettingsSchema.entry(named: key), Self.isShare(entry), case .number(let range, _, _) = entry.kind else {
      return perform([.set(key: key, value: text)], at: key)
    }
    // Refused here: the command's own words would count from 0 to 1 under a field that says 25 %.
    let accepts = "from \(Self.text(Self.tidy(range.lowerBound * 100))) to \(Self.text(Self.tidy(range.upperBound * 100))) %"
    let typed = text.filter { !$0.isWhitespace && $0 != "%" }
    guard let percent = Double(typed), percent.isFinite else { return refuse("Needs a number \(accepts), got “\(typed)”", at: key) }
    let share = Self.tidy(percent / 100)
    guard range.contains(share) else { return refuse("Must be \(accepts), got \(Self.text(percent))", at: key) }
    perform([.set(key: key, value: Self.text(share))], at: key)
  }

  private func refuse(_ reason: String, at place: String) {
    errors[place] = reason
    changed()
  }

  /// A number from 0 to 1 at most that is measured in nothing: a share of some whole.
  private static func isShare(_ entry: SettingEntry) -> Bool {
    guard case .number(let range, _, let unit) = entry.kind else { return false }
    return unit.isEmpty && range.lowerBound >= 0 && range.upperBound <= 1
  }

  /// Without the crumbs binary fractions leave (30.000000000000004).
  private static func tidy(_ value: Double) -> Double { (value * 1_000_000).rounded() / 1_000_000 }

  public func set(_ key: String, to isOn: Bool) { set(key, to: isOn ? "true" : "false") }

  /// A slider let go of. It lands on the nearest step.
  public func set(_ key: String, to value: Double) {
    // As the window counts, which for a share is in per cent.
    guard let entry = try? SettingsSchema.entry(named: key), case .number(_, let range, let step, _)? = row(for: entry)?.control
    else { return }
    set(key, to: Self.text(Self.snapped(value, in: range, step: step)))
  }

  public func reset(_ key: String) { perform([.reset(key: key)], at: key) }

  /// `value` on the nearest step counted from the lower end, inside the range, and without the crumbs
  /// binary fractions leave (0.30000000000000004).
  public static func snapped(_ value: Double, in range: ClosedRange<Double>, step: Double) -> Double {
    guard value.isFinite, step > 0 else { return range.lowerBound }
    let onStep = range.lowerBound + ((value - range.lowerBound) / step).rounded() * step
    return min(max((onStep * 1_000_000).rounded() / 1_000_000, range.lowerBound), range.upperBound)
  }

  /// A number as the field beside a slider shows it, and as `set` reads it.
  public static func text(_ value: Double) -> String { SettingValue.number(value).text }

  // MARK: Restore Defaults

  /// The settings "Restore Defaults" in a section would change: what the section can show, so not the
  /// hidden ones, which nobody looking at the window knows about. And not the lists, which took their owner
  /// longer to make than a click should undo; `reset all` keeps them too.
  public func changedKeys(in section: SettingsSection) -> [String] {
    entries(in: section).filter { entry in
      if case .list = entry.kind { return false }
      return !entry.isDefault(in: settings)
    }.map(\.key)
  }

  /// Whether a section has anything "Restore Defaults" could ever restore.
  public func canRestoreDefaults(in section: SettingsSection) -> Bool {
    entries(in: section).contains { entry in
      if case .list = entry.kind { return false }
      return true
    }
  }

  public func restoreDefaults(in section: SettingsSection) {
    perform(changedKeys(in: section).map { .reset(key: $0) }, at: Pane.section(section).id)
  }

  // MARK: What is wrong with the file

  /// Why settings.json cannot be read. While it is set nothing can be saved, so the window says this
  /// above everything else.
  public var fileProblem: String? { controller.settingsFileProblem }

  /// Values in the file that could not be used as written.
  public var valueProblems: [String] { settings.valueProblems.map(Self.withoutCodeMarks) }

  /// The way out of a file that cannot be read. Asks first.
  public func replaceFileWithDefaults() { ask(.replaceFile) }

  // MARK: Asking first

  /// What is done at a click and cannot be taken back with another. The window asks, in the place of the button.
  public enum Question: Equatable, Sendable {
    /// `count` changes to the shortcuts would go.
    case restoreAllShortcuts(count: Int)
    case replaceFile

    public var text: String {
      switch self {
      case .restoreAllShortcuts(let count):
        "Give up \(count == 1 ? "your 1 change" : "all \(count) of your changes") to the shortcuts? "
          + "A copy of the file stays beside it, as settings.before-reset.json."
      case .replaceFile:
        "Replace settings.json with the defaults? Your shortcuts, rules and lists of apps go with it. "
          + "The old file stays beside the new one, as settings.unreadable.json."
      }
    }

    /// The button that goes ahead.
    public var confirmation: String {
      switch self {
      case .restoreAllShortcuts: "Restore All Shortcuts"
      case .replaceFile: "Replace It"
      }
    }
  }

  /// What the window is asking just now.
  public private(set) var question: Question?

  private func ask(_ question: Question) {
    self.question = question
    changed()
  }

  public func answer(yes: Bool) {
    guard let asked = question else { return }
    question = nil
    guard yes else { return changed() }
    switch asked {
    case .restoreAllShortcuts: perform([.reset(key: "bindings")], at: Pane.shortcuts.id)
    case .replaceFile: perform([.resetAll(everything: true)], at: "file")
    }
  }

  // MARK: Login item

  /// "Open at Login", which macOS keeps, not settings.json. Not shown where this copy of Arbor cannot be opened at login
  /// (it does not run from an app bundle).
  public var hasLoginItem: Bool {
    switch controller.loginItem?.status {
    case nil, .unavailable: false
    case .enabled, .disabled, .requiresApproval: true
    }
  }

  /// Arbor asked to be opened at login and the user has switched it off in System Settings, where alone it can be switched
  /// on again: the window offers to go there.
  public var loginItemNeedsApproval: Bool { controller.loginItem?.status == .requiresApproval }

  /// Asked each time: it can be changed in System Settings as well.
  public var opensAtLogin: Bool { controller.loginItem?.status == .enabled }

  public func setOpensAtLogin(_ isOn: Bool) { perform([Command.launchAtLogin(isOn)], at: "login") }

  // MARK: Shortcuts

  /// One line of the Shortcuts pane: a command, and what runs it.
  public struct ShortcutRow: Equatable, Identifiable, Sendable {
    public let command: Command
    /// The shortcut that runs it now. Nil: its default one was removed, or given to another command.
    public let chord: KeyChord?
    /// Its default shortcut. Nil for a shortcut of the user's own.
    public let standard: KeyChord?
    /// `chord` as menus show it on the keyboard layout in use: ⌃⌥Ü.
    public let label: String?
    /// What the line is called: the command as the menu and the panel of shortcuts name it.
    public var title: String { command.title }
    public var isChanged: Bool { chord != standard }
    /// What to mind about the shortcut it has, e.g. that no app gets ⌘Q while Arbor runs.
    public var caution: String? { chord?.caution }
    /// A command that has no line yet: the user typed it, to record its first shortcut.
    public var isNew: Bool { chord == nil && standard == nil }
    public var id: String { "\(command.text) \(standard?.text ?? chord?.text ?? "")" }
  }

  /// Where a refusal about a line is shown: on the line, or on the pane if it has none yet.
  private func place(of row: ShortcutRow) -> String { row.isNew ? Pane.shortcuts.id : row.id }

  /// Every default shortcut in its usual order, each with what runs its command now, then the user's own
  /// by command. A default whose command was moved to other keys stays one line.
  public var shortcutRows: [ShortcutRow] {
    var free = controller.effectiveBindings.bindings
    func take(where matches: (KeyBinding) -> Bool) -> KeyBinding? {
      free.firstIndex(where: matches).map { free.remove(at: $0) }
    }
    // The untouched ones first, so that none of them is taken for the new keys of another line.
    let untouched = KeyBindings.defaults.map { standard in
      take { $0.chord == standard.chord && $0.command == standard.command }
    }
    var rows = zip(KeyBindings.defaults, untouched).map { standard, same in
      let now = same ?? take { $0.command == standard.command }
      return ShortcutRow(command: standard.command, chord: now?.chord, standard: standard.chord, label: now?.label)
    }
    rows += free.sorted { ($0.command.text, $0.chord.text) < ($1.command.text, $1.chord.text) }.map {
      ShortcutRow(command: $0.command, chord: $0.chord, standard: nil, label: $0.label)
    }
    return rows
  }

  /// Some lines under a heading.
  public struct ShortcutSection: Equatable, Identifiable, Sendable {
    public let title: String
    public let rows: [ShortcutRow]
    public var id: String { title }
  }

  /// The lines in the three groups of the panel of shortcuts, each in the table's order, then the user's own.
  public var shortcutSections: [ShortcutSection] {
    let rows = shortcutRows
    let groups = Command.Group.allCases.map { group in
      ShortcutSection(title: group.title, rows: rows.filter { $0.standard != nil && $0.command.group == group })
    }
    return (groups + [ShortcutSection(title: "Your own", rows: rows.filter { $0.standard == nil })]).filter { !$0.rows.isEmpty }
  }

  /// Entries of `bindings` in settings.json that could not be used, and why.
  public var shortcutProblems: [String] { controller.effectiveBindings.problems.map(Self.withoutCodeMarks) }

  public var shortcutsAreOff: Bool { !settings.hotkeysEnabled }

  /// The line whose next key press becomes its shortcut.
  public private(set) var recording: ShortcutRow? {
    didSet {
      guard (recording == nil) != (oldValue == nil) else { return }
      controller.isRecordingShortcut = recording != nil
      onRecordingChanged?(recording != nil)
    }
  }

  /// A recorded shortcut that another command has. It waits for `replaceHolder()` or `cancelRecording()`.
  public struct Clash: Equatable, Sendable {
    public let row: ShortcutRow
    public let chord: KeyChord
    /// `chord` as menus show it on the keyboard layout in use.
    public let label: String
    public let holder: Command
    /// What the holder's shortcut is written as, which can be another name for the same key (`us:z` and `y`).
    public let holderChord: KeyChord
    public var message: String { "\(label) runs \(holder.title) now." }
  }

  public private(set) var clash: Clash?

  public func startRecording(_ row: ShortcutRow) {
    clash = nil
    errors[place(of: row)] = nil
    recording = row
    changed()
  }

  public func cancelRecording() {
    guard recording != nil || clash != nil else { return }
    recording = nil
    clash = nil
    changed()
  }

  /// A key went down while recording: its virtual key code and the modifiers held. Returns whether the
  /// press was used, so that the window keeps it from doing anything else.
  public func keyPressed(code: UInt32, modifiers: KeyChord.Modifiers) -> Bool {
    guard let row = recording else { return false }
    guard let chord = KeyChord(code: code, modifiers: modifiers, layout: controller.layoutInEffect) else {
      errors[place(of: row)] = "that key cannot be part of a shortcut"
      changed()
      return true
    }
    // Escape alone is the way out, as everywhere.
    if chord.key == .escape, modifiers.isEmpty {
      cancelRecording()
      return true
    }
    record(chord, for: row)
    return true
  }

  private func record(_ chord: KeyChord, for row: ShortcutRow) {
    recording = nil
    // By the key, not by its name: two names can mean one key on this layout.
    let layout = controller.layoutInEffect
    if let old = row.chord, old.modifiers == chord.modifiers, old.code(in: layout) == chord.code(in: layout) {
      return changed()
    }
    let holder = controller.effectiveBindings.bindings.first {
      $0.keyCode == chord.code(in: layout) && $0.modifiers == chord.modifiers
    }
    if let holder, holder.command != row.command {
      clash = Clash(
        row: row, chord: chord, label: chord.label(in: layout), holder: holder.command, holderChord: holder.chord)
      return changed()
    }
    give(chord, to: row)
  }

  /// Takes the shortcut away from the command that has it.
  public func replaceHolder() {
    guard let clash else { return }
    self.clash = nil
    give(clash.chord, to: clash.row, takingFrom: clash.holderChord)
  }

  /// First the new shortcut, which can be refused, and only then away with the old one, and with the holder's if that
  /// is written otherwise (written the same, `bind` has replaced it).
  private func give(_ chord: KeyChord, to row: ShortcutRow, takingFrom holder: KeyChord? = nil) {
    var commands: [SettingsCommand] = [.bind(chord: chord.text, command: row.command.text)]
    if let holder, holder != chord { commands.append(.unbind(chord: holder.text)) }
    if let old = row.chord { commands.append(.unbind(chord: old.text)) }
    perform(commands, at: place(of: row))
  }

  /// The command keeps its line, if it has a default, and runs on no shortcut.
  public func removeShortcut(_ row: ShortcutRow) {
    guard let chord = row.chord else { return }
    perform([.unbind(chord: chord.text)], at: row.id)
  }

  /// Back to the default shortcut. A shortcut of the user's own has none, so it goes.
  public func restoreShortcut(_ row: ShortcutRow) {
    var commands: [SettingsCommand] = []
    if let standard = row.standard { commands.append(.bind(chord: standard.text, command: row.command.text)) }
    if let chord = row.chord, chord != row.standard { commands.append(.unbind(chord: chord.text)) }
    perform(commands, at: row.id)
  }

  public var shortcutsAreChanged: Bool { !settings.bindings.isEmpty }

  /// Asks first.
  public func restoreAllShortcuts() {
    guard shortcutsAreChanged else { return }
    ask(.restoreAllShortcuts(count: settings.bindings.count))
  }

  /// Records a first shortcut for a command typed by the user. If the text is not a command, the pane
  /// shows why.
  public func startRecording(commandText: String) {
    do {
      startRecording(ShortcutRow(command: try Command.parse(commandText), chord: nil, standard: nil, label: nil))
    } catch {
      errors[Pane.shortcuts.id] = "\(error)"
      changed()
    }
  }

  // MARK: Rules

  /// What a rule does, without its particulars: what the first menu of a rule's line offers.
  public enum RuleKind: String, CaseIterable, Identifiable, Sendable {
    case dock, dockBeside, dockAuto, float, pin, ignore

    public var id: String { rawValue }

    public var title: String {
      switch self {
      case .dock: "Dock at the edge"
      case .dockBeside: "Dock beside"
      case .dockAuto: "Dock beside the focused window"
      case .float: "Float"
      case .pin: "Float and keep in view"
      case .ignore: "Leave alone"
      }
    }

    public init(_ action: RuleAction) {
      switch action {
      case .dock: self = .dock
      case .dockBeside: self = .dockBeside
      case .dockAuto: self = .dockAuto
      case .float: self = .float
      case .pin: self = .pin
      case .ignore: self = .ignore
      }
    }
  }

  public struct RuleRow: Equatable, Identifiable, Sendable {
    /// Counted from 1, as `rules` lists them.
    public let number: Int
    public let rule: AppRule
    public let appName: String
    public var kind: RuleKind { RuleKind(rule.action) }
    /// The edge it docks at, if it docks.
    public var edge: Edge? {
      switch rule.action {
      case .dock(let edge), .dockBeside(_, let edge): edge
      case .dockAuto, .float, .pin, .ignore: nil
      }
    }
    /// The app it docks beside, if it does.
    public var neighbour: String? {
      if case .dockBeside(let bundleID, _) = rule.action { bundleID } else { nil }
    }
    public var id: Int { number }
  }

  public var ruleRows: [RuleRow] {
    settings.rules.enumerated().map { RuleRow(number: $0 + 1, rule: $1, appName: name(of: $1.app)) }
  }

  /// Entries of `rules` in settings.json that could not be read, and why.
  public var skippedRules: [String] { settings.skippedRules.map(Self.withoutCodeMarks) }

  /// Starts from the rule as it is now, not as it was when the line was drawn: a title typed on the line is
  /// handed over just before its menus act.
  private func change(_ row: RuleRow, _ edit: (inout AppRule) -> Void) {
    guard settings.rules.indices.contains(row.number - 1) else { return }
    let old = settings.rules[row.number - 1]
    var rule = old
    edit(&rule)
    guard rule != old else { return }
    perform([.changeRule(row.number, rule)], at: Pane.rules.id)
  }

  /// A new rule starts as the commonest one and is adjusted on its line.
  public func addRule(app bundleID: String) {
    perform([.addRule(AppRule(app: bundleID, action: .dock(.right)))], at: Pane.rules.id)
  }

  public func removeRule(_ row: RuleRow) { perform([.removeRule(row.number)], at: Pane.rules.id) }

  public func canMove(_ row: RuleRow, by offset: Int) -> Bool {
    (1...max(settings.rules.count, 1)).contains(row.number + offset)
  }

  /// -1 is up, towards being checked first.
  public func moveRule(_ row: RuleRow, by offset: Int) {
    guard canMove(row, by: offset) else { return }
    perform([.moveRule(row.number, to: row.number + offset)], at: Pane.rules.id)
  }

  /// Keeps the edge and the neighbour the rule had, where the new kind has a use for them.
  public func setKind(_ kind: RuleKind, of row: RuleRow) {
    change(row) { rule in
      let edge = row.edge ?? .right
      switch kind {
      case .float: rule.action = .float
      case .pin: rule.action = .pin
      case .ignore: rule.action = .ignore
      case .dock: rule.action = .dock(edge)
      case .dockAuto: rule.action = .dockAuto
      case .dockBeside:
        // Some app has to be named; the menu beside it is there to name another.
        let other = appsForRules.first { $0.bundleID != rule.app }?.bundleID
        rule.action = .dockBeside(bundleID: row.neighbour ?? other ?? rule.app, edge)
      }
    }
  }

  public func setEdge(_ edge: Edge, of row: RuleRow) {
    change(row) { rule in
      switch rule.action {
      case .dock: rule.action = .dock(edge)
      case .dockBeside(let bundleID, _): rule.action = .dockBeside(bundleID: bundleID, edge)
      case .dockAuto, .float, .pin, .ignore: break
      }
    }
  }

  public func setNeighbour(_ bundleID: String, of row: RuleRow) {
    change(row) { rule in
      if case .dockBeside(_, let edge) = rule.action { rule.action = .dockBeside(bundleID: bundleID, edge) }
    }
  }

  /// Empty text means any title.
  public func setTitle(_ text: String, of row: RuleRow) {
    let words = text.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    change(row) { $0.title = words.isEmpty ? nil : words }
  }

  // MARK: Lists of apps

  public func add(_ bundleID: String, to key: String) { perform([.addApp(key: key, app: bundleID)], at: key) }

  public func remove(_ bundleID: String, from key: String) { perform([.removeApp(key: key, app: bundleID)], at: key) }

  // MARK: Apps

  /// Running apps by name, for the menus that add a rule or name a neighbour.
  public var appsForRules: [AppChoice] { apps }

  /// An app's name if it is running, otherwise its bundle id, which is all that is known of it.
  public func name(of bundleID: String) -> String {
    apps.first { $0.bundleID.lowercased() == bundleID.lowercased() }?.name ?? bundleID
  }
}

extension SettingsPane {
  /// The name of an SF Symbol, all from the first two sets so that every macOS Arbor runs on has them.
  public var symbol: String {
    switch self {
    case .section(.general): "gearshape"
    case .section(.windows): "macwindow"
    case .section(.dragging): "hand.draw"
    case .section(.tabs): "square.stack"
    case .section(.gestures): "hand.tap"
    case .section(.calls): "video"
    case .section(.appearance): "paintbrush"
    case .section(.menuBar): "menubar.rectangle"
    case .section(.apps): "square.grid.2x2"
    case .section(.scripting): "terminal"
    case .shortcuts: "keyboard"
    case .rules: "list.bullet"
    }
  }
}
