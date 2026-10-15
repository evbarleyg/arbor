import ArborCore
import ArborIPC
@testable import ArborKit
import ArborTesting
import CoreGraphics
import Foundation
import Testing

/// The menu lists every open window (docs/MENU.md, Windows ▸; Controller+OpenWindows.swift): what is open, in the order of use, with a mark
/// for what cannot be seen, and a click ends with the window in front and whole.
@Suite @MainActor struct OpenWindowsTests {
  /// Safari | Notes over Mail, two halves, with Terminal floating over the middle. Nobody has had the keyboard yet.
  func desk(settings: Settings = Settings()) -> (Harness, safari: WindowID, notes: WindowID, mail: WindowID, terminal: WindowID) {
    let (safari, notes, mail, terminal) = (WindowID(101), WindowID(102), WindowID(103), WindowID(104))
    var tree = LayoutTree()
    tree.dock(safari, beside: tree.root, edge: .left)
    let right = tree.dock(notes, beside: tree.root, edge: .right)
    tree.dock(mail, beside: right, edge: .bottom)
    let display = FakeWindowSystem.standardDisplay.id
    let h = Harness(settings: settings, saved: PersistedState(workspaces: [display: Workspace(tree: tree)], hints: [:]))
    h.system.open(app: "Safari", title: "Arbor docs", pid: 11, frame: CGRect(x: 100, y: 100, width: 600, height: 400))
    h.system.open(app: "Notes", title: "Shopping", pid: 12, frame: CGRect(x: 300, y: 200, width: 600, height: 400))
    h.system.open(app: "Mail", title: "Inbox", pid: 13, frame: CGRect(x: 500, y: 300, width: 600, height: 400))
    h.system.open(app: "Terminal", title: "zsh", pid: 14, frame: CGRect(x: 560, y: 300, width: 300, height: 200))
    // The keyboard is on the Desktop when Arbor starts, as after a click on the wallpaper: none of the four has had it.
    h.system.userFocusesNothing()
    h.start()
    return (h, safari, notes, mail, terminal)
  }

  /// The rows under Windows ▸, as the menu would show them now.
  func rows(_ h: Harness) -> [MenuModel.Item] {
    h.controller.menuModel().item("Windows")?.sections.flatMap(\.items) ?? []
  }

  func listed(_ h: Harness) -> [WindowID] {
    rows(h).compactMap { if case .reveal(let window) = $0.command { window } else { nil } }
  }

  func row(_ h: Harness, _ window: WindowID) -> MenuModel.Item? { rows(h).first { $0.command == .reveal(window) } }

  /// The person opens the menu and clicks the window's row. Then macOS says what it has to say, and a moment passes.
  /// `prompt`: that a window is back out of the Dock, or with its app, is reported while Arbor is still asking for it. No Mac is
  /// that quick, but where things end must not depend on it.
  @discardableResult
  func click(
    _ h: Harness, _ window: WindowID, prompt: Bool = false, sourceLocation: SourceLocation = #_sourceLocation
  ) -> CommandResult? {
    guard let row = row(h, window), let command = row.command else {
      Issue.record("\(window) is not in the list", sourceLocation: sourceLocation)
      return nil
    }
    #expect(row.isEnabled, "the row of \(window) is grey", sourceLocation: sourceLocation)
    h.system.restoresLate = !prompt
    let result = h.controller.perform(command, from: .menu)
    h.system.deliverEchoes()
    h.system.reportFocus()
    h.system.finishRestoring()
    h.system.restoresLate = false
    h.scheduler.advance(by: 2)
    return result
  }

  func expectInFrontAndWhole(_ h: Harness, _ window: WindowID, sourceLocation: SourceLocation = #_sourceLocation) {
    for words in [["visible", "\(window.rawValue)"], ["focused", "\(window.rawValue)"], ["in-front", "\(window.rawValue)"]] {
      if let problem = ScenarioExpectation.check(words, harness: h, lastCommandOK: true) {
        Issue.record(Comment(rawValue: problem), sourceLocation: sourceLocation)
      }
    }
    let frame = h.system.frame(of: window) ?? .null
    #expect(
      h.system.displayList.contains { $0.visibleFrame.insetBy(dx: -0.5, dy: -0.5).contains(frame) },
      "\(window) at \(frame) is not whole on any display", sourceLocation: sourceLocation)
    #expect(row(h, window)?.note == nil, "its row still says “\(row(h, window)?.note ?? "")”", sourceLocation: sourceLocation)
    #expect(row(h, window)?.isTicked == true, "its row is not ticked", sourceLocation: sourceLocation)
    #expect(listed(h).first == window, "it is not the first of the list", sourceLocation: sourceLocation)
    expectWindowsMatchLayout(h, sourceLocation: sourceLocation)
  }

  // MARK: What is listed, and in which order

  @Test func theListIsWhatIsOpen() {
    let (h, safari, notes, mail, terminal) = desk()
    #expect(Set(listed(h)) == [safari, notes, mail, terminal])
    let music = h.system.open(app: "Music", title: "Library")
    #expect(Set(listed(h)) == [safari, notes, mail, terminal, music])
    h.system.close(notes)
    h.system.close(terminal)
    #expect(Set(listed(h)) == [safari, mail, music])
    #expect(listed(h).count == 3)
  }

  @Test func theOrderIsTheOrderOfUseTheLatestFirst() {
    let (h, safari, notes, mail, terminal) = desk()
    for window in [mail, terminal, safari, notes] { h.system.userFocus(window) }
    #expect(listed(h) == [notes, safari, terminal, mail])
    h.system.userFocus(terminal)
    #expect(listed(h) == [terminal, notes, safari, mail])
  }

  @Test func windowsThatNeverHadTheKeyboardFollowAsTheyAreLaidOut() {
    let (h, safari, notes, mail, terminal) = desk()
    h.system.focused = nil
    h.system.userFocus(mail)
    #expect(listed(h) == [mail, safari, notes, terminal])
  }

  @Test func theWindowWithTheKeyboardIsTickedAndNoOther() {
    let (h, _, notes, _, _) = desk()
    h.system.userFocus(notes)
    #expect(rows(h).filter(\.isTicked).map(\.command) == [.reveal(notes)])
  }

  /// Whatever keeps a window out of sight, it is open, and it keeps its place in the order.
  @Test func whatCannotBeSeenIsListedAllTheSame() {
    let (h, safari, notes, mail, terminal) = desk()
    for window in [terminal, mail, notes, safari] { h.system.userFocus(window) }
    h.run("zoom \(safari.rawValue)")
    h.system.setMinimized(mail, true)
    h.system.setHidden(pid: 12, true)
    #expect(listed(h) == [safari, notes, mail, terminal])
  }

  @Test func windowsArborLeavesAloneComeAfterTheOthers() {
    let (h, safari, notes, mail, terminal) = desk()
    h.system.userFocus(safari)
    h.run("exclude com.example.notes")
    #expect(listed(h) == [safari, mail, terminal, notes])
    // But the one being typed in is the latest in use, whoever arranges it.
    h.system.userFocus(notes)
    #expect(listed(h).first == notes)
    #expect(row(h, notes)?.isTicked == true)
  }

  @Test func windowsOfEveryDisplayAreListed() {
    let side = DisplaySnapshot(
      id: DisplayID("side"), frame: CGRect(x: 1440, y: 0, width: 1280, height: 800),
      visibleFrame: CGRect(x: 1440, y: 25, width: 1280, height: 775), isMain: false, name: "Studio Display")
    let h = Harness(displays: [FakeWindowSystem.standardDisplay, side])
    let here = h.system.open(app: "Safari", frame: CGRect(x: 100, y: 100, width: 600, height: 400))
    let there = h.system.open(app: "Notes", frame: CGRect(x: 1600, y: 100, width: 600, height: 400))
    h.start()
    #expect(Set(listed(h)) == [here, there])
  }

  @Test func arborsOwnWindowsAndThoseAnArborUnderTestIsNotToKnowAreNotListed() {
    let h = Harness()
    let safari = h.system.open(app: "Safari", pid: 11)
    h.system.open(app: "Arbor", title: "Welcome", pid: 1)
    h.system.open(app: "Mail", title: "Private", pid: 12)
    h.controller.filter.onlyPIDs = [11, 1]
    h.start()
    #expect(listed(h) == [safari])
  }

  @Test func withNothingOpenTheRowKeepsItsPlaceAndSaysSo() {
    let h = Harness()
    h.start()
    #expect(rows(h).map(\.title) == ["No Open Windows"])
    #expect(rows(h).allSatisfy { !$0.isEnabled })
  }

  // MARK: What a row reads

  @Test func aRowReadsAppAndTitle() {
    let (h, safari, _, _, terminal) = desk()
    #expect(row(h, safari)?.title == "Safari: Arbor docs")
    #expect(row(h, terminal)?.title == "Terminal: zsh")
    #expect(row(h, safari)?.iconOfProcess == 11)
  }

  @Test func noRowShowsAShortcut() {
    var settings = Settings()
    settings.bindings["ctrl+opt+j"] = "reveal 101"
    let (h, _, _, _, _) = desk(settings: settings)
    #expect(rows(h).allSatisfy { $0.shortcut == nil })
  }

  @Test func theMarkSaysWhatCannotBeSeen() {
    let (h, safari, notes, mail, terminal) = desk()
    #expect(rows(h).allSatisfy { $0.note == nil })
    h.run("zoom \(safari.rawValue)")
    #expect(row(h, safari)?.note == nil)
    #expect(row(h, notes)?.note == "out of view")
    h.run("show-all")
    #expect(rows(h).allSatisfy { $0.note == nil })
    h.system.setMinimized(mail, true)
    #expect(row(h, mail)?.note == "minimized")
    h.system.setHidden(pid: 12, true)
    #expect(row(h, notes)?.note == "hidden")
    h.system.setOnActiveSpace(terminal, false)
    h.scheduler.runPending()
    #expect(row(h, terminal)?.note == "another Space")
    h.system.userFocus(h.system.open(app: "Music"))
    h.system.setFullScreen(safari, true)
    h.scheduler.runPending()
    #expect(row(h, safari)?.note == "full screen")
  }

  /// In view as Arbor counts, and yet beyond the edge of every display with most of it.
  @Test func aFloatingWindowThatIsMostlyBeyondTheEdgeIsOutOfView() {
    let (h, safari, _, _, terminal) = desk()
    h.system.userFocus(safari)
    h.system.userMove(terminal, to: CGRect(x: 1200, y: 300, width: 300, height: 200))
    #expect(row(h, terminal)?.note == nil, "most of it shows")
    h.system.userMove(terminal, to: CGRect(x: 1400, y: 850, width: 300, height: 200))
    #expect(row(h, terminal)?.note == "out of view")
    h.system.userMove(terminal, to: CGRect(x: 5000, y: 3000, width: 300, height: 200))
    #expect(row(h, terminal)?.note == "out of view")
  }

  @Test func theWindowBeingTypedInInFullScreenHasNoMark() {
    let (h, safari, _, _, _) = desk()
    h.system.userFocus(safari)
    h.system.setFullScreen(safari, true)
    h.scheduler.runPending()
    #expect(row(h, safari)?.isTicked == true)
    #expect(row(h, safari)?.note == nil)
  }

  @Test func aTitleThatWasCutIsInTheRowsTooltip() {
    let (h, safari, notes, _, _) = desk()
    h.system.setTitle(safari, String(repeating: "word ", count: 30))
    #expect(row(h, safari)?.help?.hasPrefix("word word") == true)
    #expect(row(h, notes)?.help == nil)
  }

  /// A tile is a window too small to show. Whoever looks for it does not see it, and need not know the word.
  @Test(.withTiles) func aTileIsOutOfView() {
    let (h, _, notes, _, _) = desk()
    let xcode = h.system.open(app: "Xcode", frame: CGRect(x: 400, y: 200, width: 700, height: 500))
    h.system.setMinimumSize(xcode, CGSize(width: 900, height: 600))
    h.run("dock \(xcode.rawValue) beside \(notes.rawValue) bottom")
    // The window with the keyboard is never the tile: its person types in a neighbour and looks at everything again.
    h.system.userFocus(notes)
    h.run("show-all")
    #expect(ScenarioExpectation.check(["tile", "\(xcode.rawValue)"], harness: h, lastCommandOK: true) == nil)
    #expect(row(h, xcode)?.note == "out of view")
  }

  @Test func aWindowLeftAloneIsMarkedWhenMacOSKeepsItOutOfSight() {
    let (h, _, notes, mail, _) = desk()
    h.run("exclude com.example.notes")
    h.run("exclude com.example.mail")
    #expect(row(h, notes)?.note == nil)
    h.system.setMinimized(notes, true)
    h.system.setHidden(pid: 13, true)
    #expect(row(h, notes)?.note == "minimized")
    #expect(row(h, mail)?.note == "hidden")
  }

  /// The number IDEAS I17 is about: how often, over an ordinary day's acts with Arbor as it comes, a row says `out of view`. Nobody sent those
  /// windows away. **It may only fall**: whoever keeps more in view lowers the bound to what they reach.
  @Test func overAnOrdinaryDayFewRowsSayOutOfView() {
    let h = Harness()
    let apps = ["Safari", "Mail", "Notes", "Terminal", "Music", "Calendar"]
    let windows = apps.enumerated().map { index, app in
      h.system.open(app: app, pid: Int32(11 + index), frame: CGRect(x: 80 + 90 * index, y: 60 + 50 * index, width: 640, height: 420))
    }
    h.start()
    var (marked, read) = (0, 0)
    func look() {
      h.scheduler.advance(by: 1)
      marked += rows(h).filter { $0.note == "out of view" }.count
      read += rows(h).count
    }
    func act(_ line: String) {
      #expect(h.run(line, from: .shortcut).ok, "\(line)")
      look()
    }
    look()
    h.system.userFocus(windows[0])
    act("dock left")
    h.system.userFocus(windows[1])
    act("dock right")
    act("zoom")  // fills the screen with Mail
    act("zoom")  // and back
    h.system.userFocus(windows[2])
    look()
    h.system.userFocus(windows[0])
    act("zoom")
    h.system.userFocus(windows[3])  // ⌘Tab to a window that floats
    look()
    act("show-all")
    h.system.setMinimized(windows[4], true)
    look()
    h.system.setHidden(pid: 16, true)
    look()
    h.system.close(windows[1])
    look()
    _ = h.system.open(app: "Preview", pid: 20)
    look()
    act("float-all")
    #expect(read == 83, "the day has changed: count again")
    #expect(marked <= 12, "\(marked) of \(read) rows read said `out of view`")
  }

  // MARK: A click on each kind

  enum Kind: String, CaseIterable, Sendable {
    case dockedInView, dockedUnderAFloatingWindow, dockedOutOfView, tile
    case floating, floatingBehindAnother, floatingOutOfView, floatingOverTheEdge, floatingBeyondEveryDisplay, squeezedOverTheEdge
    case tab, guest
    case floatingOutOfViewOverTheEdge
    case minimizedDocked, minimizedFloating, minimizedWhileFramedElsewhere, minimizedOverTheEdge
    case hiddenDocked, hiddenFloating, hiddenAndMinimized, hiddenOverTheEdge, hiddenWhileFramedElsewhere
    case keptInView, keptInViewOverTheEdge, sentAwayBySummon
    case leftAlone, leftAloneMinimized, leftAloneHidden
  }

  /// What the window's row says before the click: that the story is the story its name tells.
  func markBefore(_ kind: Kind) -> String? {
    switch kind {
    case .dockedInView, .dockedUnderAFloatingWindow, .floating, .floatingBehindAnother, .keptInView, .leftAlone: nil
    // The first three are in view as Arbor counts, with most of them beyond the edge.
    case .squeezedOverTheEdge, .floatingOverTheEdge, .keptInViewOverTheEdge, .dockedOutOfView, .tile, .tab, .guest, .floatingOutOfView, .floatingOutOfViewOverTheEdge, .floatingBeyondEveryDisplay,
      .sentAwayBySummon:
      "out of view"
    case .minimizedDocked, .minimizedFloating, .minimizedWhileFramedElsewhere, .minimizedOverTheEdge, .hiddenAndMinimized,
      .leftAloneMinimized:
      "minimized"
    case .hiddenDocked, .hiddenFloating, .hiddenOverTheEdge, .hiddenWhileFramedElsewhere, .leftAloneHidden: "hidden"
    }
  }

  /// Brings about one window of the kind, with the keyboard elsewhere, and names it.
  func make(_ kind: Kind) -> (Harness, WindowID) {
    let (h, safari, notes, mail, terminal) = desk()
    h.system.userFocus(safari)
    switch kind {
    case .dockedInView:
      return (h, mail)
    case .dockedUnderAFloatingWindow:
      h.system.userMove(terminal, to: CGRect(x: 1000, y: 100, width: 300, height: 200))
      h.system.userFocus(terminal)
      return (h, notes)
    case .dockedOutOfView:
      h.run("zoom \(safari.rawValue)")
      return (h, mail)
    case .tile:
      let xcode = h.system.open(app: "Xcode", frame: CGRect(x: 400, y: 200, width: 700, height: 500))
      h.system.setMinimumSize(xcode, CGSize(width: 900, height: 600))
      h.run("dock \(xcode.rawValue) beside \(notes.rawValue) bottom")
      // The window with the keyboard is never the tile: its person types in a neighbour and looks at everything again.
      h.system.userFocus(notes)
      h.run("show-all")
      h.system.userFocus(safari)
      return (h, xcode)
    case .floating:
      return (h, terminal)
    case .floatingBehindAnother:
      let music = h.system.open(app: "Music", frame: CGRect(x: 520, y: 260, width: 400, height: 300))
      h.system.userFocus(music)
      return (h, terminal)
    case .floatingOutOfView:
      h.run("zoom \(safari.rawValue)")
      return (h, terminal)
    case .floatingOverTheEdge:
      h.system.userMove(terminal, to: CGRect(x: 1300, y: 780, width: 300, height: 200))
      h.system.userFocus(safari)
      return (h, terminal)
    case .floatingBeyondEveryDisplay:
      h.system.userMove(terminal, to: CGRect(x: 5000, y: 3000, width: 300, height: 200))
      h.system.userFocus(safari)
      return (h, terminal)
    case .squeezedOverTheEdge:
      return squeezedOverTheEdge()
    case .tab:
      // Safari behind Notes in one tab group, Mail beside them.
      var tree = LayoutTree()
      let group = tree.dock(safari, beside: tree.root, edge: .left)
      tree.addToStack(notes, leaf: group)
      tree.dock(mail, beside: tree.root, edge: .right)
      let display = FakeWindowSystem.standardDisplay.id
      let tabs = Harness(saved: PersistedState(workspaces: [display: Workspace(tree: tree)], hints: [:]))
      for (index, app) in ["Safari", "Notes", "Mail"].enumerated() { tabs.system.open(app: app, pid: Int32(11 + index)) }
      tabs.start()
      tabs.system.userFocus(mail)
      return (tabs, safari)
    case .guest:
      h.run("zoom \(safari.rawValue)")
      let guest = h.system.open(app: "Preview", frame: CGRect(x: 400, y: 200, width: 500, height: 400))
      h.system.userFocus(guest)
      h.system.userFocus(safari)
      h.run("show-all")
      h.run("zoom \(mail.rawValue)")
      return (h, guest)
    case .floatingOutOfViewOverTheEdge:
      h.system.userMove(terminal, to: CGRect(x: 1300, y: 780, width: 300, height: 200))
      h.system.userFocus(safari)
      h.run("zoom \(safari.rawValue)")
      return (h, terminal)
    case .minimizedOverTheEdge:
      h.system.userMove(terminal, to: CGRect(x: 1300, y: 780, width: 300, height: 200))
      h.system.setMinimized(terminal, true)
      h.system.userFocus(safari)
      return (h, terminal)
    case .hiddenOverTheEdge:
      h.system.userMove(terminal, to: CGRect(x: -200, y: 300, width: 300, height: 200))
      h.system.setHidden(pid: 14, true)
      h.system.userFocus(safari)
      return (h, terminal)
    case .keptInViewOverTheEdge:
      h.run("pin \(terminal.rawValue)")
      h.system.userMove(terminal, to: CGRect(x: 1300, y: 780, width: 300, height: 200))
      h.system.userFocus(safari)
      return (h, terminal)
    case .minimizedDocked:
      h.system.setMinimized(mail, true)
      return (h, mail)
    case .minimizedFloating:
      h.system.setMinimized(terminal, true)
      return (h, terminal)
    case .minimizedWhileFramedElsewhere:
      h.system.setMinimized(mail, true)
      h.run("zoom \(safari.rawValue)")
      return (h, mail)
    case .hiddenDocked:
      h.system.setHidden(pid: 13, true)
      return (h, mail)
    case .hiddenWhileFramedElsewhere:
      h.system.setHidden(pid: 13, true)
      h.run("zoom \(safari.rawValue)")
      return (h, mail)
    case .hiddenFloating:
      h.system.setHidden(pid: 14, true)
      return (h, terminal)
    case .hiddenAndMinimized:
      h.system.setMinimized(mail, true)
      h.system.setHidden(pid: 13, true)
      return (h, mail)
    case .keptInView:
      h.run("pin \(terminal.rawValue)")
      h.system.userFocus(safari)
      h.run("zoom \(safari.rawValue)")
      return (h, terminal)
    case .sentAwayBySummon:
      h.run("summon Terminal")
      h.system.reportFocus()
      h.run("summon Terminal")
      h.system.reportFocus()
      return (h, terminal)
    case .leftAlone:
      h.run("exclude com.example.terminal")
      return (h, terminal)
    case .leftAloneMinimized:
      h.run("exclude com.example.terminal")
      h.system.setMinimized(terminal, true)
      return (h, terminal)
    case .leftAloneHidden:
      h.run("exclude com.example.terminal")
      h.system.setHidden(pid: 14, true)
      return (h, terminal)
    }
  }

  /// Mail, 800 by 600, hangs over the left edge; Notes docks at the bottom and Mail is squeezed to what is left above it. Only where floating
  /// windows are set to make way: as Arbor ships, nothing squeezes one.
  func squeezedOverTheEdge(at origin: CGPoint = CGPoint(x: -456, y: 200), docking edge: String = "bottom") -> (Harness, WindowID) {
    let h = Harness(settings: .makingWay)
    let mail = h.system.open(app: "Mail", pid: 11, frame: CGRect(x: 100, y: 100, width: 800, height: 600))
    let notes = h.system.open(app: "Notes", pid: 12, frame: CGRect(x: 300, y: 200, width: 800, height: 600))
    h.start()
    h.system.userMove(mail, to: CGRect(origin: origin, size: CGSize(width: 800, height: 600)))
    h.run("dock \(notes.rawValue) \(edge)")
    h.system.userFocus(notes)
    return (h, mail)
  }

  @Test(.withTiles, arguments: Kind.allCases, [false, true]) func aClickEndsWithTheWindowInFrontAndWhole(kind: Kind, prompt: Bool) {
    let (h, window) = make(kind)
    h.scheduler.advance(by: 2)
    #expect(h.system.focusedWindow() != window, "the story is about a window that has not got the keyboard")
    #expect(row(h, window)?.note == markBefore(kind), "and about one of this kind")
    #expect(click(h, window, prompt: prompt)?.ok == true)
    expectInFrontAndWhole(h, window)
  }

  /// Rule 3: a window moves once, to where it ends up.
  @Test(arguments: Kind.allCases) func nothingIsSeenToMoveTwice(kind: Kind) {
    let (h, window) = make(kind)
    h.scheduler.advance(by: 2)
    let mark = h.system.moveLog.count
    click(h, window)
    #expect(h.system.jolts(since: mark) == [])
  }

  /// A docked window that went to the Dock in view, or was hidden with its app, and is asked back while the view is elsewhere: in both
  /// orders. In the order a Mac reports in, the view waits for the window, so no neighbour fills the screen until it lands. Told at
  /// once that it is back, the view goes first, so the window is not sent to the corner and fetched (Controller+OneLayout.swift).
  @Test(arguments: [Kind.minimizedWhileFramedElsewhere, .hiddenWhileFramedElsewhere], [false, true])
  func aWindowAskedBackWhileTheViewIsElsewhereMovesOnce(kind: Kind, prompt: Bool) {
    let (h, window) = make(kind)
    h.scheduler.advance(by: 2)
    let mark = h.system.moveLog.count
    click(h, window, prompt: prompt)
    #expect(h.system.jolts(since: mark) == [])
  }

  /// A size is its person's (Q20): a click fetches a floating window, it does not shape it.
  @Test(arguments: [
    Kind.floating, .floatingBehindAnother, .floatingOutOfView, .floatingOverTheEdge, .floatingOutOfViewOverTheEdge, .minimizedFloating,
    .floatingBeyondEveryDisplay, .squeezedOverTheEdge,
    .minimizedOverTheEdge, .hiddenFloating, .hiddenOverTheEdge, .keptInView, .keptInViewOverTheEdge,
  ])
  func aFloatingWindowKeepsItsSize(kind: Kind) {
    let (h, window) = make(kind)
    let size = h.system.frame(of: window)?.size
    click(h, window)
    #expect(h.system.frame(of: window)?.size == size)
  }

  /// Rule 5: what docked windows squeezed gets its own size back, click or no click. What is remembered goes the way the window went.
  @Test(arguments: ["float-all", "pause", "quit"]) func aSqueezedWindowStillGetsItsOwnSizeBack(wayOut: String) {
    func end(clicking: Bool) -> CGRect? {
      let (h, mail) = squeezedOverTheEdge()
      #expect(h.system.frame(of: mail)?.height ?? 600 < 600, "it is squeezed, or this proves nothing")
      if clicking { click(h, mail) }
      if wayOut == "quit" { h.controller.shutdown() } else { h.run(wayOut) }
      h.scheduler.advance(by: 2)
      return h.system.frame(of: mail)
    }
    #expect(end(clicking: true) == CGRect(x: 0, y: 200, width: 800, height: 600), "where the click brought it, the shortest way in")
    // What is found counts as left: nobody asked for it, so it is given back where its person parked it.
    #expect(end(clicking: false) == CGRect(x: -456, y: 200, width: 800, height: 600))
    // Over each edge and a corner, with the docked window at each side: the size is its own again.
    for origin in [CGPoint(x: -456, y: 200), CGPoint(x: 1100, y: 200), CGPoint(x: 300, y: 600), CGPoint(x: 1100, y: 600)] {
      for edge in ["left", "right", "top", "bottom"] {
        let (h, mail) = squeezedOverTheEdge(at: origin, docking: edge)
        click(h, mail)
        if wayOut == "quit" { h.controller.shutdown() } else { h.run(wayOut) }
        h.scheduler.advance(by: 2)
        #expect(h.system.frame(of: mail)?.size == CGSize(width: 800, height: 600), "from \(origin), docked \(edge)")
      }
    }
  }

  /// Where Arbor fitted a window because the displays had changed it keeps a note, to send the window back once they are as they were. Asked
  /// for, the window is where its person wanted it, and the shortest way in can end at the very frame of the note.
  @Test func aWindowThatWasFittedAndIsThenAskedForHasNothingToGoBackTo() {
    func display(_ width: CGFloat, _ height: CGFloat) -> DisplaySnapshot {
      DisplaySnapshot(
        id: DisplayID("main"), frame: CGRect(x: 0, y: 0, width: width, height: height),
        visibleFrame: CGRect(x: 0, y: 25, width: width, height: height - 25), isMain: true, isBuiltIn: true)
    }
    let h = Harness(displays: [display(1440, 900)], settings: Settings())
    let safari = h.system.open(app: "Safari", pid: 11, frame: CGRect(x: 100, y: 100, width: 800, height: 600))
    let mail = h.system.open(app: "Mail", pid: 12, frame: CGRect(x: 1000, y: 300, width: 400, height: 300))
    h.start()
    h.run("dock \(safari.rawValue) left")
    h.run("zoom \(safari.rawValue)")
    h.system.setDisplays([display(1024, 768)])
    h.run("show-all")
    let fitted = CGRect(x: 624, y: 300, width: 400, height: 300)
    #expect(h.frame(mail) == fitted && h.controller.fittedFrames[mail] == fitted, "it was fitted, or this proves nothing")
    h.system.userMove(mail, to: fitted.offsetBy(dx: 250, dy: 0))
    h.system.userFocus(safari)
    #expect(click(h, mail)?.ok == true)
    #expect(h.frame(mail) == fitted)
    #expect(h.controller.fittedFrames[mail] == nil)
    // And with the display as it was, it stays where it was asked to.
    h.system.setDisplays([display(1440, 900)])
    h.scheduler.advance(by: 3)
    #expect(h.frame(mail) == fitted)
  }

  nonisolated static let side = DisplaySnapshot(
    id: DisplayID("side"), frame: CGRect(x: 1440, y: 0, width: 1920, height: 1080),
    visibleFrame: CGRect(x: 1440, y: 25, width: 1920, height: 1055), isMain: false, name: "Studio Display")

  /// Arbor picks no size for a floating window (Q20), not even to show all of it: the corner with the title bar comes in. And it stays so
  /// through the layouts that follow: a layout fits what nobody chose, and this its person asked for.
  @Test(arguments: [CGSize(width: 1600, height: 600), CGSize(width: 800, height: 1000), CGSize(width: 1600, height: 1000)])
  func aWindowLargerThanItsDisplayIsMovedAndNeverSized(size: CGSize) {
    let h = Harness()
    let safari = h.system.open(app: "Safari", pid: 11, frame: CGRect(x: 100, y: 100, width: 800, height: 600))
    let mail = h.system.open(app: "Mail", pid: 12, frame: CGRect(x: 200, y: 200, width: 400, height: 300))
    h.start()
    h.system.userMove(safari, to: CGRect(origin: CGPoint(x: -300, y: 130), size: size))
    h.system.userFocus(mail)
    let mark = h.system.moveLog.count
    #expect(click(h, safari)?.ok == true)
    let fetched = h.system.frame(of: safari)
    #expect(fetched?.size == size)
    #expect(fetched?.minX == 0 && (fetched?.minY ?? 0) >= 25, "the corner with the title bar is in view")
    #expect(h.system.focusedWindow() == safari)
    // Again, and nothing moves: it is as far in as it goes.
    h.system.userFocus(mail)
    click(h, safari)
    #expect(h.system.moveLog[mark...].filter { $0.before != $0.after }.count == 1)
    for line in ["relayout", "dock \(mail.rawValue) left", "float \(mail.rawValue)", "relayout"] {
      h.run(line)
      h.scheduler.advance(by: 1)
    }
    #expect(h.system.frame(of: safari)?.size == size, "after the layouts that follow")
  }

  /// It comes onto the display it belongs to, and goes on coming and going with that display's view and no other's.
  @Test func withTwoDisplaysItIsFetchedOntoTheOneItBelongsTo() {
    let h = Harness(displays: [FakeWindowSystem.standardDisplay, Self.side])
    let mail = h.system.open(app: "Mail", pid: 11, frame: CGRect(x: 100, y: 100, width: 800, height: 600))
    let notes = h.system.open(app: "Notes", pid: 12, frame: CGRect(x: 200, y: 200, width: 400, height: 300))
    h.start()
    // Its middle is on the main display; the other shows more of it; a third of it is below both.
    h.system.userMove(mail, to: CGRect(x: 1000, y: 500, width: 800, height: 600))
    h.system.userFocus(notes)
    #expect(h.controller.workspaceID(containing: mail) == h.display)
    #expect(click(h, mail)?.ok == true)
    let fetched = h.system.frame(of: mail)
    #expect(fetched == CGRect(x: 640, y: 300, width: 800, height: 600))
    #expect(h.controller.workspaceID(containing: mail) == h.display)
    expectInFrontAndWhole(h, mail)
  }

  /// The displays show all of it between them: whole, as everywhere else in Arbor, unmarked and let be.
  @Test func aWindowThatLiesAcrossTwoDisplaysIsLetBe() {
    let h = Harness(displays: [FakeWindowSystem.standardDisplay, Self.side])
    let mail = h.system.open(app: "Mail", pid: 11, frame: CGRect(x: 100, y: 100, width: 800, height: 600))
    let notes = h.system.open(app: "Notes", pid: 12, frame: CGRect(x: 200, y: 200, width: 400, height: 300))
    h.start()
    h.system.userMove(mail, to: CGRect(x: 1040, y: 200, width: 800, height: 600))
    h.system.userFocus(notes)
    #expect(row(h, mail)?.note == nil)
    let mark = h.system.moveLog.count
    #expect(click(h, mail)?.ok == true)
    #expect(h.system.moveLog[mark...].filter { $0.before != $0.after }.isEmpty)
    #expect(h.system.focusedWindow() == mail)
    // Less than half on each, more than half on both together: a person sees it.
    h.system.userMove(mail, to: CGRect(x: 1040, y: 500, width: 800, height: 600))
    h.system.userFocus(notes)
    #expect(row(h, mail)?.note == nil)
  }

  @Test func aWindowOnTheOtherDisplayIsFetchedThere() {
    let side = DisplaySnapshot(
      id: DisplayID("side"), frame: CGRect(x: 1440, y: 0, width: 1280, height: 800),
      visibleFrame: CGRect(x: 1440, y: 25, width: 1280, height: 775), isMain: false, name: "Studio Display")
    let h = Harness(displays: [FakeWindowSystem.standardDisplay, side])
    let here = h.system.open(app: "Safari", pid: 11, frame: CGRect(x: 100, y: 100, width: 600, height: 400))
    let there = h.system.open(app: "Notes", pid: 12, frame: CGRect(x: 1600, y: 100, width: 600, height: 400))
    let far = h.system.open(app: "Mail", pid: 13, frame: CGRect(x: 2000, y: 300, width: 600, height: 400))
    h.start()
    h.run("dock \(there.rawValue) left")
    h.run("dock \(far.rawValue) right")
    h.run("zoom \(there.rawValue)")
    h.system.userFocus(here)
    #expect(row(h, far)?.note == "out of view")
    #expect(click(h, far)?.ok == true)
    expectInFrontAndWhole(h, far)
    #expect(side.visibleFrame.contains(h.system.frame(of: far) ?? .null))
    #expect(h.system.frame(of: here) == CGRect(x: 100, y: 100, width: 600, height: 400))
  }

  /// What the fetch changed is saved, as after a move by hand.
  @Test func whereItWasFetchedToIsSaved() {
    let (h, terminal) = make(.floatingOverTheEdge)
    h.scheduler.advance(by: 2)
    click(h, terminal)
    #expect(h.store.saved?.workspaces[h.display]?.floating[terminal] == h.system.frame(of: terminal))
  }

  /// Whole already, it stays where it is.
  @Test(arguments: [Kind.floating, .floatingBehindAnother, .dockedInView, .dockedUnderAFloatingWindow, .leftAlone])
  func aWindowThatIsWholeInViewIsNotMoved(kind: Kind) {
    let (h, window) = make(kind)
    h.scheduler.advance(by: 2)
    let mark = h.system.moveLog.count
    click(h, window)
    let moves = h.system.moveLog[mark...].filter { $0.before != $0.after }
    #expect(moves.isEmpty, "\(moves.map(\.window))")
  }

  /// It comes in by the shortest way.
  @Test func aWindowHangingOverTheEdgeComesInByTheShortestWay() {
    let (h, terminal) = make(.floatingOverTheEdge)
    click(h, terminal)
    let visible = h.visibleFrame
    #expect(h.system.frame(of: terminal) == CGRect(x: visible.maxX - 300, y: visible.maxY - 200, width: 300, height: 200))
  }

  /// Not Arbor's to place: it is shown and given the keyboard where it is.
  @Test func aWindowLeftAloneIsNeverMoved() {
    let (h, terminal) = make(.leftAlone)
    h.system.userMove(terminal, to: CGRect(x: 1300, y: 780, width: 300, height: 200))
    h.system.userFocus(WindowID(101))
    let mark = h.system.moveLog.count
    click(h, terminal)
    #expect(h.system.moveLog.count == mark)
    #expect(h.system.focusedWindow() == terminal)
  }

  /// macOS shows these on a Space of their own: Arbor asks for the keyboard, macOS switches, and the view here stays.
  @Test func aWindowInFullScreenOrOnAnotherSpaceIsGivenTheKeyboard() {
    for fullScreen in [true, false] {
      let (h, safari, _, mail, _) = desk()
      h.system.userFocus(safari)
      if fullScreen { h.system.setFullScreen(mail, true) } else { h.system.setOnActiveSpace(mail, false) }
      h.scheduler.advance(by: 2)
      #expect(click(h, mail)?.ok == true)
      #expect(h.system.focusedWindow() == mail)
    }
  }

  @Test func aWindowThatClosedWhileTheMenuWasOpenIsSaidToBeGone() throws {
    let (h, _, _, mail, _) = desk()
    let command = try #require(row(h, mail)?.command)
    h.system.close(mail)
    let mark = h.system.moveLog.count
    #expect(h.controller.perform(command, from: .menu).ok == false)
    #expect(h.system.moveLog.count == mark)
  }

  // MARK: When

  @Test func thereIsNoListWhileArborIsPausedOrWaits() {
    let (h, _, _, _, _) = desk()
    h.run("pause")
    #expect(h.controller.menuModel().item("Windows") == nil)
    h.run("resume")
    #expect(h.controller.menuModel().item("Windows") != nil)
    let starting = Harness()
    starting.system.open(app: "Safari")
    #expect(starting.controller.menuModel().item("Windows") == nil, "not started yet")
    let waiting = Harness()
    waiting.system.open(app: "Safari")
    waiting.controller.accessibilityGranted = false
    #expect(waiting.controller.menuModel().item("Windows") == nil, "no permission")
  }

  /// Nothing moves a held view, and `reveal` is refused: a row that would be is grey, as every such row is. They can still be read.
  @Test func whileTheViewIsHeldTheRowsAreGrey() {
    let (h, safari, _, mail, _) = desk()
    h.system.userFocus(safari)
    h.run("zoom \(safari.rawValue)")
    #expect(h.run("hold").ok)
    #expect(listed(h).count == 4)
    #expect(rows(h).allSatisfy { !$0.isEnabled })
    #expect(h.run("reveal \(mail.rawValue)", from: .menu).ok == false)
    h.run("release")
    #expect(rows(h).allSatisfy { $0.isEnabled })
  }

  /// Holding still, which a call begins by itself, stops what nobody asked for. A click is asking.
  @Test func whileHoldingStillAClickStillFetches() {
    let (h, safari, _, mail, _) = desk()
    h.system.userFocus(safari)
    h.run("zoom \(safari.rawValue)")
    #expect(h.run("hold still").ok)
    #expect(click(h, mail)?.ok == true)
    expectInFrontAndWhole(h, mail)
  }

  // MARK: Titles are shown, never passed on

  private func log() -> String {
    ((try? String(contentsOf: ArborPaths.logFile.appendingPathExtension("1"), encoding: .utf8)) ?? "")
      + ((try? String(contentsOf: ArborPaths.logFile, encoding: .utf8)) ?? "")
  }

  @Test(arguments: CanaryTests.shapes) func aTitleInTheListReachesNeitherTheTraceNorTheLogNorState(words: String) throws {
    let (h, safari, _, _, _) = desk()
    let window = h.system.open(app: "Pages", title: words)
    h.system.userFocus(safari)
    h.run("zoom \(safari.rawValue)")
    h.run("trace on canary")
    // The log is one file for all the shapes: only what is written from here on is this one's.
    let written = log().count
    // It is in the list, or this proves nothing. (Of the longest shapes the word is beyond the cut.)
    #expect(try #require(row(h, window)).title.lowercased().contains(CanaryTests.canary) || words.count > 60)
    h.run("menu")
    click(h, window)
    for line in ["state", "status", "doctor", "ascii"] {
      // All of the reply: `state` answers in a field of its own.
      #expect(!String(describing: h.run(line)).lowercased().contains(CanaryTests.canary), "\(line) names a title")
    }
    #expect(String(describing: h.run("state")).contains("\(window.rawValue)"), "the window is in `state`, or that proves nothing")
    h.run("trace off")
    let trace = try #require(h.lastTrace)
    #expect(trace.contains("reveal \(window.rawValue)"), "the click is in the trace, or that proves nothing")
    #expect(!trace.lowercased().contains(CanaryTests.canary))
    #expect(log().dropFirst(written).contains("reveal \(window.rawValue)"), "and in the log")
    #expect(!log().lowercased().contains(CanaryTests.canary))
  }

  /// What the click answers is shown on screen and written to the log: by number.
  @Test func theAnswerToAClickNamesNoTitle() {
    let (h, _, _, mail, _) = desk()
    let reply = click(h, mail)
    #expect(reply?.message.contains("Inbox") == false)
  }

  /// Go to… reads its commands off the menu, calls each by its way there, and what is chosen there goes into traces. A row of the list would be
  /// called by a title. The windows are in Go to… already, as places.
  @Test func goToHasNoRowOfTheListAmongItsCommands() throws {
    let (h, _, _, mail, _) = desk()
    #expect(listed(h).count == 4, "or this looks at nothing")
    h.run("find")
    let commands = try #require(h.overlays.finder?.model.commands)
    #expect(commands.contains { $0.name == "View ▸ Show the Desktop" }, "rows of submenus are among them, or this proves nothing")
    #expect(!commands.contains { $0.name.hasPrefix("Windows") })
    #expect(!commands.contains { $0.name.contains("Inbox") })
    #expect(!commands.contains { $0.destination == .command("reveal \(mail.rawValue)") })
  }
}
