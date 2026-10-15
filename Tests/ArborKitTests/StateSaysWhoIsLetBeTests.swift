import ArborCore
import ArborKit
import ArborTesting
import CoreGraphics
import Foundation
import Testing

/// The window that a launch lets be (`Controller+LetBe.swift`) is docked, is a tile in the layout, and stands in full view. `state` and
/// `ascii` are what everybody else goes by: whoever holds `arborctl state` against the screen of a real Mac, and the headless nets.
/// While only the controller knew, they called it hidden, and a window in view that Arbor calls hidden looks like a fault.
@Suite @MainActor struct StateSaysWhoIsLetBeTests {
  let launches = LaunchLetsBeTests()

  func said(_ h: Harness, of window: WindowID) throws -> StateSnapshot.Window {
    try #require(h.run("state").state?.windows.first { $0.id == window })
  }

  @Test func stateSaysOfTheWindowALaunchLetsBeThatItIsLetBe() throws {
    let (h, player, browser, notes, stood) = launches.launched()
    let window = try said(h, of: player)
    #expect(window.letBe)
    #expect(window.docked && !window.parked && window.frame == stood, "docked, not out of view, and where it stands")
    #expect(try !said(h, of: browser).letBe && !said(h, of: notes).letBe, "and of nobody else")
  }

  /// As `arborctl state` prints it, which is what the scripts on a Mac read (`state.py is <id> letBe`).
  @Test func theWordIsInTheJSON() throws {
    let (h, player, _, _, _) = launches.launched()
    let json = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(h.run("state").state)) as? [String: Any])
    let windows = try #require(json["windows"] as? [[String: Any]])
    #expect(windows.filter { $0["letBe"] as? Bool == true }.compactMap { $0["id"] as? Int } == [Int(player.rawValue)])
  }

  @Test func theDrawingShowsItWhereItStandsAndDoesNotCallItHidden() {
    let (h, player, _, _, _) = launches.launched()
    let drawing = h.ascii()
    #expect(!drawing.contains("hidden:"), "\(drawing)")
    #expect(drawing.contains("let be: \(player) Music"), "\(drawing)")
    #expect(drawing.contains(":\(player) Music"), "its outline, with its name in it\n\(drawing)")
  }

  @Test(arguments: ["relayout", "show-all", "zoom 102"]) func whenItIsOverTheWordIsGone(command: String) throws {
    let (h, player, _, _, _) = launches.launched()
    #expect(h.run(command).ok)
    launches.settle(h)
    let window = try said(h, of: player)
    #expect(!window.letBe && window.parked, "\(command)")
    #expect(h.ascii().contains("hidden: \(player) Music") && !h.ascii().contains("let be:"), "\(command)\n\(h.ascii())")
  }

  @Test(arguments: ["float", "close"]) func andWhenItIsDockedNoLongerOrGone(way: String) {
    let (h, player, _, _, _) = launches.launched()
    if way == "float" { h.run("float \(player.rawValue)") } else { h.system.close(player) }
    launches.settle(h)
    #expect(h.run("state").state?.windows.contains { $0.letBe } == false)
    #expect(!h.ascii().contains("let be:"), "\(h.ascii())")
  }

  /// The nets read the word where everybody reads it. Were it missing there, they would raise the false alarm that a Mac's did.
  @Test func theNetsGoByWhatStateSays() {
    let (h, player, _, _, _) = launches.launched()
    #expect(h.saidToBeLetBeInATile == [player])
    #expect(h.layoutProblems() == [])
    h.run("relayout")
    launches.settle(h)
    #expect(h.saidToBeLetBeInATile == [])
    #expect(h.layoutProblems() == [])
  }

  /// All three have to hold. A window that Arbor gave up on and has since sent out of view is `letBe` and `parked`: seen in view it is a fault.
  @Test func theExcuseIsForOneThatIsLetBeNotOutOfViewAndInATile() throws {
    let (h, player, _, _, _) = launches.launched()
    let state = h.controller.snapshot()
    let index = try #require(state.windows.firstIndex { $0.id == player })
    #expect(state.letBeInATile == [player])
    var (notLetBe, outOfView, noTile) = (state, state, state)
    notLetBe.windows[index].letBe = false
    outOfView.windows[index].parked = true
    for display in noTile.displays.indices { noTile.displays[display].tiles = [] }
    #expect(notLetBe.letBeInATile == [] && outOfView.letBeInATile == [] && noTile.letBeInATile == [])
  }

  /// The look is a look: it asks macOS nothing, so it is no question of Arbor's in a budget, and no line in a trace being recorded.
  @Test func theNetsLookAsksMacOSNothing() {
    let (h, player, _, _, _) = launches.launched()
    let reads = h.system.focusedWindowReads
    #expect(h.saidToBeLetBeInATile == [player])
    #expect(h.layoutProblems() == [])
    #expect(ScenarioExpectation.check(["visible", "\(player.rawValue)"], harness: h, lastCommandOK: true) == nil)
    #expect(h.system.focusedWindowReads == reads)
    #expect(h.controller.snapshot(askingWhoHasTheKeyboard: false).focused == nil && h.controller.snapshot().focused == player)
  }

  /// On another Space nobody sees it. It is on record, and comes back let be; meanwhile neither command says that it stands in view.
  @Test func whileItIsOnAnotherSpaceNeitherSaysSoAndBackItIsSaidAgain() throws {
    let (h, player, _, _, _) = launches.launched()
    let all = h.system.allWindows().map(\.id)
    for window in all { h.system.setOnActiveSpace(window, false) }
    launches.settle(h)
    #expect(h.controller.windowLetBe == player, "on record")
    #expect(try !said(h, of: player).letBe)
    #expect(!h.ascii().contains("let be:"), "\(h.ascii())")
    #expect(h.saidToBeLetBeInATile == [])
    for window in all { h.system.setOnActiveSpace(window, true) }
    launches.settle(h)
    #expect(try said(h, of: player).letBe)
    #expect(h.ascii().contains("let be: \(player) Music"), "\(h.ascii())")
  }

  @Test func afterAPauseAndAResumeItIsSaidAgain() throws {
    let (h, player, _, _, _) = launches.launched()
    h.run("pause")
    launches.settle(h)
    #expect(h.run("state").state?.windows.contains { $0.letBe } == false)
    h.run("resume")
    launches.settle(h)
    #expect(try said(h, of: player).letBe)
    #expect(h.layoutProblems() == [])
  }

  /// Put on another display between the quit and the launch, it is docked on the one and stands on the other. It is drawn where it stands.
  @Test func standingOnAnotherDisplayItIsDrawnThere() throws {
    let (h, player, _, _, _) = launches.quitWithTheKeyboardInThePlayer()
    let main = try #require(h.system.displayList.first)
    let side = CGRect(x: main.frame.maxX, y: 0, width: 1200, height: 800)
    h.system.plug(DisplaySnapshot(id: DisplayID("side"), frame: side, visibleFrame: side, isMain: false))
    h.system.userMove(player, to: CGRect(x: side.minX + 200, y: 200, width: 400, height: 300))
    h.start()
    launches.settle(h)
    try #require(h.controller.windowLetBe == player && side.contains(h.frame(player)!), "\(h.frame(player)!)")
    #expect(try said(h, of: player).letBe)
    let drawings = h.ascii().components(separatedBy: "\n\n")
    let (onMain, onSide) = (try #require(drawings.first { $0.hasPrefix("display \(main.id)") }), try #require(drawings.first { $0.hasPrefix("display side") }))
    #expect(onSide.contains(":\(player) Music") && onSide.contains("let be: \(player) Music"), "\(onSide)")
    #expect(!onMain.contains(":\(player) Music") && onMain.contains("let be: \(player) Music") && !onMain.contains("hidden:"), "\(onMain)")
  }

  /// A display on which it neither lives nor stands has nothing to say of it.
  @Test func aDisplayItHasNothingToDoWithDoesNotMentionIt() throws {
    let (h, player, _, _, _) = launches.quitWithTheKeyboardInThePlayer()
    let main = try #require(h.system.displayList.first)
    let side = CGRect(x: main.frame.maxX, y: 0, width: 1200, height: 800)
    h.system.plug(DisplaySnapshot(id: DisplayID("side"), frame: side, visibleFrame: side, isMain: false))
    h.start()
    launches.settle(h)
    try #require(h.controller.windowLetBe == player && main.frame.contains(h.frame(player)!))
    let drawings = h.ascii().components(separatedBy: "\n\n")
    #expect(try #require(drawings.first { $0.hasPrefix("display \(main.id)") }).contains("let be: \(player) Music"))
    #expect(try !#require(drawings.first { $0.hasPrefix("display side") }).contains("\(player)"), "\(h.ascii())")
  }

  /// A window that macOS zoomed at a double-click has a slot, and the nets judge it by that. The word is the same, so the drawing says the
  /// same of it: its slot, which is kept, and where it stands.
  @Test func aWindowThatMacOSZoomedIsLetBeTooAndTheDrawingSaysSo() throws {
    let h = Harness()
    let window = h.system.open(app: "Safari", frame: CGRect(x: 300, y: 200, width: 500, height: 400))
    h.start()
    h.run("dock \(window.rawValue) left")
    h.scheduler.advance(by: 5)
    #expect(!h.ascii().contains("let be:"))
    h.system.doubleClickTitleBar(of: window)
    h.scheduler.advance(by: 5)
    #expect(try said(h, of: window).letBe)
    #expect(h.saidToBeLetBeInATile == [], "it is in no tile")
    #expect(h.ascii().contains("let be: \(window) Safari") && h.ascii().contains(":\(window) Safari"), "\(h.ascii())")
    #expect(!h.ascii().contains("hidden:"))
  }
}
