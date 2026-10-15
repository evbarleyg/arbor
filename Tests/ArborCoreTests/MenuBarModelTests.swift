import ArborCore
import CoreGraphics
import Foundation
import Testing

private let display = DisplayID("main")
private let safari = WindowID(1)
private let notes = WindowID(2)

/// [Safari | Desktop | Notes], with the camera on everything.
private func makeWorkspace() -> Workspace {
  var workspace = Workspace()
  workspace.dock(safari, at: .cameraEdge(.left))
  workspace.dock(notes, at: .cameraEdge(.right))
  return workspace
}

private func current(_ model: MenuBarModel) -> [MenuBarModel.Button.ID] {
  model.buttons.filter(\.isCurrent).map(\.id)
}

/// What the menu bar item shows (docs/features/F10-menu-bar-and-onboarding.md).
@Suite struct MenuBarModelTests {
  @Test func theButtonsAreHistoryThenPlacesThenSavedViewsInSlotOrder() {
    var workspace = makeWorkspace()
    workspace.saveView(slot: 7)
    workspace.moveCamera(to: workspace.tree.leaf(containing: safari)!)
    workspace.saveView(slot: 2)
    let model = MenuBarModel(display: display, workspace: workspace)
    #expect(model.display == display)
    #expect(model.buttons.map(\.id) == [.back, .forward, .desktop, .everything, .view(2), .view(7), .menu])
    #expect(model.buttons.map(\.command) == [.back, .forward, .desktop, .showAll, .goToView(2), .goToView(7), nil])
    #expect(
      model.buttons.map(\.glyph) == [
        .symbol("chevron.left"), .symbol("chevron.right"), .symbol("menubar.dock.rectangle"), .arbor, .digit(2),
        .digit(7), .symbol("ellipsis"),
      ])
  }

  @Test func backAndForwardCanBeLeftOut() {
    let model = MenuBarModel(display: display, workspace: makeWorkspace(), historyButtons: false)
    #expect(model.buttons.map(\.id) == [.desktop, .everything, .menu])
  }

  @Test func theButtonForWhereTheCameraIsIsCurrent() {
    var workspace = makeWorkspace()
    let leaf = workspace.tree.leaf(containing: safari)!
    #expect(current(MenuBarModel(display: display, workspace: workspace)) == [.everything])

    workspace.moveCamera(to: workspace.tree.desktop)
    #expect(current(MenuBarModel(display: display, workspace: workspace)) == [.desktop])

    workspace.moveCamera(to: leaf)
    #expect(current(MenuBarModel(display: display, workspace: workspace)).isEmpty, "no button names this place")

    workspace.saveView(slot: 4)
    #expect(current(MenuBarModel(display: display, workspace: workspace)) == [.view(4)])
  }

  @Test func buttonsThatNameTheSamePlaceAreCurrentTogether() {
    // With nothing docked the Desktop is everything there is.
    var workspace = Workspace()
    #expect(current(MenuBarModel(display: display, workspace: workspace)) == [.everything], "the Desktop is everything: one is enough")
    workspace.saveView(slot: 1)
    workspace.saveView(slot: 9)
    #expect(current(MenuBarModel(display: display, workspace: workspace)) == [.everything, .view(1), .view(9)])
  }

  @Test func historyButtonsAreEnabledOnlyWhenTheyWouldMoveTheCamera() {
    var workspace = makeWorkspace()
    func history() -> [Bool] {
      let model = MenuBarModel(display: display, workspace: workspace)
      return [model.button(.back)!.isEnabled, model.button(.forward)!.isEnabled]
    }
    #expect(history() == [false, false])
    workspace.moveCamera(to: workspace.tree.leaf(containing: safari)!)
    #expect(history() == [true, false])
    _ = workspace.goBack()
    #expect(history() == [false, true])
    _ = workspace.goForward()
    #expect(history() == [true, false])

    // Both windows close: the camera and the place to go back to are now the same (the Desktop). The core drops such places
    // from the history itself these days; the button looks all the same.
    workspace.forget(safari)
    workspace.forget(notes)
    #expect(history() == [false, false])
    let moved = workspace.goBack()
    #expect(!moved, "the button told the truth")
  }

  @Test func everyOtherButtonIsAlwaysEnabled() {
    var workspace = makeWorkspace()
    workspace.saveView(slot: 1)
    let model = MenuBarModel(display: display, workspace: workspace, historyButtons: false)
    #expect(model.buttons.allSatisfy { $0.isEnabled })
  }

  @Test func tooltipsNameTheShortcutAndWhatAViewHolds() {
    var workspace = makeWorkspace()
    let leaf = workspace.tree.leaf(containing: safari)!
    workspace.saveView(slot: 1)
    workspace.moveCamera(to: leaf)
    workspace.saveView(slot: 2)
    let shortcuts: [(command: Command, label: String)] = [(.back, "⌃⌥["), (.showAll, "⌃⌥Space"), (.goToView(2), "⌃⌥2")]
    let model = MenuBarModel(
      display: display, workspace: workspace,
      shortcut: { command in shortcuts.first { $0.command == command }?.label },
      describe: { $0 == leaf ? "Safari" : nil })
    #expect(
      model.buttons.map(\.tooltip) == [
        "Back (⌃⌥[)", "Forward", "Show the Desktop", "Show Everything (⌃⌥Space)", "View 1", "View 2: Safari (⌃⌥2)",
        "Menu (a right click anywhere opens it too)",
      ])
    // The full menu shows the shortcut in its own column, so it takes the title alone.
    #expect(
      model.buttons.dropLast().map(\.title) == [
        "Back", "Forward", "Show the Desktop", "Show Everything", "View 1", "View 2: Safari",
      ])
  }

  /// Closing windows moves saved views to the nodes that remain, and a damaged state file is mended as it is read, so
  /// nothing gets here today. The model looks all the same (`savedView(slot:)`).
  @Test func aViewWhoseNodeIsGoneGetsNoButton() throws {
    var workspace = makeWorkspace()
    workspace.saveView(slot: 1)
    workspace.saveView(slot: 2)
    var json = try #require(
      JSONSerialization.jsonObject(with: JSONEncoder().encode(workspace)) as? [String: Any])
    var views = try #require(json["savedViews"] as? [String: Any])
    views["2"] = 99
    views["12"] = views["1"]
    json["savedViews"] = views
    let damaged = try JSONDecoder().decode(Workspace.self, from: JSONSerialization.data(withJSONObject: json))
    #expect(damaged.savedViews.keys.sorted() == ["1"], "neither the view of a node that is gone nor slot 12 is read")
    let model = MenuBarModel(display: display, workspace: damaged, historyButtons: false)
    #expect(model.buttons.map(\.id) == [.desktop, .everything, .view(1), .menu])
  }

  @Test func theFillStaysBetweenNothingAndSolid() {
    func fill(_ value: Double) -> Double { MenuBarModel(display: display, workspace: Workspace(), fill: value).fill }
    #expect(fill(0.12) == 0.12)
    #expect(fill(-1) == 0)
    #expect(fill(7) == 1)
    #expect(fill(.nan) == 0.25)
  }

  @Test func theEmptyModelHasNoButtons() {
    #expect(MenuBarModel().buttons.isEmpty)
    #expect(MenuBarModel().display == nil)
  }
}

/// Where the buttons are and what a click on the menu bar item does.
@Suite struct MenuBarLayoutTests {
  /// back, forward (disabled) | Desktop, everything | views 1 and 3 | menu.
  func makeLayout(historyButtons: Bool = true) -> MenuBarLayout {
    var workspace = makeWorkspace()
    workspace.saveView(slot: 3)
    workspace.moveCamera(to: workspace.tree.desktop)
    workspace.saveView(slot: 1)
    return MenuBarLayout(MenuBarModel(display: display, workspace: workspace, historyButtons: historyButtons))
  }

  @Test func cellsAreOnePitchWideWithAGapBetweenGroups() {
    let layout = makeLayout()
    #expect(layout.buttons.map(\.id) == [.back, .forward, .desktop, .everything, .view(1), .view(3), .menu])
    #expect(layout.cells.map(\.minX) == [0, 22, 48, 70, 96, 118, 144])
    #expect(layout.cells.allSatisfy { $0.width == 22 && $0.minY == 0 && $0.height == 22 })
    #expect(layout.size == CGSize(width: 166, height: 22))
    // Without history nothing is left of the places, so no gap either.
    #expect(makeLayout(historyButtons: false).cells.map(\.minX) == [0, 22, 48, 70, 96])
  }

  @Test func theBackgroundOfACurrentButtonStaysInsideItsCell() {
    for cell in makeLayout().cells {
      let chip = MenuBarLayout.chip(in: cell)
      #expect(cell.contains(chip) && chip.width >= 18 && chip.height >= 16)
    }
  }

  @Test func aClickLandsOnTheButtonUnderIt() {
    let layout = makeLayout()
    for (index, cell) in layout.cells.enumerated() {
      for x in [cell.minX + 0.5, cell.midX, cell.maxX - 0.5] {
        #expect(layout.index(atX: x) == index, "x \(x)")
      }
    }
  }

  @Test func noPartOfTheItemIsDead() {
    let layout = makeLayout()
    // macOS pads the image on both sides; clicks there count for the outermost buttons.
    #expect(layout.button(atX: -6)?.id == .back)
    #expect(layout.button(atX: layout.size.width + 6)?.id == .menu)
    // A gap between groups is shared by its neighbours.
    #expect(layout.button(atX: 45)?.id == .forward)
    #expect(layout.button(atX: 47)?.id == .desktop)
    var last = 0
    for x in stride(from: CGFloat(-10), through: layout.size.width + 10, by: 0.5) {
      let index = layout.index(atX: x)
      #expect(index != nil && index! >= last, "x \(x)")
      last = index ?? last
    }
  }

  @Test func aPlainClickRunsTheButtonAndASecondaryClickOpensTheMenu() {
    let layout = makeLayout()
    #expect(layout.click(atX: 11, secondary: false) == .run(.back))
    #expect(layout.click(atX: 33, secondary: false) == .nothing, "there is nothing to go forward to")
    #expect(layout.click(atX: 59, secondary: false) == .run(.desktop))
    #expect(layout.click(atX: 81, secondary: false) == .run(.showAll))
    #expect(layout.click(atX: 107, secondary: false) == .run(.goToView(1)))
    #expect(layout.click(atX: 129, secondary: false) == .run(.goToView(3)))
    #expect(layout.click(atX: 155, secondary: false) == .menu, "the button for those who would never right-click")
    for x in [CGFloat(11), 33, 81, 129] {
      #expect(layout.click(atX: x, secondary: true) == .menu)
    }
  }

  @Test func withoutButtonsEveryClickOpensTheMenu() {
    let layout = MenuBarLayout(MenuBarModel())
    #expect(layout.size.width == 0)
    #expect(layout.index(atX: 5) == nil)
    #expect(layout.click(atX: 5, secondary: false) == .menu)
  }
}

/// Arbor's mark, in the menu bar and on the app icon.
@Suite struct ArborGlyphTests {
  @Test func theMenuBarSizesComeOutInWholePoints() {
    #expect(
      ArborGlyph.cells(in: CGRect(origin: .zero, size: ArborGlyph.buttonSize), gap: 1) == [
        CGRect(x: 8, y: 0, width: 6, height: 12), CGRect(x: 0, y: 6, width: 7, height: 6),
        CGRect(x: 0, y: 0, width: 3, height: 5), CGRect(x: 4, y: 0, width: 3, height: 5),
      ])
    #expect(
      ArborGlyph.cells(in: CGRect(origin: .zero, size: ArborGlyph.iconSize), gap: 1) == [
        CGRect(x: 10, y: 0, width: 8, height: 14), CGRect(x: 0, y: 7, width: 9, height: 7),
        CGRect(x: 0, y: 0, width: 4, height: 6), CGRect(x: 5, y: 0, width: 4, height: 6),
      ])
    // Centred in a button's cell, it still starts on a whole point, so a 1× display draws it sharp.
    let margin = (MenuBarLayout.pitch - ArborGlyph.buttonSize.width) / 2
    #expect(margin == margin.rounded())
    #expect(MenuBarLayout.chip(in: CGRect(x: 0, y: 0, width: 22, height: 22)).width >= ArborGlyph.buttonSize.width + 4)
  }

  @Test func cellsFillTheRectangleAndKeepTheirDistance() {
    for side in [8, 10, 16, 20, 36, 72, 144, 300, 577] {
      let rect = CGRect(x: 3, y: 5, width: CGFloat(side), height: CGFloat(side))
      let gap = max((CGFloat(side) * 0.07).rounded(), 1)
      for leaves in [true, false] {
        let cells = ArborGlyph.cells(in: rect, gap: gap, leaves: leaves)
        #expect(cells.count == (leaves ? 4 : 3))
        #expect(cells.reduce(CGRect.null) { $0.union($1) } == rect, "side \(side)")
        for (index, cell) in cells.enumerated() {
          #expect(cell.width >= 1 && cell.height >= 1, "side \(side), cell \(index)")
          #expect(cell == cell.integralRounded, "side \(side), cell \(index)")
          for other in cells[(index + 1)...] {
            #expect(!cell.insetBy(dx: -gap / 2 + 0.01, dy: -gap / 2 + 0.01).overlaps(other.insetBy(dx: -gap / 2 + 0.01, dy: -gap / 2 + 0.01)))
          }
        }
        if leaves { #expect(cells[2].size == cells[3].size) }
      }
    }
  }

  @Test func theLeavesAreAtTheTopWhicheverWayYGrows() {
    let rect = CGRect(x: 0, y: 0, width: 17, height: 13)
    let down = ArborGlyph.cells(in: rect, gap: 1)
    let up = ArborGlyph.cells(in: rect, gap: 1, yUp: true)
    #expect(down[2].minY == rect.minY && down[1].maxY == rect.maxY)
    #expect(up[2].maxY == rect.maxY && up[1].minY == rect.minY)
    // One is the mirror image of the other.
    #expect(up == down.map { CGRect(x: $0.minX, y: rect.maxY - $0.maxY, width: $0.width, height: $0.height) })
  }

  @Test func everyCellHasAnOpacity() {
    #expect(ArborGlyph.opacities.count == ArborGlyph.cells(in: CGRect(x: 0, y: 0, width: 100, height: 100), gap: 7).count)
  }
}

@Suite struct MenuKeyEquivalentTests {
  @Test func everyKeyHasItsOwnKeyEquivalent() {
    let all = KeyChord.Key.allCases.map(\.menuKeyEquivalent)
    #expect(Set(all).count == all.count)
    #expect(all.allSatisfy { $0.unicodeScalars.count == 1 })
  }

  @Test func lettersStayLowercaseSoThatMenusDoNotAddShift() {
    #expect(KeyChord.Key.a.menuKeyEquivalent == "a")
    #expect(KeyChord.Key.digit1.menuKeyEquivalent == "1")
    #expect(KeyChord.Key.leftBracket.menuKeyEquivalent == "[")
    #expect(KeyChord.Key.space.menuKeyEquivalent == " ")
    #expect(KeyChord.Key.returnKey.menuKeyEquivalent == "\r")
  }
}

/// The commands and settings that came with the menu bar controls and the welcome window.
@Suite struct MenuBarCommandAndSettingsTests {
  @Test(arguments: [Command.doctor, .checkSetup, .welcome, .menuBar]) func textRoundTrips(command: Command) throws {
    #expect(try Command.parse(command.text) == command)
    #expect(throws: Command.ParseError.self) { try Command.parse(command.text + " now") }
    #expect(Command.helpText.contains(" \(command.text) "))
  }

  @Test func otherWordsForThem() throws {
    #expect(try Command.parse("permissions") == .checkSetup)
    #expect(try Command.parse("setup") == .checkSetup)
    #expect(try Command.parse("Doctor") == .doctor)
  }

  @Test func onlyTheOnesThatAnswerAreQueries() {
    #expect(Command.doctor.isQuery && Command.menuBar.isQuery)
    #expect(!Command.checkSetup.isQuery && !Command.welcome.isQuery, "they open a window, so a shortcut may run them")
  }

  /// None of them moves the view or arranges windows, and a web page has no business opening Arbor's windows.
  @Test func noneOfThemIsAcceptedFromAURL() {
    for command in [Command.doctor, .checkSetup, .welcome, .menuBar] { #expect(!command.isAllowedFromURL) }
  }

  @Test func anOldSettingsFileGetsTheMenuBarDefaults() throws {
    let settings = try JSONDecoder().decode(Settings.self, from: Data(#"{"gap": 20}"#.utf8))
    #expect(!settings.menuBarControls)
    #expect(settings.historyButtons)
    #expect(settings.menuBarFill == 0.25)
  }

  @Test func theMenuBarSettingsRoundTrip() throws {
    var settings = Settings()
    settings.menuBarControls = true
    settings.historyButtons = false
    settings.menuBarFill = 0.12
    let decoded = try JSONDecoder().decode(Settings.self, from: JSONEncoder().encode(settings))
    #expect(decoded == settings)
  }
}
