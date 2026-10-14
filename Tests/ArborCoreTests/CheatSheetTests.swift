import ArborCore
import Testing

/// What the panel of shortcuts lists (docs/features/F43-say-what-happened.md).
@Suite struct CheatSheetTests {
  private typealias Shortcut = (chord: KeyChord, command: Command)
  private let base: KeyChord.Modifiers = [.control, .option]
  private let digits: [KeyChord.Key] = [.digit1, .digit2, .digit3, .digit4, .digit5, .digit6, .digit7, .digit8, .digit9]

  private func views(_ modifiers: KeyChord.Modifiers) -> [Shortcut] {
    digits.enumerated().map { (KeyChord(modifiers, $1), .goToView($0 + 1)) }
  }

  private func rows(_ shortcuts: [Shortcut]) -> [String] {
    CheatSheetModel(shortcuts: shortcuts).sections.flatMap(\.rows).map { "\($0.keys) \($0.title)" }
  }

  @Test func sectionsAreTheHelpsGroupsInTheHelpsOrder() {
    let model = CheatSheetModel(shortcuts: [
      (KeyChord(base, .escape), .togglePause), (KeyChord(base, .a), .arrange), (KeyChord(base, .down), .stepIn),
      (KeyChord(base, .space), .showAll), (KeyChord(base, .up), .stepOut),
    ])
    #expect(model.sections.map(\.title) == ["Look", "Arrange", "Arbor itself"])
    #expect(model.sections[0].rows.map(\.title) == ["Show Everything", "Step Out", "Step In"])
    #expect(model.sections[0].rows.map(\.keys) == ["⌃⌥Space", "⌃⌥↑", "⌃⌥↓"])
  }

  @Test func aGroupWithoutShortcutsIsLeftOut() {
    #expect(CheatSheetModel(shortcuts: [(KeyChord(base, .a), .arrange)]).sections.map(\.title) == ["Arrange"])
    #expect(CheatSheetModel(shortcuts: []).columns.isEmpty)
  }

  @Test func nineViewsAreOneRow() {
    #expect(rows(views(base)) == ["⌃⌥1–9 Go to a Saved View"])
  }

  @Test func fourArrowsAreOneRow() {
    let move: KeyChord.Modifiers = [.control, .option, .command]
    let docks: [Shortcut] = [
      (KeyChord(move, .left), .dock(nil, .left)), (KeyChord(move, .right), .dock(nil, .right)),
      (KeyChord(move, .up), .dock(nil, .top)), (KeyChord(move, .down), .dock(nil, .bottom)),
    ]
    #expect(rows(docks) == ["⌃⌥⌘ + arrow Dock Focused Window, or Move It"])
  }

  @Test func aFamilyWithAMemberMissingOrMovedIsListedSingly() {
    var changed = views(base)
    changed[4] = (KeyChord(base, .v), .goToView(5))
    let listed = rows(changed)
    #expect(listed.count == 9)
    #expect(listed[0] == "⌃⌥1 View 1")
    #expect(listed[4] == "⌃⌥V View 5", "in the order of the views, not of the keys")
    #expect(rows(Array(views(base).dropLast())).count == 8)
  }

  @Test func shortFormsStandBeforeTheirFoldedFamily() {
    let shifted: KeyChord.Modifiers = [.control, .option, .shift]
    let shortcuts: [Shortcut] = [
      (KeyChord(shifted, .left), .neighbor(.left)), (KeyChord(shifted, .right), .neighbor(.right)),
      (KeyChord(shifted, .up), .neighbor(.top)), (KeyChord(shifted, .down), .neighbor(.bottom)),
      (KeyChord(base, .right), .neighbor(.right)), (KeyChord(base, .left), .neighbor(.left)),
    ]
    #expect(rows(shortcuts) == ["⌃⌥← Space to the Left", "⌃⌥→ Space to the Right", "⌃⌥⇧ + arrow Neighbouring Space"])
  }

  @Test func twoShortcutsForOneCommandAreBothListed() {
    #expect(rows([(KeyChord(base, .space), .showAll), (KeyChord(base, .e), .showAll)]) == ["⌃⌥E Show Everything", "⌃⌥Space Show Everything"])
  }

  @Test func theOrderOfTheInputDoesNotMatter() {
    let shortcuts = views(base) + [(KeyChord(base, .space), .showAll), (KeyChord(base, .a), .arrange), (KeyChord(base, .f), .toggleFloat(nil))]
    #expect(CheatSheetModel(shortcuts: shortcuts) == CheatSheetModel(shortcuts: shortcuts.reversed()))
  }

  // MARK: Columns

  /// Distinct chords on commands of each group; what they are called does not matter here.
  private func shortcuts(look: Int, arrange: Int, arbor: Int) -> [Shortcut] {
    let keys = KeyChord.Key.allCases
    var shortcuts: [Shortcut] = []
    for index in 0..<look { shortcuts.append((KeyChord(base, keys[index]), .zoomNode(NodeID(index)))) }
    for index in 0..<arrange { shortcuts.append((KeyChord([.control], keys[index]), .resize(nil, .left, Double(index)))) }
    for index in 0..<arbor { shortcuts.append((KeyChord([.option, .command], keys[index]), .pause(minutes: Double(index + 1)))) }
    return shortcuts
  }

  private func sheet(look: Int, arrange: Int, arbor: Int) -> CheatSheetModel {
    CheatSheetModel(shortcuts: shortcuts(look: look, arrange: arrange, arbor: arbor))
  }

  @Test func aShortListIsOneColumn() {
    #expect(sheet(look: 4, arrange: 2, arbor: 1).columns.count == 1)
  }

  @Test func aLongerListIsTwoColumnsOfAboutTheSameHeight() {
    let model = sheet(look: 13, arrange: 4, arbor: 2)
    #expect(model.columns.map { $0.map(\.title) } == [["Look"], ["Arrange", "Arbor itself"]])
    #expect(sheet(look: 4, arrange: 5, arbor: 12).columns.map { $0.map(\.title) } == [["Look", "Arrange"], ["Arbor itself"]])
  }

  @Test func aVeryLongListIsThreeColumns() {
    #expect(sheet(look: 20, arrange: 20, arbor: 10).columns.count == 3)
    let pointer = (1...6).map { CheatSheetModel.Row(keys: "Gesture \($0)", title: "Does \($0)") }
    let four = CheatSheetModel(shortcuts: shortcuts(look: 22, arrange: 12, arbor: 4), pointer: pointer)
    #expect(four.columns.map { $0.map(\.title) } == [["Look"], ["Arrange"], ["Arbor itself", "Pointer and trackpad"]])
  }

  @Test func theDefaultsFillTwoColumnsEvenly() {
    let pointer = (1...6).map { CheatSheetModel.Row(keys: "Gesture \($0)", title: "Does \($0)") }
    let model = CheatSheetModel(shortcuts: shortcuts(look: 13, arrange: 4, arbor: 2), pointer: pointer)
    #expect(model.columns.map { $0.map(\.title) } == [["Look"], ["Arrange", "Arbor itself", "Pointer and trackpad"]])
  }

  // MARK: The pointer's part

  @Test func thePointersPartComesLastAndOnlyIfThereIsOne() {
    let row = CheatSheetModel.Row(keys: "Drag a gap", title: "Resize Both Sides")
    #expect(CheatSheetModel(shortcuts: [(KeyChord(base, .a), .arrange)], pointer: [row]).sections.map(\.title) == ["Arrange", "Pointer and trackpad"])
    #expect(CheatSheetModel(shortcuts: [(KeyChord(base, .a), .arrange)]).sections.map(\.title) == ["Arrange"])
  }

  @Test func gesturesThatAreSwitchedOffAreNotListed() {
    func keys(_ change: (inout Settings) -> Void) -> [String] {
      var settings = Settings()
      change(&settings)
      return CheatSheetModel.pointerRows(settings: settings).map(\.keys)
    }
    #expect(keys { _ in }.suffix(3) == ["⌥ + pinch", "⌃⌥ + drag", "⇧ + drag on the Desktop"])
    #expect(keys { $0.frameRectangleOnDesktop = false }.last == "⌃⌥ + drag")
    #expect(!keys { $0.gesturesEnabled = false }.contains("⌥ + pinch"))
    #expect(keys { $0.frameRectangleModifier = "Opt + Ctrl" }.contains("⌃⌥ + drag"))
    #expect(!keys { $0.frameRectangleModifier = "none" }.contains { $0.hasSuffix("+ drag") })
    #expect(!keys { $0.frameRectangleModifier = "nonsense" }.contains { $0.hasSuffix("+ drag") })
    #expect(keys { _ in }.first == "Drag to a screen edge")
  }

  @Test func sectionsStayInOrderWhateverTheColumns() {
    for model in [sheet(look: 1, arrange: 1, arbor: 1), sheet(look: 13, arrange: 4, arbor: 2), sheet(look: 30, arrange: 30, arbor: 30)] {
      #expect(model.sections.map(\.title) == ["Look", "Arrange", "Arbor itself"])
    }
  }

  // MARK: As text

  @Test func anEndlessTitleIsCutSoThatThePanelNeedNotShrinkForIt() throws {
    let long = try Command.parse("layout Safari | (Mail / Notes) | (Terminal / Xcode / Finder) | (Music / Podcasts / Books) | Reminders")
    let model = CheatSheetModel(shortcuts: [(KeyChord([.control, .option], .a), long), (KeyChord([.control, .option], .b), .togglePin(nil))])
    let titles = model.sections.flatMap(\.rows).map(\.title)
    #expect(titles.contains("Arrange as Safari | (Mail / Notes) | (Terminal …"), "\(titles)")
    #expect(titles.contains(Command.togglePin(nil).title), "the longest of Arbor's own is whole")
    #expect(titles.allSatisfy { $0.count <= 48 })
  }

  @Test func theTextFormLinesUp() {
    let model = CheatSheetModel(shortcuts: [(KeyChord(base, .space), .showAll), (KeyChord(base, .up), .stepOut), (KeyChord(base, .a), .arrange)])
    #expect(model.text == """
      Look
        ⌃⌥Space  Show Everything
        ⌃⌥↑      Step Out

      Arrange
        ⌃⌥A      Arrange Windows
      """)
  }
}
