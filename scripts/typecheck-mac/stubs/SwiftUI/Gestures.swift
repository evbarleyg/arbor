// A stand-in for SwiftUI: gestures. See SwiftUI.swift.

@MainActor @preconcurrency public protocol Gesture<Value> {
  associatedtype Value
  associatedtype Body: Gesture
  var body: Body { get }
}
extension Never: Gesture {
  public typealias Value = Never
}
/// A gesture SwiftUI recognises itself. Not in the SDK; see `_PrimitiveView`.
public protocol _PrimitiveGesture: Gesture where Body == Never {}
extension _PrimitiveGesture {
  public nonisolated var body: Never { fatalError() }
}

public struct GestureMask: OptionSet, Sendable {
  public let rawValue: UInt32
  public init(rawValue: UInt32) { self.rawValue = rawValue }
  public static let none = GestureMask([])
  public static let gesture = GestureMask(rawValue: 1)
  public static let subviews = GestureMask(rawValue: 2)
  public static let all = GestureMask(rawValue: 3)
}
@propertyWrapper public struct GestureState<Value>: DynamicProperty {
  public init(wrappedValue: Value) {}
  public init(initialValue: Value) {}
  public init(wrappedValue: Value, resetTransaction: Transaction) {}
  public init(initialValue: Value, resetTransaction: Transaction) {}
  public init(wrappedValue: Value, reset: @escaping (Value, inout Transaction) -> Void) {}
  public init(initialValue: Value, reset: @escaping (Value, inout Transaction) -> Void) {}
  public var wrappedValue: Value { fatalError() }
  public var projectedValue: GestureState<Value> { self }
}
extension GestureState where Value: ExpressibleByNilLiteral {
  public init(resetTransaction: Transaction = Transaction()) {}
  public init(reset: @escaping (Value, inout Transaction) -> Void) {}
}

public struct TapGesture: _PrimitiveGesture {
  public typealias Value = Void
  public var count: Int
  public init(count: Int = 1) { self.count = count }
}
public struct SpatialTapGesture: _PrimitiveGesture {
  public struct Value: Equatable, Sendable {
    public var location: CGPoint
  }
  public var count: Int
  public var coordinateSpace: CoordinateSpace
  public init(count: Int = 1, coordinateSpace: CoordinateSpace = .local) {
    self.count = count
    self.coordinateSpace = coordinateSpace
  }
  public init(count: Int = 1, coordinateSpace: some CoordinateSpaceProtocol = .local) {
    self.count = count
    self.coordinateSpace = coordinateSpace.coordinateSpace
  }
}
public struct LongPressGesture: _PrimitiveGesture {
  public typealias Value = Bool
  public var minimumDuration: Double
  public var maximumDistance: CGFloat
  public init(minimumDuration: Double = 0.5, maximumDistance: CGFloat = 10) {
    self.minimumDuration = minimumDuration
    self.maximumDistance = maximumDistance
  }
}
public struct DragGesture: _PrimitiveGesture {
  public struct Value: Equatable, Sendable {
    public var time: Date
    public var location: CGPoint
    public var startLocation: CGPoint
    public var translation: CGSize { .zero }
    public var velocity: CGSize { .zero }
    public var predictedEndLocation: CGPoint { .zero }
    public var predictedEndTranslation: CGSize { .zero }
  }
  public var minimumDistance: CGFloat
  public var coordinateSpace: CoordinateSpace
  public init(minimumDistance: CGFloat = 10, coordinateSpace: CoordinateSpace = .local) {
    self.minimumDistance = minimumDistance
    self.coordinateSpace = coordinateSpace
  }
  public init(minimumDistance: CGFloat = 10, coordinateSpace: some CoordinateSpaceProtocol = .local) {
    self.minimumDistance = minimumDistance
    self.coordinateSpace = coordinateSpace.coordinateSpace
  }
}
public struct MagnifyGesture: _PrimitiveGesture {
  public struct Value: Equatable, Sendable {
    public var time: Date
    public var magnification: CGFloat
    public var velocity: CGFloat
    public var startAnchor: UnitPoint
    public var startLocation: CGPoint
  }
  public var minimumScaleDelta: CGFloat
  public init(minimumScaleDelta: CGFloat = 0.01) { self.minimumScaleDelta = minimumScaleDelta }
}
public struct RotateGesture: _PrimitiveGesture {
  public struct Value: Equatable, Sendable {
    public var time: Date
    public var rotation: Angle
    public var velocity: Angle
    public var startAnchor: UnitPoint
    public var startLocation: CGPoint
  }
  public var minimumAngleDelta: Angle
  public init(minimumAngleDelta: Angle = .degrees(1)) { self.minimumAngleDelta = minimumAngleDelta }
}
@available(*, deprecated, renamed: "MagnifyGesture")
public struct MagnificationGesture: _PrimitiveGesture {
  public typealias Value = CGFloat
  public var minimumScaleDelta: CGFloat
  public init(minimumScaleDelta: CGFloat = 0.01) { self.minimumScaleDelta = minimumScaleDelta }
}
@available(*, deprecated, renamed: "RotateGesture")
public struct RotationGesture: _PrimitiveGesture {
  public typealias Value = Angle
  public var minimumAngleDelta: Angle
  public init(minimumAngleDelta: Angle = .degrees(1)) { self.minimumAngleDelta = minimumAngleDelta }
}
public struct AnyGesture<Value>: _PrimitiveGesture {
  public init<T: Gesture>(_ gesture: T) where Value == T.Value {}
}

public struct _EndedGesture<Content: Gesture>: _PrimitiveGesture {
  public typealias Value = Content.Value
}
public struct _ChangedGesture<Content: Gesture>: _PrimitiveGesture where Content.Value: Equatable {
  public typealias Value = Content.Value
}
public struct _MapGesture<Content: Gesture, Value>: _PrimitiveGesture {}
public struct _ModifiersGesture<Content: Gesture>: _PrimitiveGesture {
  public typealias Value = Content.Value
}
public struct GestureStateGesture<Base: Gesture, State>: _PrimitiveGesture {
  public typealias Value = Base.Value
  public var base: Base
  public var state: GestureState<State>
  public var body: (Base.Value, inout State, inout Transaction) -> Void
  public init(base: Base, state: GestureState<State>, body: @escaping (Base.Value, inout State, inout Transaction) -> Void) {
    self.base = base
    self.state = state
    self.body = body
  }
}
public struct SimultaneousGesture<First: Gesture, Second: Gesture>: _PrimitiveGesture {
  public struct Value {
    public var first: First.Value?
    public var second: Second.Value?
  }
  public var first: First
  public var second: Second
  public init(_ first: First, _ second: Second) {
    self.first = first
    self.second = second
  }
}
public struct SequenceGesture<First: Gesture, Second: Gesture>: _PrimitiveGesture {
  public enum Value {
    case first(First.Value)
    case second(First.Value, Second.Value?)
  }
  public var first: First
  public var second: Second
  public init(_ first: First, _ second: Second) {
    self.first = first
    self.second = second
  }
}
public struct ExclusiveGesture<First: Gesture, Second: Gesture>: _PrimitiveGesture {
  public enum Value {
    case first(First.Value)
    case second(Second.Value)
  }
  public var first: First
  public var second: Second
  public init(_ first: First, _ second: Second) {
    self.first = first
    self.second = second
  }
}
extension Gesture {
  public func onEnded(_ action: @escaping (Value) -> Void) -> _EndedGesture<Self> { fatalError() }
  public func map<T>(_ body: @escaping (Value) -> T) -> _MapGesture<Self, T> { fatalError() }
  public func updating<State>(
    _ state: GestureState<State>, body: @escaping (Value, inout State, inout Transaction) -> Void
  ) -> GestureStateGesture<Self, State> { GestureStateGesture(base: self, state: state, body: body) }
  public func simultaneously<Other: Gesture>(with other: Other) -> SimultaneousGesture<Self, Other> { SimultaneousGesture(self, other) }
  public func sequenced<Other: Gesture>(before other: Other) -> SequenceGesture<Self, Other> { SequenceGesture(self, other) }
  public func exclusively<Other: Gesture>(before other: Other) -> ExclusiveGesture<Self, Other> { ExclusiveGesture(self, other) }
  public func modifiers(_ modifiers: EventModifiers) -> _ModifiersGesture<Self> { fatalError() }
}
extension Gesture where Value: Equatable {
  public func onChanged(_ action: @escaping (Value) -> Void) -> _ChangedGesture<Self> { fatalError() }
}

nonisolated extension View {
  public func gesture<T: Gesture>(_ gesture: T, including mask: GestureMask = .all) -> some View { self }
  public func highPriorityGesture<T: Gesture>(_ gesture: T, including mask: GestureMask = .all) -> some View { self }
  public func simultaneousGesture<T: Gesture>(_ gesture: T, including mask: GestureMask = .all) -> some View { self }
  public func onTapGesture(count: Int = 1, perform action: @escaping () -> Void) -> some View { self }
  public func onTapGesture(count: Int = 1, coordinateSpace: CoordinateSpace = .local, perform action: @escaping (CGPoint) -> Void) -> some View {
    self
  }
  public func onTapGesture(
    count: Int = 1, coordinateSpace: some CoordinateSpaceProtocol = .local, perform action: @escaping (CGPoint) -> Void
  ) -> some View { self }
  public func onLongPressGesture(
    minimumDuration: Double = 0.5, maximumDistance: CGFloat = 10, perform action: @escaping () -> Void,
    onPressingChanged: ((Bool) -> Void)? = nil
  ) -> some View { self }
}
