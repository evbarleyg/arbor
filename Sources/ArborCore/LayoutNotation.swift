/// An arrangement written as a line of text (docs/LAYOUTS.md, docs/features/F54-layouts-as-text.md):
///
///     Safari | Desktop | (Mail / Notes)
///     Xcode:2 | (Simulator / Terminal)
///     [Safari Chrome] | Slack
///
/// `|` puts spaces side by side, `/` one above the other, `( )` groups, `[ ]` makes a tab group, `:n` is a
/// relative size and `Desktop` is the Desktop. A name is an app's name or bundle id, in quotes if it
/// has spaces or punctuation; a number is a window. `Safari*` takes all the Safari windows that
/// remain, as tabs, and `Safari~Inbox` prefers the window with "Inbox" in its title.
///
/// The pieces, all pure:
/// - `LayoutNotation.parse(_:)` turns text into a `Spec`, or says which column is wrong and what was
///   expected there (LayoutNotation+Parser.swift);
/// - `Spec.text` writes it back;
/// - `Spec.resolve(_:)` matches its slots to windows, and `Spec.tree(filling:…)` builds the `LayoutTree`;
///   `Spec(_:slot:)` reads a tree back (LayoutNotation+Tree.swift).
public enum LayoutNotation {
  /// Anything the view can fill: a window or tab group, the Desktop, or a group of spaces.
  public struct Space: Equatable, Sendable {
    public enum Kind: Equatable, Sendable {
      /// `A | B` (horizontal) or `A / B` (vertical).
      case group(Axis, [Space])
      /// One slot is a window; several, or one that takes all, are a tab group.
      case windows([WindowSlot])
      case desktop
    }

    public var kind: Kind
    /// Size among its neighbours. Only ratios matter; 1 is not written. 0, for the Desktop alone: it has no room there.
    public var size: Double

    public init(_ kind: Kind, size: Double = 1) {
      self.kind = kind
      self.size = size
    }
  }

  /// A whole arrangement for one display, as written: names, not windows.
  ///
  /// Every value can be written as text and read back as the same value, because `init` tidies what
  /// it is given: groups have at least two members, tab groups at least one slot, the Desktop and
  /// a window's number appear at most once, and sizes are thousandths from 0.001 to 1000.
  public struct Spec: Equatable, Sendable, CustomStringConvertible {
    public let root: Space

    /// An arrangement with nothing in it is the Desktop alone.
    public init(root: Space) {
      var seen = Seen()
      var tidy = Self.tidied(root, seen: &seen) ?? Space(.desktop)
      // It has no neighbours to be measured against.
      tidy.size = 1
      self.root = tidy
    }

    public var description: String { text }

    /// What has one place only, and has it already. The parser refuses the second; here it is left out.
    private struct Seen {
      var desktop = false
      var windows: Set<WindowID> = []
    }

    private static func tidied(_ space: Space, seen: inout Seen) -> Space? {
      let size = LayoutNotation.tidySize(space.size)
      switch space.kind {
      case .desktop:
        guard !seen.desktop else { return nil }
        seen.desktop = true
        return Space(.desktop, size: space.size == 0 ? 0 : size)
      case .windows(let slots):
        let kept = slots.compactMap(tidied).filter { slot in
          if case .window(let id) = slot.owner { return seen.windows.insert(id).inserted }
          return true
        }
        return kept.isEmpty ? nil : Space(.windows(kept), size: size)
      case .group(let axis, let members):
        var kept: [Space] = []
        for member in members {
          if let tidy = tidied(member, seen: &seen) { kept.append(tidy) }
        }
        guard kept.count > 1 else {
          // Brackets around one thing are that thing, at the size written outside them.
          return kept.first.map { Space($0.kind, size: size) }
        }
        return Space(.group(axis, kept), size: size)
      }
    }

    /// Nil for a name that cannot be written down. A title that cannot is only a lost preference.
    private static func tidied(_ slot: WindowSlot) -> WindowSlot? {
      switch slot.owner {
      case .window(let id):
        return .window(id)
      case .app(let name):
        guard LayoutNotation.canBeWritten(name) else { return nil }
        let title = slot.title.flatMap { LayoutNotation.canBeWritten($0) ? $0 : nil }
        return .app(name, title: title, takesAll: slot.takesAll)
      }
    }
  }

  // MARK: Limits

  /// Longer than any arrangement a display can show, and short enough to read in no time.
  public static let maximumLength = 4096
  /// Brackets inside brackets. Reading, writing and building all go down level by level.
  public static let maximumDepth = 50
  /// Docking beside a window halves its share, so a few docks in one place already make 1 to 128.
  public static let smallestSize = 0.001
  public static let largestSize = 1000.0
  static let maximumNameLength = 200

  /// The nearest size that can be written: thousandths, within the limits. 1 for what is not a number.
  static func tidySize(_ size: Double) -> Double {
    guard !size.isNaN else { return 1 }
    let bounded = min(max(size, smallestSize), largestSize)
    return (bounded * 1000).rounded() / 1000
  }

  // MARK: Writing

  /// "2", "0.5", "1.373": at most three decimals, no zeros at the end.
  static func text(ofSize size: Double) -> String {
    let thousandths = Int((tidySize(size) * 1000).rounded())
    var text = String(thousandths / 1000)
    var fraction = thousandths % 1000
    guard fraction > 0 else { return text }
    var digits = 3
    while fraction % 10 == 0 {
      fraction /= 10
      digits -= 1
    }
    let written = String(fraction)
    text += "." + String(repeating: "0", count: digits - written.count) + written
    return text
  }

  /// Whether `text` can be a name or a title at all, in quotes if need be.
  public static func canBeWritten(_ text: String) -> Bool {
    guard !text.isEmpty, text.count <= maximumNameLength, !text.unicodeScalars.contains(where: isForbidden) else {
      return false
    }
    // A combining mark at the start would join the sign or quote before it into one character, and a few
    // letters at the end join what follows. Neither sign would be seen when the text is read back.
    let quoted = Array("\"" + text + "\"")
    return quoted.count == text.count + 2 && quoted.first == "\"" && quoted.last == "\""
  }

  /// `text` as it has to be written: bare if it is plain letters, digits, `.`, `-` and `_` and cannot be
  /// taken for anything else, otherwise in quotes.
  static func quoted(_ text: String, isName: Bool) -> String {
    let plain = text.allSatisfy(isBare) && text.first != "-"
    let hasOtherMeaning = isName && (text.lowercased() == "desktop" || looksLikeWindowNumber(text))
    if plain, !hasOtherMeaning, !text.isEmpty { return text }
    if !text.contains("\"") { return "\"\(text)\"" }
    if !text.contains("'") { return "'\(text)'" }
    // Both kinds inside: a quote written twice stands for itself.
    return "\"" + text.split(separator: "\"", omittingEmptySubsequences: false).joined(separator: "\"\"") + "\""
  }

  /// `412` or `w412`, as replies and `state` write windows.
  static func looksLikeWindowNumber(_ word: String) -> Bool {
    let digits = word.first == "w" || word.first == "W" ? word.dropFirst() : word[...]
    return !digits.isEmpty && digits.utf8.allSatisfy { (UInt8(ascii: "0")...UInt8(ascii: "9")).contains($0) }
  }

  static func isBare(_ character: Character) -> Bool {
    character.isLetter || character.isNumber || character == "." || character == "-" || character == "_"
  }

  /// Characters that draw nothing or change how the rest is drawn. Names end up in replies, the log
  /// and other people's dotfiles, so they are refused everywhere, as in `arbor://` URLs.
  static func isForbidden(_ scalar: Unicode.Scalar) -> Bool {
    switch scalar.properties.generalCategory {
    case .control, .format, .lineSeparator, .paragraphSeparator, .surrogate, .unassigned, .privateUse: true
    default: false
    }
  }
}

extension WindowSlot {
  /// `Safari`, `"Visual Studio Code"`, `412`, `Safari~Inbox`, `Safari*`. With `hidingTitle`, the title
  /// is replaced by `…`: window titles, and parts of them, are never logged.
  func notation(hidingTitle: Bool = false) -> String {
    var text: String
    switch owner {
    case .app(let name): text = LayoutNotation.quoted(name, isName: true)
    case .window(let id): text = String(id.rawValue)
    }
    if let title { text += "~" + (hidingTitle ? "…" : LayoutNotation.quoted(title, isName: false)) }
    if takesAll { text += "*" }
    return text
  }
}

extension LayoutNotation.Spec {
  /// The arrangement as a line of text. `LayoutNotation.parse` reads it back as the same value.
  public var text: String {
    let text = Self.text(of: root, isOutermost: true, hidingTitles: false)
    // On its own, a quoted name with the notation's signs in it would be read as a whole line in quotes.
    if case .windows(let slots) = root.kind, slots.count == 1, case .app(let name) = slots[0].owner, slots[0].title == nil,
      !slots[0].takesAll, name.contains(where: { "|/([".contains($0) })
    {
      return "(" + text + ")"
    }
    return text
  }

  /// The same with titles left out, for the log. It is not meant to be read back.
  public var textWithoutTitles: String { Self.text(of: root, isOutermost: true, hidingTitles: true) }

  private static func text(of space: LayoutNotation.Space, isOutermost: Bool, hidingTitles: Bool) -> String {
    var text: String
    switch space.kind {
    case .desktop:
      text = "Desktop"
    case .windows(let slots):
      let names = slots.map { $0.notation(hidingTitle: hidingTitles) }
      text = names.count == 1 ? names[0] : "[" + names.joined(separator: " ") + "]"
    case .group(let axis, let members):
      let inner = members.map { Self.text(of: $0, isOutermost: false, hidingTitles: hidingTitles) }
        .joined(separator: axis == .horizontal ? " | " : " / ")
      text = isOutermost ? inner : "(" + inner + ")"
    }
    if space.size != 1, !isOutermost { text += ":" + (space.size == 0 ? "0" : LayoutNotation.text(ofSize: space.size)) }
    return text
  }

  /// Every slot, in the order they are written.
  public var slots: [WindowSlot] {
    var result: [WindowSlot] = []
    func visit(_ space: LayoutNotation.Space) {
      switch space.kind {
      case .desktop: break
      case .windows(let slots): result += slots
      case .group(_, let members): members.forEach(visit)
      }
    }
    visit(root)
    return result
  }

  public var mentionsDesktop: Bool {
    func visit(_ space: LayoutNotation.Space) -> Bool {
      switch space.kind {
      case .desktop: true
      case .windows: false
      case .group(_, let members): members.contains(where: visit)
      }
    }
    return visit(root)
  }
}

/// In JSON an arrangement is its line of text, so that files holding them can be read and edited.
extension LayoutNotation.Spec: Codable {
  public init(from decoder: any Decoder) throws {
    let container = try decoder.singleValueContainer()
    let text = try container.decode(String.self)
    do {
      self = try LayoutNotation.parse(text)
    } catch {
      throw DecodingError.dataCorruptedError(in: container, debugDescription: "\(error)")
    }
  }

  public func encode(to encoder: any Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(text)
  }
}
