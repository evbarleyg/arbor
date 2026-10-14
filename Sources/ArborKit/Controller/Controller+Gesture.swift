import ArborCore

extension Controller {
  /// Takes what the fingers have done since the last call (docs/features/F16-continuous-zoom-and-pan.md).
  /// With `continuousZoom` on, the gesture taps call this on the main actor, at most once per burst of
  /// events: one `began`, any number of `changed`, one `ended` or `cancelled`, each with the movement
  /// since the update before it. Tests and arbor-sim can call it with plain values.
  ///
  /// This is where F16's model goes: a view that scales and pans with the fingers and settles when they
  /// lift. Until it does, a streamed pinch steps a level per `pinchThreshold`, as F03's does,
  /// and the pan is ignored, so that turning the setting on early changes nothing to look at.
  public func gesture(_ update: GestureUpdate) {
    // A held view follows no fingers (Controller+Hold.swift). The taps are gone then; one that was under way is not.
    guard isRunning, holdLevel != .view else {
      gestureSteps.reset()
      return
    }
    gestureSteps.threshold = settings.pinchThreshold
    let phase: GestureInterpreter.Phase =
      switch update.phase {
      case .began: .began
      case .changed: .changed
      case .ended: .ended
      case .cancelled: .cancelled
      }
    for command in gestureSteps.feed(phase, magnification: update.magnification).commands {
      _ = perform(command, from: .gesture)
    }
  }
}
