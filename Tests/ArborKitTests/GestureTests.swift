import ArborCore
import ArborKit
import ArborTesting
import CoreGraphics
import Testing

/// F16's input half: what the controller does with the updates the gesture taps stream to it. Until F16's
/// model follows the fingers, a streamed pinch steps the way F03's does.
@Suite @MainActor struct GestureTests {
  /// root(h)[a, desktop, b], showing everything, with the pointer over `a`.
  func makeHarness() -> (Harness, WindowID, WindowID) {
    let h = Harness()
    let a = h.system.open(app: "Safari", frame: CGRect(x: 100, y: 100, width: 600, height: 400))
    let b = h.system.open(app: "Notes", frame: CGRect(x: 300, y: 200, width: 600, height: 400))
    h.start()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) right")
    h.system.cursor = h.frame(a)!.center
    return (h, a, b)
  }

  func send(_ h: Harness, _ phase: GestureUpdate.Phase, magnification: Double = 0, pan: CGSize = .zero) {
    h.controller.gesture(
      GestureUpdate(phase: phase, location: h.system.cursor, magnification: magnification, pan: pan))
  }

  @Test func aStreamedPinchEndsWhereTheSameStepsWould() {
    let (h, a, b) = makeHarness()
    send(h, .began)
    send(h, .changed, magnification: 0.1)
    #expect(h.workspace.camera == h.workspace.tree.root, "below the threshold nothing moves")
    send(h, .changed, magnification: 0.2)
    send(h, .ended)
    #expect(h.workspace.camera == h.workspace.tree.leaf(containing: a))
    #expect(!h.system.isVisible(b))

    let (other, otherA, _) = makeHarness()
    other.run("in")
    #expect(other.frame(otherA) == h.frame(a))
    expectWindowsMatchLayout(h, on: h.display)
  }

  @Test func theMovementThatComesWithTheEndCounts() {
    // A whole pinch gathered while the main thread was busy arrives as began and ended.
    let (h, a, _) = makeHarness()
    send(h, .began)
    send(h, .ended, magnification: 0.3)
    #expect(h.workspace.camera == h.workspace.tree.leaf(containing: a))
  }

  @Test func travelIsNotCarriedFromOneGestureToTheNext() {
    let (h, _, _) = makeHarness()
    send(h, .began)
    send(h, .ended, magnification: 0.2)
    send(h, .began)
    send(h, .ended, magnification: 0.2)
    #expect(h.workspace.camera == h.workspace.tree.root)
  }

  @Test func updatesOutsideAGestureDoNothing() {
    let (h, _, _) = makeHarness()
    send(h, .changed, magnification: 0.9)
    send(h, .ended, magnification: 0.9)
    #expect(h.workspace.camera == h.workspace.tree.root)
  }

  @Test func aCancelledGestureKeepsWhatItHasDoneAndAddsNothing() {
    let (h, a, _) = makeHarness()
    send(h, .began)
    send(h, .changed, magnification: 0.3)
    send(h, .cancelled, magnification: -0.9)
    #expect(h.workspace.camera == h.workspace.tree.leaf(containing: a))
  }

  @Test func nothingHappensWhilePausedOrBeforeTheStart() {
    let (h, _, _) = makeHarness()
    h.run("pause")
    send(h, .began)
    send(h, .ended, magnification: 0.9)
    h.run("resume")
    #expect(h.workspace.camera == h.workspace.tree.root)

    let early = Harness()
    send(early, .began)
    send(early, .ended, magnification: 0.9)  // must not crash: there is no display yet
  }

  @Test func aPauseTurnsContinuousZoomsTapsOffWithTheOthers() {
    let (h, _, _) = makeHarness()
    var settings = h.controller.settings
    settings.continuousZoom = true
    h.controller.apply(settings: settings)
    h.run("pause")
    // The scroll tap is installed only while gestures are on.
    #expect(!h.controller.inputSettings.gesturesEnabled)
  }
}
