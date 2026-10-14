import ArborCore
import ArborKit
import ArborTesting
import CoreGraphics
import Testing

/// Where F53 meets F41: an app that is summoned by a key and keeps its own ⌃⌥. The key that brought it has to be
/// there to send it away.
@Suite @MainActor struct SummonKeyTests {
  let terminalID = "com.apple.Terminal"

  /// [editor | Desktop | browser], framed on the editor, which has the keyboard. The terminal and the notes float, out of
  /// view with the Desktop. ⌃⌥T summons the terminal, ⌃⌥N the notes. Arbor's shortcuts are off in the terminal.
  func makeHarness(listed: Bool = true, by name: String = "Terminal") -> (
    h: Harness, editor: WindowID, terminal: WindowID, notes: WindowID
  ) {
    var settings = Settings()
    settings.bindings = ["ctrl+opt+t": "summon \(name)", "ctrl+opt+n": "summon Notes"]
    if listed { settings.passThroughApps = [terminalID] }
    let h = Harness(settings: settings)
    let editor = h.system.open(app: "Editor", pid: 1001)
    let browser = h.system.open(app: "Browser", pid: 1002)
    let terminal = h.system.open(
      app: "Terminal", bundleID: terminalID, pid: 1003, frame: CGRect(x: 520, y: 300, width: 400, height: 300))
    let notes = h.system.open(app: "Notes", pid: 1004, frame: CGRect(x: 560, y: 340, width: 300, height: 300))
    h.start()
    h.run("dock \(editor.rawValue) left")
    h.run("dock \(browser.rawValue) right")
    h.system.userFocus(editor)
    h.run("zoom")
    h.scheduler.advance(by: 1)
    return (h, editor, terminal, notes)
  }

  func held(_ h: Harness) -> [String] { h.controller.activeBindings.map(\.command.text).sorted() }

  /// The product owner's day on the trunk: bind a key to `summon Terminal`, switch shortcuts off in Terminal.
  @Test func theKeyThatSummonedAnAppSendsItAwayThoughShortcutsAreOffInIt() {
    let s = makeHarness()
    #expect(s.h.key("ctrl+opt+t")?.ok == true)
    #expect(s.h.system.focused == s.terminal && s.h.system.isVisible(s.terminal))
    #expect(s.h.controller.isPassingThrough)
    #expect(held(s.h) == ["summon Terminal", "toggle-pause"], "that one shortcut, and what stays everywhere")

    #expect(s.h.key("ctrl+opt+t")?.message.hasPrefix("sent Terminal away") == true)
    #expect(!s.h.system.isVisible(s.terminal))
    #expect(s.h.system.focused == s.editor)
    #expect(!s.h.controller.isPassingThrough)
    #expect(s.h.controller.activeBindings == s.h.controller.effectiveBindings.bindings, "all of them again")
  }

  @Test func everyOtherShortcutReachesTheApp() {
    let s = makeHarness()
    s.h.key("ctrl+opt+t")
    #expect(s.h.key("ctrl+opt+space") == nil)
    #expect(s.h.key("ctrl+opt+n") == nil, "another app's summon is a shortcut like any other")
    #expect(s.h.system.focused == s.terminal)
  }

  @Test(arguments: ["Terminal", "terminal", "com.apple.Terminal"])
  func howeverTheBindingNamesTheApp(name: String) {
    let s = makeHarness(by: name)
    s.h.key("ctrl+opt+t")
    #expect(held(s.h).contains("summon \(name)"))
  }

  /// macOS says that the app came to the front before it says which window has the keyboard, and only then is a window
  /// that had been sent away summoned.
  @Test func summonedByCommandTabTheKeyIsThereToo() {
    let s = makeHarness()
    s.h.key("ctrl+opt+t")
    s.h.key("ctrl+opt+t")
    var told = 0
    s.h.controller.observe { if $0 == .input { told += 1 } }
    s.h.system.activateApp(of: s.terminal)
    #expect(held(s.h) == ["toggle-pause"], "in front, and not summoned yet")
    #expect(told == 1)
    s.h.system.userFocus(s.terminal)
    #expect(s.h.workspace.isSummoned(s.terminal))
    #expect(held(s.h) == ["summon Terminal", "toggle-pause"])
    #expect(told == 2, "the app registers only what it is told has changed")
    s.h.run("relayout")
    #expect(told == 2, "and is told once")
  }

  /// Decided: while its app is summoned. A terminal that is docked, or floats on the Desktop, is an app that keeps its keys.
  @Test func anAppThatIsInFrontWithoutBeingSummonedKeepsAllItsKeys() {
    let s = makeHarness()
    s.h.run("desktop")
    s.h.system.userFocus(s.terminal)
    #expect(s.h.controller.isPassingThrough && !s.h.workspace.isSummoned(s.terminal))
    #expect(held(s.h) == ["toggle-pause"])
  }

  @Test func whenTheSummonEndsSomeOtherWayTheKeyGoesBackToTheApp() {
    for command in ["dock left", "pin", "float"] {
      let s = makeHarness()
      s.h.key("ctrl+opt+t")
      var told = 0
      s.h.controller.observe { if $0 == .input { told += 1 } }
      let words = command.split(separator: " ")
      #expect(s.h.run(([words[0], "\(s.terminal.rawValue)"] + words.dropFirst()).joined(separator: " ")).ok, "\(command)")
      #expect(!s.h.workspace.isSummoned(s.terminal), "\(command)")
      #expect(s.h.controller.isPassingThrough, "\(command): still in front")
      #expect(held(s.h) == ["toggle-pause"], "\(command)")
      #expect(told == 1, "\(command)")
    }
  }

  @Test func observersAreToldOnceForEachChangeAndNotWithEveryLayout() {
    let s = makeHarness()
    var told = 0
    s.h.controller.observe { if $0 == .input { told += 1 } }
    s.h.key("ctrl+opt+t")
    #expect(told == 1, "shortcuts off and that key kept: one piece of news")
    s.h.run("relayout")
    s.h.run("relayout")
    #expect(told == 1)
    s.h.key("ctrl+opt+t")
    #expect(told == 3, "the summon is over while the app is still in front; then another app is")
  }

  @Test func inAnAppThatIsNotListedNothingChanges() {
    let s = makeHarness(listed: false)
    var told = 0
    s.h.controller.observe { if $0 == .input { told += 1 } }
    s.h.key("ctrl+opt+t")
    #expect(s.h.controller.activeBindings == s.h.controller.effectiveBindings.bindings)
    s.h.key("ctrl+opt+t")
    #expect(told == 0)
  }

  @Test func listingTheAppWhileItIsSummonedKeepsTheKey() {
    let s = makeHarness(listed: false)
    s.h.key("ctrl+opt+t")
    #expect(s.h.run("pass-through on").ok)
    #expect(held(s.h) == ["summon Terminal", "toggle-pause"])
    #expect(s.h.key("ctrl+opt+t")?.ok == true)
    #expect(!s.h.system.isVisible(s.terminal))
  }

  @Test func aPauseStillLeavesOnlyWhatEndsIt() {
    let s = makeHarness()
    s.h.key("ctrl+opt+t")
    s.h.run("pause")
    #expect(held(s.h) == ["toggle-pause"])
  }

  @Test func bindingsCountsIt() {
    let s = makeHarness()
    s.h.key("ctrl+opt+t")
    #expect(s.h.run("bindings").message.contains("all but 2 off in Terminal"))
  }
}
