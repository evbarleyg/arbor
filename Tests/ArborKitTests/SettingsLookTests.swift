import ArborCore
import ArborKit
import ArborTesting
import CoreGraphics
import Testing

/// Whether what the settings window says in colour can be seen, reckoned from the grounds it was measured to stand on.
@Suite struct SettingsLookTests {
  struct Ground: CustomStringConvertible, Sendable {
    var description: String
    var isDark: Bool
    var colour: RGBA

    init(_ what: String, dark: Bool = false, white: Double) {
      description = what
      isDark = dark
      colour = RGBA(white: white / 255)
    }
  }

  /// Read off pictures of the real window on a hosted Mac with macOS 26.6 (2026-10-15, run 38696793609): a form's cards, and
  /// what lies round them, which is also what the banner stands on.
  static let measured: [Ground] = [
    Ground("a card", white: 242), Ground("the pane", white: 246),
    Ground("a card", dark: true, white: 43), Ground("the pane", dark: true, white: 40),
  ]

  /// As for the panels' words (`PanelLookTests`): on a picture a small shape does not quite reach its colour.
  static let lostToThinStrokes = 1.15

  @Test(arguments: SettingsLook.Mark.allCases, measured)
  func aMarkStandsOutByThreeToOne(mark: SettingsLook.Mark, ground: Ground) {
    let contrast = SettingsLook.colour(of: mark, isDark: ground.isDark).contrast(with: ground.colour)
    #expect(contrast >= 3 * Self.lostToThinStrokes, "\(mark) on \(ground), dark: \(ground.isDark): \(contrast)")
  }

  /// The control, and why the words are no longer in colour: macOS's orange and red as they came out in those pictures.
  /// Words a person must read to act are asked 4.5 to 1, and two buttons depended on the orange ones.
  @Test func macOSsOrangeAndRedCannotBeReadAsWords() {
    func drawn(_ red: Double, _ green: Double, _ blue: Double) -> RGBA {
      RGBA(red: red / 255, green: green / 255, blue: blue / 255)
    }
    let card = RGBA(white: 242.0 / 255), darkCard = RGBA(white: 43.0 / 255)
    #expect(drawn(255, 141, 40).contrast(with: card) < 3)
    #expect(drawn(255, 56, 60).contrast(with: card) < 4.5)
    #expect(drawn(255, 66, 69).contrast(with: darkCard) < 4.5)
  }

  /// A mark is told by its shape too: whoever cannot tell orange from red still sees which it is.
  @Test func marksDifferInShape() {
    #expect(Set(SettingsLook.Mark.allCases.map(\.symbol)).count == SettingsLook.Mark.allCases.count)
  }
}

/// A setting that does nothing while a switch above it is off says so, and the window dims it.
@Suite @MainActor struct SettingsNeedsTests {
  private func harness(_ change: (inout Settings) -> Void = { _ in }) -> Harness {
    var settings = Settings()
    change(&settings)
    let h = Harness(settings: settings)
    h.start()
    return h
  }

  private func model(_ h: Harness) -> SettingsPanelModel {
    SettingsPanelModel(controller: h.controller, runningApps: { [] }, run: { h.controller.perform($0) })
  }

  private func all(_ model: SettingsPanelModel, in section: SettingsSection) -> [SettingsPanelModel.Row] {
    model.rows(in: section) + model.advancedRows(in: section)
  }

  private func label(_ key: String) throws -> String { try SettingsSchema.entry(named: key).label }

  /// The switches a setting hangs on, the nearest first.
  private func chain(of key: String) -> [String] {
    var chain: [String] = []
    var key = key
    while let next = SettingsSchema.needs[key], !chain.contains(next) {
      chain.append(next)
      key = next
    }
    return chain
  }

  /// Values from both ends of what the schema allows, and for a switch on, off and on again.
  private func extremes(of entry: SettingEntry) -> [String] {
    switch entry.kind {
    case .toggle: ["true", "false", "true"]
    case .number(let range, _, _): [String(range.lowerBound), String(range.upperBound)]
    case .text(let example): [example]
    default: []
    }
  }

  // MARK: The table

  @Test func whatIsNeededIsASwitchFurtherUpInTheSameSectionAndNoHarderToFind() throws {
    #expect(!SettingsSchema.needs.isEmpty)
    let depth: [SettingEntry.Level: Int] = [.normal: 0, .advanced: 1, .hidden: 2]
    for (key, needed) in SettingsSchema.needs {
      let entry = try SettingsSchema.entry(named: key), master = try SettingsSchema.entry(named: needed)
      #expect(entry.key == key && master.key == needed, "spelt as the schema spells them: \(key), \(needed)")
      #expect(master.kind == .toggle, "\(needed) is no switch")
      #expect(master.section == entry.section, "\(key) would be dimmed by a switch of another pane")
      let keys = SettingsSchema.entries(in: entry.section).map(\.key)
      #expect(try #require(keys.firstIndex(of: needed)) < (try #require(keys.firstIndex(of: key))), "\(needed) stands under \(key)")
      #expect(try #require(depth[master.level]) <= (try #require(depth[entry.level])), "\(key) waits for a switch that is harder to find")
    }
  }

  @Test func nothingNeedsItselfHoweverFarRound() {
    for key in SettingsSchema.needs.keys {
      #expect(!chain(of: key).contains(key), "\(key)")
      #expect(SettingsSchema.needs[chain(of: key).last ?? key] == nil, "\(key) hangs on a ring")
    }
  }

  /// Whoever adds a gesture says what it hangs on, or this says so.
  @Test func everyGestureHangsOnTheSwitchAboveThemAll() {
    for entry in SettingsSchema.entries(in: .gestures) where entry.key != "pointerGestures" {
      #expect(chain(of: entry.key).last == "pointerGestures", "\(entry.key)")
    }
  }

  // MARK: What the window says

  @Test func underTheSwitchAboveThemAllEveryGestureWaitsForIt() throws {
    let rows = all(model(harness { $0.pointerGestures = false }), in: .gestures)
    #expect(rows.count > 4)
    for row in rows {
      #expect(row.waitsFor == (row.key == "pointerGestures" ? nil : try label("pointerGestures")), "\(row.key)")
    }
  }

  @Test func withEverySwitchOnNothingWaits() {
    let model = self.model(
      harness {
        $0.pointerGestures = true
        $0.gesturesEnabled = true
        $0.scrollZoom = true
        $0.menuBarControls = true
      })
    for section in SettingsSection.allCases {
      #expect(all(model, in: section).allSatisfy { $0.waitsFor == nil && $0.whyItWaits == nil }, "\(section)")
    }
  }

  /// One level down: the pinch is off, and what hangs on it waits for it, and nothing else does.
  @Test func aSwitchInTheMiddleHoldsOnlyWhatHangsOnIt() throws {
    let model = self.model(
      harness {
        $0.pointerGestures = true
        $0.gesturesEnabled = false
      })
    for row in all(model, in: .gestures) {
      let waits = chain(of: row.key).contains("gesturesEnabled")
      #expect(row.waitsFor == (waits ? try label("gesturesEnabled") : nil), "\(row.key)")
    }
    #expect(all(model, in: .gestures).contains { $0.key == "scrollZoomThreshold" && $0.waitsFor != nil }, "two levels down")
    #expect(all(model, in: .gestures).contains { $0.key == "frameRectangleOnDesktop" && $0.waitsFor == nil })
  }

  /// Switching on the nearer one alone would change nothing.
  @Test func ofTwoThatAreOffTheOuterOneIsNamed() throws {
    let model = self.model(
      harness {
        $0.pointerGestures = false
        $0.gesturesEnabled = false
        $0.scrollZoom = false
      })
    let row = try #require(all(model, in: .gestures).first { $0.key == "scrollZoomThreshold" })
    #expect(row.waitsFor == (try label("pointerGestures")))
  }

  @Test func switchingItInTheWindowLetsTheRowsGoAndTakesThemBack() {
    let model = self.model(harness { $0.pointerGestures = false })
    model.set("pointerGestures", to: true)
    #expect(all(model, in: .gestures).allSatisfy { $0.waitsFor == nil })
    model.set("pointerGestures", to: false)
    #expect(all(model, in: .gestures).filter { $0.waitsFor != nil }.count == all(model, in: .gestures).count - 1)
  }

  /// A search can find a row without the switch it waits for, so the row carries the reason along, in words.
  @Test func aRowFoundByASearchSaysWhatItWaitsFor() throws {
    let model = self.model(harness { $0.pointerGestures = false })
    model.search = "pinch to zoom"
    let pinch = try #require(model.found.sections.flatMap(\.rows).first { $0.key == "gesturesEnabled" })
    #expect(pinch.whyItWaits == "Does nothing while “Trackpad and mouse gestures” is off.")
  }

  /// Nothing typed that can be used is lost, here as anywhere: what stood in a field when its switch went off is the person's.
  @Test func whatWasTypedBeforeTheSwitchWentOffIsStillHandedOver() {
    let h = harness { $0.pointerGestures = true }
    let model = self.model(h)
    model.type("shift", into: .setting("frameRectangleModifier"))
    model.set("pointerGestures", to: false)
    model.handOverDrafts()
    #expect(h.controller.settings.frameRectangleModifier == "shift")
  }

  // MARK: That the window may dim them

  /// What the pointer's taps go by is `inputSettings`, and they ask none of them for `pointerGestures`. So whatever hangs on that switch
  /// directly has to read "off" there while it is off, whatever it is set to. By the table: a gesture that is added, and said to hang
  /// on the switch, fails here until `inputSettings` silences it.
  @Test func whatHangsOnTheSwitchAboveThemAllIsSilencedForTheTaps() throws {
    let h = harness { $0.pointerGestures = false }
    var tried = 0
    for (key, needed) in SettingsSchema.needs where needed == "pointerGestures" {
      let entry = try SettingsSchema.entry(named: key)
      for value in extremes(of: entry) {
        #expect(h.run("set \(key) \(value)").ok, "set \(key) \(value)")
        let silenced: SettingValue = entry.kind == .toggle ? .bool(false) : .text("none")
        #expect(entry.value(in: h.controller.inputSettings) == silenced, "\(key) = \(value)")
        tried += 1
      }
    }
    #expect(tried >= 10)
    // The control: with the switch on they read as they are set.
    #expect(h.run("set pointerGestures true").ok)
    #expect(h.controller.inputSettings.gesturesEnabled && h.controller.inputSettings.frameRectangleOnDesktop)
  }

  /// One and two levels down the taps ask for themselves: without the pinch no tap is installed at all (`GestureTap.update`, which only
  /// a Mac runs), and whether scrolls are listened to is the core's to say.
  @Test func withoutThePinchOrTheScrollNoScrollIsListenedTo() throws {
    for off in ["gesturesEnabled", "scrollZoom"] {
      let h = harness { $0.pointerGestures = true }
      #expect(GestureRouter.listensToScrolls(h.controller.inputSettings), "the control")
      #expect(h.run("set \(off) false").ok)
      for key in SettingsSchema.needs.keys.sorted() where chain(of: key).contains(off) && key != "continuousZoom" {
        for value in extremes(of: try SettingsSchema.entry(named: key)) {
          #expect(h.run("set \(key) \(value)").ok, "set \(key) \(value)")
          #expect(!GestureRouter.listensToScrolls(h.controller.inputSettings), "\(off) off, \(key) = \(value)")
        }
      }
    }
  }

  @Test func withoutTheButtonsTheMenuBarIsTheSameWhateverTheyWouldBeLike() throws {
    let h = harness()
    let window = h.system.open(app: "Safari", frame: CGRect(x: 100, y: 100, width: 600, height: 400))
    h.run("dock \(window.rawValue) left")
    let hanging = SettingsSchema.needs.filter { $0.value == "menuBarControls" }.keys.sorted()
    #expect(hanging.count >= 2)
    // The control: with the buttons there each of them shows.
    for key in hanging {
      let before = h.controller.menuBarModel()
      #expect(h.run("set \(key) \(key == "historyButtons" ? "false" : "1")").ok)
      #expect(h.controller.menuBarModel() != before, "\(key) changes nothing even with the buttons there")
      #expect(h.run("reset \(key)").ok)
    }
    #expect(h.run("set menuBarControls false").ok)
    let single = h.controller.menuBarModel()
    for key in hanging {
      for value in extremes(of: try SettingsSchema.entry(named: key)) {
        #expect(h.run("set \(key) \(value)").ok)
        #expect(h.controller.menuBarModel() == single, "\(key) = \(value)")
      }
    }
  }
}
