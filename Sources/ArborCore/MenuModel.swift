/// Arbor's menu, as values: sections of items, each with its title, what choosing it does, whether it is greyed
/// out or ticked, the shortcut shown beside it and its tooltip. `Controller.menuModel()` (Controller+Menu.swift)
/// says what is in it; `StatusMenu` turns each value into an `NSMenuItem` and decides nothing. So what the menu
/// offers in any state is tested without a Mac, and the `menu` command prints it.
///
/// **To add an item, add one line to a section in Controller+Menu.swift** (docs/ARCHITECTURE.md, "The menu").
public struct MenuModel: Equatable, Sendable {
  /// What only the app can do: open a file, show a panel, register with macOS. Everything else is a `Command`.
  public enum AppAction: String, Sendable, CaseIterable {
    case openSettingsFile, showLog, showAbout, quit
  }

  /// A shortcut as a menu shows it, on the keyboard layout in use: Back is ⌃⌥[ on a US keyboard and ⌃⌥Ü on a German one.
  public struct Shortcut: Equatable, Sendable {
    public var modifiers: KeyChord.Modifiers
    /// What AppKit's menus take as the `keyEquivalent`, to draw it right-aligned in the system's own glyphs.
    public var keyEquivalent: String
    /// The whole of it as text, e.g. ⌃⌥Space.
    public var label: String

    public init(_ chord: KeyChord, layout: KeyLayout = .us) {
      modifiers = chord.modifiers
      label = chord.label(in: layout)
      // A key named after a character is shown as what is printed on it; the others are the same on every layout. Taken
      // from the label, so that the two cannot come to differ. Lowercase: AppKit reads a capital as the letter with ⇧.
      let printed = label.drop { glyph in KeyChord.Modifiers.order.contains { $0.glyph == String(glyph) } }
      keyEquivalent = chord.key.character == nil ? chord.key.menuKeyEquivalent : printed.lowercased()
    }
  }

  public struct Item: Equatable, Sendable {
    public enum Action: Equatable, Sendable {
      case run(Command)
      case app(AppAction)
      case submenu([Section])
      /// A line of text: it says something and cannot be chosen.
      case text
    }

    public var title: String
    public var action: Action
    /// False greys the item out. A line of text always is.
    public var isEnabled: Bool
    public var isTicked = false
    /// Shown right-aligned, as macOS shows shortcuts. `showingShortcuts` fills it in for commands.
    public var shortcut: Shortcut?
    /// False for a command whose shortcut would mislead here (it acts on something else than the item names).
    public var showsShortcut = true
    /// The tooltip.
    public var help: String?

    init(_ title: String, _ action: Action) {
      self.title = title
      self.action = action
      isEnabled = action != .text
    }

    // The four kinds of item.

    /// Runs `command`, and shows the shortcut registered for it.
    public static func command(_ title: String, _ command: Command) -> Item { Item(title, .run(command)) }
    public static func app(_ title: String, _ action: AppAction) -> Item { Item(title, .app(action)) }
    public static func text(_ title: String) -> Item { Item(title, .text) }
    public static func submenu(_ title: String, @MenuBuilder _ items: () -> [Item]) -> Item {
      Item(title, .submenu([Section(items: items)]))
    }
    public static func submenu(_ title: String, sections: [Section]) -> Item { Item(title, .submenu(sections)) }

    // What else can be said about one, chained: `.command("Float", .float(nil)).enabled(isDocked)`.

    public func enabled(_ isEnabled: Bool) -> Item { with { $0.isEnabled = $0.isEnabled && isEnabled } }
    public func ticked(_ isTicked: Bool) -> Item { with { $0.isTicked = isTicked } }
    public func help(_ help: String) -> Item { with { $0.help = help } }
    public func withoutShortcut() -> Item { with { $0.showsShortcut = false } }
    public func shortcut(_ chord: KeyChord) -> Item { with { $0.shortcut = Shortcut(chord) } }
    /// Greyed out when the menu bar button for the same place is, and ticked when that button is filled in.
    public func like(_ button: MenuBarModel.Button?) -> Item {
      enabled(button?.isEnabled != false).ticked(button?.isCurrent == true)
    }

    private func with(_ change: (inout Item) -> Void) -> Item {
      var copy = self
      change(&copy)
      return copy
    }

    public var command: Command? {
      if case .run(let command) = action { return command }
      return nil
    }

    public var sections: [Section] {
      if case .submenu(let sections) = action { return sections }
      return []
    }
  }

  /// Items that belong together, under a title or only a separator line.
  public struct Section: Equatable, Sendable {
    public var title: String?
    public var items: [Item]

    public init(_ title: String? = nil, @MenuBuilder items: () -> [Item]) {
      self.title = title
      self.items = items()
    }
  }

  public var sections: [Section]

  /// Sections, and submenus, that turn out empty are left out.
  public init(_ sections: [Section]) {
    self.sections = Self.pruned(sections)
  }

  private static func pruned(_ sections: [Section]) -> [Section] {
    sections.compactMap { section in
      var section = section
      section.items = section.items.compactMap { item in
        guard case .submenu(let inner) = item.action else { return item }
        let kept = pruned(inner)
        guard !kept.isEmpty else { return nil }
        var item = item
        item.action = .submenu(kept)
        return item
      }
      return section.items.isEmpty ? nil : section
    }
  }

  // MARK: Every item

  /// The same menu with every item, in submenus too, put through `change`. For a rule about all of them.
  public func mapItems(_ change: (Item) -> Item) -> MenuModel {
    func map(_ sections: [Section]) -> [Section] {
      sections.map { section in
        var section = section
        section.items = section.items.map { item in
          var item = change(item)
          if case .submenu(let inner) = item.action { item.action = .submenu(map(inner)) }
          return item
        }
        return section
      }
    }
    var copy = self
    copy.sections = map(sections)
    return copy
  }

  /// Each command's item shows the shortcut that runs it.
  public func showingShortcuts(_ shortcut: (Command) -> Shortcut?) -> MenuModel {
    mapItems { item in
      guard item.showsShortcut, item.shortcut == nil, let command = item.command else { return item }
      var item = item
      item.shortcut = shortcut(command)
      return item
    }
  }

  /// Every item, those of submenus after their parent.
  public var allItems: [Item] {
    func flatten(_ sections: [Section]) -> [Item] {
      sections.flatMap { $0.items.flatMap { [$0] + flatten($0.sections) } }
    }
    return flatten(sections)
  }

  /// The first item with this title, wherever it is.
  public func item(_ title: String) -> Item? { allItems.first { $0.title == title } }

  public func section(_ title: String?) -> Section? { sections.first { $0.title == title } }

  // MARK: As text

  /// What `menu` prints: a line per item, indented under its section or parent, with ✓ for a tick, the shortcut
  /// after two spaces, ▸ for a submenu and "(grey)" for what cannot be chosen. A line of dashes stands for the separator
  /// above a section without a title.
  public var text: String {
    func lines(_ sections: [Section], indent: String) -> [String] {
      sections.enumerated().flatMap { index, section -> [String] in
        var out: [String] = []
        if let title = section.title {
          out.append(indent + title)
        } else if index > 0 {
          out.append(indent + "-----")
        }
        for item in section.items {
          var line = indent + (item.isTicked ? "  ✓ " : "    ") + item.title
          if !item.sections.isEmpty { line += " ▸" }
          if let shortcut = item.shortcut { line += "  " + shortcut.label }
          if !item.isEnabled { line += "  (grey)" }
          out.append(line)
          // Under the item's title; a step further where the submenu has titles of its own.
          let titled = item.sections.contains { $0.title != nil }
          out += lines(item.sections, indent: indent + (titled ? "        " : "    "))
        }
        return out
      }
    }
    return lines(sections, indent: "").joined(separator: "\n")
  }
}

/// Lets a section be written as a list of lines, with `if` and `for` where an item is there only sometimes.
@resultBuilder
public enum MenuBuilder {
  public static func buildExpression(_ item: MenuModel.Item) -> [MenuModel.Item] { [item] }
  public static func buildExpression(_ items: [MenuModel.Item]) -> [MenuModel.Item] { items }
  public static func buildBlock(_ parts: [MenuModel.Item]...) -> [MenuModel.Item] { parts.flatMap { $0 } }
  public static func buildOptional(_ part: [MenuModel.Item]?) -> [MenuModel.Item] { part ?? [] }
  public static func buildEither(first part: [MenuModel.Item]) -> [MenuModel.Item] { part }
  public static func buildEither(second part: [MenuModel.Item]) -> [MenuModel.Item] { part }
  public static func buildArray(_ parts: [[MenuModel.Item]]) -> [MenuModel.Item] { parts.flatMap { $0 } }
}
