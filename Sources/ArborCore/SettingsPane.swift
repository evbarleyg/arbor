/// One pane of the settings window: a section of the schema, or the editor of a list that needs one: the shortcuts, the
/// rules. It lives here, not with the window, so that `settings-window shortcuts` is checked
/// like any command, wherever it is written.
public enum SettingsPane: Hashable, Identifiable, Sendable, Codable {
  case section(SettingsSection)
  case shortcuts, rules

  public var id: String { title }

  public var title: String {
    switch self {
    case .section(let section): section.title
    case .shortcuts: "Shortcuts"
    case .rules: "Rules"
    }
  }

  /// Its name in a command: `menu-bar`, `shortcuts`.
  public var word: String { Self.word(title) }

  /// The window's sidebar: the sections that have something to show, in the schema's order (General
  /// always, for "Open at Login"), then the lists.
  public static let all: [SettingsPane] =
    SettingsSection.allCases.filter { $0 == .general || !SettingsSchema.windowEntries(in: $0).isEmpty }.map(Self.section)
    + [.shortcuts, .rules]

  /// The pane called `name`, however it is spelt: `Menu Bar`, `menubar`, `menu-bar`. A list names the pane it is in
  /// too, by its label or key: `don't arrange`, `bindings`.
  public init?(named name: String) {
    let letters = Self.word(name).filter { $0 != "-" }
    if let list = SettingsSchema.list(named: name), list.level != .hidden {
      self = Self.editing(list) ?? .section(list.section)
      return
    }
    guard let pane = Self.all.first(where: { $0.word.filter { $0 != "-" } == letters }) else { return nil }
    self = pane
  }

  /// The pane that edits a list which has one to itself. Nil for every setting that is shown in its section.
  public static func editing(_ entry: SettingEntry) -> SettingsPane? {
    switch entry.key {
    case "bindings": .shortcuts
    case "rules": .rules
    default: nil
    }
  }

  private static func word(_ title: String) -> String {
    title.lowercased().filter { $0 != "’" && $0 != "'" }.split(whereSeparator: \.isWhitespace).joined(separator: "-")
  }
}

extension SettingsSchema {
  /// The settings the window shows in a section's own pane: not the hidden ones, not the two lists that have a pane
  /// to themselves.
  public static func windowEntries(in section: SettingsSection) -> [SettingEntry] {
    entries(in: section).filter { $0.level != .hidden && SettingsPane.editing($0) == nil }
  }
}
