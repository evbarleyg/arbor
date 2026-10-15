import ArborCore
import CoreGraphics
import Foundation
import Testing

private let laptop = DisplayTraits(
  id: DisplayID("9B2F6C1E-4A7D-4F03-8E15-6D0A3C5B7E21"), name: "Built-in Retina Display", isMain: true, isBuiltIn: true,
  size: CGSize(width: 1728, height: 1117))
private let studio = DisplayTraits(
  id: DisplayID("4C7A5B0E-9F2D-4B41-8E55-1A2B3C4D5E6F"), name: "Studio Display", isMain: false, isBuiltIn: false,
  size: CGSize(width: 2560, height: 1440))

private func decode(_ json: String) throws -> Settings {
  try JSONDecoder().decode(Settings.self, from: Data(json.utf8))
}

/// Per-display options (docs/features/F25-per-display-options.md): what `match` means.
@Suite struct DisplayMatchTests {
  @Test func theWordsMainAndBuiltin() throws {
    #expect(try DisplayMatch(text: "main") == .main)
    #expect(try DisplayMatch(text: " Main ") == .main)
    #expect(try DisplayMatch(text: "builtin") == .builtIn)
    #expect(try DisplayMatch(text: "Built-In") == .builtIn)
    #expect(DisplayMatch.main.matches(laptop) && !DisplayMatch.main.matches(studio))
    #expect(DisplayMatch.builtIn.matches(laptop) && !DisplayMatch.builtIn.matches(studio))
  }

  @Test func widthsAreComparedInPoints() throws {
    #expect(try DisplayMatch(text: ">=2500") == .width(.atLeast, 2500))
    #expect(try DisplayMatch(text: ">= 2500") == .width(.atLeast, 2500))
    #expect(try DisplayMatch(text: "<1800.5") == .width(.below, 1800.5))
    #expect(try DisplayMatch(text: "<=1728") == .width(.atMost, 1728))
    #expect(try DisplayMatch(text: ">1728") == .width(.above, 1728))
    for (text, onLaptop, onStudio) in [
      (">=2500", false, true), (">=2560", false, true), (">2560", false, false), ("<2000", true, false),
      ("<=1728", true, false), ("<1728", false, false), (">=0", true, true),
    ] {
      let match = try DisplayMatch(text: text)
      #expect(match.matches(laptop) == onLaptop, "\(text) on the laptop")
      #expect(match.matches(studio) == onStudio, "\(text) on the Studio Display")
    }
  }

  @Test func anythingElseIsAUUIDOrPartOfAName() throws {
    #expect(try DisplayMatch(text: "Studio Display") == .named("Studio Display"))
    for text in ["Studio Display", "studio", "STUDIO DISPLAY", "4C7A5B0E-9F2D-4B41-8E55-1A2B3C4D5E6F", "4c7a5b0e-9f2d-4b41-8e55-1a2b3c4d5e6f"] {
      let match = try DisplayMatch(text: text)
      #expect(match.matches(studio), "\(text)")
      #expect(!match.matches(laptop), "\(text)")
    }
    #expect(try DisplayMatch(text: "display").matches(laptop), "both names contain it")
    #expect(try DisplayMatch(text: "display").matches(studio))
    #expect(try !DisplayMatch(text: "4C7A5B0E").matches(studio), "an id is matched whole: part of one is not a name")
    let nameless = DisplayTraits(id: DisplayID("x"), name: "", isMain: false, isBuiltIn: false, size: .zero)
    #expect(try !DisplayMatch(text: "Studio").matches(nameless))
  }

  @Test func textRoundTrips() throws {
    for text in ["main", "builtin", ">=2500", "<=1728", ">1000", "<1800.5", "Studio Display", "LG UltraFine (2)"] {
      #expect(try DisplayMatch(text: text).text == text)
      #expect(try DisplayMatch(text: DisplayMatch(text: text).text) == DisplayMatch(text: text))
    }
    #expect(try DisplayMatch(text: ">= 2500").text == ">=2500")
    #expect(try DisplayMatch(text: ">=1e300").text == ">=1e+300", "a width no Int could hold still prints")
  }

  /// `@2` and `2` are how commands name a display (F54). In a file they would mean another display after the next rearrangement.
  @Test(arguments: ["2", "@2", " 1 ", "@10"])
  func aDisplaysNumberIsRefusedInWords(text: String) throws {
    let error = #expect(throws: DisplayMatch.ParseError.self) { try DisplayMatch(text: text) }
    #expect(error?.description.contains("is a display's number, and numbers change") == true)
    let settings = try decode(#"{"displays": [{"match": "\#(text)", "gap": 4}, {"match": "main", "gap": 5}]}"#)
    #expect(settings.displays == [DisplayOptions(match: .main, gap: 5)])
    #expect(settings.skippedDisplays.count == 1)
    // A name may have digits in it.
    #expect(try DisplayMatch(text: "LG 27") == .named("LG 27"))
    #expect(try DisplayMatch(text: "@home") == .named("@home"))
  }

  @Test func whatCannotBeAMatchSaysWhy() {
    for text in ["", "   ", ">=", ">=wide", "<-5", ">=inf", ">=nan", "> = 5"] {
      #expect(throws: DisplayMatch.ParseError.self, "\(text)") { try DisplayMatch(text: text) }
    }
  }
}

@Suite struct DisplayOptionsTests {
  @Test func theFirstMatchingEntryThatSetsAKeyGivesIt() throws {
    let settings = try decode(
      """
      {"gap": 10, "screenEdgeBand": 20,
       "displays": [
         {"match": "builtin", "gap": 6},
         {"match": ">=2500", "gap": 16, "minimumUsableWidth": 300, "minimumUsableHeight": 200},
         {"match": "main", "gap": 99}
       ]}
      """)
    #expect(settings.skippedDisplays.isEmpty)
    #expect(settings.displays.count == 3)

    let onLaptop = settings.applying(to: laptop)
    #expect(onLaptop.gap == 6, "builtin comes before main")
    #expect(onLaptop.minimumUsableWidth == Settings().minimumUsableWidth)
    #expect(onLaptop.screenEdgeBand == 20, "a key the entry leaves out stays as it is everywhere")
    #expect(onLaptop.layoutOptions == LayoutOptions(gap: 6, minimumUsableSize: CGSize(width: 240, height: 160), overlaps: true))

    let onStudio = settings.applying(to: studio)
    #expect(onStudio.layoutOptions == LayoutOptions(gap: 16, minimumUsableSize: CGSize(width: 300, height: 200), overlaps: true))
    #expect(onStudio.dropOptions == settings.dropOptions)

    var other = studio
    other.size.width = 1920
    #expect(settings.applying(to: other) == settings, "no entry matches: the general settings")
  }

  /// The example of the README and the spec. A Studio Display is 2560 points wide, so two entries match it.
  @Test func aParticularEntryGoesBeforeAGeneralOneAndNeedNotRepeatIt() throws {
    let settings = try decode(
      """
      {"displays": [
         {"match": "builtin", "gap": 8},
         {"match": "Studio Display", "screenEdgeBand": 24},
         {"match": ">=2500", "gap": 16, "minimumUsableWidth": 300, "minimumUsableHeight": 200, "screenEdgeBand": 40}
       ]}
      """)
    let onStudio = settings.applying(to: studio)
    #expect(onStudio.screenEdgeBand == 24, "from the first entry that matches and sets it")
    #expect(onStudio.gap == 16, "which says nothing about the gap, so the next one that matches does")
    #expect((onStudio.minimumUsableWidth, onStudio.minimumUsableHeight) == (300, 200))
    #expect(
      DisplayOptions.given(by: settings.displays, to: studio) == [
        DisplayOptions.Given(key: "gap", value: 16, match: .width(.atLeast, 2500)),
        DisplayOptions.Given(key: "minimumUsableWidth", value: 300, match: .width(.atLeast, 2500)),
        DisplayOptions.Given(key: "minimumUsableHeight", value: 200, match: .width(.atLeast, 2500)),
        DisplayOptions.Given(key: "screenEdgeBand", value: 24, match: .named("Studio Display")),
      ])
    #expect(DisplayOptions.given(by: settings.displays, to: laptop) == [DisplayOptions.Given(key: "gap", value: 8, match: .builtIn)])
    #expect(DisplayOptions.given(by: [], to: laptop).isEmpty)
  }

  @Test func theScreenEdgeBandCanDiffer() throws {
    let settings = try decode(#"{"displays": [{"match": "Studio", "screenEdgeBand": 32}]}"#)
    #expect(settings.applying(to: studio).dropOptions.screenEdgeBand == 32)
    #expect(settings.applying(to: laptop).dropOptions.screenEdgeBand == 12)
    #expect(settings.applying(to: studio).dropOptions.windowEdgeFraction == settings.dropOptions.windowEdgeFraction)
  }

  @Test func unknownKeysAreIgnored() throws {
    let settings = try decode(#"{"displays": [{"match": "main", "gap": 4, "wallpaper": "blue", "tabStripHeight": 30}]}"#)
    #expect(settings.displays == [DisplayOptions(match: .main, gap: 4)])
    #expect(settings.skippedDisplays.isEmpty)
  }

  @Test func badEntriesAreSkippedWithAReasonAndTheOthersStillApply() throws {
    let settings = try decode(
      """
      {"gap": 10, "displays": [
         {"gap": 5},
         {"match": ">=wide", "gap": 5},
         {"match": "main", "gap": -1},
         {"match": "main", "gap": 101},
         {"match": "main", "minimumUsableWidth": "wide"},
         {"match": 5},
         "main",
         {"match": "", "gap": 5},
         {"match": "main", "screenEdgeBand": 1e300},
         {"match": "main", "gap": 7}
       ]}
      """)
    #expect(settings.gap == 10, "the rest of the file still loads")
    #expect(settings.displays == [DisplayOptions(match: .main, gap: 7)])
    #expect(settings.skippedDisplays.count == 9)
    let expected = [
      "entry 1: `match` is missing",
      "entry 2 (>=wide): `>=wide` compares the display's width with something that is not a number; expected e.g. >=2500",
      "entry 3 (main): `gap` must be between 0 and 100",
      "entry 4 (main): `gap` must be between 0 and 100",
      "entry 5 (main): `minimumUsableWidth` must be a number",
      "entry 6: `match` must be text",
      #"entry 7: expected an object such as {"match": "builtin", "gap": 8}"#,
    ]
    #expect(Array(settings.skippedDisplays.prefix(7)) == expected)
    #expect(settings.skippedDisplays[7].hasPrefix("entry 8 (): `match` is empty"))
    #expect(settings.skippedDisplays[8] == "entry 9 (main): `screenEdgeBand` must be between 0 and 100")
    #expect(settings.applying(to: laptop).gap == 7)
  }

  @Test func aDisplaysKeyThatIsNotAListIsReportedAndTheFileStillLoads() throws {
    let settings = try decode(#"{"gap": 20, "displays": {"match": "main"}}"#)
    #expect(settings.gap == 20)
    #expect(settings.displays.isEmpty)
    #expect(settings.skippedDisplays == ["`displays` must be a list of entries; none were loaded"])
  }

  @Test func oldSettingsFilesHaveNoDisplayOptions() throws {
    let settings = try decode(#"{"gap": 20}"#)
    #expect(settings.displays.isEmpty && settings.skippedDisplays.isEmpty)
    #expect(settings.applying(to: laptop) == settings)
  }

  @Test func displayOptionsSurviveBeingSavedAndLoaded() throws {
    var settings = Settings()
    settings.displays = [
      DisplayOptions(match: .builtIn, gap: 8), DisplayOptions(match: .width(.atLeast, 2500), gap: 16, minimumUsableWidth: 300),
      DisplayOptions(match: .named("Studio Display"), screenEdgeBand: 24),
    ]
    let data = try JSONEncoder().encode(settings)
    #expect(try JSONDecoder().decode(Settings.self, from: data) == settings)
    let text = String(decoding: data, as: UTF8.self)
    #expect(text.contains(#""match":">=2500""#), "as the text a person would write")
    #expect(!text.contains("skippedDisplays"))
    #expect(!text.contains("null"), "keys an entry does not set are left out")
  }

  @Test func aCommandThatSavesAnotherSettingLeavesTheListAsItWasWritten() throws {
    let text = """
      {
        "displays": [
          { "match": "builtin",  "gap": 8.0 },
          { "match": ">=wide", "gap": 16 }
        ],
        "excludedBundleIDs": ["com.apple.Music"]
      }
      """
    let loaded = try Settings.read(text)
    #expect(loaded.displays.count == 1 && loaded.skippedDisplays.count == 1)
    var changed = loaded
    changed.excludedBundleIDs.append("com.apple.Notes")
    let saved = try Settings.rewrite(text, from: loaded, to: changed)
    #expect(
      saved == text.replacingOccurrences(of: #""com.apple.Music""#, with: #""com.apple.Music", "com.apple.Notes""#),
      "the entry Arbor could not read too")
  }

  @Test func anEntrySaysWhichKeysItSets() {
    #expect(DisplayOptions(match: .main).keysSet.isEmpty)
    #expect(
      DisplayOptions(match: .main, gap: 1, minimumUsableWidth: 2, minimumUsableHeight: 3, screenEdgeBand: 4).keysSet
        == ["gap", "minimumUsableWidth", "minimumUsableHeight", "screenEdgeBand"])
  }

  @Test func displaysIsAQueryWithoutArguments() throws {
    #expect(try Command.parse("displays") == .displays)
    #expect(Command.displays.text == "displays")
    #expect(Command.displays.isQuery)
    #expect(!Command.displays.isAllowedFromURL)
    #expect(throws: Command.ParseError.self) { try Command.parse("displays main") }
  }
}
