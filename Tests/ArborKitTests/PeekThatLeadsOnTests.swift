import ArborCore
import ArborKit
import ArborTesting
import CoreGraphics
import Foundation
import Testing

private let space = "ctrl+opt+space"

/// ⌃⌥Space shows everything, and the view can go on from there by itself before the key has had time to come up: the window
/// that was let be (`Controller+LetBe.swift`) goes into its tile with the keyboard in it, nothing else is in view to take the
/// keyboard, and the view goes after it. That is where the key has led. The peek used to begin all the same, took
/// everything to be showing, and at the release wrote that down without laying anything out: the screen showed one space
/// and the workspace said another, until the next key (found by the walks, with keys only, as Arbor ships).
@Suite(.withTiles) @MainActor struct PeekThatLeadsOnTests {
  /// Every story here needs a window that becomes a tile where it does not fit. The one place to say so in settings, the day Arbor
  /// ships without tiles. (The walk below has its own `settings` line.)
  func desk() -> Harness { Harness() }

  /// Too big for a place beside, above or below anything, a tile included. Framed it fits.
  func openBig(_ app: String, pid: Int32, in h: Harness) -> WindowID {
    h.system.open(
      app: app, pid: pid, frame: CGRect(x: 10, y: 30, width: 1410, height: 800), minimumSize: CGSize(width: 1410, height: 785))
  }

  /// One big window, docked to the left: a tile while everything shows. Paused and resumed with ⌃⌥⎋, with the keyboard in it:
  /// let be where it stands. `first` opens what else is to be there.
  func aloneAndLetBe(first: (Harness) -> Void = { _ in }) throws -> (Harness, WindowID) {
    let h = desk()
    h.start()
    let xcode = openBig("Xcode", pid: 1004, in: h)
    first(h)
    settle(h)
    h.system.userFocus(xcode)
    settle(h)
    try byItsKey(h, "dock left")
    tap(h, "ctrl+opt+escape")
    tap(h, "ctrl+opt+escape")
    try #require(h.controller.windowLetBe == xcode && h.workspace.camera == h.workspace.tree.root, "\(h.ascii())")
    try #require(h.layout?.tiles.contains { $0.windows.contains(xcode) } == true, "\(h.ascii())")
    return (h, xcode)
  }

  /// Two big windows one above the other and a third beside them; the view is on the two. Paused and resumed with the
  /// keyboard in the upper one: let be, in a view that is not everything.
  func letBeInAGroup() throws -> (Harness, xcode: WindowID, group: NodeID) {
    let h = desk()
    let xcode = openBig("Xcode", pid: 1004, in: h)
    let (figma, mail) = (openBig("Figma", pid: 1005, in: h), openBig("Mail", pid: 1006, in: h))
    h.start()
    for command in ["dock \(xcode.rawValue) left", "dock \(figma.rawValue) beside \(xcode.rawValue) bottom", "dock \(mail.rawValue) right"] {
      try #require(h.run(command).ok)
      settle(h)
    }
    h.system.userFocus(xcode)
    settle(h)
    try byItsKey(h, "out")
    let group = h.workspace.camera
    tap(h, "ctrl+opt+escape")
    h.system.userFocus(xcode)
    settle(h)
    tap(h, "ctrl+opt+escape")
    h.scheduler.advance(by: 10)
    try #require(h.controller.windowLetBe == xcode && h.workspace.camera == group, "\(h.ascii())")
    try #require(group != h.workspace.tree.root && group != h.workspace.tree.leaf(containing: xcode), "\(h.ascii())")
    return (h, xcode, group)
  }

  func settle(_ h: Harness) { h.scheduler.advance(by: 6) }

  /// What leads up to the key, asked for as a key asks. Which key that is depends on the map in use, and is not what these are about.
  func byItsKey(_ h: Harness, _ command: String) throws {
    try #require(h.run(command, from: .shortcut).ok, "\(command)")
    settle(h)
  }

  func tap(_ h: Harness, _ keys: String) {
    h.keyDown(keys)
    h.scheduler.advance(by: 0.05)
    h.keyUp(keys)
    settle(h)
  }

  /// What shows is what the workspace says, the window is framed with the keyboard in it, and nobody is looking. With the key
  /// up nothing of a peek is left. While it is down the peek is there and spent, as after every landing: that is what keeps
  /// the key's own repeats from beginning another.
  func expectAllOfAPiece(_ h: Harness, _ window: WindowID, keyIsUp: Bool = true, sourceLocation: SourceLocation = #_sourceLocation) {
    #expect(h.layout?.camera == h.workspace.camera, "\(h.ascii())", sourceLocation: sourceLocation)
    #expect(h.workspace.camera == h.workspace.tree.leaf(containing: window), "the view went after the keyboard", sourceLocation: sourceLocation)
    expectWindowsMatchLayout(h, sourceLocation: sourceLocation)
    #expect(h.controller.invariantViolations().isEmpty, "\(h.controller.invariantViolations())", sourceLocation: sourceLocation)
    #expect(h.system.isVisible(window) && h.system.focusedWindow() == window, sourceLocation: sourceLocation)
    #expect(!h.controller.isPeeking && h.workspace.lookingFrom == nil, sourceLocation: sourceLocation)
    #expect(h.overlays.scenes[h.display]?.peekOutline == nil, sourceLocation: sourceLocation)
    #expect(h.controller.temporaryShortcuts.isEmpty, sourceLocation: sourceLocation)
    #expect(h.controller.aPeekIsUnderWay == !keyIsUp, sourceLocation: sourceLocation)
    #expect(h.scheduler.pendingKeys.contains("peek") == !keyIsUp, "\(h.scheduler.pendingKeys)", sourceLocation: sourceLocation)
  }

  @Test func afterATapTheScreenShowsWhatTheWorkspaceSays() throws {
    let (h, xcode) = try aloneAndLetBe()
    tap(h, space)
    expectAllOfAPiece(h, xcode)
  }

  /// The key is used up when the view has gone on: held, it shows no outline and takes no keys, its repeats begin nothing, and
  /// let go late it takes nobody anywhere.
  @Test func heldItIsNoPeekAndItsReleaseMovesNothing() throws {
    let (h, xcode) = try aloneAndLetBe()
    h.keyDown(space)
    h.scheduler.advance(by: 0.05)
    expectAllOfAPiece(h, xcode, keyIsUp: false)
    let (camera, back, frame) = (h.workspace.camera, h.workspace.back, h.frame(xcode))
    h.system.clearFrameLog()
    for _ in 0..<4 {
      h.scheduler.advance(by: 0.5)
      h.keyRepeat(space)
      expectAllOfAPiece(h, xcode, keyIsUp: false)
    }
    h.keyUp(space)
    settle(h)
    expectAllOfAPiece(h, xcode)
    #expect(h.workspace.camera == camera && h.workspace.back == back && h.frame(xcode) == frame && h.system.frameLog.isEmpty)
  }

  /// A release that macOS never reports is found by the peek's own look at the keys, as for every peek.
  @Test func theSpentKeysReleaseIsFoundThoughNobodyReportsIt() throws {
    let (h, xcode) = try aloneAndLetBe()
    h.keyDown(space)
    h.scheduler.advance(by: 0.05)
    h.keyUp(space, reported: false)
    settle(h)
    expectAllOfAPiece(h, xcode)
  }

  /// One entry in history, from everything to where the key has led, as for any move of the view.
  @Test func backLeadsToEverything() throws {
    let (h, _) = try aloneAndLetBe()
    let root = h.workspace.tree.root
    tap(h, space)
    #expect(h.workspace.back.last == root, "\(h.workspace.back)")
    #expect(h.run("back").ok)
    settle(h)
    #expect(h.workspace.camera == root && h.layout?.camera == root)
    expectWindowsMatchLayout(h)
  }

  /// The key ends where the command ends.
  @Test func theKeyEndsWhereTheCommandEnds() throws {
    let (byKey, a) = try aloneAndLetBe()
    let (byCommand, b) = try aloneAndLetBe()
    tap(byKey, space)
    #expect(byCommand.run("show-all").ok)
    settle(byCommand)
    #expect(byKey.workspace.camera == byCommand.workspace.camera && byKey.frame(a) == byCommand.frame(b))
    #expect(byKey.layout?.camera == byCommand.layout?.camera && byKey.workspace.back == byCommand.workspace.back)
    expectWindowsMatchLayout(byKey)
  }

  // MARK: From a view that is not everything

  /// The look is over as after every landing: the view is put back where the key was pressed, and one ordinary move leads from
  /// there to the window. So Back leads to the view that was left. (The command makes two moves, and has everything in between.)
  @Test func fromAGroupItIsOneMoveFromThereToTheWindow() throws {
    let (h, xcode, group) = try letBeInAGroup()
    let back = h.workspace.back
    tap(h, space)
    expectAllOfAPiece(h, xcode)
    #expect(h.workspace.back == back + [group], "\(h.workspace.back)")
    #expect(h.run("back").ok)
    settle(h)
    #expect(h.workspace.camera == group && h.layout?.camera == group)
    expectWindowsMatchLayout(h)
  }

  /// One key, one look at what came of it. Everything showed on the way, so "your other windows are out of view" looked like news
  /// a moment later, in answer to the very key it recommends. The command says nothing here either.
  @Test func whatShowedOnTheWayIsNoNewsForTheLineOnScreen() throws {
    let (h, xcode, _) = try letBeInAGroup()
    let said = h.overlays.messages.count
    tap(h, space)
    expectAllOfAPiece(h, xcode)
    #expect(h.overlays.messages.count == said, "\(h.overlays.messages.map(\.model.line).suffix(2))")
  }

  // MARK: The walk

  /// The walk that found it, with keys only. Held to what every walk that found something is held to (`ChaosRegressionTests`):
  /// nothing breaks but what is on the list of known failures.
  @Test func theWalkThatFoundItFindsItNoMore() throws {
    let walk = """
      displays main:0,0,1280,800:25,0,70,0* windows-never
      settings {"windowsThatDoNotFit":"tile"}
      launch
      open 101 Xcode pid 1004 at 40 40 1188 690 min 1188 685
      settle
      focus 101
      settle
      key down dock left
      key up dock left
      settle
      toggle-pause
      settle
      toggle-pause
      settle
      key down show-all
      settle
      key up show-all
      settle
      """
    let runner = ChaosRunner()
    for action in ChaosAction.script(walk) {
      // Or the walk no longer gets to where the fault was, and proves nothing.
      if action.text == "key down show-all" { try #require(runner.controller.windowLetBe == WindowID(101)) }
      let broken = runner.step(action).map(\.rule).filter { !ChaosRunner.knownRules.contains($0) }
      #expect(broken.isEmpty, "\(action.text): \(broken)")
    }
  }

  // MARK: What stays as it was, with the peek in place before the view moves

  /// Xcode, too big for a place beside the others, and Notes, both docked; the view is on Xcode.
  func framedOnTheBigOne() throws -> (Harness, xcode: WindowID, notes: WindowID) {
    let h = desk()
    h.start()
    let xcode = openBig("Xcode", pid: 1004, in: h)
    let notes = h.system.open(app: "Notes", pid: 1005, frame: CGRect(x: 700, y: 300, width: 400, height: 300))
    for window in [notes, xcode] {
      h.system.userFocus(window)
      settle(h)
      try byItsKey(h, "dock left")
    }
    if h.workspace.camera != h.workspace.tree.leaf(containing: xcode) { tap(h, "ctrl+opt+return") }
    h.scheduler.advance(by: 10)
    try #require(h.workspace.camera == h.workspace.tree.leaf(containing: xcode) && h.layout?.tiles.isEmpty == true, "\(h.ascii())")
    return (h, xcode, notes)
  }

  /// What the move to everything brings about is news like any other: a tile that comes up at the key is explained at the key.
  @Test func aTileThatComesUpAtTheKeyIsExplainedThere() throws {
    let (h, _, _) = try framedOnTheBigOne()
    let said = h.overlays.messages.count
    h.keyDown(space)
    try #require(h.layout?.tiles.isEmpty == false && h.workspace.camera == h.workspace.tree.root, "\(h.ascii())")
    #expect(h.overlays.messages.count == said + 1, "\(h.overlays.messages.map(\.model.line))")
    #expect(h.overlays.messages.last?.model.line.contains("tile") == true, "\(h.overlays.messages.map(\.model.line))")
    h.keyUp(space)
    settle(h)
    #expect(h.overlays.messages.count == said + 1, "and the release adds nothing")
    expectWindowsMatchLayout(h)
  }

  /// The clock starts once everything shows: windows that take their time, and a release that waited behind them, are a tap.
  @Test func aTapBehindSlowWindowsIsATap() throws {
    let (h, _, _) = try framedOnTheBigOne()
    final class Lateness { var seconds = 0.0 }
    let (late, clock) = (Lateness(), h.controller.now)
    h.controller.now = { clock().addingTimeInterval(late.seconds) }
    h.system.willSetFrame = { _, _ in late.seconds += 1 }
    h.keyDown(space)
    h.system.willSetFrame = nil
    try #require(late.seconds >= 2, "or this proves nothing")
    h.keyUp(space)
    settle(h)
    #expect(h.workspace.camera == h.workspace.tree.root && h.layout?.camera == h.workspace.tree.root, "it stays on everything")
    #expect(!h.controller.aPeekIsUnderWay)
    expectWindowsMatchLayout(h)
  }

  /// Where the pointer is, and whether its button is down, is asked once everything shows and not before. What Arbor asks of macOS
  /// stands in every recording, line by line, and a recording is replayed by those lines.
  @Test func theKeyAsksNothingAboutThePointerBeforeTheViewMoves() throws {
    let (h, _, _) = try framedOnTheBigOne()
    try #require(h.run("trace on peek").ok)
    h.keyDown(space)
    try #require(h.run("trace off").ok)
    let lines = try Trace(text: h.lastTrace ?? "").entries.map(\.line)
    let firstMove = try #require(lines.firstIndex { if case .setFrame = $0 { true } else { false } })
    let aboutThePointer = lines.indices.filter {
      switch lines[$0] {
      case .cursorLocation, .isMouseButtonDown: true
      default: false
      }
    }
    #expect(aboutThePointer.allSatisfy { $0 > firstMove } && !aboutThePointer.isEmpty, "\(aboutThePointer), and the first move is \(firstMove)")
    h.keyUp(space)
    settle(h)
    expectWindowsMatchLayout(h)
  }

  /// The control: with another window in view to take the keyboard the view stays on everything, and the peek is a peek.
  @Test func withSomebodyInViewToTakeTheKeyboardItIsAPeekAsEver() throws {
    var notes: WindowID?
    let (h, _) = try aloneAndLetBe { notes = $0.system.open(app: "Notes", pid: 1005, frame: CGRect(x: 700, y: 300, width: 400, height: 300)) }
    h.keyDown(space)
    h.scheduler.advance(by: 0.4)
    #expect(h.controller.isPeeking && h.workspace.camera == h.workspace.tree.root)
    #expect(h.system.focusedWindow() == notes)
    h.keyUp(space)
    settle(h)
    #expect(h.layout?.camera == h.workspace.camera && h.workspace.camera == h.workspace.tree.root)
    #expect(!h.controller.aPeekIsUnderWay)
    expectWindowsMatchLayout(h)
  }
}
