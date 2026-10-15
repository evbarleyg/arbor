import ArborCore
import ArborKit
import ArborTesting
import CoreGraphics
import Foundation
import Testing

/// A display to the right of the standard one that reaches lower, so that the standard one parks to its left.
private let side = DisplaySnapshot(
  id: DisplayID("side"), frame: CGRect(x: 1440, y: 0, width: 1280, height: 1000),
  visibleFrame: CGRect(x: 1440, y: 0, width: 1280, height: 1000), isMain: false)
@MainActor private let main = FakeWindowSystem.standardDisplay
private let large = CGSize(width: 900, height: 700)
private let tenMinutes = 600.0

/// What Arbor learns about a window's size can be unlearned (docs/features/F45-learned-sizes-expire.md).
/// `TileTests` has the parts that need no clock: evidence from the window itself, and `relayout`.
@Suite(.withTiles) @MainActor struct LearnedSizeTests {
  /// `[a | b / c]`, halves, where c refused its slot and is a tile.
  func makeHarness(
    displays: [DisplaySnapshot] = [FakeWindowSystem.standardDisplay], settings: Settings = Settings()
  ) -> (Harness, a: WindowID, b: WindowID, c: WindowID) {
    let h = Harness(displays: displays, settings: settings)
    let a = h.system.open(app: "Safari", frame: CGRect(x: 100, y: 100, width: 600, height: 400))
    let b = h.system.open(app: "Notes", frame: CGRect(x: 300, y: 200, width: 600, height: 400))
    let c = h.system.open(app: "Slack", frame: CGRect(x: 400, y: 100, width: 900, height: 700), minimumSize: large)
    h.start()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) right")
    h.run("dock \(c.rawValue) beside \(b.rawValue) bottom")
    #expect(isTile(h, c))
    #expect(!h.system.isVisible(c))
    h.system.clearFrameLog()
    return (h, a, b, c)
  }

  func isTile(_ h: Harness, _ window: WindowID) -> Bool {
    h.layout!.tiles.contains { $0.windows.contains(window) }
  }

  /// For what a tile does when it stays one although its neighbours could make room (F61).
  var noRoomMade: Settings {
    var settings = Settings()
    settings.makeRoom = false
    return settings
  }

  /// Something that lays the display out again and changes nothing: the view goes to where it is.
  func layOutAgain(_ h: Harness) { h.run("show-all") }

  /// How much of a frame shows on the displays, in square points.
  func pointsInView(_ frame: CGRect, _ h: Harness) -> CGFloat {
    h.system.displayList.map { frame.intersection($0.frame).area }.reduce(0, +)
  }

  /// What any window out of view shows: the point, or the sliver, that parking leaves on screen. Measured on a
  /// window that is parked, so that these tests do not depend on where exactly that is.
  func sliver(_ h: Harness, _ parked: WindowID) -> CGFloat {
    #expect(h.controller.parked.contains(parked))
    return pointsInView(h.frame(parked)!, h)
  }

  // MARK: Criterion 1

  @Test func aWindowThatRefusedOnceIsAWindowAgainAtTheFirstLayoutTenMinutesLater() {
    let (h, _, _, c) = makeHarness()
    // The sheet that kept it large is gone. Nothing tells Arbor.
    h.system.setMinimumSize(c, .zero)

    h.scheduler.advance(by: tenMinutes - 1)
    layOutAgain(h)
    #expect(isTile(h, c), "too early to ask")
    #expect(h.system.frameLog.isEmpty)

    h.scheduler.advance(by: 1)
    #expect(isTile(h, c), "time alone moves nothing: no timer wakes Arbor up")
    #expect(h.system.frameLog.isEmpty)
    layOutAgain(h)
    #expect(!isTile(h, c))
    #expect(h.frame(c) == h.layout?.windowFrames[c])
    expectWindowsMatchLayout(h, on: h.display)
  }

  @Test func itComesBackWithoutShowingAnywhereButInItsSlot() throws {
    let (h, a, b, c) = makeHarness()
    let sliver = sliver(h, c)
    h.system.setMinimumSize(c, .zero)
    h.scheduler.advance(by: tenMinutes)
    layOutAgain(h)
    let slot = try #require(h.layout?.windowFrames[c])
    let moves = h.system.frameLog
    #expect(moves.allSatisfy { $0.window == c }, "\(a) and \(b) stay where they are")
    #expect(moves.last?.frame == slot)
    for move in moves.dropLast() { #expect(pointsInView(move.frame, h) <= sliver, "\(move.frame)") }
    #expect(moves.count == 2, "the question, and the move into the slot")
  }

  @Test func relayoutAsksAtOnce() {
    let (h, _, _, c) = makeHarness()
    h.system.setMinimumSize(c, .zero)
    #expect(h.run("relayout").ok)
    #expect(!isTile(h, c))
    #expect(h.frame(c) == h.layout?.windowFrames[c])
  }

  @Test func anyLayoutWillDo() {
    for command in ["show-all", "resize 101 right 10", "desktop", "float 101"] {
      let (h, _, _, c) = makeHarness()
      h.system.setMinimumSize(c, .zero)
      h.scheduler.advance(by: tenMinutes)
      h.run(command)
      h.run("show-all")
      #expect(!isTile(h, c), "\(command)")
    }
  }

  // MARK: Criterion 2

  @Test func aWindowThatAlwaysRefusesIsAskedAtMostOnceInTenMinutesAndOnlyOutOfView() {
    let (h, _, _, c) = makeHarness()
    let sliver = sliver(h, c)
    var questions = 0
    // Fifty minutes, a layout every ten seconds.
    for _ in 0..<300 {
      h.scheduler.advance(by: 10)
      h.system.clearFrameLog()
      layOutAgain(h)
      if !h.system.frameLog.isEmpty { questions += 1 }
      for move in h.system.frameLog {
        #expect(move.window == c, "no other window moves")
        #expect(pointsInView(move.frame, h) <= sliver, "\(move.frame)")
      }
      #expect(h.system.frameLog.count <= 1, "one move is the whole question")
      #expect(isTile(h, c))
      #expect(h.controller.parked.contains(c))
    }
    #expect(questions == 5)
  }

  /// Parked to the left of its display, a window that stays wider than it was asked to be would reach into view.
  @Test func parkedOnTheLeftAWindowThatRefusesNeverReachesIntoView() {
    let (h, _, _, c) = makeHarness(displays: [main, side])
    #expect(h.frame(c)!.maxX <= 1, "the corner on the right belongs to the other display")
    let sliver = sliver(h, c)
    h.scheduler.advance(by: tenMinutes)
    layOutAgain(h)
    #expect(!h.system.frameLog.isEmpty)
    for move in h.system.frameLog {
      #expect(move.window == c)
      #expect(pointsInView(move.frame, h) <= sliver, "\(move.frame)")
    }
    #expect(isTile(h, c))
    #expect(pointsInView(h.frame(c)!, h) == sliver, "as much stays on screen as of any window out of view")
  }

  @Test func parkedOnTheLeftAWindowThatShrinksSomewhatIsParkedAgainAtItsNewSize() {
    // Still wider and higher than its slot of 702 × 419.
    // (Without F61, which would find room for it: see aTileThatWillGoSmallerWhenAskedAgainGetsRoom.)
    let (h, _, _, c) = makeHarness(displays: [main, side], settings: noRoomMade)
    let sliver = sliver(h, c)
    h.system.setMinimumSize(c, CGSize(width: 720, height: 500))
    h.scheduler.advance(by: tenMinutes)
    layOutAgain(h)
    for move in h.system.frameLog { #expect(pointsInView(move.frame, h) <= sliver, "\(move.frame)") }
    #expect(isTile(h, c))
    #expect(h.frame(c)?.size == CGSize(width: 720, height: 500))
    #expect(pointsInView(h.frame(c)!, h) == sliver)
  }

  @Test func parkedOnTheLeftAWindowThatRelentsComesBack() {
    let (h, _, _, c) = makeHarness(displays: [main, side])
    let sliver = sliver(h, c)
    h.system.setMinimumSize(c, .zero)
    h.scheduler.advance(by: tenMinutes)
    layOutAgain(h)
    #expect(!isTile(h, c))
    for move in h.system.frameLog.dropLast() { #expect(pointsInView(move.frame, h) <= sliver, "\(move.frame)") }
    #expect(h.frame(c) == h.layout?.windowFrames[c])
  }

  // MARK: Criterion 3

  @Test func aResizeByHandBelowWhatWasLearnedUnlearnsIt() throws {
    let (h, _, _, c) = makeHarness()
    // Framed, it has room. The user drags its edge in, further than Arbor thought it could go.
    h.run("zoom \(c.rawValue)")
    h.system.setMinimumSize(c, .zero)
    var frame = try #require(h.frame(c))
    frame.size = CGSize(width: 400, height: 300)
    h.system.userResize(c, to: frame)
    h.scheduler.runPending()
    h.run("show-all")
    #expect(!isTile(h, c), "no waiting: the window has shown what it can do")
    #expect(h.frame(c) == h.layout?.windowFrames[c])
  }

  // MARK: What stands, and for how long

  @Test func aRefusalLeavesTheSizeJustSeenOnRecord() {
    // (Without F61, which would move the gap above it by itself.)
    let (h, _, b, c) = makeHarness(settings: noRoomMade)
    // It can be smaller than Arbor thinks, though not as small as its slot (464 × 420).
    h.system.setMinimumSize(c, CGSize(width: 440, height: 500))
    h.scheduler.advance(by: tenMinutes)
    layOutAgain(h)
    #expect(isTile(h, c))
    #expect(h.frame(c)?.height == 500)
    // Given 80 points more, its slot is tall enough. That needs no further question.
    h.system.clearFrameLog()
    h.run("resize \(b.rawValue) bottom -90")
    #expect(!isTile(h, c))
    #expect(h.frame(c) == h.layout?.windowFrames[c])
  }

  @Test func theTenMinutesStartAgainWithEveryRefusal() {
    let (h, _, _, c) = makeHarness()
    h.scheduler.advance(by: tenMinutes)
    layOutAgain(h)
    #expect(h.system.frameLog.count == 1)
    h.system.setMinimumSize(c, .zero)
    h.scheduler.advance(by: tenMinutes - 1)
    layOutAgain(h)
    #expect(isTile(h, c))
    h.scheduler.advance(by: 1)
    layOutAgain(h)
    #expect(!isTile(h, c))
  }

  @Test func aWindowThatRelentsOutOfViewAndRefusesInItsSlotIsATileAgainAtOnce() {
    let (h, a, b, c) = makeHarness()
    // An app with a will of its own: small while nobody looks, large as soon as it is on screen.
    h.system.setMinimumSize(c, .zero)
    h.system.willSetFrame = { window, frame in
      guard window == c else { return }
      h.system.setMinimumSize(c, frame.minX < 1400 ? large : .zero)
    }
    h.scheduler.advance(by: tenMinutes)
    layOutAgain(h)
    #expect(isTile(h, c))
    #expect(!h.system.isVisible(c), "it is not left lying over its neighbours")
    #expect(h.frame(a) == h.layout?.windowFrames[a])
    #expect(h.frame(b) == h.layout?.windowFrames[b])
  }

  /// Terminal sizes its windows in whole character cells and takes the nearest, which can be the larger one
  /// (Controller+SizeSteps.swift). A few points over is not a refusal, in the corner as little as in the slot.
  @Test func aWindowThatComesInStepsIsNotTakenToRefuseByACell() throws {
    let (h, _, _, c) = makeHarness()
    let sliver = sliver(h, c)
    let slot = try #require(h.layout?.tiles.first { $0.windows == [c] }?.frame)
    h.system.setMinimumSize(c, .zero)
    // Twenty-five cells are five points taller than the slot, and nearer to it than twenty-four.
    h.system.setSizeStep(c, CGSize(width: 1, height: (slot.height + 5) / 25))
    h.scheduler.advance(by: tenMinutes)
    layOutAgain(h)
    #expect(!isTile(h, c))
    #expect(try #require(h.frame(c)).height <= slot.height)
    let intoTheSlot = try #require(h.system.frameLog.firstIndex { $0.frame.minX == slot.minX })
    for move in h.system.frameLog[..<intoTheSlot] { #expect(pointsInView(move.frame, h) <= sliver, "\(move.frame)") }
  }

  // MARK: Who is not asked

  @Test func aTileThatIsOnlyTooSmallToUseIsNotAsked() {
    let (h, a, _, _) = makeHarness()
    h.run("resize \(a.rawValue) right -500")  // from 702 points to 202
    #expect(isTile(h, a))
    h.system.clearFrameLog()
    h.scheduler.advance(by: tenMinutes * 3)
    h.system.clearFrameLog()
    layOutAgain(h)
    #expect(!h.system.frameLog.contains { $0.window == a })
  }

  @Test func aWindowInViewIsNotAsked() {
    let (h, _, _, c) = makeHarness()
    h.run("zoom \(c.rawValue)")
    h.system.clearFrameLog()
    h.scheduler.advance(by: tenMinutes * 2)
    h.run("zoom \(c.rawValue)")  // a layout that leaves the view where it is
    #expect(!h.system.frameLog.contains { $0.window == c }, "framed, it has all the room it wants")
  }

  // MARK: A window that is in view when a layout would make a tile of it

  /// c framed, so in view at the size of the display, with its record ten minutes old. It has the keyboard, unless `typedIn` is false (a
  /// click on the wallpaper): a record that stands makes a tile only of a window that nobody types in (F61).
  func framedWithAnOldRecord(settings: Settings = Settings(), typedIn: Bool = true) -> (Harness, c: WindowID, framed: CGRect) {
    let (h, _, _, c) = makeHarness(settings: settings)
    h.run("zoom \(c.rawValue)")
    if !typedIn { h.system.userFocusesNothing() }
    h.scheduler.advance(by: tenMinutes)
    h.system.clearFrameLog()
    return (h, c, h.frame(c)!)
  }

  @Test func withAnOldWrongRecordItGoesFromWhereItIsToItsSlotAndNeverOutOfView() throws {
    let (h, c, framed) = framedWithAnOldRecord(settings: noRoomMade)
    h.system.setMinimumSize(c, .zero)
    h.run("show-all")
    #expect(!isTile(h, c))
    let slot = try #require(h.layout?.windowFrames[c])
    #expect(h.frame(c) == slot)
    let asked = h.system.frameLog.filter { $0.window == c }.map(\.frame)
    #expect(asked == [CGRect(origin: framed.origin, size: slot.size), slot], "smaller where it was, then into its slot")
    #expect(asked.allSatisfy(framed.contains), "it covered nothing that it did not cover before")
    // What is shown (F02) ends with the window in its slot as itself, from where it was before the question.
    let motion = try #require(h.overlays.transitions.last?[c])
    #expect(motion.from == framed && motion.to == slot && motion.toLook == .picture)
  }

  /// Typed in, it is asked all the same before its neighbours pay for a record that old. It refuses, so they do.
  @Test func ifTheWindowBeingTypedInStillRefusesItIsAskedOnceAndItsNeighboursPay() throws {
    let (h, c, framed) = framedWithAnOldRecord()
    h.run("show-all")
    #expect(!isTile(h, c))
    #expect(h.frame(c)?.size == large)
    #expect(h.system.focused == c)
    let moves = h.system.frameLog.filter { $0.window == c }.map(\.frame)
    #expect(moves.count == 2, "the question, and the way to its place: \(moves)")
    #expect(moves.first.map(framed.contains) == true)
    expectWindowsMatchLayout(h)
  }

  @Test func ifItStillRefusesItIsAskedOnceAndThenGoes() {
    let (h, c, framed) = framedWithAnOldRecord(typedIn: false)
    h.run("show-all")
    #expect(isTile(h, c))
    #expect(!h.system.isVisible(c))
    let moves = h.system.frameLog.filter { $0.window == c }.map(\.frame)
    #expect(moves.count == 2, "the question, and the way out; not asked again in its corner: \(moves)")
    #expect(moves.first.map(framed.contains) == true)

    // The ten minutes start again.
    h.system.clearFrameLog()
    h.scheduler.advance(by: tenMinutes - 1)
    layOutAgain(h)
    #expect(h.system.frameLog.isEmpty)
  }

  /// It takes a size between the one it had and the slot's: that is on record, and it leaves in this layout, not the next.
  @Test func aRefusalInViewLeavesTheSizeJustSeenOnRecordAndNothingInView() {
    let (h, c, _) = framedWithAnOldRecord(settings: noRoomMade)
    let b = WindowID(c.rawValue - 1)
    h.system.setMinimumSize(c, CGSize(width: 440, height: 500))
    h.run("show-all")
    #expect(isTile(h, c))
    #expect(!h.system.isVisible(c))
    #expect(h.controller.parked.contains(c))
    #expect(h.frame(c)?.height == 500)
    // The app's answer comes back as a report. It is Arbor's own move, not somebody's hand on the window.
    h.system.clearFrameLog()
    h.scheduler.runPending()
    layOutAgain(h)
    #expect(h.system.frameLog.isEmpty)
    #expect(isTile(h, c))
    // Given 80 points more, its slot is tall enough. That needs no further question.
    h.run("resize \(b.rawValue) bottom -90")
    #expect(!isTile(h, c))
    #expect(h.frame(c) == h.layout?.windowFrames[c])
  }

  @Test func inFullScreenOrMinimizedItIsNotAsked() {
    for away in ["full screen", "minimized"] {
      let (h, c, _) = framedWithAnOldRecord()
      if away == "minimized" { h.system.setMinimized(c, true) } else { h.system.setFullScreen(c, true) }
      h.scheduler.runPending()
      h.system.clearFrameLog()
      h.run("show-all")
      #expect(!h.system.frameLog.contains { $0.window == c }, "\(away)")
    }
  }

  @Test func nobodyInViewIsAskedWhileTheMouseIsArrangingThings() throws {
    let (h, c, _) = framedWithAnOldRecord()
    let floating = h.system.open(app: "Mail", frame: CGRect(x: 500, y: 300, width: 400, height: 300))
    h.system.clearFrameLog()
    let start = try #require(h.frame(floating))
    h.system.mouseDown = true
    h.controller.dragBegan(floating, at: CGPoint(x: start.midX, y: start.minY + 10))
    h.run("show-all")
    #expect(h.system.frameLog.filter { $0.window == c }.count == 1, "the way out")
    h.system.mouseDown = false
    h.controller.dragEnded(floating, at: CGPoint(x: start.midX, y: start.minY + 10))
  }

  @Test func aRecordThatIsFreshIsBelieved() {
    let (h, _, _, c) = makeHarness(settings: noRoomMade)
    h.run("zoom \(c.rawValue)")
    // Nobody types in it: the window with the keyboard would be served at its neighbours' cost (F61).
    h.system.userFocusesNothing()
    h.scheduler.advance(by: tenMinutes - 1)
    h.system.clearFrameLog()
    h.run("show-all")
    #expect(isTile(h, c))
    #expect(h.system.frameLog.filter { $0.window == c }.count == 1, "the way out")
  }

  @Test func itIsNeverAskedToGrowWhereItIs() throws {
    // Framed, c is as wide as it will go, 1000 points, in the middle of the display. Its slot is narrower and less tall.
    let (h, _, _, c) = makeHarness(settings: noRoomMade)
    h.system.setMaximumSize(c, CGSize(width: 1000, height: 750))
    h.run("zoom \(c.rawValue)")
    let framed = try #require(h.frame(c))
    #expect(framed.size == CGSize(width: 1000, height: 750))
    h.system.setMinimumSize(c, .zero)
    h.scheduler.advance(by: tenMinutes)
    h.system.clearFrameLog()
    h.run("show-all")
    let question = try #require(h.system.frameLog.first { $0.window == c }?.frame)
    #expect(framed.contains(question))
    #expect(!isTile(h, c))
  }

  @Test func neverMeansNotInViewEither() {
    var settings = noRoomMade
    settings.tileRetryMinutes = 0
    let (h, c, _) = framedWithAnOldRecord(settings: settings, typedIn: false)
    h.system.setMinimumSize(c, .zero)
    h.run("show-all")
    #expect(isTile(h, c))
    #expect(h.system.frameLog.filter { $0.window == c }.count == 1, "the way out")
  }

  /// With F61: what it will go down to, if not far enough for the slot, is what room is made for, before it has left.
  @Test func whatItWillGoDownToIsWhatRoomIsMadeFor() throws {
    let (h, c, _) = framedWithAnOldRecord()
    h.system.setMinimumSize(c, CGSize(width: 500, height: 600))
    h.run("show-all")
    #expect(!isTile(h, c))
    #expect(try #require(h.frame(c)).height >= 600)
    #expect(h.system.frameLog.filter { $0.window == c }.allSatisfy { pointsInView($0.frame, h) == $0.frame.area })
  }

  @Test func aWindowOutsideTheViewIsNotAsked() {
    let (h, a, _, c) = makeHarness()
    h.run("zoom \(a.rawValue)")
    h.system.clearFrameLog()
    h.scheduler.advance(by: tenMinutes * 2)
    h.run("zoom \(a.rawValue)")  // a layout that leaves the view where it is
    #expect(!h.system.frameLog.contains { $0.window == c }, "no slot is waiting for it")
  }

  @Test func aMinimizedWindowIsNotAsked() {
    let (h, _, _, c) = makeHarness()
    h.system.setMinimized(c, true)
    h.system.clearFrameLog()
    h.scheduler.advance(by: tenMinutes * 2)
    layOutAgain(h)
    #expect(!h.system.frameLog.contains { $0.window == c })
  }

  @Test func nobodyIsAskedWhileTheMouseIsArrangingThings() {
    let (h, a, _, c) = makeHarness()
    h.system.setMinimumSize(c, .zero)
    h.scheduler.advance(by: tenMinutes)
    let start = h.frame(a)!
    h.system.mouseDown = true
    h.controller.dragBegan(a, at: CGPoint(x: start.midX, y: start.minY + 10))
    layOutAgain(h)
    #expect(isTile(h, c), "drop targets must not change under the pointer")
    h.system.mouseDown = false
    h.controller.dragEnded(a, at: CGPoint(x: start.midX, y: start.midY))
    #expect(!isTile(h, c), "the layout that ends the drag asks")
  }

  @Test func whilePausedNobodyIsAsked() {
    let (h, _, _, c) = makeHarness()
    h.run("pause")
    h.system.clearFrameLog()
    h.scheduler.advance(by: tenMinutes * 2)
    layOutAgain(h)
    #expect(h.system.frameLog.isEmpty)
    _ = c
  }

  // MARK: The setting

  @Test func theIntervalIsASetting() {
    var settings = Settings()
    settings.tileRetryMinutes = 1
    let (h, _, _, c) = makeHarness(settings: settings)
    h.system.setMinimumSize(c, .zero)
    h.scheduler.advance(by: 59)
    layOutAgain(h)
    #expect(isTile(h, c))
    h.scheduler.advance(by: 1)
    layOutAgain(h)
    #expect(!isTile(h, c))
  }

  @Test(arguments: [0, -5, 1e308]) func noneOrLessOrForEverMeansNever(minutes: Double) {
    var settings = Settings()
    settings.tileRetryMinutes = minutes
    let (h, _, _, c) = makeHarness(settings: settings)
    h.system.setMinimumSize(c, .zero)
    h.scheduler.advance(by: tenMinutes * 100)
    layOutAgain(h)
    #expect(isTile(h, c))
    #expect(h.system.frameLog.isEmpty)
    h.run("relayout")
    #expect(!isTile(h, c), "asking by hand still works")
  }

  // MARK: Housekeeping

  @Test func aClockSetBackDoesNotSilenceTheQuestionForEver() {
    let (h, _, _, c) = makeHarness()
    h.system.setMinimumSize(c, .zero)
    let now = h.controller.now
    h.controller.now = { now().addingTimeInterval(-86_400) }
    layOutAgain(h)
    #expect(!isTile(h, c), "a day apart is a day apart")
  }

  @Test func whatWasLearnedOutlastsAPauseWithItsAge() {
    let (h, _, _, c) = makeHarness()
    h.scheduler.advance(by: tenMinutes - 60)
    h.run("pause")
    h.run("resume")
    #expect(isTile(h, c), "it is not tried in view again after every pause")
    h.system.setMinimumSize(c, .zero)
    h.scheduler.advance(by: 60)
    layOutAgain(h)
    #expect(!isTile(h, c))
  }
}
