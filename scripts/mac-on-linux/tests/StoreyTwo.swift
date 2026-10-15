import ArborCore
@testable import ArborKit
import ArborTesting
import ApplicationServices
import CoreGraphics
import FakeMacOS
import Foundation

// Storey two: the real `Controller` on the real `AXWindowSystem` on the model of a Mac, wired as `ArborApp` wires them. Only what draws (the overlays) and
// what writes to disk (the store) are the fakes of ArborTesting. The scheduler is the app's own, whose waiting goes by the model's clock.

@MainActor
final class StoreyTwo {
  let mac = FakeMac()
  let layer = AXWindowSystem()
  let heard = Listener()
  let overlays = FakeOverlays()
  let store = MemoryStateStore()
  let controller: Controller
  private let recording: RecordingWindowSystem
  private let watcher: FrontmostAppWatcher

  /// `before` sets the Mac up as it is when Arbor starts. A second then passes, and Arbor starts.
  init(_ story: Story, settings: Settings = Settings(), before: (FakeMac) -> Void = { _ in }) {
    FakeMac.current = mac
    before(mac)
    mac.pass(1)
    let recorder = TraceRecorder()
    layer.recorder = recorder
    recording = RecordingWindowSystem(wrapping: layer, recorder: recorder)
    controller = Controller(
      system: recording, overlays: RecordingOverlays(wrapping: overlays, recorder: recorder), store: store,
      scheduler: RecordingScheduler(wrapping: MainQueueScheduler(), recorder: recorder), settings: settings)
    let (mac, controller) = (self.mac, self.controller)
    let start = Date(timeIntervalSinceReferenceDate: 800_000_000)
    controller.now = { start.addingTimeInterval(mac.now) }
    // The listener sits between the layer and the rest, and passes everything on.
    heard.mac = mac
    heard.next = recording
    layer.events = heard
    controller.accessibilityGranted = true
    // The app's thorough way is to make an event tap, which the model has none of.
    controller.accessibilityProbe = { _ in AXIsProcessTrusted() }
    watcher = FrontmostAppWatcher { [weak controller] app in controller?.applicationActivated(app) }
    mac.note("Arbor starts")
    story.listens(heard, storey: 2, from: mac.now)
    watcher.start()
    controller.start()
    mac.pass(1)
    story.onFailure { "    what happened on the Mac, and what Arbor made of it:\n" + mac.journal.map { "      " + $0 }.joined(separator: "\n") }
    story.atTheEnd { [layer, watcher] in
      watcher.stop()
      layer.stop()
      mac.end()
    }
  }

  /// Runs a command, written as for `arborctl`, and lets things settle.
  @discardableResult
  func run(_ text: String, then seconds: TimeInterval = 1) -> CommandResult {
    mac.note("arborctl \(text)")
    let result: CommandResult
    do { result = controller.perform(try Command.parse(text)) } catch { result = .failure("\(error)") }
    if !result.ok { mac.note("    it fails: \(result.message)") }
    mac.pass(seconds)
    return result
  }

  /// How much of a window a person can see of what the display shows, from 0 to 1. Other windows in front of it are not reckoned with.
  func visibleFraction(_ window: FakeMac.Window) -> Double {
    guard mac.isShowing(window), window.bounds.width > 0, window.bounds.height > 0 else { return 0 }
    let seen = mac.screens.reduce(0.0) { sum, screen in
      let part = window.bounds.intersection(screen.frame)
      return part.isNull ? sum : sum + Double(part.width * part.height)
    }
    return seen / Double(window.bounds.width * window.bounds.height)
  }
  func isInView(_ window: FakeMac.Window) -> Bool { visibleFraction(window) > 0.95 }
  func isOutOfView(_ window: FakeMac.Window) -> Bool { visibleFraction(window) < 0.05 }
  func whereabouts(_ window: FakeMac.Window) -> String { "w\(window.number) is at \(window.bounds.text)" }
}

extension CGRect {
  /// As in the traces: x, y, width, height.
  var text: String { "\(Int(minX)),\(Int(minY)) \(Int(width))×\(Int(height))" }
}
