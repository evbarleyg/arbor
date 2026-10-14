import ArborCore
import ArborKit
import ArborTesting
import CoreGraphics
import Testing

/// F20 with F19: undo restores names with the arrangement they belonged to.
@Suite @MainActor struct NamedSpacesUndoTests {
  /// `[Safari | Desktop | Notes / Mail]`, with `Notes / Mail` named Writing and everything in view.
  private func desk() -> (Harness, safari: WindowID, notes: WindowID, mail: WindowID) {
    let h = Harness()
    let safari = h.system.open(app: "Safari")
    let notes = h.system.open(app: "Notes")
    let mail = h.system.open(app: "Mail")
    h.start()
    h.run("dock \(safari.rawValue) left")
    h.run("dock \(notes.rawValue) right")
    h.run("dock \(mail.rawValue) beside \(notes.rawValue) bottom")
    h.run("zoom \(mail.rawValue)")
    h.run("out")
    h.run("name Writing")
    h.run("show-all")
    return (h, safari, notes, mail)
  }

  private func windows(_ h: Harness, named name: String) -> [WindowID]? {
    h.workspace.node(named: name).map { h.workspace.tree.windows(under: $0) }
  }

  @Test(arguments: ["arrange", "float-all"]) func undoBringsBackTheNamesThatArrangeAndFloatAllRemove(command: String) {
    let (h, _, notes, mail) = desk()
    h.run(command)
    #expect(h.workspace.names.isEmpty)
    var heard: [Controller.Change] = []
    h.controller.observe { heard.append($0) }
    #expect(h.run("undo").ok)
    #expect(windows(h, named: "Writing") == [notes, mail])
    #expect(heard.contains(.names(h.display)))
    #expect(h.run("go writing").ok)
    #expect(h.workspace.tree.kept(for: .name) == [h.workspace.camera])
    h.run("redo")
    #expect(h.workspace.names.isEmpty)
    #expect(h.workspace.tree.invariantViolations() == [])
  }

  @Test func namingIsNotAStep() {
    let (h, safari, _, _) = desk()
    h.run("zoom \(safari.rawValue)")
    h.run("name Web")
    #expect(h.run("undo").message.hasPrefix("undid dock"), "the last change to the arrangement, not the naming")
    #expect(h.workspace.node(named: "Web") != nil)
  }

  @Test func aNameGivenSinceAStepSurvivesUndoingIt() {
    let (h, safari, notes, mail) = desk()
    h.run("resize \(safari.rawValue) right 60")
    h.run("zoom \(safari.rawValue)")
    h.run("name Web")
    h.run("go writing")
    h.run("name Desk")
    #expect(h.run("undo").message.hasPrefix("undid resize"))
    #expect(windows(h, named: "Web") == [safari])
    #expect(windows(h, named: "Desk") == [notes, mail], "renamed since, and it stays renamed")
    #expect(h.workspace.names.count == 2)
  }

  @Test func aNameTakenOffSinceAStepStaysOff() {
    let (h, safari, _, _) = desk()
    h.run("resize \(safari.rawValue) right 60")
    h.run("unname Writing")
    h.run("undo")
    #expect(h.workspace.names.isEmpty)
    #expect(h.workspace.tree.kept(for: .name) == [])
  }

  @Test func aNameWhoseSpaceTheUndoTakesAwayGoes() {
    let (h, _, _, _) = desk()
    let terminal = h.system.open(app: "Terminal")
    h.run("dock \(terminal.rawValue) left")
    h.run("zoom \(terminal.rawValue)")
    h.run("name Shell")
    h.run("undo")
    #expect(h.workspace.isFloating(terminal))
    #expect(h.workspace.node(named: "Shell") == nil)
    #expect(h.workspace.names.keys.sorted() == ["Writing"])
  }

  @Test func undoingADockIntoANamedSpaceLeavesTheSpaceAsItWas() {
    let (h, _, notes, mail) = desk()
    h.run("go writing")
    let terminal = h.system.open(app: "Terminal")
    h.run("dock \(terminal.rawValue) right")
    #expect(Set(windows(h, named: "Writing")!) == [notes, mail, terminal])
    h.run("undo")
    #expect(windows(h, named: "Writing") == [notes, mail])
    #expect(h.workspace.camera == h.workspace.node(named: "Writing"))
    #expect(h.workspace.isFloating(terminal))
    h.run("redo")
    #expect(Set(windows(h, named: "Writing")!) == [notes, mail, terminal])
    #expect(h.workspace.tree.invariantViolations() == [])
  }

  @Test func undoDoesNotBringBackANameWhoseWindowsHaveClosed() {
    let (h, _, notes, mail) = desk()
    h.run("arrange")
    h.system.close(notes)
    h.system.close(mail)
    h.run("undo")
    #expect(h.workspace.names.isEmpty)
    #expect(h.workspace.tree.invariantViolations() == [])
  }
}
