// A stand-in for the os module: the unified log and the unfair lock (scripts/typecheck-mac/README.md). Never shipped, never run.
import Foundation

public struct OSLogPrivacy: Sendable {
  public enum Mask: Sendable { case hash, none }
  public static var `public`: OSLogPrivacy { OSLogPrivacy() }
  public static var `private`: OSLogPrivacy { OSLogPrivacy() }
  public static var sensitive: OSLogPrivacy { OSLogPrivacy() }
  public static var auto: OSLogPrivacy { OSLogPrivacy() }
  public static func `private`(mask: Mask) -> OSLogPrivacy { OSLogPrivacy() }
  public static func sensitive(mask: Mask) -> OSLogPrivacy { OSLogPrivacy() }
  public static func auto(mask: Mask) -> OSLogPrivacy { OSLogPrivacy() }
}
public struct OSLogStringAlignment: Sendable {
  public static var none: OSLogStringAlignment { OSLogStringAlignment() }
  public static func right(columns: @autoclosure @escaping () -> Int) -> OSLogStringAlignment { OSLogStringAlignment() }
  public static func left(columns: @autoclosure @escaping () -> Int) -> OSLogStringAlignment { OSLogStringAlignment() }
}
public struct OSLogIntegerFormatting: Sendable {
  public static var decimal: OSLogIntegerFormatting { OSLogIntegerFormatting() }
  public static var hex: OSLogIntegerFormatting { OSLogIntegerFormatting() }
  public static var octal: OSLogIntegerFormatting { OSLogIntegerFormatting() }
}
public struct OSLogFloatFormatting: Sendable {
  public static var fixed: OSLogFloatFormatting { OSLogFloatFormatting() }
  public static func fixed(precision: @autoclosure @escaping () -> Int) -> OSLogFloatFormatting { OSLogFloatFormatting() }
}
public struct OSLogInterpolation: StringInterpolationProtocol {
  public init(literalCapacity: Int, interpolationCount: Int) {}
  public mutating func appendLiteral(_ literal: String) {}
  public mutating func appendInterpolation(
    _ value: @autoclosure @escaping () -> String, align: OSLogStringAlignment = .none, privacy: OSLogPrivacy = .auto) {}
  public mutating func appendInterpolation<T: FixedWidthInteger>(
    _ value: @autoclosure @escaping () -> T, format: OSLogIntegerFormatting = .decimal, align: OSLogStringAlignment = .none,
    privacy: OSLogPrivacy = .auto) {}
  public mutating func appendInterpolation(
    _ value: @autoclosure @escaping () -> Double, format: OSLogFloatFormatting = .fixed, align: OSLogStringAlignment = .none,
    privacy: OSLogPrivacy = .auto) {}
  public mutating func appendInterpolation(
    _ value: @autoclosure @escaping () -> Float, format: OSLogFloatFormatting = .fixed, align: OSLogStringAlignment = .none,
    privacy: OSLogPrivacy = .auto) {}
  public mutating func appendInterpolation(_ value: @autoclosure @escaping () -> Bool, privacy: OSLogPrivacy = .auto) {}
  public mutating func appendInterpolation<T: CustomStringConvertible>(
    _ value: @autoclosure @escaping () -> T, align: OSLogStringAlignment = .none, privacy: OSLogPrivacy = .auto) {}
  public mutating func appendInterpolation(_ value: @autoclosure @escaping () -> NSObject, privacy: OSLogPrivacy = .auto) {}
  public mutating func appendInterpolation(
    _ value: @autoclosure @escaping () -> Any.Type, align: OSLogStringAlignment = .none, privacy: OSLogPrivacy = .auto) {}
}
/// Only a literal makes one, as on the Mac: a `String` variable passed to `Logger.info` is an error there and here.
public struct OSLogMessage: ExpressibleByStringInterpolation {
  public init(stringInterpolation: OSLogInterpolation) {}
  public init(stringLiteral value: String) {}
}
public struct OSLogType: Equatable, RawRepresentable, Sendable {
  public let rawValue: UInt8
  public init(rawValue: UInt8) { self.rawValue = rawValue }
  public init(_ rawValue: UInt8) { self.rawValue = rawValue }
  public static let `default` = OSLogType(0)
  public static let info = OSLogType(1)
  public static let debug = OSLogType(2)
  public static let error = OSLogType(16)
  public static let fault = OSLogType(17)
}
public final class OSLog: NSObject, @unchecked Sendable {
  public static let `default` = OSLog()
  public static let disabled = OSLog()
  public struct Category: Sendable {
    public let rawValue: String
    public static let pointsOfInterest = Category(rawValue: "PointsOfInterest")
    public static let dynamicTracing = Category(rawValue: "DynamicTracing")
  }
  override init() {}
  public convenience init(subsystem: String, category: String) { self.init() }
  public convenience init(subsystem: String, category: Category) { self.init() }
  public var signpostsEnabled: Bool { false }
  public func isEnabled(type: OSLogType) -> Bool { false }
}
public struct Logger: @unchecked Sendable {
  public init() {}
  public init(subsystem: String, category: String) {}
  public init(_ logObj: OSLog) {}
  public func log(_ message: OSLogMessage) {}
  public func log(level: OSLogType, _ message: OSLogMessage) {}
  public func trace(_ message: OSLogMessage) {}
  public func debug(_ message: OSLogMessage) {}
  public func info(_ message: OSLogMessage) {}
  public func notice(_ message: OSLogMessage) {}
  public func warning(_ message: OSLogMessage) {}
  public func error(_ message: OSLogMessage) {}
  public func critical(_ message: OSLogMessage) {}
  public func fault(_ message: OSLogMessage) {}
}

public struct OSSignpostID: Sendable, Equatable {
  public let rawValue: UInt64
  public static let exclusive = OSSignpostID(0xEEEE_B0B5_B2B2_EEEE)
  public static let invalid = OSSignpostID(UInt64.max)
  public static let null = OSSignpostID(0)
  public init(_ value: UInt64) { rawValue = value }
  public init(log: OSLog) { rawValue = 0 }
  public init(log: OSLog, object: AnyObject) { rawValue = 0 }
}
public final class OSSignpostIntervalState: @unchecked Sendable {}
public struct SignpostMetadata: ExpressibleByStringInterpolation {
  public init(stringInterpolation: OSLogInterpolation) {}
  public init(stringLiteral value: String) {}
}
public struct OSSignposter: @unchecked Sendable {
  public init() {}
  public init(subsystem: String, category: String) {}
  public init(subsystem: String, category: OSLog.Category) {}
  public init(logger: Logger) {}
  public init(logHandle: OSLog) {}
  public static var disabled: OSSignposter { OSSignposter() }
  public var isEnabled: Bool { false }
  public func makeSignpostID() -> OSSignpostID { .exclusive }
  public func makeSignpostID(from object: AnyObject) -> OSSignpostID { .exclusive }
  public func beginInterval(_ name: StaticString, id: OSSignpostID = .exclusive) -> OSSignpostIntervalState { OSSignpostIntervalState() }
  public func beginInterval(_ name: StaticString, id: OSSignpostID = .exclusive, _ message: SignpostMetadata) -> OSSignpostIntervalState {
    OSSignpostIntervalState()
  }
  public func endInterval(_ name: StaticString, _ state: OSSignpostIntervalState) {}
  public func endInterval(_ name: StaticString, _ state: OSSignpostIntervalState, _ message: SignpostMetadata) {}
  public func emitEvent(_ name: StaticString, id: OSSignpostID = .exclusive) {}
  public func emitEvent(_ name: StaticString, id: OSSignpostID = .exclusive, _ message: SignpostMetadata) {}
  public func withIntervalSignpost<T>(_ name: StaticString, id: OSSignpostID = .exclusive, around task: () throws -> T) rethrows -> T {
    try task()
  }
}

public struct OSAllocatedUnfairLock<State>: @unchecked Sendable {
  public enum Ownership: Sendable { case owner, notOwner }
  public init(uncheckedState initialState: State) {}
  public func withLockUnchecked<R>(_ body: (inout State) throws -> R) rethrows -> R { fatalError() }
  public func withLock<R: Sendable>(_ body: @Sendable (inout State) throws -> R) rethrows -> R { fatalError() }
  public func withLockIfAvailableUnchecked<R>(_ body: (inout State) throws -> R) rethrows -> R? { nil }
  public func withLockIfAvailable<R: Sendable>(_ body: @Sendable (inout State) throws -> R) rethrows -> R? { nil }
  public func precondition(_ condition: Ownership) {}
}
extension OSAllocatedUnfairLock where State: Sendable {
  public init(initialState: State) {}
}
extension OSAllocatedUnfairLock where State == Void {
  public init() {}
  public func withLockUnchecked<R>(_ body: () throws -> R) rethrows -> R { try body() }
  public func withLock<R: Sendable>(_ body: @Sendable () throws -> R) rethrows -> R { try body() }
  public func lock() {}
  public func unlock() {}
  public func lockIfAvailable() -> Bool { true }
}
public struct os_unfair_lock_s {
  public init() {}
}
public typealias os_unfair_lock = os_unfair_lock_s
public typealias os_unfair_lock_t = UnsafeMutablePointer<os_unfair_lock_s>
public func os_unfair_lock_lock(_ lock: os_unfair_lock_t) {}
public func os_unfair_lock_unlock(_ lock: os_unfair_lock_t) {}
public func os_unfair_lock_trylock(_ lock: os_unfair_lock_t) -> Bool { true }
