import ArborCore
import ArborKit
import ArborTesting
import CoreGraphics
import Foundation
import Testing

/// An app as a person meets it: how small its windows go, and how large they open.
private struct App {
  var name: String
  var smallest: CGSize
  var opens = CGSize(width: 1000, height: 700)
}

private let mail = App(name: "Mail", smallest: CGSize(width: 760, height: 400))
private let notes = App(name: "Notes", smallest: CGSize(width: 709, height: 300))
private let finder = App(name: "Finder", smallest: CGSize(width: 501, height: 300), opens: CGSize(width: 920, height: 436))
private let safari = App(name: "Safari", smallest: CGSize(width: 574, height: 240))
private let xcode = App(name: "Xcode", smallest: CGSize(width: 1188, height: 685), opens: CGSize(width: 1300, height: 800))

/// Every pair is too wide for the laptop's display, or for what the Desktop leaves of it.
private let pairs: [[App]] = [[mail, finder], [finder, mail], [mail, notes], [notes, safari], [xcode, finder], [finder, xcode]]

/// Walks 519, 73 and 646 of the ordinary ones (`nobodyIsPutIntoAPlaceThatTheNextAnswerTakesAway`).
private let overturned = [
  """
  open 103 Terminal pid 1003 at 1800 706 1052 594 min 177 60
  launch
  open 104 Xcode pid 1004 at 1996 621 1188 685 min 1188 685
  key down dock top
  open 105 Xcode pid 1004 at 1981 430 1188 832 min 1188 685
  key down arrange
  """,
  """
  displays side:0,0,3008,1692:25,0,0,86* windows-never
  open 101 Xcode pid 1004 at 948 154 1188 784 min 1188 685
  open 102 Xcode pid 1004 at 1385 432 1456 936 min 1188 685
  open 103 Xcode pid 1004 at 497 205 1430 920 min 1188 685
  open 104 Xcode pid 1004 at 965 378 1469 688 min 1188 685
  launch
  key down arrange
  key down dock top
  """,
  """
  displays main:0,0,1280,800:25,0,59,0* windows-never
  open 101 Mail pid 1002 at 8 132 1045 560 min 760 400
  launch
  focus 101
  key down toggle-float
  open 104 Preview pid 1007 at 255 25 723 716 min 723 400 max 723 2000
  toggle-pause
  toggle-pause
  key down show-all
  open 106 Mail pid 1002 at 49 25 1078 716 min 760 400
  key down arrange
  """,
]

private let laptop = DisplaySnapshot(
  id: DisplayID("main"), frame: CGRect(x: 0, y: 0, width: 1280, height: 800),
  visibleFrame: CGRect(x: 0, y: 25, width: 1280, height: 775), isMain: true, isBuiltIn: true)

private let desk = DisplaySnapshot(
  id: DisplayID("main"), frame: CGRect(x: 0, y: 0, width: 1728, height: 1117),
  visibleFrame: CGRect(x: 0, y: 25, width: 1728, height: 1092), isMain: true, isBuiltIn: true)

private let studio = DisplaySnapshot(
  id: DisplayID("main"), frame: CGRect(x: 0, y: 0, width: 2560, height: 1440),
  visibleFrame: CGRect(x: 0, y: 25, width: 2560, height: 1415), isMain: true, isBuiltIn: true)

private let day: TimeInterval = 24 * 3600

/// Arbor knows how small apps go (docs/features/F68-how-small-apps-go.md): what a docked window of an app answered is kept for the next
/// window of that app, in this run and the next, so that windows that cannot all fit are planned on paper and each moves once.
/// And it is foresight, never the truth: what is wrong in the store is put right the first time it would cost anybody anything.
@Suite @MainActor struct HowSmallAppsGoTests {
  /// Without a stage, as with macOS's "Reduce motion" on: every frame that is set is seen.
  static var still: Settings {
    var settings = Settings()
    settings.animationDuration = 0
    return settings
  }

  /// A run of Arbor on a Mac on which `apps` are open, one window each, numbered from 101 in that order.
  /// - Parameter later: how long after the first day's morning it starts.
  private func run(
    _ apps: [App], knowing saved: PersistedState? = nil, on display: DisplaySnapshot = laptop, settings: Settings = still,
    later: TimeInterval = 0, macOS: Int = 26
  ) -> Harness {
    let h = Harness(displays: [display], settings: settings, saved: saved)
    h.controller.macOSVersion = macOS
    h.scheduler.advance(by: later)
    for (index, app) in apps.enumerated() { open(app, in: h, pid: Int32(2000 + index)) }
    h.start()
    return h
  }

  @discardableResult
  private func open(_ app: App, in h: Harness, pid: Int32) -> WindowID {
    let visible = h.visibleFrame
    let size = CGSize(width: min(app.opens.width, visible.width - 40), height: min(app.opens.height, visible.height - 40))
    return h.system.open(
      app: app.name, pid: pid, frame: CGRect(origin: CGPoint(x: visible.minX + 20, y: visible.minY + 20), size: size),
      minimumSize: app.smallest)
  }

  /// What a person does: click the window, press the key.
  private func dock(_ window: UInt32, _ side: String, _ h: Harness) {
    h.system.userFocus(WindowID(window))
    h.run("dock \(window) \(side)")
    h.scheduler.advance(by: 1)
  }

  private func shows(_ frame: CGRect, _ h: Harness) -> Bool {
    h.system.displayList.contains {
      let part = frame.intersection($0.frame)
      return !part.isNull && part.width > 2 && part.height > 2
    }
  }

  /// The changes a person could have seen since `mark`, by window.
  private func seen(since mark: Int, _ h: Harness) -> [WindowID: [FakeWindowSystem.Move]] {
    Dictionary(
      grouping: h.system.moveLog.dropFirst(mark).filter { $0.before != $0.after && (shows($0.before, h) || shows($0.after, h)) },
      by: \.window)
  }

  private func road(_ moves: [FakeWindowSystem.Move]) -> String {
    ([moves[0].before] + moves.map(\.after)).map { "\(Int($0.minX)),\(Int($0.minY)) \(Int($0.width))×\(Int($0.height))" }
      .joined(separator: " → ")
  }

  /// What is wrong with the road `window` was seen to take since `mark`, or nil (Roads.swift): one change of place at most, and each edge and each
  /// side one way only. A window may be sized where it stands and then moved (Controller+AskFirst.swift).
  private func detour(_ window: WindowID, since mark: Int, _ h: Harness) -> String? {
    guard let moves = seen(since: mark, h)[window] else { return nil }
    return FakeWindowSystem.detour([moves[0].before] + moves.map(\.after))
  }

  /// Runs `act` and holds it to rule 3: no docked window is seen to go out of its way. A question that changes nothing is seen by nobody. What
  /// floats is left out: that a dock squeezes floating windows, which then refuse, is a fault of its own (board 1.18).
  private func expectOneMoveEach(
    _ h: Harness, _ what: String, sourceLocation: SourceLocation = #_sourceLocation, _ act: () -> Void
  ) {
    let mark = h.system.moveLog.count
    act()
    let docked = Set(h.workspace.tree.allWindows)
    for window in seen(since: mark, h).keys.sorted() where docked.contains(window) {
      #expect(detour(window, since: mark, h) == nil, "\(what): \(window)", sourceLocation: sourceLocation)
    }
  }

  /// A first day on which Arbor meets `apps` at their smallest, and what it has saved at the end of it.
  private func whatIsKnownAfterADay(with apps: [App], on display: DisplaySnapshot = laptop) -> PersistedState? {
    let h = run(apps, on: display)
    for (index, side) in zip(apps.indices, ["left", "right", "left", "right"]) { dock(UInt32(101 + index), side, h) }
    h.run("float-all")
    h.scheduler.advance(by: 1)
    h.controller.saveNow()
    return h.store.saved
  }

  // MARK: The pair

  @Test(arguments: pairs.indices) func theNextDayEachOfAPairThatCannotBothFitMovesOnce(index: Int) {
    let pair = pairs[index]
    let known = whatIsKnownAfterADay(with: pair)
    let h = run(pair, knowing: known, later: day)
    let names = pair.map(\.name).joined(separator: " and ")
    expectOneMoveEach(h, "\(names), the first") { dock(101, "left", h) }
    expectOneMoveEach(h, "\(names), the second") { dock(102, "right", h) }
    expectWindowsMatchLayout(h)
  }

  @Test func soIsAPairOfWhichEachWasMetAlone() {
    // On different days, neither beside the other.
    var known = whatIsKnownAfterADay(with: [mail, safari, notes])
    let h1 = run([finder, xcode], knowing: known, later: day)
    dock(101, "left", h1)
    dock(102, "right", h1)
    h1.controller.saveNow()
    known = h1.store.saved

    let h = run([mail, finder], knowing: known, later: 2 * day)
    expectOneMoveEach(h, "the first") { dock(101, "left", h) }
    expectOneMoveEach(h, "the second") { dock(102, "right", h) }
    expectWindowsMatchLayout(h)
  }

  @Test func aSecondWindowOfAnAppMetTodayIsNoStranger() {
    let h = run([mail, finder])
    dock(101, "left", h)
    dock(102, "right", h)
    h.run("float-all")
    h.scheduler.advance(by: 1)
    let another = open(mail, in: h, pid: 2000)
    let third = open(finder, in: h, pid: 2001)
    h.scheduler.advance(by: 1)
    expectOneMoveEach(h, "another window of Mail") { dock(another.rawValue, "left", h) }
    expectOneMoveEach(h, "another window of Finder") { dock(third.rawValue, "right", h) }
    expectWindowsMatchLayout(h)
  }

  @Test func withAStageTheWindowsEndUpWhereTheyDoWithout() {
    let known = whatIsKnownAfterADay(with: [mail, finder])
    let still = run([mail, finder], knowing: known, later: day)
    let moving = run([mail, finder], knowing: known, settings: Settings(), later: day)
    for h in [still, moving] {
      dock(101, "left", h)
      dock(102, "right", h)
    }
    #expect(still.frame(WindowID(101)) == moving.frame(WindowID(101)))
    #expect(still.frame(WindowID(102)) == moving.frame(WindowID(102)))
  }

  // MARK: What is kept

  private func kept(_ app: App, in state: PersistedState?) -> AppSizes.Entry? {
    state?.appSizes?.entry(for: "com.example.\(app.name.lowercased())")
  }

  private func isTile(_ window: UInt32, _ h: Harness) -> Bool {
    h.layout!.tiles.contains { $0.windows.contains(WindowID(window)) }
  }

  @Test func whatAWindowWouldNotGoBelowIsKeptForItsApp() {
    let known = whatIsKnownAfterADay(with: [mail, finder])
    #expect(kept(mail, in: known)?.width == 760)
    #expect(kept(finder, in: known)?.width == 501)
    #expect(kept(mail, in: known)?.macOS == 26)
    // Nobody was asked to be lower than it goes.
    #expect(kept(mail, in: known)?.height == 0)
    #expect(known?.appSizes?.apps.count == 2)
  }

  @Test func whileNothingHasRefusedNothingIsKept() {
    let h = run([App(name: "Easy", smallest: .zero), App(name: "Going", smallest: .zero)])
    dock(101, "left", h)
    dock(102, "right", h)
    h.controller.saveNow()
    #expect(h.store.saved != nil)
    #expect(h.store.saved?.appSizes == nil)
  }

  @Test func whileNothingIsDockedNothingMovesBecauseSomethingIsKnown() {
    let known = whatIsKnownAfterADay(with: [mail, finder, notes])
    #expect(known?.appSizes?.apps.count == 3)
    let h = run([mail, finder, notes], knowing: known, later: day)
    h.scheduler.advance(by: 5)
    #expect(h.system.moveLog.isEmpty)
    // Nor when a window of a known app opens.
    open(mail, in: h, pid: 2000)
    h.scheduler.advance(by: 5)
    #expect(h.system.moveLog.isEmpty)
  }

  @Test func whatFloatsTeachesNothing() {
    // Another kind of window of Mail, of one size, floats while Finder is docked. With floating windows making way, which does not ship, the dock
    // squeezes it and it refuses.
    let panel = App(name: "Mail", smallest: CGSize(width: 820, height: 600), opens: CGSize(width: 820, height: 600))
    var settings = Settings.makingWay
    settings.animationDuration = 0
    let h = run([panel, finder], settings: settings)
    let mark = h.system.moveLog.count
    dock(102, "left", h)
    #expect(
      h.system.moveLog.dropFirst(mark).contains { $0.window == WindowID(101) && $0.after.width > $0.requested.width + 2 },
      "or this proves nothing: it is asked for less, and refuses")
    h.controller.saveNow()
    #expect(kept(mail, in: h.store.saved) == nil)
  }

  // MARK: Foresight is never the truth

  /// A home in which this is what is known, right or wrong, since the first day's morning.
  private func home(knowing sizes: [(app: App, size: CGSize)]) -> PersistedState {
    var known = AppSizes()
    for (app, size) in sizes {
      known.stoodBy(size, app: "com.example.\(app.name.lowercased())", macOS: 26, at: Date(timeIntervalSinceReferenceDate: 800_000_000))
    }
    var home = PersistedState(workspaces: [:], hints: [:])
    home.appSizes = known
    return home
  }

  private func wide(_ width: CGFloat) -> CGSize { CGSize(width: width, height: 0) }

  private func slim(_ app: App, _ width: CGFloat) -> App {
    var app = app
    app.smallest.width = width
    return app
  }

  private func frames(_ h: Harness) -> [WindowID: CGRect] {
    Dictionary(uniqueKeysWithValues: h.system.allWindows().map { ($0.id, $0.frame) })
  }

  /// The yardstick for all that follows: whatever is in the store, things end as they do in a home that knows nothing.
  private func expectTheSameEnd(
    _ apps: [App], knowing store: PersistedState, on display: DisplaySnapshot = laptop, settings: Settings = still,
    everyoneAnswers: Bool = true, sourceLocation: SourceLocation = #_sourceLocation, _ acts: (Harness) -> Void
  ) {
    let knowing = run(apps, knowing: store, on: display, settings: settings, later: day)
    let innocent = run(apps, on: display, settings: settings, later: day)
    acts(knowing)
    acts(innocent)
    let docked = Set(innocent.workspace.tree.allWindows)
    #expect(Set(knowing.workspace.tree.allWindows) == docked, sourceLocation: sourceLocation)
    for window in docked.sorted() {
      #expect(
        knowing.layout?.windowFrames[window] == innocent.layout?.windowFrames[window],
        "\(window) has \(String(describing: knowing.layout?.windowFrames[window])), and in a home that knows nothing \(String(describing: innocent.layout?.windowFrames[window]))",
        sourceLocation: sourceLocation)
    }
    // A window whose app hangs is not where it belongs, in either home.
    if everyoneAnswers { expectWindowsMatchLayout(knowing, sourceLocation: sourceLocation) }
  }

  /// A sheet was open when Mail was asked, or its app has been updated: 900 is on record, and it goes down to 400. Before anything was
  /// kept a restart cured that. Finder must not pay for it, today or at any later start.
  @Test func whatIsTooHighCostsNoNeighbourItsPlace() {
    let store = home(knowing: [(mail, wide(900)), (finder, wide(501))])
    let apps = [slim(mail, 400), finder]
    expectTheSameEnd(apps, knowing: store) { h in
      h.system.userFocus(WindowID(101))
      h.run("arrange")
      h.scheduler.advance(by: 1)
    }
    let h = run(apps, knowing: store, later: day)
    h.system.userFocus(WindowID(101))
    h.run("arrange")
    h.scheduler.advance(by: 1)
    #expect(!isTile(101, h) && !isTile(102, h))
    h.controller.saveNow()
    #expect(kept(mail, in: h.store.saved)?.width ?? 0 < 900, "and it is put right in the store")

    // Killed, so that the arrangement is there at the next start, with the room that was made.
    let next = Harness(displays: [laptop], settings: Self.still, saved: h.store.saved, system: h.system)
    next.controller.macOSVersion = 26
    next.scheduler.advance(by: 2 * day)
    next.start()
    next.scheduler.advance(by: 1)
    #expect(!isTile(101, next) && !isTile(102, next))
    #expect(next.system.isVisible(WindowID(102)))
  }

  /// Each of three in turn goes much smaller than is on record, whoever would have been the tile.
  @Test(arguments: [0, 1, 2], [10.0, 0]) func whoeverTheStoreIsWrongAboutThingsEndAsIfNothingWereKnown(wrong: Int, retry: Double) {
    var settings = Self.still
    settings.tileRetryMinutes = retry
    var apps = [mail, notes, finder]
    let store = home(knowing: apps.map { ($0, $0.smallest) })
    apps[wrong] = slim(apps[wrong], 120)
    expectTheSameEnd(apps, knowing: store, settings: settings) { h in
      h.system.userFocus(WindowID(101))
      h.run("arrange")
      h.scheduler.advance(by: 1)
    }
  }

  @Test(arguments: pairs.indices) func whereTheStoreIsRightThingsEndAsIfNothingWereKnownToo(index: Int) {
    let pair = pairs[index]
    expectTheSameEnd(pair, knowing: home(knowing: pair.map { ($0, $0.smallest) })) { h in
      dock(101, "left", h)
      dock(102, "right", h)
    }
  }

  @Test func whatIsTooLowCostsWhatNotKnowingCosts() {
    expectTheSameEnd([mail, finder], knowing: home(knowing: [(mail, wide(300)), (finder, wide(200))])) { h in
      dock(101, "left", h)
      dock(102, "right", h)
    }
  }

  @Test func inAHoldTooNobodyIsATileOnForesightAlone() {
    let store = home(knowing: [(mail, wide(900)), (finder, wide(501))])
    expectTheSameEnd([slim(mail, 400), finder], knowing: store) { h in
      h.run("hold")
      dock(101, "left", h)
      dock(102, "right", h)
    }
  }

  @Test func aFloatingWindowIsPlacedByWhatItAnsweredItselfOnly() {
    let store = home(knowing: [(mail, wide(900))])
    let knowing = run([slim(mail, 400), finder], knowing: store, later: day)
    let innocent = run([slim(mail, 400), finder], later: day)
    for h in [knowing, innocent] { dock(102, "left", h) }
    #expect(knowing.frame(WindowID(101)) == innocent.frame(WindowID(101)))
  }

  /// 600 is on record and it goes down to 300. Half the display is more than 600, so nothing rests on the record and nobody has asked.
  @Test func theKeyThatShrinksIsNotStoppedByWhatIsOnlyForeseen() throws {
    let h = run([slim(mail, 300), finder], knowing: home(knowing: [(mail, wide(600))]), later: day)
    dock(101, "left", h)
    let before = try #require(h.frame(WindowID(101))).width
    #expect(before > 600)
    for _ in 0..<3 {
      #expect(h.run("shrink").ok)
      h.scheduler.advance(by: 1)
    }
    #expect(try #require(h.frame(WindowID(101))).width == before - 120)
    #expect(!isTile(101, h))
    expectWindowsMatchLayout(h)
  }

  @Test func underTheHandNothingIsForeseen() throws {
    let h = run([slim(mail, 300), finder], knowing: home(knowing: [(mail, wide(600))]), later: day)
    dock(101, "left", h)
    let before = try #require(h.frame(WindowID(101))).width
    #expect(h.run("resize 101 right -150").ok)
    h.scheduler.advance(by: 1)
    #expect(!isTile(101, h), "it follows the hand, and says itself where it stops")
    #expect(try #require(h.frame(WindowID(101))).width == before - 150)
    expectWindowsMatchLayout(h)
  }

  /// Put right means put right: not a size that is merely not too small, which the next smaller slot would disprove again.
  @Test func whatIsDisprovedIsUnknownNotLower() {
    let h = run([slim(mail, 100), finder], knowing: home(knowing: [(mail, wide(900))]), later: day)
    dock(101, "left", h)
    h.controller.saveNow()
    #expect(kept(mail, in: h.store.saved) == nil, "it took its share: how small it goes nobody knows")
  }

  @Test func whatItStoppedAtInsteadIsWhatIsKept() {
    // Less than foreseen, more than its share.
    let h = run([slim(mail, 700), finder], knowing: home(knowing: [(mail, wide(900))]), later: day)
    dock(101, "left", h)
    expectWindowsMatchLayout(h)
    h.controller.saveNow()
    #expect(kept(mail, in: h.store.saved)?.width == 700)
    #expect(h.frame(WindowID(101))?.width == 700)
  }

  @Test func aWindowThatWantsMoreThanItsAppIsKnownToIsBelieved() {
    let h = run([mail, slim(finder, 560)], knowing: home(knowing: [(mail, wide(760)), (finder, wide(501))]), later: day)
    dock(101, "left", h)
    dock(102, "right", h)
    expectWindowsMatchLayout(h)
    h.controller.saveNow()
    #expect(kept(finder, in: h.store.saved)?.width == 560)
  }

  @Test func aWindowThatIsSmallerAlreadyWhenItIsDockedIsNotHeldToWhatIsKnown() {
    // Another kind of window of the same app.
    let small = App(name: "Mail", smallest: CGSize(width: 300, height: 200), opens: CGSize(width: 420, height: 300))
    let h = run([small, finder], knowing: home(knowing: [(mail, wide(760)), (finder, wide(501))]), later: day)
    expectOneMoveEach(h, "the small window") { dock(101, "left", h) }
    expectOneMoveEach(h, "Finder") { dock(102, "right", h) }
    #expect(!isTile(101, h) && !isTile(102, h))
  }

  @Test func soIsOneThatItsPersonMadeSmallerWhileItFloated() {
    let h = run([slim(mail, 300), finder], knowing: home(knowing: [(mail, wide(760)), (finder, wide(501))]), later: day)
    h.system.userMove(WindowID(101), to: CGRect(x: 40, y: 60, width: 500, height: 500))
    expectOneMoveEach(h, "Mail") { dock(101, "left", h) }
    expectOneMoveEach(h, "Finder") { dock(102, "right", h) }
    #expect(!isTile(101, h) && !isTile(102, h))
  }

  @Test func relayoutForgetsWhatIsKnownOfTheAppsThatHaveAWindowAndOfNoOther() {
    let store = home(knowing: [(mail, wide(600)), (finder, wide(501)), (notes, wide(709))])
    // Half the display is more than 600, so nobody has asked. It goes down to 400.
    let h = run([slim(mail, 400), App(name: "Easy", smallest: .zero)], knowing: store, later: day)
    dock(101, "left", h)
    h.controller.saveNow()
    #expect(kept(mail, in: h.store.saved) == kept(mail, in: store))
    h.run("relayout")
    h.scheduler.advance(by: 1)
    h.controller.saveNow()
    #expect(kept(mail, in: h.store.saved) == nil)
    #expect(kept(notes, in: h.store.saved) == kept(notes, in: store))
    #expect(kept(finder, in: h.store.saved) == kept(finder, in: store))
    expectWindowsMatchLayout(h)
    // Nor is it foreseen of the windows that are there: squeezed to a third, Mail is offered its share like any stranger.
    let mark = h.system.moveLog.count
    dock(102, "right", h)
    for move in h.system.moveLog.dropFirst(mark) where move.window == WindowID(101) { #expect(move.requested.width < 500, "\(move.requested)") }
  }

  // MARK: Where and how it is asked

  /// The whole point: asked for less where it stands, a window that goes no smaller stops at the size that was planned, and goes to its place from
  /// there. A question moves nobody: the next answer may overturn the plan, and where in its slot a window belongs is for `place` to say.
  @Test func aWindowWhoseRoomIsForeseenIsAskedForAStepLessWhereItStands() throws {
    let h = run([mail, finder], knowing: home(knowing: [(mail, wide(760))]), later: day)
    let mark = h.system.moveLog.count
    dock(101, "left", h)
    let moves = h.system.moveLog.dropFirst(mark).filter { $0.window == WindowID(101) }
    let slot = try #require(h.layout?.windowFrames[WindowID(101)])
    #expect(slot.width == 760)
    let question = try #require(moves.first { $0.requested.width == 720 }, "a step less than is foreseen")
    #expect(question.requested.origin == question.before.origin, "where it stands")
    #expect(question.before.origin == moves.first?.before.origin, "and nothing has moved it before")
    #expect(question.requested.height == question.before.height, "and about nothing else")
    #expect(question.after.width == 760, "it stops at what was planned")
    #expect(moves.filter { $0.before.origin != $0.after.origin }.count == 1, "it changes place once: \(road(Array(moves)))")
    #expect(moves.last?.after == slot)
    #expect(detour(WindowID(101), since: mark, h) == nil)
  }

  /// Found by the walks (1,613 of the ordinary ones, in a home that has met the apps): asked at the corner of its slot, a window that cannot be
  /// as wide as the slot stopped there, and was then moved to the middle. How large a window goes is found out in its slot since (nobody in view
  /// is asked to grow where it stands), so the first time it goes by way of that corner in any home. The question is not what takes it there.
  @Test func aWindowThatCannotFillItsSlotGoesWhereItGoesInAHomeThatKnowsNothing() throws {
    let preview = App(name: "Preview", smallest: CGSize(width: 723, height: 400), opens: CGSize(width: 723, height: 540))
    var places: [[CGPoint]] = []
    for store in [home(knowing: [(preview, preview.smallest)]), nil] {
      let h = run([preview], knowing: store, later: day)
      h.system.setMaximumSize(WindowID(101), CGSize(width: 723, height: 2000))
      let mark = h.system.moveLog.count
      dock(101, "bottom", h)
      let slot = try #require(h.layout?.windowFrames[WindowID(101)])
      #expect(slot.height == 400 && slot.width > 1000, "or this proves nothing: \(slot)")
      let moves = h.system.moveLog.dropFirst(mark).filter { $0.window == WindowID(101) }
      places.append(moves.filter { $0.before.origin != $0.after.origin }.map(\.after.origin))
      #expect(abs(try #require(h.frame(WindowID(101))).midX - slot.midX) <= 1, "in whole points")
      if store != nil {
        let question = try #require(moves.first { $0.requested.height == 360 }, "a step less than is foreseen")
        #expect(question.requested.origin == question.before.origin, "where it stands")
      }
    }
    #expect(places[0] == places[1])
  }

  /// Found by the walks, from an empty home: a window of an app met a moment ago was put into the place a plan had for it, and moved on or sent out
  /// of view when the others had answered. The scripts as the walks shrank them; the trunk without the store keeps the rules in each.
  @Test(arguments: overturned.indices) func nobodyIsPutIntoAPlaceThatTheNextAnswerTakesAway(index: Int) {
    let others = ChaosRunner.knownRules.subtracting(["moved-twice-sizing", "moved-twice-sizing-again"])
    #expect(ChaosRunner.replay(ChaosAction.script(overturned[index]), excusing: others)?.violations.map(\.description) ?? [] == [])
  }

  /// What foresight is for where windows dock by themselves: a newcomer that would not fit is not tried in a place and taken out of it again.
  /// Its control is the same in a home that knows nothing, where it is asked.
  @Test func aNewcomerThatIsForeseenNotToFitIsLeftWhereItsAppPutIt() {
    var settings = Self.still
    settings.newWindows = "dock"
    var asked: [Bool] = []
    for store in [home(knowing: [(xcode, xcode.smallest)]), nil] {
      let h = run([finder], knowing: store, settings: settings, later: day)
      dock(101, "left", h)
      let mark = h.system.moveLog.count
      let newcomer = open(xcode, in: h, pid: 2001)
      h.scheduler.advance(by: 1)
      #expect(h.workspace.isFloating(newcomer), "it does not fit beside Finder on a laptop")
      asked.append(h.system.moveLog.dropFirst(mark).contains { $0.window == newcomer })
    }
    #expect(asked == [false, true], "met before: left alone; a stranger: tried")
  }

  /// Found by a reader: a window that goes a point or two less small than is foreseen passed for one that stood by it, and the plan was kept though
  /// the window's own answer no longer fitted it: what was shown was not what a layout made then would have said.
  @Test(arguments: [1, 2, 3, 12] as [CGFloat]) func aWindowThatGoesALittleLessSmallThanForeseenIsPlannedFor(more: CGFloat) {
    let apps = [slim(mail, 760 + more), finder]
    expectTheSameEnd(apps, knowing: home(knowing: [(mail, wide(760)), (finder, wide(501))])) { h in
      for (window, side) in [(UInt32(101), "left"), (UInt32(102), "right")] { self.dock(window, side, h) }
    }
    expectTheSameEnd(apps, knowing: home(knowing: [(mail, wide(760)), (finder, wide(501))])) { h in
      h.system.userFocus(WindowID(101))
      h.run("arrange")
    }
  }

  // MARK: Found by a reader of "a question moves nobody"

  private func screen(_ width: CGFloat, _ height: CGFloat) -> DisplaySnapshot {
    DisplaySnapshot(
      id: DisplayID("main"), frame: CGRect(x: 0, y: 0, width: width, height: height), visibleFrame: CGRect(x: 0, y: 25, width: width, height: height - 25),
      isMain: true, isBuiltIn: true)
  }

  private func put(_ app: App, at frame: CGRect, in h: Harness, pid: Int32) {
    h.system.open(app: app.name, pid: pid, frame: frame, minimumSize: app.smallest)
  }

  /// With a display to the right the corner is the one to the left, where what shows of a window depends on its width. Asked there and made narrower,
  /// and a tile after all because a stranger refused, it was left with nothing of it on any display. The stranger is asked first since, so that it
  /// is a tile when its turn comes, and is asked as tiles are: its size is given back.
  @Test func askedInACornerToTheLeftItStaysWithinReach() throws {
    let main = screen(1440, 900)
    let side = DisplaySnapshot(
      id: DisplayID("side"), frame: CGRect(x: 1440, y: 0, width: 1920, height: 900), visibleFrame: CGRect(x: 1440, y: 25, width: 1920, height: 875), isMain: false)
    let h = Harness(displays: [main, side], settings: Self.still, saved: home(knowing: [(mail, mail.smallest)]))
    h.controller.macOSVersion = 26
    h.scheduler.advance(by: day)
    put(mail, at: CGRect(x: 100, y: 100, width: 900, height: 600), in: h, pid: 2000)
    put(App(name: "Stranger", smallest: CGSize(width: 900, height: 300)), at: CGRect(x: 150, y: 120, width: 1000, height: 500), in: h, pid: 2001)
    h.start()
    dock(101, "top", h)
    dock(102, "bottom", h)
    h.run("zoom 102")
    h.scheduler.advance(by: 1)
    #expect(try #require(h.frame(WindowID(101))).minX < 0, "or this proves nothing: it is parked to the left")
    h.run("dock 101 beside 102 left")
    h.scheduler.advance(by: 1)
    let frame = try #require(h.frame(WindowID(101)))
    #expect(h.layout?.windowFrames[WindowID(101)] == nil, "or this proves nothing: they do not both fit")
    #expect(frame.maxX >= 1, "a point of it shows: \(frame)")
  }

  /// The store is right about Mail, and the plan squeezes it to just that. A stranger in its column then refuses, and the column is wider than
  /// either thought. Asked before the stranger, Mail went from 1000 to 760 and back to 900; without the store it goes from 1000 to 900.
  @Test(arguments: [100, 1700] as [CGFloat]) func whoeverIsForeseenIsAskedWhenTheStrangersHaveAnswered(x: CGFloat) throws {
    let big = App(name: "Big", smallest: CGSize(width: 900, height: 500))
    let music = App(name: "Music", smallest: CGSize(width: 680, height: 480))
    let h = Harness(
      displays: [screen(2560, 1440)], settings: Self.still, saved: home(knowing: [mail, music, finder].map { ($0, $0.smallest) }))
    h.controller.macOSVersion = 26
    h.scheduler.advance(by: day)
    put(mail, at: CGRect(x: x, y: 60, width: 1000, height: 500), in: h, pid: 2000)
    put(music, at: CGRect(x: 77, y: 62, width: 980, height: 480), in: h, pid: 2001)
    put(finder, at: CGRect(x: 158, y: 338, width: 603, height: 500), in: h, pid: 2002)
    // Squeezed less than Mail: by that alone it would be asked after it.
    put(big, at: CGRect(x: 49, y: 92, width: 950, height: 500), in: h, pid: 2003)
    h.start()
    h.system.userFocus(WindowID(101))
    let mark = h.system.moveLog.count
    #expect(h.run("layout Music | (Mail / Big) | Finder | Desktop").ok)
    h.scheduler.advance(by: 1)
    #expect(h.frame(WindowID(101))?.width == 900, "or this proves nothing")
    for window in h.workspace.tree.allWindows { #expect(detour(window, since: mark, h) == nil, "\(window)") }
    // Nor is it asked to grow where it stands for having been made too small, which a Mac cuts short at the edges of the screen.
    for move in h.system.moveLog.dropFirst(mark)
    where move.window == WindowID(101) && move.requested.origin == move.before.origin && shows(move.before, h) {
      #expect(move.requested.width <= move.before.width + 1, "\(move.window) was asked to grow in place: \(move.before) to \(move.requested)")
    }
  }

  /// Left lower than macOS lets anybody put a window, it would not stay where it stands, and is asked at the corner of its slot. At the size it has:
  /// no question makes a window larger.
  @Test func noQuestionMakesAWindowLarger() throws {
    let h = Harness(displays: [screen(1440, 900)], settings: Self.still, saved: home(knowing: [(mail, wide(760))]))
    h.controller.macOSVersion = 26
    h.scheduler.advance(by: day)
    put(mail, at: CGRect(x: 300, y: 300, width: 1000, height: 500), in: h, pid: 2000)
    put(finder, at: CGRect(x: 100, y: 100, width: 603, height: 500), in: h, pid: 2001)
    h.start()
    h.system.userMove(WindowID(101), to: CGRect(x: 300, y: 880, width: 1000, height: 500))
    h.scheduler.advance(by: 1)
    let mark = h.system.moveLog.count
    dock(101, "left", h)
    let question = try #require(h.system.moveLog.dropFirst(mark).first { $0.window == WindowID(101) })
    #expect(question.requested.width == 720, "or this proves nothing: it is asked")
    #expect(question.requested.origin != question.before.origin, "or this proves nothing: not where it stands")
    #expect(question.requested.height <= question.before.height, "\(question.requested)")
  }

  // MARK: What the product owner holds the question in sight to

  /// **Only inside an act a person asked for.** Mail has the display to itself and more room than is foreseen, so it has not been asked. Three docked
  /// windows come back from the Dock, which nobody asked Arbor for, and Mail's slot is just what is foreseen. It goes there, as it must; it is not
  /// asked anything. At the next thing its person asks for, it is.
  @Test func theQuestionInSightIsPutOnlyInsideAnActAPersonAskedFor() throws {
    let others = ["Easy", "Other", "Third"].map { App(name: $0, smallest: .zero, opens: CGSize(width: 700, height: 500)) }
    let h = run(others, knowing: home(knowing: [(mail, wide(760))]), on: screen(1728, 1117), later: day)
    for (window, side) in [(UInt32(101), "left"), (102, "right"), (103, "right")] { dock(window, side, h) }
    for window in [101, 102, 103] as [UInt32] { h.system.setMinimized(WindowID(window), true) }
    h.scheduler.advance(by: 2)
    // Only now: floating while the others were docked it would have been squeezed, and have answered for itself.
    let window = open(mail, in: h, pid: 2009)
    dock(window.rawValue, "left", h)
    #expect(try #require(h.layout?.windowFrames[window]).width > 800, "or this proves nothing: it has room to spare, and is not asked")
    var mark = h.system.moveLog.count
    for other in [101, 102, 103] as [UInt32] { h.system.setMinimized(WindowID(other), false) }
    h.scheduler.advance(by: 3)
    #expect(h.layout?.windowFrames[window]?.width == 760, "or this proves nothing: \(String(describing: h.layout?.windowFrames))")
    #expect(!h.system.moveLog.dropFirst(mark).contains { $0.window == window && $0.requested.width == 720 }, "nobody asked for anything")
    mark = h.system.moveLog.count
    h.run("show-all")
    h.scheduler.advance(by: 1)
    #expect(h.system.moveLog.dropFirst(mark).filter { $0.window == window && $0.requested.width == 720 }.count == 1, "now somebody has")
  }

  /// **Once an act, not once a stranger**, and **it never makes a window larger, on either side.** Two strangers refuse one after the other in
  /// the same act, and the plan is made three times.
  @Test func inOneActAWindowIsAskedOnceHoweverManyStrangersRefuse() throws {
    let first = App(name: "First", smallest: CGSize(width: 600, height: 300)), second = App(name: "Second", smallest: CGSize(width: 560, height: 300))
    let h = run([mail, first, second], knowing: home(knowing: [(mail, wide(760))]), on: screen(2200, 1200), later: day)
    h.system.userFocus(WindowID(101))
    let mark = h.system.moveLog.count
    h.run("layout Mail | First | Second | Desktop")
    h.scheduler.advance(by: 1)
    let moves = h.system.moveLog.dropFirst(mark)
    #expect(moves.filter { $0.window != WindowID(101) && $0.after.width > $0.requested.width + 2 }.count >= 2, "or this proves nothing: both refuse")
    let questions = moves.filter { $0.window == WindowID(101) && $0.requested.width == 720 }
    #expect(questions.count == 1, "\(road(Array(moves.filter { $0.window == WindowID(101) })))")
    for question in questions {
      #expect(question.requested.width <= question.before.width && question.requested.height <= question.before.height)
    }
  }

  // MARK: Found by the gate, on tests that came to the trunk meanwhile

  /// Its share happens to be just what is foreseen, wrongly. It gives way, the plan is made anew, and its slot is the same as before. It had been
  /// offered that size a moment earlier and taken it, which was on record, and the size the question left it at passed for its answer: it was
  /// laid in the middle of its slot, a step short (`ReviewTilingTests`, seed 10: windows of one app that go differently small).
  @Test(arguments: ["top", "left"]) func whoeverGivesWayFillsItsSlotAllTheSame(side: String) throws {
    let easy = App(name: "Easy", smallest: .zero)
    let innocent = run([easy, finder])
    dock(101, side, innocent)
    let share = try #require(innocent.layout?.windowFrames[WindowID(101)]).size
    let h = run([easy, finder], knowing: home(knowing: [(easy, side == "top" ? tall(share.height) : wide(share.width))]), later: day)
    let mark = h.system.moveLog.count
    dock(101, side, h)
    #expect(
      h.system.moveLog.dropFirst(mark).contains { side == "top" ? $0.after.height == share.height - 40 : $0.after.width == share.width - 40 },
      "or this proves nothing: it is asked, and gives way")
    #expect(h.layout?.windowFrames[WindowID(101)]?.size == share, "or this proves nothing: the slot is as before")
    expectWindowsMatchLayout(h)
  }

  /// A launch lets the window with the keyboard be where it stands, though it is a tile (Controller+LetBe.swift). **Let be means that no frame is
  /// set** (the product owner's ruling): it stands in view with the keyboard in it, so of this window the paper is believed, unasked, as of a
  /// lender. A launch is then planned on paper, as a resume is. At the first thing its person asks for it is a window like any other, and is asked
  /// like any other: where the store was too high things end as in a home that knows nothing.
  @Test(arguments: [1200, 400] as [CGFloat]) func ofTheWindowThatIsLetBeThePaperIsBelievedUntilItsPersonAsksForSomething(really: CGFloat) throws {
    var ends: [[WindowID: CGRect]?] = []
    for knows in [true, false] {
      let old = Harness(settings: Self.still)
      old.controller.macOSVersion = 26
      old.start()
      let editor = old.system.open(app: "Xcode", pid: 11, frame: CGRect(x: 100, y: 100, width: 1200, height: 600))
      old.system.setMinimumSize(editor, CGSize(width: 1200, height: 500))
      let browser = old.system.open(app: "Safari", pid: 12, frame: CGRect(x: 700, y: 100, width: 600, height: 500))
      old.run("dock \(editor.rawValue) left")
      old.run("dock \(browser.rawValue) right")
      old.scheduler.advance(by: 1)
      #expect(old.layout?.hiddenWindows == [editor], "or this proves nothing: it is a tile")
      old.controller.shutdown()
      #expect(old.store.saved?.appSizes?.entry(for: "com.example.xcode")?.width == 1200, "or this proves nothing: that is kept")
      if !knows { old.store.saved?.appSizes = nil }
      // Its sidebar may have been hidden since, and somebody has clicked it.
      old.system.setMinimumSize(editor, CGSize(width: really, height: 300))
      old.system.userFocus(editor)
      let h = old.newProcess()
      h.controller.macOSVersion = 26
      let mark = h.system.moveLog.count
      h.start()
      h.scheduler.advance(by: 2)
      if knows {
        #expect(h.controller.windowLetBe == editor, "or this proves nothing")
        #expect(h.system.moveLog.dropFirst(mark).filter { $0.window == editor }.map(\.requested) == [], "no frame at all")
      }
      h.run("show-all")
      h.scheduler.advance(by: 2)
      ends.append(h.layout?.windowFrames)
      expectWindowsMatchLayout(h)
    }
    #expect(ends[0] == ends[1], "as in a home that knows nothing")
    #expect(ends[0]?.count == (really == 400 ? 2 : 1), "or this proves nothing")
  }

  /// Larger than is foreseen of it, it would be seen to shrink for the question, and to no end if the foresight is right, which is the very fault of
  /// this row. It is believed, like a lender, until it is next in its corner.
  @Test func letBeAtMoreThanIsForeseenItIsNotMadeSmallerInSight() throws {
    let old = Harness(settings: Self.still)
    old.controller.macOSVersion = 26
    old.start()
    let editor = old.system.open(app: "Xcode", pid: 11, frame: CGRect(x: 100, y: 100, width: 1300, height: 600))
    old.system.setMinimumSize(editor, CGSize(width: 1200, height: 500))
    let browser = old.system.open(app: "Safari", pid: 12, frame: CGRect(x: 700, y: 100, width: 600, height: 500))
    old.run("dock \(editor.rawValue) left")
    old.run("dock \(browser.rawValue) right")
    old.scheduler.advance(by: 1)
    #expect(old.layout?.hiddenWindows == [editor], "or this proves nothing: it is a tile")
    old.controller.shutdown()
    let stood = try #require(old.system.frame(of: editor))
    #expect(stood.width > 1201, "or this proves nothing: it has its own size back, which is more than it must have: \(stood)")
    old.system.userFocus(editor)
    let h = old.newProcess()
    h.controller.macOSVersion = 26
    let mark = h.system.moveLog.count
    h.start()
    h.scheduler.advance(by: 2)
    #expect(h.controller.windowLetBe == editor, "or this proves nothing")
    #expect(h.system.moveLog.dropFirst(mark).filter { $0.window == editor && $0.before != $0.after }.isEmpty)
    #expect(h.frame(editor) == stood)
  }

  @Test func onceItHasAnsweredItIsNotAskedAgain() {
    let h = run([mail, finder], knowing: home(knowing: [(mail, wide(760))]), later: day)
    dock(101, "left", h)
    let mark = h.system.moveLog.count
    h.run("show-all")
    h.run("zoom 101")
    h.run("back")
    h.scheduler.advance(by: 1)
    for move in h.system.moveLog.dropFirst(mark) where move.window == WindowID(101) {
      #expect(move.requested.size == move.after.size, "asked for \(move.requested.size) though it has said how small it goes")
    }
  }

  /// Three that cannot all fit, arranged at once: whoever is a tile has not been asked, and is asked where nobody sees.
  @Test func aWindowThatWouldBeATileOnForesightIsAskedInItsCorner() throws {
    let apps = [mail, notes, finder]
    let h = run(apps, knowing: home(knowing: apps.map { ($0, $0.smallest) }), later: day)
    h.system.userFocus(WindowID(101))
    let mark = h.system.moveLog.count
    h.run("arrange")
    h.scheduler.advance(by: 1)
    let tiles = [101, 102, 103].filter { isTile(UInt32($0), h) }.map { WindowID(UInt32($0)) }
    #expect(!tiles.isEmpty)
    for window in tiles {
      let moves = h.system.moveLog.dropFirst(mark).filter { $0.window == window }
      #expect(detour(window, since: mark, h) == nil, "it leaves, and that is all anybody sees: \(road(Array(moves)))")
      let questions = moves.filter { $0.requested.size != $0.after.size }
      #expect(!questions.isEmpty, "\(window) is a tile and was never asked")
      for question in questions { #expect(!shows(question.requested, h) && !shows(question.after, h), "asked in sight: \(question)") }
    }
    for window in [101, 102, 103].map({ WindowID(UInt32($0)) }) { #expect(detour(window, since: mark, h) == nil) }
    expectWindowsMatchLayout(h)
  }

  // MARK: Heights, as widths

  private func tall(_ height: CGFloat) -> CGSize { CGSize(width: 0, height: height) }

  private func low(_ app: App, _ height: CGFloat) -> App {
    var app = app
    app.smallest.height = height
    return app
  }

  /// One above the other, 751 points for both: 480 and 400 do not fit.
  @Test func inAColumnEachOfAPairThatCannotBothFitMovesOnceToo() {
    let music = App(name: "Music", smallest: CGSize(width: 300, height: 480))
    let apps = [music, low(slim(mail, 300), 400)]
    let h = run(apps, knowing: home(knowing: apps.map { ($0, $0.smallest) }), later: day)
    expectOneMoveEach(h, "the first") { dock(101, "left", h) }
    expectOneMoveEach(h, "the second") {
      h.system.userFocus(WindowID(102))
      h.run("dock 102 beside 101 bottom")
      h.scheduler.advance(by: 1)
    }
    #expect(isTile(101, h) != isTile(102, h))
    expectWindowsMatchLayout(h)
  }

  @Test(arguments: [0, 1]) func aHeightThatIsTooHighCostsNobodyItsPlaceEither(wrong: Int) {
    let music = App(name: "Music", smallest: CGSize(width: 300, height: 480))
    var apps = [music, low(slim(mail, 300), 400)]
    let store = home(knowing: apps.map { ($0, tall($0.smallest.height)) })
    apps[wrong] = low(apps[wrong], 150)
    expectTheSameEnd(apps, knowing: store) { h in
      dock(101, "left", h)
      h.system.userFocus(WindowID(102))
      h.run("dock 102 beside 101 bottom")
      h.scheduler.advance(by: 1)
    }
  }

  // MARK: Who pays when the store is wrong

  /// The questions come first: nobody is moved into a plan that is overturned a moment later.
  @Test func whenTheForesightIsWrongTheNeighboursStillMoveOnce() {
    let easy = App(name: "Easy", smallest: CGSize(width: 200, height: 200))
    let going = App(name: "Going", smallest: CGSize(width: 200, height: 200))
    let h = run([easy, going, slim(mail, 250)], knowing: home(knowing: [(mail, wide(760))]), later: day)
    dock(101, "left", h)
    dock(102, "right", h)
    let mark = h.system.moveLog.count
    dock(103, "left", h)
    for window in [WindowID(101), WindowID(102)] {
      #expect(detour(window, since: mark, h) == nil, "\(window) went \(road(seen(since: mark, h)[window] ?? []))")
    }
    expectWindowsMatchLayout(h)
  }

  /// Killed with Mail at the 900 points it stood by, a sheet open, and Finder a tile for it. The sheet is closed; nothing tells Arbor. At the start
  /// Mail is where it belongs, and is asked all the same.
  @Test func aWindowThatIsInItsPlaceAlreadyIsAskedAllTheSame() {
    let old = run([slim(mail, 900), finder])
    old.system.userFocus(WindowID(101))
    old.run("arrange")
    old.scheduler.advance(by: 1)
    #expect(isTile(102, old))
    old.controller.saveNow()
    old.system.setMinimumSize(WindowID(101), CGSize(width: 400, height: 300))

    let h = Harness(displays: [laptop], settings: Self.still, saved: old.store.saved, system: old.system)
    h.controller.macOSVersion = 26
    h.scheduler.advance(by: day)
    h.start()
    h.scheduler.advance(by: 1)
    #expect(!isTile(101, h) && !isTile(102, h))
    expectWindowsMatchLayout(h)
  }

  /// And if the sheet is still open, nothing shows.
  @Test func askedInItsPlaceAWindowThatStandsByItIsNotSeenToChange() {
    let old = run([slim(mail, 900), finder])
    old.system.userFocus(WindowID(101))
    old.run("arrange")
    old.scheduler.advance(by: 1)
    old.controller.saveNow()

    let h = Harness(displays: [laptop], settings: Self.still, saved: old.store.saved, system: old.system)
    h.controller.macOSVersion = 26
    h.scheduler.advance(by: day)
    let mark = h.system.moveLog.count
    h.start()
    h.scheduler.advance(by: 1)
    #expect(h.system.moveLog.dropFirst(mark).contains { $0.window == WindowID(101) && $0.requested.width == 860 }, "it is asked")
    #expect(seen(since: mark, h)[WindowID(101)] == nil)
  }

  /// What is left, decided by the product owner: a window that would have to LEND room, in view in a slot larger than what is foreseen of it, cannot
  /// be asked for nothing: in sight it would go there and back whenever the store is right. The paper is believed. The way back is
  /// what a person does next: they click the tile.
  @Test func aLenderIsBelievedUntilItNextGoesOutOfView() {
    let store = home(knowing: [(xcode, wide(1188)), (finder, wide(501))])
    let h = run([xcode, slim(finder, 300)], knowing: store, on: desk, later: day)
    dock(102, "left", h)
    dock(101, "right", h)
    #expect(isTile(101, h), "1188 and 501 do not fit, on paper")
    let mark = h.system.moveLog.count
    h.run("zoom 101")
    h.scheduler.advance(by: 1)
    for move in h.system.moveLog.dropFirst(mark) where move.window == WindowID(102) && move.requested.size != move.before.size {
      #expect(!shows(move.requested, h) && !shows(move.after, h), "asked in sight: \(move)")
    }
    h.run("back")
    h.scheduler.advance(by: 1)
    #expect(!isTile(101, h) && !isTile(102, h), "it goes down to 300: both fit")
    expectWindowsMatchLayout(h)
    h.controller.saveNow()
    #expect(kept(finder, in: h.store.saved)?.width ?? 0 < 501)
  }

  /// A question is a round trip to an app, and squeezes its window.
  @Test func whereNobodyIsATileWhoeverTheViewLeavesIsNotAsked() {
    let apps = [slim(mail, 500), finder]
    let h = run(apps, knowing: home(knowing: [(mail, wide(500)), (finder, wide(501))]), on: desk, later: day)
    dock(101, "left", h)
    dock(102, "right", h)
    #expect(!isTile(101, h) && !isTile(102, h))
    let mark = h.system.moveLog.count
    h.run("zoom 101")
    h.scheduler.advance(by: 1)
    #expect(h.system.moveLog.dropFirst(mark).filter { $0.window == WindowID(102) }.count == 1, "it is parked, and that is all")
  }

  /// Whatever goes by the size of a window out of view finds the size it had, and the way back is as it would have been.
  @Test func whoeverIsAskedInItsCornerHasItsSizeBackThere() throws {
    let store = home(knowing: [(xcode, wide(1188)), (finder, finder.smallest)])
    let h = run([xcode, finder], knowing: store, on: desk, later: day)
    dock(102, "left", h)
    dock(101, "right", h)
    #expect(isTile(101, h))
    let inView = try #require(h.frame(WindowID(102))).size
    let mark = h.system.moveLog.count
    h.run("zoom 101")
    h.scheduler.advance(by: 1)
    #expect(h.system.moveLog.dropFirst(mark).contains { $0.window == WindowID(102) && $0.requested.width == 461 }, "it is asked")
    #expect(h.frame(WindowID(102))?.size == inView)
    #expect(!h.system.isVisible(WindowID(102)))
    for move in h.system.moveLog.dropFirst(mark + 1) where move.window == WindowID(102) && move.before != move.after {
      #expect(!shows(move.after, h), "\(move)")
    }
    h.run("float-all")
    h.scheduler.advance(by: 1)
    #expect(h.frame(WindowID(102))?.size == CGSize(width: 920, height: 436), "its own size, as it floated")
  }

  /// A slot that happens to be a point or two larger than what is foreseen does not rest on it.
  @Test(arguments: [1, 2] as [CGFloat]) func aSlotThatIsALittleLargerIsNotAskedAbout(over: CGFloat) throws {
    let innocent = run([safari, App(name: "Easy", smallest: .zero)], later: day)
    dock(101, "left", innocent)
    let slot = try #require(innocent.frame(WindowID(101))).width
    let h = run([slim(safari, slot - over), App(name: "Easy", smallest: .zero)], knowing: home(knowing: [(safari, wide(slot - over))]), later: day)
    expectOneMoveEach(h, "Safari") { dock(101, "left", h) }
    #expect(h.frame(WindowID(101))?.width == slot)
  }

  /// Only just back from the Dock a window may not be ready to take a frame, and its answer would mean nothing. Nor did anybody ask Arbor for the
  /// layouts that its coming back sets off, so they go by the paper. It is asked at the next thing its person asks for, whether it took the
  /// frame it was given meanwhile, with the room that was made for it, or none at all.
  @Test(arguments: [0, 0.4]) func aWindowThatHasOnlyJustComeBackIsAskedAtTheNextThingItsPersonAsksFor(flight: Double) {
    let h = run([slim(mail, 300), finder], knowing: home(knowing: [(mail, wide(760))]), later: day)
    h.system.setMinimized(WindowID(101), true)
    h.scheduler.advance(by: 1)
    h.run("dock 101 left")
    h.scheduler.advance(by: 1)
    // On its way out of the Dock it takes no frame: asked now, it would seem to stand by the 1000 points it has.
    h.system.echoes.flightFromTheDock = flight
    let mark = h.system.moveLog.count
    h.system.setMinimized(WindowID(101), false)
    h.scheduler.advance(by: 5)
    #expect(!h.system.moveLog.dropFirst(mark).contains { $0.window == WindowID(101) && $0.requested.width == 720 }, "nobody asked for anything")
    h.run("show-all")
    h.scheduler.advance(by: 1)
    h.controller.saveNow()
    #expect(kept(mail, in: h.store.saved)?.width ?? 0 < 760, "\(String(describing: kept(mail, in: h.store.saved)))")
    #expect(h.frame(WindowID(101))?.width ?? 0 < 700, "it goes down to 300, and nobody holds it to 760: \(String(describing: h.frame(WindowID(101))))")
    expectWindowsMatchLayout(h)
  }

  /// Its person asks for something while it is still on its way out of the Dock. It takes no frame then: asked now, it would seem to stand by the
  /// 1000 points it has, and be held to them.
  @Test func aWindowThatIsStillOnItsWayBackIsNotAskedThoughItsPersonAsksForSomething() {
    let h = run([slim(mail, 300), finder], knowing: home(knowing: [(mail, wide(760))]), later: day)
    h.system.setMinimized(WindowID(101), true)
    h.scheduler.advance(by: 1)
    h.run("dock 101 left")
    h.scheduler.advance(by: 1)
    h.system.echoes.flightFromTheDock = 0.4
    h.system.setMinimized(WindowID(101), false)
    h.run("show-all")
    h.scheduler.advance(by: 5)
    h.run("show-all")
    h.scheduler.advance(by: 1)
    #expect(h.frame(WindowID(101))?.width ?? 0 < 700, "it goes down to 300, and nobody holds it to more: \(String(describing: h.frame(WindowID(101))))")
    expectWindowsMatchLayout(h)
  }

  /// A drop is an act a person asked for, like a command.
  @Test func aWindowThatIsDroppedIsAskedLikeOneThatIsDockedByAKey() throws {
    var small = mail
    small.opens = CGSize(width: 790, height: 600)
    let h = run([small, finder], knowing: home(knowing: [(mail, wide(760)), (finder, wide(501))]), on: desk, settings: Settings(), later: day)
    dock(102, "right", h)
    let start = try #require(h.frame(WindowID(101)))
    h.system.tiling = .off  // the screen's edges are Arbor's only with macOS's tiling off
    let mark = h.system.moveLog.count
    h.system.drag(WindowID(101), through: [CGPoint(x: start.midX, y: start.minY + 10), CGPoint(x: 300, y: 400), CGPoint(x: 3, y: 450)])
    h.scheduler.advance(by: 1)
    #expect(h.layout?.windowFrames[WindowID(101)]?.width == 760, "or this proves nothing")
    #expect(h.system.moveLog.dropFirst(mark).filter { $0.window == WindowID(101) && $0.requested.width == 720 }.count == 1)
  }

  /// Found by the walks, in a home that has met the apps.
  @Test func whileAnAppHangsWhatIsShownIsWhatALayoutMadeNowWouldSay() {
    let h = run([mail, finder], knowing: home(knowing: [(mail, wide(760))]), later: day)
    h.system.setUnresponsive(pid: 2000, true)
    dock(101, "left", h)
    #expect(h.controller.freshLayout(of: h.display)?.windowFrames == h.layout?.windowFrames)
    #expect(h.controller.freshLayout(of: h.display)?.tiles == h.layout?.tiles)
    h.system.setUnresponsive(pid: 2000, false)
    h.scheduler.advance(by: 5)
    h.run("show-all")
    h.scheduler.advance(by: 1)
    #expect(h.frame(WindowID(101))?.width == 760)
    #expect(h.controller.freshLayout(of: h.display)?.windowFrames == h.layout?.windowFrames)
    expectWindowsMatchLayout(h)
  }

  @Test func whatCannotBeAskedAboutIsNotGoneBy() {
    let store = home(knowing: [(mail, wide(900))])
    // While it hangs nobody gives room for what is only foreseen of it.
    expectTheSameEnd([slim(mail, 400), finder], knowing: store, everyoneAnswers: false) { h in
      h.system.setUnresponsive(pid: 2000, true)
      dock(101, "left", h)
      dock(102, "right", h)
    }
    expectTheSameEnd([slim(mail, 400), finder], knowing: store) { h in
      h.system.setUnresponsive(pid: 2000, true)
      dock(101, "left", h)
      dock(102, "right", h)
      h.system.setUnresponsive(pid: 2000, false)
      h.scheduler.advance(by: 5)
      h.run("show-all")
      h.scheduler.advance(by: 1)
    }
  }

  /// Which arrangement a key makes is chosen by what windows answered. Only frames are foreseen.
  @Test(arguments: [250, 501] as [CGFloat]) func whateverChoosesAnArrangementGoesByAnswersAlone(really: CGFloat) {
    let apps = [slim(finder, really), slim(safari, 300)]
    let knowing = run(apps, knowing: home(knowing: [(finder, wide(501))]), on: desk, later: day)
    let innocent = run(apps, on: desk, later: day)
    for h in [knowing, innocent] {
      dock(102, "left", h)
      h.system.userFocus(WindowID(101))
      h.run("dock 101 beside 102 top")
      h.scheduler.advance(by: 1)
      h.run("dock 101 right")
      h.scheduler.advance(by: 1)
    }
    #expect(knowing.workspace.tree.preorder() == innocent.workspace.tree.preorder())
    #expect(knowing.layout?.windowFrames == innocent.layout?.windowFrames)
  }

  /// A preview is a promise, as far as Arbor knows. Mail has never been asked anything: there is room for it on the Desktop as it is.
  @Test func thePreviewOfADropIsWorkedOutWithWhatIsForeseen() throws {
    var small = mail
    small.opens = CGSize(width: 790, height: 600)
    let h = run([small, finder], knowing: home(knowing: [(mail, wide(760)), (finder, wide(501))]), on: desk, settings: Settings(), later: day)
    dock(102, "right", h)
    let start = try #require(h.frame(WindowID(101)))
    #expect(start.width == 790, "nobody has squeezed it")
    h.system.tiling = .off  // the screen's edges are Arbor's only with macOS's tiling off
    h.system.drag(WindowID(101), through: [CGPoint(x: start.midX, y: start.minY + 10), CGPoint(x: 300, y: 400), CGPoint(x: 3, y: 450)])
    h.scheduler.advance(by: 1)
    let preview = try #require(h.overlays.previewHistory.compactMap { $0 }.last)
    #expect(preview.width == 760, "a third of the display is less: \(preview)")
    #expect(try #require(h.frame(WindowID(101))).approximatelyEquals(preview, tolerance: 1), "\(preview)")
  }

  // MARK: More than one round

  /// Mail gives way, and in the plan that follows there is room for Notes, as much as is foreseen of it: that is asked about in its turn.
  @Test func whereTheStoreIsWrongAboutTwoBothAreAskedInTheSameLayout() {
    let store = home(knowing: [(mail, wide(900)), (notes, wide(709))])
    expectTheSameEnd([slim(mail, 300), slim(notes, 250)], knowing: store) { h in
      h.system.userFocus(WindowID(101))
      h.run("arrange")
      h.scheduler.advance(by: 1)
    }
  }

  /// Found by the walks. Under the hand a window foreseen at 574 is offered 572 and stops two points over, which is no refusal. It has been asked:
  /// the next layout must not make a tile of it.
  @Test func aPointOrTwoOverUnderTheHandMakesNoTileAfterwards() throws {
    let h = run([safari, App(name: "Easy", smallest: .zero)], knowing: home(knowing: [(safari, wide(574))]), later: day)
    dock(101, "left", h)
    let width = try #require(h.frame(WindowID(101))).width
    #expect(h.run("resize 101 right \(Int(572 - width))").ok)
    h.scheduler.advance(by: 1)
    #expect(h.layout?.windowFrames[WindowID(101)]?.width == 572)
    #expect(h.controller.freshLayout(of: h.display)?.windowFrames[WindowID(101)] != nil, "what a layout made now would say")
    h.run("show-all")
    h.scheduler.advance(by: 1)
    #expect(!isTile(101, h))
  }

  /// Offered 572 under the hand, it has been asked. So has the tab that comes to the front in its place: it must not be a tile at the next layout.
  @Test func thatItHasBeenAskedPassesToTheTabThatComesToTheFront() throws {
    let h = run([safari, App(name: "Easy", smallest: .zero)], knowing: home(knowing: [(safari, wide(574))]), later: day)
    dock(101, "left", h)
    let width = try #require(h.frame(WindowID(101))).width
    #expect(h.run("resize 101 right \(Int(572 - width))").ok)
    h.scheduler.advance(by: 1)
    let tab = try #require(h.system.openTab(in: WindowID(101)))
    h.scheduler.advance(by: 1)
    #expect(h.controller.freshLayout(of: h.display)?.windowFrames[tab] != nil)
    h.run("show-all")
    h.scheduler.advance(by: 1)
    #expect(!isTile(tab.rawValue, h))
  }

  /// The record passes to it with the day it was stood by: nobody has stood by anything.
  @Test func aTabThatComesToTheFrontRenewsNothing() throws {
    let h = run([mail, finder])
    dock(101, "left", h)
    h.controller.saveNow()
    let before = try #require(kept(mail, in: h.store.saved))
    h.scheduler.advance(by: 10 * day)
    _ = try #require(h.system.openTab(in: WindowID(101)))
    h.scheduler.advance(by: 1)
    h.run("show-all")
    h.scheduler.advance(by: 1)
    h.controller.saveNow()
    #expect(kept(mail, in: h.store.saved) == before)
  }

  /// Found by the walks. Two windows of Mail are arranged at once, one of them only just back from the Dock, so that what it makes of its slot does not
  /// count yet. The other refuses, and its app is known from then on. What is shown must still be what a layout made now would say.
  @Test func aWindowWhoseAnswerDoesNotCountYetIsNotForeseenByWhatItsSiblingTeachesMeanwhile() {
    let h = run([mail, mail], on: FakeWindowSystem.standardDisplay)
    h.system.setMinimized(WindowID(102), true)
    h.scheduler.advance(by: 0.1)
    h.system.setMinimized(WindowID(102), false)
    h.run("arrange")
    #expect(h.controller.freshLayout(of: h.display)?.windowFrames == h.layout?.windowFrames)
    #expect(h.controller.freshLayout(of: h.display)?.tiles == h.layout?.tiles)
    h.scheduler.advance(by: 5)
    #expect(h.controller.freshLayout(of: h.display)?.windowFrames == h.layout?.windowFrames)
    expectWindowsMatchLayout(h)
  }

  /// A tab that comes to the front of its group stands for the one that was there, also in what is foreseen of it.
  @Test func whatIsForeseenPassesToTheTabThatComesToTheFront() throws {
    let h = run([mail, finder], knowing: home(knowing: [(mail, wide(760))]), later: day)
    let tab = try #require(h.system.openTab(in: WindowID(101)))
    h.scheduler.advance(by: 1)
    let mark = h.system.moveLog.count
    // On the right, where a stranger that refuses is seen to move twice: it grows over the edge and is fetched back.
    dock(tab.rawValue, "right", h)
    #expect(h.frame(tab)?.width == 760)
    #expect(detour(tab, since: mark, h) == nil, "\(road(seen(since: mark, h)[tab] ?? []))")
  }

  // MARK: What is foreseen is looked up, not copied

  /// On a first day that is every window that was open at the start.
  @Test func aWindowThatWasOpenBeforeItsAppWasMetIsNoStrangerAfterwards() {
    let h = run([mail, finder])
    let second = open(mail, in: h, pid: 2000)
    h.scheduler.advance(by: 1)
    dock(101, "left", h)
    h.run("float-all")
    h.scheduler.advance(by: 1)
    h.system.close(WindowID(101))
    h.scheduler.advance(by: 1)
    // On the right, where a stranger that refuses is seen to move twice.
    expectOneMoveEach(h, "the other window of Mail") { dock(second.rawValue, "right", h) }
    #expect(h.frame(second)?.width == 760)
  }

  private func aLenderThatIsBelieved() -> Harness {
    let store = home(knowing: [(xcode, wide(1188)), (finder, wide(501))])
    let h = run([xcode, slim(finder, 300)], knowing: store, on: desk, later: day)
    dock(102, "left", h)
    dock(101, "right", h)
    #expect(isTile(101, h), "1188 and 501 do not fit, on paper")
    return h
  }

  @Test func whenTheEntryIsTooOldSoIsWhatIsForeseenOfTheWindowsThatAreThere() {
    let h = aLenderThatIsBelieved()
    h.scheduler.advance(by: 31 * day)
    h.run("show-all")
    h.scheduler.advance(by: 1)
    #expect(!isTile(101, h) && !isTile(102, h), "thirty days are the end of a lender's credit, in the same run too")
    expectWindowsMatchLayout(h)
  }

  @Test func anotherDockedWindowOfTheAppThatGoesSmallerEndsItToo() {
    let h = aLenderThatIsBelieved()
    let other = h.system.open(
      app: "Finder", pid: 2001, frame: CGRect(x: 40, y: 60, width: 320, height: 300), minimumSize: CGSize(width: 200, height: 200))
    h.scheduler.advance(by: 1)
    h.system.userFocus(other)
    h.run("dock \(other.rawValue) beside 102 bottom")
    h.scheduler.advance(by: 1)
    h.run("resize \(other.rawValue) right -150")
    h.scheduler.advance(by: 1)
    h.run("show-all")
    h.scheduler.advance(by: 1)
    h.controller.saveNow()
    #expect(kept(finder, in: h.store.saved)?.width ?? 0 < 501)
  }

  /// In its corner it has the size it had again in a moment: the store is told there and then, not when somebody happens to see it smaller.
  @Test func whoeverGivesWayInItsCornerPutsTheStoreRightAtOnce() {
    let h = aLenderThatIsBelieved()
    h.run("zoom 101")
    h.scheduler.advance(by: 1)
    h.controller.saveNow()
    #expect(kept(finder, in: h.store.saved) == nil, "\(String(describing: kept(finder, in: h.store.saved)))")
  }

  // MARK: Whatever chooses goes by answers; whatever tries reckons as the layout does

  /// A refusal comes before any layout, so that nobody would ever be asked.
  @Test func aCommandIsNotRefusedBecauseOfWhatIsOnlyForeseen() {
    let tallApp = App(name: "Tall", smallest: CGSize(width: 200, height: 200))
    let easy = App(name: "Easy", smallest: CGSize(width: 200, height: 200))
    let knowing = run([tallApp, easy], knowing: home(knowing: [(tallApp, tall(700))]), later: day)
    let innocent = run([tallApp, easy], later: day)
    for h in [knowing, innocent] {
      dock(101, "left", h)
      dock(102, "right", h)
      h.system.userFocus(WindowID(101))
    }
    let (said, control) = (knowing.run("rotate"), innocent.run("rotate"))
    #expect(said.ok == control.ok, "\(said.message)")
    knowing.scheduler.advance(by: 1)
    innocent.scheduler.advance(by: 1)
    #expect(knowing.layout?.windowFrames == innocent.layout?.windowFrames)
  }

  /// Mail is docked and out of view, the view on a group beside it, when the display becomes a smaller one on which Mail's share is less than is foreseen
  /// of it. Switched to, it comes into view beside the others, as in a home that knows nothing: not framed alone because of a size nobody has
  /// asked it about.
  @Test func theViewIsNotChosenByWhatIsOnlyForeseen() {
    let apps = [slim(mail, 300), App(name: "Easy", smallest: .zero), App(name: "Going", smallest: .zero)]
    let knowing = run(apps, knowing: home(knowing: [(mail, wide(760))]), on: studio, later: day)
    let innocent = run(apps, on: studio, later: day)
    for h in [knowing, innocent] {
      dock(101, "left", h)
      dock(102, "right", h)
      h.system.userFocus(WindowID(103))
      h.run("dock 103 beside 102 bottom")
      h.scheduler.advance(by: 1)
      h.run("zoom 102")
      h.run("out")
      h.scheduler.advance(by: 1)
      #expect(!h.system.isVisible(WindowID(101)))
      h.system.setDisplays([laptop])
      h.scheduler.advance(by: 2)
      h.system.userFocus(WindowID(101))
      h.scheduler.advance(by: 2)
    }
    #expect(innocent.workspace.camera == innocent.workspace.tree.root, "the test's own premise")
    #expect(knowing.workspace.camera == innocent.workspace.camera)
    #expect(knowing.layout?.windowFrames == innocent.layout?.windowFrames)
  }

  /// Automatic docking tries a place and takes it back. If its plan and the layout reckoned differently it would do so round after round, with
  /// nothing learned in between.
  @Test func automaticDockingDoesNotTryWhatTheLayoutWillNotGive() {
    var settings = Self.still
    settings.newWindows = "dock"
    let easy = App(name: "Easy", smallest: CGSize(width: 300, height: 200))
    var counts: [Int] = []
    for store in [home(knowing: [(finder, wide(501))]), nil] {
      let h = run([finder, easy], knowing: store, on: studio, settings: settings, later: day)
      dock(101, "left", h)
      dock(102, "right", h)
      let mark = h.system.moveLog.count
      h.system.open(app: "Huge", pid: 2005, frame: CGRect(x: 100, y: 60, width: 1900, height: 1100), minimumSize: CGSize(width: 1800, height: 1030))
      h.scheduler.advance(by: 3)
      counts.append(h.system.moveLog.count - mark)
      expectWindowsMatchLayout(h)
    }
    #expect(counts[1] > 0, "the test's own premise: it is tried")
    #expect(counts[0] <= counts[1], "\(counts[0]) frames set, and \(counts[1]) in a home that knows nothing")
  }

  // MARK: Time

  @Test func merelyForeseeingRenewsNothing() {
    let store = home(knowing: [(finder, wide(501))])
    let h = run([finder, App(name: "Easy", smallest: .zero)], knowing: store, later: 29 * day)
    // Half the display is more than it needs, so nothing rests on what is foreseen, nobody is asked and nobody stands by anything.
    dock(101, "left", h)
    h.controller.saveNow()
    #expect(kept(finder, in: h.store.saved) == kept(finder, in: store))

    let late = run([finder], knowing: h.store.saved, later: 31 * day)
    #expect(late.controller.appSizes.isEmpty)
  }

  @Test func aWindowThatStandsByItRenewsIt() throws {
    let store = home(knowing: [(mail, wide(760))])
    let h = run([mail, finder], knowing: store, later: 29 * day)
    dock(101, "left", h)
    h.controller.saveNow()
    let after = try #require(kept(mail, in: h.store.saved))
    #expect(after.width == 760)
    #expect(after.seen.timeIntervalSince(try #require(kept(mail, in: store)).seen) >= 29 * day)
  }

  @Test func soDoesOneThatStandsByItInItsCorner() throws {
    let apps = [mail, notes, finder]
    // Widths only: the date is renewed when all that is known has been stood by, and in its corner it is short of width alone.
    let store = home(knowing: apps.map { ($0, wide($0.smallest.width)) })
    let h = run(apps, knowing: store, later: 29 * day)
    h.system.userFocus(WindowID(101))
    h.run("arrange")
    h.scheduler.advance(by: 1)
    h.controller.saveNow()
    let tile = try #require(zip(apps, [101, 102, 103]).first { isTile(UInt32($0.1), h) }?.0)
    let after = try #require(kept(tile, in: h.store.saved))
    #expect(after.width == Double(tile.smallest.width))
    #expect(after.seen.timeIntervalSince(try #require(kept(tile, in: store)).seen) >= 29 * day)
  }

  /// A record that its person's hand has brought down is a size nobody stood by.
  @Test func aDockedWindowMadeSmallerByHandDisprovesAndRenewsNothing() throws {
    let h = run([mail, finder])
    dock(101, "left", h)
    h.controller.saveNow()
    #expect(kept(mail, in: h.store.saved)?.width == 760)
    // The sidebar is hidden, and the window is made narrower by its own edge.
    h.system.setMinimumSize(WindowID(101), CGSize(width: 300, height: 200))
    var frame = try #require(h.frame(WindowID(101)))
    frame.size.width = 700
    h.system.userMove(WindowID(101), to: frame)
    h.scheduler.advance(by: 2)
    h.controller.saveNow()
    #expect(kept(mail, in: h.store.saved) == nil, "not 700, with today's date")
  }

  /// It is in the file no longer than it is gone by.
  @Test func inALongRunWhatIsTooOldLeavesTheFileToo() {
    let h = run([finder, App(name: "Easy", smallest: .zero)], knowing: home(knowing: [(notes, wide(709))]), later: day)
    h.scheduler.advance(by: 30 * day)
    dock(102, "left", h)
    h.controller.saveNow()
    #expect(h.store.saved?.appSizes == nil)
  }

  @Test func whatWasSeenOnAnotherMacOSIsNotGoneBy() {
    let known = whatIsKnownAfterADay(with: [mail, finder])
    let h = run([mail, finder], knowing: known, macOS: 27)
    #expect(h.controller.appSizes.isEmpty)
  }

  /// Arbor runs for weeks, and a start is not what makes a thing old.
  @Test func aWindowThatOpensAMonthLaterInTheSameRunIsAStranger() {
    let h = run([mail, finder])
    dock(101, "left", h)
    dock(102, "right", h)
    h.run("float-all")
    h.scheduler.advance(by: 31 * day)
    let late = open(mail, in: h, pid: 2000)
    h.system.setMinimumSize(late, CGSize(width: 300, height: 200))
    h.system.close(WindowID(101))
    h.scheduler.advance(by: 1)
    expectOneMoveEach(h, "it is offered its share at once, not a step less than was once known") { dock(late.rawValue, "left", h) }
    let half = h.visibleFrame.width / 2
    #expect(h.frame(late)!.width < half, "nobody holds it to 760 any more: \(h.frame(late)!.width)")
    expectWindowsMatchLayout(h)
  }

  // MARK: Traces

  @Test func aTraceSaysWhatWasKnownOfTheAppsInItAndOfNoOther() throws {
    let known = whatIsKnownAfterADay(with: [mail, finder, notes])
    let h = run([mail, finder], knowing: known, later: 3600)
    h.run("trace on sizes")
    h.run("trace off")
    let first = try #require(h.lastTrace?.split(separator: "\n").first)
    let header = try JSONDecoder().decode(TraceHeader.self, from: Data(first.utf8))
    #expect(header.appSizes?.apps.keys.sorted() == ["com.example.finder", "com.example.mail"])
    #expect(!first.contains("com.example.notes"), "which apps somebody has used this month is nobody's business")
    #expect(header.askedAbout.isEmpty)

    // Put back on a clock and a system of its own, it is as old as it was.
    let replay = Harness(displays: [laptop], settings: Self.still)
    replay.controller.macOSVersion = 6
    replay.controller.restore(from: header)
    let entry = try #require(replay.controller.appSizes.entry(for: "com.example.mail"))
    #expect(entry.width == 760)
    #expect(entry.macOS == 6)
    let age = replay.controller.now().timeIntervalSince(entry.seen)
    #expect(age > 3000 && age < 3700, "about the hour it was: \(age)")
  }

  /// The header can tell only of the apps that have a window when the recording begins. A scenario's trace begins before anything is open.
  @Test(arguments: [TraceReplayer.Mode.free, .strict]) func aReplayForeseesAnAppWhoseFirstWindowCameDuringTheRecording(mode: TraceReplayer.Mode) {
    let h = run([], knowing: whatIsKnownAfterADay(with: [mail, finder, notes]), later: day)
    h.run("trace on later")
    open(mail, in: h, pid: 2000)
    open(finder, in: h, pid: 2001)
    for (window, side) in [(UInt32(101), "left"), (UInt32(102), "right")] {
      let mark = h.system.moveLog.count
      dock(window, side, h)
      for docked in h.workspace.tree.allWindows { #expect(detour(docked, since: mark, h) == nil, "or this proves nothing: the recording foresaw them") }
    }
    h.run("trace off")
    let replayer = TraceReplayer(recordedTrace(h), mode: mode)
    #expect(replayer.run().problems == [])
    for window in [WindowID(101), WindowID(102)] { #expect(replayer.harness.frame(window) == h.frame(window)) }
  }

  @Test func whatIsKnownOfSuchAnAppIsToldOnceAndOfNoOtherApp() throws {
    let h = run([], knowing: whatIsKnownAfterADay(with: [mail, finder, notes]), later: day)
    h.run("trace on later")
    open(mail, in: h, pid: 2000)
    // By now the store has been told anew by the first window, and dated anew.
    dock(101, "right", h)
    open(mail, in: h, pid: 2000)
    open(safari, in: h, pid: 2002)
    h.run("trace off")
    let text = try #require(h.lastTrace)
    let told = recordedTrace(h).entries.compactMap { entry -> (WindowID, AppSizes.Entry)? in
      guard case .other(.read, AppSizes.traceLine, let arguments, let result?) = entry.line, let window: WindowID = arguments.first?.decoded(),
        let known: AppSizes.Entry = result.decoded()
      else { return nil }
      return (window, known)
    }
    #expect(told.map(\.0) == [WindowID(101)], "once for the app, at its first window; nothing where nothing is known")
    #expect(told.first?.1.width == 760)
    #expect(!text.contains("com.example.finder") && !text.contains("com.example.notes"), "which apps somebody has used is nobody's business")
  }

  /// A window can come to Arbor's notice otherwise than by appearing. (Not at a start: a pause ends the recording.)
  @Test func soIsTheTraceIfTheFirstThatIsHeardOfTheWindowIsThatItMoved() throws {
    let h = run([], knowing: whatIsKnownAfterADay(with: [mail]), later: day)
    h.run("trace on later")
    let listener = h.system.events
    h.system.events = nil
    let window = open(mail, in: h, pid: 2000)
    h.system.events = listener
    h.system.userMove(window, to: CGRect(x: 60, y: 60, width: 1000, height: 700))
    h.run("trace off")
    #expect(try #require(h.lastTrace).contains(AppSizes.traceLine))
    let replayer = TraceReplayer(recordedTrace(h), mode: .free)
    replayer.run()
    #expect(replayer.harness.controller.appSizes.entry(for: "com.example.mail")?.width == 760, "and the replay knows whose window that is")
  }

  @Test func ofAnAppThatTheHeaderTellsOfNoLineIsWritten() throws {
    let h = run([mail], knowing: whatIsKnownAfterADay(with: [mail]), later: day)
    h.run("trace on second")
    open(mail, in: h, pid: 2000)
    h.run("trace off")
    #expect(!(try #require(h.lastTrace)).contains(AppSizes.traceLine))
  }

  /// Found by a reader: whatever is text in such a line is searched for the names people give to spaces, and `com.example.mail` with a space
  /// called Mail came out as another app's. So the line holds no text: it names the window, whose own line says which app it is of.
  @Test(arguments: [TraceReplayer.Mode.free, .strict]) func aSpaceNamedLikeTheAppCostsTheReplayNothing(mode: TraceReplayer.Mode) throws {
    let h = run([App(name: "Easy", smallest: .zero)], knowing: whatIsKnownAfterADay(with: [mail, finder]), later: day)
    dock(101, "left", h)
    #expect(h.run("name mail").ok)
    h.run("float-all")
    h.scheduler.advance(by: 1)
    h.run("trace on later")
    open(mail, in: h, pid: 2001)
    open(finder, in: h, pid: 2002)
    dock(102, "left", h)
    dock(103, "right", h)
    h.run("trace off")
    let text = try #require(h.lastTrace)
    let line = try #require(text.split(separator: "\n").first { $0.contains(AppSizes.traceLine) })
    #expect(!line.contains("com."), "numbers only: \(line)")
    let replayer = TraceReplayer(recordedTrace(h), mode: mode)
    #expect(replayer.run().problems == [])
    #expect(replayer.harness.controller.appSizes.entry(for: "com.example.mail")?.width == 760)
  }

  @Test func theNextRecordingIsToldAfresh() throws {
    let h = run([], knowing: whatIsKnownAfterADay(with: [mail]), later: day)
    for name in ["first", "second"] {
      h.run("trace on \(name)")
      let window = open(mail, in: h, pid: 2000)
      h.run("trace off")
      #expect(try #require(h.lastTrace).contains(AppSizes.traceLine), "the \(name)")
      h.system.close(window)
    }
  }

  /// A replay must not ask whom the recording had asked already.
  @Test func aTraceSaysWhoHasBeenAsked() throws {
    let h = run([mail, finder], knowing: home(knowing: [(mail, wide(760))]), later: day)
    dock(101, "left", h)
    h.run("trace on sizes")
    h.run("trace off")
    let first = try #require(h.lastTrace?.split(separator: "\n").first)
    let header = try JSONDecoder().decode(TraceHeader.self, from: Data(first.utf8))
    #expect(header.askedAbout == [WindowID(101): "w"])
    #expect(header.minimumSizes[WindowID(101)]?.width == 760, "and what it answered")

    // Put back, it is known again: a trace of the replay says the same.
    let replay = Harness(displays: [laptop], settings: Self.still, system: h.system)
    replay.controller.macOSVersion = 26
    replay.controller.restore(from: header)
    replay.start()
    replay.run("trace on again")
    replay.run("trace off")
    let again = try JSONDecoder().decode(TraceHeader.self, from: Data(try #require(replay.lastTrace?.split(separator: "\n").first).utf8))
    #expect(again.askedAbout == header.askedAbout)
  }

  @Test func aTraceFromBeforeKnowsNothing() throws {
    let h = run([mail, finder])
    h.run("trace on sizes")
    h.run("trace off")
    let first = try #require(h.lastTrace?.split(separator: "\n").first)
    #expect(!first.contains("appSizes"))
    let replay = Harness(displays: [laptop], saved: whatIsKnownAfterADay(with: [mail]))
    replay.controller.restore(from: try JSONDecoder().decode(TraceHeader.self, from: Data(first.utf8)))
    #expect(replay.controller.appSizes.isEmpty)
  }

  @Test func aPauseForgetsNothing() {
    let h = run([mail, finder])
    dock(101, "left", h)
    dock(102, "right", h)
    let known = h.controller.appSizes
    #expect(!known.isEmpty)
    h.run("pause")
    h.scheduler.advance(by: 1)
    h.run("resume")
    h.scheduler.advance(by: 1)
    #expect(h.controller.appSizes == known)
  }

  // MARK: The file

  @Test func filesFromBeforeLoad() throws {
    let old = #"{"version":1,"workspaces":{},"hints":{}}"#
    #expect(try JSONDecoder().decode(PersistedState.self, from: Data(old.utf8)).appSizes == nil)
  }

  @Test func itSurvivesTheFile() throws {
    let known = try #require(whatIsKnownAfterADay(with: [mail, finder]))
    let notes = DecodingNotes()
    guard case .loaded(let read) = PersistedState.read(try JSONEncoder().encode(known), notes: notes) else {
      Issue.record("the file does not load")
      return
    }
    #expect(read.appSizes == known.appSizes)
    #expect(read == known)
    #expect(notes.notes.isEmpty)
  }

  @Test(arguments: [
    "7", #""often""#, "[1]", #"{"com.example.mail":7}"#, #"{"com.example.mail":{"width":1e12,"height":0,"macOS":26,"seen":1}}"#,
    #"{"com.example.mail":{"width":760,"height":0,"macOS":26,"seen":1},"com.example.odd":{"width":"wide"}}"#,
  ]) func whatCannotBeReadCostsNoArrangementAndIsNoLoss(value: String) {
    let file = #"{"version":1,"workspaces":{},"hints":{},"welcomed":true,"appSizes":\#(value)}"#
    let notes = DecodingNotes()
    guard case .loaded(let read) = PersistedState.read(Data(file.utf8), notes: notes) else {
      Issue.record("the file does not load")
      return
    }
    #expect(read.welcomed)
    #expect(notes.losses.isEmpty, "nothing a person made is gone: \(notes.losses)")
    #expect(!notes.tidied.isEmpty)
  }
}
