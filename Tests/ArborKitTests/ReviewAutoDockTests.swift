import ArborCore
import ArborKit
import ArborTesting
import CoreGraphics
import Foundation
import Testing

/// Where apps put their new windows in these tests.
private let opening = CGRect(x: 300, y: 200, width: 640, height: 420)

private let side = DisplaySnapshot(
  id: DisplayID("side"), frame: CGRect(x: 1440, y: 0, width: 1920, height: 1080),
  visibleFrame: CGRect(x: 1440, y: 0, width: 1920, height: 1080), isMain: false)

/// The settings a person has who ticked Dock New Windows and changed nothing else.
@MainActor private func ticked(
  displays: [DisplaySnapshot] = [FakeWindowSystem.standardDisplay], configure: (inout Settings) -> Void = { _ in }
) -> Harness {
  var settings = Settings()
  settings.newWindows = "dock"
  configure(&settings)
  let h = Harness(displays: displays, settings: settings)
  h.start()
  return h
}

extension Harness {
  fileprivate func docked(_ window: WindowID) -> Bool { controller.workspaces.values.contains { $0.isDocked(window) } }
  fileprivate func floats(_ window: WindowID) -> Bool { controller.workspaces.values.contains { $0.isFloating(window) } }
  fileprivate var slots: [WindowID: CGRect] { layout?.windowFrames ?? [:] }
  fileprivate func expectSound(sourceLocation: SourceLocation = #_sourceLocation) {
    for (display, workspace) in controller.workspaces {
      #expect(workspace.tree.invariantViolations().isEmpty, "\(display)", sourceLocation: sourceLocation)
    }
    for (display, layout) in controller.layouts {
      #expect(layout.tiles.isEmpty, "tiles on \(display)", sourceLocation: sourceLocation)
      for (window, slot) in layout.windowFrames {
        #expect(frame(window)?.approximatelyEquals(slot, tolerance: 1) == true, "\(window)", sourceLocation: sourceLocation)
      }
    }
  }
}

/// An independent review of automatic docking (docs/features/F23-automatic-docking.md): what it meets in the rest of Arbor,
/// and what apps do in the moment a window opens.
@MainActor
@Suite struct ReviewAutoDockTests {
  // MARK: Windows somebody asked for in another way

  @Test func aWindowThatOpensBecauseItsAppWasSummonedIsSummonedNotDocked() throws {
    let h = ticked()
    let (a, b) = (h.system.open(app: "Safari"), h.system.open(app: "Mail"))
    let (tree, slots) = (h.workspace.tree, h.slots)
    #expect(h.run("summon Terminal").message == "opening Terminal")
    let t = h.system.open(app: "Terminal")
    #expect(h.floats(t), "summoned for ten seconds, it must not take a place for good")
    #expect(h.workspace.summoned?.window == t)
    #expect(h.workspace.tree == tree)
    #expect(h.slots == slots)
    #expect(h.frame(a) == slots[a] && h.frame(b) == slots[b])
    // Terminals change their titles all the time, and a new title is when rules are asked again.
    h.system.setTitle(t, "zsh")
    #expect(h.floats(t))
    #expect(h.workspace.tree == tree)
    // And it goes away like any summoned window.
    #expect(h.run("summon Terminal").ok)
    #expect(!h.system.isVisible(t))
    h.expectSound()
  }

  @Test func aRuleThatNamesTheSummonedAppIsStillObeyed() {
    let h = ticked { $0.rules = [AppRule(app: "com.example.terminal", action: .dock(.left))] }
    _ = h.system.open(app: "Safari")
    h.run("summon Terminal")
    let t = h.system.open(app: "Terminal")
    #expect(h.docked(t), "a docked window has a place, and the place wins (F53)")
  }

  @Test func aRuleForAnyAppLeavesASummonedWindowAloneToo() {
    let h = ticked {
      $0.newWindows = "float"
      $0.rules = [AppRule(app: "*", action: .dock(.left))]
    }
    _ = h.system.open(app: "Safari")
    h.run("summon Terminal")
    let t = h.system.open(app: "Terminal")
    #expect(h.floats(t))
    #expect(h.workspace.summoned?.window == t)
  }

  @Test func anotherAppsWindowStillDocksWhileASummonIsAwaited() {
    let h = ticked()
    _ = h.system.open(app: "Safari")
    h.run("summon Terminal")
    let n = h.system.open(app: "Notes")
    #expect(h.docked(n))
  }

  @Test func anArrangementThatWaitsForItsWindowsIsNotDisturbedByOtherNewWindows() {
    let h = ticked()
    let safari = h.system.open(app: "Safari")
    #expect(h.run("layout --open Safari | Mail | Notes").ok)
    let mail = h.system.open(app: "Mail")
    #expect(h.workspace.tree.allWindows == [safari, mail], "it took the place the line kept for it")
    // Apps that start bring more than was asked for: a second window from last time, "What's New".
    let extra = h.system.open(app: "Mail")
    let other = h.system.open(app: "Music")
    #expect(h.floats(extra) && h.floats(other), "docked, they would make another arrangement of it, and Notes would find no place")
    let notes = h.system.open(app: "Notes")
    #expect(h.workspace.tree.allWindows == [safari, mail, notes])
    // Everybody is here: new windows dock again.
    let late = h.system.open(app: "Terminal")
    #expect(h.docked(late))
    h.expectSound()
  }

  // MARK: Windows that are not Arbor's to arrange

  @Test func anExcludedAppsWindowIsLeftAloneWhateverTheRulesSay() {
    let h = ticked { $0.rules = [AppRule(app: "*", action: .dock(.left))] }
    _ = h.system.open(app: "Safari")
    h.run("exclude com.example.zoom")
    let (workspace, slots) = (h.workspace, h.slots)
    h.system.clearFrameLog()
    let z = h.system.open(app: "Zoom")
    #expect(h.workspace == workspace)
    #expect(h.slots == slots)
    #expect(h.frame(z) == opening)
    #expect(h.system.frameLog.isEmpty, "nothing moves, the newcomer least of all")
  }

  // MARK: Taking one docking back

  @Test func floatTakesOneDockingBack() {
    let h = ticked()
    let (a, b) = (h.system.open(app: "Safari"), h.system.open(app: "Mail"))
    let slots = h.slots
    let n = h.system.open(app: "Notes", frame: CGRect(x: 200, y: 150, width: 800, height: 500))
    #expect(h.docked(n))
    #expect(h.run("float \(n.rawValue)").ok)
    #expect(h.floats(n))
    #expect(h.frame(n)?.size == CGSize(width: 800, height: 500), "it has the size it opened with")
    #expect(h.system.isVisible(n))
    for window in [a, b] { #expect(h.slots[window]?.approximatelyEquals(slots[window]!, tolerance: 1) == true, "\(window)") }
    // And no later title docks it again.
    h.system.setTitle(n, "Shopping list")
    #expect(h.floats(n))
    h.expectSound()
  }

  // MARK: What apps do in the moment a window opens

  @Test func anAppThatPutsItsNewWindowElsewhereAMomentLaterFindsItBackInItsSlot() {
    let h = ticked()
    _ = h.system.open(app: "Safari")
    let n = h.system.open(app: "Mail")
    let tree = h.workspace.tree
    // The frame it was reported with was a placeholder: the app restores the one it saved last time.
    h.system.userMove(n, to: CGRect(x: 100, y: 100, width: 900, height: 600))
    h.scheduler.advance(by: 2)
    #expect(h.workspace.tree == tree)
    h.expectSound()
  }

  // MARK: Windows that come and go

  @Test func aWindowThatClosesWhileItIsOfferedItsSlotLeavesNothingBehind() {
    let h = ticked()
    let a = h.system.open(app: "Safari")
    let before = h.workspace
    var closed = false
    h.system.willSetFrame = { [system = h.system] window, _ in
      guard window != a, !closed else { return }
      closed = true
      system.close(window)
    }
    let n = h.system.open(app: "Popup")
    #expect(closed)
    #expect(!h.workspace.contains(n))
    #expect(h.workspace.tree == before.tree)
    h.expectSound()
  }

  @Test func aNeighbourThatClosesWhileRoomIsMadeLeavesTheNewWindowItsPlace() {
    let h = ticked()
    let (a, b) = (h.system.open(app: "Safari"), h.system.open(app: "Mail"))
    var closed = false
    // Gone when Arbor asks it to make room. macOS says so a moment later, from the run loop.
    h.system.willSetFrame = { [system = h.system] window, _ in
      guard window == b, !closed else { return }
      closed = true
      system.remove(b)
    }
    let n = h.system.open(app: "Notes")
    h.system.willSetFrame = nil
    #expect(closed)
    h.controller.windowDestroyed(b)
    h.system.deliverEchoes()
    h.scheduler.advance(by: 2)
    #expect(!h.workspace.contains(b))
    #expect(h.workspace.contains(a) && h.workspace.contains(n))
    h.expectSound()
  }

  @Test(arguments: [false, true])
  func aBurstThatOpensAndClosesAgainGivesTheArrangementBack(oldestFirst: Bool) {
    let h = ticked()
    let (a, b) = (h.system.open(app: "Safari"), h.system.open(app: "Mail"))
    h.run("resize \(a.rawValue) right 120")
    h.system.userFocus(a)
    let slots = h.slots
    let burst = (0..<10).map { _ in h.system.open(app: "Browser", pid: 2000) }
    h.expectSound()
    for window in oldestFirst ? burst : burst.reversed() { h.system.close(window) }
    h.scheduler.advance(by: 2)
    #expect(h.slots[a]?.approximatelyEquals(slots[a]!, tolerance: 1) == true, "\(String(describing: h.slots[a])) was \(slots[a]!)")
    #expect(h.slots[b]?.approximatelyEquals(slots[b]!, tolerance: 1) == true, "\(String(describing: h.slots[b])) was \(slots[b]!)")
    h.expectSound()
  }

  // MARK: The view and the keyboard

  @Test func withNoRoomInAViewWithoutTheDesktopTheWindowStaysInSightWhereItOpened() throws {
    let h = ticked { $0.makeRoom = false }
    let (a, b, c) = (
      h.system.open(app: "Safari", minimumSize: CGSize(width: 500, height: 600)),
      h.system.open(app: "Mail", minimumSize: CGSize(width: 500, height: 600)), h.system.open(app: "Notes")
    )
    _ = c
    let leaf = try #require(h.workspace.tree.leaf(containing: a))
    let group = try #require(h.workspace.tree.parent(of: leaf))
    guard group != h.workspace.tree.root else { return }
    h.run("zoom-node \(group.rawValue)")
    _ = b
    let camera = h.workspace.camera
    let n = h.system.open(app: "Terminal")
    #expect(h.workspace.camera == camera)
    if h.floats(n) {
      #expect(h.frame(n) == opening)
      #expect(h.system.isVisible(n))
      #expect(!h.controller.parked.contains(n))
    }
    h.expectSound()
  }

  @Test func theKeyboardAndTheViewStayWhileABackgroundAppOpensWindows() {
    let h = ticked()
    let (a, b) = (h.system.open(app: "Safari"), h.system.open(app: "Mail"))
    h.system.userFocus(a)
    let camera = h.workspace.camera
    h.system.echoes.keyboard = false
    let focusCalls = h.system.focusLog.count
    for _ in 0..<4 { _ = h.system.open(app: "Chat", pid: 3000) }
    #expect(h.system.focused == a)
    #expect(h.system.focusLog.count == focusCalls, "Arbor focuses nothing")
    #expect(h.workspace.camera == camera)
    #expect(h.slots[a] != nil && h.slots[b] != nil)
    h.expectSound()
  }

  // MARK: Two displays

  @Test func aBurstOnOneDisplayLeavesTheOtherAlone() {
    let h = ticked(displays: [FakeWindowSystem.standardDisplay, side])
    let a = h.system.open(app: "Safari")
    let s = h.system.open(app: "Mail", frame: CGRect(x: 1600, y: 100, width: 800, height: 600))
    let mainBefore = h.controller.workspaces[h.display]
    h.system.echoes.keyboard = false
    // No focus report in between: the window docked a moment ago on the side display is no neighbour here, and the other way round.
    let t = h.system.open(app: "Notes", frame: CGRect(x: 1700, y: 100, width: 800, height: 600))
    #expect(h.controller.workspaces[side.id]?.isDocked(t) == true)
    #expect(h.controller.workspaces[h.display] == mainBefore)
    let m = h.system.open(app: "Terminal")
    #expect(h.controller.workspaces[h.display]?.isDocked(m) == true)
    #expect(h.controller.workspaces[side.id]?.tree.allWindows.sorted() == [s, t].sorted())
    _ = a
    h.expectSound()
  }
}
