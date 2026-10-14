import ArborCore
import ArborIPC
import ArborKit
import ArborTesting
import CoreGraphics
import Foundation
import Testing

/// The standard display, without the name it has had since F25: what a display without a name is called is tested here.
@MainActor private let main = DisplaySnapshot(
  id: FakeWindowSystem.standardDisplay.id, frame: FakeWindowSystem.standardDisplay.frame,
  visibleFrame: FakeWindowSystem.standardDisplay.visibleFrame, isMain: true)
private let side = DisplaySnapshot(
  id: DisplayID("side"), frame: CGRect(x: 1440, y: 0, width: 1280, height: 800),
  visibleFrame: CGRect(x: 1440, y: 25, width: 1280, height: 775), isMain: false, name: "Studio Display")

/// "Go to…", `find` and `reveal` (docs/features/F27-window-finder.md).
@Suite @MainActor struct FinderTests {
  /// Safari | Desktop | Notes over Mail, with Terminal floating on the Desktop. The arrangement comes from a saved
  /// state rather than from commands, so no window has had the keyboard yet.
  func makeHarness(displays: [DisplaySnapshot] = [main]) -> (Harness, WindowID, WindowID, WindowID, WindowID) {
    let (safari, notes, mail, terminal) = (WindowID(101), WindowID(102), WindowID(103), WindowID(104))
    var tree = LayoutTree()
    tree.dock(safari, beside: tree.root, edge: .left)
    let right = tree.dock(notes, beside: tree.root, edge: .right)
    tree.dock(mail, beside: right, edge: .bottom)
    let h = Harness(displays: displays, saved: PersistedState(workspaces: [main.id: Workspace(tree: tree)], hints: [:]))
    h.system.open(app: "Safari", title: "Arbor docs", pid: 11, frame: CGRect(x: 100, y: 100, width: 600, height: 400))
    h.system.open(app: "Notes", title: "Shopping", pid: 12, frame: CGRect(x: 300, y: 200, width: 600, height: 400))
    h.system.open(app: "Mail", title: "Inbox", pid: 13, frame: CGRect(x: 500, y: 300, width: 600, height: 400))
    h.system.open(app: "Terminal", title: "zsh", pid: 14, frame: CGRect(x: 560, y: 300, width: 300, height: 200))
    h.start()
    return (h, safari, notes, mail, terminal)
  }

  func leaf(_ h: Harness, _ window: WindowID, on display: DisplayID? = nil) -> NodeID? {
    h.controller.workspaces[display ?? h.display]?.tree.leaf(containing: window)
  }

  /// The windows the palette lists, in order, leaving out the other kinds of row.
  func listedWindows(_ h: Harness) -> [WindowID] {
    (h.overlays.finder?.model.rows ?? []).compactMap {
      if case .window(let window) = $0.destination { window } else { nil }
    }
  }

  func row(_ h: Harness, _ window: WindowID) -> FinderModel.Row? {
    h.overlays.finder?.model.rows.first { $0.destination == .window(window) }
  }

  /// Opens the palette just to read a window's note, and closes it again.
  func note(_ h: Harness, _ window: WindowID) -> String? {
    h.run("find")
    defer { h.overlays.dismissFinder() }
    return row(h, window)?.note
  }

  // MARK: The list

  @Test func theListIsMostRecentlyFocusedFirstWithTheFocusedWindowAfterTheOthers() {
    let (h, safari, notes, mail, terminal) = makeHarness()
    h.system.userFocus(mail)
    h.system.userFocus(safari)
    h.system.userFocus(notes)
    #expect(h.run("find").ok)
    // Notes has the keyboard, so Safari, where the user was before, comes first. Terminal never had it.
    #expect(listedWindows(h) == [safari, mail, notes, terminal])
    #expect(h.overlays.finder?.selected == .window(safari))
  }

  @Test func returnOnAnEmptyQueryGoesBackAndForthBetweenTwoWindows() {
    let (h, safari, notes, _, _) = makeHarness()
    h.system.userFocus(safari)
    h.system.userFocus(notes)
    for expected in [safari, notes, safari, notes] {
      h.run("find")
      h.overlays.chooseInFinder()
      #expect(h.system.focused == expected)
    }
  }

  @Test func windowsThatNeverHadTheKeyboardFollowInLayoutOrder() {
    let (h, safari, notes, mail, terminal) = makeHarness()
    h.system.focused = nil
    h.run("find")
    #expect(listedWindows(h) == [safari, notes, mail, terminal], "docked in tree order, then floating")
  }

  /// Right after launch: one window has the keyboard, and Arbor has seen no other have it.
  @Test func theFocusedWindowIsNeverFirst() {
    let (h, safari, notes, mail, terminal) = makeHarness()
    h.system.focus(safari)
    h.run("find")
    #expect(listedWindows(h) == [notes, safari, mail, terminal])
    h.overlays.chooseInFinder()
    #expect(h.system.focused == notes, "Return goes somewhere")
    h.run("find")
    #expect(listedWindows(h).first == safari, "and from now on back and forth")
    h.overlays.dismissFinder()

    let alone = Harness()
    let only = alone.system.open(app: "Safari")
    alone.start()
    alone.system.focus(only)
    alone.run("find")
    #expect(listedWindows(alone) == [only])
  }

  @Test func aFocusedWindowArborNeverSawGetFocusStillCountsAsTheCurrentOne() {
    let (h, safari, notes, mail, terminal) = makeHarness()
    h.system.userFocus(mail)
    h.system.focus(safari)  // no report, as for a window that was focused before Arbor started
    h.run("find")
    #expect(listedWindows(h) == [mail, safari, notes, terminal])
  }

  @Test func rowsCarryWhatThePaletteShows() throws {
    let (h, safari, _, _, _) = makeHarness()
    h.run("find")
    let row = try #require(self.row(h, safari))
    #expect(row.name == "Safari")
    #expect(row.detail == "Arbor docs")
    #expect(row.pid == 11)
    #expect(row.bundleID == "com.example.safari")
    #expect(row.display == h.display)
    #expect(row.displayName == nil, "one display needs no name")
    #expect(row.note == "in view")
  }

  @Test func notesSayWhereEachWindowIs() {
    let (h, safari, notes, mail, terminal) = makeHarness()
    #expect(note(h, safari) == "in view")
    #expect(note(h, terminal) == "floating")
    h.run("zoom \(safari.rawValue)")
    #expect(note(h, safari) == "in view")
    #expect(note(h, notes) == "out of view")
    #expect(note(h, terminal) == "floating, out of view")
    h.run("show-all")
    h.system.setMinimized(mail, true)
    #expect(note(h, mail) == "minimized")
    h.system.setHidden(pid: 12, true)
    #expect(note(h, notes) == "hidden")
    h.system.setOnActiveSpace(safari, false)
    h.scheduler.runPending()
    #expect(note(h, safari) == "on another macOS Space")
  }

  @Test func aWindowTooSmallToShowIsATile() {
    let (h, _, notes, _, _) = makeHarness()
    let xcode = h.system.open(app: "Xcode", frame: CGRect(x: 400, y: 200, width: 700, height: 500))
    h.system.setMinimumSize(xcode, CGSize(width: 900, height: 600))
    h.run("dock \(xcode.rawValue) beside \(notes.rawValue) bottom")
    #expect(note(h, xcode) == "tile")
  }

  /// Someone looking for Mail does not care that Arbor does not arrange it.
  @Test func windowsArborLeavesAloneAreListedAndOnlyFocused() {
    let (h, safari, notes, mail, terminal) = makeHarness()
    h.run("zoom \(safari.rawValue)")
    h.run("exclude com.example.mail")
    let frame = h.frame(mail)
    h.run("find")
    #expect(listedWindows(h).last == mail, "after the windows Arbor arranges")
    #expect(Set(listedWindows(h)) == [safari, notes, mail, terminal])
    #expect(row(h, mail)?.note == "not arranged")
    h.overlays.dismissFinder()

    let workspace = h.workspace
    h.system.clearFrameLog()
    let result = h.run("find inbox")
    #expect(result.message == "\(mail) is focused; Arbor does not arrange it")
    #expect(h.system.focused == mail)
    #expect(h.workspace == workspace, "the view stays")
    #expect(h.system.frameLog.isEmpty && h.frame(mail) == frame, "and so does the window")
    #expect(h.run("reveal \(mail.rawValue)").ok)

    h.run("find")
    h.overlays.typeInFinder("inbox")
    #expect(h.overlays.chooseInFinder())
    #expect(h.overlays.finder == nil && h.overlays.finderBeeps == 0)
  }

  @Test func aWindowLeftAloneComesBackFromTheDockAndFromHiding() {
    let (h, _, _, mail, _) = makeHarness()
    h.run("exclude com.example.mail")
    h.system.setMinimized(mail, true)
    #expect(h.run("find inbox").ok)
    #expect(h.controller.windows[mail]?.isMinimized == false)
    h.system.setHidden(pid: 13, true)
    #expect(h.run("find inbox").ok)
    #expect(h.controller.windows[mail]?.isHidden == false)
    #expect(h.system.focused == mail)
  }

  @Test func aWindowAnIgnoreRuleMatchedIsListedToo() {
    var settings = Settings()
    settings.rules = [AppRule(app: "com.example.preview", action: .ignore)]
    let h = Harness(settings: settings)
    h.system.open(app: "Safari")
    let preview = h.system.open(app: "Preview", title: "Plan.pdf")
    h.start()
    h.run("find")
    #expect(row(h, preview)?.note == "not arranged")
  }

  /// An Arbor limited to some processes (arbor-e2e) is not to know about anybody else's windows, let alone show their titles.
  @Test func windowsOfOtherProcessesStayUnknownToAnArborUnderTest() {
    let h = Harness()
    let mine = h.system.open(app: "Safari", pid: 11)
    let theirs = h.system.open(app: "Mail", title: "Private", pid: 12)
    h.controller.filter.onlyPIDs = [11]
    h.start()
    h.run("find")
    #expect(listedWindows(h) == [mine])
    #expect(!h.run("find private").ok)
    #expect(!h.run("reveal \(theirs.rawValue)").ok)
  }

  @Test func veryLongTitlesAreCut() throws {
    let h = Harness()
    let window = h.system.open(app: String(repeating: "A", count: 5000), title: String(repeating: "t", count: 100_000))
    h.start()
    h.run("find")
    let row = try #require(self.row(h, window))
    #expect(row.detail.count == 200)
    #expect(row.name.count == 80)
  }

  @Test func theListIsASnapshot() {
    let (h, safari, notes, mail, terminal) = makeHarness()
    h.system.focused = nil
    h.run("find")
    let before = h.overlays.finder
    h.system.echoes.keyboard = false  // a window that took the keyboard would close the palette
    h.system.open(app: "Preview")
    h.system.setTitle(mail, "Sent")
    h.system.setMinimized(notes, true)
    #expect(h.overlays.finder == before, "nothing moves under the user's hands")
    #expect(listedWindows(h) == [safari, notes, mail, terminal])
  }

  // MARK: Opening and closing

  @Test func thePaletteOpensOnTheDisplayUnderThePointer() {
    let (h, _, _, _, _) = makeHarness(displays: [main, side])
    h.run("find")
    #expect(h.overlays.finder?.model.display == main.id)
    #expect(h.overlays.finder?.model.screen == main.visibleFrame)
    h.overlays.dismissFinder()
    h.system.cursor = CGPoint(x: 2000, y: 400)
    h.run("find")
    #expect(h.overlays.finder?.model.display == side.id)
    #expect(h.overlays.finder?.model.screen == side.visibleFrame)
    #expect(h.overlays.finder.map { side.visibleFrame.contains($0.layout.panel) } == true)
  }

  @Test func findAgainClosesThePalette() {
    let (h, _, _, _, _) = makeHarness()
    #expect(h.run("find").message == "Go to… is open")
    #expect(h.overlays.finder != nil)
    #expect(h.run("find").message == "closed Go to…")
    #expect(h.overlays.finder == nil)
    #expect(h.run("find").ok)
    #expect(h.overlays.finder != nil)
  }

  @Test func escapeClosesItAndChangesNothing() {
    let (h, safari, _, _, _) = makeHarness()
    h.run("zoom \(safari.rawValue)")
    let workspace = h.workspace
    h.system.clearFrameLog()
    h.run("find")
    h.overlays.typeInFinder("notes")
    h.overlays.dismissFinder()
    #expect(h.overlays.finder == nil)
    #expect(h.workspace == workspace)
    #expect(h.system.focused == safari)
    #expect(h.system.frameLog.isEmpty)
    // The controller knows it is closed: the next `find` opens it rather than toggling it shut.
    #expect(h.run("find").message == "Go to… is open")
    #expect(h.overlays.finder?.query == "", "and it starts afresh")
  }

  @Test func shutdownClosesIt() {
    let (h, _, _, _, _) = makeHarness()
    h.run("find")
    h.controller.shutdown()
    #expect(h.overlays.finder == nil)
    h.controller.start()
    #expect(h.run("find").message == "Go to… is open")
  }

  @Test func pausingClosesItAndItStaysShutUntilArborResumes() {
    let (h, _, _, _, _) = makeHarness()
    h.run("find")
    #expect(h.run("pause").ok)
    #expect(h.overlays.finder == nil)
    for command in ["find", "find safari", "reveal 101"] {
      #expect(!h.run(command).ok, "\(command)")
      #expect(h.overlays.finder == nil)
    }
    #expect(h.run("resume").ok)
    #expect(h.run("find").message == "Go to… is open")
  }

  /// The real palette closes itself when it loses the keyboard. Should it ever not notice, the controller does.
  @Test func itClosesWhenAnotherWindowTakesTheKeyboard() {
    let (h, safari, notes, _, _) = makeHarness()
    h.system.userFocus(safari)
    let workspace = h.workspace
    h.run("find")
    h.system.userFocus(notes)  // a click, ⌘Tab, a window that opens
    #expect(h.overlays.finder == nil)
    #expect(h.workspace == workspace)
    #expect(h.run("find").message == "Go to… is open", "and the controller knows")
  }

  /// macOS reports the focus a command asked for a moment later: ⌃⌥→ and at once ⌃⌥G.
  @Test func aLateReportFromTheWindowItOpenedOverLeavesItOpen() {
    let (h, safari, _, _, _) = makeHarness()
    // By a command, as it says: asked of the stand-in directly, Arbor would not know that it had asked.
    h.run("focus \(safari.rawValue)")
    h.run("find")
    h.controller.windowFocused(safari)
    #expect(h.overlays.finder != nil)
  }

  /// On a Mac the answer changes together with the report, not ahead of it: when the palette opens, macOS still names the old window. The keyboard
  /// then arrives where the key before had sent it, which looked like somebody leaving: the palette flashed up and was gone.
  @Test(arguments: ["focus right", "zoom 102", "neighbor right", "reveal 103", "dock 104 right", "summon Terminal"])
  func openedStraightAfterAKeyThatMovedTheKeyboardItStaysOpen(key: String) throws {
    let (h, safari, _, _, _) = makeHarness()
    h.system.userFocus(safari)
    h.run("zoom")
    h.system.focusIsSlow = true
    #expect(h.run(key).ok)
    let asked = try #require(h.system.focusRequests.last)
    #expect(asked != safari, "the key sends the keyboard elsewhere")
    #expect(h.run("find").ok)
    // As with ⌘Tab, the first row is the window the person was in before this one: ↩ goes back.
    #expect(listedWindows(h).first == safari, "\(listedWindows(h))")
    h.system.finishSlowFocus()
    #expect(h.overlays.finder != nil, "the keyboard has only arrived at \(asked), where \(key) sent it")
    // Somebody who really goes elsewhere still closes it.
    h.system.focusIsSlow = false
    h.system.userFocus(safari)
    #expect(h.overlays.finder == nil)
  }

  /// The field for a space's name borrows the keyboard in the same way, and was left in the same way.
  @Test func theNameFieldOpenedStraightAfterSuchAKeyStaysOpenToo() {
    let (h, safari, _, _, _) = makeHarness()
    h.system.userFocus(safari)
    h.run("zoom")
    h.system.focusIsSlow = true
    #expect(h.run("neighbor right").ok)
    #expect(h.run("ask-name").ok)
    h.system.finishSlowFocus()
    #expect(h.overlays.namePrompt != nil)
    h.system.focusIsSlow = false
    h.system.userFocus(safari)
    #expect(h.overlays.namePrompt == nil, "somebody who really goes elsewhere has left it")
  }

  @Test(arguments: ["show-all", "save-view 2", "dock 104 left", "exclude com.example.mail", "reveal 102", "relayout"])
  func anyOtherCommandClosesIt(command: String) {
    let (h, _, _, _, _) = makeHarness()
    h.run("find")
    h.run(command)
    #expect(h.overlays.finder == nil)
    #expect(h.run("find").message == "Go to… is open")
  }

  /// The palette is answer enough (F43).
  @Test func noLineOnScreenSaysThatThePaletteIsOpenOrClosed() {
    let (h, _, _, _, _) = makeHarness()
    h.key("ctrl+opt+g")
    #expect(h.overlays.finder != nil && h.overlays.headsUp.isEmpty)
    h.key("ctrl+opt+g")
    #expect(h.overlays.finder == nil && h.overlays.headsUp.isEmpty)
  }

  /// Pressed as keys: a shortcut can do its work beside `perform`, as ⌃⌥Space does while it waits to see whether it is held.
  @Test func everyShortcutClosesIt() {
    for binding in KeyBindings.defaults {
      let (h, safari, _, _, _) = makeHarness()
      h.run("zoom \(safari.rawValue)")
      h.run("find")
      h.key(binding.chord.text)
      #expect(h.overlays.finder == nil, "\(binding.chord.text) (\(binding.command.text)) left it open")
    }
  }

  @Test(arguments: ["status", "state", "bindings", "help"])
  func queriesLeaveItOpen(command: String) {
    let (h, _, _, _, _) = makeHarness()
    h.run("find")
    h.overlays.typeInFinder("mail")
    #expect(h.run(command).ok)
    #expect(h.overlays.finder?.query == "mail")
  }

  @Test func itDoesNotOpenWhileAWindowIsDragged() {
    let (h, safari, _, _, _) = makeHarness()
    h.controller.dragBegan(safari, at: CGPoint(x: 200, y: 50))
    #expect(h.run("find").message.contains("dragged"))
    #expect(h.overlays.finder == nil)
    h.controller.dragEnded(safari, at: CGPoint(x: 200, y: 50))
    #expect(h.run("find").ok)
  }

  @Test func itClosesWhenAWindowIsDragged() {
    let (h, safari, _, _, _) = makeHarness()
    h.run("find")
    h.controller.dragBegan(safari, at: CGPoint(x: 200, y: 50))
    #expect(h.overlays.finder == nil)
    h.controller.dragEnded(safari, at: CGPoint(x: 200, y: 50))
  }

  @Test func withNoWindowsThereIsNothingToOpen() {
    let h = Harness()
    h.start()
    let result = h.run("find")
    #expect(!result.ok)
    #expect(result.message == "there are no windows to go to")
    #expect(h.overlays.finder == nil)
  }

  @Test func beforeStartingTheCommandsExplainThemselves() {
    let h = Harness()
    h.controller.accessibilityGranted = false
    for command in ["find", "find safari", "reveal 101"] {
      let result = h.run(command)
      #expect(!result.ok)
      #expect(result.message.contains("Accessibility"), "\(command)")
    }
    #expect(h.overlays.finder == nil)
  }

  @Test func choicesThatArriveAfterThePaletteClosedAreIgnored() {
    let (h, safari, notes, _, _) = makeHarness()
    h.run("zoom \(safari.rawValue)")
    let workspace = h.workspace
    h.controller.finderChose(.window(notes))
    h.controller.finderDismissed()
    #expect(h.workspace == workspace)
    #expect(h.system.focused == safari)
  }

  // MARK: Going to a window

  /// Notes and Terminal side by side above Mail, and the view on those two: a group, and not the whole column.
  func frameNotesAndTerminal(_ h: Harness) -> NodeID {
    h.run("dock 104 beside 102 right")
    h.run("zoom 102")
    h.run("out")
    let pair = h.workspace.tree.parent(of: leaf(h, WindowID(102))!)!
    #expect(h.workspace.camera == pair && pair == h.workspace.tree.parent(of: leaf(h, WindowID(104))!), "the premise")
    return pair
  }

  @Test func fromAGroupChoosingAWindowOutOfViewMovesTheCameraJustFarEnoughAndFocusesIt() {
    let (h, safari, notes, mail, _) = makeHarness()
    let pair = frameNotesAndTerminal(h)
    #expect(!h.system.isVisible(mail))
    h.run("find")
    h.overlays.typeInFinder("mail")
    #expect(h.overlays.chooseInFinder())
    #expect(h.overlays.finder == nil, "a choice closes the palette")
    #expect(h.system.focused == mail)
    #expect(h.system.isVisible(mail) && h.system.isVisible(notes))
    // The column that holds the pair and Mail, not everything.
    #expect(h.workspace.camera == h.workspace.tree.parent(of: leaf(h, mail)!))
    #expect(h.workspace.camera != h.workspace.tree.root)
    #expect(!h.system.isVisible(safari))
    expectWindowsMatchLayout(h, on: h.display)
    #expect(h.run("back").ok)
    #expect(h.workspace.camera == pair, "the move is in the camera's history")
  }

  /// The level is kept, as after ⌘Tab: someone who lives framed does not lose the frame, nor show the neighbours.
  @Test func fromAFramedWindowChoosingAWindowFramesTheChosenOne() {
    let (h, _, notes, mail, _) = makeHarness()
    h.run("zoom \(notes.rawValue)")
    #expect(!h.system.isVisible(mail))
    h.run("find")
    h.overlays.typeInFinder("mail")
    #expect(h.overlays.chooseInFinder())
    #expect(h.overlays.finder == nil)
    #expect(h.system.focused == mail)
    #expect(h.workspace.camera == leaf(h, mail))
    #expect(h.system.isVisible(mail) && !h.system.isVisible(notes))
    expectWindowsMatchLayout(h, on: h.display)
    #expect(h.run("back").ok)
    #expect(h.workspace.camera == leaf(h, notes), "the move is in the camera's history")
  }

  /// ⌃⌥G and Return at once, between two framed windows: each time one goes and the other comes.
  @Test func returnAtOnceHopsBetweenTwoFramedWindows() {
    let (h, safari, notes, _, _) = makeHarness()
    h.system.userFocus(notes)
    h.system.userFocus(safari)
    h.run("zoom \(safari.rawValue)")
    for (here, there) in [(notes, safari), (safari, notes)] {
      h.run("find")
      #expect(h.overlays.chooseInFinder())
      #expect(h.system.focused == here)
      #expect(h.workspace.camera == leaf(h, here))
      #expect(!h.system.isVisible(there))
    }
  }

  /// `hold still` starts by itself during a call, and stops only what nobody asked for (F58).
  @Test(arguments: ["find inbox", "reveal 103", "palette"]) func whileHoldingStillTheViewStillGoesWhereItIsAsked(how: String) {
    let (h, safari, _, mail, terminal) = makeHarness()
    h.system.userFocus(safari)
    h.run("zoom \(safari.rawValue)")
    h.run("hold still")
    // Long after the last click or modifier key, as Return is in a palette that has been open for a while.
    h.system.secondsSinceInput = 60
    func go(_ text: String, _ window: WindowID) {
      if how == "palette" {
        h.run("find")
        h.overlays.typeInFinder(text)
        #expect(h.overlays.chooseInFinder())
      } else {
        #expect(h.run(how.hasPrefix("find") ? "find \(text)" : "reveal \(window.rawValue)").ok)
      }
      h.system.reportFocus()
      h.scheduler.runPending()
      #expect(h.system.isVisible(window), "\(window) was asked for")
      #expect(h.system.focused == window)
    }
    go("inbox", mail)
    #expect(h.workspace.camera == leaf(h, mail))
    go("zsh", terminal)
    #expect(h.workspace.camera == h.workspace.tree.desktop)
    h.system.setMinimized(mail, true)
    go("inbox", mail)
    h.system.setHidden(pid: 11, true)
    go("arbor docs", safari)
    expectWindowsMatchLayout(h, on: h.display)
  }

  /// It used to come with macOS's report of the keyboard, which holding still turns away.
  @Test func whileHoldingStillAWindowThatWasSentAwayIsSummoned() {
    let (h, safari, _, _, terminal) = makeHarness()
    h.system.userFocus(safari)
    h.run("zoom \(safari.rawValue)")
    h.run("summon Terminal")
    h.system.userFocus(terminal)
    h.run("summon Terminal")
    #expect(h.workspace.isStashed(terminal), "the premise")
    h.run("hold still")
    h.system.secondsSinceInput = 60
    #expect(h.run("find zsh").ok)
    h.system.reportFocus()
    h.scheduler.runPending()
    #expect(h.workspace.isSummoned(terminal) && h.system.isVisible(terminal) && h.system.focused == terminal)
    #expect(h.workspace.camera == leaf(h, safari))
  }

  /// As on a Mac, where the window is back a moment after it was asked, and reports the keyboard long after any key.
  @Test func whileHoldingStillAWindowComesBackFromTheDockIntoView() {
    let (h, safari, _, mail, _) = makeHarness()
    h.system.userFocus(safari)
    h.system.setMinimized(mail, true)
    h.run("zoom \(safari.rawValue)")
    h.run("hold still")
    h.system.secondsSinceInput = 60
    h.system.restoresLate = true
    #expect(h.run("find inbox").ok)
    #expect(h.workspace.camera == leaf(h, mail))
    h.system.finishRestoring()
    h.system.reportFocus()
    h.scheduler.runPending()
    #expect(h.system.isVisible(mail) && h.system.focused == mail)
    #expect(h.workspace.camera == leaf(h, mail))
    expectWindowsMatchLayout(h, on: h.display)
  }

  @Test func choosingAWindowInViewOnlyFocusesIt() {
    let (h, safari, notes, _, _) = makeHarness()
    h.system.userFocus(safari)
    let workspace = h.workspace
    h.system.clearFrameLog()
    h.run("find")
    h.overlays.typeInFinder("shopping")
    h.overlays.chooseInFinder()
    #expect(h.system.focused == notes)
    #expect(h.workspace == workspace)
    #expect(h.system.frameLog.isEmpty, "nothing moved")
  }

  /// As after a command that moves the keyboard (F37). The palette has been open for longer than a command's grace.
  @Test func theFocusRingFlashesOnTheWindowGoneTo() {
    let (h, safari, notes, _, _) = makeHarness()
    h.system.userFocus(safari)
    func pulse() -> Int? { h.overlays.scenes[h.display]?.focusRing?.pulse }
    h.run("find")
    h.scheduler.advance(by: 5)
    let before = pulse()
    h.overlays.typeInFinder("shopping")
    h.overlays.chooseInFinder()
    h.system.reportFocus()
    #expect(h.overlays.scenes[h.display]?.focusRing?.window == notes)
    #expect(pulse() != before)
  }

  @Test func rowsCanBeChosenByNumberOrClick() {
    let (h, safari, notes, mail, terminal) = makeHarness()
    h.system.focused = nil
    h.run("find")
    #expect(listedWindows(h) == [safari, notes, mail, terminal])
    #expect(h.overlays.chooseInFinder(row: 3))
    #expect(h.system.focused == mail)
    h.run("find")
    #expect(!h.overlays.chooseInFinder(row: 9), "no ninth row")
    #expect(!h.overlays.chooseInFinder(row: 0))
    #expect(h.overlays.finder != nil)
  }

  @Test func theArrowKeysChooseAnotherRow() {
    let (h, safari, notes, mail, terminal) = makeHarness()
    h.system.focused = nil
    h.run("find")
    h.overlays.moveFinderSelection(by: 1)
    #expect(h.overlays.finder?.selected == .window(notes))
    h.overlays.moveFinderSelection(by: -2)
    #expect(h.overlays.finder?.selected == .window(terminal), "round the top to the last row")
    h.overlays.chooseInFinder()
    #expect(h.system.focused == terminal)
    _ = (safari, mail)
  }

  @Test func aTileIsFramed() {
    let (h, _, notes, _, _) = makeHarness()
    let xcode = h.system.open(app: "Xcode", frame: CGRect(x: 400, y: 200, width: 700, height: 500))
    h.system.setMinimumSize(xcode, CGSize(width: 900, height: 600))
    h.run("dock \(xcode.rawValue) beside \(notes.rawValue) bottom")
    #expect(!h.system.isVisible(xcode))
    #expect(h.run("find xcode").ok)
    #expect(h.workspace.camera == leaf(h, xcode), "no wider view can show it")
    #expect(h.system.isVisible(xcode))
    #expect(h.system.focused == xcode)
  }

  @Test func fromAGroupAFloatingWindowOutOfViewBringsTheDesktopBack() {
    let (h, safari, notes, _, terminal) = makeHarness()
    h.run("zoom \(notes.rawValue)")
    h.run("out")
    #expect(h.workspace.camera == h.workspace.tree.parent(of: leaf(h, notes)!), "the premise: the column")
    #expect(!h.system.isVisible(terminal))
    #expect(h.run("reveal \(terminal.rawValue)").ok)
    #expect(h.layout?.desktopFrame?.contains(h.frame(terminal)!) == true, "back on the Desktop")
    #expect(h.system.isVisible(safari) && h.system.isVisible(notes), "zoomed out, not away")
    #expect(h.system.focused == terminal)
  }

  /// The level is kept: from one window to the Desktop alone.
  @Test func fromAFramedWindowAFloatingWindowFramesTheDesktop() {
    let (h, safari, _, _, terminal) = makeHarness()
    h.run("zoom \(safari.rawValue)")
    #expect(!h.system.isVisible(terminal))
    #expect(h.run("reveal \(terminal.rawValue)").ok)
    #expect(h.workspace.camera == h.workspace.tree.desktop)
    #expect(h.system.isVisible(terminal) && !h.system.isVisible(safari))
    #expect(h.system.focused == terminal)
  }

  /// With many columns the Desktop is a tile at the level that would show it, so zooming out is not enough.
  @Test func aFloatingWindowIsShownEvenWhenTheDesktopIsTooSmallToShow() {
    // From a saved state: `dock` would keep a Desktop with a window on it at a usable size.
    var tree = LayoutTree()
    for number in 101...107 { tree.dock(WindowID(UInt32(number)), beside: tree.root, edge: .left) }
    // Plainly floating: found over a view without the Desktop, it would otherwise be a guest of that view, and be shown there.
    var settings = Settings()
    settings.newWindowsWhileFramed = "float"
    let h = Harness(
      settings: settings, saved: PersistedState(workspaces: [main.id: Workspace(tree: tree)], hints: [:]))
    let docked = (0..<7).map { h.system.open(app: "App\($0)") }
    let floating = h.system.open(app: "Terminal", frame: CGRect(x: 500, y: 300, width: 300, height: 200))
    h.start()
    #expect(h.layout?.tiles.contains { $0.kind == .desktop } == true, "the premise")
    h.run("zoom \(docked[0].rawValue)")
    #expect(!h.system.isVisible(floating))
    #expect(h.run("reveal \(floating.rawValue)").ok)
    #expect(h.system.isVisible(floating))
    #expect(h.workspace.camera == h.workspace.tree.desktop)
  }

  @Test func revealWithoutAWindowMeansTheFocusedOne() {
    let (h, safari, notes, _, _) = makeHarness()
    h.run("zoom \(safari.rawValue)")
    h.system.focus(notes)  // as after ⌘Tab, before macOS has reported it
    #expect(h.run("reveal").ok)
    #expect(h.system.isVisible(notes))
    h.system.focused = nil
    #expect(h.run("reveal").message.hasPrefix("no focused window"))
    #expect(!h.run("reveal 999").ok)
  }

  @Test func revealingTwiceIsTheSameAsOnce() {
    let (h, safari, _, mail, _) = makeHarness()
    h.run("zoom \(safari.rawValue)")
    h.run("reveal \(mail.rawValue)")
    let workspace = h.workspace
    h.system.clearFrameLog()
    #expect(h.run("reveal \(mail.rawValue)").ok)
    #expect(h.workspace == workspace)
    #expect(h.system.frameLog.isEmpty)
  }

  /// macOS reports Arbor's own focus call back a moment later.
  @Test func theEchoOfTheFocusChangesNothing() {
    let (h, safari, _, mail, _) = makeHarness()
    h.system.userFocus(safari)
    h.run("zoom \(safari.rawValue)")
    h.run("find inbox")
    let workspace = h.workspace
    h.system.clearFrameLog()
    h.system.userFocus(mail)
    #expect(h.workspace == workspace)
    #expect(h.system.frameLog.isEmpty)
    h.run("find")
    #expect(listedWindows(h).first == safari, "and Safari is still the window before this one")
  }

  @Test func nothingIsRevealedWhileAWindowIsBeingDragged() {
    let (h, safari, _, mail, terminal) = makeHarness()
    h.run("zoom \(safari.rawValue)")
    let camera = h.workspace.camera
    h.controller.dragBegan(safari, at: CGPoint(x: 700, y: 50))
    let result = h.run("reveal \(mail.rawValue)")
    #expect(!result.ok)
    #expect(result.message.contains("dragged"))
    #expect(h.workspace.camera == camera)
    #expect(h.system.focused != mail)
    h.controller.dragEnded(safari, at: CGPoint(x: 700, y: 450))
    #expect(h.run("reveal \(mail.rawValue)").ok)
    _ = terminal
  }

  // MARK: Tabs

  /// Safari and Notes share a tab group on the left, Notes showing; Mail is on the right.
  func makeTabs() -> (Harness, WindowID, WindowID, WindowID) {
    let (safari, notes, mail) = (WindowID(101), WindowID(102), WindowID(103))
    var tree = LayoutTree()
    let group = tree.dock(safari, beside: tree.root, edge: .left)
    tree.addToStack(notes, leaf: group)
    tree.dock(mail, beside: tree.root, edge: .right)
    let h = Harness(saved: PersistedState(workspaces: [main.id: Workspace(tree: tree)], hints: [:]))
    for app in ["Safari", "Notes", "Mail"] { h.system.open(app: app) }
    h.start()
    return (h, safari, notes, mail)
  }

  @Test func choosingAHiddenTabShowsIt() {
    let (h, safari, notes, _) = makeTabs()
    #expect(h.system.isVisible(notes) && !h.system.isVisible(safari), "the premise")
    #expect(note(h, safari) == "tab")
    #expect(note(h, notes) == "in view")
    let slot = h.frame(notes)!
    h.run("find")
    h.overlays.typeInFinder("safari")
    h.overlays.chooseInFinder()
    #expect(h.frame(safari) == slot)
    #expect(!h.system.isVisible(notes))
    #expect(h.workspace.tree.activeWindow(of: leaf(h, safari)!) == safari)
    #expect(h.system.focused == safari)
    #expect(h.workspace.camera == h.workspace.tree.root, "the group was in view, so the camera stays")
    #expect(note(h, notes) == "tab")
  }

  @Test func aHiddenTabOfAGroupOutOfViewIsShownAndBroughtIntoView() {
    let (h, safari, notes, mail) = makeTabs()
    h.run("zoom \(mail.rawValue)")
    #expect(note(h, safari) == "tab")
    #expect(note(h, notes) == "out of view")
    #expect(h.run("reveal \(safari.rawValue)").ok)
    #expect(h.system.isVisible(safari))
    #expect(!h.system.isVisible(notes))
    #expect(!h.system.isVisible(mail), "the level is kept: from one space to the other")
    expectWindowsMatchLayout(h, on: h.display)
  }

  // MARK: Minimized, hidden, on another Space

  @Test func aMinimizedWindowIsRestoredAndBroughtIntoView() {
    let (h, safari, notes, mail, _) = makeHarness()
    let slot = h.frame(mail)!
    h.system.setMinimized(mail, true)
    h.run("zoom \(safari.rawValue)")
    h.run("find")
    h.overlays.typeInFinder("inbox")
    h.overlays.chooseInFinder()
    #expect(h.controller.windows[mail]?.isMinimized == false)
    #expect(h.system.focused == mail)
    #expect(h.workspace.camera == leaf(h, mail), "framed, as Safari was")
    expectWindowsMatchLayout(h, on: h.display)
    h.run("show-all")
    #expect(h.frame(mail) == slot, "back in its own place")
    #expect(h.system.isVisible(notes))
    expectWindowsMatchLayout(h, on: h.display)
  }

  @Test func aWindowOfAHiddenAppComesBackWithItsApp() {
    let (h, safari, notes, _, _) = makeHarness()
    let second = h.system.open(app: "Notes", title: "Ideas", pid: 12, frame: CGRect(x: 520, y: 320, width: 300, height: 200))
    h.system.setHidden(pid: 12, true)
    h.run("zoom \(safari.rawValue)")
    #expect(h.run("find shopping").ok)
    #expect(h.controller.windows[notes]?.isHidden == false)
    #expect(h.controller.windows[second]?.isHidden == false, "⌘H hides an app, so unhiding shows all of it")
    #expect(h.system.isVisible(notes))
    #expect(h.system.focused == notes)
    expectWindowsMatchLayout(h, on: h.display)
  }

  @Test func aMinimizedWindowOfAHiddenAppNeedsBoth() {
    let (h, safari, notes, _, _) = makeHarness()
    h.system.setMinimized(notes, true)
    h.system.setHidden(pid: 12, true)
    h.run("zoom \(safari.rawValue)")
    #expect(h.run("reveal \(notes.rawValue)").ok)
    #expect(h.controller.windows[notes]?.isPresent == true)
    #expect(h.system.isVisible(notes))
  }

  /// On macOS the report that a window is back arrives a moment after the request, and the report that it has
  /// the keyboard can arrive first. The view must come out the same whichever way round.
  @Test(arguments: [false, true]) func theResultDoesNotDependOnWhenMacOSReports(hidden: Bool) {
    func run(late: Bool) -> (Workspace, [WindowID: CGRect]) {
      let (h, _, notes, mail, _) = makeHarness()
      if hidden { h.system.setHidden(pid: 13, true) } else { h.system.setMinimized(mail, true) }
      // From a group, where the view depends on whether Mail would show at the level above.
      _ = frameNotesAndTerminal(h)
      h.system.restoresLate = late
      #expect(h.run("reveal \(mail.rawValue)").ok)
      if late {
        #expect(h.controller.windows[mail]?.isPresent == false, "Arbor has not been told yet")
        h.system.userFocus(mail)
        h.system.finishRestoring()
      } else {
        h.system.userFocus(mail)
      }
      #expect(h.system.isVisible(mail) && h.system.isVisible(notes))
      expectWindowsMatchLayout(h, on: h.display)
      return (h.workspace, h.layout!.windowFrames)
    }
    let (prompt, late) = (run(late: false), run(late: true))
    #expect(prompt.0.camera == late.0.camera)
    #expect(prompt.0.camera != prompt.0.tree.root, "the column that holds them and Mail is enough")
    #expect(prompt.1 == late.1)
  }

  @Test func aWindowOnAnotherSpaceIsOnlyFocusedAndTheCameraFollowsWhenItsSpaceShows() {
    let (h, safari, _, mail, _) = makeHarness()
    h.system.setOnActiveSpace(mail, false)
    h.scheduler.runPending()
    h.system.userFocus(safari)
    h.run("zoom \(safari.rawValue)")
    let workspace = h.workspace
    h.system.clearFrameLog()
    #expect(h.run("find inbox").ok)
    #expect(h.system.focused == mail, "which makes macOS switch Spaces")
    #expect(h.workspace == workspace, "the Space the user is leaving is not rearranged")
    #expect(h.system.frameLog.isEmpty)
    // macOS switches: Mail's Space shows, and Mail reports the keyboard.
    h.system.setOnActiveSpace(mail, true)
    h.scheduler.runPending()
    h.system.userFocus(mail)
    #expect(h.system.isVisible(mail))
    h.run("find")
    #expect(listedWindows(h).first == safari)
  }

  @Test func aWindowInFullScreenIsOnlyFocused() {
    let (h, safari, notes, mail, terminal) = makeHarness()
    // The green button on Mail, then a swipe back to the Space of the others.
    h.system.setFullScreen(mail, true)
    h.system.setOnActiveSpace(mail, false)
    h.scheduler.advance(by: 2)
    #expect(note(h, mail) == "full screen")
    h.system.userFocus(safari)
    h.run("zoom \(safari.rawValue)")
    let workspace = h.workspace
    h.system.clearFrameLog()
    #expect(h.run("find inbox").ok)
    #expect(h.system.focused == mail, "which makes macOS show its Space")
    #expect(h.workspace == workspace)
    #expect(h.system.frameLog.isEmpty, "a window in full screen is macOS's to place")
    _ = (notes, terminal)
  }

  /// Switching Spaces gives the keyboard to a window of the new Space, which macOS can report before Arbor has
  /// laid the display out for the windows that show now.
  @Test func aTripToAnotherSpaceAndBackLeavesTheCameraWhereItWas() {
    let (h, safari, notes, mail, terminal) = makeHarness()
    h.system.setOnActiveSpace(mail, false)
    h.scheduler.runPending()
    h.system.userFocus(safari)
    h.run("zoom \(safari.rawValue)")
    let before = h.workspace
    let framed = h.frame(safari)

    for window in [safari, notes, terminal] { h.system.setOnActiveSpace(window, false) }
    h.system.setOnActiveSpace(mail, true)
    h.system.userFocus(mail)
    h.scheduler.runPending()
    #expect(h.system.isVisible(mail))
    #expect(h.workspace == before, "Mail shows without the camera moving, so it does not move")

    h.system.setOnActiveSpace(mail, false)
    for window in [safari, notes, terminal] { h.system.setOnActiveSpace(window, true) }
    h.system.userFocus(safari)
    h.scheduler.runPending()
    #expect(h.workspace == before)
    #expect(h.frame(safari) == framed, "still framed")
    expectWindowsMatchLayout(h, on: h.display)
  }

  // MARK: What was chosen has gone

  @Test func choosingAWindowThatHasClosedSaysSoAndKeepsThePaletteOpenWithAFreshList() {
    let (h, safari, notes, mail, terminal) = makeHarness()
    h.system.userFocus(safari)
    h.run("find")
    h.overlays.typeInFinder("o")
    #expect(h.overlays.finder?.items.map(\.row.destination).contains(.window(notes)) == true)
    h.overlays.typeInFinder("notes")
    h.system.close(notes)
    #expect(row(h, notes) != nil, "the list is a snapshot, so the row is still there")
    let workspace = h.workspace
    #expect(h.overlays.chooseInFinder())
    #expect(h.overlays.finderBeeps == 1)
    #expect(h.overlays.finder?.message == "That window has closed")
    #expect(h.overlays.finder?.query == "notes", "what was typed stays")
    #expect(Set(listedWindows(h)) == [safari, mail, terminal])
    #expect(h.overlays.finder?.items.isEmpty == true)
    #expect(h.workspace == workspace)
    #expect(h.system.focused == safari)
    // The palette goes on working.
    h.overlays.typeInFinder("mail")
    h.overlays.chooseInFinder()
    #expect(h.system.focused == mail)
    #expect(h.overlays.finder == nil)
    #expect(h.overlays.finderBeeps == 1)
  }

  @Test func whenTheLastWindowHasClosedThePaletteSaysSo() {
    let h = Harness()
    let only = h.system.open(app: "Safari")
    h.start()
    h.run("find")
    h.system.close(only)
    h.overlays.chooseInFinder()
    #expect(h.overlays.finder?.model.rows.isEmpty == true)
    #expect(h.overlays.finder?.message == "That window has closed")
    #expect(!h.overlays.chooseInFinder(), "nothing left to choose")
    h.overlays.dismissFinder()
  }

  // MARK: `find <text>`

  @Test func findWithTextGoesStraightToTheBestMatch() {
    let (h, safari, notes, mail, _) = makeHarness()
    h.run("zoom \(safari.rawValue)")
    let result = h.run("find shop")
    #expect(result.ok)
    #expect(result.message == "\(notes) is in view and focused")
    #expect(h.overlays.finder == nil, "no palette")
    #expect(h.system.focused == notes)
    #expect(h.run("find MAIL inbox").ok)
    #expect(h.system.focused == mail)
    #expect(h.run("find/arbor/docs").ok, "as a URL writes it: arbor://find/arbor/docs")
    #expect(h.system.focused == safari)
  }

  @Test func findWithTextPrefersTheOtherWindowOfTheSameApp() {
    let (h, safari, _, _, _) = makeHarness()
    let news = h.system.open(app: "Safari", title: "News", pid: 11)
    h.system.userFocus(safari)
    h.system.userFocus(news)
    #expect(h.run("find safari").ok)
    #expect(h.system.focused == safari, "the focused window comes after its equals")
    #expect(h.run("find safari").ok)
    #expect(h.system.focused == news)
  }

  @Test func findWithNoMatchFailsAndSaysSo() {
    let (h, safari, _, _, _) = makeHarness()
    h.run("zoom \(safari.rawValue)")
    let workspace = h.workspace
    let result = h.run("find zebra crossing")
    #expect(!result.ok)
    #expect(result.message == "no window, space or saved view matches “zebra crossing”")
    let long = h.run("find " + String(repeating: "z", count: 500)).message
    #expect(long.contains("“" + String(repeating: "z", count: 80) + "”"), "a long text is quoted up to 80 characters")
    #expect(h.workspace == workspace)
    #expect(h.system.focused == safari)
    #expect(h.overlays.finder == nil)
  }

  @Test func findWithTextClosesAnOpenPalette() {
    let (h, _, _, mail, _) = makeHarness()
    h.run("find")
    #expect(h.run("find inbox").ok)
    #expect(h.system.focused == mail)
    #expect(h.overlays.finder == nil, "the user is somewhere else now")
  }

  // MARK: Saved views

  @Test func savedViewsAreListedAfterTheWindowsWithTheAppsTheyShow() {
    let (h, safari, notes, _, _) = makeHarness()
    h.run("save-view 1")
    h.run("zoom \(notes.rawValue)")
    h.run("out")
    h.run("save-view 4")
    h.run("desktop")
    h.run("save-view 9")
    h.run("zoom \(safari.rawValue)")
    h.run("find")
    let rows = h.overlays.finder?.model.rows.dropFirst(4) ?? []
    #expect(rows.map(\.destination) == [.view(main.id, slot: 1), .view(main.id, slot: 4), .view(main.id, slot: 9)])
    #expect(rows.map(\.name) == ["View 1", "View 4", "View 9"])
    #expect(rows.map(\.detail) == ["Safari, the Desktop, Notes, Mail", "Notes, Mail", "the Desktop"])
    #expect(rows.allSatisfy { $0.note == "saved view" && $0.pid == nil })
    #expect(rows.map(\.badge) == ["1", "4", "9"])
  }

  @Test func choosingASavedViewMovesTheCameraThere() {
    let (h, safari, notes, mail, _) = makeHarness()
    h.run("zoom \(notes.rawValue)")
    h.run("out")
    let column = h.workspace.camera
    h.run("save-view 4")
    h.run("zoom \(safari.rawValue)")
    h.run("find")
    h.overlays.typeInFinder("v4")
    #expect(h.overlays.finder?.selected == .view(main.id, slot: 4))
    h.overlays.chooseInFinder()
    #expect(h.overlays.finder == nil)
    #expect(h.workspace.camera == column)
    #expect(h.system.isVisible(notes) && h.system.isVisible(mail) && !h.system.isVisible(safari))
    #expect(h.system.focused != safari, "the keyboard does not stay with a window that went out of view")
    h.run("zoom \(safari.rawValue)")
    #expect(h.run("find view 4").message == "view 4: Notes and Mail (\(column))")
    #expect(h.workspace.camera == column)
  }

  @Test func aViewHoldingAnAppIsFoundByItButAfterTheAppsOwnWindows() {
    let (h, _, notes, mail, _) = makeHarness()
    h.run("zoom \(notes.rawValue)")
    h.run("out")
    h.run("save-view 4")
    h.run("find")
    h.overlays.typeInFinder("mail")
    #expect(h.overlays.finder?.items.map(\.row.destination) == [.window(mail), .view(main.id, slot: 4)])
  }

  /// Nothing that leaves the palette open takes a saved view away today. Should that change, the palette says so.
  @Test func aSavedViewThatHasGoneSaysSo() {
    let (h, safari, _, _, _) = makeHarness()
    h.run("zoom \(safari.rawValue)")
    h.run("save-view 2")
    h.run("find")
    let camera = h.workspace.camera
    h.controller.finderChose(.view(main.id, slot: 7))
    #expect(h.overlays.finderBeeps == 1)
    #expect(h.overlays.finder?.message == "That saved view no longer exists")
    #expect(h.overlays.finder?.model.rows.filter { $0.place == .savedView }.map(\.destination) == [.view(main.id, slot: 2)])
    #expect(h.workspace.camera == camera)
  }

  // MARK: Named spaces (F20)

  /// Notes over Mail is "Writing"; Safari alone is "Reading".
  func makeNames() -> (Harness, safari: WindowID, notes: WindowID, column: NodeID) {
    let (h, safari, notes, _, _) = makeHarness()
    h.run("zoom \(notes.rawValue)")
    h.run("out")
    let column = h.workspace.camera
    h.run("name Writing")
    h.run("zoom \(safari.rawValue)")
    h.run("name Reading")
    h.run("save-view 1")
    return (h, safari, notes, column)
  }

  @Test func namedSpacesAreListedAfterTheWindowsAndBeforeTheSavedViews() {
    let (h, safari, _, column) = makeNames()
    h.run("find")
    let rows = h.overlays.finder?.model.rows.dropFirst(4) ?? []
    #expect(
      rows.map(\.destination) == [.space(main.id, leaf(h, safari)!), .space(main.id, column), .view(main.id, slot: 1)])
    #expect(rows.map(\.name) == ["Reading", "Writing", "View 1"])
    #expect(rows.map(\.detail) == ["Safari", "Notes, Mail", "Safari"])
    #expect(rows.map(\.note) == ["space", "space", "saved view"])
    #expect(rows.map(\.badge) == ["R", "W", "1"])
  }

  @Test func aNamedSpaceIsGoneToByAFewLetters() {
    let (h, _, notes, column) = makeNames()
    h.run("find")
    h.overlays.typeInFinder("wri")
    #expect(h.overlays.finder?.selected == .space(main.id, column))
    h.overlays.chooseInFinder()
    #expect(h.overlays.finder == nil)
    #expect(h.workspace.camera == column)
    #expect(h.system.isVisible(notes))
  }

  /// `go-to Writing` and `go Writing` end in the same place, whatever else is called so.
  @Test func theVeryNameOfASpaceComesBeforeEverythingElse() {
    let (h, _, _, column) = makeNames()
    let app = h.system.open(app: "Writing", title: "Writing")
    h.system.open(app: "Writing Pro", title: "Untitled")
    h.run("find")
    h.overlays.typeInFinder("WRITING")
    #expect(h.overlays.finder?.selected == .space(main.id, column))
    h.overlays.typeInFinder("writin")
    #expect(h.overlays.finder?.selected == .window(app), "short of the whole name it is a match like any other")
    h.overlays.dismissFinder()
    #expect(h.run("go-to Writing").ok)
    #expect(h.workspace.camera == column)
  }

  @Test func aNameOnTwoDisplaysIsListedTwice() {
    let (h, safari, xcode, _) = makeTwoDisplays()
    h.run("zoom \(safari.rawValue)")
    h.run("name Work")
    h.system.cursor = CGPoint(x: 2000, y: 400)
    h.system.userFocus(xcode)
    h.run("zoom \(xcode.rawValue)")
    h.run("name Work")
    h.run("find")
    let spaces = h.overlays.finder?.model.rows.filter { $0.place == .namedSpace } ?? []
    #expect(Set(spaces.map(\.display)) == [main.id, side.id], "`go Work` reaches one of them, the picker both")
    #expect(Set(spaces.map(\.note)) == ["space, on display 1", "space, on Studio Display"])
  }

  // MARK: Summoned and sent away (F53)

  @Test func aStashedWindowIsSummonedWhenChosen() {
    let (h, safari, _, _, terminal) = makeHarness()
    h.system.userFocus(safari)
    h.run("zoom \(safari.rawValue)")
    h.run("summon Terminal")
    #expect(note(h, terminal) == "summoned")
    let remembered = h.frame(terminal)
    h.system.userFocus(terminal)
    h.run("summon Terminal")
    #expect(h.workspace.isStashed(terminal) && !h.system.isVisible(terminal), "the premise")
    #expect(note(h, terminal) == "out of view until summoned")
    let camera = h.workspace.camera

    h.run("find")
    h.overlays.typeInFinder("zsh")
    h.overlays.chooseInFinder()
    #expect(h.workspace.isSummoned(terminal), "at once: macOS has not reported the keyboard yet")
    #expect(h.frame(terminal) == remembered, "where it was the last time")
    #expect(h.system.focused == terminal)
    h.system.reportFocus()
    #expect(h.workspace.isSummoned(terminal))
    #expect(h.workspace.camera == camera, "the view does not go looking for it on the Desktop")
    h.run("summon Terminal")
    #expect(h.workspace.isStashed(terminal))
    #expect(h.system.focused == safari, "the keyboard goes back to where it was")
  }

  // MARK: What is no longer there

  @Test func aSpaceIsFramedWhenChosen() {
    let (h, safari, notes, _, _) = makeHarness()
    h.run("zoom \(safari.rawValue)")
    let column = h.workspace.tree.parent(of: leaf(h, notes)!)!
    h.run("find")
    h.controller.finderChose(.space(main.id, column))
    #expect(h.overlays.finder == nil)
    #expect(h.workspace.camera == column)
    h.run("find")
    h.controller.finderChose(.space(main.id, NodeID(999)))
    #expect(h.overlays.finder?.message == "That space no longer exists")
    #expect(h.workspace.camera == column)
  }

  // MARK: Several displays

  /// The usual windows on the main display; Xcode docked beside Preview on the side display.
  func makeTwoDisplays() -> (Harness, safari: WindowID, xcode: WindowID, preview: WindowID) {
    let (h, safari, _, _, _) = makeHarness(displays: [main, side])
    let xcode = h.system.open(app: "Xcode", title: "Arbor", frame: CGRect(x: 1600, y: 100, width: 600, height: 400))
    let preview = h.system.open(app: "Preview", title: "Plan.pdf", frame: CGRect(x: 1700, y: 200, width: 600, height: 400))
    h.run("dock \(xcode.rawValue) left")
    h.run("dock \(preview.rawValue) right")
    h.system.userFocus(safari)
    return (h, safari, xcode, preview)
  }

  @Test func withSeveralDisplaysEveryRowSaysWhichItIsOn() {
    let (h, safari, xcode, _) = makeTwoDisplays()
    #expect(h.controller.workspaces[side.id]?.isDocked(xcode) == true, "the premise")
    h.run("find")
    #expect(row(h, safari)?.note == "in view, on display 1", "a display without a name has a number")
    #expect(row(h, xcode)?.note == "in view, on Studio Display")
    #expect(row(h, xcode)?.display == side.id)
  }

  /// "display 3" is what `@3` means, whatever order macOS lists the displays in.
  @Test func displaysAreNumberedAsEverywhereElse() {
    let far = DisplaySnapshot(
      id: DisplayID("far"), frame: CGRect(x: 2720, y: 0, width: 1280, height: 800),
      visibleFrame: CGRect(x: 2720, y: 25, width: 1280, height: 775), isMain: false)
    var near = side
    near.name = nil
    let h = Harness(displays: [far, main, near])
    let a = h.system.open(app: "Safari")
    let b = h.system.open(app: "Notes", frame: CGRect(x: 1600, y: 100, width: 600, height: 400))
    let c = h.system.open(app: "Mail", frame: CGRect(x: 2900, y: 100, width: 600, height: 400))
    h.start()
    h.run("find")
    #expect([a, b, c].map { row(h, $0)?.displayName } == ["display 1", "display 2", "display 3"])
  }

  @Test func displaysOfTheSameMakeAreToldApart() {
    var left = main
    left.name = "DELL U2720Q"
    var right = side
    right.name = "DELL U2720Q"
    let h = Harness(displays: [left, right])
    let a = h.system.open(app: "Safari")
    let b = h.system.open(app: "Notes", frame: CGRect(x: 1600, y: 100, width: 600, height: 400))
    h.start()
    h.run("find")
    #expect(row(h, a)?.displayName == "DELL U2720Q (1)")
    #expect(row(h, b)?.displayName == "DELL U2720Q (2)")
  }

  @Test func aWindowOnTheOtherDisplayIsRevealedThereAndThisDisplayStaysAsItIs() {
    let (h, safari, xcode, preview) = makeTwoDisplays()
    h.system.cursor = CGPoint(x: 2000, y: 400)
    h.run("zoom \(preview.rawValue)")
    h.system.cursor = CGPoint(x: 720, y: 450)
    h.run("zoom \(safari.rawValue)")
    let here = h.workspace
    #expect(!h.system.isVisible(xcode))

    h.run("find")
    #expect(h.overlays.finder?.model.display == main.id)
    #expect(row(h, xcode)?.note == "out of view, on Studio Display")
    h.overlays.typeInFinder("xcode")
    h.overlays.chooseInFinder()
    #expect(h.system.focused == xcode)
    #expect(h.system.isVisible(xcode))
    #expect(side.frame.contains(h.frame(xcode)!))
    #expect(h.workspace == here)
    #expect(h.system.cursor == CGPoint(x: 720, y: 450), "the pointer is the user's")
    expectWindowsMatchLayout(h, on: side.id)
    expectWindowsMatchLayout(h, on: main.id)
  }

  /// Shortcuts follow the keyboard (F56), and the picker takes the keyboard to another display without the pointer.
  @Test func shortcutsFollowToTheDisplayThePickerWentTo() {
    let (h, safari, xcode, _) = makeTwoDisplays()
    h.run("zoom \(safari.rawValue)")
    let here = h.workspace
    func there() -> Workspace { h.controller.workspaces[side.id]! }
    h.scheduler.advance(by: 5)  // the pointer rests on the main display

    #expect(h.press("find").ok)
    #expect(h.overlays.finder?.model.display == main.id)
    h.system.type()
    h.overlays.typeInFinder("xcode")
    h.overlays.chooseInFinder()
    h.system.reportFocus()
    h.scheduler.advance(by: 0.3)
    #expect(h.press("zoom").ok)
    #expect(there().camera == leaf(h, xcode, on: side.id))
    #expect(h.press("show-all").ok)
    #expect(there().camera == there().tree.root)
    #expect(h.workspace == here, "the display under the pointer was left alone")
    #expect(h.press("find").ok)
    #expect(h.overlays.finder?.model.display == side.id, "and the palette opens where the user is looking")
  }

  @Test func pinnedWindowsAreListedAndOnlyFocused() {
    let (h, safari, _, _, terminal) = makeHarness()
    h.run("pin \(terminal.rawValue)")
    h.run("zoom \(safari.rawValue)")
    #expect(note(h, terminal) == "kept in view")
    let workspace = h.workspace
    #expect(h.run("find zsh").ok)
    #expect(h.system.focused == terminal)
    #expect(h.workspace == workspace, "the view stays")
  }

  @Test func savedViewsOfEveryDisplayAreListedAndRecalledOnTheirOwn() {
    let (h, safari, xcode, _) = makeTwoDisplays()
    h.run("zoom \(safari.rawValue)")
    h.run("save-view 1")
    h.system.cursor = CGPoint(x: 2000, y: 400)
    h.run("zoom \(xcode.rawValue)")
    h.run("save-view 1")
    h.run("show-all")
    h.system.cursor = CGPoint(x: 720, y: 450)
    h.run("show-all")

    h.run("find")
    let views = h.overlays.finder?.model.rows.filter { $0.place == .savedView } ?? []
    #expect(views.map(\.destination) == [.view(main.id, slot: 1), .view(side.id, slot: 1)])
    #expect(views.map(\.note) == ["saved view, on display 1", "saved view, on Studio Display"])
    #expect(views.map(\.detail) == ["Safari", "Xcode"])
    h.overlays.typeInFinder("view xcode")
    h.overlays.chooseInFinder()
    #expect(h.controller.workspaces[side.id]!.camera == leaf(h, xcode, on: side.id))
    #expect(h.workspace.camera == h.workspace.tree.root, "view 1 of this display was not meant")
  }

  @Test func aDisplayThatGoesAwayClosesThePalette() {
    let (h, _, xcode, _) = makeTwoDisplays()
    h.system.cursor = CGPoint(x: 2000, y: 400)
    h.run("save-view 3")
    h.run("find")
    #expect(h.overlays.finder?.model.display == side.id)
    h.system.setDisplays([main])
    #expect(h.overlays.finder == nil, "it may have been on the display that went")
    #expect(h.run("find").message == "Go to… is open")
    #expect(h.overlays.finder?.model.display == main.id)
    h.overlays.typeInFinder("xcode")
    h.overlays.chooseInFinder()
    #expect(h.system.focused == xcode)
    #expect(h.system.isVisible(xcode))
    #expect(h.run("show-all").ok)
  }

  // MARK: Privacy

  /// `arbor.log`, wherever `ArborPaths` keeps it: tests have a folder of their own.
  private var logFile: URL { ArborPaths.logFile }

  /// Replies call a named space by its name (F20); the log never does, by whatever road the view got there.
  @Test func theNameOfASpaceGoneToIsNotLogged() throws {
    let (h, safari, _, _, _) = makeHarness()
    // A word of its own: NamedSpacesTests looks through the same log for its own.
    let secret = "Timbuktu\(UInt32.random(in: 0...UInt32.max))"
    h.run("zoom \(safari.rawValue)")
    h.run("name \(secret)")
    h.run("save-view 1")
    h.run("show-all")
    let reply = h.run("find view 1")
    #expect(reply.ok && reply.message.contains(secret), "whoever asked is told: \(reply.message)")
    let log = ((try? String(contentsOf: logFile.appendingPathExtension("1"), encoding: .utf8)) ?? "")
      + (try String(contentsOf: logFile, encoding: .utf8))
    #expect(!log.contains(secret))
  }

  /// While the view is held (F58: a call, a shared screen) these are refused, and the refusal is logged. Not what was typed.
  /// Refusals are debug lines, which are written only with ARBOR_DEBUG set, as for a bug report: without it this would pass idly.
  @Test(.enabled(if: !["", "0"].contains(ProcessInfo.processInfo.environment["ARBOR_DEBUG"] ?? "")))
  func whatIsRefusedWhileTheViewIsHeldIsLoggedWithoutItsWords() throws {
    let (h, safari, _, _, _) = makeHarness()
    let secret = "Samarkand\(UInt32.random(in: 0...UInt32.max))"
    h.run("zoom \(safari.rawValue)")
    #expect(h.run("hold").ok)
    for command in ["find \(secret)", "go \(secret)", "layout Safari~\(secret) | Mail"] {
      #expect(!h.run(command).ok, "\(command)")
    }
    let log = ((try? String(contentsOf: logFile.appendingPathExtension("1"), encoding: .utf8)) ?? "")
      + (try String(contentsOf: logFile, encoding: .utf8))
    #expect(!log.contains(secret))
  }

  /// Titles are shown, never logged, and what the user types to find a title is part of one.
  @Test func neitherTitlesNorQueriesAreLogged() throws {
    let secret = "Zanzibar\(UInt32.random(in: 0...UInt32.max))"
    // The display's id is logged, which tells this run's lines from those of other tests and earlier runs.
    var display = main
    display = DisplaySnapshot(
      id: DisplayID("display-\(secret.dropFirst(8))"), frame: display.frame, visibleFrame: display.visibleFrame, isMain: true)
    let h = Harness(displays: [display])
    let a = h.system.open(app: "Safari", title: "\(secret) accounts")
    let b = h.system.open(app: "Notes", title: "\(secret) diary")
    h.start()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) right")
    h.run("zoom \(a.rawValue)")
    h.run("save-view 1")

    #expect(h.run("find \(secret) diary").ok)
    #expect(!h.run("find \(secret)nothing").ok)
    #expect(h.run("find").ok)
    h.overlays.typeInFinder("\(secret) acc")
    #expect(h.overlays.chooseInFinder())
    h.run("find")
    h.overlays.typeInFinder(secret)
    h.system.close(b)
    h.overlays.moveFinderSelection(by: 1)
    h.overlays.chooseInFinder()
    h.overlays.dismissFinder()
    h.run("reveal \(a.rawValue)")
    h.run("find view 1")
    // A space's name is a client, a project: replies say it, the log does not (F20).
    h.run("name \(secret)client")
    #expect(h.run("find \(secret)client").message.contains("\(secret)client"))
    #expect(h.run("find view 1").message.contains("\(secret)client"), "the saved view is of the named space")

    // The file before this one too, in case the log was rotated just now.
    let log = ((try? String(contentsOf: ArborPaths.logFile.appendingPathExtension("1"), encoding: .utf8)) ?? "")
      + (try String(contentsOf: ArborPaths.logFile, encoding: .utf8))
    #expect(log.contains("find: showing 3 destination(s) on \(display.id)"), "this run's lines are in the file")
    #expect(log.contains("find: \(b): \(b) is in view and focused"))
    #expect(!log.contains(secret))
  }
}

/// The text forms of the finder's commands, and its shortcut.
@Suite struct FinderCommandTests {
  @Test func parse() throws {
    #expect(try Command.parse("find") == .find(nil))
    #expect(try Command.parse("find safari docs") == .find("safari docs"))
    #expect(try Command.parse("FIND  Safari   Docs ") == .find("Safari Docs"), "the text keeps its case")
    #expect(try Command.parse("go-to safari") == .find("safari"))
    #expect(try Command.parse(words: ["find", "Übersicht 2"]) == .find("Übersicht 2"), "a URL's words may hold spaces")
    #expect(try Command.parse(words: ["find", "a/b  c", " "]) == .find("a b c"), "so that the text parses back to the same")
    #expect(try Command.parse(words: ["find", "/", " "]) == .find(nil))
    #expect(try Command.parse("reveal") == .reveal(nil))
    #expect(try Command.parse("reveal 412") == .reveal(WindowID(412)))
    #expect(try Command.parse("reveal w412") == .reveal(WindowID(412)))
    #expect(throws: Command.ParseError.self) { try Command.parse("reveal safari") }
  }

  @Test(arguments: [
    Command.find(nil), .find("safari"), .find("Safari docs 2"), .reveal(nil), .reveal(WindowID(7)),
  ])
  func textRoundTrips(command: Command) throws {
    #expect(try Command.parse(command.text) == command)
  }

  @Test func theLogNeverSeesWhatWasLookedFor() {
    #expect(Command.find("bank statement").textForLog == "find …")
    #expect(Command.find(nil).textForLog == "find")
    #expect(Command.reveal(WindowID(7)).textForLog == "reveal 7")
  }

  @Test func neitherIsAQuery() {
    #expect(!Command.find(nil).isQuery && !Command.find("a").isQuery && !Command.reveal(nil).isQuery)
  }

  @Test func theHelpListsThem() {
    for line in ["find [text…]", "reveal [window]"] { #expect(Command.helpText.contains(line)) }
  }

  /// Any web page can ask macOS to open an arbor:// URL (CommandURL.swift).
  @Test func urlsMayNeitherOpenThePaletteNorGoToAWindow() throws {
    #expect(try Command.parse(url: "arbor://find/safari/docs") == .find("safari docs"), "they parse, for those who allow all")
    #expect(try Command.parse(url: "arbor://find/%C3%9Cbersicht") == .find("Übersicht"))
    #expect(!Command.find(nil).isAllowedFromURL, "it would take the keyboard from whatever the user is typing")
    #expect(!Command.find("safari docs").isAllowedFromURL, "a link must not fetch a window by words in its title")
    #expect(!Command.reveal(WindowID(412)).isAllowedFromURL && !Command.reveal(nil).isAllowedFromURL)
  }

  @Test func controlOptionGOpensIt() throws {
    #expect(KeyBindings.label(for: .find(nil)) == "⌃⌥G")
    #expect(KeyBindings.defaults.filter { $0.chord == KeyChord([.control, .option], .g) }.map(\.command) == [.find(nil)])
    // It can be moved, and a shortcut can go straight to a window.
    var settings = Settings()
    settings.bindings = ["ctrl+opt+g": nil, "ctrl+opt+p": "find", "ctrl+opt+cmd+f1": "find mail inbox"]
    let (bindings, problems) = KeyBindings.effective(settings: settings)
    #expect(KeyBindings.label(for: .find(nil), in: bindings) == "⌃⌥P")
    #expect(KeyBindings.label(for: .find("mail inbox"), in: bindings) == "⌃⌥⌘F1")
    #expect(problems.isEmpty)
  }
}
