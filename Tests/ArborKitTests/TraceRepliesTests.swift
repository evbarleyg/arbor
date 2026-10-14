import ArborCore
import ArborKit
import ArborTesting
import CoreGraphics
import Foundation
import Testing

/// A reply is free text that any of a hundred commands may write, and it quotes what people typed, named and wrote into their files. A trace
/// records replies. They become lines in one place (`TraceRecorder.scrubbed`), by one rule (docs/TRACES.md, "Replies").
@MainActor
@Suite struct TraceRepliesTests {
  /// Says of a command what a test wants said.
  private final class Words: TraceWordsSource {
    var shown: [String: String] = [:]
    var parts: [String: [String]] = [:]
    var unfit: [String: String] = [:]
    var names: Set<String> = []
    func wordsForTrace(inCommand text: String, from source: CommandSource?) -> (text: String, names: Set<String>, sameReply: Bool) {
      (shown[text] ?? text, names, true)
    }
    func asItMayBeLogged(_ text: String) -> String { unfit.reduce(text) { $0.replacingOccurrences(of: $1.key, with: $1.value) } }
    func partsOfTitles(inCommand text: String) -> [String] { parts[text] ?? [] }
  }

  private static let header = TraceHeader(
    name: "x", arbor: "x", os: "x", recorded: "", displays: [TraceDisplay(FakeWindowSystem.standardDisplay)], windows: [], settings: Settings(), workspaces: [:], focused: nil, cursor: .zero,
    mouseDown: false, thinning: 0.05)

  /// The `command` and `done` lines of commands that get these replies.
  private func lines(_ words: Words, settings: Settings = Settings(), _ commands: [(text: String, reply: String)]) throws -> [String] {
    let recorder = TraceRecorder()
    let sink = MemoryTraceSink(location: "memory")
    recorder.clock = { 0 }
    recorder.openSink = { _ in sink }
    recorder.words = words
    try recorder.begin(name: "x", fileName: "x") { titles in
      var header = Self.header
      header.settings = titles.sanitised(settings)
      return header
    }
    _ = recorder.window(WindowSnapshot(id: WindowID(1), pid: 1, bundleID: "com.apple.mail", appName: "Mail", title: "Payslip for March", frame: .zero))
    for command in commands {
      recorder.stimulus(.command(command.text)) { recorder.record(.done(command.text, ok: true, message: command.reply)) }
    }
    recorder.end(reason: "x")
    return try Trace(text: sink.lines.joined(separator: "\n")).entries.compactMap { entry in
      switch entry.line {
      case .command(let text, _): "> " + text
      case .done(_, _, let message): message
      default: nil
      }
    }
  }

  /// Whoever hides a word in a command need not think of its reply, nor know which replies quote it.
  @Test func aWordThatIsNotShownInACommandIsNotShownInItsReply() throws {
    let words = Words()
    words.shown = ["bind ctrl+opt+j go Blackmail": "bind ctrl+opt+j go …", "note Zebra crossing": "note …", "dock 7 left": "dock 7 left"]
    let got = try lines(words, [
        ("bind ctrl+opt+j go Blackmail", "ctrl+opt+j runs `go blackmail`; BLACKMAIL is no space yet, nor is Blackmailer"),
        ("note Zebra crossing", "noted “Zebra crossing”, the second about a zebra"), ("dock 7 left", "docked w7 on the left"),
      ])
    #expect(got == [
        "> bind ctrl+opt+j go …", "≈ ctrl+opt+j runs `go …`; … is no space yet, nor is Blackmailer",
        "> note …", "≈ noted “… …”, the second about a …",
        // Nothing hidden, nothing marked.
        "> dock 7 left", "docked w7 on the left",
      ])
  }

  /// Hidden from one command, not from the next, which may say the word for reasons of its own.
  @Test func whatACommandHidesIsForgottenWithIt() throws {
    let words = Words()
    words.shown = ["note left": "note …"]
    let got = try lines(words, [("note left", "noted left"), ("dock 7 left", "docked w7 on the left")])
    #expect(got == ["> note …", "≈ noted …", "> dock 7 left", "docked w7 on the left"])
  }

  /// `layout Mail~pays | Notes` is written `layout 1 | Notes`. The app's name is in the trace anyway, and the reply may keep it.
  @Test func anAppsNameIsNotHiddenForBeingReplacedByANumber() throws {
    let words = Words()
    words.shown = ["layout Mail~pays | Notes": "layout 1 | Notes"]
    let got = try lines(words, [("layout Mail~pays | Notes", "arranged Mail and Notes; nothing pays")])
    #expect(got == ["> layout 1 | Notes", "≈ arranged Mail and Notes; nothing …"])
  }

  /// A part of a title has a mark, so that rules match in a replay. The reply has it too, and so comes out the same there: no `≈`.
  @Test func thePartsOfTitlesThatRulesGoByAreMarksInRepliesToo() throws {
    var settings = Settings()
    settings.rules = [AppRule(app: "com.apple.mail", title: "Payslip", action: .float)]
    settings.holdStillFor = ["us.zoom.xos Board meeting"]
    let words = Words()
    words.parts = ["rule add com.a float title Redundancy plan": ["Redundancy plan"]]
    let got = try lines(words, settings: settings, [
        ("rule remove 1", "removed rule 1: com.apple.mail, title contains \"Payslip\" → float"),
        ("hold", "holding still for us.zoom.xos BOARD MEETING"),
        ("rule add com.a float title Redundancy plan", "rule 2: com.a, title contains \"Redundancy plan\" → float"),
        // A whole title first, which contains a part; and no part is looked for inside a token.
        ("status", "Payslip for March is in front; title[1][p1] it is; a payslip, not payslips"),
      ])
    #expect(got == [
        "> rule remove 1", "removed rule 1: com.apple.mail, title contains \"[p1]\" → float",
        "> hold", "holding still for us.zoom.xos [h1]",
        "> rule add com.a float title [p2]", "rule 2: com.a, title contains \"[p2]\" → float",
        "> status", "title[1][p1] is in front; title[1][p1] it is; a [p1], not payslips",
      ])
  }

  /// What is whole goes before its parts, names as titles do: or "Sam's iPad", which an entry of `displays` goes by as "ipad", would be
  /// left as "Sam's [d1]".
  @Test func aNameThatContainsAPartOfATitleGoesAsAWhole() throws {
    var settings = Settings()
    settings.rules = [AppRule(app: "com.apple.mail", title: "payslip", action: .float)]
    let words = Words()
    words.names = ["Sam's payslip run"]
    let got = try lines(words, settings: settings, [("go Sam's payslip run", "framed Sam's payslip run (n4); a payslip")])
    #expect(got == ["> go name-1", "framed name-1 (n4); a [p1]"])
  }

  @Test func whatIsNotFitForTheLogIsNotFitForATrace() throws {
    let words = Words()
    words.unfit = ["line 1, column 49: found `Redundancies`": "line 1, column 49"]
    let got = try lines(words, [("reload-settings", "cannot be read: line 1, column 49: found `Redundancies`")])
    #expect(got == ["> reload-settings", "≈ cannot be read: line 1, column 49"])
  }

  /// A rule and an entry somebody made before the recording, met by real commands. The part of a title is known from the settings, so
  /// it is a mark wherever it stands, in the command as well.
  @Test func realRepliesThatQuoteARulesTitleReplayTheSame() throws {
    var settings = Settings()
    settings.rules = [AppRule(app: "com.apple.mail", title: "Payslip", action: .float), AppRule(app: "com.apple.notes", action: .ignore)]
    settings.holdStillFor = ["com.apple.mail Boardroom"]
    let h = Harness(settings: settings)
    h.system.open(app: "Mail", title: "Your payslip for March")
    h.start()
    h.run("trace on replies")
    var replies: [String] = []
    for text in [
      "rule change 1 com.apple.mail dock left title Payslip", "rule move 1 2", "get rules", "get holdStillFor", "rules", "rule add com.apple.mail pin title PAYSLIP",
      "reset holdStillFor", "rule remove 2",
    ] {
      replies.append(h.run(text).message)
    }
    h.run("trace off")
    #expect(replies.filter { $0.contains("title contains \"Payslip\"") || $0.contains("title contains \"PAYSLIP\"") }.count == 2, "the premise: \(replies)")
    let text = h.lastTrace ?? ""
    for secret in ["Payslip", "payslip", "PAYSLIP", "March", "Boardroom", "boardroom"] { #expect(!text.contains(secret), "\(secret)") }
    let trace = try Trace(text: text)
    let lines = trace.entries.compactMap { entry -> String? in
      switch entry.line {
      case .command(let text, _) where text.contains("title"): "> " + text
      case .done(_, _, let message) where message.contains("title"): String(message.prefix { $0 != ";" })
      default: nil
      }
    }
    #expect(lines == [
      "> rule change 1 com.apple.mail dock left title [p1]", "rule 1: com.apple.mail, title contains \"[p1]\" → dock left",
      "> rule add com.apple.mail pin title [p1]", "rule 3: com.apple.mail, title contains \"[p1]\" → pin",
    ])
    #expect(TraceReplayer(trace, mode: .strict).run().problems == [])
  }

  /// A part of a title can be a word of the app's bundle id, which is no title and is in the trace anyway. Cut out of it, the rule would be
  /// for an app that does not exist, and match nothing in a replay.
  @Test func aPartOfATitleIsNotCutOutOfABundleID() throws {
    let h = Harness()
    h.start()
    h.run("trace on dots")
    #expect(h.run("rule add com.apple.mail dock left title Mail").ok)
    let late = h.system.open(app: "Mail", bundleID: "com.apple.mail", title: "All mail, 3 unread")
    h.scheduler.runPending()
    h.run("trace off")
    #expect(h.workspace.isDocked(late), "the premise: the rule matched")
    let text = h.lastTrace ?? ""
    #expect(!text.contains("unread"))
    let trace = try Trace(text: text)
    let commands = trace.entries.compactMap { entry -> String? in
      if case .command(let text, _) = entry.line { text } else { nil }
    }
    #expect(commands.first == "rule add com.apple.mail dock left title [p1]")
    let replayer = TraceReplayer(trace, mode: .strict)
    #expect(replayer.run().problems == [])
    #expect(replayer.harness.controller.settings.rules.map(\.app) == ["com.apple.mail"])
    #expect(replayer.harness.workspace.isDocked(late))
  }

  /// Found by F21's author. Shortcuts somebody made before the recording are in the header, and in a `settings` line whenever settings
  /// change. A replay reads them, and `bindings` counts those it cannot read.
  @Test func shortcutsThatChangeSettingsLoseTheirWordsAndCanStillBeRead() throws {
    var settings = Settings()
    settings.bindings = [
      "ctrl+opt+cmd+5": "find lawyers", "ctrl+opt+cmd+6": "rule change 1 com.a pin title Blackmail", "ctrl+opt+cmd+7": "rule add * float title Blackmail",
      "ctrl+opt+cmd+8": "layout @1 --open Mail~Embezzlement | (Notes~gambling* / Desktop):0.3", "ctrl+opt+cmd+9": "bind ctrl+opt+cmd+1 go Redundancies",
      "ctrl+opt+cmd+0": "bind ctrl+opt+cmd+2 bind ctrl+opt+cmd+3 rule add * float title Chemotherapy", "ctrl+opt+cmd+4": "bind ctrl+opt+cmd+1 goo Alibi",
    ]
    let h = Harness(settings: settings)
    h.system.open(app: "Safari")
    h.start()
    h.run("trace on shortcuts")
    #expect(h.run("bindings").ok && h.run("set gap 20").ok)
    h.run("trace off")
    let text = h.lastTrace ?? ""
    for secret in ["lawyers", "Blackmail", "Embezzlement", "gambling", "Redundancies", "Chemotherapy", "Alibi"] { #expect(!text.contains(secret), "\(secret)") }
    let trace = try Trace(text: text)
    let expected = [
      // Neither is a command: a shortcut that makes a shortcut that makes a shortcut, and a slip of the keyboard. The verb is kept.
      "ctrl+opt+cmd+0": "bind …", "ctrl+opt+cmd+4": "bind …",
      "ctrl+opt+cmd+5": "find …", "ctrl+opt+cmd+6": "rule change 1 com.a pin title [p1]", "ctrl+opt+cmd+7": "rule add * float title [p1]",
      "ctrl+opt+cmd+8": "layout @1 --open Mail | (Notes* / Desktop):0.3", "ctrl+opt+cmd+9": "bind ctrl+opt+cmd+1 go name-1",
    ]
    #expect(trace.header.settings.bindings.compactMapValues { $0 } == expected)
    let later = trace.entries.compactMap { entry -> [String: String]? in
      if case .settings(let settings) = entry.line { settings.bindings.compactMapValues { $0 } } else { nil }
    }
    #expect(later == [expected])
    // What was a command is one still, and what was none is none, so a replay reads as many as were read.
    for (chord, command) in expected {
      #expect(((try? Command.parse(command)) != nil) == ((try? Command.parse(settings.bindings[chord]!!)) != nil), "\(command)")
    }
    #expect(TraceReplayer(trace, mode: .strict).run().problems == [])
  }
}
