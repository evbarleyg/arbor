import Foundation
import Testing

@testable import ArborCore

/// Candidates written as "App: title".
private func candidates(_ texts: [String]) -> [FinderCandidate] {
  texts.map { text in
    let parts = text.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false).map(String.init)
    let title = parts.count > 1 ? String(parts[1].drop(while: { $0 == " " })) : ""
    return FinderCandidate(name: parts[0], detail: title)
  }
}

/// The candidates that match, best first, as they were written.
private func rank(_ query: String, _ texts: [String]) -> [String] {
  FinderQuery(query).rank(candidates(texts)).map { texts[$0.index] }
}

private func matches(_ query: String, app: String = "", title: String = "") -> Bool {
  FinderQuery(query).match(FinderCandidate(name: app, detail: title)) != nil
}

/// The matched characters of a text, with the rest replaced by dots: what a user would see highlighted.
private func highlighted(_ ranges: [Range<Int>], in text: String) -> String {
  String(text.enumerated().map { offset, character in ranges.contains { $0.contains(offset) } ? character : "·" })
}

@Suite struct FinderQueryTests {
  // MARK: What matches

  @Test func anEmptyQueryKeepsEverythingInTheGivenOrder() {
    let windows = ["Safari: Arbor", "Notes: Shopping", "Mail: Inbox", "Safari: News"]
    // Nothing, spaces, and characters that fold to nothing: a lone accent, a zero-width joiner.
    for query in ["", "   ", "\t\n", "\u{301}", "\u{200D} \u{FE0F}"] {
      #expect(FinderQuery(query).isEmpty)
      let result = FinderQuery(query).rank(candidates(windows))
      #expect(result.map(\.index) == [0, 1, 2, 3])
      #expect(result.allSatisfy { $0.nameRanges.isEmpty && $0.detailRanges.isEmpty })
    }
    #expect(FinderQuery("").rank([]).isEmpty)
  }

  @Test func lettersMatchInOrderButNotNecessarilyTogether() {
    #expect(matches("saf", app: "Safari"))
    #expect(matches("sfr", app: "Safari"))
    #expect(matches("safari", app: "Safari"))
    #expect(!matches("srf", app: "Safari"), "the order matters")
    #expect(!matches("safarii", app: "Safari"), "every letter needs its own")
    #expect(!matches("x", app: "Safari", title: "Arbor"))
    #expect(!matches("s", app: "", title: ""))
  }

  @Test func aWordMayStartInTheAppNameAndEndInTheTitle() {
    #expect(matches("sd", app: "Safari", title: "Docs"))
    #expect(!matches("ds", app: "Safari", title: "Dog"), "the app name comes first")
    #expect(matches("ds", app: "Safari", title: "Docs"), "both letters are in the title")
  }

  @Test func caseIsIgnored() {
    #expect(matches("SAFARI", app: "safari"))
    #expect(matches("safari", app: "SAFARI"))
    #expect(matches("gItHuB", title: "GitHub"))
  }

  @Test func everyWordMustMatchInAnyOrder() {
    let windows = ["Safari: Arbor docs", "Safari: News", "Notes: Docs to read"]
    #expect(rank("safari docs", windows) == ["Safari: Arbor docs"])
    #expect(rank("docs safari", windows) == ["Safari: Arbor docs"])
    #expect(rank("  docs \t safari  ", windows) == ["Safari: Arbor docs"])
    #expect(rank("safari docs zebra", windows).isEmpty)
    #expect(Set(rank("docs", windows)) == ["Safari: Arbor docs", "Notes: Docs to read"])
  }

  // MARK: What comes first

  @Test func wordStartsBeatTheMiddleOfWords() {
    #expect(rank("gc", ["Logic: Song", "Google Chrome: Song"]) == ["Google Chrome: Song", "Logic: Song"])
    #expect(rank("vsc", ["Reviews Inc: a", "Visual Studio Code: a"]).first == "Visual Studio Code: a")
    #expect(rank("in", ["Mail: Drafting", "Mail: Inbox"]).first == "Mail: Inbox")
    // A capital inside a word, and a digit after letters, start something too.
    #expect(rank("hub", ["Safari: Chubby cats", "Safari: GitHub"]).first == "Safari: GitHub")
    #expect(rank("2", ["Arbor: Test12", "Arbor: Test2"]).first == "Arbor: Test2")
    // Punctuation separates words as spaces do.
    #expect(rank("sw", ["Xcode: answers", "Xcode: main.swift"]).first == "Xcode: main.swift")
    #expect(rank("b", ["Finder: abc", "Finder: a/b", "Finder: a_b"]) == ["Finder: a/b", "Finder: a_b", "Finder: abc"])
  }

  @Test func lettersThatFollowEachOtherBeatScatteredOnes() {
    #expect(rank("not", ["Numbers: On Time", "Notes: a"]).first == "Notes: a")
    #expect(rank("arb", ["Safari: a rib", "Safari: Documentation for Arbor"]).first == "Safari: Documentation for Arbor")
    #expect(rank("code", ["Safari: Chrome OS Developer Edition", "Safari: decode"]).first == "Safari: decode")
    // The closer together, the better.
    #expect(rank("ab", ["X: a---b", "X: a-b", "X: a--b"]) == ["X: a-b", "X: a--b", "X: a---b"])
  }

  @Test func theAppNameBeatsTheTitle() {
    #expect(rank("term", ["Safari: Terminal emulators", "Terminal: zsh"]).first == "Terminal: zsh")
    #expect(rank("mail", ["Safari: Mail", "Mail: Inbox"]).first == "Mail: Inbox")
    #expect(rank("s", ["Notes: Safari", "Safari: Notes"]).first == "Safari: Notes")
  }

  @Test func shorterBeatsLongerWhenTheMatchIsAsGood() {
    #expect(rank("mail", ["Mailplane: a", "Mail: a", "MailMate: a"]) == ["Mail: a", "MailMate: a", "Mailplane: a"])
    #expect(rank("doc", ["Safari: Documentation for Arbor", "Safari: Docs"]).first == "Safari: Docs")
    // But a better match in a long title still beats a worse one in a short title.
    #expect(rank("arbor", ["Safari: a r b o r", "Safari: Everything there is to know about Arbor"]).first
      == "Safari: Everything there is to know about Arbor")
  }

  /// Three Safari windows are equally good answers to "saf", so the most recently used stays first.
  @Test func textThatDidNotMatchDoesNotCount() {
    let windows = ["Safari: A very long title that goes on and on", "Safari: b", "Safari: Medium title"]
    #expect(rank("saf", windows) == windows)
    let apps = ["A very long app name indeed: Inbox", "B: Inbox", "Medium name: Inbox"]
    #expect(rank("inbox", apps) == apps)
  }

  /// What someone would type on an ordinary day, and the row they would expect on top.
  @Test func anOrdinaryDaysWindows() {
    let desk = [
      "Xcode: Arbor — FinderPanel.swift", "Safari: evbarleyg/arbor: A window manager — GitHub",
      "Slack: general (Channel) - Acme - Slack", "Terminal: robin — -zsh — 80×24",
      "Safari: Inbox (3) - robin@example.com - Gmail", "Google Chrome: Q3 plan - Google Docs", "Mail: Inbox — iCloud",
      "Notes: Shopping list", "Finder: Downloads", "zoom.us: Zoom Meeting", "Calendar: Calendar", "Messages: Alice",
      "Music: Music", "Preview: Plan.pdf (page 2 of 10)", "System Settings: Displays", "Code: FinderQuery.swift — arbor",
      "iTerm2: vim README.md", "View 1: Safari, Slack",
    ]
    let expected = [
      "xc": "Xcode: Arbor — FinderPanel.swift", "git": "Safari: evbarleyg/arbor: A window manager — GitHub",
      "gmail": "Safari: Inbox (3) - robin@example.com - Gmail", "inb": "Mail: Inbox — iCloud",
      "saf in": "Safari: Inbox (3) - robin@example.com - Gmail", "doc": "Google Chrome: Q3 plan - Google Docs",
      "gc": "Google Chrome: Q3 plan - Google Docs", "sl": "Slack: general (Channel) - Acme - Slack",
      "slack": "Slack: general (Channel) - Acme - Slack", "term": "Terminal: robin — -zsh — 80×24", "it": "iTerm2: vim README.md",
      "code": "Code: FinderQuery.swift — arbor", "fq": "Code: FinderQuery.swift — arbor", "zoom": "zoom.us: Zoom Meeting",
      "cal": "Calendar: Calendar", "mes": "Messages: Alice", "mu": "Music: Music", "set": "System Settings: Displays",
      "ss": "System Settings: Displays", "down": "Finder: Downloads", "pdf": "Preview: Plan.pdf (page 2 of 10)",
      "read": "iTerm2: vim README.md", "shop": "Notes: Shopping list", "v1": "View 1: Safari, Slack",
      // Three rows have the word; the most recently used of the two shortest comes first.
      "arbor": "Xcode: Arbor — FinderPanel.swift",
      // Two windows of the app: the most recently used.
      "saf": "Safari: evbarleyg/arbor: A window manager — GitHub",
    ]
    for (query, row) in expected.sorted(by: { $0.key < $1.key }) {
      #expect(rank(query, desk).first == row, "\(query)")
    }
  }

  @Test func tiesKeepTheGivenOrder() {
    let windows = (1...40).map { _ in "Terminal: zsh" }
    #expect(FinderQuery("zsh").rank(candidates(windows)).map(\.index) == Array(0..<40))
    #expect(FinderQuery("t z").rank(candidates(windows)).map(\.index) == Array(0..<40))
    let scores = Set(FinderQuery("zsh").rank(candidates(windows)).map(\.score))
    #expect(scores.count == 1)
  }

  @Test func theSameQuestionAlwaysGetsTheSameAnswer() {
    var random = SeededRandom(seed: 7)
    let letters = Array("abcAB -.é")
    let windows = (0..<60).map { _ in
      FinderCandidate(
        name: String((0..<Int.random(in: 0...6, using: &random)).map { _ in letters.randomElement(using: &random)! }),
        detail: String((0..<Int.random(in: 0...12, using: &random)).map { _ in letters.randomElement(using: &random)! }))
    }
    for query in ["a", "ab", "ba c", "e", "abc"] {
      let first = FinderQuery(query).rank(windows)
      #expect(FinderQuery(query).rank(windows) == first)
      // Best first, and equals in the order given.
      for (one, next) in zip(first, first.dropFirst()) {
        #expect(one.score > next.score || (one.score == next.score && one.index < next.index))
      }
    }
  }

  // MARK: Highlighting

  @Test func rangesSayWhichCharactersMatched() throws {
    let candidate = FinderCandidate(name: "Safari", detail: "Arbor docs")
    let prefix = try #require(FinderQuery("saf").match(candidate))
    #expect(prefix.nameRanges == [0..<3])
    #expect(prefix.detailRanges.isEmpty)

    let scattered = try #require(FinderQuery("sfr").match(candidate))
    #expect(highlighted(scattered.nameRanges, in: "Safari") == "S·f·r·")

    let both = try #require(FinderQuery("docs saf").match(candidate))
    #expect(both.nameRanges == [0..<3])
    #expect(both.detailRanges == [6..<10])

    let across = try #require(FinderQuery("sad").match(candidate))
    #expect(highlighted(across.nameRanges, in: "Safari") == "Sa····")
    #expect(highlighted(across.detailRanges, in: "Arbor docs") == "······d···")
  }

  @Test func wordsThatMatchTheSameLettersShareTheirRanges() throws {
    let match = try #require(FinderQuery("saf safari ari").match(FinderCandidate(name: "Safari", detail: "")))
    #expect(match.nameRanges == [0..<6])
  }

  @Test func theBestPlaceIsHighlightedNotTheFirst() throws {
    // The first a, r and b are scattered; the word at the end is what the user means.
    let title = "a rib for Arbor"
    let match = try #require(FinderQuery("arb").match(FinderCandidate(name: "Safari", detail: title)))
    #expect(highlighted(match.detailRanges, in: title) == "··········Arb··")
  }

  @Test func rangesCountCharactersHoweverTheyAreWritten() throws {
    // é as one scalar and as two, a flag (two scalars), a family (seven) and a thumb with a skin tone (two).
    for title in ["Caf\u{E9} 🇸🇪 👨‍👩‍👧‍👦 👍🏽 menu", "Cafe\u{301} 🇸🇪 👨‍👩‍👧‍👦 👍🏽 menu"] {
      let match = try #require(FinderQuery("menu").match(FinderCandidate(name: "", detail: title)))
      #expect(match.detailRanges == [11..<15])
      #expect(highlighted(match.detailRanges, in: title) == "···········menu")
    }
  }

  @Test func utf16RangesAreWhatAttributedStringsNeed() {
    let title = "Cafe\u{301} 👍🏽 menu"
    // C a f e+accent space thumb+tone space: 1 + 1 + 1 + 2 + 1 + 4 + 1 = 11 UTF-16 units before "menu".
    #expect(FinderMatch.utf16Ranges([7..<11], in: title) == [11..<15])
    #expect(FinderMatch.utf16Ranges([3..<4, 5..<6], in: title) == [3..<5, 6..<10])
    let ns = title as NSString
    #expect(ns.substring(with: NSRange(location: 11, length: 4)) == "menu")
    #expect(FinderMatch.utf16Ranges([], in: title).isEmpty)
    // Ranges from some other text do no harm.
    #expect(FinderMatch.utf16Ranges([0..<2, 50..<60], in: "abc") == [0..<2])
    #expect(FinderMatch.utf16Ranges([2..<9], in: "abc").isEmpty)
    #expect(FinderMatch.utf16Ranges([2..<3, 0..<1], in: "abc") == [2..<3], "out of order: the rest is dropped")
  }

  // MARK: Limits and hostile input

  @Test func titlesAreSearchedUpToTwoHundredCharacters() {
    let filler = String(repeating: "-", count: 196)
    #expect(matches("zeta", title: filler + "zeta"), "characters 197 to 200")
    #expect(!matches("zeta", title: filler + "-zeta"), "the last letter is the 201st")
    #expect(!matches("zeta", title: String(repeating: "-", count: 5000) + "zeta"))
    let longApp = String(repeating: "-", count: FinderCandidate.nameLimit) + "zeta"
    #expect(!matches("zeta", app: longApp))
    #expect(matches("zeta", app: longApp, title: "zeta"), "a long app name does not push the title out")
  }

  @Test func clipCutsByCharacters() {
    #expect(FinderCandidate.clip("abc", to: 5) == "abc")
    #expect(FinderCandidate.clip("abcdef", to: 3) == "abc")
    #expect(FinderCandidate.clip("👍🏽👍🏽👍🏽", to: 2) == "👍🏽👍🏽")
    #expect(FinderCandidate.clip("e\u{301}e\u{301}e\u{301}", to: 2) == "e\u{301}e\u{301}")
    #expect(FinderCandidate.clip("abc", to: 0).isEmpty)
    #expect(FinderCandidate.clip("abc", to: -4).isEmpty)
    #expect(FinderCandidate.clip("abc", to: .max) == "abc")
    #expect(FinderCandidate.clip(String(repeating: "x", count: 1000)).count == FinderCandidate.detailLimit)
  }

  @Test func lineMakesOneLineWithoutMovingAnything() throws {
    #expect(FinderCandidate.line("plain") == "plain")
    #expect(FinderCandidate.line("a\nb\r\nc\td\u{2028}e\u{2029}f\u{85}g") == "a b c d e f g")
    #expect(FinderCandidate.line("abcdef", limit: 3) == "abc")
    #expect(FinderCandidate.line("") == "")
    // One character for one: what matched in the line is at the same place in the title.
    let title = "first\r\nsecond"
    let match = try #require(FinderQuery("second").match(FinderCandidate(name: "", detail: FinderCandidate.line(title))))
    #expect(match.detailRanges == [6..<12])
    #expect(Array(title)[6..<12] == Array("second")[...])
  }

  /// The processor time this thread has used, in seconds. Unlike the time on the wall it does not depend on what
  /// else the machine is doing, which on a build server is a lot.
  private func processorTime() -> Double {
    var time = timespec()
    clock_gettime(CLOCK_THREAD_CPUTIME_ID, &time)
    return Double(time.tv_sec) + Double(time.tv_nsec) / 1e9
  }

  /// Nothing a web page can put in its title, or a script in a query, makes the finder slow. This takes
  /// about a second in a debug build. Reading each text to its end even once would take twenty.
  @Test func hugeInputsCostNoMoreThanLongOnes() {
    let base = String(repeating: "lorem ipsum dolor sit amet ", count: 40_000)  // about a million characters
    let zalgo = "z" + String(repeating: "\u{301}", count: 1_000_000) + "algo"
    let emoji = String(repeating: "👨‍👩‍👧‍👦", count: 100_000)
    let queries = [base, zalgo, emoji, String(repeating: "l ", count: 100_000), String(repeating: "lid", count: 100_000)]
    let start = processorTime()
    let windows = (0..<50).flatMap { _ in
      [
        FinderCandidate(name: base, detail: base), FinderCandidate(name: "Safari", detail: zalgo),
        FinderCandidate(name: emoji, detail: emoji),
      ]
    }
    for query in queries { _ = FinderQuery(query).rank(windows) }
    for text in [base, zalgo, emoji] { _ = FinderCandidate.line(text) }
    #expect(processorTime() - start < 8)
  }

  @Test func whatGoesBeyondTheQuerysLimitsIsIgnored() {
    let many = (0..<100).map { _ in "a" }.joined(separator: " ")
    #expect(FinderQuery(many).words.count == FinderQuery.wordLimit)
    #expect(matches(many + " zebra", title: "a"), "the ninth word and later are not looked at")
    let long = String(repeating: "a", count: 500)
    #expect(FinderQuery(long).words.map(\.count) == [FinderQuery.unitLimit])
    #expect(matches(long, title: String(repeating: "a", count: FinderQuery.unitLimit)))
    #expect(!matches(long, title: String(repeating: "a", count: FinderQuery.unitLimit - 1)))
  }

  @Test(arguments: [
    "\0", "\0\0 \0", "\r\n", "a\r\nb", "\u{301}\u{301}", "\u{202E}abc", "\u{FEFF}", "🇸", "🇸🇪🇸", "\u{E0067}\u{E007F}",
    "\u{FFFD}", "\u{10FFFF}", "%s%n%@", "\\", "\"", "../../etc", "a\u{0}b", "\u{200B}", "ﷺ", "𝒜𝓇𝒷ℴ𝓇", "١٢٣", "ǅ",
  ])
  func oddTextIsJustText(text: String) {
    let windows = [
      FinderCandidate(name: text, detail: text), FinderCandidate(name: "", detail: ""),
      FinderCandidate(name: "Safari", detail: text + text), FinderCandidate(name: text + "x", detail: "y" + text),
    ]
    for query in [text, text + " " + text, "s", text + "s", ""] {
      let result = FinderQuery(query).rank(windows)
      for match in result {
        // Every range lies inside its text.
        let window = windows[match.index]
        #expect(match.nameRanges.allSatisfy { $0.lowerBound >= 0 && $0.upperBound <= window.name.count })
        #expect(match.detailRanges.allSatisfy { $0.lowerBound >= 0 && $0.upperBound <= window.detail.count })
      }
    }
    // Text always finds itself.
    #expect(matches(text, title: text))
    #expect(matches(text, app: text))
  }

  // MARK: The best alignment really is the best

  /// Every way to lay `word` over the candidate, scored the slow and obvious way.
  private func bestByTryingEverything(_ word: [UInt32], _ candidate: FinderCandidate) -> Int? {
    typealias Points = FinderQuery.Points
    let units = candidate.text.units
    var best: Int?
    func extend(_ positions: [Int]) {
      if positions.count == word.count {
        var score = 0
        for (i, j) in positions.enumerated() {
          var bonus = 0
          switch candidate.text.starts[j] {
          case .none: break
          case .inner: bonus = Points.innerStart
          case .word: bonus = Points.wordStart
          }
          score += Points.match + (i == 0 ? 2 * bonus : bonus) + (j < candidate.nameCount ? Points.inName : 0)
          if i > 0 {
            let skipped = j - positions[i - 1] - 1
            score += skipped == 0 ? Points.consecutive : -(Points.gapStart + (skipped - 1) * Points.gapExtension)
          }
        }
        best = max(best ?? score, score)
        return
      }
      let from = (positions.last ?? -1) + 1
      guard from < units.count else { return }
      for j in from..<units.count where units[j] == word[positions.count] { extend(positions + [j]) }
    }
    extend([])
    return best
  }

  @Test(arguments: Array<UInt64>(1...20)) func theTableFindsTheBestAlignment(seed: UInt64) {
    var random = SeededRandom(seed: seed)
    let letters = Array("aabbcA B-1")
    func text(_ length: ClosedRange<Int>) -> String {
      String((0..<Int.random(in: length, using: &random)).map { _ in letters.randomElement(using: &random)! })
    }
    for _ in 0..<150 {
      let candidate = FinderCandidate(name: text(0...5), detail: text(0...9))
      let word = Array(text(1...4).lowercased().filter { $0 != " " }.unicodeScalars.map(\.value))
      guard !word.isEmpty else { continue }
      let found = FinderQuery.align(word, with: candidate)
      #expect(found?.score == bestByTryingEverything(word, candidate), "\(word) in \(candidate.name)|\(candidate.detail)")
      if let found {
        // The positions are a real alignment: ascending, each on its own letter.
        #expect(zip(found.positions, found.positions.dropFirst()).allSatisfy { $0 < $1 })
        #expect(found.positions.enumerated().allSatisfy { candidate.text.units[$1] == word[$0] })
      }
    }
  }
}

/// Folding: what counts as the same letter. These hold on macOS and on Linux alike, which is why the finder
/// does not use Foundation's `folding(options:locale:)`; see `FinderText`.
@Suite struct FinderFoldingTests {
  private func folded(_ text: String) -> String {
    var view = String.UnicodeScalarView()
    for unit in FinderText(text, limit: 200).units { view.append(Unicode.Scalar(unit)!) }
    return String(view)
  }

  @Test func accentsAreIgnoredBothWays() {
    #expect(matches("cafe", title: "Caf\u{E9}"))
    #expect(matches("cafe", title: "Cafe\u{301}"))
    #expect(matches("caf\u{E9}", title: "Cafe"))
    #expect(matches("cafe\u{301}", title: "CAFE"))
    #expect(matches("caf\u{E9}", title: "Cafe\u{301}"))
    #expect(matches("saf", app: "Säfari"))
    #expect(matches("säf", app: "Safari"))
    #expect(folded("ÀÁÂÃÄÅàáâãäå Çç Ññ Öö Üü Žž Őő Ůů Ęę Șș") == "aaaaaaaaaaaa cc nn oo uu zz oo uu ee ss")
    // Two accents on one letter, in either order of writing.
    #expect(folded("Việt Nam ế \u{1EBF} e\u{302}\u{301}") == "viet nam e e e")
  }

  /// What the finder relies on from Foundation: canonical decomposition, the same everywhere.
  @Test func decompositionIsTheStandardOne() {
    func scalars(_ text: String) -> [UInt32] { text.decomposedStringWithCanonicalMapping.unicodeScalars.map(\.value) }
    #expect(scalars("\u{E9}") == [0x65, 0x301])
    #expect(scalars("\u{1EBF}") == [0x65, 0x302, 0x301])
    #expect(scalars("\u{D55C}") == [0x1112, 0x1161, 0x11AB])
    #expect(scalars("\u{212A}\u{212B}\u{2126}") == [0x4B, 0x41, 0x30A, 0x3A9])
    #expect(scalars("\u{DF}\u{F8}\u{FB01}\u{FF21}") == [0xDF, 0xF8, 0xFB01, 0xFF21], "no canonical decomposition")
    for text in ["Caf\u{E9} 한글 ガ 👍🏽 👨‍👩‍👧‍👦 🇸🇪 क्षि ö\u{332}", "\u{E9}\u{301}\u{E9}", "각\u{11A8}"] {
      #expect(text.decomposedStringWithCanonicalMapping.count == text.count, "characters stay characters")
    }
  }

  @Test func lettersThatAreVariantsToAPersonMatchTheirPlainForm() {
    #expect(folded("Straße") == "strasse")
    #expect(matches("strasse", title: "Straße"))
    #expect(matches("straße", title: "STRASSE"))
    #expect(matches("STRAẞE", title: "strasse"), "the capital ß")
    #expect(folded("Ærø Œuvre Łódź Đà Ðþ Ħ Ŧ") == "aero oeuvre lodz da dth h t")
    #expect(matches("lodz", title: "Łódź"))
    #expect(matches("orsted", title: "Ørsted"))
  }

  @Test func oneCharacterThatFoldsToTwoLettersIsHighlightedWhole() throws {
    let match = try #require(FinderQuery("ras").match(FinderCandidate(name: "", detail: "Straße")))
    #expect(match.detailRanges == [2..<5], "r, a and the ß that holds the s")
    let both = try #require(FinderQuery("sse").match(FinderCandidate(name: "", detail: "Straße")))
    #expect(both.detailRanges == [4..<6])
  }

  @Test func dottedAndDotlessIAreBothI() {
    #expect(folded("İstanbul Iğdır ıi") == "istanbul igdir ii")
    #expect(matches("istanbul", title: "İSTANBUL"))
    #expect(matches("İ", title: "i"))
    #expect(matches("ı", title: "I"))
  }

  @Test func otherScriptsFoldTheSameWay() {
    #expect(folded("Αθήνα ΆΈΉ ΟΔΟΣ οδός") == "αθηνα αεη οδοσ οδοσ", "Greek: accents, capitals, the final sigma")
    #expect(matches("οδος", title: "ΟΔΌΣ"))
    #expect(folded("Ёлка Йод") == "елка иод", "Cyrillic")
    #expect(matches("елка", title: "Ёлка"))
    #expect(folded("ガギ がぎ") == "カキ かき", "kana: voicing marks")
    #expect(matches("שלום", title: "שָׁלוֹם"), "Hebrew points")
    #expect(matches("日本", title: "日本語のメモ"))
    #expect(!matches("本日", title: "日本語のメモ"))
  }

  /// Korean is typed a part of a syllable at a time, so a syllable that is not finished yet finds the whole one.
  @Test func anUnfinishedKoreanSyllableFindsTheFinishedOne() throws {
    #expect(matches("한글", title: "한글 문서"))
    #expect(matches("하", title: "한글"))
    #expect(matches("\u{1112}", title: "한글"), "the first consonant alone")
    #expect(!matches("글한", title: "한글"))
    let match = try #require(FinderQuery("하").match(FinderCandidate(name: "", detail: "새 한글")))
    #expect(match.detailRanges == [2..<3])
  }

  @Test func emojiMatchWhateverTheirSkinToneOrStyle() {
    #expect(matches("👍", title: "Review 👍🏽"))
    #expect(matches("👍🏽", title: "Review 👍"))
    #expect(matches("👍🏿", title: "Review 👍🏻"))
    #expect(!matches("👎", title: "Review 👍🏽"))
    #expect(matches("❤", title: "I ❤\u{FE0F} Arbor"), "with and without the emoji style selector")
    #expect(matches("👩‍💻", title: "👩‍💻 at work"))
    #expect(matches("💻", title: "👩‍💻 at work"), "a part of a joined emoji")
    #expect(matches("🇸🇪", title: "Flag 🇸🇪"))
    #expect(!matches("🇪🇸", title: "Flag 🇸🇪"), "Spain is not Sweden")
    #expect(matches("1", title: "1\u{FE0F}\u{20E3}"), "a keycap")
  }

  @Test func typographersPunctuationMatchesWhatKeyboardsType() {
    #expect(matches("robin's", title: "Robin’s notes"))
    #expect(matches("\"a\"", title: "“a”"))
    #expect(matches("a-b", title: "a–b"))
    #expect(matches("a-b", title: "a—b"))
    #expect(matches("a—b", title: "a-b"))
    #expect(folded("a\u{AD}b\u{200B}c\u{200D}d\u{FEFF}e\u{202E}f") == "abcdef", "invisible characters are not there")
  }

  @Test func allKindsOfSpaceSeparateWords() {
    // No-break space, ideographic space, tab, line separator.
    for space in ["\u{A0}", "\u{3000}", "\t", "\u{2028}"] {
      #expect(FinderQuery("arbor\(space)docs").words.count == 2)
      #expect(rank("d", ["Safari: add", "Safari: Arbor\(space)docs"]).first == "Safari: Arbor\(space)docs")
    }
  }

  @Test func startsAreWhereWordsAndHumpsBegin() {
    func starts(_ text: String) -> String {
      String(FinderText(text, limit: 200).starts.map { $0 == .word ? "W" : $0 == .inner ? "i" : "." })
    }
    #expect(starts("Arbor docs") == "W.....W...")
    #expect(starts("gitHub") == "W..i..")
    #expect(starts("HTML") == "W...")
    #expect(starts("Test12b") == "W...i.i")
    #expect(starts("main.swift") == "W....W....")
    #expect(starts("  a") == "..W")
    #expect(starts("Élan éÉ") == "W....Wi")
    #expect(starts("日本語abc") == "W..i..")
    #expect(starts("👍ok") == ".W.")
    #expect(starts("Straße") == "W......", "seven units: only the first s of ß could start anything")
  }
}

/// A name a person gave (a named space), spelt out in full.
@Suite struct FinderNameTests {
  let rows = [
    FinderCandidate(name: "Writing", detail: "Writing"), FinderCandidate(name: "Writing Pro", detail: ""),
    FinderCandidate(name: "Writing", detail: "Notes, Mail", isAName: true),
    FinderCandidate(name: "Mail Room", detail: "Mail", isAName: true),
  ]

  @Test func theWholeNameWins() {
    #expect(FinderQuery("writing").rank(rows).first?.index == 2)
    #expect(FinderQuery(" WRÍTING ").rank(rows).first?.index == 2, "folded like everything else")
    #expect(FinderQuery("mail  room").rank(rows).first?.index == 3, "whatever the spaces between the words")
  }

  @Test func anythingLessIsAMatchLikeAnyOther() {
    #expect(FinderQuery("writin").rank(rows).first?.index == 0)
    #expect(FinderQuery("room mail").rank(rows).map(\.index) == [3], "the words the other way round still find it")
    #expect(FinderQuery("writing notes").rank(rows).map(\.index) == [2])
    #expect(FinderQuery("").rank(rows).map(\.index) == [0, 1, 2, 3])
  }
}
