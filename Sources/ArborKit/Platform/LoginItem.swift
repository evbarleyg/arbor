/// Whether macOS opens Arbor when the user logs in.
public enum LoginItemStatus: Equatable, Sendable {
  case enabled
  case disabled
  /// Arbor asked, but the user has switched it off in System Settings, and only they can switch it
  /// back on there.
  case requiresApproval
  /// This copy of Arbor cannot be opened at login, and why.
  case unavailable(String)
}

/// Arbor's entry in macOS's list of apps to open at login. `SystemLoginItem` is the real one
/// (ServiceManagement); `FakeLoginItem` stands in for it in tests.
@MainActor
public protocol LoginItem: AnyObject {
  var status: LoginItemStatus { get }
  func setEnabled(_ enabled: Bool) throws
}
