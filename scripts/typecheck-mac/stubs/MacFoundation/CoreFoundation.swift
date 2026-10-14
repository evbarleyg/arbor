// A stand-in for Core Foundation, which a Mac's Foundation brings along (scripts/typecheck-mac/README.md). Never shipped, never run.

public typealias CFTypeRef = AnyObject
public typealias CFTypeID = UInt
public typealias CFIndex = Int
public typealias CFOptionFlags = UInt
public typealias CFHashCode = UInt
public typealias CFTimeInterval = Double
public typealias CFAbsoluteTime = Double
// Foundation's classes, so that `as` bridges as on the Mac.
public typealias CFString = NSString
public typealias CFDictionary = NSDictionary
public typealias CFMutableDictionary = NSMutableDictionary
public typealias CFArray = NSArray
public typealias CFMutableArray = NSMutableArray
public typealias CFData = NSData
public typealias CFMutableData = NSMutableData
public typealias CFNumber = NSNumber
public typealias CFURL = NSURL
public typealias CFDate = NSDate
public typealias CFError = NSError
public final class CFBoolean: NSObject, @unchecked Sendable {}
public final class CFNull: NSObject, @unchecked Sendable {}
public final class CFUUID: NSObject {}
public final class CFAllocator: NSObject {}
public final class CFMachPort: NSObject {}
public final class CFRunLoop: NSObject {}
public final class CFRunLoopSource: NSObject {}
public final class CFRunLoopTimer: NSObject {}
public final class CFRunLoopObserver: NSObject {}
public nonisolated(unsafe) let kCFAllocatorDefault: CFAllocator! = nil
public let kCFBooleanTrue: CFBoolean! = CFBoolean()
public let kCFBooleanFalse: CFBoolean! = CFBoolean()
public let kCFNull: CFNull! = CFNull()
public func CFGetTypeID(_ cf: CFTypeRef!) -> CFTypeID { 0 }
public func CFBooleanGetTypeID() -> CFTypeID { 1 }
public func CFArrayGetTypeID() -> CFTypeID { 2 }
public func CFStringGetTypeID() -> CFTypeID { 3 }
public func CFNumberGetTypeID() -> CFTypeID { 4 }
public func CFDictionaryGetTypeID() -> CFTypeID { 5 }
public func CFDataGetTypeID() -> CFTypeID { 6 }
public func CFNullGetTypeID() -> CFTypeID { 7 }
public func CFURLGetTypeID() -> CFTypeID { 8 }
public func CFBooleanGetValue(_ boolean: CFBoolean!) -> Bool { false }
public func CFEqual(_ cf1: CFTypeRef!, _ cf2: CFTypeRef!) -> Bool { false }
public func CFHash(_ cf: CFTypeRef!) -> CFHashCode { 0 }
public func CFCopyDescription(_ cf: CFTypeRef!) -> CFString! { nil }
public func CFUUIDCreateString(_ alloc: CFAllocator!, _ uuid: CFUUID!) -> CFString! { nil }
public func CFUUIDCreateFromString(_ alloc: CFAllocator!, _ uuidStr: CFString!) -> CFUUID! { nil }
public func CFAbsoluteTimeGetCurrent() -> CFAbsoluteTime { 0 }
public func CFDataGetBytePtr(_ theData: CFData!) -> UnsafePointer<UInt8>! { nil }
public func CFDataGetLength(_ theData: CFData!) -> CFIndex { 0 }
public func CFArrayGetCount(_ theArray: CFArray!) -> CFIndex { 0 }
public func CFArrayGetValueAtIndex(_ theArray: CFArray!, _ idx: CFIndex) -> UnsafeRawPointer! { nil }
public func CFDictionaryGetCount(_ theDict: CFDictionary!) -> CFIndex { 0 }
public typealias CFPropertyList = CFTypeRef
public func CFPreferencesCopyAppValue(_ key: CFString, _ applicationID: CFString) -> CFPropertyList? { nil }

public struct CFRunLoopMode: RawRepresentable, Hashable, @unchecked Sendable {
  public let rawValue: CFString
  public init(rawValue: CFString) { self.rawValue = rawValue }
  public init(_ rawValue: CFString) { self.rawValue = rawValue }
  public static let defaultMode: CFRunLoopMode! = CFRunLoopMode("default")
  public static let commonModes: CFRunLoopMode! = CFRunLoopMode("common")
}
public enum CFRunLoopRunResult: Int32, Sendable { case finished = 1, stopped = 2, timedOut = 3, handledSource = 4 }
public struct CFRunLoopActivity: OptionSet, Sendable {
  public let rawValue: CFOptionFlags
  public init(rawValue: CFOptionFlags) { self.rawValue = rawValue }
  public static let entry = CFRunLoopActivity(rawValue: 1)
  public static let beforeTimers = CFRunLoopActivity(rawValue: 2)
  public static let beforeSources = CFRunLoopActivity(rawValue: 4)
  public static let beforeWaiting = CFRunLoopActivity(rawValue: 32)
  public static let afterWaiting = CFRunLoopActivity(rawValue: 64)
  public static let exit = CFRunLoopActivity(rawValue: 128)
  public static let allActivities = CFRunLoopActivity(rawValue: 0x0FFF_FFFF)
}
public func CFRunLoopGetMain() -> CFRunLoop! { nil }
public func CFRunLoopGetCurrent() -> CFRunLoop! { nil }
public func CFRunLoopRun() {}
@discardableResult public func CFRunLoopRunInMode(_ mode: CFRunLoopMode!, _ seconds: CFTimeInterval, _ returnAfterSourceHandled: Bool)
  -> CFRunLoopRunResult
{ .finished }
public func CFRunLoopStop(_ rl: CFRunLoop!) {}
public func CFRunLoopWakeUp(_ rl: CFRunLoop!) {}
public func CFRunLoopPerformBlock(_ rl: CFRunLoop!, _ mode: CFTypeRef!, _ block: (() -> Void)!) {}
public func CFRunLoopAddSource(_ rl: CFRunLoop!, _ source: CFRunLoopSource!, _ mode: CFRunLoopMode!) {}
public func CFRunLoopRemoveSource(_ rl: CFRunLoop!, _ source: CFRunLoopSource!, _ mode: CFRunLoopMode!) {}
public func CFRunLoopContainsSource(_ rl: CFRunLoop!, _ source: CFRunLoopSource!, _ mode: CFRunLoopMode!) -> Bool { false }
public func CFRunLoopSourceInvalidate(_ source: CFRunLoopSource!) {}
public func CFRunLoopAddTimer(_ rl: CFRunLoop!, _ timer: CFRunLoopTimer!, _ mode: CFRunLoopMode!) {}
public func CFRunLoopRemoveTimer(_ rl: CFRunLoop!, _ timer: CFRunLoopTimer!, _ mode: CFRunLoopMode!) {}
public func CFRunLoopTimerInvalidate(_ timer: CFRunLoopTimer!) {}
public func CFRunLoopTimerCreateWithHandler(
  _ allocator: CFAllocator!, _ fireDate: CFAbsoluteTime, _ interval: CFTimeInterval, _ flags: CFOptionFlags, _ order: CFIndex,
  _ block: ((CFRunLoopTimer?) -> Void)!
) -> CFRunLoopTimer! { nil }
public func CFRunLoopObserverCreateWithHandler(
  _ allocator: CFAllocator!, _ activities: CFOptionFlags, _ repeats: Bool, _ order: CFIndex,
  _ block: ((CFRunLoopObserver?, CFRunLoopActivity) -> Void)!
) -> CFRunLoopObserver! { nil }
public func CFRunLoopAddObserver(_ rl: CFRunLoop!, _ observer: CFRunLoopObserver!, _ mode: CFRunLoopMode!) {}
public func CFRunLoopRemoveObserver(_ rl: CFRunLoop!, _ observer: CFRunLoopObserver!, _ mode: CFRunLoopMode!) {}
public func CFMachPortCreateRunLoopSource(_ allocator: CFAllocator!, _ port: CFMachPort!, _ order: CFIndex) -> CFRunLoopSource! { nil }
public func CFMachPortInvalidate(_ port: CFMachPort!) {}
public func CFMachPortIsValid(_ port: CFMachPort!) -> Bool { false }

public final class CFNotificationCenter: NSObject {}
public struct CFNotificationName: RawRepresentable, Hashable, @unchecked Sendable {
  public let rawValue: CFString
  public init(rawValue: CFString) { self.rawValue = rawValue }
  public init(_ rawValue: CFString) { self.rawValue = rawValue }
}
public enum CFNotificationSuspensionBehavior: CFIndex, Sendable { case drop = 1, coalesce = 2, hold = 3, deliverImmediately = 4 }
/// `@convention(c)` on the Mac: it must not capture anything. See the README.
public typealias CFNotificationCallback = (
  CFNotificationCenter?, UnsafeMutableRawPointer?, CFNotificationName?, UnsafeRawPointer?, CFDictionary?
) -> Void
public func CFNotificationCenterGetDistributedCenter() -> CFNotificationCenter! { nil }
public func CFNotificationCenterGetDarwinNotifyCenter() -> CFNotificationCenter! { nil }
public func CFNotificationCenterGetLocalCenter() -> CFNotificationCenter! { nil }
public func CFNotificationCenterAddObserver(
  _ center: CFNotificationCenter!, _ observer: UnsafeRawPointer!, _ callBack: CFNotificationCallback!, _ name: CFString!,
  _ object: UnsafeRawPointer!, _ suspensionBehavior: CFNotificationSuspensionBehavior) {}
public func CFNotificationCenterRemoveObserver(
  _ center: CFNotificationCenter!, _ observer: UnsafeRawPointer!, _ name: CFNotificationName!, _ object: UnsafeRawPointer!) {}
public func CFNotificationCenterRemoveEveryObserver(_ center: CFNotificationCenter!, _ observer: UnsafeRawPointer!) {}
