import ArborCore
import ArborKit
import ArborTesting
import CoreGraphics
import Foundation
import Testing

private let terminal = "com.apple.Terminal"
private let mail = "com.apple.mail"
private let slack = "com.tinyspeck.slackmacgap"
private let finder = "com.apple.finder"

/// Scenario tests for per-app rules (docs/features/F11-app-rules.md).
@Suite @MainActor struct RuleTests {
  func harness(
    _ rules: [AppRule], displays: [DisplaySnapshot] = [FakeWindowSystem.standardDisplay],
    saved: PersistedState? = nil, configure: (inout Settings) -> Void = { _ in }
  ) -> Harness {
    var settings = Settings()
    settings.rules = rules
    configure(&settings)
    return Harness(displays: displays, settings: settings, saved: saved)
  }

  /// The split holding a docked window's stack.
  func parent(of window: WindowID, in tree: LayoutTree) -> NodeID? {
    tree.leaf(containing: window).flatMap { tree.parent(of: $0) }
  }

  /// The windows of the root's children, in order (`[]` is the Desktop).
  func columns(_ h: Harness) -> [[WindowID]] {
    let tree = h.workspace.tree
    return tree.children(of: tree.root).map { tree.windows(under: $0) }
  }

  var content: CGRect { FakeWindowSystem.standardDisplay.visibleFrame.insetBy(dx: 12, dy: 12) }

  // MARK: 1. dock <edge>

  @Test func aDockRuleDocksANewWindowAtThatEdgeOfTheView() {
    let h = harness([AppRule(app: terminal, action: .dock(.right))])
    let safari = h.system.open(app: "Safari", frame: CGRect(x: 100, y: 100, width: 600, height: 400))
    h.start()
    h.run("dock \(safari.rawValue) left")
    let t = h.system.open(app: "Terminal", bundleID: terminal)
    #expect(columns(h) == [[safari], [], [t]])
    #expect(h.workspace.camera == h.workspace.tree.root)
    #expect(h.frame(t)!.maxX == content.maxX)
    #expect(h.frame(t)!.minY == content.minY && h.frame(t)!.maxY == content.maxY)
    expectWindowsMatchLayout(h)
  }

  @Test func whenZoomedInANewWindowDocksAtTheEdgeOfThatView() {
    let h = harness([AppRule(app: terminal, action: .dock(.right))])
    let a = h.system.open(app: "Safari")
    let b = h.system.open(app: "Notes")
    let c = h.system.open(app: "Mail")
    h.start()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(c.rawValue) beside \(a.rawValue) bottom")
    h.run("dock \(b.rawValue) right")
    h.run("zoom \(a.rawValue)")
    let t = h.system.open(app: "Terminal", bundleID: terminal)
    // The view was `a` alone; now it is `a` with the new window on its right.
    let tree = h.workspace.tree
    #expect(tree.children(of: h.workspace.camera) == [tree.leaf(containing: a)!, tree.leaf(containing: t)!])
    #expect(h.system.isVisible(a) && h.system.isVisible(t))
    #expect(!h.system.isVisible(b) && !h.system.isVisible(c))
    #expect(h.frame(t)!.maxX == content.maxX)
    #expect(h.frame(t)!.minX > h.frame(a)!.maxX)
    expectWindowsMatchLayout(h)
  }

  // MARK: 2. Titles

  @Test func titlesPickTheRuleAndNonMatchingTitlesFallThrough() {
    let h = harness([
      AppRule(app: mail, title: "inbox", action: .dock(.left)),
      AppRule(app: mail, title: "New Message", action: .float),
      AppRule(app: mail, action: .dock(.right)),
    ])
    h.start()
    let inbox = h.system.open(app: "Mail", bundleID: mail, title: "Inbox – 3 messages")
    let compose = h.system.open(app: "Mail", bundleID: mail, title: "New Message")
    let reply = h.system.open(app: "Mail", bundleID: mail, title: "Re: lunch")
    let notes = h.system.open(app: "Notes", title: "Inbox ideas")
    #expect(columns(h) == [[inbox], [], [reply]])
    #expect(h.workspace.isFloating(compose), "a float rule stops later rules")
    #expect(h.workspace.isFloating(notes), "titles only count for the rule's own app")
    expectWindowsMatchLayout(h)
  }

  // MARK: 3. dock beside <app> <edge>

  @Test func dockBesideUsesTheMostRecentlyFocusedDockedWindowOfThatApp() {
    let h = harness([AppRule(app: slack, action: .dockBeside(bundleID: mail, .bottom))])
    let first = h.system.open(app: "Mail", bundleID: mail)
    let second = h.system.open(app: "Mail", bundleID: mail)
    h.start()
    h.run("dock \(first.rawValue) left")
    h.run("dock \(second.rawValue) right")
    h.system.userFocus(first)
    h.system.userFocus(second)

    let s1 = h.system.open(app: "Slack", bundleID: slack)
    #expect(parent(of: s1, in: h.workspace.tree) == parent(of: second, in: h.workspace.tree))
    #expect(h.frame(s1)!.minY > h.frame(second)!.maxY)
    #expect(abs(h.frame(s1)!.minX - h.frame(second)!.minX) < 1)

    h.system.userFocus(first)
    let s2 = h.system.open(app: "Slack", bundleID: slack)
    #expect(parent(of: s2, in: h.workspace.tree) == parent(of: first, in: h.workspace.tree))
    #expect(h.frame(s2)!.minY > h.frame(first)!.maxY)
    #expect(abs(h.frame(s2)!.minX - h.frame(first)!.minX) < 1)
    #expect(columns(h) == [[first, s2], [], [second, s1]])
    expectWindowsMatchLayout(h)
  }

  @Test func dockBesideCountsDockedWindowsThatWereNeverFocused() {
    // After a restart nothing has been focused yet; the app's docked window still counts.
    let h = harness([AppRule(app: slack, action: .dockBeside(bundleID: mail, .bottom))])
    let m = h.system.open(app: "Mail", bundleID: mail)
    h.start()
    h.run("dock \(m.rawValue) left")
    let s = h.system.open(app: "Slack", bundleID: slack)
    #expect(columns(h) == [[m, s], []])
    #expect(h.frame(s)!.minY > h.frame(m)!.maxY)
  }

  @Test func aRuleCanDockNewWindowsBesideTheAppsOwnLatestWindow() {
    let h = harness([AppRule(app: terminal, action: .dockBeside(bundleID: terminal, .bottom))]) {
      // Keep the thin windows as windows rather than tiles; only the order matters here.
      $0.minimumUsableHeight = 0
    }
    h.start()
    let t1 = h.system.open(app: "Terminal", bundleID: terminal)  // none docked yet: the bottom edge
    let t2 = h.system.open(app: "Terminal", bundleID: terminal)  // beside t1, the only one docked
    h.system.userFocus(t2)
    let t3 = h.system.open(app: "Terminal", bundleID: terminal)  // beside t2, focused last
    h.system.userFocus(t1)
    let t4 = h.system.open(app: "Terminal", bundleID: terminal)  // beside t1, focused last
    #expect(columns(h) == [[], [t1], [t4], [t2], [t3]])
    expectWindowsMatchLayout(h)
  }

  @Test func dockingBesideAWindowOutOfViewWidensTheViewToShowTheNewWindow() {
    let h = harness([AppRule(app: slack, action: .dockBeside(bundleID: mail, .bottom))])
    let m = h.system.open(app: "Mail", bundleID: mail)
    let notes = h.system.open(app: "Notes")
    h.start()
    h.run("dock \(m.rawValue) left")
    h.run("dock \(notes.rawValue) right")
    h.run("zoom \(notes.rawValue)")
    #expect(!h.system.isVisible(m))
    let s = h.system.open(app: "Slack", bundleID: slack)
    #expect(parent(of: s, in: h.workspace.tree) == parent(of: m, in: h.workspace.tree))
    #expect(h.workspace.camera == h.workspace.tree.root)
    #expect(h.system.isVisible(s) && h.system.isVisible(m) && h.system.isVisible(notes))
    expectWindowsMatchLayout(h)
  }

  @Test func dockBesideFallsBackToTheEdgeWhenThatAppHasNoDockedWindow() {
    let h = harness([AppRule(app: slack, action: .dockBeside(bundleID: mail, .bottom))])
    let floatingMail = h.system.open(app: "Mail", bundleID: mail)
    h.start()
    let s = h.system.open(app: "Slack", bundleID: slack)
    #expect(columns(h) == [[], [s]])
    #expect(h.frame(s)!.maxY == content.maxY)
    #expect(h.frame(s)!.minX == content.minX && h.frame(s)!.maxX == content.maxX)
    #expect(h.workspace.isFloating(floatingMail))
    expectWindowsMatchLayout(h)
  }

  @Test func dockBesideOnlyLooksAtTheNewWindowsDisplay() {
    let side = DisplaySnapshot(
      id: DisplayID("side"), frame: CGRect(x: 1440, y: 0, width: 1280, height: 800),
      visibleFrame: CGRect(x: 1440, y: 0, width: 1280, height: 800), isMain: false)
    let h = harness(
      [AppRule(app: slack, action: .dockBeside(bundleID: mail, .bottom))],
      displays: [FakeWindowSystem.standardDisplay, side])
    let m = h.system.open(
      app: "Mail", bundleID: mail, frame: CGRect(x: 1600, y: 100, width: 600, height: 400))
    h.start()
    h.system.cursor = CGPoint(x: 1800, y: 300)
    h.run("dock \(m.rawValue) left")
    h.system.userFocus(m)

    // Opened on the main display, where Mail has no docked window.
    let onMain = h.system.open(app: "Slack", bundleID: slack)
    #expect(columns(h) == [[], [onMain]])

    // Opened on the side display, below Mail.
    let onSide = h.system.open(
      app: "Slack", bundleID: slack, frame: CGRect(x: 1700, y: 300, width: 600, height: 400))
    let sideTree = h.controller.workspaces[side.id]!.tree
    #expect(parent(of: onSide, in: sideTree) == parent(of: m, in: sideTree))
    #expect(h.frame(onSide)!.minY > h.frame(m)!.maxY)
    #expect(side.visibleFrame.contains(h.frame(onSide)!))
  }

  // MARK: 4. ignore

  @Test func ignoredWindowsAreNeverArranged() {
    let h = harness([AppRule(app: finder, action: .ignore)])
    let a = h.system.open(app: "Safari", frame: CGRect(x: 100, y: 100, width: 600, height: 400))
    let b = h.system.open(app: "Notes", frame: CGRect(x: 700, y: 200, width: 600, height: 400))
    h.start()
    let f = h.system.open(
      app: "Finder", bundleID: finder, frame: CGRect(x: 400, y: 300, width: 500, height: 350))
    #expect(!h.workspace.contains(f))
    #expect(h.controller.filter.ignoredWindowIDs == [f])
    #expect(h.run("state").state!.window(f)?.managed == false)

    // Everything that moves windows: docking around it, moving the camera
    // away from the Desktop and back, arranging, floating everything,
    // focusing it, dragging it to a screen edge, commands aimed at it.
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) right")
    h.run("zoom \(a.rawValue)")
    h.run("back")
    h.run("desktop")
    h.run("show-all")
    h.run("arrange")
    h.run("float-all")
    h.system.userFocus(f)
    #expect(!h.run("dock \(f.rawValue) left").ok)
    #expect(!h.run("float \(f.rawValue)").ok)
    #expect(!h.run("zoom \(f.rawValue)").ok)
    let start = h.frame(f)!
    h.system.drag(f, through: [CGPoint(x: start.midX, y: start.minY + 10), CGPoint(x: 3, y: 450)])
    #expect(!h.workspace.contains(f), "dropping it on a screen edge does not dock it")
    let userFrame = CGRect(x: 200, y: 150, width: 520, height: 360)
    h.system.userMove(f, to: userFrame)

    // It stays ignored when the app announces it again, when the settings
    // change (even to no rules), and when its app is excluded and included.
    h.controller.windowAppeared(h.controller.windows[f]!)
    h.controller.apply(settings: Settings())
    #expect(h.run("exclude \(finder)").ok)
    #expect(h.run("include \(finder)").ok)
    h.run("relayout")
    h.scheduler.runPending()
    #expect(!h.workspace.contains(f))
    #expect(h.system.frameLog.allSatisfy { $0.window != f }, "Arbor never moved it")
    #expect(h.frame(f) == userFrame)

    // Quitting puts every arranged window in view and still leaves it alone.
    h.controller.shutdown()
    #expect(h.system.frameLog.allSatisfy { $0.window != f })
    #expect(h.frame(f) == userFrame)
  }

  @Test func anIgnoredWindowIsForgottenWhenItCloses() {
    let h = harness([AppRule(app: finder, action: .ignore)])
    h.start()
    let f = h.system.open(app: "Finder", bundleID: finder)
    #expect(h.controller.filter.ignoredWindowIDs == [f])
    h.system.close(f)
    #expect(h.controller.filter.ignoredWindowIDs.isEmpty)
  }

  // MARK: 5. Launch and restored state

  @Test func windowsOpenAtLaunchAreNotTouchedByRules() {
    let h = harness([AppRule(app: terminal, action: .dock(.right)), AppRule(app: finder, action: .ignore)])
    let t = h.system.open(app: "Terminal", bundleID: terminal)
    let f = h.system.open(
      app: "Finder", bundleID: finder, frame: CGRect(x: 600, y: 300, width: 500, height: 300))
    h.start()
    #expect(h.workspace.isFloating(t))
    #expect(h.controller.filter.ignoredWindowIDs == [f], "of the rules, only ignore applies at launch (Q4)")
    #expect(h.system.frameLog.isEmpty, "starting must not move anything")
    // Windows opened afterwards follow the rules.
    let later = h.system.open(app: "Terminal", bundleID: terminal)
    #expect(columns(h) == [[], [later]])
  }

  @Test func windowsRestoredFromStateKeepTheirPlace() {
    // First run, without rules: Terminal docked on the left, Finder floating.
    let first = Harness()
    let t = first.system.open(app: "Terminal", bundleID: terminal)
    let f = first.system.open(
      app: "Finder", bundleID: finder, frame: CGRect(x: 600, y: 300, width: 500, height: 300))
    first.start()
    first.run("dock \(t.rawValue) left")
    first.controller.saveNow()
    let oldTerminal = first.controller.windows[t]!
    let oldFinder = first.controller.windows[f]!

    // Second run, with rules that would dock Terminal on the right and ignore
    // Finder. Unrelated windows took the old numbers, so both windows come
    // back under new numbers and are matched by app and title.
    let again = harness(
      [AppRule(app: terminal, action: .dock(.right)), AppRule(app: finder, action: .ignore)],
      saved: first.store.saved)
    for _ in 0..<2 { again.system.open(app: "Filler") }
    let newTerminal = again.system.open(
      app: "Terminal", bundleID: terminal, title: oldTerminal.title, frame: oldTerminal.frame)
    let newFinder = again.system.open(
      app: "Finder", bundleID: finder, title: oldFinder.title, frame: oldFinder.frame)
    again.start()
    #expect(columns(again) == [[newTerminal], []])
    #expect(again.controller.filter.ignoredWindowIDs == [newFinder], "only ignore applies at launch (Q4)")
    #expect(!again.workspace.contains(newFinder))
    #expect(again.system.frameLog.allSatisfy { $0.window != newFinder })
  }

  // MARK: 6. Bad rules

  @Test func badRulesAreSkippedAndTheOthersStillApply() throws {
    let json = """
      {"rules": [
        {"app": "com.apple.Terminal", "action": "dock sideways"},
        {"app": "com.apple.Terminal", "title": "build", "action": "dock left"},
        {"app": "com.apple.Terminal"},
        {"app": "com.apple.Terminal", "action": "dock right"}
      ]}
      """
    let settings = try JSONDecoder().decode(Settings.self, from: Data(json.utf8))
    let h = Harness(settings: settings)
    h.start()
    let build = h.system.open(app: "Terminal", bundleID: terminal, title: "build — zsh")
    let shell = h.system.open(app: "Terminal", bundleID: terminal, title: "zsh")
    #expect(columns(h) == [[build], [], [shell]])

    let report = h.run("rules").text ?? ""
    #expect(report.contains("entry 1 (com.apple.Terminal): unknown edge `sideways`"))
    #expect(report.contains("entry 3 (com.apple.Terminal): `action` is missing"))
    #expect(report.contains(#"1. com.apple.Terminal, title contains "build" → dock left"#))
    #expect(report.contains("2. com.apple.Terminal → dock right"))
  }

  // MARK: The rules command and settings

  @Test func theRulesCommandShowsTheRulesAndWhatTheFocusedWindowMatches() {
    let h = harness([
      AppRule(app: terminal, action: .dock(.right)), AppRule(app: mail, title: "Inbox", action: .dock(.left)),
      AppRule(app: finder, action: .ignore),
    ])
    let t = h.system.open(app: "Terminal", bundleID: terminal)
    let notes = h.system.open(app: "Notes")
    h.start()
    h.system.userFocus(t)
    let result = h.run("rules")
    #expect(result.ok)
    #expect(result.message == "3 rule(s)")
    let text = result.text ?? ""
    #expect(text.contains("Rules for new windows, checked in order (the first match wins):"))
    #expect(text.contains("  1. com.apple.Terminal → dock right"))
    #expect(text.contains(#"  2. com.apple.mail, title contains "Inbox" → dock left"#))
    #expect(text.contains("  3. com.apple.finder → ignore"))
    #expect(text.contains("Focused window \(t) (com.apple.Terminal) matches rule 1: dock right."))
    #expect(!text.contains("Skipped"))

    h.system.userFocus(notes)
    let unmatched = h.run("rules").text ?? ""
    #expect(unmatched.contains("Focused window \(notes) (com.example.notes) matches no rule."))

    let f = h.system.open(app: "Finder", bundleID: finder)
    h.system.focus(f)
    let ignored = h.run("rules").text ?? ""
    #expect(ignored.contains("Focused window \(f) (com.apple.finder) matches rule 3: ignore."))
    #expect(ignored.contains("Arbor is leaving it alone"))
  }

  @Test func theRulesCommandWithoutRulesAndBeforeStarting() {
    let empty = Harness()
    empty.start()
    #expect(empty.run("rules").text?.hasPrefix("No rules: new windows float.") == true)

    let h = harness([AppRule(app: terminal, action: .dock(.right))])
    h.controller.accessibilityGranted = false
    let result = h.run("rules")
    #expect(result.ok, "a query works before Accessibility is granted")
    #expect(result.text?.contains("1. com.apple.Terminal → dock right") == true)
    #expect(result.text?.contains("No focused window: waiting for Accessibility permission") == true)
  }

  @Test func reloadedRulesApplyToWindowsOpenedAfterwards() {
    let h = Harness()
    let t = h.system.open(app: "Terminal", bundleID: terminal)
    h.start()
    var updated = Settings()
    updated.rules = [AppRule(app: terminal, action: .dock(.right))]
    h.controller.loadSettings = { updated }
    #expect(h.run("reload-settings").ok)
    #expect(h.workspace.isFloating(t), "rules do not move windows that are already open")
    let later = h.system.open(app: "Terminal", bundleID: terminal)
    #expect(columns(h) == [[], [later]])
  }

  @Test func exclusionWinsOverRules() {
    let h = harness([AppRule(app: terminal, action: .dock(.right))]) { $0.excludedBundleIDs = [terminal] }
    h.start()
    let t = h.system.open(app: "Terminal", bundleID: terminal)
    #expect(!h.workspace.contains(t))
    #expect(h.system.frameLog.isEmpty)
    h.system.focus(t)
    #expect(h.run("rules").text?.contains("Arbor does not arrange its app, so rules do not apply") == true)
  }
}
