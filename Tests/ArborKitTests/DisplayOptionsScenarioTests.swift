import ArborCore
import ArborIPC
import ArborKit
import ArborTesting
import CoreGraphics
import Foundation
import Testing

/// A laptop's own 1440×900 display with a 25-point menu bar, and a 2560×1440 display to its right.
private let laptop = DisplaySnapshot(
  id: DisplayID("main"), frame: CGRect(x: 0, y: 0, width: 1440, height: 900),
  visibleFrame: CGRect(x: 0, y: 25, width: 1440, height: 875), isMain: true, name: "Built-in Retina Display",
  isBuiltIn: true)
private let studio = DisplaySnapshot(
  id: DisplayID("4C7A5B0E-9F2D-4B41-8E55-1A2B3C4D5E6F"), frame: CGRect(x: 1440, y: 0, width: 2560, height: 1440),
  visibleFrame: CGRect(x: 1440, y: 0, width: 2560, height: 1440), isMain: false, name: "Studio Display")

/// Per-display options (docs/features/F25-per-display-options.md) on two displays of different sizes.
@Suite @MainActor struct DisplayOptionsScenarioTests {
  /// Two windows on each display, floating; general gap 12, 6 on the laptop, 20 and larger tiles on the big one.
  func makeHarness(_ displays: [DisplayOptions]? = nil) -> (Harness, [WindowID], [WindowID]) {
    var settings = Settings()
    settings.displays =
      displays ?? [
        DisplayOptions(match: .builtIn, gap: 6),
        DisplayOptions(match: .width(.atLeast, 2500), gap: 20, minimumUsableWidth: 700, minimumUsableHeight: 400),
      ]
    let h = Harness(displays: [laptop, studio], settings: settings)
    let small = [
      h.system.open(app: "Safari", frame: CGRect(x: 100, y: 100, width: 500, height: 400)),
      h.system.open(app: "Notes", frame: CGRect(x: 300, y: 200, width: 500, height: 400)),
    ]
    let large = [
      h.system.open(app: "Xcode", frame: CGRect(x: 1600, y: 100, width: 500, height: 400)),
      h.system.open(app: "Mail", frame: CGRect(x: 1800, y: 200, width: 500, height: 400)),
    ]
    h.start()
    return (h, small, large)
  }

  func pointAt(_ h: Harness, _ display: DisplaySnapshot) { h.system.cursor = display.frame.center }

  @Test func eachDisplayIsLaidOutWithItsOwnGap() {
    let (h, small, large) = makeHarness()
    for window in small + large { h.run("dock \(window.rawValue) left") }
    for (display, windows, gap) in [(laptop, small, CGFloat(6)), (studio, large, CGFloat(20))] {
      let content = display.visibleFrame.insetBy(dx: gap, dy: gap)
      let (second, first) = (h.frame(windows[1])!, h.frame(windows[0])!)
      #expect(second.minX == content.minX && second.minY == content.minY && second.maxY == content.maxY, "\(display.name)")
      #expect(first.minX - second.maxX == gap, "between neighbours on \(display.name)")
      #expect(h.controller.layouts[display.id]!.desktopFrame!.maxX == content.maxX)
      expectWindowsMatchLayout(h, on: display.id)
    }
  }

  @Test func framingAWindowLeavesTheDisplaysOwnGapAroundIt() {
    let (h, small, large) = makeHarness()
    h.run("dock \(small[0].rawValue) left")
    h.run("dock \(large[0].rawValue) left")
    h.run("zoom \(small[0].rawValue)")
    h.run("zoom \(large[0].rawValue)")
    #expect(h.frame(small[0]) == laptop.visibleFrame.insetBy(dx: 6, dy: 6))
    #expect(h.frame(large[0]) == studio.visibleFrame.insetBy(dx: 20, dy: 20))
    #expect(ScenarioExpectation.check(["fills", "\(small[0].rawValue)"], harness: h, lastCommandOK: true) == nil)
    #expect(ScenarioExpectation.check(["fills", "\(large[0].rawValue)"], harness: h, lastCommandOK: true) == nil)
  }

  @Test func tilesStartAtTheDisplaysOwnSize() {
    let (h, small, large) = makeHarness()
    // Three columns: about 470 points each on the laptop, about 830 on the large display.
    for window in small + large { h.run("dock \(window.rawValue) left") }
    #expect(h.controller.layouts[laptop.id]!.tiles.isEmpty, "470 is plenty where the limit is 240")
    #expect(h.controller.layouts[studio.id]!.tiles.isEmpty, "830 is enough where it is 700")
    // A fourth: about 620 each.
    let extra = h.system.open(app: "Terminal", frame: CGRect(x: 2000, y: 300, width: 500, height: 400))
    h.run("dock \(extra.rawValue) left")
    let tiles = h.controller.layouts[studio.id]!.tiles
    #expect(tiles.count == 4, "a size that would be fine on the laptop is a tile here")
    #expect(tiles.allSatisfy { $0.frame.width > 240 && $0.frame.width < 700 })
  }

  @Test func theDropPreviewIsTheResultOnEitherDisplay() {
    let (h, small, large) = makeHarness()
    for (display, window, gap) in [(laptop, small[0], CGFloat(6)), (studio, large[0], CGFloat(20))] {
      let edge = CGPoint(x: display.visibleFrame.minX + 2, y: display.visibleFrame.midY)
      h.system.tiling = .off  // the screen's edges are Arbor's only with macOS's tiling off
      h.system.drag(window, through: [h.frame(window)!.center, display.frame.center, edge])
      let preview = h.overlays.previewHistory.compactMap { $0 }.last
      #expect(preview == h.frame(window), "\(display.name)")
      #expect(h.frame(window)!.minX == display.visibleFrame.minX + gap)
    }
  }

  @Test func aWindowDraggedToTheOtherDisplayTakesThatDisplaysGap() {
    let (h, small, _) = makeHarness()
    h.run("dock \(small[0].rawValue) left")
    #expect(h.frame(small[0])!.minX == 6)
    h.system.tiling = .off  // the screen's edges are Arbor's only with macOS's tiling off
    h.system.drag(
      small[0], through: [h.frame(small[0])!.center, studio.frame.center, CGPoint(x: studio.frame.maxX - 2, y: 700)])
    #expect(h.controller.workspaces[studio.id]!.isDocked(small[0]))
    #expect(h.frame(small[0])!.maxX == studio.visibleFrame.maxX - 20)
    #expect(h.frame(small[0])!.minY == studio.visibleFrame.minY + 20)
  }

  @Test func theScreenEdgeBandIsTheDisplaysOwn() {
    let (h, small, large) = makeHarness([DisplayOptions(match: .named("Studio"), screenEdgeBand: 40)])
    // Thirty points from the left edge: inside the band on one display, outside it on the other.
    for (display, window, docks) in [(laptop, small[0], false), (studio, large[0], true)] {
      let point = CGPoint(x: display.visibleFrame.minX + 30, y: display.visibleFrame.midY)
      h.system.tiling = .off  // the screen's edges are Arbor's only with macOS's tiling off
      h.system.drag(window, through: [h.frame(window)!.center, display.frame.center, point])
      #expect(h.controller.workspaces[display.id]!.isDocked(window) == docks, "\(display.name)")
    }
  }

  /// The two windows of the large display docked, by an Arbor that did not remember where they had floated (before F48). Only
  /// such windows are let go of in their slots; the others go back to where they floated.
  func relaunchedWithNothingRemembered() throws -> (Harness, [WindowID]) {
    let (old, _, large) = makeHarness()
    pointAt(old, studio)
    old.run("dock \(large[0].rawValue) left")
    old.run("dock \(large[1].rawValue) right")
    old.controller.saveNow()
    let written = try JSONEncoder().encode(try #require(old.store.saved))
    var object = try #require(JSONSerialization.jsonObject(with: written) as? [String: Any])
    var workspaces = try #require(object["workspaces"] as? [String: Any])
    var workspace = try #require(workspaces[studio.id.rawValue] as? [String: Any])
    #expect(workspace.removeValue(forKey: "undockedFrames") != nil)
    workspaces[studio.id.rawValue] = workspace
    object["workspaces"] = workspaces
    let saved = try JSONDecoder().decode(PersistedState.self, from: JSONSerialization.data(withJSONObject: object))
    let h = Harness(displays: [laptop, studio], settings: old.controller.settings, saved: saved)
    for window in old.system.allWindows() {
      h.system.open(app: window.appName, bundleID: window.bundleID, title: window.title, pid: window.pid, frame: window.frame)
    }
    h.start()
    pointAt(h, studio)
    return (h, large)
  }

  @Test func floatAllAndQuittingUseTheDisplaysOwnGap() throws {
    for leave in ["float-all", "quit"] {
      let (h, large) = try relaunchedWithNothingRemembered()
      let slots = h.controller.layouts[studio.id]!.windowFrames
      #expect(slots[large[0]]?.minX == studio.visibleFrame.minX + 20)
      h.run("zoom \(large[0].rawValue)")
      if leave == "quit" { h.controller.shutdown() } else { h.run(leave) }
      #expect(h.frame(large[0]) == slots[large[0]], "\(leave): where it sat when everything was in view")
      #expect(h.frame(large[1]) == slots[large[1]], "\(leave)")
    }
  }

  @Test func reloadingSettingsLaysEachDisplayOutAgain() {
    let (h, small, large) = makeHarness()
    h.run("dock \(small[0].rawValue) left")
    h.run("dock \(large[0].rawValue) left")
    var edited = h.controller.settings
    edited.displays = [DisplayOptions(match: .named(studio.id.rawValue), gap: 40)]
    h.controller.loadSettings = { edited }
    #expect(h.run("reload-settings").ok)
    #expect(h.frame(small[0])!.minX == 12, "no entry matches the laptop any more: the general gap")
    #expect(h.frame(large[0])!.minX == studio.visibleFrame.minX + 40)
  }

  @Test func optionsFollowWhatADisplayIsNotWhichOneItWas() {
    let (h, _, large) = makeHarness([DisplayOptions(match: .main, gap: 30)])
    h.run("dock \(large[0].rawValue) left")
    #expect(h.frame(large[0])!.minX == studio.visibleFrame.minX + 12)
    // The lid closes: the large display is the only one, and so the main one.
    var alone = studio
    alone.isMain = true
    alone.frame.origin = .zero
    alone.visibleFrame = CGRect(x: 0, y: 25, width: 2560, height: 1415)
    h.system.setDisplays([alone])
    #expect(h.frame(large[0])!.minX == 30)
    #expect(h.frame(large[0])!.minY == 55)
  }

  @Test func withoutEntriesEveryDisplayUsesTheGeneralSettings() {
    let (h, small, large) = makeHarness([])
    h.run("dock \(small[0].rawValue) left")
    h.run("dock \(large[0].rawValue) left")
    #expect(h.frame(small[0])!.minX == 12)
    #expect(h.frame(large[0])!.minX == studio.visibleFrame.minX + 12)
    #expect(h.controller.options(for: laptop.id) == h.controller.settings)
    #expect(h.controller.options(for: DisplayID("gone")) == h.controller.settings, "a display that is not connected")
  }

  /// Many hands add to the controller. One of them reading `settings.gap` would give one display another's gap in one place only,
  /// which no scenario written for a single display can notice.
  @Test func nothingInTheControllerReadsAPerDisplayOptionFromTheGeneralSettings() throws {
    let folder = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
      .appendingPathComponent("Sources/ArborKit/Controller")
    let keys = ["layoutOptions", "dropOptions", "gap", "minimumUsableWidth", "minimumUsableHeight", "screenEdgeBand"]
    var files = 0
    for name in try FileManager.default.contentsOfDirectory(atPath: folder.path).sorted() where name.hasSuffix(".swift") {
      files += 1
      let text = try String(contentsOf: folder.appendingPathComponent(name), encoding: .utf8)
      for (number, line) in text.split(separator: "\n", omittingEmptySubsequences: false).enumerated() {
        for key in keys {
          // The key as a whole word: `settings.gap`, not `settings.gapHandles`.
          guard let range = line.range(of: "settings.\(key)") else { continue }
          let next = line[range.upperBound...].first
          #expect(
            next.map { $0.isLetter || $0.isNumber } == true,
            "\(name):\(number + 1) reads settings.\(key); on a display it is options(for: displayID).\(key) (Controller+DisplayOptions.swift)")
        }
      }
    }
    #expect(files > 10)
  }

  // MARK: With `set` (F12)

  @Test func setChangesTheGeneralValueAndLeavesTheEntriesAlone() {
    let (h, small, large) = makeHarness([DisplayOptions(match: .builtIn, gap: 6)])
    h.run("dock \(small[0].rawValue) left")
    pointAt(h, studio)
    h.run("dock \(large[0].rawValue) left")
    let reply = h.run("set gap 30")
    #expect(reply.ok)
    #expect(reply.message == "gap = 30 (was 12); Built-in Retina Display keeps 6 (`displays` in settings.json)")
    #expect(h.run("get gap").message == "gap = 30; Built-in Retina Display keeps 6 (`displays` in settings.json)")
    #expect(h.run("get gap").text == "30", "the bare value, for scripts")
    #expect(h.run("set screenEdgeBand 20").message == "screenEdgeBand = 20 (was 12)", "nobody has a band of their own")
    #expect(h.frame(small[0])!.minX == laptop.visibleFrame.minX + 6, "its entry still says 6")
    #expect(h.frame(large[0])!.minX == studio.visibleFrame.minX + 30)
    #expect(h.controller.settings.displays == [DisplayOptions(match: .builtIn, gap: 6)])

    let refused = h.run("set displays []")
    #expect(!refused.ok)
    #expect(refused.message.contains("`displays` shows what is in effect on each display"), "\(refused.message)")
  }

  // MARK: Privacy

  /// A display's name can be a person's ("Somebody's iPad" over Sidecar). Whoever asks is told; the log, which people paste into bug
  /// reports, is not.
  @Test func aDisplaysNameIsNeverLogged() throws {
    let secret = "Ouagadougou\(UInt32.random(in: 0...UInt32.max))"
    var tablet = studio
    tablet.name = "\(secret)'s iPad"
    let json = """
      {"displays": [{"match": "\(secret)", "gap": 20}, {"match": "\(secret)'s", "gap": 500}]}
      """
    let file = FileManager.default.temporaryDirectory.appendingPathComponent("arbor-\(secret).json")
    try Data(json.utf8).write(to: file)
    defer { try? FileManager.default.removeItem(at: file) }
    let settings = SettingsFile.load(from: file)
    #expect(settings.displays.count == 1 && settings.skippedDisplays.count == 1)
    #expect(settings.skippedDisplays[0].contains(secret), "`displays` says which entry it is")

    let h = Harness(displays: [laptop, tablet], settings: settings)
    h.start()
    for command in ["set gap 30", "get gap", "set gap 30", "reset gap", "displays"] {
      let reply = h.run(command)
      #expect(reply.ok && (reply.message + (reply.text ?? "")).contains(secret), "whoever asked is told: \(command): \(reply.message)")
    }
    let log = ((try? String(contentsOf: ArborPaths.logFile.appendingPathExtension("1"), encoding: .utf8)) ?? "")
      + (try String(contentsOf: ArborPaths.logFile, encoding: .utf8))
    #expect(!log.contains(secret))
  }

  // MARK: The `displays` query

  @Test func theDisplaysQueryListsEachDisplayAndItsOptions() throws {
    let json = """
      {"displays": [{"match": "builtin", "gap": 6}, {"match": ">=wide"}, {"match": "studio", "minimumUsableWidth": 650},
                    {"match": ">=2500", "gap": 20.5, "minimumUsableWidth": 700, "minimumUsableHeight": 400}]}
      """
    // Whatever order the system lists them in, they are counted as `@2` counts: the main one first.
    let h = Harness(displays: [studio, laptop], settings: try JSONDecoder().decode(Settings.self, from: Data(json.utf8)))
    h.start()
    let result = h.run("displays")
    #expect(result.ok)
    #expect(result.message == "2 display(s)")
    #expect(
      result.text == """
        1. Built-in Retina Display, 1440×900, main, built-in
           id main
           gap 6, from the entry "builtin"
           minimumUsableWidth 240
           minimumUsableHeight 160
           screenEdgeBand 12
        2. Studio Display, 2560×1440
           id 4C7A5B0E-9F2D-4B41-8E55-1A2B3C4D5E6F
           gap 20.5, from the entry ">=2500"
           minimumUsableWidth 650, from the entry "studio"
           minimumUsableHeight 400, from the entry ">=2500"
           screenEdgeBand 12
        Skipped entries of "displays" in settings.json:
          entry 2 (>=wide): `>=wide` compares the display's width with something that is not a number; expected e.g. >=2500
        """)
  }

  @Test func theDisplaysQuerySaysWhenNothingIsSet() {
    let h = Harness()
    h.start()
    #expect(
      h.run("displays").text == """
        1. Display, 1440×900, main, built-in
           id main
           gap 12
           minimumUsableWidth 240
           minimumUsableHeight 160
           screenEdgeBand 12
        Every display uses the general settings. Add a "displays" list to settings.json to change that.
        """)
  }

  @Test func theDisplaysQueryAnswersBeforeArborStarts() {
    let h = Harness()
    h.controller.accessibilityGranted = false
    let result = h.run("displays")
    #expect(result.ok)
    #expect(result.text?.hasPrefix("No displays yet: waiting for Accessibility permission") == true)
  }
}
