import ArborCore
import ArborKit
import ArborTesting
import CoreGraphics
import Foundation
import Testing

/// docs/MENU.md, rule 3: the ways out may never be below a fold. On a display 768 points high the menu once ended at 853, and
/// Pause Arbor and Quit Arbor had to be scrolled to.
@Suite @MainActor struct MenuHeightTests {
  struct Broken: Error, CustomStringConvertible { let description = "line 3, column 3: expected `,` or `}`" }

  /// Every state a menu can open in, and of those that come in pairs the pairs that take the most rows.
  nonisolated static let running = [
    "no windows", "nothing docked", "an ordinary day", "much of everything", "thirty windows", "an update waits",
    "the view is held and settings.json has a mistake", "holding still and settings.json has a mistake",
    "shortcuts are off here and settings.json has a mistake", "the arrangement was repaired and settings.json has a mistake",
  ]
  nonisolated static let notRunning = [
    "starting", "no permission", "paused", "paused and settings.json has a mistake",
    "the permission was taken away and settings.json has a mistake",
  ]

  func harness(in state: String) -> Harness {
    var settings = Settings()
    settings.automaticUpdateChecks = state == "an update waits"
    let much = state == "much of everything"
    let h = Harness(displays: [FakeWindowSystem.standardDisplay] + (much ? [Workload.secondDisplay] : []), settings: settings)
    if state == "starting" { return h }
    if state == "no permission" {
      h.controller.accessibilityGranted = false
      return h
    }
    h.watchAccessibility()
    h.controller.buildInfo = BuildInfo(version: "0.9.0", build: "214", commit: "47a2ba9")
    if state.hasPrefix("the arrangement was repaired") {
      h.store.repairs = ["workspaces: skipped `side`"]
      h.store.keptCopy = "state.before-repair.json"
    }
    let apps = [
      "Safari", "Mail", "Notes", "Music", "Maps", "Photos", "Pages", "Numbers", "Keynote", "Preview", "Terminal", "Calendar",
    ]
    var windows = state == "no windows" ? [] : apps.map { h.system.open(app: $0) }
    if state == "thirty windows" { windows += (13...30).map { h.system.open(app: "Safari", title: "Tab \($0)") } }
    h.start()
    if state != "nothing docked", !windows.isEmpty { h.run("arrange") }
    if much {
      // All a person can make a list of: nine saved views, a dozen named spaces, twenty apps that are not arranged.
      for (index, window) in windows.enumerated() {
        h.run("zoom \(window.rawValue)")
        if index < 9 { h.run("save-view \(index + 1)") }
        h.run("name Space \(index + 1)")
      }
      for index in 1...20 { h.run("exclude com.example.other\(index)") }
      h.run("show-all")
      h.run("float \(windows[11].rawValue)")
      h.run("undo")
    }
    if let first = windows.first { h.system.userFocus(first) }

    if state == "an update waits" {
      h.releases.reply = .latest(tag: "v0.9.1")
      h.scheduler.advance(by: 61)
    }
    // Before the mistake, with which no setting can be changed.
    if state.hasPrefix("shortcuts are off here") { h.run("pass-through com.example.safari on") }
    if state.hasSuffix("settings.json has a mistake") {
      h.controller.loadSettings = { throw Broken() }
      h.run("reload-settings")
    }
    if state.hasPrefix("the view is held") { h.run("hold") }
    if state.hasPrefix("holding still") { h.run("hold still") }
    if state.hasPrefix("paused") { h.run("pause") }
    if state.hasPrefix("the permission was taken away") {
      h.run("zoom \(windows[0].rawValue)")
      h.revokeAccessibility()
      h.scheduler.advance(by: 3)
    }
    return h
  }

  /// A menu and its submenus, each under the way to it.
  func everyMenu(of model: MenuModel) -> [(path: String, sections: [MenuModel.Section])] {
    func below(_ path: String, _ sections: [MenuModel.Section]) -> [(String, [MenuModel.Section])] {
      [(path, sections)]
        + sections.flatMap(\.items).filter { !$0.sections.isEmpty }.flatMap { below(path + " ▸ " + $0.title, $0.sections) }
    }
    return below("the menu", model.sections)
  }

  @Test(arguments: running + notRunning)
  func theMenuIsAtMost600PointsHigh(state: String) {
    let menu = harness(in: state).controller.menuModel()
    #expect(menu.height <= MenuModel.tallest, "\(state): \(menu.height) points\n\(menu.text)")
  }

  /// At the top level, so above the fold with the rest of it, and never greyed out.
  @Test(arguments: running)
  func theFourWaysOutNeedNoScrollingAndNoSubmenu(state: String) {
    let h = harness(in: state)
    #expect(h.controller.isRunning)
    let top = h.controller.menuModel().sections.flatMap(\.items)
    // Nothing moves a held view (docs/MENU.md, state 4): the way out of that is the row that says so.
    let first = state.hasPrefix("the view is held") ? "The view is held · Release" : "Show Everything"
    for title in [first, "Float All Windows", "Pause Arbor", "Quit Arbor"] {
      #expect(top.first { $0.title == title }?.isEnabled == true, "\(state): \(title)")
    }
    #expect(top.suffix(2).map(\.title) == ["Pause Arbor", "Quit Arbor"])
  }

  @Test(arguments: notRunning)
  func anArborThatIsNotRunningCanStillBeQuit(state: String) {
    let h = harness(in: state)
    #expect(!h.controller.isRunning)
    let top = h.controller.menuModel().sections.flatMap(\.items)
    #expect(top.last?.title.hasPrefix("Quit Arbor") == true && top.last?.isEnabled == true)
    if state.hasPrefix("paused") { #expect(top.first { $0.title.hasSuffix(" · Resume") }?.isEnabled == true) }
  }

  /// The states above are what they say: otherwise the heights prove nothing.
  @Test func theStatesAreTheStates() {
    func lines(_ state: String) -> [String] { harness(in: state).controller.menuModel().sections.first?.items.map(\.title) ?? [] }
    let mistake = ["Settings.json has a mistake: line 3, column 3 · Settings File…"]
    #expect(lines("the view is held and settings.json has a mistake") == ["The view is held · Release"] + mistake)
    #expect(
      lines("holding still and settings.json has a mistake")
        == ["Holding still · Release"] + mistake)
    #expect(
      lines("shortcuts are off here and settings.json has a mistake")
        == mistake + ["Shortcuts are off in “Safari” · Turn On"])
    #expect(
      lines("the arrangement was repaired and settings.json has a mistake")
        == mistake + ["The saved arrangement needed 1 repair when it was read"])
    #expect(lines("paused and settings.json has a mistake").count == 2)
    #expect(lines("the permission was taken away and settings.json has a mistake").count == 4, "three lines, and the file")
    #expect(harness(in: "an update waits").controller.menuModel().item("Update Available…") != nil)

    let much = harness(in: "much of everything").controller.menuModel()
    #expect(much.allItems.filter { $0.title.hasPrefix("Space ") }.count == 12)
    #expect(much.allItems.filter { $0.title.hasSuffix("(replace)") }.count == 9)
    #expect(much.allItems.filter { $0.title.hasPrefix("other") }.count == 20)
    #expect(much.item("Move to Next Display") != nil)
    #expect(much.allItems.contains { $0.title.hasPrefix("Redo ") })
    #expect(harness(in: "thirty windows").controller.menuModel().item("Windows")?.sections.flatMap(\.items).count == 30)
  }

  /// A list that a person makes longer (open windows, saved views, named spaces, apps that are not arranged) is in a submenu.
  @Test func nothingAPersonMakesLongerIsAtTheTopLevel() {
    func top(_ state: String) -> [[String]] {
      harness(in: state).controller.menuModel().sections.map { section in
        section.items.map { item in ["Undo", "Redo"].first { item.title.hasPrefix($0 + " ") } ?? item.title }
      }
    }
    #expect(top("much of everything") == top("an ordinary day"))
    #expect(top("nothing docked") == top("an ordinary day"))
    #expect(top("thirty windows") == top("an ordinary day"))
    #expect(top("no windows") == top("an ordinary day"))
  }

  /// No submenu scrolls either, but for the lists people make: with all nine views saved, Saved Views is the longest.
  @Test func noSubmenuIsHigherUntilAPersonsOwnListMakesItSo() {
    let h = harness(in: "an ordinary day")
    for slot in 1...9 { h.run("save-view \(slot)") }
    for (path, sections) in everyMenu(of: h.controller.menuModel()) {
      #expect(MenuModel.height(of: sections) <= MenuModel.tallest, "\(path): \(MenuModel.height(of: sections)) points")
    }
  }

  /// Two moves of the pointer reach every row.
  @Test(arguments: running + notRunning)
  func thereIsNoThirdLevel(state: String) {
    for (path, _) in everyMenu(of: harness(in: state).controller.menuModel()) {
      #expect(path.components(separatedBy: " ▸ ").count <= 2, "\(path)")
    }
  }

  /// `menu` says it, so that a script on a Mac can hold the height macOS gives the menu against this one.
  @Test func theMenuCommandSaysHowHighTheMenuIs() {
    let h = harness(in: "an ordinary day")
    let menu = h.controller.menuModel()
    #expect(h.run("menu").message == "\(menu.allItems.count) items, \(Int(menu.height)) points high")
  }
}
