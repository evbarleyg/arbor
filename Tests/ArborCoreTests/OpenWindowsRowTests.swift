import ArborCore
import Foundation
import Testing

/// What a row of the menu's list of windows reads (`OpenWindows`).
@Suite struct OpenWindowsRowTests {
  func row(
    app: String = "Safari", title: String = "Start Page", place: FinderPlace = .inView, hasKeyboard: Bool = false
  ) -> OpenWindows.Row {
    OpenWindows.Row(window: WindowID(101), app: app, title: title, place: place, hasKeyboard: hasKeyboard, pid: 11)
  }

  @Test func appAndTitle() {
    #expect(row().label == "Safari: Start Page")
  }

  @Test func theAppAloneWhereTheTitleSaysNoMore() {
    #expect(row(title: "").label == "Safari")
    #expect(row(title: "   ").label == "Safari")
    #expect(row(title: "Safari").label == "Safari")
  }

  @Test func anAppWithoutANameIsCalledByItsWindow() {
    #expect(row(app: "", title: "Start Page").label == "Start Page")
    #expect(row(app: "", title: "").label == "Untitled")
  }

  @Test func aLongTitleIsCutWithAnEllipsis() {
    let label = row(title: String(repeating: "word ", count: 40)).label
    #expect(label.hasPrefix("Safari: word word"))
    #expect(label.hasSuffix("…"))
    #expect(!label.hasSuffix(" …"))
    #expect(label.count <= "Safari: ".count + OpenWindows.Row.titleLimit)
  }

  @Test func aTitleOfExactlyTheLimitIsWhole() {
    let title = String(repeating: "x", count: OpenWindows.Row.titleLimit)
    #expect(row(title: title).label == "Safari: " + title)
    #expect(row(title: title + "y").label == "Safari: " + title.dropLast() + "…")
  }

  @Test func aLongNameOfAnAppIsCutToo() {
    #expect(row(app: String(repeating: "a", count: 200), title: "").label.count == OpenWindows.Row.appLimit)
  }

  /// A menu's row is one line.
  @Test func lineBreaksAndTabsAreSpaces() {
    #expect(row(title: "one\ntwo\tthree\r\nfour  five ").label == "Safari: one two three four five")
  }

  @Test func aTitleOfAMillionCharactersCostsNothing() {
    #expect(row(title: String(repeating: "x", count: 1_000_000)).label.count == "Safari: ".count + OpenWindows.Row.titleLimit)
  }

  /// One character can be as long as its app likes, too: a letter with 300,000 accents.
  @Test func norDoesOneCharacterOfAMillionScalars() {
    let label = row(title: "e" + String(repeating: "\u{301}", count: 300_000) + " and more").label
    #expect(label.unicodeScalars.count <= "Safari: ".count + 4 * OpenWindows.Row.titleLimit + 1)
    #expect(label.unicodeScalars.starts(with: "Safari: e".unicodeScalars))
  }

  /// What turns the direction of writing round would turn the rest of the row with it, and of the line `menu` prints.
  @Test func marksThatTurnTheWritingRoundAreLeftOut() {
    #expect(row(title: "\u{202E}gnp.exe\u{202C} \u{2066}x\u{2069}\u{200F}").label == "Safari: gnp.exe x")
  }

  /// A title is somebody else's text, and `menu` prints it to a terminal.
  @Test func nothingInATitleGivesATerminalOrders() {
    #expect(row(title: "\u{07}\u{1B}[31mred\u{00}\u{7F}x").label == "Safari: [31mred x")
  }

  @Test func whatHasNoWidthIsLeftOut() {
    #expect(row(title: "a\u{200B}b\u{FEFF}c\u{2060}d").label == "Safari: abcd")
    #expect(row(title: "\u{200B}").label == "Safari")
    #expect(row(title: "👩\u{200D}👧").label == "Safari: 👩\u{200D}👧", "what joins two pictures into one stays")
  }

  @Test func aTitleThatWasCutIsInTheTooltip() {
    #expect(row().help == nil)
    let long = String(repeating: "word ", count: 20)
    #expect(row(title: long).help == long.trimmingCharacters(in: .whitespaces))
    #expect((row(title: String(repeating: "x", count: 10_000)).help ?? "").count == 4 * OpenWindows.Row.titleLimit)
  }

  /// On a Space of its own, or on another of macOS's, the window being typed in is what is seen.
  @Test func theWindowBeingTypedInIsNotSaidToBeElsewhere() {
    #expect(row(place: .fullScreen, hasKeyboard: true).mark == nil)
    #expect(row(place: .otherSpace, hasKeyboard: true).mark == nil)
    #expect(row(place: .outOfView, hasKeyboard: true).mark == "out of view", "that would be a fault, and is not hushed up")
  }

  @Test func whatCanBeSeenHasNoMark() {
    for place in [FinderPlace.inView, .floating, .keptInView, .summoned, .notArranged] { #expect(row(place: place).mark == nil) }
  }

  @Test func whatArborKeepsOutOfSightIsOutOfView() {
    for place in [FinderPlace.outOfView, .tile, .tab, .floatingOutOfView, .stashed] { #expect(row(place: place).mark == "out of view") }
  }

  @Test func whatMacOSKeepsOutOfSightIsCalledAsMacOSCallsIt() {
    #expect(row(place: .hiddenApp).mark == "hidden")
    #expect(row(place: .fullScreen).mark == "full screen")
    #expect(row(place: .otherSpace).mark == "another Space")
    #expect(row(place: .minimized).mark == "minimized")
  }

  /// A mark is a word or two: it stands where a shortcut would.
  @Test func everyMarkIsShort() {
    for place in FinderPlace.allCases { #expect((place.mark ?? "").count <= 13) }
  }
}
