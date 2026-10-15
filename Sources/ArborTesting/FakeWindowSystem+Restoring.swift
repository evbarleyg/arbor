import ArborCore
import ArborKit

// MARK: Bringing windows back

extension FakeWindowSystem {
  public func unhideApp(pid: Int32) { setHidden(pid: pid, false) }

  /// Delivers the reports `restoresLate` held back.
  public func finishRestoring() {
    let windows = lateRestores
    lateRestores.removeAll()
    for window in windows {
      // A window out of the Dock is reported as somebody's doing, one whose app shows again is not (`setMinimized`, `setHidden`).
      let shown = shownLate.remove(window) != nil
      if let snapshot = self.windows[window]?.snapshot { events?.windowChanged(snapshot, userInitiated: !shown) }
    }
    afterEvents?()
    deliverEchoes()
  }
}
