import ArborCore
import Foundation
import Testing

private let music = "com.apple.Music"
private let notes = "com.apple.Notes"
private let mail = "com.apple.mail"

/// A file somebody has worked on: their own order and spacing, a key Arbor does not know, a rule and
/// a binding it cannot read, and numbers written their way.
private let handEdited = """
  {
    "gap": 8.0,
    "myNote": "ask Sam about the gap",

    "excludedBundleIDs": ["com.apple.Music"],
    "rules": [
      { "app": "com.apple.mail", "title": "Inbox", "action": "dock left" },
      { "app": "com.apple.Terminal", "action": "dock sideways" },
      { "app": "com.apple.Notes", "action": "float" }
    ],
    "bindings": {
      "ctrl+opt+h": "dock left",
      "ctrl+opt+x": 5,
      "ctrl+opt+d": null
    },
    "windowEdgeFraction": 0.250,
    "futureSetting": { "nested": [1, 2, 3] }
  }

  """

@Suite struct SettingsRewriteTests {
  /// `text` after a command changed the settings loaded from it.
  func rewritten(_ text: String, _ change: (inout Settings) -> Void) throws -> String {
    let old = try Settings.read(text)
    var new = old
    change(&new)
    return try Settings.rewrite(text, from: old, to: new)
  }

  /// The board's test for B1.
  @Test func anUnknownKeyAndABadRuleSurviveExclude() throws {
    let result = try rewritten(handEdited) { $0.excludedBundleIDs.append(notes) }
    #expect(
      result
        == handEdited.replacingOccurrences(
          of: #"["com.apple.Music"]"#, with: #"["com.apple.Music", "com.apple.Notes"]"#))
    #expect(result.contains(#""myNote": "ask Sam about the gap""#))
    #expect(result.contains(#"{ "app": "com.apple.Terminal", "action": "dock sideways" }"#))
    #expect(result.contains(#""ctrl+opt+x": 5"#))
    #expect(try Settings.read(result).excludedBundleIDs == [music, notes])
  }

  @Test func includeTakesOnlyThatAppOut() throws {
    let result = try rewritten(handEdited) { $0.excludedBundleIDs.removeAll { $0 == music } }
    #expect(result == handEdited.replacingOccurrences(of: #"["com.apple.Music"]"#, with: "[]"))
  }

  @Test func noChangeMeansNoChange() throws {
    #expect(try rewritten(handEdited) { _ in } == handEdited)
    #expect(try rewritten("{}") { _ in } == "{}")
    #expect(try rewritten(handEdited) { $0.gap = 8 } == handEdited, "8.0 is 8")
  }

  @Test func aKeyTheFileLeavesOutIsAddedOnlyWhenItChanges() throws {
    let result = try rewritten("{\n  \"gap\": 20\n}\n") { $0.excludedBundleIDs = [music] }
    #expect(result == "{\n  \"gap\": 20,\n  \"excludedBundleIDs\": [\n    \"com.apple.Music\"\n  ]\n}\n")
    #expect(try rewritten("{}") { $0.tabsEnabled = true } == "{\n  \"tabsEnabled\" : true\n}")
  }

  @Test func plainValuesAreReplacedInPlace() throws {
    #expect(
      try rewritten(handEdited) {
        $0.gap = 10.5
        $0.windowEdgeFraction = 0.4
      }
        == handEdited.replacingOccurrences(of: "8.0", with: "10.5").replacingOccurrences(
          of: "0.250", with: "0.4"))
    #expect(
      try rewritten(#"{"frameRectangleModifier": "shift+cmd", "hotkeysEnabled": true}"#) {
        $0.frameRectangleModifier = "none"
        $0.hotkeysEnabled = false
      } == #"{"frameRectangleModifier": "none", "hotkeysEnabled": false}"#)
  }

  /// Every key there is, found by looking, so that a key added to `Settings` later is covered too.
  @Test func aFileOfArborsOwnRoundTripsThroughAChangeToEveryKey() throws {
    let text = try Settings().fileText
    var values = try #require(try JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any])
    for (key, value) in values {
      switch value {
      case let flag as Bool where "\(type(of: value))".contains("Bool"): values[key] = !flag
      case let number as Double:
        guard case .number(let range, _, _) = try SettingsSchema.entry(named: key).kind else {
          Issue.record("\(key) is a number without a range")
          continue
        }
        values[key] = number == range.upperBound ? range.lowerBound : range.upperBound
      case let string as String:
        switch try SettingsSchema.entry(named: key).kind {
        case .text(let example): values[key] = example
        case .choice(let choices): values[key] = choices.first { $0.value != string }?.value
        default: Issue.record("\(key) is text that is neither checked nor a choice")
        }
      case is [Any] where key == "rules":
        values[key] = [
          ["app": mail, "title": "Inbox", "action": "dock left"], ["app": notes, "action": "ignore"],
        ]
      case is [Any] where key == "displays":
        values[key] = [["match": "builtin", "gap": 8], ["match": ">=2500", "minimumUsableWidth": 300]]
      case is [Any]: values[key] = [music, notes]
      case is [String: Any]: values[key] = ["ctrl+opt+h": "dock left", "ctrl+opt+/": NSNull()]
      default: Issue.record("a setting of a new kind: \(key); say here how to change it")
      }
    }
    let changed = try Settings.read(try JSONSerialization.data(withJSONObject: values))
    let before = try JSONText(String(decoding: try JSONEncoder().encode(Settings()), as: UTF8.self))
    let after = try JSONText(String(decoding: try JSONEncoder().encode(changed), as: UTF8.self))
    for key in try #require(before.keys(at: [])) {
      #expect(before.value(at: [key]) != after.value(at: [key]), "\(key) did not change")
    }
    let result = try Settings.rewrite(text, from: Settings(), to: changed)
    #expect(try Settings.read(result) == changed)
    #expect(try JSONText(result).keys(at: []) == JSONText(text).keys(at: []), "no key moved, none was added")
    #expect(try Settings.read(try Settings.rewrite(result, from: changed, to: Settings())) == Settings())
  }

  // MARK: Edits that were not loaded yet

  @Test func editsMadeSinceTheFileWasLoadedSurvive() throws {
    let loaded = try Settings.read(#"{"gap": 12, "excludedBundleIDs": ["com.apple.Music"]}"#)
    var changed = loaded
    changed.excludedBundleIDs.append(notes)
    // Meanwhile the file got a new gap, another exclusion, a rule and a binding.
    let edited = """
      {
        "gap": 30,
        "excludedBundleIDs": ["com.apple.Music", "com.apple.mail"],
        "rules": [{"app": "com.apple.mail", "action": "float"}],
        "bindings": {"ctrl+opt+h": "dock left"}
      }
      """
    #expect(
      try Settings.rewrite(edited, from: loaded, to: changed)
        == edited.replacingOccurrences(
          of: #"["com.apple.Music", "com.apple.mail"]"#,
          with: #"["com.apple.Music", "com.apple.mail", "com.apple.Notes"]"#))
  }

  /// `old` is the settings without what the command asks for, not what happens to be in memory.
  @Test func whatIsAskedForIsWrittenEvenIfMemoryHasItAlready() throws {
    var excluded = Settings()
    excluded.excludedBundleIDs = [music]
    // Excluded while the file had a typo, so only in memory. The typo is fixed; `exclude` again.
    #expect(
      try Settings.rewrite(#"{"gap": 3}"#, from: Settings(), to: excluded)
        == #"{"gap": 3, "excludedBundleIDs": ["com.apple.Music"]}"#)
    // In the file only, as an edit that was not reloaded. `include` takes it out.
    #expect(
      try Settings.rewrite(
        #"{"excludedBundleIDs": ["com.apple.mail", "com.apple.Music"]}"#, from: excluded, to: Settings())
        == #"{"excludedBundleIDs": ["com.apple.mail"]}"#)
  }

  /// Deleting the key says the same as emptying the list.
  @Test func whatWasDeletedByHandDoesNotComeBack() throws {
    var loaded = Settings()
    loaded.excludedBundleIDs = [music]
    loaded.bindings = ["ctrl+opt+h": "dock left"]
    loaded.rules = [AppRule(app: mail, action: .float)]
    var changed = loaded
    changed.excludedBundleIDs.append(notes)
    changed.bindings["ctrl+opt+j"] = "dock right"
    changed.rules.append(AppRule(app: notes, action: .ignore))
    for emptied in [
      "{}", #"{"excludedBundleIDs": [], "bindings": {}, "rules": []}"#,
      #"{"excludedBundleIDs": null, "bindings": null, "rules": null}"#,
    ] {
      let result = try Settings.read(try Settings.rewrite(emptied, from: loaded, to: changed))
      #expect(result.excludedBundleIDs == [notes], "\(emptied)")
      #expect(result.bindings == ["ctrl+opt+j": "dock right"], "\(emptied)")
      #expect(result.rules == [AppRule(app: notes, action: .ignore)], "\(emptied)")
    }
  }

  @Test func ofAKeyWrittenTwiceOnlyTheOneThatCountsIsChanged() throws {
    let text = #"{"excludedBundleIDs": ["a"], "gap": 1, "excludedBundleIDs": ["b", "c"], "gap": 2}"#
    #expect(try Settings.read(text).excludedBundleIDs == ["a"])
    #expect(
      try rewritten(text) {
        $0.excludedBundleIDs.append("z")
        $0.gap = 5
      } == #"{"excludedBundleIDs": ["a", "z"], "gap": 5, "excludedBundleIDs": ["b", "c"], "gap": 2}"#)
  }

  @Test func oneEntryCanTakeThePlaceOfAnother() throws {
    #expect(
      try rewritten(#"{"excludedBundleIDs": ["a", "b"]}"#) { $0.excludedBundleIDs = ["a", "c"] }
        == #"{"excludedBundleIDs": ["a", "c"]}"#)
  }

  @Test func savingTheSameChangeTwiceChangesNothingMore() throws {
    var changed = Settings()
    changed.excludedBundleIDs = [music]
    changed.bindings = ["ctrl+opt+h": "dock left"]
    changed.rules = [AppRule(app: mail, action: .float), AppRule(app: mail, action: .float)]
    changed.gap = 3
    let once = try Settings.rewrite("{}", from: Settings(), to: changed)
    #expect(try Settings.read(once) == changed)
    #expect(try Settings.rewrite(once, from: Settings(), to: changed) == once)
  }

  @Test func whatTheFileAlreadyGainedOrLostIsNotRepeated() throws {
    let loaded = try Settings.read(#"{"excludedBundleIDs": ["com.apple.Music"]}"#)
    var excluded = loaded
    excluded.excludedBundleIDs.append(notes)
    let alreadyThere = #"{"excludedBundleIDs": ["com.apple.Notes", "com.apple.Music"]}"#
    #expect(try Settings.rewrite(alreadyThere, from: loaded, to: excluded) == alreadyThere)

    var included = loaded
    included.excludedBundleIDs = []
    let alreadyGone = #"{"excludedBundleIDs": ["com.apple.mail"]}"#
    #expect(try Settings.rewrite(alreadyGone, from: loaded, to: included) == alreadyGone)
  }

  // MARK: Bindings

  @Test func bindingsChangeEntryByEntry() throws {
    let result = try rewritten(handEdited) {
      $0.bindings["ctrl+opt+h"] = "dock right"
      $0.bindings.removeValue(forKey: "ctrl+opt+d")
      $0.bindings.updateValue(nil, forKey: "ctrl+opt+space")
      $0.bindings["ctrl+opt+/"] = "arrange"
    }
    #expect(
      result
        == handEdited.replacingOccurrences(
          of: """
                "ctrl+opt+h": "dock left",
                "ctrl+opt+x": 5,
                "ctrl+opt+d": null

            """,
          with: """
                "ctrl+opt+h": "dock right",
                "ctrl+opt+x": 5,
                "ctrl+opt+/": "arrange",
                "ctrl+opt+space": null

            """))
    let settings = try Settings.read(result)
    #expect(
      settings.bindings == ["ctrl+opt+h": "dock right", "ctrl+opt+space": nil, "ctrl+opt+/": "arrange"])
    #expect(settings.unreadableBindings == ["ctrl+opt+x"])
  }

  @Test func bindingsAreAddedToAFileWithoutAny() throws {
    #expect(
      try rewritten("{\n  \"gap\": 1\n}") { $0.bindings = ["ctrl+opt+h": "dock left"] }
        == "{\n  \"gap\": 1,\n  \"bindings\": {\n    \"ctrl+opt+h\": \"dock left\"\n  }\n}")
    #expect(
      try rewritten(#"{"bindings": null}"#) { $0.bindings = ["ctrl+opt+h": nil] }
        == #"{"bindings": {"ctrl+opt+h": null}}"#)
  }

  // MARK: Rules

  @Test func addingARuleKeepsTheOthersAsWrittenAndTheUnreadableOneInPlace() throws {
    let result = try rewritten(handEdited) { $0.rules.append(AppRule(app: music, action: .ignore)) }
    #expect(
      result
        == handEdited.replacingOccurrences(
          of: """
                { "app": "com.apple.Notes", "action": "float" }

            """,
          with: """
                { "app": "com.apple.Notes", "action": "float" },
                { "app": "com.apple.Music", "action": "ignore" }

            """))
    let settings = try Settings.read(result)
    #expect(settings.rules.map(\.app) == [mail, notes, music])
    #expect(settings.skippedRules.count == 1)
  }

  @Test func removingAndReorderingRulesKeepsUnreadableEntries() throws {
    let bad = #"{ "app": "com.apple.Terminal", "action": "dock sideways" }"#
    let removed = try rewritten(handEdited) { $0.rules.removeFirst() }
    #expect(
      try JSONText(removed).elements(at: ["rules"]) == [
        bad, #"{ "app": "com.apple.Notes", "action": "float" }"#,
      ])

    let inserted = try rewritten(#"{"rules": [1, {"app": "r", "action": "float"}, 2]}"#) {
      $0.rules.insert(AppRule(app: "n", action: .float), at: 0)
    }
    #expect(
      inserted == #"{"rules": [{"app": "n", "action": "float"}, 1, {"app": "r", "action": "float"}, 2]}"#)

    let swapped = try rewritten(handEdited) { $0.rules.reverse() }
    #expect(
      try JSONText(swapped).elements(at: ["rules"]) == [
        bad, #"{ "app": "com.apple.Notes", "action": "float" }"#,
        #"{ "app": "com.apple.mail", "title": "Inbox", "action": "dock left" }"#,
      ], "it stays in front of the rule it was in front of")

    let emptied = try rewritten(handEdited) { $0.rules = [] }
    #expect(try JSONText(emptied).elements(at: ["rules"]) == [bad])
  }

  /// Each with its own note. Which of them a change is about shows in where the others are.
  @Test func ofTwoRulesThatAreTheSameEachKeepsItsOwnText() throws {
    func a(_ note: String) -> String { #"{"app": "a", "action": "float", "note": "\#(note)"}"# }
    let b = #"{"app": "b", "action": "float"}"#
    let text = #"{"rules": [\#(a("first")), \#(b), \#(a("third"))]}"#
    #expect(try rewritten(text) { $0.rules.remove(at: 0) } == #"{"rules": [\#(b), \#(a("third"))]}"#)
    #expect(try rewritten(text) { $0.rules.remove(at: 2) } == #"{"rules": [\#(a("first")), \#(b)]}"#)
    #expect(try rewritten(text) { $0.rules.remove(at: 1) } == #"{"rules": [\#(a("first")), \#(a("third"))]}"#)
    #expect(
      try rewritten(text) { $0.rules[0] = AppRule(app: "c", action: .ignore) }
        == #"{"rules": [{"app": "c", "action": "ignore", "note": "first"}, \#(b), \#(a("third"))]}"#)
    #expect(
      try rewritten(text) { $0.rules[2] = AppRule(app: "c", action: .ignore) }
        == #"{"rules": [\#(a("first")), \#(b), {"app": "c", "action": "ignore", "note": "third"}]}"#)
    #expect(
      try rewritten(text) { $0.rules.insert(AppRule(app: "c", action: .ignore), at: 0) }
        == #"{"rules": [{"app": "c", "action": "ignore"}, \#(a("first")), \#(b), \#(a("third"))]}"#)
    // An entry Arbor cannot read stays in front of the rule it was in front of.
    #expect(
      try rewritten(#"{"rules": [true, \#(a("first")), 5, \#(b), \#(a("third"))]}"#) {
        $0.rules[0] = AppRule(app: "c", action: .ignore)
      } == #"{"rules": [true, {"app": "c", "action": "ignore", "note": "first"}, 5, \#(b), \#(a("third"))]}"#)
  }

  @Test func aRuleChangedIntoTheSameAsAnotherKeepsItsOwnText() throws {
    let text = #"{"rules": [{"app": "b", "action": "float", "note": 1}, {"app": "a", "action": "float", "note": 2}]}"#
    #expect(
      try rewritten(text) { $0.rules[0] = $0.rules[1] }
        == #"{"rules": [{"app": "a", "action": "float", "note": 1}, {"app": "a", "action": "float", "note": 2}]}"#)
    #expect(
      try rewritten(text) { $0.rules[1] = $0.rules[0] }
        == #"{"rules": [{"app": "b", "action": "float", "note": 1}, {"app": "b", "action": "float", "note": 2}]}"#)
  }

  /// Found by fuzzing an earlier version, which went by the rules' places in `old`.
  @Test func savingAChangeThatMakesTwoRulesTheSameTwiceMovesNothing() throws {
    let text = #"{"rules": [{"app": "c", "action": "ignore", "note": 1}, {"app": "n", "action": "ignore"}, null, {"app": "a", "action": "float"}]}"#
    let old = try Settings.read(text)
    var new = old
    new.rules[0] = new.rules[2]
    let once = try Settings.rewrite(text, from: old, to: new)
    #expect(
      once == #"{"rules": [{"app": "a", "action": "float", "note": 1}, {"app": "n", "action": "ignore"}, null, {"app": "a", "action": "float"}]}"#)
    #expect(try Settings.rewrite(once, from: old, to: new) == once)
  }

  @Test func aLongListOfRulesIsNoTrouble() throws {
    var settings = Settings()
    settings.rules = (0..<3000).map { AppRule(app: "com.example.a\($0 % 7)", action: .float) }
    let text = try settings.fileText
    var changed = settings
    changed.rules.reverse()
    changed.rules.remove(at: 1500)
    #expect(try Settings.read(try Settings.rewrite(text, from: settings, to: changed)).rules == changed.rules)
  }

  @Test func twoRulesThatAreTheSameAreBothKept() throws {
    let text = #"{"rules": [{"app": "a", "action": "float"}, 1, {"action": "float", "app": "a"}]}"#
    let result = try rewritten(text) { $0.rules.append(AppRule(app: "b", action: .float)) }
    #expect(result == text.replacingOccurrences(of: "]}", with: #", {"app": "b", "action": "float"}]}"#))
  }

  @Test func entriesThatAreNotEvenObjectsAreKept() throws {
    let result = try rewritten(
      #"{"rules": [5, "text", null, {"app": "com.apple.mail", "action": "float"}, []]}"#
    ) {
      $0.rules[0].action = .ignore
    }
    #expect(result == #"{"rules": [5, "text", null, {"app": "com.apple.mail", "action": "ignore"}, []]}"#)
  }

  @Test func aRuleThatChangesInItsPlaceIsChangedKeyByKey() throws {
    let text = """
      {"rules": [
        { "app": "a", "note": "mine", "action": "float", "title": "x" },
        { "app": "b", "action": "float" }
      ]}
      """
    #expect(
      try rewritten(text) { $0.rules[0].action = .ignore }
        == text.replacingOccurrences(
          of: #""note": "mine", "action": "float""#, with: #""note": "mine", "action": "ignore""#))
    #expect(
      try rewritten(text) { $0.rules[0].title = nil }
        == text.replacingOccurrences(of: #", "title": "x""#, with: ""))
    #expect(
      try rewritten(text) { $0.rules[1].title = "y" }
        == text.replacingOccurrences(
          of: #""app": "b", "action": "float""#, with: #""app": "b", "action": "float", "title": "y""#))
  }

  /// A note on a rule that was removed must not end up on one that was added.
  @Test func aRuleAddedElsewhereIsNotTakenForAnEdit() throws {
    let text =
      #"{"rules": [{"app": "a", "action": "float"}, {"app": "b", "note": "about b", "action": "float"}, {"app": "c", "action": "float"}]}"#
    let result = try rewritten(text) {
      $0.rules.remove(at: 1)
      $0.rules.append(AppRule(app: "d", action: .float))
    }
    #expect(
      result
        == #"{"rules": [{"app": "a", "action": "float"}, {"app": "c", "action": "float"}, {"app": "d", "action": "float"}]}"#
    )
  }

  @Test func aRuleAddedByHandSinceTheFileWasLoadedIsKept() throws {
    let loaded = try Settings.read(#"{"rules": [{"app": "a", "action": "float"}]}"#)
    var changed = loaded
    changed.rules.append(AppRule(app: "b", action: .float))
    let edited =
      #"{"rules": [{"app": "by.hand", "action": "ignore"}, {"app": "a", "action": "float"}, {"app": "also.by.hand", "action": "float"}]}"#
    #expect(
      try Settings.rewrite(edited, from: loaded, to: changed)
        == edited.replacingOccurrences(
          of: #"{"app": "a", "action": "float"}, "#,
          with: #"{"app": "a", "action": "float"}, {"app": "b", "action": "float"}, "#))
  }

  /// It would be skipped when read back, and from then on no command could remove it.
  @Test func aRuleThatCouldNotBeReadBackIsNotWritten() throws {
    #expect(
      throws: Settings.FileError(
        "rule 1 cannot be saved: `app` must be a bundle id such as com.apple.Terminal, got \"has space\"")
    ) { try rewritten("{}") { $0.rules = [AppRule(app: "has space", action: .float)] } }
  }

  @Test func rulesThatAreNotAListAreNotWrittenOver() throws {
    let text = #"{"gap": 3, "rules": {"app": "com.apple.mail", "action": "float"}}"#
    #expect(throws: Settings.FileError("`rules` is not a list, so the rules cannot be saved; fix it first")) {
      try rewritten(text) { $0.rules = [AppRule(app: notes, action: .float)] }
    }
    // Other keys can still be saved.
    #expect(try rewritten(text) { $0.gap = 4 } == text.replacingOccurrences(of: "3", with: "4"))
    #expect(
      try rewritten(#"{"rules": null}"#) { $0.rules = [AppRule(app: notes, action: .float)] }
        == #"{"rules": [{"app": "com.apple.Notes", "action": "float"}]}"#)
  }

  // MARK: Files Arbor cannot read

  @Test(arguments: [
    "", "not json", "[1, 2]", "{\n  \"gap\": 12\n  \"on\": 1\n}", "{\"gap\": 1} // note",
  ]) func aFileThatCannotBeReadIsNeverRewritten(text: String) {
    var changed = Settings()
    changed.excludedBundleIDs = [music]
    #expect(throws: Settings.FileError.self) { try Settings.rewrite(text, from: Settings(), to: changed) }
  }

  // MARK: Values Arbor could not use

  /// Reading forgives them (`valueProblems`), so the file can be changed. They are somebody's slip, and
  /// theirs to put right.
  @Test(arguments: [
    #""gap": "wide""#, #""gap": 500"#, #""gap": 1e999"#, #""tabsEnabled": "yes""#, #""bindings": ["ctrl+opt+h"]"#,
    #""frameRectangleModifier": "banana""#,
  ]) func aValueArborCouldNotUseSurvivesAChangeToAnotherKey(entry: String) throws {
    let text = "{\(entry), \"excludedBundleIDs\": []}"
    #expect(try Settings.read(text).valueProblems.count == 1)
    #expect(
      try rewritten(text) { $0.excludedBundleIDs = [music] }
        == "{\(entry), \"excludedBundleIDs\": [\"com.apple.Music\"]}")
  }

  @Test func aSingleValueArborCouldNotUseIsReplacedWhenItsKeyChanges() throws {
    #expect(try rewritten(#"{"gap": "wide", "on": 1}"#) { $0.gap = 20 } == #"{"gap": 20, "on": 1}"#)
    #expect(try rewritten(#"{"gap": 500}"#) { $0.gap = 20 } == #"{"gap": 20}"#)
    #expect(try rewritten(#"{"tabsEnabled": "yes"}"#) { $0.tabsEnabled = true } == #"{"tabsEnabled": true}"#)
  }

  /// There may be a dozen good entries beside the bad one.
  @Test func aListOrAnObjectArborCouldNotReadIsNotWrittenOver() throws {
    for text in [#"{"excludedBundleIDs": ["a", 5]}"#, #"{"excludedBundleIDs": "a"}"#, #"{"excludedBundleIDs": {}}"#] {
      #expect(
        throws: Settings.FileError(
          "`excludedBundleIDs` is not a list Arbor can read, so it cannot be changed; fix it first")
      ) { try rewritten(text) { $0.excludedBundleIDs = [music] } }
    }
    // The second has the shape of an object, but a key `JSONDecoder` cannot read: an entry written into it would not count.
    for text in [#"{"bindings": ["ctrl+opt+h"]}"#, #"{"bindings": {"\x": "desktop", "ctrl+opt+d": null}}"#] {
      #expect(try Settings.read(text).valueProblems.count == 1)
      #expect(
        throws: Settings.FileError("`bindings` is not an object Arbor can read, so it cannot be changed; fix it first")
      ) { try rewritten(text) { $0.bindings = ["ctrl+opt+h": "dock left"] } }
    }
  }

  /// `reset` asks for exactly that.
  @Test func emptyingAListOrAnObjectArborCouldNotReadReplacesIt() throws {
    func reset(_ text: String, _ key: String) throws -> String {
      let old = try Settings.read(text)
      var new = old
      try SettingsSchema.entry(named: key).reset(in: &new)
      return try Settings.rewrite(text, from: old, to: new)
    }
    #expect(try reset(#"{"excludedBundleIDs": ["a", 5], "on": 1}"#, "excludedBundleIDs") == #"{"excludedBundleIDs": [], "on": 1}"#)
    #expect(try reset(#"{"excludedBundleIDs": "a"}"#, "excludedBundleIDs") == #"{"excludedBundleIDs": []}"#)
    #expect(try reset(#"{"bindings": ["ctrl+opt+h"]}"#, "bindings") == #"{"bindings": {}}"#)
    #expect(try reset(#"{"bindings": {"\x": "desktop"}, "on": 1}"#, "bindings") == #"{"bindings": {}, "on": 1}"#)
  }

  @Test(arguments: [Double.nan, .infinity]) func aNumberThatCannotBeWrittenIsRefusedInWords(number: Double) {
    var changed = Settings()
    changed.gap = number
    #expect(throws: Settings.FileError("a number that is infinite or not a number cannot be saved")) {
      try Settings.rewrite("{}", from: Settings(), to: changed)
    }
  }

  // MARK: Files that are not quite JSON, but always loaded

  /// `JSONDecoder` allows a comma after the last entry and does not look at values it is not asked
  /// for. Such files loaded before Arbor had a parser of its own, so they load now, and can be changed.
  @Test func filesThatAlwaysLoadedStillLoadAndCanBeChanged() throws {
    let text = """
      {
        "gap": 20,
        "note": "C:\\path",
        "future": 01,
        "excludedBundleIDs": ["com.apple.Music",],
        "rules": [
          {"app": "a", "action": "float"},
          {"app": "b", "action": "float", "title": "x\\.y"},
        ],
        "bindings": {"ctrl+opt+h": "dock left", "ctrl+opt+t": "a\tb",},
      }
      """.replacingOccurrences(of: "\\\\", with: "\\")
    let settings = try Settings.read(text)
    #expect(settings == (try JSONDecoder().decode(Settings.self, from: Data(text.utf8))))
    #expect(settings.gap == 20 && settings.excludedBundleIDs == [music] && settings.rules.map(\.app) == ["a"])
    #expect(settings.skippedRules.count == 1 && settings.unreadableBindings == ["ctrl+opt+t"])
    #expect(
      try rewritten(text) {
        $0.excludedBundleIDs.append(notes)
        $0.gap = 21
      }
        == text.replacingOccurrences(
          of: #"["com.apple.Music",]"#, with: #"["com.apple.Music", "com.apple.Notes"]"#
        )
        .replacingOccurrences(of: "20", with: "21"))
    #expect(
      try rewritten(text) { $0.tabsEnabled = true }
        == text.replacingOccurrences(of: "\"a\tb\",},\n", with: "\"a\tb\",},\n  \"tabsEnabled\": true,\n"))
  }
}

@Suite struct SettingsReadTests {
  @Test func readsWhatJSONDecoderReads() throws {
    let settings = try Settings.read(handEdited)
    #expect(settings == (try JSONDecoder().decode(Settings.self, from: Data(handEdited.utf8))))
    #expect(settings.gap == 8 && settings.rules.count == 2 && settings.skippedRules.count == 1)
    #expect(try Settings.read("{}") == Settings())
    #expect(try Settings.read("\u{FEFF}{\"gap\": 3}").gap == 3, "a byte order mark")
  }

  /// The same words on macOS and Linux, whose decoders describe errors differently.
  @Test(arguments: [
    (
      "{\n  \"gap\": 12\n  \"on\": 1\n}",
      "line 3, column 3: expected `,` or `}` after the value of `gap`, found `\"`"
    ),
    ("{\n  \"gap\": 12,,\n}", "line 2, column 13: expected a key in quotes, found `,`"),
    ("", "line 1, column 1: the file is empty"),
    ("[]", "the settings must be inside { and }"),
    ("12", "the settings must be inside { and }"),
  ]) func saysWhatIsWrong(text: String, reason: String) {
    #expect(throws: Settings.FileError(reason)) { try Settings.read(text) }
  }

  /// A typo can sit in a rule's `title`, which is part of a window title.
  @Test func whatIsLoggedQuotesNothingFromTheFile() throws {
    let text = #"{"rules": [{"app": "com.a", "title": "Salaries "Payroll" 2026", "action": "float"}]}"#
    let error = try #require(throws: Settings.FileError.self) { try Settings.read(text) }
    #expect(error.description.contains("Payroll"), "the reply may: it goes to whoever wrote the file")
    #expect(error.forTheLog == "line 1, column 49")
    let rewriting = try #require(throws: Settings.FileError.self) {
      try Settings.rewrite(text, from: Settings(), to: Settings())
    }
    #expect(rewriting.forTheLog == "line 1, column 49")
    #expect(Settings.FileError("the file is read-only").forTheLog == "the file is read-only")
  }

  @Test func aNewFileListsEveryKeyAndEndsWithANewline() throws {
    let text = try Settings().fileText
    #expect(text.hasSuffix("}\n"))
    #expect(try Settings.read(text) == Settings())
    let keys = try #require(try JSONText(text).keys(at: []))
    #expect(keys == keys.sorted())
    #expect(
      Set(["gap", "rules", "bindings", "excludedBundleIDs", "frameRectangleModifier"]).isSubset(of: keys))
    var slashed = Settings()
    slashed.bindings = ["ctrl+opt+/": "arrange"]
    #expect(try slashed.fileText.contains(#""ctrl+opt+/""#), "no \\/ in a file people read")
  }
}
