import ArborCore
import ArborKit
import CoreGraphics
import Foundation

// The rude fake (docs/REALITY.md, docs/TESTING.md "The rude fake").
//
// The fake is politer than macOS: it reports everything, once, in one order, and a window is where it was asked to be by the
// time `setFrame` returns. Every switch here takes one of those courtesies away, and each stands for something that was seen on
// a real Mac. None of them changes what the person, the apps or macOS DID, only how Arbor gets to hear of it. So Arbor has to
// end up where it ends up with the polite fake: a test that fails has found either a fault a Mac would have shown, or a
// test that pins a courtesy.
//
// Everything is a function of the seed. `ARBOR_RUDE=order,twice ARBOR_RUDE_SEED=3 swift test` makes every fake in the process rude
// (`make rude` goes through the manners one by one); a test of one manner sets `system.rudeness` itself.

/// The courtesies the fake can drop.
public struct Rudeness: Equatable, Sendable {
  /// The world runs ahead of the reports: by the time Arbor hears the first thing about a happening, all of it has happened. A new window has
  /// the keyboard and is in front before anybody says that it was created; a window that closes is gone before its app's next one is
  /// reported focused. The polite fake changes the world one report at a time.
  public var runsAhead = false
  /// What belongs to one happening is reported in any order the Accessibility layer can report it in. Apps keep to none: "the
  /// focus is on it" was seen to come a millisecond before "it was created", an app's activation before or after its focus.
  public var shufflesReports = false
  /// Reports come twice: "the keyboard moved", and a change of focus across apps, which macOS reports two to four times, of which the Accessibility layer lets a second one through after each activation, and none within one app.
  public var repeatsReports = false
  /// `setFrame` answers before the app has done it: the frame read back is the old one, or has only the new place or only the new
  /// size. The window gets there a moment later, which is reported like anybody's move.
  public var answersLate = false
  /// `focus` takes effect only after the call has returned: the app in front changes a moment after Arbor asks, and until then
  /// `focusedWindow()` gives the old answer.
  public var focusesLate = false
  /// Another app comes to the front, and two times in three nobody says which window has the keyboard now: only that the app was
  /// activated. `focusedWindow()` tells the truth when asked.
  public var switchesAppsSilently = false
  /// An app whose only window closed gives the next one the same number (Music, Notes, Calendar).
  public var reusesNumbers = false
  /// A window that closes is reported gone only after whatever else happens at that moment, and after Arbor has had a chance
  /// to ask for it once more.
  public var closesLate = false
  public var seed: UInt64 = 1

  public init() {}

  /// Whether what a helper reports waits until the helper has done all it does.
  var holdsReports: Bool { runsAhead || shufflesReports || closesLate }

  public var isPolite: Bool {
    var polite = Rudeness()
    polite.seed = seed
    return self == polite
  }

  /// The words of `ARBOR_RUDE`, and what `make rude` goes through. `small` is not among the switches: it is a display, not
  /// a manner (`FakeWindowSystem.standardDisplay`).
  public static let manners = ["ahead", "order", "twice", "late", "slow", "silent", "numbers", "closes"]

  /// Reads `order,twice`, or `all`. Nil if a word is not known.
  public init?(words: String, seed: UInt64 = 1) {
    self.seed = seed
    for word in words.split(whereSeparator: { $0 == "," || $0 == " " }) {
      switch word {
      case "ahead": runsAhead = true
      case "order": shufflesReports = true
      case "twice": repeatsReports = true
      case "late": answersLate = true
      case "slow": focusesLate = true
      case "silent": switchesAppsSilently = true
      case "numbers": reusesNumbers = true
      case "closes": closesLate = true
      case "small": break
      case "all":
        (shufflesReports, repeatsReports, answersLate, switchesAppsSilently) = (true, true, true, true)
        (reusesNumbers, closesLate, focusesLate, runsAhead) = (true, true, true, true)
      default: return nil
      }
    }
  }

  /// What the environment asks of every fake in this process. A word nobody knows ends the process: a run that was meant to be rude
  /// and was polite would pass for the wrong reason.
  public static let fromEnvironment: Rudeness = {
    let environment = ProcessInfo.processInfo.environment
    guard let words = environment["ARBOR_RUDE"], !words.isEmpty else { return Rudeness() }
    guard let rudeness = Rudeness(words: words, seed: environment["ARBOR_RUDE_SEED"].flatMap { UInt64($0) } ?? 1) else {
      fatalError("ARBOR_RUDE=\(words): the words are \(manners.joined(separator: ", ")), small and all")
    }
    return rudeness
  }()

  /// `ARBOR_RUDE` names `small` (or `all`): the display every test gets unless it asks for another is a hosted Mac's.
  public static let smallDisplayFromEnvironment: Bool = {
    let words = (ProcessInfo.processInfo.environment["ARBOR_RUDE"] ?? "").split(whereSeparator: { $0 == "," || $0 == " " })
    return words.contains("small") || words.contains("all")
  }()
}

// MARK: Reports on their way

/// One call of `WindowSystemEvents`, kept until it is delivered.
enum Report {
  case appeared(WindowSnapshot)
  case found(WindowSnapshot)
  case destroyed(WindowID)
  case changed(WindowSnapshot, userInitiated: Bool)
  case focused(WindowID)
  case activated(FrontmostApp?)
  case refused
  case dragBegan(WindowID, CGPoint)
  case dragMoved(WindowID, CGPoint)
  case dragEnded(WindowID, CGPoint)
  case dragCancelled(WindowID)
  case displaysChanged
  case resizeBegan(WindowID)
  case resizeEnded(WindowID)
  case keyboardMoved
  case replaced(WindowID, by: WindowSnapshot)
  case pressed

  /// The windows it is about.
  var windows: [WindowID] {
    switch self {
    case .appeared(let snapshot), .found(let snapshot), .changed(let snapshot, _): [snapshot.id]
    case .destroyed(let id), .focused(let id), .dragCancelled(let id), .resizeBegan(let id), .resizeEnded(let id): [id]
    case .dragBegan(let id, _), .dragMoved(let id, _), .dragEnded(let id, _): [id]
    case .replaced(let old, let snapshot): [old, snapshot.id]
    case .activated, .refused, .displaysChanged, .keyboardMoved, .pressed: []
    }
  }

  /// The first anybody hears of a window. The Accessibility layer reports nothing about a window it has no record of.
  var isBirth: Bool {
    switch self {
    case .appeared, .found, .replaced: true
    default: false
    }
  }

  var isDeath: Bool { if case .destroyed = self { true } else { false } }

  /// Made of mouse events, which come from one source, in order.
  var isOfTheMouse: Bool {
    switch self {
    case .pressed, .dragBegan, .dragMoved, .dragEnded, .dragCancelled, .resizeBegan, .resizeEnded: true
    default: false
    }
  }

  /// The end of a drag or a resize, which the Accessibility layer sends in one breath with the window's last frame before it.
  var endsAGrab: Bool {
    switch self {
    case .dragEnded, .dragCancelled, .resizeEnded: true
    default: false
    }
  }

  /// Whether macOS has been seen to say such a thing twice.
  var comesTwice: Bool {
    // How many echoes a move has is the polite fake's to play: one for each step that changes something.
    switch self {
    case .focused, .keyboardMoved: true
    default: false
    }
  }

  /// Whether `self`, said first, has to stay ahead of `later`.
  func staysAhead(of later: Report) -> Bool {
    if isOfTheMouse, later.isOfTheMouse { return true }
    // What a press brings about follows it by tens of milliseconds.
    if case .pressed = self { return true }
    // Displays change under everything else: the Accessibility layer reads every frame again before it says so.
    if case .displaysChanged = self { return true }
    if case .displaysChanged = later { return true }
    if case .refused = self { return true }
    // What the Accessibility layer sends in one loop over an app's windows, by their numbers: an app that quit, an app hidden or shown.
    if isDeath, later.isDeath { return true }
    if case .changed(let one, _) = self, case .changed(let other, _) = later, one.pid == other.pid, one.bundleID == other.bundleID { return true }
    guard windows.contains(where: later.windows.contains) else { return false }
    if isBirth || later.isDeath || isDeath || later.isBirth { return true }
    // The beginning of a grab is made of the window's first move: the Accessibility layer says "it is being dragged" and then "it has moved", in one call.
    switch self {
    case .dragBegan, .resizeBegan: if case .changed = later { return true }
    default: break
    }
    if case .changed = self {
      if later.endsAGrab { return true }
      // Each carries what the window is like when it arrives, so their order says nothing.
      if case .changed = later { return true }
    }
    return false
  }
}

/// Stands between the fake's helpers and whoever listens. While a burst is open it keeps the reports.
@MainActor
final class ReportDesk: WindowSystemEvents {
  unowned let system: FakeWindowSystem
  init(_ system: FakeWindowSystem) { self.system = system }

  private func take(_ report: Report) { system.take(report) }

  func windowAppeared(_ window: WindowSnapshot) { take(.appeared(window)) }
  func windowFound(_ window: WindowSnapshot) { take(.found(window)) }
  func windowDestroyed(_ id: WindowID) { take(.destroyed(id)) }
  func windowChanged(_ window: WindowSnapshot, userInitiated: Bool) { take(.changed(window, userInitiated: userInitiated)) }
  func windowFocused(_ id: WindowID) { take(.focused(id)) }
  func applicationActivated(_ app: FrontmostApp?) { take(.activated(app)) }
  func accessibilityWasRefused() { take(.refused) }
  func dragBegan(_ id: WindowID, at point: CGPoint) { take(.dragBegan(id, point)) }
  func dragMoved(_ id: WindowID, to point: CGPoint) { take(.dragMoved(id, point)) }
  func dragEnded(_ id: WindowID, at point: CGPoint) { take(.dragEnded(id, point)) }
  func dragCancelled(_ id: WindowID) { take(.dragCancelled(id)) }
  func displaysChanged() { take(.displaysChanged) }
  func resizeBegan(_ id: WindowID) { take(.resizeBegan(id)) }
  func resizeEnded(_ id: WindowID) { take(.resizeEnded(id)) }
  func keyboardFocusMoved() { take(.keyboardMoved) }
  func windowReplaced(_ old: WindowID, by window: WindowSnapshot) { take(.replaced(old, by: window)) }
  func pointerPressed() { take(.pressed) }
}

extension FakeWindowSystem {
  /// For a test whose SUBJECT is a courtesy of the fake's (that a report comes from inside a call, say), or the very number of reports: it says so,
  /// and why, first thing, and is polite whatever `ARBOR_RUDE` says. Not for a test that merely looks too early: let that one wait
  /// (`deliverEchoes()`, `scheduler.advance`). `scripts/rude.py` counts these lines, and the number should not grow.
  public func staysPolite(because reason: String) { rudeness = Rudeness() }

  /// Everything a helper reports between this and `endBurst()` belongs to one happening. A polite fake takes no notice.
  func beginBurst() {
    if burstDepth == 0 { whatWasAskedHasHappened() }
    burstDepth += 1
  }

  /// Delivers what the burst held, rudely, then what Arbor's reactions brought about, until nothing is left.
  func endBurst() {
    burstDepth -= 1
    guard burstDepth == 0 else { return }
    guard rudeness.holdsReports else { return timeHasPassed() }
    var rounds = 0
    while !held.isEmpty || wantsAfterEvents, rounds < 100 {
      rounds += 1
      let reports = inRudeOrder(held)
      held.removeAll()
      for report in reports { deliver(report) }
      if wantsAfterEvents {
        wantsAfterEvents = false
        whenAllAreIn?()
      }
      // What Arbor did about them echoes in its turn, as one more burst.
      burstDepth += 1
      deliverEchoes()
      burstDepth -= 1
    }
  }

  func take(_ report: Report) {
    // A refusal comes from inside the call that was refused.
    if case .refused = report { return deliver(report) }
    if burstDepth > 0, rudeness.holdsReports { held.append(report) } else { for one in inRudeOrder([report]) { deliver(one) } }
  }

  /// A random order among those the Accessibility layer could produce, with what macOS says twice said twice.
  func inRudeOrder(_ reports: [Report]) -> [Report] {
    var waiting = reports
    if rudeness.closesLate {
      // Unless the number comes round again in the same breath: then the end has to come before the new beginning.
      let deaths = waiting.filter(\.isDeath)
      let born = waiting.filter(\.isBirth).flatMap(\.windows)
      if !deaths.contains(where: { $0.windows.contains(where: born.contains) }) {
        waiting = waiting.filter { !$0.isDeath } + deaths
      }
    }
    if rudeness.repeatsReports {
      if waiting.contains(where: { if case .activated = $0 { true } else { false } }) { anAppCameForward = true }
      waiting = waiting.flatMap { report -> [Report] in
        guard report.comesTwice else { return [report] }
        // The Accessibility layer says "focused w" again only after it has forgotten that it said so: when an app has come forward.
        if case .focused = report {
          guard anAppCameForward else { return [report] }
          anAppCameForward = false
        }
        return [report, report]
      }
    }
    guard rudeness.shufflesReports, waiting.count > 1 else { return waiting }
    // The end of a drag or a resize goes out in one breath with the window's last frame, so the two travel together.
    var units: [[Report]] = []
    for report in waiting {
      if report.endsAGrab, let last = units.last, last.count == 1, case .changed = last[0], last[0].windows == report.windows {
        units[units.count - 1].append(report)
      } else {
        units.append([report])
      }
    }
    // Who waits for whom is worked out once: a desk of 150 windows echoes 150 moves in one burst, and tests hold a stopwatch.
    var followers: [[Int]] = Array(repeating: [], count: units.count)
    var waitsFor = Array(repeating: 0, count: units.count)
    for later in units.indices {
      for earlier in units.indices[..<later]
      where units[earlier].contains(where: { one in units[later].contains { one.staysAhead(of: $0) } }) {
        followers[earlier].append(later)
        waitsFor[later] += 1
      }
    }
    var free = units.indices.filter { waitsFor[$0] == 0 }
    var ordered: [Report] = []
    while !free.isEmpty {
      let unit = free.remove(at: dice.int(0...(free.count - 1)))
      ordered += units[unit]
      for follower in followers[unit] {
        waitsFor[follower] -= 1
        if waitsFor[follower] == 0 { free.append(follower) }
      }
      // In the order they were said, so that a seed means one order whatever way the free ones are found.
      free.sort()
    }
    return ordered
  }

  /// Like the Accessibility layer, which reads a window when the report arrives and not when it was sent, and says
  /// nothing about a window it has dropped.
  func deliver(_ report: Report) {
    switch report {
    case .appeared(let snapshot): listener?.windowAppeared(windows[snapshot.id]?.snapshot ?? snapshot)
    case .found(let snapshot): listener?.windowFound(windows[snapshot.id]?.snapshot ?? snapshot)
    case .destroyed(let id): listener?.windowDestroyed(id)
    case .changed(let snapshot, let userInitiated):
      listener?.windowChanged(fresh(snapshot), userInitiated: userInitiated)
    // It reads who has the focus when the notification arrives, so it cannot name a window that has gone.
    case .focused(let id): if windows[id] != nil { listener?.windowFocused(id) } else { listener?.keyboardFocusMoved() }
    case .activated(let app): listener?.applicationActivated(app)
    case .refused: listener?.accessibilityWasRefused()
    case .dragBegan(let id, let point): listener?.dragBegan(id, at: point)
    case .dragMoved(let id, let point): listener?.dragMoved(id, to: point)
    case .dragEnded(let id, let point): listener?.dragEnded(id, at: point)
    case .dragCancelled(let id): listener?.dragCancelled(id)
    case .displaysChanged: listener?.displaysChanged()
    case .resizeBegan(let id): listener?.resizeBegan(id)
    case .resizeEnded(let id): listener?.resizeEnded(id)
    case .keyboardMoved: listener?.keyboardFocusMoved()
    case .replaced(let old, let snapshot): listener?.windowReplaced(old, by: windows[snapshot.id]?.snapshot ?? snapshot)
    case .pressed: listener?.pointerPressed()
    }
  }

  /// The frame is read when the report arrives. What the report was about (minimized, hidden, another Space, a title) was true when it
  /// was sent and is still: nothing in a burst takes it back.
  private func fresh(_ snapshot: WindowSnapshot) -> WindowSnapshot {
    guard let now = windows[snapshot.id]?.snapshot else { return snapshot }
    var fresh = snapshot
    fresh.frame = now.frame
    return fresh
  }
}

// MARK: Answers that come before the deed

extension FakeWindowSystem {
  /// What `setFrame` reads back from a window that has not got round to it: nothing done, only moved, or only resized.
  func halfWay(from old: CGRect, to new: CGRect) -> CGRect {
    switch dice.int(0...2) {
    case 0: old
    case 1: CGRect(origin: new.origin, size: old.size)
    default: CGRect(origin: old.origin, size: new.size)
    }
  }

  var owesSomething: Bool { !lateAnswers.isEmpty || !lateFocus.isEmpty }

  /// At the end of a helper. Something has happened, so time has passed, and what Arbor asked for in answer comes true. Not in the chaos
  /// lab, where it waits for `appsReact()` like the echoes, or for the next thing that happens.
  func timeHasPassed() {
    if !holdsEchoes { whatWasAskedHasHappened() }
  }

  /// At the beginning of a helper. A hand, an app and macOS itself are slower than a request of Arbor's, which takes hundredths of a second: what it asked for
  /// earlier has happened, and been reported, before the next thing does. Or an old request would overrule what a person did after it.
  func whatWasAskedHasHappened() {
    var rounds = 0
    while owesSomething, burstDepth == 0, rounds < 10 {
      rounds += 1
      settleLateAnswers()
    }
  }

  /// The windows Arbor asked to give the keyboard to get it now, and the windows that still owe a frame get there. The report of a frame says what
  /// the Accessibility layer makes of it: the frame is not the one it read back, so either it comes so soon that it passes for a stage of Arbor's move and a second look calls it the app's
  /// own, or it is somebody else's move from the start. Both end in `userInitiated: true`.
  func settleLateAnswers() {
    // macOS does and reports every change it was asked for, in order.
    let asked = lateFocus
    lateFocus.removeAll()
    for window in asked where windows[window] != nil {
      // Its app comes forward, which brings back what macOS had swept aside.
      sweptAside = nil
      // Raised whoever has the keyboard, as by the polite fake and by `kAXRaiseAction`.
      bringToFront(window)
      guard focused != window else { continue }
      let crossesApps = focused.flatMap { windows[$0]?.snapshot.pid } != windows[window]?.snapshot.pid
      focused = window
      // A test that wants silence has switched the echo off, and hears what it hears of a polite fake: nothing.
      guard echoes.focus else { continue }
      activateApp(of: window)
      focusReportsInBurst += 1
      events?.windowFocused(window)
      // What the Accessibility layer makes of "application activated" and "deactivated": after the window's own report, as from the polite fake.
      if crossesApps { events?.keyboardFocusMoved() }
    }
    let owed = lateAnswers.sorted { $0.key < $1.key }
    lateAnswers.removeAll()
    for (window, frame) in owed {
      // macOS accepts a frame for a window in full screen and does nothing.
      guard var fake = windows[window], fake.snapshot.frame != frame, !fake.snapshot.isFullScreen else { continue }
      let (home, moves) = (fake.home, fake.movesNotArbors)
      fake.snapshot.frame = frame
      // It is where Arbor asked it to be, by Arbor's doing.
      (fake.home, fake.movesNotArbors, fake.placeIsArborsDoing) = (home, moves, true)
      fake.lastRequest = fake.lastRequest.map { ($0.asked, frame) }
      windows[window] = fake
      events?.windowChanged(fake.snapshot, userInitiated: true)
    }
  }
}

// MARK: Switches nobody mentions

extension FakeWindowSystem {
  /// With `switchesAppsSilently`, two times in three: the window's app is in front and the window has the keyboard, and all that is said is
  /// which app came forward. True if it went that way. Within one app the focus is always reported.
  ///
  /// As seen on a hosted Mac: the workspace says "this app was activated" while it still names the app before as the one in front. The
  /// Accessibility layer reports the focus of the app in front only, so it reported nothing, and nothing came after.
  func comesForwardUnnoticed(_ window: WindowID) -> Bool {
    guard rudeness.switchesAppsSilently, let snapshot = windows[window]?.snapshot,
      frontmost != FrontmostApp(bundleID: snapshot.bundleID, name: snapshot.appName), dice.chance(66)
    else { return false }
    undelivered.removeAll { if case .focus = $0 { true } else { false } }
    focused = window
    bringToFront(window)
    unnoticedSwitches += 1
    activateApp(of: window)
    return true
  }
}

// MARK: Numbers that come round again

extension FakeWindowSystem {
  /// The number of the next window of an app: a new one, or with `reusesNumbers` the one its only window had when it closed. An app is a
  /// process and a bundle id: most tests open every app under one pid, and no app was seen to get the number of another's window.
  func numberForNewWindow(of pid: Int32, bundleID: String?) -> WindowID {
    if rudeness.reusesNumbers, !hasWindows(pid: pid, bundleID: bundleID),
      let old = putAway.removeValue(forKey: Self.app(pid, bundleID)), !existingWindowIDs().contains(old)
    {
      return old
    }
    defer { nextID += 1 }
    return WindowID(nextID)
  }

  static func app(_ pid: Int32, _ bundleID: String?) -> String { "\(pid) \(bundleID ?? "")" }

  /// Also on a Space that is not showing, or behind a tab.
  func hasWindows(pid: Int32, bundleID: String?) -> Bool {
    [windows, unlisted, backgroundTabs].contains { $0.values.contains { $0.snapshot.pid == pid && $0.snapshot.bundleID == bundleID } }
  }

  /// The app has quit. What was seen is a running app that gives its one window the same number again.
  func forgetNumbers(of pid: Int32) {
    putAway = putAway.filter { !$0.key.hasPrefix("\(pid) ") }
  }
}
