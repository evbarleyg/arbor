import ArborCore
import ArborKit

/// Apps that `summon` asks to open. In a file of its own so that it stays out of the way of other additions.
extension FakeWindowSystem {
  public func openApplication(_ app: String) -> Bool {
    guard !missingApps.contains(app) else { return false }
    openRequests.append(app)
    return true
  }
}
