import ArborCore
import ArborKit
import ArborTesting
import CoreGraphics
import Testing

@MainActor private let laptop = FakeWindowSystem.standardDisplay
private let studio = DisplaySnapshot(
  id: DisplayID("studio"), frame: CGRect(x: 1440, y: 0, width: 2560, height: 1440),
  visibleFrame: CGRect(x: 1440, y: 25, width: 2560, height: 1415), isMain: false)

/// An undo step is in the coordinates of the displays as they stood when it was taken. The lid had a back door (K1811).
@Suite @MainActor struct UndoAcrossDisplaysTests {
  /// Notes floats in full view on the big display; Safari floated at 1600,100 and was docked there: one step to undo.
  func atTheDesk() -> (Harness, notes: WindowID, safari: WindowID) {
    let h = Harness(displays: [laptop, studio])
    let notes = h.system.open(app: "Notes", frame: CGRect(x: 2530, y: 500, width: 600, height: 400))
    let safari = h.system.open(app: "Safari", frame: CGRect(x: 1600, y: 100, width: 500, height: 400))
    h.start()
    h.system.cursor = CGPoint(x: 2000, y: 400)
    h.run("dock \(safari.rawValue) left")
    #expect(!h.controller.undoHistory.steps(.undo, on: studio.id).isEmpty)
    return (h, notes, safari)
  }

  var clamshell: DisplaySnapshot {
    var alone = studio
    alone.frame.origin = .zero
    alone.visibleFrame.origin = CGPoint(x: 0, y: 25)
    alone.isMain = true
    return alone
  }

  func closeTheLid(_ h: Harness) {
    for window in h.system.allWindows() { h.system.moveSilently(window.id, to: window.frame.offsetBy(dx: -1440, dy: 0)) }
    h.system.setDisplays([clamshell])
    h.system.cursor = CGPoint(x: 600, y: 400)
    h.scheduler.advance(by: 3)
  }

  /// Nothing to undo or redo on any display, and asking moves nothing.
  func expectNoWayBack(_ h: Harness, sourceLocation: SourceLocation = #_sourceLocation) {
    let frames = h.system.allWindows().map(\.frame)
    let workspaces = h.controller.workspaces
    for command in ["undo", "redo"] {
      #expect(!h.run(command).ok, "\(command)", sourceLocation: sourceLocation)
      h.scheduler.advance(by: 1)
    }
    for command in ["home", "relayout"] {
      h.run(command)
      h.scheduler.advance(by: 1)
    }
    #expect(h.system.allWindows().map(\.frame) == frames, sourceLocation: sourceLocation)
    #expect(h.controller.workspaces == workspaces, sourceLocation: sourceLocation)
  }

  /// Safari came back at 1600,100, its old place in the world: 1440 points from where it had floated on the display.
  @Test func theLidEndsTheHistory() {
    let (h, _, _) = atTheDesk()
    closeTheLid(h)
    expectNoWayBack(h)
  }

  @Test func soDoesADisplayMovedInSystemSettings() {
    let (h, _, _) = atTheDesk()
    for window in h.system.allWindows() { h.system.moveSilently(window.id, to: window.frame.offsetBy(dx: 0, dy: -500)) }
    var moved = studio
    moved.frame.origin.y = -500
    moved.visibleFrame.origin.y = -475
    h.system.setDisplays([laptop, moved])
    h.system.cursor = CGPoint(x: 2000, y: 0)
    expectNoWayBack(h)
  }

  /// A step can span displays, so the laptop's history ends with the big display's when the laptop's corner moves too:
  /// here the big display is the main one and is unplugged.
  @Test func theHistoryEndsOnEveryDisplayNotOnlyTheOneThatMoved() {
    var desk = clamshell
    desk.id = DisplayID("desk")
    var builtin = laptop
    builtin.id = DisplayID("builtin")
    builtin.isMain = false
    builtin.frame.origin = CGPoint(x: -1440, y: 300)
    builtin.visibleFrame.origin = CGPoint(x: -1440, y: 325)
    let h = Harness(displays: [desk, builtin])
    let mail = h.system.open(app: "Mail", frame: CGRect(x: -1200, y: 500, width: 500, height: 400))
    h.start()
    h.system.cursor = CGPoint(x: -700, y: 700)
    h.run("dock \(mail.rawValue) left")
    #expect(!h.controller.undoHistory.steps(.undo, on: builtin.id).isEmpty)

    for window in h.system.allWindows() { h.system.moveSilently(window.id, to: window.frame.offsetBy(dx: 1440, dy: -300)) }
    builtin.isMain = true
    builtin.frame.origin = .zero
    builtin.visibleFrame.origin = CGPoint(x: 0, y: 25)
    h.system.setDisplays([builtin])
    h.system.cursor = CGPoint(x: 700, y: 400)
    h.scheduler.advance(by: 3)
    expectNoWayBack(h)
  }

  /// A resume is a start on what the pause saved, with the history of before it.
  @Test func soDoesALidThatClosesDuringAPause() {
    let (h, _, _) = atTheDesk()
    h.run("pause")
    closeTheLid(h)
    h.run("resume")
    h.scheduler.advance(by: 3)
    expectNoWayBack(h)
  }

  // MARK: What does not end it

  /// A case from before the release, by hand and with one display: dock, change "Looks like" in System Settings, ⌃⌥Z. Safari went back to
  /// 1800,500 on a display now 1920 wide: 120 of its 700 points showed, and `home` did not fetch it.
  @Test func soDoesAnotherResolution() {
    let big = DisplaySnapshot(
      id: DisplayID("big"), frame: CGRect(x: 0, y: 0, width: 2560, height: 1440),
      visibleFrame: CGRect(x: 0, y: 25, width: 2560, height: 1415), isMain: true)
    let h = Harness(displays: [big])
    let safari = h.system.open(app: "Safari", frame: CGRect(x: 1800, y: 500, width: 700, height: 500))
    h.start()
    h.run("dock \(safari.rawValue) left")
    var scaled = big
    scaled.frame.size = CGSize(width: 1920, height: 1080)
    scaled.visibleFrame.size = CGSize(width: 1920, height: 1055)
    let mark = h.system.frameLog.count
    h.system.setDisplays([scaled])
    h.system.report(safari, userInitiated: !h.system.frameLog[mark...].contains { $0.window == safari })
    h.scheduler.advance(by: 10)
    expectNoWayBack(h)
    #expect(h.controller.workspaces[big.id]?.isDocked(safari) == true)
    #expect(scaled.visibleFrame.contains(h.frame(safari)!))
  }

  /// The same by another road: the scaling is changed while Arbor is paused, or has lost its permission. state.json has the
  /// corners only, but a start after a pause still knows the displays as they were.
  @Test(arguments: ["a pause", "the permission taken away"]) func soDoesAnotherResolutionWhileArborIsNotLooking(why: String) {
    let big = DisplaySnapshot(
      id: DisplayID("big"), frame: CGRect(x: 0, y: 0, width: 2560, height: 1440),
      visibleFrame: CGRect(x: 0, y: 25, width: 2560, height: 1415), isMain: true)
    let h = Harness(displays: [big])
    if why != "a pause" { h.watchAccessibility() }
    let safari = h.system.open(app: "Safari", frame: CGRect(x: 1800, y: 500, width: 700, height: 500))
    h.start()
    h.run("dock \(safari.rawValue) left")
    #expect(!h.controller.undoHistory.steps(.undo, on: big.id).isEmpty)
    if why == "a pause" {
      h.run("pause")
    } else {
      h.revokeAccessibility()
      h.scheduler.advance(by: 5)
    }
    #expect(!h.controller.isRunning)
    var scaled = big
    scaled.frame.size = CGSize(width: 1920, height: 1080)
    scaled.visibleFrame.size = CGSize(width: 1920, height: 1055)
    h.system.setDisplays([scaled])
    h.scheduler.advance(by: 5)
    if why == "a pause" { h.run("resume") } else { h.grantAccessibility() }
    h.scheduler.advance(by: 10)
    #expect(h.controller.isRunning)
    expectNoWayBack(h)
    #expect(h.controller.workspaces[big.id]?.isDocked(safari) == true)
    #expect(scaled.visibleFrame.contains(h.frame(safari)!), "\(why): Safari is at \(h.frame(safari)!)")
  }

  @Test func theDockLeavesTheHistoryAlone() {
    let (h, _, safari) = atTheDesk()
    var smaller = studio
    smaller.visibleFrame.size.height -= 70
    h.system.setDisplays([laptop, smaller])
    h.scheduler.advance(by: 1)
    #expect(h.run("undo").ok)
    #expect(h.controller.workspaces[studio.id]?.isFloating(safari) == true)
  }

  @Test func aPauseWithTheDisplaysAsTheyWereLeavesTheHistoryAlone() {
    let (h, _, safari) = atTheDesk()
    h.run("pause")
    h.run("resume")
    h.scheduler.advance(by: 3)
    #expect(h.run("undo").ok)
    #expect(h.controller.workspaces[studio.id]?.isFloating(safari) == true)
  }

  // MARK: Every road, so that there is no further one (triage's table)

  enum Change: String, CaseIterable { case corner = "a corner moves", size = "a size changes", set = "a display goes" }
  enum Moment: String, CaseIterable {
    case running = "while Arbor runs", paused = "during a pause", blind = "while the permission is gone"
  }

  /// Safari floated at the far right of the big display, was docked, and the dock was undone and redone, so that there is
  /// a step each way. Then the displays change. After another frame of a display that stays, both are refused and no
  /// window is asked to move. After a display only went, the others keep their history (F19's decision): then whatever
  /// undo and redo do, every window in view can be reached.
  @Test(arguments: Change.allCases, Moment.allCases) func everyRoadAcrossAChangeOfTheDisplays(change: Change, moment: Moment) {
    let h = Harness(displays: [laptop, studio])
    if moment == .blind { h.watchAccessibility() }
    let safari = h.system.open(app: "Safari", frame: CGRect(x: 3200, y: 500, width: 700, height: 500))
    let notes = h.system.open(app: "Notes", frame: CGRect(x: 1700, y: 300, width: 600, height: 400))
    h.start()
    h.system.cursor = CGPoint(x: 2000, y: 400)
    h.system.userFocus(safari)
    h.run("dock \(safari.rawValue) left")
    h.run("dock \(notes.rawValue) right")
    h.run("undo")
    #expect(!h.controller.undoHistory.steps(.undo, on: studio.id).isEmpty)
    #expect(!h.controller.undoHistory.steps(.redo, on: studio.id).isEmpty)

    switch moment {
    case .running: break
    case .paused: h.run("pause")
    case .blind:
      h.revokeAccessibility()
      h.scheduler.advance(by: 5)
    }
    var after = studio
    switch change {
    case .corner:
      after.frame.origin.y = 300
      after.visibleFrame.origin.y = 325
      for window in h.system.allWindows() { h.system.moveSilently(window.id, to: window.frame.offsetBy(dx: 0, dy: 300)) }
      h.system.setDisplays([laptop, after])
    case .size:
      after.frame.size = CGSize(width: 1920, height: 1080)
      after.visibleFrame.size = CGSize(width: 1920, height: 1055)
      h.system.setDisplays([laptop, after])
    case .set:
      // The laptop's own display goes to sleep in a way that leaves the big one its corner.
      h.system.setDisplays([after])
    }
    h.scheduler.advance(by: 5)
    switch moment {
    case .running: break
    case .paused: h.run("resume")
    case .blind: h.grantAccessibility()
    }
    h.scheduler.advance(by: 10)
    #expect(h.controller.isRunning)
    h.system.cursor = after.frame.center

    let note = "\(change.rawValue) \(moment.rawValue)"
    if change == .set {
      for command in ["undo", "redo", "redo", "undo", "undo"] {
        _ = h.run(command)
        h.scheduler.advance(by: 2)
        for window in h.system.allWindows() where !h.controller.parked.contains(window.id) {
          #expect(h.system.isVisible(window.id), "\(note), \(command): \(window.id) is at \(window.frame)")
        }
      }
    } else {
      // Not `expectNoWayBack`, which also lays out again: after a start on changed displays a floating window that was
      // pushed aside takes its new place only with the next layout, in view before and after. Not undo's affair.
      let before = (h.controller.workspaces, h.system.allWindows().map(\.frame))
      h.system.clearFrameLog()
      for command in ["undo", "redo", "undo"] {
        let result = h.run(command)
        h.scheduler.advance(by: 1)
        #expect(!result.ok && result.message.hasPrefix("nothing to \(command)"), "\(note), \(command): \(result.message)")
      }
      #expect(h.system.frameLog.isEmpty, "\(note): no window is asked to move")
      #expect(h.controller.workspaces == before.0 && h.system.allWindows().map(\.frame) == before.1, "\(note)")
      for window in h.system.allWindows() where !h.controller.parked.contains(window.id) {
        #expect(h.system.isVisible(window.id), "\(note): \(window.id) is at \(window.frame)")
      }
    }
  }
}
