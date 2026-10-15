import Foundation

/// Something the finder can find, known by two texts: a name (a window's app, "View 3") and a detail (the
/// window's title, the apps in the view). Making a candidate folds its text (`FinderText`), so a list is
/// prepared once and searched at every keystroke.
public struct FinderCandidate: Equatable, Sendable {
  /// How much of each text is searched, in characters. A web page can give its window a title of any
  /// length, and the finder runs on the main thread at every keystroke.
  public static let nameLimit = 80
  public static let detailLimit = 200

  public let name: String
  public let detail: String
  /// The name, a space, and the detail, folded.
  let text: FinderText
  /// How many of `text`'s units belong to the name. The unit after them is the space.
  let nameCount: Int
  /// The name is one a person gave: a query that spells it out in full means this and nothing else.
  let isAName: Bool
  /// It does something instead of being somewhere. Go to… is about places, and whoever types a few letters of a title and presses Return
  /// must not have run something: see `FinderQuery`.
  let isACommand: Bool
  /// How many of the name's units are a command's own words. From the first quotation mark on it is the name of the app the command is about;
  /// no row of the menu has words after that, and a long name is cut before the closing mark.
  let ownCount: Int

  public init(name: String, detail: String, isAName: Bool = false, isACommand: Bool = false) {
    self.name = name
    self.detail = detail
    self.isAName = isAName
    self.isACommand = isACommand
    // Nobody types the apostrophe of Don’t Arrange, and a word has to be typed from its beginning (`FinderQuery`).
    var text = FinderText(name, limit: Self.nameLimit, droppingApostrophes: isACommand)
    nameCount = text.units.count
    ownCount = isACommand ? text.units.firstIndex(of: 0x22) ?? nameCount : nameCount
    // No word of a query holds a space, so this one is never matched. It keeps a run of matches from
    // continuing out of the name into the detail.
    text.append(unit: 0x20, source: 0, start: .none)
    text.append(FinderText(detail, limit: Self.detailLimit))
    self.text = text
  }

  /// `text` cut to `limit` characters, looking at no more of it than that takes.
  public static func clip(_ text: String, to limit: Int = detailLimit) -> String {
    FinderText.clip(text, to: limit)
  }

  /// `text` made fit to show on one line: cut to `limit` characters, with a space for every line break and
  /// tab. One character for one, so offsets into the result are offsets into `text`.
  public static func line(_ text: String, limit: Int = detailLimit) -> String {
    let clipped = FinderText.clip(text, to: limit)
    guard clipped.contains(where: { $0.isNewline || $0 == "\t" }) else { return clipped }
    return String(clipped.map { $0.isNewline || $0 == "\t" ? " " : $0 })
  }
}

/// A candidate that matches a query.
public struct FinderMatch: Equatable, Sendable {
  /// The candidate's place in the list that was searched.
  public var index: Int
  /// Higher is better. Only comparable between matches of the same query.
  public var score: Int
  /// The matched characters, for highlighting: ranges of character offsets into the candidate's
  /// `name` and `detail`, in order, never touching each other.
  public var nameRanges: [Range<Int>]
  public var detailRanges: [Range<Int>]

  public init(index: Int, score: Int, nameRanges: [Range<Int>] = [], detailRanges: [Range<Int>] = []) {
    self.index = index
    self.score = score
    self.nameRanges = nameRanges
    self.detailRanges = detailRanges
  }

  /// Ranges of character offsets into `text` as ranges of UTF-16 offsets, which is what attributed
  /// strings count in. Ranges that lie outside `text` are left out.
  public static func utf16Ranges(_ ranges: [Range<Int>], in text: String) -> [Range<Int>] {
    var result: [Range<Int>] = []
    var index = text.startIndex
    var offset = 0
    for range in ranges {
      guard range.lowerBound >= offset,
        let lower = text.index(index, offsetBy: range.lowerBound - offset, limitedBy: text.endIndex),
        let upper = text.index(lower, offsetBy: range.count, limitedBy: text.endIndex)
      else { break }
      result.append(lower.utf16Offset(in: text)..<upper.utf16Offset(in: text))
      index = upper
      offset = range.upperBound
    }
    return result
  }
}

/// What the user typed into the finder, ready to be matched.
///
/// The text is split at spaces into words, and every word has to match, in any order. A word matches
/// a candidate when its letters appear in "name detail" (for a window: its app, then its title) in the same
/// order, not necessarily next to each other, ignoring case and accents: `sfr`, `SAF` and `säf` all find
/// Safari. Of the ways a word can be laid over a candidate the best counts:
///
/// - letters at the start of a word are worth more (`gc` prefers Google Chrome to Logic), most of all for the
///   word's first letter;
/// - letters that follow each other are worth more, and letters skipped between two matches cost a little;
/// - letters in the name are worth more than letters in the detail.
///
/// Between equally good matches the one with less left over wins (`mail` prefers Mail to Mailplane). Only
/// the texts that matched count, so that three Safari windows are equal for `saf` whatever their titles. What
/// is still equal stays in the order it was given, which for the finder is most recently used first.
///
/// **A command has to be named.** A title is found by whatever of it comes to mind, since nobody knows its words. A command does something, and
/// its words are in the menu to be read: it matches only when every word of the query is the beginning of a word of its name, letters
/// together (`bal`, `dock left`, `dont arr`). Scattered over a name as long as a way through the menu are the letters of many an app.
///
/// And by a word of its own. Don’t Arrange “Safari” is about Safari and is not called Safari: whoever types `saf` means the app. What stands
/// between quotation marks narrows (`dont saf`) and lists nothing by itself.
///
/// Commands are ranked among themselves (`FinderSession` lists them after the places). Those whose name begins with a word of the query come
/// first (`dock` prefers Dock Focused Window ▸ Left to Undo Dock), and then the order they were given in decides, which is the menu's: the ways back
/// and what is used most come first there (`float` prefers Float Focused Window to Float All Windows, which is shorter).
public struct FinderQuery: Equatable, Sendable {
  /// Bounds on the work one query can ask for. What goes beyond them is ignored.
  static let wordLimit = 8
  static let unitLimit = 64

  /// The folded words.
  let words: [[UInt32]]
  /// The words beyond the bounds. A place is found without them. A command is not: every word typed has to begin a word of its name, or
  /// "… ▸ View 3", copied with its signs, is View 1, which comes first. Looking for the beginning of a word costs next to nothing.
  let further: [[UInt32]]
  /// Something was typed that neither list holds, so nothing can be said about every word: no command matches.
  let isCut: Bool

  public init(_ text: String) {
    var words: [[UInt32]] = []
    var further: [[UInt32]] = []
    var room = Self.unitLimit
    let clipped = FinderText.clip(text, to: Self.unitLimit * 4)
    var isCut = clipped.utf8.count < text.utf8.count
    for word in clipped.split(whereSeparator: \.isWhitespace) {
      // No word of a command is that long.
      let whole = FinderText(String(word), limit: Self.unitLimit).units
      if word.count > Self.unitLimit || whole.count > Self.unitLimit { isCut = true }
      guard words.count < Self.wordLimit, room > 0 else {
        further.append(whole)
        continue
      }
      let units = Array(FinderText(String(word), limit: room).units.prefix(room))
      if units.count < whole.count { isCut = true }
      // A word of nothing but accents or invisible characters asks for nothing.
      guard !units.isEmpty else { continue }
      room -= units.count
      words.append(units)
    }
    self.words = words
    self.further = further
    self.isCut = isCut
  }

  /// Whether the query asks for nothing, and so matches everything.
  public var isEmpty: Bool { words.isEmpty }

  /// The candidates that match, best first. An empty query keeps them all, in the order given.
  public func rank(_ candidates: [FinderCandidate]) -> [FinderMatch] {
    var matches: [FinderMatch] = []
    for (index, candidate) in candidates.enumerated() {
      if let match = match(candidate, index: index) { matches.append(match) }
    }
    // The index makes the order total, so the result does not depend on how `sort` treats equals.
    matches.sort { ($1.score, $0.index) < ($0.score, $1.index) }
    return matches
  }

  /// How `candidate` matches, or nil if some word does not. `index` is only passed on.
  public func match(_ candidate: FinderCandidate, index: Int = 0) -> FinderMatch? {
    var quality = 0
    var matched = Set<Int>()
    var isNamed = !candidate.isACommand
    if candidate.isACommand, isCut { return nil }
    for word in candidate.isACommand ? words + further : words {
      guard candidate.isACommand else {
        guard let alignment = Self.align(word, with: candidate) else { return nil }
        quality += alignment.score
        matched.formUnion(alignment.positions)
        continue
      }
      // Without the apostrophes, which the name is searched without, and without what stands before its first letter or digit, which
      // begins no word: a quotation mark, a bracket. Nothing but signs (the ▸ of a name that was copied) asks for nothing.
      let letters = Array(word.filter { $0 != 0x27 }.drop { !FinderText.isLetterOrDigit($0) })
      guard !letters.isEmpty else { continue }
      guard let alignment = Self.beginning(letters, in: candidate) else { return nil }
      quality += alignment.score
      matched.formUnion(alignment.positions)
      if alignment.positions[0] < candidate.ownCount { isNamed = true }
    }
    guard isNamed else { return nil }
    let nameCount = candidate.nameCount
    if candidate.isAName, !words.isEmpty, Array(words.joined(separator: [0x20])) == Array(candidate.text.units.prefix(nameCount)) {
      quality += Points.theVeryName
    }
    let inName = matched.filter { $0 < nameCount }.sorted()
    let inDetail = matched.filter { $0 > nameCount }.sorted()
    var leftOver = 0
    if !inName.isEmpty { leftOver += nameCount - inName.count }
    if !inDetail.isEmpty { leftOver += candidate.text.units.count - nameCount - 1 - inDetail.count }
    // Only decides between equal qualities.
    var handicap = min(leftOver, 1023)
    if candidate.isACommand { handicap = matched.contains(0) ? 0 : 1 }
    return FinderMatch(
      index: index, score: quality * 1024 - handicap,
      nameRanges: Self.ranges(inName.map { candidate.text.sources[$0] }),
      detailRanges: Self.ranges(inDetail.map { candidate.text.sources[$0] }))
  }

  /// Ascending offsets, possibly repeated, as the fewest ranges that cover them.
  private static func ranges(_ offsets: [Int]) -> [Range<Int>] {
    var result: [Range<Int>] = []
    for offset in offsets {
      if let last = result.last, offset <= last.upperBound {
        result[result.count - 1] = last.lowerBound..<max(last.upperBound, offset + 1)
      } else {
        result.append(offset..<offset + 1)
      }
    }
    return result
  }

  // MARK: One word against one candidate

  enum Points {
    static let match = 16
    static let wordStart = 8
    /// A capital inside a word (gitHub), or a digit after a letter or the other way round.
    static let innerStart = 6
    static let consecutive = 10
    static let inName = 4
    static let gapStart = 3
    static let gapExtension = 1
    /// More than the longest query can earn any other way (64 letters of some 50 points).
    static let theVeryName = 10_000
  }

  /// The first word of a command's name that begins with `word`, scored as `align` scores letters that follow each other from the start of
  /// a word. Nil if none does. Its own words come first, so one of them is found rather than one of the app it is about.
  static func beginning(_ word: [UInt32], in candidate: FinderCandidate) -> (score: Int, positions: [Int])? {
    let (units, starts) = (candidate.text.units, candidate.text.starts)
    guard !word.isEmpty, word.count <= candidate.nameCount else { return nil }
    func bonus(_ j: Int) -> Int {
      switch starts[j] {
      case .none: 0
      case .inner: Points.innerStart
      case .word: Points.wordStart
      }
    }
    for j in 0...(candidate.nameCount - word.count) where starts[j] != .none && units[j..<(j + word.count)].elementsEqual(word) {
      let rest = (j + 1)..<(j + word.count)
      return (Points.match + 2 * bonus(j) + rest.reduce(0) { $0 + Points.match + Points.consecutive + bonus($1) }, Array(j..<(j + word.count)))
    }
    return nil
  }

  /// The best way to lay `word` over the candidate's text: its score, and the unit each of the word's
  /// units lands on. Nil if the word is not a subsequence of the text.
  ///
  /// `best[i][j]` is the best score of the word's first `i + 1` units with the last of them on unit `j`. It
  /// follows from the row above: either the unit before sits on `j - 1`, or further back with a gap.
  /// A gap's cost grows by the same amount with each unit, so the best way to arrive through a gap can be
  /// carried along the row instead of searched for, which makes the whole table `word × text` steps.
  static func align(_ word: [UInt32], with candidate: FinderCandidate) -> (score: Int, positions: [Int])? {
    let units = candidate.text.units
    let n = units.count
    let m = word.count
    guard m > 0, m <= n else { return nil }

    // The earliest and latest unit each of the word's units can land on. Finding them also rejects
    // most candidates in one pass, and keeps the table to the part that can matter.
    var earliest = [Int](repeating: 0, count: m)
    var j = 0
    for i in 0..<m {
      while j < n, units[j] != word[i] { j += 1 }
      guard j < n else { return nil }
      earliest[i] = j
      j += 1
    }
    var latest = [Int](repeating: 0, count: m)
    j = n - 1
    for i in stride(from: m - 1, through: 0, by: -1) {
      while units[j] != word[i] { j -= 1 }  // stops at `earliest[i]` at the latest
      latest[i] = j
      j -= 1
    }

    func points(at j: Int, first: Bool) -> Int {
      var bonus = 0
      switch candidate.text.starts[j] {
      case .none: break
      case .inner: bonus = Points.innerStart
      case .word: bonus = Points.wordStart
      }
      return Points.match + (first ? 2 * bonus : bonus) + (j < candidate.nameCount ? Points.inName : 0)
    }

    let impossible = Int.min / 2
    var best = [Int](repeating: impossible, count: m * n)
    /// Where the unit before landed, for reading the positions back.
    var previous = [Int](repeating: -1, count: m * n)

    for j in earliest[0]...latest[0] where units[j] == word[0] {
      best[j] = points(at: j, first: true)
    }
    for i in 1..<m {
      let above = (i - 1) * n
      var throughGap = impossible
      var gapFrom = -1
      for j in (earliest[i - 1] + 1)...latest[i] {
        // Everything already in the running skips one more unit; `j - 2` joins, skipping one.
        if throughGap > impossible { throughGap -= Points.gapExtension }
        if j >= 2, best[above + j - 2] > impossible, best[above + j - 2] - Points.gapStart > throughGap {
          throughGap = best[above + j - 2] - Points.gapStart
          gapFrom = j - 2
        }
        guard units[j] == word[i] else { continue }
        var score = impossible
        var from = -1
        if best[above + j - 1] > impossible {
          score = best[above + j - 1] + Points.consecutive
          from = j - 1
        }
        if throughGap > score {
          score = throughGap
          from = gapFrom
        }
        guard from >= 0 else { continue }
        best[i * n + j] = score + points(at: j, first: false)
        previous[i * n + j] = from
      }
    }

    // Ties go to the earliest end, as they went to the earliest beginning above.
    let last = (m - 1) * n
    var end = earliest[m - 1]
    for j in earliest[m - 1]...latest[m - 1] where best[last + j] > best[last + end] { end = j }
    guard best[last + end] > impossible else { return nil }

    var positions = [Int](repeating: 0, count: m)
    var position = end
    for i in stride(from: m - 1, through: 0, by: -1) {
      positions[i] = position
      if i > 0 { position = previous[i * n + position] }
    }
    return (best[last + end], positions)
  }
}

/// Text folded for matching: lower case, without accents, as a list of units (Unicode scalars), each
/// remembering which character of the text it came from.
///
/// Foundation's `folding(options:locale:)` is not used because it gives different answers on macOS and
/// Linux (ß, ﬁ and others), and the tests have to mean the same on both. What is used is canonical
/// decomposition, which the Unicode standard defines, and the standard library's own character
/// properties:
///
/// 1. decompose (é becomes e and a combining accent, 한 its three jamo, the Kelvin sign a K);
/// 2. drop combining marks, invisible formatting characters and emoji skin tones;
/// 3. lower-case what is left, scalar by scalar, without regard to language or position;
/// 4. replace the few letters that are variants of another to a person but not to Unicode (`variants`).
struct FinderText: Equatable, Sendable {
  /// Whether a unit is a good place for a match to begin.
  enum Start: UInt8, Sendable {
    case none
    /// Inside a word, where a capital follows a small letter or digits and letters meet.
    case inner
    /// The first character of the text, or of a word.
    case word
  }

  private(set) var units: [UInt32] = []
  /// For each unit, the offset of the character it came from.
  private(set) var sources: [Int] = []
  private(set) var starts: [Start] = []

  /// One character can be any number of scalars (a family emoji is seven; "Zalgo" text has no bound).
  /// This many are looked at, and this many units kept.
  private static let scalarsPerCharacter = 8
  private static let unitsPerCharacter = 4

  /// Letters and signs with no decomposition that people type as something else.
  private static let variants: [UInt32: [UInt32]] = {
    let table: [(Unicode.Scalar, String)] = [
      ("ß", "ss"), ("æ", "ae"), ("œ", "oe"), ("ø", "o"), ("đ", "d"), ("ð", "d"), ("þ", "th"), ("ł", "l"),
      ("ħ", "h"), ("ŧ", "t"), ("ı", "i"), ("ſ", "s"), ("ς", "σ"),
      // Curly quotes, and the hyphens and dashes from U+2010 to the minus sign.
      ("\u{2018}", "'"), ("\u{2019}", "'"), ("\u{201C}", "\""), ("\u{201D}", "\""),
      ("\u{2010}", "-"), ("\u{2011}", "-"), ("\u{2012}", "-"), ("\u{2013}", "-"), ("\u{2014}", "-"),
      ("\u{2015}", "-"), ("\u{2212}", "-"),
    ]
    return Dictionary(uniqueKeysWithValues: table.map { ($0.0.value, $0.1.unicodeScalars.map(\.value)) })
  }()

  init(_ text: String, limit: Int, droppingApostrophes: Bool = false) {
    let clipped = Self.clip(text, to: limit)
    var characters = Array(clipped)
    if !clipped.utf8.allSatisfy({ $0 < 0x80 }) {
      // Decomposing never moves the boundaries between characters (Unicode Annex 29), so the offsets still
      // count characters of `text`. Should that ever fail, matching accents exactly beats highlighting the wrong letters.
      let decomposed = Array(clipped.decomposedStringWithCanonicalMapping)
      if decomposed.count == characters.count { characters = decomposed }
    }
    units.reserveCapacity(characters.count)
    sources.reserveCapacity(characters.count)
    starts.reserveCapacity(characters.count)

    // Most characters fold to one unit. Text made of those that fold to more is searched less far.
    let unitLimit = limit + limit / 4
    var before = Kind.separator
    for (offset, character) in characters.enumerated() {
      guard units.count < unitLimit else { break }
      // As if it were not there: the t of Don’t begins no word.
      if droppingApostrophes, character == "'" || character == "\u{2019}" || character == "\u{2018}" { continue }
      let kind = Kind(character)
      var start = Start.none
      switch (before, kind) {
      case (_, .separator): break
      case (.separator, _): start = .word
      case (.lower, .upper): start = .inner
      case (.digit, .digit), (.other, .other): break
      // Digits meet letters, or a script without capitals meets one with them.
      case (.digit, _), (_, .digit), (.other, _), (_, .other): start = .inner
      default: break
      }
      before = kind

      var room = Self.unitsPerCharacter
      for scalar in character.unicodeScalars.prefix(Self.scalarsPerCharacter) {
        guard room > 0 else { break }
        if scalar.value < 0x80 {
          let isCapital = (0x41...0x5A).contains(scalar.value)
          append(unit: isCapital ? scalar.value + 0x20 : scalar.value, source: offset, start: start)
          start = .none
          room -= 1
          continue
        }
        guard !Self.isIgnored(scalar) else { continue }
        for lowered in scalar.properties.lowercaseMapping.unicodeScalars where !Self.isIgnored(lowered) {
          for unit in Self.variants[lowered.value] ?? [lowered.value] where room > 0 {
            append(unit: unit, source: offset, start: start)
            start = .none
            room -= 1
          }
        }
      }
    }
  }

  mutating func append(unit: UInt32, source: Int, start: Start) {
    units.append(unit)
    sources.append(source)
    starts.append(start)
  }

  mutating func append(_ other: FinderText) {
    units += other.units
    sources += other.sources
    starts += other.starts
  }

  /// `text` cut to `limit` characters. It is cut by scalars first, into a string of its own, which costs no
  /// more than it keeps: finding the end of a character means reading all of it, however long it is (and
  /// a substring would still read on into the rest). A character cut short that way still begins where it began.
  static func clip(_ text: String, to limit: Int) -> String {
    let limit = min(max(limit, 0), 1 << 20)
    // UTF-8 has at least one byte for each character.
    if text.utf8.count <= limit { return text }
    let scalars = String.UnicodeScalarView(text.unicodeScalars.prefix(limit * scalarsPerCharacter))
    return String(String(scalars).prefix(limit))
  }

  /// Whether a unit can begin a word, going by what `Kind` takes for a separator.
  static func isLetterOrDigit(_ unit: UInt32) -> Bool {
    guard let scalar = Unicode.Scalar(unit) else { return false }
    return Kind(Character(scalar)) != .separator
  }

  private static func isIgnored(_ scalar: Unicode.Scalar) -> Bool {
    switch scalar.properties.generalCategory {
    case .nonspacingMark, .enclosingMark, .format: return true
    default: return scalar.properties.isEmojiModifier
    }
  }

  private enum Kind {
    case separator, lower, upper, digit
    /// A letter of a script without capitals.
    case other

    init(_ character: Character) {
      if let ascii = character.asciiValue {
        switch ascii {
        case 0x61...0x7A: self = .lower
        case 0x41...0x5A: self = .upper
        case 0x30...0x39: self = .digit
        default: self = .separator
        }
      } else if character.isNumber {
        self = .digit
      } else if character.isLetter {
        self = character.isUppercase ? .upper : character.isLowercase ? .lower : .other
      } else {
        self = .separator
      }
    }
  }
}
