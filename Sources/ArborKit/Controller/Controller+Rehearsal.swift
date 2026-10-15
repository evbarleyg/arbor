import ArborCore
import Foundation

/// The first motion after a start begins as promptly as every later one.
///
/// The presenter covers the display before the real windows move (Controller+Transitions.swift), so what it makes for
/// that is time between the key and the first move. The first dock of a day with nine apps' windows on screen waited
/// two seconds for it on a hosted Mac, and the second five milliseconds: everything is kept once made. So the
/// presenter hears ahead of time where the next motion may play and whose windows may be in it, when nobody waits:
/// after every layout, the one at the start among them, and when a window turns up.
///
/// One display or one app at a time, with a pause between them: Arbor's shortcuts, taps and socket are served on the thread
/// the presenter works on, and a key pressed meanwhile waits for one piece at most. A motion that comes before the end makes
/// what is missing itself, as it always did.
///
/// Nothing shows and no window is touched, so nothing moves before the person docks something.
extension Controller {
  struct Rehearsed {
    /// What the presenter has been told of, or will be as soon as its turn comes.
    var displays: Set<DisplayID> = []
    var apps: Set<Rehearsal.App> = []
    /// The pieces still to be handed out.
    var waiting: [Rehearsal] = []
    /// A motion is under way until then, and none is handed out.
    var quietUntil = Date.distantPast
  }

  /// Long enough for whatever else waits for the main thread to have its turn.
  public static let pauseBetweenPieces = 0.01

  func rehearseNextMotion() {
    // Without motion there is nothing to be ready for, and it is not paid for.
    guard isRunning, settings.motionDuration > 0 else { return }
    let displays = Set(displays.map(\.id))
    // Also of windows that are minimized or hidden: coming back is a motion, and they are in it.
    let apps = Set(windows.values.map { Rehearsal.App(pid: $0.pid, bundleID: $0.bundleID) })
    guard displays != rehearsed.displays || apps != rehearsed.apps else { return }
    let news =
      displays.subtracting(rehearsed.displays).sorted().map { Rehearsal(displays: [$0], apps: []) }
      + apps.subtracting(rehearsed.apps).sorted { ($0.pid, $0.bundleID ?? "") < ($1.pid, $1.bundleID ?? "") }
      .map { Rehearsal(displays: [], apps: [$0]) }
    // What has gone is forgotten: a display that comes back has a new stage, and a process number a new owner.
    rehearsed.displays = displays
    rehearsed.apps = apps
    rehearsed.waiting = (rehearsed.waiting + news).filter { displays.isSuperset(of: $0.displays) && apps.isSuperset(of: $0.apps) }
    handOutPieces(after: Self.pauseBetweenPieces)
  }

  /// Everything is said again: the presenter may have let go of what it had, or had no use for it when it was told.
  /// It skips what it still has. The app calls this when macOS's Reduce Motion changes.
  public func rehearseAfresh() {
    forgetRehearsal()
    rehearseNextMotion()
  }

  /// Arbor stops: nothing is got ready for an Arbor that shows nothing.
  func forgetRehearsal() {
    scheduler.cancel("rehearsal")
    rehearsed = Rehearsed()
  }

  /// A motion has begun, or has been corrected. The timer that ends it runs on the thread a piece would keep busy.
  func rehearsalWaits(for motion: Double) {
    rehearsed.quietUntil = now().addingTimeInterval(motion + 0.2)
    handOutPieces(after: Self.pauseBetweenPieces)
  }

  private func handOutPieces(after pause: Double) {
    guard !rehearsed.waiting.isEmpty else { return scheduler.cancel("rehearsal") }
    scheduler.schedule("rehearsal", after: max(pause, rehearsed.quietUntil.timeIntervalSince(now()))) { [weak self] in
      guard let self, self.isRunning, !self.rehearsed.waiting.isEmpty else { return }
      self.overlays.rehearse(self.rehearsed.waiting.removeFirst())
      self.handOutPieces(after: Self.pauseBetweenPieces)
    }
  }
}
