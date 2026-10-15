import ArborCore
import Testing

/// What a refused parse says, or nil if it was accepted.
private func refusal(_ text: String) -> String? {
  do {
    _ = try Command.parse(text)
    return nil
  } catch {
    return "\(error)"
  }
}

/// The text form of `set`, `get`, `settings`, `reset`, `bind`, `unbind` and `rule …`.
@Suite struct SettingsCommandTests {
  static let mail = AppRule(app: "com.apple.mail", title: "Inbox (3) / Work", action: .dock(.left))
  static let samples: [SettingsCommand] = [
    .set(key: "gap", value: "16"), .set(key: "windowEdgeFraction", value: "0.25"),
    .set(key: "tabsEnabled", value: "true"),
    .set(key: "frameRectangleModifier", value: "ctrl+opt"), .get(key: "gap"), .get(key: "rules"),
    .list(.text), .list(.json),
    .list(.markdown), .closeWindow, .showWindow(), .showWindow(.rules), .showWindow(.section(.apps)), .showWindow(.section(.appearance)),
    .addApp(key: "excludedBundleIDs", app: "com.apple.Music"), .removeApp(key: "excludedBundleIDs", app: "Music"),
    .set(key: "focusRing", value: "toggle"),
    .reset(key: "gap"), .resetAll(everything: false), .resetAll(everything: true),
    .bind(chord: "ctrl+opt+h", command: "dock left"), .bind(chord: "ctrl+opt+/", command: "set gap 0"),
    .bind(chord: "f5", command: "dock 7 beside 8 bottom"), .unbind(chord: "ctrl+opt+d"),
    .unbind(chord: "ctrl+opt+/"),
    .addRule(AppRule(app: "com.apple.Terminal", action: .dock(.right))), .addRule(mail),
    .addRule(
      AppRule(app: "com.tinyspeck.slackmacgap", action: .dockBeside(bundleID: "com.apple.mail", .bottom))),
    .changeRule(2, AppRule(app: "com.apple.finder", action: .ignore)), .changeRule(1, mail), .removeRule(3),
    .moveRule(3, to: 1),
  ]

  @Test(arguments: samples) func textRoundTrips(command: SettingsCommand) throws {
    #expect(try Command.parse(command.text) == .settings(command))
    #expect(Command.settings(command).text == command.text)
  }

  @Test func onlyGetAndSettingsAreQueries() {
    for command in Self.samples {
      let reads: Bool
      switch command {
      case .get, .list: reads = true
      default: reads = false
      }
      #expect(Command.settings(command).isQuery == reads, "\(command.text)")
    }
  }

  @Test func keysAndValuesAreStoredInTheirCanonicalSpelling() throws {
    #expect(try Command.parse("set GAP 16.0") == .settings(.set(key: "gap", value: "16")))
    #expect(try Command.parse("SET tabsenabled on") == .settings(.set(key: "tabsEnabled", value: "true")))
    #expect(try Command.parse("set hotkeysEnabled 0") == .settings(.set(key: "hotkeysEnabled", value: "false")))
    #expect(try Command.parse("get MinimumUsableWidth") == .settings(.get(key: "minimumUsableWidth")))
    #expect(try Command.parse("reset Gap") == .settings(.reset(key: "gap")))
    #expect(try Command.parse("reset ALL") == .settings(.resetAll(everything: false)))
    #expect(try Command.parse("settings markdown") == .settings(.list(.markdown)))
    #expect(try Command.parse("settings --JSON") == .settings(.list(.json)))
    #expect(try Command.parse("Settings-Window") == .settings(.showWindow()))
  }

  @Test func aPaneOfTheWindowCanBeNamedHoweverItIsSpelt() throws {
    // A list names the pane it is in, by its label or its key.
    for text in ["apps", "Apps", "dont-arrange", "Don't Arrange", "Don’t arrange", "dontarrange", "excludedBundleIDs"] {
      #expect(try Command.parse("settings-window \(text)") == .settings(.showWindow(.section(.apps))), "\(text)")
    }
    #expect(try Command.parse("settings-window bindings") == .settings(.showWindow(.shortcuts)))
    #expect(try Command.parse("settings-window your shortcuts") == .settings(.showWindow(.shortcuts)))
    #expect(try Command.parse("settings-window Shortcuts") == .settings(.showWindow(.shortcuts)))
    #expect(try Command.parse("settings-window Close") == .settings(.closeWindow))
    #expect(try Command.parse("settings-window general") == .settings(.showWindow(.section(.general))))
    #expect(Command.settings(.showWindow(.section(.apps))).text == "settings-window apps")
    #expect(throws: Command.ParseError.self) { try Command.parse("settings-window colours") }
    // A section with nothing to show is no pane. (The names are unique, or a word would not name one.)
    for section in SettingsSection.allCases where section != .general {
      let isPane = SettingsPane(named: section.title) != nil
      #expect(isPane == !SettingsSchema.windowEntries(in: section).isEmpty, "\(section)")
    }
    #expect(Set(SettingsPane.all.map(\.word)).count == SettingsPane.all.count)
    #expect(SettingsPane.all.allSatisfy { SettingsPane(named: $0.word) == $0 && SettingsPane(named: $0.title) == $0 })
  }

  @Test func appsGoOnAndOffTheListsOfApps() throws {
    let added = Command.settings(.addApp(key: "excludedBundleIDs", app: "com.apple.Music"))
    // By key or by label, however that is spelt.
    for list in ["ExcludedBundleIDs", "dont-arrange", "Don't arrange", "don’t  arrange", "DONTARRANGE"] {
      #expect(try Command.parse("set \(list) add com.apple.Music") == added, "\(list)")
    }
    #expect(added.text == "set excludedBundleIDs add com.apple.Music")
    #expect(try Command.parse("set excludedbundleids remove Music") == .settings(.removeApp(key: "excludedBundleIDs", app: "Music")))
    #expect(try Command.parse("set shortcuts off in add Mail") == .settings(.addApp(key: "passThroughApps", app: "Mail")))
    #expect(try Command.parse("set pause for remove Mail") == .settings(.removeApp(key: "pauseForApps", app: "Mail")))
    #expect(refusal("set gap add com.apple.Music")?.hasPrefix("`gap` is not a list of apps; those are excludedBundleIDs, passThroughApps") == true)
    #expect(refusal("set rules add com.apple.Music")?.hasPrefix("`rules` is not a list of apps") == true)
    #expect(refusal("set excludedBundleIDs add")?.contains("which `set` cannot write") == true)
    #expect(refusal("set excludedBundleIDs add two words") != nil)
    #expect(refusal("set excludedBundleIDs add né.e") == "expected a bundle id like com.apple.Safari")
    #expect(refusal("set excluded add com.apple.Music")?.contains("did you mean `excludedBundleIDs`") == true)
    // One verb for changing a setting: these are no commands of their own.
    #expect(refusal("add excludedBundleIDs com.apple.Music")?.hasPrefix("unknown command `add`") == true)
    #expect(refusal("remove excludedBundleIDs com.apple.Music")?.hasPrefix("unknown command `remove`") == true)
    // A value that happens to have such a word in it is still a value.
    #expect(refusal("set frameRectangleModifier shift add cmd") != nil)
  }

  @Test func onlyASwitchCanBeToggled() throws {
    #expect(try Command.parse("set FocusRing Toggle") == .settings(.set(key: "focusRing", value: "toggle")))
    #expect(refusal("set gap toggle") == "`gap` needs a number from 0 to 100 pt, got `toggle`")
    #expect(refusal("set frameRectangleModifier toggle") != nil)
    #expect(refusal("set focusRing toggle twice") != nil)
  }

  @Test func aValueCanHaveSpaces() throws {
    let expected = Command.settings(.set(key: "frameRectangleModifier", value: "shift+cmd"))
    #expect(try Command.parse("set frameRectangleModifier shift + cmd") == expected)
    #expect(try Command.parse("set frameRectangleModifier  Command  +  Shift ") == expected)
  }

  @Test func urlPathsAndWordListsWork() throws {
    #expect(try Command.parse("set/gap/16") == .settings(.set(key: "gap", value: "16")))
    #expect(try Command.parse(words: ["set", "gap", "16"]) == .settings(.set(key: "gap", value: "16")))
    #expect(
      try Command.parse("bind/ctrl+opt+slash/dock/left")
        == .settings(.bind(chord: "ctrl+opt+/", command: "dock left")))
    #expect(
      try Command.parse(words: ["rule", "add", "com.apple.mail", "float", "title", "In box"])
        == .settings(.addRule(AppRule(app: "com.apple.mail", title: "In box", action: .float))))
  }

  @Test func mistakesAreCaughtWhenTheTextIsRead() {
    #expect(refusal("set gpa 16") == "unknown setting `gpa`; did you mean `gap`?")
    #expect(refusal("get gpa") == "unknown setting `gpa`; did you mean `gap`?")
    #expect(refusal("reset gpa") == "unknown setting `gpa`; did you mean `gap`?")
    #expect(refusal("set ga 16") != nil)  // the beginning of a key is not the key
    #expect(refusal("set gap 500") == "`gap` must be from 0 to 100 pt, got 500")
    #expect(refusal("set gap nan") == "`gap` needs a finite number from 0 to 100 pt, got nan")
    #expect(refusal("set gap") == "usage: set <key> <value> (`settings` lists the keys)")
    #expect(refusal("set") == "usage: set <key> <value> (`settings` lists the keys)")
    #expect(refusal("get") == "usage: get <key> (`settings` lists the keys)")
    #expect(refusal("get gap now") != nil)
    #expect(refusal("settings now") == "usage: settings [--json | --markdown]")
    #expect(refusal("settings-window now")?.hasPrefix("the settings window has no pane `now`; it has general, windows, ") == true)
    #expect(refusal("reset") == "usage: reset <key> | reset all | reset everything")
    #expect(refusal("reset gap tabsEnabled") != nil)
    #expect(refusal("set rules []")?.contains("`rule add`") == true)
  }

  // MARK: Shortcuts

  @Test func shortcutsAndTheirCommandsAreCheckedAndMadeCanonical() throws {
    #expect(
      try Command.parse("bind Opt+Ctrl+H go up")
        == .settings(.bind(chord: "ctrl+opt+h", command: "neighbor top")))
    #expect(
      try Command.parse("bind ⌃+⌥+space Show-All")
        == .settings(.bind(chord: "ctrl+opt+space", command: "show-all")))
    #expect(try Command.parse("unbind OPTION+CONTROL+D") == .settings(.unbind(chord: "ctrl+opt+d")))
    // As the menu and the documents write them.
    #expect(try Command.parse("bind ⌃⌥X dock left") == .settings(.bind(chord: "ctrl+opt+x", command: "dock left")))
    #expect(try Command.parse("unbind ⌃⌥⇧←") == .settings(.unbind(chord: "ctrl+opt+shift+left")))
    #expect(refusal("bind ctrl+opt+h teleport") == "unknown command `teleport`; try `help`")
    #expect(refusal("bind ctrl+opt+h set gpa 1") == "unknown setting `gpa`; did you mean `gap`?")
    #expect(
      refusal("bind hyper+x desktop")
        == "`hyper+x` is not a shortcut: unknown modifier `hyper`; use ctrl, opt, cmd or shift")
    #expect(refusal("unbind ctrl+") == "`ctrl+` is not a shortcut: missing key after the last +")
    #expect(refusal("bind ctrl+opt+h") == "usage: bind <shortcut> <command>, e.g. bind ctrl+opt+h dock left")
    #expect(refusal("unbind") == "usage: unbind <shortcut>, e.g. unbind ctrl+opt+g")
    #expect(refusal("unbind ctrl+opt+d now") != nil)
  }

  @Test func bindCannotBeNested() {
    #expect(refusal("bind f1 bind f2 desktop") == "a shortcut cannot run `bind`")
    #expect(refusal(String(repeating: "bind f1 ", count: 200_000) + "desktop") == "a shortcut cannot run `bind`")
    #expect(refusal("bind f1 unbind f2") == nil)
  }

  @Test func theFirstSeparatorInTheTextSeparatesAllOfIt() throws {
    // So the slash key, and a slash in a title, can be written in the form with spaces…
    #expect(
      try Command.parse("bind ctrl+opt+/ desktop") == .settings(.bind(chord: "ctrl+opt+/", command: "desktop")))
    #expect(try Command.parse("unbind ctrl+opt+/") == .settings(.unbind(chord: "ctrl+opt+/")))
    // …while everything that worked before still does.
    #expect(try Command.parse("dock/left") == .dock(nil, .left))
    #expect(try Command.parse("/dock/left/") == .dock(nil, .left))
    #expect(try Command.parse("  dock   left  ") == .dock(nil, .left))
    #expect(try Command.parse(" view/3 ") == .goToView(3))
    #expect(throws: Command.ParseError.self) { try Command.parse(" / ") }
  }

  // MARK: Rules

  @Test func ruleWordsKeepTheirCaseAndTheTitleTakesTheRestOfTheLine() throws {
    #expect(
      try Command.parse("rule add com.Apple.Mail DOCK Left TITLE Re: Hello  World / again")
        == .settings(
          .addRule(AppRule(app: "com.Apple.Mail", title: "Re: Hello World / again", action: .dock(.left)))))
    #expect(
      try Command.parse("rule change 2 com.a dock beside com.B up title x")
        == .settings(
          .changeRule(2, AppRule(app: "com.a", title: "x", action: .dockBeside(bundleID: "com.B", .top)))))
  }

  @Test func whiteSpaceInATitleComesDownToSingleSpaces() throws {
    let expected = Command.settings(.addRule(AppRule(app: "com.a", title: "In box", action: .float)))
    #expect(try Command.parse(words: ["rule", "add", "com.a", "float", "title", " In\t", "\n", "box "]) == expected)
    #expect(try Command.parse("rule add com.a float title In\tbox") == expected)
    #expect(throws: Command.ParseError.self) { try Command.parse(words: ["rule", "add", "com.a", "float", "title", " \n"]) }
  }

  @Test func addCanBeLeftOut() throws {
    #expect(
      try Command.parse("rule com.example.terminal dock right")
        == .settings(.addRule(AppRule(app: "com.example.terminal", action: .dock(.right)))))
  }

  @Test func badRulesAreRefusedWithAReason() {
    #expect(refusal("rule")?.hasPrefix("usage: rule add <bundle id> <action>") == true)
    #expect(refusal("rule add")?.hasPrefix("usage: rule add") == true)
    #expect(refusal("rule add com.apple.mail")?.hasPrefix("usage: rule add") == true)
    #expect(refusal("rule add com.apple.mail hover")?.hasPrefix("unknown action `hover`") == true)
    #expect(refusal("rule add com.apple.mail dock sideways")?.hasPrefix("unknown edge `sideways`") == true)
    #expect(refusal("rule add com.apple.mail dock beside com.apple.Notes")?.hasPrefix("unknown action") == true)
    #expect(
      refusal("rule add com.apple.mail float Inbox")?.hasPrefix(
        "expected `title <text>` after the action, got `Inbox`") == true)
    #expect(refusal("rule add com.apple.mail float title")?.hasPrefix("expected `title <text>`") == true)
    for text in [
      "rule remove", "rule remove 0", "rule remove -1", "rule remove x", "rule remove 1.5", "rule move 1",
      "rule move 0 1",
      "rule move 1 0", "rule change x com.a float", "rule remove 99999999999999999999",
    ] {
      #expect(refusal(text)?.contains("rule") == true, "\(text)")
    }
    // Bundle ids are held to what `exclude` accepts.
    for text in ["rule add com.a;b float", "rule add «app» float", "rule add com.a dock beside com/b left", "rule change 1 a\u{7}b float"] {
      #expect(refusal(text) == "expected a bundle id like com.apple.Safari", "\(text)")
    }
    #expect(refusal("rule remove 1 2") != nil)
    #expect(refusal("rule move 1 2 3") != nil)
  }

  /// What is refused while settings.json cannot be read, for a menu that greys it out.
  @Test func whatWritesToSettingsJsonSaysSo() throws {
    for text in [
      "exclude com.apple.mail", "exclude", "include com.apple.mail", "pass-through com.apple.mail", "pass-through com.apple.mail off",
      "toggle-auto-dock", "set gap 12", "set focusRing toggle", "reset gap", "reset all", "bind ctrl+opt+k zoom", "unbind ctrl+opt+k",
      "rule add com.apple.mail float", "rule remove 1",
    ] {
      #expect(try Command.parse(text).changesSettings, "\(text)")
    }
    for text in [
      // They read, or open a window.
      "get gap", "settings", "settings-window", "reload-settings",
      // It replaces the file, which is a way out of the mistake.
      "reset everything",
      // Kept elsewhere than in settings.json, or nowhere.
      "launch-at-login on", "save-view 1", "name Work", "hold", "pause", "minimap", "arrange", "float-all", "undo", "quit",
    ] {
      #expect(try !Command.parse(text).changesSettings, "\(text)")
    }
  }

  @Test func helpMentionsEveryVerb() {
    for verb in [
      "settings-window", "settings [--json]", "set <key>", "get <key>", "reset <key>", "bind <shortcut>", "unbind <shortcut>", "rule add",
      "rule change",
      "rule remove", "rule move",
    ] {
      #expect(Command.helpText.contains(verb), "\(verb)")
    }
  }
}
