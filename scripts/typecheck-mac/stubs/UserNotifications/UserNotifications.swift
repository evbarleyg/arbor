// A stand-in for UserNotifications (scripts/typecheck-mac/README.md). Never shipped, never run.
import Foundation

public struct UNAuthorizationOptions: OptionSet, Sendable {
  public let rawValue: UInt
  public init(rawValue: UInt) { self.rawValue = rawValue }
  public static let badge = UNAuthorizationOptions(rawValue: 1)
  public static let sound = UNAuthorizationOptions(rawValue: 2)
  public static let alert = UNAuthorizationOptions(rawValue: 4)
  public static let provisional = UNAuthorizationOptions(rawValue: 64)
}
public enum UNAuthorizationStatus: Int, Sendable { case notDetermined = 0, denied, authorized, provisional }
open class UNNotificationSettings: NSObject, @unchecked Sendable {
  open var authorizationStatus: UNAuthorizationStatus { .notDetermined }
}
open class UNNotificationSound: NSObject, @unchecked Sendable {
  open class var `default`: UNNotificationSound { UNNotificationSound() }
}
open class UNNotificationContent: NSObject {
  open var title: String { "" }
  open var subtitle: String { "" }
  open var body: String { "" }
  open var userInfo: [AnyHashable: Any] { [:] }
}
open class UNMutableNotificationContent: UNNotificationContent {
  open override var title: String {
    get { "" }
    set {}
  }
  open override var subtitle: String {
    get { "" }
    set {}
  }
  open override var body: String {
    get { "" }
    set {}
  }
  open override var userInfo: [AnyHashable: Any] {
    get { [:] }
    set {}
  }
  open var sound: UNNotificationSound?
  open var categoryIdentifier = ""
  open var threadIdentifier = ""
}
open class UNNotificationTrigger: NSObject {
  open var repeats: Bool { false }
}
open class UNTimeIntervalNotificationTrigger: UNNotificationTrigger {
  public convenience init(timeInterval: TimeInterval, repeats: Bool) { self.init() }
}
open class UNNotificationRequest: NSObject {
  public convenience init(identifier: String, content: UNNotificationContent, trigger: UNNotificationTrigger?) { self.init() }
  open var identifier: String { "" }
  open var content: UNNotificationContent { UNNotificationContent() }
}
open class UNNotification: NSObject {
  open var date: Date { Date() }
  open var request: UNNotificationRequest { UNNotificationRequest() }
}
open class UNNotificationResponse: NSObject {
  open var notification: UNNotification { UNNotification() }
  open var actionIdentifier: String { "" }
}
public struct UNNotificationPresentationOptions: OptionSet, Sendable {
  public let rawValue: UInt
  public init(rawValue: UInt) { self.rawValue = rawValue }
  public static let badge = UNNotificationPresentationOptions(rawValue: 1)
  public static let sound = UNNotificationPresentationOptions(rawValue: 2)
  public static let list = UNNotificationPresentationOptions(rawValue: 8)
  public static let banner = UNNotificationPresentationOptions(rawValue: 16)
}
public protocol UNUserNotificationCenterDelegate: NSObjectProtocol {
  func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions
  func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async
}
extension UNUserNotificationCenterDelegate {
  public func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async
    -> UNNotificationPresentationOptions
  { [] }
  public func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {}
}
open class UNUserNotificationCenter: NSObject, @unchecked Sendable {
  open class func current() -> UNUserNotificationCenter { UNUserNotificationCenter() }
  open weak var delegate: (any UNUserNotificationCenterDelegate)?
  open func requestAuthorization(options: UNAuthorizationOptions = [], completionHandler: @escaping @Sendable (Bool, (any Error)?) -> Void) {}
  open func requestAuthorization(options: UNAuthorizationOptions = []) async throws -> Bool { false }
  open func getNotificationSettings(completionHandler: @escaping @Sendable (UNNotificationSettings) -> Void) {}
  open func notificationSettings() async -> UNNotificationSettings { UNNotificationSettings() }
  open func add(_ request: UNNotificationRequest, withCompletionHandler completionHandler: (@Sendable ((any Error)?) -> Void)? = nil) {}
  open func add(_ request: UNNotificationRequest) async throws {}
  open func removePendingNotificationRequests(withIdentifiers identifiers: [String]) {}
  open func removeAllPendingNotificationRequests() {}
  open func removeDeliveredNotifications(withIdentifiers identifiers: [String]) {}
  open func removeAllDeliveredNotifications() {}
}
