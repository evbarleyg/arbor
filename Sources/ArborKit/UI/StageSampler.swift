import AppKit
import ArborCore
import QuartzCore

/// The eyes of one stage's log of its frames: a display link for the ticks, and where Core Animation draws the stand-ins. What is written and
/// when is `StageLogWriter`'s business; `StageLog` has the lines and says what they are for. While no trace is recorded, each of the
/// stage's three calls costs one test of a flag, and nothing runs.
///
/// It looks and does not touch: it has no window and no view, so no event can reach it, and it only reads the layers.
///
/// The ticks come on the main run loop. So the log shows the motion as the app saw it: while the main thread waits for an app to
/// take its frame there is no tick, though the window server goes on drawing the stand-ins.
@MainActor
final class StageSampler: NSObject {
  private let writer: StageLogWriter
  private var link: CADisplayLink?

  init(recorder: TraceRecorder) {
    writer = StageLogWriter(recorder: recorder)
    super.init()
  }

  /// The stand-ins are on their way. `layers` are all that are on the stage, also those that are no longer part of the motion.
  func began(_ transition: Transition, retargeted: Bool, layers: @autoclosure () -> [WindowID: CALayer]) {
    guard writer.isWanted else { return link == nil ? () : stop() }
    // In order once, and not at every tick.
    let layers = layers().sorted { $0.key < $1.key }
    // The layers' frames are relative to the display's.
    let frame = transition.frame
    writer.began(transition, retargeted: retargeted) {
      layers.map { window, layer in
        let drawn = layer.presentation() ?? layer
        return StageLog.Sample(window, ScreenGeometry.global(fromLocal: drawn.frame, in: frame), opacity: Double(drawn.opacity))
      }
    }
    guard link == nil, writer.isLogging, let screen = ScreenGeometry.screen(for: transition.display) ?? NSScreen.screens.first else { return }
    let link = screen.displayLink(target: self, selector: #selector(ticked(_:)))
    // Common modes, as the stage's timers: an open menu does not stop the motion.
    link.add(to: .main, forMode: .common)
    self.link = link
  }

  /// The motion is over and the stage begins to fade.
  func lifting() { writer.lifting() }

  /// The stage is about to be taken off the screen, with its stand-ins still on it.
  func comingDown() {
    writer.comingDown()
    if link != nil { stop() }
  }

  @objc private func ticked(_ link: CADisplayLink) {
    writer.tick()
    // The trace has ended, by command or by itself, or another has begun.
    if !writer.isLogging { stop() }
  }

  /// The link holds on to its target until it is invalidated.
  private func stop() {
    link?.invalidate()
    link = nil
  }
}
