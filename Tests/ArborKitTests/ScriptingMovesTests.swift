import ArborCore
import ArborKit
import ArborTesting
import CoreGraphics
import Foundation
import Testing

/// A command with names in it, and the same with the numbers they stand for on `desk()`.
private let pairs = [
  ("zoom Safari", "zoom 102"), ("zoom Mail", "zoom 103"), ("zoom focused", "zoom 105"), ("float Mail", "float 103"), ("toggle-float Terminal", "toggle-float 104"),
  ("dock Slack right", "dock 105 right"), ("dock focused left", "dock 105 left"), ("dock Slack beside Mail bottom", "dock 105 beside 103 bottom"),
  ("dock Mail beside Safari bottom", "dock 103 beside 102 bottom"), ("resize Mail bottom 40", "resize 103 bottom 40"), ("swap Mail Terminal", "swap 103 104"),
  ("swap Safari right", "swap 102 right"), ("pin Slack", "pin 105"), ("focus Terminal", "focus 104"), ("reveal Mail", "reveal 103"),
]

/// What a script may move (F50): a window moves once, to where it ends up, and only if the command was about it or needs its room.
/// A name, a query and a refusal add no move of their own.
@Suite @MainActor struct ScriptingMovesTests {
  func w(_ id: UInt32) -> WindowID { WindowID(id) }

  /// 102 Safari | (103 Mail / 104 Terminal) | the Desktop, where 101 Safari and 105 Slack float. Slack has the keyboard.
  func desk() -> Harness {
    let h = Harness()
    for (app, bundle) in [("Safari", "com.apple.Safari"), ("Safari", "com.apple.Safari"), ("Mail", "com.apple.mail"), ("Terminal", "com.apple.Terminal"), ("Slack", "com.tinyspeck.slackmacgap")] {
      h.system.open(app: app, bundleID: bundle)
    }
    h.start()
    for id: UInt32 in [101, 102] { h.system.userFocus(w(id)) }
    #expect(h.run("layout 102 | (103 / 104) | Desktop").ok)
    h.system.userFocus(w(105))
    h.scheduler.advance(by: 5)
    h.system.clearFrameLog()
    return h
  }

  struct Moves {
    var reply: CommandResult
    /// Every frame Arbor set, in order, until all is quiet.
    var log: [String]
    var movedTwice: [WindowID]
    /// Told to be where they were already.
    var movedNowhere: [WindowID]
  }

  func moves(of line: String, from source: CommandSource = .script) throws -> Moves {
    let h = desk()
    let before = h.system.windows.mapValues(\.snapshot.frame)
    let reply = h.controller.perform(try Command.parse(line), from: source)
    h.scheduler.advance(by: 5)
    let log = h.system.frameLog
    let touched = Set(log.map(\.window))
    return Moves(
      reply: reply, log: log.map { "\($0.window) \($0.frame)" },
      movedTwice: touched.filter { id in log.filter { $0.window == id }.count > 1 }.sorted(),
      movedNowhere: touched.filter { h.system.windows[$0]?.snapshot.frame == before[$0] }.sorted())
  }

  /// Frame for frame, in the same order: looking a name up moves nothing.
  @Test(arguments: pairs) func aNameMovesWhatItsNumberMoves(named: String, numbered: String) throws {
    for source in [CommandSource.script, .shortcut] {
      let (a, b) = (try moves(of: named, from: source), try moves(of: numbered, from: source))
      #expect(b.reply.ok, "\(numbered): \(b.reply.message)")
      #expect(a.log == b.log, "\(named) set \(a.log), \(numbered) \(b.log)")
    }
  }

  @Test(arguments: pairs.map(\.0)) func noWindowMovesTwiceAndNoneIsMovedToWhereItIs(named: String) throws {
    let moves = try moves(of: named)
    #expect(moves.reply.ok, "\(moves.reply.message)")
    #expect(moves.movedTwice.isEmpty, "\(named) moved \(moves.movedTwice) more than once: \(moves.log)")
    #expect(moves.movedNowhere.isEmpty, "\(named) set the frame \(moves.movedNowhere) had already: \(moves.log)")
  }

  /// So that the two above show something.
  @Test func mostOfThemDoMoveWindows() throws {
    #expect(try pairs.filter { try !moves(of: $0.0).log.isEmpty }.count >= 10)
  }

  /// Also where the first name means a window and the second nothing: all names are looked up before anything is done.
  @Test(arguments: [
    "zoom Nobody", "dock Nobody left", "dock Mail beside Nobody left", "dock Nobody beside Mail left", "swap Mail Nobody", "float Nobody", "resize Nobody left 40",
    "float Slack", "exclude Nobody", "pass-through Nobody on",
  ]) func whatIsRefusedMovesNothing(line: String) throws {
    let moves = try moves(of: line)
    #expect(!moves.reply.ok && moves.log.isEmpty, "\(line): \(moves.reply.message); \(moves.log)")
  }

  @Test(arguments: ["windows", "windows --titles", "where", "views", "displays", "version", "help dock", "layout", "state"])
  func askingMovesNothing(line: String) throws {
    let moves = try moves(of: line)
    #expect(moves.reply.ok && moves.log.isEmpty, "\(line): \(moves.log)")
  }

  /// A line of several commands of which one cannot be read: nothing was sent, so nothing moved.
  @Test func aLineWithAMistakeInItMovesNothing() {
    let h = desk()
    let code = Arborctl.run(
      ["dock", "Slack", "right", ",", "zoom", "Mail", ",", "hoem"],
      send: { line, _ in String(decoding: try JSONEncoder().encode(h.run(line)), as: UTF8.self) }, emit: { _ in })
    h.scheduler.advance(by: 5)
    #expect(code == 64 && h.system.frameLog.isEmpty)
  }
}
