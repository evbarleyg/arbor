import ArborCore
import Foundation
import Testing

/// Commands that name windows by app, `focused` or `pointer` (F50, part 1): their text form.
@Suite struct WindowRefTests {
  /// What the names of a command are, or nil for a plain command.
  func names(_ text: String) throws -> [WindowRef]? {
    guard case .naming(_, let names) = try Command.parse(text) else { return nil }
    return names
  }

  @Test func theExamplesOfTheSpecParse() throws {
    #expect(try names("zoom Safari") == [.app("Safari")])
    #expect(try names("dock com.apple.Terminal right") == [.app("com.apple.Terminal")])
    #expect(try names("dock Mail beside Safari bottom") == [.app("Mail"), .app("Safari")])
    #expect(try names("float Slack") == [.app("Slack")])
    #expect(try names("zoom focused") == [.focused])
    #expect(try names("dock pointer left") == [.pointer])
  }

  @Test func filledInTheyAreThePlainCommands() throws {
    let (a, b) = (WindowID(412), WindowID(388))
    #expect(try Command.parse("zoom Safari").filling([a]) == .zoom(a))
    #expect(try Command.parse("dock com.apple.Terminal right").filling([a]) == .dock(a, .right))
    #expect(try Command.parse("dock Mail beside Safari bottom").filling([a, b]) == .dockBeside(a, target: b, .bottom))
    #expect(try Command.parse("dock beside Safari top").filling([b]) == .dockBeside(nil, target: b, .top))
    #expect(try Command.parse("dock 7 beside Safari top").filling([b]) == .dockBeside(WindowID(7), target: b, .top))
    #expect(try Command.parse("dock Mail beside 7 top").filling([a]) == .dockBeside(a, target: WindowID(7), .top))
    #expect(try Command.parse("float Slack").filling([a]) == .float(a))
    #expect(try Command.parse("toggle-float Slack").filling([a]) == .toggleFloat(a))
    #expect(try Command.parse("resize Slack left -40.5").filling([a]) == .resize(a, .left, -40.5))
    #expect(try Command.parse("frame pointer").filling([a]) == .zoom(a))
  }

  @Test func fillingNeedsOneWindowPerName() throws {
    #expect(try Command.parse("dock Mail beside Safari bottom").filling([WindowID(1)]) == nil)
    #expect(try Command.parse("zoom Safari").filling([]) == nil)
    #expect(try Command.parse("zoom Safari").filling([WindowID(1), WindowID(2)]) == nil)
    #expect(Command.zoom(WindowID(1)).filling([]) == nil)
  }

  @Test func numbersStillMeanWindows() throws {
    #expect(try Command.parse("zoom 412") == .zoom(WindowID(412)))
    #expect(try Command.parse("zoom w412") == .zoom(WindowID(412)))
    #expect(try Command.parse("dock 412 beside 388 bottom") == .dockBeside(WindowID(412), target: WindowID(388), .bottom))
    #expect(try Command.parse("zoom") == .zoom(nil))
    // In quotes a number is a name.
    #expect(try names("zoom \"2048\"") == [.app("2048")])
  }

  @Test func namesKeepTheirCase() throws {
    #expect(try names("ZOOM iTerm2") == [.app("iTerm2")])
    #expect(try names("dock com.Apple.Mail LEFT") == [.app("com.Apple.Mail")])
    #expect(try names("zoom FOCUSED") == [.focused])
  }

  @Test func namesWithSpacesGoInQuotes() throws {
    #expect(try names("zoom \"Visual Studio Code\"") == [.app("Visual Studio Code")])
    #expect(try names("zoom 'Visual Studio Code'") == [.app("Visual Studio Code")])
    #expect(try names("dock \"Google Chrome\" beside 'Visual Studio Code' left") == [.app("Google Chrome"), .app("Visual Studio Code")])
    #expect(try names("zoom \"a/b\"") == [.app("a/b")])
    #expect(try names("zoom 'it''s'") == [.app("it's")])
    #expect(try names("zoom \"say \"\"hi\"\"\"") == [.app("say \"hi\"")])
    // A caller with words in hand needs no quotes: a word is a word.
    #expect(try Command.parse(words: ["zoom", "Visual Studio Code"]) == Command.parse("zoom \"Visual Studio Code\""))
  }

  @Test func anAppCalledLikeADirectionNeedsQuotes() throws {
    for word in ["left", "right", "up", "down", "top", "bottom", "beside", "r", "L", "north"] {
      let error = #expect(throws: Command.ParseError.self, "\(word)") { try Command.parse("zoom \(word)") }
      #expect(error?.description.contains("needs quotes, or its bundle id") == true)
      #expect(try names("zoom \"\(word)\"") == [.app(word)])
    }
    #expect(try names("zoom \"focused\"") == [.app("focused")])
    #expect(try Command.parse("dock left") == .dock(nil, .left))
    #expect(try names("dock \"left\" left") == [.app("left")])
  }

  static let texts = [
    "zoom Safari", "dock com.apple.Terminal right", "dock Mail beside Safari bottom", "float Slack", "toggle-float focused", "zoom pointer",
    "dock 412 beside Safari top", "dock Safari beside 412 top", "dock beside Safari left", "resize Safari right 100", "zoom \"Visual Studio Code\"",
    "zoom \"left\"", "zoom \"focused\"", "zoom \"412\"", "zoom \"w5\"", "zoom 'say \"hi\"'", "zoom \"it's\"", "zoom \"a/b\"", "zoom \"-x\"", "zoom \"C++\"", "zoom 微信",
    "zoom \"Desktop\"", "dock Safari beside Safari left",
  ]

  @Test(arguments: texts) func textRoundTrips(text: String) throws {
    let command = try Command.parse(text)
    #expect(command.text == text)
    #expect(try Command.parse(command.text) == command)
    #expect(command.logText == text)
    #expect(try JSONDecoder().decode(Command.self, from: JSONEncoder().encode(command)) == command)
  }

  @Test func theWrapperAnswersForTheCommandInside() throws {
    #expect(try Command.parse("zoom pointer").isAllowedFromURL && Command.parse("dock focused left").isAllowedFromURL)
    #expect(try !Command.parse("focus pointer").isAllowedFromURL && !Command.parse("reveal focused").isAllowedFromURL)
    #expect(try !Command.parse("zoom Safari").isQuery)
    #expect(try !Command.parse("zoom Safari").endsPause)
  }

  /// A window's number means nothing to a web page. An app's name does, and `zoom` and `dock` give the window they name the keyboard.
  @Test(arguments: ["zoom Safari", "dock Terminal left", "dock Mail beside Safari bottom", "dock pointer beside Terminal left", "float com.apple.Terminal", "pin Terminal", "resize Terminal left 40"])
  func aLinkMayNotPickAWindowByItsApp(text: String) throws {
    let command = try Command.parse(text)
    #expect(!command.isAllowedFromURL)
    #expect(command.nameWhenRefusedFromURL == "\(text.prefix { $0 != " " }) <app>")
    #expect(command.filling([WindowID(1), WindowID(2)].prefix(text.contains("beside") ? 2 : 1).map { $0 })?.isAllowedFromURL == true, "by number it may")
  }

  @Test func urlsTakeNamesWithoutSpaces() throws {
    #expect(try Command.parse(url: "arbor://zoom/Safari") == Command.parse("zoom Safari"))
    #expect(try Command.parse(url: "arbor://dock/com.apple.mail/beside/Safari/bottom") == Command.parse("dock com.apple.mail beside Safari bottom"))
    #expect(try Command.parse(url: "arbor://zoom/pointer") == Command.parse("zoom pointer"))
    #expect(throws: Command.ParseError.self) { try Command.parse(url: "arbor://zoom/Visual%20Studio%20Code") }
  }

  @Test(arguments: [
    "zoom \"", "zoom '", "zoom \"Safari", "zoom 'Safari\"", "zoom \"\"", "zoom ''", "zoom --fast", "zoom -q", "zoom \"a\u{0}b\"", "zoom a\u{202E}b", "zoom \u{1B}[2J",
    "zoom " + String(repeating: "x", count: 201), "dock Safari", "dock Safari Mail", "dock Safari beside Mail", "dock Safari beside left left", "resize Safari right",
  ]) func refuses(text: String) {
    #expect(throws: Command.ParseError.self) { try Command.parse(text) }
  }

  @Test func aNumberThatCouldBeTakenForAStandInIsRefusedBesideNames() throws {
    #expect(throws: Command.ParseError.self) { try Command.parse("dock 4294967295 beside Safari left") }
    #expect(throws: Command.ParseError.self) { try Command.parse("dock Safari beside 4294967295 left") }
    // On its own it is a number like any other.
    #expect(try Command.parse("zoom 4294967295") == .zoom(WindowID(.max)))
    #expect(try Command.parse("dock 4294967294 beside Safari left").filling([WindowID(3)]) == .dockBeside(WindowID(4_294_967_294), target: WindowID(3), .left))
  }

  @Test func quotesKeepWordsTogetherAndNothingElseChanges() throws {
    #expect(try Command.parse("  dock   left  ") == .dock(nil, .left))
    #expect(try Command.parse("dock/left") == .dock(nil, .left))
    #expect(try Command.parse("exclude com.apple.Music") == .exclude(bundleID: "com.apple.Music"))
    // A quote inside a word is a character like any other.
    #expect(try names("zoom it's") == [.app("it's")])
    #expect(try Command.parse("zoom it's").text == "zoom \"it's\"")
  }

  /// What a script's mistake looks like is refused, not looked for among the apps. `CommandTextTests.numbersAreOnlyPlainNumbers`
  /// has the list; this is why each kind is on it, and the way out.
  @Test(arguments: [
    "4294967296", "99999999999999999999999", "1.0", "1,000", "1_000", "١٢", "１２", "²", "٣",  // no letters, but digits
    "1e3", "0x10", "0xED", "0b1", "0o7", "NaN", "nan", "inf", "Infinity",  // what other tools print for a number
    "w", "W", "ww1", "www", "n", "n1", "N12", "nn1",  // `w$id` and `n$id` with `id` empty, or with its letter already
  ]) func aNumberGoneWrongIsNotAnApp(word: String) throws {
    for text in ["zoom \(word)", "dock \(word) left", "dock Mail beside \(word) bottom", "pin \(word)"] {
      let error = #expect(throws: Command.ParseError.self, "\(text)") { try Command.parse(text) }
      #expect(error?.description.contains("an app called \(word) needs quotes") == true, "\(text): \(error?.description ?? "")")
    }
    // In quotes it is a name like any other, and it is written back in quotes.
    let quoted = try Command.parse("zoom \"\(word)\"")
    #expect(try names("zoom \"\(word)\"") == [.app(word)])
    #expect(quoted.text == "zoom \"\(word)\"")
    #expect(try Command.parse(quoted.text) == quoted)
  }

  @Test(arguments: [
    "1Password", "7zip", "2Do", "4K", "Safari", "Word", "Notes", "Numbers", "News", "Warp", "w3m", "n8n", "wx1y", "Nova", "0ad", "0x", "0xZZ", "e3", "x10",
    "com.apple.Safari", "net.n1", "Information", "Nano",
  ]) func appsWithDigitsOrThoseLettersAreStillNames(word: String) throws {
    #expect(try names("zoom \(word)") == [.app(word)])
    #expect(try Command.parse("zoom \(word)").text == "zoom \(word)", "no quotes where none are needed")
  }

  /// A word that stands there twice, once as a name: they are told apart by their order, and the window comes first.
  @Test func quotesAreRememberedWordByWord() throws {
    #expect(try names("dock \"left\" left") == [.app("left")])
    #expect(try names("dock \"Left\" left") == [.app("Left")], "with its capitals")
    #expect(try names("dock Mail beside \"left\" left") == [.app("Mail"), .app("left")])
    #expect(try names("dock \"left\" beside \"left\" left") == [.app("left"), .app("left")])
    #expect(throws: Command.ParseError.self) { try Command.parse("dock \"left\" beside left left") }
    #expect(throws: Command.ParseError.self) { try Command.parse("dock left beside \"left\" left") }
    #expect(try names("zoom \"412\"") == [.app("412")])
    #expect(try Command.parse("dock 412 beside \"412\" left").text == "dock 412 beside \"412\" left")
    #expect(try Command.parse("dock \"412\" beside 412 left").text == "dock \"412\" beside 412 left")
  }

  /// A word is a name by where it stands and how it was typed there, whatever stands before it.
  @Test func aWordThatAlsoStandsThereAsSomethingElseIsNotMixedUp() throws {
    #expect(try names("dock Mail beside \"beside\" left") == [.app("Mail"), .app("beside")])
    #expect(try names("dock beside \"beside\" left") == [.app("beside")])
    #expect(try names("move-to-display 2 \"2\"") == [.app("2")])
    #expect(try Command.parse("move-to-display 2 2") == .moveToDisplay(.number(2), WindowID(2)))
    #expect(try names("move-to-display next \"next\"") == [.app("next")])
    #expect(try names("resize \"40\" left 40") == [.app("40")])
    #expect(try names("swap Safari \"left\"") == [.app("Safari"), .app("left")])
    #expect(try names("swap \"left\" left") == [.app("left")])
    #expect(try Command.parse("swap Safari left").filling([WindowID(7)]) == .swap(WindowID(7), .left))
    for text in [
      "dock Mail beside \"beside\" left", "dock beside \"beside\" left", "move-to-display 2 \"2\"", "move-to-display next \"next\"", "swap Safari \"left\"", "swap \"left\" left",
      "focus \"next\"", "focus \"previous\"", "focus \"prev\"", "focus \"left\"", "focus \"7\"",
    ] {
      let command = try Command.parse(text)
      #expect(command.text == text)
      #expect(try Command.parse(command.text) == command, "\(text) is written \(command.text)")
    }
    // Also where it is kept: a shortcut that is bound runs what was meant.
    #expect(try Command.parse("bind ctrl+opt+x focus \"next\"").text == "bind ctrl+opt+x focus \"next\"")
  }

  @Test func aSpaceWhereAWindowBelongsIsCalledThat() {
    let error = #expect(throws: Command.ParseError.self) { try Command.parse("zoom n1") }
    #expect(error?.description == "expected a window, and n1 is a space (`zoom-node 1` frames it); an app called n1 needs quotes, or its bundle id")
    let other = #expect(throws: Command.ParseError.self) { try Command.parse("zoom 1e3") }
    #expect(other?.description == "expected a window, and 1e3 is not a window's number; an app called 1e3 needs quotes, or its bundle id")
  }

  @Test func plainWindowNumbersAreStillNumbers() throws {
    #expect(try Command.parse("zoom 412") == .zoom(WindowID(412)))
    #expect(try Command.parse("zoom w412") == .zoom(WindowID(412)))
    #expect(try Command.parse("zoom 4294967295") == .zoom(WindowID(4_294_967_295)))
  }

  @Test func noWordsCrashParsingOrPrinting() {
    var random = NotationRandom(seed: 50)
    let verbs = ["zoom", "frame", "dock", "float", "toggle-float", "resize"]
    let words = LayoutNotationTests.pieces + ["left", "beside", "focused", "pointer", "Safari", "\"a b\"", "'", "4294967295", "4294967294", "10"]
    var parsed = 0
    for _ in 0..<10_000 {
      let chosen = [verbs.randomElement(using: &random)!] + (0..<Int.random(in: 0...4, using: &random)).map { _ in words.randomElement(using: &random)! }
      for attempt in [{ try Command.parse(words: chosen) }, { try Command.parse(chosen.joined(separator: " ")) }] {
        guard let command = try? attempt() else { continue }
        parsed += 1
        #expect((try? Command.parse(command.text)) == command, "\(chosen) became \(command.text.debugDescription)")
        if case .naming(_, let names) = command {
          #expect(command.filling(names.indices.map { WindowID(UInt32($0 + 1)) }) != nil, "\(command.text.debugDescription)")
        }
      }
    }
    #expect(parsed > 1000)
  }
}
