import CoreGraphics

/// The shortcuts on screen (`show-shortcuts`, docs/features/F43-say-what-happened.md): every shortcut in effect, in the
/// help's three groups and the help's order, with the names from `Command.title`, and then what the pointer and the
/// trackpad do. A panel draws it as it is.
public struct CheatSheetModel: Equatable, Sendable {
  public struct Row: Equatable, Sendable {
    /// ⌃⌥Space, ⌃⌥1–9, ⌃⌥⌘ + arrow.
    public var keys: String
    public var title: String

    /// Arbor's own titles are shorter. A shortcut of one's own can run `layout` with a line of any length, and
    /// the panel, which shrinks until it fits its display, would shrink every other row with it.
    static let longestTitle = 48

    public init(keys: String, title: String) {
      self.keys = keys
      self.title = title.count > Self.longestTitle ? title.prefix(Self.longestTitle - 1) + "…" : title
    }
  }

  public struct Section: Equatable, Sendable {
    public var title: String
    public var rows: [Row]
  }

  public var title = "Keyboard Shortcuts"
  /// The sections side by side, each column read from the top.
  public var columns: [[Section]]
  public var footer = "Press any key to close"
  /// What to centre the panel in: the display's visible frame, in global coordinates.
  public var area: CGRect = .zero

  public var sections: [Section] { columns.flatMap { $0 } }

  /// `shortcuts` are the ones in effect, in any order. `pointer` is a last section, for what is done without keys
  /// (`pointerRows(settings:)`); empty leaves it out. Keys are shown as they are labelled on `layout` (F44).
  public init(shortcuts: [(chord: KeyChord, command: Command)], pointer: [Row] = [], layout: KeyLayout = .us) {
    var remaining = shortcuts
    var entries: [Entry] = []

    // ⌃⌥1 to ⌃⌥9 are one thing to know, not nine. A family is folded into one row only when all of it is there under
    // the same modifiers, each member on its own key; after a change to one of them the rest are listed singly.
    for family in Self.families {
      let modifiers = Set(remaining.filter { family.index(of: $0.command) != nil }.map(\.chord.modifiers.rawValue))
      for raw in modifiers.sorted() {
        let held = KeyChord.Modifiers(rawValue: raw)
        func isMember(_ shortcut: (chord: KeyChord, command: Command)) -> Bool {
          family.members.contains { $0.command == shortcut.command && KeyChord(held, $0.key) == shortcut.chord }
        }
        guard remaining.filter(isMember).count == family.members.count else { continue }
        remaining.removeAll(where: isMember)
        let first = family.members[0].command
        entries.append(
          Entry(
            group: first.group, order: first.helpOrder, rank: family.members.count,
            row: Row(keys: held.label + family.keys, title: family.title)))
      }
    }
    for shortcut in remaining {
      let rank = Self.families.lazy.compactMap { $0.index(of: shortcut.command) }.first ?? 0
      entries.append(
        Entry(
          group: shortcut.command.group, order: shortcut.command.helpOrder, rank: rank,
          row: Row(keys: shortcut.chord.label(in: layout), title: shortcut.command.title)))
    }

    entries.sort { a, b in
      (a.group.rawValue, a.order, a.rank, a.row.title, a.row.keys) < (b.group.rawValue, b.order, b.rank, b.row.title, b.row.keys)
    }
    var sections = Command.Group.allCases.compactMap { group -> Section? in
      let rows = entries.filter { $0.group == group }.map(\.row)
      return rows.isEmpty ? nil : Section(title: group.title, rows: rows)
    }
    if !pointer.isEmpty { sections.append(Section(title: "Pointer and trackpad", rows: pointer)) }
    columns = Self.columns(of: sections)
  }

  /// What the pointer and the trackpad do under these settings, as in docs/KEYBOARD.md. A feature that adds a gesture
  /// adds its row at the end.
  public static func pointerRows(settings: Settings) -> [Row] {
    var rows: [Row] = []
    let docks = DragDocks(setting: settings.dragDocks)
    let drag = docks == .held ? "⌘ + drag" : "Drag"
    if docks != .never, settings.dropOptions.offersScreenEdges { rows.append(Row(keys: "\(drag) to a screen edge", title: "Dock")) }
    if docks != .never, settings.dropOptions.offersWindowEdges { rows.append(Row(keys: "\(drag) to a window’s edge", title: "Dock Beside It")) }
    rows += [Row(keys: "Drag a gap", title: "Resize Both Sides"), Row(keys: "Click a tile", title: "Zoom In on It")]
    if settings.gesturesEnabled { rows.append(Row(keys: "⌥ + pinch", title: "Zoom")) }
    if let held = RectangleGesture.Modifiers(text: settings.frameRectangleModifier), !held.isEmpty {
      rows.append(Row(keys: held.label + " + drag", title: "Frame What Is Inside"))
    }
    if settings.frameRectangleOnDesktop { rows.append(Row(keys: "⇧ + drag on the Desktop", title: "Frame What Is Inside")) }
    return rows
  }

  private struct Entry {
    var group: Command.Group
    var order: Int
    /// Among rows for the same verb: left before right, 1 before 2, single members before the folded row.
    var rank: Int
    var row: Row
  }

  // MARK: Families

  private struct Family {
    var title: String
    /// What stands for the members' keys after the modifiers.
    var keys: String
    var members: [(command: Command, key: KeyChord.Key)]

    func index(of command: Command) -> Int? { members.firstIndex { $0.command == command } }
  }

  private static let families: [Family] = {
    func arrow(_ edge: Edge) -> KeyChord.Key {
      switch edge {
      case .left: .left
      case .right: .right
      case .top: .up
      case .bottom: .down
      }
    }
    let digits: [KeyChord.Key] = [.digit1, .digit2, .digit3, .digit4, .digit5, .digit6, .digit7, .digit8, .digit9]
    return [
      Family(
        title: "Neighboring Space", keys: " + arrow", members: Edge.allCases.map { (.neighbor($0), arrow($0)) }),
      Family(
        title: "Neighboring Window", keys: " + arrow", members: Edge.allCases.map { (.focus(.direction($0)), arrow($0)) }),
      Family(
        title: "Dock Focused Window, or Move It", keys: " + arrow",
        members: Edge.allCases.map { (.dock(nil, $0), arrow($0)) }),
      Family(title: "Go to a Saved View", keys: "1–9", members: digits.enumerated().map { (.goToView($0 + 1), $1) }),
      Family(title: "Save the View", keys: "1–9", members: digits.enumerated().map { (.saveView($0 + 1), $1) }),
    ]
  }()

  // MARK: Columns

  /// A short list is one column. A longer one is two of about the same height, keeping the sections whole and in
  /// order; three when even that would be taller than a small display.
  static func columns(of sections: [Section]) -> [[Section]] {
    guard !sections.isEmpty else { return [] }
    // A heading and the space above it take about two rows.
    let heights = sections.map { $0.rows.count + 2 }
    guard heights.reduce(0, +) > 14 else { return [sections] }
    var cuts = evenCuts(heights[...], into: 2)
    if cuts.tallest > 24 { cuts = evenCuts(heights[...], into: 3) }
    let bounds = [0] + cuts.at + [sections.count]
    return zip(bounds, bounds.dropFirst()).map { Array(sections[$0..<$1]) }
  }

  /// Where to cut `heights` into at most `count` runs so that the tallest run is as low as can be; of equally good
  /// ways, the one that fills the earlier columns. There are a handful of sections, so it tries every way.
  private static func evenCuts(_ heights: ArraySlice<Int>, into count: Int) -> (at: [Int], tallest: Int) {
    var best = (at: [Int](), tallest: heights.reduce(0, +))
    guard count > 1, heights.count > 1 else { return best }
    for cut in heights.indices.dropFirst() {
      let rest = evenCuts(heights[cut...], into: count - 1)
      let tallest = max(heights[..<cut].reduce(0, +), rest.tallest)
      if tallest <= best.tallest { best = ([cut] + rest.at, tallest) }
    }
    return best
  }

  // MARK: As text

  /// The same list for a terminal, which is also what `show-shortcuts` replies.
  public var text: String {
    let width = sections.flatMap(\.rows).map(\.keys.count).max() ?? 0
    return sections.map { section in
      ([section.title] + section.rows.map { row in
        "  " + row.keys + String(repeating: " ", count: width - row.keys.count + 2) + row.title
      }).joined(separator: "\n")
    }.joined(separator: "\n\n")
  }
}

extension KeyChord.Modifiers {
  /// The glyphs in the order macOS menus show them: ⌃⌥⇧⌘.
  public var label: String { Self.order.filter { contains($0.modifier) }.map(\.glyph).joined() }
}

extension RectangleGesture.Modifiers {
  /// The same for the keys held during a drag.
  public var label: String {
    let glyphs: [(RectangleGesture.Modifiers, String)] = [(.control, "⌃"), (.option, "⌥"), (.shift, "⇧"), (.command, "⌘")]
    return glyphs.filter { contains($0.0) }.map(\.1).joined()
  }
}
