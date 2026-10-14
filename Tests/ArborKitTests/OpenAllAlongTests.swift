import ArborCore
import ArborKit
import ArborTesting
import CoreGraphics
import Testing

private let mail = "com.apple.mail"

/// Backlog K050. The Accessibility API lists only the windows of the macOS Spaces that show, so Arbor first hears of a
/// window on another Space when the user goes there. It has been open all along: rules are for windows that open.
@Suite @MainActor struct OpenAllAlongTests {
  let place = CGRect(x: 400, y: 300, width: 500, height: 350)

  func harness(_ rules: [AppRule], saved: PersistedState? = nil) -> Harness {
    var settings = Settings()
    settings.rules = rules
    return Harness(settings: settings, saved: saved)
  }

  /// Safari docked on the left; Mail open on a Space that does not show when Arbor starts.
  func makeHarness(_ rules: [AppRule]) -> (Harness, a: WindowID, m: WindowID) {
    let h = harness(rules)
    let a = h.system.open(app: "Safari", frame: CGRect(x: 100, y: 100, width: 600, height: 400))
    let m = h.system.open(app: "Mail", bundleID: mail, frame: place)
    h.system.setListed(m, false)
    h.start()
    h.run("dock \(a.rawValue) left")
    return (h, a, m)
  }

  @Test func aDockRuleDoesNotDockAWindowThatWasOpenBeforeArborStarted() {
    let (h, _, m) = makeHarness([AppRule(app: mail, action: .dock(.right))])
    h.system.setListed(m, true)
    h.scheduler.runPending()
    #expect(h.workspace.isFloating(m), "\(h.ascii())")
    #expect(h.frame(m) == place, "it is where it has been all along")
  }

  @Test func norDoesALateTitleBringARuleIntoPlay() {
    let (h, _, m) = makeHarness([AppRule(app: mail, title: "Inbox", action: .dock(.right))])
    h.system.setListed(m, true)
    h.system.setTitle(m, "Inbox")
    h.scheduler.runPending()
    #expect(h.workspace.isFloating(m))
    #expect(h.frame(m) == place)
  }

  @Test func aPinRuleDoesNotPinIt() {
    let (h, _, m) = makeHarness([AppRule(app: mail, action: .pin)])
    h.system.setListed(m, true)
    #expect(!h.controller.isPinned(m))
  }

  @Test func anIgnoreRuleStillApplies() {
    let (h, _, m) = makeHarness([AppRule(app: mail, action: .ignore)])
    h.system.setListed(m, true)
    #expect(h.controller.filter.ignoredWindowIDs == [m], "as for every window Arbor comes across rather than sees open")
    #expect(!h.workspace.contains(m))
  }

  @Test func itIsNoGuestOfTheFramedWindow() {
    let (h, a, m) = makeHarness([])
    h.run("zoom \(a.rawValue)")
    h.system.setListed(m, true)
    #expect(h.workspace.isFloating(m))
    #expect(h.workspace.guests?[m] == nil, "it did not open over Safari")
  }

  @Test func norIsAWindowThatOpenedOnAnotherSpaceWhileArborRan() {
    let (h, _, _) = makeHarness([AppRule(app: mail, action: .dock(.right))])
    // Mail opens a window on its own Space, where nobody is looking. Later the user goes there.
    let unseen = h.system.openUnlisted(app: "Mail", bundleID: mail, frame: place)
    h.system.setListed(unseen, true)
    #expect(h.workspace.isFloating(unseen))
    #expect(h.frame(unseen) == place)
  }

  @Test func afterAPauseWhatOpenedMeanwhileOnAnotherSpaceIsNotNew() {
    let (h, _, _) = makeHarness([AppRule(app: mail, action: .dock(.right))])
    h.run("pause")
    let meanwhile = h.system.openUnlisted(app: "Mail", bundleID: mail, frame: place)
    h.run("resume")
    h.system.setListed(meanwhile, true)
    #expect(h.workspace.isFloating(meanwhile))
  }

  @Test func oneLeftOutOfViewByACrashIsFetchedAndStaysInView() {
    let h = harness([
      AppRule(app: mail, title: "Login", action: .float), AppRule(app: mail, action: .dock(.left)),
    ])
    let lost = h.system.open(
      app: "Mail", bundleID: mail, title: "", frame: CGRect(x: 1439, y: 899, width: 600, height: 400))
    h.system.setListed(lost, false)
    h.start()
    h.system.setListed(lost, true)
    #expect(h.workspace.isFloating(lost))
    #expect(h.system.isVisible(lost), "\(h.frame(lost)!)")
    let fetched = h.frame(lost)!
    h.system.setTitle(lost, "Login")
    h.scheduler.runPending()
    #expect(h.frame(lost) == fetched)
  }

  @Test func aSavedSlotIsStillClaimed() {
    // Docked, saved, and on a Space that does not show when Arbor starts again: its slot waits for it.
    let first = harness([])
    let a = first.system.open(app: "Safari")
    let m = first.system.open(app: "Mail", bundleID: mail, frame: place)
    first.start()
    first.run("dock \(a.rawValue) left")
    first.run("dock \(m.rawValue) right")
    first.controller.shutdown()
    let h = harness([AppRule(app: mail, action: .float)], saved: first.store.saved)
    #expect(h.system.open(app: "Safari") == a)
    #expect(h.system.open(app: "Mail", bundleID: mail, frame: place) == m)
    h.system.setListed(m, false)
    h.start()
    h.system.setListed(m, true)
    #expect(h.workspace.isDocked(m), "\(h.ascii())")
  }

  @Test func aWindowSeenToOpenGetsItsRuleAsBefore() {
    let (h, _, m) = makeHarness([AppRule(app: mail, action: .dock(.right))])
    h.system.setListed(m, true)
    let new = h.system.open(app: "Mail", bundleID: mail, frame: place)
    #expect(h.workspace.isDocked(new))
    #expect(h.workspace.isFloating(m))
  }

  @Test func aWindowClosedAndOpenedAgainUnderItsOldNumberIsNew() {
    // Music, Notes, Calendar: one window, put away when it is closed and shown again under the same number.
    let (h, _, m) = makeHarness([AppRule(app: mail, action: .dock(.right))])
    h.system.setListed(m, true)
    let snapshot = h.system.windows[m]!.snapshot
    h.controller.windowDestroyed(m)
    h.controller.windowAppeared(snapshot)
    #expect(h.workspace.isDocked(m))
  }

  @Test func aListenerThatDoesNotCareHearsOfANewWindow() {
    let system = FakeWindowSystem()
    let listener = Listener()
    system.events = listener
    let m = system.open(app: "Mail")
    system.setListed(m, false)
    system.start()
    system.setListed(m, true)
    #expect(listener.appeared == [m])
  }
}

/// Implements only what the protocol insists on.
private final class Listener: WindowSystemEvents {
  var appeared: [WindowID] = []
  func windowAppeared(_ window: WindowSnapshot) { appeared.append(window.id) }
  func windowDestroyed(_ id: WindowID) {}
  func windowChanged(_ window: WindowSnapshot, userInitiated: Bool) {}
  func windowFocused(_ id: WindowID) {}
  func dragBegan(_ id: WindowID, at point: CGPoint) {}
  func dragMoved(_ id: WindowID, to point: CGPoint) {}
  func dragEnded(_ id: WindowID, at point: CGPoint) {}
  func displaysChanged() {}
  func resizeBegan(_ id: WindowID) {}
  func resizeEnded(_ id: WindowID) {}
  func keyboardFocusMoved() {}
  func dragCancelled(_ id: WindowID) {}
  func windowReplaced(_ old: WindowID, by window: WindowSnapshot) {}
  func pointerPressed() {}
}
