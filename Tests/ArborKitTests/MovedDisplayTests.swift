import ArborCore
import ArborKit
import ArborTesting
import CoreGraphics
import Foundation
import Testing

/// The laptop, and a big display on its right.
@MainActor private let laptop = FakeWindowSystem.standardDisplay
private let studio = DisplaySnapshot(
  id: DisplayID("studio"), frame: CGRect(x: 1440, y: 0, width: 2560, height: 1440),
  visibleFrame: CGRect(x: 1440, y: 25, width: 2560, height: 1415), isMain: false)

private func moved(_ display: DisplaySnapshot, to origin: CGPoint, isMain: Bool) -> DisplaySnapshot {
  var display = display
  let offset = CGPoint(x: origin.x - display.frame.minX, y: origin.y - display.frame.minY)
  display.frame = display.frame.offsetBy(dx: offset.x, dy: offset.y)
  display.visibleFrame = display.visibleFrame.offsetBy(dx: offset.x, dy: offset.y)
  display.isMain = isMain
  return display
}

private enum Side: String, CaseIterable, Sendable { case right, left, above, below }
private enum Story: String, CaseIterable, Sendable {
  /// A: the change, a pause, a resume. E: the pause comes first. F: Arbor quits first and a new one starts afterwards.
  case a, e, f
  /// F on a file that does not say where the displays were, as 6dd81146 and `main` wrote them.
  case olderFile
}
private let everything = Side.allCases.flatMap { side in
  [true, false].flatMap { closing in Story.allCases.map { (side, closing, $0) } }
}
private let pairs = Side.allCases.flatMap { a in Side.allCases.map { (a, $0) } }

/// The frames a workspace remembers are global, and a display's place among the displays changes: with the lid, in
/// clamshell, in System Settings. They go with it (bug bash of 2026-10-14; a tester's day found the first of them).
@Suite @MainActor struct MovedDisplayTests {
  /// What macOS does when another display becomes the main one: every window has new coordinates, and no app says so.
  func shiftEverything(_ h: Harness, by offset: CGPoint) {
    for window in h.system.allWindows() { h.system.moveSilently(window.id, to: window.frame.offsetBy(dx: offset.x, dy: offset.y)) }
  }

  func closeTheLid(_ h: Harness) {
    shiftEverything(h, by: CGPoint(x: -1440, y: 0))
    h.system.setDisplays([moved(studio, to: .zero, isMain: true)])
  }

  func openTheLid(_ h: Harness) {
    shiftEverything(h, by: CGPoint(x: 1440, y: 0))
    h.system.setDisplays([laptop, studio])
  }

  func onStudio(_ h: Harness) -> Workspace? { h.controller.workspaces[studio.id] }

  /// Where the lid meets "chosen on a display of another shape". A window somebody left hanging over the far edge keeps
  /// its overhang when its display only moves: a display that moved has kept its shape. Taken for a place chosen on another shape, it
  /// would be fitted onto the Desktop (a reviewer's test; neither order of the two features' lines in `updateDisplays` passes it as they were).
  @Test func aWindowLeftHangingOverTheEdgeByHandStillHangsThereWhenItsDisplayOnlyMoves() {
    let h = Harness(displays: [laptop, studio])
    let s = h.system.open(app: "Safari", frame: CGRect(x: 1700, y: 200, width: 900, height: 600))
    let n = h.system.open(app: "Notes", frame: CGRect(x: 2800, y: 500, width: 700, height: 500))
    h.start()
    h.system.cursor = CGPoint(x: 2000, y: 400)
    #expect(h.run("dock \(s.rawValue) left").ok)
    h.system.userMove(n, to: CGRect(x: 3940, y: 500, width: 700, height: 500))  // 60 points of it show
    h.scheduler.advance(by: 3)

    closeTheLid(h)
    h.system.report(n, userInitiated: false)
    h.scheduler.advance(by: 3)
    h.system.cursor = CGPoint(x: 560, y: 400)
    #expect(h.frame(n)?.minX == 2500, "macOS took it along")
    #expect(h.run("zoom \(s.rawValue)").ok)
    for command in ["back", "home", "relayout"] {
      h.run(command)
      h.scheduler.advance(by: 3)
      #expect(h.frame(n)?.minX == 2500, "still a strip, at the shifted place, after `\(command)`: \(String(describing: h.frame(n)))")
    }
  }

  /// Default settings, nothing docked, a window in full view. Its old frame still touched the display in its new place by
  /// 30 points, which passed for a place somebody had chosen, and Arbor pushed it there: 5 % of it showed, and
  /// Show Everything, Go to… and ⌘Tab did not fetch it.
  @Test func whenTheLidClosesAFloatingWindowStaysWhereItIsOnItsDisplay() {
    let h = Harness(displays: [laptop, studio])
    let spot = CGRect(x: 2530, y: 500, width: 600, height: 400)
    let n = h.system.open(app: "Notes", frame: spot)
    h.start()
    #expect(onStudio(h)?.floating[n] == spot)
    h.system.clearFrameLog()

    closeTheLid(h)
    h.scheduler.advance(by: 3)
    #expect(h.frame(n) == spot.offsetBy(dx: -1440, dy: 0))
    #expect(onStudio(h)?.floating[n] == spot.offsetBy(dx: -1440, dy: 0))
    #expect(h.system.frameLog.isEmpty, "macOS took it along: \(h.system.frameLog)")

    openTheLid(h)
    h.scheduler.advance(by: 3)
    #expect(h.frame(n) == spot)
    #expect(onStudio(h)?.floating[n] == spot)
    #expect(h.system.frameLog.isEmpty, "\(h.system.frameLog)")
  }

  /// This one did not move at once: it jumped 1440 points at the next change of displays.
  @Test func aFrameLeftBehindDoesNotComeBackLater() {
    let h = Harness(displays: [laptop, studio])
    let spot = CGRect(x: 2000, y: 500, width: 600, height: 400)
    let n = h.system.open(app: "Notes", frame: spot)
    h.start()
    closeTheLid(h)
    let third = DisplaySnapshot(
      id: DisplayID("third"), frame: CGRect(x: -1920, y: 0, width: 1920, height: 1080),
      visibleFrame: CGRect(x: -1920, y: 0, width: 1920, height: 1080), isMain: false)
    h.system.setDisplays([moved(studio, to: .zero, isMain: true), third])
    h.scheduler.advance(by: 3)
    #expect(h.frame(n) == spot.offsetBy(dx: -1440, dy: 0))
  }

  /// The view goes away from the Desktop and comes back, which is when floating windows that make way are sent to their frames. One that
  /// does not make way stays where the lid left it.
  @Test(arguments: [false, true]) func afterTheLidClosedFloatingWindowsAreOnTheDesktopWhereTheyWere(makingWay: Bool) {
    let h = Harness(displays: [laptop, studio], settings: makingWay ? .makingWay : Settings())
    let n = h.system.open(app: "Notes", frame: CGRect(x: 2900, y: 500, width: 600, height: 400))
    let a = h.system.open(app: "Safari", frame: CGRect(x: 1600, y: 100, width: 500, height: 400))
    h.start()
    h.system.cursor = CGPoint(x: 2000, y: 400)
    h.run("dock \(a.rawValue) left")
    let spot = h.frame(n)!
    closeTheLid(h)
    h.system.cursor = CGPoint(x: 600, y: 400)
    h.run("zoom \(a.rawValue)")
    #expect(h.system.isVisible(n) == !makingWay)
    h.run("show-all")
    #expect(h.frame(n) == spot.offsetBy(dx: -1440, dy: 0))
  }

  /// A docked window that floats again lands where it would have without the lid, seen from its display.
  @Test func aDockedWindowFloatsAgainWhereItWouldHaveWithoutTheLid() {
    func story(lid: Bool) -> CGRect {
      let h = Harness(displays: [laptop, studio])
      let n = h.system.open(app: "Notes", frame: CGRect(x: 2530, y: 500, width: 600, height: 400))
      h.start()
      h.system.cursor = CGPoint(x: 2000, y: 400)
      h.run("dock \(n.rawValue) left")
      if lid {
        closeTheLid(h)
        h.system.cursor = CGPoint(x: 560, y: 400)
      }
      h.run("float \(n.rawValue)")
      return h.frame(n)!
    }
    #expect(story(lid: true) == story(lid: false).offsetBy(dx: -1440, dy: 0))
  }

  @Test func aDisplayMovedInSystemSettingsTakesItsFramesAlong() {
    let h = Harness(displays: [laptop, studio])
    let spot = CGRect(x: 2000, y: 1000, width: 600, height: 400)
    let n = h.system.open(app: "Notes", frame: spot)
    h.start()
    h.system.clearFrameLog()
    h.system.moveSilently(n, to: spot.offsetBy(dx: 0, dy: -1000))
    h.system.setDisplays([laptop, moved(studio, to: CGPoint(x: 1440, y: -1000), isMain: false)])
    h.scheduler.advance(by: 3)
    #expect(h.frame(n) == spot.offsetBy(dx: 0, dy: -1000))
    #expect(h.system.frameLog.isEmpty, "\(h.system.frameLog)")
  }

  // MARK: A display that was away and comes back somewhere else

  /// A tester's day, in their own words but for the names: in clamshell at the desk, the laptop alone, back at the desk
  /// with the lid open. A window left hanging over the bottom edge came back with a strip of 32 points showing.
  @Test(arguments: [false, true]) func backAtTheDeskWithTheLidOpenAWindowIsWhereItWasLeftOnTheBigDisplay(makingWay: Bool) {
    let desk = DisplaySnapshot(
      id: DisplayID("desk"), frame: CGRect(x: 0, y: 0, width: 2560, height: 1440),
      visibleFrame: CGRect(x: 0, y: 25, width: 2560, height: 1415), isMain: true)
    let builtin = DisplaySnapshot(
      id: DisplayID("builtin"), frame: CGRect(x: 0, y: 0, width: 1728, height: 1117),
      visibleFrame: CGRect(x: 0, y: 33, width: 1728, height: 1084), isMain: true)
    let h = Harness(displays: [desk], settings: makingWay ? .makingWay : Settings())
    h.start()
    let n = h.system.open(app: "Notes", frame: CGRect(x: 300, y: 400, width: 700, height: 500))
    h.system.drag(n, through: [CGPoint(x: 650, y: 410), CGPoint(x: 1400, y: 800), CGPoint(x: 2077, y: 1095)])
    h.scheduler.runPending()
    let left = h.frame(n)!
    #expect(left.maxY > desk.frame.maxY, "it hangs over the bottom edge")

    // macOS moves it, and nobody hears yet.
    let listener = h.system.events
    h.system.events = nil
    h.system.userMove(n, to: CGRect(x: 1028, y: 617, width: 700, height: 500))
    h.system.events = listener
    let mark = h.system.frameLog.count
    h.system.setDisplays([builtin])
    h.controller.windowChanged(
      h.system.windows[n]!.snapshot, userInitiated: !h.system.frameLog[mark...].contains { $0.window == n })
    h.scheduler.runPending()

    h.system.setDisplays([builtin, moved(desk, to: CGPoint(x: 1728, y: -323), isMain: false)])
    h.scheduler.runPending()
    // Where it was left on the display, not in the world. But wholly in view: that it hung over the edge by its user's own hand is
    // known only until the displays change (`noteWhereItsUserLeftIt`), and where in doubt a window is brought in. The fault
    // this test is about was a strip of 32 points.
    // As Arbor ships it is brought in only if less than half of it would show (Q20), and seven tenths of this one do: exactly
    // where it was left on the display.
    let back = moved(desk, to: CGPoint(x: 1728, y: -323), isMain: false)
    let there = left.offsetBy(dx: 1728, dy: -323)
    #expect(h.frame(n) == (makingWay ? there.fitted(into: back.visibleFrame) : there))
    #expect(there.fractionInside(back.frame) >= 0.5)
    #expect(h.frame(n)?.minX == left.minX + 1728)
  }

  /// Three windows without any overhang came back shoved against the display's left and bottom edges.
  @Test func windowsInFullViewComeBackWhereTheyWereOnTheDisplayNotInTheWorld() {
    let desk = moved(studio, to: .zero, isMain: true)
    let h = Harness(displays: [desk])
    let spots = [
      CGRect(x: 43, y: 333, width: 500, height: 300), CGRect(x: 300, y: 1050, width: 500, height: 300),
      CGRect(x: 2000, y: 1100, width: 500, height: 300),
    ]
    let windows = spots.map { h.system.open(app: "Notes", frame: $0) }
    h.start()
    h.system.setDisplays([laptop])
    h.scheduler.advance(by: 3)
    h.system.setDisplays([laptop, moved(studio, to: CGPoint(x: 1440, y: -323), isMain: false)])
    h.scheduler.advance(by: 3)
    for (window, spot) in zip(windows, spots) { #expect(h.frame(window) == spot.offsetBy(dx: 1440, dy: -323)) }
  }

  // MARK: The runs before the release, by their letters: 700 wide at 2530,500, and `home` afterwards, which is what sends it

  static let spot = CGRect(x: 2530, y: 500, width: 700, height: 400)
  static let inClamshell = spot.offsetBy(dx: -1440, dy: 0)

  func atTheDesk() -> (Harness, WindowID) {
    let h = Harness(displays: [laptop, studio])
    let n = h.system.open(app: "Notes", frame: Self.spot)
    h.start()
    return (h, n)
  }

  /// A. The lid closes; a pause; a resume; `home`.
  @Test func aTheLidThenAPauseAndAResumeAndHome() {
    let (h, n) = atTheDesk()
    closeTheLid(h)
    #expect(h.frame(n) == Self.inClamshell)
    for command in ["pause", "resume", "home"] {
      h.run(command)
      h.scheduler.advance(by: 1)
      #expect(h.frame(n) == Self.inClamshell, "\(command)")
    }
  }

  /// B and C lasted before as well: a place the person gives it afterwards is the place.
  @Test func bAndCAPlaceGivenAfterwardsStays() {
    let (h, n) = atTheDesk()
    closeTheLid(h)
    let chosen = CGRect(x: 1000, y: 300, width: 700, height: 400)
    h.system.userMove(n, to: chosen)
    h.run("home")
    #expect(h.frame(n) == chosen)
  }

  /// D. Quitting leaves it where it is: in view.
  @Test func dQuittingAfterTheLidLeavesItInView() {
    let (h, n) = atTheDesk()
    closeTheLid(h)
    h.controller.shutdown()
    #expect(h.frame(n) == Self.inClamshell)
  }

  /// E. A pause BEFORE the lid closes only put it off until the next `home`.
  @Test func eAPauseBeforeTheLidThenAResumeAndHome() {
    let (h, n) = atTheDesk()
    h.run("pause")
    closeTheLid(h)
    #expect(h.frame(n) == Self.inClamshell)
    for command in ["resume", "home"] {
      h.run(command)
      h.scheduler.advance(by: 1)
      #expect(h.frame(n) == Self.inClamshell, "\(command)")
    }
    #expect(onStudio(h)?.floating[n] == Self.inClamshell)
  }

  /// F. Arbor quits; the lid closes; a new Arbor starts on what the old one saved; `home`. state.json carried the frame.
  @Test func fQuitBeforeTheLidAndANewArborOnWhatWasSaved() throws {
    let (first, n) = atTheDesk()
    first.controller.shutdown()
    let data = try JSONEncoder().encode(first.store.saved!)
    let h = Harness(
      displays: [moved(studio, to: .zero, isMain: true)], saved: try JSONDecoder().decode(PersistedState.self, from: data))
    let again = h.system.open(app: "Notes", frame: Self.inClamshell)
    #expect(again == n)
    h.start()
    h.run("home")
    h.scheduler.advance(by: 1)
    #expect(h.frame(n) == Self.inClamshell)
    #expect(onStudio(h)?.floating[n] == Self.inClamshell)
  }

  /// F the other way: quit on the train with the big display remembered, launch at the desk with the lid open.
  @Test func aDisplayMissingWhenArborQuitAndLaunchedComesBackElsewhereLater() throws {
    let desk = moved(studio, to: .zero, isMain: true)
    let first = Harness(displays: [desk])
    let n = first.system.open(app: "Notes", frame: Self.inClamshell)
    first.start()
    first.controller.shutdown()
    // Launched with the laptop alone: the big display is missing, and its arrangement waits.
    let h = Harness(displays: [laptop], saved: first.store.saved)
    #expect(h.system.open(app: "Notes", frame: CGRect(x: 300, y: 300, width: 700, height: 400)) == n)
    h.start()
    #expect(h.controller.dormant[studio.id]?.origin == .zero)
    h.system.setDisplays([laptop, studio])
    h.scheduler.advance(by: 1)
    #expect(h.frame(n) == Self.spot)
  }

  /// A tester's day: the laptop's scaling goes to More Space with the big display attached, whose corner goes from
  /// 1728 to 2056. A window 72 points in ended at the display's left edge, and Float All sent it across both displays.
  @Test func whenTheLaptopsScalingChangesTheBigDisplaysWindowsKeepTheirPlacesOnIt() {
    let small = DisplaySnapshot(
      id: DisplayID("builtin"), frame: CGRect(x: 0, y: 0, width: 1728, height: 1117),
      visibleFrame: CGRect(x: 0, y: 33, width: 1728, height: 1084), isMain: true)
    var large = small
    large.frame.size = CGSize(width: 2056, height: 1329)
    large.visibleFrame.size = CGSize(width: 2056, height: 1296)
    let h = Harness(displays: [small, moved(studio, to: CGPoint(x: 1728, y: 0), isMain: false)])
    let spot = CGRect(x: 1800, y: 100, width: 600, height: 400)
    let n = h.system.open(app: "Notes", frame: spot)
    h.start()
    h.system.moveSilently(n, to: spot.offsetBy(dx: 328, dy: 0))
    h.system.setDisplays([large, moved(studio, to: CGPoint(x: 2056, y: 0), isMain: false)])
    h.scheduler.advance(by: 1)
    #expect(h.frame(n) == spot.offsetBy(dx: 328, dy: 0))
    h.run("float-all")
    h.run("home")
    #expect(h.frame(n) == spot.offsetBy(dx: 328, dy: 0))
  }

  // MARK: Every side, both ways, every story

  private static func corner(_ side: Side) -> CGPoint {
    switch side {
    case .right: return CGPoint(x: 1440, y: 0)
    case .left: return CGPoint(x: -2560, y: 0)
    case .above: return CGPoint(x: 0, y: -1440)
    case .below: return CGPoint(x: 0, y: 900)
    }
  }

  /// Places all over the big display, seen from its corner, all in full view.
  static let places: [CGRect] = [40, 420, 800, 1090, 1500, 1900].flatMap { x in
    [60, 500, 1000].map { y in CGRect(x: x, y: y, width: 600, height: 400) }
  }

  /// As a Mac does it: the windows have their new coordinates, Arbor hears of the displays, and only then may apps
  /// say that their windows moved. What Arbor placed itself meanwhile is its own doing.
  func change(_ h: Harness, to displays: [DisplaySnapshot], shifting offset: CGPoint) {
    shiftEverything(h, by: offset)
    let mark = h.system.frameLog.count
    h.system.setDisplays(displays)
    let placed = Set(h.system.frameLog[mark...].map(\.window))
    for window in h.system.allWindows() { h.system.report(window.id, userInitiated: !placed.contains(window.id)) }
    h.scheduler.advance(by: 5)
  }

  @Test(arguments: everything)
  private func floatingWindowsKeepTheirPlacesOnTheBigDisplay(side: Side, closing: Bool, story: Story) throws {
    let open = [laptop, moved(studio, to: Self.corner(side), isMain: false)]
    let shut = [moved(studio, to: .zero, isMain: true)]
    let (from, to) = closing ? (open, shut) : (shut, open)
    let (start, end) = closing ? (Self.corner(side), .zero) : (.zero, Self.corner(side))
    let offset = CGPoint(x: end.x - start.x, y: end.y - start.y)
    var h = Harness(displays: from)
    let windows = Self.places.map { h.system.open(app: "Notes", frame: $0.offsetBy(dx: start.x, dy: start.y)) }
    h.start()
    h.scheduler.advance(by: 5)

    switch story {
    case .a:
      change(h, to: to, shifting: offset)
      for command in ["pause", "resume"] {
        h.run(command)
        h.scheduler.advance(by: 3)
      }
    case .e:
      h.run("pause")
      change(h, to: to, shifting: offset)
      h.run("resume")
      h.scheduler.advance(by: 3)
    case .f, .olderFile:
      h.controller.shutdown()
      var object = try #require(
        JSONSerialization.jsonObject(with: try JSONEncoder().encode(h.store.saved!)) as? [String: Any])
      if story == .olderFile { #expect(object.removeValue(forKey: "origins") != nil) }
      let saved = try JSONDecoder().decode(PersistedState.self, from: JSONSerialization.data(withJSONObject: object))
      h = Harness(displays: to, saved: saved)
      let again = Self.places.map { h.system.open(app: "Notes", frame: $0.offsetBy(dx: end.x, dy: end.y)) }
      #expect(again == windows)
      h.start()
      h.scheduler.advance(by: 5)
    }
    for command in ["home", "relayout", "desktop", "home"] {
      h.run(command)
      h.scheduler.advance(by: 3)
    }
    for (window, place) in zip(windows, Self.places) {
      #expect(h.frame(window) == place.offsetBy(dx: end.x, dy: end.y), "the one at \(Int(place.minX)),\(Int(place.minY))")
    }
  }

  // MARK: Apps that speak before even macOS's own list of displays has changed

  /// The lab's `windows-first`: each app says where its window is now while the list of displays that Arbor can ask for is
  /// still the old one, so that no guard has anything to see (`knowsTheDisplays`). The report passes for the person's own
  /// move, the frame is in the new coordinates already, and it was moved AGAIN with the corner. Unlikely on a Mac, not
  /// excluded, not measured. The window is the witness.
  func changeWithAppsSpeakingBeforeAnything(
    _ h: Harness, to displays: [DisplaySnapshot], shifting offset: CGPoint, who: (Int) -> Bool = { _ in true }
  ) {
    for (index, window) in h.system.allWindows().enumerated() {
      let there = window.frame.offsetBy(dx: offset.x, dy: offset.y)
      if who(index) { h.system.userMove(window.id, to: there) } else { h.system.moveSilently(window.id, to: there) }
    }
    h.system.setDisplays(displays)
    h.scheduler.advance(by: 5)
    for command in ["home", "relayout", "desktop", "home"] {
      h.run(command)
      h.scheduler.advance(by: 3)
    }
  }

  static let desk = DisplaySnapshot(
    id: DisplayID("desk"), frame: CGRect(x: 0, y: 0, width: 2560, height: 1440),
    visibleFrame: CGRect(x: 0, y: 25, width: 2560, height: 1415), isMain: true)
  static let builtin = DisplaySnapshot(
    id: DisplayID("builtin"), frame: CGRect(x: 0, y: 0, width: 1728, height: 1117),
    visibleFrame: CGRect(x: 0, y: 33, width: 1728, height: 1084), isMain: true)

  /// A tester's day: the lid OPENS. 590,429 goes to 2318,106 with its display, and Arbor moved it a
  /// second time, to 4046,−217: a fifth of it in view, and ⌃⌥0, Go to…, ⌃⌥Z and ⌘Tab did not fetch it.
  @Test func theLidOpensAndTheAppSpeaksFirst() {
    let h = Harness(displays: [Self.desk])
    let terminal = h.system.open(app: "Terminal", frame: CGRect(x: 590, y: 429, width: 1164, height: 262))
    h.start()
    h.scheduler.advance(by: 5)
    changeWithAppsSpeakingBeforeAnything(
      h, to: [Self.builtin, moved(Self.desk, to: CGPoint(x: 1728, y: -323), isMain: false)],
      shifting: CGPoint(x: 1728, y: -323))
    #expect(h.frame(terminal) == CGRect(x: 2318, y: 106, width: 1164, height: 262))
  }

  /// A tester's day, the lid CLOSES: Notes at 3300,400 belongs at 1572,723 and ended at −156,1046, half of it in view.
  @Test func theLidClosesAndTheAppSpeaksFirstOfAPlaceThatWasOnTheBigDisplay() {
    let h = Harness(displays: [Self.builtin, moved(Self.desk, to: CGPoint(x: 1728, y: -323), isMain: false)])
    let notes = h.system.open(app: "Notes", frame: CGRect(x: 3300, y: 400, width: 800, height: 600))
    h.start()
    h.scheduler.advance(by: 5)
    changeWithAppsSpeakingBeforeAnything(h, to: [Self.desk], shifting: CGPoint(x: -1728, y: 323))
    #expect(h.frame(notes) == CGRect(x: 1572, y: 723, width: 800, height: 600))
  }

  /// The first day backwards: the lid CLOSES, and the window's new place was on the LAPTOP as the displays still were.
  @Test func theLidClosesAndTheAppSpeaksFirst() {
    let h = Harness(displays: [Self.builtin, moved(Self.desk, to: CGPoint(x: 1728, y: -323), isMain: false)])
    let terminal = h.system.open(app: "Terminal", frame: CGRect(x: 2318, y: 106, width: 1164, height: 262))
    h.start()
    h.scheduler.advance(by: 5)
    changeWithAppsSpeakingBeforeAnything(h, to: [Self.desk], shifting: CGPoint(x: -1728, y: 323))
    // Not to the point, and known: the early report also says which DISPLAY the window is on, judged by the displays as
    // they still were, and 590,429 was on the laptop then. It leaves with the laptop's windows, which keep their places
    // below the menu bar, and the two bars differ by 8 points. In full view, at the same x.
    let frame = h.frame(terminal)!
    #expect(frame.size == CGSize(width: 1164, height: 262) && frame.minX == 590 && abs(frame.minY - 429) <= 8, "\(frame)")
    #expect(Self.desk.visibleFrame.contains(frame))
  }

  /// The smallest case: the same displays stay, and one corner moves by 300 points. All apps speak, or every other one.
  @Test(arguments: [true, false]) func aCornerMovesByALittleAndAppsSpeakFirst(all: Bool) {
    let h = Harness(displays: [laptop, studio])
    let windows = Self.places.map { h.system.open(app: "Notes", frame: $0.offsetBy(dx: 1440, dy: 0)) }
    h.start()
    h.scheduler.advance(by: 5)
    changeWithAppsSpeakingBeforeAnything(
      h, to: [laptop, moved(studio, to: CGPoint(x: 1440, y: 300), isMain: false)], shifting: CGPoint(x: 0, y: 300),
      who: { all || $0.isMultiple(of: 2) })
    for (window, place) in zip(windows, Self.places) {
      #expect(h.frame(window) == place.offsetBy(dx: 1440, dy: 300), "the one at \(Int(place.minX)),\(Int(place.minY))")
    }
  }

  @Test(arguments: Side.allCases, [true, false])
  private func floatingWindowsKeepTheirPlacesWhicheverSpeaksFirst(side: Side, closing: Bool) {
    let open = [laptop, moved(studio, to: Self.corner(side), isMain: false)]
    let shut = [moved(studio, to: .zero, isMain: true)]
    let (start, end) = closing ? (Self.corner(side), .zero) : (.zero, Self.corner(side))
    let h = Harness(displays: closing ? open : shut)
    let windows = Self.places.map { h.system.open(app: "Notes", frame: $0.offsetBy(dx: start.x, dy: start.y)) }
    h.start()
    h.scheduler.advance(by: 5)
    changeWithAppsSpeakingBeforeAnything(
      h, to: closing ? shut : open, shifting: CGPoint(x: end.x - start.x, y: end.y - start.y))
    for (window, place) in zip(windows, Self.places) {
      #expect(h.frame(window) == place.offsetBy(dx: end.x, dy: end.y), "the one at \(Int(place.minX)),\(Int(place.minY))")
    }
  }

  // MARK: The table drawn up before the release

  /// {the lid opens, the lid closes, a display dragged in System Settings} × {the app speaks first, late, never}, each ending
  /// in `home`. `never`: macOS has moved the window and its app says nothing at all.
  @Test(arguments: ["opens", "closes", "settings"], ["first", "late", "never"])
  func theTable(play: String, order: String) {
    let beside = moved(studio, to: CGPoint(x: 1440, y: 0), isMain: false)
    let alone = moved(studio, to: .zero, isMain: true)
    let dragged = moved(studio, to: CGPoint(x: 1440, y: -700), isMain: false)
    let (from, to): ([DisplaySnapshot], [DisplaySnapshot]) =
      play == "opens" ? ([alone], [laptop, beside]) : play == "closes" ? ([laptop, beside], [alone]) : ([laptop, beside], [laptop, dragged])
    let (start, end) = (from.last!.frame.origin, to.last!.frame.origin)
    let offset = CGPoint(x: end.x - start.x, y: end.y - start.y)
    let h = Harness(displays: from)
    // Far enough in that its new place is on the big display by the old frames as well.
    let place = CGRect(x: 1600, y: 800, width: 600, height: 400)
    let n = h.system.open(app: "Notes", frame: place.offsetBy(dx: start.x, dy: start.y))
    h.start()
    h.scheduler.advance(by: 5)
    let there = place.offsetBy(dx: end.x, dy: end.y)
    switch order {
    case "first":
      h.system.userMove(n, to: there)
      h.system.setDisplays(to)
    case "late":
      h.system.moveSilently(n, to: there)
      let mark = h.system.frameLog.count
      h.system.setDisplays(to)
      h.system.report(n, userInitiated: !h.system.frameLog[mark...].contains { $0.window == n })
    default:
      h.system.moveSilently(n, to: there)
      h.system.setDisplays(to)
    }
    _ = offset
    h.scheduler.advance(by: 5)
    for command in ["relayout", "desktop", "pause", "resume", "home"] {
      h.run(command)
      h.scheduler.advance(by: 3)
      #expect(h.frame(n) == there, "after \(command)")
    }
    #expect(onStudio(h)?.floating[n] == there)
  }

  /// A play in three acts: the app speaks, time passes, and only then does Arbor hear of the displays. With two seconds' grace the
  /// cure held to 1.9 s and failed from 2.1 s on; a Mac can take longer (1.5 s after the LAST of several notices).
  @Test(arguments: [0, 1.9, 2.1, 5, 10, 29]) func theAppSpeaksAndTimePassesBeforeArborHears(seconds: Double) {
    let h = Harness(displays: [Self.desk])
    let terminal = h.system.open(app: "Terminal", frame: CGRect(x: 590, y: 429, width: 1164, height: 262))
    h.start()
    h.scheduler.advance(by: 5)
    let there = CGRect(x: 2318, y: 106, width: 1164, height: 262)
    h.system.userMove(terminal, to: there)
    h.scheduler.advance(by: seconds)
    h.system.setDisplays([Self.builtin, moved(Self.desk, to: CGPoint(x: 1728, y: -323), isMain: false)])
    h.scheduler.advance(by: 5)
    h.run("home")
    #expect(h.frame(terminal) == there)
  }

  /// However lately somebody dragged it: macOS then takes it along in silence, and it goes with the corner.
  @Test(arguments: [0, 1, 3, 20]) func aDragAndThenTheCornerMoves(seconds: Double) {
    let h = Harness(displays: [laptop, studio])
    let n = h.system.open(app: "Notes", frame: CGRect(x: 2000, y: 500, width: 600, height: 400))
    h.start()
    let chosen = CGRect(x: 2200, y: 300, width: 600, height: 400)
    h.system.userMove(n, to: chosen)
    h.scheduler.advance(by: seconds)
    change(h, to: [laptop, moved(studio, to: CGPoint(x: 1440, y: 300), isMain: false)], shifting: CGPoint(x: 0, y: 300))
    h.run("home")
    #expect(h.frame(n) == chosen.offsetBy(dx: 0, dy: 300))
  }

  /// A drag just before the lid is not what the app said of the lid: macOS then takes the window along in silence, the
  /// place no longer says where the window is, and it goes with the corner.
  @Test func aPlaceGivenByHandJustBeforeTheLidStillGoesWithTheCorner() {
    let h = Harness(displays: [laptop, studio])
    let n = h.system.open(app: "Notes", frame: CGRect(x: 2000, y: 500, width: 600, height: 400))
    h.start()
    let chosen = CGRect(x: 2530, y: 700, width: 600, height: 400)
    h.system.userMove(n, to: chosen)
    closeTheLid(h)
    h.scheduler.advance(by: 5)
    h.run("home")
    #expect(h.frame(n) == chosen.offsetBy(dx: -1440, dy: 0))
  }

  /// An app that hangs: what is read of its window is what was read before, which equals what is remembered. It has not
  /// spoken, so the place goes with the corner.
  @Test func aPlaceThatOnlySeemsToAgreeBecauseNothingNewCouldBeReadGoesWithTheCorner() {
    let h = Harness(displays: [laptop, studio])
    let spot = CGRect(x: 2530, y: 500, width: 600, height: 400)
    let n = h.system.open(app: "Notes", frame: spot)
    h.start()
    h.scheduler.advance(by: 5)
    // The fake has the window where it was: the picture a hung app gives.
    h.system.setDisplays([moved(studio, to: .zero, isMain: true)])
    #expect(onStudio(h)?.floating[n] == spot.offsetBy(dx: -1440, dy: 0))
  }

  // MARK: Apps that speak before Arbor has heard of the displays

  /// macOS has the new displays and has shifted the windows; their apps say so; and only then, a second and a half later
  /// (`DisplayChange`), does Arbor hear of the displays. While the same displays stayed, nothing held those reports back:
  /// each passed for the person's own move, so the frame was in the new coordinates already and moved AGAIN with the
  /// corner (450, 1890, 3330: the chaos lab, 2026-10-14), and which display the window was on was judged by the old frames.
  func changeWithAppsSpeakingFirst(_ h: Harness, to displays: [DisplaySnapshot], shifting offset: CGPoint, who: (Int) -> Bool = { _ in true }) {
    h.system.displayList = displays
    for (index, window) in h.system.allWindows().enumerated() {
      let there = window.frame.offsetBy(dx: offset.x, dy: offset.y)
      if who(index) { h.system.userMove(window.id, to: there) } else { h.system.moveSilently(window.id, to: there) }
    }
    h.scheduler.advance(by: 1.5)
    h.system.setDisplays(displays)
    h.scheduler.advance(by: 5)
    for command in ["home", "relayout", "desktop", "home"] {
      h.run(command)
      h.scheduler.advance(by: 3)
    }
  }

  @Test(arguments: Side.allCases, [true, false])
  private func floatingWindowsKeepTheirPlacesAlsoIfTheirAppsSpeakFirst(side: Side, closing: Bool) {
    let open = [laptop, moved(studio, to: Self.corner(side), isMain: false)]
    let shut = [moved(studio, to: .zero, isMain: true)]
    let (start, end) = closing ? (Self.corner(side), .zero) : (.zero, Self.corner(side))
    let h = Harness(displays: closing ? open : shut)
    let windows = Self.places.map { h.system.open(app: "Notes", frame: $0.offsetBy(dx: start.x, dy: start.y)) }
    h.start()
    h.scheduler.advance(by: 5)
    changeWithAppsSpeakingFirst(h, to: closing ? shut : open, shifting: CGPoint(x: end.x - start.x, y: end.y - start.y))
    for (window, place) in zip(windows, Self.places) {
      #expect(h.frame(window) == place.offsetBy(dx: end.x, dy: end.y), "the one at \(Int(place.minX)),\(Int(place.minY))")
      #expect(onStudio(h)?.floating[window] == place.offsetBy(dx: end.x, dy: end.y))
    }
  }

  /// The same displays stay and only a corner moves. All apps speak, or every other one.
  @Test(arguments: [true, false]) func aDisplayMovedInSystemSettingsWithAppsThatSpeakFirst(all: Bool) {
    let h = Harness(displays: [laptop, studio])
    let windows = Self.places.map { h.system.open(app: "Notes", frame: $0.offsetBy(dx: 1440, dy: 0)) }
    h.start()
    h.scheduler.advance(by: 5)
    changeWithAppsSpeakingFirst(
      h, to: [laptop, moved(studio, to: CGPoint(x: 1440, y: -1000), isMain: false)], shifting: CGPoint(x: 0, y: -1000),
      who: { all || $0.isMultiple(of: 2) })
    for (window, place) in zip(windows, Self.places) {
      #expect(h.frame(window) == place.offsetBy(dx: 1440, dy: -1000), "the one at \(Int(place.minX)),\(Int(place.minY))")
      #expect(onStudio(h)?.isFloating(window) == true)
    }
  }

  /// Once Arbor has heard, a move is the person's own again.
  @Test func afterTheReportAMoveIsThePersonsOwnAgain() {
    let h = Harness(displays: [laptop, studio])
    let n = h.system.open(app: "Notes", frame: CGRect(x: 2000, y: 500, width: 600, height: 400))
    h.start()
    changeWithAppsSpeakingFirst(
      h, to: [laptop, moved(studio, to: CGPoint(x: 1440, y: -1000), isMain: false)], shifting: CGPoint(x: 0, y: -1000))
    let chosen = CGRect(x: 1700, y: -700, width: 600, height: 400)
    h.system.userMove(n, to: chosen)
    h.run("home")
    #expect(h.frame(n) == chosen)
    #expect(onStudio(h)?.floating[n] == chosen)
  }

  /// Unplugged on one side of the laptop, plugged in again on another (or the same).
  @Test(arguments: pairs) private func aDisplayThatReturnsElsewhereHasItsWindowsWhereTheyWereOnIt(left: Side, returns: Side) {
    let h = Harness(displays: [laptop, moved(studio, to: Self.corner(left), isMain: false)])
    let windows = Self.places.map { h.system.open(app: "Notes", frame: $0.offsetBy(dx: Self.corner(left).x, dy: Self.corner(left).y)) }
    h.start()
    h.system.setDisplays([laptop])
    h.scheduler.advance(by: 5)
    h.system.setDisplays([laptop, moved(studio, to: Self.corner(returns), isMain: false)])
    h.scheduler.advance(by: 5)
    h.run("home")
    for (window, place) in zip(windows, Self.places) {
      #expect(h.frame(window) == place.offsetBy(dx: Self.corner(returns).x, dy: Self.corner(returns).y), "\(place.origin)")
    }
  }

  /// A tester's day: the big display is the MAIN display, so it is the laptop's corner that moves at every unplug and
  /// replug, and the laptop's workspace is never away. Its floating windows were shoved about on every trip to a meeting.
  @Test func withTheBigDisplayAsTheMainOneTheLaptopsWindowsKeepTheirPlaces() {
    let builtin = DisplaySnapshot(
      id: DisplayID("builtin"), frame: CGRect(x: -1728, y: 323, width: 1728, height: 1117),
      visibleFrame: CGRect(x: -1728, y: 356, width: 1728, height: 1084), isMain: false)
    let desk = moved(studio, to: .zero, isMain: true)
    let h = Harness(displays: [desk, builtin])
    let spots = [
      CGRect(x: -1400, y: 500, width: 805, height: 540), CGRect(x: -900, y: 700, width: 700, height: 500),
      CGRect(x: -400, y: 1250, width: 300, height: 120),
    ]
    let windows = spots.map { h.system.open(app: "Notes", frame: $0) }
    h.start()
    h.scheduler.advance(by: 5)

    change(h, to: [moved(builtin, to: .zero, isMain: true)], shifting: CGPoint(x: 1728, y: -323))
    h.run("home")
    for (window, spot) in zip(windows, spots) { #expect(h.frame(window) == spot.offsetBy(dx: 1728, dy: -323)) }

    change(h, to: [desk, builtin], shifting: CGPoint(x: -1728, y: 323))
    h.run("home")
    for (window, spot) in zip(windows, spots) {
      #expect(h.frame(window) == spot)
      #expect(h.controller.workspaces[builtin.id]?.isFloating(window) == true)
    }
  }

  // MARK: A display that was away and comes back smaller

  /// In view, and it stays so: `home`, and a pause, a resume and `home`.
  func expectInViewForGood(_ window: WindowID, on display: DisplaySnapshot, _ h: Harness, sourceLocation: SourceLocation = #_sourceLocation) {
    h.scheduler.advance(by: 5)
    for command in ["home", "relayout", "pause", "resume", "home"] {
      h.run(command)
      h.scheduler.advance(by: 3)
      #expect(
        display.visibleFrame.contains(h.frame(window)!), "after \(command): \(h.frame(window)!)", sourceLocation: sourceLocation)
    }
  }

  func display(_ id: String, _ x: CGFloat, _ y: CGFloat, _ width: CGFloat, _ height: CGFloat, isMain: Bool = false) -> DisplaySnapshot {
    DisplaySnapshot(
      id: DisplayID(id), frame: CGRect(x: x, y: y, width: width, height: height),
      visibleFrame: CGRect(x: x, y: y + 25, width: width, height: height - 25), isMain: isMain)
  }

  /// (A), found by a random walk: the window is let go at 2694,821 on `third`, whose corner is 1440,61.
  /// `third` goes, and comes back alone at 0,0, 1280×800 where it was 1512×982. Shifted and not fitted the window was at
  /// 1254,760: 26 points of it showed, and `home` did not fetch it.
  @Test func aDisplayThatComesBackSmallerAndElsewhereHasItsWindowsInView() {
    let main = display("main", 0, 0, 1440, 900, isMain: true)
    let h = Harness(displays: [main, display("third", 1440, 61, 1512, 982)])
    let mail = h.system.open(app: "Mail", frame: CGRect(x: 2694, y: 821, width: 138, height: 103))
    h.start()
    h.system.setDisplays([main])
    h.scheduler.advance(by: 5)
    let smaller = display("third", 0, 0, 1280, 800, isMain: true)
    h.system.setDisplays([smaller])
    expectInViewForGood(mail, on: smaller, h)
  }

  /// (B): the corner is 0,0 before and after, so nothing was shifted, and nothing fitted.
  @Test func aDisplayThatComesBackSmallerAtTheSameCornerHasItsWindowsInView() {
    let h = Harness(displays: [display("desk", 0, 0, 2560, 1440, isMain: true)])
    let mail = h.system.open(app: "Mail", frame: CGRect(x: 1254, y: 760, width: 500, height: 400))
    h.start()
    h.system.setDisplays([laptop])
    h.scheduler.advance(by: 5)
    let smaller = display("desk", 0, 0, 1280, 800, isMain: true)
    h.system.setDisplays([smaller])
    expectInViewForGood(mail, on: smaller, h)
  }

  /// (B) plain: beside a laptop that stays, unplugged and plugged in again at another scaling.
  @Test func aSecondDisplayPluggedInAgainSmallerHasItsWindowsInView() {
    let h = Harness(displays: [laptop, studio])
    let mail = h.system.open(app: "Mail", frame: CGRect(x: 1440 + 1890, y: 1050, width: 500, height: 300))
    h.start()
    h.system.setDisplays([laptop])
    h.scheduler.advance(by: 5)
    let smaller = display("studio", 1440, 0, 1920, 1080)
    h.system.setDisplays([laptop, smaller])
    expectInViewForGood(mail, on: smaller, h)
  }

  /// As large as it was, nothing is fitted: a strip left on purpose comes back the same strip, wherever the display returns.
  @Test(arguments: Side.allCases) private func aDisplayThatComesBackAsLargeAsItWasKeepsAnOverhang(returns: Side) {
    let h = Harness(displays: [laptop, studio])
    let strip = CGRect(x: 1440 + 2500, y: 1300, width: 600, height: 400)
    let n = h.system.open(app: "Notes", frame: CGRect(x: 2000, y: 500, width: 600, height: 400))
    h.start()
    h.system.userMove(n, to: strip)
    h.scheduler.advance(by: 3)
    #expect(onStudio(h)?.floating[n] == strip, "put there by hand")
    h.system.setDisplays([laptop])
    h.scheduler.advance(by: 5)
    h.system.setDisplays([laptop, moved(studio, to: Self.corner(returns), isMain: false)])
    h.scheduler.advance(by: 5)
    // Not a pause: that fetches whatever is mostly off screen, whoever left it there.
    for command in ["home", "relayout", "desktop", "home"] {
      h.run(command)
      h.scheduler.advance(by: 3)
    }
    #expect(onStudio(h)?.floating[n] == strip.offsetBy(dx: Self.corner(returns).x - 1440, dy: Self.corner(returns).y))
  }

  /// It grew: every place is still on it, and fitting changes none that was in full view.
  @Test func aDisplayThatComesBackLargerKeepsPlacesInFullView() {
    let small = display("studio", 1440, 0, 1920, 1080)
    let h = Harness(displays: [laptop, small])
    let spot = CGRect(x: 1440 + 1200, y: 600, width: 500, height: 300)
    let n = h.system.open(app: "Notes", frame: spot)
    h.start()
    h.system.setDisplays([laptop])
    h.scheduler.advance(by: 5)
    h.system.setDisplays([laptop, studio])
    h.scheduler.advance(by: 5)
    h.run("home")
    #expect(h.frame(n) == spot)
  }

  // MARK: What is saved

  /// A corner that is no place for a display is not believed, and costs nothing else.
  @Test func aDamagedCornerMovesNothing() throws {
    let (first, n) = atTheDesk()
    first.system.setDisplays([laptop])
    first.controller.saveNow()
    var object = try #require(
      JSONSerialization.jsonObject(with: try JSONEncoder().encode(first.store.saved!)) as? [String: Any])
    object["origins"] = ["main": [1e300, 0], "nonsense": "here"]
    var dormant = try #require(object["dormant"] as? [String: Any])
    var entry = try #require(dormant[studio.id.rawValue] as? [String: Any])
    entry["origin"] = [-1e18, 5]
    dormant[studio.id.rawValue] = entry
    object["dormant"] = dormant
    let read = try JSONDecoder().decode(PersistedState.self, from: JSONSerialization.data(withJSONObject: object))
    #expect(read.origins == [:])
    #expect(read.dormant[studio.id]?.origin == nil)
    #expect(read.dormant[studio.id]?.workspace.floating[n] == Self.spot)
    #expect(read.workspaces == first.store.saved?.workspaces)
  }

  @Test func whereADisplayWasIsSavedAndOlderFilesStillLoad() throws {
    let h = Harness(displays: [laptop, studio])
    let n = h.system.open(app: "Notes", frame: CGRect(x: 2530, y: 500, width: 600, height: 400))
    h.start()
    h.system.setDisplays([laptop])
    h.controller.saveNow()
    #expect(h.store.saved?.dormant[studio.id]?.origin == CGPoint(x: 1440, y: 0))
    let data = try JSONEncoder().encode(h.store.saved!)
    #expect(try JSONDecoder().decode(PersistedState.self, from: data) == h.store.saved)

    // A file from before: nothing is known of where the display was, and nothing is moved on that account.
    var object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    var dormant = try #require(object["dormant"] as? [String: Any])
    var entry = try #require(dormant[studio.id.rawValue] as? [String: Any])
    #expect(entry.removeValue(forKey: "origin") != nil)
    dormant[studio.id.rawValue] = entry
    object["dormant"] = dormant
    let older = try JSONDecoder().decode(PersistedState.self, from: JSONSerialization.data(withJSONObject: object))
    #expect(older.dormant[studio.id]?.origin == nil)
    #expect(older.dormant[studio.id]?.workspace.floating[n] != nil)
  }
}
