// A stand-in for SwiftUI: edges, axes, alignments, insets, angles, what can be animated, and the `Layout` protocol. See SwiftUI.swift.
// `Edge`, `Axis` and `Layout` (and `Settings`, in App.swift) collide with Arbor's own names here as on the Mac: a file that imports both
// SwiftUI and ArborCore has to say which it means.

// MARK: Edges and axes

public enum Edge: Int8, CaseIterable, Hashable, Sendable {
  case top, leading, bottom, trailing
  public struct Set: OptionSet, Sendable {
    public let rawValue: Int8
    public init(rawValue: Int8) { self.rawValue = rawValue }
    public init(_ e: Edge) { rawValue = 1 << e.rawValue }
    public static let top = Set(rawValue: 1)
    public static let leading = Set(rawValue: 2)
    public static let bottom = Set(rawValue: 4)
    public static let trailing = Set(rawValue: 8)
    public static let all = Set(rawValue: 15)
    public static let horizontal = Set(rawValue: 10)
    public static let vertical = Set(rawValue: 5)
  }
}
public enum HorizontalEdge: Int8, CaseIterable, Codable, Hashable, Sendable {
  case leading, trailing
  public struct Set: OptionSet, Sendable {
    public let rawValue: Int8
    public init(rawValue: Int8) { self.rawValue = rawValue }
    public init(_ edge: HorizontalEdge) { rawValue = 1 << edge.rawValue }
    public static let leading = Set(rawValue: 1)
    public static let trailing = Set(rawValue: 2)
    public static let all = Set(rawValue: 3)
  }
}
public enum VerticalEdge: Int8, CaseIterable, Codable, Hashable, Sendable {
  case top, bottom
  public struct Set: OptionSet, Sendable {
    public let rawValue: Int8
    public init(rawValue: Int8) { self.rawValue = rawValue }
    public init(_ edge: VerticalEdge) { rawValue = 1 << edge.rawValue }
    public static let top = Set(rawValue: 1)
    public static let bottom = Set(rawValue: 2)
    public static let all = Set(rawValue: 3)
  }
}
public enum Axis: Int8, CaseIterable, CustomStringConvertible, Hashable, Sendable {
  case horizontal, vertical
  public var description: String { "" }
  public struct Set: OptionSet, Sendable {
    public let rawValue: Int8
    public init(rawValue: Int8) { self.rawValue = rawValue }
    public static let horizontal = Set(rawValue: 1)
    public static let vertical = Set(rawValue: 2)
  }
}
public struct EdgeInsets: Equatable, Animatable, Sendable {
  public var top: CGFloat
  public var leading: CGFloat
  public var bottom: CGFloat
  public var trailing: CGFloat
  public init(top: CGFloat, leading: CGFloat, bottom: CGFloat, trailing: CGFloat) {
    self.top = top
    self.leading = leading
    self.bottom = bottom
    self.trailing = trailing
  }
  public init() { self.init(top: 0, leading: 0, bottom: 0, trailing: 0) }
  public typealias AnimatableData = AnimatablePair<CGFloat, AnimatablePair<CGFloat, AnimatablePair<CGFloat, CGFloat>>>
  public var animatableData: AnimatableData {
    get { fatalError() }
    set {}
  }
}
public enum LayoutDirection: Hashable, CaseIterable, Sendable { case leftToRight, rightToLeft }
public enum LayoutDirectionBehavior: Hashable, Sendable {
  case fixed
  case mirrors(in: LayoutDirection)
  public static var mirrors: LayoutDirectionBehavior { .mirrors(in: .rightToLeft) }
}
public enum ContentMode: Hashable, CaseIterable, Sendable { case fit, fill }
public struct SafeAreaRegions: OptionSet, Sendable {
  public let rawValue: UInt
  public init(rawValue: UInt) { self.rawValue = rawValue }
  public static let container = SafeAreaRegions(rawValue: 1)
  public static let keyboard = SafeAreaRegions(rawValue: 2)
  public static let all = SafeAreaRegions(rawValue: 3)
}

// MARK: Alignment

public protocol AlignmentID {
  static func defaultValue(in context: ViewDimensions) -> CGFloat
}
public struct ViewDimensions: Equatable {
  public var width: CGFloat { 0 }
  public var height: CGFloat { 0 }
  public subscript(guide: HorizontalAlignment) -> CGFloat { 0 }
  public subscript(guide: VerticalAlignment) -> CGFloat { 0 }
  public subscript(explicit guide: HorizontalAlignment) -> CGFloat? { nil }
  public subscript(explicit guide: VerticalAlignment) -> CGFloat? { nil }
}
public struct HorizontalAlignment: Equatable, Sendable {
  public init(_ id: AlignmentID.Type) {}
  init() {}
  public static let leading = HorizontalAlignment()
  public static let center = HorizontalAlignment()
  public static let trailing = HorizontalAlignment()
  public static let listRowSeparatorLeading = HorizontalAlignment()
  public static let listRowSeparatorTrailing = HorizontalAlignment()
}
public struct VerticalAlignment: Equatable, Sendable {
  public init(_ id: AlignmentID.Type) {}
  init() {}
  public static let top = VerticalAlignment()
  public static let center = VerticalAlignment()
  public static let bottom = VerticalAlignment()
  public static let firstTextBaseline = VerticalAlignment()
  public static let lastTextBaseline = VerticalAlignment()
}
public struct Alignment: Equatable, Sendable {
  public var horizontal: HorizontalAlignment
  public var vertical: VerticalAlignment
  public init(horizontal: HorizontalAlignment, vertical: VerticalAlignment) {
    self.horizontal = horizontal
    self.vertical = vertical
  }
  public static let center = Alignment(horizontal: .center, vertical: .center)
  public static let leading = Alignment(horizontal: .leading, vertical: .center)
  public static let trailing = Alignment(horizontal: .trailing, vertical: .center)
  public static let top = Alignment(horizontal: .center, vertical: .top)
  public static let bottom = Alignment(horizontal: .center, vertical: .bottom)
  public static let topLeading = Alignment(horizontal: .leading, vertical: .top)
  public static let topTrailing = Alignment(horizontal: .trailing, vertical: .top)
  public static let bottomLeading = Alignment(horizontal: .leading, vertical: .bottom)
  public static let bottomTrailing = Alignment(horizontal: .trailing, vertical: .bottom)
  public static var centerFirstTextBaseline: Alignment { Alignment(horizontal: .center, vertical: .firstTextBaseline) }
  public static var centerLastTextBaseline: Alignment { Alignment(horizontal: .center, vertical: .lastTextBaseline) }
  public static var leadingFirstTextBaseline: Alignment { Alignment(horizontal: .leading, vertical: .firstTextBaseline) }
  public static var leadingLastTextBaseline: Alignment { Alignment(horizontal: .leading, vertical: .lastTextBaseline) }
  public static var trailingFirstTextBaseline: Alignment { Alignment(horizontal: .trailing, vertical: .firstTextBaseline) }
  public static var trailingLastTextBaseline: Alignment { Alignment(horizontal: .trailing, vertical: .lastTextBaseline) }
}
public enum TextAlignment: Hashable, CaseIterable, Sendable { case leading, center, trailing }

// MARK: Points and angles

public struct UnitPoint: Hashable, Animatable, Sendable {
  public var x: CGFloat
  public var y: CGFloat
  public init() { self.init(x: 0, y: 0) }
  public init(x: CGFloat, y: CGFloat) {
    self.x = x
    self.y = y
  }
  public static let zero = UnitPoint(x: 0, y: 0)
  public static let center = UnitPoint(x: 0.5, y: 0.5)
  public static let leading = UnitPoint(x: 0, y: 0.5)
  public static let trailing = UnitPoint(x: 1, y: 0.5)
  public static let top = UnitPoint(x: 0.5, y: 0)
  public static let bottom = UnitPoint(x: 0.5, y: 1)
  public static let topLeading = UnitPoint(x: 0, y: 0)
  public static let topTrailing = UnitPoint(x: 1, y: 0)
  public static let bottomLeading = UnitPoint(x: 0, y: 1)
  public static let bottomTrailing = UnitPoint(x: 1, y: 1)
  public var animatableData: AnimatablePair<CGFloat, CGFloat> {
    get { fatalError() }
    set {}
  }
}
public struct Angle: Hashable, Comparable, Animatable, Sendable {
  public var radians: Double
  public var degrees: Double {
    get { radians }
    set {}
  }
  public init() { radians = 0 }
  public init(radians: Double) { self.radians = radians }
  public init(degrees: Double) { radians = degrees }
  public static func radians(_ radians: Double) -> Angle { Angle(radians: radians) }
  public static func degrees(_ degrees: Double) -> Angle { Angle(degrees: degrees) }
  public static var zero: Angle { Angle() }
  public static func < (lhs: Angle, rhs: Angle) -> Bool { lhs.radians < rhs.radians }
  public static func + (lhs: Angle, rhs: Angle) -> Angle { lhs }
  public static func - (lhs: Angle, rhs: Angle) -> Angle { lhs }
  public static func * (lhs: Angle, rhs: Double) -> Angle { lhs }
  public static func * (lhs: Double, rhs: Angle) -> Angle { rhs }
  public static func / (lhs: Angle, rhs: Double) -> Angle { lhs }
  public static prefix func - (angle: Angle) -> Angle { angle }
  public static func += (lhs: inout Angle, rhs: Angle) {}
  public static func -= (lhs: inout Angle, rhs: Angle) {}
  public static func *= (lhs: inout Angle, rhs: Double) {}
  public static func /= (lhs: inout Angle, rhs: Double) {}
  public var animatableData: Double {
    get { radians }
    set {}
  }
}

public enum CoordinateSpace: Equatable, Hashable {
  case global
  case local
  case named(AnyHashable)
  public var isGlobal: Bool { false }
  public var isLocal: Bool { false }
}
public protocol CoordinateSpaceProtocol {
  var coordinateSpace: CoordinateSpace { get }
}
public struct NamedCoordinateSpace: CoordinateSpaceProtocol, Equatable {
  public var coordinateSpace: CoordinateSpace { .local }
}
public struct LocalCoordinateSpace: CoordinateSpaceProtocol {
  public init() {}
  public var coordinateSpace: CoordinateSpace { .local }
}
public struct GlobalCoordinateSpace: CoordinateSpaceProtocol {
  public init() {}
  public var coordinateSpace: CoordinateSpace { .global }
}
extension CoordinateSpaceProtocol where Self == NamedCoordinateSpace {
  public static func named(_ name: some Hashable) -> NamedCoordinateSpace { NamedCoordinateSpace() }
  public static func scrollView(axis: Axis) -> NamedCoordinateSpace { NamedCoordinateSpace() }
  public static var scrollView: NamedCoordinateSpace { NamedCoordinateSpace() }
}
extension CoordinateSpaceProtocol where Self == LocalCoordinateSpace {
  public static var local: LocalCoordinateSpace { LocalCoordinateSpace() }
}
extension CoordinateSpaceProtocol where Self == GlobalCoordinateSpace {
  public static var global: GlobalCoordinateSpace { GlobalCoordinateSpace() }
}

public struct Anchor<Value> {
  public struct Source {
    public init<T>(_ array: [Anchor<T>.Source]) where Value == [T] {}
    public init<T>(_ anchor: Anchor<T>.Source?) where Value == T? {}
    init() {}
  }
}
extension Anchor.Source where Value == CGRect {
  public static func rect(_ r: CGRect) -> Anchor<CGRect>.Source { Anchor<CGRect>.Source() }
  public static var bounds: Anchor<CGRect>.Source { Anchor<CGRect>.Source() }
}
extension Anchor.Source where Value == CGPoint {
  public static func point(_ p: CGPoint) -> Anchor<CGPoint>.Source { Anchor<CGPoint>.Source() }
  public static func unitPoint(_ p: UnitPoint) -> Anchor<CGPoint>.Source { Anchor<CGPoint>.Source() }
  public static var topLeading: Anchor<CGPoint>.Source { Anchor<CGPoint>.Source() }
  public static var top: Anchor<CGPoint>.Source { Anchor<CGPoint>.Source() }
  public static var topTrailing: Anchor<CGPoint>.Source { Anchor<CGPoint>.Source() }
  public static var leading: Anchor<CGPoint>.Source { Anchor<CGPoint>.Source() }
  public static var center: Anchor<CGPoint>.Source { Anchor<CGPoint>.Source() }
  public static var trailing: Anchor<CGPoint>.Source { Anchor<CGPoint>.Source() }
  public static var bottomLeading: Anchor<CGPoint>.Source { Anchor<CGPoint>.Source() }
  public static var bottom: Anchor<CGPoint>.Source { Anchor<CGPoint>.Source() }
  public static var bottomTrailing: Anchor<CGPoint>.Source { Anchor<CGPoint>.Source() }
}

// MARK: What can be animated

public protocol VectorArithmetic: AdditiveArithmetic {
  mutating func scale(by rhs: Double)
  var magnitudeSquared: Double { get }
}
extension Float: VectorArithmetic {
  public mutating func scale(by rhs: Double) {}
  public var magnitudeSquared: Double { 0 }
}
extension Double: VectorArithmetic {
  public mutating func scale(by rhs: Double) {}
  public var magnitudeSquared: Double { 0 }
}
extension CGFloat: VectorArithmetic {
  public mutating func scale(by rhs: Double) {}
  public var magnitudeSquared: Double { 0 }
}
public protocol Animatable {
  associatedtype AnimatableData: VectorArithmetic
  var animatableData: AnimatableData { get set }
}
extension Animatable where Self: VectorArithmetic {
  public var animatableData: Self {
    get { self }
    set {}
  }
}
extension Animatable where AnimatableData == EmptyAnimatableData {
  public var animatableData: EmptyAnimatableData {
    get { EmptyAnimatableData() }
    set {}
  }
}
public struct EmptyAnimatableData: VectorArithmetic, Sendable {
  public init() {}
  public static var zero: EmptyAnimatableData { EmptyAnimatableData() }
  public static func + (lhs: EmptyAnimatableData, rhs: EmptyAnimatableData) -> EmptyAnimatableData { lhs }
  public static func - (lhs: EmptyAnimatableData, rhs: EmptyAnimatableData) -> EmptyAnimatableData { lhs }
  public mutating func scale(by rhs: Double) {}
  public var magnitudeSquared: Double { 0 }
}
public struct AnimatablePair<First: VectorArithmetic, Second: VectorArithmetic>: VectorArithmetic {
  public var first: First
  public var second: Second
  public init(_ first: First, _ second: Second) {
    self.first = first
    self.second = second
  }
  public static var zero: AnimatablePair<First, Second> { AnimatablePair(.zero, .zero) }
  public static func + (lhs: AnimatablePair<First, Second>, rhs: AnimatablePair<First, Second>) -> AnimatablePair<First, Second> { lhs }
  public static func - (lhs: AnimatablePair<First, Second>, rhs: AnimatablePair<First, Second>) -> AnimatablePair<First, Second> { lhs }
  public mutating func scale(by rhs: Double) {}
  public var magnitudeSquared: Double { 0 }
}
extension AnimatablePair: Sendable where First: Sendable, Second: Sendable {}
extension CGPoint: Animatable {
  public var animatableData: AnimatablePair<CGFloat, CGFloat> {
    get { AnimatablePair(x, y) }
    set {}
  }
}
extension CGSize: Animatable {
  public var animatableData: AnimatablePair<CGFloat, CGFloat> {
    get { AnimatablePair(width, height) }
    set {}
  }
}
extension CGRect: Animatable {
  public var animatableData: AnimatablePair<CGPoint.AnimatableData, CGSize.AnimatableData> {
    get { AnimatablePair(origin.animatableData, size.animatableData) }
    set {}
  }
}
/// Deprecated in favour of a type that is both `Animatable` and a `ViewModifier`.
public protocol AnimatableModifier: Animatable, ViewModifier {}

// MARK: Layout

public struct ProposedViewSize: Equatable, Sendable {
  public var width: CGFloat?
  public var height: CGFloat?
  public init(width: CGFloat?, height: CGFloat?) {
    self.width = width
    self.height = height
  }
  public init(_ size: CGSize) { self.init(width: size.width, height: size.height) }
  public static let zero = ProposedViewSize(width: 0, height: 0)
  public static let unspecified = ProposedViewSize(width: nil, height: nil)
  public static let infinity = ProposedViewSize(width: .infinity, height: .infinity)
  public func replacingUnspecifiedDimensions(by size: CGSize = CGSize(width: 10, height: 10)) -> CGSize { size }
}
public struct ViewSpacing: Sendable {
  public init() {}
  public static let zero = ViewSpacing()
  public mutating func formUnion(_ other: ViewSpacing, edges: Edge.Set = .all) {}
  public func union(_ other: ViewSpacing, edges: Edge.Set = .all) -> ViewSpacing { self }
  public func distance(to next: ViewSpacing, along axis: Axis) -> CGFloat { 0 }
}
public struct LayoutProperties: Sendable {
  public init() {}
  public var stackOrientation: Axis?
}
public protocol LayoutValueKey {
  associatedtype Value
  static var defaultValue: Value { get }
}
public struct LayoutSubview: Equatable {
  public subscript<K: LayoutValueKey>(key: K.Type) -> K.Value { K.defaultValue }
  public var priority: Double { 0 }
  public var spacing: ViewSpacing { ViewSpacing() }
  public func sizeThatFits(_ proposal: ProposedViewSize) -> CGSize { .zero }
  public func dimensions(in proposal: ProposedViewSize) -> ViewDimensions { ViewDimensions() }
  public func place(at position: CGPoint, anchor: UnitPoint = .topLeading, proposal: ProposedViewSize) {}
}
public struct LayoutSubviews: Equatable, RandomAccessCollection, Sendable {
  public typealias Element = LayoutSubview
  public typealias Index = Int
  public typealias SubSequence = LayoutSubviews
  public var layoutDirection: LayoutDirection
  public var startIndex: Int { 0 }
  public var endIndex: Int { 0 }
  public subscript(index: Int) -> LayoutSubview { fatalError() }
  public subscript(bounds: Range<Int>) -> LayoutSubviews { self }
  public subscript<S: Sequence>(indices: S) -> LayoutSubviews where S.Element == Int { self }
}
public protocol Layout: Animatable {
  static var layoutProperties: LayoutProperties { get }
  associatedtype Cache = Void
  typealias Subviews = LayoutSubviews
  func makeCache(subviews: Subviews) -> Cache
  func updateCache(_ cache: inout Cache, subviews: Subviews)
  func spacing(subviews: Subviews, cache: inout Cache) -> ViewSpacing
  func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache) -> CGSize
  func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache)
  func explicitAlignment(
    of guide: HorizontalAlignment, in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache
  ) -> CGFloat?
  func explicitAlignment(
    of guide: VerticalAlignment, in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache
  ) -> CGFloat?
}
extension Layout {
  public static var layoutProperties: LayoutProperties { LayoutProperties() }
  public func updateCache(_ cache: inout Cache, subviews: Subviews) {}
  public func spacing(subviews: Subviews, cache: inout Cache) -> ViewSpacing { ViewSpacing() }
  public func explicitAlignment(
    of guide: HorizontalAlignment, in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache
  ) -> CGFloat? { nil }
  public func explicitAlignment(
    of guide: VerticalAlignment, in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache
  ) -> CGFloat? { nil }
  public func callAsFunction<V: View>(@ViewBuilder _ content: () -> V) -> some View { content() }
}
extension Layout where Cache == Void {
  public func makeCache(subviews: Subviews) {}
}
public struct AnyLayout: Layout {
  public struct Cache {}
  public typealias AnimatableData = EmptyAnimatableData
  public init<L: Layout>(_ layout: L) {}
  public func makeCache(subviews: Subviews) -> Cache { Cache() }
  public func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache) -> CGSize { .zero }
  public func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache) {}
}
public struct HStackLayout: Layout, Sendable {
  public var alignment: VerticalAlignment
  public var spacing: CGFloat?
  public init(alignment: VerticalAlignment = .center, spacing: CGFloat? = nil) {
    self.alignment = alignment
    self.spacing = spacing
  }
  public typealias AnimatableData = EmptyAnimatableData
  public func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) -> CGSize { .zero }
  public func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) {}
}
public struct VStackLayout: Layout, Sendable {
  public var alignment: HorizontalAlignment
  public var spacing: CGFloat?
  public init(alignment: HorizontalAlignment = .center, spacing: CGFloat? = nil) {
    self.alignment = alignment
    self.spacing = spacing
  }
  public typealias AnimatableData = EmptyAnimatableData
  public func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) -> CGSize { .zero }
  public func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) {}
}
public struct ZStackLayout: Layout, Sendable {
  public var alignment: Alignment
  public init(alignment: Alignment = .center) { self.alignment = alignment }
  public typealias AnimatableData = EmptyAnimatableData
  public func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) -> CGSize { .zero }
  public func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) {}
}
public struct GridLayout: Layout, Sendable {
  public var alignment: Alignment
  public var horizontalSpacing: CGFloat?
  public var verticalSpacing: CGFloat?
  public init(alignment: Alignment = .center, horizontalSpacing: CGFloat? = nil, verticalSpacing: CGFloat? = nil) {
    self.alignment = alignment
    self.horizontalSpacing = horizontalSpacing
    self.verticalSpacing = verticalSpacing
  }
  public typealias AnimatableData = EmptyAnimatableData
  public func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) -> CGSize { .zero }
  public func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) {}
}
nonisolated extension View {
  public func layoutValue<K: LayoutValueKey>(key: K.Type, value: K.Value) -> some View { self }
}
