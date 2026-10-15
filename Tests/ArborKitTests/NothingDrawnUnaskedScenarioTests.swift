import ArborCore
import ArborKit
import ArborTesting
import CoreGraphics
import Foundation
import Testing

/// Arbor does less by itself (collab/IDEAS.md, I20 d and e, I23), played: as it ships nothing is drawn round the focused window, the
/// menu bar item is one icon whatever happens, windows go to their places at once, each once, with no stage over them, and the wallpaper
/// behind them is left as it is.
/// Each is an option still, and a Mac that has run the first build gets the new defaults unless somebody there chose otherwise.
@Suite @MainActor struct NothingDrawnUnaskedScenarioTests {
  typealias Folder = SettingsFileTests.Folder

  /// Three windows, none docked.
  func makeHarness(settings: Settings = Settings()) -> (Harness, WindowID, WindowID, WindowID) {
    let h = Harness(settings: settings)
    let a = h.system.open(app: "Safari", frame: CGRect(x: 100, y: 100, width: 600, height: 400))
    let b = h.system.open(app: "Notes", frame: CGRect(x: 300, y: 200, width: 600, height: 400))
    let c = h.system.open(app: "Mail", frame: CGRect(x: 500, y: 300, width: 600, height: 400))
    h.start()
    return (h, a, b, c)
  }

  /// A short day: docks, moves of the view, a saved view, a close. After each step `check` looks at what there is to see.
  func day(_ h: Harness, _ a: WindowID, _ b: WindowID, _ c: WindowID, check: (String) -> Void) {
    check("at the start")
    for step in [
      "dock \(a.rawValue) left", "dock \(b.rawValue) right", "zoom \(a.rawValue)", "save-view 1", "back", "desktop",
      "show-all", "view 1", "show-all", "dock \(c.rawValue) beside \(a.rawValue) bottom", "swap right", "undo", "float \(c.rawValue)", "arrange",
      "hold still", "release", "hold", "release", "pause", "resume",
    ] {
      let mark = h.system.moveLog.count
      let result = h.run(step)
      #expect(result.ok, "\(step): \(result.message)")
      h.scheduler.advance(by: 2)
      #expect(h.system.jolts(since: mark).isEmpty, "\(step): a window moves once")
      check("after `\(step)`")
    }
    h.system.close(b)
    h.scheduler.advance(by: 2)
    check("after a close")
  }

  // MARK: As it ships

  @Test func nothingIsDrawnRoundTheFocusedWindow() {
    let (h, a, b, c) = makeHarness()
    day(h, a, b, c) { when in
      #expect(h.overlays.scenes.values.compactMap(\.focusRing).isEmpty, "\(when)")
    }
  }

  @Test func nothingLiesBehindDockedWindows() {
    let (h, a, b, c) = makeHarness()
    day(h, a, b, c) { when in
      #expect(h.overlays.scenes.values.compactMap(\.backdrop).isEmpty, "\(when)")
    }
  }

  @Test func theMenuBarItemIsOneIconAllDay() {
    let (h, a, b, c) = makeHarness()
    day(h, a, b, c) { when in
      #expect(h.controller.menuBarModel().buttons.isEmpty, "\(when)")
      #expect(h.run("menu-bar").message.hasPrefix("a single icon that opens the menu"), "\(when)")
    }
  }

  @Test func theOneIconStillSaysHowArborIs() {
    // The signs stay, inside the one icon (`MenuBarDrawingTests` holds them to one width).
    let (h, a, _, _) = makeHarness()
    h.run("dock \(a.rawValue) left")
    #expect(h.controller.menuBarModel().icon == MenuBarModel.Icon())
    h.run("hold still")
    #expect(h.controller.menuBarModel().icon == .holdingStill)
    h.run("hold")
    #expect(h.controller.menuBarModel().icon == .held)
    h.run("release")
    h.run("pause")
    #expect(h.controller.menuBarModel().icon == .paused)
  }

  @Test func theMenuGoesOnSayingWhereTheViewIs() {
    // The full menu is built from the buttons' model, whatever the item shows.
    let (h, a, _, _) = makeHarness()
    h.run("dock \(a.rawValue) left")
    #expect(h.controller.menuBarModel(complete: true).buttons.contains { $0.id == .everything && $0.isCurrent })
  }

  @Test func noStageGoesUpAndNoneIsGotReady() {
    let (h, a, b, c) = makeHarness()
    day(h, a, b, c) { when in
      #expect(h.overlays.transitions.isEmpty, "\(when)")
      #expect(h.overlays.rehearsals.allSatisfy { $0.displays.isEmpty }, "\(when): what never plays is not paid for")
    }
  }

  @Test func theFirstTilesFindTheirColoursAndIconsReady() {
    // They wear what a stand-in wears, and there is no stage now to cover the time it takes to make (`RehearsalTests`).
    let (h, _, _, _) = makeHarness()
    h.scheduler.advance(by: 1)
    #expect(Set(h.overlays.rehearsals.flatMap(\.apps).compactMap(\.bundleID)) == ["com.example.safari", "com.example.notes", "com.example.mail"])
    #expect(h.system.moveLog.isEmpty, "and getting them ready touches no window")
  }

  @Test func windowsEndUpWhereTheyDoWithMotion() {
    // The stage only ever showed a journey: the real windows went straight to their places under it.
    let (still, a, b, c) = makeHarness()
    let (moving, _, _, _) = makeHarness(settings: .withMotion)
    var frames: [String: [CGRect?]] = [:]
    day(still, a, b, c) { frames[$0] = [a, b, c].map(still.frame) }
    day(moving, a, b, c) { when in #expect(frames[when] == [a, b, c].map(moving.frame), "\(when)") }
    #expect(still.system.moveLog.count == moving.system.moveLog.count, "and in as many moves")
    expectWindowsMatchLayout(still)
  }

  // MARK: Each is an option

  @Test func theRingIsOneCommandAway() {
    let (h, a, _, _) = makeHarness()
    h.run("dock \(a.rawValue) left")
    #expect(h.run("set focusRing true").ok)
    #expect(h.overlays.scenes[h.display]?.focusRing?.window == a)
    #expect(h.run("reset focusRing").ok)
    #expect(h.overlays.scenes[h.display]?.focusRing == nil)
  }

  @Test func theBackdropIsOneCommandAway() {
    let (h, a, _, _) = makeHarness()
    h.run("dock \(a.rawValue) left")
    #expect(h.run("set dimBehindArranged 0.25").ok)
    #expect(h.overlays.scenes[h.display]?.backdrop?.dim == 0.25)
    #expect(h.overlays.scenes[h.display]?.backdrop?.desktop == nil, "the darkening alone brings no line round the Desktop")
    #expect(h.run("set desktopEdge 0.05").ok)
    #expect(h.overlays.scenes[h.display]?.backdrop?.desktop == h.layout?.desktopFrame)
    #expect(h.run("reset dimBehindArranged").ok)
    #expect(h.overlays.scenes[h.display]?.backdrop?.dim == 0, "the line is still asked for")
    #expect(h.run("reset desktopEdge").ok)
    #expect(h.overlays.scenes[h.display]?.backdrop == nil)
  }

  @Test func theButtonsAreOneCommandAway() {
    let (h, a, _, _) = makeHarness()
    h.run("dock \(a.rawValue) left")
    #expect(h.run("set menuBarControls true").ok)
    #expect(h.controller.menuBarModel().buttons.map(\.id) == [.back, .forward, .desktop, .everything, .menu])
    #expect(h.run("reset menuBarControls").ok)
    #expect(h.controller.menuBarModel().buttons.isEmpty)
  }

  @Test func theMotionIsOneCommandAway() {
    let (h, a, b, _) = makeHarness()
    h.run("dock \(a.rawValue) left")
    #expect(h.run("set animationDuration 0.46").ok)
    h.run("dock \(b.rawValue) right")
    #expect(h.overlays.transitions.last?.duration == 0.46)
    h.overlays.clearTransitions()
    #expect(h.run("reset animationDuration").ok)
    h.run("zoom")
    #expect(h.overlays.transitions.isEmpty)
  }

  // MARK: On a Mac that has run the first build (collab/QUESTIONS.md, Q27)

  /// The file the first build's first launch wrote, all of it: only a whole one is taken for that build's.
  static let untouched = Settings.fileOfTheFirstBuild()

  /// A launch on `folder`'s file, wired as the app wires it, and one dock.
  func launch(_ folder: Folder) -> (Harness, WindowID, WindowID) {
    let file = folder.file
    let h = Harness(settings: SettingsFile.load(from: file))
    h.controller.saveSettings = { try SettingsFile.update(from: $0, to: $1, at: file) }
    h.controller.loadSettings = { try SettingsFile.read(from: file) }
    let a = h.system.open(app: "Safari", frame: CGRect(x: 100, y: 100, width: 600, height: 400))
    let b = h.system.open(app: "Notes", frame: CGRect(x: 300, y: 200, width: 600, height: 400))
    h.start()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) right")
    return (h, a, b)
  }

  @Test func aFileThatNeverTouchedThemGetsLess() throws {
    let folder = try Folder()
    try folder.write(Self.untouched)
    let (h, _, _) = launch(folder)
    #expect(h.controller.settings == Settings())
    #expect(h.overlays.scenes.values.compactMap(\.focusRing).isEmpty)
    #expect(h.controller.menuBarModel().buttons.isEmpty)
    #expect(h.overlays.transitions.isEmpty)
    #expect(h.overlays.scenes.values.compactMap(\.backdrop).isEmpty)
    #expect(try JSONText(try folder.read()).keys(at: []) == ["format"], "nothing in it was anybody's choice")
  }

  @Test func aFileThatSetThemKeepsItsOwn() throws {
    // Whoever made the motion slower wanted motion. The line's width was chosen too, and waits for the line.
    let folder = try Folder()
    try folder.write(Settings.fileOfTheFirstBuild(["animationDuration": "0.8", "focusRingWidth": "6", "dimBehindArranged": "0.4"]))
    let (h, _, b) = launch(folder)
    #expect(h.overlays.transitions.last?.duration == 0.8)
    #expect(h.overlays.scenes[h.display]?.backdrop?.dim == 0.4)
    #expect(h.overlays.scenes.values.compactMap(\.focusRing).isEmpty)
    #expect(h.run("set focusRing true").ok)
    #expect(h.overlays.scenes[h.display]?.focusRing?.window == b)
    #expect(h.overlays.scenes[h.display]?.focusRing?.width == 6)
    #expect(try JSONText(try folder.read()).keys(at: []) == ["animationDuration", "dimBehindArranged", "focusRingWidth", "format", "focusRing"])
  }

  @Test func whoeverHadSwitchedThemOffFindsNothingChanged() throws {
    let folder = try Folder()
    try folder.write(Settings.fileOfTheFirstBuild(["animationDuration": "0", "focusRing": "false", "menuBarControls": "false"]))
    let (h, _, _) = launch(folder)
    #expect(h.controller.settings == Settings())
    #expect(try JSONText(try folder.read()).keys(at: []) == ["animationDuration", "focusRing", "menuBarControls", "format"])
  }

  @Test func whatIsSwitchedOnNowIsStillOnAtTheNextLaunch() throws {
    let folder = try Folder()
    try folder.write(Self.untouched)
    let (first, _, _) = launch(folder)
    for command in ["set focusRing true", "set menuBarControls true", "set animationDuration 0.46"] { #expect(first.run(command).ok) }
    let (second, _, b) = launch(folder)
    #expect(second.overlays.scenes[second.display]?.focusRing?.window == b)
    #expect(!second.controller.menuBarModel().buttons.isEmpty)
    #expect(second.overlays.transitions.last?.duration == 0.46)
  }
}
