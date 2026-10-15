import ArborCore
import ArborKit
import ArborTesting
import CoreGraphics
import Testing

/// What the stand-in does when displays come, go, move and change places (`FakeWindowSystem+Displays.swift`). Tests and arbor-sim
/// rest on it, so it is held to what it says.
@Suite @MainActor struct FakeDisplaysTests {
  let desk = DisplaySnapshot(
    id: DisplayID("desk"), frame: CGRect(x: 1440, y: -200, width: 2560, height: 1440),
    visibleFrame: CGRect(x: 1440, y: -200, width: 2560, height: 1440), isMain: false)

  /// A laptop, a big display to its right and a little higher, and a window on each.
  func make() -> (FakeWindowSystem, onTheLaptop: WindowID, atTheDesk: WindowID) {
    let system = FakeWindowSystem()
    system.plug(desk)
    let a = system.open(app: "Notes", frame: CGRect(x: 100, y: 100, width: 400, height: 300))
    let b = system.open(app: "Mail", frame: CGRect(x: 2000, y: 300, width: 400, height: 300))
    system.cursor = CGPoint(x: 2100, y: 400)
    return (system, a, b)
  }

  @Test func pluggingInTheSameDisplayAgainReplacesIt() {
    let (system, _, _) = make()
    var larger = desk
    larger.frame.size.width = 3000
    system.plug(larger)
    #expect(system.displayList.map(\.id.rawValue) == ["main", "desk"])
    #expect(system.displayList[1].frame.width == 3000)
  }

  @Test func aDisplayThatIsNotTheMainOneGoesAndNothingElseChanges() {
    let (system, a, b) = make()
    system.unplug(desk.id)
    #expect(system.displayList == [FakeWindowSystem.standardDisplay])
    #expect(system.frame(of: a)!.origin == CGPoint(x: 100, y: 100))
    #expect(system.frame(of: b)!.origin == CGPoint(x: 2000, y: 300), "where macOS would take it is not modelled")
  }

  /// The lid closes.
  @Test func whenTheMainDisplayGoesTheNextOnesCornerIsTheOrigin() {
    let (system, a, b) = make()
    system.unplug(DisplayID("main"))
    #expect(system.displayList.map(\.id) == [desk.id])
    #expect(system.displayList[0].isMain)
    #expect(system.displayList[0].frame == CGRect(x: 0, y: 0, width: 2560, height: 1440))
    #expect(system.displayList[0].visibleFrame == CGRect(x: 0, y: 0, width: 2560, height: 1440))
    #expect(system.frame(of: a)!.origin == CGPoint(x: -1340, y: 300))
    #expect(system.frame(of: b)!.origin == CGPoint(x: 560, y: 500))
    #expect(system.cursor == CGPoint(x: 660, y: 600))
  }

  @Test func theMenuBarGoesOverAndComesBackAndAllIsAsItWas() {
    let (system, a, b) = make()
    let before = (system.displayList, system.frame(of: a), system.frame(of: b), system.cursor)
    system.makeMain(desk.id)
    #expect(system.displayList.map(\.id.rawValue) == ["desk", "main"], "the main display comes first")
    #expect(system.displayList.map(\.isMain) == [true, false])
    #expect(system.displayList[1].frame.origin == CGPoint(x: -1440, y: 200))
    #expect(system.displayList[1].visibleFrame.origin == CGPoint(x: -1440, y: 225))
    system.makeMain(DisplayID("main"))
    #expect(system.displayList == before.0)
    #expect(system.frame(of: a) == before.1)
    #expect(system.frame(of: b) == before.2)
    #expect(system.cursor == before.3)
  }

  @Test func aDisplayThatIsMovedTakesItsOwnWindowsAlong() {
    let (system, a, b) = make()
    system.moveDisplay(desk.id, to: CGPoint(x: -2560, y: 0))
    #expect(system.displayList[1].frame.origin == CGPoint(x: -2560, y: 0))
    #expect(system.frame(of: a)!.origin == CGPoint(x: 100, y: 100))
    #expect(system.frame(of: b)!.origin == CGPoint(x: -2000, y: 500))
  }

  /// macOS shifts windows whether or not Arbor may look at them.
  @Test func windowsAreShiftedAlsoWhileArborHasNoPermission() {
    let (system, _, b) = make()
    system.isDenied = true
    system.makeMain(desk.id)
    #expect(system.frame(of: b)!.origin == CGPoint(x: 560, y: 500))
  }

  @Test func aDisplayNobodyKnowsChangesNothing() {
    let (system, a, _) = make()
    let before = system.displayList
    system.makeMain(DisplayID("nowhere"))
    system.moveDisplay(DisplayID("nowhere"), to: .zero)
    system.unplug(DisplayID("nowhere"))
    #expect(system.displayList == before)
    #expect(system.frame(of: a)!.origin == CGPoint(x: 100, y: 100))
  }

  /// A trace holds what Arbor read when it heard of the displays, so a lid that closes and opens replays: in the replay too the windows
  /// have their new coordinates by then, and Arbor finds every one of them in its place.
  @Test(arguments: [TraceReplayer.Mode.strict, .free]) func aLidThatClosesAndOpensReplaysFromItsTrace(mode: TraceReplayer.Mode) {
    let h = Harness()
    h.system.plug(desk)
    let a = h.system.open(app: "Code", frame: CGRect(x: 1600, y: 100, width: 800, height: 600))
    let b = h.system.open(app: "Chat", frame: CGRect(x: 2900, y: 300, width: 400, height: 300))
    h.start()
    h.system.cursor = CGPoint(x: 2000, y: 500)
    h.run("trace on lid")
    h.run("dock \(a.rawValue) left")
    h.system.clearFrameLog()
    h.system.unplug(DisplayID("main"))
    // It opens: the laptop is back where it was beside the other display, and gets the menu bar. Arbor hears once all that is over.
    var laptop = FakeWindowSystem.standardDisplay
    laptop.isMain = false
    laptop.frame.origin = CGPoint(x: -1440, y: 200)
    laptop.visibleFrame.origin = CGPoint(x: -1440, y: 225)
    let listener = h.system.events
    h.system.events = nil
    h.system.plug(laptop)
    h.system.makeMain(laptop.id)
    h.system.events = listener
    h.system.setDisplays(h.system.displayList)
    #expect(h.system.displayList == [FakeWindowSystem.standardDisplay, desk])
    #expect(h.system.frameLog.isEmpty, "nothing has moved on the glass, so Arbor has moved nothing: \(h.system.frameLog)")
    h.run("trace off")
    let replayer = TraceReplayer(recordedTrace(h), mode: mode)
    #expect(replayer.run().problems == [])
    for window in [a, b] { #expect(replayer.harness.frame(window) == h.frame(window)) }
  }

  /// None of the windows says a word: Arbor hears of the displays and has to read the frames itself.
  @Test func noWindowReportsTheShift() {
    let h = Harness()
    h.system.plug(desk)
    let a = h.system.open(app: "Notes", frame: CGRect(x: 2000, y: 300, width: 400, height: 300))
    h.start()
    h.system.makeMain(desk.id)
    #expect(h.controller.windows[a]?.frame.origin == CGPoint(x: 560, y: 500), "read when the displays were reported")
    #expect(h.system.frameLog.isEmpty, "and nothing on the glass has moved, so Arbor moves nothing")
  }
}
