import ArborCore
import Testing

/// The menu as values (docs/ARCHITECTURE.md, "The menu").
@Suite struct MenuModelTests {
  typealias Item = MenuModel.Item
  typealias Section = MenuModel.Section

  @Test func anItemStartsPlainAndSaysTheRestInAChain() {
    let plain = Item.command("Float", .float(nil))
    #expect(plain.command == .float(nil))
    #expect(plain.isEnabled && !plain.isTicked && plain.shortcut == nil && plain.help == nil)

    let full = plain.enabled(false).ticked(true).help("Takes it out of the arrangement")
    #expect(!full.isEnabled && full.isTicked)
    #expect(full.help == "Takes it out of the arrangement")
    #expect(full.title == "Float" && full.command == .float(nil))
  }

  @Test func whatOneReasonGreysOutAnotherDoesNotBringBack() {
    #expect(!Item.command("Back", .back).enabled(false).enabled(true).isEnabled)
    #expect(!Item.text("Arbor is paused").enabled(true).isEnabled, "a line of text can never be chosen")
  }

  @Test func anItemFollowsTheMenuBarButtonForTheSamePlace() {
    func button(enabled: Bool, current: Bool) -> MenuBarModel.Button {
      MenuBarModel.Button(
        id: .back, command: .back, glyph: .arbor, isEnabled: enabled, isCurrent: current, title: "Back")
    }
    let item = Item.command("Back", .back)
    #expect(!item.like(button(enabled: false, current: false)).isEnabled)
    #expect(item.like(button(enabled: true, current: true)).isTicked)
    let alone = item.like(nil)
    #expect(alone.isEnabled && !alone.isTicked, "no such button: nothing is known against it")
  }

  @Test func aSectionIsAListWithIfAndFor() {
    func section(more: Bool) -> Section {
      Section("View") {
        Item.command("Back", .back)
        if more { Item.command("Forward", .forward) }
        for slot in 1...2 { Item.command("View \(slot)", .goToView(slot)) }
        if more { Item.text("yes") } else { Item.text("no") }
        [Item.command("Step In", .stepIn), Item.command("Step Out", .stepOut)]
      }
    }
    #expect(section(more: true).items.map(\.title) == ["Back", "Forward", "View 1", "View 2", "yes", "Step In", "Step Out"])
    #expect(section(more: false).items.map(\.title) == ["Back", "View 1", "View 2", "no", "Step In", "Step Out"])
  }

  @Test func whatTurnsOutEmptyIsLeftOut() {
    let none: [String] = []
    let model = MenuModel([
      Section("View") { Item.command("Back", .back) },
      Section("Nothing") { for title in none { Item.text(title) } },
      Section("Arbor") {
        Item.submenu("Arrange Again") { for title in none { Item.text(title) } }
        Item.submenu("Saved Views", sections: [Section("Go To") { for title in none { Item.text(title) } }])
      },
    ])
    #expect(model.sections.map(\.title) == ["View"], "a submenu with nothing in it goes, and then so does its section")
  }

  @Test func shortcutsAreFilledInEverywhereButWhereTheyWouldMislead() {
    let chord = MenuModel.Shortcut(KeyChord([.control, .option], .d))
    let model = MenuModel([
      Section {
        Item.command("Show the Desktop", .desktop)
        Item.command("Also the Desktop", .desktop).withoutShortcut()
        Item.command("Back", .back)
        Item.app("Quit Arbor", .quit).shortcut(KeyChord(.command, .q))
        Item.submenu("More") { Item.command("The Desktop Again", .desktop) }
      }
    ]).showingShortcuts { $0 == .desktop ? chord : nil }
    #expect(model.item("Show the Desktop")?.shortcut == chord)
    #expect(model.item("Also the Desktop")?.shortcut == nil)
    #expect(model.item("Back")?.shortcut == nil, "nothing is registered for it")
    #expect(model.item("Quit Arbor")?.shortcut?.label == "⌘Q", "its own stays")
    #expect(model.item("The Desktop Again")?.shortcut == chord, "in submenus too")
  }

  @Test func aShortcutIsWhatAppKitDrawsAndWhatAPersonReads() {
    let space = MenuModel.Shortcut(KeyChord([.control, .option], .space))
    #expect(space.label == "⌃⌥Space" && space.keyEquivalent == " " && space.modifiers == [.control, .option])
    let letter = MenuModel.Shortcut(KeyChord([.control, .option, .shift], .f))
    #expect(letter.label == "⌃⌥⇧F" && letter.keyEquivalent == "f", "a capital would mean ⇧ a second time")
    #expect(MenuModel.Shortcut(KeyChord(.hyperlessForTests, .up)).keyEquivalent == "\u{F700}")
  }

  @Test func aRuleForEveryItemReachesSubmenus() {
    let model = MenuModel([
      Section {
        Item.command("Back", .back)
        Item.submenu("More") { Item.command("Forward", .forward) }
      }
    ]).mapItems { $0.enabled($0.command != .forward) }
    #expect(model.item("Back")?.isEnabled == true)
    #expect(model.item("More")?.isEnabled == true)
    #expect(model.item("Forward")?.isEnabled == false)
    #expect(model.allItems.map(\.title) == ["Back", "More", "Forward"])
  }

  @Test func theTextShowsEverythingAPersonWouldSee() {
    let model = MenuModel([
      Section("View") {
        Item.command("Show Everything", .showAll).ticked(true).shortcut(KeyChord([.control, .option], .space))
        Item.command("Back", .back).enabled(false)
        Item.submenu(
          "Saved Views",
          sections: [
            Section("Go To") { Item.command("View 1", .goToView(1)) },
            Section("Save This View As") { Item.command("View 2", .saveView(2)) },
          ])
        Item.submenu("Dock") { Item.command("Left", .dock(nil, .left)) }
      },
      Section { Item.text("Arbor 0.1.0") },
    ])
    #expect(
      model.text == """
        View
          ✓ Show Everything  ⌃⌥Space
            Back  (gray)
            Saved Views ▸
                Go To
                    View 1
                Save This View As
                    View 2
            Dock ▸
                Left
        -----
            Arbor 0.1.0  (gray)
        """)
  }

  /// As `StatusMenu.fill` builds it: a separator above every section but the first, a heading for a title. Submenus are menus of their own.
  @Test func aMenuIsAsHighAsItsRowsSeparatorsAndHeadings() {
    let model = MenuModel([
      Section { Item.text("Arbor is paused") },
      Section("View") {
        Item.command("Back", .back)
        Item.submenu("Saved Views") { for slot in 1...9 { Item.command("View \(slot)", .goToView(slot)) } }
      },
      Section { Item.app("Quit Arbor", .quit) },
    ])
    // Four rows, two separators, a heading, and the room above and below.
    #expect(model.height == 152, "4 × 24 + 2 × 11 + 24 + 2 × 5")
    #expect(MenuModel.height(of: model.item("Saved Views")?.sections ?? []) == 226, "9 × 24 + 2 × 5")
    let earlier = MenuModel.Metrics(row: 22, separator: 11, heading: 22, padding: 5)
    #expect(MenuModel.height(of: model.sections, earlier) == 142, "4 × 22 + 2 × 11 + 22 + 2 × 5")
  }

  /// What `NSMenu` answered on a hosted Mac with macOS 26, for Arbor's menu and its six submenus. The sizes are solved from
  /// these; `MenuHeightAppKitTests` asks again wherever the tests run on a Mac.
  @Test func theSizesGiveWhatNSMenuAnswered() {
    let answers: [(rows: Int, separators: Int, headings: Int, height: Double)] = [
      (4, 0, 0, 106), (3, 1, 0, 93), (7, 2, 0, 200), (8, 2, 0, 224), (7, 3, 0, 211), (18, 4, 0, 486), (10, 1, 1, 285),
    ]
    for answer in answers {
      // A section more than there are separators; all rows but one for each of the others in the first.
      let sections = (0...answer.separators).map { index in
        Section(index < answer.headings ? "Heading" : nil) {
          for row in 0..<(index == 0 ? answer.rows - answer.separators : 1) { Item.text("Row \(row)") }
        }
      }
      #expect(MenuModel.height(of: sections) == answer.height, "\(answer)")
    }
  }
}

extension KeyChord.Modifiers {
  fileprivate static let hyperlessForTests: KeyChord.Modifiers = [.control, .option]
}
