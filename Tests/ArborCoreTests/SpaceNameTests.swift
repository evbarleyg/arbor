import ArborCore
import Testing

/// F20: what a name may be, when two are the same, and which one a typed text means.
@Suite struct SpaceNameTests {
  // MARK: What a name may be

  @Test(arguments: [
    ("Writing", "Writing"), ("  Writing  ", "Writing"), ("Writing   Desk", "Writing Desk"), ("writing\tdesk\n", "writing desk"),
    ("Design/Review", "Design Review"), ("/a//b/", "a b"), ("Büro", "Büro"), ("仕事", "仕事"), ("📝 Notes", "📝 Notes"),
    ("👩‍💻", "👩‍💻"), ("2", "2"), ("n5", "n5"), ("Left Monitor", "Left Monitor"), ("leftovers", "leftovers"), ("a\u{A0}b", "a b"), ("a\u{85}b", "a b"),
  ])
  func namesAreTidied(typed: String, kept: String) throws {
    #expect(try SpaceName.tidied(typed) == kept)
    #expect(SpaceName.isTidy(kept))
  }

  @Test(arguments: ["", " ", "\n\t", "/", " / / "])
  func aNameNeedsSomethingInIt(text: String) {
    #expect(throws: SpaceName.Problem.self) { try SpaceName.tidied(text) }
  }

  @Test func aNameHasAtMostFortyCharacters() throws {
    #expect(try SpaceName.tidied(String(repeating: "x", count: 40)).count == 40)
    #expect(throws: SpaceName.Problem.self) { try SpaceName.tidied(String(repeating: "x", count: 41)) }
    // Forty flags are forty characters; one letter under two hundred accents is one, and far too long.
    #expect(throws: Never.self) { try SpaceName.tidied(String(repeating: "🇨🇭", count: 40)) }
    #expect(throws: SpaceName.Problem.self) { try SpaceName.tidied("e" + String(repeating: "\u{301}", count: 200)) }
    // The bound is 120 scalars: forty letters with two accents each are just within it.
    #expect(throws: Never.self) { try SpaceName.tidied(String(repeating: "e\u{301}\u{323}", count: 40)) }
    #expect(throws: SpaceName.Problem.self) { try SpaceName.tidied(String(repeating: "e\u{301}\u{323}", count: 39) + "e\u{301}\u{323}\u{331}") }
  }

  @Test(arguments: [
    "a\u{0}b", "a\u{7}", "\u{1B}[31mred", "a\u{7F}", "evil\u{202E}txt", "a\u{200B}b", "a\u{2066}b", "\u{FEFF}a", "a\u{E000}",
    "a\u{FFFF}",
  ])
  func charactersThatForgeOrHideAreRefused(text: String) {
    #expect(throws: SpaceName.Problem.self) { try SpaceName.tidied(text) }
  }

  @Test(arguments: [
    "left", "right", "up", "down", "top", "bottom", "LEFT", " Up ", "l", "r", "u", "d", "north", "south", "east", "west",
  ])
  func aDirectionIsNotAName(word: String) {
    #expect(throws: SpaceName.Problem.self) { try SpaceName.tidied(word) }
  }

  @Test func problemsSayWhatIsWrong() {
    func problem(_ text: String) -> String {
      do {
        return try SpaceName.tidied(text)
      } catch {
        return "\(error)"
      }
    }
    #expect(problem("") == "a name needs at least one character")
    #expect(problem(String(repeating: "x", count: 41)) == "a name can have at most 40 characters")
    #expect(problem("a\u{7}") == "a name cannot hold control characters or invisible formatting")
    #expect(problem("Left") == "a space cannot be named `Left`: `go Left` means the neighbouring space")
  }

  @Test func whatIsNotTidyIsNotTidy() {
    for text in [" a", "a ", "a  b", "a/b", "", "left", "a\nb"] { #expect(!SpaceName.isTidy(text), "\(text)") }
  }

  // MARK: Comparing

  @Test func capitalsDoNotTellNamesApart() {
    #expect(SpaceName.areSame("Writing", "WRITING"))
    #expect(SpaceName.areSame("Büro", "BÜRO"))
    #expect(SpaceName.areSame("e\u{301}", "\u{E9}"), "the same letter, composed and not")
    #expect(!SpaceName.areSame("Writing", "Writing 2"))
  }

  @Test func listsGoByLettersNotCapitals() {
    #expect(SpaceName.sorted(["mail", "Zoo", "Alpha", "beta"]) == ["Alpha", "beta", "mail", "Zoo"])
    // Names that differ only in capitals meet in a hand-edited file, and the order must not depend on the file's.
    #expect(SpaceName.sorted(["b", "a", "B", "A"]) == ["A", "a", "B", "b"])
    #expect(SpaceName.sorted(["A", "B", "a", "b"]) == ["A", "a", "B", "b"])
  }

  // MARK: Finding

  private let names = ["Mail", "Mailing List", "Music", "Writing Desk", "web"]

  @Test func theWholeNameWinsOverABeginning() {
    #expect(SpaceName.match("mail", among: names) == .found("Mail"))
    #expect(SpaceName.match("MAILING LIST", among: names) == .found("Mailing List"))
    #expect(SpaceName.match(" writing/desk ", among: names) == .found("Writing Desk"))
  }

  @Test func aBeginningThatFitsOneNameFindsIt() {
    #expect(SpaceName.match("mu", among: names) == .found("Music"))
    #expect(SpaceName.match("WR", among: names) == .found("Writing Desk"))
    #expect(SpaceName.match("writing d", among: names) == .found("Writing Desk"))
    #expect(SpaceName.match("maili", among: names) == .found("Mailing List"))
  }

  @Test func aBeginningThatFitsSeveralListsThem() {
    #expect(SpaceName.match("m", among: names) == .several(["Mail", "Mailing List", "Music"]))
    #expect(SpaceName.match("w", among: names) == .several(["web", "Writing Desk"]))
  }

  @Test func onlyBeginningsCount() {
    #expect(SpaceName.match("desk", among: names) == .none)
    #expect(SpaceName.match("ail", among: names) == .none)
    #expect(SpaceName.match("mailx", among: names) == .none)
    #expect(SpaceName.match("", among: names) == .none)
    #expect(SpaceName.match("  ", among: names) == .none)
    #expect(SpaceName.match("x", among: [String]()) == .none)
  }

  @Test func exactTakesNoBeginnings() {
    #expect(SpaceName.exact("music", among: names) == "Music")
    #expect(SpaceName.exact("mus", among: names) == nil)
  }
}

/// F20: the text forms of the commands.
@Suite struct NamedSpaceCommandTests {
  @Test func nameTakesTheRestOfTheLineWithItsCapitals() throws {
    #expect(try Command.parse("name Writing") == .name("Writing"))
    #expect(try Command.parse("name  Writing   Desk ") == .name("Writing Desk"))
    #expect(try Command.parse("NAME iOS Review") == .name("iOS Review"))
    #expect(try Command.parse(words: ["name", "Writing Desk"]) == .name("Writing Desk"), "one quoted argument from a shell")
  }

  @Test func nameWithoutTextRemovesTheName() throws {
    #expect(try Command.parse("name") == .unname(nil))
    #expect(try Command.parse("unname") == .unname(nil))
    #expect(try Command.parse("unname Writing Desk") == .unname("Writing Desk"))
  }

  @Test func goMeansTheNeighbourForADirectionAndANameOtherwise() throws {
    for (word, edge) in [("left", Edge.left), ("right", .right), ("up", .top), ("down", .bottom), ("top", .top), ("bottom", .bottom), ("L", .left)] {
      #expect(try Command.parse("go \(word)") == .neighbor(edge))
    }
    #expect(try Command.parse("go Writing") == .goToSpace("Writing"))
    #expect(try Command.parse("go left monitor") == .goToSpace("left monitor"))
    #expect(try Command.parse("go w") == .goToSpace("w"))
    #expect(throws: Command.ParseError.self) { try Command.parse("go") }
  }

  @Test func neighborStillTakesOnlyDirections() {
    #expect(throws: Command.ParseError.self) { try Command.parse("neighbor Writing") }
    #expect(throws: Command.ParseError.self) { try Command.parse("neighbour") }
  }

  @Test func namesThatCannotBeAreRefusedWithTheReason() {
    #expect(throws: Command.ParseError(refusing: "a space cannot be named `left`: `go left` means the neighbouring space")) {
      try Command.parse("name left")
    }
    #expect(throws: Command.ParseError(refusing: "a name can have at most 40 characters")) {
      try Command.parse("name " + String(repeating: "x", count: 41))
    }
    #expect(throws: Command.ParseError.self) { try Command.parse(words: ["name", "a\u{1B}[0m"]) }
    #expect(throws: Command.ParseError.self) { try Command.parse(words: ["go", "a\u{202E}b"]) }
  }

  @Test func theOtherForms() throws {
    #expect(try Command.parse("spaces") == .spaces)
    #expect(try Command.parse("ask-name") == .askName(cancel: false))
    #expect(try Command.parse("ask-name cancel") == .askName(cancel: true))
    #expect(throws: Command.ParseError.self) { try Command.parse("spaces all") }
    #expect(throws: Command.ParseError.self) { try Command.parse("ask-name Writing") }
  }

  @Test(arguments: [
    Command.name("Writing Desk"), .name("iOS"), .unname(nil), .unname("Writing Desk"), .goToSpace("Writing Desk"), .goToSpace("w"),
    .spaces, .askName(cancel: false), .askName(cancel: true),
  ])
  func textRoundTrips(command: Command) throws {
    #expect(try Command.parse(command.text) == command)
  }

  @Test func onlySpacesIsAQuery() {
    #expect(Command.spaces.isQuery)
    for command in [Command.name("a"), .unname(nil), .goToSpace("a"), .askName(cancel: false)] { #expect(!command.isQuery) }
  }

  @Test func helpListsThem() {
    for word in ["go <name>", "name <text>", "unname [name]", "ask-name", "spaces  "] {
      #expect(Command.helpText.contains(word), "\(word)")
    }
  }

  // MARK: URLs

  @Test func aURLMayGoToAName() throws {
    #expect(try Command.parse(url: "arbor://go/Writing") == .goToSpace("Writing"))
    #expect(try Command.parse(url: "arbor://go/Writing/Desk") == .goToSpace("Writing Desk"))
    #expect(try Command.parse(url: "arbor://go/B%C3%BCro") == .goToSpace("Büro"))
    #expect(try Command.parse(url: "arbor://go/left") == .neighbor(.left))
    #expect(Command.goToSpace("Writing").isAllowedFromURL)
  }

  @Test(arguments: [Command.name("Free prizes"), .unname(nil), .unname("Writing"), .askName(cancel: false), .askName(cancel: true), .spaces])
  func aURLMayNotNameUnnameAskOrList(command: Command) {
    #expect(!command.isAllowedFromURL)
  }
}
