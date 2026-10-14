/// What people call a command, and which part of the help it belongs to
/// (docs/features/F43-say-what-happened.md). The panel of shortcuts and the sentences on screen take their
/// words from here; menus and pickers should too, so that they cannot drift apart. The words are
/// docs/GLOSSARY.md's.
extension Command {
  /// The command's name as a menu would show it: "Show Everything", "Dock Left", "Save View 3".
  ///
  /// A command that is not listed gets its text form in title case ("tab next" becomes "Tab Next"), which
  /// is right surprisingly often; list it when it is not.
  public var title: String {
    listedTitle
      ?? text.split(whereSeparator: { $0 == " " || $0 == "-" }).map { Self.upperFirst(String($0)) }.joined(separator: " ")
  }

  /// The title somebody chose. A command Arbor comes with a shortcut for has to have one, since everybody sees it in the panel
  /// of shortcuts: "Ask Name" is what the text form made of ⌃⌥N.
  public var listedTitle: String? {
    switch self {
    case .showAll: return "Show Everything"
    case .home: return "Show Everything on All Displays"
    case .stepOut: return "Step Out"
    case .stepIn: return "Step In"
    case .back: return "Back"
    case .forward: return "Forward"
    // With its dots, as in the menu: without them the words dangle.
    case .find: return "Go to…"
    case .neighbor(.left): return "Space to the Left"
    case .neighbor(.right): return "Space to the Right"
    case .neighbor(.top): return "Space Above"
    case .neighbor(.bottom): return "Space Below"
    case .zoom(nil): return "Frame Focused Window"
    case .zoom: return "Frame a Window"
    case .zoomNode: return "Frame a Space"
    case .frameRect: return "Frame a Rectangle"
    case .desktop: return "Show the Desktop"
    case .saveView(let slot): return "Save View \(slot)"
    case .goToView(let slot): return "View \(slot)"
    case .dock(_, let edge): return "Dock \(Self.upperFirst(edge.rawValue))"
    case .dockBeside: return "Dock Beside a Window"
    case .float: return "Float Focused Window"
    case .toggleFloat: return "Float or Dock Focused Window"
    case .arrange: return "Arrange Windows"
    case .arrangeAll: return "Arrange Windows on All Displays"
    case .floatAll: return "Float All Windows"
    case .undo: return "Undo"
    case .redo: return "Redo"
    case .floatAllHere: return "Float All Windows on This Display"
    case .resize(_, let edge, let amount):
      return "\(amount < 0 ? "Shrink" : "Grow") \(Self.upperFirst(edge.rawValue))"
    case .exclude(nil): return "Don’t Arrange This App"
    case .exclude(let bundle?): return "Don’t Arrange \(bundle)"
    case .include(let bundle): return "Arrange \(bundle) Again"
    case .relayout: return "Lay Out Again"
    case .quit: return "Quit Arbor"
    case .pause(nil): return "Pause Arbor"
    case .pause(let minutes?):
      return "Pause Arbor for \(Int(exactly: minutes).map(String.init) ?? String(minutes)) \(minutes == 1 ? "Minute" : "Minutes")"
    case .resume: return "Resume Arbor"
    case .togglePause: return "Pause or Resume Arbor"
    case .showShortcuts: return "Keyboard Shortcuts"
    case .minimap: return "Show Minimap"
    case .settings(.showWindow): return "Settings"
    case .pin: return "Keep Focused Window in View"
    case .unpin: return "Stop Keeping Focused Window in View"
    case .togglePin: return "Keep Focused Window in View, or Not"
    case .passThrough(nil, _): return "Shortcuts Off in This App"
    case .passThrough(let bundle?, _): return "Shortcuts Off in \(bundle)"
    case .askName(cancel: false): return "Name This Space"
    case .askName(cancel: true): return "Close the Name Field"
    case .name(let name): return "Name This Space “\(name)”"
    case .unname(nil): return "Remove This Space’s Name"
    case .unname(let name?): return "Remove the Name “\(name)”"
    case .goToSpace(let name): return "Go to “\(name)”"
    case .summon(let app): return "Summon \(app)"
    // Without the parts of window titles it may hold: this is shown on screen, where somebody else may be looking.
    case .layout(let spec, _, let open): return "\(open ? "Open and Arrange" : "Arrange") as \(spec.textWithoutTitles)"
    case .checkForUpdates: return "Check for Updates"
    case .launchAtLogin(false): return "Don’t Open at Login"
    case .launchAtLogin: return "Open at Login"
    case .toggleAutoDock: return "Dock New Windows"
    case .hold: return "Hold This View"
    case .holdStill: return "Hold Still"
    case .release: return "Release the View"
    case .toggleHold: return "Hold This View, or Release It"
    case .focus(.direction(.left)): return "Window to the Left"
    case .focus(.direction(.right)): return "Window to the Right"
    case .focus(.direction(.top)): return "Window Above"
    case .focus(.direction(.bottom)): return "Window Below"
    case .focus(.next): return "Next Window"
    case .focus(.previous): return "Previous Window"
    case .focus(.window): return "Focus a Window"
    case .swap(_, let direction): return "Swap \(Self.upperFirst(direction.directionWord))"
    case .swapWindows: return "Swap Two Windows"
    case .grow: return "Grow"
    case .shrink: return "Shrink"
    case .equalize(all: false): return "Balance Sizes"
    case .equalize(all: true): return "Balance Sizes on the Whole Display"
    case .rotate: return "Rotate Group"
    case .mirror: return "Mirror Group"
    case .moveToDisplay(let target, _): return "Move to \(Self.title(of: target))"
    case .focusDisplay(let target): return "Focus \(Self.title(of: target))"
    default: return nil
    }
  }

  private static func title(of display: DisplayTarget) -> String {
    switch display {
    case .next: "Next Display"
    case .previous: "Previous Display"
    case .number(let number): "Display \(number)"
    }
  }

  private static func upperFirst(_ word: String) -> String {
    word.prefix(1).uppercased() + word.dropFirst()
  }

  /// The first word of the text form: `dock`, `save-view`.
  public var verb: String { String(text.prefix { $0 != " " }) }

  // MARK: The help's groups

  /// The three parts of `help`, of docs/KEYBOARD.md and of the panel of shortcuts.
  public enum Group: Int, CaseIterable, Sendable, Comparable {
    /// Changes the view; the arrangement stays as it is.
    case look
    /// Changes where windows sit.
    case arrange
    case arbor

    /// The group's heading, which is also how its part of `helpText` begins.
    public var title: String {
      switch self {
      case .look: "Look"
      case .arrange: "Arrange"
      case .arbor: "Arbor itself"
      }
    }

    public static func < (a: Group, b: Group) -> Bool { a.rawValue < b.rawValue }
  }

  /// The part of the help that lists the command. One that the help leaves out counts as "Arbor itself".
  public var group: Group { Self.helpIndex[verb]?.group ?? .arbor }

  /// Where the help lists the command, for showing commands in the help's order: smaller is earlier. A command
  /// that the help leaves out comes last.
  public var helpOrder: Int { Self.helpIndex[verb]?.order ?? Int.max }

  /// Read from `helpText` rather than written down a second time: whoever adds a command adds it to the help,
  /// and that puts it in the right group here as well.
  ///
  /// An entry of the help is indented by two spaces and starts with the command, or with several
  /// separated by " | ". What follows a later " | " may be the explanation's second half, so this also picks
  /// up words that are not verbs; nothing looks those up. The first mention of a verb counts.
  static let helpIndex: [String: (group: Group, order: Int)] = {
    var index: [String: (group: Group, order: Int)] = [:]
    var group: Group?
    for (number, line) in helpText.split(separator: "\n", omittingEmptySubsequences: false).enumerated() {
      if let heading = Group.allCases.first(where: { line.hasPrefix($0.title) }) {
        group = heading
        continue
      }
      // Three spaces or more continue the line above.
      guard let group, line.hasPrefix("  "), !line.hasPrefix("   ") else { continue }
      for (position, part) in line.split(separator: "|").enumerated() {
        if let word = part.split(separator: " ").first, index[String(word)] == nil {
          index[String(word)] = (group, number * 100 + position)
        }
      }
    }
    return index
  }()
}
