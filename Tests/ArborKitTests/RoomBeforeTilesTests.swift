import ArborCore
import ArborKit
import ArborTesting
import CoreGraphics
import Foundation
import Testing

/// F61: before a window becomes a tile because its slot is smaller than the window will go, Arbor moves the gaps around it.
/// The sizes are those of real apps on a 1440-point display.
@Suite @MainActor struct RoomBeforeTilesTests {
  let notesMinimum = CGSize(width: 709, height: 300)
  let safariMinimum = CGSize(width: 574, height: 240)

  /// Notes and Safari, floating, started. A test of what the Desktop between them gives, gets back or looks like names the column.
  func makeHarness(settings: Settings = Harness.settingsWhenNoneAreGiven) -> (Harness, notes: WindowID, safari: WindowID) {
    let h = Harness(settings: settings)
    let notes = h.system.open(
      app: "Notes", frame: CGRect(x: 200, y: 100, width: 1000, height: 660), minimumSize: notesMinimum)
    let safari = h.system.open(
      app: "Safari", frame: CGRect(x: 60, y: 60, width: 1324, height: 800), minimumSize: safariMinimum)
    h.start()
    return (h, notes, safari)
  }

  func isTile(_ h: Harness, _ window: WindowID) -> Bool {
    h.layout?.tiles.contains { $0.windows.contains(window) } == true
  }

  /// In view, where the layout says (a window that is within a point of its slot is left alone), and nothing over
  /// anything else.
  func expectInView(_ h: Harness, _ windows: WindowID..., sourceLocation: SourceLocation = #_sourceLocation) {
    for window in windows {
      #expect(!isTile(h, window), "\(window) is a tile", sourceLocation: sourceLocation)
      #expect(h.layout?.windowFrames[window] != nil, "\(window) has no slot", sourceLocation: sourceLocation)
      let slot = h.layout?.windowFrames[window] ?? .zero
      #expect(
        h.frame(window)?.approximatelyEquals(slot, tolerance: 1) == true, "\(window): \(String(describing: h.frame(window))) in \(slot)",
        sourceLocation: sourceLocation)
    }
    let frames = (h.layout?.windowFrames.keys.sorted() ?? []).compactMap { h.frame($0) }
    for (index, first) in frames.enumerated() {
      for second in frames[(index + 1)...] {
        #expect(!first.overlaps(second), "\(first) and \(second)", sourceLocation: sourceLocation)
      }
    }
  }

  // MARK: Acceptance criteria

  @Test func notesOnTheLeftAndSafariOnTheRightAreBothInView() throws {
    let (h, notes, safari) = makeHarness(settings: .withDesktopColumn)
    h.run("dock \(notes.rawValue) left")
    h.run("dock \(safari.rawValue) right")
    expectInView(h, notes, safari)
    #expect(try #require(h.frame(notes)).width >= 709)
    #expect(try #require(h.frame(safari)).width >= 574)
    #expect(h.layout?.tiles.map(\.kind) == [.desktop], "the empty Desktop is a tile between them")
    #expect(h.workspace.tree.invariantViolations().isEmpty)
  }

  /// Somebody has asked for each docked window, nobody for the Desktop's points. Whether the Calculator was there first makes no
  /// difference: it shows over the arrangement.
  @Test(arguments: [true, false]) func dockedWindowsComeBeforeTheDesktopWhateverFloatsOnIt(calculatorFirst: Bool) {
    let (h, notes, safari) = makeHarness(settings: .withDesktopColumn)
    func open() -> WindowID { h.system.open(app: "Calculator", frame: CGRect(x: 600, y: 300, width: 230, height: 408)) }
    var calculator = calculatorFirst ? open() : nil
    h.run("dock \(notes.rawValue) left")
    h.run("dock \(safari.rawValue) right")
    calculator = calculator ?? open()
    h.run("zoom \(safari.rawValue)")
    h.run("show-all")
    expectInView(h, notes, safari)
    #expect(h.layout?.tiles.map(\.kind) == [.desktop])
    #expect(h.system.isVisible(calculator!))
  }

  @Test func withoutTheSettingBothAreTilesAsBefore() {
    var settings = Settings.withDesktopColumn
    settings.makeRoom = false
    let (h, notes, safari) = makeHarness(settings: settings)
    h.run("dock \(notes.rawValue) left")
    h.run("dock \(safari.rawValue) right")
    #expect(isTile(h, notes) && isTile(h, safari))
    let weights = h.workspace.tree.children(of: h.workspace.tree.root).map { h.workspace.tree[$0]!.weight }
    #expect(weights == [1, 1, 1])
  }

  @Test func oldSettingsFilesMakeRoomAndTheSettingIsSaved() throws {
    #expect(try JSONDecoder().decode(Settings.self, from: Data("{}".utf8)).makeRoom)
    var settings = Settings()
    settings.makeRoom = false
    #expect(try JSONDecoder().decode(Settings.self, from: JSONEncoder().encode(settings)).makeRoom == false)
  }

  @Test func nothingToSpareMakesATileAndMovesNoGap() {
    let (h, notes, safari) = makeHarness()
    let xcode = h.system.open(
      app: "Xcode", frame: CGRect(x: 100, y: 100, width: 1300, height: 700), minimumSize: CGSize(width: 1300, height: 600))
    h.run("dock \(notes.rawValue) left")
    h.run("dock \(safari.rawValue) right")
    h.run("dock \(xcode.rawValue) beside \(safari.rawValue) bottom")
    #expect(isTile(h, xcode))
    expectInView(h, notes, safari)
    // Nothing was taken for it that would not have been enough: the column is still shared half and half.
    let tree = h.workspace.tree
    let column = tree.leaf(containing: xcode).flatMap { tree.parent(of: $0) }
    #expect(column.map { tree.children(of: $0).map { tree[$0]!.weight } } == [1, 1])
  }

  @Test func aGapDraggedByHandCanStillSqueezeAWindowIntoATileAndItStaysOne() throws {
    let (h, notes, safari) = makeHarness()
    let mail = h.system.open(app: "Mail")
    h.run("dock \(safari.rawValue) left")
    h.run("dock \(mail.rawValue) right")
    expectInView(h, safari, mail)
    let seam = try #require(h.overlays.seams[h.display]?.first { $0.leading == h.workspace.tree.leaf(containing: safari) })
    h.overlays.dragSeam(seam, by: -200)
    #expect(isTile(h, safari), "squeezed on purpose")
    let squeezed = h.workspace.tree

    // Nothing Arbor does by itself afterwards widens it again.
    h.run("zoom \(mail.rawValue)")
    h.run("back")
    #expect(isTile(h, safari))
    h.system.setMinimized(mail, true)
    h.system.setMinimized(mail, false)
    h.scheduler.runPending()
    #expect(isTile(h, safari))
    #expect(h.workspace.tree == squeezed)
    // Looking at it and coming back does not either.
    h.run("zoom \(safari.rawValue)")
    h.run("back")
    #expect(isTile(h, safari))
    // Another window still gets its room, from others.
    h.run("dock \(notes.rawValue) beside \(mail.rawValue) bottom")
    #expect(isTile(h, safari))
    expectInView(h, notes, mail)

    // The hand that squeezed it lets it out, and giving it another place does too.
    let again = try #require(h.overlays.seams[h.display]?.first { $0.leading == h.workspace.tree.leaf(containing: safari) })
    h.overlays.dragSeam(again, by: 260)
    #expect(!isTile(h, safari))
  }

  @Test func aSqueezedWindowThatIsGivenAnotherPlaceGetsRoomThere() throws {
    let (h, _, safari) = makeHarness()
    let mail = h.system.open(app: "Mail")
    h.run("dock \(safari.rawValue) left")
    h.run("dock \(mail.rawValue) right")
    #expect(h.run("resize \(safari.rawValue) right -200").ok)
    #expect(isTile(h, safari), "`resize` is the person's hand too")
    h.run("float \(safari.rawValue)")
    h.run("dock \(safari.rawValue) right")
    expectInView(h, safari, mail)
  }

  @Test func draggingAWindowsOwnEdgeCanSqueezeItsNeighbour() throws {
    let (h, _, safari) = makeHarness()
    let mail = h.system.open(app: "Mail")
    h.run("dock \(mail.rawValue) left")
    h.run("dock \(safari.rawValue) beside \(mail.rawValue) right")
    expectInView(h, safari, mail)
    var frame = try #require(h.frame(mail))
    frame.size.width += 150
    h.system.userResize(mail, to: frame)
    h.scheduler.runPending()
    #expect(isTile(h, safari))
    #expect(try #require(h.frame(mail)).width == frame.width, "Arbor does not push back")
  }

  @Test func thePreviewOfAWindowWhoseMinimumIsKnownIsWhereItLands() throws {
    let (h, notes, safari) = makeHarness()
    h.run("dock \(safari.rawValue) right")
    // Once docked and floated again, Arbor knows how narrow Notes will go.
    h.run("dock \(notes.rawValue) left")
    h.run("float \(notes.rawValue)")
    let start = try #require(h.frame(notes))
    let grab = CGPoint(x: start.midX, y: start.minY + 10)
    h.system.tiling = .off  // the screen's edges are Arbor's only with macOS's tiling off
    h.system.drag(notes, through: [grab, CGPoint(x: 300, y: 400), CGPoint(x: 3, y: 450)])
    expectInView(h, notes, safari)
    let preview = try #require(h.overlays.previewHistory.compactMap { $0 }.last)
    #expect(try #require(h.frame(notes)).approximatelyEquals(preview, tolerance: 1), "\(preview)")
  }

  /// With F02: the neighbours that give room arrive where they end up in the motion that shows the dock, not after it.
  @Test func theGapsMoveInTheSameMotionAsTheDock() throws {
    let (h, notes, safari) = makeHarness()
    h.run("dock \(notes.rawValue) left")
    h.overlays.clearTransitions()
    h.run("dock \(safari.rawValue) right")
    expectInView(h, notes, safari)
    let motion = try #require(h.overlays.transitions.last)
    for window in [notes, safari] {
      #expect(try #require(motion[window]).to.approximatelyEquals(try #require(h.frame(window)), tolerance: 1))
      #expect(motion[window]?.toLook == .picture)
    }
  }

  @Test func theGapsStayWhereTheyWerePutAcrossARestart() throws {
    let (old, notes, safari) = makeHarness()
    old.run("dock \(notes.rawValue) left")
    old.run("dock \(safari.rawValue) right")
    let frames = [old.frame(notes), old.frame(safari)]
    old.controller.shutdown()

    let h = Harness(saved: old.store.saved)
    for window in old.system.allWindows() {
      h.system.open(
        app: window.appName, bundleID: window.bundleID, title: window.title, pid: window.pid, frame: window.frame,
        minimumSize: window.id == notes ? notesMinimum : safariMinimum)
    }
    h.start()
    expectInView(h, notes, safari)
    for (window, frame) in zip([notes, safari], frames) {
      #expect(h.frame(window)?.approximatelyEquals(frame ?? .zero, tolerance: 1) == true)
    }
    #expect(h.workspace.tree == old.workspace.tree)
    // Into its slot, from wherever the quit left it, and no second thoughts.
    for window in [notes, safari] {
      #expect((movesWithoutWaste(h, of: window) ?? 2) <= 1 && FakeWindowSystem.detour(h.system.road(of: window)) == nil)
    }
  }

  // MARK: Whenever Arbor itself changes who has how much

  @Test func aNeighbourThatWasAskedForTooMuchGetsItsPlaceBack() throws {
    // Arbor has not met Safari's minimum yet when Xcode asks for room, so it takes more from Safari than Safari will give.
    let (h, _, safari) = makeHarness(settings: .withDesktopColumn)
    let mail = h.system.open(app: "Mail")
    let xcode = h.system.open(
      app: "Xcode", frame: CGRect(x: 100, y: 100, width: 1000, height: 700), minimumSize: CGSize(width: 900, height: 600))
    h.system.setMinimumSize(safari, CGSize(width: 460, height: 240))
    h.run("dock \(safari.rawValue) left")
    h.run("dock \(mail.rawValue) right")
    let place = try #require(h.frame(safari))
    h.system.clearFrameLog()
    h.run("dock \(xcode.rawValue) beside \(mail.rawValue) bottom")
    // 901 for Xcode and 80 for the Desktop leave 411, and Safari will not go under 460. Nobody in view pays with their place.
    #expect(isTile(h, xcode))
    expectInView(h, safari, mail)
    #expect(h.frame(safari) == place, "as if everything had been known at the start")
    #expect(h.workspace.tree.children(of: h.workspace.tree.root).map { h.workspace.tree[$0]!.weight } == [1, 1, 1])
    #expect(h.system.frameLog.count <= 16, "a few rounds, then an end: \(h.system.frameLog.count)")
  }

  @Test func whoComesFirstDoesNotDependOnWhomArborHasMetBefore() {
    // Notes is known, Activity Monitor is not: it is still Activity Monitor, docked last, that gets the room there is.
    let (h, notes, _) = makeHarness()
    let activity = h.system.open(
      app: "Activity Monitor", frame: CGRect(x: 300, y: 100, width: 960, height: 640), minimumSize: CGSize(width: 740, height: 384))
    h.run("dock \(notes.rawValue) left")
    expectInView(h, notes)
    h.system.userFocus(activity)
    h.run("dock \(activity.rawValue) right")
    expectInView(h, activity)
    #expect(isTile(h, notes), "the two need 1449 of the 1312 there are beside the narrowest Desktop")
  }

  @Test func aWindowThatComesBackFromTheDockGetsRoom() {
    let (h, notes, safari) = makeHarness()
    h.run("dock \(notes.rawValue) left")
    h.system.setMinimized(notes, true)
    h.run("dock \(safari.rawValue) right")
    h.system.setMinimized(notes, false)
    h.scheduler.runPending()
    expectInView(h, notes, safari)
  }

  @Test func whenTheWindowLeavesTheDesktopIsNoLongerATile() throws {
    let (h, notes, safari) = makeHarness()
    h.run("dock \(notes.rawValue) left")
    h.run("dock \(safari.rawValue) right")
    #expect(h.layout?.desktopFrame == nil)
    h.system.close(notes)
    #expect(try #require(h.layout?.desktopFrame).width >= 240, "it gave first, and gets back what Safari can spare")
    expectInView(h, safari)
  }

  @Test func aDesktopThePersonMadeNarrowStaysNarrow() throws {
    let (h, _, safari) = makeHarness()
    h.run("dock \(safari.rawValue) right")
    #expect(h.run("resize \(safari.rawValue) left 560").ok)
    #expect(h.layout?.tiles.map(\.kind) == [.desktop])
    let tree = h.workspace.tree
    h.run("zoom \(safari.rawValue)")
    h.run("back")
    h.system.setMinimized(safari, true)
    h.system.setMinimized(safari, false)
    h.scheduler.runPending()
    #expect(h.workspace.tree == tree)
  }

  // MARK: A window that comes to float on a Desktop Arbor has squeezed

  /// Notes and Safari docked, the empty Desktop a tile between them or left with nothing, and then the first ⌘N of the day.
  func squeezedThenOpened() -> (Harness, notes: WindowID, safari: WindowID, terminal: WindowID) {
    let (h, notes, safari) = makeHarness()
    h.run("dock \(notes.rawValue) left")
    h.run("dock \(safari.rawValue) right")
    h.system.clearFrameLog()
    let terminal = h.system.open(app: "Terminal", frame: CGRect(x: 500, y: 300, width: 585, height: 366))
    return (h, notes, safari, terminal)
  }

  @Test func nothingJumpsWhenAWindowOpens() {
    let (h, notes, safari, terminal) = squeezedThenOpened()
    expectInView(h, notes, safari)
    #expect(h.system.frameLog.isEmpty)
    #expect(h.system.isVisible(terminal))
  }

  @Test(arguments: ["show-all", "home", "back"])
  func itIsInShowEverythingAndNobodyPaysForIt(_ wayBack: String) throws {
    let (h, notes, safari, terminal) = squeezedThenOpened()
    let tree = h.workspace.tree
    h.run("zoom \(notes.rawValue)")
    #expect(h.run(wayBack).ok)
    #expect(h.system.isVisible(terminal), "a window that is open is in Show Everything, over the arrangement")
    expectInView(h, notes, safari)
    #expect(h.workspace.tree == tree, "no docked window becomes a tile for the Desktop's sake \(h.run("state").message)")
  }

  @Test func norAtTheNextChangeOfTheArrangement() throws {
    let (h, notes, safari, terminal) = squeezedThenOpened()
    #expect(h.run("dock \(safari.rawValue) left").ok, "one place to the left")
    #expect(h.system.isVisible(terminal))
    expectInView(h, notes, safari)
  }

  @Test func anAppThatMovesItsOwnWindowIsNoOccasion() {
    let (h, notes, safari, _) = squeezedThenOpened()
    let tree = h.workspace.tree
    h.system.userMove(safari, to: CGRect(x: 300, y: 200, width: 700, height: 500))
    h.scheduler.runPending()
    #expect(h.workspace.tree == tree)
    expectInView(h, notes, safari)
  }

  // MARK: Room goes back where it came from

  /// A window of 864 points is docked under one that has half the display, and the column grows for it.
  func columnThatGrew(
    settings: Settings = Harness.settingsWhenNoneAreGiven
  ) throws -> (Harness, first: WindowID, large: WindowID) {
    let h = Harness(settings: settings)
    let first = h.system.open(app: "Safari", frame: CGRect(x: 100, y: 100, width: 500, height: 400))
    let size = CGSize(width: 864, height: 525)
    let large = h.system.open(app: "Logic", frame: CGRect(origin: CGPoint(x: 300, y: 200), size: size), minimumSize: size)
    h.start()
    h.run("dock \(first.rawValue) left")
    #expect(try #require(h.frame(first)).width == 702)
    h.run("dock \(large.rawValue) beside \(first.rawValue) bottom")
    expectInView(h, first, large)
    #expect(try #require(h.frame(first)).width == 864)
    return (h, first, large)
  }

  @Test(arguments: ["close", "float", "dock elsewhere"]) func whenTheWindowHasGoneTheGapIsWhereItWas(_ how: String) throws {
    // Elsewhere is a place between the first window and the Desktop, which takes a column for the Desktop.
    let settings = how == "dock elsewhere" ? .withDesktopColumn : Harness.settingsWhenNoneAreGiven
    let (h, first, large) = try columnThatGrew(settings: settings)
    switch how {
    case "close": h.system.close(large)
    case "float": h.run("float \(large.rawValue)")
    default: h.run("dock \(large.rawValue) right")
    }
    if how == "dock elsewhere" {
      // One place to the right, [first | large | Desktop]: room is made for it there, and that goes back in its turn.
      expectInView(h, first, large)
      h.system.close(large)
    }
    #expect(try #require(h.frame(first)).width == 702, "half the display, as before the visit")
    #expect(h.layout?.desktopFrame?.width == 702)
  }

  @Test func whoeverOfTwoLeavesTheOtherKeepsNoMoreThanItsShare() throws {
    for leaver in 0...1 {
      let (h, notes, safari) = makeHarness(settings: .withDesktopColumn)
      h.run("dock \(notes.rawValue) left")
      h.run("dock \(safari.rawValue) right")
      h.system.close([notes, safari][leaver])
      let stays = [safari, notes][leaver]
      #expect(try #require(h.frame(stays)).width == (stays == notes ? 709 : 702), "half the display, or what it needs")
      #expect(try #require(h.layout?.desktopFrame).width == (stays == notes ? 695 : 702))
    }
  }

  @Test func aGapSetByHandSinceStaysWhereTheHandLeftIt() throws {
    let (h, first, large) = try columnThatGrew()
    #expect(h.run("resize \(first.rawValue) right 40").ok)
    #expect(try #require(h.frame(first)).width == 904)
    h.system.close(large)
    #expect(try #require(h.frame(first)).width == 904)
  }

  @Test func whatWasLentIsSaved() throws {
    let (old, notes, safari) = makeHarness()
    old.run("dock \(notes.rawValue) left")
    old.run("dock \(safari.rawValue) right")
    old.controller.shutdown()

    let h = Harness(saved: old.store.saved)
    for window in old.system.allWindows() {
      h.system.open(
        app: window.appName, bundleID: window.bundleID, title: window.title, pid: window.pid, frame: window.frame,
        minimumSize: window.id == notes ? notesMinimum : safariMinimum)
    }
    h.start()
    h.system.close(notes)
    // What Notes had goes back at once. What Safari has stays until Arbor knows again what Safari can spare.
    #expect(try #require(h.layout?.desktopFrame).width > 500)
    expectInView(h, safari)
  }

  @Test func aDesktopThePersonMadeNarrowStaysNarrowUnderAFloatingWindowToo() throws {
    let (h, notes, safari) = makeHarness()
    h.run("dock \(safari.rawValue) right")
    #expect(h.run("resize \(safari.rawValue) left 560").ok)
    #expect(h.layout?.tiles.map(\.kind) == [.desktop])
    #expect(h.workspace.isFloating(notes))
    let tree = h.workspace.tree
    h.run("zoom \(safari.rawValue)")
    h.run("show-all")
    #expect(h.workspace.tree == tree, "as on the trunk")
  }

  /// Tiles give down to 80 points only if it takes that. A column of tiles too narrow for any window would swallow what is docked
  /// into it later.
  @Test func aWindowDockedBesideATileIsInView() {
    let (h, notes, safari) = makeHarness(settings: .withDesktopColumn)
    let maps = h.system.open(
      app: "Maps", frame: CGRect(x: 100, y: 60, width: 1024, height: 768), minimumSize: CGSize(width: 660, height: 360))
    let terminal = h.system.open(app: "Terminal", frame: CGRect(x: 40, y: 51, width: 877, height: 499))
    h.run("dock \(notes.rawValue) left")
    h.run("dock \(safari.rawValue) right")
    h.system.userFocus(maps)
    h.run("dock \(maps.rawValue) right")
    expectInView(h, maps)
    for tile in h.layout?.tiles ?? [] where tile.kind == .window { #expect(tile.frame.width >= 240) }
    h.run("dock \(terminal.rawValue) beside \(notes.rawValue) bottom")
    expectInView(h, terminal, maps)
  }

  // MARK: The window with the keyboard

  /// Three that cannot all fit. Whoever types into a window that nobody can see has lost it, so that one is the last to be a tile.
  @Test func theWindowWithTheKeyboardIsTheLastToBecomeATile() {
    for typingIn in 0...2 {
      let (h, notes, safari) = makeHarness()
      let activity = h.system.open(
        app: "Activity Monitor", frame: CGRect(x: 300, y: 100, width: 960, height: 640), minimumSize: CGSize(width: 740, height: 384))
      let all = [notes, safari, activity]
      h.run("dock \(notes.rawValue) left")
      h.run("dock \(safari.rawValue) right")
      h.system.userFocus(all[typingIn])
      h.run("dock \(activity.rawValue) right")
      h.system.userFocus(all[typingIn])
      h.run("show-all")
      expectInView(h, all[typingIn])
    }
  }

  /// A reviewer's: a fixed window and one of 538 points fill the display, a small panel opens, and the view goes away and comes back.
  @Test func aPanelThatOpenedAWhileAgoCostsNobodyTheirPlace() {
    let h = Harness()
    let size = CGSize(width: 697, height: 640)
    let a = h.system.open(app: "A", frame: CGRect(origin: CGPoint(x: 100, y: 100), size: size), minimumSize: size)
    h.system.setMaximumSize(a, size)
    let c = h.system.open(
      app: "C", frame: CGRect(x: 300, y: 100, width: 812, height: 584), minimumSize: CGSize(width: 538, height: 504))
    h.start()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(c.rawValue) right")
    let d = h.system.open(app: "D", frame: CGRect(x: 500, y: 300, width: 300, height: 200))
    h.run("zoom \(c.rawValue)")
    h.run("show-all")
    #expect(!isTile(h, a) && !isTile(h, c))
    #expect(h.system.isVisible(a) && h.system.isVisible(c) && h.system.isVisible(d))
  }

  // MARK: Who is on the Desktop

  /// A pinned or summoned window is in view wherever the view goes, and a guest comes and goes with its space. None of them
  /// is on the Desktop, so none of them is a reason for the Desktop to take a docked window's place.
  @Test(arguments: ["pin", "summon", "guest"]) func aFloatingWindowThatIsNotOnTheDesktopCostsNobodyTheirPlace(_ how: String) {
    let (h, notes, safari) = makeHarness(settings: .withDesktopColumn)
    h.run("dock \(notes.rawValue) left")
    h.run("dock \(safari.rawValue) right")
    if how == "guest" { h.run("zoom \(notes.rawValue)") }
    let calculator = h.system.open(app: "Calculator", frame: CGRect(x: 600, y: 300, width: 230, height: 408))
    switch how {
    case "pin": #expect(h.run("pin \(calculator.rawValue)").ok)
    case "summon": #expect(h.run("summon Calculator").ok)
    default: #expect(h.workspace.guests?[calculator] != nil)
    }
    h.run("zoom \(safari.rawValue)")
    h.run("show-all")
    expectInView(h, notes, safari)
    #expect(h.layout?.tiles.map(\.kind) == [.desktop])
  }

  // MARK: How much a Desktop in use gets back

  /// Notes, which room was made for, floats: it has its own 1000 points back and lives on the Desktop now.
  @Test func theDesktopThatAWideWindowComesToFloatOnGetsAnEvenShare() throws {
    let (h, notes, safari) = makeHarness(settings: .withDesktopColumn)
    h.run("dock \(notes.rawValue) left")
    h.run("dock \(safari.rawValue) right")
    h.run("float \(notes.rawValue)")
    #expect(try #require(h.layout?.desktopFrame).width == 702, "not the 240 it is owed at the least, beside a Safari of 1164")
    #expect(try #require(h.frame(safari)).width == 702)
  }

  // MARK: A larger display

  /// Plugged into a monitor, both windows have room to spare. The Desktop is not left a sliver between them.
  @Test func onALargerDisplayTheEmptyDesktopGetsBackWhatTheOthersCanSpare() throws {
    let (h, notes, safari) = makeHarness(settings: .withDesktopColumn)
    h.run("dock \(notes.rawValue) left")
    h.run("dock \(safari.rawValue) right")
    #expect(h.layout?.desktopFrame == nil)
    h.system.setDisplays([
      DisplaySnapshot(
        id: h.display, frame: CGRect(x: 0, y: 0, width: 1920, height: 1080),
        visibleFrame: CGRect(x: 0, y: 25, width: 1920, height: 1055), isMain: true)
    ])
    h.scheduler.runPending()
    #expect(try #require(h.layout?.desktopFrame).width >= 240)
    expectInView(h, notes, safari)
  }

  /// Notes 709, Safari 574, Mail 500: 1783 of the 1380 there are. Two fit beside two narrow tiles.
  @Test func ofThreeWideWindowsTheTwoDockedLastAreInView() throws {
    let (h, notes, safari) = makeHarness()
    let mail = h.system.open(
      app: "Mail", frame: CGRect(x: 100, y: 100, width: 900, height: 600), minimumSize: CGSize(width: 500, height: 300))
    h.run("dock \(notes.rawValue) left")
    h.run("dock \(safari.rawValue) right")
    h.run("dock \(mail.rawValue) right")
    expectInView(h, safari, mail)
    #expect(isTile(h, notes))
  }

  /// F45 asks a tile again, out of view, after ten minutes. What it then learns is what room is made for.
  @Test func aTileThatWillGoSmallerWhenAskedAgainGetsRoom() {
    let h = Harness()
    let safari = h.system.open(app: "Safari", minimumSize: safariMinimum)
    let mail = h.system.open(app: "Mail")
    let slack = h.system.open(
      app: "Slack", frame: CGRect(x: 400, y: 100, width: 900, height: 700), minimumSize: CGSize(width: 900, height: 700))
    h.start()
    h.run("dock \(safari.rawValue) left")
    h.run("dock \(mail.rawValue) right")
    h.run("dock \(slack.rawValue) beside \(mail.rawValue) bottom")
    #expect(isTile(h, slack), "700 and the 160 Mail needs are more than the column has")
    // Its sidebar closes, say.
    h.system.setMinimumSize(slack, CGSize(width: 700, height: 500))
    h.scheduler.advance(by: 600)
    h.run("show-all")
    expectInView(h, slack, mail, safari)
  }

  @Test func aSmallerDisplayMakesRoomAgain() {
    let large = DisplaySnapshot(
      id: FakeWindowSystem.standardDisplay.id, frame: CGRect(x: 0, y: 0, width: 2560, height: 1440),
      visibleFrame: CGRect(x: 0, y: 25, width: 2560, height: 1415), isMain: true)
    let h = Harness(displays: [large], settings: Settings())
    let notes = h.system.open(app: "Notes", minimumSize: notesMinimum)
    let safari = h.system.open(app: "Safari", minimumSize: safariMinimum)
    h.start()
    h.run("dock \(notes.rawValue) left")
    h.run("dock \(safari.rawValue) right")
    // Halves, with nothing left for the Desktop between them. On the smaller display a half is seven points short for Notes.
    #expect(h.workspace.tree.children(of: h.workspace.tree.root).map { h.workspace.tree[$0]!.weight } == [1, 0, 1])
    h.system.setDisplays([FakeWindowSystem.standardDisplay])
    h.scheduler.runPending()
    expectInView(h, notes, safari)
  }

  @Test func arrangeMakesRoomToo() {
    let (h, notes, safari) = makeHarness()
    // Met before, so that their minimums are known.
    h.run("dock \(notes.rawValue) left")
    h.run("dock \(safari.rawValue) right")
    h.run("float-all")
    h.run("arrange")
    expectInView(h, notes, safari)
  }

  @Test func arrangeStartsAfreshForASlotThatWasSqueezed() {
    let (h, notes, safari) = makeHarness()
    h.run("dock \(notes.rawValue) left")
    h.run("dock \(safari.rawValue) right")
    h.run("arrange")
    expectInView(h, notes, safari)
    #expect(h.run("resize \(notes.rawValue) right -100").ok)
    #expect(isTile(h, notes))
    // The new tree numbers its slots from the start again: the old squeeze must not be taken for one of them.
    h.run("arrange")
    expectInView(h, notes, safari)
  }

  @Test func noGapMovesWhileAWindowIsBeingDragged() throws {
    let (h, notes, safari) = makeHarness()
    let mail = h.system.open(app: "Mail")
    let activity = h.system.open(
      app: "Activity Monitor", frame: CGRect(x: 300, y: 100, width: 960, height: 640), minimumSize: CGSize(width: 740, height: 384))
    h.run("dock \(notes.rawValue) left")
    h.run("dock \(safari.rawValue) right")
    h.system.userFocus(activity)
    h.run("dock \(activity.rawValue) right")
    h.run("dock \(mail.rawValue) beside \(activity.rawValue) bottom")
    #expect(isTile(h, notes) && isTile(h, safari), "740 and 574 are more than there is")
    let start = try #require(h.frame(mail))
    h.controller.dragBegan(mail, at: CGPoint(x: start.midX, y: start.minY + 10))
    let tree = h.workspace.tree
    // Activity Monitor goes into the Dock: there would be room for Safari now.
    h.system.setMinimized(activity, true)
    h.scheduler.runPending()
    #expect(h.workspace.tree == tree)
    h.controller.dragEnded(mail, at: CGPoint(x: start.midX, y: start.minY + 10))
    expectInView(h, safari, mail)
  }

  /// A slot is made as large as the window insisted on, not a point larger, so that where a window is does not depend
  /// on how it got there.
  @Test func aWindowRoomWasMadeForFillsItsSlotToThePoint() {
    let (h, notes, safari) = makeHarness()
    h.run("dock \(notes.rawValue) left")
    h.run("dock \(safari.rawValue) right")
    for window in [notes, safari] { #expect(h.frame(window) == h.layout?.windowFrames[window]) }
  }

  @Test func zoomingNeverRearrangesWhatIsOutOfView() throws {
    let (h, notes, safari) = makeHarness()
    let mail = h.system.open(app: "Mail")
    h.run("dock \(notes.rawValue) left")
    h.run("dock \(safari.rawValue) right")
    h.run("dock \(mail.rawValue) beside \(safari.rawValue) bottom")
    let tree = h.workspace.tree
    for command in ["zoom \(mail.rawValue)", "out", "back", "show-all", "desktop", "back"] {
      h.run(command)
      #expect(h.workspace.tree == tree, "\(command)")
    }
  }

  @Test func aTerminalsCellsAreNoReasonToMoveGaps() {
    let h = Harness(settings: Settings())
    let terminal = h.system.open(app: "Terminal", frame: CGRect(x: 300, y: 200, width: 560, height: 340))
    let mail = h.system.open(app: "Mail")
    h.system.setSizeStep(terminal, CGSize(width: 7, height: 17))
    h.start()
    h.run("dock \(terminal.rawValue) left")
    h.run("dock \(mail.rawValue) right")
    // Still halves, around a Desktop that nothing is left for.
    #expect(h.workspace.tree.children(of: h.workspace.tree.root).map { h.workspace.tree[$0]!.weight } == [1, 0, 1])
  }

  /// Whatever people do with windows that resist: the tree stays sound, what is in view fits its slot, nothing lies over
  /// anything else, and a layout asked for again changes nothing.
  @Test func anythingGoes() {
    var seed: UInt64 = 0xF061_0001
    func random(_ bound: Int) -> Int {
      seed = seed &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
      return Int((seed >> 33) % UInt64(bound))
    }
    let edges = ["left", "right", "top", "bottom"]
    for round in 0..<120 {
      let h = Harness()
      var windows: [WindowID] = []
      func open() {
        let minimum = random(3) == 0 ? CGSize.zero : CGSize(width: 100 + random(800), height: 46 + random(500))
        windows.append(h.system.open(app: "App\(windows.count)", pid: Int32(100 + windows.count), minimumSize: minimum))
      }
      for _ in 0..<(2 + random(4)) { open() }
      h.start()
      var story: [String] = []
      for _ in 0..<30 {
        let window = windows[random(windows.count)].rawValue
        let other = windows[random(windows.count)].rawValue
        let step: String
        switch random(14) {
        case 0, 1, 2: step = "dock \(window) \(edges[random(4)])"
        case 3, 4: step = "dock \(window) beside \(other) \(edges[random(4)])"
        case 5: step = "float \(window)"
        case 6: step = "zoom \(window)"
        case 7: step = ["back", "show-all", "out", "desktop", "arrange", "relayout"][random(6)]
        case 8, 9: step = "resize \(window) \(edges[random(4)]) \(random(600) - 300)"
        case 10:
          step = "minimize \(window)"
          h.system.setMinimized(WindowID(window), true)
        case 11:
          step = "restore \(window)"
          h.system.setMinimized(WindowID(window), false)
        case 12:
          step = "seam"
          if let seams = h.overlays.seams[h.display], !seams.isEmpty {
            h.overlays.dragSeam(seams[random(seams.count)], by: CGFloat(random(500) - 250))
          }
        default:
          step = "open"
          if windows.count < 8 { open() }
        }
        story.append(step)
        if step.first?.isLowercase == true, !["minimize", "restore", "seam", "open"].contains(where: step.hasPrefix) {
          h.run(step)
        }
        // With the clock: a window that has just come back is judged only when it has had time to land (K963).
        h.scheduler.advance(by: 1)

        let tree = h.workspace.tree
        let told = "round \(round): \(story.joined(separator: "; "))"
        guard tree.invariantViolations().isEmpty, let layout = h.layout else {
          Issue.record("\(tree.invariantViolations()) after \(told)")
          return
        }
        // Without a column of its own the Desktop may be left with nothing. Nobody else ever is.
        let mayHaveNothing = h.controller.settings.desktopColumn ? nil : tree.desktop
        #expect(
          tree.preorder().allSatisfy { id in
            let weight = tree[id]!.weight
            return weight.isFinite && (weight > 0 || id == mayHaveNothing && weight == 0)
          }, "\(told)")
        let shown = layout.windowFrames.keys.sorted()
        for id in shown {
          let slot = layout.windowFrames[id]!.insetBy(dx: -2, dy: -2)
          #expect(h.frame(id).map(slot.contains) == true, "\(id) \(String(describing: h.frame(id))) in \(slot) after \(told)")
        }
        for (index, first) in shown.enumerated() {
          for second in shown[(index + 1)...] {
            #expect(h.frame(first)?.overlaps(h.frame(second) ?? .zero) == false, "\(first) over \(second) after \(told)")
          }
        }
      }
      // A window that has just opened on a Desktop Arbor had squeezed is owed room at the next layout. This one.
      h.system.setDisplays(h.system.displayList)
      h.scheduler.runPending()
      // At rest: another layout moves no gap and no docked window.
      let tree = h.workspace.tree
      h.system.clearFrameLog()
      h.system.setDisplays(h.system.displayList)
      h.scheduler.runPending()
      #expect(h.workspace.tree == tree, "round \(round): \(story.joined(separator: "; "))")
      // (Floating windows and windows out of view are seen to again after a change of displays; that is not this.)
      let moved = h.system.frameLog.filter { h.layout?.windowFrames[$0.window] != nil }
      #expect(moved.isEmpty, "round \(round): \(moved) after \(story.joined(separator: "; "))")
    }
  }

  @Test func whatWasChangedIsSaved() {
    let (h, notes, safari) = makeHarness()
    h.run("dock \(notes.rawValue) left")
    h.run("dock \(safari.rawValue) right")
    h.scheduler.runPending()
    #expect(h.store.saved?.workspaces[h.display]?.tree == h.workspace.tree)
  }
}
