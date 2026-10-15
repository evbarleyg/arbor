import ArborCore
import ArborIPC
import ArborKit
import ArborTesting
import Foundation
import Testing

/// Window titles and the names people give are never logged. These are the roads by which what was typed could get there.
@Suite struct LogPrivacyTests {
  /// A shortcut in settings.json that cannot be read is logged at every start. The reason quotes the line, and the line can hold part of
  /// a window title or a name a person gave.
  @Test func aShortcutThatCannotBeReadLeavesNoPrivateWordInTheLog() {
    var settings = Settings()
    settings.bindings = [
      "ctrl+opt+1": "layout Safari~Zebra | |", "ctrl+opt+2": "layout Safari~Zebra --zebra | Mail", "ctrl+opt+3": "rule add com.x nonsense title Zebra",
      "ctrl+opt+4": "bind ctrl+opt+9 layout Safari~Zebra | |", "ctrl+opt+5": "/layout/Safari~Zebra | |", "ctrl+opt+6": "LAYOUT Safari~Zebra (",
      "ctrl+opt+7": "zom", "ctrl+opt+8": "bindings", "zebra+1": "home",
    ]
    let problems = KeyBindings.effective(settings: settings).problems
    #expect(problems.count == 9, "\(problems)")
    // This is the road: a person is told everything, in `bindings`.
    #expect(problems.filter { $0.localizedCaseInsensitiveContains("zebra") }.count >= 5, "\(problems)")
    let logged = KeyBindings.problemsForTheLog(problems, settings: settings)
    #expect(logged.count == 9)
    for line in logged { #expect(!line.localizedCaseInsensitiveContains("zebra"), "\(line)") }
    for (shortcut, verb) in [("1", "layout"), ("2", "layout"), ("3", "rule"), ("4", "bind"), ("5", "layout"), ("6", "layout"), ("8", "bindings")] {
      #expect(logged.contains("ctrl+opt+\(shortcut), for `\(verb)`; `bindings` says why"), "\(logged)")
    }
    // A slip is somebody's word too, where a command was wanted and where a key was.
    #expect(logged.contains("ctrl+opt+7, for what is no command; `bindings` says why"), "\(logged)")
    #expect(logged.contains("keys that cannot be read, for `home`; `bindings` says why"), "\(logged)")
    // Two entries that mean one key: the reason is of Arbor's own making, and names the keys in Arbor's spelling, which is nobody's entry.
    settings.bindings = ["opt+ctrl+us:z": "home", "ctrl+opt+z": "back"]
    let twice = KeyBindings.problemsForTheLog(KeyBindings.effective(settings: settings).problems, settings: settings)
    #expect(twice.count == 1 && twice[0].hasPrefix("ctrl+opt+"), "\(twice)")
  }

  /// Nothing a person typed reaches the log unless it is one of Arbor's own words: not a wrong word where one of Arbor's was wanted, not
  /// a number, not what stands for an app. The log says where; `doctor` says what, to whoever sits there.
  @Test func whatIsWrongInSettingsIsLoggedByItsPlace() throws {
    let settings = try Settings.read(
      """
      {"tileStyle": "zebra", "gap": 31337, "newWindows": ["zebra"], "focusRingColour": "zebra", "stepInToward": "zebra", "zebraKey": "zebra",
       "rules": [{"app": "com.example.a", "action": "float"}, {"app": "zebra", "action": "zebra"}, "zebra", {"app": "com.example.zebra"}],
       "displays": [{"match": "zebra", "gap": "zebra"}, {"match": "main", "gap": 31337}, "zebra"]}
      """)
    let told = settings.valueProblems + settings.skippedRules + settings.skippedDisplays
    #expect(told.filter { $0.contains("zebra") }.count >= 6, "a person is told everything: \(told)")
    #expect(told.contains { $0.contains("31337") }, "\(told)")
    let logged = settings.problemsForTheLog
    #expect(logged.count == told.count, "\(logged)")
    for line in logged { #expect(!line.contains("zebra") && !line.contains("31337"), "\(line)") }
    for place in ["tileStyle", "gap", "newWindows", "focusRingColour", "entry 2 of rules", "entry 3 of rules", "entry 4 of rules"] {
      #expect(logged.contains("\(place) cannot be used as written; `doctor` says why"), "\(place): \(logged)")
    }
    #expect(logged.contains("entry 1 of displays cannot be used as written; `displays` says why"), "\(logged)")
    var whole = try Settings.read(#"{"rules": "zebra"}"#)
    #expect(whole.problemsForTheLog == ["rules cannot be used as written; `doctor` says why"])
    whole = try Settings.read(#"{"displays": "zebra"}"#)
    #expect(whole.problemsForTheLog == ["displays cannot be used as written; `displays` says why"])
    whole = try Settings.read("{}")
    #expect(whole.problemsForTheLog.isEmpty)
  }

  /// What has been logged since `mark` was. The real log file, which every test writes to and which is never emptied.
  private func logged(since mark: String) throws -> String {
    let log =
      ((try? String(contentsOf: ArborPaths.logFile.appendingPathExtension("1"), encoding: .utf8)) ?? "")
      + (try String(contentsOf: ArborPaths.logFile, encoding: .utf8))
    return String(log[(try #require(log.range(of: mark, options: .backwards))).upperBound...])
  }

  /// A URL comes from anywhere, and a refused one is logged.
  @MainActor @Test func ofAURLThatIsRefusedTheLogHoldsOnlyArborsOwnWords() throws {
    let h = Harness()
    h.start()
    let mark = "mark \(UUID().uuidString)"
    Log.info(mark)
    for url in [
      "arbor://okapiword/left", "arbor://dock/okapiword", "arbor://dock/101/okapiword", "arbor://set/gap/okapiword", "arbor://set/gap/20",
      "arbor://OKAPIWORD", "arbor://zoom/okapiword?okapiword#okapiword", "arbor://layout/@okapiword%20Safari", "arbor://unname/okapiword",
      "arbor://the/okapiword",
    ] {
      guard case .failure = h.controller.admit(url: url) else {
        // Admitted is not run; what running it logs is the next test's.
        continue
      }
    }
    let log = try logged(since: mark)
    #expect(!log.localizedCaseInsensitiveContains("okapiword"))
    #expect(log.contains("refused a URL, arbor://…: it cannot be read as a command"))
    #expect(log.contains("refused a URL, arbor://dock…: it cannot be read as a command"))
    #expect(!log.contains("arbor://the"), "a word of `help`'s prose is no command")
    // What Arbor says of a command it did read is made of its own words.
    #expect(log.contains("refused a URL, arbor://set…: `set` is not accepted from URLs"), "the reason stays where it quotes nothing")
  }

  /// A word where a display's number was wanted: the command can be read, so it is run, refused and logged.
  @MainActor @Test func aWordThatIsNoDisplayReachesNeitherTheLogNorATrace() throws {
    var settings = Settings()
    settings.bindings = ["ctrl+opt+j": "layout @okapiword Safari"]
    let h = Harness(settings: settings)
    h.system.open(app: "Safari")
    h.start()
    let mark = "mark \(UUID().uuidString)"
    Log.info(mark)
    #expect(h.run("layout @okapiword Safari").message.contains("okapiword"), "whoever asked is told")
    h.run("bind ctrl+opt+k layout @okapiword Safari")
    #expect(!(try logged(since: mark)).localizedCaseInsensitiveContains("okapiword"))
    let words = h.controller.wordsForTrace(inCommand: "layout @okapiword Safari", from: nil)
    #expect(words.names.contains("okapiword"), "so it gets a token, in the command and in the reply")
    // An id from `state` is no secret, and must mean the same display in a replay: it becomes the number.
    #expect(h.controller.wordsForTrace(inCommand: "layout @main Safari", from: nil).text == "layout @1 Safari")
  }

  /// A person's own shortcut that macOS uses as well is logged with its command.
  @MainActor @Test func aShortcutThatIsMacOSsAsWellIsLoggedWithoutItsWords() throws {
    var settings = Settings()
    settings.bindings = ["ctrl+up": "go Okapiword", "ctrl+space": "layout Safari~Okapiword | Mail"]
    let h = Harness(settings: settings)
    h.controller.systemShortcuts = {
      SystemShortcuts(shortcuts: [SystemShortcuts.Shortcut([.control], .up), SystemShortcuts.Shortcut([.control], .space)], inputSources: 2)
    }
    h.start()
    #expect(h.controller.systemShortcutClashes.filter { $0.sentence.contains("Okapiword") }.count == 2, "`bindings` tells all")
    let mark = "mark \(UUID().uuidString)"
    Log.info(mark)
    h.controller.logSystemShortcutClashes()
    let log = try logged(since: mark)
    #expect(log.contains("shortcuts: ⌃↑ (`go ‹name›`)"), "\(log)")
    #expect(!log.localizedCaseInsensitiveContains("okapiword"))
  }

  /// What counts as one of Arbor's own first words: the commands `help` lists, each of them, and no word of its prose.
  @Test func arborsOwnFirstWords() {
    for verb in Command.documentedVerbs { #expect(Command.isVerb(verb), "\(verb)") }
    for verb in ["state", "unname", "quit", "in", "redo", "resume", "reload-settings", "LAYOUT", "Go"] { #expect(Command.isVerb(verb), "\(verb)") }
    for word in ["the", "this", "window", "arbor", "edge", "space", "frame", "zom", "", "…"] { #expect(!Command.isVerb(word), "\(word)") }
  }

  /// An account's name is a person's name as often as not, and every path in the home folder begins with it.
  @Test(arguments: [
    ("home /Users/jo/Library/Application Support/Arbor", "home ~/Library/Application Support/Arbor"),
    ("/Users/jo", "~"), ("\"/Users/jo\"", "\"~\""), ("at /Users/jo: gone", "at ~: gone"), ("(/Users/jo/a, /Users/al/b)", "(~/a, ~/b)"),
    ("file:///Users/jo/x.json", "file://~/x.json"), ("“/Users/jo/x” couldn’t be opened", "“~/x” couldn’t be opened"),
    // Anybody's, not only whoever runs Arbor.
    ("/Users/jojo/x", "~/x"),
    // Nobody's.
    ("/Users/Shared/x", "/Users/Shared/x"), ("/Users/", "/Users/"), ("/Users", "/Users"),
    // A folder like any other.
    ("/opt/Users/jo/x", "/opt/Users/jo/x"), ("x/Users/jo", "x/Users/jo"),
    ("dock 101 left", "dock 101 left"), ("a/b", "a/b"), ("", ""), ("/", "/"), ("arbor://dock/left", "arbor://dock/left"),
  ]) func aHomeFolderIsWrittenAsATilde(text: String, written: String) {
    #expect(ArborPaths.withoutHomeFolder(text, homes: ["/Users/jo"]) == written)
  }

  /// A home folder need not be under `/Users`.
  @Test func aHomeFolderThatIsSomewhereElse() {
    #expect(ArborPaths.withoutHomeFolder("in /root/x and /root, not /rootfs/x or /var/root/x", homes: ["/root"]) == "in ~/x and ~, not /rootfs/x or /var/root/x")
    #expect(ArborPaths.withoutHomeFolder("/tmp/x/home/y and /tmp/x", homes: ["/tmp/x/home", "/tmp/x"]) == "~/y and ~", "two names for it: the longer first")
    #expect(ArborPaths.withoutHomeFolder("/a/b", homes: []) == "/a/b")
    #expect(ArborPaths.homeFolders.allSatisfy { $0.count > 1 && $0.hasPrefix("/") && !$0.hasSuffix("/") }, "a home that is the root of everything says nothing")
  }

  /// In the one place every line goes through, so that it holds for lines nobody has written yet, and for the words of macOS's errors.
  @Test func noLineOfTheLogHoldsTheHomeFolder() throws {
    let mark = "mark \(UUID().uuidString)"
    Log.info(mark)
    Log.error("could not save state: “\(NSHomeDirectory())/Library/x.json” and /Users/okapiword/y")
    let log = try logged(since: mark)
    #expect(log.contains("could not save state: “~/Library/x.json” and ~/y"), "\(log)")
  }

  /// What `arborctl` answers when Arbor is not running is the line most often pasted into an issue.
  @Test func whatArborctlSaysOfTheSocketHoldsNoHomeFolder() {
    #expect(throws: ControlClient.Failure.self) { try ControlClient.send("status", socketPath: "/Users/okapiword/none/arbor.sock") }
    do {
      _ = try ControlClient.send("status", socketPath: "/Users/okapiword/none/arbor.sock")
    } catch {
      #expect("\(error)".contains("no control socket at ~/none/arbor.sock"), "\(error)")
    }
  }

  /// One list, for URLs that are refused and for shortcuts that cannot be read.
  @Test func theCommandsThatCanHoldPrivateWords() {
    for verb in ["rule", "bind", "layout", "name", "unname", "go", "Layout", "GO"] { #expect(Command.mayHoldPrivateWords(verb: verb), "\(verb)") }
    for verb in ["zoom", "dock", "summon", "bindings", "", "layouts"] { #expect(!Command.mayHoldPrivateWords(verb: verb), "\(verb)") }
  }
}
