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
      if let snapshot = self.windows[window]?.snapshot { events?.windowChanged(snapshot, userInitiated: true) }
    }
    afterEvents?()
    deliverEchoes()
  }
}
