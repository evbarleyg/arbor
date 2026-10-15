import ArborCore
import ArborKit
import ArborTesting
import CoreGraphics
import Testing

/// No empty column for the Desktop (QUESTIONS Q28 and Q29, point 5; `desktopColumn` ships false). The Desktop is what is left over,
/// not a place with a share of its own: two docks are two halves, and Arrange Windows leaves nothing over.
@MainActor
@Suite struct NoDesktopColumnTests {
  /// A harness as Arbor ships, with `count` windows open and floating.
  private func harness(_ count: Int, settings: Settings = Settings()) -> (Harness, [WindowID]) {
    let h = Harness(settings: settings)
    let apps = ["Safari", "Mail", "Notes", "Terminal", "Music", "Maps", "Preview"]
    let windows = (0..<count).map { h.system.open(app: apps[$0 % apps.count]) }
    h.start()
    return (h, windows)
  }

  /// What a layout fills: the display without the gap round the arrangement.
  private func content(_ h: Harness) -> CGRect {
    LayoutEngine.content(of: h.visibleFrame, options: h.controller.settings.layoutOptions)
  }

  /// The Desktop takes nothing: no rectangle, no tile, no gap on either side of it.
  private func expectNoRoomForTheDesktop(_ h: Harness, sourceLocation: SourceLocation = #_sourceLocation) {
    guard let layout = h.layout else {
      Issue.record("not laid out", sourceLocation: sourceLocation)
      return
    }
    let tree = h.workspace.tree
    #expect(layout.desktopFrame == nil, sourceLocation: sourceLocation)
    #expect(layout.nodeFrames[tree.desktop] == nil, sourceLocation: sourceLocation)
    #expect(!layout.tiles.contains { $0.kind == .desktop }, sourceLocation: sourceLocation)
    #expect(
      !layout.seams.contains { $0.leading == tree.desktop || $0.trailing == tree.desktop }, sourceLocation: sourceLocation)
  }

  // MARK: Two docks

  @Test func theFirstDockTakesAHalfAtOnce() {
    let (h, w) = harness(2)
    h.run("dock \(w[0].rawValue) left")
    let all = content(h)
    let gap = h.controller.settings.layoutOptions.gap
    #expect(h.frame(w[0]) == CGRect(x: all.minX, y: all.minY, width: (all.width - gap) / 2, height: all.height))
    #expect(h.layout?.desktopFrame != nil, "what is left over is the Desktop")
    expectWindowsMatchLayout(h)
  }

  @Test func twoDocksAreTwoHalvesAndTheFirstDoesNotMoveAtTheSecond() {
    let (h, w) = harness(2)
    h.run("dock \(w[0].rawValue) left")
    let first = h.frame(w[0])
    let mark = h.system.moveLog.count
    h.run("dock \(w[1].rawValue) right")
    let all = content(h)
    let gap = h.controller.settings.layoutOptions.gap
    #expect(h.frame(w[0]) == first)
    #expect(!h.system.moveLog[mark...].contains { $0.window == w[0] }, "no frame is set for the first")
    #expect(h.frame(w[1])?.width == first?.width)
    #expect(h.frame(w[1])?.minX == (first?.maxX ?? 0) + gap, "one gap between the two")
    #expect(h.frame(w[1])?.maxX == all.maxX)
    expectNoRoomForTheDesktop(h)
    expectWindowsMatchLayout(h)
  }

  @Test(arguments: [("left", "left"), ("right", "right"), ("right", "left")])
  func whicheverSidesTheyAreDockedAt(_ sides: (String, String)) {
    let (h, w) = harness(2)
    h.run("dock \(w[0].rawValue) \(sides.0)")
    let size = h.frame(w[0])?.size
    h.run("dock \(w[1].rawValue) \(sides.1)")
    #expect(h.frame(w[0])?.size == size, "the first keeps its size")
    #expect(h.frame(w[1])?.size == size)
    expectNoRoomForTheDesktop(h)
    expectWindowsMatchLayout(h)
  }

  @Test func theSecondTakesAllThatIsLeftHoweverMuchThatIs() {
    let (h, w) = harness(2)
    h.run("dock \(w[0].rawValue) left")
    h.run("resize \(w[0].rawValue) right -300")
    let first = h.frame(w[0])
    h.run("dock \(w[1].rawValue) right")
    #expect(h.frame(w[0]) == first)
    #expect(h.frame(w[1])?.maxX == content(h).maxX)
    #expect(h.frame(w[1])?.minX == (first?.maxX ?? 0) + h.controller.settings.layoutOptions.gap)
    expectNoRoomForTheDesktop(h)
  }

  @Test func besideADockedWindowWhatIsLeftGoesFirstToo() {
    let (h, w) = harness(2)
    h.run("dock \(w[0].rawValue) left")
    let first = h.frame(w[0])
    h.run("dock \(w[1].rawValue) beside \(w[0].rawValue) right")
    #expect(h.frame(w[0]) == first)
    #expect(h.frame(w[1])?.width == first?.width)
    expectNoRoomForTheDesktop(h)
  }

  @Test func withNothingLeftTheDockedWindowsGive() {
    let (h, w) = harness(3)
    h.run("dock \(w[0].rawValue) left")
    h.run("dock \(w[1].rawValue) right")
    h.run("dock \(w[2].rawValue) right")
    let widths = w.compactMap { h.frame($0)?.width }
    #expect(widths.count == 3)
    #expect((widths.max() ?? 0) - (widths.min() ?? 0) <= 1, "thirds, to the point: \(widths)")
    #expect(h.frame(w[2])?.maxX == content(h).maxX)
    expectNoRoomForTheDesktop(h)
    expectWindowsMatchLayout(h)
  }

  // MARK: Room comes back

  @Test(arguments: ["close", "float"], [0, 1])
  func whoeverIsLeftAloneStaysAsItIs(_ way: String, _ leaver: Int) {
    let (h, w) = harness(2)
    h.run("dock \(w[0].rawValue) left")
    h.run("dock \(w[1].rawValue) right")
    let stays = w[1 - leaver]
    let (before, freed) = (h.frame(stays), h.frame(w[leaver]))
    let mark = h.system.moveLog.count
    if way == "close" { h.system.close(w[leaver]) } else { h.run("float \(w[leaver].rawValue)") }
    #expect(h.frame(stays) == before)
    #expect(!h.system.moveLog[mark...].contains { $0.window == stays }, "no frame is set for it")
    #expect(h.layout?.desktopFrame == freed, "the room is left over, where it was freed")
    expectWindowsMatchLayout(h)
    // And the next dock takes it, again without moving anybody.
    let third = h.system.open(app: "Maps")
    h.run("dock \(third.rawValue) \(leaver == 0 ? "left" : "right")")
    #expect(h.frame(stays) == before)
    #expect(h.frame(third) == freed)
    expectNoRoomForTheDesktop(h)
  }

  @Test func alsoAfterArrange() {
    let (h, w) = harness(2)
    h.run("arrange")
    let before = h.frame(w[1])
    h.system.close(w[0])
    #expect(h.frame(w[1]) == before)
    #expect(h.layout?.desktopFrame != nil)
    expectWindowsMatchLayout(h)
  }

  @Test func fromThreeDownTheOthersShareAndNoColumnOpens() {
    let (h, w) = harness(3)
    for window in w { h.run("dock \(window.rawValue) right") }
    h.system.close(w[1])
    expectNoRoomForTheDesktop(h)
    #expect(h.frame(w[0])?.width == h.frame(w[2])?.width)
    #expect(h.frame(w[2])?.maxX == content(h).maxX)
    expectWindowsMatchLayout(h)
  }

  @Test func minimizedAndBackIsNothing() {
    let (h, w) = harness(2)
    h.run("dock \(w[0].rawValue) left")
    h.run("dock \(w[1].rawValue) right")
    let frames = w.map { h.frame($0) }
    h.system.setMinimized(w[0], true)
    expectNoRoomForTheDesktop(h)
    h.system.setMinimized(w[0], false)
    #expect(w.map { h.frame($0) } == frames)
    expectWindowsMatchLayout(h)
  }

  @Test func withEveryDockedWindowAwayTheDesktopHasEverything() {
    let (h, w) = harness(2)
    h.run("arrange")
    expectNoRoomForTheDesktop(h)
    for window in w { h.system.setMinimized(window, true) }
    #expect(h.layout?.desktopFrame == content(h))
    for window in w { h.system.setMinimized(window, false) }
    expectNoRoomForTheDesktop(h)
    expectWindowsMatchLayout(h)
  }

  @Test func theLastDockedWindowLeavesAPlainMac() {
    let (h, w) = harness(2)
    h.run("arrange")
    h.run("float \(w[0].rawValue)")
    h.run("float \(w[1].rawValue)")
    #expect(h.workspace.tree.root == h.workspace.tree.desktop)
    #expect(h.workspace.tree.invariantViolations() == [])
    h.run("dock \(w[0].rawValue) left")
    #expect(h.layout?.desktopFrame != nil, "and the next first dock takes a half again")
  }

  // MARK: Arrange

  @Test(arguments: 1...6)
  func arrangeLeavesNothingOver(_ count: Int) {
    let (h, w) = harness(count)
    h.run("arrange")
    let all = content(h)
    let frames = w.compactMap { h.frame($0) }
    #expect(h.layout?.windowFrames.count == count, "every window shows")
    #expect(frames.map(\.minX).min() == all.minX)
    #expect(frames.map(\.maxX).max() == all.maxX, "no column, and no gap for one")
    #expect(frames.map(\.minY).min() == all.minY)
    #expect(frames.map(\.maxY).max() == all.maxY)
    expectNoRoomForTheDesktop(h)
    expectWindowsMatchLayout(h)
  }

  @Test func arrangeTwiceMovesNothing() {
    let (h, _) = harness(4)
    h.run("arrange")
    let mark = h.system.moveLog.count
    h.run("arrange")
    #expect(h.system.moveLog.count == mark)
  }

  @Test func eveningOutLeavesTheDesktopWithoutRoom() {
    let (h, w) = harness(3)
    h.run("arrange")
    h.run("resize \(w[0].rawValue) right 120")
    h.run("balance")
    expectNoRoomForTheDesktop(h)
    #expect(w.compactMap { h.frame($0)?.maxX }.max() == content(h).maxX)
  }

  @Test func atTheEdgeADockSaysSoAtOnce() {
    // [a | b | Desktop]: beyond the last window there is nothing to trade places with.
    let (h, w) = harness(2)
    h.run("arrange")
    let tree = h.workspace.tree
    let reply = h.run("dock \(w[1].rawValue) right")
    #expect(!reply.ok, "\(reply.message)")
    #expect(h.workspace.tree == tree)
    h.system.userFocus(w[1])
    let row = h.controller.menuModel().allItems.first { $0.command == .dock(nil, .right) }
    #expect(row?.isEnabled == false, "and the menu's row looks the way it acts")
  }

  @Test func aloneWithEverythingItCanStillBeDockedAtEitherSide() {
    for side in ["left", "right"] {
      let (h, w) = harness(1)
      h.run("arrange")
      #expect(h.frame(w[0]) == content(h))
      #expect(h.run("dock \(w[0].rawValue) \(side)").ok)
      #expect(h.frame(w[0])?.width == (content(h).width - h.controller.settings.layoutOptions.gap) / 2, "\(side)")
      #expect(side == "left" ? h.frame(w[0])?.minX == content(h).minX : h.frame(w[0])?.maxX == content(h).maxX)
      #expect(h.layout?.desktopFrame != nil)
      expectWindowsMatchLayout(h)
    }
  }

  @Test func closedWhileItWasInTheDockItTakesNothingFromWhoeverIsThere() {
    for leaver in [0, 1] {
      let (h, w) = harness(2)
      h.run("dock \(w[0].rawValue) left")
      h.run("dock \(w[1].rawValue) right")
      h.system.setMinimized(w[leaver], true)
      let before = h.frame(w[1 - leaver])
      #expect(before == content(h), "the premise: who is away lends its room")
      h.system.close(w[leaver])
      #expect(h.frame(w[1 - leaver]) == before)
      expectWindowsMatchLayout(h)
    }
  }

  // MARK: The Desktop is still a place to go

  @Test func theDesktopIsStillReachedByItsCommand() {
    let (h, w) = harness(3)
    let floating = h.frame(w[2])
    h.run("dock \(w[0].rawValue) left")
    h.run("dock \(w[1].rawValue) right")
    #expect(h.run("desktop").ok)
    #expect(h.workspace.camera == h.workspace.tree.desktop)
    #expect(h.layout?.camera == h.workspace.tree.desktop, "the view is on it, not on what is around it")
    #expect(h.layout?.desktopFrame == content(h))
    #expect(h.layout?.windowFrames.isEmpty == true)
    #expect(h.frame(w[2]) == floating)
    #expect(h.run("back").ok)
    expectNoRoomForTheDesktop(h)
    #expect(h.layout?.windowFrames.count == 2)
    expectWindowsMatchLayout(h)
  }

  @Test func andFromTheMenuAndGoTo() {
    let (h, _) = harness(2)
    h.run("arrange")
    let item = h.controller.menuModel().allItems.first { $0.command == .desktop }
    #expect(item?.isEnabled == true, "Show Desktop is in the menu, and can be chosen")
    // Go to… finds windows, saved views and names. A view saved on the Desktop and a name given to it still mean it.
    h.run("desktop")
    h.run("save-view 3")
    h.run("name Loose")
    let desktop = h.workspace.tree.desktop
    for destination in [FinderDestination.view(h.display, slot: 3), .space(h.display, desktop)] {
      h.run("home")
      expectNoRoomForTheDesktop(h)
      h.run("find")
      h.controller.finderChose(destination)
      #expect(h.layout?.camera == desktop, "\(destination)")
      #expect(h.layout?.desktopFrame == content(h), "\(destination)")
    }
  }

  @Test func goToAFloatingWindowNeedsNoMoveOfTheView() {
    let (h, w) = harness(3)
    h.run("dock \(w[0].rawValue) left")
    h.run("dock \(w[1].rawValue) right")
    let camera = h.workspace.camera
    h.run("find")
    h.controller.finderChose(.window(w[2]))
    #expect(h.workspace.camera == camera, "it is in view already, over the docked ones")
    #expect(h.system.focusedWindow() == w[2])
  }

  @Test func aFloatingWindowStaysInViewOverTheDockedOnes() {
    let (h, w) = harness(3)
    h.system.userMove(w[2], to: CGRect(x: 300, y: 200, width: 500, height: 400))
    h.run("dock \(w[0].rawValue) left")
    h.run("dock \(w[1].rawValue) right")
    #expect(h.visibleFrame.contains(h.frame(w[2]) ?? .zero), "it has nowhere else to be, and it is not taken out of view")
    #expect(!h.controller.parked.contains(w[2]))
  }

  // MARK: Room before tiles

  enum End: String, CaseIterable, CustomTestStringConvertible {
    case shrinksAgain, closes
    var testDescription: String { rawValue }
  }

  /// Two halves are each window's own, so for the window with the keyboard the other lends of its own, which costs it its place. It is lent, not
  /// given: a person has dragged the gap, the app being typed in grows beyond what is there, and shrinks again or closes. The gap
  /// is where the hand left it, to the point.
  @Test(.withTiles, arguments: End.allCases) func whatTheOtherLentForTheKeyboardsSakeGoesBackToTheGapTheHandLeft(_ end: End) throws {
    let h = Harness(settings: Settings())
    let mail = h.system.open(
      app: "Mail", pid: 1001, frame: CGRect(x: 100, y: 100, width: 700, height: 600), minimumSize: CGSize(width: 560, height: 400))
    let chat = h.system.open(
      app: "Chat", pid: 1002, frame: CGRect(x: 300, y: 100, width: 700, height: 600), minimumSize: CGSize(width: 500, height: 400))
    h.start()
    h.run("dock \(mail.rawValue) left")
    h.system.userFocus(chat)
    h.run("dock \(chat.rawValue) right")
    h.overlays.dragSeam(try #require(h.overlays.seams[h.display]?.last), by: -90)
    h.scheduler.advance(by: 2)
    let theirs = try #require(h.frame(mail))
    let beside = try #require(h.frame(chat))
    #expect(theirs == CGRect(x: 12, y: 37, width: 612, height: 851) && beside == CGRect(x: 636, y: 37, width: 792, height: 851))

    // A side panel opens in the chat: 900 points and not one less. Mail would have to go under its 560.
    var grown = beside
    grown.origin.x -= 108
    grown.size.width += 108
    h.system.setMinimumSize(chat, CGSize(width: 900, height: 400))
    h.system.userMove(chat, to: grown)
    h.scheduler.advance(by: 2)
    #expect(h.frame(chat)?.width == 900 && h.system.isVisible(chat))
    #expect(h.layout?.tiles.contains { $0.windows.contains(mail) } == true, "the window being typed in is the last to be a tile")
    expectNoRoomForTheDesktop(h)

    h.system.clearFrameLog()
    switch end {
    case .shrinksAgain:
      h.system.setMinimumSize(chat, CGSize(width: 500, height: 400))
      h.system.userMove(chat, to: beside)
      h.scheduler.advance(by: 2)
      #expect(h.frame(chat) == beside)
      expectNoRoomForTheDesktop(h)
    case .closes:
      h.system.close(chat)
      h.scheduler.advance(by: 2)
      #expect(h.layout?.desktopFrame == beside, "what is freed is left over, where it was freed")
    }
    #expect(h.frame(mail) == theirs, "the gap is the hand's")
    #expect(h.system.isVisible(mail))
    #expect(h.system.frameLog.filter { $0.window == mail }.map(\.frame) == [theirs], "in one move")
    expectWindowsMatchLayout(h)
  }

  /// Not at a start, which takes no window out of view that is in view: the window with the keyboard is let be where it stands.
  @Test(.withTiles) func atAStartNobodyPaysWithTheirPlace() {
    let old = Harness(settings: Settings())
    old.start()
    let editor = old.system.open(app: "Xcode", pid: 11, frame: CGRect(x: 100, y: 100, width: 1200, height: 600))
    old.system.setMinimumSize(editor, CGSize(width: 1200, height: 500))
    let browser = old.system.open(app: "Safari", pid: 12, frame: CGRect(x: 700, y: 100, width: 600, height: 500))
    old.run("dock \(browser.rawValue) right")
    old.run("dock \(editor.rawValue) left")
    old.scheduler.advance(by: 5)
    old.controller.shutdown()
    old.system.userFocus(editor)
    let h = old.newProcess()
    let stood = h.frame(editor)
    h.start()
    h.scheduler.advance(by: 5)
    #expect(h.system.isVisible(browser) && h.layout?.windowFrames[browser] != nil)
    #expect(h.controller.windowLetBe == editor && h.frame(editor) == stood)
    expectWindowsMatchLayout(h)
  }

  /// On the word of a record that is too old to go by nobody pays either (F45): the window is asked first, where it is.
  @Test(.withTiles, arguments: [true, false]) func anOldRecordCostsNobodyTheirPlaceUnasked(relents: Bool) {
    let h = Harness(settings: Settings())
    let a = h.system.open(app: "Safari", frame: CGRect(x: 100, y: 100, width: 600, height: 400))
    let b = h.system.open(app: "Notes", frame: CGRect(x: 200, y: 100, width: 600, height: 400))
    let c = h.system.open(
      app: "Slack", frame: CGRect(x: 300, y: 100, width: 900, height: 700), minimumSize: CGSize(width: 900, height: 700))
    h.start()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) right")
    h.run("dock \(c.rawValue) beside \(b.rawValue) bottom")
    h.run("zoom \(c.rawValue)")
    h.scheduler.advance(by: 700)
    if relents { h.system.setMinimumSize(c, .zero) }
    h.run("show-all")
    h.scheduler.advance(by: 2)
    #expect(h.system.isVisible(c) && h.system.focusedWindow() == c)
    if relents {
      #expect(h.frame(a) == CGRect(x: 12, y: 37, width: 702, height: 851))
      #expect(h.frame(b) == CGRect(x: 726, y: 37, width: 702, height: 420))
      #expect(h.frame(c) == CGRect(x: 726, y: 469, width: 702, height: 419))
    } else {
      #expect(h.frame(c)?.size == CGSize(width: 900, height: 700), "it stands by its size, and is still the last to be a tile")
    }
    expectWindowsMatchLayout(h)
  }

  /// A place that waits for a late window with its room kept open has lent it to nobody. Given up, it is like a window that closes.
  @Test func aHoleThatIsGivenUpLeavesTheOtherAsItIs() {
    let old = Harness(settings: Settings())
    let (a, b) = (old.system.open(app: "Safari", pid: 11), old.system.open(app: "Mail", pid: 12))
    old.start()
    old.run("dock \(a.rawValue) left")
    old.run("dock \(b.rawValue) right")
    old.controller.shutdown()
    old.system.close(a)
    old.system.close(b)
    let h = old.newProcess()
    h.start()
    let safari = h.system.open(app: "Safari", pid: 11)
    h.scheduler.advance(by: 5)
    let half = CGRect(x: 12, y: 37, width: 702, height: 851)
    #expect(h.frame(safari) == half, "\(h.ascii())")
    h.scheduler.advance(by: 700)
    h.system.clearFrameLog()
    h.run("relayout")
    #expect(h.frame(safari) == half && h.system.frameLog.isEmpty)
    #expect(h.layout?.desktopFrame == CGRect(x: 726, y: 37, width: 702, height: 851))
    expectWindowsMatchLayout(h)
  }

  /// Places that wait side by side are kept open as one, and given up as one: the other stays as it is all the same. And it is Arbor that
  /// has given up its waiting, not the command whose layout it went with: there is nothing to take back.
  @Test func placesThatWaitSideBySideAndAreGivenUpLeaveTheOtherAsItIs() {
    let old = Harness(settings: Settings())
    let (a, b, c) = (old.system.open(app: "Safari", pid: 11), old.system.open(app: "Mail", pid: 12), old.system.open(app: "Notes", pid: 13))
    old.start()
    old.run("dock \(a.rawValue) left")
    old.run("dock \(b.rawValue) right")
    old.run("dock \(c.rawValue) beside \(b.rawValue) bottom")
    old.controller.shutdown()
    for window in [a, b, c] { old.system.close(window) }
    let h = old.newProcess()
    h.start()
    let safari = h.system.open(app: "Safari", pid: 11)
    h.scheduler.advance(by: 5)
    let half = CGRect(x: 12, y: 37, width: 702, height: 851)
    #expect(h.frame(safari) == half, "\(h.ascii())")
    h.scheduler.advance(by: 700)
    h.system.clearFrameLog()
    h.run("relayout")
    #expect(h.frame(safari) == half && h.system.frameLog.isEmpty, "\(h.ascii())")
    #expect(h.layout?.desktopFrame == CGRect(x: 726, y: 37, width: 702, height: 851))
    #expect(h.workspace.tree.allWindows == [safari])
    #expect(!h.run("undo").ok)
    #expect(h.frame(safari) == half)
    expectWindowsMatchLayout(h)
  }

  // MARK: The old thirds

  @Test func theSettingBringsTheColumnBack() {
    var settings = Settings()
    settings.desktopColumn = true
    let (h, w) = harness(2, settings: settings)
    h.run("dock \(w[0].rawValue) left")
    h.run("dock \(w[1].rawValue) right")
    let widths = [h.frame(w[0])?.width, h.layout?.desktopFrame?.width, h.frame(w[1])?.width].compactMap { $0 }
    #expect(widths.count == 3)
    #expect((widths.max() ?? 0) - (widths.min() ?? 0) <= 1, "window, Desktop, window: thirds")
    h.run("arrange")
    let column = h.layout?.desktopFrame
    #expect(column?.maxX == content(h).maxX)
    #expect(abs((column?.width ?? 0) * 2 - (h.frame(w[0])?.width ?? 0)) <= 2, "`arrangeDesktopWeight` of a window")
  }

  @Test func theOldWidthAtItsFloorIsNoLongerAsked() {
    // A file in which somebody set the old width as low as it goes, to be rid of the column.
    var settings = Settings()
    settings.arrangeDesktopWeight = 0.1
    let (h, _) = harness(3, settings: settings)
    h.run("arrange")
    expectNoRoomForTheDesktop(h)
  }

  // MARK: What is saved

  @Test func anArrangementWithoutAColumnComesBackAfterARestart() {
    let (h, w) = harness(2)
    h.run("dock \(w[0].rawValue) left")
    h.run("dock \(w[1].rawValue) right")
    let frames = w.map { h.frame($0) }
    h.controller.shutdown()
    let again = h.newProcess()
    again.start()
    again.run("home")
    #expect(again.workspace.tree.allWindows == w)
    #expect(w.map { again.frame($0) } == frames)
    expectNoRoomForTheDesktop(again)
  }

  @Test func undoGivesTheDesktopItsRoomBack() {
    let (h, w) = harness(2)
    h.run("dock \(w[0].rawValue) left")
    let desktop = h.layout?.desktopFrame
    h.run("dock \(w[1].rawValue) right")
    #expect(h.run("undo").ok)
    #expect(h.layout?.desktopFrame == desktop)
    #expect(h.run("redo").ok)
    expectNoRoomForTheDesktop(h)
  }
}
