import ArborCore

/// Writes one stage's log of its frames (`StageLog`) into the trace that is being recorded: which lines, in which order, and when none.
/// Whoever has a stage tells it what happens to it and when the display ticks, and says where the stand-ins are when asked:
/// `StageSampler` in the app, `RehearsedStage` where there is no screen.
///
/// A motion is logged from a beginning or not at all. If the trace ends in mid-motion, or another one is begun, nothing more of this
/// motion is written: the new trace would hold frames and an end of something it has no beginning of.
@MainActor
public final class StageLogWriter {
  private let recorder: TraceRecorder
  private var display = DisplayID("")
  /// Where each stand-in on the stage is drawn at this moment. Nil while nothing is logged.
  private var samples: (() -> [StageLog.Sample])?
  /// The trace that has the beginning of what is being logged.
  private var trace = 0

  public init(recorder: TraceRecorder) { self.recorder = recorder }

  /// Whether there is anybody to write for. The one thing a stage pays for while no trace is recorded.
  public var isWanted: Bool { recorder.isRecording }

  /// Whether a motion is being logged, so that ticks are worth having.
  public var isLogging: Bool {
    if samples != nil, !recorder.isRecording || recorder.tracesBegun != trace { samples = nil }
    return samples != nil
  }

  /// The stand-ins are on their way. `retargeted`: on a stage that was up already, logged or not.
  public func began(_ transition: Transition, retargeted: Bool, samples: @escaping () -> [StageLog.Sample]) {
    guard recorder.isRecording else { return self.samples = nil }
    display = transition.display
    self.samples = samples
    trace = recorder.tracesBegun
    recorder.stage(.began(transition, carryingOnFrom: retargeted ? samples() : nil))
    // At once, and not at the next tick, by when they have moved on: this is the frame that takes over from the real windows.
    tick()
  }

  /// The display shows a new frame.
  public func tick() {
    guard isLogging, let samples else { return }
    recorder.stage(.frame(display, samples()))
  }

  /// The motion is over and the stage begins to fade.
  public func lifting() {
    guard isLogging else { return }
    recorder.stage(.lift(display))
  }

  /// The stage is about to be taken off the screen, with its stand-ins still on it.
  public func comingDown() {
    guard isLogging else { return }
    // The frame that hands over to the real windows.
    tick()
    recorder.stage(.down(display))
    samples = nil
  }
}
