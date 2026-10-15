import CoreGraphics

/// Somewhere the finder ("Go to…") can take the user, or something it can do for them.
public enum FinderDestination: Hashable, Sendable, CustomStringConvertible {
  case window(WindowID)
  /// A saved view: one of a display's slots 1–9.
  case view(DisplayID, slot: Int)
  /// A named space: a node of a display's tree.
  case space(DisplayID, NodeID)
  /// A command, in its text form (`Command.text`): `dock left`.
  case command(String)

  /// For messages and the log: `w101`, `view 3`, `space n4`, `command dock`. Never a title or a name: of a command only its
  /// first word, since what follows can be a name somebody gave.
  public var description: String {
    switch self {
    case .window(let window): "\(window)"
    case .view(_, let slot): "view \(slot)"
    case .space(_, let node): "space \(node)"
    case .command(let text): "command \(text.prefix { $0 != " " })"
    }
  }
}

/// Where a destination is, from the point of view of someone looking for it. The raw value is what the
/// finder shows, in the words of docs/GLOSSARY.md.
public enum FinderPlace: String, Codable, Sendable, CaseIterable {
  /// A docked window that is showing.
  case inView = "in view"
  /// Docked outside the view.
  case outOfView = "out of view"
  /// Docked in the view, but too small to show: drawn as a tile, or part of one.
  case tile
  /// Behind the window its tab group shows.
  case tab
  case floating
  /// Floating, and out of view with the Desktop.
  case floatingOutOfView = "floating, out of view"
  /// Pinned (F49): floating, and in view wherever the view goes.
  case keptInView = "kept in view"
  /// Brought over the view by `summon` (F53), and sent away again: not even the Desktop shows it then.
  case summoned
  case stashed = "out of view until summoned"
  case minimized = "minimized"
  /// Its app is hidden (⌘H), the one case that is called hidden.
  case hiddenApp = "hidden"
  /// In macOS's own full screen, on a Space to itself.
  case fullScreen = "full screen"
  case otherSpace = "on another macOS Space"
  /// A window of an app the user told Arbor not to arrange, or one an `ignore` rule matched. It is where its app put it.
  case notArranged = "not arranged"
  case savedView = "saved view"
  case namedSpace = "space"
  /// No place: a row that does something.
  case command
}

/// What the finder shows when it opens: everywhere it can go, in the order an empty query lists it.
/// A snapshot: the list does not change under the user's hands while the palette is open.
public struct FinderModel: Equatable, Sendable {
  public struct Row: Equatable, Sendable {
    public var destination: FinderDestination
    /// The window's app, "View 3", or the space's name.
    public var name: String
    /// The window's title, or the apps in the view or space, as `FinderCandidate.line` leaves it: one
    /// line of at most `detailLimit` characters. Shown, never logged.
    public var detail: String
    public var place: FinderPlace
    public var display: DisplayID
    /// What to call the display. Nil when there is only one, which needs no name.
    public var displayName: String?
    /// For a window: the process whose icon to show, and its app.
    public var pid: Int32?
    public var bundleID: String?
    /// For a command: the key in effect that runs it, as the menu shows it, whether the menu ticks it, and whether it can be chosen
    /// there now or is greyed out.
    public var shortcut: String?
    public var isOn = false
    public var isAvailable = true

    public init(
      destination: FinderDestination, name: String, detail: String, place: FinderPlace, display: DisplayID,
      displayName: String? = nil, pid: Int32? = nil, bundleID: String? = nil
    ) {
      self.destination = destination
      self.name = name
      self.detail = detail
      self.place = place
      self.display = display
      self.displayName = displayName
      self.pid = pid
      self.bundleID = bundleID
    }

    /// What is searched. Only a space's name is a person's own word for a place: typed in full, it is what they mean.
    public var candidate: FinderCandidate {
      FinderCandidate(name: name, detail: detail, isAName: place == .namedSpace, isACommand: place == .command)
    }

    /// A row that runs `command`. `name` is what the menu calls it.
    public static func command(
      _ command: Command, name: String, shortcut: String? = nil, isOn: Bool = false, isAvailable: Bool = true, display: DisplayID
    ) -> Row {
      var row = Row(
        destination: .command(command.text), name: FinderCandidate.line(name, limit: FinderCandidate.nameLimit), detail: "",
        place: .command, display: display)
      (row.shortcut, row.isOn, row.isAvailable) = (shortcut, isOn, isAvailable)
      return row
    }

    /// The short note at the end of a row: "out of view", "minimised, on Studio Display", "command ✓, ⌃⌥F", "command, not now".
    public var note: String {
      if place == .command {
        return place.rawValue + (isOn ? " ✓" : "") + (isAvailable ? shortcut.map { ", \($0)" } ?? "" : ", not now")
      }
      return displayName.map { "\(place.rawValue), on \($0)" } ?? place.rawValue
    }

    /// What stands where a window has its app's icon: the view's number (the digit that recalls it with ⌃⌥),
    /// the first letter of the space's name, or the sign of a command.
    public var badge: String? {
      switch destination {
      case .window: nil
      case .view(_, let slot): String(slot)
      case .space: name.first.map { String($0).uppercased() } ?? ""
      case .command: "⌘"
      }
    }
  }

  /// The display to show the palette on, and the part of it that is free of the menu bar and the Dock
  /// (global coordinates).
  public var display: DisplayID
  public var screen: CGRect
  public var rows: [Row]
  /// What it can do besides. Go to… is about places: a command is not listed until it is called by name.
  public var commands: [Row]
  /// Something the user has to be told, with a beep: what they chose has gone.
  public var notice: String?

  public init(display: DisplayID, screen: CGRect, rows: [Row], commands: [Row] = [], notice: String? = nil) {
    self.display = display
    self.screen = screen
    self.rows = rows
    self.commands = commands
    self.notice = notice
  }

  /// All that can be found: the places, then the commands.
  var everything: [Row] { rows + commands }
}

/// The finder while it is open: the list, what has been typed, what matches and what is selected. All
/// of the palette's behaviour is here, so `FinderPanel` only draws it and passes keys on, and
/// `FakeOverlays` behaves the same in tests.
public struct FinderSession: Equatable, Sendable {
  /// What the empty field says.
  public static let placeholder = "A window, a space, a saved view or a command"

  public private(set) var model: FinderModel
  public private(set) var query = ""
  /// The rows that match `query`, best first. `index` counts through `model.rows` and on through `model.commands`.
  public private(set) var matches: [FinderMatch]
  public private(set) var selection: FinderSelection
  private var candidates: [FinderCandidate]
  private var everything: [FinderModel.Row]

  public init(model: FinderModel) {
    self.model = model
    everything = model.everything
    candidates = everything.map(\.candidate)
    matches = Self.rank("", candidates, places: model.rows.count)
    selection = FinderSelection(count: matches.count, pageSize: FinderLayout.pageSize(on: model.screen))
  }

  /// Best first (`FinderQuery`), but for this: **letters that stand together in a place are that place.** `vie` is Preview, though the word
  /// View begins with it and Hold This View would score higher. Until commands were listed, Return went to Preview, and whoever types
  /// a piece of a name or a title and presses Return must not have run something instead. So no command comes before such a place,
  /// nor before the places that are better still. The places keep their order among themselves, and so do the commands.
  private static func rank(_ text: String, _ candidates: [FinderCandidate], places: Int) -> [FinderMatch] {
    let query = FinderQuery(text)
    guard !query.isEmpty else { return query.rank(Array(candidates.prefix(places))) }
    let ranked = query.rank(candidates)
    guard let last = ranked.lastIndex(where: { $0.index < places && query.foundInOnePiece($0) }) else { return ranked }
    return ranked[...last].filter { $0.index < places } + ranked[...last].filter { $0.index >= places } + ranked[(last + 1)...]
  }

  /// The text in the field changed: match again and select the best. A notice has been read by then.
  public mutating func type(_ text: String) {
    if text != query { model.notice = nil }
    match(text)
  }

  private mutating func match(_ text: String) {
    query = text
    matches = Self.rank(text, candidates, places: model.rows.count)
    selection = FinderSelection(count: matches.count, pageSize: selection.pageSize)
  }

  /// A fresh list while the palette stays open. What was typed stays, and so does the selection if it is
  /// still listed; otherwise the row that took its place is selected.
  public mutating func replace(model newModel: FinderModel) {
    let destination = selected
    let text = query
    let row = selection.index
    self = FinderSession(model: newModel)
    match(text)
    selection.select(matches.firstIndex { everything[$0.index].destination == destination } ?? row)
  }

  public mutating func moveSelection(by rows: Int) { selection.move(by: rows) }
  public mutating func pageSelection(by pages: Int) { selection.page(by: pages) }

  /// One row as it shows.
  public struct Item: Equatable, Sendable {
    public var row: FinderModel.Row
    public var match: FinderMatch
    public var isSelected: Bool
  }

  /// The rows that show, from the top.
  public var items: [Item] {
    selection.visible.map { place in
      Item(row: everything[matches[place].index], match: matches[place], isSelected: place == selection.selected)
    }
  }

  /// What Return would choose.
  public var selected: FinderDestination? {
    selection.selected.map { everything[matches[$0].index].destination }
  }

  /// What shows at `place` from the top, counted from 0: what a click there, or ⌘ and the digit
  /// `place + 1`, chooses.
  public func destination(atVisible place: Int) -> FinderDestination? {
    selection.row(atVisible: place).map { everything[matches[$0].index].destination }
  }

  /// A line to show under the rows, if there is something to say.
  public var message: String? {
    if let notice = model.notice { return notice }
    if model.rows.isEmpty, matches.isEmpty { return "No windows" }
    return matches.isEmpty ? "Nothing matches" : nil
  }

  /// Where everything goes.
  public var layout: FinderLayout {
    FinderLayout(screen: model.screen, rows: selection.visible.count, hasMessage: message != nil)
  }

  /// The palette as text, for arbor-sim: the field, then the rows that show, the selected one marked.
  public var text: String {
    var lines = ["go to: \(query)"]
    for (place, item) in items.enumerated() {
      let detail = item.row.detail.isEmpty ? "" : "  \(item.row.detail)"
      let mark = item.isSelected ? ">" : " "
      lines.append("\(mark) \(place + 1) \(item.row.destination)  \(item.row.name)\(detail)  (\(item.row.note))")
    }
    let hidden = matches.count - selection.visible.count
    if hidden > 0 { lines.append("  and \(hidden) more") }
    if let message { lines.append("  \(message)") }
    return lines.joined(separator: "\n")
  }
}

/// Where the palette and its parts go. The palette's top edge stays put while the list under the field
/// grows and shrinks with what matches.
public struct FinderLayout: Equatable, Sendable {
  public static let width: CGFloat = 600
  public static let maximumRows = 9
  /// The band at the top that holds the text field.
  public static let fieldBand: CGFloat = 56
  public static let rowHeight: CGFloat = 38
  public static let messageHeight: CGFloat = 30
  /// Space above and below the list, and left and right of a row's highlight.
  public static let listPadding: CGFloat = 8
  /// The least distance to keep from the edges of the screen.
  static let margin: CGFloat = 20

  /// The whole palette, in global coordinates.
  public var panel: CGRect
  /// The text field, measured from the palette's top-left corner, y down.
  public var field: CGRect
  /// The magnifying glass before it, measured the same way: over the rows' icons. The words in an empty field are too faint to
  /// be its only label, and are meant to be.
  public var glyph: CGRect
  /// Everything under the field band, measured the same way: the rows, then the message. No height when
  /// there is neither.
  public var list: CGRect
  public var rows: Int
  public var hasMessage: Bool

  /// How many rows a palette on `screen` can show.
  public static func pageSize(on screen: CGRect) -> Int {
    let room = screen.height - 2 * margin - fieldBand - 2 * listPadding - messageHeight
    // Bounded before it becomes an integer: not every height fits one. The comparison also fails for NaN.
    guard room > rowHeight else { return 1 }
    return Int(min(room / rowHeight, CGFloat(maximumRows)))
  }

  private static func height(rows: Int, hasMessage: Bool) -> CGFloat {
    guard rows > 0 || hasMessage else { return fieldBand }
    return fieldBand + 2 * listPadding + CGFloat(rows) * rowHeight + (hasMessage ? messageHeight : 0)
  }

  public init(screen: CGRect, rows: Int, hasMessage: Bool) {
    let rows = min(max(rows, 0), Self.maximumRows)
    self.rows = rows
    self.hasMessage = hasMessage
    let width = max(min(Self.width, screen.width - 2 * Self.margin), 200)
    let height = Self.height(rows: rows, hasMessage: hasMessage)
    // A quarter of the way down, or higher if the longest list would not fit below that.
    let tallest = Self.height(rows: Self.pageSize(on: screen), hasMessage: true)
    let top = max(min(screen.minY + screen.height / 4, screen.maxY - Self.margin - tallest), screen.minY + Self.margin)
    panel = CGRect(x: (screen.midX - width / 2).rounded(), y: top.rounded(), width: width, height: height)
    // A row's icon is 24 points wide, 10 into the row, and its words begin 10 after it. A field's words begin 2 into it.
    glyph = CGRect(x: Self.listPadding + 12, y: (Self.fieldBand - 20) / 2, width: 20, height: 20)
    field = CGRect(x: Self.listPadding + 42, y: 13, width: width - Self.listPadding - 42 - 20, height: 30)
    list = CGRect(x: 0, y: Self.fieldBand, width: width, height: height - Self.fieldBand)
  }

  /// The row at `place` from the top, measured from the top-left corner of `list`.
  public func rowFrame(_ place: Int) -> CGRect {
    CGRect(
      x: Self.listPadding, y: Self.listPadding + CGFloat(place) * Self.rowHeight,
      width: list.width - 2 * Self.listPadding, height: Self.rowHeight)
  }

  /// The line under the rows, measured like them.
  public var messageFrame: CGRect {
    CGRect(
      x: Self.listPadding, y: Self.listPadding + CGFloat(rows) * Self.rowHeight,
      width: list.width - 2 * Self.listPadding, height: Self.messageHeight)
  }

  /// Which row a point in `list` is on.
  public func row(at point: CGPoint) -> Int? {
    (0..<rows).first { rowFrame($0).contains(point) }
  }
}

extension Command {
  /// `text` as it may be written to the log. What `find` looks for is likely to be part of a window's title, and
  /// titles are shown but never logged.
  public var textForLog: String {
    if case .find(.some) = self { return "find …" }
    return text
  }
}
