import ArborCore
import CoreGraphics

/// Wraps any `OverlayPresenter`, as `RecordingWindowSystem` wraps the window system: what the user does with
/// an overlay is recorded on its way to the controller, and the drop preview on its way to the screen.
/// Scenes (tiles and seam handles at rest) follow from the layout and are not recorded.
///
/// **A new requirement of `OverlayPresenter` or `OverlayActions` must be forwarded here**; an action also needs a
/// `TraceLine`, or replays will not know that the user did it.
@MainActor
public final class RecordingOverlays: OverlayPresenter {
  public let inner: any OverlayPresenter
  public let recorder: TraceRecorder
  public weak var actions: (any OverlayActions)?

  public init(wrapping inner: any OverlayPresenter, recorder: TraceRecorder) {
    self.inner = inner
    self.recorder = recorder
    inner.actions = self
  }

  public func showDropPreview(_ frame: CGRect?) {
    if recorder.isRecording { recorder.record(.showDropPreview(frame)) }
    inner.showDropPreview(frame)
  }

  public func update(display: DisplayID, scene: OverlayScene) { inner.update(display: display, scene: scene) }

  public func removeAll() { inner.removeAll() }

  // Drawn, like scenes.
  public func animate(_ transition: Transition) { inner.animate(transition) }
  public func finishAnimations() { inner.finishAnimations() }
  /// Drawn, like scenes, and not recorded: its rows are made of window titles.
  public func showFinder(_ model: FinderModel?) { inner.showFinder(model) }
  public func showHeadsUp(_ model: HeadsUpModel?, on display: DisplayID) { inner.showHeadsUp(model, on: display) }
  public func showCheatSheet(_ model: CheatSheetModel?, on display: DisplayID) { inner.showCheatSheet(model, on: display) }
  public func showMinimap(_ model: MinimapModel?, on display: DisplayID) { inner.showMinimap(model, on: display) }
  /// Follows from the windows and displays, which are recorded.
  public func rehearse(_ rehearsal: Rehearsal) { inner.rehearse(rehearsal) }
}

extension RecordingOverlays: OverlayActions {
  public func tileActivated(display: DisplayID, node: NodeID) {
    guard recorder.isRecording else {
      actions?.tileActivated(display: display, node: node)
      return
    }
    recorder.stimulus(.tileActivated(display: display, node: node)) {
      actions?.tileActivated(display: display, node: node)
    }
  }

  /// Never thinned: each call is a step, and the steps add up.
  public func seamDragged(display: DisplayID, seam: Seam, by delta: CGFloat) {
    guard recorder.isRecording else {
      actions?.seamDragged(display: display, seam: seam, by: delta)
      return
    }
    recorder.stimulus(.seamDragged(display: display, seam: seam, by: delta)) {
      actions?.seamDragged(display: display, seam: seam, by: delta)
    }
  }

  /// What was typed into the finder stays in the finder. What was chosen is a number.
  public func finderChose(_ destination: FinderDestination) {
    recorder.action("finderChose", [TraceFinderDestination(destination)]) { actions?.finderChose(destination) }
  }

  public func finderDismissed() { recorder.action("finderDismissed") { actions?.finderDismissed() } }

  public func peekOutlineClicked(display: DisplayID) {
    recorder.action("peekOutlineClicked", [display]) { actions?.peekOutlineClicked(display: display) }
  }

  public func cheatSheetDismissed() {
    recorder.action("cheatSheetDismissed") { actions?.cheatSheetDismissed() }
  }

  /// Only passed on: the controller records every command it performs (Controller+Trace.swift), and a second
  /// line here would run it twice in a replay.
  @discardableResult
  public func perform(_ command: Command) -> CommandResult {
    actions?.perform(command) ?? .failure("Arbor is not running")
  }

  public func minimapClicked(display: DisplayID, at point: CGPoint) {
    recorder.action("minimapClicked", [display, Double(point.x), Double(point.y)]) {
      actions?.minimapClicked(display: display, at: point)
    }
  }
}
