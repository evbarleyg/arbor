// A stand-in for ServiceManagement (scripts/typecheck-mac/README.md). Never shipped, never run.
import Foundation

public class SMAppService: NSObject, @unchecked Sendable {
  public enum Status: Int, Sendable { case notRegistered = 0, enabled = 1, requiresApproval = 2, notFound = 3 }
  public class var mainApp: SMAppService { SMAppService() }
  public class func loginItem(identifier: String) -> SMAppService { SMAppService() }
  public class func agent(plistName: String) -> SMAppService { SMAppService() }
  public class func daemon(plistName: String) -> SMAppService { SMAppService() }
  public class func openSystemSettingsLoginItems() {}
  public var status: Status { .notRegistered }
  public func register() throws {}
  public func unregister() throws {}
  public func unregister() async throws {}
}
