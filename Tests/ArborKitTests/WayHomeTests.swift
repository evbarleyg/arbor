import ArborCore
import ArborKit
import ArborTesting
import CoreGraphics
import Testing

/// A 1280×800 display to the right of the standard one.
private let side = DisplaySnapshot(
  id: DisplayID("side"), frame: CGRect(x: 1440, y: 0, width: 1280, height: 800),
  visibleFrame: CGRect(x: 1440, y: 0, width: 1280, height: 800), isMain: false)

/// There is always an obvious way back: `home`, `float-all`, and the frame shortcut pressed again.
@Suite @MainActor struct WayHomeTests {
  /// Two windows docked on each of two displays, each display framed on one of them.
  func twoDisplays() -> (Harness, [WindowID]) {
    let h = Harness(displays: [FakeWindowSystem.standardDisplay, side])
    let a = h.system.open(app: "Safari", frame: CGRect(x: 100, y: 100, width: 500, height: 400))
    let b = h.system.open(app: "Mail", frame: CGRect(x: 300, y: 150, width: 500, height: 400))
    let c = h.system.open(app: "Notes", frame: CGRect(x: 1600, y: 100, width: 500, height: 400))
    let d = h.system.open(app: "Slack", frame: CGRect(x: 1800, y: 150, width: 500, height: 400))
    h.start()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) right")
    h.run("dock \(c.rawValue) left")
    h.run("dock \(d.rawValue) right")
    h.run("zoom \(a.rawValue)")
    h.run("zoom \(c.rawValue)")
    return (h, [a, b, c, d])
  }

  /// [a | Desktop | b / c] on one display, showing everything.
  func nested() -> (Harness, WindowID, WindowID, WindowID) {
    let h = Harness()
    let a = h.system.open(app: "Safari")
    let b = h.system.open(app: "Mail")
    let c = h.system.open(app: "Notes")
    h.start()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) right")
    h.run("dock \(c.rawValue) beside \(b.rawValue) bottom")
    return (h, a, b, c)
  }

  // MARK: home

  @Test func homeShowsEverythingOnEveryDisplay() {
    let (h, windows) = twoDisplays()
    #expect(!h.system.isVisible(windows[1]) && !h.system.isVisible(windows[3]))
    h.system.cursor = CGPoint(x: 200, y: 200)

    let result = h.run("home")
    #expect(result.ok)
    #expect(result.message == "showing everything on every display")
    for (id, workspace) in h.controller.workspaces { #expect(workspace.camera == workspace.tree.root, "\(id)") }
    for window in windows { #expect(h.system.isVisible(window), "\(window)") }
  }

  @Test func showAllStillActsOnThePointersDisplayOnly() {
    let (h, windows) = twoDisplays()
    h.system.cursor = CGPoint(x: 200, y: 200)
    h.run("show-all")
    #expect(h.system.isVisible(windows[1]))
    #expect(!h.system.isVisible(windows[3]))
  }

  @Test func homeCanBeUndoneWithBack() {
    let (h, _, _, c) = nested()
    h.run("zoom \(c.rawValue)")
    #expect(h.run("home").message == "showing everything")
    #expect(h.run("back").ok)
    #expect(h.workspace.camera == h.workspace.tree.leaf(containing: c))
  }

  // MARK: float-all

  @Test func floatAllReturnsEveryDisplayToANormalMac() {
    let (h, windows) = twoDisplays()
    h.system.cursor = CGPoint(x: 200, y: 200)
    let result = h.run("float-all")
    #expect(result.message == "floated 4 windows")
    for workspace in h.controller.workspaces.values { #expect(workspace.tree.allWindows.isEmpty) }
    for window in windows { #expect(h.system.isVisible(window), "\(window)") }
    #expect(h.controller.parked.isEmpty)
    #expect(!h.run("float-all").ok, "nothing is left to float")
  }

  @Test func floatAllHereLeavesTheOtherDisplayAsItWas() {
    let (h, windows) = twoDisplays()
    let other = h.controller.workspaces[side.id]
    h.system.cursor = CGPoint(x: 200, y: 200)
    #expect(h.run("float-all here").message == "floated 2 windows")
    #expect(h.workspace.tree.allWindows.isEmpty)
    #expect(h.controller.workspaces[side.id] == other)
    #expect(!h.system.isVisible(windows[3]))
    #expect(!h.run("float-all here").ok)
  }

  @Test func arrangeAllDocksEachDisplaysWindowsOnThatDisplay() {
    let (h, windows) = twoDisplays()
    h.run("float-all")
    h.system.cursor = CGPoint(x: 200, y: 200)
    #expect(h.run("arrange all").message == "arranged 4 windows")
    #expect(h.workspace.tree.allWindows.sorted() == [windows[0], windows[1]])
    #expect(h.controller.workspaces[side.id]?.tree.allWindows.sorted() == [windows[2], windows[3]])
    expectWindowsMatchLayout(h, on: h.display)
    expectWindowsMatchLayout(h, on: side.id)
  }

  @Test func arrangeStillActsOnThePointersDisplayOnly() {
    let (h, _) = twoDisplays()
    h.run("float-all")
    h.system.cursor = CGPoint(x: 200, y: 200)
    #expect(h.run("arrange").message == "arranged 2 windows")
    #expect(h.controller.workspaces[side.id]?.tree.allWindows.isEmpty == true)
  }

  // MARK: The frame shortcut pressed again

  @Test func framingTheFocusedWindowAgainReturnsToWhereTheCameraCameFrom() {
    let (h, _, _, c) = nested()
    h.system.userFocus(c)
    #expect(h.run("zoom").ok)
    #expect(h.workspace.camera == h.workspace.tree.leaf(containing: c))
    #expect(h.run("zoom").ok)
    #expect(h.workspace.camera == h.workspace.tree.root, "from the overview, back to the overview, not one level out")
  }

  @Test func afterWalkingToANeighbourFramingAgainStepsOut() {
    let (h, _, b, c) = nested()
    h.run("zoom \(b.rawValue)")
    h.run("neighbor down")
    #expect(h.workspace.camera == h.workspace.tree.leaf(containing: c))
    h.system.userFocus(c)
    h.run("zoom")
    let column = h.workspace.tree.parent(of: h.workspace.tree.leaf(containing: c)!)
    #expect(h.workspace.camera == column, "back would only have framed the previous window")
  }

  @Test func namingTheWindowKeepsZoomIdempotentForScripts() {
    let (h, _, _, c) = nested()
    h.run("zoom \(c.rawValue)")
    #expect(h.run("zoom \(c.rawValue)").ok)
    #expect(h.workspace.camera == h.workspace.tree.leaf(containing: c))
  }

  /// There and back, as for a docked window. For a floating one it is the window that goes, and the view stays (QUESTIONS Q29).
  @Test func framingAFloatingWindowAgainTakesItBack() {
    let (h, _, _, _) = nested()
    let note = h.system.open(app: "Stickies")
    h.system.userFocus(note)
    let had = h.frame(note)
    h.run("zoom")
    #expect(h.controller.isFilled(note) && h.frame(note) != had)
    #expect(h.workspace.camera == h.workspace.tree.root)
    h.run("zoom")
    #expect(h.frame(note) == had)
    #expect(h.workspace.camera == h.workspace.tree.root)
  }

  @Test func withNothingDockedFramingIsHarmless() {
    let h = Harness()
    let a = h.system.open(app: "Safari")
    h.start()
    h.system.userFocus(a)
    #expect(h.run("zoom").ok)
    #expect(h.run("zoom").ok)
    #expect(h.workspace.camera == h.workspace.tree.root)
  }

  // MARK: Default shortcuts

  @Test func theWaysHomeHaveShortcuts() throws {
    func command(_ chord: String) throws -> Command? {
      let chord = try KeyChord(text: chord)
      return KeyBindings.all.first { $0.chord == chord }?.command
    }
    #expect(try command("ctrl+opt+0") == .home)
    #expect(try command("ctrl+opt+shift+f") == .floatAll)
    #expect(try command("ctrl+opt+escape") == .togglePause)
    // `focus <direction>` took these over from `neighbor`, as docs/KEYBOARD.md planned: with no window that way
    // in view it does what `neighbor` does (KeyboardFocusTests.theSameKeysTakeTheSamePathAsNeighbor).
    #expect(try command("ctrl+opt+shift+left") == .focus(.direction(.left)))
    #expect(try command("ctrl+opt+shift+right") == .focus(.direction(.right)))
  }

  @Test func noTwoDefaultsShareAChord() {
    let chords = KeyBindings.all.map(\.chord)
    #expect(Set(chords).count == chords.count)
  }

  /// TrellisWM's published table works unchanged.
  @Test func theTrellisWMTableIsUntouched() throws {
    var table: [(String, Command)] = [
      ("ctrl+opt+space", .showAll), ("ctrl+opt+up", .stepOut), ("ctrl+opt+down", .stepIn),
      ("ctrl+opt+return", .zoom(nil)), ("ctrl+opt+left", .neighbor(.left)), ("ctrl+opt+right", .neighbor(.right)),
      ("ctrl+opt+[", .back), ("ctrl+opt+]", .forward),
    ]
    for n in 1...9 {
      table.append(("ctrl+opt+\(n)", .goToView(n)))
      table.append(("ctrl+opt+shift+\(n)", .saveView(n)))
    }
    for (text, command) in table {
      let chord = try KeyChord(text: text)
      #expect(KeyBindings.all.first { $0.chord == chord }?.command == command, "\(text)")
    }
  }

  @Test func menusShowTheShortFormOfAShortcutThatHasTwo() {
    #expect(KeyBindings.label(for: .neighbor(.left), in: KeyBindings.all) == "⌃⌥←")
    #expect(KeyBindings.label(for: .showAll, in: KeyBindings.all) == "⌃⌥Space")
  }
}

/// Replies name spaces in words a person would use (docs/GLOSSARY.md).
@Suite @MainActor struct ReplyWordingTests {
  func nested() -> (Harness, WindowID, WindowID, WindowID) {
    let h = Harness()
    let a = h.system.open(app: "Safari", title: "Secret plans")
    let b = h.system.open(app: "Mail")
    let c = h.system.open(app: "Notes")
    h.start()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) right")
    h.run("dock \(c.rawValue) beside \(b.rawValue) bottom")
    return (h, a, b, c)
  }

  @Test func cameraRepliesNameWhatIsInView() {
    let (h, a, _, c) = nested()
    h.run("zoom \(c.rawValue)")
    #expect(h.run("out").message.hasPrefix("stepped out to Mail and Notes (n"))
    #expect(h.run("out").message == "stepped out to everything")
    #expect(h.run("back").message.hasPrefix("back to Mail and Notes (n"))
    #expect(h.run("neighbor left").message == "moved to the Desktop")
    #expect(h.run("neighbor left").message.hasPrefix("moved to Safari (n"))
    #expect(h.run("save-view 2").message.hasPrefix("saved view 2: Safari (n"))
    h.run("home")
    #expect(h.run("view 2").message.hasPrefix("view 2: Safari (n"))
    _ = a
  }

  @Test func aBigGroupIsCountedNotListed() {
    let h = Harness()
    let ids = (0..<5).map { h.system.open(app: "App\($0)") }
    h.start()
    h.run("dock \(ids[0].rawValue) left")
    for id in ids.dropFirst() { h.run("dock \(id.rawValue) beside \(ids[0].rawValue) bottom") }
    h.run("zoom \(ids[0].rawValue)")
    #expect(h.run("out").message.hasPrefix("stepped out to 5 windows (n"))
  }

  @Test func onlyWhatCanBeSeenIsNamed() {
    let (h, _, b, c) = nested()
    let d = h.system.open(app: "Slack")
    h.run("dock \(d.rawValue) beside \(c.rawValue) bottom")
    h.run("zoom \(c.rawValue)")
    #expect(h.run("out").message.hasPrefix("stepped out to Mail, Notes and Slack (n"))
    h.system.setMinimized(b, true)
    h.run("zoom \(c.rawValue)")
    #expect(h.run("out").message.hasPrefix("stepped out to Notes and Slack (n"), "Mail is minimized and takes no room")
  }

  @Test func repliesNeverContainWindowTitles() {
    let (h, a, _, _) = nested()
    for text in ["zoom \(a.rawValue)", "out", "in", "back", "forward", "save-view 1", "view 1", "home", "status"] {
      #expect(!h.run(text).message.contains("Secret"), "\(text)")
    }
  }

  @Test func failuresSayWhatToDoNext() {
    let h = Harness()
    let a = h.system.open(app: "Safari")
    h.start()
    #expect(h.run("in").message.contains("drag a window to a screen edge"))
    #expect(h.run("view 3").message.contains("save-view 3"))
    #expect(h.run("dock 999 left").message.contains("no window w999"))
    h.run("exclude com.example.safari")
    #expect(h.run("dock \(a.rawValue) left").message.contains("include com.example.safari"))
    h.run("include com.example.safari")
    h.run("dock \(a.rawValue) left")
    h.run("zoom \(a.rawValue)")
    #expect(h.run("in").message.contains("Safari") && !h.run("in").ok)
  }

  @Test func statusCountsInPlainWords() {
    let (h, _, _, c) = nested()
    _ = h.system.open(app: "Slack")
    #expect(h.run("status").message == "running: 1 display, 3 docked and 1 floating, 0 out of view")
    h.run("zoom \(c.rawValue)")
    #expect(h.run("status").message == "running: 1 display, 3 docked and 1 floating, 3 out of view")
  }
}
