import ArborCore
import ArborIPC
@testable import ArborKit
import ArborTesting
import CoreGraphics
import Foundation
import Testing

@MainActor private let main = FakeWindowSystem.standardDisplay
private let side = DisplaySnapshot(
  id: DisplayID("side"), frame: CGRect(x: 1440, y: 0, width: 1280, height: 800),
  visibleFrame: CGRect(x: 1440, y: 0, width: 1280, height: 800), isMain: false)
private let third = DisplaySnapshot(
  id: DisplayID("third"), frame: CGRect(x: 2720, y: 0, width: 1280, height: 800),
  visibleFrame: CGRect(x: 2720, y: 0, width: 1280, height: 800), isMain: false)

/// `[Safari | Desktop | Notes / Mail]` on the main display.
@MainActor private struct Desk {
  let h: Harness
  let safari: WindowID, notes: WindowID, mail: WindowID

  init(
    displays: [DisplaySnapshot] = [main], settings: Settings = Harness.settingsWhenNoneAreGiven, saved: PersistedState? = nil
  ) {
    h = Harness(displays: displays, settings: settings, saved: saved)
    safari = h.system.open(app: "Safari", title: "Apple", frame: CGRect(x: 100, y: 100, width: 600, height: 400))
    notes = h.system.open(app: "Notes", title: "Shopping", frame: CGRect(x: 300, y: 200, width: 600, height: 400))
    mail = h.system.open(app: "Mail", title: "Inbox", frame: CGRect(x: 400, y: 200, width: 600, height: 400))
    h.start()
    guard saved == nil else { return }
    h.run("dock \(safari.rawValue) left")
    h.run("dock \(notes.rawValue) right")
    h.run("dock \(mail.rawValue) beside \(notes.rawValue) bottom")
  }

  var workspace: Workspace { h.workspace }
  var column: NodeID { workspace.tree.parent(of: workspace.tree.leaf(containing: notes)!)! }
  func leaf(_ window: WindowID) -> NodeID { workspace.tree.leaf(containing: window)! }

  /// Puts the view on `Notes / Mail`.
  func frameColumn() { h.run("zoom-node \(column.rawValue)") }

  /// Names `Notes / Mail` and shows everything again.
  func nameColumn(_ name: String = "Writing") {
    frameColumn()
    h.run("name \(name)")
    h.run("show-all")
  }

  func windows(named name: String, on display: DisplayID? = nil) -> [WindowID]? {
    let workspace = h.controller.workspaces[display ?? h.display]!
    return workspace.node(named: name).map { workspace.tree.windows(under: $0) }
  }

  func inView(on display: DisplayID? = nil) -> [WindowID] {
    let workspace = h.controller.workspaces[display ?? h.display]!
    return workspace.tree.windows(under: workspace.camera)
  }

  var frames: [WindowID: CGRect] { Dictionary(uniqueKeysWithValues: [safari, notes, mail].map { ($0, h.frame($0)!) }) }
}

/// F20: named spaces, as a person uses them.
@Suite @MainActor struct NamedSpacesTests {
  // MARK: 1. Naming

  @Test func namingTheSpaceInViewShowsEverywhereAndMovesNothing() {
    let d = Desk()
    d.frameColumn()
    let (frames, camera) = (d.frames, d.workspace.camera)
    d.h.system.clearFrameLog()

    let result = d.h.run("name  Writing   Desk")
    #expect(result.ok)
    #expect(result.message == "named Notes and Mail (\(d.column)): Writing Desk")
    #expect(d.workspace.names == ["Writing Desk": d.column])
    #expect(d.h.controller.snapshot().displays[0].names == ["Writing Desk": d.column])
    #expect(d.h.ascii().contains("camera \(d.column) Writing Desk"))
    #expect(d.h.ascii().contains("spaces: Writing Desk \(d.column)"))
    #expect(d.h.run("spaces").text == "Writing Desk   Notes and Mail (\(d.column))   in view")

    #expect(d.frames == frames && d.workspace.camera == camera)
    #expect(d.h.system.frameLog.isEmpty, "no window is touched")
  }

  @Test func withoutNamesTheDrawingIsAsItWas() {
    let d = Desk()
    #expect(!d.h.ascii().contains("spaces:"))
    #expect(d.h.ascii().hasSuffix("camera \(d.workspace.tree.root)"))
  }

  @Test func anySpaceCanBeNamed() {
    let d = Desk()
    #expect(d.h.run("name All").message == "named everything: All")
    d.h.run("desktop")
    #expect(d.h.run("name Scratch").message == "named the Desktop: Scratch")
    d.h.run("zoom \(d.safari.rawValue)")
    #expect(d.h.run("name Web").message == "named Safari (\(d.leaf(d.safari))): Web")
    #expect(d.workspace.names.count == 3)
  }

  @Test func withNothingDockedTheDesktopCanBeNamed() {
    let h = Harness()
    h.start()
    #expect(h.run("name Home base").ok)
    #expect(h.run("go home").ok)
  }

  // MARK: 2. What a name may be

  @Test func aNameThatCannotBeIsRefusedWithTheReason() {
    let d = Desk()
    #expect(d.h.run("name left").message == "a space cannot be named `left`: `go left` means the neighboring space")
    #expect(d.h.run("name " + String(repeating: "x", count: 41)).message == "a name can have at most 40 characters")
    // Not everything comes through the parser: a binding, a rule or another feature can hand over a command.
    for text in ["", "  ", "up", "a\u{7}", "a\nb\u{1B}", String(repeating: "é", count: 500)] {
      #expect(!d.h.controller.perform(.name(text)).ok, "\(text.debugDescription)")
    }
    #expect(d.workspace.names.isEmpty)
    #expect(d.h.controller.perform(.name(" a / b ")).ok, "tidied here as well")
    #expect(d.workspace.names.keys.first == "a b")
  }

  // MARK: 3. One name per space, each name once per display

  @Test func namingANamedSpaceRenamesIt() {
    let d = Desk()
    d.frameColumn()
    d.h.run("name Draft")
    #expect(d.h.run("name Writing").message == "renamed Draft to Writing (\(d.column))")
    #expect(d.workspace.names == ["Writing": d.column])
    #expect(d.h.run("name Writing").message == "already named Writing")
    #expect(d.h.run("name WRITING").message == "renamed Writing to WRITING (\(d.column))")
  }

  @Test func aNameGivenToASecondSpaceMoves() {
    let d = Desk()
    d.nameColumn("Writing")
    d.h.run("zoom \(d.safari.rawValue)")
    let leaf = d.leaf(d.safari)
    #expect(d.h.run("name writing").message == "named Safari (\(leaf)): writing; Notes and Mail (\(d.column)) has no name now")
    #expect(d.workspace.names == ["writing": leaf])
  }

  // MARK: 4. Removing

  @Test func nameWithoutTextAndUnnameRemoveTheNameInView() {
    for command in ["name", "unname"] {
      let d = Desk()
      d.frameColumn()
      d.h.run("name Writing")
      #expect(d.h.run(command).message == "removed the name Writing from Notes and Mail (\(d.column))")
      #expect(d.workspace.names.isEmpty)
      #expect(d.h.run(command).message == "the space in view has no name")
    }
  }

  @Test func unnameWithANameNeedsAllOfIt() {
    let d = Desk()
    d.nameColumn("Writing Desk")
    #expect(!d.h.run("unname writing").ok, "removing is no place for guessing")
    #expect(d.workspace.names.count == 1)
    #expect(d.h.run("unname WRITING desk").ok)
    #expect(d.workspace.names.isEmpty)
    #expect(d.workspace.camera == d.workspace.tree.root, "the view stays")
  }

  // MARK: 5. Going

  @Test func goFindsTheWholeNameThenABeginning() {
    let d = Desk()
    d.nameColumn("Mail")
    d.h.run("zoom \(d.safari.rawValue)")
    d.h.run("name Mailing List")
    d.h.run("desktop")
    d.h.run("name Scratch")

    #expect(d.h.run("go mail").message == "moved to Mail (\(d.column))")
    #expect(d.inView() == [d.notes, d.mail])
    #expect(d.h.run("go maili").message == "moved to Mailing List (\(d.leaf(d.safari)))")
    #expect(d.inView() == [d.safari])
    #expect(d.h.run("go S").ok)
    #expect(d.workspace.camera == d.workspace.tree.desktop)
  }

  @Test func aBeginningThatFitsSeveralMovesNothingAndListsThem() {
    let d = Desk()
    d.nameColumn("Mail")
    d.h.run("zoom \(d.safari.rawValue)")
    d.h.run("name Music")
    let result = d.h.run("go m")
    #expect(!result.ok)
    #expect(result.message == "m could be Mail or Music; type more of the name")
    #expect(d.inView() == [d.safari])
  }

  @Test func aNameNobodyHasSaysWhatThereIs() {
    let d = Desk()
    #expect(d.h.run("go Writing").message == "no space has a name yet; `name <text>` names the space in view")
    d.nameColumn("Mail")
    #expect(d.h.run("go Writing").message == "no space is named Writing; there is Mail")
    d.h.run("name All")
    #expect(d.h.run("go Writing").message == "no space is named Writing; there are All and Mail")
  }

  @Test func backReturnsFromWhereGoWent() {
    let d = Desk()
    d.nameColumn()
    d.h.run("zoom \(d.safari.rawValue)")
    d.h.run("go writing")
    d.h.run("back")
    #expect(d.inView() == [d.safari])
    d.h.run("forward")
    #expect(d.inView() == [d.notes, d.mail])
  }

  @Test func goingWhereTheViewIsSucceedsAndChangesNothing() {
    let d = Desk()
    d.frameColumn()
    d.h.run("name Writing")
    let history = d.workspace.back
    d.h.system.clearFrameLog()
    #expect(d.h.run("go writing").message == "already showing Writing (\(d.column))")
    #expect(d.workspace.back == history && d.h.system.frameLog.isEmpty)
  }

  @Test func aDirectionStillMeansTheNeighbour() {
    let d = Desk(settings: Settings())
    d.h.run("zoom \(d.safari.rawValue)")
    d.h.run("go right")
    #expect(d.workspace.camera == d.column)
  }

  @Test func goBringsTheKeyboardAlong() {
    let d = Desk()
    d.nameColumn()
    d.h.run("zoom \(d.safari.rawValue)")
    #expect(d.h.system.focused == d.safari)
    d.h.run("go writing")
    #expect([d.notes, d.mail].contains(d.h.system.focused), "Safari went out of view with the keyboard")
    expectWindowsMatchLayout(d.h, on: d.h.display)
  }

  // MARK: 6. Several displays

  /// The desk, and `[Desktop | Music]` on the side display, each with the pointer's help.
  private func twoDisplays(
    _ displays: [DisplaySnapshot] = [main, side], settings: Settings = Harness.settingsWhenNoneAreGiven
  ) -> (Desk, music: WindowID) {
    let d = Desk(displays: displays, settings: settings)
    let music = d.h.system.open(app: "Music", title: "Library", frame: CGRect(x: 1600, y: 200, width: 600, height: 400))
    d.h.run("dock \(music.rawValue) right")
    return (d, music)
  }

  private func point(_ d: Desk, at display: DisplaySnapshot) { d.h.system.cursor = display.frame.center }

  @Test func twoDisplaysCanHoldTheSameNameAndGoPrefersTheOneItActsOn() {
    let (d, music) = twoDisplays()
    d.nameColumn("Media")
    point(d, at: side)
    d.h.run("zoom \(music.rawValue)")
    #expect(d.h.run("name Media").ok)
    d.h.run("show-all")
    #expect(d.windows(named: "Media", on: main.id) == [d.notes, d.mail], "the name did not move between displays")
    #expect(d.windows(named: "Media", on: side.id) == [music])

    #expect(d.h.run("go media").message.hasPrefix("moved to Media (") == true)
    #expect(d.inView(on: side.id) == [music])
    #expect(d.workspace.camera == d.workspace.tree.root)
    point(d, at: main)
    d.h.run("go media")
    #expect(d.inView(on: main.id) == [d.notes, d.mail])
  }

  @Test func goToANameOnAnotherDisplayMovesThatViewAndTheKeyboard() {
    let (d, music) = twoDisplays()
    point(d, at: side)
    d.h.run("zoom \(music.rawValue)")
    d.h.run("name Tunes")
    d.h.run("show-all")
    point(d, at: main)
    d.h.run("zoom \(d.safari.rawValue)")
    let node = d.h.controller.workspaces[side.id]!.node(named: "Tunes")!

    #expect(d.h.run("go tu").message == "moved to Tunes (\(node)) on another display")
    #expect(d.inView(on: side.id) == [music])
    #expect(d.inView(on: main.id) == [d.safari], "the display the command came from stays as it was")
    #expect(d.h.system.focused == music, "the next shortcut acts where the user went")
    #expect(d.h.system.cursor == main.frame.center, "the pointer is left alone")
    expectWindowsMatchLayout(d.h, on: main.id)
    expectWindowsMatchLayout(d.h, on: side.id)

    d.h.system.userFocus(d.safari)
    #expect(d.h.run("go tunes").message == "already showing Tunes (\(node)) on another display")
    #expect(d.h.system.focused == music)
  }

  /// The pointer is left on the main display, and the user switches to `window` with ⌘Tab and types.
  private func restPointerOnMainAndType(_ d: Desk, in window: WindowID) {
    point(d, at: main)
    d.h.scheduler.advance(by: 5)
    d.h.system.userFocus(window)
    d.h.scheduler.advance(by: 1)
    d.h.system.type()
    d.h.scheduler.advance(by: 0.3)
  }

  @Test func shortcutsNameAndGoOnTheDisplayThatHasTheKeyboard() {
    // F56: the pointer was left on the main display; the user is typing on the other one.
    let (d, music) = twoDisplays()
    d.nameColumn("Media")
    restPointerOnMainAndType(d, in: music)
    #expect(d.h.press("zoom").ok)
    #expect(d.h.press("name Media").ok)
    #expect(d.windows(named: "Media", on: side.id) == [music])
    #expect(d.windows(named: "Media", on: main.id) == [d.notes, d.mail])
    d.h.press("show-all")
    #expect(d.h.press("go media").message.hasSuffix("display") == false, "the one on the display being typed on")
    #expect(d.inView(on: side.id) == [music] && d.workspace.camera == d.workspace.tree.root)
    #expect(d.h.press("ask-name").ok)
    #expect(d.h.overlays.namePrompt?.display == side.id)
    #expect(d.h.overlays.submitName("Tunes")?.ok == true)
    #expect(d.windows(named: "Tunes", on: side.id) == [music])
  }

  @Test func afterGoingToAnotherDisplayTheNextShortcutActsThere() {
    let (d, music) = twoDisplays()
    point(d, at: side)
    d.h.run("zoom \(music.rawValue)")
    d.h.run("name Tunes")
    d.h.run("show-all")
    restPointerOnMainAndType(d, in: d.safari)
    d.h.press("zoom")
    #expect(d.h.press("go tunes").ok)
    #expect(d.h.system.focused == music)
    #expect(d.h.press("show-all").ok)
    #expect(d.h.controller.workspaces[side.id]!.camera == d.h.controller.workspaces[side.id]!.tree.root, "on the display gone to")
    #expect(d.inView(on: main.id) == [d.safari], "and not on the one left behind")
  }

  /// The menu asks when it is opened and nothing records that (TraceForwardingTests), so it must leave no mark: what the
  /// next shortcut follows is decided by what the person did, not by what was drawn.
  @Test func askingForTheNamesDoesNotChangeWhatTheNextShortcutFollows() {
    let (d, music) = twoDisplays()
    point(d, at: side)
    d.h.run("zoom \(music.rawValue)")
    d.h.run("name Tunes")
    restPointerOnMainAndType(d, in: d.safari)
    d.h.press("zoom")
    let before = d.h.controller.following.lead
    #expect(d.h.controller.namedSpacesMenu().map(\.title) == ["Tunes", "Name This Space…"])
    #expect(d.h.controller.namedSpaces().map(\.name) == ["Tunes"])
    #expect(d.h.controller.spaceName(of: d.h.controller.workspaces[side.id]!.camera, on: side.id) == "Tunes")
    #expect(d.h.controller.following.lead == before)
  }

  @Test(arguments: [false, true]) func goingToTheDesktopOfAnotherDisplayGivesAFloatingWindowThereTheKeyboard(makingWay: Bool) {
    let (d, music) = twoDisplays(settings: makingWay ? .makingWay : Settings())
    let calculator = d.h.system.open(app: "Calculator", frame: CGRect(x: 1500, y: 300, width: 300, height: 300))
    point(d, at: side)
    d.h.run("desktop")
    d.h.run("name Scratch")
    d.h.run("zoom \(music.rawValue)")
    // Only a floating window that makes way leaves with the Desktop. As Arbor ships it stays, and still gets the keyboard below.
    #expect(d.h.system.isVisible(calculator) == !makingWay)
    point(d, at: main)
    d.h.system.userFocus(d.safari)
    d.h.run("go scratch")
    #expect(d.h.system.isVisible(calculator))
    #expect(d.h.system.focused == calculator)
    // And going where nothing can take the keyboard leaves it where it is.
    d.h.system.close(calculator)
    d.h.system.userFocus(d.safari)
    d.h.run("go scratch")
    #expect(d.h.system.focused == d.safari)
  }

  @Test func goingToAnotherDisplayPrefersAWindowOfTheSpaceToAPinnedOne() {
    let (d, music) = twoDisplays()
    let timer = d.h.system.open(app: "Timer", frame: CGRect(x: 1500, y: 60, width: 200, height: 120))
    d.h.run("pin \(timer.rawValue)")
    point(d, at: side)
    d.h.run("zoom \(music.rawValue)")
    d.h.run("name Tunes")
    d.h.run("show-all")
    d.h.system.userFocus(timer)
    point(d, at: main)
    d.h.system.userFocus(d.safari)
    d.h.run("go tunes")
    #expect(d.h.system.focused == music, "the timer had the keyboard later, and is further up and left, but it is in every view")
  }

  @Test func theWholeNameElsewhereBeatsABeginningHere() {
    let (d, music) = twoDisplays()
    d.nameColumn("Mailing List")
    point(d, at: side)
    d.h.run("zoom \(music.rawValue)")
    d.h.run("name Mail")
    d.h.run("show-all")
    point(d, at: main)
    d.h.run("go mail")
    #expect(d.inView(on: side.id) == [music])
    #expect(d.workspace.camera == d.workspace.tree.root)
    d.h.run("go mai")
    #expect(d.inView(on: main.id) == [d.notes, d.mail], "of two beginnings, the one on this display")
  }

  @Test func aBeginningMustFitOnlyOneNameAcrossTheOtherDisplays() {
    let (d, music) = twoDisplays([main, side, third])
    let video = d.h.system.open(app: "TV", frame: CGRect(x: 2900, y: 200, width: 600, height: 400))
    d.h.run("dock \(video.rawValue) left")
    point(d, at: side)
    d.h.run("zoom \(music.rawValue)")
    d.h.run("name Media one")
    point(d, at: third)
    d.h.run("zoom \(video.rawValue)")
    d.h.run("name Media two")
    point(d, at: main)
    #expect(d.h.run("go med").message == "med could be Media one or Media two; type more of the name")
    #expect(d.h.run("go media t").ok)
  }

  @Test func unnameLooksAtTheActingDisplayFirstThenTheOthers() {
    let (d, music) = twoDisplays()
    d.nameColumn("Media")
    point(d, at: side)
    d.h.run("zoom \(music.rawValue)")
    d.h.run("name Media")
    #expect(d.h.run("unname media").ok)
    #expect(d.windows(named: "Media", on: side.id) == nil)
    #expect(d.windows(named: "Media", on: main.id) != nil)
    #expect(d.h.run("unname media").ok, "now the one on the other display")
    #expect(d.windows(named: "Media", on: main.id) == nil)
  }

  @Test func spacesListsEveryDisplayStartingWithThisOne() {
    let (d, music) = twoDisplays()
    d.nameColumn("Writing")
    d.h.run("name All")
    point(d, at: side)
    d.h.run("zoom \(music.rawValue)")
    d.h.run("name Tunes")
    point(d, at: main)
    let node = d.h.controller.workspaces[side.id]!.node(named: "Tunes")!
    let report = d.h.run("spaces")
    #expect(report.message == "3 named spaces")
    #expect(
      report.text == """
        All       everything            in view
        Writing   Notes and Mail (\(d.column))
        Tunes     Music (\(node))            in view, on another display
        """)
  }

  @Test func spacesSaysSoWhenEveryNameIsOnAnotherDisplay() {
    let (d, music) = twoDisplays()
    point(d, at: side)
    d.h.run("zoom \(music.rawValue)")
    d.h.run("name Tunes")
    point(d, at: main)
    #expect(d.h.run("spaces").text?.hasSuffix("in view, on another display") == true)
  }

  @Test func manyFitsAreCountedNotListed() {
    let h = Harness()
    let windows = (0..<7).map { h.system.open(app: "App\($0)") }
    h.start()
    h.run("arrange")
    for (index, window) in windows.enumerated() {
      h.run("zoom \(window.rawValue)")
      h.run("name Project \(index)")
    }
    #expect(h.run("go pro").message == "7 names begin with pro; type more of the name")
    #expect(h.run("go nothing").message == "no space is named nothing; `spaces` lists the names")
  }

  // MARK: 7. A named group is kept, and grows

  @Test func aNamedGroupSurvivesItsNeighboursLeaving() {
    // [Safari / (Notes | Mail)] beside the Desktop: without Safari, Notes | Mail would dissolve into everything.
    let h = Harness()
    let safari = h.system.open(app: "Safari")
    let notes = h.system.open(app: "Notes")
    let mail = h.system.open(app: "Mail")
    h.start()
    h.run("dock \(safari.rawValue) left")
    h.run("dock \(notes.rawValue) beside \(safari.rawValue) bottom")
    h.run("dock \(mail.rawValue) beside \(notes.rawValue) right")
    h.run("zoom \(mail.rawValue)")
    h.run("out")
    #expect(h.run("name Pair").message.hasPrefix("named Notes and Mail"))
    h.run("show-all")
    h.system.close(safari)
    #expect(h.run("go pair").ok)
    #expect(h.workspace.tree.windows(under: h.workspace.camera) == [notes, mail])
    #expect(h.layout?.desktopFrame == nil, "Pair, and not everything")
    expectWindowsMatchLayout(h, on: h.display)
  }

  @Test func downToOneWindowAndUpAgainItIsStillTheSameSpace() {
    let d = Desk()
    d.nameColumn()
    d.h.system.close(d.notes)
    d.h.run("go writing")
    #expect(d.inView() == [d.mail])
    #expect(d.h.frame(d.mail) == d.h.visibleFrame.insetBy(dx: 12, dy: 12), "one window, filling the view")
    let editor = d.h.system.open(app: "Editor")
    d.h.run("dock \(editor.rawValue) top")
    #expect(d.windows(named: "Writing") == [editor, d.mail])
    #expect(d.inView() == [editor, d.mail])
    expectWindowsMatchLayout(d.h, on: d.h.display)
  }

  @Test(arguments: ["left", "right", "top", "bottom"]) func aWindowDockedAtAnyEdgeOfItsViewJoinsTheNamedSpace(edge: String) {
    let d = Desk()
    d.frameColumn()
    d.h.run("name Writing")
    let terminal = d.h.system.open(app: "Terminal")
    #expect(d.h.run("dock \(terminal.rawValue) \(edge)").ok)
    #expect(Set(d.windows(named: "Writing")!) == [d.notes, d.mail, terminal])
    #expect(Set(d.inView()) == [d.notes, d.mail, terminal], "still in Writing, with nothing else in view")
    #expect(!d.h.system.isVisible(d.safari))
    #expect(d.h.ascii().contains(" Writing"))
    expectWindowsMatchLayout(d.h, on: d.h.display)
    d.h.run("show-all")
    #expect(d.h.run("go writing").ok)
    #expect(Set(d.inView()) == [d.notes, d.mail, terminal])
  }

  @Test func aWindowDraggedToTheEdgeOfItsViewJoinsTheNamedSpace() {
    let d = Desk()
    d.frameColumn()
    d.h.run("name Writing")
    let terminal = d.h.system.open(app: "Terminal", frame: CGRect(x: 500, y: 300, width: 400, height: 300))
    d.h.system.tiling = .off  // the screen's edges are Arbor's only with macOS's tiling off
    d.h.system.drag(terminal, through: [CGPoint(x: 700, y: 310), CGPoint(x: 300, y: 400), CGPoint(x: 2, y: 450)])
    #expect(d.workspace.isDocked(terminal))
    #expect(Set(d.windows(named: "Writing")!) == [d.notes, d.mail, terminal])
    #expect(Set(d.inView()) == [d.notes, d.mail, terminal])
  }

  @Test func turningANamedPairRoundWithTheKeyboardKeepsItsName() {
    let d = Desk()
    d.frameColumn()
    d.h.run("name Writing")
    #expect(d.h.run("dock \(d.notes.rawValue) left").ok)
    #expect(d.windows(named: "Writing") == [d.notes, d.mail])
    #expect(d.inView() == [d.notes, d.mail])
    #expect(d.h.frame(d.notes)!.maxX <= d.h.frame(d.mail)!.minX, "side by side now")
  }

  @Test func theOnlyWindowOfANamedGroupHasNowhereToGoInItsView() {
    let d = Desk()
    d.nameColumn()
    d.h.system.close(d.notes)
    d.h.run("go writing")
    for edge in ["left", "right", "top", "bottom"] {
      #expect(d.h.run("dock \(d.mail.rawValue) \(edge)").message == "\(d.mail) fills the view; `show-all` first")
    }
    #expect(d.windows(named: "Writing") == [d.mail] && d.inView() == [d.mail])
  }

  @Test func aGroupThatOnlyTheNameHeldTogetherIsStillCalledByItsWindowsWhenTheNameMovesAway() {
    let d = Desk()
    d.nameColumn()
    let column = d.column
    d.h.system.close(d.notes)
    d.h.run("zoom \(d.safari.rawValue)")
    #expect(
      d.h.run("name Writing").message
        == "named Safari (\(d.leaf(d.safari))): Writing; Mail (\(column)) has no name now")
    #expect(d.workspace.tree.invariantViolations() == [])
  }

  @Test func takingTheNameOffAGroupThatOnlyTheNameHeldTogetherKeepsEveryWindowInPlace() {
    let d = Desk()
    d.nameColumn()
    let column = d.column
    d.h.system.close(d.notes)
    d.h.run("go writing")
    let frame = d.h.frame(d.mail)
    #expect(d.h.run("unname").message == "removed the name Writing from Mail (\(column))", "in words, though the group is gone by now")
    #expect(d.inView() == [d.mail] && d.h.frame(d.mail) == frame)
    #expect(d.workspace.tree.invariantViolations() == [])
  }

  // MARK: 8. Names follow windows

  @Test func theNameOfAWindowsPlaceFollowsItWhenItIsDockedElsewhere() {
    let d = Desk()
    d.h.run("zoom \(d.safari.rawValue)")
    d.h.run("name Web")
    d.h.run("show-all")
    d.h.run("dock \(d.safari.rawValue) beside \(d.mail.rawValue) bottom")
    #expect(d.windows(named: "Web") == [d.safari])
    d.h.run("go web")
    #expect(d.inView() == [d.safari])
  }

  @Test func draggingANamedWindowToAnotherEdgeTakesTheNameAlong() {
    let d = Desk()
    d.h.run("zoom \(d.safari.rawValue)")
    d.h.run("name Web")
    d.h.run("show-all")
    d.h.system.drag(d.safari, through: [d.h.frame(d.safari)!.center, CGPoint(x: 720, y: 450), CGPoint(x: 1438, y: 450)])
    #expect(d.workspace.isDocked(d.safari))
    #expect(d.windows(named: "Web") == [d.safari])
  }

  @Test func aTabGroupKeepsItsNameWhileTabsComeAndGo() throws {
    // Nothing makes tab groups by hand before F04, so this one comes from a saved arrangement.
    let old = Desk()
    var state = old.h.controller.snapshot().displays[0].tree
    let extra = WindowID(104)
    state.addToStack(extra, leaf: old.leaf(old.safari))
    var workspace = Workspace(tree: state)
    try workspace.setName("Web", of: old.leaf(old.safari))
    let h = Harness(saved: PersistedState(workspaces: [old.h.display: workspace], hints: [:]))
    for app in ["Safari", "Notes", "Mail", "Firefox"] { _ = h.system.open(app: app) }
    h.start()
    func web() -> [WindowID]? { h.workspace.node(named: "Web").map { h.workspace.tree.windows(under: $0) } }
    #expect(web() == [old.safari, extra])
    #expect(h.run("go web").message.hasPrefix("moved to Web"))
    #expect(h.system.isVisible(extra) && !h.system.isVisible(old.safari), "the tab in front")
    h.system.close(extra)
    #expect(web() == [old.safari])
    #expect(h.system.isVisible(old.safari))
    h.system.close(old.safari)
    #expect(web() == nil)
  }

  @Test func minimizingAndHidingChangeNoName() {
    let d = Desk()
    d.nameColumn()
    d.h.system.setMinimized(d.notes, true)
    d.h.system.setMinimized(d.mail, true)
    #expect(d.windows(named: "Writing") == [d.notes, d.mail])
    d.h.system.setMinimized(d.mail, false)
    d.h.run("go writing")
    #expect(d.h.system.isVisible(d.mail))
    #expect(d.windows(named: "Writing") == [d.notes, d.mail])
  }

  // MARK: 9. The last window

  @Test func theNameGoesWhenTheLastWindowCloses() {
    let d = Desk()
    d.nameColumn()
    d.h.system.close(d.notes)
    #expect(d.windows(named: "Writing") == [d.mail])
    d.h.system.close(d.mail)
    #expect(d.workspace.names.isEmpty, "the group around it was never called that")
    #expect(!d.h.run("go writing").ok)
    #expect(d.workspace.tree.invariantViolations() == [])
  }

  @Test func theNameGoesWhenTheLastWindowFloats() {
    let d = Desk()
    d.h.run("zoom \(d.safari.rawValue)")
    d.h.run("name Web")
    d.h.run("float \(d.safari.rawValue)")
    #expect(d.workspace.names.isEmpty)
  }

  @Test func theNameGoesWhenTheLastWindowMovesToAnotherDisplay() {
    let (d, music) = twoDisplays()
    d.h.run("zoom \(d.safari.rawValue)")
    d.h.run("name Web")
    d.h.run("show-all")
    d.h.run("dock \(d.safari.rawValue) beside \(music.rawValue) left")
    #expect(d.h.controller.workspaces.values.allSatisfy { $0.names.isEmpty })
  }

  @Test func excludingAnAppTakesItsNamesAlong() {
    let d = Desk()
    d.h.run("zoom \(d.safari.rawValue)")
    d.h.run("name Web")
    d.h.run("exclude \(d.h.controller.windows[d.safari]!.bundleID!)")
    #expect(d.workspace.names.isEmpty)
  }

  // MARK: 10. arrange and float-all

  @Test func arrangeAndFloatAllRemoveNamesAsTheyDoSavedViews() {
    for command in ["arrange", "arrange all", "float-all", "float-all here"] {
      let d = Desk()
      d.nameColumn()
      var heard: [Controller.Change] = []
      d.h.controller.observe { heard.append($0) }
      #expect(d.h.run(command).ok)
      #expect(d.workspace.names.isEmpty, "\(command)")
      #expect(heard.contains(.names(d.h.display)), "\(command)")
    }
  }

  // MARK: 11. Relaunch, pause, displays

  @Test func namesSurviveARelaunch() {
    let old = Desk()
    old.nameColumn("Writing Desk")
    old.h.run("zoom \(old.safari.rawValue)")
    old.h.run("name Web")
    old.h.controller.shutdown()

    let new = Desk(saved: old.h.store.saved)
    #expect(new.windows(named: "Writing Desk") == [new.notes, new.mail])
    #expect(new.windows(named: "web") == [new.safari])
    #expect(new.h.run("go writing").ok)
    #expect(new.inView() == [new.notes, new.mail])
  }

  @Test func namesSurviveTheFileItself() throws {
    let old = Desk()
    old.nameColumn("Büro 📝")
    old.h.controller.saveNow()
    let data = try JSONEncoder().encode(#require(old.h.store.saved))
    let new = Desk(saved: try JSONDecoder().decode(PersistedState.self, from: data))
    #expect(new.windows(named: "büro 📝") == [new.notes, new.mail])
  }

  @Test func afterARebootNamesFollowTheWindowsThatAreMatchedAgain() {
    let old = Desk()
    old.nameColumn()
    old.h.run("zoom \(old.safari.rawValue)")
    old.h.run("name Web")
    old.h.controller.shutdown()

    // Every window has a new number, and Safari has not restored its window yet.
    func launch() -> (Harness, notes: WindowID, mail: WindowID) {
      let h = Harness(saved: old.h.store.saved)
      for _ in 0..<5 { h.system.close(h.system.open(app: "Filler")) }
      let notes = h.system.open(app: "Notes", title: "Shopping")
      let mail = h.system.open(app: "Mail", title: "Inbox")
      h.start()
      return (h, notes, mail)
    }
    func windows(_ h: Harness, named name: String) -> [WindowID]? {
      h.workspace.node(named: name).map { h.workspace.tree.windows(under: $0) }
    }
    let (h, notes, mail) = launch()
    #expect(windows(h, named: "Writing") == [notes, mail])
    #expect(windows(h, named: "Web") != nil, "the name waits with the place that is kept for the window")
    let safari = h.system.open(app: "Safari", title: "Apple")
    #expect(windows(h, named: "Web") == [safari])

    // It never comes: the place is given up, and the name with it.
    let (late, _, _) = launch()
    late.scheduler.advance(by: Controller.pendingSlotLifetime + 1)
    late.run("relayout")  // the room it has kept goes back with the next layout somebody causes (Q16)
    #expect(windows(late, named: "Web") == nil)
    #expect(windows(late, named: "Writing") != nil)
  }

  @Test func namesSurviveAPause() {
    let d = Desk()
    d.nameColumn()
    d.h.run("pause")
    #expect(d.h.run("spaces").ok, "a query answers during a pause")
    #expect(d.h.run("spaces").text?.hasPrefix("Writing") == true)
    for command in ["go writing", "name Other", "unname", "ask-name"] {
      #expect(d.h.run(command).message.hasPrefix("paused"), "\(command)")
    }
    d.h.run("resume")
    #expect(d.windows(named: "Writing") == [d.notes, d.mail])
    #expect(d.h.run("go writing").ok)
  }

  @Test func anUnpluggedDisplayKeepsItsNamesAndBringsThemBack() {
    let (d, music) = twoDisplays()
    point(d, at: side)
    d.h.run("zoom \(music.rawValue)")
    d.h.run("name Tunes")
    point(d, at: main)
    d.nameColumn()

    d.h.system.setDisplays([main])
    #expect(d.h.run("go tunes").message == "tunes is on a display that is not connected")
    #expect(d.h.run("spaces").message == "1 named space")
    #expect(d.windows(named: "Writing") == [d.notes, d.mail], "the display that stayed keeps its own")

    d.h.system.setDisplays([main, side])
    #expect(d.windows(named: "Tunes", on: side.id) == [music])
    #expect(d.h.run("go tunes").ok)
  }

  @Test func namesOfAnUnpluggedDisplaySurviveARelaunch() {
    let (d, music) = twoDisplays()
    point(d, at: side)
    d.h.run("zoom \(music.rawValue)")
    d.h.run("name Tunes")
    d.h.system.setDisplays([main])
    d.h.controller.shutdown()

    let h = Harness(displays: [main], saved: d.h.store.saved)
    for window in d.h.system.allWindows() {
      _ = h.system.open(app: window.appName, bundleID: window.bundleID, title: window.title, pid: window.pid, frame: window.frame)
    }
    h.start()
    #expect(h.run("go tunes").message == "tunes is on a display that is not connected")
    h.system.setDisplays([main, side])
    let workspace = h.controller.workspaces[side.id]!
    #expect(workspace.node(named: "Tunes").map { workspace.tree.windows(under: $0) } == [music])
  }

  // MARK: 12. Called by its name

  @Test func repliesCallANamedSpaceByItsName() {
    let d = Desk()
    d.nameColumn()
    d.h.run("zoom \(d.mail.rawValue)")
    #expect(d.h.run("out").message == "stepped out to Writing (\(d.column))")
    #expect(d.h.run("save-view 1").message == "saved view 1: Writing (\(d.column))")
    d.h.run("show-all")
    #expect(d.h.run("view 1").message == "view 1: Writing (\(d.column))")
    d.h.run("desktop")
    #expect(d.h.run("neighbor right").message == "moved to Writing (\(d.column))")
    #expect(d.h.run("back").ok && d.h.run("forward").message == "forward to Writing (\(d.column))")
  }

  @Test(.withTiles) func aTileThatStandsForANamedSpaceIsCaptionedWithTheName() {
    let d = Desk(settings: Settings())
    d.nameColumn()
    #expect(d.h.overlays.tiles[d.h.display]?.isEmpty == true)
    // Squeeze the column, half of the display, until it is too narrow to use.
    d.h.run("resize \(d.notes.rawValue) left -640")
    guard let tile = d.h.overlays.tiles[d.h.display]?.first(where: { $0.node == d.column }) else {
      Issue.record("the column should be a tile: \(d.h.ascii())")
      return
    }
    #expect(tile.name == "Writing" && tile.title == "Writing")
    #expect(d.h.ascii().contains("#Wri"), "as much of it as fits")
    d.h.run("unname Writing")
    #expect(d.h.overlays.tiles[d.h.display]?.first { $0.node == d.column }?.title == "2 windows")
    d.h.overlays.clickTile(d.column)
    #expect(d.inView() == [d.notes, d.mail])
  }

  @Test func theMenuListsTheNamesGoCanReach() {
    let (d, music) = twoDisplays()
    #expect(d.h.controller.namedSpacesMenu().map(\.title) == ["Name This Space…"], "nothing is named yet")

    d.nameColumn("Media")
    point(d, at: side)
    d.h.run("zoom \(music.rawValue)")
    d.h.run("name Media")
    d.h.run("show-all")
    d.h.run("name Side")
    point(d, at: main)
    d.h.run("go media")

    let menu = d.h.controller.namedSpacesMenu()
    #expect(menu.map(\.title) == ["Media", "Side", "Name This Space…"])
    #expect(menu.map(\.command) == [.goToSpace("Media"), .goToSpace("Side"), .askName(cancel: false)])
    #expect(menu.map(\.isTicked) == [true, true, false], "each is in view on its display")
    #expect(menu.map(\.startsSection) == [false, false, true])
    // Every row does what it says.
    d.h.run("show-all")
    #expect(d.h.controller.perform(menu[0].command, from: .menu).ok)
    #expect(d.inView(on: main.id) == [d.notes, d.mail], "the Media of this display: the other one is reached from there")
    #expect(d.h.controller.perform(menu[2].command, from: .menu).ok)
    #expect(d.h.overlays.namePrompt?.display == main.id)
  }

  @Test func namedSpacesSaysWhatOtherFeaturesNeed() {
    let d = Desk()
    d.nameColumn()
    let extra = d.h.system.open(app: "Notes", title: "Second")
    d.h.run("dock \(extra.rawValue) beside \(d.mail.rawValue) bottom")
    let spaces = d.h.controller.namedSpaces()
    #expect(spaces.count == 1)
    #expect(spaces[0].name == "Writing" && spaces[0].display == d.h.display && spaces[0].node == d.column)
    #expect(spaces[0].label == "2 Notes windows and Mail (\(d.column))")
    #expect(spaces[0].windows == [d.notes, d.mail, extra])
    #expect(spaces[0].apps == ["Notes", "Mail"], "each app once")
    #expect(!spaces[0].isInView && spaces[0].isReachable)
    #expect(d.h.controller.spaceName(of: d.column, on: d.h.display) == "Writing")
    #expect(d.h.controller.spaceName(of: d.leaf(d.safari), on: d.h.display) == nil)
    #expect(d.h.controller.spaceName(of: d.column, on: DisplayID("nowhere")) == nil)
  }

  @Test func observersHearWhenNamesChange() {
    let d = Desk()
    d.frameColumn()
    var heard: [Controller.Change] = []
    d.h.controller.observe { heard.append($0) }
    d.h.run("name Writing")
    #expect(heard.filter { $0 == .names(d.h.display) }.count == 1)
    heard.removeAll()
    d.h.run("name Writing")
    #expect(!heard.contains(.names(d.h.display)), "nothing changed")
    d.h.run("unname")
    #expect(heard.contains(.names(d.h.display)))
  }

  @Test func namingIsSaved() {
    let d = Desk()
    d.frameColumn()
    d.h.scheduler.runPending()
    d.h.run("name Writing")
    d.h.scheduler.runPending()
    #expect(d.h.store.saved?.workspaces[d.h.display]?.names == ["Writing": d.column])
    d.h.run("unname")
    d.h.scheduler.runPending()
    #expect(d.h.store.saved?.workspaces[d.h.display]?.names.isEmpty == true)
  }

  @Test func theNameOfADisplayWithNoWindowOnItComesBackWithTheDisplay() {
    let d = Desk(displays: [main, side])
    d.h.system.cursor = CGPoint(x: side.frame.midX, y: side.frame.midY)
    #expect(d.h.run("name Reference").ok, "its Desktop, with nothing on it yet")
    #expect(d.h.controller.workspaces[side.id]?.names.count == 1)
    d.h.system.cursor = CGPoint(x: 700, y: 400)

    d.h.system.setDisplays([main])
    let away = d.h.run("go Reference")
    #expect(!away.ok && away.message.contains("not connected"), "\(away.message)")
    d.h.system.setDisplays([main, side])
    #expect(d.h.controller.workspaces[side.id]?.names.keys.sorted() == ["Reference"])
    #expect(d.h.run("go Reference").ok)
    #expect(d.h.layoutProblems() == [])
  }

  // MARK: A held view (F58)

  @Test func onAHeldViewANameCanBeGivenAndTakenOffAndNothingOpensOrMoves() {
    let d = Desk()
    d.nameColumn("Writing")
    d.h.run("zoom \(d.safari.rawValue)")
    #expect(d.h.run("hold").ok)
    let (frames, view, moves) = (d.frames, d.workspace.camera, d.h.system.frameLog.count)

    #expect(d.h.run("name Call").ok, "it remembers where the view is, like save-view")
    #expect(d.workspace.names["Call"] == view)
    #expect(d.h.run("spaces").ok)
    #expect(d.h.run("unname Writing").ok)
    #expect(d.workspace.names == ["Call": view])
    #expect(d.h.run("unname").ok)
    #expect(d.workspace.names.isEmpty)

    d.h.run("name Call")
    // In front of an audience no field opens, and the view goes nowhere.
    let field = d.h.run("ask-name")
    #expect(!field.ok && field.message.contains("the view is held"), "\(field.message)")
    #expect(d.h.overlays.namePrompt == nil)
    #expect(d.h.run("ask-name cancel").ok)
    d.h.run("release")
    d.nameColumn("Writing")
    d.h.run("zoom \(d.safari.rawValue)")
    d.h.run("hold")
    let go = d.h.run("go Writing")
    #expect(!go.ok && go.message.contains("the view is held"), "\(go.message)")

    #expect(d.workspace.camera == view && d.frames == frames)
    #expect(d.h.system.frameLog.count >= moves)
    #expect(d.h.layoutProblems() == [])
  }

  @Test func aFieldLeftOpenWhenTheViewBeganToBeHeldCanBePutAway() {
    // It closes by itself when `hold` begins (F58's side). Should it ever be open on a held view, ⎋ must work.
    let d = Desk()
    d.frameColumn()
    d.h.run("ask-name")
    d.h.run("hold")
    #expect(d.h.run("ask-name cancel").ok)
    #expect(d.h.overlays.namePrompt == nil)
  }

  // MARK: The log

  /// Failures are logged only with `ARBOR_DEBUG`, which no test runs with, and that is the log people are asked to send. A
  /// command's own text holds what a person typed: names of spaces, titles in a `layout` line or a rule.
  @Test func noLogLineWritesACommandsOwnText() throws {
    let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    let folder = root.appendingPathComponent("Sources/ArborKit/Controller")
    let files = try FileManager.default.contentsOfDirectory(atPath: folder.path).filter { $0.hasSuffix(".swift") }
    #expect(files.count > 10)
    for file in files.sorted() {
      let source = try String(contentsOf: folder.appendingPathComponent(file), encoding: .utf8)
      for (number, line) in source.split(separator: "\n", omittingEmptySubsequences: false).enumerated()
      where line.contains("Log.") && line.contains("command.text)") {
        Issue.record("\(file):\(number + 1) logs `command.text`; `command.textWithoutNames` is for the log")
      }
    }
  }

  @Test func namesStayOutOfTheLog() throws {
    // The real log file, which every test writes to: a name nobody else uses, and lines nobody else writes.
    let d = Desk()
    d.frameColumn()
    let column = d.column
    for command in [
      "name Quixotry Merger", "show-all", "go quixotry m", "in", "out", "save-view 1", "desktop", "view 1", "back", "forward", "name Quixotry Two",
      "go Quixotry Nowhere", "ask-name", "ask-name cancel", "unname quixotry two", "name Quixotry Three", "arrange",
    ] { d.h.run(command) }
    _ = d.h.controller.admit(url: "arbor://name/Quixotry/Four")
    _ = d.h.controller.admit(url: "arbor://unname/Quixotry/Five")
    // With the file before it, in case the log was rotated just now.
    let log =
      ((try? String(contentsOf: ArborPaths.logFile.appendingPathExtension("1"), encoding: .utf8)) ?? "")
      + (try String(contentsOf: ArborPaths.logFile, encoding: .utf8))
    #expect(!log.lowercased().contains("quixotry"))
    #expect(log.contains("name ‹name›: named Notes and Mail (\(column)): ‹name›"))
    #expect(log.contains("go ‹name›: moved to ‹name› (\(column))"), "the space's number is what the log gets")
    #expect(log.contains("out: stepped out to ‹name› (\(column))"), "also in the replies of other commands")
    #expect(log.contains("unname ‹name›: removed the name ‹name› from Notes and Mail (\(column))"))
    #expect(log.contains("refused a URL, arbor://name…"))
  }

  @Test func theLogLosesTooMuchRatherThanTooLittle() throws {
    #expect(Controller.withoutNames("moved to Mail Room (n5)", ["Mail", "Mail Room"]) == "moved to ‹name› (n5)")
    #expect(Controller.withoutNames("named Notes and Mail (n5): Mail", ["Mail"]) == "named Notes and ‹name› (n5): ‹name›")
    #expect(Controller.withoutNames("showing everything", []) == "showing everything")
    #expect(Command.name("Secret").textWithoutNames == "name ‹name›")
    #expect(Command.goToSpace("Secret").textWithoutNames == "go ‹name›")
    #expect(Command.unname("Secret").textWithoutNames == "unname ‹name›")
    #expect(Command.unname(nil).textWithoutNames == "unname")
    #expect(Command.dock(nil, .left).textWithoutNames == "dock left")
    // One text for the log, whoever asks: nor the parts of titles that `layout` (F54) and `find` (F27) can hold.
    #expect(try Command.parse("layout Safari~Secret | Mail").textWithoutNames == "layout Safari~… | Mail")
    #expect(Command.find("Secret").textWithoutNames == "find …")
  }

  @Test func arrangeAndFloatAllSayHowManyNamesWent() {
    let d = Desk()
    d.nameColumn()
    #expect(d.h.run("arrange").message == "arranged 3 windows; 1 name is gone")
    #expect(d.h.run("arrange").message == "arranged 3 windows", "nothing to say the second time")
    d.h.run("name All")
    d.h.run("zoom \(d.safari.rawValue)")
    d.h.run("name Web")
    #expect(d.h.run("float-all").message == "floated 3 windows; 2 names are gone")
  }

  @Test func whicheverCommandTakesANameAlongSaysSo() {
    // A line of text builds the arrangement anew. A name stays with a space that still holds the same windows, so the line of
    // the arrangement that is there takes nothing along, and another one does.
    var d = Desk()
    d.nameColumn()
    let line = d.h.run("layout").text ?? d.h.run("layout").message
    #expect(d.h.run("layout \(line)").message == "arranged 3 windows", "\(line)")
    #expect(d.windows(named: "Writing") == [d.notes, d.mail])
    #expect(d.h.run("layout Mail | Safari | Notes").message.hasSuffix("; 1 name is gone"))
    #expect(d.workspace.names.isEmpty)

    // The last window of a named space floats.
    d = Desk()
    d.h.run("zoom \(d.safari.rawValue)")
    d.h.run("name Web")
    #expect(d.h.run("float \(d.safari.rawValue)").message.hasSuffix("; 1 name is gone"))

    // Its app is not arranged any more.
    d = Desk()
    d.h.run("zoom \(d.safari.rawValue)")
    d.h.run("name Web")
    d.h.run("show-all")
    #expect(d.h.run("exclude com.example.safari").message.hasSuffix("; 1 name is gone"))

    // Not when nothing went, nor when taking it off was the point, nor when it only waits with a display or a pause.
    d = Desk()
    d.nameColumn()
    for command in ["float \(d.notes.rawValue)", "dock \(d.notes.rawValue) left", "show-all", "name Other", "unname", "pause", "resume"] {
      let reply = d.h.run(command)
      #expect(reply.ok && !reply.message.contains("gone"), "\(command): \(reply.message)")
    }
  }

  // MARK: 14. URLs

  @Test func aURLMayGoButNotNameUnnameAskOrList() {
    let d = Desk()
    d.nameColumn("Writing Desk")
    guard case .success(let command) = d.h.controller.admit(url: "arbor://go/writing/desk") else {
      Issue.record("refused")
      return
    }
    #expect(d.h.controller.perform(command).ok)
    #expect(d.inView() == [d.notes, d.mail])
    for url in ["arbor://name/Free/prizes", "arbor://name", "arbor://unname", "arbor://unname/Writing/Desk", "arbor://ask-name", "arbor://spaces"] {
      guard case .failure = d.h.controller.admit(url: url) else {
        Issue.record("\(url) was accepted")
        continue
      }
    }
    #expect(d.workspace.names.keys.sorted() == ["Writing Desk"])
  }
}

/// F20: the field a name is typed into (⌃⌥N).
@Suite @MainActor struct NameFieldTests {
  private func subject(_ model: NamePromptModel?) -> (node: NodeID, current: String?, contents: String, others: [String: String])? {
    guard case .space(let node, let current, let contents, let others)? = model?.subject else { return nil }
    return (node, current, contents, others)
  }

  @Test func theShortcutIsControlOptionN() throws {
    let chord = try KeyChord(text: "ctrl+opt+n")
    #expect(KeyBindings.all.first { $0.chord == chord }?.command == .askName(cancel: false))
    #expect(KeyBindings.label(for: .askName(cancel: false), in: KeyBindings.all) == "⌃⌥N")
  }

  @Test func askingShowsTheFieldOverTheSpaceAndMovesNothing() {
    let d = Desk()
    d.frameColumn()
    d.h.system.userFocus(d.mail)
    d.h.system.clearFrameLog()
    #expect(d.h.overlays.namePrompt == nil)

    #expect(d.h.run("ask-name").message == "type a name for Notes and Mail (\(d.column))")
    let model = d.h.overlays.namePrompt
    #expect(model?.display == d.h.display)
    #expect(model?.title == "Name this space" && model?.initial == "")
    #expect(subject(model)?.node == d.column && subject(model)?.contents == "Notes and Mail")
    let frame = model!.frame
    #expect(frame.size == NamePromptModel.size && frame.midX == d.h.visibleFrame.midX)
    #expect(d.h.visibleFrame.contains(frame) && frame.midY < d.h.visibleFrame.midY, "in the upper middle")
    #expect(d.h.visibleFrame == CGRect(x: 0, y: 25, width: 1440, height: 875))
    #expect(frame == CGRect(x: 530, y: 218, width: 380, height: 96), "centred, its top 22 % of the way down")
    #expect(d.h.system.frameLog.isEmpty && d.h.system.focused == d.mail, "no window moves, the keyboard's window stays")
  }

  @Test func returnNamesTheSpaceAndClosesTheField() {
    let d = Desk()
    d.frameColumn()
    d.h.run("ask-name")
    #expect(d.h.overlays.submitName(" Writing  Desk ")?.message == "named Notes and Mail (\(d.column)): Writing Desk")
    #expect(d.workspace.names == ["Writing Desk": d.column])
    #expect(d.h.overlays.namePrompt == nil)
  }

  @Test func theFieldStartsWithTheNameTheSpaceHas() {
    let d = Desk()
    d.frameColumn()
    d.h.run("name Draft")
    d.h.run("ask-name")
    let model = d.h.overlays.namePrompt
    #expect(model?.title == "Rename this space" && model?.initial == "Draft")
    #expect(d.h.overlays.submitName("Writing")?.message == "renamed Draft to Writing (\(d.column))")
  }

  @Test func theLineUnderTheFieldSaysWhatReturnWillDo() {
    let d = Desk()
    d.nameColumn("Mail")
    d.h.run("zoom \(d.safari.rawValue)")
    d.h.run("ask-name")
    let fresh = d.h.overlays.namePrompt!
    #expect(fresh.answer(to: "") == .init(command: .askName(cancel: true), note: "Safari"))
    #expect(fresh.answer(to: "  ") == .init(command: .askName(cancel: true), note: "Safari"))
    #expect(fresh.answer(to: "Web") == .init(command: .name("Web"), note: "↩ names Safari"))
    #expect(fresh.answer(to: " my  web ") == .init(command: .name("my web"), note: "↩ names Safari"))
    #expect(fresh.answer(to: "MAIL") == .init(command: .name("MAIL"), note: "↩ moves the name here from Notes and Mail"))
    #expect(
      fresh.answer(to: "up")
        == .init(command: nil, note: "a space cannot be named `up`: `go up` means the neighboring space", isProblem: true))
    #expect(fresh.answer(to: String(repeating: "x", count: 41)).isProblem)
    for text in ["", "Web", "MAIL"] { #expect(!fresh.answer(to: text).isProblem, "\(text)") }
    #expect(!NamePromptModel.Answer(command: nil, note: "").isProblem)

    d.h.overlays.submitName("Web")
    d.h.run("ask-name")
    let named = d.h.overlays.namePrompt!
    #expect(named.answer(to: "") == .init(command: .unname(nil), note: "↩ removes the name Web"))
    #expect(named.answer(to: "Web") == .init(command: .askName(cancel: true), note: "Safari"))
    #expect(named.answer(to: "web") == .init(command: .name("web"), note: "↩ names Safari"), "its own name in other capitals")
  }

  @Test func aNameThatIsRefusedKeepsTheFieldOpen() {
    let d = Desk()
    d.frameColumn()
    d.h.run("ask-name")
    #expect(d.h.overlays.submitName("left") == nil)
    #expect(d.h.overlays.namePrompt != nil)
    #expect(d.workspace.names.isEmpty)
    #expect(d.h.overlays.submitName("Left side")?.ok == true)
  }

  @Test func anEmptyFieldRemovesTheNameOrJustCloses() {
    let d = Desk()
    d.frameColumn()
    d.h.run("name Writing")
    d.h.run("ask-name")
    #expect(d.h.overlays.submitName("")?.message == "removed the name Writing from Notes and Mail (\(d.column))")
    #expect(d.h.overlays.namePrompt == nil && d.workspace.names.isEmpty)
    d.h.run("ask-name")
    #expect(d.h.overlays.submitName("")?.ok == true)
    #expect(d.h.overlays.namePrompt == nil && d.workspace.names.isEmpty)
  }

  @Test func escapeTheShortcutAgainAndCancelCloseItAndChangeNothing() {
    let d = Desk()
    d.frameColumn()
    for close in [{ d.h.overlays.cancelName() }, { _ = d.h.run("ask-name") }, { _ = d.h.run("ask-name cancel") }] {
      d.h.run("ask-name")
      #expect(d.h.overlays.namePrompt != nil)
      close()
      #expect(d.h.overlays.namePrompt == nil)
    }
    #expect(d.workspace.names.isEmpty)
    #expect(d.h.run("ask-name cancel").ok, "closing what is closed is no error")
  }

  @Test func theFieldClosesWhenTheViewLeavesItsSpace() {
    for leave in ["show-all", "in", "neighbor left", "desktop", "home", "arrange", "float-all"] {
      let d = Desk()
      d.frameColumn()
      d.h.run("ask-name")
      #expect(d.h.run(leave).ok, "\(leave)")
      #expect(d.h.overlays.namePrompt == nil, "\(leave)")
      // And it does not come back with the view.
      d.h.run("back")
      #expect(d.h.overlays.namePrompt == nil, "\(leave), then back")
    }
  }

  @Test func theFieldStaysWhileTheViewStays() {
    let d = Desk()
    d.frameColumn()
    d.h.system.userFocus(d.notes)
    d.h.run("ask-name")
    d.h.run("resize \(d.notes.rawValue) bottom 40")
    d.h.run("relayout")
    d.h.scheduler.advance(by: 2)
    #expect(d.h.overlays.namePrompt != nil)
    d.h.system.userFocus(d.notes)
    #expect(d.h.overlays.namePrompt != nil, "macOS reports some focus changes twice; the window had the keyboard already")
    d.h.system.backgroundFocus(d.safari)
    d.h.scheduler.advance(by: 2)
    #expect(d.h.overlays.namePrompt != nil, "an app in the background has not taken the keyboard")
    #expect(d.h.overlays.submitName("Writing")?.ok == true)
  }

  @Test func theFieldClosesWhenAnotherWindowGetsTheKeyboard() {
    let d = Desk()
    d.frameColumn()
    d.h.system.userFocus(d.notes)
    d.h.run("ask-name")
    // A click, ⌘Tab, a swipe to another macOS Space: the view stays, the field has been left.
    d.h.system.userFocus(d.mail)
    #expect(d.h.overlays.namePrompt == nil)
    #expect(d.inView() == [d.notes, d.mail] && d.workspace.names.isEmpty)
  }

  @Test func theFieldClosesWhenItsSpaceGoesAway() {
    let d = Desk()
    d.h.run("zoom \(d.safari.rawValue)")
    d.h.run("ask-name")
    d.h.system.close(d.safari)
    #expect(d.h.overlays.namePrompt == nil)
    #expect(d.h.overlays.submitName("Web") == nil)
    #expect(d.workspace.names.isEmpty)
  }

  @Test func theFieldClosesWhenArborPausesOrQuits() {
    for stop in ["pause", "quit"] {
      let d = Desk()
      d.frameColumn()
      d.h.run("ask-name")
      if stop == "pause" { d.h.run("pause") } else { d.h.controller.shutdown() }
      #expect(d.h.overlays.namePrompt == nil, "\(stop)")
      if stop == "pause" {
        d.h.run("resume")
        #expect(d.h.overlays.namePrompt == nil, "it does not come back with the windows")
      }
    }
  }

  @Test func theFieldBelongsToItsDisplayWhereverThePointerGoes() {
    let d = Desk(displays: [main, side])
    let music = d.h.system.open(app: "Music", frame: CGRect(x: 1600, y: 200, width: 600, height: 400))
    d.h.run("dock \(music.rawValue) right")
    d.frameColumn()
    d.h.run("ask-name")
    #expect(d.h.overlays.scenes[side.id]?.namePrompt == nil, "one field, on one display")
    d.h.system.cursor = side.frame.center
    #expect(d.h.overlays.submitName("Writing")?.ok == true)
    #expect(d.windows(named: "Writing", on: main.id) == [d.notes, d.mail])
    #expect(d.h.controller.workspaces[side.id]!.names.isEmpty)
  }

  @Test func theFieldClosesWhenItsDisplayIsUnplugged() {
    let d = Desk(displays: [main, side])
    let music = d.h.system.open(app: "Music", frame: CGRect(x: 1600, y: 200, width: 600, height: 400))
    d.h.run("dock \(music.rawValue) right")
    d.h.system.cursor = side.frame.center
    d.h.run("ask-name")
    #expect(d.h.overlays.namePrompt?.display == side.id)
    d.h.system.setDisplays([main])
    #expect(d.h.overlays.namePrompt == nil)
    d.h.system.setDisplays([main, side])
    #expect(d.h.overlays.namePrompt == nil, "it does not come back with the display")
  }

  @Test func onASmallDisplayTheFieldStaysOnIt() {
    let tiny = CGRect(x: 10, y: 20, width: 300, height: 80)
    #expect(tiny.contains(NamePromptModel.frame(in: tiny)))
    #expect(NamePromptModel.frame(in: .zero) == .zero)
  }
}
