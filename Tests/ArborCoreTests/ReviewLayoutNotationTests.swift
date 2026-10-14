import CoreGraphics
import Foundation
import Testing

@testable import ArborCore

/// Runs `body` on a thread with a stack of `bytes`, and waits for it.
private func onAThread(withAStackOf bytes: Int, _ body: @escaping @Sendable () -> Void) {
  let done = DispatchSemaphore(value: 0)
  let thread = Thread {
    body()
    done.signal()
  }
  thread.stackSize = bytes
  thread.start()
  done.wait()
}

/// What an independent review of the notation (F54) tried on it.
@Suite struct ReviewLayoutNotationTests {
  /// Brackets `depth` deep that stay that deep in the tree: the direction changes at each level.
  static func deepLine(_ depth: Int) -> String {
    var line = "X"
    for level in 0..<depth { line = "(\(line) \(level % 2 == 0 ? "|" : "/") L\(level))" }
    return line
  }

  /// macOS gives every thread but the main one 512 KB, and tests of the core run on such threads. Everything that goes
  /// down an arrangement level by level is called here on the deepest one that can be written, on such a stack. (A debug
  /// build on Linux needs between 256 and 384 KB with everything on the trunk of 14 October, so there is not much to spare.)
  @Test func theDeepestLineIsSafeOnASmallStack() {
    onAThread(withAStackOf: 512 * 1024) {
      guard let spec = try? LayoutNotation.parse(Self.deepLine(LayoutNotation.maximumDepth)) else {
        Issue.record("the deepest line did not parse")
        return
      }
      #expect(spec.slots.count == LayoutNotation.maximumDepth + 1)
      #expect(!spec.mentionsDesktop)
      #expect((try? LayoutNotation.parse(spec.text)) == spec)
      #expect(!spec.textWithoutTitles.isEmpty)
      let candidates = spec.slots.enumerated().map { index, slot -> WindowCandidate in
        guard case .app(let name) = slot.owner else { return WindowCandidate(id: WindowID(0), bundleID: nil, appName: "") }
        return WindowCandidate(id: WindowID(UInt32(index + 1)), bundleID: nil, appName: name)
      }
      let tree = spec.tree(filling: spec.resolve(candidates).windows)
      #expect(tree.invariantViolations().isEmpty)
      #expect(tree.allWindows.count == LayoutNotation.maximumDepth + 1)
      #expect(spec.resolve(candidates, current: tree).windows == spec.resolve(candidates).windows)
      #expect(tree.counterparts(in: tree).count == tree.nodes.count)
      let layout = LayoutEngine.layout(
        tree, camera: tree.root, in: CGRect(x: 0, y: 0, width: 1440, height: 900), isPresent: { _ in true })
      #expect(!AsciiRenderer.render(layout, tree: tree).isEmpty)
      let names = Dictionary(uniqueKeysWithValues: candidates.map { ($0.id, $0.appName) })
      #expect(LayoutNotation.Spec(tree) { .app(names[$0] ?? "?") }.slots.count == LayoutNotation.maximumDepth + 1)
      var workspace = Workspace()
      workspace.reset(tree: tree, carrying: Workspace().tree.counterparts(in: tree))
      guard let data = try? JSONEncoder().encode(workspace) else {
        Issue.record("the deepest arrangement could not be saved")
        return
      }
      #expect((try? JSONDecoder().decode(Workspace.self, from: data))?.tree.allWindows == tree.allWindows)
      let command = Command.layout(spec, display: nil, open: false)
      #expect((try? Command.parse(command.text)) == command)
    }
  }

  // MARK: A window that arrives later

  @Test func growingKeepsTheViewAndRemembersWhereTheNewcomerFloated() throws {
    let spec = try LayoutNotation.parse("A | (B / C)")
    let (a, b, c, other) = (WindowID(1), WindowID(2), WindowID(3), WindowID(4))
    var workspace = Workspace()
    let (ownOfA, ownOfC, ownOfOther) = (
      CGRect(x: 1, y: 2, width: 500, height: 400), CGRect(x: 10, y: 20, width: 300, height: 200), CGRect(x: 5, y: 6, width: 70, height: 80)
    )
    workspace.floating = [a: ownOfA, other: ownOfOther]
    workspace.reset(tree: spec.tree(filling: [[a], [b], []]))
    let leaf = try #require(workspace.tree.leaf(containing: b))
    workspace.moveCamera(to: leaf)
    workspace.saveView(slot: 1)
    let history = workspace.back
    workspace.floating[c] = ownOfC

    workspace.grow(into: spec.tree(filling: [[a], [b], [c]]))
    #expect(workspace.tree.allWindows == [a, b, c])
    #expect(workspace.tree.invariantViolations().isEmpty)
    // The view, its history and the saved view are where they were.
    #expect(workspace.camera == leaf && workspace.tree.windows(under: leaf) == [b])
    #expect(workspace.savedView(slot: 1) == leaf)
    #expect(workspace.back == history)
    // The newcomer stops floating and can go back to where it floated. What was remembered or floats besides stays.
    #expect(workspace.floating == [other: ownOfOther])
    #expect(workspace.undockedFrame(of: c) == ownOfC)
    #expect(workspace.undockedFrame(of: a) == ownOfA)
    #expect(workspace.undockedFrame(of: b) == nil)
  }

  // MARK: What is read is what was written

  /// A name is kept or refused. One that is read and then dropped would leave `layout <name>` meaning `layout Desktop`,
  /// which floats everything.
  @Test(arguments: [
    "a\u{D4E}", "Safari | a\u{D4E}", "[Safari a\u{D4E}]", "Safari~a\u{D4E}", "\u{D4E}", "a\u{111C2}", "a\u{D4E} | Mail",
    "a\u{D4E}|Mail", "a\u{D4E}:2 | Mail", "(a\u{D4E})", "a\u{D4E}*", "a\u{D4E}~b", "@a\u{D4E} Safari", "--a\u{D4E} Safari",
  ])
  func noNameIsReadAndThenDropped(_ line: String) {
    guard let parsed = try? LayoutNotation.parseLine(line), let spec = parsed.spec else { return }
    // As many names as the words that were read as names.
    let words = ((try? LayoutNotation.tokens(of: line))?.0 ?? []).filter {
      switch $0.kind {
      case .word, .quoted: true
      default: false
      }
    }
    let sizes = ((try? LayoutNotation.tokens(of: line))?.0 ?? []).filter { $0.kind == .size }.count
    let titles = spec.slots.filter { $0.title != nil }.count
    #expect(spec.slots.count + titles + sizes == words.count, "\(line.debugDescription) was read as \(spec.text.debugDescription)")
  }

  /// Every text that parses says the same when it is written and read again, with names from the odd corners of Unicode.
  @Test func oddNamesComeBackOrAreRefused() {
    let pieces: [String] = [
      "a", "é", "e\u{301}", "\u{301}", "שלום", "\u{200F}", "\u{202E}", "👩‍👩‍👧", "👍🏽", "\u{1F3FB}", "🇩🇪", "\u{1F1E9}", "\u{0}", "\n", "\r\n", "\t",
      "\u{A0}", "\u{3000}", "\u{FEFF}", "\u{D4E}", "\u{111C2}", "ᄀ", "ᅡ", "\u{FE0F}", "\u{20E3}", "1", "w1", "W1", "٣", "½", "①", "Desktop", "deſktop",
      "des\u{212A}top", "|", "/", "(", ")", "[", "]", ":", "*", "~", "@", "-", "--", "\"", "'", "“", "”", "‘", "’", " ", ".", "_", "%", "\\",
    ]
    var state: UInt64 = 48
    func next(_ bound: Int) -> Int {
      state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
      return Int((state >> 33) % UInt64(bound))
    }
    var parsed = 0
    for _ in 0..<40_000 {
      let text = (0..<(1 + next(7))).map { _ in pieces[next(pieces.count)] }.joined()
      guard let spec = try? LayoutNotation.parse(text) else { continue }
      parsed += 1
      let written = spec.text
      #expect((try? LayoutNotation.parse(written)) == spec, "\(text.debugDescription) was written as \(written.debugDescription)")
      #expect(!written.unicodeScalars.contains(where: LayoutNotation.isForbidden), "\(text.debugDescription)")
      let command = Command.layout(spec, display: nil, open: false)
      #expect((try? Command.parse(command.text)) == command, "\(text.debugDescription)")
    }
    #expect(parsed > 1000)
  }

  // MARK: Sizes

  @Test(arguments: [
    "0", "-1", "-0", "0.0", "0.0009", "1000.001", "1001", "1e3", "1E3", "nan", "NaN", "inf", "infinity", "0x10", "1_0", "1.2.3", ".", "..", "٣", "½",
    "999999999999", "9999999999999", "00000000000001", "1,5", "+1", "1-", "w1", "", " ", ":", "1:2",
  ])
  func sizesThatAreNotSizesAreRefused(_ size: String) {
    #expect(throws: LayoutNotation.ParseError.self) { try LayoutNotation.parse("A:\(size) | B") }
  }

  @Test(arguments: [("0.001", 0.001), ("1000", 1000), ("1000.0", 1000), (".5", 0.5), ("5.", 5), ("0.0014", 0.001), ("0.0015", 0.002), ("007", 7), ("1.0004", 1)])
  func sizesAtTheEdges(_ written: String, _ size: Double) throws {
    let spec = try LayoutNotation.parse("A:\(written) | B")
    guard case .group(_, let members) = spec.root.kind else {
      Issue.record("not a group")
      return
    }
    #expect(members[0].size == size)
    #expect(try LayoutNotation.parse(spec.text) == spec)
  }

  // MARK: Limits

  @Test func namesAtAndPastTheLimit() throws {
    let longest = String(repeating: "x", count: LayoutNotation.maximumNameLength)
    for line in [longest, "\"\(longest)\"", "A~\(longest)", "A~'\(longest)'", "@\(longest) A"] {
      #expect(throws: Never.self) { try LayoutNotation.parseLine(line) }
      #expect(throws: LayoutNotation.ParseError.self) { try LayoutNotation.parseLine(line.replacingOccurrences(of: "xx", with: "xxx", range: line.range(of: "xx"))) }
    }
  }

  @Test func theLengthIsCountedInBytesAtAndPastTheLimit() {
    // "字 | " is 6 bytes and 4 characters, so the limit is reached with far fewer characters than bytes.
    let unit = "字 | "
    let most = (LayoutNotation.maximumLength - 1) / unit.utf8.count
    let body = String(repeating: unit, count: most)
    let atTheLimit = body + String(repeating: "x", count: LayoutNotation.maximumLength - body.utf8.count)
    #expect(atTheLimit.utf8.count == LayoutNotation.maximumLength && atTheLimit.count < LayoutNotation.maximumLength)
    #expect(throws: Never.self) { try LayoutNotation.parse(atTheLimit) }
    let error = #expect(throws: LayoutNotation.ParseError.self) { try LayoutNotation.parse(atTheLimit + "x") }
    #expect(error?.message.contains("bytes long") == true)
  }

  // MARK: URLs

  @Test(arguments: [
    "arbor://layout/--open%20Mail", "arbor://layout/%2D%2Dopen%20Mail", "arbor://layout/Mail%20--open", "arbor://layout/Mail%20--OPEN",
    "arbor://LAYOUT/--open%20Mail", "arbor://%6Cayout/--open%20Mail", "arbor:layout/--open%20Mail", "arbor:///layout/--open%20Mail",
    "arbor://layout/%22--open%20Mail%20%7C%20Notes%22", "arbor://layout/'--open%20Mail%20%7C%20Notes'", "arbor://layout/%E2%80%9C--open%20Mail%7CNotes%E2%80%9D",
    "arbor://layout/%22'--open%20Mail%20%7C%20Notes'%22", "arbor://layout//--open%20Mail", "arbor://layout/Mail/--open",
    "arbor://layout", "arbor://layout/", "arbor://layout/--ids", "arbor://layout/--titles", "arbor://layout/@2", "arbor://layout?Mail", "arbor://layout#Mail",
    "arbor://layout/Desktop", "arbor://layout/(Desktop)", "arbor://layout/desktop:2", "arbor://layout/@1%20Desktop",
  ])
  func aURLNeitherOpensAppsNorAsksNorFloatsEverything(_ url: String) {
    guard let command = try? Command.parse(url: url) else { return }
    #expect(!command.isAllowedFromURL, "\(url) was read as `\(command.text)`")
  }

  @Test(arguments: [
    "arbor://layout/Mail%00", "arbor://layout/Mail%0A", "arbor://layout/Mail%0D%0Aquit", "arbor://layout/Mail%09Notes", "arbor://layout/%E2%80%AEMail",
    "arbor://layout/Mail%E2%80%8F", "arbor://layout/Mail%FF", "arbor://layout/Mail%", "arbor://layout/Mail%2", "arbor://layout/Mail%GG", "arbor://layout/Mail%C0%80",
    "arbor://layout/Mail%ED%A0%80", "arbor://layout/Mail%EF%BB%BF", "arbor://layout/Mail%E2%80%A8Notes", "arbor://layout/%2520", "arbor://layout/Mail%257CNotes",
  ])
  func aURLWithWhatCannotBeSeenOrRead(_ url: String) {
    #expect(throws: Command.ParseError.self) { try Command.parse(url: url) }
  }
}
