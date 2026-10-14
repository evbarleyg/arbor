// What a Mac's Foundation, Darwin and ObjectiveC modules have and Linux's do not (scripts/typecheck-mac/README.md). Never shipped, never run.
// prepare.py imports this module into every file, because on a Mac `import Foundation` (or AppKit, or Carbon) brings all of it.
@_exported import CMacTypes
@_exported import Foundation
// URLSession and company, which are part of Foundation on a Mac.
@_exported import FoundationNetworking

// MARK: ObjectiveC

/// `#selector(x)` becomes `Selector(checked: x)` (prepare.py), so that the method's name and labels are still checked.
public struct Selector: ExpressibleByStringLiteral, Hashable, Sendable, CustomStringConvertible {
  public init(_ string: String) {}
  public init(stringLiteral value: String) {}
  public init<Method>(checked method: Method) {}
  public var description: String { "" }
}
public func NSSelectorFromString(_ name: String) -> Selector { Selector(name) }
public func NSStringFromSelector(_ selector: Selector) -> String { "" }
public func autoreleasepool<Result>(invoking body: () throws -> Result) rethrows -> Result { try body() }

// MARK: Darwin

public var noErr: OSStatus { 0 }
// Darwin's are computed properties; glibc's are global variables, which Swift 6 lets nobody touch. prepare.py writes the module's name in front.
public var stdin: UnsafeMutablePointer<FILE> { fatalError() }
public var stdout: UnsafeMutablePointer<FILE> { fatalError() }
public var stderr: UnsafeMutablePointer<FILE> { fatalError() }

public let SO_NOSIGPIPE: Int32 = 0x1022
public let O_EVTONLY: Int32 = 0x8000
public let O_EXLOCK: Int32 = 0x20
public let O_SHLOCK: Int32 = 0x10
public let O_SYMLINK: Int32 = 0x20_0000
public let LOCAL_PEERPID: Int32 = 2
public let LOCAL_PEERCRED: Int32 = 1
public let SOL_LOCAL: Int32 = 0
public let PROC_PIDPATHINFO_MAXSIZE: Int32 = 4096
public func getpeereid(_ socket: Int32, _ euid: UnsafeMutablePointer<uid_t>!, _ egid: UnsafeMutablePointer<gid_t>!) -> Int32 { -1 }
public func proc_pidpath(_ pid: Int32, _ buffer: UnsafeMutableRawPointer!, _ buffersize: UInt32) -> Int32 { 0 }
public func proc_name(_ pid: Int32, _ buffer: UnsafeMutableRawPointer!, _ buffersize: UInt32) -> Int32 { 0 }
public struct mach_timebase_info_data_t {
  public var numer: UInt32 = 1
  public var denom: UInt32 = 1
  public init() {}
  public init(numer: UInt32, denom: UInt32) {}
}
public typealias kern_return_t = Int32
public let KERN_SUCCESS: kern_return_t = 0
public func mach_absolute_time() -> UInt64 { 0 }
public func mach_continuous_time() -> UInt64 { 0 }
@discardableResult public func mach_timebase_info(_ info: UnsafeMutablePointer<mach_timebase_info_data_t>!) -> kern_return_t { 0 }
public let CLOCK_UPTIME_RAW = clockid_t(8)
public let CLOCK_MONOTONIC_RAW_APPROX = clockid_t(5)
public func clock_gettime_nsec_np(_ clock: clockid_t) -> UInt64 { 0 }
@discardableResult public func pthread_threadid_np(_ thread: pthread_t?, _ id: UnsafeMutablePointer<UInt64>!) -> Int32 { 0 }
public func pthread_main_np() -> Int32 { 1 }
public func sysctlbyname(
  _ name: UnsafePointer<CChar>!, _ old: UnsafeMutableRawPointer!, _ oldSize: UnsafeMutablePointer<Int>!, _ new: UnsafeMutableRawPointer!,
  _ newSize: Int
) -> Int32 { -1 }
public func arc4random() -> UInt32 { 0 }
public func arc4random_uniform(_ bound: UInt32) -> UInt32 { 0 }

// MARK: Key-value observing, as Foundation's _KeyValueCodingAndObserving gives it on macOS

public struct NSKeyValueObservingOptions: OptionSet, Sendable {
  public let rawValue: UInt
  public init(rawValue: UInt) { self.rawValue = rawValue }
  public static let new = NSKeyValueObservingOptions(rawValue: 1)
  public static let old = NSKeyValueObservingOptions(rawValue: 2)
  public static let initial = NSKeyValueObservingOptions(rawValue: 4)
  public static let prior = NSKeyValueObservingOptions(rawValue: 8)
}
public enum NSKeyValueChange: UInt, Sendable { case setting = 1, insertion = 2, removal = 3, replacement = 4 }
public struct NSKeyValueObservedChange<Value> {
  public let kind: NSKeyValueChange
  public let newValue: Value?
  public let oldValue: Value?
  public let isPrior: Bool
}
public final class NSKeyValueObservation: NSObject, @unchecked Sendable {
  public func invalidate() {}
}
public protocol _KeyValueCodingAndObserving {}
extension NSObject: _KeyValueCodingAndObserving {}
extension _KeyValueCodingAndObserving {
  public func observe<Value>(
    _ keyPath: KeyPath<Self, Value>, options: NSKeyValueObservingOptions = [],
    changeHandler: @escaping @Sendable (Self, NSKeyValueObservedChange<Value>) -> Void
  ) -> NSKeyValueObservation { NSKeyValueObservation() }
}

// MARK: Foundation classes Linux goes without

public class NSAppleEventDescriptor: NSObject {
  public var stringValue: String? { nil }
  public var int32Value: Int32 { 0 }
  public var eventClass: AEEventClass { 0 }
  public var eventID: AEEventID { 0 }
  public func paramDescriptor(forKeyword keyword: AEKeyword) -> NSAppleEventDescriptor? { nil }
  public func attributeDescriptor(forKeyword keyword: AEKeyword) -> NSAppleEventDescriptor? { nil }
}
public class NSAppleEventManager: NSObject {
  public class func shared() -> NSAppleEventManager { NSAppleEventManager() }
  public func setEventHandler(
    _ handler: Any, andSelector handleEventSelector: Selector, forEventClass eventClass: AEEventClass, andEventID eventID: AEEventID) {}
  public func removeEventHandler(forEventClass eventClass: AEEventClass, andEventID eventID: AEEventID) {}
  public var currentAppleEvent: NSAppleEventDescriptor? { nil }
}
public class DistributedNotificationCenter: NotificationCenter, @unchecked Sendable {
  public enum SuspensionBehavior: UInt, Sendable { case drop = 1, coalesce = 2, hold = 3, deliverImmediately = 4 }
  public class func `default`() -> DistributedNotificationCenter { DistributedNotificationCenter() }
  public func addObserver(
    _ observer: Any, selector: Selector, name: NSNotification.Name?, object: String?, suspensionBehavior: SuspensionBehavior) {}
  public func addObserver(_ observer: Any, selector: Selector, name: NSNotification.Name?, object: String?) {}
  public func postNotificationName(_ name: NSNotification.Name, object: String?, userInfo: [AnyHashable: Any]?, deliverImmediately: Bool) {}
}
extension NotificationCenter {
  public func addObserver(_ observer: Any, selector: Selector, name: NSNotification.Name?, object: Any?) {}
  public func removeObserver(_ observer: Any, name: NSNotification.Name?, object: Any?) {}
}
extension Timer {
  public class func scheduledTimer(timeInterval: TimeInterval, target: Any, selector: Selector, userInfo: Any?, repeats: Bool) -> Timer {
    fatalError()
  }
}
extension NSObject {
  public func perform(_ selector: Selector, with argument: Any?, afterDelay delay: TimeInterval) {}
  public class func cancelPreviousPerformRequests(withTarget target: Any) {}
  public func responds(to selector: Selector!) -> Bool { false }
}
extension ProcessInfo {
  public enum ThermalState: Int, Sendable { case nominal = 0, fair = 1, serious = 2, critical = 3 }
  public var thermalState: ThermalState { .nominal }
  public var isLowPowerModeEnabled: Bool { false }
  public struct ActivityOptions: OptionSet, Sendable {
    public let rawValue: UInt64
    public init(rawValue: UInt64) { self.rawValue = rawValue }
    public static let userInitiated = ActivityOptions(rawValue: 0x00FF_FFFF)
    public static let userInitiatedAllowingIdleSystemSleep = ActivityOptions(rawValue: 0x00EF_FFFF)
    public static let background = ActivityOptions(rawValue: 0xFF)
    public static let latencyCritical = ActivityOptions(rawValue: 0xFF_0000_0000)
    public static let idleSystemSleepDisabled = ActivityOptions(rawValue: 1 << 20)
    public static let suddenTerminationDisabled = ActivityOptions(rawValue: 1 << 14)
    public static let automaticTerminationDisabled = ActivityOptions(rawValue: 1 << 15)
  }
  public func beginActivity(options: ActivityOptions, reason: String) -> any NSObjectProtocol { NSObject() }
  public func endActivity(_ activity: any NSObjectProtocol) {}
  public func disableSuddenTermination() {}
  public func enableSuddenTermination() {}
  public func disableAutomaticTermination(_ reason: String) {}
  public func enableAutomaticTermination(_ reason: String) {}
}
open class UndoManager: NSObject {
  open var canUndo: Bool { false }
  open var canRedo: Bool { false }
  open var isUndoing: Bool { false }
  open var isRedoing: Bool { false }
  open var levelsOfUndo = 0
  open func undo() {}
  open func redo() {}
  open func beginUndoGrouping() {}
  open func endUndoGrouping() {}
  open func removeAllActions() {}
  open func setActionName(_ actionName: String) {}
  open func registerUndo<Target: AnyObject>(withTarget target: Target, handler: @escaping (Target) -> Void) {}
}
/// Objective-C's BOOL as C functions hand it out.
public struct DarwinBoolean: ExpressibleByBooleanLiteral, Sendable, Equatable {
  public init(_ value: Bool) { boolValue = value }
  public init(booleanLiteral value: Bool) { boolValue = value }
  public let boolValue: Bool
}
