import ArborCore
import ArborKit
import ArborTesting
import CoreGraphics
import Foundation
import Testing

private let mail = "com.apple.mail"
private let finder = "com.apple.finder"

@MainActor private func harness(
  _ rules: [AppRule], saved: PersistedState? = nil, configure: (inout Settings) -> Void = { _ in }
) -> Harness {
  var settings = Settings()
  settings.rules = rules
  configure(&settings)
  return Harness(settings: settings, saved: saved)
}

/// The windows of the root's children, in order (`[]` is the Desktop).
@MainActor private func columns(_ h: Harness) -> [[WindowID]] {
  let tree = h.workspace.tree
  return tree.children(of: tree.root).map { tree.windows(under: $0) }
}

/// The waits for late titles that are still running.
@MainActor private func titleWaits(_ h: Harness) -> [String] {
  h.scheduler.pendingKeys.filter { $0.hasPrefix("rule-title-") }
}

/// QUESTIONS Q4: `ignore` rules also apply to windows Arbor did not see open, so an ignored window
/// stays ignored across a restart without anything being saved.
@Suite @MainActor struct IgnoreOnSightTests {
  @Test func aWindowFoundAtLaunchThatARuleIgnoresIsNeverArranged() {
    let h = harness([AppRule(app: finder, action: .ignore)])
    let a = h.system.open(app: "Safari", frame: CGRect(x: 100, y: 100, width: 600, height: 400))
    let f = h.system.open(
      app: "Finder", bundleID: finder, frame: CGRect(x: 400, y: 300, width: 500, height: 350))
    h.start()
    #expect(h.controller.filter.ignoredWindowIDs == [f])
    #expect(!h.workspace.contains(f))
    #expect(h.run("state").state!.window(f)?.managed == false)

    // What used to move it after a restart: the camera leaving the Desktop, and docking over it.
    h.run("dock \(a.rawValue) left")
    h.run("zoom \(a.rawValue)")
    h.run("back")
    h.run("arrange")
    h.run("float-all")
    h.scheduler.runPending()
    h.controller.shutdown()
    #expect(h.system.frameLog.allSatisfy { $0.window != f }, "Arbor never moved it")
  }

  @Test func itStaysIgnoredThroughAPause() {
    let h = harness([AppRule(app: finder, action: .ignore)])
    let f = h.system.open(app: "Finder", bundleID: finder)
    h.start()
    let late = h.system.open(app: "Finder", bundleID: finder)
    h.run("pause")
    h.run("resume")
    #expect(h.controller.filter.ignoredWindowIDs == [f, late])
    #expect(!h.workspace.contains(f) && !h.workspace.contains(late))
    #expect(h.system.frameLog.allSatisfy { $0.window != f && $0.window != late }, "Arbor never moved them")
  }

  @Test func itLeavesTheSavedArrangement() {
    // First run, without rules: Finder docked on the left, Mail on the right.
    let first = Harness()
    let f = first.system.open(app: "Finder", bundleID: finder)
    let m = first.system.open(app: "Mail", bundleID: mail)
    first.start()
    first.run("dock \(f.rawValue) left")
    first.run("dock \(m.rawValue) right")
    first.run("zoom \(f.rawValue)")
    first.controller.saveNow()

    let again = harness([AppRule(app: finder, action: .ignore)], saved: first.store.saved)
    for window in [f, m] {
      let old = first.controller.windows[window]!
      again.system.open(app: old.appName, bundleID: old.bundleID, title: old.title, frame: old.frame)
    }
    again.start()
    #expect(again.controller.filter.ignoredWindowIDs == [f])
    #expect(columns(again) == [[], [m]])
    #expect(again.workspace.tree.invariantViolations().isEmpty)
    #expect(again.workspace.tree.contains(again.workspace.camera), "the camera was on the window that left")
    #expect(again.system.frameLog.allSatisfy { $0.window != f })
  }

  // MARK: To ignore a window is never to touch it again, so one that is out of view is fetched first

  /// Found by the chaos lab. The rule comes after the window was arranged, so it does not apply to it, until
  /// every display goes (lid shut, cable out) and Arbor comes across the window again, in its corner.
  @Test func aWindowOutOfViewIsNotIgnoredThereWhenEveryDisplayGoes() {
    let h = harness([])
    let a = h.system.open(app: "Safari")
    let f = h.system.open(app: "Finder", bundleID: finder)
    h.start()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(f.rawValue) right")
    h.run("zoom \(a.rawValue)")
    #expect(!h.system.isVisible(f))
    var settings = h.controller.settings
    settings.rules = [AppRule(app: finder, action: .ignore)]
    h.controller.apply(settings: settings)
    #expect(h.workspace.isDocked(f), "a rule does not rearrange what is arranged")

    h.system.setDisplays([])
    h.scheduler.runPending()
    #expect(h.controller.filter.ignoredWindowIDs.isEmpty, "there is nowhere to fetch it to yet")
    h.system.setDisplays([FakeWindowSystem.standardDisplay])
    h.scheduler.runPending()
    // It is arranged as it was, or ignored and in view. Either way somebody can reach it.
    #expect(h.workspace.contains(f) || h.system.isVisible(f))
    h.controller.shutdown()
    #expect(h.system.isVisible(f) && h.system.isVisible(a))
  }

  /// A run that did not quit cleanly leaves its windows where it had put them. A floating one is out of view only if that run's
  /// floating windows made way (or it was an earlier build): as Arbor ships none leaves the view.
  @Test(arguments: [true, false]) func aWindowLeftOutOfViewByACrashIsFetchedAndThenIgnored(wasDocked: Bool) {
    let first = Harness(settings: wasDocked ? Harness.settingsWhenNoneAreGiven : .makingWay)
    let own = CGRect(x: 300, y: 200, width: 500, height: 350)
    let f = first.system.open(app: "Finder", bundleID: finder, frame: own)
    let m = first.system.open(app: "Mail", bundleID: mail)
    first.start()
    if wasDocked { first.run("dock \(f.rawValue) left") }
    first.run("dock \(m.rawValue) right")
    first.run("zoom \(m.rawValue)")
    first.controller.saveNow()
    #expect(!first.system.isVisible(f))

    let again = harness([AppRule(app: finder, action: .ignore)], saved: first.store.saved)
    for window in [f, m] {
      let old = first.controller.windows[window]!
      again.system.open(app: old.appName, bundleID: old.bundleID, title: old.title, frame: old.frame)
    }
    again.start()
    #expect(again.controller.filter.ignoredWindowIDs == [f])
    #expect(!again.workspace.contains(f))
    #expect(again.frame(f) == own, "where it was before Arbor arranged it")
    let moves = again.system.frameLog.filter { $0.window == f }.count
    again.run("show-all")
    again.run("arrange")
    again.scheduler.runPending()
    again.controller.shutdown()
    #expect(again.system.frameLog.filter { $0.window == f }.count == moves, "and from then on it is left alone")
  }

  private static let own = CGRect(x: 300, y: 200, width: 500, height: 350)
  private static let belowTheDisplay = CGRect(x: 341, y: 1317, width: 500, height: 350)
  private static let other = DisplaySnapshot(
    id: DisplayID("other"), frame: CGRect(x: 0, y: 0, width: 1280, height: 800),
    visibleFrame: CGRect(x: 0, y: 25, width: 1280, height: 775), isMain: true)

  /// What a run that did not quit cleanly leaves: Finder docked (or floating), out of view in the corner, and saved
  /// so. `change` is applied to the window as the next run finds it. `before` are the first run's displays. Floating, it is
  /// left by a run whose floating windows made way (or an earlier build): as Arbor ships none leaves the view.
  private func afterACrash(
    docked: Bool = true, before: [DisplaySnapshot] = [FakeWindowSystem.standardDisplay],
    displays: [DisplaySnapshot] = [FakeWindowSystem.standardDisplay], bundleID: String = finder,
    _ change: (FakeWindowSystem, WindowID) -> Void = { _, _ in }
  ) -> (Harness, WindowID) {
    let first = Harness(displays: before, settings: docked ? Harness.settingsWhenNoneAreGiven : .makingWay)
    let f = first.system.open(app: "Finder", bundleID: finder, pid: 2000, frame: Self.own)
    let m = first.system.open(app: "Mail", bundleID: mail)
    first.start()
    if docked { first.run("dock \(f.rawValue) left") }
    first.run("dock \(m.rawValue) right")
    first.run("zoom \(m.rawValue)")
    first.controller.saveNow()
    #expect(first.controller.parked.contains(f), "or nothing is left out of view")
    let again = harness([AppRule(app: bundleID, action: .ignore)], saved: first.store.saved)
    again.system.displayList = displays
    for window in [f, m] {
      let old = first.controller.windows[window]!
      again.system.open(
        app: old.appName, bundleID: window == f ? bundleID : old.bundleID, title: old.title, pid: old.pid,
        frame: old.frame)
    }
    change(again.system, f)
    again.start()
    return (again, f)
  }

  @Test func aWindowMinimizedOutOfViewIsFetchedToo() {
    let (h, f) = afterACrash { $0.setMinimized($1, true) }
    #expect(h.controller.filter.ignoredWindowIDs == [f])
    h.system.setMinimized(f, false)
    #expect(h.system.isVisible(f))
  }

  /// Its display is not there any more either. It has the size it had before Arbor gave it that of a slot: once it is
  /// ignored nothing will give it back.
  @Test func leftOutOfViewOnADisplayThatIsGoneItComesBackOnAnotherAsItWas() {
    let (h, f) = afterACrash(displays: [Self.other])
    #expect(h.controller.filter.ignoredWindowIDs == [f])
    #expect(h.frame(f) == Self.own)
  }

  /// The same while Arbor runs: the arrangement that remembers the window is that of the display that went.
  @Test func comeAcrossOnAnotherDisplayItComesBackAsItWas() {
    let h = harness([])
    let a = h.system.open(app: "Safari")
    let f = h.system.open(app: "Finder", bundleID: finder, frame: Self.own)
    h.start()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(f.rawValue) right")
    h.run("zoom \(a.rawValue)")
    var settings = h.controller.settings
    settings.rules = [AppRule(app: finder, action: .ignore)]
    h.controller.apply(settings: settings)
    h.system.setDisplays([])
    h.scheduler.runPending()
    h.system.setDisplays([Self.other])
    h.scheduler.runPending()
    #expect(h.controller.filter.ignoredWindowIDs == [f] && !h.controller.parked.contains(f))
    #expect(h.frame(f) == Self.own)
  }

  /// Saved with no display connected, so only the arrangement of a display that is gone lists the window; and on
  /// the display that is there now its corner is nowhere special.
  @Test func anArrangementOfADisplayThatWasGoneAlreadyCountsToo() {
    let first = Harness()
    let f = first.system.open(app: "Finder", bundleID: finder, frame: Self.own)
    let m = first.system.open(app: "Mail", bundleID: mail)
    first.start()
    first.run("dock \(f.rawValue) left")
    first.run("dock \(m.rawValue) right")
    first.run("zoom \(m.rawValue)")
    first.system.setDisplays([])
    first.scheduler.runPending()
    first.controller.saveNow()
    #expect(first.store.saved?.workspaces.isEmpty == true)

    let again = harness([AppRule(app: finder, action: .ignore)], saved: first.store.saved)
    again.system.displayList = [Self.other]
    for window in [f, m] {
      let old = first.controller.windows[window]!
      again.system.open(app: old.appName, bundleID: old.bundleID, title: old.title, frame: old.frame)
    }
    again.start()
    #expect(again.controller.filter.ignoredWindowIDs == [f])
    #expect(again.frame(f) == Self.own)
  }

  // MARK: A window in Arbor's corner was put there by Arbor, whatever else is known

  /// On a Space that was not showing when Arbor started, so it appears later, like a new window. (Docked, its slot
  /// waits for it and takes it back.)
  @Test func aWindowLeftOutOfViewOnAnotherSpaceIsFetchedWhenItAppears() {
    let (h, f) = afterACrash(docked: false) { $0.setListed($1, false) }
    h.scheduler.runPending()
    h.system.setListed(f, true)
    h.scheduler.runPending()
    #expect(h.controller.filter.ignoredWindowIDs == [f])
    #expect(h.system.isVisible(f))
  }

  /// Its app started again since, and put its window back where it last was.
  @Test func theSameWindowUnderAnotherNumberIsFetched() {
    let first = Harness()
    let f = first.system.open(app: "Finder", bundleID: finder, frame: Self.own)
    let m = first.system.open(app: "Mail", bundleID: mail)
    first.start()
    first.run("dock \(f.rawValue) left")
    first.run("dock \(m.rawValue) right")
    first.run("zoom \(m.rawValue)")
    first.controller.saveNow()
    let again = harness([AppRule(app: finder, action: .ignore)], saved: first.store.saved)
    var renumbered: [WindowID] = []
    for window in [m, f] {
      let old = first.controller.windows[window]!
      renumbered.append(again.system.open(app: old.appName, bundleID: old.bundleID, title: old.title, frame: old.frame))
    }
    #expect(renumbered == [f, m], "each has the other's number now")
    again.start()
    #expect(again.controller.filter.ignoredWindowIDs == [m])
    let frame = again.frame(m)!
    #expect(abs(frame.midX - again.visibleFrame.midX) <= 1 && abs(frame.midY - again.visibleFrame.midY) <= 1, "\(frame)")
  }

  /// Between two displays no corner is out of view altogether: a strip of the window shows on a neighbour.
  @Test func moreThanASliverShowingOnANeighbourIsNoReasonToLeaveItThere() {
    func display(_ id: String, x: CGFloat) -> DisplaySnapshot {
      DisplaySnapshot(
        id: DisplayID(id), frame: CGRect(x: x, y: 0, width: 1440, height: 900),
        visibleFrame: CGRect(x: x, y: 25, width: 1440, height: 875), isMain: false)
    }
    let all = [FakeWindowSystem.standardDisplay, display("left", x: -1440), display("right", x: 1440)]
    let (h, f) = afterACrash(before: all, displays: all)
    #expect(h.controller.filter.ignoredWindowIDs == [f])
    #expect(h.frame(f) == Self.own)
  }

  // MARK: While it cannot be brought back it is not ignored

  @Test(arguments: [true, false]) func anAppThatDoesNotAnswerKeepsItsWindowArranged(docked: Bool) {
    let (h, f) = afterACrash(docked: docked) { system, _ in system.setUnresponsive(pid: 2000, true) }
    #expect(h.controller.filter.ignoredWindowIDs.isEmpty && h.workspace.contains(f))
    h.system.setUnresponsive(pid: 2000, false)
    h.scheduler.runPending()
    h.controller.shutdown()
    #expect(h.frame(f) == Self.own)
  }

  /// Come across in no arrangement, it floats meanwhile. It still counts as out of view, so it is not left in the
  /// corner as if somebody had put it there.
  @Test func anAppThatDoesNotAnswerWhenADisplayComesHasItsWindowInViewOnceItDoes() {
    let h = harness([])
    let a = h.system.open(app: "Safari")
    let f = h.system.open(app: "Finder", bundleID: finder, pid: 2000, frame: Self.own)
    h.start()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(f.rawValue) right")
    h.run("zoom \(a.rawValue)")
    var settings = h.controller.settings
    settings.rules = [AppRule(app: finder, action: .ignore)]
    h.controller.apply(settings: settings)
    h.system.setDisplays([])
    h.scheduler.runPending()
    h.system.setUnresponsive(pid: 2000, true)
    h.system.setDisplays([Self.other])
    h.scheduler.runPending()
    #expect(h.controller.filter.ignoredWindowIDs.isEmpty && h.controller.parked.contains(f))
    h.system.setUnresponsive(pid: 2000, false)
    h.scheduler.runPending()
    #expect(h.system.isVisible(f))
  }

  /// macOS does not let a window in full screen be moved, and sends it back where it was when that ends.
  @Test func aWindowInFullScreenThatWouldGoBackToTheCornerIsNotIgnoredYet() {
    let h = harness([])
    let a = h.system.open(app: "Safari")
    let f = h.system.open(app: "Finder", bundleID: finder, frame: Self.own)
    h.start()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(f.rawValue) right")
    h.run("zoom \(a.rawValue)")
    var settings = h.controller.settings
    settings.rules = [AppRule(app: finder, action: .ignore)]
    h.controller.apply(settings: settings)
    h.system.setFullScreen(f, true)
    h.scheduler.runPending()
    h.system.setDisplays([])
    h.scheduler.runPending()
    h.system.setDisplays([Self.other])
    h.scheduler.runPending()
    #expect(h.controller.filter.ignoredWindowIDs.isEmpty)
    h.system.setFullScreen(f, false)
    h.scheduler.runPending()
    h.controller.shutdown()
    #expect(h.system.isVisible(f))
  }

  /// Found by the chaos lab in the first version of the fix. Out of view is where its app or its user put it.
  @Test(arguments: [CGRect(x: 341, y: 1317, width: 500, height: 350), CGRect(x: 1340, y: 300, width: 500, height: 350)])
  func aWindowArborNeverArrangedIsLeftWhereItIs(frame: CGRect) {
    let first = harness([AppRule(app: finder, action: .ignore)])
    first.start()
    let f = first.system.open(app: "Finder", bundleID: finder, frame: frame)
    first.controller.shutdown()
    let again = harness([AppRule(app: finder, action: .ignore)], saved: first.store.saved)
    again.system.open(app: "Finder", bundleID: finder, frame: frame)
    again.start()
    #expect(again.controller.filter.ignoredWindowIDs == [f])
    for h in [first, again] { #expect(h.system.frameLog.allSatisfy { $0.window != f }) }
  }

  /// After a reboot the number can belong to a window the last run never saw, out of view by its own doing.
  @Test func aSavedNumberThatIsAnotherAppsNowSaysNothing() {
    let (h, f) = afterACrash(bundleID: "com.example.other") { $0.userMove($1, to: Self.belowTheDisplay) }
    #expect(h.controller.filter.ignoredWindowIDs == [f])
    #expect(h.system.frameLog.allSatisfy { $0.window != f })
  }

  /// Earlier versions could save a window without its app (one that closed while only the arrangement of a display
  /// that was gone listed it).
  @Test func aSavedNumberWithNothingToTellWhoseItWasSaysNothing() throws {
    let first = Harness()
    let a = first.system.open(app: "Safari")
    let n = first.system.open(app: "Notes", frame: Self.own)
    first.start()
    first.run("dock \(a.rawValue) left")
    first.run("dock \(n.rawValue) right")
    first.controller.shutdown()
    var saved = try #require(first.store.saved)
    #expect(saved.workspaces.values.contains { $0.contains(n) })
    saved.hints[n] = nil

    let again = harness([AppRule(app: finder, action: .ignore)], saved: saved)
    again.system.open(app: "Safari")
    #expect(again.system.open(app: "Finder", bundleID: finder, frame: Self.belowTheDisplay) == n)
    again.start()
    #expect(again.controller.filter.ignoredWindowIDs == [n])
    #expect(again.system.frameLog.allSatisfy { $0.window != n })
  }

  /// Once it is ignored it is out of the saved arrangement, so the next launch has no reason to touch it.
  @Test func itIsFetchedOnce() {
    let (h, f) = afterACrash()
    #expect(h.system.isVisible(f))
    h.system.userMove(f, to: CGRect(x: 341, y: 1317, width: 500, height: 350))
    h.controller.shutdown()
    let next = harness([AppRule(app: finder, action: .ignore)], saved: h.store.saved)
    next.system.open(app: "Finder", bundleID: finder, frame: h.frame(f)!)
    next.start()
    #expect(next.controller.filter.ignoredWindowIDs == [f])
    #expect(next.system.frameLog.allSatisfy { $0.window != f })
  }

  @Test func startedWithoutADisplayAWindowInNobodysArrangementIsIgnoredAtOnce() {
    let h = harness([AppRule(app: finder, action: .ignore)])
    let f = h.system.open(app: "Finder", bundleID: finder, frame: CGRect(x: 400, y: 300, width: 500, height: 350))
    h.system.displayList = []
    h.start()
    #expect(h.controller.filter.ignoredWindowIDs == [f])
    h.system.setDisplays([FakeWindowSystem.standardDisplay])
    h.scheduler.runPending()
    #expect(h.system.frameLog.allSatisfy { $0.window != f })
  }

  /// The last run quit cleanly, so the window is where its user has it. With no display nothing shows that.
  @Test(arguments: [true, false])
  func startedWithoutADisplayAWindowTheLastRunArrangedIsJudgedWhenOneComes(theSameDisplay: Bool) {
    let first = Harness()
    let f = first.system.open(app: "Finder", bundleID: finder, frame: Self.own)
    first.start()
    first.run("dock \(f.rawValue) left")
    first.controller.shutdown()
    #expect(first.frame(f) == Self.own)

    let again = harness([AppRule(app: finder, action: .ignore)], saved: first.store.saved)
    again.system.displayList = []
    again.system.open(app: "Finder", bundleID: finder, frame: Self.own)
    again.start()
    #expect(again.controller.filter.ignoredWindowIDs.isEmpty && again.controller.parked.isEmpty)
    again.system.setDisplays([theSameDisplay ? FakeWindowSystem.standardDisplay : Self.other])
    again.scheduler.runPending()
    #expect(again.controller.filter.ignoredWindowIDs == [f])
    #expect(again.controller.workspaces.values.allSatisfy { !$0.contains(f) })
    #expect(again.system.frameLog.allSatisfy { $0.window != f }, "it was in view all along")
  }

  @Test func startedWithoutADisplayAWindowLeftOutOfViewWaitsForOne() {
    let (h, f) = afterACrash(displays: [])
    #expect(h.controller.filter.ignoredWindowIDs.isEmpty, "there is nowhere to fetch it to yet")
    h.system.setDisplays([FakeWindowSystem.standardDisplay])
    h.scheduler.runPending()
    #expect(h.workspace.contains(f) || h.system.isVisible(f))
    h.controller.shutdown()
    #expect(h.system.isVisible(f))
  }

  // MARK: The same for an app that was excluded by hand while Arbor was not running

  /// As `afterACrash`, with Finder excluded in settings.json instead of ignored by a rule.
  private func excludedAfterACrash(docked: Bool, _ change: (FakeWindowSystem, WindowID) -> Void = { _, _ in }) -> (Harness, WindowID) {
    let first = Harness(settings: docked ? Harness.settingsWhenNoneAreGiven : .makingWay)
    let f = first.system.open(app: "Finder", bundleID: finder, pid: 2000, frame: Self.own)
    let m = first.system.open(app: "Mail", bundleID: mail)
    first.start()
    if docked { first.run("dock \(f.rawValue) left") }
    first.run("dock \(m.rawValue) right")
    first.run("zoom \(m.rawValue)")
    first.controller.saveNow()
    #expect(!first.system.isVisible(f))
    var settings = Settings()
    settings.excludedBundleIDs = [finder]
    let again = Harness(settings: settings, saved: first.store.saved)
    for window in [f, m] {
      let old = first.controller.windows[window]!
      again.system.open(app: old.appName, bundleID: old.bundleID, title: old.title, pid: old.pid, frame: old.frame)
    }
    change(again.system, f)
    again.start()
    return (again, f)
  }

  @Test(arguments: [true, false]) func aWindowLeftOutOfViewWhoseAppIsExcludedNowIsFetchedOnce(docked: Bool) {
    let (h, f) = excludedAfterACrash(docked: docked)
    #expect(h.frame(f) == Self.own, "where it was before Arbor arranged it")
    #expect(!h.workspace.contains(f) && !h.controller.parked.contains(f))
    let moves = h.system.frameLog.filter { $0.window == f }.count
    #expect(moves == 1)
    h.run("show-all")
    h.run("arrange")
    h.scheduler.runPending()
    h.controller.shutdown()
    #expect(h.system.frameLog.filter { $0.window == f }.count == moves, "and from then on it is left alone")
  }

  /// Out of view is where its app or its user put it, and Arbor has no business with it.
  @Test func aWindowOfAnExcludedAppThatArborNeverArrangedIsLeftWhereItIs() {
    var settings = Settings()
    settings.excludedBundleIDs = [finder]
    let h = Harness(settings: settings)
    let f = h.system.open(app: "Finder", bundleID: finder, frame: Self.belowTheDisplay)
    h.start()
    h.controller.shutdown()
    #expect(h.system.frameLog.allSatisfy { $0.window != f })
  }

  @Test func inViewItIsLeftWhereItIs() {
    let (h, f) = excludedAfterACrash(docked: true) { $0.userMove($1, to: CGRect(x: 700, y: 300, width: 464, height: 400)) }
    #expect(h.system.frameLog.allSatisfy { $0.window != f })
  }

  @Test func onlyAWindowsFirstMatchingRuleCounts() {
    let h = harness([
      AppRule(app: finder, title: "Downloads", action: .dock(.left)),
      AppRule(app: finder, title: "Trash", action: .ignore),
      AppRule(app: mail, action: .dock(.right)), AppRule(app: mail, action: .ignore),
    ])
    let downloads = h.system.open(app: "Finder", bundleID: finder, title: "Downloads")
    let trash = h.system.open(app: "Finder", bundleID: finder, title: "Trash")
    let other = h.system.open(app: "Finder", bundleID: finder, title: "Documents")
    let m = h.system.open(app: "Mail", bundleID: mail)
    h.start()
    #expect(h.controller.filter.ignoredWindowIDs == [trash])
    for window in [downloads, other, m] {
      #expect(h.workspace.isFloating(window), "the other actions still apply only to new windows")
    }
    #expect(h.system.frameLog.isEmpty)
  }

  @Test func theRulesCommandExplainsIt() throws {
    let h = harness([AppRule(app: finder, action: .ignore)])
    let f = h.system.open(app: "Finder", bundleID: finder)
    h.start()
    h.system.userFocus(f)
    let text = try #require(h.run("rules").text)
    #expect(text.contains("Arbor is leaving it alone: an ignore rule matched it."))
  }

  /// Otherwise it would float until the next restart and be ignored after it.
  @Test func includingAnAppAgainStillIgnoresWhatARuleIgnores() {
    let h = harness([AppRule(app: finder, title: "Trash", action: .ignore)]) {
      $0.excludedBundleIDs = [finder]
    }
    let trash = h.system.open(app: "Finder", bundleID: finder, title: "Trash")
    let other = h.system.open(app: "Finder", bundleID: finder, title: "Documents")
    h.start()
    #expect(h.controller.filter.ignoredWindowIDs.isEmpty, "exclusion comes first")
    #expect(h.run("include \(finder)").ok)
    #expect(h.controller.filter.ignoredWindowIDs == [trash])
    #expect(!h.workspace.contains(trash) && h.workspace.isFloating(other))
  }

  /// The Accessibility layer records some windows without announcing them (an app that was slow to
  /// answer at login). Arbor first hears of them when they change.
  @Test func aWindowThatWasNeverAnnouncedIsIgnoredToo() {
    let h = harness([AppRule(app: finder, action: .ignore)])
    h.start()
    func report(_ id: UInt32, bundleID: String) -> WindowID {
      h.controller.windowChanged(
        WindowSnapshot(
          id: WindowID(id), pid: 1000, bundleID: bundleID, appName: "App", title: "Window",
          frame: CGRect(x: 300, y: 200, width: 640, height: 420)), userInitiated: true)
      return WindowID(id)
    }
    let f = report(501, bundleID: finder)
    let m = report(502, bundleID: mail)
    #expect(h.controller.filter.ignoredWindowIDs == [f])
    #expect(!h.workspace.contains(f) && h.workspace.isFloating(m))
  }
}

/// QUESTIONS Q3: a rule with a `title` also sees the titles a new window takes in its first
/// `ruleTitleWait` seconds.
@Suite @MainActor struct LateTitleTests {
  let inbox = AppRule(app: mail, title: "Inbox", action: .dock(.left))

  @Test func aLateTitleBringsItsRuleIntoPlay() {
    let h = harness([inbox])
    h.start()
    let m = h.system.open(app: "Mail", bundleID: mail, title: "")
    #expect(h.workspace.isFloating(m))
    h.system.setTitle(m, "Loading…")
    #expect(h.workspace.isFloating(m))
    h.system.setTitle(m, "Inbox – 3 messages")
    #expect(columns(h) == [[m], []])
    #expect(h.frame(m) == h.layout?.windowFrames[m])
    #expect(titleWaits(h).isEmpty, "no rule ranks above the one that matched")
  }

  @Test func afterTheWaitTitlesNoLongerMatter() {
    let h = harness([inbox])
    h.start()
    let m = h.system.open(app: "Mail", bundleID: mail, title: "")
    h.scheduler.advance(by: 2)
    h.system.setTitle(m, "Inbox")
    #expect(h.workspace.isFloating(m))
  }

  @Test func untilTheWaitIsOverTitlesMatter() {
    let h = harness([inbox])
    h.start()
    let m = h.system.open(app: "Mail", bundleID: mail, title: "")
    h.scheduler.advance(by: 1.9)
    h.system.setTitle(m, "Inbox")
    #expect(h.workspace.isDocked(m))
  }

  @Test func aWaitOfZeroChecksOnlyTheFirstTitle() {
    let h = harness([inbox]) { $0.ruleTitleWait = 0 }
    h.start()
    let late = h.system.open(app: "Mail", bundleID: mail, title: "")
    #expect(titleWaits(h).isEmpty)
    h.system.setTitle(late, "Inbox")
    #expect(h.workspace.isFloating(late))
    let early = h.system.open(app: "Mail", bundleID: mail, title: "Inbox")
    #expect(h.workspace.isDocked(early))
  }

  @Test(arguments: [1e300, Double.infinity, 61]) func theWaitIsAtMostAMinute(wait: Double) {
    let h = harness([inbox]) { $0.ruleTitleWait = wait }
    h.start()
    h.system.open(app: "Mail", bundleID: mail, title: "")
    h.scheduler.advance(by: 59.9)
    #expect(!titleWaits(h).isEmpty)
    h.scheduler.advance(by: 0.2)
    #expect(titleWaits(h).isEmpty)
  }

  @Test(arguments: [-1, -1e300, Double.nan]) func aWaitThatMakesNoSenseIsNoWait(wait: Double) {
    let h = harness([inbox]) { $0.ruleTitleWait = wait }
    h.start()
    h.system.open(app: "Mail", bundleID: mail, title: "")
    #expect(titleWaits(h).isEmpty)
  }

  @Test func nothingWaitsWithoutARuleThatCouldStillMatch() {
    let h = harness([
      AppRule(app: mail, action: .float), inbox, AppRule(app: finder, title: "Trash", action: .ignore),
    ])
    h.start()
    // Mail's first rule has no title and already matched; Safari has no rule at all.
    let m = h.system.open(app: "Mail", bundleID: mail, title: "")
    let s = h.system.open(app: "Safari", title: "")
    #expect(titleWaits(h).isEmpty)
    h.system.setTitle(m, "Inbox")
    h.system.setTitle(s, "Inbox Trash")
    #expect(h.workspace.isFloating(m) && h.workspace.isFloating(s), "a rule further down never takes over")
  }

  @Test func aLateTitleOutranksTheRuleThatMatchedAtFirst() {
    let h = harness([inbox, AppRule(app: mail, action: .dock(.right))])
    h.start()
    let m = h.system.open(app: "Mail", bundleID: mail, title: "")
    #expect(columns(h) == [[], [m]])
    h.system.setTitle(m, "Inbox")
    #expect(columns(h) == [[m], []])
    #expect(h.workspace.tree.invariantViolations().isEmpty)
  }

  @Test func aLateTitleCanUndockAgain() {
    let h = harness([
      AppRule(app: mail, title: "Compose", action: .float), AppRule(app: mail, action: .dock(.right)),
    ])
    h.start()
    let m = h.system.open(app: "Mail", bundleID: mail, title: "")
    #expect(h.workspace.isDocked(m))
    h.system.setTitle(m, "Compose: hello")
    #expect(h.workspace.isFloating(m))
    #expect(h.workspace.tree.allWindows.isEmpty)
    #expect(h.system.isVisible(m))
  }

  @Test func eachBetterMatchTakesOverUntilNoneIsLeft() {
    let h = harness([
      AppRule(app: mail, title: "Urgent", action: .dock(.top)), inbox,
      AppRule(app: mail, title: "Compose", action: .dock(.right)),
    ])
    h.start()
    let m = h.system.open(app: "Mail", bundleID: mail, title: "")
    h.system.setTitle(m, "Inbox")
    #expect(columns(h) == [[m], []])
    #expect(titleWaits(h).count == 1, "the rule above could still match")
    let leaf = h.workspace.tree.leaf(containing: m)
    h.system.setTitle(m, "Inbox again")
    #expect(h.workspace.tree.leaf(containing: m) == leaf, "the same rule is not applied twice")
    h.system.setTitle(m, "Compose")
    #expect(columns(h) == [[m], []], "a rule further down never takes over from a better one")
    h.system.setTitle(m, "Inbox: Urgent")
    guard case .split(.vertical, let rows) = h.workspace.tree[h.workspace.tree.root]?.kind else {
      Issue.record("the window should be docked at the top")
      return
    }
    #expect(h.workspace.tree.windows(under: rows[0]) == [m])
    #expect(titleWaits(h).isEmpty)
  }

  @Test func aLateTitleCanEndAnIgnore() {
    let h = harness([
      AppRule(app: finder, title: "Downloads", action: .dock(.left)), AppRule(app: finder, action: .ignore),
    ])
    h.start()
    let f = h.system.open(app: "Finder", bundleID: finder, title: "")
    #expect(h.controller.filter.ignoredWindowIDs == [f])
    h.system.setTitle(f, "Downloads")
    #expect(h.controller.filter.ignoredWindowIDs.isEmpty)
    #expect(columns(h) == [[f], []])
  }

  @Test func aLateTitleCanStartAnIgnore() {
    let h = harness([
      AppRule(app: finder, title: "Trash", action: .ignore), AppRule(app: finder, action: .dock(.right)),
    ])
    let (a, b) = (h.system.open(app: "Safari"), h.system.open(app: "Notes"))
    h.start()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) right")
    let f = h.system.open(app: "Finder", bundleID: finder, title: "")
    #expect(columns(h) == [[a], [], [b], [f]])
    let narrow = h.frame(a)!.width
    h.system.setTitle(f, "Trash")
    #expect(h.controller.filter.ignoredWindowIDs == [f])
    #expect(columns(h) == [[a], [], [b]])
    // Two are left. (One left alone would stay as it is, and the room would be the Desktop's.)
    #expect(
      h.frame(a)!.width > narrow && h.frame(a) == h.layout?.windowFrames[a],
      "the others take its space at once")
    #expect(h.system.isVisible(f))
    h.system.clearFrameLog()
    h.run("zoom \(a.rawValue)")
    h.run("back")
    #expect(h.system.frameLog.allSatisfy { $0.window != f }, "left alone from here on")
  }

  /// It floated while the camera was elsewhere and was parked when the camera moved.
  /// Floating windows that make way: only they leave with the Desktop.
  @Test func aWindowThatWasParkedComesBackIntoViewWhenItIsIgnored() {
    let h = harness([AppRule(app: finder, title: "Trash", action: .ignore)]) { $0.floatingWindowsMakeWay = true }
    let a = h.system.open(app: "Safari")
    let b = h.system.open(app: "Notes")
    h.start()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) right")
    let f = h.system.open(app: "Finder", bundleID: finder, title: "")
    h.run("zoom \(a.rawValue)")
    #expect(!h.system.isVisible(f))
    h.system.setTitle(f, "Trash")
    #expect(h.controller.filter.ignoredWindowIDs == [f])
    #expect(h.system.isVisible(f), "an ignored window must not be left out of view")
  }

  /// As Arbor ships the camera took it nowhere: it is ignored where it floats.
  @Test func aWindowThatFloatsOverAFramedOneIsIgnoredWhereItIs() {
    let h = harness([AppRule(app: finder, title: "Trash", action: .ignore)])
    let a = h.system.open(app: "Safari")
    let b = h.system.open(app: "Notes")
    h.start()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) right")
    let f = h.system.open(app: "Finder", bundleID: finder, title: "")
    let place = h.frame(f)
    h.run("zoom \(a.rawValue)")
    #expect(h.frame(f) == place && !h.controller.parked.contains(f))
    h.system.setTitle(f, "Trash")
    #expect(h.controller.filter.ignoredWindowIDs == [f])
    #expect(h.frame(f) == place)
  }

  /// The new window is docked and has the focus, so it is its app's most recently focused docked window.
  @Test func dockBesideItsOwnAppNeverMeansBesideItself() {
    let h = harness([
      AppRule(app: mail, title: "Inbox", action: .dockBeside(bundleID: mail, .bottom)),
      AppRule(app: mail, action: .dock(.right)),
    ])
    let old = h.system.open(app: "Mail", bundleID: mail, title: "Archive")
    h.start()
    h.run("dock \(old.rawValue) left")
    let m = h.system.open(app: "Mail", bundleID: mail, title: "")
    h.system.userFocus(m)
    #expect(columns(h) == [[old], [], [m]])
    h.system.setTitle(m, "Inbox")
    #expect(columns(h) == [[old, m], []])
    #expect(h.workspace.tree.invariantViolations().isEmpty)
  }

  // MARK: The same result as if the title had been there from the start

  /// A window docked as it opens is revealed when its app then focuses it. Here the focus came first.
  @Test func aLateDockDoesNotLeaveTheFocusedWindowOutOfView() {
    let h = harness([inbox])
    h.start()
    let m = h.system.open(
      // More than the Desktop beside it could spare (F61).
      app: "Mail", bundleID: mail, title: "", minimumSize: CGSize(width: 1400, height: 600))
    h.system.userFocus(m)
    h.system.setTitle(m, "Inbox")
    #expect(h.workspace.isDocked(m))
    #expect(
      h.system.isVisible(m) && h.layout?.windowFrames[m] == h.frame(m),
      "too large for its slot, so the camera goes to it")
  }

  @Test func theReportOfTheNewTitleDoesNotOverwriteWhatTheRuleDid() {
    let h = harness([inbox])
    h.start()
    let m = h.system.open(app: "Mail", bundleID: mail, title: "")
    h.scheduler.cancel("save")  // the one for the window opening
    h.system.setTitle(m, "Inbox")
    #expect(h.scheduler.pendingKeys.contains("save"))
    #expect(
      !h.scheduler.pendingKeys.contains { $0.hasPrefix("enforce-") },
      "the frame in the report is not a move by the user")
    h.scheduler.runPending()
    #expect(h.store.saved?.hints[m]?.title == "Inbox", "the title it is matched by after a restart")
  }

  @Test(arguments: [RuleAction.float, .ignore]) func aLateFloatOrIgnoreGoesBackToWhereTheWindowOpened(
    action: RuleAction
  ) {
    let h = harness([
      AppRule(app: mail, title: "Compose", action: action), AppRule(app: mail, action: .dock(.right)),
    ])
    h.start()
    let opened = CGRect(x: 800, y: 300, width: 500, height: 300)
    let m = h.system.open(app: "Mail", bundleID: mail, title: "", frame: opened)
    #expect(h.frame(m) != opened)
    h.system.setTitle(m, "Compose: hello")
    #expect(h.frame(m) == opened, "not the size of the slot it was in for a moment")
    #expect(h.workspace.tree.allWindows.isEmpty)
    if action == .float { #expect(h.workspace.floating[m] == opened) }
  }

  /// It became a tile, which parks it in a corner. That corner must not be remembered as its place.
  @Test func aLateFloatOfAWindowThatBecameATileComesBackIntoView() {
    let h = harness([
      AppRule(app: mail, title: "Compose", action: .float), AppRule(app: mail, action: .dock(.left)),
    ])
    let a = h.system.open(app: "Safari")
    h.start()
    h.run("dock \(a.rawValue) right")
    // More than Safari and the Desktop could spare between them (F61).
    let opened = CGRect(x: 200, y: 200, width: 1200, height: 600)
    // Opened without taking the keyboard: with it, the view would go to the window and it would not be parked.
    h.system.echoes.keyboard = false
    let m = h.system.open(app: "Mail", bundleID: mail, title: "", frame: opened, minimumSize: opened.size)
    #expect(!h.system.isVisible(m))
    h.system.setTitle(m, "Compose")
    #expect(h.system.isVisible(m))
    #expect(h.workspace.floating[m] == opened)
  }

  /// The usual case: the new window is focused, so the view went to it before its title came.
  @Test func aLateFloatOfAWindowTheViewWentToIsBackWhereItOpened() {
    let h = harness([
      AppRule(app: mail, title: "Compose", action: .float),
      AppRule(app: mail, action: .dockBeside(bundleID: "com.example.safari", .right)),
    ])
    let docked = ["Safari", "Notes", "Maps"].map { h.system.open(app: $0) }
    h.start()
    h.run("dock \(docked[0].rawValue) left")
    for window in docked[1...] { h.run("dock \(window.rawValue) right") }
    // Three thirds. Half of Safari's is too narrow to show a window.
    let opened = CGRect(x: 200, y: 200, width: 1200, height: 600)
    let m = h.system.open(app: "Mail", bundleID: mail, title: "", frame: opened)
    #expect(h.system.isVisible(m))
    #expect(h.workspace.camera == h.workspace.tree.leaf(containing: m) && h.frame(m) != opened)
    h.system.setTitle(m, "Compose")
    #expect(h.system.isVisible(m))
    #expect(h.frame(m) == opened, "\(h.ascii())")
    #expect(h.workspace.floating[m] == opened)
  }

  // MARK: What the user arranges is not for a rule to undo

  @Test(arguments: [
    "dock %@ right", "float %@", "toggle-float %@", "zoom %@", "arrange", "arrange all", "float-all",
    "float-all here",
  ])
  func aCommandAimedAtTheWindowEndsTheWait(command: String) {
    let h = harness([inbox])
    let a = h.system.open(app: "Safari")
    h.start()
    h.run("dock \(a.rawValue) top")
    let m = h.system.open(app: "Mail", bundleID: mail, title: "")
    #expect(titleWaits(h).count == 1)
    h.run(command.replacingOccurrences(of: "%@", with: String(m.rawValue)))
    #expect(titleWaits(h).isEmpty)
    let arranged = h.workspace
    h.system.setTitle(m, "Inbox")
    #expect(h.workspace == arranged)
  }

  @Test func commandsAboutOtherThingsDoNot() {
    let h = harness([inbox])
    let a = h.system.open(app: "Safari")
    h.start()
    let m = h.system.open(app: "Mail", bundleID: mail, title: "")
    for command in ["dock \(a.rawValue) right", "show-all", "state", "rules", "resize \(a.rawValue) left 20"]
    { h.run(command) }
    #expect(titleWaits(h).count == 1)
    h.system.setTitle(m, "Inbox")
    #expect(h.workspace.isDocked(m))
  }

  @Test func aDropEndsTheWaitWhateverTitlesFollow() {
    let h = harness([inbox])
    h.start()
    let m = h.system.open(app: "Mail", bundleID: mail, title: "")
    let start = h.frame(m)!
    h.system.tiling = .off  // the screen's edges are Arbor's only with macOS's tiling off
    h.system.drag(m, through: [CGPoint(x: start.midX, y: start.minY + 10), CGPoint(x: 1437, y: 450)])
    #expect(columns(h) == [[], [m]])
    h.system.setTitle(m, "Inbox (1 unread)")
    #expect(columns(h) == [[], [m]])
  }

  @Test func draggingAnIgnoredWindowEndsItsWaitToo() {
    let h = harness([
      AppRule(app: finder, title: "Downloads", action: .dock(.left)), AppRule(app: finder, action: .ignore),
    ])
    h.start()
    let f = h.system.open(app: "Finder", bundleID: finder, title: "")
    h.system.heldModifiers = DragDocks.key
    h.controller.dragBegan(f, at: CGPoint(x: 600, y: 210))
    h.system.setTitle(f, "Downloads")
    #expect(h.controller.filter.ignoredWindowIDs == [f])
    #expect(titleWaits(h).isEmpty)
  }

  @Test func resizingTheWindowByItsEdgesEndsTheWait() {
    let h = harness([
      AppRule(app: mail, title: "Inbox", action: .dock(.left)), AppRule(app: mail, action: .dock(.right)),
    ])
    h.start()
    let m = h.system.open(app: "Mail", bundleID: mail, title: "")
    var frame = h.frame(m)!
    frame.origin.x -= 100
    frame.size.width += 100
    h.system.userResize(m, to: frame)
    h.system.setTitle(m, "Inbox")
    #expect(columns(h) == [[], [m]])
  }

  @Test func nothingIsRearrangedWhileTheMouseIsArrangingSomethingElse() {
    let h = harness([inbox])
    let a = h.system.open(app: "Safari")
    h.start()
    h.run("dock \(a.rawValue) right")
    let m = h.system.open(app: "Mail", bundleID: mail, title: "")
    h.system.heldModifiers = DragDocks.key
    h.controller.dragBegan(a, at: CGPoint(x: 1000, y: 50))
    h.system.clearFrameLog()
    h.system.setTitle(m, "Inbox")
    #expect(h.workspace.isFloating(m) && h.system.frameLog.isEmpty)
    h.controller.dragEnded(a, at: CGPoint(x: 1000, y: 50))
    h.system.setTitle(m, "Inbox (2)")
    #expect(h.workspace.isDocked(m), "the next title within the wait still counts")
  }

  @Test func aWindowThatTakesNoSpaceIsLeftAlone() {
    let h = harness([inbox])
    let a = h.system.open(app: "Safari")
    h.start()
    h.run("dock \(a.rawValue) right")
    h.run("zoom \(a.rawValue)")
    let m = h.system.open(app: "Mail", bundleID: mail, title: "")
    h.system.setMinimized(m, true)
    let camera = h.workspace.camera
    h.system.setTitle(m, "Inbox")
    #expect(
      h.workspace.isFloating(m) && h.workspace.camera == camera,
      "docking it would widen the view for nothing to see")
  }

  /// The time runs from when the window opened: a page that keeps changing its title does not extend it.
  @Test func theWaitIsNotStartedAgainByEachMatch() {
    final class CountingScheduler: Scheduler {
      var scheduled: [String: Int] = [:]
      func schedule(_ key: String, after seconds: Double, _ action: @escaping @MainActor () -> Void) {
        scheduled[key, default: 0] += 1
      }
      func cancel(_ key: String) {}
    }
    var settings = Settings()
    settings.rules = [AppRule(app: mail, title: "Urgent", action: .dock(.top)), inbox]
    let system = FakeWindowSystem()
    let scheduler = CountingScheduler()
    let controller = Controller(
      system: system, overlays: FakeOverlays(), store: MemoryStateStore(), scheduler: scheduler,
      settings: settings,
      filter: WindowFilter(ownPID: 1))
    controller.start()
    let m = system.open(app: "Mail", bundleID: mail, title: "")
    system.setTitle(m, "Inbox")
    #expect(controller.workspaces.values.contains { $0.isDocked(m) })
    #expect(scheduler.scheduled["rule-title-\(m.rawValue)"] == 1)
  }

  @Test func windowsFoundAtLaunchAreNotWatched() {
    let h = harness([inbox])
    let m = h.system.open(app: "Mail", bundleID: mail, title: "")
    h.start()
    #expect(titleWaits(h).isEmpty)
    h.system.setTitle(m, "Inbox")
    #expect(h.workspace.isFloating(m))
  }

  @Test func closingTheWindowOrChangingTheSettingsEndsTheWait() {
    let h = harness([inbox])
    h.start()
    let closed = h.system.open(app: "Mail", bundleID: mail, title: "")
    #expect(titleWaits(h).count == 1)
    h.system.close(closed)
    #expect(titleWaits(h).isEmpty)

    let m = h.system.open(app: "Mail", bundleID: mail, title: "")
    var settings = h.controller.settings
    settings.rules.insert(AppRule(app: finder, action: .float), at: 0)
    h.controller.apply(settings: settings)
    #expect(titleWaits(h).isEmpty)
    h.system.setTitle(m, "Inbox")
    #expect(h.workspace.isFloating(m), "rules changed while a window is open do not rearrange it")
  }

  @Test func quittingEndsTheWaits() {
    let h = harness([inbox])
    h.start()
    h.system.open(app: "Mail", bundleID: mail, title: "")
    #expect(titleWaits(h).count == 1)
    h.controller.shutdown()
    #expect(titleWaits(h).isEmpty)
  }

  @Test func pausingEndsTheWaitsAndResumingDoesNotStartThemAgain() {
    let h = harness([inbox])
    h.start()
    let m = h.system.open(app: "Mail", bundleID: mail, title: "")
    #expect(titleWaits(h).count == 1)
    h.run("pause")
    #expect(titleWaits(h).isEmpty)
    h.system.setTitle(m, "Inbox")
    h.run("resume")
    #expect(titleWaits(h).isEmpty)
    #expect(h.workspace.isFloating(m), "to a resume, as to a launch, it is a window that was already open")
    h.system.setTitle(m, "Inbox – 3 messages")
    #expect(h.workspace.isFloating(m))
  }
}
