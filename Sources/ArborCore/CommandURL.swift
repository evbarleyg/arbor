/// `arbor://` URLs.
///
/// Hotkeys, the menu and the control socket belong to the person at the Mac. A URL does not: any
/// web page, document, e-mail or chat message can ask macOS to open `arbor://…`, and the browser's
/// "Open Arbor?" question is one careless click. So URLs are parsed strictly, and only commands that
/// move the camera or arrange windows are accepted from them unless the user opts in.
extension Command {
  /// Whether an `arbor://` URL may run this command when `allowAllURLCommands` is off.
  ///
  /// Accepted: looking somewhere else, and arranging windows in ways that are easily put back.
  /// `arrange` rebuilds the whole tree, but it is the first URL TrellisWM publishes (T71).
  /// Everything else is refused, including every command added later until it is listed here:
  /// `quit`, `exclude` and `include`, `float-all`, and anything that changes settings, rules,
  /// shortcuts or saved data could be used to switch Arbor off or to reconfigure it. Queries are
  /// refused because a URL has nowhere to send the answer.
  public var isAllowedFromURL: Bool {
    switch self {
    case .showAll, .stepOut, .stepIn, .neighbor, .back, .forward, .zoom, .zoomNode, .desktop: true
    case .saveView, .goToView, .frameRect: true
    case .dock, .dockBeside, .float, .toggleFloat, .arrange, .resize, .relayout: true
    // `home` only looks, and `arrange all` is `arrange` on each display. `pause` stays off the list: it
    // brings every window into view and takes the shortcuts away. So do `resume` and `toggle-pause`,
    // which would end a pause someone chose, and `float-all here`, with `float-all`.
    case .home, .arrangeAll: true
    case .pin, .unpin, .togglePin: true
    // Both are refused where they would cost a saved view or a name, which only the controller can tell (Controller+URLCost.swift).
    // Arranging is like `arrange`. Opening apps is not something a web page should be able to ask for, and a line that
    // names no window (`layout Desktop`) is `float-all here` by another name.
    case .layout(let spec, _, let open): !open && !spec.slots.isEmpty
    // `go <name>` only looks. `name` and `unname` stay off the list: a page could put its own words into the
    // menu and the replies, or delete names. So does `ask-name`, which opens a field that takes the keyboard.
    case .goToSpace: true
    case .undo, .redo: true
    // A name is the window it stands for, but for an app's. A window's number means nothing to a page, so it cannot aim; an app's name does,
    // and `zoom` and `dock` give the window they name the keyboard, which a page must not pick (see `focus` below). `focused` and
    // `pointer` are chosen by the person at the Mac.
    case .naming(let command, let names): command.isAllowedFromURL && names.allSatisfy { $0 == .focused || $0 == .pointer }
    // The keyboard tiling tools (F22) arrange windows, or step to a neighbour in view, and each is as easily put back. But a
    // web page must not pick the window the keyboard types into: not `focus <window>`, nor `swap <window> <direction>`,
    // which focuses the window it names, nor the commands that take the keyboard to another display.
    case .focus(let target):
      if case .window = target { false } else { true }
    case .swap(let window, _): window == nil
    case .swapWindows, .equalize, .rotate, .mirror, .grow, .shrink: true
    // Not `find` and `reveal`. The palette takes the keyboard, and whatever is being typed with it; and a link that
    // un-minimises, unhides and focuses a window picked by words in its title, perhaps in the middle of a shared screen,
    // is more than moving the view and arranging. Launchers have `arborctl`.
    // Only looks, and holds no words but the user's own.
    case .minimap: true
    default: false
    }
  }

  /// Parses `arbor://dock/left`, `arbor:show-all` or `arbor://zoom/412`: the words of the text form
  /// separated by slashes. A query (`?…`) or fragment (`#…`) is ignored.
  ///
  /// Written without Foundation's `URL`, whose reading of odd input differs between platforms and
  /// releases: what the tests accept and refuse here is what the app accepts and refuses.
  public static func parse(url text: String) throws -> Command {
    if let line = try layoutLine(ofURL: text) { return try parseLayout(line) }
    return try parse(words: words(ofURL: text))
  }

  static let maximumURLLength = 1024

  /// What follows `arbor:`, up to a query or fragment.
  static func path(ofURL text: String) throws -> Substring {
    guard text.utf8.count <= maximumURLLength else {
      throw ParseError("the URL is longer than \(maximumURLLength) bytes")
    }
    guard let colon = text.firstIndex(of: ":"), text[..<colon].lowercased() == "arbor" else {
      throw ParseError("not an arbor:// URL")
    }
    return text[text.index(after: colon)...].prefix { $0 != "?" && $0 != "#" }
  }

  static func words(ofURL text: String) throws -> [String] {
    try path(ofURL: text).split(separator: "/").map { segment in
      guard let word = percentDecoded(segment) else {
        throw ParseError("the URL has a bad % escape")
      }
      // A word is one argument. Spaces would smuggle in more, control characters forge log lines.
      guard word.unicodeScalars.allSatisfy({ !$0.properties.isWhitespace && !isControl($0) && $0 != "/" }) else {
        throw ParseError("the URL has a space, a slash or a control character inside a word")
      }
      return word
    }
  }

  private static func isControl(_ scalar: Unicode.Scalar) -> Bool {
    switch scalar.properties.generalCategory {
    case .control, .format, .lineSeparator, .paragraphSeparator, .surrogate, .unassigned, .privateUse: true
    default: false
    }
  }

  /// Decodes `%41` escapes once. Nil for a truncated or non-hexadecimal escape, and for bytes that
  /// are not UTF-8.
  static func percentDecoded(_ text: Substring) -> String? {
    var bytes: [UInt8] = []
    var input = text.utf8.makeIterator()
    while let byte = input.next() {
      guard byte == UInt8(ascii: "%") else {
        bytes.append(byte)
        continue
      }
      guard let high = input.next().flatMap(hexValue), let low = input.next().flatMap(hexValue) else { return nil }
      bytes.append(high << 4 | low)
    }
    var scalars = String.UnicodeScalarView()
    var decoder = UTF8()
    var iterator = bytes.makeIterator()
    while true {
      switch decoder.decode(&iterator) {
      case .scalarValue(let scalar): scalars.append(scalar)
      case .emptyInput: return String(scalars)
      case .error: return nil
      }
    }
  }

  private static func hexValue(_ byte: UInt8) -> UInt8? {
    switch byte {
    case UInt8(ascii: "0")...UInt8(ascii: "9"): byte - UInt8(ascii: "0")
    case UInt8(ascii: "a")...UInt8(ascii: "f"): byte - UInt8(ascii: "a") + 10
    case UInt8(ascii: "A")...UInt8(ascii: "F"): byte - UInt8(ascii: "A") + 10
    default: nil
    }
  }
}

extension Command.ParseError {
  /// For callers outside the core that refuse a command which did parse.
  public init(refusing description: String) { self.init(description) }
}
