import CoreGraphics

/// The heads-up line (docs/features/F43-say-what-happened.md): what Arbor says on screen to someone who pressed a key,
/// pinched or chose a menu item, and so has nowhere to read the command's reply.
///
/// Everything that can be decided without a screen is decided here: which replies earn a line, in which
/// words, for how long and where. The controller supplies the facts, a panel draws the result.

extension CommandSource {
  /// Whether a person at the Mac asked, who has nowhere to read the reply. A script reads it. A URL may come from
  /// any web page or document, which must not be able to put words on the screen.
  public var isAnsweredOnScreen: Bool {
    switch self {
    case .shortcut, .menu, .gesture: true
    case .script, .url: false
    }
  }
}

/// The `messages` setting: how much Arbor says on screen.
public enum MessageLevel: String, Sendable, CaseIterable {
  /// Every reply, routine successes included.
  case all
  /// Problems, changes that cannot be seen, and the first few teaching moments.
  case helpful
  case off
}

extension Settings {
  /// `messages` as a level. Text that is not one counts as the default, so a typing mistake does not silence Arbor.
  public var messageLevel: MessageLevel { MessageLevel(rawValue: messages.lowercased()) ?? .helpful }
}

/// One line on screen.
public struct HeadsUpModel: Equatable, Sendable {
  public enum Kind: String, Sendable {
    /// The command failed: the key is not dead, there was nothing for it to do.
    case problem
    /// Something changed that cannot be seen.
    case change
    /// A teaching moment.
    case hint
    /// A routine success, shown only at the level `all`.
    case reply
  }

  public var kind: Kind
  public var text: String
  /// What to press next, said more quietly after the text: "⌃⌥Space shows everything".
  public var hint: String?
  /// The middle of the line's bottom edge, in global coordinates.
  public var anchor: CGPoint = .zero
  /// The widest the line may get before it wraps.
  public var maximumWidth: CGFloat = 720
  /// It answers a key, a gesture or a menu item of the person's, rather than being something Arbor says by itself. Only
  /// an answer shows in another app's full-screen Space: whoever pressed Arbor's key there asked Arbor a question.
  public var isAnswer = false

  public init(kind: Kind, text: String, hint: String? = nil) {
    self.kind = kind
    self.text = text
    self.hint = hint
  }

  /// The whole line as one string, as logs, arbor-sim and tests show it.
  public var line: String { hint.map { "\(text) · \($0)" } ?? text }

  /// The line read out, as VoiceOver gets it: two sentences, where the eye has a dot between two weights of type.
  public var spoken: String { hint.map { "\(text). \($0)" } ?? text }

  /// How long the line stays, in seconds: a glance for a few words, and time to read a sentence.
  public var duration: Double { min(max(Self.shortestStay, Double(line.count) * Self.stayPerCharacter), Self.longestStay) }

  static let shortestStay = 1.5
  static let longestStay = 6.0
  /// About 17 characters a second: an unhurried reader who first has to notice the line.
  static let stayPerCharacter = 0.06

  // MARK: Where

  /// From the bottom of the display's visible frame to the lowest of Arbor's passing panels.
  public static let bottomMargin: CGFloat = 56
  /// Between two of them when both show.
  public static let spacing: CGFloat = 10
  static let sideMargin: CGFloat = 32

  /// The line low on a display, centred. `lower` is another passing panel at the bottom of that display (the
  /// minimap), in global coordinates: the line sits directly above it, so that both can show together.
  public func placed(in visibleFrame: CGRect, above lower: CGRect? = nil) -> HeadsUpModel {
    var placed = self
    let bottom = lower.map { $0.minY - Self.spacing } ?? visibleFrame.maxY - Self.bottomMargin
    // On a display too low for all that, still inside it.
    placed.anchor = CGPoint(x: visibleFrame.midX, y: max(bottom, visibleFrame.minY + visibleFrame.height / 2))
    placed.maximumWidth = max(min(720, visibleFrame.width - 2 * Self.sideMargin), 120)
    return placed
  }
}

// MARK: Which replies earn a line

extension Command {
  /// Whether the command leaves nothing to see when it succeeds, so that someone who pressed its keys cannot tell
  /// that it worked. List a new command here if that is true of it.
  public var worksUnseen: Bool {
    switch self {
    case .saveView, .pause, .resume, .togglePause, .exclude, .include, .reloadSettings, .passThrough: true
    // Every window stays where it is; only the gaps stop being handles.
    case .floatAll, .floatAllHere: true
    // Shows only when the view next moves.
    case .pin, .unpin, .togglePin: true
    // A name shows in the menu and in `go`, not on the space.
    case .name, .unname: true
    case .launchAtLogin: true
    // A hold shows in what no longer happens. That it began is not said: the audience is there already (Controller+Hold.swift).
    case .release, .toggleHold: true
    // What changed is easy to miss, and the line names it.
    case .undo, .redo: true
    default: false
    }
  }
}

extension Command {
  /// Whether what the command puts on screen, or takes off it, when it succeeds is answer enough: a panel, a field, a window
  /// of Arbor's own.
  public var opensItsOwnAnswer: Bool {
    switch self {
    case .showShortcuts, .minimap, .askName, .checkSetup, .welcome, .settings(.showWindow), .settings(.closeWindow): true
    // The palette. With text it goes somewhere, or says that it is there already.
    case .find(nil): true
    default: false
    }
  }
}

public enum HeadsUpPolicy {
  /// What kind of line the reply to `command` earns, or nil for none.
  ///
  /// Routine successes stay silent unless asked for: what the key did is on screen already, and a line for every
  /// key press is what makes people switch such lines off.
  ///
  /// `changedNothing`: the command succeeded and left the view, the arrangement, every window and the keyboard as they
  /// were. To the person who pressed the key that looks exactly like a dead key, so the reply is said.
  ///
  /// `namesALoss`: the command did what was asked and took something along that was not (`HeadsUpText.namesALoss`). The windows
  /// moving show the one; nothing shows the other.
  public static func kind(
    of command: Command, ok: Bool, from source: CommandSource, level: MessageLevel, changedNothing: Bool = false,
    namesALoss: Bool = false
  ) -> HeadsUpModel.Kind? {
    guard source.isAnsweredOnScreen, level != .off, !command.isQuery else { return nil }
    guard ok else { return .problem }
    if namesALoss { return .change }
    if command.opensItsOwnAnswer { return nil }
    if command.worksUnseen || changedNothing { return .change }
    return level == .all ? .reply : nil
  }
}

// MARK: Teaching moments

/// What the teaching moments are read from: one display, counted.
public struct HeadsUpFacts: Equatable, Sendable {
  public var docked: Int
  public var outOfView: Int
  public var tiles: Int
  /// Docked windows in view that are wider than their places, and so lie partly over a neighbour (`Layout.overhangs`).
  public var tooWide = 0
  /// The same for those that are only taller.
  public var tooTall = 0

  public init(docked: Int, outOfView: Int, tiles: Int) {
    self.docked = docked
    self.outOfView = outOfView
    self.tiles = tiles
  }

  /// The moments in getting from these facts to `after`, the most pressing first.
  public func moments(to after: HeadsUpFacts) -> [HeadsUpHint] {
    var moments: [HeadsUpHint] = []
    // Only when everything was in view before: that is when windows seem to have gone. Walking from one framed
    // window to the next would otherwise use the hint up in three key presses.
    if outOfView == 0, after.outOfView > 0 { moments.append(.outOfView) }
    if tiles == 0, after.tiles > 0 { moments.append(.tile) }
    // At the act that causes it: one more than before.
    if after.tooWide + after.tooTall > tooWide + tooTall { moments.append(.overlap) }
    // One window. After `arrange` there is no "it" to frame.
    if after.docked == docked + 1 { moments.append(.docked) }
    return moments
  }
}

/// A sentence that explains Arbor at the moment it is needed, a few times ever.
public enum HeadsUpHint: String, Sendable, CaseIterable {
  case outOfView
  case tile
  case docked
  /// A window was let go where macOS itself tiles, and Arbor stood aside (`MacTiling`).
  case leftToMacOS
  /// macOS made a docked window big at a double-click on its title bar, and Arbor stood aside (`AppsDoubleClick`).
  case zoomedByMacOS
  /// A docked window has another frame within a second of a click or a modifier key, and Arbor let it be. Who did it, macOS or its app, Arbor
  /// does not know, so it does not say.
  case leftAsItIs
  /// Docked windows do not fit beside or above each other at their smallest, and lie partly over each other.
  case overlap

  /// How often each is shown before Arbor takes it as read. More than once, because a line that fades
  /// after a few seconds is easily missed the first time.
  public static let timesShown = 3

  /// The sentence. `shortcut` gives the keys in effect for a command, or nil if it has none, in which case the
  /// part that names them is left out.
  public func model(facts: HeadsUpFacts, shortcut: (Command) -> String?) -> HeadsUpModel {
    switch self {
    case .outOfView:
      return HeadsUpModel(
        kind: .hint,
        text: facts.outOfView == 1
          ? "Your other window is out of view, not closed" : "Your other windows are out of view, not closed",
        hint: shortcut(.showAll).map { "\($0) shows everything" })
    case .tile:
      return HeadsUpModel(
        kind: .hint, text: "Too small to show: click the tile to zoom in", hint: shortcut(.find(nil)).map { "\($0) goes there too" })
    case .docked:
      return HeadsUpModel(kind: .hint, text: "Docked", hint: shortcut(.zoom(nil)).map { "\($0) frames it" })
    case .leftToMacOS:
      // First the way that works at once, then the lasting cure, which is no shortcut and is said whatever the keys are.
      let ways = [shortcut(.dock(nil, .left)).map { "\($0) docks it" }, "Check Setup… in the menu"].compactMap { $0 }
      return HeadsUpModel(kind: .hint, text: "macOS tiled this window; Arbor stood aside", hint: ways.joined(separator: " · "))
    case .zoomedByMacOS:
      // Not "double-click again": seen on a Mac, that is a way back only while macOS is set to zoom. Set to fill, it leaves the window filled.
      return HeadsUpModel(
        kind: .hint, text: "macOS zoomed this window",
        hint: shortcut(.showAll).map { "\($0) puts it back" } ?? "Show Everything in the menu puts it back")
    case .leftAsItIs:
      return HeadsUpModel(
        kind: .hint, text: "Left as it is",
        hint: shortcut(.showAll).map { "\($0) puts it back in its place" } ?? "Show Everything in the menu puts it back in its place")
    case .overlap:
      return HeadsUpModel(
        kind: .hint, text: facts.tooWide > 0 ? "Too wide to stand side by side" : "Too tall to stand one above the other",
        hint: "they overlap")
    }
  }
}

extension Command {
  /// The window a command is about: nil for a command that is about none, `.some(nil)` for the focused one.
  public var window: WindowID?? {
    switch self {
    case .zoom(let window), .float(let window), .toggleFloat(let window), .dock(let window, _),
      .dockBeside(let window, _, _), .resize(let window, _, _), .pin(let window), .unpin(let window),
      .togglePin(let window):
      .some(window)
    default: nil
    }
  }

  public var actsOnTheFocusedWindow: Bool { window == .some(nil) }
}

extension Command {
  /// Commands whose shortcut does the same job where this one has none: `resume` is what ⌃⌥⎋ does while paused.
  public var standIns: [Command] {
    switch self {
    case .resume, .pause(nil): [.togglePause]
    case .float(nil): [.toggleFloat(nil)]
    case .showAll: [.home]
    default: []
    }
  }
}

// MARK: The words

/// Turns a command's reply, a lower-case fragment written for a terminal, into a sentence for the screen.
public enum HeadsUpText {
  static let longest = 160

  /// Whether a reply says, after what was asked for, that something else went with it: "arranged 4 windows; 2 saved views are
  /// gone", "docked w7 at the left edge and it is no longer kept in view", "arranged 2 windows; w7 no longer comes and goes with
  /// its key". Read from the words, which are the only place where commands say it; HeadsUpTests runs the commands that do, so
  /// that another wording does not go unheard.
  public static func namesALoss(_ reply: String) -> Bool {
    reply.split(separator: "; ").dropFirst().contains {
      $0.hasSuffix(" is gone") || $0.hasSuffix(" are gone") || $0.contains(" no longer ")
    } || reply.contains(" and it is no longer ") || reply.contains(" and it no longer ")
  }

  /// - "stepped in to Safari and Mail (n5)" loses the node number: "Stepped in to Safari and Mail". So does
  ///   "summoned Notes (w412)", which has named the app already.
  /// - "w412 fills the view" names the app: "Safari fills the view". Never the window's title.
  /// - "view 3 is not saved; `save-view 3` saves where you are looking" names the keys in effect, "⌃⌥⇧3 saves…", or
  ///   the command's title in quotation marks where it has none.
  /// - "no longer arranging com.apple.mail" names the app too, where `bundleName` knows it: "No longer arranging Mail".
  /// - Advice that only makes sense at a terminal ("`state` lists the windows", "…, or name one") is left out.
  public static func sentence(
    from reply: String, appName: (WindowID) -> String?, bundleName: (String) -> String? = { _ in nil },
    shortcut: (Command) -> String?
  ) -> String {
    let clauses = withoutAsides(reply).split(separator: "; ", omittingEmptySubsequences: false)
    var said: [String] = []
    var startsWithName = false
    for (index, clause) in clauses.enumerated() {
      let parts = clause.split(separator: "`", omittingEmptySubsequences: false).map(String.init)
      var words = ""
      var sayable = true
      for (position, part) in parts.enumerated() {
        if position % 2 == 0 {
          let (byWindow, windowFirst) = namingApps(in: part, appName: appName)
          let (text, bundleFirst) = namingBundles(in: byWindow, bundleName: bundleName)
          if index == 0, position == 0 { startsWithName = windowFirst || bundleFirst }
          words += text
        } else if let command = try? Command.parse(part), !command.isQuery {
          words += shortcut(command) ?? "“\(command.title)”"
        } else {
          sayable = false
          words += part
        }
      }
      // The first clause is what happened, so it is said whatever it contains.
      if sayable || index == 0 { said.append(words) }
    }
    var sentence = onOneLine(said.joined(separator: "; "))
    // An app's name keeps its own spelling (iTerm2), and so does the name of a file or a bundle (settings.json).
    let firstWord = sentence.prefix { $0 != " " }
    if !startsWithName, !firstWord.dropLast().contains(".") { sentence = sentence.prefix(1).uppercased() + sentence.dropFirst() }
    return sentence.count > longest ? sentence.prefix(longest - 1) + "…" : sentence
  }

  /// An app can call itself anything, and replies name apps. Nothing that breaks the line or steers the text around it
  /// (reversing the reading direction, say) gets on screen.
  private static func onOneLine(_ text: String) -> String {
    var scalars = String.UnicodeScalarView()
    for scalar in text.unicodeScalars {
      switch scalar.properties.generalCategory {
      case .control, .format, .lineSeparator, .paragraphSeparator, .surrogate, .privateUse, .unassigned: continue
      default: scalars.append(scalar)
      }
    }
    return String(scalars)
  }

  /// Drops " (n5)", " (w412)" and any bracket that quotes a command: those are notes for scripts. With such a bracket goes the
  /// alternative it explains: "click one, or name one (`state` lists their ids)" is "click one" to someone without a terminal.
  private static func withoutAsides(_ text: String) -> String {
    var result = ""
    var rest = Substring(text)
    while let open = rest.firstRange(of: " ("), let close = rest[open.upperBound...].firstIndex(of: ")") {
      let inside = rest[open.upperBound..<close]
      let isNumber = (inside.first == "n" || inside.first == "w") && inside.count > 1 && inside.dropFirst().allSatisfy(\.isNumber)
      result += rest[..<open.lowerBound]
      if !isNumber, !inside.contains("`") { result += rest[open.lowerBound...close] }
      if inside.contains("`"), let alternative = result.ranges(of: ", or ").last,
        !result[alternative.upperBound...].contains(";")
      {
        result.removeSubrange(alternative.lowerBound...)
      }
      rest = rest[rest.index(after: close)...]
    }
    return result + rest
  }

  /// Replaces whole words that are bundle ids `bundleName` knows by what it calls them.
  private static func namingBundles(in text: String, bundleName: (String) -> String?) -> (String, nameFirst: Bool) {
    guard text.contains(".") else { return (text, false) }
    var nameFirst = false
    let words = text.split(separator: " ", omittingEmptySubsequences: false).enumerated().map { index, word -> String in
      let bare = word.prefix(word.count - word.reversed().prefix { ",;:".contains($0) }.count)
      guard bare.contains("."), let name = bundleName(String(bare)) else { return String(word) }
      if index == 0 { nameFirst = true }
      return name + word.dropFirst(bare.count)
    }
    return (words.joined(separator: " "), nameFirst)
  }

  /// Replaces window ids (`w412`) by their apps' names. Also says whether the text now starts with one.
  private static func namingApps(in text: String, appName: (WindowID) -> String?) -> (String, nameFirst: Bool) {
    var result = ""
    var nameFirst = false
    var afterWord = false  // whether the previous character belongs to a word, so that "row2" is left alone
    var index = text.startIndex
    while index < text.endIndex {
      let character = text[index]
      if character == "w", !afterWord {
        let digits = text[text.index(after: index)...].prefix { $0.isASCII && $0.isNumber }
        let end = text.index(index, offsetBy: digits.count + 1)
        let endsWord = end == text.endIndex || !(text[end].isLetter || text[end].isNumber)
        if endsWord, let number = UInt32(digits) {
          let name = appName(WindowID(number))
          if result.isEmpty, name != nil { nameFirst = true }
          // One that Arbor does not know has only its number: "there is no window w999" is "There is no window 999".
          result += name ?? (result.hasSuffix("window ") ? String(number) : "the window")
          index = end
          afterWord = true
          continue
        }
      }
      result.append(character)
      afterWord = character.isLetter || character.isNumber
      index = text.index(after: index)
    }
    return (result, nameFirst)
  }
}
