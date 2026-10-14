import ArborCore
@testable import ArborKit
import ArborTesting
import CoreGraphics
import Foundation
import Testing

/// The words people type into commands never reach a trace, and the commands still replay (docs/TRACES.md, "What is never in a
/// trace"). Titles are replaced wherever they turn up whole; these are the words that are not whole titles.
@Suite @MainActor struct TraceWordsTests {
  /// `[Safari | Desktop | Notes / Mail]`, with titles nobody else should read, and a shortcut somebody made.
  private func desk(recording: Bool = true) -> (Harness, safari: WindowID, other: WindowID, notes: WindowID, mail: WindowID) {
    var settings = Settings()
    settings.bindings = ["ctrl+opt+m": "go Acme merger", "ctrl+opt+l": "layout Mail~payslip | Notes"]
    let h = Harness(settings: settings)
    let safari = h.system.open(app: "Safari", title: "My diagnosis - Search")
    let other = h.system.open(app: "Safari", title: "Divorce lawyers near me")
    let notes = h.system.open(app: "Notes", title: "Shopping")
    let mail = h.system.open(app: "Mail", title: "Your payslip for October")
    h.start()
    h.run("dock \(safari.rawValue) left")
    h.run("dock \(notes.rawValue) right")
    h.run("dock \(mail.rawValue) beside \(notes.rawValue) bottom")
    // A name from before the recording: it is in the header's arrangement.
    h.run("zoom \(safari.rawValue)")
    h.run("name Acme merger")
    h.run("show-all")
    if recording { h.run("trace on words") }
    return (h, safari, other, notes, mail)
  }

  /// Everything that can be done with names and with parts of titles. Returns the replies.
  @discardableResult
  private func session(_ h: Harness, notes: WindowID) -> [String] {
    var replies: [String] = []
    func run(_ text: String) { replies.append(h.run(text).message) }
    run("zoom \(notes.rawValue)")
    run("name Chemotherapy plan")
    run("show-all")
    run("go acme")  // the beginning of a name
    run("go CHEMOTHERAPY PLAN")  // other capitals
    run("go embezzlement")  // no such name; the reply quotes it
    run("name Acme lawsuit")  // now two names begin alike
    run("go acme")  // and the reply lists them
    run("spaces")
    run("show-all")
    replies.append(h.key("ctrl+opt+m")?.message ?? "")  // the shortcut
    run("unname acme MERGER")
    run("unname")
    run("show-all")
    // Parts of titles: found; not found, so that the app's other window does; of an app that is not open; and a slot without any.
    run("layout Safari~lawyers | (Mail~pays / Notes~gambling) | Xcode~blackmail | Safari | Desktop")
    replies.append(h.key("ctrl+opt+l")?.message ?? "")
    run("layout Safari* | Notes")
    return replies
  }

  static let secrets = [
    "Acme", "acme", "merger", "MERGER", "lawsuit", "Chemo", "CHEMO", "plan", "PLAN", "embezzle", "lawyers", "pays", "gambling", "blackmail", "payslip",
    "diagnosis", "Divorce", "October", "Shopping",
  ]

  @Test func namesAndPartsOfTitlesNeverReachATraceAndTheCommandsStillReplay() throws {
    let (h, safari, other, notes, mail) = desk()
    let replies = session(h, notes: notes)
    h.run("trace off")
    // The premise: all of it worked, and the replies do hold the words.
    #expect(replies.contains { $0.contains("Acme merger") } && replies.contains { $0.contains("embezzlement") })
    #expect(replies.contains { $0.contains("Acme lawsuit") && $0.contains("Acme merger") }, "two names fit")

    let text = h.lastTrace ?? ""
    for secret in Self.secrets { #expect(!text.contains(secret), "\(secret)") }

    let trace = try Trace(text: text)
    #expect(trace.header.workspaces.values.flatMap(\.names.keys) == ["name-1"])
    #expect(trace.header.settings.bindings == ["ctrl+opt+m": "go name-1", "ctrl+opt+l": "layout Mail | Notes"])
    let commands = trace.entries.compactMap { entry -> String? in
      if case .command(let text, _) = entry.line { text } else { nil }
    }
    #expect(commands.contains("name name-2"))
    #expect(commands.filter { $0 == "go name-1" }.count == 2, "the beginning of the name, and the shortcut: \(commands)")
    #expect(commands.contains("go name-2"), "whatever the capitals")
    #expect(commands.contains("unname name-1"))
    // By number where a title was asked for and a window found; the app alone where none was; as written where none was asked for.
    #expect(
      commands.contains("layout \(other.rawValue) | (\(mail.rawValue) / \(notes.rawValue)) | Xcode | Safari | Desktop"), "\(commands)")
    #expect(commands.contains("layout \(mail.rawValue) | Notes"))
    #expect(commands.contains("layout Safari* | Notes"))
    _ = safari

    let replayer = TraceReplayer(trace, mode: .strict)
    #expect(replayer.run().problems == [])
    // Where several names fit, the reply lists them, and tokens all begin alike. The trace says that a replay will say something else.
    let about = trace.entries.compactMap { entry -> String? in
      if case .done(_, false, let message) = entry.line, message.hasPrefix(TraceLine.aboutMark) { message } else { nil }
    }
    #expect(about == ["≈ name-5 could be name-4 or name-1; type more of the name"])
    let replayed = replayer.harness
    for (display, workspace) in h.controller.workspaces {
      let twin = try #require(replayed.controller.workspaces[display])
      #expect(twin.tree == workspace.tree && twin.camera == workspace.camera && twin.floating == workspace.floating)
      #expect(Set(twin.names.values) == Set(workspace.names.values), "the same spaces have names")
    }
    for id in h.system.windows.keys { #expect(replayed.frame(id) == h.frame(id)) }
  }

  /// F27 finds named spaces too, and what stands for one that holds no app is its name.
  @Test func findingANamedSpaceLeavesNoNameInATraceAndStillFindsIt() throws {
    let (h, safari, _, _, _) = desk(recording: false)
    h.run("desktop")
    h.run("name Blackmail stash")
    h.run("zoom \(safari.rawValue)")
    h.run("trace on words")
    var replies: [String] = []
    for text in ["find blackm", "show-all", "find Blackmail stash", "show-all", "find acme mer", "show-all", "find Acme merger"] {
      replies.append(h.run(text).message)
    }
    h.run("trace off")
    #expect(replies.contains { $0.contains("Blackmail stash") } && replies.contains { $0.contains("Acme merger") }, "\(replies)")
    let text = h.lastTrace ?? ""
    for secret in Self.secrets + ["Blackmail", "blackm", "stash"] { #expect(!text.contains(secret), "\(secret)") }
    let trace = try Trace(text: text)
    let commands = trace.entries.compactMap { entry -> String? in
      if case .command(let text, _) = entry.line { text } else { nil }
    }
    #expect(commands.filter { $0 == "find name-1" }.count == 2 && commands.filter { $0 == "find name-2" }.count == 2, "\(commands)")
    let replayer = TraceReplayer(trace, mode: .strict)
    #expect(replayer.run().problems == [])
    #expect(replayer.harness.workspace.camera == h.workspace.camera)
  }

  /// F19: what `undo` and `redo` reply quotes history, and a trace has rewritten some of that: the line below is recorded with
  /// the window's number. So the trace says that a replay will say something else.
  @Test func undoAndRedoReplayThoughTheirRepliesQuoteWhatATraceRewrote() throws {
    let (h, _, _, _, _) = desk()
    for text in ["layout Safari~lawyers | Mail", "undo", "redo", "undo"] { #expect(h.run(text).ok, "\(text)") }
    h.run("trace off")
    let text = h.lastTrace ?? ""
    for secret in Self.secrets { #expect(!text.contains(secret), "\(secret)") }
    let trace = try Trace(text: text)
    let replies = trace.entries.compactMap { entry -> String? in
      if case .done(let command, true, let message) = entry.line, ["undo", "redo"].contains(command) { message } else { nil }
    }
    #expect(replies == ["undid", "redid", "undid"].map { "≈ \($0) layout Safari~… | Mail" })
    let replayer = TraceReplayer(trace, mode: .strict)
    #expect(replayer.run().problems == [])
    #expect(replayer.harness.workspace.tree == h.workspace.tree && replayer.harness.workspace.floating == h.workspace.floating)
  }

  /// F25: an entry of `displays` in settings.json can go by a part of a display's name.
  @Test func theNamesDisplaysAreMatchedByNeverReachATrace() throws {
    var settings = Settings()
    settings.displays = [
      DisplayOptions(match: .named("Robin's iPad"), gap: 4), DisplayOptions(match: .named("MAIN"), gap: 6), DisplayOptions(match: .builtIn, gap: 8),
      DisplayOptions(match: .named("robin's ipad"), minimumUsableWidth: 300), DisplayOptions(match: .named("Studio"), gap: 10),
    ]
    let h = Harness(settings: settings)
    h.system.open(app: "Safari")
    h.start()
    h.run("trace on words")
    var changed = settings
    changed.gap = 20
    changed.displays.append(DisplayOptions(match: .named("Granny's telly"), gap: 2))
    h.controller.apply(settings: changed)
    h.run("trace off")
    let text = h.lastTrace ?? ""
    for secret in ["Robin", "robin", "iPad", "ipad", "Studio", "Granny", "telly"] { #expect(!text.contains(secret), "\(secret)") }
    let trace = try Trace(text: text)
    // The same words have the same mark; the display's own id, however it is written, and what is no name stay.
    #expect(trace.header.settings.displays.map(\.match.text) == ["[d1]", "main", "builtin", "[d1]", "[d2]"])
    let later = trace.entries.compactMap { entry -> [String]? in
      if case .settings(let settings) = entry.line { settings.displays.map(\.match.text) } else { nil }
    }
    #expect(later == [["[d1]", "main", "builtin", "[d1]", "[d2]", "[d3]"]])
    #expect(TraceReplayer(trace, mode: .strict).run().problems == [])
  }

  /// Leaving the name out of the record of a display does not keep it out of a trace: replies call displays by their names (found by F52's author).
  @Test func theNamesOfDisplaysNeverReachATraceAndWhatGoesByThemStillDoes() throws {
    let main = DisplaySnapshot(
      id: FakeWindowSystem.standardDisplay.id, frame: FakeWindowSystem.standardDisplay.frame,
      visibleFrame: FakeWindowSystem.standardDisplay.visibleFrame, isMain: true, name: "Robin's iPad")
    let side = DisplaySnapshot(
      id: DisplayID("side"), frame: CGRect(x: 1440, y: 0, width: 1280, height: 800),
      visibleFrame: CGRect(x: 1440, y: 0, width: 1280, height: 800), isMain: false, name: "Granny's telly")
    var settings = Settings()
    settings.displays = [DisplayOptions(match: .named("ipad"), gap: 6)]
    let h = Harness(displays: [main, side], settings: settings)
    let safari = h.system.open(app: "Safari")
    let music = h.system.open(app: "Music", frame: CGRect(x: 1600, y: 200, width: 600, height: 400))
    h.start()
    h.run("trace on words")
    h.run("dock \(safari.rawValue) left")
    h.run("dock \(music.rawValue) right")
    var replies = [h.run("set gap 50").message]
    // An entry that goes by the other display's name arrives while the trace is being recorded.
    var changed = h.controller.settings
    changed.displays.append(DisplayOptions(match: .named("TELLY"), gap: 2))
    h.controller.apply(settings: changed)
    replies.append(h.run("set gap 40").message)
    h.run("trace off")
    #expect(replies[0].contains("Robin's iPad keeps 6") && replies[1].contains("Granny's telly keeps 2"), "the premise: \(replies)")

    let text = h.lastTrace ?? ""
    for secret in ["Robin", "iPad", "ipad", "Granny", "telly", "TELLY"] { #expect(!text.contains(secret), "\(secret)") }
    let trace = try Trace(text: text)
    #expect(trace.header.displays.map(\.name) == ["display-1[d1]", "display-2"])
    #expect(text.contains("display-1[d1] keeps 6") && text.contains("display-2[d2] keeps 2"))

    // The gaps of the two displays are their own in the replay as well, so the entries matched by name; and the replies are the same.
    let replayer = TraceReplayer(trace, mode: .strict)
    #expect(replayer.run().problems == [])
    for id in [safari, music] { #expect(replayer.harness.frame(id) == h.frame(id)) }
    #expect(h.frame(safari)?.minX == 6 && h.frame(music)?.maxX == 1440 + 1280 - 2, "\(String(describing: h.frame(safari))) \(String(describing: h.frame(music)))")
  }

  /// Working out what the words stand for asks the questions the command is about to ask itself, and one of them remembers its
  /// answer (which hand leads, F56).
  @Test func recordingChangesNothing() {
    let (recorded, _, _, notes, _) = desk(recording: true)
    let (plain, _, _, _, _) = desk(recording: false)
    #expect(session(recorded, notes: notes) == session(plain, notes: notes))
    // Shortcuts after it follow the same hand.
    for h in [recorded, plain] {
      h.system.type()
      h.system.cursor = CGPoint(x: 100, y: 100)
    }
    #expect(recorded.press("in").message == plain.press("in").message)
    #expect(recorded.controller.workspaces == plain.controller.workspaces)
    #expect(recorded.controller.parked == plain.controller.parked)
    #expect(recorded.system.focused == plain.system.focused)
    for id in plain.system.windows.keys { #expect(recorded.frame(id) == plain.frame(id)) }
  }

  /// `cameraDisplay()` and `commandDisplayID()` look like questions, but `InputLead` remembers what it answered, and for another
  /// source than the one that is about to ask it answers differently.
  @Test func workingOutTheWordsLeavesNoMarkOnWhichHandLeads() {
    let side = DisplaySnapshot(
      id: DisplayID("side"), frame: CGRect(x: 1440, y: 0, width: 1280, height: 800),
      visibleFrame: CGRect(x: 1440, y: 0, width: 1280, height: 800), isMain: false)
    let h = Harness(displays: [FakeWindowSystem.standardDisplay, side])
    let safari = h.system.open(app: "Safari", title: "Apple")
    let music = h.system.open(app: "Music", title: "Library", frame: CGRect(x: 1600, y: 200, width: 600, height: 400))
    h.start()
    h.run("dock \(safari.rawValue) left")
    h.run("dock \(music.rawValue) right")
    h.system.cursor = side.frame.center
    h.run("zoom \(music.rawValue)")
    h.run("name Tunes")
    // The pointer rests on the main display, the person types in Safari and presses a shortcut: the keyboard leads.
    h.system.cursor = FakeWindowSystem.standardDisplay.frame.center
    h.scheduler.advance(by: 5)
    h.system.userFocus(safari)
    h.scheduler.advance(by: 1)
    h.system.type()
    h.scheduler.advance(by: 0.3)
    h.press("zoom")
    let (lead, source) = (h.controller.following.lead, h.controller.following.source)
    for asking in CommandSource.allCases.map(Optional.some) + [nil] {
      #expect(h.controller.wordsForTrace(inCommand: "go tun", from: asking).text == "go Tunes")
      #expect(h.controller.wordsForTrace(inCommand: "layout Music~lib | Safari", from: asking).text == "layout \(music.rawValue) | Safari")
      #expect(h.controller.following.lead == lead && h.controller.following.source == source, "\(asking.map(\.rawValue) ?? "nobody")")
    }
  }

  /// The questions asked to work out the words leave no lines of their own.
  @Test func lookingUpWhatWordsStandForLeavesNoLines() throws {
    let (h, _, _, _, _) = desk()
    h.run("go acme")
    h.run("trace off")
    let lines = try Trace(text: h.lastTrace ?? "").entries.map(\.line)
    #expect(lines.first == .command("go name-1"), "nothing stands before the command: \(lines.prefix(3))")
  }

  /// The next command that takes words has to be looked at by somebody. Bundle ids, app names, and the numbers and ids of displays are
  /// in traces anyway.
  @Test func everyCommandThatTakesWordsIsKnownHere() throws {
    /// `helpOn` holds one of Arbor's own command words (`Command.canonicalVerb`), never what was typed.
    let harmless: Set = ["exclude", "include", "passThrough", "summon", "printLayout", "helpOn"]
    /// `find` comes with F27, which brings its own stand-in.
    let replaced: Set = ["name", "unname", "goToSpace", "layout", "find"]
    let found = try casesThatTakeWords(in: "Sources/ArborCore/Command.swift")
    #expect(Set(found).isSuperset(of: ["name", "unname", "goToSpace", "layout"]), "the reader of Command.swift no longer finds what is there: \(found)")
    for name in found { #expect(harmless.contains(name) || replaced.contains(name), Self.whatToDo("Command", name)) }
  }

  /// A command can keep its words a level further down: `.settings(.bind(chord:command:))`. So every type a case of `Command` carries is
  /// either plainly without words, or one whose own cases are looked at here in the same way.
  @Test func soIsEveryCommandInsideACommand() throws {
    let plain: Set = [
      "Edge", "WindowID", "NodeID", "Int", "Double", "Bool", "String", "LayoutNotation.Spec", "LayoutNotation.Naming",
      // Kinds of event and a switch | a window or a direction | next, previous or a number.
      "WatchOptions", "FocusTarget", "DisplayTarget",
    ]
    let lookedInto: [String: (file: String, harmless: Set<String>, replaced: Set<String>)] = [
      // Keys of settings and simple values; shortcuts; bundle ids.
      "SettingsCommand": (
        "Sources/ArborCore/SettingsCommand.swift", ["set", "get", "reset", "unbind", "addApp", "removeApp"], ["bind", "addRule", "changeRule"]
      ),
      // The name of the file, of letters and digits, which whoever shares the trace sees; and a remark they write into it themselves.
      "TraceCommand": ("Sources/ArborCore/Trace.swift", ["on", "note"], []),
    ]
    let source = try source("Sources/ArborCore/Command.swift")
    let payloads = source.matches(of: /\n  case [A-Za-z]+\(([^\n]*)\)/).map { String($0.1) }
    let types = Set(payloads.flatMap { $0.matches(of: /(?:^|[ (:,])([A-Z][A-Za-z.]*)/).map { String($0.1) } })
    #expect(types.isSuperset(of: ["SettingsCommand", "TraceCommand", "WindowID"]), "the reader of Command.swift no longer finds what is there: \(types)")
    for type in types.sorted() {
      #expect(
        plain.contains(type) || lookedInto[type] != nil,
        "A case of `Command` carries a `\(type)`. If it can hold words, list it in `lookedInto` with the file that declares it; if not, in `plain`.")
    }
    for (type, entry) in lookedInto.sorted(by: { $0.key < $1.key }) {
      let found = try casesThatTakeWords(in: entry.file, of: type)
      #expect(Set(found).isSuperset(of: entry.replaced), "the reader of \(entry.file) no longer finds what is there: \(found)")
      for name in found { #expect(entry.harmless.contains(name) || entry.replaced.contains(name), Self.whatToDo(type, name)) }
    }
  }

  private func source(_ path: String) throws -> String {
    let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    return try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8)
  }

  /// The cases that carry text, an arrangement or a rule. With `type`, those of that enum alone, which ends at the first `}` in the margin.
  private func casesThatTakeWords(in path: String, of type: String? = nil) throws -> [String] {
    var source = try source(path)[...]
    if let type {
      let start = try #require(source.firstRange(of: "enum \(type)"), "\(path) declares no enum \(type)")
      source = source[start.upperBound...]
      source = source[..<(source.firstRange(of: "\n}")?.lowerBound ?? source.endIndex)]
    }
    return source.matches(of: /\n  case ([A-Za-z]+)\([^\n]*(String|Spec|AppRule)[^\n]*\)/).map { String($0.1) }
  }

  private static func whatToDo(_ type: String, _ name: String) -> Comment {
    """
    `\(type).\(name)` takes words. If a person can put a title, a part of one, or a name of their own into them, a trace must not hold them as \
    typed, and the command must still replay: see Controller+TraceWords.swift and docs/TRACES.md, "What is never in a trace". Then list it here.
    """
  }

  /// Found by the bug bash of 2026-10-14: these went into a trace as they were typed.
  @Test func wordsInCommandsThatChangeSettingsNeverReachATraceAndTheCommandsStillReplay() throws {
    let (h, _, _, notes, mail) = desk()
    var replies: [String] = []
    for text in [
      "bind ctrl+opt+cmd+1 go acme", "bind ctrl+opt+cmd+2 go Embezzlement", "bind ctrl+opt+cmd+3 layout Mail~pays | Notes~gambling",
      "bind ctrl+opt+cmd+4 find lawyers", "bind ctrl+opt+cmd+5 name Chemotherapy plan", "bind ctrl+opt+cmd+6 unname Acme merger",
      "rule add com.apple.mail float title Payslip", "rule change 1 * float title October", "rules",
    ] {
      replies.append(h.run(text).message)
    }
    // A rule that came during the recording matches in the replay what it matched.
    let late = h.system.open(app: "Mail", title: "Statement for October")
    replies.append(h.key("ctrl+opt+cmd+3")?.message ?? "")
    h.run("trace off")
    #expect(replies.contains { $0.contains("Embezzlement") } && replies.contains { $0.contains("October") }, "\(replies)")
    let text = h.lastTrace ?? ""
    for secret in Self.secrets + ["Embezzle", "Payslip", "Statement"] {
      #expect(!text.contains(secret), "\(secret): \(text.split(separator: "\n").filter { $0.contains(secret) }.map { $0.prefix(200) })")
    }
    let trace = try Trace(text: text)
    let commands = trace.entries.compactMap { entry -> String? in
      if case .command(let text, _) = entry.line { text } else { nil }
    }
    #expect(commands.contains("bind ctrl+opt+cmd+1 go name-1"), "the whole name, as its token: \(commands)")
    #expect(commands.contains("bind ctrl+opt+cmd+3 layout \(mail.rawValue) | \(notes.rawValue)"))
    #expect(commands.contains("bind ctrl+opt+cmd+4 find …"))
    #expect(commands.contains { $0.hasPrefix("rule add com.apple.mail float title [p") })
    let replayer = TraceReplayer(trace, mode: .strict)
    #expect(replayer.run().problems == [])
    #expect(replayer.harness.workspace.isFloating(late) == h.workspace.isFloating(late))
    #expect(replayer.harness.controller.settings.rules.count == h.controller.settings.rules.count)
  }
}
