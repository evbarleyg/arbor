// A stand-in for Combine: the operators, and the types under `Publishers` that they return. See Combine.swift.
// The types have the SDK's names, generic parameters, `Output` and `Failure`, but neither its initialisers nor its stored properties: a chain
// is made with the operators.

public enum Publishers {}

public protocol TopLevelDecoder {
  associatedtype Input
  func decode<T: Decodable>(_ type: T.Type, from: Input) throws -> T
}
public protocol TopLevelEncoder {
  associatedtype Output
  func encode<T: Encodable>(_ value: T) throws -> Output
}

extension Publishers {
  public struct Map<Upstream: Publisher, Output>: Publisher {
    public typealias Failure = Upstream.Failure
    public func receive<S: Subscriber>(subscriber: S) where S.Input == Output, S.Failure == Failure {}
  }
  public struct TryMap<Upstream: Publisher, Output>: Publisher {
    public typealias Failure = Error
    public func receive<S: Subscriber>(subscriber: S) where S.Input == Output, S.Failure == Failure {}
  }
  public struct MapKeyPath<Upstream: Publisher, Output>: Publisher {
    public typealias Failure = Upstream.Failure
    public func receive<S: Subscriber>(subscriber: S) where S.Input == Output, S.Failure == Failure {}
  }
  public struct MapKeyPath2<Upstream: Publisher, Output0, Output1>: Publisher {
    public typealias Output = (Output0, Output1)
    public typealias Failure = Upstream.Failure
    public func receive<S: Subscriber>(subscriber: S) where S.Input == Output, S.Failure == Failure {}
  }
  public struct MapKeyPath3<Upstream: Publisher, Output0, Output1, Output2>: Publisher {
    public typealias Output = (Output0, Output1, Output2)
    public typealias Failure = Upstream.Failure
    public func receive<S: Subscriber>(subscriber: S) where S.Input == Output, S.Failure == Failure {}
  }
  public struct MapError<Upstream: Publisher, Failure: Error>: Publisher {
    public typealias Output = Upstream.Output
    public func receive<S: Subscriber>(subscriber: S) where S.Input == Output, S.Failure == Failure {}
  }
  public struct Scan<Upstream: Publisher, Output>: Publisher {
    public typealias Failure = Upstream.Failure
    public func receive<S: Subscriber>(subscriber: S) where S.Input == Output, S.Failure == Failure {}
  }
  public struct TryScan<Upstream: Publisher, Output>: Publisher {
    public typealias Failure = Error
    public func receive<S: Subscriber>(subscriber: S) where S.Input == Output, S.Failure == Failure {}
  }
  public struct Filter<Upstream: Publisher>: Publisher {
    public typealias Output = Upstream.Output
    public typealias Failure = Upstream.Failure
    public func receive<S: Subscriber>(subscriber: S) where S.Input == Output, S.Failure == Failure {}
  }
  public struct TryFilter<Upstream: Publisher>: Publisher {
    public typealias Output = Upstream.Output
    public typealias Failure = Error
    public func receive<S: Subscriber>(subscriber: S) where S.Input == Output, S.Failure == Failure {}
  }
  public struct CompactMap<Upstream: Publisher, Output>: Publisher {
    public typealias Failure = Upstream.Failure
    public func receive<S: Subscriber>(subscriber: S) where S.Input == Output, S.Failure == Failure {}
  }
  public struct TryCompactMap<Upstream: Publisher, Output>: Publisher {
    public typealias Failure = Error
    public func receive<S: Subscriber>(subscriber: S) where S.Input == Output, S.Failure == Failure {}
  }
  public struct RemoveDuplicates<Upstream: Publisher>: Publisher {
    public typealias Output = Upstream.Output
    public typealias Failure = Upstream.Failure
    public func receive<S: Subscriber>(subscriber: S) where S.Input == Output, S.Failure == Failure {}
  }
  public struct TryRemoveDuplicates<Upstream: Publisher>: Publisher {
    public typealias Output = Upstream.Output
    public typealias Failure = Error
    public func receive<S: Subscriber>(subscriber: S) where S.Input == Output, S.Failure == Failure {}
  }
  public struct ReplaceEmpty<Upstream: Publisher>: Publisher {
    public typealias Output = Upstream.Output
    public typealias Failure = Upstream.Failure
    public func receive<S: Subscriber>(subscriber: S) where S.Input == Output, S.Failure == Failure {}
  }
  public struct ReplaceError<Upstream: Publisher>: Publisher {
    public typealias Output = Upstream.Output
    public typealias Failure = Never
    public func receive<S: Subscriber>(subscriber: S) where S.Input == Output, S.Failure == Failure {}
  }
  public struct Collect<Upstream: Publisher>: Publisher {
    public typealias Output = [Upstream.Output]
    public typealias Failure = Upstream.Failure
    public func receive<S: Subscriber>(subscriber: S) where S.Input == Output, S.Failure == Failure {}
  }
  public struct CollectByCount<Upstream: Publisher>: Publisher {
    public typealias Output = [Upstream.Output]
    public typealias Failure = Upstream.Failure
    public func receive<S: Subscriber>(subscriber: S) where S.Input == Output, S.Failure == Failure {}
  }
  public struct CollectByTime<Upstream: Publisher, Context: Scheduler>: Publisher {
    public typealias Output = [Upstream.Output]
    public typealias Failure = Upstream.Failure
    public func receive<S: Subscriber>(subscriber: S) where S.Input == Output, S.Failure == Failure {}
  }
  public struct IgnoreOutput<Upstream: Publisher>: Publisher {
    public typealias Output = Never
    public typealias Failure = Upstream.Failure
    public func receive<S: Subscriber>(subscriber: S) where S.Input == Output, S.Failure == Failure {}
  }
  public struct Reduce<Upstream: Publisher, Output>: Publisher {
    public typealias Failure = Upstream.Failure
    public func receive<S: Subscriber>(subscriber: S) where S.Input == Output, S.Failure == Failure {}
  }
  public struct TryReduce<Upstream: Publisher, Output>: Publisher {
    public typealias Failure = Error
    public func receive<S: Subscriber>(subscriber: S) where S.Input == Output, S.Failure == Failure {}
  }
  public struct Count<Upstream: Publisher>: Publisher {
    public typealias Output = Int
    public typealias Failure = Upstream.Failure
    public func receive<S: Subscriber>(subscriber: S) where S.Input == Output, S.Failure == Failure {}
  }
  public struct Comparison<Upstream: Publisher>: Publisher {
    public typealias Output = Upstream.Output
    public typealias Failure = Upstream.Failure
    public func receive<S: Subscriber>(subscriber: S) where S.Input == Output, S.Failure == Failure {}
  }
  public struct TryComparison<Upstream: Publisher>: Publisher {
    public typealias Output = Upstream.Output
    public typealias Failure = Error
    public func receive<S: Subscriber>(subscriber: S) where S.Input == Output, S.Failure == Failure {}
  }
  public struct Contains<Upstream: Publisher>: Publisher where Upstream.Output: Equatable {
    public typealias Output = Bool
    public typealias Failure = Upstream.Failure
    public func receive<S: Subscriber>(subscriber: S) where S.Input == Output, S.Failure == Failure {}
  }
  public struct ContainsWhere<Upstream: Publisher>: Publisher {
    public typealias Output = Bool
    public typealias Failure = Upstream.Failure
    public func receive<S: Subscriber>(subscriber: S) where S.Input == Output, S.Failure == Failure {}
  }
  public struct TryContainsWhere<Upstream: Publisher>: Publisher {
    public typealias Output = Bool
    public typealias Failure = Error
    public func receive<S: Subscriber>(subscriber: S) where S.Input == Output, S.Failure == Failure {}
  }
  public struct AllSatisfy<Upstream: Publisher>: Publisher {
    public typealias Output = Bool
    public typealias Failure = Upstream.Failure
    public func receive<S: Subscriber>(subscriber: S) where S.Input == Output, S.Failure == Failure {}
  }
  public struct TryAllSatisfy<Upstream: Publisher>: Publisher {
    public typealias Output = Bool
    public typealias Failure = Error
    public func receive<S: Subscriber>(subscriber: S) where S.Input == Output, S.Failure == Failure {}
  }
  public struct Drop<Upstream: Publisher>: Publisher {
    public typealias Output = Upstream.Output
    public typealias Failure = Upstream.Failure
    public func receive<S: Subscriber>(subscriber: S) where S.Input == Output, S.Failure == Failure {}
  }
  public struct DropWhile<Upstream: Publisher>: Publisher {
    public typealias Output = Upstream.Output
    public typealias Failure = Upstream.Failure
    public func receive<S: Subscriber>(subscriber: S) where S.Input == Output, S.Failure == Failure {}
  }
  public struct TryDropWhile<Upstream: Publisher>: Publisher {
    public typealias Output = Upstream.Output
    public typealias Failure = Error
    public func receive<S: Subscriber>(subscriber: S) where S.Input == Output, S.Failure == Failure {}
  }
  public struct DropUntilOutput<Upstream: Publisher, Other: Publisher>: Publisher where Upstream.Failure == Other.Failure {
    public typealias Output = Upstream.Output
    public typealias Failure = Upstream.Failure
    public func receive<S: Subscriber>(subscriber: S) where S.Input == Output, S.Failure == Failure {}
  }
  public struct Output<Upstream: Publisher>: Publisher {
    public typealias Output = Upstream.Output
    public typealias Failure = Upstream.Failure
    public func receive<S: Subscriber>(subscriber: S) where S.Input == Output, S.Failure == Failure {}
  }
  public struct PrefixWhile<Upstream: Publisher>: Publisher {
    public typealias Output = Upstream.Output
    public typealias Failure = Upstream.Failure
    public func receive<S: Subscriber>(subscriber: S) where S.Input == Output, S.Failure == Failure {}
  }
  public struct TryPrefixWhile<Upstream: Publisher>: Publisher {
    public typealias Output = Upstream.Output
    public typealias Failure = Error
    public func receive<S: Subscriber>(subscriber: S) where S.Input == Output, S.Failure == Failure {}
  }
  public struct PrefixUntilOutput<Upstream: Publisher, Other: Publisher>: Publisher {
    public typealias Output = Upstream.Output
    public typealias Failure = Upstream.Failure
    public func receive<S: Subscriber>(subscriber: S) where S.Input == Output, S.Failure == Failure {}
  }
  public struct First<Upstream: Publisher>: Publisher {
    public typealias Output = Upstream.Output
    public typealias Failure = Upstream.Failure
    public func receive<S: Subscriber>(subscriber: S) where S.Input == Output, S.Failure == Failure {}
  }
  public struct FirstWhere<Upstream: Publisher>: Publisher {
    public typealias Output = Upstream.Output
    public typealias Failure = Upstream.Failure
    public func receive<S: Subscriber>(subscriber: S) where S.Input == Output, S.Failure == Failure {}
  }
  public struct TryFirstWhere<Upstream: Publisher>: Publisher {
    public typealias Output = Upstream.Output
    public typealias Failure = Error
    public func receive<S: Subscriber>(subscriber: S) where S.Input == Output, S.Failure == Failure {}
  }
  public struct Last<Upstream: Publisher>: Publisher {
    public typealias Output = Upstream.Output
    public typealias Failure = Upstream.Failure
    public func receive<S: Subscriber>(subscriber: S) where S.Input == Output, S.Failure == Failure {}
  }
  public struct LastWhere<Upstream: Publisher>: Publisher {
    public typealias Output = Upstream.Output
    public typealias Failure = Upstream.Failure
    public func receive<S: Subscriber>(subscriber: S) where S.Input == Output, S.Failure == Failure {}
  }
  public struct TryLastWhere<Upstream: Publisher>: Publisher {
    public typealias Output = Upstream.Output
    public typealias Failure = Error
    public func receive<S: Subscriber>(subscriber: S) where S.Input == Output, S.Failure == Failure {}
  }
  public struct Concatenate<Prefix: Publisher, Suffix: Publisher>: Publisher
  where Prefix.Failure == Suffix.Failure, Prefix.Output == Suffix.Output {
    public typealias Output = Suffix.Output
    public typealias Failure = Suffix.Failure
    public func receive<S: Subscriber>(subscriber: S) where S.Input == Output, S.Failure == Failure {}
  }
  public struct CombineLatest<A: Publisher, B: Publisher>: Publisher where A.Failure == B.Failure {
    public typealias Output = (A.Output, B.Output)
    public typealias Failure = A.Failure
    public func receive<S: Subscriber>(subscriber: S) where S.Input == Output, S.Failure == Failure {}
  }
  public struct CombineLatest3<A: Publisher, B: Publisher, C: Publisher>: Publisher where A.Failure == B.Failure, B.Failure == C.Failure {
    public typealias Output = (A.Output, B.Output, C.Output)
    public typealias Failure = A.Failure
    public func receive<S: Subscriber>(subscriber: S) where S.Input == Output, S.Failure == Failure {}
  }
  public struct CombineLatest4<A: Publisher, B: Publisher, C: Publisher, D: Publisher>: Publisher
  where A.Failure == B.Failure, B.Failure == C.Failure, C.Failure == D.Failure {
    public typealias Output = (A.Output, B.Output, C.Output, D.Output)
    public typealias Failure = A.Failure
    public func receive<S: Subscriber>(subscriber: S) where S.Input == Output, S.Failure == Failure {}
  }
  public struct Merge<A: Publisher, B: Publisher>: Publisher where A.Failure == B.Failure, A.Output == B.Output {
    public typealias Output = A.Output
    public typealias Failure = A.Failure
    public func receive<S: Subscriber>(subscriber: S) where S.Input == Output, S.Failure == Failure {}
  }
  public struct Merge3<A: Publisher, B: Publisher, C: Publisher>: Publisher
  where A.Failure == B.Failure, A.Output == B.Output, B.Failure == C.Failure, B.Output == C.Output {
    public typealias Output = A.Output
    public typealias Failure = A.Failure
    public func receive<S: Subscriber>(subscriber: S) where S.Input == Output, S.Failure == Failure {}
  }
  public struct Merge4<A: Publisher, B: Publisher, C: Publisher, D: Publisher>: Publisher
  where A.Failure == B.Failure, A.Output == B.Output, B.Failure == C.Failure, B.Output == C.Output, C.Failure == D.Failure, C.Output == D.Output {
    public typealias Output = A.Output
    public typealias Failure = A.Failure
    public func receive<S: Subscriber>(subscriber: S) where S.Input == Output, S.Failure == Failure {}
  }
  public struct MergeMany<Upstream: Publisher>: Publisher {
    public typealias Output = Upstream.Output
    public typealias Failure = Upstream.Failure
    public func receive<S: Subscriber>(subscriber: S) where S.Input == Output, S.Failure == Failure {}
  }
  public struct Zip<A: Publisher, B: Publisher>: Publisher where A.Failure == B.Failure {
    public typealias Output = (A.Output, B.Output)
    public typealias Failure = A.Failure
    public func receive<S: Subscriber>(subscriber: S) where S.Input == Output, S.Failure == Failure {}
  }
  public struct Zip3<A: Publisher, B: Publisher, C: Publisher>: Publisher where A.Failure == B.Failure, B.Failure == C.Failure {
    public typealias Output = (A.Output, B.Output, C.Output)
    public typealias Failure = A.Failure
    public func receive<S: Subscriber>(subscriber: S) where S.Input == Output, S.Failure == Failure {}
  }
  public struct Zip4<A: Publisher, B: Publisher, C: Publisher, D: Publisher>: Publisher
  where A.Failure == B.Failure, B.Failure == C.Failure, C.Failure == D.Failure {
    public typealias Output = (A.Output, B.Output, C.Output, D.Output)
    public typealias Failure = A.Failure
    public func receive<S: Subscriber>(subscriber: S) where S.Input == Output, S.Failure == Failure {}
  }
  public struct FlatMap<NewPublisher: Publisher, Upstream: Publisher>: Publisher where NewPublisher.Failure == Upstream.Failure {
    public typealias Output = NewPublisher.Output
    public typealias Failure = Upstream.Failure
    public func receive<S: Subscriber>(subscriber: S) where S.Input == Output, S.Failure == Failure {}
  }
  public struct SwitchToLatest<P: Publisher, Upstream: Publisher>: Publisher where P == Upstream.Output, P.Failure == Upstream.Failure {
    public typealias Output = P.Output
    public typealias Failure = P.Failure
    public func receive<S: Subscriber>(subscriber: S) where S.Input == Output, S.Failure == Failure {}
  }
  public struct Debounce<Upstream: Publisher, Context: Scheduler>: Publisher {
    public typealias Output = Upstream.Output
    public typealias Failure = Upstream.Failure
    public func receive<S: Subscriber>(subscriber: S) where S.Input == Output, S.Failure == Failure {}
  }
  public struct Throttle<Upstream: Publisher, Context: Scheduler>: Publisher {
    public typealias Output = Upstream.Output
    public typealias Failure = Upstream.Failure
    public func receive<S: Subscriber>(subscriber: S) where S.Input == Output, S.Failure == Failure {}
  }
  public struct Delay<Upstream: Publisher, Context: Scheduler>: Publisher {
    public typealias Output = Upstream.Output
    public typealias Failure = Upstream.Failure
    public func receive<S: Subscriber>(subscriber: S) where S.Input == Output, S.Failure == Failure {}
  }
  public struct Timeout<Upstream: Publisher, Context: Scheduler>: Publisher {
    public typealias Output = Upstream.Output
    public typealias Failure = Upstream.Failure
    public func receive<S: Subscriber>(subscriber: S) where S.Input == Output, S.Failure == Failure {}
  }
  public struct MeasureInterval<Upstream: Publisher, Context: Scheduler>: Publisher {
    public typealias Output = Context.SchedulerTimeType.Stride
    public typealias Failure = Upstream.Failure
    public func receive<S: Subscriber>(subscriber: S) where S.Input == Output, S.Failure == Failure {}
  }
  public struct ReceiveOn<Upstream: Publisher, Context: Scheduler>: Publisher {
    public typealias Output = Upstream.Output
    public typealias Failure = Upstream.Failure
    public func receive<S: Subscriber>(subscriber: S) where S.Input == Output, S.Failure == Failure {}
  }
  public struct SubscribeOn<Upstream: Publisher, Context: Scheduler>: Publisher {
    public typealias Output = Upstream.Output
    public typealias Failure = Upstream.Failure
    public func receive<S: Subscriber>(subscriber: S) where S.Input == Output, S.Failure == Failure {}
  }
  public struct HandleEvents<Upstream: Publisher>: Publisher {
    public typealias Output = Upstream.Output
    public typealias Failure = Upstream.Failure
    public func receive<S: Subscriber>(subscriber: S) where S.Input == Output, S.Failure == Failure {}
  }
  public struct Print<Upstream: Publisher>: Publisher {
    public typealias Output = Upstream.Output
    public typealias Failure = Upstream.Failure
    public func receive<S: Subscriber>(subscriber: S) where S.Input == Output, S.Failure == Failure {}
  }
  public struct Breakpoint<Upstream: Publisher>: Publisher {
    public typealias Output = Upstream.Output
    public typealias Failure = Upstream.Failure
    public func receive<S: Subscriber>(subscriber: S) where S.Input == Output, S.Failure == Failure {}
  }
  public struct Buffer<Upstream: Publisher>: Publisher {
    public typealias Output = Upstream.Output
    public typealias Failure = Upstream.Failure
    public func receive<S: Subscriber>(subscriber: S) where S.Input == Output, S.Failure == Failure {}
  }
  public struct Catch<Upstream: Publisher, NewPublisher: Publisher>: Publisher where Upstream.Output == NewPublisher.Output {
    public typealias Output = Upstream.Output
    public typealias Failure = NewPublisher.Failure
    public func receive<S: Subscriber>(subscriber: S) where S.Input == Output, S.Failure == Failure {}
  }
  public struct TryCatch<Upstream: Publisher, NewPublisher: Publisher>: Publisher where Upstream.Output == NewPublisher.Output {
    public typealias Output = Upstream.Output
    public typealias Failure = Error
    public func receive<S: Subscriber>(subscriber: S) where S.Input == Output, S.Failure == Failure {}
  }
  public struct Retry<Upstream: Publisher>: Publisher {
    public typealias Output = Upstream.Output
    public typealias Failure = Upstream.Failure
    public func receive<S: Subscriber>(subscriber: S) where S.Input == Output, S.Failure == Failure {}
  }
  public struct AssertNoFailure<Upstream: Publisher>: Publisher {
    public typealias Output = Upstream.Output
    public typealias Failure = Never
    public func receive<S: Subscriber>(subscriber: S) where S.Input == Output, S.Failure == Failure {}
  }
  public struct SetFailureType<Upstream: Publisher, Failure: Error>: Publisher where Upstream.Failure == Never {
    public typealias Output = Upstream.Output
    public func receive<S: Subscriber>(subscriber: S) where S.Input == Output, S.Failure == Failure {}
  }
  public struct Decode<Upstream: Publisher, Output: Decodable, Coder: TopLevelDecoder>: Publisher where Upstream.Output == Coder.Input {
    public typealias Failure = Error
    public func receive<S: Subscriber>(subscriber: S) where S.Input == Output, S.Failure == Failure {}
  }
  public struct Encode<Upstream: Publisher, Coder: TopLevelEncoder>: Publisher where Upstream.Output: Encodable {
    public typealias Output = Coder.Output
    public typealias Failure = Error
    public func receive<S: Subscriber>(subscriber: S) where S.Input == Output, S.Failure == Failure {}
  }
  public struct Sequence<Elements: Swift.Sequence, Failure: Error>: Publisher {
    public typealias Output = Elements.Element
    public func receive<S: Subscriber>(subscriber: S) where S.Input == Output, S.Failure == Failure {}
  }

  public enum PrefetchStrategy: Hashable { case keepFull, byRequest }
  public enum BufferingStrategy<Failure: Error> {
    case dropNewest
    case dropOldest
    case customError(() -> Failure)
  }
  public enum TimeGroupingStrategy<Context: Scheduler> {
    case byTime(Context, Context.SchedulerTimeType.Stride)
    case byTimeOrCount(Context, Context.SchedulerTimeType.Stride, Int)
  }

  public final class Share<Upstream: Publisher>: Publisher, Equatable {
    public typealias Output = Upstream.Output
    public typealias Failure = Upstream.Failure
    public func receive<S: Subscriber>(subscriber: S) where S.Input == Output, S.Failure == Failure {}
    public static func == (lhs: Share<Upstream>, rhs: Share<Upstream>) -> Bool { lhs === rhs }
  }
  public final class Multicast<Upstream: Publisher, SubjectType: Subject>: ConnectablePublisher
  where Upstream.Failure == SubjectType.Failure, Upstream.Output == SubjectType.Output {
    public typealias Output = Upstream.Output
    public typealias Failure = Upstream.Failure
    public func receive<S: Subscriber>(subscriber: S) where S.Input == Output, S.Failure == Failure {}
    public func connect() -> Cancellable { fatalError() }
  }
  public struct MakeConnectable<Upstream: Publisher>: ConnectablePublisher {
    public typealias Output = Upstream.Output
    public typealias Failure = Upstream.Failure
    public func receive<S: Subscriber>(subscriber: S) where S.Input == Output, S.Failure == Failure {}
    public func connect() -> Cancellable { fatalError() }
  }
  public class Autoconnect<Upstream: ConnectablePublisher>: Publisher {
    public typealias Output = Upstream.Output
    public typealias Failure = Upstream.Failure
    public func receive<S: Subscriber>(subscriber: S) where S.Input == Output, S.Failure == Failure {}
  }
}

// MARK: Changing the values

extension Publisher {
  public func map<T>(_ transform: @escaping (Output) -> T) -> Publishers.Map<Self, T> { fatalError() }
  public func tryMap<T>(_ transform: @escaping (Output) throws -> T) -> Publishers.TryMap<Self, T> { fatalError() }
  public func map<T>(_ keyPath: KeyPath<Output, T>) -> Publishers.MapKeyPath<Self, T> { fatalError() }
  public func map<T0, T1>(_ keyPath0: KeyPath<Output, T0>, _ keyPath1: KeyPath<Output, T1>) -> Publishers.MapKeyPath2<Self, T0, T1> {
    fatalError()
  }
  public func map<T0, T1, T2>(
    _ keyPath0: KeyPath<Output, T0>, _ keyPath1: KeyPath<Output, T1>, _ keyPath2: KeyPath<Output, T2>
  ) -> Publishers.MapKeyPath3<Self, T0, T1, T2> { fatalError() }
  public func mapError<E: Error>(_ transform: @escaping (Failure) -> E) -> Publishers.MapError<Self, E> { fatalError() }
  public func replaceNil<T>(with output: T) -> Publishers.Map<Self, T> where Output == T? { fatalError() }
  public func scan<T>(_ initialResult: T, _ nextPartialResult: @escaping (T, Output) -> T) -> Publishers.Scan<Self, T> { fatalError() }
  public func tryScan<T>(_ initialResult: T, _ nextPartialResult: @escaping (T, Output) throws -> T) -> Publishers.TryScan<Self, T> {
    fatalError()
  }
  public func compactMap<T>(_ transform: @escaping (Output) -> T?) -> Publishers.CompactMap<Self, T> { fatalError() }
  public func tryCompactMap<T>(_ transform: @escaping (Output) throws -> T?) -> Publishers.TryCompactMap<Self, T> { fatalError() }
  public func flatMap<T, P: Publisher>(
    maxPublishers: Subscribers.Demand = .unlimited, _ transform: @escaping (Output) -> P
  ) -> Publishers.FlatMap<P, Self> where T == P.Output, Failure == P.Failure { fatalError() }
  public func flatMap<P: Publisher>(
    maxPublishers: Subscribers.Demand = .unlimited, _ transform: @escaping (Output) -> P
  ) -> Publishers.FlatMap<Publishers.SetFailureType<P, Failure>, Self> where P.Failure == Never { fatalError() }
  public func decode<Item: Decodable, Coder: TopLevelDecoder>(
    type: Item.Type, decoder: Coder
  ) -> Publishers.Decode<Self, Item, Coder> where Output == Coder.Input { fatalError() }
}
extension Publisher where Failure == Never {
  public func flatMap<P: Publisher>(
    maxPublishers: Subscribers.Demand = .unlimited, _ transform: @escaping (Output) -> P
  ) -> Publishers.FlatMap<P, Publishers.SetFailureType<Self, P.Failure>> { fatalError() }
  public func flatMap<P: Publisher>(
    maxPublishers: Subscribers.Demand = .unlimited, _ transform: @escaping (Output) -> P
  ) -> Publishers.FlatMap<P, Self> where P.Failure == Never { fatalError() }
  public func setFailureType<E: Error>(to failureType: E.Type) -> Publishers.SetFailureType<Self, E> { fatalError() }
}
extension Publisher where Output: Encodable {
  public func encode<Coder: TopLevelEncoder>(encoder: Coder) -> Publishers.Encode<Self, Coder> { fatalError() }
}

// MARK: Choosing among the values

extension Publisher {
  public func filter(_ isIncluded: @escaping (Output) -> Bool) -> Publishers.Filter<Self> { fatalError() }
  public func tryFilter(_ isIncluded: @escaping (Output) throws -> Bool) -> Publishers.TryFilter<Self> { fatalError() }
  public func removeDuplicates(by predicate: @escaping (Output, Output) -> Bool) -> Publishers.RemoveDuplicates<Self> { fatalError() }
  public func tryRemoveDuplicates(by predicate: @escaping (Output, Output) throws -> Bool) -> Publishers.TryRemoveDuplicates<Self> {
    fatalError()
  }
  public func replaceEmpty(with output: Output) -> Publishers.ReplaceEmpty<Self> { fatalError() }
  public func replaceError(with output: Output) -> Publishers.ReplaceError<Self> { fatalError() }
  public func ignoreOutput() -> Publishers.IgnoreOutput<Self> { fatalError() }
  public func dropFirst(_ count: Int = 1) -> Publishers.Drop<Self> { fatalError() }
  public func drop(while predicate: @escaping (Output) -> Bool) -> Publishers.DropWhile<Self> { fatalError() }
  public func tryDrop(while predicate: @escaping (Output) throws -> Bool) -> Publishers.TryDropWhile<Self> { fatalError() }
  public func drop<P: Publisher>(untilOutputFrom publisher: P) -> Publishers.DropUntilOutput<Self, P> where Failure == P.Failure {
    fatalError()
  }
  public func prefix(_ maxLength: Int) -> Publishers.Output<Self> { fatalError() }
  public func prefix(while predicate: @escaping (Output) -> Bool) -> Publishers.PrefixWhile<Self> { fatalError() }
  public func tryPrefix(while predicate: @escaping (Output) throws -> Bool) -> Publishers.TryPrefixWhile<Self> { fatalError() }
  public func prefix<P: Publisher>(untilOutputFrom publisher: P) -> Publishers.PrefixUntilOutput<Self, P> { fatalError() }
  public func first() -> Publishers.First<Self> { fatalError() }
  public func first(where predicate: @escaping (Output) -> Bool) -> Publishers.FirstWhere<Self> { fatalError() }
  public func tryFirst(where predicate: @escaping (Output) throws -> Bool) -> Publishers.TryFirstWhere<Self> { fatalError() }
  public func last() -> Publishers.Last<Self> { fatalError() }
  public func last(where predicate: @escaping (Output) -> Bool) -> Publishers.LastWhere<Self> { fatalError() }
  public func tryLast(where predicate: @escaping (Output) throws -> Bool) -> Publishers.TryLastWhere<Self> { fatalError() }
  public func output(at index: Int) -> Publishers.Output<Self> { fatalError() }
  public func output<R: RangeExpression>(in range: R) -> Publishers.Output<Self> where R.Bound == Int { fatalError() }
}
extension Publisher where Output: Equatable {
  public func removeDuplicates() -> Publishers.RemoveDuplicates<Self> { fatalError() }
  public func contains(_ output: Output) -> Publishers.Contains<Self> { fatalError() }
}

// MARK: Summing up

extension Publisher {
  public func collect() -> Publishers.Collect<Self> { fatalError() }
  public func collect(_ count: Int) -> Publishers.CollectByCount<Self> { fatalError() }
  public func collect<S: Scheduler>(
    _ strategy: Publishers.TimeGroupingStrategy<S>, options: S.SchedulerOptions? = nil
  ) -> Publishers.CollectByTime<Self, S> { fatalError() }
  public func reduce<T>(_ initialResult: T, _ nextPartialResult: @escaping (T, Output) -> T) -> Publishers.Reduce<Self, T> { fatalError() }
  public func tryReduce<T>(_ initialResult: T, _ nextPartialResult: @escaping (T, Output) throws -> T) -> Publishers.TryReduce<Self, T> {
    fatalError()
  }
  public func count() -> Publishers.Count<Self> { fatalError() }
  public func min(by areInIncreasingOrder: @escaping (Output, Output) -> Bool) -> Publishers.Comparison<Self> { fatalError() }
  public func max(by areInIncreasingOrder: @escaping (Output, Output) -> Bool) -> Publishers.Comparison<Self> { fatalError() }
  public func tryMin(by areInIncreasingOrder: @escaping (Output, Output) throws -> Bool) -> Publishers.TryComparison<Self> { fatalError() }
  public func tryMax(by areInIncreasingOrder: @escaping (Output, Output) throws -> Bool) -> Publishers.TryComparison<Self> { fatalError() }
  public func contains(where predicate: @escaping (Output) -> Bool) -> Publishers.ContainsWhere<Self> { fatalError() }
  public func tryContains(where predicate: @escaping (Output) throws -> Bool) -> Publishers.TryContainsWhere<Self> { fatalError() }
  public func allSatisfy(_ predicate: @escaping (Output) -> Bool) -> Publishers.AllSatisfy<Self> { fatalError() }
  public func tryAllSatisfy(_ predicate: @escaping (Output) throws -> Bool) -> Publishers.TryAllSatisfy<Self> { fatalError() }
}
extension Publisher where Output: Comparable {
  public func min() -> Publishers.Comparison<Self> { fatalError() }
  public func max() -> Publishers.Comparison<Self> { fatalError() }
}

// MARK: Several publishers

extension Publisher {
  public func append(_ elements: Output...) -> Publishers.Concatenate<Self, Publishers.Sequence<[Output], Failure>> { fatalError() }
  public func append<S: Sequence>(_ elements: S) -> Publishers.Concatenate<Self, Publishers.Sequence<S, Failure>>
  where Output == S.Element { fatalError() }
  public func append<P: Publisher>(_ publisher: P) -> Publishers.Concatenate<Self, P> where Failure == P.Failure, Output == P.Output {
    fatalError()
  }
  public func prepend(_ elements: Output...) -> Publishers.Concatenate<Publishers.Sequence<[Output], Failure>, Self> { fatalError() }
  public func prepend<S: Sequence>(_ elements: S) -> Publishers.Concatenate<Publishers.Sequence<S, Failure>, Self>
  where Output == S.Element { fatalError() }
  public func prepend<P: Publisher>(_ publisher: P) -> Publishers.Concatenate<P, Self> where Failure == P.Failure, Output == P.Output {
    fatalError()
  }

  public func combineLatest<P: Publisher>(_ other: P) -> Publishers.CombineLatest<Self, P> where Failure == P.Failure { fatalError() }
  public func combineLatest<P: Publisher, T>(
    _ other: P, _ transform: @escaping (Output, P.Output) -> T
  ) -> Publishers.Map<Publishers.CombineLatest<Self, P>, T> where Failure == P.Failure { fatalError() }
  public func combineLatest<P: Publisher, Q: Publisher>(_ publisher1: P, _ publisher2: Q) -> Publishers.CombineLatest3<Self, P, Q>
  where Failure == P.Failure, P.Failure == Q.Failure { fatalError() }
  public func combineLatest<P: Publisher, Q: Publisher, T>(
    _ publisher1: P, _ publisher2: Q, _ transform: @escaping (Output, P.Output, Q.Output) -> T
  ) -> Publishers.Map<Publishers.CombineLatest3<Self, P, Q>, T> where Failure == P.Failure, P.Failure == Q.Failure { fatalError() }
  public func combineLatest<P: Publisher, Q: Publisher, R: Publisher>(
    _ publisher1: P, _ publisher2: Q, _ publisher3: R
  ) -> Publishers.CombineLatest4<Self, P, Q, R> where Failure == P.Failure, P.Failure == Q.Failure, Q.Failure == R.Failure { fatalError() }
  public func combineLatest<P: Publisher, Q: Publisher, R: Publisher, T>(
    _ publisher1: P, _ publisher2: Q, _ publisher3: R, _ transform: @escaping (Output, P.Output, Q.Output, R.Output) -> T
  ) -> Publishers.Map<Publishers.CombineLatest4<Self, P, Q, R>, T>
  where Failure == P.Failure, P.Failure == Q.Failure, Q.Failure == R.Failure { fatalError() }

  public func merge<P: Publisher>(with other: P) -> Publishers.Merge<Self, P> where Failure == P.Failure, Output == P.Output { fatalError() }
  public func merge<B: Publisher, C: Publisher>(with b: B, _ c: C) -> Publishers.Merge3<Self, B, C>
  where Failure == B.Failure, Output == B.Output, B.Failure == C.Failure, B.Output == C.Output { fatalError() }
  public func merge<B: Publisher, C: Publisher, D: Publisher>(with b: B, _ c: C, _ d: D) -> Publishers.Merge4<Self, B, C, D>
  where Failure == B.Failure, Output == B.Output, B.Failure == C.Failure, B.Output == C.Output, C.Failure == D.Failure, C.Output == D.Output {
    fatalError()
  }
  public func merge(with other: Self) -> Publishers.MergeMany<Self> { fatalError() }

  public func zip<P: Publisher>(_ other: P) -> Publishers.Zip<Self, P> where Failure == P.Failure { fatalError() }
  public func zip<P: Publisher, T>(
    _ other: P, _ transform: @escaping (Output, P.Output) -> T
  ) -> Publishers.Map<Publishers.Zip<Self, P>, T> where Failure == P.Failure { fatalError() }
  public func zip<P: Publisher, Q: Publisher>(_ publisher1: P, _ publisher2: Q) -> Publishers.Zip3<Self, P, Q>
  where Failure == P.Failure, P.Failure == Q.Failure { fatalError() }
  public func zip<P: Publisher, Q: Publisher, T>(
    _ publisher1: P, _ publisher2: Q, _ transform: @escaping (Output, P.Output, Q.Output) -> T
  ) -> Publishers.Map<Publishers.Zip3<Self, P, Q>, T> where Failure == P.Failure, P.Failure == Q.Failure { fatalError() }
  public func zip<P: Publisher, Q: Publisher, R: Publisher>(
    _ publisher1: P, _ publisher2: Q, _ publisher3: R
  ) -> Publishers.Zip4<Self, P, Q, R> where Failure == P.Failure, P.Failure == Q.Failure, Q.Failure == R.Failure { fatalError() }
}
extension Publishers.MergeMany {
  public init(_ upstream: Upstream...) { fatalError() }
  public init<S: Swift.Sequence>(_ upstream: S) where Upstream == S.Element { fatalError() }
}
extension Publisher where Output: Publisher, Output.Failure == Failure {
  public func switchToLatest() -> Publishers.SwitchToLatest<Output, Self> { fatalError() }
}
extension Publisher where Output: Publisher, Failure == Never {
  public func switchToLatest() -> Publishers.SwitchToLatest<Output, Publishers.SetFailureType<Self, Output.Failure>> { fatalError() }
}
extension Publisher where Output: Publisher, Failure == Never, Output.Failure == Never {
  public func switchToLatest() -> Publishers.SwitchToLatest<Output, Self> { fatalError() }
}

// MARK: Time and threads

extension Publisher {
  public func debounce<S: Scheduler>(
    for dueTime: S.SchedulerTimeType.Stride, scheduler: S, options: S.SchedulerOptions? = nil
  ) -> Publishers.Debounce<Self, S> { fatalError() }
  public func throttle<S: Scheduler>(for interval: S.SchedulerTimeType.Stride, scheduler: S, latest: Bool) -> Publishers.Throttle<Self, S> {
    fatalError()
  }
  public func delay<S: Scheduler>(
    for interval: S.SchedulerTimeType.Stride, tolerance: S.SchedulerTimeType.Stride? = nil, scheduler: S, options: S.SchedulerOptions? = nil
  ) -> Publishers.Delay<Self, S> { fatalError() }
  public func timeout<S: Scheduler>(
    _ interval: S.SchedulerTimeType.Stride, scheduler: S, options: S.SchedulerOptions? = nil, customError: (() -> Failure)? = nil
  ) -> Publishers.Timeout<Self, S> { fatalError() }
  public func measureInterval<S: Scheduler>(using scheduler: S, options: S.SchedulerOptions? = nil) -> Publishers.MeasureInterval<Self, S> {
    fatalError()
  }
  public func receive<S: Scheduler>(on scheduler: S, options: S.SchedulerOptions? = nil) -> Publishers.ReceiveOn<Self, S> { fatalError() }
  public func subscribe<S: Scheduler>(on scheduler: S, options: S.SchedulerOptions? = nil) -> Publishers.SubscribeOn<Self, S> { fatalError() }
}

// MARK: Errors

extension Publisher {
  public func `catch`<P: Publisher>(_ handler: @escaping (Failure) -> P) -> Publishers.Catch<Self, P> where Output == P.Output { fatalError() }
  public func tryCatch<P: Publisher>(_ handler: @escaping (Failure) throws -> P) -> Publishers.TryCatch<Self, P> where Output == P.Output {
    fatalError()
  }
  public func retry(_ retries: Int) -> Publishers.Retry<Self> { fatalError() }
  public func assertNoFailure(_ prefix: String = "", file: StaticString = #file, line: UInt = #line) -> Publishers.AssertNoFailure<Self> {
    fatalError()
  }
}

// MARK: Sharing, looking on, erasing

extension Publisher {
  public func share() -> Publishers.Share<Self> { fatalError() }
  public func multicast<S: Subject>(_ createSubject: @escaping () -> S) -> Publishers.Multicast<Self, S>
  where Failure == S.Failure, Output == S.Output { fatalError() }
  public func multicast<S: Subject>(subject: S) -> Publishers.Multicast<Self, S> where Failure == S.Failure, Output == S.Output {
    fatalError()
  }
  public func buffer(
    size: Int, prefetch: Publishers.PrefetchStrategy, whenFull: Publishers.BufferingStrategy<Failure>
  ) -> Publishers.Buffer<Self> { fatalError() }
  public func handleEvents(
    receiveSubscription: ((Subscription) -> Void)? = nil, receiveOutput: ((Output) -> Void)? = nil,
    receiveCompletion: ((Subscribers.Completion<Failure>) -> Void)? = nil, receiveCancel: (() -> Void)? = nil,
    receiveRequest: ((Subscribers.Demand) -> Void)? = nil
  ) -> Publishers.HandleEvents<Self> { fatalError() }
  public func print(_ prefix: String = "", to stream: TextOutputStream? = nil) -> Publishers.Print<Self> { fatalError() }
  public func breakpoint(
    receiveSubscription: ((Subscription) -> Bool)? = nil, receiveOutput: ((Output) -> Bool)? = nil,
    receiveCompletion: ((Subscribers.Completion<Failure>) -> Bool)? = nil
  ) -> Publishers.Breakpoint<Self> { fatalError() }
  public func breakpointOnError() -> Publishers.Breakpoint<Self> { fatalError() }
  public func eraseToAnyPublisher() -> AnyPublisher<Output, Failure> { AnyPublisher(self) }
}
extension Publisher where Failure == Never {
  public func makeConnectable() -> Publishers.MakeConnectable<Self> { fatalError() }
}

// MARK: The end of a chain

extension Publisher {
  public func sink(
    receiveCompletion: @escaping ((Subscribers.Completion<Failure>) -> Void), receiveValue: @escaping ((Output) -> Void)
  ) -> AnyCancellable { fatalError() }
}
extension Publisher where Failure == Never {
  public func sink(receiveValue: @escaping ((Output) -> Void)) -> AnyCancellable { fatalError() }
  public func assign<Root>(to keyPath: ReferenceWritableKeyPath<Root, Output>, on object: Root) -> AnyCancellable { fatalError() }
  public func assign(to published: inout Published<Output>.Publisher) {}
}
