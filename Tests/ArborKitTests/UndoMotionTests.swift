import ArborCore
import ArborKit
import ArborTesting
import CoreGraphics
import Testing

/// Undo and redo shown as motion (F19 with F02). The stage goes up before anything moves and shows stand-ins travelling
/// from where the windows were to where they go, so whatever an undo moves has to be known to the layout that plans
/// the journey: a window moved before it vanishes without a trace, one moved after it jumps when the stage lifts.
@Suite @MainActor struct UndoMotionTests {
  /// Three floating windows, started.
  func makeHarness(settings: Settings = Harness.settingsWhenNoneAreGiven) -> (Harness, WindowID, WindowID, WindowID) {
    let h = Harness(settings: settings.withMotion)
    let a = h.system.open(app: "Safari", frame: CGRect(x: 100, y: 100, width: 600, height: 400))
    let b = h.system.open(app: "Notes", frame: CGRect(x: 300, y: 200, width: 600, height: 400))
    let c = h.system.open(app: "Mail", frame: CGRect(x: 500, y: 300, width: 600, height: 400))
    h.start()
    return (h, a, b, c)
  }

  /// Runs `command` and returns the journey it showed. One journey: a second would be a correction of the first.
  func journey(_ h: Harness, _ command: String, sourceLocation: SourceLocation = #_sourceLocation) -> Transition? {
    h.overlays.clearTransitions()
    #expect(h.run(command).ok, sourceLocation: sourceLocation)
    #expect(h.overlays.transitions.count == 1, "\(h.overlays.transitions.count) journeys", sourceLocation: sourceLocation)
    return h.overlays.transitions.last
  }

  func item(_ window: WindowID, in transition: Transition?) -> Transition.Item? {
    transition?.items.first { $0.window == window }
  }

  @Test func aWindowThatFloatsAgainTravelsFromItsSlotToWhereItWas() throws {
    let (h, a, _, _) = makeHarness()
    let floated = try #require(h.frame(a))
    h.run("dock \(a.rawValue) left")
    let slot = try #require(h.frame(a))
    let item = try #require(self.item(a, in: journey(h, "undo")))
    #expect(h.frame(a) == floated)
    #expect(item.from == slot && item.fromOpacity == 1, "it starts where it is seen")
    #expect(item.to == floated && item.toOpacity == 1)
  }

  @Test func aWindowPutBackOverDockedWindowsTravelsThere() throws {
    let (h, a, _, c) = makeHarness()
    h.run("dock \(a.rawValue) left")
    // Left over the docked window on purpose.
    let place = CGRect(x: 200, y: 300, width: 400, height: 300)
    h.system.userMove(c, to: place)
    h.run("dock \(c.rawValue) right")
    let slot = try #require(h.frame(c))
    let item = try #require(self.item(c, in: journey(h, "undo")))
    #expect(h.frame(c) == place)
    #expect(item.from == slot && item.to == place)
  }

  /// Floating windows that make way: only they leave with the Desktop.
  @Test func aWindowThatGoesOutOfViewWithTheUndoIsSeenLeaving() throws {
    let (h, a, b, _) = makeHarness(settings: .makingWay)
    h.run("dock \(a.rawValue) left")
    h.run("zoom \(a.rawValue)")
    #expect(h.controller.parked.contains(b), "out of view with the Desktop")
    // Docking b brings it into view; undoing that sends it out again.
    h.run("dock \(b.rawValue) right")
    let slot = try #require(h.frame(b))
    let item = try #require(self.item(b, in: journey(h, "undo")))
    #expect(h.controller.parked.contains(b))
    #expect(item.from == slot && item.fromOpacity == 1, "it starts where it is seen")
    #expect(!item.to.overlaps(h.visibleFrame) || item.toOpacity == 0, "and leaves")
  }

  /// As Arbor ships the same undo frames a again, and b floats over it where it floated before.
  @Test func aWindowThatFloatsAgainOverAFramedOneTravelsToWhereItWas() throws {
    let (h, a, b, _) = makeHarness(settings: Settings())
    let floated = try #require(h.frame(b))
    h.run("dock \(a.rawValue) left")
    h.run("zoom \(a.rawValue)")
    #expect(h.frame(b) == floated && !h.controller.parked.contains(b), "no view takes it away")
    h.run("dock \(b.rawValue) right")
    let slot = try #require(h.frame(b))
    let item = try #require(item(b, in: journey(h, "undo")))
    #expect(h.workspace.camera == h.workspace.tree.leaf(containing: a))
    #expect(h.frame(b) == floated && !h.controller.parked.contains(b))
    #expect(item.from == slot && item.fromOpacity == 1, "it starts where it is seen")
    #expect(item.to == floated && item.toOpacity == 1, "and ends where it is")
  }

  @Test func redoIsAJourneyToo() throws {
    let (h, a, _, _) = makeHarness()
    let floated = try #require(h.frame(a))
    h.run("dock \(a.rawValue) left")
    let slot = try #require(h.frame(a))
    h.run("undo")
    let item = try #require(self.item(a, in: journey(h, "redo")))
    #expect(item.from == floated && item.to == slot)
  }

  /// Whatever came before: the journey an undo or a redo shows starts where each window was seen and ends where it is.
  @Test(arguments: Array<UInt64>(1...30)) func everyJourneyStartsAndEndsWhereTheWindowsAre(seed: UInt64) {
    var random = SplitMix(seed: seed)
    let (h, _, _, _) = makeHarness()
    func pick() -> WindowID? { h.system.allWindows().map(\.id).randomElement(using: &random) }
    func inView() -> [WindowID: CGRect] {
      var frames: [WindowID: CGRect] = [:]
      for window in h.system.allWindows()
      where h.controller.windows[window.id]?.isPresent == true && !h.controller.parked.contains(window.id) {
        frames[window.id] = window.frame
      }
      return frames
    }
    let edges = ["left", "right", "top", "bottom"]
    for step in 0..<150 {
      var did = ""
      switch Int.random(in: 0..<16, using: &random) {
      case 0...3: did = "undo"
      case 4...5: did = "redo"
      case 6...8: if let w = pick() { did = "dock \(w.rawValue) \(edges.randomElement(using: &random)!)" }
      case 9: if let w = pick() { did = "toggle-float \(w.rawValue)" }
      case 10: if let w = pick() { did = "zoom \(w.rawValue)" }
      case 11: did = ["back", "show-all", "out", "desktop", "arrange", "float-all"].randomElement(using: &random)!
      case 12: if let w = pick() { did = "toggle-pin \(w.rawValue)" }
      case 13:
        if h.system.allWindows().count < 6 {
          h.system.open(app: "New\(step)", frame: CGRect(x: 200 + 40 * (step % 9), y: 200, width: 400, height: 300))
        }
      case 14:
        if let w = pick(), h.workspace.isFloating(w), !h.controller.parked.contains(w) {
          h.system.userMove(
            w, to: CGRect(x: Int.random(in: 20...900, using: &random), y: Int.random(in: 40...500, using: &random), width: 420, height: 300))
        }
      default: if let w = pick() { did = "resize \(w.rawValue) \(edges.randomElement(using: &random)!) 70" }
      }
      h.scheduler.advance(by: 2)
      guard !did.isEmpty else { continue }
      let before = inView()
      h.overlays.clearTransitions()
      guard h.run(did).ok, did == "undo" || did == "redo", let journey = h.overlays.transitions.last else { continue }
      let after = inView()
      let note = "\(did) at step \(step), seed \(seed)"
      for item in journey.items {
        if let seen = before[item.window] {
          #expect(item.from.approximatelyEquals(seen, tolerance: 1), "\(item.window) starts elsewhere than it was seen: \(note)")
        }
        if let lands = after[item.window] {
          #expect(item.to.approximatelyEquals(lands, tolerance: 1), "\(item.window) ends elsewhere than it is: \(note)")
        } else if h.workspace.isFloating(item.window) {
          // (A docked window out of view can end on its tile.)
          #expect(!item.to.overlaps(h.visibleFrame) || item.toOpacity == 0, "\(item.window) is out of view, its stand-in is not: \(note)")
        }
      }
      for window in Set(before.keys).union(after.keys) where before[window] != after[window] {
        #expect(journey.items.contains { $0.window == window }, "\(window) moved and is not in the journey: \(note)")
      }
    }
  }
}

/// SplitMix64, so random tests are reproducible.
private struct SplitMix: RandomNumberGenerator {
  var state: UInt64
  init(seed: UInt64) { state = (seed ^ 0x5_DEEC_E66D) &* 0xD134_2543_DE82_EF95 }
  mutating func next() -> UInt64 {
    state &+= 0x9E37_79B9_7F4A_7C15
    var z = state
    z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
    z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
    return z ^ (z >> 31)
  }
}
