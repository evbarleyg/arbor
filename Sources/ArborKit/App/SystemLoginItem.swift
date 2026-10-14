import Foundation
import ServiceManagement

/// Arbor itself as a login item (`SMAppService.mainApp`, macOS 13 and later). macOS remembers the app
/// bundle, wherever it is installed: `~/Applications` works like `/Applications`, and a new build copied over
/// the old one keeps the entry. See "Launch at login" in docs/INSTALL.md.
@MainActor
final class SystemLoginItem: LoginItem {
  var status: LoginItemStatus {
    guard Bundle.main.bundleURL.pathExtension == "app" else {
      return .unavailable("only Arbor.app can open at login, and this Arbor runs outside an app bundle")
    }
    switch SMAppService.mainApp.status {
    case .enabled: return .enabled
    case .requiresApproval: return .requiresApproval
    case .notRegistered, .notFound: return .disabled
    @unknown default: return .disabled
    }
  }

  func setEnabled(_ enabled: Bool) throws {
    if enabled {
      try SMAppService.mainApp.register()
    } else {
      try SMAppService.mainApp.unregister()
    }
  }
}
