// A stand-in for SwiftUI: animations, transactions, transitions. See SwiftUI.swift.

// MARK: Animation

public struct Spring: Hashable, Sendable {
  public init(duration: TimeInterval = 0.5, bounce: Double = 0.0) {}
  public init(mass: Double = 1.0, stiffness: Double, damping: Double, allowOverDamping: Bool = false) {}
  public init(response: Double, dampingRatio: Double) {}
  public init(settlingDuration: TimeInterval, dampingRatio: Double, epsilon: Double = 0.001) {}
  public var duration: TimeInterval { 0 }
  public var bounce: Double { 0 }
  public var response: Double { 0 }
  public var dampingRatio: Double { 0 }
  public var mass: Double { 0 }
  public var stiffness: Double { 0 }
  public var damping: Double { 0 }
  public var settlingDuration: TimeInterval { 0 }
  public static var smooth: Spring { Spring() }
  public static func smooth(duration: TimeInterval = 0.5, extraBounce: Double = 0.0) -> Spring { Spring() }
  public static var snappy: Spring { Spring() }
  public static func snappy(duration: TimeInterval = 0.5, extraBounce: Double = 0.0) -> Spring { Spring() }
  public static var bouncy: Spring { Spring() }
  public static func bouncy(duration: TimeInterval = 0.5, extraBounce: Double = 0.0) -> Spring { Spring() }
}
public struct UnitCurve: Hashable, Sendable {
  public static func bezier(startControlPoint: UnitPoint, endControlPoint: UnitPoint) -> UnitCurve { UnitCurve() }
  public static let easeInOut = UnitCurve()
  public static let easeIn = UnitCurve()
  public static let easeOut = UnitCurve()
  public static let circularEaseIn = UnitCurve()
  public static let circularEaseOut = UnitCurve()
  public static let circularEaseInOut = UnitCurve()
  public static let linear = UnitCurve()
  public func value(at progress: Double) -> Double { 0 }
  public func velocity(at progress: Double) -> Double { 0 }
  public var inverse: UnitCurve { self }
}
public struct Animation: Equatable, Hashable, Sendable, CustomStringConvertible {
  init() {}
  public var description: String { "" }
  public static let `default` = Animation()
  public static var linear: Animation { Animation() }
  public static func linear(duration: TimeInterval) -> Animation { Animation() }
  public static var easeIn: Animation { Animation() }
  public static func easeIn(duration: TimeInterval) -> Animation { Animation() }
  public static var easeOut: Animation { Animation() }
  public static func easeOut(duration: TimeInterval) -> Animation { Animation() }
  public static var easeInOut: Animation { Animation() }
  public static func easeInOut(duration: TimeInterval) -> Animation { Animation() }
  public static func timingCurve(_ p1x: Double, _ p1y: Double, _ p2x: Double, _ p2y: Double, duration: TimeInterval = 0.35) -> Animation {
    Animation()
  }
  public static func timingCurve(_ curve: UnitCurve, duration: TimeInterval) -> Animation { Animation() }
  public static var spring: Animation { Animation() }
  public static func spring(_ spring: Spring, blendDuration: TimeInterval = 0.0) -> Animation { Animation() }
  public static func spring(duration: TimeInterval = 0.5, bounce: Double = 0.0, blendDuration: Double = 0) -> Animation { Animation() }
  @_disfavoredOverload public static func spring(
    response: Double = 0.5, dampingFraction: Double = 0.825, blendDuration: TimeInterval = 0
  ) -> Animation { Animation() }
  public static var interactiveSpring: Animation { Animation() }
  @_disfavoredOverload public static func interactiveSpring(
    response: Double = 0.15, dampingFraction: Double = 0.86, blendDuration: TimeInterval = 0.25
  ) -> Animation { Animation() }
  public static func interactiveSpring(
    duration: TimeInterval = 0.15, extraBounce: Double = 0.0, blendDuration: TimeInterval = 0.25
  ) -> Animation { Animation() }
  public static var interpolatingSpring: Animation { Animation() }
  public static func interpolatingSpring(_ spring: Spring, initialVelocity: Double = 0.0) -> Animation { Animation() }
  public static func interpolatingSpring(mass: Double = 1.0, stiffness: Double, damping: Double, initialVelocity: Double = 0.0) -> Animation {
    Animation()
  }
  public static func interpolatingSpring(duration: TimeInterval = 0.5, bounce: Double = 0.0, initialVelocity: Double = 0.0) -> Animation {
    Animation()
  }
  public static var smooth: Animation { Animation() }
  public static func smooth(duration: TimeInterval = 0.5, extraBounce: Double = 0.0) -> Animation { Animation() }
  public static var snappy: Animation { Animation() }
  public static func snappy(duration: TimeInterval = 0.5, extraBounce: Double = 0.0) -> Animation { Animation() }
  public static var bouncy: Animation { Animation() }
  public static func bouncy(duration: TimeInterval = 0.5, extraBounce: Double = 0.0) -> Animation { Animation() }

  public func delay(_ delay: TimeInterval) -> Animation { self }
  public func speed(_ speed: Double) -> Animation { self }
  public func repeatCount(_ repeatCount: Int, autoreverses: Bool = true) -> Animation { self }
  public func repeatForever(autoreverses: Bool = true) -> Animation { self }
  public func logicallyComplete(after duration: TimeInterval) -> Animation { self }
}
public struct AnimationCompletionCriteria: Hashable, Sendable {
  public static let logicallyComplete = AnimationCompletionCriteria()
  public static let removed = AnimationCompletionCriteria()
}

public func withAnimation<Result>(_ animation: Animation? = .default, _ body: () throws -> Result) rethrows -> Result { try body() }
public func withAnimation<Result>(
  _ animation: Animation? = .default, completionCriteria: AnimationCompletionCriteria = .logicallyComplete, _ body: () throws -> Result,
  completion: @escaping () -> Void
) rethrows -> Result { try body() }

// MARK: Transaction

public protocol TransactionKey {
  associatedtype Value
  static var defaultValue: Value { get }
}
public struct Transaction {
  public init() {}
  public init(animation: Animation?) {}
  public var animation: Animation?
  public var disablesAnimations = false
  public var isContinuous = false
  public var tracksVelocity = false
  public subscript<K: TransactionKey>(key: K.Type) -> K.Value {
    get { K.defaultValue }
    set {}
  }
  public mutating func addAnimationCompletion(criteria: AnimationCompletionCriteria = .logicallyComplete, _ completion: @escaping () -> Void) {}
}
public func withTransaction<Result>(_ transaction: Transaction, _ body: () throws -> Result) rethrows -> Result { try body() }
public func withTransaction<R, V>(_ keyPath: WritableKeyPath<Transaction, V>, _ value: V, _ body: () throws -> R) rethrows -> R { try body() }

// MARK: Transitions

public struct AnyTransition {
  init() {}
  public init<T: Transition>(_ transition: T) {}
  public static var identity: AnyTransition { AnyTransition() }
  public static var opacity: AnyTransition { AnyTransition() }
  public static var slide: AnyTransition { AnyTransition() }
  public static var scale: AnyTransition { AnyTransition() }
  public static func scale(scale: CGFloat, anchor: UnitPoint = .center) -> AnyTransition { AnyTransition() }
  public static func move(edge: Edge) -> AnyTransition { AnyTransition() }
  public static func push(from edge: Edge) -> AnyTransition { AnyTransition() }
  public static func offset(_ offset: CGSize) -> AnyTransition { AnyTransition() }
  public static func offset(x: CGFloat = 0, y: CGFloat = 0) -> AnyTransition { AnyTransition() }
  public static func asymmetric(insertion: AnyTransition, removal: AnyTransition) -> AnyTransition { AnyTransition() }
  public static func modifier<E: ViewModifier>(active: E, identity: E) -> AnyTransition { AnyTransition() }
  public func combined(with other: AnyTransition) -> AnyTransition { self }
  public func animation(_ animation: Animation?) -> AnyTransition { self }
}

public enum TransitionPhase: Hashable, Sendable {
  case willAppear, identity, didDisappear
  public var isIdentity: Bool { false }
  public var value: Double { 0 }
}
public struct TransitionProperties: Sendable {
  public init(hasMotion: Bool = true) { self.hasMotion = hasMotion }
  public var hasMotion: Bool
}
public struct PlaceholderContentView<Value>: _PrimitiveView {}
@MainActor @preconcurrency public protocol Transition {
  associatedtype Body: View
  @ViewBuilder func body(content: Content, phase: TransitionPhase) -> Body
  static var properties: TransitionProperties { get }
  typealias Content = PlaceholderContentView<Self>
}
extension Transition {
  public static var properties: TransitionProperties { TransitionProperties() }
  public func combined<T: Transition>(with other: T) -> some Transition { self }
  public func animation(_ animation: Animation?) -> some Transition { self }
}
public struct IdentityTransition: Transition {
  public init() {}
  public func body(content: Content, phase: TransitionPhase) -> some View { content }
}
public struct OpacityTransition: Transition {
  public init() {}
  public func body(content: Content, phase: TransitionPhase) -> some View { content }
}
public struct SlideTransition: Transition {
  public init() {}
  public func body(content: Content, phase: TransitionPhase) -> some View { content }
}
public struct ScaleTransition: Transition {
  public var scale: Double
  public var anchor: UnitPoint
  public init(_ scale: Double, anchor: UnitPoint = .center) {
    self.scale = scale
    self.anchor = anchor
  }
  public func body(content: Content, phase: TransitionPhase) -> some View { content }
}
public struct MoveTransition: Transition {
  public var edge: Edge
  public init(edge: Edge) { self.edge = edge }
  public func body(content: Content, phase: TransitionPhase) -> some View { content }
}
public struct PushTransition: Transition {
  public var edge: Edge
  public init(edge: Edge) { self.edge = edge }
  public func body(content: Content, phase: TransitionPhase) -> some View { content }
}
public struct OffsetTransition: Transition {
  public var offset: CGSize
  public init(_ offset: CGSize) { self.offset = offset }
  public func body(content: Content, phase: TransitionPhase) -> some View { content }
}
public struct BlurReplaceTransition: Transition {
  public struct Configuration: Equatable, Sendable {
    public static let downUp = Configuration()
    public static let upUp = Configuration()
  }
  public var configuration: Configuration
  public init(configuration: Configuration) { self.configuration = configuration }
  public func body(content: Content, phase: TransitionPhase) -> some View { content }
}
public struct AsymmetricTransition<Insertion: Transition, Removal: Transition>: Transition {
  public var insertion: Insertion
  public var removal: Removal
  public init(insertion: Insertion, removal: Removal) {
    self.insertion = insertion
    self.removal = removal
  }
  public func body(content: Content, phase: TransitionPhase) -> some View { content }
}
extension Transition where Self == IdentityTransition {
  public static var identity: IdentityTransition { IdentityTransition() }
}
extension Transition where Self == OpacityTransition {
  public static var opacity: OpacityTransition { OpacityTransition() }
}
extension Transition where Self == SlideTransition {
  public static var slide: SlideTransition { SlideTransition() }
}
extension Transition where Self == ScaleTransition {
  public static var scale: ScaleTransition { ScaleTransition(0.5) }
  public static func scale(_ scale: Double, anchor: UnitPoint = .center) -> ScaleTransition { ScaleTransition(scale, anchor: anchor) }
}
extension Transition where Self == MoveTransition {
  public static func move(edge: Edge) -> MoveTransition { MoveTransition(edge: edge) }
}
extension Transition where Self == PushTransition {
  public static func push(from edge: Edge) -> PushTransition { PushTransition(edge: edge) }
}
extension Transition where Self == OffsetTransition {
  public static func offset(_ offset: CGSize) -> OffsetTransition { OffsetTransition(offset) }
  public static func offset(x: CGFloat = 0, y: CGFloat = 0) -> OffsetTransition { OffsetTransition(.zero) }
}
extension Transition where Self == BlurReplaceTransition {
  public static var blurReplace: BlurReplaceTransition { BlurReplaceTransition(configuration: .downUp) }
  public static func blurReplace(_ config: BlurReplaceTransition.Configuration = .downUp) -> BlurReplaceTransition {
    BlurReplaceTransition(configuration: config)
  }
}
extension Transition {
  public static func asymmetric<I: Transition, R: Transition>(insertion: I, removal: R) -> AsymmetricTransition<I, R>
  where Self == AsymmetricTransition<I, R> { AsymmetricTransition(insertion: insertion, removal: removal) }
}

public struct MatchedGeometryProperties: OptionSet, Sendable {
  public let rawValue: UInt32
  public init(rawValue: UInt32) { self.rawValue = rawValue }
  public static let position = MatchedGeometryProperties(rawValue: 1)
  public static let size = MatchedGeometryProperties(rawValue: 2)
  public static let frame = MatchedGeometryProperties(rawValue: 3)
}

nonisolated extension View {
  public func animation<V: Equatable>(_ animation: Animation?, value: V) -> some View { self }
  @available(*, deprecated, message: "Use withAnimation or animation(_:value:) instead.")
  public func animation(_ animation: Animation?) -> some View { self }
  public func animation<V: View>(_ animation: Animation?, @ViewBuilder body: (PlaceholderContentView<Self>) -> V) -> some View { self }
  public func transition(_ t: AnyTransition) -> some View { self }
  public func transition<T: Transition>(_ transition: T) -> some View { self }
  public func transaction(_ transform: @escaping (inout Transaction) -> Void) -> some View { self }
  public func transaction(value: some Equatable, _ transform: @escaping (inout Transaction) -> Void) -> some View { self }
  public func contentTransition(_ transition: ContentTransition) -> some View { self }
  public func matchedGeometryEffect<ID: Hashable>(
    id: ID, in namespace: Namespace.ID, properties: MatchedGeometryProperties = .frame, anchor: UnitPoint = .center, isSource: Bool = true
  ) -> some View { self }
  public func geometryGroup() -> some View { self }
}
extension View where Self: Equatable {
  public nonisolated func equatable() -> EquatableView<Self> { fatalError() }
  @available(*, deprecated, message: "Use withAnimation or animation(_:value:) instead.")
  public nonisolated func animation(_ animation: Animation?) -> some View { self }
}
