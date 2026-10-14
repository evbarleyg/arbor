import ArborCore
import Foundation
import Testing

private let terminal = "com.apple.Terminal"
private let mail = "com.apple.mail"

private func decodeSettings(_ json: String) throws -> Settings {
  try JSONDecoder().decode(Settings.self, from: Data(json.utf8))
}

@Suite struct RuleActionTests {
  @Test func parsesEveryForm() throws {
    #expect(try RuleAction(text: "float") == .float)
    #expect(try RuleAction(text: "ignore") == .ignore)
    #expect(try RuleAction(text: "dock right") == .dock(.right))
    #expect(try RuleAction(text: "dock beside com.apple.mail bottom") == .dockBeside(bundleID: mail, .bottom))
  }

  @Test func wordsIgnoreCaseAndSpacingButBundleIDsKeepTheirCase() throws {
    #expect(try RuleAction(text: "  Dock   UP ") == .dock(.top))
    #expect(try RuleAction(text: "FLOAT") == .float)
    #expect(
      try RuleAction(text: "dock BESIDE com.apple.Terminal down") == .dockBeside(bundleID: terminal, .bottom))
  }

  @Test(arguments: [
    RuleAction.float, .ignore, .dock(.left), .dock(.bottom), .dockBeside(bundleID: terminal, .top),
  ])
  func textRoundTrips(action: RuleAction) throws {
    #expect(try RuleAction(text: action.text) == action)
  }

  @Test(arguments: [
    "", "   ", "dock", "dock sideways", "dock beside com.apple.mail", "dock beside com.apple.mail sideways",
    "dock left now", "teleport", "float now", "ignore it",
  ])
  func rejectsBadText(text: String) {
    #expect(throws: RuleAction.ParseError.self) { try RuleAction(text: text) }
  }

  @Test func errorsSayWhatIsWrong() {
    func message(_ text: String) -> String {
      do {
        _ = try RuleAction(text: text)
        return "no error"
      } catch {
        return "\(error)"
      }
    }
    let usage = "expected float, ignore, pin, dock auto, dock <edge> or dock beside <bundle id> <edge>"
    let edges = "expected left, right, top or bottom"
    #expect(message("dock sideways") == "unknown edge `sideways` in `dock sideways`; \(edges)")
    #expect(message("teleport") == "unknown action `teleport`; \(usage)")
    #expect(message(" ") == "`action` is empty; \(usage)")
  }
}

@Suite struct AppRuleTests {
  @Test func matchesTheWholeBundleIDIgnoringCase() {
    let rule = AppRule(app: terminal, action: .dock(.right))
    #expect(rule.matches(bundleID: terminal, title: "anything"))
    #expect(rule.matches(bundleID: "com.apple.terminal", title: "anything"))
    #expect(!rule.matches(bundleID: "com.apple.Terminal2", title: "anything"))
    #expect(!rule.matches(bundleID: nil, title: "anything"))
  }

  @Test func titlesMatchAsCaseInsensitiveSubstrings() {
    let rule = AppRule(app: mail, title: "Inbox", action: .dock(.left))
    #expect(rule.matches(bundleID: mail, title: "Inbox – 3 messages"))
    #expect(rule.matches(bundleID: mail, title: "All INBOXES"))
    #expect(!rule.matches(bundleID: mail, title: "New Message"))
    #expect(!rule.matches(bundleID: mail, title: ""))
  }

  /// The same on macOS and Linux, whichever `contains` Foundation brings along.
  @Test func titlesMatchWholeCharacters() {
    func matches(_ pattern: String, _ title: String) -> Bool {
      AppRule(app: mail, title: pattern, action: .float).matches(bundleID: mail, title: title)
    }
    // One character written two ways (é, and e followed by a combining accent) is the same character.
    #expect(matches("caf\u{E9}", "Cafe\u{301} menu"))
    #expect(matches("cafe\u{301}", "CAF\u{C9} MENU"))
    // Part of a character is not a match: e is not é, and 👍 is not 👍🏽.
    #expect(!matches("cafe", "Caf\u{E9} menu"))
    #expect(!matches("cafe", "Cafe\u{301} menu"))
    #expect(!matches("👍", "Review 👍🏽"))
    #expect(matches("👍🏽", "Review 👍🏽"))
  }

  @Test func anEmptyTitleMatchesEveryTitle() {
    let rule = AppRule(app: mail, title: "", action: .float)
    #expect(rule.title == nil)
    #expect(rule.matches(bundleID: mail, title: "New Message"))
    #expect(rule.matches(bundleID: mail, title: ""))
    var edited = AppRule(app: mail, title: "Inbox", action: .float)
    edited.title = ""
    #expect(edited.matches(bundleID: mail, title: "New Message"))
    #expect("\(edited)" == "com.apple.mail → float")
  }

  @Test func theFirstMatchWinsAndNonMatchingTitlesFallThrough() {
    let inbox = AppRule(app: mail, title: "inbox", action: .dock(.left))
    let compose = AppRule(app: mail, title: "New Message", action: .float)
    let anyMail = AppRule(app: mail, action: .dock(.right))
    let alsoInbox = AppRule(app: mail, title: "Inbox", action: .ignore)
    let rules = [inbox, compose, anyMail, alsoInbox]
    #expect(AppRule.firstMatch(in: rules, bundleID: mail, title: "Inbox (12)") == inbox)
    #expect(AppRule.firstMatch(in: rules, bundleID: mail, title: "New Message") == compose)
    #expect(AppRule.firstMatch(in: rules, bundleID: mail, title: "Re: lunch") == anyMail)
    #expect(AppRule.firstMatch(in: rules, bundleID: terminal, title: "Inbox") == nil)
    #expect(AppRule.firstMatch(in: [], bundleID: mail, title: "Inbox") == nil)
  }

  @Test func describesItself() {
    #expect("\(AppRule(app: terminal, action: .dock(.right)))" == "com.apple.Terminal → dock right")
    #expect(
      "\(AppRule(app: mail, title: "Inbox", action: .dockBeside(bundleID: terminal, .bottom)))"
        == #"com.apple.mail, title contains "Inbox" → dock beside com.apple.Terminal bottom"#)
  }

  @Test func codableRoundTripWritesTheActionAsText() throws {
    let rules = [
      AppRule(app: terminal, action: .dock(.right)),
      AppRule(app: mail, title: "Inbox", action: .dockBeside(bundleID: terminal, .bottom)),
    ]
    let data = try JSONEncoder().encode(rules)
    #expect(try JSONDecoder().decode([AppRule].self, from: data) == rules)
    let json = String(decoding: data, as: UTF8.self)
    #expect(json.contains(#""action":"dock right""#))
    #expect(json.contains(#""action":"dock beside com.apple.Terminal bottom""#))
    #expect(!json.contains(#""title":null"#), "a missing title is left out")
  }
}

@Suite struct SettingsRulesTests {
  @Test func theSpecExampleLoads() throws {
    let settings = try decodeSettings(
      """
      {
        "rules": [
          { "app": "com.apple.Terminal", "action": "dock right" },
          { "app": "com.apple.mail", "title": "Inbox", "action": "dock left" },
          { "app": "com.tinyspeck.slackmacgap", "action": "dock beside com.apple.mail bottom" },
          { "app": "com.apple.systempreferences", "action": "float" },
          { "app": "com.apple.finder", "action": "ignore" }
        ]
      }
      """)
    #expect(
      settings.rules == [
        AppRule(app: terminal, action: .dock(.right)),
        AppRule(app: mail, title: "Inbox", action: .dock(.left)),
        AppRule(app: "com.tinyspeck.slackmacgap", action: .dockBeside(bundleID: mail, .bottom)),
        AppRule(app: "com.apple.systempreferences", action: .float),
        AppRule(app: "com.apple.finder", action: .ignore),
      ])
    #expect(settings.skippedRules.isEmpty)
  }

  @Test func badRulesAreSkippedWithAReasonAndTheOthersStillLoad() throws {
    let settings = try decodeSettings(
      """
      {
        "gap": 20,
        "rules": [
          { "app": "com.apple.Terminal", "action": "dock sideways" },
          { "app": "com.apple.Notes" },
          { "action": "float" },
          "com.apple.mail",
          { "app": "com.apple.mail", "title": "Inbox", "action": "dock left" },
          null,
          { "app": 42, "action": "float" },
          { "app": "com.apple.Safari", "title": 7, "action": "float" },
          { "app": "com.apple.Safari ", "action": "float" },
          { "app": "com.apple.finder", "action": "teleport" },
          { "app": "com.apple.Terminal", "action": "dock right" }
        ]
      }
      """)
    #expect(settings.gap == 20)
    #expect(
      settings.rules == [
        AppRule(app: mail, title: "Inbox", action: .dock(.left)),
        AppRule(app: terminal, action: .dock(.right)),
      ])
    let example = #"expected an object such as {"app": "com.apple.Terminal", "action": "dock right"}"#
    let expected = [
      "entry 1 (com.apple.Terminal): unknown edge `sideways` in `dock sideways`; "
        + "expected left, right, top or bottom",
      "entry 2 (com.apple.Notes): `action` is missing",
      "entry 3: `app` is missing",
      "entry 4: \(example)",
      "entry 6: \(example)",
      "entry 7: `app` must be text",
      "entry 8 (com.apple.Safari): `title` must be text",
      #"entry 9 (com.apple.Safari ): `app` must be a bundle id such as com.apple.Terminal, "#
        + #"got "com.apple.Safari ""#,
      "entry 10 (com.apple.finder): unknown action `teleport`; "
        + "expected float, ignore, pin, dock auto, dock <edge> or dock beside <bundle id> <edge>",
    ]
    #expect(settings.skippedRules == expected)
  }

  @Test func rulesThatAreNotAListAreSkippedWithoutLosingTheOtherSettings() throws {
    let settings = try decodeSettings(
      #"{"gap": 30, "rules": {"app": "com.apple.Terminal", "action": "float"}}"#)
    #expect(settings.gap == 30)
    #expect(settings.rules.isEmpty)
    #expect(settings.skippedRules == ["`rules` must be a list of rules; none were loaded"])
    let null = try decodeSettings(#"{"rules": null}"#)
    #expect(null.rules.isEmpty && null.skippedRules.isEmpty)
  }

  @Test func anOldSettingsFileWithoutRulesStillLoads() throws {
    // Every key settings.json had before rules existed.
    let settings = try decodeSettings(
      """
      {
        "arrangeDesktopWeight" : 0.75,
        "excludedBundleIDs" : ["com.apple.Music"],
        "gap" : 8,
        "hotkeysEnabled" : false,
        "minimumUsableHeight" : 100,
        "minimumUsableWidth" : 200,
        "screenEdgeBand" : 10,
        "tabsEnabled" : true,
        "windowEdgeFraction" : 0.25
      }
      """)
    #expect(settings.gap == 8)
    #expect(settings.excludedBundleIDs == ["com.apple.Music"])
    #expect(!settings.hotkeysEnabled)
    #expect(settings.arrangeDesktopWeight == 0.75)
    #expect(settings.rules.isEmpty)
    #expect(settings.skippedRules.isEmpty)
  }

  @Test func rulesRoundTripAndSkippedReasonsAreNotSaved() throws {
    var settings = try decodeSettings(
      #"{"rules": [{"app": "com.apple.Terminal", "action": "dock nowhere"}]}"#)
    #expect(settings.skippedRules.count == 1)
    settings.rules = [
      AppRule(app: terminal, action: .dock(.right)), AppRule(app: mail, title: "Inbox", action: .ignore),
    ]
    let data = try JSONEncoder().encode(settings)
    let json = String(decoding: data, as: UTF8.self)
    #expect(json.contains(#""rules":["#))
    #expect(!json.contains("skipped"))
    let decoded = try JSONDecoder().decode(Settings.self, from: data)
    #expect(decoded.rules == settings.rules)
    #expect(decoded.skippedRules.isEmpty)
  }

  @Test func oldSettingsFilesWaitTwoSeconds() throws {
    let old = try JSONDecoder().decode(Settings.self, from: Data(#"{"gap": 8, "rules": []}"#.utf8))
    #expect(old.ruleTitleWait == 2)
    let set = try JSONDecoder().decode(Settings.self, from: Data(#"{"ruleTitleWait": 0.5}"#.utf8))
    #expect(set.ruleTitleWait == 0.5)
    #expect(try JSONDecoder().decode(Settings.self, from: try JSONEncoder().encode(set)) == set)
  }

  @Test func newSettingsFilesListAnEmptyRulesKey() throws {
    let json = String(decoding: try JSONEncoder().encode(Settings()), as: UTF8.self)
    #expect(json.contains(#""rules":[]"#))
  }
}

@Suite struct RulesCommandTests {
  @Test func parsesAndRoundTrips() throws {
    #expect(try Command.parse("rules") == .rules)
    #expect(try Command.parse("Rules") == .rules)
    #expect(try Command.parse(Command.rules.text) == .rules)
    #expect(throws: Command.ParseError.self) { try Command.parse("rules now") }
  }

  @Test func isAQueryAndIsInTheHelp() {
    #expect(Command.rules.isQuery)
    #expect(Command.helpText.contains("rules "))
  }
}
