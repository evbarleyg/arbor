import ArborCore
import ArborKit
import ArborTesting
import CoreGraphics
import Foundation
import Testing

/// New windows that open while one window is framed (docs/features/F57-new-windows-while-framed.md).
@Suite @MainActor struct GuestWindowTests {
  /// `[a | b | Desktop]`, framed on `a`. As Arbor ships, the two are arranged in halves and the Desktop has no room.
  func framed(settings: Settings = Settings()) -> (Harness, a: WindowID, b: WindowID) {
    let h = Harness(settings: settings)
    let a = h.system.open(app: "Safari", pid: 11, frame: CGRect(x: 100, y: 100, width: 600, height: 400))
    let b = h.system.open(app: "Notes", pid: 12, frame: CGRect(x: 800, y: 200, width: 500, height: 400))
    h.start()
    h.run("arrange")
    h.run("zoom \(a.rawValue)")
    return (h, a, b)
  }

  let place = CGRect(x: 400, y: 200, width: 500, height: 400)

  func openGuest(_ h: Harness) -> WindowID { h.system.open(app: "Safari", pid: 11, frame: place) }

  @Test func aNewWindowLeavesAndComesBackWithTheViewItOpenedOver() {
    let (h, a, _) = framed()
    let new = openGuest(h)
    #expect(h.frame(new) == place)
    #expect(h.workspace.isFloating(new))
    h.run("neighbor right")
    #expect(!h.system.isVisible(new), "it belongs to Safari's view, which is out of view")
    h.run("back")
    #expect(h.workspace.camera == h.workspace.tree.leaf(containing: a))
    #expect(h.frame(new) == place, "Back brings it back, where it was")
  }

  @Test(arguments: [false, true]) func itIsInViewWheneverItsHostIs(makingWay: Bool) {
    let (h, _, b) = framed(settings: (makingWay ? Settings.makingWay : Settings()).withDesktopColumn)
    let new = openGuest(h)
    h.run("show-all")
    #expect(h.system.isVisible(new))
    if makingWay {
      #expect(isOnDesktop(new, h), "with the Desktop in view it sits there like any floating window")
    } else {
      #expect(h.frame(new) == place, "it was in view and is in view: like any floating window, it is not moved")
    }
    h.run("zoom \(b.rawValue)")
    #expect(!h.system.isVisible(new))
    h.run("desktop")
    #expect(h.system.isVisible(new), "and the Desktop still shows every floating window")
    if !makingWay { #expect(h.frame(new) == place, "where it was") }
  }

  @Test func switchingToAGuestOutOfViewGoesToItsHost() {
    let (h, a, b) = framed()
    let new = openGuest(h)
    h.run("zoom \(b.rawValue)")
    h.scheduler.advance(by: 1)
    h.system.userFocus(new)
    #expect(h.workspace.camera == h.workspace.tree.leaf(containing: a))
    #expect(h.frame(new) == place)
  }

  @Test func movingItKeepsItAGuestAtItsNewPlace() {
    let (h, _, _) = framed()
    let new = openGuest(h)
    let moved = place.offsetBy(dx: 120, dy: 60)
    h.system.userMove(new, to: moved)
    h.run("neighbor right")
    h.run("back")
    #expect(h.frame(new) == moved)
  }

  @Test func dockingItEndsTheVisit() {
    let (h, _, _) = framed()
    let new = openGuest(h)
    h.run("dock \(new.rawValue) right")
    #expect(h.workspace.isDocked(new))
    #expect(h.workspace.guests?[new] == nil)
  }

  @Test func closingTheHostMakesItAnOrdinaryFloatingWindow() {
    let (h, a, b) = framed()
    let new = openGuest(h)
    h.system.close(a)
    h.scheduler.advance(by: 1)
    #expect(h.workspace.guests?[new] == nil)
    #expect(h.workspace.isFloating(new))
    #expect(h.workspace.tree.invariantViolations().isEmpty)
    h.run("zoom \(b.rawValue)")
    #expect(!h.system.isVisible(new))
    h.run("desktop")
    #expect(h.system.isVisible(new))
  }

  @Test func itFollowsAHostThatIsMovedInTheArrangement() {
    let (h, a, _) = framed()
    let new = openGuest(h)
    h.run("show-all")
    h.run("dock \(a.rawValue) down")
    h.run("zoom \(a.rawValue)")
    #expect(h.workspace.guests?[new] == h.workspace.tree.leaf(containing: a))
    #expect(h.system.isVisible(new))
  }

  @Test func aRuleForTheAppWins() {
    var settings = Settings()
    settings.rules = [AppRule(app: "com.example.safari", action: .dock(.right))]
    let (h, _, _) = framed(settings: settings)
    let new = openGuest(h)
    #expect(h.workspace.isDocked(new))
    #expect(h.workspace.guests?[new] == nil)
  }

  @Test func nothingChangesWhenTheViewShowsTheDesktop() {
    for view in ["show-all", "desktop"] {
      let (h, _, _) = framed()
      h.run(view)
      let new = openGuest(h)
      #expect(h.workspace.guests?[new] == nil, "\(view)")
    }
  }

  // MARK: Any view without the Desktop has guests

  /// `[a | b over c]`... with the Desktop between; the view is on the group of `b` and `c`, saved as view 2.
  func onAGroup() -> (Harness, a: WindowID, b: WindowID, c: WindowID) {
    let h = Harness()
    let a = h.system.open(app: "Safari", pid: 11)
    let b = h.system.open(app: "Notes", pid: 12)
    let c = h.system.open(app: "Mail", pid: 13)
    h.start()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) right")
    h.run("dock \(c.rawValue) beside \(b.rawValue) bottom")
    h.run("zoom \(b.rawValue)")
    h.run("out")
    h.run("save-view 2")
    return (h, a, b, c)
  }

  @Test func aWindowOpenedOverAGroupComesBackWithTheGroup() {
    let (h, a, b, _) = onAGroup()
    #expect(h.layout!.desktopFrame == nil)
    let new = h.system.open(app: "Terminal", pid: 14, frame: place)
    h.run("zoom \(a.rawValue)")
    #expect(!h.system.isVisible(new))
    h.run("view 2")
    #expect(h.frame(new) == place)
    // Inside the group only a part of what it opened over is showing.
    h.run("zoom \(b.rawValue)")
    #expect(!h.system.isVisible(new))
    h.run("out")
    #expect(h.frame(new) == place)
  }

  @Test func aGroupThatShrinksToOneWindowKeepsItsGuests() {
    let (h, a, b, c) = onAGroup()
    let new = h.system.open(app: "Terminal", pid: 14, frame: place)
    h.system.close(c)
    #expect(h.workspace.guests?[new] == h.workspace.tree.leaf(containing: b))
    h.run("zoom \(a.rawValue)")
    #expect(!h.system.isVisible(new))
    h.run("zoom \(b.rawValue)")
    #expect(h.frame(new) == place)
  }

  @Test func aWindowOpenedWhileTheDesktopIsATileBelongsToThatView() {
    let h = Harness()
    let ids = ["A", "B", "C", "D", "E"].map { h.system.open(app: $0) }
    h.start()
    h.run("arrange")
    #expect(h.layout!.desktopFrame == nil)
    let new = h.system.open(app: "Terminal", pid: 14, frame: place)
    h.run("zoom \(ids[0].rawValue)")
    #expect(!h.system.isVisible(new))
    h.run("back")
    #expect(h.frame(new) == place)
  }

  @Test func aWindowOpenedDuringAPauseOverAFramedWindowStaysWithIt() {
    let (h, a, _) = framed()
    h.run("pause")
    let new = openGuest(h)
    h.run("resume")
    #expect(h.workspace.camera == h.workspace.tree.leaf(containing: a))
    #expect(h.frame(new) == place, "resuming must not take away what opened meanwhile")
    h.run("neighbor right")
    #expect(!h.system.isVisible(new))
    h.run("back")
    #expect(h.frame(new) == place)
  }

  /// To macOS each native tab is a window of its own. To a person, and to Arbor, the group is one window.
  @Test func aGuestWithNativeTabsStaysAGuestWhenItsTabChanges() throws {
    let (h, a, _) = framed()
    let new = openGuest(h)
    let tab = try #require(h.system.openTab(in: new))
    #expect(h.workspace.guests?[tab] == h.workspace.tree.leaf(containing: a))
    h.run("neighbor right")
    #expect(!h.system.isVisible(tab))
    h.run("back")
    #expect(h.frame(tab) == place)
  }

  /// Unpinned over a framed window it is where it was a moment ago, and must not be gone after the next move.
  @Test func aWindowUnpinnedOverAViewWithoutTheDesktopStaysWithThatView() {
    let (h, _, _) = framed()
    let call = openGuest(h)
    h.run("pin \(call.rawValue)")
    h.run("neighbor right")
    #expect(h.system.isVisible(call))
    h.run("back")
    h.run("unpin \(call.rawValue)")
    let left = h.frame(call)!
    h.run("neighbor right")
    #expect(!h.system.isVisible(call))
    h.run("back")
    #expect(h.frame(call) == left)
  }

  @Test func stateSaysWhoseGuestAWindowIs() {
    let (h, a, b) = framed()
    let new = openGuest(h)
    let state = h.controller.snapshot()
    #expect(state.window(new)?.guestOf == h.workspace.tree.leaf(containing: a))
    #expect(state.window(a)?.guestOf == nil && state.window(b)?.guestOf == nil)
  }

  // MARK: Who is in front

  @Test func comingBackTheGuestHasTheFocusItHadSoItIsInFrontOfItsHost() {
    for command in ["back", "view 1", "zoom %a"] {
      let (h, a, _) = framed()
      h.run("save-view 1")
      let new = openGuest(h)
      // Over the host only: the pointer must not decide who covers whom.
      h.system.cursor = CGPoint(x: 1200, y: 700)
      h.run("neighbor right")
      h.run(command.replacingOccurrences(of: "%a", with: String(a.rawValue)))
      #expect(h.workspace.camera == h.workspace.tree.leaf(containing: a))
      #expect(h.system.focusedWindow() == new, "`\(command)` focused and so raised the host, which fills the display")
    }
  }

  /// ⌘Tab or a click in the Dock: macOS has raised the host before Arbor hears of it and brings the guest back.
  ///
  /// Rewritten to the decision. This test said that the guest ends in front, which took a raise over the very window its person had just
  /// switched to. QUESTIONS Q20 and Q25: the window switched to comes to the front, Arbor raises nothing else, and going out of view
  /// and coming back changes no window's place in the order. The ways to the guest are in `RaisesNothingElseTests`.
  @Test func switchingToTheHostFromElsewhereLeavesTheHostInFront() {
    let h = Harness()
    let ids = ["A", "B", "C", "D", "E"].enumerated().map { h.system.open(app: $1, pid: 21 + Int32($0)) }
    h.start()
    h.run("arrange")
    h.run("zoom \(ids[0].rawValue)")
    let new = h.system.open(app: "Terminal", pid: 14, frame: CGRect(x: 40, y: 60, width: 500, height: 400))
    h.run("zoom \(ids[4].rawValue)")
    h.scheduler.advance(by: 1)
    #expect(!h.system.isVisible(new))
    h.system.clearRaiseLog()
    h.system.userFocus(ids[0])
    #expect(h.system.isVisible(new))
    #expect(h.frame(new)!.overlaps(h.frame(ids[0])!))
    #expect(h.system.focusedWindow() == ids[0], "the focus stays where the user put it")
    #expect(h.system.windowsFrontToBack().first == ids[0], "and so does the front: \(h.system.windowsFrontToBack())")
    #expect(h.system.raiseLog.isEmpty)
    // A switch to the guest brings it to the front, and the view stays.
    h.system.userFocus(new)
    #expect(h.system.windowsFrontToBack().first == new && h.workspace.camera == h.workspace.tree.leaf(containing: ids[0]))
  }

  @Test func aHostThatWasUsedLastGetsTheFocusBack() {
    let (h, a, _) = framed()
    _ = openGuest(h)
    h.system.userFocus(a)
    h.run("neighbor right")
    h.run("back")
    #expect(h.system.focusedWindow() == a)
  }

  /// It used to leave the framed view. Since QUESTIONS Q29 the key does the same for every floating window (Controller+Fill.swift).
  @Test func theShortcutForFramingPressedOnAGuestFillsTheViewWithItAndTheViewStays() {
    let (h, a, _) = framed()
    let new = openGuest(h)
    #expect(h.system.focusedWindow() == new)
    let (had, host) = (h.frame(new), h.frame(a))
    let result = h.run("zoom")
    #expect(result.ok)
    #expect(h.workspace.camera == h.workspace.tree.leaf(containing: a), "\(result.message)")
    #expect(h.frame(new) == host && h.frame(a) == host, "as large as its host, which is behind it and has not moved")
    #expect(h.workspace.guests?[new] != nil, "it is still a guest of the view it opened over")
    h.run("zoom")
    #expect(h.frame(new) == had)
    #expect(h.workspace.camera == h.workspace.tree.leaf(containing: a))
    #expect(h.system.focusedWindow() == new)
  }

  @Test func theSettingTurnsItOff() {
    var settings = Settings()
    settings.newWindowsWhileFramed = "float"
    let (h, _, _) = framed(settings: settings)
    let new = openGuest(h)
    h.run("neighbor right")
    h.run("back")
    #expect(h.workspace.guests?[new] == nil)
    #expect(!h.system.isVisible(new), "as before: it waits on the Desktop")
  }

  @Test func guestsSurviveARestartAndOldStateStillLoads() throws {
    let (old, a, _) = framed()
    let new = openGuest(old)
    old.controller.saveNow()
    let data = try JSONEncoder().encode(old.store.saved!)
    let saved = try JSONDecoder().decode(PersistedState.self, from: data)
    #expect(saved.workspaces[old.display]?.guests?[new] == old.workspace.tree.leaf(containing: a))

    var object = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(Workspace())) as? [String: Any])
    object["guests"] = nil
    let bare = try JSONDecoder().decode(Workspace.self, from: JSONSerialization.data(withJSONObject: object))
    #expect(bare.guests == nil)
  }

  @Test func quittingPutsAGuestOutOfViewBackOnScreen() {
    let (h, _, b) = framed()
    let new = openGuest(h)
    h.run("zoom \(b.rawValue)")
    h.controller.shutdown()
    #expect(h.system.isVisible(new))
  }
}
