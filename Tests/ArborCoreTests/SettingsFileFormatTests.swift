import Foundation
import Testing

@testable import ArborCore

/// `settings.json` holds only what differs from the defaults, and files from before that are put right once (collab/QUESTIONS.md, Q27).
@Suite struct SettingsFileFormatTests {
  /// What the first launch of the build of 2026-10-15 wrote, byte for byte: every default of its day.
  static let wholeFile = #"""
    {
      "allowAllURLCommands" : false,
      "animationDuration" : 0.46,
      "appColourAmount" : 0.25,
      "appColours" : true,
      "arrangeDesktopWeight" : 0.5,
      "autoDockMinimumHeight" : 300,
      "autoDockMinimumWidth" : 400,
      "automaticUpdateChecks" : false,
      "bindings" : {

      },
      "blurBehindArranged" : 0,
      "continuousZoom" : false,
      "desktopEdge" : 0.05,
      "dimBehindArranged" : 0.25,
      "displays" : [

      ],
      "dropDwell" : 0.15,
      "excludedBundleIDs" : [

      ],
      "focusRing" : true,
      "focusRingColour" : "accent",
      "focusRingRadius" : 0,
      "focusRingWidth" : 3,
      "frameRectangleModifier" : "ctrl+opt",
      "frameRectangleOnDesktop" : true,
      "gap" : 12,
      "gapHandles" : "shown",
      "gesturesEnabled" : true,
      "guardDesktopClicks" : false,
      "historyButtons" : true,
      "holdStillFor" : [

      ],
      "holdStillWhileCameraIsOn" : false,
      "holdStillWhileMicrophoneIsOn" : false,
      "hotkeysEnabled" : true,
      "keepPushed" : true,
      "makeRoom" : true,
      "menuBarControls" : true,
      "menuBarFill" : 0.25,
      "messages" : "helpful",
      "minimapDuration" : 0,
      "minimumUsableHeight" : 160,
      "minimumUsableWidth" : 240,
      "newWindows" : "float",
      "newWindowsWhileFramed" : "guest",
      "passThroughApps" : [

      ],
      "pauseForApps" : [

      ],
      "peek" : true,
      "pinchThreshold" : 0.25,
      "pointerGestures" : false,
      "previewDrags" : true,
      "reflowWhileDragging" : false,
      "resizeStep" : 40,
      "ruleTitleWait" : 2,
      "rules" : [

      ],
      "screenEdgeBand" : 12,
      "scrollOnDesktopZooms" : false,
      "scrollZoom" : true,
      "scrollZoomThreshold" : 40,
      "shareRemovedSpace" : true,
      "shortcutsFollowLayout" : true,
      "shrinkOutOfView" : false,
      "soleFloatTakesDesktop" : false,
      "stepInToward" : "auto",
      "summonStays" : false,
      "tabsEnabled" : false,
      "tileFade" : 0.2,
      "tileRetryMinutes" : 10,
      "tileStyle" : "icon",
      "tintBehindArranged" : 0,
      "windowEdgeFraction" : 0.3,
      "windowPictures" : false
    }
    """# + "\n"

  // MARK: A new file

  @Test func afterAFirstLaunchTheFileHoldsTheMarkAndNothingElse() throws {
    #expect(try Settings().fileText == "{\n  \"format\": 2\n}\n")
    #expect(try Settings.read(try Settings().fileText) == Settings())
  }

  @Test func aNewFileHoldsOnlyWhatDiffers() throws {
    var settings = Settings()
    settings.gap = 20
    settings.peek.toggle()
    settings.bindings = ["ctrl+opt+h": "dock left"]
    settings.rules = [AppRule(app: "com.apple.Terminal", action: .dock(.right))]
    let text = try settings.fileText
    #expect(try JSONText(text).keys(at: []) == ["format", "bindings", "gap", "peek", "rules"])
    #expect(try Settings.read(text) == settings)
    #expect(try Settings.upgradedFile(text) == nil, "it has the mark")
  }

  // MARK: Commands

  @Test func aChangeWritesOneKey() throws {
    var changed = Settings()
    changed.gap = 16
    #expect(try Settings.rewrite("{\n  \"format\": 2\n}\n", from: Settings(), to: changed) == "{\n  \"format\": 2,\n  \"gap\": 16\n}\n")
  }

  @Test func aValueThatGoesBackToTheDefaultLeavesTheFile() throws {
    var changed = Settings()
    (changed.gap, changed.peek) = (16, !changed.peek)
    var back = changed
    back.gap = Settings().gap
    let text = #"{"format": 2, "mine": [1, 2], "gap": 16, "peek": \#(changed.peek)}"#
    #expect(try Settings.rewrite(text, from: changed, to: back) == #"{"format": 2, "mine": [1, 2], "peek": \#(changed.peek)}"#)
    #expect(try Settings.rewrite(text, from: changed, to: Settings()) == #"{"format": 2, "mine": [1, 2]}"#)
  }

  @Test func aValueArborCouldNotUseLeavesTheFileWhenItsKeyIsReset() throws {
    let text = #"{"format": 2, "gap": "wide", "peek": false}"#
    let read = try Settings.read(text)
    #expect(read.gap == Settings().gap && !read.valueProblems.isEmpty)
    var put = read
    put.valueProblems = []  // as `reset gap` leaves them
    #expect(try Settings.rewrite(text, from: read, to: put) == #"{"format": 2, "peek": false}"#)
  }

  // MARK: A file from before the mark

  @Test func aFileNobodyEverChangedIsEmptied() throws {
    let upgraded = try #require(try Settings.upgradedFile(Self.wholeFile))
    #expect(upgraded.text == "{\n  \"format\" : 2\n}\n", "in the file's own style")
    #expect(upgraded.stripped.count == 68 && upgraded.stripped == upgraded.stripped.sorted())
  }

  @Test func whatSomebodyChangedStaysByteForByteWithItsOrderItsSpacingAndWhatArborDoesNotKnow() throws {
    let text = """
      {
          "peek" : true,
          "gap":   20,
          "theirs" : { "a": [1,  2] },
          "animationDuration" : 0.46,
          "rules": [ {"app": "com.apple.Terminal", "action": "dock right"} ],
          "bindings" : {

          },
          "tileStyle": "name"
      }

      """
    let upgraded = try #require(try Settings.upgradedFile(text))
    #expect(
      upgraded.text == """
        {
            "gap":   20,
            "theirs" : { "a": [1,  2] },
            "rules": [ {"app": "com.apple.Terminal", "action": "dock right"} ],
            "tileStyle": "name",
            "format" : 2
        }

        """)
    #expect(upgraded.stripped == ["animationDuration", "bindings", "peek"])
  }

  @Test func whatStaysMeansWhatItMeant() throws {
    // Of what goes nothing is said here on purpose: it follows the defaults of the day, which is the point.
    let text = Self.wholeFile.replacingOccurrences(of: #""gap" : 12"#, with: #""gap" : 30"#)
      .replacingOccurrences(of: #""peek" : true"#, with: #""peek" : false"#)
      .replacingOccurrences(of: #""messages" : "helpful""#, with: #""messages" : "all""#)
    let upgraded = try #require(try Settings.upgradedFile(text))
    #expect(try JSONText(upgraded.text).keys(at: []) == ["gap", "messages", "peek", "format"])
    let read = try Settings.read(upgraded.text)
    #expect(read.gap == 30 && !read.peek && read.messages == "all")
  }

  @Test func aDefaultOfAnEarlierDayIsNoChoiceEither() throws {
    // ⇧⌘ were the rectangle's keys until 2026-10-14, and the guard shipped switched on until then.
    let upgraded = try #require(try Settings.upgradedFile(#"{"frameRectangleModifier": "shift+cmd", "guardDesktopClicks": true, "gap": 12}"#))
    #expect(upgraded.text == #"{"format": 2}"#)
    #expect(try Settings.read(upgraded.text) == Settings(), "they follow the defaults of today")
  }

  @Test func theSwitchForTheGesturesIsStrippedOnlyAsTheFirstBuildWroteIt() throws {
    #expect(try Settings.upgradedFile(#"{"pointerGestures": false}"#)?.text == #"{"format": 2}"#)
    #expect(try Settings.upgradedFile(#"{"pointerGestures": true}"#)?.text == #"{"pointerGestures": true, "format": 2}"#, "somebody switched it on")
  }

  @Test func itHappensOnce() throws {
    let upgraded = try #require(try Settings.upgradedFile(Self.wholeFile))
    #expect(try Settings.upgradedFile(upgraded.text) == nil)
    // What somebody writes into a marked file is a choice, whatever it says.
    #expect(try Settings.upgradedFile(#"{"format": 2, "gap": 12, "peek": true}"#) == nil)
  }

  @Test func numbersAreComparedByTheirValueAndListsWithoutTheirWhiteSpace() throws {
    // An older macOS wrote 0.46 with seventeen digits, and an empty list over three lines.
    let text = "{\"animationDuration\": 0.46000000000000002, \"gap\": 12.0, \"rules\": [\n\n  ], \"bindings\": { }, \"messages\": \"helpful\"}"
    #expect(try Settings.upgradedFile(text)?.text == #"{"format": 2}"#)
    // White space inside a string counts, and so does half a point.
    #expect(try Settings.upgradedFile(#"{"excludedBundleIDs": [" "], "holdStillFor": [""], "gap": 12.5}"#)?.stripped == [])
  }

  @Test func aFileArborCannotReadIsLeftAlone() throws {
    #expect(throws: Settings.FileError.self) { try Settings.upgradedFile(#"{"gap": 12,, "peek": true}"#) }
    // No object, so no file of any kind: what is wrong with it is `load`'s to say.
    #expect(try Settings.upgradedFile("[]") == nil)
  }

  @Test func aValueArborCannotUseStaysForWhoeverWroteIt() throws {
    let upgraded = try #require(try Settings.upgradedFile(#"{"gap": "12", "peek": true}"#))
    #expect(upgraded.text == #"{"gap": "12", "format": 2}"#)
  }

  @Test func aByteOrderMarkAndTheLineEndingsOfAnotherSystemStay() throws {
    let upgraded = try #require(try Settings.upgradedFile("\u{FEFF}{\r\n  \"peek\": true,\r\n  \"gap\": 20\r\n}\r\n"))
    #expect(upgraded.text == "\u{FEFF}{\r\n  \"gap\": 20,\r\n  \"format\": 2\r\n}\r\n")
  }

  @Test func whatArborCouldNotReadInAListStaysAsItWasWritten() throws {
    let text = #"""
      {"gap": 12, "rules": [{"app": "com.b", "action": "dock sideways"}], "bindings": {"ctrl+opt+x": 5}, "displays": [{"gap": 3}]}
      """#
    #expect(
      try Settings.upgradedFile(text)?.text == #"""
        {"rules": [{"app": "com.b", "action": "dock sideways"}], "bindings": {"ctrl+opt+x": 5}, "displays": [{"gap": 3}], "format": 2}
        """#)
  }

  @Test func aMarkedFileIsNotEvenRead() throws {
    // It has a typo, which is `load`'s to speak of, in its own words.
    #expect(try Settings.upgradedFile(#"{"format": 2, "gap": wide}"#) == nil)
  }

  @Test func aKeyWrittenTwiceGoesTwice() throws {
    #expect(try Settings.upgradedFile(#"{"gap": 12, "peek": false, "gap": 30}"#)?.text == #"{"peek": false, "format": 2}"#)
  }

  // MARK: The table

  /// The table is history. When a default changes it stays as it is, and that is what lets the change reach an old file. If this fails,
  /// somebody has "kept it up to date": take the change back.
  @Test func theTableOfOldDefaultsIsFrozen() throws {
    var hash: UInt64 = 0xcbf2_9ce4_8422_2325
    for byte in Settings.defaultsOfOldFiles.utf8 { hash = (hash ^ UInt64(byte)) &* 0x100_0000_01b3 }
    #expect(hash == 0xcda9_d01b_bc8f_a7cc)
    #expect(try JSONText(Settings.defaultsOfOldFiles).keys(at: [])?.count == 68)
  }
}
