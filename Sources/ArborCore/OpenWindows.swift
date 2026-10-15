/// Every open window, as Arbor's menu lists them under Windows (docs/MENU.md): by app and title, in the order of use, with a mark
/// for what cannot be seen just now. `Controller.openWindows()` says which there are and where each is; what a row reads is
/// decided here, so that it is tested without a Mac. `StatusMenu` only shows it.
///
/// Titles are shown, never logged.
public struct OpenWindows: Equatable, Sendable {
  public struct Row: Equatable, Sendable {
    public var window: WindowID
    public var app: String
    public var title: String
    public var place: FinderPlace
    /// It is the window being typed in.
    public var hasKeyboard: Bool
    /// The process whose icon to show.
    public var pid: Int32

    public init(window: WindowID, app: String, title: String, place: FinderPlace, hasKeyboard: Bool = false, pid: Int32) {
      self.window = window
      self.app = app
      self.title = title
      self.place = place
      self.hasKeyboard = hasKeyboard
      self.pid = pid
    }

    /// A menu is as wide as its widest row.
    public static let appLimit = 30
    public static let titleLimit = 50

    /// "Safari: Start Page". The app alone where the window has no title, or none that says more.
    public var label: String {
      let (app, title) = (Self.line(app, limit: Self.appLimit), Self.line(title, limit: Self.titleLimit))
      if app.isEmpty { return title.isEmpty ? "Untitled" : title }
      return title.isEmpty || title == app ? app : "\(app): \(title)"
    }

    /// Why it cannot be seen just now. Nil for a window that can: most rows say nothing. The window being typed in on a Space of its own, or
    /// of macOS's, is the one thing that is seen.
    public var mark: String? { hasKeyboard && [.fullScreen, .otherSpace].contains(place) ? nil : place.mark }

    /// The tooltip of a row whose title was cut: more of it.
    public var help: String? {
      let whole = Self.line(title, limit: 4 * Self.titleLimit)
      return whole.count > Self.titleLimit ? whole : nil
    }

    /// One line, without space at its ends, cut with an ellipsis.
    static func line(_ text: String, limit: Int) -> String {
      // Cut roughly before anything is looked at, and by scalars: a title can be as long as its app likes, and so can one character.
      var rough = String.UnicodeScalarView()
      for scalar in FinderCandidate.clip(text, to: 4 * limit).unicodeScalars {
        // What turns the direction of writing round would turn the rest of the row with it; what has no width only hides.
        if scalar.properties.isBidiControl || [0x200B, 0x2060, 0xFEFF].contains(scalar.value) { continue }
        // A title is somebody else's text (a web page's), and `menu` prints it to a terminal: nothing in it gives orders there.
        rough.append(scalar.properties.generalCategory == .control ? " " : scalar)
      }
      let words = String(rough).split(whereSeparator: { $0.isWhitespace || $0.isNewline })
      var line = words.joined(separator: " ")
      var isCut = line.count > limit
      if isCut { line = String(line.prefix(limit - 1)) }
      // A letter under a tower of accents is one character. Four scalars to a character is more than any writing needs on the average.
      if line.unicodeScalars.count > 4 * limit {
        line = String(String.UnicodeScalarView(line.unicodeScalars.prefix(4 * limit)))
        isCut = true
      }
      return isCut ? line.trimmingSuffix(" ") + "…" : line
    }
  }

  public var rows: [Row]

  public init(_ rows: [Row]) { self.rows = rows }
}

extension FinderPlace {
  /// What the list of windows says of a window that cannot be seen where it is. Few words, and macOS's own where it has any: that
  /// a window is a tile, or behind the one its tab group shows, is how it comes to be out of view, which nobody looking for it asks.
  public var mark: String? {
    switch self {
    case .inView, .floating, .keptInView, .summoned, .notArranged, .savedView, .namedSpace, .command: nil
    case .outOfView, .tile, .tab, .floatingOutOfView, .stashed: FinderPlace.outOfView.rawValue
    case .minimized: "minimized"
    case .hiddenApp, .fullScreen: rawValue
    case .otherSpace: "another Space"
    }
  }
}

extension String {
  fileprivate func trimmingSuffix(_ suffix: Character) -> String {
    var copy = self
    while copy.last == suffix { copy.removeLast() }
    return copy
  }
}
