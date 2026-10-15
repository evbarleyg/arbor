import ArborCore
@testable import ArborKit
import ArborTesting
import CoreGraphics
import Testing

/// `Harness.layoutProblems`, which `expectWindowsMatchLayout` reports: it has to notice what it is there to notice.
@Suite @MainActor struct LayoutCheckTests {
  /// `[Safari | Mail]`; with a column for the Desktop `[Safari | Desktop | Mail]`.
  private func desk() -> (Harness, safari: WindowID, mail: WindowID) {
    let h = Harness()
    let safari = h.system.open(app: "Safari")
    let mail = h.system.open(app: "Mail")
    h.start()
    h.run("dock \(safari.rawValue) left")
    h.run("dock \(mail.rawValue) right")
    return (h, safari, mail)
  }

  @Test func allIsWellAfterOrdinaryCommands() {
    let (h, safari, _) = desk()
    #expect(h.layoutProblems() == [])
    for command in ["zoom \(safari.rawValue)", "out", "desktop", "back", "float \(safari.rawValue)", "arrange", "float-all"] {
      h.run(command)
      #expect(h.layoutProblems() == [], "\(command)")
    }
  }

  @Test func aViewThatMovedWithoutALayoutIsNoticed() {
    // What a command that forgets to lay out leaves behind. The windows still match the layout from before it.
    let (h, safari, _) = desk()
    let leaf = h.workspace.tree.leaf(containing: safari)!
    h.controller.workspaces[h.display]!.moveCamera(to: leaf)
    let problems = h.layoutProblems()
    #expect(problems.first == "main was not laid out again: the view was on \(h.workspace.tree.root) and is on \(leaf)")
    #expect(problems.count == 3, "and neither window is where it belongs now: \(problems)")
  }

  @Test func anArrangementThatChangedWithoutALayoutIsNoticed() {
    let (h, safari, mail) = desk()
    // A third place: of two the one that is left would stay as it is, of three the others share.
    let notes = h.system.open(app: "Notes")
    h.run("dock \(notes.rawValue) right")
    h.controller.workspaces[h.display]!.forget(safari)
    #expect(h.layoutProblems().contains { $0.hasPrefix("main was not laid out again: the place of \(safari) was") })
    #expect(h.layoutProblems().contains { $0.hasPrefix("\(mail) is at") })
  }

  @Test func aWindowOutOfItsPlaceIsNoticed() {
    let (h, safari, _) = desk()
    _ = h.system.setFrame(CGRect(x: 40, y: 60, width: 300, height: 200), of: safari)  // behind the controller's back
    #expect(h.layoutProblems().count == 1)
    #expect(h.layoutProblems().first?.hasPrefix("\(safari) is at (40.0,60.0 300.0×200.0), and its place is") == true)
  }

  @Test func aWindowThatShouldBeOutOfViewIsNoticed() {
    let (h, safari, mail) = desk()
    h.run("zoom \(safari.rawValue)")
    _ = h.system.setFrame(CGRect(x: 400, y: 300, width: 300, height: 200), of: mail)  // behind the controller's back
    #expect(h.layoutProblems() == ["\(mail) should be out of view and is at (400.0,300.0 300.0×200.0)"])
  }

  @Test func oneDisplayCanBeAskedAbout() {
    let (h, safari, _) = desk()
    h.controller.workspaces[h.display]!.forget(safari)
    #expect(!h.layoutProblems(on: h.display).isEmpty)
    #expect(h.layoutProblems(on: DisplayID("nowhere")) == ["there is no display nowhere"])
  }
}

/// What the check found when it was run after every command and event of every test (K525).
@Suite @MainActor struct LayoutCheckFindings {
  @Test func aWindowOfAnAppExcludedWhileItWasOnAnotherSpaceIsNotArrangedWhenItShowsAgain() {
    let first = Harness()
    let safari = first.system.open(app: "Safari")
    let mail = first.system.open(app: "Mail")
    first.start()
    first.run("dock \(safari.rawValue) left")
    first.run("dock \(mail.rawValue) right")
    first.controller.saveNow()

    // Arbor starts again while Mail's window is on a macOS Space that is not showing: its place waits for it.
    let h = Harness(saved: first.store.saved)
    for window in first.system.allWindows() {
      _ = h.system.open(app: window.appName, bundleID: window.bundleID, title: window.title, pid: window.pid, frame: window.frame)
    }
    h.system.setListed(mail, false)
    h.start()
    #expect(h.workspace.isDocked(mail))
    #expect(h.run("exclude \(first.controller.windows[mail]!.bundleID!)").ok)

    h.system.clearFrameLog()
    h.system.setListed(mail, true)
    #expect(!h.workspace.contains(mail), "Don't Arrange means this window too")
    h.run("relayout")
    #expect(!h.system.frameLog.contains { $0.window == mail }, "and nothing moves it")
    expectWindowsMatchLayout(h)
  }
}
