import ArborCore
import ArborKit
import CoreGraphics

/// Stands in for the stages of the real app where there is no screen: plays every transition the controller asks for as a stage that
/// does everything right would, on the manual scheduler's clock, and has it logged into the trace that is being recorded by the writer the
/// app uses (`StageLogWriter`), with sixty ticks a second.
///
/// For rehearsing what comes after a run on a Mac: that the lines get through a trace file and `arbor-sim stage-judge` reads them. The roads
/// are the real controller's. The motion along them is made up, so a rehearsal says nothing about how Arbor moves.
@MainActor
public final class RehearsedStage {
  /// One display's stage while it is up.
  private struct Playing {
    var plan: StageLog.Plan
    var began: Double
  }

  /// `Stage.liftDuration`.
  private static let liftDuration = 0.08

  private let recorder: TraceRecorder
  private let scheduler: ManualScheduler
  private var writers: [DisplayID: StageLogWriter] = [:]
  private var playing: [DisplayID: Playing] = [:]

  /// Takes `overlays.onAnimate` and `onFinish` for itself.
  public init(recorder: TraceRecorder, scheduler: ManualScheduler, overlays: FakeOverlays) {
    self.recorder = recorder
    self.scheduler = scheduler
    overlays.onAnimate = { [weak self] in self?.play($0) }
    overlays.onFinish = { [weak self] in self?.finish() }
  }

  /// As `StageDirector.play` and `Stage.play`. The stage goes up and comes down whether or not anybody records it.
  private func play(_ transition: Transition) {
    guard transition.duration > 0 else { return finish() }
    let display = transition.display
    let writer = writers[display] ?? StageLogWriter(recorder: recorder)
    writers[display] = writer
    let now = playing[display].map { samples($0) }
    guard let plan = StageLog.Line.began(transition, carryingOnFrom: now).plan else { return }
    playing[display] = Playing(plan: plan, began: scheduler.now)
    writer.began(transition, retargeted: now != nil) { [weak self] in self?.playing[display].map { self?.samples($0) ?? [] } ?? [] }
    // Not through the decorator that records scheduled work: these are the stage's and the display's doing, none of the controller's.
    scheduler.schedule("rehearsed-stage-\(display)", after: transition.duration) { [weak self] in self?.lift(display) }
    tickLater(display)
  }

  private func tickLater(_ display: DisplayID) {
    guard writers[display]?.isLogging == true else { return scheduler.cancel("rehearsed-tick-\(display)") }
    scheduler.schedule("rehearsed-tick-\(display)", after: 1.0 / 60) { [weak self] in
      self?.writers[display]?.tick()
      self?.tickLater(display)
    }
  }

  private func lift(_ display: DisplayID) {
    writers[display]?.lifting()
    scheduler.schedule("rehearsed-stage-\(display)", after: Self.liftDuration) { [weak self] in self?.drop(display) }
  }

  private func drop(_ display: DisplayID) {
    scheduler.cancel("rehearsed-stage-\(display)")
    scheduler.cancel("rehearsed-tick-\(display)")
    guard playing[display] != nil else { return }
    writers[display]?.comingDown()
    playing[display] = nil
  }

  /// Takes every stage down at once.
  private func finish() {
    for display in playing.keys.sorted() { drop(display) }
  }

  private func samples(_ stage: Playing) -> [StageLog.Sample] {
    let share = Transition.progress(after: (scheduler.now - stage.began) / stage.plan.duration)
    func mix(_ a: CGFloat, _ b: CGFloat) -> CGFloat { a + (b - a) * CGFloat(share) }
    return stage.plan.roads.map { road in
      let (a, b) = (road.from.frame, road.to.frame)
      return StageLog.Sample(
        road.window,
        CGRect(x: mix(a.minX, b.minX), y: mix(a.minY, b.minY), width: mix(a.width, b.width), height: mix(a.height, b.height)),
        opacity: road.from.opacity + (road.to.opacity - road.from.opacity) * share)
    }
  }
}
