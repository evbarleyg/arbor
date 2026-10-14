// A stand-in for Combine (scripts/typecheck-mac/README.md). Never shipped, never run. Names, labels, generics and constraints as in the
// macOS 14 SDK. This file: the protocols, subscribers, cancellables, subjects, the publishers that start a chain, `@Published`,
// `ObservableObject`. Only the two frozen value types, `Demand` and `Completion`, are `Sendable`, as in the SDK.
@_exported import Foundation

// MARK: The protocols

public protocol Publisher<Output, Failure> {
  associatedtype Output
  associatedtype Failure: Error
  func receive<S: Subscriber>(subscriber: S) where Failure == S.Failure, Output == S.Input
}
extension Publisher {
  public func subscribe<S: Subscriber>(_ subscriber: S) where Failure == S.Failure, Output == S.Input {}
  public func subscribe<S: Subject>(_ subject: S) -> AnyCancellable where Failure == S.Failure, Output == S.Output { fatalError() }
}
public struct CombineIdentifier: Hashable, CustomStringConvertible {
  public init() {}
  public init(_ obj: AnyObject) {}
  public var description: String { "" }
}
public protocol CustomCombineIdentifierConvertible {
  var combineIdentifier: CombineIdentifier { get }
}
extension CustomCombineIdentifierConvertible where Self: AnyObject {
  public var combineIdentifier: CombineIdentifier { CombineIdentifier(self) }
}
public protocol Subscriber<Input, Failure>: CustomCombineIdentifierConvertible {
  associatedtype Input
  associatedtype Failure: Error
  func receive(subscription: Subscription)
  func receive(_ input: Input) -> Subscribers.Demand
  func receive(completion: Subscribers.Completion<Failure>)
}
extension Subscriber where Input == Void {
  public func receive() -> Subscribers.Demand { .none }
}
public protocol Cancellable {
  func cancel()
}
extension Cancellable {
  public func store<C: RangeReplaceableCollection>(in collection: inout C) where C.Element == AnyCancellable {}
  public func store(in set: inout Set<AnyCancellable>) {}
}
public protocol Subscription: Cancellable, CustomCombineIdentifierConvertible {
  func request(_ demand: Subscribers.Demand)
}
public enum Subscriptions {
  public static var empty: Subscription { fatalError() }
}
public protocol Subject<Output, Failure>: AnyObject, Publisher {
  func send(_ value: Output)
  func send(completion: Subscribers.Completion<Failure>)
  func send(subscription: Subscription)
}
extension Subject where Output == Void {
  public func send() {}
}
public protocol ConnectablePublisher<Output, Failure>: Publisher {
  func connect() -> Cancellable
}
extension ConnectablePublisher {
  public func autoconnect() -> Publishers.Autoconnect<Self> { fatalError() }
}

// MARK: Cancellables and subscribers

public final class AnyCancellable: Cancellable, Hashable {
  public init(_ cancel: @escaping () -> Void) {}
  public init<C: Cancellable>(_ canceller: C) {}
  public func cancel() {}
  public func hash(into hasher: inout Hasher) {}
  public static func == (lhs: AnyCancellable, rhs: AnyCancellable) -> Bool { lhs === rhs }
  public func store<C: RangeReplaceableCollection>(in collection: inout C) where C.Element == AnyCancellable {}
  public func store(in set: inout Set<AnyCancellable>) {}
}

public enum Subscribers {
  public struct Demand: Equatable, Comparable, Hashable, Codable, CustomStringConvertible, Sendable {
    public static let unlimited = Demand()
    public static let none = Demand()
    public static func max(_ value: Int) -> Demand { Demand() }
    public var max: Int? { nil }
    public var description: String { "" }
    public static func + (lhs: Demand, rhs: Demand) -> Demand { lhs }
    public static func += (lhs: inout Demand, rhs: Demand) {}
    public static func + (lhs: Demand, rhs: Int) -> Demand { lhs }
    public static func += (lhs: inout Demand, rhs: Int) {}
    public static func - (lhs: Demand, rhs: Demand) -> Demand { lhs }
    public static func -= (lhs: inout Demand, rhs: Demand) {}
    public static func - (lhs: Demand, rhs: Int) -> Demand { lhs }
    public static func -= (lhs: inout Demand, rhs: Int) {}
    public static func * (lhs: Demand, rhs: Int) -> Demand { lhs }
    public static func *= (lhs: inout Demand, rhs: Int) {}
    public static func < (lhs: Demand, rhs: Demand) -> Bool { false }
    public static func > (lhs: Demand, rhs: Int) -> Bool { false }
    public static func >= (lhs: Demand, rhs: Int) -> Bool { false }
    public static func < (lhs: Demand, rhs: Int) -> Bool { false }
    public static func <= (lhs: Demand, rhs: Int) -> Bool { false }
    public static func == (lhs: Demand, rhs: Int) -> Bool { false }
    public static func != (lhs: Demand, rhs: Int) -> Bool { false }
  }
  public enum Completion<Failure: Error>: Sendable {
    case finished
    case failure(Failure)
  }
  public final class Sink<Input, Failure: Error>: Subscriber, Cancellable {
    public let receiveValue: (Input) -> Void
    public let receiveCompletion: (Completion<Failure>) -> Void
    public init(receiveCompletion: @escaping ((Completion<Failure>) -> Void), receiveValue: @escaping ((Input) -> Void)) {
      self.receiveValue = receiveValue
      self.receiveCompletion = receiveCompletion
    }
    public func receive(subscription: Subscription) {}
    public func receive(_ value: Input) -> Demand { .none }
    public func receive(completion: Completion<Failure>) {}
    public func cancel() {}
  }
  public final class Assign<Root, Input>: Subscriber, Cancellable {
    public typealias Failure = Never
    public private(set) var object: Root?
    public let keyPath: ReferenceWritableKeyPath<Root, Input>
    public init(object: Root, keyPath: ReferenceWritableKeyPath<Root, Input>) {
      self.object = object
      self.keyPath = keyPath
    }
    public func receive(subscription: Subscription) {}
    public func receive(_ value: Input) -> Demand { .none }
    public func receive(completion: Completion<Never>) {}
    public func cancel() {}
  }
}
extension Subscribers.Completion: Equatable where Failure: Equatable {}
extension Subscribers.Completion: Hashable where Failure: Hashable {}

public struct AnySubscriber<Input, Failure: Error>: Subscriber {
  public let combineIdentifier = CombineIdentifier()
  public init<S: Subscriber>(_ s: S) where Input == S.Input, Failure == S.Failure {}
  public init<S: Subject>(_ s: S) where Input == S.Output, Failure == S.Failure {}
  public init(
    receiveSubscription: ((Subscription) -> Void)? = nil, receiveValue: ((Input) -> Subscribers.Demand)? = nil,
    receiveCompletion: ((Subscribers.Completion<Failure>) -> Void)? = nil) {}
  public func receive(subscription: Subscription) {}
  public func receive(_ value: Input) -> Subscribers.Demand { .none }
  public func receive(completion: Subscribers.Completion<Failure>) {}
}

// MARK: Subjects

public final class PassthroughSubject<Output, Failure: Error>: Subject {
  public init() {}
  public func receive<S: Subscriber>(subscriber: S) where Output == S.Input, Failure == S.Failure {}
  public func send(_ input: Output) {}
  public func send(completion: Subscribers.Completion<Failure>) {}
  public func send(subscription: Subscription) {}
}
public final class CurrentValueSubject<Output, Failure: Error>: Subject {
  public var value: Output
  public init(_ value: Output) { self.value = value }
  public func receive<S: Subscriber>(subscriber: S) where Output == S.Input, Failure == S.Failure {}
  public func send(_ input: Output) {}
  public func send(completion: Subscribers.Completion<Failure>) {}
  public func send(subscription: Subscription) {}
}

// MARK: Publishers that start a chain

public struct AnyPublisher<Output, Failure: Error>: Publisher, CustomStringConvertible {
  public init<P: Publisher>(_ publisher: P) where Output == P.Output, Failure == P.Failure {}
  public var description: String { "" }
  public func receive<S: Subscriber>(subscriber: S) where Output == S.Input, Failure == S.Failure {}
}
public struct Just<Output>: Publisher {
  public typealias Failure = Never
  public let output: Output
  public init(_ output: Output) { self.output = output }
  public func receive<S: Subscriber>(subscriber: S) where Output == S.Input, S.Failure == Never {}
}
public struct Empty<Output, Failure: Error>: Publisher, Equatable {
  public let completeImmediately: Bool
  public init(completeImmediately: Bool = true) { self.completeImmediately = completeImmediately }
  public init(completeImmediately: Bool = true, outputType: Output.Type, failureType: Failure.Type) {
    self.completeImmediately = completeImmediately
  }
  public func receive<S: Subscriber>(subscriber: S) where Output == S.Input, Failure == S.Failure {}
}
public struct Fail<Output, Failure: Error>: Publisher {
  public let error: Failure
  public init(error: Failure) { self.error = error }
  public init(outputType: Output.Type, failure: Failure) { error = failure }
  public func receive<S: Subscriber>(subscriber: S) where Output == S.Input, Failure == S.Failure {}
}
public struct Deferred<DeferredPublisher: Publisher>: Publisher {
  public typealias Output = DeferredPublisher.Output
  public typealias Failure = DeferredPublisher.Failure
  public let createPublisher: () -> DeferredPublisher
  public init(createPublisher: @escaping () -> DeferredPublisher) { self.createPublisher = createPublisher }
  public func receive<S: Subscriber>(subscriber: S) where DeferredPublisher.Failure == S.Failure, DeferredPublisher.Output == S.Input {}
}
public final class Future<Output, Failure: Error>: Publisher {
  public typealias Promise = (Result<Output, Failure>) -> Void
  public init(_ attemptToFulfill: @escaping (@escaping Promise) -> Void) {}
  public func receive<S: Subscriber>(subscriber: S) where Output == S.Input, Failure == S.Failure {}
}
extension Future where Failure == Never {
  public var value: Output { get async { fatalError() } }
}
extension Future {
  public var value: Output { get async throws { fatalError() } }
}

extension Sequence {
  public var publisher: Publishers.Sequence<Self, Never> { fatalError() }
}
extension Optional {
  public struct Publisher: Combine.Publisher {
    public typealias Output = Wrapped
    public typealias Failure = Never
    public let output: Wrapped?
    public init(_ output: Wrapped?) { self.output = output }
    public func receive<S: Subscriber>(subscriber: S) where Wrapped == S.Input, S.Failure == Never {}
  }
  public var publisher: Optional<Wrapped>.Publisher { Publisher(self) }
}
extension Result {
  public struct Publisher: Combine.Publisher {
    public typealias Output = Success
    public let result: Result<Success, Failure>
    public init(_ result: Result<Success, Failure>) { self.result = result }
    public init(_ output: Success) { result = .success(output) }
    public init(_ failure: Failure) { result = .failure(failure) }
    public func receive<S: Subscriber>(subscriber: S) where Success == S.Input, Failure == S.Failure {}
  }
  public var publisher: Result<Success, Failure>.Publisher { Publisher(self) }
}

// MARK: Observable objects

public final class ObservableObjectPublisher: Publisher {
  public typealias Output = Void
  public typealias Failure = Never
  public init() {}
  public func receive<S: Subscriber>(subscriber: S) where S.Failure == Never, S.Input == Void {}
  public func send() {}
}
public protocol ObservableObject: AnyObject {
  associatedtype ObjectWillChangePublisher: Publisher = ObservableObjectPublisher where ObjectWillChangePublisher.Failure == Never
  var objectWillChange: ObjectWillChangePublisher { get }
}
extension ObservableObject where ObjectWillChangePublisher == ObservableObjectPublisher {
  public var objectWillChange: ObservableObjectPublisher { ObservableObjectPublisher() }
}

/// Reads and writes go through the subscript, which wants a class around the property; in a struct the compiler falls back on
/// `wrappedValue`, which nobody may use. The Mac says the same of `@Published` in a struct.
@propertyWrapper public struct Published<Value> {
  public init(wrappedValue: Value) {}
  public init(initialValue: Value) {}
  public struct Publisher: Combine.Publisher {
    public typealias Output = Value
    public typealias Failure = Never
    public func receive<S: Subscriber>(subscriber: S) where Value == S.Input, S.Failure == Never {}
  }
  public var projectedValue: Published<Value>.Publisher {
    mutating get { Publisher() }
    set {}
  }
  @available(*, unavailable, message: "@Published is only available on properties of classes")
  public var wrappedValue: Value {
    get { fatalError() }
    set {}
  }
  public static subscript<EnclosingSelf: AnyObject>(
    _enclosingInstance object: EnclosingSelf, wrapped wrappedKeyPath: ReferenceWritableKeyPath<EnclosingSelf, Value>,
    storage storageKeyPath: ReferenceWritableKeyPath<EnclosingSelf, Published<Value>>
  ) -> Value {
    get { fatalError() }
    set {}
  }
}

// MARK: As asynchronous sequences

public struct AsyncPublisher<P: Publisher>: AsyncSequence where P.Failure == Never {
  public typealias Element = P.Output
  public struct Iterator: AsyncIteratorProtocol {
    public typealias Element = P.Output
    public mutating func next() async -> P.Output? { nil }
  }
  public init(_ publisher: P) {}
  public func makeAsyncIterator() -> Iterator { Iterator() }
}
public struct AsyncThrowingPublisher<P: Publisher>: AsyncSequence {
  public typealias Element = P.Output
  public struct Iterator: AsyncIteratorProtocol {
    public typealias Element = P.Output
    public mutating func next() async throws -> P.Output? { nil }
  }
  public init(_ publisher: P) {}
  public func makeAsyncIterator() -> Iterator { Iterator() }
}
extension Publisher where Failure == Never {
  public var values: AsyncPublisher<Self> { AsyncPublisher(self) }
}
extension Publisher {
  public var values: AsyncThrowingPublisher<Self> { AsyncThrowingPublisher(self) }
}
