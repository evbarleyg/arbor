// A stand-in for Combine: schedulers, and what Foundation and Dispatch add once Combine is there (on a Mac those extensions live in
// Foundation's and Dispatch's own modules). See Combine.swift.
import Dispatch
import MacFoundation

public protocol SchedulerTimeIntervalConvertible {
  static func seconds(_ s: Int) -> Self
  static func seconds(_ s: Double) -> Self
  static func milliseconds(_ ms: Int) -> Self
  static func microseconds(_ us: Int) -> Self
  static func nanoseconds(_ ns: Int) -> Self
}
public protocol Scheduler<SchedulerTimeType> {
  associatedtype SchedulerTimeType: Strideable where SchedulerTimeType.Stride: SchedulerTimeIntervalConvertible
  associatedtype SchedulerOptions
  var now: SchedulerTimeType { get }
  var minimumTolerance: SchedulerTimeType.Stride { get }
  func schedule(options: SchedulerOptions?, _ action: @escaping () -> Void)
  func schedule(after date: SchedulerTimeType, tolerance: SchedulerTimeType.Stride, options: SchedulerOptions?, _ action: @escaping () -> Void)
  func schedule(
    after date: SchedulerTimeType, interval: SchedulerTimeType.Stride, tolerance: SchedulerTimeType.Stride, options: SchedulerOptions?,
    _ action: @escaping () -> Void
  ) -> Cancellable
}
extension Scheduler {
  public func schedule(_ action: @escaping () -> Void) {}
  public func schedule(after date: SchedulerTimeType, _ action: @escaping () -> Void) {}
  public func schedule(after date: SchedulerTimeType, tolerance: SchedulerTimeType.Stride, _ action: @escaping () -> Void) {}
  public func schedule(after date: SchedulerTimeType, interval: SchedulerTimeType.Stride, _ action: @escaping () -> Void) -> Cancellable {
    fatalError()
  }
  public func schedule(
    after date: SchedulerTimeType, interval: SchedulerTimeType.Stride, tolerance: SchedulerTimeType.Stride, _ action: @escaping () -> Void
  ) -> Cancellable { fatalError() }
}

public struct ImmediateScheduler: Scheduler {
  public struct SchedulerTimeType: Strideable {
    public struct Stride: ExpressibleByFloatLiteral, Comparable, SignedNumeric, Codable, SchedulerTimeIntervalConvertible {
      public var magnitude: Int
      public init(_ value: Int) { magnitude = value }
      public init(integerLiteral value: Int) { magnitude = value }
      public init(floatLiteral value: Double) { magnitude = Int(value) }
      public init?<T: BinaryInteger>(exactly source: T) { magnitude = 0 }
      public static func < (lhs: Stride, rhs: Stride) -> Bool { false }
      public static func * (lhs: Stride, rhs: Stride) -> Stride { lhs }
      public static func + (lhs: Stride, rhs: Stride) -> Stride { lhs }
      public static func - (lhs: Stride, rhs: Stride) -> Stride { lhs }
      public static func *= (lhs: inout Stride, rhs: Stride) {}
      public static func seconds(_ s: Int) -> Stride { 0 }
      public static func seconds(_ s: Double) -> Stride { 0 }
      public static func milliseconds(_ ms: Int) -> Stride { 0 }
      public static func microseconds(_ us: Int) -> Stride { 0 }
      public static func nanoseconds(_ ns: Int) -> Stride { 0 }
    }
    public func distance(to other: SchedulerTimeType) -> Stride { 0 }
    public func advanced(by n: Stride) -> SchedulerTimeType { self }
  }
  public typealias SchedulerOptions = Never
  public static var shared: ImmediateScheduler { ImmediateScheduler() }
  public var now: SchedulerTimeType { SchedulerTimeType() }
  public var minimumTolerance: SchedulerTimeType.Stride { 0 }
  public func schedule(options: Never?, _ action: @escaping () -> Void) {}
  public func schedule(after date: SchedulerTimeType, tolerance: SchedulerTimeType.Stride, options: Never?, _ action: @escaping () -> Void) {}
  public func schedule(
    after date: SchedulerTimeType, interval: SchedulerTimeType.Stride, tolerance: SchedulerTimeType.Stride, options: Never?,
    _ action: @escaping () -> Void
  ) -> Cancellable { fatalError() }
}

// MARK: Dispatch

extension DispatchQueue: Scheduler {
  public struct SchedulerTimeType: Strideable, Codable, Hashable {
    public var dispatchTime: DispatchTime
    public init(_ time: DispatchTime) { dispatchTime = time }
    public init(from decoder: Decoder) throws { fatalError() }
    public func encode(to encoder: Encoder) throws {}
    public func hash(into hasher: inout Hasher) {}
    public static func == (lhs: SchedulerTimeType, rhs: SchedulerTimeType) -> Bool { false }
    public func distance(to other: SchedulerTimeType) -> Stride { 0 }
    public func advanced(by n: Stride) -> SchedulerTimeType { self }
    public struct Stride: SchedulerTimeIntervalConvertible, Comparable, SignedNumeric, ExpressibleByFloatLiteral, Hashable, Codable {
      /// In nanoseconds.
      public var magnitude: Int
      public var timeInterval: DispatchTimeInterval { .nanoseconds(magnitude) }
      public init(_ timeInterval: DispatchTimeInterval) { magnitude = 0 }
      public init(floatLiteral value: Double) { magnitude = 0 }
      public init(integerLiteral value: Int) { magnitude = 0 }
      public init?<T: BinaryInteger>(exactly source: T) { magnitude = 0 }
      public static func < (lhs: Stride, rhs: Stride) -> Bool { false }
      public static func * (lhs: Stride, rhs: Stride) -> Stride { lhs }
      public static func + (lhs: Stride, rhs: Stride) -> Stride { lhs }
      public static func - (lhs: Stride, rhs: Stride) -> Stride { lhs }
      public static func *= (lhs: inout Stride, rhs: Stride) {}
      public static func seconds(_ s: Double) -> Stride { 0 }
      public static func seconds(_ s: Int) -> Stride { 0 }
      public static func milliseconds(_ ms: Int) -> Stride { 0 }
      public static func microseconds(_ us: Int) -> Stride { 0 }
      public static func nanoseconds(_ ns: Int) -> Stride { 0 }
    }
  }
  public struct SchedulerOptions {
    public var qos: DispatchQoS
    public var flags: DispatchWorkItemFlags
    public var group: DispatchGroup?
    public init(qos: DispatchQoS = .unspecified, flags: DispatchWorkItemFlags = [], group: DispatchGroup? = nil) {
      self.qos = qos
      self.flags = flags
      self.group = group
    }
  }
  public var minimumTolerance: SchedulerTimeType.Stride { 0 }
  public var now: SchedulerTimeType { SchedulerTimeType(.now()) }
  public func schedule(options: SchedulerOptions?, _ action: @escaping () -> Void) {}
  public func schedule(
    after date: SchedulerTimeType, tolerance: SchedulerTimeType.Stride, options: SchedulerOptions?, _ action: @escaping () -> Void) {}
  public func schedule(
    after date: SchedulerTimeType, interval: SchedulerTimeType.Stride, tolerance: SchedulerTimeType.Stride, options: SchedulerOptions?,
    _ action: @escaping () -> Void
  ) -> Cancellable { fatalError() }
}

// MARK: Foundation

extension RunLoop: Scheduler {
  public struct SchedulerTimeType: Strideable, Codable, Hashable {
    public var date: Date
    public init(_ date: Date) { self.date = date }
    public func distance(to other: SchedulerTimeType) -> Stride { 0 }
    public func advanced(by n: Stride) -> SchedulerTimeType { self }
    public struct Stride: ExpressibleByFloatLiteral, Comparable, SignedNumeric, Codable, SchedulerTimeIntervalConvertible {
      public var magnitude: TimeInterval
      public var timeInterval: TimeInterval { magnitude }
      public init(_ timeInterval: TimeInterval) { magnitude = timeInterval }
      public init(integerLiteral value: TimeInterval) { magnitude = value }
      public init(floatLiteral value: TimeInterval) { magnitude = value }
      public init?<T: BinaryInteger>(exactly source: T) { magnitude = 0 }
      public static func < (lhs: Stride, rhs: Stride) -> Bool { false }
      public static func * (lhs: Stride, rhs: Stride) -> Stride { lhs }
      public static func + (lhs: Stride, rhs: Stride) -> Stride { lhs }
      public static func - (lhs: Stride, rhs: Stride) -> Stride { lhs }
      public static func *= (lhs: inout Stride, rhs: Stride) {}
      public static func seconds(_ s: Int) -> Stride { 0 }
      public static func seconds(_ s: Double) -> Stride { 0 }
      public static func milliseconds(_ ms: Int) -> Stride { 0 }
      public static func microseconds(_ us: Int) -> Stride { 0 }
      public static func nanoseconds(_ ns: Int) -> Stride { 0 }
    }
  }
  public struct SchedulerOptions {}
  public var now: SchedulerTimeType { SchedulerTimeType(Date()) }
  public var minimumTolerance: SchedulerTimeType.Stride { 0 }
  public func schedule(options: SchedulerOptions?, _ action: @escaping () -> Void) {}
  public func schedule(
    after date: SchedulerTimeType, tolerance: SchedulerTimeType.Stride, options: SchedulerOptions?, _ action: @escaping () -> Void) {}
  public func schedule(
    after date: SchedulerTimeType, interval: SchedulerTimeType.Stride, tolerance: SchedulerTimeType.Stride, options: SchedulerOptions?,
    _ action: @escaping () -> Void
  ) -> Cancellable { fatalError() }
}

extension OperationQueue: Scheduler {
  public struct SchedulerTimeType: Strideable, Codable, Hashable {
    public var date: Date
    public init(_ date: Date) { self.date = date }
    public func distance(to other: SchedulerTimeType) -> Stride { 0 }
    public func advanced(by n: Stride) -> SchedulerTimeType { self }
    public struct Stride: ExpressibleByFloatLiteral, Comparable, SignedNumeric, Codable, SchedulerTimeIntervalConvertible {
      public var magnitude: TimeInterval
      public var timeInterval: TimeInterval { magnitude }
      public init(_ timeInterval: TimeInterval) { magnitude = timeInterval }
      public init(integerLiteral value: TimeInterval) { magnitude = value }
      public init(floatLiteral value: TimeInterval) { magnitude = value }
      public init?<T: BinaryInteger>(exactly source: T) { magnitude = 0 }
      public static func < (lhs: Stride, rhs: Stride) -> Bool { false }
      public static func * (lhs: Stride, rhs: Stride) -> Stride { lhs }
      public static func + (lhs: Stride, rhs: Stride) -> Stride { lhs }
      public static func - (lhs: Stride, rhs: Stride) -> Stride { lhs }
      public static func *= (lhs: inout Stride, rhs: Stride) {}
      public static func seconds(_ s: Int) -> Stride { 0 }
      public static func seconds(_ s: Double) -> Stride { 0 }
      public static func milliseconds(_ ms: Int) -> Stride { 0 }
      public static func microseconds(_ us: Int) -> Stride { 0 }
      public static func nanoseconds(_ ns: Int) -> Stride { 0 }
    }
  }
  public struct SchedulerOptions {}
  public var now: SchedulerTimeType { SchedulerTimeType(Date()) }
  public var minimumTolerance: SchedulerTimeType.Stride { 0 }
  public func schedule(options: SchedulerOptions?, _ action: @escaping () -> Void) {}
  public func schedule(
    after date: SchedulerTimeType, tolerance: SchedulerTimeType.Stride, options: SchedulerOptions?, _ action: @escaping () -> Void) {}
  public func schedule(
    after date: SchedulerTimeType, interval: SchedulerTimeType.Stride, tolerance: SchedulerTimeType.Stride, options: SchedulerOptions?,
    _ action: @escaping () -> Void
  ) -> Cancellable { fatalError() }
}

extension NotificationCenter {
  public struct Publisher: Combine.Publisher {
    public typealias Output = Notification
    public typealias Failure = Never
    public let center: NotificationCenter
    public let name: Notification.Name
    public let object: AnyObject?
    public init(center: NotificationCenter, name: Notification.Name, object: AnyObject? = nil) {
      self.center = center
      self.name = name
      self.object = object
    }
    public func receive<S: Subscriber>(subscriber: S) where S.Failure == Never, S.Input == Notification {}
  }
  public func publisher(for name: Notification.Name, object: AnyObject? = nil) -> NotificationCenter.Publisher {
    Publisher(center: self, name: name, object: object)
  }
}

extension Timer {
  public final class TimerPublisher: ConnectablePublisher {
    public typealias Output = Date
    public typealias Failure = Never
    public let interval: TimeInterval
    public let tolerance: TimeInterval?
    public let runLoop: RunLoop
    public let mode: RunLoop.Mode
    public let options: RunLoop.SchedulerOptions?
    public init(
      interval: TimeInterval, tolerance: TimeInterval? = nil, runLoop: RunLoop, mode: RunLoop.Mode, options: RunLoop.SchedulerOptions? = nil
    ) {
      self.interval = interval
      self.tolerance = tolerance
      self.runLoop = runLoop
      self.mode = mode
      self.options = options
    }
    public func receive<S: Subscriber>(subscriber: S) where S.Failure == Never, S.Input == Date {}
    public func connect() -> Cancellable { fatalError() }
  }
  public static func publish(
    every interval: TimeInterval, tolerance: TimeInterval? = nil, on runLoop: RunLoop, in mode: RunLoop.Mode,
    options: RunLoop.SchedulerOptions? = nil
  ) -> Timer.TimerPublisher { TimerPublisher(interval: interval, tolerance: tolerance, runLoop: runLoop, mode: mode, options: options) }
}

extension URLSession {
  public struct DataTaskPublisher: Combine.Publisher {
    public typealias Output = (data: Data, response: URLResponse)
    public typealias Failure = URLError
    public let request: URLRequest
    public let session: URLSession
    public init(request: URLRequest, session: URLSession) {
      self.request = request
      self.session = session
    }
    public func receive<S: Subscriber>(subscriber: S) where S.Failure == URLError, S.Input == (data: Data, response: URLResponse) {}
  }
  public func dataTaskPublisher(for url: URL) -> DataTaskPublisher { DataTaskPublisher(request: URLRequest(url: url), session: self) }
  public func dataTaskPublisher(for request: URLRequest) -> DataTaskPublisher { DataTaskPublisher(request: request, session: self) }
}

extension NSObject {
  public struct KeyValueObservingPublisher<Subject: NSObject, Value>: Combine.Publisher {
    public typealias Output = Value
    public typealias Failure = Never
    public let object: Subject
    public let keyPath: KeyPath<Subject, Value>
    public let options: NSKeyValueObservingOptions
    public init(object: Subject, keyPath: KeyPath<Subject, Value>, options: NSKeyValueObservingOptions) {
      self.object = object
      self.keyPath = keyPath
      self.options = options
    }
    public func receive<S: Subscriber>(subscriber: S) where S.Failure == Never, S.Input == Value {}
  }
}
extension _KeyValueCodingAndObserving where Self: NSObject {
  public func publisher<Value>(
    for keyPath: KeyPath<Self, Value>, options: NSKeyValueObservingOptions = [.initial, .new]
  ) -> NSObject.KeyValueObservingPublisher<Self, Value> { NSObject.KeyValueObservingPublisher(object: self, keyPath: keyPath, options: options) }
}

extension JSONDecoder: TopLevelDecoder {
  public typealias Input = Data
}
extension JSONEncoder: TopLevelEncoder {
  public typealias Output = Data
}
extension PropertyListDecoder: TopLevelDecoder {
  public typealias Input = Data
}
extension PropertyListEncoder: TopLevelEncoder {
  public typealias Output = Data
}
