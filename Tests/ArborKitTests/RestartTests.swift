import ArborCore
import ArborKit
import ArborTesting
import CoreGraphics
import Foundation
import Testing

@MainActor private let main = FakeWindowSystem.standardDisplay
private let side = DisplaySnapshot(
  id: DisplayID("side"), frame: CGRect(x: 1440, y: 0, width: 1280, height: 800),
  visibleFrame: CGRect(x: 1440, y: 0, width: 1280, height: 800), isMain: false)

/// Save, quit, start again.
@Suite @MainActor struct RestartTests {
  /// A new Arbor process that sees `windows` (same numbers unless `renumber` maps them).
  func relaunch(
    _ old: Harness, displays: [DisplaySnapshot] = [main], keeping keep: (WindowSnapshot) -> Bool = { _ in true }
  ) -> Harness {
    let h = Harness(displays: displays, saved: old.store.saved)
    var next: UInt32 = 101
    for window in old.system.allWindows() {
      // The fake numbers windows in order; fill the gaps so numbers stay the same.
      while next < window.id.rawValue {
        let filler = h.system.open(app: "Filler")
        h.system.close(filler)
        next += 1
      }
      let id = h.system.open(
        app: window.appName, bundleID: window.bundleID, title: window.title, pid: window.pid, frame: window.frame)
      if !keep(window) { h.system.close(id) }
      next += 1
    }
    return h
  }

  @Test func nothingMovesAndNothingChangesWhenNothingChanged() {
    let old = Harness()
    let a = old.system.open(app: "Safari", frame: CGRect(x: 100, y: 100, width: 600, height: 400))
    let b = old.system.open(app: "Notes", frame: CGRect(x: 300, y: 200, width: 600, height: 400))
    let c = old.system.open(app: "Mail", frame: CGRect(x: 500, y: 300, width: 600, height: 400))
    _ = old.system.open(app: "Calculator", frame: CGRect(x: 560, y: 300, width: 320, height: 300))
    old.start()
    old.run("dock \(a.rawValue) left")
    old.run("dock \(b.rawValue) right")
    old.run("dock \(c.rawValue) beside \(a.rawValue) bottom")
    old.run("zoom \(c.rawValue)")
    old.run("save-view 1")
    old.run("back")
    // Killed, not quit: quitting puts docked windows back where they floated (F48; the next test).
    old.controller.saveNow()
    let saved = old.store.saved

    let h = relaunch(old)
    h.start()
    #expect(h.system.frameLog.isEmpty, "\(h.system.frameLog)")
    h.scheduler.runPending()
    #expect(h.store.saved == saved)
  }

  @Test func afterAQuitEachDockedWindowMovesOnceIntoItsSlotAndNothingElseChanges() {
    let old = Harness()
    let a = old.system.open(app: "Safari", frame: CGRect(x: 100, y: 100, width: 600, height: 400))
    let b = old.system.open(app: "Notes", frame: CGRect(x: 300, y: 200, width: 600, height: 400))
    let c = old.system.open(app: "Mail", frame: CGRect(x: 500, y: 300, width: 600, height: 400))
    let f = old.system.open(app: "Calculator", frame: CGRect(x: 560, y: 300, width: 320, height: 300))
    old.start()
    old.run("dock \(a.rawValue) left")
    old.run("dock \(b.rawValue) right")
    old.run("dock \(c.rawValue) beside \(a.rawValue) bottom")
    old.run("zoom \(c.rawValue)")
    old.run("save-view 1")
    old.run("back")
    let slots = old.layout?.windowFrames
    old.controller.shutdown()
    // But for where the quit left the windows, which only a quit's file says.
    var saved = old.store.saved
    saved?.leftAt = nil

    let h = relaunch(old)
    h.start()
    #expect(h.layout?.windowFrames == slots)
    // A new run knows nothing of them, so each is asked for the size where the quit left it, and then goes.
    for window in [a, b, c] {
      #expect(movesWithoutWaste(h, of: window) == 1, "\(window)")
      #expect(FakeWindowSystem.detour(h.system.road(of: window)) == nil, "\(window)")
    }
    #expect(!h.system.frameLog.contains { $0.window == f })
    expectWindowsMatchLayout(h, on: h.display)
    h.scheduler.runPending()
    #expect(h.store.saved == saved)
  }

  @Test func aSurvivingWindowIsNotPulledToAnotherDisplayBecauseItsTwinClosed() {
    // Two terminals with the same title, one docked on each display.
    let old = Harness(displays: [main, side])
    let a = old.system.open(app: "Terminal", title: "zsh", frame: CGRect(x: 100, y: 100, width: 600, height: 400))
    let b = old.system.open(app: "Terminal", title: "zsh", frame: CGRect(x: 1600, y: 100, width: 600, height: 400))
    old.start()
    old.run("dock \(a.rawValue) left")
    old.run("dock \(b.rawValue) left")
    #expect(old.controller.workspaceID(containing: b) == side.id)
    old.controller.shutdown()

    // The one on the main display is closed while Arbor is not running.
    let h = relaunch(old, displays: [main, side], keeping: { $0.id != a })
    h.start()
    #expect(h.controller.workspaceID(containing: b) == side.id)
    #expect(h.controller.workspaces[side.id]?.isDocked(b) == true)
    // The closed one's slot waits a while for a window to come back to it (Controller+PendingSlots.swift),
    // taking no space, and is then dropped.
    #expect(h.controller.layouts[main.id]?.windowFrames.isEmpty == true)
    h.scheduler.advance(by: Controller.pendingSlotLifetime + 1)
    #expect(h.controller.workspaces[main.id]?.tree.allWindows.isEmpty == true)
    #expect(h.controller.workspaces[side.id]?.isDocked(b) == true)
  }

  @Test func twoWindowsWithTheSameTitleKeepTheirOrderAfterAReboot() {
    let old = Harness()
    let a = old.system.open(app: "Terminal", title: "zsh")
    let b = old.system.open(app: "Terminal", title: "zsh")
    old.start()
    old.run("dock \(a.rawValue) left")
    old.run("dock \(b.rawValue) right")
    old.controller.shutdown()

    let h = Harness(saved: old.store.saved)
    for _ in 0..<5 { h.system.close(h.system.open(app: "Filler")) }
    let a2 = h.system.open(app: "Terminal", title: "zsh")
    let b2 = h.system.open(app: "Terminal", title: "zsh")
    h.start()
    #expect(h.workspace.tree.allWindows == [a2, b2])
    #expect(h.frame(a2)!.maxX < h.frame(b2)!.minX)
  }
}
