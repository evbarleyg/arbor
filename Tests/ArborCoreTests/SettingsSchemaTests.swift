import ArborCore
import CoreGraphics
import Foundation
import Testing

/// `settings` as the top-level object of settings.json.
private func json(_ settings: Settings) throws -> [String: Any] {
  let object = try JSONSerialization.jsonObject(with: JSONEncoder().encode(settings))
  return try #require(object as? [String: Any])
}

/// Any JSON value as text that is the same for equal values, whatever order dictionaries come in.
private func canonical(_ value: Any) throws -> String {
  String(
    decoding: try JSONSerialization.data(withJSONObject: value, options: [.sortedKeys, .fragmentsAllowed]),
    as: UTF8.self)
}

private func decode(_ text: String) throws -> Settings {
  try JSONDecoder().decode(Settings.self, from: Data(text.utf8))
}

/// What a refused call says, or nil if it was not refused.
private func refusal(_ body: () throws -> Void) -> String? {
  do {
    try body()
    return nil
  } catch {
    return "\(error)"
  }
}

/// A valid value for `entry` other than its default.
private func anotherValue(for entry: SettingEntry) throws -> SettingValue {
  switch (entry.kind, entry.defaultValue) {
  case (.toggle, .bool(let flag)):
    return .bool(!flag)
  case (.number(let range, _, _), .number(let number)):
    return .number(number == range.upperBound ? range.lowerBound : range.upperBound)
  case (.choice(let choices), .text(let text)):
    return .text(try #require(choices.first { $0.value != text }, "\(entry.key) offers no choice").value)
  case (.text(let example), _):
    return .text(example)
  default:
    throw SchemaMismatch(key: entry.key)
  }
}

private struct SchemaMismatch: Error { var key: String }

private let simpleEntries = SettingsSchema.entries.filter {
  if case .list = $0.kind { false } else { true }
}

/// The list itself: complete, consistent, and honest about which key each entry stands for.
@Suite struct SettingsSchemaTests {
  @Test func everySettingsKeyHasASchemaEntry() throws {
    let keys = Set(try json(Settings()).keys)
    let described = Set(SettingsSchema.entries.map(\.key))
    #expect(
      keys.subtracting(described).isEmpty,
      "add an entry for these keys to their section in Sources/ArborCore/SettingsSchema.swift (its first comment shows how)"
    )
    #expect(described.subtracting(keys).isEmpty, "these entries have no key in Settings.CodingKeys")
  }

  @Test func keysAreDistinctEvenIgnoringCase() {
    let keys = SettingsSchema.entries.map { $0.key.lowercased() }
    #expect(Set(keys).count == keys.count)
    // `reset all` and `reset everything` must stay unambiguous.
    #expect(!keys.contains("all") && !keys.contains("everything"))
  }

  @Test func everyEntryReadsAndWritesTheKeyItIsNamedAfter() throws {
    let before = try json(Settings())
    for entry in simpleEntries {
      let value = try anotherValue(for: entry)
      var settings = Settings()
      try entry.set(value, in: &settings)
      #expect(entry.value(in: settings) == value, "\(entry.key)")
      #expect(!entry.isDefault(in: settings), "\(entry.key)")
      let after = try json(settings)
      let changed = try after.keys.filter { try canonical(after[$0]!) != canonical(before[$0]!) }
      #expect(changed == [entry.key], "setting \(entry.key) changed \(changed)")
      entry.reset(in: &settings)
      #expect(settings == Settings(), "\(entry.key)")
    }
  }

  @Test func listsAreReadAsTheJSONOfTheirKey() throws {
    var settings = Settings()
    settings.excludedBundleIDs = ["com.apple.Music", "com.apple/odd"]
    settings.bindings = ["ctrl+opt+h": "dock left", "ctrl+opt+d": nil]
    settings.rules = [AppRule(app: "com.apple.mail", title: "Inbox", action: .dock(.left))]
    settings.holdStillFor = ["com.google.Chrome Meet"]
    settings.displays = [DisplayOptions(match: .builtIn, gap: 8), DisplayOptions(match: .width(.atLeast, 2500), minimumUsableWidth: 300)]
    let lists = SettingsSchema.entries.filter { !simpleEntries.map(\.key).contains($0.key) }
    #expect(Set(lists.map(\.key)).isSuperset(of: ["bindings", "excludedBundleIDs", "rules"]))
    for entry in lists where entry.isAppList { entry.setApps(["com.apple.Music", "com.apple/odd"], in: &settings) }
    let whole = try json(settings)
    // A list of another shape that comes later is at least read, and reset, from its default.
    for entry in lists where entry.isDefault(in: settings) {
      #expect(try canonical(JSONSerialization.jsonObject(with: Data(entry.defaultValue.text.utf8))) == canonical(whole[entry.key]!))
    }
    for entry in lists where !entry.isDefault(in: settings) {
      let text = entry.value(in: settings).text
      let parsed = try JSONSerialization.jsonObject(with: Data(text.utf8))
      #expect(try canonical(parsed) == canonical(whole[entry.key]!), "\(entry.key)")
      #expect(!entry.isDefault(in: settings))
      entry.reset(in: &settings)
      #expect(entry.isDefault(in: settings))
    }
    #expect(settings == Settings())
    #expect(try SettingsSchema.entry(named: "rules").defaultValue == .list(json: "[]", count: 0))
    #expect(try SettingsSchema.entry(named: "bindings").defaultValue == .list(json: "{}", count: 0))
  }

  @Test func everyEntryIsFitToShow() throws {
    for entry in SettingsSchema.entries {
      #expect(!entry.label.isEmpty && entry.label.count <= 40, "\(entry.key): the label is a few words")
      #expect(entry.help.hasSuffix(".") && !entry.help.contains("\n"), "\(entry.key): the help is a sentence")
      #expect(SettingsSchema.entries(in: entry.section).contains { $0.key == entry.key })
    }
    for entry in simpleEntries {
      #expect(
        try entry.validated(entry.defaultValue) == entry.defaultValue, "\(entry.key): the default must be valid"
      )
      #expect(try entry.parse(entry.defaultValue.text) == entry.defaultValue, "\(entry.key)")
      #expect(try anotherValue(for: entry) != entry.defaultValue, "\(entry.key)")
      if case .number(let range, let step, _) = entry.kind {
        #expect(range.lowerBound < range.upperBound, "\(entry.key)")
        #expect(step > 0 && step <= range.upperBound - range.lowerBound, "\(entry.key)")
      }
    }
  }

  /// docs/GLOSSARY.md, "Do not say". Keys keep their names; this is about what the settings window shows.
  @Test func whatTheWindowShowsIsInTheGlossarysWords() {
    let instead = [
      "hotkey": "shortcut", "hotkeys": "shortcuts", "binding": "shortcut", "bindings": "shortcuts", "chord": "shortcut",
      "seam": "gap", "seams": "gaps", "divider": "gap", "stack": "tab group", "stacks": "tab groups",
      "monitor": "display", "monitors": "displays", "camera": "the view", "viewport": "the view", "parked": "out of view",
      "off-screen": "out of view", "offscreen": "out of view", "node": "space", "nodes": "spaces", "workspace": "space",
      "managed": "arranged", "unmanaged": "floating", "undock": "float", "snap": "dock", "maximise": "frame",
      "maximize": "frame", "wallpaper": "the Desktop", "thumbnail": "tile", "bookmark": "saved view", "disable": "pause",
    ]
    let meantLiterally: [String: Set<String>] = [
      "camera": ["holdStillWhileCameraIsOn", "holdStillWhileMicrophoneIsOn"],
      "wallpaper": ["dimBehindArranged", "blurBehindArranged", "tintBehindArranged"],
    ]
    for entry in SettingsSchema.entries where entry.level != .hidden {
      var texts = [entry.label, entry.help]
      if case .choice(let choices) = entry.kind { texts += choices.map(\.label) }
      // What stands between “ and ” is somebody else's name for something, such as a switch in System Settings.
      let own = texts.joined(separator: " ").split(separator: "“").enumerated().map { index, part in
        index == 0 ? part : part.drop { $0 != "”" }
      }
      let words = own.joined(separator: " ").lowercased().split { !($0.isLetter || $0 == "-") }.map(String.init)
      for (index, word) in words.enumerated() {
        if let better = instead[word], meantLiterally[word]?.contains(entry.key) != true { Issue.record("\(entry.key): say “\(better)”, not “\(word)”") }
        // "Screen edge" and "on screen" are the two places for the word.
        let isIdiom = (words.dropFirst(index + 1).first ?? "").hasPrefix("edge") || (index > 0 && words[index - 1] == "on")
        if word == "screen" || word == "screens", !isIdiom {
          Issue.record("\(entry.key): say “display”, not “\(word)”")
        }
      }
    }
  }

  /// The window draws the help as plain text beside a control. Code marks come out as backticks there, what settings.json calls a
  /// choice is not what the menu beside it offers, and how sure its builders are is said in one word people know.
  @Test func whatTheWindowShowsIsWrittenForTheWindow() {
    for entry in SettingsSchema.entries where entry.level != .hidden {
      #expect(!entry.help.contains("`") && !entry.label.contains("`"), "\(entry.key): no code in the window")
      if case .choice(let choices) = entry.kind {
        for choice in choices {
          #expect(!"\(entry.help) ".lowercased().contains("\(choice.value.lowercased()): "), "\(entry.key): “\(choice.value):” is the file's word")
        }
      }
      for phrase in ["not yet", "seen at work", "from memory", "not ready", "an experiment"] {
        #expect(!entry.help.lowercased().contains(phrase), "\(entry.key): “\(phrase)” is the builders' talk; say Experimental")
      }
    }
  }

  /// What the window has no use for is not lost: it follows the help where values and commands are typed.
  @Test func whatIsTypedIsExplainedWhereItIsTyped() throws {
    let report = SettingsSchema.report(Settings()), page = SettingsSchema.markdown()
    for words in [
      "`toggle-auto-dock` switches it too.", "`resize` moves a window's edge whatever this says.",
      "0 leaves it as it is, 1 is black.", "0 is gray, 1 is the color itself.",
      "That is `dock auto` and a rule for `*`; a rule that names an app docks its windows whatever their size.",
    ] {
      #expect(report.contains(words) && page.contains(words), "\(words)")
      #expect(!SettingsSchema.entries.contains { $0.help.contains(words) })
    }
  }

  /// Said in the schema and not guessed from the numbers: the next ratio from 0 to 1 need not be a share of anything.
  @Test func aShareIsANumberFromNoughtToOneAtMostWithoutAUnit() throws {
    let shares = SettingsSchema.entries.filter(\.isShare).map(\.key)
    #expect(
      Set(shares) == [
        "windowEdgeFraction", "dimBehindArranged", "blurBehindArranged", "appColourAmount", "tintBehindArranged", "desktopEdge",
      ])
    for entry in SettingsSchema.entries where entry.isShare {
      guard case .number(let range, _, let unit) = entry.kind else {
        Issue.record("\(entry.key) is no number")
        continue
      }
      #expect(unit.isEmpty && range.lowerBound >= 0 && range.upperBound <= 1, "\(entry.key)")
    }
  }

  @Test func aChoicesValuesAreExplainedWhereTheyAreTyped() throws {
    let entry = try SettingsSchema.entry(named: "newWindowsWhileFramed")
    let note = "`guest`: Stay with that view. `float`: Belong to the Desktop."
    #expect(!entry.help.contains("guest"))
    #expect(SettingsSchema.report(Settings()).contains("floating window. \(note)\n"))
    #expect(SettingsSchema.markdown().contains("floating window. \(note) |"))
  }

  @Test func levelsDecideOnlyWhereASettingIsShown() throws {
    #expect(try SettingsSchema.entry(named: "gap").level == .normal)
    #expect(try SettingsSchema.entry(named: "screenEdgeBand").level == .advanced)
    #expect(try SettingsSchema.entry(named: "focusRingRadius").level == .hidden)
    #expect(SettingsSchema.entries.allSatisfy { $0.isAdvanced == ($0.level != .normal) })
    let hidden = SettingEntry.toggle("x", \.tabsEnabled, "X", "X.", advanced: true, hidden: true)
    #expect(hidden.level == .hidden)
    // A hidden setting is as good as any other everywhere but in the window.
    let radius = try SettingsSchema.entry(named: "focusRingRadius")
    var settings = Settings()
    try radius.set(try radius.parse("10"), in: &settings)
    #expect(settings.focusRingRadius == 10)
    #expect(SettingsSchema.report(settings).contains("\n* focusRingRadius = 10  ("))
    #expect(SettingsSchema.markdown().contains("| `focusRingRadius` | `0` | 0 to 60 pt | "))
    #expect(SettingsSchema.markdown().contains("*Not in the settings window.* |"))
  }

  @Test func aSearchLooksAtLabelHelpAndKey() throws {
    let gap = try SettingsSchema.entry(named: "gap")
    for words in ["gap", "GAP", "space between", "between space", "screen edges", "docked win", ""] {
      #expect(gap.matches(search: words), "\(words)")
    }
    for words in ["pinch", "gap pinch", "gapp"] { #expect(!gap.matches(search: words), "\(words)") }
    #expect(try SettingsSchema.entry(named: "hotkeysEnabled").matches(search: "shortcuts"))
    #expect(try SettingsSchema.entry(named: "hotkeysEnabled").matches(search: "hotkeys"))
  }

  @Test func sectionsKeepTheirOrder() {
    let order = SettingsSection.allCases
    let sections = SettingsSchema.entries.map { order.firstIndex(of: $0.section)! }
    #expect(sections == sections.sorted())
    #expect(
      order.map(\.title) == [
        "General", "Windows", "Dragging", "Tabs", "Gestures", "Calls", "Appearance", "Menu Bar", "Apps", "Scripting",
      ])
  }
}

/// What `set` accepts and what it says when it does not.
@Suite struct SettingValidationTests {
  let gap = try! SettingsSchema.entry(named: "gap")
  let tabs = try! SettingsSchema.entry(named: "tabsEnabled")
  let modifier = try! SettingsSchema.entry(named: "frameRectangleModifier")
  /// No setting is a choice yet, so this borrows a text property.
  let choice = SettingEntry.choice(
    "tileClick", \.frameRectangleModifier, ["single": "One click", "double": "Double-click"], "Open tiles with",
    "How.")

  @Test func numbersInRangeAreTaken() throws {
    #expect(try gap.parse("16") == .number(16))
    #expect(try gap.parse("0") == .number(0))
    #expect(try gap.parse("100") == .number(100))
    #expect(try gap.parse("7.5") == .number(7.5))
    #expect(try gap.parse("1e1") == .number(10))
  }

  @Test func aNumbersBoundsCanBeAskedFor() {
    #expect(SettingsSchema.range(of: "gap") == 0...100)
    #expect(SettingsSchema.range(of: "GAP") == 0...100)
    #expect(SettingsSchema.range(of: "focusRing") == nil && SettingsSchema.range(of: "nonsense") == nil)
  }

  @Test func numbersOutsideTheRangeAreRefusedWithTheRange() {
    #expect(refusal { _ = try gap.parse("-1") } == "`gap` must be from 0 to 100 pt, got -1")
    #expect(refusal { _ = try gap.parse("100.5") } == "`gap` must be from 0 to 100 pt, got 100.5")
    #expect(refusal { _ = try gap.parse("1e300") } == "`gap` must be from 0 to 100 pt, got 1e+300")
    var settings = Settings()
    #expect(refusal { try gap.set(.number(500), in: &settings) } == "`gap` must be from 0 to 100 pt, got 500")
    #expect(settings == Settings())
  }

  @Test(arguments: ["nan", "inf", "-inf", "infinity", "1e999", "-1e999"])
  func numbersThatAreNotFiniteAreRefused(text: String) throws {
    let reason = try #require(refusal { _ = try gap.parse(text) })
    #expect(reason.hasPrefix("`gap` needs a finite number from 0 to 100 pt, got "))
  }

  @Test(arguments: ["banana", "", "12pt", "12 pt", "1,5", "true"])
  func textThatIsNotANumberIsRefused(text: String) {
    #expect(refusal { _ = try gap.parse(text) } == "`gap` needs a number from 0 to 100 pt, got `\(text)`")
  }

  @Test func switchesTakeTheUsualWords() throws {
    for word in ["true", "on", "yes", "1", "TRUE", "On"] {
      #expect(try tabs.parse(word) == .bool(true), "\(word)")
    }
    for word in ["false", "off", "no", "0", "False", "OFF"] {
      #expect(try tabs.parse(word) == .bool(false), "\(word)")
    }
    #expect(
      refusal { _ = try tabs.parse("maybe") }
        == "`tabsEnabled` is true or false (or on/off, yes/no, 1/0), got `maybe`")
    #expect(refusal { _ = try tabs.parse("2") } != nil)
  }

  @Test func unknownChoicesListTheValidOnes() throws {
    #expect(try choice.parse("double") == .text("double"))
    #expect(try choice.parse("Single") == .text("single"))  // stored as the schema spells it
    #expect(refusal { _ = try choice.parse("triple") } == "`tileClick` must be single or double, got `triple`")
    #expect(choice.accepts == "single or double")
    guard case .choice(let choices) = choice.kind else { return #expect(Bool(false), "not a choice") }
    #expect(choices.map(\.value) == ["single", "double"])  // in the order they were given
    #expect(choices.map(\.label) == ["One click", "Double-click"])
  }

  @Test func aChoiceInTheFileIsStoredAsTheSchemaSpellsItOrGoesBackToTheDefault() {
    var settings = Settings()
    settings.frameRectangleModifier = "DOUBLE"
    #expect(choice.sanitize(&settings) == nil)
    #expect(settings.frameRectangleModifier == "double")
    settings.frameRectangleModifier = "triple"
    #expect(
      choice.sanitize(&settings) == "tileClick: `triple` is not single or double; using the default, ctrl+opt")
    #expect(settings.frameRectangleModifier == Settings().frameRectangleModifier)
  }

  @Test func textIsCheckedAndStoredInItsCanonicalSpelling() throws {
    #expect(try modifier.parse("Command + Shift") == .text("shift+cmd"))
    #expect(try modifier.parse("⌃⌥") == .text("ctrl+opt"))
    #expect(try modifier.parse("off") == .text("none"))
    #expect(
      refusal { _ = try modifier.parse("banana") }
        == "`frameRectangleModifier` needs modifier keys joined by +, such as shift+cmd, or none, got `banana`")
  }

  @Test func listsSendTheUserToTheirOwnCommands() throws {
    let rules = try SettingsSchema.entry(named: "rules")
    let reason = try #require(refusal { _ = try rules.parse("[]") })
    #expect(reason.contains("`rule add`") && reason.contains("`set` cannot write"))
  }

  @Test func aValueOfAnotherKindIsRefused() {
    var settings = Settings()
    #expect(refusal { try gap.set(.bool(true), in: &settings) } != nil)
    #expect(refusal { try tabs.set(.number(1), in: &settings) } != nil)
    #expect(refusal { try modifier.set(.number(1), in: &settings) } != nil)
    #expect(settings == Settings())
  }

  @Test func longNonsenseIsCutShortInMessages() throws {
    let reason = try #require(refusal { _ = try gap.parse(String(repeating: "x", count: 10_000)) })
    #expect(reason.count < 120)
  }

  @Test func valuesPrintTheWayTheyAreTyped() {
    #expect(SettingValue.number(12).text == "12")
    #expect(SettingValue.number(0.3).text == "0.3")
    #expect(SettingValue.number(-2).text == "-2")
    #expect(SettingValue.bool(true).text == "true")
    #expect(SettingValue.text("shift+cmd").text == "shift+cmd")
    // Never a crash, whatever the number.
    #expect(SettingValue.number(1e300).text == "1e+300")
    #expect(SettingValue.number(.infinity).text == "inf")
    #expect(SettingValue.number(.nan).text == "nan")
    #expect(SettingValue.list(json: "[]", count: 0).summary == "none")
    #expect(SettingValue.list(json: "[1]", count: 1).summary == "1 entry")
    #expect(SettingValue.list(json: "[1,2]", count: 2).summary == "2 entries")
  }
}

/// Finding a setting by what the user typed.
@Suite struct SettingNameTests {
  @Test func keysIgnoreCase() throws {
    #expect(try SettingsSchema.entry(named: "GAP").key == "gap")
    #expect(try SettingsSchema.entry(named: "minimumusablewidth").key == "minimumUsableWidth")
    #expect(try SettingsSchema.entry(named: "excludedBundleIds").key == "excludedBundleIDs")
  }

  @Test func theBeginningOfAKeyIsNotEnough() {
    // `pinch` could only mean one key today; a later version may add another.
    #expect(
      refusal { _ = try SettingsSchema.entry(named: "pinch") }
        == "unknown setting `pinch`; did you mean `pinchThreshold` or `gesturesEnabled`?")  // "Pinch to zoom"
    #expect(refusal { _ = try SettingsSchema.entry(named: "ga") } != nil)
  }

  @Test func typosGetASuggestion() {
    #expect(SettingsSchema.suggestions(for: "gpa") == ["gap"])
    #expect(SettingsSchema.suggestions(for: "gaps") == ["gap", "gapHandles"])
    #expect(SettingsSchema.suggestions(for: "minimumUsableWidht").first == "minimumUsableWidth")
    #expect(SettingsSchema.suggestions(for: "hotkeysenabeld") == ["hotkeysEnabled"])
    #expect(SettingsSchema.suggestions(for: "windowFraction") == ["windowEdgeFraction"])
    #expect(SettingsSchema.suggestions(for: "usable") == ["minimumUsableHeight", "minimumUsableWidth"])
    #expect(
      refusal { _ = try SettingsSchema.entry(named: "gpa") } == "unknown setting `gpa`; did you mean `gap`?")
    #expect(
      refusal { _ = try SettingsSchema.entry(named: "usable") }
        == "unknown setting `usable`; did you mean `minimumUsableHeight` or `minimumUsableWidth`?")
  }

  @Test func aWordFromTheLabelFindsTheKey() {
    // What people see is "Use keyboard shortcuts", not `hotkeysEnabled`.
    #expect(SettingsSchema.suggestions(for: "shortcuts").contains("hotkeysEnabled"))
    #expect(SettingsSchema.suggestions(for: "don't arrange").contains("excludedBundleIDs"))
  }

  @Test func nothingIsSuggestedForSomethingElseEntirely() {
    #expect(SettingsSchema.suggestions(for: "volume").isEmpty)
    #expect(SettingsSchema.suggestions(for: "").isEmpty)
    #expect(
      refusal { _ = try SettingsSchema.entry(named: "volume") }
        == "unknown setting `volume`; `settings` lists them all")
    // A name of any length (it can come from a URL) is answered at once, and not echoed in full.
    let long = String(repeating: "gap", count: 100_000)
    #expect(SettingsSchema.suggestions(for: long).isEmpty)
    #expect((refusal { _ = try SettingsSchema.entry(named: long) } ?? "").count < 120)
  }
}

/// settings.json written by hand: nothing in it may crash Arbor, wedge it, or cost the rest of the file.
@Suite struct HandEditedSettingsTests {
  @Test func numbersOutsideTheirRangeMoveToTheNearestEnd() throws {
    let settings = try decode(
      #"{"gap": -500, "minimumUsableWidth": 1e9, "windowEdgeFraction": 7, "arrangeDesktopWeight": -3, "pinchThreshold": 0}"#
    )
    #expect(settings.gap == 0)
    #expect(settings.minimumUsableWidth == 1000)
    #expect(settings.windowEdgeFraction == 0.5)
    #expect(settings.arrangeDesktopWeight == 0.1)
    #expect(settings.pinchThreshold == 0.05)
    // One line for each, in the order of the schema.
    #expect(
      settings.valueProblems == [
        "gap: -500 is outside 0 to 100 pt; using 0",
        "minimumUsableWidth: 1000000000 is outside 0 to 1000 pt; using 1000",
        "arrangeDesktopWeight: -3 is outside 0.1 to 3; using 0.1",
        "windowEdgeFraction: 7 is outside 0 to 0.5; using 0.5",
        "pinchThreshold: 0 is outside 0.05 to 2; using 0.05",
      ])
  }

  @Test func valuesInRangeAreLeftExactlyAsWritten() throws {
    let settings = try decode(
      #"{"gap": 0, "windowEdgeFraction": 0.5, "frameRectangleModifier": "Command + Shift"}"#)
    #expect(settings.gap == 0 && settings.windowEdgeFraction == 0.5)
    #expect(settings.frameRectangleModifier == "Command + Shift")
    #expect(settings.valueProblems.isEmpty)
    #expect(try decode("{}") == Settings())
  }

  @Test(arguments: ["1e999", "-1e999", "1e308", "-1e308"])
  func hugeNumbersNeverGetThroughAndCostOnlyTheirKeys(number: String) throws {
    // A number too large for a Double is an error of Foundation's own, not a `DecodingError`, where it is read.
    let settings = try decode("{\"gap\": \(number), \"pinchThreshold\": \(number), \"screenEdgeBand\": 20}")
    #expect((0...100).contains(settings.gap))
    #expect((0.05...2).contains(settings.pinchThreshold))
    #expect(settings.screenEdgeBand == 20)
    #expect(settings.valueProblems.count == 2)
  }

  @Test func aNumberTooLargeForADoubleCostsOnlyItsOwnKey() throws {
    let settings = try decode(#"{"gap": 1e999, "pinchThreshold": 0.4, "tabsEnabled": true}"#)
    #expect(settings.gap == Settings().gap)
    #expect(settings.pinchThreshold == 0.4 && settings.tabsEnabled)
    #expect(settings.valueProblems.count == 1 && settings.valueProblems[0].hasPrefix("gap: "))
  }

  @Test func sanitizingCatchesWhatNoFileCanSay() {
    var settings = Settings()
    settings.gap = .nan
    settings.pinchThreshold = .infinity
    settings.minimumUsableHeight = -.infinity
    let problems = SettingsSchema.sanitize(&settings)
    #expect(settings == Settings())
    #expect(
      problems == [
        "gap: `nan` is not 0 to 100 pt; using the default, 12",
        "minimumUsableHeight: `-inf` is not 0 to 1000 pt; using the default, 160",
        "pinchThreshold: `inf` is not 0.05 to 2; using the default, 0.25",
      ])
    #expect(SettingsSchema.sanitize(&settings).isEmpty)
  }

  @Test func textThatMeansNothingGoesBackToTheDefault() throws {
    let settings = try decode(#"{"frameRectangleModifier": "banana", "gap": 20}"#)
    #expect(settings.frameRectangleModifier == "ctrl+opt")
    #expect(settings.gap == 20)
    #expect(
      settings.valueProblems == [
        "frameRectangleModifier: `banana` is not modifier keys joined by +, such as shift+cmd, or none; "
          + "using the default, ctrl+opt"
      ])
  }

  @Test func aValueOfTheWrongTypeCostsOnlyItsOwnKey() throws {
    let settings = try decode(
      #"""
      {"gap": "12", "tabsEnabled": 1, "excludedBundleIDs": "com.apple.Music", "bindings": 3, "frameRectangleModifier": 4,
       "hotkeysEnabled": "no", "pinchThreshold": 0.4, "minimumUsableWidth": 300,
       "rules": [{"app": "com.apple.Terminal", "action": "dock right"}]}
      """#)
    #expect(settings.pinchThreshold == 0.4 && settings.minimumUsableWidth == 300)
    #expect(settings.rules == [AppRule(app: "com.apple.Terminal", action: .dock(.right))])
    var rest = settings
    rest.pinchThreshold = Settings().pinchThreshold
    rest.minimumUsableWidth = Settings().minimumUsableWidth
    rest.rules = []
    #expect(try canonical(json(rest)) == canonical(json(Settings())))
    #expect(
      Set(settings.valueProblems) == [
        "gap: not a number; using the default, 12",
        "tabsEnabled: not true or false; using the default, false",
        "excludedBundleIDs: not a list of bundle ids; using the default, none",
        "bindings: not an object that maps shortcuts to commands; using the default, none",
        "frameRectangleModifier: not text; using the default, ctrl+opt",
        "hotkeysEnabled: not true or false; using the default, true",
      ])
  }

  @Test func nullMeansTheDefault() throws {
    #expect(try decode(#"{"gap": null, "tabsEnabled": null, "rules": null, "bindings": null}"#) == Settings())
  }

  @Test func aFileThatIsNotAnObjectIsStillAnError() {
    #expect(throws: DecodingError.self) { try decode("[1, 2]") }
    #expect(throws: DecodingError.self) { try decode("12") }
    #expect(throws: DecodingError.self) { try decode(#"{"gap": }"#) }
  }

  @Test func problemsAreNotSaved() throws {
    let settings = try decode(#"{"gap": -500}"#)
    #expect(!settings.valueProblems.isEmpty)
    let again = try JSONDecoder().decode(Settings.self, from: JSONEncoder().encode(settings))
    #expect(again.gap == 0 && again.valueProblems.isEmpty)
  }

  @Test func aGapTooLargeForTheSpaceLeavesFiniteFrames() {
    // Within the schema's range and still too much for a small display or many columns.
    var tree = LayoutTree()
    for number in 1...9 { tree.dock(WindowID(UInt32(number)), beside: tree.desktop, edge: .left) }
    for frame in [
      CGRect(x: 0, y: 0, width: 150, height: 90), CGRect(x: 0, y: 25, width: 1440, height: 875), .zero,
    ] {
      let layout = LayoutEngine.layout(
        tree, camera: tree.root, in: frame, options: LayoutOptions(gap: 100), isPresent: { _ in true })
      let rectangles =
        Array(layout.nodeFrames.values) + Array(layout.windowFrames.values) + layout.tiles.map(\.frame)
        + layout.tiles.flatMap(\.miniature.values) + layout.seams.map(\.frame)
      #expect(!rectangles.isEmpty)
      for rectangle in rectangles {
        #expect(!rectangle.isNull && !rectangle.isInfinite, "\(rectangle) in \(frame)")
        #expect(
          rectangle.minX.isFinite && rectangle.minY.isFinite && rectangle.width >= 0 && rectangle.height >= 0)
      }
      // What `arborctl ascii` does with them used to crash on the null rectangle.
      _ = AsciiRenderer.render(layout, tree: tree)
    }
  }
}

/// `settings` and docs/SETTINGS.md.
@Suite struct SettingsReportTests {
  @Test func theReportGroupsBySectionAndMarksWhatChanged() throws {
    var settings = Settings()
    settings.gap = 30
    settings.rules = [AppRule(app: "com.apple.mail", action: .float)]
    let lines = SettingsSchema.report(settings).components(separatedBy: "\n")
    #expect(lines.contains("* gap = 30  (0 to 100 pt; default 12)"))
    #expect(lines.contains("  minimumUsableWidth = 240  (0 to 1000 pt; default 240)"))
    #expect(lines.contains("* rules = 1 entry  (a list of rules; default none)"))
    #expect(lines.contains("  tabsEnabled = false  (true or false; default false)"))
    #expect(lines.filter { $0.hasPrefix("*") }.count == 2)
    // Every setting is there, under its section, followed by its help.
    for entry in SettingsSchema.entries {
      let index = try #require(
        lines.firstIndex { $0.dropFirst(2).hasPrefix("\(entry.key) = ") }, "\(entry.key)")
      #expect(lines[index + 1].hasPrefix("      \(entry.help)"))
      let heading = lines[..<index].last { SettingsSection(rawValue: $0) != nil }
      #expect(heading == entry.section.title, "\(entry.key)")
    }
    // Sections nobody has filled yet are left out.
    for section in SettingsSection.allCases where SettingsSchema.entries(in: section).isEmpty {
      #expect(!lines.contains(section.title))
    }
    #expect(!lines.contains { $0.contains("could not use") })
  }

  @Test func theReportShowsWhatWasWrongWithTheFile() throws {
    let report = SettingsSchema.report(try decode(#"{"gap": -500}"#))
    #expect(
      report.contains("Values in settings.json that Arbor could not use as written:\n  gap: -500 is outside"))
  }

  /// docs/SETTINGS.md is generated. When it is out of date this test rewrites it and fails once, so:
  /// run the tests, look at the change, commit it.
  @Test func theSettingsDocumentIsUpToDate() throws {
    let file = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
      .deletingLastPathComponent().appendingPathComponent("docs/SETTINGS.md")
    let expected = SettingsSchema.markdown()
    let current = try? String(contentsOf: file, encoding: .utf8)
    if current != expected { try expected.write(to: file, atomically: true, encoding: .utf8) }
    #expect(
      current == expected, "docs/SETTINGS.md was out of date and has been rewritten from the schema; commit it")
  }

  @Test func theJSONFormSaysTheSameForScripts() throws {
    var settings = Settings()
    settings.gap = 30
    settings.rules = [AppRule(app: "com.apple.mail", title: "a/b", action: .float)]
    let parsed = try JSONSerialization.jsonObject(with: Data(SettingsSchema.json(settings).utf8))
    let objects = try #require(parsed as? [[String: Any]])
    #expect(objects.map { $0["key"] as? String } == SettingsSchema.entries.map(\.key))
    let gap = try #require(objects.first { $0["key"] as? String == "gap" })
    #expect(gap["value"] as? Double == 30 && gap["default"] as? Double == 12 && gap["changed"] as? Bool == true)
    #expect(gap["min"] as? Double == 0 && gap["max"] as? Double == 100 && gap["step"] as? Double == 1)
    #expect(gap["unit"] as? String == "pt" && gap["kind"] as? String == "number" && gap["level"] as? String == "normal")
    #expect(gap["section"] as? String == "Windows" && gap["label"] as? String == "Gap")
    let rules = try #require(objects.first { $0["key"] as? String == "rules" })
    #expect((rules["value"] as? [[String: String]])?.first?["title"] == "a/b")
    #expect((rules["default"] as? [Any])?.isEmpty == true && rules["kind"] as? String == "list")
    let ring = try #require(objects.first { $0["key"] as? String == "focusRing" })
    #expect(ring["value"] as? Bool == true && ring["changed"] as? Bool == false && ring["kind"] as? String == "switch")
    let colour = try #require(objects.first { $0["key"] as? String == "focusRingColour" })
    #expect(colour["example"] as? String == "#FF8000" && colour["kind"] as? String == "text")
  }

  @Test func theDocumentHasARowForEverySetting() {
    let markdown = SettingsSchema.markdown()
    for entry in SettingsSchema.entries {
      #expect(markdown.contains("\n| `\(entry.key)` | `\(entry.defaultValue.text)` | "), "\(entry.key)")
    }
    #expect(markdown.contains("| `gap` | `12` | 0 to 100 pt | **Gap.** Space between docked windows"))
    #expect(markdown.contains("*Advanced.* |"))
    #expect(markdown.hasSuffix("\n") && !markdown.hasSuffix("\n\n"))
  }
}
